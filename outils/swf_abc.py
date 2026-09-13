# Decode le DoABC (ActionScript 3 compile) d'un SWF : pool de chaines, puis
# classes/traits. Le pool contient TOUS les noms de champs, cles de localisation
# et constantes d'agencement des menus de PR3.
import sys, struct, zlib, re
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

class Bits:
    def __init__(s,d,p): s.d=d; s.p=p; s.b=0
    def ub(s,k):
        v=0
        for _ in range(k):
            v=(v<<1)|((s.d[s.p]>>(7-s.b))&1); s.b+=1
            if s.b==8: s.b=0; s.p+=1
        return v

def tags(d):
    bb=Bits(d,8); k=bb.ub(5); [bb.ub(k) for _ in range(4)]
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

def u30(d,p):
    v=0; sh=0
    for _ in range(5):
        b=d[p]; p+=1
        v |= (b & 0x7f) << sh
        if not (b & 0x80): break
        sh += 7
    return v,p

def abc_strings(abc):
    p=4  # minor,major
    n,p=u30(abc,p)                      # int
    for _ in range(max(0,n-1)): _,p=u30(abc,p)
    n,p=u30(abc,p)                      # uint
    for _ in range(max(0,n-1)): _,p=u30(abc,p)
    n,p=u30(abc,p)                      # double
    p += 8*max(0,n-1)
    n,p=u30(abc,p)                      # strings
    out=[""]
    for _ in range(max(0,n-1)):
        ln,p=u30(abc,p)
        out.append(abc[p:p+ln].decode('utf-8','replace')); p+=ln
    return out

nom=sys.argv[1]
d=charger(nom)
for code,body,ln in tags(d):
    if code!=82: continue
    p=body+4                             # flags u32
    while d[p]: p+=1
    p+=1                                 # name cstring
    abc=d[p:body+ln]
    S=abc_strings(abc)
    print(f"=== {nom} : DoABC, {len(S)} chaines ===")
    motif=sys.argv[2] if len(sys.argv)>2 else None
    vus=set()
    for s in S:
        if not s or s in vus: continue
        vus.add(s)
        if motif and motif.lower() not in s.lower(): continue
        if len(s)>120: continue
        print("  "+s)
