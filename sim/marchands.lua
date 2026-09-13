-- Les convois marchands des villes, armés de navires de Port Royale 3.
--
-- CE QUE PR3 DIT DE SES CONVOIS, et ce qu'on en tire. Son outil de débogage
-- interne (`xsl/wac.xsl`, voir `outils/PR3_TECHNIQUE.md`) affiche par ville un
-- nombre de convois IA, et pour chaque convoi : ses navires, sa capacité, CINQ
-- taux de remplissage et une VILLE CIBLE. Son exécutable a un réglage
-- `KiUpdateConvoySize` : la taille des convois IA est recalculée en cours de
-- partie. Et ses textes posent la règle de vitesse — « un convoi ne va jamais
-- plus vite que son navire le plus lent ».
--
-- Ce qui n'est écrit nulle part de lisible, c'est COMBIEN de navires une ville
-- arme. On le proportionne donc à sa population, et le coefficient est mesuré :
-- `tools/equilibre.gd` fait tourner cinq ans d'économie, et c'est lui qui a
-- montré qu'avec des cales de quarante-cinq tonneaux la carte mourait de
-- logistique — outils à 2 % de leurs ateliers, café et rhum introuvables.
--
-- Deux métiers, comme les deux ordres marchands de PR3 :
--
--   1. LE CABOTEUR suit une ROUTE DE COMMERCE : un circuit de quelques ports
--      voisins, son port d'attache compris. À chaque escale il décharge ce dont
--      la ville manque, puis recharge ce qu'elle a en trop et qui manquera plus
--      loin sur son circuit. Toutes les villes en ont un.
--   2. LE LONG-COURRIER va vers une VILLE CIBLE, choisie à chaque départ sur
--      toute la carte : celle où ce qu'on a en trop chez soi se vendra le mieux,
--      retour compris. Seules les villes d'une certaine taille en arment un.
--
-- Le second est venu d'une mesure, pas d'une idée. Les caboteurs seuls ne
-- sortent jamais de leur voisinage : les outils fondus au sud-est n'arrivaient
-- pas aux plantations de café du golfe, et le café disparaissait de la carte
-- entière alors que chaque maillon de sa chaîne était produit quelque part.
--
-- Deux versions abandonnées précèdent ce fichier, et leurs échecs valent d'être
-- gardés :
--
--   · DES ARBITRAGISTES LIBRES, qui couraient la meilleure marge de la carte.
--     Ils nivelaient les cours et ne servaient personne : une ville manquait de
--     blé pendant qu'un convoi passait devant son port avec du tabac.
--   · UN ALLER-RETOUR vers un fournisseur unique. Une cale sur deux revenait
--     vide, et les dix-neuf autres lignes du comptoir ne voyaient jamais un
--     navire.
--
-- Le long-courrier n'est pas l'arbitragiste revenu : il part toujours de chez
-- lui, il y revient toujours, et il ne charge au loin que ce dont SA ville
-- manque.
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
local Navires      = require("sim.navires")

local Marchands = {}

-- Tonneaux de cale marchande armés par habitant de la ville. Voir l'en-tête :
-- c'est la sonde d'équilibre qui le fixe. Mesures sur cinq ans, à partir de
-- 82 500 habitants :
--
--   cales de 45 t par ville (avant PR3)   74 600 hab.   56 villes en disette   outils  2 %
--   0,30 par habitant                    103 300 hab.   20 villes              outils  8 %, café  0 %
--   0,45 par habitant                    113 300 hab.   17 villes              outils 16 %, café 23 %
--   0,55 par habitant                    118 600 hab.   15 villes              outils 48 %, café 35 %
--
-- Au-delà, le gain s'essouffle : ce qui manque encore — le rhum, les vêtements —
-- tient à la distance entre les ateliers et leurs intrants, pas au tonnage.
Marchands.CALE_PAR_HABITANT = 0.55

-- Une ville arme un long-courrier à partir de cette classe de taille (1 bourg,
-- 2 ville, 3 grande ville), et lui donne cette part de sa cale.
--
-- La part est fixée et non ce qui « reste » après le caboteur : au premier
-- réglage le long-courrier ne recevait que le navire en trop, et une ville de
-- deux mille âmes, armée d'une seule flûte marchande, n'en avait jamais. Six
-- villes sur soixante allaient au loin, et le café restait introuvable.
Marchands.TAILLE_LONG_COURS = 2
Marchands.PART_LONG_COURS = 0.40

-- L'or de départ, par tonneau de cale : de quoi remplir la cale une fois et
-- demie de marchandise moyenne. En dessous, une flûte marchande appareille à
-- moitié vide faute de pouvoir payer.
local OR_PAR_TONNEAU = 80

local ESCALE = 1.0          -- jours passés à quai

-- En dessous de ce nombre de barres, la ville est considérée en manque. Quatre
-- barres = entrepôt plein, zéro = pénurie ; c'est le barème de Port Royale 3.
local SEUIL_MANQUE = 3

-- Nombre d'escales du circuit d'un caboteur, port d'attache compris. Court
-- exprès : à cinq escales et quelques jours de mer entre chacune, une ville
-- revoit son convoi toutes les deux ou trois semaines.
local ESCALES = 5

-- Parmi combien de voisins on taille ce circuit.
local VOISINAGE = 12

-- Combien de marchandises un convoi charge à une escale : les cinq taux de
-- remplissage que l'outil de débogage de PR3 affiche pour chaque convoi IA.
local LOTS_PAR_ESCALE = 5

-- Plus petit lot qui vaille une manoeuvre de chargement, en tonneaux.
local LOT_MINIMUM = 20

-- Une route de mer est plus longue que la ligne droite entre deux rades : il
-- faut contourner les îles. Pour choisir une cible on n'a pas le temps de
-- tracer soixante routes ; on majore la ligne droite.
local DETOUR = 1.3

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


-- Le circuit d'un caboteur : son port, puis de proche en proche parmi ses
-- voisins.
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


-- La flotte d'une ville : des navires marchands de PR3, du plus grand qui ait
-- du sens au plus petit, jusqu'à la cale visée. Un navire n'est pris que s'il
-- ne dépasse pas ce qui reste de plus d'un demi-sloop : une bourgade n'arme pas
-- une flûte marchande pour trois cents tonneaux de besoins.
local function composer_flotte(cale_visee)
  local flotte = {}
  local reste = cale_visee
  local plus_petit = Navires.marchands[#Navires.marchands]
  while reste > plus_petit.cale * 0.75 do
    local choisi = plus_petit
    for _, n in ipairs(Navires.marchands) do
      if n.cale <= reste + plus_petit.cale * 0.5 then choisi = n break end
    end
    flotte[#flotte + 1] = choisi
    reste = reste - choisi.cale
  end
  if #flotte == 0 then flotte[1] = plus_petit end
  return flotte
end


local function nom_flotte(navires, port)
  if #navires == 1 then
    return string.format("%s de %s", navires[1].nom, port.nom)
  end
  return string.format("Convoi de %s (%d navires)", port.nom, #navires)
end


local function armer(port, genre, navires, circuit)
  local nation = Archipel.nations[port.nation]
  local rx, rz = rade(port.cle)
  local capacite = Navires.cale(navires)
  return {
    cle = genre .. "_" .. port.cle,
    genre = genre,
    nom = nom_flotte(navires, port),
    nation = nation.cle,
    attache = port.cle,
    navires = navires,
    capacite = capacite,
    vitesse = Navires.vitesse_jour(navires),
    or_ = capacite * OR_PAR_TONNEAU,
    cale = {},
    achats = {},               -- ce que chaque lot a coûté, par tonne
    circuit = circuit,
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


function Marchands.reinitialiser()
  construire_voisinage()
  Marchands.liste = {}
  for _, port in ipairs(Archipel.ports) do
    local cale = port.habitants * Marchands.CALE_PAR_HABITANT
    -- Le cabotage garde toujours la plus grosse part : servir ses voisins passe
    -- avant le commerce lointain.
    local part_loin = 0
    if (port.taille or 1) >= Marchands.TAILLE_LONG_COURS then
      part_loin = Marchands.PART_LONG_COURS
    end
    Marchands.liste[#Marchands.liste + 1] = armer(port, "caboteur",
      composer_flotte(cale * (1 - part_loin)), tracer_circuit(port.cle))
    if part_loin > 0 then
      Marchands.liste[#Marchands.liste + 1] = armer(port, "long_cours",
        composer_flotte(cale * part_loin), { port.cle })
    end
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


-- La ville cible d'un long-courrier : où son chargement rapportera le plus PAR
-- JOUR DE MER, aller et retour compris.
--
-- Pour chaque port de la carte on additionne deux gains : ce qu'on a en trop
-- chez soi et qui manque là-bas, et — à moitié, puisqu'on n'est pas sûr de le
-- trouver en arrivant — ce qu'il a en trop et qui manque chez soi. On divise
-- par la durée du voyage : un bon marché à trois semaines vaut moins qu'un
-- marché moyen à quatre jours.
local function choisir_cible(m)
  local ax, az = rade(m.attache)
  local lot = m.capacite / LOTS_PAR_ESCALE
  local ici = {}
  for _, marchandise in ipairs(Marchandises.liste) do
    ici[marchandise.cle] = Economie.ligne(m.attache, marchandise.cle)
  end

  local cible, meilleur = nil, 0
  for _, port in ipairs(Archipel.ports) do
    if port.cle ~= m.attache then
      local gain = 0
      for _, marchandise in ipairs(Marchandises.liste) do
        local cle = marchandise.cle
        local l_ici = ici[cle]
        local surplus_ici = l_ici.barres >= SEUIL_MANQUE + 1
        local manque_ici = l_ici.barres < SEUIL_MANQUE
        if surplus_ici or manque_ici then
          local la = Economie.ligne(port.cle, cle)
          if surplus_ici and la.barres < SEUIL_MANQUE then
            local g = (Economie.cotation(port.cle, cle, lot, "vente")
                     - Economie.cotation(m.attache, cle, lot, "achat")) * lot
            if g > 0 then gain = gain + g end
          elseif manque_ici and la.barres >= SEUIL_MANQUE + 1 then
            local g = (Economie.cotation(m.attache, cle, lot, "vente")
                     - Economie.cotation(port.cle, cle, lot, "achat")) * lot
            if g > 0 then gain = gain + g * 0.5 end
          end
        end
      end
      if gain > 0 then
        local px, pz = rade(port.cle)
        local jours = 2 * distance(ax, az, px, pz) * DETOUR / m.vitesse + 2 * ESCALE
        local par_jour = gain / jours
        if par_jour > meilleur then cible, meilleur = port.cle, par_jour end
      end
    end
  end
  return cible
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

  for _ = 1, LOTS_PAR_ESCALE do
    local place = m.capacite - charge(m)
    if place < LOT_MINIMUM then return end

    local meilleur = nil
    for _, marchandise in ipairs(Marchandises.liste) do
      local cle = marchandise.cle
      local l = Economie.ligne(m.ville, cle)
      if l and l.barres >= SEUIL_MANQUE + 1 and not m.cale[cle] then
        local lot = math.min(place, math.floor(l.stock - l.reference * 0.9))
        if lot >= LOT_MINIMUM then
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


-- 3. APPAREILLER vers l'escale suivante.
--
--    Un long-courrier choisit sa cible AVANT de charger, depuis son port : c'est
--    pour elle qu'il achète. S'il n'en trouve aucune qui vaille le voyage, il
--    reste à quai et regardera de nouveau quelques jours plus tard.
local function appareiller(m)
  if m.genre == "long_cours" and m.ville == m.attache then
    decharger(m)
    local cible = choisir_cible(m)
    if not cible then
      m.escale = ESCALE * 4
      return
    end
    m.circuit = { m.attache, cible }
    m.etape = 1
  else
    decharger(m)
  end
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
      local reste = m.vitesse * jours
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
