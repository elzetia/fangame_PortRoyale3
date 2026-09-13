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
-- Le code du jeu dit COMBIEN et DE QUELLE TAILLE (`0x79DB00`, `0x79D6B0`) : chaque
-- ville arme `Konvois` convois — deux — et chacun vise une cale proportionnelle à
-- sa population. Ce qu'il ne montre pas lisiblement, c'est où ils vont : leurs
-- routes sont les nôtres, ci-dessous, et elles ont été mesurées avec
-- `tools/equilibre.gd`. Avec des cales de quarante-cinq tonneaux, la carte
-- mourait de logistique — outils à 2 % de leurs ateliers, café et rhum
-- introuvables.
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

-- LA FLOTTE DE PR3. Chaque marchand IA d'une ville reçoit `Konvois` convois, soit
-- deux, et chacun vise une cale de habitants × 420 ÷ 1 900 tonneaux. Le jeu la
-- remplit en tirant au hasard jusqu'à trois navires parmi les types marchands,
-- et s'arrête dès qu'il a atteint ce tonnage.
--
-- Il remplace le coefficient qu'on avait mesuré — 0,55 tonneau par habitant pour
-- une flotte unique, dont une part partait au long cours dans les seules grandes
-- villes. Deux convois à 0,22 arment une cale totale du même ordre, mais en deux
-- flottes qui ne vont pas au même endroit, et dans toutes les villes.
Marchands.KONVOIS = 2
Marchands.CALE_PAR_HABITANT = 420 / 1900
Marchands.NAVIRES_MAX = 3

-- L'or du marchand IA au départ : 120 000, 90 000 ou 76 000 selon un réglage de
-- partie. On prend le cran du milieu, partagé entre ses deux convois.
local OR_MARCHAND = 90000

-- Un convoi est un CAPITAL DE TRAVAIL, pas un trésor. Dans PR3 l'or d'un marchand
-- ressort aussitôt : il bâtit des ateliers et des maisons, arme d'autres navires,
-- paie ses équipages. On ne simule pas ces dépenses une à une, mais on en garde
-- l'effet : la caisse d'un convoi est plafonnée, et tout ce qui déborde alimente
-- le fonds de construction (voir `investir`). Sans ce plafond, les convois
-- amassaient des millions sans jamais rien en faire.
local OR_PLAFOND = OR_MARCHAND

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

-- Plus petit lot qui vaille une manoeuvre de chargement, en tonneaux. Petit : à
-- l'échelle de PR3, un bourg consomme moins de trois tonneaux de bois par jour.
local LOT_MINIMUM = 5

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


-- La flotte d'un convoi, comme PR3 la compose : un type marchand tiré au hasard,
-- puis un autre tant que la cale visée n'est pas atteinte, trois au plus. Un
-- bourg peut donc armer une flûte marchande, et une grande ville trois pinasses :
-- le jeu ne cherche pas la flotte juste, il tire.
--
-- Le hasard est REPRODUCTIBLE : il part d'une graine tirée de la ville, pour
-- qu'une partie relancée retrouve les mêmes convois (générateur de Park et
-- Miller, dont les produits tiennent dans un flottant sans perte).
local function composer_flotte(cale_visee, graine)
  local flotte = {}
  local reste = cale_visee
  local g = graine % 2147483646 + 1
  while #flotte < Marchands.NAVIRES_MAX do
    g = (g * 16807) % 2147483647
    local choisi = Navires.marchands[(g % #Navires.marchands) + 1]
    flotte[#flotte + 1] = choisi
    if choisi.cale >= reste then break end
    reste = reste - choisi.cale
  end
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
    entretien = Navires.entretien(navires),   -- or par jour
    or_ = OR_MARCHAND / Marchands.KONVOIS,
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
  Marchands.fonds = 0
  Marchands.demande_ref = nil
  Marchands.liste = {}
  for _, port in ipairs(Archipel.ports) do
    local graine = 0
    for k = 1, string.len(port.cle) do
      graine = (graine * 31 + string.byte(port.cle, k)) % 99991
    end
    local cale = port.habitants * Marchands.CALE_PAR_HABITANT
    -- Le premier convoi dessert ses voisins, le second part au long cours : les
    -- deux métiers qu'il a fallu pour que les chaînes de fabrication traversent
    -- la carte.
    for i = 1, Marchands.KONVOIS do
      local genre = (i == 1) and "caboteur" or "long_cours"
      local circuit = (genre == "caboteur") and tracer_circuit(port.cle) or { port.cle }
      Marchands.liste[#Marchands.liste + 1] =
        armer(port, genre, composer_flotte(cale, graine * 7 + i * 104729), circuit)
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
        -- On n'achète que ce qui dépasse le plateau à 120 % (X3) : le reste est
        -- la réserve dont la ville a besoin.
        local lot = math.min(place, math.floor(l.stock - l.seuils[4]))
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


-- L'INVESTISSEMENT DE L'IA. Les marchands de PR3 ne thésaurisent pas : leur or
-- sert à bâtir des ateliers (`0x7B4F90`). Quand une marchandise est sous-produite
-- sur la carte — sa demande dépasse `Bauquotient` × sa production — un marchand en
-- construit un et paie le terrain (`Bauplatzkosten`).
--
-- On le reproduit pour deux raisons trouvées dans le jeu : drainer l'or que les
-- convois accumulaient sans fin, et grossir les chaînes faibles. On ne bâtit que
-- ce dont LES INTRANTS sont disponibles — une boulangerie sans blé ni sucre ne
-- produirait rien ; le blé et le sucre, eux, se bâtissent toujours, et c'est par
-- eux que la chaîne du pain se débloque. La caisse commune des convois paie, ce
-- qui la vide au rythme où elle se remplit.
local INTERVALLE_CONSTRUCTION = 30    -- jours entre deux chantiers
local COUVERTURE_VISEE = 0.98         -- on ne bâtit plus au-dessus de ce seuil
local INTRANTS_MINIMUM = 0.90         -- couverture requise des intrants pour bâtir
local CHANTIERS_MAX = 8               -- au plus tant de chantiers par mois
local jours_ecoules = 0

-- Le fonds de construction, alimenté par le débordement des caisses des convois.
Marchands.fonds = 0

-- La ville où poser l'atelier : la plus peuplée qui a déjà cette vocation, à
-- défaut la plus peuplée de la carte — c'est là que PR3 concentre les fabriques.
local function ville_pour(cle_bien)
  local hote, taille = nil, -1
  local grande, gtaille = nil, -1
  for _, port in ipairs(Archipel.ports) do
    if port.habitants > gtaille then grande, gtaille = port.cle, port.habitants end
    for _, c in ipairs(port.produits or {}) do
      if c == cle_bien and port.habitants > taille then hote, taille = port.cle, port.habitants end
    end
  end
  return hote or grande
end

-- Le bien le moins couvert dont les intrants suivent — bâtir sans intrants ne
-- produirait rien. Renvoie la marchandise, ou nil si tout est assez couvert.
--
-- On vise une demande DE RÉFÉRENCE, figée à la première passe : la construction
-- comble les chaînes faibles jusqu'au niveau du jour zéro, puis s'arrête. Sans
-- cela elle poursuivrait une demande qui enfle avec la population — chaque
-- atelier bâti nourrissant la croissance qui en réclame un autre, sans fin. Elle
-- rattrape un déséquilibre de départ ; elle n'est pas un moteur de croissance.
local function bien_a_batir(prod, dem)
  local pire, pire_c = nil, COUVERTURE_VISEE
  for _, m in ipairs(Marchandises.liste) do
    local besoin = dem[m.cle]
    if besoin > 0 then
      local seuil = COUVERTURE_VISEE / (m.bauquotient or 1.0)
      local c = prod[m.cle] / besoin
      if c < seuil and c < pire_c then
        local intrants_ok = true
        for _, ing in ipairs(m.recette or {}) do
          if (dem[ing[1]] or 0) > 0 and (prod[ing[1]] or 0) / dem[ing[1]] < INTRANTS_MINIMUM then
            intrants_ok = false
          end
        end
        if intrants_ok then pire, pire_c = m, c end
      end
    end
  end
  return pire
end

-- On bâtit tant que le fonds le permet, au plus quelques chantiers par mois : le
-- fonds vient du débordement des caisses, donc les chantiers suivent le rythme où
-- les convois dégagent un surplus, et cessent quand les chaînes sont complètes.
local function investir()
  -- La demande de référence, figée au premier mois.
  if not Marchands.demande_ref then
    local _, dem = Economie.couverture()
    Marchands.demande_ref = dem
  end
  local ref = Marchands.demande_ref
  for _ = 1, CHANTIERS_MAX do
    local prod = Economie.couverture()
    local m = bien_a_batir(prod, ref)
    if not m or Marchands.fonds < m.batiment.cout then return end
    local cle_ville = ville_pour(m.cle)
    if not cle_ville or not Economie.batir(cle_ville, m.cle) then return end
    Marchands.fonds = Marchands.fonds - m.batiment.cout
  end
end


-- Avance les convois de `jours` jours de jeu (fraction acceptée).
function Marchands.avancer(jours)
  if #Marchands.liste == 0 then Marchands.reinitialiser() end
  if not jours or jours <= 0 then return end

  jours_ecoules = jours_ecoules + jours
  while jours_ecoules >= INTERVALLE_CONSTRUCTION do
    jours_ecoules = jours_ecoules - INTERVALLE_CONSTRUCTION
    investir()
  end

  for _, m in ipairs(Marchands.liste) do
    -- L'entretien des navires, au jour le jour, à quai comme en mer.
    m.or_ = m.or_ - (m.entretien or 0) * jours
    -- Le débordement de la caisse part au fonds de construction : un convoi ne
    -- garde qu'un capital de travail.
    if m.or_ > OR_PLAFOND then
      Marchands.fonds = Marchands.fonds + (m.or_ - OR_PLAFOND)
      m.or_ = OR_PLAFOND
    end
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
