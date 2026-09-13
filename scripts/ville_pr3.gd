# L'info-ville de Port Royale 3 — l'écran REJOUÉ depuis le .swf.
#
# `dialog_trade.swf` = `scenes.Scene_Trade`, un dialogue à onglets. La fiche de
# ville est son premier onglet, `Tab_TownInfo`, posé à (15,113). `EcranPR3`
# rejoue son agencement : 58 éléments aux coordonnées exactes de PR3.
#
# PR3 range ses onglets sur DEUX rangées : trois onglets à libellé (Infos ville,
# Liste denrées, Equiper) puis trois onglets-ICÔNES qui disent le sens de
# l'échange — ville↔convoi, comptoir↔convoi, ville↔comptoir. Ces derniers ne
# portent pas un mot mais une image (`<img src='icon_trade_town_convoy'>`), qu'on
# retrouve dans dialog_trade/5.png, 6.png, 7.png (106x17).
#
# Les champs que PR3 a nommés dans Tab_TownInfo :
#   identité    tf_nationinfo(118,19) tf_towndesc(140,53) tf_citizens(167,88)
#               tf_rep(326,18) tf_defense(326,53) tf_guards(326,88)
#   « État »    tf_status_prosperity(40,183) tf_status_citizens(175,183)
#               tf_status_citizens_growth(308,184) tf_production_production(40,259)
#               tf_status_buildings(175,259) tf_status_buildings_percentage(308,259)
#   production  icon_production_ware_0..4, à x=74,137,201,263,326 et y=308
#   « Player »  tf_player_production(41,411) tf_player_factories(176,411)
#               tf_player_residential(309,411) tf_player_reputation(344,346)
#
# Cet écran ne calcule rien : `Sim.etat_ville` a le dernier mot sur les nombres.
#
# API identique à l'ancien panneau (poser_villes / ouvrir / fermer / rafraichir,
# signal denrees_demandees) pour rester un remplacement direct dans la carte.
class_name VillePR3
extends CanvasLayer

signal ferme
signal denrees_demandees(port: Dictionary)

const SWF := "dialog_trade"
const RACINE := "scenes.Scene_Trade"
const SCENE := "exports.Tab_TownInfo"
const ICONES := "res://sprites/marchandises/"

# Les sept paliers de prospérité de PR3 (ID_GUI_TOWN_WEALTH), par etat_ville.niveau.
const PROSPERITE := ["", "Pauvreté", "Récession", "Stagnation", "Redressement",
	"Croissance", "Prospérité", "Opulence"]

# La classe de ville de PR3 (ID_GUI_TOWN_TYPE_00..03), affichée sous la nation.
# PR3 en compte quatre ; notre archipel n'en gradue que trois (`taille` 1..3),
# si bien que le quatrième palier — Vice-roi — n'est pas encore atteignable.
const TYPES_VILLE := [
	["ID_GUI_TOWN_TYPE_00", "Village"],
	["ID_GUI_TOWN_TYPE_01", "Ville coloniale"],
	["ID_GUI_TOWN_TYPE_02", "Ville de Gouverneur"],
	["ID_GUI_TOWN_TYPE_03", "Vice-roi"],
]

# Ce que les citoyens pensent du joueur, par palier de réputation dans la ville
# (ID_GUI_REPUTATION_TOWN_PERCENTAGE_00..05). PR3 pose cette phrase sous la
# section « Vos bâtiments », dans le champ tf_citizeninfo.
const REPUTATION_VILLE := [
	["ID_GUI_REPUTATION_TOWN_PERCENTAGE_00", "Les citoyens vous dédaignent."],
	["ID_GUI_REPUTATION_TOWN_PERCENTAGE_01", "Peu de citoyens s'intéressent à vous."],
	["ID_GUI_REPUTATION_TOWN_PERCENTAGE_02", "Certains citoyens vous apprécient."],
	["ID_GUI_REPUTATION_TOWN_PERCENTAGE_03", "Vous êtes populaire parmi les citoyens."],
	["ID_GUI_REPUTATION_TOWN_PERCENTAGE_04", "Tous les citoyens vous aiment."],
	["ID_GUI_REPUTATION_TOWN_PERCENTAGE_05", "Vous êtes un héros pour les citoyens."],
]

# La ligne de tête de PR3 : « Espagne, neutre ». Le %1 est le nom de la nation,
# le palier vient de la réputation du joueur auprès d'elle
# (ID_REPUTATION_NATION_0..3).
const REPUTATION_NATION := [
	["ID_REPUTATION_NATION_0", "%1, hostile"],
	["ID_REPUTATION_NATION_1", "%1, neutre"],
	["ID_REPUTATION_NATION_2", "%1, respecté"],
	["ID_REPUTATION_NATION_3", "%1, populaire"],
]

# Première rangée : les onglets à libellé.
const ONGLETS := [
	["ID_GUI_TAB_TOWNINFO_TABBUTTONTEXT", "Infos ville"],
	["ID_GUI_TAB_TOWNGOODS_TABBUTTONTEXT", "Liste denrées"],
	["ID_GUI_TAB_EQUIPMENT_TABBUTTONTEXT", "Equiper"],
]

# Seconde rangée : les onglets-icônes de sens d'échange, tels que PR3 les pose.
const ONGLETS_ICONES := [
	["dialog_trade/5", "Ville → convoi"],
	["dialog_trade/6", "Comptoir → convoi"],
	["dialog_trade/7", "Ville → comptoir"],
]

var _sim: Object = null
var _port: Dictionary = {}
var _villes: Villes = null
var _convoi_a_quai := false

var _racine: Control
var _page: Control
var _titre: Label
var _onglet_denrees: Button


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

	_racine = Control.new()
	_racine.set_anchors_preset(Control.PRESET_CENTER)
	_racine.custom_minimum_size = Vector2(EcranPR3.CADRE_LARGEUR, EcranPR3.CADRE_HAUTEUR)
	_racine.size = Vector2(EcranPR3.CADRE_LARGEUR, EcranPR3.CADRE_HAUTEUR)
	_racine.position = Vector2(-EcranPR3.CADRE_LARGEUR / 2.0, -EcranPR3.CADRE_HAUTEUR / 2.0)
	_racine.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_racine)
	_racine.add_child(EcranPR3.cadre_tabbed())

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

	# Rangée 1 : les onglets à libellé.
	var largeur := (EcranPR3.CADRE_LARGEUR - 24.0) / ONGLETS.size()
	var x := 12.0
	for i in ONGLETS.size():
		var o: Array = ONGLETS[i]
		var b := Button.new()
		b.text = LocaPR3.texte(str(o[0]), str(o[1]))
		b.position = Vector2(x, 64)
		b.size = Vector2(largeur - 4.0, 26)
		b.clip_text = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
		if i == 0:
			b.disabled = true
		elif i == 1:
			_onglet_denrees = b
			b.pressed.connect(func() -> void: denrees_demandees.emit(_port))
		else:
			b.disabled = true
			b.tooltip_text = "Pas encore en place"
		_racine.add_child(b)
		x += largeur

	# Rangée 2 : les onglets-icônes de sens d'échange.
	x = 12.0
	for o in ONGLETS_ICONES:
		var cadre := Panel.new()
		cadre.position = Vector2(x, 92)
		cadre.size = Vector2(largeur - 4.0, 22)
		cadre.tooltip_text = str(o[1])
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.30, 0.22, 0.13, 0.55)
		sb.border_color = Color(0.48, 0.38, 0.20)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		cadre.add_theme_stylebox_override("panel", sb)
		_racine.add_child(cadre)
		var tex := SkinPR3.texture(str(o[0]))
		if tex != null:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.position = Vector2(x, 94)
			tr.size = Vector2(largeur - 4.0, 18)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_racine.add_child(tr)
		x += largeur

	# La page décodée, à son décalage de scène — (15,113).
	_page = EcranPR3.batir(SWF, SCENE)
	_page.position = EcranPR3.decalage_onglet(SWF, RACINE, SCENE)
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
	if _onglet_denrees != null:
		_onglet_denrees.disabled = not _convoi_a_quai
		_onglet_denrees.tooltip_text = ("Le comptoir de la ville"
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

	# « Espagne, neutre » : la nation et le palier de réputation auprès d'elle.
	# La simulation tient bien une réputation par NATION — la moyenne de ses
	# villes, de 0 à 100 — que `etat_compagnie` rend par clé de nation.
	var rep_nation := reputation
	if _sim != null and _sim.has_method("etat_compagnie"):
		var reps = (_sim.etat_compagnie() as Dictionary).get("reputation", {})
		if reps is Dictionary:
			rep_nation = int(reps.get(str(_port.get("nation_cle", "")), reputation))
	var pn: Array = REPUTATION_NATION[_palier_nation(rep_nation)]
	_poser("tf_nationinfo", LocaPR3.format(str(pn[0]),
		[str(_port.get("nation", _port.get("nation_cle", "")))], str(pn[1])))
	var type_ville: Array = TYPES_VILLE[clampi(int(_port.get("taille", 1)) - 1, 0, 3)]
	_poser("tf_towndesc", LocaPR3.texte(str(type_ville[0]), str(type_ville[1])))
	_poser("tf_citizens", _nombre(habitants))
	_poser("tf_rep", str(reputation))
	_poser("tf_defense", "—")
	_poser("tf_guards", "—")

	_poser("tf_status_prosperity", PROSPERITE[clampi(niveau, 1, 7)])
	_poser("tf_status_citizens", _nombre(habitants))
	_poser("tf_status_citizens_growth", fleche)
	_poser("tf_production_production", str(fabriques))
	_poser("tf_status_buildings", str(maisons))
	_poser("tf_status_buildings_percentage", "%d %%" % int(round(occupation * 100.0)))

	_poser("tf_player_production", "—")
	_poser("tf_player_factories", "—")
	_poser("tf_player_residential", "—")
	_poser("tf_player_reputation", str(reputation))
	# La phrase de PR3 sur l'estime des citoyens, choisie par palier de réputation.
	var palier: Array = REPUTATION_VILLE[clampi(reputation * 6 / 100, 0, 5)]
	_poser("tf_citizeninfo", LocaPR3.texte(str(palier[0]), str(palier[1])))

	_poser_produits()


# Les cinq emplacements de marchandise produite, aux positions de PR3.
func _poser_produits() -> void:
	var produits: Array = _port.get("produits", [])
	for i in 5:
		var n := EcranPR3.champ(_page, "icon_production_ware_%d" % i)
		if not (n is TextureRect):
			continue
		var tr := n as TextureRect
		tr.size = Vector2(40, 40)
		if i >= produits.size():
			tr.texture = null
			tr.tooltip_text = ""
			continue
		var cle := str(produits[i])
		var chemin := ICONES + cle + ".png"
		tr.texture = load(chemin) if ResourceLoader.exists(chemin) else null
		tr.tooltip_text = cle.capitalize()


# Les quatre paliers de PR3 : hostile, neutre, respecté, populaire. La réputation
# part à 50 — qui doit se lire « neutre » — et non au milieu d'une échelle
# linéaire, d'où des seuils plutôt qu'une division.
func _palier_nation(rep: int) -> int:
	if rep < 25:
		return 0
	if rep < 60:
		return 1
	if rep < 85:
		return 2
	return 3


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
