# Le chantier naval de Port Royale 3 — l'écran REJOUÉ, pas réinterprété.
#
# `scenes.Scene_Shipyard` (dialog_shipyard_pc.swf) décodé : un cadre à onglets
# et cinq pages empilées — Tab_Shipyard_build, _repair, _buy, _sell (+ _sell_pirate).
# On ne redessine pas cet écran de mémoire : on lit l'agencement exporté
# (reference_pr3/ui/agencement/dialog_shipyard_pc.json) et `EcranPR3` pose les
# nœuds aux coordonnées de PR3.
#
# La grille de statistiques relevée dans le .swf, au pixel :
#   ligne 1, y=499 : tf_barrels(-45) tf_cannon(45) tf_heart(135) tf_crew(225)
#   ligne 2, y=552 : tf_wheel(-45)  tf_knot(45)   tf_draft(135)  tf_cost(225)
#   prix : tf_price(61,600)   choix : chooser(-25,461)   action : bu_action(111,652)
# Chaque champ a sa plaque `Text_Bg_Nomal` et son icône `icn_tt_N` juste dessous.
#
# Les libellés sont ceux du jeu, pas les miens : `LocaPR3` les tire de
# `global.res` (ID_GUI_TAB_BUILD_TABBUTTONTEXT = « Contrat de construction »…).
#
# La simulation reste seule maîtresse des nombres : cet écran ne calcule rien,
# il branche `Sim.chantier_infos` sur les champs que PR3 a nommés.
class_name ChantierPR3
extends CanvasLayer

signal ferme

const SWF := "dialog_shipyard_pc"

# Les onglets dans l'ordre de Scene_Shipyard, avec leur clé de libellé PR3.
const ONGLETS := [
	["ID_GUI_TAB_BUILD_TABBUTTONTEXT", "Contrat de construction", "exports.Tab_Shipyard_build"],
	["ID_GUI_TAB_REPAIR_TABBUTTONTEXT", "Réparer", "exports.Tab_Shipyard_repair"],
	["ID_GUI_TAB_BUY_TABBUTTONTEXT", "Acheter", "exports.Tab_Shipyard_buy"],
	["ID_GUI_TAB_SELL_TABBUTTONTEXT", "Vendre", "exports.Tab_Shipyard_sell"],
]

var _sim: Object
var _port: Dictionary = {}
var _racine: Control
var _page: Control
var _scene := "exports.Tab_Shipyard_build"
var _titre: Label
var _msg: Label
var _type: OptionButton
var _types: Array = []


func _ready() -> void:
	layer = 62
	visible = false
	_batir()


func ouvrir(sim_obj: Object, port: Dictionary) -> void:
	_sim = sim_obj
	_port = port
	_titre.text = "%s — chantier niveau %d" % [
		str(port.get("nom", "?")), int(port.get("niveau_chantier", 0))]
	_remplir_types()
	_poser_page()
	visible = true


func fermer() -> void:
	visible = false
	ferme.emit()


# La carte rafraîchit l'écran ouvert à chaque jour écoulé.
func rafraichir() -> void:
	_rafraichir_page()


func _batir() -> void:
	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 0.55)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			fermer())
	add_child(voile)

	# Le cadre à onglets de PR3, composé de ses bandes peintes (430 px de large).
	_racine = Control.new()
	_racine.set_anchors_preset(Control.PRESET_CENTER)
	_racine.custom_minimum_size = Vector2(430, 572)
	_racine.position = Vector2(-215, -286)
	_racine.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_racine)
	_racine.add_child(EcranPR3.cadre_tabbed(572))

	_titre = Label.new()
	_titre.position = Vector2(26, 16)
	_titre.add_theme_font_size_override("font_size", 22)
	_titre.add_theme_color_override("font_color", Color(0.95, 0.90, 0.76))
	_racine.add_child(_titre)

	var fermer_b := Button.new()
	fermer_b.text = "✕"
	fermer_b.flat = true
	fermer_b.position = Vector2(394, 12)
	fermer_b.add_theme_color_override("font_color", Color(0.93, 0.88, 0.78))
	fermer_b.pressed.connect(fermer)
	_racine.add_child(fermer_b)

	var x := 8.0
	for o in ONGLETS:
		var b := Button.new()
		b.text = LocaPR3.texte(str(o[0]), str(o[1]))
		b.position = Vector2(x, 62)
		b.custom_minimum_size = Vector2(102, 28)
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 12)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_choisir.bind(str(o[2])))
		_racine.add_child(b)
		x += 104.0

	_type = OptionButton.new()
	_type.position = Vector2(24, 100)
	_type.custom_minimum_size = Vector2(240, 26)
	_type.item_selected.connect(func(_i: int) -> void: _rafraichir_page())
	_racine.add_child(_type)

	_msg = Label.new()
	_msg.position = Vector2(24, 540)
	_msg.add_theme_font_size_override("font_size", 13)
	_racine.add_child(_msg)


func _choisir(scene: String) -> void:
	_scene = scene
	_poser_page()


# Pose la page décodée de l'onglet courant, à sa place dans le cadre.
func _poser_page() -> void:
	if _page != null:
		_page.queue_free()
		_page = null
	_page = EcranPR3.batir(SWF, _scene)
	_page.position = Vector2(40, 130)
	_racine.add_child(_page)
	_rafraichir_page()


func _cle_choisie() -> String:
	if _type.selected >= 0 and _type.selected < _types.size():
		return str(_types[_type.selected].get("cle", ""))
	return ""


func _remplir_types() -> void:
	var niveau := int(_port.get("niveau_chantier", 0))
	_types = []
	_type.clear()
	for n in _sim.navires_marchands():
		var req := int(_sim.chantier_infos(str(n.get("cle", ""))).get("niveau_requis", 99))
		if req <= niveau:
			_types.append(n)
	for i in _types.size():
		_type.add_item(str(_types[i].get("nom", "?")), i)
	if _types.is_empty():
		_type.add_item("(aucun navire à ce niveau)", -1)


# Branche la simulation sur les champs que PR3 a nommés.
func _rafraichir_page() -> void:
	if _page == null or _sim == null:
		return
	var cle := _cle_choisie()
	if cle == "":
		return
	var d: Dictionary = _sim.chantier_infos(cle)
	var fiche := {}
	for n in _sim.navires_marchands():
		if str(n.get("cle", "")) == cle:
			fiche = n
			break

	# Les noms sont ceux de PR3 (tf_barrels…), les valeurs celles du pont.
	# Canons, équipage et tirant d'eau ne sont PAS dans la table navires de
	# constdata (Value, Capacity, Hitpoints, HitpointsSail, Construct,
	# DailyCosts, rangs, Vmin, Vmax, Wendig) : tant qu'on n'a pas trouvé leur
	# source dans PR3, on ne montre pas un chiffre inventé.
	_poser("tf_barrels", str(int(fiche.get("cale", 0))))
	_poser("tf_heart", str(int(fiche.get("coque", 0))))
	_poser("tf_knot", str(int(fiche.get("vmax", 0))))
	_poser("tf_wheel", str(int(fiche.get("maniabilite", 0))))
	_poser("tf_cost", str(int(fiche.get("entretien", 0))))
	_poser("tf_cannon", "—")
	_poser("tf_crew", "—")
	_poser("tf_draft", "—")

	match _scene:
		"exports.Tab_Shipyard_buy":
			_poser("tf_price", _nombre(int(d.get("prix_achat", 0))))
		"exports.Tab_Shipyard_sell":
			_poser("tf_price", _nombre(int(d.get("prix_revente", 0))))
		"exports.Tab_Shipyard_build":
			_poser("tf_price", _nombre(int(d.get("cout_construction", 0))))
			_poser("tf_time_val", "%d j" % int(d.get("jours", 0)))
			var mats: Array = d.get("materiaux", [])
			for i in 4:
				_poser("tf_good_%d" % i,
					str(int(mats[i].get("quantite", 0))) if i < mats.size() else "")
		"exports.Tab_Shipyard_repair":
			_poser("tf_cost_val", "—")
			_poser("tf_time_val", "—")


func _poser(nom: String, valeur: String) -> void:
	var n := EcranPR3.champ(_page, nom)
	if n is Label:
		(n as Label).text = valeur


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


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		fermer()
		get_viewport().set_input_as_handled()
