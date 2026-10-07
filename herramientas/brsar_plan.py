import sys,re,json
sys.path.insert(0,'/home/claude/work'); from brsar import parse
P="/mnt/user-data/uploads/The last Story Proyect/TLS Juego beta/"
def load(f):
    d={}
    for l in open(P+'logs/'+f,encoding='utf-8-sig'):
        p=l.rstrip('\r\n').split('\t')
        if len(p)==3: d[p[0].replace('\\','/')]=(int(p[1]),p[2])
    return d
U=load('lista_US.tsv'); J=load('lista_JP.tsv')
bu,fu,_=parse(P+'para_claude/US_lastworld.brsar'); bj,fj,_=parse(P+'para_claude/JP_lastworld.brsar')
def chk(files,D,tag):
    bad=0;miss=0
    for x in files:
        if not x['name']: continue
        k='DATA/files/sound/'+x['name']
        if k not in D: miss+=1; continue
        if D[k][0]!=x['size']: bad+=1
    print(tag,'size mismatch',bad,'missing',miss)
chk(fu,U,'US'); chk(fj,J,'JP')
swap=re.compile(r'^(VO_.*|SE_VO.*|ev\d.*)\.brstm$')
patch=[]; names_us={x['name'] for x in fu if x['name']}
for x in fu:
    n=x['name']
    if not n: continue
    base=n.split('/')[-1]; k='DATA/files/sound/'+n
    if swap.match(base) and k in J and J[k][0]!=x['size']:
        patch.append((x['off'],x['size'],J[k][0],n))
print('entries to patch',len(patch))
# internal (non-external) files count & sizes compare
iu=[x for x in fu if not x['name']]; ij=[x for x in fj if not x['name']]
print('internal US',len(iu),'JP',len(ij))
json.dump(patch,open('patch.json','w'))
