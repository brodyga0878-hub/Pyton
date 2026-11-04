#!/usr/bin/env python3
"""Execute original F581 terrain collision caller and F1876 with source model data.

This supplies raw model-local observer vectors. It captures the original query
matrix and computes original integer altitude, without guessing a geographic
matrix or claiming physical SI units. Broad synthetic object bounds force the
terrain branch and do not replace any frame or height arithmetic.
"""
import argparse,hashlib,json,math,struct,subprocess,tempfile
from pathlib import Path
import build_terrain_query_reference as query
from extract_ship_registry import Image

EXTRA_PROCEDURES=[581,1341,1466,1502,1523,1669]
OUTPUT_KEYS=['collision_status','altitude_low_u32','altitude_high_i32','recorded_intersection_raw','pending_query_flag','terrain_query_calls']
START = r"""_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:input
 add rsi,r8
 mov edx,20
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,20
 jne read_more
 mov eax,DWORD PTR [input]
 imul eax,24
 lea ebx,[rax+model_table]
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [object+0xa0],eax
 mov eax,DWORD PTR [input+8]
 mov DWORD PTR [collinfo],eax
 mov eax,DWORD PTR [input+12]
 mov DWORD PTR [collinfo+4],eax
 mov eax,DWORD PTR [input+16]
 mov DWORD PTR [collinfo+8],eax
 mov eax,DWORD PTR [ebx]
 mov DWORD PTR [collinfo+16],eax
 mov eax,DWORD PTR [ebx+8]
 mov DWORD PTR [collinfo+20],eax
 mov eax,DWORD PTR [ebx+12]
 mov DWORD PTR [collinfo+24],eax
 mov eax,DWORD PTR [ebx+16]
 mov DWORD PTR [object+0x138],eax
 mov eax,DWORD PTR [ebx+20]
 mov DWORD PTR [object+0x13c],eax
 mov DWORD PTR [object+0x140],0
 mov DWORD PTR [object+0x144],0
 mov DWORD PTR [DATA_008812],1
 mov DWORD PTR [query_count],0
 mov DWORD PTR [rval],-999
 push OFFSET FLAT:collinfo
 push 0
 push OFFSET FLAT:object
 mov eax,DWORD PTR [ebx+4]
 push rax
 push OFFSET FLAT:rval
 call FUNC_000581
 add rsp,40
 mov eax,DWORD PTR [rval]
 mov DWORD PTR [output],eax
 mov eax,DWORD PTR [DATA_008703]
 mov DWORD PTR [output+4],eax
 mov eax,DWORD PTR [DATA_008704]
 mov DWORD PTR [output+8],eax
 mov eax,DWORD PTR [DATA_009283]
 mov DWORD PTR [output+12],eax
 mov eax,DWORD PTR [DATA_009284]
 mov DWORD PTR [output+16],eax
 mov eax,DWORD PTR [query_count]
 mov DWORD PTR [output+20],eax
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,80
 syscall
 jmp next_case
finished:
 mov eax,60
 xor edi,edi
 syscall
FUNC_001876:
 push rax
 push rcx
 push rsi
 push rdi
 inc DWORD PTR [query_count]
 mov esi,DWORD PTR [rsp+32+56]
 mov edi,OFFSET FLAT:output+24
 mov ecx,9
 rep movsd
 mov esi,DWORD PTR [rsp+32+48]
 mov edi,OFFSET FLAT:output+60
 mov ecx,3
 rep movsd
 mov eax,DWORD PTR [rsp+32+64]
 mov DWORD PTR [output+72],eax
 mov eax,DWORD PTR [rsp+32+16]
 mov DWORD PTR [output+76],eax
 pop rdi
 pop rsi
 pop rcx
 pop rax
 jmp OriginalTerrainQuery
_abs:
 mov eax,DWORD PTR [rsp+8]
 cdq
 xor eax,edx
 sub eax,edx
 ret
"""


def model_data(executable, model_ids=None, largest_axis_probes=False):
 image=Image(executable);models={};assembly=['.section .data','DATA_007738: .quad FUNC_001502']
 for slot,index in enumerate([119,125,129,133] if model_ids is None else model_ids):
  descriptor=image.pointer(0xba8fc+index*4,68);fields=struct.unpack_from('<17I',executable,descriptor)
  vertices=image.offset(fields[1],24);collision=image.offset(fields[13],6)
  if executable[collision] != 16 or executable[collision+1] not in [0x82,0x83] or executable[collision+2] != 255:raise ValueError('Unexpected source terrain collision record')
  end=collision+9
  while struct.unpack_from('<H',executable,end)[0]:
   end+=16
   if end>collision+4096:raise ValueError('Unbounded source terrain feature list')
  raw_vertices=executable[vertices:vertices+24];raw_payload=executable[collision+3:end+2]
  if raw_payload[:4] != bytes([6,2,4,0]):raise ValueError('Source planet basis changed')
  axis=abs(struct.unpack_from('<b',raw_vertices,2)[0])
  axes=[struct.unpack_from('<b',raw_vertices,offset)[0] for offset in [2,15,10]]
  if largest_axis_probes:axis=max(abs(value) for value in axes)
  radius=axis<<14
  zoom=fields[5]+fields[6];scale=zoom-14
  upper_bound=(radius*4)<<scale
  row={'model_index':index,'slot':slot,'descriptor_offset':hex(descriptor),'descriptor_sha256':hashlib.sha256(executable[descriptor:descriptor+68]).hexdigest(),'vertices_offset':hex(vertices),'vertices_hex':raw_vertices.hex(),'vertices_sha256':hashlib.sha256(raw_vertices).hexdigest(),'collision_stream_offset':hex(collision),'collision_payload_offset':hex(collision+3),'collision_payload_hex':raw_payload.hex(),'collision_payload_sha256':hashlib.sha256(raw_payload).hexdigest(),'terrain_style_raw':struct.unpack_from('<H',raw_payload,4)[0],'mesh_zoom':zoom,'vector_scale':scale,'terrain_radius_parameter_raw':radius,'synthetic_outer_bound_raw_u64':upper_bound}
  if model_ids is not None:
   row.update(collision_stream_prefix_hex=executable[collision:collision+3].hex(),static_axis_vertices_raw=axes,probe_radius_axis_rule='largest_absolute_static_axis' if largest_axis_probes else 'absolute_first_static_x_axis')
  models[str(index)]=row
  assembly += [f'vertices{slot}:','.byte '+','.join(str(v) for v in raw_vertices),f'payload{slot}:','.byte '+','.join(str(v) for v in raw_payload)]
 assembly.append('model_table:')
 for row in models.values():
  slot=row['slot'];upper=row['synthetic_outer_bound_raw_u64']
  assembly.append(f".long vertices{slot},payload{slot},{row['mesh_zoom']},{row['vector_scale']},{upper&0xffffffff},{upper>>32}")
 return models,assembly


def cases_for(models):
 cases=[]
 directions=[[0,0,1],[0,0,-1],[0,1,0],[0,-1,0],[1,0,0],[-1,0,0],[.3,.7,.8],[.7,-.4,.6],[-.5,-.6,-.7],[.0889442089999,.915405324379,.392583774225]]
 for row in models.values():
  for seed in [1,0x12345678,0x0abc1234]:
   for direction_index,direction in enumerate(directions):
    norm=math.sqrt(sum(v*v for v in direction))
    point=[round(v/norm*row['terrain_radius_parameter_raw']*1.1) for v in direction]
    cases.append({'model_index':row['model_index'],'model_slot':row['slot'],'seed':seed,'observer_model_local_raw':point,'mesh_zoom':row['mesh_zoom'],'vector_scale':row['vector_scale'],'direction_probe_index':direction_index})
 return cases


def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('source',type=Path);parser.add_argument('executable',type=Path);parser.add_argument('--data-source',type=Path);parser.add_argument('--project',type=Path,default=Path(__file__).resolve().parents[1]);parser.add_argument('--fixture-name',default='terrain_game_query_reference.json');parser.add_argument('--model-ids');parser.add_argument('--largest-axis-probes',action='store_true');args=parser.parse_args()
 source=args.source.read_text();data=(args.data_source or args.source.with_name('ffedat.asm')).read_text();executable=args.executable.read_bytes()
 old_numbers=query.NUMBERS;old_frames=query.WIDENED_FRAMES
 try:
  query.NUMBERS=old_numbers+EXTRA_PROCEDURES;query.WIDENED_FRAMES=old_frames+[1669]
  hashes=query.function_hashes(source);assembly,resources=query.adapt_assembly(source,data,executable)
 finally:query.NUMBERS=old_numbers;query.WIDENED_FRAMES=old_frames
 model_ids=None if args.model_ids is None else [int(value,0) for value in args.model_ids.split(',')]
 models,model_assembly=model_data(executable,model_ids,args.largest_axis_probes)
 assembly=assembly.replace('FUNC_001876:','OriginalTerrainQuery:')
 begin=assembly.index('_start:');end=assembly.index('.section .bss',begin)
 assembly=assembly[:begin]+START+'\n'+'\n'.join(model_assembly)+'\n'+assembly[end:]
 assembly=assembly.replace('input: .zero 56','input: .zero 20').replace('output: .zero 24','output: .zero 80\ncollinfo: .zero 28\nrval:.zero 4\nquery_count:.zero 4')
 cases=cases_for(models);ordered=cases+list(reversed(cases))
 payload=b''.join(struct.pack('<5I',row['model_slot'],row['seed'],*(v&0xffffffff for v in row['observer_model_local_raw'])) for row in ordered)
 with tempfile.TemporaryDirectory(prefix='ffe-terrain-game-query-') as directory:
  work=Path(directory);(work/'query.s').write_text(assembly)
  subprocess.run(['as','--64',str(work/'query.s'),'-o',str(work/'query.o')],check=True)
  undefined=subprocess.check_output(['nm','-u',str(work/'query.o')],text=True)
  adapter,adapter_metadata=query.unresolved_adapter(undefined,data);(work/'excluded.s').write_text(adapter)
  subprocess.run(['as','--64',str(work/'excluded.s'),'-o',str(work/'excluded.o')],check=True)
  subprocess.run(['ld','-m','elf_x86_64',str(work/'query.o'),str(work/'excluded.o'),'-o',str(work/'query')],check=True)
  output=subprocess.run([str(work/'query')],input=payload,capture_output=True,check=True,timeout=30).stdout
  fresh=subprocess.run([str(work/'query')],input=payload,capture_output=True,check=True,timeout=30).stdout
 if output!=fresh or len(output)!=80*len(ordered):raise ValueError('Original F581 queries did not reproduce completely')
 for index,row in enumerate(cases):
  values=struct.unpack_from('<20i',output,index*80)
  if values!=struct.unpack_from('<20i',output,(len(ordered)-1-index)*80):raise ValueError('F581 result depends on earlier query order')
  if values[5]!=1 or values[4]!=0:raise ValueError('Source F581 skipped or did not finish the terrain query')
  result=dict(zip(OUTPUT_KEYS,values[:6]));result['altitude_low_u32']&=0xffffffff
  result.update(query_matrix_raw=list(values[6:15]),query_center_raw=list(values[15:18]),query_style_raw=values[18],query_limit_raw=values[19])
  result['altitude_raw_i64']=(values[2]<<32)+(values[1]&0xffffffff)
  row['result']=result
 report={'schema':1,'revision':'terrain-game-query-raw-v1','scope':'Actual original F581 collision caller followed by original F1876 query mode 1, original model vertices/collision stream/features and integer frame/altitude math. Raw model-local observer points only. Synthetic broad outer bounds and zero inner bound force entry into the terrain branch; they do not replace geometry. POSIX abs is adapted for the host ABI. No latitude/longitude, SI-unit scale, planetary spin or live Android terrain claim.','source_sha256':hashlib.sha256(executable).hexdigest(),'source_procedure_hashes':hashes,'assembly_sha256':hashlib.sha256(assembly.encode()).hexdigest(),'unreached_adapter_sha256':hashlib.sha256(adapter.encode()).hexdigest(),'original_resources':resources,'host_adapter':adapter_metadata,'models':models,'case_count':len(cases),'same_process_interleaved_repeat_checks':len(cases),'fresh_process_reproduction_verified':True,'query_mode':1,'real_model_feature_lists':True,'source_seed_probes':[1,0x12345678,0x0abc1234],'earth_explicit_source_uid_probe':0x0abc1234,'cases':cases}
 output_file=args.project/'tests/fixtures'/args.fixture_name;output_file.parent.mkdir(parents=True,exist_ok=True);output_file.write_text(json.dumps(report,separators=(',',':'))+'\n')
 print('Original F581→F1876 queries:',len(cases),'models:',list(models),'interleaved repeats:',len(cases))


if __name__=='__main__':main()
