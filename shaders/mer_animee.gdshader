// La mer qui bouge, posée sur la carte cuite.
//
// La carte est peinte une fois pour toutes : ses vagues sont figées dans la
// texture. Cette nappe passe par-dessus et ne fait qu'AJOUTER du mouvement —
// crêtes qui avancent, miroitement, ressac qui respire contre la plage.
// C'est ainsi que procède Port Royale 3 : un fond dessiné, et quelques
// couches animées bon marché au-dessus.
//
// Elle ne sait rien de la géographie : elle lit la fiche de mer cuite en même
// temps que la carte (rouge = eau, vert = profondeur). Le trait de rivage y
// est déjà dentelé par le bruit de la cuisson, donc le ressac épouse la côte
// peinte au pixel près, ce qu'aucun recalcul côté moteur ne saurait faire.

shader_type canvas_item;
render_mode unshaded;

uniform vec2 taille_monde = vec2(3600.0, 2700.0);  // étendue de la carte, en unités
uniform float vitesse = 1.0;
uniform float force = 1.0;
uniform vec3 teinte_crete : source_color = vec3(0.78, 0.94, 0.95);
uniform vec3 lumiere = vec3(-0.55, 0.68, -0.48);   // même soleil qu'à la cuisson

// Le zoom de la caméra, poussé par le jeu à chaque image.
//
// Il ne sert QU'AUX PAILLETTES, et pour une raison précise : une paillette a la
// taille d'un éclat de soleil sur l'eau, pas celle d'un morceau de mer. Fixée
// en unités de monde, elle fait vingt pixels à l'écran quand on est près et un
// cinquième de pixel quand on a tout dézoomé — le filtrage l'efface alors
// complètement, et l'océan devient un aplat mort au moment même où l'on en voit
// le plus. Indexée sur le zoom, elle garde sa taille à l'écran quel que soit
// l'éloignement.
uniform float zoom = 1.0;

// L'étendue de référence du motif. Toutes les fréquences ci-dessous sont
// exprimées dans CETTE largeur, et elle ne dépend NI de la taille du monde NI
// de la définition de l'image : les fréquences se lisent sur `UV`, donc sur la
// fraction de carte, et une carte redessinée à une autre définition garde la
// même houle. Laissées en unités de monde elles donneraient un grain et non des
// vagues, la carte faisant seize mille unités de large.
const float LARGEUR_MOTIF = 3600.0;

// LA HOULE DE GERSTNER. Fonction portée d'Ocean3D Lite (MIT, Justin Schroeder),
// ramenée de la 3D à la 2D : on ne déplace pas de sommets sur une nappe plate,
// mais on lit la HAUTEUR et la PENTE du champ de vagues, et c'est l'ombrage qui
// les raconte — crête éclairée, creux sombre, écume là où la vague se cambre.
//
// Ce qu'elle apporte sur le bruit fractal qu'il y avait là : une vraie
// DISPERSION. La célérité vaut sqrt(g/k), donc les longues houles courent plus
// vite que le clapot, et les trains se croisent au lieu de dériver ensemble.
// C'est ce décalage qui fait qu'une mer a l'air d'être en mouvement plutôt que
// d'être une texture qui glisse.
//
// vagues[i] = (direction en degrés, cambrure, longueur d'onde)
const float G_HOULE = 9.8;
// Les longueurs d'onde sont COURTES : une unité de motif vaut environ un pixel
// et demi de carte, donc la plus longue de ces houles fait quatre-vingt-dix
// pixels de crête à crête. Au premier essai je les avais prises trois fois plus
// longues, par fidélité à la houle de la carte peinte — et les lobes du miroir
// s'étalaient alors en nappes laiteuses, plus proches de la brume que de la mer.
// Vue de haut, une mer se lit à sa TEXTURE, pas à ses grandes ondulations.
// SIX trains, et des longueurs d'onde volontairement sans rapport simple entre
// elles : quatre sinusoides aux periodes voisines se resomment vite en un motif
// qu'on reconnait d'un bout a l'autre de la carte — toutes les vagues se
// ressemblent. Des periodes incommensurables ne se referment jamais.
const int N_VAGUES = 6;
// Les directions sont ETALEES sur tout le tour, et non groupees dans un
// quadrant : deux trains voisins font des bandes paralleles qui rayent l'ocean
// d'un bord a l'autre. C'est ce qui est arrive au premier essai, et le miroir a
// bord franc le soulignait au lieu de le casser.
const vec3 VAGUES[6] = {
	vec3(  28.0, 0.40, 61.0),
	vec3( 118.0, 0.30, 37.0),
	vec3( 205.0, 0.26, 23.0),
	vec3( 300.0, 0.20, 14.3),
	vec3(  72.0, 0.15,  9.1),
	vec3( 246.0, 0.11,  5.7)
};

// Renvoie le déplacement (x, hauteur, y) du point de surface.
vec3 gerstner(vec2 xz, float t) {
	vec3 d = vec3(0.0);
	for (int i = 0; i < N_VAGUES; i++) {
		float ang = radians(VAGUES[i].x);
		vec2 dir = vec2(cos(ang), sin(ang));
		float k = 6.28318530718 / VAGUES[i].z;
		float c = sqrt(G_HOULE / k);
		float a = VAGUES[i].y / k;
		float f = k * (dot(dir, xz) - c * t);
		d.x += dir.x * a * cos(f);
		d.y += a * sin(f);
		d.z += dir.y * a * cos(f);
	}
	return d;
}


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
	for (int i = 0; i < 5; i++) {
		if (i >= octaves) break;
		v += amp * bruit(p);
		p *= 2.07;
		amp *= 0.5;
	}
	return v;
}


// --- l'ecume, en CELLULES ----------------------------------------------------
//
// Recette reprise du Stylized Water Shader d'EmacEArt (usage personnel), que
// l'utilisateur donne pour reference. Son idee tient en deux points, et ce sont
// les deux qui manquaient ici :
//
//   1. l'ecume n'est pas du bruit fractal mais des CELLULES de Worley, avec un
//      bord franc. Du bruit donne une brume ; des cellules donnent des paquets
//      d'ecume qu'on distingue les uns des autres ;
//   2. les paillettes ne sont pas un champ continu seuille, mais UN POINT PAR
//      CELLULE, dont seule une fraction s'allume, chacune sur sa propre phase.
//      C'est ce qui fait un scintillement irregulier au lieu d'une grille.

// Distance au point le plus proche d'une grille perturbee.
float worley(vec2 p) {
	vec2 pi = floor(p);
	vec2 pf = fract(p);
	float d = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = vec2(hash21(pi + g), hash21(pi + g + 19.3));
			d = min(d, length(g + o - pf));
		}
	}
	return d;
}

// Un candidat par cellule ; `densite` dit combien s'allument.
float paillettes(vec2 p, float t, float densite, float taille) {
	vec2 pi = floor(p);
	vec2 pf = fract(p);
	float v = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 c = pi + g;
			float h = hash21(c);
			if (h < densite) {
				vec2 o = vec2(hash21(c + 7.1), hash21(c + 31.7));
				// Chaque paillette a sa periode ET sa phase : deux voisines ne
				// clignotent jamais ensemble.
				float bat = 0.5 + 0.5 * sin(t * (1.3 + 2.4 * hash21(c + 3.3)) + h * 62.8);
				float d = length(g + o - pf);
				// UN COEUR ET UN HALO, pas une simple décroissance. Avec une seule
				// rampe, seul le centre passe au-dessus du bleu du fond : la
				// paillette se réduit à trois pixels aux bords durs, et l'on voit
				// des carrés au lieu d'un éclat. Le halo porte la douceur, le
				// coeur porte l'éclat.
				float coeur = 1.0 - smoothstep(0.0, taille * 0.62, d);
				float halo = 1.0 - smoothstep(0.0, taille * 1.80, d);
				v = max(v, (coeur * coeur * 0.66 + halo * halo * 0.52) * bat);
			}
		}
	}
	return v;
}

void fragment() {
	vec2 fiche = texture(TEXTURE, UV).rg;
	float eau = fiche.r;
	float prof = fiche.g * 60.0;          // en mètres, comme à la cuisson

	// Ramené à la largeur de référence : voir LARGEUR_MOTIF.
	vec2 p = UV * vec2(LARGEUR_MOTIF, LARGEUR_MOTIF * taille_monde.y / taille_monde.x);
	float t = TIME * vitesse;
	float au_large = smoothstep(1.5, 9.0, prof);

	// LE DOMAINE EST GAUCHI avant d'être passé aux vagues, exactement comme la
	// cuisson gauchit ses chaînes de montagnes. Sans ça les crêtes courent
	// droit et parallèles d'un bord à l'autre de la carte : un treillis, pas
	// une mer. Gauchies, elles serpentent, se rejoignent, se séparent — et
	// aucune vague ne ressemble tout à fait à sa voisine.
	vec2 pg = p + vec2(fbm(p * 0.0031 + vec2(t * 0.004, 0.0), 3),
				   fbm(p * 0.0031 + vec2(41.7, -t * 0.003), 3)) * 105.0;

	// La surface, et sa normale par différences finies. Les deux tangentes
	// partent du déplacement de Gerstner, donc la normale tient compte du
	// resserrement horizontal des crêtes — c'est lui qui les rend acérées.
	float e = 1.1;
	vec3 d0 = gerstner(pg, t);
	vec3 tx = vec3(e, 0.0, 0.0) + gerstner(pg + vec2(e, 0.0), t) - d0;
	vec3 tz = vec3(0.0, 0.0, e) + gerstner(pg + vec2(0.0, e), t) - d0;
	vec3 n = normalize(cross(tz, tx));

	// Le miroir du soleil sur la pente de l'eau. Le bord est FRANC, pas un lobe
	// qui s'eteint doucement : c'est ce qui distingue une eau stylisee d'une eau
	// photographique, et c'est le parti de toute la carte.
	float mir = max(dot(n, normalize(lumiere)), 0.0);
	float glace = smoothstep(0.62, 0.74, mir) * 0.75 + smoothstep(0.80, 0.93, mir) * 0.25;

	// L'écume ne se pose pas n'importe où sur la crête : elle se pose là où la
	// vague SE CAMBRE, c'est-à-dire là où le déplacement horizontal resserre la
	// surface. Le déterminant des deux tangentes le dit exactement — sous un,
	// la surface se replie sur elle-même, et c'est là que ça déferle.
	float jacobien = tx.x * tz.z - tx.z * tz.x;
	float ecume = smoothstep(0.55, 0.12, jacobien / (e * e));

	// L'ecume des cretes, en paquets : les cellules de Worley derivent avec la
	// houle, et seules celles qui tombent sur une crete cambree se voient.
	float cell = 1.0 - smoothstep(0.30, 0.46,
		worley(pg * 0.055 + vec2(t * 0.055, -t * 0.035)));
	float moutons = ecume * cell;

	// Paillettes : une par cellule, chacune sur sa phase. Deux choses suivent le
	// zoom, et il a fallu les deux :
	//
	//   la MAILLE, pour qu'une paillette garde sa taille à l'écran — fixée en
	//   unités de monde, elle tombe sous le pixel au dézoom et le filtrage
	//   l'efface ;
	//   l'ÉCLAT, parce que la taille ne suffisait pas. À pleine distance il ne
	//   reste qu'un point de vingt pixels à cinq centièmes d'alpha sur du bleu
	//   profond : mathématiquement présent, invisible à l'œil. De loin, une mer
	//   a besoin de plus de contraste, pas de moins — c'est le seul détail qui
	//   dise encore qu'elle est vivante quand tout le reste a fondu.
	float loin = 1.0 - clamp((zoom - 0.25) / 0.75, 0.0, 1.0);

	// En s'éloignant, le grain se RESSERRE au lieu de grossir. Garder la maille
	// strictement constante à l'écran paraissait la bonne idée : elle l'est de
	// près, elle ne l'est pas de loin. À mi-distance la même tache de vingt
	// pixels ne se lit plus comme un éclat sur une mer immense mais comme un
	// paquet posé dessus — d'autant que la densité et l'éclat montaient eux
	// aussi. On garde donc l'éclat qui monte, puisque le contraste manque à
	// distance, mais la tache rétrécit et on en sème à peine plus.
	float maille = 0.085 * clamp(zoom, 0.08, 2.0) * (1.0 + 0.85 * loin);
	// La fraction allumée est BASSE : une paillette est un accident, pas un état
	// de la surface. À un cinquième des cellules on obtenait un semis continu —
	// de la neige sur la mer plutôt que du soleil dessus. À un neuvième, l'oeil
	// accroche les quelques éclats qui bougent au lieu de subir le tapis.
	float paillette = paillettes(p * maille + vec2(t * 0.012, -t * 0.008),
						  t, 0.11 + 0.03 * loin, 0.52);
	float eclat = mix(0.048, 0.105, loin);

	// Ressac : la frange contre la plage enfle et se retire.
	float rive = 1.0 - smoothstep(0.0, 3.2, prof);
	float souffle = 0.5 + 0.5 * sin(t * 0.9 + fbm(p * 0.012, 2) * 8.0);

	// Quatre trains de Gerstner seuls, c'est un motif qui se répète : vu de haut
	// on lit les rangées. Une modulation lente et large casse la régularité —
	// des zones se calment, d'autres moutonnent, et la mer respire.
	float humeur = 0.45 + 0.85 * fbm(p * 0.0055 + vec2(t * 0.006, -t * 0.004), 3);

	// L'ACTION EST COTIERE. Sur la carte de Port Royale 3 comme sur l'image de
	// reference, le large est un bleu calme et presque uni : c'est le plateau et
	// la frange qui moutonnent. Une pleine mer couverte de cretes d'un bord a
	// l'autre se lit comme du papier peint, et fatigue l'oeil d'autant plus que
	// c'est la que le joueur passe son temps.
	// Cretes et miroir sont donc bornes au PLATEAU. Au large il ne reste que les
	// paillettes : un scintillement sans direction, qui ne peut pas rayer
	// l'image. Toute trace de houle qu'on y laissait finissait en diagonales
	// paralleles d'un bord a l'autre de l'ocean.
	float cotier = 1.0 - smoothstep(5.0, 30.0, prof);
	float a = (moutons * 0.34 * cotier * humeur
	         + glace * 0.11 * cotier * humeur
	         + paillette * eclat) * au_large;
	a += rive * (0.05 + 0.13 * souffle);
	COLOR = vec4(teinte_crete, clamp(a, 0.0, 1.0) * force * eau);
}
