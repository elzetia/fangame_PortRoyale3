# Les états que la CARTE DU MONDE affiche sous le nom des villes : existent-ils
# vraiment, et la carte sait-elle les dessiner ?
#
# POURQUOI CE TEST À PART. `test_pont.gd` vérifie que `etats_villes` rend bien
# soixante fiches complètes — mais au démarrage AUCUNE ville n'a de fléau. Son
# contrôle du vocabulaire ne s'exécute donc jamais : il passe en ne prouvant rien,
# et l'affichage pourrait n'avoir jamais rien dessiné de sa vie sans qu'on le voie.
#
# La règle acquise sur ce projet : UN CONTRÔLE DOIT FAIRE SES PREUVES SUR UN CAS
# POSITIF AVANT QU'UN NÉGATIF NE COMPTE. On fait donc courir le calendrier jusqu'à
# ce que des fléaux tombent, et c'est LÀ qu'on regarde.
#
# Et rien n'est laissé au hasard : la simulation tire ses fléaux sur une graine
# déterministe (`graine_fleau + jour_no`), donc le même nombre de jours donne
# toujours les mêmes malheurs. Ce test ne peut pas devenir capricieux.
#
# Lance : godot --headless --path . --script outils/test_etats_villes.gd
extends SceneTree

# Le vocabulaire que la carte sait dessiner (ICONES_ETAT dans scripts/carte2d.gd).
# Si la simulation renommait un fléau, la carte n'afficherait plus rien — en
# silence, et seulement les jours où un fléau frappe.
const FLEAUX_CARTE := ["peste", "sauterelles", "feu"]

# Les icônes du jeu que la carte réclame, par leur identité relevée dans
# `reference_pr3/ui/agencement/icones.txt`.
const ICONES := {
	"peste": "skinlib_pr3/1743",       # Visual_IconButton_Plague
	"feu": "skinlib_pr3/1838",         # Visual_IconButton_Fire
	"sauterelles": "skinlib_pr3/1456", # Visual_IconButton_Events (générique assumé)
	"famine": "skinlib_pr3/1917",      # Visual_IconButton_Attention_Red (générique assumé)
}

const PAS_SECONDE := 1.0     # `avancer_temps` prend des secondes de jeu
const SECONDES_JOUR := 12.0  # Calendrier.SECONDES_JOUR à la vitesse ×1
const JOURS := 600           # assez pour que les fléaux tombent et se retirent

var _ecarts := 0


func _rater(quoi: String) -> void:
	_ecarts += 1
	print("  ÉCART  ", quoi)


func _init() -> void:
	var sim := Sim.new()
	if not sim.pret:
		print("ARRÊT : le pont Lua ne démarre pas — ", sim.erreur)
		quit(1)
		return

	print("=== 1. AU DÉMARRAGE ===")
	var depart: Dictionary = sim.etats_villes()
	print("  %d villes, %d sous un fléau" % [depart.size(), _compter_fleaux(depart)])

	print("")
	print("=== 2. ON FAIT COURIR %d JOURS ===" % JOURS)
	# On relève les fléaux AU PASSAGE : un fléau dure 30 jours puis se retire, donc
	# ne regarder qu'à l'arrivée en manquerait la plupart.
	var vus := {}          # type de fléau -> nombre de villes touchées
	var jours_max := 0
	var villes_affamees := {}
	var pas := int(JOURS * SECONDES_JOUR / PAS_SECONDE)
	var releve := int(SECONDES_JOUR / PAS_SECONDE) * 5   # un relevé tous les 5 jours
	for i in pas:
		sim.avancer_temps(PAS_SECONDE)
		if i % releve != 0:
			continue
		var etats: Dictionary = sim.etats_villes()
		for cle in etats:
			var e: Dictionary = etats[cle]
			var f := String(e.get("fleau", ""))
			if f != "":
				vus[f] = int(vus.get(f, 0)) + 1
				jours_max = maxi(jours_max, int(e.get("jours_fleau", 0)))
				if not FLEAUX_CARTE.has(f):
					_rater("%s : fléau « %s » — la carte ne sait pas le dessiner" % [cle, f])
				if int(e.get("jours_fleau", 0)) <= 0:
					_rater("%s : fléau « %s » mais 0 jour restant" % [cle, f])
			if int(e.get("faim", -3)) > 0:
				villes_affamees[cle] = true

	print("  fléaux rencontrés : ", vus if not vus.is_empty() else "AUCUN")
	print("  villes passées par la famine : %d" % villes_affamees.size())

	# LE POINT DE TOUT LE TEST. Sans un seul fléau observé, rien au-dessus n'a
	# tourné : on aurait un affichage que rien n'a jamais exercé.
	if vus.is_empty():
		_rater("aucun fléau en %d jours — l'affichage de la carte n'a jamais été exercé"
				% JOURS)
	else:
		# Un fléau dure 30 jours dans la simulation : au-delà, le décompte fuit.
		if jours_max > 30:
			_rater("un fléau annonce %d jours restants, 30 au maximum" % jours_max)
		# LE GARDE-FOU QUI MANQUAIT À MA PREMIÈRE VERSION. Elle se contentait de
		# « des fléaux tombent » — et ils tombaient : tous des pestes, parce que le
		# tirage du TYPE était collé à celui de la porte (générateur linéaire,
		# graines voisines). Deux tiers des icônes de la carte ne pouvaient donc
		# jamais s'afficher, et le test passait au vert sans rien dire.
		if vus.size() < 2:
			_rater("un seul type de fléau en %d jours (%s) : le tirage du type est corrélé à celui de la porte"
					% [JOURS, ", ".join(PackedStringArray(vus.keys()))])

	print("")
	print("=== 3. LES ICÔNES DU JEU ===")
	# L'art est sous droits et vit dans `reference_pr3/`, ignoré par git. Son
	# absence n'est PAS une faute : la carte retombe sur ses pastilles de couleur.
	# On dit seulement ce qui est là, pour que le repli ne passe pas inaperçu.
	var manquantes := 0
	for etat in ICONES:
		var cle := String(ICONES[etat])
		if SkinPR3.texture(cle) == null:
			manquantes += 1
			print("  %-12s %s  absente → pastille dessinée" % [etat, cle])
		else:
			print("  %-12s %s  chargée" % [etat, cle])
	if manquantes == ICONES.size():
		print("  (aucun art PR3 sur ce poste — la carte reste lisible en repli)")

	print("")
	if _ecarts == 0:
		print("=== LA CARTE SAIT AFFICHER LES ÉTATS DES VILLES. ===")
	else:
		print("=== %d ÉCART(S). ===" % _ecarts)
	quit(0 if _ecarts == 0 else 1)


func _compter_fleaux(etats: Dictionary) -> int:
	var n := 0
	for cle in etats:
		if String((etats[cle] as Dictionary).get("fleau", "")) != "":
			n += 1
	return n
