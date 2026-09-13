-- L'économie des villes : stocks, production, consommation, prix.
--
-- Le modèle est celui de Port Royale 3, relu dans le code de son exécutable
-- (voir `outils/PR3_TECHNIQUE.md`, §7, et `sim/ECONOMIE_PR3.md`, §10) : chaque
-- ville produit quelques marchandises, les consomme toutes en proportion de sa
-- population, et son prix ne dépend que de ce qu'il lui en reste en entrepôt,
-- rapporté à QUATRE SEUILS propres à la ville et à la denrée. C'est l'écart entre
-- deux villes qui fait le métier de marchand.
--
-- Les unités sont celles du jeu : des tonneaux, par jour.
--
-- Lua pur : ce fichier ne connaît pas Godot.

local Archipel     = require("sim.archipel")
local Marchandises = require("sim.marchandises")

local Economie = {}

-- LES SEUILS DE PRIX, en jours de besoins. PR3 les recalcule pour chaque denrée
-- de chaque ville (fonction `0x7BF8A0` de son exécutable) :
--
--   t  = besoin de dix jours : habitants, export et intrants de ses ateliers
--   X1 = Grundbedarf + 3 t − 1,5 × min(production de dix jours, t)   (au moins 1)
--   X2 = X1 + t
--   X3 = X2 + production de vingt jours + 5
--   X4 = X3 + t
--
-- Une ville vise donc un stock profond : les prix de pénurie commencent sous
-- trente jours de besoins, le plateau s'étend sur sa réserve de production.
-- Celle-ci vaut 20, 10 ou 4 jours selon un réglage de partie ; 20 est le premier
-- cran, celui du barème publié.
--
-- On en avait deviné une version plate — des fractions fixes d'une réserve de
-- trente jours. Elle tenait la forme de la courbe mais pas sa profondeur : une
-- ville qui produit la denrée ne se distinguait pas d'une ville qui l'importe.
local JOURS_BESOIN = 10
local JOURS_PRODUCTION = 20
local CREDIT_PRODUCTEUR = 1.5

-- PR3 applique la même courbe à l'achat et à la vente, sans commission : un lot
-- acheté puis revendu aussitôt sur place rend exactement ce qu'il a coûté. Le
-- marché tient seul l'écart entre deux villes. L'ancienne marge de 9 % n'avait
-- pas d'équivalent dans le jeu.
local MARGE = 0.0

-- Production quotidienne, en tonneaux.
--
-- Ce n'est plus une quantité acquise mais une CAPACITÉ : ce que la ville
-- produirait si elle avait de quoi. Depuis que les recettes existent, un
-- atelier sans intrants chôme.
--
-- LES VOCATIONS SONT CELLES DE PORT ROYALE 3, et elles ne sont plus ecrites a
-- la main : chaque ville de `sim/villes_pr3.lua` porte les CINQ marchandises
-- que le jeu lui fait produire, relevees dans son `ini/constdata.dat`. La
-- Havane fait coton, ble, briques, rhum et tabac ; New Orleans sucre, tissu,
-- briques, pain et teintures. Rien de tout cela n'est de mon invention, et
-- c'est ce qui donne a la carte sa structure : le golfe ne produit pas ce que
-- produisent les Petites Antilles.
--
-- Ce qui reste a moi, ce sont les DEBITS. PR3 les fait dependre des batiments
-- que le joueur construit, ce que ce jeu-ci ne simule pas encore ; on les
-- calcule donc :
--
--   1. on remonte la chaine de fabrication A L'ENVERS pour connaitre la
--      demande totale de la carte -- celle des habitants PLUS celle des
--      ateliers, qui mangent des intrants que quelqu'un doit produire ;
--   2. on ajoute la marge, et de quoi croitre ;
--   3. on repartit ce total entre les villes qui produisent la marchandise,
--      AU PRORATA DE LEUR POPULATION -- une grande ville produit plus.
--
-- La regle a ne pas casser : sur la carte entiere, la production de chaque
-- marchandise couvre a peu pres sa consommation. Une seule denree durablement
-- deficitaire et tout le monde s'affame, ce qu'aucune manoeuvre du joueur ne
-- peut redresser.
--
-- En revanche AUCUNE ville n'est autosuffisante, et c'est voulu : cinq
-- marchandises sur vingt. C'est cet ecart, et lui seul, qui fait le metier de
-- marchand.

-- De quoi croitre. Sans cette marge, les villes butent des le premier mois sur
-- le plafond demographique et ne grandissent jamais -- or c'est la seule
-- recompense visible du travail du joueur.
local CROISSANCE = 1.20
local MARGE_CHAINE = 1.06

-- La viande et le pain reçoivent de quoi garder du stock : ce sont les deux
-- aliments transformés, ceux qu'une ville encore servie garde en dernier, et
-- ce sont les trois récoltes qui font la limite -- donc un cours qui bouge et une
-- route qui vit.
local AISANCE = { viande = 1.25, pain = 1.20 }

local PRODUCTIONS
do
  local population = 0
  for _, port in ipairs(Archipel.ports) do population = population + port.habitants end

  -- Qui consomme quoi, et en quelle quantite, pour remonter la chaine.
  local consommateurs = {}
  for _, m in ipairs(Marchandises.liste) do
    for _, ing in ipairs(m.recette or {}) do
      consommateurs[ing[1]] = consommateurs[ing[1]] or {}
      consommateurs[ing[1]][#consommateurs[ing[1]] + 1] = { m.cle, ing[2] }
    end
  end

  -- A l'envers de l'ordre de fabrication : le rhum avant le sucre, sinon on ne
  -- saurait pas combien de sucre il faut.
  local cible = {}
  for i = #Marchandises.ordreFabrication, 1, -1 do
    local m = Marchandises.ordreFabrication[i]
    local besoin = Marchandises.besoin(m) * population * CROISSANCE / 1000.0
    for _, c in ipairs(consommateurs[m.cle] or {}) do
      besoin = besoin + (cible[c[1]] or 0) * c[2]
    end
    cible[m.cle] = besoin * MARGE_CHAINE * (AISANCE[m.cle] or 1.0)
  end

  -- LE SOCLE VIVRIER. Les cinq marchandises de PR3 sont la production
  -- COMMERCIALE d'une ville, pas son potager : aucune colonie ne vivait de ce
  -- qu'elle vendait seulement. Sans ce socle, une ville qui n'a aucun vivre
  -- dans ses cinq n'en produit pas un gramme et fond jusqu'au plancher en cinq
  -- ans -- ce qui est arrive aux deux tiers de la carte au premier essai.
  --
  -- Chaque ville couvre donc cette part de ses PROPRES besoins vitaux. Le
  -- reglage est auto-stabilisant : la production est fixe, la consommation
  -- suit la population, donc une ville jamais ravitaillee decroit jusqu'a
  -- cette part de sa taille et s'y arrete. Elle ne meurt pas, elle attend le
  -- marchand.
  local AUTONOMIE_VIVRES = 0.85

  -- Le socle doit couvrir les INTRANTS de ses propres ateliers vitaux, pas
  -- seulement ce que les habitants mangent : une ville a qui l'on donne 85 % de
  -- sa viande sans lui donner le mais qui la fait n'en produit pas un gramme.
  --
  -- Seuls les vivres faits DE VIVRES y entrent. Le pain de PR3 se pétrit au
  -- sucre : une ville sans canne ne peut pas s'en faire un potager. Son pain
  -- vient par la mer, comme dans le jeu.
  local socle = {}
  for _, port in ipairs(Archipel.ports) do
    local t = {}
    for _, cle in ipairs(Marchandises.vitales) do
      local m = Marchandises.get(cle)
      local de_vivres = true
      for _, ing in ipairs(m.recette or {}) do
        if not Marchandises.get(ing[1]).vitale then de_vivres = false end
      end
      if de_vivres then
        t[cle] = AUTONOMIE_VIVRES * m.conso * port.habitants / 1000.0
      end
    end
    for i = #Marchandises.ordreFabrication, 1, -1 do
      local m = Marchandises.ordreFabrication[i]
      if t[m.cle] then
        for _, ing in ipairs(m.recette or {}) do
          if t[ing[1]] then t[ing[1]] = t[ing[1]] + t[m.cle] * ing[2] end
        end
      end
    end
    socle[port.cle] = t
  end

  -- Ce que le socle couvre deja se retranche de la cible : sinon on produirait
  -- deux fois le meme ble et la carte croulerait sous les vivres.
  local deja = {}
  for _, port in ipairs(Archipel.ports) do
    for cle, q in pairs(socle[port.cle]) do deja[cle] = (deja[cle] or 0) + q end
  end

  -- Le reste, au prorata de la population des villes qui la produisent.
  local poids = {}
  for _, port in ipairs(Archipel.ports) do
    for _, cle in ipairs(port.produits or {}) do
      poids[cle] = (poids[cle] or 0) + port.habitants
    end
  end

  PRODUCTIONS = {}
  for _, port in ipairs(Archipel.ports) do
    local t = {}
    for cle, q in pairs(socle[port.cle]) do t[cle] = q end
    for _, cle in ipairs(port.produits or {}) do
      if poids[cle] and poids[cle] > 0 then
        local reste = cible[cle] - (deja[cle] or 0)
        if reste < 0 then reste = 0 end
        t[cle] = (t[cle] or 0) + reste * port.habitants / poids[cle]
      end
    end
    PRODUCTIONS[port.cle] = t
  end
end

Economie.villes = {}
local reste_jour = 0.0


local function borner(v, mini, maxi)
  if v < mini then return mini end
  if v > maxi then return maxi end
  return v
end


-- Consommation quotidienne d'une ville pour une marchandise, en tonneaux : ses
-- habitants, et l'Europe par-dessus pour les denrées qui s'exportent. C'est ce
-- qui sort de l'entrepôt sans rien produire en échange.
local function consommation(ville, m)
  return Marchandises.besoin(m) * ville.habitants / 1000.0
end


-- Ce que la ville tire de ses entrepôts chaque jour pour cette denrée : ses
-- habitants et l'export, plus les intrants de SES ateliers. C'est le besoin que
-- PR3 compte pour ses seuils ; sans la part des ateliers, une forge ne signalait
-- jamais qu'elle manquait de métal.
local function besoin_jour(ville, m)
  return consommation(ville, m) + ((ville.ateliers or {})[m.cle] or 0)
end


-- Les cinq bornes de la courbe de prix : le stock nul, puis X1…X4.
local function seuils(ville, m)
  local t = besoin_jour(ville, m) * JOURS_BESOIN
  local prod = ville.production[m.cle] or 0
  local x1 = m.grundbedarf + 3 * t - CREDIT_PRODUCTEUR * math.min(prod * JOURS_BESOIN, t)
  if x1 < 1 then x1 = 1 end
  local x2 = x1 + t
  local x3 = x2 + prod * JOURS_PRODUCTION + 5
  local x4 = x3 + t
  return { 0, x1, x2, x3, x4 }
end


-- Le stock « normal » d'une ville : le début du plateau à 120 %, X2. C'est le
-- chiffre que le comptoir montre en regard du stock.
local function reference(ville, m)
  return seuils(ville, m)[3]
end


-- Les coefficients de prix de PR3 (table `Preisfaktoren`) : trois crans, chacun
-- avec une série normale et une série « pénurie » plus raide dans le haut. Le
-- premier cran est celui du barème publié (200, 180, 120, 80). PR3 bascule sur
-- la série « pénurie » quand un indicateur d'état de la ville est levé ; son
-- déclencheur n'a pas été lu, elle reste éteinte.
Economie.PREISFAKTOREN = {
  { normal = { 2.0, 1.8, 1.2, 1.2, 0.8 }, penurie = { 3.0, 2.7, 1.2, 1.2, 0.8 } },
  { normal = { 1.8, 1.6, 1.2, 1.2, 0.7 }, penurie = { 2.7, 2.4, 1.2, 1.2, 0.7 } },
  { normal = { 1.6, 1.4, 1.1, 1.1, 0.6 }, penurie = { 2.4, 2.1, 1.1, 1.1, 0.6 } },
}
Economie.REGLAGE_PRIX = 1
Economie.PENURIE = false

local function coefficients()
  local jeu = Economie.PREISFAKTOREN[Economie.REGLAGE_PRIX] or Economie.PREISFAKTOREN[1]
  return Economie.PENURIE and jeu.penurie or jeu.normal
end


-- Le facteur à un niveau de stock, et le segment où il tombe — qui EST le nombre
-- de barres d'abondance (fonction `0x765310` du jeu). Les deux sortent du même
-- calcul : la jauge et le cours ne peuvent pas se contredire à l'écran.
local function facteur(stock, s)
  local c = coefficients()
  if stock <= 0 then return c[1], 0 end
  for i = 1, 4 do
    if stock < s[i + 1] then
      local t = (stock - s[i]) / (s[i + 1] - s[i])
      return c[i] + (c[i + 1] - c[i]) * t, i - 1
    end
  end
  return c[5], 4
end


-- L'intégrale du facteur entre deux niveaux de stock, a < b.
--
-- C'est le prix de PR3 (`0x856780`) : non pas le cours au stock de départ, mais
-- la MOYENNE de la courbe sur toute la quantité échangée. Vider un entrepôt fait
-- monter le prix tonneau après tonneau, et c'est ce qui empêche d'emporter mille
-- tonneaux au cours du premier. La part qui passerait sous zéro — acheter plus
-- que le stock — se compte au premier coefficient, le plus cher.
local function integrale(a, b, s, c)
  local total = 0.0
  if a < 0 then
    local fin = math.min(b, 0)
    total = total + (fin - a) * c[1]
    a = fin
    if a >= b then return total end
  end
  for i = 1, 4 do
    local bas, haut = s[i], s[i + 1]
    local x0, x1 = math.max(a, bas), math.min(b, haut)
    if x1 > x0 and haut > bas then
      local f0 = c[i] + (c[i + 1] - c[i]) * (x0 - bas) / (haut - bas)
      local f1 = c[i] + (c[i + 1] - c[i]) * (x1 - bas) / (haut - bas)
      total = total + (x1 - x0) * (f0 + f1) * 0.5
    end
  end
  if b > s[5] then
    total = total + (b - math.max(a, s[5])) * c[5]
  end
  return total
end


-- Nombre de barres d'abondance, de 0 à 4 : le nombre de seuils franchis.
--
--   0 barre  : 200 à 180 %      3 barres : 120 à 80 %
--   1 barre  : 180 à 120 %      4 barres : 80 %
--   2 barres : 120 %
--
-- `delta` déplace le stock avant le calcul, sans rien changer à la ville : le
-- comptoir s'en sert pour montrer, pendant qu'on tire la jauge, l'abondance que
-- l'échange LAISSERAIT.
function Economie.barres(cle_ville, cle_m, delta)
  local ville = Economie.ville(cle_ville)
  local m = Marchandises.get(cle_m)
  if not ville or not m then return 0 end
  local stock = (ville.stock[cle_m] or 0) + (delta or 0)
  if stock < 0 then stock = 0 end
  local _, barres = facteur(stock, seuils(ville, m))
  return barres
end


function Economie.reinitialiser()
  Economie.villes = {}
  reste_jour = 0.0
  for _, port in ipairs(Archipel.ports) do
    local ville = {
      cle = port.cle,
      nom = port.nom,
      habitants = port.habitants,
      production = PRODUCTIONS[port.cle] or {},
      stock = {},
      faim = -3,
      penurie = -12,
    }
    -- Ce que ses ateliers tirent de ses entrepôts chaque jour, à pleine
    -- capacité : la part « manufactures » de sa demande. La production est
    -- fixe : on la compte une fois.
    ville.ateliers = {}
    for cle, q in pairs(ville.production) do
      for _, ing in ipairs(Marchandises.get(cle).recette or {}) do
        ville.ateliers[ing[1]] = (ville.ateliers[ing[1]] or 0) + q * ing[2]
      end
    end
    -- La graine du bourg, tirée des lettres de sa clé : deux villes dont la clé a
    -- la même longueur ne partent pas avec les mêmes entrepôts.
    local graine = 0
    for k = 1, string.len(port.cle) do
      graine = (graine * 31 + string.byte(port.cle, k)) % 997
    end

    for i, m in ipairs(Marchandises.liste) do
      -- On démarre chaque entrepôt autour de son stock normal, avec un écart
      -- déterministe et LARGE d'une denrée à l'autre : une partie qui commence à
      -- l'équilibre parfait n'offre aucune occasion, et la jauge ne dirait rien
      -- au joueur le premier matin.
      local biais = 0.30 + 1.05 * (((i * 37 + graine) % 100) / 100.0)
      if ville.production[m.cle] then biais = biais + 0.40 end
      ville.stock[m.cle] = reference(ville, m) * biais
    end
    Economie.villes[port.cle] = ville
  end
end


function Economie.ville(cle)
  if not next(Economie.villes) then Economie.reinitialiser() end
  return Economie.villes[cle]
end


-- Emplois, fabriques et logements — tout se déduit du nombre d'habitants.
--
-- Port Royale 3 donne ses chiffres dans son tutoriel, et son exécutable les
-- confirme : chaque atelier a 25 ouvriers (`Produktion`), chaque emploi fait
-- quatre citoyens, chaque maison loge cent locataires (`Renter`).
--
--   « Les marchands d'une ville construisent toujours de nouvelles maisons
--     lorsque les maisons existantes sont remplies à 80%. »
--
-- Le défaut de ce seuil dans le code est 65 % (`FillRate`) ; sa vraie valeur n'a
-- pas été retrouvée, et on garde celle du tutoriel.
--
-- Rien de tout cela n'est simulé bâtiment par bâtiment. La population reste la
-- seule variable d'état ; ces nombres en sont des lectures.
Economie.EMPLOIS_PAR_FABRIQUE = 25
Economie.CITOYENS_PAR_EMPLOI  = 4
Economie.LOGES_PAR_MAISON     = 100
Economie.SEUIL_CONSTRUCTION   = 0.80

function Economie.demographie(cle)
  local v = Economie.ville(cle)
  local h = v and v.habitants or 0
  if h < 1 then
    return { habitants = 0, ouvriers = 0, fabriques = 0, maisons = 0, occupation = 0.0 }
  end

  local ouvriers  = math.floor(h / Economie.CITOYENS_PAR_EMPLOI + 0.5)
  local fabriques = math.floor(ouvriers / Economie.EMPLOIS_PAR_FABRIQUE + 0.5)
  if fabriques < 1 then fabriques = 1 end

  -- Le plus petit nombre de maisons qui garde la ville sous le seuil.
  local par_maison = Economie.LOGES_PAR_MAISON * Economie.SEUIL_CONSTRUCTION
  local maisons = math.ceil(h / par_maison)
  if maisons < 1 then maisons = 1 end

  return {
    habitants  = math.floor(h + 0.5),
    ouvriers   = ouvriers,
    fabriques  = fabriques,
    maisons    = maisons,
    occupation = h / (maisons * Economie.LOGES_PAR_MAISON),
  }
end


-- Prix unitaire moyen d'une transaction : la moyenne de la courbe sur le lot,
-- comme PR3. Pour une quantité nulle, le cours au stock présent.
function Economie.cotation(cle_ville, cle_m, quantite, sens)
  local ville = Economie.ville(cle_ville)
  local m = Marchandises.get(cle_m)
  if not ville or not m then return nil end

  quantite = quantite or 0
  local stock = ville.stock[cle_m] or 0
  local s = seuils(ville, m)
  local f
  if quantite <= 0 or (sens ~= "achat" and sens ~= "vente") then
    f = facteur(stock, s)
  elseif sens == "achat" then
    f = integrale(stock - quantite, stock, s, coefficients()) / quantite
  else
    f = integrale(stock, stock + quantite, s, coefficients()) / quantite
  end

  local base = m.prix * f
  if sens == "achat" then
    return base * (1 + MARGE)
  elseif sens == "vente" then
    return base * (1 - MARGE)
  end
  return base
end


-- L'etat d'UNE ligne, sans construire les vingt autres.
--
-- `Economie.marche` batit un tableau complet : vingt lignes, quatre cotations
-- chacune. A soixante villes, un convoi qui cherche ou acheter son ble
-- interrogeait soixante marches entiers ; cette porte-ci en coute trois.
function Economie.ligne(cle_ville, cle_m)
  local ville = Economie.ville(cle_ville)
  local m = Marchandises.get(cle_m)
  if not ville or not m then return nil end
  local stock = ville.stock[cle_m] or 0
  local s = seuils(ville, m)
  local _, barres = facteur(stock, s)
  local prod = ville.production[cle_m] or 0
  return {
    cle = cle_m,
    stock = stock,
    reference = s[3],
    seuils = s,
    barres = barres,
    production = prod,
    solde = ((ville.rendement or {})[cle_m] or prod) - consommation(ville, m),
  }
end


-- Tableau du marché d'une ville : une ligne par marchandise.
-- `lot` est la quantité que le joueur envisage d'échanger. Les colonnes de
-- prix sont données pour l'unité ET pour ce lot : c'est le second chiffre qu'il
-- paiera vraiment, et l'écart entre les deux est la profondeur du marché.
function Economie.marche(cle_ville, lot)
  local ville = Economie.ville(cle_ville)
  if not ville then return nil end
  lot = lot or 1
  if lot < 1 then lot = 1 end
  local lignes = {}
  for _, m in ipairs(Marchandises.liste) do
    local prod = ville.production[m.cle] or 0
    lignes[#lignes + 1] = {
      cle = m.cle,
      nom = m.nom,
      categorie = m.categorie,
      stock = ville.stock[m.cle] or 0,
      reference = reference(ville, m),
      production = prod,
      consommation = consommation(ville, m),
      achat = Economie.cotation(cle_ville, m.cle, 1, "achat"),
      vente = Economie.cotation(cle_ville, m.cle, 1, "vente"),
      achat_lot = Economie.cotation(cle_ville, m.cle, lot, "achat"),
      vente_lot = Economie.cotation(cle_ville, m.cle, lot, "vente"),
      -- Tendance : ce que la ville gagne ou perd chaque jour, à partir du
      -- rendement RÉEL de la veille : un atelier à l'arrêt faute d'intrants doit
      -- se voir.
      solde = ((ville.rendement or {})[m.cle] or prod) - consommation(ville, m),
      capacite = prod,
      barres = Economie.barres(cle_ville, m.cle),
    }
  end
  return lignes
end


-- Retire de la marchandise à la ville. Renvoie la quantité réellement servie et
-- la somme due.
--
-- Comme dans PR3, rien n'empêche de vider l'entrepôt : le prix s'en charge, qui
-- monte vers le double du prix standard à mesure que le stock fond. L'ancien
-- plancher, qui gardait toujours un fond de cale à la ville, n'avait pas
-- d'équivalent dans le jeu.
function Economie.acheter(cle_ville, cle_m, quantite)
  local ville = Economie.ville(cle_ville)
  local m = Marchandises.get(cle_m)
  if not ville or not m or quantite <= 0 then return 0, 0 end

  local dispo = ville.stock[cle_m] or 0
  if dispo <= 0 then return 0, 0 end
  if quantite > dispo then quantite = dispo end

  local prix = Economie.cotation(cle_ville, cle_m, quantite, "achat")
  ville.stock[cle_m] = ville.stock[cle_m] - quantite
  return quantite, prix * quantite
end


-- Vend à la ville. Renvoie la quantité acceptée et la somme perçue.
function Economie.vendre(cle_ville, cle_m, quantite)
  local ville = Economie.ville(cle_ville)
  local m = Marchandises.get(cle_m)
  if not ville or not m or quantite <= 0 then return 0, 0 end

  local prix = Economie.cotation(cle_ville, cle_m, quantite, "vente")
  ville.stock[cle_m] = (ville.stock[cle_m] or 0) + quantite
  return quantite, prix * quantite
end


-- LA FAIM DE PR3, lue dans sa consommation quotidienne (`0x7C2080`). Chaque
-- denrée non servie ce jour-là incrémente deux compteurs :
--
--   · les ALIMENTS manquants, à partir de −3 ;
--   · TOUTES les denrées manquantes, à partir de −12.
--
-- La ville décline dès qu'un compteur passe au-dessus de zéro : plus de trois
-- aliments sur cinq, ou plus de douze denrées sur vingt. C'est le tutoriel qui
-- avait raison (« si 3 de ces produits font défaut simultanément »). Une ville de
-- moins de 300 habitants a son compteur forcé à −10 : elle ne connaît pas la
-- famine.
local DEPART_FAIM = -3
local DEPART_PENURIE = -12
local SANS_FAMINE = 300

-- Ce que PR3 fait de ces compteurs passe par sa prospérité, dont la vitesse n'a
-- pas été lue. Les taux ci-dessous sont les nôtres : on repeuple une colonie
-- lentement, on la vide en une saison.
local CROISSANCE_MAX = 0.0008
local DECLIN_PAR_ALIMENT = 0.0015
local DECLIN_PAR_DENREE = 0.0005
local DECLIN_MAX = 0.0050


-- Une journée de vie économique.
--
-- L'ORDRE des trois étapes est le coeur du modèle :
--
--   1. les récoltes et les mines livrent — elles ne dépendent de rien ;
--   2. les habitants se servent ;
--   3. les ateliers transforment CE QUI RESTE.
--
-- Mettre les ateliers avant les habitants faisait mourir New Orléans en un an :
-- sa boulangerie mangeait le blé de ses propres gens. Les ateliers vivent du
-- surplus, jamais du nécessaire.
local function jour(ville)
  ville.rendement = ville.rendement or {}

  -- 1. Ce qui sort de terre.
  for _, m in ipairs(Marchandises.ordreFabrication) do
    if not m.recette then
      local capacite = ville.production[m.cle] or 0
      ville.stock[m.cle] = (ville.stock[m.cle] or 0) + capacite
      ville.rendement[m.cle] = capacite
    end
  end

  -- 2. Les habitants, et les compteurs de faim.
  local faim, penurie = DEPART_FAIM, DEPART_PENURIE
  local vivres_servis, vivres = 0, 0
  for _, m in ipairs(Marchandises.liste) do
    local dispo = ville.stock[m.cle] or 0
    local demande = consommation(ville, m)
    local servi = demande
    if servi > dispo then servi = dispo end
    local manque = demande > 0 and servi < demande * 0.999
    if manque then penurie = penurie + 1 end
    if m.vitale then
      vivres = vivres + 1
      if manque then faim = faim + 1 else vivres_servis = vivres_servis + 1 end
    end
    ville.stock[m.cle] = dispo - servi
  end
  if ville.habitants < SANS_FAMINE then faim = -10 end
  ville.faim, ville.penurie = faim, penurie
  ville.subsistance = vivres > 0 and vivres_servis / vivres or 1.0

  -- 3. Les ateliers, sur le surplus, dans l'ordre des dépendances. Ils gardent
  --    trois jours de consommation des habitants : un atelier qui racle
  --    l'entrepôt laisserait la ville sans rien le lendemain matin.
  for _, m in ipairs(Marchandises.ordreFabrication) do
    if m.recette then
      local capacite = ville.production[m.cle] or 0
      local sortie = capacite
      if sortie > 0 then
        for _, ing in ipairs(m.recette) do
          local garde = consommation(ville, Marchandises.get(ing[1])) * 3.0
          local dispo = (ville.stock[ing[1]] or 0) - garde
          local possible = dispo / ing[2]
          if possible < sortie then sortie = possible end
        end
        if sortie < 0 then sortie = 0 end
        for _, ing in ipairs(m.recette) do
          ville.stock[ing[1]] = (ville.stock[ing[1]] or 0) - sortie * ing[2]
        end
        ville.stock[m.cle] = (ville.stock[m.cle] or 0) + sortie
      end
      ville.rendement[m.cle] = sortie
    end
  end

  -- 4. Les entrepôts débordent au-delà d'une fois et demie le dernier seuil :
  --    sans plafond, une ville productrice accumulerait sans fin et son cours
  --    resterait collé au plancher pour toujours.
  for _, m in ipairs(Marchandises.liste) do
    local s2 = ville.stock[m.cle] or 0
    local plafond = seuils(ville, m)[5] * 1.5
    if s2 > plafond then s2 = plafond end
    if s2 < 0 then s2 = 0 end
    ville.stock[m.cle] = s2
  end

  -- 5. Démographie, selon les compteurs.
  local taux
  if faim > 0 then
    taux = -DECLIN_PAR_ALIMENT * faim
  elseif penurie > 0 then
    taux = -DECLIN_PAR_DENREE * penurie
  elseif faim == 0 then
    taux = 0
  else
    taux = CROISSANCE_MAX * math.min(-faim, 3) / 3
  end
  taux = borner(taux, -DECLIN_MAX, CROISSANCE_MAX)
  ville.habitants = borner(ville.habitants * (1 + taux), 120, 12000)
end


-- Avance l'économie de `heures` heures de jeu. Les journées entamées sont
-- reportées : à x4 comme à x1, une journée produit exactement la même chose.
-- Rend le nombre de journées écoulées.
function Economie.avancer(heures)
  if not next(Economie.villes) then Economie.reinitialiser() end
  reste_jour = reste_jour + (heures or 0) / 24.0
  local n = math.floor(reste_jour)
  if n <= 0 then return 0 end
  if n > 30 then n = 30 end          -- garde-fou si le jeu est resté suspendu
  reste_jour = reste_jour - n
  for _ = 1, n do
    for _, ville in pairs(Economie.villes) do
      jour(ville)
    end
  end
  -- La population commande les stades de croissance du village : on la recopie
  -- dans l'archipel, qui reste la table que le rendu interroge.
  for _, port in ipairs(Archipel.ports) do
    local v = Economie.villes[port.cle]
    if v then port.habitants = math.floor(v.habitants + 0.5) end
  end
  return n
end


Economie.reinitialiser()

return Economie
