# La localisation de Port Royale 3, decodee.
#
# Les textes vivent dans data_fr.fuk -> ui/locale/frfr/global.res, au format
# maison "L10N" v2.1 :
#   entete : 'L10N'(4) version(u32) nombre(u32)
#   table  : `nombre` enregistrements de 12 octets (hash u32, offset u32, longueur u32)
#   textes : UTF-16LE, a partir de la fin de table ; les offsets sont comptes
#            depuis la fin de l'entete, d'ou le +12 a appliquer.
#
# Les cles (ID_GUI_*, 2610 dans l'exe) n'y figurent PAS : la table les designe
# par un hash. Ce hash est un polynome simple, retrouve en ancrant sur une paire
# connue (ID_GUI_TOWN_WEALTH_00 = "Pauvrete") :
#
#       h = 0 ; pour chaque octet c : h = (h * 113 + c) mod 2^32
#
# On le verifie sur la serie des sept paliers de prosperite, dont les hashes
# sont consecutifs -- propriete d'un hash polynomial quand seul le dernier
# caractere change.
#
# Ecrit reference_pr3/ui/agencement/textes_fr.txt (ignore par git : texte du jeu).
import sys, struct, os, re

JEU = r"D:\GOG Galaxy\Games\Port Royale 3"
SORTIE = r"D:\GOG Galaxy\Games\PortRoyale3D\reference_pr3\ui\agencement\textes_fr.txt"
sys.path.insert(0, os.path.join(JEU, "_mod", "pr3"))


def hash_cle(cle):
    h = 0
    for c in cle.encode("latin1"):
        h = (h * 113 + c) & 0xFFFFFFFF
    return h


def charger_res():
    import pr3fuk
    ar = pr3fuk.load(os.path.join(JEU, "data_fr.fuk"))
    e = [x for x in ar["files"] if x["path"].endswith("global.res")][0]
    return pr3fuk.content(ar, e)


def table(d):
    magic, ver, n = struct.unpack_from("<4sII", d, 0)
    assert magic == b"L10N", magic
    out = {}
    for i in range(n):
        h, off, ln = struct.unpack_from("<III", d, 12 + i * 12)
        out[h] = d[off + 12:off + 12 + ln].decode("utf-16-le", "replace").rstrip("\x00")
    return out, ver, n


MOTIF = r"(?:ID|IMG)_[A-Z0-9_]{3,70}"


def cles_exe():
    """L'executable : la source d'origine, 2610 cles."""
    exe = open(os.path.join(JEU, "PortRoyale3.exe"), "rb").read()
    return {m.group(0).decode("latin1")
            for m in re.finditer(MOTIF.encode("latin1"), exe)}


def cles_swf():
    """Le bytecode des 169 ecrans. Gisement jamais fouille : les infobulles du
    jeu (`ID_GUI_TT_*`) n'existent QUE la. Comme elles n'etaient pas dans l'exe,
    elles n'etaient jamais hachees -- donc jamais appariees, alors que leur
    texte est bien dans global.res."""
    import glob
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from swf_lecture import Swf
    base = os.path.join(os.path.dirname(os.path.dirname(SORTIE)), "agencement")
    out = set()
    for p in sorted(glob.glob(os.path.join(base, "*.json"))):
        try:
            s = Swf(os.path.basename(p)[:-5] + ".swf")
        except Exception:
            continue
        for c in s.chaines():
            if re.fullmatch(MOTIF, c):
                out.add(c)
    return out


def cles_xml():
    """Les XML d'aide, en clair : `ui/help_hud.xml` nomme les entrees d'aide du
    HUD, `ui/gui.xml` le cablage des ecrans."""
    import pr3fuk
    ar = pr3fuk.load(os.path.join(JEU, "data0.fuk"))
    out = set()
    for e in ar["files"]:
        if not e["path"].lower().endswith(".xml"):
            continue
        try:
            t = pr3fuk.content(ar, e).decode("utf-8", "replace")
        except Exception:
            continue
        out |= set(re.findall(MOTIF, t))
    return out


def main():
    d = charger_res()
    txt, ver, n = table(d)
    sources = [("exe", cles_exe()), ("swf", cles_swf()), ("xml", cles_xml())]
    for nom, s in sources:
        print(f"   source {nom:<4} : {len(s)} cles")
    cles = sorted(set().union(*(s for _, s in sources)))
    trouve = {}
    for k in cles:
        h = hash_cle(k)
        if h in txt:
            trouve[k] = txt[h]
    os.makedirs(os.path.dirname(SORTIE), exist_ok=True)
    with open(SORTIE, "w", encoding="utf-8") as f:
        for k in sorted(trouve):
            f.write(f"{k}\t{trouve[k]}\n")
    print(f"L10N v{ver >> 8}.{ver & 0xFF} : {n} textes ; {len(cles)} cles dans l'exe ; "
          f"{len(trouve)} appariees ({100 * len(trouve) // max(1, len(cles))} %)")
    for k in ("ID_GUI_TOWN_WEALTH_00", "ID_GUI_TOWN_WEALTH_05", "ID_GUI_TOWN_WEALTH_07"):
        print(f"   {k} = {trouve.get(k, '?')!r}")


if __name__ == "__main__":
    main()
