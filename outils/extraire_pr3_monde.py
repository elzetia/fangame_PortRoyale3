# -*- coding: utf-8 -*-
"""Extrait de Port Royale 3 le monde reel : son masque terre/mer et ses 60 villes.

    py outils/extraire_pr3_monde.py

Ecrit deux fichiers de donnees Lua, tous deux relus par `sim/archipel.lua` :

  sim/carte_monde.lua   le masque terre/mer de `ini/map.bmp` (1320 x 960),
                        encode par plages -- la cote est simple, donc six plages
                        suffisent en moyenne par ligne, et le fichier tient en
                        quelques dizaines de kilo-octets la ou le masque brut en
                        pese 158.
  sim/villes_pr3.lua    les 60 villes : nom, case, nation, taille, productions.

CE QUI A ETE RETRO-CONCU ICI, et qui ne l'etait pas dans `_mod/pr3` :

  * `ini/constdata.dat`, enregistrement de 97 octets. L'enregistrement est un
    flux serialise generique : chaque tableau est precede de son NOMBRE. D'ou
    +7 = 4 suivi de quatre flottants (la position, en vecteur4), et +32 = 5
    suivi de CINQ octets -- les index des cinq marchandises produites.
    Le `_mod` d'origine prenait ce 5 pour un marqueur constant ; je l'ai d'abord
    cru aussi, et lu quatre marchandises plus une "region" valant 11 a 14. Ces
    valeurs-la sont en fait teintures, cafe, cacao et tabac : la cinquieme
    marchandise est TOUJOURS une culture coloniale, et c'est le climat qui la
    decide. Les trois verifications qui emportent la conviction : La Havane
    produit du TABAC, New Orleans des TEINTURES (l'indigo de Louisiane) et
    Curacao du CACAO. Avec quatre marchandises seulement, ces quatre cultures
    n'etaient produites nulle part et l'archipel en manquait pour toujours.
  * offsets +41 a +68 : un nombre (4) puis quatre entrees <u32 2><u8 taille><u8 nation>, les nations
    tournant a partir de celle qui possede la ville. Donc +49 = la TAILLE
    (1 bourg, 2 ville, 3 grande ville : 48 / 8 / 4) et +50 = la NATION.
  * Les index de nation se lisent sur la carte : 0 tient tout le Main espagnol,
    Cuba et le Mexique (30 villes) ; 2 tient la cote du golfe -- New Orleans,
    Biloxi, Pensacola, Fort Caroline (10) ; 1 tient Hispaniola et les Petites
    Antilles (15) ; 3 les Bahamas (5). D'ou Espagne, Angleterre, France,
    Hollande. Port Royale et Curacao ESPAGNOLES surprennent, mais c'est juste
    pour l'epoque : la Jamaique l'est jusqu'en 1655 et Curacao jusqu'en 1634.

Les noms viennent de `ui/locale/frfr/global.res` (ID_GUI_TOWN_00 a 59) et les
marchandises de ID_GUI_GOOD_00 a 19 -- c'est ce dernier qui donne l'ordre des
index : bois, briques, ble, fruits, mais, sucre, chanvre, textiles, metal,
coton, objets metal, teintures, cafe, cacao, tabac, viande, vetements, cordes,
rhum, pain.
"""
import io
import os
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PR3_MOD = r"D:\GOG Galaxy\Games\Port Royale 3\_mod\pr3"
sys.path.insert(0, PR3_MOD)

import pr3fuk      # noqa: E402
import pr3data     # noqa: E402
import pr3res      # noqa: E402
import pr3map      # noqa: E402

NL = chr(10)

# L'ordre des index de marchandise dans constdata, donne par ID_GUI_GOOD_xx.
# La cle est la mienne, celle de `sim/marchandises.lua`.
CLES = ["bois", "briques", "ble", "fruits", "mais", "sucre", "chanvre", "tissu",
        "metal", "coton", "outils", "teinture", "cafe", "cacao", "tabac", "viande",
        "vetements", "cordage", "rhum", "pain"]

NATIONS = ["espagne", "angleterre", "france", "hollande"]

# LE PORTUGAL N'EST PAS DANS PORT ROYALE 3 : il n'y a que quatre couronnes.
# C'est un ajout demande, et il prend la cote ouest -- le golfe du Mexique, le
# Yucatan et la cote de la Baie. Dix villes reprises a l'Espagne, qui en garde
# vingt. Vera Cruz est la principale, donc classee grande ville.
PORTUGAL = ["corpus_christi", "tampico", "vera_cruz", "villahermosa", "campeche",
            "sisal", "cancun", "belize", "roatan", "providence"]
PRINCIPALE = "vera_cruz"


def lire():
    jeu = pr3map.game()
    afr = pr3fuk.load(pr3map.orig(jeu, "data_fr.fuk"))
    res = pr3res.Res(pr3fuk.content(afr, pr3fuk.find(afr, "global.res")))
    a0 = pr3fuk.load(pr3map.orig(jeu, "data0.fuk"))
    cd = pr3data.Constdata(pr3fuk.content(a0, "ini/constdata.dat"))

    villes = []
    for i in range(60):
        o = bytes(cd.d[slice(*cd.rec_slice(i))])
        villes.append({
            "idx": i,
            "nom": res.get("ID_GUI_TOWN_%02d" % i),
            "case": (o[2] | o[3] << 8, o[4] | o[5] << 8),
            "taille": o[49],
            "nation": NATIONS[o[50]],
            # +69 = `Region`, l'octet que lit le chargeur [Town%u]. Quatre
            # valeurs, geographiques : 0 golfe et Floride, 1 Mexique et Main,
            # 2 Grandes Antilles, 3 Petites Antilles. Elle repond une pour une a
            # la culture coloniale ci-dessous, sur les soixante villes.
            "region": o[69],
            "produits": [CLES[o[36 + k]] for k in range(5)],
        })
        cle = cle_de(villes[-1]["nom"])
        if cle in PORTUGAL:
            villes[-1]["nation"] = "portugal"
        if cle == PRINCIPALE:
            villes[-1]["taille"] = 3
    afr["f"].close()
    a0["f"].close()
    masque, largeur, hauteur = pr3map.world_mask()
    return villes, masque, largeur, hauteur


def ecrire_masque(masque, w, h):
    """Le masque, encode par plages : chaque ligne alterne mer, terre, mer..."""
    lignes = []
    for y in range(h):
        deb, x, plages = y * w, 0, []
        valeur = 0                     # toute ligne commence par une plage de MER
        while x < w:
            x0 = x
            while x < w and masque[deb + x] == valeur:
                x += 1
            plages.append(x - x0)
            valeur = 1 - valeur
        lignes.append(plages)

    out = [
        "-- Le masque terre/mer du monde de Port Royale 3, extrait de son",
        "-- `ini/map.bmp` par `outils/extraire_pr3_monde.py`. NE PAS EDITER A LA MAIN.",
        "--",
        "-- Une case du masque est l'unite de la carte de PR3, et c'est aussi l'unite",
        "-- dans laquelle ses villes sont placees. Les 60 ports tombent tous sur une",
        "-- case de MER bordant la terre -- c'est la definition d'un mouillage chez",
        "-- lui, et c'est ce qui a servi a verifier que le masque etait lu dans le",
        "-- bon sens : aucune des 60 ne tombe sur la terre ferme.",
        "--",
        "-- Encode par plages, une entree par ligne d'image : la premiere plage est",
        "-- de MER, et l'on alterne ensuite. Une cote est un contour simple, donc il",
        "-- faut peu de plages par ligne -- %d nombres pour %d cases. Le masque"
        % (sum(len(p) for p in lignes), w * h),
        "-- brut en pese 158 ko, ce fichier-ci en pese trente.",
        "",
        "local Carte = {}",
        "",
        "Carte.largeur, Carte.hauteur = %d, %d" % (w, h),
        "",
        "Carte.plages = {",
    ]
    for plages in lignes:
        out.append("  {" + ",".join(str(n) for n in plages) + "},")
    out.append("}")
    out.append("")
    out.append(SOCLE_MASQUE)
    io.open(os.path.join(RACINE, "sim", "carte_monde.lua"), "w",
            encoding="utf-8", newline=NL).write(NL.join(out))
    return sum(len(p) for p in lignes)


SOCLE_MASQUE = '''
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
Carte.plages = nil          -- ne sert plus a rien, et pese


function Carte.terreCase(cx, cz)
  if cx < 0 or cz < 0 or cx >= Carte.largeur or cz >= Carte.hauteur then
    return false
  end
  return string.byte(Carte.octets, cz * Carte.largeur + cx + 1) == 1
end


-- Le masque dilate de `rayon` cases, pour tenir un navire au large.
--
-- La dilatation est SEPARABLE : un maximum glissant horizontal, puis le meme
-- vertical. C'est la difference entre 1,3 million de cases fois (2r+1) au carre
-- et fois 2(2r+1) -- a trois cases de marge, un facteur sept, et c'est ce qui
-- permet de la calculer au demarrage sans que le jeu marque un temps d'arret.
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


def ecrire_villes(villes):
    out = [
        "-- Les 60 villes de Port Royale 3, extraites de son `ini/constdata.dat`",
        "-- par `outils/extraire_pr3_monde.py`. NE PAS EDITER A LA MAIN.",
        "--",
        "-- `case` est la position sur la carte du monde de PR3, en cases de son",
        "-- `ini/map.bmp` -- la meme unite que `sim/carte_monde.lua`.",
        "-- `taille` vaut 1 (bourg), 2 (ville) ou 3 (grande ville) : 48, 8 et 4",
        "-- villes respectivement. `produits` sont les CINQ marchandises que le",
        "-- jeu fait produire a la ville : quatre du fonds commun, plus une",
        "-- culture coloniale (teintures, cafe, cacao ou tabac) dictee par le climat.",
        "--",
        "-- `region` est l'octet +69 de l'enregistrement, `Region` chez PR3 : 0 le",
        "-- golfe et la Floride, 1 le Mexique et le Main, 2 les Grandes Antilles,",
        "-- 3 les Petites. Elle repond une pour une a la culture coloniale, sur les",
        "-- soixante villes -- ce sont deux facons de dire la meme chose.",
        "--",
        "-- La nation est celle du DEPART de PR3, sauf le Portugal, qui n'existe pas",
        "-- chez lui et prend ici la cote ouest. Elle est d'epoque : Port Royale",
        "-- et Curacao sont espagnoles, la Jamaique ne devenant anglaise qu'en 1655",
        "-- et Curacao hollandaise qu'en 1634.",
        "",
        "return {",
    ]
    for v in villes:
        out.append(
            '  { cle = "%s", nom = "%s", nation = "%s", case = { %d, %d },'
            ' taille = %d, region = %d,' % (
                cle_de(v["nom"]), v["nom"], v["nation"],
                v["case"][0], v["case"][1], v["taille"], v["region"]))
        out.append('    produits = { %s } },'
                   % ", ".join('"%s"' % p for p in v["produits"]))
    out.append("}")
    io.open(os.path.join(RACINE, "sim", "villes_pr3.lua"), "w",
            encoding="utf-8", newline=NL).write(NL.join(out) + NL)


ACCENTS = {"\u00e0": "a", "\u00e2": "a", "\u00e4": "a", "\u00e7": "c",
           "\u00e8": "e", "\u00e9": "e", "\u00ea": "e", "\u00eb": "e",
           "\u00ee": "i", "\u00ef": "i", "\u00f4": "o", "\u00f6": "o",
           "\u00f9": "u", "\u00fb": "u", "\u00fc": "u", "\u00ed": "i",
           "\u00e1": "a", "\u00f3": "o", "\u00fa": "u", "\u00f1": "n"}


def cle_de(nom):
    s = nom.lower()
    s = "".join(ACCENTS.get(c, c) for c in s)
    s = "".join(c if c.isalnum() else "_" for c in s)
    while "__" in s:
        s = s.replace("__", "_")
    return s.strip("_")


def main():
    villes, masque, w, h = lire()
    n = ecrire_masque(masque, w, h)
    ecrire_villes(villes)
    terre = sum(masque)
    print("masque %d x %d, %.1f %% de terre, %d plages" % (w, h, 100.0 * terre / (w * h), n))
    print("%d villes ecrites" % len(villes))
    sur_terre = [v["nom"] for v in villes if masque[v["case"][1] * w + v["case"][0]]]
    print("villes tombant sur la terre ferme :", sur_terre or "aucune")
    import collections
    compte = collections.Counter(p for v in villes for p in v["produits"])
    manquants = [c for c in CLES if c not in compte]
    print("marchandises sans producteur :", manquants or "aucune")
    print("  producteurs par marchandise :",
          ", ".join("%s %d" % (c, compte[c]) for c in CLES))
    for nat in NATIONS + ["portugal"]:
        noms = [v["nom"] for v in villes if v["nation"] == nat]
        print("  %-11s %2d" % (nat, len(noms)), ", ".join(noms[:4]), "...")


if __name__ == "__main__":
    main()
