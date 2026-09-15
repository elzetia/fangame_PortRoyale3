# Le panneau d'infos de ville pose-t-il VRAIMENT notre vignette ?
#
# POURQUOI CE TEST. `VillePR3` recevait la table des vignettes par `poser_villes()`
# depuis toujours — la carte la lui donnait à la construction — et NE S'EN SERVAIT
# JAMAIS. La table était stockée et morte, et seul l'ancien panneau dessinait la
# ville. Rien ne le signalait : le panneau se bâtit très bien sans image.
#
# Et la première correction n'a rien corrigé : elle testait `is TextureRect` sur
# l'emplacement `icon_town`, qui est un CONTROL NU — son caractère de PR3 est
# anonyme, donc l'écran ne lui pose aucune image. La fonction sortait en silence.
# Deux bugs muets de suite au même endroit : d'où ce test, qui instancie le
# panneau pour de bon et va CHERCHER l'image.
#
# ON ATTEND UNE IMAGE avant d'ouvrir : dans `_init`, `_ready` n'est pas encore
# propagé et la page du panneau n'existe pas. Le jeu, lui, ouvre le panneau
# longtemps après le démarrage.
#
# Lance : godot --headless --path . --script outils/test_ville_pr3.gd
extends SceneTree

var _ecarts := 0


func _rater(quoi: String) -> void:
	_ecarts += 1
	print("  ÉCART  ", quoi)


# Le nœud nommé `nom`, cherché dans TOUT l'arbre — la page de PR3 est profonde.
func _trouver(n: Node, nom: String) -> Node:
	var pile: Array = [n]
	while not pile.is_empty():
		var noeud: Node = pile.pop_back()
		for e in noeud.get_children():
			if str(e.name) == nom:
				return e
			pile.append(e)
	return null


func _init() -> void:
	process_frame.connect(_lancer, CONNECT_ONE_SHOT)


func _lancer() -> void:
	var sim := Sim.new()
	if not sim.pret:
		print("ARRÊT : le pont Lua ne démarre pas — ", sim.erreur)
		quit(1)
		return
	var ports: Array = sim.ports()
	if ports.is_empty():
		print("ARRÊT : aucun port.")
		quit(1)
		return

	var villes := Villes.new()
	print("vignettes de ville chargées : %d" % villes.textures.size())
	if villes.vide():
		# Les vignettes sont à NOUS (`sprites/villes/`), pas à PR3 : elles sont
		# dans le dépôt. Absentes, c'est une vraie panne, pas un repli.
		_rater("aucune vignette dans sprites/villes — rien à poser")

	var panneau := VillePR3.new()
	root.add_child(panneau)
	panneau.poser_villes(villes)

	var port: Dictionary = ports[0]
	print("ville d'essai : %s" % port.get("nom", "?"))
	panneau.ouvrir(sim, port, true)

	var slot := _trouver(panneau, "icon_town")
	print("emplacement icon_town : %s" % ("ABSENT" if slot == null else slot.get_class()))
	if slot == null:
		_rater("pas d'emplacement icon_town dans la page")
		_verdict()
		return

	var vignette := slot.get_node_or_null(NodePath("vignette_ville")) as TextureRect
	if vignette == null:
		_rater("aucune vignette attachée à icon_town — le panneau n'a rien posé")
		_verdict()
		return
	print("  vignette : %s, taille %s" % [
			"posée" if vignette.texture != null else "SANS TEXTURE", vignette.size])
	if vignette.texture == null:
		_rater("la vignette est là mais ne porte aucune image")
	elif not villes.textures.has(vignette.texture):
		_rater("la vignette ne vient pas de sprites/villes")

	# ET ELLE DOIT SUIVRE LA POPULATION. Sans cette exigence, le panneau pourrait
	# poser toujours la même image : le test passerait, et l'on ne verrait jamais
	# un comptoir devenir une cité.
	var stades := {}
	for p in ports:
		var d: Dictionary = p
		panneau.ouvrir(sim, d, true)
		var v := slot.get_node_or_null(NodePath("vignette_ville")) as TextureRect
		if v != null and v.texture != null:
			stades[v.texture] = true
	print("  stades distincts sur les %d villes : %d" % [ports.size(), stades.size()])
	if stades.size() < 2:
		_rater("toutes les villes montrent la même vignette — elle ne suit pas la population")

	_verdict()


func _verdict() -> void:
	print("")
	if _ecarts == 0:
		print("=== LE PANNEAU POSE NOTRE VIGNETTE DE VILLE. ===")
	else:
		print("=== %d ÉCART(S). ===" % _ecarts)
	quit(0 if _ecarts == 0 else 1)
