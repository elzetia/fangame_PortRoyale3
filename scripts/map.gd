# Assemblage de la carte stratégique.
#
# Rien n'est stocké dans la scène : tout est construit ici à partir de ce que
# renvoie la simulation Lua. Changer l'archipel, c'est éditer sim/archipel.lua,
# pas cliquer dans l'éditeur.
extends Node3D

const NIVEAU_MER := 0.0
const RAYON_CLIC_PORT := 110.0     # tolérance de clic autour d'un bourg

var sim: Sim
var camera_rig: CameraStrategique
var navire: Navire

var ports: Array = []
var _noeuds_ports: Array[Node3D] = []
var _port_survole: Dictionary = {}
var _trace_route: MeshInstance3D
var _mat_eau: ShaderMaterial
var _env: Environment

# HUD
var _lbl_date: Label
var _lbl_heure: Label
var _lbl_navire: Label
var _lbl_statut: Label
var _boutons_vitesse: Array[Button] = []

var _clic_depart := Vector2.ZERO
var _clic_deplace := false
var _pan_gauche := false


func _ready() -> void:
	sim = Sim.new()
	if not sim.pret:
		push_error("La simulation Lua n'a pas démarré : %s" % sim.erreur)
		return

	var cases := sim.preparer_navigation()
	print("[sim] grille de navigation : %d cases" % cases)

	_creer_environnement()
	_creer_mer()
	_creer_fond_marin()
	_creer_iles()
	_creer_ports()
	_creer_navire()
	_creer_camera()
	_creer_hud()
	_creer_trace_route()
	_capture_auto()


# Outil de développement : `godot --path <projet> -- --capture <fichier.png> [s]`
# lance le jeu, attend, enregistre une image du rendu et quitte. Bien plus
# fiable qu'une capture d'écran système, qui attrape la fenêtre du dessus.
func _capture_auto() -> void:
	var args := OS.get_cmdline_user_args()

	# Modes de diagnostic du rendu
	if args.has("--sans-eau"):
		get_node("Mer").visible = false
	if args.has("--debug-eau"):
		_mat_eau.set_shader_parameter("mode_debug", 1)
	if args.has("--albedo"):
		# Albédo brut, sans éclairage : sépare un problème de matériau
		# d'un problème d'exposition.
		get_viewport().debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	var d := args.find("--distance")
	if d >= 0 and d + 1 < args.size():
		camera_rig.distance = float(args[d + 1])
		camera_rig._appliquer()
	if args.has("--fond-magenta"):
		# Tout ce qui reste magenta est du vide, pas du décor.
		var e := _env
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(1, 0, 1)
		e.fog_enabled = false
	if args.has("--double-face"):
		for n in _tous_les_maillages(self):
			if n.material_override is StandardMaterial3D:
				(n.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	if args.has("--sans-etiquettes"):
		for n in _tous_les_noeuds(self):
			if n is Label3D:
				n.visible = false
	if args.has("--sans-hud"):
		for n in get_children():
			if n is CanvasLayer:
				n.visible = false
	# Cuisson de la carte : `-- --cuire <fichier.png> [largeur]`
	var k := args.find("--cuire")
	if k >= 0 and k + 1 < args.size():
		var largeur := 4096
		if k + 2 < args.size() and args[k + 2].is_valid_int():
			largeur = int(args[k + 2])
		var angle := 65.0
		if k + 3 < args.size() and args[k + 3].is_valid_float():
			angle = float(args[k + 3])
		var res: Dictionary = await CuissonCarte.cuire(self, sim, args[k + 1], largeur, angle)
		print("[cuisson] %s %s  %s px  %.2f m/px  angle %.0f deg  %.1f s" % [
			args[k + 1], "ok" if res["ok"] else "ECHEC %d" % res["erreur"],
			res["pixels"], res["metres_par_pixel"], res["angle"], res["secondes"]])
		get_tree().quit()
		return

	# `--test-mer x z` : appareillage vers un point de haute mer, sans souris
	var m := args.find("--test-mer")
	if m >= 0 and m + 2 < args.size():
		var cible := Vector3(float(args[m + 1]), 0.0, float(args[m + 2]))
		var ok := cap_vers_point(cible)
		print("[test] cap sur %s : %s, %d points de route" % [
			cible, "accepté" if ok else "refusé", navire.route.size()])

	var c := args.find("--test-cap")
	if c >= 0 and c + 1 < args.size():
		# Vérifie sans souris que le calcul de route et l'appareillage marchent
		var cible := _port_par_cle(args[c + 1])
		_clic_gauche_sur(cible)
		print("[test] cap sur %s : %d points de route" % [cible["nom"], navire.route.size()])
	if args.has("--diag"):
		_diagnostic()

	var i := args.find("--capture")
	if i < 0 or i + 1 >= args.size():
		return
	var chemin: String = args[i + 1]
	var delai := 4.0
	if i + 2 < args.size():
		delai = float(args[i + 2])

	await get_tree().create_timer(delai).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(chemin)
	print("[capture] %s (%s)" % [chemin, "ok" if err == OK else "erreur %d" % err])
	get_tree().quit()


func _diagnostic() -> void:
	print("--- diagnostic de la scène ---")
	var cam := camera_rig.camera()
	print("caméra globale : %s  regarde %s" % [
		cam.global_position, -cam.global_transform.basis.z])
	print("caméra active du viewport : %s (la nôtre : %s)" % [
		get_viewport().get_camera_3d(), cam])
	for n in _tous_les_maillages(self):
		var m: Mesh = n.mesh
		var surfaces := m.get_surface_count() if m else -1
		var aabb := n.get_aabb() if m else AABB()
		var couleur := "-"
		if n.material_override is StandardMaterial3D:
			var sm: StandardMaterial3D = n.material_override
			couleur = "override albedo=%s vc=%s" % [sm.albedo_color, sm.vertex_color_use_as_albedo]
		elif m and surfaces > 0 and m.surface_get_material(0) is StandardMaterial3D:
			couleur = "surface albedo=%s" % (m.surface_get_material(0) as StandardMaterial3D).albedo_color
		print("  %-22s vis=%s surf=%d aabb=%s  %s" % [
			n.name, n.is_visible_in_tree(), surfaces, aabb, couleur])

	# Les couleurs de sommets sont-elles vraiment dans le maillage ?
	for n in _tous_les_maillages(self):
		if n.mesh and n.mesh.get_surface_count() > 0 and n.name.begins_with("Isla"):
			var arr := (n.mesh as ArrayMesh).surface_get_arrays(0)
			var couleurs = arr[Mesh.ARRAY_COLOR]
			print("  [%s] format couleurs : %s (n=%d) premières=%s" % [
				n.name,
				"présentes" if couleurs != null else "ABSENTES",
				(couleurs.size() if couleurs != null else 0),
				str(couleurs.slice(0, 3)) if couleurs != null else "-"])
			break


func _tous_les_noeuds(racine: Node) -> Array[Node]:
	var sortie: Array[Node] = []
	for enfant in racine.get_children():
		sortie.append(enfant)
		sortie.append_array(_tous_les_noeuds(enfant))
	return sortie


func _tous_les_maillages(racine: Node) -> Array[MeshInstance3D]:
	var sortie: Array[MeshInstance3D] = []
	for enfant in racine.get_children():
		if enfant is MeshInstance3D:
			sortie.append(enfant)
		sortie.append_array(_tous_les_maillages(enfant))
	return sortie


# --- décor --------------------------------------------------------------------

func _creer_environnement() -> void:
	var ciel := ProceduralSkyMaterial.new()
	ciel.sky_top_color = Color(0.16, 0.42, 0.80)
	ciel.sky_horizon_color = Color(0.78, 0.88, 0.93)
	ciel.sky_curve = 0.18
	ciel.ground_bottom_color = Color(0.14, 0.30, 0.42)
	ciel.ground_horizon_color = Color(0.78, 0.88, 0.93)
	ciel.sun_angle_max = 24.0
	ciel.sun_curve = 0.08

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ciel

	# Éclairage sobre : le soleil fait l'essentiel, l'ambiante ne fait que
	# déboucher les ombres. Monter les deux à la fois délave tout en blanc.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 0.35

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0

	# Une brume légère éloigne l'horizon et pose l'ambiance tropicale
	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.82, 0.90)
	env.fog_density = 0.00006
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.15

	var we := WorldEnvironment.new()
	_env = env
	we.environment = env
	add_child(we)

	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-48.0, 132.0, 0.0)
	soleil.light_color = Color(1.0, 0.96, 0.87)
	soleil.light_energy = 1.0
	soleil.shadow_enabled = true
	soleil.directional_shadow_max_distance = 4200.0
	soleil.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	soleil.shadow_blur = 1.2
	add_child(soleil)


func _creer_mer() -> void:
	var plan := PlaneMesh.new()
	plan.size = Vector2(6400, 5200)
	# Assez de sommets pour que la houle de Gerstner ne se crénèle pas :
	# environ une maille tous les 12 m.
	plan.subdivide_width = 520
	plan.subdivide_depth = 420

	_mat_eau = ShaderMaterial.new()
	_mat_eau.shader = load("res://shaders/stylized_water.gdshader")
	Houle.appliquer_au_shader(_mat_eau)

	var mi := MeshInstance3D.new()
	mi.name = "Mer"
	mi.mesh = plan
	mi.material_override = _mat_eau
	mi.position.y = NIVEAU_MER
	# La mer ne projette pas d'ombre, et son AABB doit couvrir la houle
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 40.0
	add_child(mi)


# Sans fond marin, on verrait le ciel à travers l'eau transparente.
func _creer_fond_marin() -> void:
	var plan := PlaneMesh.new()
	plan.size = Vector2(9000, 7000)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.13, 0.20)
	mat.roughness = 1.0
	mat.metallic = 0.0

	var mi := MeshInstance3D.new()
	mi.name = "FondMarin"
	mi.mesh = plan
	mi.material_override = mat
	mi.position.y = -210.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _creer_iles() -> void:
	var bruit := FastNoiseLite.new()
	bruit.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	bruit.frequency = 0.0055
	bruit.fractal_octaves = 4
	bruit.seed = 20250910

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.metallic = 0.0

	var parent := Node3D.new()
	parent.name = "Iles"
	add_child(parent)

	for ile in sim.iles(176):
		var mi := MeshInstance3D.new()
		mi.name = ile["nom"]
		mi.mesh = IleBuilder.construire(ile, bruit)
		mi.material_override = mat
		parent.add_child(mi)


func _creer_ports() -> void:
	ports = sim.ports()
	var parent := Node3D.new()
	parent.name = "Ports"
	add_child(parent)

	for port in ports:
		var noeud := _creer_marqueur_port(port)
		parent.add_child(noeud)
		_noeuds_ports.append(noeud)


func _creer_marqueur_port(port: Dictionary) -> Node3D:
	var racine := Node3D.new()
	racine.name = port["nom"]
	var bourg: Vector3 = port["bourg"]
	racine.position = Vector3(bourg.x, 0.0, bourg.z)

	var couleur: Color = port["couleur"]
	var bord: Color = port["couleur_bord"]

	# Terre-plein du bourg, aux couleurs de la couronne
	var socle := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 34.0
	cyl.bottom_radius = 38.0
	cyl.height = 5.0
	cyl.radial_segments = 20
	socle.mesh = cyl
	var mat_socle := StandardMaterial3D.new()
	mat_socle.albedo_color = couleur
	mat_socle.roughness = 0.9
	socle.mesh.material = mat_socle
	socle.position.y = 3.0
	racine.add_child(socle)

	# Quelques toits, pour que ça ressemble à un bourg et pas à un jeton
	var mat_toit := StandardMaterial3D.new()
	mat_toit.albedo_color = Color(0.55, 0.24, 0.16)
	var mat_mur := StandardMaterial3D.new()
	mat_mur.albedo_color = Color(0.92, 0.88, 0.78)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(port["cle"])
	for i in 7:
		var a := rng.randf() * TAU
		var r := rng.randf_range(6.0, 26.0)
		var h := rng.randf_range(9.0, 16.0)
		var maison := MeshInstance3D.new()
		var boite := BoxMesh.new()
		boite.size = Vector3(rng.randf_range(8.0, 13.0), h, rng.randf_range(8.0, 13.0))
		boite.material = mat_mur
		maison.mesh = boite
		maison.position = Vector3(cos(a) * r, 5.0 + h * 0.5, sin(a) * r)
		maison.rotation.y = rng.randf() * TAU
		racine.add_child(maison)

		var toit := MeshInstance3D.new()
		var prisme := PrismMesh.new()
		prisme.size = Vector3(boite.size.x * 1.25, 6.0, boite.size.z * 1.25)
		prisme.material = mat_toit
		toit.mesh = prisme
		toit.position = maison.position + Vector3(0.0, h * 0.5 + 3.0, 0.0)
		toit.rotation.y = maison.rotation.y
		racine.add_child(toit)

	# Mât et pavillon
	var mat_bois := StandardMaterial3D.new()
	mat_bois.albedo_color = Color(0.25, 0.16, 0.09)
	var mat_pole := MeshInstance3D.new()
	var pole := CylinderMesh.new()
	pole.top_radius = 1.0
	pole.bottom_radius = 1.2
	pole.height = 62.0
	pole.material = mat_bois
	mat_pole.mesh = pole
	mat_pole.position.y = 36.0
	racine.add_child(mat_pole)

	var pavillon := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(30.0, 19.0)
	var mat_pav := StandardMaterial3D.new()
	mat_pav.albedo_color = couleur
	mat_pav.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_pav.roughness = 0.9
	quad.material = mat_pav
	pavillon.mesh = quad
	pavillon.position = Vector3(15.0, 57.0, 0.0)
	racine.add_child(pavillon)

	# Étiquette : toujours face à la caméra, toujours lisible
	var etiquette := Label3D.new()
	etiquette.text = port["nom"]
	etiquette.font_size = 96
	etiquette.pixel_size = 0.42
	# Ni fixed_size ni no_depth_test : combinés, ils faisaient exploser le quad
	# de l'étiquette jusqu'à recouvrir tout l'écran d'un blanc uniforme.
	etiquette.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiquette.outline_size = 26
	etiquette.modulate = Color(1.0, 0.98, 0.92)
	etiquette.outline_modulate = Color(0.05, 0.04, 0.03, 0.9)
	etiquette.position = Vector3(0.0, 92.0, 0.0)
	racine.add_child(etiquette)

	# Anneau de mouillage, au large
	var rade: Vector3 = port["rade"]
	var anneau := MeshInstance3D.new()
	var tore := TorusMesh.new()
	tore.inner_radius = 16.0
	tore.outer_radius = 20.0
	tore.rings = 20
	var mat_anneau := StandardMaterial3D.new()
	mat_anneau.albedo_color = Color(1.0, 1.0, 1.0, 0.35)
	mat_anneau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_anneau.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tore.material = mat_anneau
	anneau.mesh = tore
	anneau.position = Vector3(rade.x - bourg.x, 2.0, rade.z - bourg.z)
	racine.add_child(anneau)

	return racine


func _creer_navire() -> void:
	navire = Navire.new()
	navire.name = "Navire"
	add_child(navire)

	var depart := _port_par_cle("port_royale")
	var rade: Vector3 = depart["rade"]
	navire.global_position = Vector3(rade.x, 0.0, rade.z)
	navire.vitesse_monde = sim.vitesse_monde(8.0)
	navire.arrive.connect(_sur_arrivee)


func _creer_camera() -> void:
	camera_rig = CameraStrategique.new()
	camera_rig.name = "Camera"
	camera_rig.limites = sim.limites()
	add_child(camera_rig)
	camera_rig.viser(navire.global_position)


func _creer_trace_route() -> void:
	_trace_route = MeshInstance3D.new()
	_trace_route.name = "Route"
	_trace_route.mesh = ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trace_route.material_override = mat
	_trace_route.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trace_route)


# --- HUD ----------------------------------------------------------------------

func _creer_hud() -> void:
	var couche := CanvasLayer.new()
	add_child(couche)

	var bois := Color(0.13, 0.09, 0.06, 0.92)

	# Cartouche de date, en haut à gauche
	var cartouche := PanelContainer.new()
	cartouche.position = Vector2(16, 16)
	cartouche.custom_minimum_size = Vector2(230, 0)
	cartouche.add_theme_stylebox_override("panel", _style(bois))
	couche.add_child(cartouche)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	cartouche.add_child(vb)

	_lbl_date = Label.new()
	_lbl_date.add_theme_font_size_override("font_size", 20)
	_lbl_date.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
	_lbl_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_lbl_date)

	_lbl_heure = Label.new()
	_lbl_heure.add_theme_font_size_override("font_size", 13)
	_lbl_heure.add_theme_color_override("font_color", Color(0.70, 0.62, 0.50))
	_lbl_heure.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_lbl_heure)

	# Barre du bas
	var barre := PanelContainer.new()
	barre.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	barre.offset_top = -78
	barre.add_theme_stylebox_override("panel", _style(bois))
	couche.add_child(barre)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	barre.add_child(hb)

	var infos := VBoxContainer.new()
	infos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	infos.add_theme_constant_override("separation", 2)
	hb.add_child(infos)

	_lbl_navire = Label.new()
	_lbl_navire.text = "Sloop « Aurore »"
	_lbl_navire.add_theme_font_size_override("font_size", 18)
	_lbl_navire.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	infos.add_child(_lbl_navire)

	_lbl_statut = Label.new()
	_lbl_statut.add_theme_font_size_override("font_size", 14)
	_lbl_statut.add_theme_color_override("font_color", Color(0.84, 0.70, 0.32))
	infos.add_child(_lbl_statut)

	var vitesses := HBoxContainer.new()
	vitesses.alignment = BoxContainer.ALIGNMENT_END
	vitesses.add_theme_constant_override("separation", 6)
	hb.add_child(vitesses)

	var libelles := ["II", "x1", "x2", "x4"]
	for i in 4:
		var b := Button.new()
		b.text = libelles[i]
		b.custom_minimum_size = Vector2(46, 38)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_sur_vitesse.bind(i + 1))
		vitesses.add_child(b)
		_boutons_vitesse.append(b)


func _style(couleur: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = couleur
	sb.border_color = Color(0.32, 0.22, 0.14)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


# --- boucle -------------------------------------------------------------------

func _process(delta: float) -> void:
	if not sim.pret:
		return

	# Le navire avance au rythme du calendrier : à x2, il va deux fois plus vite.
	var vitesse_jeu := float(sim.etat_temps()["vitesse"])
	sim.avancer_temps(delta)
	navire.avancer(delta * vitesse_jeu)
	navire.poser_sur_la_houle(float(Time.get_ticks_msec()) / 1000.0)

	_deplacement_clavier(delta)
	_maj_survol()
	_maj_trace_route()
	_maj_hud()


func _deplacement_clavier(delta: float) -> void:
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q):
		d.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		d.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z):
		d.y += 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		d.y -= 1.0
	camera_rig.deplacer_clavier(d.normalized(), delta)


func _maj_survol() -> void:
	_port_survole = {}
	var souris := get_viewport().get_mouse_position()
	var sol := camera_rig.point_au_sol(souris)
	if sol == Vector3.ZERO:
		return
	var meilleure := RAYON_CLIC_PORT
	for port in ports:
		var bourg: Vector3 = port["bourg"]
		var d := Vector2(sol.x - bourg.x, sol.z - bourg.z).length()
		if d < meilleure:
			meilleure = d
			_port_survole = port


func _maj_trace_route() -> void:
	var mesh: ImmediateMesh = _trace_route.mesh
	mesh.clear_surfaces()
	if navire.route.is_empty():
		return

	var points: Array[Vector3] = [navire.global_position]
	for wp in navire.route:
		points.append(Vector3(wp.x, 0.0, wp.z))

	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_set_color(Color(1.0, 0.93, 0.72, 0.85))
	var tiret := 26.0
	var trou := 18.0
	for i in range(points.size() - 1):
		var a := Vector3(points[i].x, 6.0, points[i].z)
		var b := Vector3(points[i + 1].x, 6.0, points[i + 1].z)
		var longueur := a.distance_to(b)
		if longueur < 0.01:
			continue
		var u := (b - a) / longueur
		var t := 0.0
		while t < longueur:
			var t2: float = minf(t + tiret, longueur)
			mesh.surface_add_vertex(a + u * t)
			mesh.surface_add_vertex(a + u * t2)
			t = t2 + trou
	mesh.surface_end()


func _maj_hud() -> void:
	var etat := sim.etat_temps()
	_lbl_date.text = etat["date"]
	_lbl_heure.text = etat["heure"]

	if navire.au_mouillage():
		var p := _port_le_plus_proche(navire.global_position)
		var rade: Vector3 = p["rade"]
		var d := Vector2(navire.global_position.x - rade.x, navire.global_position.z - rade.z).length()
		# À l'ancre au large, on n'est pas « à quai » pour autant
		if d < 70.0:
			_lbl_statut.text = "À quai - %s (%s)" % [p["nom"], p["nation"]]
		else:
			_lbl_statut.text = "En mer - à l'ancre"
	else:
		var duree := sim.duree_traversee(navire.distance_restante(), 8.0)
		var nom: String = navire.destination.get("nom", "")
		if nom == "":
			_lbl_statut.text = "En mer - cap au large, arrivée dans %s" % duree
		else:
			_lbl_statut.text = "En mer - cap sur %s, arrivée dans %s" % [nom, duree]

	for i in _boutons_vitesse.size():
		_boutons_vitesse[i].button_pressed = (int(etat["indice"]) == i + 1)


# --- interactions -------------------------------------------------------------

func _unhandled_input(evenement: InputEvent) -> void:
	if evenement is InputEventMouseButton and evenement.button_index == MOUSE_BUTTON_LEFT:
		if evenement.pressed:
			_clic_depart = evenement.position
			_clic_deplace = false
			_pan_gauche = true
		else:
			_pan_gauche = false
			if not _clic_deplace:
				_clic_gauche(evenement.position)

	elif evenement is InputEventMouseMotion and _pan_gauche:
		if evenement.position.distance_to(_clic_depart) > 6.0:
			_clic_deplace = true
		if _clic_deplace and _port_survole.is_empty():
			camera_rig.deplacer_souris(evenement.relative)

	elif evenement is InputEventKey and evenement.pressed and not evenement.echo:
		match evenement.keycode:
			KEY_SPACE:
				sim.basculer_pause()
			KEY_1, KEY_2, KEY_3, KEY_4:
				_sur_vitesse(evenement.keycode - KEY_0)
			KEY_R:
				camera_rig.viser(navire.global_position)
			KEY_ESCAPE:
				get_tree().quit()


func _clic_gauche(pixel: Vector2) -> void:
	if not _port_survole.is_empty():
		_clic_gauche_sur(_port_survole)
		return

	# Clic en pleine mer : le navire n'est pas tenu d'aller de port en port,
	# il va où on lui dit. La route évite quand même les côtes.
	var sol := camera_rig.point_au_sol(pixel)
	if sol == Vector3.ZERO:
		return
	cap_vers_point(sol)


# Appareillage vers un point quelconque de la mer. Séparé du clic pour être
# testable sans souris.
func cap_vers_point(sol: Vector3) -> bool:
	if sim.est_terre(sol.x, sol.z, 30.0):
		return false
	var route := sim.route(navire.global_position, Vector3(sol.x, 0.0, sol.z))
	if route.is_empty():
		push_warning("Aucune route vers ce point")
		return false
	navire.cap_sur(route, {})
	return true


# Appareillage vers un port donné. Séparé du clic pour être testable sans souris.
func _clic_gauche_sur(port: Dictionary) -> void:
	if port.is_empty():
		return
	var rade: Vector3 = port["rade"]
	if navire.global_position.distance_to(Vector3(rade.x, navire.global_position.y, rade.z)) < 40.0:
		return
	var route := sim.route(navire.global_position, Vector3(rade.x, 0.0, rade.z))
	if route.is_empty():
		push_warning("Aucune route vers %s" % port["nom"])
		return
	navire.cap_sur(route, port)


func _sur_vitesse(indice: int) -> void:
	sim.definir_vitesse(indice)


func _sur_arrivee(port) -> void:
	# On ne met le jeu en pause qu'en arrivant dans un port, comme dans
	# Port Royale. Jeter l'ancre au large n'interrompt rien.
	if port is Dictionary and not port.is_empty():
		print("[jeu] mouillage à %s" % port["nom"])
		sim.definir_vitesse(1)


# --- utilitaires --------------------------------------------------------------

func _port_par_cle(cle: String) -> Dictionary:
	for p in ports:
		if p["cle"] == cle:
			return p
	return ports[0] if not ports.is_empty() else {}


func _port_le_plus_proche(pos: Vector3) -> Dictionary:
	var meilleur: Dictionary = ports[0]
	var d := INF
	for p in ports:
		var rade: Vector3 = p["rade"]
		var dist := Vector2(pos.x - rade.x, pos.z - rade.z).length()
		if dist < d:
			d = dist
			meilleur = p
	return meilleur
