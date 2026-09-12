-- Navigation maritime : grille d'eau + A* + lissage de la route.
-- Lua pur : c'est de la simulation, pas du rendu. Le moteur ne fait que
-- dessiner la route qu'on lui renvoie.
--
-- Sans ça, un navire couperait à travers les îles en ligne droite.

local Archipel = require("sim.archipel")

local Navigation = {}

-- Le cache des routes.
--
-- Les marchands tournent en CIRCUIT : les mêmes couples de mouillages
-- reviennent indéfiniment, et une route ne change que si la grille change.
-- Sans cache, chaque départ repayait ses 23 ms, soixante fois par tour de
-- circuit, pour toujours.
--
-- La clé est la paire de CASES, pas la paire de points : deux départs dans la
-- même case donnent la même route. L'écart possible est d'une case, et il ne
-- peut pas faire toucher la terre — le lissage ne tend un segment que du
-- large au large, donc à plus de MARGE de toute côte.
local cache = {}
local cache_n = 0
local CACHE_MAX = 8000

local CELLULE = Archipel.ECHELLE   -- la case du masque, exactement
local MARGE   = 40     -- marge de sécurité au large des côtes

-- Ce que coûte une case située dans la marge, comparée à une case du large.
--
-- La marge était un INTERDIT : la grille bloquait tout ce qui bordait la terre
-- de moins de MARGE. Mais une rade est par définition une case de mer bordant
-- la terre, donc toujours bloquée — l'A* ne pouvait jamais partir d'elle. On
-- cherchait alors la case libre la plus proche « en anneaux », sans regarder
-- ce qu'il y avait entre les deux : pour un mouillage au fond d'une baie, elle
-- tombait de l'AUTRE CÔTÉ d'une pointe, et le raccord traversait l'île. Dix
-- ports sur soixante en étaient là, jusqu'à 138 unités de terre traversée.
--
-- Une passe de mouillage a le droit de longer la côte — c'est ce qu'est une
-- passe. C'est le LARGE qui doit garder ses distances. La marge devient donc
-- un coût : assez élevé pour qu'une traversée préfère toujours le large, assez
-- fini pour qu'on puisse entrer au port.
local PENALITE = 8.0

-- Poids de l'heuristique dans l'A*.
--
-- A 1, l'A* rend la route la plus courte, mais explore tout ce qui pourrait
-- encore la raccourcir : depuis que la grille est a la case du masque, ca
-- coutait 200 ms par route, et les soixante marchands qui partent le deuxieme
-- jour bloquaient le jeu image apres image. Au-dela de 1, on accepte une route
-- un peu plus longue contre beaucoup moins d'exploration. La terre reste
-- infranchissable dans tous les cas : le poids ne change QUE l'ordre de
-- visite, jamais les cases visitables.
local POIDS = 1.6

-- Tas binaire : file de priorité pour A*
local Tas = {}
Tas.__index = Tas

function Tas.nouveau() return setmetatable({ n = 0 }, Tas) end

function Tas:pousser(item, priorite)
  self.n = self.n + 1
  self[self.n] = { item = item, p = priorite }
  local i = self.n
  while i > 1 do
    local parent = math.floor(i / 2)
    if self[parent].p <= self[i].p then break end
    self[parent], self[i] = self[i], self[parent]
    i = parent
  end
end

function Tas:retirer()
  if self.n == 0 then return nil end
  local sommet = self[1]
  self[1] = self[self.n]
  self[self.n] = nil
  self.n = self.n - 1
  local i = 1
  while true do
    local g, d, meilleur = i * 2, i * 2 + 1, i
    if g <= self.n and self[g].p < self[meilleur].p then meilleur = g end
    if d <= self.n and self[d].p < self[meilleur].p then meilleur = d end
    if meilleur == i then break end
    self[i], self[meilleur] = self[meilleur], self[i]
    i = meilleur
  end
  return sommet.item
end


function Navigation.construire()
  local marge_carte = 260
  Navigation.x0 = -Archipel.limites.x - marge_carte
  Navigation.z0 = -Archipel.limites.z - marge_carte
  Navigation.colonnes = math.ceil((Archipel.limites.x * 2 + marge_carte * 2) / CELLULE)
  Navigation.lignes   = math.ceil((Archipel.limites.z * 2 + marge_carte * 2) / CELLULE)

  Navigation.bloque = {}
  Navigation.proche = {}
  for c = 1, Navigation.colonnes do
    Navigation.bloque[c] = {}
    Navigation.proche[c] = {}
    for l = 1, Navigation.lignes do
      local x = Navigation.x0 + (c - 0.5) * CELLULE
      local z = Navigation.z0 + (l - 0.5) * CELLULE
      -- `bloque` : la terre peinte, seul vrai obstacle.
      -- `proche` : de l'eau, mais à moins de MARGE d'une côte.
      Navigation.bloque[c][l] = Archipel.estTerre(x, z, 0)
      Navigation.proche[c][l] = not Navigation.bloque[c][l]
        and Archipel.estTerre(x, z, MARGE)
    end
  end
  cache = {}
  cache_n = 0
  Navigation.zones = Navigation.marquerZones()
  return Navigation.colonnes * Navigation.lignes
end

local function versCase(x, z)
  local c = math.floor((x - Navigation.x0) / CELLULE) + 1
  local l = math.floor((z - Navigation.z0) / CELLULE) + 1
  if c < 1 then c = 1 elseif c > Navigation.colonnes then c = Navigation.colonnes end
  if l < 1 then l = 1 elseif l > Navigation.lignes then l = Navigation.lignes end
  return c, l
end

local function versMonde(c, l)
  return Navigation.x0 + (c - 0.5) * CELLULE,
         Navigation.z0 + (l - 0.5) * CELLULE
end

local function libre(c, l)
  if c < 1 or l < 1 or c > Navigation.colonnes or l > Navigation.lignes then return false end
  return not Navigation.bloque[c][l]
end


-- Au large : de l'eau, et à plus de MARGE de toute côte.
local function auLarge(c, l)
  if c < 1 or l < 1 or c > Navigation.colonnes or l > Navigation.lignes then return false end
  return not Navigation.bloque[c][l] and not Navigation.proche[c][l]
end


-- Les COMPOSANTES d'eau. Deux points qui ne communiquent pas ne donneront
-- jamais de route, et le dire doit coûter un test, pas une exploration.
--
-- Sans ça, un itinéraire impossible vidait l'A* sur toute la mer atteignable
-- avant d'abandonner : 1 523 ms par tentative, mesuré, contre 27 ms pour une
-- route qui aboutit. Trois mouillages sont enclos dans une eau que
-- l'illustration peint fermée, et les marchands qui les desservent
-- réessayaient à chaque départ — c'est ce qui faisait tomber le jeu à cinq
-- images par seconde le deuxième jour.
--
-- Le remplissage suit EXACTEMENT la règle de déplacement de l'A*, interdiction
-- de couper un coin de terre en diagonale comprise. Une composante est donc
-- précisément une classe d'accessibilité : ni plus large, auquel cas on
-- promettrait une route qui n'existe pas, ni plus étroite, auquel cas on en
-- refuserait une qui existe.
local function zoneDe(c, l)
  if c < 1 or l < 1 or c > Navigation.colonnes or l > Navigation.lignes then return nil end
  return Navigation.zone[(l - 1) * Navigation.colonnes + c]
end


function Navigation.marquerZones()
  local col, lig = Navigation.colonnes, Navigation.lignes
  local zone = {}
  Navigation.zone = zone
  local n = 0
  for l0 = 1, lig do
    for c0 = 1, col do
      local id0 = (l0 - 1) * col + c0
      if zone[id0] == nil and libre(c0, l0) then
        n = n + 1
        zone[id0] = n
        local pile, haut = { id0 }, 1
        while haut > 0 do
          local id = pile[haut]
          pile[haut] = nil
          haut = haut - 1
          local c = (id - 1) % col + 1
          local l = math.floor((id - 1) / col) + 1
          for dc = -1, 1 do
            for dl = -1, 1 do
              if not (dc == 0 and dl == 0) and libre(c + dc, l + dl) then
                local ok = true
                if dc ~= 0 and dl ~= 0 then
                  ok = libre(c + dc, l) and libre(c, l + dl)
                end
                if ok then
                  local nid = (l + dl - 1) * col + c + dc
                  if zone[nid] == nil then
                    zone[nid] = n
                    haut = haut + 1
                    pile[haut] = nid
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  return n
end

-- Si un point tombe sur la terre, on cherche l'eau navigable la plus proche.
-- Depuis que `libre` ne parle plus que de la terre peinte, une rade répond
-- oui du premier coup : ce secours ne sert qu'aux points aberrants.
local function libreLePlusProche(c, l)
  if libre(c, l) then return c, l end
  for anneau = 1, 40 do
    for dc = -anneau, anneau do
      for dl = -anneau, anneau do
        if math.abs(dc) == anneau or math.abs(dl) == anneau then
          if libre(c + dc, l + dl) then return c + dc, l + dl end
        end
      end
    end
  end
  return nil
end

-- Vue dégagée entre deux points ? Échantillonnage le long du segment.
local function vueDegagee(x1, z1, x2, z2)
  local dx, dz = x2 - x1, z2 - z1
  local distance = math.sqrt(dx * dx + dz * dz)
  local pas = math.max(2, math.ceil(distance / (CELLULE * 0.5)))
  for i = 0, pas do
    local t = i / pas
    local c, l = versCase(x1 + dx * t, z1 + dz * t)
    if not auLarge(c, l) then return false end
  end
  return true
end

-- Retire les points intermédiaires inutiles : la route devient une suite de
-- longues lignes droites, comme un cap tracé à la règle sur une carte marine.
local function tendre(points)
  if #points <= 2 then return points end
  local sortie = { points[1] }
  local i = 1
  while i < #points do
    local j = #points
    while j > i + 1 do
      local a, b = points[i], points[j]
      if vueDegagee(a[1], a[2], b[1], b[2]) then break end
      j = j - 1
    end
    sortie[#sortie + 1] = points[j]
    i = j
  end
  return sortie
end

-- Trace une route. Renvoie une liste de { x, z }, sans le point de départ.
function Navigation.route(xd, zd, xa, za)
  if not Navigation.bloque then Navigation.construire() end

  if vueDegagee(xd, zd, xa, za) then
    return { { xa, za } }
  end

  local cd, ld = libreLePlusProche(versCase(xd, zd))
  local ca, la = libreLePlusProche(versCase(xa, za))
  if not cd or not ca then return nil end

  -- Inatteignable : on le sait sans chercher.
  -- Attention au nommage : `za` est la coordonnée z d'arrivée, un paramètre de
  -- cette fonction. Une locale du même nom la masquerait, et c'est l'identité
  -- de zone qui finirait dans le dernier point de la route.
  local zone_dep, zone_arr = zoneDe(cd, ld), zoneDe(ca, la)
  if zone_dep == nil or zone_arr == nil or zone_dep ~= zone_arr then return nil end

  local cle = ((ld - 1) * Navigation.colonnes + cd)
            * (Navigation.colonnes * Navigation.lignes + 1)
            + ((la - 1) * Navigation.colonnes + ca)
  local garde = cache[cle]
  if garde then
    -- Une COPIE : l'appelant consomme sa route en retirant les points au fur
    -- et à mesure (`table.remove` dans marchands.lua). Rendre la table du
    -- cache la viderait pour tout le monde.
    local copie = {}
    for i = 1, #garde do copie[i] = { garde[i][1], garde[i][2] } end
    -- L'arrivée exacte, elle, appartient à l'appelant : la case est partagée,
    -- le point ne l'est pas.
    if #copie > 0 then copie[#copie] = { xa, za } end
    return copie
  end

  local idDepart = (ld - 1) * Navigation.colonnes + cd
  local idArrivee = (la - 1) * Navigation.colonnes + ca

  local cout, provenance = { [idDepart] = 0 }, {}
  local ferme = {}
  local ouvert = Tas.nouveau()

  local function heuristique(c, l)
    local dc, dl = math.abs(c - ca), math.abs(l - la)
    return (dc + dl) + (math.sqrt(2) - 2) * math.min(dc, dl)
  end

  ouvert:pousser(idDepart, POIDS * heuristique(cd, ld))

  local trouve = false
  while true do
    local courant = ouvert:retirer()
    if not courant then break end
    if courant == idArrivee then trouve = true; break end
    if not ferme[courant] then
      ferme[courant] = true
      local cc = (courant - 1) % Navigation.colonnes + 1
      local cl = math.floor((courant - 1) / Navigation.colonnes) + 1
      for dc = -1, 1 do
        for dl = -1, 1 do
          if not (dc == 0 and dl == 0) then
            local nc, nl = cc + dc, cl + dl
            if libre(nc, nl) then
              -- interdit de couper un coin de terre en diagonale
              local ok = true
              if dc ~= 0 and dl ~= 0 then
                ok = libre(cc + dc, cl) and libre(cc, cl + dl)
              end
              if ok then
                local nid = (nl - 1) * Navigation.colonnes + nc
                local pas = (dc ~= 0 and dl ~= 0) and math.sqrt(2) or 1
                if Navigation.proche[nc][nl] then pas = pas * PENALITE end
                local nouveau = cout[courant] + pas
                if not cout[nid] or nouveau < cout[nid] then
                  cout[nid] = nouveau
                  provenance[nid] = courant
                  ouvert:pousser(nid, nouveau + POIDS * heuristique(nc, nl))
                end
              end
            end
          end
        end
      end
    end
  end

  if not trouve then return nil end

  local cases, courant = {}, idArrivee
  while courant do
    table.insert(cases, 1, courant)
    courant = provenance[courant]
  end

  local points = {}
  for _, id in ipairs(cases) do
    local c = (id - 1) % Navigation.colonnes + 1
    local l = math.floor((id - 1) / Navigation.colonnes) + 1
    local x, z = versMonde(c, l)
    points[#points + 1] = { x, z }
  end
  points[1] = { xd, zd }
  points[#points + 1] = { xa, za }

  local route = tendre(points)
  table.remove(route, 1)     -- le premier point, c'est le navire lui-même

  if cache_n < CACHE_MAX then
    local garde = {}
    for i = 1, #route do garde[i] = { route[i][1], route[i][2] } end
    cache[cle] = garde
    cache_n = cache_n + 1
  end
  return route
end

return Navigation
