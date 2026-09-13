# Vérifie le modèle unifié des convois du joueur :
#   godot --headless --path <projet> --script res://tools/convois_smoke.gd
# - le joueur DÉMARRE avec un convoi (l'Aurore), pas un navire unique ;
# - le comptoir échange avec le CONVOI ACTIF (sa cale) ;
# - on fabrique un second convoi, on l'ordonne vers un port, il y arrive.
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

	# --- l'Aurore est un convoi dès le départ -------------------------------
	var cj = b.get("convois_joueur").invoke()
	print("convois au départ     : ", cj.size(), " -> ", cj[0] if cj.size() > 0 else "aucun")
	if cj.size() != 1:
		printerr("  ECHEC : le joueur devrait démarrer avec 1 convoi (l'Aurore)."); echecs += 1
	else:
		var a = cj[0] as Dictionary
		if String(a.get("nom", "")) != "Aurore" or String(a.get("mode", "")) != "manuel":
			printerr("  ECHEC : le 1er convoi devrait être l'Aurore, manuel."); echecs += 1
	var etat = b.get("etat_compagnie").invoke()
	print("etat_compagnie        : navire=", etat.get("navire"), " capacité=", etat.get("capacite"))
	if String(etat.get("navire", "")) != "Aurore" or int(etat.get("capacite", 0)) != 200:
		printerr("  ECHEC : la fiche devrait montrer l'Aurore (200 t)."); echecs += 1

	# --- le comptoir échange avec le convoi actif (l'Aurore) ----------------
	var port_aurore := String((b.get("convois_joueur").invoke()[0] as Dictionary).get("ville", ""))
	var marche = b.get("marche").invokev([port_aurore, 10])
	var bien := ""
	for l in marche:
		if int(l.get("stock", 0)) > 20:
			bien = String(l["cle"]); break
	if bien != "":
		var achat = b.get("acheter").invokev([port_aurore, bien, 10])
		var e2 = b.get("etat_compagnie").invoke()
		print("achat ", bien, " x10       : ", achat, " -> cale ", e2.get("charge"), " cargaison=", e2.get("cargaison"))
		if int(e2.get("charge", 0)) <= 0:
			printerr("  ECHEC : l'achat n'a pas rempli la cale du convoi actif."); echecs += 1
	else:
		print("  (aucun bien en stock à ", port_aurore, " — achat non testé)")

	# --- fabriquer un 2e convoi et l'ordonner -------------------------------
	var ports = b.get("ports").invoke()
	var chantier := ""
	for p in ports:
		if int(p.get("niveau_chantier", 0)) >= 2:
			chantier = String(p["cle"]); break
	b.get("acheter_navire").invokev([chantier, "sloop"])
	b.get("acheter_navire").invokev([chantier, "sloop"])
	# les indices de flotte 1 et 2 sont les deux sloops achetés
	var rc = b.get("creer_convoi").invokev([[1, 2], chantier])
	print("creer 2e convoi       : ", rc)
	var cj2 = b.get("convois_joueur").invoke()
	if cj2.size() != 2:
		printerr("  ECHEC : il devrait y avoir 2 convois."); echecs += 1
	var arrivee := ""
	for p in ports:
		if String(p["cle"]) != chantier:
			arrivee = String(p["cle"]); break
	b.get("ordonner_convoi").invokev([2, arrivee])
	for j in 300:
		b.get("avancer_temps").invokev([24.0])
	var conv2 = b.get("convois_joueur").invoke()[1] as Dictionary
	print("2e convoi après 300 j : a_quai=", conv2.get("a_quai"), " ville=", conv2.get("ville"))
	if String(conv2.get("ville", "")) != arrivee:
		printerr("  ECHEC : le 2e convoi n'est pas arrivé à ", arrivee, "."); echecs += 1

	# --- mettre le 2e convoi en route de commerce, puis la retirer ----------
	var circuit = [chantier, arrivee]
	var rm = b.get("mettre_en_route").invokev([2, circuit, "resources", 5000])
	var m2 = b.get("convois_joueur").invoke()[1] as Dictionary
	print("mettre en route conv2 : ", rm, " ; mode=", m2.get("mode"))
	if not bool(rm.get("ok", false)) or String(m2.get("mode", "")) != "route":
		printerr("  ECHEC : le convoi n'est pas passé en route."); echecs += 1
	var rt = b.get("retirer_route").invokev([2])
	var m2b = b.get("convois_joueur").invoke()[1] as Dictionary
	print("retirer route conv2   : ", rt, " ; mode=", m2b.get("mode"))
	if not bool(rt.get("ok", false)) or String(m2b.get("mode", "")) != "manuel":
		printerr("  ECHEC : le convoi n'est pas redevenu manuel."); echecs += 1

	# --- envoyer l'Aurore vers un POINT DE MER (pas un port) ----------------
	var cible = ports[5]["rade"]     # un mouillage = un point de mer navigable
	var rp = b.get("ordonner_convoi_position").invokev([1, cible.x, cible.z])
	var ap = b.get("convois_joueur").invoke()[0] as Dictionary
	print("Aurore -> point de mer : ", rp, " ; a_quai=", ap.get("a_quai"))
	if not bool(rp.get("ok", false)) or bool(ap.get("a_quai", false)):
		printerr("  ECHEC : l'ordre vers un point de mer n'a pas fait appareiller l'Aurore."); echecs += 1

	if echecs > 0:
		printerr("ECHEC : ", echecs, " en défaut."); quit(1); return
	print("OK : Aurore = convoi, comptoir sur le convoi actif, 2e convoi commandé.")
	quit(0)
