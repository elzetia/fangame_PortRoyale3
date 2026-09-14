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
remontant les deux chaînes poussées juste avant (section, clé) — en coupant aux
frontières d'appel, sans quoi une clé emprunte la section de sa voisine — on
obtient le **dictionnaire complet** : **82 sections, 455 clés**
(`outils/config_map.py`). Certaines sections sont **formatées à l'exécution**
(`[Ship%02u]`, `[Town%02u]`) et n'existent nulle part comme chaîne : leurs clés
sont rangées sous `(section calculée)` plutôt que rattachées à une section
inventée.
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

#### Le rang — mécanique établie, seuils introuvables

**L'échelle** fait dix-huit échelons et elle est NAVALE, pas marchande : Mousse,
Novice, Matelot, Marinier, Enseigne, Officier marinier, Officier major,
Timonier, Navigateur, Commandant, Capitaine, Cap. de corvette, Contre-amiral,
Vice-amiral, Amiral, V-amiral d'escadre, Amiral d'escadre, Maître des mers. La
carrière pirate a son propre libellé unique (`ID_RANK_PIRATE_MALE_00`,
« Pirate »). Vérifié deux fois et par deux voies indépendantes : la table de
textes du jeu (`ID_RANK_MALE_00`…`_17`) et les titres de dix-neuf sauvegardes
réelles, de « Mousse_Steven » à « Amiral_Elzetia ». Les deux séries ne sont pas
des copies : au rang 15 le masculin dit « V-amiral d'escadre », le féminin
« Grand amiral ».

**Où il vit** : un OCTET en `joueur + 0x30A` (le sexe juste à côté, en +0x311).
Lu par `0x43E420` ; seulement trois écritures dans tout l'exe — la mise à zéro
du constructeur (`0x75B194`) et deux mutateurs jumeaux (`0x759C70`, `0x759C90`),
qui lèvent tous deux le drapeau « ce champ a changé » (`0x200`). Le numéro
devient un nom par une table de saut en `0x63BAE0`, qui prend le rang et le
sexe. Des portes en dur le consomment : hôpital ≥ 10, chantier ≥ 12,
licence ≥ 10.

**La règle de montée** (`0x7C6C80`) : le jeu demande l'enregistrement du rang
SUIVANT, n'avance que D'UN CRAN, et seulement si les TROIS seuils de cet
enregistrement sont franchis ; il plafonne à dix-huit (`cmp esi, 0x12`). Les
grandeurs comparées sont une richesse 64 bits, une somme de capacité, et un
troisième cumul bâti sur les comptoirs. Cela recoupe
`ID_TOWNBUILDER_LICENCE_RANK`, qui dit que le rang monte avec les *richesses* et
la *capacité des soutes*.

**Les seuils, eux, sont introuvables dans le jeu livré**, et c'est un résultat
négatif solide, pas un abandon. PR3 les lit sous `[Rank] Requirements%02u` ;
cette clé n'existe :

- dans aucun des 9433 fichiers des trois `.fuk` (relus sans une seule erreur de
  décompression — un premier balayage avalait les échecs en silence) ;
- dans aucun des deux `constdata.dat`, cherchés sous dix dispositions, dont
  celle LUE dans le désérialiseur `0x814510` (compte `u32` puis enregistrements
  de 16 octets) et non devinée ;
- dans aucun fichier libre du dossier de jeu ;
- dans aucune des dix-neuf sauvegardes.

Faute de clé, le chargeur remplit le tampon avec son défaut (`rep stosd` avec 0,
en `0x89D87C`), et le constructeur de table sort dès son premier tour, sur
`arr[1] == 0`. `sim/compagnie.lua` implémente donc la RÈGLE avec une table VIDE :
le jour où ces nombres seront retrouvés, seule la table changera.

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

Les seuils, décodés dans le grand chargeur de config (`0x8297e1`, `0x865a90`) :
- **Droit aux convois** : on démarre à `[Initial] Konvois` = **3** ; le rang le fait
  monter jusqu'au plafond dur `[Limits] maxConvoys` = **100** (avec `maxConvoyMembers`
  50 et `maxShips` 50, voir la section chantier).
- **Concessions de l'architecte** : `[Licence]` = `Rank` **10**, `RepNation` **5**,
  `RepTown` **5**, `Buildings` **3** (le seuil de base pour obtenir une licence).
- **Exigences par bâtiment / palier** : des sections `[Requirements%02u]`, chacune
  avec un tableau `Rank` de 4 (rang et réputations requis) — c'est la grille fine des
  droits de construction.
- **Bâtiments à rang minimal** : `[MinRank]` `ShipYard`, `Hospital`.
- **Navires** : rang requis `minRankMil`, `maxRankMil`, `minRankPir` (par `[Ship%02u]`,
  voir la section chantier).
- **Annexion** : `[NationReputation] Annexed` = 200.

Les DIX-HUIT titres eux-mêmes (`ID_RANK_MALE_00…17`) et la table des seuils de
richesse qui les sépare vivent dans les données localisées (`.fuk`), pas dans
l'exécutable : c'est un relevé à part si l'on veut la courbe exacte. La sim ne modélise
pas encore le rang du joueur ; elle prendra ces chiffres quand elle le fera.

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

## Le chantier naval : acheter, construire, réparer

Le chantier est un **dialogue à cinq onglets** (`DialogShipyard`, classes NGUI
natives, `0x45781f` monte le dialogue) :

| Onglet | Classe NGUI | Ce qu'il fait |
|---|---|---|
| **Build** | `TabShipyardBuild` (`0x58c0f0`) | **construire** un navire neuf : or + marchandises + délai |
| **Buy** | `TabShipyardBuy` (`0x58dd70`) | **acheter** un navire tout fait, au prix `Value` |
| **Sell** | `TabShipyardSell` (`0x58d0c0`) | revendre un navire |
| **SellPirate** | `TabShipyardSellPirate` (`0x58cee0`) | le revendre aux pirates (autre cote) |
| **Repair** | `TabShipyardRepair` (`0x58e7b0`) | réparer la coque |

**Acheter (Buy).** Le prix est le `Value` du type de navire (défaut 10 000, valeur
réelle par navire dans `[Ship%02u]`). Livraison quasi immédiate — un petit délai
`[Time] Einkaufszeit` = 64 pas.

**Construire (Build) — le cœur.** Choisir un type produit une *offre de construction*
(objet `ShipConstructionOffer`, lu par `0x5ec150`). La méthode qui la met en forme
(`0x58c890`) affiche, depuis cet objet : cale (barils), canons, coque, équipage, un
**prix en or** (format monnaie), une **durée de construction** (un seul chiffre :
« offer time » = « constructing time »), et **jusqu'à 4 marchandises avec quantité**
(paires (marchandise, quantité flottante), boucle `0x58cae0`, accès `+0x2a4`). L'offre
signale si la ville A les marchandises (`prod.visible`) et si l'or suffit. Donc
**construire = payer de l'or + consommer jusqu'à 4 marchandises + attendre un délai**,
là où **acheter = payer le plein `Value`, tout de suite**. Le classique de Port Royale :
on construit moins cher (contre matières + temps) à son PROPRE chantier, on achète au
prix fort partout.

Les accesseurs de l'offre : matériaux à `+4` (`0x437570`), bloc prix/durée à `+0x12b4`
(`0x437710`). **La recette exacte** (quelles marchandises, combien, quel or, quelle
durée par navire) est **calculée en direct** à la sélection à partir de l'état de la
ville et du type de navire — ce n'est pas une table plate de config. Comme la
puissance de combat, ce dernier chiffre se lit le plus sûrement **en jeu** (construire
quelques navires et relever or + marchandises + jours) ; le mécanisme, lui, est
entièrement décortiqué ci-dessus.

**Réparer (Repair).** `[Repairs]` : `Zeit` = 30 (facteur de temps, plancher 1),
`Kosten` = 50 (coût à l'unité de coque). `0x8557c2`.

**Le bâtiment chantier** (dans la ville) : rang minimal pour le bâtir dans
`[MinRank] ShipYard`. On le **monte de niveau** — `[AusbauKosten] Upgrade_Shipyard:i[]`
(or par palier) et `[AusbauWaren] Upgrade_Shipyard:i[]` (marchandises par palier),
chargés par le loader générique des bâtiments `0x85505c` ; un niveau plus haut débloque
de plus gros navires. `[Shipyard] RotateTime` n'est que la rotation de la vue.

**Stats d'un navire** — chaque type a sa section `[Ship%02u]`, lue par `0x85f760` :
`Capacity` (obligatoire), `Hitpoints` (**×1000 en interne**), `HitpointsSail` (×1000),
`Value` (10 000 défaut), `minRankMil`/`maxRankMil`/`minRankPir`, `Vmin` 20 / `Vmax` 28 /
`Wendig` 60, puis la géométrie 3D (coque, voiles, `GunPos%02u`). Il n'y a **pas** de
champ `Construct`/`Bauzeit`/matériaux dans cette table : c'est bien l'offre qui les
calcule.

**Limites de flotte** (`[Limits]`, `0x8299d9`) : `maxConvoys` 100, `maxConvoyMembers`
50, `maxShips` 50. **Canons** (`[Equipment]`) : `PriceStandard[6]` et `PricePirates[6]`,
six calibres. **Délais** (`[Time]`, en pas de jeu) : achat 64, vente 64, accostage 128.

## La journée d'une ville, pas à pas — le cœur de la copie

Pour copier fidèlement PR3, l'ordre des opérations compte autant que les formules :
une même journée, jouée dans un autre ordre, ne donne pas les mêmes stocks. Le
répartiteur `0x7C2D20` exécute, pour chaque ville et chaque jour, **cette
séquence exacte** de vingt étapes (esi = la ville, edi = le monde) :

| # | Fonction | Rôle | État |
|---|---|---|---|
| 1 | `0x7BF8A0` | Seuils de prix X1–X4 **et** note de qualité de vie | **lu** |
| 2 | `0x7C1930` | **Déclencheur de fléau/feu par surpopulation** : si citoyens > `[+0x112] × 2000` (seuil de logement), un tirage `RNG % 30000` déclenche un événement négatif — d'autant plus probable que la ville est surpeuplée | **décortiqué** |
| 3 | `0x7C2080` | Consommation des habitants + surconsommation des fléaux | **lu** |
| 4 | `0x7C0040` | **Production** : chaque atelier consomme ses intrants (`0x75FDA0`) et produit ses sorties dans l'entrepôt (`0x75FD40`) **au prix = coût de production** (`Grundkosten` + salaires ÷ production). C'est ici que le stock d'un bien produit augmente | **décortiqué** |
| 5 | `0x7BF160` | **Conseiller** : pour chaque problème qui dure depuis > 15 jours, lève un message avec une probabilité croissante `(nb × 3 + 10) × ancienneté` contre un tirage sur 1 000 (`0x841830` crée l'événement) | **lu** (décortiqué) |
| 6 | `0x7C2400` | Événements et conseiller : famine, fléaux, bits de prospérité | **lu** |
| 7 | `0x7C2B30` | **Efficacité des ateliers** : une manufacture qui ne peut tourner (manque d'ouvriers/intrants, test `0x946310`) perd **1 point d'efficacité/jour** (`[+0x92]−1`, `0x7632D0`) ; les chantiers (type `0x29`) émettent un événement. La production (étape 4) est mise à l'échelle par cette efficacité | **décortiqué** |
| 8 | `0x7C26C0` | Niveau de prospérité (note → niveau, seuils 20/40/60/90, portes 2 000/6 000) | **lu** |
| 9 | `0x7C2900` | **Dispatcher de croissance** : somme le stock des 20 biens (`E+0xE2`) ; si `stock × 4 > capacité d'entrepôt (E+0xC8)` ou mauvais état → décline/ralentit (`0x7C0BD0`), sinon croît vers la capacité (`0x7C0F90`) ; gère les jalons de grande ville (> 8 000 citoyens) et met à jour les colons | **décortiqué** |
| 10 | `0x7C0920` | Emploi et efficacité : lit les ouvriers d'un atelier (`+0x84`), la **réduit de moitié** en cas de manque d'ouvriers ou d'intrants, et déclenche les vérifications de construction (`0x7CBD40`/`0x7CB8E0`) | **décortiqué** |
| 11 | `0x7C1E40` | Construction par l'IA : bâtit un atelier si demande > `Bauquotient` × production | **lu** |
| 12 | `0x7C1A80` | Accumulation offre/demande par bien | observé |
| 13 | `0x7C1600` | Garnison / défense selon la taille (militaire, hors économie) | **caractérisé** |
| 14 | `0x7BF2E0` | Conseiller (message d'immigration si `(+0x120 − +0x11C)/3 ≠ 0` et prospérité basse) + ajustement d'un bien sur les 4 premiers | **décortiqué** |
| 15 | `0x7BF3D0` | **Emploi** : ouvriers employés → cible (citoyens ÷ 4 selon la taille) d'au plus 10/jour, depuis le vivier d'ouvriers (voir « Population, main-d'œuvre et logement ») | **décortiqué** |
| 16 | `0x7BF500` | Met à jour des compteurs par nation à partir des citoyens (statistiques, non économique) | **caractérisé** |
| 17-19 | `0x855BD0`, `0x855C00`, `0x767F20` | **Indicateurs dérivés** : emploi %, richesse par tête (`citoyens × 100 × 100`), et publication des champs de synthèse de la ville (`+0x134…+0x140` : actElq, actAlq…). Ne changent pas l'état, ils le publient | **décortiqué** |
| 20 | `0x7C1B10` | Logement : bâtit/retire des maisons pour viser `citoyens ÷ 100 + 1` (100 locataires/maison → capacité `maisons × 100`) | **décortiqué** |

**L'état économique d'une ville est donc entièrement décortiqué** : toutes les
étapes qui MODIFIENT l'état (2 fléau, 3 consommation, 4 production, 6 prospérité,
7 efficacité, 8 niveau, 9 croissance, 10-15 emploi, 11 construction, 20 logement)
ont leur math exacte ci-dessus et dans `ECONOMIE_PR3.md`. Les étapes 5, 12, 13, 16,
17-19 sont du conseiller, de la détection d'inactivité, de la garnison, des
compteurs et des indicateurs dérivés — elles lisent l'état, ne le changent pas.

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

### La structure d'une route commerciale — décodée

Une route (le joueur en trace, l'IA en reçoit) est **une liste de `Waypoint`**
(escales, chacune avec un `id` de ville et une position `posx/posy`) ; à chaque
escale, une liste de `MoveableEntries` — les **ordres**. Le schéma d'un ordre,
lu dans son (dé)sérialiseur (`0x8801C0`, `0x880D7C`) :

    { town, office, good, amount, action = "set_goods" }

soit : « à l'escale *town*, dans l'entrepôt *office*, amène la marchandise *good*
à la quantité *amount* ». Le convoi charge si le stock est sous la cible, décharge
s'il est au-dessus — la cible par bien et par escale que le joueur règle dans
l'interface de route (« charger jusqu'à X », « décharger jusqu'à X »). Les
**stratégies automatiques** (Profit, Prospérité, Matières premières, Matériaux de
construction, Entrepôts vides — voir `PR3_TECHNIQUE.md` §5) sont des générateurs
qui remplissent ces mêmes ordres tout seuls.

C'est le modèle exact de PR3, joueur comme IA. La sim l'implémente déjà **en
esprit** : ses convois chargent ce qui dépasse le plateau (`stock − X3`) et
déchargent dans le manque — c'est-à-dire qu'ils poussent chaque bien vers une
cible par escale, la cible étant le seuil de référence. Le mot `set_goods` n'est
que l'étiquette de sérialisation ; le générateur pose une action-entier.

### Les neuf stratégies automatiques (`0x63D6E0`)

L'index de stratégie (0 à 8) d'une route, et son sens (les six premières sont
décrites au tutoriel, `PR3_TECHNIQUE.md` §5) :

Noms internes EXACTS (table de saut `0x68e6b8`, mappeur `0x68e620`) :

| # | Nom interne | Sens (tutoriel) | Ordres générés |
|---|---|---|---|
| 0 | `manuell` | Manuel | aucun — le joueur pose les ordres à la main |
| 1 | `wealth` | Prospérité | échange les produits qui promettent le plus de profit |
| 2 | `profit` | Profit | achète bas, vend haut, tous biens confondus |
| 3 | `stock` | Entrepôts vides | vide un entrepôt et décharge au premier suivant |
| 4 | `rawmaterials` | Matières premières | répartit les matières premières là où elles manquent |
| 5 | `office` | Comptoirs | approvisionne les comptoirs du joueur |
| 6 | `materials` | Matériaux de construction | bois et briques, jusqu'à 500 / 1 000 |
| 7 | `distribute` | Distribution | disperse les biens depuis un centre vers les voisins |
| 8 | `central` | Centralisation | rassemble les biens des voisins vers un centre |

Chaque stratégie est un générateur qui remplit les ordres `set_goods` d'une route
automatiquement ; leur logique fine (par stratégie) reste à décompiler une à une,
mais leur sémantique est connue (tutoriel + noms).

## Population, main-d'œuvre et logement — la carte des champs

Décodés sur l'objet économie de la ville (`[ville+0x6C]`, noté E) :

- **`E+0xC0` = citoyens** (la population ; c'est ce que la famine à 300 et les
  seuils de prospérité 2 500 / 6 000 regardent) ;
- **`E+0xC8` = capacité de logement** (le maximum de citoyens) ;
- **`E+0xD4` = ouvriers employés**, **`E+0xD0` = ouvriers disponibles** (le vivier),
  **`E+0xD8` = cible d'ouvriers**.

Il y a donc **deux couches**, à ne pas confondre (je les avais d'abord mêlées) :

**1. L'EMPLOI** (`0x7BF3D0`). Les ouvriers employés (`d4`) se rapprochent chaque
jour de la cible (`d8`) d'**au plus dix**, le vivier disponible (`d0`) bougeant à
l'inverse (conservation `d0+d4`) :

    si d4 > d8 :  n = min(d4 − d8, 10) ;      d0 += n ; d4 −= n   -- on débauche
    si d4 < d8 :  n = min(d8 − d4, d0, 10) ;  d0 −= n ; d4 += n   -- on embauche

La **cible d'ouvriers** `d8` (`0x7BD9C0`) est une fraction des citoyens, selon la
taille de la ville, bornée à [300, 1500] :

| Taille (`+0x15A`) | Cible d'ouvriers |
|---|---|
| bourg (1) | citoyens ÷ 8 |
| ville (2) | citoyens × 3 ÷ 16 |
| grande ville (3) | citoyens ÷ 4 (les 4 citoyens/ouvrier) |

(En état d'événement, `[ville+0x36] ≥ 4`, la cible vient d'un autre calcul,
`0x856C00`, ou vaut 100.)

**2. LA POPULATION** (`0x7C0BD0` / `0x7C0F90`). Les citoyens (`E+0xC0`) croissent
vers la **capacité de logement** (`E+0xC8`), d'un montant journalier **décodé** :

    croissance = (place libre) × facteur_nation ÷ diviseur

- **place libre** = capacité − citoyens (ce qui reste à peupler) ;
- **diviseur** = 200 si l'état `[E+0x158]` est nul (rapide), 400 sinon (lent) —
  donc ~0,5 %/jour de la place libre au mieux, ~0,25 % au ralenti ;
- **facteur_nation** = coefficient d'immigration par nation et difficulté
  (`0x828900`, tiré de `[Difficulty]` et de la nation du propriétaire).

La croissance ralentit donc d'elle-même à l'approche de la capacité, et rien ne
dépasse le logement. La **capacité** suit les maisons : la ville vise
`citoyens ÷ 100 + 1` maisons (plafond 10 par passe), bâtit (`0x7BDD00`) tant qu'il
en manque, en retire quand `maisons × 1000 > citoyens + 1500`. Cent locataires par
maison — la capacité est donc `maisons × 100`, et elle croît avec la ville jusqu'aux
plafonds de prospérité (2 000 pour Prospérité, 6 000 pour Opulence).

*Implication pour la sim* : le modèle exact de PR3 est **citoyens += (capacité −
citoyens) × facteur ÷ 200** (approche exponentielle de la capacité de logement),
plus une couche d'emploi visant citoyens ÷ 4 — à porter tel quel pour la courbe de
population fidèle. La démographie en pourcentage actuelle de la sim en est une
approximation.

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
l'écho. Les événements recouvrent les fléaux (§ économie). **Leur déclencheur est décodé**
(`0x7C1930`, étape 2 de la journée) : c'est la **surpopulation** — quand les
citoyens dépassent un seuil dérivé du logement (`[+0x112] × 2000`), un tirage
`RNG % 30000` peut déclencher un fléau, d'autant plus probable que la ville est
surpeuplée. (La sim les tire d'après la qualité de vie, ce qui en est une
approximation raisonnable.)

Les missions et quêtes de la campagne sont une couche scriptée par-dessus (durée
d'affichage `[MissionDuration]`, comptage `[EventCount]`, drapeaux de nations
`[Flags]`), qui déclenche ces mêmes signaux — hors du modèle économique.

## Combat naval — deux régimes

Il faut distinguer deux combats, et c'est décisif pour la copie :

**1. Le combat MANUEL (temps réel)** — celui qu'on joue. Le boulet a une physique
(`AmmoTrajectory`), touche selon l'angle et la distance, et `DmgHull` / `DmgSail` /
`DmgCrew` s'appliquent au coup. Les PARAMÈTRES sont **décodés statiquement** (loader
`0x86C470`) — tout est dans les fichiers, il n'y a rien qui « n'existe qu'à
l'exécution » :

- **`[Battleship]` (physique du navire en bataille)** : `MaxTurn` 90, `MaxAccel` 1,
  `ReloadTime` 5 s, `NavigationFactor` 0.05, `TurnSpeedFactor` 0.3, `SinkSpeed` −0.01,
  `SpeedFactor` 1.
- **`[AmmoTrajectory]` (le boulet)** : `Gravity`, `Amax`, `ACorrMax`, `FiringDelay`,
  `ScatterMin`, `ScatterMax`, `AAimMax`.
- **`[AmmoData]` (4 types de munition) — DÉCODÉ** (table `constdata`, ancre
  `cannonball0`, `outils/pr3_constdata.py`). Vmax, puis dégâts coque/voiles/équipage
  (à comparer aux PV internes = `Hitpoints` ×1000 ; un sloop a 110 000 de coque) :

  | Munition | Vmax | Coque | Voiles | Équipage | Rôle |
  |---|---|---|---|---|---|
  | boulet | 424 | **1000** | 100 | 300 | polyvalent, anti-coque |
  | chaîne | 366 | 200 | **1500** | 100 | anti-voiles (immobilise) |
  | mitraille | 312 | 300 | 100 | **800** | anti-équipage (abordage) |
  | lourd | 554 | **2500** | **2500** | 100 | gros dégâts coque + voiles |
- **`[HullDamage]` / `[SailDamage]`** : paliers `Condition_%d` (%, jusqu'à 100) →
  `SpeedFactor_%d` : une coque/voilure abîmée ralentit le navire par paliers.
- **`[Boarding]` (l'abordage) — décodé** : `Prepare` 7, `Start` 3.5, `DmgMod` 5,
  `HpModMax` 3 ; dégâts d'arme **mousquet 2 / sabre 1 / mains nues 0.7**, points de
  vie **mousquet 5 / sabre 10 / mains nues 10** ; `MaxSpeed` 25, `CloseUpSpeed` 5.
- **`[Captain]`** : bonus `Damage` et `Boarding` du capitaine (tableaux par niveau).
- **`[Ship] CrewmenAtGun`**, **`[Tactic]`** (`MaxFleeDist`, `SecUpdateFleetAi`),
  **`[Equipment]`** (prix des canons), **`[Repairs]`** (`Zeit` 30, `Kosten` 50).

Reste, pour le manuel : lire les VALEURS de `[AmmoData]`/`[Captain]` dans
`constdata`, et suivre les fonctions qui appliquent le coup (angle → touche →
dégâts). Fastidieux, pas bloqué.

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

**Carte précise de la traque (session de RE dédiée au combat).** Le chemin de la
puissance est entièrement cartographié — il ne manque que l'écriture :
- La puissance des deux camps vit dans un **sous-objet du convoi à `convoi+0xfd0`**
  (voisin du compteur de navires de combat `+0xf9c`), lu par l'accesseur `0x4376f0`
  (`return this+0xfd0`).
- La fenêtre pré-bataille `0x6c5970` en **copie** les stats dans des locales
  (puissance attaquant = `word [ebp-0xa2]`, défenseur `[ebp-0xd4]`, équipage
  `[ebp-0xda]`) puis les affiche (`tf_convoystrength_attacker/defender`) ; la
  fenêtre `0x568650` fait pareil ; le setup du dialogue (boutons Manuel/Auto/Annuler)
  est `0x56cd90`. Toutes **lisent**, aucune ne calcule.
- Le **remplisseur** du sous-objet `+0xfd0` (qui écrit la puissance) est parmi les
  écrivains appelant `0x4376f0` (candidats : `0x52a8f0`, `0x52e73e`, `0x49a2ff`…),
  ou dans la mise à jour du `BattleShipComponent`. Un balayage des multiplications
  ×5 (« ≤ 5 marins/canon ») dans tout le `.text` n'a donné que des courbes
  d'économie (`0x8629b0`) et une courbe par paliers `0x51b8a0` (rang/richesse,
  non-combat) — la formule n'est pas une simple ×5 en clair.

**Structure reconstruite (session « bloc » dédiée).** Le sous-objet `+0xfd0` est un
objet « aperçu de bataille » : constructeur `0x49c7c0`, il contient **deux camps
identiques** (attaquant à `+0`, défenseur à `+0x38`, chacun de la classe `0x49c990`,
taille 0x38 o) plus une `std::string` à `+0x74`. Chaque camp a des accesseurs de
champ (`get` à `+0x28`, `+0x34`, …). La puissance affichée est un champ de camp.

**Ce qui résiste (honnête, après ~10 angles).** L'accesseur `0x4376f0` a **192
appels** — tous des LECTEURS/copieurs (aucun n'écrit ni ne calcule juste après). Le
déclencheur d'escorte `0x4b7a50` est un **dispatcher de 82 cas**. Les balayages ×5
(« ≤ 5 marins/canon ») et « lit canons `+0x3b` ET équipage `+0x30` » ne donnent que
des **widgets d'UI** dont les offsets de cache (0x30/0x34/0x3b) **coïncident** avec
ceux d'un navire — la réutilisation d'offsets défait le balayage. L'écriture de la
puissance vit dans la mise à jour du composant ECS, atteinte seulement par le
système de composants abstrait.

**Constat.** Ce n'est pas absent des fichiers, mais **ce chiffre précis ne cède pas
au balayage statique** dans un effort raisonnable : cache + réutilisation d'offsets
+ abstraction ECS. Deux vraies voies restent : (a) reconstruire tout le système de
composants ECS (long, payoff incertain) ; (b) pour le portage, une formule **calée
sur le modèle connu** (somme sur ≤ 3 navires de combat de `canons·a + min(équipage,
canons·5)·b`, modulée par la maniabilité), à ajuster au ressenti. Le modèle est sûr ;
seuls les coefficients a/b manquent.

## Guerre terrestre — batailles de ville (pilier mappé)

Quand on assiège/prend une ville, PR3 joue une **bataille terrestre** : des SOLDATS
se disputent des **points de contrôle** de la ville. Système mappé (à porter) :
- **Points d'attaque** : `TownBattleApMarket` (le marché), `TownBattleApFortress`
  (la forteresse) — les objectifs à tenir/prendre.
- **Soldats** : composant ECS `Client::TownSoldierComponent` (`0x68a4c0`). Chaque
  type de soldat a des stats `[Soldier]` : `Damage:f[]`, `Health:f[]`, `Range:f[]`,
  `Speed:f[]` (**tableaux par type, valeurs dans `constdata`** — à extraire comme les
  munitions, par ancre binaire). Scalaires décodés (`0x863e81`, et `PR3_CONFIG.md`) :
  `MovementFactor` 1, `EvadeSpeed` 2, `InteractStand` 1.5, `WalkFactor`, `UnitSize`,
  `UnitMax`, `RangeFactor` 1.4, `Speed` de base 3.
- **Données de bataille** : `Database::TownBattle` (`0x767330`) — paramètres de la
  bataille (table binaire `constdata`). `Database::Fortress` / `[Fortress]` (`Range`
  100, `ReloadTime`, `Hit:i[]`, `Gun_%u_%02u:f[]`) — les canons de la forteresse.
- **UI/temps** : `HudTownBattle` (`0x5fbd80`), musique `MusicTownBattle`, `[Timer]
  SoldierLeave` (les soldats quittent après un délai).

Comme le combat naval, la **résolution** (dégâts/déplacement en temps réel) vit dans
le composant ECS `TownSoldierComponent` : même mur que la puissance navale, à faire
dans la passe combat dédiée. La STRUCTURE et les PARAMÈTRES, eux, sont lisibles.

## Actions du joueur sur la carte maritime

Décodé du système de carte (`SeaMapComponent` `0x6fc200`, registre d'entités
`0x460d11`, config `[Gui]` / `[SeaMapMovement]`). C'est le modèle exact à porter.

**Sélection.** On clique un convoi ; il est pris s'il est dans un rayon de
`[Gui] SelectionRange` = **16** (unités carte) du clic — un marqueur `SelectionConvoyMap`
s'affiche dessus (`SelectionConvoyTown` pour une ville, rayon `SelectionRangeTown`
= **11**). PR3 sélectionne **un convoi à la fois** sur la carte, et la sim fait de
même. (Elle a porté un temps une sélection au rectangle multi-convois, ajoutée à la
demande ; elle a été retirée — le clone prime sur la préférence.)

**Ordre de déplacement.** Clic droit sur la destination : « Cliquez avec le bouton
droit sur votre destination pour faire partir votre convoi. » Une **ligne de cible**
`ConvoyTargetLine` se trace du convoi vers le point (mer ou rade d'un port), et le
convoi s'y rend ; sa route suivie est `ConvoyRoute`. Le convoi du joueur est
`PlayerShipConvoy`.

**Déplacement / vision.** `[SeaMapMovement]` : `SpeedFactor` **0.1** (vitesse sur la
carte), `RangeOfVision1` **8** / `RangeOfVision2` **12** / `RangeOfVisionWatch` **12**
(portées de vue — le brouillard se lève selon la taille/veille du convoi). La carte
elle-même : `[Gui] SeaMapWidth` 1024 × `SeaMapHeight` 512, `SpeedFactor` 0.25 (vitesse
de défilement de la vue).

**Entités visuelles** (assets, registre `0x460d11`) : `PlayerShipConvoy` (le convoi),
`SelectionConvoyMap` / `SelectionConvoyTown` (le marqueur de sélection), `ConvoyTargetLine`
(la ligne d'ordre), `ConvoyRoute` (le tracé de route), `SeaMapView` (la vue).

**Alignement de la sim.** `scripts/carte2d.gd` fait : clic gauche = sélection d'UN
convoi, clic droit = destination (port OU point de mer), anneau d'or = marqueur de
sélection, sceau sur la ville = convoi à quai, et le tracé en pointillés de la route
du convoi sélectionné (`ConvoyTargetLine` / `ConvoyRoute`), alimenté par les points
que le convoi suit réellement (`d.route`, posé par `sim/bridge.lua`). Elle déplace le
convoi via `Marchands.ordonner` / `ordonner_position`, et applique le ratio 16:11 de
PR3 sur les rayons de clic (`_convoi_sous_monde`).

**Ce qui reste à porter** : le BROUILLARD DE GUERRE — `[SeaMapMovement]`
`RangeOfVision1` 8 / `RangeOfVision2` 12 / `RangeOfVisionWatch` 12 — dont la sim n'a
rien ; et les ÉTATS de convoi que PR3 nomme (Bataille navale, Réparations, Raid,
Patrouille, « À l'ancre - oisif »), bloqués en amont faute de combat, de réparations
et de piraterie dans la simulation.

## État du rétro-engineering — le bilan complet

Cinq niveaux : **porté** (dans `sim/`), **décodé** (math/structure exacte lue),
**semantique** (sens connu, logique fine non décompilée), **bloqué-dynamique**
(ne se lit qu'en exécution), **contenu / hors-jeu** (scénario, rendu, réseau).

| Sous-système | État |
|---|---|
| Consommation, prix, seuils, faim, knapp | **porté** |
| Production, coût, recettes, entrepôt (stock/prix moyen) | **porté** |
| Qualité de vie, 7 niveaux de prospérité | **porté** |
| Croissance de population (vers capacité de logement), logement | **porté** |
| Efficacité des ateliers (inertie ±1/jour) | **porté** |
| Emploi (ouvriers → citoyens ÷ 4) | **décodé** (non porté : la sim n'a pas la couche ouvriers) |
| Fléaux (peste/sauterelles/feu, par surpopulation) | **porté** |
| Construction de l'IA (Bauquotient) | **porté** |
| Réputation par ville (commerce) | **porté** |
| Navires (16 types, cale, vitesse, entretien), carte, eau, formats | **porté / décodé** |
| Convois : taille (420÷1900), composition, routes à ordres `set_goods`, 9 stratégies | **décodé** ; modèle porté |
| Bâtiments : coûts, matériaux, effets (école, hôpital, ambassade…) | **décodé** |
| Chantier : 5 onglets (build/buy/sell/repair), stats `[Ship%02u]`, limites, réparation, montée de niveau | **décodé** (mécanisme) ; recette de construction **bloquée-dynamique** |
| Journée d'une ville : les 20 étapes de `0x7C2D20`, dans l'ordre | **décodé** |
| Diplomatie : 18 rangs à la richesse, licences, donations, lettres de marque | **sémantique** ; seuils numériques (convois 3→100, `[Licence]`, `[Requirements%02u]`, `[MinRank]`) **décodés**, titres/courbe de richesse dans les `.fuk` |
| Réputation de nation, dérive sinusoïdale (`Offset`/`Amplitude`/`Phase`) | **sémantique** |
| Pirates, tempêtes, sauterelles, mines, patrouilles, météo | **décodé** (paramètres) |
| Signaux de ville (conseiller) — taxonomie | **décodé** |
| Générateurs de stratégie (Profit, Resources… → ordres) | **sémantique** (logique par stratégie non décompilée) |
| Combat — PARAMÈTRES (`[Battleship]`, `[AmmoData]`, `[HullDamage]`, `[Boarding]`, `[Captain]`, `[Tactic]`) | **décodé** — physique/abordage dans l'exe, **4 munitions (dégâts coque/voiles/équipage) dans `constdata`** ; restent prix canons + capitaine |
| Combat AUTOMATIQUE : formule de puissance par camp | **partiel** — modèle connu, l'arithmétique est en cache ECS (RE profonde ou relevé en jeu) |
| Combat MANUEL : application du coup (angle → touche → dégâts) | **partiel** — paramètres décodés, fonctions d'application à suivre |
| Affectation équipage/escorte au combat (3 navires, ≤ 5 marins/canon) | **décodé** (règle) |
| Guerre terrestre : batailles de ville (soldats, points marché/forteresse, `[Soldier]`, `TownBattle`, `Fortress`) | **mappé** — structure + params scalaires ; stats soldats (tableaux `constdata`) à extraire ; résolution ECS avec le combat |
| Missions et campagne | **contenu** (à réécrire, pas à décompiler) |
| UI — structure des écrans (`.swf`) : catalogues de composants, hiérarchie, placements nommés | **décodé** (`swf_ui.py`, `PR3_UI.md`) — positions fines/images restantes |
| Rendu, caméra, audio, réseau | **hors-jeu** |

**Verdict.** Toute la logique de JEU lisible statiquement est décortiquée : l'économie
entière (portée dans la sim), les convois et le commerce, la ville et sa population,
la diplomatie, les fléaux, les bâtiments. Ne restent hors de portée du binaire figé
que **trois choses, par nature** :

1. **Les formules de combat** (puissance, dégâts, abordage) — calculées et mises en
   cache dans la couche de composants ECS, elles ne s'exposent pas en clair ; leur
   seule voie fiable est la **lecture à l'exécution** (le jeu affiche la puissance
   d'un convoi ; quelques relevés donnent la formule).
2. **La recette de construction d'un navire** (quelles marchandises, combien, quel
   or, quelle durée) — l'*offre* est bâtie en direct depuis l'état de la ville ; le
   mécanisme est décodé, les chiffres se relèvent en jeu, comme la puissance.
3. **Le scénario de campagne** — du contenu scripté, à réécrire.
4. **Le rendu, l'UI, l'audio et le réseau** — hors du modèle.

**Rectification (important).** « Bloqué » n'a jamais voulu dire « indisponible » :
tout ce que le jeu fait est dans ces fichiers, donc **tout est récupérable**. La
seule variable, c'est l'EFFORT d'extraction. Trois niveaux : les DONNÉES/config
(lisibles direct — fait) ; la LOGIQUE compilée (économie faite, combat en cours,
au désassemblage) ; l'UI/l'art dans les `.swf` Iggy (chaînes extraites ; layouts
complets avec un décodeur SWF). Le raccourci « relevé en jeu » que j'avais proposé
pour le combat était un choix de rapidité, pas une limite.

## Le programme : « connaître PR3 par les fichiers, au point de le recréer »

Objectif : une bible complète tirée des seuls fichiers, et le fan game bâti dessus,
extensible. Prochaines briques, par ordre d'utilité :

1. **Config scalaire — FAIT.** `outils/PR3_CONFIG.md` (généré par
   `outils/config_defauts.py`) donne les **81 sections / 438 clés avec leurs
   défauts**. Découverte : il n'y a **pas** d'arbre de config texte ; `constdata.dat`
   est fait de **TABLES BINAIRES** (navires, villes, munitions, prix…) et l'exe porte
   la logique + les défauts scalaires. Pour les scalaires, le défaut EST la valeur du
   jeu.
2. **Tables binaires de `constdata`** — parser table par table pour les VALEURS des
   tableaux (`i[]`/`f[]`) : munitions (`AmmoData` DmgHull/Sail/Crew), prix des canons
   (`Equipment`), coûts d'agrandissement (`AusbauKosten`/`Waren`), capitaine, etc.
   Navires et villes déjà faits (`navires.lua`, `pr3data.py`).
3. **Combat** : fonctions d'application du coup + formule de puissance auto (RE
   profonde de `BattleShipComponent` / `0x86C470` et suivantes).
4. **Guerre terrestre** (`[Soldier]`, sièges) : structure et paramètres.
5. **UI/menus — structure FAITE.** `outils/swf_ui.py` + `PR3_UI.md` : catalogue de composants et hiérarchie de chaque écran (radial, ville/convoi/chantier, HUD, routes, capitainerie), extraits des `.swf`. Restent les positions fines (bruit CXFORM) et les images (droits, non extraites).
6. **Campagne/missions** : script à lire et réécrire.

La liste exhaustive des 82 sections et 455 clés est reproductible par
`py -3 outils/config_map.py` (l'outil lit l'exécutable local, jamais commité).

---

## La réputation : deux systèmes, un seul alimenté par le commerce

Relevé au désassembleur, fonction par fonction. C'est la réponse à « la
réputation baisse vite et ne remonte jamais ».

### Deux magasins distincts, dans le même objet

Tout vit dans `joueur+0x1B8` :

| Zone | Forme | Portée |
|---|---|---|
| vecteur d'enregistrements de **12 octets** | `[0]` accumulateur, `[4]` base, `[8]` valeur affichée 0–100, `[9]` dernière variation | **par ville** |
| `+0x20` : quatre `u32` | 0–1000, affichage ÷10 | **par nation** |
| `+0x30` : quatre `u32` | cumul brut des gains | par nation |
| `+0x40` : quatre octets | nation *liée* (si < 4, moyenne des deux) | par nation |
| `+0x52` | bits « à rafraîchir » | — |

### Qui écrit quoi

```
COMMERCE ──> 0x7839E0 (vendre sous X1)  ──┐
             0x783B40 (acheter sous X1) ──┼──> 0x759F00 ──> 0x75CEF0 ──> 0x75CC30
             0x783C00                    ──┘                          (ACCUMULE, ±1000)
                                                                      => VILLE seulement

MISSIONS, ANNEXION, PIRATERIE ──> 0x783510 (boucle sur les 4 nations)
                                  0x783CB0 (annexion, valeur Annexed = 200)
                                      └──> 0x7C72A0 ──> 0x759E40 ──> 0x75C700
                                                                     (ACCUMULE, 0..1000)
                                                                     => NATION seulement
```

**Aucun chemin du commerce n'atteint `0x75C700`.** La séparation est
architecturale, pas un réglage.

### Pourquoi ça paraît asymétrique

Les coefficients, eux, sont symétriques : gain et perte de ville valent tous deux
`100 × part/X1` en unités d'accumulateur (`RepFactor` vaut 1000 par défaut —
`fld1` × la constante `1000.0` en `0xB3D9B8` — et le gain vaut `RepFactor/10`).
`[Reputation] Offset/Amplitude/Phase` se chargent avec `fldz`, donc la dérive
SINUSOÏDALE est nulle — mais **il existe bel et bien une érosion passive**,
mesurée en jeu à environ **−16 points par minute** (voir plus bas). Elle ne passe
pas par `0x75C700`, qui n'a qu'un seul appelant : elle écrit ailleurs. L'asymétrie vient d'ailleurs :

1. **La punition est collective** — `0x783510` boucle sur les quatre nations : une
   attaque sans lettre de marque coûte partout à la fois. Le gain ne concerne
   jamais qu'une couronne.
2. **Le gain est épisodique**, jamais continu, alors que le commerce est l'action
   permanente du joueur.
3. **Verrou d'amorçage** — il faut déjà 25 % auprès d'une nation pour que son
   gouverneur offre les missions qui sont la principale source de réputation
   (`ID_TOWNHALL_GOVERNOR_CASE2`), et 75 % pour le vice-roi.

### Le correctif

`outils/pr3_patch_reputation.py`. Dans `0x7839E0`, le `call 0x759F00` de
`0x783A79` fait exactement 5 octets — la taille d'un `jmp rel32`. On le remplace
par un saut vers une section ajoutée (`.pr3fix`), qui refait l'appel d'origine
puis appelle `0x75C700(nation, valeur)` pour la nation propriétaire de la ville,
avant de revenir à `0x783A7E`.

Faits qui rendent la greffe sûre : `[ville+0x36]` est l'index de nation (six
sites le bornent par `cmp al,4; jae`) ; `0x759F00` ne touche jamais `ebx`, donc
l'objet ville survit ; et l'exe est **sans ASLR** (`DllCharacteristics` 0x8100,
table de relocations vide), si bien que toutes les adresses absolues restent
valides. L'en-tête PE a 120 octets libres — assez pour une dixième section.


### Mesuré en jeu, sur l'exécutable instrumenté

Relevé par lecture de la mémoire du processus (`joueur+0x1B8+nation*4+0x20`),
pendant qu'une route commerciale automatique desservait les villes d'une nation :

| nation | cumul reçu du greffon | variation nette sur 90 s |
|---|---:|---:|
| 0 (desservie) | +52 | **+28** |
| 1 (effleurée) | +12 | −12 |
| 2 et 3 (jamais touchées) | **0** | **−24** |

Les nations 2 et 3 n'ont reçu aucun apport et perdent pourtant 24 points : c'est
l'**érosion native**, soit **≈ −16 points/minute (−1,6 %/min)**. C'est elle qui
explique « la réputation baisse vite et ne remonte jamais » — rien, dans le jeu
d'origine, ne la compensait en continu.

Vérifié aussi : les quatre octets de « nation liée » (`magasin+0x40`) valent tous
**0xFF**, donc ≥ 4, donc la branche de moyenne de `0x75C700` n'est jamais prise.
Le greffon ne peut pas déplacer la réputation d'une nation voisine — chaque gain
reste sur la couronne visée.

Avec `valeur = 2`, une route active rapporte ≈ +35/min bruts contre ≈ −16/min
d'érosion : elle renverse la pente sans l'emballer. C'est le réglage par défaut
de `outils/pr3_patch_reputation.py`, modifiable en troisième argument.
