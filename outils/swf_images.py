"""Extrait les images d'un SWF Scaleform, sans dependance.

Port Royale 3 dessine toute son interface en Flash : les fonds de fenetre, les
cadres et les boutons sont des bitmaps enfermes dans les .swf de son dossier
ui/. Rien ne permet de les regarder autrement qu'en decodant le conteneur.

Balises traitees : DefineBitsLossless (20) et DefineBitsLossless2 (36), les
seules ou l'image est un simple bloc zlib. Les JPEG embarques (21, 35) sont
signales mais laisses de cote.

    py -3 swf_images.py fichier.swf dossier_sortie

Aucune dependance : bibliotheque standard uniquement.
"""
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from decouper_planche import ecrire_png


def decompresser(donnees):
    """Un SWF est CWS (zlib), ZWS (LZMA) ou FWS (brut). Seuls les huit premiers
    octets sont toujours en clair."""
    sig = donnees[:3]
    if sig == b'FWS':
        return donnees
    if sig == b'CWS':
        return donnees[:8] + zlib.decompress(donnees[8:])
    raise ValueError("signature %r non geree" % sig)


def sauter_rect(donnees, pos):
    """Le RECT du debut est un champ de bits, de longueur variable."""
    nbits = donnees[pos] >> 3
    total = 5 + 4 * nbits
    return pos + (total + 7) // 8


def balises(donnees, pos):
    while pos + 2 <= len(donnees):
        (entete,) = struct.unpack_from('<H', donnees, pos)
        pos += 2
        code = entete >> 6
        taille = entete & 0x3f
        if taille == 0x3f:
            (taille,) = struct.unpack_from('<I', donnees, pos)
            pos += 4
        if code == 0:
            return
        yield code, donnees[pos:pos + taille]
        pos += taille


def image_lossless(code, corps):
    """-> (id, largeur, hauteur, rgba) ou None"""
    ident, fmt, w, h = struct.unpack_from('<HBHH', corps, 0)
    pos = 7
    n_couleurs = 0
    if fmt == 3:
        n_couleurs = corps[pos] + 1
        pos += 1
    brut = zlib.decompress(corps[pos:])

    sortie = bytearray(w * h * 4)
    if fmt == 5:
        # ARGB premultiplie pour la balise 36, XRGB pour la 20.
        for i in range(w * h):
            a, r, g, b = brut[i * 4:i * 4 + 4]
            if code == 20:
                a = 255
            if a and a < 255:
                # Demultiplication : sans elle les bords antialiases sont noirs.
                r = min(255, r * 255 // a)
                g = min(255, g * 255 // a)
                b = min(255, b * 255 // a)
            o = i * 4
            sortie[o] = r; sortie[o + 1] = g; sortie[o + 2] = b; sortie[o + 3] = a
    elif fmt == 3:
        octets = 4 if code == 36 else 3
        palette = brut[:n_couleurs * octets]
        pas = ((w + 3) // 4) * 4          # lignes alignees sur 4 octets
        base = n_couleurs * octets
        for y in range(h):
            for x in range(w):
                idx = brut[base + y * pas + x]
                p = idx * octets
                o = (y * w + x) * 4
                sortie[o] = palette[p]
                sortie[o + 1] = palette[p + 1]
                sortie[o + 2] = palette[p + 2]
                sortie[o + 3] = palette[p + 3] if octets == 4 else 255
    else:
        return None
    return ident, w, h, sortie


def main():
    src, dst = sys.argv[1], sys.argv[2]
    donnees = decompresser(open(src, 'rb').read())
    pos = sauter_rect(donnees, 8)
    pos += 4                               # frame rate (2) + frame count (2)

    os.makedirs(dst, exist_ok=True)
    n = 0
    jpeg = 0
    for code, corps in balises(donnees, pos):
        if code in (20, 36):
            r = image_lossless(code, corps)
            if not r:
                continue
            ident, w, h, rgba = r
            nom = os.path.join(dst, "img_%03d_%dx%d.png" % (ident, w, h))
            ecrire_png(nom, w, h, rgba)
            print("  %s" % os.path.basename(nom))
            n += 1
        elif code in (21, 35, 6):
            jpeg += 1
    print("%d images extraites (%d JPEG ignores)" % (n, jpeg))


if __name__ == '__main__':
    main()
