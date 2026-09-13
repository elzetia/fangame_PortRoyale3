import sys, struct, zlib
sys.path.insert(0, r"D:\GOG Galaxy\Games\Port Royale 3\_mod\pr3")
import pr3fuk
NOMS={0:"End",1:"ShowFrame",2:"DefineShape",9:"SetBackgroundColor",11:"DefineText",
20:"DefineBitsLossless",21:"DefineBitsJPEG2",22:"DefineShape2",26:"PlaceObject2",
32:"DefineShape3",33:"DefineText2",35:"DefineBitsJPEG3",36:"DefineBitsLossless2",
37:"DefineEditText",39:"DefineSprite",43:"FrameLabel",48:"DefineFont2",
56:"ExportAssets",57:"ImportAssets",62:"DefineFontInfo2",70:"PlaceObject3",
71:"ImportAssets2",73:"DefineFontAlignZones",75:"DefineFont3",76:"SymbolClass",
77:"Metadata",82:"DoABC",83:"DefineShape4",86:"DefineSceneAndFrameLabelData",
88:"DefineFontName",91:"DefineFont4"}
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
    def ub(s,k):
        v=0
        for _ in range(k):
            v=(v<<1)|((s.d[s.p]>>(7-s.b))&1); s.b+=1
            if s.b==8: s.b=0; s.p+=1
        return v
d=charger(sys.argv[1])
bb=B(d,8); k=bb.ub(5); [bb.ub(k) for _ in range(4)]
if bb.b: bb.p+=1
o=bb.p+4
from collections import Counter
c=Counter(); tot=Counter()
def scan(o,end,depth=0):
    while o<end-1:
        rh=struct.unpack_from("<H",d,o)[0]; o+=2
        code=rh>>6; ln=rh&0x3f
        if ln==0x3f: ln=struct.unpack_from("<I",d,o)[0]; o+=4
        if code==0: break
        c[code]+=1; tot[code]+=ln
        if code==39:
            scan(o+4,o+ln,depth+1)
        o+=ln
scan(o,len(d))
print(f"=== {sys.argv[1]} : tags (recursif dans les sprites) ===")
for code,n in c.most_common():
    print(f"  {code:>3} {NOMS.get(code,'?'):<28} x{n:<6} {tot[code]:>9} o")
