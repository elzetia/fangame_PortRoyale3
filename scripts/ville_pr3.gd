# L'info-ville de Port Royale 3 — l'écran REJOUÉ depuis le .swf.
#
# `dialog_trade.swf` = `scenes.Scene_Trade`, un dialogue à onglets
# (Tab_TownInfo · Tab_TownGoods · Tab_Equipment · Tab_Trade). La fiche de ville
# est son PREMIER onglet. On ne la redessine pas de mémoire : `EcranPR3` rejoue
# l'agencement exporté, 58 éléments posés aux coordonnées exactes de PR3.
#
# Les champs que PR3 a nommés dans Tab_TownInfo, et ce qu'ils portent :
#   identité    tf_nationinfo(118,19) tf_towndesc(140,53) tf_citizens(167,88)
#               tf_rep(326,18) tf_defense(326,53) tf_guards(326,88)
#   « Status »  tf_status_prosperity(40,183) tf_status_citizens(175,183)
#               tf_status_citizens_growth(308,184) tf_production_production(40,259)
#               tf_status_buildings(175,259) tf_status_buildings_percentage(308,259)
#   production  icon_production_ware_0..4, à x=74,137,201,263,326 et y=308
#   « Player »  tf_player_production(41,411) tf_player_factories(176,411)
#               tf_player_residential(309,411) tf_player_reputation(344,346)
#
# Cet écran ne calcule rien : `Sim.etat_ville` a le dernier mot sur les nombres,
# comme dans PR3 où la fiche n'est qu'un affichage de l'état de la ville.
#
# API identique à l'ancien panneau (poser_villes / ouvrir / fermer / rafraichir,
# signal denrees_demandees) pour rester un remplacement direct dans la carte.
class_name VillePR3
extends CanvasLayer

signal ferme
signal denrees_demandees(port: Dictionary)

const SWF := "dialog_trade"
const SCENE := "exports.Tab_TownInfo"
const ICONES := "res://sprites/marchandises/"

# Les sept paliers de prospérité de PR3 (ID_GUI_TOWN_WEALTH), par etat_ville.niveau.
const PROSPERITE := ["", "Pauvreté", "Récession", "Stagnation", "Redressement",
	"Croissance", "Prospérité", "Opulence"]

# Les onglets de Scene_Trade, dans l'ordre du .swf, avec leur clé de libellé
# PR3. Les onglets de sens d'échange (ville↔convoi, comptoir↔convoi) ne portent
# pas un mot mais une IMAGE dans le jeu (`<img src='icon_trade_town_convoy'>`) :
# on les nomme ici en clair faute de les avoir encore posés.
const ONGLETS := [
	["ID_GUI_TAB_TOWNINFO_TABBUTTONTEXT", "Infos ville"],
	["ID_GUI_TAB_TOWNGOODS_TABBUTTONTEXT", "Liste denrées"],
	["ID_GUI_TAB_EQUIPMENT_TABBUTTONTEXT", "Equiper"],
	["ID_GUI_TAB_TOWN_CONVOY_TABBUTTONTEXT", "Commerce"],
]

var _sim: Object = null
var _port: Dictionary = {}
var _villes: Villes = null
var _convoi_a_quai := false

var _racine: Control
var _page: Control
var _titre: Label
var _onglet_marchandises: Button


func _init() -> void:
	layer = 8


func _ready() -> void:
	visible = false
	_batir()


func poser_villes(table: Villes) -> void:
	_villes = table


func _batir() -> void:
	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 0.45)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_STOP
	voile.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			fermer())
	add_child(voile)

	# Le cadre à onglets de PR3 : ses quatre bandes peintes, larges de 430 px.
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

	var x := 12.0
	for i in ONGLETS.size():
		var o: Array = ONGLETS[i]
		var b := Button.new()
		# Le libellé du jeu ; le texte d'un onglet-image est remplacé par un mot.
		var brut := LocaPR3.texte(str(o[0]), str(o[1]))
		b.text = str(o[1]) if brut.begins_with("<img") else brut
		b.position = Vector2(x, 62)
		b.custom_minimum_size = Vector2(100, 26)
		b.clip_text = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
		if i == 0:
			b.disabled = true
		elif i == 1:
			_onglet_marchandises = b
			b.pressed.connect(func() -> void: denrees_demandees.emit(_port))
		else:
			b.disabled = true
			b.tooltip_text = "Pas encore en place"
		_racine.add_child(b)
		x += 104.0

	# La page décodée, ramenée sous la bande d'onglets.
	_page = EcranPR3.batir(SWF, SCENE)
	_page.position = Vector2(14, 100)
	_racine.add_child(_page)


func ouvrir(sim_obj: Object, port_dict: Dictionary, convoi_a_quai := false) -> void:
	_sim = sim_obj
	_port = port_dict
	_convoi_a_quai = convoi_a_quai
	visible = true
	rafraichir()


func fermer() -> void:
	if not visible:
		return
	visible = false
	ferme.emit()


func _poser(nom: String, valeur: String) -> void:
	var n := EcranPR3.champ(_page, nom)
	if n is Label:
		(n as Label).text = valeur


func rafraichir() -> void:
	if _port.is_empty() or _page == null:
		return
	_titre.text = str(_port.get("nom", "?"))
	if _onglet_marchandises != null:
		_onglet_marchandises.disabled = not _convoi_a_quai
		_onglet_marchandises.tooltip_text = ("Le comptoir de la ville"
			if _convoi_a_quai else "Il faut un convoi à quai pour commercer")

	var habitants := int(_port.get("habitants", 0))
	var tendance := 0
	var niveau := 5
	var fabriques := 0
	var maisons := 0
	var occupation := 0.0
	var reputation := 0

	if _sim != null:
		var etat: Dictionary = _sim.etat_ville(str(_port.get("cle", "")))
		if not etat.is_empty():
			habitants = int(etat.get("habitants", habitants))
			tendance = int(etat.get("tendance", 0))
			niveau = int(etat.get("niveau", 5))
			fabriques = int(etat.get("fabriques", 0))
			maisons = int(etat.get("maisons", 0))
			occupation = float(etat.get("occupation", 0.0))
			reputation = int(etat.get("reputation", 0))

	var fleche := "—"
	if tendance > 0:
		fleche = "▲"
	elif tendance < 0:
		fleche = "▼"

	# Identité
	_poser("tf_nationinfo", str(_port.get("nation", _port.get("nation_cle", ""))).capitalize())
	_poser("tf_towndesc", str(_port.get("nom", "?")))
	_poser("tf_citizens", "%s %s" % [_nombre(habitants), fleche])
	_poser("tf_rep", str(reputation))
	_poser("tf_defense", "—")
	_poser("tf_guards", "—")

	# Section « Status »
	_poser("tf_status_prosperity", PROSPERITE[clampi(niveau, 1, 7)])
	_poser("tf_status_citizens", _nombre(habitants))
	_poser("tf_status_citizens_growth", fleche)
	_poser("tf_production_production", "%d fabriques" % fabriques)
	_poser("tf_status_buildings", "%d maisons" % maisons)
	_poser("tf_status_buildings_percentage", "%d %%" % int(round(occupation * 100.0)))

	# Section « Player » — ce que le joueur possède ici.
	_poser("tf_player_production", "—")
	_poser("tf_player_factories", "—")
	_poser("tf_player_residential", "—")
	_poser("tf_player_reputation", str(reputation))
	_poser("tf_citizeninfo", "")

	_poser_produits()


# Les cinq emplacements de marchandise produite, aux positions de PR3.
func _poser_produits() -> void:
	var produits: Array = _port.get("produits", [])
	for i in 5:
		var n := EcranPR3.champ(_page, "icon_production_ware_%d" % i)
		if not (n is TextureRect):
			continue
		var tr := n as TextureRect
		if i >= produits.size():
			tr.texture = null
			tr.tooltip_text = ""
			continue
		var cle := str(produits[i])
		var chemin := ICONES + cle + ".png"
		tr.texture = load(chemin) if ResourceLoader.exists(chemin) else null
		tr.custom_minimum_size = Vector2(40, 40)
		tr.tooltip_text = cle.capitalize()


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
