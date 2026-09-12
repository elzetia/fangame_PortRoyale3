extends SceneTree

# Prepare `bas_de_menu.png` pour servir de bordure basse en NinePatchRect.
#
# La planche arrive en 1774 x 887, deux equerres dorees perdues dans du vide, et
# chacune fait 390 px de large. Un NinePatch ne met PAS ses coins a l'echelle :
# ils gardent leur taille en pixels source. Postee telle quelle sous un menu de
# 790 de large, les deux equerres en mangeaient la quasi-totalite.
#
# On recadre donc sur la bande utile, puis on reduit a une hauteur ou l'equerre
# pese ce qu'elle doit peser -- une soixantaine de pixels, comme celles du
# bandeau de titre.
#
#   godot --headless --path . --script outils/preparer_bas_menu.gd

const SRC := "D:/GOG Galaxy/Games/PortRoyale3D/sprites/ui_pr/bas_de_menu.png"
const HAUTEUR_VOULUE := 64

func _initialize() -> void:
	var im := Image.load_from_file(SRC)
	if im == null:
		print("illisible"); quit(); return
	print("source ", im.get_size())

	# Boite englobante des pixels VRAIMENT opaques : `get_used_rect` retient des
	# pixels a alpha quasi nul et rend presque toute la toile.
	var minx := 99999; var maxx := -1; var miny := 99999; var maxy := -1
	for y in range(im.get_height()):
		for x in range(im.get_width()):
			if im.get_pixel(x, y).a > 0.5:
				minx = mini(minx,x); maxx = maxi(maxx,x)
				miny = mini(miny,y); maxy = maxi(maxy,y)
	var r := Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)
	print("bande utile ", r)

	var coupe := im.get_region(r)
	var ech := float(HAUTEUR_VOULUE) / float(r.size.y)
	var large := int(round(r.size.x * ech))
	coupe.resize(large, HAUTEUR_VOULUE, Image.INTERPOLATE_LANCZOS)
	coupe.save_png(SRC)
	print("ecrit ", coupe.get_size())
	print("=> marge NinePatch gauche/droite conseillee : ",
		int(round(390.0 * ech)) + 2)
	quit()
