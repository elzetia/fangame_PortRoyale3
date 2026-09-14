"""Les tables chiffrees de Port Royale 3, lues dans `ini/constdata.dat`.

Le fichier est la SERIALISATION des structures que le jeu remplit en lisant ses
reglages : les champs se suivent dans l'ordre de la structure, sans nom. Les noms,
eux, sont dans l'executable, dans le code qui remplit ces structures a partir
d'un ini par section et par cle (voir `outils/PR3_TECHNIQUE.md`, « Le chargeur
des reglages ») :

    lecteur(section, cle, defaut)   -> rangé a tel decalage de la structure

C'est ce code, desassemble, qui donne le nom, le type et parfois la
transformation de chaque valeur — la consommation est rangee x100 x Faktor, les
quantites des recettes x64. Sans lui, on lisait des tableaux anonymes et on
devinait leur sens.

Les ancres de lecture sont structurelles : les tableaux ont leur compte devant
(`u32 20` puis vingt valeurs). Rien n'est copie dans le depot : le script lit
l'installation du joueur.

    py -3 outils/pr3_constdata.py
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
    facteurs de prix (u32 3, u32 2)."""
    for o in range(len(cd) - 60):
        if cd[o:o + 4] == b"\x14\x00\x00\x00" and \
           cd[o + 44:o + 52] == b"\x03\x00\x00\x00\x02\x00\x00\x00":
            return o
    raise LookupError("tableau des prix introuvable")


def tableau(cd, o, fmt, n=20):
    assert struct.unpack_from("<I", cd, o)[0] == n, f"compte attendu {n} a {o:#x}"
    taille = struct.calcsize("<" + fmt)
    return list(struct.unpack_from(f"<{n}{fmt}", cd, o + 4)), o + 4 + taille * n


def main():
    cd = charger()

    # --- prix -----------------------------------------------------------------
    o = chercher_prix(cd)
    prix, o = tableau(cd, o, "H")
    print("== Standardpreise (section Standardpreise, cles Ware%02u_SWP)")
    for d, p in zip(DENREES, prix):
        print(f"   {d:10s} {p}")

    o += 8
    print("\n== Preisfaktoren (cles X%u et X%uknapp) : 5 coefficients, stock vide -> plein")
    for jeu in range(3):
        series = []
        for _ in range(2):
            o += 1
            n = struct.unpack_from("<I", cd, o)[0]
            series.append([round(x, 2) for x in struct.unpack_from(f"<{n}f", cd, o + 4)])
            o += 4 + 4 * n
        o += 4
        print(f"   cran {jeu}: normal {series[0]}   penurie {series[1]}")

    # --- bloc economie : l'ordre est celui de la structure ------------------------
    b = cd.find(b"\x14\x00\x00\x00\x13\x01", o)
    conso, b = tableau(cd, b, "H")          # +0x0c  Warenverbrauch x100 x Faktor
    par_ouvrier, b = tableau(cd, b, "H")    # +0x34  Produktion : sortie / ouvriers
    grundbedarf, b = tableau(cd, b, "H")    # +0x5c  Grundbedarf
    ouvriers, b = tableau(cd, b, "B")       # +0x84  Produktion : ouvriers
    minimales, b = tableau(cd, b, "B")      # +0x98  Minimalmengen

    # Recettes (+0xfc) : 4 index d'intrants par denree, puis 4 quantites x64.
    assert struct.unpack_from("<I", cd, b)[0] == 20
    intrants = [[x for x in cd[b + 8 + 8 * i:b + 12 + 8 * i] if x != 0xff] for i in range(20)]
    b += 4 + 8 * 20
    assert struct.unpack_from("<I", cd, b)[0] == 20
    quantites = [cd[b + 8 + 8 * i:b + 12 + 8 * i] for i in range(20)]
    b += 4 + 8 * 20

    n = struct.unpack_from("<I", cd, b)[0]
    assert n == len(BATIMENTS), f"{n} batiments"
    b += 4
    batiments = []
    for nom in BATIMENTS:
        couts = struct.unpack_from("<3I", cd, b + 5)
        valeur = struct.unpack_from("<I", cd, b + 17)[0]
        duree = cd[b + 21]
        biens = [x for x in cd[b + 26:b + 30]]
        nb = struct.unpack_from("<I", cd, b + 30)[0]
        montants = struct.unpack_from(f"<{nb // 2}H", cd, b + 34)
        batiments.append((nom, couts, valeur, duree, biens, montants))
        b += 42

    # Les reglages scalaires : apres les modificateurs de construction
    # (Bauquotient_Mod, vingt flottants) et le loyer d'entrepot (Lagermiete, trois).
    m = b
    while True:
        m = cd.find(b"\x14\x00\x00\x00", m + 1)
        vals = struct.unpack_from("<20f", cd, m + 4)
        if all(0.1 <= v <= 10 for v in vals) and struct.unpack_from("<I", cd, m + 84)[0] == 3:
            break
    mods = vals
    lagermiete = struct.unpack_from("<3f", cd, m + 88)
    s = m + 100
    faktor, bettler, reparation = struct.unpack_from("<3f", cd, s)
    fass, start_fabriken = struct.unpack_from("<2H", cd, s + 12)
    (grundkosten, lohn, heuer, verwalter, vorrat, neubau_office, neubau_welt,
     neubau_alq, konvois) = cd[s + 16:s + 25]
    # Un octet de plus apres Konvois (a +0x879 dans la structure, non nomme), puis
    # l'alignement : les mots commencent a s + 27.
    verkauf, einkauf, einlauf, ki_convoy, min_area, basic_cap = struct.unpack_from("<6H", cd, s + 27)

    print("\n== Reglages de la section Data, Time et Initial")
    for nom, v, sens in (
        ("1Fass", fass, "unites par tonneau"),
        ("Faktor", round(faktor, 3), "multiplicateur de la consommation"),
        ("Lohn", lohn, "salaire d'un ouvrier, par jour"),
        ("Grundkosten", grundkosten, "frais fixes d'un atelier de 25 ouvriers, par jour"),
        ("Heuer", heuer, "solde d'un marin, par jour"),
        ("VerwalterLohn", verwalter, "salaire de l'administrateur"),
        ("VorratTage", vorrat, "jours de production gardes en reserve"),
        ("NeubauOfficeVorratTage", neubau_office, "seuil de reserve du comptoir pour batir"),
        ("NeubauWeltVorratTage", neubau_welt, "seuil de reserve mondiale pour batir"),
        ("NeubauMinAlq", neubau_alq, "chomage minimal pour batir un atelier"),
        ("StartFabriken", start_fabriken, "ateliers au depart"),
        ("Konvois (Initial)", konvois, "convois IA par comptoir (defaut compile 3)"),
        ("Verkaufszeit", verkauf, "temps de vente a quai"),
        ("Einkaufszeit", einkauf, "temps d'achat a quai"),
        ("Einlaufzeit", einlauf, "temps d'entree au port"),
        ("KiUpdateConvoySize", ki_convoy, "intervalle de redimensionnement des convois IA"),
        ("MinAreaFactor", min_area, ""),
        ("BasicCapacity", basic_cap, "capacite de base d'un comptoir"),
        ("Bettlerfaktor", round(bettler, 3), "facteur des mendiants"),
        ("Repairs/Zeit (probable)", round(reparation, 3), "duree de reparation"),
        ("Lagermiete", [round(x, 3) for x in lagermiete], "loyer d'entrepot, trois paliers"),
    ):
        print(f"   {nom:26s} {str(v):>18s}   {sens}")

    print("\n== Consommation, production, recettes")
    print("   denree       Verbrauch  A(range)  par_ouvrier  ouvriers  Grundbedarf  Minimal  Bauquotient")
    for i, d in enumerate(DENREES):
        print(f"   {d:10s} {conso[i] / (100 * faktor):9.2f} {conso[i]:9d} {par_ouvrier[i]:12d}"
              f" {ouvriers[i]:9d} {grundbedarf[i]:12d} {minimales[i]:8d} {mods[i]:11.2f}")

    print("\n== Recettes (intrant x quantite par unite produite ; rangee x64)")
    for i, d in enumerate(DENREES):
        if intrants[i]:
            txt = " + ".join(f"{DENREES[k]} x{quantites[i][j] / 64:g}"
                             for j, k in enumerate(intrants[i]))
            print(f"   {d:10s} <- {txt}")

    # La preuve : le prix standard est le cout de production d'un tonneau.
    print("\n== Prix standard recalcule = (Grundkosten + ouvriers x Lohn) / production + intrants")
    cout = {}
    for i in range(20):
        par_jour = ouvriers[i] * par_ouvrier[i] / fass
        c = (grundkosten + ouvriers[i] * lohn) / par_jour
        for j, k in enumerate(intrants[i]):
            c += quantites[i][j] / 64 * cout.get(k, prix[k])
        cout[i] = c
        print(f"   {DENREES[i]:10s} calcule {c:7.1f}   jeu {prix[i]}")

    print("\n== Batiments : Bauplatzkosten x3, valeur des materiaux, duree, materiaux (Baukosten Betriebe)")
    for nom, couts, valeur, duree, biens, montants in batiments:
        if any(couts):
            mats = ", ".join(f"{montants[j]} {DENREES[k]}" for j, k in enumerate(biens)
                             if k < 20 and j < len(montants) and montants[j])
            print(f"   {nom:16s} {str(couts):26s} {valeur:7d} {duree:3d}  {mats}")

    print("\n== Navires : Value, Capacity, Hitpoints, HitpointsSail, Construct (or),"
          " DailyCosts, rangs mil/mil/pir, Vmin, Vmax, Wendig")
    fin = 0
    for nom in NAVIRES:
        pos = cd.find(struct.pack("<I", len(nom) + 1) + nom.encode() + b"\x00", fin)
        p = None
        for i in range(pos - 40, max(fin, pos - 260), -1):
            a, c = struct.unpack_from("<II", cd, i)
            if a == c and 20000 <= a <= 2000000:
                p = i
        valeur_n = struct.unpack_from("<I", cd, p - 6)[0]
        cale = struct.unpack_from("<H", cd, p - 2)[0]
        coque, voiles, construction = struct.unpack_from("<3I", cd, p)
        entretien = struct.unpack_from("<H", cd, p + 12)[0]
        rangs = ["-" if x == 255 else x for x in cd[p + 18:p + 21]]
        vmin, vmax, wendig = cd[p + 21], cd[p + 22], cd[p + 23]
        print(f"   {nom:17s} {valeur_n:6d} {cale:4d} {coque // 1000:4d} {voiles // 1000:4d}"
              f" {construction:7d} {entretien:4d} {rangs} {vmin:2d} {vmax:2d} {wendig:3d}")
        fin = pos + len(nom)

    # --- munitions (section AmmoData) ---------------------------------------
    # Chaque type porte l'asset "cannonball0" ; les entrees se suivent au pas de
    # 0x26. Le bloc string fait 4 (prefixe u32 de longueur) + 12 ("cannonball0\0").
    # Juste avant : les champs. A +5 du bloc numerique : Vmax (f32) puis DmgHull,
    # DmgSail, DmgCrew (i32). Les degats sont a comparer aux PV internes (Hitpoints
    # x1000 : un sloop a 110 000 de coque).
    AMMO = ["boulet", "chaine", "mitraille", "lourd"]
    prem = cd.find(b"cannonball0")
    print("\n== Munitions (AmmoData : Vmax, DmgHull, DmgSail, DmgCrew)")
    for k, nom in enumerate(AMMO):
        strp = prem - 4 + k * 0x26
        b = cd[strp - 22:strp]
        vmax = struct.unpack_from("<f", b, 5)[0]
        dh, ds, dc = struct.unpack_from("<3i", b, 9)
        print(f"   {nom:10s} Vmax {vmax:6.1f}   coque {dh:5d}  voiles {ds:5d}  equipage {dc:5d}")


if __name__ == "__main__":
    main()
