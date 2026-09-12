# Le cartouche du temps : une horloge à gauche, la date sur son parchemin.
#
# L'aiguille TOURNE. Elle était peinte sur la planche, pointant vers deux heures ;
# `outils/extraire_aiguille.gd` l'en a détachée et a rebouché le cadran, d'où les
# deux fichiers : `menu_date_nu.png` pour le fond, `aiguille.png` pour elle seule,
# centrée sur son pivot. On ne garde que les heures : à douze secondes la journée,
# une trotteuse tournerait comme un ventilateur et ne dirait rien de plus.
#
# Tout se repère en FRACTIONS de la planche, comme pour la barre du temps : la
# fenêtre change de taille, pas les proportions du dessin.
class_name PanneauDate
extends Control

const PLANCHE := "res://sprites/ui_pr/menu_date_nu.png"
const AIGUILLE := "res://sprites/ui_pr/aiguille.png"
const POLICE := "res://polices/serif_gras.ttf"

const TAILLE_SOURCE := Vector2(1311, 539)

# Relevés par l'outil d'extraction, en pixels de la planche.
const CENTRE_CADRAN := Vector2(280.0, 244.5)
const AIGUILLE_SOURCE := 192.0
# L'angle vers lequel l'aiguille était peinte. C'est de lui qu'on part : la
# rotation appliquée est la différence entre l'heure à montrer et cette pose.
const ANGLE_PEINT := -28.9

# Le parchemin, en fractions : où poser la date.
const PARCHEMIN := Rect2(0.355, 0.255, 0.395, 0.375)

const ENCRE := Color(0.26, 0.17, 0.09)

var _planche: TextureRect
var _aiguille: TextureRect
var _date: Label
var _heure_affichee := -1.0


func _init() -> void:
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

	# L'aiguille tourne autour de SON centre, qui est le pivot du cadran : le
	# pivot de rotation se règle donc à la moitié de sa propre texture.
	_aiguille = TextureRect.new()
	_aiguille.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_aiguille.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_aiguille.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(AIGUILLE):
		_aiguille.texture = load(AIGUILLE)
	add_child(_aiguille)

	_date = Label.new()
	_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_date.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_date.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_date.add_theme_color_override("font_color", ENCRE)
	_date.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(POLICE):
		_date.add_theme_font_override("font", load(POLICE))
	add_child(_date)

	resized.connect(_replacer)
	_replacer()


# Le rectangle réellement peint : la planche garde ses proportions et se centre,
# donc les repères doivent suivre le dessin, pas le cadre du Control.
func _rect_dessine() -> Rect2:
	var r := TAILLE_SOURCE.x / TAILLE_SOURCE.y
	var large := size.x
	var haut := size.x / r
	if haut > size.y:
		haut = size.y
		large = size.y * r
	return Rect2((size - Vector2(large, haut)) * 0.5, Vector2(large, haut))


func _replacer() -> void:
	if _aiguille == null:
		return
	var d := _rect_dessine()
	var ech := d.size.x / TAILLE_SOURCE.x

	var cote := AIGUILLE_SOURCE * ech
	_aiguille.size = Vector2(cote, cote)
	_aiguille.pivot_offset = Vector2(cote, cote) * 0.5
	_aiguille.position = (d.position + CENTRE_CADRAN * ech
		- Vector2(cote, cote) * 0.5)

	_date.position = d.position + Vector2(
		PARCHEMIN.position.x * d.size.x, PARCHEMIN.position.y * d.size.y)
	_date.size = Vector2(PARCHEMIN.size.x * d.size.x, PARCHEMIN.size.y * d.size.y)
	_date.add_theme_font_size_override("font_size",
		int(maxf(d.size.y * 0.105, 10.0)))


# `heure` est en heures décimales : 14,5 vaut quatorze heures trente.
func poser(texte_date: String, heure: float) -> void:
	if _date == null:
		return
	_date.text = texte_date
	# On ne remue l'aiguille que si elle a changé d'heure : la rotation force un
	# redessin, et le cartouche se rafraîchit à chaque image.
	var h := floorf(heure)
	if is_equal_approx(h, _heure_affichee):
		return
	_heure_affichee = h
	# Midi en haut : l'aiguille avance de 30° par heure, et 0° pointe à droite
	# dans les angles de Godot, d'où le quart de tour retranché.
	var vise := -90.0 + fmod(h, 12.0) * 30.0
	_aiguille.rotation_degrees = vise - ANGLE_PEINT
