-- Les vingt marchandises de Port Royale 3.
--
-- La liste est la sienne, et les PRIX DE BASE aussi : bois 33, blé 33, sucre 50,
-- métal 83, tissu 150, outils 200, rhum 267, viande 300, vêtements 450. Ce sont
-- ses vrais chiffres, relevés sur le barème publié par ses joueurs, et ils
-- donnent une échelle bien plus raide que celle que j'avais devinée — un
-- tonneau de rhum y vaut huit fois un quintal de blé.
--
-- Le projet est parti de la liste de Port Royale 1 (21 denrées, dont poisson,
-- sel, vin et poterie). PR3 a une autre gamme : ni poisson ni sel, mais du pain,
-- du café, des épices et du cordage. On a basculé sur la sienne le jour où les
-- vingt vignettes sont arrivées — c'est la seule façon d'avoir une icône pour
-- chaque ligne, et une économie qui se raconte d'une seule voix.
--
-- `conso` est en tonnes par jour et par millier d'habitants, et les chiffres
-- viennent du jeu : son `goods.js` pose `CONSUMPTION_COEF = BaseCost * 0,00275`
-- par habitant et par jour. On les a multipliés par mille, rien de plus.
--
-- Mes valeurs devinées étaient non seulement deux fois et demie trop basses en
-- volume, mais surtout mal PONDÉRÉES entre elles : je mettais les briques à
-- 0,32 là où c'est, avec le blé, la denrée la plus consommée du jeu — et le
-- cordage à 0,14 pour une valeur réelle de 1,10. Aucun réglage de production
-- n'aurait rattrapé ça.
--
-- C'est ce qui lie l'économie à la démographie : une ville qui grandit consomme
-- davantage, donc fait monter ses prix, donc appelle le marchand.

local Marchandises = {}

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
Marchandises.liste = {
  { cle = "bois",      nom = "Bois",        prix =  33, categorie = "matieres",     conso = 1.375 },
  { cle = "briques",   nom = "Briques",     prix =  33, categorie = "matieres",     conso = 2.750 },
  { cle = "ble",       nom = "Blé",         prix =  33, categorie = "vivres",       conso = 2.750 },
  { cle = "fruits",    nom = "Fruits",      prix =  50, categorie = "vivres",       conso = 2.200 },
  { cle = "mais",      nom = "Maïs",        prix =  50, categorie = "vivres",       conso = 1.100 },
  { cle = "sucre",     nom = "Sucre",       prix =  50, categorie = "coloniales",   conso = 1.100 },
  { cle = "chanvre",   nom = "Chanvre",     prix =  50, categorie = "matieres",     conso = 1.100 },
  { cle = "tissu",     nom = "Tissu",       prix = 150, categorie = "manufactures", conso = 0.550,
    recette = { { "coton", 2 } } },
  { cle = "metal",     nom = "Métal",       prix =  83, categorie = "matieres",     conso = 0.550 },
  { cle = "coton",     nom = "Coton",       prix =  50, categorie = "matieres",     conso = 1.100 },
  { cle = "outils",    nom = "Outils",      prix = 200, categorie = "manufactures", conso = 0.550,
    recette = { { "bois", 1 }, { "metal", 2 } } },
  -- TEINTURE, pas épice. Je l'avais nommée "Épices" parce que la vignette de
  -- PR3 s'appelle `spices.png`, et le tableau de consommation de l'utilisateur
  -- disait "Teinture" -- doute laissé ouvert pendant des jours. Sa table de
  -- textes tranche : ID_GUI_GOOD_11 vaut "Teintures". C'est l'indigo et la
  -- cochenille des colonies, et c'est ce que New Orleans produit.
  { cle = "teinture",  nom = "Teintures",   prix = 100, categorie = "coloniales",   conso = 0.330 },
  { cle = "cafe",      nom = "Café",        prix = 140, categorie = "coloniales",   conso = 0.715 },
  { cle = "cacao",     nom = "Cacao",       prix = 140, categorie = "coloniales",   conso = 0.715 },
  { cle = "tabac",     nom = "Tabac",       prix = 100, categorie = "coloniales",   conso = 0.715 },
  { cle = "viande",    nom = "Viande",      prix = 300, categorie = "vivres",       conso = 0.550,
    recette = { { "mais", 2 } } },
  { cle = "vetements", nom = "Vêtements",   prix = 450, categorie = "manufactures", conso = 0.550,
    recette = { { "tissu", 1 }, { "teinture", 1 } } },
  { cle = "cordage",   nom = "Cordage",     prix = 150, categorie = "manufactures", conso = 1.100,
    recette = { { "chanvre", 2 } } },
  { cle = "rhum",      nom = "Rhum",        prix = 267, categorie = "manufactures", conso = 0.550,
    recette = { { "sucre", 1 }, { "bois", 0.5 } } },
  { cle = "pain",      nom = "Pain",        prix = 142, categorie = "vivres",       conso = 1.100,
    recette = { { "ble", 1 }, { "mais", 1 } } },
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
  Marchandises.parCle[m.cle] = m
  Marchandises.ordre[#Marchandises.ordre + 1] = m.cle
end

-- Les vivres sont à part : c'est leur manque qui fait fondre une population,
-- pas celui du tabac. La croissance démographique ne regarde que celles-là.
Marchandises.vitales = { "ble", "fruits", "mais", "viande" }
for _, cle in ipairs(Marchandises.vitales) do
  Marchandises.parCle[cle].vitale = true
end

function Marchandises.get(cle)
  return Marchandises.parCle[cle]
end

return Marchandises
