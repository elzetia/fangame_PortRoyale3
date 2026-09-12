# Source de vérité unique pour la houle.
#
# Ces paramètres sont poussés dans le shader d'eau au démarrage ET utilisés ici
# pour poser le navire sur les vagues. Un seul endroit à modifier : le navire ne
# peut pas se retrouver à flotter au-dessus ou sous la surface.
class_name Houle
extends RefCounted

# Chaque vague : xy = direction, z = amplitude (m), w = longueur d'onde (m).
const VAGUES: Array[Vector4] = [
	Vector4( 1.0,  0.35, 0.90, 150.0),
	Vector4(-0.6,  1.00, 0.60,  96.0),
	Vector4( 0.8, -0.70, 0.34,  56.0),
	Vector4(-0.9, -0.30, 0.18,  29.0),
]
const RAIDEUR := 0.75
const VITESSE := 0.5


# Déplacement de Gerstner d'un point de la surface : horizontal ET vertical.
static func deplacement(pos: Vector2, t: float) -> Vector3:
	var offset := Vector3.ZERO
	for v in VAGUES:
		var dir := Vector2(v.x, v.y).normalized()
		var amplitude := v.z
		var longueur: float = maxf(v.w, 1.0)
		var k := TAU / longueur
		var celerite := sqrt(9.81 / k)
		var phase := k * (dir.dot(pos) - celerite * t * VITESSE)
		var q := RAIDEUR / maxf(k * amplitude * 4.0, 0.0001)
		offset += Vector3(q * amplitude * dir.x * cos(phase),
						  amplitude * sin(phase),
						  q * amplitude * dir.y * cos(phase))
	return offset


static func hauteur(pos: Vector2, t: float) -> float:
	return deplacement(pos, t).y


# Applique les mêmes vagues au shader, pour que les deux ne divergent jamais.
static func appliquer_au_shader(mat: ShaderMaterial) -> void:
	for i in VAGUES.size():
		mat.set_shader_parameter("vague_%d" % (i + 1), VAGUES[i])
	mat.set_shader_parameter("raideur", RAIDEUR)
	mat.set_shader_parameter("vitesse_temps", VITESSE)
