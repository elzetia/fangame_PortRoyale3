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
				_icones[bouts[0].strip_edges()] = bouts[1].strip_edges()
	return _icones


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
static func _noeud(el: Dictionary) -> Control:
	var classe := str(el.get("classe", ""))
	var sx := float(el.get("sx", 1.0))
	var sy := float(el.get("sy", 1.0))

	if classe.contains("Visual_Textfeld"):
		var l := Label.new()
		l.add_theme_font_size_override("font_size", _taille_police(classe))
		l.add_theme_color_override("font_color", Color(0.19, 0.13, 0.07))
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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

	# `Visual_Button_Empty` est une zone de clic invisible dans PR3 : la rendre
	# en bouton posait un rectangle gris fantôme sous l'action.
	if classe.contains("Visual_Button_Empty") or classe.contains("Button_Mask"):
		var vide := Control.new()
		vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vide.size = Vector2(1, 1)
		return vide

	if classe.contains("IconButton") or classe.begins_with("icon"):
		var tex := _icone(classe)
		return _image(tex, tex.get_size() if tex != null else Vector2(24, 24))

	# Beaucoup de `Visual_Button_*` sont en fait des icônes (le « i » d'info, les
	# flèches…) : on les pose en image si la table en connaît une.
	if classe.contains("Visual_Button") or classe.contains("Textbutton"):
		var ti := _icone(classe)
		if ti != null:
			return _image(ti, ti.get_size())
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		b.size = Vector2(110, 26)
		return b

	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(1, 1)
	return c


# --- construction d'un écran ---------------------------------------------------

# Bâtit la page `scene` du fichier `swf` : rend un Control dont chaque enfant
# porte le nom d'instance de PR3, posé à ses coordonnées d'origine.
static func batir(swf: String, scene: String) -> Control:
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
		var n := _noeud(d)
		var nom := str(d.get("nom", ""))
		if nom != "":
			n.name = nom
		n.position = Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
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


# Retrouve un élément par son nom d'instance PR3 (tf_hp, icon_town, li_trade…).
static func champ(racine: Control, nom: String) -> Control:
	return racine.get_node_or_null(NodePath(nom)) as Control
