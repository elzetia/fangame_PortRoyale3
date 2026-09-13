extends SceneTree

# Rend les navires de carte de Port Royale 3 en atlas de trente-deux caps.
#
# La carte ne passe pas en 3D pour autant : elle choisit, pour chaque navire, la
# vignette de son cap. C'est ce que faisait déjà la pinasse dessinée, en huit
# vues ; les modèles de PR3 permettent d'en rendre trente-deux, et un navire qui
# vire ne saute plus d'un huitième de tour à l'autre.
#
# Les maillages sont lus tels qu'`outils/extraire_navires_pr3.py` les a posés
# dans `reference_pr3/navires_wm/`, et les atlas écrits à côté. Rien de tout cela
# n'entre dans git : ce sont des modèles sous droits, en attendant ceux du projet.
#
# Le format des tampons est décrit dans `outils/pr3_mesh.py` : taille des
# données à l'octet 10, quatre-vingts octets par sommet — position, couleur,
# normale, tangente, binormale, uv.
#
# LA TEXTURE EST UN FLIPBOOK. Les seize navires partagent `0_ships_wm.dds`, une
# grille de trois variantes sur trois ; chaque variante est une même palette de
# bois, de toiles et de peintures, dont seule la couleur des VOILES change. Les
# UV d'un navire couvrent une variante entière, de 0 à 1, et le shader de PR3 les
# ramène dans la case voulue (son paramètre `g_flipBook`). Au premier rendu on les
# avait appliquées à toute la texture : chaque pièce tombait trois carreaux trop
# loin, et les navires sortaient vert olive, voiles rayées de rouge.
#
# Les neuf variantes répondent sans doute aux couleurs de voiles que règle l'exe
# (`SailColor_Trader`, `SailColor_Nation`, `SailColor_Pirate`, `SailColor_Player0`…),
# dans un ordre qu'aucune table lisible ne donne. On les rend donc toutes, et la
# carte choisit.
#
# L'outil a BESOIN d'un vrai rendu — donc pas de `--headless`.
#
#   py -3 outils/extraire_navires_pr3.py
#   godot --path . --script outils/rendre_navires_pr3.gd [-- <modele> ...]

const SOURCE := "res://reference_pr3/navires_wm"
const CAPS := 32
const COLONNES := 8
const COTE := 160
const VARIANTES := 9          # trois sur trois
# Plus bas que l'atlas procédural (72°). Celui-là n'avait qu'une voile triangulaire
# et une coque ; les navires de PR3 portent des voiles carrées sur de hauts mâts,
# et à 72° on les voyait par la tranche — une flûte marchande se réduisait à une
# coque noire barrée de traits. À 60° la toile se montre.
const ELEVATION := 60.0
const AZIMUT_SOLEIL := 135.0

var _dossier := ""
var _travaux: Array = []          # [modele, variante]
var _maillages: Dictionary = {}
var _i_travail := 0
var _i_cap := 0
var _attente := 2
var _images: Array[Image] = []
var _vue: SubViewport
var _pivot: Node3D
var _instance: MeshInstance3D
var _mat: StandardMaterial3D
var _pret := false


func _initialize() -> void:
	_dossier = ProjectSettings.globalize_path(SOURCE)
	var d := DirAccess.open(_dossier)
	if d == null:
		print("dossier absent : ", _dossier, " — lance d'abord outils/extraire_navires_pr3.py")
		quit(1)
		return
	var modeles: Array[String] = []
	for nom in d.get_directories():
		if nom.ends_with("_wm") and FileAccess.file_exists(
				_dossier.path_join(nom).path_join(nom + "_baseshape.vbuf")):
			modeles.append(nom)
	modeles.sort()
	if modeles.is_empty():
		print("aucun navire dans ", _dossier)
		quit(1)
		return

	var image := Image.load_from_file(_dossier.path_join("0_ships_wm.png"))
	if image == null:
		print("texture absente : 0_ships_wm.png")
		quit(1)
		return
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)

	# UNE échelle pour tous : la caméra est cadrée sur le plus grand navire, et
	# chaque atlas garde donc les proportions du jeu — une pinasse reste trois fois
	# plus courte qu'un vaisseau de ligne. Cadrer chaque navire sur sa propre case
	# les aurait tous rendus de la même taille.
	#
	# Le cadrage se calcule sur TOUS les navires, même quand on n'en rend qu'un :
	# sinon l'atlas refait isolément n'aurait plus la même échelle que les autres.
	var hauteur := 0.0
	for nom in modeles:
		var m := _charger(nom)
		_maillages[nom] = m
		hauteur = maxf(hauteur, m.get_aabb().end.y)
	# La caméra vise un peu au-dessus de la flottaison, au tiers de la mâture ; le
	# rayon qui englobe tout, depuis ce point, fixe le cadrage.
	var cible := Vector3(0.0, hauteur * 0.35, 0.0)
	var englobe := 0.0
	for nom in modeles:
		for p in (_maillages[nom] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var r := Vector2(p.x, p.z).length()
			englobe = maxf(englobe, Vector2(r, p.y - cible.y).length())
	var taille := englobe * 2.05

	var demandes := OS.get_cmdline_user_args()
	for nom in modeles:
		if demandes.is_empty() or demandes.has(nom.trim_suffix("_wm")):
			for v in VARIANTES:
				_travaux.append([nom, v])
	if _travaux.is_empty():
		print("aucun des modeles demandes : ", demandes)
		quit(1)
		return

	_vue = SubViewport.new()
	_vue.size = Vector2i(COTE, COTE)
	_vue.transparent_bg = true
	_vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vue.msaa_3d = Viewport.MSAA_4X
	root.add_child(_vue)

	var monde := Node3D.new()
	_vue.add_child(monde)
	_pivot = Node3D.new()
	monde.add_child(_pivot)
	_instance = MeshInstance3D.new()
	_pivot.add_child(_instance)

	_mat = StandardMaterial3D.new()
	_mat.albedo_texture = texture
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# Les couleurs de sommets de PR3 sont une occlusion en gris, que son shader
	# multiplie à la texture EN ESPACE GAMMA. Les déclarer sRGB reproduit cette
	# multiplication ; lues comme linéaires, elles éclaircissaient tout d'un cran.
	_mat.vertex_color_use_as_albedo = true
	_mat.vertex_color_is_srgb = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.roughness = 0.9
	_mat.metallic_specular = 0.2
	_mat.uv1_scale = Vector3(1.0 / 3.0, 1.0 / 3.0, 1.0)
	_instance.material_override = _mat

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = taille
	var e := deg_to_rad(ELEVATION)
	var dist := englobe * 4.0
	cam.look_at_from_position(cible + Vector3(0.0, sin(e), cos(e)) * dist, cible, Vector3.UP)
	cam.far = dist * 3.0
	monde.add_child(cam)

	# Une lumière de plein jour, surtout AMBIANTE. La texture de PR3 porte déjà
	# son modelé — l'occlusion des couleurs de sommets creuse les recoins — et le
	# soleil n'a qu'à dire de quel côté il vient. Au premier réglage (ambiance bleue
	# à 0,45, soleil seul à porter la lumière) les voiles tournées de biais
	# tombaient dans le noir, et le navire sortait en silhouette sombre sur la mer.
	#
	# L'ambiance est pleine et blanche : à elle seule elle rend la texture telle
	# que PR3 la multiplie à l'occlusion, et le soleil ne fait qu'ajouter son côté
	# éclairé. À 0,80 d'ambiance les voiles blanches sortaient encore grises.
	var soleil := DirectionalLight3D.new()
	soleil.light_energy = 0.55
	var az := deg_to_rad(AZIMUT_SOLEIL)
	soleil.look_at_from_position(Vector3(cos(az) * 50.0, 60.0, sin(az) * 50.0),
		Vector3.ZERO, Vector3.UP)
	monde.add_child(soleil)

	var ciel := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 1.0, 0.97)
	env.ambient_light_energy = 1.0
	ciel.environment = env
	monde.add_child(ciel)

	# La fiche que la carte lit pour poser les vignettes. Le point de flottaison
	# du navire ne tombe pas au centre de la case : la caméra vise plus haut, et
	# la plongée le fait descendre. Sans ce décalage le navire flotterait au-dessus
	# de son sillage.
	var fiche := {
		"caps": CAPS, "colonnes": COLONNES, "cote": COTE,
		"variantes": VARIANTES,
		"taille_modele": taille,
		"decalage_flottaison": cible.y * cos(e) / taille,
		"elevation": ELEVATION,
		"note": "Fichier <modele>_<variante>.png. Case i = etrave au cap i x 11,25 deg, depuis le nord dans le sens horaire. Variante v = case (v mod 3, v div 3) du flipbook.",
	}
	DirAccess.make_dir_recursive_absolute(_dossier.path_join("atlas"))
	var f := FileAccess.open(_dossier.path_join("atlas").path_join("fiche.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(fiche, "\t"))
	f.close()

	_poser_travail()
	_pret = true
	print("%d atlas a rendre, cadre %.1f unites..." % [_travaux.size(), taille])


func _poser_travail() -> void:
	var t: Array = _travaux[_i_travail]
	_instance.mesh = _maillages[t[0]]
	var v := int(t[1])
	_mat.uv1_offset = Vector3(float(v % 3) / 3.0, float(int(v / 3)) / 3.0, 0.0)
	_attente = 2


# Un maillage de carte : une seule pièce, `baseshape`.
#
# PR3 est un moteur Direct3D, en repère main GAUCHE ; Godot est en main droite.
# On retourne donc l'axe x, et avec lui l'ordre des sommets de chaque triangle,
# sinon tribord devient bâbord et toutes les faces regardent vers l'intérieur.
func _charger(nom: String) -> ArrayMesh:
	var base := _dossier.path_join(nom).path_join(nom + "_baseshape")
	var vb := FileAccess.get_file_as_bytes(base + ".vbuf")
	var ib := FileAccess.get_file_as_bytes(base + ".ibuf")
	var tv := vb.decode_u32(10)
	var ti := ib.decode_u32(10)
	var ov := vb.size() - tv
	var oi := ib.size() - ti

	var indices := PackedInt32Array()
	var plus_grand := 0
	for k in int(ti / 2):
		var v := ib.decode_u16(oi + 2 * k)
		indices.append(v)
		plus_grand = maxi(plus_grand, v)
	var n := plus_grand + 1
	var pas := int(tv / n)
	if pas != 80:
		push_warning("%s : %d octets par sommet, 80 attendus" % [nom, pas])

	var positions := PackedVector3Array()
	var normales := PackedVector3Array()
	var uvs := PackedVector2Array()
	var couleurs := PackedColorArray()
	for k in n:
		var o := ov + k * pas
		positions.append(Vector3(-vb.decode_float(o), vb.decode_float(o + 4), vb.decode_float(o + 8)))
		couleurs.append(Color(vb.decode_float(o + 12), vb.decode_float(o + 16), vb.decode_float(o + 20)))
		normales.append(Vector3(-vb.decode_float(o + 28), vb.decode_float(o + 32), vb.decode_float(o + 36)))
		uvs.append(Vector2(vb.decode_float(o + 64), vb.decode_float(o + 68)))
	for k in range(0, indices.size() - 2, 3):
		var t := indices[k + 1]
		indices[k + 1] = indices[k + 2]
		indices[k + 2] = t

	var tableaux := []
	tableaux.resize(Mesh.ARRAY_MAX)
	tableaux[Mesh.ARRAY_VERTEX] = positions
	tableaux[Mesh.ARRAY_NORMAL] = normales
	tableaux[Mesh.ARRAY_TEX_UV] = uvs
	tableaux[Mesh.ARRAY_COLOR] = couleurs
	tableaux[Mesh.ARRAY_INDEX] = indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux)
	return m


func _process(_delta: float) -> bool:
	if not _pret:
		return false
	# Deux images d'avance : la première pose la scène, la seconde la dessine.
	if _attente > 0:
		_attente -= 1
		# Les caps tournent dans le sens horaire vu du ciel : une rotation
		# POSITIVE autour de y tourne l'étrave vers l'ouest, d'où le signe.
		_pivot.rotation.y = -TAU * float(_i_cap) / float(CAPS)
		return false

	_images.append(_vue.get_texture().get_image())
	_i_cap += 1
	if _i_cap < CAPS:
		_attente = 2
		return false

	var t: Array = _travaux[_i_travail]
	_assembler("%s_%d" % [String(t[0]).trim_suffix("_wm"), int(t[1])])
	_images.clear()
	_i_cap = 0
	_i_travail += 1
	if _i_travail >= _travaux.size():
		print("termine.")
		return true
	_poser_travail()
	return false


func _assembler(nom: String) -> void:
	var lignes := int(ceil(float(CAPS) / float(COLONNES)))
	var atlas := Image.create(COLONNES * COTE, lignes * COTE, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	for i in _images.size():
		var im := _images[i]
		im.convert(Image.FORMAT_RGBA8)
		atlas.blit_rect(im, Rect2i(0, 0, COTE, COTE),
			Vector2i((i % COLONNES) * COTE, int(i / COLONNES) * COTE))
	var sortie := _dossier.path_join("atlas").path_join(nom + ".png")
	atlas.save_png(sortie)
	print("  ", sortie.get_file())
