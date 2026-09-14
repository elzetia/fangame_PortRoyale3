-- Les vingt marchandises de Port Royale 3.
--
-- La liste est la sienne, et les PRIX DE BASE aussi : bois 33, blé 33, sucre 50,
-- métal 83, tissu 150, outils 200, rhum 267, viande 300, vêtements 450. Ils sont
-- relus dans `ini/constdata.dat`, table `Standardpreise` (voir
-- `outils/pr3_constdata.py`), et ils donnent une échelle bien plus raide que
-- celle que j'avais devinée — un tonneau de rhum y vaut huit fois un quintal
-- de blé.
--
-- Le projet est parti de la liste de Port Royale 1 (21 denrées, dont poisson,
-- sel, vin et poterie). PR3 a une autre gamme : ni poisson ni sel, mais du pain,
-- du café, des teintures et du cordage. On a basculé sur la sienne le jour où les
-- vingt vignettes sont arrivées — c'est la seule façon d'avoir une icône pour
-- chaque ligne, et une économie qui se raconte d'une seule voix.
--
-- `verbrauch` est la table de consommation de PR3 (`Warenverbrauch`), telle que
-- son chargeur la range. `conso`, qu'on en tire, est en tonneaux par jour et par
-- millier d'habitants : verbrauch / 200.
--
-- L'échelle n'est pas un choix : elle se lit dans le code du jeu. Sa
-- consommation quotidienne vaut verbrauch x habitants / 100 unités, et un
-- tonneau (`1Fass`) en vaut 2 000. Une échelle de 50 avait été essayée avant
-- qu'on lise les seuils de prix, pour qu'une cale de sloop pèse sur un marché ;
-- PR3 obtient cet effet autrement, par des stocks visés de trente à cinquante
-- jours de besoins (voir `sim/economie.lua`), et la consommation quatre fois
-- trop forte vidait la carte.
--
-- `grundbedarf` est le besoin de base de PR3, en tonneaux, que chaque ville
-- ajoute à son premier seuil de prix : trente de bois et soixante de briques
-- pour bâtir, cinq pour tout le reste.
--
-- `export` est ce que l'Europe absorbe EN PLUS, dans les mêmes unités. PR3 compte
-- cette demande à part (`Verbr. Export` dans son outil de débogage) et ne la
-- donne qu'aux quatre denrées qui partent en galion : tabac, cacao, café,
-- teintures. La table qu'on avait relevée en jeu les mêlait aux habitants, à
-- 1,3 fois la consommation pour les trois premières et 1,2 pour la teinture ;
-- ce sont ces écarts qu'on garde ici comme export.
--
-- C'est ce qui lie l'économie à la démographie : une ville qui grandit consomme
-- davantage, donc fait monter ses prix, donc appelle le marchand.

local Marchandises = {}

Marchandises.ECHELLE = 200

Marchandises.CATEGORIES = {
  vivres       = "Vivres",
  matieres     = "Matières premières",
  coloniales   = "Denrées coloniales",
  manufactures = "Produits manufacturés",
}

-- L'ORDRE EST CELUI DE PORT ROYALE 3, relevé dans le jeu. Ce n'est ni l'ordre
-- alphabétique ni un classement par catégorie : il suit la logique du joueur,
-- des matériaux bruts vers les produits finis, en gardant voisines les denrées
-- qu'on achète ensemble. Le comptoir affiche la liste telle quelle, donc qui
-- connaît PR3 retrouve ses lignes au même rang.
--
-- Les catégories restent posées sur chaque ligne : elles servent aux règles,
-- pas au rangement.
--
-- LES RECETTES SONT CELLES DE PR3, relues dans `constdata.dat` : les index des
-- intrants, puis leur quantité par unité produite, rangée en SOIXANTE-QUATRIÈMES.
-- Le facteur se lit dans le chargeur de l'exécutable, qui multiplie la quantité
-- de l'ini par 64 avant de la ranger sur un octet. Un premier relevé, fait à
-- l'oeil, avait divisé par 32 : toutes les recettes étaient deux fois trop
-- gourmandes.
--
-- La preuve que c'est juste tient dans les prix. PR3 paie 25 ouvriers à 6 pièces
-- par jour, plus 50 de frais fixes : 200 pièces par atelier. Divisés par ce que
-- l'atelier produit, plus le coût de ses intrants à ces quantités, on retombe sur
-- les vingt prix standard — tissu 150, métal 83, outils 200, viande 300,
-- vêtements 450, rhum 267, pain 142. Le prix de PR3 EST le coût de production.
--
-- Par rapport aux recettes d'avant PR3, cinq lignes changent : le pain se fait au
-- sucre et non au maïs, le tissu et le cordage prennent un intrant au lieu de
-- deux, les outils à moitié, et le métal, le café et le cacao ne sont plus tirés
-- de rien.
Marchandises.liste = {
  { cle = "bois",      nom = "Bois",        prix =  33, categorie = "matieres",     verbrauch = 275, grundbedarf = 30 },
  { cle = "briques",   nom = "Briques",     prix =  33, categorie = "matieres",     verbrauch = 550, grundbedarf = 60 },
  { cle = "ble",       nom = "Blé",         prix =  33, categorie = "vivres",       verbrauch = 550 },
  { cle = "fruits",    nom = "Fruits",      prix =  50, categorie = "vivres",       verbrauch = 440 },
  { cle = "mais",      nom = "Maïs",        prix =  50, categorie = "vivres",       verbrauch = 220 },
  { cle = "sucre",     nom = "Sucre",       prix =  50, categorie = "coloniales",   verbrauch = 220 },
  { cle = "chanvre",   nom = "Chanvre",     prix =  50, categorie = "matieres",     verbrauch = 220 },
  { cle = "tissu",     nom = "Textiles",       prix = 150, categorie = "manufactures", verbrauch = 110,
    recette = { { "coton", 1 } } },
  -- Le métal se fond au bois : c'est ce qui fait du bois la matière première la
  -- plus sollicitée de la carte, bien au-delà de ce que les habitants brûlent.
  { cle = "metal",     nom = "Métal",       prix =  83, categorie = "matieres",     verbrauch = 110,
    recette = { { "bois", 0.5 } } },
  { cle = "coton",     nom = "Coton",       prix =  50, categorie = "matieres",     verbrauch = 220 },
  { cle = "outils",    nom = "Objets métal",      prix = 200, categorie = "manufactures", verbrauch = 110,
    recette = { { "bois", 0.5 }, { "metal", 1 } } },
  -- TEINTURE, pas épice. Je l'avais nommée "Épices" parce que la vignette de
  -- PR3 s'appelle `spices.png`, et le tableau de consommation de l'utilisateur
  -- disait "Teinture" -- doute laissé ouvert pendant des jours. Sa table de
  -- textes tranche : ID_GUI_GOOD_11 vaut "Teintures". C'est l'indigo et la
  -- cochenille des colonies, et c'est ce que New Orleans produit.
  { cle = "teinture",  nom = "Teintures",   prix = 100, categorie = "coloniales",   verbrauch =  55, export = 11 },
  -- Café et cacao demandent un quart d'outil par unité : une plantation vit de ce
  -- que la forge lui envoie. C'est le seul lien de PR3 entre les denrées
  -- coloniales et l'industrie.
  { cle = "cafe",      nom = "Café",        prix = 140, categorie = "coloniales",   verbrauch = 110, export = 33,
    recette = { { "outils", 0.25 } } },
  { cle = "cacao",     nom = "Cacao",       prix = 140, categorie = "coloniales",   verbrauch = 110, export = 33,
    recette = { { "outils", 0.25 } } },
  { cle = "tabac",     nom = "Tabac",       prix = 100, categorie = "coloniales",   verbrauch = 110, export = 33 },
  { cle = "viande",    nom = "Viande",      prix = 300, categorie = "vivres",       verbrauch = 110,
    recette = { { "mais", 2 } } },
  { cle = "vetements", nom = "Vêtements",   prix = 450, categorie = "manufactures", verbrauch = 110,
    recette = { { "tissu", 1 }, { "teinture", 1 } } },
  { cle = "cordage",   nom = "Cordes",     prix = 150, categorie = "manufactures", verbrauch = 220,
    recette = { { "chanvre", 1 } } },
  { cle = "rhum",      nom = "Rhum",        prix = 267, categorie = "manufactures", verbrauch = 110,
    recette = { { "bois", 0.5 }, { "sucre", 1 } } },
  { cle = "pain",      nom = "Pain",        prix = 142, categorie = "vivres",       verbrauch = 220,
    recette = { { "ble", 0.5 }, { "sucre", 0.5 } } },
}

-- LES ATELIERS DE PR3, relus dans `constdata.dat` (voir `outils/pr3_constdata.py`) :
--
--   sortie       ce qu'un ouvrier produit par jour, en unités (2 000 le tonneau) ;
--                un atelier en a 25 ;
--   cout         `Bauplatzkosten`, le premier des trois crans ;
--   bois/briques `Baukosten Betriebe`, les matériaux du chantier, en tonneaux ;
--   duree        un octet égal à ce tonnage divisé par dix, lu comme des jours ;
--   quotient     `Bauquotient_Mod` : l'IA bâtit quand la demande de la carte
--                atteint ce multiple de sa production (voir `sim/construction.lua`).
local ATELIERS = {
  --             sortie   cout  bois briques duree quotient
  bois      = {    480,  8000,  20,  40,   6, 0.95 },
  briques   = {    480,  8000,  20,  40,   6, 0.95 },
  ble       = {    480,  8000,  20,  40,   6, 1.00 },
  fruits    = {    320,  8000,  20,  40,   6, 1.00 },
  mais      = {    320,  8000,  20,  40,   6, 1.00 },
  sucre     = {    320,  8000,  20,  40,   6, 1.00 },
  chanvre   = {    320,  8000,  20,  40,   6, 1.00 },
  tissu     = {    160, 12000,  40,  80,  12, 1.00 },
  metal     = {    240, 10000,  40,  80,  12, 1.00 },
  coton     = {    320,  8000,  30,  60,   9, 1.00 },
  outils    = {    160, 16000,  60, 120,  18, 1.00 },
  teinture  = {    160,  8000,  20,  40,   6, 1.00 },
  cafe      = {    160, 10000,  40,  80,  12, 1.00 },
  cacao     = {    160, 10000,  40,  80,  12, 1.00 },
  tabac     = {    160,  8000,  20,  40,   6, 1.00 },
  viande    = {     80, 12000,  40,  80,  12, 1.00 },
  vetements = {     80, 18000,  60, 120,  18, 1.00 },
  cordage   = {    160, 12000,  40,  80,  12, 1.00 },
  rhum      = {     80, 10000,  40,  80,  12, 1.00 },
  pain      = {    160, 10000,  40,  80,  12, 1.00 },
}
Marchandises.OUVRIERS_PAR_ATELIER = 25
Marchandises.UNITES_PAR_TONNEAU = 2000

-- LA QUALITÉ DE VIE, telle que PR3 la calcule (fin de `0x7BF8A0`) : chaque denrée
-- rapporte des points selon son stock rapporté au premier seuil de prix X1, et
-- les points sont pleins dès X1 atteint — « la fourniture de denrées a un impact
-- maximum sur la prospérité de la ville dès que le stock atteint au moins une
-- barre », dit le tutoriel. Quatre groupes, chacun plafonné à vingt points :
--
--   base    bois, briques, blé, fruits              7 × stock/X1, 7 au plus
--   fini    outils, viande, vêtements, cordage,
--           rhum, pain                              6 × stock/X1, 6 au plus
--   export  teintures, café, cacao, tabac           5 × stock/X1, 5 au plus
--   autre   maïs, sucre, chanvre, tissu, métal,
--           coton                                   5 × stock/X1, 6 au plus,
--                                                   × 1 ; 0,9 ; 0,8 selon la
--                                                   difficulté
--
-- Quatre-vingts points au mieux ; les bâtiments publics donnent le reste. Chaque
-- GROUPE est plafonné à vingt (`plafond_groupe`), si bien qu'un excédent d'une
-- denrée ne compense pas le manque d'une autre du même groupe.
Marchandises.GROUPES_QUALITE = {
  base   = { pente = 7, plafond_groupe = 20 },
  fini   = { pente = 6, plafond_groupe = 20 },
  export = { pente = 5, plafond_groupe = 20 },
  autre  = { pente = 5, plafond_groupe = 20 },
}
local GROUPE = {
  bois = "base", briques = "base", ble = "base", fruits = "base",
  outils = "fini", viande = "fini", vetements = "fini", cordage = "fini", rhum = "fini", pain = "fini",
  teinture = "export", cafe = "export", cacao = "export", tabac = "export",
}

-- LES FLÉAUX et les denrées qu'ils font consommer en plus (`0x7C2080`) : la peste
-- use le tissu et les vêtements, les sauterelles les fruits, le chanvre et le
-- pain, le feu le bois et les briques.
Marchandises.FLEAUX = {
  peste       = { "tissu", "vetements" },
  sauterelles = { "fruits", "chanvre", "pain" },
  feu         = { "bois", "briques" },
}


-- Ordre de FABRICATION : les matières premières d'abord, puis ce qui les
-- transforme. Sans cet ordre, une distillerie tournerait avec le sucre de la
-- veille au lieu de celui du matin, et la chaîne prendrait un jour de retard
-- par étage.
--
-- Il est calculé, pas écrit à la main : on répète en ne gardant que les biens
-- dont tous les intrants sont déjà placés. Une recette circulaire ferait donc
-- boucler à l'infini — d'où le garde-fou.
Marchandises.ordreFabrication = {}
do
  local place, reste = {}, {}
  for _, m in ipairs(Marchandises.liste) do reste[#reste + 1] = m end
  local garde = 0
  while #reste > 0 and garde < 50 do
    garde = garde + 1
    local suivant = {}
    for _, m in ipairs(reste) do
      local pret = true
      for _, ing in ipairs(m.recette or {}) do
        if not place[ing[1]] then pret = false end
      end
      if pret then
        Marchandises.ordreFabrication[#Marchandises.ordreFabrication + 1] = m
      else
        suivant[#suivant + 1] = m
      end
    end
    for _, m in ipairs(Marchandises.ordreFabrication) do place[m.cle] = true end
    reste = suivant
  end
  for _, m in ipairs(reste) do
    Marchandises.ordreFabrication[#Marchandises.ordreFabrication + 1] = m
  end
end

Marchandises.parCle = {}
Marchandises.ordre = {}
for i, m in ipairs(Marchandises.liste) do
  m.rang = i
  m.conso = m.verbrauch / Marchandises.ECHELLE
  m.export = (m.export or 0) / Marchandises.ECHELLE
  m.grundbedarf = m.grundbedarf or 5
  local a = ATELIERS[m.cle]
  m.sortie = a[1]
  -- Ce qu'un atelier livre par jour, en tonneaux.
  m.atelier = Marchandises.OUVRIERS_PAR_ATELIER * a[1] / Marchandises.UNITES_PAR_TONNEAU
  m.batiment = { cout = a[2], bois = a[3], briques = a[4], duree = a[5] }
  m.bauquotient = a[6]
  m.groupe = GROUPE[m.cle] or "autre"
  Marchandises.parCle[m.cle] = m
  Marchandises.ordre[#Marchandises.ordre + 1] = m.cle
end

-- LA NOURRITURE, telle que PR3 la déclare dans une de ses missions : « Blé,
-- Fruits, Maïs, Viande et Pain ». Cinq denrées, dont deux transformées. C'est
-- leur manque qui fait fondre une population, pas celui du tabac.
--
-- Il n'y en avait que quatre, sans le pain : tant que la démographie regardait
-- la PIRE d'entre elles, un pain fait au sucre aurait affamé toute ville loin
-- des cannes. PR3 ne compte pas ainsi — il faut que TROIS aliments manquent
-- ensemble pour la famine. Voir `jour()` dans `sim/economie.lua`.
Marchandises.vitales = { "ble", "fruits", "mais", "viande", "pain" }
for _, cle in ipairs(Marchandises.vitales) do
  Marchandises.parCle[cle].vitale = true
end

function Marchandises.get(cle)
  return Marchandises.parCle[cle]
end

-- Ce qu'une ville tire de ses entrepôts chaque jour, pour mille habitants :
-- les habitants, et l'Europe par-dessus pour les denrées qui s'exportent.
function Marchandises.besoin(m)
  return m.conso + m.export
end

return Marchandises
