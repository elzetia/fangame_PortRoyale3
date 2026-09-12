"""Fabrique un panneau de bois sans couture a partir d'une seule planche.

Port Royale 3 n'a pas de fond de fenetre en bitmap : ses panneaux sont dessines
en vectoriel, et la seule matiere qu'on puisse recuperer de ses .swf est UNE
planche de 424 x 126. La repeter telle quelle donne un damier : chaque bord
apparait, et la fenetre se decoupe en carreaux.

On la reflechit donc horizontalement — un bord colle alors a son propre miroir,
donc a lui-meme — puis on empile les rangees en les decalant les unes par
rapport aux autres, comme un vrai lambris. Un joint sombre marque chaque
rangee : c'est lui qui fait lire des planches plutot qu'un aplat de bois.

    py -3 bois_panneau.py sprites/interface/bois.png sortie.png [--largeur 1700] [--hauteur 820]

Aucune dependance : bibliotheque standard uniquement.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from decouper_planche import lire_png, ecrire_png

# Le joint n'est pas un trait noir mais un petit degrade : une ombre qui
# s'approfondit, puis un rehaut. Un trait franc coupait les lignes de texte
# posees dessus et transformait le panneau en palissade.
JOINT = [0.80, 0.66, 0.58, 0.74, 1.10]
DECALAGES = [0, 173, 61, 291, 118, 233, 37]   # premiers nombres sans motif
ECHELLE = 1.7           # planches plus hautes = moins de joints en travers


def main():
    src, dst = sys.argv[1], sys.argv[2]
    largeur, hauteur = 1700, 820
    if '--largeur' in sys.argv:
        largeur = int(sys.argv[sys.argv.index('--largeur') + 1])
    if '--hauteur' in sys.argv:
        hauteur = int(sys.argv[sys.argv.index('--hauteur') + 1])

    w0, h0, px0 = lire_png(src)
    # Agrandissement au plus proche : le fil du bois supporte tres bien d'etre
    # grossi, et cela espace les joints.
    w, h = int(w0 * ECHELLE), int(h0 * ECHELLE)
    px = bytearray(w * h * 4)
    for y in range(h):
        sy = min(h0 - 1, int(y / ECHELLE))
        for x in range(w):
            sx = min(w0 - 1, int(x / ECHELLE))
            s0 = (sy * w0 + sx) * 4
            o0 = (y * w + x) * 4
            px[o0:o0 + 4] = px0[s0:s0 + 4]
    # Bande miroir : sa largeur est 2w, et son bord droit est identique a son
    # bord gauche, ce qui la rend repetable sans couture visible.
    bw = w * 2
    bande = bytearray(bw * h * 4)
    for y in range(h):
        for x in range(bw):
            sx = x if x < w else (bw - 1 - x)
            s = (y * w + sx) * 4
            o = (y * bw + x) * 4
            bande[o:o + 4] = px[s:s + 4]

    out = bytearray(largeur * hauteur * 4)
    rangee = 0
    y0 = 0
    while y0 < hauteur:
        dec = DECALAGES[rangee % len(DECALAGES)]
        for y in range(h):
            gy = y0 + y
            if gy >= hauteur:
                break
            for x in range(largeur):
                sx = (x + dec) % bw
                s = (y * bw + sx) * 4
                o = (gy * largeur + x) * 4
                out[o] = bande[s]
                out[o + 1] = bande[s + 1]
                out[o + 2] = bande[s + 2]
                out[o + 3] = 255
        # Joint : une ombre qui s'approfondit puis un rehaut, jamais un trait.
        for j, f in enumerate(JOINT):
            gy = y0 + h + j
            if gy >= hauteur:
                break
            for x in range(largeur):
                o = (gy * largeur + x) * 4
                s = ((h - 1) * bw + (x + dec) % bw) * 4
                out[o] = min(255, int(bande[s] * f))
                out[o + 1] = min(255, int(bande[s + 1] * f))
                out[o + 2] = min(255, int(bande[s + 2] * f))
                out[o + 3] = 255
        y0 += h + len(JOINT)
        rangee += 1

    ecrire_png(dst, largeur, hauteur, out)
    print("%s : %d x %d, %d rangees" % (dst, largeur, hauteur, rangee))


if __name__ == '__main__':
    main()
