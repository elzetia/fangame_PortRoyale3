# Resout un sprite (par nom de classe, sous-chaine) en la liste des bitmaps
# feuilles qu'il place, recursivement, avec leurs dimensions. Sert a savoir
# QUELLE image extraire pour tel cadre/onglet/fond.
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

d=charger(sys.argv[1])
T=tags(d)
names={}; bmp={}; sprites={}
for code,body,ln in T:
    if code==76:
        cnt=struct.unpack_from("<H",d,body)[0]; p=body+2
        for _ in range(cnt):
            cid=struct.unpack_from("<H",d,p)[0]; p+=2
            s,p=czstr(d,p); names[cid]=s
    elif code in (20,36):
        cid=struct.unpack_from("<H",d,body)[0]
        w=struct.unpack_from("<H",d,body+3)[0]; h=struct.unpack_from("<H",d,body+5)[0]
        bmp[cid]=(w,h)
    elif code in (21,35):
        cid=struct.unpack_from("<H",d,body)[0]; bmp[cid]=('jpg',0)
    elif code==39:
        sid=struct.unpack_from("<H",d,body)[0]
        p=body+4; placed=[]
        while p<body+ln-1:
            srh=struct.unpack_from("<H",d,p)[0]; p+=2
            sc=srh>>6; sl=srh&0x3f
            if sl==0x3f: sl=struct.unpack_from("<I",d,p)[0]; p+=4
            if sc==0: break
            if sc==26:
                flags=d[p]
                if flags&2: placed.append(struct.unpack_from("<H",d,p+3)[0])
            elif sc==70:
                placed.append(struct.unpack_from("<H",d,p+4)[0])
            p+=sl
        sprites[sid]=placed

def leaves(cid,seen=None):
    if seen is None: seen=set()
    if cid in seen: return []
    seen.add(cid)
    if cid in bmp: return [cid]
    r=[]
    for k in sprites.get(cid,[]):
        r+=leaves(k,seen)
    return r

motif=sys.argv[2].lower() if len(sys.argv)>2 else "dialog"
for cid in sorted(names, key=lambda i:names[i].lower()):
    if motif in names[cid].lower():
        lv=leaves(cid)
        info=", ".join(f"{b}({bmp[b][0]}x{bmp[b][1]})" if isinstance(bmp[b][0],int) else f"{b}(jpg)" for b in lv)
        print(f"{cid:>5} {names[cid]:<52} -> {info if info else '(vectoriel/vide)'}")
