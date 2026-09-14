# La vignette de convoi : elle se BATIT, et ses onglets veulent dire quelque chose.
#
# « Ca compile » ne prouve rien : un script sans faute de syntaxe peut ne trouver
# aucun de ses noeuds et rendre une carte vide, sans qu'une seule erreur
# s'affiche. Et un compteur de noeuds ment aussi -- il a menti plusieurs fois sur
# ce projet. On verifie donc le SENS :
#
#   * UN SEUL panneau visible a la fois, et c'est celui qu'on a demande ;
#   * la variante pirate masquee, sinon une tete de mort se poserait sur la
#     boussole de la route (les deux boutons sont au meme point, x = 229) ;
#   * les champs NOMMES par PR3 existent, onglet par onglet -- c'est la seule
#     chose qui prouve que ma lecture de `hud_pc.swf` etait juste ;
#   * l'en-tete change vraiment de texte quand on le pose ;
#   * aucune infobulle ne laisse fuir une cle a l'ecran (`LocaPR3` reemet la cle
#     quand la table manque : « ID_GUI_TT_... » s'afficherait tel quel).
#
# Lance : godot --headless --path . --script res://outils/test_vignette.gd
extends SceneTree

# Ce que PR3 nomme dans chaque onglet. Releve dans `hud_pc.json`, pas invente.
const CHAMPS := {
	"convoy": ["tf_cargo", "tf_ships", "tf_health", "tf_knot", "tf_cannon",
			"tf_crew", "tf_strength"],
	"bships": ["tf_crew", "tf_cannon", "tf_strength", "tf_strength_max"],
	"captain": ["tf_costs", "tf_fights", "tf_name", "tf_xp_fight",
			"tf_xp_navigate", "tf_xp_trade", "tf_xp_repair", "tf_xp_enter",
			"tf_xp_view"],
	"route": ["tf_name", "tf_towns", "tf_time", "tf_profit", "tf_tour",
			"tf_state"],
}

# Les boutons que PR3 pose dans ces onglets.
const BOUTONS := ["bu_patrol", "bu_attack_town", "bu_max", "bu_organize",
		"bu_activate", "bu_edit", "bu_save", "bu_load", "bu_prev", "bu_next"]

var _ecarts := 0


func _rater(quoi: String) -> void:
	_ecarts += 1
	print("   ECART  ", quoi)


func _init() -> void:
	var v := ConvoiVignettePR3.new()
	get_root().add_child(v)
	# `_ready()` N'A PAS ENCORE TOURNE : on est dans `_init()` de la SceneTree,
	# avant la premiere image. Sans cette attente la vignette parait VIDE, et
	# c'est exactement ce que ce test a signale au premier essai. On laisse
	# passer une image plutot que d'appeler `_ready()` a la main -- on veut le
	# vrai chemin de code, sinon le test ne prouve rien. (Meme remarque que
	# `outils/test_minimap.gd`, qui l'avait deja paye.)
	await process_frame
	print("vignette batie : %d enfant(s)" % v.get_child_count())
	if v.get_child_count() == 0:
		_rater("la vignette est vide : `batir` n'a rien rendu")
		quit(1)
		return

	# --- les cinq onglets ----------------------------------------------------
	print("\n=== les onglets ===")
	for paire in ConvoiVignettePR3.ONGLETS:
		var nom_panneau: String = paire[1]
		v.montrer(nom_panneau)
		if v.onglet() != nom_panneau:
			_rater("montrer(%s) : l'onglet actif est %s" % [nom_panneau, v.onglet()])
		var visibles := PackedStringArray()
		for autre in ConvoiVignettePR3.ONGLETS:
			var n: String = autre[1]
			var p := v.find_child(n, true, false) as Control
			if p == null:
				_rater("panneau introuvable : %s" % n)
			elif p.visible:
				visibles.append(n)
		print("   %-9s -> visible(s) : %s" % [nom_panneau, ", ".join(visibles)])
		if visibles.size() != 1 or visibles[0] != nom_panneau:
			_rater("%s : %d panneau(x) visible(s), un seul attendu"
					% [nom_panneau, visibles.size()])

	# --- la variante pirate --------------------------------------------------
	print("\n=== la variante pirate ===")
	for nom in ["bu_pirate", "pirate"]:
		var n := v.find_child(nom, true, false) as Control
		if n == null:
			print("   %s : absent du .swf rejoue" % nom)
		else:
			print("   %s : visible = %s" % [nom, n.visible])
			if n.visible:
				_rater("%s est visible : il se poserait sur la route" % nom)

	# --- les champs que PR3 nomme -------------------------------------------
	print("\n=== les champs, onglet par onglet ===")
	for onglet in CHAMPS:
		var manquants := PackedStringArray()
		for nom in CHAMPS[onglet]:
			if v.find_child(str(nom), true, false) == null:
				manquants.append(str(nom))
		print("   %-9s %d champ(s), manquant(s) : %s"
				% [onglet, (CHAMPS[onglet] as Array).size(),
					"aucun" if manquants.is_empty() else ", ".join(manquants)])
		if not manquants.is_empty():
			_rater("%s : %d champ(s) introuvable(s)" % [onglet, manquants.size()])

	# --- les douze cases de cargaison ---------------------------------------
	var cases := 0
	for i in range(12):
		if v.find_child("list_item_%d" % i, true, false) != null:
			cases += 1
	print("\n=== cargaison : %d / 12 cases ===" % cases)
	if cases < 12:
		_rater("cargaison : %d cases sur 12" % cases)

	# --- les boutons d'action ------------------------------------------------
	var absents := PackedStringArray()
	for nom in BOUTONS:
		if v.find_child(nom, true, false) == null:
			absents.append(nom)
	print("=== boutons : %d / %d, absent(s) : %s ==="
			% [BOUTONS.size() - absents.size(), BOUTONS.size(),
				"aucun" if absents.is_empty() else ", ".join(absents)])
	if not absents.is_empty():
		_rater("%d bouton(s) introuvable(s)" % absents.size())

	# --- l'en-tete : il doit CHANGER ----------------------------------------
	print("\n=== l'en-tete ===")
	v.poser_entete("Tourbillon", "Evangelista (0.5)")
	var bu_name := v.find_child("bu_name", true, false)
	var vu_nom := ""
	if bu_name != null:
		var t := bu_name.find_child("mctext", true, false) as Label
		if t != null:
			vu_nom = t.text
	print("   nom affiche : « %s »" % vu_nom)
	if vu_nom != "Tourbillon":
		_rater("le nom du convoi ne s'affiche pas (« %s »)" % vu_nom)

	# --- les infobulles ------------------------------------------------------
	print("\n=== les infobulles ===")
	var fuites := 0
	for n in v.find_children("*", "Button", true, false):
		var b := n as Button
		if b.tooltip_text != "":
			print("   %-14s « %s »" % [b.name, b.tooltip_text])
			if b.tooltip_text.begins_with("ID_"):
				fuites += 1
	if fuites > 0:
		_rater("%d infobulle(s) laissent fuir leur cle" % fuites)

	print()
	if _ecarts > 0:
		print("%d ecart(s)." % _ecarts)
		quit(1)
		return
	print("La vignette se batit, ses onglets s'excluent et ses champs existent.")
	quit(0)
