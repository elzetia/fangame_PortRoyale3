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
-- `verbrauch` est la table de consommation de PR3 (`Warenverbrauch`), recopiée
-- telle quelle. `conso`, qu'on en tire, est en tonnes par jour et par millier
-- d'habitants : verbrauch / ECHELLE.
--
-- L'unité de PR3 n'est pas établie, et l'échelle est donc un choix. Elle est
-- fixée par ses NAVIRES : un sloop y porte deux cents tonneaux, une flûte
-- marchande huit cents (voir `sim/navires.lua`). Pour qu'une cale de sloop pèse
-- sur un marché ce qu'elle y pèse dans le jeu — un bon tiers de l'entrepôt d'une
-- denrée courante, pas trois fois son contenu —, il faut une consommation quatre
-- fois plus forte que celle qu'on jouait avec un sloop de cinquante tonneaux :
-- une échelle de 50, et non plus de 200. Les rapports entre denrées, eux, ne
-- dépendent pas de ce choix.
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

Marchandises.ECHELLE = 50

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
-- LES RECETTES SONT CELLES DE PR3, relues dans la même table que les prix : les
-- index des intrants, puis leur quantité par unité produite, en trente-deuxièmes.
-- Les miennes s'en écartaient sur cinq lignes — le pain fait au maïs au lieu du
-- sucre, la viande à deux maïs au lieu de quatre, les vêtements à moitié prix de
-- matière, le rhum à moitié de sucre, et le métal, le café et le cacao tirés de
-- rien. Celles de PR3 ont une propriété que les miennes n'avaient pas : ses
-- chaînes sont équilibrées UNE POUR UNE. Une ferme de maïs nourrit exactement
-- une manufacture de viande, une plantation de coton exactement un tissage.
Marchandises.liste = {
  { cle = "bois",      nom = "Bois",        prix =  33, categorie = "matieres",     verbrauch = 275 },
  { cle = "briques",   nom = "Briques",     prix =  33, categorie = "matieres",     verbrauch = 550 },
  { cle = "ble",       nom = "Blé",         prix =  33, categorie = "vivres",       verbrauch = 550 },
  { cle = "fruits",    nom = "Fruits",      prix =  50, categorie = "vivres",       verbrauch = 440 },
  { cle = "mais",      nom = "Maïs",        prix =  50, categorie = "vivres",       verbrauch = 220 },
  { cle = "sucre",     nom = "Sucre",       prix =  50, categorie = "coloniales",   verbrauch = 220 },
  { cle = "chanvre",   nom = "Chanvre",     prix =  50, categorie = "matieres",     verbrauch = 220 },
  { cle = "tissu",     nom = "Tissu",       prix = 150, categorie = "manufactures", verbrauch = 110,
    recette = { { "coton", 2 } } },
  -- Le métal se fond au bois : c'est ce qui fait du bois la matière première la
  -- plus sollicitée de la carte, bien au-delà de ce que les habitants brûlent.
  { cle = "metal",     nom = "Métal",       prix =  83, categorie = "matieres",     verbrauch = 110,
    recette = { { "bois", 1 } } },
  { cle = "coton",     nom = "Coton",       prix =  50, categorie = "matieres",     verbrauch = 220 },
  { cle = "outils",    nom = "Outils",      prix = 200, categorie = "manufactures", verbrauch = 110,
    recette = { { "bois", 1 }, { "metal", 2 } } },
  -- TEINTURE, pas épice. Je l'avais nommée "Épices" parce que la vignette de
  -- PR3 s'appelle `spices.png`, et le tableau de consommation de l'utilisateur
  -- disait "Teinture" -- doute laissé ouvert pendant des jours. Sa table de
  -- textes tranche : ID_GUI_GOOD_11 vaut "Teintures". C'est l'indigo et la
  -- cochenille des colonies, et c'est ce que New Orleans produit.
  { cle = "teinture",  nom = "Teintures",   prix = 100, categorie = "coloniales",   verbrauch =  55, export = 11 },
  -- Café et cacao demandent un demi-outil par unité : une plantation vit de ce
  -- que la forge lui envoie. C'est le seul lien de PR3 entre les denrées
  -- coloniales et l'industrie.
  { cle = "cafe",      nom = "Café",        prix = 140, categorie = "coloniales",   verbrauch = 110, export = 33,
    recette = { { "outils", 0.5 } } },
  { cle = "cacao",     nom = "Cacao",       prix = 140, categorie = "coloniales",   verbrauch = 110, export = 33,
    recette = { { "outils", 0.5 } } },
  { cle = "tabac",     nom = "Tabac",       prix = 100, categorie = "coloniales",   verbrauch = 110, export = 33 },
  { cle = "viande",    nom = "Viande",      prix = 300, categorie = "vivres",       verbrauch = 110,
    recette = { { "mais", 4 } } },
  { cle = "vetements", nom = "Vêtements",   prix = 450, categorie = "manufactures", verbrauch = 110,
    recette = { { "tissu", 2 }, { "teinture", 2 } } },
  { cle = "cordage",   nom = "Cordage",     prix = 150, categorie = "manufactures", verbrauch = 220,
    recette = { { "chanvre", 2 } } },
  { cle = "rhum",      nom = "Rhum",        prix = 267, categorie = "manufactures", verbrauch = 110,
    recette = { { "bois", 1 }, { "sucre", 2 } } },
  { cle = "pain",      nom = "Pain",        prix = 142, categorie = "vivres",       verbrauch = 220,
    recette = { { "ble", 1 }, { "sucre", 1 } } },
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
