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
	# `icon_town` est l'emplacement que PR3 reserve a l'illustration de la ville,
	# en (61,79) dans sa page, pour un caractere de 90 x 83.
	#
	# Il sort en CONTROL NU, et c'est normal : son caractere est anonyme, donc
	# `EcranPR3` ne lui connait aucune image. `VillePR3` y attache NOTRE vignette
	# en enfant. Ce test ne verifie donc que l'existence de l'emplacement ; que la
	# vignette y arrive vraiment, c'est `outils/test_ville_pr3.gd` qui le prouve.
	var icone_ville := EcranPR3.champ(t, "icon_town")
	print("  icon_town : %s" % ("ABSENT" if icone_ville == null
			else icone_ville.get_class()))
	if icone_ville == null:
		print("  *** ECART : pas d'emplacement icon_town, la vignette n'a nulle part ou aller")

	# La planche de gauche du HUD (hud_pc.swf). Attendu : 8 nœuds, dont QUATRE
	# portent une image — la planche de bois (639), les deux boutons d'allure
	# (453) et le bouton rond de la chronique (1037). Les trois autres sont la
	# plaque `Text_Bg_Nomal`, les deux champs, et `gr_scenario_info` qui reste
	# vide faute de table des caractères anonymes.
	# Avant le repli sur la table d'icônes, DEUX seulement portaient une image :
	# ni la planche ni le bouton rond ne tombaient dans une branche de `_noeud`.
	var h := EcranPR3.batir("hud_pc", "Hud_pc_fla.Hud_Woodboard_Left_PC_68", true)
	# On parcourt TOUT L'ARBRE, pas seulement les enfants directs. Depuis que les
	# symboles se rendent en EMPILEMENT (un bezel, son glyphe par-dessus), les
	# images vivent un cran plus bas, dans le Control de la pile : compter les
	# enfants directs affichait « 0 avec image » pour une planche qui en porte
	# cinq. Un compteur qui ment est pire qu'un compteur absent.
	var avec_image := 0
	var nommes: Array = []
	var a_voir: Array = [h]
	while not a_voir.is_empty():
		var noeud: Node = a_voir.pop_back()
		for e in noeud.get_children():
			if e is TextureRect and (e as TextureRect).texture != null:
				avec_image += 1
			a_voir.append(e)
	for e in h.get_children():
		var n := str(e.name)
		if n.begins_with("tf_") or n.begins_with("bu_"):
			nommes.append(n)
	print("HUD planche gauche -> %d noeuds, %d avec image : %s"
		% [h.get_child_count(), avec_image, ", ".join(nommes)])

	# Ce test comptait des nœuds sans jamais regarder OÙ ils tombent. C'est par
	# ce trou qu'une régression a déplacé TOUS les boutons de +taille/2 en
	# passant « au vert » : la table des décalages n'était plus lue alors que le
	# recentrage à la main venait d'être retiré. On épingle donc des points
	# connus, mesurés dans le .swf.
	#   bu_minus : 453.png fait 28x28, origine (-14,-14), placé en (96,36)
	#   bu_plus  : même image, placé en (167,36)
	#   tf_date  : un champ, sans décalage, placé en (65,5)
	print("--- positions attendues (décalage mesuré + point de placement) ---")
	var attendus := {"bu_minus": Vector2(82, 22), "bu_plus": Vector2(153, 22),
		"tf_date": Vector2(65, 5)}
	for nom in attendus:
		var e := EcranPR3.champ(h, str(nom))
		var vise: Vector2 = attendus[nom]
		var bon := e != null and e.position.is_equal_approx(vise)
		print("   %-10s %-14s attendu %-14s %s" % [nom,
			str(e.position) if e != null else "ABSENT", str(vise),
			"OK" if bon else "*** ECART ***"])

	# La planche DROITE vit de conteneurs imbriqués — son fond, la minimap, la
	# barre d'XP. Sans profondeur, `batir` les rendait en Control 1x1 : on doit
	# donc voir beaucoup plus de nœuds avec profondeur qu'à plat.
	for prof in [0, 4]:
		var dr := EcranPR3.batir("hud_pc", "Hud_pc_fla.Hud_Woodboard_Right_3",
			true, prof)
		var total := 0
		var images := 0
		var pile: Array = [dr]
		while not pile.is_empty():
			var noeud: Node = pile.pop_back()
			for e in noeud.get_children():
				total += 1
				if e is TextureRect and (e as TextureRect).texture != null:
					images += 1
				pile.append(e)
		print("HUD planche droite (profondeur %d) -> %d noeuds, %d avec image"
			% [prof, total, images])

	# `carte2d.gd` n'a PAS de class_name : rien ne le chargeait dans ce test, et
	# une erreur de syntaxe y serait donc passée inaperçue — c'est précisément le
	# trou par lequel un écran cassé pouvait être livré « tests au vert ».
	print("--- chargement des scripts sans class_name ---")
	for chemin in ["res://scripts/carte2d.gd", "res://scripts/hud_pr3.gd",
			"res://scripts/hud_droite_pr3.gd", "res://scripts/ecran_pr3.gd"]:
		# `ResourceLoader.load()` rend un objet NON NUL même quand le script ne
		# compile pas : le tester ne prouve RIEN. Première version de ce test,
		# elle affichait « carte2d.gd OK » dans l'exécution même où Godot criait
		# « Failed to load script : Parse error ». `reload()` rend, lui, le vrai
		# code d'erreur.
		var sc := ResourceLoader.load(chemin) as GDScript
		var etat := "ECHEC (illisible)"
		if sc != null:
			etat = "OK" if sc.reload() == OK else "ECHEC (erreur de syntaxe)"
		print("   %-24s %s" % [chemin.get_file(), etat])
	quit()
