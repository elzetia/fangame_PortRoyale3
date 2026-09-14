# La planche de droite du HUD de Port Royale 3 — la minimap et la bourse.
#
# `Hud_pc_fla.Hud_Woodboard_Right_3` (hud_pc.swf), rejouée. Elle ne tient debout
# que grâce à deux choses acquises juste avant elle :
#
#  1. la TABLE DES CARACTÈRES ANONYMES (`outils/swf_caracteres.py`) : le cadre
#     (char172), la carte des mers (char14) et la barre d'XP (char62, char68)
#     n'ont aucun nom de classe. Sans cette table, la planche était nue ;
#  2. la RÉCURSION dans les conteneurs : le fond, la minimap et la barre d'XP
#     sont des sprites imbriqués, que `batir()` rendait en Control 1x1.
#
# ANCRAGE : tous les enfants ont un x NÉGATIF (-207 à -27). Cette planche est
# donc conçue ancrée par son BORD DROIT — et c'est ainsi qu'on la pose, ancrée
# en haut à droite, ses enfants gardant leurs coordonnées d'origine.
#
# CE QUI RESTE VIDE, ET POURQUOI. PR3 remplit au runtime la liste des 60 villes
# (`Minimap_Steadte_Liste_14`), les tracés de route, les navires et le cadre de
# vue (`Visual_Minimap_Frame`), et les batailles (`Visual_Minimap_Mc_Objects`).
# Dans le .swf, TOUS les membres de ces collections sont empilés au même point
# d'auteur : composer la planche à la main les faisait sortir en un bloc de
# losanges bleus flottant hors du cadre. `EcranPR3.RUNTIME` les écarte donc ;
# leurs nœuds existent, nommés et vides, et c'est à la simulation de les peupler
# — chaque ville à sa place sur la carte, ce qui reste à faire.
#
# `tf_rang` n'est PAS renseigné. PR3 a une notion de rang (Krämer… Patrizier) ;
# la simulation n'en a aucune, et je ne vais pas en inventer une pour remplir un
# champ. Il reste vide tant que le rang n'est pas dérivé du jeu.
class_name HudDroitePR3
extends Control

signal liste_demandee
signal journal_demande
signal carte_basculee

const SWF := "hud_pc"
const PLANCHE := "Hud_pc_fla.Hud_Woodboard_Right_3"
# Assez pour descendre fond > minimap > masque et barre d'XP > jauge.
const PROFONDEUR := 4

# Le cadre (char172) commence à -207 et la planche descend jusqu'à 273.
const TAILLE := Vector2(207, 275)

const ENCRE := Color(0.93, 0.88, 0.76)

var _plateau: Control
var _or: Label
var _rang: Label
var _en_mer: Label
var _a_quai: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = TAILLE
	size = TAILLE

	_plateau = EcranPR3.batir(SWF, PLANCHE, true, PROFONDEUR)
	add_child(_plateau)

	_or = EcranPR3.champ(_plateau, "tf_gold") as Label
	_rang = EcranPR3.champ(_plateau, "tf_rang") as Label
	_en_mer = EcranPR3.champ(_plateau, "tf_on_sea") as Label
	_a_quai = EcranPR3.champ(_plateau, "tf_anchor") as Label
	# L'or et le rang sont posés sur le bois, pas sur une plaque claire : encre
	# pâle. Les deux compteurs, eux, ont leur plaque `Text_Bg_Nomal`.
	for clair in [_or, _rang]:
		if clair != null:
			clair.add_theme_color_override("font_color", ENCRE)

	_armer("bu_liste", "Convois", func() -> void: liste_demandee.emit())
	_armer("bu_logbook", "Journal de bord", func() -> void: journal_demande.emit())
	_armer("bu_switch", "Changer de carte", func() -> void: carte_basculee.emit())
	# `bu_anchor` et `bu_on_sea` filtrent la liste des convois dans PR3. Sans
	# écran de liste, les brancher ne ferait rien : on les laisse inertes plutôt
	# que d'émettre un signal que personne n'écoute.


func _armer(nom: String, infobulle: String, geste: Callable) -> void:
	var zone := EcranPR3.bouton(_plateau, nom, "", infobulle)
	if zone != null:
		zone.pressed.connect(geste)


# Sépare les milliers : « 12 480 » se lit, « 12480 » se compte.
static func nombre(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = " " + out
	return ("-" if n < 0 else "") + out


func poser(or_: int, en_mer: int, a_quai: int) -> void:
	if _or != null:
		_or.text = nombre(or_)
	if _en_mer != null:
		_en_mer.text = str(en_mer)
	if _a_quai != null:
		_a_quai.text = str(a_quai)
