# Table classe -> bitmap pour les symboles NOMMES d'un .swf (SymbolClass),
# resolue RECURSIVEMENT a travers sprites ET remplissages bitmap de formes.
#
# Le parseur vit dans `swf_lecture.py`, partage avec `swf_caracteres.py` : les
# pieges de format (HasClassName, balises longues) n'ont ainsi qu'une seule
# implementation a garder juste.
#
#     py -3 swf_icones.py <fichier.swf> [motif]
#
# Ecrit reference_pr3/ui/agencement/icones.txt (tabule), lu par EcranPR3.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from swf_lecture import Swf, SORTIE

s = Swf(sys.argv[1])
motif = sys.argv[2].lower() if len(sys.argv) > 2 else ""

lignes = []
for cid in sorted(s.names, key=lambda i: s.names[i].lower()):
    if motif and motif not in s.names[cid].lower():
        continue
    best = s.meilleure(cid)
    if best is None:
        continue
    # Le nom ENTIER quand c'est un nom de fichier : `split('.')[-1]` reduisait
    # « Flag_England.png » a « png » et faisait s'effondrer 414 symboles sur une
    # seule cle. Sinon, le dernier segment pointe : components.button.Visual_X.
    nm = s.names[cid]
    court = nm if nm.lower().endswith(".png") else nm.split('.')[-1]
    # Le DECALAGE, en 4e et 5e colonnes : ou poser l'art par rapport au point de
    # placement. Mesure et non devine -- les boutons rendent -taille/2, les
    # plaques (0,0). Les trois premieres colonnes ne bougent pas, les lecteurs
    # qui n'en veulent pas les ignorent.
    dx, dy = s.origine(cid, best) or (0.0, 0.0)
    # TABULATEURS : c'est ainsi que `EcranPR3.icones()` decoupe le fichier.
    lignes.append(f"{court}\t{best}.png\t{s.bmp[best][0]}x{s.bmp[best][1]}"
                  f"\t{dx:.0f}\t{dy:.0f}")

dest = os.path.join(SORTIE, "agencement", "icones.txt")
os.makedirs(os.path.dirname(dest), exist_ok=True)
open(dest, "w", encoding="utf-8").write("\n".join(lignes) + "\n")
print(f"{len(lignes)} entrees -> icones.txt")
