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
local jour_no = 0


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
-- premier cran est celui du barème publié (200, 180, 120, 80).
--
-- PR3 bascule une ville sur sa série « pénurie » quand le drapeau `X%uknapp`
-- (bit 11 de l'état de la ville) est levé. Ce drapeau se lève par un compteur
-- lissé (`0x75C120`) : chaque jour où plusieurs denrées manquent l'incrémente, et
-- quand il atteint 25 le marché tout entier passe en régime de rareté ; il se
-- rabaisse quand la ville est de nouveau servie. C'est notre `ville.knapp`, tenu
-- par `jour()`.
Economie.PREISFAKTOREN = {
  { normal = { 2.0, 1.8, 1.2, 1.2, 0.8 }, penurie = { 3.0, 2.7, 1.2, 1.2, 0.8 } },
  { normal = { 1.8, 1.6, 1.2, 1.2, 0.7 }, penurie = { 2.7, 2.4, 1.2, 1.2, 0.7 } },
  { normal = { 1.6, 1.4, 1.1, 1.1, 0.6 }, penurie = { 2.4, 2.1, 1.1, 1.1, 0.6 } },
}
Economie.REGLAGE_PRIX = 1

local function coefficients(knapp)
  local jeu = Economie.PREISFAKTOREN[Economie.REGLAGE_PRIX] or Economie.PREISFAKTOREN[1]
  return knapp and jeu.penurie or jeu.normal
end


-- Le facteur à un niveau de stock, et le segment où il tombe — qui EST le nombre
-- de barres d'abondance (fonction `0x765310` du jeu). Les deux sortent du même
-- calcul : la jauge et le cours ne peuvent pas se contredire à l'écran.
local function facteur(stock, s, c)
  c = c or coefficients(false)
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
  local _, barres = facteur(stock, seuils(ville, m), coefficients(ville.knapp))
  return barres
end


function Economie.reinitialiser()
  Economie.villes = {}
  reste_jour = 0.0
  jour_no = 0
  for _, port in ipairs(Archipel.ports) do
    local ville = {
      cle = port.cle,
      nom = port.nom,
      habitants = port.habitants,
      production = PRODUCTIONS[port.cle] or {},
      stock = {},
      faim = -3,
      penurie = -12,
      knapp = false,
      knapp_serie = 0,
      qualite = 100,
      niveau = 5,
      tendance = 0,
      maisons = math.floor(port.habitants / 100) + 1,   -- logement : 100 par maison
      capacite = (math.floor(port.habitants / 100) + 1) * 100,
      fleau = nil,        -- { type = "peste"|"sauterelles"|"feu", jours = n }
    }
    -- Une graine propre à la ville, pour ses tirages de fléaux.
    local gf = 0
    for k = 1, string.len(port.cle) do
      gf = (gf * 131 + string.byte(port.cle, k)) % 2147483629
    end
    ville.graine_fleau = gf + 1
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


-- La couverture de chaque marchandise sur toute la carte : sa production
-- rapportée à sa demande (habitants, export et intrants des ateliers). C'est ce
-- que l'IA de PR3 regarde pour décider de bâtir (`0x7B4F90`) : sous Bauquotient,
-- la marchandise manque.
function Economie.couverture()
  local prod, dem = {}, {}
  for _, m in ipairs(Marchandises.liste) do prod[m.cle], dem[m.cle] = 0, 0 end
  for _, v in pairs(Economie.villes) do
    for _, m in ipairs(Marchandises.liste) do
      prod[m.cle] = prod[m.cle] + (v.production[m.cle] or 0)
      dem[m.cle] = dem[m.cle] + consommation(v, m) + ((v.ateliers or {})[m.cle] or 0)
    end
  end
  return prod, dem
end


-- Bâtir un atelier : PR3 y fait passer l'or que ses marchands amassent. On ajoute
-- la capacité d'un atelier (25 ouvriers) à la production de la ville et on
-- inscrit les intrants qu'il tirera désormais de ses entrepôts. Renvoie le coût
-- du terrain (`Bauplatzkosten`), ou nil si le bien est inconnu.
function Economie.batir(cle_ville, cle_bien)
  local v = Economie.ville(cle_ville)
  local m = Marchandises.get(cle_bien)
  if not v or not m then return nil end
  v.production[cle_bien] = (v.production[cle_bien] or 0) + m.atelier
  v.ateliers = v.ateliers or {}
  for _, ing in ipairs(m.recette or {}) do
    v.ateliers[ing[1]] = (v.ateliers[ing[1]] or 0) + m.atelier * ing[2]
  end
  return m.batiment.cout
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
  local c = coefficients(ville.knapp)
  local f
  if quantite <= 0 or (sens ~= "achat" and sens ~= "vente") then
    f = facteur(stock, s, c)
  elseif sens == "achat" then
    f = integrale(stock - quantite, stock, s, c) / quantite
  else
    f = integrale(stock, stock + quantite, s, c) / quantite
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
  local _, barres = facteur(stock, s, coefficients(ville.knapp))
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

-- LA QUALITÉ DE VIE ET LA PROSPÉRITÉ, comme PR3 les calcule (`0x7BF8A0`, puis
-- `0x7C2400`). Chaque jour la ville se note sur cent : chaque denrée rapporte des
-- points selon son stock rapporté à son premier seuil de prix X1, pleins dès X1
-- atteint — « la fourniture de denrées a un impact maximum sur la prospérité dès
-- que le stock atteint au moins une barre », dit le tutoriel. Les vingt denrées
-- se répartissent en quatre groupes (voir `Marchandises.GROUPES_QUALITE`), chacun
-- plafonné, pour un total de quatre-vingts points ; les vingt derniers viennent
-- des bâtiments publics, qu'on n'a pas, et qu'on remplace par une dotation civique
-- proportionnelle à la note des denrées.
--
-- Cette note (0 à 100) commande sept niveaux, du plus bas au plus haut, comme les
-- textes `ID_GUI_TOWN_WEALTH_00…07` : Pauvreté, Récession, Stagnation,
-- Redressement, Croissance, Prospérité, Opulence. Le tutoriel en donne la vitesse
-- et les portes : « sous 40 %, des citoyens redeviennent chaque jour des colons »,
-- Prospérité au-delà de 2 000 habitants, Opulence au-delà de 6 000.
--
-- On remplace ainsi une démographie qui ne lisait que les compteurs de faim : la
-- vitesse de croissance et de déclin est désormais celle de PR3, graduée par la
-- satisfaction et non par le seul manque d'un aliment.
local QUALITE_CIVIQUE = 0.25      -- dotation des bâtiments publics, en fraction de la note des denrées
local SEUIL_RECESSION = 40        -- sous 40 %, la ville décline (tutoriel)
local SEUIL_STAGNATION = 60
local SEUIL_PROSPERITE = 75
local SEUIL_OPULENCE = 90
local POP_PROSPERITE = 2000       -- Prospérité (niveau 6) exige cette population
local POP_OPULENCE = 6000         -- Opulence (niveau 7) exige celle-là

-- Le déclin garde les vitesses du tutoriel de PR3 (Pauvreté 2 %/jour, Récession
-- 1 %/jour). La CROISSANCE, elle, suit désormais le modèle exact de PR3 (voir plus
-- bas) et non plus un pourcentage.
local DECLIN_PAUVRETE = -0.020
local DECLIN_RECESSION = -0.010
local DECLIN_MAX = 0.0050

-- LA CROISSANCE EXACTE DE PR3 (`0x7C0BD0`) : les citoyens ne montent pas d'un
-- pourcentage, ils approchent la CAPACITÉ DE LOGEMENT (maisons × 100) d'un montant
--
--     croissance = (capacité − citoyens) × facteur ÷ diviseur
--
-- Le diviseur est 200 (rapide) ; le facteur est le coefficient d'immigration par
-- nation et difficulté (`0x828900`), qu'on ne lit pas et qu'on calibre. Les maisons
-- se bâtissent vers `citoyens ÷ 100 + 1` (100 locataires par maison), et une ville
-- prospère en bâtit DEVANT, d'où une capacité libre plus large et une montée plus
-- vive. La courbe ralentit d'elle-même près de la capacité, sans taux écrit.
local CROISSANCE_DIVISEUR = 200
local CROISSANCE_FACTEUR = 1.5        -- facteur d'immigration, calibré sur equilibre.gd
local MAISONS_AVANCE_PROSPERE = 2     -- maisons bâties DEVANT la population en Prospérité
local MAISONS_AVANCE_CROISSANCE = 1   -- et en simple croissance

-- La famine passe outre la prospérité : trois aliments manquants font fuir la
-- population quoi que dise la note.
local DECLIN_PAR_ALIMENT = 0.0015

-- Le drapeau « knapp » (série de prix de rareté) suit un compteur lissé, comme
-- `0x75C120` : il monte du nombre de denrées manquantes chaque jour, plafonne à
-- 25, et lève la rareté au-delà de 24 ; sans manque il redescend et l'éteint.
local KNAPP_PLAFOND = 25
local KNAPP_SEUIL = 24

-- LES FLÉAUX de PR3 (`0x7C2080` les applique, `0x829780` les charge). Rares, ils
-- frappent surtout les villes mal loties : le jeu les tire sur une probabilité
-- liée à la qualité de vie et à la surpopulation (`0x7C1930`). Chacun ajoute
-- 100 % de consommation (`Verbrauch/Pest`… = 100) à ses denrées le temps qu'il
-- dure — la peste au tissu et aux vêtements, les sauterelles aux fruits, au
-- chanvre et au pain, le feu au bois et aux briques (voir `Marchandises.FLEAUX`).
-- La peste tue en plus (`Pesttote`) et fait émigrer (`Abwanderung`).
--
-- Le tirage est DÉTERMINISTE, par ville et par jour, pour qu'une partie relancée
-- retrouve les mêmes fléaux aux mêmes dates.
local FLEAU_DUREE = 30            -- jours qu'un fléau dure
local FLEAU_PROBA = 0.0006        -- probabilité de base, par ville et par jour
local PESTE_MORTALITE = 0.004     -- déclin quotidien supplémentaire sous la peste
local FLEAU_TYPES = { "peste", "sauterelles", "feu" }

-- L'efficacité d'un atelier (`0x7C2B30`) monte ou descend d'un point par jour, sur
-- une échelle de 0 à 100 — soit 0,01 par jour. On garde un plancher pour qu'une
-- chaîne coupée puisse repartir une fois ses intrants revenus.
local EFFICACITE_PAS = 0.01
local EFFICACITE_MIN = 0.10

-- Un générateur de Park et Miller, semé de la ville et du jour : reproductible.
local function tirage(graine)
  local g = graine % 2147483646 + 1
  g = (g * 16807) % 2147483647
  return g / 2147483647
end


-- La note de la ville sur cent, et son niveau de prospérité de 0 à 6.
--
-- Chaque denrée vaut, dans son groupe, `pente × min(1, stock/X1)` point ; chaque
-- groupe est plafonné. La somme des quatre groupes va de 0 à 80 ; on l'étire sur
-- 100 en y ajoutant la dotation civique. Le niveau se lit ensuite sur des seuils
-- de PR3, avec les portes de population pour Prospérité et Opulence.
local function qualite(ville)
  local groupes = {}
  for _, m in ipairs(Marchandises.liste) do
    local g = Marchandises.GROUPES_QUALITE[m.groupe]
    if g then
      local x1 = seuils(ville, m)[2]
      local ratio = x1 > 0 and (ville.stock[m.cle] or 0) / x1 or 1.0
      if ratio > 1 then ratio = 1 end
      groupes[m.groupe] = (groupes[m.groupe] or 0) + g.pente * ratio
    end
  end
  local denrees = 0
  for cle, somme in pairs(groupes) do
    local g = Marchandises.GROUPES_QUALITE[cle]
    denrees = denrees + math.min(somme, g.plafond_groupe or 20)
  end
  local note = denrees * (1 + QUALITE_CIVIQUE) * 100.0 / 80.0
  if note > 100 then note = 100 end

  local h = ville.habitants
  local niveau
  if note <= 20 then niveau = 0
  elseif note <= SEUIL_RECESSION then niveau = 1
  elseif note <= SEUIL_STAGNATION then niveau = 2
  elseif note <= SEUIL_PROSPERITE then niveau = 4
  elseif note <= SEUIL_OPULENCE then niveau = (h >= POP_PROSPERITE) and 5 or 4
  else niveau = (h >= POP_OPULENCE) and 6 or ((h >= POP_PROSPERITE) and 5 or 4) end
  return note, niveau
end


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

  -- 2. Les habitants, et les compteurs de faim. Un fléau en cours double la
  --    consommation de ses denrées (Verbrauch = 100 %) — ce qui peut à lui seul
  --    jeter la ville dans le manque.
  local fleau_sur = {}
  if ville.fleau then
    for _, cle in ipairs(Marchandises.FLEAUX[ville.fleau.type] or {}) do
      fleau_sur[cle] = true
    end
  end
  local faim, penurie = DEPART_FAIM, DEPART_PENURIE
  local vivres_servis, vivres = 0, 0
  for _, m in ipairs(Marchandises.liste) do
    local dispo = ville.stock[m.cle] or 0
    local demande = consommation(ville, m)
    if fleau_sur[m.cle] then demande = demande * 2 end
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

  -- Le compteur lissé de rareté : il monte du nombre de denrées manquantes,
  -- plafonne, et lève « knapp » au-delà du seuil. Une pénurie passagère ne suffit
  -- donc pas à durcir tout le marché ; une disette installée, oui.
  local manquantes = penurie - DEPART_PENURIE
  local serie = (ville.knapp_serie or 0) + manquantes - 1
  if serie < 0 then serie = 0 end
  if serie > KNAPP_PLAFOND then serie = KNAPP_PLAFOND end
  ville.knapp_serie = serie
  ville.knapp = serie > KNAPP_SEUIL

  -- 3. Les ateliers, sur le surplus, dans l'ordre des dépendances. Ils gardent
  --    trois jours de consommation des habitants : un atelier qui racle
  --    l'entrepôt laisserait la ville sans rien le lendemain matin.
  --
  --    L'EFFICACITÉ de PR3 (`0x7C2B30`) : un atelier ne tourne pas à plein d'un
  --    coup. Sa production visée vaut capacité × efficacité ; si les intrants ne
  --    suivent pas, l'efficacité tombe d'un point par jour (`[+0x92]−1`), sinon
  --    elle remonte. C'est l'inertie qui fait qu'une chaîne coupée met des jours à
  --    repartir même quand ses intrants reviennent.
  ville.efficacite = ville.efficacite or {}
  for _, m in ipairs(Marchandises.ordreFabrication) do
    if m.recette then
      local capacite = ville.production[m.cle] or 0
      local sortie = 0
      if capacite > 0 then
        local eff = ville.efficacite[m.cle] or 1.0
        sortie = capacite * eff
        local affame = false
        for _, ing in ipairs(m.recette) do
          local garde = consommation(ville, Marchandises.get(ing[1])) * 3.0
          local dispo = (ville.stock[ing[1]] or 0) - garde
          local possible = dispo / ing[2]
          if possible < sortie then sortie = possible; affame = true end
        end
        if sortie < 0 then sortie = 0 end
        for _, ing in ipairs(m.recette) do
          ville.stock[ing[1]] = (ville.stock[ing[1]] or 0) - sortie * ing[2]
        end
        ville.stock[m.cle] = (ville.stock[m.cle] or 0) + sortie
        -- Le ramp d'efficacité : −1 point/jour si les intrants manquent, +1 sinon.
        eff = affame and (eff - EFFICACITE_PAS) or (eff + EFFICACITE_PAS)
        ville.efficacite[m.cle] = borner(eff, EFFICACITE_MIN, 1.0)
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

  -- 5. La note de la ville et son niveau de prospérité.
  local note, niveau = qualite(ville)
  ville.qualite, ville.niveau = note, niveau

  -- 6. Démographie, comme PR3. Le DÉCLIN reste un pourcentage (les vitesses du
  --    tutoriel) ; la CROISSANCE approche la capacité de logement.
  --
  --    a) Le logement (`0x7BF3D0`) : la ville vise `citoyens ÷ 100 + 1` maisons,
  --       et si elle croît elle en bâtit DEVANT — c'est cette avance qui crée la
  --       capacité libre où la population monte.
  local avance = 0
  if faim <= 0 and note > SEUIL_STAGNATION then
    avance = (niveau >= 5) and MAISONS_AVANCE_PROSPERE or MAISONS_AVANCE_CROISSANCE
  end
  local cible_maisons = math.floor(ville.habitants / 100) + 1 + avance
  if niveau == 6 and ville.habitants >= POP_OPULENCE * 1.8 then
    cible_maisons = math.floor(ville.habitants / 100) + 1   -- l'Opulence cesse de pousser
  end
  local maisons = ville.maisons or (math.floor(ville.habitants / 100) + 1)
  if maisons < cible_maisons then
    maisons = math.min(cible_maisons, maisons + 1)          -- une maison par jour
  elseif maisons * 100 > ville.habitants + 1500 then
    maisons = maisons - 1                                   -- on retire le surplus (PR3)
  end
  if maisons < 1 then maisons = 1 end
  ville.maisons = maisons
  local capacite = maisons * Economie.LOGES_PAR_MAISON
  ville.capacite = capacite

  --    b) La population.
  if faim > 0 then
    ville.habitants = ville.habitants * (1 - borner(DECLIN_PAR_ALIMENT * faim, 0, DECLIN_MAX))
    ville.tendance = -1
  elseif note <= 20 then
    ville.habitants = ville.habitants * (1 + DECLIN_PAUVRETE)
    ville.tendance = -1
  elseif note <= SEUIL_RECESSION then
    ville.habitants = ville.habitants * (1 + DECLIN_RECESSION)
    ville.tendance = -1
  elseif note <= SEUIL_STAGNATION or capacite <= ville.habitants then
    ville.tendance = 0                                      -- stagnation, ou plus de logement
  else
    -- Croissance vers la capacité, freinée par la subsistance : une ville qui ne
    -- nourrit pas déjà tous ses gens n'attire plus de colons (frein au carré, pour
    -- qu'elle ne dépasse pas ce que sa nourriture porte et ne bascule pas en
    -- famine — la sim ne veut pas de la famine que PR3 corrige par l'exode).
    local subsist = ville.subsistance or 1.0
    local croissance = (capacite - ville.habitants) * CROISSANCE_FACTEUR
                       / CROISSANCE_DIVISEUR * subsist * subsist
    ville.habitants = ville.habitants + croissance
    ville.tendance = croissance > 0.01 and 1 or 0
  end
  -- La peste tue tant qu'elle dure, par-dessus le reste.
  if ville.fleau and ville.fleau.type == "peste" then
    ville.habitants = ville.habitants * (1 - PESTE_MORTALITE)
    ville.tendance = -1
  end
  ville.habitants = borner(ville.habitants, 120, 12000)

  -- 7. Les fléaux : on décompte celui qui court, sinon on tire. Une ville mal
  --    lotie (note basse) est bien plus exposée — c'est ainsi que PR3 frappe les
  --    villes en difficulté (`0x7C1930`). Aucune famine sous 300 habitants, aucun
  --    fléau non plus : un hameau n'intéresse pas les malheurs.
  if ville.fleau then
    ville.fleau.jours = ville.fleau.jours - 1
    if ville.fleau.jours <= 0 then ville.fleau = nil end
  elseif ville.habitants >= SANS_FAMINE then
    -- Le risque suit la SURPOPULATION, comme PR3 (`0x7C1930` : citoyens contre un
    -- seuil de logement, tirage sur 30 000) : une ville qui remplit ses maisons est
    -- plus exposée aux épidémies et aux incendies.
    local risque = FLEAU_PROBA * ville.habitants / math.max(ville.capacite, 1)
    local graine = ville.graine_fleau + jour_no * 2654435761
    if tirage(graine) < risque then
      local i = math.floor(tirage(graine + 777) * #FLEAU_TYPES) + 1
      if i > #FLEAU_TYPES then i = #FLEAU_TYPES end
      ville.fleau = { type = FLEAU_TYPES[i], jours = FLEAU_DUREE }
    end
  end
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
    jour_no = jour_no + 1
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
