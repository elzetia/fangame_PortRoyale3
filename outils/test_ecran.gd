# Verifie au runtime que EcranPR3 lit l'agencement exporte, que la table de
# localisation repond, et que les deux ecrans se batissent.
# Lance : godot --headless --script res://outils/test_ecran.gd
extends SceneTree

func _init() -> void:
	print("loca disponible : ", LocaPR3.disponible())
	print("  onglet build  : ", LocaPR3.texte("ID_GUI_TAB_BUILD_TABBUTTONTEXT", "?"))
	print("  onglet info   : ", LocaPR3.texte("ID_GUI_TAB_TOWNINFO_TABBUTTONTEXT", "?"))
	print("  prosperite 07 : ", LocaPR3.texte("ID_GUI_TOWN_WEALTH_07", "?"))
	print("  batiment      : ", LocaPR3.texte("ID_GUI_BUILDING_SHIPYARD", "?"))
	var doc := EcranPR3.agencement("dialog_shipyard_pc")
	print("JSON charge : ", not doc.is_empty(), "  icones : ", EcranPR3.icones().size())
	for scene in ["exports.Tab_Shipyard_build", "exports.Tab_Shipyard_repair",
			"exports.Tab_Shipyard_buy", "exports.Tab_Shipyard_sell"]:
		var n := EcranPR3.batir("dialog_shipyard_pc", scene)
		var champs: Array = []
		for e in n.get_children():
			if e.name.begins_with("tf_"):
				champs.append(str(e.name))
		print("%s -> %d noeuds : %s" % [scene, n.get_child_count(), ", ".join(champs)])
	var t := EcranPR3.batir("dialog_trade", "exports.Tab_TownInfo")
	var tf: Array = []
	for e in t.get_children():
		if e.name.begins_with("tf_"):
			tf.append(str(e.name))
	print("Tab_TownInfo -> %d noeuds, %d champs" % [t.get_child_count(), tf.size()])
	print("  champs : ", ", ".join(tf))

	# La planche de gauche du HUD (hud_pc.swf). Attendu : 8 nœuds, dont QUATRE
	# portent une image — la planche de bois (639), les deux boutons d'allure
	# (453) et le bouton rond de la chronique (1037). Les trois autres sont la
	# plaque `Text_Bg_Nomal`, les deux champs, et `gr_scenario_info` qui reste
	# vide faute de table des caractères anonymes.
	# Avant le repli sur la table d'icônes, DEUX seulement portaient une image :
	# ni la planche ni le bouton rond ne tombaient dans une branche de `_noeud`.
	var h := EcranPR3.batir("hud_pc", "Hud_pc_fla.Hud_Woodboard_Left_PC_68", true)
	var avec_image := 0
	var nommes: Array = []
	for e in h.get_children():
		if e is TextureRect and (e as TextureRect).texture != null:
			avec_image += 1
		var n := str(e.name)
		if n.begins_with("tf_") or n.begins_with("bu_"):
			nommes.append(n)
	print("HUD planche gauche -> %d noeuds, %d avec image : %s"
		% [h.get_child_count(), avec_image, ", ".join(nommes)])
	quit()
