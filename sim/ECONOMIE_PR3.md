# L'économie de Port Royale 3, relevée dans le jeu

Ce document sert de cahier des charges à `sim/`. Il note ce que PR3 fait
réellement, pas ce qu'on suppose qu'il fait.

**D'où ça sort.** Quatre sources :

1. `ini/constdata.dat`, les constantes du jeu elles-mêmes : prix, facteurs de
   prix, consommation, rendements, recettes, bâtiments (§10). Les valeurs sont
   exactes ; le sens de certaines colonnes est déduit.
2. Les textes du jeu (`data_fr.fuk` → `ui/locale/frfr/global.res`, format `L10N`,
   5 546 entrées). Le tutoriel de PR3 explique ses propres règles, chiffres
   compris. Tout ce qui est entre guillemets ci-dessous en vient **mot pour mot**.
3. `PortRoyale3.exe`, pour la table des marchandises, leurs noms internes et les
   noms des réglages.
4. Les descriptions de bâtiments, pour les chaînes de production.

Le décodeur du format `L10N` : en-tête `L10N` + version + nombre d'entrées, puis
une table de 12 octets par entrée (offset, longueur, hash), le texte en UTF-16-LE.
**Les offsets sont relatifs à 12**, pas à la fin de l'en-tête — c'est le seul
piège. Le hash sert de clé, il n'y a pas de noms de chaînes en clair.

---

## 1. Les vingt marchandises

Relevées d'un bloc dans `PortRoyale3.exe`, avec leurs noms internes :

| # | Interne | Français | Produit à partir de |
|---|---|---|---|
| 1 | `wood` | Bois | — |
| 2 | `bricks` | Briques | — |
| 3 | `grain` | Blé | — |
| 4 | `fruits` | Fruits | — |
| 5 | `corn` | Maïs | — |
| 6 | `sugar` | Sucre | — |
| 7 | `hemp` | Chanvre | — |
| 8 | `cloth` | Textile | Coton |
| 9 | `metals` | Métal | Bois |
| 10 | `cotton` | Coton | — |
| 11 | `tools` | Objets métal | Bois + Métal |
| 12 | `dyestuffs` | Teinture | — |
| 13 | `coffee` | Café | Objets métal (peu) |
| 14 | `cocoa` | Cacao | Objets métal (peu) |
| 15 | `tabacco` *(sic)* | Tabac | — |
| 16 | `meat` | Viande | Maïs |
| 17 | `clothes` | Vêtements | Textile + Teinture |
| 18 | `ropes` | Cordes | Chanvre |
| 19 | `rum` | Rhum | Bois + Sucre |
| 20 | `bread` | Pain | Blé + Sucre |

**L'ordre est celui du jeu**, relevé à l'écran par le joueur — pas celui que
j'avais déduit de l'exécutable. Les noms internes s'y trouvent bien en un bloc,
mais leur rang dans le binaire ne dit pas leur rang dans l'interface : j'avais
supposé un ordre de déclaration inverse, ce qui plaçait Cordes en cinquième et
Pain en dixième. La liste ci-dessus les remet où PR3 les montre.

Elle ne suit ni l'alphabet ni les catégories : elle va des matériaux bruts aux
produits finis en gardant voisines les denrées qu'on achète ensemble. C'est
l'ordre de `sim/marchandises.lua`, et donc celui du comptoir.

Dix marchandises poussent sans rien consommer, dix sont transformées. Aucune
chaîne ne fait plus de deux étages.

## 2. Les catégories

**La nourriture est un groupe déclaré, pas une étiquette par marchandise.** Le
jeu le dit noir sur blanc dans une mission :

> « Les produits suivants sont considérés comme de la nourriture : Blé, Fruits,
> Maïs, Viande et Pain. »

Cinq aliments, dont deux transformés. C'est ce groupe, et lui seul, qui déclenche
la famine — voir §5.

**Les matériaux de construction** sont le Bois et les Briques. La stratégie de
route « Focus sur les matériaux de construction » ne collecte que ces deux-là, et
se désactive « dès que vous aurez accumulé 500 de Bois et 1000 de Briques ».

Les autres marchandises n'ont pas de catégorie déclarée : elles sont consommées
individuellement, chacune avec son propre niveau de besoin.

## 3. Qui consomme quoi

Toutes les marchandises sont consommées par la population — c'est explicite pour
le Chanvre, le Coton, la Teinture, le Cacao, le Café, les Briques, sans exception
relevée. Certaines le sont **en plus** d'être des intrants :

- Le Textile « est consommé directement par la population, mais sert également de
  matière première pour faire des Vêtements ».
- Le Chanvre « est requis pour faire des Cordes. Il est également consommé
  directement par la population ».
- Le Coton, même schéma : « la population ait également besoin directement de Coton ».
- La Teinture : « La population requiert également ce produit en petites quantités. »

Donc : **une marchandise intermédiaire n'échappe pas à la consommation**. Le
modèle n'a pas de classe « bien de production » séparée.

Trois débouchés s'ajoutent à la consommation des habitants :

- **Les manufactures**, qui « prennent toujours leurs matières premières dans
  l'entrepôt », chaque jour, et « cessent de fonctionner » s'il n'y en a pas.
- **La construction**, qui consomme Bois et Briques « récupérés au port de la ville ».
- **L'export vers l'Europe**, qui absorbe Tabac, Cacao, Café et Teinture — « exporté
  vers l'Europe en Galion ». C'est un puits de demande permanent, sans ville en face.

La consommation varie avec la richesse de la ville. Un paramètre de partie :

> « Augmente la consommation de Fruits, de Objets métal, de Viande, de Vêtements
> et réduit la consommation de Blé, de Maïs, de Rhum et de Pain. La valeur
> spécifiée s'applique aux villes prospères et double pour les villes riches. »

Autrement dit : **en s'enrichissant, une ville troque le pain contre la viande**.
Le volume ne fait pas que monter, le panier se déforme.

## 4. Le prix

PR3 n'a pas un prix de marché flottant librement : il a un **coût de production**
comme point d'ancrage, et le prix s'en écarte selon la rareté. Deux paramètres de
partie le disent :

> « Détermine la limite que peut atteindre le prix d'un produit fini
> **relativement à son coût de production** quand ce produit se fait rare dans une
> ville. »

> « Détermine la **rapidité** à laquelle le prix d'un produit **sombre sous son
> prix de production** quand le bien est en surplus dans une ville. »

Il faut donc trois choses par marchandise et par ville : un coût de production de
référence, un plafond exprimé en multiple de ce coût, et une vitesse de descente
sous ce coût en cas de surplus. Le plafond et la vitesse sont des réglages
globaux de partie, pas des valeurs par marchandise.

Noter l'asymétrie : à la hausse le jeu parle d'une **limite**, à la baisse d'une
**vitesse**. La montée est bornée, la chute est progressive.

## 5. La famine

Deux formulations, qui ne disent pas la même chose :

- Le tutoriel : « Si 3 de ces produits font défaut simultanément sur une longue
  période, une famine se déclenche. »
- Une mission : « créant une pénurie de 4 types de marchandises sur 5 pendant
  20 jours ».

La seconde est plus précise et chiffrée (4 aliments sur 5, 20 jours) mais décrit
une condition de mission ; la première est un conseil au joueur. **Tranché par le
code** (§10.8) : la consommation quotidienne compte les aliments manquants à
partir de −3, et la ville décline au-delà de trois. C'est le tutoriel qui a
raison ; la mission décrit un cas plus sévère.

Effets : « La famine peut avoir un impact significatif sur la satisfaction des
citoyens ». Un hôpital « réduit les risques de famine ».

Conseil du jeu, utile pour la formule : « Essayez d'obtenir différentes
nourritures » — la variété compte, pas seulement le tonnage.

## 6. La population

C'est la mécanique la mieux documentée du jeu, et la plus simple.

**Trois états** : colons (*settlers*), citoyens (*citizens*), marins. « Les colons
peuvent devenir citoyens ou marins. »

**La règle centrale**, citée deux fois mot pour mot :

> « Pour chaque emploi pourvu, 4 colons deviennent des citoyens et il y a donc
> dans chaque ville un nombre de citoyens égal à 4x le nombre d'ouvriers. »
> « Un emploi = un ouvrier et 3 membres de sa famille. »

Donc `citoyens = 4 × ouvriers`, exactement. Et l'emploi est créé par les
manufactures. La population d'une ville n'est pas une variable libre : **c'est une
conséquence du nombre de postes de travail**.

Le mouvement inverse est vrai aussi : « Si vous réduisez la production d'une
manufacture, un nombre conséquent d'ouvriers sont renvoyés (et 4x plus de citoyens
redeviennent des colons). »

**Le logement borne le tout** : « Chaque citoyen a besoin d'un endroit où
habiter », « il faut en moyenne une maison par manufacture », et « les marchands
d'une ville construisent toujours de nouvelles maisons lorsque les maisons
existantes sont **remplies à 80%** ». La ville se loge donc toute seule, mais
avec un temps de retard — et c'est ce retard qui fait le goulot.

**Quand ça va mal**, les citoyens se déclassent — deux paliers relevés :
« 2% des citoyens deviennent des colons chaque jour » et « 1% des citoyens
deviennent des colons chaque jour », chacun accompagné de « Il n'est pas possible
d'avoir de nouveaux ouvriers ».

**Les colons arrivent** de deux façons : l'immigration et la croissance propre,
« même sans immigration ».

L'immigration passe par le joueur, et **pas** par un transport direct de colons :

> « Un colon peut également devenir marin. Pour obtenir des colons, vous devez
> embarquer des marins dans une ville et les décharger ailleurs. Plus votre
> popularité est élevée dans une ville, plus vous aurez de marins disponibles. »

C'est le marin qui sert de véhicule : on recrute à un bout, on débarque à l'autre,
et le marin redevient colon. La quantité disponible dépend de la popularité du
joueur dans la ville de départ. Une fois débarqués, « comme ils cherchent du
travail, les colons se dispersent un peu dans toutes les villes ». Une école
« augmente le nombre de colons », avec un bonus plafonné à 100 %, et n'agit
« que sur les villes riches ou prospères ». Un hospice « attire autant les colons
qu'une ville de vice-roi ».

## 7. La prospérité

Un niveau par ville, qui monte avec l'approvisionnement et la population. Seuils
relevés dans les descriptions de paliers :

- « Tant que le commerce continue et que la population est supérieure à
  **2000 habitants**, le niveau de prospérité peut continuer de monter. »
- « Pour parvenir au prochain niveau de prospérité, la ville doit compter plus de
  **6000 habitants**. » — palier accompagné de « entretien -5% » et « De nouveaux
  colons arrivent chaque jour ».
- Palier supérieur : « entretien -5%, production +5% » et « **Deux fois plus** de
  nouveaux colons arrivent chaque jour ».

Il existe un libellé « Prospérité faible » et un objectif de mission « prospérité
supérieure à 75% », donc la prospérité est **un pourcentage** doublé de paliers
nommés.

Ce qui la fait monter, côté marchandises :

> « La fourniture de denrées a un impact maximum sur la prospérité de la ville dès
> que le stock atteint **au moins une barre** dans la fenêtre commerciale. »
> « Quand environ **80%** de tous les produits sont disponibles dans une ville, la
> fourniture des marchandises est déjà bien équilibrée. »

C'est capital pour la simulation : **l'effet d'une marchandise sature très vite**.
Inonder une ville de rhum ne sert à rien ; couvrir 80 % des vingt marchandises,
même faiblement, vaut mieux que saturer cinq d'entre elles.

## 8. Les convois

### Les convois du joueur : les routes commerciales

Une route commerciale est une suite d'escales avec, à chaque escale, ce que le
capitaine achète, vend ou transfère. Le joueur peut tout régler à la main, ou
choisir une **stratégie** préréglée. Celles relevées :

| Stratégie | Ce que fait le capitaine |
|---|---|
| **Manuel** | « le capitaine n'appliquera que les ordres que vous donnez en personne » |
| **Profit** | « échangera tous les biens qu'il peut acheter à bas coût et vendre plus cher » |
| **Prospérité** | « tentera d'échanger les produits qui promettent les profits les plus élevés » |
| **Matières premières** | « va répartir les matières premières entre les différents entrepôts […] acheminées là où elles sont le plus nécessaire » |
| **Matériaux de construction** | Bois et Briques, déchargés au premier entrepôt ; s'arrête à 500 Bois / 1000 Briques |
| **Entrepôts vides** | « collecter toutes les marchandises de l'entrepôt et les déchargera dans le premier entrepôt rencontré » |

Précision du jeu sur les deux premières : « Si le convoi est assez grand, il n'y a
pas de différence entre les stratégies "Prospérité" et "Profit". » Elles ne
divergent que **sous contrainte de cale** — Prospérité priorise ce dont la ville
manque, Profit la meilleure marge, et avec une grande cale on prend tout.

Deux stratégies (« Matières premières », « Entrepôts vides ») précisent si les
consignes de l'administrateur sont respectées ou ignorées : il existe donc un
niveau de réglage par ville qui se superpose à la route.

Le **magasinier** double ce système : il « ne vend pas de matières premières
requises par vos manufactures si les stocks sont inférieurs à la limite fixée ».

### Les convois de l'IA

Les nations font circuler des « Convois commerciaux » nommés par nation (espagnol,
anglais, français, hollandais). Ils sont attaquables et pillables, et **c'est par
eux que transitent les marchandises entre villes IA** : une mission demande de
provoquer une famine « en achetant ces marchandises aux docks **ou en pillant tous
les convois commerciaux qui approchent** » de la ville. Couper les convois d'une
ville suffit donc à l'affamer — l'approvisionnement des villes IA passe
matériellement par des convois, ce n'est pas un flux abstrait.

Les convois militaires sont hors sujet ici, comme demandé.

## 9. L'argent des villes

Oui, les villes ont de l'argent : un **Trésor de la ville**, consultable
(« Le Trésor de la ville contient %1 »), transférable, et pillable (« Vous pillez
le Trésor de la ville avant de partir avec votre convoi »).

Ce qui n'est pas établi : si ce trésor **borne les achats** de la ville. Rien dans
les textes ne dit qu'une ville cesse d'acheter faute de fonds, et le modèle
habituel de la série est que la ville achète toujours au prix courant, le trésor
servant aux dépenses publiques et au butin. À vérifier en jeu avant de lier les
deux dans la simulation.

## 10. Les tables chiffrées de `constdata.dat`

Une version précédente de ce document affirmait qu'elles étaient introuvables.
C'était faux : le premier balayage cherchait des tableaux **alignés** de vingt
valeurs, alors que le flux n'est pas aligné. Les tableaux y sont préfixés par
leur compte (`u32 20` puis les vingt valeurs), à n'importe quel octet.

L'ancre a été posée par texte connu : les prix relevés à l'écran (33, 33, 33,
50…) sortent d'un bloc, en entiers 16 bits. Tout le reste s'est lu à partir de
là, en suivant la structure. `outils/pr3_constdata.py` ressort toutes ces tables
depuis l'installation locale, sans rien copier dans le dépôt.

Les **noms** des tables ne sont pas dans le fichier. Ils sont dans l'exe, en
allemand (`Standardpreise`, `Preisfaktoren`, `Warenverbrauch`, `Produktion`,
`Rohstoffbedarf`…), dans l'ordre inverse de leur lecture. Ce qui est **certain**
ci-dessous est marqué comme tel. Le reste est une lecture par recoupement,
marquée « probable ».

### 10.1 Prix standard — certain

| Denrée | Prix | | Denrée | Prix |
|---|---|---|---|---|
| Bois | 33 | | Outils | 200 |
| Briques | 33 | | Teinture | 100 |
| Blé | 33 | | Café | 140 |
| Fruits | 50 | | Cacao | 140 |
| Maïs | 50 | | Tabac | 100 |
| Sucre | 50 | | Viande | 300 |
| Chanvre | 50 | | Vêtements | 450 |
| Tissu | 150 | | Cordage | 150 |
| Métal | 83 | | Rhum | 267 |
| Coton | 50 | | Pain | 142 |

C'est exactement `prix` dans `sim/marchandises.lua`.

### 10.2 Facteurs de prix — certain

Juste après les prix : **trois crans**, chacun avec deux séries de cinq
coefficients, une « normale » et une « `knapp` » (pénurie) :

| Cran | Normal (stock vide → plein) | Pénurie |
|---|---|---|
| 0 | 2,0 · 1,8 · 1,2 · 1,2 · 0,8 | 3,0 · 2,7 · 1,2 · 1,2 · 0,8 |
| 1 | 1,8 · 1,6 · 1,2 · 1,2 · 0,7 | 2,7 · 2,4 · 1,2 · 1,2 · 0,7 |
| 2 | 1,6 · 1,4 · 1,1 · 1,1 · 0,6 | 2,4 · 2,1 · 1,1 · 1,1 · 0,6 |

Le code le confirme (`outils/PR3_TECHNIQUE.md`, §7) :
- **prix = prix standard × moyenne des coefficients** sur le lot échangé ;
- les coefficients sont posés sur le stock 0 et les quatre seuils `X1…X4` de la
  ville (§10.5) ;
- le cran vient du profil de partie ;
- la série « pénurie » s'applique quand la ville porte un indicateur d'état
  particulier (le bit 11).

### 10.3 Consommation, production, besoin de base — certain

Les noms et les transformations viennent du chargeur des réglages de l'exe.

| Denrée | `Verbrauch` (ini) | A (rangé) | Sortie par ouvrier | `Grundbedarf` |
|---|---|---|---|---|
| Bois | 2,5 | 275 | 480 | 30 |
| Briques | 5 | 550 | 480 | 60 |
| Blé | 5 | 550 | 480 | 5 |
| Fruits | 4 | 440 | 320 | 5 |
| Maïs | 2 | 220 | 320 | 5 |
| Sucre | 2 | 220 | 320 | 5 |
| Chanvre | 2 | 220 | 320 | 5 |
| Tissu | 1 | 110 | 160 | 5 |
| Métal | 1 | 110 | 240 | 5 |
| Coton | 2 | 220 | 320 | 5 |
| Outils | 1 | 110 | 160 | 5 |
| Teinture | 0,5 | 55 | 160 | 5 |
| Café | 1 | 110 | 160 | 5 |
| Cacao | 1 | 110 | 160 | 5 |
| Tabac | 1 | 110 | 160 | 5 |
| Viande | 1 | 110 | 80 | 5 |
| Vêtements | 1 | 110 | 80 | 5 |
| Cordage | 2 | 220 | 160 | 5 |
| Rhum | 1 | 110 | 80 | 5 |
| Pain | 2 | 220 | 160 | 5 |

- **Consommation** : A = arrondi(`Faktor` × 100 × `Verbrauch` + 0,75), avec
  `Faktor` = 1,1. Une ville consomme A × habitants ÷ 100 unités par jour. Un
  tonneau valant 2 000 unités, cela fait **A ÷ 200 tonneaux pour mille habitants
  par jour**. C'est l'échelle de la table relevée par le joueur.
- **Production** : chaque atelier a **25 ouvriers**, ce qui confirme le tutoriel
  et `Economie.EMPLOIS_PAR_FABRIQUE`. Il produit sortie × 25 unités par jour : un
  atelier de bois donne 6 tonneaux, une manufacture de viande 1.
- **`Grundbedarf`** : un besoin de base, en tonneaux, ajouté au premier seuil de
  prix (§10.5). `Minimalmengen` vaut 1 partout. Le modificateur de construction
  `Bauquotient_Mod` vaut 0,95 pour le bois et les briques, 1 ailleurs.
- **L'export** reste compté à part (café, cacao, tabac, teinture), comme le
  montrait déjà la table du joueur.

**Dans la sim**, `sim/marchandises.lua` divise A par 200, comme PR3, et chaque
denrée porte son `Grundbedarf`. Une échelle de 50 avait été essayée avant la
lecture des seuils de prix, pour qu'une cale de sloop pèse sur un marché ; PR3
obtient cet effet par des stocks visés profonds (§10.5), et la consommation quatre
fois trop forte vidait la carte.

### 10.4 Recettes et coût de production — certain

Le chargeur range chaque quantité **× 64**. Une première lecture divisait par 32
et y voyait une coïncidence (« une ferme de maïs nourrit exactement une
manufacture de viande ») : elle était fausse.

| Produit | Intrants par unité |
|---|---|
| Tissu | 1 coton |
| Métal | 0,5 bois |
| Outils | 0,5 bois + 1 métal |
| Café | 0,25 outils |
| Cacao | 0,25 outils |
| Viande | 2 maïs |
| Vêtements | 1 tissu + 1 teinture |
| Cordage | 1 chanvre |
| Rhum | 0,5 bois + 1 sucre |
| Pain | 0,5 blé + 0,5 sucre |

**La preuve est dans les prix.** Un atelier coûte `Grundkosten` (50) + 25 ouvriers
× `Lohn` (6) = 200 pièces par jour. Divisé par sa production, plus le coût de ses
intrants à ces quantités, on retrouve **les vingt prix standard** :

- bois 33,3, tissu 150, métal 83,3, outils 200 ;
- viande 300, vêtements 450, rhum 266,7, pain 141,7.

Seuls café et cacao font exception : 150 calculés pour 140 affichés. **Le prix
standard de PR3 est son coût de production** (§4).

**Dans la sim**, `sim/marchandises.lua` a ces recettes. Trois changements les
accompagnent, sans lesquels la carte s'affamait :
- **les ateliers comptent** dans le stock visé d'une ville ;
- **la famine compte trois aliments sur cinq** (§10.8), et le pain rejoint la
  nourriture ;
- **les convois sont armés de navires de PR3**.

Mesuré sur cinq ans par `tools/equilibre.gd`, à partir de 82 500 habitants :

| | Population | Villes en disette | Outils | Café | Pain |
|---|---|---|---|---|---|
| Avant PR3 | 74 600 | 56 | 2 % | sans recette | 17 % |
| Recettes à /32 | 118 600 | 15 | 48 % | 35 % | 48 % |
| Recettes à /64 (justes) | 119 100 | 14 | 32 % | 57 % | 46 % |
| Modèle PR3 complet (§10.10) | 155 800 | 2 | 59 % | 44 % | 29 % |

Les trois premières lignes comptent en disette les villes dont le troisième
aliment le mieux servi l'est à moins de 97 % ; la dernière compte les villes en
famine au sens de PR3, plus de trois aliments manquants.

### 10.5 Le prix d'une ville et ses seuils — certain

Chaque ville tient, pour chaque denrée, quatre seuils de stock `X1…X4`,
recalculés régulièrement. Avec *t* le besoin de dix jours en tonneaux (habitants
et intrants de ses ateliers) :

    X1 = Grundbedarf + 3 t + matériaux des chantiers − 1,5 × min(production de 10 jours, t)
         (au moins 1)
    X2 = X1 + t
    X3 = X2 + production de 20, 10 ou 4 jours (réglage de partie) + 5
    X4 = X3 + t

Les coefficients se lisent donc ainsi :
- **2,0 → 1,8** tant que le stock est sous trente jours de besoins ;
- **1,8 → 1,2** sur les dix jours suivants ;
- **plateau à 1,2** sur toute la réserve de production ;
- **1,2 → 0,8** sur dix jours de plus ;
- **0,8** au-delà.

Une ville qui produit la denrée baisse son premier seuil de quinze jours de sa
production : elle se juge moins vite en pénurie de ce qu'elle fait elle-même.

Les barres d'abondance sont le nombre de seuils franchis. `sim/economie.lua`
calcule désormais ces seuils comme PR3 (§10.10). Ils remplacent des fractions
fixes d'une réserve de trente jours (0,17 · 0,90 · 1,10 · 2,05), qui tenaient la
forme de la courbe mais pas sa profondeur.

### 10.6 Bâtiments — certain

Quarante-trois fiches, dans l'ordre de l'enum `BLD_` de l'exe. Chaque fiche
contient :
- **`Bauplatzkosten`** : trois coûts en or ;
- **`Baukosten Betriebe`** : les matériaux de construction, en bois et briques ;
- deux valeurs dérivées : la valeur de ces matériaux, et un octet égal à leur
  tonnage ÷ 10, probablement la durée du chantier.

| Bâtiment | Coûts | Matériaux |
|---|---|---|
| Fermes, plantations, teinture, tabac | 8 000 / 16 000 / 24 000 | 20 bois, 40 briques |
| Coton | 8 000 / 16 000 / 24 000 | 30 bois, 60 briques |
| Métal, café, cacao, rhum, pain | 10 000 / 20 000 / 30 000 | 40 bois, 80 briques |
| Tissu, viande, cordage | 12 000 / 24 000 / 36 000 | 40 bois, 80 briques |
| Outils | 16 000 / 32 000 / 48 000 | 60 bois, 120 briques |
| Vêtements | 18 000 / 36 000 / 54 000 | 60 bois, 120 briques |
| Maison | 14 000 / 28 000 / 42 000 | 40 bois, 80 briques |
| Entrepôt, arbres, puits | 6 000 / 12 000 / 18 000 | 20 bois, 40 briques |
| École, hôpital, pompiers, hospice, ambassade, bordel | 14 000 / 28 000 / 42 000 | 60 bois, 120 briques |
| Chantier naval | 50 000 / 100 000 / 150 000 | 100 bois, 200 briques |
| Hôtel de ville | 200 000 / 400 000 / 600 000 | 200 bois, 400 briques |

Une lecture précédente prenait les matériaux pour des nombres d'ouvriers. Tous
les ateliers ont 25 ouvriers.

Le logement (`Residential`) loge 100 locataires par maison. Un nouveau logement
est bâti à `FillRate` de remplissage : le défaut du code est **65 %**, le
tutoriel parle de 80 %. La valeur réelle n'a pas été retrouvée.

### 10.7 Les réglages de la partie — certain

| Réglage | Valeur | Sens |
|---|---|---|
| `1Fass` | 2 000 | unités par tonneau |
| `Lohn` | 6 | salaire d'un ouvrier par jour |
| `Grundkosten` | 50 | frais fixes d'un atelier par jour |
| `Heuer` | 2 | solde d'un marin par jour |
| `VerwalterLohn` | 50 | salaire de l'administrateur |
| `VorratTage` | 15 | jours de production gardés par un atelier |
| `NeubauOfficeVorratTage` / `NeubauWeltVorratTage` | 5 / 15 | seuils de réserve pour bâtir |
| `NeubauMinAlq` | 50 | chômage minimal pour bâtir un atelier |
| `StartFabriken` | 20 | ateliers au départ |
| `Konvois` | 2 | convois IA par ville au départ |
| `Einlaufzeit` / `Einkaufszeit` / `Verkaufszeit` | 128 / 64 / 64 | temps à quai |
| `BasicCapacity` | 1 000 | capacité de base d'un comptoir |
| `Lagermiete` | 0,1 / 0,2 / 0,3 | loyer d'entrepôt |
| `Bettlerfaktor` | 1,4 | facteur des mendiants |

### 10.8 Faim, fléaux, prospérité — certain

**La faim.** Chaque jour, chaque denrée non servie incrémente deux compteurs :
- les **aliments manquants, à partir de −3** ;
- **toutes les denrées manquantes, à partir de −12**.

La ville évolue selon le premier : la famine commence au-delà de **trois
aliments manquants**, ce qui tranche la contradiction du §5 en faveur du
tutoriel. Une ville de moins de 300 habitants n'entre jamais en famine.

**La série de prix « pénurie »** (bit 11, `X%uknapp`) est levée par un compteur
lissé (`0x75C120`) : chaque jour où des denrées manquent l'incrémente du nombre
de manquantes, plafonné à 25 ; au-delà de 24 la ville passe au barème de rareté,
et sans manque le compteur redescend et l'éteint. Le même schéma tient le
compteur de faim (`0x75BA00`, à partir de son propre seuil).

**Les fléaux** ajoutent une consommation en pourcentage de A (`0x7C2080`), et
sont chargés depuis `Katastrophen`/`Verbrauch` (`0x829780`) :
- **peste** (`Pest`) : tissu et vêtements ;
- **sauterelles** (`Heuschrecken`) : fruits, chanvre et pain ;
- **feu** (`Feuer`, avec `FeuerSpread`) : bois et briques.

Ils sont tirés au sort (`0x7BD5E0` lance un événement de durée `2`, `0x7BD6F0`,
`0x7BD7B0`), et la peste tue en plus (`Pesttote`) et fait émigrer (`Abwanderung`,
facteurs `Arbeiter` et `Pesttote`, `0x7B9F40`).

**La qualité de vie** (`0x7BF8A0`, en fin de calcul des seuils) est une note sur
cent. Chaque denrée rapporte `poids × min(1, stock/X1)` point, plein dès son
premier seuil de prix atteint — « la fourniture de denrées a un impact maximum
sur la prospérité dès que le stock atteint au moins une barre ». Les vingt
denrées forment quatre groupes, chacun plafonné à vingt points :

| Groupe | Poids | Denrées |
|---|---|---|
| base | 7 | bois, briques, blé, fruits |
| produits finis | 6 | outils, viande, vêtements, cordage, rhum, pain |
| export | 5 | teintures, café, cacao, tabac |
| autres | 5 (× difficulté) | maïs, sucre, chanvre, tissu, métal, coton |

Quatre-vingts points au mieux ; les vingt derniers viennent des bâtiments publics
(école, hôpital…) et d'un terme de population et d'emploi.

**La prospérité** a sept niveaux nommés (`ID_GUI_TOWN_WEALTH_00…07`, plus
`Opulence`), lus de la note sur cent (`0x7C2400`, seuils 20/40/60/75/90) avec des
portes de population :

| Niveau | Note | Effet |
|---|---|---|
| Pauvreté | ≤ 20 | 2 % des citoyens redeviennent colons par jour ; ni bâtiments ni ouvriers |
| Récession | ≤ 40 | 1 % par jour ; « sous 40 %, des citoyens partent chaque jour » |
| Stagnation | ≤ 60 | ni montée ni descente |
| Redressement / Croissance | ≤ 75 | la ville remonte |
| Prospérité | > 75 | colons chaque jour, au-delà de 2 000 habitants ; entretien −5 % |
| Opulence | > 90 | au-delà de 6 000 habitants |

La croissance passe par un stock de colons (`+0xD0`) qui se convertit en citoyens
(`+0xC0`) vers une cible (`+0xD4`), au plus dix par jour (`0x7BF3D0`) ; les
colons arrivent et repartent par la mer, portés par les convois (`0x7C9860`).

**La construction de l'IA** (`0x7B4F90`) : chaque marchand, à intervalle
`KiUpdateConvoySize`, parcourt les vingt métiers et bâtit un atelier de la
marchandise dont la demande de l'archipel dépasse `Bauquotient × production`
(comparaison `demande × 100 > production × 85`), à condition que la ville soit
au-dessus de `NeubauMinAlq` (50) de qualité et qu'il reste moins de trente
chantiers en cours. C'est là que passe l'or que les marchands amassent —
`0x7B5A90` ajoute le coût du terrain et le prélève.

### 10.9 Ce qui a été tranché

- **Café et cacao, 150 calculés pour 140 affichés.** Le prix standard est **lu**
  dans la table `Standardpreise`, pas calculé : café et cacao y valent 140, quand
  la formule coût-de-production (100 de main-d'œuvre + 0,25 outil × 200 = 150) en
  donnerait 150. Ce sont les deux seules denrées où la table de PR3 s'écarte de sa
  propre formule, d'environ 7 % vers le bas — un choix de son concepteur. La sim
  utilise la valeur de la table (140), donc elle affiche le bon prix ; il n'y a
  rien à corriger, seulement à expliquer l'écart.
- **`FillRate`.** Le chargeur (`0x84E150`) pose 65 % par défaut à `+0x372` ; le
  tutoriel parle de 80 %. On n'a pas retrouvé le lecteur à l'exécution : cette
  valeur ne pèse que sur le décompte des maisons affiché (`Economie.demographie`),
  pas sur l'économie. La sim garde les 80 % du tutoriel.
- **Le trésor.** Les clés `Treasure` (`0x854900` : `scaleX/Y`, `StartX/Y`,
  `EndX/Y`, `minPosY`, `maxPosY`) décrivent la disposition de la **chasse au
  trésor enfoui**, un mini-jeu — hors du modèle économique.
- **Trajets et débits de départ.** Le nombre et la taille des convois IA sont lus
  (2 par ville, habitants × 420 ÷ 1 900) ; leurs trajets restent les nôtres (un
  caboteur, un long-courrier). Les débits de départ se déduisent de la demande,
  puis la construction de l'IA prend le relais comme dans le jeu (`StartFabriken`
  = 20 ateliers au départ).

### 10.10 Ce que la sim applique

Tout ce qui précède et qui se simule sans bâtiments ni combats est dans `sim/` :

| Règle de PR3 | Où |
|---|---|
| Consommation A ÷ 200 tonneaux pour mille habitants, export à part | `sim/marchandises.lua` |
| Recettes à /64, prix standard, `Grundbedarf` | `sim/marchandises.lua` |
| Seuils X1…X4 en jours de besoins, avec la réserve de 20 jours de production | `sim/economie.lua` |
| Prix = moyenne de la courbe sur le lot, sans commission ; la ville peut être vidée | `sim/economie.lua` |
| Faim : aliments manquants à partir de −3, denrées à partir de −12, pas de famine sous 300 habitants | `sim/economie.lua` |
| 25 ouvriers par atelier, 4 citoyens par emploi, 100 locataires par maison | `sim/economie.lua` |
| **Qualité de vie sur cent, par quatre groupes de denrées ; sept niveaux de prospérité** | `sim/economie.lua` |
| **Croissance et déclin gradués par la prospérité : Pauvreté −2 %/j, Récession −1 %/j, Prospérité +colons, freinés par la subsistance** | `sim/economie.lua` |
| **Série de prix « pénurie » par ville, levée par un compteur de manque lissé (seuil 24)** | `sim/economie.lua` |
| Seize navires, leur cale, leur vitesse maximale et leur entretien journalier | `sim/navires.lua` |
| Entretien du navire du joueur, prélevé chaque jour | `sim/compagnie.lua` |
| 2 convois IA par ville, cale visée de habitants × 420 ÷ 1 900, 1 à 3 navires tirés au hasard, 90 000 pièces | `sim/marchands.lua` |
| **Or d'un convoi plafonné à son capital de travail ; le débordement bâtit des ateliers pour les chaînes faibles (comme l'IA de PR3)** | `sim/marchands.lua` |
| **Réputation du joueur par ville, montée en comblant un manque, baissée en le creusant (moyenne par nation pour l'affichage)** | `sim/compagnie.lua` |
| **Fléaux (peste, sauterelles, feu) : consommation doublée sur leurs denrées, peste mortelle ; tirés surtout dans les villes mal loties** | `sim/economie.lua` |

Mesuré sur douze ans par `tools/equilibre.gd`, à partir de 82 500 habitants :
- **Population** : elle monte régulièrement puis plafonne autour de 160 000 (un peu
  moins qu'avant les fléaux, qui coûtent quelques habitants).
- **Famine** : de 0 à 6 villes selon les années.
- **Pénurie générale** : 0 à 1 ville.
- **Or moyen d'un convoi** : borné, autour de 65 000 à 85 000 pièces (au lieu de
  s'envoler vers plusieurs millions).
- **Ateliers à douze ans** : métal et tissu 91 %, cordage 80 %, viande et vêtements
  60 %, café 59 %, outils 57 %, pain 48 %, rhum 37 %, cacao 22 %.

Le pain, qui restait la chaîne la plus faible (24 %), monte à 48 % ; les vêtements
passent de 33 % à 60 %. La construction de l'IA comble les chaînes dont les
intrants sont disponibles, jusqu'à la demande du jour zéro, puis s'arrête : elle
rattrape le déséquilibre de départ sans devenir un moteur de croissance sans fin.

**Comment la prospérité est appliquée.** La note de PR3 est reproduite denrée par
denrée (`Marchandises.GROUPES_QUALITE`), et c'est elle qui commande la
démographie — la vitesse de PR3, non plus le seul compteur de faim. La famine
(trois aliments manquants) l'emporte toujours ; la subsistance freine la
croissance, si bien qu'une ville prospère de tissu mais sans pain n'enfle pas
au-delà de ce que sa nourriture porte.

**La réputation** (`sim/compagnie.lua`) est celle de `0x7839E0` / `0x783B40`, et
elle est tenue **par ville** : PR3 la range dans un tableau indexé par
l'identifiant de la ville (`0x75CEF0`). Vendre à une ville dont le stock est sous
X1 comble un manque et fait monter SA réputation, au prorata de la part comblée ;
acheter jusqu'à la faire passer sous X1 la fait baisser d'autant. De 0 à 100, à
partir de 50. Le jeu tient aussi une réputation par nation (`RepNation`, nourrie
par les missions et les annexions) ; le commerce ne touche que celle de la ville,
et on en dérive une moyenne par nation pour l'affichage large.

**Les fléaux** (`sim/economie.lua`) sont tirés au sort, plus souvent dans les
villes à basse qualité — l'écho du déclencheur de PR3 (`0x7C1930`), qui frappe les
villes en difficulté. Chacun double la consommation de ses denrées le temps qu'il
dure, et la peste tue et fait fuir (`Pesttote`, `Abwanderung`).

**Ce qui reste une approximation, faute d'avoir été entièrement lu :**
- **Bâtiments publics** : les vingt derniers points de qualité (école, hôpital…)
  sont remplacés par une dotation civique proportionnelle à la note des denrées.
- **Trajets des convois** : un caboteur de voisinage et un long-courrier vers la
  ville la plus rentable, mesurés et non lus dans la machine à états de PR3.
- **Déclenchement exact des fléaux** : PR3 les fait passer par son système
  d'événements (objets de quête), impénétrable à la lecture statique ; on en
  reproduit la fréquence et les effets, pas le tirage octet pour octet.
