"""Assemble les sprites decoupes en une planche-contact, dans l'ordre de la
fiche. Sert a identifier a l'oeil quel index correspond a quel motif avant de
trier une planche en familles.

    py -3 planche_contact.py <dossier> <sortie.png> [--colonnes 8] [--cellule 170]

Aucune dependance : bibliotheque standard uniquement.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from decouper_planche import lire_png, ecrire_png


def main():
    dossier, sortie = sys.argv[1], sys.argv[2]
    colonnes = 8
    cellule = 170
    if '--colonnes' in sys.argv:
        colonnes = int(sys.argv[sys.argv.index('--colonnes') + 1])
    if '--cellule' in sys.argv:
        cellule = int(sys.argv[sys.argv.index('--cellule') + 1])

    fiche = next(f for f in os.listdir(dossier)
                 if f.endswith('.json'))
    d = json.load(open(os.path.join(dossier, fiche), encoding='utf-8'))
    sprites = d['sprites']

    lignes = (len(sprites) + colonnes - 1) // colonnes
    W, H = colonnes * cellule, lignes * cellule
    out = bytearray(W * H * 4)
    # Damier : sans lui, on ne distingue pas un sprite sombre du fond.
    for y in range(H):
        for x in range(W):
            o = (y * W + x) * 4
            v = 70 if ((x // 16) + (y // 16)) % 2 else 95
            out[o] = out[o + 1] = out[o + 2] = v
            out[o + 3] = 255

    for n, sp in enumerate(sprites):
        w, h, px = lire_png(os.path.join(dossier, sp['fichier']))
        ech = min(1.0, (cellule - 12) / float(max(w, h)))
        nw, nh = max(1, int(w * ech)), max(1, int(h * ech))
        cx = (n % colonnes) * cellule + (cellule - nw) // 2
        cy = (n // colonnes) * cellule + (cellule - nh) // 2
        for y in range(nh):
            sy = int(y / ech)
            for x in range(nw):
                sx = int(x / ech)
                s = (sy * w + sx) * 4
                a = px[s + 3] / 255.0
                if a <= 0.01:
                    continue
                o = ((cy + y) * W + cx + x) * 4
                for k in range(3):
                    out[o + k] = int(px[s + k] * a + out[o + k] * (1 - a))

        # Reglette d'index : n batons de 3 px en haut a gauche de la case.
        bx = (n % colonnes) * cellule + 4
        by = (n // colonnes) * cellule + 4
        for j in range(n % 10 + 1):
            for y in range(6):
                for x in range(2):
                    o = ((by + y) * W + bx + j * 3 + x) * 4
                    out[o] = 255; out[o + 1] = 220; out[o + 2] = 0
        for j in range(n // 10):
            for y in range(6):
                for x in range(2):
                    o = ((by + 8 + y) * W + bx + j * 3 + x) * 4
                    out[o] = 60; out[o + 1] = 200; out[o + 2] = 255

    ecrire_png(sortie, W, H, out)
    print(f"{len(sprites)} sprites -> {sortie}  ({W}x{H})")


if __name__ == '__main__':
    main()
