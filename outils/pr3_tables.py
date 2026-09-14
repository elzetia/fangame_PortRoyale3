# -*- coding: utf-8 -*-
"""Les TABLES DE SAUTS de Port Royale 3 — c'est-a-dire ses enumerations.

POURQUOI CET OUTIL EXISTE. Un `switch` dense compile par MSVC devient une table
d'adresses indexee par la valeur testee. Cette table est la trace la plus fidele
qui subsiste d'une ENUMERATION du jeu : son nombre de cas donne le nombre de
valeurs, et l'ordre des cas est l'ordre de l'enumere.

C'est ce qui a permis, cette session, de comprendre que la creation d'un marchand
IA passe par une FABRIQUE indexee par numero (`0x007751B0`, case 1) — et donc que
le nombre de marchands ne se trouverait pas en remontant les appels. Ce releve
etait manuel. Ici il est systematique.

LES DEUX FORMES, toutes deux reconnues :

  * DIRECTE     cmp reg, N ; ja defaut ; jmp dword ptr [reg*4 + TABLE]
  * INDEXEE     cmp reg, N ; ja defaut
                movzx reg, byte ptr [reg + INDEX] ; jmp dword ptr [reg*4 + TABLE]

    La seconde est employee quand plusieurs valeurs partagent le meme cas : la
    table INDEX (un octet par valeur) renvoie vers une table d'adresses plus
    courte. Lire la table d'adresses sans la table d'index ferait croire a moins
    de cas qu'il n'y en a — c'est le piege principal de ce releve.

ANCRAGE SUR LES OCTETS, pas sur un desassemblage lineaire : `jmp dword ptr
[reg*4 + disp32]` s'encode `FF 24 <SIB> <disp32>` avec un SIB d'echelle 4 et une
base « disp32 » (SIB & 0xC7 == 0x85). On ne cherche donc aucun debut de fonction
— cette heuristique s'est trompee trois fois dans la meme session.

AUTO-TEST. Un balayage qui ne se prouve pas sur un positif connu ne permet de
conclure aucun negatif. Le temoin est la fabrique de commandes : site
`0x007751C2`, table `0x00776290`, borne `0x7F`, case 1 -> `0x007751EB`.

Rien n'est copie dans le depot : l'outil lit l'installation locale du joueur.

    py -3 outils/pr3_tables.py
    py -3 outils/pr3_tables.py --site 0x007751C2
    py -3 outils/pr3_tables.py --min 8 --csv
"""
import struct
import sys

try:
    from capstone import Cs, CS_ARCH_X86, CS_MODE_32
except ImportError:                                    # pragma: no cover
    raise SystemExit("capstone est requis : py -3 -m pip install capstone")

EXE = r"D:\GOG Galaxy\Games\Port Royale 3\PortRoyale3.exe"

SECTIONS = [(0x401000, 0x400, 0x736000),
            (0xB38000, 0x736600, 0x86400),
            (0xBBF000, 0x7bca00, 0x44800)]

TEMOIN = dict(site=0x007751C2, table=0x00776290, borne=0x7F,
              cas=1, cible=0x007751EB)


class Image:
    def __init__(self):
        with open(EXE, "rb") as f:
            self.exe = f.read()
        self.tv, self.tf, self.tt = SECTIONS[0]
        self.text = self.exe[self.tf:self.tf + self.tt]
        self.md = Cs(CS_ARCH_X86, CS_MODE_32)

    def lire(self, va, n):
        for v, f, t in SECTIONS:
            if v <= va < v + t:
                o = f + va - v
                return self.exe[o:o + n]
        return b""

    def dword(self, va):
        d = self.lire(va, 4)
        return struct.unpack("<I", d)[0] if len(d) == 4 else None

    def dans_code(self, va):
        return self.tv <= va < self.tv + self.tt

    def aligner(self, cible, recul=0x40):
        """Le depart le plus lointain dont le flux retombe EXACTEMENT sur `cible`."""
        for d in range(recul, 3, -1):
            dep = cible - d
            for ins in self.md.disasm(self.lire(dep, d + 16), dep):
                if ins.address == cible:
                    return dep
                if ins.address > cible:
                    break
        return cible


def sauts(img):
    """Tous les `jmp dword ptr [reg*4 + disp32]` : [(site, table)]."""
    out, text, tv = [], img.text, img.tv
    i = text.find(b"\xff\x24")
    while i != -1 and i + 7 <= len(text):
        sib = text[i + 2]
        if (sib & 0xC7) == 0x85:                       # echelle 4, base disp32
            table = struct.unpack_from("<I", text, i + 3)[0]
            if img.dans_code(table) or 0xB38000 <= table < 0xC04000:
                out.append((tv + i, table))
        i = text.find(b"\xff\x24", i + 1)
    return out


def contexte(img, site):
    """(borne, table_index) lus dans les instructions qui precedent le saut."""
    dep = img.aligner(site, 0x40)
    borne = index = None
    for ins in img.md.disasm(img.lire(dep, (site - dep) + 16), dep):
        if ins.address > site:
            break
        if ins.mnemonic == "cmp" and "," in ins.op_str:
            d = ins.op_str.rsplit(",", 1)[1].strip()
            try:
                v = int(d, 0)
                if 0 < v < 0x4000:
                    borne = v
            except ValueError:
                pass
        if ins.mnemonic == "movzx" and "byte ptr [" in ins.op_str:
            m = ins.op_str.rsplit("+", 1)
            if len(m) == 2 and m[1].strip().endswith("]"):
                try:
                    v = int(m[1].strip()[:-1], 0)
                    if v > 0x400000:
                        index = v
                except ValueError:
                    pass
    return borne, index


def cas(img, table, borne, index):
    """[(valeur, cible)] — l'enumeration telle que le code la voit."""
    if index is not None and borne is not None:
        octets = img.lire(index, borne + 1)
        out = []
        for v in range(min(borne + 1, len(octets))):
            cible = img.dword(table + 4 * octets[v])
            if cible is None or not img.dans_code(cible):
                break
            out.append((v, cible))
        return out
    n = (borne + 1) if borne is not None else 256
    out = []
    for v in range(n):
        cible = img.dword(table + 4 * v)
        if cible is None or not img.dans_code(cible):
            break
        out.append((v, cible))
    return out


def main():
    img = Image()
    brut = sauts(img)

    tables = []
    for site, table in brut:
        borne, index = contexte(img, site)
        entrees = cas(img, table, borne, index)
        if entrees:
            tables.append((site, table, borne, index, entrees))

    print("### AUTO-TEST — la fabrique de commandes")
    t = next((x for x in tables if x[0] == TEMOIN["site"]), None)
    if t is None:
        raise SystemExit("   site temoin 0x%08X absent : balayage casse, "
                         "rien n'est conclu." % TEMOIN["site"])
    site, table, borne, index, entrees = t
    cible = dict(entrees).get(TEMOIN["cas"])
    ok = (table == TEMOIN["table"] and borne == TEMOIN["borne"]
          and cible == TEMOIN["cible"])
    print("   site 0x%08X  table 0x%08X  borne 0x%X  %d cas  case %d -> %s  %s"
          % (site, table, borne or 0, len(entrees), TEMOIN["cas"],
             ("0x%08X" % cible) if cible else "?", "OK" if ok else "ECHEC"))
    if not ok:
        raise SystemExit("   -> temoin en echec : rien n'est conclu.")

    mini = 2
    if "--min" in sys.argv:
        mini = int(sys.argv[sys.argv.index("--min") + 1], 0)
    tables = [t for t in tables if len(t[4]) >= mini]

    print()
    print("%d table(s) de sauts de >=%d cas (%d sauts reperes au total)"
          % (len(tables), mini, len(brut)))
    print("Une table INDEXEE compte plus de valeurs que de cibles distinctes :")
    print("lire la table d'adresses seule ferait sous-estimer l'enumere.")

    if "--site" in sys.argv:
        vise = int(sys.argv[sys.argv.index("--site") + 1], 0)
        for site, table, borne, index, entrees in tables:
            if site != vise:
                continue
            print()
            print("site 0x%08X  table 0x%08X  index %s  borne 0x%X"
                  % (site, table, ("0x%08X" % index) if index else "-", borne or 0))
            for v, c in entrees:
                print("   [%3d] -> 0x%08X" % (v, c))
        return

    if "--csv" in sys.argv:
        print("site;table;index;borne;nb_cas;cibles_distinctes")
        for site, table, borne, index, entrees in tables:
            print("0x%08X;0x%08X;%s;%s;%d;%d"
                  % (site, table, ("0x%08X" % index) if index else "",
                     borne if borne is not None else "", len(entrees),
                     len({c for _, c in entrees})))
        return

    print()
    print("### LES TABLES, DE LA PLUS GRANDE A LA PLUS PETITE")
    for site, table, borne, index, entrees in sorted(tables, key=lambda x: -len(x[4]))[:60]:
        distinct = len({c for _, c in entrees})
        print("   0x%08X  %3d cas  %3d cible(s)  table 0x%08X %s"
              % (site, len(entrees), distinct, table,
                 "index 0x%08X" % index if index else ""))


if __name__ == "__main__":
    main()
