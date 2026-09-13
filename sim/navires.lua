-- Les navires de Port Royale 3.
--
-- Seize types, relus dans `ini/constdata.dat` (voir `outils/pr3_constdata.py`) :
-- prix, cale, coque, vitesses et maniabilité sont ceux du jeu, au chiffre près.
--
-- Deux règles du jeu, citées de ses textes, disent comment s'en servir sur la
-- carte :
--
--   « Sur la carte maritime, seule la vitesse maximale est considérée et un
--     convoi ne va jamais plus vite que son navire le plus lent. »
--
-- La vitesse minimale (vent debout) ne sert qu'aux batailles.
--
-- Les unités de vitesse de PR3 ne sont pas les nôtres. On les ancre sur le
-- sloop du joueur, qui file 900 unités de monde par jour — 75 par seconde de
-- jeu à x1, douze secondes par jour (voir `scripts/navire_etat.gd`). Les autres
-- s'en déduisent par le rapport de leurs vitesses maximales : une pinasse va aux
-- 40/44e d'un sloop, un vaisseau de ligne aux 56/44e.
--
-- Lua pur : ce fichier ne connaît pas Godot.

local Navires = {}

Navires.UNITES_JOUR_SLOOP = 900

-- `militaire` : le jeu donne à chaque type un rang minimal pour les marines.
-- Les cinq qu'il leur INTERDIT sont les navires de commerce et la barque des
-- pirates ; c'est ce champ, pas une liste écrite à la main, qui dit quels
-- navires un marchand peut armer.
Navires.liste = {
  { cle = "pinasse",            nom = "Pinasse",            prix =  10000, cale = 200, coque = 100000, vmin = 24, vmax = 40, maniabilite = 100, militaire = false },
  { cle = "sloop",              nom = "Sloop",              prix =  19000, cale = 200, coque = 110000, vmin = 24, vmax = 44, maniabilite = 100, militaire = false },
  { cle = "brick",              nom = "Brick",              prix =  27000, cale = 250, coque = 140000, vmin = 20, vmax = 44, maniabilite =  95, militaire = true },
  { cle = "barque",             nom = "Barque",             prix =  36000, cale = 250, coque = 150000, vmin = 20, vmax = 48, maniabilite =  90, militaire = true },
  { cle = "barque_pirate",      nom = "Barque pirate",      prix =  36000, cale = 300, coque = 180000, vmin = 20, vmax = 48, maniabilite =  90, militaire = false, pirate = true },
  { cle = "flute",              nom = "Flûte",              prix =  40000, cale = 500, coque = 220000, vmin = 16, vmax = 40, maniabilite =  85, militaire = false },
  { cle = "flute_marchande",    nom = "Flûte marchande",    prix =  50000, cale = 800, coque = 300000, vmin = 16, vmax = 40, maniabilite =  80, militaire = false },
  { cle = "corvette",           nom = "Corvette",           prix =  60000, cale = 350, coque = 200000, vmin = 16, vmax = 48, maniabilite =  85, militaire = true },
  { cle = "fregate",            nom = "Frégate",            prix =  70000, cale = 400, coque = 220000, vmin = 20, vmax = 44, maniabilite =  80, militaire = true },
  { cle = "corvette_militaire", nom = "Corvette militaire", prix = 100000, cale = 300, coque = 210000, vmin = 20, vmax = 44, maniabilite =  85, militaire = true },
  { cle = "fregate_militaire",  nom = "Frégate militaire",  prix = 120000, cale = 350, coque = 250000, vmin = 20, vmax = 48, maniabilite =  85, militaire = true },
  { cle = "galion",             nom = "Galion",             prix = 120000, cale = 600, coque = 280000, vmin = 16, vmax = 40, maniabilite =  75, militaire = true },
  { cle = "caraque",            nom = "Caraque",            prix = 140000, cale = 550, coque = 320000, vmin = 20, vmax = 48, maniabilite =  75, militaire = true },
  { cle = "caravelle",          nom = "Caravelle",          prix = 160000, cale = 500, coque = 300000, vmin = 16, vmax = 44, maniabilite =  75, militaire = true },
  { cle = "galion_de_guerre",   nom = "Galion de guerre",   prix = 180000, cale = 400, coque = 320000, vmin = 16, vmax = 52, maniabilite =  70, militaire = true },
  { cle = "vaisseau_de_ligne",  nom = "Vaisseau de ligne",  prix = 200000, cale = 400, coque = 340000, vmin = 12, vmax = 56, maniabilite =  70, militaire = true },
}

Navires.parCle = {}
for _, n in ipairs(Navires.liste) do Navires.parCle[n.cle] = n end

-- Les navires qu'un marchand peut armer, du plus grand au plus petit : c'est
-- l'ordre dans lequel on compose une flotte.
Navires.marchands = {}
for _, n in ipairs(Navires.liste) do
  if not n.militaire and not n.pirate then
    Navires.marchands[#Navires.marchands + 1] = n
  end
end
table.sort(Navires.marchands, function(a, b)
  if a.cale ~= b.cale then return a.cale > b.cale end
  return a.vmax > b.vmax
end)


function Navires.get(cle)
  return Navires.parCle[cle]
end


-- Unités de monde parcourues en un jour par un navire, ou par un groupe de
-- navires : le plus lent donne l'allure.
function Navires.vitesse_jour(navires)
  local vmax = math.huge
  for _, n in ipairs(navires) do
    if n.vmax < vmax then vmax = n.vmax end
  end
  if vmax == math.huge then return 0 end
  return Navires.UNITES_JOUR_SLOOP * vmax / Navires.parCle.sloop.vmax
end


function Navires.cale(navires)
  local c = 0
  for _, n in ipairs(navires) do c = c + n.cale end
  return c
end


return Navires
