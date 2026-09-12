extends SceneTree

# Rend transparent le fond sombre d'une planche, puis la recadre et la reduit.
#
# Les icones arrivent parfois sur un aplat noir avec un halo : posees telles
# quelles sur la carte, elles y collent un rectangle noir. On ne peut pas se
# contenter d'un seuil de luminance sur toute l'image -- les contours bruns qui
# dessinent l'objet sont sombres eux aussi et disparaitraient avec le fond. On
# part donc des BORDS par diffusion : seul ce qui touche le cadre par une chaine
# de pixels sombres est du fond.
#
#   godot --headless --path . --script outils/detourer_fond.gd -- <png> <cote>

const SEUIL := 0.30      # luminance en dessous de laquelle un pixel est « fond »

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("usage : ... -- <fichier.png> <cote voulu>")
		quit(); return
	var chemin: String = args[0]
	var cote := int(args[1])
	var im := Image.load_from_file(chemin)
	if im == null:
		print("illisible : ", chemin); quit(); return
	print(chemin, " ", im.get_size())
	im.convert(Image.FORMAT_RGBA8)

	var l := im.get_width()
	var h := im.get_height()
	var fond := {}
	var file: Array[Vector2i] = []
	for x in range(l):
		for y in [0, h - 1]:
			var p := Vector2i(x, y)
			if _sombre(im, p) and not fond.has(p):
				fond[p] = true; file.push_back(p)
	for y in range(h):
		for x in [0, l - 1]:
			var p2 := Vector2i(x, y)
			if _sombre(im, p2) and not fond.has(p2):
				fond[p2] = true; file.push_back(p2)

	while not file.is_empty():
		var p3: Vector2i = file.pop_back()
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var q: Vector2i = p3 + d
			if q.x < 0 or q.y < 0 or q.x >= l or q.y >= h: continue
			if fond.has(q): continue
			if _sombre(im, q):
				fond[q] = true; file.push_back(q)
	print("  fond : ", fond.size(), " pixels")
	for p4 in fond.keys():
		im.set_pixelv(p4, Color(0, 0, 0, 0))

	# Recadrage sur ce qui reste vraiment visible.
	var minx := 99999; var maxx := -1; var miny := 99999; var maxy := -1
	for y in range(h):
		for x in range(l):
			if im.get_pixel(x, y).a > 0.4:
				minx = mini(minx,x); maxx = maxi(maxx,x)
				miny = mini(miny,y); maxy = maxi(maxy,y)
	if maxx < 0:
		print("  plus rien d'opaque"); quit(); return
	var r := Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)
	var coupe := im.get_region(r)
	print("  recadre ", r.size)

	var ech: float = float(cote) / float(maxi(r.size.x, r.size.y))
	coupe.resize(maxi(int(round(r.size.x * ech)), 1),
				 maxi(int(round(r.size.y * ech)), 1), Image.INTERPOLATE_LANCZOS)
	coupe.save_png(chemin)
	print("  -> ", coupe.get_size())
	quit()

func _sombre(im: Image, p: Vector2i) -> bool:
	var c := im.get_pixel(p.x, p.y)
	if c.a < 0.4:
		return true
	return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) < SEUIL
