# -*- coding: utf-8 -*-
"""Fabrique le pavillon du PORTUGAL dans le style exact de ceux de Port Royale 3.

    py -3 outils/pavillon_portugal_pr3.py [--donneur 1569] [--apercu]

Ecrit `reference_pr3/ui/pavillons_pr3/portugal.png` (44 x 30), charge ensuite par
`SkinPR3.texture("pavillons_pr3/portugal")`.

POURQUOI. PR3 n'a PAS de pavillon portugais, et ce n'est pas un oubli
d'extraction : zero occurrence de « portug » dans ses trois tables d'icones, zero
dans `data.fuk` et `data0.fuk`, et la liste complete des `Flag_*` s'arrete a
Angleterre, France, Pays-Bas, Espagne, Pirate, Joueur. Le jeu a quatre nations ;
le Portugal est la cinquieme de NOTRE simulation.

Notre propre `sprites/pavillons/portugal.png` fait 259 x 198 : pose a cote de
pavillons dessines pour etre vus en 44 x 30, il tranche.

CE QUE FAIT CET OUTIL, ET CE QU'IL NE FAIT PAS. Il ne DESSINE pas un drapeau : il
REPEINT celui de PR3. L'ombrage du plisse, le liseré sombre et l'alpha de la
frange d'ombre sont ceux du donneur, au pixel pres ; seules les couleurs des
champs changent.

LA METHODE, tiree de la mesure du donneur (1569, le tricolore neerlandais, choisi
parce que ses aplats sont purs -- aucun embleme n'y pollue l'ombrage) :

    la toile occupe y = 1..26 ; y=0 et y>=27 ne portent que l'ombre portee
    bandes : orange y=3..8, blanc y=10..16, bleu y=18..25
    y=1..2 et y=25..26 sont le LISERE sombre
    le « blanc » releve vaut (148,157,150) : toute la toile est assombrie

On calcule donc, pour chaque pixel, un facteur d'ombrage = sa luminance divisee
par celle de la base de SA bande. Ce facteur porte le plisse sans porter la
couleur. On le reapplique ensuite sur les champs du Portugal -- vert sur les deux
cinquiemes cote hampe, rouge sur les trois autres.

LES PIXELS DU LISERE NE SONT PAS REPEINTS : sous un facteur de 0,45, on garde la
couleur d'origine. Sans cette regle, le contour noir devenait vert fonce et la
toile perdait sa decoupe.

La sphere armillaire est un BLOB dore de quelques pixels a la jointure : a
44 x 30, c'est tout ce qu'un embleme peut etre, et PR3 ne fait pas autrement pour
les armes d'Espagne.

L'art de depart est celui de Port Royale 3 -- (c) Kalypso / Gaming Minds -- et ce
qu'on en derive l'est aussi : la sortie vit dans `reference_pr3/`, ignore par git.
On versionne l'OUTIL, jamais sa sortie.

Aucune dependance : bibliotheque standard uniquement.
"""
import os
import struct
import sys
import zlib

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIN = os.path.join(RACINE, "reference_pr3", "ui", "skinlib_pr3")
SORTIE = os.path.join(RACINE, "reference_pr3", "ui", "pavillons_pr3")

# Les couleurs du Portugal, a pleine saturation : l'ombrage du donneur les
# rabattra tout seul, exactement comme il rabat le blanc neerlandais a (148,157,150).
VERT = (0, 102, 0)
ROUGE = (218, 41, 28)
OR = (255, 204, 51)

# La part de la largeur occupee par le vert, cote hampe.
PART_VERTE = 0.40
# En dessous de ce facteur d'ombrage, un pixel est du LISERE : on n'y touche pas.
SEUIL_LISERE = 0.45
# Au-dessus, on ecrete : voir la note sur les coutures dans la boucle de repeinte.
PLAFOND_OMBRAGE = 1.35


def lire_png(chemin):
    d = open(chemin, "rb").read()
    pos, idat = 8, b""
    w = h = ct = 0
    while pos < len(d):
        ln = struct.unpack(">I", d[pos:pos + 4])[0]
        typ = d[pos + 4:pos + 8]
        dat = d[pos + 8:pos + 8 + ln]
        if typ == b"IHDR":
            w, h, _bd, ct = struct.unpack(">IIBB", dat[:10])
        elif typ == b"IDAT":
            idat += dat
        pos += 12 + ln
    if ct != 6:
        raise ValueError("%s : type de couleur %d, RGBA attendu" % (chemin, ct))
    raw = zlib.decompress(idat)
    nc, st = 4, w * 4
    lignes, prec, i = [], bytearray(st), 0
    for _y in range(h):
        f = raw[i]; i += 1
        l = bytearray(raw[i:i + st]); i += st
        for x in range(st):
            a = l[x - nc] if x >= nc else 0
            b = prec[x]
            c = prec[x - nc] if x >= nc else 0
            if f == 1:
                l[x] = (l[x] + a) & 255
            elif f == 2:
                l[x] = (l[x] + b) & 255
            elif f == 3:
                l[x] = (l[x] + (a + b) // 2) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                l[x] = (l[x] + pr) & 255
        lignes.append(bytearray(l)); prec = l
    return w, h, lignes


def ecrire_png(chemin, w, h, lignes):
    def bloc(typ, dd):
        c = typ + dd
        return struct.pack(">I", len(dd)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)
    brut = b"".join(b"\x00" + bytes(l) for l in lignes)
    open(chemin, "wb").write(
        b"\x89PNG\r\n\x1a\n"
        + bloc(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
        + bloc(b"IDAT", zlib.compress(brut, 9))
        + bloc(b"IEND", b""))


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def main():
    donneur = "1569"
    apercu = "--apercu" in sys.argv
    if "--donneur" in sys.argv:
        donneur = sys.argv[sys.argv.index("--donneur") + 1]
    src = os.path.join(SKIN, donneur + ".png")
    if not os.path.exists(src):
        raise SystemExit("donneur absent : %s\n"
                         "Extrais d'abord l'interface de ta copie du jeu." % src)

    w, h, lignes = lire_png(src)
    px = lambda x, y: tuple(lignes[y][x * 4:(x + 1) * 4])

    # --- 1. la base d'ombrage, PAR BANDE et non par ligne.
    #
    # C'EST LE POINT DELICAT, et ma premiere version s'y est trompee. Normaliser
    # chaque ligne par SA PROPRE moyenne efface la variation VERTICALE : or les
    # lignes du haut et du bas de la toile sont naturellement plus sombres, c'est
    # le bord ombre du tissu. Elles ressortaient donc a facteur 1, repeintes en
    # vert pleine intensite -- deux barres claires en haut et en bas.
    #
    # Les chiffres du donneur le disent : y=2 vaut (138,77,20) contre (190,107,28)
    # au coeur de la bande orange, soit 72 % de sa luminance. Divise par sa propre
    # ligne, ce 72 % redevient 100 %.
    #
    # On regroupe donc les lignes en BANDES de couleur, et toutes les lignes d'une
    # bande partagent une seule reference. L'ombrage vertical survit, les plis
    # horizontaux aussi, et comme chaque bande a par construction une moyenne de
    # 1, aucune couture n'apparait entre elles.
    moyennes = {}
    for y in range(h):
        p = [px(x, y) for x in range(w) if px(x, y)[3] > 200]
        # Les lignes trop peu couvertes sont le LISERE du haut et du bas (7, 24 et
        # 12 pixels opaques chez le donneur, contre une quarantaine ailleurs) :
        # elles n'entrent dans aucune bande et ne seront pas repeintes.
        if len(p) >= 30:
            moyennes[y] = (sum(q[0] for q in p) / len(p),
                           sum(q[1] for q in p) / len(p),
                           sum(q[2] for q in p) / len(p))

    bandes = []
    for y in sorted(moyennes):
        c = moyennes[y]
        if bandes and y == bandes[-1][-1][0] + 1:
            ref = bandes[-1][0][1]
            ecart = sum(abs(c[k] - ref[k]) for k in range(3))
            if ecart < 150:                 # meme bande
                bandes[-1].append((y, c))
                continue
        bandes.append([(y, c)])

    # LES LIGNES DE TRANSITION GARDENT LEUR PROPRE MOYENNE.
    #
    # Une ligne a cheval sur deux bandes -- y=17 chez le donneur, un melange
    # bleu-blanc -- n'appartient a AUCUNE. Rangee dans la bande bleue, dont la
    # base vaut 53 de luminance, elle sortait a f=1,62 : une ligne claire en
    # travers du drapeau. J'ai d'abord tente d'ECRETER ce facteur a 1,35 ; ca n'a
    # rien donne de visible, et pour cause -- la mediane etant a 0,94, une ligne a
    # 1,35 reste une ligne claire.
    #
    # Normalisee par sa PROPRE moyenne, une telle ligne revient a f ~ 1,0, donc au
    # niveau de ses voisines. La couture disparait par construction, sans rien
    # raboter du plisse.
    base = {}
    for bande in bandes:
        n = len(bande)
        moy = tuple(sum(e[1][k] for e in bande) / n for k in range(3))
        for y, c in bande:
            ecart = sum(abs(c[k] - moy[k]) for k in range(3))
            base[y] = c if ecart > 90 else moy
    print("   %d bande(s) : %s" % (len(bandes),
          ", ".join("y=%d..%d" % (b[0][0], b[-1][0]) for b in bandes)))

    # --- 2. l'etendue de la TOILE, pour placer la partition verticale.
    cols = [x for x in range(w)
            if any(px(x, y)[3] > 200 for y in range(h))]
    if not cols:
        raise SystemExit("le donneur n'a aucun pixel opaque")
    x0, x1 = min(cols), max(cols)
    coupe = x0 + (x1 - x0) * PART_VERTE
    print("donneur %s : toile x=%d..%d, coupe verte/rouge a x=%.1f"
          % (donneur, x0, x1, coupe))

    # --- 3. repeindre.
    sortie = [bytearray(l) for l in lignes]
    n_liseré = n_peint = 0
    for y in range(h):
        b = base.get(y)
        for x in range(w):
            r, g, bl, a = px(x, y)
            if a == 0:
                continue
            if b is None or lum(b) < 1.0:
                continue
            f = lum((r, g, bl)) / lum(b)
            if f < SEUIL_LISERE:
                n_liseré += 1
                continue                      # liseré : on garde l'original
            # BORNE HAUTE, contre les COUTURES aux jointures de bandes.
            #
            # Les lignes de TRANSITION -- y=17 chez le donneur, un melange
            # bleu-blanc range dans la bande bleue -- sortent a f=1,62 contre une
            # base de 53 : une ligne claire nette en travers du drapeau.
            #
            # Aucun seuil ne les separe des vrais reflets : la mesure donne, dans
            # les bandes, p05=0,39 med=0,94 p95=1,57. On ECRETE donc plutot que de
            # trier. A 1,35 la couture disparait et le plisse reste entier, la
            # mediane etant a 0,94.
            f = min(f, PLAFOND_OMBRAGE)
            champ = VERT if x < coupe else ROUGE
            o = (x * 4)
            sortie[y][o + 0] = min(255, int(champ[0] * f))
            sortie[y][o + 1] = min(255, int(champ[1] * f))
            sortie[y][o + 2] = min(255, int(champ[2] * f))
            n_peint += 1
    print("   %d pixels repeints, %d gardes comme lisere" % (n_peint, n_liseré))

    # --- 4. la sphere armillaire : un blob dore a la jointure, ombre comme le reste.
    cy = (1 + 26) / 2.0
    for y in range(h):
        b = base.get(y)
        for x in range(w):
            if px(x, y)[3] < 200 or b is None:
                continue
            d2 = ((x - coupe) / 3.2) ** 2 + ((y - cy) / 3.6) ** 2
            if d2 > 1.0:
                continue
            f = lum(px(x, y)[:3]) / lum(b)
            if f < SEUIL_LISERE:
                continue
            o = x * 4
            sortie[y][o + 0] = min(255, int(OR[0] * f))
            sortie[y][o + 1] = min(255, int(OR[1] * f))
            sortie[y][o + 2] = min(255, int(OR[2] * f))

    os.makedirs(SORTIE, exist_ok=True)
    cible = os.path.join(SORTIE, "portugal.png")
    ecrire_png(cible, w, h, sortie)
    print("ecrit : %s (%d x %d)" % (cible, w, h))

    if apercu:
        Z = 8
        gros = []
        for y in range(h * Z):
            s = sortie[y // Z]
            l = bytearray()
            for x in range(w * Z):
                l += s[(x // Z) * 4:(x // Z) * 4 + 4]
            gros.append(l)
        ap = os.path.join(os.environ.get("TEMP", "."), "portugal_apercu.png")
        ecrire_png(ap, w * Z, h * Z, gros)
        print("apercu : %s" % ap)

    print("`reference_pr3/` est ignore par git : cet art derive ne doit pas etre commite.")


if __name__ == "__main__":
    main()
