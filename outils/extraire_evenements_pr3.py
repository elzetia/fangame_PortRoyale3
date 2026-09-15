# -*- coding: utf-8 -*-
"""Decoupe l'ATLAS D'EVENEMENTS de Port Royale 3 en icones nommees.

    py -3 outils/extraire_evenements_pr3.py

Ecrit dans `reference_pr3/ui/atlas_evenements/` un PNG de 128 x 128 par cellule
demandee, chargeable ensuite par `SkinPR3.texture("atlas_evenements/<nom>")`.

OU C'EST DANS LE JEU. `textures/0_icons.dds` de `data.fuk` : 1024 x 1024 en DXT5,
soit une grille de 8 x 8 cellules de 128 px dont 23 sont occupees (rangees 0 et 1
pleines, rangee 2 a sept). C'est l'atlas que le MOTEUR utilise pour les evenements
de ville -- a ne pas confondre avec `skinlib_pr3`, qui est la bibliotheque de
l'interface Flash.

POURQUOI CET OUTIL EXISTE. J'avais ecrit dans `scripts/carte2d.gd` qu'aucune icone
de SAUTERELLES n'existait, et pose a la place un parchemin generique
(`Visual_IconButton_Events`). C'etait faux : le criquet est ici, cellule (6,1).
L'erreur venait d'une recherche par NOM dans la table d'icones de l'interface,
alors que cet atlas n'est pas nomme -- ses cellules n'ont que des coordonnees.
Les effets `0_fx_locustsswarm1/2.dds` confirment d'ailleurs que les sauterelles
sont bien un fleau du jeu.

CE QUE CHAQUE CELLULE CONTIENT a ete VERIFIE EN LA REGARDANT, pas deduit de sa
voisine -- c'est la faute que ce projet m'a coutee plusieurs fois. Seules les
trois qui servent aujourd'hui sont donc nommees ; les autres attendent d'etre
regardees a leur tour.

L'art est celui de Port Royale 3 -- (c) Kalypso / Gaming Minds -- donc il ne peut
pas entrer dans un depot public : il vit dans `reference_pr3/`, ignore par git.
On versionne l'OUTIL, jamais sa sortie.

Aucune dependance : bibliotheque standard, plus `outils/dds2png.py` du projet.
"""
import os
import struct
import subprocess
import sys
import zlib

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PR3_MOD = r"D:\GOG Galaxy\Games\Port Royale 3\_mod\pr3"
sys.path.insert(0, PR3_MOD)

import pr3fuk                                    # noqa: E402
import pr3map                                    # noqa: E402

SOURCE = "textures/0_icons.dds"
SORTIE = os.path.join(RACINE, "reference_pr3", "ui", "atlas_evenements")
DDS2PNG = os.path.join(RACINE, "outils", "dds2png.py")
COTE = 128

# (colonne, rangee) -> nom. Les trois fleaux que la simulation connait.
CELLULES = {
    (2, 1): "peste",        # deux pestiferes encapuchonnes
    (4, 1): "feu",          # une flamme
    (6, 1): "sauterelles",  # un criquet vert
}


def lire_png(chemin):
    """Rend (largeur, hauteur, lignes RGBA). L'atlas sort de dds2png en RGBA8."""
    d = open(chemin, "rb").read()
    pos, idat = 8, b""
    w = h = ct = 0
    while pos < len(d):
        ln = struct.unpack(">I", d[pos:pos + 4])[0]
        typ = d[pos + 4:pos + 8]
        dat = d[pos + 8:pos + 8 + ln]
        if typ == b"IHDR":
            w, h, _bd, ct = struct.unpack(">IIBB", dat[:10])
        elif typ == b"IDAT":
            idat += dat
        pos += 12 + ln
    if ct != 6:
        raise ValueError("PNG inattendu : type de couleur %d, RGBA attendu" % ct)
    raw = zlib.decompress(idat)
    nc, st = 4, w * 4
    lignes, prec, i = [], bytearray(st), 0
    for _y in range(h):
        f = raw[i]; i += 1
        l = bytearray(raw[i:i + st]); i += st
        for x in range(st):
            a = l[x - nc] if x >= nc else 0
            b = prec[x]
            c = prec[x - nc] if x >= nc else 0
            if f == 1:
                l[x] = (l[x] + a) & 255
            elif f == 2:
                l[x] = (l[x] + b) & 255
            elif f == 3:
                l[x] = (l[x] + (a + b) // 2) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                l[x] = (l[x] + pr) & 255
        lignes.append(bytes(l)); prec = l
    return w, h, lignes


def ecrire_png(chemin, w, h, lignes):
    def bloc(typ, dd):
        c = typ + dd
        return struct.pack(">I", len(dd)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)
    brut = b"".join(b"\x00" + l for l in lignes)
    png = (b"\x89PNG\r\n\x1a\n"
           + bloc(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + bloc(b"IDAT", zlib.compress(brut, 9))
           + bloc(b"IEND", b""))
    open(chemin, "wb").write(png)


def main():
    os.makedirs(SORTIE, exist_ok=True)
    jeu = pr3map.game()
    ar = pr3fuk.load(pr3map.orig(jeu, "data.fuk"))
    e = ar["by_path"].get(SOURCE)
    if e is None:
        raise SystemExit("ABSENT de l'archive : %s" % SOURCE)
    d = pr3fuk.content(ar, e)
    ar["f"].close()

    h, w = struct.unpack_from("<2i", d, 12)
    print("%s : %d x %d %s" % (SOURCE, w, h, d[84:88].decode("latin1", "replace")))
    dds = os.path.join(SORTIE, "atlas.dds")
    png = os.path.join(SORTIE, "atlas.png")
    with open(dds, "wb") as f:
        f.write(d)
    subprocess.check_call([sys.executable, DDS2PNG, dds, png])

    lw, lh, lignes = lire_png(png)
    if lw != w or lh != h:
        raise SystemExit("le PNG converti fait %d x %d, pas %d x %d" % (lw, lh, w, h))

    for (gx, gy), nom in sorted(CELLULES.items()):
        cel = [lignes[y][gx * COTE * 4:(gx + 1) * COTE * 4]
               for y in range(gy * COTE, (gy + 1) * COTE)]
        # Un controle qui attrape une cellule VIDE : on aurait nomme du vent.
        vus = sum(1 for y in range(0, COTE, 4) for x in range(0, COTE, 4)
                  if cel[y][x * 4 + 3] > 40)
        part = 100 * vus // ((COTE // 4) ** 2)
        if part < 5:
            raise SystemExit("cellule (%d,%d) « %s » quasi vide (%d %%) : "
                             "la grille a bouge" % (gx, gy, nom, part))
        ecrire_png(os.path.join(SORTIE, nom + ".png"), COTE, COTE, cel)
        print("   %-14s cellule (%d,%d)  %d %% visible" % (nom, gx, gy, part))

    os.remove(dds)
    os.remove(png)
    print()
    print("ecrits dans %s" % SORTIE)
    print("`reference_pr3/` est ignore par git : cet art ne doit pas etre commite.")


if __name__ == "__main__":
    main()
