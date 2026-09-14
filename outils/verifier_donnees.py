# -*- coding: utf-8 -*-
"""Controle les donnees du clone contre Port Royale 3 lui-meme.

    py -3 outils/verifier_donnees.py

Rien n'est ecrit : on relit l'installation du joueur et on compare. Sortie non
nulle si un ecart apparait, pour que le controle puisse servir de garde-fou.

POURQUOI. Deux erreurs ont dormi dans le depot sans que rien ne les signale :

  * `sim/carte_monde.lua` etait commite en 1320 x 866 au lieu de 1320 x 960.
    Trente-trois villes sur soixante tombaient alors SUR LA TERRE FERME, et
    toute la conversion case <-> monde etait decalee ;
  * `sim/villes_pr3.lua` ne portait aucun champ `region`, si bien que
    `archipel.lua` propageait nil pour les soixante villes.

Les deux se detectent en une seconde par un invariant du jeu. D'ou ce fichier.

CE QUI EST VERIFIE

  navires   canons, equipage et tirant des seize navires, contre constdata
  villes    case, region et productions des soixante villes, contre constdata
  noms      les noms affiches, contre la localisation du jeu
  littoral  l'invariant de PR3 : ses soixante villes sont sur une case de MER
            bordee de terre a moins de trois cases
  masque    le masque du monde fait bien 1320 x 960

CE QUI EST EXCLU, ET POURQUOI. Le clone s'ecarte de PR3 en deux points, tous
deux voulus et documentes dans `outils/extraire_pr3_monde.py` : le Portugal, qui
n'existe pas chez PR3 et reprend dix villes a l'Espagne, et la taille de Vera
Cruz, promue grande ville comme capitale portugaise. La nation et la taille ne
sont donc pas comparees.

On lit les archives `.original` de `_mod`, c'est-a-dire le JEU D'ORIGINE, et non
les archives installees qui peuvent porter des ajouts.
"""
import io
import os
import re
import struct
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JEU = r"D:\GOG Galaxy\Games\Port Royale 3"
sys.path.insert(0, os.path.join(JEU, "_mod"))
sys.path.insert(0, os.path.join(JEU, "_mod", "pr3"))

import unfuk        # noqa: E402
import pr3data      # noqa: E402
import pr3res       # noqa: E402

MODELES = ("pinnace sloop brig barc piratebarc fluyt tradefluyt corvette frigate "
           "militarycorvette militaryfrigate galleon carrack caravel wargalleon "
           "liner").split()
CLES = ["bois", "briques", "ble", "fruits", "mais", "sucre", "chanvre", "tissu",
        "metal", "coton", "outils", "teinture", "cafe", "cacao", "tabac",
        "viande", "vetements", "cordage", "rhum", "pain"]

ecarts = []


def signaler(quoi, detail):
    ecarts.append(f"{quoi} : {detail}")
    print(f"   ECART  {quoi} : {detail}")


def archive(nom):
    """L'archive d'ORIGINE, sinon celle qui est installee."""
    p = os.path.join(JEU, "_mod", nom + ".original")
    return p if os.path.isfile(p) else os.path.join(JEU, nom)


def constdata():
    f, ents = unfuk.parse(archive("data0.fuk"))
    return unfuk.read(f, [e for e in ents if e["path"] == "ini/constdata.dat"][0])


def localisation():
    f, ents = unfuk.parse(archive("data_fr.fuk"))
    return pr3res.Res(unfuk.read(f, [e for e in ents
                                     if e["path"].endswith("global.res")][0]))


def lua(chemin):
    return io.open(os.path.join(RACINE, chemin), encoding="utf-8").read()


# --------------------------------------------------------------------- navires
def verifier_navires(cd):
    """Canons, equipage et tirant : l'enregistrement declare son nombre de
    positions de canon, et le triplet Nations/Masts/Gauge suit la derniere."""
    jeu, fin = {}, 0
    for m in MODELES:
        s = m.encode() + b"\x00"
        a = cd.find(struct.pack("<I", len(s)) + s, fin)
        fin = a + len(s)
        o = a + 4 + len(s) + 1
        o += 4 + struct.unpack_from("<I", cd, o)[0] + 1
        n = struct.unpack_from("<I", cd, o)[0]
        t = o + 4 + n * 21
        jeu[m] = {"canons": 2 * n, "equipage": 10 * n, "tirant": cd[t + 2]}

    src = lua("sim/navires.lua")
    vus = 0
    for mm in re.finditer(r'modele = "(\w+)",(.*?)\},', src, re.S):
        modele, corps = mm.group(1), mm.group(2)
        if modele not in jeu:
            continue
        vus += 1
        for champ in ("canons", "equipage", "tirant"):
            r = re.search(champ + r"\s*=\s*(\d+)", corps)
            v = int(r.group(1)) if r else None
            if v != jeu[modele][champ]:
                signaler("navire", f"{modele} {champ} : clone {v}, jeu {jeu[modele][champ]}")
    if vus != len(MODELES):
        signaler("navire", f"{vus} navires dans la sim, {len(MODELES)} dans le jeu")
    print(f"navires  : {vus} compares, {len(MODELES) * 3} champs")


# ---------------------------------------------------------------------- villes
def villes_du_jeu(cd, res):
    C = pr3data.Constdata(cd)
    out = {}
    for i in range(60):
        r = C.get_record(i)
        out[res.get("ID_GUI_TOWN_%02d" % i)] = {
            "case": C.get_grid(i),
            "region": struct.unpack_from("<I", r, 69)[0],
            "produits": [CLES[r[36 + k]] for k in range(5)],
        }
    return out


def verifier_villes(jeu):
    src = lua("sim/villes_pr3.lua")
    vus = 0
    for bloc in re.split(r"\n\s*\{\s*cle\s*=", src)[1:]:
        n = re.search(r'nom\s*=\s*"([^"]+)"', bloc)
        if not n:
            continue
        nom = n.group(1)
        g = jeu.get(nom)
        if g is None:
            signaler("ville", f"{nom} est inconnue du jeu")
            continue
        vus += 1
        ca = re.search(r"case\s*=\s*\{\s*(\d+)\s*,\s*(\d+)\s*\}", bloc)
        rg = re.search(r"region\s*=\s*(\d+)", bloc)
        pr = re.search(r"produits\s*=\s*\{([^}]*)\}", bloc)
        if rg is None:
            signaler("ville", f"{nom} n'a pas de region")
        elif int(rg.group(1)) != g["region"]:
            signaler("ville", f"{nom} region : clone {rg.group(1)}, jeu {g['region']}")
        if ca is None or (int(ca.group(1)), int(ca.group(2))) != g["case"]:
            signaler("ville", f"{nom} case : jeu {g['case']}")
        if pr is None or re.findall(r'"(\w+)"', pr.group(1)) != g["produits"]:
            signaler("ville", f"{nom} produits : jeu {g['produits']}")
    if vus != len(jeu):
        signaler("ville", f"{vus} villes dans la sim, {len(jeu)} dans le jeu")
    print(f"villes   : {vus} comparees")


# ------------------------------------------------------------------ denrees
def verifier_denrees(res):
    src = lua("sim/marchandises.lua")
    paires = re.findall(r'cle\s*=\s*"([^"]+)"\s*,\s*nom\s*=\s*"([^"]+)"', src)
    for i, (_, nom) in enumerate(paires):
        attendu = res.get("ID_GUI_GOOD_%02d" % i)
        if attendu and nom != attendu.strip():
            signaler("denree", f"{i} : clone « {nom} », jeu « {attendu.strip()} »")
    print(f"denrees  : {len(paires)} comparees")


# ------------------------------------------------------------------- littoral
def masque_du_clone():
    t = lua("sim/carte_monde.lua")
    m = re.search(r"Carte\.largeur,\s*Carte\.hauteur\s*=\s*(\d+),\s*(\d+)", t)
    w, h = int(m.group(1)), int(m.group(2))
    masque = bytearray(w * h)
    for y, ligne in enumerate(re.findall(r"^\s*\{([\d,]+)\},\s*$", t, re.M)):
        if y >= h:
            break
        x, v = 0, 0
        for n in (int(k) for k in ligne.split(",") if k):
            if v == 1:
                for k in range(x, min(x + n, w)):
                    masque[y * w + k] = 1
            x += n
            v = 1 - v
    return w, h, masque


def verifier_littoral(jeu):
    """L'invariant de PR3 : une ville est sur une case de MER bordee de terre.
    C'est lui qui aurait signale le masque en 1320 x 866."""
    w, h, masque = masque_du_clone()
    if (w, h) != (1320, 960):
        signaler("masque", f"{w} x {h} au lieu de 1320 x 960")
    bons = 0
    for nom, g in jeu.items():
        cx, cz = g["case"]
        if not (0 <= cx < w and 0 <= cz < h):
            signaler("littoral", f"{nom} est hors de la carte")
            continue
        if masque[cz * w + cx] == 1:
            signaler("littoral", f"{nom} tombe sur la terre ferme")
            continue
        borde = any(0 <= cx + dx < w and 0 <= cz + dz < h
                    and masque[(cz + dz) * w + cx + dx] == 1
                    for dz in range(-3, 4) for dx in range(-3, 4))
        if not borde:
            signaler("littoral", f"{nom} n'a pas de terre a moins de trois cases")
            continue
        bons += 1
    print(f"littoral : {bons}/{len(jeu)} villes au mouillage, masque {w} x {h}")


def main():
    cd = constdata()
    res = localisation()
    jeu = villes_du_jeu(cd, res)
    verifier_navires(cd)
    verifier_villes(jeu)
    verifier_denrees(res)
    verifier_littoral(jeu)
    print()
    if ecarts:
        print(f"{len(ecarts)} ecart(s) avec Port Royale 3.")
        return 1
    print("Aucun ecart : les donnees du clone sont celles du jeu.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
