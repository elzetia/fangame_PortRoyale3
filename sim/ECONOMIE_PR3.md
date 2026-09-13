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
une condition de mission ; la première est un conseil au joueur. Elles peuvent
coexister — un seuil d'alerte et un seuil de déclenchement. **À trancher en jeu**,
c'est le seul point de ce document où deux sources se contredisent.

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

### 10.2 Facteurs de prix — certain pour les valeurs, probable pour le sens

Juste après les prix : **trois jeux**, chacun de deux séries de cinq
coefficients, une « normale » et une « `knapp` » (pénurie) :

| Jeu | Normal (5 paliers de stock) | Pénurie |
|---|---|---|
| 0 | 2,0 · 1,8 · 1,2 · 1,2 · 0,8 | 3,0 · 2,7 · 1,2 · 1,2 · 0,8 |
| 1 | 1,8 · 1,6 · 1,2 · 1,2 · 0,7 | 2,7 · 2,4 · 1,2 · 1,2 · 0,7 |
| 2 | 1,6 · 1,4 · 1,1 · 1,1 · 0,6 | 2,4 · 2,1 · 1,1 · 1,1 · 0,6 |

Le modèle qui s'en dégage : **prix = prix standard × facteur**, le facteur étant
interpolé selon le stock entre cinq paliers. L'outil de débogage interne du jeu
(voir `outils/PR3_TECHNIQUE.md`) affiche pour chaque denrée de chaque ville
quatre seuils `X1…X4` à côté du prix : ce sont les bornes de ces paliers, propres
à chaque ville. Stock vide → ×2 (×3 en pénurie), stock plein → ×0,8.

Les trois jeux correspondent très probablement aux trois crans du réglage de
partie « prix » (`PriceStandard`). Cela rejoint §4 : le plafond est **borné**
(le premier coefficient), la chute est **progressive** (les paliers).

### 10.3 Consommation et rendement — certain pour les valeurs

Deux tableaux de vingt, suivis d'un troisième :

| Denrée | A (consommation) | B (rendement d'une manufacture) | C |
|---|---|---|---|
| Bois | 275 | 480 | 30 |
| Briques | 550 | 480 | 60 |
| Blé | 550 | 480 | 5 |
| Fruits | 440 | 320 | 5 |
| Maïs | 220 | 320 | 5 |
| Sucre | 220 | 320 | 5 |
| Chanvre | 220 | 320 | 5 |
| Tissu | 110 | 160 | 5 |
| Métal | 110 | 240 | 5 |
| Coton | 220 | 320 | 5 |
| Outils | 110 | 160 | 5 |
| Teinture | 55 | 160 | 5 |
| Café | 110 | 160 | 5 |
| Cacao | 110 | 160 | 5 |
| Tabac | 110 | 160 | 5 |
| Viande | 110 | 80 | 5 |
| Vêtements | 110 | 80 | 5 |
| Cordage | 220 | 160 | 5 |
| Rhum | 110 | 80 | 5 |
| Pain | 220 | 160 | 5 |

**A est la table de consommation** : `conso` dans `sim/marchandises.lua` vaut
exactement A / 200, sauf pour quatre denrées. Café, cacao et tabac y sont à
1,3 × A / 200, et teinture à 1,2 × A / 200. Ce sont justement les quatre denrées
exportées vers l'Europe (§3). La table relevée par le joueur incluait donc
probablement l'export, que PR3 compte à part (`Verbr. Export` dans l'outil de
débogage).

**B est le rendement d'une manufacture** (probable, et fortement recoupé par les
recettes, §10.4). L'unité de temps n'est pas établie : seuls les rapports
comptent.

**C** : 30 bois, 60 briques, 5 pour tout le reste. Probablement les stocks
minimaux qu'une ville garde (`Minimalmengen`), les matériaux de construction à
part.

### 10.4 Recettes — certain

Pour chaque denrée, jusqu'à quatre index d'intrants, puis en regard leur quantité
par unité produite, en 1/32 :

| Produit | Intrants par unité |
|---|---|
| Tissu | 2 coton |
| Métal | 1 bois |
| Outils | 1 bois + 2 métal |
| Café | 0,5 outils |
| Cacao | 0,5 outils |
| Viande | 4 maïs |
| Vêtements | 2 tissu + 2 teinture |
| Cordage | 2 chanvre |
| Rhum | 1 bois + 2 sucre |
| Pain | 1 blé + 1 sucre |

Le recoupement avec B est parfait : **une ferme de maïs (320) nourrit exactement
une manufacture de viande (80 × 4)**. De même, une plantation de coton nourrit
une manufacture de tissu, une chanvrière une corderie, et un tissage plus une
teinturerie une manufacture de vêtements. Les chaînes ont été équilibrées une
pour une. C'est ce qui confirme que B est bien le rendement.

**Écarts avec `sim/marchandises.lua`**, à corriger quand on voudra coller à PR3 :

- Pain : la sim dit blé + **maïs**, PR3 dit blé + **sucre** (le §1 le disait déjà).
- Viande : 2 maïs dans la sim, **4** dans PR3.
- Vêtements : 1 + 1 dans la sim, **2 + 2** dans PR3.
- Rhum : 1 sucre + 0,5 bois dans la sim, **2 sucre + 1 bois** dans PR3.
- Métal, café et cacao n'ont pas de recette dans la sim ; PR3 leur en donne une.

### 10.5 Bâtiments — valeurs certaines, sens des champs probable

Quarante-trois fiches, dans l'ordre de l'enum `BLD_` de l'exe : vingt
manufactures, puis les bâtiments de ville, puis ceux du marchand. Chaque fiche :
trois coûts, une valeur X, un octet, une paire.

| Bâtiment | Coûts | X | Octet | Paire |
|---|---|---|---|---|
| Bois, briques, blé, fruits, maïs, sucre, chanvre, teinture, tabac | 8 000 / 16 000 / 24 000 | 2 000 | 6 | 20 / 40 |
| Coton | 8 000 / 16 000 / 24 000 | 3 000 | 9 | 30 / 60 |
| Métal, café, cacao, rhum, pain | 10 000 / 20 000 / 30 000 | 4 000 | 12 | 40 / 80 |
| Tissu, viande, cordage | 12 000 / 24 000 / 36 000 | 4 000 | 12 | 40 / 80 |
| Outils | 16 000 / 32 000 / 48 000 | 6 000 | 18 | 60 / 120 |
| Vêtements | 18 000 / 36 000 / 54 000 | 6 000 | 18 | 60 / 120 |
| Maison (du marchand) | 14 000 / 28 000 / 42 000 | 18 000 | 12 | 40 / 80 |
| Entrepôt | 6 000 / 12 000 / 18 000 | 8 000 | 6 | 20 / 40 |
| École, hôpital, pompiers, hospice, ambassade, bordel | 14 000 / 28 000 / 42 000 | 20 000 | 18 | 60 / 120 |
| Arbres, puits | 6 000 / 12 000 / 18 000 | 8 000 | 6 | 20 / 40 |
| Chantier naval | 50 000 / 100 000 / 150 000 | 60 000 | — | 100 / 200 |
| Hôtel de ville | 200 000 / 400 000 / 600 000 | 220 000 | — | 200 / 400 |
| Forteresse | 100 000 / 200 000 / 300 000 | — | — | 25 / 50 |

Pour les manufactures, X = 100 × le premier nombre de la paire, et l'octet vaut
0,3 × ce même nombre. Tout est proportionnel à la paire. Lecture probable : la
paire est le **nombre d'ouvriers** (au premier et au second niveau
d'agrandissement), X le coût d'entretien, l'octet la durée du chantier en jours.
Si c'est bien ça, `Economie.EMPLOIS_PAR_FABRIQUE = 25` est une moyenne. PR3
emploie 20 ouvriers dans une ferme et 60 dans une manufacture d'outils, soit
80 et 240 citoyens par la règle du ×4 (§6).

### 10.6 Ce qu'il reste à trancher

- L'unité de temps de A et de B (par jour ? pour 1 000 habitants ?).
- Quel jeu de facteurs de prix s'applique, et quand bascule la série « pénurie ».
- Les seuils `X1…X4` : leur calcul (probablement la consommation × un nombre de
  jours, `VorratTage`).
- La famine (§5) et le rôle du trésor (§9), toujours ouverts.

Les constantes scalaires (salaires `Lohn`, solde `Heuer`, loyer d'entrepôt
`Lagermiete`, jours de réserve `VorratTage`, chômage minimal pour bâtir
`NeubauMinAlq`…) sont dans le fichier, mais serrées octet contre octet sans
compte devant. Les nommer demanderait de lire le chargeur dans l'exe.
