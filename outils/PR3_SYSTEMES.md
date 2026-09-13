# Les systèmes de Port Royale 3 — inventaire complet

Ce document est la **carte de tout PR3**, et le journal de son rétro-engineering.
Là où `sim/ECONOMIE_PR3.md` et `outils/PR3_TECHNIQUE.md` détaillent l'économie et
les formats, celui-ci recense **l'ensemble des systèmes pilotés par données** du
jeu, pour savoir ce qui est compris, ce qui ne l'est qu'en surface, et ce qui
reste à faire.

## D'où vient cet inventaire

PR3 lit tous ses réglages par cinq fonctions de chargement, chacune prenant une
**section**, une **clé** et une **valeur par défaut** :

| Fonction | Type lu |
|---|---|
| `0x89D6E0` | entier |
| `0x89D750` | flottant |
| `0x89D7C0` | tableau d'entiers |
| `0x89D8A0` | tableau de flottants |
| `0x89E270` | chaîne |

En balayant l'exécutable pour tous les appels à ces cinq fonctions et en
remontant les deux chaînes poussées juste avant (section, clé), on obtient le
**dictionnaire complet** : **134 sections, 421 clés** (`outils/config_map.py`).
La valeur par défaut poussée est celle qui s'applique quand `ini/constdata.dat`
ne la surcharge pas — souvent la valeur effective du jeu.

## Les grands sous-systèmes

### Économie et villes — **rétro-ingéniérie complète** (voir `ECONOMIE_PR3.md`)

`Data`, `Standardpreise`, `Warenverbrauch` / `Verbrauch`, `Produktion`,
`Grundbedarf`, `Minimalmengen`, `Rohstoffbedarf`, `Bauquotient_Mod`,
`Residential`, `Time`, `Lebensqualitaet`, `Schatzflotte`, `Export`, `Repairs`,
`Bauplatzkosten`, `Baukosten Betriebe`, `Bauplatzfaktor`, `Initial` (Konvois).

Consommation, prix, seuils, faim, fléaux, qualité de vie et prospérité,
construction de l'IA, réputation — tout est lu et appliqué à la sim.

### Navires — **complet** (voir `PR3_TECHNIQUE.md` §4)

`Vmax`, `Vmin`, `Wendig`, `Gauge`, `HitpointsSail`, `HullWidth`, `SailHeight`,
`SailLength`, `DailyCosts`, `Shipyard`, `AusbauKosten` / `AusbauWaren` (mise à
niveau au chantier).

### Combat naval — **paramètres relevés** (§ ci-dessous)

`Battleship` / `BattleShip`, `AmmoTrajectory`, `AmmoData`, `Condition_%d`
(`HullDamage`, `SailDamage`), `Boarding`, `Soldier`, `Captain`, `Fortress`,
`Obstacle`, `Shark`, `Sailor`, `Flotsam`, `DropGoods`, `Seabattle`, `Tactic`,
`Equipment`, `Mine`.

### Diplomatie et progression — **paramètres relevés**

`Licence` (`Rank`, `RepNation`, `RepTown`, `Buildings`), `Difficulty`
(`RepFactor`, `Create`, `Receive`), `Reputation` (`Offset`, `Amplitude`,
`Phase` — une dérive sinusoïdale de la réputation dans le temps), `Donation`
(`Ansehen`, `Pay`, `Steps`), `NationReputation` (`Annexed`), `Abwanderung`
(exode), `MinRank`, `minRankMil` / `maxRankMil` / `minRankPir`, `Player`.

### Événements et pirates — **identifiés**

`Pirate`, `Pirates` (`Activity`, `TownAttackDist`, `TownAttackLock`), `Storm`,
`Grasshopper`, `Patrol`, `Attraction`, `Weather`, `EventCount`,
`MissionDuration`, `Timer`.

### Monde, caméra, rendu — **hors modèle de simulation**

`Terrain`, `Roads`, `Colors`, `Stadtliste`, `Minimap`, `Anchorage`, `TownView`,
`TownDeco`, `Treasure`, `Video`, `Gui`, `Sails`, `SeaMapMovement`, `Fov`,
`Zoom*`, `Tilt*`, `Rot*`, `NearDist` / `FarDist` / `MinDist` / `MaxDist`,
`EffectSystem`, `Flotsam`, `Barrel`, `Assets`, `FadeIn` / `FadeOut`.

### Système et réglages — **hors jeu**

`Settings`, `Game`, `Init`, `Sound`, `Network`, `Multiplayer`, `Singleplayer`,
`Language`, `Autosave`, `GameSpeed`, `TimeSteps`, `Global`, `Info`, `Aktion`,
`SpecialEdition`.

## Le combat naval

Ce sous-système, le plus gros hors économie, se charge autour de `0x86C470`.

### Le tir au canon

**Trajectoire** (`[AmmoTrajectory]`, `0x86C5F9`) : les boulets ont une physique.

| Clé | Défaut | Sens |
|---|---|---|
| `Gravity` | 10 | chute du boulet |
| `Amax` | 30 | angle de tir maximal |
| `ACorrMax` | 5 | correction d'angle maximale |
| `FiringDelay` | 6 | délai entre deux bordées |
| `ScatterMin` / `ScatterMax` | 0,98 / 1,02 | dispersion (× la portée) |
| `AAimMax` | 2 | visée assistée |

**Munitions** (`[AmmoData]`, tableaux par type de boulet — rond, chaîné,
mitraille) : `Vmax_%d` (vitesse), `DmgHull_%d` (dégâts de coque), `DmgSail_%d`
(dégâts de voile), `DmgCrew_%d` (pertes d'équipage), `Asset_%d` (modèle). Chaque
type de boulet vise donc un organe : la coque pour couler, la voile pour
immobiliser, la mitraille pour l'équipage avant l'abordage.

**Maniement au combat** (`[Battleship]`, `0x86C470`) :

| Clé | Défaut | Sens |
|---|---|---|
| `MaxTurn` | 90 | rotation maximale |
| `ReloadTime` | 5 | rechargement (s) |
| `NavigationFactor` | 0,05 | inertie de barre |
| `TurnSpeedFactor` | 0,3 | vitesse de virage |
| `SinkSpeed` | −0,01 | vitesse de naufrage |

**Dégâts et vitesse** (`[Condition_%d]`, `0x86C961` / `0x86CA6C`) : l'état de la
coque (`HullDamage`) et des voiles (`SailDamage`) réduit la vitesse par un
`SpeedFactor_%d` — un navire éventré ou démâté ralentit. Le forteresse de la
ville (`[Fortress]`, `0x863C6E`) a ses propres canons (`Gun_%u_%02u`, positions),
sa `Range`, son `ReloadTime` et une table de coups `Hit`.

### L'abordage

`[Boarding]` (`0x86D1AD`) : quand deux navires s'accrochent, l'équipage se bat.

| Clé | Défaut | Sens |
|---|---|---|
| `Prepare` | 7 | temps d'accrochage (s) |
| `Start` | 3,5 | délai avant la mêlée |
| `Steps` | 20 | pas de résolution |
| `DmgMod` | 5 | modulation des dégâts |
| `HpModMax` | 3 | bonus de points de vie maximal |
| `DmgMuskets` | 2 | dégâts au mousquet |
| `DmgCutlass` | ~0,7 | dégâts au sabre |
| `DmgUnarmed` | (constdata) | dégâts à mains nues |
| `HpMuskets` / `HpCutlass` / `HpUnarmed` | (constdata) | points de vie selon l'arme |
| `MaxSpeed`, `CloseUpSpeed`, `MaxOffset` | | approche des navires |

Les combattants sont des `[Soldier]` (`0x863D5E`) : `UnitSize` 10, `UnitMax` 225,
`Health` 10, `Speed` 3, `RangeFactor` 1,4, `WalkFactor` 0,5, plus des tableaux
`Damage` et `Range` par type. Le `[Captain]` ajoute ses bonus (`Damage`,
`Boarding`), et gagne des compétences au fil des combats (`skill0…skill5`, voir
`PR3_TECHNIQUE.md`, « Les convois de l'IA »).

### L'environnement de la bataille

`[Shark]` (les requins tournent autour des naufragés : `KillTime`, `SpawnRadius`),
`[Sailor]` (les marins à la mer : `LifeTime` 120 s, `FallTime`, `DropChance` 0,2,
`PickupDist` 5), `[Obstacle]`, `[Flotsam]` (les épaves flottantes, `GoodsProb`,
`GoldProb`), `[DropGoods]` (le butin qui flotte). `[Limits]` borne les flottes :
`maxConvoys` 100, `maxConvoyMembers` 50, `maxShips` 50.

## Diplomatie, rangs et lettres de marque

**Le rang du joueur** monte avec sa RICHESSE (`0x63BAE0` nomme les titres). Dix-huit
rangs (`ID_RANK_MALE_00…17`, et leur variante féminine), du plus bas au plus haut :
« au fur et à mesure que votre richesse augmente, la jauge de progression se
remplit ; lorsqu'elle est pleine, vous passez au rang suivant ». Le rang ouvre des
droits :
- **plus de convois** autorisés, et plus de villes où bâtir ;
- l'accès aux **gouverneurs** (rang + réputation ≥ 25 %) et aux **vice-rois** (rang
  + réputation élevée auprès de la nation) ;
- les **concessions et licences** de l'architecte : entrepôt et maisons d'abord,
  puis manufactures — « plus votre rang est élevé et plus vous êtes présent dans
  de nombreuses villes, plus l'architecte fait payer cher la concession ».

Les seuils sont dans `[Licence]` (`Rank`, `RepNation`, `RepTown`, `Buildings`) et
`[MinRank]` (`Hospital`, `ShipYard` exigent un rang minimal). Les navires ont aussi
un rang requis (`minRankMil`, `maxRankMil`, `minRankPir` — voir `PR3_TECHNIQUE.md`).

**La réputation** est double (voir `ECONOMIE_PR3.md` §10.10) : par ville
(le commerce) et par nation (`NationReputation`, `[Licence]` `RepNation`). Une
composante de fond dérive dans le temps : `[Reputation]` `Offset` + `Amplitude` ×
sinus de `Phase` (des tableaux, `0x828D50`) — l'humeur des nations oscille
lentement, indépendamment du joueur.

**Les donations** (`[Donation]`) achètent de la réputation : `Pay` 10 pièces par
pas, `Ansehen` 0,01 de réputation par pas, `MaxSteps` 20 pas par don.

**Les lettres de marque.** En guerre, le vice-roi (si la réputation est assez
haute) accorde une lettre de marque contre une nation : on peut alors attaquer ses
navires et ses villes **sans perdre de réputation auprès des neutres**. Sans
lettre, toute attaque est de la piraterie et fait chuter la réputation auprès de
**toutes** les nations. `[Difficulty]` module cela (`RepFactor`, `Create`,
`Receive`), et `[GuildPrivilege]` / `StandardPaymentValue` tiennent les privilèges
de guilde.

**La partie** démarre en **novembre 1550** (`[GameStart]` `Year` 1550, `Month` 11).

## Pirates, tempêtes et météo

`[Pirates]` : `Activity` 250, `TownAttackDist` 200 (distance sous laquelle un
pirate attaque une ville), `TownAttackLock`. Les pirates ont leurs repaires
(classe `Hideout`, voir `PR3_TECHNIQUE.md`). Les fléaux et catastrophes naturelles
— `[Storm]` (tempêtes : `Months`, `Radius`, `Speed`), `[Grasshopper]` (sauterelles :
`Months`, `Radius`), `[Mine]` (mines flottantes), `[Patrol]` — sont des événements
mobiles sur la carte. La météo (`[Weather]` `Region%uRain`) fait pleuvoir par
région.

## Les bâtiments et leurs effets

Les quarante-trois fiches (coûts et matériaux) sont dans `ECONOMIE_PR3.md` §10.6.
Ce que chaque type FAIT, tiré des descriptions du jeu :

| Bâtiment | Effet |
|---|---|
| **Entrepôt** | +`BasicCapacity` (1 000) de stockage par entrepôt ; coûts quotidiens (`Lagermiete`) ; un gérant peut tenir les routes à la place du joueur |
| **Manufacture** | livre sa production à l'entrepôt chaque jour après y avoir pris ses intrants ; 25 ouvriers, **100 colons par manufacture** ; entretien fixe, donc plus elle produit plus elle est rentable |
| **Maison** | 100 locataires ; bâtie à `FillRate` de remplissage |
| **École** | +satisfaction et **+croissance des colons (jusqu'à +100 %)** ; n'agit que dans les villes riches ou prospères |
| **Hôpital** | +satisfaction et **réduit le risque de famine** |
| **Église** | +moral (fêtes), attire des colons, convertit les citoyens d'autres nations → +réputation |
| **Ambassade** | les galions d'une nation (réputation > 25 %) viennent acheter les denrées coloniales (teintures, café, cacao, tabac) et **déposent ~1 colon par denrée achetée** |
| **Caserne de pompiers** | réduit la propagation des incendies ; à bâtir près des manufactures à feu |
| **Hospice** | rend la ville plus attirante pour les colons en quête de travail |
| **Grand puits** | un réservoir retarde la sécheresse de plusieurs jours si la pluie manque |
| **Parc** | +qualité de vie, seulement au-delà de 5 000 habitants et au statut Prospérité |
| **Hôtel de ville, chantier naval, forteresse** | administration, construction navale, défense |

Ces bâtiments publics (école, hôpital, église, parc…) sont les **vingt derniers
points de qualité de vie** que la sim remplace par une dotation civique
(`ECONOMIE_PR3.md` §10.10) : l'école pousse les colons, l'hôpital retient la
famine, l'ambassade et l'église amènent des colons d'Europe. La croissance « même
sans immigration » qu'évoque le jeu est exactement la croissance à la prospérité
que la sim applique.

## La journée d'une ville, pas à pas — le cœur de la copie

Pour copier fidèlement PR3, l'ordre des opérations compte autant que les formules :
une même journée, jouée dans un autre ordre, ne donne pas les mêmes stocks. Le
répartiteur `0x7C2D20` exécute, pour chaque ville et chaque jour, **cette
séquence exacte** de vingt étapes (esi = la ville, edi = le monde) :

| # | Fonction | Rôle | État |
|---|---|---|---|
| 1 | `0x7BF8A0` | Seuils de prix X1–X4 **et** note de qualité de vie | **lu** |
| 2 | `0x7C1930` | Tirage d'incendie / déclin selon la surpopulation (fabriques × 2 000 vs habitants) et la qualité | lu (structure) |
| 3 | `0x7C2080` | Consommation des habitants + surconsommation des fléaux | **lu** |
| 4 | `0x7C0040` | **Production** : chaque atelier consomme ses intrants (`0x75FDA0`) et produit ses sorties dans l'entrepôt (`0x75FD40`) **au prix = coût de production** (`Grundkosten` + salaires ÷ production). C'est ici que le stock d'un bien produit augmente | **décortiqué** |
| 5 | `0x7BF160` | **Conseiller** : pour chaque problème qui dure depuis > 15 jours, lève un message avec une probabilité croissante `(nb × 3 + 10) × ancienneté` contre un tirage sur 1 000 (`0x841830` crée l'événement) | **lu** (décortiqué) |
| 6 | `0x7C2400` | Événements et conseiller : famine, fléaux, bits de prospérité | **lu** |
| 7 | `0x7C2B30` | Livraison de la production aux entrepôts (parcourt les ateliers) | lu (structure) |
| 8 | `0x7C26C0` | Niveau de prospérité (note → niveau, seuils 20/40/60/90, portes 2 000/6 000) | **lu** |
| 9 | `0x7C2900` | Recalcul des réserves + arrivée/départ des colons par les convois | lu (structure) |
| 10 | `0x7C0920` | Emploi et efficacité : lit les ouvriers d'un atelier (`+0x84`), la **réduit de moitié** en cas de manque d'ouvriers ou d'intrants, et déclenche les vérifications de construction (`0x7CBD40`/`0x7CB8E0`) | **décortiqué** |
| 11 | `0x7C1E40` | Construction par l'IA : bâtit un atelier si demande > `Bauquotient` × production | **lu** |
| 12 | `0x7C1A80` | Accumulation offre/demande par bien | observé |
| 13 | `0x7C1600` | Défense / garnison selon la taille de la ville | observé |
| 14 | `0x7BF2E0` | Conseiller (message d'immigration si `(+0x120 − +0x11C)/3 ≠ 0` et prospérité basse) + ajustement d'un bien sur les 4 premiers | **décortiqué** |
| 15 | `0x7BF3D0` | Conversion colons ↔ citoyens : ≤ 10/jour vers la cible de logement, tamponnée par le vivier de colons (voir « La démographie exacte ») | **décortiqué** |
| 16 | `0x7BF500` | Compteurs par nation | observé |
| 17-19 | `0x855BD0`, `0x855C00`, `0x767F20` | Finalisation de la structure économique | observé |
| 20 | `0x7C1B10` | Logement : bâtit des maisons à `FillRate` de remplissage | lu (structure) |

**L'entrepôt d'un comptoir**, tel qu'il ressort de la production et de la
consommation, a une disposition simple : le **stock** de chaque bien est à
`[comptoir + bien×4 + 0x18]`, son **prix moyen d'acquisition** à
`[comptoir + bien×4 + 0x68]`, et le **tonnage total** à `[comptoir + 0x14]`. Poser
du stock (`0x75FD40`) met à jour le prix moyen pondéré ; en retirer (`0x75FDA0`)
laisse le prix. La sim tient le même couple stock/prix moyen pour ses convois
(`m.achats`).

**La sim reproduit déjà les étapes 1, 3, 4, 5, 6, 7, 8, 9, 11 et 15** dans un
`jour()` condensé (`sim/economie.lua`), et dans le même ordre relatif :
production → consommation des habitants → ateliers sur le surplus → seuils, note,
prospérité, croissance. Les étapes 10, 12-14, 16-20 sont des raffinements de
gestion (emploi fin, garnison, mendiants, logement bâti) que la sim résume dans
sa démographie et sa dotation civique.

**Ce qu'une copie complète exige encore**, étape par étape : la math exacte de
chaque fonction ci-dessus marquée « structure » ou « observé », et surtout la
décision des convois (la hiérarchie `StoreKeeper` / `TradeContainer` / `Route`).
Ce document en est le plan : chaque adresse est un point d'entrée à décortiquer.

## La décision des convois

Décortiquée depuis l'orchestrateur d'escale `0x7CED60` : quand un convoi est à
quai, il **parcourt les vingt biens** et, pour chacun, décide d'acheter ou de
vendre par deux prédicats — `0x7CE600` (acheter ?) et `0x7CEC10` (vendre ?). Ces
prédicats ne sont pas un simple « le meilleur profit » : ils croisent

- le **type d'atelier** de la ville (`0x763F70`, `== 4` = elle produit ce bien) ;
- l'**état économique** (`[ville+0x6C]`) et des drapeaux (`[ville+0xAD]`) ;
- surtout l'**ordre de la route commerciale** : la quantité cible vient des seuils
  de l'ordre (`0x7CE790` lit `[+0x1E]`→`[+0x1C]` et la compare au stock).

L'échange est ensuite exécuté par `0x783E80` (qui déplace le prix, `0x859C20`, et
la réputation, `0x7839E0`). Autrement dit, **les convois de PR3 suivent des routes
avec des ordres par ville et par bien** (charger / décharger, avec des seuils),
pas une recherche de profit à la volée — le joueur trace les mêmes routes.

C'est le modèle que la sim approxime par « acheter le surplus au-dessus de X3,
décharger dans le manque » (`sim/marchands.lua`).

**La cible par bien** (`0x7CE790`) construit un tableau de vingt quantités visées —
une par marchandise — à partir de la taille de la ville (`[ville+0x158]`), des
`Minimalmengen`, de la production par ouvrier (struct économie `+0x34`) et des
masques de groupe (`0x854D50`). Le convoi charge ou décharge pour rapprocher le
stock de la ville de cette cible. C'est, au fond, **le même travail que les seuils
X1…X4 de la sim** comparés au stock : combien ce port veut de chaque bien.

Copier PR3 au bit près ici demanderait de décompiler ce calcul de cible
(230 instructions + `0x854D50`, `0x75B9E0`, la struct éco) et la structure des
ordres de route. L'entrée et la forme sont connues ; c'est un sous-chantier à part
entière, au gain comportemental modeste puisque la sim équilibre déjà la carte.

## La démographie exacte — décortiquée (`0x7BF3D0`)

C'est le cœur de la population, et la copie exacte diffère du modèle en pourcentage
de la sim. La ville tient trois nombres sur son objet économie (`[ville+0x6C]`) :

- **`+0xD0` = les colons** (le vivier, `0x765160` l'écrit) ;
- **`+0xD4` = les citoyens** (la population active, `0x765190`) ;
- **`+0xD8` = la cible** (population désirée, `0x7651C0`), calculée par `0x7BD9C0`
  à partir du logement et de `citoyens ÷ 4` (les quatre citoyens par ouvrier).

**Chaque jour, les citoyens se rapprochent de la cible d'AU PLUS DIX** (`0xA`), et
le vivier de colons bouge à l'inverse :

    si citoyens (d4) > cible (d8) :          -- trop de monde
        n = min(d4 − d8, 10)
        colons  += n                          -- ils repartent au vivier
        citoyens −= n
    sinon si citoyens (d4) < cible (d8) :     -- de la place
        n = min(d8 − d4, colons, 10)          -- bornée aussi par les colons dispo
        colons  −= n                          -- ils s'installent
        citoyens += n

**La conséquence est forte pour une copie fidèle** : PR3 ne fait pas croître une
ville d'un pourcentage, mais d'un **nombre plat, dix habitants par jour au plus**,
vers une cible bornée par le logement. Un bourg de 900 âmes croît donc à ~1 %/jour,
une ville de 9 000 à ~0,1 %/jour — la croissance relative ralentit toute seule avec
la taille, sans qu'aucun taux ne soit écrit. Et rien ne bouge sans **colons dans le
vivier** : c'est là qu'entrent l'immigration (église, ambassade, hospice, école)
et la sortie par la mer.

**Le logement**, ensuite : la ville vise `citoyens ÷ 100 + 1` maisons (plafonné à
10 par passe), et bâtit (`0x7BDD00`) tant qu'il en manque, ou en retire quand
`maisons × 1000 > citoyens + 1500`. Cent locataires par maison, confirmé.

*Implication pour la sim* : sa démographie en pourcentage (Pauvreté −2 %/j, etc.)
est une approximation raisonnable ; le modèle exact de PR3 est une **file de dix
par jour vers une cible de logement, tamponnée par un vivier de colons**. Candidat
de raffinement, à porter si l'on veut la courbe de population au plus près.

## Les signaux d'une ville (le conseiller)

PR3 tient, par ville, une liste de raisons qui expliquent son état — ce que le
conseiller affiche. L'énumération (`0x68E310`, `0x68E440`) en donne le vocabulaire
complet :

- **Manques économiques** : `missing_raw` (intrants manquants), `missing_worker`
  (ouvriers manquants), `storage_cost` (entrepôt trop cher), `workload` (surcharge),
  `housing` (logement insuffisant), `materials` / `materials_ship` (matériaux de
  construction), `construct` (chantier), `nofood` (famine), `townwealth`
  (prospérité).
- **Convois** : `convoy_idle` (convoi inactif), `convoy_hp` (convoi endommagé),
  `route` / `route_idle` (route commerciale à l'arrêt).
- **Personnel** : `teacher` (école), `admin` (gérant d'entrepôt), `gouv`
  (gouvernance).
- **Événements** : `plague` (peste), `grashopper` (sauterelles), `fire` (feu),
  `drought` (sécheresse), `blizzard`, `attack_sea` (attaque en mer), `feast`
  (fête), `rouge`, `mission`.

Les trois premiers manques (`missing_raw`, `missing_worker`, `nofood`) et
`townwealth` sont exactement ce que la sim calcule (rendement des ateliers,
subsistance, qualité) ; `Bridge.besoin_prioritaire` et `etat_ville` en sont
l'écho. Les événements recouvrent les fléaux (§ économie).

Les missions et quêtes de la campagne sont une couche scriptée par-dessus (durée
d'affichage `[MissionDuration]`, comptage `[EventCount]`, drapeaux de nations
`[Flags]`), qui déclenche ces mêmes signaux — hors du modèle économique.

## Combat naval — deux régimes

Il faut distinguer deux combats, et c'est décisif pour la copie :

**1. Le combat MANUEL (temps réel)** — celui qu'on joue. Le boulet a une physique
(`AmmoTrajectory` : gravité, dispersion), touche selon l'angle et la distance, et
`DmgHull` / `DmgSail` / `DmgCrew` s'appliquent en continu. Ces formules-là vivent
dans des fonctions temps réel (`0x86C470` et suivantes) qui ne se lisent bien
qu'en exécution. À garder pour la fin, et par traçage dynamique.

**2. Le combat AUTOMATIQUE (déterministe) — LISIBLE STATIQUEMENT.** Quand la
bataille n'est pas jouée à la main — IA contre IA, choix « combat automatique »
(`ID_GUI_AUTOMATIC_BATTLE`, `0x56CAE0`), ou fin du compte à rebours en multijoueur,
« le résultat est déterminé automatiquement, de la même façon que le mode
automatique » — PR3 **calcule l'issue d'une formule**, pas d'une simulation.

Le modèle, confirmé par la fenêtre de bataille (`0x568650`) et les textes, repose
sur une **PUISSANCE par camp**, affichée poste par poste : navires de combat,
navires marchands, canons, marins, et la **puissance de convoi** qui en résulte.
La puissance d'un navire « reflète le nombre de canons, sa maniabilité et le
nombre de marins à bord » — avec **4 marins par canon idéalement, 5 au maximum**
(`CrewmenAtGun`). Seuls les **navires d'escorte (3 au plus)** combattent ; les
marins du convoi y sont répartis automatiquement au début du combat. L'issue
compare les deux puissances (`tf_convoystrength_attacker` / `_defender`,
`0x568650` / `0x6C5970`) et en déduit le vainqueur et les pertes ; le résultat est
gardé dans le journal (`TabChronicPower`, `info_last_battle`).

Réglages associés : `[Equipment]` (`PriceStandard`, `PricePirates` — prix des
canons/munitions), `[Repairs]` (`Zeit`, `Kosten` — temps et coût de réparation),
`[Tactic]` (`MaxFleeDist`, `SecUpdateFleetAi` — l'IA décide d'attaquer ou fuir sur
le rapport de puissance).

**Le modèle des 3 navires de combat est confirmé dans le code.** Un convoi porte
un compteur de navires de combat (`[convoi+0xF9C]`, `0x4B7A50` le gère : « nombre
de navires de combat du convoi ») ; seuls ces navires d'escorte (3 au plus)
comptent. Chaque navire de combat est un composant ECS `Client::BattleShipComponent`
(`0x677F70`), et la **puissance par camp** est affichée par la fenêtre de bataille
(`0x568650`), le classement des puissances (`0x5550C0`, `power.li`) et le journal
(`TabChronicPower`).

**Mais la puissance est une valeur MISE EN CACHE.** Toutes ces vues la *lisent*
sur l'objet (un champ flottant du camp de bataille, p. ex. `[+0x74]`) ; aucune ne
la recalcule. L'arithmétique qui la remplit vit dans la mise à jour du composant,
recalculée quand la composition d'escorte change — et elle résiste aux points
d'entrée statiques (ECS + GUI l'enveloppent).

**Les données de combat, trouvées dans l'exe.** Chaque navire porte, à l'exécution
(vidage `Ship` `0x880C6C`) : `actHp` (+0x28), `maxHp` (+0x2C), `actCrew` (+0x30),
`maxCrew` (+0x34, mot), `type` (+0x3A), **`guns`** (+0x3B, octet = nombre de
canons, tiré des positions `GunPos%02u`) et le drapeau **`battleShip`** (+0x3C).
Les cinq stats affichées d'un navire sont `heart` (PV), `cannon`, `crew`,
`strength`, `barrels` (`0x68E2A0`).

**La puissance est mise en cache** : toutes les vues (fiche de convoi `0x608700`,
fenêtre de bataille `0x568650`, classement `0x5550C0`) et l'auto-combat la
**lisent** sur l'objet, via un emplacement d'affichage générique (`[+0x30]+0x7C`,
partagé avec les autres stats). Aucune ne la recalcule. L'écriture — la formule qui
combine `guns`, `crew` (≤ 5/canon) et la maniabilité — est déclenchée quand la
composition du convoi change, dans la couche de composants ECS
(`BattleShipComponent`).

**Où en est la traque, honnêtement.** Toutes les DONNÉES d'entrée sont dans l'exe
et localisées (canons par navire `guns`+0x3B, équipage +0x30/+0x34, PV +0x28/+0x2C,
maniabilité, drapeau de combat +0x3C). Le modèle est confirmé (somme sur les 3
navires de combat). Mais la FORMULE elle-même est calculée une fois dans l'ECS et
rangée en cache ; chaque chemin lisible statiquement (fiche, bataille, classement,
composant, export debug) lit ce cache, jamais l'arithmétique. C'est le seul chiffre
du jeu qui résiste à la lecture statique par les chemins accessibles.

Deux voies pour l'obtenir exactement, aucune n'étant de l'intuition :
1. **Décompiler la mise à jour du composant ECS** qui écrit la puissance (long : il
   faut d'abord reconstituer la disposition mémoire de `BattleShipComponent`).
2. **Lire la puissance que le jeu AFFICHE** sur la fiche d'un convoi pour quelques
   compositions connues (un navire de canons/marins donnés, puis deux, puis trois).
   Ce n'est pas deviner : c'est lire la sortie authentique de PR3. Trois ou quatre
   relevés donnent la formule exacte.

## État du rétro-engineering

| Sous-système | État |
|---|---|
| Économie, villes, prix, prospérité, réputation | **complet et appliqué à la sim** |
| Navires (caractéristiques), carte, eau, formats | **complet** |
| Convois de l'IA (modèle d'objet, taille, classes) | **structure + entrée de décision lues** : routes à ordres par bien (`0x7CED60`) |
| Bâtiments (coûts, matériaux, effets) | **complet** (effets lus des descriptions) |
| Combat AUTOMATIQUE (puissance par camp, issue déterministe) | **modèle et entrées lus** ; formule décompilable statiquement |
| Combat MANUEL (canon temps réel, abordage) | **paramètres relevés**, formules à tracer en exécution |
| Diplomatie, rangs, licences, donations, lettres de marque | **mécanique lue** (18 rangs à la richesse, réputation double + dérive sinusoïdale) |
| Pirates, tempêtes, sauterelles, patrouilles, météo | **paramètres relevés** |
| Signaux de ville (conseiller) | **taxonomie complète lue** |
| Missions et quêtes | **identifiées** (couche scriptée sur les signaux) |
| Rendu, caméra, interface, audio, réseau | **hors du modèle de simulation** |

La liste exhaustive des 134 sections et 421 clés est reproductible par
`py -3 outils/config_map.py` (l'outil lit l'exécutable local, jamais commité).
