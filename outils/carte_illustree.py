# -*- coding: utf-8 -*-
"""Fait d'une illustration LA carte : decor, navigation et nappe de mer.

    py outils/carte_illustree.py <carte.png>

Godot ne garde alors que ce qui BOUGE -- l'eau et les nuages. La terre, le
relief, les montagnes et les arbres viennent tous de l'image, et plus de la
cuisson.

Ce que l'outil ecrit :

  carte_cuite.png       l'illustration, cadre ouvrage retire
  carte_cuite.json      la fiche de projection : l'image est desormais ZENITHALE
                        (angle 90), et non plus en plongee oblique a 58 degres.
  carte_cuite_mer.png   la fiche de mer pour la nappe animee : rouge = eau,
                        vert = profondeur. Deduite de l'image, donc le ressac
                        epouse la cote PEINTE au pixel pres.
  sim/carte_monde.lua   le masque de navigation, deduit de l'image lui aussi.

⚠ CE DERNIER POINT EST LE COEUR DE L'AFFAIRE. Une illustration ne reproduit pas
les contours d'une source, seulement son allure : mesure faite, celle-ci ne
s'accordait qu'a 84 % avec la carte de Port Royale 3. Peindre l'une et naviguer
sur l'autre, c'est un navire qui traverse une ile peinte une fois sur six. On
abandonne donc le masque de PR3 : la cote peinte DEVIENT la cote navigable, et
les soixante ports sont recales dessus.

⚠ Contrepartie a connaitre : l'image fait 1 500 pixels de large la ou la carte
cuite en faisait 6 100. Le monde n'a pas change de taille, donc chaque pixel
couvre quatre fois plus de terrain, et cela se verra au zoom maximal.
"""
import io
import os
import struct
import sys
import zlib
from collections import deque

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(RACINE, "outils"))

from decouper_planche import lire_png      # noqa: E402

NL = chr(10)

# Le cadre ouvrage, mesure sur l'image : la mer commence a quinze pixels du bord.
# On rogne un peu plus large pour n'en garder aucune trace.
MARGE_CADRE = 24

# Largeur du masque de navigation, en cases. La hauteur suit le rapport de
# l'image : c'est elle qui commande desormais, et non l'inverse.
MASQUE_L = 1320

# Unites de monde par case. Inchange : c'est ce qui garde les vitesses de navire
# et les durees de traversee telles qu'on les a reglees.
ECHELLE = 12.0


def ecrire_png(chemin, w, h, rgb, canaux=3):
    brut = bytearray()
    pas = w * canaux
    for y in range(h):
        brut.append(0)
        brut += rgb[y * pas:(y + 1) * pas]

    def bloc(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)

    couleur = 2 if canaux == 3 else 6
    with io.open(chemin, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(bloc(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, couleur, 0, 0, 0)))
        f.write(bloc(b'IDAT', zlib.compress(bytes(brut), 6)))
        f.write(bloc(b'IEND', b''))


def rogner(px, w, h, m):
    nw, nh = w - 2 * m, h - 2 * m
    out = bytearray(nw * nh * 4)
    for y in range(nh):
        s = ((y + m) * w + m) * 4
        d = y * nw * 4
        out[d:d + nw * 4] = px[s:s + nw * 4]
    return out, nw, nh


def silhouette(px, w, h, mw, mh):
    """Terre / mer par case, en moyennant un bloc de l'image.

    On moyenne plutot que d'echantillonner un pixel : une illustration est
    bruitee -- ecume, reflets, ombres de palmier sur le sable -- et un pixel
    isole fait dire n'importe quoi a une case entiere.
    """
    terre = bytearray(mw * mh)
    for cz in range(mh):
        y0 = cz * h // mh
        y1 = max(y0 + 1, (cz + 1) * h // mh)
        for cx in range(mw):
            x0 = cx * w // mw
            x1 = max(x0 + 1, (cx + 1) * w // mw)
            r = v = b = n = 0
            for y in range(y0, y1):
                base = y * w
                for x in range(x0, x1):
                    i = (base + x) * 4
                    r += px[i]; v += px[i + 1]; b += px[i + 2]; n += 1
            r //= n; v //= n; b //= n
            # La mer est bleue et le reste ne l'est pas : sable, jungle, roche,
            # ecume passent tous ce test du bon cote.
            terre[cz * mw + cx] = 0 if (b > r + 20 and b > 58) else 1
    return terre


def ouvrir(m, w, h):
    """Efface les cases isolees, dans un sens comme dans l'autre.

    Une illustration seme des reflets clairs au large et des flaques sombres
    dans les terres. Sans ce nettoyage, le masque se retrouve constelle d'ilots
    d'une case sur lesquels un navire viendrait buter sans qu'on voie pourquoi.
    """
    out = bytearray(m)
    for z in range(h):
        for x in range(w):
            n = 0
            for dz in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dz == 0:
                        continue
                    u, v = x + dx, z + dz
                    if 0 <= u < w and 0 <= v < h and m[v * w + u]:
                        n += 1
            i = z * w + x
            if m[i] and n <= 2:
                out[i] = 0
            elif not m[i] and n >= 7:
                out[i] = 1
    return out


def chanfrein(dedans, w, h):
    """Distance de chanfrein 5-7 aux cases ou `dedans` est faux, /5."""
    GRAND = 1 << 28
    d = [0 if not dedans[i] else GRAND for i in range(w * h)]
    for y in range(h):
        base = y * w
        for x in range(w):
            i = base + x
            if d[i] == 0:
                continue
            m = d[i]
            if y > 0:
                if x > 0:
                    m = min(m, d[i - w - 1] + 7)
                m = min(m, d[i - w] + 5)
                if x + 1 < w:
                    m = min(m, d[i - w + 1] + 7)
            if x > 0:
                m = min(m, d[i - 1] + 5)
            d[i] = m
    for y in range(h - 1, -1, -1):
        base = y * w
        for x in range(w - 1, -1, -1):
            i = base + x
            if d[i] == 0:
                continue
            m = d[i]
            if y + 1 < h:
                if x + 1 < w:
                    m = min(m, d[i + w + 1] + 7)
                m = min(m, d[i + w] + 5)
                if x > 0:
                    m = min(m, d[i + w - 1] + 7)
            if x + 1 < w:
                m = min(m, d[i + 1] + 5)
            d[i] = m
    return d


SOCLE = '''
-- On deplie les plages en une CHAINE d'un octet par case, une fois pour toutes.
-- Une table Lua d'un million d'entrees couterait des dizaines de mega-octets et
-- un ramassage de miettes a chaque passage ; une chaine en coute un, et
-- `string.byte` y lit en temps constant.
local morceaux = {}
for y = 1, Carte.hauteur do
  local ligne, valeur = {}, 0
  for _, n in ipairs(Carte.plages[y]) do
    ligne[#ligne + 1] = string.rep(valeur == 1 and "\\1" or "\\0", n)
    valeur = 1 - valeur
  end
  morceaux[y] = table.concat(ligne)
end
Carte.octets = table.concat(morceaux)
Carte.plages = nil


function Carte.terreCase(cx, cz)
  if cx < 0 or cz < 0 or cx >= Carte.largeur or cz >= Carte.hauteur then
    return false
  end
  return string.byte(Carte.octets, cz * Carte.largeur + cx + 1) == 1
end


-- Le masque dilate de `rayon` cases, pour tenir un navire au large. Separable :
-- un maximum glissant horizontal, puis le meme vertical.
local dilates = {}

function Carte.dilate(rayon)
  if rayon <= 0 then return Carte.octets end
  if dilates[rayon] then return dilates[rayon] end
  local L, H = Carte.largeur, Carte.hauteur
  local src, mid = Carte.octets, {}
  for z = 0, H - 1 do
    local base, ligne = z * L, {}
    for x = 0, L - 1 do
      local t = 0
      for d = -rayon, rayon do
        local u = x + d
        if u >= 0 and u < L and string.byte(src, base + u + 1) == 1 then t = 1 break end
      end
      ligne[x + 1] = t == 1 and "\\1" or "\\0"
    end
    mid[z + 1] = table.concat(ligne)
  end
  local sortie = {}
  for z = 0, H - 1 do
    local ligne = {}
    for x = 0, L - 1 do
      local t = 0
      for d = -rayon, rayon do
        local v = z + d
        if v >= 0 and v < H and string.byte(mid[v + 1], x + 1) == 1 then t = 1 break end
      end
      ligne[x + 1] = t == 1 and "\\1" or "\\0"
    end
    sortie[z + 1] = table.concat(ligne)
  end
  dilates[rayon] = table.concat(sortie)
  return dilates[rayon]
end


function Carte.terreCaseDilatee(cx, cz, rayon)
  if cx < 0 or cz < 0 or cx >= Carte.largeur or cz >= Carte.hauteur then
    return false
  end
  return string.byte(Carte.dilate(rayon), cz * Carte.largeur + cx + 1) == 1
end


return Carte
'''


def ecrire_masque(terre, mw, mh):
    lignes = []
    for z in range(mh):
        deb, x, plages, valeur = z * mw, 0, [], 0
        while x < mw:
            x0 = x
            while x < mw and terre[deb + x] == valeur:
                x += 1
            plages.append(x - x0)
            valeur = 1 - valeur
        lignes.append(plages)
    out = [
        "-- Le masque terre/mer, deduit de L'ILLUSTRATION qui sert de carte.",
        "-- Ecrit par `outils/carte_illustree.py`. NE PAS EDITER A LA MAIN.",
        "--",
        "-- Il ne vient plus du `ini/map.bmp` de Port Royale 3. Une illustration ne",
        "-- reproduit pas les contours d'une source, seulement son allure : celle-ci",
        "-- ne s'accordait qu'a 84 % avec le masque de PR3, soit un navire qui",
        "-- traverse une ile peinte une fois sur six. Puisque c'est elle qu'on",
        "-- regarde, c'est elle qui fait loi : la cote PEINTE est la cote navigable.",
        "",
        "local Carte = {}",
        "",
        "Carte.largeur, Carte.hauteur = %d, %d" % (mw, mh),
        "",
        "Carte.plages = {",
    ]
    for plages in lignes:
        out.append("  {" + ",".join(str(n) for n in plages) + "},")
    out.append("}")
    out.append(SOCLE)
    io.open(os.path.join(RACINE, "sim", "carte_monde.lua"), "w",
            encoding="utf-8", newline=NL).write(NL.join(out))
    return sum(len(p) for p in lignes)


def main(chemin):
    w, h, px = lire_png(chemin)
    print("illustration %d x %d" % (w, h))
    px, w, h = rogner(px, w, h, MARGE_CADRE)
    print("cadre retire : %d x %d" % (w, h))

    mh = int(round(MASQUE_L * h / float(w)))
    terre = ouvrir(silhouette(px, w, h, MASQUE_L, mh), MASQUE_L, mh)
    print("masque %d x %d, %.1f %% de terre"
          % (MASQUE_L, mh, 100.0 * sum(terre) / (MASQUE_L * mh)))

    n = ecrire_masque(terre, MASQUE_L, mh)
    print("sim/carte_monde.lua : %d plages" % n)

    # Le decor : l'illustration telle quelle.
    rgb = bytearray(w * h * 3)
    for i in range(w * h):
        rgb[i * 3:i * 3 + 3] = px[i * 4:i * 4 + 3]
    ecrire_png(os.path.join(RACINE, "carte_cuite.png"), w, h, rgb)

    monde = (MASQUE_L * ECHELLE, mh * ECHELLE)
    fiche = ('{' + NL
             + '\t"angle": 90.0,' + NL
             + '\t"centre": [0.0, 0.0],' + NL
             + '\t"vue_taille": [%.1f, %.1f],' % monde + NL
             + '\t"pixels": [%d, %d]' % (w, h) + NL
             + '}' + NL)
    io.open(os.path.join(RACINE, "carte_cuite.json"), "w",
            encoding="utf-8", newline=NL).write(fiche)
    print("carte_cuite.png + .json ecrits (monde %.0f x %.0f, zenithal)" % monde)

    # La fiche de mer, au quart : rouge = eau, vert = profondeur.
    #
    # LE VERT EST UNE RAMPE, ET SON ECHELLE EST TOUT LE SUJET. Le shader ne lit
    # pas une distance : il lit des METRES, et il en tire trois bandes aux
    # seuils fixes -- le ressac sous 3,2 m, le passage au large entre 1,5 et
    # 9 m, les moutons qui s'eteignent a 30 m. Toute la vie de la nappe tient
    # dans ces trente premiers metres.
    #
    # La premiere version calait la pleine echelle sur VINGT cases. Le ressac
    # tombait alors sur la premiere case et les moutons sur les dix premieres :
    # a l'echelle de la carte, un lisere d'une case, echantillonne une fois sur
    # deux par la reduction au quart. Le reste de la mer -- tout le reste --
    # saturait a 255, donc hors de toutes les bandes. On ne voyait plus l'eau
    # bouger nulle part, et la ou elle bougeait encore le liseré montait en
    # marches d'escalier.
    #
    # Une case vaut donc UN METRE sur le plateau, ce qui donne un ressac de
    # trois cases et un plateau moutonnant de trente ; au-dela on va doucement
    # jusqu'au fond, de sorte que le large reste le large.
    mer = [not terre[i] for i in range(MASQUE_L * mh)]
    prof = chanfrein(mer, MASQUE_L, mh)
    PLATEAU, FOND = 30.0, 150.0        # en cases

    def metres(cases):
        if cases <= PLATEAU:
            return cases                      # un metre par case
        if cases >= FOND:
            return 60.0
        return 30.0 + 30.0 * (cases - PLATEAU) / (FOND - PLATEAU)

    fw, fh = MASQUE_L // 2, mh // 2
    fiche_mer = bytearray(fw * fh * 3)
    for y in range(fh):
        for x in range(fw):
            j = (y * fw + x) * 3
            # On reduit par BLOC et non en prenant une case sur deux. Le rouge
            # compte les cases d'eau du bloc, ce qui donne un trait de cote
            # adouci au lieu d'un escalier ; le vert prend la PLUS FAIBLE
            # profondeur, pour qu'une bande etroite ne disparaisse jamais entre
            # deux echantillons.
            eaux, creux = 0, None
            for dy in (0, 1):
                for dx in (0, 1):
                    u, v = x * 2 + dx, y * 2 + dy
                    if u >= MASQUE_L or v >= mh:
                        continue
                    i = v * MASQUE_L + u
                    if mer[i]:
                        eaux += 1
                        c = prof[i] / 5.0          # le chanfrein compte 5 par case
                        if creux is None or c < creux:
                            creux = c
            if eaux:
                fiche_mer[j] = eaux * 255 // 4
                fiche_mer[j + 1] = int(round(metres(creux) * 255.0 / 60.0))
    ecrire_png(os.path.join(RACINE, "carte_cuite_mer.png"), fw, fh, fiche_mer)
    print("carte_cuite_mer.png : %d x %d" % (fw, fh))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1
         else os.path.join(os.path.expanduser("~"), "Downloads", "carte.png"))
