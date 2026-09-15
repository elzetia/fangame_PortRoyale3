# -*- coding: utf-8 -*-
"""Sort de Port Royale 3 les BATIMENTS de ville, et en rend les vignettes.

    py -3 outils/extraire_batiments_pr3.py [--taille N] [--angle A]

Ecrit les maillages dans `reference_pr3/batiments/<nom>/` et les vignettes dans
`reference_pr3/ui/batiments/<nom>.png`, ou `SkinPR3.texture("batiments/<nom>")`
va les chercher.

POURQUOI. Le menu radial de PR3 montre sur chaque petale le BATIMENT de la ville
-- phare, eglise, taverne, hotel de ville, chantier, entrepot -- la ou le notre
n'affiche qu'un mot. Ces illustrations N'EXISTENT PAS comme images : j'ai cherche
dans les 171 dossiers d'interface extraits (balayage par taille), dans les
`textures/` de l'archive (105 entrees hors terrain, toutes du materiel moteur),
et dans `rendertarget/` (plomberie : miroirs, ombres, refraction). Rien.

PR3 les rend depuis ses MODELES 3D. On fait donc pareil, avec l'outil que le
projet a deja : `outils/pr3_mesh.py` lit le format de maillage -- il connait le
pas de 16 octets des batiments autant que celui de 80 des navires -- et en rend
une vignette en plongee. C'est la meme recette que `rendre_navires_pr3.gd` pour
les navires de la carte.

CE QUI EST SUR, ET CE QUI NE L'EST PAS. Les noms viennent de la table de textes
du jeu (`ID_GUI_BUILDING_*`) croisee avec les noms d'assets :

    Capitainerie    lighthouse      ID_GUI_BUILDING_LIGHTHOUSE = « Capitainerie »
    Eglise          church0_<nat>   ID_GUI_BUILDING_CHURCH
    Taverne         tavern
    Hotel de ville  administration0_<nat>
    Entrepot        depot           ID_GUI_BUILDING_DEPOT = « Entrepot »
    Chantier naval  dockyard0
    Docks           port0

Les deux derniers etaient un choix a verifier, « dockyard » se lisant aussi bien
chantier que dock. VERIFIE EN REGARDANT LES RENDUS : `port0` est une plate-forme
a pilotis avec platelage -- un quai, donc les Docks -- et `dockyard0` l'ensemble
industriel a echafaudages, donc le chantier. Leurs boites englobantes le disent
aussi : seuls ces deux modeles descendent SOUS le zero (y_min -8,85 et -7,79),
comme il se doit pour des pilotis dans l'eau.

LE DECODAGE DES MAILLAGES A ETE EPROUVE sur les six modeles : pas de 16 octets
partout, le tampon divise EXACTEMENT (aucun reste), et chaque boite englobante
est plausible -- le phare est haut et mince (5,9 x 23,2 x 5,7), les batiments
poses au sol ont y_min = 0. Six coherences de ce genre ne sont pas un hasard.
J'avais d'abord cru la geometrie cassee en voyant les vignettes : c'est la
LISIBILITE qui manque, pas les donnees.

VARIANTES PAR NATION : l'eglise et l'hotel de ville en ont une par pavillon
(`_en`, `_fr`, `_nl`, `_sp`, plus `_pl` pour le Polonais du jeu). Le Portugal de
notre simulation n'en a pas -- il retombe sur l'espagnole, la plus proche.

L'art est celui de Port Royale 3 -- (c) Kalypso / Gaming Minds -- donc il ne peut
pas entrer dans un depot public : tout vit dans `reference_pr3/`, ignore par git.
On versionne l'OUTIL, jamais sa sortie.

Aucune dependance : bibliotheque standard, plus `outils/pr3_mesh.py` du projet.
"""
import os
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PR3_MOD = r"D:\GOG Galaxy\Games\Port Royale 3\_mod\pr3"
sys.path.insert(0, PR3_MOD)
sys.path.insert(0, os.path.join(RACINE, "outils"))

import pr3fuk                                    # noqa: E402
import pr3map                                    # noqa: E402
import pr3_mesh                                  # noqa: E402

MAILLAGES = os.path.join(RACINE, "reference_pr3", "batiments")
VIGNETTES = os.path.join(RACINE, "reference_pr3", "ui", "batiments")

# Les modeles a sortir. Un par petale, plus les deux candidats a departager.
BATIMENTS = [
    "lighthouse",            # Capitainerie   -- une seule variante
    "tavern",                # Taverne        -- une seule
    "depot",                 # Entrepot       -- une seule (hors _pl)
    "dockyard0",             # Chantier naval
    "port0",                 # Docks
    # L'EGLISE et l'HOTEL DE VILLE ont une variante par nation. Les suffixes de
    # l'archive sont `_en`, `_fr`, `_nl`, `_sp` -- quinze .asset chacun -- plus
    # `_pl`, treize. J'ai d'abord cru `_pl` = joueur ; la symetrie de la famille
    # le dement, et les assets pirates sont ecrits en toutes lettres
    # (`piratebarc`), pas abreges. On le sort donc pour le REGARDER.
    "church0_en", "church0_fr", "church0_nl", "church0_sp", "church0_pl",
    "administration0_en", "administration0_fr", "administration0_nl",
    "administration0_sp", "administration0_pl",
]


def sortir(ar, nom):
    """Copie les maillages et la premiere texture d'un batiment. -> nb fichiers"""
    prefixe = "assets/%s/" % nom
    voulus = [e for e in ar["files"] if e["path"].startswith(prefixe)
              and (e["path"].endswith(".vbuf") or e["path"].endswith(".ibuf"))]
    # UNE SEULE texture : `pr3_mesh.lire_texture` prend la premiere du dossier,
    # et `0_` passe avant `1_` au tri. En copier deux ne servirait a rien.
    tex = [e for e in ar["files"] if e["path"] == "%s0_%s.dds" % (prefixe, nom)]
    if not voulus:
        print("   %-22s AUCUN maillage -- ignore" % nom)
        return 0
    dossier = os.path.join(MAILLAGES, nom)
    os.makedirs(dossier, exist_ok=True)
    for e in voulus + tex:
        with open(os.path.join(dossier, os.path.basename(e["path"])), "wb") as f:
            f.write(pr3fuk.content(ar, e))
    return len(voulus) + len(tex)


def main():
    taille, angle, gain = 142, 58.0, 1.7
    if "--taille" in sys.argv:
        taille = int(sys.argv[sys.argv.index("--taille") + 1])
    if "--angle" in sys.argv:
        angle = float(sys.argv[sys.argv.index("--angle") + 1])
    if "--gain" in sys.argv:
        gain = float(sys.argv[sys.argv.index("--gain") + 1])

    os.makedirs(MAILLAGES, exist_ok=True)
    os.makedirs(VIGNETTES, exist_ok=True)
    jeu = pr3map.game()
    ar = pr3fuk.load(pr3map.orig(jeu, "data.fuk"))

    print("--- extraction ---")
    faits = []
    for nom in BATIMENTS:
        n = sortir(ar, nom)
        if n:
            print("   %-22s %2d fichiers" % (nom, n))
            faits.append(nom)
    ar["f"].close()

    if not faits:
        raise SystemExit("aucun batiment sorti : l'archive n'a rien livre")

    print()
    # LE GAIN D'ECLAIRAGE, choisi EN REGARDANT trois valeurs sur deux batiments.
    #
    # A 1,0 -- l'ombrage neutre de `pr3_mesh` -- le phare reste un brun illisible ;
    # a 2,4 le haut de sa tour se delave. A 1,7 la galerie, la brique et la porte
    # se detachent sans rien bruler. Les textures de PR3 sont sombres parce que le
    # jeu les eclaire avec un soleil a 2,5 et un ciel a 1,5.
    #
    # CE QUE LE GAIN NE CORRIGE PAS : la taverne et le chantier restent charges a
    # toute valeur. Leur defaut n'est pas la lumiere mais la GEOMETRIE -- balcons,
    # escaliers et poutres rendus a 142 px en ombrage plat, sans anti-crenelage.
    # Les batiments massifs passent, les touffus non.
    print("--- rendu (%d px, plongee %.0f deg, gain %.1f) ---" % (taille, angle, gain))
    for nom in faits:
        src = os.path.join(MAILLAGES, nom)
        png = os.path.join(VIGNETTES, nom + ".png")
        try:
            ns, nt = pr3_mesh.rendre(src, png, taille, angle,
                                     (-0.55, 0.68, -0.48), gain)
        except Exception as ex:                      # noqa: BLE001
            print("   %-22s ECHEC : %s" % (nom, ex))
            continue
        print("   %-22s %5d sommets, %5d triangles" % (nom, ns, nt))

    print()
    print("maillages -> %s" % MAILLAGES)
    print("vignettes -> %s" % VIGNETTES)
    print("`reference_pr3/` est ignore par git : cet art ne doit pas etre commite.")


if __name__ == "__main__":
    main()
