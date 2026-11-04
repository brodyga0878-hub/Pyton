#!/usr/bin/env python3
"""Read constant arguments of the verified FFE handcrafted-world initializer.
This is a bounded static data extractor, not an x86 interpreter or emulator.
It refuses any instruction outside the initializer's audited linear grammar.
"""
import argparse, hashlib, json, struct
from pathlib import Path
from extract_ship_registry import Image
from extract_galaxy import EXPECTED
START=0x28568
TABLE_SIGNATURE=bytes.fromhex('1897a402000000001897a406380000001677a40e4b000000')

def extract(path):
 b=Path(path).read_bytes();image=Image(b)
 if b[START:START+5]!=bytes.fromhex('558bec5356'):raise ValueError('Unexpected initializer')
 pos=START+5;ebx=struct.unpack_from('<I',b,pos+1)[0];pos+=5
 if b[pos]!=0xbe:raise ValueError('Missing name base')
 esi=struct.unpack_from('<I',b,pos+1)[0];pos+=5
 records={};terminators=[];stack=[];eax=None;chunk=pos;targets={}
 def signed(n):return n-0x100000000 if n>=0x80000000 else n
 def name(address):
  at=image.offset(address,1);end=b.find(b'\0',at,at+40)
  if end<0:raise ValueError('Missing world name terminator')
  return b[at:end].decode('ascii')
 while pos<START+12000:
  op=b[pos]
  if op==0x68:stack.append(struct.unpack_from('<I',b,pos+1)[0]);pos+=5
  elif op==0x6a:stack.append(struct.unpack_from('<b',b,pos+1)[0]&0xffffffff);pos+=2
  elif op==0x50:
   if eax is None:raise ValueError('Unknown pushed value')
   stack.append(eax);pos+=1
  elif op==0x53:stack.append(ebx);pos+=1
  elif op==0x8d:
   mod=b[pos+1]
   if mod not in [0x86,0x83,0x43]:raise ValueError('Unaudited LEA')
   size=1 if mod==0x43 else 4
   delta=int.from_bytes(b[pos+2:pos+2+size],'little',signed=True)
   eax=(esi if mod==0x86 else ebx)+delta;pos+=2+size
  elif op==0xe8:
   target=pos+5+struct.unpack_from('<i',b,pos+1)[0]
   args=list(reversed(stack));stack=[]
   if len(args) not in [7,14]:raise ValueError('Unexpected argument count')
   if len(args) in targets and targets[len(args)]!=target:raise ValueError('Changed constructor target')
   targets[len(args)]=target
   index=(args[0]-ebx)//68
   if args[0]!=ebx+index*68 or not 0<=index<146 or index in records:raise ValueError('Invalid record address')
   if len(args)==14:
    _,mass,seed,ecc,tilt,parent,orbit,phase,temp,spin,orientation,kind,model,label=args
    row={'mass_raw':mass,'seed_raw':seed,'eccentricity_raw':ecc,'inclination_tenths_raw':tilt,'parent_index':parent,'orbit_raw':orbit,'phase_degrees':phase,'temperature_c':signed(temp),'rotation_raw':spin,'orientation_raw':orientation,'type_code':kind,'model_index':model,'name_en':name(label),'constructor':873}
   else:
    _,seed,lat,lon,parent,model,label=args
    row={'seed_raw':seed,'latitude_raw':signed(lat),'longitude_raw':signed(lon),'parent_index':parent,'type_code':35,'model_index':model,'name_en':name(label),'constructor':874}
   row.update({'global_index':index,'call_offset':hex(pos),'initializer_hex':b[chunk:pos+5].hex()})
   if row['type_code']<32:
    d=image.pointer(0xba8fc+row['model_index']*4,68)
    fields=struct.unpack_from('<17I',b,d)
    row['model_radius_raw']=fields[11];row['model_scale_raw']=fields[5]+fields[6]-8
   records[index]=row;pos+=5
   if b[pos:pos+2]!=b'\x83\xc4' or b[pos+2]!=len(args)*4:raise ValueError('Unexpected stack cleanup')
   pos+=3;chunk=pos
  elif b[pos:pos+2] in [b'\x33\xc0',b'\x31\xc0']:eax=0;pos+=2
  elif b[pos:pos+2] in [b'\x89\x83',b'\x89\x43']:
   size=4 if b[pos+1]==0x83 else 1
   delta=int.from_bytes(b[pos+2:pos+2+size],'little',signed=True)
   if eax!=0 or delta%68:raise ValueError('Unexpected initializer write')
   terminators.append(delta//68);pos+=2+size;chunk=pos
  elif b[pos:pos+4]==bytes.fromhex('5e5b5dc3'):
   pos+=4;break
  else:raise ValueError(f'Unaudited opcode at {pos:#x}: {b[pos:pos+8].hex()}')
 else:raise ValueError('Unbounded initializer')
 at=b.find(TABLE_SIGNATURE)
 if at<0:raise ValueError('Missing system mapping')
 systems=[]
 for i in range(11):
  code,start=struct.unpack_from('<II',b,at+i*8)
  end=min(t for t in terminators if t>=start)
  rows=[dict(records[j],local_index=j-start+1) for j in range(start,end)]
  for r in rows:
   if not 0<=r['parent_index']<r['local_index']:raise ValueError('Invalid parent tree')
  systems.append({'system_id':code,'name_en':rows[0]['name_en'],'start_index':start,'objects':rows})
 # The original falls back to entry 143 for an unmatched handcrafted system.
 fallback=[dict(records[j],local_index=j-143+1) for j in range(143,146)]
 return {'schema':1,'source_sha256':EXPECTED,'initializer_offset':hex(START),'initializer_end':hex(pos),'initializer_sha256':hashlib.sha256(b[START:pos]).hexdigest(),'mapping_offset':hex(at),'systems':systems,'unmatched_fallback':fallback,'note':'Original constant arguments and parent trees. Display translations and analytic physical adapter are separate; this is not the procedural generator.'}

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('executable',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
 d=extract(a.executable);a.output.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
 print([(s['name_en'],len(s['objects'])) for s in d['systems']])
if __name__=='__main__':main()
