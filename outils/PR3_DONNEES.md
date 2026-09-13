# PR3 — données chiffrées de `constdata.dat` (tables binaires)

Généré par `outils/pr3_constdata.py` (lit ta copie locale, jamais commitée). Ce
sont des FAITS de gameplay (prix, recettes, coûts, stats de navires) tirés des
tables binaires de `ini/constdata.dat` — pas les défauts de l'exe, mais les vraies
valeurs du jeu (elles écrasent parfois l'exe : 1Fass 2000, Faktor 1.1, Lohn 6).

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
```
