"""Decoupe une maquette d'interface en elements nommes.

Une planche de sprites se decoupe par composantes connexes : chaque tache de
couleur sur fond uni devient un sprite. Une maquette d'INTERFACE, elle, est une
image composee — tout se touche, rien n'est isole. Il n'y a donc rien a
detecter : il faut dire ou couper.

Le manifeste JSON donne les rectangles, en pixels de la maquette :

    { "elements": { "bouton_fermer": [666, 32, 52, 52] },
      "grille":   { "lignes": 10, "haut": 280, "pas": 69.7,
                    "noms": ["bois", "briques", ...],
                    "colonnes": { "vignette": [57, 82], ... } } }

`grille` sert aux tableaux : une seule description vaut pour les dix lignes.

    py -3 decouper_ui.py maquette.png manifeste.json sortie/

Aucune dependance : bibliotheque standard uniquement.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from decouper_planche import lire_png, ecrire_png


def couper(w, h, px, x, y, lw, lh):
    x, y = max(0, int(x)), max(0, int(y))
    lw, lh = min(int(lw), w - x), min(int(lh), h - y)
    out = bytearray(lw * lh * 4)
    for j in range(lh):
        s = ((y + j) * w + x) * 4
        out[j * lw * 4:(j + 1) * lw * 4] = px[s:s + lw * 4]
    return lw, lh, out


def main():
    src, manif, dst = sys.argv[1], sys.argv[2], sys.argv[3]
    w, h, px = lire_png(src)
    d = json.load(open(manif, encoding='utf-8'))
    os.makedirs(dst, exist_ok=True)
    n = 0

    for nom, r in d.get('elements', {}).items():
        lw, lh, out = couper(w, h, px, r[0], r[1], r[2], r[3])
        ecrire_png(os.path.join(dst, nom + '.png'), lw, lh, out)
        print("  %-22s %dx%d" % (nom, lw, lh))
        n += 1

    g = d.get('grille')
    if g:
        for i in range(g['lignes']):
            y = g['haut'] + g['pas'] * i
            etiquette = g['noms'][i] if i < len(g['noms']) else "ligne%02d" % i
            for col, (cx, cw) in g['colonnes'].items():
                # Une seule colonne par nom suffit pour les fonds et les
                # cadres : on ne garde la premiere ligne que pour ceux-la.
                if col in g.get('une_seule', []) and i > 0:
                    continue
                lw, lh, out = couper(w, h, px, cx, y, cw, g['hauteur'])
                base = ("%s_%s" % (col, etiquette)) if col not in g.get('une_seule', []) else col
                ecrire_png(os.path.join(dst, base + '.png'), lw, lh, out)
                print("  %-22s %dx%d" % (base, lw, lh))
                n += 1

    print("%d elements -> %s" % (n, dst))


if __name__ == '__main__':
    main()
