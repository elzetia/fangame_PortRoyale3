# -*- coding: utf-8 -*-
"""Fabrique la texture qui sert de terrain a la cuisson : un CHAMP DE DISTANCE.

    py outils/champ_cote.py

Ecrit `carte_champ.png` (1320 x 960), une image ou chaque canal dit une chose :

  R  distance a la cote vers l'INTERIEUR des terres, en cases, plafonnee a 255
  G  distance a la cote vers le LARGE, en cases, plafonnee a 255
  B  le relief de Port Royale 3 a cet endroit, 0 a 255

Pourquoi un champ de distance plutot que la carte d'altitude de PR3 directement.

Le masque `ini/map.bmp` est la VERITE DU JEU : c'est lui qui dit ou un navire
peut passer et ou une ville se pose. Sa carte d'altitude, elle, vit dans une
autre texture, avec son propre cadre et son propre calage -- et rien ne garantit
que les deux coincident au pixel. Cuire le decor depuis l'altitude, c'est
risquer un trait de cote peint a dix cases du trait de cote jouable : le joueur
verrait son sloop traverser une plage. Le champ de distance, lui, est calcule
DEPUIS le masque : la cote peinte est la cote jouable, par construction.

Le relief de PR3 garde quand meme un role, dans le canal bleu : il ne decide pas
ou est la terre, seulement ou sont les MONTAGNES. Un decalage de quelques cases
y est sans consequence -- une sierra un peu deplacee reste une sierra.

La distance est calculee par balayage de chanfrein (5-7-11), deux passes : une
descendante, une remontante. Ce n'est pas la distance euclidienne exacte, mais
l'ecart est de l'ordre du pour cent, et l'exactitude n'a aucune importance ici :
on s'en sert pour faire monter un relief, pas pour mesurer un cap.
"""
import io
import os
import struct
import sys
import zlib

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PR3_MOD = r"D:\GOG Galaxy\Games\Port Royale 3\_mod\pr3"
sys.path.insert(0, PR3_MOD)

import pr3fuk    # noqa: E402
import pr3map    # noqa: E402

# Calage du relief de PR3 sur le masque, en BLOCS de 4 pixels de sa texture.
# Le contenu de la carte du monde occupe 5 632 des 6 144 pixels de large : il y a
# 256 pixels de cadre a gauche et autant a droite, et rien en haut ni en bas.
# 5632 / 4096 = 1,375, qui est exactement le rapport du masque 1320 x 960 -- ce
# qui confirme le decoupage. D'ou une seule et meme echelle sur les deux axes.
# Le calage exact a ete cherche, pas devine : on maximise l'accord entre "ce que
# la carte peinte montre comme terre" (le bleu de la mer ne ment pas) et le
# masque, sur dix-sept mille points d'epreuve. L'optimum vaut 87,8 % d'accord --
# le reste est la frange de haut-fond, que les deux sources ne tranchent pas au
# meme endroit, et qui n'a aucune importance pour ce a quoi ce canal sert.
BLOC_X0 = 75.0
BLOC_Y0 = 27.0
BLOC_PAR_CASE_X = 1.0580
BLOC_PAR_CASE_Y = 1.0540

# La zone de contenu de la texture, en blocs : le cadre est exclu.
CONTENU = (64, 1471, 18, 1004)   # x_min, x_max, y_min, y_max

MAX = 255


def ecrire_png(chemin, w, h, rgb):
    brut = bytearray()
    for y in range(h):
        brut.append(0)
        brut += rgb[y * w * 3:(y + 1) * w * 3]

    def bloc(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)

    with io.open(chemin, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(bloc(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)))
        f.write(bloc(b'IDAT', zlib.compress(bytes(brut), 6)))
        f.write(bloc(b'IEND', b''))


def chanfrein(dedans, w, h):
    """Distance de chanfrein 5-7-11 aux cases ou `dedans` est faux, /5."""
    GRAND = 1 << 28
    d = [0 if not dedans[i] else GRAND for i in range(w * h)]
    # Descendante.
    for y in range(h):
        base = y * w
        for x in range(w):
            i = base + x
            if d[i] == 0:
                continue
            m = d[i]
            if y > 0:
                if x > 0:
                    m = min(m, d[i - w - 1] + 7)
                m = min(m, d[i - w] + 5)
                if x + 1 < w:
                    m = min(m, d[i - w + 1] + 7)
                if x > 1 and y > 0:
                    m = min(m, d[i - w - 2] + 11)
            if x > 0:
                m = min(m, d[i - 1] + 5)
            d[i] = m
    # Remontante.
    for y in range(h - 1, -1, -1):
        base = y * w
        for x in range(w - 1, -1, -1):
            i = base + x
            if d[i] == 0:
                continue
            m = d[i]
            if y + 1 < h:
                if x + 1 < w:
                    m = min(m, d[i + w + 1] + 7)
                m = min(m, d[i + w] + 5)
                if x > 0:
                    m = min(m, d[i + w - 1] + 7)
            if x + 1 < w:
                m = min(m, d[i + 1] + 5)
            d[i] = m
    return d


def _dds_blocs(data, canaux):
    """Une valeur par bloc DXT1 de 4 x 4 px : la couleur c0, sans tout decoder.

    Un apercu au quart suffit, et il est mille fois moins cher qu'un decodage
    complet des vingt-cinq millions de pixels de la carte du monde.
    """
    h, w = struct.unpack_from("<ii", data, 12)
    off, bw, bh = 128, w // 4, h // 4
    out = bytearray(bw * bh * canaux)
    for by in range(bh):
        p = off + by * bw * 8
        for bx in range(bw):
            c0 = data[p] | data[p + 1] << 8
            i = (by * bw + bx) * canaux
            if canaux == 1:
                out[i] = ((c0 >> 5) & 0x3f) << 2
            else:
                out[i] = ((c0 >> 11) & 0x1f) << 3
                out[i + 1] = ((c0 >> 5) & 0x3f) << 2
                out[i + 2] = (c0 & 0x1f) << 3
            p += 8
    return out, bw, bh


def _dds_luminance(data):
    """Le DXT1 DECODE, tous les pixels, en luminance.

    L'apercu par bloc suffit pour savoir ou est la terre ; il ne suffit pas pour
    le relief. Un bloc fait quatre pixels de cote : en n'en gardant qu'une
    couleur, on jette les trois quarts de la finesse du terrain de Port Royale 3
    -- exactement la ou l'on voudrait des cretes.

    DXT1 : deux couleurs de reference en RGB565, puis seize index de deux bits
    qui choisissent parmi ces deux couleurs et leurs deux interpolations.
    """
    h, w = struct.unpack_from("<ii", data, 12)
    off, bw, bh = 128, w // 4, h // 4
    out = bytearray(w * h)
    for by in range(bh):
        p = off + by * bw * 8
        for bx in range(bw):
            c0 = data[p] | data[p + 1] << 8
            c1 = data[p + 2] | data[p + 3] << 8
            bits = data[p + 4] | data[p + 5] << 8 | data[p + 6] << 16 | data[p + 7] << 24
            # On ne garde que le canal vert (six bits) : le relief est gris, et
            # c'est le canal le mieux quantifie du RGB565.
            v0 = ((c0 >> 5) & 0x3f) << 2
            v1 = ((c1 >> 5) & 0x3f) << 2
            if c0 > c1:
                pal = (v0, v1, (2 * v0 + v1) // 3, (v0 + 2 * v1) // 3)
            else:
                pal = (v0, v1, (v0 + v1) // 2, 0)
            base = by * 4 * w + bx * 4
            for ty in range(4):
                d = base + ty * w
                b4 = bits >> (ty * 8)
                out[d] = pal[b4 & 3]
                out[d + 1] = pal[(b4 >> 2) & 3]
                out[d + 2] = pal[(b4 >> 4) & 3]
                out[d + 3] = pal[(b4 >> 6) & 3]
            p += 8
    return out, w, h


def _assembler(gauche, droite, canaux):
    g, gw, gh = _dds_blocs(gauche, canaux)
    d, dw, _ = _dds_blocs(droite, canaux)
    W, H = gw + dw, gh
    R = bytearray(W * H * canaux)
    for y in range(H):
        R[(y * W) * canaux:(y * W + gw) * canaux] = g[y * gw * canaux:(y + 1) * gw * canaux]
        R[(y * W + gw) * canaux:((y + 1) * W) * canaux] = d[y * dw * canaux:(y + 1) * dw * canaux]
    return R, W, H


def textures_pr3():
    """Le relief et la couleur de la carte du monde, lus dans l'archive du jeu.

    Le relief est decode ENTIEREMENT (6 144 x 4 096), la couleur seulement par
    bloc : la premiere sert a sculpter, la seconde seulement a dire ou est la
    terre peinte, et une valeur par bloc y suffit largement.
    """
    jeu = pr3map.game()
    a = pr3fuk.load(pr3map.orig(jeu, "data.fuk"))
    lire = lambda n: pr3fuk.content(a, pr3fuk.find(a, n))

    g, gw, gh = _dds_luminance(lire("worldmaplefthght.dds"))
    d, dw, _dh = _dds_luminance(lire("worldmaprighthght.dds"))
    W, H = gw + dw, gh
    R = bytearray(W * H)
    for y in range(H):
        R[y * W:y * W + gw] = g[y * gw:(y + 1) * gw]
        R[y * W + gw:(y + 1) * W] = d[y * dw:(y + 1) * dw]

    couleur = _assembler(lire("worldmapleft.dds"), lire("worldmapright.dds"), 3)
    a["f"].close()
    return (R, W, H), couleur


def _glissant(m, w, h, r, maxi):
    """Maximum (ou minimum) glissant, separable : horizontal puis vertical.

    La fenetre est simplement coupee au bord : une cloture qui touche le bord de
    la carte doit y rester une cloture, pas s'y eroder.
    """
    out = bytearray(m)
    tmp = bytearray(w * h)
    for z in range(h):
        base = z * w
        for x in range(w):
            v = 0 if maxi else 1
            for k in range(max(0, x - r), min(w, x + r + 1)):
                u = out[base + k]
                if maxi:
                    if u:
                        v = 1
                        break
                elif not u:
                    v = 0
                    break
            tmp[base + x] = v
    for z in range(h):
        base = z * w
        for x in range(w):
            v = 0 if maxi else 1
            for k in range(max(0, z - r), min(h, z + r + 1)):
                u = tmp[k * w + x]
                if maxi:
                    if u:
                        v = 1
                        break
                elif not u:
                    v = 0
                    break
            out[base + x] = v
    return out


def ouvrir(m, w, h, r):
    """Ouverture morphologique : erosion puis dilatation.

    Elle efface les franges minces et ne garde que les blocs massifs. C'est ce
    qui permet de distinguer une vraie CLOTURE -- des milliers de cases d'un
    bloc -- d'un simple desaccord de quelques cases sur un trait de cote.
    """
    return _glissant(_glissant(m, w, h, r, False), w, h, r, True)


# --- les biomes ---------------------------------------------------------------
#
# Le bassin caraibe n'est pas une seule jungle. On pose donc une carte de biome a
# cote du champ de distance, tiree de la geographie REELLE :
#
#   rouge  aridite   0 = foret humide, 255 = desert
#   vert   coniferes 0 = aucune, 255 = pinede
#
# Les foyers ci-dessous sont places a la main d'apres ce qui pousse vraiment la.
# Chacun rayonne sur un disque a bord doux, et l'on garde le maximum : deux
# foyers voisins se rejoignent au lieu de se moyenner en bouillie.
#
#   x, z    en cases du masque
#   rayon   en cases, jusqu'ou le foyer porte
#   aridite, coniferes  0 a 1
FOYERS = [
    # -- cote du Tamaulipas et du Texas : matorral epineux, jaune et rase.
    #    C'est le seul vrai semi-desert cotier du golfe, et il porte Corpus
    #    Christi et Tampico.
    (119, 175, 130, 0.88, 0.05),   # Corpus Christi
    (60, 250, 120, 0.92, 0.05),
    (63, 362, 120, 0.86, 0.08),    # Tampico
    (20, 300, 150, 0.95, 0.10),    # l'interieur, plus sec encore
    # -- Sierra Madre Orientale : les plateaux au nord-ouest, pins d'altitude.
    (10, 180, 120, 0.70, 0.55),
    (15, 420, 110, 0.72, 0.45),
    # -- Louisiane et cote du golfe : marais et pins des plaines.
    (297, 140, 110, 0.10, 0.55),   # Nouvelle Orleans
    (400, 145, 120, 0.08, 0.60),   # Biloxi, Pensacola
    # -- Floride : pinedes plates et marais, jamais aride.
    (500, 180, 130, 0.12, 0.62),
    (530, 280, 110, 0.10, 0.35),
    # -- Yucatan : calcaire plat et foret SECHE, pas de coniferes.
    (280, 430, 120, 0.52, 0.0),
    (340, 470, 110, 0.45, 0.0),
    # -- Guajira, Coro, Paraguana : le desert cotier du Venezuela, dunes
    #    comprises. Coro est litteralement un desert.
    (903, 749, 95, 0.90, 0.0),
    (860, 790, 80, 0.72, 0.0),
    (770, 745, 85, 0.68, 0.0),     # vers Santa Marta et la Guajira
]


def carte_biome(w, h):
    """Aridite et coniferes par case, en deux octets."""
    ar = bytearray(w * h)
    co = bytearray(w * h)
    for cx, cz, rayon, aridite, coniferes in FOYERS:
        r2 = float(rayon * rayon)
        x0, x1 = max(0, cx - rayon), min(w, cx + rayon + 1)
        z0, z1 = max(0, cz - rayon), min(h, cz + rayon + 1)
        for z in range(z0, z1):
            dz = z - cz
            for x in range(x0, x1):
                dx = x - cx
                d2 = dx * dx + dz * dz
                if d2 >= r2:
                    continue
                # Un PLATEAU, pas une pointe. Avec une simple parabole au carre,
                # seul le coeur du foyer etait vraiment sec et tout le reste
                # revenait au vert : un desert de la taille d'un village. Ici la
                # valeur est PLEINE jusqu'a la moitie du rayon, puis descend en
                # douceur -- une region a un centre large et des marges floues.
                d = (d2 / r2) ** 0.5
                if d <= 0.50:
                    t = 1.0
                else:
                    u = (d - 0.50) / 0.50
                    t = 1.0 - u * u * (3.0 - 2.0 * u)
                i = z * w + x
                a = int(255 * aridite * t)
                c = int(255 * coniferes * t)
                if a > ar[i]:
                    ar[i] = a
                if c > co[i]:
                    co[i] = c
    return ar, co


def main():
    masque, w, h = pr3map.world_mask()
    print("masque %d x %d" % (w, h))
    (relief, RW, RH), (couleur, CW, CH) = textures_pr3()
    print("textures de PR3 : %d x %d blocs" % (RW, RH))

    def bloc_de_case(x, y):
        # Borne a la zone de CONTENU, cadre exclu. Sans ca les quinze dernieres
        # lignes du masque tombent au-dela des 1 024 blocs de la texture : la
        # carte peinte n'a rien a y dire, tout y passait pour de la mer, donc
        # pour une cloture -- et il restait une bande de plage sur toute la
        # largeur du bas de la carte.
        bx = int(BLOC_X0 + x * BLOC_PAR_CASE_X)
        by = int(BLOC_Y0 + y * BLOC_PAR_CASE_Y)
        return min(max(bx, CONTENU[0]), CONTENU[1]), min(max(by, CONTENU[2]), CONTENU[3])

    # Ce que la carte PEINTE de PR3 montre comme terre : le bleu de la mer ne
    # ment pas, et le cadre est gris neutre.
    peint = bytearray(w * h)
    for y in range(h):
        for x in range(w):
            bx, by = bloc_de_case(x, y)
            if 0 <= bx < CW and 0 <= by < CH:
                i = (by * CW + bx) * 3
                r, v, b = couleur[i], couleur[i + 1], couleur[i + 2]
                cadre = abs(r - v) < 10 and abs(v - b) < 10 and r > 150
                peint[y * w + x] = 0 if (not cadre and b > r + 24 and b > v + 8) else 1

    # LA CLOTURE. Port Royale 3 marque comme terre, dans son masque, de vastes
    # zones que sa carte peinte montre en PLEINE MER : c'est ainsi qu'il borne
    # le monde, en barrant le large plutot qu'en posant une limite invisible.
    # Peintes comme de la jungle, elles donnaient un continent imaginaire au
    # sud-ouest.
    #
    # On les reconnait a ce qu'elles sont MASSIVES. Les deux sources se
    # chamaillent aussi d'une case ou deux sur chaque trait de cote -- haut-fond
    # ici, banc de sable la -- et il ne faut surtout pas prendre ces franges
    # pour des clotures, sinon on raboterait toutes les cotes du jeu. D'ou
    # l'ouverture morphologique : elle efface le mince et garde le massif.
    brut = bytearray(1 if (masque[i] and not peint[i]) else 0 for i in range(w * h))
    cloture = ouvrir(brut, w, h, 5)
    n_brut, n_cl = sum(brut), sum(cloture)
    print("desaccord masque/peinture : %d cases, dont %d de cloture massive (%.0f %%)"
          % (n_brut, n_cl, 100.0 * n_cl / max(n_brut, 1)))

    # La terre PEINTE est donc le masque moins la cloture. La terre NAVIGABLE,
    # elle, reste le masque entier : `sim/carte_monde.lua` ne change pas, et un
    # navire ne franchit toujours pas la cloture. Seul le decor cesse de mentir.
    terre = [bool(masque[i] and not cloture[i]) for i in range(w * h)]
    mer = [not t for t in terre]
    print("distance vers l'interieur...")
    d_terre = chanfrein(terre, w, h)
    print("distance vers le large...")
    d_mer = chanfrein(mer, w, h)

    px = bytearray(w * h * 3)
    for y in range(h):
        for x in range(w):
            i = y * w + x
            bx, by = bloc_de_case(x, y)
            b = 0
            # Au-dela du contenu de la texture, on ne SAIT pas : bloquer le
            # relief a zero plutot que d'etirer la derniere ligne connue, qui
            # peignait des stries verticales sur toute la largeur du bas.
            hors = int(BLOC_Y0 + y * BLOC_PAR_CASE_Y) > CONTENU[3]
            if not hors and 0 <= bx < RW and 0 <= by < RH:
                m = relief[by * RW + bx]
                b = 0 if m == 188 else m       # 188 = le cadre
            px[i * 3] = min(MAX, d_terre[i] // 5)
            px[i * 3 + 1] = min(MAX, d_mer[i] // 5)
            px[i * 3 + 2] = b

    # LE RELIEF, A DEUX FOIS LA RESOLUTION DU MASQUE.
    #
    # Le champ de distance se contente d'une valeur par case : c'est une donnee
    # lisse, qui ne gagne rien a etre plus fine. Le relief, lui, est ce qu'on
    # sculpte -- et une valeur par case, sur une carte cuite a six mille pixels,
    # etale chaque cote de montagne sur cinq pixels. On le sort donc a part, au
    # double, et decode entierement plutot que par bloc.
    print("relief de PR3 en pleine resolution...")
    FIN = 2
    rw, rh = w * FIN, h * FIN
    px_rel = bytearray(rw * rh * 3)
    for y in range(rh):
        cy = y / float(FIN)
        by = (BLOC_Y0 + cy * BLOC_PAR_CASE_Y)
        hors = by > CONTENU[3]
        by4 = int(min(max(by, CONTENU[2]), CONTENU[3]) * 4.0)
        for x in range(rw):
            v = 0
            if not hors:
                cx = x / float(FIN)
                bx = BLOC_X0 + cx * BLOC_PAR_CASE_X
                bx4 = int(min(max(bx, CONTENU[0]), CONTENU[1]) * 4.0)
                if 0 <= bx4 < RW and 0 <= by4 < RH:
                    m = relief[by4 * RW + bx4]
                    v = 0 if m == 188 else m        # 188 = le cadre
            i = (y * rw + x) * 3
            px_rel[i] = v
            px_rel[i + 1] = v
            px_rel[i + 2] = v
    ecrire_png(os.path.join(RACINE, "carte_relief.png"), rw, rh, px_rel)
    print("  ecrit : carte_relief.png %d x %d" % (rw, rh))

    print("carte des biomes...")
    ar, co = carte_biome(w, h)
    px_bio = bytearray(w * h * 3)
    for i in range(w * h):
        px_bio[i * 3] = ar[i]
        px_bio[i * 3 + 1] = co[i]
    ecrire_png(os.path.join(RACINE, "carte_biome.png"), w, h, px_bio)
    arides = sum(1 for v in ar if v > 110)
    print("  %.1f %% de la carte est aride, %.1f %% porte des coniferes"
          % (100.0 * arides / (w * h), 100.0 * sum(1 for v in co if v > 90) / (w * h)))

    sortie = os.path.join(RACINE, "carte_champ.png")
    ecrire_png(sortie, w, h, px)
    print("ecrit : %s" % sortie)
    print("  terre peinte : %.1f %% (masque : %.1f %%)"
          % (100.0 * sum(terre) / (w * h), 100.0 * sum(masque) / (w * h)))


if __name__ == "__main__":
    main()
