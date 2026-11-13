#!/usr/bin/env python3
"""Original native contact-field witnesses; no Python expected-height arithmetic.

Original archived F576/F579/F582/F581/F1876 instructions and resources are reused.
The sole added F581 wrapper observes its actual context and query state while
preserving registers/flags. Original player and parent buffers are immutable.
Geometry-only model117 exclusions use explicitly enlarged bounds, separately
from all three canonical positive-player classifiers with original bounds.
"""
from __future__ import annotations
import argparse,hashlib,json,struct,subprocess,sys,tempfile
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[3]
PROOF=Path(__file__).resolve().parent
sys.path.insert(0,str(PROJECT/'tools'))
import rebuild_source_natural_contact_native as N
ORIGINAL=PROJECT/'validation/natural-2026-11-13/nativeproof'
MASK=0xffffffff

def sha(raw):return hashlib.sha256(raw).hexdigest()
def encode64(value):return struct.pack('<q',value).hex()
def point_hex(point):return struct.pack('<3q',*point).hex()
def ray_point(direction,radius):return [(int(value)*int(radius))>>31 for value in direction]

def build(work):
 source=(ORIGINAL/'natural-native.s').read_text()
 source=source.replace('FUNC_000581:','RootOriginalF581:',1)
 source+='\n.section .text\n'+OBSERVE_F581
 (work/'root.s').write_text(source)
 for stem,path in [('root',work/'root.s'),('canonical',ORIGINAL/'natural-native.s'),('excluded',ORIGINAL/'excluded-native.s')]:
  subprocess.run(['as','--64',str(path),'-o',str(work/(stem+'.o'))],check=True)
 for stem in ['root','canonical']:
  subprocess.run(['ld','-m','elf_x86_64',str(work/(stem+'.o')),str(work/'excluded.o'),'-o',str(work/stem)],check=True)
 return source

OBSERVE_F581=r'''FUNC_000581:
 push rbp
 mov rbp,rsp
 push rax
 push rdx
 pushfq
 mov edx,DWORD PTR [rbp+48]
 mov eax,DWORD PTR [edx+24]
 mov DWORD PTR [output_full+960],eax
 mov eax,DWORD PTR [edx]
 mov DWORD PTR [output_full+964],eax
 mov eax,DWORD PTR [edx+4]
 mov DWORD PTR [output_full+968],eax
 mov eax,DWORD PTR [edx+8]
 mov DWORD PTR [output_full+972],eax
 popfq
 pop rdx
 pop rax
 push QWORD PTR [rbp+48]
 push QWORD PTR [rbp+40]
 push QWORD PTR [rbp+32]
 push QWORD PTR [rbp+24]
 push QWORD PTR [rbp+16]
 call RootOriginalF581
 lea rsp,[rsp+40]
 pushfq
 push rax
 push rdx
 mov eax,DWORD PTR [DATA_009269]
 mov DWORD PTR [output_full+976],eax
 mov eax,DWORD PTR [DATA_009273]
 mov DWORD PTR [output_full+980],eax
 mov edx,DWORD PTR [rbp+16]
 mov eax,DWORD PTR [edx]
 mov DWORD PTR [output_full+984],eax
 movzx eax,BYTE PTR [DATA_008707]
 mov DWORD PTR [output_full+988],eax
 pop rdx
 pop rax
 popfq
 pop rbp
 ret
'''

def execute(binary,rows,reproduce=True):
 ordered=rows+list(reversed(rows)) if reproduce else rows
 payload=b''.join(N.packet(row)for row in ordered);outputs=[]
 for _ in range(3 if reproduce else 1):
  result=subprocess.run([str(binary)],input=payload,capture_output=True,timeout=120)
  if result.returncode:raise RuntimeError('Native failed status%d after%d cases'%(result.returncode,len(result.stdout)//N.OUTPUT))
  if len(result.stdout)!=len(ordered)*N.OUTPUT:raise ValueError('Incomplete native output')
  outputs.append(result.stdout)
 if any(raw!=outputs[0]for raw in outputs[1:]):raise ValueError('Fresh-process discrepancy')
 if reproduce:
  for index,row in enumerate(rows):
   if outputs[0][index*N.OUTPUT:(index+1)*N.OUTPUT]!=outputs[0][(len(ordered)-1-index)*N.OUTPUT:(len(ordered)-index)*N.OUTPUT]:raise ValueError('Order/repeat discrepancy '+row['id'])
 return outputs[0]

def expected_geometry(raw,row):
 observed=N.decode(raw);g=observed['globals'];scale,x,y,z,depth,vertices,status,kind=struct.unpack_from('<8i',raw,960)
 if observed['terrain_query_calls']!=1 or observed['f579_calls']!=1:raise ValueError('Geometry witness did not execute exactly one original terrain query '+row['id'])
 previous=int(g['previous_altitude_low_u32'])+(int(g['previous_altitude_high_s32'])<<32)
 if observed['player_hex']!=row['player_object_hex']or observed['parent_hex']!=row['parent_object_hex']or observed['relative_after_hex']!=row['relative_before_hex']:raise ValueError('Native caller buffer mutated')
 return {'query_result_s32':int(g['recorded_intersection_raw']),'residual_s64_hex':encode64(previous),'residual_raw_s64':str(previous),'vector_scale_s32':scale,'observer_model_local_raw':[x,y,z],'recorded_intersection_raw':int(g['recorded_intersection_raw']),'pending_query_flag':int(g['pending_query_flag']),'terrain_query_calls':observed['terrain_query_calls'],'native_f581_status_s32':status,'collision_kind_u8':kind,'depth_control_raw':depth,'vertex_pool_count':vertices}

def template(anchor,players,parents,ship,geometry=False):
 model=int(anchor['model_index']);body=bytearray.fromhex(players[ship]);parent=bytearray.fromhex(parents[model]);record=bytes.fromhex(anchor['source_record_hex'])
 for index,value in enumerate(anchor['bodyorientation_q31']):struct.pack_into('<i',body,index*4,int(value))
 for index in range(9):struct.pack_into('<i',parent,index*4,0x7fffffff if index in [0,4,8]else 0)
 parent[0x86]=1;struct.pack_into('<I',parent,0xa0,struct.unpack_from('<I',record,4)[0]);body[0x86]=2;body[0x56]=1;body[0x57]=1
 original=bytes(parent);policy='original_parent_bounds'
 if geometry and not anchor['result']['source_bounds']['terrain_query_eligible']:
  if model!=117:raise ValueError('Unexpected geometry coarse-gate exclusion outside model117')
  # Explicit geometry-only context: full original F581 still executes its own
  # gates. A nonnegative small inner and positive signed32 outer after scaling
  # admit the root region. Canonical F576 cases NEVER use this override.
  scale=int(next(s['vector_scale_s32']for s in anchor['result']['query_trace']if int(s['ray_radius_raw'])==int(anchor['result']['ray_radius_raw'])))
  struct.pack_into('<q',parent,0x138,0x3fffffff<<scale);struct.pack_into('<q',parent,0x140,0)
  policy='model117_geometry_only_expanded_bounds'
 return {'player_object_hex':body.hex(),'parent_object_hex':parent.hex(),'relative_before_hex':point_hex(anchor['result']['position_raw']),'context':{'graphics_level':1,'initial_globals':{key:0 for key,_,_ in N.GLOBAL_FIELDS}}},original.hex(),policy

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--candidates',type=Path,default=PROOF/'field-candidate-inputs.json');parser.add_argument('--work',type=Path);args=parser.parse_args()
 work=args.work or Path(tempfile.mkdtemp(prefix='source-contact-field-native-'));work.mkdir(parents=True,exist_ok=True)
 candidate_raw=args.candidates.read_bytes();candidates=json.loads(candidate_raw)['rows']
 old_raw=(PROJECT/'tests/fixtures/source_natural_contact_native.json').read_bytes();old=json.loads(old_raw)
 players={mid:next(row['player_object_hex']for row in old['cases']if row['player_model']==mid)for mid in [24,38,15]}
 parents={mid:next(row['parent_object_hex']for row in old['cases']if row['parent_model']==mid)for mid in range(117,134)}
 assembly=build(work);geometry=[];classifiers=[];anchors=[];witness_selection_queries=0
 for anchor in candidates:
  if not anchor['result'].get('ok')or not anchor['result'].get('certified'):raise ValueError('Uncertified candidate '+anchor['id'])
  result=anchor['result'];radius=int(result['ray_radius_raw']);direction=[int(v)for v in anchor['radial_q31']]
  base,parent_original,policy=template(anchor,players,parents,24,True)
  final=dict(base);final.update(id=anchor['id']+'/final',anchor_id=anchor['id'],model_index=int(anchor['model_index']),role='final',source_record_hex=anchor['source_record_hex'],radial_q31=direction,ray_radius_raw=radius,original_parent_object_hex=parent_original,geometry_parent_object_hex=base['parent_object_hex'],geometry_bounds_policy=policy,point_hex=base['relative_before_hex'])
  geometry.append(final)
  supplied=result.get('bracket',{})
  for role,sign in [('inside',-1),('outside',1)]:
   selected=None;origin='field_certified_bracket'
   if supplied:
    sample=supplied[role];selected=dict(base);selected['relative_before_hex']=sample['point_hex'];witness_radius=int(sample['ray_radius_raw'])
    observed=expected_geometry(execute(work/'root',[dict(selected,id='witness_probe')],False),dict(selected,id='witness_probe'));witness_selection_queries+=1
    if sign*int(observed['residual_raw_s64'])<=0:raise ValueError('Supplied field bracket sign disagrees with native '+anchor['id'])
   else:
    origin='independent_native_signed_neighbor_search';step=1
    for attempt in range(16):
     witness_radius=radius+sign*step;selected=dict(base);selected['relative_before_hex']=point_hex(ray_point(direction,witness_radius))
     observed=expected_geometry(execute(work/'root',[dict(selected,id='witness_probe')],False),dict(selected,id='witness_probe'));witness_selection_queries+=1
     if sign*int(observed['residual_raw_s64'])>0:break
     step*=2
    else:raise ValueError('No bounded native signed witness '+anchor['id']+'/'+role)
   selected.update(id=anchor['id']+'/'+role,anchor_id=anchor['id'],model_index=int(anchor['model_index']),role=role,source_record_hex=anchor['source_record_hex'],radial_q31=direction,ray_radius_raw=witness_radius,original_parent_object_hex=parent_original,geometry_parent_object_hex=base['parent_object_hex'],geometry_bounds_policy=policy,point_hex=selected['relative_before_hex'],witness_selection=origin)
   geometry.append(selected)
  anchors.append({'id':anchor['id'],'model_index':int(anchor['model_index']),'anchor':anchor['anchor'],'source_record_hex':anchor['source_record_hex'],'radial_q31':direction,'bodyorientation_q31':anchor['bodyorientation_q31'],'latitude':anchor['latitude'],'longitude':anchor['longitude'],'certified_status':result['status'],'field_query_count':int(result['query_count']),'final_point_hex':final['point_hex'],'final_ray_radius_raw':radius,'field_claimed_residual_s64_hex':encode64(int(result['residual_raw_s64'])),'source_bounds':result['source_bounds'],'seed':result['seed'],'height_policy':result['height_policy'],'field_contract':result['source_contract']})
  for ship in [24,38,15]:
   classifier,_,_=template(anchor,players,parents,ship,False);inner=struct.unpack_from('<q',bytes.fromhex(classifier['player_object_hex']),0x140)[0]
   for role,point in [('final',result['position_raw']),('native_inner_clearance',ray_point(direction,radius+inner))]:
    row=json.loads(json.dumps(classifier));row.update(id=anchor['id']+f'/ship{ship}/'+role,anchor_id=anchor['id'],parent_model=int(anchor['model_index']),player_model=ship,role=role,source_record_hex=anchor['source_record_hex'],relative_before_hex=point_hex(point),raw_inner_s64=inner,ray_radius_raw=radius+(inner if role=='native_inner_clearance'else 0))
    row['context']['initial_globals']=N.globals_for(len(classifiers));classifiers.append(row)
 geometry_output=execute(work/'root',geometry)
 for index,row in enumerate(geometry):row['expected']=expected_geometry(geometry_output[index*N.OUTPUT:(index+1)*N.OUTPUT],row)
 for anchor in anchors:
  native=next(row for row in geometry if row['anchor_id']==anchor['id']and row['role']=='final')['expected']
  if anchor['field_claimed_residual_s64_hex']!=native['residual_s64_hex']:raise ValueError('Field final residual differs from native '+anchor['id'])
  endpoint={role:next(row for row in geometry if row['anchor_id']==anchor['id']and row['role']==role)for role in ['inside','outside']}
  if int(endpoint['inside']['expected']['residual_raw_s64'])>=0 or int(endpoint['outside']['expected']['residual_raw_s64'])<=0:raise ValueError('Native bracket signs invalid')
  anchor['native_witness_bracket_width_raw']=endpoint['outside']['ray_radius_raw']-endpoint['inside']['ray_radius_raw']
 classifier_output=execute(work/'canonical',classifiers)
 for index,row in enumerate(classifiers):
  expected=N.decode(classifier_output[index*N.OUTPUT:(index+1)*N.OUTPUT]);row['expected']=expected
  if expected['player_hex']!=row['player_object_hex']or expected['parent_hex']!=row['parent_object_hex']or expected['relative_after_hex']!=row['relative_before_hex']:raise ValueError('Canonical source classifier mutated input')
 native_proofs=(ORIGINAL/'instruction-proofs.json').read_bytes();oldsha=sha(old_raw)
 report={'schema':1,'revision':'source-contact-field-native-v1','source_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'source_commit':N.COMMIT,'scope':'Independent original archived fullF576/F579/boundednaturalF582/F581/F1876 checks at17landablemodels×3anchors. Geometry cases use actualpositiveEagle24 and canonicalF579scale; only excluded model117axis anchors explicitly expand coarsebounds to evaluate the signedgeometryfield. Canonical classifier cases always retain actualoriginal parentbounds and actualpositiveEagle24/Cobra38/Shuttle15 radii/children. No F575response/gameplay/livev5triangle/device claim.','seed_provenance':'Immutable oldGround sampler follows pinnedJJFFE F879 SAR3; uploadedDOS F879 hasSAR4. New signedfieldpoints are certified independently by unchangedDOSF581/F1876; aplacementseed is not an asserted exact originalsurfacezero.','raw_units_policy':'All coordinate/altitude comparisons are original signedinteger rawunits. SI display conversion remains SourceUnits.METRES_PER_RAW, not rounded0.001. Three actual positive shipinnerbounds are5200/9600/1920raw, with original childstreams.','source_units_metres_per_raw_rational':{'numerator':16785,'denominator':16777216},'actual_player_inner_bounds_raw':{'24':5200,'38':9600,'15':1920},'source_units_module_sha256':sha((PROJECT/'scripts/source_units.gd').read_bytes()),'source_canonical_fixture_sha256':oldsha,'source_instruction_proofs_sha256':sha(native_proofs),'source_archived_assembly_sha256':sha((ORIGINAL/'natural-native.s').read_bytes()),'source_archived_excluded_assembly_sha256':sha((ORIGINAL/'excluded-native.s').read_bytes()),'source_candidate_inputs_sha256':sha(candidate_raw),'generator_sha256':sha(Path(__file__).read_bytes()),'observed_geometry_assembly_sha256':sha(assembly.encode()),'native_geometry_ordered_output_sha256':sha(geometry_output),'native_classifier_ordered_output_sha256':sha(classifier_output),'anchor_count':len(anchors),'model_count':17,'player_models':[24,38,15],'geometry_case_count':len(geometry),'classifier_case_count':len(classifiers),'case_count':len(geometry)+len(classifiers),'native_witness_selection_query_count':witness_selection_queries,'fresh_process_runs_per_bank':3,'geometry_reverse_repeat_count':len(geometry),'classifier_reverse_repeat_count':len(classifiers),'original_body_parent_buffers_and_canaries_unchanged':True,'python_expected_query_arithmetic':False,'geometry_exclusion_anchor_ids':[row['id']for row in anchors if not row['source_bounds']['terrain_query_eligible']],'geometry_context_policy':'Only model117coarse-gateexcluded anchors use explicitpositiveouter/zeroinner context to execute originalterrainbranch; these modified radii never enter canonical classifiercases.','anchors':anchors,'geometry_cases':geometry,'classifier_cases':classifiers}
 (PROJECT/'tests/fixtures/source_contact_field_native.json').write_text(json.dumps(report,separators=(',',':'))+'\n')
 (PROOF/'field-f581-observed-kernel.s').write_text(assembly)
 (PROOF/'summary.json').write_text(json.dumps({key:value for key,value in report.items()if key not in ['anchors','geometry_cases','classifier_cases']},indent=2)+'\n')
 print('SOURCE CONTACT FIELD NATIVE:',report['anchor_count'],'anchors;',len(geometry),'signedgeometry;',len(classifiers),'actualplayerclassifiers;3fresh+reverse;explicit117exclusions',report['geometry_exclusion_anchor_ids'],'work',work)
 print('FIXTURE SHA256',sha((PROJECT/'tests/fixtures/source_contact_field_native.json').read_bytes()))
if __name__=='__main__':main()
