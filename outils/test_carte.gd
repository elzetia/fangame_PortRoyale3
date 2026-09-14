# Le decor de la carte se charge-t-il VRAIMENT ?
#
# CE TEST EXISTE A CAUSE D'UNE PANNE QUI N'A LAISSE AUCUNE TRACE VISIBLE. Le
# `.ctex` de `carte_cuite.png` avait disparu de `.godot/imported` : `load()`
# rendait `null`, le decor n'etait donc pas dessine, et il ne restait a l'ecran
# que la nappe de mer -- un bleu uniforme d'un bord a l'autre, sans une ile. Le
# jeu le signalait bien, par un `push_error` de `carte2d.gd`, mais personne ne
# lit la console en lancant `jouer.bat`. Rien dans les suites ne chargeait la
# carte : elles mesuraient la projection, jamais la texture.
#
# DEUX PANNES A NE PAS CONFONDRE, et c'est tout l'objet de ce test :
#
#   * LE FICHIER EST ABSENT. C'est le cas NORMAL d'une copie fraiche : la carte
#     est celle de Port Royale 3, sous droits, et ne vient plus avec le depot.
#     Il faut la refabriquer depuis sa propre copie du jeu. Le test le dit et
#     s'arrete la, sans crier a l'erreur.
#
#   * LE FICHIER EST LA MAIS NE SE CHARGE PAS. C'est la vraie panne, celle qui
#     donne l'ecran bleu : le cache d'import est casse.
#     `godot --headless --path . --import` le reconstruit.
#
# Lance : godot --headless --path . --script res://outils/test_carte.gd
extends SceneTree

const CARTE := "res://carte_cuite.png"
const MER := "res://carte_cuite_mer.png"
const FICHE := "res://carte_cuite.json"

# La taille de l'assemblage de Port Royale 3 : worldmapleft (4096 x 4096) et
# worldmapright (2048 x 4096) accolees, puis reduites de moitie.
const TAILLE := Vector2i(3072, 2048)

# En dessous de cette part d'opaque, l'ecran serait bleu meme avec une texture
# chargee : une carte toute transparente ne se voit pas plus qu'une carte absente.
const OPAQUE_MINIMUM := 20.0

var _ecarts := 0


func _rater(quoi: String) -> void:
	_ecarts += 1
	print("*** ECART : %s" % quoi)


# Charge une texture en DISTINGUANT les deux pannes.
func _charger(chemin: String, quoi: String) -> Texture2D:
	if not FileAccess.file_exists(chemin):
		print("   %s : ABSENT" % quoi)
		return null
	var tex: Texture2D = load(chemin)
	if tex == null:
		_rater("%s est sur le disque mais `load()` rend null" % quoi)
		print("      -> cache d'import casse. Reconstruire :")
		print("         godot --headless --path . --import")
		return null
	print("   %s : charge, %d x %d" % [quoi, tex.get_width(), tex.get_height()])
	return tex


func _init() -> void:
	print("=== le decor de la carte ===")
	var absente := not FileAccess.file_exists(CARTE)
	var carte := _charger(CARTE, "carte_cuite.png")
	var _mer := _charger(MER, "carte_cuite_mer.png")

	if carte != null:
		if Vector2i(carte.get_width(), carte.get_height()) != TAILLE:
			_rater("la carte fait %d x %d, attendu %d x %d" % [
					carte.get_width(), carte.get_height(), TAILLE.x, TAILLE.y])
		# UNE CARTE ENTIEREMENT TRANSPARENTE donnerait le meme ecran bleu qu'une
		# carte absente : on verifie qu'il reste de la terre opaque a dessiner.
		var img := carte.get_image()
		if img == null:
			_rater("la carte est chargee mais ne rend aucune image")
		else:
			var opaques := 0
			var total := 0
			for y in range(0, img.get_height(), 37):
				for x in range(0, img.get_width(), 37):
					total += 1
					if img.get_pixel(x, y).a > 0.9:
						opaques += 1
			var part := 100.0 * float(opaques) / float(maxi(1, total))
			print("   opaque : %.1f %% (la terre et les hauts-fonds)" % part)
			if part < OPAQUE_MINIMUM:
				_rater("la carte est presque toute transparente (%.1f %%) : l'ecran serait bleu" % part)

	var proj := ProjectionCarte.new(FICHE)
	print("   fiche de projection : valide = %s" % proj.valide)
	if not proj.valide:
		_rater("fiche invalide : %s" % proj.erreur)

	print("")
	if absente:
		print("carte_cuite.png est ABSENT, et c'est normal sur une copie fraiche :")
		print("  la carte est celle de Port Royale 3, elle n'est pas dans le depot.")
		print("  Refabrique-la depuis ta copie du jeu :")
		print("     py -3 outils/carte_ombrage.py")
		print("     py -3 outils/carte_eau.py")
		quit(0)
		return
	if _ecarts > 0:
		print("%d ecart(s) : le decor ne s'afficherait pas." % _ecarts)
		quit(1)
		return
	print("Le decor, la nappe de mer et la fiche se chargent.")
	quit(0)
