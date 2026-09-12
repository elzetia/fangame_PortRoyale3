# Le navire du joueur : maillage procédural, suivi de route, et assiette sur
# la houle.
#
# Il est volontairement surdimensionné par rapport à l'échelle géographique —
# comme les convois de Port Royale, qui font plusieurs kilomètres de long sur
# la carte. Un navire à l'échelle réelle serait un pixel.
class_name Navire
extends Node3D

const BOIS   := Color(0.32, 0.19, 0.10)
const PONT   := Color(0.55, 0.38, 0.21)
const VOILE  := Color(0.96, 0.93, 0.86)
const MAT    := Color(0.28, 0.17, 0.09)

# Demi-contour du pont, de l'étrave à la poupe (x = tribord, z = axe du navire)
const DEMI_COQUE := [
	Vector2(0.0,  24.0),
	Vector2(3.4,  15.0),
	Vector2(4.8,   5.0),
	Vector2(5.0,  -5.0),
	Vector2(4.2, -14.0),
	Vector2(2.6, -19.5),
	Vector2(0.0, -21.5),
]

const HAUTEUR_PONT := 2.2
const HAUTEUR_QUILLE := -3.6

var route: PackedVector3Array = PackedVector3Array()
var vitesse_monde := 75.0        # mètres monde par seconde de jeu
var cap := 0.0
var destination: Dictionary = {}

signal arrive(port)

var _mesh: MeshInstance3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _construire_maillage()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED   # les voiles sont des plans
	mat.roughness = 0.85
	_mesh.material_override = mat
	add_child(_mesh)


# --- géométrie ----------------------------------------------------------------

static func _contour_pont() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in DEMI_COQUE:
		pts.append(p)
	# Retour par bâbord, sans répéter l'étrave ni la poupe
	for i in range(DEMI_COQUE.size() - 2, 0, -1):
		var p: Vector2 = DEMI_COQUE[i]
		pts.append(Vector2(-p.x, p.y))
	return pts


func _construire_maillage() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var contour := _contour_pont()
	var n := contour.size()

	# Bordé : du pont à la quille, la coque se resserre vers le bas
	for i in n:
		var j := (i + 1) % n
		var a := contour[i]
		var b := contour[j]
		var ha := Vector3(a.x, HAUTEUR_PONT, a.y)
		var hb := Vector3(b.x, HAUTEUR_PONT, b.y)
		var qa := Vector3(a.x * 0.30, HAUTEUR_QUILLE, a.y * 0.88)
		var qb := Vector3(b.x * 0.30, HAUTEUR_QUILLE, b.y * 0.88)
		_quad(st, ha, hb, qb, qa, BOIS)

	# Pont : éventail depuis le centre
	var centre := Vector3(0.0, HAUTEUR_PONT, 1.0)
	for i in n:
		var j := (i + 1) % n
		_tri(st, centre,
			Vector3(contour[i].x, HAUTEUR_PONT, contour[i].y),
			Vector3(contour[j].x, HAUTEUR_PONT, contour[j].y), PONT)

	# Mât
	_boite(st, Vector3(0.0, HAUTEUR_PONT, 1.0), Vector3(0.55, 30.0, 0.55), MAT)
	# Beaupré, incliné vers l'avant
	_boite(st, Vector3(0.0, HAUTEUR_PONT + 2.0, 21.0), Vector3(0.4, 0.4, 9.0), MAT)

	# Grand-voile et hunier : deux plans dans l'axe du vent
	_voile(st, 5.0, 20.0, -9.0, 8.0)
	_voile(st, 21.0, 29.0, -4.0, 6.0)

	st.index()
	st.generate_normals()
	return st.commit()


func _voile(st: SurfaceTool, y0: float, y1: float, z0: float, z1: float) -> void:
	# Léger galbe : trois panneaux plutôt qu'un plan tout plat
	var creux := 1.6
	var pas := (z1 - z0) / 3.0
	for k in 3:
		var za := z0 + pas * k
		var zb := z0 + pas * (k + 1)
		var xa := creux * sin(PI * float(k) / 3.0)
		var xb := creux * sin(PI * float(k + 1) / 3.0)
		_quad(st, Vector3(xa, y1, za), Vector3(xb, y1, zb),
				  Vector3(xb, y0, zb), Vector3(xa, y0, za), VOILE)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(st, a, b, c, col)
	_tri(st, a, c, d, col)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	for p in [a, b, c]:
		st.set_color(col)
		st.add_vertex(p)


func _boite(st: SurfaceTool, base: Vector3, taille: Vector3, col: Color) -> void:
	var hx := taille.x * 0.5
	var hz := taille.z * 0.5
	var y0 := base.y
	var y1 := base.y + taille.y
	var c := Vector3(base.x, 0.0, base.z)
	var coins := [
		Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz),
		Vector3(hx, 0, hz), Vector3(-hx, 0, hz),
	]
	for i in 4:
		var j := (i + 1) % 4
		var a: Vector3 = coins[i]
		var b: Vector3 = coins[j]
		_quad(st, c + Vector3(a.x, y1, a.z), c + Vector3(b.x, y1, b.z),
				  c + Vector3(b.x, y0, b.z), c + Vector3(a.x, y0, a.z), col)


# --- navigation ---------------------------------------------------------------

func cap_sur(nouvelle_route: PackedVector3Array, port: Dictionary) -> void:
	route = nouvelle_route
	destination = port


func au_mouillage() -> bool:
	return route.is_empty()


# Distance restante en mètres monde, pour l'estimation d'arrivée
func distance_restante() -> float:
	if route.is_empty():
		return 0.0
	var d := 0.0
	var p := Vector2(global_position.x, global_position.z)
	for wp in route:
		var q := Vector2(wp.x, wp.z)
		d += p.distance_to(q)
		p = q
	return d


func avancer(delta_jeu: float) -> void:
	if route.is_empty():
		return

	var budget := vitesse_monde * delta_jeu
	var pos := Vector2(global_position.x, global_position.z)

	while budget > 0.0 and not route.is_empty():
		var cible := Vector2(route[0].x, route[0].z)
		var d := pos.distance_to(cible)
		if d <= budget:
			pos = cible
			budget -= d
			route.remove_at(0)
			if route.is_empty():
				global_position = Vector3(pos.x, global_position.y, pos.y)
				var port := destination
				destination = {}
				arrive.emit(port)
				return
		else:
			pos = pos.lerp(cible, budget / d)
			budget = 0.0

	global_position = Vector3(pos.x, global_position.y, pos.y)

	# Cap : on vise le prochain point de route, sans pivoter instantanément
	if not route.is_empty():
		var vers := Vector2(route[0].x, route[0].z) - pos
		if vers.length_squared() > 0.01:
			var vise := atan2(vers.x, vers.y)
			cap = lerp_angle(cap, vise, clampf(delta_jeu * 1.5, 0.0, 1.0))


# --- assiette sur la houle ----------------------------------------------------

func poser_sur_la_houle(t: float) -> void:
	var pos := Vector2(global_position.x, global_position.z)
	var dir := Vector2(sin(cap), cos(cap))
	var travers := Vector2(dir.y, -dir.x)

	var h := Houle.hauteur(pos, t)
	global_position.y = h + 0.6

	# Tangage et roulis mesurés sur la vraie surface, pas simulés au hasard
	var av := Houle.hauteur(pos + dir * 14.0, t)
	var ar := Houle.hauteur(pos - dir * 14.0, t)
	var tb := Houle.hauteur(pos + travers * 5.0, t)
	var bb := Houle.hauteur(pos - travers * 5.0, t)

	var tangage := atan2(av - ar, 28.0)
	var roulis := atan2(tb - bb, 10.0)
	rotation = Vector3(-tangage, cap, roulis)
