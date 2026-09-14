# -*- coding: utf-8 -*-
"""L'index croise des CHAINES de Port Royale 3 : ou chaque texte est-il utilise ?

POURQUOI CET OUTIL EXISTE. Quand un programme est compile, les noms de variables
et de fonctions sont jetes. Il ne reste en clair que les TEXTES dont le programme
se sert a l'execution : cles de configuration, identifiants d'interface
(`ID_GUI_*`), chemins d'assets, noms de scenes, messages de debogage. Ces textes
sont donc les seules etiquettes qui subsistent — et savoir OU chacun est utilise
revient a nommer le code qui l'entoure.

C'est la manoeuvre qui a permis, cette session, d'identifier le vecteur `+0x18`
du monde comme la table des villes : ses appelants citaient `MinimapTown`,
`lookminimaptown` et `mapdiscover`. Elle etait faite a la main, une chaine a la
fois. Ici, elle l'est en une passe.

CE QUE L'OUTIL FAIT. Il releve toutes les chaines imprimables des sections de
donnees, puis balaie le CODE a la recherche de leur adresse. Une adresse trouvee
dans le flot d'instructions est une reference : `push <adr>` (0x68),
`mov reg, <adr>` (0xB8..0xBF), ou un autre encodage. Le type est deduit de
l'octet qui precede et affiche tel quel — l'outil ne desassemble pas pour
trancher, et le dit.

CE QU'IL NE FAIT PAS. Les references INDIRECTES lui echappent : une chaine
atteinte par une table de pointeurs, ou construite a l'execution par `sprintf`
(les cles en `Ware%02u_Verbrauch`, par exemple) n'a pas d'adresse poussee
litteralement. « Zero site » ne veut donc jamais dire « jamais utilisee ».

AUTO-TEST. Quatre filtres rates en une session ont impose la regle : un balayage
qui ne se prouve pas sur des positifs connus ne permet de conclure aucun negatif.
Trois temoins releves a la main gardent l'outil ; s'ils tombent, il refuse.

Rien n'est copie dans le depot : l'outil lit l'installation locale du joueur.

    py -3 outils/pr3_chaines.py --motif Konvois
    py -3 outils/pr3_chaines.py --motif "^ID_GUI_CONVOY" --sites
    py -3 outils/pr3_chaines.py --adresse 0xB7BACC
    py -3 outils/pr3_chaines.py --zone 0x855000 0x856000
"""
import re
import struct
import sys

EXE = r"D:\GOG Galaxy\Games\Port Royale 3\PortRoyale3.exe"

# ImageBase 0x400000 ; (adresse virtuelle, decalage fichier, taille)
SECTIONS = [(0x401000, 0x400, 0x736000),
            (0xB38000, 0x736600, 0x86400),
            (0xBBF000, 0x7bca00, 0x44800)]

LONGUEUR_MIN = 4

# Temoins : chaine -> (adresse, nombre de sites attendu, un site connu).
TEMOINS = {
    "Konvois":    (0x00B7BACC, 1, 0x008556A8),
    # Le site est celui du `push` de la chaine, PAS celui du `call` qui suit :
    # la table de `pr3_reglages.py` publie l'adresse de l'appel, et prendre
    # celle-la comme temoin le faisait echouer a tort (0x004611B7).
    "Colors":     (0x00B3E1AC, 32, 0x00461155),
    "maxConvoys": (0x00B79FCC, 1, 0x008299D7),
}

# L'octet qui precede l'adresse dit comment elle est employee.
def genre(octet):
    if octet == 0x68:
        return "push"
    if 0xB8 <= octet <= 0xBF:
        return "mov"
    if octet == 0x05:
        return "add"
    return "autre"


class Image:
    def __init__(self):
        with open(EXE, "rb") as f:
            self.exe = f.read()
        self.tv, self.tf, self.tt = SECTIONS[0]
        self.text = self.exe[self.tf:self.tf + self.tt]

    def va_de(self, off):
        for v, f, t in SECTIONS:
            if f <= off < f + t:
                return v + off - f
        return None


def chaines(img):
    """{adresse: texte} pour toutes les chaines des sections de donnees."""
    out = {}
    motif = re.compile(rb"[\x20-\x7e]{%d,}" % LONGUEUR_MIN)
    for v, f, t in SECTIONS[1:]:
        bloc = img.exe[f:f + t]
        for m in motif.finditer(bloc):
            # une chaine C est nul-terminee : on n'accepte que si le caractere
            # suivant est un zero, sinon on ramasse des fragments de donnees
            fin = m.end()
            if fin < len(bloc) and bloc[fin] != 0:
                continue
            out[v + m.start()] = m.group().decode("latin1")
    return out


def references(img, adresses):
    """{adresse: [(site, genre)]} — ou chaque adresse apparait dans le CODE.

    Un seul balayage du code : on lit chaque fenetre de 4 octets (non alignee,
    puisqu'un operande de `push` ne l'est pas) et l'on teste l'appartenance.
    """
    index = {}
    text, tv = img.text, img.tv
    n = len(text) - 4
    for i in range(n):
        v = text[i] | (text[i + 1] << 8) | (text[i + 2] << 16) | (text[i + 3] << 24)
        if v in adresses:
            index.setdefault(v, []).append((tv + i - 1, genre(text[i - 1] if i else 0)))
    return index


def main():
    img = Image()
    tous = chaines(img)
    refs = references(img, set(tous))

    print("### AUTO-TEST")
    rates = 0
    for nom, (adr, attendu, site) in TEMOINS.items():
        r = refs.get(adr, [])
        sites = [s for s, _ in r]
        ok = tous.get(adr) == nom and len(r) == attendu and site in sites
        if not ok:
            rates += 1
        print("   %-12s 0x%08X  %d site(s) (attendu %d)  temoin %s  %s"
              % (nom, adr, len(r), attendu,
                 "present" if site in sites else "ABSENT",
                 "OK" if ok else "ECHEC"))
    if rates:
        raise SystemExit("   -> %d temoin(s) en echec : rien n'est conclu." % rates)

    print()
    print("%d chaine(s) dans les donnees, %d referencee(s) depuis le code"
          % (len(tous), len(refs)))
    print("Les references INDIRECTES echappent a ce balayage (table de pointeurs,")
    print("cle construite par sprintf) : « 0 site » ne veut pas dire « inutilisee ».")

    if "--adresse" in sys.argv:
        adr = int(sys.argv[sys.argv.index("--adresse") + 1], 0)
        print()
        print("0x%08X : %r" % (adr, tous.get(adr)))
        for s, g in refs.get(adr, []):
            print("   %-6s 0x%08X" % (g, s))
        return

    if "--zone" in sys.argv:
        k = sys.argv.index("--zone")
        lo, hi = int(sys.argv[k + 1], 0), int(sys.argv[k + 2], 0)
        print()
        print("### CHAINES CITEES DEPUIS LA ZONE 0x%08X..0x%08X" % (lo, hi))
        vus = {}
        for adr, r in refs.items():
            for s, g in r:
                if lo <= s < hi:
                    vus.setdefault(adr, []).append(s)
        for adr in sorted(vus, key=lambda a: min(vus[a])):
            print("   0x%08X  %-46s <- %s"
                  % (adr, repr(tous[adr])[:46],
                     " ".join("0x%08X" % s for s in vus[adr][:4])))
        return

    motif = None
    if "--motif" in sys.argv:
        motif = re.compile(sys.argv[sys.argv.index("--motif") + 1], re.I)
    detail = "--sites" in sys.argv

    if "--csv" in sys.argv:
        print("adresse;chaine;nb_sites;sites")
        for adr in sorted(tous):
            if motif and not motif.search(tous[adr]):
                continue
            r = refs.get(adr, [])
            print("0x%08X;%s;%d;%s" % (adr, tous[adr].replace(";", "\\;"), len(r),
                                       " ".join("0x%08X" % s for s, _ in r)))
        return

    if motif is None:
        print()
        print("Precise un filtre : --motif <regex>, --adresse <va>, --zone <lo> <hi>.")
        print("Sans filtre la sortie ferait %d lignes." % len(tous))
        return

    print()
    n = 0
    for adr in sorted(tous):
        if not motif.search(tous[adr]):
            continue
        n += 1
        r = refs.get(adr, [])
        print("   0x%08X  %-52s %d site(s)" % (adr, repr(tous[adr])[:52], len(r)))
        if detail:
            for s, g in r:
                print("                 %-6s 0x%08X" % (g, s))
    print("\n   %d chaine(s) retenue(s)" % n)


if __name__ == "__main__":
    main()
