extends SceneTree

# Découpe une planche de navire en neuf vues, les détoure, et en fait un atlas.
#
# Les planches arrivent en grille 3 x 3 sur un aplat gris : huit orientations
# autour, la vue de dessus au centre. On ne peut pas couper la grille au tiers —
# les bateaux ne sont pas centrés dans leur case et débordent inégalement. On
# cherche donc les NEUF TACHES par diffusion, et chacune donne sa propre boîte.
#
# Le détourage ne peut pas se faire au seuil de luminance : la voile est presque
# blanche mais le pont est sombre, et l'ombre portée est plus sombre encore que
# le fond. Ce qui sépare le navire du gris, c'est la COULEUR — le fond et son
# ombre sont parfaitement neutres, la coque est bleue, dorée, brune. On garde
# donc ce qui est coloré, plus ce qui est nettement plus clair que le fond.
#
#   godot --headless --path . --script outils/decouper_navire.gd -- <planche.png> <cote>

# Écart entre le canal le plus fort et le plus faible, au-delà duquel un pixel
# est « coloré » donc au navire.
const SATURATION := 0.10
# Luminance au-dessus de laquelle un pixel gris appartient quand même au navire
# (la voile, les reflets du pont).
const CLARTE := 0.42
const TACHE_MINI := 4000      # pixels : en dessous, c'est une salissure


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("usage : ... -- <planche.png> <cote de la case>")
		quit(); return
	var chemin: String = args[0]
	var cote := int(args[1])
	var im := Image.load_from_file(chemin)
	if im == null:
		print("illisible : ", chemin); quit(); return
	im.convert(Image.FORMAT_RGBA8)
	print(chemin, " ", im.get_size())

	var l := im.get_width()
	var h := im.get_height()

	# 1. Le masque du navire, pixel par pixel.
	var garde := PackedByteArray()
	garde.resize(l * h)
	var n_garde := 0
	for y in range(h):
		for x in range(l):
			if _au_navire(im.get_pixel(x, y)):
				garde[y * l + x] = 1
				n_garde += 1
	print("  pixels de navire : ", n_garde)

	# 2. Les taches, par diffusion.
	var vu := PackedByteArray()
	vu.resize(l * h)
	var taches: Array = []
	for y0 in range(h):
		for x0 in range(l):
			var d := y0 * l + x0
			if garde[d] == 0 or vu[d] == 1:
				continue
			var file: Array[Vector2i] = [Vector2i(x0, y0)]
			vu[d] = 1
			var minx := x0; var maxx := x0; var miny := y0; var maxy := y0
			var n := 0
			while not file.is_empty():
				var p: Vector2i = file.pop_back()
				n += 1
				minx = mini(minx, p.x); maxx = maxi(maxx, p.x)
				miny = mini(miny, p.y); maxy = maxi(maxy, p.y)
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						var q := Vector2i(p.x + dx, p.y + dy)
						if q.x < 0 or q.y < 0 or q.x >= l or q.y >= h:
							continue
						var e := q.y * l + q.x
						if garde[e] == 1 and vu[e] == 0:
							vu[e] = 1
							file.push_back(q)
			if n >= TACHE_MINI:
				taches.append({"rect": Rect2i(minx, miny, maxx - minx + 1,
											 maxy - miny + 1), "n": n})
	print("  taches retenues : ", taches.size())
	if taches.size() != 9:
		print("  ATTENTION : neuf vues attendues")

	# 3. Rangées de haut en bas, puis de gauche à droite : l'ordre de lecture de
	#    la planche, qui est celui de la rose des vents.
	taches.sort_custom(func(a, b):
		var ra: Rect2i = a["rect"]
		var rb: Rect2i = b["rect"]
		var ca := ra.position.y + ra.size.y / 2
		var cb := rb.position.y + rb.size.y / 2
		if absi(ca - cb) > h / 6:
			return ca < cb
		return ra.position.x < rb.position.x)

	# 4. Chaque vue, détourée et posée au centre de sa case.
	var atlas := Image.create(cote * taches.size(), cote, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	for i in taches.size():
		var r: Rect2i = taches[i]["rect"]
		var vue := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
		for y in range(r.size.y):
			for x in range(r.size.x):
				var sx := r.position.x + x
				var sy := r.position.y + y
				if garde[sy * l + sx] == 1:
					vue.set_pixel(x, y, im.get_pixel(sx, sy))
				else:
					vue.set_pixel(x, y, Color(0, 0, 0, 0))
		# À l'échelle, en gardant les proportions : une vue de profil est bien
		# plus large que haute, l'étirer la ferait grossir d'une case à l'autre.
		var ech: float = float(cote) / float(maxi(r.size.x, r.size.y))
		var nl := maxi(int(round(r.size.x * ech)), 1)
		var nh := maxi(int(round(r.size.y * ech)), 1)
		vue.resize(nl, nh, Image.INTERPOLATE_LANCZOS)
		atlas.blit_rect(vue, Rect2i(0, 0, nl, nh),
			Vector2i(i * cote + (cote - nl) / 2, (cote - nh) / 2))
		print("    vue ", i, " ", r.size, " -> ", Vector2i(nl, nh))

	var sortie := chemin.get_basename() + "_atlas.png"
	atlas.save_png(sortie)
	print("  ecrit ", sortie, " ", atlas.get_size())
	quit()


func _au_navire(c: Color) -> bool:
	if c.a < 0.5:
		return false
	var hi: float = maxf(c.r, maxf(c.g, c.b))
	var lo: float = minf(c.r, minf(c.g, c.b))
	if hi - lo > SATURATION:
		return true
	return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) > CLARTE
