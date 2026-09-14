# Reconstruit une VRAIE fonte TrueType depuis les glyphes embarques d'un .swf.
#
# PR3 n'installe aucun fichier de police : ses lettres vivent dans
# `ui/glyph_lib.swf`, en DefineFont3, sous forme de CONTOURS VECTORIELS. Trois
# coupes y sont definies -- Arial, Benjamin-Book et Benjamin-Bold -- et c'est
# Benjamin qui donne au jeu son aspect. Le clone tournait jusqu'ici sur un
# substitut choisi a la main.
#
# POURQUOI C'EST POSSIBLE. Un glyphe de DefineFont3 est une SHAPE sans styles :
# rien que des aretes, droites ou QUADRATIQUES. Or TrueType emploie lui aussi des
# quadratiques : la conversion est directe, sans approximation. Verifie avant
# d'ecrire une ligne de format binaire -- le « A » sort a 2 contours, le « o » a
# 2 (dont 16 courbes et 2 droites), le « 8 » a 3. Le compte des contours colle
# aux lettres, ce qui ne serait pas le cas d'une lecture de travers.
#
# DEUX CONVERSIONS A NE PAS RATER :
#   * l'axe Y. Le SWF compte vers le BAS, TrueType vers le HAUT : on nie Y.
#   * l'echelle. DefineFont3 travaille au 1/20e d'unite sur un cadratin de 1024,
#     soit 20480 unites -- au-dela du maximum de 16384 qu'admet `unitsPerEm`. On
#     divise donc par 20 pour retomber sur un cadratin de 1024, ou la hauteur de
#     capitale du « A » vaut 683, valeur tout a fait ordinaire.
#
# DROITS. Benjamin est une fonte COMMERCIALE (SoftMaker Software GmbH). Le
# fichier produit va donc dans `reference_pr3/`, ignore par git, exactement comme
# le reste de l'art extrait : il ne quitte pas la machine du joueur.
#
#     py -3 outils/swf_fonte.py [Benjamin-Book|Benjamin-Bold|Arial]
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from swf_lecture import charger, Bits, rect, SORTIE

CADRATIN = 1024          # cadratin vise
ECHELLE = 20             # DefineFont3 compte au 1/20e d'unite


# --- lecture du DefineFont3 ---------------------------------------------------

def fontes(nom_swf="glyph_lib.swf"):
    """Toutes les fontes du .swf : {nom complet: donnees}."""
    d = charger(nom_swf)
    b = Bits(d, 8)
    rect(b)
    o = b.p + 4
    brut = {}
    noms = {}
    while o < len(d) - 2:
        rh = struct.unpack_from("<H", d, o)[0]
        o += 2
        code = rh >> 6
        ln = rh & 0x3f
        if ln == 0x3f:
            ln = struct.unpack_from("<I", d, o)[0]
            o += 4
        if code == 0:
            break
        if code == 75:
            brut[struct.unpack_from("<H", d, o)[0]] = (o, ln)
        elif code == 88:                       # DefineFontName
            cid = struct.unpack_from("<H", d, o)[0]
            p = o + 2
            e = d.index(b"\0", p)
            noms[cid] = d[p:e].decode("latin1")
        o += ln
    return d, brut, noms


def lire_fonte(d, body, ln):
    """Glyphes, codes, avances et metrique d'un DefineFont3."""
    p = body + 2
    f1 = d[p]
    p += 2                                     # drapeaux + langue
    lg = d[p]
    p += 1
    p += lg                                    # nom court
    n = struct.unpack_from("<H", d, p)[0]
    p += 2
    large_off = bool(f1 & 0x08)
    large_codes = bool(f1 & 0x04)
    mise_en_page = bool(f1 & 0x80)
    gras = bool(f1 & 0x01)
    pas = 4 if large_off else 2
    fmt = "<I" if large_off else "<H"
    debut = p
    offs = [struct.unpack_from(fmt, d, debut + i * pas)[0] for i in range(n)]
    fin = struct.unpack_from(fmt, d, debut + n * pas)[0]

    glyphes = [_contours(d, debut + offs[i],
                         debut + (offs[i + 1] if i + 1 < n else fin))
               for i in range(n)]

    q = debut + fin
    if large_codes:
        codes = [struct.unpack_from("<H", d, q + i * 2)[0] for i in range(n)]
        q += n * 2
    else:
        codes = [d[q + i] for i in range(n)]
        q += n
    asc = desc = saut = 0
    avances = [0] * n
    if mise_en_page:
        asc, desc, saut = struct.unpack_from("<hhh", d, q)
        q += 6
        avances = list(struct.unpack_from("<%dh" % n, d, q))
    return {"glyphes": glyphes, "codes": codes, "avances": avances,
            "asc": asc, "desc": desc, "saut": saut, "gras": gras}


def _contours(d, deb, fin):
    """Les contours d'un glyphe : [[(x, y, sur_courbe), ...], ...]."""
    b = Bits(d, deb)
    nfill = b.u(4)
    nline = b.u(4)
    out = []
    cour = None
    x = y = 0
    while b.p < fin:
        if b.u(1) == 0:
            drapeaux = b.u(5)
            if drapeaux == 0:
                break
            if drapeaux & 0x01:
                nb = b.u(5)
                x = b.sg(nb)
                y = b.sg(nb)
                if cour:
                    out.append(cour)
                cour = [(x, y, True)]
            if drapeaux & 0x02:
                b.u(nfill)
            if drapeaux & 0x04:
                b.u(nfill)
            if drapeaux & 0x08:
                b.u(nline)
        else:
            if cour is None:
                cour = [(x, y, True)]
            if b.u(1):                          # droite
                nb = b.u(4) + 2
                if b.u(1):
                    dx = b.sg(nb)
                    dy = b.sg(nb)
                elif b.u(1):
                    dx = 0
                    dy = b.sg(nb)
                else:
                    dx = b.sg(nb)
                    dy = 0
                x += dx
                y += dy
                cour.append((x, y, True))
            else:                               # quadratique
                nb = b.u(4) + 2
                cx = x + b.sg(nb)
                cy = y + b.sg(nb)
                x = cx + b.sg(nb)
                y = cy + b.sg(nb)
                cour.append((cx, cy, False))
                cour.append((x, y, True))
    if cour:
        out.append(cour)
    return out


# --- ecriture du TrueType -----------------------------------------------------

def _table_glyf(contours):
    """Un glyphe simple. Rend (octets, xMin, yMin, xMax, yMax)."""
    pts = []
    fins = []
    for c in contours:
        # Le SWF referme implicitement : on jette un dernier point identique au
        # premier, que TrueType n'attend pas.
        cc = c[:-1] if len(c) > 1 and c[0][:2] == c[-1][:2] else c
        if len(cc) < 2:
            continue
        for (x, y, sur) in cc:
            pts.append((round(x / ECHELLE), -round(y / ECHELLE), sur))
        fins.append(len(pts) - 1)
    if not pts:
        return b"", 0, 0, 0, 0
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    x0, y0, x1, y1 = min(xs), min(ys), max(xs), max(ys)

    out = struct.pack(">hhhhh", len(fins), x0, y0, x1, y1)
    out += b"".join(struct.pack(">H", f) for f in fins)
    out += struct.pack(">H", 0)                 # aucune instruction
    # Drapeaux simples : un octet par point, sans compression ni vecteurs courts.
    out += bytes(0x01 if p[2] else 0x00 for p in pts)
    px = 0
    for p in pts:
        out += struct.pack(">h", p[0] - px)
        px = p[0]
    py = 0
    for p in pts:
        out += struct.pack(">h", p[1] - py)
        py = p[1]
    if len(out) % 4:
        out += b"\0" * (4 - len(out) % 4)
    return out, x0, y0, x1, y1


def _cmap(codes):
    """Format 4, un segment par plage contigue.

    LE GLYPHE VISE EST `i + 1`, PAS `i`. `construire()` place en tete le
    `.notdef` qu'exige TrueType : le glyphe SWF numero i devient donc le glyphe
    TrueType i+1 -- ce que `glyfs`, `loca` et `hmtx` font deja.

    Une premiere version cartographiait vers `i` et decalait TOUTE LA FONTE d'un
    cran : « W » dessinait un « V », « A » un « @ ». Le texte etait illisible, et
    RIEN ne le signalait -- les 366 codes etaient presents, chaque glyphe avait
    ses contours, Godot chargeait le fichier sans broncher. C'est la CHASSE qui a
    vendu la meche : « i » et « W » sortaient a la meme largeur, celle de leurs
    voisins. La comparaison avance/encre a acheve la preuve -- le .swf donne
    « W » 927 et « i » 316, la fonte produite rendait 655 et 648, soit les
    avances de « V » et de « h ».
    """
    paires = sorted((c, i + 1) for i, c in enumerate(codes) if 0 < c < 0xFFFF)
    segs = []
    for c, gi in paires:
        if segs and c == segs[-1][1] + 1 and gi == segs[-1][2] + (segs[-1][1] - segs[-1][0]) + 1:
            segs[-1][1] = c
        else:
            segs.append([c, c, gi])
    segs.append([0xFFFF, 0xFFFF, 0])
    n = len(segs)
    fin = b"".join(struct.pack(">H", s[1]) for s in segs)
    deb = b"".join(struct.pack(">H", s[0]) for s in segs)
    delta = b"".join(struct.pack(">h", ((s[2] - s[0]) & 0xFFFF) - 0x10000
                                if ((s[2] - s[0]) & 0xFFFF) > 0x7FFF
                                else (s[2] - s[0]) & 0xFFFF) for s in segs)
    plage = b"".join(struct.pack(">H", 0) for _ in segs)
    seg2 = n * 2
    ent = max(0, (seg2).bit_length() - 1)
    sous = struct.pack(">HHHHHHH", 4, 16 + 8 * n, 0, seg2,
                       2 ** ent, ent - 1 if ent else 0, seg2 - 2 ** ent)
    sous += fin + b"\0\0" + deb + delta + plage
    sous = sous[:2] + struct.pack(">H", len(sous)) + sous[4:]
    entete = struct.pack(">HHHHI", 0, 1, 3, 1, 12)
    return entete + sous


def _nom(famille, style):
    complet = "%s %s" % (famille, style)
    ps = ("%s-%s" % (famille, style)).replace(" ", "")
    vals = {1: famille, 2: style, 4: complet, 6: ps}
    recs = []
    donnees = b""
    for nid in sorted(vals):
        b = vals[nid].encode("utf-16-be")
        recs.append(struct.pack(">HHHHHH", 3, 1, 0x409, nid, len(b), len(donnees)))
        donnees += b
    return (struct.pack(">HHH", 0, len(recs), 6 + 12 * len(recs))
            + b"".join(recs) + donnees)


def construire(f, famille, style):
    n = len(f["glyphes"]) + 1                  # +1 : le .notdef obligatoire
    glyfs = [(b"", 0, 0, 0, 0)]
    for c in f["glyphes"]:
        glyfs.append(_table_glyf(c))
    glyf = b"".join(g[0] for g in glyfs)
    loca = b""
    off = 0
    for g in glyfs:
        loca += struct.pack(">I", off)
        off += len(g[0])
    loca += struct.pack(">I", off)

    av = [0] + [max(0, round(a / ECHELLE)) for a in f["avances"]]
    hmtx = b"".join(struct.pack(">Hh", av[i], glyfs[i][1]) for i in range(n))

    asc = round(f["asc"] / ECHELLE) or 800
    desc = round(f["desc"] / ECHELLE) or 200
    saut = round(f["saut"] / ECHELLE)
    x0 = min((g[1] for g in glyfs if g[0]), default=0)
    y0 = min((g[2] for g in glyfs if g[0]), default=0)
    x1 = max((g[3] for g in glyfs if g[0]), default=0)
    y1 = max((g[4] for g in glyfs if g[0]), default=0)

    head = struct.pack(">IIIIHHQQhhhhHHhhh", 0x00010000, 0x00010000, 0,
                       0x5F0F3CF5, 0x0003, CADRATIN, 0, 0,
                       x0, y0, x1, y1, 1 if f["gras"] else 0, 8, 2, 1, 0)
    hhea = struct.pack(">IhhhHhhhhhhhhhhhH", 0x00010000, asc, -desc, saut,
                       max(av) if av else 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, n)
    maxp = struct.pack(">IHHHHHHHHHHHHHH", 0x00010000, n, 512, 64, 0, 0, 2,
                       0, 0, 0, 0, 0, 0, 0, 0)
    # PAS de table OS/2. Elle est la plus capricieuse du format -- une trentaine
    # de champs dont l'ordre ne pardonne rien -- et ma premiere version l'a
    # empaquetee de travers (34 attendus, 38 fournis). FreeType, que Godot
    # emploie, charge un TrueType sans elle et prend ses metriques dans `hhea`.
    # On la supprime plutot que de la rafistoler : moins de surface d'erreur.
    post = struct.pack(">IIhhIIIII", 0x00030000, 0, 0, 0, 0, 0, 0, 0, 0)

    tables = {b"cmap": _cmap(f["codes"]), b"glyf": glyf,
              b"head": head, b"hhea": hhea, b"hmtx": hmtx, b"loca": loca,
              b"maxp": maxp, b"name": _nom(famille, style), b"post": post}

    cles = sorted(tables)
    nt = len(cles)
    ent = max(0, (nt).bit_length() - 1)
    sortie = struct.pack(">IHHHH", 0x00010000, nt, 16 * (2 ** ent), ent,
                         16 * nt - 16 * (2 ** ent))
    debut = 12 + 16 * nt
    corps = b""
    reps = b""
    for k in cles:
        t = tables[k]
        reps += struct.pack(">4sIII", k, 0, debut + len(corps), len(t))
        corps += t + b"\0" * ((4 - len(t) % 4) % 4)
    return sortie + reps + corps


def main():
    voulue = sys.argv[1] if len(sys.argv) > 1 else "Benjamin-Book"
    d, brut, noms = fontes()
    cid = next((c for c, nm in noms.items() if nm == voulue), None)
    if cid is None:
        print("fontes disponibles : " + ", ".join(sorted(noms.values())))
        return
    f = lire_fonte(d, *brut[cid])
    famille, _, style = voulue.partition("-")
    ttf = construire(f, famille, style or "Regular")
    dest = os.path.join(SORTIE, "polices")
    os.makedirs(dest, exist_ok=True)
    chemin = os.path.join(dest, voulue + ".ttf")
    open(chemin, "wb").write(ttf)
    n_pts = sum(len(c) for g in f["glyphes"] for c in g)
    print(f"{voulue} : {len(f['glyphes'])} glyphes, {n_pts} points, "
          f"asc {f['asc']} desc {f['desc']}")
    print(f"   -> {chemin}  ({len(ttf)} octets)")


if __name__ == "__main__":
    main()
