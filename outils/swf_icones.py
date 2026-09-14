# Table classe -> bitmap, resolue RECURSIVEMENT a travers sprites ET
# remplissages bitmap de formes (FillStyle 0x40..0x43), parses proprement.
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
    nb=b.u(5); a=[b.sg(nb) for _ in range(4)]; b.align(); return a
def strz(d,o):
    e=d.index(b'\0',o); return d[o:e].decode('latin1'), e+1
d=charger(sys.argv[1])
b=B(d,8); rect(b); o=b.p+4
names={}; bmp={}; sprites={}; shapes={}
while o<len(d)-2:
    rh=struct.unpack_from("<H",d,o)[0]; o+=2
    code=rh>>6; ln=rh&0x3f
    if ln==0x3f: ln=struct.unpack_from("<I",d,o)[0]; o+=4
    if code==0: break
    body=o
    if code==76:
        cnt=struct.unpack_from("<H",d,body)[0]; p=body+2
        for _ in range(cnt):
            cid=struct.unpack_from("<H",d,p)[0]; p+=2
            nm,p=strz(d,p); names[cid]=nm
    elif code in (20,36):
        cid=struct.unpack_from("<H",d,body)[0]
        bmp[cid]=(struct.unpack_from("<H",d,body+3)[0], struct.unpack_from("<H",d,body+5)[0])
    elif code in (21,35):
        cid=struct.unpack_from("<H",d,body)[0]; bmp[cid]=(0,0)
    elif code==39:
        sid=struct.unpack_from("<H",d,body)[0]
        p=body+4; kids=[]
        while p<body+ln-1:
            srh=struct.unpack_from("<H",d,p)[0]; hp=p; p+=2
            sc=srh>>6; sl=srh&0x3f
            # Forme LONGUE : il faut retenir le fait AVANT d'ecraser `sl`, sinon
            # l'avancement compte un en-tete de 2 octets la ou il en fait 6.
            longue = (sl==0x3f)
            if longue: sl=struct.unpack_from("<I",d,p)[0]; p+=4
            if sc==0: break
            if sc==26:
                f=d[p]
                if f&2: kids.append(struct.unpack_from("<H",d,p+3)[0])
            elif sc==70:
                f1=d[p]; f2=d[p+1]; q=p+4
                # Nom de classe seulement si HasClassName : Scaleform n'en met
                # pas pour HasImage, et le lire fabrique de faux charId.
                if f2&0x08: _,q=strz(d,q)
                if f1&0x02: kids.append(struct.unpack_from("<H",d,q)[0])
            p=hp+(6 if longue else 2)+sl
        sprites[sid]=kids
    elif code in (2,22,32,83):
        shapes[struct.unpack_from("<H",d,body)[0]]=(code,body,ln)
    o+=ln
def shape_bmps(cid):
    code,body,ln=shapes[cid]
    shape3 = code in (32,83)
    bb=B(d,body+2); rect(bb)
    if code==83: rect(bb); bb.p+=1
    bb.align()
    n=d[bb.p]; bb.p+=1
    if n==0xff: n=struct.unpack_from("<H",d,bb.p)[0]; bb.p+=2
    out=[]
    for _ in range(n):
        if bb.p>=body+ln: break
        t=d[bb.p]; bb.p+=1
        if t==0: bb.p += 4 if shape3 else 3
        elif t in (0x10,0x12,0x13):
            if bb.u(1): k=bb.u(5); bb.u(k); bb.u(k)
            if bb.u(1): k=bb.u(5); bb.u(k); bb.u(k)
            k=bb.u(5); bb.u(k); bb.u(k); bb.align()
            bb.u(4); num=bb.u(4)
            for _ in range(num): bb.p+=1+(4 if shape3 else 3)
        elif t in (0x40,0x41,0x42,0x43):
            bid=struct.unpack_from("<H",d,bb.p)[0]; bb.p+=2
            if bid in bmp: out.append(bid)
            if bb.u(1): k=bb.u(5); bb.u(k); bb.u(k)
            if bb.u(1): k=bb.u(5); bb.u(k); bb.u(k)
            k=bb.u(5); bb.u(k); bb.u(k); bb.align()
        else: break
    return out
def leaves(cid,seen=None,prof=0):
    if seen is None: seen=set()
    if cid in seen or prof>8: return []
    seen.add(cid)
    if cid in bmp: return [cid]
    r=[]
    if cid in shapes:
        try: r+=shape_bmps(cid)
        except Exception: pass
    for k in sprites.get(cid,[]):
        for x in leaves(k,seen,prof+1):
            if x not in r: r.append(x)
    return r
motif=sys.argv[2].lower() if len(sys.argv)>2 else ""
lignes=[]
for cid in sorted(names, key=lambda i:names[i].lower()):
    if motif and motif not in names[cid].lower(): continue
    lv=[b for b in leaves(cid) if bmp[b][0]]
    if not lv: continue
    # La PLUS PETITE feuille, pas la plus grande : un symbole d'interface place
    # son glyphe sur un support (cadre de bouton, bandeau de liste) toujours plus
    # grand que lui. « La plus grande » ramenait donc le decor. Verifie a l'oeil :
    # Cycle -> 1872 (deux fleches) et non 436 (une plaque) ; Bships -> 1186 (un
    # navire) et non 1480 (un bandeau). Mesure : 622 entrees justes sur 677
    # contre 599 pour l'ancienne regle. C'est une approximation, pas une loi.
    best=min(lv, key=lambda b: bmp[b][0]*bmp[b][1])
    # Le nom ENTIER quand c'est un nom de fichier : `split('.')[-1]` reduisait
    # « Flag_England.png » a « png » et faisait s'effondrer 414 symboles sur une
    # seule cle. Sinon, le dernier segment pointe : components.button.Visual_X.
    nm=names[cid]
    court = nm if nm.lower().endswith(".png") else nm.split('.')[-1]
    # TABULATEURS : c'est ainsi que `EcranPR3.icones()` decoupe le fichier.
    lignes.append(f"{court}\t{best}.png\t{bmp[best][0]}x{bmp[best][1]}")
dest=r"D:\GOG Galaxy\Games\PortRoyale3D\reference_pr3\ui\agencement\icones.txt"
os.makedirs(os.path.dirname(dest),exist_ok=True)
open(dest,"w",encoding="utf-8").write("\n".join(lignes)+"\n")
print(f"{len(lignes)} entrees -> icones.txt")
