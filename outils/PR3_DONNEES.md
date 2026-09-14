# PR3 — données chiffrées de `constdata.dat` (tables binaires)

Généré par `outils/pr3_constdata.py` (lit ta copie locale, jamais commitée). Ce
sont des FAITS de gameplay (prix, recettes, coûts, stats de navires, munitions)
tirés des tables binaires de `ini/constdata.dat` — pas les défauts de l'exe, mais
les vraies valeurs du jeu (elles écrasent parfois l'exe : 1Fass 2000, Faktor 1.1,
Lohn 6).

Pour la config SCALAIRE complète (146 sections), voir `PR3_CONFIG.md`.
Pour la logique et les systèmes, voir `PR3_SYSTEMES.md`.

```
== Standardpreise (section Standardpreise, cles Ware%02u_SWP)
   bois       33
   briques    33
   ble        33
   fruits     50
   mais       50
   sucre      50
   chanvre    50
   tissu      150
   metal      83
   coton      50
   outils     200
   teinture   100
   cafe       140
   cacao      140
   tabac      100
   viande     300
   vetements  450
   cordage    150
   rhum       267
   pain       142

== Preisfaktoren (cles X%u et X%uknapp) : 5 coefficients, stock vide -> plein
   cran 0: normal [2.0, 1.8, 1.2, 1.2, 0.8]   penurie [3.0, 2.7, 1.2, 1.2, 0.8]
   cran 1: normal [1.8, 1.6, 1.2, 1.2, 0.7]   penurie [2.7, 2.4, 1.2, 1.2, 0.7]
   cran 2: normal [1.6, 1.4, 1.1, 1.1, 0.6]   penurie [2.4, 2.1, 1.1, 1.1, 0.6]

== Reglages de la section Data, Time et Initial
   1Fass                                    2000   unites par tonneau
   Faktor                                    1.1   multiplicateur de la consommation
   Lohn                                        6   salaire d'un ouvrier, par jour
   Grundkosten                                50   frais fixes d'un atelier de 25 ouvriers, par jour
   Heuer                                       2   solde d'un marin, par jour
   VerwalterLohn                              50   salaire de l'administrateur
   VorratTage                                 15   jours de production gardes en reserve
   NeubauOfficeVorratTage                      5   seuil de reserve du comptoir pour batir
   NeubauWeltVorratTage                       15   seuil de reserve mondiale pour batir
   NeubauMinAlq                               50   chomage minimal pour batir un atelier
   StartFabriken                              20   ateliers au depart
   Konvois (Initial)                           2   convois IA par ville au depart
   Verkaufszeit                               64   temps de vente a quai
   Einkaufszeit                               64   temps d'achat a quai
   Einlaufzeit                               128   temps d'entree au port
   KiUpdateConvoySize                       7680   intervalle de redimensionnement des convois IA
   MinAreaFactor                              10   
   BasicCapacity                            1000   capacite de base d'un comptoir
   Bettlerfaktor                             1.4   facteur des mendiants
   Repairs/Zeit (probable)                  30.0   duree de reparation
   Lagermiete                    [0.1, 0.2, 0.3]   loyer d'entrepot, trois paliers

== Consommation, production, recettes
   denree       Verbrauch  A(range)  par_ouvrier  ouvriers  Grundbedarf  Minimal  Bauquotient
   bois            2.50       275          480        25           30        1        0.95
   briques         5.00       550          480        25           60        1        0.95
   ble             5.00       550          480        25            5        1        1.00
   fruits          4.00       440          320        25            5        1        1.00
   mais            2.00       220          320        25            5        1        1.00
   sucre           2.00       220          320        25            5        1        1.00
   chanvre         2.00       220          320        25            5        1        1.00
   tissu           1.00       110          160        25            5        1        1.00
   metal           1.00       110          240        25            5        1        1.00
   coton           2.00       220          320        25            5        1        1.00
   outils          1.00       110          160        25            5        1        1.00
   teinture        0.50        55          160        25            5        1        1.00
   cafe            1.00       110          160        25            5        1        1.00
   cacao           1.00       110          160        25            5        1        1.00
   tabac           1.00       110          160        25            5        1        1.00
   viande          1.00       110           80        25            5        1        1.00
   vetements       1.00       110           80        25            5        1        1.00
   cordage         2.00       220          160        25            5        1        1.00
   rhum            1.00       110           80        25            5        1        1.00
   pain            2.00       220          160        25            5        1        1.00

== Recettes (intrant x quantite par unite produite ; rangee x64)
   tissu      <- coton x1
   metal      <- bois x0.5
   outils     <- bois x0.5 + metal x1
   cafe       <- outils x0.25
   cacao      <- outils x0.25
   viande     <- mais x2
   vetements  <- tissu x1 + teinture x1
   cordage    <- chanvre x1
   rhum       <- bois x0.5 + sucre x1
   pain       <- ble x0.5 + sucre x0.5

== Prix standard recalcule = (Grundkosten + ouvriers x Lohn) / production + intrants
   bois       calcule    33.3   jeu 33
   briques    calcule    33.3   jeu 33
   ble        calcule    33.3   jeu 33
   fruits     calcule    50.0   jeu 50
   mais       calcule    50.0   jeu 50
   sucre      calcule    50.0   jeu 50
   chanvre    calcule    50.0   jeu 50
   tissu      calcule   150.0   jeu 150
   metal      calcule    83.3   jeu 83
   coton      calcule    50.0   jeu 50
   outils     calcule   200.0   jeu 200
   teinture   calcule   100.0   jeu 100
   cafe       calcule   150.0   jeu 140
   cacao      calcule   150.0   jeu 140
   tabac      calcule   100.0   jeu 100
   viande     calcule   300.0   jeu 300
   vetements  calcule   450.0   jeu 450
   cordage    calcule   150.0   jeu 150
   rhum       calcule   266.7   jeu 267
   pain       calcule   141.7   jeu 142

== Batiments : Bauplatzkosten x3, valeur des materiaux, duree, materiaux (Baukosten Betriebe)
   bois             (8000, 16000, 24000)          2000   6  20 bois, 40 briques
   briques          (8000, 16000, 24000)          2000   6  20 bois, 40 briques
   ble              (8000, 16000, 24000)          2000   6  20 bois, 40 briques
   fruits           (8000, 16000, 24000)          2000   6  20 bois, 40 briques
   mais             (8000, 16000, 24000)          2000   6  20 bois, 40 briques
   sucre            (8000, 16000, 24000)          2000   6  20 bois, 40 briques
   chanvre          (8000, 16000, 24000)          2000   6  20 bois, 40 briques
   tissu            (12000, 24000, 36000)         4000  12  40 bois, 80 briques
   metal            (10000, 20000, 30000)         4000  12  40 bois, 80 briques
   coton            (8000, 16000, 24000)          3000   9  30 bois, 60 briques
   outils           (16000, 32000, 48000)         6000  18  60 bois, 120 briques
   teinture         (8000, 16000, 24000)          2000   6  20 bois, 40 briques
   cafe             (10000, 20000, 30000)         4000  12  40 bois, 80 briques
   cacao            (10000, 20000, 30000)         4000  12  40 bois, 80 briques
   tabac            (8000, 16000, 24000)          2000   6  20 bois, 40 briques
   viande           (12000, 24000, 36000)         4000  12  40 bois, 80 briques
   vetements        (18000, 36000, 54000)         6000  18  60 bois, 120 briques
   cordage          (12000, 24000, 36000)         4000  12  40 bois, 80 briques
   rhum             (10000, 20000, 30000)         4000  12  40 bois, 80 briques
   pain             (10000, 20000, 30000)         4000  12  40 bois, 80 briques
   hotel_de_ville   (200000, 400000, 600000)    220000   0  200 bois, 400 briques
   chantier_naval   (50000, 100000, 150000)      60000   0  100 bois, 200 briques
   ecole            (14000, 28000, 42000)        20000  18  60 bois, 120 briques
   hopital          (14000, 28000, 42000)        20000  18  60 bois, 120 briques
   arbres           (6000, 12000, 18000)          8000   6  20 bois, 40 briques
   puits            (6000, 12000, 18000)          8000   6  20 bois, 40 briques
   pompiers         (14000, 28000, 42000)        20000  18  60 bois, 120 briques
   hospice          (14000, 28000, 42000)        20000  18  60 bois, 120 briques
   ambassade        (14000, 28000, 42000)        20000  18  60 bois, 120 briques
   forteresse       (100000, 200000, 300000)         0   0  25 bois, 50 briques
   entrepot         (6000, 12000, 18000)          8000   6  20 bois, 40 briques
   maison           (14000, 28000, 42000)        18000  12  40 bois, 80 briques
   bordel           (14000, 28000, 42000)        20000  18  60 bois, 120 briques

== Navires : Value, Capacity, Hitpoints, HitpointsSail, Construct (or), DailyCosts, rangs mil/mil/pir, Vmin, Vmax, Wendig
   pinnace            10000  200  100  100    9000  100 ['-', 0, '-'] 24 40 100
   sloop              19000  200  110  110   18000  110 ['-', 0, 0] 24 44 100
   brig               27000  250  140  140   25000  140 [0, 4, 0] 20 44  95
   barc               36000  250  150  150   35000  150 [0, 4, 0] 20 48  90
   piratebarc         36000  300  180  180   35000  180 ['-', 0, 0] 20 48  90
   fluyt              40000  500  220  220   40000  220 ['-', 0, '-'] 16 40  85
   tradefluyt         50000  800  300  300   48000  240 ['-', 0, '-'] 16 40  80
   corvette           60000  350  200  200   60000  200 [2, 8, 0] 16 48  85
   frigate            70000  400  220  220   72000  220 [28, 8, 0] 20 44  80
   militarycorvette  100000  300  210  210  105000  210 [4, '-', '-'] 20 44  85
   militaryfrigate   120000  350  250  250  130000  250 [4, '-', 4] 20 48  85
   galleon           120000  600  280  280  135000  280 [6, '-', 6] 16 40  75
   carrack           140000  550  320  320  160000  320 [6, '-', 8] 20 48  75
   caravel           160000  500  300  300  180000  300 [6, '-', 8] 16 44  75
   wargalleon        180000  400  320  320  210000  320 [8, '-', '-'] 16 52  70
   liner             200000  400  340  340  240000  340 [8, '-', '-'] 12 56  70

== Munitions (AmmoData : Vmax, DmgHull, DmgSail, DmgCrew)
   boulet     Vmax  424.4   coque  1000  voiles   100  equipage   300
   chaine     Vmax  365.9   coque   200  voiles  1500  equipage   100
   mitraille  Vmax  311.8   coque   300  voiles   100  equipage   800
   lourd      Vmax  554.3   coque  2500  voiles  2500  equipage   100
```

---

## La table des navires de `constdata.dat`, relue proprement

Mon premier décodeur cherchait les navires par une ancre heuristique et ne lisait
que onze colonnes. La structure réelle se lit mieux : **chaque navire occupe un
bloc de 120 octets qui se termine à son nom**, suivi de son nom de carte et de
ses positions de canon.

```
[ scalaires, 120 octets ] [ nom ] [ nom_wm ] [ blocs GunPos de 16 octets ]
```

### Colonnes PROUVÉES

Vérifiées en croisant chaque valeur connue contre chaque offset, sur les seize
navires. Une colonne n'est retenue qu'au-delà de quatorze concordances sur seize.

| champ | offset | type | concordance |
|---|---:|---|---:|
| `Value` (prix) | +13 | u32 | 16/16 |
| `Capacity` (cale) | +17 | u16 | 16/16 |
| `Construct` (construction) | +27 | u32 | 16/16 |
| `DailyCosts` (entretien) | +31 | u16 | 16/16 |
| `Vmin` | +40 | u8 | 16/16 |
| `Vmax` | +41 | u8 | 16/16 |
| `Wendig` (maniabilité) | +42 | u8 | 16/16 |

### Les canons, et l'équipage qui s'en déduit

Après les deux noms, l'enregistrement **déclare son compte** : un octet de garde,
puis un `u32` qui donne le nombre de positions de canon. Suivent autant d'entrées
de **21 octets** — un octet de garde, un `u32` égal à 4 (le nombre de flottants),
puis quatre flottants : x, y, z et un quatrième toujours nul.

C'était d'abord décrit comme des blocs de 16 octets à trois flottants, trouvés
par reconnaissance de motif. La lecture du compte déclaré donne les mêmes valeurs
sur quinze navires et **corrige le seizième** (voir plus bas).

Le fichier ne garde qu'**un seul bord** — pour un navire donné, toutes les
positions partagent le signe de leur x — et le jeu mire l'autre. D'où :

```
canons   = 2 × nombre de positions
équipage = canons × [Ship] CrewmenAtGun (5)
```

Vérifié sur une capture du jeu : le sloop y affiche **14 canons et 70 marins**,
et `constdata` lui donne **7 positions**. Deux champs indépendants qui tombent
juste. De la pinasse (4 positions → 8 canons) au vaisseau de ligne (25 → 50), la
série est monotone avec le prix et le tonnage.

Le vaisseau de ligne en portait 26 dans la première lecture ; son compte déclaré
dit **25**. La structure tranche : à 25 positions, le triplet qui suit vaut
`02 04 02` — quatre mâts, tirant de classe 2, l'un et l'autre valides ; à 26, il
tomberait sur `00 00 00`, et un navire à **zéro mât** n'existe pas. Le motif de
cinq octets qui clôt l'enregistrement se retrouve alors au même endroit que chez
la pinasse et le sloop.

| navire | positions | canons | équipage |
|---|---:|---:|---:|
| pinasse, flûte commerciale | 4 | 8 | 40 |
| sloop | 7 | 14 | 70 |
| brick, flûte | 8 | 16 | 80 |
| barque | 10 | 20 | 100 |
| barque pirate, corvette | 12 | 24 | 120 |
| frégate | 13 | 26 | 130 |
| corvette combat | 16 | 32 | 160 |
| frégate combat, galion | 18 | 36 | 180 |
| caraque, caravelle | 20 | 40 | 200 |
| galion de guerre | 23 | 46 | 230 |
| vaisseau de ligne | 25 | 50 | 250 |

### Colonnes prouvées, seconde passe

`Hitpoints` EST dans le bloc — je l'avais d'abord déclaré absent, à tort : il est
stocké en `u32` **multiplié par 1000**, et je le cherchais en `u16`.

| champ | offset | type | concordance |
|---|---:|---|---:|
| `Hitpoints` (coque) | +19 | u32 ÷ 1000 | 16/16 |
| `HitpointsSail` (voiles) | +23 | u32 ÷ 1000 | 16/16 |
| `minRankMil` | +37 | u8 (255 = interdit) | 16/16 |
| `maxRankMil` | +38 | u8 | 16/16 |
| `minRankPir` | +39 | u8 | 16/16 |

Coque et voiles portent la même valeur pour les seize navires, ce que disaient
déjà les notes. C'est cette paire d'entiers égaux que le premier décodeur prenait
pour une « ancre » sans savoir ce qu'elle était.

### Les colonnes de tête sont décalées d'un navire

Les octets `+0` à `+11` de la fenêtre d'un navire appartiennent à
l'enregistrement **précédent** : la fenêtre de 120 octets déborde sur la queue du
voisin. En réattribuant `+5` au navire d'avant on lit 2, 1, 2, 3 pour pinasse,
sloop, brick, barque — soit leurs mâts, ce qui est historiquement juste.

### `Masts`, à +5 de la fenêtre suivante

En appliquant le décalage d'un navire, la colonne `+5` donne :

| navire | mâts | | navire | mâts |
|---|---:|---|---|---:|
| pinasse | 2 | | flûte, flûte comm. | 3 |
| sloop | **1** | | corvette, frégate | 3 |
| brick | 2 | | galion, caraque, caravelle | 3 |
| barque, barque pirate | 3 | | galion de guerre | **4** |

Un sloop à un mât, un galion de guerre à quatre, une pinasse à deux : la série
est historiquement juste. C'est `Masts`. Le vaisseau de ligne, longtemps hors
d'atteinte faute de voisin où lire sa colonne, en porte **4** lui aussi : les
seize navires sont désormais lus, par le compte de canons déclaré.

Nuance de méthode : contrairement aux colonnes ci-dessus, celle-ci n'est pas
vérifiée contre une valeur numérique connue mais contre la vraisemblance du
domaine. Solidement indiquée, donc, plutôt que prouvée.

### `Gauge` n'est pas une profondeur mais une CLASSE — prouvé

La colonne `+7` avait d'abord été proposée puis écartée à juste titre. Le
chargeur tranche la question, en `0x85fe2f` :

```
0085fe25  push 0
0085fe27  push 0xb7be6c      ; "Gauge"
0085fe2d  mov ecx, edi
0085fe2f  call 0x89d6e0      ; lecteur d'entier
0085fe34  cdq
0085fe35  mov ecx, 3
0085fe3a  idiv ecx           ; DIVISE PAR TROIS
0085fe3f  mov byte [ebp-0x118], dl   ; et ne garde que le RESTE
```

Le jeu ne conserve donc que `Gauge mod 3` : un tirant d'eau à **trois niveaux**,
0, 1 ou 2 — et non une profondeur. C'est ce qui explique le « 0 » affiché au
chantier pour le sloop, qu'on avait pris pour un champ vide.

La colonne est à **+6** de la fenêtre, soit `ancre(suivant) − 114`. L'ancrage se
vérifie sans rien supposer du domaine : à `ancre(suivant) − 115`, la colonne `+5`
reproduit **11 fois sur 11** les mâts publiés ci-dessus (sloop 1, brick 2, galion
de guerre 4) ; sa voisine `+6` tient dans 0..2 pour les quinze navires, ce que la
voisine `+4` ne fait pas — celle-ci porte des masques (15, 143, 255, 8…), c'est
`Nations`. Les trois se suivent dans l'ordre même du chargeur.

L'appartenance au navire *précédent* est elle aussi structurelle et non
seulement vraisemblable : le triplet tombe toujours **quinze octets avant le bloc
numérique du navire suivant**, sur les quinze paires mesurables.

| classe | navires |
|---|---|
| **0** | pinasse, sloop, brick, barque, barque pirate, corvette, corvette combat |
| **1** | flûte, flûte commerciale, frégate, frégate combat |
| **2** | galion, caraque, caravelle, galion de guerre |

La classe suit la **carène** et non le tonnage, ce qui est physiquement juste :
la flûte commerciale (800 tonneaux) est en classe 1, le galion de guerre (400)
en classe 2.

Le **vaisseau de ligne** a d'abord échappé à cette mesure : tant qu'on ancrait le
triplet sur le navire *suivant*, le dernier des seize n'en avait pas. Le compte
de canons déclaré lève l'obstacle — le triplet suit la dernière position de
canon, sans rien devoir au voisin. Il vaut `Nations=2`, `Masts=4`, `Gauge=2` :
quatre mâts et le tirant le plus fort, ce qu'on attend du plus gros navire du
jeu. **Les seize sont lus.**

### L'enregistrement est entièrement cartographié

Il n'y a plus de « colonnes flottantes » inexpliquées : ce n'étaient pas des
colonnes. L'enregistrement est une **chaîne de tableaux à compte devant**, et le
chargeur (`0x85f8a7`–`0x85fe81`, section `[Ship%02u]`) en donne l'ordre exact —
ses 21 lectures, désassemblées, se posent sur la structure sans jeu :

| # | clé | type | ce qu'on lit pour le sloop |
|---:|---|---|---|
| 1–3 | `minRankMil`, `maxRankMil`, `minRankPir` | int | 255, 0, 0 |
| 4–6 | `Vmin`, `Vmax`, `Wendig` | int | 24, 44, 100 |
| 7–8 | `BattleAsset`, `SeaMapAsset` | str | `sloop`, `sloop_wm` |
| 9 | `HullLength` | f[3] | −12.1, 4.5, 11.5 |
| 10 | `HullWidth` | f[2] | 2.9, 3.8 |
| 11 | `HullHeight` | flt | 2.8 |
| 12 | `SailOffset` | f[3] | 0, 17, 0 |
| 13 | `SailLength` | f[3] | 14, 26, 0 |
| 14 | `SailHeight` | flt | 25 |
| 15 | `SailType` | i[3] | 0, 1, 255 |
| 16 | `GunPos%02u` | f[] | 7 positions |
| 17–19 | `Nations`, `Masts`, `Gauge` | i[8], int, int | 143, 1, 0 |
| 20–21 | `DailyCosts`, `Construct` | int, i[6] | 110, coûts |

Deux clés n'apparaissent pas comme chaînes dans l'exécutable — `GunPos%02u` et la
section `[Ship%02u]` elle-même : elles sont **formatées à l'exécution** dans un
tampon de pile. C'est ce qui trompait la carte des réglages (voir `PR3_CONFIG.md`).

`SailType` explique au passage le dernier octet qu'on n'arrivait pas à placer : le
`ff` que portent quinze navires — et le `01` de la flûte — est le troisième
élément de ce tableau, pas un rang.

### Huit navires n'ont pas de géométrie propre

Les valeurs partagées qu'on avait relevées (5.5, 2.75, 7.0, 15.0, 16.0) sont
bien réelles, et la question est tranchée : les blocs de **pinasse, barque
pirate, flûte commerciale, corvette combat, frégate combat, caraque, caravelle et
vaisseau de ligne** sont identiques **octet pour octet**.

Ce n'est pas une mauvaise lecture, et ce n'est pas non plus une structure
recyclée d'une itération à l'autre : la barque pirate copie la **pinasse**, pas sa
voisine la barque. Ces huit navires n'ont simplement aucune entrée de géométrie
dans les données, et retombent tous sur les mêmes valeurs par défaut. C'est une
lacune de PR3, pas du décodage — elle ne touche que la coque et la voilure
affichées au combat, jamais les chiffres de commerce.
