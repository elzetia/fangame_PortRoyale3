# Cuit la carte de l'archipel en une image haute résolution.
#
# Le rendu est une **plongée oblique**, pas une vue zénithale : le shader lance
# un rayon par pixel dans le champ d'altitude, ce qui donne de vraies silhouettes
# de montagnes, des faces sud visibles et des ombres portées. C'est la technique
# du « 3D pré-rendu » des jeux du début des années 2000, dont Port Royale.
#
# Le coût n'a aucune importance : il n'est payé qu'à la fabrication. En jeu, il
# ne restera qu'une texture à afficher.
class_name CuissonCarte
extends RefCounted

# Plus de décor peint au-delà de la zone jouable. Il y en a eu, et il n'a jamais
# rien apporté : au nord et à l'ouest, là où la terre touche le bord du monde,
# cette marge se voyait — d'abord comme une lamelle d'eau, puis, une fois le
# terrain prolongé, comme une bande étirée. La carte s'arrête maintenant où le
# monde s'arrête, ce qui est la seule limite qui ne demande pas d'explication.
const MARGE := 0.0
const ECHELLE_CASE := 12.0     # unités de monde par case du masque de PR3

# Plafond du relief, seulement pour cadrer la projection. Il ne sert qu'au BORD
# NORD : en plongée oblique, une montagne posée là dépasse vers le haut de
# l'image, et il lui faut ce dégagement. Partout ailleurs la profondeur du
# terrain s'en charge. Or le nord de la carte est de l'arrière-pays, plafonné
# bas — d'où 130 et non 340, qui réservait du ciel vide.
const ALTITUDE_MAX := 130.0
const ALTITUDE_MIN := -190.0

# Bande du NORD que l'on ne peint pas, en unités de monde. Au-dessus de
# Charleston — le port le plus septentrional, et l'utilisateur l'a descendu
# exprès — il n'y a plus que de l'arrière-pays sombre : autant ne pas le cuire.
# La fiche de projection porte le décalage, donc la simulation n'en sait rien et
# n'a pas à en savoir.
const NORD_COUPE := 400.0
const TUILES := 4              # découpage du rendu, en TUILES x TUILES


static func cuire(hote: Node, sim: Sim, chemin: String, largeur_px := 4096,
				  angle_vue := 65.0, palmiers := true) -> Dictionary:
	var limites := sim.limites()
	var zone := Vector2((limites.x + MARGE) * 2.0,
				   (limites.y + MARGE) * 2.0 - NORD_COUPE)
	# On recentre vers le sud de la moitié de ce qu'on a retiré au nord.
	var centre := Vector2(0.0, NORD_COUPE * 0.5)

	# Étendue du plan de projection. En oblique, la hauteur à l'écran combine
	# la profondeur nord-sud et l'altitude du relief.
	var th := deg_to_rad(angle_vue)
	var v_haut := ALTITUDE_MAX * cos(th) + zone.y * 0.5 * sin(th)
	var v_bas := ALTITUDE_MIN * cos(th) - zone.y * 0.5 * sin(th)
	var vue_taille := Vector2(zone.x, maxf(v_haut, -v_bas) * 2.0)

	var hauteur_px := int(round(largeur_px * vue_taille.y / vue_taille.x))
	# Chaque tuile doit tomber juste : on arrondit sur un multiple de TUILES
	largeur_px = int(ceil(largeur_px / float(TUILES))) * TUILES
	hauteur_px = int(ceil(hauteur_px / float(TUILES))) * TUILES

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/cuisson_carte.gdshader")
	mat.set_shader_parameter("angle_vue", angle_vue)
	mat.set_shader_parameter("vue_centre", centre)
	mat.set_shader_parameter("vue_taille", vue_taille)
	_envoyer_champ(mat, sim)

	var tuile_px := Vector2i(largeur_px / TUILES, hauteur_px / TUILES)

	var vp := SubViewport.new()
	vp.size = tuile_px
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	vp.disable_3d = true

	var rect := ColorRect.new()
	rect.material = mat
	rect.size = Vector2(tuile_px)
	vp.add_child(rect)
	hote.add_child(vp)

	var debut := Time.get_ticks_msec()

	# Passe couleur, puis passe densite de vegetation : la meme scene rendue
	# deux fois, avec un uniforme qui change ce que le shader ecrit.
	mat.set_shader_parameter("mode_densite", 0)
	var finale := await _rendre(vp, mat, largeur_px, hauteur_px, tuile_px)

	if palmiers:
		# Un passage donne trois masques (un par canal), un second les recifs.
		mat.set_shader_parameter("mode_densite", 1)
		var masque: Image = await _rendre(vp, mat, largeur_px, hauteur_px, tuile_px)
		mat.set_shader_parameter("mode_densite", 2)
		var masque_mer: Image = await _rendre(vp, mat, largeur_px, hauteur_px, tuile_px)
		# Une passe a part pour les sapins : les trois canaux du premier masque
		# sont deja pris par les palmiers, les bosquets et les massifs.
		mat.set_shader_parameter("mode_densite", 4)
		var masque_sapins: Image = await _rendre(vp, mat, largeur_px, hauteur_px, tuile_px)

		# On rassemble les quatre familles AVANT de dessiner, puis on trie le
		# tout du nord au sud. Trier famille par famille laissait la jungle,
		# dessinee apres, recouvrir entierement les massifs.
		# Clairieres : un village a defriche autour de lui. Sans ca, un
		# palmier plante au milieu des toits, et rien ne le rattrape ensuite —
		# le decor est cuit. L'emprise vient de scripts/villes.gd, le meme
		# calcul que celui qui dessine la vignette en jeu.
		var clairieres := _clairieres(sim, centre, vue_taille, largeur_px, hauteur_px, angle_vue)
		print("[cuisson]   %d clairieres de village reservees" % clairieres.size())

		# Ce qui vit dans l'eau n'a pas de test d'emprise : ces sprites sont
		# FAITS pour y etre. Tout ce qui pousse doit poser son pied sur la
		# terre ferme.
		var familles := [
			# LES DENSITÉS SUIVENT LA RÉFÉRENCE FOURNIE : une côte y est peuplée
			# PARTOUT — cocoteraies serrées, bosquets sombres, cailloux dans les
			# hauts-fonds — et les rochers y sont NOMBREUX ET PETITS, jamais les
			# gros massifs isolés qu'on avait. D'où deux réglages de front sur les
			# montagnes : trois fois plus, et deux fois plus petites.
			_placer(masque_mer, 2, "res://sprites/ecueils/", "ecueils", 0.50, 120, 0.34, 4001, null, clairieres),
			_placer(masque, 2, "res://sprites/montagnes/", "montagnes", 0.40, 54, 0.12, 4002, masque_mer, clairieres),
			_placer(masque, 1, "res://sprites/bosquets/", "bosquets", 0.24, 30, 0.16, 4003, masque_mer, clairieres),
			# Les sapins sont plus petits que les palmiers : ils sont plus haut, donc
			# plus loin, et ils ne doivent pas leur voler la vedette sur la cote.
			_placer(masque_sapins, 0, "res://sprites/sapins/", "sapins", 0.0, 21, 0.16, 4004, masque_mer, clairieres, 24),
			_placer(masque, 0, "res://sprites/palmiers/", "palmiers", 0.0, 17, 0.12, 20260910, masque_mer, clairieres),
		]
		var tout: Array = []
		for f in familles:
			tout.append_array(f["places"])
			print("[cuisson]   %-10s : %d" % [f["nom"], f["places"].size()])
		tout.sort_custom(func(a, b): return a[1] < b[1])
		for pl in tout:
			var img: Image = pl[2]
			var anc: Vector2i = pl[3]
			finale.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()),
							  Vector2i(pl[0], pl[1]) - anc)
		print("[cuisson] %d elements de terrain semes" % tout.size())

	# Fiche de mer, pour la nappe animee du jeu : ou est l'eau, et sa
	# profondeur. Le quart de resolution suffit — c'est une donnee lisse, et
	# elle est echantillonnee en lineaire.
	mat.set_shader_parameter("mode_densite", 3)
	var mer: Image = await _rendre(vp, mat, largeur_px, hauteur_px, tuile_px)
	mer.resize(largeur_px / 4, hauteur_px / 4, Image.INTERPOLATE_LANCZOS)
	mer.save_png(chemin.get_basename() + "_mer.png")

	var duree := Time.get_ticks_msec() - debut
	var err := finale.save_png(chemin)
	vp.queue_free()

	# Fiche de projection, à côté de l'image. Le jeu la lit pour placer navires
	# et ports : ces chiffres ne doivent surtout pas être recopiés à la main
	# des deux côtés, sinon le décor et la simulation finissent par diverger.
	var fiche := {
		"angle": angle_vue,
		"centre": [centre.x, centre.y],
		"vue_taille": [vue_taille.x, vue_taille.y],
		"pixels": [largeur_px, hauteur_px],
	}
	var f := FileAccess.open(chemin.get_basename() + ".json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(fiche, "\t"))
		f.close()

	return {
		"ok": err == OK,
		"erreur": err,
		"pixels": Vector2i(largeur_px, hauteur_px),
		"angle": angle_vue,
		"secondes": duree / 1000.0,
		"metres_par_pixel": vue_taille.x / float(largeur_px),
	}


# Les tableaux d'uniformes ont une taille fixe côté shader : on remplit le
# reste avec des îles d'amplitude nulle, sans effet.
# Le terrain vient d'une TEXTURE, plus de paramètres d'îles.
#
# `carte_champ.png` porte, par case du masque de Port Royale 3, la distance à la
# côte vers l'intérieur (rouge) et vers le large (vert), plus l'amplitude de son
# relief (bleu). Elle est fabriquée par `outils/champ_cote.py` depuis le masque
# qui fait aussi loi pour la navigation : la côte peinte et la côte jouable ne
# peuvent donc pas diverger.
#
# Les réglages d'échelle suivent le monde. Il est passé de trois mille unités de
# large à près de seize mille : une fréquence de bruit ou un espacement de
# palmiers laissés tels quels donneraient cinq fois trop de détail, et la carte
# ressemblerait à du grain.
static func _envoyer_champ(mat: ShaderMaterial, sim: Sim) -> void:
	var champ := load("res://carte_champ.png") as Texture2D
	if champ == null:
		push_error("carte_champ.png absent : lance d'abord outils/champ_cote.py")
		return
	var limites := sim.limites()
	mat.set_shader_parameter("champ_cote", champ)
	# La carte des biomes : aridité et conifères, posée par le même outil.
	var bio := load("res://carte_biome.png") as Texture2D
	if bio == null:
		push_error("carte_biome.png absent : lance d'abord outils/champ_cote.py")
	else:
		mat.set_shader_parameter("champ_biome", bio)
	var rel := load("res://carte_relief.png") as Texture2D
	if rel == null:
		push_error("carte_relief.png absent : lance d'abord outils/champ_cote.py")
	else:
		mat.set_shader_parameter("champ_relief", rel)
	mat.set_shader_parameter("champ_origine", Vector2(-limites.x, -limites.y))
	mat.set_shader_parameter("champ_taille", Vector2(limites.x, limites.y) * 2.0)
	mat.set_shader_parameter("champ_unite", ECHELLE_CASE)

	mat.set_shader_parameter("sommet", 260.0)
	mat.set_shader_parameter("portee_mont", 620.0)
	mat.set_shader_parameter("largeur_plage", 45.0)
	mat.set_shader_parameter("largeur_lagon", 300.0)

	# Les crêtes sont ADOUCIES. A 0,40 -- le réglage de l'archipel procédural --
	# le bruit taillait assez de faces raides pour que la roche nue perce en
	# échine continue sur toute la longueur de Cuba. Sur la référence, un massif
	# est un piton compact à silhouette nette, pas une sierra : c'est le sprite
	# de montagne qui doit le dire, pas le terrain.
	mat.set_shader_parameter("relief_force", 0.20)

	# Tout ce qui se compte en unités de monde suit le changement d'échelle.
	mat.set_shader_parameter("relief_echelle", 0.0014)
	mat.set_shader_parameter("taille_arbre", 185.0)
	mat.set_shader_parameter("hauteur_palmier", 105.0)
	mat.set_shader_parameter("taille_sous_bois", 32.0)
	mat.set_shader_parameter("houle_frequence", 0.0085)


# Rend la scene par tuiles et recompose l'image. Une seule passe plein cadre
# depasserait le delai de garde du pilote graphique.
static func _rendre(vp: SubViewport, mat: ShaderMaterial, largeur: int,
					hauteur: int, tuile: Vector2i) -> Image:
	var image := Image.create(largeur, hauteur, false, Image.FORMAT_RGBA8)
	for ty in TUILES:
		for tx in TUILES:
			mat.set_shader_parameter("tuile_min",
				Vector2(float(tx) / TUILES, float(ty) / TUILES))
			mat.set_shader_parameter("tuile_taille",
				Vector2(1.0 / TUILES, 1.0 / TUILES))
			# Deux images : la premiere applique les uniformes, la seconde rend.
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var morceau := vp.get_texture().get_image()
			if morceau.get_format() != image.get_format():
				morceau.convert(image.get_format())
			image.blit_rect(morceau, Rect2i(Vector2i.ZERO, tuile),
							Vector2i(tx * tuile.x, ty * tuile.y))
	return image


const PALMIER_HAUTEUR := 34        # hauteur voulue pour un palmier, en pixels


# Seme une famille de sprites la ou le masque l'autorise.
#
# `canal` choisit la composante du masque (0 = rouge, 1 = vert, 2 = bleu) :
# une seule passe de rendu porte ainsi trois masques a la fois.
# `facteur` met les sprites a l'echelle ; a 0, on les ramene tous a
# PALMIER_HAUTEUR, ce qui convient aux palmiers mais pas aux massifs, dont la
# variete de taille EST l'interet.
# Rectangle interdit autour de chaque village, en pixels de carte.
#
# La marge est proportionnelle a la vignette : une eglise a deux clochers merite
# plus de degagement qu'un hameau de quatre cases.
static func _clairieres(sim: Sim, centre: Vector2, vue_taille: Vector2, largeur_px: int,
						hauteur_px: int, angle_vue: float) -> Array:
	var proj := ProjectionCarte.new()
	proj.definir(angle_vue, centre, vue_taille,
				 Vector2i(largeur_px, hauteur_px))
	var villes := Villes.new()
	var sortie: Array = []
	if villes.vide():
		return sortie
	for port in sim.ports():
		var e: Rect2 = villes.emprise(proj, port)
		if e.size.x <= 0.0 or e.size.y <= 0.0:
			continue
		sortie.append(e.grow(maxf(e.size.x, e.size.y) * 0.16))
	return sortie


static func _placer(masque: Image, canal: int, dossier: String,
					nom: String, facteur: float, espacement: int,
					seuil: float, graine: int, terre: Image,
					clairieres: Array = [], hauteur_px := PALMIER_HAUTEUR) -> Dictionary:
	var vide := {"nom": nom, "places": []}
	var fiche_chemin := dossier + nom + ".json"
	if not FileAccess.file_exists(fiche_chemin):
		push_warning("sprites absents : " + fiche_chemin)
		return vide
	var d = JSON.parse_string(FileAccess.get_file_as_string(fiche_chemin))
	if typeof(d) != TYPE_DICTIONARY:
		return vide

	# Plusieurs calibres par variante. Un bois dont tous les arbres font
	# exactement la meme hauteur se lit comme un motif imprime : c'est l'ecart
	# de taille entre voisins qui donne l'echelle et la profondeur. Les massifs
	# et les recifs, eux, arrivent deja avec leur propre variete de tailles.
	var calibres: Array = [0.78, 0.92, 1.06, 1.22] if facteur <= 0.0 else [1.0]

	# Chaque variante est redimensionnee une fois, pas a chaque plantation.
	var images: Array[Image] = []
	var ancres: Array[Vector2i] = []
	for sp in d.get("sprites", []):
		var tex: Texture2D = load(dossier + str(sp["fichier"]))
		if tex == null:
			continue
		var source := tex.get_image()
		source.convert(Image.FORMAT_RGBA8)
		var base := facteur
		if facteur <= 0.0:
			base = float(hauteur_px) / float(source.get_height())
		for cal in calibres:
			var ech: float = base * float(cal)
			var img := source.duplicate() as Image
			if absf(ech - 1.0) > 0.01:
				img.resize(maxi(1, int(img.get_width() * ech)),
						   maxi(1, int(img.get_height() * ech)),
						   Image.INTERPOLATE_LANCZOS)
			images.append(img)
			var a: Array = sp["ancrage"]
			ancres.append(Vector2i(int(a[0] * ech), int(a[1] * ech)))
	if images.is_empty():
		return vide

	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var places: Array = []
	var w := masque.get_width()
	var h := masque.get_height()
	var gigue: int = maxi(1, espacement / 2)

	var y := 0
	while y < h:
		var x := 0
		while x < w:
			var px := x + rng.randi_range(-gigue, gigue)
			var py := y + rng.randi_range(-gigue, gigue)
			if px >= 0 and py >= 0 and px < w and py < h:
				var c := masque.get_pixel(px, py)
				var dens: float = [c.r, c.g, c.b][canal]
				if dens > seuil and rng.randf() < dens:
					var k := rng.randi() % images.size()
					var coin := Vector2i(px, py) - ancres[k]
					var cadre := Rect2(Vector2(coin), Vector2(images[k].get_size()))
					var libre := true
					for cl in clairieres:
						if (cl as Rect2).intersects(cadre):
							libre = false
							break
					if libre and (terre == null or _pied_sur_terre(terre, images[k], coin)):
						places.append([px, py, images[k], ancres[k]])
			x += espacement
		y += espacement

	return {"nom": nom, "places": places}


# Le PIED d'un sprite doit tenir sur la terre ferme.
#
# Tester le seul point d'ancrage ne suffit pas : un amas large accroche au
# rivage garde son ancre sur le sable et etale la moitie de son feuillage sur
# la mer. On regarde donc la bande basse de l'image — celle qui touche le sol —
# sur toute sa largeur, et uniquement la ou le sprite est opaque.
#
# La couronne, elle, a le droit de deborder vers le haut : en plongee oblique,
# le haut de l'ecran c'est le nord ET l'altitude, et un arbre du rivage nord
# masque legitimement l'eau qui se trouve derriere lui.
const PIED_PART := 0.34            # part basse de l'image consideree comme pied
const PIED_TOLERANCE := 0.88       # part de ce pied qui doit etre sur la terre


static func _pied_sur_terre(terre: Image, img: Image, coin: Vector2i) -> bool:
	var iw := img.get_width()
	var ih := img.get_height()
	var tw := terre.get_width()
	var th := terre.get_height()
	var y0 := int(ih * (1.0 - PIED_PART))
	var pas: int = maxi(1, maxi(iw, ih - y0) / 10)

	var pleins := 0
	var fermes := 0
	var y := y0
	while y < ih:
		var x := 0
		while x < iw:
			if img.get_pixel(x, y).a > 0.55:
				pleins += 1
				var gx := coin.x + x
				var gy := coin.y + y
				if gx >= 0 and gy >= 0 and gx < tw and gy < th 						and terre.get_pixel(gx, gy).g > 0.5:
					fermes += 1
			x += pas
		y += pas

	if pleins == 0:
		return false
	return float(fermes) / float(pleins) >= PIED_TOLERANCE
