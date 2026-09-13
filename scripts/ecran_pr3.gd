# Le constructeur d'écran de Port Royale 3.
#
# Plutôt que de coder chaque interface à la main, on REJOUE l'agencement décodé
# des .swf : `outils/swf_export.py` a exporté les 169 fichiers d'interface de PR3
# en JSON (161 scènes, ~15 900 éléments), chacun portant son nom d'instance, sa
# classe de composant et sa position au pixel. Ce script lit ce JSON et pose les
# nœuds Godot aux mêmes coordonnées, avec l'art extrait du jeu.
#
# Ce qu'on a dû corriger pour y arriver : PR3 instancie ses composants par
# PlaceObject3 « HasClassName » — une chaîne de classe glissée avant le charId.
# Tant qu'on ne la sautait pas, le nom d'instance et la matrice étaient lus au
# mauvais offset, et l'agencement paraissait absent. Il ne l'était pas.
#
# L'art (cadres, icônes) vient de `reference_pr3/`, ignoré par git — sous droits,
# lu au runtime comme les modèles de navires. Absent, l'écran se bâtit quand même
# en aplats : la STRUCTURE ne dépend jamais de l'art.
#
# Conventions de PR3 relevées dans le skin :
#   components.textfield.Visual_Textfeld_NN  -> un texte de NN pixels
#   exports.Text_Bg_Nomal                    -> la plaque sombre sous un chiffre
#   components.button.Visual_IconButton_X    -> une icône (table icones.txt)
#   components.textbutton.*                  -> un bouton à libellé
#
# Usage : `var e := EcranPR3.batir("dialog_shipyard_pc", "exports.Tab_Shipyard_repair")`
# puis `e.champ("tf_hp").text = "…"` pour brancher la simulation sur un champ.
class_name EcranPR3
extends RefCounted

const AGENCEMENT := "res://reference_pr3/ui/agencement/"
const SKIN := "skinlib_pr3/"

# Les quatre bandes du cadre à onglets (Dialog_Tabbed), larges de 430 px.
const CADRE_TABBED := {
	"tete": "757",    # 430x62
	"corps": "753",   # 430x48
	"tuile": "777",   # 430x50
	"pied": "750",    # 430x50 — posé à y=522
}

static var _json: Dictionary = {}
static var _icones: Dictionary = {}


# --- lecture des données décodées --------------------------------------------

static func agencement(swf: String) -> Dictionary:
	if _json.has(swf):
		return _json[swf]
	var doc := {}
	var chemin := ProjectSettings.globalize_path(AGENCEMENT + swf + ".json")
	if FileAccess.file_exists(chemin):
		var brut := FileAccess.get_file_as_string(chemin)
		var lu = JSON.parse_string(brut)
		if lu is Dictionary:
			doc = lu
	_json[swf] = doc
	return doc


# La table classe de composant -> fichier bitmap, extraite du skin partagé.
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


# --- fabrique de nœuds ---------------------------------------------------------

# La taille de police est encodée dans le nom du composant : Visual_Textfeld_22.
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


# Bâtit UN élément selon sa classe de composant PR3.
static func _noeud(el: Dictionary) -> Control:
	var classe := String(el.get("classe", ""))
	var nom := String(el.get("nom", ""))

	if classe.contains("Visual_Textfeld"):
		var l := Label.new()
		l.add_theme_font_size_override("font_size", _taille_police(classe))
		l.add_theme_color_override("font_color", Color(0.93, 0.89, 0.80))
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return l

	if classe.contains("Text_Bg"):
		# La plaque sombre sous un chiffre : 13x20 de base, étirée par l'échelle.
		var p := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.06, 0.04, 0.72)
		sb.border_color = Color(0.42, 0.33, 0.18)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(2)
		if classe.contains("Red"):
			sb.border_color = Color(0.62, 0.22, 0.18)
		p.add_theme_stylebox_override("panel", sb)
		p.custom_minimum_size = Vector2(13.0 * float(el.get("sx", 1.0)), 20.0)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return p

	if classe.contains("IconButton") or classe.begins_with("icon"):
		var t := TextureRect.new()
		t.texture = _icone(classe)
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if t.texture != null:
			t.custom_minimum_size = t.texture.get_size()
		return t

	if classe.contains("Textbutton") or classe.contains("Visual_Button"):
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 15)
		return b

	# Tout le reste : un conteneur nu, qui garde sa place et son nom.
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# --- construction d'un écran ---------------------------------------------------

# Bâtit la page `scene` du fichier `swf` : rend un Control dont chaque enfant
# porte le nom d'instance de PR3, posé à ses coordonnées d'origine.
static func batir(swf: String, scene: String) -> Control:
	var racine := Control.new()
	racine.name = scene.get_slice(".", scene.get_slice_count(".") - 1)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var doc := agencement(swf)
	var ecrans: Dictionary = doc.get("ecrans", {})
	if not ecrans.has(scene):
		return racine

	for el in (ecrans[scene] as Array):
		var d: Dictionary = el
		if String(d.get("type", "")) == "texte":
			continue
		var n := _noeud(d)
		var nom := String(d.get("nom", ""))
		if nom != "":
			n.name = nom
		n.position = Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
		racine.add_child(n)
	return racine


# Le cadre à onglets de PR3, composé de ses quatre bandes peintes (430 px).
static func cadre_tabbed(hauteur := 572) -> Control:
	var c := Control.new()
	c.name = "cadre"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var y := 0
	for cle in ["tete", "corps"]:
		var tex := SkinPR3.texture(SKIN + String(CADRE_TABBED[cle]))
		if tex == null:
			continue
		var tr := TextureRect.new()
		tr.texture = tex
		tr.position = Vector2(0, y)
		c.add_child(tr)
		y += int(tex.get_height())
	# Le corps se répète jusqu'au pied.
	var tuile := SkinPR3.texture(SKIN + String(CADRE_TABBED["tuile"]))
	if tuile != null:
		while y < hauteur - 50:
			var tr2 := TextureRect.new()
			tr2.texture = tuile
			tr2.position = Vector2(0, y)
			c.add_child(tr2)
			y += int(tuile.get_height())
	var pied := SkinPR3.texture(SKIN + String(CADRE_TABBED["pied"]))
	if pied != null:
		var tp := TextureRect.new()
		tp.texture = pied
		tp.position = Vector2(0, hauteur - pied.get_height())
		c.add_child(tp)
	return c


# Retrouve un élément par son nom d'instance PR3 (tf_hp, icon_town, li_trade…).
static func champ(racine: Control, nom: String) -> Control:
	return racine.get_node_or_null(NodePath(nom)) as Control
