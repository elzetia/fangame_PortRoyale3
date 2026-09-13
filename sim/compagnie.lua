-- La compagnie du joueur : sa caisse et la cale de ses navires.
--
-- Départ de carrière conforme à Port Royale : 1er janvier 1600, vingt mille
-- pièces d'or et un sloop — celui de PR3, et sa cale de deux cents tonneaux.
--
-- L'achat et la vente passent obligatoirement par ici, jamais directement par
-- `sim.economie` : c'est le seul endroit qui sache à la fois ce que la ville
-- demande, ce que la caisse contient et ce que la cale peut porter. Une
-- transaction ne doit jamais pouvoir réussir à moitié.

local Archipel     = require("sim.archipel")
local Economie     = require("sim.economie")
local Marchandises = require("sim.marchandises")
local Navires      = require("sim.navires")
local Marchands    = require("sim.marchands")
local Chantier     = require("sim.chantier")

local Compagnie = {}

-- LA RÉPUTATION, comme PR3 la fait bouger au commerce (`0x7839E0`, `0x783B40`).
-- Elle est tenue **PAR VILLE** : le jeu la range dans un tableau indexé par
-- l'identifiant de la ville (`0x75CEF0`, une entrée par ville). Vendre à une ville
-- dont le stock est SOUS son premier seuil de prix X1 comble un manque et FAIT
-- MONTER sa réputation, au prorata de la part comblée ; acheter jusqu'à la faire
-- passer sous X1 aggrave le manque et la FAIT BAISSER d'autant. De 0 à 100, départ
-- 50 — ni amie ni ennemie.
--
-- PR3 la range en interne sur une échelle plus large (−1000 à 1000, `0x75CC30`)
-- qu'il ramène à 0-100 pour l'affichage ; on garde directement l'échelle visible.
-- Il tient aussi une réputation par NATION (`RepNation`, `ID_REPUTATION_NATION_*`),
-- nourrie par les missions et les annexions ; le commerce, lui, ne touche que
-- celle de la ville. On en dérive une moyenne par nation pour l'affichage large.
Compagnie.REP_DEPART = 50
Compagnie.REP_PLEIN = 3.0     -- points pour un lot qui comble un X1 entier de manque

local function ajuster_reputation(cle_ville, cle_m, stock_avant, sens, quantite)
  local l = Economie.ligne(cle_ville, cle_m)
  if not l then return end
  local x1 = l.seuils[2]
  if x1 <= 0 then return end

  local delta = 0
  if sens == "vente" then
    -- La part du manque (sous X1) que ce lot vient combler.
    local manque = math.max(0, x1 - stock_avant)
    if manque > 0 then delta = Compagnie.REP_PLEIN * math.min(quantite, manque) / x1 end
  else -- achat
    -- La part du lot qui fait descendre le stock sous X1.
    local sous_x1 = math.max(0, x1 - (stock_avant - quantite)) - math.max(0, x1 - stock_avant)
    if sous_x1 > 0 then delta = -Compagnie.REP_PLEIN * math.min(quantite, sous_x1) / x1 end
  end
  if delta ~= 0 then
    local r = (Compagnie.reputation[cle_ville] or Compagnie.REP_DEPART) + delta
    if r < 0 then r = 0 elseif r > 100 then r = 100 end
    Compagnie.reputation[cle_ville] = r
  end
end


-- La réputation du joueur dans une ville, de 0 à 100.
function Compagnie.reputation_ville(cle_ville)
  return Compagnie.reputation[cle_ville] or Compagnie.REP_DEPART
end


-- La réputation moyenne auprès d'une nation : la moyenne de ses villes. C'est
-- l'agrégat que PR3 montre à côté du drapeau, faute de simuler les missions.
function Compagnie.reputation_nation(cle_nation)
  local somme, n = 0, 0
  for _, port in ipairs(Archipel.ports) do
    if port.nation == cle_nation then
      somme = somme + Compagnie.reputation_ville(port.cle)
      n = n + 1
    end
  end
  return n > 0 and somme / n or Compagnie.REP_DEPART
end

-- LA FLOTTE DU JOUEUR, telle que PR3 la fait vivre (voir `sim/chantier.lua`).
--
-- On ACHÈTE ou on CONSTRUIT des navires au chantier ; ils entrent dans la flotte
-- possédée (`Compagnie.flotte`), à quai, désœuvrés. On en AFFECTE ensuite plusieurs
-- à un convoi automatique (`Compagnie.convois`), qui part sur un circuit avec une
-- stratégie et commerce seul — le cœur de Port Royale. Dissoudre un convoi rend ses
-- navires à la flotte. On peut donc avoir autant de convois qu'on veut, chacun taillé
-- sur mesure, dans les limites de PR3 (50 navires en tout, 50 par convoi, 100 convois).
--
-- Un « navire possédé » est léger : sa clé de type (`sim/navires`) et un nom propre.
-- La coque et l'équipage ne sont pas encore suivis faute de combat dans la sim.
Compagnie.flotte = {}         -- navires possédés, à quai, non affectés
Compagnie.file_chantier = {}  -- constructions en cours : { cle, nom, ville, jours }
Compagnie.convois = {}        -- TOUS les convois du joueur (manuel ou route)
Compagnie.selection = 1       -- indice du convoi sélectionné (celui que commande le joueur)


-- Le convoi que le joueur commande en ce moment : celui qu'il déplace sur la carte
-- et pour qui il négocie au comptoir. C'est là que va la cargaison achetée.
function Compagnie.convoi_actif()
  return Compagnie.convois[Compagnie.selection]
end


-- Choisit le convoi actif (borne l'indice ; garde l'actuel si l'indice est mauvais).
function Compagnie.selectionner(indice)
  if Compagnie.convois[indice] then Compagnie.selection = indice end
end

-- Baptise chaque navire pour le distinguer dans la flotte : « Sloop 3 ».
local function baptiser(navire)
  Compagnie.compteur_navires = (Compagnie.compteur_navires or 0) + 1
  return string.format("%s %d", navire.nom, Compagnie.compteur_navires)
end


-- Combien de navires le joueur possède EN TOUT : flotte à quai + constructions en
-- cours + navires embarqués dans les convois + son navire personnel. C'est ce total
-- que plafonne `maxShips` (50).
function Compagnie.nombre_navires()
  local n = #Compagnie.flotte + #Compagnie.file_chantier
  for _, m in ipairs(Compagnie.convois) do
    n = n + #(m.navires_joueur or m.navires or {})
  end
  return n
end


-- Le chantier est PROPRE À CHAQUE PORT : on n'achète et on ne construit qu'au port
-- où l'on est, et seulement s'il a un chantier assez grand pour ce navire. Renvoie
-- un message d'erreur, ou nil si tout va bien.
local function verifier_chantier(cle_ville, cle_type)
  local port = Archipel.portsParCle[cle_ville]
  if not port or not port.chantier then
    return "Ce port n'a pas de chantier naval."
  end
  if not Chantier.autorise(port.niveau_chantier, cle_type) then
    return string.format("Le chantier de %s (niveau %d) est trop petit pour ce navire.",
      port.nom, port.niveau_chantier or 0)
  end
  return nil
end


-- ACHETER un navire tout fait : on paie son plein prix (`Value`) et il rejoint la
-- flotte tout de suite. Renvoie ok, message.
function Compagnie.acheter_navire(cle_ville, cle_type)
  local navire = Navires.get(cle_type)
  if not navire then return false, "Type de navire inconnu." end
  local err = verifier_chantier(cle_ville, cle_type)
  if err then return false, err end
  if Compagnie.nombre_navires() >= Chantier.LIMITE_NAVIRES then
    return false, string.format("Flotte pleine (%d navires).", Chantier.LIMITE_NAVIRES)
  end
  local prix = Chantier.prix_achat(cle_type)
  if prix > Compagnie.or_ then return false, "Or insuffisant." end
  Compagnie.or_ = Compagnie.or_ - prix
  Compagnie.flotte[#Compagnie.flotte + 1] =
    { cle = cle_type, nom = baptiser(navire), attache = cle_ville }
  return true, nil
end


-- CONSTRUIRE un navire neuf : moins d'or (`Construct`) mais il faut que la ville ait
-- les matières (bois, cordage, tissu, métal — puisées à son marché) et il faut
-- attendre le délai de construction. Renvoie ok, message.
function Compagnie.construire_navire(cle_ville, cle_type)
  local recette = Chantier.recette(cle_type)
  if not recette then return false, "Type de navire inconnu." end
  local err = verifier_chantier(cle_ville, cle_type)
  if err then return false, err end
  if Compagnie.nombre_navires() >= Chantier.LIMITE_NAVIRES then
    return false, string.format("Flotte pleine (%d navires).", Chantier.LIMITE_NAVIRES)
  end
  if recette.or_ > Compagnie.or_ then return false, "Or insuffisant." end

  -- Toutes les matières doivent être disponibles AVANT d'en consommer aucune :
  -- une construction ne doit jamais réussir à moitié.
  for _, mat in ipairs(recette.materiaux) do
    local l = Economie.ligne(cle_ville, mat.cle)
    if not l or l.stock < mat.quantite then
      local m = Marchandises.get(mat.cle)
      return false, string.format("Il manque du %s au chantier.",
        (m and m.nom:lower()) or mat.cle)
    end
  end

  for _, mat in ipairs(recette.materiaux) do
    Economie.acheter(cle_ville, mat.cle, mat.quantite)  -- vide le stock de la ville
  end
  Compagnie.or_ = Compagnie.or_ - recette.or_
  local navire = Navires.get(cle_type)
  Compagnie.file_chantier[#Compagnie.file_chantier + 1] =
    { cle = cle_type, nom = baptiser(navire), ville = cle_ville, jours = recette.jours }
  return true, nil
end


-- Fait avancer les constructions en cours ; celles arrivées à terme rejoignent la
-- flotte. Appelé par le pont, avec le temps.
function Compagnie.avancer_chantier(jours)
  if not jours or jours <= 0 then return end
  local reste = {}
  for _, b in ipairs(Compagnie.file_chantier) do
    b.jours = b.jours - jours
    if b.jours <= 0 then
      Compagnie.flotte[#Compagnie.flotte + 1] = { cle = b.cle, nom = b.nom, attache = b.ville }
    else
      reste[#reste + 1] = b
    end
  end
  Compagnie.file_chantier = reste
end


-- Arme un convoi en y AFFECTANT des navires de la flotte (leurs indices), sur un
-- circuit, avec une stratégie et un capital prélevé sur la caisse. Les navires
-- quittent la flotte pour le convoi. Renvoie le convoi, ou un message d'échec.
function Compagnie.armer_route(indices_flotte, circuit, strategie, capital)
  if not circuit or #circuit < 1 then return nil, "Circuit vide." end
  if #Compagnie.convois >= Chantier.LIMITE_CONVOIS then
    return nil, "Trop de convois." end

  -- On trie les indices en ordre décroissant pour retirer de la flotte sans décaler.
  local choisis = {}
  for _, i in ipairs(indices_flotte or {}) do
    if Compagnie.flotte[i] then choisis[#choisis + 1] = i end
  end
  if #choisis == 0 then return nil, "Aucun navire choisi." end
  if #choisis > Chantier.LIMITE_MEMBRES then
    return nil, string.format("Un convoi ne peut porter plus de %d navires.", Chantier.LIMITE_MEMBRES)
  end
  table.sort(choisis, function(a, b) return a > b end)

  capital = math.max(0, capital or 0)
  if capital > Compagnie.or_ then return nil, "Or insuffisant pour le capital." end

  local possedes, types = {}, {}
  for _, i in ipairs(choisis) do
    local s = Compagnie.flotte[i]
    possedes[#possedes + 1] = s
    types[#types + 1] = Navires.get(s.cle)
  end

  local m = Marchands.armer_joueur(circuit[1], types, circuit, strategie, capital)
  if not m then return nil, "Port d'attache inconnu." end
  m.navires_joueur = possedes  -- pour rendre les mêmes navires en dissolvant

  for _, i in ipairs(choisis) do table.remove(Compagnie.flotte, i) end
  Compagnie.or_ = Compagnie.or_ - capital
  Compagnie.convois[#Compagnie.convois + 1] = m
  return m, nil
end


-- VENDRE un navire de la flotte au chantier : il quitte la flotte, la caisse
-- encaisse son prix de revente. Renvoie ok, message, somme.
function Compagnie.vendre_navire(indice_flotte)
  local s = Compagnie.flotte[indice_flotte]
  if not s then return false, "Navire inconnu.", 0 end
  local somme = Chantier.prix_revente(s.cle)
  Compagnie.or_ = Compagnie.or_ + somme
  table.remove(Compagnie.flotte, indice_flotte)
  return true, nil, somme
end


-- Fabrique un NOUVEAU convoi MANUEL depuis des navires de la flotte (indices), à
-- quai dans `cle_port`. Il ne part pas tout seul : le joueur le commande
-- (`ordonner_convoi`) ou lui donne plus tard une route. Renvoie le convoi ou un
-- message d'échec.
function Compagnie.creer_convoi(indices_flotte, cle_port)
  if #Compagnie.convois >= Chantier.LIMITE_CONVOIS then
    return nil, "Trop de convois." end
  local choisis = {}
  for _, i in ipairs(indices_flotte or {}) do
    if Compagnie.flotte[i] then choisis[#choisis + 1] = i end
  end
  if #choisis == 0 then return nil, "Aucun navire choisi." end
  if #choisis > Chantier.LIMITE_MEMBRES then
    return nil, string.format("Un convoi ne peut porter plus de %d navires.", Chantier.LIMITE_MEMBRES)
  end
  table.sort(choisis, function(a, b) return a > b end)
  local possedes, types = {}, {}
  for _, i in ipairs(choisis) do
    local s = Compagnie.flotte[i]
    possedes[#possedes + 1] = s
    types[#types + 1] = Navires.get(s.cle)
  end
  local m = Marchands.armer_joueur_manuel(cle_port, types)
  if not m then return nil, "Port d'attache inconnu." end
  m.navires_joueur = possedes
  for _, i in ipairs(choisis) do table.remove(Compagnie.flotte, i) end
  Compagnie.convois[#Compagnie.convois + 1] = m
  return m, nil
end


-- Envoie un convoi MANUEL à un port : il appareille et navigue tout seul jusque
-- là, puis attend. Renvoie ok, message.
function Compagnie.ordonner_convoi(indice, cle_port_dest)
  local m = Compagnie.convois[indice]
  if not m then return false, "Convoi inconnu." end
  if m.mode ~= "manuel" then return false, "Ce convoi suit une route ; dissous-la d'abord." end
  if not Archipel.portsParCle[cle_port_dest] then return false, "Port inconnu." end
  Marchands.ordonner(m, cle_port_dest)
  return true, nil
end


-- MET un convoi EN ROUTE DE COMMERCE : on lui donne un circuit et une stratégie,
-- et un capital de travail prélevé sur la caisse. Il commerce alors seul. Un convoi
-- n'est donc pas « manuel OU route » de naissance : il naît manuel, on lui applique
-- une route quand on veut (et on la lui retire avec `retirer_route`). Renvoie ok, msg.
function Compagnie.mettre_en_route(indice, circuit, strategie, capital)
  local m = Compagnie.convois[indice]
  if not m then return false, "Convoi inconnu." end
  if not circuit or #circuit < 2 then return false, "Une route demande au moins deux escales." end
  capital = math.max(0, capital or 0)
  if capital > Compagnie.or_ then return false, "Or insuffisant pour le capital." end

  m.mode = "route"
  m.circuit = {}
  for _, c in ipairs(circuit) do m.circuit[#m.circuit + 1] = c end
  m.attache = circuit[1]
  m.strategie = strategie or "profit"
  m.etape = 1
  m.destination = nil
  m.route = {}
  Compagnie.or_ = Compagnie.or_ - capital
  m.or_ = (m.or_ or 0) + capital
  return true, nil
end


-- RETIRE la route d'un convoi : il redevient manuel (le joueur le commande), et son
-- or de travail rentre dans la caisse. Le convoi et ses navires restent. Renvoie ok, msg.
function Compagnie.retirer_route(indice)
  local m = Compagnie.convois[indice]
  if not m then return false, "Convoi inconnu." end
  if m.mode ~= "route" then return false, "Ce convoi n'est pas en route." end
  Compagnie.or_ = Compagnie.or_ + math.floor(math.max(0, m.or_) + 0.5)
  m.or_ = 0
  m.mode = "manuel"
  m.strategie = nil
  m.circuit = { m.ville or m.attache }
  return true, nil
end


-- Envoie un convoi MANUEL vers un point de mer quelconque (clic droit en pleine
-- mer). Renvoie ok, message.
function Compagnie.ordonner_convoi_position(indice, x, z)
  local m = Compagnie.convois[indice]
  if not m then return false, "Convoi inconnu." end
  if m.mode ~= "manuel" then return false, "Ce convoi suit une route ; dissous-la d'abord." end
  if not Marchands.ordonner_position(m, x, z) then
    return false, "Aucune route maritime jusque-là."
  end
  return true, nil
end


-- Dissout un convoi du joueur : rend ses navires à la flotte, rapatrie son or dans
-- la caisse (sa cargaison est perdue, ou à vendre avant). Rend l'or récupéré.
function Compagnie.dissoudre_route(indice)
  local m = Compagnie.convois[indice]
  if not m then return 0 end
  for _, s in ipairs(m.navires_joueur or {}) do
    s.attache = m.ville or m.attache   -- les navires rentrent au port où l'on dissout
    Compagnie.flotte[#Compagnie.flotte + 1] = s
  end
  local recup = math.floor(math.max(0, m.or_) + 0.5)
  Compagnie.or_ = Compagnie.or_ + recup
  table.remove(Compagnie.convois, indice)
  return recup
end


-- Recompose les champs dérivés d'un convoi après un ajout ou un retrait de navire :
-- la liste des types, la capacité, la vitesse, l'entretien, le nom. La cargaison
-- (`m.cale`) est un pot commun, jamais attachée à un navire précis : retirer un
-- navire réduit la capacité sans rien perdre, le commerce écoule le trop-plein.
local function recomposer_convoi(m)
  local types = {}
  for _, s in ipairs(m.navires_joueur) do types[#types + 1] = Navires.get(s.cle) end
  m.navires = types
  m.capacite = Navires.cale(types)
  m.vitesse = Navires.vitesse_jour(types)
  m.entretien = Navires.entretien(types)
  local port = Archipel.portsParCle[m.attache]
  local lieu = port and port.nom or m.attache
  if #types == 1 then
    m.nom = string.format("%s de %s", types[1].nom, lieu)
  else
    m.nom = string.format("Convoi de %s (%d navires)", lieu, #types)
  end
end


-- Ajoute des navires de la flotte (leurs indices) à un convoi EXISTANT. Ils
-- quittent la flotte. Renvoie ok, message.
function Compagnie.ajouter_navire_convoi(indice_convoi, indices_flotte)
  local m = Compagnie.convois[indice_convoi]
  if not m then return false, "Convoi inconnu." end
  local choisis = {}
  for _, i in ipairs(indices_flotte or {}) do
    if Compagnie.flotte[i] then choisis[#choisis + 1] = i end
  end
  if #choisis == 0 then return false, "Aucun navire choisi." end
  if #m.navires_joueur + #choisis > Chantier.LIMITE_MEMBRES then
    return false, string.format("Un convoi ne peut porter plus de %d navires.", Chantier.LIMITE_MEMBRES)
  end
  table.sort(choisis, function(a, b) return a > b end)  -- retirer sans décaler
  for _, i in ipairs(choisis) do
    m.navires_joueur[#m.navires_joueur + 1] = Compagnie.flotte[i]
  end
  for _, i in ipairs(choisis) do table.remove(Compagnie.flotte, i) end
  recomposer_convoi(m)
  return true, nil
end


-- Retire un navire (par sa place dans le convoi) et le rend à la flotte. S'il ne
-- reste plus de navire, le convoi se dissout et son or rentre en caisse. Renvoie
-- ok, message.
function Compagnie.retirer_navire_convoi(indice_convoi, indice_navire)
  local m = Compagnie.convois[indice_convoi]
  if not m then return false, "Convoi inconnu." end
  local s = m.navires_joueur[indice_navire]
  if not s then return false, "Navire inconnu." end
  table.remove(m.navires_joueur, indice_navire)
  s.attache = m.ville or m.attache   -- il rejoint la flotte là où on le débarque
  Compagnie.flotte[#Compagnie.flotte + 1] = s
  if #m.navires_joueur == 0 then
    local recup = math.floor(math.max(0, m.or_) + 0.5)
    Compagnie.or_ = Compagnie.or_ + recup
    table.remove(Compagnie.convois, indice_convoi)
    return true, "Dernier navire retiré : convoi dissous."
  end
  recomposer_convoi(m)
  return true, nil
end


-- Fait avancer les convois automatiques du joueur d'un pas de `jours`. Appelé par
-- le pont, en même temps que les convois de l'IA.
function Compagnie.avancer_convois(jours)
  for _, m in ipairs(Compagnie.convois) do
    Marchands.piloter(m, jours)
  end
end


-- Le joueur a-t-il un convoi à quai dans cette ville ? Le radial n'ouvre le dock
-- et le chantier que si oui — comme PR3, on n'entre au port qu'avec un navire.
function Compagnie.convoi_au_port(cle_ville)
  for _, m in ipairs(Compagnie.convois) do
    if m.ville == cle_ville then return true end
  end
  return false
end


-- La richesse totale du joueur : caisse + or des convois automatiques.
function Compagnie.richesse()
  local total = Compagnie.or_
  for _, m in ipairs(Compagnie.convois) do total = total + math.max(0, m.or_) end
  return total
end


function Compagnie.reinitialiser()
  local sloop = Navires.get("sloop")
  Compagnie.or_ = 20000
  Compagnie.flotte = {}
  Compagnie.file_chantier = {}
  Compagnie.compteur_navires = 0
  Compagnie.convois = {}
  Compagnie.reputation = {}
  for _, port in ipairs(Archipel.ports or {}) do
    Compagnie.reputation[port.cle] = Compagnie.REP_DEPART
  end
  -- Le joueur DÉMARRE avec un convoi : l'Aurore, un sloop, à quai à son port
  -- d'attache, en mode manuel. Plus de « navire unique » : tout est convoi, comme
  -- dans PR3. C'est le convoi sélectionné par défaut.
  local depart = (Archipel.portsParCle and Archipel.portsParCle["port_royale"] and "port_royale")
    or (Archipel.ports and Archipel.ports[1] and Archipel.ports[1].cle) or nil
  Compagnie.selection = 1
  if depart then
    local m = Marchands.armer_joueur_manuel(depart, { sloop })
    if m then
      m.nom = "Aurore"
      m.navires_joueur = { { cle = sloop.cle, nom = "Aurore", attache = depart } }
      Compagnie.convois[1] = m
    end
  end
end


-- Tonnage embarqué DANS LE CONVOI ACTIF.
function Compagnie.charge()
  local m = Compagnie.convoi_actif()
  if not m then return 0 end
  local t = 0
  for _, q in pairs(m.cale) do t = t + q end
  return t
end


function Compagnie.place_libre()
  local m = Compagnie.convoi_actif()
  if not m then return 0 end
  return m.capacite - Compagnie.charge()
end


function Compagnie.quantite(cle_m)
  local m = Compagnie.convoi_actif()
  return (m and m.cale[cle_m]) or 0
end


-- Combien le joueur PEUT acheter : le minimum de ce que la ville peut céder,
-- de ce que la caisse permet et de ce que la cale peut porter. C'est ce chiffre
-- que l'interface propose comme maximum, pour qu'un bouton « tout acheter » ne
-- puisse jamais échouer.
function Compagnie.achat_maximum(cle_ville, cle_m)
  if not Marchandises.get(cle_m) then return 0 end

  local place = math.floor(Compagnie.place_libre())
  if place <= 0 then return 0 end

  local prix = Economie.cotation(cle_ville, cle_m, 1, "achat") or 0
  if prix <= 0 then return 0 end

  local abordable = math.floor(Compagnie.or_ / prix)
  local cedable = math.floor(Compagnie.disponible(cle_ville, cle_m))
  return math.max(0, math.min(place, abordable, cedable))
end


-- Ce que la ville accepte de céder, avant toute contrainte du joueur : tout son
-- stock. Comme dans PR3, c'est le prix qui retient le joueur de la vider, pas un
-- plancher.
function Compagnie.disponible(cle_ville, cle_m)
  local l = Economie.ligne(cle_ville, cle_m)
  if not l then return 0 end
  return math.max(0, l.stock)
end


-- L'entretien, prélevé à chaque journée. PR3 fait payer à chaque navire ses
-- `DailyCosts` (110 pièces/jour pour un sloop) : un convoi qui attend coûte. Les
-- convois MANUELS sont payés sur la caisse (le joueur les finance directement) ;
-- les convois sur ROUTE paient sur leur propre or, dans `piloter_convoi`. La caisse
-- peut passer sous zéro ; c'est au joueur de la renflouer.
function Compagnie.payer_entretien(jours)
  if not jours or jours <= 0 then return 0 end
  local du = 0
  for _, m in ipairs(Compagnie.convois) do
    if m.mode == "manuel" then du = du + (m.entretien or 0) * jours end
  end
  Compagnie.or_ = Compagnie.or_ - du
  return du
end


-- Achète pour le CONVOI ACTIF. Renvoie quantite, cout, message.
function Compagnie.acheter(cle_ville, cle_m, quantite)
  local convoi = Compagnie.convoi_actif()
  if not convoi then return 0, 0, "Aucun convoi sélectionné." end
  quantite = math.floor(quantite or 0)
  if quantite <= 0 then return 0, 0, "Quantité nulle." end
  if quantite > Compagnie.place_libre() then
    quantite = math.floor(Compagnie.place_libre())
  end
  if quantite <= 0 then return 0, 0, "Cale pleine." end

  local prix = Economie.cotation(cle_ville, cle_m, quantite, "achat") or 0
  if prix * quantite > Compagnie.or_ then
    quantite = math.floor(Compagnie.or_ / math.max(prix, 0.01))
  end
  if quantite <= 0 then return 0, 0, "Or insuffisant." end

  -- On prend le coût que l'économie RENVOIE, sans jamais le recalculer.
  -- Le recalculer après coup interrogeait un entrepôt déjà vidé de la
  -- cargaison qu'on venait d'en sortir : le cours y était au plafond, la
  -- facture triplait, et la caisse passait en négatif sur un achat que la
  -- vérification d'avant l'échange avait pourtant jugé abordable.
  local ligne_avant = Economie.ligne(cle_ville, cle_m)
  local servi, cout = Economie.acheter(cle_ville, cle_m, quantite)
  servi = math.floor(servi)
  if servi <= 0 then return 0, 0, "La ville n'a plus rien à céder." end

  if ligne_avant then
    ajuster_reputation(cle_ville, cle_m, ligne_avant.stock, "achat", servi)
  end
  Compagnie.or_ = Compagnie.or_ - cout
  local cale = convoi.cale
  cale[cle_m] = (cale[cle_m] or 0) + servi
  return servi, cout, nil
end


-- Vend depuis le CONVOI ACTIF. Renvoie quantite, recette, message.
function Compagnie.vendre(cle_ville, cle_m, quantite)
  local convoi = Compagnie.convoi_actif()
  if not convoi then return 0, 0, "Aucun convoi sélectionné." end
  quantite = math.floor(quantite or 0)
  local en_cale = Compagnie.quantite(cle_m)
  if quantite > en_cale then quantite = math.floor(en_cale) end
  if quantite <= 0 then return 0, 0, "Rien de tel en cale." end

  local ligne_avant = Economie.ligne(cle_ville, cle_m)
  local servi, recette = Economie.vendre(cle_ville, cle_m, quantite)
  if ligne_avant then
    ajuster_reputation(cle_ville, cle_m, ligne_avant.stock, "vente", servi)
  end
  Compagnie.or_ = Compagnie.or_ + recette
  local cale = convoi.cale
  cale[cle_m] = en_cale - servi
  if cale[cle_m] <= 0.0001 then cale[cle_m] = nil end
  return servi, recette, nil
end


Compagnie.reinitialiser()

return Compagnie
