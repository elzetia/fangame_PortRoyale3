# Le constructeur d'écran de Port Royale 3.
#
# Plutôt que de coder chaque interface à la main, on REJOUE l'agencement décodé
# des .swf : `outils/swf_export.py` a exporté les 169 fichiers d'interface de PR3
# en JSON (161 scènes, ~15 900 éléments), chacun portant son nom d'instance, sa
# classe de composant et sa position au pixel. Ce script lit ce JSON et pose les
# nœuds Godot aux mêmes coordonnées, avec l'art extrait du jeu.
#
# Les pièges, tous payés comptant :
#
#  1. PR3 instancie ses composants par PlaceObject3 « HasClassName » — une chaîne
#     de classe glissée avant le charId. Tant qu'on ne la saute pas, le nom
#     d'instance et la matrice sont lus au mauvais offset.
#  2. Un onglet a son PROPRE décalage dans la scène (le chantier pose ses pages
#     à (102,-123), l'info-ville à (15,113)). Sans lui, la grille de statistiques
#     tombe hors du cadre. Voir `decalage_onglet()`.
#  3. Un Control libre n'a pas de taille : `custom_minimum_size` ne vaut que dans
#     un conteneur. Il faut poser `size`.
#  4. Un TextureRect a pour taille MINIMALE celle de sa texture : sans
#     `expand_mode = EXPAND_IGNORE_SIZE`, il refuse de rétrécir et une icône de
#     marchandise s'affiche à sa taille native.
#  5. L'échelle d'un placement étire la LARGEUR du champ, pas sa police. Un
#     `Visual_Textfeld_16` mesure environ 82 px avant étirement — vérifié sur
#     `tf_ships` (×0,703) dont la plaque fait 13×4,62 = 60 px, et 82 × 0,703 = 58.
#     Sans cette largeur, « Espagne, neutre » s'affiche « agne, ne ».
#
# L'art (cadres, icônes) vient de `reference_pr3/`, ignoré par git — sous droits,
# lu au runtime comme les modèles de navires. Absent, l'écran se bâtit quand même
# en aplats : la STRUCTURE ne dépend jamais de l'art.
class_name EcranPR3
extends RefCounted

const AGENCEMENT := "res://reference_pr3/ui/agencement/"
const SKIN := "skinlib_pr3/"

# Le cadre à onglets de PR3 (exports.Dialog_Tabbed), large de 430 px :
# un bandeau de bois, un parchemin répété, un culot bordé de corde dorée.
# (777 et 750 sont des CULOTS arrondis, pas des tuiles — les répéter empile des
# plaques au lieu de remplir le fond. Seul 753 se répète.)
const CADRE := {"bandeau": "757", "corps": "753", "culot": "750"}
const CADRE_LARGEUR := 430
const CADRE_HAUTEUR := 572

# La plaque `Text_Bg_Nomal` mesure 13x20 avant étirement ; un champ de texte
# environ 82 de large.
const PLAQUE := Vector2(13, 20)
const LARGEUR_TEXTE := 82.0

static var _json: Dictionary = {}
static var _icones: Dictionary = {}
static var _caracteres: Dictionary = {}
# Les DÉCALAGES, 4e et 5e colonnes des deux tables : où poser l'art par rapport
# au point de placement. Voir `_pose()`.
static var _decalages: Dictionary = {}
static var _caracteres_dec: Dictionary = {}
# La table en COUCHES : une classe -> l'empilement de son état au repos.
static var _couches: Dictionary = {}
# La table des champs texte : hauteur, couleur et alignement déclarés par PR3.
static var _textes: Dictionary = {}


# --- lecture des données décodées --------------------------------------------

static func agencement(swf: String) -> Dictionary:
	if _json.has(swf):
		return _json[swf]
	var doc := {}
	var chemin := ProjectSettings.globalize_path(AGENCEMENT + swf + ".json")
	if FileAccess.file_exists(chemin):
		var lu = JSON.parse_string(FileAccess.get_file_as_string(chemin))
		if lu is Dictionary:
			doc = lu
	_json[swf] = doc
	return doc


static func icones() -> Dictionary:
	if not _icones.is_empty():
		return _icones
	var chemin := ProjectSettings.globalize_path(AGENCEMENT + "icones.txt")
	if FileAccess.file_exists(chemin):
		for ligne in FileAccess.get_file_as_string(chemin).split("\n"):
			var bouts := ligne.split("\t")
			if bouts.size() >= 2:
				var cle := bouts[0].strip_edges()
				_icones[cle] = bouts[1].strip_edges()
				# 4e et 5e colonnes : le DÉCALAGE mesuré dans le .swf. 454 des
				# 969 entrées en ont un. Sans cette lecture, et `bouton()` ne
				# recentrant plus à la main, tous les boutons partaient de
				# +taille/2 — sans que le test le voie, faute de regarder leur
				# position.
				if bouts.size() >= 5:
					_decalages[cle] = Vector2(float(bouts[3]), float(bouts[4]))
	return _icones


# La table en COUCHES (`outils/swf_icones.py` -> icones_couches.txt).
#
# Un bouton de PR3 n'est pas une image mais un EMPILEMENT : un bezel de 42x42 et
# son glyphe par-dessus. La table à une seule feuille gardait le glyphe et jetait
# l'anneau — et pire, prenait le glyphe de l'image 0, qui pour un bouton rond est
# étiquetée « NormalDisable ». Les boutons sortaient donc nus ET grisés.
#
# 1383 couches pour 967 classes, dont 139 en portent plusieurs : 100 bezel +
# glyphe, 30 disjointes (six onglets côte à côte), 9 exclusions que le fichier
# ne sait pas départager — `Visual_SelectedAmmo` nomme ses images AmmoA/B/C sans
# aucun « Normal », c'est le jeu qui choisit la munition.
static func couches() -> Dictionary:
	if not _couches.is_empty():
		return _couches
	var chemin := ProjectSettings.globalize_path(AGENCEMENT + "icones_couches.txt")
	if FileAccess.file_exists(chemin):
		for ligne in FileAccess.get_file_as_string(chemin).split("\n"):
			var bouts := ligne.split("\t")
			if bouts.size() >= 6:
				var cle := bouts[0].strip_edges()
				if not _couches.has(cle):
					_couches[cle] = []
				(_couches[cle] as Array).append({
					"fichier": bouts[2].strip_edges(),
					"decalage": Vector2(float(bouts[4]), float(bouts[5]))})
	return _couches


# Bâtit l'empilement d'une classe, ou `null` si la table ne la connaît pas.
#
# Le nœud rendu a pour origine le coin haut-gauche de l'UNION des couches, et
# chacune y est posée relativement. `batir()` ajoute ensuite le point de
# placement, si bien que l'ensemble retombe exactement où les décalages le
# veulent — et qu'un symbole à UNE couche rend le même pixel qu'avant.
static func _pile(classe: String) -> Control:
	var court := classe.get_slice(".", classe.get_slice_count(".") - 1)
	var liste: Array = couches().get(court, [])
	if liste.is_empty():
		return null

	var trouvees: Array = []
	var coin := Vector2(INF, INF)
	var bout := Vector2(-INF, -INF)
	for c in liste:
		var d: Dictionary = c
		var tex := SkinPR3.texture(SKIN + str(d["fichier"]).replace(".png", ""))
		if tex == null:
			continue
		var dec: Vector2 = d["decalage"]
		trouvees.append([tex, dec])
		coin = Vector2(minf(coin.x, dec.x), minf(coin.y, dec.y))
		bout = Vector2(maxf(bout.x, dec.x + tex.get_width()),
			maxf(bout.y, dec.y + tex.get_height()))
	if trouvees.is_empty():
		return null

	var racine := Control.new()
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.position = coin
	racine.size = bout - coin
	for t in trouvees:
		var paire: Array = t
		var tex2: Texture2D = paire[0]
		var dec2: Vector2 = paire[1]
		var im := _image(tex2, tex2.get_size())
		im.position = dec2 - coin
		racine.add_child(im)
	return racine


# La table des CHAMPS TEXTE (`outils/swf_icones.py` -> textes.txt).
#
# Les écrans ne définissent aucun `DefineEditText` : les 25 du jeu vivent à la
# RACINE de skinlib_pr3, et hud_pc comme dialog_trade se contentent de placer des
# `Visual_Textfeld_*`. La branche « texte » du constructeur d'écrans n'a donc
# jamais rien produit — elle ne le pouvait pas. D'où cette table par CLASSE.
static func textes() -> Dictionary:
	if not _textes.is_empty():
		return _textes
	var chemin := ProjectSettings.globalize_path(AGENCEMENT + "textes.txt")
	if FileAccess.file_exists(chemin):
		for ligne in FileAccess.get_file_as_string(chemin).split("\n"):
			var bouts := ligne.split("\t")
			if bouts.size() >= 5:
				_textes[bouts[0].strip_edges()] = {
					"hauteur": int(bouts[1]),
					"couleur": bouts[2].strip_edges(),
					"align": int(bouts[4]) if bouts[4].strip_edges().is_valid_int() else 0}
	return _textes


# La table charId -> bitmap d'UN .swf, écrite par `outils/swf_caracteres.py`.
#
# Un caractère anonyme n'a pas de nom de classe : seul son numéro le désigne, et
# ce numéro ne vaut que dans son propre .swf. D'où une table par fichier, posée à
# côté de ses PNG, et non dans la table globale des classes.
#
# Le piège qu'elle résout : un charId placé désigne une FORME, alors que le PNG
# extrait porte l'identifiant du BITMAP que cette forme remplit. Les deux
# numérotations sont disjointes.
static func caracteres(swf: String) -> Dictionary:
	if _caracteres.has(swf):
		return _caracteres[swf]
	var table := {}
	var decalages := {}
	var chemin := ProjectSettings.globalize_path(
		SkinPR3.RACINE + swf + "/caracteres.txt")
	if FileAccess.file_exists(chemin):
		for ligne in FileAccess.get_file_as_string(chemin).split("\n"):
			var bouts := ligne.split("\t")
			if bouts.size() >= 2:
				var cle := bouts[0].strip_edges()
				table[cle] = bouts[1].strip_edges()
				if bouts.size() >= 5:
					decalages[cle] = Vector2(float(bouts[3]), float(bouts[4]))
	_caracteres[swf] = table
	_caracteres_dec[swf] = decalages
	return table


# L'image d'un caractère anonyme, si la classe en est un (« char172 »).
#
# On exige des CHIFFRES derrière « char » : PR3 a de vraies classes qui
# commencent par ces quatre lettres — `char_dutch_admin01.png`,
# `char_england_admin01.png` — et les happer ici les priverait de leur image.
static func _caractere(swf: String, classe: String) -> Texture2D:
	if not classe.begins_with("char"):
		return null
	var numero := classe.substr(4)
	if not numero.is_valid_int():
		return null
	var fichier: String = caracteres(swf).get(numero, "")
	if fichier == "":
		return null
	return SkinPR3.texture(swf + "/" + fichier.replace(".png", ""))


# Où la scène pose cet onglet. C'est le décalage que PR3 applique à la page
# entière : sans lui les champs sont posés comme si l'onglet vivait en (0,0).
static func decalage_onglet(swf: String, scene_racine: String, onglet: String) -> Vector2:
	var ecrans: Dictionary = agencement(swf).get("ecrans", {})
	for el in (ecrans.get(scene_racine, []) as Array):
		var d: Dictionary = el
		if str(d.get("classe", "")) == onglet:
			return Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
	return Vector2.ZERO


# La position d'un élément NOMMÉ dans une scène — `cr_ship`, `mc_bg`… Certains
# vivent au niveau de la scène et non dans un onglet : on va donc chercher leur
# point plutôt que de le fixer à la main.
static func point(swf: String, scene: String, nom: String) -> Vector2:
	var ecrans: Dictionary = agencement(swf).get("ecrans", {})
	for el in (ecrans.get(scene, []) as Array):
		var d: Dictionary = el
		if str(d.get("nom", "")) == nom:
			return Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
	return Vector2.ZERO


# --- fabrique de nœuds ---------------------------------------------------------

static func _taille_police(classe: String) -> int:
	var m := RegEx.new()
	m.compile("Visual_Textfeld_(\\d+)")
	var r := m.search(classe)
	return int(r.get_string(1)) if r != null else 16


static func _icone(classe: String) -> Texture2D:
	var court := classe.get_slice(".", classe.get_slice_count(".") - 1)
	var fichier: String = icones().get(court, "")
	if fichier == "":
		return null
	return SkinPR3.texture(SKIN + fichier.replace(".png", ""))


# Le décalage d'un symbole NOMMÉ, et celui d'un caractère anonyme.
static func _decalage_icone(classe: String) -> Vector2:
	icones()
	return _decalages.get(classe.get_slice(".", classe.get_slice_count(".") - 1),
		Vector2.ZERO)


static func _decalage_caractere(swf: String, classe: String) -> Vector2:
	caracteres(swf)
	var table: Dictionary = _caracteres_dec.get(swf, {})
	return table.get(classe.substr(4), Vector2.ZERO)


# Pose une image À SON DÉCALAGE, mesuré dans le .swf et non deviné.
#
# L'art d'un symbole ne commence pas forcément à son point de placement : une
# forme porte ses bornes dans son RECT, un sprite pose son contenu par une
# matrice. Mesure sur skinlib_pr3 : les boutons rendent exactement -taille/2,
# les plaques (0,0). La règle « boutons par le centre, plaques par le coin »,
# d'abord DÉDUITE de la mise en page de la planche gauche, n'était donc qu'un
# reflet de cette origine — juste, mais aveugle à tout le reste : la planche du
# bandeau de ville a pour origine -219, et `char126` (-99,-11).
#
# 454 des 969 entrées de la table d'icônes ont un décalage non nul, et 65 des
# 139 caractères de hud_pc.
static func _pose(tex: Texture2D, decalage: Vector2) -> Control:
	var n := _image(tex, tex.get_size())
	n.position = decalage
	return n


static func _image(tex: Texture2D, taille: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	# Sans cela un TextureRect ne descend jamais sous la taille de sa texture.
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size = taille
	return t


# Bâtit UN élément selon sa classe de composant PR3, À SA TAILLE.
#
# `repli` ouvre le dernier recours à la table classe -> image (voir plus bas). Il
# est FERMÉ par défaut, et c'est une MESURE qui l'a décidé : ouvert partout, il
# fait dessiner 2109 éléments de plus — 13,3 % — dans 156 des 169 fichiers
# d'écran. Beaucoup seraient faux, car la règle de plus-petite-surface de la
# table est calibrée pour des ICÔNES : elle rend `Dialog_Tabbed` -> 714.png, le
# carreau de fond de 16x16, là où le cadre est 801.png en 748x578, et pose une
# plaque d'onglet de 138x34 sous les 395 `Visual_TextButton_Tab` d'écrans qui
# dessinent déjà leurs onglets. Les écrans livrés gardent donc leur rendu ; seul
# qui le demande obtient le repli.
static func _noeud(el: Dictionary, repli: bool, swf: String) -> Control:
	var classe := str(el.get("classe", ""))
	var sx := float(el.get("sx", 1.0))
	var sy := float(el.get("sy", 1.0))

	if classe.contains("Visual_Textfeld"):
		var l := Label.new()
		# La hauteur DÉCLARÉE par PR3 quand la table la connaît, le nom sinon.
		# Les deux s'accordent sur 17 des 19 symboles ; les deux écarts
		# (`_18_Shadow` qui rend 17, `_24` qui rend 22) réutilisent
		# l'enregistrement d'un voisin — un fait du fichier, pas une erreur.
		var fiche: Dictionary = textes().get(
			classe.get_slice(".", classe.get_slice_count(".") - 1), {})
		l.add_theme_font_size_override("font_size",
			int(fiche.get("hauteur", _taille_police(classe))))
		# La police du JEU, quand elle a été extraite sur cette machine. C'est ici
		# qu'elle se pose et nulle part ailleurs : tous les écrans fabriquent
		# leurs champs par ce chemin, le HUD comme les dialogues. Absente, Godot
		# garde la sienne et l'écran reste lisible — voir `FontePR3`.
		FontePR3.poser(l)
		l.add_theme_color_override("font_color", Color(0.19, 0.13, 0.07))
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# L'alignement DÉCLARÉ, lu dans la table, et non plus un test sur le nom.
		# Le bloc de mise en page d'un `DefineEditText` porte un octet
		# d'alignement (0 gauche, 1 droite, 2 centre, 3 justifié) qui était sauté
		# avec le reste du bloc. Tout centrer décalait chaque valeur dans sa
		# plaque — l'or de la planche droite le premier.
		#
		# Un test sur « Subheadline » aurait couvert trois classes ; la table en
		# mesure 115, dont `Visual_ListButton_Lock` et
		# `Visual_TextButton_Input_Chooser`, centrés sans que leur nom le dise.
		match int(fiche.get("align", 0)):
			1: l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			2: l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			3: l.horizontal_alignment = HORIZONTAL_ALIGNMENT_FILL
			_: l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.clip_text = true
		l.size = Vector2(LARGEUR_TEXTE * sx, PLAQUE.y)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return l

	if classe.contains("Text_Bg"):
		var p := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.62, 0.56, 0.42, 0.55)
		sb.border_color = Color(0.38, 0.30, 0.17, 0.9)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		if classe.contains("Red"):
			sb.border_color = Color(0.60, 0.20, 0.16)
		p.add_theme_stylebox_override("panel", sb)
		p.size = Vector2(PLAQUE.x * sx, PLAQUE.y * sy)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return p

	# Ce qui ne doit JAMAIS se peindre.
	#
	# `Visual_Button_Empty` est une zone de clic invisible dans PR3 : la rendre
	# en bouton posait un rectangle gris fantôme sous l'action.
	#
	# Les `Mask_*` / `Maske_*` sont des MASQUES — de la géométrie qui découpe,
	# jamais de l'art. Leur forme est un aplat noir opaque (char9 en 32x32,
	# char22 en 34x34, char96 en 156x34), et la peindre poserait un carré noir
	# par-dessus la minimap ou le nom de la ville. PR3 les affecte au runtime en
	# ActionScript, pas par le `ClipDepth` du conteneur : le drapeau est absent
	# des balises, et seul le NOM du sprite parent les trahit.
	if classe.contains("Visual_Button_Empty") or classe.contains("Button_Mask") \
			or classe.contains("Mask_") or classe.contains("Maske_"):
		var vide := Control.new()
		vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vide.size = Vector2(1, 1)
		return vide

	if classe.contains("IconButton") or classe.begins_with("icon"):
		var empile_a := _pile(classe)
		if empile_a != null:
			return empile_a
		var tex := _icone(classe)
		if tex == null:
			return _image(null, Vector2(24, 24))
		return _pose(tex, _decalage_icone(classe))

	# Beaucoup de `Visual_Button_*` sont en fait des icônes (le « i » d'info, les
	# flèches…) : on les pose en image si la table en connaît une.
	if classe.contains("Visual_Button") or classe.contains("Textbutton"):
		var empile_b := _pile(classe)
		if empile_b != null:
			return empile_b
		var ti := _icone(classe)
		if ti != null:
			return _pose(ti, _decalage_icone(classe))
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		b.size = Vector2(110, 26)
		return b

	# Dernier recours, sur demande : la table classe -> image. Beaucoup de classes
	# ne sont ni bouton ni champ — planches de fond, plaques, pavillons, boutons
	# RONDS — et tombaient toutes dans le Control vide ci-dessous : elles ne
	# dessinaient rien, table d'icônes réparée ou pas. Leur NOM ne dit pas
	# qu'elles portent une image ; seule la table le sait. C'est ce qui privait le
	# HUD de sa planche de bois et de ses boutons ronds, `Visual_RoundButton_*` ne
	# contenant pas la chaîne « Visual_Button ».
	if repli:
		# D'abord les caractères ANONYMES : « charNNN » ne dit rien par son nom,
		# mais la table du .swf sait à quel bitmap il mène. Sous les planches du
		# HUD ils sont la majorité — minimap, fond de planche droite et bandeau
		# de ville tiennent presque entièrement à eux.
		var anonyme := _caractere(swf, classe)
		if anonyme != null:
			return _pose(anonyme, _decalage_caractere(swf, classe))

		# Puis l'empilement : c'est par ici que passent les boutons RONDS, dont le
		# nom ne contient pas « Visual_Button ».
		var empile_c := _pile(classe)
		if empile_c != null:
			return empile_c

		var reste := _icone(classe)
		if reste != null:
			return _pose(reste, _decalage_icone(classe))

	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(1, 1)
	return c


# --- construction d'un écran ---------------------------------------------------

# Ce que PR3 REMPLIT AU RUNTIME et qu'il ne faut donc jamais rejouer depuis
# l'agencement : dans le .swf, tous les membres de ces collections sont empilés
# au même point d'auteur, et le jeu les replace ensuite lui-même.
#
# Composer la planche droite à la main l'a montré sans appel : les 60 villes de
# `Minimap_Steadte_Liste_14` sortaient en un bloc de losanges bleus flottant
# HORS du cadre, toutes au même endroit. Même cause pour les trois créneaux
# d'événement du bandeau de ville, qui affichaient trois fois la même icône.
#
# Ces nœuds existent quand même, vides et nommés : c'est la simulation qui les
# peuplera (convois, villes, batailles), chacun à sa place sur la carte.
const RUNTIME := [
	"Minimap_Steadte_Liste_14",   # les 60 villes de la minimap
	"Visual_Minimap_Frame",       # les tracés de route, les navires, la vue
	"Visual_Minimap_Mc_Objects",  # les batailles navales
	"Visual_CustomRender",        # un rendu 3D temps réel dans PR3
	"Visual_CustomRender_Minimap",
	"Visual_TooltipContainer",    # les infobulles, posées au survol
]


# Faut-il descendre dans ce conteneur ? Non s'il est rempli au runtime, non si
# c'est un masque — de la géométrie qui découpe, jamais de l'art.
static func _rejouable(classe: String) -> bool:
	var court := classe.get_slice(".", classe.get_slice_count(".") - 1)
	if RUNTIME.has(court):
		return false
	return not (court.contains("Mask_") or court.contains("Maske_"))

# Bâtit la page `scene` du fichier `swf` : rend un Control dont chaque enfant
# porte le nom d'instance de PR3, posé à ses coordonnées d'origine.
#
# `repli` se transmet à `_noeud()` : à ouvrir pour un écran dont on a vérifié À
# L'ŒIL que la table lui rend les bonnes images, jamais par défaut.
static func batir(swf: String, scene: String, repli := false,
		profondeur := 0) -> Control:
	var racine := Control.new()
	racine.name = scene.get_slice(".", scene.get_slice_count(".") - 1)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var ecrans: Dictionary = agencement(swf).get("ecrans", {})
	if not ecrans.has(scene):
		return racine

	for el in (ecrans[scene] as Array):
		var d: Dictionary = el
		if str(d.get("type", "")) == "texte":
			continue
		# Les IMAGES > 0 d'un sprite sont ses ÉTATS ALTERNATIFS — un bouton
		# survolé, pressé, désactivé ; une planche de rechange. PR3 n'en montre
		# qu'un à la fois, et l'image 0 est l'état par défaut. Les dessiner tous
		# posait `char147`, opaque à 91 %, sur le bandeau de ville qu'elle
		# devait remplacer et non recouvrir.
		if int(d.get("img", 0)) > 0:
			continue
		var classe := str(d.get("classe", ""))
		var n: Control
		# Un CONTENEUR est une classe qui est elle-même une scène du même .swf.
		# `batir` n'en descendait aucun : la planche droite du HUD, faite de son
		# fond, de sa minimap et de sa barre d'XP, sortait en trois Control 1x1.
		if profondeur > 0 and ecrans.has(classe) and _rejouable(classe):
			n = batir(swf, classe, repli, profondeur - 1)
		else:
			n = _noeud(d, repli, swf)
		var nom := str(d.get("nom", ""))
		if nom != "":
			n.name = nom
		# `+=` et non `=` : `_noeud()` a déjà posé le DÉCALAGE de l'art, qu'on
		# décale ici du point de placement.
		n.position += Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
		racine.add_child(n)
	return racine


# Le cadre à onglets de PR3 : bandeau de bois, parchemin répété, culot doré.
static func cadre_tabbed(hauteur := CADRE_HAUTEUR) -> Control:
	var c := Control.new()
	c.name = "cadre"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var culot := SkinPR3.texture(SKIN + str(CADRE["culot"]))
	var h_culot := culot.get_height() if culot != null else 0
	var bandeau := SkinPR3.texture(SKIN + str(CADRE["bandeau"]))
	var h_bandeau := bandeau.get_height() if bandeau != null else 0

	var corps := SkinPR3.texture(SKIN + str(CADRE["corps"]))
	if corps != null:
		var y := h_bandeau
		while y < hauteur - h_culot:
			var tr := TextureRect.new()
			tr.texture = corps
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.position = Vector2(0, y)
			tr.size = Vector2(corps.get_width(), min(corps.get_height(), hauteur - h_culot - y))
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.clip_contents = true
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.add_child(tr)
			y += corps.get_height()

	if culot != null:
		c.add_child(_image(culot, culot.get_size()))
		c.get_child(c.get_child_count() - 1).position = Vector2(0, hauteur - h_culot)

	if bandeau != null:
		c.add_child(_image(bandeau, bandeau.get_size()))
	return c


# Encre des libellés posés sur une plaque d'or.
const ENCRE_BOUTON := Color(0.16, 0.10, 0.05)
const ENCRE_BOUTON_SURVOL := Color(0.10, 0.24, 0.42)


# Arme un bouton : recentre son image sur son point, puis pose par-dessus une
# zone sensible transparente. `batir()` rend des images INERTES, jamais des
# boutons — c'est voulu, une planche n'est pas forcément cliquable.
#
# Le recentrage n'est pas un ajustement à vue. Dans PR3 les boutons sont ancrés
# par leur CENTRE là où les plaques et les champs le sont par leur COIN, et cela
# se DÉDUIT de la mise en page : sur la planche gauche, bu_minus (96,36) occupe
# ainsi 82..110 et bu_plus (167,36) 153..181, de part et d'autre de la plaque
# 112..152 — deux pixels de jeu d'un côté, un de l'autre. Posés par le coin, ils
# la chevaucheraient.
#
# Le LIBELLÉ est porté par le bouton et non par son image : les plaques d'or
# (453.png) sont nues, PR3 pose le glyphe en texte par-dessus. Composer l'art à
# la main l'a montré — sans libellé, « + » et « − » sont deux carrés identiques.
static func bouton(racine: Control, nom: String, libelle := "",
		infobulle := "") -> Button:
	var image := champ(racine, nom)
	if image == null:
		return null
	var taille := image.size
	# PLUS de recentrage à la main ici : le décalage vient désormais de la table,
	# MESURÉ dans le .swf. Le recentrer en plus l'appliquerait deux fois. Le
	# résultat est identique au pixel pour les boutons — leur origine mesurée
	# vaut exactement -taille/2 — mais il vaut maintenant aussi pour tout ce que
	# cette règle ne voyait pas.

	var zone := Button.new()
	zone.flat = true
	zone.focus_mode = Control.FOCUS_NONE
	zone.text = libelle
	zone.tooltip_text = infobulle
	zone.add_theme_font_size_override("font_size", 18)
	# La graisse ORDINAIRE, pas la grasse : les `DefineEditText` de PR3 nomment
	# tous `$RegularFont1`. Rien ne m'autorise à mettre du gras ici tant que je
	# n'ai pas relevé une classe qui déclare l'autre.
	FontePR3.poser(zone)
	zone.add_theme_color_override("font_color", ENCRE_BOUTON)
	zone.add_theme_color_override("font_hover_color", ENCRE_BOUTON_SURVOL)
	zone.add_theme_color_override("font_pressed_color", ENCRE_BOUTON_SURVOL)
	zone.position = image.position
	zone.size = taille
	image.get_parent().add_child(zone)
	return zone


# Retrouve un élément par son nom d'instance PR3 (tf_hp, icon_town, li_trade…).
static func champ(racine: Control, nom: String) -> Control:
	return racine.get_node_or_null(NodePath(nom)) as Control
