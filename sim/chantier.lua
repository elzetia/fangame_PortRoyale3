-- Le chantier naval, tel que PR3 le fait (voir `outils/PR3_SYSTEMES.md`
-- § « Le chantier naval »).
--
-- PR3 offre cinq gestes au chantier : ACHETER un navire tout fait (au plein prix
-- `Value`, tout de suite), le CONSTRUIRE neuf (moins cher, contre des matières et
-- un délai), le RÉPARER, le REVENDRE (cote normale ou cote pirate). Ce module tient
-- les RÈGLES et les CHIFFRES ; les gestes qui touchent la caisse et la flotte vivent
-- dans `sim/compagnie.lua`, seul maître de l'or du joueur.
--
-- Ce qui est EXACT (lu dans l'exécutable) :
--   * acheter = prix `Value` du type (colonne `prix` de `sim/navires`), immédiat ;
--   * construire = coût `Construct` (colonne `construction`) + matières + délai ;
--   * limites de flotte `[Limits]` : 50 navires, 50 par convoi, 100 convois ;
--   * réparation `[Repairs]` : Zeit 30, Kosten 50 la coque.
--
-- Ce qui est PROVISOIRE : la recette de construction — matières et durée. On pose
-- une recette raisonnable, à caler sur des relevés en jeu, comme la puissance de
-- combat. Tout ce qui est provisoire est marqué CALER.
--
-- CORRECTION d'une note antérieure, qui affirmait que PR3 ne range pas sa recette
-- en table. C'est faux au moins en partie : sa clé `Construct` est un tableau de
-- six entiers dont le PREMIER est le coût en or (exact, déjà utilisé ici) et les
-- cinq suivants CINQ OCTETS rangés par navire, juste après le triplet
-- Nations/Masts/Gauge. Ils croissent avec la coque — la pinasse porte
-- 11, 20, 10, 15, 10 et le vaisseau de ligne 38, 65, 35, 45, 45.
--
-- Cinq octets pour quatre emplacements de marchandise à l'écran : le cinquième
-- est vraisemblablement la durée en jours (10 pour la pinasse, 45 pour le
-- vaisseau de ligne), ce qui n'est pas démontré. Et rien ne dit encore QUELLES
-- denrées désignent les quatre autres. Voir `outils/PR3_DONNEES.md`.

local Navires = require("sim.navires")

local Chantier = {}

-- Limites de flotte, `[Limits]` de PR3 (`0x8299d9`) — EXACT.
Chantier.LIMITE_NAVIRES = 50   -- maxShips : navires possédés en tout
Chantier.LIMITE_MEMBRES = 50   -- maxConvoyMembers : navires dans un même convoi
Chantier.LIMITE_CONVOIS = 100  -- maxConvoys

-- Réparation, `[Repairs]` de PR3 (`0x8557c2`) — EXACT. Sans combat dans la sim, la
-- coque ne s'abîme pas encore ; on garde les chiffres pour quand elle le fera.
Chantier.REPARATION_ZEIT = 30    -- facteur de temps (plancher 1)
Chantier.REPARATION_KOSTEN = 50  -- coût à l'unité de coque manquante

-- Revente d'un navire au chantier : une fraction de son `Value`. CALER : PR3 rachète
-- à perte (et le pétale « pirate » à un autre taux) ; on pose la moitié, à ajuster.
Chantier.REVENTE = 0.5

-- Ce que le chantier paie pour un navire d'occasion.
function Chantier.prix_revente(cle_type)
  local navire = Navires.get(cle_type)
  return navire and math.floor(navire.prix * Chantier.REVENTE + 0.5) or 0
end

-- Les matières navales de PR3 : bois, cordage (gréement), tissu (voiles), et métal
-- pour les coques armées. Jusqu'à QUATRE, comme l'offre du jeu (boucle `0x58cae0`,
-- qui itère sur un vecteur d'éléments de huit octets — un `u32` d'indice de denrée
-- et un `f32` de quantité — et s'arrête à quatre).
-- CALER : quantités provisoires, à l'échelle de la cale. Relever en jeu la recette
-- réelle (construire quelques navires, noter les marchandises) puis remplacer.
local function recette_materiaux(navire)
  local cale = navire.cale
  local m = {
    { cle = "bois",    quantite = math.ceil(cale / 8) },   -- la coque
    { cle = "cordage", quantite = math.ceil(cale / 40) },  -- le gréement
    { cle = "tissu",   quantite = math.ceil(cale / 30) },  -- les voiles
  }
  if navire.militaire then
    m[#m + 1] = { cle = "metal", quantite = math.ceil(cale / 50) }  -- le bordé armé
  end
  return m
end

-- Le délai de construction, en JOURS. CALER : formule provisoire, à l'échelle de la
-- cale (un sloop de 200 t ~ 3 j, un galion de 600 t ~ 8 j). PR3 le calcule en direct
-- (offer time = constructing time, `0x58c890`) et le module le niveau du chantier ;
-- on n'a encore ni l'un ni l'autre en clair.
local function duree_construction(navire)
  return math.max(2, math.floor(navire.cale / 80 + 0.5))
end

-- Ce que coûte et exige la construction d'un type de navire : l'or (`Construct`,
-- EXACT), les matières et le délai (CALER). Renvoie nil si le type est inconnu.
function Chantier.recette(cle_type)
  local navire = Navires.get(cle_type)
  if not navire then return nil end
  return {
    cle = navire.cle,
    or_ = navire.construction,
    materiaux = recette_materiaux(navire),
    jours = duree_construction(navire),
  }
end

-- Le prix d'achat d'un navire tout fait : son `Value` — EXACT.
function Chantier.prix_achat(cle_type)
  local navire = Navires.get(cle_type)
  return navire and navire.prix or 0
end

-- Le NIVEAU de chantier qu'exige un type de navire. En PR3 un chantier plus grand
-- construit de plus gros navires ; on l'échelonne sur la cale (CALER : paliers
-- provisoires — petit ≤ 250, moyen ≤ 500, gros au-delà). Un chantier de niveau N
-- construit tout ce qui exige ≤ N.
function Chantier.niveau_requis(cle_type)
  local navire = Navires.get(cle_type)
  if not navire then return 99 end
  if navire.cale <= 250 then return 1 end
  if navire.cale <= 500 then return 2 end
  return 3
end

-- Un chantier de niveau `niveau_port` peut-il fournir ce type de navire ?
function Chantier.autorise(niveau_port, cle_type)
  return (niveau_port or 0) >= Chantier.niveau_requis(cle_type)
end

return Chantier
