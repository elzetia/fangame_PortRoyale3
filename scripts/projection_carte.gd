# La projection de la carte cuite.
#
# La carte est rendue en plongée oblique : un point du monde n'y tombe donc pas
# à sa simple position en x/z, l'altitude et la profondeur nord-sud se mélangent
# à l'écran. Tout ce qui doit se poser sur la carte — navires, ports, routes —
# passe par ici.
#
# Les chiffres viennent de la fiche écrite par la cuisson, jamais de constantes
# recopiées : c'est ce qui garantit que le décor et la simulation restent d'accord.
class_name ProjectionCarte
extends RefCounted

var angle := 58.0
var centre := Vector2.ZERO      # centre de la zone, en mètres monde (x, z)
var vue_taille := Vector2.ONE   # étendue du plan de projection, en mètres
var pixels := Vector2i.ONE
# La couleur de l'eau du large, mesurée sur l'illustration par
# `outils/carte_eau.py`. C'est elle qu'on voit là où l'illustration a rendu le
# large à la nappe animée.
var mer_fond := Color(0.0, 0.30, 0.52)
var valide := false
var erreur := ""

var _sin: float
var _cos: float


func _init(chemin_fiche: String = "") -> void:
	if chemin_fiche != "":
		charger(chemin_fiche)


func charger(chemin: String) -> bool:
	if not FileAccess.file_exists(chemin):
		erreur = "fiche de projection absente : %s" % chemin
		return false
	var texte := FileAccess.get_file_as_string(chemin)
	var d = JSON.parse_string(texte)
	if typeof(d) != TYPE_DICTIONARY:
		erreur = "fiche de projection illisible : %s" % chemin
		return false

	angle = float(d.get("angle", 58.0))
	var c: Array = d.get("centre", [0.0, 0.0])
	centre = Vector2(c[0], c[1])
	var t: Array = d.get("vue_taille", [1.0, 1.0])
	vue_taille = Vector2(t[0], t[1])
	var p: Array = d.get("pixels", [1, 1])
	pixels = Vector2i(int(p[0]), int(p[1]))
	if d.has("mer_fond"):
		var f: Array = d["mer_fond"]
		mer_fond = Color(f[0], f[1], f[2])

	_sin = sin(deg_to_rad(angle))
	_cos = cos(deg_to_rad(angle))
	valide = true
	return true


# Construit la projection sans passer par un fichier. La cuisson connaît ces
# chiffres avant même de les écrire : elle a besoin de projeter des points
# pendant qu'elle fabrique l'image, pas seulement après.
func definir(a: float, c: Vector2, taille: Vector2, px: Vector2i) -> void:
	angle = a
	centre = c
	vue_taille = taille
	pixels = px
	_sin = sin(deg_to_rad(angle))
	_cos = cos(deg_to_rad(angle))
	valide = true


# Monde (x, z) au niveau de la mer -> pixel dans l'image de la carte.
func vers_carte(x: float, z: float, altitude := 0.0) -> Vector2:
	var u := 0.5 + (x - centre.x) / vue_taille.x
	# La composante verticale mêle altitude et distance nord-sud : c'est
	# exactement ce que fait le shader de cuisson.
	var v_monde := altitude * _cos - (z - centre.y) * _sin
	var v := 0.5 - v_monde / vue_taille.y
	return Vector2(u * pixels.x, v * pixels.y)


# Pixel de la carte -> monde (x, z), en supposant le point au niveau de la mer.
func vers_monde(pixel: Vector2) -> Vector2:
	var u := pixel.x / float(pixels.x)
	var v := pixel.y / float(pixels.y)
	var x := centre.x + (u - 0.5) * vue_taille.x
	var z := centre.y + (v - 0.5) * vue_taille.y / _sin
	return Vector2(x, z)


# Combien de pixels de carte pour un mètre monde, selon l'axe.
#
# ATTENTION À CE QU'ON EN DÉDUIT. Avec la fiche de la carte PEINTE — celle que
# `outils/carte_illustree.py` écrit, `angle: 90` — `_sin` vaut 1, et le rapport
# des deux composantes vaut 0,9998 : la projection ne comprime RIEN. L'obliquité
# qu'on voit est peinte dans le dessin de PR3.
#
# Ce rapport ne mesure donc l'écrasement du sol QUE pour un terrain cuit par
# `cuisson_carte.gd`, qui a un vrai `angle_vue`. S'en servir pour aplatir un
# anneau sur la carte peinte donne un cercle parfait — l'erreur a été faite.
func echelle() -> Vector2:
	return Vector2(pixels.x / vue_taille.x, pixels.y * _sin / vue_taille.y)


# Un cap monde (dx, dz) devient cet angle à l'écran : la compression nord-sud
# fait qu'un navire cap au nord ne pointe pas droit vers le haut de l'image.
func angle_ecran(dx: float, dz: float) -> float:
	return atan2(dz * _sin, dx)
