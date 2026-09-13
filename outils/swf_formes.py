# Decode les FillStyles/LineStyles des DefineShape references par une classe
# (sous-chaine de nom). Donne les couleurs REELLES du cadre PR3 : solides,
# degrades (stops RGBA), ou remplissage bitmap (id). Sert a reproduire le skin.
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

class R:
    def __init__(s,d,p): s.d=d; s.p=p; s.b=0
    def align(s):
        if s.b: s.b=0; s.p+=1
    def u8(s):
        s.align(); v=s.d[s.p]; s.p+=1; return v
    def u16(s):
        s.align(); v=struct.unpack_from("<H",s.d,s.p)[0]; s.p+=2; return v
    def u32(s):
        s.align(); v=struct.unpack_from("<I",s.d,s.p)[0]; s.p+=4; return v
    def ub(s,k):
        v=0
        for _ in range(k):
            v=(v<<1)|((s.d[s.p]>>(7-s.b))&1); s.b+=1
            if s.b==8: s.b=0; s.p+=1
        return v
    def rect(s):
        nb=s.ub(5); [s.ub(nb) for _ in range(4)]; s.align()
    def rgb(s): return (s.u8(),s.u8(),s.u8(),255)
    def rgba(s): return (s.u8(),s.u8(),s.u8(),s.u8())
    def matrix(s):
        if s.ub(1): n=s.ub(5); s.ub(n); s.ub(n)          # scale
        if s.ub(1): n=s.ub(5); s.ub(n); s.ub(n)          # rotate
        n=s.ub(5); s.ub(n); s.ub(n); s.align()           # translate
    def gradient(s,shape3):
        s.ub(2); s.ub(2)  # spread + interp (part of first byte)
        # relire proprement : SpreadMode(2)+InterpMode(2)+NumGradients(4)
        # on a deja lu 4 bits ; lire 4 pour num
        num=s.ub(4)
        stops=[]
        for _ in range(num):
            ratio=s.u8()
            c=s.rgba() if shape3 else s.rgb()
            stops.append((ratio,c))
        return stops

def fillstyles(r,shape3):
    n=r.u8()
    if n==0xff: n=r.u16()
    out=[]
    for _ in range(n):
        t=r.u8()
        if t==0x00:
            c=r.rgba() if shape3 else r.rgb(); out.append(("solid",c))
        elif t in (0x10,0x12,0x13):
            r.matrix(); st=r.gradient(shape3); out.append(("grad",st))
        elif t in (0x40,0x41,0x42,0x43):
            bid=r.u16(); r.matrix(); out.append(("bitmap",bid))
        else:
            out.append(("?",t)); break
    return out

def linestyles(r,shape3):
    n=r.u8()
    if n==0xff: n=r.u16()
    out=[]
    for _ in range(n):
        w=r.u16()
        c=r.rgba() if shape3 else r.rgb()
        out.append((w,c))
    return out

d=charger(sys.argv[1]); T=tags(d)
names={}; sprites={}; shapes={}
for code,body,ln in T:
    if code==76:
        cnt=struct.unpack_from("<H",d,body)[0]; p=body+2
        for _ in range(cnt):
            cid=struct.unpack_from("<H",d,p)[0]; p+=2
            s,p=czstr(d,p); names[cid]=s
    elif code==39:
        sid=struct.unpack_from("<H",d,body)[0]
        p=body+4; placed=[]
        while p<body+ln-1:
            srh=struct.unpack_from("<H",d,p)[0]; p+=2
            sc=srh>>6; sl=srh&0x3f
            if sl==0x3f: sl=struct.unpack_from("<I",d,p)[0]; p+=4
            if sc==0: break
            if sc==26:
                fl=d[p]
                if fl&2: placed.append(struct.unpack_from("<H",d,p+3)[0])
            elif sc==70: placed.append(struct.unpack_from("<H",d,p+4)[0])
            p+=sl
        sprites[sid]=placed
    elif code in (2,22,32,83):  # DefineShape 1/2/3/4
        sid=struct.unpack_from("<H",d,body)[0]
        shapes[sid]=(code,body,ln)

def find_shapes(cid,seen=None):
    if seen is None: seen=set()
    if cid in seen: return []
    seen.add(cid)
    if cid in shapes: return [cid]
    r=[]
    for k in sprites.get(cid,[]): r+=find_shapes(k,seen)
    return r

motif=sys.argv[2].lower()
for cid in sorted(names):
    if motif not in names[cid].lower(): continue
    for sid in find_shapes(cid):
        code,body,ln=shapes[sid]
        shape3 = code in (32,83)
        r=R(d,body+2)  # skip shape id
        r.rect()       # bounds
        if code==83:   # shape4 : edge bounds + flags
            r.rect(); r.u8()
        try:
            fs=fillstyles(r,shape3); ls=linestyles(r,shape3)
        except Exception as ex:
            print(f"{names[cid]} shape{sid}: erreur {ex}"); continue
        print(f"{names[cid]} (shape {sid}, def{code}):")
        for f in fs:
            if f[0]=="solid": print(f"   fill solid  rgba{f[1]}")
            elif f[0]=="grad": print(f"   fill grad   "+" ".join(f"{s[0]}:{s[1]}" for s in f[1]))
            elif f[0]=="bitmap": print(f"   fill bitmap id={f[1]}")
            else: print(f"   fill {f}")
        for w,c in ls: print(f"   line w={w/20:.1f}px rgba{c}")
