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

# --- la minimap ---------------------------------------------------------------
#
# Le nœud `towns` est posé en (-200,59), c'est-à-dire EXACTEMENT sur la carte des
# mers : son repère local est donc le pixel de minimap, sans conversion.
const MINIMAP := Vector2(196, 156)

# Le cadrage de 12.png par rapport à la grande carte. MESURÉ, pas deviné, par
# `outils/test_minimap.gd` : on projette les soixante ports et on regarde à
# quelle distance du littoral ils tombent.
#   sans cadrage : 22 ports à 1 px ou moins, 19 au-delà de 4 px, 1 hors cadre
#   avec         : 50 à 1 px ou moins, AUCUN au-delà de 4, aucun hors cadre
#   au hasard    : 27 % des points sont à 2 px ou moins
# La moyenne passe de 3,1 px à 0,7 px. Les échecs sans cadrage étaient groupés —
# toute la côte du Golfe, puis la façade atlantique — donc systématiques.
const CADRAGE_KU := 1.070
const CADRAGE_DU := 0.020
const CADRAGE_KV := 0.930
const CADRAGE_DV := 0.025

# Les marqueurs de PR3, tous en 8x8 centrés sur leur point.
const PASTILLE := Vector2(8, 8)
const PASTILLE_VILLE := "hud_pc/24"      # une ville
const PASTILLE_CONVOI := "hud_pc/38"     # un convoi à quai

# Un convoi EN MER n'a pas de bitmap dans le .swf : PR3 le trace au runtime
# (`Visual_Minimap_Frame` ne mène à aucune image). On pose donc un point d'or,
# et c'est la seule chose ici qui ne vienne pas de l'art du jeu.
const OR_CONVOI := Color(0.98, 0.82, 0.35)
const OR_CHOISI := Color(1.0, 0.97, 0.80)

var _villes_posees := false

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


# Monde -> pixel de la minimap, EN PASSANT PAR la projection de la grande carte.
# On ne réécrit pas une seconde projection : la minimap et la carte doivent
# s'accorder, et deux sources finiraient par diverger.
func _vers_minimap(proj: ProjectionCarte, x: float, z: float) -> Vector2:
	var pix := proj.vers_carte(x, z)
	var u := 0.5 + (pix.x / float(proj.pixels.x) - 0.5) * CADRAGE_KU + CADRAGE_DU
	var v := 0.5 + (pix.y / float(proj.pixels.y) - 0.5) * CADRAGE_KV + CADRAGE_DV
	return Vector2(u * MINIMAP.x, v * MINIMAP.y)


func _pastille(hote: Control, cle: String, centre: Vector2) -> void:
	var tex := SkinPR3.texture(cle)
	if tex == null:
		return
	var m := TextureRect.new()
	m.texture = tex
	m.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	m.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.size = PASTILLE
	m.position = centre - PASTILLE * 0.5
	hote.add_child(m)


# Les soixante villes. Elles ne bougent jamais : on les pose une seule fois.
#
# PR3 distingue la ville ordinaire (24.png) du comptoir du joueur (31.png). On
# n'utilise que la première : le pont n'expose pas encore de drapeau « comptoir »,
# et je ne vais pas deviner lesquelles le sont.
func poser_villes(ports: Array, proj: ProjectionCarte) -> void:
	if _villes_posees or proj == null or not proj.valide:
		return
	var hote := EcranPR3.champ(_plateau, "towns")
	if hote == null:
		return
	for e in hote.get_children():
		e.queue_free()
	for p in ports:
		var d: Dictionary = p
		var rade: Vector3 = d["rade"]
		_pastille(hote, PASTILLE_VILLE, _vers_minimap(proj, rade.x, rade.z))
	_villes_posees = true


# Les convois du joueur, relus à chaque image : ceux-là bougent.
func poser_convois(convois: Array, proj: ProjectionCarte) -> void:
	if proj == null or not proj.valide:
		return
	var hote := EcranPR3.champ(_plateau, "minimap_ships")
	if hote == null:
		return
	for e in hote.get_children():
		e.queue_free()
	for c in convois:
		var d: Dictionary = c
		var pos: Vector2 = d.get("position", Vector2.ZERO)
		var point := _vers_minimap(proj, pos.x, pos.y)
		if bool(d.get("a_quai", false)):
			_pastille(hote, PASTILLE_CONVOI, point)
			continue
		var r := ColorRect.new()
		r.color = OR_CHOISI if bool(d.get("selectionne", false)) else OR_CONVOI
		r.size = Vector2(3, 3)
		r.position = point - Vector2(1.5, 1.5)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hote.add_child(r)


func poser(or_: int, en_mer: int, a_quai: int) -> void:
	if _or != null:
		_or.text = nombre(or_)
	if _en_mer != null:
		_en_mer.text = str(en_mer)
	if _a_quai != null:
		_a_quai.text = str(a_quai)
