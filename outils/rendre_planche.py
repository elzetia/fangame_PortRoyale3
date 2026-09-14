"""Rend une planche d'interface en PNG, pour la REGARDER.

Le HUD a ete verifie par des NOMBRES -- positions comparees au pixel, compteurs
de noeuds, libelles compares a la table du jeu. Des composites ponctuels ont bien
ete bricoles en cours de route, mais aucun outil versionne ne refait l'operation
a volonte : `comparer_maquette.py` superpose un rendu deja produit a une
maquette, `planche_contact.py` assemble des sprites deja decoupes, et Godot cale
en mode fenetre sur cette machine, ce qui interdit la capture.

D'ou ce compositeur, qui rejoue EN PYTHON ce que `scripts/ecran_pr3.gd` fait
dans Godot, a partir des memes fichiers :

  * `agencement/<swf>.json`      quelles classes, a quelles coordonnees
  * `agencement/icones_couches.txt`  une classe -> ses images EMPILEES
  * `agencement/icones.txt`      une classe -> son image, quand elle est seule
  * `<swf>/caracteres.txt`       un charId ANONYME -> son bitmap, table par .swf
  * `skinlib_pr3/*.png`, `<swf>/*.png`   l'art extrait

DEUX PIEGES, tous deux payes comptant lors du premier essai :

1. LES CARACTERES ANONYMES. `charNNN` ne dit rien par son nom et n'est pas dans
   la table des icones : sa table vit A COTE DES PNG DU .SWF, pas dans le dossier
   d'agencement. Sans elle, la planche droite sortait avec ses seuls boutons --
   ni bois, ni carte, ni barre d'XP, qui tiennent presque entierement a des
   `char`.

2. LES MASQUES. Un `Mask_*` / `Maske_*` est de la geometrie qui DECOUPE, et sa
   forme est un aplat noir opaque. Le peindre poserait un carre noir sur la
   minimap. On ne descend pas dedans et on ne le dessine pas.

UNE SUBTILITE QUI SIMPLIFIE TOUT. Dans `EcranPR3`, `_pile()` pose sa racine au
coin de l'UNION des couches et chaque couche relativement a ce coin, puis
`batir()` ajoute le point de placement. Le coin s'annule : une couche atterrit
donc exactement en `(x + dx, y + dy)`.

CE QUE CE RENDU NE MONTRE PAS : le texte (l'or, le rang, la date) et tout ce que
la simulation pose au runtime -- pastilles de villes, traces de route, cadre de
vue. On voit l'ART, c'est-a-dire ce qui vient du jeu.

    py -3 outils/rendre_planche.py hud_pc Hud_pc_fla.Hud_Woodboard_Right_3 sortie.png [profondeur]

Aucune dependance : bibliotheque standard uniquement.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from decouper_planche import lire_png, ecrire_png

REF = r"D:\GOG Galaxy\Games\PortRoyale3D\reference_pr3\ui"
AGENCEMENT = os.path.join(REF, "agencement")
SKIN = os.path.join(REF, "skinlib_pr3")

# Les memes exclusions que `EcranPR3.RUNTIME` : des conteneurs que PR3 remplit a
# l'execution, et dont tous les membres sont empiles au meme point d'auteur.
RUNTIME = {
    "Minimap_Steadte_Liste_14",
    "Visual_Minimap_Frame",
    "Visual_Minimap_Mc_Objects",
    "Visual_CustomRender",
    "Visual_CustomRender_Minimap",
    "Visual_TooltipContainer",
}

# Ce qui ne doit JAMAIS se peindre (meme liste que `EcranPR3._noeud`).
SANS_ART = ("Visual_Button_Empty", "Button_Mask", "Mask_", "Maske_")

_images = {}


def court(classe):
    return classe.split(".")[-1]


def rejouable(classe):
    c = court(classe)
    if c in RUNTIME:
        return False
    return "Mask_" not in c and "Maske_" not in c


def _table(chemin, col_fichier, col_dx, mini, multi):
    """Lit une table tabulee : cle -> (fichier, dx, dy), ou -> [(...)] si
    plusieurs lignes peuvent porter la meme cle."""
    out = {}
    if not os.path.exists(chemin):
        return out
    with open(chemin, encoding="utf-8") as f:
        for ligne in f:
            b = ligne.rstrip("\r\n").split("\t")
            if len(b) < mini:
                continue
            cle = b[0].strip()
            val = (b[col_fichier].strip(), float(b[col_dx]), float(b[col_dx + 1]))
            if multi:
                out.setdefault(cle, []).append(val)
            else:
                out.setdefault(cle, val)
    return out


def image(dossier, fichier):
    """(w, h, px RGBA) ou None. Repli .jpg comme `SkinPR3.texture` : 14 des 969
    entrees n'existent QUE sous cette extension."""
    base = fichier.replace(".png", "")
    cle = (dossier, base)
    if cle in _images:
        return _images[cle]
    trouve = None
    for ext in (".png", ".jpg"):
        p = os.path.join(dossier, base + ext)
        if os.path.exists(p):
            try:
                trouve = lire_png(p)
            except Exception:
                trouve = None
            break
    _images[cle] = trouve
    return trouve


def echelonner(src, sx, sy):
    """Au plus proche voisin. Les rares elements mis a l'echelle par le .swf
    sortiraient sinon a leur taille d'origine, donc a la mauvaise place."""
    w, h, px = src
    nw, nh = max(1, int(round(w * sx))), max(1, int(round(h * sy)))
    if (nw, nh) == (w, h):
        return src
    out = bytearray(nw * nh * 4)
    for y in range(nh):
        sy0 = min(h - 1, y * h // nh)
        for x in range(nw):
            sx0 = min(w - 1, x * w // nw)
            o, i = (y * nw + x) * 4, (sy0 * w + sx0) * 4
            out[o:o + 4] = px[i:i + 4]
    return (nw, nh, out)


def resoudre(classe, tables, dossier_swf):
    """Les images d'une classe : [(fichier, dx, dy, dossier)]. L'ordre suit
    `EcranPR3._noeud` -- caracteres anonymes d'abord, puis l'empilement, puis la
    table a une seule feuille."""
    c = court(classe)
    if c.startswith("char") and c[4:].isdigit():
        v = tables["caracteres"].get(c[4:])
        return [(v[0], v[1], v[2], dossier_swf)] if v else []
    liste = tables["couches"].get(c)
    if liste:
        return [(f, dx, dy, SKIN) for f, dx, dy in liste]
    v = tables["icones"].get(c)
    return [(v[0], v[1], v[2], SKIN)] if v else []


def collecter(ecrans, tables, dossier_swf, scene, profondeur, ox, oy,
              sortie, manques):
    """Aplatit la scene en (x, y, image, classe) de l'arriere vers l'avant --
    l'ordre du fichier est deja l'ordre de profondeur."""
    for el in ecrans.get(scene, []):
        if el.get("type") == "texte" or int(el.get("img", 0) or 0) > 0:
            continue
        classe = el.get("classe") or ""
        x = ox + float(el.get("x", 0.0))
        y = oy + float(el.get("y", 0.0))
        if profondeur > 0 and classe in ecrans and rejouable(classe):
            collecter(ecrans, tables, dossier_swf, classe, profondeur - 1,
                      x, y, sortie, manques)
            continue
        if any(s in classe for s in SANS_ART):
            continue
        trouvees = resoudre(classe, tables, dossier_swf)
        if not trouvees:
            manques.add(court(classe))
            continue
        sx = float(el.get("sx", 1.0) or 1.0)
        sy = float(el.get("sy", 1.0) or 1.0)
        for fichier, dx, dy, dossier in trouvees:
            im = image(dossier, fichier)
            if im is None:
                manques.add(fichier)
                continue
            if sx != 1.0 or sy != 1.0:
                im = echelonner(im, sx, sy)
            sortie.append((x + dx, y + dy, im, court(classe)))


def composer(pieces, marge=8):
    x0 = min(p[0] for p in pieces) - marge
    y0 = min(p[1] for p in pieces) - marge
    x1 = max(p[0] + p[2][0] for p in pieces) + marge
    y1 = max(p[1] + p[2][1] for p in pieces) + marge
    W, H = int(round(x1 - x0)), int(round(y1 - y0))
    # Damier : sans lui, on ne distingue pas du bois sombre d'un fond vide, ni
    # une zone transparente d'une zone noire.
    out = bytearray(W * H * 4)
    for y in range(H):
        for x in range(W):
            o = (y * W + x) * 4
            v = 60 if ((x // 8) + (y // 8)) % 2 else 82
            out[o] = out[o + 1] = out[o + 2] = v
            out[o + 3] = 255

    for px0, py0, (w, h, px), _cl in pieces:
        bx, by = int(round(px0 - x0)), int(round(py0 - y0))
        for y in range(h):
            dy = by + y
            if not (0 <= dy < H):
                continue
            base_s = y * w * 4
            base_d = dy * W * 4
            for x in range(w):
                dx = bx + x
                if not (0 <= dx < W):
                    continue
                i = base_s + x * 4
                a = px[i + 3]
                if a == 0:
                    continue
                o = base_d + dx * 4
                if a == 255:
                    out[o:o + 3] = px[i:i + 3]
                else:
                    for k in range(3):
                        out[o + k] = (px[i + k] * a + out[o + k] * (255 - a)) // 255
    return W, H, out, x0, y0


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        return
    swf, scene, dst = sys.argv[1], sys.argv[2], sys.argv[3]
    profondeur = int(sys.argv[4]) if len(sys.argv) > 4 else 4
    dossier_swf = os.path.join(REF, swf)

    d = json.load(open(os.path.join(AGENCEMENT, swf + ".json"), encoding="utf-8"))
    ecrans = d.get("ecrans", {})
    if scene not in ecrans:
        print(f"scene « {scene} » absente. Quelques scenes du fichier :")
        for s in list(ecrans)[:25]:
            print("   ", s)
        return

    tables = {
        # classe -> [(fichier, dx, dy)] : colonnes 0, 2, 4, 5
        "couches": _table(os.path.join(AGENCEMENT, "icones_couches.txt"), 2, 4, 6, True),
        # classe -> (fichier, dx, dy) : colonnes 0, 1, 3, 4
        "icones": _table(os.path.join(AGENCEMENT, "icones.txt"), 1, 3, 5, False),
        # charId -> (fichier, dx, dy) : colonnes 0, 1, 3, 4
        "caracteres": _table(os.path.join(dossier_swf, "caracteres.txt"), 1, 3, 5, False),
    }

    pieces, manques = [], set()
    collecter(ecrans, tables, dossier_swf, scene, profondeur, 0.0, 0.0,
              pieces, manques)
    if not pieces:
        print("aucune image : rien a composer")
        return

    W, H, px, x0, y0 = composer(pieces)
    ecrire_png(dst, W, H, px)
    print(f"{len(pieces)} couche(s) posee(s), {W}x{H}, origine ({x0:.0f}, {y0:.0f})")
    print(f"   tables : {len(tables['couches'])} classes en couches, "
          f"{len(tables['icones'])} icones, "
          f"{len(tables['caracteres'])} caracteres de {swf}")
    print(f"   -> {dst}")
    if manques:
        print(f"   {len(manques)} classe(s) sans art : "
              + ", ".join(sorted(manques)[:14]))


if __name__ == "__main__":
    main()
