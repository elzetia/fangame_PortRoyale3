-- Les navires de Port Royale 3.
--
-- Seize types, relus dans `ini/constdata.dat` (voir `outils/pr3_constdata.py`) :
-- chaque colonne porte le nom que lui donne le chargeur de l'exécutable.
--
--   prix          `Value`       ce que coûte le navire à l'achat
--   cale          `Capacity`    tonneaux
--   coque         `Hitpoints`   points de coque (voiles : autant)
--   construction  `Construct`   ce que coûte sa construction au chantier
--   entretien     `DailyCosts`  ce qu'il coûte chaque jour, en or
--   vmin, vmax    vitesse vent debout, vent arrière
--   maniabilite   `Wendig`
--   tirant        `Gauge`       CLASSE de tirant d'eau (0, 1, 2)
--
-- Le tirant n'est pas une profondeur. Le chargeur lit `Gauge` puis le divise par
-- trois et n'en garde que le RESTE (`idiv ecx` avec ecx = 3, en `0x85fe34`) :
-- c'est donc une classe à trois niveaux, et c'est pourquoi l'écran du chantier
-- de PR3 affiche « 0 » pour le sloop. La classe suit la carène et non le
-- tonnage : la flûte commerciale (800 tonneaux) est en 1, le galion de guerre
-- (400) en 2.
--
-- Les seize navires sont lus, vaisseau de ligne compris : l'enregistrement
-- déclare lui-même son nombre de positions de canon, et le triplet
-- `Nations`/`Masts`/`Gauge` suit la dernière d'entre elles.
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
-- `modele` est le nom du navire dans les fichiers de PR3. La carte s'en sert pour
-- trouver l'atlas du navire (voir `outils/rendre_navires_pr3.gd`) ; des modèles
-- faits pour le projet pourront prendre le même nom.
--
-- Lua pur : ce fichier ne connaît pas Godot.

local Navires = {}

Navires.UNITES_JOUR_SLOOP = 900

-- `militaire` : le jeu donne à chaque type un rang minimal pour les marines.
-- Les cinq qu'il leur INTERDIT sont les navires de commerce et la barque des
-- pirates ; c'est ce champ, pas une liste écrite à la main, qui dit quels
-- navires un marchand peut armer.
Navires.liste = {
  { cle = "pinasse",            nom = "Pinasse",            modele = "pinnace",          prix =  10000, cale = 200, coque = 100, construction =   9000, entretien = 100, vmin = 24, vmax = 40, maniabilite = 100, canons = 8, equipage = 40, tirant = 0, militaire = false },
  { cle = "sloop",              nom = "Sloop",              modele = "sloop",            prix =  19000, cale = 200, coque = 110, construction =  18000, entretien = 110, vmin = 24, vmax = 44, maniabilite = 100, canons = 14, equipage = 70, tirant = 0, militaire = false },
  { cle = "brick",              nom = "Brick",              modele = "brig",             prix =  27000, cale = 250, coque = 140, construction =  25000, entretien = 140, vmin = 20, vmax = 44, maniabilite =  95, canons = 16, equipage = 80, tirant = 0, militaire = true },
  { cle = "barque",             nom = "Barque",             modele = "barc",             prix =  36000, cale = 250, coque = 150, construction =  35000, entretien = 150, vmin = 20, vmax = 48, maniabilite =  90, canons = 20, equipage = 100, tirant = 0, militaire = true },
  { cle = "barque_pirate",      nom = "Barque pirate",      modele = "piratebarc",       prix =  36000, cale = 300, coque = 180, construction =  35000, entretien = 180, vmin = 20, vmax = 48, maniabilite =  90, canons = 24, equipage = 120, tirant = 0, militaire = false, pirate = true },
  { cle = "flute",              nom = "Flûte",              modele = "fluyt",            prix =  40000, cale = 500, coque = 220, construction =  40000, entretien = 220, vmin = 16, vmax = 40, maniabilite =  85, canons = 16, equipage = 80, tirant = 1, militaire = false },
  { cle = "flute_marchande",    nom = "Flûte commerciale",    modele = "tradefluyt",       prix =  50000, cale = 800, coque = 300, construction =  48000, entretien = 240, vmin = 16, vmax = 40, maniabilite =  80, canons = 8, equipage = 40, tirant = 1, militaire = false },
  { cle = "corvette",           nom = "Corvette",           modele = "corvette",         prix =  60000, cale = 350, coque = 200, construction =  60000, entretien = 200, vmin = 16, vmax = 48, maniabilite =  85, canons = 24, equipage = 120, tirant = 0, militaire = true },
  { cle = "fregate",            nom = "Frégate",            modele = "frigate",          prix =  70000, cale = 400, coque = 220, construction =  72000, entretien = 220, vmin = 20, vmax = 44, maniabilite =  80, canons = 26, equipage = 130, tirant = 1, militaire = true },
  { cle = "corvette_militaire", nom = "Corvette combat", modele = "militarycorvette", prix = 100000, cale = 300, coque = 210, construction = 105000, entretien = 210, vmin = 20, vmax = 44, maniabilite =  85, canons = 32, equipage = 160, tirant = 0, militaire = true },
  { cle = "fregate_militaire",  nom = "Frégate combat",  modele = "militaryfrigate",  prix = 120000, cale = 350, coque = 250, construction = 130000, entretien = 250, vmin = 20, vmax = 48, maniabilite =  85, canons = 36, equipage = 180, tirant = 1, militaire = true },
  { cle = "galion",             nom = "Galion",             modele = "galleon",          prix = 120000, cale = 600, coque = 280, construction = 135000, entretien = 280, vmin = 16, vmax = 40, maniabilite =  75, canons = 36, equipage = 180, tirant = 2, militaire = true },
  { cle = "caraque",            nom = "Caraque",            modele = "carrack",          prix = 140000, cale = 550, coque = 320, construction = 160000, entretien = 320, vmin = 20, vmax = 48, maniabilite =  75, canons = 40, equipage = 200, tirant = 2, militaire = true },
  { cle = "caravelle",          nom = "Caravelle",          modele = "caravel",          prix = 160000, cale = 500, coque = 300, construction = 180000, entretien = 300, vmin = 16, vmax = 44, maniabilite =  75, canons = 40, equipage = 200, tirant = 2, militaire = true },
  { cle = "galion_de_guerre",   nom = "Galion de guerre",   modele = "wargalleon",       prix = 180000, cale = 400, coque = 320, construction = 210000, entretien = 320, vmin = 16, vmax = 52, maniabilite =  70, canons = 46, equipage = 230, tirant = 2, militaire = true },
  { cle = "vaisseau_de_ligne",  nom = "Vaisseau de ligne",  modele = "liner",            prix = 200000, cale = 400, coque = 340, construction = 240000, entretien = 340, vmin = 12, vmax = 56, maniabilite =  70, canons = 50, equipage = 250, tirant = 2, militaire = true },
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


-- Ce qu'une flotte coûte par jour : la somme de ses `DailyCosts`.
function Navires.entretien(navires)
  local c = 0
  for _, n in ipairs(navires) do c = c + n.entretien end
  return c
end


-- Les agrégats que la VIGNETTE DE CONVOI de PR3 affiche dans son onglet
-- « loupe » : le nombre de canons, l'équipage et la coque du convoi entier.
-- Ce sont de simples sommes — une fiche de navire porte déjà `canons`,
-- `equipage` et `coque`.
--
-- CE QU'ON NE CALCULE PAS, ET POURQUOI. PR3 montre aussi une PUISSANCE
-- (`tf_strength`, avec son `tf_strength_max`), qu'on retrouve sur l'écran
-- d'organisation et sur le résultat de bataille navale. Sa formule n'est
-- établie nulle part dans ce projet : on ne connaît que le nom du champ. On la
-- laisse donc vide plutôt que d'inventer un nombre — comme les seuils de rang.
function Navires.canons(navires)
  local c = 0
  for _, n in ipairs(navires) do c = c + (n.canons or 0) end
  return c
end


function Navires.equipage(navires)
  local c = 0
  for _, n in ipairs(navires) do c = c + (n.equipage or 0) end
  return c
end


function Navires.coque(navires)
  local c = 0
  for _, n in ipairs(navires) do c = c + (n.coque or 0) end
  return c
end


return Navires
