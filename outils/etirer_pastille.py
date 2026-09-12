"""Fabrique une texture etirable a partir d'un champ d'interface qui porte
deja du texte.

Les maquettes livrent les pastilles avec leur contenu grave : « 148 », « 39 »,
« Infos ville ». Les etirer en neuf tranches deformerait ces caracteres, puisque
la tranche centrale est justement celle qui les porte.

On garde donc les deux extremites intactes — ce sont elles qui font la forme —
et on remplace tout le milieu par une COLONNE UNIQUE prise dans une zone vide.
La texture obtenue s'etire alors sans rien deformer, et le texte se pose
par-dessus, en vrai.

La colonne propre est cherchee automatiquement : c'est celle qui ressemble le
plus a sa voisine, donc celle qui appartient a un aplat et non a un glyphe.

    py -3 etirer_pastille.py source.png sortie.png [--cap 34]

Affiche les marges de decoupe en neuf tranches a reporter dans le StyleBox.
Aucune dependance : bibliotheque standard uniquement.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from decouper_planche import lire_png, ecrire_png


def colonne_propre(w, h, px, cap):
    """x de la colonne la plus lisse, hors des deux extremites."""
    meilleur, score_min = cap, None
    for x in range(cap, w - cap - 1):
        s = 0
        for y in range(h):
            a = (y * w + x) * 4
            b = (y * w + x + 1) * 4
            for c in range(4):
                s += abs(px[a + c] - px[b + c])
        if score_min is None or s < score_min:
            score_min, meilleur = s, x
    return meilleur


def main():
    src, dst = sys.argv[1], sys.argv[2]
    cap = 34
    if '--cap' in sys.argv:
        cap = int(sys.argv[sys.argv.index('--cap') + 1])

    w, h, px = lire_png(src)

    # Certains champs portent un ornement HORS du cadre (un engrenage colle a
    # gauche ou a droite). Il fausserait les extremites : on recadre avant.
    if '--zone' in sys.argv:
        x0, lw0 = (int(v) for v in sys.argv[sys.argv.index('--zone') + 1].split(','))
        recadre = bytearray(lw0 * h * 4)
        for y in range(h):
            s0 = (y * w + x0) * 4
            recadre[y * lw0 * 4:(y + 1) * lw0 * 4] = px[s0:s0 + lw0 * 4]
        px, w = recadre, lw0

    cap = min(cap, (w - 4) // 2)
    xc = colonne_propre(w, h, px, cap)

    # Gauche + 2 colonnes propres + droite. Deux plutot qu'une : une tranche
    # centrale d'un seul pixel se fait ronger par le filtrage bilineaire.
    lw = cap + 2 + cap
    out = bytearray(lw * h * 4)
    for y in range(h):
        for x in range(cap):
            s = (y * w + x) * 4
            o = (y * lw + x) * 4
            out[o:o + 4] = px[s:s + 4]
        for k in range(2):
            s = (y * w + xc) * 4
            o = (y * lw + cap + k) * 4
            out[o:o + 4] = px[s:s + 4]
        for x in range(cap):
            s = (y * w + (w - cap + x)) * 4
            o = (y * lw + cap + 2 + x) * 4
            out[o:o + 4] = px[s:s + 4]

    ecrire_png(dst, lw, h, out)
    print("%s : %dx%d -> %dx%d   colonne propre x=%d" % (
        os.path.basename(src), w, h, lw, h, xc))
    print("   marges 9 tranches : gauche %d, droite %d, haut/bas %d"
          % (cap, cap, h // 3))


if __name__ == '__main__':
    main()
