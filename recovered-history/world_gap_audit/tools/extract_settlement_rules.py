#!/usr/bin/env python3
"""Extract port tables and statically initialize four F875 templates from verified arguments."""
import argparse,hashlib,json,struct
from pathlib import Path
from extract_ship_registry import Image
from extract_worlds import extract as worlds
MASK=0xffffffff

def extract(path):
 b=Path(path).read_bytes();image=Image(b);source=worlds(path)
 all_rows={r['global_index']:r for s in source['systems'] for r in s['objects']}
 a=0x1234;c=0x5678;templates={}
 def seed():
  nonlocal a,c
  value=((a<<16)+c)&MASK;a=(((a*0xc6b)&MASK)//39)&65535;c=(((c*3137)&MASK)//39)&65535
  return value
 for index in range(18):
  r=all_rows[index];row=bytearray(68)
  rawseed=r['seed_raw'];kind=r['constructor']
  if kind==873:
   struct.pack_into('<I',row,0,(r['mass_raw']+1)&MASK)
   value=(((rawseed<<16)|(rawseed>>16))&MASK) if rawseed else seed()
   struct.pack_into('<I',row,4,value);struct.pack_into('<HHH',row,8,r['parent_index'],r['type_code'],r['model_index'])
   struct.pack_into('<I',row,14,r['orbit_raw']);struct.pack_into('<H',row,18,((r['phase_degrees']<<16)&MASK)//360)
   struct.pack_into('<HHH',row,32,r['eccentricity_raw'],((r['inclination_tenths_raw']<<16)&MASK)//3600,(r['temperature_c']+273)&65535)
   row[62]=r['rotation_raw']&255;row[63]=min(r['parent_index'],2)
  else:
   struct.pack_into('<IIHHH',row,0,0xfff60000,rawseed if rawseed else seed(),r['parent_index'],35,r['model_index'])
   phase=(-(((r['latitude_raw']<<16)&MASK)//36000)-0x4000)&65535
   struct.pack_into('<H',row,18,phase);struct.pack_into('<HH',row,34,(((r['longitude_raw']<<16)&MASK)//36000)&65535,293);row[63]=3
  name=r['name_en'].encode()+b'\0';row[38:38+len(name)]=name
  # Constructors clear these fields after copying the name.
  row[58:62]=bytes(4);row[64:68]=bytes(4)
  if index in [2,12,16,17]:templates[str(index)]=row.hex()
 signatures={'ground_coordinates':(struct.pack('<4I',0x2ea9,0xf7ed,0x496,0xe647),32),'ground_models':(struct.pack('<4I',0x56,0x59,0x57,0x58),48),'orbital_models':(struct.pack('<4I',0x48,0x4b,0x4c,0x4e),12)}
 result={'schema':1,'source_sha256':hashlib.sha256(b).hexdigest(),'templates':templates,'tables':{},'provenance':{},'template_initializer_sha256':source['initializer_sha256'],'template_call_offsets':{str(i):all_rows[i]['call_offset'] for i in [2,12,16,17]},'template_scope':'Static F873/F874 initialization through record 17, original initial F872 seeds 0x1234/0x5678. Compared separately with actual native F875.'}
 for key,(signature,count) in signatures.items():
  at=b.find(signature)
  if at<0 or b.find(signature,at+1)>=0:raise ValueError('Missing or ambiguous table '+key)
  raw=b[at:at+4*count];result['tables'][key]=list(struct.unpack('<'+'I'*count,raw));result['provenance'][key]={'offset':hex(at),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
 return result
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('executable',type=Path);p.add_argument('output',type=Path);a=p.parse_args();d=extract(a.executable);a.output.write_text(json.dumps(d,indent=2)+'\n');print('Settlement templates:',len(d['templates']))
