#!/usr/bin/env python3
"""Capture actual DOS mission bytes and replay their bounded resource graph.

The JJFFE source supplies named layout cross-checks, never replacement bytecode.
Default replay opens only the committed original byte-span capture.
"""
from __future__ import annotations
import argparse,hashlib,json,re,struct
from pathlib import Path
from extract_source_collision_programs import Image

PROJECT=Path(__file__).resolve().parents[1]
PROOF=PROJECT/'validation/mission-expressions-2026-11-18/resources'
CAPTURE=PROOF/'original-spans.json'
OUTPUT=PROJECT/'data/ffe_mission_programs.json'
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
DATA_SHA='34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850'
MISSION_SHA='6f9732f6f881f038a9780460e287437d4d0b6b4b6df739d8a24e19a80e687a33'
IDENTITIES={'source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'source_data_sha256':DATA_SHA,'source_mission_assembly_sha256':MISSION_SHA}
BASE=0x4801c4;TABLE=0x48e0f8;TABLE_END=TABLE+105*4;END=0x49aa16
GLOBAL=0x60bde0;NULL=0xffffffff
REGIONS={'mission':(BASE,TABLE_END-BASE),'name_table':(0x48e29c,68*8),'string_table':(0x48e4bc,468*4),'event_functions':(0x48ec0c,48),'expression_metadata':(0x48ec3c,68*16),'vectors':(0x48f07c,27*12),'names':(0x48f1c0,716),'strings':(0x48f48c,46474)}
sha=lambda raw:hashlib.sha256(raw).hexdigest()
def require(ok,message):
 if not ok:raise ValueError(message)
def encode(doc):return (json.dumps(doc,ensure_ascii=False,indent=2)+'\n').encode()
def numeric(source,start,end):
 raw=bytearray()
 for line in source[source.index(start+':'):source.index(end+':')].splitlines():
  line=line.split(';')[0].strip();m=re.fullmatch(r'(db|dd)\s+(.+)',line)
  if m:
   for word in m[2].split(','):raw.extend((int(word.strip(),0)&(255 if m[1]=='db'else 0xffffffff)).to_bytes(1 if m[1]=='db'else 4,'little'))
 return bytes(raw)
def source_layout(mission,data):
 table=mission[mission.index('DATA_001697:'):mission.index('; MODEL DATA START')]
 labels=re.findall(r'\bdd (DATA_\d+)',table);require(len(labels)==105,'Mission source table count differs')
 counts=[];headers=[]
 for label in labels:
  match=re.search(r'^'+label+r':[^\n]*\n(.*?)(?=^DATA_\d+:)',mission,re.M|re.S);require(match is not None,'Source descriptor missing '+label)
  words=bytearray();pointers=[]
  for line in match[1].splitlines():
   line=line.split(';')[0].strip();m=re.fullmatch(r'(db|dd)\s+(.+)',line)
   if not m:continue
   for value in m[2].split(','):
    value=value.strip()
    if value.startswith('DATA_'):pointers.append(len(words));words.extend(b'\0'*4)
    else:words.extend((int(value,0)&(255 if m[1]=='db'else 0xffffffff)).to_bytes(1 if m[1]=='db'else 4,'little'))
  require(len(words)>=32 and (len(words)-28)%4==0 and all(n%4==0 for n in pointers),'Source descriptor layout differs')
  counts.append((len(words)-28)//4)
  headers.append({str(n):struct.unpack_from('<I',words,n)[0]for n in [8,12,16,24]})
 name_rows=data[data.index('DATA_001698:'):data.index('DATA_001699:')]
 module_ids=[]
 for line in name_rows.splitlines():
  m=re.match(r'\s*db\s+([^;]+)',line)
  if m:module_ids.append(int.from_bytes(bytes(int(v.strip(),0)for v in m[1].split(',')),'little'))
 require(len(module_ids)==68,'Source name mapping count differs')
 return {'module_source_labels':labels,'descriptor_block_counts':counts,'descriptor_scalar_words':headers,'expression_metadata_hex':numeric(data,'DATA_001701','DATA_001705').hex(),'vectors_hex':numeric(data,'DATA_001705','DATA_001708').hex(),'name_table_module_indices':module_ids,'string_table_count':len(re.findall(r'\bdd DATA_\d+',data[data.index('DATA_001699:'):data.index('DATA_001700:')])),'first_expression_hex':numeric(mission,'DATA_000090','DATA_000091').hex()}

def capture_original(exe,assembly,data_path,mission_path):
 raw=exe.read_bytes();asm_raw=assembly.read_bytes();data_raw=data_path.read_bytes();mission_raw=mission_path.read_bytes()
 require([sha(x)for x in [raw,asm_raw,data_raw,mission_raw]]==[EXE_SHA,ASM_SHA,DATA_SHA,MISSION_SHA],'Pinned original identities differ')
 image=Image(raw);layout=source_layout(mission_raw.decode(),data_raw.decode());spans={}
 for name,(va,count)in REGIONS.items():
  b=image.read(va,count);spans[name]={'virtual_address_u32':va,'executable_offset':image.offset(va,count),'bytes':count,'hex':b.hex(),'sha256':sha(b)}
 require(image.read(BASE,len(bytes.fromhex(layout['first_expression_hex'])))==bytes.fromhex(layout['first_expression_hex']),'First mission expression anchor differs')
 require(raw.find(bytes.fromhex(layout['first_expression_hex']))==image.offset(BASE,1)and raw.find(bytes.fromhex(layout['first_expression_hex']),image.offset(BASE,1)+1)<0,'First expression must uniquely bind the mission base')
 for name,key in [('expression_metadata','expression_metadata_hex'),('vectors','vectors_hex')]:
  b=bytes.fromhex(layout[key]);require(b==image.read(REGIONS[name][0],REGIONS[name][1])and raw.find(b)==image.offset(REGIONS[name][0],len(b))and raw.find(b,raw.find(b)+1)<0,'Actual immutable source numeric table differs '+name)
 # The first32 bytes are present in the final raw data section; the last8
 # come from that PE section's explicitly zero-filled virtual extension.
 require(image.read(GLOBAL,32)==bytes(32),'Initial file-backed module globals differ')
 sections=[s for s in image.sections if image.base+s[1]<=GLOBAL<image.base+s[1]+s[0]];require(len(sections)==1,'Module global section is ambiguous')
 virt,rva,size,at=sections[0];require(image.base+rva+size==GLOBAL+32 and GLOBAL+40<=image.base+rva+virt,'Module global virtual tail binding differs')
 globals_proof={'original_va_u32':GLOBAL,'bytes':40,'file_backed_bytes':32,'executable_offset':image.offset(GLOBAL,32),'file_backed_hex':image.read(GLOBAL,32).hex(),'virtual_zero_fill_bytes':8,'section_virtual_end_u32':image.base+rva+virt,'initial_hex':bytes(40).hex()}
 return {'schema':'starfrontier-original-mission-byte-spans-v1',**IDENTITIES,'spans':spans,'source_layout':layout,'module_globals_initialization':globals_proof,'resource_image_start_va_u32':BASE,'resource_image_end_va_u32':END}

def extract(capture):
 require(capture.get('schema')=='starfrontier-original-mission-byte-spans-v1'and all(capture.get(k)==v for k,v in IDENTITIES.items()),'Mission capture identity differs')
 spans=capture['spans'];require(set(spans)==set(REGIONS),'Mission span inventory differs')
 regions={}
 for name,(va,n)in REGIONS.items():
  row=spans[name];b=bytes.fromhex(row['hex']);require(row['virtual_address_u32']==va and row['bytes']==len(b)==n and row['sha256']==sha(b)and row['executable_offset']==va-0x480000+0x69c00,'Invalid source byte span '+name)
  regions[name]={'original_va_u32':va,'bytes':n,'hex':b.hex(),'sha256':sha(b),'executable_offset':row['executable_offset']}
 require(sum(n for _,n in REGIONS.values())==END-BASE and capture['resource_image_start_va_u32']==BASE and capture['resource_image_end_va_u32']==END,'Captured resource image has gaps/overlap')
 image=bytes.fromhex(regions['mission']['hex']);layout=capture['source_layout'];module_ptrs=struct.unpack_from('<105I',image,TABLE-BASE)
 require(len(set(module_ptrs))==105 and len(layout['module_source_labels'])==len(layout['descriptor_block_counts'])==len(layout['descriptor_scalar_words'])==105,'Mission descriptor inventory differs')
 def pointer(p,count=1):require(BASE<=p and p+count<=TABLE,'Program resource pointer outside image '+hex(p));return p-BASE
 blocks={};modules=[];differences=[]
 for index,p in enumerate(module_ptrs):
  offset=pointer(p,32);w=struct.unpack_from('<7I',image,offset);limit=min(q for q in [*module_ptrs,TABLE]if q>p);block_ptrs=[]
  # Only backward pointers to complete source block headers are accepted.
  while p+28+len(block_ptrs)*4<limit:
   b=struct.unpack_from('<I',image,offset+28+len(block_ptrs)*4)[0]
   if not BASE<=b<p:break
   guard,count=struct.unpack_from('<2I',image,b-BASE)
   if not BASE<=guard<b or count>1024 or b+8+count*4>p:break
   refs=list(struct.unpack_from('<%dI'%count,image,b-BASE+8))
   require(all(BASE<=q<b for q in refs),'Invalid clause pointer')
   block_ptrs.append(b);blocks[str(b-BASE)]={'block_offset_u32':b-BASE,'initialization_offset_u32':guard-BASE,'clause_offsets_u32':[q-BASE for q in refs]}
  require(len(block_ptrs)==layout['descriptor_block_counts'][index]>0,'Actual/source block topology differs for module'+str(index))
  require(w[2]<=256 and 2<=w[4]<=256 and w[6]<=10,'Descriptor scalar outside source profile')
  cleanup=(w[3]&0x7fffffff)-(w[3]&0x80000000);require(cleanup==-1 or 0<=cleanup<len(block_ptrs),'Cleanup block out of bounds')
  require((w[2]>0)==(w[0]!=0)and(w[2]>0)==(w[1]!=0),'Argument pointers/count mismatch')
  require((w[6]>0)==(w[5]!=0),'Module globals pointer/count mismatch')
  if w[6]:require(GLOBAL<=w[5]and w[5]+w[6]*4<=GLOBAL+40 and (w[5]-GLOBAL)%4==0,'Module globals owner outside40B')
  for key,n in [('argument_count',8),('cleanup_block',12),('variable_words',16),('global_words',24)]:
   actual=w[n//4];reviewed=layout['descriptor_scalar_words'][index][str(n)]
   if actual!=reviewed:differences.append({'module_index_u32':index,'source_label':layout['module_source_labels'][index],'field':key,'DOS_u32':actual,'JJFFE_u32':reviewed,'DOS_executable_offset':regions['mission']['executable_offset']+offset+n})
  modules.append({'module_index_u32':index,'source_label':layout['module_source_labels'][index],'descriptor_offset_u32':offset,'argument_targets_offset_u32':pointer(w[0])if w[0]else NULL,'argument_expressions_offset_u32':pointer(w[1])if w[1]else NULL,'argument_count_u32':w[2],'cleanup_block_index_s32':cleanup,'variable_words_u32':w[4],'global_owner_offset_u32':w[5]-GLOBAL if w[5]else NULL,'global_words_u32':w[6],'block_offsets_u32':[q-BASE for q in block_ptrs]})
 require(len(blocks)==337,'Actual block inventory differs')
 require(any(d['module_index_u32']==32 and d['field']=='variable_words'and d['DOS_u32']==15 and d['JJFFE_u32']==16 for d in differences),'Confirmed DOS/JJFFE module32 difference missing')
 def string_rows(region,table_region,count,stride):
  raw=bytes.fromhex(regions[region]['hex']);table=bytes.fromhex(regions[table_region]['hex']);base=regions[region]['original_va_u32'];result=[]
  for i in range(count):
   p=struct.unpack_from('<I',table,i*stride)[0];offset=p-base;require(0<=offset<len(raw),'String pointer outside captured region');end=raw.index(0,offset)
   row={'index_u32':i,'offset_u32':offset,'bytes_including_NUL_u32':end-offset+1}
   if stride==8:row['module_index_u32']=struct.unpack_from('<I',table,i*stride+4)[0];require(row['module_index_u32']<105,'Name module out of range')
   result.append(row)
  return result
 names=string_rows('names','name_table',68,8);strings=string_rows('strings','string_table',468,4)
 require([n['module_index_u32']for n in names]==layout['name_table_module_indices']and layout['string_table_count']==468,'Name/string source table topology differs')
 metadata=bytes.fromhex(regions['expression_metadata']['hex']);vectors=bytes.fromhex(regions['vectors']['hex'])
 require(metadata.hex()==layout['expression_metadata_hex']and vectors.hex()==layout['vectors_hex'],'Immutable source numeric resources differ')
 metadata_rows=[{'selector_u8':i,'child_expression_count_s32':a,'event_code_s32':b,'event_argument0_kind_s32':c,'event_argument1_kind_s32':d}for i,(a,b,c,d)in enumerate(struct.iter_unpack('<4i',metadata))]
 globals_proof=capture['module_globals_initialization'];require(globals_proof['original_va_u32']==GLOBAL and globals_proof['bytes']==40 and globals_proof['file_backed_bytes']==32 and globals_proof['virtual_zero_fill_bytes']==8 and globals_proof['executable_offset']==GLOBAL-0x480000+0x69c00 and globals_proof['section_virtual_end_u32']==0x6db000 and globals_proof['file_backed_hex']==bytes(32).hex()and globals_proof['initial_hex']==bytes(40).hex(),'Module global initialization proof differs')
 return {'schema':'starfrontier-original-mission-program-resources-v1','profile':'dos-firstenc-mission-resource-graph-v1',**IDENTITIES,'region_count':len(regions),'captured_file_bytes':sum(v['bytes']for v in regions.values()),'regions':regions,'module_table_offset_u32':TABLE-BASE,'module_count':105,'modules':modules,'block_count':len(blocks),'blocks':blocks,'expression_metadata_rows':metadata_rows,'expression_selector_count':68,'vector_count':27,'name_count':68,'names':names,'mission_string_count':468,'mission_strings':strings,'event_function_words_u32':list(struct.unpack('<12I',bytes.fromhex(regions['event_functions']['hex']))),'module_globals_initialization':globals_proof,'DOS_JJFFE_descriptor_scalar_differences':differences,'descriptor_extent_policy':'Actual backward-pointer scan with complete header/clauses bounds; all105 counts independently cross-checked against named source descriptor spans. Full DOS image is retained regardless of decoding.','bytecode_semantic_execution_claimed':False,'all_DOS_mission_resource_bytes_retained':True,'full_F41_VM_executed':False,'Main_integrated':False,'scope':'Exact bounded DOS mission resource image,105descriptor roots,337block headers and all clause pointers;68expression metadata rows,27vectors,68names,468NULstrings and12event words. Bytecode bytes are captured without pretending to decode or execute all statements. JJFFE descriptor scalars are variant diagnostics only; actual DOS bytes remain authoritative.'}

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--mission-asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffebmp.asm'));p.add_argument('--capture',type=Path,default=CAPTURE);p.add_argument('--output',type=Path,default=OUTPUT);p.add_argument('--reprove-original',action='store_true');a=p.parse_args()
 if a.reprove_original:
  capture=capture_original(a.exe,a.asm,a.data,a.mission_asm);a.capture.parent.mkdir(parents=True,exist_ok=True);a.capture.write_bytes(encode(capture))
 else:capture=json.loads(a.capture.read_text())
 doc=extract(capture);encoded=encode(doc);a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_bytes(encoded)
 report={'status':'verified','resource_sha256':sha(encoded),'resource_bytes':len(encoded),'capture_sha256':sha(a.capture.read_bytes()),'module_count':doc['module_count'],'block_count':doc['block_count'],'captured_file_bytes':doc['captured_file_bytes'],'expression_selector_count':68,'mission_string_count':468,'DOS_JJFFE_descriptor_scalar_differences':doc['DOS_JJFFE_descriptor_scalar_differences'],'bytecode_semantic_execution_claimed':False,'full_F41_VM_executed':False}
 if a.reprove_original:(a.capture.parent/'verification.json').write_bytes(encode(report))
 print(json.dumps(report,indent=2))
if __name__=='__main__':main()
