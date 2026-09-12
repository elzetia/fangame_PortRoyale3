# Les textes de Port Royale 3, decodes depuis `data_fr.fuk`.
#
# C'est la source la plus fiable sur les regles du jeu : le tutoriel de PR3
# explique sa propre economie, chiffres compris. `sim/ECONOMIE_PR3.md` est ecrit
# a partir de ce que ce script sort.
#
# Le format s'appelle L10N :
#
#     0   "L10N"
#     4   version (0x102)
#     8   nombre d'entrees
#     12  longueur du blob
#     16  table : offset (4), longueur (4), hash (4), par entree
#
# Le piege : les offsets sont relatifs a l'octet 12, pas a la fin de l'en-tete.
# Cale sur 16, tout le texte sort decale de deux caracteres et on croit a un
# probleme d'encodage. Le texte lui-meme est de l'UTF-16-LE, et la longueur
# compte son terminateur.
#
# Les cles sont des hashs : il n'y a aucun nom lisible, on cherche donc par
# contenu.
#
#   py -3 outils/textes_pr3.py                      tout, vers textes_pr3.json
#   py -3 outils/textes_pr3.py "famine|prosperite"  ce qui correspond

import json
import os
import re
import struct
import sys

JEU = r"D:\GOG Galaxy\Games\Port Royale 3"
MOD = os.path.join(JEU, "_mod")          # unfuk.py y vit


def charger_res(archive=os.path.join(JEU, "data_fr.fuk"),
                dedans="ui/locale/frfr/global.res"):
    sys.path.insert(0, MOD)
    import unfuk
    f, entrees = unfuk.parse(archive)
    for e in entrees:
        if e["path"] == dedans:
            return unfuk.read(f, e)
    raise SystemExit(f"{dedans} introuvable dans {archive}")


def decoder(d):
    if d[:4] != b"L10N":
        raise SystemExit("ce n'est pas un fichier L10N")
    _ver, n, _blob = struct.unpack_from("<III", d, 4)
    textes = []
    for i in range(n):
        off, ln, h = struct.unpack_from("<III", d, 16 + i * 12)
        brut = d[12 + off:12 + off + ln]
        if len(brut) % 2:
            brut = brut[:-1]
        textes.append((h, brut.decode("utf-16-le", "replace").strip("\x00")))
    return textes


if __name__ == "__main__":
    textes = decoder(charger_res())
    print(f"{len(textes)} textes", file=sys.stderr)

    if len(sys.argv) > 1:
        motif = re.compile(sys.argv[1], re.I)
        for _h, s in textes:
            if motif.search(s):
                print("  " + s.replace("\n", "\\n"))
    else:
        sortie = os.path.join(os.path.dirname(__file__), "..", "textes_pr3.json")
        with open(sortie, "w", encoding="utf-8") as f:
            json.dump(textes, f, ensure_ascii=False, indent=1)
        print(f"-> {os.path.normpath(sortie)}", file=sys.stderr)
