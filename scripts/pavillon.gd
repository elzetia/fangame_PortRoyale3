# Les pavillons des cinq couronnes.
#
# Ce sont désormais des IMAGES, fournies sur une planche et détourées par
# `outils/decouper_pavillons.py`. Elles remplacent les motifs que ce fichier
# traçait en code — champs, croix et fleurs de lys posés au `draw_rect`.
#
# Le tracé avait ses raisons : aucune dépendance à des textures, net à n'importe
# quelle taille, et une nation de plus tenait en dix lignes. Mais un pavillon
# dessiné à plat est un rectangle de couleur, quand celui-ci ondule, porte son
# écu et se lit comme une étoffe. Sur une carte qui vient tout entière de Port
# Royale 3, c'était le dernier élément qui avait encore l'air d'un placeholder.
#
# Les vignettes sont des drapeaux à hampe libre, plus larges que hautes et aux
# coins transparents. On les pose donc à la HAUTEUR demandée, largeur déduite du
# rapport de l'image : étirées au rectangle, elles s'écrasent, et une étoffe
# écrasée se voit tout de suite.
class_name Pavillon
extends RefCounted

const DOSSIER := "res://sprites/pavillons/"

# Chargées une seule fois pour toute la partie. Soixante ports redemandent la
# même poignée de textures à chaque image : les relire à chaque appel coûterait
# un accès disque par village et par trame.
static var _textures: Dictionary = {}
static var _chargees := false


static func _charger() -> void:
	_chargees = true
	var nations: PackedStringArray = ["espagne", "angleterre", "france",
								  "hollande", "portugal"]
	for nation in nations:
		var chemin: String = DOSSIER + nation + ".png"
		if not ResourceLoader.exists(chemin):
			continue
		var tex: Texture2D = load(chemin)
		if tex != null:
			_textures[nation] = tex


static func texture(cle: String) -> Texture2D:
	if not _chargees:
		_charger()
	return _textures.get(cle, null)


static func dessiner(ci: CanvasItem, cle: String, rect: Rect2) -> void:
	var tex := texture(cle)
	if tex == null:
		# Une couronne sans vignette reste visible : mieux vaut un carré gris
		# qu'un port qui perd son pavillon sans qu'on sache pourquoi.
		ci.draw_rect(rect, Color(0.6, 0.6, 0.6))
		ci.draw_rect(rect, Color(0.10, 0.09, 0.08), false, maxf(1.0, rect.size.y * 0.08))
		return

	var taille := Vector2(tex.get_width(), tex.get_height())
	var h := rect.size.y
	var l := h * taille.x / taille.y
	var pose := Rect2(rect.position + Vector2((rect.size.x - l) * 0.5, 0.0),
					  Vector2(l, h))

	# Une ombre d'un pixel, décalée vers le bas-droite comme toutes les ombres
	# de la carte. Sans elle, un pavillon clair — l'anglais, le hollandais —
	# disparaît sur le sable, et un pavillon sombre se noie dans la mer. La
	# planche fournie en portait une, mais peinte DANS l'image : elle aurait
	# tourné avec la vignette au lieu de suivre le soleil.
	var d := maxf(1.0, h * 0.09)
	ci.draw_texture_rect(tex, Rect2(pose.position + Vector2(d, d), pose.size),
						 false, Color(0.05, 0.04, 0.03, 0.55))
	ci.draw_texture_rect(tex, pose, false)
