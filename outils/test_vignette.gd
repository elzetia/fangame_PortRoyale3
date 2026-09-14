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

	# --- LA PLANCHE DE FOND --------------------------------------------------
	# Sans elle la vignette flotte sur la carte, plaques et boutons sans support.
	# Ce test passait AUSSI BIEN AVANT QU'APRES son ajout : il ne savait pas
	# faire la difference. Le meme angle mort que celui des champs dupliques,
	# qu'on ne laisse pas se reinstaller.
	#
	# On verifie aussi qu'elle est DERRIERE : un fond dessine par-dessus
	# masquerait tout, et la vignette paraitrait vide au lieu de rincee.
	print("\n=== la planche de fond ===")
	var parchemin := v.get_node_or_null("parchemin") as TextureRect
	if parchemin == null:
		_rater("pas de planche de fond : la vignette flotterait sur la carte")
	else:
		var t := parchemin.texture
		print("   parchemin %s, image %s, rang %d sur %d enfants"
				% [parchemin.size, "absente" if t == null
					else "%dx%d" % [t.get_width(), t.get_height()],
					parchemin.get_index(), v.get_child_count()])
		if t == null:
			_rater("la planche de fond n'a pas d'image")
		elif Vector2(t.get_width(), t.get_height()) != v.FOND_TAILLE:
			_rater("image %dx%d, attendu %s"
					% [t.get_width(), t.get_height(), v.FOND_TAILLE])
		if parchemin.get_index() != 0:
			_rater("la planche de fond est au rang %d : elle couvrirait le reste"
					% parchemin.get_index())

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

	# --- le REMPLISSAGE ------------------------------------------------------
	# Les valeurs sont celles d'une fiche connue : on verifie qu'elles
	# ARRIVENT A L'ECRAN, et pas seulement qu'aucune erreur ne s'affiche. Un
	# champ muet est le defaut le plus facile a ne pas voir.
	print("\n=== le remplissage ===")
	v.poser_details({"charge": 24, "capacite": 200, "navires": 3, "noeuds": 40,
			"canons": 28, "equipage": 140})
	# PAR PANNEAU, et c'est le coeur de l'affaire. Plusieurs onglets declarent
	# les MEMES noms -- `tf_cannon`, `tf_crew` et `tf_strength` sont dans la
	# loupe ET dans l'escorte. Ce test cherchait GLOBALEMENT, exactement comme le
	# code qu'il verifiait : il partageait donc son angle mort, et restait vert
	# pendant qu'a l'ecran la moitie des plaques etaient blanches. Un test qui se
	# trompe de la meme facon que le code ne prouve rien.
	var attendus := {"tf_cargo": "24/200", "tf_ships": "3", "tf_knot": "40",
			"tf_cannon": "28", "tf_crew": "140"}
	for nom in attendus:
		var l := v.champ_de("convoy", str(nom))
		var vu := l.text if l != null else "<absent>"
		print("   %-12s « %s »   attendu « %s »   %s"
				% [nom, vu, attendus[nom], "OK" if vu == attendus[nom] else "*** ECART ***"])
		if vu != attendus[nom]:
			_rater("%s affiche « %s »" % [nom, vu])

	# Ce qui doit rester VIDE : la sim ne suit ni les degats ni la puissance.
	for nom in ["tf_health", "tf_strength"]:
		var l2 := v.champ_de("convoy", str(nom))
		if l2 != null and l2.text != "":
			_rater("%s devrait rester vide, il affiche « %s »" % [nom, l2.text])
	print("   tf_health et tf_strength laisses vides (aucune source) : ok")

	# La route : le TYPE doit porter le nom DU JEU, pas une cle ni ma traduction.
	v.poser_route({"nom": "Tourbillon", "villes": 6, "strategie": "wealth"})
	var tour := v.champ_de("route", "tf_tour")
	var vu_tour := tour.text if tour != null else "<absent>"
	print("   tf_tour      « %s »   attendu « Prospérité »   %s"
			% [vu_tour, "OK" if vu_tour == "Prospérité" else "*** ECART ***"])
	if vu_tour != "Prospérité":
		_rater("le type de route affiche « %s »" % vu_tour)
	if vu_tour.begins_with("ID_"):
		_rater("le type de route laisse fuir sa cle")
	var villes := v.champ_de("route", "tf_towns")
	if villes != null and villes.text != "6":
		_rater("tf_towns affiche « %s » au lieu de 6" % villes.text)

	# AUCUN TOUR BOUCLÉ : durée et gain doivent rester VIDES. Un « 0 j » ou un
	# « 0 » affirmerait une route qui tourne sans rien rapporter — ce qui n'est
	# pas la même chose que « pas encore mesuré ».
	for nom in ["tf_time", "tf_profit"]:
		var vide := v.champ_de("route", nom)
		if vide != null and vide.text != "":
			_rater("%s devrait rester vide sans rotation, il affiche « %s »"
					% [nom, vide.text])
	print("   tf_time et tf_profit vides tant qu'aucun tour n'est bouclé : ok")

	# UN TOUR BOUCLÉ : les deux champs parlent, et l'état porte les MOTS DU JEU.
	v.poser_route({"nom": "Tourbillon", "villes": 6, "strategie": "wealth",
			"rotations": 3, "rotation_jours": 18, "rotation_gain": -12450,
			"route_active": true})
	var duree := v.champ_de("route", "tf_time")
	var vu_duree := duree.text if duree != null else "<absent>"
	if vu_duree != "18 j":
		_rater("tf_time affiche « %s » au lieu de « 18 j »" % vu_duree)
	# UN GAIN NÉGATIF GARDE SON SIGNE, et les milliers au point de PR3
	# (« -12.450 ») : une route à perte affichée « 12.450 » mentirait sur son sens.
	var gain := v.champ_de("route", "tf_profit")
	var vu_gain := gain.text if gain != null else "<absent>"
	var attendu_gain := HudDroitePR3.nombre(-12450)
	if vu_gain != attendu_gain:
		_rater("tf_profit affiche « %s » au lieu de « %s »"
				% [vu_gain, attendu_gain])
	if not vu_gain.begins_with("-"):
		_rater("tf_profit perd le signe d'une rotation à perte : « %s »" % vu_gain)
	print("   tf_time « %s », tf_profit « %s » : ok" % [vu_duree, vu_gain])

	# L'état doit porter le texte de PR3, jamais sa clé.
	var etat := v.champ_de("route", "tf_state")
	var vu_etat := etat.text if etat != null else "<absent>"
	print("   tf_state     « %s »   attendu « Route activée »   %s"
			% [vu_etat, "OK" if vu_etat == "Route activée" else "*** ECART ***"])
	if vu_etat != "Route activée":
		_rater("tf_state affiche « %s »" % vu_etat)
	if vu_etat.begins_with("ID_"):
		_rater("tf_state laisse fuir sa cle")

	# --- la GRILLE DE CARGAISON ---------------------------------------------
	# Une case remplie doit porter une ICONE et une QUANTITE, et deux
	# marchandises differentes ne doivent pas montrer la meme image -- c'est ce
	# qui distingue une grille qui marche d'une grille qui pose douze fois le
	# meme tonneau. On donne treize lots pour exercer aussi la pagination.
	print("\n=== la cargaison ===")
	var lots: Array = []
	for r in range(13):
		lots.append({"cle": "m%d" % r, "nom": "M%d" % r, "rang": r,
				"quantite": 10 + r})
	v.poser_cargaison(lots)
	print("   %d lots -> %d page(s), page courante %d"
			% [lots.size(), v.pages(), v.page()])
	if v.pages() != 2:
		_rater("13 lots devraient tenir sur 2 pages, pas %d" % v.pages())

	var textures := {}
	var remplies := 0
	for i in range(12):
		var case := v.find_child("list_item_%d" % i, true, false)
		if case == null:
			continue
		var ic := case.get_node_or_null("icone") as TextureRect
		var q := case.get_node_or_null("quantite") as Label
		if ic == null or q == null:
			_rater("list_item_%d : icone ou quantite absente" % i)
			continue
		if ic.texture != null and q.text != "":
			remplies += 1
			# PAR IDENTITE D'OBJET, et non par `resource_path` : `SkinPR3`
			# fabrique ses textures en memoire depuis un fichier, et une texture
			# construite ainsi a un chemin VIDE. Les douze se reduisaient alors a
			# une seule cle, et le test criait « les cases se repetent » alors
			# que la grille allait bien -- une erreur de MESURE, pas de rendu.
			textures[ic.texture.get_instance_id()] = true
			if i < 3:
				print("      case %d : quantite « %s », image %dx%d, chemin « %s »"
						% [i, q.text, ic.texture.get_width(),
							ic.texture.get_height(), ic.texture.resource_path])
	print("   %d / 12 cases remplies, %d image(s) distincte(s)"
			% [remplies, textures.size()])
	if remplies != 12:
		_rater("%d cases remplies sur 12" % remplies)
	if textures.size() < 12:
		_rater("seulement %d images distinctes : les cases se repetent"
				% textures.size())

	# Page suivante : il ne reste qu'UN lot, donc une seule case remplie.
	v.tourner(1)
	var reste := 0
	for i in range(12):
		var case2 := v.find_child("list_item_%d" % i, true, false)
		var q2 := case2.get_node_or_null("quantite") as Label if case2 else null
		if q2 != null and q2.text != "":
			reste += 1
	print("   page %d -> %d case(s) remplie(s), 1 attendue" % [v.page(), reste])
	if reste != 1:
		_rater("page 2 : %d cases remplies, 1 attendue" % reste)
	# Et on ne doit pas pouvoir depasser la derniere page.
	v.tourner(5)
	if v.page() != v.pages() - 1:
		_rater("la pagination depasse : page %d sur %d" % [v.page(), v.pages()])
	v.tourner(-9)
	if v.page() != 0:
		_rater("la pagination passe sous zero : page %d" % v.page())

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
