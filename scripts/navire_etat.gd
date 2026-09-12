# État d'un navire, en coordonnées monde (x, z), sans rien savoir de l'affichage.
#
# Séparé du rendu : la carte est désormais une image en plongée oblique, mais le
# navire, lui, continue de naviguer dans un plan bien plat. C'est la projection
# qui fait le lien au moment de dessiner.
class_name NavireEtat
extends RefCounted

signal arrive(port)

var position := Vector2.ZERO        # monde (x, z)
var cap := 0.0                      # radians dans le plan monde
var vitesse_monde := 75.0           # mètres monde par seconde de jeu, à x1
var route: Array[Vector2] = []
var destination: Dictionary = {}

const TAUX_VIRAGE := 1.8


func cap_sur(points: PackedVector3Array, port: Dictionary) -> void:
	route.clear()
	for p in points:
		route.append(Vector2(p.x, p.z))
	destination = port


func au_mouillage() -> bool:
	return route.is_empty()


func distance_restante() -> float:
	var d := 0.0
	var p := position
	for wp in route:
		d += p.distance_to(wp)
		p = wp
	return d


func avancer(delta_jeu: float) -> void:
	if route.is_empty():
		return

	var budget := vitesse_monde * delta_jeu

	while budget > 0.0 and not route.is_empty():
		var cible: Vector2 = route[0]
		var d := position.distance_to(cible)
		if d <= budget:
			position = cible
			budget -= d
			route.remove_at(0)
			if route.is_empty():
				var port := destination
				destination = {}
				arrive.emit(port)
				return
		else:
			position = position.lerp(cible, budget / d)
			budget = 0.0

	# On vise le prochain point sans pivoter d'un bloc
	if not route.is_empty():
		var vers: Vector2 = route[0] - position
		if vers.length_squared() > 0.01:
			cap = lerp_angle(cap, atan2(vers.y, vers.x),
							 clampf(delta_jeu * TAUX_VIRAGE, 0.0, 1.0))
