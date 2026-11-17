#!/usr/bin/env python3
"""Extract complete original collision bytecode, not render-command streams.

All bytes originate in the pinned uploaded executable. Archive-only replay uses
exact VA/offset byte-span captures; it does not guess unknown record lengths.
"""
from __future__ import annotations
import argparse,hashlib,json,struct
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
OUT=PROJECT/'data/ffe_collision_programs.json'
PROOF=PROJECT/'validation/collision-programs-2026-11-17/resources'
CAPTURE=PROOF/'original-spans.json'
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
DATA_SHA='34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850'
TABLE_OFFSET=0xba8fc
ROOTS=list(range(149))
def sha(b):return hashlib.sha256(b).hexdigest()
def require(ok,why):
 if not ok:raise ValueError(why)
class Image:
 def __init__(self,raw):
  self.raw=raw;self.spans={};pe=struct.unpack_from('<I',raw,60)[0];self.base=struct.unpack_from('<I',raw,pe+52)[0];count=struct.unpack_from('<H',raw,pe+6)[0];at=pe+24+struct.unpack_from('<H',raw,pe+20)[0];self.sections=[struct.unpack_from('<4I',raw,at+i*40+8)for i in range(count)]
 def offset(self,va,n):
  for _,rva,size,at in self.sections:
   d=va-self.base-rva
   if 0<=d and d+n<=size and at+d+n<=len(self.raw):return at+d
  raise ValueError('Unmapped source pointer '+hex(va)+' length '+str(n))
 def read(self,va,n):return self.raw[self.offset(va,n):self.offset(va,n)+n]
 def keep(self,name,va,n):
  raw=self.read(va,n);self.spans[name]={'virtual_address_u32':va,'executable_offset':self.offset(va,n),'bytes':n,'hex':raw.hex(),'sha256':sha(raw)};return raw
class Archived:
 def __init__(self,capture):self.spans=capture['spans']
 def read(self,va,n):
  for row in self.spans.values():
   lo=row['virtual_address_u32'];raw=bytes.fromhex(row['hex'])
   if lo<=va and va+n<=lo+len(raw):return raw[va-lo:va-lo+n]
  raise ValueError('Missing captured source span '+hex(va)+' length '+str(n))
 def keep(self,name,va,n):
  row=self.spans[name];raw=self.read(va,n);require(row['virtual_address_u32']==va and row['bytes']>=n and bytes.fromhex(row['hex'])[:n]==raw and row['sha256']==sha(bytes.fromhex(row['hex'])),'Archived resource span differs '+name);return raw

def decode_program(image,va):
 records=[];at=0;refs=[];classes={};planes=[];verts=[]
 def read(n):
  nonlocal at
  require(at+n<=65536,'Program exceeds reviewed64KiB limit');v=image.read(va+at,n);at+=n;return v
 def plane_list(first=None):
  result=[]
  if first is not None:
   if first==0:return result
   result.append(first)
  for _ in range(4096):
   q=read(1)[0]
   if q==0:return result
   result.append(q)
  raise ValueError('Unterminated plane list')
 for _ in range(4096):
  start=at;op=read(1)[0]
  if op==0:return records,at,sorted(set(refs)),sorted(set(planes)),sorted(set(verts)),classes
  volume=read(1)[0];cls=op&0xc0;classes[str(cls)]=classes.get(str(cls),0)+1
  row={'offset':start,'opcode_u8':op,'volume_u8':volume,'class_u8':cls}
  if op&0x20:
   q=read(2);row['condition']={'equipment_index_u8':q[0],'shift_sign_u8':q[1]}
  if cls==0:
   first=read(1)[0]
   if first==255:
    basis=read(6);features_start=at;count=0
    while struct.unpack('<h',image.read(va+at,2))[0]!=0:
     read(16);count+=1;require(count<=4096,'Terrain feature list exceeds limit')
    read(2);row.update(kind='terrain',terrain_basis_hex=basis.hex(),terrain_features_offset=features_start,terrain_feature_count=count)
    verts.extend(basis[:4])
   else:
    values=plane_list(first);row.update(kind='planes_all',plane_codes_u8=values);planes.extend(values)
  elif cls==0x40:
   values=plane_list();row.update(kind='planes_any',plane_codes_u8=values);planes.extend(values)
  elif cls==0x80:
   q=read(4);index=q[0]*256+q[1];refs.append(index);verts.append(q[3]);row.update(kind='submodel',model_index_u32=index,vertex_code_u8=q[3],orientation_u8=q[2])
  else:
   values=plane_list();row.update(kind='planes_volume',plane_codes_u8=values);planes.extend(values)
  row['next_offset']=at;records.append(row)
 raise ValueError('Collision program record limit exceeded')

def extract(image,table,source_hashes):
 models={};pending=ROOTS.copy();table_slots={};classes={}
 while pending:
  index=pending.pop(0)
  if str(index)in models:continue
  require(0<=index<65536,'F1538 reference index outside reviewed source table domain')
  slot=table(index);ptr=struct.unpack('<I',slot)[0];table_slots[str(index)]=slot.hex();require(ptr!=0,'Null descriptor table entry '+str(index))
  desc=image.keep('model%d/descriptor'%index,ptr,68);w=struct.unpack('<17I',desc)
  vertex_bytes=w[2]*3;normal_bytes=w[4]*3
  require(vertex_bytes<=65536 and normal_bytes<=65536,'Descriptor vector count outside resource bound')
  vertex=image.keep('model%d/vertices'%index,w[1],vertex_bytes)if w[1]and vertex_bytes else b''
  normal=image.keep('model%d/normals'%index,w[3]-6,normal_bytes+6)if w[3]else b''
  records=[];refs=[];plane_codes=[];vertex_codes=[];child_records=[];children=b'';program=b'';modelclasses={}
  if w[13]:
   records,n,refs,plane_codes,vertex_codes,modelclasses=decode_program(image,w[13]);program=image.keep('model%d/program'%index,w[13],n)
   lo=w[13]-2
   for _ in range(1024):
    displacement=struct.unpack('<h',image.read(lo,2))[0]
    if displacement==0:break
    encoded=struct.unpack('<h',image.read(lo-2,2))[0];child_records.append({'axis_radius_encoded_s16':encoded,'displacement_s16':displacement});lo-=4
   else:raise ValueError('Unterminated backward child list '+str(index))
   children=image.keep('model%d/children'%index,lo,w[13]-lo)
  # Preserve exact packed source reads, including the six bytes before the
  # normal origin. This is necessary for literal plane codes0/1.
  max_vertex_end=len(vertex);read_notes=[]
  max_normal_end=max([len(normal)]+[(code>>1)*6+6 for code in plane_codes])
  if max_normal_end>len(normal):
   require(w[3]!=0,'Null normal pointer used by collision program model'+str(index));read_notes.append({'normal_required_bytes':max_normal_end,'descriptor_count_derived_bytes':normal_bytes+6});normal=image.keep('model%d/normals'%index,w[3]-6,max_normal_end)
  for code in plane_codes:
   off=(code>>1)*6 # normal capture has6byte prefix, source lookup has-6
   require(normal and off+6<=len(normal),'Plane code outside captured normals model%d code%d'%(index,code))
   vertex_codes.append(normal[off])
  for code in vertex_codes:
   need=(code>>1)*6+6
   if need>max_vertex_end:read_notes.append({'vertex_code_u8':code,'required_bytes':need,'declared_bytes':vertex_bytes});max_vertex_end=max(max_vertex_end,need)
  if max_vertex_end>len(vertex):vertex=image.keep('model%d/vertices'%index,w[1],max_vertex_end)
  for c,n in modelclasses.items():classes[c]=classes.get(c,0)+n
  spans={name.rsplit('/',1)[1]:row for name,row in image.spans.items()if name.startswith('model%d/'%index)}
  models[str(index)]={'model_index_u32':index,'descriptor_hex':desc.hex(),'vertices_hex':vertex.hex(),'vertices_origin_u32':0,'normals_hex':normal.hex(),'normals_origin_u32':6 if normal else 0,'collision_program_hex':program.hex(),'collision_program_present':bool(w[13]),'children_hex':children.hex(),'children_records':child_records,'children_enabled_by_factory':bool(program and program[0]),'undefined_child_axis_records':[j for j,c in enumerate(child_records)if(c['axis_radius_encoded_s16']&6)==6],'program_records':records,'nested_model_indices':refs,'packed_read_extensions':read_notes,'original_pointers_u32':{'descriptor':ptr,'vertices':w[1],'normals':w[3],'collision_program':w[13]},'source_spans':spans,'all_program_records_structurally_decoded':True}
  pending.extend(i for i in refs if str(i)not in models)
 return {'schema':'starfrontier-original-collision-program-resources-v1','profile':'dos-firstenc-collision-program-resources-v1','source_executable_sha256':source_hashes['executable'],'source_assembly_sha256':source_hashes['assembly'],'source_data_sha256':source_hashes['data'],'root_model_indices':ROOTS,'root_model_count':149,'model_count':len(models),'collision_program_count':sum(v['collision_program_present']for v in models.values()),'nested_model_indices':sorted(int(k)for k in models if int(k)not in ROOTS),'model_table_executable_offset':TABLE_OFFSET,'model_table_slots_hex':table_slots,'record_class_counts':classes,'models':models,'scope':'Exact original68B descriptors, complete structurally decoded collision programs, source packed vertices/normals including six-byte normal prefixes and backward F576 child lists for all149 primary models and recursively referenced collision submodels. These are collision programs, not render streams. Structural extraction does not establish execution of all F582/F580/F581 branches, a complete world collider, damage engine or Main integration.'}

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--output',type=Path,default=OUT);p.add_argument('--capture',type=Path,default=CAPTURE);p.add_argument('--refresh-original-proof',action='store_true');a=p.parse_args()
 if a.refresh_original_proof:
  raw=a.exe.read_bytes();require(sha(raw)==EXE_SHA and sha(a.asm.read_bytes())==ASM_SHA and sha(a.data.read_bytes())==DATA_SHA,'Pinned original identities differ');image=Image(raw)
  def table(i):
   at=TABLE_OFFSET+i*4;ptr=struct.unpack_from('<I',raw,at)[0]
   # The real model-pointer table lies atVA4D0CFC in the uploaded image.
   require(image.offset(0x4d0cfc+i*4,4)==at,'Model table mapping differs');return image.keep('table/%d'%i,0x4d0cfc+i*4,4)
  doc=extract(image,table,{'executable':EXE_SHA,'assembly':ASM_SHA,'data':DATA_SHA});capture={'schema':'starfrontier-original-collision-byte-spans-v1','source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'source_data_sha256':DATA_SHA,'spans':image.spans};a.capture.parent.mkdir(parents=True,exist_ok=True);a.capture.write_text(json.dumps(capture,indent=2)+'\n')
 else:
  c=json.loads(a.capture.read_text());require(c['source_executable_sha256']==EXE_SHA and c['source_assembly_sha256']==ASM_SHA and c['source_data_sha256']==DATA_SHA,'Capture source identities differ')
  for row in c['spans'].values():require(row['bytes']==len(bytes.fromhex(row['hex'])) and row['sha256']==sha(bytes.fromhex(row['hex'])),'Captured original span identity differs')
  image=Archived(c);doc=extract(image,lambda i:image.keep('table/%d'%i,0x4d0cfc+i*4,4),{'executable':EXE_SHA,'assembly':ASM_SHA,'data':DATA_SHA})
 a.output.parent.mkdir(parents=True,exist_ok=True);encoded=(json.dumps(doc,indent=2)+'\n').encode();a.output.write_bytes(encoded)
 report={'status':'verified','root_model_count':149,'model_count':doc['model_count'],'collision_program_count':doc['collision_program_count'],'nested_model_indices':doc['nested_model_indices'],'record_class_counts':doc['record_class_counts'],'resource_sha256':sha(encoded),'resource_bytes':len(encoded),'capture_sha256':sha(a.capture.read_bytes()),'original_spans':len(image.spans),'all_records_structurally_decoded':True,'expected_physics_calculated':False}
 if a.refresh_original_proof:(a.capture.parent/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(report,indent=2))
if __name__=='__main__':main()
