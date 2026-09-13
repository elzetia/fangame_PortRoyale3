# L'info-ville de Port Royale 3 : l'onglet `Tab_TownInfo` du dialogue de ville.
#
# Décodage (dialog_trade.swf) : cliquer une ville ouvre `scenes.Scene_Trade`, un
# dialogue à onglets — Tab_TownInfo, Tab_TownGoods, Tab_Equipment, Tab_Trade. La
# « fiche de ville » n'est pas un écran à part : c'est le PREMIER onglet de ce
# dialogue. Son contenu n'est pas posé dans la timeline du .swf mais monté au
# runtime par l'ActionScript (composants Visual_List_Town_Goods,
# Visual_Wealth_Text_Trend, customrenderelement) ; le .swf ne nous livre donc que
# le SKIN et les composants, pas des coordonnées. On reconstruit l'agencement à
# partir du contenu connu de TownInfo et du modèle de données décodé.
#
# Le look vient du skin PR3 (skinlib_pr3) : le cadre est le panneau peint
# `Dialog_Tabbed_Big` (748x578), chargé depuis l'install locale du joueur via
# SkinPR3 — art sous droits, ignoré par git. Absent, on retombe sur un parchemin
# dessiné : le comportement ne dépend jamais de l'art, seul le look en dépend.
#
# Comme dans PR3, ce panneau ne calcule rien : population, prospérité, fabriques
# et occupation viennent de `Sim.etat_ville`, qui les déduit selon les constantes
# de PR3. Il ne décide rien non plus : il émet ce que le joueur demande (voir les
# marchandises), la carte arbitre.
class_name VillePanneau
extends CanvasLayer

signal ferme
signal denrees_demandees(port: Dictionary)

const ICONES := "res://sprites/marchandises/"
const PAVILLONS := "res://sprites/pavillons/"
const POLICE := "res://polices/serif_gras.ttf"

# Taille native du panneau peint de PR3 (Dialog_Tabbed_Big) : on ne l'étire pas,
# ses ornements resteraient nets.
const LARGEUR := 748
const HAUTEUR := 578

# Couleurs relevées sur le parchemin de PR3 : une encre brune chaude sur le crème
# du panneau, l'or des titres, le vert/rouge des tendances.
const ENCRE       := Color(0.24, 0.16, 0.09)
const ENCRE_PALE  := Color(0.46, 0.38, 0.29)
const OR          := Color(0.60, 0.44, 0.16)
const OR_CLAIR    := Color(0.86, 0.71, 0.36)
const VERT        := Color(0.30, 0.52, 0.22)
const ROUGE       := Color(0.72, 0.28, 0.22)
const BOIS        := Color(0.16, 0.11, 0.07)

# Les onglets de Scene_Trade, dans l'ordre du .swf. Seul le premier est la page
# courante ; « Marchandises » renvoie au comptoir, le reste attend son écran.
const ONGLETS := ["Infos ville", "Marchandises", "Équipement", "Commerce"]

var _sim: Object = null
var _port: Dictionary = {}
var _villes: Villes = null
var _convoi_a_quai := false

var _titre: Label
var _pavillon: TextureRect
var _vignette: TextureRect
var _lbl_habitants: Label
var _lbl_prosperite: Label
var _fleche: Label
var _lbl_fabriques: Label
var _lbl_maisons: Label
var _lbl_occupation: Label
var _rang_produits: HBoxContainer
var _onglet_marchandises: Button


func _init() -> void:
	layer = 8


func _ready() -> void:
	visible = false
	_batir()


func poser_villes(table: Villes) -> void:
	_villes = table


func _police() -> Font:
	return load(POLICE) if ResourceLoader.exists(POLICE) else null


func _texte(contenu: String, taille: int, teinte: Color,
			align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = contenu
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", teinte)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var f := _police()
	if f != null:
		l.add_theme_font_override("font", f)
	return l


# --- construction -------------------------------------------------------------

func _batir() -> void:
	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 0.45)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_STOP
	voile.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_fermer())
	add_child(voile)

	# Le cadre : le panneau peint de PR3, à sa taille native, centré. Les marges
	# de contenu rentrent sous le cadre peint ; plus haut en tête pour l'ornement
	# et le nom de la ville, qui vit dans le bandeau du panneau.
	var cadre := PanelContainer.new()
	cadre.set_anchors_preset(Control.PRESET_CENTER)
	cadre.custom_minimum_size = Vector2(LARGEUR, HAUTEUR)
	cadre.position = Vector2(-LARGEUR / 2.0, -HAUTEUR / 2.0)
	var style := SkinPR3.cadre("skinlib_pr3/801")
	if style is StyleBoxTexture:
		style.set_content_margin_all(44)
		style.content_margin_top = 30
		style.content_margin_bottom = 40
	cadre.add_theme_stylebox_override("panel", style)
	cadre.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cadre)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	cadre.add_child(col)

	# Tête : nom de la ville, et le X de fermeture, comme les dialogues de PR3.
	var tete := HBoxContainer.new()
	col.add_child(tete)
	_titre = _texte("", 26, OR.darkened(0.1))
	_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tete.add_child(_titre)
	var fermer_b := Button.new()
	fermer_b.text = "✕"
	fermer_b.flat = true
	fermer_b.add_theme_font_size_override("font_size", 20)
	fermer_b.add_theme_color_override("font_color", ENCRE)
	fermer_b.pressed.connect(_fermer)
	tete.add_child(fermer_b)

	col.add_child(_bande_onglets())

	# Corps : deux colonnes, comme la fiche TownInfo — la vue de la ville à
	# gauche, ses chiffres et ses biens à droite.
	var corps := HBoxContainer.new()
	corps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corps.add_theme_constant_override("separation", 20)
	col.add_child(corps)

	corps.add_child(_colonne_vue())

	var droite := VBoxContainer.new()
	droite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	droite.size_flags_vertical = Control.SIZE_EXPAND_FILL
	droite.add_theme_constant_override("separation", 12)
	corps.add_child(droite)

	droite.add_child(_ligne_prosperite())
	droite.add_child(_ligne_habitants())
	droite.add_child(_separateur())
	droite.add_child(_section_production())

	var pousse := Control.new()
	pousse.size_flags_vertical = Control.SIZE_EXPAND_FILL
	droite.add_child(pousse)

	var pied := _texte("Échap ou clic hors du cadre pour fermer", 12, ENCRE_PALE,
					   HORIZONTAL_ALIGNMENT_CENTER)
	pied.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(pied)


# La bande d'onglets de Scene_Trade. La page courante (Infos ville) est enfoncée
# et inerte ; « Marchandises » mène au comptoir si un convoi est à quai ; les
# autres attendent leur écran.
func _bande_onglets() -> Control:
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 4)
	for i in ONGLETS.size():
		var libelle: String = ONGLETS[i]
		var b := Button.new()
		b.text = libelle
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 34
		b.add_theme_font_size_override("font_size", 15)
		var f := _police()
		if f != null:
			b.add_theme_font_override("font", f)
		var courant := i == 0
		for etat in ["normal", "hover", "pressed", "disabled"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = BOIS if courant else Color(0.30, 0.22, 0.13, 0.65)
			if etat == "hover":
				sb.bg_color = Color(0.34, 0.25, 0.15)
			sb.border_color = OR
			sb.border_width_top = 2
			sb.border_width_left = 2
			sb.border_width_right = 2
			sb.set_corner_radius_all(3)
			sb.content_margin_top = 6
			sb.content_margin_bottom = 6
			b.add_theme_stylebox_override(etat, sb)
		b.add_theme_color_override("font_color", OR_CLAIR if courant else Color(0.78, 0.70, 0.56))
		b.add_theme_color_override("font_hover_color", OR_CLAIR)
		b.add_theme_color_override("font_disabled_color", OR_CLAIR)
		if courant:
			b.disabled = true
		elif libelle == "Marchandises":
			_onglet_marchandises = b
			b.pressed.connect(func() -> void: denrees_demandees.emit(_port))
		else:
			b.disabled = true
			b.tooltip_text = "Pas encore en place"
		ligne.add_child(b)
	return ligne


# La vue de la ville : sa vignette sur le pavillon de sa nation, comme le portrait
# de ville de TownInfo.
func _colonne_vue() -> Control:
	var boite := Control.new()
	boite.custom_minimum_size = Vector2(300, 0)
	boite.size_flags_vertical = Control.SIZE_EXPAND_FILL
	boite.clip_contents = true

	_pavillon = TextureRect.new()
	_pavillon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pavillon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pavillon.modulate = Color(1, 1, 1, 0.55)
	_pavillon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pavillon.set_anchors_preset(Control.PRESET_FULL_RECT)
	boite.add_child(_pavillon)

	_vignette = TextureRect.new()
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.offset_top = 40
	_vignette.offset_bottom = -40
	boite.add_child(_vignette)
	return boite


func _ligne_prosperite() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.add_child(_texte("Prospérité", 18, OR.darkened(0.1)))
	_lbl_prosperite = _texte("", 20, ENCRE)
	_lbl_prosperite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_prosperite.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(_lbl_prosperite)
	_fleche = _texte("", 22, VERT)
	hb.add_child(_fleche)
	return hb


func _ligne_habitants() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.add_child(_texte("Population", 18, OR.darkened(0.1)))
	_lbl_habitants = _texte("", 20, ENCRE)
	_lbl_habitants.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_habitants.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(_lbl_habitants)
	hb.add_child(_texte("hab.", 15, ENCRE_PALE))
	return hb


func _separateur() -> Control:
	var t := ColorRect.new()
	t.color = OR.darkened(0.2)
	t.custom_minimum_size = Vector2(0, 2)
	return t


func _section_production() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.add_child(_texte("Production", 18, OR.darkened(0.1)))

	var chiffres := HBoxContainer.new()
	chiffres.add_theme_constant_override("separation", 0)
	_lbl_fabriques = _texte("", 15, ENCRE)
	_lbl_fabriques.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_maisons = _texte("", 15, ENCRE, HORIZONTAL_ALIGNMENT_CENTER)
	_lbl_maisons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_occupation = _texte("", 15, ENCRE, HORIZONTAL_ALIGNMENT_RIGHT)
	_lbl_occupation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chiffres.add_child(_lbl_fabriques)
	chiffres.add_child(_lbl_maisons)
	chiffres.add_child(_lbl_occupation)
	col.add_child(chiffres)

	_rang_produits = HBoxContainer.new()
	_rang_produits.add_theme_constant_override("separation", 10)
	col.add_child(_rang_produits)
	return col


# --- remplissage --------------------------------------------------------------

func ouvrir(sim_obj: Object, port_dict: Dictionary, convoi_a_quai := false) -> void:
	_sim = sim_obj
	_port = port_dict
	_convoi_a_quai = convoi_a_quai
	visible = true
	rafraichir()


func _fermer() -> void:
	visible = false
	ferme.emit()


func fermer() -> void:
	if visible:
		_fermer()


func rafraichir() -> void:
	if _port.is_empty():
		return

	_titre.text = String(_port.get("nom", "?"))
	if _onglet_marchandises != null:
		_onglet_marchandises.disabled = not _convoi_a_quai
		_onglet_marchandises.tooltip_text = ("Le comptoir de la ville"
			if _convoi_a_quai else "Il faut un convoi à quai pour commercer")

	var habitants := int(_port.get("habitants", 0))
	var tendance := 0
	var fabriques := 0
	var maisons := 0
	var occupation := 0.0
	var prosperite := int(_port.get("prosperite", 0))

	if _sim != null:
		var etat: Dictionary = _sim.etat_ville(String(_port.get("cle", "")))
		if not etat.is_empty():
			habitants = int(etat.get("habitants", habitants))
			tendance = int(etat.get("tendance", 0))
			fabriques = int(etat.get("fabriques", 0))
			maisons = int(etat.get("maisons", 0))
			occupation = float(etat.get("occupation", 0.0))
			prosperite = int(etat.get("prosperite", prosperite))

	_lbl_habitants.text = _nombre(habitants)
	_lbl_prosperite.text = (_nombre(prosperite) if prosperite > 0
		else "occupée à %d %%" % int(round(occupation * 100.0)))
	if tendance > 0:
		_fleche.text = "▲"
		_fleche.add_theme_color_override("font_color", VERT)
	elif tendance < 0:
		_fleche.text = "▼"
		_fleche.add_theme_color_override("font_color", ROUGE)
	else:
		_fleche.text = "—"
		_fleche.add_theme_color_override("font_color", ENCRE_PALE)

	_lbl_fabriques.text = "%d fabriques" % fabriques
	_lbl_maisons.text = "%d maisons" % maisons
	_lbl_occupation.text = "occupées à %d %%" % int(round(occupation * 100.0))

	_poser_vignette(habitants)
	_poser_pavillon()
	_poser_produits()


func _poser_vignette(habitants: int) -> void:
	if _villes == null or _villes.vide():
		return
	_vignette.texture = _villes.texture_pour({"habitants": habitants})


func _poser_pavillon() -> void:
	var cle := String(_port.get("nation_cle", ""))
	var chemin := PAVILLONS + cle + ".png"
	_pavillon.texture = load(chemin) if ResourceLoader.exists(chemin) else null


func _poser_produits() -> void:
	for enfant in _rang_produits.get_children():
		enfant.queue_free()
	for cle in _port.get("produits", []):
		var chemin := ICONES + String(cle) + ".png"
		if not ResourceLoader.exists(chemin):
			continue
		var v := TextureRect.new()
		v.texture = load(chemin)
		v.custom_minimum_size = Vector2(52, 52)
		v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		v.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		v.tooltip_text = String(cle).capitalize()
		_rang_produits.add_child(v)


func _nombre(n: int) -> String:
	var s := str(absi(n))
	var sortie := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		sortie = s[i] + sortie
		c += 1
		if c % 3 == 0 and i > 0:
			sortie = " " + sortie
	return ("-" if n < 0 else "") + sortie


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_fermer()
		get_viewport().set_input_as_handled()
