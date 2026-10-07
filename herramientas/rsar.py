import struct
B=open("/mnt/user-data/uploads/The last Story Proyect/TLS Juego beta/para_claude/US_lastworld.brsar",'rb').read()
u32=lambda o:struct.unpack_from('>I',B,o)[0]; u16=lambda o:struct.unpack_from('>H',B,o)[0]
symb,symbsz,info,infosz,fil,filsz=struct.unpack_from('>6I',B,0x10)
base=info+8
def ref(o): return B[o],u32(o+4)
refs=[ref(base+i*8) for i in range(6)]
def table(r):
    t=base+r; n=u32(t); return [base+u32(t+4+i*8+4) for i in range(n)]
files=table(refs[3][1]); groups=table(refs[4][1])
def fileinfo(fid):
    fo=files[fid]; size,wsize,entry=struct.unpack_from('>IIi',B,fo)
    ptab=u32(fo+12+8+4)  # filePosTable ref value
    pos=[]
    if ptab:
        t=base+ptab; n=u32(t)
        for i in range(n):
            po=base+u32(t+4+i*8+4); pos.append(struct.unpack_from('>II',B,po))
    return size,wsize,pos
def group(gid):
    g=groups[gid]
    # GroupInfo: stringId(u32), entryNum(s32), extFilePathRef(8), offset, size, waveDataOffset, waveDataSize, itemTableRef(8)
    off,size,woff,wsize=struct.unpack_from('>IIII',B,g+16)
    it=base+u32(g+32+4); n=u32(it); items=[]
    for i in range(n):
        io=base+u32(it+4+i*8+4); items.append(struct.unpack_from('>IIIII',B,io))  # fileId, offset,size,woff,wsize
    return off,size,woff,wsize,items
def locate(fid):
    size,wsize,pos=fileinfo(fid)
    gid,idx=pos[0]; off,gsz,woff,wsz,items=group(gid)
    f,io,isz,iwo,iwsz=items[idx]; assert f==fid,(f,fid)
    return dict(data=(off+io,isz), wave=(woff+iwo,iwsz), size=size, wsize=wsize, group=gid)
if __name__=='__main__':
    print(hex(fil),len(files),len(groups))
    for fid in (12951,12952,12953): print(fid, locate(fid), B[locate(fid)['data'][0]:locate(fid)['data'][0]+4])

sounds=table(refs[0][1]); banks=table(refs[1][1])
def soundinfo(sid):
    s=sounds[sid]
    strid,fid,player=struct.unpack_from('>III',B,s)
    vol,prio,stype=B[s+20],B[s+21],B[s+22]
    det=base+u32(s+24+4)
    if stype==1:  # SEQ
        doff,bank,alloc=struct.unpack_from('>III',B,det); return dict(type='seq',file=fid,vol=vol,offset=doff,bank=bank)
    return dict(type=stype,file=fid,vol=vol)
def bankfile(bid): return u32(banks[bid]+4)

def rbnk(fid):
    L=locate(fid); o,n=L['data']; d=B[o:o+n]
    i=d.find(b'DATA'); db=i+8
    cnt=struct.unpack_from('>I',d,db)[0]
    return d,db,cnt
def inst_lookup(fid,prg,key,vel=100):
    d,db,cnt=rbnk(fid)
    def resolve(rt,dt,val,depth=0):
        p=db+val
        if dt==1:
            w,a,de,s,r,h,loc,noff,alt,okey,vol,pan,span=struct.unpack_from('>iBBBBBBBBBBBB',d,p)
            tune=struct.unpack_from('>f',d,p+16)[0]
            return dict(wave=w,attack=a,decay=de,sustain=s,release=r,okey=okey,vol=vol,pan=pan,tune=tune)
        if dt==2:  # range table (by key at depth0, by velocity at depth1)
            sz=d[p]; keys=d[p+1:p+1+sz]; refo=p+1+sz; refo=(refo+3)&~3
            k=key if depth==0 else vel
            for j,kk in enumerate(keys):
                if k<=kk:
                    rt2,dt2=d[refo+j*8],d[refo+j*8+1]; v2=struct.unpack_from('>I',d,refo+j*8+4)[0]
                    return resolve(rt2,dt2,v2,depth+1)
            return None
        if dt==3:
            mn,mx=d[p],d[p+1]; k=key if depth==0 else vel
            if not mn<=k<=mx: return None
            j=k-mn; rt2,dt2=d[p+4+j*8],d[p+4+j*8+1]; v2=struct.unpack_from('>I',d,p+4+j*8+4)[0]
            return resolve(rt2,dt2,v2,depth+1)
        return None
    rt,dt=d[db+4+prg*8],d[db+4+prg*8+1]; val=struct.unpack_from('>I',d,db+4+prg*8+4)[0]
    return resolve(rt,dt,val)

def rwar_waves(fid):
    L=locate(fid); o,n=L['wave']; w=B[o:o+n]; assert w[:4]==b'RWAR',w[:4]
    t=w.find(b'TABL'); cnt=struct.unpack_from('>I',w,t+8)[0]
    dpos=w.find(b'DATA')
    out=[]
    for i in range(cnt):
        _,_,off,size=struct.unpack_from('>BBHII',w,t+12+i*12)[0:4] if False else (0,0,*struct.unpack_from('>II',w,t+12+i*12+4))
        out.append(w[dpos+off:dpos+off+size])
    return out
def dsp_decode(data,coefs,nsamples,start):
    import array
    out=array.array('h'); h1=h2=0; p=start
    while len(out)<nsamples:
        ps=data[p]; pred=ps>>4; scale=1<<(ps&15); c1,c2=coefs[pred*2],coefs[pred*2+1]; p+=1
        for k in range(14):
            byte=data[p+k//2]; nib=(byte>>4) if k%2==0 else (byte&15)
            if nib>=8: nib-=16
            s=((nib*scale)<<11)+1024+c1*h1+c2*h2; s>>=11
            s=max(-32768,min(32767,s)); out.append(s); h2=h1; h1=s
            if len(out)>=nsamples: break
        p+=7
    return out
def decode_rwav(rw):
    assert rw[:4]==b'RWAV',rw[:4]
    info=rw.find(b'INFO'); ib=info+8
    fmt,loop,ch,srh=rw[ib],rw[ib+1],rw[ib+2],rw[ib+3]
    sr=(srh<<16)|struct.unpack_from('>H',rw,ib+4)[0]
    loopstart,nend,chtab=struct.unpack_from('>III',rw,ib+8)
    nsamp=(nend//16)*14+max(0,(nend%16)-2)
    dpos=rw.find(b'DATA')
    chans=[]
    for c in range(ch):
        co=ib+struct.unpack_from('>I',rw,ib+chtab+c*4)[0]
        doff,adoff=struct.unpack_from('>II',rw,co)
        coefs=struct.unpack_from('>16h',rw,ib+adoff)
        if fmt==2: chans.append(dsp_decode(rw,coefs,nsamp,dpos+8+doff))
        else: raise Exception('fmt %d'%fmt)
    return sr,chans
def save_wav(path,sr,chans,gain=1.0):
    import wave,array
    n=len(chans[0]); w=wave.open(path,'wb'); w.setnchannels(len(chans)); w.setsampwidth(2); w.setframerate(sr)
    a=array.array('h')
    for i in range(n):
        for c in chans: a.append(max(-32768,min(32767,int(c[i]*gain))))
    w.writeframes(a.tobytes()); w.close()
