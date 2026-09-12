# L'économie de Port Royale 3, relevée dans le jeu

Ce document sert de cahier des charges à `sim/`. Il note ce que PR3 fait
réellement, pas ce qu'on suppose qu'il fait.

**D'où ça sort.** Trois sources, par ordre de fiabilité décroissante :

1. Les textes du jeu (`data_fr.fuk` → `ui/locale/frfr/global.res`, format `L10N`,
   5 546 entrées). Le tutoriel de PR3 explique ses propres règles, chiffres
   compris. Tout ce qui est entre guillemets ci-dessous en vient **mot pour mot**.
2. `PortRoyale3.exe`, pour la table des marchandises et leurs noms internes.
3. Les descriptions de bâtiments, pour les chaînes de production.

Le décodeur du format `L10N` : en-tête `L10N` + version + nombre d'entrées, puis
une table de 12 octets par entrée (offset, longueur, hash), le texte en UTF-16-LE.
**Les offsets sont relatifs à 12**, pas à la fin de l'en-tête — c'est le seul
piège. Le hash sert de clé, il n'y a pas de noms de chaînes en clair.

---

## 1. Les vingt marchandises

Relevées d'un bloc dans `PortRoyale3.exe`, avec leurs noms internes :

| # | Interne | Français | Produit à partir de |
|---|---|---|---|
| 0 | `wood` | Bois | — |
| 1 | `bricks` | Briques | — |
| 2 | `grain` | Blé | — |
| 3 | `hemp` | Chanvre | — |
| 4 | `cloth` | Textile | Coton |
| 5 | `ropes` | Cordes | Chanvre |
| 6 | `tabacco` *(sic)* | Tabac | — |
| 7 | `sugar` | Sucre | — |
| 8 | `tools` | Objets métal | Bois + Métal |
| 9 | `bread` | Pain | Blé + Sucre |
| 10 | `dyestuffs` | Teinture | — |
| 11 | `coffee` | Café | Objets métal (peu) |
| 12 | `fruits` | Fruits | — |
| 13 | `clothes` | Vêtements | Textile + Teinture |
| 14 | `corn` | Maïs | — |
| 15 | `metals` | Métal | Bois |
| 16 | `cotton` | Coton | — |
| 17 | `meat` | Viande | Maïs |
| 18 | `rum` | Rhum | Bois + Sucre |
| 19 | `cocoa` | Cacao | Objets métal (peu) |

Les noms sont sûrs, l'**ordre ne l'est pas** : ils apparaissent dans l'exe en
ordre inverse de cette table, ce qui est le comportement habituel d'un
compilateur pour des littéraux déclarés à la suite. L'ordre restitué ici est donc
l'ordre de déclaration le plus probable, et il est cohérent (matières premières
d'abord). À vérifier si un index précis devient important ; pour la simulation,
il ne l'est pas.

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

## 10. Ce qui n'a pas pu être extrait

Les **constantes chiffrées** ne sont pas dans les fichiers de données. Cherchées
sans succès dans `ini/constdata.dat` (1,4 Mo) et dans l'exe :

- consommation par habitant et par jour, marchandise par marchandise ;
- coût de production de référence de chaque marchandise ;
- valeurs du plafond de prix et de la vitesse de chute ;
- rendement et besoins exacts de chaque manufacture.

`constdata.dat` est un **flux sérialisé**, pas un tableau : les champs n'ont ni
alignement ni étiquette, et aucune table de vingt valeurs cohérentes n'y apparaît.
Un balayage de l'exe à la recherche de tables de vingt valeurs ne rend que du
bruit. Sans symboles de débogage, tout chiffre qu'on en tirerait serait une
devinette présentée comme une mesure.

**La voie fiable pour ces valeurs est le jeu lui-même** : les prix et les stocks
sont affichés à l'écran de commerce de chaque ville, et une partie posée avec un
carnet donne en une heure des valeurs vraies plutôt que supposées. C'est aussi
comme ça que se tranche l'ambiguïté sur la famine (§5) et la question du trésor (§9).
