# Table charId -> bitmap pour les caracteres ANONYMES d'un .swf.
#
# `swf_icones.py` ne resout que les symboles NOMMES (ceux du SymbolClass). Or un
# agencement exporte reference aussi des caracteres sans nom, que `swf_export.py`
# note « charNNN ». Sous les planches du HUD, ils sont la majorite : minimap,
# bandeau de ville et fond de planche droite tiennent presque entierement a eux.
#
# Le piege, paye comptant : un charId place designe une FORME, pas un bitmap,
# alors que les PNG tires par `swf_bitmaps.py` portent l'identifiant du BITMAP
# que cette forme remplit. Les deux numerotations sont DISJOINTES -- hud_pc.swf
# sort 52 PNG (1, 2, 3, 4, 5, 6, 12, 24...) et son agencement n'en reference
# aucun (14, 16, 20, 22, 30, 32...). Conclure a un export manquant est l'erreur
# naturelle ; ce qui manque est cette table.
#
#     py -3 swf_caracteres.py <fichier.swf>
#
# Ecrit reference_pr3/ui/<swf>/caracteres.txt, a cote des PNG du meme .swf :
#     <charId>\t<bitmapId>.png\t<L>x<H>
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from swf_lecture import Swf, SORTIE


def main():
    s = Swf(sys.argv[1])
    dossier = os.path.join(SORTIE, s.base)
    # Ce que `swf_bitmaps.py` a reellement tire : une entree qui pointe vers un
    # fichier absent ne vaut rien, autant le dire tout de suite.
    presents = set()
    if os.path.isdir(dossier):
        presents = {f.rsplit(".", 1)[0] for f in os.listdir(dossier)
                    if f.lower().endswith(".png")}

    # Tout caractere susceptible d'etre PLACE : formes et sprites. Les bitmaps
    # se resolvent en eux-memes et entrent aussi, pour que la table reponde a
    # n'importe quel charId sans que l'appelant ait a savoir ce qu'il tient.
    cids = sorted(set(s.shapes) | set(s.sprites) | set(s.bmp))
    lignes = []
    resolus = orphelins = 0
    for cid in cids:
        best = s.meilleure(cid)
        if best is None:
            continue
        resolus += 1
        if str(best) not in presents:
            orphelins += 1
            continue
        lignes.append(f"{cid}\t{best}.png\t{s.bmp[best][0]}x{s.bmp[best][1]}")

    os.makedirs(dossier, exist_ok=True)
    dest = os.path.join(dossier, "caracteres.txt")
    open(dest, "w", encoding="utf-8").write("\n".join(lignes) + "\n")
    print(f"{s.nom} : {len(cids)} caracteres, {resolus} menent a un bitmap, "
          f"{len(lignes)} ecrits")
    if orphelins:
        print(f"   {orphelins} pointent vers un bitmap SANS PNG sur le disque "
              f"(lancer swf_bitmaps.py {s.nom} ?)")
    print(f"   -> reference_pr3/ui/{s.base}/caracteres.txt")


main()
