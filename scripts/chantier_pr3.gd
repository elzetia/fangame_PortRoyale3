# Le chantier naval de Port Royale 3 — l'écran REJOUÉ, pas réinterprété.
#
# `scenes.Scene_Shipyard` (dialog_shipyard_pc.swf) décodé : un cadre à onglets
# et cinq pages empilées à (102,-123) — Tab_Shipyard_build, _repair, _buy, _sell,
# _sell_pirate. On ne redessine pas cet écran de mémoire : on lit l'agencement
# exporté (reference_pr3/ui/agencement/dialog_shipyard_pc.json) et on pose les
# nœuds aux coordonnées de PR3 via `EcranPR3`.
#
# La grille de statistiques de navire relevée dans le .swf, au pixel :
#   ligne 1, y=499 : tf_barrels(-45) tf_cannon(45) tf_heart(135) tf_crew(225)
#   ligne 2, y=552 : tf_wheel(-45)  tf_knot(45)   tf_draft(135)  tf_cost(225)
#   prix  : tf_price(61,600)   choix : chooser(-25,461)   action : bu_action(111,652)
#   navire: cr_ship(38,112) — le rendu 3D, ici la vignette du modèle
# Chaque champ a sa plaque `Text_Bg_Nomal` et son icône `icn_tt_N` juste dessous.
#
# La simulation reste seule maîtresse des nombres : cet écran ne calcule rien,
# il branche `Sim.chantier_infos` sur les champs que PR3 a nommés.
class_name ChantierPR3
extends CanvasLayer

signal ferme

const SWF := "dialog_shipyard_pc"
const ONGLETS := {
	"Construire": "exports.Tab_Shipyard_build",
	"Réparer": "exports.Tab_Shipyard_repair",
	"Acheter": "exports.Tab_Shipyard_buy",
	"Vendre": "exports.Tab_Shipyard_sell",
}
# Décalage de la page dans le cadre, relevé sur Scene_Shipyard.
const DECALAGE_PAGE := Vector2(102, -123)

var _sim: Object
var _port: Dictionary = {}
var _racine: Control
var _page: Control
var _onglet := "Construire"
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
		String(port.get("nom", "?")), int(port.get("niveau_chantier", 0))]
	_remplir_types()
	_poser_page()
	visible = true


func fermer() -> void:
	visible = false
	ferme.emit()


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

	# La bande d'onglets, dans l'ordre de Scene_Shipyard.
	var x := 20.0
	for nom in ONGLETS.keys():
		var b := Button.new()
		b.text = String(nom)
		b.position = Vector2(x, 62)
		b.custom_minimum_size = Vector2(96, 28)
		b.add_theme_font_size_override("font_size", 14)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_choisir.bind(String(nom)))
		_racine.add_child(b)
		x += 100.0

	_type = OptionButton.new()
	_type.position = Vector2(24, 100)
	_type.custom_minimum_size = Vector2(240, 26)
	_type.item_selected.connect(func(_i: int) -> void: _rafraichir_page())
	_racine.add_child(_type)

	_msg = Label.new()
	_msg.position = Vector2(24, 540)
	_msg.add_theme_font_size_override("font_size", 13)
	_racine.add_child(_msg)


func _choisir(nom: String) -> void:
	_onglet = nom
	_poser_page()


# Pose la page décodée de l'onglet courant, à sa place dans le cadre.
func _poser_page() -> void:
	if _page != null:
		_page.queue_free()
		_page = null
	var scene := String(ONGLETS.get(_onglet, ""))
	if scene == "":
		return
	_page = EcranPR3.batir(SWF, scene)
	# La page vit à (102,-123) dans Scene_Shipyard ; on la ramène dans le cadre.
	_page.position = Vector2(40, 130) - DECALAGE_PAGE * 0.0
	_racine.add_child(_page)
	_rafraichir_page()


func _cle_choisie() -> String:
	if _type.selected >= 0 and _type.selected < _types.size():
		return String(_types[_type.selected].get("cle", ""))
	return ""


func _remplir_types() -> void:
	var niveau := int(_port.get("niveau_chantier", 0))
	_types = []
	_type.clear()
	for n in _sim.navires_marchands():
		var req := int(_sim.chantier_infos(String(n.get("cle", ""))).get("niveau_requis", 99))
		if req <= niveau:
			_types.append(n)
	for i in _types.size():
		_type.add_item(String(_types[i].get("nom", "?")), i)
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
		if String(n.get("cle", "")) == cle:
			fiche = n
			break

	_poser("tf_barrels", str(int(fiche.get("cale", 0))))
	_poser("tf_cannon", str(int(fiche.get("canons", 0))))
	_poser("tf_heart", str(int(fiche.get("coque", 0))))
	_poser("tf_crew", str(int(fiche.get("equipage", 0))))
	_poser("tf_knot", "%.1f" % float(fiche.get("vitesse", 0.0)))
	_poser("tf_wheel", "%.1f" % float(fiche.get("manoeuvre", 0.0)))
	_poser("tf_draft", str(int(fiche.get("tirant", 0))))
	_poser("tf_cost", str(int(fiche.get("entretien", 0))))

	match _onglet:
		"Acheter", "Vendre":
			_poser("tf_price", _nombre(int(d.get(
				"prix_achat" if _onglet == "Acheter" else "prix_revente", 0))))
		"Construire":
			_poser("tf_price", _nombre(int(d.get("cout_construction", 0))))
			_poser("tf_time_val", "%d j" % int(d.get("jours", 0)))
			var mats: Array = d.get("materiaux", [])
			for i in 4:
				_poser("tf_good_%d" % i, str(int(mats[i].get("quantite", 0))) if i < mats.size() else "")
		"Réparer":
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
