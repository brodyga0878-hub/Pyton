#!/usr/bin/env python3
"""Native uploaded-DOS F1008 and bounded F1056 landing-gear branch controls.

Complete F1008 and JUMP_004410..JUMP_004413 plus its outgoing jump are proved
against original DOS instructions before host ABI conversion. Full F1056's
input dispatcher and F1116 console implementation are expressly outside scope.
Python never calculates expected gear/timer/warning transitions.
"""
from __future__ import annotations
import argparse,hashlib,importlib.util,json,random,re,struct,subprocess,tempfile
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
RANGES={'F1008':(0x31590,0x316c1),'F1056_JUMP_004410':(0x3409a,0x3410e)}
ALIASES={'DATA_008804':0x64213c,'DATA_009155':0x652c0c,'FUNC_000262':0x41d308,'FUNC_001097':0x444518,'FUNC_001116':0x445aac,'FUNC_001906':0x46fe7a,'JUMP_004431':0x443574}
OPS=['F1008','toggle','toggle_then_step','step_then_toggle']
INPUT=928;OUTPUT=3072;GUARD=0x47454152444f5353

def load(name,path):
 sp=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m);return m
A=load('gear_atmospheric_helpers',PROJECT/'tools/rebuild_source_atmospheric_native.py');J=A.J

def sha(raw):return hashlib.sha256(raw).hexdigest()
def s32(v):return (int(v)&0x7fffffff)-(int(v)&0x80000000)
def bodies(source):
 block=J.block(source,1056)
 toggle=re.search(r'(^\s*JUMP_004410:.*?)(?=^\s*JUMP_004414:)',block,re.S|re.M)
 if not toggle:raise ValueError('Unreviewed F1056 gear branch bounds')
 return {'F1008':J.block(source,1008),'F1056_JUMP_004410':toggle[1]}

def proof(source,exe,exe_path):
 pieces=bodies(source);proofs={};disassembly={}
 for name,body in pieces.items():
  start,end=RANGES[name]
  original=subprocess.run(['objdump','-d','-Mintel','--no-show-raw-insn','--start-address='+hex(J.file_to_va(exe,start)),'--stop-address='+hex(J.file_to_va(exe,end-1)+1),str(exe_path)],capture_output=True,text=True,check=True).stdout;disassembly[name]=original
  asm='.intel_syntax noprefix\n.code32\n.section .text\n'+''.join('.equ %s,0x%x\n'%(key,value)for key,value in ALIASES.items())+A.gas32(body)
  entry='FUNC_001008'if name=='F1008'else'JUMP_004410'
  with tempfile.TemporaryDirectory(prefix='gear-dos-proof-')as d:
   p=Path(d);(p/'p.s').write_text(asm)
   r=subprocess.run(['as','--32',str(p/'p.s'),'-o',str(p/'p.o')],capture_output=True,text=True)
   if r.returncode:raise ValueError(r.stderr)
   subprocess.run(['ld','-m','elf_i386','-e',entry,'--section-start=.text='+hex(J.file_to_va(exe,start)),str(p/'p.o'),'-o',str(p/'p')],capture_output=True,check=True)
   compiled=subprocess.run(['objdump','-d','-Mintel','--no-show-raw-insn',str(p/'p')],capture_output=True,text=True,check=True).stdout
  expected=J.canonical(J.instructions(original),name!='F1008');actual=J.canonical(J.instructions(compiled),name!='F1008')
  if expected!=actual:raise ValueError('DOS instruction proof '+name+str((len(expected),len(actual)))+str([(i,a,b)for i,(a,b)in enumerate(zip(expected,actual))if a!=b][:8]))
  raw=exe[start:end]
  if exe.find(raw)!=start or exe.find(raw,start+1)>=0:raise ValueError('Original code block not unique')
  proofs[name]={'executable_offset':start,'virtual_address':J.file_to_va(exe,start),'byte_length':end-start,'sha256':sha(raw),'instruction_count':len(expected),'normalized_instruction_sha256':sha('\n'.join(expected).encode()),'all_instructions_equal_after_branch_destination_normalization':True,'outgoing_branch':'None'if name=='F1008'else'Only terminal JMP_004431 exits; normalized to slice_exit for instruction comparison, host returns instead of executing remaining VM.'}
 return pieces,proofs,disassembly

def native(pieces):
 adapter=load('gear_host_abi',PROJECT/'recovered-history/ground_harness/tools/native_reference.py')
 source=pieces['F1008']+'\nFUNC_900056:\npush ebp\nmov ebp,esp\npush esi\nmov esi,DATA_008804\n'+pieces['F1056_JUMP_004410']+'\nJUMP_004431:\npop esi\npop ebp\nret\nFUNC_999999:\nret\n'
 source=re.sub(r'FUNC_(\d{6})_[A-Za-z0-9_]+',r'FUNC_\1',source)
 lines,_=adapter.procedures(source,[1008,900056]);text='\n'.join(lines)+'\n'
 for n,setup in [(262,'mov ebx,DWORD PTR [rbp+16]\nmov ecx,DWORD PTR [rbp+24]'),(1097,'mov ebx,DWORD PTR [rbp+16]\nmov ecx,DWORD PTR [rbp+24]'),(1116,'xor ebx,ebx\nxor ecx,ecx'),(1906,'mov ebx,DWORD PTR [rbp+16]\nxor ecx,ecx')]:
  text+='FUNC_%06d:\npush rbp\nmov rbp,rsp\npush rax\npush rbx\npush rcx\npush rdx\nmov eax,%d\n'%(n,n)+setup+'\ncall record_event\npop rdx\npop rcx\npop rbx\npop rax\npop rbp\nret\n'
 text+='''record_event:
 push rdi
 mov edi,DWORD PTR [output]
 cmp edi,126
 jae failed
 shl edi,4
 mov DWORD PTR [output+1024+rdi],eax
 mov DWORD PTR [output+1028+rdi],ebx
 mov DWORD PTR [output+1032+rdi],ecx
 mov DWORD PTR [output+1036+rdi],0
 inc DWORD PTR [output]
 pop rdi
 ret
.global _start
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 lea rsi,[input+r8]
 mov edx,928
 sub edx,r8d
 syscall
 test eax,eax
 jz finished
 js failed
 add r8d,eax
 cmp r8d,928
 jb read_more
 mov rax,0x47454152444f5353
 mov QWORD PTR [object_before],rax
 mov QWORD PTR [object_after],rax
 mov QWORD PTR [globals_before],rax
 mov QWORD PTR [globals_after],rax
 mov QWORD PTR [output_before],rax
 mov QWORD PTR [output_after],rax
 mov esi,OFFSET FLAT:input+32
 mov edi,OFFSET FLAT:object
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:DATA_008804
 mov ecx,556
 rep movsb
 mov DWORD PTR [DATA_008804+0xc8],OFFSET FLAT:object
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [DATA_009155],eax
 mov edi,OFFSET FLAT:output
 xor eax,eax
 mov ecx,3072
 rep stosb
 mov DWORD PTR [iteration],0
run_repeat:
 cmp DWORD PTR [input],0
 je step_case
 cmp DWORD PTR [input],1
 je toggle_case
 cmp DWORD PTR [input],2
 je toggle_step_case
 cmp DWORD PTR [input],3
 je step_toggle_case
 jmp failed
step_case:
 push OFFSET FLAT:object
 call FUNC_001008
 add rsp,8
 jmp iteration_done
toggle_case:
 call FUNC_900056
 jmp iteration_done
toggle_step_case:
 call FUNC_900056
 push OFFSET FLAT:object
 call FUNC_001008
 add rsp,8
 jmp iteration_done
step_toggle_case:
 push OFFSET FLAT:object
 call FUNC_001008
 add rsp,8
 call FUNC_900056
iteration_done:
 inc DWORD PTR [iteration]
 mov eax,DWORD PTR [iteration]
 cmp eax,DWORD PTR [input+8]
 jb run_repeat
 mov DWORD PTR [output+4],eax
 mov DWORD PTR [output+8],0x10081056
 mov esi,OFFSET FLAT:object
 mov edi,OFFSET FLAT:output+32
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:DATA_008804
 mov ecx,556
 rep movsb
 # Absolute relocation of the host object pointer is not a source result.
 mov DWORD PTR [output+370+0xc8],0
 mov rax,0x47454152444f5353
 mov QWORD PTR [output+3056],rax
 mov QWORD PTR [output+3064],rax
 cmp QWORD PTR [object_before],rax
 jne failed
 cmp QWORD PTR [object_after],rax
 jne failed
 cmp QWORD PTR [globals_before],rax
 jne failed
 cmp QWORD PTR [globals_after],rax
 jne failed
 cmp QWORD PTR [output_before],rax
 jne failed
 cmp QWORD PTR [output_after],rax
 jne failed
 xor r8d,r8d
write_more:
 mov eax,1
 mov edi,1
 lea rsi,[output+r8]
 mov edx,3072
 sub edx,r8d
 syscall
 test eax,eax
 jle failed
 add r8d,eax
 cmp r8d,3072
 jb write_more
 jmp next_case
finished:
 mov eax,60
 xor edi,edi
 syscall
failed:
 mov eax,60
 mov edi,94
 syscall
.section .bss
.align 8
input: .zero 928
iteration: .zero 4
DATA_009155: .zero 4
object_before: .zero 8
object: .zero 338
object_after: .zero 8
globals_before: .zero 8
DATA_008804: .zero 556
globals_after: .zero 8
output_before: .zero 8
output: .zero 3072
output_after: .zero 8
.align 16
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
'''
 return '.intel_syntax noprefix\n.code64\n.section .text\n'+text

def cases():
 rows=[]
 def add(operation='F1008',domain='boundary',**kw):
  state={'position_u16':65535,'object_timer_u16':1234,'autopilot_phase_u8':0,'flight_state_u8':0,'control_flags_u8':0,'warning_flags_u16':0,'speed_s32':0}
  for key in list(kw):
   if key in state:state[key]=kw.pop(key)
  row={'operation':operation,'domain':domain,'state':state,'step_ticks_u32':kw.pop('step_ticks_u32',49710),'repeat_count':kw.pop('repeat_count',1)}
  if kw:raise ValueError(kw)
  rows.append(row)
 ticks=[0,1,2,3,32767,32768,65534,65535,65536,65537,131069,131070,131071,0x7fffffff,0x80000000,0xfffffffe,0xffffffff]
 for timer in [0,1,2,32767,32768,65534,65535]:
  for step in ticks:
   for flags in [0,2,0xfd,0xff]:add(object_timer_u16=timer,step_ticks_u32=step,control_flags_u8=flags,domain='timer_unsigned_cap_and_gear_direction')
 for position in [0,1,2,32767,32768,65534,65535]:
  for step in ticks:
   for flags in [0,2]:add(position_u16=position,step_ticks_u32=step,control_flags_u8=flags,domain='deployment_retraction_equalities')
 for flight_state in [0,1,2,3,127,128,255]:
  for phase in [0,29,30,31,35,36,37,127,128,255]:
   for flags in [0,2,0xfd,0xff]:add(flight_state_u8=flight_state,autopilot_phase_u8=phase,control_flags_u8=flags,warning_flags_u16=0xffff,domain='autopilot_unsigned_phase_force')
 for speed in [-2147483648,-100000,-1,0,99999,100000,100001,2147483647]:
  for state in [0,2,255]:
   for flags in [0,2]:
    for warning in [0,1,2,3,0xfffd,0xffff]:add(speed_s32=speed,flight_state_u8=state,control_flags_u8=flags,warning_flags_u16=warning,repeat_count=3,domain='signed_speed_and_warning_latch')
 for operation in ['toggle','toggle_then_step','step_then_toggle']:
  for phase in [0,30,31,35,36,37,255]:
   for flags in [0,2,0xfd,0xff]:
    for flight_state in [0,2,0x24,255]:
     for repeat in [1,2,8]:add(operation,autopilot_phase_u8=phase,control_flags_u8=flags,flight_state_u8=flight_state,warning_flags_u16=0xffff,repeat_count=repeat,domain='toggle_block_callbacks_and_composition')
 rng=random.Random(0x10081056)
 for _ in range(512):add(rng.choice(OPS),domain='seeded_integer_control',position_u16=rng.randrange(65536),object_timer_u16=rng.randrange(65536),autopilot_phase_u8=rng.randrange(256),flight_state_u8=rng.randrange(256),control_flags_u8=rng.randrange(256),warning_flags_u16=rng.randrange(65536),speed_s32=s32(rng.getrandbits(32)),step_ticks_u32=rng.getrandbits(32))
 add(domain='literal_deploy_one',position_u16=0,object_timer_u16=0,step_ticks_u32=2)
 add(domain='literal_retract_complete',control_flags_u8=2,step_ticks_u32=131070)
 add(domain='literal_timer_equality',object_timer_u16=65535,step_ticks_u32=65535)
 add(domain='literal_odd_tick_truncation',position_u16=0,step_ticks_u32=1)
 add(domain='literal_auto_low_phase',flight_state_u8=2,autopilot_phase_u8=30,step_ticks_u32=0)
 add(domain='literal_auto_high_phase',flight_state_u8=2,autopilot_phase_u8=31,control_flags_u8=2,step_ticks_u32=0)
 add(domain='literal_warning_exact_speed',speed_s32=100000,step_ticks_u32=0)
 add(domain='literal_warning_below_speed',speed_s32=99999,step_ticks_u32=0)
 add('toggle',domain='literal_toggle_blocked',autopilot_phase_u8=0x24,warning_flags_u16=65535)
 add('toggle',domain='literal_toggle_request',warning_flags_u16=65535)
 return rows

def pack(row):
 out=bytearray(INPUT);struct.pack_into('<3I',out,0,OPS.index(row['operation']),row['step_ticks_u32'],row['repeat_count']);s=row['state']
 obj=bytearray((i*43+7)&255 for i in range(338));game=bytearray((i*59+11)&255 for i in range(556))
 struct.pack_into('<H',obj,0x9e,s['position_u16']);struct.pack_into('<H',obj,0xe8,s['object_timer_u16']);obj[0xff]=s['autopilot_phase_u8']
 game[0xe8]=s['flight_state_u8'];game[0xe9]=s['control_flags_u8'];struct.pack_into('<H',game,0xc6,s['warning_flags_u16']);struct.pack_into('<i',game,0xd8,s['speed_s32']);struct.pack_into('<I',game,0xc8,0)
 out[32:370]=obj;out[370:926]=game;return bytes(out)

def parse(row,raw):
 if len(raw)!=OUTPUT or struct.unpack_from('<2Q',raw,3056)!=(GUARD,GUARD):raise ValueError('Native canary failure')
 count,repeat,sentinel=struct.unpack_from('<3I',raw);obj=raw[32:370];game=raw[370:926];before=pack(row)
 for label,old,new,allowed in [('object',before[32:370],obj,{0x9e,0x9f,0xe8,0xe9}),('globals',before[370:926],game,{0xc6,0xc7,0xe9})]:
  if any(a!=b and i not in allowed for i,(a,b)in enumerate(zip(old,new))):raise ValueError('Unscoped '+label+' write')
 if sentinel!=0x10081056:raise ValueError('Native sentinel')
 state={'position_u16':struct.unpack_from('<H',obj,0x9e)[0],'object_timer_u16':struct.unpack_from('<H',obj,0xe8)[0],'autopilot_phase_u8':obj[0xff],'flight_state_u8':game[0xe8],'control_flags_u8':game[0xe9],'warning_flags_u16':struct.unpack_from('<H',game,0xc6)[0],'speed_s32':struct.unpack_from('<i',game,0xd8)[0]}
 return {'state':state,'callbacks_raw_u32':[list(struct.unpack_from('<4I',raw,1024+i*16))for i in range(count)],'repeat_count':repeat,'object_sha256':sha(obj),'globals_sha256':sha(game)}

def execute(assembly,rows):
 with tempfile.TemporaryDirectory(prefix='landing-gear-native-')as d:
  p=Path(d);(p/'native.s').write_text(assembly)
  r=subprocess.run(['as','--64',str(p/'native.s'),'-o',str(p/'native.o')],capture_output=True,text=True)
  if r.returncode:raise ValueError(r.stderr)
  subprocess.run(['ld','-m','elf_x86_64',str(p/'native.o'),'-o',str(p/'native')],capture_output=True,check=True)
  payload=b''.join(pack(row)for row in rows);runs=[]
  for _ in range(3):
   r=subprocess.run([str(p/'native')],input=payload,capture_output=True,timeout=30)
   if r.returncode or len(r.stdout)!=len(rows)*OUTPUT:raise ValueError('Native execution'+str((r.returncode,len(r.stdout),len(rows)*OUTPUT)))
   runs.append(r.stdout)
  if len(set(runs))!=1:raise ValueError('Fresh-process mismatch')
  r=subprocess.run([str(p/'native')],input=b''.join(pack(row)for row in reversed(rows)),capture_output=True,timeout=30)
  if r.returncode or r.stdout!=b''.join(runs[0][i*OUTPUT:(i+1)*OUTPUT]for i in range(len(rows)-1,-1,-1)):raise ValueError('Case-order contamination')
 return [parse(row,runs[0][i*OUTPUT:(i+1)*OUTPUT])for i,row in enumerate(rows)]

def warning_resource(exe):
 raw=bytes([1,2])+b'WARNING: '+bytes([1,3])+b'Undercarriage down.'+b'\r   (It may be damaged by micrometeorites)\0'
 at=exe.find(raw)
 if at<0 or exe.find(raw,at+1)>=0:raise ValueError('Unreviewed original warning literal')
 return {'ff_code_u16':0x98ce,'data_label':'DATA_005860','executable_offset':at,'hex':raw.hex(),'sha256':sha(raw),'plain_text':'WARNING: Undercarriage down.\n   (It may be damaged by micrometeorites)'}

def literal_controls(rows):
 # Manual source examples independently guard ABI input mapping and flag names.
 # All full expected transitions remain outputs of the actual native program.
 conditions={
  'literal_deploy_one':({'position_u16':1},[]),
  'literal_retract_complete':({'position_u16':0},[]),
  'literal_timer_equality':({'object_timer_u16':0},[]),
  'literal_odd_tick_truncation':({'position_u16':0},[]),
  'literal_auto_low_phase':({'control_flags_u8':2},[[1116,0,0,0]]),
  'literal_auto_high_phase':({'control_flags_u8':0},[[1116,0,0,0]]),
  'literal_warning_exact_speed':({'warning_flags_u16':2},[[1097,0x98ce,0xffffffff,0]]),
  'literal_warning_below_speed':({'warning_flags_u16':0},[]),
  'literal_toggle_blocked':({'control_flags_u8':0,'warning_flags_u16':65535},[[1906,0x14,0,0]]),
  'literal_toggle_request':({'control_flags_u8':2,'warning_flags_u16':65533},[[262,0x38,0,0],[262,0x46,0,0],[1116,0,0,0],[1906,0xc,0,0],[1906,0x14,0,0]])}
 result=[]
 for name,(state,callbacks)in conditions.items():
  matched=[row for row in rows if row['domain']==name]
  if len(matched)!=1:raise ValueError('Literal control nonunique '+name)
  row=matched[0];observed=row['expected']
  if any(observed['state'][key]!=value for key,value in state.items())or observed['callbacks_raw_u32']!=callbacks:raise ValueError('Independent source literal control failed '+name)
  result.append({'name':name,'case_id':row['id'],'literal_state_subset':state,'literal_callbacks_raw_u32':callbacks,'passed':True})
 return result

def main():
 p=argparse.ArgumentParser();p.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_landing_gear_native.json');p.add_argument('--validation-dir',type=Path,default=PROJECT/'validation/gear-2026-11-08/nativeproof');args=p.parse_args()
 source=args.source.read_text();exe=args.executable.read_bytes()
 if sha(exe)!=EXE_SHA or sha(args.source.read_bytes())!=ASM_SHA:raise ValueError('Unreviewed original source')
 pieces,proofs,disassembly=proof(source,exe,args.executable);warning=warning_resource(exe);assembly=native(pieces);rows=cases();results=execute(assembly,rows)
 for i,(row,result)in enumerate(zip(rows,results)):row['id']='dos-landing-gear-%05d'%i;row['expected']=result
 controls=literal_controls(rows)
 doc={'schema_version':1,'reference':'uploaded DOS FIRSTENC.EXE','executable_sha256':EXE_SHA,'pinned_asm_sha256':ASM_SHA,'source_commit':'7e540341d4e09aa3c92877b87d49e7f2c143ad8d','case_count':len(rows),'byte_instruction_proofs':proofs,'known_dos_jjffe_differences':[],'warning_resource':warning,'callback_raw_schema':['function_number','arg1_u32','arg2_u32','reserved_zero'],'callback_arguments':{'262':['button_id','image_id'],'1097':['message_code_u32','selector_s32_bits'],'1116':[],'1906':['sample']},'raw_semantics':{'game_e9_mask02_set':'retract requested; object9E tends to0','game_e9_mask02_clear':'deploy requested; object9E tends to65535','object9e_zero':'fully retracted','object9e_ffff':'fully deployed; required by F575 terminal docking predicate','objectff_24hex':'bounded toggle blocked; only sound0x14 still emitted','gamee8_state2':'autopilot overrides desired gear command based on unsigned objectFF<=0x1E','frame_ticks':'DATA9155 u32 per original F1009→F1008 player physics invocation; not F152 whole-seconds cadence'},'execution_checks':{'fresh_identical_processes':3,'reverse_case_order_identical':True,'object_globals_output_canaries':True,'unrelated_bytes_unchanged':True,'expected_transitions_computed_by_python':False},'scope':['Full F1008 arithmetic/control flow, including timer, automatic command, warning latch and gear animation.','Only F1056 JUMP_004410..004413 and terminal branch; no complete keyboard, hot-area or pause/flight dispatcher claim.','F1116 console update, F262 button image, F1097 notification and F1906 sound are observed callbacks; full UI and sound engine excluded.','No forced flight-state transition exists in this exact toggle branch.','Source unit conversion, virtual scheduling, save persistence and phone UI are separate caller policies.'],'invalid_domains_not_executed':['Malformed object pointers are rejected by public adapter; source raw instructions assume valid338-byte object and DATA8804 context.'],'cases':rows}
 doc['independent_literal_controls']=controls
 args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(doc,indent=2)+'\n');args.validation_dir.mkdir(parents=True,exist_ok=True)
 report={k:v for k,v in doc.items()if k!='cases'};report.update(fixture_sha256=sha(args.output.read_bytes()),tool_sha256=sha(Path(__file__).read_bytes()),native_assembly_sha256=sha(assembly.encode()),counts_by_operation={op:sum(r['operation']==op for r in rows)for op in OPS})
 (args.validation_dir/'source-landing-gear-native-proof.json').write_text(json.dumps(report,indent=2)+'\n');(args.validation_dir/'dos-landing-gear-disassembly.txt').write_text('\n\n'.join(name+'\n'+text for name,text in disassembly.items()))
 print(json.dumps({'cases':len(rows),'operations':report['counts_by_operation'],'fixture_sha256':report['fixture_sha256'],'instructions':{k:v['instruction_count']for k,v in proofs.items()},'fresh_runs':3,'reverse_order':True}))
if __name__=='__main__':main()
