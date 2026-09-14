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

	# --- ville : ce que l'info-ville consomme --------------------------------
	var etat: Dictionary = sim.etat_ville(str(p0.get("cle", "")))
	print("etat_ville(%s) : %d champs" % [p0.get("cle", "?"), etat.size()])
	if etat.is_empty():
		_rater("etat_ville ne renvoie rien")
	else:
		print("  cles : ", ", ".join(PackedStringArray(etat.keys())))

	print()
	if _ecarts > 0:
		print(_ecarts, " ecart(s).")
		quit(1)
		return
	print("Le pont repond et les fiches sont completes.")
	quit(0)
