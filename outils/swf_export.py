# Exporte l'agencement COMPLET d'un SWF PR3 en JSON exploitable par Godot.
# Pour chaque sprite exporte : ses enfants (nom d'instance, classe, x, y, echelle)
# et ses champs texte. Plus l'inventaire des champs vu dans l'ActionScript.
import sys, struct, zlib, json, os, re
sys.path.insert(0, r"D:\GOG Galaxy\Games\Port Royale 3\_mod\pr3")
import pr3fuk

SORTIE = r"D:\GOG Galaxy\Games\PortRoyale3D\reference_pr3\ui\agencement"

def charger(nom):
    for a in ("data0.fuk","data.fuk"):
        ar=pr3fuk.load(r"D:\GOG Galaxy\Games\Port Royale 3\\"+a)
        e=pr3fuk.find(ar,nom)
        if e:
            d=pr3fuk.content(ar,e)
            if d[:3]==b'CWS': d=b'FWS'+d[3:8]+zlib.decompress(d[8:])
            return d
    return None

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
    # Le nom de classe n'est la QUE si HasClassName (0x08). La spec SWF ajoute
    # « ou HasImage(0x10) et HasCharacter(0x02) », mais Scaleform/Iggy n'emet
    # alors AUCUNE chaine : la lire consomme des octets de bourrage, decale tout
    # ce qui suit et fabrique de faux charId. C'est ce qui rendait « char 64 »
    # pour 269 symboles de skinlib_pr3 ; sans cette clause, la table classe ->
    # image passe de 412 a 599 entrees justes sur 681.
    if code==70 and (f2 & 0x08):
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
    return {"d":depth,"cid":cid,"classe":klass,"nom":name,
            "x":round(tx,1),"y":round(ty,1),"sx":round(sx,3),"sy":round(sy,3)}

def edittext(d,body):
    eid=struct.unpack_from("<H",d,body)[0]
    b=Bits(d,body+2); r=rect(b)
    hasText=b.u(1); b.u(1); b.u(1); b.u(1); b.u(1)
    hasColor=b.u(1); hasMaxLen=b.u(1); hasFont=b.u(1); hasFontClass=b.u(1); b.u(1)
    hasLayout=b.u(1); b.u(1); b.u(1); b.u(1); b.u(1); b.u(1)
    b.align(); p=b.p
    # L'ORDRE REEL, lu dans les octets et non dans la spec : la CLASSE de police
    # vient d'abord, la HAUTEUR ensuite -- et cette hauteur est ecrite meme
    # quand HasFont vaut 0, ce qui est le cas partout chez Scaleform (il nomme
    # sa police par une classe, `$RegularFont1`, sans embarquer de FontID).
    # L'ancienne version lisait la hauteur sous `if hasFont` : elle ne la lisait
    # donc JAMAIS, puis prenait ces octets pour la couleur et decalait tout le
    # reste. Les `police` et `couleur` de tous les agencements etaient faux, et
    # `var` sortait a « ( ».
    #
    # Controle gratuit : `Visual_Textfeld_NN` doit rendre NN*20 twips. 17 des 19
    # tombent juste ; les deux autres (18_Shadow -> 340, 24 -> 440) reutilisent
    # l'enregistrement d'un voisin, ce qui est un fait du fichier, pas un bug.
    classe_police=None
    if hasFontClass: classe_police,p=strz(d,p)
    if hasFont: p+=2                       # FontID
    taille=None
    if hasFont or hasFontClass:
        taille=struct.unpack_from("<H",d,p)[0]/20.0; p+=2
    col=None
    if hasColor:
        col="#%02x%02x%02x"%(d[p],d[p+1],d[p+2])
        alpha=d[p+3]; p+=4
    else:
        alpha=255
    if hasMaxLen: p+=2
    # L'ALIGNEMENT : 0 gauche, 1 droite, 2 centre, 3 justifie. Il etait saute
    # d'un `p+=9` avec le reste du bloc de mise en page. PR3 declare « gauche »
    # pour 19 de ses 22 champs, le centre etant reserve aux Subheadline -- alors
    # que le rendu les centrait TOUS.
    align=None
    if hasLayout:
        align=d[p]; p+=9
    var,p=strz(d,p)
    txt=""
    if hasText: txt,p=strz(d,p)
    return {"type":"texte","cid":eid,"x":round(r[0]),"y":round(r[2]),
            "w":round(r[1]-r[0]),"h":round(r[3]-r[2]),
            "police":taille,"couleur":col,"alpha":alpha,"align":align,
            "fonte":classe_police,"var":var,"texte":txt[:80]}

def walk(d,start,end,sprites,items):
    o=start
    # L'IMAGE courante du sprite : ShowFrame (balise 1) la fait avancer. Sans ce
    # compte, toutes les images s'aplatissent en une seule et les ETATS
    # ALTERNATIFS se dessinent les uns sur les autres -- un bouton montre a la
    # fois son etat normal, survole, presse et desactive. C'est ce qui posait
    # `char147`, la planche de l'image 4 de Hud_Scroll_Top_50, par-dessus le
    # bandeau de ville de l'image 0, qu'elle recouvrait a 91 %.
    img=0
    while o<end-1:
        rh=struct.unpack_from("<H",d,o)[0]; o+=2
        code=rh>>6; ln=rh&0x3f
        if ln==0x3f: ln=struct.unpack_from("<I",d,o)[0]; o+=4
        body=o; o2=o+ln
        if code==0: return
        if code==1:
            img+=1
        elif code==39:
            sid=struct.unpack_from("<H",d,body)[0]
            kids=[]
            walk(d,body+4,o2,sprites,kids)
            sprites[sid]=kids
        elif code in (26,70):
            try:
                it=place(d,body,code); it["img"]=img; items.append(it)
            except Exception: pass
        elif code==37:
            try: items.append(edittext(d,body))
            except Exception: pass
        elif code==76:
            cnt=struct.unpack_from("<H",d,body)[0]; p=body+2
            for _ in range(cnt):
                cid=struct.unpack_from("<H",d,p)[0]; p+=2
                nm,p=strz(d,p); items.append({"type":"sym","cid":cid,"nom":nm})
        o=o2

def u30(d,p):
    v=0; sh=0
    for _ in range(5):
        b=d[p]; p+=1
        v |= (b & 0x7f) << sh
        if not (b & 0x80): break
        sh += 7
    return v,p

def abc_champs(d,tags):
    for code,body,ln in tags:
        if code!=82: continue
        p=body+4
        while d[p]: p+=1
        p+=1
        abc=d[p:body+ln]
        try:
            q=4
            n,q=u30(abc,q)
            for _ in range(max(0,n-1)): _,q=u30(abc,q)
            n,q=u30(abc,q)
            for _ in range(max(0,n-1)): _,q=u30(abc,q)
            n,q=u30(abc,q); q+=8*max(0,n-1)
            n,q=u30(abc,q)
            out=[]
            for _ in range(max(0,n-1)):
                L,q=u30(abc,q)
                out.append(abc[q:q+L].decode('utf-8','replace')); q+=L
            return sorted({s for s in out if re.match(r'^(tf_|li_|mc_|bu_|btn_|icn_|icon_|cr_|tab_|bar_|bg_|good_|grp_)',s)})
        except Exception:
            return []
    return []

def tags_of(d):
    b=Bits(d,8); rect(b); o=b.p+4
    out=[]
    while o<len(d)-2:
        rh=struct.unpack_from("<H",d,o)[0]; o+=2
        code=rh>>6; ln=rh&0x3f
        if ln==0x3f: ln=struct.unpack_from("<I",d,o)[0]; o+=4
        if code==0: break
        out.append((code,o,ln)); o+=ln
    return out

os.makedirs(SORTIE, exist_ok=True)
resume=[]
for nom in sys.argv[1:]:
    court=nom.split('/')[-1]
    d=charger(court)
    if d is None:
        continue
    try:
        sprites={}; top=[]
        b=Bits(d,8); stage=rect(b)
        walk(d,b.p+4,len(d),sprites,top)
        names={t["cid"]:t["nom"] for t in top if isinstance(t,dict) and t.get("type")=="sym"}
        def cls(it):
            if it.get("classe"): return it["classe"]
            c=it.get("cid")
            return names.get(c, f"char{c}") if c is not None else None
        ecrans={}
        for cid,nm in names.items():
            if cid not in sprites: continue
            enfants=[]
            for it in sprites[cid]:
                if it.get("type")=="texte":
                    enfants.append(it)
                elif "d" in it:
                    e={"nom":it["nom"],"classe":cls(it),"x":it["x"],"y":it["y"]}
                    if abs(it["sx"]-1)>0.005 or abs(it["sy"]-1)>0.005:
                        e["sx"]=it["sx"]; e["sy"]=it["sy"]
                    e["cid"]=it["cid"]
                    # La PROFONDEUR ordonne l'empilement, l'IMAGE dit l'etat.
                    # On garde les deux sans rien jeter : les images > 0 sont
                    # les etats alternatifs (survole, presse, desactive), que le
                    # rendu ne doit pas empiler sur l'etat par defaut -- mais
                    # qui serviront le jour ou les boutons reagiront.
                    e["prof"]=it["d"]
                    if it.get("img",0): e["img"]=it["img"]
                    enfants.append(e)
            if enfants: ecrans[nm]=enfants
        doc={"swf":court,"scene":[round(stage[1]),round(stage[3])],
             "classes":{str(k):v for k,v in names.items()},
             "ecrans":ecrans,"champs_abc":abc_champs(d,tags_of(d))}
        with open(os.path.join(SORTIE,court.replace('.swf','')+'.json'),'w',encoding='utf-8') as f:
            json.dump(doc,f,ensure_ascii=False,indent=1)
        resume.append((court,len(ecrans),sum(len(v) for v in ecrans.values()),len(doc["champs_abc"])))
    except Exception as ex:
        resume.append((court,-1,-1,0))
print(f"{'SWF':<42}{'ecrans':>8}{'elements':>10}{'champs':>8}")
for r in sorted(resume, key=lambda x:-x[2]):
    print(f"{r[0]:<42}{r[1]:>8}{r[2]:>10}{r[3]:>8}")
