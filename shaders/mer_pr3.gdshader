// La mer à la manière de Port Royale 3, posée sur la carte peinte.
//
// Ce que fait PR3, relu dans les tables de constantes de ses shaders DirectX 9
// (voir outils/PR3_TECHNIQUE.md) : une carte de normales qui défile pour les
// vaguelettes, le temps qui anime la houle, un reflet qui dépend de la lumière,
// le miroir du soleil, de l'écume le long des côtes. Sa carte à lui est en 3D ;
// la nôtre est une illustration cuite. On garde donc la recette, et on la joue
// EN SURCOUCHE : aucune couleur de la mer peinte n'est remplacée, chaque couche
// l'éclaircit ou l'assombrit d'un souffle.
//
// Aucune texture n'est lue en dehors de la fiche de mer : les normales sont
// calculées ici, par bruit. Les textures de PR3 sont sous droits, et un bruit
// défilant fait le même travail qu'une carte de normales qui défile.
//
// La fiche de mer est celle de `mer_animee.gdshader` : rouge = eau, vert =
// profondeur (× 60 m).
//
// Trois leçons du premier essai, gardées parce qu'elles valent pour toute eau
// vue d'aussi haut :
//
//   1. LE REFLET DE FRESNEL NE SE VOIT PAS. À 58° de plongée, une facette
//      inclinée de quinze degrés ne change son reflet que de quelques
//      millièmes : le calcul était juste et l'écran restait uni. Ce qui fait lire
//      les vaguelettes d'en haut, c'est la LUMIÈRE — la pente tournée vers le
//      soleil s'éclaire, l'autre s'assombrit.
//   2. LE MIROIR DU SOLEIL NON PLUS : le soleil de la carte est haut à gauche,
//      son reflet tombe hors de l'écran. Les éclats viennent donc de paillettes
//      semées, comme dans la nappe d'origine.
//   3. UNE ÉCUME TIRÉE DES COURBES DE PROFONDEUR DESSINE DES COURBES DE NIVEAU :
//      des tirets blancs réguliers autour de chaque rocher, une carte
//      topographique plutôt qu'un ressac. Elle ne suit plus que le rivage, et un
//      bruit large la déchire.

shader_type canvas_item;
render_mode unshaded;

uniform vec2 taille_monde = vec2(3600.0, 2700.0);
uniform float zoom = 1.0;
uniform float vitesse = 1.0;
uniform float force = 1.0;

uniform vec3 couleur_ciel : source_color = vec3(0.80, 0.94, 0.98);
uniform vec3 couleur_creux : source_color = vec3(0.00, 0.07, 0.18);
uniform vec3 couleur_ecume : source_color = vec3(0.96, 0.99, 1.0);
uniform vec3 couleur_lagon : source_color = vec3(0.72, 1.0, 0.94);
// Le soleil de la cuisson, haut à gauche, pour que les pentes s'éclairent du
// même côté que les ombres peintes des îles.
uniform vec3 soleil = vec3(-0.55, 0.68, -0.48);

// Même étendue de référence que la mer animée : les fréquences se lisent sur
// la fraction de carte, et ne dépendent pas de sa définition.
const float LARGEUR_MOTIF = 3600.0;
// La longueur d'onde de la plus grande vaguelette, en unités de motif.
const float ONDE = 26.0;


float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	// Interpolation QUINTIQUE, pas cubique : la cubique a une dérivée seconde
	// discontinue aux bords de cellule, et la normale qu'on tire de ce bruit y
	// casse. Éclairée, la mer montrait alors la grille — des losanges, une
	// moquette froissée plutôt qu'une eau.
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(hash21(i),                 hash21(i + vec2(1.0, 0.0)), f.x),
	           mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		v += amp * bruit(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		amp *= 0.5;
	}
	return v;
}

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


// LES VAGUELETTES : trois couches de bruit qui défilent dans trois directions,
// à trois vitesses. C'est la carte de normales de PR3, superposée à elle-même
// en sens contraires — ce qui empêche l'oeil de voir un motif qui glisse,
// puisque rien ne glisse d'un seul bloc.
//
// Le domaine est tourné dans le sens de l'alizé et ÉTIRÉ en travers : une
// vague a une crête longue et un dos court. Un bruit isotrope donnait des
// bosses rondes, qui se lisent comme un crépi et non comme une mer.
const mat2 VENT = mat2(vec2(0.94, 0.34), vec2(-0.34, 0.94));

float vaguelettes(vec2 p, float t) {
	// À peine étiré. À 1,7 contre 0,55 les crêtes devenaient des traits
	// parallèles d'un bord à l'autre de l'écran, et la mer semblait sous l'averse ;
	// à 1,25 contre 0,80 la pluie se devinait encore. Les trois couches croisées
	// cassent déjà la régularité, l'étirement n'a qu'à suggérer le vent.
	vec2 v = (VENT * p) * vec2(1.08, 0.92);
	return 0.55 * bruit(v / ONDE + vec2( 0.30,  0.11) * t)
	     + 0.30 * bruit(v / ONDE * 2.2 + vec2(-0.21,  0.37) * t)
	     + 0.15 * bruit(v / ONDE * 4.6 + vec2( 0.44, -0.29) * t);
}


// Un éclat par cellule, dont seule une fraction s'allume, chacun sur sa phase :
// la recette des paillettes de la nappe d'origine.
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
				float bat = 0.5 + 0.5 * sin(t * (1.3 + 2.4 * hash21(c + 3.3)) + h * 62.8);
				float d = length(g + o - pf);
				float coeur = 1.0 - smoothstep(0.0, taille * 0.62, d);
				float halo = 1.0 - smoothstep(0.0, taille * 1.80, d);
				v = max(v, (coeur * coeur * 0.66 + halo * halo * 0.52) * bat);
			}
		}
	}
	return v;
}


// Le « over » en alpha droit : pose une couche sur ce qui est déjà composé.
// Toutes les couches se superposent dans le shader, et l'image n'en reçoit
// qu'une seule, déjà mélangée.
vec4 poser(vec4 dessous, vec3 c, float a) {
	a = clamp(a, 0.0, 1.0);
	float sortie = a + dessous.a * (1.0 - a);
	if (sortie < 1e-5) {
		return vec4(0.0);
	}
	vec3 rgb = (c * a + dessous.rgb * dessous.a * (1.0 - a)) / sortie;
	return vec4(rgb, sortie);
}


void fragment() {
	vec2 fiche = texture(TEXTURE, UV).rg;
	float eau = fiche.r;
	if (eau < 0.01) {
		discard;
	}
	float prof = fiche.g * 60.0;

	vec2 p = UV * vec2(LARGEUR_MOTIF, LARGEUR_MOTIF * taille_monde.y / taille_monde.x);
	float t = TIME * vitesse;

	// LE DÉTAIL SE RÈGLE SUR L'ÉCRAN, pas sur le zoom. `fwidth` dit combien
	// d'unités de motif couvre un pixel ici et maintenant : une vaguelette qui
	// tient en moins de six pixels ne produit plus que du grésillement, on la
	// fond. Le premier essai lisait le zoom de la caméra, dont la valeur dépend
	// de la taille de la fenêtre : sur un écran de 2 560 pixels les vaguelettes
	// étaient éteintes au plus près.
	float px_par_onde = ONDE / max(fwidth(p.x), 1e-4);
	float detail = smoothstep(6.0, 16.0, px_par_onde);

	vec4 c = vec4(0.0);

	// --- les vaguelettes, éclairées ------------------------------------------
	float e = 0.9;
	float h0 = vaguelettes(p, t);
	float hx = vaguelettes(p + vec2(e, 0.0), t);
	float hz = vaguelettes(p + vec2(0.0, e), t);
	vec2 pente = vec2(hx - h0, hz - h0) / e * ONDE * 0.55;
	vec3 n = normalize(vec3(-pente.x, 1.0, -pente.y));
	vec3 l = normalize(soleil);
	// Retenu : au premier réglage l'éclairage montait à un tiers d'opacité, et la
	// mer peinte disparaissait sous un grain uniforme. Il doit se voir comme un
	// frisson sur l'eau, pas comme la surface elle-même.
	float eclaire = (dot(n, l) - l.y) * 2.2 * detail;
	c = poser(c, couleur_creux, max(-eclaire, 0.0) * 0.17 * force);
	c = poser(c, couleur_ciel, max(eclaire, 0.0) * 0.15 * force);

	// --- les caustiques du lagon ------------------------------------------------
	//
	// Sur le plateau clair, le fond se voit : la lumière y dessine son réseau
	// mouvant. Deux cellules de Worley qui dérivent en sens contraires, et on ne
	// garde que leurs arêtes communes.
	float lagon = smoothstep(0.2, 1.0, prof) * (1.0 - smoothstep(2.5, 6.0, prof));
	vec2 q = p / 13.0;
	float w1 = worley(q + vec2(t * 0.09, t * 0.03));
	float w2 = worley(q * 1.31 + vec2(-t * 0.06, t * 0.08) + 3.1);
	// Arêtes larges et faibles : fines et vives, elles traçaient un filet blanc
	// sur les hauts-fonds, plus proche d'un grillage que de la lumière.
	float caustique = pow(1.0 - smoothstep(0.0, 0.32, abs(w1 - w2)), 3.0);
	c = poser(c, couleur_lagon, caustique * lagon * 0.13 * detail * force);

	// --- l'écume du rivage ------------------------------------------------------
	//
	// Un liseré qui enfle et se retire contre la plage, déchiré par un bruit LARGE
	// — des lambeaux, pas un pointillé.
	float souffle = 0.5 + 0.5 * sin(t * 0.8 + fbm(p * 0.015) * 6.0);
	float rive = 1.0 - smoothstep(0.0, 0.5 + 0.8 * souffle, prof);
	float lambeaux = smoothstep(0.30, 0.65, fbm(p / 18.0 + vec2(t * 0.04, -t * 0.03)));
	c = poser(c, couleur_ecume, rive * (0.25 + 0.55 * lambeaux) * 0.50 * force);

	// Le ressac : une seule vague à la fois qui monte vers la plage et s'y efface,
	// visible sur le premier mètre et demi seulement.
	float ressac = fract(prof * 0.55 - t * 0.12 + fbm(p / 40.0) * 1.5);
	float front = smoothstep(0.80, 0.97, ressac) * (1.0 - smoothstep(0.97, 1.0, ressac));
	float bande = smoothstep(0.1, 0.5, prof) * (1.0 - smoothstep(1.0, 1.8, prof));
	c = poser(c, couleur_ecume, front * bande * lambeaux * 0.35 * force);

	// --- les paillettes ----------------------------------------------------------
	//
	// Une par cellule, et une maille qui suit la taille du pixel : vue de loin la
	// mer garde ses éclats, vue de près ils ne deviennent pas des taches.
	float maille = 1.0 / (14.0 * max(fwidth(p.x), 1e-3));
	float loin = 1.0 - detail;
	float paillette = paillettes(p * maille + vec2(t * 0.02, -t * 0.013), t, 0.10 + 0.04 * loin, 0.50);
	float au_large = smoothstep(1.5, 8.0, prof);
	c = poser(c, couleur_ecume, paillette * mix(0.08, 0.14, loin) * au_large * force);

	COLOR = vec4(c.rgb, c.a * eau);
}
