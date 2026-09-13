# Parseur SWF minimal orienté UI : hiérarchie de sprites, instances nommées +
# position, champs texte, noms de symboles. Pas d'extraction d'images (droits).
import sys, struct, zlib, re
sys.path.insert(0, r"D:\GOG Galaxy\Games\Port Royale 3\_mod\pr3")
import pr3fuk

class Bits:
    def __init__(self, data, pos=0):
        self.d=data; self.byte=pos; self.bit=0
    def align(self):
        if self.bit: self.byte+=1; self.bit=0
    def u(self, n):
        v=0
        for _ in range(n):
            v=(v<<1)|((self.d[self.byte]>>(7-self.bit))&1)
            self.bit+=1
            if self.bit==8: self.bit=0; self.byte+=1
        return v
    def s(self, n):
        v=self.u(n)
        if n and (v>>(n-1))&1: v-=(1<<n)
        return v

def rect(b):
    nb=b.u(5); xmin=b.s(nb); xmax=b.s(nb); ymin=b.s(nb); ymax=b.s(nb); b.align()
    return (xmin/20,ymin/20,xmax/20,ymax/20)

def matrix(b):
    tx=ty=0.0; sx=sy=1.0
    if b.u(1):
        n=b.u(5); sx=b.s(n)/65536.0; sy=b.s(n)/65536.0
    if b.u(1):
        n=b.u(5); b.s(n); b.s(n)
    n=b.u(5); tx=b.s(n)/20.0; ty=b.s(n)/20.0
    b.align()
    return tx,ty,sx,sy

def strz(d,o):
    e=d.index(b'\0',o); return d[o:e].decode('latin1'), e+1

def parse_tags(d, start, end, out, sprites, depth=0):
    o=start
    while o<end:
        rh=struct.unpack_from("<H",d,o)[0]; o+=2
        code=rh>>6; ln=rh&0x3f
        if ln==0x3f: ln=struct.unpack_from("<I",d,o)[0]; o+=4
        body=o; o2=o+ln
        if code==0: return o2
        if code==39:  # DefineSprite
            sid=struct.unpack_from("<H",d,body)[0]
            fc=struct.unpack_from("<H",d,body+2)[0]
            children=[]
            parse_tags(d, body+4, o2, children, sprites, depth+1)
            sprites[sid]={"frames":fc,"children":children}
        elif code in (26,70):  # PlaceObject2/3
            pl=_placeobj(d,body,o2,code)
            if pl: out.append(pl)
        elif code==37:  # DefineEditText
            out.append(_edittext(d,body))
        elif code==43:  # FrameLabel
            s,_=strz(d,body); out.append(("framelabel",s))
        elif code==76:  # SymbolClass
            cnt=struct.unpack_from("<H",d,body)[0]; p=body+2
            for _ in range(cnt):
                cid=struct.unpack_from("<H",d,p)[0]; p+=2
                nm,p=strz(d,p); out.append(("symbolclass",cid,nm))
        elif code==56:  # ExportAssets
            cnt=struct.unpack_from("<H",d,body)[0]; p=body+2
            for _ in range(cnt):
                cid=struct.unpack_from("<H",d,p)[0]; p+=2
                nm,p=strz(d,p); out.append(("export",cid,nm))
        o=o2
    return o

def _placeobj(d,body,end,code):
    b=Bits(d,body)
    f=b.u(8)
    hasClip=f&0x80; hasName=f&0x20; hasRatio=f&0x10; hasCx=f&0x08; hasMat=f&0x04; hasCh=f&0x02; move=f&0x01
    if code==70:
        b.u(8)  # flags2 (PlaceObject3)
    depth=struct.unpack_from("<H",d,b.byte)[0]; b.byte+=2
    cid=None
    if hasCh:
        cid=struct.unpack_from("<H",d,b.byte)[0]; b.byte+=2
    tx=ty=0.0; sx=sy=1.0
    if hasMat:
        tx,ty,sx,sy=matrix(b)
    name=None
    # sauter CXFORM si présent (approx : on relit le nom via scan si besoin)
    # Pour rester robuste, on ne lit le nom que s'il n'y a pas de CXFORM.
    if hasName and not hasCx:
        name,_=strz(d,b.byte)
    return ("place",depth,cid,name,round(tx,1),round(ty,1),round(sx,3),round(sy,3))

def _edittext(d,body):
    eid=struct.unpack_from("<H",d,body)[0]
    b=Bits(d,body+2); r=rect(b); o=b.byte
    flags=struct.unpack_from("<H",d,o)[0]; o+=2
    hasText=flags&0x80; hasFont=flags&0x01; hasColor=flags&0x04; hasMaxLen=flags&0x02; hasLayout=flags&0x20
    if hasFont: o+=4
    if hasColor: o+=4
    if hasMaxLen: o+=2
    if hasLayout: o+=9
    var,o=strz(d,o)
    txt=""
    if hasText: txt,o=strz(d,o)
    return ("edittext",eid,round(r[0]),round(r[1]),round(r[2]-r[0]),round(r[3]-r[1]),var,txt[:40])

def charger(nom):
    ar=pr3fuk.load(r"D:\GOG Galaxy\Games\Port Royale 3\data0.fuk")
    e=pr3fuk.find(ar,nom)
    if not e:
        ar=pr3fuk.load(r"D:\GOG Galaxy\Games\Port Royale 3\data.fuk")
        e=pr3fuk.find(ar,nom)
    d=pr3fuk.content(ar,e)
    if d[:3]==b'CWS': d=b'FWS'+d[3:8]+zlib.decompress(d[8:])
    return d

def main():
    nom=sys.argv[1]
    d=charger(nom)
    b=Bits(d,8); stage=rect(b)
    print(f"# {nom}  scène {round(stage[2])}x{round(stage[3])} px")
    top=[]; sprites={}
    parse_tags(d, b.byte+4, len(d), top, sprites)  # +4 : frameRate(2)+frameCount(2)
    # symboles nommés
    names={cid:nm for t in top if t[0]=="symbolclass" for cid,nm in [(t[1],t[2])]}
    for t in top:
        if t[0]=="symbolclass": print(f"  classe {t[1]}: {t[2]}")
    print(f"  {len(sprites)} sprites, {sum(1 for t in top if t[0]=='place')} placements racine")
    # champs texte (labels/valeurs)
    places=[t for sp in sprites.values() for t in sp["children"] if t[0]=="place" and t[3]]
    print(f"  {len(places)} placements nommes :")
    for t in places[:45]:
        cls=names.get(t[2],f"char{t[2]}") if t[2] is not None else "-"
        print(f"    {t[3]:32s} @({t[4]:.0f},{t[5]:.0f}) x{t[6]:g} <{cls}>")
    et=[t for sp in sprites.values() for t in sp["children"] if t[0]=="edittext"]
    et+=[t for t in top if t[0]=="edittext"]
    print(f"  {len(et)} champs texte :")
    for t in et[:20]:
        print(f"    edit @({t[2]},{t[3]}) {t[4]}x{t[5]} var={t[6]!r} txt={t[7]!r}")

if __name__=="__main__": main()
