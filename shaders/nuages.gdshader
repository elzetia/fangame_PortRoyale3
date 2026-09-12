// Les nuages qui traversent la carte, et leur ombre portée.
//
// C'est la dernière couche, au-dessus de tout le reste : le terrain cuit, la
// nappe de mer, les navires et les villages. Port Royale 3 fait exactement ça —
// quelques paquets de cumulus qui dérivent sur l'archipel, et sous chacun une
// tache sombre qui glisse sur l'eau puis escalade les terres. C'est peu de
// chose, et c'est ce qui fait qu'une carte respire au lieu d'être une image.
//
// Le principe tient en une phrase : on évalue DEUX FOIS le même champ de
// nuages, une fois à sa place et une fois décalé, et le décalage est l'ombre.
// Rien ne distingue l'ombre du nuage sinon l'endroit où on la lit et la couleur
// qu'on lui donne.
//
// Le sens du décalage n'est pas libre : c'est celui du soleil de la cuisson,
// qui vient du haut-gauche. Toutes les ombres de la carte — celles du relief,
// celles des palmiers, celles des villages — tombent vers le bas-droite. Une
// ombre de nuage qui partirait ailleurs trahirait l'ensemble d'un coup.

shader_type canvas_item;
render_mode unshaded;

uniform vec2 taille_monde = vec2(15840.0, 9632.0);
uniform float vitesse = 1.0;

// Combien de ciel est couvert. C'est un SEUIL sur le bruit, pas une densité :
// au-dessus, les nuages se rejoignent en une couche continue et l'on ne voit
// plus passer grand-chose. En dessous de 0,40 on retombe sur un ciel vide.
uniform float couverture : hint_range(0.30, 0.85) = 0.672;
uniform vec2 vent = vec2(0.88, 0.34);

// Combien de paquets sur la largeur de la carte. Assez pour qu'un cumulus soit
// un objet qu'on suit des yeux, pas une texture — et pas au point de voiler la
// carte : au premier essai, les deux tiers de l'archipel disparaissaient sous
// une couche continue.
uniform float echelle = 13.0;

uniform vec3 teinte : source_color = vec3(0.97, 0.98, 1.0);
uniform float force_nuage : hint_range(0.0, 1.0) = 0.66;
uniform float force_ombre : hint_range(0.0, 1.0) = 0.34;

// Décalage de l'ombre, en fraction de la largeur de carte. Il vaut l'altitude
// du nuage projetée au sol : plus il est grand, plus les nuages paraissent
// hauts. Trop grand, l'ombre se détache de son nuage et l'on ne les associe
// plus.
uniform vec2 decalage_ombre = vec2(0.022, 0.019);


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


// Le champ de nuages en un point. Zéro = ciel clair, un = coeur du cumulus.
float nuage(vec2 q) {
	float v = fbm(q, 4);
	// Un seuil DOUX : franc, il découpe des continents de coton aux bords nets ;
	// absent, on obtient une brume uniforme sur toute la carte. La largeur de la
	// transition est ce qui fait un bord de cumulus.
	float m = smoothstep(couverture, couverture + 0.20, v);
	// Effilochage : le bord d'un nuage n'est pas une courbe lisse.
	m *= 0.62 + 0.38 * fbm(q * 3.3 + 11.7, 3);
	return clamp(m, 0.0, 1.0);
}


void fragment() {
	// Les nuages dérivent dans le plan de la carte, à vitesse constante. Ils ne
	// tiennent pas compte du relief : un nuage passe au-dessus de tout.
	float t = TIME * vitesse * 0.012;
	vec2 ratio = vec2(1.0, taille_monde.y / taille_monde.x);
	vec2 q = UV * echelle * ratio + vent * t;

	float n = nuage(q);
	// L'ombre est le MÊME champ, lu EN AMONT du soleil. Le signe compte : lu en
	// aval, la tache tombait en haut-à-gauche de son nuage, c'est-à-dire du côté
	// d'où vient la lumière — et toute la carte s'en trouvait contredite d'un
	// coup, puisque relief, palmiers et villages portent la leur en bas-à-droite.
	float o = nuage(q - decalage_ombre * echelle * ratio);

	// Composition dans l'ordre : l'ombre d'abord, le nuage par-dessus. On la
	// fait à la main parce que les deux couches n'ont pas la même couleur — un
	// simple mélange donnerait un nuage grisâtre là où les deux se recouvrent,
	// alors qu'un nuage cache toujours sa propre ombre.
	float a_ombre = o * force_ombre;
	float a_nuage = n * force_nuage;
	float a = a_nuage + a_ombre * (1.0 - a_nuage);
	// L'ombre est noire, donc elle n'apporte rien à la couleur : seule la part
	// du nuage la porte.
	vec3 c = a > 0.0005 ? teinte * (a_nuage / a) : vec3(0.0);

	COLOR = vec4(c, a);
}
