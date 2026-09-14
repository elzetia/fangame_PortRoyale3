# Lecture commune des .swf de Port Royale 3 : le conteneur, ses caracteres, et
# la resolution symbole -> bitmap.
#
# C'est la SEULE copie de cette logique. `swf_icones.py` (table des symboles
# NOMMES) et `swf_caracteres.py` (table des caracteres ANONYMES) s'en servent
# tous deux. La dupliquer obligerait a corriger deux fois des pieges qui ont
# coute cher :
#
#   * `HasClassName` : dans PlaceObject3, le nom de classe n'est present QUE si
#     le drapeau 0x08 est leve. La spec ajoute « ou HasImage et HasCharacter »,
#     mais Scaleform n'emet alors aucune chaine -- la lire consomme du bourrage
#     et fabrique de faux charId. C'est ce qui faisait resoudre 269 symboles sur
#     une seule et meme mauvaise image.
#   * la forme LONGUE d'une balise : il faut retenir le fait AVANT d'ecraser la
#     longueur, sinon l'avancement compte un en-tete de 2 octets la ou il en
#     fait 6, et tout le sprite se desynchronise.
#
# Un `charId` place dans un agencement designe une FORME, pas un bitmap ; le PNG
# extrait porte l'identifiant du BITMAP que cette forme remplit. Les deux
# numerotations sont disjointes. C'est tout l'objet de `leaves()`.
import os
import struct
import sys
import zlib

sys.path.insert(0, r"D:\GOG Galaxy\Games\Port Royale 3\_mod\pr3")
import pr3fuk

RACINE_PR3 = r"D:\GOG Galaxy\Games\Port Royale 3"
SORTIE = r"D:\GOG Galaxy\Games\PortRoyale3D\reference_pr3\ui"

# Plancher de taille pour le choix d'une feuille. Sans lui, « la plus petite »
# attrape parfois un eclat de plaque de texte (607, qui fait 6x20) au lieu de
# l'icone. A 10 px on garde les 622 bonnes reponses sur 677 et les eclats
# tombent de 50 a 19 ; au-dela cela degrade (620 a 16 px, 613 a 20 px).
PLANCHER = 10


def charger(nom):
    """Le .swf decompresse, pris dans les archives de l'install locale."""
    for a in ("data0.fuk", "data.fuk"):
        ar = pr3fuk.load(os.path.join(RACINE_PR3, a))
        e = pr3fuk.find(ar, nom)
        if e:
            d = pr3fuk.content(ar, e)
            if d[:3] == b'CWS':
                d = b'FWS' + d[3:8] + zlib.decompress(d[8:])
            return d
    raise LookupError(nom)


class Bits:
    """Lecteur de champs de bits : un RECT ou une matrice de SWF n'est pas
    aligne sur l'octet."""

    def __init__(s, d, p):
        s.d = d
        s.p = p
        s.b = 0

    def align(s):
        if s.b:
            s.b = 0
            s.p += 1

    def u(s, k):
        v = 0
        for _ in range(k):
            v = (v << 1) | ((s.d[s.p] >> (7 - s.b)) & 1)
            s.b += 1
            if s.b == 8:
                s.b = 0
                s.p += 1
        return v

    def sg(s, k):
        v = s.u(k)
        if k and (v >> (k - 1)) & 1:
            v -= (1 << k)
        return v


def rect(b):
    nb = b.u(5)
    a = [b.sg(nb) for _ in range(4)]
    b.align()
    return a


def matrice(b):
    """La TRANSLATION d'une MATRIX de SWF, en pixels. L'echelle et la rotation
    sont lues pour avancer, puis jetees : seul le point d'ancrage nous occupe."""
    if b.u(1):
        n = b.u(5); b.sg(n); b.sg(n)        # echelle
    if b.u(1):
        n = b.u(5); b.sg(n); b.sg(n)        # rotation
    n = b.u(5)
    tx = b.sg(n) / 20.0
    ty = b.sg(n) / 20.0
    b.align()
    return tx, ty


def strz(d, o):
    e = d.index(b'\0', o)
    return d[o:e].decode('latin1'), e + 1


def sof(jpg):
    """Dimensions d'un flux JPEG, lues a son marqueur SOF. Sans elles, les
    symboles dont l'art est un JPEG sortaient en (0,0) et le filtre de taille
    les jetait en silence -- quatre entrees de la table avaient ainsi disparu."""
    i = jpg.find(b"\xff\xd8")
    if i < 0:
        return (0, 0)
    i += 2
    while i + 4 < len(jpg):
        if jpg[i] != 0xFF:
            i += 1
            continue
        m = jpg[i + 1]
        if m in (0xC0, 0xC1, 0xC2, 0xC3, 0xC9, 0xCA, 0xCB):
            return (struct.unpack_from(">H", jpg, i + 7)[0],
                    struct.unpack_from(">H", jpg, i + 5)[0])
        if m in (0xD8, 0xD9) or 0xD0 <= m <= 0xD7:
            i += 2
            continue
        i += 2 + struct.unpack_from(">H", jpg, i + 2)[0]
    return (0, 0)


class Swf:
    """Un .swf de PR3, parse : ses symboles nommes, ses bitmaps, ses sprites et
    ses formes -- de quoi remonter de n'importe quel caractere a son image."""

    def __init__(self, nom):
        self.nom = nom
        self.base = nom.replace(".swf", "")
        self.d = charger(nom)
        self.names = {}     # charId -> nom de classe (SymbolClass)
        self.bmp = {}       # charId -> (largeur, hauteur)
        self.sprites = {}   # charId -> [charId des enfants places]
        self.shapes = {}    # charId -> (code, offset, longueur)
        self._parcourir()

    def _parcourir(self):
        d = self.d
        b = Bits(d, 8)
        rect(b)
        o = b.p + 4
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
            body = o
            if code == 76:                      # SymbolClass
                cnt = struct.unpack_from("<H", d, body)[0]
                p = body + 2
                for _ in range(cnt):
                    cid = struct.unpack_from("<H", d, p)[0]
                    p += 2
                    nm, p = strz(d, p)
                    self.names[cid] = nm
            elif code in (20, 36):              # DefineBitsLossless / 2
                cid = struct.unpack_from("<H", d, body)[0]
                self.bmp[cid] = (struct.unpack_from("<H", d, body + 3)[0],
                                 struct.unpack_from("<H", d, body + 5)[0])
            elif code in (21, 35, 6, 90):       # DefineBitsJPEG*
                cid = struct.unpack_from("<H", d, body)[0]
                p = body + 2
                if code == 35:
                    p += 4                      # longueur des donnees alpha
                self.bmp[cid] = sof(bytes(d[p:body + ln]))
            elif code == 39:                    # DefineSprite
                self.sprites[struct.unpack_from("<H", d, body)[0]] = \
                    self._enfants(body, ln)
            elif code in (2, 22, 32, 83):       # DefineShape*
                self.shapes[struct.unpack_from("<H", d, body)[0]] = (code, body, ln)
            o += ln

    def _enfants(self, body, ln):
        """Les enfants places dans un sprite : (charId, tx, ty).

        La TRANSLATION compte autant que le charId. L'art d'un symbole n'est pas
        forcement pose sur son point de placement : `char124` de hud_pc porte le
        sien a +363 px, et sans cette translation l'icone sortait a 500 px de la
        planche a laquelle elle appartient."""
        d = self.d
        p = body + 4
        kids = []
        while p < body + ln - 1:
            srh = struct.unpack_from("<H", d, p)[0]
            hp = p
            p += 2
            sc = srh >> 6
            sl = srh & 0x3f
            # Forme LONGUE : retenir le fait AVANT d'ecraser `sl`.
            longue = (sl == 0x3f)
            if longue:
                sl = struct.unpack_from("<I", d, p)[0]
                p += 4
            if sc == 0:
                break
            if sc in (26, 70):
                f1 = d[p]
                cid = None
                q = None
                if sc == 26:
                    q = p + 3
                    if f1 & 0x02:
                        cid = struct.unpack_from("<H", d, q)[0]
                        q += 2
                else:
                    f2 = d[p + 1]
                    q = p + 4
                    # Nom de classe seulement si HasClassName (voir l'en-tete).
                    if f2 & 0x08:
                        _, q = strz(d, q)
                    if f1 & 0x02:
                        cid = struct.unpack_from("<H", d, q)[0]
                        q += 2
                tx = ty = 0.0
                if cid is not None and (f1 & 0x04):
                    tx, ty = matrice(Bits(d, q))
                if cid is not None:
                    kids.append((cid, tx, ty))
            p = hp + (6 if longue else 2) + sl
        return kids

    def shape_bmps(self, cid):
        """Les bitmaps que les remplissages d'une forme designent (0x40..0x43)."""
        d = self.d
        code, body, ln = self.shapes[cid]
        shape3 = code in (32, 83)
        bb = Bits(d, body + 2)
        rect(bb)
        if code == 83:
            rect(bb)
            bb.p += 1
        bb.align()
        n = d[bb.p]
        bb.p += 1
        if n == 0xff:
            n = struct.unpack_from("<H", d, bb.p)[0]
            bb.p += 2
        out = []
        for _ in range(n):
            if bb.p >= body + ln:
                break
            t = d[bb.p]
            bb.p += 1
            if t == 0:
                bb.p += 4 if shape3 else 3
            elif t in (0x10, 0x12, 0x13):
                if bb.u(1):
                    k = bb.u(5); bb.u(k); bb.u(k)
                if bb.u(1):
                    k = bb.u(5); bb.u(k); bb.u(k)
                k = bb.u(5); bb.u(k); bb.u(k); bb.align()
                bb.u(4)
                num = bb.u(4)
                for _ in range(num):
                    bb.p += 1 + (4 if shape3 else 3)
            elif t in (0x40, 0x41, 0x42, 0x43):
                bid = struct.unpack_from("<H", d, bb.p)[0]
                bb.p += 2
                if bid in self.bmp:
                    out.append(bid)
                if bb.u(1):
                    k = bb.u(5); bb.u(k); bb.u(k)
                if bb.u(1):
                    k = bb.u(5); bb.u(k); bb.u(k)
                k = bb.u(5); bb.u(k); bb.u(k); bb.align()
            else:
                break
        return out

    def leaves(self, cid, seen=None, prof=0):
        """Tous les bitmaps atteignables depuis un caractere, a travers sprites
        ET remplissages de formes."""
        if seen is None:
            seen = set()
        if cid in seen or prof > 8:
            return []
        seen.add(cid)
        if cid in self.bmp:
            return [cid]
        r = []
        if cid in self.shapes:
            try:
                r += self.shape_bmps(cid)
            except Exception:
                pass
        for k, _tx, _ty in self.sprites.get(cid, []):
            for x in self.leaves(k, seen, prof + 1):
                if x not in r:
                    r.append(x)
        return r

    def origine(self, cid, cible, prof=0, seen=None):
        """Ou poser l'art de `cid` par rapport a son point de placement.

        Un charId designe une FORME ou un SPRITE, jamais directement un bitmap,
        et rien ne dit que cet art commence au point de placement :
          * une forme porte ses bornes dans son RECT -- `char147` de hud_pc va
            de -219 a +209, donc sa planche se pose 219 px a GAUCHE du point ;
          * un sprite pose son contenu par une MATRIX, qu'il faut cumuler
            jusqu'au bitmap.

        Mesure sur skinlib_pr3 : les boutons rendent exactement -taille/2 et les
        plaques (0,0). C'est la preuve que la regle « boutons par le centre,
        plaques par le coin », d'abord DEDUITE de la mise en page, n'etait qu'un
        reflet de cette origine -- mais l'origine, elle, couvre aussi ce que la
        regle ne voyait pas (-219, ou (-99,-11) pour char126).

        Rend (dx, dy) en pixels, ou None si `cible` n'est pas atteint.
        """
        if seen is None:
            seen = set()
        if cid in seen or prof > 8:
            return None
        seen = seen | {cid}
        if cid == cible:
            return (0.0, 0.0)
        if cid in self.shapes:
            code, body, ln = self.shapes[cid]
            bb = Bits(self.d, body + 2)
            a = rect(bb)          # xmin, xmax, ymin, ymax, en twips
            try:
                if cible in self.shape_bmps(cid):
                    return (a[0] / 20.0, a[2] / 20.0)
            except Exception:
                pass
            return None
        for k, tx, ty in self.sprites.get(cid, []):
            r = self.origine(k, cible, prof + 1, seen)
            if r is not None:
                return (tx + r[0], ty + r[1])
        return None

    def meilleure(self, cid):
        """Le bitmap qui represente le mieux ce caractere, ou None.

        La PLUS PETITE feuille, pas la plus grande : un symbole d'interface pose
        son glyphe sur un support (cadre de bouton, bandeau de liste) toujours
        plus grand que lui. « La plus grande » ramenait donc le decor. Verifie a
        l'oeil : Cycle -> 1872 (deux fleches) et non 436 (une plaque) ; Bships ->
        1186 (un navire) et non 1480 (un bandeau). Mesure : 622 entrees justes
        sur 677 contre 599 pour l'ancienne regle. C'est une approximation, pas
        une loi -- mais avec le PLANCHER, sans quoi elle attrape des eclats.
        """
        lv = [b for b in self.leaves(cid) if self.bmp[b][0]]
        if not lv:
            return None
        franc = [b for b in lv
                 if min(self.bmp[b][0], self.bmp[b][1]) >= PLANCHER] or lv
        return min(franc, key=lambda b: self.bmp[b][0] * self.bmp[b][1])
