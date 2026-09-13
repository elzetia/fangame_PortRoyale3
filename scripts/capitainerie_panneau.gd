# La capitainerie d'un port — la gestion des convois de Port Royale 3.
#
# Ouverte par le pétale Capitainerie du menu radial (donc seulement là où l'on a un
# convoi). Elle montre, POUR CE PORT : les convois à quai, et les navires sans convoi
# qui s'y trouvent (achetés, construits, ou débarqués d'un convoi). On y forme un
# convoi des navires libres, on ajoute/retire des navires d'un convoi à quai.
#
# Rien n'est calculé ici : tout vient du pont (compagnie). On filtre juste par port.
class_name CapitaineriePanneau
extends CanvasLayer

signal ferme

const BOIS       := Color(0.16, 0.11, 0.07)
const BOIS_CLAIR := Color(0.26, 0.18, 0.11)
const OR         := Color(0.86, 0.71, 0.36)
const LIN        := Color(0.921, 0.888, 0.812)
const ENCRE      := Color(0.16, 0.11, 0.07)

var _sim: Object
var _port: Dictionary = {}
var _titre: Label
var _liste_libres: ItemList
var _libres: Array = []       # index de ligne -> navire libre (avec indice sim)
var _convois_box: VBoxContainer
var _msg: Label
var _cadre: PanelContainer
var _depuis_maj := 0.0
const INTERVALLE := 0.7


func _ready() -> void:
	layer = 61
	visible = false
	_construire()


func _process(delta: float) -> void:
	if not visible or _sim == null:
		return
	_depuis_maj += delta
	if _depuis_maj < INTERVALLE:
		return
	if _cadre != null and _cadre.get_global_rect().has_point(get_viewport().get_mouse_position()):
		return
	_depuis_maj = 0.0
	rafraichir()


func ouvrir(sim_obj: Object, port: Dictionary) -> void:
	_sim = sim_obj
	_port = port
	rafraichir()
	visible = true


func fermer() -> void:
	visible = false
	ferme.emit()


func _label(txt: String, taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	return l


func _construire() -> void:
	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 0.55)
	voile.anchor_right = 1.0
	voile.anchor_bottom = 1.0
	voile.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			fermer())
	add_child(voile)

	var cadre := PanelContainer.new()
	cadre.set_anchors_preset(Control.PRESET_CENTER)
	cadre.custom_minimum_size = Vector2(780, 620)
	cadre.position = Vector2(-390, -310)
	var style := StyleBoxFlat.new()
	style.bg_color = LIN
	style.border_color = BOIS
	style.set_border_width_all(6)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(16)
	cadre.add_theme_stylebox_override("panel", style)
	cadre.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cadre)
	_cadre = cadre

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	cadre.add_child(col)

	var titre_ligne := HBoxContainer.new()
	col.add_child(titre_ligne)
	_titre = _label("Capitainerie", 26, BOIS)
	_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titre_ligne.add_child(_titre)
	var fermer_b := Button.new()
	fermer_b.text = "Fermer"
	fermer_b.pressed.connect(fermer)
	titre_ligne.add_child(fermer_b)

	var deux := HBoxContainer.new()
	deux.add_theme_constant_override("separation", 16)
	deux.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(deux)

	# --- gauche : navires sans convoi, ici -----------------------------------
	var gauche := VBoxContainer.new()
	gauche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gauche.add_theme_constant_override("separation", 6)
	deux.add_child(gauche)
	gauche.add_child(_label("Navires sans convoi, à ce quai", 16, BOIS_CLAIR))
	_liste_libres = ItemList.new()
	_liste_libres.select_mode = ItemList.SELECT_MULTI
	_liste_libres.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gauche.add_child(_liste_libres)
	var former_b := Button.new()
	former_b.text = "Former un convoi des navires cochés"
	former_b.pressed.connect(_former_convoi)
	gauche.add_child(former_b)

	# --- droite : convois à quai ---------------------------------------------
	var droite := VBoxContainer.new()
	droite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	droite.add_theme_constant_override("separation", 6)
	deux.add_child(droite)
	droite.add_child(_label("Convois à quai ici", 16, BOIS_CLAIR))
	var defil := ScrollContainer.new()
	defil.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	droite.add_child(defil)
	_convois_box = VBoxContainer.new()
	_convois_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_convois_box.add_theme_constant_override("separation", 6)
	defil.add_child(_convois_box)

	_msg = _label("", 13, Color(0.5, 0.1, 0.1))
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(_msg)


func _cle_port() -> String:
	return String(_port.get("cle", ""))


func rafraichir() -> void:
	if _sim == null or _liste_libres == null:
		return
	_titre.text = "Capitainerie de %s" % String(_port.get("nom", "?"))
	var ici := _cle_port()

	# Les navires libres à CE port.
	var garde := _liste_libres.get_selected_items()
	_libres = []
	for s in _sim.flotte():
		if String(s.get("attache", "")) == ici:
			_libres.append(s)
	_liste_libres.clear()
	for s in _libres:
		_liste_libres.add_item("%s — %s, %d t" % [
			String(s.get("nom", "?")), String(s.get("type", "?")), int(s.get("cale", 0))])
	for i in garde:
		if i < _liste_libres.item_count:
			_liste_libres.select(i, false)

	# Les convois à quai ici.
	for e in _convois_box.get_children():
		e.queue_free()
	var n := 0
	for r in _sim.routes():
		if String(r.get("ville", "")) == ici:
			_convois_box.add_child(_ligne_convoi(r))
			n += 1
	if n == 0:
		_convois_box.add_child(_label("Aucun convoi à quai ici.", 13, ENCRE))


func _ligne_convoi(r: Dictionary) -> Control:
	var fond := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(1, 1, 1, 0.35)
	st.border_color = BOIS_CLAIR
	st.set_border_width_all(1)
	st.set_content_margin_all(8)
	fond.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	fond.add_child(v)

	var indice := int(r.get("indice", 0))
	var titre := "%s  (%s)" % [String(r.get("nom", "?")), String(r.get("mode", "route"))]
	v.add_child(_label(titre, 15, BOIS))
	v.add_child(_label("cale %d/%d · %s" % [
		int(r.get("charge", 0)), int(r.get("capacite", 0)),
		String(r.get("cargaison", "sur lest"))], 12, ENCRE))

	# Les navires du convoi, chacun retirable (il revient au quai).
	var noms: Array = r.get("navires_noms", [])
	var quai := FlowContainer.new()
	quai.add_theme_constant_override("h_separation", 4)
	quai.add_theme_constant_override("v_separation", 4)
	v.add_child(quai)
	for k in noms.size():
		var chip := Button.new()
		chip.text = "%s  ✕" % String(noms[k])
		chip.add_theme_font_size_override("font_size", 11)
		var pos := k + 1
		chip.pressed.connect(func() -> void:
			_sim.retirer_navire_convoi(indice, pos)
			rafraichir())
		quai.add_child(chip)

	var ajouter := Button.new()
	ajouter.text = "+ Ajouter les navires cochés"
	ajouter.add_theme_font_size_override("font_size", 12)
	ajouter.pressed.connect(func() -> void:
		var sel := _indices_coches()
		if sel.is_empty():
			_erreur("Coche des navires à gauche.")
			return
		var res: Dictionary = _sim.ajouter_navire_convoi(indice, sel)
		if not bool(res.get("ok", false)):
			_erreur(String(res.get("message", "Échec.")))
		rafraichir())
	v.add_child(ajouter)
	return fond


func _indices_coches() -> Array:
	var sel: Array = []
	for i in _liste_libres.get_selected_items():
		sel.append(int(_libres[i].get("indice", 0)))
	return sel


func _former_convoi() -> void:
	if _sim == null:
		return
	var sel := _indices_coches()
	if sel.is_empty():
		_erreur("Coche au moins un navire.")
		return
	var res: Dictionary = _sim.creer_convoi(sel, _cle_port())
	if bool(res.get("ok", false)):
		_msg.add_theme_color_override("font_color", Color(0.1, 0.4, 0.1))
		_msg.text = "Convoi formé — sélectionne-le sur la carte pour le commander."
		rafraichir()
	else:
		_erreur(String(res.get("message", "Échec.")))


func _erreur(txt: String) -> void:
	_msg.add_theme_color_override("font_color", Color(0.5, 0.1, 0.1))
	_msg.text = txt
