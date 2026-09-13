# Agencement d'un sprite (par sous-chaine de nom de classe) : ses PlaceObject2/3
# directs -> (profondeur, charId + nom de classe du char, nom d'instance, x,y px).
# Les noms d'instance disent la fonction de chaque case (txt_population...).
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
    def u8(s): s.align(); v=s.d[s.p]; s.p+=1; return v
    def u16(s): s.align(); v=struct.unpack_from("<H",s.d,s.p)[0]; s.p+=2; return v
    def ub(s,k):
        v=0
        for _ in range(k):
            v=(v<<1)|((s.d[s.p]>>(7-s.b))&1); s.b+=1
            if s.b==8: s.b=0; s.p+=1
        return v
    def sb(s,k):
        v=s.ub(k)
        if k and v>>(k-1): v-=(1<<k)
        return v
    def matrix(s):
        tx=ty=0
        if s.ub(1): n=s.ub(5); s.ub(n); s.ub(n)
        if s.ub(1): n=s.ub(5); s.ub(n); s.ub(n)
        n=s.ub(5); tx=s.sb(n); ty=s.sb(n); s.align()
        return tx,ty
    def cxform(s,alpha):
        has_add=s.ub(1); has_mul=s.ub(1); n=s.ub(4)
        cnt=(4 if alpha else 3)
        if has_mul:
            for _ in range(cnt): s.sb(n)
        if has_add:
            for _ in range(cnt): s.sb(n)
        s.align()

def tags(d):
    r=R(d,8); nb=r.ub(5); [r.sb(nb) for _ in range(4)]; r.align(); p=r.p+4
    out=[]
    while p<len(d)-2:
        rh=struct.unpack_from("<H",d,p)[0]; p+=2
        code=rh>>6; ln=rh&0x3f
        if ln==0x3f: ln=struct.unpack_from("<I",d,p)[0]; p+=4
        if code==0: break
        out.append((code,p,ln)); p+=ln
    return out

d=charger(sys.argv[1]); T=tags(d)
names={}; sprites={}
for code,body,ln in T:
    if code==76:
        cnt=struct.unpack_from("<H",d,body)[0]; p=body+2
        for _ in range(cnt):
            cid=struct.unpack_from("<H",d,p)[0]; p+=2
            s,p=czstr(d,p); names[cid]=s
    elif code==39:
        sid=struct.unpack_from("<H",d,body)[0]
        sprites[sid]=(body,ln)

def nm(cid): return names.get(cid,f"char{cid}")

def dump_sprite(sid, indent="  "):
    body,ln=sprites[sid]
    p=body+4
    while p<body+ln-1:
        srh=struct.unpack_from("<H",d,p)[0]; hp=p; p+=2
        sc=srh>>6; sl=srh&0x3f
        if sl==0x3f: sl=struct.unpack_from("<I",d,p)[0]; p+=4
        if sc==0: break
        if sc in (26,70):
            r=R(d,p)
            if sc==70: fl2=r.u8()
            fl=r.u8() if sc==26 else r.u8()
            # PlaceObject2: flags(8) déjà lu en fl ; PlaceObject3: fl2 puis fl
            if sc==26:
                flags=fl; depth=r.u16()
                hasChar=flags&2; hasMat=flags&4; hasCx=flags&8
                hasRatio=flags&16; hasName=flags&32; hasClip=flags&64
            else:
                flags=fl; flags2=fl2; depth=r.u16()
                hasChar=flags&2; hasMat=flags&4; hasCx=flags&8
                hasRatio=flags&16; hasName=flags&32; hasClip=flags&64
            cid=None; tx=ty=0; iname=""
            if hasChar: cid=r.u16()
            if hasMat: tx,ty=r.matrix()
            if hasCx: r.cxform(True)
            if hasRatio: r.u16()
            if hasName: iname,r.p=czstr(d,r.p)
            desc=f"{nm(cid)}" if cid is not None else "(modif)"
            print(f"{indent}d{depth:<3} {desc:<48} inst='{iname}'  x={tx/20:.0f} y={ty/20:.0f}")
        p = hp + (6 if sl == 0x3f else 2) + sl

motif=sys.argv[2].lower()
for cid in sorted(names):
    if motif in names[cid].lower() and cid in sprites:
        print(f"### {names[cid]} (sprite {cid}) ###")
        dump_sprite(cid)
