# Le menu radial d'une ville se bâtit-il vraiment, et avec les mots du jeu ?
#
# POURQUOI CE TEST. `test_compilation.gd` prouve que le script se COMPILE ;
# `test_ecran.gd` ne l'instancie jamais. Entre les deux, tout le menu pouvait être
# réécrit sans qu'une seule ligne ne s'exécute — et il vient de l'être en entier.
# Un `null` dans la construction, un pétale qui disparaît, un libellé vide : rien
# de tout cela n'apparaît à la compilation.
#
# ON ATTEND UNE IMAGE AVANT D'OUVRIR. Dans `_init`, la fenêtre racine n'est pas
# encore montée et `get_viewport()` rend `null` : le menu ne peut pas savoir où
# sont les bords de l'écran. Le jeu, lui, ajoute la couronne au démarrage et ne
# l'ouvre qu'au clic, bien plus tard. Le test se place donc dans les mêmes
# conditions — plutôt que d'obliger le menu à se replier sur une taille inventée
# pour un cas qui n'arrive jamais en jouant.
#
# CE QU'ON EXIGE :
#   1. HUIT pétales, pas sept — la couronne de PR3 en a huit, et la version
#      précédente n'en comptait que sept faute d'avoir lu la table des textes.
#   2. Les libellés viennent de la table de PR3 quand elle est là.
#   3. Les DROITS : sans convoi au port, seul « Info ville » est accessible ;
#      avec un convoi, les docks et la capitainerie s'ouvrent, et le chantier
#      seulement si la ville en a un.
#
# Lance : godot --headless --path . --script outils/test_radial.gd
extends SceneTree

# Les huit libellés attendus, dans l'ordre de la couronne. Ce sont les textes de
# PR3 (`ID_ACTION_RADIAL_DIR_*`) ; sans la table, le repli du code donne les mêmes.
const ATTENDUS := ["Info ville", "Docks", "Chantier naval", "Taverne",
	"Eglise", "Hôtel de ville", "Capitainerie", "Entrepôt"]

var _ecarts := 0


func _rater(quoi: String) -> void:
	_ecarts += 1
	print("  ÉCART  ", quoi)


# Tous les nœuds sous `n`, à plat.
func _tous(n: Node) -> Array:
	var sortie: Array = []
	var pile: Array = [n]
	while not pile.is_empty():
		var noeud: Node = pile.pop_back()
		for e in noeud.get_children():
			sortie.append(e)
			pile.append(e)
	return sortie


func _boutons(radial: RadialVille) -> Array:
	var sortie: Array = []
	for e in _tous(radial):
		if e is Button:
			sortie.append(e)
	return sortie


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
	# Une ville AVEC chantier : c'est le seul cas où les quatre pétales branchés
	# sont tous accessibles, donc le seul qui les exerce tous.
	var port: Dictionary = ports[0]
	for p in ports:
		if bool((p as Dictionary).get("chantier", false)):
			port = p
			break
	print("ville d'essai : %s (chantier : %s, taille %s, nation %s)" % [
			port.get("nom", "?"), port.get("chantier"), port.get("taille"),
			port.get("nation_cle", "?")])

	var radial := RadialVille.new()
	root.add_child(radial)

	print("")
	print("=== 1. AVEC UN CONVOI AU PORT ===")
	radial.ouvrir(port, Vector2(700, 450), true, sim)
	var b := _boutons(radial)
	print("  pétales bâtis : %d" % b.size())
	if b.size() != 8:
		_rater("%d pétale(s) au lieu des 8 de la couronne de PR3" % b.size())

	# LE LIBELLE EST DANS L'INFOBULLE, plus dans le texte du bouton : PR3 ne met
	# pas de mot sur ses petales, c'est le BATIMENT qui dit lequel c'est. Le
	# controle n'a pas disparu pour autant -- il a suivi le libelle.
	var libelles: Array = []
	var ouverts: Array = []
	for e in b:
		var bo: Button = e
		libelles.append(bo.tooltip_text)
		if not bo.disabled:
			ouverts.append(bo.tooltip_text)
		if bo.tooltip_text.strip_edges() == "":
			_rater("un pétale sans libellé")
	print("  libellés : ", ", ".join(PackedStringArray(libelles)))
	for a in ATTENDUS:
		if not libelles.has(a):
			_rater("pétale manquant ou mal nommé : « %s »" % a)
	print("  accessibles : ", ", ".join(PackedStringArray(ouverts)))
	# Avec un convoi et un chantier : ville, docks, chantier, capitainerie.
	if ouverts.size() != 4:
		_rater("%d pétale(s) accessible(s), 4 attendus avec convoi et chantier"
				% ouverts.size())

	print("")
	print("=== 2. SANS CONVOI AU PORT ===")
	# PR3 n'ouvre le port qu'à qui s'y présente avec un navire : seule la fiche de
	# la ville reste consultable.
	radial.ouvrir(port, Vector2(700, 450), false, sim)
	var ouverts2: Array = []
	for e in _boutons(radial):
		var bo: Button = e
		if not bo.disabled:
			# LE LIBELLE EST DANS L'INFOBULLE, ici aussi. Cette ligne lisait encore
			# `bo.text` alors que la section 1 avait migre : elle rendait donc une
			# chaine VIDE, et le controle passait quand meme puisqu'il ne comptait
			# que les entrees. Une chaine vide compte pour une.
			ouverts2.append(bo.tooltip_text)
	print("  accessibles : ", ouverts2 if not ouverts2.is_empty() else "aucun")
	if ouverts2.size() != 1:
		_rater("%d pétale(s) accessible(s) sans convoi, 1 attendu" % ouverts2.size())
	# ET ON REGARDE LAQUELLE. Compter ne suffit pas : c'est precisement ce qui a
	# laisse passer une infobulle vide comptee comme une entree valide.
	elif String(ouverts2[0]) != "Info ville":
		_rater("sans convoi, le pétale accessible est « %s », « Info ville » attendu"
				% String(ouverts2[0]))

	print("")
	print("=== 3. L'ART DU JEU ===")
	# Sous droits, dans `reference_pr3/` ignoré par git : son absence n'est pas une
	# faute, le menu retombe sur son tracé. On dit seulement ce qui est là.
	var art := {
		"anneau de sélection": "ingame_radial_town/8",
		"disque désactivé": "ingame_radial_town/4",
		"illustration de ville": "ingame_radial_town/18",
		"loupe « Sélectionner »": "ingame_radial_town/33",
		"pavillon d'Espagne": "skinlib_pr3/1568",
		"icône habitants": "skinlib_pr3/1798",
		"marqueur de réputation": "skinlib_pr3/1936",
	}
	var manquants := 0
	for nom in art:
		if SkinPR3.texture(String(art[nom])) == null:
			manquants += 1
			print("  %-24s absent" % nom)
		else:
			print("  %-24s chargé" % nom)
	if manquants == art.size():
		print("  (aucun art PR3 sur ce poste — le menu reste jouable en repli)")

	# LES BATIMENTS DES PETALES, rendus depuis les modeles 3D du jeu par
	# `outils/extraire_batiments_pr3.py`.
	#
	# CE CONTROLE COMBLE UNE PANNE MUETTE : `_batiment()` sort sans rien dire
	# quand la texture est introuvable, donc un nom mal orthographie donnerait des
	# petales NUS sans qu'aucune erreur ne paraisse. Les pavillons, les ancres et
	# la barre a roue sont deja controles par leur taille ; ceux-ci ne l'etaient
	# pas.
	#
	# 142 px est la taille de rendu de l'outil : une autre valeur voudrait dire
	# qu'on regarde une vignette produite autrement.
	# LA LISTE VIENT DU CODE, pas d'une copie à la main. `RadialVille` dit lui-même
	# quels bâtiments il pose, et les trois illisibles — taverne, entrepôt,
	# chantier — n'y sont plus : ils gardent leur libellé. Une liste recopiée ici
	# mentirait deux fois. Elle resterait verte si un nom disparaissait du menu, et
	# elle virerait au rouge le jour où l'on effacerait un rendu devenu inutile.
	#
	# LES QUATRE NATIONS, pas seulement l'Espagne : l'église et l'hôtel de ville
	# prennent le suffixe du port. Un `church0_fr` manquant ne se verrait que dans
	# une ville française, donc jamais ici tant qu'on ne contrôlait que `_sp`.
	var batis: Array = []
	for cle_b in RadialVille.BATIMENTS:
		batis.append(String(RadialVille.BATIMENTS[cle_b]))
	for cle_b in RadialVille.BATIMENTS_NATION:
		for suffixe in RadialVille.SUFFIXE_NATION.values():
			var nom_n := String(RadialVille.BATIMENTS_NATION[cle_b]) + String(suffixe)
			if not batis.has(nom_n):
				batis.append(nom_n)
	var batis_absents := 0
	for nom_b in batis:
		var tb := SkinPR3.texture("batiments/" + String(nom_b))
		if tb == null:
			batis_absents += 1
			print("  batiment %-22s absent" % String(nom_b))
			continue
		if tb.get_width() != 142 or tb.get_height() != 142:
			_rater("batiment %s fait %d x %d, attendu 142 x 142"
					% [String(nom_b), tb.get_width(), tb.get_height()])
	print("  batiments : %d sur %d" % [batis.size() - batis_absents, batis.size()])
	# Tous absents = poste sans l'art, c'est le repli normal. QUELQUES-UNS
	# absents = l'extraction est incomplete, et la des petales seraient nus.
	if batis_absents > 0 and batis_absents < batis.size():
		_rater("%d batiment(s) manquant(s) sur %d : extraction incomplete"
				% [batis_absents, batis.size()])

	# LA BARRE A ROUE du centre, et son OMBRE. Deux entrees ANONYMES de
	# `skinlib_pr3` -- des identifiants nus, sans classe `Visual_*` -- ce qui les a
	# rendues invisibles a un inventaire par nom pendant toute la reprise du menu.
	#
	# Leurs TAILLES sont le controle utile : 196 x 196 et 210 x 210. Une autre
	# dimension voudrait dire qu'on est tombe sur une image voisine, l'erreur que
	# j'ai deja faite plusieurs fois ici.
	for nom_roue in [["barre a roue", "skinlib_pr3/301", 196, 196],
			["ombre de la barre", "skinlib_pr3/298", 210, 210]]:
		var t := SkinPR3.texture(String(nom_roue[1]))
		if t == null:
			print("  %-22s absente -> la couronne s'en passe" % String(nom_roue[0]))
			continue
		print("  %-22s %d x %d" % [String(nom_roue[0]), t.get_width(), t.get_height()])
		if t.get_width() != int(nom_roue[2]) or t.get_height() != int(nom_roue[3]):
			_rater("%s fait %d x %d, attendu %d x %d" % [String(nom_roue[0]),
					t.get_width(), t.get_height(), int(nom_roue[2]), int(nom_roue[3])])

	# Et les images posées : avec l'art présent, la couronne doit en porter.
	radial.ouvrir(port, Vector2(700, 450), true, sim)
	var images := 0
	for e in _tous(radial):
		if e is TextureRect and (e as TextureRect).texture != null:
			images += 1
	print("  images posées dans la couronne : %d" % images)
	if manquants == 0 and images == 0:
		_rater("l'art est là mais la couronne n'en pose aucune image")

	print("")
	if _ecarts == 0:
		print("=== LA COURONNE DE PR3 SE BÂTIT. ===")
	else:
		print("=== %d ÉCART(S). ===" % _ecarts)
	quit(0 if _ecarts == 0 else 1)
