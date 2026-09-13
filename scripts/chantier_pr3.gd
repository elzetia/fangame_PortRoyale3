# Le chantier naval de Port Royale 3 — l'écran REJOUÉ, pas réinterprété.
#
# `scenes.Scene_Shipyard` (dialog_shipyard_pc.swf) décodé : un cadre à onglets
# et cinq pages empilées au même point, (102,-123). On ne redessine pas cet écran
# de mémoire : `EcranPR3` lit l'agencement exporté et pose les nœuds aux
# coordonnées de PR3.
#
# L'ordre des onglets est celui des indices du .swf — tab_0 sell, tab_2 buy,
# tab_3 repair, tab_4 build — soit à l'écran : Vendre, Acheter, Réparer, et
# « Contrat de construction » seulement là où le joueur administre la ville
# (« Seul l'administrateur de la ville peut commande des navires au chantier
# naval », ID_GUI_SHIPYARD_BUILD_EMPTY). Le titre est le nom du bâtiment selon
# son niveau : Petit chantier naval, Grand chantier naval, Chantier naval.
#
# La grille de statistiques relevée dans le .swf, au pixel :
#   ligne 1, y=499 : tf_barrels(-45) tf_cannon(45) tf_heart(135) tf_crew(225)
#   ligne 2, y=552 : tf_wheel(-45)  tf_knot(45)   tf_draft(135)  tf_cost(225)
#   prix : tf_price(61,600)   choix : chooser(-25,461)   action : bu_action(111,652)
# Chaque champ a sa plaque `Text_Bg_Nomal` ; l'icône `icn_tt_N` mord son bord
# gauche, dix pixels plus bas.
#
# La simulation reste seule maîtresse des nombres : cet écran ne calcule rien,
# il branche `Sim.chantier_infos` sur les champs que PR3 a nommés.
class_name ChantierPR3
extends CanvasLayer

signal ferme

const SWF := "dialog_shipyard_pc"
const RACINE := "scenes.Scene_Shipyard"

# Les onglets dans l'ordre d'affichage de PR3, avec leur clé de libellé.
# `niveau` est le niveau de chantier minimum pour que l'onglet paraisse.
const ONGLETS := [
	["ID_GUI_TAB_SELL_TABBUTTONTEXT", "Vendre", "exports.Tab_Shipyard_sell", 0],
	["ID_GUI_TAB_BUY_TABBUTTONTEXT", "Acheter", "exports.Tab_Shipyard_buy", 0],
	["ID_GUI_TAB_REPAIR_TABBUTTONTEXT", "Réparer", "exports.Tab_Shipyard_repair", 0],
	["ID_GUI_TAB_BUILD_TABBUTTONTEXT", "Contrat de construction",
		"exports.Tab_Shipyard_build", 3],
]

# Le nom du bâtiment selon son niveau (ID_GUI_BUILDING_SHIPYARD*).
const TITRES := {
	3: ["ID_GUI_BUILDING_SHIPYARD3", "Chantier naval"],
	2: ["ID_GUI_BUILDING_SHIPYARD2", "Grand chantier naval"],
	0: ["ID_GUI_BUILDING_SHIPYARD", "Petit chantier naval"],
}

var _sim: Object
var _port: Dictionary = {}
var _racine: Control
var _onglets_boite: Control
var _page: Control
var _scene := "exports.Tab_Shipyard_buy"
var _titre: Label
var _type: OptionButton
var _types: Array = []


func _ready() -> void:
	layer = 62
	visible = false
	_batir()


func ouvrir(sim_obj: Object, port: Dictionary) -> void:
	_sim = sim_obj
	_port = port
	var niveau := int(port.get("niveau_chantier", 0))
	var t: Array = TITRES.get(niveau, TITRES[0])
	_titre.text = LocaPR3.texte(str(t[0]), str(t[1]))
	_poser_onglets(niveau)
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

	# Le cadre à onglets de PR3 : bandeau de bois, parchemin, culot doré.
	_racine = Control.new()
	_racine.set_anchors_preset(Control.PRESET_CENTER)
	_racine.custom_minimum_size = Vector2(EcranPR3.CADRE_LARGEUR, EcranPR3.CADRE_HAUTEUR)
	_racine.size = Vector2(EcranPR3.CADRE_LARGEUR, EcranPR3.CADRE_HAUTEUR)
	_racine.position = Vector2(-EcranPR3.CADRE_LARGEUR / 2.0, -EcranPR3.CADRE_HAUTEUR / 2.0)
	_racine.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_racine)
	_racine.add_child(EcranPR3.cadre_tabbed())

	# Le titre, centré dans le bandeau de bois, comme dans PR3.
	_titre = Label.new()
	_titre.position = Vector2(60, 12)
	_titre.size = Vector2(EcranPR3.CADRE_LARGEUR - 120, 32)
	_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_titre.add_theme_font_size_override("font_size", 20)
	_titre.add_theme_color_override("font_color", Color(0.95, 0.90, 0.76))
	_racine.add_child(_titre)

	var fermer_b := Button.new()
	fermer_b.text = "✕"
	fermer_b.flat = true
	fermer_b.position = Vector2(EcranPR3.CADRE_LARGEUR - 40, 10)
	fermer_b.size = Vector2(30, 30)
	fermer_b.add_theme_color_override("font_color", Color(0.93, 0.88, 0.78))
	fermer_b.pressed.connect(fermer)
	_racine.add_child(fermer_b)

	_onglets_boite = Control.new()
	_onglets_boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(_onglets_boite)

	_type = OptionButton.new()
	_type.position = Vector2(90, 100)
	_type.size = Vector2(250, 24)
	_type.item_selected.connect(func(_i: int) -> void: _rafraichir_page())
	_racine.add_child(_type)


# La bande d'onglets, bornée par le niveau du chantier.
func _poser_onglets(niveau: int) -> void:
	for e in _onglets_boite.get_children():
		e.queue_free()
	var visibles: Array = []
	for o in ONGLETS:
		if niveau >= int(o[3]):
			visibles.append(o)
	if visibles.is_empty():
		return
	var largeur := (EcranPR3.CADRE_LARGEUR - 24.0) / visibles.size()
	var x := 12.0
	for o in visibles:
		var b := Button.new()
		b.text = LocaPR3.texte(str(o[0]), str(o[1]))
		b.position = Vector2(x, 64)
		b.size = Vector2(largeur - 4.0, 26)
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 12)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_choisir.bind(str(o[2])))
		_onglets_boite.add_child(b)
		x += largeur
	# Si l'onglet courant n'est pas offert ici, on retombe sur le premier.
	var scenes: Array = []
	for o in visibles:
		scenes.append(str(o[2]))
	if not scenes.has(_scene):
		_scene = str(visibles[0][2])


func _choisir(scene: String) -> void:
	_scene = scene
	_poser_page()


# Pose la page décodée de l'onglet courant, à sa place dans le cadre.
func _poser_page() -> void:
	if _page != null:
		_page.queue_free()
		_page = null
	_page = EcranPR3.batir(SWF, _scene)
	# Le décalage que Scene_Shipyard applique à ses pages — (102,-123) — et non
	# une position choisie à la main : sans lui la grille de stats sort du cadre.
	_page.position = EcranPR3.decalage_onglet(SWF, RACINE, _scene)
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
	# constdata : tant qu'on n'a pas trouvé leur source, on ne montre pas un
	# chiffre inventé.
	_poser("tf_barrels", str(int(fiche.get("cale", 0))))
	_poser("tf_heart", str(int(fiche.get("coque", 0))))
	_poser("tf_knot", str(int(fiche.get("vmax", 0))))
	_poser("tf_wheel", "%d %%" % int(fiche.get("maniabilite", 0)))
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
