# Une route maritime ne doit JAMAIS passer sur la terre peinte.
#   godot --headless --path <projet> --script res://tools/routes_smoke.gd
#
# La sonde échantillonne chaque segment à la demi-case du masque et refuse le
# lot si un seul point tombe à terre. Elle sépare le MILIEU du trajet des deux
# RACCORDS de mouillage, parce que ce sont deux mécanismes distincts : le
# milieu sort de l'A* sur la grille dilatée, les raccords relient la rade — qui
# borde la terre par définition — à cette grille. Ce sont les raccords qui ont
# longtemps traversé les îles, sans que rien ne le dise.
extends SceneTree

const PAS := 6.0          # une demi-case de masque, en unités de monde


func _init() -> void:
	if not ClassDB.class_exists("LuaState"):
		printerr("ECHEC : classe LuaState absente, extension non chargée.")
		quit(1)
		return
	var lua = ClassDB.instantiate("LuaState")
	lua.open_libraries()
	var b = lua.do_file("res://sim/bridge.lua")
	if b is LuaError:
		printerr("ECHEC chargement sim/bridge.lua : ", b)
		quit(1)
		return
	b.get("preparer_navigation").invoke()

	var est_terre = b.get("est_terre")
	var route = b.get("route")
	var ports = b.get("ports").invoke()
	print("ports : ", ports.size())

	var f_raccord := 0
	var f_milieu := 0
	var sans_route := 0
	var paires := 0
	var pts := 0
	var fautifs := {}

	for i in range(0, ports.size(), 3):
		for j in range(i + 1, ports.size(), 7):
			var a = ports[i]["rade"]
			var c = ports[j]["rade"]
			var r = route.invoke(Vector3(a.x, 0, a.z), Vector3(c.x, 0, c.z))
			paires += 1
			if r.size() == 0:
				sans_route += 1
				print("  AUCUNE ROUTE : %s -> %s" % [ports[i]["nom"], ports[j]["nom"]])
				continue
			var chemin := [Vector2(a.x, a.z)]
			for p in r:
				chemin.append(Vector2(p.x, p.z))
			var n := chemin.size() - 1
			for k in range(n):
				var f := _terre_sur(est_terre, chemin[k], chemin[k + 1])
				pts += f[1]
				if f[0] > 0:
					if k == 0 or k == n - 1:
						f_raccord += f[0]
						var cle: String = ports[i]["nom"] if k == 0 else ports[j]["nom"]
						fautifs[cle] = int(fautifs.get(cle, 0)) + f[0]
					else:
						f_milieu += f[0]

	print("paires testées        : ", paires)
	print("sans route            : ", sans_route)
	print("points échantillonnés : ", pts)
	print("fautes au MILIEU      : ", f_milieu)
	print("fautes aux RACCORDS   : ", f_raccord)
	if not fautifs.is_empty():
		print("ports en cause :")
		for k in fautifs:
			print("  %-18s %d points" % [k, fautifs[k]])

	if f_milieu > 0 or f_raccord > 0 or sans_route > 0:
		printerr("ECHEC : une route passe sur la terre, ou un port est isolé.")
		quit(1)
		return
	print("OK : aucune route ne touche la terre.")
	quit(0)


# Renvoie [fautes, points échantillonnés] pour un segment.
func _terre_sur(est_terre, p0: Vector2, p1: Vector2) -> Array:
	var n := int(ceil(p0.distance_to(p1) / PAS))
	var f := 0
	for s in range(n + 1):
		var q: Vector2 = p0.lerp(p1, float(s) / float(n))
		if est_terre.invoke(q.x, q.y, 0.0):
			f += 1
	return [f, n + 1]
