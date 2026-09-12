# Caméra de carte, à la Port Royale 3 : vue strictement zénithale, en
# projection orthographique.
#
# L'orthographique est le choix qui fait la « sensation carte » : sans fuite
# perspective, une île au bord de l'écran a exactement la même allure qu'une
# île au centre, et le zoom se lit comme une échelle. Une caméra inclinée,
# elle, donne tout de suite l'impression d'un Sid Meier's Pirates!.
class_name CameraStrategique
extends Node3D

const TAILLE_MIN := 260.0     # largeur de carte visible, en mètres
const TAILLE_MAX := 3600.0
const ALTITUDE := 2600.0      # sans effet visuel en ortho, mais garde tout devant le plan proche

var taille := 2000.0
var yaw := 0.0                # la carte reste nord en haut, comme dans PR
var limites := Vector2(1500, 1100)

var _camera: Camera3D
var _deplace := false


func _ready() -> void:
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 1.0
	_camera.far = 9000.0
	add_child(_camera)
	_appliquer()


func _appliquer() -> void:
	taille = clampf(taille, TAILLE_MIN, TAILLE_MAX)
	position.x = clampf(position.x, -limites.x, limites.x)
	position.z = clampf(position.z, -limites.y, limites.y)
	rotation = Vector3(-PI / 2.0, yaw, 0.0)   # plein zénith
	_camera.position = Vector3(0.0, 0.0, ALTITUDE)
	_camera.size = taille


func camera() -> Camera3D:
	return _camera


func viser(cible: Vector3) -> void:
	position = Vector3(cible.x, 0.0, cible.z)
	_appliquer()


func _unhandled_input(evenement: InputEvent) -> void:
	if evenement is InputEventMouseButton:
		match evenement.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				taille *= 0.88
				_appliquer()
			MOUSE_BUTTON_WHEEL_DOWN:
				taille /= 0.88
				_appliquer()
			MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
				_deplace = evenement.pressed
	elif evenement is InputEventMouseMotion and _deplace:
		deplacer_souris(evenement.relative)


# En orthographique, un pixel d'écran vaut une fraction connue de la carte :
# le décor colle exactement au curseur pendant le glissé.
func _metres_par_pixel() -> float:
	var largeur := get_viewport().get_visible_rect().size.x
	return taille / maxf(largeur, 1.0)


func deplacer_souris(relative: Vector2) -> void:
	var m := _metres_par_pixel()
	position.x -= relative.x * m
	position.z -= relative.y * m
	_appliquer()


func deplacer_clavier(direction: Vector2, delta: float) -> void:
	if direction == Vector2.ZERO:
		return
	var vitesse := taille * delta * 0.8
	position.x += direction.x * vitesse
	position.z -= direction.y * vitesse
	_appliquer()


# Point du plan de mer visé par un pixel : sert au clic sur un port.
func point_au_sol(pixel: Vector2) -> Vector3:
	var origine := _camera.project_ray_origin(pixel)
	var direction := _camera.project_ray_normal(pixel)
	if absf(direction.y) < 0.0001:
		return Vector3.ZERO
	var t := -origine.y / direction.y
	return origine + direction * t


# Position écran d'un point du monde : sert aux étiquettes 2D des ports.
func vers_ecran(monde: Vector3) -> Vector2:
	return _camera.unproject_position(monde)
