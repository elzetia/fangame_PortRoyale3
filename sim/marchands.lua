-- Les convois : un navire par ville, qui suit une ROUTE DE COMMERCE.
--
-- Une route est un circuit de quelques ports, dont son port d'attache. Le
-- convoi la parcourt sans fin : à chaque escale il décharge ce dont la ville
-- manque, puis recharge ce qu'elle a en trop et qui manquera plus loin sur son
-- circuit. C'est le mécanisme de Port Royale 3, et c'est ce qui distingue un
-- marchand d'un coursier.
--
-- Ce fichier a connu deux versions abandonnées, et les deux échecs valent d'être
-- gardés :
--
--   1. DES ARBITRAGISTES LIBRES, qui couraient la meilleure marge de la carte.
--      Ils nivelaient bien les cours et ne servaient personne : une ville
--      manquait de blé pendant qu'un convoi passait devant son port avec du
--      tabac, parce que la marge y était meilleure.
--   2. UN ALLER-RETOUR, d'un port d'attache vers un unique fournisseur. Servait
--      bien sa ville, mais une cale sur deux revenait vide, et la denrée
--      rapportée était la seule qui bougeait — les dix-neuf autres lignes du
--      comptoir ne voyaient jamais un navire.
--
-- Le circuit tient les deux bouts : le port d'attache est une escale comme les
-- autres, donc sa ville est servie à chaque tour, et le navire commerce tout du
-- long au lieu de caboter à vide.
--
-- Le circuit reste LOCAL, une poignée de ports voisins. Un bourg de Floride qui
-- irait chercher son blé à Trinidad mettrait trois semaines de mer pour une
-- cale : il serait plus souvent en route qu'à servir sa ville. Le commerce de
-- proximité est le sien ; la longue distance est le métier du joueur, et c'est
-- là que sa marge doit être.
--
-- Ces navires passent par les MÊMES portes que le joueur — `Economie.acheter`
-- et `Economie.vendre` — donc leurs achats déplacent réellement les cours. Un
-- joueur qui arrive après le convoi espagnol trouve le marché qu'il a laissé.
--
-- Lua pur : ce fichier ne connaît pas Godot.

local Archipel     = require("sim.archipel")
local Navigation   = require("sim.navigation")
local Economie     = require("sim.economie")
local Marchandises = require("sim.marchandises")

local Marchands = {}

local CAPACITE  = 45        -- tonneaux
local OR_DEPART = 15000
local VITESSE   = 700       -- unités de monde par jour
local ESCALE    = 1.0       -- jours passés à quai

-- En dessous de ce nombre de barres, la ville est considérée en manque. Quatre
-- barres = entrepôt plein, zéro = pénurie ; c'est le barème de Port Royale 3.
local SEUIL_MANQUE = 3

-- Nombre d'escales du circuit, port d'attache compris. Court exprès : à cinq
-- escales et quelques jours de mer entre chacune, une ville revoit son convoi
-- toutes les deux ou trois semaines, ce qui est le rythme d'un ravitaillement.
local ESCALES = 5

-- Parmi combien de voisins on taille ce circuit.
local VOISINAGE = 12

Marchands.liste = {}
Marchands.voisins = {}


local function distance(x1, z1, x2, z2)
  local dx, dz = x2 - x1, z2 - z1
  return math.sqrt(dx * dx + dz * dz)
end


local function rade(cle)
  local p = Archipel.portsParCle[cle]
  if not p then return 0, 0 end
  local _, _, rx, rz = Archipel.positionPort(p)
  return rx, rz
end


-- Les plus proches voisins de chaque port, une fois pour toutes : la carte ne
-- bouge pas, et refaire ce classement à chaque appareillage serait absurde.
local function construire_voisinage()
  local pos = {}
  for _, p in ipairs(Archipel.ports) do
    local rx, rz = rade(p.cle)
    pos[p.cle] = { rx, rz }
  end
  Marchands.voisins = {}
  for _, p in ipairs(Archipel.ports) do
    local classement = {}
    for _, q in ipairs(Archipel.ports) do
      if q.cle ~= p.cle then
        classement[#classement + 1] = {
          cle = q.cle,
          d = distance(pos[p.cle][1], pos[p.cle][2], pos[q.cle][1], pos[q.cle][2]),
        }
      end
    end
    table.sort(classement, function(u, v) return u.d < v.d end)
    local proches = {}
    for i = 1, math.min(VOISINAGE, #classement) do proches[i] = classement[i].cle end
    Marchands.voisins[p.cle] = proches
  end
end


-- Le circuit d'un port : lui, puis de proche en proche parmi ses voisins.
--
-- C'est la tournée du plus proche voisin, la plus simple des heuristiques de
-- voyageur de commerce. Elle ne donne pas le tour optimal, et ce n'est pas le
-- but : on veut un anneau qui ne revienne pas sur ses pas, pour que la boucle
-- se lise sur la carte. Le terme en `0.5` pénalise l'éloignement du port
-- d'attache — sans lui le circuit part en ligne droite et ne rentre jamais.
local function tracer_circuit(cle_attache)
  local circuit = { cle_attache }
  local pris = { [cle_attache] = true }
  local courant = cle_attache
  local ax, az = rade(cle_attache)
  while #circuit < ESCALES do
    local cx, cz = rade(courant)
    local suivant, meilleure = nil, math.huge
    for _, cle in ipairs(Marchands.voisins[cle_attache] or {}) do
      if not pris[cle] then
        local qx, qz = rade(cle)
        local d = distance(cx, cz, qx, qz) + distance(ax, az, qx, qz) * 0.5
        if d < meilleure then suivant, meilleure = cle, d end
      end
    end
    if not suivant then break end
    circuit[#circuit + 1] = suivant
    pris[suivant] = true
    courant = suivant
  end
  return circuit
end


function Marchands.reinitialiser()
  construire_voisinage()
  Marchands.liste = {}
  for _, port in ipairs(Archipel.ports) do
    local nation = Archipel.nations[port.nation]
    local rx, rz = rade(port.cle)
    Marchands.liste[#Marchands.liste + 1] = {
      cle = "convoi_" .. port.cle,
      -- Un navire PAR VILLE, pas par couronne : à soixante ports, un convoi
      -- par nation ne servirait qu'une ville sur quinze. Le pavillon reste
      -- celui de sa couronne, mais c'est sa ville qu'il sert.
      nom = "Convoi de " .. port.nom,
      nation = nation.cle,
      attache = port.cle,
      capacite = CAPACITE,
      or_ = OR_DEPART,
      cale = {},
      achats = {},               -- ce que chaque lot a coûté, par tonne
      circuit = tracer_circuit(port.cle),
      etape = 1,
      ville = port.cle,          -- port où il est à quai, nil s'il est en mer
      destination = nil,
      quete = "",
      x = rx, z = rz,
      cap = 0,
      route = {},
      escale = ESCALE,
    }
  end
end


local function charge(m)
  local t = 0
  for _, q in pairs(m.cale) do t = t + q end
  return t
end


-- Les escales qui RESTENT avant de revenir ici : c'est pour elles qu'on achète.
local function escales_suivantes(m)
  local suite = {}
  local n = #m.circuit
  for k = 1, n - 1 do
    suite[k] = m.circuit[(m.etape - 1 + k) % n + 1]
  end
  return suite
end


-- 1. DÉCHARGER. On vend ici ce dont cette ville manque, et seulement si l'on y
--    gagne — un convoi n'est pas une œuvre de charité, et vendre à perte
--    viderait sa caisse en quelques tours.
--
--    Son propre port fait exception : ce qu'on a chargé pour lui, il le reçoit,
--    même si le cours a bougé entre-temps. C'est la raison d'être du convoi.
local function decharger(m)
  local chez_soi = (m.ville == m.attache)
  for cle, q in pairs(m.cale) do
    if q > 0.5 then
      local l = Economie.ligne(m.ville, cle)
      local prix = Economie.cotation(m.ville, cle, q, "vente") or 0
      local paye = m.achats[cle] or 0
      if l and (l.barres < SEUIL_MANQUE or chez_soi) and (prix > paye or chez_soi) then
        local _, somme = Economie.vendre(m.ville, cle, q)
        m.or_ = m.or_ + somme
        m.cale[cle] = nil
        m.achats[cle] = nil
      end
    end
  end
end


-- 2. CHARGER. On achète ici ce que la ville a en trop et qui manquera plus loin
--    sur le circuit, du plus rentable au moins rentable, jusqu'à remplir la
--    cale.
--
--    Le gain se mesure sur le LOT ENTIER, pas à la tonne. C'est l'erreur qui
--    m'avait coûté deux tours de réglage : une route annoncée à +230 la tonne
--    perdait de l'argent, parce que le cours monte à l'achat et descend à la
--    vente au fur et à mesure qu'on remplit la cale.
local function charger(m)
  local suite = escales_suivantes(m)
  if #suite == 0 then return end

  for _ = 1, 3 do                      -- au plus trois marchandises par escale
    local place = m.capacite - charge(m)
    if place < 5 then return end

    local meilleur = nil
    for _, marchandise in ipairs(Marchandises.liste) do
      local cle = marchandise.cle
      local l = Economie.ligne(m.ville, cle)
      if l and l.barres >= SEUIL_MANQUE + 1 and not m.cale[cle] then
        local lot = math.min(place, math.floor(l.stock - l.reference * 0.9))
        if lot >= 5 then
          local achat = Economie.cotation(m.ville, cle, lot, "achat") or 0
          if achat > 0 and achat * lot <= m.or_ then
            -- Où l'écouler ? La meilleure escale à venir. On privilégie son
            -- propre port — le servir vaut quelques pièces — et on décote les
            -- escales lointaines, qui immobilisent la cale plus longtemps.
            for rang, dest in ipairs(suite) do
              local ld = Economie.ligne(dest, cle)
              if ld and ld.barres < SEUIL_MANQUE then
                local vente = Economie.cotation(dest, cle, lot, "vente") or 0
                local gain = (vente - achat) * lot
                if dest == m.attache then gain = gain * 1.35 end
                gain = gain / (1 + 0.12 * (rang - 1))
                if gain > 0 and (not meilleur or gain > meilleur.gain) then
                  meilleur = { cle = cle, lot = lot, achat = achat, gain = gain }
                end
              end
            end
          end
        end
      end
    end

    if not meilleur then return end
    local servi, cout = Economie.acheter(m.ville, meilleur.cle, meilleur.lot)
    if servi <= 0 then return end
    m.or_ = m.or_ - cout
    m.cale[meilleur.cle] = (m.cale[meilleur.cle] or 0) + servi
    m.achats[meilleur.cle] = cout / servi
  end
end


local function tracer_route(m, cle_ville)
  local rx, rz = rade(cle_ville)
  m.route = Navigation.route(m.x, m.z, rx, rz) or { { rx, rz } }
  m.destination = cle_ville
  m.ville = nil
end


-- 3. APPAREILLER vers l'escale suivante du circuit.
local function appareiller(m)
  decharger(m)
  charger(m)
  m.etape = m.etape % #m.circuit + 1
  m.quete = ""
  for cle in pairs(m.cale) do m.quete = cle break end
  tracer_route(m, m.circuit[m.etape])
end


local function accoster(m)
  m.ville = m.destination
  m.destination = nil
  m.route = {}
  m.escale = ESCALE
end


-- Avance les convois de `jours` jours de jeu (fraction acceptée).
function Marchands.avancer(jours)
  if #Marchands.liste == 0 then Marchands.reinitialiser() end
  if not jours or jours <= 0 then return end

  for _, m in ipairs(Marchands.liste) do
    if m.ville then
      m.escale = m.escale - jours
      if m.escale <= 0 then
        m.escale = ESCALE
        appareiller(m)
      end
    else
      local reste = VITESSE * jours
      while reste > 0 and #m.route > 0 do
        local cible = m.route[1]
        local d = distance(m.x, m.z, cible[1], cible[2])
        if d <= reste then
          m.x, m.z = cible[1], cible[2]
          table.remove(m.route, 1)
          reste = reste - d
        else
          m.cap = math.atan2 and math.atan2(cible[2] - m.z, cible[1] - m.x)
                  or math.atan(cible[2] - m.z, cible[1] - m.x)
          m.x = m.x + (cible[1] - m.x) / d * reste
          m.z = m.z + (cible[2] - m.z) / d * reste
          reste = 0
        end
      end
      if #m.route == 0 then accoster(m) end
    end
  end
end


-- De quoi la ville manque-t-elle le plus ? Pour le diagnostic, et pour dire au
-- joueur ce qu'il gagnerait à apporter ici.
--
-- On classe sur les barres d'abondance, les vivres d'abord : une ville sans
-- blé meurt, une ville sans tabac s'ennuie. À barres égales on départage sur le
-- solde quotidien, qui dit si le manque se creuse ou se comble.
function Marchands.besoin_prioritaire(cle_ville)
  local pire, score_pire = nil, math.huge
  for _, marchandise in ipairs(Marchandises.liste) do
    local l = Economie.ligne(cle_ville, marchandise.cle)
    if l and l.barres < SEUIL_MANQUE then
      local score = l.barres * 10
      if marchandise.vitale then score = score - 15 end
      if l.solde < 0 then score = score - 3 end
      if score < score_pire then pire, score_pire = l.cle, score end
    end
  end
  return pire
end


-- Ce que chaque ville réclame, et combien de convois la desservent.
function Marchands.diagnostic()
  local sortie = {}
  local dessert = {}
  for _, m in ipairs(Marchands.liste) do
    for _, cle in ipairs(m.circuit) do
      dessert[cle] = (dessert[cle] or 0) + 1
    end
  end
  for _, port in ipairs(Archipel.ports) do
    local besoin = Marchands.besoin_prioritaire(port.cle)
    sortie[#sortie + 1] = {
      ville = port.cle,
      trouve = besoin ~= nil,
      cle = besoin or "",
      vers = "",
      lot = dessert[port.cle] or 0, total = 0, par_tonne = 0,
    }
  end
  return sortie
end


-- Ce que le navire porte, en clair, pour l'infobulle.
function Marchands.cargaison(m)
  local morceaux = {}
  for cle, q in pairs(m.cale) do
    if q > 0.5 then
      local marchandise = Marchandises.get(cle)
      morceaux[#morceaux + 1] = string.format("%d t de %s",
        math.floor(q + 0.5), marchandise and marchandise.nom:lower() or cle)
    end
  end
  if #morceaux == 0 then return "sur lest" end
  return table.concat(morceaux, ", ")
end


Marchands.reinitialiser()

return Marchands
