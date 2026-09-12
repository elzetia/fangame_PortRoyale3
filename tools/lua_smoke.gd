# Vérifie que la simulation Lua se charge et renvoie bien des types Godot natifs.
#   godot --headless --path <projet> --script res://tools/lua_smoke.gd
extends SceneTree


func _init() -> void:
	if not ClassDB.class_exists("LuaState"):
		printerr("ECHEC : classe LuaState absente, extension non chargée.")
		quit(1)
		return

	var lua = ClassDB.instantiate("LuaState")
	lua.open_libraries()
	print("runtime      : ", lua.do_string("return _VERSION"))

	var bridge = lua.do_file("res://sim/bridge.lua")
	if bridge is LuaError:
		printerr("ECHEC chargement sim/bridge.lua : ", bridge)
		quit(1)
		return

	var iles = bridge.get("iles").invoke(32)
	print("iles         : ", type_string(typeof(iles)), " n=", iles.size())
	for i in iles:
		print("  %-18s centre=%s rayon=%s contour=%d pts" % [
			i["nom"], i["centre"], i["rayon"], i["contour"].size()])

	var ports = bridge.get("ports").invoke()
	print("ports        : ", type_string(typeof(ports)), " n=", ports.size())
	for p in ports:
		print("  %-14s %-12s rade=%s couleur=%s" % [
			p["nom"], p["nation"], p["rade"], p["couleur"]])

	var terre = bridge.get("est_terre")
	print("est_terre centre d'ile (-880,-510) : ", terre.invoke(-880.0, -510.0, 0.0), " (attendu true)")
	print("est_terre pleine mer  (0,-900)     : ", terre.invoke(0.0, -900.0, 0.0), " (attendu false)")

	print("OK : le pont Lua fonctionne.")
	quit(0)
