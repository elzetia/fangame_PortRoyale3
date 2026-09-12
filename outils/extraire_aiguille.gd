extends SceneTree

# Detache l'aiguille peinte sur le cadran de `menu_date.png`, pour pouvoir la
# faire tourner a l'heure du jeu.
#
# L'aiguille est le seul noir qui TOUCHE le moyeu : les chiffres romains sont du
# noir eux aussi, mais posés au bord. Une diffusion partie du centre et bornée au
# disque les laisse donc dehors — c'est tout l'astuce, et elle evite d'avoir a
# detourer quoi que ce soit a la main.
#
# Le trou se rebouche en copiant le pixel situe a +90°. La rose des vents a huit
# branches, donc elle est invariante par quart de tour : la matiere qu'on va
# chercher est exactement celle qui manque, decor compris.
#
#   godot --headless --path . --script outils/extraire_aiguille.gd

const SRC := "D:/GOG Galaxy/Games/PortRoyale3D/sprites/ui_pr/menu_date.png"
const HORS := "D:/GOG Galaxy/Games/PortRoyale3D/sprites/ui_pr/menu_date_nu.png"
const AIG := "D:/GOG Galaxy/Games/PortRoyale3D/sprites/ui_pr/aiguille.png"

const CENTRE := Vector2(280.0, 244.5)
const RAYON_DIFFUSION := 88.0        # sous les chiffres romains
const DEMI := 96                     # demi-cote de la texture d'aiguille

func _initialize() -> void:
	var im := Image.load_from_file(SRC)
	var masque := _aiguille(im)
	# On dilate : l'aiguille porte un lisere clair — son reflet — que le seuil du
	# noir laisse passer. Sans ces deux pixels de marge, il restait un fin trait
	# blanc en travers du cadran, plus visible que l'aiguille elle-meme.
	masque = _dilater(masque, 2)
	print("pixels d'aiguille (dilatee) : ", masque.size())
	if masque.size() < 200:
		print("ECHEC : trop peu de pixels, revoir les seuils")
		quit(); return

	# L'angle vers lequel elle pointe : on prend le pixel le plus eloigne du
	# moyeu, c'est la pointe.
	var loin := 0.0
	var angle := 0.0
	for p in masque.keys():
		var v := Vector2(p.x, p.y) - CENTRE
		if v.length() > loin:
			loin = v.length()
			angle = rad_to_deg(atan2(v.y, v.x))
	print("pointe a ", loin, " px, angle peint ", angle, "°")

	# 1. La planche sans son aiguille.
	var nu := Image.create(im.get_width(), im.get_height(), false, im.get_format())
	nu.copy_from(im)
	for p in masque.keys():
		var v := Vector2(p.x, p.y) - CENTRE
		var w := v.rotated(deg_to_rad(90.0)) + CENTRE
		nu.set_pixel(p.x, p.y, im.get_pixel(int(round(w.x)), int(round(w.y))))
	nu.save_png(HORS)
	print("ecrit ", HORS)

	# 2. L'aiguille seule, centree sur son pivot.
	var aig := Image.create(DEMI * 2, DEMI * 2, false, Image.FORMAT_RGBA8)
	aig.fill(Color(0, 0, 0, 0))
	for p in masque.keys():
		var v := Vector2i(p) - Vector2i(CENTRE) + Vector2i(DEMI, DEMI)
		if v.x >= 0 and v.y >= 0 and v.x < DEMI*2 and v.y < DEMI*2:
			aig.set_pixel(v.x, v.y, im.get_pixel(p.x, p.y))
	aig.save_png(AIG)
	print("ecrit ", AIG)
	print("=> a recopier : CENTRE_CADRAN ", CENTRE, "  ANGLE_PEINT ", angle)
	quit()

func _dilater(masque: Dictionary, rayon: int) -> Dictionary:
	var sortie := masque.duplicate()
	for p in masque.keys():
		for dy in range(-rayon, rayon + 1):
			for dx in range(-rayon, rayon + 1):
				var q := Vector2i(p) + Vector2i(dx, dy)
				if Vector2(q.x, q.y).distance_to(CENTRE) <= RAYON_DIFFUSION:
					sortie[q] = true
	return sortie


func _sombre(c: Color) -> bool:
	return c.a > 0.9 and c.r < 0.34 and c.g < 0.34 and c.b < 0.36

func _aiguille(im: Image) -> Dictionary:
	var depart := Vector2i(int(CENTRE.x), int(CENTRE.y))
	if not _sombre(im.get_pixel(depart.x, depart.y)):
		print("ATTENTION : le centre n'est pas sombre")
	var vus := {}
	var file: Array[Vector2i] = [depart]
	vus[depart] = true
	while not file.is_empty():
		var p: Vector2i = file.pop_back()
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1),
				  Vector2i(1,1), Vector2i(-1,-1), Vector2i(1,-1), Vector2i(-1,1)]:
			var q: Vector2i = p + d
			if vus.has(q): continue
			if Vector2(q.x, q.y).distance_to(CENTRE) > RAYON_DIFFUSION: continue
			if _sombre(im.get_pixel(q.x, q.y)):
				vus[q] = true
				file.push_back(q)
	return vus
