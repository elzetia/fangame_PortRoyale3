extends SceneTree

# Recadre un PNG sur ses pixels visibles. Les planches d'interface arrivent
# souvent centrees dans une grande toile vide : gardee telle quelle, l'image
# reserve de la place pour du rien, et tout calcul de marge en NinePatch porte
# sur des proportions fausses.
#
#   godot --headless --path . --script outils/recadrer.gd -- <fichier.png>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage : ... --script outils/recadrer.gd -- <fichier.png>")
		quit(); return
	var chemin: String = args[0]
	var im := Image.load_from_file(chemin)
	if im == null:
		print("illisible : ", chemin); quit(); return
	print(chemin, " : ", im.get_size())
	var r := im.get_used_rect()
	print("  pixels visibles : ", r)
	if r.size.x <= 0 or r.size.y <= 0:
		print("  rien d'opaque"); quit(); return
	if r.position == Vector2i.ZERO and r.size == im.get_size():
		print("  deja au plus juste"); quit(); return
	var coupe := im.get_region(r)
	coupe.save_png(chemin)
	print("  recadre a ", coupe.get_size(), " -> ", chemin)
	quit()
