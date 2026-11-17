#!/usr/bin/env python3
"""Compose original native mode, input, phase and contact kernels by raw responses.

Archived DOS instruction proofs are always used; private paths are accepted only
for portable-command parity and never read. No expected game arithmetic is Python.
"""
from __future__ import annotations
import argparse,copy,hashlib,json,random,struct,subprocess,tempfile
from pathlib import Path
import rebuild_source_player_mode_native as M
import rebuild_source_player_dispatch_native as P
import rebuild_source_player_phase_native as H
import rebuild_source_player_input_native as I
import rebuild_source_player_motion_native as T
PROJECT=M.PROJECT;PROOF=PROJECT/'validation/player-cycle-2026-11-17/cycle-native-proof';FIXTURE=PROJECT/'tests/fixtures/source_player_cycle_native.json'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def signed(raw,at):return struct.unpack_from('<i',raw,at)[0]
def word(raw,at):return struct.unpack_from('<I',raw,at)[0]
def canonical_hash(value):return sha(json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=False).encode())
def boundary_hash(value):
 e=value['external'];cells=[e['frame_ticks_u32'],e['forward_key_u8'],e['reverse_key_u8'],*e['spin_xyz_s32'],e['transfer_state_u32'],e['saved_flight_flags_u32'],e['effect_gate_s32']]
 return sha(bytes.fromhex(value['body'])+bytes.fromhex(value['root'])+struct.pack('<9I',*[v&0xffffffff for v in cells]))
def context(value):return {'body':value['body_hex'],'root':H.unpatch(value['root_patch']).hex(),'external':value['external']}
def observation(value):
 result={'kind':value['kind'],'args':value['args'],'before':context(value['before']),'after':context(value['after']),'return_u32':value['return_u32']}
 if value['kind']=='F1033':result.update(collider_body=value['collider_hex'],collider_index=value['collider_index'])
 return result

def all_external(frame,i):
 return dict(frame_ticks_u32=frame,system_frame_ticks_u32=[0,1,64,49710][i%4],speed_multiplier_u32=[16,17,255][i%3],forward_key_u8=i%2,reverse_key_u8=(i//2)%2,throttle_key_u8=i%2,aux_key1_u8=1,aux_key2_u8=1,mouse_buttons_u8=[0,0x10,0x30][i%3],input_gate_s8=-1,spin_xyz_s32=[0,0,0],transfer_state_u32=1,saved_flight_flags_u32=i%2,effect_gate_s32=0,action_a_u32=0,action_b_u32=0)
def subset(state,fields):return {key:copy.deepcopy(state[key])for key in fields}
def mode_row(core):
 return {'name':'cycle-mode','operation':'control_f1009','body_before_hex':core['body_hex'],'root_before':M.sparse(bytes.fromhex(core['root_hex'])),'externals_before':subset(core['external'],M.FIELDS),'clock':core['clock'],'native_mutations':[[255,0,0,0]],'trace':[]}
def player_globals(root,ext):
 return dict(frame_ticks_u32=ext['frame_ticks_u32'],spin_elapsed_s32=signed(root,0xdc),player_mode_u8=root[0xe8],flight_flags_u8=root[0xe9],set_speed_s32=signed(root,0x1b8),damping_flags_u8=root[0x3fb6],reference_velocity_s32=[signed(root,at)for at in [0x88,0x8c,0x90]],forward_key_u8=ext['forward_key_u8'],reverse_key_u8=ext['reverse_key_u8'],spin_xyz_s32=ext['spin_xyz_s32'],player_index_u32=word(root,0xc0),player_roll_s16=struct.unpack_from('<h',root,0x210)[0],drift_ticks_low_u32=word(root,0xe0),drift_ticks_high_u32=word(root,0xe4))
def mutations(before,after,ordinal):
 result=[]
 for region,a,b in [(0,bytes.fromhex(before['body_before_hex']),bytes.fromhex(after['body_hex'])),(1,bytes.fromhex(before['root_before_hex']),bytes.fromhex(after['root_hex'])),(2,struct.pack('<3I',*[before['externals_before'][k]for k in M.FIELDS]),struct.pack('<3I',*[after['external'][k]for k in M.FIELDS]))]:
  result.extend([ordinal,region,i,y]for i,(x,y)in enumerate(zip(a,b))if x!=y)
 return result or [[255,0,0,0]]
def segments(a,b):return [[s['offset'],s['hex']]for s in I.segments(a,b)]

def generate(args):
 # Enlarging only the observer journal allows one exact native phase response;
 # no original instruction, root alias or pointer-table word layout is changed.
 M.MAX_MUT=256;M.INPUT=12+M.STATE+4+M.MAX_MUT*16
 definitions={}
 for name,module,file in [('mode',M,'source-procedures.asm'),('player',P,'source-procedures.s'),('phase',H,'source-procedures.s'),('input',I,'source-procedures.s'),('motion',T,'source-procedures.s')]:
  directory=module.PROOF;meta=json.loads((directory/'instruction-proof.json').read_text());source=(directory/file).read_text()
  if name in ['mode','player','motion']:module.verify_archived(meta,source)
  else:module.verify(meta,source)
  native=module.assembly(source,meta)if name=='phase'else module.assembly(source,json.loads(M.TABLE.read_text()))if name=='mode'else module.assembly(source)
  definitions[name]=(module,native)
 cases=[];native_digests=[];rng=random.Random(0x10091044)
 with tempfile.TemporaryDirectory(prefix='owned-player-cycle-native-')as directory:
  work=Path(directory)
  for name,(_,native)in definitions.items():
   (work/(name+'.s')).write_text(native);subprocess.run(['as','--64','-o',str(work/(name+'.o')),str(work/(name+'.s'))],check=True);subprocess.run(['ld','-o',str(work/name),str(work/(name+'.o'))],check=True)
  def run(name,row):
   module=definitions[name][0];data=module.packet(row);runs=[]
   for _ in range(3):
    result=subprocess.run([str(work/name)],input=data,capture_output=True,check=True,timeout=30)
    if result.stderr or len(result.stdout)!=module.OUTPUT:raise ValueError('Native composition guard/size '+name)
    runs.append(result.stdout)
   if runs[0]!=runs[1]or runs[0]!=runs[2]:raise ValueError('Native fresh-process variation '+name)
   native_digests.append({'kernel':name,'input_sha256':sha(data),'output_sha256':sha(runs[0])})
   return module.decode(runs[0],row)
  def complete(core,name,phase_row=None):
   mr=mode_row(core);prefix,trace=run('mode',mr);boundary=trace[-1]
   if boundary['request']['kind']!='control_phase':raise ValueError('Missing native selected phase')
   selected=boundary['request']['function_id_u32'];body=boundary['body_before_hex'];root=bytes.fromhex(boundary['root_before_hex']);external=copy.deepcopy(core['external']);external.update(boundary['externals_before'])
   payload={'mode_observations':trace[:-1],'phase_observations':[],'gui_samples':[],'contacts':[]}
   if selected==1044:
    pr={'name':name,'operation':'drift_f1044','body_before_hex':body,'parent_hex':core['parent_hex'],'globals_before':player_globals(root,external),'frame_response_body_hex':''}
    result=run('player',pr);after={'body_hex':result['body_after_hex'],'root_hex':root.hex(),'external':external};phase_order=result['source_order']
   elif selected in [1019,1021]:
    hr=copy.deepcopy(phase_row);hr.update(body_before_hex=body,root_before_patch=H.patches(root),external_before=subset(external,H.FIELDS),scripts=[{'kind':1033,'return_u32':0}])
    first=run('phase',hr);gui=next(o for o in first['observations']if o['kind']in ['F1037','F1039']);gctx=context(gui['before']);gui_word=[0,0x00010001,0xfffe0002,0x80007fff][len(cases)%4]
    ir={'name':name,'operation':'throttle_f1037'if gui['kind']=='F1037'else'view_f1039','body_before_hex':gctx['body'],'root_fill_u8':0xa5,'root_before_segments':I.segments(bytes([0xa5])*M.ROOT,bytes.fromhex(gctx['root'])),'globals_before':subset(external,I.GLOBALS),'gui_accumulator_u32':gui_word,'speed_input_s32':0}
    ie=run('input',ir);input_root=bytearray.fromhex(gctx['root'])
    for change in ie['root_after_changes']:input_root[change['offset']:change['offset']+len(bytes.fromhex(change['hex']))]=bytes.fromhex(change['hex'])
    hr['scripts'].append({'kind':int(gui['kind'][1:]),'return_u32':0,'root_patch':segments(bytes.fromhex(gctx['root']),input_root),'body_patch':segments(bytes.fromhex(gctx['body']),bytes.fromhex(ie['body_after_hex']))})
    middle=run('phase',hr);contact=next(o for o in middle['observations']if o['kind']=='F1033');cctx=context(contact['before']);contact_root=bytes.fromhex(cctx['root'])
    cb={'caller_profile':T.CONTACT,'body_before_hex':cctx['body'],'body_after_hex':cctx['body'],'flags_u8':[0,1,0x20,0x40,0x60][len(cases)%5],'altitude_raw_s32':0,'collider_ref_u32':37,'collider_index_u8':37,'material_u8':0,'collider_body_hex':hr['collider_hex']}
    tr={'name':name,'operation':'contact_f1033','root_prefix_before_hex':contact_root[:T.PREFIX].hex(),'root_tail_fill_u8':0xa5,'effects_enabled_root_u8':contact_root[0x3f5e],'body_before_hex':cctx['body'],'globals_before':{'effect_gate_s32':external['effect_gate_s32'],'sound_mode_s8':external['input_gate_s8'],'step_u32':external['frame_ticks_u32']},'boundary':cb}
    te=run('motion',tr);newroot=bytearray(contact_root);newroot[:T.PREFIX]=bytes.fromhex(te['root_prefix_after_hex'])
    hr['scripts'][0]={'kind':1033,'return_u32':te['return_s32']&0xffffffff,'root_patch':segments(contact_root,newroot),'body_patch':segments(bytes.fromhex(cctx['body']),bytes.fromhex(te['body_after_hex']))}
    final=run('phase',hr);phase_order=final['source_order'];external.update(final['external_after']);after={'body_hex':final['body_after_hex'],'root_hex':H.unpatch(final['root_after_patch']).hex(),'external':external}
    payload['phase_observations']=[observation(o)for o in final['observations']if o['kind']not in['F1037','F1039','F1033']]
    fg=next(o for o in final['observations']if o['kind']==gui['kind']);fctx=context(fg['before'])
    payload['gui_samples']=[{'kind':gui['kind'],'before_sha256':boundary_hash(fctx),'gui_u32':gui_word}];payload['contacts']=[cb]
   else:raise ValueError('Unexpected native selected phase '+str(selected))
   # Replay the actual native phase response through the original F1009 call
   # continuation; this checks the full final body/root/external bytes as well.
   mr['native_mutations']=mutations(boundary,after,len(trace));expected,finaltrace=run('mode',mr)
   if expected['body_after_hex']!=after['body_hex']or M.expand(expected['root_after'])!=bytes.fromhex(after['root_hex']):raise ValueError('Native callback response copy differs')
   result_core={'body_hex':expected['body_after_hex'],'parent_hex':core['parent_hex'],'root_hex':M.expand(expected['root_after']).hex(),'external':after['external'],'clock':copy.deepcopy(core['clock'])};result_core['external'].update(expected['externals_after'])
   cases.append({'name':name,'core_before':core,'command':{'operation':'control','payload':payload},'expected_core':result_core,'expected_selected_function_id_u32':selected,'expected_phase_source_order':phase_order,'expected_mode_source_order':['F1009','F1008']+['F'+str(t['request']['function_id_u32'])for t in finaltrace]})
  for i in range(64):
   row=M.base(rng,i,'control_f1009');body=bytearray.fromhex(row['body_before_hex']);body[0x86]=114;root=bytearray(M.expand(row['root_before']));struct.pack_into('<I',root,0xc0,114);struct.pack_into('<II',root,0xc8,114,0);root[0xe8]=44;root[0xe9]=i%2
   core={'body_hex':body.hex(),'parent_hex':rng.randbytes(M.BODY).hex(),'root_hex':root.hex(),'external':all_external(row['externals_before']['frame_ticks_u32'],i),'clock':row['clock']};complete(core,'mode-to-drift/'+str(i))
  for i in range(16):
   hr=H.base_row(rng,i,'phase_f1021'if i%2==0 else'phase_f1019');body=bytearray.fromhex(hr['body_before_hex']);body[0xca]|=2;body[0x14e]=0;root=bytearray(H.unpatch(hr['root_before_patch']));root[0x3fb6]=0;root[0x3f5e]=0;root[0xea]=[0,2,3,4][i%4];root[0xe9]=i%2;struct.pack_into('<i',root,0xd8,0)
   external=all_external([0,1,2,4971][i%4],i);external['spin_xyz_s32']=hr['external_before']['spin_xyz_s32'];clock={'tick_u32':[0,49710,0x7fffffff,0xffffffff][i%4],'day_u32':[0,1,0xffffffff][i%3]}
   core={'body_hex':body.hex(),'parent_hex':hr['parent_hex'],'root_hex':root.hex(),'external':external,'clock':clock};complete(core,'mode-input-phase-contact/'+str(i),hr)
 args.proof_dir.mkdir(parents=True,exist_ok=True)
 for name,(_,native)in definitions.items():(args.proof_dir/(name+'-composed-native.s')).write_text(native)
 paths=['data/ffe_player_modes.json','tests/fixtures/source_motion_native.json','tests/fixtures/source_player_phase_native.json','tools/rebuild_source_natural_contact_native.py','tools/rebuild_source_surface_contact_native.py','tools/rebuild_source_atmospheric_native.py','tools/rebuild_source_jet_fuel_native.py','tools/rebuild_ground_surface_native.py','recovered-history/ground_harness/tools/build_terrain_query_reference.py','recovered-history/ground_harness/tools/native_reference.py','tools/rebuild_source_player_cycle_native.py','tools/rebuild_source_player_mode_native.py','tools/rebuild_source_player_dispatch_native.py','tools/rebuild_source_player_phase_native.py','tools/rebuild_source_player_input_native.py','tools/rebuild_source_player_motion_native.py']
 for name,module,file in [('mode',M,'source-procedures.asm'),('player',P,'source-procedures.s'),('phase',H,'source-procedures.s'),('input',I,'source-procedures.s'),('motion',T,'source-procedures.s')]:paths.extend([str((module.PROOF/'instruction-proof.json').relative_to(PROJECT)),str((module.PROOF/file).relative_to(PROJECT))])
 pins={path:sha((PROJECT/path).read_bytes())for path in paths};proof={'source_executable_sha256':M.EXE_SHA,'source_assembly_sha256':M.ASM_SHA,'source_data_sha256':M.DATA_SHA,'source_dependencies_sha256':pins,'host_assembly_sha256':{name:sha(native.encode())for name,(_,native)in definitions.items()},'fresh_process_runs_each_call':3,'native_calls':len(native_digests),'native_calls_sha256':canonical_hash({'calls':native_digests}),'private_original_inputs_needed':False,'expected_arithmetic_calculated_in_python':False,'observer_mutation_capacity_bytes':256,'scope':'Actual original F1009 whole mode prefix selects native F1044 or native F1019/F1021. Actual native F1037/F1039 and F1033 outputs resume their phase boundaries, then actual native phase result resumes F1009. F569 geometry and remaining world/presentation callbacks are explicit supplied observations. Full338body/16384root/external owner state retained; no full scheduler, world callbacks or Main claim.'}
 result={'schema':'starfrontier-source-player-cycle-native-v1','case_count':len(cases),'case_counts_by_selected_function':{str(fid):sum(c['expected_selected_function_id_u32']==fid for c in cases)for fid in [1044,1019,1021]},'proof':proof,'cases':cases};args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,indent=2)+'\n');(args.proof_dir/'composition-proof.json').write_text(json.dumps(proof,indent=2)+'\n');print(json.dumps({'case_count':len(cases),'fixture_sha256':sha(args.output.read_bytes()),'native_calls':len(native_digests),'output':str(args.output)},indent=2))

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--proof-dir',type=Path,default=PROOF)
 for flag in ['exe','asm','data']:p.add_argument('--'+flag,type=Path)
 generate(p.parse_args())
if __name__=='__main__':main()
