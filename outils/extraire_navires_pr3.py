"""Extrait de Port Royale 3 les navires de la carte du monde.

PR3 garde deux versions de chaque navire : l'une pour les batailles, détaillée,
en plusieurs pièces et deux textures ; l'autre pour la carte, suffixée `_wm`
(« world map »), d'une seule pièce et de quelques centaines de sommets. C'est
celle-ci qu'on veut : elle est faite pour être vue de loin, comme les nôtres.

Les seize navires de carte partagent UNE texture, `textures/0_ships_wm.dds`, et
leurs couleurs de sommets ne sont qu'une occlusion en niveaux de gris. Leurs
fiches `.mesh` ne nomment aucune texture : le lien passe par le matériau
`materials/ship_wm.mat`.

Tout est écrit dans `reference_pr3/navires_wm/`, ignoré par git : ces modèles
sont sous droits et servent en local, le temps que le projet ait les siens.
`outils/rendre_navires_pr3.gd` en fait ensuite les atlas de la carte.

    py -3 outils/extraire_navires_pr3.py
"""
import os
import re
import sys

JEU = r"D:\GOG Galaxy\Games\Port Royale 3"
PROJET = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SORTIE = os.path.join(PROJET, "reference_pr3", "navires_wm")

sys.path.insert(0, os.path.join(JEU, "_mod"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import unfuk                                  # noqa: E402
from dds2png import lire_dds, ecrire_png      # noqa: E402

TEXTURE = "textures/0_ships_wm.dds"


def main():
    # `data0.fuk` est le correctif officiel : il remplace des fichiers de
    # `data.fuk` (la caraque de carte, par exemple). On lit donc le correctif en
    # dernier, et il écrase.
    fichiers = {}
    for archive in ("data.fuk", "data0.fuk"):
        f, entrees = unfuk.parse(os.path.join(JEU, archive))
        for e in entrees:
            if re.match(r"assets/[a-z]+_wm/[^/]+\.(vbuf|ibuf|mesh)$", e["path"]) \
                    or e["path"] == TEXTURE:
                fichiers[e["path"]] = unfuk.read(f, e)

    modeles = set()
    for chemin, octets in fichiers.items():
        if chemin == TEXTURE:
            continue
        dossier, nom = chemin.split("/")[1:]
        modeles.add(dossier)
        os.makedirs(os.path.join(SORTIE, dossier), exist_ok=True)
        with open(os.path.join(SORTIE, dossier, nom), "wb") as sortie:
            sortie.write(octets)

    dds = os.path.join(SORTIE, "0_ships_wm.dds")
    with open(dds, "wb") as sortie:
        sortie.write(fichiers[TEXTURE])
    w, h, _, rgba = lire_dds(dds)
    # Le canal alpha de cette texture est constant (64) : ce n'est pas une
    # transparence. On l'écrit opaque, sinon toute la coque sort translucide.
    rgba = bytearray(rgba)
    rgba[3::4] = b"\xff" * (len(rgba) // 4)
    ecrire_png(os.path.join(SORTIE, "0_ships_wm.png"), w, h, rgba)

    print(f"{len(modeles)} navires et la texture {w}x{h} -> {SORTIE}")


if __name__ == "__main__":
    main()
