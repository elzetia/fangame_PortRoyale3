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
# Le cadrage que `HudDroitePR3` applique, recopie ici pour formuler une ATTENTE
# independante : si les deux se mettent a diverger, le test doit le dire.
#
# LA COPIE EST VOULUE, ne pas la remplacer par une lecture de `HudDroitePR3` :
# une attente qui lit la valeur qu'elle verifie ne verifie plus rien.
#
# Refait TROIS FOIS, chaque fois que la projection OU la position des ports a
# bouge :
#   1. le decor passe de l'illustration a la carte de Port Royale 3
#      (1,070/0,930 -> 1,170/1,090) ;
#   2. le masque de navigation recale sur le relief de PR3 -- la fiche prend un
#      centre non nul et `vue_taille.y` perd 3,55 %, donc seul l'axe V bouge
#      (1,090 -> 1,040) ;
#   3. les soixante ports rendus aux cases de PR3, `villes_reglages.lua` vide.
#
# L'ECHELLE VERTICALE EST ALORS TOMBEE A 1,000 EXACTEMENT (1,090 -> 1,040 ->
# 1,000) : la minimap n'a plus rien a redimensionner. Une constante de
# compensation qui s'annule dit que ce qu'elle compensait a disparu.
const CADRAGE_ATTENDU_U := 1.160
const CADRAGE_ATTENDU_V := 1.000
# La taille de la carte des mers, pour formuler l'attente sans relire l'image.
const MINIMAP_L := 196.0
const MINIMAP_H := 156.0
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
		# Seulement les MARQUEURS : depuis que la minimap se clique, chaque ville
		# porte aussi une zone sensible posee au meme point. Les compter toutes
		# doublerait le total et ferait mentir la ligne « 60 marqueurs ».
		var c := e as TextureRect
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
	# --- le CADRE DE VUE -----------------------------------------------------
	# Rien ne l'exercait : ni `test_ecran` (sans sim ni projection), ni la mesure
	# ci-dessus. Il pouvait donc planter, ou se poser n'importe ou sur la
	# planche, en laissant tous les tests au vert. On lui donne une vue CONNUE --
	# la moitie centrale de la carte -- et on relit les quatre bords.
	var centre := Vector2(proj.pixels) * 0.5
	var demi := Vector2(proj.pixels) * 0.25
	planche.poser_vue(proj, Rect2(centre - demi, demi * 2.0))
	var vue_hote := planche.get_node_or_null("Hud_Woodboard_Right_3/minimap_view")
	if vue_hote == null:
		print("\n=== cadre de vue : noeud `minimap_view` INTROUVABLE ===")
	else:
		var bords: Array[ColorRect] = []
		for e in vue_hote.get_children():
			var cr := e as ColorRect
			if cr != null:
				bords.append(cr)
		print("\n=== cadre de vue : %d bords poses ===" % bords.size())
		if bords.size() == 4:
			var x0 := bords[2].position.x
			var x1 := bords[3].position.x + bords[3].size.x
			var y0 := bords[0].position.y
			var y1 := bords[1].position.y + bords[1].size.y
			# La vue couvre la moitie de la carte : apres cadrage le rectangle
			# doit faire ~196/2*1,170 sur ~156/2*1,090, centre sur la minimap.
			print("   x %.1f..%.1f   y %.1f..%.1f   (minimap 196 x 156)"
				% [x0, x1, y0, y1])
			print("   taille %.1f x %.1f   attendu ~%.0f x %.0f"
				% [x1 - x0, y1 - y0, 196.0 * 0.5 * CADRAGE_ATTENDU_U,
					156.0 * 0.5 * CADRAGE_ATTENDU_V])

			# Second cas : une vue PLUS GRANDE que la carte, ce qu'on obtient au
			# dezoom maximal -- un etat tout a fait ordinaire en jeu. Le cadre
			# doit alors etre rogne au rectangle de la minimap, sans quoi il irait
			# peindre sur le bois de la planche. C'est ce que le commentaire de
			# `poser_vue()` affirme, et cette branche (`Rect2.intersection`)
			# n'etait pas exercee : on verifie l'affirmation plutot que de la
			# croire.
			planche.poser_vue(proj, Rect2(-centre, Vector2(proj.pixels) * 2.0))
			var gx0 := bords[2].position.x
			var gx1 := bords[3].position.x + bords[3].size.x
			var gy0 := bords[0].position.y
			var gy1 := bords[1].position.y + bords[1].size.y
			print("   au dezoom maximal : x %.1f..%.1f   y %.1f..%.1f"
				% [gx0, gx1, gy0, gy1])
			var deborde := (gx0 < -0.01 or gy0 < -0.01
				or gx1 > MINIMAP_L + 0.01 or gy1 > MINIMAP_H + 0.01)
			print("   %s" % ("*** DEBORDE : le cadre peindrait sur le bois ***"
				if deborde else "rogne au cadre, rien ne deborde"))

	# --- le CLIC -------------------------------------------------------------
	# Un signal jamais emis est un signal mort. On presse la premiere zone.
	var recu := {"cle": ""}
	planche.ville_choisie.connect(func(c: String) -> void: recu["cle"] = c)
	var zones := 0
	var premier: Button = null
	for e in hote.get_children():
		var bt := e as Button
		if bt != null:
			zones += 1
			if premier == null:
				premier = bt
	if premier == null:
		print("\n=== clic : AUCUNE zone sensible sur les villes ===")
	else:
		premier.pressed.emit()
		print("\n=== clic : %d zones sensibles ===" % zones)
		print("   la premiere rend la cle « %s »" % str(recu["cle"]))

	# --- les ROUTES ----------------------------------------------------------
	# Comme le cadre de vue, rien ne les exerce. On donne DEUX convois en route
	# — dont un choisi — et un troisieme a quai : la planche doit poser DEUX
	# traces, pas un. C'est tout l'objet du changement : elle posait la pastille
	# de chaque convoi mais ne tracait qu'une route.
	var depart := proj.centre
	var etapes: Array = [
		Vector2(proj.centre.x + 2000.0, proj.centre.y),
		Vector2(proj.centre.x + 2000.0, proj.centre.y + 1500.0)]
	var faux_convois: Array = [
		{"position": depart, "route": etapes,
			"selectionne": true, "a_quai": false},
		{"position": Vector2(proj.centre.x - 1500.0, proj.centre.y),
			"route": [Vector2(proj.centre.x - 1500.0, proj.centre.y + 900.0)],
			"selectionne": false, "a_quai": false},
		{"position": depart, "route": [], "selectionne": false, "a_quai": true}]
	planche.poser_routes(faux_convois, proj)
	var route_hote := planche.get_node_or_null("Hud_Woodboard_Right_3/minimap_route")
	if route_hote == null:
		print("\n=== routes : noeud `minimap_route` INTROUVABLE ===")
	else:
		var lignes: Array[Line2D] = []
		for e in route_hote.get_children():
			var l2 := e as Line2D
			if l2 != null and l2.points.size() > 0:
				lignes.append(l2)
		print("\n=== routes : %d trace(s) pose(s), 2 attendus   %s ===" % [
			lignes.size(), "OK" if lignes.size() == 2 else "*** ECART ***"])
		for l in lignes:
			print("   %d points, alpha %.2f" % [l.points.size(), l.default_color.a])
		# Le convoi CHOISI doit avoir le trace le plus franc, sinon sa route se
		# confondrait avec celles des autres.
		if lignes.size() >= 2:
			var alphas: Array = []
			for l in lignes:
				alphas.append(l.default_color.a)
			print("   le choisi se distingue : %s"
				% ["oui" if alphas.max() > alphas.min() else "*** NON ***"])
		# Tous a quai : plus aucun trace visible. Les `Line2D` restent en place,
		# videes, pour le prochain appareillage.
		planche.poser_routes([{"position": depart, "route": [],
			"selectionne": true, "a_quai": true}], proj)
		var restants := 0
		for e in route_hote.get_children():
			var l3 := e as Line2D
			if l3 != null and l3.points.size() > 0:
				restants += 1
		print("   tous a quai -> %d trace(s) visible(s)   %s"
			% [restants, "OK" if restants == 0 else "*** ECART ***"])

	# --- L'OR, tel que la capture du JEU le montre ---------------------------
	# Rien n'exercait `nombre()`, ni le centrage, ni l'encre : trois changements
	# qu'aucun test ne touchait. L'attente ci-dessous ne vient pas de mon code
	# mais de Port Royale 3 lui-meme, ou la planche affiche « 1.480.445 ».
	print("\n=== l'or ===")
	var attendu := "1.480.445"
	var rendu := HudDroitePR3.nombre(1480445)
	print("   nombre(1480445) = « %s »   attendu « %s »   %s"
		% [rendu, attendu, "OK" if rendu == attendu else "*** ECART ***"])

	var champ_or := planche.get_node_or_null(
		"Hud_Woodboard_Right_3/tf_gold") as Label
	if champ_or == null:
		print("   tf_gold INTROUVABLE")
	else:
		# La capture montre « 1.480.445 » et « Matelot », de longueurs
		# differentes, partageant leur AXE : donc centres, alors que le fichier
		# declare « gauche ». PR3 surcharge au runtime, comme pour la couleur.
		# `est_centre` et non `centre` : un `centre` existe deja plus haut dans
		# `_init`, pour le cadre de vue, et GDScript les met en meme portee.
		var est_centre := champ_or.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
		print("   tf_gold centre : %s" % ("oui" if est_centre else "*** NON ***"))
		var encre := champ_or.get_theme_color("font_color")
		var claire := encre.get_luminance() > 0.5
		print("   encre %s, luminance %.2f -> %s"
			% [encre, encre.get_luminance(),
				"claire, lisible sur le bois" if claire
				else "*** SOMBRE : le fichier declare du noir, mais le jeu teinte ***"])

		# --- la PIECE d'or -------------------------------------------------
		# `poser()` n'etait appele par aucun test : `_placer_piece()` n'avait
		# donc JAMAIS tourne. On la pose pour de vrai et on regarde ou elle
		# tombe -- elle doit suivre le nombre, pas flotter au bord du champ.
		# Rang 2 = Matelot : celui de la capture du jeu fournie en reference.
		planche.poser(1480445, 3, 2, 2)
		var piece: TextureRect = null
		for e in champ_or.get_parent().get_children():
			var tr := e as TextureRect
			if tr != null and tr.size == Vector2(12, 12):
				piece = tr
		if piece == null:
			print("\n=== piece d'or : AUCUNE (12x12 introuvable) ===")
		else:
			var centre_texte := champ_or.position.x + champ_or.size.x * 0.5
			print("\n=== piece d'or ===")
			print("   posee en (%.0f, %.0f), le champ est en %.0f..%.0f"
				% [piece.position.x, piece.position.y, champ_or.position.x,
					champ_or.position.x + champ_or.size.x])
			print("   a droite du centre du texte (%.0f) : %s"
				% [centre_texte,
					"oui" if piece.position.x > centre_texte else "*** NON ***"])

	# --- le RANG, avec les mots du JEU --------------------------------------
	# Le rang est un NUMERO cote sim ; la planche doit le traduire par la table de
	# textes de PR3. Un compteur de noeuds n'y verrait rien : une cle mal epelee
	# retombe EN SILENCE sur du vide, et le champ existerait quand meme. On
	# compare donc au LIBELLE, celui de la capture du jeu.
	print("\n=== le rang ===")
	var champ_rang := planche.get_node_or_null(
		"Hud_Woodboard_Right_3/tf_rang") as Label
	if champ_rang == null:
		print("   tf_rang INTROUVABLE")
	else:
		var attendu_rang := "Matelot"
		print("   rang 2 -> « %s »   attendu « %s »   %s"
			% [champ_rang.text, attendu_rang,
				"OK" if champ_rang.text == attendu_rang else "*** ECART ***"])
		# La CLE ne doit jamais fuir a l'ecran : `LocaPR3` la reemet quand la
		# table manque, et « ID_RANK_MALE_02 » s'afficherait sur le bois.
		print("   la cle ne fuit pas : %s"
			% ["oui" if not champ_rang.text.begins_with("ID_") else "*** NON ***"])
		# Rang INCONNU (-1) : le champ reste vide plutot que d'inventer un echelon.
		planche.poser(1480445, 3, 2, -1)
		print("   rang -1 -> « %s » (vide attendu)   %s"
			% [champ_rang.text, "OK" if champ_rang.text == "" else "*** ECART ***"])
		planche.poser(1480445, 3, 2, 2)

	# --- les INFOBULLES, avec les mots du JEU -------------------------------
	# Rien ne lisait un `tooltip_text`. Or les six libelles viennent desormais de
	# `LocaPR3.propre()` : une cle mal epelee retomberait EN SILENCE sur mon
	# ancien francais, tous compteurs au vert. Et « Convois &amp; villes » teste
	# d'un coup la resolution de la cle ET le desechappement du HTML.
	var bulles_droite: Array[String] = []
	for e in planche.get_node("Hud_Woodboard_Right_3").get_children():
		var bt := e as Button
		if bt != null and bt.tooltip_text != "":
			bulles_droite.append(bt.tooltip_text)

	var gauche := HudPR3.new()
	get_root().add_child(gauche)
	await process_frame
	var bulles_gauche: Array[String] = []
	for e in gauche.get_node("Hud_Woodboard_Left_PC_68").get_children():
		var bt2 := e as Button
		if bt2 != null and bt2.tooltip_text != "":
			bulles_gauche.append(bt2.tooltip_text)

	print("\n=== les infobulles ===")
	print("   planche droite : %s" % ", ".join(bulles_droite))
	print("   planche gauche : %s" % ", ".join(bulles_gauche))
	var attendues := {
		"Convois & villes": bulles_droite,
		"Journal": bulles_droite,
		"Augmenter la vitesse du jeu": bulles_gauche,
		"Baisser la vitesse du jeu": bulles_gauche,
	}
	# On compare APRES NORMALISATION : la table du jeu porte des espaces
	# INSECABLES (U+00A0), typographie francaise courante, qui s'impriment comme
	# une espace ordinaire mais ne comparent pas egal. Une premiere version de ce
	# test annoncait « 0 / 4 ABSENTE » alors que les six infobulles etaient
	# justes a l'ecran -- le compteur mentait, pas le rendu.
	var bon := 0
	for mot in attendues:
		var liste: Array = attendues[mot]
		var vise := _normalise(str(mot))
		var trouve := false
		for b in liste:
			if _normalise(str(b)) == vise:
				trouve = true
				break
		bon += int(trouve)
		print("   %-30s %s" % [mot, "OK" if trouve else "*** ABSENTE ***"])
		if not trouve:
			# Le diagnostic : quels points de code separent les deux chaines ?
			for b in liste:
				if str(b).length() == str(mot).length():
					print("      candidat « %s »" % b)
					print("        attendu : %s" % _codes(str(mot)))
					print("        obtenu  : %s" % _codes(str(b)))
	print("   -> %d / %d  (les mots viennent de la table du jeu, pas de moi)"
		% [bon, attendues.size()])

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
# Espaces INSECABLES ramenees a des espaces ordinaires, et bords rognes.
# La table du jeu porte de la typographie francaise : ces caracteres
# s'impriment comme une espace mais ne comparent pas egal.
#
# PLUS DE `strip_edges()` ICI. Il rognait les bords, donc il cachait le RETOUR
# CHARIOT que `LocaPR3` laissait au bout de chacune des 2955 valeurs du jeu
# (fichier CRLF decoupe sur « \n » seul). Ce test avait vu le symptome, et la
# bequille l'a fait taire pendant que le defaut restait dans le chargeur, pour
# tous les ecrans. Corrige a la source : le test n'a plus a s'en proteger, et il
# doit desormais ECHOUER si la pollution revient.
func _normalise(s: String) -> String:
	return s.replace(String.chr(0x00A0), " ").replace(String.chr(0x202F), " ")


# Les points de code d'une chaine, pour voir ce qui separe deux textes
# visuellement identiques.
func _codes(s: String) -> String:
	var out: Array[String] = []
	for i in s.length():
		out.append("%d" % s.unicode_at(i))
	return ", ".join(out)


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
