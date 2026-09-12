-- Navigation maritime : grille d'eau + A* + lissage de la route.
-- Lua pur : c'est de la simulation, pas du rendu. Le moteur ne fait que
-- dessiner la route qu'on lui renvoie.
--
-- Sans ça, un navire couperait à travers les îles en ligne droite.

local Archipel = require("sim.archipel")

local Navigation = {}

local CELLULE = 26     -- côté d'une case, en mètres
local MARGE   = 40     -- marge de sécurité au large des côtes

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
  for c = 1, Navigation.colonnes do
    Navigation.bloque[c] = {}
    for l = 1, Navigation.lignes do
      local x = Navigation.x0 + (c - 0.5) * CELLULE
      local z = Navigation.z0 + (l - 0.5) * CELLULE
      Navigation.bloque[c][l] = Archipel.estTerre(x, z, MARGE)
    end
  end
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

-- Si un point tombe sur la terre, on cherche l'eau navigable la plus proche.
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
    if not libre(c, l) then return false end
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

  local idDepart = (ld - 1) * Navigation.colonnes + cd
  local idArrivee = (la - 1) * Navigation.colonnes + ca

  local cout, provenance = { [idDepart] = 0 }, {}
  local ferme = {}
  local ouvert = Tas.nouveau()

  local function heuristique(c, l)
    local dc, dl = math.abs(c - ca), math.abs(l - la)
    return (dc + dl) + (math.sqrt(2) - 2) * math.min(dc, dl)
  end

  ouvert:pousser(idDepart, heuristique(cd, ld))

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
                local nouveau = cout[courant] + pas
                if not cout[nid] or nouveau < cout[nid] then
                  cout[nid] = nouveau
                  provenance[nid] = courant
                  ouvert:pousser(nid, nouveau + heuristique(nc, nl))
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
  return route
end

return Navigation
