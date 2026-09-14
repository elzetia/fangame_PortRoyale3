# La vignette de convoi de Port Royale 3 — la vraie, rejouée.
#
# Quand on sélectionne un convoi, PR3 ouvre sous la planche droite une carte à
# CINQ ONGLETS. Tout ce qui suit est relevé dans `hud_pc.swf`, jamais inventé :
# le conteneur est `Hud_pc_fla.Hud_Scroll_Right_Elemente_33`, ses cinq boutons
# ronds sont alignés à y = 83 (x = 92, 127, 161, 195, 229) et chaque onglet a
# son propre panneau, posé au même endroit et montré seul.
#
#   bu_convoy  -> convoy    détails : cale, navires, coque, nœuds, canons,
#                           équipage, puissance, et les deux cases « patrouiller »
#                           et « attaquer la ville »
#   bu_goods   -> li_goods  la cargaison : douze cases (4 x 3) et deux flèches
#   bu_bships  -> bships    l'escorte : TROIS emplacements, marins/canons/
#                           puissance, le bouton « Max. » et « Organiser »
#   bu_captain -> captain   le capitaine : salaire, batailles, nom, et SIX
#                           compétences (combat, navigation, commerce,
#                           réparation, abordage, vigie)
#   bu_route   -> route     la route commerciale : nom, type, villes, durée,
#                           gain de la dernière rotation, case « Route active »,
#                           et les boutons éditer / sauvegarder / charger
#
# `bu_pirate` est posé AU MÊME POINT que `bu_route` (x = 229) : c'est la variante
# de la carrière pirate, et les deux ne coexistent jamais. On ne montre donc que
# celui qui a lieu d'être.
#
# En tête, `name_task` porte le nom du convoi et son message de situation — ce
# que PR3 appelle la « tâche » (`ID_GUI_CONVOY_ON_SEA`, `_BATTLE`, `_EMERGENCY`,
# `_PIRATEMODE`, et `ID_GUI_CONVOY_ON_ROUTE_NUM` = « %1 (%2) »).
#
# AUCUNE COORDONNÉE N'EST RECOPIÉE ICI. `EcranPR3.batir` les lit dans le fichier
# du jeu ; ce script ne connaît que des NOMS de nœuds. C'est ce qui fait qu'une
# correction de l'extraction profite à l'écran sans qu'on y retouche.
class_name ConvoiVignettePR3
extends Control

signal onglet_change(nom: String)

const SWF := "hud_pc"
const PLANCHE := "Hud_pc_fla.Hud_Scroll_Right_Elemente_33"
# La planche de fond : bandeau de bois et corps de toile. Voir `_ready()`.
const FOND := "75"
const FOND_TAILLE := Vector2(204, 360)
# Assez pour descendre conteneur > panneau > sous-panneau > plaques.
const PROFONDEUR := 5

# Le bouton d'onglet et le panneau qu'il montre. L'ordre est celui de PR3, de
# gauche à droite.
const ONGLETS := [
	["bu_convoy", "convoy"],
	["bu_goods", "li_goods"],
	["bu_bships", "bships"],
	["bu_captain", "captain"],
	["bu_route", "route"],
]

# L'encre des champs posés sur le parchemin de la vignette. `EcranPR3` les rend
# en brun sombre par défaut, ce qui convient ici : contrairement à l'or de la
# planche droite, ces valeurs sont sur fond clair.

var _plateau: Control
var _panneaux: Dictionary = {}
var _actif := "convoy"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

	# `repli` ouvert : la vignette est faite pour l'essentiel de classes qui ne
	# portent leur image que par la table — plaques de texte, boutons ronds,
	# pictogrammes. Les 128 couches qu'elle en tire ont été regardées au rendu.
	# LE PARCHEMIN, D'ABORD : il se dessine DERRIÈRE tout le reste, donc il entre
	# dans l'arbre avant le plateau.
	#
	# Sans lui la vignette flottait sur la carte, plaques et boutons sans support
	# — « complètement rincée ». PR3 le pose dans `Scene_Hud` sous le nom
	# `scroll_r`, mais par un `char106` que la table fait pointer sur `98.png`,
	# un crayon de 32x32 : la numérotation des FORMES et celle des BITMAPS sont
	# disjointes, et le piège est documenté dans `swf_lecture.py`. On adresse
	# donc le bitmap directement.
	#
	# `hud_pc/75` fait 204 x 360 là où le contenu de la carte mesure 203 x 326 :
	# un bandeau de bois en haut, puis un corps de toile borde de cordelette
	# doree. C'est bien la planche des captures du jeu — verifiee a l'oeil, pas
	# deduite de ses dimensions : deux fois deja sur ce projet un bitmap de la
	# bonne taille s'est revele etre autre chose.
	var fond := SkinPR3.texture("hud_pc/" + FOND)
	if fond != null:
		var tr := TextureRect.new()
		tr.name = "parchemin"
		tr.texture = fond
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.size = FOND_TAILLE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)

	_plateau = EcranPR3.batir(SWF, PLANCHE, true, PROFONDEUR)
	add_child(_plateau)

	# L'ORIGINE. `batir` pose chaque enfant aux coordonnées du .swf, qui pour
	# cette carte commencent vers (62, 28) — PR3 la place dans un conteneur qui
	# lui donne ce décalage. Laissée telle quelle, une vignette ancrée en haut à
	# droite sortirait de l'écran par la droite. On ramène donc son contenu sur
	# (0, 0) UNE FOIS, en décalant le plateau : le reste du code peut alors la
	# poser comme n'importe quel panneau, sans connaître ce détail du fichier.
	var coin := Vector2(INF, INF)
	for e in _plateau.get_children():
		var c := e as Control
		if c != null:
			coin = Vector2(minf(coin.x, c.position.x), minf(coin.y, c.position.y))
	if coin.x < INF and coin.y < INF:
		_plateau.position = -coin

	# La carrière pirate remplace la route au même point : sans cela les deux
	# pictogrammes se superposeraient, et on verrait une tête de mort sur la
	# boussole.
	var pirate := _trouver("bu_pirate")
	if pirate != null:
		pirate.visible = false
	var panneau_pirate := _trouver("pirate")
	if panneau_pirate != null:
		panneau_pirate.visible = false

	for paire in ONGLETS:
		var nom_bouton: String = paire[0]
		var nom_panneau: String = paire[1]
		var panneau := _trouver(nom_panneau)
		if panneau != null:
			_panneaux[nom_panneau] = panneau
		var zone := EcranPR3.bouton(_plateau, nom_bouton, "", _infobulle(nom_bouton))
		if zone != null:
			zone.pressed.connect(func() -> void: montrer(nom_panneau))

	montrer(_actif)


# Les infobulles DU JEU quand elles existent. La table n'en porte que pour deux
# des cinq onglets — il n'y a pas de clé `ROUNDBUTTON_CONVOIDETAILS`,
# `_FREIGHTLIST` ni `_CAPTAIN`. On laisse donc les trois autres sans infobulle
# plutôt que d'écrire un libellé français de mon cru.
func _infobulle(nom_bouton: String) -> String:
	match nom_bouton:
		"bu_bships": return LocaPR3.propre("ID_GUI_TT_VISUAL_ROUNDBUTTON_SHIPLIST", "")
		"bu_route": return LocaPR3.propre("ID_GUI_TT_VISUAL_ROUNDBUTTON_TRADEROUTE", "")
	return ""


# Les panneaux sont IMBRIQUÉS (un onglet contient ses sous-groupes) : une
# recherche sur les enfants directs, comme le fait `EcranPR3.champ`, n'en
# trouverait aucun.
func _trouver(nom: String) -> Control:
	if _plateau == null:
		return null
	return _plateau.find_child(nom, true, false) as Control


# Le champ texte d'un onglet, par son nom d'instance PR3.
func champ(nom: String) -> Label:
	return _trouver(nom) as Label


func montrer(nom_panneau: String) -> void:
	if not _panneaux.has(nom_panneau):
		return
	for cle in _panneaux:
		(_panneaux[cle] as Control).visible = (cle == nom_panneau)
	_actif = nom_panneau
	onglet_change.emit(nom_panneau)


func onglet() -> String:
	return _actif


# L'onglet « loupe », depuis une fiche de convoi du pont.
#
# CE QUI RESTE VIDE, ET POURQUOI. `tf_health` (l'état de coque en %) et
# `tf_strength` (la puissance) n'ont pas de source : la simulation ne modélise
# pas encore les dégâts, et la formule de puissance de PR3 n'est établie nulle
# part — on ne connaît que le nom du champ, vu aussi sur l'écran d'organisation
# et sur le résultat de bataille navale. Un champ vide dit la vérité ; un nombre
# inventé mentirait.
func poser_details(fiche: Dictionary) -> void:
	_poser("convoy", "tf_cargo", "%d/%d" % [int(fiche.get("charge", 0)),
			int(fiche.get("capacite", 0))])
	_poser("convoy", "tf_ships", str(int(fiche.get("navires", 0))))
	_poser("convoy", "tf_knot", str(int(fiche.get("noeuds", 0))))
	_poser("convoy", "tf_cannon", str(int(fiche.get("canons", 0))))
	_poser("convoy", "tf_crew", str(int(fiche.get("equipage", 0))))
	_poser("convoy", "tf_health", "")
	_poser("convoy", "tf_strength", "")


# L'onglet « route ». Le TYPE de route porte le nom que PR3 lui donne : la sim
# garde une clé (`profit`, `wealth`, `construct`…), le nom vient de la table du
# jeu (`ID_STRATEGY_*_NAME`), jamais d'une traduction de mon cru.
#
# LA ROTATION est mesurée, désormais, et le mot est celui du jeu : PR3 intitule
# ce champ « Dernière rotation : » (`ID_GUI_HUD_TROUTE_LAST_TOUR`). La sim clôt
# un tour quand le convoi ré-accoste à la première escale de son circuit, et
# retient sa durée et le gain net de sa caisse (voir `sim/marchands.lua`).
#
# TANT QU'AUCUN TOUR N'EST BOUCLÉ, la durée et le gain restent VIDES : un « 0 j »
# et un « 0 » se liraient comme une route qui tourne sans rien rapporter, ce qui
# est un autre fait que « on ne sait pas encore ».
func poser_route(fiche: Dictionary) -> void:
	_poser("route", "tf_name", str(fiche.get("nom", "")))
	_poser("route", "tf_towns", str(int(fiche.get("villes", 0))))
	_poser("route", "tf_tour", _nom_strategie(str(fiche.get("strategie", ""))))
	var tours := int(fiche.get("rotations", 0))
	_poser("route", "tf_time",
		("%d j" % int(fiche.get("rotation_jours", 0))) if tours > 0 else "")
	_poser("route", "tf_profit",
		HudDroitePR3.nombre(int(fiche.get("rotation_gain", 0))) if tours > 0 else "")
	# L'état porte les mots de PR3, pas les miens : « Route activée » / « Route
	# désactivée » sont dans sa table.
	_poser("route", "tf_state", _texte_jeu(
		"ID_GUI_HUD_TROUTE_ACTIVATED" if bool(fiche.get("route_active", false))
		else "ID_GUI_HUD_TROUTE_DEACTIVE"))


# Le texte du jeu pour cette clé, ou RIEN. `LocaPR3` RÉÉMET LA CLÉ quand la table
# est absente : sans ce test, la vignette afficherait « ID_GUI_HUD_TROUTE_ACTIVATED »
# en toutes lettres. C'est le même piège que pour le type de route, ci-dessous.
func _texte_jeu(cle: String) -> String:
	var t := LocaPR3.propre(cle, "")
	return "" if t == cle else t


func _nom_strategie(cle: String) -> String:
	if cle == "":
		return ""
	var k := "ID_STRATEGY_%s_NAME" % cle.to_upper()
	var nom := LocaPR3.propre(k, "")
	# `LocaPR3` RÉÉMET LA CLÉ quand la table manque : sans ce test, la vignette
	# afficherait « ID_STRATEGY_PROFIT_NAME » en toutes lettres.
	return "" if nom == k else nom


# L'onglet « tonneau » : la grille des marchandises portées.
#
# PR3 pose DOUZE cases (4 x 3) et deux flèches pour tourner les pages. Chaque
# case est un `Visual_ListButton_Goods`, fait de trois couches — la plaque, un
# éclat de plaque-texte sous elle, et le petit glyphe d'unité en bas à droite.
# AUCUNE n'est l'icône du produit : comme les pastilles de la minimap et la
# pièce d'or, PR3 l'assigne à l'exécution.
#
# L'ICÔNE EST `82 + rang`. Les vingt marchandises occupent les bitmaps 82 à 101
# de `skinlib_pr3`, sans trou, dans l'ordre canonique du jeu — wood 82, bricks
# 83, wheat 84, jusqu'à bread 101. Le rang vient du pont, qui le tient de
# l'ordre de `Marchandises.liste`. Se fier aux NOMS anglais aurait été piégeux :
# `fabric` est le tissu et `cloth` les vêtements, deux mots que seul l'ordre
# départage.
#
# LE CHAMP DE QUANTITÉ EST AJOUTÉ ICI. `textes.txt` déclare bien que cette classe
# porte du texte (16 px, police ordinaire), mais `EcranPR3` ne fabrique un
# `Label` que pour les classes `Visual_Textfeld` : un textbutton sort en pile
# d'images. On pose donc le champ sous l'icône, là où la couche `607.png` du jeu
# met sa plaque de texte.
const CASES := 12
const CASE_ICONE := Vector2(42, 42)
const CASE_TEXTE := Vector2(42, 18)
const ICONE_BOIS := 82        # le premier bitmap de la serie des marchandises

var _lots: Array = []
var _page := 0


func poser_cargaison(lots: Array) -> void:
	_lots = lots
	_page = 0
	_rafraichir_cargaison()


func _rafraichir_cargaison() -> void:
	var debut := _page * CASES
	for i in range(CASES):
		var case := _trouver("list_item_%d" % i)
		if case == null:
			continue
		var j := debut + i
		var lot: Dictionary = _lots[j] if j < _lots.size() else {}
		_poser_case(case, lot)


func _poser_case(case: Control, lot: Dictionary) -> void:
	# Les deux nœuds sont créés une seule fois et RÉUTILISÉS : la grille se
	# rafraîchit à chaque changement de page, et les recréer ferait des
	# allocations pour rien — même règle que les tracés de la minimap.
	var icone := case.get_node_or_null("icone") as TextureRect
	if icone == null:
		icone = TextureRect.new()
		icone.name = "icone"
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icone.size = CASE_ICONE
		case.add_child(icone)
	var qte := case.get_node_or_null("quantite") as Label
	if qte == null:
		qte = Label.new()
		qte.name = "quantite"
		qte.add_theme_font_size_override("font_size", 16)
		FontePR3.poser(qte)
		qte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		qte.position = Vector2(0, CASE_ICONE.y)
		qte.size = CASE_TEXTE
		case.add_child(qte)

	if lot.is_empty():
		icone.texture = null
		qte.text = ""
		return
	icone.texture = SkinPR3.texture(
		EcranPR3.SKIN + str(ICONE_BOIS + int(lot.get("rang", 0))))
	qte.text = str(int(lot.get("quantite", 0)))


# Combien de pages la cargaison occupe : au moins une, même vide.
func pages() -> int:
	return maxi(1, int(ceil(_lots.size() / float(CASES))))


func page() -> int:
	return _page


func tourner(pas: int) -> void:
	_page = clampi(_page + pas, 0, pages() - 1)
	_rafraichir_cargaison()


# LE CHAMP D'UN PANNEAU DONNÉ, et c'est indispensable : PLUSIEURS PANNEAUX
# DÉCLARENT LES MÊMES NOMS. `tf_cannon`, `tf_crew` et `tf_strength` existent dans
# l'onglet loupe ET dans l'onglet escorte ; `tf_name` dans la route ET le
# capitaine. Une recherche sur toute la carte tombe alors sur le champ d'un
# onglet CACHÉ, et la plaque visible reste blanche — ce qui se voyait à l'écran
# comme une vignette à moitié vide, les seuls champs remplis étant ceux dont le
# nom est unique (`tf_cargo`, `tf_ships`, `tf_knot`).
func champ_de(panneau: String, nom: String) -> Label:
	var p: Control = _panneaux.get(panneau)
	if p == null:
		return null
	return p.find_child(nom, true, false) as Label


func _poser(panneau: String, nom: String, valeur: String) -> void:
	var l := champ_de(panneau, nom)
	if l != null:
		l.text = valeur


# L'en-tête : le nom du convoi, et son message de situation.
#
# `situation` est déjà un texte : c'est à l'appelant de le composer avec les clés
# du jeu, parce que lui seul sait si le convoi est en mer, au combat, en
# réparation ou sur une route — et PR3 formate ce dernier cas
# (`ID_GUI_CONVOY_ON_ROUTE_NUM`, « %1 (%2) »).
func poser_entete(nom: String, situation: String) -> void:
	# MÊME PIÈGE QUE LES CHAMPS DES ONGLETS : `mctext` est déclaré DEUX FOIS dans
	# l'en-tête — une fois dans l'icône de tâche (`Visual_Convoy_Task_46`), une
	# fois dans le bouton du nom (`Buttonset_Text_Convoyname_48`). Une recherche
	# globale écrirait le message de situation dans le mauvais, et l'un des deux
	# resterait blanc. On descend donc par le nœud qui les distingue.
	var tache := _trouver("task")
	if tache != null:
		var s := tache.find_child("mctext", true, false) as Label
		if s != null:
			s.text = situation
	var bouton := _trouver("bu_name")
	if bouton != null:
		var t := bouton.find_child("mctext", true, false) as Label
		if t != null:
			t.text = nom
