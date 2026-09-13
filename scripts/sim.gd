# Pont vers la simulation Lua.
#
# Tout ce qui touche à l'état du monde (géographie, navigation, et plus tard
# l'économie) vit dans sim/*.lua. Ce fichier est la seule couche qui connaisse
# à la fois Lua et Godot : le reste du moteur ne voit que des types natifs.
class_name Sim
extends RefCounted

var _lua: Object
var _bridge: Object
var pret := false
var erreur := ""


func _init() -> void:
	if not ClassDB.class_exists("LuaState"):
		erreur = "extension Lua absente (addons/lua-gdextension)"
		push_error(erreur)
		return

	_lua = ClassDB.instantiate("LuaState")
	_lua.open_libraries()

	var res = _lua.do_file("res://sim/bridge.lua")
	if res is LuaError:
		erreur = "sim/bridge.lua : %s" % res
		push_error(erreur)
		return

	_bridge = res
	pret = true


func _appel(nom: String, args: Array = []):
	if not pret:
		return null
	var f = _bridge.get(nom)
	if f == null:
		push_error("fonction Lua introuvable : %s" % nom)
		return null
	return f.invokev(args)


func iles(segments := 160) -> Array:
	var r = _appel("iles", [segments])
	return r if r is Array else []


func ports() -> Array:
	var r = _appel("ports", [])
	return r if r is Array else []


func limites() -> Vector2:
	var r = _appel("limites", [])
	return r if r is Vector2 else Vector2(1500, 1100)


func preparer_navigation() -> int:
	var r = _appel("preparer_navigation", [])
	return int(r) if r != null else 0


# --- commerce -----------------------------------------------------------------

# `lot` : la quantité envisagée. Les prix reviennent pour l'unité et pour ce
# lot-là, ce qui évite d'annoncer au joueur un cours qu'il ne paiera pas.
func marche(cle_ville: String, lot := 1) -> Array:
	var r = _appel("marche", [cle_ville, lot])
	return r if r is Array else []


# Le cours à l'unité pour un lot de cette taille. Deux appels voisins donnent
# le coût marginal : ce que coûte réellement la tonne suivante.
func cotation(cle_ville: String, cle_m: String, quantite: int, sens: String) -> float:
	var r = _appel("cotation", [cle_ville, cle_m, quantite, sens])
	return float(r) if r != null else 0.0


# Les barres d'abondance, le stock de la ville décalé de `delta` : négatif si le
# joueur achète (la ville se vide), positif s'il vend.
func barres(cle_ville: String, cle_m: String, delta := 0) -> int:
	var r = _appel("barres", [cle_ville, cle_m, delta])
	return int(r) if r != null else 0


func etat_compagnie() -> Dictionary:
	var r = _appel("etat_compagnie", [])
	return r if r is Dictionary else {"or_": 0, "capacite": 0, "charge": 0, "libre": 0}


func acheter(cle_ville: String, cle_m: String, quantite: int) -> Dictionary:
	var r = _appel("acheter", [cle_ville, cle_m, quantite])
	return r if r is Dictionary else {"ok": false, "quantite": 0, "somme": 0, "message": "erreur"}


func vendre(cle_ville: String, cle_m: String, quantite: int) -> Dictionary:
	var r = _appel("vendre", [cle_ville, cle_m, quantite])
	return r if r is Dictionary else {"ok": false, "quantite": 0, "somme": 0, "message": "erreur"}


func besoins_villes() -> Dictionary:
	var r = _appel("besoins_villes", [])
	return r if r is Dictionary else {}


func diag_marchands() -> Array:
	var r = _appel("diag_marchands", [])
	return r if r is Array else []


func marchands() -> Array:
	var r = _appel("marchands", [])
	return r if r is Array else []


# --- routes commerciales automatiques du joueur ------------------------------

func strategies() -> Array:
	var r = _appel("strategies", [])
	return r if r is Array else []


func navires_marchands() -> Array:
	var r = _appel("navires_marchands", [])
	return r if r is Array else []


func routes() -> Array:
	var r = _appel("routes", [])
	return r if r is Array else []


func armer_route(navires: Array, circuit: Array, strategie: String, capital: int) -> Dictionary:
	var r = _appel("armer_route", [navires, circuit, strategie, capital])
	return r if r is Dictionary else {}


func dissoudre_route(indice: int) -> int:
	var r = _appel("dissoudre_route", [indice])
	return int(r) if r != null else 0


func convoi_au_port(cle_ville: String) -> bool:
	var r = _appel("convoi_au_port", [cle_ville])
	return bool(r) if r != null else false


func convois_joueur() -> Array:
	var r = _appel("convois_joueur", [])
	return r if r is Array else []


func creer_convoi(navires: Array, cle_port: String) -> Dictionary:
	var r = _appel("creer_convoi", [navires, cle_port])
	return r if r is Dictionary else {}


func ordonner_convoi(indice_convoi: int, cle_port_dest: String) -> Dictionary:
	var r = _appel("ordonner_convoi", [indice_convoi, cle_port_dest])
	return r if r is Dictionary else {}


func selectionner_convoi(indice_convoi: int) -> void:
	_appel("selectionner_convoi", [indice_convoi])


func ordonner_convoi_position(indice_convoi: int, x: float, z: float) -> Dictionary:
	var r = _appel("ordonner_convoi_position", [indice_convoi, x, z])
	return r if r is Dictionary else {}


func mettre_en_route(indice_convoi: int, circuit: Array, strategie: String, capital: int) -> Dictionary:
	var r = _appel("mettre_en_route", [indice_convoi, circuit, strategie, capital])
	return r if r is Dictionary else {}


func retirer_route(indice_convoi: int) -> Dictionary:
	var r = _appel("retirer_route", [indice_convoi])
	return r if r is Dictionary else {}


func ajouter_navire_convoi(indice_convoi: int, navires: Array) -> Dictionary:
	var r = _appel("ajouter_navire_convoi", [indice_convoi, navires])
	return r if r is Dictionary else {}


func retirer_navire_convoi(indice_convoi: int, indice_navire: int) -> Dictionary:
	var r = _appel("retirer_navire_convoi", [indice_convoi, indice_navire])
	return r if r is Dictionary else {}


# --- chantier naval : acheter, construire, flotte possédée -------------------

func flotte() -> Array:
	var r = _appel("flotte", [])
	return r if r is Array else []


func chantier_file() -> Array:
	var r = _appel("chantier_file", [])
	return r if r is Array else []


func chantier_infos(cle_type: String) -> Dictionary:
	var r = _appel("chantier_infos", [cle_type])
	return r if r is Dictionary else {}


func acheter_navire(cle_ville: String, cle_type: String) -> Dictionary:
	var r = _appel("acheter_navire", [cle_ville, cle_type])
	return r if r is Dictionary else {}


func construire_navire(cle_ville: String, cle_type: String) -> Dictionary:
	var r = _appel("construire_navire", [cle_ville, cle_type])
	return r if r is Dictionary else {}


func vendre_navire(indice_flotte: int) -> Dictionary:
	var r = _appel("vendre_navire", [indice_flotte])
	return r if r is Dictionary else {}


func etat_ville(cle_ville: String) -> Dictionary:
	var r = _appel("etat_ville", [cle_ville])
	return r if r is Dictionary else {}


# --- édition ------------------------------------------------------------------

func deplacer_port(cle: String, x: float, z: float) -> bool:
	return bool(_appel("deplacer_port", [cle, x, z]))


func decaler_port(cle: String, dx: float, dz: float) -> bool:
	return bool(_appel("decaler_port", [cle, dx, dz]))


func source_reglages() -> String:
	var r = _appel("source_reglages", [])
	return str(r) if r != null else ""


func est_terre(x: float, z: float, marge := 0.0) -> bool:
	var r = _appel("est_terre", [x, z, marge])
	return bool(r) if r != null else false


func iles_parametres() -> Array:
	var r = _appel("iles_parametres", [])
	return r if r is Array else []


func route(depart: Vector3, arrivee: Vector3) -> PackedVector3Array:
	var r = _appel("route", [depart, arrivee])
	return r if r is PackedVector3Array else PackedVector3Array()


# --- calendrier ---------------------------------------------------------------

func avancer_temps(dt: float) -> float:
	var r = _appel("avancer_temps", [dt])
	return float(r) if r != null else 0.0


func etat_temps() -> Dictionary:
	var r = _appel("etat_temps", [])
	return r if r is Dictionary else {"date": "", "heure": "", "vitesse": 0, "indice": 1, "en_pause": true}


func definir_vitesse(indice: int) -> void:
	_appel("definir_vitesse", [indice])


func definir_survol(actif: bool) -> void:
	_appel("definir_survol", [actif])


func basculer_pause() -> void:
	_appel("basculer_pause", [])


func duree_traversee(metres: float, noeuds: float) -> String:
	var r = _appel("duree_traversee", [metres, noeuds])
	return str(r) if r != null else ""


# Vitesse d'un navire en mètres monde par seconde de jeu, à vitesse x1.
func vitesse_monde(noeuds: float) -> float:
	var r = _appel("vitesse_monde", [noeuds])
	return float(r) if r != null else 75.0
