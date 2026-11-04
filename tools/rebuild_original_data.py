#!/usr/bin/env python3
"""Regenerate original FFE data from the verified user-supplied executable.

This is a NEW recovery driver around preserved, unmodified extractors. Their
missing extract_galaxy dependency supplied only EXPECTED: the fixed digest is
injected as a constant-only import adapter, never as a replacement galaxy tool.
No DOS program or CPU emulator is run. Optional host-native controls are separate.
"""
from __future__ import annotations
import argparse,hashlib,importlib.util,json,re,runpy,struct,sys,types
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
HISTORY=PROJECT/'recovered-history'
EXPECTED='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ARCHIVE_SHA256='8495ca9a5c7714816c62255810bb88b878dab8f33b09090ef5e57a3ffafcd7fd'
SIN_SIGNATURE=bytes.fromhex('000000003f2403007e480600be6c0900fd900c003db50f007cd91200bbfd1500')
SQRT_SIGNATURE=bytes.fromhex('0000a8050008cc09500ba60cdb0df70e')
SOURCE_HASHES={'ffe.asm':'d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a','ffedat.asm':'34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850','ffebmp.asm':'6f9732f6f881f038a9780460e287437d4d0b6b4b6df739d8a24e19a80e687a33'}

def digest(data:bytes)->str:return hashlib.sha256(data).hexdigest()

def module(name:str,path:Path):
 spec=importlib.util.spec_from_file_location(name,path)
 result=importlib.util.module_from_spec(spec);sys.modules[name]=result
 assert spec.loader is not None;spec.loader.exec_module(result)
 return result

def load_extractors():
 guard=types.ModuleType('extract_galaxy');guard.EXPECTED=EXPECTED
 guard.__doc__='Constant-only import adapter; does not implement galaxy extraction.'
 sys.modules['extract_galaxy']=guard
 harness=HISTORY/'ground_harness/tools';world=HISTORY/'world_gap_audit/tools'
 sys.path.insert(0,str(harness));sys.path.insert(0,str(world))
 result={}
 for name,path in [('extract_ship_registry',harness/'extract_ship_registry.py'),('extract_worlds',world/'extract_worlds.py'),('extract_settlement_rules',world/'extract_settlement_rules.py'),('native_reference',harness/'native_reference.py'),('build_ground_reference',harness/'build_ground_reference.py'),('build_ground_pads_reference',harness/'build_ground_pads_reference.py'),('build_terrain_query_reference',harness/'build_terrain_query_reference.py'),('build_terrain_game_query_reference',harness/'build_terrain_game_query_reference.py'),('extract_world_models',HISTORY/'ground_vector_source/tools/extract_world_models.py')]:
  result[name]=module(name,path)
 return result

def emit(directory:Path,name:str,value,outputs:list):
 data=(json.dumps(value,ensure_ascii=False,separators=(',',':'))+'\n').encode()
 target=directory/name;target.parent.mkdir(parents=True,exist_ok=True)
 target.write_bytes(data);outputs.append({'file':name,'bytes':len(data),'sha256':digest(data)})

def initialized_records(worlds:dict)->dict:
 rows={r['global_index']:r for s in worlds['systems'] for r in s['objects']}
 rows.update({r['global_index']:r for r in worlds['unmatched_fallback']})
 ordered=sorted(rows.values(),key=lambda r:int(r['call_offset'],16))
 a,c=0x1234,0x5678;records={}
 def seed():
  nonlocal a,c
  value=((a<<16)+c)&0xffffffff
  a=(((a*0xc6b)&0xffffffff)//39)&65535
  c=(((c*3137)&0xffffffff)//39)&65535
  return value
 for r in ordered:
  raw=bytearray(68);rawseed=r['seed_raw']
  if r['constructor']==873:
   struct.pack_into('<I',raw,0,(r['mass_raw']+1)&0xffffffff)
   value=(((rawseed<<16)|(rawseed>>16))&0xffffffff) if rawseed else seed()
   struct.pack_into('<IHHH',raw,4,value,r['parent_index'],r['type_code'],r['model_index'])
   struct.pack_into('<IH',raw,14,r['orbit_raw'],(((r['phase_degrees']<<16)&0xffffffff)//360)&65535)
   struct.pack_into('<HHH',raw,32,r['eccentricity_raw']&65535,(((r['inclination_tenths_raw']<<16)&0xffffffff)//3600)&65535,(r['temperature_c']+273)&65535)
   raw[62]=r['rotation_raw']&255;raw[63]=min(r['parent_index'],2)
  elif r['constructor']==874:
   value=rawseed if rawseed else seed()
   struct.pack_into('<IIHHH',raw,0,0xfff60000,value,r['parent_index'],35,r['model_index'])
   phase=(-(((r['latitude_raw']<<16)&0xffffffff)//36000)-0x4000)&65535
   struct.pack_into('<H',raw,18,phase)
   struct.pack_into('<HH',raw,34,(((r['longitude_raw']<<16)&0xffffffff)//36000)&65535,293)
   raw[63]=3
  else:raise ValueError('Unreviewed initializer constructor')
  name=r['name_en'].encode('ascii')+b'\0'
  if len(name)>30:raise ValueError('Initializer name exceeds record storage')
  raw[38:38+len(name)]=name
  raw[58:62]=bytes(4);raw[64:68]=bytes(4)
  assert len(raw)==68
  records[str(r['global_index'])]={'global_index':r['global_index'],'record_hex':raw.hex(),'seed_u32':struct.unpack_from('<I',raw,4)[0],'model_index':r['model_index'],'constructor':r['constructor'],'name_en':r['name_en']}
 result={'schema':1,'source_sha256':EXPECTED,'scope':'Regenerated original F875/F873/F874 record initialization, not ephemerides or a live object factory. Exact field writes derived from the preserved settlement extractor and verified source procedures.','initial_seed_words':[0x1234,0x5678],'final_seed_words':[a,c],'records':records}
 fixture=PROJECT/'tests/fixtures/rebuild_handcrafted_native_reference.json'
 if fixture.is_file():
  native=json.loads(fixture.read_text())
  if native['source_sha256']!=EXPECTED or set(native['records'])!=set(records):raise ValueError('Native F875 control uses a different source or record set')
  raw=bytearray(native['slots']*68)
  for key,row in records.items():
   if row['record_hex']!=native['records'][key]['record_hex']:raise ValueError('Static/native F875 mismatch at record '+key)
   raw[int(key)*68:(int(key)+1)*68]=bytes.fromhex(row['record_hex'])
  if digest(raw)!=native['slots_sha256'] or [a,c]!=native['source_seed_words_final']:raise ValueError('Static/native F875 buffer or final RNG mismatch')
  result['native_validation']={'fixture_sha256':digest(fixture.read_bytes()),'all_133_records_equal':True,'slots':native['slots'],'slots_sha256':native['slots_sha256'],'final_seed_words_equal':True,'fresh_process_repetitions_identical':native['fresh_process_repetitions_identical'],'source_procedure_hashes':native['source_procedure_hashes'],'four_preserved_old_native_records_equal':len(native.get('preserved_old_native_records_exact_matches',[]))==4}
 return result

def terrain_resources(mods:dict,source_data:str,exe:bytes)->dict:
 helper=mods['build_terrain_query_reference']
 _,metadata=helper.resource_assembly(source_data,exe)
 tables={}
 for number in range(7835,7895):
  key=f'DATA_{number:06d}';block=helper.data_block(source_data,number)
  offset=int(metadata['tables'][key]['exe_offset'],16);cursor=0;relocations=[]
  for line in block.splitlines():
   clean=line.split(';')[0].strip()
   if not clean or clean.startswith(('DATA_','align')):continue
   if clean.startswith('db '):cursor+=len(clean[3:].split(','))
   elif clean.startswith('dd '):
    for symbol in clean[3:].split(','):
     symbol=symbol.strip()
     if not re.fullmatch(r'(?:FUNC|DATA)_\d+',symbol):raise ValueError('Unreviewed terrain relocation')
     relocations.append({'offset':cursor,'symbol':symbol});cursor+=4
   else:raise ValueError('Unreviewed terrain resource directive')
  raw=exe[offset:offset+cursor]
  tables[str(number)]={'label':key,'exe_offset':hex(offset),'bytes_hex':raw.hex(),'sha256':digest(raw),'relocations':relocations}
 maps={}
 for number in [7637,7638]:
  raw=helper.byte_block(helper.data_block(source_data,number));at=exe.find(raw)
  if at<0:raise ValueError('Feature-map bytes absent from executable')
  maps[str(number)]={'label':f'DATA_{number:06d}','exe_offset':hex(at),'bytes_hex':raw.hex(),'sha256':digest(raw)}
 models,_=mods['build_terrain_game_query_reference'].model_data(exe,list(range(117,134)),True)
 return {'schema':2,'revision':'verified-terrain-resources-regenerated-v1','source_sha256':EXPECTED,'scope':'Original tables/maps and model117..133 collision resources. Non-pointer bytes verified against the executable; symbolic relocation identities retained from the matching source. Model117 is ellipsoidal and is not automatically eligible for a spherical provider.','tables':tables,'maps':maps,'models':models,'resource_verification':metadata}

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('executable',type=Path);p.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--output',type=Path,default=PROJECT/'data');p.add_argument('--native-ground-controls',action='store_true');p.add_argument('--native-terrain-controls',action='store_true');a=p.parse_args()
 if (a.native_ground_controls or a.native_terrain_controls) and a.output.resolve()!=(PROJECT/'data').resolve():raise SystemExit('Native control builders currently require the canonical project data output directory')
 if (a.native_ground_controls or a.native_terrain_controls) and not a.source.is_file():raise SystemExit('Native control builders require the reviewed reference assembly source')
 exe=a.executable.read_bytes()
 if digest(exe)!=EXPECTED:raise SystemExit('Unsupported original executable; checksum does not match')
 if a.source.is_file():
  for filename,expected_hash in SOURCE_HASHES.items():
   candidate=a.source.with_name(filename)
   if not candidate.is_file() or digest(candidate.read_bytes())!=expected_hash:raise SystemExit('Unsupported reference source; checksum does not match: '+filename)
 mods=load_extractors();a.output.mkdir(parents=True,exist_ok=True);outputs=[]
 worlds=mods['extract_worlds'].extract(a.executable)
 emit(a.output,'ffe_worlds.json',worlds,outputs)
 ships=mods['extract_ship_registry'].extract(a.executable);emit(a.output,'ffe_ship_registry.json',ships,outputs)
 models=mods['extract_world_models'].extract(a.executable);emit(a.output,'ffe_world_models.json',models,outputs)
 settlements=mods['extract_settlement_rules'].extract(a.executable)
 if any(len(bytes.fromhex(v))!=68 for v in settlements['templates'].values()):raise ValueError('Invalid source template size')
 emit(a.output,'ffe_settlement_rules.json',settlements,outputs)
 initialized=initialized_records(worlds);emit(a.output,'ffe_handcrafted_records.json',initialized,outputs)
 at=exe.find(SQRT_SIGNATURE)
 if at<0 or exe.find(SQRT_SIGNATURE,at+1)>=0:raise ValueError('Missing/ambiguous source sqrt table')
 raw=exe[at:at+4096]
 emit(a.output,'ffe_math.json',{'schema':1,'source_sha256':EXPECTED,'scope':'Original integer square-root constants; arithmetic implementation is separate.','sqrt_table_offset':hex(at),'sqrt_table_sha256':digest(raw),'sqrt_table':list(struct.unpack('<2048H',raw))},outputs)
 if a.source.is_file():
  source=a.source.read_text();source_data=a.source.with_name('ffedat.asm').read_text()
  pads=mods['build_ground_pads_reference'];extracted=pads.extract_tables(source_data,exe)
  pad_data={'schema':1,'source_sha256':EXPECTED,**extracted,'coordinate_shift_after_matrix':10,'scope':'Regenerated original open-air F650 pad tables for model81..90; underground model96 has a distinct original docking branch.','models':{str(model):{'table':str(table),'pad_count':pads.TABLE_COUNTS[table],'last_pad_index':pads.TABLE_COUNTS[table]-1} for model,table in pads.MODEL_TABLES.items()}}
  emit(a.output,'ffe_ground_pads.json',pad_data,outputs)
  at=exe.find(SIN_SIGNATURE)
  if at<0 or exe.find(SIN_SIGNATURE,at+1)>=0:raise ValueError('Missing/ambiguous source sine table')
  raw=exe[at:at+65536];values=list(struct.unpack('<16384i',raw))
  if values[0]!=0 or values[-1]!=0x7ffffff5 or not all(x<y for x,y in zip(values,values[1:])):raise ValueError('Invalid source sine table')
  bitmap=a.source.with_name('ffebmp.asm').read_text();block=mods['build_terrain_query_reference'].data_block(bitmap,7975)
  original=bytes(int(value.strip(),0) for line in block.splitlines() if line.split(';')[0].strip().startswith('db ') for value in line.split(';')[0].strip()[3:].split(','))
  if len(original)!=65536:raise ValueError('Unexpected original sine source resource size')
  if original!=raw:raise ValueError('Executable/source sine table mismatch')
  emit(a.output,'ffe_ground_coordinates.json',{'schema':1,'source_sha256':EXPECTED,'sine_table_offset':hex(at),'sine_table_sha256':digest(raw),'sine_table_matches_reviewed_resource':True,'scope':'Original DATA7975 Q31 quarter-sine bytes verified against ffebmp.asm.','sin_quarter_q31':values},outputs)
  emit(a.output,'ffe_terrain_query.json',terrain_resources(mods,source_data,exe),outputs)
 if a.native_ground_controls:
  for tool in ['build_ground_reference','build_ground_pads_reference']:
   script=Path(mods[tool].__file__);old=sys.argv
   try:
    (PROJECT/'tests/fixtures').mkdir(parents=True,exist_ok=True)
    sys.argv=[str(script),str(a.source),str(a.executable),'--project',str(PROJECT)]
    runpy.run_path(str(script),run_name='__main__')
   finally:sys.argv=old
  for filename in ['ffe_ground_coordinates.json','ffe_ground_pads.json']:
   item=next(r for r in outputs if r['file']==filename);raw=(a.output/filename).read_bytes();item.update(bytes=len(raw),sha256=digest(raw))
 if a.native_terrain_controls:
  controls=[('build_terrain_query_reference',[]),('build_terrain_game_query_reference',[]),('build_terrain_game_query_reference',['--model-ids',','.join(str(v) for v in range(117,134)),'--largest-axis-probes','--fixture-name','rebuild_terrain_all_models_reference.json'])]
  for tool,extra in controls:
   script=Path(mods[tool].__file__);old=sys.argv
   try:
    sys.argv=[str(script),str(a.source),str(a.executable),'--project',str(PROJECT),*extra]
    runpy.run_path(str(script),run_name='__main__')
   finally:sys.argv=old
 source_files={}
 if a.source.is_file():
  for filename in ['ffe.asm','ffedat.asm','ffebmp.asm']:
   path=a.source.with_name(filename);source_files[filename]={'bytes':path.stat().st_size,'sha256':digest(path.read_bytes())}
 provenance={'schema':1,'generation_kind':'deterministic regeneration from verified original files, not recovered old JSON text','original_archive_sha256':ARCHIVE_SHA256,'original_executable_sha256':EXPECTED,'extractor_import_adapter':'Only the previously verified EXPECTED constant is supplied for the missing extract_galaxy import; no galaxy algorithm is emulated.','counts':{'ships':len(ships['ships']),'selection_pools':len(ships['selection_pools']),'world_model_assets':len(models['models']),'handcrafted_systems':len(worlds['systems']),'handcrafted_objects':sum(len(s['objects']) for s in worlds['systems']),'initialized_records':len(initialized['records'])},'native_handcrafted_validation':initialized.get('native_validation',{}),'reference_source':{'url':'https://github.com/videogamepreservation/jjffe','commit':'7e540341d4e09aa3c92877b87d49e7f2c143ad8d','files':source_files,'known_variant_difference':'F879 SAR3 in this source versus SAR4 in uploaded executable; no F879 is used by F875 validation.'},'native_ground_controls_regenerated':a.native_ground_controls,'native_terrain_controls_regenerated':a.native_terrain_controls,'outputs':outputs}
 emit(a.output,'ffe_data_provenance.json',provenance,[])
 print(json.dumps({'counts':provenance['counts'],'outputs':outputs},ensure_ascii=False,indent=2))

if __name__=='__main__':main()
