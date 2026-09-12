"""Decoupe une planche de sprites generee (fond magenta) en sprites detoures.

    py -3 decouper_planche.py assets_generes/palmiers.png sprites/palmiers --ancrage pied
    py -3 decouper_planche.py assets_generes/bourgs.png   sprites/bourgs --lignes-noires

Le detourage se fait par distance a la couleur de fond, ce qui donne un alpha
progressif sur les bords antialiases au lieu d'un decoupage en escalier. Un
« despill » retire ensuite la frange magenta qui reste sur les contours.

Les sprites sont ensuite isoles par composantes connexes : pas besoin que la
planche soit une grille reguliere, chaque tache de couleur devient un sprite.

Aucune dependance : bibliotheque standard uniquement.
"""
import collections
import json
import os
import struct
import sys
import zlib


# --- lecture PNG -------------------------------------------------------------

def lire_png(chemin):
    """-> (largeur, hauteur, bytearray RGBA)"""
    d = open(chemin, 'rb').read()
    if d[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError(f"{chemin} n'est pas un PNG")

    i = 8
    idat = bytearray()
    w = h = bits = couleur = 0
    while i < len(d):
        n = int.from_bytes(d[i:i + 4], 'big')
        tag = d[i + 4:i + 8]
        data = d[i + 8:i + 8 + n]
        i += 12 + n
        if tag == b'IHDR':
            w, h, bits, couleur, _comp, _filt, entrelace = struct.unpack('>IIBBBBB', data)
            if bits != 8 or entrelace != 0:
                raise ValueError("seuls les PNG 8 bits non entrelaces sont geres")
            if couleur not in (2, 6):
                raise ValueError(f"type de couleur {couleur} non gere (attendu RGB ou RGBA)")
        elif tag == b'IDAT':
            idat += data
        elif tag == b'IEND':
            break

    canaux = 3 if couleur == 2 else 4
    brut = zlib.decompress(bytes(idat))
    pas = w * canaux
    sortie = bytearray(w * h * 4)
    precedente = bytearray(pas)
    pos = 0

    for y in range(h):
        filtre = brut[pos]
        pos += 1
        ligne = bytearray(brut[pos:pos + pas])
        pos += pas

        # Defiltrage PNG : chaque ligne est encodee par rapport a ses voisines
        if filtre == 1:      # Sub
            for x in range(canaux, pas):
                ligne[x] = (ligne[x] + ligne[x - canaux]) & 0xff
        elif filtre == 2:    # Up
            for x in range(pas):
                ligne[x] = (ligne[x] + precedente[x]) & 0xff
        elif filtre == 3:    # Average
            for x in range(pas):
                a = ligne[x - canaux] if x >= canaux else 0
                ligne[x] = (ligne[x] + ((a + precedente[x]) >> 1)) & 0xff
        elif filtre == 4:    # Paeth
            for x in range(pas):
                a = ligne[x - canaux] if x >= canaux else 0
                b = precedente[x]
                c = precedente[x - canaux] if x >= canaux else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                ligne[x] = (ligne[x] + pr) & 0xff
        elif filtre != 0:
            raise ValueError(f"filtre PNG inconnu : {filtre}")

        precedente = ligne
        for x in range(w):
            s = x * canaux
            o = (y * w + x) * 4
            sortie[o] = ligne[s]
            sortie[o + 1] = ligne[s + 1]
            sortie[o + 2] = ligne[s + 2]
            sortie[o + 3] = ligne[s + 3] if canaux == 4 else 255
    return w, h, sortie


def ecrire_png(chemin, w, h, rgba):
    brut = bytearray()
    for y in range(h):
        brut.append(0)
        brut += rgba[y * w * 4:(y + 1) * w * 4]

    def bloc(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)

    with open(chemin, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(bloc(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)))
        f.write(bloc(b'IDAT', zlib.compress(bytes(brut), 6)))
        f.write(bloc(b'IEND', b''))


# --- detourage ---------------------------------------------------------------

CLE = (255, 0, 255)
# Seuils larges : le JPEG bruite le fond magenta, et un seuil serre laisse des
# rectangles fantomes autour de chaque sprite.
SEUIL_BAS = 95        # en deca : franchement du fond
SEUIL_HAUT = 170      # au dela : franchement du sujet


def detourer(rgba, w, h, lignes_noires, erosion=1, cle=None, seuils=None):
    """Alpha par distance a la cle, puis demelange pour retirer la frange.

    `cle` permet de detourer une planche livree sur autre chose que du magenta
    (certaines arrivent sur un bleu d'ocean uni). Le despill, lui, ne vaut que
    pour le magenta : sur un fond bleu il mangerait le ciel et les lagons.
    """
    cle = cle or CLE
    bas, haut = seuils or (SEUIL_BAS, SEUIL_HAUT)
    despill = cle == CLE
    for i in range(0, len(rgba), 4):
        r, g, b = rgba[i], rgba[i + 1], rgba[i + 2]

        if lignes_noires and r < 55 and g < 55 and b < 55:
            rgba[i + 3] = 0
            continue

        dr, dg, db = r - cle[0], g - cle[1], b - cle[2]
        d = (dr * dr + dg * dg + db * db) ** 0.5
        if d <= bas:
            rgba[i + 3] = 0
            continue
        a = 1.0 if d >= haut else (d - bas) / (haut - bas)
        rgba[i + 3] = int(a * 255)

        # Demelange : un pixel de bord vaut a*couleur + (1-a)*cle. On inverse
        # pour retrouver la couleur reelle, ce qui supprime la frange rose au
        # lieu de simplement la desaturer.
        if a < 0.999:
            inv = 1.0 - a
            for k in range(3):
                v = (rgba[i + k] - inv * cle[k]) / max(a, 0.06)
                rgba[i + k] = max(0, min(255, int(v)))

        # Despill. Le JPEG encode la couleur en demi-resolution : le magenta
        # bave a l'INTERIEUR du sujet, sur des pixels pourtant opaques, que le
        # demelange ci-dessus ne corrige pas. Un pixel teinte magenta a ses deux
        # canaux rouge ET bleu au-dessus du vert ; on les redescend.
        # Une palme verte, un toit rouge ou une dorure n'ont jamais ce profil.
        m = min(rgba[i], rgba[i + 2])
        if despill and m > rgba[i + 1]:
            exces = m - rgba[i + 1]
            rgba[i] = max(0, rgba[i] - exces)
            rgba[i + 2] = max(0, rgba[i + 2] - exces)

    # Erosion : les tout derniers pixels de bord restent sales apres JPEG.
    for _ in range(erosion):
        aplat = bytearray(w * h)
        for y in range(h):
            for x in range(w):
                i = y * w + x
                if rgba[i * 4 + 3] == 0:
                    continue
                vide = False
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if nx < 0 or ny < 0 or nx >= w or ny >= h or rgba[(ny * w + nx) * 4 + 3] == 0:
                        vide = True
                        break
                aplat[i] = 1 if vide else 0
        for i in range(w * h):
            if aplat[i]:
                rgba[i * 4 + 3] = 0


# --- composantes connexes ----------------------------------------------------

def composantes(rgba, w, h, alpha_min=40, aire_min=400):
    """Isole chaque tache opaque. -> liste de (x0, y0, x1, y1)."""
    vu = bytearray(w * h)
    boites = []
    for depart in range(w * h):
        if vu[depart] or rgba[depart * 4 + 3] < alpha_min:
            continue
        file = collections.deque([depart])
        vu[depart] = 1
        x0 = x1 = depart % w
        y0 = y1 = depart // w
        aire = 0
        while file:
            p = file.popleft()
            aire += 1
            px, py = p % w, p // w
            if px < x0: x0 = px
            if px > x1: x1 = px
            if py < y0: y0 = py
            if py > y1: y1 = py
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = px + dx, py + dy
                if 0 <= nx < w and 0 <= ny < h:
                    q = ny * w + nx
                    if not vu[q] and rgba[q * 4 + 3] >= alpha_min:
                        vu[q] = 1
                        file.append(q)
        if aire >= aire_min:
            boites.append((x0, y0, x1, y1))
    return boites


def fusionner(boites, seuil):
    """Regroupe les boites separees de moins de `seuil` pixels.

    Un bourg dont le ponton est detache des maisons ressort en deux
    composantes : sans cette etape, on obtiendrait un village et un quai
    orphelin au lieu d'un seul sprite.
    """
    boites = list(boites)
    change = True
    while change:
        change = False
        for i in range(len(boites)):
            for j in range(i + 1, len(boites)):
                a, b = boites[i], boites[j]
                dx = max(0, max(a[0], b[0]) - min(a[2], b[2]))
                dy = max(0, max(a[1], b[1]) - min(a[3], b[3]))
                if dx <= seuil and dy <= seuil:
                    boites[i] = (min(a[0], b[0]), min(a[1], b[1]),
                                 max(a[2], b[2]), max(a[3], b[3]))
                    del boites[j]
                    change = True
                    break
            if change:
                break
    return boites


def decouper(rgba, w, boite):
    x0, y0, x1, y1 = boite
    cw, ch = x1 - x0 + 1, y1 - y0 + 1
    out = bytearray(cw * ch * 4)
    for y in range(ch):
        s = ((y0 + y) * w + x0) * 4
        out[y * cw * 4:(y + 1) * cw * 4] = rgba[s:s + cw * 4]
    return cw, ch, out


def cote_quai(cw, ch, rgba):
    """De quel cote se trouve le quai ? -> 'gauche' ou 'droite'.

    On repere les toits rouges, tres caracteristiques, et on en prend le centre :
    le quai est a l'oppose des maisons. Sans cette information, un bourg place
    sur une cote est se retrouverait avec son ponton tourne vers l'interieur
    des terres.
    """
    somme = 0
    poids = 0
    for y in range(ch):
        for x in range(cw):
            o = (y * cw + x) * 4
            if rgba[o + 3] < 120:
                continue
            r, g, b = rgba[o], rgba[o + 1], rgba[o + 2]
            if r > 110 and r > g * 1.45 and r > b * 1.45:
                somme += x
                poids += 1
    if poids == 0:
        return 'droite'
    centre = somme / poids
    return 'gauche' if centre > cw * 0.5 else 'droite'


def ancrage(cw, ch, rgba, mode):
    """Point par lequel le sprite se pose sur le terrain."""
    if mode == 'centre':
        return [cw // 2, ch // 2]
    # 'pied' : milieu des pixels opaques des dernieres lignes. Pour un palmier,
    # c'est le bas du stipe — pas le centre de l'image, sinon l'arbre flotte.
    for y in range(ch - 1, -1, -1):
        xs = [x for x in range(cw) if rgba[(y * cw + x) * 4 + 3] > 60]
        if xs:
            return [(min(xs) + max(xs)) // 2, y]
    return [cw // 2, ch - 1]


def main():
    src = sys.argv[1]
    dst = sys.argv[2]
    mode = 'pied'
    if '--ancrage' in sys.argv:
        mode = sys.argv[sys.argv.index('--ancrage') + 1]
    lignes_noires = '--lignes-noires' in sys.argv
    cle = seuils = None
    if '--cle' in sys.argv:
        cle = tuple(int(v) for v in sys.argv[sys.argv.index('--cle') + 1].split(','))
    if '--seuils' in sys.argv:
        seuils = tuple(int(v) for v in sys.argv[sys.argv.index('--seuils') + 1].split(','))
    aire_min = 400
    if '--aire-min' in sys.argv:
        aire_min = int(sys.argv[sys.argv.index('--aire-min') + 1])

    w, h, rgba = lire_png(src)
    print(f"{src} : {w}x{h}")
    # Certaines planches arrivent deja detourees : leur fond est transparent,
    # pas d'une couleur a chasser. Y passer le detourage abimerait les bords
    # antialiases pour rien.
    if '--alpha' not in sys.argv:
        detourer(rgba, w, h, lignes_noires, cle=cle, seuils=seuils)

    boites = composantes(rgba, w, h, aire_min=aire_min)
    if '--fusionner' in sys.argv:
        seuil = int(sys.argv[sys.argv.index('--fusionner') + 1])
        avant = len(boites)
        boites = fusionner(boites, seuil)
        print(f"  fusion a {seuil} px : {avant} -> {len(boites)}")
    # Ordre de lecture : de haut en bas, puis de gauche a droite.
    # Les lignes sont formees par PROXIMITE des centres, pas par division
    # entiere : sur une planche de stades de croissance, les sprites n'ont pas
    # la meme hauteur (un clocher depasse), et une division fixe tombe tot ou
    # tard sur une frontiere, ce qui melange l'ordre.
    if boites:
        hauteurs = sorted(b[3] - b[1] for b in boites)
        tol = max(30, hauteurs[len(hauteurs) // 2] * 0.6)
        par_centre = sorted(boites, key=lambda b: (b[1] + b[3]) / 2.0)
        lignes, courante = [], [par_centre[0]]
        ref = (par_centre[0][1] + par_centre[0][3]) / 2.0
        for b in par_centre[1:]:
            c = (b[1] + b[3]) / 2.0
            if c - ref <= tol:
                courante.append(b)
            else:
                lignes.append(courante)
                courante, ref = [b], c
        lignes.append(courante)
        boites = []
        for ligne in lignes:
            boites.extend(sorted(ligne, key=lambda b: b[0]))

    print(f"  {len(boites)} sprites trouves")

    os.makedirs(dst, exist_ok=True)
    base = os.path.splitext(os.path.basename(src))[0]
    fiche = []
    for n, boite in enumerate(boites):
        cw, ch, sp = decouper(rgba, w, boite)
        nom = f"{base}_{n:02d}.png"
        ecrire_png(os.path.join(dst, nom), cw, ch, sp)
        a = ancrage(cw, ch, sp, mode)
        q = cote_quai(cw, ch, sp)
        fiche.append({"fichier": nom, "largeur": cw, "hauteur": ch,
                      "ancrage": a, "quai": q})
        print(f"  {nom}  {cw}x{ch}  ancrage {a}  quai a {q}")

    with open(os.path.join(dst, base + ".json"), 'w', encoding='utf-8') as f:
        json.dump({"source": os.path.basename(src), "ancrage": mode,
                   "sprites": fiche}, f, indent='\t', ensure_ascii=False)
    print(f"  -> fiche {base}.json")


if __name__ == '__main__':
    main()
