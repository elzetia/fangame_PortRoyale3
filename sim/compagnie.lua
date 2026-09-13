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

-- Les convois AUTOMATIQUES du joueur : des flottes lancées sur un circuit avec une
-- stratégie (voir `sim/strategies.lua`), qui commercent seules — le cœur de Port
-- Royale. Ils réutilisent la machinerie des convois de l'IA (`sim/marchands.lua`),
-- mais gardent leur or, alimenté par le joueur. La richesse totale du joueur, c'est
-- sa caisse plus l'or embarqué sur ses convois.
Compagnie.convois = {}

-- Arme un convoi du joueur : une liste de clés de navires (types de `sim/navires`),
-- un circuit de villes, une stratégie, et un capital prélevé sur la caisse. Renvoie
-- le convoi, ou un message d'échec.
function Compagnie.armer_route(cles_navires, circuit, strategie, capital)
  local navires = {}
  for _, cle in ipairs(cles_navires or {}) do
    local n = Navires.get(cle)
    if n then navires[#navires + 1] = n end
  end
  if #navires == 0 then return nil, "Aucun navire." end
  if not circuit or #circuit < 1 then return nil, "Circuit vide." end
  capital = math.max(0, capital or 0)
  if capital > Compagnie.or_ then return nil, "Or insuffisant pour le capital." end

  local m = Marchands.armer_joueur(circuit[1], navires, circuit, strategie, capital)
  if not m then return nil, "Port d'attache inconnu." end
  Compagnie.or_ = Compagnie.or_ - capital
  Compagnie.convois[#Compagnie.convois + 1] = m
  return m, nil
end


-- Dissout un convoi du joueur : rapatrie son or dans la caisse, sa cargaison est
-- perdue (ou à vendre avant). Rend l'or récupéré.
function Compagnie.dissoudre_route(indice)
  local m = Compagnie.convois[indice]
  if not m then return 0 end
  local recup = math.floor(math.max(0, m.or_) + 0.5)
  Compagnie.or_ = Compagnie.or_ + recup
  table.remove(Compagnie.convois, indice)
  return recup
end


-- Fait avancer les convois automatiques du joueur d'un pas de `jours`. Appelé par
-- le pont, en même temps que les convois de l'IA.
function Compagnie.avancer_convois(jours)
  for _, m in ipairs(Compagnie.convois) do
    Marchands.piloter(m, jours)
  end
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
  Compagnie.convois = {}
  Compagnie.reputation = {}
  for _, port in ipairs(Archipel.ports or {}) do
    Compagnie.reputation[port.cle] = Compagnie.REP_DEPART
  end
  Compagnie.navire = {
    nom = "Aurore",
    classe = sloop.nom,
    type = sloop.cle,
    modele = sloop.modele,
    entretien = sloop.entretien,  -- or par jour (`DailyCosts` de PR3)
    capacite = sloop.cale,  -- tonneaux
    cale = {},              -- cle -> tonnes
  }
end


-- Tonnage embarqué.
function Compagnie.charge()
  local t = 0
  for _, q in pairs(Compagnie.navire.cale) do t = t + q end
  return t
end


function Compagnie.place_libre()
  return Compagnie.navire.capacite - Compagnie.charge()
end


function Compagnie.quantite(cle_m)
  return Compagnie.navire.cale[cle_m] or 0
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


-- L'entretien du navire, prélevé à chaque journée qui passe. PR3 fait payer à
-- chaque navire ses `DailyCosts` — 110 pièces par jour pour un sloop — et c'est
-- ce qui rend un navire à quai coûteux : un marchand qui attend perd de l'argent.
-- La caisse peut passer sous zéro ; c'est au joueur de la renflouer.
function Compagnie.payer_entretien(jours)
  if not jours or jours <= 0 then return 0 end
  local du = (Compagnie.navire.entretien or 0) * jours
  Compagnie.or_ = Compagnie.or_ - du
  return du
end


-- Achète. Renvoie quantite, cout, message.
function Compagnie.acheter(cle_ville, cle_m, quantite)
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
  local cale = Compagnie.navire.cale
  cale[cle_m] = (cale[cle_m] or 0) + servi
  return servi, cout, nil
end


-- Vend. Renvoie quantite, recette, message.
function Compagnie.vendre(cle_ville, cle_m, quantite)
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
  local cale = Compagnie.navire.cale
  cale[cle_m] = en_cale - servi
  if cale[cle_m] <= 0.0001 then cale[cle_m] = nil end
  return servi, recette, nil
end


Compagnie.reinitialiser()

return Compagnie
