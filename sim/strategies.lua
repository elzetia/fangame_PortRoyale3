-- Les stratégies de route commerciale de Port Royale 3, RÉÉCRITES.
--
-- PR3 a neuf stratégies (enum `0x63D6E0` : MANUAL, WEALTH, PROFIT, STORAGE,
-- RESOURCES, OFFICE, CONSTRUCT, DISTRIBUTE, CENTRAL). Leur logique fine ne se lit
-- pas dans l'exécutable — elle est répartie dans le système d'ordres — mais leur
-- SENS est connu, mot pour mot, par le tutoriel du jeu (voir
-- `outils/PR3_TECHNIQUE.md` §5 et `outils/PR3_SYSTEMES.md`). On les reconstruit
-- donc à partir de ce sens, dans le modèle `set_goods` de PR3 : chaque stratégie
-- répond, pour une ville et un bien, la QUANTITÉ CIBLE à tenir dans l'entrepôt.
-- Le convoi charge quand le stock dépasse la cible, décharge quand il est dessous.
--
-- `nil` veut dire « ce bien ne concerne pas cette stratégie » — le convoi ne le
-- touche pas. C'est ainsi qu'une route « Matériaux de construction » ignore le
-- café et le rhum.
--
-- Ce module est pur (il ne connaît pas Godot) et sert aussi bien les convois de
-- l'IA que, plus tard, les routes que le joueur tracera.

local Economie     = require("sim.economie")
local Marchandises = require("sim.marchandises")

local Strategies = {}

-- Les seuils publiés du tutoriel pour la stratégie « Matériaux de construction ».
Strategies.CONSTRUCT_BOIS = 500
Strategies.CONSTRUCT_BRIQUES = 1000

-- Le plateau de référence d'une ville pour un bien (le stock « normal », X2) :
-- c'est la cible naturelle du modèle set_goods, celle vers laquelle on ramène un
-- entrepôt.
local function reference(cle_ville, cle_bien)
  local l = Economie.ligne(cle_ville, cle_bien)
  return l and l.reference or 0
end


-- MATÉRIAUX DE CONSTRUCTION : « ne collecte que le Bois et les Briques […]
-- s'arrête à 500 de Bois et 1 000 de Briques ». On tient donc ces deux biens à
-- leur plafond, et rien d'autre.
function Strategies.construct(cle_ville, cle_bien)
  if cle_bien == "bois" then return Strategies.CONSTRUCT_BOIS end
  if cle_bien == "briques" then return Strategies.CONSTRUCT_BRIQUES end
  return nil
end


-- MATIÈRES PREMIÈRES : « répartit les matières premières entre les entrepôts,
-- acheminées là où elles sont le plus nécessaire ». On maintient donc chaque
-- matière première au stock de référence de la ville.
function Strategies.resources(cle_ville, cle_bien)
  local m = Marchandises.get(cle_bien)
  if not m or m.categorie ~= "matieres" then return nil end
  return reference(cle_ville, cle_bien)
end


-- ENTREPÔTS VIDES : « collecter toutes les marchandises et les décharger au
-- premier entrepôt rencontré ». La cible est zéro partout sauf au point de
-- déchargement — on charge tout ce qui traîne.
function Strategies.storage(cle_ville, cle_bien)
  return 0
end


-- APPROVISIONNEMENT DES COMPTOIRS (OFFICE) : garder chaque bien au plateau de
-- référence dans ses propres villes. Comme RESOURCES, mais pour tous les biens.
function Strategies.office(cle_ville, cle_bien)
  return reference(cle_ville, cle_bien)
end


-- DISTRIBUER / CENTRALISER : disperser depuis un centre / rassembler vers un
-- centre. Ce sont des variantes d'approvisionnement ; sans point pivot dans la
-- sim, on les ramène à l'approvisionnement au plateau.
Strategies.distribute = Strategies.office
Strategies.central = Strategies.office


-- PROFIT / PROSPÉRITÉ : pas de cible fixe. Ce sont des stratégies d'ARBITRAGE —
-- acheter bas, vendre haut — que la sim gère par le choix de destination du
-- long-courrier (`sim/marchands.lua`, `choisir_cible`). On renvoie donc `nil` :
-- la stratégie ne pose pas de cible set_goods, elle suit la marge.
function Strategies.profit() return nil end
Strategies.wealth = Strategies.profit


-- MANUEL : aucune cible automatique, c'est le joueur qui pose ses ordres.
function Strategies.manual() return nil end


-- La table des générateurs, par nom de stratégie.
Strategies.par_nom = {
  manual = Strategies.manual,
  wealth = Strategies.wealth,
  profit = Strategies.profit,
  storage = Strategies.storage,
  resources = Strategies.resources,
  office = Strategies.office,
  construct = Strategies.construct,
  distribute = Strategies.distribute,
  central = Strategies.central,
}


-- La cible set_goods d'un bien à une escale, sous une stratégie donnée. `nil` si
-- la stratégie ne touche pas ce bien.
function Strategies.cible(strategie, cle_ville, cle_bien)
  local gen = Strategies.par_nom[strategie] or Strategies.profit
  return gen(cle_ville, cle_bien)
end


return Strategies
