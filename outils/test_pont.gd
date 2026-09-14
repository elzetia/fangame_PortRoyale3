# Verifie au runtime que le PONT vers la simulation Lua repond, et que les fiches
# qu'il renvoie portent les champs que les ecrans affichent.
#
# `outils/test_ecran.gd` prouve que les ecrans se BATISSENT ; il ne touche jamais
# a la sim. Celui-ci prouve qu'ils peuvent se REMPLIR — la difference entre un
# squelette aux bonnes coordonnees et un ecran de Port Royale 3.
#
# Lance : godot --headless --path . --script outils/test_pont.gd
extends SceneTree

# Ce que le chantier affiche dans sa grille, et qui doit donc exister sur chaque
# fiche de navire. `tirant` est le dernier venu : c'est `Gauge`, une classe 0/1/2.
const CHAMPS_NAVIRE := ["cle", "nom", "cale", "coque", "canons", "equipage",
		"tirant", "maniabilite", "vmax", "vmin", "construction", "modele"]

var _ecarts := 0


func _rater(quoi: String) -> void:
	_ecarts += 1
	print("  ECART  ", quoi)


func _init() -> void:
	var sim := Sim.new()
	print("pont Lua pret : ", sim.pret)
	if not sim.pret:
		print("  erreur : ", sim.erreur)
		quit(1)
		return

	# --- geographie ----------------------------------------------------------
	var ports: Array = sim.ports()
	print("ports : ", ports.size())
	if ports.is_empty():
		_rater("aucun port : la sim ne repond pas")
		quit(1)
		return
	var p0: Dictionary = ports[0]
	print("  premier port : ", p0.get("nom", "?"), "  cle ", p0.get("cle", "?"),
			"  region ", p0.get("region", "<absente>"))
	if not p0.has("region") or p0.get("region") == null:
		_rater("le port n'a pas de region (champ nil ou absent)")

	# --- navires : les champs que le chantier affiche -------------------------
	var navires: Array = sim.navires_marchands()
	print("navires marchands : ", navires.size())
	var sans_tirant := 0
	for n in navires:
		var f: Dictionary = n
		for c in CHAMPS_NAVIRE:
			if not f.has(c):
				_rater("navire %s : champ manquant %s" % [f.get("cle", "?"), c])
		if not f.has("tirant"):
			sans_tirant += 1
	print("  navires sans tirant : ", sans_tirant)
	for n in navires:
		var f: Dictionary = n
		if str(f.get("modele", "")) == "sloop":
			print("  sloop : cale %s  coque %s  canons %s  equipage %s  tirant %s" % [
					f.get("cale"), f.get("coque"), f.get("canons"),
					f.get("equipage"), f.get("tirant")])
			# Valeurs relevees dans constdata.dat, verifiees en memoire du jeu.
			if int(f.get("canons", 0)) != 14: _rater("sloop : canons != 14")
			if int(f.get("equipage", 0)) != 70: _rater("sloop : equipage != 70")
			if int(f.get("tirant", -1)) != 0: _rater("sloop : tirant != 0")

	# --- chantier : la fiche que l'ecran consomme ----------------------------
	if not navires.is_empty():
		var cle := str((navires[0] as Dictionary).get("cle", ""))
		var fiche: Dictionary = sim.chantier_infos(cle)
		print("chantier_infos(%s) : %d champs" % [cle, fiche.size()])
		if fiche.is_empty():
			_rater("chantier_infos ne renvoie rien")
		else:
			print("  cles : ", ", ".join(PackedStringArray(fiche.keys())))

	# --- convois : ce que la MINIMAP consomme --------------------------------
	# Ce test ne regardait aucun convoi. Or la minimap en dessine les pastilles
	# et trace la route du convoi choisi : un champ manquant s'y verrait par une
	# carte vide, sans que rien ne le dise.
	var convois: Array = sim.convois_joueur()
	print("convois du joueur : ", convois.size())
	if convois.is_empty():
		_rater("aucun convoi : la minimap n'aurait rien a tracer")
	else:
		var c0: Dictionary = convois[0]
		# Les quatre premiers servent a la MINIMAP ; les suivants a la VIGNETTE
		# de convoi. Sans eux la vignette resterait muette, et le test qui la
		# couvre ne le verrait pas : il lui passe un dictionnaire fabrique a la
		# main, pas la sortie du pont.
		for champ in ["position", "a_quai", "selectionne", "route",
				"capacite", "charge", "canons", "equipage", "noeuds",
				"strategie", "villes", "lots",
				# L'onglet « bourse » de la vignette : la ROTATION mesuree --
				# duree d'un tour de circuit, gain net du dernier tour boucle,
				# et si la route tourne.
				"rotations", "rotation_jours", "rotation_gain", "route_active"]:
			if not c0.has(champ):
				_rater("convoi : champ manquant %s" % champ)
		# `lots` nourrit la GRILLE de l'onglet « tonneau ». Le test de la
		# vignette lui passe un tableau fabrique a la main : sans l'exigence
		# ici, le pont pourrait n'en produire aucun sans que rien ne le dise.
		# Chaque lot porte un RANG, qui choisit l'icone du jeu (`82 + rang`) --
		# hors de 0..19 la case afficherait l'image d'autre chose.
		var lots: Array = c0.get("lots", [])
		var somme := 0
		for l in lots:
			var lot: Dictionary = l
			for k in ["cle", "nom", "rang", "quantite"]:
				if not lot.has(k):
					_rater("lot : champ manquant %s" % k)
			var r := int(lot.get("rang", -1))
			if r < 0 or r > 19:
				_rater("lot %s : rang %d hors de 0..19" % [lot.get("cle"), r])
			somme += int(lot.get("quantite", 0))
		print("  cargaison : %d lot(s), %d tonneaux" % [lots.size(), somme])
		# La somme des lots EST la charge : deux chemins vers le meme nombre,
		# donc une incoherence se verrait ici et nulle part ailleurs.
		if somme != int(c0.get("charge", -1)):
			_rater("la somme des lots (%d) ne fait pas la charge (%s)"
					% [somme, c0.get("charge")])
		# Et les valeurs doivent avoir un SENS : un convoi qui porte des navires
		# a forcement une cale, des canons, un equipage et une allure. Un champ
		# present mais a zero serait un agregat qui ne somme rien.
		print("  agregats : cale %s/%s  canons %s  equipage %s  noeuds %s  strategie « %s »  villes %s"
				% [c0.get("charge"), c0.get("capacite"), c0.get("canons"),
					c0.get("equipage"), c0.get("noeuds"), c0.get("strategie"),
					c0.get("villes")])
		if int(c0.get("navires", 0)) > 0:
			for champ in ["capacite", "canons", "equipage", "noeuds"]:
				if int(c0.get(champ, 0)) <= 0:
					_rater("convoi : %s vaut %s alors qu'il a %s navire(s)"
							% [champ, c0.get(champ), c0.get("navires")])
		if int(c0.get("charge", -1)) < 0:
			_rater("convoi : charge negative")
		if int(c0.get("charge", 0)) > int(c0.get("capacite", 0)):
			_rater("convoi : charge %s au-dela de la cale %s"
					% [c0.get("charge"), c0.get("capacite")])
		var trace: Array = c0.get("route", [])
		print("  premier convoi : %s  a_quai %s  %d point(s) de route" % [
				c0.get("nom", "?"), c0.get("a_quai"), trace.size()])
		# Un convoi EN MER doit avoir une route ; a quai, `accoster` la vide.
		for c in convois:
			var f: Dictionary = c
			var r: Array = f.get("route", [])
			if not bool(f.get("a_quai", false)) and r.is_empty():
				_rater("convoi %s : en mer mais sans route" % f.get("nom", "?"))

	# --- ce que le joueur a decouvert -----------------------------------------
	#
	# CE BLOC EXISTE PARCE QUE RIEN D'AUTRE NE PEUT L'ATTRAPER. `test_compilation`
	# ne compile que du GDScript : un `require` circulaire cote Lua, ou une
	# fonction de pont qui rendrait autre chose que ce qu'on attend, lui echappent
	# entierement.
	#
	# CHEZ PR3 LA CARTE MONTRE TOUT LE MONDE ; ce sont les VILLES qui manquent tant
	# qu'on ne les a pas approchees (`ID_PLAYER_TIPP_A00_TEXT`). On verifie donc un
	# compteur d'entites, pas une surface.
	var decouvertes := sim.villes_decouvertes()
	print("villes decouvertes : %d / %d" % [decouvertes, ports.size()])
	if decouvertes < 0 or decouvertes > ports.size():
		_rater("villes decouvertes : %d hors de 0..%d" % [decouvertes, ports.size()])
	# AU DEPART, AUCUNE N'EST DECOUVERTE : le convoi de depart est a quai et n'a
	# pas encore ete pilote. Si la carte etait deja ouverte ici, c'est que la
	# decouverte se ferait ailleurs qu'a l'approche, et elle ne voudrait rien dire.
	if decouvertes != 0:
		_rater("villes decouvertes : %d au demarrage, 0 attendu" % decouvertes)
	# Et le premier port ne doit pas l'etre non plus.
	var cle0 := String((ports[0] as Dictionary).get("cle", ""))
	if sim.ville_decouverte(cle0):
		_rater("%s est decouverte avant d'avoir ete approchee" % cle0)
	# Aucun oeil pose tant qu'aucun convoi n'a navigue : rien n'est en vue.
	if sim.en_vue(0.0, 0.0):
		_rater("un point est « en vue » alors qu'aucun convoi n'a navigue")
	print("  version %d, rien en vue au demarrage : ok" % sim.exploration_version())

	# --- compagnie : ce que la PLANCHE DROITE consomme -----------------------
	# Rien n'exercait `etat_compagnie`. Or la planche droite y prend l'or ET le
	# RANG : un champ absent cote Lua ne se verrait que par un HUD muet, sans
	# qu'aucun compteur ne bronche.
	var compagnie: Dictionary = sim.etat_compagnie()
	print("etat_compagnie : %d champs" % compagnie.size())
	for champ in ["or_", "rang", "capacite", "charge"]:
		if not compagnie.has(champ):
			_rater("compagnie : champ manquant %s" % champ)
	var rang := int(compagnie.get("rang", -1))
	print("  or %s  rang %d" % [compagnie.get("or_", "?"), rang])
	# PR3 demarre a l'echelon 0 (« Mousse ») — une sauvegarde reelle du jeu le
	# confirme. Hors de 0..17, le HUD afficherait un echelon qui n'existe pas.
	if rang < 0 or rang > 17:
		_rater("compagnie : rang %d hors de l'echelle 0..17" % rang)

	# --- ville : ce que l'info-ville consomme --------------------------------
	var etat: Dictionary = sim.etat_ville(str(p0.get("cle", "")))
	print("etat_ville(%s) : %d champs" % [p0.get("cle", "?"), etat.size()])
	if etat.is_empty():
		_rater("etat_ville ne renvoie rien")
	else:
		print("  cles : ", ", ".join(PackedStringArray(etat.keys())))

	# --- etats des villes : ce que la CARTE DU MONDE consomme -----------------
	#
	# La carte dessine sous chaque nom de port les fleaux du jeu, avec les icones
	# de PR3. Elle lit `etats_villes` par paquet, une fois toutes les 1,5 s.
	#
	# CE QUE SEUL CE TEST PEUT ATTRAPER : le VOCABULAIRE. La carte ne dessine une
	# icone que pour « peste », « sauterelles » et « feu » ; si la sim renommait un
	# fleau, la carte n'afficherait plus rien -- en silence, et seulement les jours
	# ou un fleau frappe, donc invisible a la relecture comme au test de compilation.
	const FLEAUX_CONNUS := ["", "peste", "sauterelles", "feu"]
	var etats: Dictionary = sim.etats_villes()
	print("etats_villes : %d ville(s) sur %d port(s)" % [etats.size(), ports.size()])
	if etats.size() != ports.size():
		_rater("etats_villes rend %d fiches pour %d ports" % [etats.size(), ports.size()])
	var avec_fleau := 0
	var affames := 0
	for cle in etats:
		var e: Dictionary = etats[cle]
		for champ in ["fleau", "jours_fleau", "niveau", "tendance", "faim", "knapp"]:
			if not e.has(champ):
				_rater("etat de %s : champ manquant %s" % [cle, champ])
		var f := String(e.get("fleau", ""))
		if not FLEAUX_CONNUS.has(f):
			_rater("%s : fleau « %s » inconnu de la carte" % [cle, f])
		if f != "":
			avec_fleau += 1
			# Un fleau en cours dure forcement encore un jour au moins : la sim le
			# retire des que son compteur tombe a zero.
			if int(e.get("jours_fleau", 0)) <= 0:
				_rater("%s : fleau « %s » mais %s jour(s) restant(s)"
						% [cle, f, e.get("jours_fleau")])
		if int(e.get("faim", -3)) > 0:
			affames += 1
	print("  %d ville(s) sous un fleau, %d affamee(s) au demarrage" % [avec_fleau, affames])

	print()
	if _ecarts > 0:
		print(_ecarts, " ecart(s).")
		quit(1)
		return
	print("Le pont repond et les fiches sont completes.")
	quit(0)
