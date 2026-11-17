#!/usr/bin/env python3
"""Native F575 -> F576/F579 -> F582/F583/F580 composition on real programs.

Python transports actual native results at the existing observed boundaries;
it never computes expected collision arithmetic. Damage replies are explicit
identity observations. This cohort uses real non-terrain model programs.
"""
from __future__ import annotations
import argparse,copy,hashlib,json,struct,subprocess,tempfile
from pathlib import Path
import rebuild_source_contact_classifier_native as C
import rebuild_source_collision_geometry_native as G
import rebuild_source_collision_program_native as V
import rebuild_source_collision_planes_native as P
import rebuild_source_collision_transform_native as T

PROJECT=C.PROJECT
PROOF=PROJECT/'validation/collision-programs-2026-11-17/contact-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_collision_contact_native.json'
CATALOG='data/ffe_collision_programs.json'
PROFILE='dos-firstenc-geometry-contact-composition-v1'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def model_for_vm(resource):
 return {'descriptor_hex':resource['descriptor_hex'],'normals_hex':resource['normals_hex'],'vertices_hex':resource['vertices_hex'],'collision_program_hex':resource['collision_program_hex'],'normal_origin_u32':resource['normals_origin_u32'],'vertex_origin_u32':resource['vertices_origin_u32']}
def closure(models,root):
 selected={};todo=[root]
 while todo:
  index=todo.pop()
  if str(index)in selected:continue
  resource=models[str(index)]
  if index>255 or any(len(bytes.fromhex(resource[k]))>n for k,n in [('collision_program_hex',V.PROG),('normals_hex',V.BUF),('vertices_hex',V.BUF)]):raise ValueError('Composition model exceeds declared native transport')
  selected[str(index)]=model_for_vm(resource);todo.extend(resource['nested_model_indices'])
 if len(selected)>V.MODELS:raise ValueError('Nested model transport limit exceeded')
 return selected
def observation_context(value):return {'body':value['body_hex'],'collider':value['collider_hex'],'relative':value['relative_hex'],'globals':value['globals']}
def observations(expected):
 return [{**{k:v for k,v in row.items()if k not in ['before','after']},'before':observation_context(row['before']),'after':observation_context(row['after'])}for row in expected['observations']if row['kind']!='F576']
def compile_native(folder,name,text):
 (folder/(name+'.s')).write_text(text)
 subprocess.run(['as','--64','-o',str(folder/(name+'.o')),str(folder/(name+'.s'))],check=True,capture_output=True)
 subprocess.run(['ld','-o',str(folder/name),str(folder/(name+'.o'))],check=True,capture_output=True)
 return folder/name
def initial_cases(models):
 factory=json.loads((PROJECT/'tests/fixtures/source_object_factory_native.json').read_text())
 seeds={int(row['model_index_u32']):bytes.fromhex(row['expected_body_hex'])for row in factory['cases']if row['name'].startswith('real-model')and row['name'].endswith('-inplace')}
 parents=[15,19,21,24,26,38,62,64,70,76,80];rows=[]
 identity=(0x7fffffff,0,0,0,0x7fffffff,0,0,0,0x7fffffff)
 rotate=(0,0,-0x7fffffff,0,0x7fffffff,0,0x7fffffff,0,0)
 for i in range(32):
  parent=parents[i%len(parents)];own=[15,24,38][i%3]
  if own==parent:own=38 if parent!=38 else 15
  body=bytearray(seeds[own]);collider=bytearray(seeds[parent])
  body[0x86]=114;collider[0x86]=37;body[0x87]=[3,11,14][i%3];collider[0x87]=3
  body[0x56]=37 if i%3 else 0;collider[0x56]=0;body[0x57]=i%2;collider[0x57]=0
  struct.pack_into('<9i',body,0,*identity);struct.pack_into('<9i',collider,0,*(rotate if i%4==1 else identity))
  struct.pack_into('<3i',body,0x8c,*[(0,0,0),(120,-200,300),(-600,10,-20)][i%3]);struct.pack_into('<3i',collider,0x8c,20,30,-40)
  struct.pack_into('<H',body,0x9e,0xffff)
  outer=struct.unpack_from('<q',collider,0x138)[0]
  # These are authored source-space poses, not expected contact arithmetic.
  position=[(0,0,0),(1,-1,1),(outer//4,outer//8,-outer//16),(outer,-outer//4,0)][i%4]
  struct.pack_into('<3q',body,0x3e,*position);struct.pack_into('<3q',collider,0x3e,0,0,0)
  # Actual source equipment words decide the original nested-record condition.
  struct.pack_into('<H',collider,0x9c+23*2,0 if i%2 else 0x2000)
  globals={name:0 for name,_,_ in C.FIELDS};globals.update(player_index_u32=114 if i%2 else 17,collision_enabled_u8=[0,1,255][i%3],altitude_low_u32=0xffffffff,collider_ref_u32=37)
  rows.append({'name':'actual-program-contact/%02d'%i,'body_hex':body.hex(),'collider_hex':collider.hex(),'relative_hex':struct.pack('<3q',*position).hex(),'globals_before':globals,'own_model_u32':own,'collider_model_u32':parent})
 return rows

def generate(a):
 catalog_raw=(PROJECT/CATALOG).read_bytes();catalog=json.loads(catalog_raw);models=catalog['models']
 cm=json.loads((C.PROOF/'instruction-proof.json').read_text());cs=(C.PROOF/'source-procedures.asm').read_text();C.verify_archived(cm,cs)
 gm=json.loads((G.PROOF/'instruction-proof.json').read_text());gs=(G.PROOF/'source-procedures.asm').read_text();G.verify_archived(gm,gs)
 vm,vs=V.verify(V.PROOF);pm,ps=P.verify(P.PROOF);tm,ts=T.verify(T.PROOF)
 assemblies={'classifier':C.assembly(cs),'geometry':G.assembly(gs),'program':V.assembly(vs,ps,ts)}
 records={k:[]for k in assemblies};rows=initial_cases(models)
 with tempfile.TemporaryDirectory(prefix='native-program-contact-')as directory:
  folder=Path(directory);binaries={k:compile_native(folder,k,v)for k,v in assemblies.items()}
  def execute(kind,packet,size):
   outputs=[subprocess.run([str(binaries[kind])],input=packet,capture_output=True,check=True,timeout=30).stdout for _ in range(3)]
   if len(set(outputs))!=1 or len(outputs[0])!=size:raise ValueError('Native execution length/repeat differs '+kind)
   records[kind].append((packet,outputs[0]));return outputs[0]
  for row in rows:
   own=row['own_model_u32'];parent=row['collider_model_u32'];nested=closure(models,parent)
   for mid in [own,parent]:
    if models[str(mid)]['descriptor_hex']!=cm['models'][str(mid)]['descriptor_hex']:raise ValueError('Actual descriptor identity differs between native kernels')
   classifier={'name':row['name'],'body_before_hex':row['body_hex'],'collider_before_hex':row['collider_hex'],'relative_before_hex':row['relative_hex'],'globals_before':row['globals_before'],'scripts':[{'return_u32':0,'globals':{}}for _ in range(C.MAXOBS)]}
   first=C.decode(execute('classifier',C.packet(classifier,cm['models']),C.OUTPUT),classifier)
   boundaries=[(i,o)for i,o in enumerate(first['observations'])if o['kind']=='F576']
   if len(boundaries)!=1:raise ValueError('Composition must reach exactly one actual F576 boundary '+row['name'])
   boundary_index,boundary=boundaries[0];before=boundary['before']
   front={'name':row['name']+'/F576','body_hex':before['body_hex'],'collider_hex':before['collider_hex'],'relative_hex':before['relative_hex'],'globals_before':{name:before['globals'][name]for name,_,_ in G.FIELDS},'resources':{str(own):copy.deepcopy(models[str(own)]),str(parent):copy.deepcopy(models[str(parent)])},'scripts':[]}
   program_calls=[]
   for iteration in range(G.MAXCALLS+1):
    result=G.decode(execute('geometry',G.packet(front),G.OUTPUT),front)
    if len(front['scripts'])==len(result['calls']):break
    if len(front['scripts'])>len(result['calls']):raise ValueError('A native continuation erased earlier F582 calls')
    call=result['calls'][len(front['scripts'])];resource=models[str(parent)]
    context={k:call[k]for k in ['point_xyz_s32','mesh_zoom_s32','vector_scale_s32']}
    context.update(normals_hex=resource['normals_hex'],vertices_hex=resource['vertices_hex'],normal_origin_u32=resource['normals_origin_u32'],vertex_origin_u32=resource['vertices_origin_u32'])
    program={'name':row['name']+'/F582-%02d'%len(front['scripts']),'body_before_hex':front['collider_hex'],'program_hex':resource['collision_program_hex'],'context':context,'threshold_s32':call['threshold_s32'],'globals_before':call['globals_before'],'primitive_u8_before':0,'resources':nested,'terrain_scripts':[]}
    actual=V.decode(execute('program',V.packet(program),V.OUTPUT),program)
    if actual['observations']:raise ValueError('This real non-terrain cohort must not invent F581 answers')
    front['scripts'].append({'return_s32':actual['return_s8'],'primitive_u8':actual['primitive_u8'],'globals_after':actual['globals_after']})
    program_calls.append({'input':program,'expected':actual})
   else:raise ValueError('Native F576 callback transport limit exceeded')
   for call,program_call in zip(result['calls'],program_calls):
    actual=program_call['expected']
    if call['return_s32']!=actual['return_s8']or call['primitive_u8']!=actual['primitive_u8']or call['globals_after']!=actual['globals_after']:raise ValueError('Actual VM result was not resumed exactly inside F576')
   after=dict(result['globals_after']);after['player_index_u32']=before['globals']['player_index_u32']
   classifier['scripts'][boundary_index]={'return_u32':result['return_s32']&0xffffffff,'globals':after}
   final=C.decode(execute('classifier',C.packet(classifier,cm['models']),C.OUTPUT),classifier)
   resumed=next(o for o in final['observations']if o['kind']=='F576')
   if resumed['after']['globals']!=after or resumed['return_u32']!=(result['return_s32']&0xffffffff):raise ValueError('Actual F576 result was not resumed exactly inside F575')
   row['observations']=observations(final);row['geometry_observations']=[];row['expected']=final;row['geometry_expected']=result;row['program_calls']=program_calls
  for kind,items in records.items():
   raw=subprocess.run([str(binaries[kind])],input=b''.join(packet for packet,_ in reversed(items)),capture_output=True,check=True,timeout=60).stdout
   if raw!=b''.join(output for _,output in reversed(items)):raise ValueError('Native reverse order mismatch '+kind)
 paths=['tools/rebuild_source_collision_contact_native.py','tools/rebuild_source_contact_classifier_native.py','tools/rebuild_source_collision_geometry_native.py','tools/rebuild_source_collision_program_native.py','tools/rebuild_source_collision_planes_native.py','tools/rebuild_source_collision_transform_native.py','tools/rebuild_source_surface_contact_native.py','tools/rebuild_source_spherical_contact_native.py','tools/rebuild_source_natural_contact_native.py','tools/rebuild_source_frame_dispatch_native.py','recovered-history/ground_harness/tools/native_reference.py','tests/fixtures/source_object_factory_native.json',CATALOG]
 for directory in [C.PROOF,G.PROOF,V.PROOF,P.PROOF,T.PROOF]:
  paths.extend(str(p.relative_to(PROJECT))for p in directory.iterdir()if p.name in ['instruction-proof.json','source-procedures.asm','source-procedures.s'])
 pins={p:sha((PROJECT/p).read_bytes())for p in sorted(set(paths))}
 proof={'schema':'starfrontier-original-program-contact-composition-v1','source_executable_sha256':C.C.EXE_SHA,'source_assembly_sha256':C.C.ASM_SHA,'collision_resource_sha256':sha(catalog_raw),'source_dependencies_sha256':pins,'host_assembly_sha256':{k:sha(v.encode())for k,v in assemblies.items()},'fresh_process_runs_each_call':3,'reverse_repeat_native_calls':{k:len(v)for k,v in records.items()},'native_calls':{k:len(v)for k,v in records.items()},'native_input_sha256':{k:sha(b''.join(p for p,_ in v))for k,v in records.items()},'native_output_sha256':{k:sha(b''.join(o for _,o in v))for k,v in records.items()},'expected_arithmetic_calculated_in_python':False,'all_raw_canaries_verified':True,'F581_terrain_answers_invented':False,'F953_policy':'Explicit matched identity observations; authoritative damage/world engine is not executed.','scope':'Whole original F575 resumes actual original F576/F579, whose F582 callbacks resume actual F582/F583/F580 on original collision resources. Full raw results, global words and caller vectors are compared. Authored source-space pose/identity follows independently native F1533 records. This non-terrain cohort does not implement F581, damage engine, live Main or physical Android.'}
 proof['actual_nested_F580_calls']=sum(p['expected']['source_order'].count('F580')for row in rows for p in row['program_calls'])
 proof['actual_plane_F583_calls']=sum(p['expected']['source_order'].count('F583')for row in rows for p in row['program_calls'])
 proof['matched_F953_identity_observations']=sum(len(row['observations'])for row in rows)
 a.proof_dir.mkdir(parents=True,exist_ok=True)
 for name,text in assemblies.items():(a.proof_dir/(name+'-composed-native.s')).write_text(text)
 (a.proof_dir/'composition-proof.json').write_text(json.dumps(proof,indent=2)+'\n')
 fixture={'schema':'starfrontier-source-collision-contact-native-v1','profile':PROFILE,'case_count':len(rows),'actual_F576_calls':len(rows),'actual_F582_calls':sum(len(r['program_calls'])for r in rows),'proof':proof,'cases':rows,'scope':proof['scope']}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(fixture,indent=2)+'\n')
 print(json.dumps({'case_count':len(rows),'actual_F582_calls':fixture['actual_F582_calls'],'native_calls':proof['native_calls'],'fixture_sha256':sha(a.output.read_bytes())},indent=2))
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--proof-dir',type=Path,default=PROOF)
 for name in ['exe','asm','data']:p.add_argument('--'+name,type=Path)
 generate(p.parse_args())
if __name__=='__main__':main()
