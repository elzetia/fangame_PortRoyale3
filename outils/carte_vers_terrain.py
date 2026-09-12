"""Derive le masque de terre d'une carte illustree, et en fait une grille de
navigation pour la simulation.

Quand la carte devient une image dessinee, ce n'est plus la geometrie qui donne
les cotes : il faut les LIRE dans l'image, sinon le navire traverserait la terre
et contournerait de l'eau. Cet outil est ce pont-la.

    py -3 carte_vers_terrain.py assets_generes/carte_iles.png sim/terrain.lua \\
        --largeur-monde 3600 --cellule 14

Ecrit un module Lua contenant la grille et sa correspondance avec le monde.
Aucune dependance : bibliotheque standard uniquement.
"""
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from decouper_planche import lire_png, ecrire_png


def masque_eau(w, h, px):
    """L'eau est bleue : son canal bleu domine nettement le rouge.

    Le sable (r > g > b), la jungle (vert dominant) et la roche (canaux
    proches) ne remplissent jamais ce critere.
    """
    eau = bytearray(w * h)
    for i in range(w * h):
        o = i * 4
        if px[o + 2] > px[o] * 1.15:
            eau[i] = 1
    return eau


def ocean_depuis_le_bord(w, h, eau):
    """Remplissage depuis les bords : seule l'eau reliee au large compte.

    Sans cette etape, les ombres de jungle et les lagons interieurs restent
    classes en eau, et le calcul de route croirait pouvoir y faire naviguer
    un trois-mats.
    """
    ocean = bytearray(w * h)
    file = collections.deque()
    for x in range(w):
        for y in (0, h - 1):
            i = y * w + x
            if eau[i] and not ocean[i]:
                ocean[i] = 1
                file.append(i)
    for y in range(h):
        for x in (0, w - 1):
            i = y * w + x
            if eau[i] and not ocean[i]:
                ocean[i] = 1
                file.append(i)

    while file:
        i = file.popleft()
        x, y = i % w, i // w
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h:
                j = ny * w + nx
                if eau[j] and not ocean[j]:
                    ocean[j] = 1
                    file.append(j)
    return ocean


def vers_grille(w, h, terre, colonnes, lignes, seuil=0.35):
    """Sous-echantillonne le masque pixel en cases de navigation."""
    grille = bytearray(colonnes * lignes)
    for cy in range(lignes):
        y0 = cy * h // lignes
        y1 = max(y0 + 1, (cy + 1) * h // lignes)
        for cx in range(colonnes):
            x0 = cx * w // colonnes
            x1 = max(x0 + 1, (cx + 1) * w // colonnes)
            n = 0
            total = 0
            for y in range(y0, y1):
                base = y * w
                for x in range(x0, x1):
                    total += 1
                    n += terre[base + x]
            # Une case compte comme terre des qu'elle en contient assez : mieux
            # vaut une cote un peu large qu'un navire qui rase les rochers.
            grille[cy * colonnes + cx] = 1 if total and n / total >= seuil else 0
    return grille


def dilater(grille, colonnes, lignes, passes=1):
    """Marge de securite : on epaissit la terre d'une case."""
    for _ in range(passes):
        copie = bytearray(grille)
        for y in range(lignes):
            for x in range(colonnes):
                if copie[y * colonnes + x]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < colonnes and 0 <= ny < lignes and copie[ny * colonnes + nx]:
                        grille[y * colonnes + x] = 1
                        break
    return grille


def main():
    src, dst = sys.argv[1], sys.argv[2]
    largeur_monde = 3600.0
    cellule = 14.0
    if '--largeur-monde' in sys.argv:
        largeur_monde = float(sys.argv[sys.argv.index('--largeur-monde') + 1])
    if '--cellule' in sys.argv:
        cellule = float(sys.argv[sys.argv.index('--cellule') + 1])

    w, h, px = lire_png(src)
    metres_par_pixel = largeur_monde / w
    hauteur_monde = h * metres_par_pixel
    colonnes = max(1, int(round(largeur_monde / cellule)))
    lignes = max(1, int(round(hauteur_monde / cellule)))

    print(f"{src} : {w}x{h}")
    print(f"  monde  : {largeur_monde:.0f} x {hauteur_monde:.0f} m"
          f"  ({metres_par_pixel:.2f} m/pixel)")
    print(f"  grille : {colonnes} x {lignes} cases de {cellule:.0f} m")

    eau = masque_eau(w, h, px)
    ocean = ocean_depuis_le_bord(w, h, eau)
    terre = bytearray(1 if not ocean[i] else 0 for i in range(w * h))
    print(f"  terre  : {100 * sum(terre) / (w * h):.1f} % de l'image")

    grille = dilater(vers_grille(w, h, terre, colonnes, lignes), colonnes, lignes)
    print(f"  cases de terre : {100 * sum(grille) / len(grille):.1f} %")

    lignes_lua = [
        "-- Grille de navigation, DERIVEE de la carte illustree.",
        "-- Genere par outils/carte_vers_terrain.py : ne pas editer a la main.",
        "-- '#' = terre, '.' = eau. L'origine est au centre du monde.",
        "",
        "local Terrain = {}",
        "",
        f"Terrain.colonnes = {colonnes}",
        f"Terrain.lignes = {lignes}",
        f"Terrain.cellule = {cellule}",
        f"Terrain.largeur_monde = {largeur_monde}",
        f"Terrain.hauteur_monde = {hauteur_monde:.1f}",
        f"Terrain.image = {{ {w}, {h} }}",
        "",
        "Terrain.cases = {",
    ]
    for cy in range(lignes):
        rangee = "".join('#' if grille[cy * colonnes + cx] else '.'
                         for cx in range(colonnes))
        lignes_lua.append(f'  "{rangee}",')
    lignes_lua += ["}", "", "return Terrain", ""]

    with open(dst, 'w', encoding='utf-8', newline='\n') as f:
        f.write("\n".join(lignes_lua))
    print(f"  -> {dst}")

    apercu = bytearray(w * h * 4)
    for i in range(w * h):
        o = i * 4
        v = 235 if terre[i] else 34
        apercu[o] = v
        apercu[o + 1] = v
        apercu[o + 2] = v if terre[i] else 78
        apercu[o + 3] = 255
    chemin = os.path.splitext(dst)[0] + "_apercu.png"
    ecrire_png(chemin, w, h, apercu)
    print(f"  -> {chemin}")


if __name__ == '__main__':
    main()
