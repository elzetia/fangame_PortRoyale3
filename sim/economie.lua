-- L'économie des villes : stocks, production, consommation, prix.
--
-- Le modèle est celui de Port Royale 1, le plus simple des trois et celui sur
-- lequel les deux autres se sont construits : chaque ville produit quelques
-- marchandises, les consomme toutes en proportion de sa population, et son prix
-- ne dépend que de ce qu'il lui en reste en entrepôt. Aucun marché mondial,
-- aucun cours de référence : c'est la pénurie locale qui fait le prix, et c'est
-- l'écart entre deux villes qui fait le métier de marchand.
--
-- Lua pur : ce fichier ne connaît pas Godot.

local Archipel     = require("sim.archipel")
local Marchandises = require("sim.marchandises")

local Economie = {}

-- Une ville garde en réserve de quoi tenir ce nombre de jours. C'est ce chiffre
-- qui fixe la PROFONDEUR du marché : la quantité qu'un navire peut écouler
-- sans effondrer le cours.
--
-- C'est un équilibre à deux dangers. Trop peu, et une seule escale retourne le
-- cours : le prix payé n'a plus de rapport avec celui affiché. Trop, et le
-- contraire arrive — à 90 jours, les entrepôts tenaient huit cents tonnes, la
-- cale d'un sloop n'y changeait rien de visible, ni le prix ni la réglette
-- d'abondance ne bougeaient sous les doigts du joueur, et le marché devenait
-- un décor.
--
-- 18 jours place une cargaison de cinquante tonneaux à un bon tiers de
-- l'entrepôt d'une denrée courante : le geste se voit, sans faire la loi.
--
-- C'était 42, et les entrepôts d'un bourg de douze cents âmes tenaient trois
-- cent tonnes de blé — cent jours de pain d'avance. Un chiffre juste pour les
-- grandes villes du premier réglage (jusqu'à 3 300 habitants) devient absurde
-- pour cinq colonies naissantes : elles n'ont ni les bras ni les hangars pour
-- ça. La réserve se compte désormais en semaines, pas en saisons.
local JOURS_RESERVE = 30

-- Écart entre le prix d'achat et le prix de vente. Le marchand ne gagne donc
-- jamais rien à revendre sur place : il faut déplacer la marchandise.
local MARGE = 0.09

-- Les bornes du prix, et donc la MARGE MAXIMALE DU JEU, ne sont plus des
-- constantes : ce sont le premier et le dernier des coefficients de PR3, 2,00 et
-- 0,80 (voir `facteur`). Entre acheter au plancher et vendre au plafond il y a
-- un rapport de 2,5, moins deux fois la commission du courtier.
--
-- Deux erreurs successives les avaient précédées, chacune d'un ordre de
-- grandeur : 3,0 / 0,40 — mes valeurs devinées — donnaient des routes à
-- +460 %, et la première traversée d'un sloop rapportait plus que le capital de
-- départ ; puis un plancher à 1,00, qui clouait le cours au prix de base dès que
-- l'entrepôt dépassait une fois et demie sa réserve, et une ville gorgée de
-- marchandise ne bradait jamais.

-- Production quotidienne, en tonnes.
--
-- Ce n'est plus une quantité acquise mais une CAPACITÉ : ce que la ville
-- produirait si elle avait de quoi. Depuis que les recettes existent, un
-- atelier sans intrants chôme.
--
-- Les chiffres ont été recalculés à l'arrivée des recettes, par une méthode
-- plutôt qu'à la main : chaque ville produit d'abord 65 % de ses PROPRES
-- intrants — un atelier qui dépend entièrement de l'import chôme dès que le
-- navire a du retard — puis les totaux de l'archipel sont relevés pour couvrir
-- la demande des habitants ET celle de l'industrie, avec six pour cent de
-- marge. Sans cette seconde passe, l'archipel s'effondrait en un an : les
-- ateliers dévoraient des matières premières que personne ne produisait.
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
-- calcule donc, et par la meme methode qu'avant :
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
-- peut redresser. C'est la raison d'etre du calcul : a soixante villes, aucune
-- table ecrite a la main ne tiendrait cette propriete apres une retouche.
--
-- En revanche AUCUNE ville n'est autosuffisante, et c'est voulu : cinq
-- marchandises sur vingt. C'est cet ecart, et lui seul, qui fait le metier de
-- marchand.

-- De quoi croitre. Sans cette marge, les villes butent des le premier mois sur
-- le plafond demographique et ne grandissent jamais -- or c'est la seule
-- recompense visible du travail du joueur.
local CROISSANCE = 1.20
local MARGE_CHAINE = 1.06

-- La démographie regarde le TROISIÈME aliment le mieux servi sur cinq — la
-- famine de PR3 exige que trois manquent ensemble (voir `jour`). Au point fixe,
-- trois vivres tombent donc à court en même temps. On donne à la viande et au
-- pain de quoi garder du stock : ce sont les deux transformés, ceux dont une
-- ville encore servie tire sa marge, et ce sont les trois récoltes qui font la
-- limite — donc un cours qui bouge et une route qui vit.
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
  -- dans ses cinq n'en produit pas un gramme et fond jusqu'au plancher de cent
  -- vingt ames en cinq ans -- ce qui est arrive aux deux tiers de la carte au
  -- premier essai.
  --
  -- Chaque ville couvre donc cette part de ses PROPRES besoins vitaux. Le
  -- reglage est auto-stabilisant : la production est fixe, la consommation
  -- suit la population, donc une ville jamais ravitaillee decroit jusqu'a
  -- cette part de sa taille et s'y arrete. Elle ne meurt pas, elle attend le
  -- marchand -- et les quarante pour cent qui manquent sont sa demande
  -- permanente, donc une route qui ne se tarit jamais.
  -- Quatre-vingt-cinq pour cent : une ville jamais ravitaillee se stabilise a
  -- 88 % de sa taille, ce qui est une gene, pas une agonie. A 60 % elle perdait
  -- les deux cinquiemes de ses habitants avant que le premier convoi ait fait
  -- deux tours -- la logistique d'une carte de soixante ports est trop lente
  -- pour une chute aussi raide.
  local AUTONOMIE_VIVRES = 0.85

  -- Le socle doit couvrir les INTRANTS de ses propres ateliers vitaux, pas
  -- seulement ce que les habitants mangent. La viande se fait avec deux mais,
  -- le pain avec un ble et un mais : une ville a qui l'on donne 85 % de sa
  -- viande sans lui donner le mais qui la fait n'en produit pas un gramme.
  -- C'est ce qui est arrive au premier essai -- Corpus Christi gardait mille
  -- tonnes de ble au plafond de son entrepot et zero viande, zero pain,
  -- subsistance nulle. Les vivres se remontent donc a l'envers, comme le reste.
  --
  -- Seuls les vivres faits DE VIVRES y entrent. Le pain de PR3 se pétrit au
  -- sucre : une ville sans canne ne peut pas s'en faire un potager, et lui
  -- donner un four sans sucre ne produirait qu'une capacité à l'arrêt. Son pain
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


-- Consommation quotidienne d'une ville pour une marchandise, en tonnes : ses
-- habitants, et l'Europe par-dessus pour les denrées qui s'exportent. C'est ce
-- qui sort de l'entrepôt sans rien produire en échange.
local function consommation(ville, m)
  return Marchandises.besoin(m) * ville.habitants / 1000.0
end


-- Stock que la ville cherche à tenir, en trois parts — les colonnes de la
-- consommation dans l'outil de débogage de PR3 (habitants et export,
-- manufactures) plus la réserve d'un port producteur :
--
--   · de quoi servir ses habitants et l'export pendant la réserve ;
--   · de quoi faire tourner SES ATELIERS pendant la même réserve ;
--   · si elle produit la denrée, de quoi charger les navires — sans ça un port
--     exportateur serait toujours à sec et son cours ne descendrait jamais.
--
-- La part des ateliers manquait. Une ville à forge ne visait son métal qu'au
-- titre de ce que ses habitants en usent : l'entrepôt affichait trois barres
-- avec de quoi tenir deux jours d'atelier, aucun convoi n'y voyait de manque,
-- et la forge chômait. Mesuré sur cinq ans avant la correction : outils à 2 %
-- de leur capacité, rhum à 6 %, tissu à 15 %.
local function reference(ville, m)
  local c = consommation(ville, m) * JOURS_RESERVE
  local a = ((ville.ateliers or {})[m.cle] or 0) * JOURS_RESERVE
  local p = (ville.production[m.cle] or 0) * JOURS_RESERVE * 0.55
  local r = c + a + p
  if r < 12 then r = 12 end
  return r
end


-- Le facteur de prix, selon le remplissage de l'entrepôt.
--
-- C'est le modèle de Port Royale 3, relu dans son `constdata.dat` (table
-- `Preisfaktoren`) : CINQ coefficients posés sur quatre seuils de stock, une
-- droite entre deux, et le prix vaut prix standard × coefficient.
--
--   stock / référence    0      0,17    0,90    1,10    2,05 et plus
--   facteur             2,00    1,80    1,20    1,20    0,80
--
-- Les coefficients sont ceux du jeu. Les SEUILS ne sont pas dans le fichier —
-- PR3 les calcule ville par ville (ses `X1…X4`) — et ils sont choisis ici pour
-- retomber sur la courbe qu'on avait calée à la main, 3/(1,5+r) bornée entre
-- 0,80 et 2,00 : moins de 3 % d'écart sur toute la plage. Le réglage du marché
-- (profondeur, marges des routes, décisions des convois) reste donc valable.
--
-- Ce que le modèle apporte, c'est le PLATEAU. Les deux coefficients égaux à 1,20
-- sont l'état « deux barres » du barème — la ville normalement approvisionnée —
-- et l'ancienne courbe passait par 1,20 sans s'y arrêter.
--
-- PR3 a trois séries de coefficients, une par cran de son réglage de prix, et
-- pour chacune une variante « pénurie » plus raide dans le haut. La première est
-- celle du barème publié (200, 180, 120, 80) : c'est elle qu'on joue. Quand le
-- jeu bascule sur la variante n'est pas établi ; elle est gardée, éteinte.
Economie.PREISFAKTOREN = {
  { normal = { 2.0, 1.8, 1.2, 1.2, 0.8 }, penurie = { 3.0, 2.7, 1.2, 1.2, 0.8 } },
  { normal = { 1.8, 1.6, 1.2, 1.2, 0.7 }, penurie = { 2.7, 2.4, 1.2, 1.2, 0.7 } },
  { normal = { 1.6, 1.4, 1.1, 1.1, 0.6 }, penurie = { 2.4, 2.1, 1.1, 1.1, 0.6 } },
}
Economie.REGLAGE_PRIX = 1
Economie.PENURIE = false
local SEUILS = { 0.0, 0.17, 0.90, 1.10, 2.05 }

-- Rend le facteur ET le segment où tombe le stock, qui est le nombre de barres.
-- Les deux sortent du même calcul : la jauge et le cours ne peuvent donc pas se
-- contredire à l'écran.
local function facteur(ratio)
  local jeu = Economie.PREISFAKTOREN[Economie.REGLAGE_PRIX] or Economie.PREISFAKTOREN[1]
  local c = Economie.PENURIE and jeu.penurie or jeu.normal
  if ratio <= 0 then return c[1], 0 end
  for i = 1, #SEUILS - 1 do
    if ratio < SEUILS[i + 1] then
      local t = (ratio - SEUILS[i]) / (SEUILS[i + 1] - SEUILS[i])
      return c[i] + (c[i + 1] - c[i]) * t, i - 1
    end
  end
  return c[#c], #SEUILS - 1
end


-- Nombre de barres d'abondance, de 0 à 4 : le segment de la courbe où tombe le
-- stock. Le barème de PR3 se lit ainsi directement sur ses coefficients :
--
--   0 barre  : 200 à 180 %      3 barres : 120 à 80 %
--   1 barre  : 180 à 120 %      4 barres : 80 %
--   2 barres : 120 %
--
-- L'ancienne version tirait les barres de la VALEUR du facteur, avec des seuils
-- retouchés à la main — 1,25 et 1,15 autour de 1,20, 0,85 au-dessus du
-- plancher — parce que ce barème semblait se contredire à 120 %, les deux
-- barres n'y ayant qu'une valeur unique. Il ne se contredit pas : 120 % est un
-- plateau, et les deux barres sont ce plateau.
--
-- `delta` déplace le stock avant le calcul, sans rien changer à la ville : le
-- comptoir s'en sert pour montrer, pendant qu'on tire la jauge, l'abondance que
-- l'échange LAISSERAIT. Le décalage passe par ici, et pas par un calcul refait
-- côté panneau, pour que la prévision suive exactement le même barème que
-- l'affichage au repos.
function Economie.barres(cle_ville, cle_m, delta)
  local ville = Economie.ville(cle_ville)
  local m = Marchandises.get(cle_m)
  if not ville or not m then return 0 end
  local stock = (ville.stock[cle_m] or 0) + (delta or 0)
  if stock < 0 then stock = 0 end
  local _, barres = facteur(stock / reference(ville, m))
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
    }
    -- Ce que ses ateliers tirent de ses entrepôts chaque jour, à pleine
    -- capacité : la part « manufactures » de sa demande, que `reference` ajoute
    -- à celle des habitants. La production est fixe : on la compte une fois.
    ville.ateliers = {}
    for cle, q in pairs(ville.production) do
      for _, ing in ipairs(Marchandises.get(cle).recette or {}) do
        ville.ateliers[ing[1]] = (ville.ateliers[ing[1]] or 0) + q * ing[2]
      end
    end
    -- On démarre chaque entrepôt à son niveau de référence, avec un écart
    -- déterministe d'une marchandise à l'autre : une partie qui commence à
    -- l'équilibre parfait n'offre aucune occasion, et il n'y aurait rien à
    -- faire au premier jour.
    -- La graine du bourg. Elle était tirée de la LONGUEUR de sa clé, ce qui a
    -- fini par se payer : `cartagene` et `iles_turk` font neuf lettres, donc
    -- partaient avec exactement les mêmes entrepôts, aux mêmes cours, et deux
    -- des cinq villes n'offraient aucune occasion l'une par rapport à l'autre.
    -- Un vrai condensé des lettres n'a pas ce défaut.
    local graine = 0
    for k = 1, string.len(port.cle) do
      graine = (graine * 31 + string.byte(port.cle, k)) % 997
    end

    for i, m in ipairs(Marchandises.liste) do
      -- Écart de départ volontairement LARGE. Resserré autour de la référence
      -- (0,75 à 1,25), il donnait quatre barres vertes sur presque toutes les
      -- lignes au premier jour : l'écran était uniforme, et rien n'indiquait au
      -- joueur où aller. De 0,30 à 1,35, la jauge parle dès l'ouverture — et
      -- c'est cet écart, bien plus que la production, qui fait qu'une route
      -- rapporte au premier matin.
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
-- Port Royale 3 donne ses trois chiffres lui-même, dans son tutoriel :
--
--   « Chaque manufacture créant 25 emplois, et chaque emploi apportant 4
--     nouveaux citoyens à la ville, la construction de vos Plantations de coton
--     a accru la population de Port Royale de 200 personnes. »
--
-- Deux plantations, 25 emplois chacune, quatre citoyens par emploi : 200. Le
-- compte tombe juste, donc les deux constantes sont sûres. Une fabrique porte
-- ainsi cent habitants, ouvrier et famille compris.
--
--   « Il faut pour chaque manufacture construire un immeuble qui logera les
--     ouvriers. Les marchands d'une ville construisent toujours de nouvelles
--     maisons lorsque les maisons existantes sont remplies à 80%. »
--
-- D'où le calcul du logement : on pose le plus petit nombre de maisons qui tient
-- la ville sous les 80 %. C'est ce seuil qui fait osciller le taux d'occupation
-- au lieu de le coller à 100 — une ville qui grandit franchit 80 %, une maison
-- sort de terre, et le taux retombe. Le chiffre affiché n'est donc pas cosmétique :
-- c'est la place qui reste avant la prochaine construction.
--
-- Rien de tout cela n'est simulé bâtiment par bâtiment. La population reste la
-- seule variable d'état ; ces trois nombres en sont des lectures, et c'est
-- exactement le rapport qu'entretient PR3 entre sa démographie et ses murs.
Economie.EMPLOIS_PAR_FABRIQUE = 25
Economie.CITOYENS_PAR_EMPLOI  = 4
Economie.LOGES_PAR_MAISON     = 100     -- 25 × 4 : une maison par manufacture
Economie.SEUIL_CONSTRUCTION   = 0.80    -- au-delà, les marchands rebâtissent

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


-- Prix unitaire moyen d'une transaction.
--
-- On évalue le cours au stock MOYEN pendant l'échange, et non au stock de
-- départ : vider un entrepôt fait monter le prix au fur et à mesure, et c'est
-- ce qui empêche d'emporter mille tonnes au cours de la première.
function Economie.cotation(cle_ville, cle_m, quantite, sens)
  local ville = Economie.ville(cle_ville)
  local m = Marchandises.get(cle_m)
  if not ville or not m then return nil end

  quantite = quantite or 0
  local stock = ville.stock[cle_m] or 0
  local moyen = stock
  if sens == "achat" then
    moyen = stock - quantite * 0.5          -- le joueur achète : le stock baisse
  elseif sens == "vente" then
    moyen = stock + quantite * 0.5
  end
  if moyen < 0 then moyen = 0 end

  local base = m.prix * facteur(moyen / reference(ville, m))
  if sens == "achat" then
    return base * (1 + MARGE)
  elseif sens == "vente" then
    return base * (1 - MARGE)
  end
  return base
end


-- Tableau du marché d'une ville : une ligne par marchandise.
-- `lot` est la quantité que le joueur envisage d'échanger. Les colonnes de
-- prix sont données pour l'unité ET pour ce lot : c'est le second chiffre qu'il
-- paiera vraiment, et l'écart entre les deux est la profondeur du marché.
-- L'etat d'UNE ligne, sans construire les vingt autres.
--
-- `Economie.marche` batit un tableau complet : vingt lignes, quatre cotations
-- chacune. C'etait sans consequence a cinq villes ; a soixante, un convoi qui
-- cherche ou acheter son ble interrogeait soixante marches entiers, soit sept
-- mille evaluations de prix pour une seule decision. Cinq annees de jeu
-- prenaient deux minutes. Cette porte-ci en coute trois.
function Economie.ligne(cle_ville, cle_m)
  local ville = Economie.ville(cle_ville)
  local m = Marchandises.get(cle_m)
  if not ville or not m then return nil end
  local stock = ville.stock[cle_m] or 0
  local ref = reference(ville, m)
  local _, barres = facteur(stock / ref)
  local prod = ville.production[cle_m] or 0
  return {
    cle = cle_m,
    stock = stock,
    reference = ref,
    barres = barres,
    production = prod,
    solde = ((ville.rendement or {})[cle_m] or prod) - consommation(ville, m),
  }
end


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
      -- Tendance : ce que la ville gagne ou perd chaque jour. C'est elle qui
      -- dit au joueur si le cours va monter, bien plus que le prix seul.
      -- Le solde affiché part du rendement RÉEL de la veille, pas de la
      -- capacité : un atelier à l'arrêt faute d'intrants doit se voir.
      solde = ((ville.rendement or {})[m.cle] or prod) - consommation(ville, m),
      capacite = prod,
      barres = Economie.barres(cle_ville, m.cle),
    }
  end
  return lignes
end


-- Retire de la marchandise à la ville. Renvoie la quantité réellement servie et
-- la somme due. La ville garde toujours un fond de cale : sans ce plancher, un
-- joueur pourrait affamer une ville en une seule escale.
function Economie.acheter(cle_ville, cle_m, quantite)
  local ville = Economie.ville(cle_ville)
  local m = Marchandises.get(cle_m)
  if not ville or not m or quantite <= 0 then return 0, 0 end

  local plancher = reference(ville, m) * 0.08
  local dispo = (ville.stock[cle_m] or 0) - plancher
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


-- Combien d'aliments sur cinq doivent être servis pour qu'une ville mange à sa
-- faim : la famine de PR3 se déclenche quand trois font défaut, donc trois
-- suffisent. Voir l'étape 2 de `jour`.
local ALIMENTS_SUFFISANTS = 3


-- Une journée de vie économique.
--
-- L'ORDRE des trois étapes est le coeur du modèle :
--
--   1. les récoltes et les mines livrent — elles ne dépendent de rien ;
--   2. les habitants se servent ;
--   3. les ateliers transforment CE QUI RESTE.
--
-- Mettre les ateliers avant les habitants paraissait plus naturel, et faisait
-- mourir New Orléans en un an : sa boulangerie mangeait le blé de ses propres
-- gens. Une ville ne doit pas pouvoir s'affamer en bâtissant un four. Les
-- ateliers vivent du surplus, jamais du nécessaire.
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

  -- 2. Les habitants.
  local parts = {}
  for _, m in ipairs(Marchandises.liste) do
    local dispo = ville.stock[m.cle] or 0
    local demande = consommation(ville, m)
    local servi = demande
    if servi > dispo then servi = dispo end

    -- La subsistance se mesure sur les besoins RÉELLEMENT SERVIS dans la
    -- journée, pas sur le niveau des entrepôts. Mesurée sur le stock, une
    -- ville en équilibre de flux mais aux réserves minces se lit comme
    -- affamée, et décline sans fin alors qu'elle mange à sa faim tous les
    -- jours. Le stock, lui, fait le prix — c'est son seul rôle.
    if m.vitale and demande > 0 then
      parts[#parts + 1] = servi / demande
    end
    ville.stock[m.cle] = dispo - servi
  end

  -- LA FAMINE DE PR3 : « si 3 de ces produits font défaut simultanément sur une
  -- longue période, une famine se déclenche ». Une ville tient donc tant que
  -- trois de ses cinq aliments sont servis, et la mesure qui le dit est le
  -- TROISIÈME le mieux servi.
  --
  -- On regardait le pire. C'était tenable à quatre vivres tous récoltés sur
  -- place ; ça ne l'est plus avec le pain de PR3, qui se fait au sucre : une
  -- ville loin des cannes serait morte de faim avec ses greniers pleins. Et le
  -- jeu le dit lui-même — « essayez d'obtenir différentes nourritures » : c'est
  -- la variété qui nourrit, pas l'aliment le plus rare.
  table.sort(parts, function(a, b) return a > b end)
  local pire = parts[math.min(ALIMENTS_SUFFISANTS, #parts)] or 1.0

  -- 3. Les ateliers, sur le surplus, dans l'ordre des dépendances. Ils gardent
  --    une réserve de sécurité : un atelier qui racle l'entrepôt jusqu'au fond
  --    laisserait la ville sans rien à vendre le lendemain matin.
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
      -- Le rendement réel sert au tableau du comptoir : une ville dont
      -- l'atelier chôme faute d'intrants doit le dire, sinon le joueur ne sait
      -- pas quoi lui apporter.
      ville.rendement[m.cle] = sortie
    end
  end

  -- 4. Les entrepôts débordent : au-delà du triple de leur référence, le
  --    surplus est perdu. Sans ce plafond, une ville productrice accumulerait
  --    sans fin et son cours resterait collé au plancher pour toujours.
  for _, m in ipairs(Marchandises.liste) do
    local s2 = ville.stock[m.cle] or 0
    local plafond = reference(ville, m) * 3.0
    if s2 > plafond then s2 = plafond end
    if s2 < 0 then s2 = 0 end
    ville.stock[m.cle] = s2
  end

  -- 5. Démographie. Il faut couvrir 97 % des besoins vitaux pour gagner des
  -- habitants ; en dessous la ville se vide, d'autant plus vite que la disette
  -- est profonde. Les deux vitesses ne sont pas symétriques : on repeuple une
  -- colonie lentement, on la vide en une saison.
  local taux = borner((pire - 0.97) * 0.010, -0.0050, 0.0008)
  ville.habitants = borner(ville.habitants * (1 + taux), 120, 12000)
  ville.subsistance = pire
end


-- Avance l'économie de `heures` heures de jeu. Les journées entamées sont
-- reportées : à x4 comme à x1, une journée produit exactement la même chose.
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
