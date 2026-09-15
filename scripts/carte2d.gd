# La carte de jeu : l'image cuite, et tout ce qui se pose dessus.
#
# Depuis que la carte est un rendu cuit en plongée oblique, la scène n'a plus
# besoin d'être en 3D. Elle affiche une image, et projette dessus les positions
# que lui donne la simulation Lua. C'est l'architecture de Port Royale 3 —
# et elle est bien plus légère que le terrain 3D qu'elle remplace.
extends Node2D

const CHEMIN_CARTE := "res://carte_cuite.png"
const CHEMIN_FICHE := "res://carte_cuite.json"
const CHEMIN_MER := "res://carte_cuite_mer.png"
const RAYON_CLIC_PORT := 90.0        # en mètres monde
const MARGE_CLIC := 8.0              # en pixels de carte, autour du dessin

# L'ANNEAU DE SÉLECTION DU JEU, et non un disque de mon cru.
#
# Port Royale 3 le pose en `selectioncircle` : le registre d'entités de la carte
# maritime (`0x460d11`) nomme `SelectionConvoyMap` pour un convoi et
# `SelectionConvoyTown` pour une ville, et l'archive livre deux anneaux de
# 256 x 256 — `selectioncircle0` (trait FIN) et `selectioncircle1` (trait ÉPAIS).
#
# CE QUE JE N'AI PAS PU ÉTABLIR : lequel des deux revient à la ville. Leurs
# descripteurs `.asset` sont identiques à leur nom près, et leurs maillages le
# sont au octet près (215 / 1104 / 416) — la taille est appliquée à l'exécution,
# elle n'est pas dans l'art, donc le rapport 16:11 des rayons de sélection ne
# permet pas de les départager non plus. Il se peut d'ailleurs que la distinction
# ne soit pas ville/convoi mais SURVOL/SÉLECTION, ce que l'écart d'épaisseur
# suggère davantage. L'appariement vit dans l'exécutable.
#
# On prend donc le trait fin pour le survol d'une ville, et c'est un choix, pas
# un relevé. L'art est sous droits (© Kalypso / Gaming Minds) : il vit dans
# `reference_pr3/`, ignoré par git, et s'extrait de ta copie du jeu.
const ANNEAU_SELECTION := "res://reference_pr3/assets/selectioncircle0.png"

# LES ICÔNES D'ÉTAT DE VILLE, prises dans le jeu.
#
# Ce que la carte montrait avant sous le nom d'un port — la marchandise qui lui
# manque le plus — était une INVENTION du projet. Port Royale 3 y affiche les
# états de la ville : les fléaux qui la frappent.
#
# Relevé dans la table d'icônes du jeu (`reference_pr3/ui/agencement/icones.txt`),
# et les deux images ont été regardées, pas seulement leur nom :
#   Visual_IconButton_Plague  1743  34x34   la peste
#   Visual_IconButton_Fire    1838  42x42   l'incendie
#
# PRUDENCE ACQUISE : une piste voisine, `icon_InTownEvent_01..19`, ressemblait à
# une numérotation des catastrophes. Elle n'en est pas une — 1852 est un tas de
# rondins, 1849 un badge « 100 % ». Seules les entrées NOMMÉES sont fiables.
#
# DEUX TROUS, et je les comble avec des génériques du jeu plutôt que de faire
# passer une icône pour ce qu'elle n'est pas — la table ne contient ni criquets
# ni famine :
#   sauterelles -> Visual_IconButton_Events (1456), le parchemin d'événement ;
#   famine      -> Visual_IconButton_Attention_Red (1917), le badge « ! ».
# Ce sont des CHOIX, pas des relevés. `Drought_Protection` (1866) existe mais
# c'est la PROTECTION contre la sécheresse, et notre simulation n'a pas ce
# fléau : on ne le détourne pas.
const ICONES_ETAT := {
	"peste": "skinlib_pr3/1743",
	"feu": "skinlib_pr3/1838",
	"sauterelles": "skinlib_pr3/1456",
	"famine": "skinlib_pr3/1917",
}

# Le repli dessiné, quand `reference_pr3/` n'est pas là — dépôt public, autre
# poste. Le LOOK dépend de l'art, jamais ce que le joueur peut savoir : une pastille
# de couleur dit encore « cette ville va mal », et laquelle.
const COULEURS_ETAT := {
	"peste": Color(0.62, 0.78, 0.35),
	"feu": Color(0.95, 0.55, 0.16),
	"sauterelles": Color(0.72, 0.60, 0.30),
	"famine": Color(0.86, 0.22, 0.20),
}

var sim: Sim
var proj: ProjectionCarte
var navire := NavireEtat.new()
var ports: Array = []

var _carte: Sprite2D
var _mer: Sprite2D
# Quelle mer est posée : l'ancienne nappe animée, ou celle qui suit la recette
# de Port Royale 3 (`--eau-pr3` au lancement, F3 en jeu pour comparer).
var _mer_pr3 := false
var _nuages: ColorRect
var _cam: Camera2D
var _zoom := 0.55
var _zoom_min := 0.1
var _zoom_max := 2.0
var _vitesse_cam := Vector2.ZERO
var _port_survole: Dictionary = {}
var _police: Font
var _plaque: StyleBoxFlat
# L'état de chaque ville — fléau en cours, famine. Rafraîchi PAR INTERVALLE et
# non par image : le pont fait le tour des soixante ports et chacun coûte un
# calcul de démographie, alors que l'état ne bouge pas d'une trame à l'autre.
var _etats: Dictionary = {}
var _etats_delai := 0.0
# Largeur de plaque par taille de police : le nom le plus long de la carte.
var _largeurs: Dictionary = {}
# Une ville est un objet posé sur le terrain : elle grandit avec le zoom, à la
# différence du pavillon et de l'étiquette, qui restent lisibles à taille fixe.
# Chargement, stades et emprise vivent dans scripts/villes.gd, que la cuisson
# relit pour réserver la clairière autour de chaque village.
var _villes: Villes


# HUD
var _hud_planche: HudPR3
var _hud_droite: HudDroitePR3
# La carte à cinq onglets que PR3 ouvre sous la planche droite quand un convoi
# est sélectionné.
var _vignette: ConvoiVignettePR3
var _lbl_statut: Label
var _lbl_cargaison: Label
var _lbl_message: Label

const MARGE_FICHE := Vector2(12, 10)
# Les planches du HUD sont posées à LEUR taille, celle de PR3 : 210x66 pour
# celle de gauche, 207x275 pour la minimap. Elles étaient d'abord grossies x1,6
# pour la lisibilité, mais la planche droite mangeait alors 68 % de la hauteur
# d'écran contre 36 % dans le vrai jeu. La fidélité tranche.
const ECHELLE_HUD := 1.0
const MARGE_HUD := Vector2(8, 6)

var _glisse := false
var _clic_depart := Vector2.ZERO
var _a_glisse := false
var _glisse_bouton := 0        # quel bouton mène le glissé (seul le milieu panoramique)

# La barre d'espace a deux sens selon la durée : un appui bref bascule la pause,
# un appui tenu passe en x10 le temps qu'on le tient. On ne peut donc pas
# décider à l'enfoncement — il faut attendre de voir si la touche est relâchée
# avant le seuil.
const SEUIL_SURVOL := 0.28
var _espace_tenu := -1.0
var _survol := false

# Mode d'édition : F2. Permet de faire glisser les villes sur la carte et de
# réécrire sim/archipel.lua avec les positions obtenues.
var _mode_edition := false
var _port_saisi: Dictionary = {}
var _saisie_image := false      # on déplace l'image, pas le point réel
var _charge := false         # le démarrage est-il terminé ?
var _tex_ombre: ImageTexture
var _rects_villes := {}         # rectangle dessiné de chaque village, pour le saisir
var _sceaux := {}               # couronne et bague, chargées une fois
var _atlas_nav: Texture2D       # les trente-deux caps du navire
var _message := ""
var _message_fin := 0.0

# Le comptoir, ouvert quand le navire est a quai.
var _comptoir: MarchePanneau
var _infos_ville: VillePR3
var _routes: RoutesPanneau
var _chantier: ChantierPR3
var _radial: RadialVille
var _capitainerie: CapitaineriePanneau
var _convoy_town: ConvoyTownPanneau

# Les cinq marchands des nations, relus à chaque image : ils bougent tout
# seuls, y compris pendant que le joueur regarde ailleurs.
var _marchands: Array = []

# Les convois du JOUEUR, relus à chaque image : on les dessine, on en sélectionne
# un (clic gauche), et on l'envoie à un port (clic droit) s'il est manuel.
var _convois_joueur: Array = []
var _convoi_selectionne := 1      # convoi PRIMAIRE (fiche, comptoir, caméra)
# PR3 NE SÉLECTIONNE QU'UN CONVOI À LA FOIS sur la carte maritime (`SeaMapComponent`,
# marqueur `SelectionConvoyMap`). Il n'y a donc pas d'ensemble sélectionné : le
# convoi commandé est `_convoi_selectionne`, et lui seul.
var _sel_a_quai_prec := true      # le convoi primaire était-il à quai à l'image d'avant


func _ready() -> void:
	# L'écran de chargement d'abord, et UNE image laissée au moteur avant de
	# commencer : sans elle, tout le démarrage retomberait dans la même image
	# et l'écran n'apparaîtrait jamais. Voir scripts/chargement.gd.
	var ecran := Chargement.new()
	add_child(ecran)
	await get_tree().process_frame

	const ETAPES := 8

	await ecran.avancer("Simulation économique", 0, ETAPES)
	sim = Sim.new()
	if not sim.pret:
		push_error("Simulation Lua absente : %s" % sim.erreur)
		ecran.queue_free()
		return

	await ecran.avancer("Grille de navigation", 1, ETAPES)
	sim.preparer_navigation()

	await ecran.avancer("Fiche de projection", 2, ETAPES)
	proj = ProjectionCarte.new(CHEMIN_FICHE)
	if not proj.valide:
		push_error(proj.erreur + "  (lance d'abord la cuisson de la carte)")
		ecran.queue_free()
		return

	_police = ThemeDB.fallback_font
	# Les vignettes sont réduites d'un facteur 4 environ. Sans mipmap, elles
	# restent artificiellement piquées et tranchent avec le terrain, qui est
	# doux. Le filtrage les ramène au même niveau de détail.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	await ecran.avancer("Vignettes des villes", 3, ETAPES)
	_villes = Villes.new()

	await ecran.avancer("Illustration de la carte", 4, ETAPES)
	_creer_ombre()
	_creer_fond_mer()
	_creer_carte()

	await ecran.avancer("Nappe animée et nuages", 5, ETAPES)
	_creer_mer()

	await ecran.avancer("Villes et mouillages", 6, ETAPES)
	# Les ports AVANT la caméra : c'est elle qui calcule les bornes de zoom, et
	# la borne du plus près se mesure sur deux d'entre eux.
	ports = sim.ports()
	_creer_camera()
	_placer_navire()

	await ecran.avancer("Habillage et ambiance", 7, ETAPES)
	_creer_hud()
	# Le ressac et la musique. Un noeud a part : il ne dépend de rien d'autre
	# que de lui-même, et continue de tourner quand le jeu est en pause.
	add_child(Ambiance.new())
	_comptoir = MarchePanneau.new()
	add_child(_comptoir)
	_infos_ville = VillePR3.new()
	add_child(_infos_ville)
	_infos_ville.poser_villes(_villes)
	# L'écran des routes commerciales automatiques du joueur.
	_routes = RoutesPanneau.new()
	add_child(_routes)
	# L'écran du chantier naval : y constituer sa flotte.
	_chantier = ChantierPR3.new()
	add_child(_chantier)
	# Le menu radial au clic sur une ville : infos, dock, chantier (si elle en a un).
	_radial = RadialVille.new()
	add_child(_radial)
	# La capitainerie d'un port : convois à quai et navires sans convoi qui y sont.
	_capitainerie = CapitaineriePanneau.new()
	add_child(_capitainerie)
	# Le bureau du port tabulé, fidèle à Scene_Convoy_Town de PR3 (remplace la
	# Capitainerie séparée : Convois / Navires / Villes / Routes en onglets).
	_convoy_town = ConvoyTownPanneau.new()
	add_child(_convoy_town)
	_radial.infos_demandee.connect(func(port: Dictionary) -> void:
		_ouvrir_infos_ville(port))
	# Dock = le marché. On sélectionne d'abord un convoi présent au port, pour que
	# le comptoir échange avec celui qui est là.
	_radial.dock_demande.connect(func(port: Dictionary) -> void:
		_selectionner_convoi_au_port(port)
		_ouvrir_comptoir(port))
	# Bureau du port = l'écran de ville tabulé (Convois/Navires/Villes/Routes).
	_radial.capitainerie_demande.connect(func(port: Dictionary) -> void:
		if _convoy_town != null:
			_convoy_town.ouvrir(sim, port))
	_radial.chantier_demande.connect(func(port: Dictionary) -> void:
		if _chantier != null:
			_chantier.ouvrir(sim, port))
	# Le bouton « Infos ville » du comptoir passe par ici : c'est la carte qui
	# arbitre lequel des deux panneaux est à l'écran.
	_comptoir.infos_demandees.connect(func(port: Dictionary) -> void:
		_ouvrir_infos_ville(port))
	_infos_ville.denrees_demandees.connect(func(port: Dictionary) -> void:
		_ouvrir_comptoir(port))

	await ecran.avancer("Prêt", 8, ETAPES)
	ecran.queue_free()
	_charge = true

	_diagnostic_marche()
	_capture_auto()


# Outil : `-- --marche [jours]`. Imprime les marchés des cinq villes, puis
# les réimprime après N jours simulés. C'est la seule façon de voir si
# l'économie converge ou si elle diverge : un déséquilibre met des semaines de
# jeu à se manifester, et rien ne se voit sur une capture d'écran.
func _diagnostic_marche() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--marche")
	if i < 0:
		return
	var jours := 0
	if i + 1 < args.size() and args[i + 1].is_valid_int():
		jours = int(args[i + 1])

	if jours > 0:
		# On passe par la même porte que le jeu — `avancer_temps` en secondes
		# réelles — plutôt que d'appeler l'économie en direct : c'est le vrai
		# chemin qu'on veut éprouver, pas un raccourci de test.
		# 12 s réelles = une journée à vitesse x1 (Calendrier.SECONDES_JOUR).
		for _j in jours:
			sim.avancer_temps(12.0)

	var etat := sim.etat_compagnie()
	print("\n=== %s — %s « %s », %d/%d t, %d or ===" % [
		sim.etat_temps().get("date", ""), etat.get("classe", ""),
		etat.get("navire", ""), etat.get("charge", 0), etat.get("capacite", 0),
		etat.get("or_", 0)])

	for port in ports:
		var v := sim.etat_ville(str(port["cle"]))
		print("\n-- %-12s %5d hab.  subsistance %.0f %%" % [
			port["nom"], v.get("habitants", 0), v.get("subsistance", 0.0) * 100.0])
		for l in sim.marche(str(port["cle"])):
			var fleche := "  " if absf(l["solde"]) < 0.05 else ("↑" if l["solde"] > 0 else "↓")
			print("   %-15s stock %5d /%5d  %s%+6.1f t/j   achat %6.1f   vente %6.1f" % [
				l["nom"], l["stock"], l["reference"], fleche, l["solde"],
				l["achat"], l["vente"]])
	_diagnostic_troc()
	_diagnostic_marchands()
	_diagnostic_profondeur()
	get_tree().quit()


# Outil : `-- --marche 0 --profondeur`. De combien le cours bouge-t-il quand on
# achète une, dix, cinquante tonnes ?
#
# C'est LA question de réglage du marché, et elle ne se voit nulle part
# ailleurs : un entrepôt trop profond fige le prix et la réglette d'abondance
# sous les doigts du joueur, un entrepôt trop mince rend le prix affiché
# mensonger. On veut quelques pour cent à dix tonnes, dix à vingt à cinquante.
# Son corps est plus bas, après le diagnostic des convois.


# Outil : `-- --marche <jours> --marchands`. Où sont les cinq convois, que
# portent-ils, et de quoi chaque ville réclame-t-elle ?
#
# C'est le seul moyen de voir s'ils servent vraiment leur port : un convoi qui
# tourne entre deux villes sans jamais rapporter ce qui manque chez lui
# passerait inaperçu sur la carte.
func _diagnostic_marchands() -> void:
	if not OS.get_cmdline_user_args().has("--marchands"):
		return
	print("\n--- les marchands des nations ---")
	for m in sim.marchands():
		var ou := "à quai à %s" % m["ville"]
		if not bool(m["a_quai"]):
			ou = "en mer, cap sur %s" % m["destination"]
		print("  %-22s %-28s %6d or   %s" % [
			m["nom"], ou, int(m["or_"]), m["cargaison"]])

	print("  -- ce que chaque ville reclame --")
	for d in sim.diag_marchands():
		if bool(d["trouve"]):
			print("    %-12s manque de %-12s -> en chercher a %s" % [
				d["ville"], d["cle"], d["vers"] if str(d["vers"]) != "" else "nulle part"])
		else:
			print("    %-12s ne manque de rien" % d["ville"])


func _diagnostic_profondeur() -> void:
	if not OS.get_cmdline_user_args().has("--profondeur"):
		return
	print("\n--- profondeur du marche a Port Royale ---")
	print("  %-15s %6s %8s %8s %8s   ecart 50 t" % ["", "stock", "1 t", "10 t", "50 t"])
	var un := sim.marche("port_royale", 1)
	var dix := sim.marche("port_royale", 10)
	var cinquante := sim.marche("port_royale", 50)
	for i in un.size():
		var a1 := float(un[i]["achat_lot"])
		var a50 := float(cinquante[i]["achat_lot"])
		print("  %-15s %6d %8.1f %8.1f %8.1f   %+5.1f %%" % [
			un[i]["nom"], int(un[i]["stock"]), a1,
			float(dix[i]["achat_lot"]), a50, (a50 / a1 - 1.0) * 100.0])


# Outil : `-- --marche [jours] --troc`. Cherche la meilleure route du moment,
# la parcourt vraiment, et imprime le compte.
#
# Le tableau du comptoir peut afficher des chiffres justes sans qu'aucun échange
# n'aboutisse : seul le solde de la caisse prouve que la chaîne entière tient.
# Et la route est cherchée plutôt qu'écrite en dur — mon premier essai codait
# « rhum des Îles Turk vers Cartagène » et perdait 4 344 pièces, parce que le
# rhum est justement rare à Port Royale ce jour-là. Un test qui doit deviner le
# bon sens ne teste que la mémoire de celui qui l'a écrit.
func _diagnostic_troc() -> void:
	if not OS.get_cmdline_user_args().has("--troc"):
		return

	# Les marchés sont cotés POUR LA CALE ENTIÈRE, pas à l'unité.
	#
	# Ma première version comparait les prix unitaires puis achetait cinquante
	# tonnes : sur un marché mince l'estimation n'avait aucun rapport avec la
	# réalité, et l'outil annonçait des routes à +230 la tonne qui se soldaient
	# par une perte. Un instrument de mesure qui ment est pire que pas d'outil —
	# j'ai réglé les marchands contre lui pendant deux tours.
	var tonnage := int(sim.etat_compagnie().get("capacite", 50))
	var marches := {}
	for port in ports:
		marches[str(port["cle"])] = sim.marche(str(port["cle"]), tonnage)

	var meilleure := {"gain": -INF}
	for depart in marches:
		for i in (marches[depart] as Array).size():
			var ici: Dictionary = marches[depart][i]
			var lot: int = mini(tonnage, int(ici["achat_max"]))
			if lot <= 0:
				continue
			for arrivee in marches:
				if arrivee == depart:
					continue
				var la: Dictionary = marches[arrivee][i]
				var gain: float = float(la["vente_lot"]) - float(ici["achat_lot"])
				if gain > float(meilleure["gain"]):
					meilleure = {"gain": gain, "cle": str(ici["cle"]),
								 "nom": str(ici["nom"]), "de": depart, "vers": arrivee}
	if not meilleure.has("cle"):
		print("
--- essai de negoce : aucune route praticable ---")
		return

	var etat := sim.etat_compagnie()
	var cale := int(etat["capacite"])
	print("
--- essai de negoce : %s, %s -> %s (%+.1f /t attendu) ---" % [
		meilleure["nom"], meilleure["de"], meilleure["vers"], meilleure["gain"]])
	var avant := int(etat["or_"])

	var achat := sim.acheter(str(meilleure["de"]), str(meilleure["cle"]), cale)
	print("  achat  : %s  %d t pour %d pieces" % [
		"ok" if achat["ok"] else "ECHEC (%s)" % achat["message"],
		achat["quantite"], achat["somme"]])
	var vente := sim.vendre(str(meilleure["vers"]), str(meilleure["cle"]), cale)
	print("  vente  : %s  %d t pour %d pieces" % [
		"ok" if vente["ok"] else "ECHEC (%s)" % vente["message"],
		vente["quantite"], vente["somme"]])

	var fin := sim.etat_compagnie()
	print("  cale   : %d / %d t,  caisse %d" % [fin["charge"], fin["capacite"], fin["or_"]])
	print("  BENEFICE DU VOYAGE : %+d pieces sur %d de capital" % [
		int(fin["or_"]) - avant, avant])

	# L'echange doit avoir bouge les cours des DEUX villes : c'est la preuve
	# qu'il a atteint les entrepots, et pas seulement la caisse.
	for cle in [str(meilleure["de"]), str(meilleure["vers"])]:
		for l in sim.marche(cle):
			if str(l["cle"]) == str(meilleure["cle"]):
				print("  %-14s a %-12s stock %4d   achat %6.1f   vente %6.1f" % [
					meilleure["nom"], cle, l["stock"], l["achat"], l["vente"]])


# Le fond de mer : un aplat sous l'illustration.
#
# L'illustration ne peint plus le large — `outils/carte_eau.py` l'a rendu à la
# nappe animée, qui se dessine par-dessus mais n'est pas opaque. Sans rien
# derrière, on verrait le fond de la fenêtre à travers l'eau. Cet aplat est
# exactement la couleur que l'illustration portait là : à l'oeil, rien n'a
# changé; c'est la texture au pinceau qui a disparu sous le mouvement.
# L'ombre de contact des villages, en TEXTURE.
#
# Trois cercles empilés se lisaient comme trois cercles : des bords nets et
# deux marches de gris. Dix cercles donnaient bien une pente lisse, mais
# `draw_circle` est cher — à soixante villages, dix cercles chacun coûtaient
# 33 ms PAR IMAGE, mesuré, contre 15 ms pour trois. Un tiers du budget pour une
# ombre.
#
# Le dégradé est donc calculé une seule fois dans une petite image, et chaque
# village n'en fait plus qu'un `draw_texture_rect`. L'écrasement vertical vient
# du rectangle lui-même, ce qui évite même le `draw_set_transform`.
func _creer_ombre() -> void:
	const N := 64
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var r := (N - 1) * 0.5
	for y in N:
		for x in N:
			var d := Vector2(x - r, y - r).length() / r
			# Chute quadratique : un bord franc se verrait comme un disque.
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.05, 0.04, 0.03, a * a * OMBRE_ALPHA))
	_tex_ombre = ImageTexture.create_from_image(img)


func _creer_fond_mer() -> void:
	var fond := ColorRect.new()
	fond.position = Vector2.ZERO
	fond.size = Vector2(proj.pixels)
	fond.color = proj.mer_fond
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.z_index = -11          # sous l'illustration, qui est à -10
	add_child(fond)


func _creer_carte() -> void:
	var tex: Texture2D = load(CHEMIN_CARTE)
	if tex == null:
		push_error("carte introuvable : %s" % CHEMIN_CARTE)
		return
	_carte = Sprite2D.new()
	_carte.texture = tex
	_carte.centered = false
	_carte.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_carte)
	# Tout le reste se dessine par-dessus
	_carte.z_index = -10


# La nappe animée : elle ne remplace pas la mer peinte, elle l'agite.
#
# Son support est la fiche de mer elle-même, étirée aux dimensions de la carte.
# Ainsi l'UV du shader tombe exactement sur la carte, sans qu'aucune constante
# de cadrage n'ait à être recopiée d'un fichier à l'autre.
func _creer_mer() -> void:
	if not FileAccess.file_exists(CHEMIN_MER):
		push_warning("fiche de mer absente (recuis la carte) : " + CHEMIN_MER)
		return
	var tex: Texture2D = load(CHEMIN_MER)
	if tex == null:
		return
	_mer = Sprite2D.new()
	_mer.texture = tex
	_mer.centered = false
	_mer.scale = Vector2(proj.pixels) / Vector2(tex.get_size())
	_mer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_mer_pr3 = OS.get_cmdline_user_args().has("--eau-pr3")
	_poser_shader_mer()
	_mer.z_index = -9
	# `--sans-mer` retire la nappe animée et ne laisse que l'illustration. C'est
	# un outil de mesure : l'eau peinte de la carte et l'eau animée se
	# ressemblent assez pour qu'on ne puisse pas les départager à l'oeil, et la
	# caméra suit un navire — deux captures à des instants différents ne se
	# superposent donc pas. À délai égal, avec et sans, elles se superposent.
	if not OS.get_cmdline_user_args().has("--sans-mer"):
		add_child(_mer)
	_creer_nuages()


# Pose sur la nappe l'une ou l'autre mer. Les deux shaders lisent la même fiche
# et reçoivent les mêmes paramètres : seule la recette change, ce qui permet de
# basculer en pleine partie et de comparer au même endroit, au même instant.
func _poser_shader_mer() -> void:
	if _mer == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/mer_pr3.gdshader" if _mer_pr3
		else "res://shaders/mer_animee.gdshader")
	mat.set_shader_parameter("taille_monde", proj.vue_taille)
	mat.set_shader_parameter("zoom", _zoom)
	_mer.material = mat


# Les nuages passent AU-DESSUS de tout : terrain, mer, navires, villages. C'est
# ce que fait Port Royale 3, et c'est la seule place qui se tienne — un nuage
# qui passerait sous un navire se lirait comme une tache sur la vitre.
func _creer_nuages() -> void:
	_nuages = ColorRect.new()
	_nuages.position = Vector2.ZERO
	_nuages.size = Vector2(proj.pixels)
	_nuages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/nuages.gdshader")
	mat.set_shader_parameter("taille_monde", proj.vue_taille)
	_nuages.material = mat
	_nuages.z_index = 6
	add_child(_nuages)


func _creer_camera() -> void:
	_cam = Camera2D.new()
	# Bornes = les bords de l'image : on ne doit jamais voir au-delà de la carte.
	_cam.limit_left = 0
	_cam.limit_top = 0
	_cam.limit_right = proj.pixels.x
	_cam.limit_bottom = proj.pixels.y
	_cam.zoom = Vector2(_zoom, _zoom)
	add_child(_cam)
	_cam.make_current()
	_recalculer_zoom_min()


# Le dézoom maximal : collée dans le coin nord-ouest, la caméra voit jusqu'à
# Port Royale, et pas au-delà.
#
# Deux réglages ont précédé celui-ci, et tous deux étaient des règles sans
# repère. Le premier calait le zoom sur la fenêtre — celui qui la remplit tout
# juste, pour ne jamais voir le vide autour de la carte : bonne règle, mais sur
# un grand écran elle interdisait de reculer assez. Le second posait un quart de
# la taille réelle : un chiffre rond, qui ne dit rien de ce qu'on embrasse.
#
# Celui-ci se lit sur la carte elle-même : du coin jusqu'à Port Royale, soit à
# peu près le Golfe, la Floride, Cuba et la Jamaïque d'un seul regard. C'est une
# portée de navigation, pas une fraction d'image, et elle reste juste si la
# carte change de taille au prochain recuisson.
const LOIN_JUSQUA := "port_royale"

# Le pas d'un cran de molette. Il sert aussi à CALER la borne du plus près :
# la portée voulue n'est presque jamais un multiple entier du pas, et le dernier
# cran se retrouvait alors rogné par le `clamp` — un palier de plus, à peine
# différent du précédent, qui donnait l'impression de zoomer pour rien. On
# descend donc la borne sur le dernier pas ENTIER depuis le dézoom maximal.
const PAS_ZOOM := 1.12

# L'alpha au centre de l'ombre de contact des villages.
const OMBRE_ALPHA := 0.34

# Combien d'événements de glissé à deux doigts valent un cran de molette.
const CRANS_PAR_GESTE := 4.0

# Déplacement de la caméra au clavier et à la souris.
#
# La vitesse est en PIXELS D'ÉCRAN par seconde, divisée par le zoom au moment de
# l'appliquer : sans ça on traverserait la carte en une seconde de près et on
# n'avancerait plus de loin. Ce qui doit rester constant, c'est la sensation —
# le décor qui file sous les yeux à la même vitesse quelle que soit l'altitude.
const VITESSE_CAMERA := 620.0
# Bande, en pixels d'écran, où la souris pousse la vue. Assez large pour être
# trouvée sans viser, assez fine pour ne pas se déclencher en visant un port.
const BORD_DEFILEMENT := 22.0
# Le mou du départ et de l'arrêt. Plus grand = plus sec ; à l'infini on retrouve
# le à-coup d'une caméra qui démarre et s'arrête au pixel près.
const INERTIE_CAMERA := 6.5

# --- le cartouche d'un port, en unités de CARTE -------------------------------
#
# Rien ici ne dépend du zoom, et c'est tout le principe : le cartouche est un
# objet posé sur la carte, comme le village qu'il surmonte. On le règle une fois
# pour le zoom maximal, et il rapetisse ensuite comme le reste — s'éloigner,
# c'est s'éloigner de tout.
#
# Les trois premières versions compensaient le zoom, chacune à sa façon : taille
# d'écran constante pour le texte, racine du zoom pour le pavillon. Le résultat
# se tenait pris élément par élément, et se défaisait à l'ensemble — les
# proportions du cartouche changeaient à chaque cran de molette.
# EN UNITÉS DE MONDE, et non en pixels de carte. La différence n'était sensible
# que le jour où la carte a changé de résolution : l'illustration compte quatre
# fois moins de pixels que la cuisson pour le même monde, et tout le cartouche
# s'est retrouvé quatre fois trop gros d'un coup. Une taille exprimée en monde
# ne dépend plus de la finesse de l'image.
const CART_POLICE := 28.4        # hauteur de police
# CART_PAVILLON_H a disparu. La hauteur du pavillon n'est plus un réglage libre :
# elle se déduit de la bande, dans les proportions de Port Royale 3 (44 x 30 pour
# une bande de 54). Voir `_geometrie_cartouche`.
# La part de la largeur d'une plaque sur laquelle son fond s'efface, à chaque
# bout. C'est le DÉFAUT de `_plaque_carte` ; le cartouche des villes, lui, passe
# la valeur relevée dans la forme de PR3 (voir BANDE_FRANGE).
#
# CART_FILET a disparu avec les filets : la forme du jeu ne porte aucun trait.
const CART_FRANGE := 0.16
# Ce que vaut le cartouche au dézoom maximal, par rapport à sa taille au plus
# près. Au-delà de 1,5 il écrase l'île qu'il désigne.
const CART_GROSSI_LOIN := 1.5

# Les navires. La planche de la pinasse donne neuf vues en grille 3 x 3 : huit
# orientations autour, la vue de dessus au centre — que la carte n'utilise pas,
# ses villages étant eux-mêmes vus de biais.
const NAV_ATLAS := "res://sprites/navires/pinasse_atlas.png"
# Où chercher les atlas de modèles 3D, dans l'ordre : ceux du projet d'abord,
# ceux extraits de Port Royale 3 ensuite (voir `_atlas_modele`).
const NAV_DOSSIERS_MODELES := [
	"res://sprites/navires/modeles/",
	"res://reference_pr3/navires_wm/atlas/",
]
# Unités de monde par unité de modèle. Une pinasse de PR3 mesure vingt-trois
# unités de l'étrave à la poupe : à 2,2 elle garde la longueur de la pinasse
# dessinée qu'elle remplace, et les autres navires suivent à proportion.
const NAV_MONDE_PAR_UNITE_MODELE := 2.2
# La couleur des voiles : la variante du flipbook de PR3 (0 à 8, voir
# `outils/rendre_navires_pr3.gd`). Neuf couleurs — blanc, noir, rouge, bleu,
# bordeaux, vert, jaune et deux blancs — et donc de quoi en donner une à chaque
# couronne : on reconnaît un convoi portugais à ses voiles vertes avant d'avoir
# lu son pavillon. La palette n'a pas d'orange ; la Hollande prend le bordeaux.
#
# Le joueur garde le blanc, qu'aucune nation ne porte. Le noir attend les pirates.
const NAV_VOILES_NATIONS := {
	"espagne": 6,
	"angleterre": 2,
	"france": 3,
	"hollande": 4,
	"portugal": 5,
}
const NAV_VOILE_DEFAUT := 0
const NAV_VOILE_JOUEUR := 0
var _atlas_modeles := {}        # modele -> {texture, fiche}, ou {} s'il n'existe pas
var _modele_joueur := "?"       # « ? » : pas encore demandé à la simulation
const NAV_COTE := 128.0
# Le côté d'une vignette en UNITÉS DE MONDE, et non en pixels d'écran. Mesuré à
# l'écran, le navire gardait la même taille à tous les zooms : il grossissait
# donc sur la carte à mesure qu'on s'éloignait, jusqu'à couvrir une île entière
# au plan large. Mesuré en monde, il a une taille sur l'eau — on le voit
# simplement de plus loin.
const NAV_TAILLE := 62.0

# La case de l'atlas pour chaque cap, du nord et dans le sens des aiguilles :
# N, NE, E, SE, S, SO, O, NO.
#
# L'atlas est rangé dans l'ordre de lecture de la planche, qui n'est pas celui
# des caps. Deux pièges s'y cachent. La vue de face — proue vers nous — montre un
# navire qui DESCEND vers le sud, et celle de poupe un navire qui monte au nord.
# Et surtout, une planche d'orientations nomme ses profils du côté du BATEAU
# qu'on regarde : le « profil gauche » montre le flanc bâbord, donc une proue qui
# pointe à GAUCHE de l'écran, soit un cap à l'ouest. Lire ces deux vues à
# l'envers revient à mettre toute la rose en miroir, et chaque navire croise
# alors la route qu'il devrait suivre.
const NAV_ROSE := [7, 8, 5, 2, 1, 0, 3, 6]

# Le sillage, en côtés de vignette : sa longueur et son demi-écartement.
const SILLAGE_LONG := 1.15
const SILLAGE_OUVRE := 0.30
const CART_MARGE := 23.2         # respiration à gauche et à droite du nom
# Cote de la vignette d'état, en hauteurs de pavillon.
const CART_ICONE := 0.87

# LA BANDE DE NOM DE PORT ROYALE 3 : UN DÉGRADÉ, PAS UNE IMAGE.
#
# J'ai d'abord cru que c'était un 3-tranches fait des images 46/47/48 de
# `hud_seamap_pc`, dont les tailles — 10 / 1 / 10 px — s'y prêtaient à merveille.
# C'ÉTAIT FAUX, et deux indices auraient dû m'arrêter : `Seamap_Text_Bg_16` est le
# caractère 39, ABSENT de `caracteres.txt` — donc pas un bitmap —, et AUCUN écran
# ne référence 46, 47 ni 48. J'ai déduit « bitmap » de tailles de fichiers.
#
# `outils/swf_formes.py hud_seamap_pc.swf Seamap_Text_Bg` décode la vraie forme :
#
#   Seamap_Text_Bg_16         fill grad  118:(0,0,0,153)  255:(0,0,0,0)
#   Seamap_Text_Bg_Player_17  fill grad  203:(0,129,255,255)  255:(0,0,0,0)
#
# Un DÉGRADÉ de noir à alpha 153, soit 60 %, qui s'efface jusqu'à la transparence,
# et AUCUN trait — la forme ne porte pas de LineStyle. Notre plaque peinte était
# donc la bonne TECHNIQUE ; seuls ses chiffres étaient faux (0,72 d'alpha, deux
# filets, un fondu de 16 %).
#
# Le noir garde sa pleine densité jusqu'au repère 118 sur 255, puis s'efface : le
# fondu occupe (255-118)/255, soit 54 % de la DEMI-largeur — donc 27 % de la
# largeur totale à chaque bout.
const BANDE_ALPHA := 0.60
const BANDE_FRANGE := 0.27

# `marker_office`, LA SECONDE FORME, EST UN ÉTAT ET NON UNE DÉCORATION. Son
# dégradé est BLEU — (0,129,255) —, et PR3 la superpose à la bande quand le joueur
# tient un entrepôt dans la ville : c'est la ligne cyan qu'on voit sur les
# captures du jeu. On ne la dessine pas, faute d'entrepôts de joueur dans la
# simulation ; sa couleur est notée ici pour le jour où ils existeront.
#
# La copier comme ornement aurait fait passer un état pour un décor — et l'aurait
# montrée sur les soixante villes.

# Une unité de l'agencement de PR3, mesurée sur son champ de nom
# (`Visual_Textfeld_16_Shadow`, seize points, soit environ 21 unités de haut).
# La bande étant un dégradé sans dimensions propres, c'est le TEXTE qui donne
# l'échelle du cartouche — pavillon et icône de type s'en déduisent.
const TEXTE_PR3 := 21.0

# Les pavillons du jeu (`Visual_NationFlag_Small`, 44 x 30). PR3 n'en livre pas
# pour le Portugal : cette nation garde le nôtre plutôt qu'un drapeau qui n'est
# pas le sien.
const PAVILLONS_PR3 := {
	"espagne": "skinlib_pr3/1568",
	"hollande": "skinlib_pr3/1569",
	"france": "skinlib_pr3/1570",
	"angleterre": "skinlib_pr3/1571",
}
# `icon_type` du cartouche de PR3 : la couronne du roi, l'écusson du gouverneur.
const TYPE_ROI := "skinlib_pr3/1694"
const TYPE_GOUVERNEUR := "skinlib_pr3/1695"

const UI_CARTE := "res://sprites/ui_pr/"
# Le sceau du dignitaire : sa taille en hauteurs de pavillon, et la part de
# lui-même qui passe au-dessus de l'arête du drapeau.
const DIGNITAIRE_TAILLE := 0.58
const DIGNITAIRE_MORD := 0.62

# Et au plus près, la vue embrasse à peu près la distance qui sépare Nouvelle
# Orléans de St-Augustin — d'un bout à l'autre de la côte de Floride.
#
# On ne fige pas un chiffre : on MESURE ces deux ports. Ils peuvent être
# déplacés à l'éditeur, et une constante écrite à la main mentirait dès le
# premier déplacement. Les clés, elles, ne bougent pas.
const PRES_DE := "nouvelle_orleans"
const PRES_A := "st_augustin"

func _recalculer_zoom_min() -> void:
	var vp := get_viewport_rect().size
	if ports.is_empty():
		return

	# Depuis le coin haut-gauche, la vue doit ATTEINDRE ce port : il faut donc
	# que la fenêtre couvre sa distance au coin, sur les deux axes. On prend le
	# plus petit des deux rapports — le plus grand n'en couvrirait qu'un.
	var loin := _port_par_cle(LOIN_JUSQUA)
	if not loin.is_empty():
		var rl: Vector3 = loin["rade"]
		var pl := proj.vers_carte(rl.x, rl.z)
		if pl.x > 1.0 and pl.y > 1.0:
			_zoom_min = minf(vp.x / pl.x, vp.y / pl.y)

	# La portée voulue, en pixels de carte, puis le zoom qui la fait tenir dans
	# la largeur de la fenêtre.
	var a := _port_par_cle(PRES_DE)
	var b := _port_par_cle(PRES_A)
	if a.is_empty() or b.is_empty():
		return
	var pa: Vector3 = a["rade"]
	var pb: Vector3 = b["rade"]
	var portee := proj.vers_carte(pa.x, pa.z).distance_to(proj.vers_carte(pb.x, pb.z))
	if portee > 1.0:
		var vise: float = maxf(_zoom_min, vp.x / portee)
		var crans: float = floor(log(vise / _zoom_min) / log(PAS_ZOOM))
		_zoom_max = _zoom_min * pow(PAS_ZOOM, maxf(crans, 0.0))
	_zoom = maxf(_zoom, _zoom_min)
	_cam.zoom = Vector2(_zoom, _zoom)


func _placer_navire() -> void:
	var depart := _port_par_cle("port_royale")
	var rade: Vector3 = depart["rade"]
	navire.position = Vector2(rade.x, rade.z)
	navire.vitesse_monde = sim.vitesse_monde(8.0)
	navire.arrive.connect(_sur_arrivee)
	_cam.position = proj.vers_carte(navire.position.x, navire.position.y)


# --- dessin -------------------------------------------------------------------

func _draw() -> void:
	if proj == null or not proj.valide:
		return

	for port in ports:
		_dessiner_port(port)
	if _mode_edition:
		_dessiner_reperes_edition()
	_dessiner_marchands()
	# La ligne d'ordre du convoi sélectionné passe SOUS les navires : c'est le
	# `ConvoyTargetLine` de PR3, qui va du convoi à sa destination.
	_dessiner_route_convoi()
	_dessiner_convois_joueur()
	# Les cartouches passent EN DERNIER, donc au-dessus des navires. Un convoi
	# qui passe devant l'étiquette de son port la rend illisible juste au moment
	# où l'on regarde ce port ; derrière, il ne gêne rien et l'on voit quand même
	# qu'il est là.
	#
	# Et EN TROIS PASSES, pas en une par ville : sur une côte serrée les
	# cartouches se chevauchent, et l'ordre de recouvrement doit être le même
	# partout. Une seule passe laisserait l'icône d'état d'un port voisin
	# recouvrir un nom, ce qui est exactement l'inverse de ce qu'on veut lire.
	for port in ports:
		_dessiner_etats(port)
	for port in ports:
		_dessiner_nom(port)
	for port in ports:
		_dessiner_pavillon(port)
	for port in ports:
		_dessiner_marque_convoi(port)


# Une ville n'est sur la carte QUE SI le joueur l'a découverte — « d'autres villes
# vont apparaître quand vous les découvrirez » (`ID_PLAYER_TIPP_A00_TEXT`), et
# « pour découvrir une ville, vous devez en approcher avec votre convoi »
# (`ID_TUTORIAL_A04_TEXT2`).
#
# LE TERRAIN, LUI, RESTE TOUJOURS VISIBLE : la carte maritime « montre tout le
# monde du jeu ». Port Royale 3 n'a pas de voile, et une première version de ce
# travail en avait posé un à tort — c'est l'entité qui manque, jamais le décor.
func _ville_vue(port: Dictionary) -> bool:
	return sim.ville_decouverte(String(port.get("cle", "")))


func _dessiner_port(port: Dictionary) -> void:
	if not _ville_vue(port):
		return
	var bourg: Vector3 = port["bourg"]
	var rade: Vector3 = port["rade"]
	var p := proj.vers_carte(bourg.x, bourg.z, 14.0)   # un peu au-dessus du sol
	var r := proj.vers_carte(rade.x, rade.z)
	var couleur: Color = port["couleur"]
	var bord: Color = port["couleur_bord"]
	var e := 1.0 / _zoom                                # taille constante à l'écran

	if _port_survole == port:
		# L'anneau du jeu s'il est là, le disque dessiné sinon. `SkinPR3.fichier`
		# rend `null` quand l'art manque, et la règle du projet est que SEUL LE
		# LOOK en dépende, jamais le comportement : une copie fraîche, sans
		# `reference_pr3/`, doit rester jouable.
		var anneau := SkinPR3.fichier(ANNEAU_SELECTION)
		if anneau != null:
			# Même encombrement que le disque qu'il remplace (rayon 22) : on
			# change l'art, pas la taille — sans quoi on ne saurait plus lequel
			# des deux a bougé.
			var cote := 44.0 * e
			draw_texture_rect(anneau,
				Rect2(p - Vector2(cote, cote) * 0.5, Vector2(cote, cote)),
				false, Color(1.0, 0.98, 0.85, 0.85))
		else:
			draw_circle(p, 22 * e, Color(1, 0.95, 0.7, 0.25))

	# Mouillage, au large
	draw_arc(r, 9 * e, 0, TAU, 20, Color(1, 1, 1, 0.35), 1.5 * e)

	# --- la ville -------------------------------------------------------------
	if not _villes.vide():
		var tex: Texture2D = _villes.texture_pour(port)
		var emprise := _villes.emprise(proj, port)
		var coin := emprise.position
		var taille := emprise.size
		_rects_villes[port["cle"]] = emprise

		# Ombre de contact : un objet qui n'en projette pas a toujours l'air
		# collé sur l'image. Elle est décalée vers le bas-droite, comme les
		# ombres du terrain, dont le soleil vient du haut-gauche.
		var pied := coin + Vector2(taille.x * 0.55, taille.y * 0.94)
		var lo := taille.x
		var ht := lo * 0.34
		draw_texture_rect(_tex_ombre,
				Rect2(pied - Vector2(lo * 0.5, ht * 0.5), Vector2(lo, ht)), false)

		# Teinte légèrement rabattue : le rendu généré est plus saturé et plus
		# contrasté que le terrain cuit, et ressort trop sans ça.
		draw_texture_rect(tex, Rect2(coin, taille), false, Color(0.93, 0.93, 0.90))
	else:
		draw_circle(p, 7 * e, Color(0.10, 0.08, 0.06))
		draw_circle(p, 5 * e, couleur)



# Le haut du village, en pixels de carte : c'est de là que pend le cartouche.
# Les deux passes en ont besoin — celle qui dessine le bourg et celle qui
# dessine l'étiquette — d'où ce calcul partagé plutôt qu'un champ mémorisé, qui
# se périmerait au premier déplacement de ville.
func _haut_bourg(port: Dictionary) -> Vector2:
	var bourg: Vector3 = port["bourg"]
	var p := proj.vers_carte(bourg.x, bourg.z, 14.0)
	if _villes.vide():
		return p
	var emprise := _villes.emprise(proj, port)
	return Vector2(emprise.position.x + emprise.size.x * 0.5, emprise.position.y)


# Le cartouche d'un port : pavillon, nom, type de ville et état. Dessiné dans une
# passe à part, après les navires — voir `_draw`.
#
# LA LARGEUR EST CELLE DU NOM, et c'est un RETOUR EN ARRIÈRE ASSUMÉ.
#
# Toutes les plaques avaient la même largeur, délibérément : ajustées au nom,
# elles donnaient « soixante plaques de soixante largeurs », une rangée
# d'étiquettes dépareillées où l'œil lit la longueur du mot avant le mot. Mais la
# bande de Port Royale 3 est un 3-tranches, donc taillée sur son texte par
# construction, et c'est celle du jeu qui est demandée. La fidélité l'emporte
# sur ma préférence.
func _largeur_plaque_nom(nom: String, taille_t: int) -> float:
	var cle := nom + "|" + str(taille_t)
	if _largeurs.has(cle):
		return _largeurs[cle]
	var l := _police.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, taille_t).x
	_largeurs[cle] = l
	return l


# La taille de police À L'ÉCRAN pour un texte haut de `CART_POLICE` sur la carte.
#
# On rastérise à la taille affichée, pas à la taille de carte : une police gravée
# à onze pixels puis agrandie par la caméra est floue, et c'est précisément au
# zoom maximal — là où l'on lit — que ça se verrait. Le dessin se fait donc dans
# une transformation inverse, en pixels d'écran, pour un résultat net à tous les
# crans.
func _police_ecran() -> int:
	return int(clampf(CART_POLICE * _par_unite() * _zoom, 6.0, 400.0))

# Pixels de carte par unité de monde. C'est le seul endroit qui sait à quelle
# finesse la carte est dessinée ; tout le reste raisonne en monde.
func _par_unite() -> float:
	if proj == null or proj.vue_taille.x <= 0.0:
		return 1.0
	return float(proj.pixels.x) / proj.vue_taille.x * _grossissement()


# Pixels de carte par unité de monde, SANS le grossissement des cartouches. Les
# étiquettes ont besoin de rester lisibles au loin ; un navire, lui, est un objet
# posé sur l'eau et doit garder sa taille au milieu des îles.
func _par_unite_brut() -> float:
	if proj == null or proj.vue_taille.x <= 0.0:
		return 1.0
	return float(proj.pixels.x) / proj.vue_taille.x


# Les cartouches grossissent quand on s'éloigne.
#
# Mesurés en unités de monde, ils gardent une taille constante SUR LA CARTE : ils
# rapetissent donc à l'écran à mesure qu'on dézoome, et c'est précisément au plan
# large — quand on cherche où aller — qu'on a le plus besoin de les lire. On leur
# rend donc la moitié de ce que le dézoom leur prend, en fondu entre les deux
# bornes plutôt que par paliers, pour qu'aucun cran de molette ne les fasse
# sauter.
func _grossissement() -> float:
	if _zoom_max <= _zoom_min:
		return 1.0
	var t: float = clampf((_zoom - _zoom_min) / (_zoom_max - _zoom_min), 0.0, 1.0)
	return lerpf(CART_GROSSI_LOIN, 1.0, t)


func _geometrie_cartouche(port: Dictionary) -> Dictionary:
	var haut_bourg := _haut_bourg(port)
	var u := _par_unite()
	var t_ecran := _police_ecran()
	# On mesure à l'écran, puis on ramène en pixels de carte.
	var ht := _police.get_height(t_ecran) / _zoom
	var lplaque := _largeur_plaque_nom(str(port.get("nom", "")), t_ecran) / _zoom \
			+ CART_MARGE * u * 2.0

	# TOUT LE CARTOUCHE EST À L'ÉCHELLE DE LA BANDE, dans les proportions du jeu.
	# `s` vaut une unité de son image : la bande y fait 54 de haut, l'embout 10,
	# le pavillon 44 x 30, l'icône de type 22 x 24.
	#
	# On cale `s` sur le CORPS PLEIN de la bande — 41 de ses 54 unités, le reste
	# étant le fondu du haut et du bas — pour qu'il garde la hauteur du texte. La
	# barre sombre derrière le nom pèse donc exactement ce qu'elle pesait ; ce
	# sont les fondus et le filet du jeu qui viennent en plus.
	var s := ht / TEXTE_PR3
	# La bande respire autour du texte ; son dégradé s'efface de toute façon avant
	# d'atteindre ses bords.
	var hbande := ht * 1.30
	var lp := 44.0 * s
	var hp := 30.0 * s

	var bas := haut_bourg.y - 4.0 * u
	var rect_nom := Rect2(haut_bourg.x - lplaque * 0.5, bas - ht, lplaque, ht)
	# La bande déborde le texte de son fondu, en haut comme en bas.
	var bande := Rect2(rect_nom.position.x,
			rect_nom.position.y - (hbande - ht) * 0.5, lplaque, hbande)
	# Le pavillon : PR3 le pose à 58 unités du bord gauche pour une bande d'environ
	# 160, soit le milieu — on le centre donc, ce qui tient quelle que soit la
	# longueur du nom. Il MORD sur le haut de la bande de 8 unités, comme le jeu.
	var pav := Rect2(bande.position.x + (lplaque - lp) * 0.5,
			bande.position.y - hp + 8.0 * s, lp, hp)
	var cote := hp * CART_ICONE
	return {
		"t_ecran": t_ecran, "ht": ht, "s": s,
		"nom": rect_nom,
		"bande": bande,
		"pavillon": pav,
		# `icon_type` : 22 unités à droite du bord gauche du pavillon, une unité
		# plus haut — il chevauche donc la moitié droite du drapeau.
		"type": Rect2(pav.position.x + 22.0 * s, pav.position.y - 1.0 * s,
				22.0 * s, 24.0 * s),
		"icone": Rect2(rect_nom.position.x + cote * 0.10,
						bande.position.y + hbande + 2.0 * u, cote, cote),
	}

# Ce dont la ville souffre, sous son nom — les fléaux de Port Royale 3, avec les
# icônes du jeu (voir ICONES_ETAT).
#
# Passe 1, donc EN DESSOUS des étiquettes : deux ports voisins se chevauchent
# souvent, et c'est alors le nom qu'il faut pouvoir lire, pas l'état du voisin.
func _etats_affiches(cle: String) -> Array:
	var d = _etats.get(cle, null)
	if not (d is Dictionary):
		return []
	var fiche: Dictionary = d
	var sortie: Array = []
	# Un seul fléau à la fois : c'est la règle de la simulation, qui décompte
	# celui qui court avant d'en tirer un autre.
	var fleau := String(fiche.get("fleau", ""))
	if fleau != "" and ICONES_ETAT.has(fleau):
		sortie.append(fleau)
	# `faim` part à -3 et monte d'un cran par vivre manquant : au-dessus de zéro,
	# la ville ne mange plus à sa faim.
	if int(fiche.get("faim", -3)) > 0:
		sortie.append("famine")
	return sortie


func _dessiner_etats(port: Dictionary) -> void:
	if not _ville_vue(port):
		return
	var etats := _etats_affiches(String(port.get("cle", "")))
	if etats.is_empty():
		return
	var g := _geometrie_cartouche(port)
	var cadre: Rect2 = g["icone"]
	var plaque: Rect2 = g["nom"]
	var u := _par_unite()
	var cote := cadre.size.x
	var ecart := cote * 0.22
	# CENTRÉES sous la plaque : une seule icône tombe sous le milieu du nom, deux
	# se partagent la largeur. Calées à gauche, elles pendaient hors du cartouche.
	var large := cote * etats.size() + ecart * maxi(etats.size() - 1, 0)
	var x := plaque.position.x + plaque.size.x * 0.5 - large * 0.5
	for i in etats.size():
		var e := String(etats[i])
		var cell := Rect2(Vector2(x + i * (cote + ecart), cadre.position.y),
						Vector2(cote, cote))
		var tex := SkinPR3.texture(String(ICONES_ETAT.get(e, "")))
		if tex != null:
			# Les icônes du jeu portent déjà leur fond peint : aucun cadre sombre
			# par-dessus, il ferait double bordure.
			draw_texture_rect(tex, cell, false)
		else:
			var c: Color = COULEURS_ETAT.get(e, Color(0.86, 0.22, 0.20))
			var centre := cell.position + cell.size * 0.5
			var ray := cote * 0.42
			draw_circle(centre, ray + 1.2 * u, Color(0.03, 0.03, 0.04, 0.8))
			draw_circle(centre, ray, c)


# Passe 2 : la plaque et le nom.
func _dessiner_nom(port: Dictionary) -> void:
	if not _ville_vue(port):
		return
	var g := _geometrie_cartouche(port)
	var r: Rect2 = g["nom"]
	var t_ecran: int = g["t_ecran"]
	var texte: String = port["nom"]
	_bande_pr3(g["bande"])

	# Le texte est tracé en pixels d'ÉCRAN, dans une transformation inverse :
	# c'est ce qui le garde net quel que soit le cran de zoom.
	var lt := _police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, t_ecran).x
	var he := _police.get_height(t_ecran)
	draw_set_transform(r.position, 0.0, Vector2(1.0 / _zoom, 1.0 / _zoom))
	draw_string(_police, Vector2((r.size.x * _zoom - lt) * 0.5, he * 0.78),
				texte, HORIZONTAL_ALIGNMENT_LEFT, -1, t_ecran,
				Color(1, 0.98, 0.94))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Un de tes convois est-il à quai dans ce port ?
func _convoi_du_joueur_au_port(cle: String) -> bool:
	for m in _convois_joueur:
		if bool(m.get("a_quai", false)) and String(m.get("ville", "")) == cle:
			return true
	return false


# Un petit sceau d'or au bord de la plaque quand un de tes convois y est à quai :
# d'un coup d'œil sur la carte, on sait où sont ses navires.
func _dessiner_marque_convoi(port: Dictionary) -> void:
	if not _ville_vue(port):
		return
	if not _convoi_du_joueur_au_port(String(port.get("cle", ""))):
		return
	var g := _geometrie_cartouche(port)
	var r: Rect2 = g["nom"]
	var u := _par_unite()
	var c := r.position + Vector2(0.0, r.size.y * 0.5)   # bord gauche de la plaque
	var ray := maxf(r.size.y * 0.42, 5.0 * u)
	draw_circle(c, ray + 1.4 * u, Color(0.03, 0.03, 0.04, 0.85))
	draw_circle(c, ray, Color(0.95, 0.83, 0.4, 1.0))
	# Une petite ancre stylisée : jambe + jas + patte, en sombre sur l'or.
	var sombre := Color(0.16, 0.11, 0.07)
	var ep := maxf(ray * 0.16, 0.8 * u)
	draw_line(c + Vector2(0, -ray * 0.55), c + Vector2(0, ray * 0.5), sombre, ep)
	draw_line(c + Vector2(-ray * 0.45, -ray * 0.3), c + Vector2(ray * 0.45, -ray * 0.3), sombre, ep)
	draw_arc(c + Vector2(0, ray * 0.15), ray * 0.5, deg_to_rad(20), deg_to_rad(160), 10, sombre, ep)


# Passe 3 : le pavillon, tout au-dessus. Il mord sur le filet supérieur de la
# plaque — voir CART_CHEVAUCHE.
func _dessiner_pavillon(port: Dictionary) -> void:
	if not _ville_vue(port):
		return
	var g := _geometrie_cartouche(port)
	var rect: Rect2 = g["pavillon"]
	var cle := str(port.get("nation_cle", ""))
	var tex := SkinPR3.texture(String(PAVILLONS_PR3.get(cle, "")))
	if tex != null:
		draw_texture_rect(tex, rect, false)
	else:
		# Le Portugal, et tout poste sans l'art du jeu.
		Pavillon.dessiner(self, cle, rect)
	_dessiner_type_ville(port, g)


# `icon_type` du cartouche de PR3 : la couronne du roi sur les capitales,
# l'écusson du gouverneur sur les villes de rang 2. Elle remplace le sceau que
# nous dessinions — même idée, mais l'icône est celle du jeu. Sans elle, on
# retombe sur le sceau.
func _dessiner_type_ville(port: Dictionary, g: Dictionary) -> void:
	var rang := int(port.get("taille", 1))
	if rang < 2:
		return
	var tex := SkinPR3.texture(TYPE_ROI if rang >= 3 else TYPE_GOUVERNEUR)
	if tex == null:
		_dessiner_dignitaire(port, g["pavillon"])
		return
	draw_texture_rect(tex, g["type"], false)


# La bande de nom du jeu. Rien à charger : c'est une forme vectorielle, et l'on
# reproduit son dégradé avec les chiffres relevés dans le .swf — noir à 60 %,
# effacé sur 27 % de la largeur à chaque bout, SANS filet.
#
# Elle ne dépend donc d'aucun art : elle s'affiche à l'identique sur une copie
# fraîche du dépôt, sans `reference_pr3/`.
func _bande_pr3(r: Rect2) -> void:
	_plaque_carte(r, BANDE_ALPHA, Color(0, 0, 0, 0), 0.0, BANDE_FRANGE)


# La couronne des capitales, la bague des villes de gouverneur.
#
# Aucune donnée à ajouter : `taille` porte déjà le rang. PR3 compte cinq villes
# de taille 3 — une par nation, exactement ses capitales — et sept de taille 2.
# Le vice-roi siège donc dans les premières, un gouverneur dans les secondes.
#
# L'icône mord sur le coin du pavillon plutôt que de se poser à côté : à l'échelle
# de la carte, deux petits objets séparés se lisent comme deux marques sans
# rapport, alors que celle-ci doit se lire comme un sceau APPOSÉ sur le drapeau.
func _sceau(rang: int) -> Texture2D:
	var nom := "viceroi" if rang >= 3 else "gouverneur"
	if _sceaux.has(nom):
		return _sceaux[nom]
	var chemin := UI_CARTE + nom + ".png"
	var tex: Texture2D = load(chemin) if ResourceLoader.exists(chemin) else null
	_sceaux[nom] = tex
	return tex


func _dessiner_dignitaire(port: Dictionary, pavillon: Rect2) -> void:
	var rang := int(port.get("taille", 1))
	if rang < 2:
		return
	# La texture vient du cache et n'est PAS chargée ici. `load()` appelé dans un
	# `_draw()` rend la première fois une texture encore vide : le sceau se
	# dessinait en carré blanc, et rien ne le corrigeait puisque le dessin ne
	# revient qu'au prochain redessin. C'est aussi une lecture de disque par
	# image, pour un fichier qui ne change jamais.
	var tex: Texture2D = _sceau(rang)
	if tex == null:
		return
	var cote := pavillon.size.y * DIGNITAIRE_TAILLE
	# A CHEVAL sur l'arete du haut, centre sur la hampe : le sceau se lit alors
	# comme pose sur le drapeau, tandis qu'au coin il flottait a l'oblique sans
	# qu'on sache auquel des deux ports voisins il appartenait.
	var coin := pavillon.position + Vector2(
		(pavillon.size.x - cote) * 0.5,
		-cote * DIGNITAIRE_MORD)
	draw_texture_rect(tex, Rect2(coin, Vector2(cote, cote)), false)


# La plaque de nom, comme dans Port Royale 3 : un fond noir qui s'efface vers
# la gauche et vers la droite, et deux filets clairs en haut et en bas.
#
# Un `StyleBoxFlat` ne sait pas faire ce dégradé horizontal — il n'a qu'une
# couleur de fond. On pose donc deux quadrilatères à couleurs de sommet :
# `draw_polygon` interpole entre les quatre coins, et deux quads dos à dos
# donnent un fondu symétrique sans la moindre texture.
func _plaque_carte(r: Rect2, alpha: float, bord: Color, ep_bord: float,
		frange := CART_FRANGE) -> void:
	# Le NOIR du jeu est du noir pur : sa forme donne (0,0,0,153). Le nôtre tirait
	# très légèrement sur le bleu, ce qui ne se voyait pas mais n'avait pas de
	# raison d'être.
	var noir := Color(0.0, 0.0, 0.0, alpha)
	var vide := Color(0.0, 0.0, 0.0, 0.0)
	var x0 := r.position.x
	var x1 := r.position.x + r.size.x
	var y0 := r.position.y
	var y1 := y0 + r.size.y

	# Le fondu ne prend plus la MOITIÉ de la plaque de chaque côté : il tient sur
	# une frange étroite, et tout le milieu reste pleinement opaque. Étalé sur la
	# demi-largeur, le noir n'atteignait sa densité qu'au centre exact et le nom
	# se lisait sur un fond qui fuyait sous ses premières et dernières lettres.
	var f := r.size.x * frange
	var xa := x0 + f
	var xb := x1 - f

	draw_polygon(PackedVector2Array([
		Vector2(x0, y0), Vector2(xa, y0), Vector2(xa, y1), Vector2(x0, y1)]),
		PackedColorArray([vide, noir, noir, vide]))
	draw_polygon(PackedVector2Array([
		Vector2(xa, y0), Vector2(xb, y0), Vector2(xb, y1), Vector2(xa, y1)]),
		PackedColorArray([noir, noir, noir, noir]))
	draw_polygon(PackedVector2Array([
		Vector2(xb, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(xb, y1)]),
		PackedColorArray([noir, vide, vide, noir]))

	# La forme de PR3 ne porte AUCUN trait : la bande du cartouche passe donc ici
	# avec une épaisseur nulle et ressort tout de suite. Les filets ne servent plus
	# qu'aux autres plaques du jeu, qui en ont.
	if ep_bord <= 0.0 or bord.a <= 0.0:
		return

	# Les filets s'effacent AVEC le fond : un liseré net sur un fond dégradé
	# donnerait deux traits qui flottent dans le vide à chaque extrémité.
	var b0 := Color(bord.r, bord.g, bord.b, 0.0)
	for y in [y0, y1 - ep_bord]:
		draw_polygon(PackedVector2Array([
			Vector2(x0, y), Vector2(xa, y), Vector2(xa, y + ep_bord), Vector2(x0, y + ep_bord)]),
			PackedColorArray([b0, bord, bord, b0]))
		draw_polygon(PackedVector2Array([
			Vector2(xa, y), Vector2(xb, y), Vector2(xb, y + ep_bord), Vector2(xa, y + ep_bord)]),
			PackedColorArray([bord, bord, bord, bord]))
		draw_polygon(PackedVector2Array([
			Vector2(xb, y), Vector2(x1, y), Vector2(x1, y + ep_bord), Vector2(xb, y + ep_bord)]),
			PackedColorArray([bord, b0, b0, bord]))


# Un chemin en pointillés, en pixels de carte. Écrit une fois : la route du
# navire personnel et celle du convoi sélectionné se dessinent pareil, et deux
# copies finiraient par diverger.
func _trait_pointille(pts: Array[Vector2]) -> void:
	var e := 1.0 / _zoom
	var tiret := 14.0 * e
	var trou := 10.0 * e
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var lon := a.distance_to(b)
		if lon < 0.01:
			continue
		var u := (b - a) / lon
		var t := 0.0
		while t < lon:
			var t2: float = minf(t + tiret, lon)
			draw_line(a + u * t, a + u * t2, Color(1, 0.93, 0.72, 0.8), 1.6 * e)
			t = t2 + trou


func _dessiner_route() -> void:
	if navire.route.is_empty():
		return
	var pts: Array[Vector2] = [proj.vers_carte(navire.position.x, navire.position.y)]
	for wp in navire.route:
		pts.append(proj.vers_carte(wp.x, wp.y))
	_trait_pointille(pts)


# LA ROUTE DU CONVOI SÉLECTIONNÉ — le `ConvoyTargetLine` / `ConvoyRoute` de PR3.
#
# Les points viennent du pont (`d.route`) et sont ceux que le convoi SUIT
# réellement : `sim/bridge.lua` prend soin de les exposer tels quels plutôt que
# de laisser le moteur recalculer un chemin seulement plausible. La liste se vide
# à l'accostage, donc le tracé disparaît de lui-même quand le convoi arrive.
func _dessiner_route_convoi() -> void:
	var m := _convoi_par_indice(_convoi_selectionne)
	if m.is_empty():
		return
	var chemin: Array = m.get("route", [])
	if chemin.is_empty():
		return
	var pos: Vector2 = m["position"]
	var pts: Array[Vector2] = [proj.vers_carte(pos.x, pos.y)]
	for wp in chemin:
		pts.append(proj.vers_carte(wp.x, wp.y))
	_trait_pointille(pts)


# Les navires marchands des nations. Même coque que celle du joueur, mais aux
# couleurs de leur couronne et sans voile : d'un coup d'oeil on sait que ce
# n'est pas le sien.
func _dessiner_marchands() -> void:
	var e := 1.0 / _zoom
	for m in _marchands:
		# On les dessine AUSSI à quai, en plus pâle. Les masquer au port les
		# faisait disparaître la moitié du temps, et l'archipel semblait vide.
		var quai := bool(m.get("a_quai", false))
		var pos: Vector2 = m["position"]
		# UN CONVOI ÉTRANGER NE SE VOIT QUE SOUS LES YEUX D'UN DES NÔTRES, ici et
		# maintenant. À la différence d'une ville, voir un navire ne s'acquiert
		# pas : il bouge, donc la vue se reperd dès qu'on s'éloigne.
		if not sim.en_vue(pos.x, pos.y):
			continue
		var p := proj.vers_carte(pos.x, pos.y)
		var a := proj.angle_ecran(cos(float(m["cap"])), sin(float(m["cap"])))

		# Un halo sous la coque : un navire brun foncé sur une mer bleu nuit ne se
		# voit pas au zoom de la carte.
		var u := _par_unite_brut()
		if not quai:
			_dessiner_sillage(p, a, u)
		draw_circle(p, NAV_TAILLE * 0.18 * u, Color(0, 0, 0, 0.18 if quai else 0.24))
		_poser_navire(p, a, NAV_TAILLE * 0.88 * u,
			Color(1, 1, 1, 0.55) if quai else Color(1, 1, 1, 1),
			_modele_voile(str(m.get("modele", "")),
				int(NAV_VOILES_NATIONS.get(str(m.get("nation_cle", "")), NAV_VOILE_DEFAUT))))
		continue

		var coque: Array[Vector2] = [
			Vector2(12, 0), Vector2(3, 5), Vector2(-9, 4),
			Vector2(-10, 0), Vector2(-9, -4), Vector2(3, -5),
		]
		var pts := PackedVector2Array()
		for v in coque:
			pts.append(p + v.rotated(a) * e)
		draw_colored_polygon(pts, Color(0.44, 0.33, 0.21) if quai
							 else Color(0.62, 0.47, 0.30))
		draw_polyline(pts + PackedVector2Array([pts[0]]),
					  Color(0.14, 0.08, 0.04), 1.5 * e)

		# Pavillon de la nation, planté au milieu de la coque : c'est lui qui
		# dit à qui on a affaire.
		var couleur: Color = m["couleur"]
		var flamme := PackedVector2Array([
			p + Vector2(-2, -2).rotated(a) * e,
			p + Vector2(-2, -13).rotated(a) * e,
			p + Vector2(8, -10).rotated(a) * e,
		])
		draw_colored_polygon(flamme, couleur.darkened(0.35) if quai else couleur)
		draw_polyline(flamme + PackedVector2Array([flamme[0]]),
					  Color(0.10, 0.06, 0.03), 1.0 * e)


func _dessiner_navire() -> void:
	var p := proj.vers_carte(navire.position.x, navire.position.y)
	var e := 1.0 / _zoom
	# Le cap monde ne pointe pas au même endroit à l'écran : la carte est
	# comprimée nord-sud, donc on passe par la projection.
	var a := proj.angle_ecran(cos(navire.cap), sin(navire.cap))
	var u := _par_unite_brut()
	if not navire.au_mouillage():
		_dessiner_sillage(p, a, u)
	draw_circle(p, NAV_TAILLE * 0.20 * u, Color(0, 0, 0, 0.22))
	_poser_navire(p, a, NAV_TAILLE * u, Color(1, 1, 1, 1), _modele_du_joueur())


# Les convois du joueur, dessinés comme le sien (voiles du joueur), avec un anneau
# d'or sous le convoi sélectionné. Ils naviguent dans la simulation ; ici on ne
# fait que les montrer et repérer celui qu'on commande.
func _dessiner_convois_joueur() -> void:
	var u := _par_unite_brut()
	for m in _convois_joueur:
		var pos: Vector2 = m["position"]
		var p := proj.vers_carte(pos.x, pos.y)
		var a := proj.angle_ecran(cos(float(m["cap"])), sin(float(m["cap"])))
		var quai := bool(m.get("a_quai", false))
		if not quai:
			_dessiner_sillage(p, a, u)
		if int(m.get("indice", -1)) == _convoi_selectionne:
			draw_arc(p, NAV_TAILLE * 0.5 * u, 0.0, TAU, 32, Color(0.95, 0.83, 0.4, 0.95), 2.5 * u)
		draw_circle(p, NAV_TAILLE * 0.20 * u, Color(0, 0, 0, 0.22))
		_poser_navire(p, a, NAV_TAILLE * 0.9 * u, Color(1, 1, 1, 1),
			_modele_voile(str(m.get("modele", "")), NAV_VOILE_JOUEUR))


# Le dico du convoi du joueur d'indice donné (relu chaque image), ou {}.
func _convoi_par_indice(ic: int) -> Dictionary:
	for m in _convois_joueur:
		if int(m.get("indice", -1)) == ic:
			return m
	return {}


# La position écran du convoi sélectionné, pour recentrer la caméra dessus.
func _pos_convoi_selectionne() -> Vector2:
	var m := _convoi_par_indice(_convoi_selectionne)
	if not m.is_empty():
		var pos: Vector2 = m["position"]
		return proj.vers_carte(pos.x, pos.y)
	return _cam.position


# Ouvre le comptoir quand le convoi sélectionné vient d'accoster — comme l'ancien
# navire du joueur ouvrait le dock en arrivant.
func _detecter_arrivee_convoi() -> void:
	var m := _convoi_par_indice(_convoi_selectionne)
	if m.is_empty():
		_sel_a_quai_prec = true
		return
	var quai := bool(m.get("a_quai", false))
	if quai and not _sel_a_quai_prec:
		var p := _port_par_cle(String(m.get("ville", "")))
		if not p.is_empty():
			_ouvrir_comptoir(p)
	_sel_a_quai_prec = quai


# Fixe le convoi commandé. UN SEUL, comme PR3 : la sélection au rectangle
# multi-convois qui vivait ici a été retirée — c'était un ajout, pas du jeu.
func _selectionner(indice: int) -> void:
	if indice < 0:
		return
	_convoi_selectionne = indice
	sim.selectionner_convoi(_convoi_selectionne)


# Plus aucun convoi commandé.
#
# On ne prévient PAS la simulation, et c'est délibéré : son `Compagnie.selection`
# désigne le convoi avec qui le comptoir négocie, et la vider ferait perdre
# l'interlocuteur du port. Ici tout ce qui lit `_convoi_selectionne` tolère déjà
# l'absence — `_convoi_par_indice` rend {}, la vignette se referme, le clic droit
# ne commande rien, et la caméra comme le bureau du port ont leur repli.
func _deselectionner() -> void:
	_convoi_selectionne = -1
	queue_redraw()


# L'indice du convoi du joueur sous un point du monde, ou -1. Sert à en sélectionner
# un d'un clic en pleine mer.
func _convoi_sous_monde(monde: Vector2) -> int:
	var meilleur := -1
	# PR3 : rayon de sélection d'un convoi (SelectionRange 16) plus large que celui
	# d'une ville (SelectionRangeTown 11), ratio 16/11.
	var rayon := RAYON_CLIC_PORT * 16.0 / 11.0
	var d2 := rayon * rayon
	for m in _convois_joueur:
		var pos: Vector2 = m["position"]
		var dd := monde.distance_squared_to(pos)
		if dd < d2:
			d2 = dd
			meilleur = int(m.get("indice", -1))
	return meilleur


# Le modèle du navire du joueur, demandé une seule fois à la simulation : il ne
# change pas en cours de route, et la question traverse le pont Lua.
func _modele_du_joueur() -> String:
	if _modele_joueur == "?":
		var modele := str(sim.etat_compagnie().get("modele", "")) if sim != null else ""
		_modele_joueur = _modele_voile(modele, NAV_VOILE_JOUEUR)
	return _modele_joueur


# Le nom d'atlas d'un modèle sous une couleur de voiles : `tradefluyt_0`. Un
# modèle vide reste vide, et la carte retombe alors sur la pinasse dessinée.
func _modele_voile(modele: String, voile: int) -> String:
	if modele == "":
		return ""
	return "%s_%d" % [modele, voile]


# Le sillage : deux traits qui s'ouvrent en V derrière la poupe, et s'effacent
# en s'éloignant. C'est ce qui donne au navire sa vitesse et son sens de marche —
# sans lui, un bateau à l'arrêt et un bateau au grand largue se dessinent pareil.
#
# Il se trace à partir du CAP, comme la vignette : si l'un des deux tombait de
# travers, le V partirait de l'étrave et le désaccord sauterait aux yeux.
func _dessiner_sillage(p: Vector2, angle: float, u: float) -> void:
	var arriere := Vector2(-1.0, 0.0).rotated(angle)
	var cote := Vector2(0.0, 1.0).rotated(angle)
	var base := p + arriere * (NAV_TAILLE * 0.14 * u)
	var longueur := NAV_TAILLE * SILLAGE_LONG * u
	var ouverture := NAV_TAILLE * SILLAGE_OUVRE * u
	var ep := maxf(NAV_TAILLE * 0.055 * u, 0.6)
	for s in [-1.0, 1.0]:
		var bout: Vector2 = base + arriere * longueur + cote * (ouverture * float(s))
		var n: Vector2 = (bout - base).normalized().orthogonal() * ep
		# Un quadrilatère plutôt qu'un trait : l'écume est large à la poupe et
		# se dissipe au loin, ce qu'une ligne d'épaisseur constante ne dit pas.
		draw_polygon(
			PackedVector2Array([base - n, base + n, bout + n * 0.35, bout - n * 0.35]),
			PackedColorArray([
				Color(1, 1, 1, 0.34), Color(1, 1, 1, 0.34),
				Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))


# L'atlas des navires, découpé de la planche par outils/decouper_navire.gd.
func _atlas_navire() -> Texture2D:
	if _atlas_nav != null:
		return _atlas_nav
	if ResourceLoader.exists(NAV_ATLAS):
		_atlas_nav = load(NAV_ATLAS)
	return _atlas_nav


# L'atlas d'un MODÈLE de navire : trente-deux caps, rendus depuis un maillage 3D
# par outils/rendre_navires_pr3.gd, un fichier par modèle et une fiche commune.
#
# On cherche d'abord les modèles du projet, puis ceux extraits de Port Royale 3.
# Ces derniers ne sont pas dans le dépôt — ils sont sous droits et vivent dans
# `reference_pr3/`, ignoré par git — et ils sont donc lus comme de simples
# fichiers, sans passer par l'import de Godot. Absent l'un et l'autre, le navire
# retombe sur la pinasse dessinée.
#
# Le résultat est gardé, y compris quand il est vide : sans ça la carte irait
# frapper au disque pour chaque navire, à chaque image.
func _atlas_modele(modele: String) -> Dictionary:
	if modele == "":
		return {}
	if _atlas_modeles.has(modele):
		return _atlas_modeles[modele]
	var trouve := {}
	for dossier in NAV_DOSSIERS_MODELES:
		var chemin := ProjectSettings.globalize_path(dossier + modele + ".png")
		var chemin_fiche := ProjectSettings.globalize_path(dossier + "fiche.json")
		if not FileAccess.file_exists(chemin) or not FileAccess.file_exists(chemin_fiche):
			continue
		var fiche = JSON.parse_string(FileAccess.get_file_as_string(chemin_fiche))
		var image := Image.load_from_file(chemin)
		if image == null or not (fiche is Dictionary):
			continue
		# Des mipmaps : au dézoom la vignette de 160 pixels tombe à une vingtaine,
		# et sans elles les mâts scintillent d'une image à l'autre.
		image.generate_mipmaps()
		trouve = {"texture": ImageTexture.create_from_image(image), "fiche": fiche}
		break
	_atlas_modeles[modele] = trouve
	return trouve


# Pose la vignette d'un modèle au cap le plus proche parmi ses trente-deux.
#
# Sa taille ne vient pas de l'appelant mais du modèle : tous les atlas partagent
# le même cadrage, calé sur le plus grand navire, si bien qu'une pinasse garde sa
# taille de pinasse à côté d'une flûte marchande.
func _poser_modele(p: Vector2, angle: float, teinte: Color, atlas: Dictionary) -> void:
	var fiche: Dictionary = atlas["fiche"]
	var caps := int(fiche.get("caps", 32))
	var colonnes := int(fiche.get("colonnes", 8))
	var px := float(fiche.get("cote", 160))
	var t := (angle + PI * 0.5) / TAU * float(caps)
	var k := ((int(round(t)) % caps) + caps) % caps
	var src := Rect2(float(k % colonnes) * px, float(int(k / colonnes)) * px, px, px)
	var cote := float(fiche.get("taille_modele", 60.0)) * NAV_MONDE_PAR_UNITE_MODELE * _par_unite_brut()
	# La flottaison tombe sous le centre de la case : on remonte l'image d'autant
	# pour que la coque se pose sur le point du navire, et son sillage derrière.
	var decal := float(fiche.get("decalage_flottaison", 0.0)) * cote
	draw_texture_rect_region(atlas["texture"],
		Rect2(p - Vector2(cote * 0.5, cote * 0.5 + decal), Vector2(cote, cote)), src, teinte)


# Pose la vue dont le cap est le plus proche. On ne fait PAS tourner l'image :
# ces vues sont en volume, et les faire pivoter à plat les retournerait comme des
# cartons découpés — le pont et l'ombre tournant avec la coque. Choisir la vue,
# c'est tout l'intérêt d'une planche d'orientations.
func _poser_navire(p: Vector2, angle: float, cote: float, teinte: Color, modele := "") -> void:
	var atlas := _atlas_modele(modele)
	if not atlas.is_empty():
		_poser_modele(p, angle, teinte, atlas)
		return
	var tex := _atlas_navire()
	if tex == null:
		return
	# L'angle écran a son zéro à l'est et tourne vers le bas ; les caps de la rose
	# partent du nord. D'où le quart de tour ajouté avant d'arrondir au huitième.
	var n := NAV_ROSE.size()
	var t := (angle + PI * 0.5) / TAU * float(n)
	var k := ((int(round(t)) % n) + n) % n
	var i: int = NAV_ROSE[k]
	var src := Rect2(float(i) * NAV_COTE, 0.0, NAV_COTE, NAV_COTE)
	draw_texture_rect_region(tex,
		Rect2(p - Vector2(cote, cote) * 0.5, Vector2(cote, cote)), src, teinte)


# --- boucle -------------------------------------------------------------------

func _process(delta: float) -> void:
	# Pendant le chargement, `sim` et `proj` n'existent pas encore : rien ici
	# ne doit tourner. Le garde est en TÊTE parce que la première ligne utile
	# interroge déjà `sim`.
	if not _charge:
		return
	# La barre d'espace tenue passe en x10. Le seuil se mesure ici parce qu'aucun
	# événement n'arrive tant que la touche ne bouge pas : sans horloge, un appui
	# maintenu est indistinguable d'un appui bref qui dure.
	if _espace_tenu >= 0.0 and not _survol:
		_espace_tenu += delta
		if _espace_tenu >= SEUIL_SURVOL:
			_survol = true
			sim.definir_survol(true)
	# Filet : si la fenêtre perd le focus touche enfoncée, le relâchement n'arrive
	# jamais et le jeu resterait en x10 pour toujours.
	elif _survol and not Input.is_key_pressed(KEY_SPACE):
		_finir_survol()
		_espace_tenu = -1.0

	_etats_delai -= delta
	if _etats_delai <= 0.0:
		_etats_delai = 1.5
		_etats = sim.etats_villes()
	# La nappe indexe la taille de ses paillettes sur le zoom : sans ça elles
	# disparaissent au dézoom, au moment où l'on voit le plus de mer. On le pousse
	# ICI et pas dans `_zoomer` : le zoom change aussi au cadrage initial et par
	# l'outil de capture, et rattraper ces endroits un à un se paie toujours.
	if _mer != null and _mer.material != null:
		(_mer.material as ShaderMaterial).set_shader_parameter("zoom", _zoom)
	if not sim.pret or proj == null or not proj.valide:
		return
	_conduire_camera(delta)
	sim.avancer_temps(delta)
	_marchands = sim.marchands()
	_convois_joueur = sim.convois_joueur()
	_detecter_arrivee_convoi()
	_maj_survol()
	_maj_hud()
	if _comptoir != null and _comptoir.visible:
		# Les cours suivent le temps qui passe, meme comptoir ouvert : le
		# tableau doit donc se relire, sinon il montre des prix perimes.
		_comptoir.rafraichir()
		var m := _comptoir.message()
		if m != "":
			_noter(m)
	# L'écran des routes se rafraîchit tout seul, à cadence throttlée (il porte des
	# boutons qu'un rebâti par image casserait). Les constructions du chantier, elles,
	# n'ont pas de bouton par ligne : on peut les relire à chaque image sans risque.
	if _chantier != null and _chantier.visible:
		_chantier.rafraichir()
	queue_redraw()


func _maj_survol() -> void:
	_port_survole = _port_sous(get_global_mouse_position())


# Le port désigné par un point de la carte, ou un dictionnaire vide.
#
# On vise l'IMAGE du village, pas son point. Le bourg est une convention
# interne — le joueur ne le voit jamais. Ce qu'il voit, c'est un village
# dessiné, et c'est dessus qu'il clique. L'ancien rayon était centré sur le
# bourg alors que le sprite est posé EN DÉCALÉ par rapport à lui (`ancrages`) :
# il fallait donc viser à côté du dessin pour attraper la ville.
#
# La décision est séparée de la souris pour qu'une sonde puisse l'interroger
# sur un point choisi, sans piloter le curseur.
func _port_sous(pos: Vector2) -> Dictionary:
	if not _villes.vide():
		var trouve := {}
		var plus_pres := INF
		for port in ports:
			# L'emprise ÉLARGIE : le sprite ne fait qu'une dizaine de pixels
			# et il est posé sur la terre, donc viser juste à côté est la
			# règle. La marge rend la cible atteignable sans ramener le
			# défaut d'origine, puisqu'elle reste centrée sur le DESSIN et
			# non sur le point.
			var r: Rect2 = _villes.emprise(proj, port).grow(MARGE_CLIC)
			if r.has_point(pos):
				# Deux villages peuvent se chevaucher : on prend celui dont le
				# centre est le plus près du point.
				var d := r.get_center().distance_to(pos)
				if d < plus_pres:
					plus_pres = d
					trouve = port
		return trouve

	# Pas de sprites chargés : le point redevient la seule cible possible.
	return _port_proche(proj.vers_monde(pos), RAYON_CLIC_PORT)


# Le port dont le bourg est le plus proche d'un point du MONDE, dans un rayon.
func _port_proche(monde: Vector2, rayon: float) -> Dictionary:
	var trouve := {}
	var meilleure := rayon
	for port in ports:
		var b: Vector3 = port["bourg"]
		var d := monde.distance_to(Vector2(b.x, b.z))
		if d < meilleure:
			meilleure = d
			trouve = port
	return trouve


# --- entrées ------------------------------------------------------------------

func _unhandled_input(e: InputEvent) -> void:
	# Rien tant que la carte n'est pas batie : l'ecran de chargement reste
	# affiche plus d'une seconde, et une molette tournee pendant ce temps
	# atteignait `_zoomer` alors que la camera n'existe pas encore.
	if not _charge:
		return

	# La barre d'espace se traite AVANT les gardes des panneaux. Si un écran
	# s'ouvre pendant qu'on la tient, c'est lui qui recevrait le relâchement —
	# et le jeu resterait bloqué en x10, à devoir deviner pourquoi.
	if e is InputEventKey and e.keycode == KEY_SPACE and not e.echo:
		_espace(e.pressed)
		return

	# Comptoir ouvert : la carte ne doit plus reagir derriere lui, ni au clic
	# ni au clavier. Il gere sa propre touche Echap.
	if _comptoir != null and _comptoir.visible:
		return
	if _infos_ville != null and _infos_ville.visible:
		return
	if e is InputEventMouseButton:
		match e.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoomer(PAS_ZOOM)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoomer(1.0 / PAS_ZOOM)
			MOUSE_BUTTON_LEFT:
				if e.pressed:
					# En édition, saisir une ville prend le pas sur tout le reste
					if _mode_edition:
						var pris := _saisir(get_global_mouse_position())
						if not pris.is_empty():
							_port_saisi = pris
							return
					_clic_depart = e.position
					_a_glisse = false
					_glisse = true
					_glisse_bouton = MOUSE_BUTTON_LEFT
				else:
					if not _port_saisi.is_empty():
						_port_saisi = {}
						return
					_glisse = false
					# Un simple clic DÉSIGNE ; un glissé gauche ne fait rien. PR3
					# n'a pas de sélection au rectangle, et on ne lui en prête pas.
					if not _a_glisse:
						_clic_gauche()
					queue_redraw()
			# Le clic DROIT commande le navire, comme dans Port Royale 3 :
			# « Cliquez avec le bouton droit sur votre destination pour faire
			# partir votre convoi. » Le gauche sert alors à désigner — une ville
			# qu'on veut regarder — et les deux gestes cessent de se disputer le
			# même bouton : on consultait un port en appareillant vers lui.
			MOUSE_BUTTON_RIGHT:
				# Pas de `_a_glisse` ici : ce drapeau appartient au glissé du
				# bouton gauche, qui ne le rabaisse qu'à sa propre pression
				# suivante. Le consulter faisait avaler le premier ordre donné
				# après chaque déplacement de la carte — le navire ne bougeait
				# pas, une fois sur deux, sans que rien ne l'explique.
				if not e.pressed:
					_clic_droit()
			MOUSE_BUTTON_MIDDLE:
				_glisse = e.pressed
				_a_glisse = e.pressed
				_glisse_bouton = MOUSE_BUTTON_MIDDLE
	# Le trackpad ne parle PAS la langue de la molette. Sur macOS, Godot rend
	# le glissé à deux doigts comme un InputEventPanGesture et le pincement
	# comme un InputEventMagnifyGesture : aucun des deux n'est un bouton de
	# souris. Sans ces deux branches, un Mac sans souris ne peut pas zoomer du
	# tout — et rien ne le dit, puisque la carte réagit au reste.
	elif e is InputEventMagnifyGesture:
		# `factor` est déjà une échelle : on la passe telle quelle.
		_zoomer(e.factor)
	elif e is InputEventPanGesture:
		# Le glissé à deux doigts tient le rôle de la molette. Il arrive en
		# rafale de petits deltas, là où la molette arrive par crans : on prend
		# donc une fraction de cran par événement, sinon deux doigts traversent
		# toute la plage de zoom d'un coup.
		if absf(e.delta.y) > 0.0:
			_zoomer(pow(PAS_ZOOM, -e.delta.y / CRANS_PAR_GESTE))
	elif e is InputEventMouseMotion and not _port_saisi.is_empty():
		var m := proj.vers_monde(get_global_mouse_position())
		var cle: String = _port_saisi["cle"]
		var ok := false
		if _saisie_image:
			# On ne déplace que le dessin : le décalage est la différence entre
			# la souris et le point réel, en mètres monde.
			var b: Vector3 = _port_saisi["bourg"]
			ok = sim.decaler_port(cle, m.x - b.x, m.y - b.z)
		else:
			# Le point réel se recale sur la côte la plus proche : impossible
			# de le poser en pleine mer ou au sommet d'une montagne.
			ok = sim.deplacer_port(cle, m.x, m.y)
		if ok:
			ports = sim.ports()
			for pt in ports:
				if pt["cle"] == cle:
					_port_saisi = pt
	elif e is InputEventMouseMotion and _glisse:
		if e.position.distance_to(_clic_depart) > 5.0:
			_a_glisse = true
		# Seul le bouton du MILIEU panoramique. Le glissé gauche ne trace plus de
		# boîte de sélection : PR3 n'en a pas.
		if _a_glisse and _glisse_bouton != MOUSE_BUTTON_LEFT:
			_cam.position -= e.relative / _zoom
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_SPACE: pass   # tout se joue au relâchement, voir _input_espace
			KEY_1, KEY_2, KEY_3, KEY_4: sim.definir_vitesse(e.keycode - KEY_0)
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: _zoomer(PAS_ZOOM)
			KEY_MINUS, KEY_KP_SUBTRACT: _zoomer(1.0 / PAS_ZOOM)
			KEY_R: _cam.position = _pos_convoi_selectionne()
			KEY_M:
				var quai := _port_a_quai()
				if quai.is_empty():
					_noter("Il faut être à quai pour visiter le comptoir.")
				else:
					_ouvrir_comptoir(quai)
			KEY_I:
				_ouvrir_infos_ville(_ville_regardee())
			KEY_F3:
				_mer_pr3 = not _mer_pr3
				_poser_shader_mer()
				_noter("Mer : %s" % ("recette Port Royale 3" if _mer_pr3 else "nappe animée d'origine"))
			KEY_F2:
				_mode_edition = not _mode_edition
				_port_saisi = {}
				_noter("Édition des villes : %s" % ("activée — glisse une ville, Ctrl+S pour enregistrer"
					if _mode_edition else "désactivée"))
			KEY_S:
				if e.ctrl_pressed and _mode_edition:
					_enregistrer_ports()
			# Sauver et reprendre. F5/F9 est la convention des jeux de stratégie, et
			# les deux touches étaient libres — `S` sert déjà à la caméra.
			#
			# Une seule case, nommée « partie » : c'est une sauvegarde rapide, pas
			# encore un écran de gestion. Le fichier est du JSON dans le dossier
			# utilisateur, donc lisible et modifiable à la main.
			KEY_F5:
				var res_s: Dictionary = sim.sauver("partie")
				if bool(res_s.get("ok", false)):
					_noter("Partie enregistrée.")
				else:
					_noter("Enregistrement impossible : " + String(res_s.get("message", "")))
			KEY_F9:
				var res_c: Dictionary = sim.charger("partie")
				if bool(res_c.get("ok", false)):
					# La carte gardait en mémoire le convoi commandé ; après un
					# rechargement il peut ne plus exister. On reprend celui que la
					# simulation vient de restaurer, sinon on piloterait un fantôme.
					_convoi_selectionne = int(sim.etat_compagnie().get("selection", 1))
					_noter("Partie reprise.")
				else:
					_noter("Reprise impossible : " + String(res_c.get("message", "")))
			KEY_ESCAPE: get_tree().quit()


# Conduire la vue : WASD (ou les flèches), et la souris contre un bord.
#
# On passe par une VITESSE plutôt que par un déplacement direct. Un déplacement
# direct démarre et s'arrête net, ce qui hache le décor ; une vitesse qu'on
# ramène doucement vers sa consigne donne le glissé d'une carte qu'on pousse.
# C'est le même `lerp` à l'aller et au retour, donc l'arrêt est aussi doux que
# le départ.
func _conduire_camera(delta: float) -> void:
	if _cam == null:
		return
	var dir := Vector2.ZERO
	# Touches PHYSIQUES : sur un clavier français, les quatre touches sous la
	# main gauche restent les mêmes qu'ailleurs, ce que tout jeu fait.
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0

	# La souris contre un bord pousse la vue de ce côté. On ne le fait que si
	# elle est DANS la fenêtre : posée ailleurs, sa dernière position connue
	# ferait défiler la carte toute seule.
	var vp := get_viewport_rect().size
	var m := get_viewport().get_mouse_position()
	if m.x >= 0.0 and m.y >= 0.0 and m.x <= vp.x and m.y <= vp.y:
		if m.x < BORD_DEFILEMENT:
			dir.x -= 1.0
		elif m.x > vp.x - BORD_DEFILEMENT:
			dir.x += 1.0
		if m.y < BORD_DEFILEMENT:
			dir.y -= 1.0
		elif m.y > vp.y - BORD_DEFILEMENT:
			dir.y += 1.0

	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	var cible := dir * (VITESSE_CAMERA / _zoom)
	_vitesse_cam = _vitesse_cam.lerp(cible, clampf(INERTIE_CAMERA * delta, 0.0, 1.0))
	if _vitesse_cam.length_squared() > 0.02:
		_cam.position += _vitesse_cam * delta


func _zoomer(facteur: float) -> void:
	var avant := get_global_mouse_position()
	_zoom = clampf(_zoom * facteur, _zoom_min, _zoom_max)
	_cam.zoom = Vector2(_zoom, _zoom)
	# On recale pour que le point sous le curseur ne bouge pas
	var apres := get_global_mouse_position()
	_cam.position += avant - apres


# Clic gauche : on DÉSIGNE. Une ville sous le curseur ouvre son écran ; ailleurs
# il ne se passe rien, et c'est voulu — le bouton qui fait bouger la flotte est
# le droit, et un ordre d'appareillage donné par mégarde coûte des jours de mer.
# Bref, la barre bascule la pause ; tenue, elle passe en x10 jusqu'au
# relâchement. On ne tranche donc qu'au relâchement : à l'enfoncement, on ne
# sait pas encore lequel des deux gestes le joueur est en train de faire.
func _espace(enfonce: bool) -> void:
	if enfonce:
		if _espace_tenu < 0.0:
			_espace_tenu = 0.0
		return
	if _survol:
		_finir_survol()
	elif _espace_tenu >= 0.0:
		sim.basculer_pause()
	_espace_tenu = -1.0


func _finir_survol() -> void:
	_survol = false
	sim.definir_survol(false)


func _clic_gauche() -> void:
	var monde := proj.vers_monde(get_global_mouse_position())
	var port := _port_survole
	if port.is_empty():
		port = _port_proche(monde, RAYON_CLIC_PORT)
	if not port.is_empty() and _radial != null:
		# Un port : la couronne s'ouvre au curseur, en pixels écran (elle vit dans
		# une CanvasLayer, hors de la transformée de la caméra). Dock et chantier
		# ne s'ouvrent que si un convoi du joueur est à ce port.
		# `sim` en quatrième argument : le centre de la couronne y prend la
		# réputation de la ville et les compteurs que PR3 pose sur ses pétales
		# (convois à l'ancre, navires en construction). L'argument est facultatif,
		# la couronne s'ouvre sans lui.
		_radial.ouvrir(port, get_viewport().get_mouse_position(),
				_joueur_au_port(port), sim)
		return
	# Pas de port : on sélectionne un convoi du joueur en pleine mer (anneau d'or),
	# et un clic dans le VIDE désélectionne.
	#
	# PR3 a bien cet ordre : `ID_LEGEND_ORDER_CONVOYDESELECT`, « Désélectionner le
	# convoi », dans la légende des ordres de la carte maritime — aux côtés de
	# `CONVOYSELECT`, `CONVOYTARGETPOS` et `CONVOYPATROL`. En revanche le GESTE qui
	# le déclenche n'est PAS dans la table de textes : les seules légendes de
	# commandes qui s'y trouvent (`ID_LEGEND_PC_HUD_*`) concernent le mode
	# construction et les routes. Le clic gauche à vide est donc DÉDUIT, pas relevé
	# — c'est le seul aboutissement inutilisé du clic gauche, et il n'entre en
	# conflit avec rien.
	var ic := _convoi_sous_monde(monde)
	if ic != -1:
		_selectionner(ic)
	else:
		_deselectionner()


# Le joueur a-t-il un convoi à quai dans ce port ? Tout est convoi désormais.
func _joueur_au_port(port: Dictionary) -> bool:
	return sim.convoi_au_port(String(port.get("cle", "")))


# Le port sur lequel ouvrir le bureau du port depuis le HUD : celui où le convoi
# sélectionné est à quai, sinon le premier port de la carte.
func _port_pour_bureau() -> Dictionary:
	var m := _convoi_par_indice(_convoi_selectionne)
	if not m.is_empty() and bool(m.get("a_quai", false)):
		var p := _port_par_cle(String(m.get("ville", "")))
		if not p.is_empty():
			return p
	return ports[0] if not ports.is_empty() else {}


# Sélectionne un convoi du joueur à quai dans ce port (pour que le comptoir échange
# avec lui). Ne change rien si aucun n'y est.
func _selectionner_convoi_au_port(port: Dictionary) -> void:
	var cle := String(port.get("cle", ""))
	for m in _convois_joueur:
		if bool(m.get("a_quai", false)) and String(m.get("ville", "")) == cle:
			_selectionner(int(m.get("indice", _convoi_selectionne)))
			return


# Clic droit : on COMMANDE. Le convoi sélectionné part vers le port visé, ou vers
# le point de mer cliqué — « Cliquez avec le bouton droit sur votre destination
# pour faire partir votre convoi. » UN SEUL convoi part, comme dans PR3.
func _clic_droit() -> void:
	if not _convoi_par_indice(_convoi_selectionne).is_empty():
		var monde0 := proj.vers_monde(get_global_mouse_position())
		var port0 := _port_survole
		if port0.is_empty():
			port0 = _port_proche(monde0, RAYON_CLIC_PORT)
		var refus := ""
		if not port0.is_empty():
			var res := sim.ordonner_convoi(
				_convoi_selectionne, String(port0.get("cle", "")))
			if not bool(res.get("ok", false)):
				refus = String(res.get("message", "Ordre refusé."))
		elif sim.est_terre(monde0.x, monde0.y, 30.0):
			_noter("Impossible d'aller à terre — clique sur la mer ou un port.")
			return
		else:
			var res := sim.ordonner_convoi_position(
				_convoi_selectionne, monde0.x, monde0.y)
			if not bool(res.get("ok", false)):
				refus = String(res.get("message", "Ordre refusé."))
		if refus != "":
			_noter(refus)
		return

	var port := _port_survole
	var cible := Vector2.ZERO

	if port.is_empty():
		var monde := proj.vers_monde(get_global_mouse_position())
		if sim.est_terre(monde.x, monde.y, 30.0):
			# Cliquer sur la terre ne peut pas être un non-événement.
			#
			# Le survol vise l'image du village, au pixel — c'est ce qu'on veut
			# pour désigner. Mais un village est DESSINÉ sur la terre et ne fait
			# qu'une dizaine de pixels : mesuré, 83 % des clics autour d'un
			# village tombaient à terre, donc dans un `return` muet. Le joueur
			# voyait un bateau qui refuse de partir sans qu'on lui dise pourquoi.
			# On rattrape donc le mouillage le plus proche, et à défaut on parle.
			port = _port_proche(monde, RAYON_CLIC_PORT)
			if port.is_empty():
				_noter("Pas de mouillage ici : clique sur la mer ou sur un port.")
				return
		else:
			cible = monde

	if not port.is_empty():
		var rade: Vector3 = port["rade"]
		cible = Vector2(rade.x, rade.z)
		if navire.position.distance_to(cible) < 40.0:
			return

	var route := sim.route(Vector3(navire.position.x, 0, navire.position.y),
						   Vector3(cible.x, 0, cible.y))
	if route.is_empty():
		# Trois mouillages sont enclos dans une eau que l'illustration peint
		# fermée (Maracaïbo, Gibraltar, Port-d'Espagne) : sans ce message, le
		# navire semblait simplement désobéir.
		_noter("Aucune route maritime jusque-là.")
		return
	navire.cap_sur(route, port)


# L'horloge ne s'arrête JAMAIS toute seule, ni à l'arrivée ni à l'ouverture du
# comptoir. Le monde continue de tourner pendant qu'on négocie — c'est le sens
# d'avoir des marchands concurrents. La barre d'espace met en panne quand le
# joueur le décide.
func _sur_arrivee(port) -> void:
	if port is Dictionary and not port.is_empty():
		_ouvrir_comptoir(port)


# Le port où le convoi SÉLECTIONNÉ est à quai, {} s'il est en mer ou absent.
func _port_a_quai() -> Dictionary:
	var m := _convoi_par_indice(_convoi_selectionne)
	if m.is_empty() or not bool(m.get("a_quai", false)):
		return {}
	return _port_par_cle(String(m.get("ville", "")))


# Comptoir et infos ville ne cohabitent pas : ce sont deux vues de la même
# ville, pas deux fenêtres. Empilées, fermer celle du dessus reposait le joueur
# sur celle du dessous sans qu'il l'ait demandé — on croyait quitter le dock et
# on y restait.
func _ouvrir_comptoir(port: Dictionary) -> void:
	if _comptoir == null or port.is_empty():
		return
	if _infos_ville != null:
		_infos_ville.fermer()
	_comptoir.ouvrir(sim, port)


# La ville dont on parle quand le joueur demande « infos ville » : celle où il
# est à quai, sinon la plus proche. Le comptoir, lui, exige d'être à quai —
# on n'achète qu'au port. Mais regarder une ville de loin ne coûte rien, et
# s'en priver obligerait à naviguer pour décider si le voyage vaut la peine.
func _ville_regardee() -> Dictionary:
	var quai := _port_a_quai()
	return quai if not quai.is_empty() else _port_le_plus_proche()


func _ouvrir_infos_ville(port: Dictionary) -> void:
	if _infos_ville == null:
		return
	if port.is_empty():
		_noter("Aucune ville en vue.")
		return
	if _comptoir != null:
		_comptoir.fermer()
	# Le comptoir n'est ouvrable que là où le joueur a un navire. On compare les
	# clés plutôt que les distances : être à quai à Tortuga n'ouvre pas le
	# comptoir de Port Royale, même si on regarde Port Royale.
	var quai := _port_a_quai()
	var ici: bool = (not quai.is_empty()
		and String(quai.get("cle", "")) == String(port.get("cle", "")))
	_infos_ville.ouvrir(sim, port, ici)


# --- HUD ----------------------------------------------------------------------

func _creer_hud() -> void:
	var couche := CanvasLayer.new()
	add_child(couche)

	var bois := Color(0.13, 0.09, 0.06, 0.93)

	# La planche de gauche du HUD de PR3, rejouée depuis hud_pc.swf : la date,
	# l'allure et ses deux boutons, la chronique. Voir scripts/hud_pr3.gd. Elle
	# tient à elle seule ce que `PanneauDate` et `BarreVitesse` faisaient à deux
	# avec un art peint à la main.
	_hud_planche = HudPR3.new()
	_hud_planche.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hud_planche.scale = Vector2.ONE * ECHELLE_HUD
	_hud_planche.position = MARGE_HUD
	_hud_planche.vitesse_choisie.connect(func(i: int) -> void:
		sim.definir_vitesse(i))
	couche.add_child(_hud_planche)

	# La planche de droite de PR3 : minimap, or en caisse, convois en mer et à
	# quai. Voir scripts/hud_droite_pr3.gd. Son `bu_liste` remplace le bouton
	# « Bureau du port » écrit à la main, qui occupait ce même coin.
	#
	# Ancrée en haut à DROITE sans marge : tous ses enfants ont un x négatif,
	# c'est ainsi que le .swf la conçoit.
	_hud_droite = HudDroitePR3.new()
	_hud_droite.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hud_droite.scale = Vector2.ONE * ECHELLE_HUD
	_hud_droite.liste_demandee.connect(func() -> void:
		if _convoy_town != null:
			_convoy_town.ouvrir(sim, _port_pour_bureau()))
	# Cliquer une ville sur la minimap y porte la caméra — c'est ce que fait PR3,
	# dont chaque pastille est un bouton.
	_hud_droite.ville_choisie.connect(func(cle: String) -> void:
		var p := _port_par_cle(cle)
		if p.is_empty() or proj == null or _cam == null:
			return
		var rade: Vector3 = p["rade"]
		_cam.position = proj.vers_carte(rade.x, rade.z))
	couche.add_child(_hud_droite)

	# La VIGNETTE DE CONVOI, sous la planche droite — c'est là que PR3 l'ouvre
	# quand on sélectionne un convoi. Voir scripts/convoi_vignette_pr3.gd.
	#
	# Alignée sur le bord GAUCHE de la planche (x = -207, sa largeur) et posée
	# juste dessous (y = sa hauteur) : les deux nombres viennent de
	# `HudDroitePR3.TAILLE`, pas d'une mesure à l'œil.
	_vignette = ConvoiVignettePR3.new()
	_vignette.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_vignette.scale = Vector2.ONE * ECHELLE_HUD
	_vignette.position = Vector2(-HudDroitePR3.TAILLE.x, HudDroitePR3.TAILLE.y)
	couche.add_child(_vignette)

	# Plus de bouton « Chantier » global : le chantier est propre à chaque port et
	# ne s'ouvre que depuis le menu radial d'une ville où l'on a un convoi.

	_lbl_message = Label.new()
	_lbl_message.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_lbl_message.offset_top = 14
	_lbl_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_message.add_theme_font_size_override("font_size", 16)
	_lbl_message.add_theme_color_override("font_color", Color(1, 0.92, 0.72))
	_lbl_message.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_lbl_message.add_theme_constant_override("outline_size", 5)
	_lbl_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	couche.add_child(_lbl_message)

	# La fiche du navire : une petite carte dans le coin, et non plus un bandeau
	# qui barre l'écran. Un fond pleine largeur coûtait soixante-dix pixels de
	# mer sur toute la largeur pour n'y porter que deux lignes de texte, et la
	# carte est ce qu'on est venu regarder.
	#
	# Elle se dimensionne sur son contenu : ancrée par son coin bas-gauche, on ne
	# lui fixe que ses marges de ce côté-là et le PanelContainer trouve le reste.
	var fiche := PanelContainer.new()
	fiche.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	fiche.grow_horizontal = Control.GROW_DIRECTION_END
	fiche.grow_vertical = Control.GROW_DIRECTION_BEGIN
	fiche.offset_left = MARGE_FICHE.x
	fiche.offset_bottom = -MARGE_FICHE.y
	fiche.add_theme_stylebox_override("panel", _style(bois))
	couche.add_child(fiche)

	var infos := VBoxContainer.new()
	infos.add_theme_constant_override("separation", 2)
	fiche.add_child(infos)

	var nom := Label.new()
	nom.text = "Sloop « Aurore »"
	nom.add_theme_font_size_override("font_size", 18)
	nom.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	infos.add_child(nom)

	_lbl_statut = Label.new()
	_lbl_statut.add_theme_font_size_override("font_size", 14)
	_lbl_statut.add_theme_color_override("font_color", Color(0.84, 0.70, 0.32))
	infos.add_child(_lbl_statut)

	# Ce que le navire porte, et l'or en caisse : on veut savoir sa cargaison sans
	# ouvrir le comptoir.
	_lbl_cargaison = Label.new()
	_lbl_cargaison.add_theme_font_size_override("font_size", 13)
	_lbl_cargaison.add_theme_color_override("font_color", Color(0.90, 0.86, 0.74))
	infos.add_child(_lbl_cargaison)


func _style(couleur: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = couleur
	sb.border_color = Color(0.32, 0.22, 0.14)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _maj_hud() -> void:
	var etat := sim.etat_temps()

	# La fiche montre le CONVOI SÉLECTIONNÉ (celui qu'on commande).
	var sel := _convoi_par_indice(_convoi_selectionne)
	var nom_convoi := String(sel.get("nom", "Convoi")) if not sel.is_empty() else ""
	if sel.is_empty():
		_lbl_statut.text = "Aucun convoi"
	elif bool(sel.get("a_quai", false)):
		var p := _port_par_cle(String(sel.get("ville", "")))
		_lbl_statut.text = "%s — à quai à %s (%s)" % [
			nom_convoi, String(p.get("nom", "?")), String(p.get("nation", ""))]
	else:
		var pd := _port_par_cle(String(sel.get("destination", "")))
		var dn := String(pd.get("nom", ""))
		_lbl_statut.text = ("%s — en mer" % nom_convoi) if dn == "" \
			else ("%s — cap sur %s" % [nom_convoi, dn])

	# La planche droite : l'or en caisse, et les convois comptés en mer et à quai
	# — c'est ce que PR3 met derrière `tf_on_sea` et `tf_anchor`.
	if _hud_droite != null:
		var compagnie := sim.etat_compagnie()
		var convois := sim.convois_joueur()
		var en_mer := 0
		var a_quai := 0
		for m in convois:
			if bool((m as Dictionary).get("a_quai", false)):
				a_quai += 1
			else:
				en_mer += 1
		# Le rang est un NUMÉRO côté sim ; la planche va chercher son nom dans la
		# table de textes du jeu. Défaut -1 = inconnu, et le champ reste vide.
		_hud_droite.poser(int(compagnie.get("or_", 0)), en_mer, a_quai,
			int(compagnie.get("rang", -1)))

		# LA VIGNETTE DU CONVOI CHOISI. PR3 l'ouvre dès qu'un convoi est
		# sélectionné et la referme sinon — d'où le `visible` plutôt qu'une
		# vignette vide qui occuperait le coin pour rien.
		#
		# Le message de situation vient des mots DU JEU : à quai, PR3 nomme le
		# port ; en mer, il dit « En mer » (`ID_GUI_CONVOY_ON_SEA`). Les autres
		# états qu'il connaît — bataille, réparations, raid — n'existent pas
		# encore dans la simulation, donc on ne les invente pas.
		if _vignette != null:
			var vu := _convoi_par_indice(_convoi_selectionne)
			_vignette.visible = not vu.is_empty()
			if not vu.is_empty():
				# `situation` et non `etat` : `_maj_hud` déclare déjà un `etat`
				# pour la date, et GDScript les met dans la MÊME portée. C'est le
				# quatrième nom que ce fichier me force à distinguer, après
				# `sel`/`choisi`, `somme`/`cumul` et `centre`/`est_centre`.
				var situation := LocaPR3.propre("ID_GUI_CONVOY_ON_SEA", "En mer")
				if bool(vu.get("a_quai", false)):
					var p := _port_par_cle(String(vu.get("ville", "")))
					if not p.is_empty():
						situation = String(p.get("nom", ""))
				_vignette.poser_entete(String(vu.get("nom", "")), situation)
				_vignette.poser_details(vu)
				_vignette.poser_route(vu)
				_vignette.poser_cargaison(vu.get("lots", []))
		# LA MINIMAP NE MONTRE QUE LES VILLES DÉCOUVERTES, comme la grande carte :
		# « d'autres villes vont apparaître quand vous les découvrirez »
		# (`ID_PLAYER_TIPP_A00_TEXT`). Elle n'est donc plus posée une fois pour
		# toutes — `poser_villes` se rebâtit quand le compte change.
		#
		# LE FILTRAGE EST FAIT ICI, PAR LA CARTE, et pas dans la planche : celle-ci
		# ne reçoit que des données simples et ignore la simulation, ce qui est
		# exactement ce qui permet à `test_minimap` de l'exercer seule. Lui passer
		# `sim` pour la commodité casserait cette propriété.
		var villes_vues: Array = []
		for p in ports:
			if sim.ville_decouverte(String((p as Dictionary).get("cle", ""))):
				villes_vues.append(p)
		_hud_droite.poser_villes(villes_vues, proj)
		_hud_droite.poser_convois(convois, proj)
		# Les routes de TOUS les convois, telles que la SIM les suit — `m.route`,
		# pas un chemin recalculé pour l'occasion. La planche distingue elle-même
		# le convoi choisi par son champ `selectionne`, exactement comme elle le
		# fait déjà pour les pastilles : rien à trier ici.
		_hud_droite.poser_routes(convois, proj)
		# Le cadre de vue. On prend le centre VU (`get_screen_center_position`)
		# et non `position` : les bornes de la caméra écartent les deux dès
		# qu'on longe un bord de la carte.
		if _cam != null:
			var demi := get_viewport_rect().size / (2.0 * _zoom)
			_hud_droite.poser_vue(proj,
				Rect2(_cam.get_screen_center_position() - demi, demi * 2.0))

	# La cargaison du convoi sélectionné et l'or en caisse.
	if _lbl_cargaison != null:
		var c := sim.etat_compagnie()
		var cargo := String(c.get("cargaison", "sur lest"))
		_lbl_cargaison.text = "%d pièces  ·  cale %d/%d  ·  %s" % [
			int(c.get("or_", 0)), int(c.get("charge", 0)),
			int(c.get("capacite", 0)), cargo]

	# La planche porte la date et l'allure. Elle lit l'indice DU CALENDRIER plutôt
	# que de retenir le dernier clic : la vitesse change aussi au clavier et,
	# pendant un survol, sans qu'on ait touché aux boutons.
	if _hud_planche != null:
		_hud_planche.poser(String(etat["date"]), int(etat["indice"]),
			bool(etat.get("survol", false)))

	var maintenant := Time.get_ticks_msec() / 1000.0
	if _mode_edition:
		_lbl_message.text = _message if maintenant < _message_fin 			else "Édition — glisse une ville le long d'une côte, Ctrl+S pour enregistrer, F2 pour sortir"
	elif maintenant < _message_fin:
		_lbl_message.text = _message
	else:
		_lbl_message.text = ""


# --- utilitaires --------------------------------------------------------------

func _port_par_cle(cle: String) -> Dictionary:
	for p in ports:
		if p["cle"] == cle:
			return p
	# À défaut, le premier port — et rien du tout si la table n'est pas encore
	# chargée : cette fonction est appelée au démarrage, avant elle.
	return ports[0] if not ports.is_empty() else {}


func _port_le_plus_proche() -> Dictionary:
	var ref := _pos_monde_convoi_selectionne()
	var meilleur: Dictionary = ports[0]
	var d := INF
	for p in ports:
		var rade: Vector3 = p["rade"]
		var dist := ref.distance_to(Vector2(rade.x, rade.z))
		if dist < d:
			d = dist
			meilleur = p
	return meilleur


# La position MONDE du convoi sélectionné (pour trouver le port le plus proche).
func _pos_monde_convoi_selectionne() -> Vector2:
	var m := _convoi_par_indice(_convoi_selectionne)
	if not m.is_empty():
		return m["position"]
	return navire.position


# Outil : `-- --capture <fichier.png> [secondes]`
func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_WM_SIZE_CHANGED and _cam != null and proj != null and proj.valide:
		_recalculer_zoom_min()


func _capture_auto() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--capture")
	if i < 0 or i + 1 >= args.size():
		return
	var delai := 3.0
	if i + 2 < args.size() and args[i + 2].is_valid_float():
		delai = float(args[i + 2])
	if args.has("--edition"):
		_mode_edition = true
	if args.has("--comptoir"):
		_ouvrir_comptoir(_port_a_quai())
	if args.has("--infos-ville"):
		_ouvrir_infos_ville(_ville_regardee())
	var cn := args.find("--comptoir-nu")
	if cn >= 0 and cn + 1 < args.size():
		_ouvrir_comptoir(_port_a_quai())
		await get_tree().process_frame
		await _comptoir.capturer_plan(args[cn + 1])
		get_tree().quit()
		return
	var z := args.find("--zoom")

	await get_tree().create_timer(delai).timeout

	# Le zoom se pose APRES l'attente, pas avant : la fenêtre s'ouvre puis se
	# redimensionne, et le redimensionnement recalcule la borne basse et rabote
	# le zoom au passage. Posé avant, il valait ce qu'il voulait au moment de la
	# prise — deux captures lancées avec le même argument ne cadraient pas
	# pareil, ce qui rend toute comparaison entre deux rendus illusoire.
	if z >= 0 and z + 1 < args.size():
		_zoom = clampf(float(args[z + 1]), _zoom_min, _zoom_max)
		_cam.zoom = Vector2(_zoom, _zoom)
		if _mer != null and _mer.material != null:
			(_mer.material as ShaderMaterial).set_shader_parameter("zoom", _zoom)
		queue_redraw()
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	print("[capture] %s (%s)" % [args[i + 1], "ok" if img.save_png(args[i + 1]) == OK else "echec"])
	get_tree().quit()


# --- édition des villes -------------------------------------------------------

func _noter(texte: String) -> void:
	_message = texte
	_message_fin = Time.get_ticks_msec() / 1000.0 + 5.0


# Réécrit le bloc `Archipel.ports` de sim/archipel.lua avec les positions
# actuelles. La simulation reste la source de vérité : on n'enregistre pas des
# pixels, mais des angles de côte.
func _enregistrer_ports() -> void:
	# On écrit `villes_reglages.lua` EN ENTIER, et pas un bloc dans
	# `archipel.lua`. L'ancienne version y remplaçait la table `Archipel.ports`,
	# qui n'est plus une table littérale mais une boucle sur les données extraites
	# de Port Royale 3 : la recherche du `}` fermant serait tombée n'importe où.
	var chemin := "res://sim/villes_reglages.lua"
	var contenu: String = sim.source_reglages()
	if contenu == "":
		_noter("La simulation n'a rien renvoyé")
		return
	var sortie := FileAccess.open(chemin, FileAccess.WRITE)
	if sortie == null:
		_noter("Écriture impossible : " + chemin)
		print(contenu)
		return
	sortie.store_string(contenu)
	sortie.close()
	_noter("Placements enregistrés dans sim/villes_reglages.lua")
	print("[edition] villes_reglages.lua mis a jour" + char(10) + contenu)


# En édition, deux poignées par ville : le réticule est le point RÉEL (celui du
# mouillage et du clic), le village lui-même est son IMAGE. Un trait les relie
# quand ils ont été séparés.
func _dessiner_reperes_edition() -> void:
	var e := 1.0 / _zoom
	for port in ports:
		var b: Vector3 = port["bourg"]
		var reel := proj.vers_carte(b.x, b.z)
		var dec: Vector2 = port.get("decalage", Vector2.ZERO)
		var saisi: bool = (not _port_saisi.is_empty()
						   and _port_saisi.get("cle", "") == port["cle"])

		if dec.length_squared() > 1.0:
			var img := proj.vers_carte(b.x + dec.x, b.z + dec.y)
			var lien := Color(1, 0.85, 0.35, 0.55)
			var d := reel.distance_to(img)
			var u := (img - reel) / maxf(d, 0.001)
			var t := 0.0
			while t < d:
				var t2: float = minf(t + 8.0 * e, d)
				draw_line(reel + u * t, reel + u * t2, lien, 1.2 * e)
				t = t2 + 6.0 * e

		var couleur := Color(1, 0.85, 0.25) if saisi else Color(1, 1, 1, 0.7)
		draw_arc(reel, 12 * e, 0, TAU, 24, couleur, 2.0 * e)
		draw_line(reel - Vector2(7 * e, 0), reel + Vector2(7 * e, 0), couleur, 1.5 * e)
		draw_line(reel - Vector2(0, 7 * e), reel + Vector2(0, 7 * e), couleur, 1.5 * e)


# Que saisit-on sous le curseur ? Le réticule l'emporte sur le village, sinon
# on ne pourrait plus attraper le point réel d'une ville qui le recouvre.
func _saisir(pos: Vector2) -> Dictionary:
	var seuil := 16.0 / _zoom

	for port in ports:
		var b: Vector3 = port["bourg"]
		if proj.vers_carte(b.x, b.z).distance_to(pos) <= seuil:
			_saisie_image = false
			return port

	for port in ports:
		var r: Rect2 = _rects_villes.get(port["cle"], Rect2())
		if r.has_point(pos):
			_saisie_image = true
			return port

	return {}
