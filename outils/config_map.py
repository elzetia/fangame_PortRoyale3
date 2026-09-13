# Le dictionnaire complet des réglages de Port Royale 3.
#
# PR3 lit tous ses réglages par cinq fonctions de chargement, chacune prenant une
# SECTION, une CLÉ et une valeur PAR DÉFAUT :
#
#     0x89D6E0  entier            0x89D8A0  tableau de flottants
#     0x89D750  flottant          0x89E270  chaîne
#     0x89D7C0  tableau d'entiers
#
# En balayant l'exécutable pour tous les appels à ces fonctions et en remontant
# les deux chaînes poussées juste avant (clé puis section), on obtient la liste
# de tout ce que le jeu sait régler : 134 sections, 421 clés. C'est la carte de
# `outils/PR3_SYSTEMES.md`.
#
#   py -3 outils/config_map.py
#
# Comme les autres outils, il lit ta propre copie de PortRoyale3.exe et ne commit
# rien.

import os
import re
import struct
from capstone import Cs, CS_ARCH_X86, CS_MODE_32

JEU = r"D:\GOG Galaxy\Games\Port Royale 3"
exe = open(os.path.join(JEU, "PortRoyale3.exe"), "rb").read()

# (adresse virtuelle, décalage fichier, taille) des sections utiles.
SECTIONS = [(0x401000, 0x400, 0x736000), (0xB38000, 0x736600, 0x86400),
            (0xBBF000, 0x7bca00, 0x44800)]
TV, TF, TT = SECTIONS[0]
text = exe[TF:TF + TT]
md = Cs(CS_ARCH_X86, CS_MODE_32)

READERS = {0x89d6e0: "int", 0x89d750: "flt", 0x89d7c0: "i[]",
           0x89d8a0: "f[]", 0x89e270: "str"}


def chaine(va):
    for v, f, t in SECTIONS:
        if v <= va < v + t:
            m = re.match(rb"[\x20-\x7e]{1,80}\x00", exe[f + va - v:f + va - v + 96])
            return m.group()[:-1].decode() if m else None
    return None


def collecter():
    pairs = {}
    for i in range(len(text) - 5):
        if text[i] != 0xE8:
            continue
        cible = TV + i + 5 + struct.unpack_from("<i", text, i + 1)[0]
        if cible not in READERS:
            continue
        # Remonter ~48 octets et décoder vers l'avant jusqu'à l'appel : on garde
        # les offsets poussés qui pointent une chaîne.
        a = TV + i - 48
        pousses = []
        for ins in md.disasm(exe[TF + (a - TV):TF + (a - TV) + 64], a):
            if ins.address >= TV + i:
                break
            if ins.mnemonic == "push":
                m = re.match(r"0x([0-9a-f]+)$", ins.op_str)
                if m:
                    s = chaine(int(m.group(1), 16))
                    if s is not None:
                        pousses.append(s)
        if len(pousses) >= 2:
            # Ordre poussé : défaut, clé, section — donc section = -1, clé = -2.
            section, cle = pousses[-1], pousses[-2]
            pairs.setdefault(section, {}).setdefault(cle, READERS[cible])
    return pairs


def main():
    pairs = collecter()
    total = sum(len(v) for v in pairs.values())
    print(f"== {len(pairs)} sections, {total} cles\n")
    for sec in sorted(pairs, key=lambda s: (-len(pairs[s]), s)):
        ks = pairs[sec]
        print(f"[{sec}]  ({len(ks)})")
        print("   " + ", ".join(f"{k}:{t}" for k, t in ks.items()))


if __name__ == "__main__":
    main()
