# Le bureau du port — l'écran de ville tabulé de Port Royale 3.
#
# Reconstruit d'après la structure DÉCODÉE de PR3 (`Scene_Convoy_Town`, voir
# `outils/PR3_UI.md`) : un dialogue à onglets. PR3 en a sept (ConvoyList, ShipList,
# TownList, TradingRoutes, advisor, patrol, piracy) ; on porte les quatre utiles à
# la sim actuelle — Convois, Navires, Villes, Routes — dans le même ordre logique.
# Il remplace les panneaux séparés Capitainerie + Routes : la structure de PR3 fait
# foi. Ouvert par le pétale « Bureau du port » du menu radial.
#
# Façade pure : tout vient du pont (compagnie/chantier). Filtré par le port courant
# pour Convois/Navires ; Villes et Routes sont globaux.
class_name ConvoyTownPanneau
extends CanvasLayer

signal ferme

const BOIS       := Color(0.16, 0.11, 0.07)
const BOIS_CLAIR := Color(0.26, 0.18, 0.11)
const OR         := Color(0.86, 0.71, 0.36)
const LIN        := Color(0.921, 0.888, 0.812)
const ENCRE      := Color(0.16, 0.11, 0.07)

var _sim: Object
var _port: Dictionary = {}
var _cadre: PanelContainer
var _titre: Label
var _depuis_maj := 0.0
const INTERVALLE := 0.7

# Onglet Convois
var _convois_box: VBoxContainer
# Onglet Navires
var _liste_libres: ItemList
var _libres: Array = []
var _msg: Label
# Onglet Villes
var _villes_box: VBoxContainer
# Onglet Routes
var _choix_convoi: OptionButton
var _convois_route: Array = []
var _liste_escales: ItemList
var _villes: Array = []
var _strategie: OptionButton
var _strats: Array = []
var _capital: SpinBox


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
	_rafraichir_convois()


func ouvrir(sim_obj: Object, port: Dictionary) -> void:
	_sim = sim_obj
	_port = port
	if _villes.is_empty():
		_remplir_villes_strats()
	_titre.text = "Bureau du port de %s" % String(port.get("nom", "?"))
	_rafraichir_tout()
	visible = true


func fermer() -> void:
	visible = false
	ferme.emit()


func _lbl(txt: String, taille: int, couleur: Color) -> Label:
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
	cadre.custom_minimum_size = Vector2(820, 660)
	cadre.position = Vector2(-410, -330)
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
	col.add_theme_constant_override("separation", 8)
	cadre.add_child(col)

	var titre_ligne := HBoxContainer.new()
	col.add_child(titre_ligne)
	_titre = _lbl("Bureau du port", 24, BOIS)
	_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titre_ligne.add_child(_titre)
	var fermer_b := Button.new()
	fermer_b.text = "Fermer"
	fermer_b.pressed.connect(fermer)
	titre_ligne.add_child(fermer_b)

	_msg = _lbl("", 13, Color(0.5, 0.1, 0.1))
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(tabs)
	tabs.add_child(_onglet_convois())
	tabs.add_child(_onglet_navires())
	tabs.add_child(_onglet_villes())
	tabs.add_child(_onglet_routes())
	tabs.set_tab_title(0, "Convois")
	tabs.set_tab_title(1, "Navires")
	tabs.set_tab_title(2, "Villes")
	tabs.set_tab_title(3, "Routes")
	col.add_child(_msg)


func _defil(hote: VBoxContainer) -> VBoxContainer:
	var d := ScrollContainer.new()
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	d.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hote.add_child(d)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	d.add_child(box)
	return box


# --- onglet Convois -----------------------------------------------------------
func _onglet_convois() -> Control:
	var v := VBoxContainer.new()
	v.name = "Convois"
	v.add_theme_constant_override("separation", 6)
	v.add_child(_lbl("Tes convois", 15, BOIS_CLAIR))
	_convois_box = _defil(v)
	return v


func _rafraichir_convois() -> void:
	if _convois_box == null:
		return
	for e in _convois_box.get_children():
		e.queue_free()
	var routes: Array = _sim.routes()
	if routes.is_empty():
		_convois_box.add_child(_lbl("Aucun convoi. Forme-en un dans l'onglet Navires.", 13, ENCRE))
		return
	for r in routes:
		_convois_box.add_child(_ligne_convoi(r))


func _ligne_convoi(r: Dictionary) -> Control:
	var fond := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(1, 1, 1, 0.35)
	st.border_color = BOIS_CLAIR
	st.set_border_width_all(1)
	st.set_content_margin_all(8)
	fond.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	fond.add_child(v)
	var indice := int(r.get("indice", 0))
	var est_route := String(r.get("mode", "route")) == "route"
	var t := HBoxContainer.new()
	v.add_child(t)
	var nom := _lbl(String(r.get("nom", "?")), 14, BOIS)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_child(nom)
	if est_route:
		var stop := Button.new()
		stop.text = "Retirer la route"
		stop.pressed.connect(func() -> void:
			_sim.retirer_route(indice); _rafraichir_convois())
		t.add_child(stop)
	var diss := Button.new()
	diss.text = "Dissoudre"
	diss.pressed.connect(func() -> void:
		_sim.dissoudre_route(indice); _rafraichir_tout())
	t.add_child(diss)
	var lieu := String(r.get("ville", ""))
	if lieu == "":
		lieu = "en mer"
	var mode_txt := ("route %s" % String(r.get("strategie", ""))) if est_route else "manuel"
	v.add_child(_lbl("%s · %s · cale %d/%d · %s · %s" % [
		mode_txt, _nombre(int(r.get("or_", 0))), int(r.get("charge", 0)),
		int(r.get("capacite", 0)), String(r.get("cargaison", "")), lieu], 12, ENCRE))
	return fond


# --- onglet Navires -----------------------------------------------------------
func _onglet_navires() -> Control:
	var v := VBoxContainer.new()
	v.name = "Navires"
	v.add_theme_constant_override("separation", 6)
	v.add_child(_lbl("Navires sans convoi, à ce port", 15, BOIS_CLAIR))
	_liste_libres = ItemList.new()
	_liste_libres.select_mode = ItemList.SELECT_MULTI
	_liste_libres.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_liste_libres)
	var b := Button.new()
	b.text = "Former un convoi des navires cochés"
	b.pressed.connect(_former_convoi)
	v.add_child(b)
	return v


func _rafraichir_navires() -> void:
	if _liste_libres == null:
		return
	var ici := String(_port.get("cle", ""))
	_libres = []
	for s in _sim.flotte():
		if String(s.get("attache", "")) == ici:
			_libres.append(s)
	_liste_libres.clear()
	for s in _libres:
		_liste_libres.add_item("%s — %s, %d t" % [
			String(s.get("nom", "?")), String(s.get("type", "?")), int(s.get("cale", 0))])


func _former_convoi() -> void:
	var sel: Array = []
	for i in _liste_libres.get_selected_items():
		sel.append(int(_libres[i].get("indice", 0)))
	if sel.is_empty():
		_erreur("Coche au moins un navire.")
		return
	var res: Dictionary = _sim.creer_convoi(sel, String(_port.get("cle", "")))
	if bool(res.get("ok", false)):
		_ok("Convoi formé — commande-le sur la carte, ou mets-lui une route.")
		_rafraichir_tout()
	else:
		_erreur(String(res.get("message", "Échec.")))


# --- onglet Villes ------------------------------------------------------------
func _onglet_villes() -> Control:
	var v := VBoxContainer.new()
	v.name = "Villes"
	v.add_theme_constant_override("separation", 6)
	v.add_child(_lbl("Les villes de l'archipel", 15, BOIS_CLAIR))
	_villes_box = _defil(v)
	return v


func _rafraichir_villes() -> void:
	if _villes_box == null:
		return
	for e in _villes_box.get_children():
		e.queue_free()
	for p in _sim.ports():
		var taille := int(p.get("taille", 1))
		var noms_taille := ["bourg", "bourg", "ville", "grande ville"]
		var t: String = noms_taille[clampi(taille, 0, 3)]
		var ch := ("chantier niv. %d" % int(p.get("niveau_chantier", 0))) if bool(p.get("chantier", false)) else "pas de chantier"
		_villes_box.add_child(_lbl("%s (%s) — %s · %s" % [
			String(p.get("nom", "?")), String(p.get("nation", "")), t, ch], 12, ENCRE))


# --- onglet Routes ------------------------------------------------------------
func _onglet_routes() -> Control:
	var v := VBoxContainer.new()
	v.name = "Routes"
	v.add_theme_constant_override("separation", 6)
	v.add_child(_lbl("Mettre un convoi en route de commerce", 15, BOIS_CLAIR))
	v.add_child(_lbl("Convoi", 13, ENCRE))
	_choix_convoi = OptionButton.new()
	v.add_child(_choix_convoi)
	v.add_child(_lbl("Escales, dans l'ordre du clic", 13, ENCRE))
	_liste_escales = ItemList.new()
	_liste_escales.select_mode = ItemList.SELECT_MULTI
	_liste_escales.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_liste_escales)
	var reg := HBoxContainer.new()
	reg.add_theme_constant_override("separation", 8)
	v.add_child(reg)
	reg.add_child(_lbl("Stratégie", 13, ENCRE))
	_strategie = OptionButton.new()
	reg.add_child(_strategie)
	reg.add_child(_lbl("Capital", 13, ENCRE))
	_capital = SpinBox.new()
	_capital.min_value = 0
	_capital.max_value = 100000000
	_capital.step = 1000
	_capital.value = 10000
	reg.add_child(_capital)
	var b := Button.new()
	b.text = "Mettre en route de commerce"
	b.pressed.connect(_mettre_en_route)
	v.add_child(b)
	return v


func _remplir_villes_strats() -> void:
	_villes = _sim.ports()
	_liste_escales.clear()
	for v in _villes:
		_liste_escales.add_item(String(v.get("nom", "?")))
	_strats = _sim.strategies()
	_strategie.clear()
	for i in _strats.size():
		_strategie.add_item(String(_strats[i]), i)


func _rafraichir_routes() -> void:
	if _choix_convoi == null:
		return
	var garde := _choix_convoi.selected
	_convois_route = _sim.routes()
	_choix_convoi.clear()
	for i in _convois_route.size():
		var c: Dictionary = _convois_route[i]
		_choix_convoi.add_item("%s [%s]" % [String(c.get("nom", "?")), String(c.get("mode", "route"))], i)
	if garde >= 0 and garde < _choix_convoi.item_count:
		_choix_convoi.select(garde)


func _mettre_en_route() -> void:
	if _choix_convoi.selected < 0 or _choix_convoi.selected >= _convois_route.size():
		_erreur("Choisis un convoi.")
		return
	var indice := int(_convois_route[_choix_convoi.selected].get("indice", 0))
	var circuit: Array = []
	for i in _liste_escales.get_selected_items():
		circuit.append(String(_villes[i].get("cle", "")))
	if circuit.size() < 2:
		_erreur("Choisis au moins deux escales.")
		return
	var strat := "profit"
	if _strategie.selected >= 0 and _strategie.selected < _strats.size():
		strat = String(_strats[_strategie.selected])
	var res: Dictionary = _sim.mettre_en_route(indice, circuit, strat, int(_capital.value))
	if bool(res.get("ok", false)):
		_ok("Convoi mis en route de commerce.")
		_rafraichir_tout()
	else:
		_erreur(String(res.get("message", "Échec.")))


# --- commun -------------------------------------------------------------------
func _rafraichir_tout() -> void:
	_rafraichir_convois()
	_rafraichir_navires()
	_rafraichir_villes()
	_rafraichir_routes()


func _ok(txt: String) -> void:
	_msg.add_theme_color_override("font_color", Color(0.1, 0.4, 0.1))
	_msg.text = txt


func _erreur(txt: String) -> void:
	_msg.add_theme_color_override("font_color", Color(0.5, 0.1, 0.1))
	_msg.text = txt


func _nombre(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = " " + out
	return ("-" if n < 0 else "") + out
