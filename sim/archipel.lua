-- La géographie : source de vérité unique, partagée par la simulation et le
-- rendu. Lua pur, aucune référence à Godot : ce module doit rester portable.
--
-- C'EST LA CARTE DE PORT ROYALE 3, la vraie. Les golfes, Cuba, Hispaniola,
-- l'arc des Petites Antilles et le Main espagnol viennent de son `ini/map.bmp`,
-- et ses soixante ports de son `ini/constdata.dat` — nom, nation, taille et
-- les quatre marchandises que chacun produit. L'extraction vit dans
-- `outils/extraire_pr3_monde.py`, qui documente ce qu'il a fallu retro-concevoir.
--
-- Avant, c'était sept îles décrites par des harmoniques, et cinq ports. Assez
-- pour bâtir l'économie, pas pour la faire vivre : à cinq villes aux
-- productions voisines, aucune route ne payait sa cale. Le commerce est un jeu
-- de nombres — il lui faut des dizaines de ports, des distances qui coûtent, et
-- des régions qui ne produisent pas la même chose. Soixante ports règlent la
-- question d'un coup.
--
-- Repère : plan XZ, origine au CENTRE de la carte. Y est la verticale, comme
-- dans Godot. Une case du masque de PR3 vaut ÉCHELLE unités de monde.

local Carte  = require("sim.carte_monde")
local Villes   = require("sim.villes_pr3")
local Reglages = require("sim.villes_reglages")

local Archipel = {}

-- Douze unités par case. Ce n'est pas un chiffre libre : il est choisi pour que
-- la vitesse d'un navire reste celle qu'on avait réglée (700 unités par jour) et
-- que les traversées durent ce qu'elles doivent. Port Royale — La Havane fait
-- 251 cases, donc 3 012 unités, donc quatre jours et demi de mer. C'est l'ordre
-- de grandeur de Port Royale 3.
Archipel.ECHELLE = 12

local L2, H2 = Carte.largeur / 2, Carte.hauteur / 2

Archipel.limites = { x = L2 * Archipel.ECHELLE, z = H2 * Archipel.ECHELLE }


-- Case du masque <-> unités de monde.
function Archipel.versMonde(cx, cz)
  return (cx - L2) * Archipel.ECHELLE, (cz - H2) * Archipel.ECHELLE
end

function Archipel.versCase(x, z)
  return math.floor(x / Archipel.ECHELLE + L2), math.floor(z / Archipel.ECHELLE + H2)
end


-- Le point est-il sur la terre ? `marge` gonfle les côtes, en unités de monde :
-- c'est ainsi que la navigation tient les navires au large.
function Archipel.estTerre(x, z, marge)
  local cx, cz = Archipel.versCase(x, z)
  local rayon = math.floor((marge or 0) / Archipel.ECHELLE + 0.5)
  if rayon <= 0 then
    return Carte.terreCase(cx, cz)
  end
  return Carte.terreCaseDilatee(cx, cz, rayon)
end


Archipel.nations = {
  espagne    = { cle = "espagne",    nom = "Espagne",    adj = "espagnole",   couleur = { 0.90, 0.72, 0.13 }, bord = { 0.72, 0.10, 0.13 } },
  angleterre = { cle = "angleterre", nom = "Angleterre", adj = "anglaise",    couleur = { 0.78, 0.09, 0.18 }, bord = { 1.00, 1.00, 1.00 } },
  france     = { cle = "france",     nom = "France",     adj = "française",   couleur = { 0.15, 0.32, 0.68 }, bord = { 0.95, 0.85, 0.35 } },
  hollande   = { cle = "hollande",   nom = "Hollande",   adj = "hollandaise", couleur = { 0.89, 0.45, 0.11 }, bord = { 0.20, 0.28, 0.55 } },
  portugal   = { cle = "portugal",   nom = "Portugal",   adj = "portugaise",  couleur = { 0.11, 0.47, 0.20 }, bord = { 0.92, 0.78, 0.22 } },
}

-- Les quatre régions de PR3, qu'il numérote 11 à 14. Elles comptent : c'est
-- d'elles que vient la structure du commerce — le golfe ne produit pas ce que
-- produisent les Petites Antilles, et il y a des jours de mer entre les deux.
Archipel.regions = {
  [11] = "Golfe et Floride",
  [12] = "Mexique et Main",
  [13] = "Petites Antilles",
  [14] = "Grandes Antilles",
}


-- Population de départ, d'après la classe de taille de PR3 (1 bourg, 2 ville,
-- 3 grande ville). L'écart interne est déterministe et tiré du nom : deux
-- bourgs voisins ne doivent pas afficher le même chiffre, sinon la carte a
-- l'air d'un tableur.
local SOCLE   = { [1] = 900, [2] = 1800, [3] = 2800 }
local AMPLEUR = { [1] = 400, [2] = 400, [3] = 400 }

local function population(v)
  local graine = 0
  for k = 1, string.len(v.cle) do
    graine = (graine * 31 + string.byte(v.cle, k)) % 1009
  end
  return SOCLE[v.taille] + math.floor(AMPLEUR[v.taille] * (graine % 100) / 100)
end


-- Le bourg est la terre la plus proche du mouillage. PR3 place ses villes sur
-- une case de MER bordant la côte : le mouillage est donc donné, et c'est le
-- village qu'il faut aller chercher à terre. Sans ça le clocher flotterait.
local function bourg_pres_de(cx, cz)
  for r = 1, 6 do
    local meilleur, d2 = nil, math.huge
    for dz = -r, r do
      for dx = -r, r do
        if math.max(math.abs(dx), math.abs(dz)) == r and Carte.terreCase(cx + dx, cz + dz) then
          local d = dx * dx + dz * dz
          if d < d2 then meilleur, d2 = { cx + dx, cz + dz }, d end
        end
      end
    end
    if meilleur then return meilleur[1], meilleur[2] end
  end
  return cx, cz
end


-- Publique : l'éditeur de villes recalcule le bourg après avoir bougé le
-- mouillage, et il passe par le pont.
Archipel.bourgPres = bourg_pres_de

Archipel.ports = {}
for _, v in ipairs(Villes) do
  -- Les retouches faites à l'éditeur passent AVANT le calcul du bourg : celui-ci
  -- se déduit du mouillage, donc déplacer l'un doit déplacer l'autre.
  local r = Reglages[v.cle] or {}
  local cas = r.case or v.case
  local bx, bz = bourg_pres_de(cas[1], cas[2])
  Archipel.ports[#Archipel.ports + 1] = {
    cle = v.cle,
    nom = v.nom,
    nation = v.nation,
    region = v.region,
    taille = v.taille,
    produits = v.produits,
    case = cas,                -- le mouillage, en cases
    caseBourg = { bx, bz },    -- le village, en cases
    habitants = population(v),
    -- `decalage` ne bouge QUE l'image, en unités de monde : le point réel du
    -- port reste sur l'eau. C'est ce qui permet de poser joliment un village
    -- sans déplacer le mouillage ni la cible du clic.
    decalage = r.decalage or { 0.0, 0.0 },
    -- A-t-elle un chantier naval, et de quel NIVEAU ? En PR3 les chantiers ont des
    -- paliers (`AusbauKosten Upgrade_Shipyard`) et un chantier plus grand construit
    -- de plus gros navires. Heuristique à l'échelle de la ville : pas de chantier
    -- dans les bourgs (taille 1), niveau 2 dans les villes, niveau 3 dans les grandes
    -- villes. À caler sur la liste réelle de PR3 (emplacement « chantier » des plans).
    chantier = (v.taille or 1) >= 2,
    niveau_chantier = ((v.taille or 1) >= 3 and 3) or ((v.taille or 1) >= 2 and 2) or 0,
  }
end

Archipel.portsParCle = {}
for _, p in ipairs(Archipel.ports) do
  Archipel.portsParCle[p.cle] = p
end


-- Position du bourg et de sa rade. Le bourg est à terre, le mouillage au large :
-- c'est là que le navire s'arrête.
function Archipel.positionPort(port)
  local bx, bz = Archipel.versMonde(port.caseBourg[1] + 0.5, port.caseBourg[2] + 0.5)
  local rx, rz = Archipel.versMonde(port.case[1] + 0.5, port.case[2] + 0.5)
  return bx, bz, rx, rz
end


-- Le mouillage valide le plus proche d'un point : une case de MER bordant la
-- terre. C'est la définition de PR3, et c'est l'éditeur de villes qui s'en sert.
function Archipel.mouillageProche(x, z, rayon_max)
  local cx, cz = Archipel.versCase(x, z)
  rayon_max = rayon_max or 40
  local COTES = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
  for r = 0, rayon_max do
    for dz = -r, r do
      for dx = -r, r do
        if r == 0 or math.max(math.abs(dx), math.abs(dz)) == r then
          local ux, uz = cx + dx, cz + dz
          -- `dansCarte` d'abord : hors des bornes, `terreCase` dit false, ce qui
          -- se lit comme de la mer. Le bord de carte passait alors pour un
          -- mouillage, et la ville disparaissait sous la scene.
          if Carte.dansCarte(ux, uz) and not Carte.terreCase(ux, uz) then
            for _, d in ipairs(COTES) do
              if Carte.terreCase(ux + d[1], uz + d[2]) then return ux, uz end
            end
          end
        end
      end
    end
  end
  return nil
end


-- Contour d'une masse de terre, suivi sur le masque, en unités de monde.
--
-- Le rendu en a besoin : il dessine des polygones, pas des pixels. On monte
-- jusqu'à sortir de la terre, puis on longe le bord en gardant toujours la
-- terre du même côté (marche de Moore). Un contour se referme sur lui-même.
function Archipel.contourTerre(cx, cz, max_points)
  max_points = max_points or 4000
  while Carte.terreCase(cx, cz) do cz = cz - 1 end
  cz = cz + 1
  if not Carte.terreCase(cx, cz) then return {} end

  local VOISINS = { { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 },
                    { -1, 0 }, { -1, -1 }, { 0, -1 }, { 1, -1 } }
  local pts = {}
  local x, z, dir = cx, cz, 0
  local x0, z0 = x, z
  repeat
    local wx, wz = Archipel.versMonde(x + 0.5, z + 0.5)
    pts[#pts + 1] = { x = wx, z = wz }
    local trouve = false
    for k = 0, 7 do
      local d = (dir + 6 + k) % 8
      local nx, nz = x + VOISINS[d + 1][1], z + VOISINS[d + 1][2]
      if Carte.terreCase(nx, nz) then
        x, z, dir, trouve = nx, nz, d, true
        break
      end
    end
    if not trouve then break end
  until (x == x0 and z == z0) or #pts >= max_points
  return pts
end


-- L'ancienne carte procédurale décrivait sept îles par des harmoniques, et le
-- rendu s'en servait pour bâtir son maillage. Il n'y a plus d'îles nommées :
-- la terre est un masque. On garde les tables vides pour que le pont ne casse
-- pas, le temps que le rendu bascule lui aussi sur le masque.
Archipel.iles = {}
Archipel.ilesParCle = {}

return Archipel
