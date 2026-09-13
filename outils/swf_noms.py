# Dresse la carte id->nom (SymbolClass) d'un SWF, et pour chaque sprite exporte
# les bitmaps qu'il place (chaine sprite->PlaceObject->bitmap). But : identifier
# quelle tuile skin est le cadre / l'onglet / le bouton, SANS la voir.
import sys, struct, zlib
sys.path.insert(0, r"D:\GOG Galaxy\Games\Port Royale 3\_mod\pr3")
import pr3fuk

def charger(nom):
    for a in ("data0.fuk","data.fuk"):
        ar=pr3fuk.load(r"D:\GOG Galaxy\Games\Port Royale 3\\"+a)
        e=pr3fuk.find(ar,nom)
        if e:
            d=pr3fuk.content(ar,e)
            if d[:3]==b'CWS': d=b'FWS'+d[3:8]+zlib.decompress(d[8:])
            return d
    raise LookupError(nom)

def tags(d):
    class B:
        def __init__(s,dd,p): s.d=dd; s.p=p; s.b=0
        def u(s,k):
            v=0
            for _ in range(k):
                v=(v<<1)|((s.d[s.p]>>(7-s.b))&1); s.b+=1
                if s.b==8: s.b=0; s.p+=1
            return v
    bb=B(d,8); k=bb.u(5); [bb.u(k) for _ in range(4)]
    if bb.b: bb.p+=1
    o=bb.p+4
    out=[]
    while o<len(d)-2:
        rh=struct.unpack_from("<H",d,o)[0]; o+=2
        code=rh>>6; ln=rh&0x3f
        if ln==0x3f: ln=struct.unpack_from("<I",d,o)[0]; o+=4
        if code==0: break
        out.append((code,o,ln)); o+=ln
    return out

def czstr(d,p):
    e=p
    while d[e]: e+=1
    return d[p:e].decode('latin1'), e+1

def main():
    nom=sys.argv[1]
    d=charger(nom)
    T=tags(d)
    names={}       # id -> nom exporte
    bmp={}         # id -> (w,h,type)
    sprites={}     # id -> [placed char ids]
    for code,body,ln in T:
        if code==76:  # SymbolClass
            cnt=struct.unpack_from("<H",d,body)[0]; p=body+2
            for _ in range(cnt):
                cid=struct.unpack_from("<H",d,p)[0]; p+=2
                s,p=czstr(d,p); names[cid]=s
        elif code in (20,36):  # bitmap lossless
            cid=struct.unpack_from("<H",d,body)[0]
            w=struct.unpack_from("<H",d,body+3)[0]; h=struct.unpack_from("<H",d,body+5)[0]
            bmp[cid]=(w,h,'png')
        elif code in (21,35):  # jpeg
            cid=struct.unpack_from("<H",d,body)[0]; bmp[cid]=(0,0,'jpg')
        elif code==39:  # DefineSprite
            sid=struct.unpack_from("<H",d,body)[0]
            # parcourir les sous-tags du sprite pour PlaceObject2/3 -> char place
            p=body+4; placed=[]
            while p<body+ln-1:
                srh=struct.unpack_from("<H",d,p)[0]; p+=2
                sc=srh>>6; sl=srh&0x3f
                if sl==0x3f: sl=struct.unpack_from("<I",d,p)[0]; p+=4
                if sc==0: break
                if sc==26:  # PlaceObject2
                    flags=d[p]
                    if flags&2:  # HasCharacter
                        cid=struct.unpack_from("<H",d,p+3)[0]; placed.append(cid)
                elif sc==70:  # PlaceObject3
                    cid=struct.unpack_from("<H",d,p+4)[0]; placed.append(cid)
                p+=sl
            sprites[sid]=placed
    # sortie : classes exportees, tri par nom
    print(f"=== {nom} : {len(names)} classes, {len(bmp)} bitmaps, {len(sprites)} sprites ===")
    for cid in sorted(names, key=lambda i:names[i].lower()):
        nm=names[cid]
        tag='?'
        if cid in bmp: tag=f"BITMAP {bmp[cid][0]}x{bmp[cid][1]}"
        elif cid in sprites:
            kids=sprites[cid]
            dims=[]
            for kk in kids[:6]:
                if kk in bmp: dims.append(f"bmp{kk}:{bmp[kk][0]}x{bmp[kk][1]}")
                else: dims.append(f"spr{kk}")
            tag=f"SPRITE -> {', '.join(dims)}"+(" ..." if len(kids)>6 else "")
        print(f"  {cid:>5}  {nm:<40} {tag}")

main()
