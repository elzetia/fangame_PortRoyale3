# Sauver, jouer, recharger : la partie revient-elle telle qu'on l'a laissée ?
#
# POURQUOI CE TEST. Sans sauvegarde, on ne peut ni quitter une partie ni juger une
# modification sur la durée — c'est le préalable à un Port Royale qu'on édite. Et
# une sauvegarde qui rend une partie SUBTILEMENT différente est pire que pas de
# sauvegarde du tout : on ne s'en aperçoit qu'après des heures.
#
# Le test ne vérifie donc pas « ça n'a pas planté » mais l'ALLER-RETOUR :
#
#   1. on relève l'or, la date et le stock d'une ville ;
#   2. on sauve ;
#   3. on JOUE — on achète, on laisse filer des jours ;
#   4. on vérifie que la partie a bel et bien changé (sans quoi l'étape 5 ne
#      prouverait rien) ;
#   5. on recharge, et l'on exige que les trois relevés soient revenus.
#
# Lance : godot --headless --path . --script res://outils/test_sauvegarde.gd
extends SceneTree

const VILLE_TEMOIN := "port_royale"
const PAS_SECONDE := 0.5      # `avancer_temps` prend des secondes de jeu
const PAS := 400              # assez pour changer de jour


var _ecarts := 0


func _rater(quoi: String) -> void:
	_ecarts += 1
	print("  ÉCART  ", quoi)


func _stock(sim: Sim, cle_m: String) -> int:
	for l in sim.marche(VILLE_TEMOIN, 1):
		var d: Dictionary = l
		if String(d.get("cle", "")) == cle_m:
			return int(d.get("stock", 0))
	return -1


func _init() -> void:
	var sim := Sim.new()
	if not sim.pret:
		print("ARRÊT : le pont Lua ne démarre pas — ", sim.erreur)
		quit(1)
		return

	print("=== 1. L'ÉTAT DE DÉPART ===")
	var or_avant := int(sim.etat_compagnie().get("or_", 0))
	var date_avant := String(sim.etat_temps().get("date", ""))
	# Une marchandise quelconque, mais toujours la même : on la prend au marché.
	var marche: Array = sim.marche(VILLE_TEMOIN, 1)
	if marche.is_empty():
		print("  ÉCHEC : marché vide, rien à comparer.")
		quit(1)
		return
	var cle_m := String((marche[0] as Dictionary).get("cle", ""))
	var stock_avant := _stock(sim, cle_m)
	print("  or %d   date « %s »   stock de %s à %s : %d"
			% [or_avant, date_avant, cle_m, VILLE_TEMOIN, stock_avant])

	print("")
	print("=== 2. ON SAUVE ===")
	var txt := sim.sauver_texte()
	if txt == "":
		print("  ÉCHEC : la simulation n'a rendu aucun texte.")
		quit(1)
		return
	print("  %d caractères de JSON" % txt.length())
	if not txt.contains("\"version\""):
		_rater("le texte ne porte pas de version — le format ne se protège pas")
	# On vérifie aussi que Godot sait le relire : si JSON.parse échoue ici, le
	# fichier ne serait pas modifiable à la main, ce qui est tout l'intérêt.
	var relu = JSON.parse_string(txt)
	if relu == null:
		_rater("Godot ne sait pas relire ce JSON — il n'est donc pas éditable")
	else:
		print("  Godot le relit : %d sections" % (relu as Dictionary).size())

	var res_f: Dictionary = sim.sauver("test_aller_retour")
	if not bool(res_f.get("ok", false)):
		_rater("écriture du fichier : " + String(res_f.get("message", "")))
	else:
		print("  écrit dans %s" % String(res_f.get("chemin", "")))

	print("")
	print("=== 3. ON JOUE ===")
	var achat: Dictionary = sim.acheter(VILLE_TEMOIN, cle_m, 30)
	print("  achat de 30 t de %s -> %s" % [cle_m, str(achat)])
	for i in PAS:
		sim.avancer_temps(PAS_SECONDE)
	var or_apres := int(sim.etat_compagnie().get("or_", 0))
	var date_apres := String(sim.etat_temps().get("date", ""))
	var stock_apres := _stock(sim, cle_m)
	print("  or %d   date « %s »   stock %d" % [or_apres, date_apres, stock_apres])

	# Sans changement réel, le rechargement ne prouverait rien.
	if or_apres == or_avant and date_apres == date_avant:
		print("  ÉCHEC : la partie n'a pas bougé, le test ne peut rien conclure.")
		quit(1)
		return

	print("")
	print("=== 4. ON RECHARGE ===")
	var res: Dictionary = sim.charger("test_aller_retour")
	print("  -> %s" % str(res))
	if not bool(res.get("ok", false)):
		print("  ÉCHEC : rechargement refusé.")
		quit(1)
		return

	var or_repris := int(sim.etat_compagnie().get("or_", 0))
	var date_reprise := String(sim.etat_temps().get("date", ""))
	var stock_repris := _stock(sim, cle_m)
	print("  or %d   date « %s »   stock %d" % [or_repris, date_reprise, stock_repris])

	if or_repris != or_avant:
		_rater("l'or n'est pas revenu : %d attendu, %d obtenu" % [or_avant, or_repris])
	if date_reprise != date_avant:
		_rater("la date n'est pas revenue : « %s » attendue, « %s » obtenue"
				% [date_avant, date_reprise])
	if stock_repris != stock_avant:
		_rater("le stock n'est pas revenu : %d attendu, %d obtenu"
				% [stock_avant, stock_repris])

	# Le convoi de départ doit être là, avec son nom et son port.
	var convois: Array = sim.convois_joueur()
	if convois.is_empty():
		_rater("plus aucun convoi après rechargement")
	else:
		var c: Dictionary = convois[0]
		print("  convoi repris : %s, à %s, cale %d"
				% [String(c.get("nom", "?")), String(c.get("ville", "?")),
				   int(c.get("capacite", 0))])
		if int(c.get("capacite", 0)) <= 0:
			_rater("le convoi a perdu sa capacité — les navires n'ont pas été reconstruits")

	print("")
	if _ecarts == 0:
		print("=== LA SAUVEGARDE TIENT : la partie revient telle qu'on l'a laissée. ===")
	else:
		print("=== %d ÉCART(S) : la sauvegarde ne restitue pas la partie. ===" % _ecarts)
	quit(0 if _ecarts == 0 else 1)
