"""Superpose un rendu de jeu et la maquette qu'il doit reproduire.

Le rendu part dans le canal ROUGE, la maquette dans le VERT. Ce qui coincide
vire au jaune ; tout decalage sort en franges rouges d'un cote et vertes de
l'autre. C'est la verification de calage classique, et elle se lit d'un coup
d'oeil la ou une comparaison cote a cote demande de faire des allers-retours.

    py -3 comparer_maquette.py rendu.png maquette.png sortie.png x,y,w,h

`x,y,w,h` est le rectangle du panneau DANS le rendu : on l'en extrait, on le
ramene aux dimensions de la maquette, puis on superpose.

Aucune dependance : bibliotheque standard uniquement.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from decouper_planche import lire_png, ecrire_png


def gris(px, i):
    o = i * 4
    return (px[o] * 299 + px[o + 1] * 587 + px[o + 2] * 114) // 1000


def main():
    rendu, maquette, dst = sys.argv[1], sys.argv[2], sys.argv[3]
    x0, y0, lw, lh = (int(v) for v in sys.argv[4].split(','))

    rw, rh, rp = lire_png(rendu)
    mw, mh, mp = lire_png(maquette)

    out = bytearray(mw * mh * 4)
    ecart = 0
    for y in range(mh):
        sy = y0 + y * lh // mh
        for x in range(mw):
            sx = x0 + x * lw // mw
            r = 0
            if 0 <= sx < rw and 0 <= sy < rh:
                r = gris(rp, sy * rw + sx)
            g = gris(mp, y * mw + x)
            o = (y * mw + x) * 4
            out[o] = r
            out[o + 1] = g
            out[o + 2] = 0
            out[o + 3] = 255
            ecart += abs(r - g)

    ecrire_png(dst, mw, mh, out)
    print("%s : ecart moyen %.1f / 255" % (os.path.basename(dst),
                                           ecart / float(mw * mh)))


if __name__ == '__main__':
    main()
