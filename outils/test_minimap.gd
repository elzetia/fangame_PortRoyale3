# Quelle part du monde la minimap montre-t-elle ? Mesure, avant d'y dessiner
# soixante villes.
#
# La planche droite du HUD montre `char14` -> hud_pc/12.png, 196x156, posee en
# (-200,59). Pour y placer une ville il faut projeter sa position monde dans ce
# rectangle. On refuse d'ecrire une seconde projection : `ProjectionCarte`,
# celle de la grande carte, reste la seule source, sans quoi la minimap et la
# carte se contrediraient. On ne cherche que le CADRAGE de 12.png.
#
# CE QU'ON MESURE, ET POURQUOI PAS AUTRE CHOSE. Un premier test demandait « le
# port tombe-t-il sur une case de MER bordee de terre ? ». Il donnait 19 ports
# sur 60 poses en pleine terre, et aucun cadrage ne le corrigeait : l'ajustement
# tirait l'axe X a 1,14 pendant qu'il serrait l'axe Y a 0,90, signe qu'il
# compensait par la geometrie une difference qui n'en est pas une.
#
# Comparer les deux silhouettes cote a cote a montre l'erreur : les deux cartes
# montrent la MEME geographie et le meme cadrage, mais 12.png est une carte de
# PARCHEMIN, aux cotes generalisees et EPAISSIES. Un port est a sa rade, une
# case d'eau contre la cote ; sur une carte dont la terre est dessinee grasse,
# il tombe donc DANS la terre. Le test etait faux, pas la projection.
#
# On mesure donc la DISTANCE A LA COTE, des deux cotes du trait. Un port doit
# etre pres du littoral ; qu'il soit a un pixel dedans ou dehors ne dit rien.
#
# Lance : godot --headless --path . --script res://outils/test_minimap.gd
extends SceneTree

const FICHE := "res://carte_cuite.json"
const SEAMAP := "res://reference_pr3/ui/hud_pc/12.png"
const LOIN := 99            # distance sentinelle
# Les quatre voisins. En constantes nommées plutôt qu'en tableaux posés dans la
# boucle : indexer un tableau littéral rend un Variant, que `:=` ne sait pas
# typer.
const DX := [1, -1, 0, 0]
const DY := [0, 0, 1, -1]

var _img: Image
var _l := 0
var _h := 0
var _dist: PackedInt32Array  # distance au trait de cote, en pixels


func _init() -> void:
	var proj := ProjectionCarte.new(FICHE)
	print("fiche : ", proj.valide, "  pixels %s  angle %.0f" % [proj.pixels, proj.angle])
	var chemin := ProjectSettings.globalize_path(SEAMAP)
	if FileAccess.file_exists(chemin):
		_img = Image.load_from_file(chemin)
	if not proj.valide or _img == null:
		print("il manque de quoi mesurer.")
		quit(1)
		return
	_l = _img.get_width()
	_h = _img.get_height()
	print("carte des mers : %dx%d" % [_l, _h])

	var sim := Sim.new()
	if not sim.pret:
		print("pont Lua : ", sim.erreur)
		quit(1)
		return
	var ports: Array = sim.ports()
	print("ports : ", ports.size())

	_champ_de_distance()

	# La reference du hasard : a quelle distance du littoral est un point pris
	# au hasard ? Sans ce chiffre, « 50 ports a moins de 2 px » ne dit rien.
	var somme := 0
	var proches := 0
	for i in range(_l * _h):
		var d := _dist[i]
		somme += mini(d, 20)
		if d <= 2:
			proches += 1
	print("hasard : distance moyenne %.1f px, %.0f %% des points a <= 2 px"
		% [float(somme) / float(_l * _h), 100.0 * proches / float(_l * _h)])

	var uv: Array[Vector2] = []
	var noms: Array[String] = []
	for p in ports:
		var d: Dictionary = p
		var rade: Vector3 = d["rade"]
		var pix := proj.vers_carte(rade.x, rade.z)
		uv.append(Vector2(pix.x / float(proj.pixels.x), pix.y / float(proj.pixels.y)))
		noms.append(str(d.get("nom", "?")))

	print("\n=== SANS aucun ajustement ===")
	_rapport(uv, noms, 1.0, 0.0, 1.0, 0.0)

	# Un ajustement aiderait-il encore ? On minimise la distance totale.
	var best := [1.0, 0.0, 1.0, 0.0]
	var meilleur := _cout(uv, 1.0, 0.0, 1.0, 0.0)
	for passe in range(2):
		var pas := 0.04 if passe == 0 else 0.01
		var n := 6
		var b0: float = best[0]
		var b1: float = best[1]
		var b2: float = best[2]
		var b3: float = best[3]
		for i in range(-n, n + 1):
			for j in range(-n, n + 1):
				for a in range(-n, n + 1):
					for b in range(-n, n + 1):
						var ku := b0 + i * pas
						var du := b1 + j * pas * 0.5
						var kv := b2 + a * pas
						var dv := b3 + b * pas * 0.5
						if ku <= 0.5 or kv <= 0.5:
							continue
						var c := _cout(uv, ku, du, kv, dv)
						if c < meilleur:
							meilleur = c
							best = [ku, du, kv, dv]
	print("\n=== avec le MEILLEUR ajustement trouve ===")
	print("   u' = 0,5 + (u - 0,5) x %.3f %+.3f" % [float(best[0]), float(best[1])])
	print("   v' = 0,5 + (v - 0,5) x %.3f %+.3f" % [float(best[2]), float(best[3])])
	_rapport(uv, noms, float(best[0]), float(best[1]), float(best[2]), float(best[3]))

	# --- ce que pose REELLEMENT le code livre --------------------------------
	# Mesurer un cadrage ne prouve pas que la planche l'applique juste : une
	# constante mal recopiee, un repere local autre que celui qu'on croit, et
	# les soixante marqueurs tombent a cote sans que rien ne le signale --
	# `test_ecran` compte des noeuds, il ne regarde pas ou ils sont. On batit
	# donc la VRAIE planche et on relit ce qu'elle a pose.
	var planche := HudDroitePR3.new()
	get_root().add_child(planche)
	# `_ready()` n'a pas encore tourne : on est toujours dans `_init()` de la
	# SceneTree, avant la premiere image, donc `_plateau` serait nul. On laisse
	# passer une image plutot que d'appeler `_ready()` a la main -- on veut le
	# vrai chemin de code, sinon le test ne prouve rien.
	await process_frame
	planche.poser_villes(ports, proj)
	var hote := planche.get_node_or_null("Hud_Woodboard_Right_3/towns")
	if hote == null:
		print("\n=== code livre : noeud `towns` INTROUVABLE ===")
		quit(1)
		return

	var poses: Array[Vector2] = []
	for e in hote.get_children():
		var c := e as Control
		if c != null:
			poses.append(c.position + HudDroitePR3.PASTILLE * 0.5)

	print("\n=== ce que pose le code livre : %d marqueurs ===" % poses.size())
	var seaux := [0, 0, 0, 0]
	var hors := 0
	var cumul := 0
	for p in poses:
		var x := int(round(p.x))
		var y := int(round(p.y))
		if x < 0 or y < 0 or x >= _l or y >= _h:
			hors += 1
			continue
		var d: int = _dist[y * _l + x]
		cumul += d
		if d <= 1: seaux[0] += 1
		elif d <= 2: seaux[1] += 1
		elif d <= 4: seaux[2] += 1
		else: seaux[3] += 1
	print("   distance au littoral : <=1 px %d   <=2 px %d   <=4 px %d   au-dela %d   hors %d"
		% [seaux[0], seaux[1], seaux[2], seaux[3], hors])
	print("   distance moyenne %.1f px"
		% (float(cumul) / float(maxi(poses.size(), 1))))
	print("   (doit reproduire la ligne « avec le MEILLEUR ajustement » ci-dessus)")

	# On DÉPOSE les points, pour pouvoir les regarder. Une distance moyenne de
	# 0,7 px ne dit pas si la carte est lisible, et chaque défaut sérieux trouvé
	# sur ce HUD l'a été à l'œil, jamais par un compteur. Godot en mode fenêtre
	# cale sur cette machine : la composition se fait donc hors du moteur.
	#
	#   godot --headless --script res://outils/test_minimap.gd -- <fichier>
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		var sortie := FileAccess.open(args[0], FileAccess.WRITE)
		if sortie != null:
			for p in poses:
				sortie.store_line("%.2f %.2f" % [p.x, p.y])
			sortie.close()
			print("   %d points déposés dans %s" % [poses.size(), args[0]])
		else:
			print("   impossible d'écrire dans %s" % args[0])
	quit(0)


# Distance de chaque pixel au trait de cote, par propagation en largeur.
func _champ_de_distance() -> void:
	_dist = PackedInt32Array()
	_dist.resize(_l * _h)
	var file := PackedInt32Array()
	for y in range(_h):
		for x in range(_l):
			var i := y * _l + x
			_dist[i] = LOIN
			if _bord(x, y):
				_dist[i] = 0
				file.append(i)
	var t := 0
	while t < file.size():
		var i := file[t]
		t += 1
		var x := i % _l
		var y := i / _l
		for k in range(4):
			var nx: int = x + DX[k]
			var ny: int = y + DY[k]
			if nx < 0 or ny < 0 or nx >= _l or ny >= _h:
				continue
			var j: int = ny * _l + nx
			if _dist[j] > _dist[i] + 1:
				_dist[j] = _dist[i] + 1
				file.append(j)


# Un pixel du TRAIT de cote : de la terre et de l'eau se touchent ici.
func _bord(x: int, y: int) -> bool:
	var ici := _terre(x, y)
	for k in range(4):
		var nx: int = x + DX[k]
		var ny: int = y + DY[k]
		if nx < 0 or ny < 0 or nx >= _l or ny >= _h:
			continue
		if _terre(nx, ny) != ici:
			return true
	return false


func _terre(x: int, y: int) -> bool:
	var c := _img.get_pixel(x, y)
	return c.a > 0.5 and c.r > c.b + 0.06


func _cout(uv: Array[Vector2], ku: float, du: float, kv: float, dv: float) -> int:
	var somme := 0
	for p in uv:
		var u := 0.5 + (p.x - 0.5) * ku + du
		var v := 0.5 + (p.y - 0.5) * kv + dv
		if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
			somme += 40
			continue
		var x := int(round(u * (_l - 1)))
		var y := int(round(v * (_h - 1)))
		somme += mini(_dist[y * _l + x], 20)
	return somme


func _rapport(uv: Array[Vector2], noms: Array[String],
		ku: float, du: float, kv: float, dv: float) -> void:
	var seaux := [0, 0, 0, 0]      # <=1, <=2, <=4, au-dela
	var hors := 0
	var somme := 0
	var loin: Array[String] = []
	for i in range(uv.size()):
		var u := 0.5 + (uv[i].x - 0.5) * ku + du
		var v := 0.5 + (uv[i].y - 0.5) * kv + dv
		if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
			hors += 1
			loin.append(noms[i] + " (hors)")
			continue
		var x := int(round(u * (_l - 1)))
		var y := int(round(v * (_h - 1)))
		var d := _dist[y * _l + x]
		somme += d
		if d <= 1: seaux[0] += 1
		elif d <= 2: seaux[1] += 1
		elif d <= 4: seaux[2] += 1
		else:
			seaux[3] += 1
			loin.append("%s (%d px)" % [noms[i], d])
	var n := maxi(uv.size(), 1)
	print("   distance au littoral : <=1 px %d   <=2 px %d   <=4 px %d   au-dela %d   hors %d"
		% [seaux[0], seaux[1], seaux[2], seaux[3], hors])
	print("   soit %.0f %% a 2 px ou moins, distance moyenne %.1f px"
		% [100.0 * (seaux[0] + seaux[1]) / float(n), float(somme) / float(n)])
	if not loin.is_empty():
		print("   les eloignes : ", ", ".join(PackedStringArray(loin)).substr(0, 300))
