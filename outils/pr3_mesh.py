"""Lecture des maillages de Port Royale 3, et rendu en vignette.

Format retrouve par sondage (aucune documentation) :

  .vbuf   en-tete de 80 octets, puis 16 octets par sommet :
            0-5   position, 3 demi-flottants
            6-7   bourrage, toujours nul
            8-11  normale, 4 entiers signes 8 bits
            12-15 coordonnees de texture, 2 demi-flottants
  .ibuf   en-tete de 80 octets, puis des indices sur 16 bits, par triplets

Verifie sur assets/port0 (7262 sommets, 5200 triangles) : les positions sortent
bornees, les UV tombent dans [0, 1] et tous les indices sont valides.

    py -3 pr3_mesh.py <dossier_asset> <sortie.png> [--taille 512] [--angle 58]

Aucune dependance : bibliotheque standard uniquement.
"""
import glob
import math
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dds2png import lire_dds, ecrire_png

ENTETE = 80
PAS = 16


def _demi(u):
    """Demi-flottant IEEE 754 -> float."""
    s = (u >> 15) & 1
    e = (u >> 10) & 0x1f
    m = u & 0x3ff
    if e == 0:
        val = (m / 1024.0) * 2.0 ** -14
    elif e == 31:
        return 0.0
    else:
        val = (1.0 + m / 1024.0) * 2.0 ** (e - 15)
    return -val if s else val


def lire_maillage(dossier):
    """-> (sommets, normales, uv, triangles)"""
    vb = glob.glob(os.path.join(dossier, "*.vbuf"))
    ib = glob.glob(os.path.join(dossier, "*.ibuf"))
    if not vb or not ib:
        raise FileNotFoundError(f"pas de .vbuf/.ibuf dans {dossier}")

    v = open(vb[0], 'rb').read()
    i = open(ib[0], 'rb').read()
    n = (len(v) - ENTETE) // PAS

    sommets, normales, uv = [], [], []
    for k in range(n):
        o = ENTETE + k * PAS
        px, py, pz = struct.unpack_from('<3H', v, o)
        nx, ny, nz, _ = struct.unpack_from('<4b', v, o + 8)
        tu, tv = struct.unpack_from('<2H', v, o + 12)
        sommets.append((_demi(px), _demi(py), _demi(pz)))
        normales.append((nx / 127.0, ny / 127.0, nz / 127.0))
        uv.append((_demi(tu), _demi(tv)))

    m = (len(i) - ENTETE) // 2
    m -= m % 3
    idx = struct.unpack_from(f'<{m}H', i, ENTETE)
    triangles = [idx[k:k + 3] for k in range(0, m, 3)]
    return sommets, normales, uv, triangles


def lire_texture(dossier):
    """Premiere texture DDS du dossier -> (largeur, hauteur, rgba)"""
    dds = sorted(glob.glob(os.path.join(dossier, "*.dds")))
    if not dds:
        return None
    w, h, _, px = lire_dds(dds[0])
    return w, h, px


def rendre(dossier, sortie, taille=512, angle=58.0, lumiere=(-0.55, 0.68, -0.48)):
    """Rend le maillage en plongee oblique, sur fond transparent."""
    sommets, normales, uv, triangles = lire_maillage(dossier)
    tex = lire_texture(dossier)
    th = math.radians(angle)
    cs, sn = math.cos(th), math.sin(th)

    # Projection : meme convention que la carte cuite. L'axe vertical de
    # l'ecran melange altitude et profondeur nord-sud.
    def projeter(p):
        x, y, z = p
        return x, y * cs - z * sn

    plan = [projeter(p) for p in sommets]
    xs = [p[0] for p in plan]
    ys = [p[1] for p in plan]
    minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
    etendue = max(maxx - minx, maxy - miny) * 1.06
    if etendue <= 0:
        raise ValueError("maillage degenere")

    ech = taille / etendue
    cx = (minx + maxx) * 0.5
    cy = (miny + maxy) * 0.5

    def ecran(p):
        u, w = projeter(p)
        return ((u - cx) * ech + taille * 0.5,
                taille * 0.5 - (w - cy) * ech)

    # Profondeur le long du rayon de vue, pour trier
    def profondeur(p):
        return p[1] * sn + p[2] * cs

    img = bytearray(taille * taille * 4)
    zbuf = [1e9] * (taille * taille)

    lum = list(lumiere)
    ln = math.sqrt(sum(c * c for c in lum))
    lum = [c / ln for c in lum]

    for tri in triangles:
        a, b, c = tri
        pa, pb, pc = ecran(sommets[a]), ecran(sommets[b]), ecran(sommets[c])
        # Normale moyenne, pour un ombrage plat mais correct
        nm = [(normales[a][k] + normales[b][k] + normales[c][k]) / 3.0 for k in range(3)]
        nl = math.sqrt(sum(x * x for x in nm)) or 1.0
        nm = [x / nl for x in nm]
        eclair = max(0.0, sum(nm[k] * lum[k] for k in range(3)))
        prof = (profondeur(sommets[a]) + profondeur(sommets[b])
                + profondeur(sommets[c])) / 3.0

        # Rasterisation par balayage du rectangle englobant
        x0 = max(0, int(min(pa[0], pb[0], pc[0])))
        x1 = min(taille - 1, int(max(pa[0], pb[0], pc[0])) + 1)
        y0 = max(0, int(min(pa[1], pb[1], pc[1])))
        y1 = min(taille - 1, int(max(pa[1], pb[1], pc[1])) + 1)
        aire = ((pb[0] - pa[0]) * (pc[1] - pa[1])
                - (pc[0] - pa[0]) * (pb[1] - pa[1]))
        if abs(aire) < 1e-9:
            continue

        for py in range(y0, y1 + 1):
            for px in range(x0, x1 + 1):
                w0 = ((pb[0] - pa[0]) * (py + 0.5 - pa[1])
                      - (px + 0.5 - pa[0]) * (pb[1] - pa[1])) / aire
                w1 = ((px + 0.5 - pa[0]) * (pc[1] - pa[1])
                      - (pc[0] - pa[0]) * (py + 0.5 - pa[1])) / aire
                w2 = 1.0 - w0 - w1
                if w0 < 0 or w1 < 0 or w2 < 0:
                    continue
                o = py * taille + px
                if prof >= zbuf[o]:
                    continue
                zbuf[o] = prof

                if tex:
                    tw, th_, tpx = tex
                    tu = uv[a][0] * w2 + uv[b][0] * w1 + uv[c][0] * w0
                    tv = uv[a][1] * w2 + uv[b][1] * w1 + uv[c][1] * w0
                    sx = int((tu % 1.0) * (tw - 1))
                    sy = int((tv % 1.0) * (th_ - 1))
                    s = (sy * tw + sx) * 4
                    r, g, b_ = tpx[s], tpx[s + 1], tpx[s + 2]
                    # Pas de test d'alpha : dans 0_port0.dds le canal alpha
                    # n'est pas une transparence (il est opaque a 0 %), mais
                    # une carte auxiliaire. S'en servir vidait le rendu.
                else:
                    r = g = b_ = 190

                f = 0.62 + 0.48 * eclair
                d = o * 4
                img[d] = min(255, int(r * f))
                img[d + 1] = min(255, int(g * f))
                img[d + 2] = min(255, int(b_ * f))
                img[d + 3] = 255

    ecrire_png(sortie, taille, taille, img)
    return len(sommets), len(triangles)


if __name__ == '__main__':
    dossier, sortie = sys.argv[1], sys.argv[2]
    taille = 512
    angle = 58.0
    if '--taille' in sys.argv:
        taille = int(sys.argv[sys.argv.index('--taille') + 1])
    if '--angle' in sys.argv:
        angle = float(sys.argv[sys.argv.index('--angle') + 1])
    ns, nt = rendre(dossier, sortie, taille, angle)
    print(f"{dossier} : {ns} sommets, {nt} triangles -> {sortie}")
