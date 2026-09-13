# Resout ImportAssets2 (tag 71) : quel SWF fournit quels symboles.
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
    def u(s,k):
        v=0
        for _ in range(k):
            v=(v<<1)|((s.d[s.p]>>(7-s.b))&1); s.b+=1
            if s.b==8: s.b=0; s.p+=1
        return v
def strz(d,o):
    e=d.index(b'\0',o); return d[o:e].decode('latin1'), e+1
nom=sys.argv[1]; d=charger(nom)
bb=B(d,8); k=bb.u(5); [bb.u(k) for _ in range(4)]
if bb.b: bb.p+=1
o=bb.p+4
while o<len(d)-2:
    rh=struct.unpack_from("<H",d,o)[0]; o+=2
    code=rh>>6; ln=rh&0x3f
    if ln==0x3f: ln=struct.unpack_from("<I",d,o)[0]; o+=4
    if code==0: break
    if code in (57,71):
        url,p=strz(d,o)
        if code==71: p+=2
        cnt=struct.unpack_from("<H",d,p)[0]; p+=2
        print(f"{nom} importe de '{url}' : {cnt} symboles")
        for _ in range(cnt):
            cid=struct.unpack_from("<H",d,p)[0]; p+=2
            nm,p=strz(d,p)
            print(f"   {cid:>5}  {nm}")
    o+=ln
