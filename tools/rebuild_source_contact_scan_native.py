#!/usr/bin/env python3
"""Compose actual DOS F569/F570 bank traversal with whole F575/F577/F578.

Only the host F575 observer gains a full-record response transport. All source
scan, frame/cache, classification and contact arithmetic executes in the
independently checked original instruction bodies, never Python arithmetic.
"""
from __future__ import annotations
import argparse,copy,hashlib,inspect,json,random,struct,subprocess,tempfile
from pathlib import Path
import rebuild_source_frame_dispatch_native as F
import rebuild_source_contact_classifier_native as C
PROJECT=F.PROJECT
PROOF=PROJECT/'validation/contact-classifier-2026-11-17/scan-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_contact_scan_native.json'
ROOT_BYTES=0x4000
PROFILE='dos-firstenc-actual-f569-f575-scan-v1'

def sha(raw):return hashlib.sha256(raw).hexdigest()
def identity_response():
 return {'mask_u32':0,'globals':{name:0 for name,_,_ in F.FIELDS},'return_u8':0,'subject_xor_offset':0xffffffff,'subject_xor_u8':0,'collider_xor_offset':0xffffffff,'collider_xor_u8':0,'full_records':False}
def adapted_frame():
 proof=json.loads((F.PROOF/'instruction-proof.json').read_text())
 captured=(F.PROOF/'frame-dispatch-observed-kernel.s').read_text()
 if sha(captured.encode())!=proof['host_assembly_sha256']:raise ValueError('Archived whole-frame kernel differs')
 namespace=F.__dict__.copy();namespace.update(SCRIPT_BYTES=752,INPUT=64+F.OBJECT+F.BANK+F.MAX_CALLS*752)
 source=inspect.getsource(F.packet)
 old="responses+=struct.pack('<18I',r['mask_u32'],*[int(r['globals'][name])&0xffffffff for name,_,_ in FIELDS],r['return_u8'],r['subject_xor_offset'],r['subject_xor_u8'],r['collider_xor_offset'],r['collider_xor_u8'])"
 if source.count(old)!=1:raise ValueError('Unreviewed frame response serializer')
 source=source.replace(old,old+"\n        responses+=struct.pack('<I',int(r.get('full_records',False)))+bytes.fromhex(r.get('subject_after_hex','00'*338))+bytes.fromhex(r.get('collider_after_hex','00'*338))")
 exec(source,namespace)
 full_copy='''
 cmp DWORD PTR [r9+72],0
 je full_records_done
 mov esi,r9d
 add esi,76
 mov edi,DWORD PTR [rbp+24]
 mov ecx,338
 rep movsb
 mov esi,r9d
 add esi,414
 mov edi,DWORD PTR [rbp+32]
 mov ecx,338
 rep movsb
full_records_done:
'''
 namespace['WRAPPER']=F.WRAPPER.replace('@APPLY_GLOBALS@','@APPLY_GLOBALS@'+full_copy)
 exec(inspect.getsource(F.wrapper),namespace)
 exec(inspect.getsource(F.decode),namespace)
 prefix=captured[:captured.index('decode_ref:')]
 kernel=prefix+namespace['wrapper']()
 return namespace,kernel,proof,prefix

def compile_native(folder,name,assembly):
 source=folder/(name+'.s');source.write_text(assembly)
 obj=folder/(name+'.o');binary=folder/name
 subprocess.run(['as','--64','-o',str(obj),str(source)],check=True)
 subprocess.run(['ld','-o',str(binary),str(obj)],check=True)
 return binary

def observation_context(value):
 return {'body':value['body_hex'],'collider':value['collider_hex'],'relative':value['relative_hex'],'globals':value['globals']}
def observations(expected):
 return [{**{k:v for k,v in o.items()if k not in ['before','after']},'before':observation_context(o['before']),'after':observation_context(o['after'])}for o in expected['observations']]

def controlled_record(rng,index,parent=0,rotating=0,model=38):
 body=F.record(rng,index,parent,rotating)
 struct.pack_into('<I',body,0x82,model);body[0x87]=3;body[0x14c]=0
 struct.pack_into('<q',body,0x138,1000);struct.pack_into('<q',body,0x140,700)
 struct.pack_into('<3q',body,0x3e,0,500,0)
 struct.pack_into('<3i',body,0x8c,0,0,0);struct.pack_into('<H',body,0x9e,0xffff)
 return body

def initial_cases():
 rng=random.Random(0x569575578);rows=[]
 for i in range(32):
  own=114;parent=1 if i<24 else 0
  body=controlled_record(rng,own,parent,i%2,[15,24,38][i%3])
  body[0x87]=[3,11,14,1][i%4]
  if i%4==1:struct.pack_into('<3i',body,0x8c,601,-3000,25)
  struct.pack_into('<I',body,0x148,[0,1,127,0x7fffffff][i%4])
  if i%6==0:struct.pack_into('<3q',body,0x3e,1<<40,-(1<<37),123456)
  objects={};flags=bytearray(115);flags[own]=4
  if parent:
   other=controlled_record(rng,parent,0,0,[38,81,96][i%3]);other[0x87]=[1,2,3][i%3]
   if i%3==1:struct.pack_into('<9i',other,0,0,0,-2147483648,0,2147483647,0,2147483647,0,0)
   if i%3==2:struct.pack_into('<9i',other,0,1518500249,0,1518500249,0,2147483647,0,-1518500249,0,1518500249)
   objects[str(parent)]=other.hex()
  if i>=8:
   for j,index in enumerate([113,65,7,2]):
    other=controlled_record(rng,index,parent,(i+j)%2,[38,81,96,0x99][j])
    if j==3:struct.pack_into('<I',other,0x82,0x99)
    struct.pack_into('<3q',other,0x3e,(j+1)*2000,500-j*200,300+j*100)
    if j==0 and i%5==0:other[0x8b]=1
    if j==1 and i%5==1:other[0x56]=0
    objects[str(index)]=other.hex();flags[index]=4 if j!=2 or i%3 else 0
  root=bytearray(b'\xa5'*ROOT_BYTES);struct.pack_into('<I',root,0xc0,114 if i%4 else 17);struct.pack_into('<II',root,0xc8,own,83)
  globals=F.global_state(rng,[own,*map(int,objects)]);globals['collider_ref_u32']=83
  rows.append({'name':'actual-scan-%02d'%i,'enabled':bool(i%2),'player_hex':body.hex(),'objects_by_index':objects,'flags_hex':flags.hex(),'globals':globals,'root_before_hex':root.hex(),'frame_ticks_u32':[0,1,127,4971,0x7fffffff,0x80000000,0xffffffff][i%7],'source_frame_byte':[0,1,2,127,255][i%5],'response_scripts':[identity_response()for _ in range(F.MAX_CALLS)]})
 return rows

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--output',type=Path,default=FIXTURE)
 for name in ['exe','asm','data']:p.add_argument('--'+name,type=Path)
 a=p.parse_args();namespace,frame_assembly,frame_proof,prefix=adapted_frame()
 classifier_proof=json.loads((C.PROOF/'instruction-proof.json').read_text());source=(C.PROOF/'source-procedures.asm').read_text();C.verify_archived(classifier_proof,source);classifier_assembly=C.assembly(source)
 rows=initial_cases();packets={'frame':[],'classifier':[]};outputs={'frame':[],'classifier':[]};calls=[];frame_conversions=0;cache_records=0
 with tempfile.TemporaryDirectory(prefix='actual-native-scan-')as directory:
  folder=Path(directory);binaries={'frame':compile_native(folder,'frame',frame_assembly),'classifier':compile_native(folder,'classifier',classifier_assembly)}
  def execute(kind,packet,size):
   runs=[subprocess.run([str(binaries[kind])],input=packet,capture_output=True,check=True,timeout=60).stdout for _ in range(3)]
   if len(set(runs))!=1 or len(runs[0])!=size:raise ValueError('Native repeat or output length differs '+kind)
   packets[kind].append(packet);outputs[kind].append(runs[0]);return runs[0]
  for row in rows:
   completed=[];classifier_calls=[];supplied=[];player_index=struct.unpack_from('<I',bytes.fromhex(row['root_before_hex']),0xc0)[0]
   for iteration in range(F.MAX_CALLS+1):
    raw=execute('frame',namespace['packet'](row),F.OUTPUT);trace,expected=namespace['decode'](raw,row)
    if len(completed)==len(trace):break
    if len(completed)>len(trace):raise ValueError('Frame continuation erased an earlier callback')
    t=trace[len(completed)];g=dict(t['globals_before']);g['player_index_u32']=player_index
    cr={'name':row['name']+'/F575-%02d'%len(completed),'body_before_hex':t['subject_before_hex'],'collider_before_hex':t['collider_before_hex'],'relative_before_hex':t['relative_before_hex'],'globals_before':g,'scripts':[{'return_u32':0,'globals':{}}for _ in range(C.MAXOBS)]}
    # These cases use the real F577/F578 path. No synthetic model program is
    # supplied under the F576 name; every parent has original simple flags.
    result=C.decode(execute('classifier',C.packet(cr,classifier_proof['models']),C.OUTPUT),cr)
    if any(o['kind']=='F576'for o in result['observations']):raise ValueError('Unexpected generic geometry boundary in simple-source scan case')
    source_observations=observations(result)
    if source_observations:supplied.append({'call_index_u32':len(completed),'observations':source_observations})
    response=identity_response();response.update(mask_u32=0xfff,globals={name:result['globals_after'][name]for name,_,_ in F.FIELDS},return_u8=result['return_u8'],full_records=True,subject_after_hex=result['body_after_hex'],collider_after_hex=result['collider_after_hex'])
    row['response_scripts'][len(completed)]=response;completed.append(response)
    player_index=result['globals_after']['player_index_u32']
    classifier_calls.append({'input':{k:v for k,v in cr.items()if k!='scripts'},'expected':result})
   else:raise ValueError('Actual source scan callback limit exhausted')
   if len(classifier_calls)!=len(trace):raise ValueError('Source callback coverage differs')
   for t,cc in zip(trace,classifier_calls):
    x=cc['expected']
    if t['subject_after_hex']!=x['body_after_hex']or t['collider_after_hex']!=x['collider_after_hex']or t['globals_after']!={name:x['globals_after'][name]for name,_,_ in F.FIELDS}or t['return_u8']!=x['return_u8']:raise ValueError('Actual classifier output failed frame callback transport')
   root_after=bytearray.fromhex(row['root_before_hex']);struct.pack_into('<I',root_after,0xc0,player_index)
   expected['root_after_hex']=root_after.hex();row['classifier_observations']=supplied;row['classifier_calls']=classifier_calls;row['trace']=trace;row['expected']=expected;row.pop('response_scripts')
   frame_conversions+=int(bytes.fromhex(row['player_hex'])[0x57]!=bytes.fromhex(expected['player_hex'])[0x57])
   cache_records+=sum(bytes.fromhex(v)[0x25:0x3e]!=bytes.fromhex(row['objects_by_index'][k])[0x25:0x3e]for k,v in expected['objects_by_index'].items())
   calls.extend(classifier_calls)
  for kind,size in [('frame',F.OUTPUT),('classifier',C.OUTPUT)]:
   if packets[kind]:
    reversed_output=subprocess.run([str(binaries[kind])],input=b''.join(reversed(packets[kind])),capture_output=True,check=True,timeout=120).stdout
    if reversed_output!=b''.join(reversed(outputs[kind])):raise ValueError('Fresh reverse replay state contamination '+kind)
 a.proof_dir.mkdir(parents=True,exist_ok=True);(a.proof_dir/'frame-composed-native.s').write_text(frame_assembly);(a.proof_dir/'classifier-composed-native.s').write_text(classifier_assembly)
 paths=['tools/rebuild_source_contact_scan_native.py','tools/rebuild_source_frame_dispatch_native.py','tools/rebuild_source_contact_classifier_native.py','tools/rebuild_source_surface_contact_native.py','tools/rebuild_source_spherical_contact_native.py','tools/rebuild_source_natural_contact_native.py','recovered-history/ground_harness/tools/native_reference.py','validation/player-dispatch-2026-11-17/frame-native-proof/instruction-proof.json','validation/player-dispatch-2026-11-17/frame-native-proof/frame-dispatch-observed-kernel.s','validation/contact-classifier-2026-11-17/native-proof/instruction-proof.json','validation/contact-classifier-2026-11-17/native-proof/source-procedures.asm']
 pins={name:sha((PROJECT/name).read_bytes())for name in paths}
 proof={'source_executable_sha256':F.EXE_SHA,'source_assembly_sha256':F.ASM_SHA,'source_dependencies_sha256':pins,'host_assembly_sha256':{'frame':sha(frame_assembly.encode()),'classifier':sha(classifier_assembly.encode())},'original_frame_body_prefix_sha256':sha(prefix.encode()),'fresh_process_runs_each_call':3,'reverse_repeat_native_calls':{k:len(v)for k,v in packets.items()},'native_calls':{k:len(v)for k,v in packets.items()},'native_input_sha256':{k:sha(b''.join(v))for k,v in packets.items()},'native_output_sha256':{k:sha(b''.join(v))for k,v in outputs.items()},'all_raw_record_bank_and_output_canaries_verified':True,'expected_arithmetic_calculated_in_python':False,'frame_conversion_cases':frame_conversions,'cache_record_change_count':cache_records,'callback_transport':'Only derived ELF64 F575 observer transport expands72B to752B and copies actual native classifier output records after globals. All original frame/math instructions remain the archived prefix. F953 responses are matched identity observations, not world damage execution. No F576 generic VM response is invented.'}
 fixture={'schema':'starfrontier-source-contact-scan-native-v1','profile':PROFILE,'case_count':len(rows),'actual_F575_calls':len(calls),'proof':proof,'cases':rows,'scope':'Actual original F569/F570 traversal resumed through full F575, real F577/F578 on simple source objects, with raw bank caches, cooldown, frame conversion and globals. General F576 model programs, authoritative F953 damage/world effects, Main and Android remain separate.'}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(fixture,indent=2)+'\n');(a.proof_dir/'composition-proof.json').write_text(json.dumps(proof,indent=2)+'\n')
 print(json.dumps({'case_count':len(rows),'actual_F575_calls':len(calls),'native_calls':proof['native_calls'],'frame_conversion_cases':frame_conversions,'cache_record_change_count':cache_records,'fixture_sha256':sha(a.output.read_bytes())},indent=2))
if __name__=='__main__':main()
