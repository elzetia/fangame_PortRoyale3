# -*- coding: utf-8 -*-
"""TOUS les reglages nommes de Port Royale 3, releves mecaniquement dans l'exe.

POURQUOI CET OUTIL EXISTE. Le projet a longtemps relevé ces reglages un par un,
au fil des questions. Ca a produit des erreurs que l'utilisateur a du corriger :
le cas le plus net est `[Initial] Konvois`, dont le DEFAUT COMPILE vaut 3 alors
que les donnees le surchargent a 2 — la fiche a affiche 3 pendant des mois. Un
relevé exhaustif, rejouable, evite cette classe entiere d'erreurs : il met le
defaut ET le decalage de rangement cote a cote, ce qui permet ensuite a
`outils/pr3_constdata.py` d'aller lire la valeur REELLEMENT stockee.

LE MOTIF. Tous les reglages passent par la meme sequence, sans exception relevee :

    push <defaut> ; push <cle> ; push <section> ; mov ecx, <objet> ; call <lecteur>
    mov <destination>, ax|al|eax

Les arguments sont empiles a l'envers (cdecl), donc la SECTION est poussee en
DERNIER. Cinq lecteurs seulement :

    0x89d6e0  entier            0x89d750  flottant        0x89e270  chaine
    0x89d7c0  tableau           0x89d8a0  tableau de flottants

LE PIEGE DU RANGEMENT DECALE. Le compilateur ordonnance : le `mov` qui range le
resultat d'un appel apparait APRES les `push` de l'appel SUIVANT. Lire
naivement « le mov qui suit le call » attribue donc chaque valeur au mauvais
champ. On resout l'ambiguite en bornant : la destination d'un appel est le
dernier `mov <memoire>, ax|al|eax` situe entre CET appel et le suivant.

LE PIEGE DU REALIGNEMENT. Un flux x86 lu depuis un mauvais octet produit des
instructions plausibles et fausses. On ne cherche donc jamais un « debut de
fonction » (le motif `push ebp; mov ebp, esp` rate toutes les fonctions sans
cadre de pile et rend alors, en silence, la fonction PRECEDENTE — ca s'est
produit trois fois). On ancre sur les octets de l'appel et l'on essaie des
departs de plus en plus proches, en n'acceptant que celui dont le flux retombe
EXACTEMENT sur l'adresse visee.

CE QUE L'OUTIL DONNE, ET CE QU'IL NE DONNE PAS. Il donne la section, la cle, le
type, le DEFAUT COMPILE et le decalage de rangement. Il ne donne PAS la valeur
effective : celle-ci vit dans `ini/constdata.dat` et `ini/clientdata.dat`, qui
serialisent les champs dans l'ordre des structures SANS leurs noms. C'est
precisement pour cela que les decalages comptent.

Rien n'est copie dans le depot : l'outil lit l'installation locale du joueur.

    py -3 outils/pr3_reglages.py [--section <nom>] [--csv]
"""
import re
import struct
import sys

try:
    from capstone import Cs, CS_ARCH_X86, CS_MODE_32
except ImportError:                                    # pragma: no cover
    raise SystemExit("capstone est requis : py -3 -m pip install capstone")

EXE = r"D:\GOG Galaxy\Games\Port Royale 3\PortRoyale3.exe"

# ImageBase 0x400000 ; (adresse virtuelle, decalage fichier, taille)
SECTIONS = [(0x401000, 0x400, 0x736000),
            (0xB38000, 0x736600, 0x86400),
            (0xBBF000, 0x7bca00, 0x44800)]

LECTEURS = {
    0x89D6E0: "entier",
    0x89D750: "flottant",
    0x89D7C0: "tableau",
    0x89D8A0: "tableau flt",
    0x89E270: "chaine",
}

RECUL = 0x90          # jusqu'ou remonter pour realigner devant un appel
PORTEE = 0x60         # jusqu'ou chercher la destination apres un appel


def charger():
    with open(EXE, "rb") as f:
        return f.read()


class Image:
    def __init__(self, exe):
        self.exe = exe
        self.tv, self.tf, self.tt = SECTIONS[0]
        self.text = exe[self.tf:self.tf + self.tt]
        self.md = Cs(CS_ARCH_X86, CS_MODE_32)

    def lire(self, va, n):
        for v, f, t in SECTIONS:
            if v <= va < v + t:
                o = f + va - v
                return self.exe[o:o + n]
        return b""

    def chaine(self, va, maxi=96):
        d = self.lire(va, maxi)
        if not d:
            return None
        fin = d.find(b"\x00")
        if fin < 1:
            return None
        s = d[:fin]
        if not s or not all(32 <= c < 127 for c in s):
            return None
        return s.decode("ascii")

    def flottant(self, va):
        d = self.lire(va, 4)
        return struct.unpack("<f", d)[0] if len(d) == 4 else None

    def appels(self, cible):
        """Toutes les adresses de `call rel32` visant `cible`."""
        out = []
        i = self.text.find(b"\xe8")
        while i != -1 and i + 5 <= len(self.text):
            rel = struct.unpack_from("<i", self.text, i + 1)[0]
            if (self.tv + i + 5 + rel) & 0xFFFFFFFF == cible:
                out.append(self.tv + i)
            i = self.text.find(b"\xe8", i + 1)
        return out

    def aligner(self, cible, recul=RECUL):
        """Le depart le plus lointain dont le flux retombe EXACTEMENT sur `cible`."""
        for d in range(recul, 3, -1):
            dep = cible - d
            for ins in self.md.disasm(self.lire(dep, d + 16), dep):
                if ins.address == cible:
                    return dep
                if ins.address > cible:
                    break
        return cible

    def flux(self, depart, fin):
        return [ins for ins in self.md.disasm(self.lire(depart, (fin - depart) + 32), depart)
                if ins.address <= fin]


def defaut_flottant(img, avant):
    """Le defaut d'un lecteur flottant : `fld1`/`fldz`/`fld dword ptr [adr]`
    suivi de `fstp dword ptr [esp]`. On remonte le flux a l'envers."""
    for ins in reversed(avant):
        if ins.mnemonic == "fld1":
            return 1.0
        if ins.mnemonic == "fldz":
            return 0.0
        if ins.mnemonic in ("fld", "fld dword"):
            m = re.search(r"\[(0x[0-9a-f]+)\]", ins.op_str)
            if m:
                return img.flottant(int(m.group(1), 16))
            return None
    return None


def analyser(img, site, type_lecteur, fins):
    """Un site d'appel -> (section, cle, defaut, destination)."""
    dep = img.aligner(site)
    ctx = img.flux(dep, site)
    if not ctx or ctx[-1].address != site:
        return None                                  # realignement rate : on s'abstient

    # Les `push` qui precedent, du plus proche au plus lointain.
    pousses = []
    for ins in reversed(ctx[:-1]):
        if ins.mnemonic == "push":
            pousses.append(ins)
        if len(pousses) >= 6:
            break

    section = cle = None
    defaut = None
    textes = []
    for ins in pousses:
        # PIEGE : capstone rend les petits immediats en DECIMAL (`push 3`) et les
        # grands en hexa (`push 0x1e00`). Tester `startswith("0x")` rate donc tous
        # les petits defauts et fait remonter le scan jusqu'au reglage PRECEDENT —
        # c'est ainsi que `Konvois` (defaut 3) est sorti a 7680, la valeur de
        # `KiUpdateConvoySize`. `int(s, 0)` accepte les deux ecritures.
        try:
            v = int(ins.op_str, 0)
        except ValueError:
            continue                                 # `push ecx`, `push eax`...
        s = img.chaine(v) if v > 0x400000 else None
        if s is not None:
            textes.append(s)
        elif defaut is None and v <= 0xFFFFFF:
            defaut = v
    if textes:
        section = textes[0]                          # pousse en dernier => 1er argument
    if len(textes) >= 2:
        cle = textes[1]
    elif section is not None:
        cle = "<calculee>"                           # cle fabriquee par sprintf

    if type_lecteur in ("flottant", "tableau flt") and defaut is None:
        defaut = defaut_flottant(img, ctx[:-1])

    # La DESTINATION : le dernier `mov <memoire>, ax|al|eax` entre cet appel et le
    # suivant. C'est le rangement decale ; le borner est la seule facon de ne pas
    # l'attribuer au mauvais champ.
    suivant = min((f for f in fins if f > site), default=site + PORTEE)
    dest = None
    for ins in img.flux(site + 5, min(suivant, site + 0x200)):
        if ins.mnemonic == "mov" and ins.op_str.endswith((", ax", ", al", ", eax")) \
                and "ptr [" in ins.op_str:
            # Le PREMIER rangement apres l'appel, pas le dernier : le resultat est
            # ecrit tout de suite, et les `mov` suivants appartiennent deja au bloc
            # d'apres. Prendre le dernier donnait `[ebp-0xc]` la ou le vrai champ
            # est `[edi+0x878]`.
            dest = ins.op_str.split(",")[0].strip()
            break
    return section, cle, defaut, dest


def main():
    filtre = None
    if "--section" in sys.argv:
        filtre = sys.argv[sys.argv.index("--section") + 1].lower()
    csv = "--csv" in sys.argv

    img = Image(charger())

    sites = []
    for adr, type_lecteur in LECTEURS.items():
        for s in img.appels(adr):
            sites.append((s, type_lecteur))
    sites.sort()
    fins = [s for s, _ in sites]

    lignes, rates = [], 0
    for site, type_lecteur in sites:
        r = analyser(img, site, type_lecteur, fins)
        if r is None:
            rates += 1
            continue
        section, cle, defaut, dest = r
        if section is None:
            rates += 1
            continue
        lignes.append((section, cle, type_lecteur, defaut, dest, site))

    if csv:
        print("section;cle;type;defaut;destination;site")
        for section, cle, t, d, dest, site in lignes:
            print("%s;%s;%s;%s;%s;0x%08X" % (section, cle, t, d, dest or "", site))
        return

    print("%d site(s) de lecture, %d exploitable(s), %d non realignable(s)"
          % (len(sites), len(lignes), rates))
    print("Defauts COMPILES. La valeur effective peut etre surchargee par")
    print("ini/constdata.dat ou ini/clientdata.dat (voir outils/pr3_constdata.py).")

    par_section = {}
    for l in lignes:
        par_section.setdefault(l[0], []).append(l)

    for section in sorted(par_section):
        if filtre and filtre not in section.lower():
            continue
        entrees = par_section[section]
        print()
        print("[%s]   %d reglage(s)" % (section, len(entrees)))
        for _, cle, t, d, dest, site in entrees:
            print("   %-30s %-12s defaut=%-12s %-26s 0x%08X"
                  % (cle, t, "?" if d is None else d, dest or "", site))


if __name__ == "__main__":
    main()
