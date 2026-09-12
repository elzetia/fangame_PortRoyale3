# L'écran de chargement.
#
# Il existe pour une raison mécanique, pas décorative : tout le démarrage tenait
# dans `_ready`, or Godot ne dessine RIEN avant que `_ready` ait rendu la main.
# La fenêtre restait donc absente une vingtaine de secondes — ce qui ressemble
# beaucoup à un plantage silencieux, d'autant que sur un Mac Intel un vrai
# échec de rendu produit exactement le même symptôme.
#
# La carte annonce donc ses étapes une par une, en laissant passer une image
# entre chacune. Le chargement n'en va pas plus vite ; il devient visible.
class_name Chargement
extends CanvasLayer

const BOIS := Color(0.07, 0.05, 0.04)
const ENCRE := Color(0.95, 0.88, 0.72)
const LISERE := Color(0.72, 0.58, 0.34)

var _etape: Label
var _jauge: ColorRect
var _jauge_fond: ColorRect


func _init() -> void:
	layer = 128          # au-dessus de tout, nuages compris

	var fond := ColorRect.new()
	fond.color = BOIS
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fond)

	var centre := VBoxContainer.new()
	centre.set_anchors_preset(Control.PRESET_CENTER)
	centre.grow_horizontal = Control.GROW_DIRECTION_BOTH
	centre.grow_vertical = Control.GROW_DIRECTION_BOTH
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_theme_constant_override("separation", 14)
	add_child(centre)

	var titre := Label.new()
	titre.text = "Port Royale : Under the wind"
	titre.add_theme_font_size_override("font_size", 44)
	titre.add_theme_color_override("font_color", ENCRE)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre.add_child(titre)

	_etape = Label.new()
	_etape.add_theme_font_size_override("font_size", 16)
	_etape.add_theme_color_override("font_color", LISERE)
	_etape.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre.add_child(_etape)

	# La jauge : deux rectangles, parce qu'une ProgressBar traînerait tout le
	# thème par défaut avec elle pour un trait de six pixels.
	_jauge_fond = ColorRect.new()
	_jauge_fond.color = Color(LISERE.r, LISERE.g, LISERE.b, 0.22)
	_jauge_fond.custom_minimum_size = Vector2(360, 6)
	centre.add_child(_jauge_fond)

	_jauge = ColorRect.new()
	_jauge.color = LISERE
	_jauge.position = Vector2.ZERO
	_jauge.size = Vector2(0, 6)
	_jauge_fond.add_child(_jauge)


# Annonce une étape et rend la main le temps d'une image, pour que l'annonce
# soit réellement peinte avant que l'étape ne bloque le fil.
func avancer(nom: String, fait: int, total: int) -> void:
	_etape.text = nom
	var part := clampf(float(fait) / float(maxi(total, 1)), 0.0, 1.0)
	_jauge.size = Vector2(_jauge_fond.size.x * part, 6)
	await get_tree().process_frame
	await get_tree().process_frame
