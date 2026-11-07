#!/usr/bin/env python3
"""Execute uploaded DOS atmospheric/damage instructions with observed callbacks.

F1014 is recovered directly from DOS instructions because JJFFE changes its heat
and drag formulas. F34/35/953/1016/1017/1521/1530 are separately matched against
DOS before host ABI adaptation. Host callbacks observe sound, module dispatch,
equipment damage and destruction; they do not implement their full engines.
Python prepares raw cases and parses results; it never computes expected heat,
velocity, shields, hull or random output.
"""
from __future__ import annotations
import argparse,hashlib,importlib.util,json,random,re,struct,subprocess,tempfile
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
RANGES={34:(0x32f8,0x3317),35:(0x3318,0x3327),953:(0x2ed7c,0x2ef30),1014:(0x31890,0x319d1),1016:(0x319ec,0x31a07),1017:(0x31a08,0x31a12),1521:(0x44278,0x44289),1530:(0x444bc,0x444fb)}
ALIASES={'FUNC_000034':0x4124f8,'FUNC_000035':0x412518,'FUNC_000048':0x414044,'FUNC_000144':0x419308,'FUNC_000148':0x41942c,'FUNC_000942':0x43da1c,'FUNC_000952':0x43df30,'FUNC_000953':0x43df7c,'FUNC_001016':0x440bec,'FUNC_001017':0x440c08,'FUNC_001521':0x453478,'FUNC_001906':0x46fe7a,'FUNC_001907':0x47007c,'DATA_008548':0x60be08,'DATA_008621':0x630a8c,'DATA_008623':0x630a95,'DATA_007758':0x501854,'DATA_007756':0x501848,'DATA_007752':0x501838,'DATA_007754':0x501840,'DATA_008804':0x64213c,'DATA_008867':0x642218,'DATA_008818':0x642160,'DATA_008820':0x642164,'DATA_009133':0x647948,'DATA_009155':0x652c0c}
OPS=['F1014','F953','F1014_damage','F1016','F1017','F1530']
INPUT=1024;OUTPUT=3600;GUARD=0x41544d4f53504852

def sha(raw):return hashlib.sha256(raw).hexdigest()
def s32(v):return (int(v)&0x7fffffff)-(int(v)&0x80000000)
def load(name,path):
 s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
J=load('atmospheric_jet_helpers',PROJECT/'tools/rebuild_source_jet_fuel_native.py')

def disassemble(exe_path,exe,n):
 start,end=RANGES[n]
 return subprocess.run(['objdump','-d','-Mintel','--no-show-raw-insn','--start-address='+hex(J.file_to_va(exe,start)),'--stop-address='+hex(J.file_to_va(exe,end-1)+1),str(exe_path)],capture_output=True,text=True,check=True).stdout

def recover_dos1014(disassembly):
 rows=J.instructions(disassembly);targets={v:k for k,v in ALIASES.items()};lines=['FUNC_001014:']
 for at,op,args in rows:
  lines.append('DOS_%x:'%at)
  args=re.sub(r'\s*,\s*',',',args)
  if op.startswith('j'):args='DOS_%x'%int(args,16)
  elif op=='call' and re.fullmatch(r'(?:0x)?[0-9a-f]+',args):args=targets[int(args,16)]
  else:
   args=re.sub(r'ds:0x([0-9a-f]+)',lambda m:'['+targets[int(m[1],16)]+']',args)
   if op=='mov' and args=='esi,0x64213c':args='esi,DATA_008804'
  args=re.sub(r'\b(BYTE|WORD|DWORD) PTR ',lambda m:m[1].lower()+' ',args)
  if op=='push' and args=='0xffffffff':args='byte -1'
  lines.append(op+' '+args)
 return '\n'.join(lines)+'\n'

def gas32(body):
 out=[]
 for line in body.splitlines():
  line=line.split(';',1)[0].strip()
  if not line:continue
  line=re.sub(r'\b(?:near|short)\s+','',line)
  line=re.sub(r'\b(byte|word|dword)\s*\[',lambda m:m[1].upper()+' PTR [',line)
  line=re.sub(r'\b(?:byte|word|dword)\s+(?=[+\-0-9])','',line)
  line=re.sub(r'^push dword (DATA_\d+)$',r'push OFFSET FLAT:\1',line)
  line=re.sub(r'^(mov \w+,)(DATA_\d+)$',r'\1OFFSET FLAT:\2',line)
  line=re.sub(r'^(mov DWORD PTR \[[^\]]+\],)(DATA_\d+)$',r'\1OFFSET FLAT:\2',line)
  line=line.replace('call [','call DWORD PTR [')
  line=re.sub(r'FUNC_(\d{6})_[A-Za-z0-9_]+',r'FUNC_\1',line)
  out.append(line)
 return '\n'.join(out)+'\n'

def proof(source,exe,exe_path):
 bodies={n:J.block(source,n) for n in RANGES if n!=1014}
 original={n:disassemble(exe_path,exe,n) for n in RANGES}
 bodies[1014]=recover_dos1014(original[1014]);result={}
 for n,body in bodies.items():
  start,end=RANGES[n];name='FUNC_%06d'%n
  asm='.intel_syntax noprefix\n.code32\n.section .text\n'+''.join('.equ %s,0x%x\n'%(key,value)for key,value in ALIASES.items()if key!=name)+gas32(body)
  with tempfile.TemporaryDirectory(prefix='atmospheric-dos-proof-')as d:
   p=Path(d);(p/'p.s').write_text(asm)
   subprocess.run(['as','--32',str(p/'p.s'),'-o',str(p/'p.o')],check=True,capture_output=True)
   subprocess.run(['ld','-m','elf_i386','-e',name,'--section-start=.text='+hex(J.file_to_va(exe,start)),str(p/'p.o'),'-o',str(p/'p')],check=True,capture_output=True)
   compiled=subprocess.run(['objdump','-d','-Mintel','--no-show-raw-insn',str(p/'p')],capture_output=True,text=True,check=True).stdout
  expected=J.canonical(J.instructions(original[n]));actual=J.canonical(J.instructions(compiled))
  if expected!=actual:raise ValueError('DOS proof F'+str(n)+' counts'+str((len(expected),len(actual)))+' diff'+str([(i,a,b)for i,(a,b)in enumerate(zip(expected,actual))if a!=b][:8]))
  raw=exe[start:end]
  if exe.find(raw)!=start or exe.find(raw,start+1)>=0:raise ValueError('Nonunique DOS procedure')
  result[str(n)]={'executable_offset':start,'virtual_address':J.file_to_va(exe,start),'byte_length':len(raw),'sha256':sha(raw),'instruction_count':len(expected),'normalized_instruction_sha256':sha('\n'.join(expected).encode()),'all_instructions_equal_after_only_branch_destination_normalization':True,'source':'direct uploaded DOS disassembly'if n==1014 else'pinned ASM, independently matched to DOS'}
 return bodies,result,original

def callback(name,body,return_code=None):
 # Retain original caller registers; observe source arguments through host ABI.
 text=name+':\npush rbp\nmov rbp,rsp\npush rax\npush rbx\npush rcx\npush rdx\npush rsi\n'+body+'\ncall record_event\npop rsi\npop rdx\npop rcx\npop rbx\npop rax\n'
 if return_code:text+=return_code+'\n'
 return text+'pop rbp\nret\n'

def native(bodies):
 adapter=load('atmospheric_host_abi',PROJECT/'recovered-history/ground_harness/tools/native_reference.py')
 source='\n'.join(bodies.values())+'\nFUNC_999999:\nret\n'
 source=re.sub(r'FUNC_(\d{6})_[A-Za-z0-9_]+',r'FUNC_\1',source)
 source=re.sub(r'\[ebp\+0x([89a-f][0-9a-f]{7})\]',lambda m:'[ebp-0x%x]'%(0x100000000-int(m[1],16)),source)
 source=re.sub(r'add esp,0x([89a-f][0-9a-f]{7})',lambda m:'add esp,-0x%x'%(0x100000000-int(m[1],16)),source)
 lines,_=adapter.procedures(source,list(bodies));text='\n'.join(lines)
 text=text.replace('call DWORD PTR [','call QWORD PTR [')
 text=re.sub(r'^(mov DWORD PTR \[[^\]]+\],)(DATA_\d+)$',r'\1OFFSET FLAT:\2',text,flags=re.M)
 for n in [35,953,1016,1017,1530]:text=text.replace('FUNC_%06d:\n'%n,'REAL_%d:\n'%n)
 # Keep original source labels but route observed calls through adapters.
 text+='\n'+callback('FUNC_000048','''mov eax,34
 mov ebx,DWORD PTR [rbp+32]
 mov ecx,DWORD PTR [DATA_008548+rbx*4]
 xor edx,edx
 xor esi,esi''')
 # F48 observer can explicitly filter C after its source write.
 text=text.replace('FUNC_000048:\n','FUNC_000048:\n')
 # Separate wrapper is needed to filter before source F35 reloads the bus.
 text+=callback('FILTER_TRACE','''mov eax,35
 mov ebx,12
 mov ecx,DWORD PTR [return_value]
 xor edx,edx
 xor esi,esi''')
 text+='''FUNC_000035:
 cmp DWORD PTR [input+20],0
 je read_source_bus
 mov eax,DWORD PTR [input+24]
 mov DWORD PTR [DATA_008548+48],eax
read_source_bus:
 push QWORD PTR [rsp+8]
 call REAL_35
 add rsp,8
 mov DWORD PTR [return_value],eax
 call FILTER_TRACE
 mov eax,DWORD PTR [return_value]
 ret
'''
 text+=callback('DAMAGE_TRACE','''mov eax,953
 mov ebx,DWORD PTR [requested_damage]
 mov ecx,DWORD PTR [requested_attacker]
 xor edx,edx
 xor esi,esi''')
 text+='''FUNC_000953:
 push rax
 mov eax,DWORD PTR [rsp+24]
 mov DWORD PTR [requested_damage],eax
 mov eax,DWORD PTR [rsp+32]
 mov DWORD PTR [requested_attacker],eax
 pop rax
 call DAMAGE_TRACE
 cmp DWORD PTR [input],2
 je REAL_953
 xor eax,eax
 ret
'''
 for n,args,ret in [(144,'''mov ebx,DWORD PTR [rbp+16]
 mov ecx,DWORD PTR [rbp+24]
 mov esi,DWORD PTR [rbp+32]
 mov edx,DWORD PTR [esi]
 movzx esi,BYTE PTR [rsi+8]''',None),(148,'''mov ebx,DWORD PTR [rbp+16]
 mov ecx,DWORD PTR [rbp+24]
 xor edx,edx
 xor esi,esi''',None),(942,'''mov ebx,DWORD PTR [rbp+24]
 xor ecx,ecx
 xor edx,edx
 xor esi,esi''','mov eax,DWORD PTR [input+44]'),(952,'''xor ebx,ebx
 xor ecx,ecx
 xor edx,edx
 xor esi,esi''','mov eax,DWORD PTR [input+48]'),(1538,'''xor ebx,ebx
 xor ecx,ecx
 xor edx,edx
 xor esi,esi''','mov eax,OFFSET FLAT:descriptor'),(1532,'''xor ebx,ebx
 xor ecx,ecx
 xor edx,edx
 xor esi,esi''','mov eax,OFFSET FLAT:parent'),(1906,'''mov ebx,DWORD PTR [rbp+16]
 xor ecx,ecx
 xor edx,edx
 xor esi,esi''',None),(1907,'''mov ebx,DWORD PTR [rbp+16]
 mov ecx,DWORD PTR [rbp+24]
 xor edx,edx
 xor esi,esi''',None)]:
  text+=callback('FUNC_%06d'%n,'mov eax,%d\n'%n+args,ret)
 for n in [1016,1017]:
  text+=callback('TRACE_%d'%n,'mov eax,%d\nxor ebx,ebx\nxor ecx,ecx\nxor edx,edx\nxor esi,esi'%n)
  text+='FUNC_%06d:\ncall TRACE_%d\njmp REAL_%d\n'%(n,n,n)
 text+=callback('RNG_TRACE','''mov eax,1530
 mov ebx,DWORD PTR [return_value]
 xor ecx,ecx
 xor edx,edx
 xor esi,esi''')
 text+='''FUNC_001530:
 cmp DWORD PTR [input+28],0
 jne explicit_rng
 call REAL_1530
 jmp rng_observed
explicit_rng:
 mov eax,DWORD PTR [input+32]
rng_observed:
 mov DWORD PTR [return_value],eax
 call RNG_TRACE
 mov eax,DWORD PTR [return_value]
 ret
record_event:
 push rdi
 mov edi,DWORD PTR [output+4]
 cmp edi,128
 jae failed
 imul edi,edi,24
 mov DWORD PTR [output+512+rdi],eax
 mov DWORD PTR [output+516+rdi],ebx
 mov DWORD PTR [output+520+rdi],ecx
 mov DWORD PTR [output+524+rdi],edx
 mov DWORD PTR [output+528+rdi],esi
 mov DWORD PTR [output+532+rdi],0
 inc DWORD PTR [output+4]
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
 mov edx,1024
 sub edx,r8d
 syscall
 test eax,eax
 jz finished
 js failed
 add r8d,eax
 cmp r8d,1024
 jb read_more
 mov rax,0x41544d4f53504852
 mov QWORD PTR [object_before],rax
 mov QWORD PTR [object_after],rax
 mov QWORD PTR [globals_before],rax
 mov QWORD PTR [globals_after],rax
 mov QWORD PTR [output_before],rax
 mov QWORD PTR [output_after],rax
 mov esi,OFFSET FLAT:input+128
 mov edi,OFFSET FLAT:object
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:DATA_008804
 xor eax,eax
 mov ecx,16240
 rep stosb
 mov edi,OFFSET FLAT:output
 mov ecx,3600
 rep stosb
 mov edi,OFFSET FLAT:DATA_008548
 mov ecx,256
 rep stosb
 mov eax,DWORD PTR [input+64]
 mov DWORD PTR [DATA_008804+0xdc],eax
 mov eax,DWORD PTR [input+68]
 mov DWORD PTR [DATA_008804+0xd8],eax
 mov eax,DWORD PTR [input+72]
 mov DWORD PTR [DATA_008804+0x1ec],eax
 mov eax,DWORD PTR [input+76]
 shl eax,1
 mov BYTE PTR [DATA_008804+0xe9],al
 mov eax,DWORD PTR [input+80]
 mov BYTE PTR [DATA_008804+0x3f62],al
 mov eax,DWORD PTR [input+84]
 mov BYTE PTR [DATA_008804+0x3f5c],al
 mov eax,DWORD PTR [input+88]
 mov WORD PTR [parent+0xe0],ax
 mov eax,DWORD PTR [input+92]
 mov BYTE PTR [DATA_008804+0x74],al
 mov eax,DWORD PTR [input+36]
 mov DWORD PTR [DATA_008818],eax
 mov eax,DWORD PTR [input+40]
 mov DWORD PTR [DATA_008820],eax
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [DATA_009155],eax
 mov eax,DWORD PTR [input+52]
 mov DWORD PTR [DATA_008621],eax
 mov esi,OFFSET FLAT:input+96
 mov edi,OFFSET FLAT:DATA_008623
 mov ecx,16
module_copy:
 lodsb
 stosb
 add edi,7
 loop module_copy
 mov eax,DWORD PTR [input+56]
 mov DWORD PTR [descriptor+0x38],eax
 movzx eax,BYTE PTR [object+0x86]
 mov edx,DWORD PTR [input+60]
 mov BYTE PTR [object_flags+rax],dl
 mov DWORD PTR [iteration],0
run_repeat:
 cmp DWORD PTR [input],0
 je atmosphere_case
 cmp DWORD PTR [input],2
 je atmosphere_case
 cmp DWORD PTR [input],1
 je damage_case
 cmp DWORD PTR [input],3
 je f1016_case
 cmp DWORD PTR [input],4
 je f1017_case
 cmp DWORD PTR [input],5
 je rng_case
 jmp failed
atmosphere_case:
 push OFFSET FLAT:object
 call FUNC_001014
 add rsp,8
 jmp iteration_done
damage_case:
 push QWORD PTR [input+16]
 push QWORD PTR [input+12]
 push OFFSET FLAT:object
 call REAL_953
 add rsp,24
 jmp iteration_done
f1016_case:
 push OFFSET FLAT:object
 call FUNC_001016
 add rsp,8
 jmp iteration_done
f1017_case:
 push OFFSET FLAT:object
 call FUNC_001017
 add rsp,8
 jmp iteration_done
rng_case:
 call FUNC_001530
iteration_done:
 mov DWORD PTR [output],eax
 inc DWORD PTR [iteration]
 mov eax,DWORD PTR [iteration]
 cmp eax,DWORD PTR [input+8]
 jb run_repeat
 mov DWORD PTR [output+8],eax
 mov DWORD PTR [output+12],0x9531014
 mov eax,DWORD PTR [DATA_008818]
 mov DWORD PTR [output+16],eax
 mov eax,DWORD PTR [DATA_008820]
 mov DWORD PTR [output+20],eax
 mov eax,DWORD PTR [DATA_008804+0x1ec]
 mov DWORD PTR [output+24],eax
 mov esi,OFFSET FLAT:object+0x8c
 mov edi,OFFSET FLAT:output+28
 mov ecx,3
 rep movsd
 movzx eax,BYTE PTR [DATA_008804+0x74]
 mov DWORD PTR [output+40],eax
 mov esi,OFFSET FLAT:DATA_008548+48
 mov edi,OFFSET FLAT:output+44
 mov ecx,3
 rep movsd
 mov esi,OFFSET FLAT:object
 mov edi,OFFSET FLAT:output+64
 mov ecx,338
 rep movsb
 mov rax,0x41544d4f53504852
 mov QWORD PTR [output+3584],rax
 mov QWORD PTR [output+3592],rax
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
 mov edx,3600
 sub edx,r8d
 syscall
 test eax,eax
 jle failed
 add r8d,eax
 cmp r8d,3600
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
.section .data
.align 8
DATA_007752: .quad FUNC_001530
DATA_007754: .quad FUNC_001532
DATA_007756: .quad FUNC_001538
DATA_007758: .long object_flags
DATA_009133: .long parent
DATA_009155: .long 0
DATA_008621: .long 0
DATA_008623: .zero 128
descriptor: .zero 64
parent: .zero 338
.section .bss
.align 8
input: .zero 1024
iteration: .zero 4
requested_damage: .zero 4
requested_attacker: .zero 4
return_value: .zero 4
object_flags: .zero 256
DATA_008548: .zero 256
object_before: .zero 8
object: .zero 338
object_after: .zero 8
globals_before: .zero 8
DATA_008804: .zero 16240
.equ DATA_008867,DATA_008804+0xdc
.equ DATA_008818,DATA_008804+0x24
.equ DATA_008820,DATA_008804+0x28
globals_after: .zero 8
output_before: .zero 8
output: .zero 3600
output_after: .zero 8
.align 16
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
'''
 return '.intel_syntax noprefix\n.code64\n.section .text\n'+text

def cases():
 rows=[]
 def add(operation='F1014',domain='boundary',**kw):
  state={'altitude_s32':0,'speed_s32':3000,'heat_s32':0,'velocity_s32':[0x12345678,-12345678,-2147483648],'shielding':False,'gear_down':False,'wind_enabled':False,'wind_armed':False,'parent_shield_s16':0,'wind_flags_u8':3,'object_index_u8':17,'kind_u8':3,'volume_s8':-7,'player_selector_u8':255,'shield_u16':100,'hull_u16':1000,'damage_timer_u8':7,'damage_flags_u8':0xa0}
  context={'object_flags_u8':0,'has_spec':True,'module_flags_u8':[],'rng_state':{'seed_a_u32':0x12345678,'seed_b_u32':0x87654321},'destruction_return_s32':-77,'equipment_return_s32':-88}
  for key in list(kw):
   if key in state:state[key]=kw.pop(key)
   elif key in context or key in ['filtered_damage_s32','rng_u32']:context[key]=kw.pop(key)
  row={'operation':operation,'domain':domain,'state':state,'context':context,'step_ticks_u32':kw.pop('step_ticks_u32',49710),'damage_s32':kw.pop('damage_s32',1),'attacker_u32':kw.pop('attacker_u32',0x89abcdef),'repeat_count':kw.pop('repeat_count',1)}
  if kw:raise ValueError(kw)
  rows.append(row)
 for altitude in [-2147483648,-1,0,19999999,20000000,20000001,2147483647]:
  for speed in [-2147483648,-3000,-1,0,2999,3000,3001,65535,2147483647]:
   for shielding in [False,True]:
    for gear in [False,True]:add(altitude_s32=altitude,speed_s32=speed,shielding=shielding,gear_down=gear,domain='height_speed_shield_gear')
 for heat in [-2147483648,-1,0,32767,32768,65534,65535,65536,2147483647]:
  for speed in [15,16,31,32,4095,4096,8191,8192,1048576,2147483647]:
   for repeat in [1,4]:add(heat_s32=heat,speed_s32=speed,repeat_count=repeat,domain='per_call_heat_damage_signed_wrap')
 for ticks in [0,1,2,49710,65535,65536,0xffffe,0xfffff,0x100000,0x7fffffff,0x80000000,0xffffffff]:
  for velocity in [[0,1,-1],[2147483647,-2147483648,0x40000000],[-32768,32767,123456789]]:add(step_ticks_u32=ticks,velocity_s32=velocity,domain='unsigned_drag_cap_q31')
 for enabled in [False,True]:
  for armed in [False,True]:
   for parent_shield in [-32768,0,277,278,279,32767]:
    for flags in [0,0x40,0xbf,0xff]:add(wind_enabled=enabled,wind_armed=armed,parent_shield_s16=parent_shield,wind_flags_u8=flags,domain='wind_alarm_signed_parent')
 for amount in [-2147483648,-1,0,1,99,100,101,102,249,250,251,999,1000,1100,65535,2147483647]:
  for shield,hull in [(0,0),(0,1),(0,3),(0,4),(0,1000),(100,1000),(65535,65535)]:
   for kind in [3,11,4]:add('F953',damage_s32=amount,shield_u16=shield,hull_u16=hull,kind_u8=kind,domain='damage_clamp_shield_hull_boundaries')
 for kind in [3,11,4,255]:
  for flags in [0,0x10,0xff]:
   for has_spec in [False,True]:
    for volume in [-128,-1,0,127]:add('F953',kind_u8=kind,object_flags_u8=flags,has_spec=has_spec,volume_s8=volume,damage_s32=101,domain='damage_eligibility_volume')
 for amount in [1,2,9,99,100,101,199,200,201]:
  for rngvalue in [0,1,32767,32768,65535,0xffffffff]:add('F953',damage_s32=amount,shield_u16=0,hull_u16=1000,rng_u32=rngvalue,domain='equipment_unsigned_random_threshold')
 for filt in [-2147483648,-100,-1,0,1,100,101,2147483647]:
  for modules in [[],[0],[4],[4,0,255,8,4],[4]*16]:add('F953',filtered_damage_s32=filt,module_flags_u8=modules,domain='explicit_event_filter_module_observers')
 for operation in ['F1014_damage','F953']:
  for repeat in [1,2,8]:
   for selector in [0,254,255]:add(operation,speed_s32=100000,damage_s32=21,shield_u16=100,hull_u16=5000,repeat_count=repeat,player_selector_u8=selector,module_flags_u8=[4,0,4],domain='combined_repeat_call_order')
 for operation in ['F1016','F1017']:
  for altitude in [-2147483648,20000000,20000001,2147483647]:add(operation,altitude_s32=altitude,domain='true_noop_helpers')
 for a in [0,1,0x7fffffff,0x80000000,0xffffffff]:
  for b in [0,1,0x1234567f,0x80000000,0xffffffff]:
   for repeat in [1,2,8]:add('F1530',rng_state={'seed_a_u32':a,'seed_b_u32':b},repeat_count=repeat,domain='actual_source_rng_state')
 rng=random.Random(0x1014953)
 for i in range(256):
  add('F1014'if i%2 else'F953',domain='seeded_raw_integer',altitude_s32=rng.choice([0,20000000,20000001]),speed_s32=s32(rng.getrandbits(32)),heat_s32=s32(rng.getrandbits(32)),velocity_s32=[s32(rng.getrandbits(32))for _ in range(3)],step_ticks_u32=rng.getrandbits(32),damage_s32=s32(rng.getrandbits(32)),shield_u16=rng.randrange(65536),hull_u16=rng.randrange(65536),shielding=bool(rng.getrandbits(1)),gear_down=bool(rng.getrandbits(1)),rng_state={'seed_a_u32':rng.getrandbits(32),'seed_b_u32':rng.getrandbits(32)})
 return rows

def pack(row):
 s=row['state'];c=row['context'];out=bytearray(INPUT);seeds=c['rng_state'];modules=c['module_flags_u8']
 values=[OPS.index(row['operation']),row['step_ticks_u32'],row['repeat_count'],row['damage_s32'],row['attacker_u32'],int('filtered_damage_s32'in c),c.get('filtered_damage_s32',0),int('rng_u32'in c),c.get('rng_u32',0),seeds['seed_a_u32'],seeds['seed_b_u32'],c['destruction_return_s32'],c['equipment_return_s32'],len(modules),int(c['has_spec']),c['object_flags_u8'],s['altitude_s32'],s['speed_s32'],s['heat_s32'],int(s['gear_down']),int(s['wind_enabled']),int(s['wind_armed']),s['parent_shield_s16'],s['wind_flags_u8']]
 struct.pack_into('<24I',out,0,*[v&0xffffffff for v in values]);out[96:96+len(modules)]=bytes(modules)
 raw=bytearray((i*43+7)&255 for i in range(338));raw[0x56]=3;struct.pack_into('<I',raw,0x82,38)
 for key,at in [('object_index_u8',0x86),('kind_u8',0x87),('volume_s8',0x88),('player_selector_u8',0x118),('damage_timer_u8',0x14e),('damage_flags_u8',0x151)]:raw[at]=s[key]&255
 raw[0xcb]=(raw[0xcb]&0xbf)|(0x40 if s['shielding']else 0)
 struct.pack_into('<3i',raw,0x8c,*s['velocity_s32']);struct.pack_into('<H',raw,0xe0,s['shield_u16']);struct.pack_into('<H',raw,0xe4,s['hull_u16']);out[128:466]=raw
 return bytes(out)

def parse(row,raw):
 if len(raw)!=OUTPUT or struct.unpack_from('<2Q',raw,3584)!=(GUARD,GUARD):raise ValueError('Native output canary')
 words=struct.unpack_from('<14I',raw);obj=raw[64:402];before=pack(row)[128:466]
 allowed=set(range(0x8c,0x98))|{0xe0,0xe1,0xe4,0xe5,0x14e,0x151}
 if any(a!=b and i not in allowed for i,(a,b)in enumerate(zip(before,obj))):raise ValueError('Unscoped native object mutation')
 state=dict(row['state']);state.update(heat_s32=s32(words[6]),velocity_s32=[s32(v)for v in words[7:10]],wind_flags_u8=words[10],shield_u16=struct.unpack_from('<H',obj,0xe0)[0],hull_u16=struct.unpack_from('<H',obj,0xe4)[0],damage_timer_u8=obj[0x14e],damage_flags_u8=obj[0x151])
 traces=[list(struct.unpack_from('<6I',raw,512+24*i))for i in range(words[1])]
 return {'state':state,'return_s32':s32(words[0])if row['operation']in ['F953','F1530']else None,'callbacks_raw_u32':traces,'damage_calls':[{'amount_s32':s32(t[1]),'attacker_u32':t[2]}for t in traces if t[0]==953],'rng_state':{'seed_a_u32':words[4],'seed_b_u32':words[5]},'source_variable_bus_u32':{'12':words[11],'13':words[12],'14':words[13]},'repeat_count':words[2],'object_hex':obj.hex()}

def execute(assembly,rows):
 with tempfile.TemporaryDirectory(prefix='atmospheric-dos-native-')as d:
  p=Path(d);(p/'native.s').write_text(assembly)
  compiled=subprocess.run(['as','--64',str(p/'native.s'),'-o',str(p/'native.o')],capture_output=True,text=True)
  if compiled.returncode:raise ValueError(compiled.stderr)
  subprocess.run(['ld','-m','elf_x86_64',str(p/'native.o'),'-o',str(p/'native')],capture_output=True,check=True)
  payload=b''.join(pack(row)for row in rows);runs=[]
  for _ in range(3):
   r=subprocess.run([str(p/'native')],input=payload,capture_output=True,timeout=30)
   if r.returncode or len(r.stdout)!=len(rows)*OUTPUT:raise ValueError('Native execution '+str((r.returncode,len(r.stdout),len(rows)*OUTPUT)))
   runs.append(r.stdout)
  if len(set(runs))!=1:raise ValueError('Fresh process nondeterminism')
  r=subprocess.run([str(p/'native')],input=b''.join(pack(row)for row in reversed(rows)),capture_output=True,timeout=30)
  if r.returncode or r.stdout!=b''.join(runs[0][i*OUTPUT:(i+1)*OUTPUT]for i in range(len(rows)-1,-1,-1)):raise ValueError('Case-order contamination')
 return [parse(row,runs[0][i*OUTPUT:(i+1)*OUTPUT])for i,row in enumerate(rows)]

def literal_controls(rows):
 # Independent, hand-worked source canaries also check the host input mapping.
 # They never replace any expected result produced by the native executable.
 controls=[]
 def check(name,predicate,observe,literal):
  matches=[row for row in rows if predicate(row)]
  if len(matches)!=1:raise ValueError('Nonunique literal control '+name)
  row=matches[0];value=observe(row['expected'])
  if value!=literal:raise ValueError('Literal source canary failed '+name+str((value,literal)))
  controls.append({'name':name,'case_id':row['id'],'observed':value,'literal_expected':literal,'passed':True})
 for shielding,gear,literal in [(False,False,187),(False,True,93),(True,False,2),(True,True,1)]:
  check('3000-speed-heat-shield-%d-gear-%d'%(shielding,gear),lambda r,s=shielding,g=gear:r['domain']=='height_speed_shield_gear'and r['state']['altitude_s32']==0 and r['state']['speed_s32']==3000 and r['state']['shielding']==s and r['state']['gear_down']==g,lambda e:e['state']['heat_s32'],literal)
 check('fatal-candidate-does-not-write-heat',lambda r:r['domain']=='per_call_heat_damage_signed_wrap'and r['state']['speed_s32']==16 and r['state']['heat_s32']==65535 and r['repeat_count']==1,lambda e:[e['state']['heat_s32'],e['damage_calls'],e['callbacks_raw_u32'][-1][0]],[65535,[{'amount_s32':-1,'attacker_u32':0}],1017])
 check('wind-parent-277-sets-only-bit40',lambda r:r['domain']=='wind_alarm_signed_parent'and r['state']['wind_enabled']and r['state']['wind_armed']and r['state']['parent_shield_s16']==277 and r['state']['wind_flags_u8']==0,lambda e:[e['state']['wind_flags_u8'],e['callbacks_raw_u32'][:2]],[64,[[1532,0,0,0,0,0],[1906,14,0,0,0,0]]])
 check('exact-shield-boundary-preserves-hull',lambda r:r['domain']=='damage_clamp_shield_hull_boundaries'and r['damage_s32']==100 and r['state']['shield_u16']==100 and r['state']['hull_u16']==1000 and r['state']['kind_u8']==3,lambda e:[e['state']['shield_u16'],e['state']['hull_u16'],e['state']['damage_flags_u8'],e['return_s32']],[0,1000,161,1])
 check('zero-seeds-first-source-random',lambda r:r['operation']=='F1530'and r['context']['rng_state']=={'seed_a_u32':0,'seed_b_u32':0}and r['repeat_count']==1,lambda e:[e['return_s32'],e['rng_state']],[0x68ac,{'seed_a_u32':0xfe2468ac,'seed_b_u32':0}])
 return controls

def main():
 p=argparse.ArgumentParser();p.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_atmospheric_native.json');p.add_argument('--validation-dir',type=Path,default=PROJECT/'validation/thermal-2026-11-07');args=p.parse_args()
 source=args.source.read_text();exe=args.executable.read_bytes()
 if sha(exe)!=EXE_SHA or sha(args.source.read_bytes())!=ASM_SHA:raise ValueError('Unreviewed original input')
 bodies,proofs,disassembly=proof(source,exe,args.executable);assembly=native(bodies);rows=cases();results=execute(assembly,rows)
 for i,(row,result)in enumerate(zip(rows,results)):row['id']='dos-atmospheric-%04d'%i;row['expected']=result
 controls=literal_controls(rows)
 doc={'schema_version':1,'reference':'uploaded DOS FIRSTENC.EXE','executable_sha256':EXE_SHA,'pinned_asm_sha256':ASM_SHA,'source_commit':'7e540341d4e09aa3c92877b87d49e7f2c143ad8d','byte_instruction_proofs':proofs,'case_count':len(rows),'callback_raw_schema':['function_number','arg1_u32','arg2_u32','arg3_u32','arg4_u32','reserved_zero'],'callback_arguments':{'34':['register','value_u32'],'35':['register','return_u32'],'144':['module_index','event','code','object_index_u8'],'148':['action','value'],'942':['attacker_u32'],'952':[],'953':['amount_s32_bits','attacker_u32'],'1016':[],'1017':[],'1530':['return_u32'],'1532':[],'1538':[],'1906':['sample'],'1907':['sample','volume_s8_sign_extended_u32']},'execution_checks':{'fresh_identical_processes':3,'reverse_case_order_identical':True,'object_globals_output_canaries':True,'unrelated_object_bytes_unchanged':True,'expected_arithmetic_computed_by_python':False},'scope':['F1014 original per-invocation heat; unsigned drag cap0xFFFFF; original wind branch','F953 shield/hull/equipment decision arithmetic; original F34/F35 variable bus and original F1530 RNG','F144/F148/sound/object lookup/F942/F952 are explicitly observed adapters, not full event/equipment/destruction implementations','F1014 operation observes F953 requests only; F1014_damage executes F953 core with those external adapters','F1530 uses fixture-local source seeds; no claim to reproduce the unported global AI/event RNG stream'], 'known_jjffe_differences':['JJFFE F1014 heat uses dt product and4096 cap with shifted22/19, DOS uses speed SAR11/5 minus gear-up adjustment per call','JJFFE comments out incremental F953 damage and adds heat bit0x8000 notification, absent in DOS','JJFFE signed drag cap0xFFFF differs from DOS unsigned0xFFFFF'],'invalid_domains_not_executed':[{'domain':'malformed object or missing parent pointer','policy':'API rejects; source raw pointers require valid object banks'},{'domain':'module count beyond host input16','policy':'fixture adapter bound only; original source uses DATA8621 count; not a source gameplay restriction'}],'cases':rows}
 doc['independent_literal_controls']=controls
 args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(doc,indent=2)+'\n');args.validation_dir.mkdir(parents=True,exist_ok=True)
 report={k:v for k,v in doc.items()if k!='cases'};report.update(fixture_sha256=sha(args.output.read_bytes()),tool_sha256=sha(Path(__file__).read_bytes()),generated_native_assembly_sha256=sha(assembly.encode()),counts_by_operation={op:sum(row['operation']==op for row in rows)for op in OPS})
 (args.validation_dir/'source-atmospheric-native-proof.json').write_text(json.dumps(report,indent=2)+'\n')
 (args.validation_dir/'dos-atmospheric-disassembly.txt').write_text('\n\n'.join('F'+str(n)+'\n'+d for n,d in disassembly.items()))
 print(json.dumps({'cases':len(rows),'operations':report['counts_by_operation'],'fixture_sha256':report['fixture_sha256'],'instruction_proofs':{k:v['instruction_count']for k,v in proofs.items()},'fresh_runs':3,'reverse_order':True}))
if __name__=='__main__':main()
