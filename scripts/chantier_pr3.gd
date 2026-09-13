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
# (ID_GUI_SHIPYARD_BUILD_EMPTY). Le titre est le nom du bâtiment selon son
# niveau : Petit chantier naval, Grand chantier naval, Chantier naval.
#
# L'agencement d'une page, au pixel :
#   stats 1, y=499 : tf_barrels(-45) tf_cannon(45) tf_heart(135) tf_crew(225)
#   stats 2, y=552 : tf_wheel(-45)  tf_knot(45)   tf_draft(135)  tf_cost(225)
#   prix   tf_price(61,600)   choix  chooser(-25,461)   action  bu_action(111,652)
# `bu_action` est ancré par son CENTRE : (111,652) retombe au milieu du cadre de
# 430, comme le bouton centré du jeu.
#
# La simulation reste seule maîtresse des nombres et des règles : cet écran ne
# calcule rien, il branche `Sim.chantier_infos` sur les champs que PR3 a nommés
# et renvoie les gestes du joueur à `Sim.acheter_navire` / `construire_navire` /
# `vendre_navire`.
class_name ChantierPR3
extends CanvasLayer

signal ferme

const SWF := "dialog_shipyard_pc"
const RACINE := "scenes.Scene_Shipyard"

# Les onglets dans l'ordre d'affichage de PR3 : clé de libellé, repli, scène,
# niveau de chantier minimum, puis la clé du libellé de son bouton d'action.
const ONGLETS := [
	["ID_GUI_TAB_SELL_TABBUTTONTEXT", "Vendre", "exports.Tab_Shipyard_sell", 0,
		"ID_GUI_LEGEND_SHIPYARD_SELL", "Vendre vaisseau"],
	["ID_GUI_TAB_BUY_TABBUTTONTEXT", "Acheter", "exports.Tab_Shipyard_buy", 0,
		"ID_GUI_LEGEND_SHIPYARD_BUY", "Acheter vaisseau"],
	["ID_GUI_TAB_REPAIR_TABBUTTONTEXT", "Réparer", "exports.Tab_Shipyard_repair", 0,
		"ID_GUI_LEGEND_SHIPYARD_REPAIR_CONVOY", "Réparer convoi"],
	["ID_GUI_TAB_BUILD_TABBUTTONTEXT", "Contrat de construction",
		"exports.Tab_Shipyard_build", 3,
		"ID_GUI_LEGEND_SHIPYARD_BUILD", "Signer le contrat"],
]

# Le nom du bâtiment selon son niveau (ID_GUI_BUILDING_SHIPYARD*).
const TITRES := {
	3: ["ID_GUI_BUILDING_SHIPYARD3", "Chantier naval"],
	2: ["ID_GUI_BUILDING_SHIPYARD2", "Grand chantier naval"],
	0: ["ID_GUI_BUILDING_SHIPYARD", "Petit chantier naval"],
}

# Le plan du navire, au niveau de la SCÈNE et non d'un onglet : `cr_ship` est un
# Visual_CustomRender, c'est-à-dire un rendu 3D en temps réel dans PR3. On en
# donne l'équivalent plat : le plan d'architecte extrait du .swf (18.png,
# 374x228) en fond, et le modèle vu de profil par-dessus, pris dans les atlas de
# navires déjà rendus pour la carte.
#
# Un atlas fait 8 colonnes sur 4 rangées de 160 px ; la case i porte l'étrave au
# cap i x 11,25° depuis le nord. La case 8 est donc le plein est — le profil.
const PLAN := "dialog_shipyard_pc/18"
const PLAN_TAILLE := Vector2(374, 228)
const ATLAS := "res://reference_pr3/navires_wm/atlas/"
const ATLAS_COTE := 160
const ATLAS_COLONNES := 8
const CAP_PROFIL := 8

var _sim: Object
var _port: Dictionary = {}
var _plan: TextureRect
var _navire: TextureRect
var _racine: Control
var _onglets_boite: Control
var _page: Control
var _scene := "exports.Tab_Shipyard_buy"
var _titre: Label
var _msg: Label
var _type: OptionButton
var _action: Button
# Ce que le sélecteur propose : des TYPES à acheter/construire, ou les navires
# de la flotte présents ici quand on vend.
var _choix: Array = []
var _sur_flotte := false


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
	_msg.text = ""
	_poser_onglets(niveau)
	_poser_page()
	visible = true


func fermer() -> void:
	visible = false
	ferme.emit()


# La carte rafraîchit l'écran ouvert à chaque jour écoulé.
func rafraichir() -> void:
	_remplir_choix()
	_rafraichir_page()


func _batir() -> void:
	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 0.55)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
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

	# Le plan et le navire, au point que Scene_Shipyard donne à `cr_ship`. Ils
	# vivent dans le cadre et non dans la page : PR3 les garde d'un onglet à
	# l'autre, comme le rendu 3D qu'ils remplacent.
	var pt := EcranPR3.point(SWF, RACINE, "cr_ship")
	_plan = TextureRect.new()
	_plan.texture = SkinPR3.texture(PLAN)
	_plan.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plan.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_plan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plan.position = pt
	_plan.size = PLAN_TAILLE
	_racine.add_child(_plan)

	_navire = TextureRect.new()
	_navire.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_navire.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_navire.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_navire.size = Vector2(PLAN_TAILLE.y, PLAN_TAILLE.y)
	_navire.position = pt + Vector2((PLAN_TAILLE.x - PLAN_TAILLE.y) / 2.0, 0)
	_racine.add_child(_navire)

	_onglets_boite = Control.new()
	_onglets_boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(_onglets_boite)

	_msg = Label.new()
	_msg.position = Vector2(16, EcranPR3.CADRE_HAUTEUR - 34)
	_msg.size = Vector2(EcranPR3.CADRE_LARGEUR - 32, 20)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.add_theme_font_size_override("font_size", 12)
	_racine.add_child(_msg)


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
	var scenes: Array = []
	for o in visibles:
		scenes.append(str(o[2]))
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
	if not scenes.has(_scene):
		_scene = str(visibles[0][2])


func _choisir(scene: String) -> void:
	_scene = scene
	_msg.text = ""
	_poser_page()


func _onglet_courant() -> Array:
	for o in ONGLETS:
		if str(o[2]) == _scene:
			return o
	return ONGLETS[1]


# Pose la page décodée de l'onglet courant, à sa place dans le cadre, puis y
# greffe le sélecteur et le bouton d'action AUX POINTS QUE PR3 LEUR DONNE.
func _poser_page() -> void:
	if _page != null:
		_page.queue_free()
		_page = null
	_page = EcranPR3.batir(SWF, _scene)
	# Le décalage que Scene_Shipyard applique à ses pages — (102,-123) — et non
	# une position choisie à la main : sans lui la grille de stats sort du cadre.
	_page.position = EcranPR3.decalage_onglet(SWF, RACINE, _scene)
	_racine.add_child(_page)

	var ancre_choix := EcranPR3.champ(_page, "chooser")
	_type = OptionButton.new()
	_type.size = Vector2(250, 26)
	_type.position = (ancre_choix.position if ancre_choix != null else Vector2(0, 461))
	_type.item_selected.connect(func(_i: int) -> void: _rafraichir_page())
	_page.add_child(_type)

	var o := _onglet_courant()
	var ancre_action := EcranPR3.champ(_page, "bu_action")
	_action = Button.new()
	_action.text = LocaPR3.texte(str(o[4]), str(o[5]))
	_action.size = Vector2(200, 30)
	# `bu_action` est ancré par son centre.
	var c := (ancre_action.position if ancre_action != null else Vector2(111, 652))
	_action.position = c - _action.size / 2.0
	_action.focus_mode = Control.FOCUS_NONE
	_action.add_theme_font_size_override("font_size", 14)
	_action.pressed.connect(_agir)
	_page.add_child(_action)

	_remplir_choix()
	_rafraichir_page()


# Ce que le sélecteur propose selon l'onglet : les navires de la flotte présents
# ici quand on vend, les types constructibles sinon.
func _remplir_choix() -> void:
	if _sim == null or _type == null:
		return
	var garde := _type.selected
	_choix = []
	_type.clear()
	_sur_flotte = _scene == "exports.Tab_Shipyard_sell"
	if _sur_flotte:
		var ici := str(_port.get("cle", ""))
		for s in _sim.flotte():
			if str(s.get("attache", "")) == ici:
				_choix.append(s)
		for i in _choix.size():
			_type.add_item("%s — %s" % [str(_choix[i].get("nom", "?")),
				str(_choix[i].get("type", "?"))], i)
		if _choix.is_empty():
			_type.add_item("(aucun navire à ce port)", -1)
	else:
		var niveau := int(_port.get("niveau_chantier", 0))
		for n in _sim.navires_marchands():
			var req := int(_sim.chantier_infos(str(n.get("cle", ""))).get("niveau_requis", 99))
			if req <= niveau:
				_choix.append(n)
		for i in _choix.size():
			_type.add_item(str(_choix[i].get("nom", "?")), i)
		if _choix.is_empty():
			_type.add_item("(aucun navire à ce niveau)", -1)
	if garde >= 0 and garde < _choix.size():
		_type.selected = garde

	if _action != null:
		# Réparer n'a pas encore de règle dans la simulation : on le dit, plutôt
		# que d'offrir un bouton qui ne ferait rien.
		var reparation := _scene == "exports.Tab_Shipyard_repair"
		_action.disabled = reparation or _choix.is_empty()
		_action.tooltip_text = ("Les combats n'abîment pas encore les coques."
			if reparation else "")


func _choisi() -> Dictionary:
	if _type != null and _type.selected >= 0 and _type.selected < _choix.size():
		return _choix[_type.selected]
	return {}


func _agir() -> void:
	var d := _choisi()
	if d.is_empty() or _sim == null:
		return
	var ville := str(_port.get("cle", ""))
	var res: Dictionary = {}
	match _scene:
		"exports.Tab_Shipyard_buy":
			res = _sim.acheter_navire(ville, str(d.get("cle", "")))
		"exports.Tab_Shipyard_build":
			res = _sim.construire_navire(ville, str(d.get("cle", "")))
		"exports.Tab_Shipyard_sell":
			res = _sim.vendre_navire(int(d.get("indice", 0)))
		_:
			return
	if bool(res.get("ok", false)):
		_msg.add_theme_color_override("font_color", Color(0.16, 0.42, 0.14))
		var somme := int(res.get("somme", 0))
		_msg.text = "Fait." if somme == 0 else "Vendu (%s pièces)." % _nombre(somme)
		_remplir_choix()
		_rafraichir_page()
	else:
		_msg.add_theme_color_override("font_color", Color(0.58, 0.13, 0.10))
		_msg.text = str(res.get("message", "Échec."))


# Branche la simulation sur les champs que PR3 a nommés.
func _rafraichir_page() -> void:
	if _page == null or _sim == null:
		return
	var d := _choisi()
	if d.is_empty():
		return
	# En vente, la fiche du navire vendu est celle de son TYPE.
	var cle := str(d.get("type_cle", d.get("cle", "")))
	var infos: Dictionary = _sim.chantier_infos(cle)
	var fiche := d
	if _sur_flotte:
		for n in _sim.navires_marchands():
			if str(n.get("cle", "")) == cle:
				fiche = n
				break

	# Canons et équipage viennent des positions de canon de `constdata` : chaque
	# navire y porte les siennes en blocs de 16 octets (trois flottants), mais
	# d'UN SEUL bord — le jeu mire l'autre. D'où canons = 2 × positions, et
	# équipage = canons × `[Ship] CrewmenAtGun` (5). Vérifié sur le sloop, que
	# PR3 affiche à 14 canons et 70 marins pour 7 positions relevées.
	#
	# Le tirant d'eau (`Gauge`) reste en attente : sa colonne n'est pas encore
	# ancrée avec certitude dans l'enregistrement binaire, et on préfère un tiret
	# à un chiffre inventé.
	_poser_navire(str(fiche.get("modele", "")))
	_poser("tf_barrels", str(int(fiche.get("cale", 0))))
	_poser("tf_heart", str(int(fiche.get("coque", 0))))
	_poser("tf_knot", str(int(fiche.get("vmax", 0))))
	_poser("tf_wheel", "%d %%" % int(fiche.get("maniabilite", 0)))
	_poser("tf_cost", str(int(fiche.get("entretien", 0))))
	_poser("tf_cannon", str(int(fiche.get("canons", 0))))
	_poser("tf_crew", str(int(fiche.get("equipage", 0))))
	_poser("tf_draft", "—")

	match _scene:
		"exports.Tab_Shipyard_buy":
			_poser("tf_price", _nombre(int(infos.get("prix_achat", 0))))
		"exports.Tab_Shipyard_sell":
			_poser("tf_price", _nombre(int(infos.get("prix_revente", 0))))
		"exports.Tab_Shipyard_build":
			_poser("tf_price", _nombre(int(infos.get("cout_construction", 0))))
			_poser("tf_time_val", "%d j" % int(infos.get("jours", 0)))
			var mats: Array = infos.get("materiaux", [])
			for i in 4:
				_poser("tf_good_%d" % i,
					str(int(mats[i].get("quantite", 0))) if i < mats.size() else "")
		"exports.Tab_Shipyard_repair":
			_poser("tf_cost_val", "—")
			_poser("tf_time_val", "—")


# Le navire choisi, vu de profil, découpé dans son atlas.
func _poser_navire(modele: String) -> void:
	if _navire == null:
		return
	if modele == "":
		_navire.texture = null
		return
	var atlas := SkinPR3.fichier(ATLAS + modele + "_0.png")
	if atlas == null:
		_navire.texture = null
		return
	var a := AtlasTexture.new()
	a.atlas = atlas
	a.region = Rect2(
		(CAP_PROFIL % ATLAS_COLONNES) * ATLAS_COTE,
		(CAP_PROFIL / ATLAS_COLONNES) * ATLAS_COTE,
		ATLAS_COTE, ATLAS_COTE)
	_navire.texture = a


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
