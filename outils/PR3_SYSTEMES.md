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

## État du rétro-engineering

| Sous-système | État |
|---|---|
| Économie, villes, prix, prospérité, réputation | **complet et appliqué à la sim** |
| Navires (caractéristiques), carte, eau, formats | **complet** |
| Convois de l'IA (modèle d'objet, taille, classes) | **structure lue**, décision dans une hiérarchie de classes |
| Combat naval (canon, abordage, forteresse) | **paramètres relevés**, formules à confirmer |
| Diplomatie, rangs, licences, donations | **paramètres relevés** |
| Pirates, tempêtes, sauterelles, patrouilles | **identifiés** |
| Missions et quêtes | **identifiées** (système d'événements) |
| Rendu, caméra, interface, audio, réseau | **hors du modèle de simulation** |

La liste exhaustive des 134 sections et 421 clés est reproductible par
`py -3 outils/config_map.py` (l'outil lit l'exécutable local, jamais commité).
