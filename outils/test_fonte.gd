# La fonte de PR3, reconstruite depuis le .swf — est-elle VRAIMENT lisible ?
#
# `outils/swf_fonte.py` rebatit un TrueType a partir des DefineFont3 de
# skinlib_pr3.swf. Rien ne prouve qu'un fichier de 100 ko soit une fonte : un
# en-tete plausible et des tables mal chainees produisent le meme poids. Godot
# est ici le seul juge qui compte, puisque c'est lui qui devra l'afficher.
#
# CE QUI SERAIT UN FAUX SUCCES : `FontFile.new()` ne rate jamais, et une fonte
# vide rend des tailles nulles sans lever d'erreur. On mesure donc des GLYPHES,
# pas des objets — et on exige qu'ils soient de largeurs DIFFERENTES, sans quoi
# on regarderait un rectangle de secours servi par le repli du serveur de texte.
#
# Lance : godot --headless --path . --script res://outils/test_fonte.gd
extends SceneTree

const DOSSIER := "res://reference_pr3/ui/polices/"
const FONTES := ["Benjamin-Book", "Benjamin-Bold"]
const TAILLE := 16

# Ce que le HUD doit savoir ecrire : le nombre d'or, le rang, l'allure.
const ECHANTILLON := "1.480.445 Matelot x1"

var _echecs := 0


func _dire(ok: bool, texte: String) -> void:
	if not ok:
		_echecs += 1
	print("   %s %s" % ["ok  " if ok else "RATE", texte])


func _charger(nom: String) -> FontFile:
	var chemin := ProjectSettings.globalize_path(DOSSIER + nom + ".ttf")
	if not FileAccess.file_exists(chemin):
		_dire(false, "%s.ttf absent (%s)" % [nom, chemin])
		return null
	var f := FontFile.new()
	# Le nom de la methode a change entre les versions de Godot ; on ne veut pas
	# qu'une erreur de compilation passe pour une fonte illisible.
	var err := ERR_UNAVAILABLE
	if f.has_method("load_dynamic_font"):
		err = f.call("load_dynamic_font", chemin)
	elif f.has_method("load_dynamic_font_from_file"):
		err = f.call("load_dynamic_font_from_file", chemin)
	else:
		_dire(false, "aucune methode de chargement dynamique sur FontFile")
		return null
	if err != OK:
		_dire(false, "%s.ttf refuse par Godot (erreur %d)" % [nom, err])
		return null
	return f


func _examiner(nom: String) -> Dictionary:
	print("\n=== %s ===" % nom)
	var f := _charger(nom)
	if f == null:
		return {}
	_dire(true, "chargee, nom interne « %s », style « %s »"
		% [f.get_font_name(), f.get_font_style_name()])

	var mesures := {}
	var largeurs := {}
	for c in ["A", "o", "W", "8", "i", "1", "."]:
		var t := f.get_char_size(c.unicode_at(0), TAILLE)
		largeurs[c] = t.x
		_dire(t.x > 0.0 and t.y > 0.0, "glyphe « %s » : %.1f x %.1f" % [c, t.x, t.y])

	# Un repli de secours rend TOUJOURS la meme case. Une vraie fonte
	# proportionnelle ne peut pas donner « i » et « W » a la meme largeur.
	_dire(largeurs["i"] < largeurs["W"],
		"proportionnelle : « i » (%.1f) plus etroit que « W » (%.1f)"
			% [largeurs["i"], largeurs["W"]])

	var ligne := f.get_string_size(ECHANTILLON, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE)
	_dire(ligne.x > TAILLE * 4, "« %s » mesure %.1f x %.1f"
		% [ECHANTILLON, ligne.x, ligne.y])
	_dire(f.get_ascent(TAILLE) > 0.0 and f.get_descent(TAILLE) > 0.0,
		"ascendante %.1f, descendante %.1f"
			% [f.get_ascent(TAILLE), f.get_descent(TAILLE)])

	# Le test qui separe une fonte d'un en-tete bien forme : on FACONNE la ligne
	# et on regarde les INDEX de glyphes. Un index 0, c'est `.notdef` — le
	# caractere n'est pas dans la `cmap`, et le joueur verrait une case vide.
	var encres := 0
	var ts := TextServerManager.get_primary_interface()
	var buf := ts.create_shaped_text()
	ts.shaped_text_add_string(buf, ECHANTILLON, [f.get_rids()[0]], TAILLE)
	ts.shaped_text_shape(buf)
	_dire(ts.shaped_text_get_glyph_count(buf) >= ECHANTILLON.length() - 3,
		"%d glyphes faconnes pour %d caracteres"
			% [ts.shaped_text_get_glyph_count(buf), ECHANTILLON.length()])
	for g in ts.shaped_text_get_glyphs(buf):
		var idx: int = g.get("index", 0)
		if idx != 0:
			encres += 1
	ts.free_rid(buf)
	_dire(encres >= ECHANTILLON.length() - 3,
		"%d glyphes ont un INDEX non nul (un 0 = caractere absent de cmap)" % encres)
	mesures["largeur"] = ligne.x
	return mesures


func _init() -> void:
	print("Godot ", Engine.get_version_info().string)
	var vues := {}
	for nom in FONTES:
		vues[nom] = _examiner(nom)

	print("\n=== les deux graisses ===")
	var a: Dictionary = vues.get("Benjamin-Book", {})
	var b: Dictionary = vues.get("Benjamin-Bold", {})
	if a.has("largeur") and b.has("largeur"):
		var la: float = a["largeur"]
		var lb: float = b["largeur"]
		# Deux fichiers batis depuis deux DefineFont3 differents : s'ils mesurent
		# pareil au dixieme pres, c'est que j'ai ecrit deux fois le meme.
		_dire(absf(la - lb) > 0.5,
			"Book %.1f vs Bold %.1f — ce sont bien deux dessins" % [la, lb])

	print("\n-> %s" % ("tout passe" if _echecs == 0 else "%d echec(s)" % _echecs))
	quit(0 if _echecs == 0 else 1)
