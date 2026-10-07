import struct
from dol import Dol
d=Dol('US_main.dol'); b=d.b
def words():
    for o,a,z in d.text():
        for k in range(0,z,4): yield a+k, struct.unpack_from('>I',b,o+k)[0]
W=dict(words())
def find_seq(seq):
    res=[]
    for a in W:
        if all(W.get(a+4*i)==v for i,v in enumerate(seq)): res.append(a)
    return res
def bl_target(a):
    w=W[a]
    if (w>>26)!=18 or not (w&1): return None
    li=w&0x03FFFFFC
    if li&0x02000000: li-=0x04000000
    return (a+li)&0xffffffff
def callers(f): return [a for a,w in W.items() if (w>>26)==18 and (w&1) and bl_target(a)==f]
