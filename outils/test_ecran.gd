# Verifie au runtime que EcranPR3 lit bien l'agencement exporte et batit
# les noeuds. Lance : godot --headless --script res://outils/test_ecran.gd
extends SceneTree

func _init() -> void:
	var doc := EcranPR3.agencement("dialog_shipyard_pc")
	print("JSON charge : ", not doc.is_empty())
	if doc.is_empty():
		print("  (art PR3 absent -> rien a verifier)")
		quit(); return
	print("ecrans : ", (doc.get("ecrans", {}) as Dictionary).size())
	print("icones : ", EcranPR3.icones().size())
	for scene in ["exports.Tab_Shipyard_build", "exports.Tab_Shipyard_repair",
			"exports.Tab_Shipyard_buy", "exports.Tab_Shipyard_sell"]:
		var n := EcranPR3.batir("dialog_shipyard_pc", scene)
		var noms: Array = []
		for e in n.get_children():
			if e.name.begins_with("tf_"):
				noms.append(String(e.name))
		print("%s -> %d noeuds, champs: %s" % [scene, n.get_child_count(), ", ".join(noms)])
	var t := EcranPR3.batir("dialog_trade", "exports.Tab_TownInfo")
	print("Tab_TownInfo -> %d noeuds" % t.get_child_count())
	quit()
