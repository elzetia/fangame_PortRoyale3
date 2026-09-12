# Construit le maillage 3D d'une île à partir du contour fourni par la
# simulation Lua. La côte que l'on voit est donc exactement celle que le
# navire contourne : une seule géométrie, deux usages.
#
# Le profil d'altitude compte autant que la forme : c'est la pente douce sous
# l'eau (le plateau) qui crée l'anneau turquoise du shader d'eau. Sans elle,
# les îles auraient l'air posées sur du bleu profond.
class_name IleBuilder
extends RefCounted

const SABLE         := Color(0.90, 0.82, 0.58)
const SABLE_MOUILLE := Color(0.72, 0.70, 0.55)
const HERBE         := Color(0.33, 0.55, 0.24)
const HERBE_SOMBRE  := Color(0.17, 0.35, 0.15)
const ROCHE         := Color(0.46, 0.43, 0.38)
const FOND          := Color(0.14, 0.26, 0.28)

# Anneaux : denses près de la côte, où se joue tout le rendu.
const ANNEAUX := [
	0.00, 0.10, 0.20, 0.30, 0.40, 0.50, 0.60, 0.68, 0.75, 0.81,
	0.86, 0.90, 0.93, 0.96, 0.98, 1.00,
	1.03, 1.07, 1.11, 1.15, 1.19, 1.24, 1.30, 1.37, 1.45, 1.60,
]

const MARGE_SOUS_MARINE := 0.60   # étendue du plateau, en fraction du rayon
const PROFONDEUR_MAX    := 190.0
const ALTITUDE_COTE     := 1.2    # la côte finit juste au-dessus de l'eau


static func hauteur(s: float, sommet: float, bruit: float) -> float:
	if s <= 1.0:
		var base := sommet * pow(1.0 - s, 1.75)
		# On aplatit la frange côtière : ça pose une vraie bande de sable
		# au lieu d'un cône qui plonge droit dans l'eau.
		var plage := smoothstep(0.88, 1.0, s)
		base = lerpf(base, ALTITUDE_COTE, plage)
		# Le relief ne doit pas déformer la ligne de côte, sinon la géométrie
		# ne correspond plus au contour utilisé pour la navigation.
		return base + bruit * sommet * 0.22 * (1.0 - plage) * smoothstep(0.0, 0.25, s)

	# Sous l'eau : plateau puis tombant. L'exposant fait la largeur du lagon.
	var u: float = clampf((s - 1.0) / MARGE_SOUS_MARINE, 0.0, 1.0)
	return lerpf(ALTITUDE_COTE, -PROFONDEUR_MAX, pow(u, 2.6))


static func couleur_terrain(h: float, sommet: float) -> Color:
	if h < -45.0:
		return FOND
	if h < -2.0:
		return FOND.lerp(SABLE_MOUILLE, smoothstep(-45.0, -2.0, h))
	if h < 2.2:
		return SABLE_MOUILLE.lerp(SABLE, smoothstep(-2.0, 2.2, h))
	if h < 10.0:
		return SABLE.lerp(HERBE, smoothstep(2.2, 10.0, h))
	var haut := sommet * 0.60
	if h < haut:
		return HERBE.lerp(HERBE_SOMBRE, smoothstep(10.0, haut, h))
	return HERBE_SOMBRE.lerp(ROCHE, smoothstep(haut, sommet * 0.92, h))


static func construire(ile: Dictionary, bruit: FastNoiseLite) -> ArrayMesh:
	var contour: PackedVector2Array = ile["contour"]
	var centre: Vector3 = ile["centre"]
	var sommet: float = ile["sommet"]
	var segments := contour.size()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Grille de sommets : un anneau par valeur de ANNEAUX, un point par segment
	var grille: Array = []
	for a in ANNEAUX.size():
		var s: float = ANNEAUX[a]
		var anneau: Array[Vector3] = []
		for j in segments:
			var cote := contour[j]
			var dx := cote.x - centre.x
			var dz := cote.y - centre.z
			var x := centre.x + dx * s
			var z := centre.z + dz * s
			var n := bruit.get_noise_2d(x, z)
			anneau.append(Vector3(x, hauteur(s, sommet, n), z))
		grille.append(anneau)

	for a in range(ANNEAUX.size() - 1):
		var interieur: Array = grille[a]
		var exterieur: Array = grille[a + 1]
		for j in segments:
			var k := (j + 1) % segments
			var p0: Vector3 = interieur[j]
			var p1: Vector3 = interieur[k]
			var p2: Vector3 = exterieur[k]
			var p3: Vector3 = exterieur[j]
			# Deux triangles, orientés vers le haut
			_triangle(st, p0, p3, p2, sommet)
			_triangle(st, p0, p2, p1, sommet)

	st.index()
	st.generate_normals()
	return st.commit()


static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, sommet: float) -> void:
	for p in [a, b, c]:
		st.set_color(couleur_terrain(p.y, sommet))
		st.add_vertex(p)
