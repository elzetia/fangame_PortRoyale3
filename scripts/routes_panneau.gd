# L'écran des routes commerciales automatiques du joueur.
#
# Le cœur de Port Royale : on arme un convoi (des navires), on lui trace un
# circuit de villes et on lui donne une stratégie ; il navigue et commerce seul.
# Tout le moteur vit dans `sim/` (marchands + strategies + compagnie) ; ce
# panneau n'est qu'une façade : il liste les routes existantes et en crée.
#
# Contrôles standard de Godot (listes, menu, compteur), habillés de la palette
# de la maison. Il ne calcule rien : l'or, la cale, la cargaison viennent du pont.
class_name RoutesPanneau
extends CanvasLayer

signal ferme

const BOIS       := Color(0.16, 0.11, 0.07)
const BOIS_CLAIR := Color(0.26, 0.18, 0.11)
const OR         := Color(0.86, 0.71, 0.36)
const OR_PALE    := Color(0.98, 0.92, 0.76)
const LIN        := Color(0.921, 0.888, 0.812)
const ENCRE      := Color(0.16, 0.11, 0.07)

var _sim: Object
var _liste_navires: ItemList
var _liste_villes: ItemList
var _strategie: OptionButton
var _capital: SpinBox
var _routes_box: VBoxContainer
var _msg: Label
var _navires: Array = []      # index de ligne -> dico du type de navire
var _villes: Array = []       # index de ligne -> dico de ville
var _strats: Array = []       # index -> nom de stratégie


func _ready() -> void:
	layer = 60
	visible = false
	_construire()


func ouvrir(sim_obj: Object) -> void:
	_sim = sim_obj
	if _navires.is_empty():
		_remplir_choix()
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
	# Voile sombre plein écran qui capte les clics hors du cadre.
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
	cadre.custom_minimum_size = Vector2(760, 640)
	cadre.position = Vector2(-380, -320)
	var style := StyleBoxFlat.new()
	style.bg_color = LIN
	style.border_color = BOIS
	style.set_border_width_all(6)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(16)
	cadre.add_theme_stylebox_override("panel", style)
	# Le cadre ne laisse pas passer le clic au voile.
	cadre.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cadre)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	cadre.add_child(col)

	# Titre + bouton fermer.
	var titre_ligne := HBoxContainer.new()
	col.add_child(titre_ligne)
	var titre := _label("Routes commerciales", 26, BOIS)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titre_ligne.add_child(titre)
	var fermer_b := Button.new()
	fermer_b.text = "Fermer"
	fermer_b.pressed.connect(fermer)
	titre_ligne.add_child(fermer_b)

	var deux := HBoxContainer.new()
	deux.add_theme_constant_override("separation", 16)
	deux.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(deux)

	# --- colonne gauche : créer une route -----------------------------------
	var gauche := VBoxContainer.new()
	gauche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gauche.add_theme_constant_override("separation", 6)
	deux.add_child(gauche)

	gauche.add_child(_label("Nouvelle route", 18, BOIS_CLAIR))
	gauche.add_child(_label("Navires (choix multiple)", 13, ENCRE))
	_liste_navires = ItemList.new()
	_liste_navires.select_mode = ItemList.SELECT_MULTI
	_liste_navires.custom_minimum_size = Vector2(0, 130)
	_liste_navires.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gauche.add_child(_liste_navires)

	gauche.add_child(_label("Escales, dans l'ordre du clic", 13, ENCRE))
	_liste_villes = ItemList.new()
	_liste_villes.select_mode = ItemList.SELECT_MULTI
	_liste_villes.custom_minimum_size = Vector2(0, 170)
	_liste_villes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gauche.add_child(_liste_villes)

	var reglages := HBoxContainer.new()
	reglages.add_theme_constant_override("separation", 8)
	gauche.add_child(reglages)
	reglages.add_child(_label("Stratégie", 13, ENCRE))
	_strategie = OptionButton.new()
	reglages.add_child(_strategie)
	reglages.add_child(_label("Capital", 13, ENCRE))
	_capital = SpinBox.new()
	_capital.min_value = 0
	_capital.max_value = 100000000
	_capital.step = 1000
	_capital.value = 10000
	reglages.add_child(_capital)

	var armer_b := Button.new()
	armer_b.text = "Armer la route"
	armer_b.pressed.connect(_armer)
	gauche.add_child(armer_b)

	_msg = _label("", 13, Color(0.5, 0.1, 0.1))
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	gauche.add_child(_msg)

	# --- colonne droite : routes existantes ---------------------------------
	var droite := VBoxContainer.new()
	droite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	droite.add_theme_constant_override("separation", 6)
	deux.add_child(droite)
	droite.add_child(_label("Routes en service", 18, BOIS_CLAIR))
	var defil := ScrollContainer.new()
	defil.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	droite.add_child(defil)
	_routes_box = VBoxContainer.new()
	_routes_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_routes_box.add_theme_constant_override("separation", 6)
	defil.add_child(_routes_box)


func _remplir_choix() -> void:
	if _sim == null:
		return
	_navires = _sim.navires_marchands()
	_liste_navires.clear()
	for n in _navires:
		_liste_navires.add_item("%s — %d t, %s pièces, entretien %d/j" % [
			String(n.get("nom", "?")), int(n.get("cale", 0)),
			_nombre(int(n.get("prix", 0))), int(n.get("entretien", 0))])

	_villes = _sim.ports()
	_liste_villes.clear()
	for v in _villes:
		_liste_villes.add_item(String(v.get("nom", "?")))

	_strats = _sim.strategies()
	_strategie.clear()
	for i in _strats.size():
		_strategie.add_item(String(_strats[i]), i)


func _armer() -> void:
	if _sim == null:
		return
	var navires_cles: Array = []
	for i in _liste_navires.get_selected_items():
		navires_cles.append(String(_navires[i].get("cle", "")))
	var circuit: Array = []
	for i in _liste_villes.get_selected_items():
		circuit.append(String(_villes[i].get("cle", "")))
	if navires_cles.is_empty():
		_msg.text = "Choisis au moins un navire."
		return
	if circuit.size() < 2:
		_msg.text = "Choisis au moins deux escales."
		return
	var strat := "profit"
	if _strategie.selected >= 0 and _strategie.selected < _strats.size():
		strat = String(_strats[_strategie.selected])
	var res: Dictionary = _sim.armer_route(navires_cles, circuit, strat, int(_capital.value))
	if bool(res.get("ok", false)):
		_msg.add_theme_color_override("font_color", Color(0.1, 0.4, 0.1))
		_msg.text = "Route armée."
		rafraichir()
	else:
		_msg.add_theme_color_override("font_color", Color(0.5, 0.1, 0.1))
		_msg.text = String(res.get("message", "Échec."))


func rafraichir() -> void:
	if _sim == null or _routes_box == null:
		return
	for e in _routes_box.get_children():
		e.queue_free()
	var routes: Array = _sim.routes()
	if routes.is_empty():
		_routes_box.add_child(_label("Aucune route. Arme-en une à gauche.", 13, ENCRE))
		return
	for r in routes:
		_routes_box.add_child(_ligne_route(r))


func _ligne_route(r: Dictionary) -> Control:
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

	var t := HBoxContainer.new()
	v.add_child(t)
	var nom := _label(String(r.get("nom", "?")), 15, BOIS)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_child(nom)
	var diss := Button.new()
	diss.text = "Dissoudre"
	var indice := int(r.get("indice", 0))
	diss.pressed.connect(func() -> void:
		_sim.dissoudre_route(indice)
		rafraichir())
	t.add_child(diss)

	var circ: Array = r.get("circuit", [])
	v.add_child(_label("%s · %s" % [String(r.get("strategie", "")),
		" → ".join(PackedStringArray(circ))], 12, ENCRE))
	var lieu := String(r.get("ville", ""))
	if lieu == "":
		lieu = "en mer → " + String(r.get("destination", ""))
	v.add_child(_label("%s pièces · cale %d/%d · %s · %s" % [
		_nombre(int(r.get("or_", 0))), int(r.get("charge", 0)),
		int(r.get("capacite", 0)), String(r.get("cargaison", "")), lieu], 12, ENCRE))
	return fond


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
