# La police de Port Royale 3 : Benjamin, rebatie depuis les glyphes du jeu.
#
# PR3 n'installe aucun fichier de police. Ses lettres vivent dans
# `ui/glyph_lib.swf`, en DefineFont3, sous forme de contours vectoriels.
# `outils/swf_fonte.py` les reconstitue en TrueType dans
# `reference_pr3/ui/polices/`. Le clone tournait jusqu'ici sur la police par
# defaut de Godot : c'est le dernier ecart visible entre sa planche et celle du
# jeu, une fois l'art, les couleurs et les positions en place.
#
# DROITS ET ABSENCE. Benjamin est une fonte COMMERCIALE (SoftMaker Software
# GmbH) : les .ttf vivent dans `reference_pr3/`, ignore par git, et ne quittent
# pas la machine du joueur. Le depot etant PUBLIC, une copie fraiche n'a donc
# AUCUN .ttf. `charger()` rend alors `null` et l'appelant garde la police par
# defaut — exactement ce que fait `LocaPR3` quand la table des textes manque.
# L'ecran reste lisible, seulement pas dans les lettres de PR3.
#
# On charge par chemin ABSOLU (`load_dynamic_font`) et non par `load()` :
# `reference_pr3/` n'est pas importe par Godot, et ne doit pas l'etre — ses
# fichiers ne sont pas des ressources du projet.
class_name FontePR3
extends RefCounted

const DOSSIER := "res://reference_pr3/ui/polices/"

# Les deux graisses que le jeu embarque. (`Arial` est la troisieme fonte du
# .swf, mais PR3 ne s'en sert pas pour son interface.)
const LIVRE := "Benjamin-Book"
const GRAS := "Benjamin-Bold"

static var _cache: Dictionary = {}


# La fonte demandee, ou `null` si elle n'a pas ete extraite sur cette machine.
static func charger(nom := LIVRE) -> FontFile:
	if _cache.has(nom):
		return _cache[nom]
	_cache[nom] = null
	var chemin := ProjectSettings.globalize_path(DOSSIER + nom + ".ttf")
	if not FileAccess.file_exists(chemin):
		return null
	var f := FontFile.new()
	# Le nom de la methode a change selon les versions de Godot : on interroge
	# l'objet plutot que de parier, sinon l'absence d'UNE methode ferait echouer
	# la COMPILATION du script au lieu de degrader proprement.
	var err := ERR_UNAVAILABLE
	if f.has_method("load_dynamic_font"):
		err = f.call("load_dynamic_font", chemin)
	elif f.has_method("load_dynamic_font_from_file"):
		err = f.call("load_dynamic_font_from_file", chemin)
	if err != OK:
		return null
	_cache[nom] = f
	return f


# Pose la fonte sur un nœud, s'il y en a une. Sans surcharge, Godot garde la
# sienne : c'est voulu, et c'est pourquoi on ne pose rien quand `charger()` rend
# `null` plutot que d'ecrire une surcharge vide.
static func poser(n: Control, gras := false) -> bool:
	var f := charger(GRAS if gras else LIVRE)
	if f == null:
		return false
	n.add_theme_font_override("font", f)
	return true


static func disponible() -> bool:
	return charger() != null
