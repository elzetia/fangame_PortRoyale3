# Chargeur du skin de Port Royale 3 pour les écrans Godot.
#
# Les interfaces de PR3 sont des .swf Flash (Iggy). Leur art — cadres peints,
# bandes d'onglets, illustrations, icônes — a été extrait des .swf de l'install
# du joueur vers `reference_pr3/ui/<swf>/<id>.png`. Ce dossier est SOUS DROITS et
# ignoré par git, exactement comme les modèles de navires : on ne le lit donc pas
# via l'import de Godot (`load()`), mais comme de simples fichiers au runtime
# (`Image.load_from_file`), et tout est gardé en cache.
#
# Repli : si l'art n'est pas là (dépôt public, autre poste), `texture()` rend
# `null` et chaque écran retombe sur son rendu dessiné. Le comportement ne dépend
# JAMAIS de la présence de l'art — seul le look en dépend.
#
# Identités décodées des .swf (voir outils/swf_*.py) :
#   skinlib_pr3/801.png  748x578  cadre de dialogue à onglets (Dialog_Tabbed_Big)
#   skinlib_pr3/845.png  748x578  cadre de dialogue simple    (Dialog_Big)
#   skinlib_pr3/738.png  748x642  cadre XXL                   (Dialog_XXL)
#   skinlib_pr3/820.png  430x80   bande d'onglets             (Dialog_Tabbed_BG_Tabs)
#   skinlib_pr3/714.png  16x16    carreau de texture du fond
#   dialog_shipyard_pc/18.png  374x228  illustration du chantier
class_name SkinPR3
extends RefCounted

const RACINE := "res://reference_pr3/ui/"

# Cache de process : partagé par tous les écrans, gardé même vide.
static var _cache: Dictionary = {}


# Rend la texture `reference_pr3/ui/<swf>/<id>.png`, ou `null` si absente.
# `cle` est "<swf>/<id>", p. ex. "skinlib_pr3/801".
static func texture(cle: String) -> Texture2D:
	var tex := fichier(RACINE + cle + ".png")
	if tex != null:
		return tex
	# Repli `.jpg` : `swf_bitmaps.py` dépose les DefineBitsJPEG sous cette
	# extension, et 14 des 969 entrées de la table d'icônes n'existent QUE
	# ainsi — dont `Dialog_Scroll_Small_Top`, `Dialog_Scroll_Small_Bottom` et
	# `Visual_Seabattle_Big`, qui sont de l'art bien visible — plus cinq
	# caractères de `hud_pc`. Godot lit le JPEG aussi bien que le PNG : seule
	# l'extension supposée ici les rendait introuvables.
	return fichier(RACINE + cle + ".jpg")


# Charge N'IMPORTE QUELLE image de `reference_pr3/` par son chemin `res://`, au
# runtime — les atlas de navires comme le skin d'interface. Rend `null` si elle
# n'est pas là, ce qui laisse l'appelant se passer d'elle.
static func fichier(chemin_res: String) -> Texture2D:
	if _cache.has(chemin_res):
		return _cache[chemin_res]
	var res: Texture2D = null
	var chemin := ProjectSettings.globalize_path(chemin_res)
	if FileAccess.file_exists(chemin):
		var img := Image.load_from_file(chemin)
		if img != null:
			res = ImageTexture.create_from_image(img)
	_cache[chemin_res] = res
	return res


static func a_le_skin() -> bool:
	return texture("skinlib_pr3/801") != null


# Un StyleBox qui peint le cadre PR3 en fond d'un PanelContainer, étiré en
# 9-tranches (les bords peints gardent leur épaisseur, le centre s'étire). Si
# l'art manque, rend un StyleBoxFlat parchemin approchant pour ne pas casser.
static func cadre(cle: String, marge: int = 40) -> StyleBox:
	var tex := texture(cle)
	if tex == null:
		var plat := StyleBoxFlat.new()
		plat.bg_color = Color(0.921, 0.888, 0.812)
		plat.border_color = Color(0.16, 0.11, 0.07)
		plat.set_border_width_all(6)
		plat.set_corner_radius_all(4)
		plat.set_content_margin_all(16)
		return plat
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin_all(marge)
	# Marge de contenu : on rentre le contenu à l'intérieur du cadre peint.
	sb.set_content_margin_all(marge)
	return sb
