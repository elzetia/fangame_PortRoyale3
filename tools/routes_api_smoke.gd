# Vérifie l'API du pont pour les routes commerciales automatiques du joueur.
#   godot --headless --path <projet> --script res://tools/routes_api_smoke.gd
#
# On arme un convoi de deux navires sur un circuit de trois villes, on relit la
# route, puis on la dissout. Le point délicat est le passage d'un Array Godot au
# Lua : il arrive en userdata indexé depuis 0, pas en table — d'où la vérif que
# la cale cumulée des deux navires (et non d'un seul) revient bien.
extends SceneTree


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

	var echecs := 0

	# Les stratégies proposées à l'interface.
	var strats = b.get("strategies").invoke()
	print("stratégies            : ", strats.size(), " -> ", strats)
	if strats.size() < 1:
		printerr("  ECHEC : aucune stratégie proposée."); echecs += 1

	# Le catalogue des navires marchands, avec cale et entretien.
	var nv = b.get("navires_marchands").invoke()
	print("navires marchands     : ", nv.size(), " types ; 1er=", nv[0] if nv.size() > 0 else "aucun")
	if nv.size() < 1:
		printerr("  ECHEC : aucun navire marchand."); echecs += 1

	# Arme une route de deux navires sur trois villes.
	var ports = b.get("ports").invoke()
	if ports.size() < 3:
		printerr("ECHEC : moins de trois ports, circuit impossible."); quit(1); return
	var circuit = [ports[0]["cle"], ports[1]["cle"], ports[2]["cle"]]
	var cale_flute := _cale_de(nv, "flute")
	var cale_sloop := _cale_de(nv, "sloop")
	var res = b.get("armer_route").invokev([["flute", "sloop"], circuit, "resources", 15000])
	print("armer_route           : ", res)
	if not bool(res.get("ok", false)):
		printerr("  ECHEC : route non armée : ", res.get("message", "?")); echecs += 1

	# Relit la route : c'est `routes()` qui porte le détail (cale, circuit), et
	# c'est ce que lit l'écran de gestion. On y vérifie que la cale est bien la
	# SOMME des deux navires — sinon l'Array Godot n'a pas été lu en entier.
	var routes = b.get("routes").invoke()
	print("routes en service     : ", routes.size(), " -> ", routes[0] if routes.size() > 0 else "aucune")
	if routes.size() < 1:
		printerr("  ECHEC : la route armée n'apparaît pas."); echecs += 1
	else:
		var r = routes[0]
		var cale = int(r.get("capacite", 0))
		var attendu := cale_flute + cale_sloop
		print("  cale cumulée         : ", cale, " (attendu ", attendu, " = flûte+sloop)")
		if attendu > 0 and cale != attendu:
			printerr("  ECHEC : cale ", cale, " ≠ somme des deux navires ", attendu,
				" — l'Array n'a pas été lu en entier."); echecs += 1
		var circ = r.get("circuit", []) as Array
		print("  circuit              : ", circ)
		if circ.size() != 3:
			printerr("  ECHEC : ", circ.size(), " escales au lieu de 3."); echecs += 1
	var rec = b.get("dissoudre_route").invokev([1])
	var reste = b.get("routes").invoke().size()
	print("dissoudre route 1     : récupéré ", rec, " ; restantes ", reste)
	if reste != 0:
		printerr("  ECHEC : la route n'a pas été dissoute."); echecs += 1

	if echecs > 0:
		printerr("ECHEC : ", echecs, " vérification(s) en défaut.")
		quit(1)
		return
	print("OK : l'API des routes du joueur fonctionne.")
	quit(0)


# La cale d'un type de navire dans le catalogue renvoyé par le pont, 0 si absent.
func _cale_de(navires, cle: String) -> int:
	for n in navires:
		if String(n.get("cle", "")) == cle:
			return int(n.get("cale", 0))
	return 0
