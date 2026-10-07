import sys,subprocess,struct
from dol import Dol
d=Dol('US_main.dol')
def dis(start,n=40):
    o=d.off(start); bs=d.b[o:o+4*n]
    txt=' '.join('0x%02x'%x for x in bs)
    r=subprocess.run(['llvm-mc','--disassemble','-triple=powerpc-unknown-unknown','-mcpu=750'],input=txt,capture_output=True,text=True)
    lines=[l.strip() for l in r.stdout.splitlines() if l.strip() and not l.strip().startswith('.text')]
    out=[]
    for i,l in enumerate(lines):
        a=start+4*i; w=struct.unpack_from('>I',bs,4*i)[0]
        # resolve branch targets
        if l.startswith('bl') or l.startswith('b\t') or l.startswith('b '):
            if (w>>26)==18:
                li=w&0x03FFFFFC
                if li&0x02000000: li-=0x04000000
                tgt=(li if w&2 else a+li)&0xFFFFFFFF; l+='   -> %08x'%tgt
        out.append('%08x: %08x  %s'%(a,w,l))
    return '\n'.join(out)
if __name__=='__main__':
    print(dis(int(sys.argv[1],16),int(sys.argv[2]) if len(sys.argv)>2 else 40))
