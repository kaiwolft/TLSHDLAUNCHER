import struct,sys
from dol import Dol
from sig import W
d=Dol('US_main.dol'); b=d.b
def o2a(o):
    for i,oo,a,z in d.secs:
        if oo<=o<oo+z: return a+o-oo
def refs(tgt):
    out=[]
    for i in range(0,len(b)-3,4):
        if struct.unpack_from('>I',b,i)[0]==tgt: out.append(('ptr',o2a(i)))
    hi_a=(tgt+0x8000)>>16; lo=tgt&0xffff; hi_l=tgt>>16
    for a,w in W.items():
        if (w>>26)==15 and (w&0xffff) in (hi_a,hi_l) and ((w>>16)&31)==0:
            rD=(w>>21)&31
            for j in range(1,20):
                w2=W.get(a+4*j,0)
                if (w2>>26) in (14,24,32,48,36) and ((w2>>16)&31)==rD and (w2&0xffff)==lo: out.append(('code',a,a+4*j)); break
    return out
if __name__=='__main__':
    for t in sys.argv[1:]: print(t,[(k,*map(hex,v)) for k,*v in refs(int(t,16))])
