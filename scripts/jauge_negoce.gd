# La jauge de négoce : vers la gauche on vend, vers la droite on achète.
#
# Elle remplace les deux boutons « Acheter » / « Vendre ». Un bouton demande de
# choisir la quantité AVANT de voir ce qu'elle coûte ; la jauge fait l'inverse —
# on tire, on lit le prix sous le curseur, et on ne s'engage qu'en relâchant.
# Tant que le doigt est dessus, rien n'est joué.
#
# Elle ne calcule aucun prix elle-même. Elle annonce la quantité visée par
# `apercu`, et le comptoir va demander à la simulation ce que ça coûte : c'est
# la seule façon d'être sûr que le chiffre montré est celui qui sera appliqué.
# Sur un marché mince, vendre trente tonnes ne rapporte pas trente fois la
# première, et une règle de trois ici mentirait au joueur.
class_name JaugeNegoce
extends Control

# < 0 vendre, > 0 acheter. Émis au RELÂCHEMENT seulement.
signal valide(quantite: int)
# Émis pendant le glissé, pour que le comptoir aille chercher le prix.
signal apercu(quantite: int)

# La palette du comptoir. Recopiée plutôt qu'importée : une jauge est une
# feuille de l'arbre, et lui faire connaître le panneau qui la porte créerait
# un cycle pour cinq couleurs.
const BOIS      := Color(0.16, 0.11, 0.07)
const OR        := Color(0.86, 0.71, 0.36)
const PARCHEMIN := Color(0.90, 0.86, 0.78)
const ENCRE     := Color(0.58, 0.52, 0.44)
const VERT      := Color(0.45, 0.72, 0.35)
const ROUGE     := Color(0.84, 0.42, 0.34)

const HAUT_RAIL := 13.0

var police: Font
var max_vente := 0            # ce que la cale porte
var max_achat := 0            # ce que la caisse, la cale et la ville permettent
var quantite := 0             # la position courante du curseur
var texte := ""               # le prix, écrit par le comptoir

var _glisse := false


func est_glissee() -> bool:
	return _glisse


func _ready() -> void:
	custom_minimum_size = Vector2(172, 44)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


# La quantité visée par une abscisse. Le centre est le zéro, et chaque moitié
# porte sa propre limite : la cale à gauche, le permis d'achat à droite.
func _quantite_en(x: float) -> int:
	var demi := size.x * 0.5
	if demi <= 0.0:
		return 0
	var part: float = clampf((x - demi) / demi, -1.0, 1.0)
	if part < 0.0:
		return -int(round(-part * float(max_vente)))
	return int(round(part * float(max_achat)))


func _gui_input(evenement: InputEvent) -> void:
	if evenement is InputEventMouseButton:
		var b := evenement as InputEventMouseButton
		if b.button_index != MOUSE_BUTTON_LEFT:
			return
		if b.pressed:
			if max_vente <= 0 and max_achat <= 0:
				return
			_glisse = true
			quantite = _quantite_en(b.position.x)
			apercu.emit(quantite)
			queue_redraw()
		elif _glisse:
			_glisse = false
			var q := quantite
			# On remet la jauge au zéro AVANT d'émettre : l'échange va
			# rafraîchir les limites, et une jauge encore tirée s'y
			# retrouverait à une quantité qui n'a plus cours.
			quantite = 0
			texte = ""
			queue_redraw()
			if q != 0:
				valide.emit(q)
	elif evenement is InputEventMouseMotion and _glisse:
		var q := _quantite_en((evenement as InputEventMouseMotion).position.x)
		if q != quantite:
			quantite = q
			apercu.emit(quantite)
		queue_redraw()


func _draw() -> void:
	var demi := size.x * 0.5
	var y := size.y - HAUT_RAIL - 2.0
	var mort := max_vente <= 0 and max_achat <= 0

	# Le rail, et les deux moitiés que la simulation autorise.
	draw_rect(Rect2(0, y, size.x, HAUT_RAIL), BOIS)
	if not mort:
		if max_vente > 0:
			draw_rect(Rect2(0, y, demi, HAUT_RAIL), Color(ROUGE.r, ROUGE.g, ROUGE.b, 0.16))
		if max_achat > 0:
			draw_rect(Rect2(demi, y, demi, HAUT_RAIL), Color(VERT.r, VERT.g, VERT.b, 0.16))

	# Le remplissage, du centre vers le curseur.
	if quantite != 0:
		var part := 0.0
		if quantite < 0 and max_vente > 0:
			part = float(-quantite) / float(max_vente)
		elif quantite > 0 and max_achat > 0:
			part = float(quantite) / float(max_achat)
		var l := demi * part
		var teinte := ROUGE if quantite < 0 else VERT
		if quantite < 0:
			draw_rect(Rect2(demi - l, y, l, HAUT_RAIL), teinte)
		else:
			draw_rect(Rect2(demi, y, l, HAUT_RAIL), teinte)
		# Le curseur : un trait franc, pour qu'on sache où on en est.
		var cx: float = demi + (l if quantite > 0 else -l)
		draw_rect(Rect2(cx - 1.5, y - 3.0, 3.0, HAUT_RAIL + 6.0), OR)

	# Le zéro, toujours visible : c'est le point de non-engagement.
	draw_rect(Rect2(demi - 1.0, y - 2.0, 2.0, HAUT_RAIL + 4.0),
			  ENCRE if not mort else Color(ENCRE.r, ENCRE.g, ENCRE.b, 0.4))

	if police == null:
		return
	# Au repos la jauge dit à quoi elle sert ; tirée, elle dit le prix.
	var t := texte
	if t == "":
		t = "—" if mort else "◀ vendre    acheter ▶"
	var teinte_t := PARCHEMIN if quantite != 0 else ENCRE
	var taille := 13 if quantite != 0 else 11
	# On confie le centrage ET la largeur à `draw_string` : centrer à la main
	# laissait l'aperçu déborder sur la colonne voisine dès que la somme
	# passait le millier.
	draw_string(police, Vector2(0.0, y - 6.0), t, HORIZONTAL_ALIGNMENT_CENTER,
				size.x, taille, teinte_t)
