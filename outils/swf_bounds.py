# Bounds + styles de chars precis d'un SWF (formes ET sprites), par id.
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
class B:
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
def strz(d,o):
    e=d.index(b'\0',o); return d[o:e].decode('latin1'), e+1
d=charger(sys.argv[1])
b=B(d,8); rect(b); o=b.p+4
shapes={}; names={}
while o<len(d)-2:
    rh=struct.unpack_from("<H",d,o)[0]; o+=2
    code=rh>>6; ln=rh&0x3f
    if ln==0x3f: ln=struct.unpack_from("<I",d,o)[0]; o+=4
    if code==0: break
    body=o
    if code in (2,22,32,83):
        cid=struct.unpack_from("<H",d,body)[0]
        bb=B(d,body+2); r=rect(bb)
        shapes[cid]=(code,r,body,ln)
    elif code==76:
        cnt=struct.unpack_from("<H",d,body)[0]; p=body+2
        for _ in range(cnt):
            cid=struct.unpack_from("<H",d,p)[0]; p+=2
            nm,p=strz(d,p); names[cid]=nm
    o+=ln
def fills(code,body,ln):
    shape3 = code in (32,83)
    bb=B(d,body+2); rect(bb)
    if code==83: rect(bb); bb.p+=1
    bb.align()
    n=d[bb.p]; bb.p+=1
    if n==0xff: n=struct.unpack_from("<H",d,bb.p)[0]; bb.p+=2
    out=[]
    for _ in range(n):
        t=d[bb.p]; bb.p+=1
        if t==0:
            if shape3:
                out.append(("solid",tuple(d[bb.p:bb.p+4]))); bb.p+=4
            else:
                out.append(("solid",tuple(d[bb.p:bb.p+3]))); bb.p+=3
        elif t in (0x40,0x41,0x42,0x43):
            bid=struct.unpack_from("<H",d,bb.p)[0]; bb.p+=2
            out.append(("bitmap",bid)); break
        else:
            out.append(("autre",hex(t))); break
    return out
for a in sys.argv[2:]:
    cid=int(a)
    if cid in shapes:
        code,r,body,ln=shapes[cid]
        w=r[1]-r[0]; h=r[3]-r[2]
        print(f"char{cid} {names.get(cid,'')} : forme def{code} bounds {w:.1f}x{h:.1f} px (x{r[0]:.1f}..{r[1]:.1f}, y{r[2]:.1f}..{r[3]:.1f})")
        try:
            for f in fills(code,body,ln): print("    fill",f)
        except Exception as e: print("    (fill?)",e)
    else:
        print(f"char{cid} : pas une forme")
