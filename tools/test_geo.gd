extends SceneTree
func _init() -> void:
	var sim = Sim.new()
	if not sim.pret: printerr("sim : ", sim.erreur); quit(1); return
	print("cases de navigation : ", sim.preparer_navigation())
	print("limites : ", sim.limites())
	for p in sim.ports():
		print("  %-14s bourg=%s rade=%s" % [p["nom"], p["bourg"], p["rade"]])
	var r = sim.route(Vector3(-906, 0, -509), Vector3(1008, 0, 511))
	print("route Cartagene -> Grande Bahama : ", r.size(), " points")
	print("est_terre au centre d'une ile (-906,-509) : ", sim.est_terre(-906.0, -509.0, 0.0))
	print("est_terre en pleine mer (0,-700)         : ", sim.est_terre(0.0, -700.0, 0.0))
	quit(0)
