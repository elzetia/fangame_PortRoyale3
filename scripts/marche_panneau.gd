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
const POLICE := "res://polices/serif_gras.ttf"

const LARGEUR := 640
const HAUTEUR := 720

# Lots proposés. -1 = tout ce que la caisse, la cale et la ville permettent.
const QUANTITES := [1, 10, 50, -1]

const BOIS       := Color(0.16, 0.11, 0.07)
const BOIS_CLAIR := Color(0.26, 0.18, 0.11)
const OR         := Color(0.86, 0.71, 0.36)
const OR_PALE    := Color(0.98, 0.92, 0.76)
const PARCHEMIN  := Color(0.90, 0.86, 0.78)
const ENCRE      := Color(0.58, 0.52, 0.44)
const VERT       := Color(0.45, 0.72, 0.35)
const ROUGE      := Color(0.84, 0.42, 0.34)

var _sim: Object = null
var _port: Dictionary = {}
var _messages: Array[String] = []

var _titre: Label
var _sous_titre: Label
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


# --- construction -------------------------------------------------------------

func _batir() -> void:
	var voile := ColorRect.new()
	voile.color = Color(0.02, 0.02, 0.03, 0.55)
	voile.anchor_right = 1.0
	voile.anchor_bottom = 1.0
	voile.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(voile)

	var fenetre := PanelContainer.new()
	fenetre.anchor_left = 0.5
	fenetre.anchor_top = 0.5
	fenetre.anchor_right = 0.5
	fenetre.anchor_bottom = 0.5
	fenetre.offset_left = -LARGEUR * 0.5
	fenetre.offset_top = -HAUTEUR * 0.5
	fenetre.offset_right = LARGEUR * 0.5
	fenetre.offset_bottom = HAUTEUR * 0.5
	var sb := _cadre(BOIS, 10, 3)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	fenetre.add_theme_stylebox_override("panel", sb)
	add_child(fenetre)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	fenetre.add_child(vb)

	# --- titre : le nom du port ------------------------------------------------
	_titre = _texte("", 30, OR_PALE, 0, HORIZONTAL_ALIGNMENT_CENTER)
	_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(_titre)

	_sous_titre = _texte("", 13, ENCRE, 0, HORIZONTAL_ALIGNMENT_CENTER)
	_sous_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(_sous_titre)

	# --- trois boutons, en ligne ----------------------------------------------
	var onglets := HBoxContainer.new()
	onglets.add_theme_constant_override("separation", 8)
	for libelle in ["Infos ville", "Liste denrées", "Équiper"]:
		var b := _bouton(libelle)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 38
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
	barre.add_child(_texte("Par lots de", 13, ENCRE))
	for q in QUANTITES:
		var b := _bouton("tout" if q < 0 else str(q) + " t", 54)
		b.toggle_mode = true
		b.pressed.connect(_choisir_lot.bind(q))
		barre.add_child(b)
		_boutons_lot.append(b)
	vb.add_child(barre)

	# --- la colonne des marchandises ------------------------------------------
	var defilement := ScrollContainer.new()
	defilement.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(defilement)

	_colonne = VBoxContainer.new()
	_colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_colonne.add_theme_constant_override("separation", 3)
	defilement.add_child(_colonne)

	# --- pied : caisse et cale -------------------------------------------------
	var bas := HBoxContainer.new()
	_pied = _texte("", 15, OR)
	_pied.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bas.add_child(_pied)
	var fermer := _bouton("Appareiller   Échap", 180)
	fermer.pressed.connect(_fermer)
	bas.add_child(fermer)
	vb.add_child(bas)

	_choisir_lot(10)


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

	var pair := true
	for m in _sim.marche(String(_port.get("cle", "")), 1):
		var cle := String(m.get("cle", ""))
		var fond := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.05) if pair else Color(0, 0, 0, 0.16)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		fond.add_theme_stylebox_override("panel", sb)
		pair = not pair

		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		fond.add_child(h)

		var vignette := TextureRect.new()
		vignette.custom_minimum_size = Vector2(46, 42)
		vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		vignette.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var chemin := ICONES + cle + ".png"
		if ResourceLoader.exists(chemin):
			vignette.texture = load(chemin)
		h.add_child(vignette)

		h.add_child(_texte(String(m.get("nom", cle)), 15, PARCHEMIN, 118))

		var e := {"cle": cle}

		# La barre d'abondance, à la manière de Port Royale 3 : quatre cases,
		# et le VERT compte le stock. Zéro verte, la ville manque et le cours
		# est au plafond ; quatre vertes, elle regorge et il est au plancher.
		var barre := TextureRect.new()
		barre.custom_minimum_size = Vector2(88, 40)
		barre.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		barre.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(barre)
		e["barre"] = barre

		e["stock"] = _texte("", 13, ENCRE, 54, HORIZONTAL_ALIGNMENT_RIGHT)
		e["achat"] = _texte("", 16, OR_PALE, 66, HORIZONTAL_ALIGNMENT_RIGHT)
		e["cale"] = _texte("", 15, PARCHEMIN, 60, HORIZONTAL_ALIGNMENT_RIGHT)
		e["vente"] = _texte("", 16, OR, 66, HORIZONTAL_ALIGNMENT_RIGHT)
		for k in ["stock", "achat", "cale", "vente"]:
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

	_titre.text = String(_port.get("nom", ""))
	# Ni la nation ni la population ici : elles vivent dans « Infos ville », et
	# les répéter au comptoir donnait deux chiffres à tenir d'accord pour rien.
	# Ce qui reste est ce qu'on vient chercher au comptoir — l'état du garde-manger,
	# qui dit si les prix vont monter.
	_sous_titre.text = "vivres %d %%" % roundi(float(v.get("subsistance", 1.0)) * 100.0)
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
			(e["stock"] as Label).text = "%d t" % int(m.get("stock", 0))
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
	(e["stock"] as Label).text = "%d t" % maxi(laisse, 0)


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
