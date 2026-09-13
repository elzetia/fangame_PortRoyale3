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

**`constdata.dat`** est écrit par `Serialization::TypeLibrary` : les objets sont
numérotés dans l'ordre et les champs se suivent sans alignement ni étiquette.
Les tableaux ont un compte `u32` devant, les chaînes aussi (terminateur compris).
Les noms des champs sont dans l'exe, en allemand. Changer la taille d'un tableau
casse la numérotation de tout ce qui suit.

**Les maillages** : les deux fichiers commencent par `77 fe ba b0`, et
l'octet 10 donne la taille des données. Le pas d'un sommet se déduit du plus
grand indice : 16 octets (demi-flottants) pour le décor, 80 octets (flottants)
pour les navires. Détail dans l'en-tête de `outils/pr3_mesh.py`.

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
- L'exe a une section `Konvois` avec `KiUpdateConvoySize` : la **taille** des
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

### Ce que les noms de clés laissent deviner

Les réglages économiques de l'exe (sections `Konvois`, `Produktion`, `Hausbau`…)
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
