import struct, re
from capstone import Cs, CS_ARCH_X86, CS_MODE_32
exe = open(r"D:\GOG Galaxy\Games\Port Royale 3\PortRoyale3.exe","rb").read()
SEC=[(0x401000,0x400,0x736000),(0xB38000,0x736600,0x86400),(0xBBF000,0x7bca00,0x44800)]
TV,TF,TT=SEC[0]; text=exe[TF:TF+TT]
md=Cs(CS_ARCH_X86,CS_MODE_32)
def rd(va,n):
    for v,f,t in SEC:
        if v<=va<v+t: return exe[f+va-v:f+va-v+n]
    return b""
def chaine(va):
    b=rd(va,96); m=re.match(rb"[\x20-\x7e]{1,80}\x00",b)
    return m.group()[:-1].decode() if m else None
def f32(va):
    b=rd(va,4)
    return struct.unpack("<f",b)[0] if len(b)==4 else None
READERS={0x89d6e0:"int",0x89d750:"flt",0x89d7c0:"i[]",0x89d8a0:"f[]",0x89e270:"str"}
rows=[]
for i in range(len(text)-5):
    if text[i]!=0xE8: continue
    t=TV+i+5+struct.unpack_from("<i",text,i+1)[0]
    if t not in READERS: continue
    a=TV+i-56
    strs=[]; imms=[]; fconst=None
    for ins in md.disasm(rd(a,72), a):
        if ins.address>=TV+i: break
        op=ins.op_str
        if ins.mnemonic=="push":
            m=re.match(r"0x([0-9a-f]+)$",op)
            if m:
                v=int(m.group(1),16); s=chaine(v)
                if s is not None: strs.append((ins.address,s))
                else: imms.append((ins.address,v))
            else:
                m2=re.match(r"(-?\d+)$",op)
                if m2: imms.append((ins.address,int(m2.group(1))))
                elif op in ("0","1"): imms.append((ins.address,int(op)))
        elif ins.mnemonic in ("fld","movss","fild") and "0x" in op:
            m=re.search(r"0x([0-9a-f]+)",op)
            if m:
                fv=f32(int(m.group(1),16))
                if fv is not None: fconst=fv
        elif ins.mnemonic=="fld1": fconst=1.0
        elif ins.mnemonic=="fldz": fconst=0.0
    if len(strs)<2: continue
    sec=strs[-1][1]; key=strs[-2][1]; typ=READERS[t]
    dft=""
    if typ=="int":
        # le defaut int est le push imm juste avant la cle
        cands=[v for (ad,v) in imms if ad<strs[-2][0]]
        if cands: dft=str(cands[-1])
    elif typ=="flt":
        if fconst is not None:
            dft=("%g"%fconst)
    rows.append((sec,key,typ,dft))
# dedup en gardant l'ordre
vus=set(); uniq=[]
for r in rows:
    k=(r[0],r[1])
    if k in vus: continue
    vus.add(k); uniq.append(r)
# groupé par section
from collections import defaultdict
g=defaultdict(list)
for sec,key,typ,dft in uniq: g[sec].append((key,typ,dft))
print(f"== {len(g)} sections, {len(uniq)} cles (avec defaut quand lisible)\n")
for sec in sorted(g):
    print(f"[{sec}]")
    for key,typ,dft in g[sec]:
        print(f"   {key} : {typ}" + (f" = {dft}" if dft!="" else ""))
