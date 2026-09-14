# Le menu radial d'une ville — la couronne `Scene_Radial_Town` de Port Royale 3.
#
# CE QUE PR3 FAIT, relevé dans son propre agencement (`outils/swf_arbre.py` sur
# `ingame_radial_town.swf`) et non deviné :
#
#   sept pétales autour d'un centre, aux huit directions d'une couronne —
#     haut-gauche  entrepôt    (le négoce : c'est là qu'on échange)
#     haut         ville       (la fiche de la ville)
#     gauche       capitainerie (navires ET convois à l'ancre)
#     droite       chantier    (nombre de navires)
#     bas-gauche   palais
#     bas          église
#     bas-droite   taverne
#
#   et un CENTRE qui n'est pas un simple disque : nom de la ville, habitants avec
#   leur icône, réputation avec son marqueur, pavillon de la nation, type de
#   ville, et LES CINQ MARCHANDISES PRODUITES disposées en arc.
#
# Autrement dit, chaque pétale de PR3 est un petit tableau de bord, pas une
# étiquette. La version précédente n'avait que quatre boutons de texte en
# éventail — d'où l'écart de tenue avec l'original.
#
# DEUX CHOIX ASSUMÉS, pour ne pas laisser croire à une copie exacte :
#
#  1. PR3 n'a pas de pétale « Marché » : son lieu de négoce est l'ENTREPÔT. Notre
#     comptoir y est donc rattaché, ce qui garde les quatre écrans du clone
#     atteignables tout en respectant la disposition d'origine.
#  2. Église, taverne et palais existent dans PR3 mais pas encore ici : ils sont
#     dessinés DÉSACTIVÉS, comme PR3 le fait avec son propre calque `disable`,
#     plutôt qu'omis. Un menu amputé ment sur le jeu ; un menu grisé dit ce qui
#     reste à construire.
#
# L'ART DES PÉTALES de PR3 est du dessin vectoriel : l'extracteur n'en sort pas
# d'image, et il n'y en a donc pas à charger. Les illustrations de VILLE, elles,
# existent (`ingame_radial_town/18..28.png`, sept états) et sont utilisées quand
# l'extraction locale est là. Comme partout dans le projet, leur absence ne
# change que le look : `SkinPR3.texture()` rend `null` et l'on retombe sur le
# tracé maison.
#
# Le panneau ne décide de rien : il émet un signal par pétale, la carte branche.
class_name RadialVille
extends CanvasLayer

signal infos_demandee(port: Dictionary)
signal dock_demande(port: Dictionary)          # l'entrepôt : le négoce
signal capitainerie_demande(port: Dictionary)  # la gestion des convois
signal chantier_demande(port: Dictionary)      # acheter/réparer/construire/vendre

const BOIS       := Color(0.16, 0.11, 0.07)
const BOIS_CLAIR := Color(0.26, 0.18, 0.11)
const OR         := Color(0.86, 0.71, 0.36)
const LIN        := Color(0.921, 0.888, 0.812)
const GRIS       := Color(0.55, 0.52, 0.47)

const RAYON    := 132.0   # centre -> pétale
const R_PETALE := 48.0
const R_CENTRE := 62.0
const R_PRODUIT := 13.0   # les pastilles de marchandises, en arc sous le centre

# Les sept pétales de PR3, dans l'ordre de sa couronne. `angle` en degrés, 0 = à
# droite, sens horaire (repère écran). `signal` vide = pas encore d'écran.
const PETALES := [
	{"cle": "entrepot",     "txt": "Entrepôt",      "angle": -135.0, "sig": "dock"},
	{"cle": "ville",        "txt": "Ville",         "angle":  -90.0, "sig": "infos"},
	{"cle": "chantier",     "txt": "Chantier",      "angle":    0.0, "sig": "chantier"},
	{"cle": "capitainerie", "txt": "Bureau du port","angle":  180.0, "sig": "capitainerie"},
	{"cle": "palais",       "txt": "Palais",        "angle":  135.0, "sig": ""},
	{"cle": "eglise",       "txt": "Église",        "angle":   90.0, "sig": ""},
	{"cle": "taverne",      "txt": "Taverne",       "angle":   45.0, "sig": ""},
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
	_port = port
	_sim = sim_ref
	_a_convoi = a_convoi
	for e in _racine.get_children():
		e.queue_free()

	# On garde la couronne entière à l'écran : le centre est repoussé des bords.
	var vp := get_viewport().get_visible_rect().size
	var marge := RAYON + R_PETALE + 10.0
	var c := Vector2(
		clampf(ecran_pos.x, marge, vp.x - marge),
		clampf(ecran_pos.y, marge, vp.y - marge))

	for p in PETALES:
		_petale(c, p)
	_centre(c)          # le centre EN DERNIER : il passe au-dessus des pétales
	visible = true


func fermer() -> void:
	visible = false


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

	# Le liseré à la couleur de la nation — le `flag` de PR3, réduit à sa teinte
	# faute d'avoir les pavillons vectoriels.
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

	# L'illustration de la ville, si l'extraction locale est là. PR3 en a sept,
	# indexées par le type de ville ; on prend la taille (1 bourg, 2 ville,
	# 3 grande ville) comme approche la plus proche de ce dont on dispose.
	var taille := int(_port.get("taille", 1))
	var ids := ["18", "20", "22", "24", "26", "28"]
	var vue := SkinPR3.texture("ingame_radial_town/" + ids[clampi(taille - 1, 0, ids.size() - 1)])
	if vue != null:
		var tr := TextureRect.new()
		tr.texture = vue
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size = Vector2(d - 22, (d - 22) * 0.62)
		tr.position = c - Vector2(tr.size.x, tr.size.y) / 2.0 - Vector2(0, 10)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_racine.add_child(tr)

	_texte(c + Vector2(0, -R_CENTRE + 14), String(_port.get("nom", "?")), 14, BOIS, 150)

	# Habitants et réputation, comme les `tf_citizen` / `tf_rep_val` de PR3.
	var hab := int(_port.get("habitants", 0))
	_texte(c + Vector2(0, R_CENTRE - 26), "%d hab." % hab, 11, BOIS, 120)
	if _sim != null and _sim.has_method("etat_ville"):
		var e: Dictionary = _sim.etat_ville(String(_port.get("cle", "")))
		if e.has("reputation"):
			_texte(c + Vector2(0, R_CENTRE - 14), "rép. %d" % int(e["reputation"]),
					11, BOIS_CLAIR, 120)

	_produits(c)


# Les cinq marchandises produites, en arc SOUS le centre — le `gr_goods` de PR3.
func _produits(c: Vector2) -> void:
	var prod: Array = _port.get("produits", [])
	if prod.is_empty():
		return
	var n := mini(prod.size(), 5)
	var r := R_CENTRE + 22.0
	var etendue := deg_to_rad(86.0)
	var depart := deg_to_rad(90.0) - etendue / 2.0
	for i in n:
		var a := depart + (etendue * i / maxf(1.0, float(n - 1)))
		var pos := c + Vector2(cos(a), sin(a)) * r
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


# --- les pétales -------------------------------------------------------------

func _petale(c: Vector2, p: Dictionary) -> void:
	var a := deg_to_rad(float(p["angle"]))
	var pos := c + Vector2(cos(a), sin(a)) * RAYON
	var actif := _actif(String(p["cle"]))

	var b := Button.new()
	b.text = String(p["txt"])
	b.size = Vector2(R_PETALE * 2, R_PETALE * 2)
	b.position = pos - Vector2(R_PETALE, R_PETALE)
	b.add_theme_font_size_override("font_size", 13)
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
	_racine.add_child(b)

	var compteur := _compteur(String(p["cle"]))
	if compteur != "":
		_texte(pos + Vector2(0, R_PETALE - 12), compteur, 11, BOIS_CLAIR, 80)


# Un pétale est actif s'il mène quelque part ET si le joueur peut y entrer.
func _actif(cle: String) -> bool:
	match cle:
		"ville":
			return true
		"entrepot", "capitainerie":
			return _a_convoi
		"chantier":
			return _a_convoi and bool(_port.get("chantier", false))
		_:
			return false      # église, taverne, palais : pas encore d'écran


# Les chiffres que PR3 pose sur ses pétales : navires au chantier, navires et
# convois à l'ancre à la capitainerie.
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
