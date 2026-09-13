# L'écran du chantier naval.
#
# Le geste d'avant les routes : on s'y constitue une flotte. Choisir une ville et
# un type de navire, puis ACHETER (plein prix, tout de suite) ou CONSTRUIRE (moins
# d'or, mais il faut les matières au marché de la ville et un délai). Les navires
# rejoignent la flotte possédée ; on les affecte ensuite à des routes.
#
# Comme le panneau des routes, ce n'est qu'une façade : tout le calcul (prix,
# matières, délai, limites) vient du pont (sim/chantier + sim/compagnie).
class_name ChantierPanneau
extends CanvasLayer

signal ferme

const BOIS       := Color(0.16, 0.11, 0.07)
const BOIS_CLAIR := Color(0.26, 0.18, 0.11)
const OR         := Color(0.86, 0.71, 0.36)
const LIN        := Color(0.921, 0.888, 0.812)
const ENCRE      := Color(0.16, 0.11, 0.07)

var _sim: Object
var _titre_port: Label
var _type: OptionButton
var _infos: RichTextLabel
var _msg: Label
var _flotte_box: VBoxContainer
var _file_box: VBoxContainer
var _port_courant: Dictionary = {}   # le chantier est propre à CE port
var _types: Array = []               # index -> dico de type de navire (constructibles ici)


func _ready() -> void:
	layer = 61
	visible = false
	_construire()


func ouvrir(sim_obj: Object, port: Dictionary) -> void:
	_sim = sim_obj
	_port_courant = port
	_titre_port.text = "Chantier de %s — niveau %d" % [
		String(port.get("nom", "?")), int(port.get("niveau_chantier", 0))]
	_remplir_choix()
	_maj_infos()
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
	cadre.custom_minimum_size = Vector2(760, 620)
	cadre.position = Vector2(-380, -310)
	var style := StyleBoxFlat.new()
	style.bg_color = LIN
	style.border_color = BOIS
	style.set_border_width_all(6)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(16)
	cadre.add_theme_stylebox_override("panel", style)
	cadre.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cadre)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	cadre.add_child(col)

	var titre_ligne := HBoxContainer.new()
	col.add_child(titre_ligne)
	var titre := _label("Chantier naval", 26, BOIS)
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

	# --- gauche : commander un navire ---------------------------------------
	var gauche := VBoxContainer.new()
	gauche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gauche.add_theme_constant_override("separation", 6)
	deux.add_child(gauche)

	gauche.add_child(_label("Commander un navire", 18, BOIS_CLAIR))
	# Le chantier est propre à ce port : son nom et son niveau, pas de choix de ville.
	_titre_port = _label("", 13, BOIS)
	gauche.add_child(_titre_port)

	gauche.add_child(_label("Type de navire", 13, ENCRE))
	_type = OptionButton.new()
	_type.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type.item_selected.connect(func(_i: int) -> void: _maj_infos())
	gauche.add_child(_type)

	_infos = RichTextLabel.new()
	_infos.bbcode_enabled = true
	_infos.fit_content = true
	_infos.custom_minimum_size = Vector2(0, 150)
	_infos.add_theme_color_override("default_color", ENCRE)
	gauche.add_child(_infos)

	var boutons := HBoxContainer.new()
	boutons.add_theme_constant_override("separation", 8)
	gauche.add_child(boutons)
	var acheter_b := Button.new()
	acheter_b.text = "Acheter"
	acheter_b.pressed.connect(_acheter)
	boutons.add_child(acheter_b)
	var construire_b := Button.new()
	construire_b.text = "Construire"
	construire_b.pressed.connect(_construire_navire)
	boutons.add_child(construire_b)

	_msg = _label("", 13, Color(0.5, 0.1, 0.1))
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	gauche.add_child(_msg)

	# --- droite : flotte et constructions -----------------------------------
	var droite := VBoxContainer.new()
	droite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	droite.add_theme_constant_override("separation", 6)
	deux.add_child(droite)

	droite.add_child(_label("En construction", 16, BOIS_CLAIR))
	_file_box = VBoxContainer.new()
	_file_box.add_theme_constant_override("separation", 3)
	droite.add_child(_file_box)

	droite.add_child(_label("Flotte à quai", 16, BOIS_CLAIR))
	var defil := ScrollContainer.new()
	defil.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	droite.add_child(defil)
	_flotte_box = VBoxContainer.new()
	_flotte_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flotte_box.add_theme_constant_override("separation", 3)
	defil.add_child(_flotte_box)


func _remplir_choix() -> void:
	if _sim == null:
		return
	# Seuls les navires que le chantier de CE port peut fournir (niveau requis ≤
	# niveau du chantier).
	var niveau := int(_port_courant.get("niveau_chantier", 0))
	_types = []
	for n in _sim.navires_marchands():
		var req := int(_sim.chantier_infos(String(n.get("cle", ""))).get("niveau_requis", 99))
		if req <= niveau:
			_types.append(n)
	_type.clear()
	for i in _types.size():
		_type.add_item(String(_types[i].get("nom", "?")), i)
	if _types.is_empty():
		_type.add_item("(aucun navire à ce niveau)", -1)


func _type_choisi() -> String:
	if _type.selected >= 0 and _type.selected < _types.size():
		return String(_types[_type.selected].get("cle", ""))
	return ""


func _ville_choisie() -> String:
	return String(_port_courant.get("cle", ""))


func _maj_infos() -> void:
	if _sim == null:
		return
	var cle := _type_choisi()
	if cle == "":
		_infos.text = ""
		return
	var d: Dictionary = _sim.chantier_infos(cle)
	var mats := ""
	for m in (d.get("materiaux", []) as Array):
		mats += "  %d %s" % [int(m.get("quantite", 0)), String(m.get("nom", "?"))]
	if mats == "":
		mats = " —"
	_infos.text = ("[b]Acheter[/b] : %s pièces, livré tout de suite.\n"
		+ "[b]Construire[/b] : %s pièces + %d jours.\n"
		+ "[b]Matières[/b] (au marché de la ville) :%s") % [
		_nombre(int(d.get("prix_achat", 0))), _nombre(int(d.get("cout_construction", 0))),
		int(d.get("jours", 0)), mats]


func _acheter() -> void:
	if _sim == null:
		return
	var res: Dictionary = _sim.acheter_navire(_ville_choisie(), _type_choisi())
	_apres_commande(res)


func _construire_navire() -> void:
	if _sim == null:
		return
	var res: Dictionary = _sim.construire_navire(_ville_choisie(), _type_choisi())
	_apres_commande(res)


func _apres_commande(res: Dictionary) -> void:
	if bool(res.get("ok", false)):
		_msg.add_theme_color_override("font_color", Color(0.1, 0.4, 0.1))
		_msg.text = "Commande passée."
		rafraichir()
	else:
		_msg.add_theme_color_override("font_color", Color(0.5, 0.1, 0.1))
		_msg.text = String(res.get("message", "Échec."))


func rafraichir() -> void:
	if _sim == null or _flotte_box == null:
		return
	for e in _file_box.get_children():
		e.queue_free()
	var file: Array = _sim.chantier_file()
	if file.is_empty():
		_file_box.add_child(_label("Aucune construction en cours.", 12, ENCRE))
	else:
		for b in file:
			_file_box.add_child(_label("%s — %s, %d j" % [
				String(b.get("nom", "?")), String(b.get("ville", "?")),
				int(b.get("jours", 0))], 12, ENCRE))

	for e in _flotte_box.get_children():
		e.queue_free()
	var flotte: Array = _sim.flotte()
	if flotte.is_empty():
		_flotte_box.add_child(_label("Flotte vide. Achète ou construis un navire.", 12, ENCRE))
	else:
		for s in flotte:
			_flotte_box.add_child(_label("%s — %s, %d t" % [
				String(s.get("nom", "?")), String(s.get("type", "?")),
				int(s.get("cale", 0))], 13, BOIS))


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
