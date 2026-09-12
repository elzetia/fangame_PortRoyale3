"""Convertit les textures DDS de Port Royale 3 en PNG.

Gere BC1 (DXT1) et BC3 (DXT5), les deux seuls formats utilises par le jeu pour
la carte, le cadre et les atlas d'icones. Aucune dependance : la bibliotheque
standard suffit, comme le reste de l'outillage PR3.

    py -3 dds2png.py entree.dds sortie.png [--reduire N]

`--reduire N` ecrit en plus une version reduite d'un facteur N, pour pouvoir
regarder une texture de 4096 px sans ouvrir 64 Mo.
"""
import struct
import sys
import zlib


# --- ecriture PNG ------------------------------------------------------------

def ecrire_png(chemin, w, h, rgba):
    """rgba : bytes de longueur w*h*4."""
    brut = bytearray()
    for y in range(h):
        brut.append(0)                       # filtre None
        brut += rgba[y * w * 4:(y + 1) * w * 4]

    def bloc(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)

    with open(chemin, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(bloc(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)))
        f.write(bloc(b'IDAT', zlib.compress(bytes(brut), 6)))
        f.write(bloc(b'IEND', b''))


# --- decodage des blocs ------------------------------------------------------

def _couleurs_bc1(c0, c1):
    """Les quatre couleurs d'un bloc, depuis deux valeurs RGB565."""
    def etendre(c):
        r = (c >> 11) & 0x1f
        g = (c >> 5) & 0x3f
        b = c & 0x1f
        return ((r * 527 + 23) >> 6, (g * 259 + 33) >> 6, (b * 527 + 23) >> 6)

    a, b = etendre(c0), etendre(c1)
    if c0 > c1:
        # Quatre couleurs opaques
        return (a, b,
                tuple((2 * a[i] + b[i]) // 3 for i in range(3)),
                tuple((a[i] + 2 * b[i]) // 3 for i in range(3)))
    # Trois couleurs, la quatrieme est transparente
    return (a, b,
            tuple((a[i] + b[i]) // 2 for i in range(3)),
            (0, 0, 0))


def _alphas_bc3(a0, a1):
    if a0 > a1:
        return [a0, a1] + [((7 - i) * a0 + i * a1) // 7 for i in range(1, 7)]
    return ([a0, a1] + [((5 - i) * a0 + i * a1) // 5 for i in range(1, 5)]
            + [0, 255])


def decoder(donnees, w, h, fourcc):
    """Renvoie un bytearray RGBA de w*h*4."""
    sortie = bytearray(w * h * 4)
    bw, bh = (w + 3) // 4, (h + 3) // 4
    taille_bloc = 8 if fourcc == b'DXT1' else 16
    pos = 0

    for by in range(bh):
        for bx in range(bw):
            bloc = donnees[pos:pos + taille_bloc]
            pos += taille_bloc

            if fourcc == b'DXT1':
                c0, c1, idx = struct.unpack('<HHI', bloc)
                alphas = None
            else:
                a0, a1 = bloc[0], bloc[1]
                bits_a = int.from_bytes(bloc[2:8], 'little')
                alphas = _alphas_bc3(a0, a1)
                c0, c1, idx = struct.unpack('<HHI', bloc[8:16])

            palette = _couleurs_bc1(c0, c1)
            transparent = (fourcc == b'DXT1' and c0 <= c1)

            for py in range(4):
                y = by * 4 + py
                if y >= h:
                    break
                ligne = y * w * 4
                for px in range(4):
                    x = bx * 4 + px
                    if x >= w:
                        break
                    i = py * 4 + px
                    code = (idx >> (2 * i)) & 3
                    r, g, b = palette[code]
                    if alphas is not None:
                        a = alphas[(bits_a >> (3 * i)) & 7]
                    else:
                        a = 0 if (transparent and code == 3) else 255
                    o = ligne + x * 4
                    sortie[o] = r
                    sortie[o + 1] = g
                    sortie[o + 2] = b
                    sortie[o + 3] = a
    return sortie


def lire_dds(chemin):
    """-> (largeur, hauteur, fourcc, rgba)"""
    with open(chemin, 'rb') as f:
        entete = f.read(128)
        if entete[:4] != b'DDS ':
            raise ValueError(f"{chemin} n'est pas un DDS")
        h, w = struct.unpack('<2I', entete[12:20])
        fourcc = entete[84:88]
        if fourcc not in (b'DXT1', b'DXT5'):
            raise ValueError(f"format non gere : {fourcc!r}")
        # Seul le niveau 0 nous interesse ; les mips suivent mais on les ignore.
        octets = ((w + 3) // 4) * ((h + 3) // 4) * (8 if fourcc == b'DXT1' else 16)
        donnees = f.read(octets)
    return w, h, fourcc, decoder(donnees, w, h, fourcc)


def reduire(w, h, rgba, facteur):
    """Sous-echantillonnage par moyenne de blocs facteur x facteur."""
    nw, nh = w // facteur, h // facteur
    sortie = bytearray(nw * nh * 4)
    n = facteur * facteur
    for y in range(nh):
        for x in range(nw):
            r = g = b = a = 0
            for dy in range(facteur):
                ligne = ((y * facteur + dy) * w + x * facteur) * 4
                for dx in range(facteur):
                    o = ligne + dx * 4
                    r += rgba[o]
                    g += rgba[o + 1]
                    b += rgba[o + 2]
                    a += rgba[o + 3]
            o = (y * nw + x) * 4
            sortie[o] = r // n
            sortie[o + 1] = g // n
            sortie[o + 2] = b // n
            sortie[o + 3] = a // n
    return nw, nh, sortie


if __name__ == '__main__':
    src, dst = sys.argv[1], sys.argv[2]
    w, h, fourcc, rgba = lire_dds(src)
    print(f"{src} : {w}x{h} {fourcc.decode()}")
    ecrire_png(dst, w, h, rgba)
    print(f"  -> {dst}")
    if '--reduire' in sys.argv:
        f = int(sys.argv[sys.argv.index('--reduire') + 1])
        nw, nh, petit = reduire(w, h, rgba, f)
        apercu = dst.replace('.png', f'_apercu.png')
        ecrire_png(apercu, nw, nh, petit)
        print(f"  -> {apercu} ({nw}x{nh})")
