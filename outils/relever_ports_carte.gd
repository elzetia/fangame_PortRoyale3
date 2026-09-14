# Releve la position PIXEL de chaque port sur la grande carte cuite.
#
# L'utilisateur voit l'illustration « trop basse », les ports « plus haut ». La
# minimap, elle, a ete verifiee : ses soixante pastilles tombent sur le littoral
# de `hud_pc/12.png`. Le desaccord est donc sur la GRANDE carte, et il se mesure
# plutot qu'il ne se discute : on deverse les positions calculees, on les
# superpose a `carte_cuite.png`, et on regarde.
#
# On passe par exactement le meme chemin que le jeu -- `ProjectionCarte` chargee
# depuis la fiche de cuisson, `sim.ports()` pour les rades -- sans quoi on
# mesurerait autre chose que ce qui s'affiche.
#
# Lance : godot --headless --path . --script res://outils/relever_ports_carte.gd -- sortie.txt
extends SceneTree

const FICHE := "res://carte_cuite.json"


func _init() -> void:
	var proj := ProjectionCarte.new(FICHE)
	if not proj.valide:
		print("fiche illisible : ", proj.erreur)
		quit(1)
		return
	print("fiche : angle %.1f  centre (%.0f, %.0f)  vue %.0f x %.0f  pixels %d x %d"
		% [proj.angle, proj.centre.x, proj.centre.y,
			proj.vue_taille.x, proj.vue_taille.y, proj.pixels.x, proj.pixels.y])

	var sim := Sim.new()
	if not sim.pret:
		print("sim indisponible : ", sim.erreur)
		quit(1)
		return
	var ports: Array = sim.ports()
	print("ports : ", ports.size())

	var lignes := PackedStringArray()
	var xmin := INF
	var xmax := -INF
	var ymin := INF
	var ymax := -INF
	for p in ports:
		var d: Dictionary = p
		var rade: Vector3 = d["rade"]
		var pix := proj.vers_carte(rade.x, rade.z)
		xmin = minf(xmin, pix.x)
		xmax = maxf(xmax, pix.x)
		ymin = minf(ymin, pix.y)
		ymax = maxf(ymax, pix.y)
		lignes.append("%.2f %.2f %s" % [pix.x, pix.y, str(d.get("cle", "?"))])
	print("   x %.1f..%.1f   y %.1f..%.1f   (carte %d x %d)"
		% [xmin, xmax, ymin, ymax, proj.pixels.x, proj.pixels.y])
	# Une marge tres inegale en haut et en bas trahit un decalage vertical.
	print("   marge haute %.1f px, marge basse %.1f px"
		% [ymin, proj.pixels.y - ymax])

	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		var f := FileAccess.open(args[0], FileAccess.WRITE)
		if f != null:
			for l in lignes:
				f.store_line(l)
			f.close()
			print("   %d positions deposees dans %s" % [lignes.size(), args[0]])
		else:
			print("   impossible d'ecrire dans ", args[0])
	quit(0)
