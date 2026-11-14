#!/usr/bin/env python3
"""Observe original F581 affine/query frames and bounded F570 caller signs.

No Python expected frame or subtraction arithmetic. Actual instructions produce
all matrices, vectors and caller entry witnesses. Diagnostic native F1669/F1670
calls are explicitly separate from the original F581 algorithm.
"""
from __future__ import annotations
import hashlib,importlib.util,json,struct,subprocess,sys,tempfile,argparse
from pathlib import Path
sys.dont_write_bytecode=True
PROJECT=Path(__file__).resolve().parents[3];PROOF=Path(__file__).resolve().parent
OLD=PROJECT/'validation/footprint-2026-11-14/native-proof'
spec=importlib.util.spec_from_file_location('contact_frame_footprint_helpers',OLD/'rebuild_source_footprint_native.py');F=importlib.util.module_from_spec(spec);spec.loader.exec_module(F)
N=F.N;OUTPUT=3072

def sha(raw):return hashlib.sha256(raw).hexdigest()
def keep(code):return F.preserve(code)
def capture(fields):
 code=['mov ecx,[cf_ptr]']
 for dest,offset,count in fields:
  for i in range(count):code += [f'mov eax,DWORD PTR [rbp{offset+i*4:+d}]',f'mov DWORD PTR [rcx+{dest+i*4}],eax']
 return keep('\n'.join(code))
def build_frame(work):
 text=(OLD/'footprint-observed-kernel.s').read_text();text=F.once(text,'output_full: .zero 2048','output_full: .zero 3072')
 start=text.index('_start:');end=text.index('.section .bss',start);wrapper=text[start:end]
 wrapper=F.once(wrapper,'mov ecx,512\n rep stosd','mov ecx,768\n rep stosd')
 diagnostic='''mov ebx,0
cf_diagnostic_loop:
 mov esi,ebx
 shl esi,8
 add esi,OFFSET FLAT:output_full+2048
 cmp DWORD PTR [rsi+4],0
 je cf_diagnostic_next
 lea eax,[rsi+56]
 push rax
 lea eax,[rsi+20]
 push rax
 lea eax,[rsi+144]
 push rax
 call FUNC_001669
 lea rsp,[rsp+24]
 mov eax,DWORD PTR [rsi+20]
 neg eax
 mov DWORD PTR [rsi+184],eax
 mov eax,DWORD PTR [rsi+24]
 neg eax
 mov DWORD PTR [rsi+188],eax
 mov eax,DWORD PTR [rsi+28]
 neg eax
 mov DWORD PTR [rsi+192],eax
 lea eax,[rsi+56]
 push rax
 lea eax,[rsi+184]
 push rax
 lea eax,[rsi+196]
 push rax
 call FUNC_001669
 lea rsp,[rsp+24]
 mov eax,DWORD PTR [rsi+92]
 add eax,DWORD PTR [rsi+196]
 mov DWORD PTR [rsi+208],eax
 mov eax,DWORD PTR [rsi+96]
 add eax,DWORD PTR [rsi+200]
 mov DWORD PTR [rsi+212],eax
 mov eax,DWORD PTR [rsi+100]
 add eax,DWORD PTR [rsi+204]
 mov DWORD PTR [rsi+216],eax
 mov eax,DWORD PTR [rsi+92]
 sub eax,DWORD PTR [rsi+144]
 mov DWORD PTR [rsi+220],eax
 mov eax,DWORD PTR [rsi+96]
 sub eax,DWORD PTR [rsi+148]
 mov DWORD PTR [rsi+224],eax
 mov eax,DWORD PTR [rsi+100]
 sub eax,DWORD PTR [rsi+152]
 mov DWORD PTR [rsi+228],eax
 lea eax,[rsi+56]
 push rax
 lea eax,[rsi+92]
 push rax
 lea eax,[rsi+156]
 push rax
 call FUNC_001670
 lea rsp,[rsp+24]
cf_diagnostic_next:
 inc ebx
 cmp ebx,3
 jl cf_diagnostic_loop
'''
 wrapper=F.once(wrapper,'mov eax,1\n mov edi,1\n mov esi,OFFSET FLAT:output_full\n mov edx,2048',diagnostic+'mov eax,1\n mov edi,1\n mov esi,OFFSET FLAT:output_full\n mov edx,3072')
 text=text[:start]+wrapper+text[end:]
 setup='''mov eax,DWORD PTR [volume_count]
shl eax,8
add eax,OFFSET FLAT:output_full+2048
mov DWORD PTR [cf_ptr],eax
mov ecx,eax
mov DWORD PTR [rcx],1
mov edx,DWORD PTR [rbp+48]
'''
 for axis in range(3):setup+=f'mov eax,DWORD PTR [rdx+{axis*4}]\nmov DWORD PTR [rcx+{44+axis*4}],eax\n'
 setup+='mov eax,DWORD PTR [rdx+24]\nmov DWORD PTR [rcx+140],eax\nmov eax,DWORD PTR [rbp+40]\nmov DWORD PTR [rcx+172],eax'
 text=F.once(text,'FootprintOriginalF581:\npush rbp\nmov rbp,rsp\n','FootprintOriginalF581:\npush rbp\nmov rbp,rsp\n'+keep(setup))
 text=F.once(text,'JUMP_002487:\n','JUMP_002487:\n'+capture([(8,-0x30,3)]))
 text=F.once(text,'lea eax,[rbp-0x30]\npush rax\ncall FUNC_001466',''.join([capture([(20,-0x30,3)]),'lea eax,[rbp-0x30]\npush rax\ncall FUNC_001466']))
 # These stores are executed only on their actual nonzero rotation paths.
 text=F.once(text,'jz JUMP_002496\nmov [rbp-0x84],eax','jz JUMP_002496\nmov [rbp-0x84],eax\n'+keep('mov ecx,[cf_ptr]\nmov DWORD PTR [rcx+176],1'))
 text=F.once(text,'jz JUMP_002504\nxor edx,edx\nmov [rbp-0x90],edx','jz JUMP_002504\nxor edx,edx\nmov [rbp-0x90],edx\n'+keep('mov ecx,[cf_ptr]\nmov DWORD PTR [rcx+180],1'))
 text=F.once(text,'JUMP_002504:\n','JUMP_002504:\n'+capture([(32,-0x30,3)]))
 text=F.once(text,'call FUNC_001876\nadd rsp,96',capture([(56,-0x54,9),(92,-0x30,3),(104,-0x78,9)])+keep('mov ecx,[cf_ptr]\nmov DWORD PTR [rcx+4],1')+'call FUNC_001876\nadd rsp,96')
 text+='\n.section .bss\ncf_ptr: .zero 4\n'
 (work/'frames.s').write_text(text)
 for stem,path in [('frames',work/'frames.s'),('excluded',PROJECT/'validation/natural-2026-11-13/nativeproof/excluded-native.s')]:subprocess.run(['as','--64',str(path),'-o',str(work/(stem+'.o'))],check=True)
 subprocess.run(['ld','-m','elf_x86_64',str(work/'frames.o'),str(work/'excluded.o'),'-o',str(work/'frames')],check=True)
 return text

def frame_cases():
 old=json.loads((PROJECT/'tests/fixtures/source_natural_contact_native.json').read_text())['cases'];anchors=json.loads((PROJECT/'tests/fixtures/source_contact_field_native.json').read_text())['anchors'];rows=[]
 for model in range(117,134):
  original=next(r for r in old if r['parent_model']==model and r['player_model']==24);parent=bytearray.fromhex(original['parent_object_hex']);body=bytearray.fromhex(original['player_object_hex']);parent[0x86]=1;body[0x86]=2;body[0x56]=1;body[0x57]=1
  record=bytes.fromhex(next(a['source_record_hex']for a in anchors if a['model_index']==model));struct.pack_into('<I',parent,0xa0,struct.unpack_from('<I',record,4)[0]);radius=(struct.unpack_from('<q',parent,0x138)[0]+struct.unpack_from('<q',parent,0x140)[0])//2;outer=struct.unpack_from('<q',parent,0x138)[0]-8000
  variants=[('plusX',[radius,0,0]),('minusX',[-radius,0,0]),('plusY',[0,radius,0]),('minusY',[0,-radius,0]),('plusZ',[0,0,radius]),('minusZ',[0,0,-radius]),('plusZ_xplus1',[1,0,radius]),('plusZ_xminus1',[-1,0,radius]),('plusZ_xplus64',[64,0,radius]),('plusZ_yplus1',[0,1,radius]),('plusZ_yplus64',[0,64,radius]),('outer_plusZ',[0,0,outer]),('outer_plusZ_x64',[64,0,outer])]
  for label,point in variants:
   candidate=bytearray(body)
   for axis,value in enumerate(point):struct.pack_into('<q',candidate,0x3e+8*axis,value)
   rows.append({'id':f'model{model}/{label}','parent_model':model,'player_model':24,'input_domain':'actual_solid_descriptor_bounds_fixed_parent_frame','point_policy':label,'player_object_hex':candidate.hex(),'parent_object_hex':parent.hex(),'relative_before_hex':struct.pack('<3q',*point).hex(),'context':{'graphics_level':1,'initial_globals':N.globals_for(len(rows))},'mode':'original_f576'})
 # Explicit parent-frame convention controls: byte57 selects whether the
 # same raw input is already rotating-frame or requires parent transpose.
 base=next(row for row in rows if row['id']=='model120/plusZ')
 for sign in [-1,1]:
  for rotating in [0,1]:
   row=json.loads(json.dumps(base));body=bytearray.fromhex(row['player_object_hex']);parent=bytearray.fromhex(row['parent_object_hex']);body[0x57]=rotating
   matrix=[0,0,sign*0x7fffffff,0,0x7fffffff,0,-sign*0x7fffffff,0,0]
   for index,value in enumerate(matrix):struct.pack_into('<i',parent,index*4,value)
   row.update(id=f'model120/parentYquarter{sign}/frame57_{rotating}',player_object_hex=body.hex(),parent_object_hex=parent.hex(),input_domain='explicit_Q31_parent_rotation_and_frame57_convention');rows.append(row)
 footprint=json.loads((PROJECT/'tests/fixtures/source_footprint_native.json').read_text())['actor_cases']
 for name in ['118_cobra_roll_minus_3.0','118_cobra_roll_plus_3.0','118_shuttle_pitch_minus_0.5','118_cobra_compound_80.0','published-control/natural146/ship15/inner_equal/axis2']:
  row=json.loads(json.dumps(next(r for r in footprint if r['id']==name)));row.pop('expected');row['id']='retained-footprint/'+name;rows.append(row)
 return rows

def execute(binary,payload,size,count):
 outputs=[]
 for _ in range(3):
  run=subprocess.run([str(binary)],input=payload,capture_output=True,timeout=120)
  if run.returncode or len(run.stdout)!=count*2*size:raise ValueError(f'Native control failed{run.returncode},length{len(run.stdout)}')
  outputs.append(run.stdout)
 if outputs[0]!=outputs[1]or outputs[0]!=outputs[2]:raise ValueError('Cold run discrepancy')
 for index in range(count):
  if outputs[0][index*size:(index+1)*size]!=outputs[0][(2*count-1-index)*size:(2*count-index)*size]:raise ValueError('Reverse repeat discrepancy')
 return outputs[0]
def decode_frame(raw,row):
 footprint=F.decode(raw[:2048],row);frames=[]
 for index in range(footprint['visited_volume_count']):
  at=2048+index*256;v=struct.unpack_from('<64i',raw,at)
  frames.append({'child_index':index,'f581_observed':bool(v[0]),'query_frame_observed':bool(v[1]),'source_origin_raw':list(v[2:5]),'center_difference_raw':list(v[5:8]),'working_difference_raw':list(v[8:11]),'observer_model_local_raw':list(v[11:14]),'U_q31':list(v[14:23]),'C_raw':list(v[23:26]),'A_raw':list(v[26:35]),'vector_scale_s32':v[35],'native_U_times_D_raw':list(v[36:39]),'native_U_transpose_C_raw':list(v[39:42]),'threshold_scaled_s32':v[43],'xy_rotation_taken':bool(v[44]),'yz_rotation_taken':bool(v[45]),'native_negative_D_raw':list(v[46:49]),'native_U_times_negative_D_raw':list(v[49:52]),'native_observer_forward_q_raw':list(v[52:55]),'native_center_minus_rotated_difference_raw':list(v[55:58])})
 return {'footprint':footprint,'frames':frames}

CALLER_WRAPPER=r'''
.global _start
_start:
 mov esp,OFFSET FLAT:caller_stack_end
 cld
caller_next:
 xor r8d,r8d
caller_read:
 xor eax,eax
 xor edi,edi
 lea rsi,[caller_input+r8]
 mov edx,96
 sub edx,r8d
 syscall
 test eax,eax
 jle caller_done
 add r8d,eax
 cmp r8d,96
 jne caller_read
 mov edi,OFFSET FLAT:caller_bank
 xor eax,eax
 mov ecx,86644
 rep stosb
 mov edi,OFFSET FLAT:caller_body
 mov ecx,338
 rep stosb
 mov edi,OFFSET FLAT:caller_output
 mov ecx,64
 rep stosd
 mov edi,OFFSET FLAT:caller_primary
 mov DWORD PTR [rdi],0x7fffffff
 mov DWORD PTR [rdi+16],0x7fffffff
 mov DWORD PTR [rdi+32],0x7fffffff
 mov BYTE PTR [rdi+0x86],1
 mov edi,OFFSET FLAT:caller_candidate
 mov BYTE PTR [rdi+0x86],2
 mov eax,DWORD PTR [caller_input+88]
 mov BYTE PTR [rdi+0x56],al
 mov eax,DWORD PTR [caller_input+12]
 mov BYTE PTR [rdi+0x57],al
 mov esi,OFFSET FLAT:caller_input+64
 add edi,0x3e
 mov ecx,6
 rep movsd
 mov esi,OFFSET FLAT:caller_input+40
 mov edi,OFFSET FLAT:caller_primary+0x3e
 mov ecx,6
 rep movsd
 mov esi,OFFSET FLAT:caller_input+16
 mov edi,OFFSET FLAT:caller_body+0x3e
 mov ecx,6
 rep movsd
 mov BYTE PTR [caller_body+0x86],3
 mov eax,DWORD PTR [caller_input+4]
 mov BYTE PTR [caller_body+0x56],al
 mov eax,DWORD PTR [caller_input+8]
 mov BYTE PTR [caller_body+0x57],al
 mov DWORD PTR [caller_body+0x148],1
 mov eax,DWORD PTR [caller_input+92]
 mov BYTE PTR [caller_bank+2],al
 mov DWORD PTR [caller_count],0
 mov DWORD PTR [DATA_009155],0
 push OFFSET FLAT:caller_primitive
 push OFFSET FLAT:caller_height
 push OFFSET FLAT:caller_collider
 push OFFSET FLAT:caller_ref
 push OFFSET FLAT:caller_flags
 push OFFSET FLAT:caller_bank
 push OFFSET FLAT:caller_body
 call FUNC_000569
 lea rsp,[rsp+56]
 movzx eax,al
 mov DWORD PTR [caller_output],eax
 mov eax,DWORD PTR [caller_count]
 mov DWORD PTR [caller_output+4],eax
 mov esi,OFFSET FLAT:caller_body+0x3e
 mov edi,OFFSET FLAT:caller_output+8
 mov ecx,6
 rep movsd
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:caller_output
 mov edx,256
 syscall
 jmp caller_next
caller_done:
 mov eax,60
 xor edi,edi
 syscall
FUNC_000575:
 push rbp
 mov rbp,rsp
 push rbx
 push rsi
 push rdi
 mov ebx,DWORD PTR [caller_count]
 cmp ebx,2
 jae caller_bad
 shl ebx,5
 add ebx,OFFSET FLAT:caller_output+32
 mov esi,DWORD PTR [rbp+16]
 mov edi,ebx
 mov ecx,6
 rep movsd
 mov eax,DWORD PTR [rbp+24]
 movzx eax,BYTE PTR [eax+0x86]
 mov DWORD PTR [rbx+24],eax
 mov eax,DWORD PTR [rbp+32]
 movzx eax,BYTE PTR [eax+0x86]
 mov DWORD PTR [rbx+28],eax
 inc DWORD PTR [caller_count]
 xor eax,eax
 pop rdi
 pop rsi
 pop rbx
 pop rbp
 ret
caller_bad:
 mov eax,60
 mov edi,109
 syscall
FUNC_000572:
 mov eax,60
 mov edi,110
 syscall
FUNC_000573:
 mov eax,60
 mov edi,111
 syscall
FUNC_001677:
 mov eax,60
 mov edi,112
 syscall
.section .data
DATA_007754: .long FUNC_001532
DATA_007802: .long FUNC_001677
DATA_008696: .byte 0
DATA_008697: .byte 0
DATA_008698: .byte 0
DATA_008700: .byte 0
DATA_008701: .byte 0
DATA_008702: .long 0
DATA_008703: .long 0
DATA_008704: .long 0
DATA_008707: .byte 0
DATA_009155: .long 0
.section .bss
caller_input: .zero 96
caller_output: .zero 256
caller_body: .zero 338
caller_bank: .zero 86644
.set caller_primary,caller_bank+454
.set caller_candidate,caller_bank+792
caller_count: .zero 4
caller_primitive: .zero 4
caller_height: .zero 4
caller_collider: .zero 4
caller_ref: .zero 4
caller_flags: .zero 4
.balign 16
caller_stack: .zero 1048576
caller_stack_end:
'''
def build_caller(work):
 procedures=(PROOF/'caller-source-procedures.s').read_bytes();proof=json.loads((PROOF/'caller-instruction-proofs.json').read_text())
 if sha(procedures)!=proof['adapted_native_procedures_sha256']:raise ValueError('Archived caller procedure provenance changed')
 text=procedures.decode()+CALLER_WRAPPER;(work/'caller.s').write_text(text)
 subprocess.run(['as','--64',str(work/'caller.s'),'-o',str(work/'caller.o')],check=True);subprocess.run(['ld','-m','elf_x86_64',str(work/'caller.o'),'-o',str(work/'caller')],check=True);return text

def caller_cases():
 rows=[]
 vectors=[('positiveZ',[0,0,4000000000],[10,20,30]),('negativeZ',[0,0,-4000000000],[-10,-20,-30]),('mixed',[111,-222,333],[11,-22,33]),('carry64',[1099511627779,-1099511627777,2147483655],[4294967297,-4294967297,2147483648])]
 for label,body,other in vectors:
  for primary,eligible,frame in [(1,0,1),(1,4,1),(0,4,0)]:
   rows.append({'id':f'{label}/primary{primary}/pair{bool(eligible)}/frame{frame}','body_position_raw':[str(v)for v in body],'primary_parent_position_raw':['999','-777','555'],'other_position_raw':[str(v)for v in other],'body_parent_index':primary,'body_frame57':frame,'other_parent_index':primary,'other_frame57':frame,'eligible_flag':eligible})
 return rows
def caller_packet(row):
 return struct.pack('<4I9q2I',0,row['body_parent_index'],row['body_frame57'],row['other_frame57'],*map(int,row['body_position_raw']),*map(int,row['primary_parent_position_raw']),*map(int,row['other_position_raw']),row['other_parent_index'],row['eligible_flag'])
def caller_decode(raw):
 count=struct.unpack_from('<I',raw,4)[0];entries=[]
 for i in range(count):
  at=32+32*i;entries.append({'relative_entry_hex':raw[at:at+24].hex(),'relative_entry_raw':[str(v)for v in struct.unpack_from('<3q',raw,at)],'body_index':struct.unpack_from('<I',raw,at+24)[0],'other_index':struct.unpack_from('<I',raw,at+28)[0]})
 return {'f570_return_u8':struct.unpack_from('<I',raw)[0],'intercepted_f575_entry_count':count,'body_position_after_hex':raw[8:32].hex(),'entries':entries}

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--work',type=Path);args=p.parse_args();work=args.work or Path(tempfile.mkdtemp(prefix='source-contact-frame-'));work.mkdir(parents=True,exist_ok=True)
 frame_assembly=build_frame(work);caller_assembly=build_caller(work);rows=frame_cases();ordered=rows+list(reversed(rows));raw=execute(work/'frames',b''.join(F.packet(row)for row in ordered),OUTPUT,len(rows))
 for i,row in enumerate(rows):row['expected']=decode_frame(raw[i*OUTPUT:(i+1)*OUTPUT],row)
 calls=caller_cases();ordered=calls+list(reversed(calls));callraw=execute(work/'caller',b''.join(caller_packet(row)for row in ordered),256,len(calls))
 for i,row in enumerate(calls):row['expected']=caller_decode(callraw[i*256:(i+1)*256])
 proof=(PROOF/'caller-instruction-proofs.json').read_bytes();pins={str(path.relative_to(PROJECT)):sha(path.read_bytes())for path in [PROJECT/'tests/fixtures/source_natural_contact_native.json',PROJECT/'tests/fixtures/source_contact_field_native.json',PROJECT/'tests/fixtures/source_footprint_native.json',OLD/'footprint-observed-kernel.s',PROOF/'caller-source-procedures.s',PROOF/'caller-instruction-proofs.json']}
 report={'schema':1,'revision':'original-native-contact-frame-and-caller-v1','source_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'source_commit':N.COMMIT,'scope':'ActualfullF576/F579/F581/F1876 frame observations across17solidmodels andretainedfootprints; nativeF1669/F1670 extra diagnostic calls are explicitly not originalF581operations. SeparatelyactualF569/F570/F1532/F1662/F1335 withF575entryobserverstub, matching57pairframes andpositiveframe-timer/zero-tick context; F572/F573/F1677 abort. Thisboundedcallerproof doesnotexecuteclassification/response/worldframeconversion. No signfix, repairedphysics, render/GPU/liveclaim.','original_provenance_sha256':pins,'generator_sha256':sha(Path(__file__).read_bytes()),'observed_frame_assembly_sha256':sha(frame_assembly.encode()),'caller_assembly_sha256':sha(caller_assembly.encode()),'frame_output_sha256':sha(raw),'caller_output_sha256':sha(callraw),'frame_case_count':len(rows),'caller_case_count':len(calls),'case_count':len(rows)+len(calls),'solid_model_count':17,'fresh_process_runs_per_bank':3,'frame_reverse_repeat_count':len(rows),'caller_reverse_repeat_count':len(calls),'python_expected_frame_or_subtraction_arithmetic':False,'diagnostic_native_math_scope':'native_U_times_D andnative_U_times_negative_D are separateoriginalF1669 calls; native_observer_forward_q is actual32bitC+T_U(-D), usingoriginalF1876ADDsemantics. NativeNEGconstructs-D; no assumptionT(-D)=-T(D). LegacyC-T(D)is separatelylabellednative_center_minus_rotated_difference. native_U_transpose_C is separateF1670(C,U), not exactinverse ororiginalalgorithmcall.','frame_cases':rows,'caller_cases':calls}
 destination=PROJECT/'tests/fixtures/source_contact_frame_native.json';destination.write_text(json.dumps(report,separators=(',',':'))+'\n');(PROOF/'frame-observed-kernel.s').write_text(frame_assembly);(PROOF/'caller-observed-kernel.s').write_text(caller_assembly);(PROOF/'summary.json').write_text(json.dumps({k:v for k,v in report.items()if k not in ['frame_cases','caller_cases']},indent=2)+'\n')
 print('SOURCE CONTACT FRAME:',len(rows),'framecases;',len(calls),'boundedcallercases;3fresh+reverse;work',work);print('FIXTURE SHA256',sha(destination.read_bytes()))
if __name__=='__main__':main()
