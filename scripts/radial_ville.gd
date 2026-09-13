# Le menu radial qui s'ouvre au clic sur une ville — comme le `Scene_Radial_Town`
# de Port Royale 3.
#
# PR3 ouvre au clic une couronne autour de la ville : un CENTRE (nom, drapeau,
# réputation) et des pétales — Bureau du port (le dock, où l'on négocie) et
# Chantier naval, ce dernier seulement si la ville en a un. On reprend cette
# logique : le centre porte le nom, trois pétales ouvrent chacun un écran, et le
# pétale Chantier ne paraît que si `port.chantier`.
#
# Le panneau ne décide rien : il émet un signal par pétale, la carte branche
# chacun sur l'écran voulu (infos, comptoir, chantier).
class_name RadialVille
extends CanvasLayer

signal infos_demandee(port: Dictionary)
signal dock_demande(port: Dictionary)          # le marché (marchandises)
signal capitainerie_demande(port: Dictionary)  # la gestion des convois
signal chantier_demande(port: Dictionary)       # acheter/réparer/construire/vendre

const BOIS       := Color(0.16, 0.11, 0.07)
const BOIS_CLAIR := Color(0.26, 0.18, 0.11)
const OR         := Color(0.86, 0.71, 0.36)
const LIN        := Color(0.921, 0.888, 0.812)
const RAYON      := 96.0    # distance du centre aux pétales
const R_PETALE   := 46.0    # rayon d'un pétale

var _port: Dictionary
var _voile: ColrRectFerme
var _racine: Control


# Un ColorRect qui se ferme au clic — déclaré à part pour capter le clic hors menu.
class ColrRectFerme extends ColorRect:
	signal clic_dehors
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			clic_dehors.emit()


func _ready() -> void:
	layer = 62
	visible = false
	_voile = ColrRectFerme.new()
	_voile.color = Color(0, 0, 0, 0.35)
	_voile.anchor_right = 1.0
	_voile.anchor_bottom = 1.0
	_voile.clic_dehors.connect(fermer)
	add_child(_voile)
	_racine = Control.new()
	_racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.anchor_right = 1.0
	_racine.anchor_bottom = 1.0
	add_child(_racine)


# Ouvre la couronne autour de `ecran_pos` (en pixels écran). `a_convoi` dit si un
# convoi du joueur est à ce port : sans lui, ni dock ni chantier — comme PR3, on
# n'entre au port qu'avec un navire.
func ouvrir(port: Dictionary, ecran_pos: Vector2, a_convoi: bool) -> void:
	_port = port
	for e in _racine.get_children():
		e.queue_free()

	# On garde la couronne entière à l'écran : le centre est repoussé des bords.
	var vp := get_viewport().get_visible_rect().size
	var marge := RAYON + R_PETALE + 8.0
	var c := Vector2(
		clampf(ecran_pos.x, marge, vp.x - marge),
		clampf(ecran_pos.y, marge, vp.y - marge))

	_centre(c)

	# Les pétales, en éventail au-dessus du centre. Infos toujours ; Dock (marché)
	# et Capitainerie (convois) si un convoi du joueur est là ; Chantier en plus
	# si la ville a un chantier naval.
	var petales: Array = [
		{"txt": "Infos", "sig": "infos"},
	]
	if a_convoi:
		petales.append({"txt": "Dock", "sig": "dock"})
		petales.append({"txt": "Capitainerie", "sig": "capitainerie"})
		if bool(port.get("chantier", false)):
			petales.append({"txt": "Chantier", "sig": "chantier"})

	var n := petales.size()
	# Éventail centré sur le haut (-90°) ; on resserre l'écart quand il y a plus
	# de pétales pour que la couronne reste lisible.
	var pas := deg_to_rad(58.0 if n <= 3 else 46.0)
	var depart := deg_to_rad(-90.0) - pas * (n - 1) / 2.0
	for i in n:
		var a := depart + pas * i
		var pos := c + Vector2(cos(a), sin(a)) * RAYON
		_petale(pos, String(petales[i]["txt"]), String(petales[i]["sig"]))

	visible = true


func fermer() -> void:
	visible = false


func _centre(c: Vector2) -> void:
	var disque := Panel.new()
	var d := 84.0
	disque.size = Vector2(d, d)
	disque.position = c - Vector2(d, d) / 2.0
	var st := StyleBoxFlat.new()
	st.bg_color = LIN
	st.border_color = BOIS
	st.set_border_width_all(4)
	st.set_corner_radius_all(int(d / 2))
	disque.add_theme_stylebox_override("panel", st)
	_racine.add_child(disque)

	# Un liseré à la couleur de la nation, en anneau intérieur.
	var coul: Color = _port.get("couleur", OR)
	var anneau := Panel.new()
	anneau.size = Vector2(d - 12, d - 12)
	anneau.position = c - Vector2(d - 12, d - 12) / 2.0
	var sa := StyleBoxFlat.new()
	sa.bg_color = Color(0, 0, 0, 0)
	sa.border_color = coul
	sa.set_border_width_all(3)
	sa.set_corner_radius_all(int((d - 12) / 2))
	anneau.add_theme_stylebox_override("panel", sa)
	_racine.add_child(anneau)

	var nom := Label.new()
	nom.text = String(_port.get("nom", "?"))
	nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nom.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nom.autowrap_mode = TextServer.AUTOWRAP_WORD
	nom.size = Vector2(d - 16, d - 16)
	nom.position = c - Vector2(d - 16, d - 16) / 2.0
	nom.add_theme_font_size_override("font_size", 13)
	nom.add_theme_color_override("font_color", BOIS)
	_racine.add_child(nom)


func _petale(centre: Vector2, txt: String, sig: String) -> void:
	var b := Button.new()
	b.text = txt
	b.size = Vector2(R_PETALE * 2, R_PETALE * 2)
	b.position = centre - Vector2(R_PETALE, R_PETALE)
	b.add_theme_font_size_override("font_size", 15)
	var st := StyleBoxFlat.new()
	st.bg_color = LIN
	st.border_color = BOIS_CLAIR
	st.set_border_width_all(3)
	st.set_corner_radius_all(int(R_PETALE))
	st.set_content_margin_all(6)
	b.add_theme_stylebox_override("normal", st)
	var sh := st.duplicate() as StyleBoxFlat
	sh.bg_color = OR
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_color_override("font_color", BOIS)
	b.add_theme_color_override("font_hover_color", BOIS)
	b.pressed.connect(_sur_petale.bind(sig))
	_racine.add_child(b)


func _sur_petale(sig: String) -> void:
	fermer()
	match sig:
		"infos": infos_demandee.emit(_port)
		"dock": dock_demande.emit(_port)
		"capitainerie": capitainerie_demande.emit(_port)
		"chantier": chantier_demande.emit(_port)
