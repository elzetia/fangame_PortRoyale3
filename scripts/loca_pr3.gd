# Les textes de Port Royale 3, dans la langue du jeu.
#
# PR3 range ses libellés dans `data_fr.fuk -> ui/locale/frfr/global.res`, format
# maison « L10N » : une table de (hash, offset, longueur) puis les textes en
# UTF-16LE. Les clés (ID_GUI_*) ne sont pas dans le fichier — seulement leur
# hash. Ce hash a été retrouvé en ancrant sur une paire connue :
#
#       h = 0 ; pour chaque octet c de la clé : h = (h * 113 + c) mod 2^32
#
# `outils/pr3_loca.py` applique ce hash aux 2610 clés lues dans l'exe et écrit
# la table appariée (2103 clés, 80 %) dans
# `reference_pr3/ui/agencement/textes_fr.txt`, ignoré par git : c'est le texte
# du jeu, sous droits. Absent, `texte()` rend le repli passé par l'appelant —
# l'écran reste lisible, seulement pas dans les mots exacts de PR3.
class_name LocaPR3
extends RefCounted

const FICHIER := "res://reference_pr3/ui/agencement/textes_fr.txt"

static var _table: Dictionary = {}
static var _lu := false


static func _charger() -> void:
	if _lu:
		return
	_lu = true
	var chemin := ProjectSettings.globalize_path(FICHIER)
	if not FileAccess.file_exists(chemin):
		return
	# LE FICHIER EST EN CRLF, et découper sur « \n » seul laissait un RETOUR
	# CHARIOT au bout de CHACUNE des 2955 valeurs. « Matelot\r » ne vaut pas
	# « Matelot » : la comparaison échoue sur deux chaînes qui s'affichent
	# pourtant identiques. Cela touchait TOUT le jeu — chaque libellé, chaque
	# infobulle, chaque écran —, pas seulement le champ qui l'a révélé.
	#
	# Le test des infobulles avait attrapé ce symptôme plus tôt ; je l'avais
	# alors fait taire en normalisant DANS LE TEST (`strip_edges`). Le défaut est
	# resté ici, invisible, jusqu'à ce que le rang le remontre. Corrigé à la
	# source, et la béquille du test est retirée.
	var texte := FileAccess.get_file_as_string(chemin).replace("\r\n", "\n")
	for ligne in texte.split("\n"):
		var coupe := ligne.split("\t", true, 1)
		if coupe.size() == 2:
			_table[coupe[0]] = coupe[1]


# Le texte de PR3 pour cette clé, ou `defaut` si la table n'est pas là.
static func texte(cle: String, defaut := "") -> String:
	_charger()
	return str(_table.get(cle, defaut if defaut != "" else cle))


# Le texte de PR3, DÉSÉCHAPPÉ. La table porte du HTML : « Convois &amp; villes »
# s'affiche tel quel dans une infobulle si on ne le décode pas.
static func propre(cle: String, defaut := "") -> String:
	var s := texte(cle, defaut)
	return (s.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
		.replace("&quot;", "\"").replace("&apos;", "'").replace("&nbsp;", " "))


# Comme `texte`, mais remplace les jetons %1, %2… de PR3 par les arguments.
static func format(cle: String, args: Array, defaut := "") -> String:
	var s := texte(cle, defaut)
	for i in args.size():
		s = s.replace("%%%d" % (i + 1), str(args[i]))
	return s


static func disponible() -> bool:
	_charger()
	return not _table.is_empty()
