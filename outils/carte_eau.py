# -*- coding: utf-8 -*-
"""Retire l'eau du LARGE de l'illustration, garde le rivage et les recifs.

    py outils/carte_eau.py

Pourquoi. La nappe animee se dessine PAR-DESSUS l'illustration (z -9 contre
-10) : elle agite une mer deja peinte. Le large peint n'apporte alors rien --
c'est un aplat -- mais sa texture au pinceau se bat avec le mouvement du
shader. On le retire donc, et on le remplace par un fond uni de la MEME
couleur : rien ne change a l'oeil la ou le shader est transparent, mais l'eau
du large appartient desormais entierement a la nappe.

Ce qu'on garde. Le turquoise du rivage et les recifs : c'est la que la couleur
peinte dit quelque chose que le shader ne sait pas dire. La mesure montre qu'il
n'y a AUCUNE frontiere entre eau peu profonde et eau profonde -- la couleur
descend en degrade continu de (85,156,139) a une case de la cote jusqu'a
(0,75,131) a quarante. Un seuil net y dessinerait un anneau autour de chaque
ile. On fait donc un FONDU, et on garde en plus tout pixel dont la couleur
s'ecarte du large : un recif au milieu de nulle part survit ainsi, quelle que
soit sa profondeur.

Entrees  : carte_cuite.png, sim/carte_monde.lua
Sorties  : carte_cuite.png (RGBA), carte_cuite.json (champ "mer_fond")

L'original est dans git : `git checkout -- carte_cuite.png` le rend.
"""
import importlib.util
import io
import json
import os
import re

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

_spec = importlib.util.spec_from_file_location(
    "carte_illustree", os.path.join(RACINE, "outils", "carte_illustree.py"))
ci = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ci)

# Le fondu, en cases du masque depuis la cote.
OPAQUE_JUSQUA   = 10      # en deca, l'illustration est gardee telle quelle
TRANSPARENT_DES = 32      # au dela, elle est entierement rendue a la nappe

# De combien la couleur doit s'ecarter du large pour qu'on parle d'un recif.
# 28 sur 255 : au dela du bruit du pinceau, en deca du turquoise franc.
ECART_RECIF = 28

NL = chr(10)


def lire_masque():
    """Le masque terre/mer, decode depuis le RLE de sim/carte_monde.lua."""
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


# L'IMAGE NE COUVRE PLUS EXACTEMENT L'EMPRISE DU MASQUE, et c'est tout l'objet
# de ce qui suit. Tant que la carte etait une illustration dont la fiche etait
# tiree d'elle, `x * mw // iw` suffisait : un pixel de bord tombait sur une case
# de bord. La carte de Port Royale 3 porte un CADRE DE BOIS hors de la zone
# jouable, donc elle couvre un monde plus large (17280 x 11940) que le masque
# (1320 x 960 cases a 12 unites, soit 15840 x 11520). Garder la proportion
# decalerait tout le ressac de la largeur du cadre -- 128 px a cette resolution.
#
# On passe donc par le MONDE, comme le moteur : pixel -> monde par la fiche,
# monde -> case par l'echelle de `sim/archipel.lua`.
ECHELLE_CASE = 12.0


def lire_vue():
    """(vue_x, vue_y) de `carte_cuite.json`. Le centre y est a [0, 0]."""
    fiche = json.load(io.open(os.path.join(RACINE, "carte_cuite.json"),
                              encoding="utf-8"))
    v = fiche["vue_taille"]
    c = fiche.get("centre", [0.0, 0.0])
    if abs(c[0]) > 0.5 or abs(c[1]) > 0.5:
        raise SystemExit("centre non nul : ce script suppose [0, 0]")
    return float(v[0]), float(v[1])


def case_de_pixel(x, y, iw, ih, mw, mh, vue):
    cx = (x / float(iw) - 0.5) * (vue[0] / ECHELLE_CASE) + mw / 2.0
    cz = (y / float(ih) - 0.5) * (vue[1] / ECHELLE_CASE) + mh / 2.0
    return int(cx), int(cz)


def pixel_de_case(cx, cz, iw, ih, mw, mh, vue):
    x = iw * (0.5 + (cx + 0.5 - mw / 2.0) * ECHELLE_CASE / vue[0])
    y = ih * (0.5 + (cz + 0.5 - mh / 2.0) * ECHELLE_CASE / vue[1])
    return int(x), int(y)


def couleur_du_large(ipx, iw, ih, mw, mh, terre, prof, vue):
    """La couleur de l'eau a plus de TRANSPARENT_DES cases de toute cote."""
    r = v = b = n = 0
    for cz in range(mh):
        for cx in range(mw):
            i = cz * mw + cx
            if terre[i] or prof[i] // 5 < TRANSPARENT_DES:
                continue
            ix, iy = pixel_de_case(cx, cz, iw, ih, mw, mh, vue)
            if not (0 <= ix < iw and 0 <= iy < ih):
                continue
            s = (iy * iw + ix) * 4
            r += ipx[s]; v += ipx[s + 1]; b += ipx[s + 2]; n += 1
    if n == 0:
        raise SystemExit("aucune eau du large trouvee : seuils a revoir")
    return (r // n, v // n, b // n), n


def main():
    mw, mh, terre = lire_masque()
    iw, ih, ipx = ci.lire_png(os.path.join(RACINE, "carte_cuite.png"))
    print("illustration %d x %d, masque %d x %d" % (iw, ih, mw, mh))

    vue = lire_vue()
    print("vue_taille %s : le monde couvert par l'image" % (vue,))
    mer = [not terre[i] for i in range(mw * mh)]
    prof = ci.chanfrein(mer, mw, mh)          # le chanfrein compte 5 par case
    fond, n_large = couleur_du_large(ipx, iw, ih, mw, mh, terre, prof, vue)
    print("couleur du large : %s  (sur %d cases)" % (fond, n_large))

    # Alpha par CASE du masque, puis lu par pixel : le masque est la seule
    # grille ou la profondeur ait un sens.
    alpha = bytearray(mw * mh)
    for i in range(mw * mh):
        if terre[i]:
            alpha[i] = 255
            continue
        d = prof[i] / 5.0
        if d <= OPAQUE_JUSQUA:
            alpha[i] = 255
        elif d >= TRANSPARENT_DES:
            alpha[i] = 0
        else:
            t = (d - OPAQUE_JUSQUA) / float(TRANSPARENT_DES - OPAQUE_JUSQUA)
            alpha[i] = int(round(255.0 * (1.0 - t)))

    sortie = bytearray(iw * ih * 4)
    recifs = 0
    for y in range(ih):
        _, cz = case_de_pixel(0, y, iw, ih, mw, mh, vue)
        dehors_y = not (0 <= cz < mh)
        for x in range(iw):
            s = (y * iw + x) * 4
            d = (y * iw + x) * 4
            cx, _ = case_de_pixel(x, 0, iw, ih, mw, mh, vue)
            # Hors du monde jouable (le cadre de bois) : on garde l'image telle
            # quelle, la nappe animee ne va pas jusque-la.
            if dehors_y or not (0 <= cx < mw):
                sortie[d] = ipx[s]; sortie[d + 1] = ipx[s + 1]
                sortie[d + 2] = ipx[s + 2]; sortie[d + 3] = 255
                continue
            a = alpha[cz * mw + cx]
            r, v, b = ipx[s], ipx[s + 1], ipx[s + 2]
            if a < 255:
                # Un recif garde sa couleur meme au large : on le reconnait a
                # son ecart au bleu du large, pas a sa profondeur.
                ecart = max(abs(r - fond[0]), abs(v - fond[1]), abs(b - fond[2]))
                if ecart > ECART_RECIF:
                    a = 255
                    recifs += 1
            sortie[d] = r; sortie[d + 1] = v; sortie[d + 2] = b; sortie[d + 3] = a
    print("pixels rendus opaques comme recifs : %d" % recifs)

    opaques = sum(1 for i in range(iw * ih) if sortie[i * 4 + 3] == 255)
    print("opaque %.1f %%, transparent %.1f %%, en fondu %.1f %%" % (
        100.0 * opaques / (iw * ih),
        100.0 * sum(1 for i in range(iw * ih) if sortie[i * 4 + 3] == 0) / (iw * ih),
        100.0 * sum(1 for i in range(iw * ih)
                    if 0 < sortie[i * 4 + 3] < 255) / (iw * ih)))

    ci.ecrire_png(os.path.join(RACINE, "carte_cuite.png"), iw, ih, sortie, 4)
    print("carte_cuite.png reecrit en RGBA")

    # Le fond de mer va dans la fiche, pas dans le code : le moteur ne doit
    # recopier aucune constante de cadrage ni de couleur.
    chemin = os.path.join(RACINE, "carte_cuite.json")
    fiche = json.load(io.open(chemin, encoding="utf-8"))
    fiche["mer_fond"] = [fond[0] / 255.0, fond[1] / 255.0, fond[2] / 255.0]
    io.open(chemin, "w", encoding="utf-8", newline=NL).write(
        json.dumps(fiche, indent="\t", ensure_ascii=False) + NL)
    print("carte_cuite.json : mer_fond = %s" % (fiche["mer_fond"],))

    # LE PAS QU'ON OUBLIE, ET QUI EFFACE LA CARTE SANS RIEN DIRE.
    print()
    print("RELANCER ENSUITE : godot --headless --path . --import")
    print("   SANS QUOI LE DECOR DISPARAIT. Godot constate que la source a")
    print("   change, invalide son .ctex et NE LE RECONSTRUIT PAS -- le mode")
    print("   --script ne le fait pas non plus. `load()` rend alors null, plus")
    print("   rien n'est dessine, et il ne reste que la nappe de mer : un ecran")
    print("   uniformement bleu, sans une ile et sans erreur visible.")
    print()
    print("PUIS VERIFIER :")
    print("   godot --headless --path . --script res://outils/test_carte.gd")


if __name__ == "__main__":
    main()
