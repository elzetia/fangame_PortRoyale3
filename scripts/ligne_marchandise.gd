# Une ligne du comptoir, et tout le négoce qu'elle porte.
#
# La jauge ne vit plus en permanence à droite de chaque ligne : elle se déplie
# SOUS celle qu'on tient. Vingt jauges affichées côte à côte occupaient le tiers
# de la largeur pour un geste qui ne concerne jamais qu'une denrée à la fois, et
# elles volaient la place aux chiffres qu'on vient lire.
#
# Le geste complet : on survole — la ligne s'éclaire ; on appuie — elle s'ouvre
# et la jauge apparaît ; on tire à gauche pour vendre, à droite pour acheter ; on
# relâche — l'échange se fait. Le clic droit pendant le glissé annule tout.
# Rien n'est joué tant que le doigt est dessus, ce qui permet de regarder le prix
# avant de s'engager.
#
# Elle ne calcule aucun prix. Elle annonce la quantité visée par `apercu`, le
# comptoir va la chiffrer auprès de la simulation et lui rend le texte à
# afficher. Sur un marché mince, vendre trente tonnes ne rapporte pas trente fois
# la première : une règle de trois ici mentirait au joueur.
class_name LigneMarchandise
extends Control

# < 0 vendre, > 0 acheter. Émis au RELÂCHEMENT seulement.
signal valide(quantite: int)
# Émis pendant le glissé, pour que le comptoir aille chercher le prix.
signal apercu(quantite: int)

const OR         := Color(0.86, 0.71, 0.36)
const OR_VIF     := Color(1.0, 0.89, 0.55)
const VERT       := Color(0.36, 0.60, 0.28)
const ROUGE      := Color(0.76, 0.34, 0.27)
const ENCRE      := Color(0.30, 0.22, 0.13)

# Ce qu'il faut parcourir, en pixels, pour aller d'un bout à l'autre de la jauge.
const COURSE := 150.0
const HAUTEUR_JAUGE := 30.0
const RAIL := 7.0

var couleur_fond := Color(0.42, 0.32, 0.18, 0.13)
var depart_pointe := 18.0
var pointe := 20.0
var finesse := 3.0
var police: Font

var max_vente := 0            # ce que la cale porte
var max_achat := 0            # ce que la caisse, la cale et la ville permettent
var texte_prix := ""          # écrit par le comptoir, à chaque aperçu

var hauteur_ligne := 34.0

var _survol := false
var _ouverte := false
var _depart_x := 0.0
var _quantite := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	mouse_entered.connect(func() -> void:
		_survol = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_survol = false
		queue_redraw())
	_ajuster()


func _ajuster() -> void:
	custom_minimum_size.y = hauteur_ligne + (HAUTEUR_JAUGE if _ouverte else 0.0)


# --- le geste -----------------------------------------------------------------

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT \
			and e.pressed and not _ouverte:
		if max_vente <= 0 and max_achat <= 0:
			return
		_ouverte = true
		_depart_x = get_global_mouse_position().x
		_quantite = 0
		texte_prix = ""
		_ajuster()
		apercu.emit(0)
		queue_redraw()
		accept_event()


# Pendant le glissé, la souris sort vite de la ligne : on écoute donc au niveau
# du nœud plutôt que dans `_gui_input`, qui ne reçoit que ce qui tombe sur elle.
func _input(e: InputEvent) -> void:
	if not _ouverte:
		return

	if e is InputEventMouseMotion:
		var q := _quantite_pour(get_global_mouse_position().x - _depart_x)
		if q != _quantite:
			_quantite = q
			apercu.emit(q)
			queue_redraw()
		get_viewport().set_input_as_handled()

	elif e is InputEventMouseButton and not e.pressed \
			and e.button_index == MOUSE_BUTTON_LEFT:
		var q := _quantite
		_fermer()
		if q != 0:
			valide.emit(q)
		get_viewport().set_input_as_handled()

	elif e is InputEventMouseButton and e.pressed \
			and e.button_index == MOUSE_BUTTON_RIGHT:
		# Annulation : on referme sans rien échanger. C'est le filet de sécurité
		# du geste — un glissé entamé par erreur ne coûte rien.
		_fermer()
		get_viewport().set_input_as_handled()


func _fermer() -> void:
	_ouverte = false
	_quantite = 0
	texte_prix = ""
	_ajuster()
	queue_redraw()


func _quantite_pour(delta: float) -> int:
	var part: float = clampf(delta / COURSE, -1.0, 1.0)
	if part < 0.0:
		return -int(round(-part * float(max_vente)))
	return int(round(part * float(max_achat)))


func poser_prix(texte: String) -> void:
	texte_prix = texte
	queue_redraw()


func est_ouverte() -> bool:
	return _ouverte


# --- le dessin ----------------------------------------------------------------

func _draw() -> void:
	_dessiner_bande()
	if _survol or _ouverte:
		_dessiner_liseré()
	if _ouverte:
		_dessiner_jauge()


# Le bandeau part en pointe sous la vignette : un bord droit se voyait déborder
# tout autour de la denrée, dont l'image est détourée.
func _dessiner_bande() -> void:
	var haut := finesse
	var bas := hauteur_ligne - finesse
	if bas <= haut or size.x <= depart_pointe:
		return
	var x0 := depart_pointe
	var x1 := minf(depart_pointe + pointe, size.x)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x0, (haut + bas) * 0.5),
		Vector2(x1, haut),
		Vector2(size.x, haut),
		Vector2(size.x, bas),
		Vector2(x1, bas),
	]), couleur_fond)


func _dessiner_liseré() -> void:
	var haut := finesse
	var bas := hauteur_ligne - finesse
	var x0 := depart_pointe
	var x1 := minf(depart_pointe + pointe, size.x)
	var teinte := OR_VIF if _ouverte else OR
	var contour := PackedVector2Array([
		Vector2(x0, (haut + bas) * 0.5),
		Vector2(x1, haut),
		Vector2(size.x, haut),
		Vector2(size.x, bas),
		Vector2(x1, bas),
		Vector2(x0, (haut + bas) * 0.5),
	])
	draw_polyline(contour, teinte, 1.5, true)


# La jauge, sous la ligne : un rail, un curseur, et le prix au milieu. Le zéro
# est là où le doigt s'est posé, pas au centre de la ligne — c'est ce qui rend le
# geste lisible quel que soit l'endroit où l'on a appuyé.
func _dessiner_jauge() -> void:
	var y := hauteur_ligne + HAUTEUR_JAUGE * 0.5
	var zero := _depart_x - global_position.x
	var gauche := maxf(zero - COURSE, 2.0)
	var droite := minf(zero + COURSE, size.x - 2.0)

	draw_line(Vector2(gauche, y), Vector2(droite, y), ENCRE * Color(1, 1, 1, 0.35), RAIL)
	if _quantite < 0:
		draw_line(Vector2(maxf(zero - COURSE * float(-_quantite) / maxf(float(max_vente), 1.0), gauche), y),
			Vector2(zero, y), ROUGE, RAIL)
	elif _quantite > 0:
		draw_line(Vector2(zero, y),
			Vector2(minf(zero + COURSE * float(_quantite) / maxf(float(max_achat), 1.0), droite), y),
			VERT, RAIL)
	draw_line(Vector2(zero, y - RAIL), Vector2(zero, y + RAIL), OR, 1.5)

	if texte_prix == "" or police == null:
		return
	# Le texte est centré sur le ZERO : c'est le prix à l'unité qu'on lit en
	# tirant, et il doit rester sous le doigt plutôt que de courir avec lui.
	var taille := police.get_string_size(texte_prix, HORIZONTAL_ALIGNMENT_LEFT,
		-1.0, 12)
	var pos := Vector2(zero - taille.x * 0.5, y - RAIL - 4.0)
	pos.x = clampf(pos.x, 2.0, maxf(size.x - taille.x - 2.0, 2.0))
	draw_string(police, pos, texte_prix, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12,
		OR_VIF if _quantite != 0 else ENCRE)
