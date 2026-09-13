# Le chantier naval — écran tabulé fidèle à PR3 (DialogShipyard : TabShipyardBuild,
# Buy, Sell, SellPirate, Repair). On porte les quatre gestes utiles : Acheter,
# Construire, Vendre, Réparer. Propre à CE port et borné par son niveau de chantier.
#
# Façade pure : prix, matières, délai, limites viennent du pont (sim/chantier +
# sim/compagnie). La structure de PR3 fait foi.
class_name ChantierPanneau
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
var _msg: Label
var _types: Array = []            # types constructibles à ce port
var _type_achat: OptionButton
var _infos_achat: RichTextLabel
var _type_constr: OptionButton
var _infos_constr: RichTextLabel
var _file_box: VBoxContainer
var _vendre_box: VBoxContainer


func _ready() -> void:
	layer = 62
	visible = false
	_construire()


func ouvrir(sim_obj: Object, port: Dictionary) -> void:
	_sim = sim_obj
	_port = port
	_titre.text = "Chantier de %s — niveau %d" % [
		String(port.get("nom", "?")), int(port.get("niveau_chantier", 0))]
	_remplir_types()
	_maj_infos()
	rafraichir()
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

	# Le cadre : le panneau peint de PR3 (Dialog_Tabbed_Big, 748x578) si l'art est
	# là, sinon un parchemin dessiné. On garde la taille native du panneau pour ne
	# pas étirer ses ornements. Les marges de contenu rentrent SOUS le cadre peint :
	# plus haut en tête pour laisser l'ornement d'en-tête de PR3.
	var cadre := PanelContainer.new()
	cadre.set_anchors_preset(Control.PRESET_CENTER)
	cadre.custom_minimum_size = Vector2(748, 578)
	cadre.position = Vector2(-374, -289)
	var style := SkinPR3.cadre("skinlib_pr3/801")
	if style is StyleBoxTexture:
		style.set_content_margin_all(44)
		style.content_margin_top = 70
		style.content_margin_bottom = 40
	cadre.add_theme_stylebox_override("panel", style)
	cadre.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cadre)
	_cadre = cadre

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	cadre.add_child(col)

	var titre_ligne := HBoxContainer.new()
	col.add_child(titre_ligne)
	_titre = _lbl("Chantier naval", 24, BOIS)
	_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titre_ligne.add_child(_titre)
	var fermer_b := Button.new()
	fermer_b.text = "Fermer"
	fermer_b.pressed.connect(fermer)
	titre_ligne.add_child(fermer_b)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(tabs)
	# Ordre exact de Scene_Shipyard (dialog_shipyard_pc.swf, décodé) :
	# Tab_Shipyard_build, _repair, _buy, _sell (+ _sell_pirate, hors jeu ici).
	tabs.add_child(_onglet_construire())
	tabs.add_child(_onglet_reparer())
	tabs.add_child(_onglet_acheter())
	tabs.add_child(_onglet_vendre())
	tabs.set_tab_title(0, "Construire")
	tabs.set_tab_title(1, "Réparer")
	tabs.set_tab_title(2, "Acheter")
	tabs.set_tab_title(3, "Vendre")

	_msg = _lbl("", 13, Color(0.5, 0.1, 0.1))
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(_msg)


func _onglet_acheter() -> Control:
	var v := VBoxContainer.new()
	v.name = "Acheter"
	v.add_theme_constant_override("separation", 6)
	v.add_child(_lbl("Acheter un navire tout fait (livré aussitôt)", 15, BOIS_CLAIR))
	_type_achat = OptionButton.new()
	_type_achat.item_selected.connect(func(_i: int) -> void: _maj_infos())
	v.add_child(_type_achat)
	_infos_achat = RichTextLabel.new()
	_infos_achat.bbcode_enabled = true
	_infos_achat.fit_content = true
	_infos_achat.custom_minimum_size = Vector2(0, 120)
	_infos_achat.add_theme_color_override("default_color", ENCRE)
	v.add_child(_infos_achat)
	var b := Button.new()
	b.text = "Acheter"
	b.pressed.connect(func() -> void:
		_apres(_sim.acheter_navire(String(_port.get("cle", "")), _cle(_type_achat))))
	v.add_child(b)
	return v


func _onglet_construire() -> Control:
	var v := VBoxContainer.new()
	v.name = "Construire"
	v.add_theme_constant_override("separation", 6)
	# L'illustration du chantier de PR3 (dialog_shipyard_pc/18.png), si l'art est là.
	var illu := SkinPR3.texture("dialog_shipyard_pc/18")
	if illu != null:
		var tr := TextureRect.new()
		tr.texture = illu
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(0, 150)
		tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(tr)
	v.add_child(_lbl("Construire un navire (or + matières + délai)", 15, BOIS_CLAIR))
	_type_constr = OptionButton.new()
	_type_constr.item_selected.connect(func(_i: int) -> void: _maj_infos())
	v.add_child(_type_constr)
	_infos_constr = RichTextLabel.new()
	_infos_constr.bbcode_enabled = true
	_infos_constr.fit_content = true
	_infos_constr.custom_minimum_size = Vector2(0, 120)
	_infos_constr.add_theme_color_override("default_color", ENCRE)
	v.add_child(_infos_constr)
	var b := Button.new()
	b.text = "Construire"
	b.pressed.connect(func() -> void:
		_apres(_sim.construire_navire(String(_port.get("cle", "")), _cle(_type_constr))))
	v.add_child(b)
	v.add_child(_lbl("En construction ici", 14, BOIS_CLAIR))
	_file_box = VBoxContainer.new()
	_file_box.add_theme_constant_override("separation", 3)
	v.add_child(_file_box)
	return v


func _onglet_vendre() -> Control:
	var v := VBoxContainer.new()
	v.name = "Vendre"
	v.add_theme_constant_override("separation", 6)
	v.add_child(_lbl("Vendre un navire de la flotte présent ici", 15, BOIS_CLAIR))
	var defil := ScrollContainer.new()
	defil.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(defil)
	_vendre_box = VBoxContainer.new()
	_vendre_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vendre_box.add_theme_constant_override("separation", 4)
	defil.add_child(_vendre_box)
	return v


func _onglet_reparer() -> Control:
	var v := VBoxContainer.new()
	v.name = "Réparer"
	v.add_theme_constant_override("separation", 6)
	v.add_child(_lbl("Réparer", 15, BOIS_CLAIR))
	v.add_child(_lbl("Disponible quand les combats abîmeront les coques : sans avarie, "
		+ "rien à réparer. Tarif de PR3 : Kosten 50 par unité de coque, Zeit 30.",
		12, ENCRE))
	return v


func _cle(ob: OptionButton) -> String:
	if ob.selected >= 0 and ob.selected < _types.size():
		return String(_types[ob.selected].get("cle", ""))
	return ""


func _remplir_types() -> void:
	var niveau := int(_port.get("niveau_chantier", 0))
	_types = []
	for n in _sim.navires_marchands():
		var req := int(_sim.chantier_infos(String(n.get("cle", ""))).get("niveau_requis", 99))
		if req <= niveau:
			_types.append(n)
	for ob in [_type_achat, _type_constr]:
		ob.clear()
		for i in _types.size():
			ob.add_item(String(_types[i].get("nom", "?")), i)
		if _types.is_empty():
			ob.add_item("(aucun navire à ce niveau)", -1)


func _maj_infos() -> void:
	if _sim == null:
		return
	var ca := _cle(_type_achat)
	if ca != "":
		var d: Dictionary = _sim.chantier_infos(ca)
		_infos_achat.text = "[b]Prix d'achat[/b] : %s pièces, livré tout de suite." % _nombre(int(d.get("prix_achat", 0)))
	var cc := _cle(_type_constr)
	if cc != "":
		var d2: Dictionary = _sim.chantier_infos(cc)
		var mats := ""
		for m in (d2.get("materiaux", []) as Array):
			mats += "  %d %s" % [int(m.get("quantite", 0)), String(m.get("nom", "?"))]
		if mats == "":
			mats = " —"
		_infos_constr.text = ("[b]Construction[/b] : %s pièces + %d jours.\n[b]Matières[/b] (au marché de la ville) :%s") % [
			_nombre(int(d2.get("cout_construction", 0))), int(d2.get("jours", 0)), mats]


func _apres(res: Dictionary) -> void:
	if bool(res.get("ok", false)):
		_msg.add_theme_color_override("font_color", Color(0.1, 0.4, 0.1))
		var somme := int(res.get("somme", 0))
		_msg.text = "Fait." if somme == 0 else "Vendu (%s pièces)." % _nombre(somme)
		rafraichir()
	else:
		_msg.add_theme_color_override("font_color", Color(0.5, 0.1, 0.1))
		_msg.text = String(res.get("message", "Échec."))


func rafraichir() -> void:
	if _sim == null or _file_box == null:
		return
	var ici := String(_port.get("cle", ""))
	for e in _file_box.get_children():
		e.queue_free()
	var n := 0
	for b in _sim.chantier_file():
		if String(b.get("ville_cle", "")) == ici:
			_file_box.add_child(_lbl("%s — %d j" % [String(b.get("nom", "?")), int(b.get("jours", 0))], 12, ENCRE))
			n += 1
	if n == 0:
		_file_box.add_child(_lbl("Aucune construction en cours ici.", 12, ENCRE))

	for e in _vendre_box.get_children():
		e.queue_free()
	var m := 0
	for s in _sim.flotte():
		if String(s.get("attache", "")) != ici:
			continue
		m += 1
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 8)
		var nom := _lbl("%s — %s, %d t" % [
			String(s.get("nom", "?")), String(s.get("type", "?")), int(s.get("cale", 0))], 13, BOIS)
		nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ligne.add_child(nom)
		var vendre := Button.new()
		vendre.text = "Vendre %s" % _nombre(int(_sim.chantier_infos(String(s.get("cle", ""))).get("prix_revente", 0)))
		var idx := int(s.get("indice", 0))
		vendre.pressed.connect(func() -> void: _apres(_sim.vendre_navire(idx)))
		ligne.add_child(vendre)
		_vendre_box.add_child(ligne)
	if m == 0:
		_vendre_box.add_child(_lbl("Aucun navire à ce port.", 12, ENCRE))


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
