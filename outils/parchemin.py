"""Fabrique une feuille de parchemin repetable.

L'interieur des fenetres de Port Royale est du papier, pas du bois : un fond
creme tres clair, a peine marbre, sur lequel des pastilles portent les chiffres.
Aucun bitmap de ce papier n'existe dans les archives du jeu — les fenetres sont
dessinees en vectoriel. On le fabrique donc, avec du bruit a plusieurs echelles
et un tramage tres leger de fibres.

    py -3 parchemin.py sortie.png [--taille 512]

Aucune dependance : bibliotheque standard uniquement.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from decouper_planche import ecrire_png

CLAIR = (233, 221, 191)
SOMBRE = (206, 190, 156)


def hash21(x, y):
    n = math.sin(x * 127.1 + y * 311.7) * 43758.5453
    return n - math.floor(n)


def bruit(x, y, per):
    """Bruit de valeur PERIODIQUE : les bords se rejoignent, la feuille se
    repete donc sans couture."""
    x0, y0 = int(math.floor(x)), int(math.floor(y))
    fx, fy = x - x0, y - y0
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    v = 0.0
    for dy in (0, 1):
        for dx in (0, 1):
            h = hash21((x0 + dx) % per, (y0 + dy) % per)
            px = fx if dx else 1 - fx
            py = fy if dy else 1 - fy
            v += h * px * py
    return v


def main():
    dst = sys.argv[1]
    n = 512
    if '--taille' in sys.argv:
        n = int(sys.argv[sys.argv.index('--taille') + 1])

    out = bytearray(n * n * 4)
    for y in range(n):
        for x in range(n):
            u, v = x / float(n), y / float(n)
            # Trois octaves periodiques : les taches larges donnent le grain du
            # papier, les fines la fibre.
            t = (bruit(u * 4, v * 4, 4) * 0.55
                 + bruit(u * 11, v * 11, 11) * 0.30
                 + bruit(u * 29, v * 29, 29) * 0.15)
            t = min(1.0, max(0.0, (t - 0.32) * 2.1))
            o = (y * n + x) * 4
            for c in range(3):
                out[o + c] = int(CLAIR[c] + (SOMBRE[c] - CLAIR[c]) * t)
            out[o + 3] = 255
    ecrire_png(dst, n, n, out)
    print("%s : %d x %d" % (dst, n, n))


if __name__ == '__main__':
    main()
