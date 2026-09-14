# Tous les scripts du projet compilent-ils ?
#
# CE TEST EXISTE PARCE QUE LES AUTRES NE COUVRENT PAS LE GROS DU CODE. Les quatre
# suites instancient `ProjectionCarte`, `HudDroitePR3`, `ConvoiVignettePR3`,
# `Sim` — mais JAMAIS `scripts/carte2d.gd`, qui est pourtant le plus gros fichier
# du jeu et celui qu'on touche le plus souvent. Une erreur de syntaxe y passait
# donc au VERT sur toute la batterie, et ne se voyait qu'en lançant la partie.
#
# ET `--check-only` NE RATTRAPE RIEN. Sur un script qui n'hérite pas de
# `SceneTree`, `godot --headless --check-only --script res://scripts/carte2d.gd`
# rend 0 sans imprimer une ligne — qu'il ait compilé ou qu'il l'ait ignoré. Deux
# situations opposées, sortie identique : ce contrôle ne prouve rien.
#
# Ici on fait la seule chose qui prouve quelque chose : on CHARGE chaque script.
# `load()` rend `null` quand la compilation échoue, et Godot imprime l'erreur au
# passage. Un fichier qui se charge est un fichier qui compile.
#
# Lance : godot --headless --path . --script res://outils/test_compilation.gd
extends SceneTree

const DOSSIERS := ["res://scripts", "res://outils", "res://tools"]

var _rates: Array[String] = []
var _vus := 0


# Tous les `.gd` sous un dossier, en descendant.
func _lister(chemin: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(chemin)
	if d == null:
		return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var complet := chemin + "/" + n
		if d.current_is_dir():
			if not n.begins_with("."):
				out.append_array(_lister(complet))
		elif n.ends_with(".gd"):
			out.append(complet)
		n = d.get_next()
	d.list_dir_end()
	return out


func _init() -> void:
	print("=== compilation de tous les scripts ===")
	for dossier in DOSSIERS:
		var fichiers := _lister(dossier)
		print("   %-16s %d fichier(s)" % [dossier.trim_prefix("res://"), fichiers.size()])
		for chemin in fichiers:
			_vus += 1
			# `load()` et pas `ResourceLoader.exists()` : seul le chargement
			# compile réellement le script.
			var s: Resource = load(chemin)
			if s == null:
				_rates.append(chemin)

	print("")
	if _rates.is_empty():
		print("Les %d scripts compilent." % _vus)
		quit(0)
		return
	for r in _rates:
		print("*** ECART : %s ne compile pas" % r)
	print("%d script(s) en echec sur %d." % [_rates.size(), _vus])
	quit(1)
