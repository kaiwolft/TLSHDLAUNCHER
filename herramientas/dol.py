import struct
class Dol:
    def __init__(s,path):
        s.b=open(path,'rb').read(); b=s.b
        offs=struct.unpack_from('>18I',b,0); addrs=struct.unpack_from('>18I',b,0x48); sizes=struct.unpack_from('>18I',b,0x90)
        s.secs=[(i,o,a,z) for i,(o,a,z) in enumerate(zip(offs,addrs,sizes)) if z]
        s.bss=struct.unpack_from('>2I',b,0xD8); s.entry=struct.unpack_from('>I',b,0xE0)[0]
    def off(s,addr):
        for i,o,a,z in s.secs:
            if a<=addr<a+z: return o+addr-a
        return None
    def u32(s,addr):
        o=s.off(addr); return None if o is None else struct.unpack_from('>I',s.b,o)[0]
    def f32(s,addr):
        o=s.off(addr); return None if o is None else struct.unpack_from('>f',s.b,o)[0]
    def text(s):
        for i,o,a,z in s.secs:
            if i<7: yield o,a,z
