#!/usr/bin/env python3
"""Replay all five original DOS input procedures; no private EXE needed by default.

The original instructions are checked by static32 assembly, then execute through
the project's reviewed native64 stack ABI. GUI1445 returns a supplied raw word;
F931 is a typed request observer, not an implemented event handler.
"""
from __future__ import annotations
import argparse, hashlib, importlib.util, inspect, json, random, re, struct, subprocess, tempfile
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
PROOF=PROJECT/'validation/player-cycle-2026-11-17/input-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_player_input_native.json'
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
PROFILE='dos-firstenc-player-input-v1'
NUMBERS=[1037,1038,1039,1040,1121]
OPS={'throttle_f1037':0,'accumulate_f1038':1,'view_f1039':2,'auxiliary_f1040':3,'speed_increment_f1121':4}
GLOBALS=['input_gate_s8','system_frame_ticks_u32','speed_multiplier_u32','forward_key_u8','reverse_key_u8','throttle_key_u8','aux_key1_u8','aux_key2_u8','mouse_buttons_u8']
SYMBOLS=['DATA_008630','DATA_009122','DATA_007690','DATA_007692','DATA_007694','DATA_007696','DATA_007708','DATA_007711','DATA_009163']
WIDTHS=[1,4,4,1,1,1,1,1,1]
ROOT=0x4000;BODY=338;INPUT=48+BODY+ROOT;OUTPUT=160+BODY+ROOT+64
def sha(raw):return hashlib.sha256(raw).hexdigest()
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
def s32(x):return (x&0x7fffffff)-(x&0x80000000)
def segments(before,after):
 result=[];i=0
 while i<len(before):
  if before[i]==after[i]:i+=1;continue
  start=i
  while i<len(before)and before[i]!=after[i]:i+=1
  result.append({'offset':start,'hex':after[start:i].hex()})
 return result
def root_for(row):
 root=bytearray([row['root_fill_u8']])*ROOT
 for segment in row['root_before_segments']:root[segment['offset']:segment['offset']+len(bytes.fromhex(segment['hex']))]=bytes.fromhex(segment['hex'])
 return bytes(root)
def reprove(args):
 n=load('input_original_proof',PROJECT/'tools/rebuild_source_natural_contact_native.py')
 exe=args.exe.read_bytes();raw=args.asm.read_bytes()
 if sha(exe)!=EXE_SHA or sha(raw)!=ASM_SHA:raise ValueError('Unreviewed original executable/source')
 source=raw.decode().replace('\r\n','\n');start=source.index('FUNC_CheckInputWrap:');end=source.index('FUNC_001038:',start);source=source[:start]+source[end:]
 restored=n.G.block((args.proof_dir/'source-procedures.s').read_text(),1038)
 start=source.index('FUNC_001038:');end=source.index('FUNC_001039:',start);source=source[:start]+restored+'\n'+source[end:]
 resolver=inspect.getsource(n.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_001037',0x441c18)").replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
 namespace=n.__dict__.copy();exec(resolver,namespace)
 bodies,records,dis,_,aliases=namespace['proof'](source,args.data.read_text(),exe,args.exe,NUMBERS)
 metadata=json.loads((args.proof_dir/'instruction-proof.json').read_text())
 for k,record in records.items():
  at=record['executable_offset'];record['hex']=exe[at:at+record['byte_length']].hex()
 if records!=metadata['procedures']:raise ValueError('Reproved original full procedure records changed')
 # Preserve the reviewed archive's harmless spacing; the new resolver has
 # independently matched every complete procedure against the private EXE.
 selected=(args.proof_dir/'source-procedures.s').read_text()
 metadata['procedures']=records;metadata['source_procedures_sha256']=sha(selected.encode())
 (args.proof_dir/'instruction-proof.json').write_text(json.dumps(metadata,indent=2)+'\n');(args.proof_dir/'source-procedures.s').write_text(selected)
 (args.proof_dir/'dos-disassembly.txt').write_text('\n'.join('F'+str(k)+'\n'+v for k,v in dis.items()))
def verify(metadata,source):
 if sha(source.encode())!=metadata['source_procedures_sha256']or metadata['source_executable_sha256']!=EXE_SHA or metadata['source_assembly_sha256']!=ASM_SHA or not metadata['all_full_procedure_instructions_equal']or set(metadata['procedures'])!=set(map(str,NUMBERS)):raise ValueError('Archived input proof changed')
 n=load('input_archived_proof',PROJECT/'tools/rebuild_source_natural_contact_native.py')
 for number in NUMBERS:
  record=metadata['procedures'][str(number)];body=n.G.block(source,number)
  compiled=n.C.J.instructions(n.C.compile32(body,metadata['bindings'],'FUNC_%06d'%number,record['virtual_address']))
  if sha('\n'.join(n.canonical(compiled)).encode())!=record['normalized_instruction_sha256']or sha(bytes.fromhex(record['hex']))!=record['sha256']:raise ValueError('Original instruction comparison failed F'+str(number))
def trace(number):
 return f'''pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,16
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],{number}
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq
'''
def assembly(source):
 abi=load('input_host_abi',PROJECT/'recovered-history/ground_harness/tools/native_reference.py')
 selected=source+'\nFUNC_999999:\nret\n'
 selected=re.sub(r'add esp,0x(f[0-9a-f]{7})',lambda m:'add esp,-0x%x'%(0x100000000-int(m[1],16)),selected)
 lines,_=abi.procedures(selected,NUMBERS);body='\n'.join(lines)
 old='FUNC_001038:\npush rbp\nmov rbp,rsp\nadd rsp,-8'
 if body.count(old)!=1:raise ValueError('Unreviewed original F1038 two-pop frame')
 body=body.replace(old,old.replace('rsp,-8','rsp,-16'))
 for number in NUMBERS:body=body.replace('FUNC_%06d:'%number,'FUNC_%06d:\n'%number+trace(number))
 loads=[];saves=[];storage=[]
 for index,(symbol,width)in enumerate(zip(SYMBOLS,WIDTHS)):
  loads.append(f'mov eax,DWORD PTR [input+{4+index*4}]\nmov {"BYTE"if width==1 else"DWORD"} PTR [{symbol}],{"al"if width==1 else"eax"}')
  saves.append((f'movsx eax,BYTE PTR [{symbol}]'if index==0 else f'movzx eax,BYTE PTR [{symbol}]'if width==1 else f'mov eax,DWORD PTR [{symbol}]')+f'\nmov DWORD PTR [output+{96+index*4}],eax')
  storage.append(symbol+': .zero '+str(width))
 calls='\n'.join(f'cmp DWORD PTR [input],{code}\nje input_op{code}'for code in range(5))+'\njmp bad_trace\n'
 for op,code in OPS.items():
  number=int(op[-4:]);calls+=f'input_op{code}:\n'+('mov eax,DWORD PTR [input+44]\npush rax\n'if code==4 else'push OFFSET FLAT:body\n')+f'call FUNC_{number:06d}\nadd rsp,8\n'
  if code==4:calls+='mov DWORD PTR [output+20],eax\n'
  calls+='jmp operation_done\n'
 wrapper=WRAPPER.replace('@LOADS@','\n'.join(loads)).replace('@SAVES@','\n'.join(saves)).replace('@STORAGE@','\n'.join(storage)).replace('@CALLS@',calls).replace('@TRACEGUI@',trace(1445)).replace('@TRACE931@',trace(931))
 wrapper=wrapper.replace('@INPUT@',str(INPUT)).replace('@OUTPUT@',str(OUTPUT)).replace('@ROOT@',str(ROOT))
 return '.intel_syntax noprefix\n.code64\n.section .text\n.global _start\n'+body+'\n'+wrapper
def case(rng,index,operation):
 body=bytearray(rng.randbytes(BODY));body[0xd1]=[0,3,4,127,128,255][index%6]
 speeds=[-0x80000000,-1,0,1,0x7fff,0x3ffffff,0x4000000,0x7fffffe,0x7ffffff,0x8000000,0x7fffffff]
 ticks=[0,1,63,64,255,256,49710,0x40000000,0x7fffffff,0xffffffff]
 multipliers=[0,1,16,17,70,255,0xffffff10,0xffffff11,0xffffffff]
 root=bytearray([0xa5])*ROOT
 struct.pack_into('<I',root,0xd0,[0,0xffff,0xffff0000,0x7fff8000,0xffffffff,rng.getrandbits(32)][index%6])
 struct.pack_into('<i',root,0xdc,[-0x80000000,0,39999999,40000000,40000001,0x7fffffff][index%6])
 root[0xe9]=[0,1,0x80,0x81,0xff][(index//3)%5];root[0xea]=[0,2,3,4,5,6,127,128,255][index%9]
 struct.pack_into('<i',root,0x1b8,speeds[index%len(speeds)])
 struct.pack_into('<2h',root,0x204,*[rng.choice([-32768,-16385,-16384,-16383,-1,0,1,16383,16384,32767])for _ in range(2)])
 root[0x212]=[0,0x20,0xff][(index//5)%3]
 for j in range(3):root[0x3f54+j]=[0,1,255][(index//(j+1))%3]
 g=dict(zip(GLOBALS,[-1 if index%7 else 0,ticks[(index//2)%len(ticks)],multipliers[(index//3)%len(multipliers)],[0,1,255][index%3],[0,1,255][(index//3)%3],[0,1][(index//2)%2],[0,1,255][index%3],[0,1,255][(index//3)%3],[0,0x10,0x20,0x30,0xff][(index//4)%5]]))
 return {'name':operation+'/'+str(index),'operation':operation,'body_before_hex':body.hex(),'root_fill_u8':0xa5,'root_before_segments':segments(bytes([0xa5])*ROOT,root),'globals_before':g,'gui_accumulator_u32':[0,0xffffffff,0x00010001,0xfffe0002,0x80007fff,rng.getrandbits(32)][index%6],'speed_input_s32':speeds[index%len(speeds)]}
def packet(row):
 words=[OPS[row['operation']],*[row['globals_before'][key]for key in GLOBALS],row['gui_accumulator_u32'],row['speed_input_s32']]
 return struct.pack('<12I',*[x&0xffffffff for x in words])+bytes.fromhex(row['body_before_hex'])+root_for(row)
def decode(raw,row):
 magic,gui,f931,mode,pointer,value,ntrace=struct.unpack_from('<7I',raw)
 if magic!=0x50494e50 or gui>1 or f931>1 or ntrace>16 or(f931 and pointer!=1)or raw[-64:]!=b'\xa5'*64:raise ValueError('Input native pointer/canary/trace guard failed '+row['name'])
 after_body=raw[160:160+BODY];after_root=raw[160+BODY:160+BODY+ROOT];before=root_for(row)
 keys=list(struct.unpack_from('<9I',raw,96));keys[0]=s32(keys[0]);g=dict(zip(GLOBALS,keys))
 if g!=row['globals_before']:raise ValueError('External globals mutated')
 requests=[]
 if gui:requests.append({'kind':'F1445','return_u32':row['gui_accumulator_u32']})
 if f931:requests.append({'kind':'F931','mode_s32':s32(mode),'body_hex_at_call':after_body.hex()})
 allowed_root=set(range(0xd0,0xd4))|{0xe9,0xea}|set(range(0x1b8,0x1bc))|set(range(0x204,0x208))
 if any(before[i]!=after_root[i]for i in range(ROOT)if i not in allowed_root):raise ValueError('Original input changed unrelated root bytes')
 before_body=bytes.fromhex(row['body_before_hex']);allowed_body=set(range(0xb0,0xb6))
 if any(before_body[i]!=after_body[i]for i in range(BODY)if i not in allowed_body):raise ValueError('Original input changed unrelated body bytes')
 return {'body_after_hex':after_body.hex(),'root_after_changes':segments(before,after_root),'root_after_sha256':sha(after_root),'globals_after':g,'requests':requests,'source_order':['F'+str(k)for k in struct.unpack_from('<16I',raw,32)[:ntrace]],'value_u32':value}
def generate(proof,output):
 metadata=json.loads((proof/'instruction-proof.json').read_text());source=(proof/'source-procedures.s').read_text();verify(metadata,source)
 native=assembly(source);rng=random.Random(0x10371038)
 rows=[case(rng,i,op)for op in OPS for i in range(128 if op!='speed_increment_f1121'else 198)]
 with tempfile.TemporaryDirectory(prefix='player-input-native-')as directory:
  path=Path(directory);(path/'kernel.s').write_text(native)
  subprocess.run(['as','--64','-o',str(path/'kernel.o'),str(path/'kernel.s')],check=True);subprocess.run(['ld','-o',str(path/'kernel'),str(path/'kernel.o')],check=True)
  def run(items):
   result=subprocess.run([str(path/'kernel')],input=b''.join(packet(r)for r in items),capture_output=True,check=True,timeout=90)
   if result.stderr or len(result.stdout)!=len(items)*OUTPUT:raise ValueError('Unexpected input native output size')
   return result.stdout
  prior=case(rng,142,'throttle_f1037');prior['globals_before'].update(input_gate_s8=-1,forward_key_u8=0,reverse_key_u8=1);root=bytearray(root_for(prior));root[0xe9]=0;root[0xea]=0;struct.pack_into('<i',root,0x1b8,0);prior['root_before_segments']=segments(bytes([0xa5])*ROOT,root)
  for i in range(64):
   row=json.loads(json.dumps(prior));row['name']='consecutive-native/'+str(i);row['sequence_step']=i;row['gui_accumulator_u32']=(i*0x31ffe9)&0xffffffff;rows.append(row)
   raw=run([row]);actual=decode(raw,row);prior=row.copy();prior['body_before_hex']=actual['body_after_hex'];prior['root_before_segments']=segments(bytes([0xa5])*ROOT,raw[160+BODY:160+BODY+ROOT]);prior['globals_before']=actual['globals_after']
  runs=[run(rows)for _ in range(3)]
  if len(set(runs))!=1:raise ValueError('Fresh native process outputs differ')
  reverse=run(list(reversed(rows)))
  if reverse!=b''.join(runs[0][i*OUTPUT:(i+1)*OUTPUT]for i in reversed(range(len(rows)))):raise ValueError('Input native case order leakage')
  for i,row in enumerate(rows):row['expected']=decode(runs[0][i*OUTPUT:(i+1)*OUTPUT],row)
 result={'schema':'starfrontier-source-player-input-native-v1','profile':PROFILE,'source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'instruction_proof_sha256':sha((proof/'instruction-proof.json').read_bytes()),'source_procedures_sha256':sha(source.encode()),'host_assembly_sha256':sha(native.encode()),'input_packets_sha256':sha(b''.join(packet(r)for r in rows)),'native_output_sha256':sha(runs[0]),'case_count':len(rows),'case_counts_by_operation':{op:sum(r['operation']==op for r in rows)for op in OPS},'root_bytes':ROOT,'object_bytes':BODY,'fresh_process_runs':3,'reverse_repeat_cases':len(rows),'consecutive_native_steps':64,'all_full_root_body_and_canary_checks_passed':True,'expected_arithmetic_calculated_in_python':False,'root_aliases_share_one_backing_store':True,'callback_policy':{'F1445':'Typed supplied raw u32 response; no Android input collection','F931':'Typed mode and raw338B body pointer observer only; no event-handler effects'},'scope':'Whole original DOS F1037/F1038/F1039/F1040/F1121. All220 instructions match the uploaded EXE; no JJFFE CalcKeyInput or saturation patches. This is not live Android input, full player scheduling or F931 effects.','cases':rows}
 output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(result,indent=2)+'\n');(proof/'player-input-native.s').write_text(native)
 (proof/'validation.json').write_text(json.dumps({k:v for k,v in result.items()if k!='cases'},indent=2)+'\n')
 print(json.dumps({'case_count':len(rows),'fixture_sha256':sha(output.read_bytes()),'output':str(output)},indent=2))
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));parser.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));parser.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));parser.add_argument('--proof-dir',type=Path,default=PROOF);parser.add_argument('--output',type=Path,default=FIXTURE);parser.add_argument('--refresh-original-proof',action='store_true');args=parser.parse_args()
 if args.refresh_original_proof:reprove(args)
 generate(args.proof_dir,args.output)

WRAPPER=r'''
gui_observer:
@TRACEGUI@
 inc DWORD PTR [output+4]
 mov eax,DWORD PTR [input+40]
 ret
FUNC_000931:
@TRACE931@
 push rbp
 mov rbp,rsp
 pushfq
 push rax
 inc DWORD PTR [output+8]
 mov eax,DWORD PTR [rbp+24]
 mov DWORD PTR [output+12],eax
 cmp DWORD PTR [rbp+16],OFFSET FLAT:body
 sete al
 movzx eax,al
 mov DWORD PTR [output+16],eax
 pop rax
 popfq
 pop rbp
 ret
bad_trace:
 mov edi,91
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
 mov edi,OFFSET FLAT:root_before
 mov ecx,@ROOT@+32
 rep stosb
 mov esi,OFFSET FLAT:input+48
 mov edi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:input+386
 mov edi,OFFSET FLAT:DATA_008804
 mov ecx,@ROOT@
 rep movsb
 mov edi,OFFSET FLAT:output
 mov ecx,@OUTPUT@
 xor eax,eax
 rep stosb
 mov DWORD PTR [trace_count],eax
 mov edi,OFFSET FLAT:trace_codes
 mov ecx,64
 rep stosb
@LOADS@
@CALLS@
operation_done:
 mov DWORD PTR [output],0x50494e50
 mov eax,DWORD PTR [trace_count]
 mov DWORD PTR [output+24],eax
 mov esi,OFFSET FLAT:trace_codes
 mov edi,OFFSET FLAT:output+32
 mov ecx,64
 rep movsb
@SAVES@
 mov esi,OFFSET FLAT:body
 mov edi,OFFSET FLAT:output+160
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:DATA_008804
 mov ecx,@ROOT@
 rep movsb
 mov esi,OFFSET FLAT:body_before
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:body_after
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:root_before
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:root_after
 mov ecx,16
 rep movsb
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
DATA_007682: .quad gui_observer
.section .bss
.balign 16
input: .zero @INPUT@
body_before: .zero 16
body: .zero 338
body_after: .zero 16
root_before: .zero 16
DATA_008804: .zero @ROOT@
root_after: .zero 16
.set DATA_008872,DATA_008804+0xea
output: .zero @OUTPUT@
trace_codes: .zero 64
trace_count: .zero 4
@STORAGE@
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
'''
if __name__=='__main__':main()
