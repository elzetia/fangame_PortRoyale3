"""Extrait une famille de sprites d'une planche deja decoupee.

Une planche generee melange souvent plusieurs familles (ecueils, buissons,
coraux...). Le decoupage les sort toutes dans l'ordre de lecture ; cet outil
en preleve un sous-ensemble par index et en fait un dossier de famille propre,
avec sa fiche.

    py -3 extraire_famille.py <source> <destination> <nom> 0,1,2,54,55

Les index se lisent sur la planche-contact (outils/planche_contact.py).
Aucune dependance : bibliotheque standard uniquement.
"""
import json
import os
import shutil
import sys


def main():
    src, dst, nom = sys.argv[1], sys.argv[2], sys.argv[3]
    index = [int(v) for v in sys.argv[4].split(',')]

    fiche = next(f for f in os.listdir(src) if f.endswith('.json'))
    d = json.load(open(os.path.join(src, fiche), encoding='utf-8'))
    sprites = d['sprites']

    os.makedirs(dst, exist_ok=True)
    # On repart de zero : sinon les sprites d'une extraction precedente
    # trainent dans le dossier et le moteur les seme encore.
    for f in os.listdir(dst):
        if f.endswith('.png') or f.endswith('.png.import') or f.endswith('.json'):
            os.remove(os.path.join(dst, f))

    sortie = []
    for n, i in enumerate(index):
        sp = dict(sprites[i])
        cible = f"{nom}_{n:02d}.png"
        shutil.copyfile(os.path.join(src, sp['fichier']),
                        os.path.join(dst, cible))
        sp['fichier'] = cible
        sortie.append(sp)
        print(f"  {i:>3} -> {cible}  {sp['largeur']}x{sp['hauteur']}")

    with open(os.path.join(dst, nom + '.json'), 'w', encoding='utf-8') as f:
        json.dump({"source": d.get('source', ''), "ancrage": d.get('ancrage', 'pied'),
                   "sprites": sortie}, f, indent='\t', ensure_ascii=False)
    print(f"{len(sortie)} sprites -> {dst}/{nom}.json")


if __name__ == '__main__':
    main()
