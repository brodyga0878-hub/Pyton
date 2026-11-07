#!/usr/bin/env python3
"""Uploaded DOS F575 post-classification (JUMP2410..2432) instruction oracle.

The original classification/geometry provider is an explicit input. The oracle
executes the entire bounded continuation, including position correction, exact
landing predicate, basis/velocity reaction and observed F953 requests. It never
claims full F575/F569/F578, or executes the damage/event/gameplay engine.
"""
from __future__ import annotations
import argparse,hashlib,importlib.util,json,random,re,struct,subprocess,tempfile
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
COMMIT='7e540341d4e09aa3c92877b87d49e7f2c143ad8d'
HELPERS=[571,1333,1335,1466,1501,1502,1503,1504,1519,1520,1521,1522,1523,1538,1552,1656,1657,1658,1660]
GLOBAL_VA={8696:0x633ec8,8698:0x633eca,8699:0x633ecb,8700:0x633ecc,8702:0x633ed0,8705:0x633edc,8706:0x633ee0,8707:0x633ee4,8857:0x6421fc}
SEED_VA={571:0x4274e0,1333:0x44e816,1335:0x44e848,1503:0x452b8a,1504:0x452bc6,1519:0x45339a,1520:0x453422,1521:0x453478,1658:0x459ad0}
PRIMARY=(0x185f5,0x18c6e)
INPUT=1024;OUTPUT=3104;GUARD=0x5355524641434535

def load(name,path):
 p=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(p);p.loader.exec_module(m);return m
A=load('surface_contact_atmosphere_helpers',PROJECT/'tools/rebuild_source_atmospheric_native.py');J=A.J
G=load('surface_contact_resource_image',PROJECT/'tools/rebuild_ground_surface_native.py')
def sha(raw):return hashlib.sha256(raw).hexdigest()
def s32(v):return (int(v)&0x7fffffff)-(int(v)&0x80000000)
def source_fragment(source):
 body=J.block(source,575)
 return re.search(r'(^\s*JUMP_002410:.*?)(?=^\s*JUMP_002432:)',body,re.S|re.M)[1]

def compile32(body,aliases,entry,address):
 text='.intel_syntax noprefix\n.code32\n.section .text\n'+''.join('.equ %s,0x%x\n'%(k,v)for k,v in aliases.items()if k!=entry)+A.gas32(body)
 with tempfile.TemporaryDirectory(prefix='source-contact-static-proof-')as d:
  p=Path(d);(p/'p.s').write_text(text)
  r=subprocess.run(['as','--32',str(p/'p.s'),'-o',str(p/'p.o')],capture_output=True,text=True)
  if r.returncode:raise ValueError(r.stderr)
  r=subprocess.run(['ld','-m','elf_i386','-e',entry,'--section-start=.text='+hex(address),str(p/'p.o'),'-o',str(p/'p')],capture_output=True,text=True)
  if r.returncode:raise ValueError(r.stderr)
  return subprocess.run(['objdump','-d','-Mintel','--no-show-raw-insn',str(p/'p')],capture_output=True,text=True,check=True).stdout

def original_rows(exe_path,address,count=None,end=None):
 text=subprocess.run(['objdump','-d','-Mintel','--no-show-raw-insn','--start-address='+hex(address),'--stop-address='+hex(end if end is not None else address+8192),str(exe_path)],capture_output=True,text=True,check=True).stdout
 rows=J.instructions(text)
 return rows if count is None else rows[:count]

def proof(source,exe,exe_path):
 image=G.Image(exe);bodies={n:J.block(source,n)for n in HELPERS}
 aliases={**{'DATA_%06d'%n:v for n,v in GLOBAL_VA.items()},'_abs':0x476238,'FUNC_000953':0x43df7c,'JUMP_002432':0x427e6e}
 addresses=dict(SEED_VA);aliases.update({'FUNC_%06d'%n:v for n,v in addresses.items()})
 # The model descriptor lookup is entered through its exact DOS pointer table.
 addresses[1538]=struct.unpack_from('<I',exe,image.offset(0x501848,4))[0]
 aliases['FUNC_001538']=addresses[1538];aliases['DATA_007756']=0x501848;aliases['DATA_007719']=0x501304
 for n,body in bodies.items():
  for symbol in re.findall(r'\b(?:FUNC_\d{6})(?:_[A-Za-z0-9_]+)?|DATA_\d{6}|_abs',body):
   symbol=re.sub(r'(FUNC_\d{6})_[A-Za-z0-9_]+',r'\1',symbol);aliases.setdefault(symbol,0)
 remaining=set(HELPERS);records={};disassembly={}
 while remaining:
  ready=next((n for n in sorted(remaining)if n in addresses),None)
  if ready is None:raise ValueError('Unresolved required helper entries '+str(remaining))
  n=ready;body=bodies[n];name='FUNC_%06d'%n;address=addresses[n]
  tentative=J.instructions(compile32(body,aliases,name,address));rows=original_rows(exe_path,address,len(tentative))
  if len(rows)!=len(tentative)or rows[-1][1]!='ret':raise ValueError('Original helper boundary differs '+str(n))
  source_calls=[]
  for line in body.splitlines():
   line=line.strip()
   if line.startswith('call'):
    matched=re.match(r'call(?: near)?\s+(\[DATA_\d+\]|FUNC_\d+(?:_[A-Za-z0-9_]+)?|_abs)',line)
    if not matched:raise ValueError('Unsupported source call '+line)
    source_calls.append((re.sub(r'(FUNC_\d{6})_[A-Za-z0-9_]+',r'\1',matched[1].strip('[]')),line))
  calls=[args for _,op,args in rows if op=='call']
  if len(source_calls)!=len(calls):raise ValueError('Helper call count changed '+str(n))
  for (symbol,line),args in zip(source_calls,calls):
   match=re.search(r'0x([0-9a-f]+)',args)
   if match is None:raise ValueError('No actual DOS external call address')
   value=int(match[1],16)
   if aliases.get(symbol,0)not in [0,value]:raise ValueError('Inconsistent source/DOS binding '+symbol)
   aliases[symbol]=value
   if symbol.startswith('FUNC_'):
    child=int(symbol[5:]);addresses[child]=value
   elif symbol.startswith('DATA_'):
    target=re.search(r'FUNC_(\d+)',line)
    if target:
     child=int(target[1]);value=struct.unpack_from('<I',exe,image.offset(value,4))[0];addresses[child]=value;aliases['FUNC_%06d'%child]=value
  # F1538's descriptor table address is the only non-call external helper operand.
  if n==1538:
   actual=[args for _,op,args in rows if op=='mov'and '*4+'in args]
   if len(actual)!=1:raise ValueError('Unreviewed F1538 descriptor lookup')
   table=int(re.search(r'\+0x([0-9a-f]+)',actual[0])[1],16);aliases['DATA_004681']=table
  compiled=J.instructions(compile32(body,aliases,name,address));expected=J.canonical(rows);observed=J.canonical(compiled)
  if expected!=observed:raise ValueError('DOS helper instruction mismatch F'+str(n)+' '+str([(i,a,b)for i,(a,b)in enumerate(zip(expected,observed))if a!=b][:8]))
  start=image.offset(address,1);end=image.offset(rows[-1][0],1)+1;raw=exe[start:end]
  records[str(n)]={'executable_offset':start,'virtual_address':address,'byte_length':len(raw),'sha256':sha(raw),'instruction_count':len(rows),'normalized_instruction_sha256':sha('\n'.join(expected).encode()),'all_instructions_equal_after_branch_destination_normalization':True}
  disassembly[str(n)]='\n'.join('%08x: %s %s'%r for r in rows)
  remaining.remove(n)
 fragment=source_fragment(source)
 rows=original_rows(exe_path,0x4277f5,end=0x427e6e);compiled=J.instructions(compile32(fragment,aliases,'JUMP_002410',0x4277f5))
 expected=J.canonical(rows,True);observed=J.canonical(compiled,True)
 if expected!=observed:raise ValueError('F575 postclassification instruction mismatch')
 raw=exe[PRIMARY[0]:PRIMARY[1]];records['575_postclassification']={'executable_offset':PRIMARY[0],'virtual_address':0x4277f5,'byte_length':len(raw),'sha256':sha(raw),'instruction_count':len(rows),'normalized_instruction_sha256':sha('\n'.join(expected).encode()),'all_instructions_equal_after_branch_destination_normalization':True,'outgoing_edge':'JUMP_002432 is the original epilogue; host wrapper captures results then restores registers and returns.'}
 disassembly['575_postclassification']='\n'.join('%08x: %s %s'%r for r in rows)
 # Full original Watcom _abs: preserve the INT_MIN wrap exactly.
 absrows=original_rows(exe_path,0x476238,end=0x476238+len(G.ABS_DOS))
 if absrows[-1][1]!='ret':raise ValueError('Unreviewed DOS abs boundary')
 absraw=exe[0x67038:0x67038+len(G.ABS_DOS)]
 if absraw!=G.ABS_DOS:raise ValueError('DOS abs literal differs')
 absbody='FUNC_900997:\npush ebp\nmov ebp,esp\nmov eax,[ebp+0x8]\ntest eax,eax\njge ABS_nonnegative\nmov edx,eax\nneg edx\njmp ABS_done\nABS_nonnegative:\nmov edx,eax\nABS_done:\nmov eax,edx\npop ebp\nret\n'
 if J.canonical(absrows)!=J.canonical(J.instructions(compile32(absbody,{},'FUNC_900997',0x476238))):raise ValueError('Watcom abs instruction clone differs')
 records['abs']={'executable_offset':0x67038,'virtual_address':0x476238,'byte_length':len(absraw),'sha256':sha(absraw),'instruction_count':len(absrows),'all_instructions_equal_after_branch_destination_normalization':True,'source':'Exact uploaded DOS Watcom abs bytes; clone independently reassembled, INT_MIN stays negative.'}
 return bodies,fragment,aliases,records,disassembly

def native(bodies,fragment):
 adapter=load('contact_host_abi',PROJECT/'recovered-history/ground_harness/tools/native_reference.py')
 # Source observations are plain MOV instructions: no GPR or EFLAGS changes.
 fragment=fragment.replace('mov [ebp-0x10],esi','mov [ebp-0x10],esi\nmov [output+32],esi',1)
 fragment=fragment.replace('mov eax,esi\n\t\tcmp dword [ebp-0x10],0x258','mov eax,esi\nmov [output+36],eax\n\t\tcmp dword [ebp-0x10],0x258',1)
 fragment=fragment.replace('or byte [DATA_008696],0x40','or byte [DATA_008696],0x40\nmov dword [output+40],1',1)
 wrapper='''FUNC_900575:
push ebp
mov ebp,esp
add esp,-0xd4
push ebx
push esi
push edi
mov esi,relative
lea edi,[ebp-0x38]
mov ecx,6
rep movsd
mov ebx,object
mov edi,parent
mov eax,[input+28]
mov [ebp-0xc],eax
'''+fragment+'''
JUMP_002432:
movzx eax,al
mov [output],eax
mov eax,[ebp-0x80]
mov [output+16],eax
mov eax,[ebp-0x7c]
mov [output+20],eax
mov eax,[ebp-0x78]
mov [output+24],eax
pop edi
pop esi
pop ebx
mov esp,ebp
pop ebp
ret
FUNC_900997:
push ebp
mov ebp,esp
mov eax,[ebp+0x8]
test eax,eax
jge ABS_nonnegative
mov edx,eax
neg edx
jmp ABS_done
ABS_nonnegative:
mov edx,eax
ABS_done:
mov eax,edx
pop ebp
ret
FUNC_999999:
ret
'''
 source='\n'.join(bodies.values())+'\n'+wrapper
 source=re.sub(r'FUNC_(\d{6})_[A-Za-z0-9_]+',r'FUNC_\1',source)
 source=re.sub(r'\[ebp\+0x([89a-f][0-9a-f]{7})\]',lambda m:'[ebp-0x%x]'%(0x100000000-int(m[1],16)),source)
 source=re.sub(r'add esp,0x([89a-f][0-9a-f]{7})',lambda m:'add esp,-0x%x'%(0x100000000-int(m[1],16)),source)
 lines,_=adapter.procedures(source,HELPERS+[900575,900997]);text='\n'.join(lines)
 text=text.replace('call _abs','call FUNC_900997')
 # Bare non-DATA wrapper labels represent addresses, never memory operands.
 for label in ['relative','object','parent']:text=text.replace(','+label+'\n',',OFFSET FLAT:'+label+'\n')
 text=re.sub(r'^(mov DWORD PTR \[[^\]]+\],)(DATA_\d+)$',r'\1OFFSET FLAT:\2',text,flags=re.M)
 text+='''
FUNC_000953:
 push rbp
 mov rbp,rsp
 push rax
 push rbx
 push rcx
 mov eax,DWORD PTR [output+4]
 cmp eax,128
 jae failed
 shl eax,4
 mov DWORD PTR [output+1024+rax],953
 mov ebx,DWORD PTR [rbp+24]
 mov DWORD PTR [output+1028+rax],ebx
 mov ebx,DWORD PTR [rbp+32]
 mov DWORD PTR [output+1032+rax],ebx
 mov DWORD PTR [output+1036+rax],0
 inc DWORD PTR [output+4]
 pop rcx
 pop rbx
 pop rax
 pop rbp
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
 mov rax,0x5355524641434535
'''
 guards=[stem+'_'+suffix for stem in ['object','parent','relative','body_descriptor','parent_descriptor','ship_spec','output']for suffix in ['before','after']]
 text+=''.join(' mov QWORD PTR [%s],rax\n'%name for name in guards)
 text+='''
 mov esi,OFFSET FLAT:input+128
 mov edi,OFFSET FLAT:object
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:parent
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:body_descriptor
 mov ecx,68
 rep movsb
 mov edi,OFFSET FLAT:parent_descriptor
 mov ecx,68
 rep movsb
 mov edi,OFFSET FLAT:ship_spec
 mov ecx,24
 rep movsb
 mov esi,OFFSET FLAT:input+64
 mov edi,OFFSET FLAT:relative
 mov ecx,24
 rep movsb
 mov edi,OFFSET FLAT:output
 xor eax,eax
 mov ecx,3104
 rep stosb
 mov edi,OFFSET FLAT:DATA_004681
 mov ecx,150
 rep stosd
 mov eax,DWORD PTR [object+0x82]
 cmp eax,150
 jae failed
 mov DWORD PTR [DATA_004681+rax*4],OFFSET FLAT:body_descriptor
 mov eax,DWORD PTR [parent+0x82]
 cmp eax,150
 jae failed
 mov DWORD PTR [DATA_004681+rax*4],OFFSET FLAT:parent_descriptor
 mov DWORD PTR [body_descriptor+0x38],OFFSET FLAT:ship_spec
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [DATA_008857],eax
 movzx edx,BYTE PTR [object+0x86]
 cmp eax,edx
 jne failed
 mov eax,DWORD PTR [input+8]
 mov BYTE PTR [DATA_008696],al
 mov eax,DWORD PTR [input+12]
 mov BYTE PTR [DATA_008698],al
 mov eax,DWORD PTR [input+16]
 mov BYTE PTR [DATA_008699],al
 mov eax,DWORD PTR [input+20]
 mov BYTE PTR [DATA_008700],al
 mov eax,DWORD PTR [input+24]
 mov BYTE PTR [DATA_008707],al
 mov eax,DWORD PTR [input+32]
 mov DWORD PTR [DATA_008705],eax
 mov eax,DWORD PTR [input+36]
 mov DWORD PTR [DATA_008706],eax
 mov DWORD PTR [DATA_008702],0
 cmp DWORD PTR [input+40],0
 je pointer_initialized
 mov DWORD PTR [DATA_008702],OFFSET FLAT:parent
pointer_initialized:
 mov DWORD PTR [iteration],0
run_repeat:
 mov DWORD PTR [output+40],0
 call FUNC_900575
 inc DWORD PTR [iteration]
 mov eax,DWORD PTR [iteration]
 cmp eax,DWORD PTR [input]
 jb run_repeat
 mov DWORD PTR [output+8],eax
 mov DWORD PTR [output+12],0x5752410
 movzx eax,BYTE PTR [DATA_008696]
 mov DWORD PTR [output+44],eax
 movzx eax,BYTE PTR [DATA_008698]
 mov DWORD PTR [output+48],eax
 movzx eax,BYTE PTR [DATA_008699]
 mov DWORD PTR [output+52],eax
 movzx eax,BYTE PTR [DATA_008700]
 mov DWORD PTR [output+56],eax
 movzx eax,BYTE PTR [DATA_008707]
 mov DWORD PTR [output+60],eax
 mov eax,DWORD PTR [DATA_008857]
 mov DWORD PTR [output+64],eax
 mov eax,DWORD PTR [DATA_008705]
 mov DWORD PTR [output+68],eax
 mov eax,DWORD PTR [DATA_008706]
 mov DWORD PTR [output+72],eax
 cmp DWORD PTR [DATA_008702],OFFSET FLAT:parent
 sete al
 movzx eax,al
 mov DWORD PTR [output+76],eax
 mov esi,OFFSET FLAT:object
 mov edi,OFFSET FLAT:output+128
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:parent
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:relative
 mov ecx,24
 rep movsb
 mov esi,OFFSET FLAT:body_descriptor
 mov ecx,68
 rep movsb
 mov esi,OFFSET FLAT:parent_descriptor
 mov ecx,68
 rep movsb
 mov esi,OFFSET FLAT:ship_spec
 mov ecx,24
 rep movsb
 # Only descriptor+38 is relocated for the host pointer table.
 mov eax,DWORD PTR [input+804+56]
 mov DWORD PTR [output+828+56],eax
 mov rax,0x5355524641434535
 mov QWORD PTR [output+3088],rax
 mov QWORD PTR [output+3096],rax
'''
 text+=''.join(' cmp QWORD PTR [%s],rax\n jne failed\n'%name for name in guards)
 text+='''
 xor r8d,r8d
write_more:
 mov eax,1
 mov edi,1
 lea rsi,[output+r8]
 mov edx,3104
 sub edx,r8d
 syscall
 test eax,eax
 jle failed
 add r8d,eax
 cmp r8d,3104
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
DATA_007719: .quad FUNC_001520
DATA_007737: .quad FUNC_001522
DATA_007738: .quad FUNC_001502
DATA_007756: .quad FUNC_001538
.section .bss
.align 8
input: .zero 1024
iteration: .zero 4
DATA_004681: .zero 600
DATA_008696: .zero 1
DATA_008698: .zero 1
DATA_008699: .zero 1
DATA_008700: .zero 1
DATA_008702: .zero 4
DATA_008705: .zero 4
DATA_008706: .zero 4
DATA_008707: .zero 1
DATA_008857: .zero 4
'''
 for stem,size in [('object',338),('parent',338),('relative',24),('body_descriptor',68),('parent_descriptor',68),('ship_spec',24),('output',OUTPUT)]:text+=f'{stem}_before: .zero 8\n{stem}: .zero {size}\n{stem}_after: .zero 8\n'
 text+='''
.align 16
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
'''
 return '.intel_syntax noprefix\n.code64\n.section .text\n'+text

def resources(exe):
 image=G.Image(exe);result={}
 for model in [15,24,38,81,96,117,118,121,130,134,140]:
  pointer_at=0xba8fc+model*4;at=image.pointer(pointer_at,68);descriptor=exe[at:at+68];spec_pointer=struct.unpack_from('<I',descriptor,56)[0]
  spec_at=image.offset(spec_pointer,24)if spec_pointer else None;spec=exe[spec_at:spec_at+24]if spec_at is not None else bytes(24)
  result[str(model)]={'model_index':model,'descriptor_file_offset':at,'descriptor_hex':descriptor.hex(),'descriptor_sha256':sha(descriptor),'spec_file_offset':spec_at,'spec_hex':spec.hex(),'spec_sha256':sha(spec),'actual_source_spec_pointer_u32':spec_pointer}
 for model in [15,24,38]:
  original=json.loads((PROJECT/'data/ffe_hyperdrive.json').read_text())['ship_specs'][str(model)]
  if original['spec_hex']!=result[str(model)]['spec_hex']:raise ValueError('Frozen original source ship spec mismatch')
 return result

def cases(models):
 rows=[];q=0x7fffffff
 def add(domain='natural_contact',body_model=38,parent_model=117,relative=None,velocity=None,up=None,forward=None,gear=65535,flags=0,active=0,enabled=1,kind=1,previous=0,current=0,collider=0,selected=False,distance=0x10000000,position=None,repeat=1,mass_override=None,player_index=17):
  body=bytearray((i*43+7)&255 for i in range(338));parent=bytearray((i*59+11)&255 for i in range(338))
  matrix=[q,0,0]+(up or [0,q,0])+(forward or [0,0,q])
  struct.pack_into('<9i',body,0,*matrix);struct.pack_into('<I',body,0x82,body_model);body[0x86]=player_index;body[0x87]=3
  struct.pack_into('<3i',body,0x8c,*(velocity or [0,0,0]));struct.pack_into('<H',body,0x9e,gear)
  struct.pack_into('<3q',body,0x3e,*(position or [100000,-200000,300000]));struct.pack_into('<q',body,0x140,current)
  struct.pack_into('<9i',parent,0,q,0,0,0,q,0,0,0,q);struct.pack_into('<I',parent,0x82,parent_model);parent[0x86]=9
  struct.pack_into('<q',parent,0x138,1000);struct.pack_into('<q',parent,0x140,1001)
  descriptor=bytes.fromhex(models[str(body_model)]['descriptor_hex']);parent_descriptor=bytes.fromhex(models[str(parent_model)]['descriptor_hex']);spec=bytearray.fromhex(models[str(body_model)]['spec_hex'])
  if mass_override is not None:struct.pack_into('<h',spec,6,mass_override)
  point=relative or [0,1<<40,0]
  ctx={'relative_position_s64':point,'relative_position_s64_hex':struct.pack('<3q',*point).hex(),'distance_squared_s32':s32(distance),'globals':{'collision_flags_u8':flags,'collider_index_u8':collider,'collision_active_u8':active,'collision_enabled_u8':enabled,'previous_altitude_s64':previous,'previous_altitude_s64_hex':struct.pack('<q',previous).hex(),'collision_kind_u8':kind,'player_object_index_u32':player_index,'collider_parent_selected':selected},'body_descriptor_hex':descriptor.hex(),'parent_descriptor_hex':parent_descriptor.hex(),'body_spec_hex':spec.hex()}
  rows.append({'operation':'F575_postclassification','domain':domain,'body_hex':body.hex(),'parent_hex':parent.hex(),'context':ctx,'repeat_count':repeat})
 for velocity in [[0,0,0],[600,0,0],[601,0,0],[-600,0,0],[200,200,200],[201,200,200],[0,-1,0],[0,-600,0],[0,-601,0],[2147483647,0,0],[-2147483648,0,0],[-2147483648,-2147483648,1]]:
  for gear in [0,1,65534,65535]:
   for enabled in [0,1,255]:add(domain='signed_speed_gear_gate',velocity=velocity,gear=gear,enabled=enabled)
 for up in [[0,q,0],[0,0x77ffffff,0],[0,0x78000000,0],[0,0x78000001,0],[0,0x78000002,0],[q,0,0],[0,-q,0],[0,0,0]]:
  for flags in [0,0x40,0x80,255]:
   for active in [0,1,255]:add(domain='alignment_gate_existing_flags',up=up,flags=flags,active=active)
 for body_model in [15,24,38]:
  for parent_model in [117,118,121,130,134,140]:
   for velocity in [[1000,-1000,0],[0,-10000,0],[0,10000,0],[1000000,-1000000,123456],[0,0,0]]:
    add(domain='actual_source_profiles_player_impact',body_model=body_model,parent_model=parent_model,velocity=velocity,gear=0,current=5000,previous=1234)
 for current,previous in [(0,0),(1,0),(-1,0),(2147483647,0),(2147483648,0),(4294967295,0),(4294967296,0),(-4294967297,0),((1<<63)-1,-1),(-(1<<63),1),(100,-(1<<63))]:
  for point in [[0,1<<40,0],[1<<40,0,0],[0,-(1<<40),0],[1<<44,1<<44,-(1<<44)],[0,0,0]]:
   add(domain='natural_correction_lowword_signed64_wrap',current=current,previous=previous,relative=point,velocity=[3,-7,11],gear=0)
 for kind in [0,2,127,128,255]:
  for parent_model in [81,96,117]:
   for distance in [0,1,2,0x10000,0x10000000,0x3fffffff,0x40000000,0x7fffffff,0x80000000,0xffffffff]:
    add(domain='supplied_non_natural_classification',kind=kind,parent_model=parent_model,distance=distance,relative=[123456,456789,-234567],velocity=[13,-500,27],gear=0)
 for collider in [0,1,9,255]:
  for selected in [False,True]:
   for flags in [0,1,0x40,0x80,255]:add(domain='collider_bookkeeping_preservation',collider=collider,selected=selected,flags=flags,enabled=0,gear=0)
 for player in [0,1,17,255]:
  for repeat in [2,3,8]:add(domain='canonical_player_repeat',player_index=player,velocity=[999,-3000,32],gear=0,current=5000,repeat=repeat)
 for mass in [-32768,-1,0,1,32767]:
  for velocity in [[0,-1,0],[0,-100000,0],[2147483647,2147483647,2147483647]]:add(domain='synthetic_spec_operand',mass_override=mass,velocity=velocity,gear=0)
 rng=random.Random(0x5752410)
 for _ in range(256):
  point=[rng.randrange(-(1<<47),1<<47)for _ in range(3)]
  add(domain='seeded_classified_raw_transition',relative=point,velocity=[s32(rng.getrandbits(32))for _ in range(3)],gear=rng.choice([0,65535]),flags=rng.randrange(256),enabled=rng.choice([0,1,128,255]),current=rng.randrange(-(1<<48),1<<48),previous=rng.randrange(-(1<<48),1<<48),collider=rng.randrange(256),selected=bool(rng.getrandbits(1)))
 return rows

def pack(row):
 c=row['context'];g=c['globals'];out=bytearray(INPUT)
 struct.pack_into('<8I',out,0,row['repeat_count'],g['player_object_index_u32'],g['collision_flags_u8'],g['collider_index_u8'],g['collision_active_u8'],g['collision_enabled_u8'],g['collision_kind_u8'],c['distance_squared_s32']&0xffffffff)
 out[32:40]=bytes.fromhex(g['previous_altitude_s64_hex']);struct.pack_into('<I',out,40,int(g['collider_parent_selected']));out[64:88]=bytes.fromhex(c['relative_position_s64_hex'])
 out[128:466]=bytes.fromhex(row['body_hex']);out[466:804]=bytes.fromhex(row['parent_hex']);out[804:872]=bytes.fromhex(c['body_descriptor_hex']);out[872:940]=bytes.fromhex(c['parent_descriptor_hex']);out[940:964]=bytes.fromhex(c['body_spec_hex'])
 return bytes(out)

def parse(row,raw):
 if len(raw)!=OUTPUT or struct.unpack_from('<2Q',raw,3088)!=(GUARD,GUARD):raise ValueError('Native surface-contact output canary')
 if struct.unpack_from('<I',raw,12)[0]!=0x5752410:raise ValueError('Native surface-contact sentinel')
 before=pack(row);body=raw[128:466];parent=raw[466:804];point=raw[804:828]
 if parent!=before[466:804] or point!=before[64:88]:raise ValueError('Parent or original classified relative point changed')
 if raw[828:896]!=before[804:872]or raw[896:964]!=before[872:940]or raw[964:988]!=before[940:964]:raise ValueError('Original descriptor/spec changed')
 allowed=set(range(36))|set(range(0x3e,0x56))|set(range(0x8c,0x98))
 if any(a!=b and i not in allowed for i,(a,b)in enumerate(zip(before[128:466],body))):raise ValueError('Unrelated body bytes changed')
 words=struct.unpack_from('<20I',raw);count=words[1];callbacks=[list(struct.unpack_from('<4I',raw,1024+i*16))for i in range(count)]
 globals_after={'collision_flags_u8':words[11],'collider_index_u8':words[12],'collision_active_u8':words[13],'collision_enabled_u8':words[14],'previous_altitude_s64':struct.unpack_from('<q',raw,68)[0],'previous_altitude_s64_hex':raw[68:76].hex(),'collision_kind_u8':words[15],'player_object_index_u32':words[16],'collider_parent_selected':bool(words[19])}
 return {'body_hex':body.hex(),'parent_hex':parent.hex(),'relative_position_s64_hex':point.hex(),'globals':globals_after,'return_flags_u8':words[0],'landing_accepted':bool(words[10]),'normal_q31':list(struct.unpack_from('<3i',raw,16)),'initial_velocity_l1_s32':s32(words[8]),'alignment_dot_s32':s32(words[9]),'damage_calls':[{'amount_s32':s32(event[1]),'attacker_u32':event[2]}for event in callbacks],'callbacks_raw_u32':callbacks,'repeat_count':words[2]}

def execute(assembly,rows):
 with tempfile.TemporaryDirectory(prefix='surface-contact-native-')as d:
  p=Path(d);(p/'native.s').write_text(assembly)
  r=subprocess.run(['as','--64',str(p/'native.s'),'-o',str(p/'native.o')],capture_output=True,text=True)
  if r.returncode:raise ValueError(r.stderr)
  subprocess.run(['ld','-m','elf_x86_64',str(p/'native.o'),'-o',str(p/'native')],capture_output=True,check=True)
  payload=b''.join(pack(row)for row in rows);runs=[]
  for _ in range(3):
   r=subprocess.run([str(p/'native')],input=payload,capture_output=True,timeout=60)
   if r.returncode or len(r.stdout)!=len(rows)*OUTPUT:raise ValueError('Native contact execution '+str((r.returncode,len(r.stdout),len(rows)*OUTPUT)))
   runs.append(r.stdout)
  if len(set(runs))!=1:raise ValueError('Fresh source-contact process mismatch')
  r=subprocess.run([str(p/'native')],input=b''.join(pack(row)for row in reversed(rows)),capture_output=True,timeout=60)
  if r.returncode or r.stdout!=b''.join(runs[0][i*OUTPUT:(i+1)*OUTPUT]for i in range(len(rows)-1,-1,-1)):raise ValueError('Surface-contact case-order contamination')
 return [parse(row,runs[0][i*OUTPUT:(i+1)*OUTPUT])for i,row in enumerate(rows)]

def literal_controls(rows):
 # Independent, hand-worked source examples guard entry ABI, signed abs and
 # observed acceptance. Full expected states are still native outputs only.
 result=[]
 def case(domain,velocity=None,gear=None,enabled=None,**globals_filter):
  found=[]
  for row in rows:
   if row['domain']!=domain:continue
   raw=bytes.fromhex(row['body_hex']);g=row['context']['globals']
   if velocity is not None and list(struct.unpack_from('<3i',raw,0x8c))!=velocity:continue
   if gear is not None and struct.unpack_from('<H',raw,0x9e)[0]!=gear:continue
   if enabled is not None and g['collision_enabled_u8']!=enabled:continue
   if any(g[key]!=value for key,value in globals_filter.items()):continue
   found.append(row)
  if len(found)!=1:raise ValueError('Independent control selection not unique '+domain+str(globals_filter))
  return found[0]
 def check(name,row,observe,literal):
  actual=observe(row['expected'])
  if actual!=literal:raise ValueError('Independent literal control failed '+name+str((actual,literal)))
  result.append({'name':name,'case_id':row['id'],'literal_expected':literal,'observed':actual,'passed':True})
 vector=lambda e:list(struct.unpack_from('<3i',bytes.fromhex(e['body_hex']),0x8c))
 check('fully-deployed-clean-contact',case('signed_speed_gear_gate',[0,0,0],65535,1),lambda e:[e['landing_accepted'],e['globals']['collision_flags_u8'],e['globals']['collision_active_u8'],e['damage_calls'],vector(e)],[True,0x43,0,[],[0,0,0]])
 check('gear-not-ready-zero-speed-quarter-hull-request',case('signed_speed_gear_gate',[0,0,0],0,1),lambda e:[e['landing_accepted'],e['globals']['collision_flags_u8'],e['damage_calls']],[False,0x83,[{'amount_s32':100,'attacker_u32':0}]])
 check('disabled-response-no-invented-damage',case('signed_speed_gear_gate',[0,0,0],0,0),lambda e:[e['landing_accepted'],e['globals']['collision_flags_u8'],e['damage_calls']],[False,3,[]])
 check('speed600-equality-lands',case('signed_speed_gear_gate',[600,0,0],65535,1),lambda e:[e['initial_velocity_l1_s32'],e['landing_accepted'],e['damage_calls'],vector(e)],[600,True,[],[0,0,0]])
 check('speed601-tangent-damping-and-mass-floor',case('signed_speed_gear_gate',[601,0,0],65535,1),lambda e:[e['initial_velocity_l1_s32'],e['landing_accepted'],e['damage_calls'],vector(e)],[601,False,[{'amount_s32':100,'attacker_u32':0}],[400,0,0]])
 check('incoming-normal-bounce-and-source-damage',case('signed_speed_gear_gate',[0,-600,0],0,1),lambda e:[e['damage_calls'],vector(e)],[[{'amount_s32':111,'attacker_u32':0}],[0,100,0]])
 check('watcom-int-min-abs-wrap-kept',case('signed_speed_gear_gate',[-2147483648,0,0],65535,1),lambda e:[e['initial_velocity_l1_s32'],e['landing_accepted'],e['damage_calls']],[-2147483648,True,[]])
 check('old40-flag-is-not-new-acceptance',case('collider_bookkeeping_preservation',gear=0,enabled=0,collision_flags_u8=0x40,collider_index_u8=0,collider_parent_selected=False),lambda e:[e['landing_accepted'],e['globals']['collision_flags_u8']],[False,0x43])
 check('existing-collider-parent-identity-preserved',case('collider_bookkeeping_preservation',gear=0,enabled=0,collision_flags_u8=0,collider_index_u8=255,collider_parent_selected=True),lambda e:[e['globals']['collider_index_u8'],e['globals']['collider_parent_selected']],[255,True])
 return result

def main():
 p=argparse.ArgumentParser();p.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_surface_contact_native.json');p.add_argument('--validation-dir',type=Path,default=PROJECT/'validation/contact-2026-11-08/nativeproof');args=p.parse_args()
 source=args.source.read_text();exe=args.executable.read_bytes()
 if sha(exe)!=EXE_SHA or sha(args.source.read_bytes())!=ASM_SHA:raise ValueError('Unreviewed original reference image')
 helpers,fragment,aliases,proofs,disassembly=proof(source,exe,args.executable);models=resources(exe);assembly=native(helpers,fragment);rows=cases(models);results=execute(assembly,rows)
 for i,(row,result)in enumerate(zip(rows,results)):row['id']='dos-surface-contact-%04d'%i;row['expected']=result
 controls=literal_controls(rows)
 doc={'schema_version':1,'reference':'uploaded DOS FIRSTENC.EXE','executable_sha256':EXE_SHA,'pinned_asm_sha256':ASM_SHA,'source_commit':COMMIT,'case_count':len(rows),'byte_instruction_proofs':proofs,'models':models,'source_external_aliases':aliases,'callback_raw_schema':['function_number','amount_s32_bits','attacker_u32','reserved_zero'],'execution_checks':{'fresh_identical_processes':3,'reverse_case_order_identical':True,'object_parent_relative_descriptor_spec_output_canaries':True,'unrelated_body_bytes_unchanged':True,'parent_and_descriptors_and_specs_unchanged':True,'expected_transitions_computed_by_python':False},'scope':['Complete original bounded F575 JUMP002410..JUMP002431 then epilogue; original prior classification is supplied, not executed.','Canonical player body86==DATA8857 only; NPC branch is not part of generated canonical cases.','Source F953 calls are recorded without applying HP, equipment destruction, RNG or callbacks; caller owns those separately.','F577 distance-squared/raw context can be supplied independently for synthetic operand controls; no geometric hit proof follows from them.','Raw64 fields also have exact little-endian hex; JSON decimal numbers are human previews and must not be used as lossy64-bit machine inputs.','No F569/F576/F577/F578 scanner/geometry or reference-frame transition is executed; no complete F575 or original collision-engine claim.'],'invalid_domains_not_executed':['Non-player object identity: this kernel scope requires body86==player index0..255.','Malformed raw338 objects, raw68 descriptors or raw24 specification; missing descriptor/model table entry.'],'cases':rows}
 doc['independent_literal_controls']=controls
 args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(doc,indent=2)+'\n');args.validation_dir.mkdir(parents=True,exist_ok=True)
 report={k:v for k,v in doc.items()if k!='cases'};report.update(fixture_sha256=sha(args.output.read_bytes()),tool_sha256=sha(Path(__file__).read_bytes()),native_assembly_sha256=sha(assembly.encode()))
 (args.validation_dir/'source-surface-contact-native-proof.json').write_text(json.dumps(report,indent=2)+'\n');(args.validation_dir/'dos-source-surface-contact-disassembly.txt').write_text('\n\n'.join('F'+name+'\n'+text for name,text in disassembly.items()))
 print(json.dumps({'cases':len(rows),'fixture_sha256':report['fixture_sha256'],'proof_procedures':len(proofs),'primary_bytes':proofs['575_postclassification']['byte_length'],'primary_instructions':proofs['575_postclassification']['instruction_count'],'fresh_runs':3,'reverse_order':True}))
if __name__=='__main__':main()
