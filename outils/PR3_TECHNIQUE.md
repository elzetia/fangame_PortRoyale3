# Port Royale 3 sous le capot

Ce qu'on sait de la technique de PR3 : formats, carte, eau, navires, et le modèle
de données de la simulation. L'économie chiffrée est dans `sim/ECONOMIE_PR3.md`.

**Rien de ce qui est décrit ici n'est copié dans le dépôt.** Les outils lisent
l'installation du joueur (`D:\GOG Galaxy\Games\Port Royale 3`). Les textures, les
maillages et les textes de PR3 sont sous droits : on peut s'en servir en local
pour comparer ou prototyper, jamais les publier.

---

## 1. Les archives et les formats

| Format | Où | Outil |
|---|---|---|
| `.fuk` | archives du jeu (`data.fuk`, `data0.fuk`, `data_fr.fuk`) | `_mod/unfuk.py` |
| `L10N` | `ui/locale/frfr/global.res`, textes | `outils/textes_pr3.py` |
| flux sérialisé | `ini/constdata.dat`, toutes les constantes | `outils/pr3_constdata.py` |
| `.vbuf` / `.ibuf` | maillages | `outils/pr3_mesh.py` |
| `.dds` | textures DXT1/DXT3/DXT5 | `outils/dds2png.py` |
| `.swf` | écrans d'interface (Flash/Scaleform « Iggy ») | `outils/swf_export.py`, `swf_bitmaps.py`, `swf_icones.py` |

**`constdata.dat`** est écrit par `Serialization::TypeLibrary` : les objets sont
numérotés dans l'ordre et les champs se suivent sans alignement ni étiquette.
Les tableaux ont un compte `u32` devant, les chaînes aussi (terminateur compris).
Les noms des champs sont dans l'exe, en allemand. Changer la taille d'un tableau
casse la numérotation de tout ce qui suit.

**Les maillages** : les deux fichiers commencent par `77 fe ba b0`, et
l'octet 10 donne la taille des données. Le pas d'un sommet se déduit du plus
grand indice : 16 octets (demi-flottants) pour le décor, 80 octets (flottants)
pour les navires. Détail dans l'en-tête de `outils/pr3_mesh.py`.

**Les `.swf` d'interface** cachent deux pièges de format, tous deux payés comptant.

Le premier est `PlaceObject3` : le nom de classe n'est là QUE si le drapeau
`HasClassName` (0x08) est levé. La spécification SWF ajoute « ou `HasImage` et
`HasCharacter` », mais Scaleform n'émet alors aucune chaîne — la lire consomme
des octets de bourrage, décale tout ce qui suit et fabrique de faux `charId`.
C'est ce qui faisait résoudre 269 symboles sur une seule et même mauvaise image.

Le second : **un `charId` placé dans un agencement désigne une FORME, pas un
bitmap**, alors que les PNG extraits portent l'identifiant du BITMAP que cette
forme remplit. Les deux numérotations sont disjointes — `hud_pc.swf` exporte 52
PNG (1, 2, 3, 4, 5, 6, 12, 24…) et son agencement ne référence aucun d'eux (14,
16, 20, 22, 30, 32…). Conclure à un export manquant est l'erreur naturelle, et
elle a été commise ici : ce qui manque est la résolution forme → bitmap, celle
que `swf_icones.py` sait déjà faire (`leaves()` / `shape_bmps()`) mais seulement
pour les symboles NOMMÉS. Les caractères anonymes demandent la même passe, par
SWF — c'est ce qui bloque aujourd'hui la minimap et le bandeau de ville du HUD.

## 2. La carte

| Fichier | Taille | Rôle |
|---|---|---|
| `textures/worldmapleft.dds` | 4096 × 4096, DXT1 | moitié ouest de la carte peinte |
| `textures/worldmapright.dds` | 2048 × 4096, DXT1 | moitié est |
| `worldmaplefthght` / `worldmaprighthght` | mêmes tailles | hauteurs du relief |
| `worldmapborder` | | le cadre |
| `0_seamapdeco0…5` | 1024², DXT3 | décors posés sur la mer |
| `map.bmp` | 1320 × 960 | masque terre/mer pour la navigation |
| `ini/navmapdata.dat`, `ini/routemgr.dat` | | graphe de navigation et routes **précalculées** |

La carte entière fait donc **6144 × 4096 pixels**, découpée en deux textures pour
rester sous la limite de 4096 des cartes graphiques de 2012. Le relief a sa
propre carte de hauteurs à la même résolution. C'est elle qui donne l'ombrage et,
très probablement, l'écume le long des côtes.

Les routes ne sont pas cherchées en jeu : `RouteMgr` les charge toutes faites.

## 3. L'eau

Les shaders sont du bytecode DirectX 9 compilé, mais leurs tables de constantes
sont lisibles :

- `seamap.vsh` : `g_World`, `g_View`, `g_Projection`, **`g_Time`**. Les sommets
  de la mer bougent : la houle est géométrique, pas seulement peinte.
- `seamap.psh` : `tex0`, `s_diffuse`, `s_alpha`, **`envc`** (environnement) et
  **`g_ViewInverse`**. On reconstruit la direction du regard pour un reflet
  dépendant de l'angle (Fresnel).
- `seamap.sceneview` : une passe d'**ombres**, une passe de **réflexion** sur un
  `ReflectionPlane` (le ciel et les navires se reflètent), `g_skyColor`,
  `g_sunColor`.

Textures : `water1_onrm.dds` (carte de normales 1024², celle qui fait les
vaguelettes), `oceanfoam.dds` et `0_wat_foam1.dds` (écume), `0_bowwave.dds`
(la vague d'étrave, un masque alpha seul), `sky_*.dds` (ciel 2048²).

La recette : deux cartes de normales qui défilent à des vitesses différentes, un
reflet du ciel pondéré par l'angle, une passe de réflexion pour les navires, de
l'écume là où le fond remonte, une décalque d'étrave sous chaque navire. Tout
cela existe tel quel dans Godot : shader de surface, `ReflectionProbe` ou
réflexion planaire, texture de hauteurs lue dans le shader.

## 4. Les navires

Seize types, tous en 3D. Du plus léger au plus lourd : la pinasse fait environ
1 500 sommets en quatre pièces (coque, voile, mât, gui), le galion de guerre
environ 69 000. Chaque navire a deux textures et un `.asset` qui accroche :
`fx_pe_bowwave` (la vague d'étrave), les canons `gun_l_0…3` / `gun_r_0…3`, le
pavillon `flag_0`, l'icône `icon_top`, les voiles (`_mat_sail`). Les voiles sont
un matériau à part, donc animables.

La couleur de sommet des navires de bataille est un **masque de pièce** (le gui en
(1, 0, 1), le mât en (0, 1, 1)), pas une teinte.

### Les navires de la carte

Chaque type existe en seconde version pour la carte du monde, suffixée `_wm`
(`assets/pinnace_wm/`, `assets/tradefluyt_wm/`…) :

- **Maillage** : une seule pièce `baseshape`, de 358 sommets (pinasse) à 1 730
  (vaisseau de ligne), au même format de 80 octets par sommet. La caraque est
  remplacée par le correctif `data0.fuk`.
- **Couleurs de sommets** : une **occlusion en niveaux de gris**, multipliée à la
  texture.
- **Texture** : **une seule pour les seize navires**, `textures/0_ships_wm.dds`
  (512², DXT5, alpha constant à 64, qui n'est pas une transparence). Aucun `.mesh`
  ne la nomme ; le lien passe par `materials/ship_wm.mat`.
- **Flipbook** : la texture est une grille de **trois variantes sur trois**. Toutes
  ont la même palette (bois, toiles, peintures), seule la couleur des voiles
  change. Les UV d'un navire couvrent une variante entière, de 0 à 1, et le
  paramètre `g_flipBook` du `.asset` choisit la case. Appliquer ces UV à la
  texture entière fait tomber chaque pièce sur la mauvaise couleur.
- **Couleurs de voiles** : les neuf variantes répondent sans doute aux réglages
  `SailColor_Trader`, `SailColor_Nation`, `SailColor_Pirate`, `SailColor_Pirate2`
  et `SailColor_Player0…3` de l'exe. L'ordre n'est lisible nulle part.
- **Effet attaché** : chaque `.asset` accroche l'effet `bowwave_wm`, la vague
  d'étrave.
- **Repère** : PR3 est en Direct3D, main gauche. Pour Godot, on retourne l'axe x et
  l'ordre des sommets de chaque triangle.

- **Caméra de la carte** : la vue `seamap` de `default.sceneviewmgr` place la caméra
  en (0 ; 280,083 ; −400), visant l'origine, soit **35°** au-dessus de l'horizon
  (280,083 / 400 = tan 35°). Le même triplet revient deux fois dans
  `constdata.dat`. Suivent un champ de 60° et des plans à 0,1 et 1 000. Les
  navires allégés sont faits pour cet angle : rendus à 60° ou 72°, ils sortent
  aplatis.
- **Lumière de la carte** (`seamap.sceneview`) : soleil `g_sunColor` à 2,5, ciel
  `g_skyColor` à (1,5 ; 1,45 ; 1,4), `LightDirection` (−1 ; −1 ; −1), donc un
  soleil à 35,26° de hauteur. Les autres vues ont un soleil à (2,3 ; 2,2 ; 2,1) et
  un ciel à (1,05 ; 1,15 ; 1,25).

Chaîne locale, sans rien copier dans le dépôt :

    py -3 outils/extraire_navires_pr3.py              → reference_pr3/navires_wm/
    godot --path . --script outils/rendre_navires_pr3.gd
                                                      → reference_pr3/navires_wm/atlas/

L'outil de rendu produit, pour chaque modèle et chaque variante, un atlas de
trente-deux caps (`<modele>_<variante>.png`), plus une fiche commune : cadrage
partagé, décalage de flottaison. La carte les cherche d'abord dans
`sprites/navires/modeles/`, où iront les modèles du projet, puis dans
`reference_pr3/`. Sans atlas, elle retombe sur la pinasse dessinée.

Sur la carte, chaque couronne a sa couleur de voiles (`NAV_VOILES_NATIONS` dans
`scripts/carte2d.gd`), choisie à l'œil sur la planche des neuf variantes :

| Espagne | Angleterre | France | Hollande | Portugal | Joueur | (pirates) |
|---|---|---|---|---|---|---|
| jaune (6) | rouge (2) | bleu (3) | bordeaux (4) | vert (5) | blanc (0) | noir (1) |

La palette n'a pas d'orange ; la Hollande prend le bordeaux.

Fiches de `constdata.dat` (valeurs certaines, sens des colonnes probable) :

| Navire | Prix | Cale | Coque | Vmin | Vmax | Maniabilité |
|---|---|---|---|---|---|---|
| Pinasse | 10 000 | 200 | 100 000 | 24 | 40 | 100 |
| Sloop | 19 000 | 200 | 110 000 | 24 | 44 | 100 |
| Brick | 27 000 | 250 | 140 000 | 20 | 44 | 95 |
| Barque | 36 000 | 250 | 150 000 | 20 | 48 | 90 |
| Barque pirate | 36 000 | 300 | 180 000 | 20 | 48 | 90 |
| Flûte | 40 000 | 500 | 220 000 | 16 | 40 | 85 |
| Flûte marchande | 50 000 | 800 | 300 000 | 16 | 40 | 80 |
| Corvette | 60 000 | 350 | 200 000 | 16 | 48 | 85 |
| Frégate | 70 000 | 400 | 220 000 | 20 | 44 | 80 |
| Corvette militaire | 100 000 | 300 | 210 000 | 20 | 44 | 85 |
| Frégate militaire | 120 000 | 350 | 250 000 | 20 | 48 | 85 |
| Galion | 120 000 | 600 | 280 000 | 16 | 40 | 75 |
| Caraque | 140 000 | 550 | 320 000 | 20 | 48 | 75 |
| Caravelle | 160 000 | 500 | 300 000 | 16 | 44 | 75 |
| Galion de guerre | 180 000 | 400 | 320 000 | 16 | 52 | 70 |
| Vaisseau de ligne | 200 000 | 400 | 340 000 | 12 | 56 | 70 |

La cale se reconnaît à la flûte marchande (800, la plus grande), le prix à sa
progression régulière. Vmin et Vmax sont probablement la vitesse vent debout et
vent arrière : le vaisseau de ligne a l'écart le plus grand. Chaque fiche porte
aussi trois rangs requis, une seconde valeur proche du prix (coût de
construction ?), les dimensions de coque, le décalage des voiles et les
positions des canons.

## 5. Le modèle de la simulation

L'exe n'a pas de RTTI, mais ses noms qualifiés donnent les classes :
`Database::Town`, `Nation`, `Convoy`, `ConvoyAiInfo`, `AutoTradeLogic`,
`AutoTradeRoute`, `Trader`, `StoreKeeper`, `GoodsContainer`, `LimitedContainer`,
`Office`, `OfficeBalance`, `Building`, `BuildingConstruction`, `Captain`, `Ship`,
`Sailor`, `Mission`, `PirateInfo`, `Hideout`, `SeaBattle`, `TownBattle`, `World`,
`Storm`. La simulation tourne côté `Server::Simulation`, même en solo.

La source la plus riche est **l'outil de débogage interne**, resté dans
l'archive : une interface web (`xsl/wac.xsl`) qui affichait l'état du serveur.
Ses colonnes sont les champs de la simulation.

**Une ville** : adresse, position, type (`Village`, `Kolonial`, `Gouverneur`,
`Vizekönig`), nation, habitants (`citizen`), **mendiants** (`beggars`), richesse
(`arm` / `wohlhabend` / `reich` : pauvre, aisée, riche), `Elq`, `Alq`
(probablement la qualité de vie et le **taux de chômage**), navires proposés,
convois IA.

**Une denrée dans une ville** : production, stock, **seuils `X1…X4`**, prix, et
la consommation **décomposée en trois** : habitants (`need_e`), manufactures
(`need_b`), export (`need_x`), plus le total (`need_s`) et un **entrepôt
d'export** (`expo_lgr`).

**Une manufacture** (`GoodsIndustry`) : maisons, locataires, produit, ouvriers,
ouvriers max, **efficacité**, production.

**Un convoi IA** : propriétaire, capacité, cinq taux de remplissage `F0…F4`,
ville cible.

**Le monde, denrée par denrée** : stock, réserve, export, production et
consommation **théoriques puis réelles**, ouvriers, manufactures.

**Les ordres d'un convoi** : `ORDER_AI_TRADE`, `ORDER_TRADEROUTE`,
`ORDER_PROTECT_TOWN`, `ORDER_RAID`, `ORDER_WATCH`, `ORDER_EXPORT`,
`ORDER_FLEET`.

**Ses états** : `STORING`, `SELLING`, `REPAIRING`, `LOADING`, `BUYING`, `IDLE`,
`SEAMAP_MOVE`, `SEAMAP_EMERGENCY`, `BATTLE`.

**Les comportements IA** : `FOLLOW`, `WATCH`, `PIRATE`, `PRIVATEER`,
`CONQUEROR`, `FLEET`, `SLIDER`, `ATTACK`, `TREASUREFLEET`.

**Les acteurs** : `ACT_TRADER_STATIC` (marchands IA fixes), `ACT_NATION_ADMIRAL`,
`ACT_PIRATE_CLAN`, `ACT_PIRATE_PLAYER`, `ACT_PLAYER`.

**La météo** : ensoleillé, brouillard, sécheresse, pluie, tempête, sauterelles.

**Les rangs** : Krämer, Händler, Großhändler, Kaufmann, Fernkaufmann,
Großkaufmann, Ratsherr, Ratsmeister, Ratspräsident, Patrizier.

**Le capitaine** : combat, navigation, commerce, réparation, abordage, vue.

### Les convois marchands de l'IA

Ce qui est établi :

- Chaque ville a un **nombre de convois IA** (colonne `AIConvoys` de la liste des
  villes).
- Chaque convoi IA affiche ses **navires**, sa **capacité**, **cinq taux de
  remplissage** `F0…F4` et une **ville cible** (`Zielstadt`).
- L'exe a un réglage `[Time] KiUpdateConvoySize` (7 680) : la **taille** des
  convois IA est recalculée en cours de partie. Ils ont aussi des temps fixes
  pour entrer au port, acheter et vendre (`Einlaufzeit`, `Einkaufszeit`,
  `Verkaufszeit`).
- Les textes du jeu : « sur la carte maritime, **seule la vitesse maximale est
  considérée** et un convoi ne va jamais plus vite que son **navire le plus
  lent** ».
- Les fiches de navires donnent un rang minimal par type pour les marines. Cinq
  types leur sont **interdits** : pinasse, sloop, flûte, flûte marchande et
  barque pirate. Ce sont les navires de commerce, plus celui des pirates.

Ce qui ne l'est pas : **combien** de convois une ville arme, et de quelle taille.
Aucune table lisible ne le dit. Les cinq taux `F0…F4` correspondent probablement
aux cinq marchandises que produit la ville d'attache.

Ce que la sim en fait (`sim/marchands.lua`, `sim/navires.lua`) :

- Des flottes de **navires marchands PR3**, composées du plus grand au plus
  petit. La cale armée est **proportionnelle à la population**, avec un
  coefficient **mesuré** par `tools/equilibre.gd` (0,55 tonneau par habitant).
- Deux métiers : un **caboteur** sur circuit local pour chaque ville, et pour les
  villes de taille 2 et 3 un **long-courrier** vers une ville cible choisie à
  chaque départ, sur toute la carte.
- La vitesse d'un convoi est la vitesse maximale de son navire le plus lent,
  rapportée à celle du sloop du joueur.

## 6. Le prototype d'eau

`shaders/mer_pr3.gdshader` rejoue la recette de PR3 en surcouche de la carte
peinte : vaguelettes éclairées par défilement de bruit, caustiques sur les
hauts-fonds, écume du rivage et ressac, paillettes. On bascule en jeu avec
**F3**, ou dès le lancement avec `-- --eau-pr3`.

Deux enseignements de l'essai valent pour toute eau vue d'aussi haut. Le reflet
de Fresnel ne varie presque pas à 58° de plongée : ce qui rend les vaguelettes
lisibles, c'est l'éclairage des pentes. Et une écume tirée des courbes de
profondeur dessine des courbes de niveau.

## 7. Le code de l'exécutable

L'exe est un x86 32 bits (base 0x400000, code à 0x401000, données en lecture
seule à 0xB38000), sans symboles. On le lit avec capstone : chaque nom de
réglage est une chaîne de `.rdata`, et l'unique `push offset` qui la charge mène
au code qui s'en sert.

### Le chargeur des réglages

Les réglages sont lus dans un ini par section et par clé, avec un défaut, puis
rangés dans une structure. `constdata.dat` est cette structure **sérialisée** :
les champs y sont dans l'ordre de la structure, sans nom. C'est pourquoi le
fichier ne contient aucun nom, ni en clair ni haché (vérifié sur 9 412
identifiants et huit fonctions de hachage).

| Fonction | Rôle |
|---|---|
| `0x89D6E0` | entier (section, clé, défaut) |
| `0x89D750` | flottant |
| `0x89D7C0` | tableau d'entiers |
| `0x89D8A0` | tableau de flottants |
| `0x89E270` | chaîne |
| `0x854E00` | renvoie la structure économique |

Transformations faites **au chargement**, et donc visibles dans le fichier :

- consommation rangée = arrondi(`Faktor` × 100 × `Ware%02u_Verbrauch` + 0,75),
  avec `Faktor` = 1,1 ;
- `Produktion/Betrieb%02u` = (ouvriers, sortie) ; on range les ouvriers (25) et
  la sortie par ouvrier ;
- quantités des recettes (`Rohstoffbedarf`) × 64, sur un octet ;
- points de vie des navires × 1 000.

La table complète, avec les noms, sort de `outils/pr3_constdata.py`.

### Les unités, et la preuve par les prix

- Un **tonneau** (`1Fass`) vaut 2 000 unités.
- **Production** d'un atelier par jour : sortie par ouvrier × ouvriers (25).
  Bois : 480 × 25 = 12 000 unités = 6 tonneaux.
- **Consommation** d'une ville par jour (`0x7C2080`) : A × habitants ÷ 100
  unités, soit **A ÷ 200 tonneaux pour mille habitants**.
- **Coût** d'un atelier par jour (`0x7C00D0`) : `Grundkosten` (50) × ouvriers ÷ 25
  + `Lohn` (6) × ouvriers = 200 pièces.

Coût ÷ production + intrants redonne **les vingt prix standard** (bois 33,3,
tissu 150, métal 83,3, outils 200, viande 300, vêtements 450, rhum 266,7, pain
141,7). Seuls café et cacao donnent 150 pour 140 affichés. Le prix standard de
PR3 est son coût de production.

### Le prix d'une ville

- Chaque marché range, par denrée, son stock et **quatre seuils X1…X4**.
- `0x856780` intègre les cinq coefficients de `Preisfaktoren` posés sur 0, X1, X2,
  X3 et X4, entre le stock avant et le stock après l'échange : le prix est une
  **moyenne sur le lot**, × prix standard (`0x858100` achat, `0x8581A0` vente).
- Acheter au-delà du stock facture le manque au premier coefficient.
- La série « pénurie » s'applique quand la ville porte le **bit 11** de ses
  indicateurs d'état ; le cran vient du profil de partie (`0x8629B0`).
- Les barres d'abondance sont le nombre de seuils franchis (`0x765310`), ou leur
  version décimale interpolée (`0x764FB0`).

**Les seuils** sont recalculés par `0x7BF8A0`. Avec *t* le besoin de 10 jours en
tonneaux (habitants, plus les intrants des ateliers de la ville) :

    X1 = Grundbedarf + 3 t + matériaux des chantiers − 1,5 × min(production de 10 jours, t)
         (au moins 1)
    X2 = X1 + t
    X3 = X2 + production de 20, 10 ou 4 jours (réglage de partie) + 5
    X4 = X3 + t

Une ville vise donc un stock profond : les prix de pénurie commencent sous 30
jours de besoins, le plateau à 120 % s'étend sur la réserve de production.

### La faim et les fléaux

Dans la consommation quotidienne (`0x7C2080`), chaque denrée non servie
incrémente deux compteurs. L'un compte les **aliments manquants à partir de −3**,
l'autre **toutes les denrées manquantes à partir de −12**. Le premier va à
`0x7685D0`, qui fait évoluer la ville. La famine commence donc au-delà de
**trois aliments manquants**, comme le dit le tutoriel. Une ville de moins de
300 habitants a son compteur forcé à −10 : elle n'entre jamais en famine.

Trois fléaux sont des bits d'état de la ville. Chacun ajoute une consommation de
A × habitants × pourcentage ÷ 10 000 sur une liste de denrées :

| Fléau | Bit | Réglage | Denrées |
|---|---|---|---|
| Peste | 1 | `Verbrauch/Pest` | tissu, vêtements |
| Sauterelles | 5 | `Verbrauch/Heuschrecken` | fruits, chanvre, pain |
| Feu | 6 | `Verbrauch/Feuer` (+ `FeuerSpread`) | bois, briques |

Les fléaux sont chargés par `0x829780` (section `Katastrophen`) et tirés au sort
par `0x7BD5E0` / `0x7BD6F0` / `0x7BD7B0`, qui lancent un événement de durée fixe.
La peste tue en plus (`Pesttote`) et fait émigrer (`Abwanderung`, avec les
facteurs `Arbeiter` et `Pesttote`, dans `0x7B9F40`). Le tirage passe par le
système d'événements de la ville et dépend de la qualité de vie et de la
surpopulation (`0x7C1930`) : il frappe les villes en difficulté.

*Dans la sim* (`sim/economie.lua`), chaque ville tire un fléau chaque jour avec
une probabilité qui monte quand sa qualité baisse ; il dure trente jours, double
la consommation de ses denrées, et la peste ajoute une mortalité. Le tirage est
déterministe (générateur de Park et Miller semé de la ville et du jour).

**La série de prix « pénurie »** (`X%uknapp`, bit 11 de l'état de la ville) est
levée par un second compteur lissé (`0x75C120`) : chaque jour où des denrées
manquent l'augmente du nombre de manquantes, plafonné à 25 ; au-delà de 24 le
marché entier de la ville passe au barème de rareté (`0x768640` pose le bit et
émet l'événement `0x100`). Le compteur redescend et éteint le drapeau dès que la
ville est de nouveau servie. Le compteur de faim (`0x75BA00`, reçu par `0x7685D0`)
suit le même schéma pour le bit de famine (bit 2).

### Les convois de l'IA

`0x79F140` **crée un marchand IA, pas une ville** : il alloue un objet de 0x438
octets et enchaîne cinq étapes :

1. **L'or du marchand IA** (`0x79E210`) : 120 000, 90 000 ou 76 000, choisis par
   une table de sauts sur `[ville+0x20]` (valeurs 1 à 9) — donc selon la nation.
2. **Une étape non lue** (`0x79DCD0`).
3. **Les comptoirs.** Une boucle parcourt les enregistrements du monde
   (`0x825080`, pas de 0x40 octets) en appelant `0x79EC80`, qui abandonne quand
   `0x828260(enregistrement, nation) == 4`. Chaque retour non nul est empilé par
   `0x79F0A0` dans le vecteur `+0x30` du marchand.
4. **Les convois** (`0x79DB00`). La taille visée est la somme des habitants des
   villes rattachées au marchand (vecteur `+0x20`), × 420 ÷ 1 900 : environ
   **0,22 tonneau par habitant**. Puis, **pour chaque élément du vecteur `+0x30`**
   dont l'octet `+0x40` est nul, le jeu crée **`Konvois` convois** (`0x79D6B0`).
5. **Les seuils de prix initiaux** (`0x79C8E0`).

Le nombre de convois d'un marchand vaut donc `Konvois × (éléments retenus du
vecteur +0x30)` — **ce n'est ni « par ville » ni « par marchand »**, et ce compte
d'éléments n'a pas encore été mesuré.

**`Konvois` vaut 2.** Le défaut *compilé* est 3 (`0x8556A6 : push 3 ; push
"Konvois" ; push "Initial" ; call 0x89d6e0 ; mov byte ptr [edi+0x878], al`), mais
`ini/constdata.dat` le surcharge à **2**. Le piège mérite d'être noté : ce fichier
sérialise les champs dans l'ordre de la structure **sans leurs noms**, donc
chercher la chaîne « Konvois » dans les archives ne rend rien et ferait conclure à
tort que le défaut fait foi. Seul `outils/pr3_constdata.py` lit la valeur réelle ;
son calage est confirmé par les six mots qui suivent (64, 64, 128, 7 680, 10,
1 000). Trois autres réglages du même bloc sont également surchargés : `1Fass`
2 000 (défaut 1 000), `Faktor` 1,1 (1,0), `Lohn` 6 (5).

**Combien de marchands IA ? Non résolu**, et la voie statique est fermée. La
chaîne de création est `0x79F140` ← `0x77A460` ← `0x777D20` (le constructeur du
marchand) ← `0x0079947E`, qui vit dans la **méthode virtuelle** `0x00799450` d'un
objet-commande (table virtuelle `0xB77654`), lui-même construit par la **fabrique
de commandes** `0x007751B0`, **case 1** de sa table de sauts (`0x00776290`). Les
commandes étant créées par numéro, un balayage de `call rel32` ne peut pas
remonter plus haut. Les sauvegardes n'aident pas davantage : leur corps est à
8,000 bits/octet d'entropie (0,41 % d'octets nuls), donc comprimé ou chiffré.

**Les acteurs, ordres, états et IA — les énumérations complètes.** Elles ne sont
pas déduites : elles sont écrites en toutes lettres dans `xsl/wac.xsl`, la feuille
de style du vidage de débogage du jeu, sous forme de gabarits nommés.

`TraderType` — **qui** possède des convois :

| 0 | 1 | 2 | 3 | 4 |
|---|---|---|---|---|
| `ACT_TRADER_STATIC` | `ACT_NATION_ADMIRAL` | `ACT_PIRATE_CLAN` | `ACT_PIRATE_PLAYER` | `ACT_PLAYER` |

Le marchand d'une ville est un `ACT_TRADER_STATIC`. **L'amiral d'une nation est un
*Trader* de la même classe** : les convois militaires ne sont pas un sous-système,
c'est le même moteur avec un autre propriétaire.

`ConvoyOrder` — ce qu'un convoi **fait** : `ORDER_NONE`, `ORDER_AI_TRADE`,
`ORDER_TRADEROUTE`, `ORDER_PROTECT_TOWN`, `ORDER_RAID`, `ORDER_WATCH`,
`ORDER_EXPORT`, `ORDER_FLEET` (0 à 7).

`ConvoyState` — où il en **est** : `STATE_STORING`, `STATE_SELLING`,
`STATE_REPAIRING`, `STATE_LOADING`, `STATE_BUYING`, `STATE_IDLE`,
`STATE_SEAMAP_MOVE`, `STATE_SEAMAP_EMERGENCY`, `STATE_BATTLE` (0 à 8).

`AiName` (`aitype`) — **comment** il se conduit : `AIINFO_FOLLOW`, `AIINFO_WATCH`,
`AIINFO_PIRATE`, `AIINFO_PRIVATEER`, `AIINFO_CONQUEROR`, `AIINFO_FLEET`,
`AIINFO_SLIDER`, `AIINFO_ATTACK`, `AIINFO_TREASUREFLEET` (0 à 8).

`PRIVATEER`, `CONQUEROR`, `FLEET` et `TREASUREFLEET` sont donc des **`aitype`
attachés à un convoi**, et non des types d'acteur ni des catégories de convoi —
ce document les a longtemps mal classés. `NationType` complète le tableau :
0 Espagne, 1 Angleterre, 2 France, 3 Hollande, **4 Pirates**, au-delà le joueur.

**La composition d'un convoi** (`0x79D6B0`) :
- le jeu dresse la liste des types de navires marchands, 8 au plus ;
- il en **tire un au hasard**, arme le navire et retranche sa cale de la taille
  visée ;
- il recommence tant qu'il reste du tonnage, **trois navires au plus**.

Un bourg peut donc sortir avec une flûte marchande, une grande ville avec trois
pinasses.

**La taille est revue** tous les `KiUpdateConvoySize` (7 680) : `0x79DB00` resomme
les habitants des villes servies à l'instant du calcul, donc les flottes de l'IA
grossissent avec la population. La division par 1 900 est confirmée (multiplication
magique `0x44FC3A35`, `shr 9` → ÷1 900,6), ce qui valide le `420 ÷ 1 900` de la
sim. *La sim ne redimensionne pas* : ses convois tournent déjà à ~18 % de
remplissage, la capacité n'est jamais le facteur limitant.

**L'objet convoi**, tel que l'exposent ses vidages de débogage (`ConvoyBasics`
`0x880390`, `ConvoyState` `0x880950`) :

| Champ | Offset | Sens |
|---|---|---|
| `owner` | `+0x10` | le marchand (son `+0x40` = type, `+0x14`→`+0x34` = ville d'attache) |
| `posx`, `posy` | `+0x48`, `+0x4A` | position sur la carte (mot) |
| route | `+0x74` | un vecteur de villes (`TownName1 -X- TownName2`, `tripLength`) |
| `order`, `state`, `aitype` | — | l'ordre courant, l'état, et le type d'IA |

**Un convoi de l'IA et un convoi du joueur sont le MÊME OBJET.** Le registre
d'inspecteurs de débogage `0x717940` enregistre 61 classes à la file (`push <nom> ;
call 0x88cb10 ; mov ecx, [eax+0x14] ; call <inspecteur>`), et il n'y a qu'**un seul
`Convoy`** — ni `AiConvoy`, ni `PlayerConvoy`. C'est cohérent avec le vidage de
débogage, où `ConvoyList` liste tous les convois du monde sous un format de ligne
unique (`ConvoyBasics`) portant une colonne *Owner Type* : le propriétaire est un
`Trader`, et le joueur en est un (`ACT_PLAYER`).

**L'IA est un pilote qu'on GREFFE sur un convoi**, pas une sous-espèce de convoi :
le registre déclare une famille séparée, `ConvoyAiInfo` et treize spécialisations —
`Follow`, `Watch`, `Privateer`, `Fleet`, `Pirate`, `Slider`, `Conqueror`, `Attack`,
`TreasureFleet`, `PirateRaid`, `Commuter`, et surtout **`PlayerRaidAiInfo` et
`PlayerPirateAiInfo`**. Ces deux dernières le prouvent : *le joueur aussi* peut
porter une info d'IA. Un convoi PNJ est donc un convoi ordinaire auquel on a
attaché un pilote, et un convoi du joueur un convoi sans pilote — ou avec, selon
le mode.

*Nuance :* l'énuméré `AiName` de `wac.xsl` ne compte que **neuf** valeurs quand le
registre déclare **quatorze** classes d'`AiInfo`. La feuille de style de débogage
est en retard sur le code ; c'est le registre qui fait foi.

Les autres classes du modèle, relevées au même endroit : `Ship`, `Captain` (six
compétences `skill0…skill5` et un `learn`), `GoodsContainer`, `TradeContainer`,
`LimitedContainer`, `StoreKeeper`, `Route`, `AutoTradeLogic`, `AutoTradeRoute`,
`Town`, `Office`, `OfficeBalance`, `Building`, `BuildingConstruction`, `Trader`,
`Nation`, `World`, `PlayerData`, `PirateInfo`, `Hideout` / `HideoutData`,
`Mission`, `SeaBattle` / `SeaBattleShip` / `SeaBattleSector` / `BattleShip`,
`TownBattle` / `TownBattleShip`, `Projectile`, `Mine`, `Sailor`, `Shark`, `Storm`,
`Grasshopper`, `Flotsam`, `Barrel`, `RoadSpline`, `DecoObject`, et les `Event*`
(`MissionTimer`, `MissionIdle`, `TownStatus`, `TownFire`, `TownTurrets`,
`TownFortressUpgrade`, `WorldWeather`, `WorldPirateClanRespawn`). Le capitaine a
donc des **compétences qui progressent**, et le commerce automatique passe par un
`StoreKeeper` sur des `Route` persistantes — celles-là mêmes que le joueur trace.

Cette liste n'est plus relevée à la main : **`py -3 outils/pr3_classes.py`** la
régénère, avec l'adresse de chaque inspecteur, et extrait en plus les **71 classes
du moteur et de l'interface** (`Render::*`, `NGUI::*`, `Client::*Component`) que
le studio déclare par son RTTI maison (`TypeIdSetupGmRtti`). Deux mises en garde
que l'outil répète : PR3 est compilé **sans RTTI MSVC** (`??_R0` × 0), et les
inspecteurs **n'énumèrent pas les champs** de leur classe — leurs corps sont
identiques à une constante près, celle de la fabrique créée par type. On a donc
des noms, pas des dispositions mémoire.

**À quai**, un convoi passe `Einlaufzeit` (128) à entrer, puis `Einkaufszeit` et
`Verkaufszeit` (64 chacun). Le détail de la décision — quelle ville viser, quoi
charger — vit dans cette hiérarchie de classes (`StoreKeeper` / `TradeContainer`
/ `Route`) et non dans une formule isolée : c'est le seul morceau du modèle qui
résiste à la lecture statique. Les trajets de la sim (un caboteur de voisinage,
un long-courrier vers la ville la plus rentable) restent donc les nôtres.

**Le commerce agit sur la réputation** (`0x7839E0`, `0x783B40`), tenue **par
ville** — un tableau indexé par l'identifiant de la ville (`0x75CEF0`, une entrée
par ville) :
- **vendre** à une ville dont le stock est sous son premier seuil X1 fait monter
  sa réputation, au prorata de la part du manque comblée ;
- **acheter** jusqu'à la faire passer sous X1 la fait baisser d'autant.

PR3 tient en plus une réputation par nation (`RepNation`, `ID_REPUTATION_NATION_*`),
nourrie par les missions et les annexions, distincte de celle des villes.

*Dans la sim* (`sim/compagnie.lua`), la réputation du joueur est tenue par ville,
de 0 à 100, et bouge à chaque transaction selon cette règle ; l'affichage par
nation en est la moyenne.

**Dans la sim** (`sim/marchands.lua`) :
- 2 convois par ville — la SIMPLIFICATION assumée de la règle de PR3 ci-dessus
  (`Konvois` convois par comptoir du marchand), faute d'avoir mesuré combien de
  comptoirs un marchand ouvre ;
- une cale visée de habitants × 420 ÷ 1 900, remplie d'un à trois navires
  marchands tirés au hasard (tirage reproductible par ville) ;
- 90 000 pièces d'or partagées entre les deux convois ;
- l'entretien journalier des navires (`DailyCosts`) ;
- **l'or plafonné au capital de travail** : le débordement alimente un fonds de
  construction qui bâtit des ateliers pour les chaînes faibles dont les intrants
  suivent — le mécanisme de `0x7B4F90`, borné à la demande du jour zéro pour
  rattraper le déséquilibre de départ sans devenir un moteur de croissance.

Les trajets restent ceux qu'on a mesurés : le premier convoi en caboteur, le
second au long cours.

### La qualité de vie et la prospérité

**La note sur cent** est calculée en fin de `0x7BF8A0`, juste après les seuils de
prix. Chaque denrée rapporte `poids × min(1, stock/X1)` point — plein dès son
premier seuil X1 atteint, ce que dit le tutoriel : « la fourniture de denrées a un
impact maximum sur la prospérité dès que le stock atteint au moins une barre ».
Quatre groupes, testés par masques de bits (`0x854D50`…`0x854DB0`), chacun
plafonné à vingt points :

| Groupe | Poids | Masque | Denrées |
|---|---|---|---|
| base | 7 | `0x000F` | bois, briques, blé, fruits |
| produits finis | 6 | `0xF8400` | outils, viande, vêtements, cordage, rhum, pain |
| export | 5 | `0x7800` | teintures, café, cacao, tabac |
| autres | 5 × difficulté | `0xFA7C` | maïs, sucre, chanvre, tissu, métal, coton |

Quatre-vingts points au plus ; les vingt derniers viennent des bâtiments publics
et d'un terme de population (bonus sous 800 habitants) et d'emploi. Le tout est
posé par `0x767EF0` sur le flottant `+0x150`, et arrondi sur `+0x154`.

**Les sept niveaux** (`ID_GUI_TOWN_WEALTH_00…07`, le septième `Opulence`) se
lisent de cette note par `0x7C2400` (seuils `0x14`/`0x28`/`0x3C`/`0x5A` =
20/40/60/90) avec deux portes de population (`0x7D0` = 2 000, `0x1770` = 6 000) :

| Niveau | Note | Effet décrit |
|---|---|---|
| Pauvreté | ≤ 20 | 2 % des citoyens redeviennent colons par jour, ni bâtiments ni ouvriers |
| Récession | ≤ 40 | 1 % par jour ; « quand la satisfaction tombe sous 40 %, des citoyens partent » |
| Stagnation | ≤ 60 | aucun effet |
| Redressement / Croissance | ≤ 75 | la ville remonte, tant qu'elle dépasse 2 000 habitants |
| Prospérité | > 75, > 2 000 hab. | entretien −5 %, colons chaque jour |
| Opulence | > 90, > 6 000 hab. | le plus haut niveau |

**La croissance** passe par un stock de colons `+0xD0` qui se convertit en
citoyens `+0xC0` vers une cible `+0xD4`, au plus dix par jour (`0x7BF3D0`,
`0x765160` pose le compte de citoyens). Les colons arrivent et repartent par la
mer : les convois les débarquent (`0x7C9860`) et les rembarquent quand la ville
décline.

### La construction de l'IA

`0x7B4F90`, appelée à chaque révision des marchands, décide quels ateliers bâtir.
Elle parcourt les vingt métiers de la ville et, pour chacun, compare la demande de
l'archipel à sa production :

- elle n'agit que si la qualité de la ville dépasse `NeubauMinAlq` (50, à `+0x877`)
  et s'il reste moins de trente chantiers en cours (`0x1E`) ;
- elle bâtit un atelier du métier quand `demande × 100 > production × 85`
  (`imul 0x64` contre `imul 0x55`), c'est-à-dire quand la production couvre moins
  de ~85 % de la demande — modulée par le `Bauquotient_Mod` de chaque bien ;
- elle vérifie aussi la réserve mondiale contre `NeubauWeltVorratTage` (15).

`0x7B5A90` ajoute le coût du terrain (`Bauplatzkosten`) et le prélève : **c'est là
que passe l'or que les marchands amassent.** Un marchand qui prospère ne
thésaurise pas, il bâtit.

### Les autres chargeurs

- **Navires** (`0x85F7E0`), dans l'ordre :
  - `Capacity`, `Hitpoints`, `HitpointsSail`, `Value` ;
  - rangs `minRankMil`/`maxRankMil`/`minRankPir` ;
  - `Vmin`, `Vmax`, `Wendig` ;
  - assets, dimensions de coque et de voiles, positions des canons ;
  - `Nations` (masque), `Masts`, `Gauge` (**classe** de tirant d'eau 0/1/2 : le
    chargeur n'en garde que le reste modulo 3), `DailyCosts` (entretien
    par jour), `Construct` (coût et matériaux au chantier).
- **Bâtiments** : `Bauplatzkosten` (trois coûts) et `Baukosten Betriebe` (les
  matériaux : 20 bois et 40 briques pour une ferme, 60 et 120 pour une
  manufacture d'outils).
- **Logement** (`Residential`, `0x84E150`) : loyer en six paliers, 100
  locataires, construction à `FillRate` (défaut 65 %), entretien 50, seuils
  `Wohlstand%u`.
- **Partie** (`0x829840`) :
  - fléaux et exode (`Abwanderung`, `Pesttote`) ;
  - licences et réputation ;
  - limites de 100 convois, 50 navires par convoi, 50 navires ;
  - facteur de réputation selon la difficulté, prix de l'équipement ;
  - or, capital et navires de départ.
- **Villes** (`0x8282C0`) : position sur la minimap, biens produits, position,
  type, nations, région, région sonore.
- Les couleurs de voiles (`SailColor_*`) ne sont lues que par une table de
  pointeurs, sans référence directe dans le code.

### Ce que les noms de clés laissent deviner

Les réglages économiques de l'exe (sections `Initial`, `Produktion`, `Hausbau`…)
esquissent la logique de l'IA. **Ce sont des noms, pas du code** : tout ce qui
suit est une hypothèse à vérifier.

- `KiUpdateConvoySize`, `Einlaufzeit`, `Einkaufszeit`, `Verkaufszeit` : les
  convois IA passent un temps fixe à entrer au port, acheter et vendre.
- `StartFabriken`, `NeubauMinAlq`, `NeubauWeltVorratTage`,
  `NeubauOfficeVorratTage` : une ville **bâtit une nouvelle manufacture** quand
  son chômage dépasse un seuil ET que le stock mondial de la denrée tombe sous un
  nombre de jours de consommation.
- `VorratTage` : les réserves se comptent en jours de consommation.
- `Lohn`, `Heuer`, `VerwalterLohn`, `Grundkosten` : salaire ouvrier, solde des
  marins, salaire de l'administrateur, frais fixes.
- `BasicCapacity`, `Lagermiete` : capacité de base d'un comptoir, loyer
  d'entrepôt.
- `Hausbau Waren`, `Hausbau Kosten` : une maison coûte de l'or **et** des
  marchandises.
- `Bettlerfaktor` : les mendiants sont un compartiment de population à part.
- `Schatzflotte` : la flotte au trésor est un réglage économique, pas seulement
  un événement.
- Réglages de partie : `Feuer`, `Heuschrecken` (sauterelles), `Pest`,
  `Abwanderung` (exode), `Arbeiter`, `Lebensqualitaet`.
