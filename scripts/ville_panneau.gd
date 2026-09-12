# Les infos d'une ville : ce qu'elle est, pas ce qu'on peut lui acheter.
#
# Le comptoir (`marche_panneau.gd`) montre des prix ; celui-ci montre une ville.
# La séparation est celle de Port Royale 3, et elle tient à ce qu'on regarde :
# devant un prix on décide d'un achat, devant une population on décide d'une
# route.
#
# Comme le comptoir, il ne calcule rien. Les fabriques, les maisons et le taux
# d'occupation viennent de `Economie.demographie`, qui les déduit des habitants
# selon les constantes de PR3 — 25 emplois par manufacture, 4 citoyens par
# emploi. Les recalculer ici les ferait diverger de la simulation au premier
# réglage.
class_name VillePanneau
extends CanvasLayer

signal ferme

# Comme le comptoir, ce panneau n'ouvre rien lui-même : il dit ce que le joueur
# a demandé, la carte arbitre.
signal denrees_demandees(port: Dictionary)

const ICONES := "res://sprites/marchandises/"
const VILLES := "res://sprites/villes/"
const PAVILLONS := "res://sprites/pavillons/"
const POLICE := "res://polices/serif_gras.ttf"

# Même largeur qu'au comptoir : le bandeau porte deux boutons ronds de taille
# fixe, et sur une plaque étroite ils mangeaient la moitié de la planche.
const LARGEUR := 640
const HAUTEUR := 560

# Le pavillon passe DERRIÈRE la vignette et déborde d'elle : il se lit comme une
# couleur de fond, pas comme un blason posé à côté. À pleine opacité il mangeait
# la ville ; à 70 % la silhouette des toits repasse devant.
const OPACITE_PAVILLON := 0.70
const DEBORD_PAVILLON := 1.35
const HAUTEUR_BLASON := 210.0

const BOIS       := Color(0.16, 0.11, 0.07)
const BOIS_CLAIR := Color(0.26, 0.18, 0.11)
const OR         := Color(0.86, 0.71, 0.36)
const OR_PALE    := Color(0.98, 0.92, 0.76)
const PARCHEMIN  := Color(0.90, 0.86, 0.78)
# Même lin qu'au comptoir : les deux écrans sont deux pages d'un même dossier.
# Uni, et sans trame : la tuile de parchemin ne se raccordait pas et rayait le
# fond de lignes tous les soixante pixels. Un aplat crème tient mieux qu'un
# grain qu'il faut affaiblir jusqu'à l'invisible pour qu'il cesse de gêner.
const LIN         := Color(0.945, 0.919, 0.855)
const UI          := "res://sprites/ui_pr/"
const RETRAIT_FOND := 20.0
const DESCENTE_FOND := 46.0
const HAUTEUR_BAS := 64.0
# De combien les équerres passent sous la plaque. Alignées sur elle, le lin
# affleurait leur base et se voyait dépasser entre les deux coins.
const DEBORD_BAS := 12.0
const MARGE_EQUERRE := 70
const ENCRE_BRUNE := Color(0.24, 0.16, 0.09)
const ENCRE_PALE  := Color(0.44, 0.36, 0.28)
const ENCRE      := Color(0.58, 0.52, 0.44)
const VERT       := Color(0.45, 0.72, 0.35)
const ROUGE      := Color(0.84, 0.42, 0.34)

var _sim: Object = null
var _port: Dictionary = {}
var _villes: Villes = null

var _bandeau: BandeauTitre
var _plaque: PanelContainer
var _bas: NinePatchRect
var _vignette: TextureRect
var _pavillon: TextureRect
var _lbl_habitants: Label
var _fleche: Label
var _lbl_fabriques: Label
var _lbl_maisons: Label
var _lbl_occupation: Label
var _rang_produits: HBoxContainer
var _bouton_denrees: Button
var _convoi_a_quai := false


func _init() -> void:
	layer = 8


func _ready() -> void:
	visible = false
	_batir()


# La table des vignettes vient de la carte, qui l'a déjà chargée. En créer une
# seconde ici relirait les cinq PNG pour rien, et surtout laisserait deux tables
# de seuils vivre côte à côte : le jour où l'une bouge, le panneau montrerait un
# village que la carte ne dessine pas.
func poser_villes(table: Villes) -> void:
	_villes = table


func _police() -> Font:
	return load(POLICE) if ResourceLoader.exists(POLICE) else null


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


func _bouton(texte: String) -> Button:
	var b := Button.new()
	b.text = texte
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
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
	return b


# La même rangée qu'au comptoir : les deux écrans sont deux pages d'un même
# dossier de ville, et une barre qui change de place ou de contenu d'une page à
# l'autre se lit comme deux fenêtres sans rapport.
#
# « Liste denrées » ne s'allume que si le joueur a un convoi à quai ICI. On peut
# regarder une ville de loin — c'est même le principal usage de cet écran — mais
# on ne commerce qu'au port, et un bouton actif qui mène à un comptoir vide
# ferait promettre à l'écran ce que la règle refuse.
func _onglets() -> Control:
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 8)
	for libelle in ["Infos ville", "Liste denrées", "Équiper"]:
		var b := _bouton(libelle)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 38
		match libelle:
			"Infos ville":
				# La page courante : montrée enfoncée, et sans effet au clic.
				b.disabled = true
				b.add_theme_stylebox_override("disabled", _cadre(BOIS, 4))
				b.add_theme_color_override("font_disabled_color", OR)
			"Liste denrées":
				_bouton_denrees = b
				b.pressed.connect(func() -> void: denrees_demandees.emit(_port))
			_:
				b.disabled = true
				b.tooltip_text = "Pas encore en place"
		ligne.add_child(b)
	return ligne


# --- construction -------------------------------------------------------------

func _batir() -> void:
	var fond := ColorRect.new()
	fond.color = Color(0, 0, 0, 0.45)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	fond.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_fermer())
	add_child(fond)

	# Le bandeau coiffe la plaque au lieu d'y être rangé : c'est la planche de
	# bois qui doit border l'écran, pas le lin. Même construction qu'au comptoir.
	var racine := Control.new()
	racine.set_anchors_preset(Control.PRESET_CENTER)
	racine.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(racine)
	racine.offset_left = -LARGEUR / 2.0
	racine.offset_top = -HAUTEUR / 2.0
	racine.offset_right = LARGEUR / 2.0
	racine.offset_bottom = HAUTEUR / 2.0

	var plaque := PanelContainer.new()
	var sb := _cadre(LIN, 8, 3)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	plaque.add_theme_stylebox_override("panel", sb)
	plaque.set_anchors_preset(Control.PRESET_FULL_RECT)
	plaque.offset_left = RETRAIT_FOND
	plaque.offset_right = -RETRAIT_FOND
	plaque.offset_top = DESCENTE_FOND
	plaque.clip_contents = true
	plaque.mouse_filter = Control.MOUSE_FILTER_STOP
	racine.add_child(plaque)


	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	plaque.add_child(col)

	var sous_bandeau := Control.new()
	sous_bandeau.custom_minimum_size.y = BandeauTitre.HAUTEUR - DESCENTE_FOND
	col.add_child(sous_bandeau)

	_bandeau = BandeauTitre.new()
	_bandeau.ferme.connect(_fermer)
	# On est déjà sur la page d'infos : le « i » du bandeau n'a nulle part où
	# mener.
	_bandeau.griser_infos(true)
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
	_plaque = plaque
	plaque.resized.connect(_replacer_bandeau)
	_replacer_bandeau()

	var dedans := MarginContainer.new()
	dedans.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for cote in ["left", "right"]:
		dedans.add_theme_constant_override("margin_" + cote, 14)
	dedans.add_theme_constant_override("margin_bottom", 36)
	col.add_child(dedans)
	var col2 := VBoxContainer.new()
	col2.add_theme_constant_override("separation", 10)
	dedans.add_child(col2)
	col = col2

	col.add_child(_onglets())
	col.add_child(_blason())
	col.add_child(_ligne_habitants())
	col.add_child(_separateur())
	col.add_child(_section_production())

	var pousse := Control.new()
	pousse.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(pousse)

	var pied := _texte("Échap ou clic hors du cadre pour fermer", 12, ENCRE_PALE,
					   0.0, HORIZONTAL_ALIGNMENT_CENTER)
	pied.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(pied)


# La vignette du village sur son pavillon. Les deux sont empilés dans le même
# rectangle, le pavillon d'abord : c'est l'ordre des enfants qui fait la
# profondeur, et non un z_index qu'il faudrait maintenir.
func _blason() -> Control:
	var boite := Control.new()
	boite.custom_minimum_size = Vector2(0, HAUTEUR_BLASON)
	boite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Le pavillon dépasse de la VIGNETTE, jamais de la boîte. C'est toute la
	# différence entre un fond et un débordement : en laissant le pavillon sortir
	# de son conteneur, il passait par-dessus le nom de la nation et le nombre
	# d'habitants, qui devenaient illisibles sur les bandes rouges.
	boite.clip_contents = true

	_pavillon = TextureRect.new()
	_pavillon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pavillon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pavillon.modulate = Color(1, 1, 1, OPACITE_PAVILLON)
	_pavillon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pavillon.set_anchors_preset(Control.PRESET_FULL_RECT)
	boite.add_child(_pavillon)

	# La vignette occupe le centre : c'est elle qu'on rétrécit, et le pavillon
	# qui reste pleine boîte se voit donc dépasser tout autour.
	_vignette = TextureRect.new()
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	var marge := HAUTEUR_BLASON * (1.0 - 1.0 / DEBORD_PAVILLON) * 0.5
	_vignette.offset_top = marge
	_vignette.offset_bottom = -marge
	boite.add_child(_vignette)
	return boite


func _replacer_bandeau() -> void:
	if _bandeau == null or _plaque == null:
		return
	_bandeau.position = Vector2(_plaque.position.x - RETRAIT_FOND, 0.0)
	_bandeau.size = Vector2(_plaque.size.x + RETRAIT_FOND * 2.0,
							BandeauTitre.HAUTEUR)
	if _bas != null:
		_bas.position = Vector2(_plaque.position.x - RETRAIT_FOND,
			_plaque.position.y + _plaque.size.y - HAUTEUR_BAS + DEBORD_BAS)
		_bas.size = Vector2(_plaque.size.x + RETRAIT_FOND * 2.0, HAUTEUR_BAS)


func _ligne_habitants() -> Control:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 8)

	_lbl_habitants = _texte("", 22, ENCRE_BRUNE)
	hb.add_child(_lbl_habitants)

	_fleche = _texte("", 22, VERT)
	hb.add_child(_fleche)

	var h := _texte("habitants", 15, ENCRE_PALE)
	hb.add_child(h)
	return hb


func _separateur() -> Control:
	var t := ColorRect.new()
	t.color = OR.darkened(0.35)
	t.custom_minimum_size = Vector2(0, 2)
	return t


func _section_production() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)

	col.add_child(_texte("Production", 18, OR.darkened(0.45)))

	# Première ligne : les trois chiffres de l'activité.
	var chiffres := HBoxContainer.new()
	chiffres.add_theme_constant_override("separation", 0)
	_lbl_fabriques = _texte("", 15, ENCRE_BRUNE)
	_lbl_fabriques.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_maisons = _texte("", 15, ENCRE_BRUNE, 0.0, HORIZONTAL_ALIGNMENT_CENTER)
	_lbl_maisons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_occupation = _texte("", 15, ENCRE_BRUNE, 0.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_lbl_occupation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chiffres.add_child(_lbl_fabriques)
	chiffres.add_child(_lbl_maisons)
	chiffres.add_child(_lbl_occupation)
	col.add_child(chiffres)

	# Seconde ligne : les cinq marchandises que la ville produit.
	_rang_produits = HBoxContainer.new()
	_rang_produits.alignment = BoxContainer.ALIGNMENT_CENTER
	_rang_produits.add_theme_constant_override("separation", 10)
	col.add_child(_rang_produits)
	return col


# --- remplissage --------------------------------------------------------------

func ouvrir(sim_obj: Object, port_dict: Dictionary, convoi_a_quai := false) -> void:
	_sim = sim_obj
	_port = port_dict
	_convoi_a_quai = convoi_a_quai
	visible = true
	rafraichir()


func _fermer() -> void:
	visible = false
	ferme.emit()


func fermer() -> void:
	if visible:
		_fermer()


func rafraichir() -> void:
	if _port.is_empty():
		return

	_bandeau.poser(String(_port.get("nom", "?")))
	if _bouton_denrees != null:
		_bouton_denrees.disabled = not _convoi_a_quai
		_bouton_denrees.tooltip_text = ("Le comptoir de la ville"
			if _convoi_a_quai else "Il faut un convoi à quai pour commercer")

	var habitants := int(_port.get("habitants", 0))
	var tendance := 0
	var fabriques := 0
	var maisons := 0
	var occupation := 0.0

	# La simulation a le dernier mot sur tous ces chiffres : la population du
	# dictionnaire de port date du dernier rafraîchissement de la carte, celle
	# de l'économie est du jour même.
	if _sim != null:
		var etat: Dictionary = _sim.etat_ville(String(_port.get("cle", "")))
		if not etat.is_empty():
			habitants = int(etat.get("habitants", habitants))
			tendance = int(etat.get("tendance", 0))
			fabriques = int(etat.get("fabriques", 0))
			maisons = int(etat.get("maisons", 0))
			occupation = float(etat.get("occupation", 0.0))

	_lbl_habitants.text = _nombre(habitants)
	if tendance > 0:
		_fleche.text = "▲"
		_fleche.add_theme_color_override("font_color", VERT)
	elif tendance < 0:
		_fleche.text = "▼"
		_fleche.add_theme_color_override("font_color", ROUGE)
	else:
		_fleche.text = "—"
		_fleche.add_theme_color_override("font_color", ENCRE)

	_lbl_fabriques.text = "%d fabriques" % fabriques
	_lbl_maisons.text = "%d maisons" % maisons
	_lbl_occupation.text = "occupées à %d %%" % int(round(occupation * 100.0))

	_poser_vignette(habitants)
	_poser_pavillon()
	_poser_produits()


# Le stade de croissance vient de `Villes`, et de nulle part ailleurs : la carte
# dessine déjà le village avec cette table, et deux seuils différents feraient
# afficher au panneau une ville que le joueur ne voit pas sur la carte.
func _poser_vignette(habitants: int) -> void:
	if _villes == null or _villes.vide():
		return
	var faux_port := {"habitants": habitants}
	_vignette.texture = _villes.texture_pour(faux_port)


func _poser_pavillon() -> void:
	var cle := String(_port.get("nation_cle", ""))
	var chemin := PAVILLONS + cle + ".png"
	_pavillon.texture = load(chemin) if ResourceLoader.exists(chemin) else null


func _poser_produits() -> void:
	for enfant in _rang_produits.get_children():
		enfant.queue_free()
	for cle in _port.get("produits", []):
		var chemin := ICONES + String(cle) + ".png"
		if not ResourceLoader.exists(chemin):
			continue
		var v := TextureRect.new()
		v.texture = load(chemin)
		v.custom_minimum_size = Vector2(52, 52)
		v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		v.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		v.tooltip_text = String(cle).capitalize()
		_rang_produits.add_child(v)


func _nombre(n: int) -> String:
	var s := str(absi(n))
	var sortie := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		sortie = s[i] + sortie
		c += 1
		if c % 3 == 0 and i > 0:
			sortie = " " + sortie
	return ("-" if n < 0 else "") + sortie


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_fermer()
		get_viewport().set_input_as_handled()
