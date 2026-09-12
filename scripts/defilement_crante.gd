# Une liste qui descend d'une ligne à la fois, jamais d'une demie.
#
# Le défilement continu de Godot laissait la marchandise du haut et celle du bas
# coupées en deux, et l'œil qui parcourt vingt lignes de chiffres n'a pas besoin
# d'une ligne tronquée de plus. Chaque cran vaut donc exactement une ligne, et la
# position se recale toujours sur un multiple de sa hauteur.
#
# On surcharge `_gui_input` plutôt que de brancher le signal : le ScrollContainer
# traite la molette dans cette méthode, et il faut la lui prendre avant qu'il ne
# fasse glisser la liste à sa façon.
class_name DefilementCrante
extends ScrollContainer

# Repli tant qu'aucune ligne n'est dessinée : la hauteur réelle ne se connaît
# qu'après la première mise en page.
const PAS_DEFAUT := 46.0

# Ce que vaut un cran au trackpad. Le glissé à deux doigts arrive en rafale de
# petits deltas, là où la molette arrive par crans francs.
const SEUIL_GESTE := 4.0

var _colonne: Container
var _reste := 0.0


func poser_colonne(c: Container) -> void:
	_colonne = c


# La hauteur d'une ligne, mesurée sur la première : elle change avec la police et
# les vignettes, et un pas figé finirait par décaler la liste d'un cheveu à
# chaque cran jusqu'à couper de nouveau.
func _pas() -> float:
	if _colonne == null:
		return PAS_DEFAUT
	# On cherche une LIGNE, pas le premier enfant venu : la colonne commence par
	# une reserve d'air qui laisse deborder la vignette du haut, et la prendre
	# pour une ligne donnait un pas de dix pixels — le crantage ne servait plus
	# a rien.
	for enfant in _colonne.get_children():
		var c := enfant as LigneMarchandise
		if c != null and c.size.y > 1.0:
			var sep := 0.0
			if _colonne is BoxContainer:
				sep = float(_colonne.get_theme_constant("separation"))
			return c.size.y + sep
	return PAS_DEFAUT


func _crans(sens: int) -> void:
	var p := _pas()
	if p <= 0.0:
		return
	# On part du cran le plus proche, pas de la position courante : si la liste a
	# été posée entre deux lignes (barre tirée à la souris, saut au clavier), le
	# premier cran la remet d'aplomb au lieu de conserver le décalage.
	var cran := roundi(float(scroll_vertical) / p)
	scroll_vertical = int(round((cran + sens) * p))


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		match e.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_crans(-1)
				accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				_crans(1)
				accept_event()
	elif e is InputEventPanGesture:
		# On accumule jusqu'à valoir un cran, sinon le geste ne ferait jamais
		# bouger la liste.
		_reste += e.delta.y
		while absf(_reste) >= SEUIL_GESTE:
			_crans(1 if _reste > 0.0 else -1)
			_reste -= SEUIL_GESTE * signf(_reste)
		accept_event()
