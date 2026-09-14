# -*- coding: utf-8 -*-
"""Refait `carte_cuite_mer.png`, la fiche que lit la nappe animee.

    py -3 outils/carte_mer.py

POURQUOI UN OUTIL A PART. Cette fiche etait produite par `carte_illustree.py`,
en meme temps que le decor et le masque de navigation. Mais ce script-la part
d'une ILLUSTRATION et reecrit au passage `sim/carte_monde.lua` et
`carte_cuite.json` : le relancer aujourd'hui remplacerait la geographie de Port
Royale 3 par celle d'un dessin. On extrait donc la seule etape qui nous manque.

CE QUE LA FICHE CONTIENT (recette inchangee) :

    rouge = la part d'EAU du bloc
    vert  = la PLUS FAIBLE profondeur du bloc, en metres, sur 255 pour 60 m

Le vert est une rampe, et son echelle est tout le sujet : le shader ne lit pas
une distance mais des METRES, et il en tire trois bandes aux seuils fixes -- le
ressac sous 3,2 m, le passage au large entre 1,5 et 9 m, les moutons qui
s'eteignent a 30 m. Toute la vie de la nappe tient dans ces trente premiers
metres. D'ou une case = un metre sur le plateau, puis une montee lente jusqu'au
fond, pour que le large reste le large.

DEUX DEFAUTS QUE CET OUTIL CORRIGE, et qui venaient du meme endroit :

 1. LA HAUTEUR. La fiche en place fait 660 x 433. Elle a ete calculee quand le
    masque etait deduit de l'illustration (1320 x 866). Le masque livre est
    celui de PR3 : 1320 x 960.

 2. LE CADRE. `carte2d.gd` etire la fiche sur TOUTE l'image
    (`scale = proj.pixels / tex.size`, ancree en (0,0)). Or son contenu decrit
    le monde JOUABLE, alors que la carte de PR3 porte un cadre de bois hors de
    ce monde : l'image couvre 17280 x 11940 la ou le masque couvre
    15840 x 11520. Etiree bord a bord, la nappe se decalerait de la largeur du
    cadre. On fabrique donc la fiche AUX PROPORTIONS DE L'IMAGE et on y insere
    le masque en son centre, au retrait que donne la fiche de projection. Le
    moteur garde son etirement simple, et le cadrage reste ou vit deja tout le
    reste : dans les outils.

Aucune dependance : bibliotheque standard uniquement.
"""
import importlib.util
import io
import json
import os
import re
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

_spec = importlib.util.spec_from_file_location(
    "carte_illustree", os.path.join(RACINE, "outils", "carte_illustree.py"))
ci = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ci)

ECHELLE_CASE = 12.0        # unites de monde par case (sim/archipel.lua)
REDUCTION = 4              # la fiche fait le quart de l'image, comme avant
PLATEAU, FOND = 30.0, 150.0    # en cases
NL = chr(10)


def lire_masque():
    """(largeur, hauteur, terre) depuis le RLE de `sim/carte_monde.lua`."""
    src = io.open(os.path.join(RACINE, "sim", "carte_monde.lua"),
                  encoding="utf-8").read()
    mw, mh = map(int, re.search(
        r"Carte\.largeur,\s*Carte\.hauteur\s*=\s*(\d+),\s*(\d+)", src).groups())
    bloc = src.split("Carte.plages = {", 1)[1].split(NL + "}", 1)[0]
    terre = bytearray(mw * mh)
    for z, ligne in enumerate(re.findall(r"\{([0-9,\s]+)\}", bloc)):
        x, valeur = 0, 0
        for n in (int(t) for t in ligne.split(",") if t.strip()):
            if valeur:
                for k in range(x, min(x + n, mw)):
                    terre[z * mw + k] = 1
            x += n
            valeur = 1 - valeur
    return mw, mh, terre


def metres(cases):
    """Un metre par case sur le plateau, puis une montee lente jusqu'au fond."""
    if cases <= PLATEAU:
        return cases
    if cases >= FOND:
        return 60.0
    return 30.0 + 30.0 * (cases - PLATEAU) / (FOND - PLATEAU)


def main():
    fiche = json.load(io.open(os.path.join(RACINE, "carte_cuite.json"),
                              encoding="utf-8"))
    vue = fiche["vue_taille"]
    pixels = fiche["pixels"]
    centre = fiche.get("centre", [0.0, 0.0])
    if abs(centre[0]) > 0.5 or abs(centre[1]) > 0.5:
        raise SystemExit("centre non nul : cet outil suppose [0, 0]")

    mw, mh, terre = lire_masque()
    fw, fh = pixels[0] // REDUCTION, pixels[1] // REDUCTION
    print("masque %d x %d   image %d x %d   fiche %d x %d"
          % (mw, mh, pixels[0], pixels[1], fw, fh))
    print("   monde du masque %.0f x %.0f, monde de l'image %.0f x %.0f"
          % (mw * ECHELLE_CASE, mh * ECHELLE_CASE, vue[0], vue[1]))

    mer = [not terre[i] for i in range(mw * mh)]
    prof = ci.chanfrein(mer, mw, mh)        # le chanfrein compte 5 par case

    # Ou le monde jouable tombe DANS la fiche : le masque n'occupe pas toute
    # l'image, il en occupe la part que la fiche de projection lui donne.
    part_x = mw * ECHELLE_CASE / vue[0]
    part_y = mh * ECHELLE_CASE / vue[1]
    print("   le masque occupe %.2f %% x %.2f %% de l'image"
          % (100.0 * part_x, 100.0 * part_y))

    # On accumule PAR PIXEL de la fiche, en parcourant les cases : cela vaut
    # pour n'importe quel rapport entre les deux grilles, la ou l'ancienne
    # version supposait des blocs de 2x2 exactement.
    eaux = [0] * (fw * fh)
    total = [0] * (fw * fh)
    creux = [None] * (fw * fh)
    for cz in range(mh):
        v = (cz + 0.5) / mh - 0.5
        py = int((0.5 + v * part_y) * fh)
        if not (0 <= py < fh):
            continue
        for cx in range(mw):
            u = (cx + 0.5) / mw - 0.5
            px = int((0.5 + u * part_x) * fw)
            if not (0 <= px < fw):
                continue
            j = py * fw + px
            total[j] += 1
            i = cz * mw + cx
            if mer[i]:
                eaux[j] += 1
                c = prof[i] / 5.0
                # La PLUS FAIBLE profondeur du bloc : une bande etroite ne doit
                # jamais disparaitre entre deux echantillons.
                if creux[j] is None or c < creux[j]:
                    creux[j] = c

    sortie = bytearray(fw * fh * 3)
    remplis = 0
    for j in range(fw * fh):
        if total[j] == 0 or eaux[j] == 0:
            continue                 # hors du monde jouable, ou terre pleine
        remplis += 1
        k = j * 3
        sortie[k] = eaux[j] * 255 // total[j]
        sortie[k + 1] = int(round(metres(creux[j]) * 255.0 / 60.0))
    print("   %d pixels d'eau sur %d (%.1f %%)"
          % (remplis, fw * fh, 100.0 * remplis / (fw * fh)))

    ci.ecrire_png(os.path.join(RACINE, "carte_cuite_mer.png"), fw, fh, sortie)
    print("carte_cuite_mer.png : %d x %d" % (fw, fh))


if __name__ == "__main__":
    main()
