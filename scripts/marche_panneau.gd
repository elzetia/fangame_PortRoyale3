# Le comptoir : la liste des denrées d'une ville.
#
# Il ne décide de rien. Tous les chiffres viennent de la simulation Lua, et
# chaque geste lui repasse la main : c'est `sim.compagnie` qui sait si la caisse
# suit, si la cale peut porter et si la ville a de quoi céder. Le panneau ne
# fait que montrer et transmettre — sans quoi il finirait par afficher un prix
# que la simulation n'appliquerait pas.
#
# Volontairement nu : un titre, trois boutons, une colonne de marchandises. Les
# seules images sont les vignettes des denrées ; tout le reste est dessiné par
# des styles, donc se règle en changeant une couleur plutôt qu'en redécoupant
# une planche.
class_name MarchePanneau
extends CanvasLayer

signal ferme

# Le comptoir ne sait pas ouvrir d'autres panneaux, et n'a pas à le savoir : il
# annonce que le joueur veut voir la ville, la carte décide de la suite.
signal infos_demandees(port: Dictionary)

const ICONES := "res://sprites/marchandises/"
const BARRES := "res://sprites/barres/"
const UI := "res://sprites/ui_pr/"
const POLICE := "res://polices/serif_gras.ttf"

const LARGEUR := 640
const HAUTEUR := 800

# Lots proposés. -1 = tout ce que la caisse, la cale et la ville permettent.
const QUANTITES := [1, 10, 50, -1]

const BOIS       := Color(0.16, 0.11, 0.07)
const BOIS_CLAIR := Color(0.26, 0.18, 0.11)
const OR         := Color(0.86, 0.71, 0.36)
const OR_PALE    := Color(0.98, 0.92, 0.76)
const PARCHEMIN  := Color(0.90, 0.86, 0.78)
# Le fond des écrans de ville : un lin très clair, à peine chaud. Sur cette
# teinte, l'or et le parchemin des textes ne se lisent plus — le contenu passe
# donc à l'encre brune, et seuls les éléments de bois (bandeau, onglets, plaques
# de tonnage) gardent leurs couleurs claires, puisqu'ils portent leur propre fond.
# Uni, et sans trame : la tuile de parchemin ne se raccordait pas et rayait le
# fond de lignes tous les soixante pixels. Un aplat crème tient mieux qu'un
# grain qu'il faut affaiblir jusqu'à l'invisible pour qu'il cesse de gêner.
const LIN        := Color(0.945, 0.919, 0.855)
# De combien la plaque se rentre sous la planche du titre, de chaque côté et
# par le haut.
# Le bois doit border le crème, pas flotter autour : à vingt pixels le cadre
# se décollait du fond, à huit il ne se voyait plus déborder du tout.
const RETRAIT_FOND := 13.0
const DESCENTE_FOND := 46.0
const HAUTEUR_BAS := 64.0
# De combien les équerres passent sous la plaque. Alignées sur elle, le lin
# affleurait leur base et se voyait dépasser entre les deux coins.
const DEBORD_BAS := 7.0
const MARGE_EQUERRE := 70
const ENCRE_BRUNE := Color(0.24, 0.16, 0.09)
const ENCRE_PALE  := Color(0.44, 0.36, 0.28)
const VERT_SOMBRE := Color(0.20, 0.42, 0.18)
# Le bandeau que chaque ligne pose sur le lin, et de combien il s'amincit par
# rapport à la hauteur qu'elle occupe.
const BANDE_LIGNE := Color(0.42, 0.32, 0.18, 0.13)
const BANDE_FINESSE := 3.0

# Gabarit d'une ligne. Tout est au trois quarts de ce qu'il valait : le comptoir
# mangeait trop d'ecran pour ce qu'il montre, et une liste de vingt denrees se
# lit d'autant mieux qu'on en voit beaucoup d'un coup.
const COL_NOM := 88.0
const COL_BARRE := 66.0
const COL_STOCK := 47.0
const COL_PRIX := 50.0
const COL_CALE := 45.0
const HAUTEUR_PLAQUE := 26.0
const SEPARATION := 6

# La vignette, elle, ne retrecit PAS : elle grandit. Sa case reste etroite mais
# l'image deborde du bandeau en haut et en bas, ce qui la pose sur la ligne au
# lieu de l'y enfermer — c'est elle qu'on cherche des yeux en parcourant la
# liste, pas la colonne qui la contient.
const COL_VIGNETTE := 50.0
const HAUTEUR_VIGNETTE := 32.0
const DEBORD_VIGNETTE := 9.0

const PT_NOM := 12
const PT_PRIX := 13
const PT_CALE := 12
const PT_STOCK := 11
const ENCRE      := Color(0.58, 0.52, 0.44)
const VERT       := Color(0.45, 0.72, 0.35)
const ROUGE      := Color(0.84, 0.42, 0.34)

var _sim: Object = null
var _port: Dictionary = {}
var _messages: Array[String] = []

var _bandeau: BandeauTitre
var _fenetre: PanelContainer
var _bas: NinePatchRect
var _pied: Label
var _colonne: VBoxContainer
var _lignes: Array = []
var _quantite := 10
var _boutons_lot: Array[Button] = []


func _init() -> void:
	layer = 8


func _ready() -> void:
	visible = false
	_batir()


func _police() -> Font:
	return load(POLICE) if ResourceLoader.exists(POLICE) else null


# --- styles -------------------------------------------------------------------

func _cadre(fond: Color, rayon := 6, bordure := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fond
	sb.border_color = OR.darkened(0.45)
	sb.set_border_width_all(bordure)
	sb.set_corner_radius_all(rayon)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _bouton(texte: String, largeur := 0.0) -> Button:
	var b := Button.new()
	b.text = texte
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", OR_PALE)
	b.add_theme_color_override("font_hover_color", Color(1, 0.97, 0.86))
	b.add_theme_color_override("font_pressed_color", OR)
	b.add_theme_color_override("font_disabled_color", ENCRE.darkened(0.2))
	var f := _police()
	if f != null:
		b.add_theme_font_override("font", f)
	for etat in ["normal", "hover", "pressed", "disabled"]:
		var fond := BOIS_CLAIR
		if etat == "hover":
			fond = BOIS_CLAIR.lightened(0.12)
		elif etat == "pressed":
			fond = BOIS
		elif etat == "disabled":
			fond = BOIS_CLAIR.darkened(0.35)
		b.add_theme_stylebox_override(etat, _cadre(fond, 4))
	if largeur > 0.0:
		b.custom_minimum_size.x = largeur
	return b


func _texte(contenu: String, taille: int, teinte: Color,
			largeur := 0.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = contenu
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", teinte)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var f := _police()
	if f != null:
		l.add_theme_font_override("font", f)
	if largeur > 0.0:
		l.custom_minimum_size.x = largeur
	return l


# Les pictos qui coiffent les colonnes. Ils reprennent au pixel près les largeurs
# de `_batir_lignes` — vignette 46, nom 118, barre 88, stock 54… — et la même
# séparation de 8 : une rangée d'en-têtes qui glisse d'un cran par rapport à ses
# colonnes est pire que pas d'en-têtes du tout, elle désigne la mauvaise.
# La plaque brune du tonnage. C'est un NinePatchRect : son cadre doré ne doit
# pas s'étirer avec le nombre, sinon un « 1057 t » l'épaissit plus qu'un « 39 t »
# et la colonne se met à onduler d'une ligne à l'autre.
func _plaque_stock(etiquette: Label, largeur: float) -> Control:
	var boite := PanelContainer.new()
	boite.custom_minimum_size = Vector2(largeur, HAUTEUR_PLAQUE)
	var chemin := UI + "fond_stock.png"
	if ResourceLoader.exists(chemin):
		# StyleBoxTexture et non NinePatchRect : un conteneur impose sa taille à
		# ses enfants et écrase leurs ancres, si bien que le rectangle posé en
		# fond restait invisible. Le style, lui, EST le fond du conteneur.
		var st := StyleBoxTexture.new()
		st.texture = load(chemin)
		# Le cadre doré, préservé ; seul le brun du milieu s'étire avec le nombre.
		# Ces marges ne s'échelonnent PAS : ce sont des pixels de la texture, posés
		# tels quels. A 16 sur une plaque haute de 26, les coins du haut et du bas
		# se chevauchaient et la plaque se dessinait en losange écrasé. La texture
		# a donc été réduite de moitié, et les marges avec elle.
		st.texture_margin_left = 8
		st.texture_margin_right = 8
		st.texture_margin_top = 8
		st.texture_margin_bottom = 8
		st.content_margin_left = 4
		st.content_margin_right = 4
		boite.add_theme_stylebox_override("panel", st)
	etiquette.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	boite.add_child(etiquette)
	return boite


func _picto(fichier: String, largeur: float, infobulle: String,
			a_droite := false) -> Control:
	# Les chiffres de prix sont ferrés à droite dans leur case : un picto centré
	# au-dessus flotte visiblement à côté de la colonne qu'il coiffe. On le cale
	# donc comme la donnée, pas comme la case.
	var boite := BoxContainer.new()
	boite.alignment = (BoxContainer.ALIGNMENT_END if a_droite
		else BoxContainer.ALIGNMENT_CENTER)
	boite.custom_minimum_size.x = largeur
	var t := TextureRect.new()
	var chemin := UI + fichier
	if ResourceLoader.exists(chemin):
		t.texture = load(chemin)
	t.custom_minimum_size = Vector2(29, 24)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.tooltip_text = infobulle
	boite.add_child(t)
	return boite


func _entetes() -> Control:
	# Le MÊME gabarit qu'une ligne de marchandise : un PanelContainer aux mêmes
	# marges, un HBox à la même séparation, et des cases aux mêmes largeurs.
	# Bâtie à part, la rangée dérivait de quelques pixels et chaque picto
	# désignait la colonne d'à côté.
	var cadre := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	cadre.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", SEPARATION)
	cadre.add_child(h)

	# Rien au-dessus de la vignette ni du nom : ils se passent d'étiquette.
	for largeur in [COL_VIGNETTE, COL_NOM]:
		var vide := Control.new()
		vide.custom_minimum_size.x = largeur
		h.add_child(vide)

	# La barre d'abondance et le tonnage disent la même chose — ce que la ville
	# a en magasin — donc un seul picto les coiffe tous les deux.
	h.add_child(_picto("stock.png", COL_BARRE, "Ce que la ville tient en magasin"))
	var t := Control.new()
	t.custom_minimum_size.x = COL_STOCK
	h.add_child(t)

	h.add_child(_picto("prix.png", COL_PRIX, "Le cours du jour", true))
	for largeur in [COL_CALE, COL_PRIX]:
		var vide2 := Control.new()
		vide2.custom_minimum_size.x = largeur
		h.add_child(vide2)

	var reste := Control.new()
	reste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(reste)
	return cadre


# --- construction -------------------------------------------------------------

func _batir() -> void:
	var voile := ColorRect.new()
	voile.color = Color(0.02, 0.02, 0.03, 0.55)
	voile.anchor_right = 1.0
	voile.anchor_bottom = 1.0
	voile.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(voile)

	# Le bandeau n'est PLUS dans la plaque : il la coiffe. Rangé dedans, la
	# plaque le débordait d'un liseré clair sur la droite et au-dessus — c'est
	# la planche de bois qui doit border l'écran, pas le lin. La plaque est donc
	# un frère du bandeau, rentré de chaque côté et descendu sous lui.
	var racine := Control.new()
	racine.anchor_left = 0.5
	racine.anchor_top = 0.5
	racine.anchor_right = 0.5
	racine.anchor_bottom = 0.5
	racine.offset_left = -LARGEUR * 0.5
	racine.offset_top = -HAUTEUR * 0.5
	racine.offset_right = LARGEUR * 0.5
	racine.offset_bottom = HAUTEUR * 0.5
	racine.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(racine)

	var fenetre := PanelContainer.new()
	fenetre.set_anchors_preset(Control.PRESET_FULL_RECT)
	fenetre.offset_left = RETRAIT_FOND
	fenetre.offset_right = -RETRAIT_FOND
	fenetre.offset_top = DESCENTE_FOND
	fenetre.clip_contents = true
	var sb := _cadre(LIN, 10, 3)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	fenetre.add_theme_stylebox_override("panel", sb)
	racine.add_child(fenetre)


	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	fenetre.add_child(vb)

	# La place que le bandeau occupe par-dessus la plaque.
	var sous_bandeau := Control.new()
	sous_bandeau.custom_minimum_size.y = BandeauTitre.HAUTEUR - DESCENTE_FOND
	vb.add_child(sous_bandeau)

	# --- titre : le nom du port ------------------------------------------------
	_bandeau = BandeauTitre.new()
	_bandeau.ferme.connect(_fermer)
	_bandeau.infos.connect(func() -> void: infos_demandees.emit(_port))
	racine.add_child(_bandeau)
	# La bordure du bas : deux equerres qui ferment le cadre, comme le bandeau le
	# coiffe. Son milieu est vide, donc seuls les coins mordent sur le contenu —
	# d'ou la marge basse qui leur laisse la place.
	_bas = NinePatchRect.new()
	var cb := UI + "bas_de_menu.png"
	if ResourceLoader.exists(cb):
		_bas.texture = load(cb)
	_bas.patch_margin_left = MARGE_EQUERRE
	_bas.patch_margin_right = MARGE_EQUERRE
	_bas.patch_margin_top = 0
	_bas.patch_margin_bottom = 0
	_bas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(_bas)
	# Le bandeau se cale sur la PLAQUE, pas sur la racine : la largeur réelle de
	# l'écran est dictée par la liste des denrées, qui réclame plus que LARGEUR.
	# Ancré sur la racine, le bandeau restait à 640 pendant que la plaque
	# s'étalait à 790 — et c'est le lin qui débordait, l'inverse de ce qu'on veut.
	_fenetre = fenetre
	fenetre.resized.connect(_replacer_bandeau)
	_replacer_bandeau()

	var dedans := MarginContainer.new()
	dedans.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for cote in ["left", "right"]:
		dedans.add_theme_constant_override("margin_" + cote, 18)
	dedans.add_theme_constant_override("margin_bottom", 40)
	vb.add_child(dedans)
	var vb2 := VBoxContainer.new()
	vb2.add_theme_constant_override("separation", 10)
	dedans.add_child(vb2)
	vb = vb2

	# --- trois boutons, en ligne ----------------------------------------------
	var onglets := HBoxContainer.new()
	onglets.add_theme_constant_override("separation", 8)
	for libelle in ["Infos ville", "Liste denrées", "Équiper"]:
		var b := _bouton(libelle)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 29
		if libelle == "Infos ville":
			b.pressed.connect(func() -> void: infos_demandees.emit(_port))
		else:
			# Les deux autres attendent leur écran. Grisés plutôt que muets :
			# un bouton qui répond au clic sans rien faire se lit comme une panne.
			b.disabled = true
			b.tooltip_text = "Pas encore en place"
		onglets.add_child(b)
	vb.add_child(onglets)

	# --- taille des lots -------------------------------------------------------
	var barre := HBoxContainer.new()
	barre.add_theme_constant_override("separation", 6)
	barre.alignment = BoxContainer.ALIGNMENT_CENTER
	barre.add_child(_texte("Par lots de", 11, ENCRE_PALE))
	for q in QUANTITES:
		var b := _bouton("tout" if q < 0 else str(q) + " t", 42)
		b.toggle_mode = true
		b.pressed.connect(_choisir_lot.bind(q))
		barre.add_child(b)
		_boutons_lot.append(b)
	vb.add_child(barre)

	# --- en-têtes de colonnes --------------------------------------------------
	vb.add_child(_entetes())

	# --- la colonne des marchandises ------------------------------------------
	# Défilement cranté : une marchandise par cran, jamais de ligne coupée en
	# deux. Voir scripts/defilement_crante.gd.
	var defilement := DefilementCrante.new()
	defilement.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(defilement)

	_colonne = VBoxContainer.new()
	_colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_colonne.add_theme_constant_override("separation", 3)
	defilement.add_child(_colonne)
	# Il mesure la hauteur d'un cran sur la première ligne réellement dessinée.
	defilement.poser_colonne(_colonne)

	# --- pied : caisse et cale -------------------------------------------------
	var bas := HBoxContainer.new()
	_pied = _texte("", 12, ENCRE_BRUNE)
	_pied.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bas.add_child(_pied)
	var fermer := _bouton("Appareiller   Échap", 140)
	fermer.pressed.connect(_fermer)
	bas.add_child(fermer)
	vb.add_child(bas)

	_choisir_lot(10)


func _replacer_bandeau() -> void:
	if _bandeau == null or _fenetre == null:
		return
	_bandeau.position = Vector2(_fenetre.position.x - RETRAIT_FOND, 0.0)
	_bandeau.size = Vector2(_fenetre.size.x + RETRAIT_FOND * 2.0,
							BandeauTitre.HAUTEUR)
	if _bas != null:
		_bas.position = Vector2(_fenetre.position.x - RETRAIT_FOND,
			_fenetre.position.y + _fenetre.size.y - HAUTEUR_BAS + DEBORD_BAS)
		_bas.size = Vector2(_fenetre.size.x + RETRAIT_FOND * 2.0, HAUTEUR_BAS)


func _choisir_lot(q: int) -> void:
	_quantite = q
	for i in _boutons_lot.size():
		_boutons_lot[i].button_pressed = (QUANTITES[i] == q)
	if _sim != null:
		rafraichir()


# --- ouverture ----------------------------------------------------------------

func ouvrir(sim_obj: Object, port_dict: Dictionary) -> void:
	_sim = sim_obj
	_port = port_dict
	_batir_lignes()
	visible = true
	rafraichir()


func _fermer() -> void:
	visible = false
	ferme.emit()


# Fermeture demandée du dehors, quand un autre panneau prend la place. Le signal
# part quand même : qui écoutait la sortie du comptoir doit l'apprendre, que le
# joueur ait cliqué « fermer » ou ouvert les infos de la ville.
func fermer() -> void:
	if visible:
		_fermer()


# Une ligne par marchandise : vignette, nom, stock, prix d'achat, ce qu'on en
# porte, prix de vente, et les deux poignées d'échange.
func _batir_lignes() -> void:
	for enfant in _colonne.get_children():
		_colonne.remove_child(enfant)
		enfant.queue_free()
	_lignes.clear()

	# Les cinq marchandises du cru, telles que l'archipel les donne.
	var produits: Array = _port.get("produits", [])
	for m in _sim.marche(String(_port.get("cle", "")), 1):
		var cle := String(m.get("cle", ""))
		var fond := PanelContainer.new()
		# Toutes les lignes portent le MÊME bandeau. L'alternance une ligne sur
		# deux découpait la liste en paquets de deux et donnait à lire un rythme
		# qui ne veut rien dire — il n'y a pas deux sortes de marchandises.
		var sb := StyleBoxFlat.new()
		sb.bg_color = BANDE_LIGNE
		sb.set_corner_radius_all(6)
		# Rien a gauche : le bandeau part exactement au bord de la vignette. Une
		# marge l'en faisait deborder, et la ligne semblait commencer avant son
		# image au lieu d'etre portee par elle.
		sb.content_margin_left = 0
		sb.content_margin_right = 6
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		# Marges négatives : le bandeau se dessine plus mince que la place qu'il
		# occupe. Il reste ainsi un filet de lin au-dessus et en dessous, qui
		# sépare les lignes sans qu'on ait à tracer un trait.
		sb.expand_margin_top = -BANDE_FINESSE
		sb.expand_margin_bottom = -BANDE_FINESSE
		fond.add_theme_stylebox_override("panel", sb)

		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", SEPARATION)
		fond.add_child(h)

		# La case garde le gabarit de la ligne ; l'image, elle, sort de ses bords
		# par des marges negatives. Lui donner directement une taille plus grande
		# aurait pousse la ligne entiere a grandir avec elle.
		var case := Control.new()
		case.custom_minimum_size = Vector2(COL_VIGNETTE, HAUTEUR_VIGNETTE)
		h.add_child(case)

		var vignette := TextureRect.new()
		vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		vignette.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
		# En haut et en bas SEULEMENT : deborder aussi sur les cotes faisait mordre
		# l'image sur le nom de la denree, qu'on ne lisait plus. La case est donc
		# assez large pour que l'image y grandisse sans pousser a droite.
		vignette.offset_top = -DEBORD_VIGNETTE
		vignette.offset_bottom = DEBORD_VIGNETTE
		var chemin := ICONES + cle + ".png"
		if ResourceLoader.exists(chemin):
			vignette.texture = load(chemin)
		case.add_child(vignette)

		# L'engrenage, en bas à droite de la vignette, marque ce que la ville
		# FABRIQUE. C'est la question qu'on se pose devant un comptoir : ce
		# tonneau est-il du cru — donc bon marché et renouvelé chaque jour — ou
		# de passage ? Le prix seul ne le dit pas : une ville peut brader ce
		# qu'elle vient de recevoir.
		if cle in produits:
			var marque := TextureRect.new()
			marque.texture = load(UI + "produit.png")
			marque.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			marque.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			marque.size = Vector2(17, 17)
			marque.mouse_filter = Control.MOUSE_FILTER_IGNORE
			marque.tooltip_text = "Produit ici"
			# Accroche a la CASE et non a l'image : celle-ci deborde de tous
			# cotes, et l'engrenage aurait suivi le debordement au lieu de rester
			# au coin de la ligne.
			marque.position = Vector2(COL_VIGNETTE - 15.0, HAUTEUR_VIGNETTE - 15.0)
			case.add_child(marque)

		h.add_child(_texte(String(m.get("nom", cle)), PT_NOM, ENCRE_BRUNE, COL_NOM))

		var e := {"cle": cle}

		# La barre d'abondance, à la manière de Port Royale 3 : quatre cases,
		# et le VERT compte le stock. Zéro verte, la ville manque et le cours
		# est au plafond ; quatre vertes, elle regorge et il est au plancher.
		var barre := TextureRect.new()
		barre.custom_minimum_size = Vector2(COL_BARRE, HAUTEUR_VIGNETTE)
		barre.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		barre.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(barre)
		e["barre"] = barre

		# Le tonnage en ville va dans sa plaque : c'est le chiffre qu'on cherche
		# des yeux en descendant la liste, et il se perdait entre deux colonnes
		# de prix alignées comme lui.
		e["stock"] = _texte("", PT_STOCK, OR_PALE, 0, HORIZONTAL_ALIGNMENT_CENTER)
		h.add_child(_plaque_stock(e["stock"], COL_STOCK))

		e["achat"] = _texte("", PT_PRIX, ENCRE_BRUNE, COL_PRIX, HORIZONTAL_ALIGNMENT_RIGHT)
		e["cale"] = _texte("", PT_CALE, ENCRE_PALE, COL_CALE, HORIZONTAL_ALIGNMENT_RIGHT)
		e["vente"] = _texte("", PT_PRIX, VERT_SOMBRE, COL_PRIX, HORIZONTAL_ALIGNMENT_RIGHT)
		for k in ["achat", "cale", "vente"]:
			h.add_child(e[k])

		# Une jauge plutôt que deux boutons : on tire vers la gauche pour
		# vendre, vers la droite pour acheter, et l'échange ne se fait qu'au
		# relâchement. Voir scripts/jauge_negoce.gd.
		var j := JaugeNegoce.new()
		j.police = _police()
		j.apercu.connect(_sur_apercu.bind(e))
		j.valide.connect(_sur_valide.bind(cle))
		h.add_child(j)
		e["jauge"] = j

		_colonne.add_child(fond)
		_lignes.append(e)


# --- affichage ----------------------------------------------------------------

func rafraichir() -> void:
	if _sim == null or not _port.has("cle") or not visible:
		return
	var ville := String(_port.get("cle", ""))
	var c: Dictionary = _sim.etat_compagnie()
	var v: Dictionary = _sim.etat_ville(ville)

	_bandeau.poser(String(_port.get("nom", "")))
	_pied.text = "%s pièces d'or      cale %d / %d tonneaux" % [
		_nombre(int(c.get("or_", 0))), int(c.get("charge", 0)),
		int(c.get("capacite", 0))]

	# Les cours sont demandés POUR LE LOT choisi, pas à l'unité : c'est ce
	# chiffre-là que le joueur paiera. Sur un marché mince, acheter cinquante
	# tonnes coûte sensiblement plus cher que cinquante fois la première.
	var lignes: Array = _sim.marche(ville, maxi(1, _quantite if _quantite > 0
										else int(c.get("capacite", 1))))
	for i in mini(lignes.size(), _lignes.size()):
		var m: Dictionary = lignes[i]
		var e: Dictionary = _lignes[i]
		var en_cale := int(m.get("en_cale", 0))
		# Une jauge qu'on tire montre l'abondance que l'échange LAISSERAIT :
		# on ne vient donc pas réécrire par-dessus à chaque image.
		var tire: bool = (e["jauge"] as JaugeNegoce).est_glissee()
		if not tire:
			# Le nombre de barres vient de la simulation, pas d'un calcul refait
			# ici : elle le déduit du facteur de prix, si bien que la jauge et le
			# cours ne peuvent pas se contredire à l'écran.
			_poser_barre(e, clampi(int(m.get("barres", 0)), 0, 4),
						 int(m.get("stock", 0)), int(m.get("reference", 0)))
			(e["stock"] as Label).text = "%d" % int(m.get("stock", 0))
		e["reference"] = int(m.get("reference", 0))
		e["stock_reel"] = int(m.get("stock", 0))
		(e["achat"] as Label).text = "%d" % int(float(m.get("achat_lot", 0.0)))
		(e["cale"] as Label).text = ("%d t" % en_cale) if en_cale > 0 else "—"
		(e["vente"] as Label).text = "%d" % int(float(m.get("vente_lot", 0.0)))

		# Une jauge qui ne peut rien faire doit se voir avant d'être tirée.
		# On ne touche pas à celle qu'on est en train de glisser : ses bornes
		# changeraient sous le doigt, et le curseur sauterait.
		var j := e["jauge"] as JaugeNegoce
		if not j.est_glissee():
			j.max_achat = int(m.get("achat_max", 0))
			j.max_vente = en_cale
			j.queue_redraw()


# Pose la vignette d'abondance et son infobulle. Deux appelants : l'affichage
# au repos et la prévision pendant le glissé.
func _poser_barre(e: Dictionary, n: int, stock: int, reference: int) -> void:
	var chemin := BARRES + "barre_%d.png" % clampi(n, 0, 4)
	if ResourceLoader.exists(chemin):
		(e["barre"] as TextureRect).texture = load(chemin)
	(e["barre"] as TextureRect).tooltip_text = "%d t en ville, réserve visée %d t" % [
		stock, reference]


func _nombre(n: int) -> String:
	# Séparateur de milliers : « 20 000 » se lit, « 20000 » se compte.
	var s := str(absi(n))
	var sortie := ""
	var k := 0
	for i in range(s.length() - 1, -1, -1):
		sortie = s[i] + sortie
		k += 1
		if k % 3 == 0 and i > 0:
			sortie = " " + sortie
	return ("-" if n < 0 else "") + sortie


# --- échanges -----------------------------------------------------------------

# Le prix affiché sous le curseur est demandé à la simulation POUR LA QUANTITÉ
# EXACTE visée, à chaque cran. C'est plus coûteux qu'une règle de trois, et
# c'est le but : sur un marché mince, trente tonnes ne valent pas trente fois
# la première, et un prix calculé ici ne serait pas celui qu'on paierait.
func _sur_apercu(quantite: int, e: Dictionary) -> void:
	var cle := String(e["cle"])
	var jauge := e["jauge"] as JaugeNegoce
	if quantite == 0 or _sim == null:
		jauge.texte = ""
		jauge.queue_redraw()
		return
	# Le cours de la tonne SUIVANTE, pas la moyenne du lot.
	#
	# `cotation` rend un cours MOYEN : elle déplace le stock de la moitié de la
	# quantité, et la somme due vaut ce cours fois la quantité. La moyenne
	# masque donc ce qu'on regarde en composant un lot — jusqu'où le marché
	# reste intéressant. Le coût du cran suivant, lui, le dit : c'est la
	# différence des deux sommes.
	var ville := String(_port.get("cle", ""))
	var sens := "achat" if quantite > 0 else "vente"
	var q := absi(quantite)
	var somme_q: float = _sim.cotation(ville, cle, q, sens) * float(q)
	var somme_q1: float = _sim.cotation(ville, cle, q + 1, sens) * float(q + 1)
	var marginal := roundi(somme_q1 - somme_q)
	# Le sens se lit déjà au côté tiré et à la couleur du remplissage ; le
	# texte n'a pas à le répéter en entier.
	jauge.texte = "%s %d t · %s/t" % [
		"achat" if quantite > 0 else "vente", q, _nombre(marginal)]
	jauge.queue_redraw()

	# L'abondance que l'échange laisserait. Acheter vide la ville, vendre la
	# remplit : le décalage est donc l'opposé de la quantité, dans les deux sens
	# d'un seul coup. On le demande à la simulation pour que la prévision suive
	# le même barème que l'affichage au repos.
	var laisse := int(e.get("stock_reel", 0)) - quantite
	_poser_barre(e, _sim.barres(ville, cle, -quantite),
				 maxi(laisse, 0), int(e.get("reference", 0)))
	(e["stock"] as Label).text = "%d" % maxi(laisse, 0)


# Au relâchement seulement : c'est là que l'échange se fait.
func _sur_valide(quantite: int, cle: String) -> void:
	if quantite > 0:
		_annoncer(_sim.acheter(String(_port.get("cle", "")), cle, quantite),
				  cle, "Acheté", "payées")
	else:
		_annoncer(_sim.vendre(String(_port.get("cle", "")), cle, -quantite),
				  cle, "Vendu", "reçues")
	rafraichir()


func _annoncer(r: Dictionary, cle: String, verbe: String, sens: String) -> void:
	if not bool(r.get("ok", false)):
		_messages.append(String(r.get("message", "Impossible.")))
		return
	var nom := cle
	for m in _sim.marche(String(_port.get("cle", "")), 1):
		if String(m.get("cle", "")) == cle:
			nom = String(m.get("nom", cle))
			break
	_messages.append("%s %d t de %s — %s pièces %s" % [
		verbe, int(r.get("quantite", 0)), nom.to_lower(),
		_nombre(int(r.get("somme", 0))), sens])


func message() -> String:
	if _messages.is_empty():
		return ""
	return _messages.pop_front()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
			_fermer()
			get_viewport().set_input_as_handled()
