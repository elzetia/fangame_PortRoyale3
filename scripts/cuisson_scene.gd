# Scène dédiée à la cuisson de la carte, séparée du jeu :
#   godot --path <projet> res://scenes/cuisson.tscn -- --cuire <fichier.png> [largeur] [angle]
extends Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var k := args.find("--cuire")
	if k < 0 or k + 1 >= args.size():
		printerr("usage : -- --cuire <fichier.png> [largeur] [angle]")
		get_tree().quit(1)
		return

	var largeur := 4096
	if k + 2 < args.size() and args[k + 2].is_valid_int():
		largeur = int(args[k + 2])
	var angle := 58.0
	if k + 3 < args.size() and args[k + 3].is_valid_float():
		angle = float(args[k + 3])

	var sim := Sim.new()
	if not sim.pret:
		printerr("simulation Lua absente : ", sim.erreur)
		get_tree().quit(1)
		return

	var res: Dictionary = await CuissonCarte.cuire(self, sim, args[k + 1], largeur, angle, not args.has("--sans-palmiers"))
	print("[cuisson] %s %s  %s px  %.2f m/px  angle %.0f deg  %.1f s" % [
		args[k + 1], "ok" if res["ok"] else "ECHEC %d" % res["erreur"],
		res["pixels"], res["metres_par_pixel"], res["angle"], res["secondes"]])
	get_tree().quit(0 if res["ok"] else 1)
