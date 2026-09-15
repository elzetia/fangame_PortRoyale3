# Le menu du joueur se bâtit-il, et « Quitter » demande-t-il bien DEUX fois ?
#
# POURQUOI CE TEST. `test_compilation.gd` prouve que le script compile. Le menu
# radial compilait aussi, et ne bâtissait AUCUN pétale : entre les deux, un écran
# entier peut être écrit sans qu'une seule ligne ne s'exécute.
#
# Et il y a ici une exigence qu'on ne peut pas juger a l'oeil sans risque : Échap
# QUITTAIT le jeu sans rien demander, et c'est ce qui faisait perdre des parties.
# Le premier appui sur « Quitter » doit donc ARMER, pas fermer. Cela se verifie
# sans jamais quitter : on presse une fois, et l'on regarde si le libelle a change
# pendant qu'on est toujours la.
#
# Lance : godot --headless --path . --script outils/test_menu_pause.gd
extends SceneTree

# Les sept entrees de PR3, dans l'ordre de sa `Scene_Ingame_Menu`.
const ATTENDUS := ["Reprendre le jeu", "Sauvegarder la partie", "Charger",
	"Paramètres", "Succès", "Menu principal", "Quitter"]
# Celles qui mènent quelque part chez nous. Les trois autres sont grisees, comme
# les petales sans ecran du radial.
const ACTIVES := ["Reprendre le jeu", "Sauvegarder la partie", "Charger", "Quitter"]

var _ecarts := 0


func _rater(quoi: String) -> void:
	_ecarts += 1
	print("  ÉCART  ", quoi)


func _boutons(n: Node) -> Array:
	var sortie: Array = []
	var pile: Array = [n]
	while not pile.is_empty():
		var noeud: Node = pile.pop_back()
		for e in noeud.get_children():
			if e is Button:
				sortie.append(e)
			pile.append(e)
	return sortie


func _init() -> void:
	# Comme pour le radial : dans `_init`, `_ready` n'est pas encore propagé.
	process_frame.connect(_lancer, CONNECT_ONE_SHOT)


func _lancer() -> void:
	var sim := Sim.new()
	if not sim.pret:
		print("ARRÊT : le pont Lua ne démarre pas — ", sim.erreur)
		quit(1)
		return

	var menu := MenuPause.new()
	root.add_child(menu)

	print("=== 1. LE MENU SE BÂTIT ===")
	var avant_pause := bool(sim.etat_temps().get("en_pause", false))
	menu.ouvrir(sim)
	var b := _boutons(menu)
	print("  entrées bâties : %d" % b.size())
	if b.size() != ATTENDUS.size():
		_rater("%d entrée(s) au lieu de %d" % [b.size(), ATTENDUS.size()])

	var libelles: Array = []
	var actives: Array = []
	for e in b:
		var bo: Button = e
		libelles.append(bo.text)
		if not bo.disabled:
			actives.append(bo.text)
	print("  libellés : ", ", ".join(PackedStringArray(libelles)))
	for a in ATTENDUS:
		if not libelles.has(a):
			_rater("entrée manquante ou mal nommée : « %s »" % a)
	print("  actives : ", ", ".join(PackedStringArray(actives)))
	for a in ACTIVES:
		if not actives.has(a):
			_rater("« %s » devrait être accessible" % a)
	if actives.size() != ACTIVES.size():
		_rater("%d entrée(s) active(s), %d attendues" % [actives.size(), ACTIVES.size()])

	print("")
	print("=== 2. LE JEU EST MIS EN PAUSE ===")
	var pendant := bool(sim.etat_temps().get("en_pause", false))
	print("  avant %s  ->  pendant %s" % [avant_pause, pendant])
	if not pendant:
		_rater("le menu est ouvert et le jeu tourne toujours")

	print("")
	print("=== 3. « QUITTER » DEMANDE DEUX FOIS ===")
	# LE CONTROLE QUI JUSTIFIE TOUT L'ECRAN. On presse UNE fois : si le premier
	# appui fermait le jeu, ce test n'irait pas plus loin -- et le libelle doit
	# avoir change pour annoncer la confirmation.
	var quitter: Button = null
	for e in b:
		if (e as Button).text == "Quitter":
			quitter = e
	if quitter == null:
		_rater("pas de bouton « Quitter »")
	else:
		quitter.pressed.emit()
		print("  après un appui, libellé : « %s »" % quitter.text)
		if quitter.text == "Quitter":
			_rater("le premier appui n'a pas armé la confirmation")
		elif not quitter.text.to_lower().contains("confirmer"):
			_rater("le libellé armé ne dit pas qu'il faut confirmer : « %s »" % quitter.text)

	print("")
	print("=== 4. FERMER REND LA MAIN ===")
	menu.fermer()
	print("  visible après fermeture : %s" % menu.visible)
	if menu.visible:
		_rater("le menu reste affiché après `fermer()`")
	var apres := bool(sim.etat_temps().get("en_pause", false))
	print("  pause après fermeture : %s (était %s avant ouverture)" % [apres, avant_pause])
	if apres != avant_pause:
		_rater("la pause n'est pas rendue à son état d'avant : %s -> %s"
				% [avant_pause, apres])

	print("")
	if _ecarts == 0:
		print("=== LE MENU DU JOUEUR TIENT, ET QUITTER DEMANDE DEUX FOIS. ===")
	else:
		print("=== %d ÉCART(S). ===" % _ecarts)
	quit(0 if _ecarts == 0 else 1)
