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
	_plateau = EcranPR3.batir(SWF, PLANCHE, true, PROFONDEUR)
	add_child(_plateau)

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
	_poser("tf_cargo", "%d/%d" % [int(fiche.get("charge", 0)),
			int(fiche.get("capacite", 0))])
	_poser("tf_ships", str(int(fiche.get("navires", 0))))
	_poser("tf_knot", str(int(fiche.get("noeuds", 0))))
	_poser("tf_cannon", str(int(fiche.get("canons", 0))))
	_poser("tf_crew", str(int(fiche.get("equipage", 0))))
	_poser("tf_health", "")
	_poser("tf_strength", "")


# L'onglet « route ». Le TYPE de route porte le nom que PR3 lui donne : la sim
# garde une clé (`profit`, `wealth`, `construct`…), le nom vient de la table du
# jeu (`ID_STRATEGY_*_NAME`), jamais d'une traduction de mon cru.
#
# `tf_time`, `tf_profit` et l'état actif restent vides : la sim ne mesure pas
# encore les rotations.
func poser_route(fiche: Dictionary) -> void:
	_poser("tf_name", str(fiche.get("nom", "")))
	_poser("tf_towns", str(int(fiche.get("villes", 0))))
	_poser("tf_tour", _nom_strategie(str(fiche.get("strategie", ""))))
	_poser("tf_time", "")
	_poser("tf_profit", "")
	_poser("tf_state", "")


func _nom_strategie(cle: String) -> String:
	if cle == "":
		return ""
	var k := "ID_STRATEGY_%s_NAME" % cle.to_upper()
	var nom := LocaPR3.propre(k, "")
	# `LocaPR3` RÉÉMET LA CLÉ quand la table manque : sans ce test, la vignette
	# afficherait « ID_STRATEGY_PROFIT_NAME » en toutes lettres.
	return "" if nom == k else nom


func _poser(nom: String, valeur: String) -> void:
	var l := champ(nom)
	if l != null:
		l.text = valeur


# L'en-tête : le nom du convoi, et son message de situation.
#
# `situation` est déjà un texte : c'est à l'appelant de le composer avec les clés
# du jeu, parce que lui seul sait si le convoi est en mer, au combat, en
# réparation ou sur une route — et PR3 formate ce dernier cas
# (`ID_GUI_CONVOY_ON_ROUTE_NUM`, « %1 (%2) »).
func poser_entete(nom: String, situation: String) -> void:
	var etiquette := champ("mctext")
	if etiquette != null:
		etiquette.text = situation
	var bouton := _trouver("bu_name")
	if bouton != null:
		var t := bouton.find_child("mctext", true, false) as Label
		if t != null:
			t.text = nom
