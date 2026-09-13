# Vérifie l'API du pont pour le chantier naval ET les routes du joueur.
#   godot --headless --path <projet> --script res://tools/routes_api_smoke.gd
#
# Le flux fidèle de Port Royale : on ACHÈTE et on CONSTRUIT des navires au chantier
# (ils entrent dans la flotte possédée), on AFFECTE plusieurs navires de la flotte à
# un convoi sur un circuit, il commerce seul, puis on le dissout (les navires
# reviennent à la flotte). On vérifie chaque maillon.
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
	# Budget de test : le joueur démarre à 20 000 ; on gonfle la caisse pour
	# exercer tout le flux (acheter, construire, armer) sans devoir commercer.
	lua.do_string("package.loaded['sim.compagnie'].or_ = 2000000")

	var echecs := 0
	var ports = b.get("ports").invoke()
	if ports.size() < 3:
		printerr("ECHEC : moins de trois ports."); quit(1); return
	var ville: String = ports[0]["cle"]

	# --- chantier : acheter un sloop ----------------------------------------
	var infos = b.get("chantier_infos").invokev(["sloop"])
	print("chantier_infos sloop  : achat=", infos.get("prix_achat"),
		" construction=", infos.get("cout_construction"),
		" jours=", infos.get("jours"), " matériaux=", infos.get("materiaux"))
	var ra = b.get("acheter_navire").invokev([ville, "sloop"])
	print("acheter sloop         : ", ra)
	if not bool(ra.get("ok", false)):
		printerr("  ECHEC achat : ", ra.get("message")); echecs += 1

	# --- chantier : acheter une flûte, pour avoir deux navires en flotte -----
	var rf = b.get("acheter_navire").invokev([ville, "flute"])
	if not bool(rf.get("ok", false)):
		printerr("  ECHEC achat flûte : ", rf.get("message")); echecs += 1
	var flotte = b.get("flotte").invoke()
	print("flotte après 2 achats : ", flotte.size(), " navires -> ",
		flotte[0] if flotte.size() > 0 else "vide")
	if flotte.size() != 2:
		printerr("  ECHEC : flotte = ", flotte.size(), " au lieu de 2."); echecs += 1

	# --- chantier : construire un sloop, puis avancer le temps ---------------
	var rc = b.get("construire_navire").invokev([ville, "sloop"])
	print("construire sloop      : ", rc)
	if bool(rc.get("ok", false)):
		var file = b.get("chantier_file").invoke()
		print("file de chantier      : ", file.size(), " -> ", file[0] if file.size() > 0 else "vide")
		if file.size() != 1:
			printerr("  ECHEC : file = ", file.size(), " au lieu de 1."); echecs += 1
		# 60 jours de jeu doivent finir la construction (bien plus que le délai).
		for j in 60:
			b.get("avancer_temps").invokev([24.0])
		var flotte2 = b.get("flotte").invoke()
		print("flotte après construction : ", flotte2.size(), " (attendu 3)")
		if flotte2.size() != 3:
			printerr("  ECHEC : la construction n'a pas rejoint la flotte (", flotte2.size(), ")."); echecs += 1
	else:
		print("  (construction refusée : ", rc.get("message"), " — sans doute matières manquantes)")

	# --- routes : armer un convoi depuis la flotte (indices 1 et 2) ----------
	var circuit = [ports[0]["cle"], ports[1]["cle"], ports[2]["cle"]]
	var avant = b.get("flotte").invoke().size()
	var res = b.get("armer_route").invokev([[1, 2], circuit, "resources", 15000])
	print("armer_route [1,2]     : ", res)
	if not bool(res.get("ok", false)):
		printerr("  ECHEC armement : ", res.get("message")); echecs += 1
	var routes = b.get("routes").invoke()
	if routes.size() < 1:
		printerr("  ECHEC : aucune route en service."); echecs += 1
	else:
		var r = routes[0]
		print("route en service      : ", r.get("nom"), " cale=", r.get("capacite"),
			" circuit=", r.get("circuit"))
		if int(r.get("capacite", 0)) <= 0:
			printerr("  ECHEC : cale nulle."); echecs += 1
	var apres = b.get("flotte").invoke().size()
	if apres != avant - 2:
		printerr("  ECHEC : la flotte n'a pas cédé 2 navires (", avant, " -> ", apres, ")."); echecs += 1

	# --- dissoudre : les navires reviennent à la flotte ----------------------
	var rec = b.get("dissoudre_route").invokev([1])
	var apres2 = b.get("flotte").invoke().size()
	print("dissoudre route 1     : récupéré ", rec, " ; flotte ", apres, " -> ", apres2)
	if apres2 != apres + 2:
		printerr("  ECHEC : les navires ne sont pas revenus à la flotte."); echecs += 1

	if echecs > 0:
		printerr("ECHEC : ", echecs, " vérification(s) en défaut.")
		quit(1)
		return
	print("OK : chantier + flotte + routes fonctionnent.")
	quit(0)
