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

## Combat naval — formules à confirmer

Les paramètres sont relevés (§ « Le combat naval ») ; les formules exactes —
comment un boulet touche selon l'angle et la dispersion, comment `DmgHull` /
`DmgSail` / `DmgCrew` s'appliquent aux points de vie d'un navire, comment
l'abordage se résout pas à pas — vivent dans des fonctions qui ne se lisent bien
qu'en exécution (traçage dynamique). Elles ne sont pas dans le périmètre de la
sim, qui ne simule pas le combat.

## État du rétro-engineering

| Sous-système | État |
|---|---|
| Économie, villes, prix, prospérité, réputation | **complet et appliqué à la sim** |
| Navires (caractéristiques), carte, eau, formats | **complet** |
| Convois de l'IA (modèle d'objet, taille, classes) | **structure lue**, décision dans une hiérarchie de classes |
| Bâtiments (coûts, matériaux, effets) | **complet** (effets lus des descriptions) |
| Combat naval (canon, abordage, forteresse) | **paramètres relevés**, formules à tracer en exécution |
| Diplomatie, rangs, licences, donations, lettres de marque | **mécanique lue** (18 rangs à la richesse, réputation double + dérive sinusoïdale) |
| Pirates, tempêtes, sauterelles, patrouilles, météo | **paramètres relevés** |
| Signaux de ville (conseiller) | **taxonomie complète lue** |
| Missions et quêtes | **identifiées** (couche scriptée sur les signaux) |
| Rendu, caméra, interface, audio, réseau | **hors du modèle de simulation** |

La liste exhaustive des 134 sections et 421 clés est reproductible par
`py -3 outils/config_map.py` (l'outil lit l'exécutable local, jamais commité).
