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

	# --- l'art du CARTOUCHE des villes ---------------------------------------
	#
	# LA BANDE DU NOM N'EST PAS DE L'ART. C'est une forme VECTORIELLE de PR3
	# (`Seamap_Text_Bg_16`), qu'on repeint d'apres ses chiffres decodes -- noir a
	# 60 %, efface sur 27 % de la largeur a chaque bout, sans filet. Elle s'affiche
	# donc partout, meme sans `reference_pr3/`. Rien a verifier ici.
	#
	# LE PAVILLON ET L'ICONE DE TYPE, eux, sont des images du jeu : sous droits,
	# hors du depot, et leur absence n'est pas une faute -- la carte retombe sur
	# nos propres pavillons. Mais quand elles SONT la, leurs dimensions doivent
	# etre celles annoncees par la table d'icones. C'est ce qui attrape un
	# identifiant qui s'est trompe de cible, et j'en ai pris plusieurs aujourd'hui.
	print("")
	print("=== l'art du cartouche (facultatif) ===")
	var art := {
		"pavillon Espagne": ["skinlib_pr3/1568", 44, 30],
		"pavillon Hollande": ["skinlib_pr3/1569", 44, 30],
		"pavillon France": ["skinlib_pr3/1570", 44, 30],
		"pavillon Angleterre": ["skinlib_pr3/1571", 44, 30],
		"couronne du roi": ["skinlib_pr3/1694", 22, 24],
		"ecusson du gouverneur": ["skinlib_pr3/1695", 22, 24],
		"ancre (repos)": ["skinlib_pr3/1114", 36, 34],
		"ancre (survol)": ["skinlib_pr3/1111", 36, 34],
	}
	var presents := 0
	for nom in art:
		var f: Array = art[nom]
		var tex := SkinPR3.texture(str(f[0]))
		if tex == null:
			print("   %-24s absent" % nom)
			continue
		presents += 1
		print("   %-24s %d x %d" % [nom, tex.get_width(), tex.get_height()])
		if tex.get_width() != int(f[1]) or tex.get_height() != int(f[2]):
			_rater("%s fait %d x %d, attendu %d x %d : mauvais identifiant"
					% [nom, tex.get_width(), tex.get_height(), int(f[1]), int(f[2])])
	if presents == 0:
		print("   (aucun art PR3 ici : nos propres pavillons prennent le relais)")
	# Le Portugal n'a PAS de pavillon chez PR3 -- quatre nations seulement, plus le
	# pirate. Il garde le notre, et ce n'est pas un manque a signaler.
	print("   (le Portugal garde le notre : PR3 n'en livre pas)")

	# --- l'ecrasement des anneaux poses au sol --------------------------------
	#
	# CE CONTROLE EXISTE A CAUSE D'UNE PANNE QUI EST PASSEE AU VERT DEUX FOIS. Les
	# anneaux de selection doivent etre des ELLIPSES, ecrasees comme la carte. Ils
	# etaient des cercles, et le « correctif » multipliait le rayon vertical par
	# 0,9998 -- un cercle. Rien ne le disait : la compilation passait, les tests
	# aussi, et l'ecran ne changeait pas. C'est le joueur qui l'a vu.
	#
	# Un tel facteur ne se LIT pas, il se CALCULE. On le calcule donc ici, sur la
	# vraie fiche.
	print("")
	print("=== l'ecrasement des anneaux (ellipse, pas cercle) ===")
	var sc_carte := ResourceLoader.load("res://scripts/carte2d.gd") as GDScript
	if sc_carte == null or sc_carte.reload() != OK:
		_rater("carte2d.gd ne compile pas : l'ecrasement n'est pas verifiable")
	elif not proj.valide:
		print("   fiche absente : rien a mesurer")
	else:
		var k := proj.echelle()
		var f: float = sc_carte.call("_aplatissement", proj.angle, k)
		print("   fiche  : angle %.1f   echelle (%.6f ; %.6f)   rapport %.4f"
				% [proj.angle, k.x, k.y, k.y / k.x])
		print("   applique : %.4f" % f)
		if f > 0.9:
			_rater("aplatissement %.4f : l'anneau serait un cercle, pas une ellipse" % f)
		# La camera `seamap` de PR3 est a 35 deg (atan(280,083/400)), donc
		# sin = 0,5736. La fiche peinte etant zenithale, c'est ce qu'on doit
		# retrouver exactement.
		if proj.angle >= 89.0 and absf(f - 0.5736) > 0.01:
			_rater("fiche zenithale : %.4f obtenu, 0,5736 attendu (sin 35 deg)" % f)
		# Et un terrain CUIT, lui, a deja son obliquite dans la projection : on ne
		# doit pas lui ajouter celle du dessin par-dessus.
		var cuit: float = sc_carte.call("_aplatissement", 65.0, Vector2(0.2, 0.12))
		print("   terrain cuit (angle 65, rapport 0,60) : %.4f" % cuit)
		if absf(cuit - 0.6) > 0.001:
			_rater("terrain cuit : %.4f obtenu, 0,60 attendu (aucun facteur en plus)" % cuit)

	# --- l'ancre : le cycle entre les convois a quai --------------------------
	#
	# L'ancre du cartouche se clique et fait defiler les convois du port. La regle
	# est STATIQUE dans carte2d.gd pour etre exercable ici : monter toute la carte
	# pour verifier un bouclage serait absurde, et ne pas le verifier laisserait
	# passer le cas qui casse -- le DERNIER convoi, qui doit revenir au premier.
	# Ce cas ne se voit qu'avec plusieurs convois dans un meme port.
	print("")
	print("=== l'ancre : cycle entre les convois a quai ===")
	var sc := ResourceLoader.load("res://scripts/carte2d.gd") as GDScript
	if sc == null or sc.reload() != OK:
		_rater("carte2d.gd ne compile pas : le cycle n'est pas verifiable")
	else:
		var cas := [
			[[3], 3, 3, "un seul convoi : il reste"],
			[[1, 2, 3], 1, 2, "du premier au deuxieme"],
			[[1, 2, 3], 3, 1, "du DERNIER au premier (le bouclage)"],
			[[1, 2, 3], 9, 1, "selection hors du port : on entre par le premier"],
			[[], 1, -1, "aucun convoi : rien a selectionner"],
		]
		for c in cas:
			var attendu := int(c[2])
			var obtenu: int = sc.call("_convoi_suivant", c[0], int(c[1]))
			var bon := obtenu == attendu
			print("   %-44s %s + %s -> %d  %s" % [str(c[3]), str(c[0]), str(c[1]),
					obtenu, "OK" if bon else "*** ECART ***"])
			if not bon:
				_rater("cycle (%s) : %d attendu, %d obtenu" % [str(c[3]), attendu, obtenu])

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
