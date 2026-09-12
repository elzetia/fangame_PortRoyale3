// Eau stylisée « lagon des Caraïbes ».
//
// Trois choses font le rendu, dans cet ordre d'importance :
//   1. la couleur par profondeur — le turquoise vif sur les hauts-fonds qui
//      vire au bleu profond au large, c'est 80 % de l'effet ;
//   2. l'écume de rivage, une bande qui épouse la côte et ondule ;
//   3. la houle de Gerstner, qui donne le relief et les crêtes écumeuses.
//
// Tout est procédural : aucune texture à charger.
//
// Hypothèse : le plan d'eau n'est ni tourné ni mis à l'échelle (translation
// seule). Ça permet de travailler en espace monde sans inverser de matrice.

shader_type spatial;
// depth_draw_never : l'eau ne doit surtout pas écrire dans le tampon de
// profondeur qu'elle échantillonne, sinon elle se lit elle-même et la
// profondeur mesurée vaut zéro partout (écume sur tout l'océan).
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;

group_uniforms Couleurs;
uniform vec3 couleur_haut_fond : source_color = vec3(0.22, 0.88, 0.82);
uniform vec3 couleur_lagon     : source_color = vec3(0.05, 0.55, 0.72);
uniform vec3 couleur_large     : source_color = vec3(0.02, 0.16, 0.36);
uniform float profondeur_lagon = 24.0;
uniform float profondeur_large = 110.0;

group_uniforms Ecume;
uniform vec3 couleur_ecume : source_color = vec3(1.0, 1.0, 1.0);
uniform float ecume_largeur = 9.0;        // bande de rivage : fine, comme dans PR3
uniform float ecume_bruit_echelle = 0.055;
uniform float ecume_vitesse = 1.6;
uniform float ecume_cretes = 1.55;        // seuil haut : seules les vraies crêtes moutonnent

group_uniforms Vagues;
// Chaque vague : xy = direction, z = amplitude (m), w = longueur d'onde (m).
uniform vec4 vague_1 = vec4( 1.0,  0.35, 0.90, 150.0);
uniform vec4 vague_2 = vec4(-0.6,  1.00, 0.60,  96.0);
uniform vec4 vague_3 = vec4( 0.8, -0.70, 0.34,  56.0);
uniform vec4 vague_4 = vec4(-0.9, -0.30, 0.18,  29.0);
uniform float raideur = 0.75;             // 0 = sinus mou, 1 = crêtes pointues
uniform float vitesse_temps = 0.5;

group_uniforms Surface;
uniform float rugosite = 0.55;
uniform float transparence = 0.92;
uniform float fresnel_force = 0.10;

uniform sampler2D texture_profondeur : hint_depth_texture, filter_linear_mipmap;

// Diagnostic : 1 = profondeur en niveaux de gris (200 m = blanc).
// Sert à vérifier ce que le shader mesure vraiment, plutôt qu'à le supposer.
uniform int mode_debug = 0;

varying vec3 monde;
varying float crete;      // hauteur de la vague, pour l'écume de crête


// --- bruit de valeur, pour faire onduler l'écume -----------------------------
// Hachage robuste (Dave Hoskins) : le hachage naïf pave l'image de rectangles
// dès que les coordonnées monde dépassent quelques centaines de mètres.
float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i),                hash21(i + vec2(1.0, 0.0)), f.x),
	           mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		v += amp * bruit(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return v;
}


// --- houle de Gerstner -------------------------------------------------------
// Le sommet se déplace aussi horizontalement, vers les crêtes : c'est ce qui
// donne des crêtes pointues et des creux larges, là où une simple sinusoïde
// reste molle. Dérivation classique (GPU Gems 1, ch. 1), transposée du repère
// « z vers le haut » de l'article au repère « y vers le haut » de Godot.
//
// `accN` accumule les termes de la normale analytique : pas de recalcul par
// différences finies, donc pas de facettes.
vec3 gerstner(vec4 v, vec2 pos, float t, inout vec3 accN) {
	vec2 dir = normalize(v.xy);
	float amplitude = v.z;
	float longueur = max(v.w, 1.0);

	float k = TAU / longueur;
	float celerite = sqrt(9.81 / k);          // houle de gravité en eau profonde
	float phase = k * (dot(dir, pos) - celerite * t * vitesse_temps);
	float c = cos(phase);
	float s = sin(phase);

	// Q borné : au-delà de 1/(k*A), la vague se replie sur elle-même
	float Q = raideur / max(k * amplitude * 4.0, 0.0001);
	float wa = k * amplitude;

	accN.x += dir.x * wa * c;
	accN.y += Q * wa * s;
	accN.z += dir.y * wa * c;

	return vec3(Q * amplitude * dir.x * c,
	            amplitude * s,
	            Q * amplitude * dir.y * c);
}


void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME;

	vec3 accN = vec3(0.0);
	vec3 offset = vec3(0.0);
	offset += gerstner(vague_1, p.xz, t, accN);
	offset += gerstner(vague_2, p.xz, t, accN);
	offset += gerstner(vague_3, p.xz, t, accN);
	offset += gerstner(vague_4, p.xz, t, accN);

	VERTEX += offset;          // pas de rotation ni d'échelle : offset direct
	monde = p + offset;
	crete = offset.y;

	NORMAL = normalize(vec3(-accN.x, 1.0 - accN.y, -accN.z));
}


void fragment() {
	// --- profondeur d'eau sous ce pixel ---------------------------------------
	float brut = texture(texture_profondeur, SCREEN_UV).r;
	vec4 vue = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, brut, 1.0);
	vue.xyz /= vue.w;
	float fond = -vue.z;                  // distance au fond marin
	float surface = -VERTEX.z;            // distance à la surface (VERTEX = espace vue)
	float profondeur = max(fond - surface, 0.0);

	// --- couleur par profondeur : le cœur du rendu ----------------------------
	vec3 teinte = mix(couleur_haut_fond, couleur_lagon,
	                  smoothstep(0.0, profondeur_lagon, profondeur));
	teinte = mix(teinte, couleur_large,
	             smoothstep(profondeur_lagon, profondeur_large, profondeur));

	// --- écume ----------------------------------------------------------------
	vec2 uv_bruit = monde.xz * ecume_bruit_echelle;
	float ondulation = fbm(uv_bruit + vec2(TIME * ecume_vitesse * 0.06,
	                                       TIME * ecume_vitesse * 0.04));

	// Bande de rivage : elle suit la ligne de profondeur, déformée par le bruit
	float bord = 1.0 - smoothstep(0.0, ecume_largeur,
	                              profondeur + ondulation * ecume_largeur * 0.9);
	// Seconde bande plus au large et plus fine : la houle qui déferle
	float bande = (1.0 - smoothstep(ecume_largeur, ecume_largeur * 2.8,
	                                profondeur + ondulation * ecume_largeur * 1.5)) * 0.3;
	// Crêtes écumeuses en pleine mer
	float sommet = smoothstep(ecume_cretes, ecume_cretes + 0.4, crete)
	             * step(0.55, ondulation) * 0.22;

	float ecume = clamp(bord + bande + sommet, 0.0, 1.0);

	// --- assemblage -----------------------------------------------------------
	ALBEDO = mix(teinte, couleur_ecume, ecume);

	// L'eau très peu profonde laisse voir le sable : on la rend transparente.
	float alpha = mix(0.30, transparence,
	                  smoothstep(0.0, profondeur_lagon * 0.7, profondeur));
	ALPHA = max(alpha, ecume);

	ROUGHNESS = mix(0.9, rugosite, 1.0 - ecume);
	METALLIC = 0.0;
	// Une carte ne doit pas éblouir : pas de tache de soleil sur l'eau.
	SPECULAR = mix(0.10, 0.05, ecume);

	// Fresnel : la mer s'éclaircit vers l'horizon
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
	RIM = fresnel * fresnel_force;
	RIM_TINT = 0.3;

	// Diagnostic en dernier : Godot interdit `return` dans fragment().
	if (mode_debug == 1) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(clamp(profondeur / 200.0, 0.0, 1.0));
		ALPHA = 1.0;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
		RIM = 0.0;
	}
}
