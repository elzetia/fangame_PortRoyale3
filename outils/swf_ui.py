# Parseur SWF oriente UI : hierarchie de sprites, instances nommees + position,
# champs texte, noms de symboles. Pas d'extraction d'images (droits).
import sys, struct, zlib
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

def cxform(b):
    hasAdd=b.u(1); hasMult=b.u(1); n=b.u(4)
    for _ in range(4 if hasMult else 0): b.s(n)
    for _ in range(4 if hasAdd else 0): b.s(n)
    b.align()

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
        if code==39:
            sid=struct.unpack_from("<H",d,body)[0]
            fc=struct.unpack_from("<H",d,body+2)[0]
            children=[]
            parse_tags(d, body+4, o2, children, sprites, depth+1)
            sprites[sid]={"frames":fc,"children":children}
        elif code in (26,70):
            try:
                pl=_placeobj(d,body,o2,code)
                if pl: out.append(pl)
            except Exception: pass
        elif code==37:
            try: out.append(_edittext(d,body))
            except Exception: pass
        elif code==43:
            s,_=strz(d,body); out.append(("framelabel",s))
        elif code==76:
            cnt=struct.unpack_from("<H",d,body)[0]; p=body+2
            for _ in range(cnt):
                cid=struct.unpack_from("<H",d,p)[0]; p+=2
                nm,p=strz(d,p); out.append(("symbolclass",cid,nm))
        elif code==56:
            cnt=struct.unpack_from("<H",d,body)[0]; p=body+2
            for _ in range(cnt):
                cid=struct.unpack_from("<H",d,p)[0]; p+=2
                nm,p=strz(d,p); out.append(("export",cid,nm))
        o=o2
    return o

def _placeobj(d,body,end,code):
    b=Bits(d,body)
    f=b.u(8)
    hasClipAct=f&0x80; hasClipDepth=f&0x40; hasName=f&0x20; hasRatio=f&0x10
    hasCx=f&0x08; hasMat=f&0x04; hasCh=f&0x02; move=f&0x01
    if code==70:
        b.u(8)
    depth=struct.unpack_from("<H",d,b.byte)[0]; b.byte+=2
    cid=None
    if hasCh:
        cid=struct.unpack_from("<H",d,b.byte)[0]; b.byte+=2
    tx=ty=0.0; sx=sy=1.0
    if hasMat:
        tx,ty,sx,sy=matrix(b)
    if hasCx:
        cxform(b)
    if hasRatio:
        b.byte+=2
    name=None
    if hasName:
        name,_=strz(d,b.byte)
    return ("place",depth,cid,name,round(tx,1),round(ty,1),round(sx,3),round(sy,3))

def _edittext(d,body):
    eid=struct.unpack_from("<H",d,body)[0]
    b=Bits(d,body+2); r=rect(b)
    hasText=b.u(1); wordWrap=b.u(1); multiline=b.u(1); password=b.u(1); readonly=b.u(1)
    hasColor=b.u(1); hasMaxLen=b.u(1); hasFont=b.u(1); hasFontClass=b.u(1); autosize=b.u(1)
    hasLayout=b.u(1); noSelect=b.u(1); border=b.u(1); wasStatic=b.u(1); html=b.u(1); useOut=b.u(1)
    b.align(); o=b.byte
    if hasFont: o+=4
    if hasFontClass:
        _,o=strz(d,o)
    if hasColor: o+=4
    if hasMaxLen: o+=2
    if hasLayout: o+=9
    var,o=strz(d,o)
    txt=""
    if hasText: txt,o=strz(d,o)
    return ("edittext",eid,round(r[0]),round(r[1]),round(r[2]-r[0]),round(r[3]-r[1]),var,txt[:48])

def charger(nom):
    for arch in ("data0.fuk","data.fuk"):
        ar=pr3fuk.load(r"D:\GOG Galaxy\Games\Port Royale 3\\"+arch)
        e=pr3fuk.find(ar,nom)
        if e:
            d=pr3fuk.content(ar,e)
            if d[:3]==b'CWS': d=b'FWS'+d[3:8]+zlib.decompress(d[8:])
            return d
    raise LookupError(nom)

def main():
    nom=sys.argv[1]
    d=charger(nom)
    b=Bits(d,8); stage=rect(b)
    print(f"# {nom}  scene {round(stage[2])}x{round(stage[3])} px")
    top=[]; sprites={}
    parse_tags(d, b.byte+4, len(d), top, sprites)
    names={t[1]:t[2] for t in top if t[0]=="symbolclass"}
    for t in top:
        if t[0]=="symbolclass": print(f"  classe {t[1]}: {t[2]}")
    places=[t for sp in sprites.values() for t in sp["children"] if t[0]=="place" and t[3]]
    et=[t for sp in sprites.values() for t in sp["children"] if t[0]=="edittext"]
    et+=[t for t in top if t[0]=="edittext"]
    print(f"  {len(sprites)} sprites, {len(places)} placements nommes, {len(et)} champs texte")
    print("  -- placements nommes (position en px) --")
    shown=0
    for t in places:
        if abs(t[4])>20000 or abs(t[5])>20000: continue
        cls=names.get(t[2], f"char{t[2]}") if t[2] is not None else "-"
        print(f"    {t[3]:34s} @({t[4]:.0f},{t[5]:.0f}) x{t[6]:g} <{cls}>")
        shown+=1
        if shown>=50: break
    print("  -- champs texte (bounds px, variable) --")
    for t in et[:30]:
        print(f"    edit @({t[2]},{t[3]}) {t[4]}x{t[5]} var={t[6]!r} txt={t[7]!r}")

if __name__=="__main__": main()
