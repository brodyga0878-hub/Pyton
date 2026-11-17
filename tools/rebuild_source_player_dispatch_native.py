#!/usr/bin/env python3
"""Replay independently DOS-checked F1041/F1043/F1044/F1045 player callbacks.

The whole arithmetic closure executes through a reviewed native64 stack ABI
adapter. F606 is an explicit observer/response boundary; sound is observed.
This does not execute F1019 admission, the full scheduler or a universal tick.
"""
from __future__ import annotations
import argparse,hashlib,importlib.util,inspect,json,random,re,struct,subprocess,tempfile
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
PROOF=PROJECT/'validation/player-dispatch-2026-11-17/player-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_player_dispatch_native.json'
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
NUMBERS=[1041,1043,1044,1045,585,584,611,609,1520,1519,1552,1466,1656,1523,1521,1502,603,599,607,601,602,1333,1338,1482,1483,1496,1511,1512,1515,1516,1532,1657,1658,1660,1661,1670]
OBJECT=338;BANK=0x74+256*OBJECT;INPUT=80+OBJECT*3;OUTPUT=1214
OPS={'prepare_f1041':0,'manual_f1043':1,'drift_f1044':2,'drift_f1045':3}
TRACE=[1041,1043,1044,1045,585,603,609,599,607,1512]
FIELDS=['frame_ticks_u32','spin_elapsed_s32','player_mode_u8','flight_flags_u8','set_speed_s32','damping_flags_u8','reference_velocity_s32','forward_key_u8','reverse_key_u8','spin_xyz_s32','player_index_u32','player_roll_s16','drift_ticks_low_u32','drift_ticks_high_u32']
PROFILE='dos-firstenc-player-control-dispatch-v1'

def sha(raw):return hashlib.sha256(raw).hexdigest()
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def s32(x):return (x&0x7fffffff)-(x&0x80000000)
def dos_source(source):
 start=source.index('\t\tcmp byte [DATA_007692]',source.index('FUNC_001043:'));end=source.index('\n\tJUMP_004316:',start)
 return source[:start]+'''\t\tcmp byte [DATA_007692],0x0
\t\tjnz JUMP_004315
\t\tmov dword [ebp-0x4],0x7fff
\t\tjmp short JUMP_004317
\tJUMP_004315:
\t\tcmp byte [DATA_007694],0x0
\t\tjnz JUMP_004316
\t\tmov dword [ebp-0x4],0xffff8001
\t\tjmp short JUMP_004317
'''+source[end:]

def reprove(args):
 n=load('dispatch_original_proof',PROJECT/'tools/rebuild_source_natural_contact_native.py')
 exe=args.exe.read_bytes();raw=args.asm.read_bytes()
 if sha(exe)!=EXE_SHA or sha(raw)!=ASM_SHA:raise ValueError('Unreviewed original game/source')
 source=dos_source(raw.decode().replace('\r\n','\n'));data=args.data.read_text()
 signature=bytes.fromhex('558bec83c4e8538b5d08a1')
 if exe.find(signature)!=0x32ce8 or exe.find(signature,0x32ce9)>=0:raise ValueError('Unreviewed F1041 anchor')
 resolver=inspect.getsource(n.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_001041',0x441ee8)")
 resolver=resolver.replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
 ns=n.__dict__.copy();exec(resolver,ns)
 bodies,records,dis,_,aliases=ns['proof'](source,data,exe,args.exe,NUMBERS)
 for key,record in records.items():
  at=record['executable_offset'];record['hex']=exe[at:at+record['byte_length']].hex()
 selected='\n'.join(bodies[k] for k in NUMBERS)
 symbols={re.sub(r'(FUNC_\d{6})_[A-Za-z0-9_]+',r'\1',s)for s in re.findall(r'\b(?:DATA_\d+|FUNC_\d+)(?:_[A-Za-z0-9_]+)?|_abs',selected)}
 bindings={s:aliases[s] for s in sorted(symbols)}
 image=n.G.Image(exe);at=image.offset(aliases['DATA_006159'],12);table=exe[at:at+12]
 if table!=bytes.fromhex('120303030502010101010000'):raise ValueError('Angular normalization table changed')
 args.proof_dir.mkdir(parents=True,exist_ok=True)
 (args.proof_dir/'source-procedures.s').write_text(selected)
 abs_raw=n.G.ABS_DOS
 if exe[0x67038:0x67038+len(abs_raw)]!=abs_raw:raise ValueError('OriginalDOS abs body changed')
 metadata={'abs':{'virtual_address':0x476238,'executable_offset':0x67038,'hex':abs_raw.hex(),'sha256':sha(abs_raw)},'schema':'starfrontier-original-player-dispatch-instruction-proof-v1','source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'procedures':records,'bindings':bindings,'source_procedure_sha256':{str(n):sha(bodies[n].encode())for n in NUMBERS},'source_procedures_sha256':sha(selected.encode()),'decrement_table_hex':table.hex(),'all_full_procedure_instructions_equal':True,'DOS_F1043_restoration':'Only active-low original forward/reverse keys; pressed-key paths jump directly to F599 and suppress sound callback. JJFFE added key branches and removed both jumps.','host_adaptations':['Established reviewed64bit cdecl stack/register ABI retaining32bit raw arithmetic and low-address data/stack','F585 andF1670 scratch locals8→16 for two host pops','F611 local table index EBX→RBX only for host stack address width','Indirect pointer slots widened to8bytes without changing source data fields','F606 request/response boundary observer only; the frame math is independently covered by the raw-bank control suite','F1910 sound request observer only; exact original parameter words and body-pointer identity checked'],'scope':'Whole original F1041/F1043/F1044/F1045 plus actual angular, gravity, thrust, speed and drift arithmetic closure. F606 and sound callbacks are explicit boundaries, not executed full bodies. No F1019 admission, universal callback order, complete world scheduler or live Main route claim.'}
 (args.proof_dir/'instruction-proof.json').write_text(json.dumps(metadata,indent=2)+'\n')
 (args.proof_dir/'dos-disassembly.txt').write_text('\n'.join('F'+k+'\n'+v for k,v in dis.items()))
 return metadata,selected

def verify_archived(metadata,source):
 if sha(source.encode())!=metadata['source_procedures_sha256'] or not metadata['all_full_procedure_instructions_equal'] or metadata['source_executable_sha256']!=EXE_SHA or metadata['source_assembly_sha256']!=ASM_SHA or set(metadata['procedures'])!=set(map(str,NUMBERS)) or metadata['decrement_table_hex']!='120303030502010101010000':raise ValueError('Archived original dispatch proof changed')
 if sha(bytes.fromhex(metadata['abs']['hex']))!=metadata['abs']['sha256']:raise ValueError('Archived DOS abs body changed')
 n=load('dispatch_replay_original',PROJECT/'tools/rebuild_source_natural_contact_native.py')
 bodies={k:n.G.block(source,k)for k in NUMBERS}
 for k in NUMBERS:
  record=metadata['procedures'][str(k)]
  compiled=n.C.J.instructions(n.C.compile32(bodies[k],metadata['bindings'],'FUNC_%06d'%k,record['virtual_address']))
  if sha('\n'.join(n.canonical(compiled)).encode())!=record['normalized_instruction_sha256'] or sha(bytes.fromhex(record['hex']))!=record['sha256']:raise ValueError('Archived procedure no longer reassembles to original instructions F'+str(k))

def assembly(source):
 abi=load('dispatch_host_adapter',PROJECT/'recovered-history/ground_harness/tools/native_reference.py')
 selected=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',source)+'\nFUNC_999999:\nret\n'
 selected=re.sub(r'add esp,0x(f[0-9a-f]{7})',lambda m:'add esp,-0x%x'%(0x100000000-int(m[1],16)),selected)
 selected=re.sub(r'\[ebp\+0x(f[0-9a-f]{7})(?=[+\]])',lambda m:'[ebp-0x%x'%(0x100000000-int(m[1],16)),selected)
 lines,_=abi.procedures(selected,NUMBERS);text='\n'.join(lines)
 for k in (585,1670):
  old=f'FUNC_{k:06d}:\npush rbp\nmov rbp,rsp\nadd rsp,-8'
  if text.count(old)!=1:raise ValueError('Unreviewed two-pop scratch frame '+str(k))
  text=text.replace(old,old.replace('rsp,-8','rsp,-16'))
 if text.count('[rbp+ebx-0xe]')!=1:raise ValueError('UnreviewedF611 local table')
 text=text.replace('[rbp+ebx-0xe]','[rbp+rbx-0xe]')
 for k in TRACE:text=text.replace(f'FUNC_{k:06d}:',f'FUNC_{k:06d}:\n'+trace(k))
 return '.intel_syntax noprefix\n.code64\n.section .text\n.global _start\n'+text+'\n'+WRAPPER.replace('@INPUT@',str(INPUT)).replace('@OUTPUT@',str(OUTPUT)).replace('@BANK@',str(BANK)).replace('@TRACE606@',trace(606))

def trace(k):
 return f'''pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,16
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],{k}
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq
'''

_MOTION_ORIGINS=None
def base_row(rng,i,op):
 # Raw initial body/parent physics samples already admitted by the independent
 # fixed-frame native bank; only control/angle fields are varied here.
 global _MOTION_ORIGINS
 if _MOTION_ORIGINS is None:
  corpus=json.loads((PROJECT/'tests/fixtures/source_motion_native.json').read_text());_MOTION_ORIGINS=[r for r in corpus['cases']if int(r['operation'])in(6,7)]
 origins=_MOTION_ORIGINS
 origin=origins[i%len(origins)];body=bytearray.fromhex(origin['initial_body_hex']);parent=bytearray.fromhex(origin['parent_hex'])
 matrices=[(2147483647,0,0,0,2147483647,0,0,0,2147483647),(0,0,-2147483648,0,2147483647,0,2147483647,0,0),(1518500249,0,1518500249,0,2147483647,0,-1518500249,0,1518500249)]
 struct.pack_into('<9i',body,0,*matrices[i%3]);body[0x24]=[0,1,18,127,128,255][i%6];body[0x57]=0;body[0x86]=114
 struct.pack_into('<I',body,0x82,[24,38,53,58,59,120][i%6])
 struct.pack_into('<3h',body,0xb0,*[rng.choice([0,14,-14,15,-15,20,-20,2555,-2555,32767,-32768])for _ in range(3)])
 struct.pack_into('<3h',body,0x110,*[rng.randint(-32768,32767)for _ in range(3)])
 body[0x14d]=[0,1,13,127,128,129,255][i%7]
 ints=[0,1,-1,256,-256,257,-257,0x7fffffff,-0x80000000]
 ticks=[0,1,2,3,49710,65535,65536,0x7fffffff,0x80000000,0xfffffffe,0xffffffff]
 g={'frame_ticks_u32':ticks[i%len(ticks)],'spin_elapsed_s32':[-0x80000000,0,39999999,40000000,40000001,0x7fffffff][i%6],'player_mode_u8':[0,2,36,255][i%4],'flight_flags_u8':[0,1,2,255][(i//4)%4],'set_speed_s32':rng.choice(ints),'damping_flags_u8':[0,2,255][i%3],'reference_velocity_s32':[rng.choice(ints)for _ in range(3)],'forward_key_u8':[1,0,1,0][i%4],'reverse_key_u8':[1,1,0,0][i%4],'spin_xyz_s32':[rng.choice(ints)for _ in range(3)],'player_index_u32':114 if i%3 else 1,'player_roll_s16':rng.choice([-32768,-2555,-1,0,1,2555,32767]),'drift_ticks_low_u32':ticks[(i+3)%len(ticks)],'drift_ticks_high_u32':[0,1,0x7fffffff,0x80000000,0xffffffff][i%5]}
 if op=='manual_f1043' and i<64:
  struct.pack_into('<9i',body,0,*matrices[0])
  directed=[0,1,-1,255,256,257,258,-255,-256,-257,-258,0x7fffffff,-0x80000000]
  struct.pack_into('<3i',body,0x8c,directed[i%len(directed)],directed[(i+3)%len(directed)],directed[(i+7)%len(directed)])
  g['reference_velocity_s32']=[0,0,0];g['damping_flags_u8']=2
 return {'name':op+'/'+str(i),'operation':op,'body_before_hex':body.hex(),'parent_hex':parent.hex(),'globals_before':g,'frame_response_body_hex':''}

def packet(row):
 g=row['globals_before'];header=[OPS[row['operation']],g['frame_ticks_u32'],g['spin_elapsed_s32'],g['player_mode_u8'],g['flight_flags_u8'],g['set_speed_s32'],g['damping_flags_u8'],*g['reference_velocity_s32'],g['forward_key_u8'],g['reverse_key_u8'],*g['spin_xyz_s32'],g['player_index_u32'],g['player_roll_s16'],g['drift_ticks_low_u32'],g['drift_ticks_high_u32'],int(bool(row['frame_response_body_hex']))]
 assert len(header)==20
 return struct.pack('<20I',*[x&0xffffffff for x in header])+bytes.fromhex(row['body_before_hex'])+bytes.fromhex(row['parent_hex'])+(bytes.fromhex(row['frame_response_body_hex'])if row['frame_response_body_hex']else bytes(OBJECT))

def decode(raw,row):
 magic,ntrace,nrequest,boundary,response,bank_changed,roll,spin_x,spin_y,spin_z=struct.unpack_from('<10I',raw)
 if magic!=0x50444f53 or ntrace>16 or nrequest>2 or bank_changed or raw[-64:]!=b'\xa5'*64:raise ValueError('Native pointer/bank/canary/trace guard failed '+row['name'])
 trace_rows=list(struct.unpack_from('<16I',raw,1054))[:ntrace];requests=[]
 for i in range(nrequest):
  kind,a,b,c=struct.unpack_from('<4I',raw,1118+i*16)
  if kind==606:requests.append({'kind':'F606','body_hex_at_call':raw[716:1054].hex()})
  elif kind==1910:requests.append({'kind':'F1910','args':[a,b,c]})
  else:raise ValueError('Unknown callback')
 g=json.loads(json.dumps(row['globals_before']));g['player_roll_s16']=((roll&32767)-(roll&32768));g['spin_xyz_s32']=[s32(spin_x),s32(spin_y),s32(spin_z)]
 if raw[378:716].hex()!=row['parent_hex']:raise ValueError('Native parent mutated')
 return {'body_after_hex':raw[40:378].hex(),'globals_after':g,'requests':requests,'source_order':['F'+str(k)for k in trace_rows],'frame_selection_requested':bool(boundary),'frame_boundary_body_hex':raw[716:1054].hex()if boundary else'','response_applied':bool(response)}

def generate(proof,output):
 metadata=json.loads((proof/'instruction-proof.json').read_text());source=(proof/'source-procedures.s').read_text();verify_archived(metadata,source)
 native=assembly(source);rng=random.Random(0x10411043)
 rows=[base_row(rng,i,op)for op,count in [('prepare_f1041',256),('manual_f1043',128),('drift_f1044',96),('drift_f1045',96)]for i in range(count)]
 with tempfile.TemporaryDirectory(prefix='player-dispatch-native-')as directory:
  p=Path(directory);(p/'kernel.s').write_text(native)
  subprocess.run(['as','--64','-o',str(p/'kernel.o'),str(p/'kernel.s')],check=True);subprocess.run(['ld','-o',str(p/'kernel'),str(p/'kernel.o')],check=True)
  def run(items):
   payload=b''.join(packet(r)for r in items);r=subprocess.run([str(p/'kernel')],input=payload,capture_output=True,check=True,timeout=90)
   if r.stderr or len(r.stdout)!=len(items)*OUTPUT:raise ValueError('Native output length or stderr differs')
   return r.stdout
  probe=run(rows)
  bank=json.loads((PROJECT/'tests/fixtures/source_reference_bank_native.json').read_text());responses=[r for r in bank['cases']if r['operation']=='select_parent']
  for i,row in enumerate(rows[:256]):
   observed=decode(probe[i*OUTPUT:(i+1)*OUTPUT],row)
   if observed['frame_selection_requested']and i%2==0:
    replacement=bytearray.fromhex(observed['frame_boundary_body_hex']);source_body=bytes.fromhex(responses[i%len(responses)]['expected_body_hex'])
    replacement[0x25:0x57]=source_body[0x25:0x57];replacement[0x8c:0x98]=source_body[0x8c:0x98]
    row['frame_response_body_hex']=replacement.hex();row['response_origin']='independent-source-reference-bank-native-fields'
  prior=base_row(rng,777,'prepare_f1041');prior['globals_before'].update(frame_ticks_u32=49710,spin_elapsed_s32=0,player_mode_u8=2,flight_flags_u8=1,forward_key_u8=1,reverse_key_u8=1);body=bytearray.fromhex(prior['body_before_hex']);body[0x14d]=0;prior['body_before_hex']=body.hex()
  for i in range(64):
   row=json.loads(json.dumps(prior));row['name']='consecutive-native/'+str(i);row['sequence_step']=i;rows.append(row)
   actual=decode(run([row]),row);prior=row.copy();prior['body_before_hex']=actual['body_after_hex'];prior['globals_before']=actual['globals_after']
  output_runs=[run(rows)for _ in range(3)]
  if len(set(output_runs))!=1:raise ValueError('Unstable fresh native output')
  backwards=run(list(reversed(rows)))
  if backwards!=b''.join(output_runs[0][i*OUTPUT:(i+1)*OUTPUT]for i in reversed(range(len(rows)))):raise ValueError('Native case order leakage')
  for i,row in enumerate(rows):row['expected']=decode(output_runs[0][i*OUTPUT:(i+1)*OUTPUT],row)
 output.parent.mkdir(parents=True,exist_ok=True)
 result={'schema':'starfrontier-source-player-dispatch-native-v1','profile':PROFILE,'source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'instruction_proof_sha256':sha((proof/'instruction-proof.json').read_bytes()),'source_procedures_sha256':sha(source.encode()),'host_assembly_sha256':sha(native.encode()),'input_packets_sha256':sha(b''.join(packet(r)for r in rows)),'native_output_sha256':sha(output_runs[0]),'case_count':len(rows),'case_counts_by_operation':{op:sum(r['operation']==op for r in rows)for op in OPS},'consecutive_native_steps':64,'frame_response_cases':sum(bool(r['frame_response_body_hex'])for r in rows),'fresh_process_runs':3,'reverse_repeat_cases':len(rows),'all_body_parent_bank_canaries_unchanged':True,'expected_arithmetic_calculated_in_python':False,'source_dependencies_sha256':{'tests/fixtures/source_motion_native.json':sha((PROJECT/'tests/fixtures/source_motion_native.json').read_bytes()),'tests/fixtures/source_reference_bank_native.json':sha((PROJECT/'tests/fixtures/source_reference_bank_native.json').read_bytes()),'recovered-history/ground_harness/tools/native_reference.py':sha((PROJECT/'recovered-history/ground_harness/tools/native_reference.py').read_bytes())},'callback_policy':{'F606':'Observed request; optional separately supplied raw response copied at the exact original boundary, no F606 body executed','F1910':'Sound request observer preserving original arguments and no effects'},'scope':metadata['scope'],'cases':rows}
 output.write_text(json.dumps(result,indent=2)+'\n');(proof/'player-dispatch-native.s').write_text(native)
 print(json.dumps({'case_count':len(rows),'frame_response_cases':result['frame_response_cases'],'fixture_sha256':sha(output.read_bytes()),'output':str(output)},indent=2))

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--refresh-original-proof',action='store_true');a=p.parse_args()
 if a.refresh_original_proof:reprove(a)
 generate(a.proof_dir,a.output)

WRAPPER=r'''
_abs:
 push rbp
 mov rbp,rsp
 mov eax,DWORD PTR [rbp+16]
 test eax,eax
 jge abs_nonnegative
 mov edx,eax
 neg edx
 jmp abs_return
abs_nonnegative:
 mov edx,eax
abs_return:
 mov eax,edx
 pop rbp
 ret
FUNC_000606:
@TRACE606@
 push rbp
 mov rbp,rsp
 pushfq
 push rax
 push rcx
 push rdx
 push rsi
 push rdi
 cmp DWORD PTR [rbp+16],OFFSET FLAT:body
 jne bad_pointer
 cmp DWORD PTR [rbp+24],OFFSET FLAT:bank
 jne bad_pointer
 mov DWORD PTR [boundary_called],1
 mov esi,OFFSET FLAT:body
 mov edi,OFFSET FLAT:boundary_body
 mov ecx,338
 rep movsb
 mov eax,DWORD PTR [request_count]
 cmp eax,2
 jae bad_trace
 shl eax,4
 mov DWORD PTR [requests+eax],606
 inc DWORD PTR [request_count]
 cmp DWORD PTR [input+76],0
 je frame_response_done
 mov esi,OFFSET FLAT:input+756
 mov edi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 mov DWORD PTR [response_applied],1
frame_response_done:
 pop rdi
 pop rsi
 pop rdx
 pop rcx
 pop rax
 popfq
 pop rbp
 ret
FUNC_001910:
 push rbp
 mov rbp,rsp
 pushfq
 push rax
 push rcx
 push rdx
 cmp DWORD PTR [rbp+40],OFFSET FLAT:body
 jne bad_pointer
 mov eax,DWORD PTR [request_count]
 cmp eax,2
 jae bad_trace
 shl eax,4
 mov DWORD PTR [requests+eax],1910
 mov ecx,DWORD PTR [rbp+16]
 mov DWORD PTR [requests+eax+4],ecx
 mov ecx,DWORD PTR [rbp+24]
 mov DWORD PTR [requests+eax+8],ecx
 mov ecx,DWORD PTR [rbp+32]
 mov DWORD PTR [requests+eax+12],ecx
 inc DWORD PTR [request_count]
 pop rdx
 pop rcx
 pop rax
 popfq
 pop rbp
 ret
bad_trace:
 mov edi,91
 jmp finish
bad_pointer:
 mov edi,92
 jmp finish
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 mov esp,OFFSET FLAT:stack_end
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:input
 add rsi,r8
 mov edx,@INPUT@
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,@INPUT@
 jne read_more
 cld
 mov edi,OFFSET FLAT:body_before
 mov ecx,370
 mov al,0xa5
 rep stosb
 mov edi,OFFSET FLAT:bank_before
 mov ecx,@BANK@+32
 mov al,0xa5
 rep stosb
 mov esi,OFFSET FLAT:input+80
 mov edi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 movzx eax,BYTE PTR [body+0x56]
 imul eax,338
 add eax,OFFSET FLAT:bank+0x74
 mov DWORD PTR [parent_address],eax
 mov edi,eax
 mov esi,OFFSET FLAT:input+418
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:bank
 mov edi,OFFSET FLAT:bank_copy
 mov ecx,@BANK@
 rep movsb
 mov edi,OFFSET FLAT:output
 mov ecx,@OUTPUT@
 xor eax,eax
 rep stosb
 mov edi,OFFSET FLAT:boundary_body
 mov ecx,338+64+32+16
 rep stosb
 mov DWORD PTR [trace_count],eax
 mov DWORD PTR [request_count],eax
 mov DWORD PTR [boundary_called],eax
 mov DWORD PTR [response_applied],eax
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [DATA_009155],eax
 mov eax,DWORD PTR [input+8]
 mov DWORD PTR [DATA_008867],eax
 mov eax,DWORD PTR [input+12]
 mov BYTE PTR [DATA_008870],al
 mov eax,DWORD PTR [input+16]
 mov BYTE PTR [DATA_008871],al
 mov eax,DWORD PTR [input+20]
 mov DWORD PTR [DATA_008918],eax
 mov eax,DWORD PTR [input+24]
 mov BYTE PTR [DATA_009046],al
 mov eax,DWORD PTR [input+28]
 mov DWORD PTR [DATA_008839],eax
 mov eax,DWORD PTR [input+32]
 mov DWORD PTR [DATA_008840],eax
 mov eax,DWORD PTR [input+36]
 mov DWORD PTR [DATA_008841],eax
 mov eax,DWORD PTR [input+40]
 mov BYTE PTR [DATA_007692],al
 mov eax,DWORD PTR [input+44]
 mov BYTE PTR [DATA_007694],al
 mov eax,DWORD PTR [input+48]
 mov DWORD PTR [DATA_008708],eax
 mov eax,DWORD PTR [input+52]
 mov DWORD PTR [DATA_008709],eax
 mov eax,DWORD PTR [input+56]
 mov DWORD PTR [DATA_008710],eax
 mov eax,DWORD PTR [input+60]
 mov DWORD PTR [DATA_008857],eax
 mov eax,DWORD PTR [input+64]
 mov WORD PTR [DATA_008933],ax
 mov eax,DWORD PTR [input+68]
 mov DWORD PTR [DATA_008868],eax
 mov eax,DWORD PTR [input+72]
 mov DWORD PTR [DATA_008869],eax
 push OFFSET FLAT:body
 cmp DWORD PTR [input],0
 je operation1041
 cmp DWORD PTR [input],1
 je operation1043
 cmp DWORD PTR [input],2
 je operation1044
 cmp DWORD PTR [input],3
 jne bad_trace
 call FUNC_001045
 jmp operation_done
operation1041:
 call FUNC_001041
 jmp operation_done
operation1043:
 call FUNC_001043
 jmp operation_done
operation1044:
 call FUNC_001044
operation_done:
 add rsp,8
 mov DWORD PTR [output],0x50444f53
 mov eax,DWORD PTR [trace_count]
 mov DWORD PTR [output+4],eax
 mov eax,DWORD PTR [request_count]
 mov DWORD PTR [output+8],eax
 mov eax,DWORD PTR [boundary_called]
 mov DWORD PTR [output+12],eax
 mov eax,DWORD PTR [response_applied]
 mov DWORD PTR [output+16],eax
 movsx eax,WORD PTR [DATA_008933]
 mov DWORD PTR [output+24],eax
 mov eax,DWORD PTR [DATA_008708]
 mov DWORD PTR [output+28],eax
 mov eax,DWORD PTR [DATA_008709]
 mov DWORD PTR [output+32],eax
 mov eax,DWORD PTR [DATA_008710]
 mov DWORD PTR [output+36],eax
 mov esi,OFFSET FLAT:body
 mov edi,OFFSET FLAT:output+40
 mov ecx,338
 rep movsb
 mov esi,DWORD PTR [parent_address]
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:boundary_body
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:trace_codes
 mov ecx,64
 rep movsb
 mov esi,OFFSET FLAT:requests
 mov ecx,32
 rep movsb
 mov esi,OFFSET FLAT:body_before
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:body_after
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:bank_before
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:bank_after
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:bank
 mov edi,OFFSET FLAT:bank_copy
 mov ecx,@BANK@
 repe cmpsb
 sete al
 xor al,1
 movzx eax,al
 mov DWORD PTR [output+20],eax
 mov esi,OFFSET FLAT:output
 mov edx,@OUTPUT@
write_more:
 mov eax,1
 mov edi,1
 syscall
 test eax,eax
 jle write_failed
 add esi,eax
 sub edx,eax
 jnz write_more
 jmp next_case
write_failed:
 mov edi,93
 jmp finish
finished:
 xor edi,edi
finish:
 mov eax,60
 syscall
.section .data
DATA_006143: .quad FUNC_000585
DATA_006151: .quad FUNC_000599
DATA_006153: .quad FUNC_000603
DATA_006154: .quad FUNC_000606
DATA_006155: .quad FUNC_000607
DATA_006157: .quad FUNC_000609
DATA_006159: .byte 18,3,3,3
DATA_006160: .byte 5,2,1,1
DATA_006161: .byte 1,1,0,0
DATA_007719: .quad FUNC_001520
DATA_007722: .quad FUNC_001496
DATA_007731: .quad FUNC_001483
DATA_007738: .quad FUNC_001502
DATA_007744: .quad FUNC_001512
DATA_007747: .quad FUNC_001515
DATA_007748: .quad FUNC_001516
DATA_007754: .quad FUNC_001532
DATA_009133: .long bank
.section .bss
.balign 16
input: .zero @INPUT@
body_before: .zero 16
body: .zero 338
body_after: .zero 16
bank_before: .zero 16
bank: .zero @BANK@
bank_after: .zero 16
bank_copy: .zero @BANK@
output: .zero @OUTPUT@
parent_address: .zero 4
boundary_body: .zero 338
trace_codes: .zero 64
requests: .zero 32
trace_count: .zero 4
request_count: .zero 4
boundary_called: .zero 4
response_applied: .zero 4
DATA_007692: .zero 1
DATA_007694: .zero 1
.balign 4
DATA_008708: .zero 4
DATA_008709: .zero 4
DATA_008710: .zero 4
DATA_008839: .zero 4
DATA_008840: .zero 4
DATA_008841: .zero 4
DATA_008857: .zero 4
DATA_008867: .zero 4
DATA_008868: .zero 4
DATA_008869: .zero 4
DATA_008870: .zero 1
DATA_008871: .zero 1
.balign 4
DATA_008918: .zero 4
DATA_008933: .zero 2
DATA_009046: .zero 1
.balign 4
DATA_009155: .zero 4
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
'''

if __name__=='__main__':main()
