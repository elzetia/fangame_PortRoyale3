# Le menu radial d'une ville — la couronne `Scene_Radial_Town` de Port Royale 3.
#
# TOUT CE QUI SUIT EST MESURÉ, pas deviné. Les sources sont deux fichiers que
# `outils/swf_*.py` tire du jeu, et qui vivent dans `reference_pr3/` (sous droits,
# ignoré par git) :
#
#   agencement/ingame_radial_town.json  la scène, ses groupes et leurs positions
#   ingame_radial_town/caracteres.txt   ce que chaque image est, et où elle se pose
#
# LA GÉOMÉTRIE RELEVÉE, en pixels de la scène Flash :
#
#   centre de la couronne      (335,5 ; 334)
#   rayon centre -> pétale     208      (haut 207, gauche 207,5, diagonales 209,6)
#   disque d'un pétale         Ø 142    (4.png)
#   anneau de sélection        Ø 192    (8.png, plus sa queue : 192 x 246)
#   arc des marchandises       r ≈ 83, du demi-cercle SOUS le centre
#
# HUIT PÉTALES, ET NON SEPT. Une version précédente de ce menu n'en comptait que
# sept : `ingame_radial_town.json` ne place que sept groupes d'éléments, et j'en
# avais conclu que le huitième emplacement restait vide. C'est faux — la table de
# localisation nomme les HUIT directions (`ID_ACTION_RADIAL_DIR_*`), et la
# huitième s'appelle « Docks ». Le groupe manquait parce que son contenu est
# dessiné par le MOTEUR, pas par Flash (voir plus bas).
#
# LES LIBELLÉS SONT CEUX DU JEU, pris dans sa propre table :
#
#   haut         ID_ACTION_RADIAL_DIR_UP         Info ville
#   haut-droite  ID_ACTION_RADIAL_DIR_UPRIGHT    Docks
#   droite       ID_ACTION_RADIAL_DIR_RIGHT      Chantier naval
#   bas-droite   ID_ACTION_RADIAL_DIR_DOWNRIGHT  Taverne
#   bas          ID_ACTION_RADIAL_DIR_DOWN       Eglise
#   bas-gauche   ID_ACTION_RADIAL_DIR_DOWNLEFT   Hôtel de ville
#   gauche       ID_ACTION_RADIAL_DIR_LEFT       Capitainerie
#   haut-gauche  ID_ACTION_RADIAL_DIR_UPLEFT     Entrepôt
#
# DEUX ERREURS DE LA VERSION PRÉCÉDENTE, CORRIGÉES ICI :
#
#  1. Le pétale bas-gauche s'appelait « Palais ». Son groupe Flash se nomme bien
#     `Group_Radial_Palace_19`, mais le jeu l'AFFICHE « Hôtel de ville ». Le nom
#     interne n'est pas le nom montré au joueur.
#  2. Le négoce était rattaché à l'ENTREPÔT, au motif que « PR3 n'a pas de pétale
#     marché ». Il en a un : les DOCKS. `dialog_storage` est un écran de gestion
#     d'entrepôt (aperçu, bilan, administrateur) tandis que `dialog_trade` porte
#     `Tab_Trade_Town_Office` et `Tab_Trade_Office_Convoy`, et refuse d'ouvrir
#     sans « un entrepôt OU UN CONVOI dans la ville ». Le radial pirate tranche
#     définitivement : sa direction haut s'appelle « Dock du port ».
#     Le comptoir est donc aux Docks, et l'Entrepôt reste gris faute d'écran.
#
# L'ART QUE PR3 FOURNIT, ET CELUI QU'IL NE FOURNIT PAS. `caracteres.txt` montre
# que les caractères 9 à 16 sont UNE MÊME IMAGE — 8.png — posée aux huit
# directions, et ses décalages retombent au pixel près sur les boutons (char15 en
# (128,333) = `bu_rad_left`). C'est l'anneau de sélection. Le char7, lui, est le
# disque gris de 4.png : l'état DÉSACTIVÉ.
#
# En revanche le FOND de la couronne est un `Visual_CR_Radial`, un
# « customrenderelement » : le moteur le dessine en code natif, il n'existe donc
# aucune image de pétale à charger. Le disque d'un pétale est tracé ici — c'est
# assumé, pas un pis-aller. Un commentaire antérieur affirmait que tout l'art des
# pétales était vectoriel et qu'il n'y avait rien à charger : à moitié faux, et
# c'est ce qui avait fait passer l'anneau et le disque gris pour inexistants.
#
# L'ILLUSTRATION DE LA VILLE N'EST PAS AU CENTRE. `Group_Radial_Town_8` la pose
# en (335,124), soit exactement sur le bouton du haut : c'est le VISAGE du pétale
# « Info ville ». Le centre, lui, ne porte que le nom, les habitants, la
# réputation, le pavillon, le type de ville et les cinq marchandises produites.
# La version précédente mettait l'illustration au centre.
#
# `Icon_Towns_Big` compte SEPT états : six illustrations (18 à 28) et un CRÂNE
# (30.png). On indexe par la taille de la ville, faute de savoir ce que PR3
# indexe — c'est un choix, et le crâne n'est pas employé.
#
# UN ÉCART ASSUMÉ SUR LES PAVILLONS : la simulation a cinq nations, dont le
# Portugal. PR3 n'en livre que quatre (Espagne 1568, Pays-Bas 1569, France 1570,
# Angleterre 1571) plus le pirate. Le Portugal garde donc sa bande de couleur :
# lui coller le drapeau d'une autre nation serait pire que ne rien montrer.
#
# Le panneau ne décide de rien : il émet un signal par pétale, la carte branche.
class_name RadialVille
extends CanvasLayer

signal infos_demandee(port: Dictionary)
signal dock_demande(port: Dictionary)          # les Docks : le négoce
signal capitainerie_demande(port: Dictionary)  # la gestion des convois
signal chantier_demande(port: Dictionary)      # acheter/réparer/construire/vendre

const BOIS       := Color(0.16, 0.11, 0.07)
const BOIS_CLAIR := Color(0.26, 0.18, 0.11)
const OR         := Color(0.86, 0.71, 0.36)
const LIN        := Color(0.921, 0.888, 0.812)
const GRIS       := Color(0.55, 0.52, 0.47)

# --- les mesures de PR3, en pixels de sa scène -------------------------------
const PR3_RAYON    := 208.0   # centre -> centre d'un pétale
const PR3_PETALE   := 142.0   # Ø du disque d'un pétale
const PR3_HALO_L   := 192.0   # l'anneau de sélection, largeur
const PR3_HALO_H   := 246.0   #   ... et hauteur, queue comprise
const PR3_CENTRE   := 150.0   # Ø du disque central (déduit de l'arc, r ≈ 83)
const PR3_GOODS_R  := 83.0    # rayon de l'arc des cinq marchandises
const PR3_GOODS_IC := 22.0    # `Visual_IconButton_Goods_NoBg`, 22 x 20

# L'ÉCHELLE est le seul chiffre choisi. Les PROPORTIONS ci-dessus sont celles du
# jeu ; on les réduit toutes du même facteur pour que la couronne tienne dans nos
# fenêtres. Un seul facteur, donc aucun rapport n'est déformé.
const ECHELLE := 0.70

const RAYON     := PR3_RAYON * ECHELLE
const R_PETALE  := PR3_PETALE * ECHELLE / 2.0
const R_CENTRE  := PR3_CENTRE * ECHELLE / 2.0
const R_GOODS   := PR3_GOODS_R * ECHELLE
const R_PRODUIT := PR3_GOODS_IC * ECHELLE / 2.0

# --- l'art du jeu -------------------------------------------------------------
const ART_DESACTIVE := "ingame_radial_town/4"    # le disque gris (char7)
const ART_HALO      := "ingame_radial_town/8"    # l'anneau de sélection (char9..16)
const ART_LOUPE     := "ingame_radial_town/33"   # « Sélectionner », sur le pétale ville

# LA BARRE À ROUE DU CENTRE, et il m'a fallu trois essais pour la trouver.
#
# `skinlib_pr3/301` (196 x 196) est la roue de bois — huit rayons, huit poignées,
# moyeu doré. `skinlib_pr3/298` (210 x 210) est son OMBRE PORTÉE : 51 % de
# transparent, 12 % d'opaque, et UNE SEULE couleur opaque, le noir pur.
#
# ELLES ÉTAIENT LÀ DEPUIS LE DÉBUT, et voici par où elles me sont passées sous le
# nez : mon inventaire de `skinlib_pr3` se faisait par NOM DE CLASSE (`Visual_*`),
# or ces deux entrées sont anonymes — des identifiants nus, invisibles à une
# recherche par nom.
#
# CE QUE J'AVAIS MIS À LA PLACE : `centercircle0`, tiré des archives du jeu, un
# anneau lumineux à huit rayons dont les angles tombaient juste. Il s'affichait en
# grand cercle pâle autour de la couronne — et une capture du jeu a montré qu'il
# n'y est pas. C'était un décalque de carte, pas le fond du radial. Les angles qui
# « tombaient juste » ne prouvaient rien : huit directions, c'est commun.
#
# MESURÉE par rayon (fraction du demi-côté) : alésage 0,04 ; moyeu plein
# 0,10-0,22 ; rayons 0,28-0,46 ; JANTE PLEINE 0,52-0,70 ; poignées jusqu'à 0,95.
#
# Fusion NORMALE : jante opaque, fond transparent. Rien à voir avec l'alpha plat
# de `centercircle0`, qui imposait l'additif.
const ART_BARRE := "skinlib_pr3/301"
const ART_BARRE_OMBRE := "skinlib_pr3/298"
# Le bord INTÉRIEUR de la jante, en fraction du demi-côté. C'est lui qui borne la
# carte d'identité posée au centre : on dimensionne donc la roue par
# `R_CENTRE / BARRE_JANTE`, ce qui pose du même coup les poignées (0,95) juste au
# bord intérieur des pétales. Les deux contraintes tombent ensemble, comme chez
# PR3 où la fiche de ville tient dans la jante.
const BARRE_JANTE := 0.52
# Les six illustrations de ville. Le septième état d'`Icon_Towns_Big` est un
# crâne (`ingame_radial_town/30`) : on ne sait pas ce qui le déclenche.
const ART_VILLES := ["ingame_radial_town/18", "ingame_radial_town/20",
	"ingame_radial_town/22", "ingame_radial_town/24",
	"ingame_radial_town/26", "ingame_radial_town/28"]

const ICN_HABITANTS  := "skinlib_pr3/1798"   # Visual_IconButton_habitants
const ICN_POUCE      := "skinlib_pr3/1438"   # Visual_IconButton_ThumbsUp
const ICN_TYPE       := "skinlib_pr3/1695"   # Visual_IconButton_Towninfo
const ICN_REPUTATION := "skinlib_pr3/1936"   # Visual_AniElement_Reputationmarker

# `Flag_*_small` de la table d'icônes, tous en 44 x 30.
const PAVILLONS := {
	"espagne": "skinlib_pr3/1568",
	"hollande": "skinlib_pr3/1569",
	"france": "skinlib_pr3/1570",
	"angleterre": "skinlib_pr3/1571",
}

# Les huit pétales, dans le sens horaire depuis le haut. `angle` en degrés,
# 0 = à droite, y vers le bas (repère écran). `sig` vide = pas encore d'écran.
const PETALES := [
	{"cle": "ville", "loca": "ID_ACTION_RADIAL_DIR_UP",
		"txt": "Info ville", "angle": -90.0, "sig": "infos"},
	{"cle": "docks", "loca": "ID_ACTION_RADIAL_DIR_UPRIGHT",
		"txt": "Docks", "angle": -45.0, "sig": "dock"},
	{"cle": "chantier", "loca": "ID_ACTION_RADIAL_DIR_RIGHT",
		"txt": "Chantier naval", "angle": 0.0, "sig": "chantier"},
	{"cle": "taverne", "loca": "ID_ACTION_RADIAL_DIR_DOWNRIGHT",
		"txt": "Taverne", "angle": 45.0, "sig": ""},
	{"cle": "eglise", "loca": "ID_ACTION_RADIAL_DIR_DOWN",
		"txt": "Eglise", "angle": 90.0, "sig": ""},
	{"cle": "hotel_ville", "loca": "ID_ACTION_RADIAL_DIR_DOWNLEFT",
		"txt": "Hôtel de ville", "angle": 135.0, "sig": ""},
	{"cle": "capitainerie", "loca": "ID_ACTION_RADIAL_DIR_LEFT",
		"txt": "Capitainerie", "angle": 180.0, "sig": "capitainerie"},
	{"cle": "entrepot", "loca": "ID_ACTION_RADIAL_DIR_UPLEFT",
		"txt": "Entrepôt", "angle": -135.0, "sig": ""},
]

var _port: Dictionary
var _sim                       # facultatif : réputation et compteurs
var _a_convoi := false
var _voile: ColrRectFerme
var _racine: Control
var _icones: Dictionary = {}


# Un ColorRect qui se ferme au clic — déclaré à part pour capter le clic hors menu.
class ColrRectFerme extends ColorRect:
	signal clic_dehors
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			clic_dehors.emit()


func _ready() -> void:
	_batir_socle()


# Le voile qui ferme au clic, et la racine où vivent les pétales et le centre.
#
# BÂTI À PART, ET APPELÉ AUSSI DEPUIS `ouvrir`, pour que l'ouverture ne dépende
# pas de l'ordre dans lequel Godot a propagé `_ready`. En jeu la question ne se
# pose pas — la carte ajoute le menu dans son propre `_ready` et ne l'ouvre qu'au
# clic, bien plus tard. C'est un appelant PRÉCOCE qui trouvait `_racine` nul.
# L'appel est sans effet la deuxième fois : le socle ne se bâtit qu'une seule.
func _batir_socle() -> void:
	if _racine != null:
		return
	layer = 62
	visible = false
	_voile = ColrRectFerme.new()
	_voile.color = Color(0, 0, 0, 0.35)
	_voile.anchor_right = 1.0
	_voile.anchor_bottom = 1.0
	_voile.clic_dehors.connect(fermer)
	add_child(_voile)
	_racine = Control.new()
	_racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.anchor_right = 1.0
	_racine.anchor_bottom = 1.0
	add_child(_racine)


# Ouvre la couronne autour de `ecran_pos` (pixels écran). `a_convoi` dit si un
# convoi du joueur est à ce port : sans lui, ni négoce ni chantier — comme PR3,
# on n'entre au port qu'avec un navire. `sim_ref` est FACULTATIF : sans lui le
# centre affiche ce que porte déjà la fiche du port, avec lui il ajoute la
# réputation et les compteurs. L'ancienne signature à trois arguments reste donc
# valide.
func ouvrir(port: Dictionary, ecran_pos: Vector2, a_convoi: bool, sim_ref = null) -> void:
	_batir_socle()
	_port = port
	_sim = sim_ref
	_a_convoi = a_convoi
	# ON RETIRE DE L'ARBRE AVANT DE LIBÉRER. `queue_free` est DIFFÉRÉ : le nœud ne
	# s'en va qu'en fin d'image. Deux ouvertures dans la même image laissaient donc
	# la couronne PRÉCÉDENTE en place sous la nouvelle — les pétales d'une autre
	# ville par-dessous, et leurs boutons encore cliquables. `remove_child` coupe
	# sur-le-champ, `queue_free` fait le ménage ensuite.
	for e in _racine.get_children():
		_racine.remove_child(e)
		e.queue_free()

	# On garde la couronne entière à l'écran : le centre est repoussé des bords.
	var vp := get_viewport().get_visible_rect().size
	var marge := RAYON + R_PETALE + 10.0
	var c := Vector2(
		clampf(ecran_pos.x, marge, vp.x - marge),
		clampf(ecran_pos.y, marge, vp.y - marge))

	_roue(c)            # la roue du jeu, SOUS tout le reste (prof 1 chez PR3)
	for p in PETALES:
		_petale(c, p)
	_centre(c)          # le centre EN DERNIER : il passe au-dessus des pétales
	visible = true


func fermer() -> void:
	visible = false


# Le libellé de PR3 pour ce pétale, ou le nôtre si la table n'est pas là.
func _libelle(p: Dictionary) -> String:
	return LocaPR3.texte(String(p["loca"]), String(p["txt"]))


# La barre à roue au centre de la couronne : son ombre d'abord, puis elle.
# Absente, on ne dessine rien de plus — les pétales et la fiche se suffisent.
func _roue(c: Vector2) -> void:
	var tex := SkinPR3.texture(ART_BARRE)
	if tex == null:
		return
	var demi := R_CENTRE / BARRE_JANTE

	var ombre := SkinPR3.texture(ART_BARRE_OMBRE)
	if ombre != null:
		# L'ombre est dessinée plus large que la roue dans le jeu — 210 contre
		# 196 — et l'on garde ce rapport plutôt que de les caler bord à bord.
		var do := demi * 210.0 / 196.0
		var tro := TextureRect.new()
		tro.texture = ombre
		tro.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tro.size = Vector2(do, do) * 2.0
		tro.position = c - Vector2(do, do) + Vector2(2.0, 3.0)
		tro.modulate = Color(1, 1, 1, 0.45)
		tro.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_racine.add_child(tro)

	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.size = Vector2(demi, demi) * 2.0
	tr.position = c - Vector2(demi, demi)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(tr)


# --- les pétales -------------------------------------------------------------

func _petale(c: Vector2, p: Dictionary) -> void:
	var a := deg_to_rad(float(p["angle"]))
	var pos := c + Vector2(cos(a), sin(a)) * RAYON
	var actif := _actif(String(p["cle"]))

	# 1. L'ANNEAU DE SÉLECTION, sous le pétale et caché jusqu'au survol.
	#
	# L'image porte son anneau en haut et une QUEUE en dessous, qui pointe vers le
	# centre de la couronne. Dans la source la queue va vers le bas ; pour un
	# pétale posé à l'angle θ elle doit viser le centre, donc l'image tourne de
	# θ + 90°. Vérification sur le cas du haut (θ = -90) : rotation nulle, queue
	# vers le bas, centre en dessous. C'est bien ce que fait le jeu.
	var halo: TextureRect = null
	var tex_halo := SkinPR3.texture(ART_HALO)
	if tex_halo != null and actif:
		halo = TextureRect.new()
		halo.texture = tex_halo
		halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		halo.size = Vector2(PR3_HALO_L, PR3_HALO_H) * ECHELLE
		# Le pivot est le centre de l'ANNEAU, pas celui de l'image : l'anneau
		# occupe le carré supérieur (192 x 192), la queue pend sous lui.
		halo.pivot_offset = Vector2(PR3_HALO_L, PR3_HALO_L) * ECHELLE / 2.0
		halo.position = pos - halo.pivot_offset
		halo.rotation = a + PI / 2.0
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		halo.visible = false
		_racine.add_child(halo)

	# 2. LE DISQUE du pétale. La ROUE du jeu passe dessous (voir `_roue`) ; ce
	#    disque-ci reste tracé, car PR3 n'a pas d'image par pétale — sa roue porte
	#    les huit secteurs d'un seul tenant.
	var b := Button.new()
	b.text = _libelle(p)
	b.size = Vector2(R_PETALE * 2, R_PETALE * 2)
	b.position = pos - Vector2(R_PETALE, R_PETALE)
	b.add_theme_font_size_override("font_size", 12)
	b.clip_text = false
	b.autowrap_mode = TextServer.AUTOWRAP_WORD

	var st := StyleBoxFlat.new()
	st.bg_color = LIN if actif else Color(LIN.r, LIN.g, LIN.b, 0.45)
	st.border_color = BOIS_CLAIR if actif else GRIS
	st.set_border_width_all(3)
	st.set_corner_radius_all(int(R_PETALE))
	st.set_content_margin_all(4)
	b.add_theme_stylebox_override("normal", st)
	var sh := st.duplicate() as StyleBoxFlat
	sh.bg_color = OR
	b.add_theme_stylebox_override("hover", sh if actif else st)
	b.add_theme_color_override("font_color", BOIS if actif else GRIS)
	b.add_theme_color_override("font_hover_color", BOIS)
	b.disabled = not actif
	if actif:
		b.pressed.connect(_sur_petale.bind(String(p["sig"])))
		if halo != null:
			b.mouse_entered.connect(func() -> void: halo.visible = true)
			b.mouse_exited.connect(func() -> void: halo.visible = false)
	_racine.add_child(b)

	# 3. LE VISAGE DU PÉTALE « INFO VILLE » : l'illustration de la ville, que PR3
	#    pose exactement sur ce bouton.
	if String(p["cle"]) == "ville":
		_illustration(pos)

	# 4. LE DISQUE GRIS de PR3 par-dessus ce qui ne mène nulle part.
	if not actif:
		var gris := SkinPR3.texture(ART_DESACTIVE)
		if gris != null:
			var tr := TextureRect.new()
			tr.texture = gris
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.size = Vector2(PR3_PETALE, PR3_PETALE) * ECHELLE
			tr.position = pos - tr.size / 2.0
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_racine.add_child(tr)

	var compteur := _compteur(String(p["cle"]))
	if compteur != "":
		_texte(pos + Vector2(0, R_PETALE - 12), compteur, 11, BOIS_CLAIR, 90)


# L'illustration de la ville, sur le pétale du haut. PR3 en a six, plus un crâne
# dont on ignore le déclencheur ; on indexe par la taille (1 bourg, 2 ville,
# 3 grande ville), et c'est un choix faute de mieux.
func _illustration(pos: Vector2) -> void:
	var taille := int(_port.get("taille", 1))
	var vue := SkinPR3.texture(String(ART_VILLES[clampi(taille - 1, 0, ART_VILLES.size() - 1)]))
	if vue == null:
		return
	var tr := TextureRect.new()
	tr.texture = vue
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# L'illustration fait 146 x 134 pour un disque de 142 : on la rentre un peu
	# pour qu'elle ne déborde pas du pétale.
	tr.size = Vector2(R_PETALE * 1.7, R_PETALE * 1.7 * 134.0 / 146.0)
	tr.position = pos - tr.size / 2.0 - Vector2(0, R_PETALE * 0.18)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(tr)
	# La loupe « Sélectionner » (`ID_ACTION_RADIAL_CHOOSE`), en coin.
	var loupe := SkinPR3.texture(ART_LOUPE)
	if loupe != null:
		var l := TextureRect.new()
		l.texture = loupe
		l.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		l.size = Vector2(44, 48) * ECHELLE * 0.55
		l.position = pos + Vector2(R_PETALE * 0.42, -R_PETALE * 0.92)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_racine.add_child(l)


# Un pétale est actif s'il mène quelque part ET si le joueur peut y entrer.
func _actif(cle: String) -> bool:
	match cle:
		"ville":
			return true
		"docks", "capitainerie":
			return _a_convoi
		"chantier":
			return _a_convoi and bool(_port.get("chantier", false))
		_:
			# Entrepôt, hôtel de ville, église, taverne : pas encore d'écran.
			return false


# Les chiffres que PR3 pose sur ses pétales : ses groupes `Harbourmaster` et
# `Shipyard` portent `tf_ships` et `tf_convoys` avec leurs icônes.
func _compteur(cle: String) -> String:
	if _sim == null:
		return ""
	var port_cle := String(_port.get("cle", ""))
	if port_cle == "":
		return ""
	match cle:
		"capitainerie":
			if not _sim.has_method("convois_joueur"):
				return ""
			var n := 0
			for m in _sim.convois_joueur():
				var d: Dictionary = m
				if String(d.get("ville", "")) == port_cle:
					n += 1
			return "%d convoi(s)" % n if n > 0 else ""
	# PR3 pose aussi un nombre de navires sur le pétale CHANTIER. On ne l'affiche
	# pas : `chantier_file()` rend la file GLOBALE du joueur, pas celle de ce
	# port — le même chiffre s'afficherait dans les soixante villes. Un compteur
	# faux est pire qu'un compteur absent ; il reviendra quand la file saura dire
	# où chaque navire se construit.
	return ""


# --- le centre ---------------------------------------------------------------

func _centre(c: Vector2) -> void:
	var d := R_CENTRE * 2.0
	var disque := Panel.new()
	disque.size = Vector2(d, d)
	disque.position = c - Vector2(d, d) / 2.0
	var st := StyleBoxFlat.new()
	st.bg_color = LIN
	st.border_color = BOIS
	st.set_border_width_all(4)
	st.set_corner_radius_all(int(d / 2.0))
	disque.add_theme_stylebox_override("panel", st)
	_racine.add_child(disque)

	# Le liseré à la couleur de la nation, sous le pavillon.
	var coul: Color = _port.get("couleur", OR)
	var anneau := Panel.new()
	anneau.size = Vector2(d - 12, d - 12)
	anneau.position = c - Vector2(d - 12, d - 12) / 2.0
	var sa := StyleBoxFlat.new()
	sa.bg_color = Color(0, 0, 0, 0)
	sa.border_color = coul
	sa.set_border_width_all(3)
	sa.set_corner_radius_all(int((d - 12) / 2.0))
	anneau.add_theme_stylebox_override("panel", sa)
	_racine.add_child(anneau)

	# Le PAVILLON et le TYPE DE VILLE, au-dessus du nom — `flag` et `towntype`
	# de PR3, posés en (14,-32) et (36,-32) dans son groupe central.
	var pav := String(PAVILLONS.get(String(_port.get("nation_cle", "")), ""))
	if pav != "":
		_image(pav, c + Vector2(-16, -R_CENTRE - 2), Vector2(44, 30) * ECHELLE * 0.8)
	_image(ICN_TYPE, c + Vector2(16, -R_CENTRE - 2), Vector2(22, 24) * ECHELLE * 0.8)

	_texte(c + Vector2(0, -R_CENTRE * 0.42), String(_port.get("nom", "?")), 14, BOIS, 150)

	# Habitants et réputation, comme les `tf_citizen` / `tf_rep_val` de PR3, avec
	# leurs icônes : `Visual_IconButton_habitants` et le marqueur de réputation.
	var hab := int(_port.get("habitants", 0))
	_image(ICN_HABITANTS, c + Vector2(-26, R_CENTRE * 0.12), Vector2(42, 30) * ECHELLE * 0.6)
	_texte(c + Vector2(8, R_CENTRE * 0.12), "%d" % hab, 11, BOIS, 80)
	if _sim != null and _sim.has_method("etat_ville"):
		var e: Dictionary = _sim.etat_ville(String(_port.get("cle", "")))
		if e.has("reputation"):
			var rep := int(e["reputation"])
			_image(ICN_REPUTATION, c + Vector2(-26, R_CENTRE * 0.52),
					Vector2(32, 32) * ECHELLE * 0.6)
			_texte(c + Vector2(8, R_CENTRE * 0.52), "%d" % rep, 11, BOIS_CLAIR, 80)
			# Le pouce levé de PR3 (`icn_tt_1`) quand la ville nous apprécie.
			if rep >= 50:
				_image(ICN_POUCE, c + Vector2(R_CENTRE * 0.62, R_CENTRE * 0.52),
						Vector2(28, 28) * ECHELLE * 0.6)

	_produits(c)


# Les cinq marchandises produites, sur le DEMI-CERCLE sous le centre — le
# `gr_goods` de PR3. Ses cinq positions relevées tombent aux angles 180, 139, 92,
# 42 et 0 degrés sur un rayon d'environ 83 : un demi-tour complet, et non le
# petit éventail de 86° qu'affichait la version précédente.
func _produits(c: Vector2) -> void:
	var prod: Array = _port.get("produits", [])
	if prod.is_empty():
		return
	var n := mini(prod.size(), 5)
	for i in n:
		var t := float(i) / maxf(1.0, float(n - 1))
		var ang := deg_to_rad(lerpf(180.0, 0.0, t))
		# `sin` positif vers le bas en repère écran : l'arc passe donc SOUS le
		# centre, comme celui du jeu.
		var pos := c + Vector2(cos(ang), sin(ang)) * R_GOODS
		var pastille := Panel.new()
		pastille.size = Vector2(R_PRODUIT * 2, R_PRODUIT * 2)
		pastille.position = pos - Vector2(R_PRODUIT, R_PRODUIT)
		var sp := StyleBoxFlat.new()
		sp.bg_color = LIN
		sp.border_color = BOIS_CLAIR
		sp.set_border_width_all(2)
		sp.set_corner_radius_all(int(R_PRODUIT))
		pastille.add_theme_stylebox_override("panel", sp)
		_racine.add_child(pastille)
		var tex := _icone_marchandise(String(prod[i]))
		if tex != null:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.size = Vector2(R_PRODUIT * 1.7, R_PRODUIT * 1.7)
			tr.position = pos - tr.size / 2.0
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_racine.add_child(tr)


func _icone_marchandise(cle: String) -> Texture2D:
	if _icones.has(cle):
		return _icones[cle]
	var chemin := "res://sprites/marchandises/%s.png" % cle
	var tex: Texture2D = load(chemin) if ResourceLoader.exists(chemin) else null
	_icones[cle] = tex
	return tex


# --- petits outils ------------------------------------------------------------

# Une image du jeu, centrée sur `centre`. Ne fait rien si l'art n'est pas là :
# comme partout, l'absence de `reference_pr3/` ne change que le look.
func _image(cle: String, centre: Vector2, taille: Vector2) -> void:
	var tex := SkinPR3.texture(cle)
	if tex == null:
		return
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size = taille
	tr.position = centre - taille / 2.0
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(tr)


func _texte(centre: Vector2, txt: String, taille: int, coul: Color, largeur: float) -> void:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(largeur, 16)
	l.position = centre - Vector2(largeur / 2.0, 8)
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", coul)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(l)


func _sur_petale(sig: String) -> void:
	fermer()
	match sig:
		"infos": infos_demandee.emit(_port)
		"dock": dock_demande.emit(_port)
		"capitainerie": capitainerie_demande.emit(_port)
		"chantier": chantier_demande.emit(_port)
