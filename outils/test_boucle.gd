# Joue une PARTIE, en entier, pour savoir si la boucle de jeu tient debout.
#
# POURQUOI CE TEST EXISTE. Les autres prouvent que les écrans se BÂTISSENT
# (`test_ecran.gd`) et que le pont RÉPOND (`test_pont.gd`). Aucun ne prouve qu'on
# peut JOUER. C'est pourtant la seule question qui compte : le but du projet est
# un Port Royale jouable et modifiable, pas une belle documentation de son
# exécutable.
#
# Ce script fait donc ce qu'un joueur fait dans ses cinq premières minutes :
#
#   1. il regarde où est son convoi et ce qu'il a en caisse ;
#   2. il lit le marché du port où il se trouve ;
#   3. il achète ce qui paraît le plus rentable ;
#   4. il appareille vers une ville voisine ;
#   5. il laisse filer les jours jusqu'à l'arrivée ;
#   6. il revend, et compte.
#
# Le verdict n'est pas « ça n'a pas planté » mais : EST-CE QUE ÇA RAPPORTE, et en
# combien de jours. Une boucle qui tourne mais ne rapporte rien n'est pas un jeu.
#
# Lance : godot --headless --path . --script res://outils/test_boucle.gd
extends SceneTree

const JOURS_MAX := 120          # au-delà, on considère que le convoi n'arrive pas

# PIÈGE : `avancer_temps` prend des SECONDES DE JEU, pas des jours, et rend les
# HEURES écoulées. Un jour de jeu dure douze secondes à vitesse ×1. Compter les
# appels comme des jours donnait « 100,5 jours » pour une traversée qui en prend
# huit et demi — et faisait croire à un jeu figé. On accumule donc les heures que
# la simulation rend, sans supposer la cadence.
const PAS_SECONDE := 0.5


func _dire(s: String) -> void:
	print(s)


func _cle(d: Dictionary, noms: Array, defaut = null):
	# Les fiches du pont n'ont pas toutes les mêmes noms de champs selon les
	# versions ; on essaie plusieurs clés plutôt que de planter sur une absence.
	for n in noms:
		if d.has(n) and d[n] != null:
			return d[n]
	return defaut


func _init() -> void:
	var sim := Sim.new()
	if not sim.pret:
		_dire("ARRÊT : le pont Lua ne démarre pas — " + str(sim.erreur))
		quit(1)
		return

	_dire("=== 1. LA SITUATION DE DÉPART ===")
	var compagnie: Dictionary = sim.etat_compagnie()
	var or_depart: float = float(_cle(compagnie, ["or", "or_", "gold"], 0.0))
	_dire("   or en caisse : %d" % int(or_depart))

	var convois: Array = sim.convois_joueur()
	if convois.is_empty():
		_dire("   ÉCHEC : le joueur n'a aucun convoi. Sans navire, pas de jeu.")
		quit(1)
		return
	var c: Dictionary = convois[0]
	_dire("   convoi : %s" % str(_cle(c, ["nom"], "?")))
	_dire("   champs disponibles : %s" % str(c.keys()))
	var port_cle := str(_cle(c, ["ville", "port", "attache"], ""))
	var cale := float(_cle(c, ["capacite", "cale"], 0.0))
	_dire("   à quai à : %s   cale : %d tonneaux" % [port_cle, int(cale)])
	if port_cle == "":
		_dire("   ÉCHEC : le convoi n'est à aucun port au départ.")
		quit(1)
		return

	_dire("")
	_dire("=== 2. LE MARCHÉ DE CE PORT ===")
	var lignes: Array = sim.marche(port_cle, 1)
	if lignes.is_empty():
		_dire("   ÉCHEC : le marché est vide.")
		quit(1)
		return
	_dire("   %d marchandises cotées ; champs : %s"
			% [lignes.size(), str((lignes[0] as Dictionary).keys())])

	# On cherche la meilleure MARGE, pas le prix le plus bas.
	#
	# La première version prenait la marchandise la moins chère : c'est le pire
	# réflexe possible. Elle achetait du blé — une denrée de base, abondante
	# partout, donc sans écart entre les ports — et le voyage ne payait pas
	# l'équipage. Un joueur compare ce qu'il paie ici à ce qu'on lui en donnera
	# ailleurs ; c'est cette décision-là qu'il faut simuler.
	var ports_tous: Array = sim.ports()
	var meilleur: Dictionary = {}
	var meilleure_marge := 0.0
	for l in lignes:
		var d: Dictionary = l
		var cle := str(_cle(d, ["cle", "marchandise"], ""))
		if cle == "":
			continue
		var achat := float(sim.cotation(port_cle, cle, 100, "achat"))
		if achat <= 0.0:
			continue
		for p in ports_tous:
			var pd: Dictionary = p
			var k := str(_cle(pd, ["cle"], ""))
			if k == "" or k == port_cle:
				continue
			var vente := float(sim.cotation(k, cle, 100, "vente"))
			var marge := vente - achat
			if marge > meilleure_marge:
				meilleure_marge = marge
				meilleur = {
					"cle": cle, "nom": str(_cle(d, ["nom"], cle)), "achat": achat,
					"vers": k, "vers_nom": str(_cle(pd, ["nom"], k)), "vente": vente,
				}
	if meilleur.is_empty():
		_dire("   ÉCHEC : aucune marchandise ne se revend plus cher ailleurs.")
		_dire("   -> c'est un défaut d'équilibrage : sans écart entre les ports,")
		_dire("      il n'y a pas de commerce, donc pas de jeu.")
		quit(1)
		return
	_dire("   meilleure marge : %s, acheté %.1f ici, vendu %.1f à %s (+%.1f/t)"
			% [meilleur["nom"], meilleur["achat"], meilleur["vente"],
			   meilleur["vers_nom"], meilleure_marge])

	_dire("")
	_dire("=== 3. ON ACHÈTE ===")
	var prix_achat := float(meilleur["achat"])
	var lot := int(min(cale, floor(or_depart / max(prix_achat, 1.0))))
	lot = int(min(lot, 100))
	if lot <= 0:
		_dire("   ÉCHEC : pas les moyens d'acheter un seul tonneau.")
		quit(1)
		return
	var achat_res: Dictionary = sim.acheter(port_cle, str(meilleur["cle"]), lot)
	_dire("   demandé %d t de %s -> %s" % [lot, meilleur["nom"], str(achat_res)])
	var or_apres_achat: float = float(_cle(sim.etat_compagnie(), ["or", "or_", "gold"], 0.0))
	_dire("   or après achat : %d  (dépensé %d)"
			% [int(or_apres_achat), int(or_depart - or_apres_achat)])
	if or_apres_achat >= or_depart:
		_dire("   ANOMALIE : l'achat n'a rien coûté.")

	_dire("")
	_dire("=== 4. OÙ VENDRE ? ===")
	# La destination est déjà choisie : c'est elle qui a DÉFINI l'achat, puisqu'on
	# sélectionne la marchandise au meilleur écart entre ici et ailleurs. La
	# rechercher une seconde fois serait non seulement redondant mais faux — le
	# prix d'achat a bougé depuis, l'écart aussi.
	var cible := str(meilleur["vers"])
	var cible_nom := str(meilleur["vers_nom"])
	var meilleure_vente := float(meilleur["vente"])
	_dire("   %s paie %.1f la tonne (contre %.1f à l'achat)"
			% [cible_nom, meilleure_vente, prix_achat])
	_dire("   marge théorique sur le lot : %d" % int((meilleure_vente - prix_achat) * lot))

	_dire("")
	_dire("=== 5. ON APPAREILLE ===")
	# PIÈGE : les convois sont numérotés À PARTIR DE 1 — la simulation est en Lua,
	# où les tableaux commencent à 1, et l'interface démarre elle aussi à 1. Passer
	# la position dans le tableau (0) rend « Convoi inconnu. » et fait croire à tort
	# que la navigation est cassée. On lit donc le champ `indice` de la fiche.
	var indice := int(_cle(c, ["indice"], 1))
	var ordre: Dictionary = sim.ordonner_convoi(indice, cible)
	_dire("   ordre -> %s" % str(ordre))

	var heures := 0.0
	var arrive := false
	while heures < JOURS_MAX * 24.0:
		# On accumule ce que la simulation REND (des heures), au lieu de supposer
		# que le pas d'entrée est une journée.
		heures += float(sim.avancer_temps(PAS_SECONDE))
		var cc: Array = sim.convois_joueur()
		if cc.is_empty():
			break
		var etat: Dictionary = cc[0]
		if str(_cle(etat, ["ville", "port"], "")) == cible:
			arrive = true
			break
	if not arrive:
		_dire("   ÉCHEC : le convoi n'est pas arrivé en %d jours." % int(JOURS_MAX))
		_dire("   -> la navigation ou l'ordre de route ne fonctionne pas.")
		quit(1)
		return
	var jours := heures / 24.0
	_dire("   arrivé à %s en %.1f jours" % [cible_nom, jours])

	_dire("")
	_dire("=== 6. ON REVEND ===")
	var vente_res: Dictionary = sim.vendre(cible, str(meilleur["cle"]), lot)
	_dire("   vendu -> %s" % str(vente_res))
	var or_final: float = float(_cle(sim.etat_compagnie(), ["or", "or_", "gold"], 0.0))
	var gain := or_final - or_depart

	_dire("")
	_dire("=== VERDICT ===")
	_dire("   or au départ : %d" % int(or_depart))
	_dire("   or à l'arrivée : %d" % int(or_final))
	_dire("   bénéfice : %d en %.1f jours" % [int(gain), jours])
	if gain > 0.0:
		_dire("   LA BOUCLE TIENT : acheter, naviguer, revendre rapporte.")
	else:
		_dire("   LA BOUCLE NE RAPPORTE PAS. Un joueur qui suit son instinct perd")
		_dire("   de l'argent : c'est un défaut d'équilibrage, pas un plantage.")
	quit(0)
