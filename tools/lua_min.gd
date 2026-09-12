extends SceneTree

func _init() -> void:
	print("--- debut ---")
	print("LuaState existe : ", ClassDB.class_exists("LuaState"))
	if ClassDB.class_exists("LuaState"):
		var lua = ClassDB.instantiate("LuaState")
		print("instance : ", lua)
		lua.open_libraries()
		print("libs ouvertes")
		print("do_string : ", lua.do_string("return 1+1"))
	print("--- fin ---")
	quit(0)
