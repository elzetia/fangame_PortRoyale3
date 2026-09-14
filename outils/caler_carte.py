# -*- coding: utf-8 -*-
"""Cale l'ILLUSTRATION sous la GEOGRAPHIE DE PR3, et rend la fiche de projection.

LE PROBLEME, mesure et non suppose. Les soixante ports vivent en CASES du masque
de navigation `sim/carte_monde.lua`, qui est celui de Port Royale 3 (1320 x 960,
extrait de son `ini/map.bmp`). Le decor, lui, est une illustration (1488 x 976).
Les deux representent le MEME archipel -- on y reconnait Cuba, Hispaniola, l'arc
des Petites Antilles -- mais ils ne sont pas cales l'un sur l'autre.

La fiche `carte_cuite.json` dit `vue_taille = [15840, 10392]`. La largeur tombe
juste : 1320 cases x 12 unites = 15840. La HAUTEUR non : 960 x 12 = 11520, pas
10392. Ce 10392 vaut 866 x 12, et 866 est la hauteur qu'aurait un masque deduit
de L'ILLUSTRATION (1320 x 976/1488). Autrement dit la fiche a ete ecrite par
`carte_illustree.py`, qui suppose le masque tire du dessin, alors que le masque
en place vient de PR3. D'ou des ports 10 % trop hauts, un port hors cadre en
haut et 122 px de vide en bas.

LA REPARATION. On ne touche ni aux ports ni au masque : c'est la geographie du
jeu, et la minimap le confirme (ses pastilles tombent sur le littoral de
`hud_pc/12.png`, la carte de PR3). On recale le DESSIN dessous, ce que la fiche
sait exprimer avec exactement quatre nombres : `centre` (x, z) pour le decalage
et `vue_taille` (x, y) pour l'echelle.

LA METHODE. On cherche ces quatre nombres par la mesure, pas a l'oeil : celui
qui fait le mieux coincider la terre de PR3 avec la terre PEINTE. La silhouette
du dessin vient de `carte_illustree.silhouette` -- on reutilise la detection que
le projet a deja mise au point plutot que d'en ecrire une seconde qui
divergerait. Recherche grossiere puis affinee, trois passes.

    py -3 outils/caler_carte.py [--ecrire] [--image sortie.png]

Sans `--ecrire`, l'outil ne fait que MESURER et afficher : rien n'est modifie.

Aucune dependance : bibliotheque standard uniquement.
"""
import io
import json
import os
import re
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(RACINE, "outils"))

from decouper_planche import lire_png, ecrire_png      # noqa: E402
from carte_illustree import silhouette, ouvrir         # noqa: E402

CARTE = os.path.join(RACINE, "carte_cuite.png")
FICHE = os.path.join(RACINE, "carte_cuite.json")
MASQUE = os.path.join(RACINE, "sim", "carte_monde.lua")

ECHELLE = 12.0        # unites de monde par case (sim/archipel.lua)

# Resolution a laquelle on compare les deux terres. Assez fine pour que les
# petites Antilles comptent, assez grossiere pour qu'une recherche a plusieurs
# milliers de candidats tienne en Python.
CMP_L, CMP_H = 186, 122


def lire_masque_pr3():
    """(W, H, terre) depuis `sim/carte_monde.lua` : plages RLE, la premiere de MER."""
    texte = io.open(MASQUE, encoding="utf-8").read()
    m = re.search(r"Carte\.largeur,\s*Carte\.hauteur\s*=\s*(\d+)\s*,\s*(\d+)", texte)
    if not m:
        raise SystemExit("dimensions du masque introuvables")
    W, H = int(m.group(1)), int(m.group(2))
    corps = texte.split("Carte.plages", 1)[1]
    rangs = []
    for l in re.findall(r"\{([0-9,\s]*)\}", corps):
        nums = [int(n) for n in l.replace(" ", "").split(",") if n]
        if nums:
            rangs.append(nums)
        if len(rangs) == H:
            break
    if len(rangs) != H:
        raise SystemExit("%d rangs lus, %d attendus" % (len(rangs), H))
    terre = bytearray(W * H)
    for z, plages in enumerate(rangs):
        x, valeur = 0, 0
        for n in plages:
            if valeur:
                for k in range(x, min(W, x + n)):
                    terre[z * W + k] = 1
            x += n
            valeur = 1 - valeur
    return W, H, terre


def rogner_cadre(px, w, h):
    """Retire le CADRE DE BOIS d'une texture de carte, et rend (px, w, h, n).

    La carte du monde de PR3 est encadree de planches. Or `silhouette` tranche
    « la mer est bleue, le reste ne l'est pas » : le bois passe donc pour de la
    TERRE sur les quatre bords, et il tire l'ajustement. On le retire.

    On le reconnait a ce qu'il est UNIFORME : une ligne de cadre varie peu le
    long de son parcours, une ligne de carte beaucoup. On avance depuis chaque
    bord tant que la variance reste basse, et on garde la plus grande marge des
    quatre -- le cadre est le meme tout autour.
    """
    def variance(indices):
        n = len(indices)
        s = s2 = 0
        for i in indices:
            v = (px[i * 4] + px[i * 4 + 1] + px[i * 4 + 2]) // 3
            s += v
            s2 += v * v
        return s2 / n - (s / n) ** 2

    SEUIL = 120.0        # variance au-dela de laquelle on est dans la carte
    marges = []
    for bord in range(4):
        n = 0
        while n < min(w, h) // 4:
            if bord == 0:
                idx = [n * w + x for x in range(0, w, 4)]
            elif bord == 1:
                idx = [(h - 1 - n) * w + x for x in range(0, w, 4)]
            elif bord == 2:
                idx = [y * w + n for y in range(0, h, 4)]
            else:
                idx = [y * w + (w - 1 - n) for y in range(0, h, 4)]
            if variance(idx) > SEUIL:
                break
            n += 1
        marges.append(n)
    n = max(marges)
    print("   cadre detecte : haut %d, bas %d, gauche %d, droite %d -> on rogne %d"
          % (marges[0], marges[1], marges[2], marges[3], n))
    if n <= 0:
        return px, w, h, 0
    nw, nh = w - 2 * n, h - 2 * n
    out = bytearray(nw * nh * 4)
    for y in range(nh):
        s = ((y + n) * w + n) * 4
        d = y * nw * 4
        out[d:d + nw * 4] = px[s:s + nw * 4]
    return out, nw, nh, n


def rogner_uniforme(px, w, h, tol=6):
    """Retire un cadre de couleur CONSTANTE, et rend (px, w, h, n).

    `rogner_cadre` cherchait une variance basse : sur le cadre de BOIS de la
    carte peinte, le grain la fait grimper aussitot, la detection s'arretait a
    31 px et l'ajustement en sortait pire (72 % contre 79 %). Le cadre de la
    carte de RELIEF, lui, est un gris parfaitement uniforme : on avance tant que
    la ligne reste a `tol` pres de la couleur du coin.
    """
    def gris(i):
        return (px[i * 4] + px[i * 4 + 1] + px[i * 4 + 2]) // 3

    ref = gris(0)

    def uniforme(idx):
        return all(abs(gris(i) - ref) <= tol for i in idx)

    marges = []
    for bord in range(4):
        n = 0
        while n < min(w, h) // 3:
            if bord == 0:
                idx = [n * w + x for x in range(0, w, 4)]
            elif bord == 1:
                idx = [(h - 1 - n) * w + x for x in range(0, w, 4)]
            elif bord == 2:
                idx = [y * w + n for y in range(0, h, 4)]
            else:
                idx = [y * w + (w - 1 - n) for y in range(0, h, 4)]
            if not uniforme(idx):
                break
            n += 1
        marges.append(n)
    n = max(marges)
    print("   cadre uniforme (gris %d) : haut %d, bas %d, gauche %d, droite %d"
          % (ref, marges[0], marges[1], marges[2], marges[3]))
    if n <= 0:
        return px, w, h, 0
    nw, nh = w - 2 * n, h - 2 * n
    out = bytearray(nw * nh * 4)
    for y in range(nh):
        s = ((y + n) * w + n) * 4
        d = y * nw * 4
        out[d:d + nw * 4] = px[s:s + nw * 4]
    return out, nw, nh, n


def masque_relief(px, w, h, dw, dh, seuil=10):
    """Terre/mer depuis une carte de RELIEF, echantillonnee en dw x dh.

    POURQUOI LE RELIEF PLUTOT QUE LA CARTE PEINTE. `silhouette` tranche sur la
    couleur (« la mer est bleue, le reste ne l'est pas ») : les plages claires,
    les hauts-fonds turquoise et le cadre de bois en font un signal bruite, et
    l'ajustement plafonnait a 79 % avec des ports encore en pleine eau. Un
    relief, lui, est NOIR en mer (gris median 1) et clair sur terre : la
    frontiere est franche, et l'on compare enfin du binaire a du binaire.
    """
    terre = bytearray(dw * dh)
    for cz in range(dh):
        y0 = cz * h // dh
        y1 = max(y0 + 1, (cz + 1) * h // dh)
        for cx in range(dw):
            x0 = cx * w // dw
            x1 = max(x0 + 1, (cx + 1) * w // dw)
            s = n = 0
            for y in range(y0, y1):
                base = y * w
                for x in range(x0, x1):
                    i = (base + x) * 4
                    s += (px[i] + px[i + 1] + px[i + 2]) // 3
                    n += 1
            terre[cz * dw + cx] = 1 if s // n > seuil else 0
    return terre


def reduire(src, sw, sh, dw, dh):
    """Sous-echantillonne un masque binaire au plus proche voisin."""
    out = bytearray(dw * dh)
    for y in range(dh):
        sy = min(sh - 1, y * sh // dh)
        for x in range(dw):
            out[y * dw + x] = src[sy * sw + min(sw - 1, x * sw // dw)]
    return out


def accord(terre_pr3, W, H, ill, a, b, c, d):
    """Part des points de comparaison ou les deux terres s'accordent.

    On parcourt la grille de COMPARAISON (celle du dessin) et on demande a PR3
    ce qu'il y a au meme endroit : c'est l'inverse du placement, mais cela borne
    le cout, qui ne depend alors plus de l'echelle essayee.
    """
    bons = 0
    for y in range(CMP_H):
        py = (y + 0.5) * 976.0 / CMP_H
        j = int((py - d) / c)
        ligne = j * W
        dedans_j = 0 <= j < H
        base = y * CMP_L
        for x in range(CMP_L):
            px = (x + 0.5) * 1488.0 / CMP_L
            i = int((px - b) / a)
            t = 1 if (dedans_j and 0 <= i < W and terre_pr3[ligne + i]) else 0
            if t == ill[base + x]:
                bons += 1
    return bons / float(CMP_L * CMP_H)


def profil(masque, w, h, selon_x):
    """Part de terre par colonne (selon_x) ou par ligne."""
    if selon_x:
        return [sum(masque[j * w + i] for j in range(h)) / float(h)
                for i in range(w)]
    return [sum(masque[j * w + i] for i in range(w)) / float(w)
            for j in range(h)]


def caler_axe(src, n_src, cible, n_cible, taille_img):
    """Cale un axe seul : rend (a, b) tel que pixel = a * case + b.

    UNE RECHERCHE CONJOINTE SUR LES QUATRE NOMBRES EST IMPOSSIBLE ICI : treize
    valeurs par parametre font 13^4 candidats par passe, et chacun coute 22 692
    points de comparaison -- pres de deux milliards d'operations. Or dans cette
    projection l'horizontale ne depend que de x et la verticale que de z : les
    deux axes se calent donc SEPAREMENT, en comparant les profils de terre. Le
    cout tombe a quelques milliers d'operations, et l'affinage conjoint qui suit
    n'a plus qu'un petit voisinage a explorer.
    """
    a0 = taille_img / float(n_src)
    plage_a, plage_b = 0.40 * a0, 0.30 * taille_img
    meilleur = (-1.0, a0, 0.0)
    for _ in range(4):
        pas_a, pas_b = plage_a / 8.0, plage_b / 8.0
        _, ca, cb = meilleur if meilleur[0] >= 0.0 else (0.0, a0, 0.0)
        for ia in range(-8, 9):
            a = ca + ia * pas_a
            if a <= 0.05:
                continue
            for ib in range(-8, 9):
                b = cb + ib * pas_b
                ecart = 0.0
                for k in range(n_cible):
                    p = (k + 0.5) * taille_img / n_cible
                    i = int((p - b) / a)
                    v = src[i] if 0 <= i < n_src else 0.0
                    ecart += abs(v - cible[k])
                s = 1.0 - ecart / n_cible
                if s > meilleur[0]:
                    meilleur = (s, a, b)
        plage_a, plage_b = plage_a / 3.0, plage_b / 3.0
    return meilleur


def chercher(terre_pr3, W, H, ill):
    """D'abord chaque axe par son profil, puis un affinage CONJOINT.

    Les profils donnent l'echelle et le decalage a peu de frais, mais ils
    ignorent la forme : deux archipels de meme repartition mais de dessin
    different les satisferaient. L'affinage conjoint, lui, compare case a case --
    on ne peut se le permettre que sur un petit voisinage, ce que les profils
    viennent precisement de fournir.
    """
    sx, a, b = caler_axe(profil(terre_pr3, W, H, True), W,
                         profil(ill, CMP_L, CMP_H, True), CMP_L, 1488.0)
    sy, c, d = caler_axe(profil(terre_pr3, W, H, False), H,
                         profil(ill, CMP_L, CMP_H, False), CMP_H, 976.0)
    print("   profils : x %.3f (a %.4f  b %.1f)   y %.3f (c %.4f  d %.1f)"
          % (sx, a, b, sy, c, d))

    meilleur = (accord(terre_pr3, W, H, ill, a, b, c, d), a, b, c, d)
    print("   accord initial : %.3f" % meilleur[0])
    pa, pb, pc, pd = 0.04 * a, 0.05 * 1488.0, 0.04 * c, 0.05 * 976.0
    for passe in range(3):
        _, ca, cb, cc, cd = meilleur
        for ia in range(-2, 3):
            for ib in range(-2, 3):
                for ic in range(-2, 3):
                    for idd in range(-2, 3):
                        aa = ca + ia * pa / 2.0
                        bb = cb + ib * pb / 2.0
                        ccc = cc + ic * pc / 2.0
                        dd = cd + idd * pd / 2.0
                        if aa <= 0.05 or ccc <= 0.05:
                            continue
                        s = accord(terre_pr3, W, H, ill, aa, bb, ccc, dd)
                        if s > meilleur[0]:
                            meilleur = (s, aa, bb, ccc, dd)
        pa, pb, pc, pd = pa / 3.0, pb / 3.0, pc / 3.0, pd / 3.0
        print("   affinage %d : accord %.3f   a %.4f  b %.1f  c %.4f  d %.1f"
              % (passe + 1, meilleur[0], meilleur[1], meilleur[2],
                 meilleur[3], meilleur[4]))
    return meilleur


def vers_fiche(a, b, c, d, W, H, iw, ih):
    """(a, b, c, d) pixels<-cases  ->  centre et vue_taille de la fiche.

    `vers_carte` pose  px = iw * (0.5 + (x - cx) / vue_x)  avec x = (i - W/2)*E.
    D'ou  a = iw * E / vue_x  et  px(0) = b = iw * (0.5 - (W/2 * E + cx) / vue_x).
    """
    vue_x = iw * ECHELLE / a
    vue_y = ih * ECHELLE / c
    cx = (0.5 - b / iw) * vue_x - (W / 2.0) * ECHELLE
    cz = (0.5 - d / ih) * vue_y - (H / 2.0) * ECHELLE
    return cx, cz, vue_x, vue_y


def _arg(nom, defaut=None):
    return sys.argv[sys.argv.index(nom) + 1] if nom in sys.argv else defaut


def main():
    ecrire = "--ecrire" in sys.argv
    sortie_img = _arg("--image")
    # `--carte` : caler le masque sur une AUTRE image que `carte_cuite.png`.
    # C'est ainsi qu'on essaie la vraie carte du monde de PR3
    # (`textures/worldmapleft.dds` + `worldmapright.dds` assemblees), qui vient
    # de la meme source que le masque et devrait donc s'accorder bien mieux que
    # l'illustration etrangere -- laquelle plafonnait a 71,8 %, soit a peine
    # au-dessus du score trivial d'un « tout est mer ».
    carte = _arg("--carte", CARTE)
    if ecrire and carte != CARTE:
        print("refus : --ecrire n'a de sens que pour carte_cuite.png")
        return

    # `--relief` : caler sur la carte de RELIEF de PR3 plutot que sur une carte
    # peinte. C'est le meme monde, mais le signal est franc -- mer noire, terre
    # claire -- la ou la couleur brouille tout. Son cadre, lui, est un gris
    # uniforme : on peut enfin le rogner proprement.
    relief = _arg("--relief")
    source = relief or carte
    iw, ih, ipx = lire_png(source)
    print("image calee : %s (%dx%d)" % (os.path.basename(source), iw, ih))
    if relief:
        ipx, iw, ih, _marge = rogner_uniforme(ipx, iw, ih)
        print("   relief rogne : %dx%d (rapport %.4f)"
              % (iw, ih, iw / float(ih)))
    # `--rogner` : retirer le cadre de bois avant de caler. La fiche rendue
    # decrit alors l'image ROGNEE -- ce qui est bien ce qu'on veut, puisque
    # c'est elle qu'on afficherait.
    if "--rogner" in sys.argv:
        ipx, iw, ih, marge = rogner_cadre(ipx, iw, ih)
        print("   apres rognage : %dx%d (rapport %.4f)" % (iw, ih, iw / float(ih)))
    W, H, terre = lire_masque_pr3()
    print("illustration %dx%d   masque PR3 %dx%d" % (iw, ih, W, H))
    print("   monde selon le masque : %.0f x %.0f"
          % (W * ECHELLE, H * ECHELLE))
    fiche = json.load(io.open(FICHE, encoding="utf-8"))
    print("   vue_taille de la fiche : %.0f x %.0f"
          % (fiche["vue_taille"][0], fiche["vue_taille"][1]))

    print("silhouette de la source (%dx%d)..." % (CMP_L, CMP_H))
    if relief:
        # Pas d'`ouvrir` ici : le relief ne seme ni reflets ni flaques, et
        # nettoyer un signal deja net ne ferait que ronger les petites iles.
        ill = masque_relief(ipx, iw, ih, CMP_L, CMP_H)
    else:
        ill = ouvrir(silhouette(ipx, iw, ih, CMP_L, CMP_H), CMP_L, CMP_H)
    print("   terre peinte : %.1f %%" % (100.0 * sum(ill) / (CMP_L * CMP_H)))
    print("   terre PR3    : %.1f %%" % (100.0 * sum(terre) / (W * H)))

    print("recherche du calage :")
    s, a, b, c, d = chercher(terre, W, H, ill)
    cx, cz, vue_x, vue_y = vers_fiche(a, b, c, d, W, H, iw, ih)
    print("\n=== calage retenu : accord %.1f %% ===" % (100.0 * s))
    print("   centre      [%.1f, %.1f]" % (cx, cz))
    print("   vue_taille  [%.1f, %.1f]" % (vue_x, vue_y))
    print("   (la fiche actuelle : centre %s, vue_taille %s)"
          % (fiche["centre"], fiche["vue_taille"]))

    if sortie_img:
        out = bytearray(iw * ih * 4)
        for i in range(iw * ih):
            out[i * 4:i * 4 + 4] = ipx[i * 4:i * 4 + 4]
            out[i * 4 + 3] = 255
        for y in range(ih):
            j = int((y - d) / c)
            if not (0 <= j < H):
                continue
            ligne = j * W
            for x in range(iw):
                i = int((x - b) / a)
                if 0 <= i < W and terre[ligne + i]:
                    o = (y * iw + x) * 4
                    out[o] = (out[o] + 510) // 3
                    out[o + 1] //= 3
                    out[o + 2] //= 3
        ecrire_png(sortie_img, iw, ih, out)
        print("   -> %s" % sortie_img)

    if ecrire:
        fiche["centre"] = [round(cx, 1), round(cz, 1)]
        fiche["vue_taille"] = [round(vue_x, 1), round(vue_y, 1)]
        io.open(FICHE, "w", encoding="utf-8", newline=chr(10)).write(
            json.dumps(fiche, indent=1, ensure_ascii=False) + chr(10))
        print("   carte_cuite.json REECRIT")
    else:
        print("   (rien n'a ete modifie ; --ecrire pour appliquer)")


if __name__ == "__main__":
    main()
