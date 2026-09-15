"""Lecture des maillages de Port Royale 3, et rendu en vignette.

Format retrouve par sondage (aucune documentation). Les deux fichiers partagent
le meme debut d'en-tete : une signature `77 fe ba b0`, puis a l'octet 10 la
TAILLE DES DONNEES sur 32 bits. L'en-tete, c'est donc ce qui reste devant :
80 octets pour un .vbuf de port, 96 pour un .vbuf de navire, 32 pour tout .ibuf.

  .ibuf   des indices sur 16 bits, par triplets
  .vbuf   le pas d'un sommet n'est ecrit nulle part de lisible : on le deduit,
          taille des donnees / (plus grand indice + 1). Deux formats rencontres :

          16 octets (ports, decor)            80 octets (navires)
            0-5   position, 3 demi-flottants    0-11  position, 3 flottants
            6-7   bourrage                      12-27 couleur RGBA, 4 flottants
            8-11  normale, 4 entiers 8 bits     28-39 normale
            12-15 uv, 2 demi-flottants          40-51 tangente
                                                52-63 binormale
                                                64-71 uv
                                                72-79 inutilise (0, 1)

La couleur des navires n'est pas une teinte : c'est un MASQUE de piece
(le gui sort en (1, 0, 1), le mat en (0, 1, 1)), que le shader lit sans doute
pour animer ou abimer chaque partie separement.

Un navire est fait de plusieurs pieces, une paire .vbuf/.ibuf chacune (coque,
voile, mat, gui) : on les lit toutes.

Verifie sur assets/port0 (7262 sommets) et assets/pinnace (1277 + 162 + 54 + 54
sommets) : positions bornees, tous les indices valides, et un rendu qui
ressemble a une pinasse.

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


def _donnees(chemin):
    """Les octets utiles d'un .vbuf ou d'un .ibuf, en-tete retire."""
    b = open(chemin, 'rb').read()
    taille = struct.unpack_from('<I', b, 10)[0]
    if not 0 < taille <= len(b):
        raise ValueError(f"{chemin} : taille de donnees illisible ({taille})")
    return b[len(b) - taille:]


def lire_maillage(dossier):
    """-> (sommets, normales, uv, triangles), toutes pieces reunies"""
    paires = [(v, v[:-5] + ".ibuf")
              for v in sorted(glob.glob(os.path.join(dossier, "*.vbuf")))]
    paires = [(v, i) for v, i in paires if os.path.exists(i)]
    if not paires:
        raise FileNotFoundError(f"pas de paire .vbuf/.ibuf dans {dossier}")

    sommets, normales, uv, triangles = [], [], [], []
    for chemin_v, chemin_i in paires:
        v = _donnees(chemin_v)
        i = _donnees(chemin_i)
        m = len(i) // 2
        m -= m % 3
        idx = struct.unpack_from(f'<{m}H', i, 0)
        n = max(idx) + 1
        pas = len(v) // n
        base = len(sommets)

        for k in range(n):
            o = k * pas
            if pas == 16:
                px, py, pz = struct.unpack_from('<3H', v, o)
                nx, ny, nz, _ = struct.unpack_from('<4b', v, o + 8)
                tu, tv = struct.unpack_from('<2H', v, o + 12)
                sommets.append((_demi(px), _demi(py), _demi(pz)))
                normales.append((nx / 127.0, ny / 127.0, nz / 127.0))
                uv.append((_demi(tu), _demi(tv)))
            elif pas == 80:
                sommets.append(struct.unpack_from('<3f', v, o))
                normales.append(struct.unpack_from('<3f', v, o + 28))
                uv.append(struct.unpack_from('<2f', v, o + 64))
            else:
                raise ValueError(f"{chemin_v} : pas de sommet inconnu ({pas} octets)")

        triangles.extend((idx[k] + base, idx[k + 1] + base, idx[k + 2] + base)
                         for k in range(0, m, 3))
    return sommets, normales, uv, triangles


def lire_texture(dossier):
    """Premiere texture DDS du dossier -> (largeur, hauteur, rgba)"""
    dds = sorted(glob.glob(os.path.join(dossier, "*.dds")))
    if not dds:
        return None
    w, h, _, px = lire_dds(dds[0])
    return w, h, px


def _reduire(img, grand, petit, n):
    """Moyenne des blocs n x n : le lissage qui manque au rastériseur."""
    out = bytearray(petit * petit * 4)
    inv = 1.0 / (n * n)
    for y in range(petit):
        for x in range(petit):
            r = g = b = a = 0
            for dy in range(n):
                base = ((y * n + dy) * grand + x * n) * 4
                for dx in range(n):
                    o = base + dx * 4
                    r += img[o]; g += img[o + 1]; b += img[o + 2]; a += img[o + 3]
            d = (y * petit + x) * 4
            out[d] = int(r * inv)
            out[d + 1] = int(g * inv)
            out[d + 2] = int(b * inv)
            out[d + 3] = int(a * inv)
    return out


def rendre(dossier, sortie, taille=512, angle=58.0, lumiere=(-0.55, 0.68, -0.48),
           gain=1.0, sursample=1):
    """Rend le maillage en plongee oblique, sur fond transparent.

    `sursample` : rend N fois plus grand, puis reduit en moyennant. C'est le seul
    lissage de ce rastériseur, qui ecrit sinon un pixel par triangle sans aucun
    fondu -- d'ou des contours en escalier et un grain sale qui mange les formes
    a petite taille. Les vignettes de batiment du menu radial en vivaient.
    """
    sortie_taille = taille
    sursample = max(1, int(sursample))
    # Tout le rendu travaille en GRAND : `taille` est locale, la reassigner ici
    # suffit a mettre projection, cadrage et tampons a l'echelle.
    taille = taille * sursample
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

                # LE GAIN. L'ombrage `0,62 + 0,48 x eclairement` est celui d'un
                # rendu neutre ; les textures de batiment de PR3 sont sombres, et
                # les vignettes sortaient illisibles. Le jeu, lui, eclaire sa
                # carte avec un soleil a 2,5 et un ciel a 1,5 (releve dans
                # `seamap.sceneview`, voir outils/PR3_TECHNIQUE.md) -- trois a
                # quatre fois plus que ce rendu. `rendre_navires_pr3.gd` avait
                # paye la meme lecon : ses navires « sortaient sombres ».
                #
                # Defaut a 1,0 : le comportement d'avant, pour ne rien changer a
                # qui ne demande rien.
                f = (0.62 + 0.48 * eclair) * gain
                d = o * 4
                img[d] = min(255, int(r * f))
                img[d + 1] = min(255, int(g * f))
                img[d + 2] = min(255, int(b_ * f))
                img[d + 3] = 255

    if sursample > 1:
        img = _reduire(img, taille, sortie_taille, sursample)
    ecrire_png(sortie, sortie_taille, sortie_taille, img)
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
