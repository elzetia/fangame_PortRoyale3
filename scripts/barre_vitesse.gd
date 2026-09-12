# La barre du temps : le gouvernail met en panne, les trois boutons donnent
# l'allure, et la plaque de droite affiche celle qui tourne.
#
# Tout est peint sur une seule image (`vitesse.png`). On ne pose donc pas de
# boutons habillés par-dessus, mais des zones sensibles transparentes, repérées
# en FRACTIONS de l'image et non en pixels : la barre se redimensionne avec la
# fenêtre, et des coordonnées en dur auraient glissé hors des ronds dorés dès
# qu'on change son échelle.
class_name BarreVitesse
extends Control

# L'indice tel que le calendrier le compte : 1 = pause, 2 = x1, 3 = x3, 4 = x5.
signal vitesse_choisie(indice: int)
signal pause_demandee

const PLANCHE := "res://sprites/ui_pr/vitesse.png"
const POLICE := "res://polices/serif_gras.ttf"

const TAILLE_SOURCE := Vector2(839, 341)

# Relevés sur la planche, en fractions de sa largeur et de sa hauteur.
const RONDS := {
	"pause": Vector2(0.176, 0.505),
	"v1":    Vector2(0.379, 0.575),
	"v2":    Vector2(0.516, 0.575),
	"v3":    Vector2(0.659, 0.575),
}
const RAYON_ROND := 0.062          # en fraction de la largeur
const RAYON_ROUE := 0.078          # le gouvernail est plus large

# La plaque bleue, à droite : centre et demi-dimensions.
const PLAQUE := Vector2(0.834, 0.575)
const PLAQUE_DEMI := Vector2(0.056, 0.135)

const OR_PALE := Color(0.98, 0.92, 0.76)
const BLEU_PALE := Color(0.72, 0.86, 0.94)

var _planche: TextureRect
var _etiquette: Label
var _zones := {}


func _init() -> void:
	# Pas de taille minimale : c'est l'appelant qui décide de l'échelle. Figée
	# ici à la moitié de la planche, elle l'emportait sur les marges posées par
	# le HUD et la barre se retrouvait coupée par le bord de l'écran.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_planche = TextureRect.new()
	_planche.set_anchors_preset(Control.PRESET_FULL_RECT)
	_planche.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_planche.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_planche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(PLANCHE):
		_planche.texture = load(PLANCHE)
	add_child(_planche)

	for nom in RONDS.keys():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		var cle := String(nom)
		if cle == "pause":
			b.tooltip_text = "Pause — barre d'espace"
			b.pressed.connect(func() -> void: pause_demandee.emit())
		else:
			# v1 → indice 2, v2 → 3, v3 → 4 : le calendrier garde la pause en 1.
			var indice := int(cle.substr(1)) + 1
			b.tooltip_text = "Vitesse %s" % _libelle(indice)
			b.pressed.connect(func() -> void: vitesse_choisie.emit(indice))
		_zones[cle] = b
		add_child(b)

	# Le chiffre dans la plaque : ce n'est pas un bouton, seulement le rappel de
	# l'allure en cours. Sans lui, trois boutons ronds se ressemblent trop pour
	# qu'on sache lequel est enfoncé d'un coup d'œil.
	_etiquette = Label.new()
	_etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiquette.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_etiquette.add_theme_color_override("font_color", OR_PALE)
	_etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(POLICE):
		_etiquette.add_theme_font_override("font", load(POLICE))
	add_child(_etiquette)

	resized.connect(_replacer)
	_replacer()


func _libelle(indice: int) -> String:
	match indice:
		1: return "II"
		2: return "x1"
		3: return "x3"
		4: return "x5"
	return "x1"


# L'image garde ses proportions et se centre : les zones doivent donc suivre le
# RECTANGLE RÉELLEMENT DESSINÉ, pas celui du Control, sinon elles dérivent dès
# que la barre n'a pas exactement le rapport de la planche.
func _rect_dessine() -> Rect2:
	var r := TAILLE_SOURCE.x / TAILLE_SOURCE.y
	var large := size.x
	var haut := size.x / r
	if haut > size.y:
		haut = size.y
		large = size.y * r
	return Rect2((size - Vector2(large, haut)) * 0.5, Vector2(large, haut))


func _replacer() -> void:
	if _etiquette == null:
		return
	var d := _rect_dessine()
	for nom in _zones.keys():
		var b: Button = _zones[nom]
		var frac: Vector2 = RONDS[nom]
		var rayon: float = (RAYON_ROUE if nom == "pause" else RAYON_ROND) * d.size.x
		b.size = Vector2(rayon, rayon) * 2.0
		b.position = d.position + Vector2(frac.x * d.size.x, frac.y * d.size.y) - b.size * 0.5

	var demi := Vector2(PLAQUE_DEMI.x * d.size.x, PLAQUE_DEMI.y * d.size.y)
	_etiquette.size = demi * 2.0
	_etiquette.position = (d.position
		+ Vector2(PLAQUE.x * d.size.x, PLAQUE.y * d.size.y) - demi)
	_etiquette.add_theme_font_size_override("font_size", int(maxf(demi.y * 0.9, 10.0)))


# `indice` est celui du calendrier ; `survol` dit qu'on tient la barre d'espace.
func poser(indice: int, survol: bool) -> void:
	if _etiquette == null:
		return
	if survol:
		_etiquette.text = "x10"
		_etiquette.add_theme_color_override("font_color", BLEU_PALE)
	else:
		_etiquette.text = _libelle(indice)
		_etiquette.add_theme_color_override("font_color", OR_PALE)
