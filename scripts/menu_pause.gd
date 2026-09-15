# Le menu du joueur, celui qu'Échap ouvre — la `Scene_Ingame_Menu` de PR3.
#
# POURQUOI IL EXISTE : Échap QUITTAIT LE JEU, sans rien demander. Une frappe par
# réflexe et la partie était perdue. C'était une ligne dans `carte2d.gd` :
#
#     KEY_ESCAPE: get_tree().quit()
#
# CE QUE PR3 MET DEDANS, relevé dans `ingame_menu.swf` et sa table de textes :
#
#   ID_GUI_INGAME_MENU_HEADLINE        Menu joueur
#   ID_GUI_INGAME_MENU_CONTINUE        Reprendre le jeu
#   ID_GUI_INGAME_MENU_SAVE            Sauvegarder la partie
#   ID_GUI_INGAME_MENU_LOAD            Charger
#   ID_GUI_INGAME_MENU_OPTIONS         Paramètres
#   ID_GUI_INGAME_MENU_ACHIEVEMENTS    Succès
#   ID_GUI_INGAME_MENU_BACK_TO_TITLE   Menu principal
#
# LA DISPOSITION, mesurée dans son agencement. `Scene_Ingame_Menu` pose son groupe
# de boutons en (81, 62) ; le groupe aligne huit emplacements
# `Visual_Textbutton_Standard_W260` à x = 130, y = 15, 55, 95 … 295 — donc un pas
# de 40.
#
# ATTENTION À L'ANCRAGE : la table d'icônes donne à ce bouton un décalage de
# (-130, -15), soit la moitié de ses 260 x 30. Ce x = 130 est donc son CENTRE et
# non son coin — le bouton couvre 0 à 260 dans le groupe. Pris pour un coin, la
# colonne débordait le cadre de 260 px. C'est le même piège que la couronne du
# cartouche des villes, et cette fois il est vu.
#
# CE QU'ON NE SAIT PAS ENCORE FAIRE est GRISÉ, pas retiré : Paramètres, Succès et
# Menu principal n'ont pas d'écran ici. Un menu amputé ment sur le jeu ; un menu
# grisé dit ce qui reste à construire. Même règle que les pétales du radial.
#
# ET « QUITTER » DEMANDE DEUX FOIS. C'est tout l'objet de cet écran : le premier
# clic change le libellé en confirmation, le second seulement ferme le jeu.
class_name MenuPause
extends CanvasLayer

signal ferme

# --- la disposition de PR3, en pixels de sa scène ---------------------------
const PR3_GROUPE := Vector2(81.0, 62.0)   # `mc_buttons` dans la scène
const PR3_BOUTON := Vector2(260.0, 30.0)  # `Visual_Textbutton_Standard_W260`
const PR3_X := 130.0                      # CENTRE du bouton dans le groupe
const PR3_Y0 := 15.0                      # centre du premier
const PR3_PAS := 40.0                     # d'un bouton au suivant

const BOIS       := Color(0.16, 0.11, 0.07)
const BOIS_CLAIR := Color(0.26, 0.18, 0.11)
const OR         := Color(0.86, 0.71, 0.36)
const LIN        := Color(0.921, 0.888, 0.812)
const GRIS       := Color(0.55, 0.52, 0.47)

# Les entrées, dans l'ordre de PR3. `action` vide = pas encore d'écran.
const ENTREES := [
	{"loca": "ID_GUI_INGAME_MENU_CONTINUE", "txt": "Reprendre le jeu", "action": "reprendre"},
	{"loca": "ID_GUI_INGAME_MENU_SAVE", "txt": "Sauvegarder la partie", "action": "sauver"},
	{"loca": "ID_GUI_INGAME_MENU_LOAD", "txt": "Charger", "action": "charger"},
	{"loca": "ID_GUI_INGAME_MENU_OPTIONS", "txt": "Paramètres", "action": ""},
	{"loca": "ID_GUI_INGAME_MENU_ACHIEVEMENTS", "txt": "Succès", "action": ""},
	{"loca": "ID_GUI_INGAME_MENU_BACK_TO_TITLE", "txt": "Menu principal", "action": ""},
	{"loca": "ID_GUI_GD_EXIT_PROGRAM_TITLE", "txt": "Quitter", "action": "quitter"},
]

var _sim: Object = null
var _racine: Control
var _voile: ColorRect
var _note: Label
# Le jeu était-il DÉJÀ en pause quand on a ouvert ? Si oui, on ne le relance pas
# en fermant : sans ça, le menu réveillait une partie que le joueur avait arrêtée.
var _pause_avant := false
var _quitter_arme := false
var _bouton_quitter: Button


func _ready() -> void:
	layer = 70
	visible = false
	_batir()


func _batir() -> void:
	_voile = ColorRect.new()
	_voile.color = Color(0, 0, 0, 0.55)
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_voile)

	var haut := PR3_GROUPE.y + PR3_Y0 + PR3_PAS * ENTREES.size() + 34.0
	var large := float(EcranPR3.CADRE_LARGEUR)

	_racine = Control.new()
	_racine.set_anchors_preset(Control.PRESET_CENTER)
	_racine.size = Vector2(large, haut)
	_racine.position = -_racine.size / 2.0
	_racine.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_racine)
	_racine.add_child(EcranPR3.cadre_tabbed(int(haut)))

	var titre := Label.new()
	titre.text = LocaPR3.texte("ID_GUI_INGAME_MENU_HEADLINE", "Menu joueur")
	titre.position = Vector2(0, 18)
	titre.size = Vector2(large, 30)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 20)
	titre.add_theme_color_override("font_color", Color(0.95, 0.90, 0.76))
	_racine.add_child(titre)

	for i in ENTREES.size():
		_entree(i, ENTREES[i])

	# La ligne de retour : ce que la dernière action a donné.
	_note = Label.new()
	_note.position = Vector2(0, haut - 30)
	_note.size = Vector2(large, 22)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", 12)
	_note.add_theme_color_override("font_color", OR)
	_racine.add_child(_note)


func _entree(i: int, e: Dictionary) -> void:
	var actif := String(e["action"]) != ""
	var b := Button.new()
	b.text = LocaPR3.texte(String(e["loca"]), String(e["txt"]))
	# Le x de PR3 est un CENTRE : le bouton couvre x-130 à x+130.
	b.position = PR3_GROUPE + Vector2(PR3_X - PR3_BOUTON.x / 2.0,
			PR3_Y0 + PR3_PAS * i - PR3_BOUTON.y / 2.0)
	b.size = PR3_BOUTON
	b.add_theme_font_size_override("font_size", 14)
	b.disabled = not actif

	var st := StyleBoxFlat.new()
	st.bg_color = LIN if actif else Color(LIN.r, LIN.g, LIN.b, 0.40)
	st.border_color = BOIS_CLAIR if actif else GRIS
	st.set_border_width_all(2)
	st.set_corner_radius_all(4)
	var sh := st.duplicate() as StyleBoxFlat
	sh.bg_color = OR
	# LES SIX ÉTATS, et pas seulement `normal` : un bouton désactivé sans style
	# propre retombe sur le thème de Godot, qui pose un rectangle sombre. C'est le
	# carré noir qui est apparu derrière les pétales grises du menu radial.
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", sh if actif else st)
	b.add_theme_stylebox_override("pressed", sh if actif else st)
	b.add_theme_stylebox_override("disabled", st)
	b.add_theme_stylebox_override("focus", st)
	b.add_theme_color_override("font_color", BOIS if actif else GRIS)
	b.add_theme_color_override("font_hover_color", BOIS)
	b.add_theme_color_override("font_disabled_color", GRIS)
	if actif:
		b.pressed.connect(_agir.bind(String(e["action"])))
	else:
		b.tooltip_text = "Pas encore en place"
	_racine.add_child(b)
	if String(e["action"]) == "quitter":
		_bouton_quitter = b


# --- ouvrir, fermer ---------------------------------------------------------

func ouvrir(sim_obj: Object) -> void:
	_sim = sim_obj
	_desarmer_quitter()
	_note.text = ""
	# ON MET LE JEU EN PAUSE, comme PR3. Et l'on retient s'il l'était déjà : sinon
	# fermer le menu relancerait une partie que le joueur avait arrêtée lui-même.
	_pause_avant = _en_pause()
	if _sim != null and not _pause_avant and _sim.has_method("basculer_pause"):
		_sim.basculer_pause()
	visible = true


func fermer() -> void:
	if not visible:
		return
	if _sim != null and not _pause_avant and _en_pause() and _sim.has_method("basculer_pause"):
		_sim.basculer_pause()
	visible = false
	_desarmer_quitter()
	ferme.emit()


func _en_pause() -> bool:
	if _sim == null or not _sim.has_method("etat_temps"):
		return false
	return bool((_sim.etat_temps() as Dictionary).get("en_pause", false))


func _desarmer_quitter() -> void:
	_quitter_arme = false
	if _bouton_quitter != null:
		_bouton_quitter.text = LocaPR3.texte("ID_GUI_GD_EXIT_PROGRAM_TITLE", "Quitter")


func _agir(action: String) -> void:
	match action:
		"reprendre":
			fermer()
		"sauver":
			if _sim == null:
				return
			var r: Dictionary = _sim.sauver("partie")
			_note.text = ("Partie enregistrée." if bool(r.get("ok", false))
					else "Enregistrement impossible : " + String(r.get("message", "")))
		"charger":
			if _sim == null:
				return
			var c: Dictionary = _sim.charger("partie")
			if bool(c.get("ok", false)):
				_note.text = "Partie reprise."
				fermer()
			else:
				_note.text = "Reprise impossible : " + String(c.get("message", ""))
		"quitter":
			# DEUX FOIS. Le premier clic arme, le second ferme le jeu — c'est tout
			# l'objet de cet écran, puisque c'est un Échap réflexe qui faisait
			# perdre des parties.
			if not _quitter_arme:
				_quitter_arme = true
				if _bouton_quitter != null:
					_bouton_quitter.text = "Confirmer : quitter"
				_note.text = "Les progrès non enregistrés seront perdus."
				return
			get_tree().quit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		# Échap referme le menu au lieu de le rouvrir — et surtout, on MARQUE
		# l'événement traité pour que la carte ne le voie pas.
		fermer()
		get_viewport().set_input_as_handled()
