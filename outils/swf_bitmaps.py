# Extrait les bitmaps d'un SWF (DefineBitsLossless2 + JPEG2/3) vers des PNG.
# Ecrit dans reference_pr3/ui/<swf>/ (gitignore). Art de PR3 : local, jamais commite.
import sys, struct, zlib, os
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

def png(w,h,rgba):
    def chunk(t,data):
        c=t+data
        return struct.pack(">I",len(data))+c+struct.pack(">I",zlib.crc32(c)&0xffffffff)
    raw=bytearray()
    for y in range(h):
        raw.append(0)
        raw+=rgba[y*w*4:(y+1)*w*4]
    return (b"\x89PNG\r\n\x1a\n"
        +chunk(b"IHDR",struct.pack(">IIBBBBB",w,h,8,6,0,0,0))
        +chunk(b"IDAT",zlib.compress(bytes(raw),9))
        +chunk(b"IEND",b""))

def lossless2(d,body,ln):
    fmt=d[body+2]; w=struct.unpack_from("<H",d,body+3)[0]; h=struct.unpack_from("<H",d,body+5)[0]
    o=body+7
    if fmt==3:
        n=d[o]+1; o+=1
        raw=zlib.decompress(d[o:body+ln])
        pal=[(raw[i*4],raw[i*4+1],raw[i*4+2],raw[i*4+3]) for i in range(n)]
        idx=raw[n*4:]
        stride=(w+3)&~3
        out=bytearray()
        for y in range(h):
            for x in range(w):
                p=pal[idx[y*stride+x]]; out+=bytes(p)
        return w,h,out
    else:  # fmt 5 : 32 bits (A,R,G,B) premultiplie
        raw=zlib.decompress(d[o:body+ln])
        out=bytearray(w*h*4)
        for i in range(w*h):
            a=raw[i*4]; r=raw[i*4+1]; g=raw[i*4+2]; b=raw[i*4+3]
            if a and a<255:
                r=min(255,r*255//a); g=min(255,g*255//a); b=min(255,b*255//a)
            out[i*4]=r; out[i*4+1]=g; out[i*4+2]=b; out[i*4+3]=a
        return w,h,out

def main():
    nom=sys.argv[1]
    d=charger(nom)
    base=nom.replace(".swf","")
    outdir=os.path.join(r"D:\GOG Galaxy\Games\PortRoyale3D\reference_pr3\ui", base)
    os.makedirs(outdir, exist_ok=True)
    o=8
    # header : sauter RECT (nbits*4) + 4
    nb=d[8]>>3; total=5+((nb*4+5+7)//8); o=8+ (( (d[8]>>3)*4 +5 +7)//8 ); o+=4
    n_png=n_jpg=0
    # relire proprement l'offset des tags : on reparcourt via RECT bit-exact
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
    while o<len(d)-2:
        rh=struct.unpack_from("<H",d,o)[0]; o+=2
        code=rh>>6; ln=rh&0x3f
        if ln==0x3f: ln=struct.unpack_from("<I",d,o)[0]; o+=4
        body=o; o2=o+ln
        if code==0: break
        if code in (20,36):  # DefineBitsLossless / 2
            try:
                cid=struct.unpack_from("<H",d,body)[0]
                w,h,rgba=lossless2(d,body,ln)
                if 0<w<=2048 and 0<h<=2048:
                    open(os.path.join(outdir,f"{cid}.png"),"wb").write(png(w,h,rgba))
                    n_png+=1
            except Exception as ex: pass
        elif code in (21,35):  # DefineBitsJPEG2/3 -> dump jpeg
            try:
                cid=struct.unpack_from("<H",d,body)[0]
                p=body+2
                if code==35: 
                    alen=struct.unpack_from("<I",d,p)[0]; p+=4
                jpg=d[p:body+ln] if code==21 else d[p:p+alen]
                if jpg[:2]==b'\xff\xd8':
                    open(os.path.join(outdir,f"{cid}.jpg"),"wb").write(jpg); n_jpg+=1
            except Exception: pass
        o=o2
    print(f"{nom}: {n_png} PNG + {n_jpg} JPG -> reference_pr3/ui/{base}/")

main()
