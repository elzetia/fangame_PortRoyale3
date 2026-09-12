# Sonde l'API réelle de LuaTable / LuaFunction plutôt que de la deviner.
extends SceneTree


func _init() -> void:
	var lua = ClassDB.instantiate("LuaState")
	lua.open_libraries()

	var t = lua.do_string("return { n = 7, f = function(a, b) return a + b end }")
	print("table    : ", t, "  classe=", t.get_class())
	print("  t['n'] : ", t.get("n") if t.has_method("get") else "(pas de get)")

	print("  methodes LuaTable :")
	for m in t.get_method_list():
		print("    ", m["name"])

	var f = lua.do_string("return function(a, b) return a * b end")
	print("fonction : ", f, "  classe=", f.get_class())
	print("  methodes LuaFunction :")
	for m in f.get_method_list():
		print("    ", m["name"])

	quit(0)
