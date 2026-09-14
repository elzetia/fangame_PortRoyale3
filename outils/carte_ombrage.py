# -*- coding: utf-8 -*-
"""Refabrique `carte_cuite.png` depuis Port Royale 3, et lui donne son relief.

    py -3 outils/carte_ombrage.py --verifier     # ne rien ecrire, tout mesurer
    py -3 outils/carte_ombrage.py [--force 1.0] [--moyenne]

DEUX RAISONS D'EXISTER, et la seconde n'est pas la moindre.

1. OMBRER. La carte du jeu est peinte a plat. On calcule un ombrage depuis ses
   propres hauteurs et on le multiplie dans la couleur : meme geographie, meme
   cadrage, meme projection, seulement eclairee.

2. REGENERER. Le decor est devenu celui de PR3 (commit « Carte : le decor
   devient celle de Port Royale 3 ») par un assemblage FAIT A LA MAIN : aucun
   outil du depot ne savait le refaire. Une texture sous droits se retrouvait
   donc versionnee sans recette, ce que le projet s'interdit -- on versionne les
   outils, jamais leur sortie. Cet outil EST la recette, et `carte_cuite.png`
   peut desormais sortir du depot comme `reference_pr3/`.

CE QU'IL LIT, dans l'archive de TA copie du jeu (rien n'est redistribue) :

    worldmapleft.dds  + worldmapright.dds       4096x4096 + 2048x4096, la couleur
    worldmaplefthght + worldmaprighthght        les memes tailles, les hauteurs

Assemblees et reduites de moitie : 6144x4096 -> 3072x2048, la taille exacte du
decor en place. La reduction garde UN TEXEL SUR DEUX, et ce n'est pas un gout :
c'est ainsi que l'assemblage d'origine avait ete fait. Mesure, pas suppose --
`--verifier` donne 0,00 d'ecart moyen et 100,0 % de pixels identiques avec le
fichier en place. L'outil reproduit donc le decor AU BIT PRES avant de l'ombrer,
ce qui fait de lui sa recette exacte et non une approximation. `--moyenne` prend
plutot la moyenne de chaque carre 2x2 : plus lisse, mais ce n'est alors plus le
fichier d'origine (8,76 d'ecart moyen, 57,6 % d'identiques).

`--verifier` n'ecrit rien et mesure cet ecart : c'est la preuve que le cadrage ne
bouge pas, et les soixante ports en dependent.

POURQUOI L'OMBRAGE EST LEGITIME, mesure avant d'etre ecrit :

  * les deux textures partagent le cadrage. Terre selon la hauteur et terre
    selon la couleur s'accordent a 97,13 % pixel a pixel (28,2 % et 30,5 % de
    terre). Aucun recalage n'est necessaire.
  * la carte peinte NE PORTE PAS d'ombrage directionnel : entre pentes opposees,
    l'ecart de luminance est de 4 sur 93, soit 4 %, sur plus de cinquante mille
    echantillons de chaque cote. Une carte vraiment ombree en montre 20 a 40. On
    ajoute donc une lumiere, on n'en double pas une.

LA DIRECTION DU SOLEIL VIENT DU JEU, pas de moi : `seamap.sceneview` donne
`LightDirection` (-1, -1, -1), soit un soleil a 35,26 degres de hauteur (voir
`outils/PR3_TECHNIQUE.md`). Elle recoupe la mesure ci-dessus, dont le faible
ecart va dans le meme sens : pentes vers le nord-ouest plus claires.

L'INTENSITE, ELLE, EST UN CHOIX, et je ne le maquille pas en valeur relevee. Les
multiplicateurs de PR3 (soleil 2,5, ciel 1,5/1,45/1,4) appartiennent a son moteur
d'eclairage et ne se transposent pas a une multiplication sur une image deja
peinte. Le gain est donc cale sur la distribution REELLE des pentes, et `--force`
le multiplie. Attention au piege, paye une fois : cette carte de hauteurs est en
MAJORITE PLATE, si bien qu'une mediane prise sur toutes les terres vaut zero et
fait degenerer le calage en silence. La reference est donc un centile haut des
pentes NON NULLES, et l'outil REFUSE de travailler si elles sont trop rares.
`--sonder` montre la distribution sans rien ecrire.

APRES CET OUTIL, RELANCER `outils/carte_eau.py` : il rend la mer du large a la
nappe animee et recalcule `mer_fond`. Celui-ci ecrit du RGB opaque ; `lire_png`
le relit en RGBA, donc l'enchainement est sans piege.

Lent a dessein : vingt-cinq millions de texels en Python pur, quelques minutes.
Aucune dependance : bibliotheque standard uniquement.
"""
import importlib.util
import math
import os
import struct
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PR3_MOD = r"D:\GOG Galaxy\Games\Port Royale 3\_mod\pr3"
sys.path.insert(0, os.path.join(RACINE, "outils"))
sys.path.insert(0, PR3_MOD)

import pr3fuk                                    # noqa: E402
import pr3map                                    # noqa: E402

# `carte_illustree` porte le seul ecrire_png a nombre de canaux variable (celui
# de `decouper_planche` est fige en RGBA). On l'importe comme le font deja
# `carte_eau.py` et `carte_mer.py` : par chemin, car son `main()` est garde.
_spec = importlib.util.spec_from_file_location(
    "carte_illustree", os.path.join(RACINE, "outils", "carte_illustree.py"))
ci = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ci)

COULEUR = ("worldmapleft.dds", "worldmapright.dds")
HAUTEUR = ("worldmaplefthght.dds", "worldmaprighthght.dds")

# Le soleil de PR3 : `LightDirection` (-1, -1, -1) est la direction que SUIT la
# lumiere ; le vecteur VERS le soleil en est l'oppose.
VERS_SOLEIL = (1.0, 1.0, 1.0)

# La part de lumiere venant du ciel. Sans elle une pente a l'ombre tomberait au
# noir, alors que PR3 y garde de la couleur.
CIEL = 0.55

# Contraste vise sur la pente de REFERENCE : le choix assume de l'en-tete.
CONTRASTE_REF = 0.35

# Quel centile des pentes NON NULLES sert de reference. Un centile haut, parce
# que la carte de hauteurs de PR3 est faite en majorite de plateaux plats : une
# mediane prise sur l'ensemble y vaut zero, et le calage degenerait en silence.
CENTILE_REF = 90

# En dessous de quoi on considere qu'on est en mer et qu'on n'ombre pas.
NIVEAU_MER = 8


def _etendre(c):
    r = (c >> 11) & 0x1f
    g = (c >> 5) & 0x3f
    b = c & 0x1f
    return ((r * 527 + 23) >> 6, (g * 259 + 33) >> 6, (b * 527 + 23) >> 6)


def demi_dxt1(d, gris_seul=False, point=False):
    """Decode un DXT1 en DEMI resolution : chaque bloc 4x4 donne 2x2 pixels.

    Par defaut chaque pixel de sortie MOYENNE les 2x2 texels qu'il couvre ; avec
    `point`, il n'en garde que le premier. Un decodage pleine resolution servirait
    uniquement a etre reduit ensuite : on fait les deux d'un coup.
    """
    h, w = struct.unpack_from("<2i", d, 12)
    bw, bh = w // 4, h // 4
    ow, oh = w // 2, h // 2
    canaux = 1 if gris_seul else 3
    out = bytearray(ow * oh * canaux)
    o = 128
    for by in range(bh):
        for bx in range(bw):
            c0, c1, idx = struct.unpack_from("<HHI", d, o)
            o += 8
            a, b = _etendre(c0), _etendre(c1)
            if c0 > c1:
                pal = (a, b,
                       tuple((2 * a[i] + b[i]) // 3 for i in range(3)),
                       tuple((a[i] + 2 * b[i]) // 3 for i in range(3)))
            else:
                pal = (a, b,
                       tuple((a[i] + b[i]) // 2 for i in range(3)),
                       (0, 0, 0))
            for sy in (0, 1):
                dy = by * 2 + sy
                for sx in (0, 1):
                    dx = bx * 2 + sx
                    k = (dy * ow + dx) * canaux
                    if point:
                        p = pal[(idx >> (2 * ((sy * 2) * 4 + sx * 2))) & 3]
                        if gris_seul:
                            out[k] = (p[0] + p[1] + p[2]) // 3
                        else:
                            out[k], out[k + 1], out[k + 2] = p
                        continue
                    # Les quatre texels du carre couvert par ce pixel.
                    r = v = bl = 0
                    for ty in (0, 1):
                        for tx in (0, 1):
                            q = pal[(idx >> (2 * ((sy * 2 + ty) * 4
                                                  + sx * 2 + tx))) & 3]
                            r += q[0]
                            v += q[1]
                            bl += q[2]
                    if gris_seul:
                        out[k] = (r + v + bl) // 12
                    else:
                        out[k] = r >> 2
                        out[k + 1] = v >> 2
                        out[k + 2] = bl >> 2
    return ow, oh, out


def accoler(moities, canaux):
    (lw, lh, lpx), (rw, rh, rpx) = moities
    W, H = lw + rw, max(lh, rh)
    out = bytearray(W * H * canaux)
    for y in range(H):
        d0 = y * W * canaux
        out[d0:d0 + lw * canaux] = lpx[y * lw * canaux:(y + 1) * lw * canaux]
        s = d0 + lw * canaux
        out[s:s + rw * canaux] = rpx[y * rw * canaux:(y + 1) * rw * canaux]
    return W, H, out


def lire_textures(point):
    jeu = pr3map.game()
    ar = pr3fuk.load(pr3map.orig(jeu, "data.fuk"))
    lire = lambda n: pr3fuk.content(ar, pr3fuk.find(ar, n))
    coul = [demi_dxt1(lire(n), False, point) for n in COULEUR]
    W, H, px = accoler(coul, 3)
    haut = [demi_dxt1(lire(n), True, point) for n in HAUTEUR]
    Wh, Hh, hz = accoler(haut, 1)
    ar["f"].close()
    if (W, H) != (Wh, Hh):
        raise SystemExit("couleur %dx%d et hauteurs %dx%d : rien ne serait cale"
                         % (W, H, Wh, Hh))
    return W, H, px, hz


def verifier(W, H, px):
    """Compare la couleur decodee au `carte_cuite.png` en place.

    C'est la garantie que le cadrage ne bouge pas. Les soixante ports sont cales
    sur CETTE image : un decalage d'un pixel ici les deplace tous.
    """
    chemin = os.path.join(RACINE, "carte_cuite.png")
    if not os.path.isfile(chemin):
        print("aucun carte_cuite.png en place : rien a comparer")
        return
    iw, ih, ipx = ci.lire_png(chemin)           # toujours rendu en RGBA
    print("en place %d x %d   decode %d x %d" % (iw, ih, W, H))
    if (iw, ih) != (W, H):
        print("   TAILLES DIFFERENTES : le cadrage NE serait PAS conserve")
        return
    ecart = n = exacts = 0
    for y in range(0, H, 3):
        for x in range(0, W, 3):
            s, d = (y * W + x) * 4, (y * W + x) * 3
            e = (abs(ipx[s] - px[d]) + abs(ipx[s + 1] - px[d + 1])
                 + abs(ipx[s + 2] - px[d + 2]))
            ecart += e
            exacts += 1 if e == 0 else 0
            n += 1
    part = 100.0 * exacts / n
    print("   ecart moyen %.2f / 765 sur %d points   (%.1f %% identiques)"
          % (float(ecart) / n, n, part))
    # LE VERDICT SUIT LA MESURE, il ne la precede pas. C'est la part de pixels
    # IDENTIQUES qui atteste le cadrage, jamais l'egalite des tailles : un
    # decalage d'un seul pixel l'effondrerait a presque rien sur une carte
    # peinte aussi detaillee, alors que les tailles, elles, concorderaient
    # toujours.
    if part > 99.0:
        print("   -> REPRODUCTION A L'IDENTIQUE : meme methode de reduction.")
    elif part > 20.0:
        print("   -> cadrage conserve, AUCUN decalage ; la reduction differe.")
        print("      (essayer l'autre reduction : --moyenne, ou son absence)")
    else:
        print("   -> SUSPECT : trop peu de pixels identiques pour affirmer que")
        print("      le cadrage est conserve. NE PAS ecraser la carte en l'etat.")


def pentes_terres(hz, W, H, pas=7):
    """Les pentes relevees sur la terre, et combien sont RIGOUREUSEMENT nulles.

    Les deux sont separes a dessein. La carte de hauteurs de PR3 est en grande
    partie faite de plateaux plats : une mediane calculee sur l'ensemble y tombe
    a zero, et tout calage qui s'appuierait dessus degenererait sans le dire.
    C'est exactement ce qui est arrive au premier jet de cet outil.
    """
    pentes, plats = [], 0
    for y in range(2, H - 2, pas):
        for x in range(2, W - 2, pas):
            i = y * W + x
            if hz[i] <= NIVEAU_MER:
                continue
            p = math.hypot(hz[i + 1] - hz[i - 1], hz[i + W] - hz[i - W])
            if p == 0.0:
                plats += 1
            else:
                pentes.append(p)
    pentes.sort()
    return pentes, plats


def sonder(hz, W, H):
    """Dit ce que contient vraiment la carte de hauteurs, sans rien ecrire."""
    mer = sum(1 for v in hz if v <= NIVEAU_MER)
    print("hauteurs : min %d, max %d   mer %.1f %%, terre %.1f %%"
          % (min(hz), max(hz), 100.0 * mer / len(hz),
             100.0 * (len(hz) - mer) / len(hz)))
    pentes, plats = pentes_terres(hz, W, H)
    n = len(pentes) + plats
    if n == 0:
        print("   aucune terre relevee")
        return
    print("   %d releves sur terre : %d plats (%.1f %%), %d en pente"
          % (n, plats, 100.0 * plats / n, len(pentes)))
    for q in (10, 25, 50, 75, 90, 99):
        if pentes:
            print("      centile %2d des pentes non nulles : %.1f"
                  % (q, pentes[min(len(pentes) - 1, q * len(pentes) // 100)]))


def calibrer(hz, W, H, force):
    """Le gain de pente, tire de la distribution REELLE -- ou un refus net."""
    pentes, plats = pentes_terres(hz, W, H)
    n = len(pentes) + plats
    if not pentes or len(pentes) * 4 < n:
        raise SystemExit(
            "REFUS : %d pentes non nulles sur %d releves de terre.\n"
            "  La carte de hauteurs est trop plate pour en tirer une echelle,\n"
            "  et un gain choisi au hasard ne serait pas un calage.\n"
            "  Relancer avec --sonder pour voir sa distribution."
            % (len(pentes), n))
    ref = pentes[min(len(pentes) - 1, CENTILE_REF * len(pentes) // 100)]
    gain = (CONTRASTE_REF * force) / ref
    print("   terre %.1f %% plate ; pente de reference (centile %d) %.1f"
          " -> gain %.4f" % (100.0 * plats / n, CENTILE_REF, ref, gain))
    return gain


def main():
    # Un texel sur deux PAR DEFAUT : c'est la reduction de l'assemblage
    # d'origine, verifiee identique au bit pres. `--moyenne` lisse a la place.
    point = "--moyenne" not in sys.argv
    force = (float(sys.argv[sys.argv.index("--force") + 1])
             if "--force" in sys.argv else 1.0)

    W, H, px, hz = lire_textures(point)
    print("assemble %d x %d  (reduction : %s)"
          % (W, H, "un texel sur deux" if point else "moyenne 2x2"))

    if "--verifier" in sys.argv:
        verifier(W, H, px)
        print("\n--verifier : rien n'a ete ecrit.")
        return

    if "--sonder" in sys.argv:
        sonder(hz, W, H)
        print("\n--sonder : rien n'a ete ecrit.")
        return

    gain = calibrer(hz, W, H, force)

    sx, sy, sz = VERS_SOLEIL
    ns = math.sqrt(sx * sx + sy * sy + sz * sz)
    sx, sy, sz = sx / ns, sy / ns, sz / ns

    sortie = bytearray(W * H * 3)
    terres = sombres = clairs = 0
    for y in range(H):
        y0 = (y - 1) * W if y > 0 else 0
        y1 = (y + 1) * W if y < H - 1 else (H - 1) * W
        base = y * W
        for x in range(W):
            i = base + x
            k = i * 3
            if hz[i] <= NIVEAU_MER:             # la mer : aucune ombre
                sortie[k] = px[k]
                sortie[k + 1] = px[k + 1]
                sortie[k + 2] = px[k + 2]
                continue
            terres += 1
            x0 = x - 1 if x > 0 else 0
            x1 = x + 1 if x < W - 1 else W - 1
            # Normale d'un champ de hauteur : (-dz/dx, -dz/dy, 1). L'axe y de
            # l'image descend vers le sud comme celui du monde : aucun signe a
            # retourner.
            nx = -(hz[base + x1] - hz[base + x0]) * gain
            ny = -(hz[y1 + x] - hz[y0 + x]) * gain
            n = math.sqrt(nx * nx + ny * ny + 1.0)
            # NORMALISE PAR LE CAS PLAT. Un terrain plat donne exactement 1,0 et
            # garde donc sa couleur peinte : seule la PENTE eclaircit ou
            # assombrit. Sans cette division, le plat valait 1,069 et toute la
            # terre de la carte se retrouvait eclaircie de 7 % -- ce qui n'est
            # plus un ombrage mais un virage de teinte.
            f = CIEL + (1.0 - CIEL) * max(0.0, (nx * sx + ny * sy + sz) / n) / sz
            if f < 0.98:
                sombres += 1
            elif f > 1.02:
                clairs += 1
            for c in range(3):
                v = int(px[k + c] * f)
                sortie[k + c] = 255 if v > 255 else v
    print("   terre %d px : %d assombris, %d eclaircis (%.0f %% modeles)"
          % (terres, sombres, clairs,
             100.0 * (sombres + clairs) / max(1, terres)))

    ci.ecrire_png(os.path.join(RACINE, "carte_cuite.png"), W, H, sortie, 3)
    print("carte_cuite.png : %d x %d, ombre" % (W, H))
    print()
    print("RELANCER ENSUITE : py -3 outils/carte_eau.py")
    print("   (il rend la mer du large a la nappe animee et recalcule mer_fond)")


if __name__ == "__main__":
    main()
