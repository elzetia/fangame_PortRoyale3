# Le bandeau qui porte une ligne de marchandise.
#
# Ce n'est pas un simple rectangle : il part en POINTE sous la vignette. Un bord
# droit se voyait dépasser tout autour de la denrée — les images sont détourées,
# donc le coin du bandeau apparaissait dans le vide laissé par la silhouette. La
# pointe, elle, disparaît derrière l'image : la ligne semble naître de la denrée
# au lieu de commencer à côté d'elle.
#
# Dessiné plutôt que composé d'un StyleBox : aucune boîte de Godot ne fait de
# biseau, et l'approcher avec des bordures aurait demandé plus de réglages que
# ces quatre points.
class_name FondLigne
extends Control

var couleur := Color(0.42, 0.32, 0.18, 0.13)
# Où la pointe commence, depuis le bord gauche : on la veut sous la vignette.
var depart := 16.0
# Longueur du biseau.
var pointe := 18.0
# De combien le bandeau est plus mince que la ligne, en haut et en bas. C'est ce
# qui laisse un filet de fond entre deux lignes sans avoir à tracer un trait.
var finesse := 3.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var haut := finesse
	var bas := size.y - finesse
	if bas <= haut or size.x <= depart:
		return
	var x0 := depart
	var x1 := minf(depart + pointe, size.x)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x0, (haut + bas) * 0.5),
		Vector2(x1, haut),
		Vector2(size.x, haut),
		Vector2(size.x, bas),
		Vector2(x1, bas),
	]), couleur)


func rafraichir() -> void:
	queue_redraw()
