# Les vignettes de village : chargement, stade de croissance, et surtout
# EMPRISE — le rectangle qu'un village occupe sur la carte.
#
# Ce dernier calcul vit ici, et nulle part ailleurs. Deux endroits en ont
# besoin : la scène de jeu, qui dessine le village et le laisse saisir à la
# souris, et la cuisson, qui doit réserver une clairière autour de lui pour ne
# pas planter de palmier au milieu des toits. Recopié des deux côtés, il
# divergerait au premier réglage — exactement ce que la fiche de projection
# évite déjà pour le cadrage.
class_name Villes
extends RefCounted

const DOSSIER := "res://sprites/villes/"
# LA MOITIE de ce qu'elle valait. Passee au tiers exact (0,073) puis a 0,098,
# elle restait un cran trop petite. Les vignettes avaient ete calibrees sur un
# archipel de sept iles ; sur la carte entiere des Caraibes, un village couvrait
# la moitie de son ile. Toucher a cette constante oblige a RECUIRE : la cuisson
# reserve la clairiere d'apres cette meme emprise.
# Taille d'un village en UNITÉS DE MONDE par pixel de sprite, et non en pixels
# de carte : sinon la vignette change de taille des que la carte change de
# finesse. 0,2836 = l'ancien 0,11 multiplie par les 2,578 unites par pixel de la
# carte cuite, donc a l'identique sur celle-ci.
const ECHELLE_MONDE := 0.2836

# Seuils de population des cinq stades : cases de chaume, maisons de tuiles,
# maisons de pierre, chapelle à un clocher, église à deux clochers.
const SEUILS := [900, 1800, 2800, 3600]

var textures: Array[Texture2D] = []
var ancrages: Array[Vector2] = []


func _init() -> void:
	var chemin := DOSSIER + "villes.json"
	if not FileAccess.file_exists(chemin):
		push_warning("sprites de villes absents : " + chemin)
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	if typeof(d) != TYPE_DICTIONARY:
		return
	for sp in d.get("sprites", []):
		var tex: Texture2D = load(DOSSIER + str(sp["fichier"]))
		if tex == null:
			continue
		textures.append(tex)
		var a: Array = sp["ancrage"]
		ancrages.append(Vector2(a[0], a[1]))


func vide() -> bool:
	return textures.is_empty()


# Stade de croissance d'après la population. C'est ce qui donnera tout son sel
# à l'économie : un comptoir qui devient une cité sous les yeux du joueur, sans
# qu'aucun texte ne l'annonce.
func stade(habitants: int) -> int:
	var n := 0
	for seuil in SEUILS:
		if habitants >= int(seuil):
			n += 1
	return mini(n, maxi(textures.size() - 1, 0))


func texture_pour(port: Dictionary) -> Texture2D:
	if textures.is_empty():
		return null
	return textures[stade(int(port.get("habitants", 0)))]


# Rectangle occupé par le village sur la carte, en pixels d'image.
#
# LA VIGNETTE EST CENTRÉE SUR LE POINT DU PORT. Elle ne l'était pas : elle se
# posait par son ancrage de base, puis on la REPOUSSAIT vers l'intérieur des
# terres de 45 % de sa hauteur, le long de l'axe mouillage -> bourg, pour qu'une
# ville de côte nord ne déborde pas sur sa propre mer. Le village se retrouvait
# donc à côté de son point au lieu d'être dessus, et c'est ce décalage qu'on
# retire.
#
# UNE CONSÉQUENCE À CONNAÎTRE : `cuisson_carte.gd` appelle CETTE MÊME fonction
# pour réserver la clairière autour de chaque village (`_clairieres`, emprise
# élargie de 16 %). Une carte cuite AVANT ce changement garde donc ses clairières
# à l'ancienne place — il faut la recuire, sans quoi des palmiers poussent au
# milieu des toits. C'est tout l'intérêt d'avoir gardé ce calcul dans un seul
# endroit : le rendu et la cuisson ne peuvent pas diverger, mais ils doivent être
# refaits ensemble.
#
# Le `decalage` de la fiche du port reste appliqué : c'est une donnée d'auteur,
# qui écarte l'image d'un relief gênant. Le point réel, lui, ne bouge jamais —
# c'est lui qui sert au mouillage.
func emprise(proj: ProjectionCarte, port: Dictionary) -> Rect2:
	if textures.is_empty():
		return Rect2()
	var i := stade(int(port.get("habitants", 0)))
	var tex: Texture2D = textures[i]
	# Combien de pixels de carte vaut une unite de monde, ici et maintenant.
	var ech: float = ECHELLE_MONDE * float(proj.pixels.x) / proj.vue_taille.x
	var taille := Vector2(tex.get_width(), tex.get_height()) * ech

	var bourg: Vector3 = port["bourg"]
	var dec: Vector2 = port.get("decalage", Vector2.ZERO)
	var p_img := proj.vers_carte(bourg.x + dec.x, bourg.z + dec.y, 14.0)
	return Rect2(p_img - taille * 0.5, taille)
