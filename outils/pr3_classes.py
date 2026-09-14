# -*- coding: utf-8 -*-
"""Les NOMS de classes de Port Royale 3, lus dans ses deux registres maison.

CE QUE CET OUTIL N'EST PAS. Une premiere version cherchait le RTTI de MSVC
(descripteurs « .?AVCTown@@ », localisateurs d'objet complet, tables virtuelles).
La mesure l'a refutee : `.?AV` x14, `.?AU` x0, `??_R0` x0, `??_7` x0 — ce binaire
est compile SANS RTTI (/GR-). L'auto-test avait refuse de publier un inventaire
vide, et c'est ainsi qu'on l'a su. Le controle est conserve ci-dessous : il vaut
mieux qu'un outil dise « je n'ai rien trouve » que de laisser croire a un
inventaire complet.

LES DEUX VRAIS REGISTRES.

1. Le RTTI MAISON du studio. Des instanciations de template laissent leur nom en
   clair : « Core::TypeIdSetupGmRtti<class Render::Context>::TypeIdSetupGmRtti ».
   71 classes, toutes de la couche MOTEUR et INTERFACE : `Render::*`, `NGUI::*`,
   `Components::Entity`, `Sound::SoundComponent`. Chacune est referencee par un
   `push` unique, ce qui donne son site d'enregistrement.

2. Le REGISTRE D'INSPECTEURS de debogage, a 0x717940. 61 classes de JEU —
   `Convoy`, `Trader`, `Town`, `Office`, `Nation`, `ConvoyAiInfo` et la famille
   des `*AiInfo`, `SeaBattle*`, `TownBattle*`, les `Event*`... Motif :

       push <nom> ; call 0x88cb10 ; mov ecx, [eax+0x14] ; call <inspecteur>

   Les classes de JEU ne sont QUE dans ce second registre ; celles du moteur QUE
   dans le premier. Chercher un `Convoy` parmi les `TypeIdSetupGmRtti` ne donne
   rien, et ce n'est pas une absence.

CE QUE LES INSPECTEURS NE DONNENT PAS. On a espere qu'ils enumerent les CHAMPS de
leur classe — ce qui aurait donne un plan de structure nomme, avec offsets, pour
61 classes. C'est faux, et verifie sur trois d'entre eux (`Convoy` 0x710D30,
`Nation` 0x715A10, `ConvoyAiInfo` 0x715BC0) : les corps sont structurellement
IDENTIQUES — meme prologue, meme insertion dans une table, meme `new 8`. La seule
difference est une constante de table virtuelle, celle de la petite FABRIQUE creee
par type (0xb7348c, 0xb7395c, 0xb73978), et non celle de la classe elle-meme.
Elle ne permet donc pas de nommer un objet croise au hasard dans un desassemblage.

Cet outil donne donc des NOMS et des ADRESSES, pas des dispositions memoire.

    py -3 outils/pr3_classes.py [--nom <motif>] [--csv]
"""
import re
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

REGISTRE = 0x717940        # premier `push <nom>` du registre d'inspecteurs
ETENDUE = 0x460            # sa longueur, mesuree
FABRIQUE = 0x88CB10        # `call` d'enregistrement, a ne pas prendre pour l'inspecteur

# Temoins : un par registre. Sans eux, aucun negatif ne serait interpretable.
TEMOIN_JEU = ("Convoy", 0x00710D30)
TEMOIN_MOTEUR = ("Render::Context", 0x00443E97)


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

    def va_de(self, off):
        for v, f, t in SECTIONS:
            if f <= off < f + t:
                return v + off - f
        return None

    def chaine(self, va, maxi=160):
        d = self.lire(va, maxi)
        if not d:
            return None
        fin = d.find(b"\x00")
        if fin < 1:
            return None
        s = d[:fin]
        return s.decode("latin1") if all(32 <= c < 127 for c in s) else None

    def sites_push(self, va):
        out, motif = [], b"\x68" + struct.pack("<I", va)
        i = self.text.find(motif)
        while i != -1:
            out.append(self.tv + i)
            i = self.text.find(motif, i + 1)
        return out


def rtti_msvc(img):
    """Le RTTI de MSVC est-il present ? (reponse attendue : non)"""
    return {m.decode("latin1"): img.exe.count(m)
            for m in (b".?AV", b".?AU", b"??_R0", b"??_7")}


def classes_moteur(img):
    """{nom: [sites]} depuis « TypeIdSetupGmRtti<class X> »."""
    out = {}
    for m in re.finditer(rb"TypeIdSetupGmRtti<(?:class|struct)\s+([A-Za-z0-9_:<>, ]+?)>",
                         img.exe):
        nom = m.group(1).decode("latin1")
        # l'adresse de la chaine ENTIERE, pas du fragment : on remonte au debut
        deb = img.exe.rfind(b"\x00", 0, m.start()) + 1
        va = img.va_de(deb)
        if va is None:
            continue
        out.setdefault(nom, [])
        for s in img.sites_push(va):
            if s not in out[nom]:
                out[nom].append(s)
    return out


def classes_jeu(img):
    """[(nom, inspecteur, vtable_fabrique)] depuis le registre 0x717940."""
    out, dernier = [], None
    for ins in img.md.disasm(img.lire(REGISTRE, ETENDUE), REGISTRE):
        if ins.mnemonic == "push" and ins.op_str.startswith("0x"):
            v = int(ins.op_str, 16)
            if v > 0x400000:
                s = img.chaine(v)
                if s and not s.startswith("::"):
                    dernier = s
        elif ins.mnemonic == "call" and ins.op_str.startswith("0x"):
            cible = int(ins.op_str, 16)
            if dernier and cible != FABRIQUE:
                out.append((dernier, cible, vtable_fabrique(img, cible)))
                dernier = None
    return out


def vtable_fabrique(img, inspecteur):
    """La constante `mov dword ptr [eax], 0xb7xxxx` du corps de l'inspecteur.

    C'est la table virtuelle de la petite FABRIQUE creee par type — pas celle de
    la classe. On la releve parce qu'elle identifie l'instanciation, pas pour
    nommer des objets rencontres ailleurs.
    """
    for ins in img.md.disasm(img.lire(inspecteur, 0xA0), inspecteur):
        if ins.mnemonic == "mov" and ins.op_str.startswith("dword ptr [eax], 0x"):
            v = int(ins.op_str.rsplit(",", 1)[1].strip(), 16)
            if v > 0x400000:
                return v
    return None


def main():
    img = Image()
    msvc = rtti_msvc(img)
    moteur = classes_moteur(img)
    jeu = classes_jeu(img)
    par_nom_jeu = {n: (i, v) for n, i, v in jeu}

    print("### AUTO-TEST")
    nom, adr = TEMOIN_JEU
    ok_jeu = par_nom_jeu.get(nom, (None,))[0] == adr
    print("   registre de jeu    : « %s » -> 0x%08X  %s"
          % (nom, adr, "OK" if ok_jeu else "ECHEC"))
    nom, adr = TEMOIN_MOTEUR
    ok_mot = adr in moteur.get(nom, [])
    print("   registre du moteur : « %s » -> 0x%08X  %s"
          % (nom, adr, "OK" if ok_mot else "ECHEC"))
    if not (ok_jeu and ok_mot):
        raise SystemExit("   -> un temoin manque : le balayage est casse, "
                         "rien n'est conclu.")

    print()
    print("### RTTI DE MSVC : %s"
          % ("absent — binaire compile /GR-"
             if msvc["??_R0"] == 0 else "PRESENT (revoir cet outil)"))
    print("   " + "  ".join("%s x%d" % (k, v) for k, v in msvc.items()))

    if "--csv" in sys.argv:
        print("registre;classe;adresse;vtable_fabrique")
        for n, i, v in jeu:
            print("jeu;%s;0x%08X;%s" % (n, i, ("0x%08X" % v) if v else ""))
        for n in sorted(moteur):
            for s in moteur[n]:
                print("moteur;%s;0x%08X;" % (n, s))
        return

    motif = None
    if "--nom" in sys.argv:
        motif = sys.argv[sys.argv.index("--nom") + 1].lower()

    print()
    print("### %d CLASSES DE JEU (registre d'inspecteurs 0x%06X)" % (len(jeu), REGISTRE))
    for n, i, v in jeu:
        if motif and motif not in n.lower():
            continue
        print("   %-30s inspecteur 0x%08X   fabrique %s"
              % (n, i, ("0x%08X" % v) if v else "?"))

    print()
    print("### %d CLASSES MOTEUR / INTERFACE (TypeIdSetupGmRtti)" % len(moteur))
    for n in sorted(moteur):
        if motif and motif not in n.lower():
            continue
        s = moteur[n]
        print("   %-46s %s" % (n, " ".join("0x%08X" % x for x in s) if s else "(non reference)"))

    print()
    print("Rappel : ces registres donnent des NOMS et des ADRESSES. Les inspecteurs")
    print("n'enumerent PAS les champs — verifie sur Convoy, Nation et ConvoyAiInfo,")
    print("dont les corps sont identiques a une constante pres.")


if __name__ == "__main__":
    main()
