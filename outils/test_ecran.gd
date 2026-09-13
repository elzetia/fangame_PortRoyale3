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
	quit()
