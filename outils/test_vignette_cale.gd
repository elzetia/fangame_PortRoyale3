# L'onglet de la CALE de la vignette de convoi : sa pagination tient-elle ?
#
# POURQUOI CE TEST. Le panneau etait signale « completement bugue ». Il ne l'etait
# pas : instancie seul, tout y fonctionnait -- douze cases, icones, quantites,
# deux pages pour quatorze lots. Le defaut etait dans son USAGE, et aucun test ne
# l'exercait.
#
#   1. Les deux fleches `bu_prev` / `bu_next` que PR3 declare n'etaient branchees
#      a RIEN. `tourner()` existait sans appelant.
#   2. `poser_cargaison()` remettait la page a zero, et la carte l'appelle a
#      CHAQUE IMAGE depuis `_maj_hud()`. La page choisie ne survivait pas une
#      milliseconde.
#
# Les deux se voient seulement en SIMULANT la boucle de jeu : on tourne une page,
# puis on repose la meme cargaison comme le fait `_process`, et l'on regarde si la
# page a tenu. Un test qui se contente d'appeler `tourner()` passerait au vert.
#
# Lance : godot --headless --path . --script outils/test_vignette_cale.gd
extends SceneTree

var _ecarts := 0


func _rater(quoi: String) -> void:
	_ecarts += 1
	print("  ÉCART  ", quoi)


func _lots(n: int) -> Array:
	var sortie: Array = []
	for i in range(n):
		sortie.append({"cle": "bois", "nom": "Bois", "rang": i % 20,
				"quantite": 10 + i})
	return sortie


func _init() -> void:
	process_frame.connect(_lancer, CONNECT_ONE_SHOT)


func _lancer() -> void:
	var v := ConvoiVignettePR3.new()
	root.add_child(v)

	print("=== 1. LA GRILLE SE REMPLIT ===")
	var lots := _lots(14)
	v.poser_cargaison(lots)
	print("  %d lots -> %d page(s), page %d" % [lots.size(), v.pages(), v.page()])
	if v.pages() != 2:
		_rater("14 lots devraient tenir sur 2 pages, %d obtenue(s)" % v.pages())
	var remplies := 0
	for i in range(12):
		var case := v.find_child("list_item_%d" % i, true, false)
		if case == null:
			continue
		var q := case.get_node_or_null("quantite") as Label
		if q != null and q.text != "":
			remplies += 1
	print("  cases remplies : %d / 12" % remplies)
	if remplies != 12:
		_rater("%d case(s) remplie(s) sur 12" % remplies)

	print("")
	print("=== 2. LES FLÈCHES SONT BRANCHÉES ===")
	# PR3 les nomme `bu_prev` et `bu_next` dans `Visual_List_Goods_43`. Elles
	# doivent porter une connexion, sans quoi elles sont inertes a l'ecran.
	var liste := v.find_child("li_goods", true, false)
	var branchees := 0
	if liste == null:
		_rater("panneau `li_goods` introuvable")
	else:
		for nom in ["bu_prev", "bu_next"]:
			var trouve := false
			for e in liste.find_children("*", "Button", true, false):
				var b: Button = e
				if b.position == (liste.find_child(nom, true, false) as Control).position \
						and b.pressed.get_connections().size() > 0:
					trouve = true
			if trouve:
				branchees += 1
			else:
				_rater("la flèche %s n'est connectée à rien" % nom)
	print("  flèches connectées : %d / 2" % branchees)

	print("")
	print("=== 3. LA PAGE SURVIT À LA BOUCLE DE JEU ===")
	# LE CONTROLE QUI COMPTE. La carte repose la cargaison a chaque image ; si
	# `poser_cargaison` remet la page a zero, tourner une page est impossible.
	v.tourner(1)
	var apres_fleche := v.page()
	print("  après tourner(1) : page %d" % apres_fleche)
	if apres_fleche != 1:
		_rater("la flèche n'a pas tourné la page")
	# Trois « images » de jeu avec la MEME cargaison.
	for _i in range(3):
		v.poser_cargaison(_lots(14))
	print("  après 3 images de jeu : page %d" % v.page())
	if v.page() != apres_fleche:
		_rater("la page est retombée à %d : elle ne survit pas à la boucle" % v.page())

	print("")
	print("=== 4. UNE CARGAISON QUI CHANGE REDESSINE ===")
	v.poser_cargaison(_lots(3))
	print("  3 lots -> %d page(s), page %d" % [v.pages(), v.page()])
	if v.pages() != 1:
		_rater("3 lots devraient tenir sur 1 page")
	# La page 1 n'existe plus : on doit etre revenu a la premiere.
	if v.page() != 0:
		_rater("la page %d n'existe plus, on devait revenir à 0" % v.page())
	var reste := 0
	for i in range(12):
		var case := v.find_child("list_item_%d" % i, true, false)
		if case == null:
			continue
		var q := case.get_node_or_null("quantite") as Label
		if q != null and q.text != "":
			reste += 1
	print("  cases remplies : %d (3 attendues)" % reste)
	if reste != 3:
		_rater("%d case(s) remplie(s), 3 attendues : la grille n'a pas suivi" % reste)

	print("")
	if _ecarts == 0:
		print("=== LA CALE TIENT : pagination branchée et durable. ===")
	else:
		print("=== %d ÉCART(S). ===" % _ecarts)
	quit(0 if _ecarts == 0 else 1)
