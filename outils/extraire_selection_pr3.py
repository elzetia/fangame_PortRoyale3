# -*- coding: utf-8 -*-
"""Sort de Port Royale 3 les ANNEAUX de sa carte maritime et la ROUE de son menu
radial.

    py -3 outils/extraire_selection_pr3.py

Ecrit dans `reference_pr3/assets/` :

    selectioncircle0.png   l'anneau a trait FIN     (256 x 256, DXT5)
    selectioncircle1.png   l'anneau a trait EPAIS   (256 x 256, DXT5)
    centercircle0.png      la roue du menu radial   (512 x 512, DXT5)

POURQUOI CET OUTIL EXISTE. `scripts/carte2d.gd` pose l'anneau du jeu sous la
ville survolee, au lieu du disque translucide qu'il dessinait. Cet art est celui
de Port Royale 3 — (c) Kalypso / Gaming Minds — donc il ne peut pas entrer dans
un depot public : il vit dans `reference_pr3/`, ignore par git.

Sans recette versionnee, une copie fraiche perdrait l'anneau pour toujours. Le
projet a deja paye cette lecon avec `carte_cuite.png`, versionnee sans qu'aucun
outil sache la refaire : on versionne les OUTILS, jamais leur sortie, et un
artefact genere n'est acceptable que s'il porte le nom de ce qui le reconstruit.

OU C'EST DANS LE JEU. Le registre d'entites de la carte maritime (`0x460d11`)
nomme `SelectionConvoyMap` pour un convoi et `SelectionConvoyTown` pour une
ville ; l'archive `data.fuk` livre l'art sous `assets/selectioncircleN/`, avec
son maillage, son materiau (`materials/selectioncircle.mat`) et ses shaders
(`shader/selectioncircle.psh` / `.vsh`).

CE QUI RESTE INDETERMINE, et qu'il ne faut pas affirmer : LEQUEL des deux revient
a la ville. Leurs descripteurs `.asset` sont identiques a leur propre nom pres,
et leurs maillages le sont a l'octet pres (215 / 1104 / 416) — la taille est
appliquee a l'execution, pas gravee dans l'art, donc le rapport 16:11 des rayons
de selection (`[Gui] SelectionRange` / `SelectionRangeTown`) ne les departage pas
davantage. Il se peut meme que la distinction ne soit pas ville/convoi mais
SURVOL/SELECTION, ce que l'ecart d'epaisseur suggere. L'appariement vit dans
l'executable, pas dans les fichiers.

Aucune dependance : bibliotheque standard, plus `outils/dds2png.py` du projet.
"""
import os
import struct
import subprocess
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PR3_MOD = r"D:\GOG Galaxy\Games\Port Royale 3\_mod\pr3"
sys.path.insert(0, PR3_MOD)

import pr3fuk                                    # noqa: E402
import pr3map                                    # noqa: E402

SORTIE = os.path.join(RACINE, "reference_pr3", "assets")
DDS2PNG = os.path.join(RACINE, "outils", "dds2png.py")

CIBLES = [
    "assets/selectioncircle0/selectioncircle0.dds",
    "assets/selectioncircle1/selectioncircle1.dds",
    # LA ROUE DU MENU RADIAL. 512 x 512, DXT5, et c'est bien le fond de la
    # couronne : la mesure donne HUIT rayons a 0/45/90/135/180/225/270/315
    # degres -- verifiee a trois rayons differents (0,35 / 0,55 / 0,75) --, un
    # anneau lumineux a 0,89 du demi-cote et un moyeu vers 0,05.
    #
    # ELLE S'EST LONGTEMPS CACHEE : `ingame_radial_town.swf` ne porte pour ce
    # fond qu'un `Visual_CR_Radial`, un `customrenderelement` dont le remplissage
    # Flash est un aplat bleu de remplacement (0, 102, 204). J'en avais conclu
    # que le moteur peignait les petales sans texture. C'etait faux : il pose CE
    # maillage et CETTE texture, rangee dans `data.fuk` comme `selectioncircle`.
    #
    # ATTENTION AU RENDU : son alpha est PLAT. Les 16384 blocs BC3 ont tous la
    # meme paire (a0=64, a1=65) et les 262144 indices valent 0, donc chaque texel
    # est a 64. Le dessin vit dans le RGB, sombre partout sauf l'anneau, les
    # rayons et le moyeu : elle se pose en fusion ADDITIVE. En fusion normale,
    # c'est un carre sombre a 25 %.
    "assets/centercircle0/centercircle0.dds",
]


def main():
    os.makedirs(SORTIE, exist_ok=True)
    jeu = pr3map.game()
    ar = pr3fuk.load(pr3map.orig(jeu, "data.fuk"))
    faits = []
    for cible in CIBLES:
        e = ar["by_path"].get(cible)
        if e is None:
            print("ABSENT de l'archive : %s" % cible)
            continue
        d = pr3fuk.content(ar, e)
        nom = os.path.basename(cible)
        dds = os.path.join(SORTIE, nom)
        with open(dds, "wb") as f:
            f.write(d)
        # L'en-tete DDS porte la taille et le format : on les affiche pour
        # n'avoir rien a supposer au moment de convertir.
        h, w = struct.unpack_from("<2i", d, 12)
        print("%-24s %4d x %-4d  %s" % (nom, w, h, d[84:88].decode("latin1", "replace")))
        faits.append(dds)
    ar["f"].close()

    if not faits:
        raise SystemExit("rien a convertir : l'archive n'a pas livre les textures")

    print()
    for dds in faits:
        png = os.path.splitext(dds)[0] + ".png"
        subprocess.check_call([sys.executable, DDS2PNG, dds, png])
        # Le .dds ne sert plus : seul le PNG est lu par le moteur.
        os.remove(dds)
    print()
    print("ecrits dans %s" % SORTIE)
    print("`reference_pr3/` est ignore par git : cet art ne doit pas etre commite.")


if __name__ == "__main__":
    main()
