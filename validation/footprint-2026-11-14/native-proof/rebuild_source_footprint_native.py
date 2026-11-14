#!/usr/bin/env python3
"""Original-native ordered F576 footprint observations, without host formulas.

All source instructions are retained. New wrappers preserve registers/flags,
observe actual F576 offset locals, F579 arguments/context and F1876 winning
integer triangles. Direct F579 threshold-zero controls are explicitly separate.
"""
from __future__ import annotations
import argparse,hashlib,json,struct,subprocess,sys,tempfile
from pathlib import Path
sys.dont_write_bytecode=True
PROJECT=Path(__file__).resolve().parents[3];PROOF=Path(__file__).resolve().parent
sys.path.insert(0,str(PROJECT/'tools'))
import rebuild_source_natural_contact_native as N
ORIGINAL=PROJECT/'validation/natural-2026-11-13/nativeproof'
OUTPUT=2048;TRACE=1024;STRIDE=320
FIELDS=N.GLOBAL_FIELDS+[('recorded_intersection_raw',9283,4),('pending_query_flag',9284,4)]

def sha(raw):return hashlib.sha256(raw).hexdigest()
def once(text,old,new):
 if text.count(old)!=1:raise ValueError('Unreviewed native anchor '+repr(old))
 return text.replace(old,new,1)
def preserve(code):return 'pushfq\npush rax\npush rcx\npush rdx\n'+code+'\npop rdx\npop rcx\npop rax\npopfq\n'
def inline(code):return 'push rcx\nmov ecx,[fp_trace_ptr]\n'+code+'\npop rcx\n'
def capture_globals(at):
 result=[]
 for index,(_,number,size)in enumerate(FIELDS):
  result += [('movzx eax,BYTE PTR 'if size==1 else'mov eax,DWORD PTR ')+f'[DATA_{number:06d}]',f'mov DWORD PTR [rbx+{at+index*4}],eax']
 result+=['mov eax,DWORD PTR [DATA_008702]','cmp eax,DWORD PTR [rbp+32]','sete al','movzx eax,al',f'mov DWORD PTR [rbx+{at+52}],eax']
 return '\n'.join(result)

def build(work):
 text=(ORIGINAL/'natural-native.s').read_text();original=text
 # New output space retains the complete original1024-byte record first.
 text=once(text,'output_full: .zero 1024','output_full: .zero 2048')
 start=text.index('_start:');end=text.index('.section .bss',start);wrapper=text[start:end]
 wrapper=once(wrapper,'mov ecx,256\n rep stosd','mov ecx,512\n rep stosd')
 wrapper=once(wrapper,'mov edx,1024\n syscall','mov edx,2048\n syscall')
 wrapper=once(wrapper,'mov DWORD PTR [DATA_008702],0','''mov DWORD PTR [DATA_008702],0
 cmp DWORD PTR [input_full+60],0
 je fp_parent_not_selected
 mov DWORD PTR [DATA_008702],OFFSET FLAT:parent
fp_parent_not_selected:
 mov DWORD PTR [fp_offset],0
 mov DWORD PTR [fp_offset+4],0
 mov DWORD PTR [fp_offset+8],0
 mov DWORD PTR [fp_stop_reason],0''')
 wrapper=once(wrapper,'classify_full:\n push OFFSET FLAT:relative','''classify_full:
 test DWORD PTR [input_full],2
 jnz fp_direct_query
 push OFFSET FLAT:relative''')
 wrapper=once(wrapper,'call FUNC_000576\n add rsp,24\ncapture_full:', '''call FUNC_000576
 add rsp,24
 jmp capture_full
fp_direct_query:
 mov DWORD PTR [fp_stop_reason],4
 mov esi,OFFSET FLAT:relative
 mov edi,OFFSET FLAT:fp_direct_relative
 mov ecx,6
 rep movsd
 push 0
 push OFFSET FLAT:fp_direct_relative
 push OFFSET FLAT:parent
 push OFFSET FLAT:player
 push OFFSET FLAT:fp_primitive
 call FUNC_000579
 lea rsp,[rsp+40]
capture_full:''')
 wrapper=once(wrapper,'mov DWORD PTR [output_full],eax','mov DWORD PTR [output_full],eax\n mov eax,DWORD PTR [fp_stop_reason]\n mov DWORD PTR [output_full+1984],eax')
 text=text[:start]+wrapper+text[end:]
 # Copy the actual signed32 offsets already produced by original F576.
 start=text.index('FUNC_000576:');end=text.index('OriginalF579:',start);body=text[start:end]
 body=once(body,'xor eax,eax\njmp JUMP_002445','xor eax,eax\nmov DWORD PTR [fp_stop_reason],1\njmp JUMP_002445')
 for reason in [2,3]:body=body.replace('or eax,-0x1\njmp JUMP_002445',f'or eax,-0x1\nmov DWORD PTR [fp_stop_reason],{reason}\njmp JUMP_002445',1)
 for index,offset in enumerate([0x30,0x2c,0x28]):
  old=f'mov eax,[rbp-0x{offset:x}]\npush rax'
  body=once(body,old,f'mov eax,[rbp-0x{offset:x}]\nmov DWORD PTR [fp_offset+{index*4}],eax\npush rax')
 text=text[:start]+body+text[end:]
 text=once(text,'JUMP_002461:\npush rdi','JUMP_002461:\nmov DWORD PTR [fp_transpose],1\npush rdi')
 # F581 coarse gates and actual fresh-altitude write are observed in situ.
 start=text.index('FUNC_000581:');end=text.index('FUNC_000582:',start);body=text[start:end]
 body=once(body,'mov [rbp-0x14],eax','mov [rbp-0x14],eax\n'+inline('mov DWORD PTR [rcx+288],eax'))
 needle='sub eax,[rbp-0x20]\ncmp eax,[rbp+40]'
 if body.count(needle)!=2:raise ValueError('F581 gate anchor changed')
 for at,flag in [(292,300),(296,304)]:body=body.replace(needle,'sub eax,[rbp-0x20]\n'+inline(f'mov DWORD PTR [rcx+{at}],eax\nmov DWORD PTR [rcx+{flag}],1')+'cmp eax,[rbp+40]',1)
 body=once(body,'mov [DATA_008703],edx','mov [DATA_008703],edx\n'+inline('mov DWORD PTR [rcx+216],1'))
 body=once(body,'FUNC_000581:','FootprintOriginalF581:');text=text[:start]+body+text[end:]
 text=once(text,'FUNC_001876:','FootprintOriginalF1876:')
 # Winning source vertex p fields and depths; no reconstructed triangle.
 triangle=['mov ecx,[fp_trace_ptr]']
 for corner,offset in enumerate([0x48,0x4c,0x50]):
  triangle.append(f'mov edx,[rbp-0x{offset:x}]')
  for axis,field in enumerate([4,8,12]):triangle += [f'mov eax,DWORD PTR [rdx+{field}]',f'mov DWORD PTR [rcx+{224+(corner*3+axis)*4}],eax']
  triangle += ['mov eax,DWORD PTR [rdx+68]',f'mov DWORD PTR [rcx+{260+corner*4}],eax']
 triangle += ['mov DWORD PTR [rcx+272],1','mov eax,[rbp-0x10]','mov DWORD PTR [rcx+284],eax']
 text=once(text,'JUMP_008002:\n','JUMP_008002:\n'+preserve('\n'.join(triangle)))
 text=once(text,'JUMP_008034:\n','JUMP_008034:\n'+preserve('mov ecx,[fp_trace_ptr]\nmov eax,[rbp-0x6c]\nmov DWORD PTR [rcx+276],eax\nmov eax,[rbp-0x88]\nmov DWORD PTR [rcx+280],eax'))
 text=once(text,N.TRACE_F579,trace_f579())
 text+='\n.section .text\n'+wrappers()+'\n.section .bss\nfp_trace_ptr: .zero 4\nfp_offset: .zero 12\nfp_transpose: .zero 4\nfp_primitive: .zero 4\nfp_direct_relative: .zero 24\nfp_stop_reason: .zero 4\n'
 (work/'observed.s').write_text(text)
 for stem,path in [('observed',work/'observed.s'),('excluded',ORIGINAL/'excluded-native.s')]:subprocess.run(['as','--64',str(path),'-o',str(work/(stem+'.o'))],check=True)
 subprocess.run(['ld','-m','elf_x86_64',str(work/'observed.o'),str(work/'excluded.o'),'-o',str(work/'observed')],check=True)
 return text,original

def trace_f579():
 pre=capture_globals(96);post=capture_globals(152)
 return r'''FUNC_000579:
 push rbp
 mov rbp,rsp
 push rbx
 push rsi
 push rdi
 pushfq
 push rax
 push rcx
 push rdx
 mov ebx,DWORD PTR [volume_count]
 cmp ebx,3
 jae invalid_trace
 imul ebx,320
 add ebx,OFFSET FLAT:output_full+1024
 mov DWORD PTR [fp_trace_ptr],ebx
 mov DWORD PTR [fp_transpose],0
 mov DWORD PTR [rbx+64],0x7fffffff
 mov DWORD PTR [rbx+68],0x7fffffff
 mov DWORD PTR [rbx+208],0x7fffffff
 mov DWORD PTR [rbx+288],0x7fffffff
 mov eax,DWORD PTR [rbp+48]
 mov DWORD PTR [rbx],eax
 mov eax,DWORD PTR [fp_offset]
 mov DWORD PTR [rbx+4],eax
 mov eax,DWORD PTR [fp_offset+4]
 mov DWORD PTR [rbx+8],eax
 mov eax,DWORD PTR [fp_offset+8]
 mov DWORD PTR [rbx+12],eax
 mov esi,DWORD PTR [rbp+40]
 lea edi,[rbx+16]
 mov ecx,6
 rep movsd
 mov eax,DWORD PTR [query_count_full]
 mov DWORD PTR [rbx+88],eax
'''+pre+r'''
 pop rdx
 pop rcx
 pop rax
 popfq
 push QWORD PTR [rbp+48]
 push QWORD PTR [rbp+40]
 push QWORD PTR [rbp+32]
 push QWORD PTR [rbp+24]
 push QWORD PTR [rbp+16]
 call OriginalF579
 lea rsp,[rsp+40]
 pushfq
 push rax
 push rcx
 push rdx
 mov DWORD PTR [rbx+92],eax
 mov esi,DWORD PTR [rbp+40]
 lea edi,[rbx+40]
 mov ecx,6
 rep movsd
 mov eax,DWORD PTR [query_count_full]
 sub eax,DWORD PTR [rbx+88]
 mov DWORD PTR [rbx+88],eax
 mov eax,DWORD PTR [fp_transpose]
 mov DWORD PTR [rbx+84],eax
'''+post+r'''
 # Retain the old canonical volume trace verbatim in the first1024bytes.
 mov edi,DWORD PTR [volume_count]
 shl edi,6
 add edi,OFFSET FLAT:output_full+768
 mov eax,DWORD PTR [rbx]
 mov DWORD PTR [rdi],eax
 lea esi,[rbx+16]
 add edi,4
 mov ecx,12
 rep movsd
 mov eax,DWORD PTR [rbx+92]
 mov DWORD PTR [rdi],eax
 mov eax,DWORD PTR [rbx+88]
 mov DWORD PTR [rdi+4],eax
 inc DWORD PTR [volume_count]
 pop rdx
 pop rcx
 pop rax
 popfq
 pop rdi
 pop rsi
 pop rbx
 pop rbp
 ret
invalid_trace:
 mov eax,60
 mov edi,95
 syscall
'''

def wrappers():
 entry='mov ecx,[fp_trace_ptr]\nmov edx,DWORD PTR [rbp+48]\nmov eax,DWORD PTR [edx+24]\nmov DWORD PTR [rcx+64],eax\nmov eax,DWORD PTR [rbp+40]\nmov DWORD PTR [rcx+68],eax\n'
 for axis in range(3):entry+=f'mov eax,DWORD PTR [rdx+{axis*4}]\nmov DWORD PTR [rcx+{72+axis*4}],eax\n'
 entry+='mov DWORD PTR [rcx+220],1'
 result='FUNC_000581:\npush rbp\nmov rbp,rsp\n'+preserve(entry)
 result+=''.join(f'push QWORD PTR [rbp+{at}]\n'for at in [48,40,32,24,16])+'call FootprintOriginalF581\nlea rsp,[rsp+40]\n'
 result+=preserve('mov ecx,[fp_trace_ptr]\nmov edx,DWORD PTR [rbp+16]\nmov eax,DWORD PTR [rdx]\nmov DWORD PTR [rcx+308],eax\nmovzx eax,BYTE PTR [DATA_008707]\nmov DWORD PTR [rcx+312],eax')+'pop rbp\nret\n'
 result+='FUNC_001876:\npush rbp\nmov rbp,rsp\n'+preserve('mov ecx,[fp_trace_ptr]\nmov eax,DWORD PTR [rbp+24]\nmov DWORD PTR [rcx+212],eax')
 result+=''.join(f'push QWORD PTR [rbp+{at}]\n'for at in range(104,15,-8))+'call FootprintOriginalF1876\nlea rsp,[rsp+96]\n'
 result+=preserve('mov ecx,[fp_trace_ptr]\nmov edx,DWORD PTR [rbp+16]\nmov eax,DWORD PTR [rdx]\nmov DWORD PTR [rcx+208],eax')+'pop rbp\nret\n'
 return result

def packet(row):
 raw=bytearray(N.packet(row));struct.pack_into('<I',raw,0,2 if row.get('mode')=='direct_f579_threshold_zero'else 0);struct.pack_into('<I',raw,60,int(row['context']['initial_globals'].get('collider_parent_selected',False)));return bytes(raw)
def execute(binary,rows,reproduce=True):
 ordered=rows+list(reversed(rows))if reproduce else rows;payload=b''.join(packet(row)for row in ordered);outputs=[]
 for _ in range(3 if reproduce else 1):
  r=subprocess.run([str(binary)],input=payload,capture_output=True,timeout=120)
  if r.returncode:raise ValueError(f'Native failed{r.returncode} after{len(r.stdout)//OUTPUT}records')
  if len(r.stdout)!=len(ordered)*OUTPUT:raise ValueError('Native output truncated')
  outputs.append(r.stdout)
 if any(o!=outputs[0]for o in outputs[1:]):raise ValueError('Cold-run mismatch')
 if reproduce:
  for i,row in enumerate(rows):
   if outputs[0][i*OUTPUT:(i+1)*OUTPUT]!=outputs[0][(len(ordered)-1-i)*OUTPUT:(len(ordered)-i)*OUTPUT]:raise ValueError('Reverse-repeat mismatch '+row['id'])
 return outputs[0]
def globals_at(raw,at):
 values=struct.unpack_from('<14i',raw,at);result={}
 for (name,_,_),value in zip(FIELDS,values):result[name]=value&MASK if name.endswith('_u32')else value
 result['collider_parent_selected']=bool(values[-1]);return result
MASK=0xffffffff

def decode(raw,row):
 canonical=N.decode(raw[:1024]);traces=[]
 for index in range(canonical['f579_calls']):
  at=TRACE+index*STRIDE;ints=struct.unpack_from('<80i',raw,at);before=globals_at(raw,at+96);after=globals_at(raw,at+152);queries=ints[22];kind=ints[78]
  branch='terrain_query'if queries else('outside_outer'if kind==0 else'inside_inner'if kind==1 else'unknown')
  query={'executed':bool(queries),'result_s32':ints[52],'limit_s32':ints[53],'fresh_altitude_written':bool(ints[54])}
  triangle={'captured':bool(ints[68]),'positions_raw':[list(ints[56+c*3:59+c*3])for c in range(3)],'depths_s32':list(ints[65:68]),'sar_shift_s32':ints[69],'recorded_intersection_raw':ints[70],'leaf_depth_s32':ints[71]}
  traces.append({'child_index':index,'offset_s32':list(ints[1:4]),'relative_before_hex':raw[at+16:at+40].hex(),'relative_truncated_hex':raw[at+40:at+64].hex(),'threshold_before_s32':ints[0],'vector_scale_s32':ints[16],'threshold_scaled_s32':ints[17],'observer_model_local_raw':list(ints[18:21]),'parent_transpose_applied':bool(ints[21]),'terrain_query_calls':queries,'f579_return_s32':ints[23],'globals_before':before,'globals_after_f579':after,'f581_visited':bool(ints[55]),'f581_return_s32':ints[77],'branch':branch,'distance_s32':ints[72],'outer_delta_s32':ints[73],'inner_delta_s32':ints[74],'outer_checked':bool(ints[75]),'inner_checked':bool(ints[76]),'query':query,'winning_triangle':triangle})
 selected=next((i for i,t in enumerate(traces)if t['f579_return_s32']>=0),-1)
 previous=canonical['globals']['previous_altitude_low_u32']+(canonical['globals']['previous_altitude_high_s32']<<32)
 if canonical['player_hex']!=row['player_object_hex']or canonical['parent_hex']!=row['parent_object_hex']or canonical['relative_after_hex']!=row['relative_before_hex']:raise ValueError('Source caller data mutated')
 stop=int(struct.unpack_from('<I',raw,1984)[0]);termination={1:'first_nonnegative_f579',2:'body_child_flag_disabled',3:'source_zero_child_terminator',4:'direct_f579_helper_return'}[stop]
 nominal={24:1,38:3,15:2}[int(row['player_model'])]
 return {'native_termination':termination,'nominal_source_volume_count':nominal,'all_actual_volumes_visited':len(traces)==nominal if row.get('mode')!='direct_f579_threshold_zero'else None,'selected_previous_fresh_from_selected_volume':bool(traces[selected]['query']['fresh_altitude_written'])if selected>=0 else False,'canonical':canonical,'volume_trace':traces,'selected_child_index':selected,'selected_previous_altitude_s64_hex':struct.pack('<q',previous).hex(),'selected_previous_raw_s64':str(previous),'visited_volume_count':len(traces)}

def controls(candidates):
 rows=[]
 for candidate in candidates:
  row=json.loads(json.dumps(candidate));row['mode']='original_f576';rows.append(row)
 old=json.load(open(PROJECT/'tests/fixtures/source_natural_contact_native.json'))['cases']
 names=['natural117/ship38/target_child_hit_1_0','natural117/ship38/target_child_hit_-1_0','natural117/ship15/target_child_hit_-1_2','natural146/ship15/inner_equal/axis2','natural117/ship38/child_flag_cleared_outside','natural117/ship15/child_flag_cleared_outside','natural122/ship24/matrix_sentinel1','natural122/ship38/matrix_sentinel1','natural122/ship15/matrix_sentinel1']
 for name in names:
  row=json.loads(json.dumps(next(r for r in old if r['name']==name)));row.pop('expected');row['id']='published-control/'+name;row['mode']='original_f576';row['input_domain']='published_raw_source_control_not_modern_surface_admission';row['visible_ground_points']=[];rows.append(row)
 return rows

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--work',type=Path);args=parser.parse_args();work=args.work or Path(tempfile.mkdtemp(prefix='source-footprint-native-'));work.mkdir(parents=True,exist_ok=True)
 raw_candidates=(PROOF/'candidate-inputs.json').read_bytes();actors=controls(json.loads(raw_candidates)['rows']);assembly,original=build(work)
 raw=execute(work/'observed',actors)
 for i,row in enumerate(actors):row['expected']=decode(raw[i*OUTPUT:(i+1)*OUTPUT],row)
 ground=[]
 for actor in actors:
  for point in actor.get('visible_ground_points',[]):
   index=int(point['child_index']);actual=actor['expected']['volume_trace'][index]
   if actual['relative_before_hex']!=point['actor_probe_relative_hex']:raise ValueError('Provider input used a reconstructed wrong actor probe')
   row={key:actor[key]for key in ['player_object_hex','parent_object_hex','context','player_model','parent_model','input_domain']};row.update(id=actor['id']+f'/ground_probe{index}',mode='direct_f579_threshold_zero',actor_case_id=actor['id'],actor_child_index=index,relative_before_hex=point['visible_ground_raw_hex'],visible_point=point);ground.append(row)
 groundraw=execute(work/'observed',ground)
 for i,row in enumerate(ground):row['expected']=decode(groundraw[i*OUTPUT:(i+1)*OUTPUT],row)
 oldhash={str(path.relative_to(PROJECT)):sha(path.read_bytes())for path in [PROJECT/'tests/fixtures/source_natural_contact_native.json',PROJECT/'tests/fixtures/source_contact_field_native.json',PROJECT/'tools/rebuild_source_natural_contact_native.py',ORIGINAL/'natural-native.s',ORIGINAL/'excluded-native.s',ORIGINAL/'instruction-proofs.json']}
 report={'schema':1,'revision':'original-native-ordered-source-footprint-v1','source_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'source_commit':N.COMMIT,'scope':'Actual original orderedF576 probe origins/quantization/radii/sourceglobals/selected-first-hit and actualF1876 winning integer triangles. ExplicitdirectF579threshold0 controls query supplied visiblegroundpoint; they are separate diagnostics and retain actualpositiveplayerrecord/originalparentbounds. Not a simultaneous/allunvisitedvolume clearance certificate, originalF575chain, modernadmissionpolicy, fulltriangle/render/GPU/device/gameplay claim.','old_source_provenance_sha256':oldhash,'candidate_inputs_sha256':sha(raw_candidates),'generator_sha256':sha(Path(__file__).read_bytes()),'observed_assembly_sha256':sha(assembly.encode()),'actor_output_sha256':sha(raw),'ground_output_sha256':sha(groundraw),'native_fresh_process_runs_per_bank':3,'actor_reverse_repeat_count':len(actors),'ground_reverse_repeat_count':len(ground),'actor_case_count':len(actors),'visible_ground_case_count':len(ground),'case_count':len(actors)+len(ground),'source_quantization_policy':'NativeF576offsetlocals observed afterNEG/SAR16/IMUL/SAR; centres always ORIGINALinput+newsourceoffset, never cumulative or Python-computed.','previous_altitude_policy':'Actualsourcewordsbefore/aftereachF579; previous canbe inheritedatcoarsegateorcappedquery. Fresh-altitudeflagobservesactualF581writebranch, not querycallcount.','selected_trace_policy':'StopatfirstactualF579>=0; unvisitedchildrenarenotassertedclear. body14Csigncleared maystopbeforeactualchildlistterminator.','winning_triangle_policy':'ActualthreepDWORDs/depths atoriginalJUMP8002; nativeSARshift/intercept atJUMP8034. No hostvertex reconstruction/floatplane expectedvalue.','host_adaptations':'Archived low-address64bitABI pluspreservingGPR/EFLAGS observations; every originalinstructionretained. Output doublespace andexplicitinitialcollider-parentselection supported.','actor_cases':actors,'ground_cases':ground}
 (PROJECT/'tests/fixtures/source_footprint_native.json').write_text(json.dumps(report,separators=(',',':'))+'\n');(PROOF/'footprint-observed-kernel.s').write_text(assembly);(PROOF/'summary.json').write_text(json.dumps({k:v for k,v in report.items()if k not in ['actor_cases','ground_cases']},indent=2)+'\n')
 print('SOURCE FOOTPRINT NATIVE:',len(actors),'actors;',len(ground),'directzero-thresholdgroundpoints;3fresh+reverse;work',work)
 print('FIXTURE SHA256',sha((PROJECT/'tests/fixtures/source_footprint_native.json').read_bytes()))
if __name__=='__main__':main()
