# La planche de droite du HUD de Port Royale 3 — la minimap et la bourse.
#
# `Hud_pc_fla.Hud_Woodboard_Right_3` (hud_pc.swf), rejouée. Elle ne tient debout
# que grâce à deux choses acquises juste avant elle :
#
#  1. la TABLE DES CARACTÈRES ANONYMES (`outils/swf_caracteres.py`) : le cadre
#     (char172), la carte des mers (char14) et la barre d'XP (char62, char68)
#     n'ont aucun nom de classe. Sans cette table, la planche était nue ;
#  2. la RÉCURSION dans les conteneurs : le fond, la minimap et la barre d'XP
#     sont des sprites imbriqués, que `batir()` rendait en Control 1x1.
#
# ANCRAGE : tous les enfants ont un x NÉGATIF (-207 à -27). Cette planche est
# donc conçue ancrée par son BORD DROIT — et c'est ainsi qu'on la pose, ancrée
# en haut à droite, ses enfants gardant leurs coordonnées d'origine.
#
# CE QUI RESTE VIDE, ET POURQUOI. PR3 remplit au runtime la liste des 60 villes
# (`Minimap_Steadte_Liste_14`), les tracés de route, les navires et le cadre de
# vue (`Visual_Minimap_Frame`), et les batailles (`Visual_Minimap_Mc_Objects`).
# Dans le .swf, TOUS les membres de ces collections sont empilés au même point
# d'auteur : composer la planche à la main les faisait sortir en un bloc de
# losanges bleus flottant hors du cadre. `EcranPR3.RUNTIME` les écarte donc ;
# leurs nœuds existent, nommés et vides, et c'est à la simulation de les peupler
# — chaque ville à sa place sur la carte, ce qui reste à faire.
#
# `tf_rang` porte le RANG, et l'échelle notée ici était FAUSSE : « Krämer…
# Patrizier » est celle de Patrician et de Port Royale 2. Celle de PR3 est
# NAVALE et compte dix-huit échelons, de Mousse à Maître des mers — vérifié deux
# fois, par la table de textes du jeu (`ID_RANK_MALE_00`…`_17`) et par les titres
# de dix-neuf parties réelles, qui vont de « Mousse_Steven » à « Amiral_Elzetia ».
#
# Le nom affiché n'est donc pas inventé : il vient de la table du jeu. Le NUMÉRO
# vient de la sim, qui le garde comme PR3 — un octet de 0 à 17. Ce que la sim ne
# sait pas encore, c'est FAIRE MONTER ce numéro : les seuils de PR3 sont
# introuvables dans le jeu livré (voir `sim/compagnie.lua`). Le champ affiche
# donc « Mousse », ce qu'affiche aussi PR3 pour une compagnie neuve.
class_name HudDroitePR3
extends Control

signal liste_demandee
signal journal_demande
signal carte_basculee
# Dans PR3 chaque emplacement de ville est un `Visual_Button_Minimap_Town` : la
# minimap se CLIQUE. On rend donc la clé du port, et la carte se recentre.
signal ville_choisie(cle: String)

const SWF := "hud_pc"
const PLANCHE := "Hud_pc_fla.Hud_Woodboard_Right_3"
# Assez pour descendre fond > minimap > masque et barre d'XP > jauge.
const PROFONDEUR := 4

# Le cadre (char172) commence à -207 et la planche descend jusqu'à 273.
const TAILLE := Vector2(207, 275)

# L'encre de l'or et du rang. PR3 déclare ses 25 champs texte en NOIR
# (#000000) et les teinte au runtime : la couleur visible n'est pas dans le
# champ mais dans une CONSTANTE NOMMÉE, `ID_GUI_DEF_COLOR_DARK_BG` — « le texte
# posé sur fond sombre » —, qui vaut 0xFFFFFF. Du blanc pur.
#
# Je l'avais d'abord relevée à l'œil sur une capture (0,96 / 0,94 / 0,89) faute
# de savoir la lire ; la constante du jeu prime sur mon estimation.
const ENCRE := Color(1.0, 1.0, 1.0)
# L'or pâle des titres et sous-titres, si jamais l'or de la bourse s'en sert :
# `ID_GUI_DEF_COLOR_TITLE` = 0xFFE59E.
const OR_TITRE := Color(1.0, 0.898, 0.62)

# PR3 sépare les milliers par un POINT : « 1.480.445 ». On affichait une espace.
const SEPARATEUR := "."

# --- la minimap ---------------------------------------------------------------
#
# Le nœud `towns` est posé en (-200,59), c'est-à-dire EXACTEMENT sur la carte des
# mers : son repère local est donc le pixel de minimap, sans conversion.
const MINIMAP := Vector2(196, 156)

# Le cadrage de 12.png par rapport à la grande carte. MESURÉ, pas deviné, par
# `outils/test_minimap.gd` : on projette les soixante ports et on regarde à
# quelle distance du littoral ils tombent.
#   sans cadrage : 31 ports à 1 px ou moins, 11 au-delà de 4 px, aucun hors cadre
#   avec         : 48 à 1 px ou moins, AUCUN au-delà de 4, aucun hors cadre
# La moyenne passe de 2,7 px à 0,6 px. Les échecs sans cadrage sont groupés —
# le golfe du Mexique, puis tout l'arc des Petites Antilles — donc systématiques.
#
# CES QUATRE NOMBRES DÉPENDENT DE LA PROJECTION DE LA GRANDE CARTE, et ils ont
# déjà été refaits DEUX FOIS pour cette raison :
#
#   1. quand le décor est passé de l'illustration à la carte de Port Royale 3
#      (`vue_taille` 15840 x 10392 -> 17280 x 11940). Les valeurs d'avant
#      (1,070 / 0,020 / 0,930 / 0,025) laissaient la moyenne à 2,1 px et onze
#      ports au-delà de 4 ;
#   2. quand le masque de navigation a été recalé sur le relief de PR3
#      (`outils/caler_masque.py` : accord 83,20 % -> 88,97 %). La fiche y a pris
#      un centre non nul et `vue_taille.y` a perdu 3,55 %. SEUL L'AXE V BOUGE,
#      1,090 / 0,030 -> 1,040 / 0,010, et c'est cohérent : ce recalage-là était
#      vertical (+34,7 px) et quasi nul en x (-3,6 px).
#
# Si la fiche de projection rebouge encore, relire ce que `outils/test_minimap.gd`
# propose sous « MEILLEUR ajustement » et réécrire ces quatre lignes. Le test les
# cherche pour ça, et il dit quand le code livré cesse de les reproduire — c'est
# exactement ainsi que la deuxième reprise a été détectée.
const CADRAGE_KU := 1.170
const CADRAGE_DU := 0.020
const CADRAGE_KV := 1.040
const CADRAGE_DV := 0.010

# Les marqueurs de PR3, tous en 8x8 centrés sur leur point.
const PASTILLE := Vector2(8, 8)
const PASTILLE_VILLE := "hud_pc/24"      # une ville
const PASTILLE_CONVOI := "hud_pc/38"     # un convoi à quai

# Un convoi EN MER n'a pas de bitmap dans le .swf : PR3 le trace au runtime
# (`Visual_Minimap_Frame` ne mène à aucune image). On pose donc un point d'or,
# et c'est la seule chose ici qui ne vienne pas de l'art du jeu.
const OR_CONVOI := Color(0.98, 0.82, 0.35)
const OR_CHOISI := Color(1.0, 0.97, 0.80)

# Le cadre de vue — où regarde la caméra. Comme les convois en mer, PR3 le trace
# au runtime : `Visual_Minimap_Frame` ne mène à aucun bitmap. Il est donc dessiné
# et non extrait, et c'est assumé.
const CADRE_VUE := Color(1.0, 0.95, 0.78, 0.85)
const CADRE_EPAISSEUR := 1.0

# Le tracé de route, lui aussi dessiné et non extrait. Plus pâle que la pastille
# d'or du convoi : c'est son chemin, pas lui.
const TRACE_ROUTE := Color(0.98, 0.86, 0.48, 0.70)
# La route des AUTRES convois : le même ton, simplement plus effacé. C'est la
# distinction que `poser_convois` fait déjà entre `OR_CHOISI` et `OR_CONVOI`,
# reprise telle quelle plutôt qu'une teinte inventée pour l'occasion.
const TRACE_ROUTE_AUTRE := Color(0.98, 0.86, 0.48, 0.30)
const TRACE_EPAISSEUR := 1.0

# La pièce d'or accolée au nombre (`ID_FORMATTER_ICON_GOLD`).
const PIECE := "skinlib_pr3/1826"
const PIECE_TAILLE := Vector2(12, 12)
const ECART_PIECE := 3.0

var _piece: TextureRect = null
var _villes_posees := false
# Les quatre bords du cadre de vue, gardés d'une image à l'autre : les recréer à
# chaque rafraîchissement ferait soixante allocations par seconde pour rien.
var _vue: Array[ColorRect] = []
# Les tracés de route, gardés d'une image à l'autre comme les bords du cadre :
# un par convoi en route, réutilisé plutôt que recréé.
var _traces: Array[Line2D] = []

var _plateau: Control
var _or: Label
var _rang: Label
var _en_mer: Label
var _a_quai: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = TAILLE
	size = TAILLE

	_plateau = EcranPR3.batir(SWF, PLANCHE, true, PROFONDEUR)
	add_child(_plateau)

	_or = EcranPR3.champ(_plateau, "tf_gold") as Label
	_rang = EcranPR3.champ(_plateau, "tf_rang") as Label
	_en_mer = EcranPR3.champ(_plateau, "tf_on_sea") as Label
	_a_quai = EcranPR3.champ(_plateau, "tf_anchor") as Label
	# L'or et le rang sont posés sur le bois, pas sur une plaque claire : encre
	# pâle. Les deux compteurs, eux, ont leur plaque `Text_Bg_Nomal`.
	for clair in [_or, _rang]:
		if clair != null:
			clair.add_theme_color_override("font_color", ENCRE)
			# CENTRÉS, contre ce que le fichier déclare. `EcranPR3` applique
			# l'alignement du `DefineEditText`, qui dit « gauche » — mais la
			# capture du jeu montre « 1.480.445 » et « Matelot », de longueurs
			# différentes, partageant leur AXE et non leur bord gauche. PR3
			# surcharge donc l'alignement au runtime pour ces deux champs, comme
			# il surcharge la couleur. La valeur déclarée reste la règle
			# ailleurs ; ceci est une exception constatée, pas un abandon.
			clair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Les infobulles DU JEU. Leurs clés ne vivent que dans le bytecode des .swf,
	# que la table de localisation ne fouillait pas : d'où mes libellés écrits à
	# la main jusqu'ici. PR3 dit « Convois & villes » et « Journal ».
	_armer("bu_liste",
		LocaPR3.propre("ID_GUI_TT_VISUAL_ROUNDBUTTON_CONVOILIST", "Convois"),
		func() -> void: liste_demandee.emit())
	_armer("bu_logbook", LocaPR3.propre("ID_GUI_TT_ICON_LOG", "Journal"),
		func() -> void: journal_demande.emit())
	# `bu_switch` n'a pas d'infobulle dans le bytecode : on garde la nôtre.
	_armer("bu_switch", "Changer de carte", func() -> void: carte_basculee.emit())
	# `bu_anchor` et `bu_on_sea` filtrent la liste des convois dans PR3. Sans
	# écran de liste, les brancher ne ferait rien : on les laisse inertes plutôt
	# que d'émettre un signal que personne n'écoute.


func _armer(nom: String, infobulle: String, geste: Callable) -> void:
	var zone := EcranPR3.bouton(_plateau, nom, "", infobulle)
	if zone != null:
		zone.pressed.connect(geste)


# Sépare les milliers comme PR3 : « 1.480.445 », au POINT. On mettait une espace.
static func nombre(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = SEPARATEUR + out
	return ("-" if n < 0 else "") + out


# Monde -> pixel de la minimap, EN PASSANT PAR la projection de la grande carte.
# On ne réécrit pas une seconde projection : la minimap et la carte doivent
# s'accorder, et deux sources finiraient par diverger.
func _vers_minimap(proj: ProjectionCarte, x: float, z: float) -> Vector2:
	return _carte_vers_minimap(proj, proj.vers_carte(x, z))


# Pixel de la GRANDE carte -> pixel de la minimap. La caméra se repère déjà en
# pixels de carte : elle n'a donc pas à repasser par le monde pour revenir ici.
func _carte_vers_minimap(proj: ProjectionCarte, pix: Vector2) -> Vector2:
	var u := 0.5 + (pix.x / float(proj.pixels.x) - 0.5) * CADRAGE_KU + CADRAGE_DU
	var v := 0.5 + (pix.y / float(proj.pixels.y) - 0.5) * CADRAGE_KV + CADRAGE_DV
	return Vector2(u * MINIMAP.x, v * MINIMAP.y)


func _pastille(hote: Control, cle: String, centre: Vector2) -> void:
	var tex := SkinPR3.texture(cle)
	if tex == null:
		return
	var m := TextureRect.new()
	m.texture = tex
	m.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	m.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.size = PASTILLE
	m.position = centre - PASTILLE * 0.5
	hote.add_child(m)


# Les soixante villes. Elles ne bougent jamais : on les pose une seule fois.
#
# PR3 distingue la ville ordinaire (24.png) du comptoir du joueur (31.png). On
# n'utilise que la première : le pont n'expose pas encore de drapeau « comptoir »,
# et je ne vais pas deviner lesquelles le sont.
func poser_villes(ports: Array, proj: ProjectionCarte) -> void:
	if _villes_posees or proj == null or not proj.valide:
		return
	var hote := EcranPR3.champ(_plateau, "towns")
	if hote == null:
		return
	for e in hote.get_children():
		e.queue_free()
	for p in ports:
		var d: Dictionary = p
		var rade: Vector3 = d["rade"]
		var point := _vers_minimap(proj, rade.x, rade.z)
		_pastille(hote, PASTILLE_VILLE, point)
		# La zone sensible, au même point que le marqueur : PR3 fait de chaque
		# ville un bouton, et une minimap qu'on ne peut pas cliquer n'est qu'une
		# illustration.
		var zone := Button.new()
		zone.flat = true
		zone.focus_mode = Control.FOCUS_NONE
		zone.tooltip_text = str(d.get("nom", ""))
		zone.size = PASTILLE
		zone.position = point - PASTILLE * 0.5
		var cle := str(d.get("cle", ""))
		zone.pressed.connect(func() -> void: ville_choisie.emit(cle))
		hote.add_child(zone)
	_villes_posees = true


# Les convois du joueur, relus à chaque image : ceux-là bougent.
func poser_convois(convois: Array, proj: ProjectionCarte) -> void:
	if proj == null or not proj.valide:
		return
	var hote := EcranPR3.champ(_plateau, "minimap_ships")
	if hote == null:
		return
	for e in hote.get_children():
		e.queue_free()
	for c in convois:
		var d: Dictionary = c
		var pos: Vector2 = d.get("position", Vector2.ZERO)
		var point := _vers_minimap(proj, pos.x, pos.y)
		if bool(d.get("a_quai", false)):
			_pastille(hote, PASTILLE_CONVOI, point)
			continue
		var r := ColorRect.new()
		r.color = OR_CHOISI if bool(d.get("selectionne", false)) else OR_CONVOI
		r.size = Vector2(3, 3)
		r.position = point - Vector2(1.5, 1.5)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hote.add_child(r)


# Les routes des convois : les points de passage qu'ils suivent RÉELLEMENT.
#
# Ils viennent de la simulation (`convois_joueur().route`, c'est-à-dire `m.route`
# de `sim/marchands.lua`) et ne sont pas recalculés ici. La tentation était de
# refaire le chemin avec `sim.route(position, destination)` : cela aurait donné
# un tracé plausible, mais pas celui que le convoi navigue.
#
# TOUS les convois, et non le seul convoi choisi. La planche posait déjà la
# pastille de chacun tout en ne traçant qu'une route : un joueur qui arme trois
# routes n'en voyait qu'une, et rien ne le lui disait. Le convoi choisi garde le
# tracé franc, les autres le même ton en retrait.
#
# Chaque tracé part de la POSITION COURANTE de son convoi, sans quoi il
# commencerait au prochain point de passage et flotterait devant sa pastille.
func poser_routes(convois: Array, proj: ProjectionCarte) -> void:
	if proj == null or not proj.valide:
		return
	var hote := EcranPR3.champ(_plateau, "minimap_route")
	if hote == null:
		return

	var pose := 0
	for c in convois:
		var d: Dictionary = c
		var points: Array = d.get("route", [])
		# Route vide = convoi à quai : rien à tracer, et pas de `Line2D` gâchée.
		if points.is_empty():
			continue
		while _traces.size() <= pose:
			var neuve := Line2D.new()
			neuve.width = TRACE_EPAISSEUR
			neuve.joint_mode = Line2D.LINE_JOINT_ROUND
			neuve.begin_cap_mode = Line2D.LINE_CAP_ROUND
			neuve.end_cap_mode = Line2D.LINE_CAP_ROUND
			hote.add_child(neuve)
			_traces.append(neuve)
		var ligne := _traces[pose]
		var depart: Vector2 = d.get("position", Vector2.ZERO)
		var pts := PackedVector2Array()
		pts.append(_vers_minimap(proj, depart.x, depart.y))
		for p in points:
			var w: Vector2 = p
			pts.append(_vers_minimap(proj, w.x, w.y))
		ligne.points = pts
		ligne.default_color = (TRACE_ROUTE if bool(d.get("selectionne", false))
			else TRACE_ROUTE_AUTRE)
		pose += 1

	# Les tracés en trop sont VIDÉS, pas libérés : un convoi qui accoste laisse sa
	# ligne prête pour le prochain qui appareille. `Line2D` ne dessine rien sous
	# deux points, donc une ligne vidée disparaît vraiment.
	while pose < _traces.size():
		_traces[pose].points = PackedVector2Array()
		pose += 1


# Le cadre de vue : ce que la caméra montre, reporté sur la minimap. `vue` est
# donné en PIXELS DE LA GRANDE CARTE, le repère où vit déjà la caméra.
func poser_vue(proj: ProjectionCarte, vue: Rect2) -> void:
	if proj == null or not proj.valide:
		return
	var hote := EcranPR3.champ(_plateau, "minimap_view")
	if hote == null:
		return
	if _vue.is_empty():
		for i in range(4):
			var bord := ColorRect.new()
			bord.color = CADRE_VUE
			bord.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hote.add_child(bord)
			_vue.append(bord)

	var a := _carte_vers_minimap(proj, vue.position)
	var b := _carte_vers_minimap(proj, vue.position + vue.size)
	# Borné au cadre : au dézoom maximal la vue déborde la carte, et un cadre qui
	# dépasse irait peindre sur le bois de la planche.
	var r := Rect2(a, b - a).abs().intersection(Rect2(Vector2.ZERO, MINIMAP))
	var e := CADRE_EPAISSEUR
	_vue[0].position = r.position
	_vue[0].size = Vector2(r.size.x, e)
	_vue[1].position = r.position + Vector2(0.0, r.size.y - e)
	_vue[1].size = Vector2(r.size.x, e)
	_vue[2].position = r.position
	_vue[2].size = Vector2(e, r.size.y)
	_vue[3].position = r.position + Vector2(r.size.x - e, 0.0)
	_vue[3].size = Vector2(e, r.size.y)


# La PIÈCE d'or, collée au nombre. PR3 ne la pose pas dans l'agencement : son
# formateur la colle au texte, `ID_FORMATTER_ICON_GOLD` valant
# « %1&nbsp;<img src='Window_Trade_Icon_Goldcoin.png'> ». D'où son absence de la
# planche, que j'avais d'abord prise pour un élément dessiné au runtime.
#
# L'asset est `Window_Trade_Icon_Goldcoin.png` = skinlib_pr3/1826, en 12x12.
func _placer_piece() -> void:
	if _or == null:
		return
	if _piece == null:
		var tex := SkinPR3.texture(PIECE)
		if tex == null:
			return
		_piece = TextureRect.new()
		_piece.texture = tex
		_piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_piece.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_piece.size = PIECE_TAILLE
		_or.get_parent().add_child(_piece)

	# Le champ est CENTRÉ : la pièce se pose donc au bord droit du texte rendu,
	# pas au bord du champ — sinon elle flotterait loin du nombre.
	var police := _or.get_theme_font("font")
	var corps := _or.get_theme_font_size("font_size")
	var large := 0.0
	if police != null:
		large = police.get_string_size(_or.text, HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, corps).x
	var centre := _or.position.x + _or.size.x * 0.5
	_piece.position = Vector2(centre + large * 0.5 + ECART_PIECE,
		_or.position.y + (_or.size.y - PIECE_TAILLE.y) * 0.5)


# Le nom du rang, pris dans la table du jeu. Un `rang` négatif veut dire
# « inconnu » : on laisse le champ vide plutôt que d'afficher un échelon qu'on
# n'a pas.
func _nom_rang(rang: int) -> String:
	if rang < 0:
		return ""
	var cle := "ID_RANK_MALE_%02d" % clampi(rang, 0, 17)
	# `LocaPR3` RÉÉMET LA CLÉ quand la table manque : sans ce test, le HUD
	# afficherait « ID_RANK_MALE_02 » en toutes lettres sur le bois.
	var nom := LocaPR3.propre(cle, "")
	return "" if nom == cle else nom


func poser(or_: int, en_mer: int, a_quai: int, rang := -1) -> void:
	if _or != null:
		_or.text = nombre(or_)
		_placer_piece()
	if _rang != null:
		_rang.text = _nom_rang(rang)
	if _en_mer != null:
		_en_mer.text = str(en_mer)
	if _a_quai != null:
		_a_quai.text = str(a_quai)
