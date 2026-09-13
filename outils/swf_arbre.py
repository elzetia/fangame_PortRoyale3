# Arbre d'agencement COMPLET d'un SWF PR3.
# Cle : PlaceObject3 porte un HasClassName -> une CHAINE de classe avant le charId.
# PR3 instancie ainsi les composants de skinlib_pr3.swf par nom, au runtime.
# Ordre exact PO3 : flags1,u8 | flags2,u8 | depth,u16 | [className] | [charId] |
#                   [matrix] | [cxform] | [ratio] | [name] | [clipDepth]
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

class Bits:
    def __init__(s,d,p): s.d=d; s.p=p; s.b=0
    def align(s):
        if s.b: s.b=0; s.p+=1
    def u(s,k):
        v=0
        for _ in range(k):
            v=(v<<1)|((s.d[s.p]>>(7-s.b))&1); s.b+=1
            if s.b==8: s.b=0; s.p+=1
        return v
    def sg(s,k):
        v=s.u(k)
        if k and (v>>(k-1))&1: v-=(1<<k)
        return v

def rect(b):
    nb=b.u(5); a=[b.sg(nb) for _ in range(4)]; b.align()
    return [x/20.0 for x in a]

def matrix(b):
    sx=sy=1.0; tx=ty=0.0
    if b.u(1):
        n=b.u(5); sx=b.sg(n)/65536.0; sy=b.sg(n)/65536.0
    if b.u(1):
        n=b.u(5); b.sg(n); b.sg(n)
    n=b.u(5); tx=b.sg(n)/20.0; ty=b.sg(n)/20.0
    b.align()
    return tx,ty,sx,sy

def cxform(b):
    ha=b.u(1); hm=b.u(1); n=b.u(4)
    for _ in range(4 if hm else 0): b.sg(n)
    for _ in range(4 if ha else 0): b.sg(n)
    b.align()

def strz(d,o):
    e=d.index(b'\0',o); return d[o:e].decode('latin1'), e+1

def place(d,body,code):
    b=Bits(d,body)
    f1=b.u(8)
    f2=b.u(8) if code==70 else 0
    depth=struct.unpack_from("<H",d,b.p)[0]; b.p+=2
    klass=None
    if code==70 and ((f2 & 0x08) or ((f2 & 0x10) and (f1 & 0x02))):
        klass,b.p=strz(d,b.p)
    cid=None
    if f1 & 0x02:
        cid=struct.unpack_from("<H",d,b.p)[0]; b.p+=2
    tx=ty=0.0; sx=sy=1.0
    if f1 & 0x04: tx,ty,sx,sy=matrix(b)
    if f1 & 0x08: cxform(b)
    if f1 & 0x10: b.p+=2
    name=None
    if f1 & 0x20: name,b.p=strz(d,b.p)
    return ("place",depth,cid,klass,name,tx,ty,sx,sy)

def edittext(d,body):
    eid=struct.unpack_from("<H",d,body)[0]
    b=Bits(d,body+2); r=rect(b)
    hasText=b.u(1); b.u(1); b.u(1); b.u(1); b.u(1)
    hasColor=b.u(1); hasMaxLen=b.u(1); hasFont=b.u(1); hasFontClass=b.u(1); b.u(1)
    hasLayout=b.u(1); b.u(1); b.u(1); b.u(1); b.u(1); b.u(1)
    b.align(); p=b.p
    if hasFont: p+=4
    if hasFontClass: _,p=strz(d,p)
    col=None
    if hasColor:
        col=(d[p],d[p+1],d[p+2],d[p+3]); p+=4
    if hasMaxLen: p+=2
    if hasLayout: p+=9
    var,p=strz(d,p)
    txt=""
    if hasText: txt,p=strz(d,p)
    return ("text",eid,r,var,txt[:60],col)

def walk(d,start,end,sprites,items):
    o=start
    while o<end-1:
        rh=struct.unpack_from("<H",d,o)[0]; o+=2
        code=rh>>6; ln=rh&0x3f
        if ln==0x3f: ln=struct.unpack_from("<I",d,o)[0]; o+=4
        body=o; o2=o+ln
        if code==0: return
        if code==39:
            sid=struct.unpack_from("<H",d,body)[0]
            kids=[]
            walk(d,body+4,o2,sprites,kids)
            sprites[sid]=kids
        elif code in (26,70):
            try: items.append(place(d,body,code))
            except Exception: pass
        elif code==37:
            try: items.append(edittext(d,body))
            except Exception: pass
        elif code==76:
            cnt=struct.unpack_from("<H",d,body)[0]; p=body+2
            for _ in range(cnt):
                cid=struct.unpack_from("<H",d,p)[0]; p+=2
                nm,p=strz(d,p); items.append(("sym",cid,nm))
        o=o2

nom=sys.argv[1]
d=charger(nom)
sprites={}; top=[]
b=Bits(d,8); rect(b)
walk(d,b.p+4,len(d),sprites,top)
names={t[1]:t[2] for t in top if t[0]=="sym"}
def cls(cid,klass):
    if klass: return klass
    return names.get(cid, f"char{cid}") if cid is not None else "-"

motif=(sys.argv[2].lower() if len(sys.argv)>2 else None)
def montre(sid, prof=0, vus=None):
    if vus is None: vus=set()
    if sid in vus or prof>3: return
    vus=vus|{sid}
    ind="   "*(prof+1)
    for it in sprites.get(sid,[]):
        if it[0]=="place":
            _,dp,cid,klass,nm,tx,ty,sx,sy = it
            ech = "" if (abs(sx-1)<0.01 and abs(sy-1)<0.01) else f" x{sx:.2f}"
            etiq = nm if nm else "·"
            print(f"{ind}{etiq:<32} @({tx:>5.0f},{ty:>5.0f}){ech}  <{cls(cid,klass)}>")
            if cid in sprites: montre(cid, prof+1, vus)
        elif it[0]=="text":
            _,eid,r,var,txt,col = it
            c = f" #{col[0]:02x}{col[1]:02x}{col[2]:02x}" if col else ""
            print(f"{ind}[texte] @({r[0]:.0f},{r[1]:.0f}) {r[2]-r[0]:.0f}x{r[3]-r[1]:.0f}{c} var={var!r} {txt!r}")

print(f"=== {nom} : arbre d'agencement ===")
for cid in sorted(names):
    if motif and motif not in names[cid].lower(): continue
    if cid not in sprites: continue
    print(f"\n### {names[cid]} (sprite {cid}) ###")
    montre(cid)
