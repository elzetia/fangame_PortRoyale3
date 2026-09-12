extends SceneTree

# Pré-rend le navire 3D sous N caps, et en fait un atlas de vignettes.
#
# La carte dessinait ses bateaux au polygone : une coque hexagonale et un
# triangle pour la voile. C'est lisible mais plat, et l'archipel autour est en
# volume — le navire y flottait comme une pièce de jeu de société.
#
# On ne passe pas la carte en 3D pour autant. Port Royale 3 fait exactement
# l'inverse : ses ports sont des modèles 3D, mais ses pavillons et ses vignettes
# sont des sprites. On rend donc le maillage une fois pour toutes, sous chaque
# cap, et la carte n'a plus qu'à choisir la bonne case. Aucun coût par image,
# aucune lumière à accorder avec celle de la carte cuite : elle est cuite dedans.
#
# L'outil a BESOIN d'un vrai rendu — donc pas de `--headless`, qui n'ouvre aucun
# contexte graphique et rendrait des vignettes vides.
#
#   godot --path . --script outils/rendre_navires.gd

const SORTIE := "D:/GOG Galaxy/Games/PortRoyale3D/sprites/navires/atlas.png"
const FICHE := "D:/GOG Galaxy/Games/PortRoyale3D/sprites/navires/atlas.json"

# 32 caps : un pas de 11,25°, sous lequel l'œil ne distingue plus le saut d'une
# vignette à l'autre quand le navire vire.
const CAPS := 32
const COLONNES := 8
const COTE := 128

# Plus haut que les 58° des villages et des palmiers : eux sont posés à terre et
# se regardent de biais, alors qu'un navire se suit sur l'eau, presque d'aplomb.
# A 58° la coque paraissait couchée et le mât barrait la vignette.
const ELEVATION := 72.0
# La lumière vient du haut-gauche, comme sur toutes les planches du jeu.
const AZIMUT_SOLEIL := 135.0

var _vue: SubViewport
var _pivot: Node3D
var _i := 0
var _attente := 2
var _images: Array[Image] = []
var _navire: Node3D
var _materiau_pose := false


func _initialize() -> void:
	var dossier := SORTIE.get_base_dir()
	if not DirAccess.dir_exists_absolute(dossier):
		DirAccess.make_dir_recursive_absolute(dossier)

	_vue = SubViewport.new()
	_vue.size = Vector2i(COTE, COTE)
	_vue.transparent_bg = true
	_vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Sans anticrénelage, les haubans et les vergues papillotent d'un cap à
	# l'autre ; à cette taille de vignette, c'est tout ce qui se voit.
	_vue.msaa_3d = Viewport.MSAA_4X
	root.add_child(_vue)

	var monde := Node3D.new()
	_vue.add_child(monde)

	_pivot = Node3D.new()
	monde.add_child(_pivot)

	# Le maillage vient de `Navire`, pas d'une copie : deux géométries à tenir
	# d'accord finiraient par diverger, et la vignette montrerait un autre bateau
	# que celui de la simulation.
	var n := Navire.new()
	_pivot.add_child(n)
	_navire = n

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Le navire mesure 45 unités de l'étrave à la poupe ; on laisse respirer.
	cam.size = 62.0
	var d := 120.0
	var e := deg_to_rad(ELEVATION)
	# `look_at_from_position` et non `look_at` : celui-ci exige que le noeud soit
	# deja dans l'arbre, et on vise avant d'y entrer.
	cam.look_at_from_position(Vector3(0.0, sin(e) * d, cos(e) * d),
							  Vector3(0.0, 6.0, 0.0), Vector3.UP)
	monde.add_child(cam)

	var soleil := DirectionalLight3D.new()
	soleil.light_energy = 0.95
	var a := deg_to_rad(AZIMUT_SOLEIL)
	soleil.look_at_from_position(Vector3(cos(a) * 50.0, 60.0, sin(a) * 50.0),
								 Vector3.ZERO, Vector3.UP)
	monde.add_child(soleil)

	var ciel := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Un ambiant DISCRET : a pleine force, il s'ajoutait au soleil et delavait la
	# coque brune jusqu'au beige, voiles et borde confondus. Le ciel des Caraibes
	# n'a pas a repeindre le bateau, seulement a deboucher ses ombres.
	env.ambient_light_color = Color(0.58, 0.68, 0.82)
	env.ambient_light_energy = 0.35
	ciel.environment = env
	monde.add_child(ciel)

	print("rendu de ", CAPS, " caps...")


func _process(_delta: float) -> bool:
	if _pivot == null:
		return false
	if not _materiau_pose:
		_poser_materiau()
		_materiau_pose = true
	# Deux images d'avance : la première pose la scène, la seconde la dessine.
	if _attente > 0:
		_attente -= 1
		_pivot.rotation.y = TAU * float(_i) / float(CAPS)
		return false

	var im := _vue.get_texture().get_image()
	_images.append(im)
	_i += 1
	if _i >= CAPS:
		_assembler()
		return true
	_attente = 2
	return false


# Les couleurs du maillage sont posées sommet par sommet, mais un
# StandardMaterial3D ne les lit comme albedo que si on le lui dit — et, en 4.x,
# seulement en les déclarant sRGB. Sans cela le rendu prend l'albédo blanc par
# défaut : coque, pont et voiles sortaient du même beige délavé.
func _poser_materiau() -> void:
	for enfant in _navire.get_children():
		var mi := enfant as MeshInstance3D
		if mi == null:
			continue
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 0.85
		mat.specular = 0.15
		mi.material_override = mat


func _assembler() -> void:
	var lignes := int(ceil(float(CAPS) / float(COLONNES)))
	var atlas := Image.create(COLONNES * COTE, lignes * COTE, false,
							  Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	for i in _images.size():
		var x := (i % COLONNES) * COTE
		var y := int(i / COLONNES) * COTE
		atlas.blit_rect(_images[i], Rect2i(0, 0, COTE, COTE), Vector2i(x, y))
	atlas.save_png(SORTIE)

	var fiche := {
		"caps": CAPS, "colonnes": COLONNES, "cote": COTE,
		"elevation": ELEVATION, "azimut_soleil": AZIMUT_SOLEIL,
		"note": "Case 0 = etrave vers le NORD ; les caps tournent dans le sens horaire.",
	}
	var f := FileAccess.open(FICHE, FileAccess.WRITE)
	f.store_string(JSON.stringify(fiche, "\t"))
	f.close()
	print("atlas ecrit : ", SORTIE, " (", atlas.get_size(), ")")
