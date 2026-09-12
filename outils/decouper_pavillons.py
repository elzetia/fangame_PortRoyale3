# -*- coding: utf-8 -*-
"""Detoure les pavillons de la planche fournie et les range en sprites.

    py outils/decouper_pavillons.py <planche.png>

La planche est une grille de 3 x 2 pavillons sur fond noir. Le detourage ne se
fait PAS par seuil de luminance : le bleu de la France est presque aussi sombre
que le fond, et un seuil le trouerait. On remplit depuis les BORDS de chaque
case -- tout ce qui est noir ET relie au bord est du fond, tout ce qui est noir
mais enferme dans le pavillon est du pavillon. C'est la seule facon de garder
une ombre portee interieure et un champ d'azur.

Les ombres portees, elles, disparaissent avec le fond : sur la carte, le
`Pavillon` pose deja son propre lisere, et une ombre peinte dans la vignette
contredirait celle du terrain des qu'on la tournerait.
"""
import io
import os
import struct
import sys
import zlib
from collections import deque

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(RACINE, "outils"))

from decouper_planche import lire_png, ecrire_png   # noqa: E402

NL = chr(10)

# L'ordre de lecture de la planche, de gauche a droite puis de haut en bas.
# La case 4 est un doublon de la France : on la saute.
CASES = [
    (0, 0, "portugal"),
    (1, 0, "espagne"),
    (2, 0, "hollande"),
    (0, 1, "france"),
    (1, 1, None),
    (2, 1, "angleterre"),
]

COLONNES, LIGNES = 3, 2
SEUIL_FOND = 34          # en dessous de cette luminance, c'est peut-etre le fond


def detourer(px, w, h):
    """Alpha par remplissage depuis les bords : renvoie un bytearray RGBA."""
    fond = bytearray(w * h)
    file = deque()

    def sombre(i):
        r, v, b = px[i * 4], px[i * 4 + 1], px[i * 4 + 2]
        return max(r, v, b) <= SEUIL_FOND

    for x in range(w):
        for y in (0, h - 1):
            i = y * w + x
            if not fond[i] and sombre(i):
                fond[i] = 1
                file.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            i = y * w + x
            if not fond[i] and sombre(i):
                fond[i] = 1
                file.append((x, y))

    while file:
        x, y = file.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            u, v = x + dx, y + dy
            if 0 <= u < w and 0 <= v < h:
                i = v * w + u
                if not fond[i] and sombre(i):
                    fond[i] = 1
                    file.append((u, v))

    out = bytearray(px)
    for i in range(w * h):
        out[i * 4 + 3] = 0 if fond[i] else 255
    return out


def rogner(px, w, h):
    """Reduit au rectangle des pixels opaques."""
    x0, y0, x1, y1 = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            if px[(y * w + x) * 4 + 3]:
                if x < x0: x0 = x
                if x > x1: x1 = x
                if y < y0: y0 = y
                if y > y1: y1 = y
    if x1 < x0:
        return px, w, h
    nw, nh = x1 - x0 + 1, y1 - y0 + 1
    out = bytearray(nw * nh * 4)
    for y in range(nh):
        d = y * nw * 4
        s = ((y0 + y) * w + x0) * 4
        out[d:d + nw * 4] = px[s:s + nw * 4]
    return out, nw, nh


def main(chemin):
    w, h, px = lire_png(chemin)
    print("planche %d x %d" % (w, h))
    cw, ch = w // COLONNES, h // LIGNES
    dossier = os.path.join(RACINE, "sprites", "pavillons")
    if not os.path.isdir(dossier):
        os.makedirs(dossier)

    fiche = {}
    for cx, cy, nom in CASES:
        if nom is None:
            continue
        cellule = bytearray(cw * ch * 4)
        for y in range(ch):
            d = y * cw * 4
            s = ((cy * ch + y) * w + cx * cw) * 4
            cellule[d:d + cw * 4] = px[s:s + cw * 4]
        detoure = detourer(cellule, cw, ch)
        rogne, rw, rh = rogner(detoure, cw, ch)
        ecrire_png(os.path.join(dossier, nom + ".png"), rw, rh, bytes(rogne))
        opaques = sum(1 for i in range(rw * rh) if rogne[i * 4 + 3])
        fiche[nom] = (rw, rh)
        print("  %-11s %3d x %-3d  %5.1f %% opaque" % (nom, rw, rh, 100.0 * opaques / (rw * rh)))

    io.open(os.path.join(dossier, "pavillons.json"), "w",
            encoding="utf-8", newline=NL).write(NL.join([
        "{",
        '\t"source": "flags.png",',
        '\t"note": "Pavillons fournis, detoures par outils/decouper_pavillons.py.",',
        '\t"sprites": [',
    ] + [
        '\t\t{ "nation": "%s", "fichier": "%s.png", "largeur": %d, "hauteur": %d }%s'
        % (n, n, fiche[n][0], fiche[n][1], "," if k < len(fiche) - 1 else "")
        for k, n in enumerate(fiche)
    ] + [
        "\t]",
        "}",
        "",
    ]))
    print("fiche ecrite")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1
         else os.path.join(os.path.expanduser("~"), "Downloads", "flags.png"))
