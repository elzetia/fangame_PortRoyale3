# La planche de gauche du HUD de Port Royale 3 — la vraie, rejouée.
#
# `Hud_pc_fla.Hud_Woodboard_Left_PC_68` (hud_pc.swf), décodé par
# `outils/swf_export.py` : une planche de bois de 210x66 (skinlib_pr3/639), une
# plaque de texte, deux petits boutons d'allure et le bouton rond de la
# chronique. Elle remplace `PanneauDate` et `BarreVitesse`, deux planches PEINTES
# À LA MAIN (`sprites/ui_pr/*.png`) faute d'avoir su lire l'art du jeu.
#
# Ce que PR3 pose dessus, au pixel :
#   bu_chronic   (33,30)   la chronique
#   tf_date      (65,5)    la date
#   bu_minus     (96,36)   ralentir
#   tf_gamespeed (112,25)  l'allure, sur sa plaque `Text_Bg_Nomal`
#   bu_plus      (167,36)  accélérer
#
# L'ANCRAGE, qui n'était pas donné : le .swf livre la translation du placement,
# jamais les bornes du symbole placé. Les deux règles se DÉDUISENT de la mise en
# page, elles ne sont pas supposées —
#   * plaques et champs sont posés par leur COIN : `Text_Bg_Nomal` (40 de large)
#     et `tf_gamespeed` (38) partagent le point (112,25). Ils ne se recouvrent
#     qu'à cette condition ;
#   * les boutons sont posés par leur CENTRE : bu_minus occupe alors 82..110 et
#     bu_plus 153..181, de part et d'autre de la plaque 112..152 — deux pixels de
#     jeu d'un côté, un de l'autre. Posés par le coin, ils la chevaucheraient.
#     Le même constat avait été fait sur `bu_action` du chantier.
# La planche se referme alors sur elle-même : 14 px de marge à gauche (bu_chronic
# commence à 14), 15 à droite (tf_date finit à 195 sur 210).
#
# PAS DE BOUTON PAUSE : PR3 n'en met pas sur cette planche. L'indice 1 du
# calendrier EST la pause, et `bu_minus` y descend ; la barre d'espace la garde
# aussi. C'est un geste de moins qu'avec `BarreVitesse`, et c'est ce que fait le
# jeu.
class_name HudPR3
extends Control

# L'indice tel que le calendrier le compte : 1 = pause, 2 = x1, 3 = x3, 4 = x5.
signal vitesse_choisie(indice: int)
signal chronique_demandee

const SWF := "hud_pc"
const PLANCHE := "Hud_pc_fla.Hud_Woodboard_Left_PC_68"
# La taille de `HUD_Woodboard_Left_Top` (skinlib_pr3/639.png), donc de la planche.
const TAILLE := Vector2(210, 66)

const INDICE_MIN := 1
const INDICE_MAX := 4

const ENCRE := Color(0.16, 0.10, 0.05)
# Pendant un survol (barre d'espace tenue), l'allure n'est pas celle qu'on a
# choisie : on la distingue à l'encre plutôt que d'inventer un sigle.
const ENCRE_SURVOL := Color(0.10, 0.24, 0.42)

var _plateau: Control
var _date: Label
var _allure: Label
var _indice := 2


func _ready() -> void:
	# PASS et non IGNORE : la planche ne prend pas le clic pour elle, mais ses
	# boutons doivent le recevoir.
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = TAILLE
	size = TAILLE

	# `repli` ouvert : cette planche est justement faite de classes qui ne portent
	# leur image que par la table — le bois, les boutons ronds. Les cinq images
	# qu'elle en tire ont été vérifiées une à une.
	_plateau = EcranPR3.batir(SWF, PLANCHE, true)
	add_child(_plateau)

	# `gr_scenario_info` pend SOUS la planche, en (-20,66), et ne sert qu'en
	# scénario. Son art n'est pas encore résolu (il bute sur `char72`, une forme
	# dont le bitmap demande la table des caractères anonymes) : on l'enlève
	# plutôt que de laisser un nœud vide traîner sous le bois.
	var scenario := EcranPR3.champ(_plateau, "gr_scenario_info")
	if scenario != null:
		scenario.queue_free()

	_date = EcranPR3.champ(_plateau, "tf_date") as Label
	_allure = EcranPR3.champ(_plateau, "tf_gamespeed") as Label
	for etiquette in [_date, _allure]:
		if etiquette != null:
			etiquette.add_theme_color_override("font_color", ENCRE)

	# Le SIGNE est porté par le bouton, pas par son image : `453.png` n'est que la
	# plaque d'or. Composer l'art à la main (planche 639 + 1037 + 453 x2 aux
	# coordonnées ci-dessus) montre deux carrés d'or NUS — c'est ce que verrait le
	# joueur sans ces libellés. `Visual_Textbutton_Standard_Tiny` porte bien son
	# nom : dans PR3 le glyphe est du TEXTE posé sur la plaque.
	# Les infobulles sont celles DU JEU, pas les miennes. Leurs clés vivent dans
	# le bytecode des .swf, un gisement que `pr3_loca.py` ne fouillait pas : je
	# les avais donc écrites à la main (« Accélérer », « Ralentir »), faute de
	# pouvoir les lire. PR3 dit « Augmenter la vitesse du jeu ».
	_armer("bu_minus", "−",
		LocaPR3.propre("ID_GUI_TT_HUD_BTN_GAMESPEED_DECREASE", "Ralentir"),
		func() -> void: _changer(-1))
	_armer("bu_plus", "+",
		LocaPR3.propre("ID_GUI_TT_HUD_BTN_GAMESPEED_INCREASE", "Accélérer"),
		func() -> void: _changer(1))
	# La chronique, elle, a son glyphe peint dans l'image (un sablier) : pas de
	# libellé à ajouter.
	_armer("bu_chronic", "",
		LocaPR3.propre("ID_GUI_TT_VISUAL_ROUNDBUTTON_CHRONIK", "Chronique"),
		func() -> void: chronique_demandee.emit())


# Recentre l'image d'un bouton sur son point — voir l'en-tête —, puis pose
# par-dessus une zone sensible transparente : `EcranPR3` rend des images inertes,
# jamais des boutons.
func _armer(nom: String, libelle: String, infobulle: String, geste: Callable) -> void:
	# Le recentrage et la zone sensible vivent dans `EcranPR3.bouton()` : les
	# deux planches du HUD les partagent, et la règle d'ancrage par le centre n'a
	# ainsi qu'un seul endroit où être juste.
	var zone := EcranPR3.bouton(_plateau, nom, libelle, infobulle)
	if zone != null:
		zone.pressed.connect(geste)


# Les boutons ne choisissent pas une allure, ils la déplacent d'un cran — c'est
# un « + » et un « − », pas trois boutons d'allure. L'indice courant vient du
# calendrier, jamais d'un compte tenu ici : il change aussi au clavier.
func _changer(pas: int) -> void:
	var vise := clampi(_indice + pas, INDICE_MIN, INDICE_MAX)
	if vise != _indice:
		vitesse_choisie.emit(vise)


func _libelle(indice: int) -> String:
	match indice:
		1: return "II"
		2: return "x1"
		3: return "x3"
		4: return "x5"
	return "x1"


# `indice` est celui du calendrier ; `survol` dit qu'on tient la barre d'espace.
func poser(date: String, indice: int, survol: bool) -> void:
	_indice = indice
	if _date != null:
		_date.text = date
	if _allure == null:
		return
	_allure.text = "x10" if survol else _libelle(indice)
	_allure.add_theme_color_override("font_color",
		ENCRE_SURVOL if survol else ENCRE)
