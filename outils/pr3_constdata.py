"""Les tables chiffrees de Port Royale 3, lues dans `ini/constdata.dat`.

Le fichier est un flux serialise sans etiquettes : les noms de cles vivent dans
l'exe (`Standardpreise`, `Preisfaktoren`, `Warenverbrauch`...), les valeurs ici,
dans l'ordre ou le chargeur les lit. On ne peut donc pas le parcourir de bout en
bout sans le code du chargeur. Mais les tableaux sont prefixes par leur compte
(`u32 20` puis vingt valeurs), et c'est ce qui permet de les retrouver.

Les ancres ont ete posees par TEXTE CONNU : les prix de base releves a l'ecran
(33, 33, 33, 50...) sortent d'un bloc, en u16. Tout le reste s'est lu a partir de
la, en suivant la structure.

Rien n'est copie dans le depot : le script lit l'installation du joueur.

    py -3 outils/pr3_constdata.py            toutes les tables
"""
import os
import struct
import sys

JEU = r"D:\GOG Galaxy\Games\Port Royale 3"
sys.path.insert(0, os.path.join(JEU, "_mod"))

DENREES = ("bois briques ble fruits mais sucre chanvre tissu metal coton outils "
           "teinture cafe cacao tabac viande vetements cordage rhum pain").split()

# L'ordre de l'enum BLD_ de l'exe : les chaines y sont rangees a l'envers.
BATIMENTS = DENREES + ("etal grue jetee place_marche poi hotel_de_ville eglise "
                       "dock chantier_ville taverne chantier_naval phare ecole "
                       "hopital arbres puits pompiers hospice ambassade forteresse "
                       "entrepot maison bordel").split()

NAVIRES = ("pinnace sloop brig barc piratebarc fluyt tradefluyt corvette frigate "
           "militarycorvette militaryfrigate galleon carrack caravel wargalleon "
           "liner").split()


def charger():
    import unfuk
    f, entrees = unfuk.parse(os.path.join(JEU, "data0.fuk"))
    e = [x for x in entrees if x["path"] == "ini/constdata.dat"][0]
    return unfuk.read(f, e)


def chercher_prix(cd):
    """Le tableau des prix standard : u32 20, puis 20 u16, puis l'en-tete des
    facteurs de prix (u32 3, u32 2). Pas de valeurs attendues dans le motif :
    seulement la structure, pour ne pas tourner en rond."""
    for o in range(len(cd) - 60):
        if cd[o:o + 4] == b"\x14\x00\x00\x00" and \
           cd[o + 44:o + 52] == b"\x03\x00\x00\x00\x02\x00\x00\x00":
            return o
    raise LookupError("tableau des prix introuvable")


def u16s(cd, o, n=20):
    assert struct.unpack_from("<I", cd, o)[0] == n, f"compte attendu {n} a {o:#x}"
    return list(struct.unpack_from(f"<{n}H", cd, o + 4)), o + 4 + 2 * n


def main():
    cd = charger()
    o = chercher_prix(cd)
    prix, o = u16s(cd, o)
    print("== Standardpreise (prix standard)")
    for d, p in zip(DENREES, prix):
        print(f"   {d:10s} {p}")

    # Trois jeux, chacun deux series de cinq : normale, puis « knapp » (penurie).
    o += 8
    print("\n== Preisfaktoren (5 paliers de stock, du vide au plein)")
    for jeu in range(3):
        series = []
        for _ in range(2):
            o += 1
            n = struct.unpack_from("<I", cd, o)[0]
            series.append([round(x, 2) for x in struct.unpack_from(f"<{n}f", cd, o + 4)])
            o += 4 + 4 * n
        o += 4
        print(f"   jeu {jeu}: normal {series[0]}   penurie {series[1]}")

    # Le bloc production : chercher le compte 20 suivi de 275 (bois, u16).
    b = cd.find(b"\x14\x00\x00\x00\x13\x01", o)
    conso, b = u16s(cd, b)
    rendement, b = u16s(cd, b)
    minima, b = u16s(cd, b)
    print("\n== consommation (A) / rendement par manufacture (B) / C")
    for i, d in enumerate(DENREES):
        print(f"   {d:10s} A={conso[i]:4d}  B={rendement[i]:4d}  C={minima[i]}")

    # Deux tableaux d'octets, puis les recettes : pour chaque denree, 4 octets
    # d'index d'intrants (0xff = rien) ; puis, en regard, 4 octets de quantites
    # en 1/32 d'unite par unite produite.
    b += 4 + 20
    b += 4 + 20
    assert struct.unpack_from("<I", cd, b)[0] == 20
    intrants = []
    for i in range(20):
        intrants.append([x for x in cd[b + 8 + 8 * i:b + 12 + 8 * i] if x != 0xff])
    b += 4 + 8 * 20
    assert struct.unpack_from("<I", cd, b)[0] == 20
    print("\n== recettes (intrant x quantite par unite produite)")
    for i, d in enumerate(DENREES):
        q = cd[b + 8 + 8 * i:b + 12 + 8 * i]
        if intrants[i]:
            txt = " + ".join(f"{DENREES[k]} x{q[j] / 32:g}" for j, k in enumerate(intrants[i]))
            print(f"   {d:10s} <- {txt}")
    b += 4 + 8 * 20

    n = struct.unpack_from("<I", cd, b)[0]
    assert n == len(BATIMENTS), f"{n} batiments"
    b += 4
    print("\n== batiments : couts x3, X, jours ?, paire (probablement ouvriers)")
    for nom in BATIMENTS:
        couts = struct.unpack_from("<3I", cd, b + 5)
        x = struct.unpack_from("<I", cd, b + 17)[0]
        jours = cd[b + 21]
        paire = struct.unpack_from("<2H", cd, b + 34)
        if any(couts):
            print(f"   {nom:16s} {couts}  X={x:6d}  {jours:2d}  {paire}")
        b += 42

    print("\n== navires : prix, cale, coque, D, E, rangs, Vmin, Vmax, maniabilite")
    fin = 0
    for nom in NAVIRES:
        pos = cd.find(struct.pack("<I", len(nom) + 1) + nom.encode() + b"\x00", fin)
        p = None
        for i in range(pos - 40, max(fin, pos - 260), -1):
            a, c = struct.unpack_from("<II", cd, i)
            if a == c and 20000 <= a <= 2000000:
                p = i
        prix_n = struct.unpack_from("<I", cd, p - 6)[0]
        cale = struct.unpack_from("<H", cd, p - 2)[0]
        coque = struct.unpack_from("<I", cd, p)[0]
        d = struct.unpack_from("<I", cd, p + 8)[0]
        e = struct.unpack_from("<H", cd, p + 12)[0]
        rangs = ["-" if x == 255 else x for x in cd[p + 18:p + 21]]
        vmin, vmax, wendig = cd[p + 21], cd[p + 22], cd[p + 23]
        print(f"   {nom:17s} {prix_n:6d} {cale:4d} {coque:7d} {d:6d} {e:4d} "
              f"{rangs} {vmin:2d} {vmax:2d} {wendig:3d}")
        fin = pos + len(nom)


if __name__ == "__main__":
    main()
