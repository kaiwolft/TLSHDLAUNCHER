import struct,sys
def u32(b,o): return struct.unpack_from('>I',b,o)[0]
def u16(b,o): return struct.unpack_from('>H',b,o)[0]
def parse(path):
    b=open(path,'rb').read()
    assert b[:4]==b'RSAR'
    symb,symbsz,info,infosz,fil,filsz=struct.unpack_from('>6I',b,0x10)
    base=info+8
    ref=lambda o:(b[o],b[o+1],u32(b,o+4))
    refs=[ref(base+i*8) for i in range(6)]
    ft=base+refs[3][2]; n=u32(b,ft)
    files=[]
    for i in range(n):
        rt,dt,v=ref(ft+4+i*8); fo=base+v
        size,wsize,entry=struct.unpack_from('>IIi',b,fo)
        prt,pdt,pv=ref(fo+12)
        name=None
        if pv:
            so=base+pv; e=b.index(b'\0',so); name=b[so:e].decode('ascii','replace')
        files.append(dict(i=i,off=fo,size=size,wsize=wsize,entry=entry,name=name))
    return b,files,dict(symb=symb,info=info,infosz=infosz,file=fil,filesz=filsz,refs=refs)
if __name__=='__main__':
    b,f,h=parse(sys.argv[1]); print(h,len(f))
    ext=[x for x in f if x['name']]; print('external',len(ext))
    for x in f[:3]+ext[:5]: print(x)
