# Dispose : pour chaque DefineSprite (et le main timeline), liste les PlaceObject
# (depth, charId, nom instance, x,y en px) + les DefineEditText (bounds, variable,
# texte initial, html) et DefineText. Donne l'agencement d'un ecran PR3.
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

def czstr(d,p):
    e=p
    while d[e]: e+=1
    return d[p:e].decode('latin1'), e+1

class R:
    def __init__(s,d,p): s.d=d; s.p=p; s.b=0
    def align(s):
        if s.b: s.b=0; s.p+=1
    def ub(s,k):
        v=0
        for _ in range(k):
            v=(v<<1)|((s.d[s.p]>>(7-s.b))&1); s.b+=1
            if s.b==8: s.b=0; s.p+=1
        return v
    def sb(s,k):
        v=s.ub(k)
        if v>>(k-1): v-=(1<<k)
        return v
    def rect(s):
        nb=s.ub(5); a=[s.sb(nb) for _ in range(4)]; s.align(); return a
    def matrix(s):
        tx=ty=0
        if s.ub(1): n=s.ub(5); s.ub(n); s.ub(n)
        if s.ub(1): n=s.ub(5); s.ub(n); s.ub(n)
        n=s.ub(5); tx=s.sb(n); ty=s.sb(n); s.align()
        return tx,ty

def tags(d):
    r=R(d,8); r.rect(); r.align(); p=r.p+4
    out=[]
    while p<len(d)-2:
        rh=struct.unpack_from("<H",d,p)[0]; p+=2
        code=rh>>6; ln=rh&0x3f
        if ln==0x3f: ln=struct.unpack_from("<I",d,p)[0]; p+=4
        if code==0: break
        out.append((code,p,ln)); p+=ln
    return out

def place(d,body,ln):
    # PlaceObject2 (26)
    r=R(d,body); fl=r.ub(8); depth=struct.unpack_from("<H",d,r.p)[0]; r.p+=2
    cid=name=None; tx=ty=0
    if fl&2: cid=struct.unpack_from("<H",d,r.p)[0]; r.p+=2
    if fl&4: tx,ty=r.matrix()
    if fl&8:  # cxform
        pass
    # ratio, name...
    return depth,cid,tx,ty

def place3(d,body,ln):
    r=R(d,body); fl1=r.ub(8); fl2=r.ub(8); depth=struct.unpack_from("<H",d,r.p)[0]; r.p+=2
    cid=None; tx=ty=0
    if fl1&2: cid=struct.unpack_from("<H",d,r.p)[0]; r.p+=2
    if fl1&4: tx,ty=r.matrix()
    return depth,cid,tx,ty

d=charger(sys.argv[1]); T=tags(d)
names={}
for code,body,ln in T:
    if code==76:
        cnt=struct.unpack_from("<H",d,body)[0]; p=body+2
        for _ in range(cnt):
            cid=struct.unpack_from("<H",d,p)[0]; p+=2
            s,p=czstr(d,p); names[cid]=s

def nm(cid): return names.get(cid, f"char{cid}")

print(f"=== {sys.argv[1]} : classes ===")
for cid in sorted(names): print(f"  {cid:>4}  {names[cid]}")

# DefineEditText (37)
print("=== DefineEditText (champs texte) ===")
for code,body,ln in T:
    if code==37:
        r=R(d,body); cid=struct.unpack_from("<H",d,body)[0]; r.p=body+2
        bounds=r.rect(); r.align()
        fl=struct.unpack_from("<H",d,r.p)[0]; r.p+=2
        hasText=fl&0x80; hasFont=fl&0x1; hasColor=fl&0x4; hasMaxLen=fl&0x2
        hasLayout=fl&0x20; html=fl&0x40
        if hasFont: r.p+=2; r.p+=2  # fontID+height
        if fl&0x8000: r.p+=2  # hasFontClass? (approx)
        if hasColor: r.p+=4
        if hasMaxLen: r.p+=2
        if hasLayout: r.p+=1+2+2+2+2
        var,r.p=czstr(d,r.p)
        txt=""
        if hasText: txt,r.p=czstr(d,r.p)
        w=(bounds[1]-bounds[0])/20; h=(bounds[3]-bounds[2])/20
        print(f"  {cid} '{nm(cid)}' {w:.0f}x{h:.0f}px var='{var}' html={'Y' if html else 'N'} txt={txt[:60]!r}")
