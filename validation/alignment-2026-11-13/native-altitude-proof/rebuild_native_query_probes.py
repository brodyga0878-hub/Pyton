#!/usr/bin/env python3
"""Reproduce new alignment probes from archived native assemblies, read-only.

Build files live under /tmp. No published fixture/generator/runtime is written.
The source experiment uses full originalF581/F1876; explicit scales are reported
separately from canonicalF576. Requires GNU as/ld and Python3 on x86_64 Linux.
"""
import hashlib,json,struct,subprocess,sys,tempfile
from pathlib import Path
P=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(P/'tools'));import rebuild_source_natural_contact_native as N
D=Path(tempfile.mkdtemp(prefix='natural-alignment-native-'))
HERE=Path(__file__).resolve().parent
OLD=P/'validation/natural-2026-11-13/nativeproof'
asm=(HERE/'forced-scale-kernel.s').read_text()
for name,path in [('natural',OLD/'natural-native.s'),('forced-scale',HERE/'forced-scale-kernel.s'),('excluded',OLD/'excluded-native.s')]:
 subprocess.run(['as','--64',str(path),'-o',str(D/(name+'.o'))],check=True)
for name in ['natural','forced-scale']:
 subprocess.run(['ld','-m','elf_x86_64',str(D/(name+'.o')),str(D/'excluded.o'),'-o',str(D/name)],check=True)
j=json.load(open(P/'tests/fixtures/source_natural_contact_native.json'));base=next(r for r in j['cases']if r['selection']=='visual_provider_mismatch_probe');body=bytearray.fromhex(next(r['player_object_hex']for r in j['cases']if r['player_model']==24));body[0x57]=1;body[0x56]=bytes.fromhex(base['parent_object_hex'])[0x86]
poses=[('source_first_probe',[-2033142121,-3584667443,1540339193]),('source_intermediate_probe',[-1814382072,-3198967880,1374603274]),('source_two_pass_final',[-1783199833,-3143989945,1350979139]),('visual_grid_height',[-1783199125,-3143988506,1350978525]),('visual_grid_height_plus9_6m',[-1783203560,-3143996326,1350981885])]
cases=[]
for name,point in poses:
 for graphics in range(7):
  row=json.loads(json.dumps(base));row['name']=name;row['player_object_hex']=body.hex();row['relative_before_hex']=struct.pack('<3q',*point).hex();row['context']={'graphics_level':graphics,'initial_globals':{key:0 for key,_,_ in N.GLOBAL_FIELDS}};cases.append(row)
def run(binary,payload,size):
 out=[subprocess.run([str(binary)],input=payload,capture_output=True,check=True).stdout for _ in range(3)]
 assert out[0]==out[1]==out[2] and len(out[0])%size==0
 return out[0]
canonical=run(D/'natural',b''.join(N.packet(r)for r in cases+list(reversed(cases))),1024)
canonical_rows=[]
for i,row in enumerate(cases):
 block=canonical[i*1024:(i+1)*1024];assert block==canonical[(2*len(cases)-1-i)*1024:(2*len(cases)-i)*1024]
 e=N.decode(block);g=e['globals'];canonical_rows.append({'name':row['name'],'point_hex':row['relative_before_hex'],'graphics_level':row['context']['graphics_level'],'f576_return_s32':e['f576_return_s32'],'query_calls':e['terrain_query_calls'],'volume_trace':e['volume_trace'],'previous_altitude_s64':str(g['previous_altitude_low_u32']+(g['previous_altitude_high_s32']<<32)),'recorded_intersection_raw':g['recorded_intersection_raw'],'collision_kind_u8':g['collision_kind_u8']})
forced=[];payload=b''
for name,point in poses:
 for scale in range(3,13):
  for graphics in [0,1,4]:
   row=json.loads(json.dumps(base));row['name']=name;row['player_object_hex']=body.hex();row['relative_before_hex']=struct.pack('<3q',*point).hex();row['context']['graphics_level']=graphics;packet=bytearray(N.packet(row));struct.pack_into('<I',packet,0,scale);payload+=packet;forced.append({'name':name,'point_hex':row['relative_before_hex'],'vector_scale':scale,'graphics_level':graphics})
forcedraw=run(D/'forced-scale',payload,64)
for i,row in enumerate(forced):
 raw=forcedraw[i*64:(i+1)*64];v=struct.unpack_from('<13i',raw);assert v[0]==row['vector_scale'] and v[1]==row['graphics_level'];row.update(query_calls=v[2],f581_return_s32=v[3],altitude_s64=str(struct.unpack_from('<q',raw,16)[0]),previous_altitude_s64=str(struct.unpack_from('<q',raw,24)[0]),recorded_intersection_raw=v[8],pending_query_flag=v[9],shifted_point_raw=list(v[10:13]))
report={'scope':'Read-only alignment investigation. Canonical full F576 with actual Eagle24 and source-model120 parent from frozen993fixture; separately full originalF581/F1876 at explicit input vector_scales3..12 using nativeF1660 truncation and original descriptor context. No expected height formula in Python; forced scales beyond canonical3 are experiments, not changes toF579. OriginalF581/F1876 source bytes already proved by frozenfixture. SourceSurfaceTerrain continuous two-pass samples are adapter inputs, not asserted exact originalF879 matrix constructor outputs.','source_fixture_sha256':hashlib.sha256((P/'tests/fixtures/source_natural_contact_native.json').read_bytes()).hexdigest(),'native_original_classifier_sha256':hashlib.sha256((D/'natural').read_bytes()).hexdigest(),'native_forced_scale_assembly_sha256':hashlib.sha256(asm.encode()).hexdigest(),'canonical_output_sha256':hashlib.sha256(canonical).hexdigest(),'forced_scale_output_sha256':hashlib.sha256(forcedraw).hexdigest(),'fresh_native_runs':3,'canonical_reverse_repeat_count':len(cases),'canonical_case_count':len(canonical_rows),'forced_scale_case_count':len(forced),'canonical_cases':canonical_rows,'explicit_scale_cases':forced}
Dest=D;(Dest/'alignment-native-query-probes.json').write_text(json.dumps(report,indent=2)+'\n');print('Scratch result:',Dest/'alignment-native-query-probes.json')
print(json.dumps({'canonical_case_count':len(canonical_rows),'forced_scale_case_count':len(forced),'canonical_at_graphics1':[(r['name'],r['previous_altitude_s64'],r['recorded_intersection_raw'])for r in canonical_rows if r['graphics_level']==1],'forced_at_graphics1':[(r['name'],r['vector_scale'],r['previous_altitude_s64'])for r in forced if r['graphics_level']==1]},indent=2))
