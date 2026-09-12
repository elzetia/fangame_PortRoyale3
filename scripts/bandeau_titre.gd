# L'en-tête des écrans de ville : une planche de bois, le nom du port gravé au
# milieu, un bouton « i » à gauche et une croix à droite.
#
# Le même objet sert au comptoir et aux infos : ce sont deux pages d'un même
# dossier, et un en-tête qui change d'une page à l'autre les ferait lire comme
# deux fenêtres sans rapport.
#
# La planche est un NinePatchRect : seules les extrémités portent un dessin
# (l'équerre et son bouton), le milieu n'est que du bois. On étire donc le
# milieu et on laisse les bouts tranquilles, ce qui permet au bandeau de tenir
# n'importe quelle largeur sans déformer les deux boutons ronds.
#
# Ils sont VRAIMENT cliquables. Une croix dessinée qui ne ferme rien se lit
# comme une panne — c'est exactement ce qui est arrivé aux trois onglets du
# comptoir, restés décoratifs assez longtemps pour passer pour un bug.
class_name BandeauTitre
extends Control

signal ferme
signal infos

const PLANCHE := "res://sprites/ui_pr/barre_titre.png"
const POLICE := "res://polices/serif_gras.ttf"

# La texture fait 1138 × 130. Les 130 premiers et derniers pixels portent
# l'équerre dorée et son bouton : c'est ce qu'on soustrait à l'étirement.
const HAUTEUR := 130.0
const BOUT := 130.0

# Le rond cliquable dans son bout de planche, mesuré sur la texture.
const RAYON_BOUTON := Vector2(96, 96)
const MARGE_BOUTON := 12.0

const OR_PALE := Color(0.98, 0.92, 0.76)

var _planche: NinePatchRect
var _nom: Label
var _b_infos: Button
var _b_ferme: Button


func _init() -> void:
	custom_minimum_size.y = HAUTEUR
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	_planche = NinePatchRect.new()
	_planche.set_anchors_preset(Control.PRESET_FULL_RECT)
	_planche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(PLANCHE):
		_planche.texture = load(PLANCHE)
	_planche.patch_margin_left = int(BOUT)
	_planche.patch_margin_right = int(BOUT)
	# Rien à préserver en haut ni en bas : le bandeau garde sa hauteur native,
	# donc la bande centrale ne s'étire que dans un seul sens.
	_planche.patch_margin_top = 0
	_planche.patch_margin_bottom = 0
	add_child(_planche)

	# Le nom du port est posé PAR-DESSUS la planche, pas gravé dedans : la même
	# image sert alors aux soixante ports.
	_nom = Label.new()
	_nom.set_anchors_preset(Control.PRESET_FULL_RECT)
	_nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nom.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_nom.add_theme_font_size_override("font_size", 40)
	_nom.add_theme_color_override("font_color", OR_PALE)
	_nom.add_theme_constant_override("shadow_offset_y", 2)
	_nom.add_theme_color_override("font_shadow_color", Color(0.20, 0.10, 0.04, 0.8))
	_nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(POLICE):
		_nom.add_theme_font_override("font", load(POLICE))
	add_child(_nom)

	_b_infos = _rond("Infos de la ville")
	_b_infos.pressed.connect(func() -> void: infos.emit())
	add_child(_b_infos)

	_b_ferme = _rond("Fermer")
	_b_ferme.pressed.connect(func() -> void: ferme.emit())
	add_child(_b_ferme)

	resized.connect(_replacer)
	_replacer()


# Un bouton sans habillage : le rond est déjà peint sur la planche, on ne pose
# qu'une zone sensible par-dessus.
func _rond(infobulle: String) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = infobulle
	b.custom_minimum_size = RAYON_BOUTON
	b.size = RAYON_BOUTON
	return b


func _replacer() -> void:
	if _b_infos == null or _b_ferme == null:
		return
	var y := (size.y - RAYON_BOUTON.y) * 0.5
	_b_infos.position = Vector2(MARGE_BOUTON, y)
	_b_ferme.position = Vector2(size.x - RAYON_BOUTON.x - MARGE_BOUTON, y)
	# Le nom ne doit pas courir sous les deux ronds : on le borne entre eux. Il
	# est ancré plein cadre, donc on le rentre par ses MARGES — lui poser une
	# taille en dur se ferait écraser au premier redimensionnement, et Godot
	# prévient qu'il n'en tiendra pas compte.
	_nom.offset_left = BOUT
	_nom.offset_right = -BOUT
	_nom.offset_top = 0
	_nom.offset_bottom = 0


func poser(nom: String) -> void:
	if _nom != null:
		_nom.text = nom


# Sur la page d'infos, le « i » désigne la page où l'on est déjà.
func griser_infos(grise: bool) -> void:
	if _b_infos != null:
		_b_infos.disabled = grise
