# -*- coding: utf-8 -*-
"""Greffe sur PortRoyale3.exe : le COMMERCE alimente la reputation de COURONNE.

Le probleme, tel que le code le montre. PR3 tient DEUX reputations distinctes :

  - par VILLE : un vecteur d'enregistrements de 12 octets a `joueur+0x1B8`,
    accumulateur borne a +/-1000, affichage = (base+acc)/10 borne 0..100.
    Alimente par le commerce : 0x7839E0 (vendre sous le seuil X1) et 0x783B40.
  - par NATION : quatre u32 a `magasin+nation*4+0x20`, bornes 0..1000, affichage
    /10. Alimentee UNIQUEMENT par 0x75C700, lui-meme atteint par les missions,
    l'annexion, le rasage de repaires et les attaques en temps de guerre.

Aucun chemin du commerce n'atteint la seconde. D'ou la sensation que la
reputation « descend vite et ne remonte jamais » : les penalites de piraterie
frappent les quatre couronnes a la fois (0x783510 boucle sur 0..3), tandis que
le seul gain renouvelable -- les missions d'administrateur -- exige deja 25 % de
reputation pour que le gouverneur accepte de vous recevoir. C'est un verrou
d'amorcage, pas une lenteur.

Ce que fait la greffe. Dans 0x7839E0, le `call 0x759F00` de 0x783A79 fait
exactement 5 octets -- la taille d'un jmp rel32. On le remplace par un saut vers
une section ajoutee, qui refait l'appel d'origine puis accorde en plus un petit
gain a la nation proprietaire de la ville, avant de revenir a 0x783A7E.

Faits verifies avant ecriture :
  [ville+0x36]      index de nation 0..3 (confirme par 6 sites `cmp al,4; jae`)
  0x75C700(idx,val) thiscall, ecx = joueur+0x1B8, accumule et borne a 1000
  0x759F00          ne touche jamais ebx : l'objet ville survit a l'appel
  exe sans ASLR     DllCharacteristics 0x8100, table de relocations vide

N'ECRIT JAMAIS sur l'installation : il produit une COPIE patchee.
Usage : py -3 pr3_patch_reputation.py <exe_source> <exe_sortie> [valeur]
"""
import struct, shutil, sys

HOOK, RETOUR = 0x783A79, 0x783A7E
ORIG, CROWN = 0x759F00, 0x75C700
OCTETS_ORIGINE = bytes.fromhex('e8 82 64 fd ff')   # call 0x759F00


def off(va):
    """Adresse virtuelle -> offset fichier, pour la section .text."""
    return 0x400 + (va - 0x401000)


def greffon(cave_va, valeur):
    """Assemble le greffon. Rend les octets."""
    def rel32(depuis, vers):
        return struct.pack('<i', vers - (depuis + 5))

    c = bytearray()
    ici = lambda: cave_va + len(c)
    c += b'\xe8' + rel32(ici(), ORIG)        # call 0x759F00  (consomme ses 2 args)
    c += b'\x50'                              # push eax       (sauve le retour)
    c += b'\x0f\xb6\x43\x36'                  # movzx eax, byte [ebx+0x36]
    c += b'\x3c\x04'                          # cmp al, 4
    s1 = len(c); c += b'\x73\x00'             # jae SKIP
    c += b'\x8b\x4d\x0c'                      # mov ecx, [ebp+0xC]
    c += b'\x8b\x49\x1c'                      # mov ecx, [ecx+0x1C]   (joueur)
    c += b'\x85\xc9'                          # test ecx, ecx
    s2 = len(c); c += b'\x74\x00'             # je SKIP
    c += b'\x81\xc1\xb8\x01\x00\x00'          # add ecx, 0x1B8        (magasin)
    c += b'\x6a' + bytes([valeur])            # push valeur           (arg2)
    c += b'\x50'                              # push eax              (arg1 = nation)
    c += b'\xe8' + rel32(ici(), CROWN)        # call 0x75C700 (ret 8)
    skip = len(c)
    c[s1 + 1] = skip - (s1 + 2)
    c[s2 + 1] = skip - (s2 + 2)
    c += b'\x58'                              # pop eax
    c += b'\xe9' + rel32(ici(), RETOUR)       # jmp 0x783A7E
    return bytes(c)


def patcher(src, out, valeur=2):
    shutil.copyfile(src, out)
    d = bytearray(open(out, 'rb').read())
    if d[off(HOOK):off(HOOK) + 5] != OCTETS_ORIGINE:
        raise SystemExit("site de greffe inattendu : executable different ou deja patche")

    pe = struct.unpack_from('<I', d, 0x3c)[0]
    opt = pe + 24
    n = struct.unpack_from('<H', d, pe + 6)[0]
    hdr = opt + struct.unpack_from('<H', d, pe + 20)[0]
    if hdr + (n + 1) * 40 > struct.unpack_from('<I', d, hdr + 20)[0]:
        raise SystemExit("pas de place dans l'en-tete pour une section de plus")

    o = hdr + (n - 1) * 40
    vsz, rva, rsz, raw = struct.unpack_from('<IIII', d, o + 8)
    if raw + rsz != len(d):
        raise SystemExit("la derniere section ne finit pas en fin de fichier")

    cave_rva = (rva + vsz + 0xFFF) & ~0xFFF
    cave_raw, cave_sz = len(d), 0x1000
    cave_va = struct.unpack_from('<I', d, opt + 28)[0] + cave_rva

    d[off(HOOK):off(HOOK) + 5] = b'\xe9' + struct.pack('<i', cave_va - (HOOK + 5))
    g = greffon(cave_va, valeur)
    d += bytes(cave_sz)
    d[cave_raw:cave_raw + len(g)] = g

    struct.pack_into('<H', d, pe + 6, n + 1)
    struct.pack_into('<I', d, opt + 56, cave_rva + cave_sz)
    struct.pack_into('<8sIIIIIIHHI', d, hdr + n * 40,
                     b'.pr3fix', cave_sz, cave_rva, cave_sz, cave_raw,
                     0, 0, 0, 0, 0x60000020)   # CODE | EXECUTE | READ
    open(out, 'wb').write(d)
    return cave_va, len(g)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    val = int(sys.argv[3]) if len(sys.argv) > 3 else 2
    va, taille = patcher(sys.argv[1], sys.argv[2], val)
    print(f"greffon de {taille} octets a {va:#x} ; gain de couronne = {val} "
          f"({val / 10:.1f} point affiche) par livraison qualifiante")
