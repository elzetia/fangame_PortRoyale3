// Cuisson de la carte : rend une fois, en très haute résolution, une carte
// marine peinte à partir des paramètres d'îles de la simulation.
//
// L'idée vient de Port Royale 3, dont la carte est un fond dessiné : la
// jungle, le relief, les hauts-fonds et les bleus sont *dans la texture*.
// Le jeu n'anime par-dessus que des effets (miroitement, ombres de nuages)
// et des icônes. Plutôt que de calculer du terrain 3D à chaque image, on
// peint donc la carte une bonne fois pour toutes.
//
// Tout se joue au pixel : on recalcule le relief exact sous chaque pixel,
// puis on l'ombre et on le colorie. Pas de maillage, donc pas de facettes.

shader_type canvas_item;
render_mode unshaded;

group_uniforms Vue;
// 90 = plongée zénithale, 60 = franchement oblique. Port Royale se situe vers
// 62-68 : on voit le toit des bâtiments *et* leur façade, la face sud des
// montagnes, et les reliefs masquent un peu ce qui est derrière eux.
uniform float angle_vue = 65.0;
uniform vec2 vue_centre;       // centre de la zone cuite, en mètres monde (x, z)
uniform vec2 vue_taille;       // étendue du plan de projection, en mètres
// Cuisson par tuiles : sous-rectangle de la vue, en 0..1. Une seule passe
// plein cadre dépasserait le délai de garde du pilote graphique.
uniform vec2 tuile_min = vec2(0.0);
uniform vec2 tuile_taille = vec2(1.0);

const float Y_MAX = 400.0;     // plafond du terrain, pour amorcer le rayon
const float Y_MIN = -210.0;

// LE TERRAIN N'EST PLUS PROCÉDURAL. Il l'a été : sept îles décrites par des
// harmoniques, dont ce shader reconstruisait la côte. C'est désormais la carte
// de Port Royale 3, et une côte réelle ne se décrit pas par quatre sinus.
//
// On lui donne donc un CHAMP DE DISTANCE, fabriqué par `outils/champ_cote.py`
// depuis le masque terre/mer du jeu : rouge = distance à la côte vers
// l'intérieur, vert = vers le large, bleu = le relief de PR3, qui ne sert qu'à
// dire où sont les montagnes. La côte peinte est donc, par construction, la
// côte que le navire longe — un décor cuit d'après une autre source aurait
// laissé le sloop traverser la plage.
uniform sampler2D champ_cote : filter_linear, repeat_disable, source_color;
uniform vec2 champ_origine;            // coin nord-ouest, en unités de monde
uniform vec2 champ_taille;             // étendue couverte, en unités de monde
uniform float champ_unite = 12.0;      // unités de monde par case du champ
uniform float sommet = 260.0;          // altitude des plus hautes terres
uniform float portee_mont = 620.0;     // distance à la côte pour l'atteindre
uniform float largeur_plage = 45.0;    // frange côtière plate
uniform float largeur_lagon = 150.0;   // plateau avant le tombant

// LES BIOMES. Le bassin caraïbe n'est pas une seule jungle : la côte du
// Tamaulipas est un matorral épineux jaune adossé aux plateaux de la Sierra
// Madre, la Floride et la Louisiane sont des pinèdes de plaine, le Yucatán une
// forêt sèche sur calcaire plat, et Coro, au Venezuela, un vrai désert de dunes.
// `outils/champ_cote.py` pose ces foyers d'après la géographie réelle.
//   rouge = aridité, vert = part de conifères.
uniform sampler2D champ_biome : filter_linear, repeat_disable, source_color;

// LE RELIEF DE PORT ROYALE 3, à part et deux fois plus fin que le champ de
// distance. Celui-ci est une donnée lisse qui ne gagne rien à être détaillée ;
// le relief, lui, est ce qu'on sculpte — et une valeur par case de masque étale
// chaque flanc de montagne sur cinq pixels de carte cuite. Il est aussi décodé
// entièrement, et non par bloc DXT : en ne gardant qu'une couleur par bloc de
// quatre pixels de côté, on jetait les trois quarts de la finesse du terrain.
uniform sampler2D champ_relief : filter_linear, repeat_disable, source_color;

// La palette sèche, en regard de la palette humide. Les mêmes tranches
// d'altitude, d'autres couleurs : on calcule les deux et on fond de l'une vers
// l'autre selon l'aridité, plutôt que de bricoler des seuils par région.
uniform vec3 steppe_claire : source_color = vec3(0.800, 0.735, 0.470);
uniform vec3 steppe       : source_color = vec3(0.660, 0.600, 0.350);
uniform vec3 matorral     : source_color = vec3(0.480, 0.452, 0.278);
uniform vec3 roche_seche  : source_color = vec3(0.588, 0.500, 0.360);

// L'ARRIÈRE-PAYS. Le masque de Port Royale 3 marque comme terre de vastes
// zones que sa carte peinte, elle, montre en pleine mer : c'est sa CLÔTURE de
// navigation, pas un continent — il barre simplement le large. Peintes comme
// de la jungle, ces zones donnaient un immense gazon vert au sud-ouest, qui
// n'est ni beau ni vrai. Au-delà de quelques dizaines de cases de la côte, on
// quitte donc la carte utile : la couleur s'assombrit et la végétation cesse
// de se semer. L'œil suit la côte, qui est le seul endroit où l'on joue.
uniform float arriere_debut = 460.0;   // unités de monde depuis la côte
uniform float arriere_fin   = 1150.0;
uniform vec3 arriere_teinte : source_color = vec3(0.106, 0.141, 0.110);

group_uniforms Relief;
uniform float relief_force = 0.40;      // part du sommet laissée aux crêtes
uniform float relief_echelle = 0.0062;
uniform float deformation = 0.85;       // gauchissement du domaine des crêtes
uniform float ombrage_force = 0.70;
uniform vec3 direction_lumiere = vec3(-0.55, 0.68, -0.48);

group_uniforms Mer;
// Palette de la bible de DA. L'ocean n'est pas un degrade mais une suite de
// PALIERS : c'est l'anneau turquoise autour des iles qui donne toute sa
// lisibilite a leur silhouette.
uniform vec3 mer_abysse   : source_color = vec3(0.024, 0.251, 0.439);  // #064070
uniform vec3 mer_large    : source_color = vec3(0.027, 0.353, 0.522);  // #075A85
uniform vec3 mer_claire   : source_color = vec3(0.027, 0.561, 0.627);  // #078FA0
uniform vec3 mer_turquoise: source_color = vec3(0.188, 0.769, 0.753);  // #30C4C0
uniform vec3 mer_ecume    : source_color = vec3(0.659, 0.878, 0.812);  // #A8E0CF
uniform float palier_net = 0.55;   // 0 = degrade continu, 1 = paliers francs
uniform vec2 houle_direction = vec2(0.86, 0.51);   // sens de propagation
uniform float houle_frequence = 0.042;             // radians par metre
uniform float houle_force = 0.09;

group_uniforms Vegetation;
uniform float taille_arbre = 42.0;      // espacement moyen des palmiers, en mètres
uniform float hauteur_palmier = 25.0;   // hauteur du stipe, en mètres
uniform float taille_sous_bois = 7.0;   // grain du moucheté de végétation
uniform float frondes = 6.0;            // nombre de palmes de la couronne
uniform float densite_palmiers = 0.16;
// 1 = ne sort pas la couleur mais la densite de vegetation, que le semeur de
// palmiers relit pour savoir ou planter. On la produit ici plutot que de la
// recalculer cote moteur : elle correspond ainsi exactement au terrain dessine.
uniform int mode_densite = 0;
// Volontairement hors d'échelle : à 7 m, un arbre ne fait que 3 px à l'écran
// quand on regarde tout l'archipel, et la canopée disparaît. PR3 fait pareil.

group_uniforms Finition;
uniform float saturation = 1.14;
uniform float contraste = 1.10;

group_uniforms Terre;
uniform vec3 sable        : source_color = vec3(0.906, 0.827, 0.553);  // #E7D38D
uniform vec3 sable_clair  : source_color = vec3(0.945, 0.878, 0.647);  // #F1E0A5
uniform vec3 herbe        : source_color = vec3(0.545, 0.686, 0.286);  // #8BAF49
uniform vec3 jungle_claire: source_color = vec3(0.451, 0.612, 0.267);  // #739C44
uniform vec3 jungle       : source_color = vec3(0.310, 0.494, 0.224);  // #4F7E39
uniform vec3 jungle_haute : source_color = vec3(0.220, 0.380, 0.196);  // #386132
uniform vec3 roche        : source_color = vec3(0.467, 0.459, 0.404);  // #777567
uniform vec3 roche_sombre : source_color = vec3(0.282, 0.314, 0.290);  // #48504A

group_uniforms Contours;
// Les contours separent les masses. Sans eux, le rendu reste « photo adoucie »
// au lieu de « carte peinte ». Brun-olive tres sombre, jamais du noir pur :
// le noir donne tout de suite un aspect dessin anime enfantin.
uniform vec3 contour_teinte : source_color = vec3(0.098, 0.129, 0.086);
uniform float contour_cote = 0.20;
uniform float contour_relief = 0.35;
uniform float largeur_contour = 2.6;   // en metres, epaisseur constante a l'ecran
uniform float ombrage_plat = 0.70;     // 0 = degrade continu, 1 = trois tons

const float MARGE_SOUS_MARINE = 0.36;
const float PROFONDEUR_MAX = 190.0;
const float ALTITUDE_COTE = 1.2;


// --- bruit -------------------------------------------------------------------
// Hachage robuste (Dave Hoskins). Le hachage naïf `fract(p * 123.34)` perd ses
// décimales dès que les coordonnées dépassent quelques centaines : le bruit se
// met alors à paver l'image de rectangles. Sur une carte de plusieurs milliers
// de mètres, c'est rédhibitoire.
float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i),                 hash21(i + vec2(1.0, 0.0)), f.x),
	           mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p, int octaves) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 6; i++) {
		if (i >= octaves) break;
		v += amp * bruit(p);
		p *= 2.07;
		amp *= 0.5;
	}
	return v;
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.x, p.y, p.x) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

// Voronoï : renvoie (distance à la couronne la plus proche, vecteur vers elle).
// C'est la brique du « tree-clump » : chaque cellule devient un arbre.
vec3 voronoi(vec2 p) {
	vec2 n = floor(p);
	vec2 f = p - n;
	float md = 8.0;
	vec2 mr = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash22(n + g);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < md) { md = d; mr = r; }
		}
	}
	return vec3(sqrt(md), mr);
}

// Bruit « ridged » : les crêtes deviennent des arêtes nettes au lieu de bosses
// molles. C'est ce qui donne des chaînes de montagnes plutôt que des taupinières.
float ridged(vec2 p, int octaves) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 6; i++) {
		if (i >= octaves) break;
		float n = 1.0 - abs(bruit(p) * 2.0 - 1.0);
		v += amp * n * n;
		p *= 2.11;
		amp *= 0.5;
	}
	return v;
}


// --- relief ------------------------------------------------------------------

// Le biome en un point : (aridité, conifères), de zéro à un.
vec2 biome(vec2 p) {
	vec2 uv = clamp((p - champ_origine) / champ_taille, vec2(0.0), vec2(1.0));
	return texture(champ_biome, uv).rg;
}


// Les deux distances à la côte, en unités de monde, et l'amplitude de relief.
// Hors du champ, on est au large : distance infinie vers la terre.
vec3 champ(vec2 p) {
	// Au-dela du champ, on PROLONGE la carte au lieu de basculer en pleine mer :
	// la ou la terre touche le bord du monde — au nord et a l'ouest — la marge de
	// decor se lisait sinon comme une lamelle d'eau, la cote coupee a la regle.
	//
	// Mais on ne la prolonge pas EN REPETANT le bord, ce qui a ete mon premier
	// reflexe : repetee, la derniere colonne connue donne un terrain constant le
	// long de x, et la plongee oblique le lit alors en terrasses horizontales —
	// tout le bord de carte paraissait etire. On s'ENFONCE : la distance a la cote
	// continue de croitre vers l'exterieur, donc le relief continue de varier, et
	// c'est le bruit de cretes qui fait le detail comme partout ailleurs.
	vec2 brut = (p - champ_origine) / champ_taille;
	vec2 uv = clamp(brut, vec2(0.0), vec2(1.0));
	vec3 c = texture(champ_cote, uv).rgb;
	c.b = texture(champ_relief, uv).r;
	float d_terre = c.r * 255.0 * champ_unite;
	float d_mer = c.g * 255.0 * champ_unite;
	float dehors = length((brut - uv) * champ_taille);
	if (dehors > 0.0) {
		if (d_terre > d_mer) { d_terre += dehors; } else { d_mer += dehors; }
		// Et le relief se fond vers une valeur moyenne : garde tel quel, il etire
		// les montagnes de la derniere colonne sur toute la largeur de la marge.
		c.b = mix(c.b, 0.40, clamp(dehors / 90.0, 0.0, 1.0));
	}
	return vec3(d_terre, d_mer, c.b);
}


// Altitude du terrain sous un point du monde. Négatif = fond marin.
//
// La forme est celle d'avant, transposée : là où l'on lisait un rayon normalisé
// (0 au centre de l'île, 1 à la côte), on lit maintenant une distance à la côte.
// D'où le même vocabulaire — une frange de plage aplatie, des crêtes qui
// s'estompent vers le rivage pour ne pas déformer le trait, un plateau
// sous-marin puis un tombant.
float hauteur(vec2 p) {
	vec3 ch = champ(p);
	float d_terre = ch.x;
	float d_mer = ch.y;

	if (d_terre > d_mer) {
		// La frange côtière est plate : c'est ce qui pose une vraie bande de sable.
		float plage = 1.0 - smoothstep(0.0, largeur_plage, d_terre);
		// Le PLAFOND d'altitude vient de Port Royale 3, pas de la distance à la
		// côte. Sans lui, tout ce qui est loin d'un rivage monte au maximum : le
		// Yucatan et la Floride, qui sont plats comme la main, se retrouvaient
		// gris rocheux jusqu'à l'horizon, et l'intérieur du continent n'était
		// plus qu'une croûte. La distance fait la MONTÉE, le relief de PR3 fait
		// la HAUTEUR qu'elle atteint.
		float plafond = sommet * mix(0.11, 1.0, ch.z);
		float aridite = biome(p).x;
		float t = clamp(d_terre / portee_mont, 0.0, 1.0);
		// EN PAYS ARIDE, LE RELIEF MONTE EN PLATEAUX. Un `pow` fait une pente
		// qui s'adoucit vers le haut — le profil d'une montagne humide,
		// ravinée par l'eau. Une mesa fait l'inverse : plaine, escarpement
		// franc, sommet plat. Le `smoothstep` donne exactement ce profil, et
		// c'est ce qui dessine la Sierra Madre derrière Tampico.
		float profil = mix(pow(t, 1.20), smoothstep(0.16, 0.50, t), aridite);
		float base = mix(ALTITUDE_COTE, plafond, profil);

		// Le relief fin de PR3 n'a PAS besoin d'un terme à lui : il passe déjà
		// par `plafond`, et c'est suffisant dès lors qu'il est lu à sa vraie
		// finesse — le plafond varie alors de crête en crête au lieu de varier
		// de région en région, et le relief se dessine tout seul.
		// J'avais ajouté un terme de sculpture par-dessus : il remontait
		// l'altitude de tout le continent, poussait la terre au-dessus de la
		// bande où poussent les palmiers, et la carte s'est retrouvée pelée —
		// deux mille palmiers perdus d'un coup. L'altitude est une échelle
		// PARTAGÉE avec la végétation : on n'y touche pas sans tout déplacer.
		base = mix(base, ALTITUDE_COTE, plage);

		// Crêtes. Le domaine est gauchi avant d'être passé au bruit ridged :
		// c'est ce qui fait serpenter et se ramifier les chaînes, au lieu
		// d'obtenir des rides parallèles régulières.
		vec2 w = p * relief_echelle;
		w += vec2(fbm(w * 0.5, 3), fbm(w * 0.5 + 7.3, 3)) * deformation;
		float crete = ridged(w, 5) - 0.32;
		// Le canal bleu dit où Port Royale 3 met ses montagnes : la Sierra Madre
		// se soulève, le plat pays de Floride reste plat. Le bruit fait le détail,
		// lui fait la géographie.
		// Les crêtes s'effacent sur les plateaux : un sommet plat n'a pas de
		// dentelure, c'est ce qui le distingue d'une chaîne.
		float ampleur = mix(0.34, 1.30, ch.z) * (1.0 - 0.65 * aridite);
		// Les crêtes gardent un PLANCHER, mais MODESTE. Il a été trop haut : la
		// plaine montait alors jusque dans la bande d'altitude qui déclenche la
		// roche nue et le semis de massifs, et le continent se couvrait de
		// montagnes d'un bout à l'autre. Sur la référence, la terre est verte et
		// plate, et un massif est un ACCENT — un ou deux par île. Une plaine
		// ondule à peine ; ce sont les palmiers qui lui donnent sa matière, pas
		// le relief.
		float ampleur_h = max(plafond, sommet * 0.17);
		return base + crete * ampleur_h * relief_force * ampleur * (1.0 - plage)
		       * smoothstep(0.0, portee_mont * 0.30, d_terre);
	}

	// Sous l'eau : plateau puis tombant. L'exposant fait la largeur du lagon —
	// et c'est LUI qui dessine le halo turquoise de la reference. A 1,25 le
	// fond plongeait a vingt metres en deux cases : l'ile n'avait qu'un lisere
	// de craie. A 2,3 le plateau s'etale sur une dizaine de cases avant le
	// tombant, et le bleu clair fait le tour de l'ile comme il doit.
	float u = clamp(d_mer / largeur_lagon, 0.0, 1.0);
	return mix(ALTITUDE_COTE, -PROFONDEUR_MAX, pow(u, 2.30));
}


// --- couleur -----------------------------------------------------------------
// L'eau profonde de PR3 est d'un bleu saturé et *uniforme* ; toute la lecture
// se fait sur le lavis turquoise côtier, qui doit trancher net.
vec3 couleur_mer(float h, vec2 p) {
	float prof = -h;
	// Cinq paliers. `palier_net` durcit chaque transition : a 0 on retrouve un
	// degrade continu, a 1 les bandes deviennent franches comme sur une carte
	// peinte a la main.
	// Seuils resserres : a vingt-cinq metres de fond, la mer est deja pleine
	// et opaque. C'est ce qui fait un ocean plutot qu'un bassin.
	float k = mix(1.0, 0.20, palier_net);
	vec3 c = mix(mer_ecume, mer_turquoise, smoothstep(0.3, 0.3 + 2.4 * k, prof));
	c = mix(c, mer_claire, smoothstep(2.8, 2.8 + 4.6 * k, prof));
	c = mix(c, mer_large, smoothstep(8.5, 8.5 + 9.0 * k, prof));
	c = mix(c, mer_abysse, smoothstep(19.0, 19.0 + 17.0 * k, prof));

	// Le fond de sable transparait sous les petits fonds, et s'efface avec la
	// profondeur. C'est CE degrade qui fait lire une plage qui descend dans
	// l'eau ; un lisere blanc pose sur le trait de rivage ne fait qu'un trait
	// de craie autour de l'ile.
	float fond = 1.0 - smoothstep(0.0, 2.4, prof);
	fond = fond * fond;
	// Le sable du fond est vu A TRAVERS l'eau : il en garde la teinte.
	vec3 sable_noye = mix(sable * 0.92, mer_turquoise, 0.50);
	c = mix(c, sable_noye, fond * 0.55);

	// Ondulation du trait de deferlante : sans elle, la limite du haut-fond
	// est un cercle parfait, ce qui trahit la geometrie analytique de l'ile.
	// Le fond du lagon n'est pas un aplat : bancs de sable, herbiers et taches
	// de corail le marbrent. Sans cette rugosite, le haut-fond se lit comme un
	// degrade imprime, et sa limite avec le sable devient un trait net.
	float marbrure = fbm(p * 0.085, 4);
	float tavelure = fbm(p * 0.31, 3);
	float lagon = 1.0 - smoothstep(0.8, 6.5, prof);
	vec3 fonds = mix(sable * 0.92, mer_claire * 0.74, smoothstep(0.34, 0.70, marbrure));
	c = mix(c, fonds, lagon * (0.10 + 0.24 * tavelure));

	float ride = fbm(p * 0.028, 3);
	c = mix(c, mer_ecume, (1.0 - smoothstep(0.0, 1.8, prof)) * (0.12 + 0.18 * ride));

	float au_large = smoothstep(3.0, 20.0, prof);

	// Grain de fond : de fines rides etirees est-ouest, tres faible amplitude.
	float houle = fbm(vec2(p.x * 0.05, p.y * 0.19), 3)
	            + 0.5 * fbm(vec2(p.x * 0.13, p.y * 0.41), 2);
	c *= 0.962 + 0.055 * houle * au_large;

	// PAS DE CRETES PEINTES ICI. Il y en a eu — une houle longue, orientee,
	// gauchie par du bruit. Elles se justifiaient tant que la nappe animee
	// reprenait la meme phase : on voyait alors les memes cretes, mais qui
	// avancaient. Depuis que la nappe est une houle de Gerstner, elle a sa
	// propre longueur d'onde, et les deux motifs se battaient : une mer
	// moiree, ou l'oeil suit le battement des deux periodes au lieu des vagues.
	// La mer cuite ne porte donc plus que son grain de fond et le marbrage du
	// lagon ; tout le mouvement vient de la nappe.
	c = mix(c, c, 0.0);

	// Clapot : une seconde serie, plus courte et de biais, qui casse la
	// regularite de la premiere.
	float phase2 = dot(p, vec2(-0.42, 0.91)) * houle_frequence * 2.7
	             + fbm(p * 0.030, 3) * 9.5;
	float clapot = pow(clamp(sin(phase2), 0.0, 1.0), 11.0);
	c = mix(c, mix(c, mer_ecume, 0.38), clapot * houle_force * 0.45 * au_large);
	return c;
}

// Palmiers en plongée oblique.
//
// À 58°, un arbre n'est pas une tache vue de dessus : son stipe se projette
// vers le sud (le bas de l'image) et sa couronne se retrouve décalée vers le
// nord d'exactement hauteur/tan(angle). On dessine donc chaque palmier comme
// un objet debout — couronne en éventail, stipe dessous, ombre portée — au
// lieu d'un simple amas de feuillage.
//
// Renvoie (couronne, stipe, ombre au sol, éclairement de la couronne).
vec4 palmiers(vec2 p, float densite) {
	float cell = max(taille_arbre, 1.0);
	float dz = hauteur_palmier / max(tan(radians(angle_vue)), 0.1);
	vec2 lum2 = normalize(vec2(direction_lumiere.x, direction_lumiere.z));

	float couronne = 0.0;
	float stipe = 0.0;
	float ombre = 0.0;
	float eclat = 0.0;

	vec2 base = floor(p / cell);
	// On balaie aussi les cellules au nord : leur stipe descend jusqu'ici.
	for (int j = -2; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cellule = base + vec2(float(i), float(j));
			vec2 h1 = hash22(cellule);
			vec2 h2 = hash22(cellule + 37.7);
			if (h2.x > densite) continue;          // palmeraie clairsemée

			vec2 A = (cellule + h1) * cell;        // sommet du palmier, à l'écran
			vec2 r = p - A;
			float R = cell * (0.24 + 0.13 * h2.y);

			// Couronne : le rayon ondule avec l'angle, ce qui découpe les palmes
			float lobe = 0.58 + 0.42 * abs(cos(frondes * atan(r.y, r.x) + h1.x * 6.2832));
			float c = 1.0 - smoothstep(R * lobe * 0.5, R * lobe, length(r));
			if (c > couronne) {
				couronne = c;
				eclat = dot(normalize(r + vec2(1e-5)), -lum2);
			}

			// Stipe : il descend vers le sud, légèrement courbé
			float t = clamp(r.y / max(dz, 0.01), 0.0, 1.0);
			float courbe = (h2.y - 0.5) * cell * 0.22 * t;
			float largeur = cell * 0.032;
			stipe = max(stipe, (1.0 - smoothstep(largeur * 0.55, largeur, abs(r.x - courbe)))
			                 * step(0.0, r.y)
			                 * (1.0 - smoothstep(dz * 0.8, dz, r.y)));

			// Ombre au sol, du côté opposé au soleil, écrasée par la perspective
			vec2 ro = (p - (A + vec2(0.0, dz) - lum2 * hauteur_palmier * 0.8)) * vec2(1.0, 1.7);
			ombre = max(ombre, 1.0 - smoothstep(R * 0.4, R * 0.95, length(ro)));
		}
	}
	return vec4(couronne, stipe, clamp(ombre - couronne - stipe, 0.0, 1.0), eclat);
}

vec3 couleur_terre(float h, vec2 p, float pente) {
	vec2 bio = biome(p);
	float aridite = bio.x;

	vec3 c = mix(sable, mer_turquoise, 0.16) * 0.90;   // sable mouille
	c = mix(c, sable, smoothstep(0.0, 1.6, h));
	c = mix(c, sable_clair, smoothstep(1.2, 3.4, h));  // sable sec, plus pale

	// Deux montées d'altitude, l'une humide et l'autre sèche, fondues l'une
	// dans l'autre. Le littoral reste le même partout : du sable est du sable.
	vec3 vert = c;
	vert = mix(vert, herbe, smoothstep(3.0, 9.0, h));
	vert = mix(vert, jungle_claire, smoothstep(7.0, 18.0, h));
	vert = mix(vert, jungle, smoothstep(16.0, 40.0, h));
	vert = mix(vert, jungle_haute, smoothstep(38.0, 95.0, h));

	vec3 sec = c;
	sec = mix(sec, steppe_claire, smoothstep(2.0, 8.0, h));
	sec = mix(sec, steppe, smoothstep(7.0, 26.0, h));
	sec = mix(sec, matorral, smoothstep(24.0, 72.0, h));

	c = mix(vert, sec, aridite);

	// La roche perce là où c'est raide, quelle que soit l'altitude — c'est ce
	// qui distingue une chaîne de montagnes d'une colline verte pointue.
	// Le terme d'altitude a ete releve avec le relief : a 105 unites, toute la
	// plaine passait au gris. La roche est une affaire de PENTE avant tout — et
	// d'une pente FRANCHE. A 0,90 elle dessinait encore une echine grise
	// continue sur toute la longueur de Cuba ; sur la reference, un massif est
	// un piton a silhouette nette, et c'est le sprite qui le porte, pas la
	// teinte du terrain.
	float rocheux = clamp(smoothstep(1.30, 2.05, pente)
	                    + smoothstep(190.0, 265.0, h), 0.0, 1.0);
	// La roche d'un pays sec est ocre, pas grise : c'est du grès et du calcaire,
	// pas du basalte sous la pluie.
	vec3 pierre = mix(mix(roche, roche_sombre, smoothstep(70.0, 160.0, h)),
				  roche_seche, aridite);
	c = mix(c, pierre, rocheux);

	// L'arrière-pays s'efface : au-delà de la bande côtière, la carte n'a plus
	// rien à raconter, et le vert uni qu'on y peignait sautait aux yeux.
	float lointain = smoothstep(arriere_debut, arriere_fin, champ(p).x);
	c = mix(c, arriere_teinte, lointain * 0.90);

	// La forêt couvre les basses et moyennes altitudes, ni la plage ni les cimes,
	// et lâche prise sur les à-pics.
	// Deux couches, comme dans PR3 : un moucheté fin qui donne sa matière à la
	// masse végétale, et par-dessus des palmiers individuels, plus gros et
	// plus rares. Le moucheté seul fait un tapis ; les palmiers seuls font un
	// semis clairsemé sur du vide.
	float dens_verte = smoothstep(1.5, 5.0, h)
	                 * (1.0 - smoothstep(105.0, 165.0, h))
	                 * (1.0 - rocheux * 0.9) * (1.0 - lointain)
	                 * (1.0 - 0.85 * aridite);
	if (dens_verte > 0.001) {
		// Taches de couvert, a deux echelles, SANS relief propre.
		// La version precedente eclairait chaque cellule de Voronoi comme une
		// demi-sphere : vu de loin, le sol se lisait comme un tapis de boules.
		// Ce sont les arbres semes par-dessus qui doivent porter le volume ;
		// le sol, lui, n'est qu'un lavis.
		float tache = fbm(p * 0.042, 4);
		float grain = fbm(p * 0.21, 3);
		float m = clamp((tache - 0.5) * 1.8 + (grain - 0.5) * 0.55, -1.0, 1.0);
		vec3 tapis = mix(herbe, jungle, smoothstep(-0.40, 0.60, m));
		c = mix(c, tapis, 0.44 * dens_verte);
		c *= 1.0 + (grain - 0.5) * 0.09 * dens_verte;
	}

	// Les palmiers tiennent les basses terres et le pourtour des îles.
	float densite = smoothstep(1.5, 6.0, h)
	              * (1.0 - smoothstep(90.0, 160.0, h))
	              * (1.0 - rocheux * 0.7) * (1.0 - lointain)
	              * (1.0 - 0.92 * aridite);   // pas de cocotier au matorral

	vec4 pal = palmiers(p, densite * densite_palmiers);
	c *= 1.0 - pal.z * 0.38;                                  // ombre portee au sol
	c = mix(c, vec3(0.34, 0.24, 0.14), pal.y * 0.75);         // stipe
	// La couronne n'existe visuellement que si elle a son propre modelé :
	// peinte d'un vert proche du fond, elle disparaît et il ne reste que le
	// stipe, qui donne alors des piquets plantés dans le sol.
	vec3 palme = mix(jungle_haute * 0.85, mix(jungle_claire, vec3(0.70, 0.84, 0.44), 0.55),
	                 0.5 + pal.w * 0.5);
	c = mix(c, palme, pal.x * 0.97);                          // couronne
	return c;
}


// Ombre portée : on remonte vers le soleil dans le champ d'altitude. C'est ce
// qui pose vraiment les montagnes dans la vue oblique — sans ombre portée, un
// relief éclairé reste plat.
float ombre_portee(vec3 depart) {
	vec3 vers_soleil = normalize(direction_lumiere);
	float pas = 9.0;
	float ombre = 1.0;
	for (int i = 1; i <= 24; i++) {
		vec3 q = depart + vers_soleil * (float(i) * pas);
		if (q.y > Y_MAX) break;
		float dh = hauteur(q.xz) - q.y;
		if (dh > 0.0) {
			ombre = min(ombre, 1.0 - clamp(dh / 26.0, 0.0, 1.0) * 0.75);
			if (ombre < 0.3) break;
		}
	}
	return ombre;
}


void fragment() {
	vec2 uvg = tuile_min + UV * tuile_taille;

	// --- construction du rayon ------------------------------------------------
	float th = radians(angle_vue);
	vec3 dir = normalize(vec3(0.0, -sin(th), -cos(th)));
	vec3 droite = vec3(1.0, 0.0, 0.0);
	vec3 haut = normalize(cross(droite, dir));   // « haut » à l'écran

	vec3 centre = vec3(vue_centre.x, 0.0, vue_centre.y);
	vec3 origine = centre
		+ droite * ((uvg.x - 0.5) * vue_taille.x)
		+ haut   * ((0.5 - uvg.y) * vue_taille.y);

	// Où le rayon perce le niveau de la mer : sert au raccourci « plein océan »
	vec2 p_mer = (origine + dir * ((0.0 - origine.y) / dir.y)).xz;

	vec3 ch_mer = champ(p_mer);
	bool pres_terre = ch_mer.x > 0.0 || ch_mer.y < largeur_lagon * 2.5;

	vec2 p;
	vec3 impact;
	if (!pres_terre) {
		// Loin de toute terre, le fond est plat : inutile de marcher.
		p = p_mer;
		impact = vec3(p_mer.x, -PROFONDEUR_MAX, p_mer.y);
	} else {
		float t = (Y_MAX - origine.y) / dir.y;
		float t_fin = (Y_MIN - origine.y) / dir.y;
		float pas = (t_fin - t) / 128.0;
		float t_prec = t;
		for (int i = 0; i < 128; i++) {
			vec3 q = origine + dir * t;
			if (q.y < hauteur(q.xz)) break;
			t_prec = t;
			t += pas;
		}
		// Dichotomie : sans elle, la silhouette des côtes serait en escalier
		for (int i = 0; i < 10; i++) {
			float tm = (t_prec + t) * 0.5;
			vec3 q = origine + dir * tm;
			if (q.y < hauteur(q.xz)) t = tm; else t_prec = tm;
		}
		impact = origine + dir * t;
		p = impact.xz;
	}

	float h_reel = hauteur(p);
	float dentelle = (fbm(p * 0.085, 4) - 0.5) * 2.6;
	float h = h_reel + dentelle * smoothstep(7.0, 0.0, abs(h_reel));

	// --- ombrage du relief ----------------------------------------------------
	// Calculé par différences finies sur le vrai champ d'altitude : le relief
	// est éclairé pour de bon, pas simulé par un dégradé.
	float e = 5.0;
	float hx = hauteur(p + vec2(e, 0.0)) - hauteur(p - vec2(e, 0.0));
	float hz = hauteur(p + vec2(0.0, e)) - hauteur(p - vec2(0.0, e));
	vec3 normale = normalize(vec3(-hx, 2.0 * e, -hz));
	float lum = clamp(dot(normale, normalize(direction_lumiere)), 0.0, 1.0);
	float pente = length(vec2(hx, hz)) / (2.0 * e);

	// Ombrage semi-plat : trois tons plutot qu'un degrade continu. C'est la
	// difference entre « rendu 3D » et « illustration peinte ».
	float paliers = smoothstep(0.24, 0.34, lum) * 0.5 + smoothstep(0.52, 0.66, lum) * 0.5;
	float lum_p = mix(lum, paliers, ombrage_plat);

	vec3 couleur;
	if (h > 0.0) {
		couleur = couleur_terre(h, p, pente);
		// L'ombrage ne s'applique franchement qu'à la terre
		couleur *= mix(1.0 - ombrage_force * 0.45, 1.0 + ombrage_force * 0.26, lum_p);
		couleur *= mix(1.0, ombre_portee(vec3(p.x, h + 1.5, p.y)), 0.8);
	} else {
		couleur = couleur_mer(h, p);
		// Une eau opaque ne montre pas le modele de son fond : on ne garde de
		// l'ombrage qu'un souffle, sinon les courbes de niveau reapparaissent
		// et le plateau redevient un fond de bassin.
		couleur *= mix(0.995, 1.005, lum_p);
		// L'ombre de l'ile, elle, se pose bien sur la mer.
		if (-h < 70.0) {
			couleur *= mix(1.0, ombre_portee(vec3(p.x, 0.4, p.y)), 0.42);
		}
	}

	// --- ressac ---------------------------------------------------------------
	// Le blanc ne marque plus que le tout dernier metre, et il est decoupe par
	// du bruit : une ecume qui mord la plage, pas un contour au blanc d'Espagne.
	float bruit_cote = (fbm(p * 0.06, 3) - 0.5) * 2.4;
	float bande = 1.0 - smoothstep(0.0, 1.5, abs(h + 0.2 + bruit_cote * 0.55));
	couleur = mix(couleur, vec3(0.97, 0.99, 0.98), bande * 0.55);

	// --- contours -------------------------------------------------------------
	// Distance a la ligne de rivage, NORMALISEE par la pente : le trait garde
	// ainsi une epaisseur constante a l'ecran, qu'il longe une falaise abrupte
	// ou une plage en pente douce.
	float grad = max(length(vec2(hx, hz)) / (2.0 * e), 0.0001);
	float trait = 1.0 - smoothstep(0.0, largeur_contour, abs(h) / grad);
	couleur = mix(couleur, contour_teinte, trait * contour_cote);

	// Second contour, la ou la roche perce la vegetation
	if (h > 0.0) {
			float roc = clamp(smoothstep(1.30, 2.05, pente)
		                + smoothstep(190.0, 265.0, h), 0.0, 1.0);
		float bord = pow(clamp(1.0 - abs(roc - 0.5) * 2.0, 0.0, 1.0), 5.0);
		couleur = mix(couleur, contour_teinte, bord * contour_relief);
	}

	// --- finition « pré-rendu » ----------------------------------------------
	// Net, saturé, un rien brillant : le style vise la maquette 3D propre,
	// pas la carte peinte à la main.
	float gris = dot(couleur, vec3(0.299, 0.587, 0.114));
	couleur = mix(vec3(gris), couleur, saturation);
	couleur = clamp((couleur - 0.5) * contraste + 0.5, vec3(0.0), vec3(1.0));

	if (mode_densite == 1) {
		// Trois masques d'un coup, un par canal : ou semer les palmiers, les
		// amas de jungle et les massifs rocheux. Les produire ici plutot que de
		// les recalculer cote moteur garantit qu'ils collent au terrain dessine.
			float roc = clamp(smoothstep(1.30, 2.05, pente)
		                + smoothstep(190.0, 265.0, h), 0.0, 1.0);
		// Rien ne se sème dans l'arrière-pays : ni palmier, ni bosquet, ni massif.
		float sur_terre = step(0.5, h)
		                * (1.0 - smoothstep(arriere_debut, arriere_fin, champ(p).x));

		// Palmiers : partout sauf la roche nue. Ils descendent jusque dans le
		// sable — sur la reference, la cocoteraie borde vraiment la plage — et
		// remontent jusqu'au pied des massifs.
		float d_palm = smoothstep(0.6, 2.4, h)
		             * (1.0 - smoothstep(70.0, 130.0, h))
		             * (1.0 - roc) * sur_terre;
		// Bosquets de feuillus : quelques taches sombres dans les terres, pour
		// rompre la cocoteraie. Rares, sinon ils referment la canopee.
		float d_jungle = smoothstep(12.0, 30.0, h)
		               * (1.0 - smoothstep(70.0, 120.0, h))
		               * (1.0 - roc * 0.8) * sur_terre;
		// Massifs : haut ET raide. Sur la reference ils forment un ou deux
		// pitons compacts par ile, pas une chaine qui recouvre tout. Le seuil a
		// ete monte de 42 a 120 : a l'ancien, six cents massifs se semaient sur
		// la carte et la terre disparaissait dessous.
		// Des ESCARPEMENTS, pas des sommets. Le seuil était réglé pour ne garder
		// qu'un ou deux pitons par île, parce qu'ils étaient gros ; réduits de
		// moitié, ils redeviennent ce qu'ils sont sur la référence — des cailloux
		// de relief qui ponctuent une côte, et qu'on peut semer bien plus bas et
		// sur des pentes bien plus douces.
		float d_mont = smoothstep(48.0, 120.0, h)
		             * smoothstep(0.20, 0.62, pente) * sur_terre;

		COLOR = vec4(d_palm, d_jungle, clamp(d_mont, 0.0, 1.0), 1.0);
	} else if (mode_densite == 2) {
		float prof = -h;
		// Rouge : coraux et herbiers, le tapis du lagon, entre le sable et le
		// tombant. Ils appartiennent au haut-fond de l'ile.
		float d_corail = smoothstep(3.0, 6.5, prof) * (1.0 - smoothstep(13.0, 28.0, prof));

		// Bleu : ecueils. Ils portent LEUR PROPRE haut-fond deja peint, donc
		// ils n'ont rien a faire au milieu du lagon d'une ile — ils y
		// poseraient un second haut-fond par-dessus le premier. Mais ils n'ont
		// rien a faire non plus en pleine mer : un caillou isole a mille
		// metres de toute terre ne raconte rien. Leur place est juste au-dela
		// du tombant, en vue de la cote.
		// Le rayon normalisé d'autrefois — 1,0 sur la côte — se lit maintenant
		// sur la distance au large : une largeur de lagon vaut un rayon.
		float s_min = 1.0 + champ(p).y / largeur_lagon;
		// Le plateau etant desormais etroit, c'est la distance a la cote qui
		// borne seule la zone : passe 1,7 rayon on est en pleine mer, quelle
		// que soit la profondeur qu'on y lit.
		float d_ecueil = smoothstep(1.08, 1.28, s_min)
		               * (1.0 - smoothstep(1.62, 1.95, s_min))
		               * smoothstep(3.0, 10.0, prof);

		// Vert : masque de terre, relu par le semeur pour verifier que
		// l'empreinte d'un sprite ne deborde pas dans la mer.
		COLOR = vec4(d_corail, step(0.2, h), d_ecueil, 1.0);
	} else if (mode_densite == 5) {
		// Temoin : le biome tel que le shader le lit.
		COLOR = vec4(biome(p), 0.0, 1.0);
	} else if (mode_densite == 4) {
		// Les SAPINS des denivelees. Ils tiennent la tranche d'altitude qui est
		// au-dessus de la cocoteraie et au-dessous de la roche nue : sur les
		// massifs, c'est exactement la ou une foret de coniferes pousse. En
		// dessous il fait trop chaud, au-dessus il n'y a plus de terre.
		float roc = clamp(smoothstep(1.30, 2.05, pente)
		                + smoothstep(190.0, 265.0, h), 0.0, 1.0);
		float sur_terre = step(0.5, h)
		                * (1.0 - smoothstep(arriere_debut, arriere_fin, champ(p).x));
		float d_sapin = smoothstep(58.0, 118.0, h)
		              * (1.0 - roc * 0.85)
		              * (0.45 + 0.55 * smoothstep(0.18, 0.70, pente)) * sur_terre;
		COLOR = vec4(clamp(d_sapin, 0.0, 1.0), 0.0, 0.0, 1.0);
	} else if (mode_densite == 3) {
		// Fiche de mer, relue en jeu par la nappe animee : ou est l'eau, et
		// quelle profondeur. Elle est cuite ici pour coller au pixel pres au
		// trait de rivage peint — y compris ses dentelures, que le bruit
		// ajoute et qu'aucun calcul cote moteur ne saurait retrouver.
		COLOR = vec4(1.0 - step(0.0, h), clamp(-h / 60.0, 0.0, 1.0), 0.0, 1.0);
		} else {
		COLOR = vec4(couleur, 1.0);
	}
}
