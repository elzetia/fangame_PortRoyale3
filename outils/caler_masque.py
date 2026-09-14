# -*- coding: utf-8 -*-
"""Le masque de navigation tombe-t-il sur la terre PEINTE ? Mesure, et recalage.

    py -3 outils/caler_masque.py              # mesure seulement, n'ecrit rien
    py -3 outils/caler_masque.py --ecrire     # pose le meilleur calage trouve

LE SYMPTOME QUI L'A FAIT ECRIRE. Un navire s'arrete en pleine eau, a bonne
distance du rivage peint : la zone navigable et le decor ne se superposent pas.
Les ports, eux, tombent juste -- ils vivent en cases du masque, comme la
navigation, donc ils partagent son erreur sans jamais la reveler.

D'OU VIENT L'ERREUR. Le calage en place a ete obtenu en faisant coincider deux
BOITES ENGLOBANTES de terre : celle de `ini/map.bmp` et celle du relief de PR3.
Or la terre du masque touche LES QUATRE BORDS du bitmap -- mesure : 1320/1320
cases sur la ligne du bas, 960/960 sur la colonne de gauche, zero marge vide.
Elle est donc TRONQUEE, quand celle du relief est entouree du cadre de bois et ne
l'est pas. Pire : une emprise qui remplit toute l'image ne dit RIEN de la
position du monde ; l'apparier a une autre n'est pas une mesure, c'est une
supposition.

CE QU'ON COMPARE. D'un cote le masque `sim/carte_monde.lua` (1320 x 960 cases,
tire de `ini/map.bmp`), de l'autre LA CARTE DE HAUTEURS de PR3, decodee un point
par bloc DXT1 -- 1536 x 1024, seize fois moins cher qu'un decodage complet et
deja plus fin que la grille de comparaison. Le relief partage le cadrage de la
carte peinte a 97,13 % (mesure), donc caler le masque sur le relief, c'est le
caler sur la peinture, sans dependre ni de l'alpha ni du pinceau.

LE PIEGE DU CADRE, paye une fois. Le cadre de bois de la texture est un gris
uniforme, tres au-dessus du seuil de terre : au premier jet, tout l'encadrement
comptait comme un continent, les profils etaient noyes et l'ajustement fuyait
vers un monde 26 % trop etroit -- moins bon que le calage qu'il devait corriger.
On se restreint donc a `champ_cote.CONTENU`, la zone utile mesuree deux fois
(emprise des terres et detection de cadre, memes nombres).

LA CONVENTION EST CELLE DU MOTEUR, relue dans `scripts/projection_carte.gd` et
non reconstituee. A l'angle 90 (sin = 1, cos = 0) :

    u = 0.5 + (x - centre.x) / vue_taille.x
    v = 0.5 + (z - centre.y) / vue_taille.y

et une case du masque vaut le monde  (c + 0.5 - n/2) * 12  sur chaque axe.

TROIS CANDIDATS SONT JUGES SUR LA MEME MESURE, plutot qu'un fit seul dont rien ne
dirait s'il vaut mieux que l'existant :

  1. la fiche en place ;
  2. LE CALAGE DE `champ_cote.py` -- qui n'est pas une supposition mais une
     mesure deja faite dans le projet, par maximisation de l'accord sur dix-sept
     mille points (87,8 %) ;
  3. un affinage qui descend sur l'accord lui-meme, a partir du meilleur des
     deux precedents. On a d'abord tente un ajustement par PROFILS de terre : il
     a echoue trois fois, et la troisieme SOUS le score trivial. La cause est la
     meme que plus haut -- la terre du masque touche les quatre bords, son profil
     est sature aux extremites, et aucune application lineaire ne l'accorde a
     celui du relief. Une methode qui rend du bruit n'a pas sa place parmi les
     candidats : elle a ete retiree, pas laissee en commentaire.

On affiche aussi ce que vaut un classeur trivial (« tout est mer ») : sans ce
repere, un accord de 70 % se lit comme un succes alors qu'il ne dit rien.

Aucune dependance : bibliotheque standard uniquement.
"""
import io
import json
import os
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PR3_MOD = r"D:\GOG Galaxy\Games\Port Royale 3\_mod\pr3"
sys.path.insert(0, os.path.join(RACINE, "outils"))
sys.path.insert(0, PR3_MOD)

import pr3fuk                                     # noqa: E402
import pr3map                                     # noqa: E402
from caler_carte import lire_masque_pr3           # noqa: E402
import champ_cote                                 # noqa: E402

FICHE = os.path.join(RACINE, "carte_cuite.json")
HAUTEUR = ("worldmaplefthght.dds", "worldmaprighthght.dds")

ECHELLE = 12.0          # unites de monde par case (sim/archipel.lua)
SEUIL_TERRE = 10        # au-dela, le relief est de la terre
NL = chr(10)


def relief_pr3():
    """La terre selon le relief de PR3 : (largeur, hauteur, binaire), en blocs."""
    jeu = pr3map.game()
    ar = pr3fuk.load(pr3map.orig(jeu, "data.fuk"))
    lire = lambda n: pr3fuk.content(ar, pr3fuk.find(ar, n))
    g, gw, gh = champ_cote._dds_blocs(lire(HAUTEUR[0]), 1)
    d, dw, dh = champ_cote._dds_blocs(lire(HAUTEUR[1]), 1)
    ar["f"].close()
    W, H = gw + dw, max(gh, dh)
    terre = bytearray(W * H)
    for y in range(H):
        for x in range(gw):
            terre[y * W + x] = 1 if g[y * gw + x] > SEUIL_TERRE else 0
        for x in range(dw):
            terre[y * W + gw + x] = 1 if d[y * dw + x] > SEUIL_TERRE else 0
    return W, H, terre


def bords(nom, m, w, x0, x1, y0, y1):
    """Dit si la terre TOUCHE les bords de la zone : une emprise tronquee ne
    peut pas servir de repere, et c'est toute l'histoire de ce fichier."""
    haut = sum(m[y0 * w + x] for x in range(x0, x1 + 1))
    bas = sum(m[y1 * w + x] for x in range(x0, x1 + 1))
    gauche = sum(m[y * w + x0] for y in range(y0, y1 + 1))
    droite = sum(m[y * w + x1] for y in range(y0, y1 + 1))
    nx, ny = x1 - x0 + 1, y1 - y0 + 1
    print("   %-18s haut %4d/%d  bas %4d/%d  gauche %4d/%d  droite %4d/%d"
          % (nom, haut, nx, bas, nx, gauche, ny, droite, ny))


def accord(masque, mw, mh, terre, W, zone, cx, cz, vx, vy, pas=2):
    """Part des blocs de la ZONE UTILE ou les deux terres disent la meme chose.

    Rend aussi la couverture : la part de la zone que le masque recouvre. Sans
    elle, un calage qui replierait le masque sur un coin passerait pour bon.
    """
    x0, x1, y0, y1 = zone
    # La hauteur se DEDUIT du tableau, elle ne se code pas en dur a cote d'une
    # largeur passee en parametre : les deux doivent venir de la meme source.
    H = len(terre) // W
    bons = total = couverts = 0
    for by in range(y0, y1 + 1, pas):
        v = (by + 0.5) / float(H)
        z = cz + (v - 0.5) * vy
        j = int(z / ECHELLE + mh / 2.0 - 0.5)
        dedans = 0 <= j < mh
        for bx in range(x0, x1 + 1, pas):
            u = (bx + 0.5) / float(W)
            x = cx + (u - 0.5) * vx
            i = int(x / ECHELLE + mw / 2.0 - 0.5)
            ok = dedans and 0 <= i < mw
            if ok:
                couverts += 1
            t = 1 if (ok and masque[j * mw + i]) else 0
            if t == terre[by * W + bx]:
                bons += 1
            total += 1
    return bons / float(total), couverts / float(total)


def vers_fiche(a, b, n_case, n_bloc):
    """(a, b) blocs<-cases  ->  (centre, vue) de cet axe. `b` en bloc PLEIN."""
    vue = ECHELLE * n_bloc / a
    centre = ECHELLE * (0.5 - n_case / 2.0) - ((b + 0.5) / n_bloc - 0.5) * vue
    return centre, vue


def affiner(masque, mw, mh, terre, W, zone, depart, passes=4):
    """Affine un calage en optimisant L'ACCORD LUI-MEME, pas un profil.

    POURQUOI PAS LES PROFILS. On a essaye, trois fois, et toujours le meme
    echec : la terre du masque TOUCHE LES QUATRE BORDS, donc son profil est
    sature aux extremites et aucune application lineaire ne peut l'accorder a
    celui du relief. L'ajustement fuyait vers un monde plus etroit et finissait
    SOUS le score trivial -- une mesure qui ne mesure rien. On descend donc
    directement sur la quantite qu'on cherche a maximiser.

    Descente par coordonnees : on pousse chaque parametre d'un pas, on garde ce
    qui ameliore, et on resserre le pas quand plus rien ne bouge. Le score se
    prend a `pas=4` pendant la recherche -- quatre fois moins de points, meme
    optimum -- et se reverifie a la resolution pleine ensuite.
    """
    p = list(depart)
    meilleur = accord(masque, mw, mh, terre, W, zone, *p, pas=4)[0]
    pas = [240.0, 240.0, 240.0, 240.0]      # unites de monde
    for _ in range(passes):
        ameliore = True
        while ameliore:
            ameliore = False
            for k in range(4):
                for signe in (1.0, -1.0):
                    q = list(p)
                    q[k] += signe * pas[k]
                    if q[2] <= 1.0 or q[3] <= 1.0:
                        continue
                    s = accord(masque, mw, mh, terre, W, zone, *q, pas=4)[0]
                    if s > meilleur + 1e-9:
                        p, meilleur = q, s
                        ameliore = True
        pas = [x / 3.0 for x in pas]
    return tuple(p)


def juger(nom, masque, mw, mh, terre, W, zone, cx, cz, vx, vy):
    a, couv = accord(masque, mw, mh, terre, W, zone, cx, cz, vx, vy)
    print("   %-24s accord %6.2f %%   couverture %5.1f %%" % (nom, 100.0 * a, 100.0 * couv))
    print("      centre [%9.1f, %9.1f]   vue_taille [%9.1f, %9.1f]"
          % (cx, cz, vx, vy))
    return a, (cx, cz, vx, vy)


def main():
    mw, mh, masque = lire_masque_pr3()
    W, H, terre = relief_pr3()
    zone = champ_cote.CONTENU          # (x_min, x_max, y_min, y_max), en blocs
    x0, x1, y0, y1 = zone
    print("masque %d x %d cases   relief %d x %d blocs" % (mw, mh, W, H))
    print("zone utile du relief (cadre exclu) : x %d..%d  y %d..%d" % (x0, x1, y0, y1))

    n_tout = sum(terre)
    n_zone = sum(terre[y * W + x] for y in range(y0, y1 + 1)
                 for x in range(x0, x1 + 1))
    aire = (x1 - x0 + 1) * (y1 - y0 + 1)
    print("   terre du relief : %.1f %% de l'image entiere, %.1f %% de la zone utile"
          % (100.0 * n_tout / (W * H), 100.0 * n_zone / aire))
    print("   (l'ecart entre les deux, c'est le CADRE compte comme terre)")
    print()
    print("=== la terre touche-t-elle les bords ? ===")
    bords("masque", masque, mw, 0, mw - 1, 0, mh - 1)
    bords("relief (zone utile)", terre, W, x0, x1, y0, y1)

    fiche = json.load(io.open(FICHE, encoding="utf-8"))
    print()
    print("=== LES CANDIDATS, juges sur la meme mesure ===")
    trivial, _ = accord(masque, mw, mh, terre, W, zone, 0.0, 0.0, 1e12, 1e12)
    print("   %-24s accord %6.2f %%   (repere : ne rien savoir)"
          % ("tout est mer", 100.0 * trivial))

    cx0, cz0 = fiche["centre"]
    vx0, vy0 = fiche["vue_taille"]
    a_fiche, p_fiche = juger("1. la fiche en place", masque, mw, mh, terre, W,
                             zone, cx0, cz0, vx0, vy0)

    # `champ_cote` a MESURE ce calage (87,8 % sur 17 000 points) : on le juge ici
    # dans la convention de la fiche, plutot que de refaire ce travail.
    cx1, vx1 = vers_fiche(champ_cote.BLOC_PAR_CASE_X, champ_cote.BLOC_X0, mw, W)
    cz1, vy1 = vers_fiche(champ_cote.BLOC_PAR_CASE_Y, champ_cote.BLOC_Y0, mh, H)
    a_cc, p_cc = juger("2. calage de champ_cote", masque, mw, mh, terre, W,
                       zone, cx1, cz1, vx1, vy1)

    # On repart du meilleur des deux, et on descend sur la mesure elle-meme.
    depart = p_cc if a_cc >= a_fiche else p_fiche
    p_aff = affiner(masque, mw, mh, terre, W, zone, depart)
    a_fit, p_fit = juger("3. affinage sur l'accord", masque, mw, mh, terre, W,
                         zone, *p_aff)

    classement = sorted([(a_fiche, "la fiche en place", p_fiche),
                         (a_cc, "le calage de champ_cote", p_cc),
                         (a_fit, "l'affinage sur l'accord", p_fit)],
                        reverse=True)
    best_a, best_nom, best_p = classement[0]
    print()
    print("=== VERDICT ===")
    print("   le meilleur est : %s (%.2f %%)" % (best_nom, 100.0 * best_a))
    if best_nom == "la fiche en place":
        print("   -> rien a changer : aucun candidat ne fait mieux que l'existant.")
    else:
        dx = (best_p[0] - cx0) / vx0 * fiche["pixels"][0]
        dy = (best_p[1] - cz0) / vy0 * fiche["pixels"][1]
        print("   -> gain %+.2f point(s) sur la fiche en place" % (100.0 * (best_a - a_fiche)))
        print("      la carte se deplacerait de %+.1f px en x, %+.1f px en y"
              % (-dx, -dy))
        print("      echelle x %+.2f %%, y %+.2f %%"
              % (100.0 * (best_p[2] / vx0 - 1.0), 100.0 * (best_p[3] / vy0 - 1.0)))

    if "--ecrire" not in sys.argv:
        print()
        print("Rien n'a ete ecrit. Relancer avec --ecrire pour poser le meilleur.")
        return
    if best_nom == "la fiche en place":
        print()
        print("REFUS : la fiche en place est deja la meilleure.")
        return
    fiche["centre"] = [round(best_p[0], 1), round(best_p[1], 1)]
    fiche["vue_taille"] = [round(best_p[2], 1), round(best_p[3], 1)]
    io.open(FICHE, "w", encoding="utf-8", newline=NL).write(
        json.dumps(fiche, indent="\t", ensure_ascii=False) + NL)
    print()
    print("carte_cuite.json reecrit avec : %s" % best_nom)
    print("RELANCER ENSUITE :")
    print("   py -3 outils/carte_eau.py        (la fiche commande l'alpha de la mer)")
    print("   py -3 outils/carte_mer.py        (et la fiche de profondeur)")
    print("   godot --headless --path . --import")
    print("   godot --headless --path . --script res://outils/test_minimap.gd")
    print("      ATTENTION : changer vue_taille rend FAUSSES les quatre constantes")
    print("      de cadrage de la minimap (hud_droite_pr3.gd). Le test affiche sous")
    print("      « MEILLEUR ajustement » celles qu'il faut y reecrire.")


if __name__ == "__main__":
    main()
