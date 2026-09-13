# Vérifie les convois MANUELS du joueur : fabriquer, ordonner un déplacement, arriver.
#   godot --headless --path <projet> --script res://tools/convois_smoke.gd
extends SceneTree


func _init() -> void:
	if not ClassDB.class_exists("LuaState"):
		printerr("ECHEC : LuaState absente."); quit(1); return
	var lua = ClassDB.instantiate("LuaState")
	lua.open_libraries()
	var b = lua.do_file("res://sim/bridge.lua")
	if b is LuaError:
		printerr("ECHEC bridge : ", b); quit(1); return
	b.get("preparer_navigation").invoke()
	lua.do_string("package.loaded['sim.compagnie'].or_ = 2000000")

	var echecs := 0
	var ports = b.get("ports").invoke()
	var depart := ""
	for p in ports:
		if int(p.get("niveau_chantier", 0)) >= 2:
			depart = String(p["cle"]); break
	# une destination différente
	var arrivee := ""
	for p in ports:
		if String(p["cle"]) != depart:
			arrivee = String(p["cle"]); break
	print("départ=", depart, " arrivée=", arrivee)

	# Deux navires achetés, puis un convoi manuel.
	b.get("acheter_navire").invokev([depart, "sloop"])
	b.get("acheter_navire").invokev([depart, "sloop"])
	var rc = b.get("creer_convoi").invokev([[1, 2], depart])
	print("creer_convoi          : ", rc)
	if not bool(rc.get("ok", false)):
		printerr("  ECHEC création."); echecs += 1

	var cj = b.get("convois_joueur").invoke()
	print("convois joueur        : ", cj.size(), " -> ", cj[0] if cj.size() > 0 else "aucun")
	if cj.size() != 1 or String((cj[0] as Dictionary).get("mode", "")) != "manuel":
		printerr("  ECHEC : pas un convoi manuel."); echecs += 1
	if not bool((cj[0] as Dictionary).get("a_quai", false)):
		printerr("  ECHEC : le convoi neuf devrait être à quai."); echecs += 1

	# On l'ordonne vers l'arrivée, puis on avance le temps.
	var ro = b.get("ordonner_convoi").invokev([1, arrivee])
	print("ordonner_convoi       : ", ro)
	if not bool(ro.get("ok", false)):
		printerr("  ECHEC ordre."); echecs += 1
	# juste après l'ordre, il doit être EN MER (a_quai faux)
	var apres_ordre = b.get("convois_joueur").invoke()[0] as Dictionary
	print("après ordre           : a_quai=", apres_ordre.get("a_quai"), " dest=", apres_ordre.get("destination"))

	for j in 300:
		b.get("avancer_temps").invokev([24.0])
	var fin = b.get("convois_joueur").invoke()[0] as Dictionary
	print("après 300 j           : a_quai=", fin.get("a_quai"), " ville=", fin.get("ville"))
	if not bool(fin.get("a_quai", false)) or String(fin.get("ville", "")) != arrivee:
		printerr("  ECHEC : le convoi n'est pas arrivé à ", arrivee, " (ville=", fin.get("ville"), ")."); echecs += 1

	if echecs > 0:
		printerr("ECHEC : ", echecs, " en défaut."); quit(1); return
	print("OK : convois manuels — fabriquer, ordonner, arriver.")
	quit(0)
