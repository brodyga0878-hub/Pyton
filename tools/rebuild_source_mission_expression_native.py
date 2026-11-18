#!/usr/bin/env python3
"""Whole original mission expressions, preserving inline selector tables.

Expected arithmetic is measured from reviewed source32 instructions through an
ELF64 ABI bridge. This is an offline oracle, not an Android emulator or full VM.
"""
from __future__ import annotations
import argparse,base64,copy,hashlib,json,random,re,struct,subprocess,tempfile,zlib
from pathlib import Path
import rebuild_source_natural_contact_native as N
PROJECT=N.PROJECT
PROOF=PROJECT/'validation/mission-expressions-2026-11-18/expression-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_mission_expression_native.json'
NUMBERS=[*range(20,32),462,463,922,1530,1532]
PROFILE='dos-firstenc-mission-expressions-v1'
ROOT=16384;TAIL=6160;BANK=38986;REGS=284;GLOBALS=40;VARS=1024;PROGRAM=65536
CONTEXT_KEYS=['root','root_tail','bank','event_registers','module_globals','task_variables','program','ip_u32','module_global_offset_u32','temporary_event_index_s32']
SIZES=[ROOT,TAIL,BANK,REGS,GLOBALS,VARS,PROGRAM,4,4,4]
OFFSETS=[];at=0
for count in SIZES:OFFSETS.append(at);at+=count
OWNER=at
MAX_OBS=16;MAX_TRACE=512
OPS=['F20','F21','F22','F23','F24','F25','F26','F27','F28','F29','F30','F31','F462','F463','F922','F1530','F1532']
UNDEFINED=[0,1,28,29,30,33,38,39,40,41,42,43,44]
sha=lambda raw:hashlib.sha256(raw).hexdigest()
def s32(v):return(v&0x7fffffff)-(v&0x80000000)
def normalized(rows):
 out=[]
 for _,op,args in rows:
  args=re.sub(r'\s+','',args.lower()).replace('dwordptrds:','ds:')
  if(op.startswith('j')or op=='call')and re.fullmatch(r'(?:0x)?[0-9a-f]+',args):args=hex(int(args,16))
  out.append(op+' '+args)
 return out

def positions(source):return {m[1]:0x400000+int(m[2],16)for m in re.finditer(r'^\s*((?:FUNC|JUMP|DATA)_\d+)(?:_\w+)?:\s*;\s*Pos = ([0-9a-f]+)',source,re.M)}
def source_labels(body):
 result=[]
 for piece in re.split(r'(SECTION \.data.*?SECTION \.text)',body,flags=re.S):
  if not piece.strip()or piece.startswith('SECTION .data'):continue
  ordinal=0;labels=[]
  for line in piece.splitlines():
   line=line.split(';',1)[0].strip()
   if not line:continue
   if re.fullmatch(r'(?:FUNC|JUMP)_\d+:',line):labels.append((line[:-1],ordinal))
   else:ordinal+=1
  result.append((ordinal,labels))
 return result

def chunks(body,aliases,n):
 result=[];tables=[]
 pieces=re.split(r'(SECTION \.data.*?SECTION \.text)',body,flags=re.S)
 for piece in pieces:
  if piece.startswith('SECTION .data'):
   m=re.search(r'(DATA_\d+):',piece);targets=re.findall(r'^\s*dd\s+(JUMP_\d+)',piece,re.M)
   if not m or not targets:raise ValueError('Unsupported inline resource')
   tables.append((m[1],targets));continue
  if not piece.strip():continue
  m=re.search(r'((?:FUNC|JUMP)_\d+):\s*;\s*Pos = ([0-9a-f]+)',piece)
  if not m:raise ValueError('Missing original code-region anchor')
  start=aliases[m[1]]
  clean=re.sub(r'^\s*(?:FUNC|JUMP)_\d+:.*$','',piece,flags=re.M)
  clean=re.sub(r'push dword (FUNC_\d+)',r'push OFFSET FLAT:\1',clean)
  result.append((start,'proof_entry:\n'+clean))
 return result,tables

def reprove(a):
 exe=a.exe.read_bytes();source=a.asm.read_text()
 if sha(exe)!=N.EXE_SHA or sha(a.asm.read_bytes())!=N.ASM_SHA:raise ValueError('Original identity differs')
 bodies={n:N.G.block(source,n)for n in NUMBERS};pos=positions(source);aliases=dict(pos)
 syms=set(re.findall(r'\bDATA_\d+','\n'.join(bodies.values())))
 fake={n:0x71000000+i*0x10000 for i,n in enumerate(sorted(syms))if n not in aliases};aliases.update(fake)
 previous=json.loads((PROJECT/'validation/damage-core-2026-11-17/native-proof/instruction-proof.json').read_text())
 # The original callback table, not later source Pos labels, anchors these helpers.
 for n in [922,1530]:aliases['FUNC_%06d'%n]=previous['procedures'][str(n)]['virtual_address']
 image=N.G.Image(exe)
 for _ in range(3):
  for n,body in bodies.items():
   entry='FUNC_%06d'%n;delta=aliases[entry]-pos[entry]
   for m in re.finditer(r'^\s*((?:JUMP|DATA)_\d+):\s*;\s*Pos = ([0-9a-f]+)',body,re.M):aliases[m[1]]=0x400000+int(m[2],16)+delta
   for start,clean in chunks(body,aliases,n)[0]:
    compiled=N.C.J.instructions(N.C.compile32(clean,aliases,'proof_entry',start));original=N.C.original_rows(a.exe,start,count=len(compiled))
    if len(compiled)!=len(original):raise ValueError('Code-region boundary differs')
    for cr,orr in zip(compiled,original):
     cs=re.findall('0x[0-9a-f]+',cr[2]);os=re.findall('0x[0-9a-f]+',orr[2])
     if len(cs)!=len(os):continue
     for cv,ov in zip(map(lambda x:int(x,16),cs),map(lambda x:int(x,16),os)):
      for sym,fv in fake.items():
       if -1024<cv-fv<1024:aliases[sym]=ov-(cv-fv)
    source_calls=[]
    for line in clean.splitlines():
     match=re.match(r'\s*call(?: near)?\s+(\[DATA_\d+\]|FUNC_\d+(?:_\w+)?)',line)
     if match:source_calls.append(re.sub(r'(FUNC_\d+)_\w+',r'\1',match[1].strip('[]')))
     elif re.match(r'\s*call\s+',line):source_calls.append(None)
    actual_calls=[r for r in original if r[1]=='call']
    if len(actual_calls)!=len(source_calls):raise ValueError('Call sequence differs')
    for sym,row in zip(source_calls,actual_calls):
     if sym is None:continue
     match=re.search(r'(?:0x)?([0-9a-f]{6,})',row[2]);value=int(match[1],16);aliases[sym]=value
     if sym.startswith('DATA_'):
      target=struct.unpack_from('<I',exe,image.offset(value,4))[0]
      expected='FUNC_000922'if sym=='DATA_007217'else'FUNC_001532'if sym=='DATA_007754'else None
      if expected:aliases[expected]=target
 records={};disassembly=[];all_code_addresses=set();tables_pending=[]
 for n,body in bodies.items():
  entry='FUNC_%06d'%n;delta=aliases[entry]-pos[entry]
  for m in re.finditer(r'^\s*((?:JUMP|DATA)_\d+):\s*;\s*Pos = ([0-9a-f]+)',body,re.M):aliases[m[1]]=0x400000+int(m[2],16)+delta
  regions,tables=chunks(body,aliases,n);label_regions=source_labels(body);records[str(n)]={'virtual_address':aliases[entry],'code_regions':[],'inline_tables':[],'instruction_count':0}
  for region_index,(start,clean)in enumerate(regions):
   compiled=N.C.J.instructions(N.C.compile32(clean,aliases,'proof_entry',start));original=N.C.original_rows(a.exe,start,count=len(compiled));actual=normalized(original);expected=normalized(compiled)
   if actual!=expected:raise ValueError('Whole DOS expression code differs F%d %s'%(n,[(i,x,y)for i,(x,y)in enumerate(zip(actual,expected))if x!=y][:8]))
   ordinal_count,label_positions=label_regions[region_index]
   if ordinal_count!=len(original)or any(index>=len(original)or aliases[label]!=original[index][0]for label,index in label_positions):raise ValueError('Source labels do not identify the same original instructions F'+str(n))
   label_proof=[{'symbol':label,'instruction_index_u32':index,'original_va_u32':original[index][0]}for label,index in label_positions]
   after=N.C.original_rows(a.exe,start,count=len(compiled)+1)[-1][0];at=image.offset(start,1);end=image.offset(after,1);raw=exe[at:end]
   record={'virtual_address':start,'executable_offset':at,'hex':raw.hex(),'sha256':sha(raw),'byte_length':len(raw),'instruction_count':len(original),'normalized_instruction_sha256':sha('\n'.join(actual).encode()),'all_original_instructions_equal':True,'source_label_instruction_boundaries':label_proof}
   records[str(n)]['code_regions'].append(record);records[str(n)]['instruction_count']+=len(original);all_code_addresses.update(row[0]for row in original)
   disassembly+=['F%d code region %08x'%(n,start),*('%08x: %s %s'%r for r in original)]
  tables_pending.extend((n,name,targets)for name,targets in tables)
 variants=[]
 for n,name,targets in tables_pending:
  at=image.offset(aliases[name],len(targets)*4);raw=exe[at:at+len(targets)*4];wanted=struct.pack('<%dI'%len(targets),*(aliases[t]for t in targets))
  if raw!=wanted:
   by_address={aliases[m]:m for m in re.findall(r'^\s*(JUMP_\d+):',bodies[n],re.M)}
   actual_words=struct.unpack('<%dI'%len(targets),raw)
   if any(value not in by_address for value in actual_words):raise ValueError('Unknown actual inline target '+name)
   original_targets=targets;targets=[by_address[value]for value in actual_words]
   for index,(old,new)in enumerate(zip(original_targets,targets)):
    if old!=new:variants.append({'procedure_u32':n,'table':name,'slot_u32':index,'JJFFE_target_symbol':old,'DOS_target_symbol':new,'DOS_target_original_va_u32':aliases[new]})
   match=re.search(r'(SECTION \.data.*?SECTION \.text)',bodies[n],re.S);part=match[1];iterator=iter(targets);replacement=re.sub(r'^\s*dd\s+JUMP_\d+',lambda m:'\tdd '+next(iterator),part,flags=re.M);bodies[n]=bodies[n].replace(part,replacement)
   wanted=struct.pack('<%dI'%len(targets),*(aliases[t]for t in targets))
  if raw!=wanted or any(aliases[t]not in all_code_addresses for t in targets):raise ValueError('Inline table bytes/actual code targets differ '+name)
  records[str(n)]['inline_tables'].append({'symbol':name,'virtual_address':aliases[name],'executable_offset':at,'hex':raw.hex(),'sha256':sha(raw),'entry_count':len(targets),'target_symbols':targets,'target_original_va_u32':[aliases[t]for t in targets],'all_targets_are_proved_instruction_boundaries':True})
 captured='\n'.join(bodies[n]for n in NUMBERS)+'\nFUNC_999999:\nret\n'
 used=set(re.findall(r'\b(?:DATA|FUNC|JUMP)_\d+','\n'.join(bodies.values())))
 bindings={k:aliases[k]for k in sorted(used)if k in aliases}
 root=aliases['DATA_008804'];root_fields={k:aliases[k]-root for k in sorted(syms)if 0<=aliases[k]-root<0x5810}
 expected={'DATA_009093':0x50e0,'DATA_009095':0x50f8,'DATA_009133':0x580c,'DATA_008861':0xc8,'DATA_008862':0xcc,'DATA_008807':4}
 if root!=0x64213c or any(root_fields.get(k)!=v for k,v in expected.items())or aliases['DATA_008548']!=0x60be08 or aliases['DATA_008560']!=0x60bf4c:raise ValueError('Actual DOS owner bindings differ')
 meta={'schema':'starfrontier-original-mission-expression-proof-v1','source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'source_procedures_sha256':sha(captured.encode()),'bindings':bindings,'procedures':records,'whole_procedure_count':len(NUMBERS),'whole_instruction_count':sum(r['instruction_count']for r in records.values()),'all_code_regions_equal':True,'all_source_label_instruction_boundaries_equal':True,'all_inline_table_bytes_and_targets_equal':True,'source_table_variants':variants,'unmodified_JJFFE_tables_all_equal':not bool(variants),'root_original_va_u32':root,'root_fields':root_fields,'event_registers_original_va_u32':0x60be08,'module_globals_original_va_u32':0x60bde0,'temporary_original_va_u32':0x60bf4c,'undefined_F31_selector_slots':UNDEFINED,'source_diagnostics':'Undefined local-result branches are rejected; no initial stack value is asserted as a source result. Later JJFFE Pos labels of RNG/lookup helpers are replaced by actual DOS callback targets.'}
 a.proof_dir.mkdir(parents=True,exist_ok=True);(a.proof_dir/'source-procedures.asm').write_text(captured);(a.proof_dir/'instruction-proof.json').write_text(json.dumps(meta,indent=2)+'\n');(a.proof_dir/'dos-disassembly.txt').write_text('\n'.join(disassembly)+'\n')
 return meta,captured

def verify(proof=PROOF):
 meta=json.loads((proof/'instruction-proof.json').read_text());source=(proof/'source-procedures.asm').read_text()
 if meta['source_executable_sha256']!=N.EXE_SHA or sha(source.encode())!=meta['source_procedures_sha256']:raise ValueError('Archived expression identity differs')
 aliases=meta['bindings'];addresses=set()
 for n in NUMBERS:
  body=N.G.block(source,n);regions,tables=chunks(body,aliases,n);record=meta['procedures'][str(n)]
  if len(regions)!=len(record['code_regions'])or len(tables)!=len(record['inline_tables']):raise ValueError('Archived code/table segmentation differs')
  for region_index,((start,clean),r)in enumerate(zip(regions,record['code_regions'])):
   rows=N.C.J.instructions(N.C.compile32(clean,aliases,'proof_entry',start));raw=bytes.fromhex(r['hex'])
   if sha(raw)!=r['sha256']or len(rows)!=r['instruction_count']or sha('\n'.join(normalized(rows)).encode())!=r['normalized_instruction_sha256']:raise ValueError('Archived whole code proof differs F'+str(n))
   # Actual stored bytes are disassembled separately; source assembly is not its own oracle.
   with tempfile.TemporaryDirectory(prefix='mission-original-region-')as directory:
    p=Path(directory)/'raw';p.write_bytes(raw);text=subprocess.check_output(['objdump','-D','-b','binary','-m','i386','-Mintel','--no-show-raw-insn','--adjust-vma='+hex(start),str(p)],text=True);original=N.C.J.instructions(text)
   if normalized(original)!=normalized(rows):raise ValueError('Actual archived code bytes differ')
   ordinal_count,labels=source_labels(body)[region_index]
   wanted_labels=[{'symbol':label,'instruction_index_u32':index,'original_va_u32':original[index][0]}for label,index in labels]
   if ordinal_count!=len(original)or wanted_labels!=r['source_label_instruction_boundaries']or any(aliases[label]!=original[index][0]for label,index in labels):raise ValueError('Archived source-label/code binding differs')
   addresses.update(row[0]for row in original)
  for(name,targets),r in zip(tables,record['inline_tables']):
   wanted=struct.pack('<%dI'%len(targets),*(aliases[t]for t in targets));raw=bytes.fromhex(r['hex'])
   if raw!=wanted or sha(raw)!=r['sha256']:raise ValueError('Archived inline table differs')
 for record in meta['procedures'].values():
  for table in record['inline_tables']:
   if any(value not in addresses for value in table['target_original_va_u32']):raise ValueError('Unproved inline branch target')
 return meta,source

def trace(n):
 return 'pushfq\npush rax\npush rcx\nmov ecx,DWORD PTR [e_trace_count]\ncmp ecx,512\njae e_abort\nmov DWORD PTR [e_trace+rcx*4],%d\ninc DWORD PTR [e_trace_count]\npop rcx\npop rax\npopfq\n'%n

def assembly(source,meta):
 selected=re.sub(r'(FUNC_\d+)_\w+',r'\1',source)
 selected=re.sub(r'\+0x(f[0-9a-f]{7})',lambda m:'-0x%x'%(0x100000000-int(m[1],16)),selected)
 selected=re.sub(r'add esp,0x(f[0-9a-f]{7})',lambda m:'add esp,-0x%x'%(0x100000000-int(m[1],16)),selected)
 selected=selected.replace('SECTION .data','.section .rodata').replace('SECTION .text','.section .text')
 selected=re.sub(r'^\s*dd\s+',r'.long ',selected,flags=re.M)
 selected=re.sub(r'push dword (FUNC_\d+)',r'push OFFSET FLAT:\1',selected)
 lines,_=N.Q.procedures(selected,NUMBERS);text='\n'.join(lines)
 text=re.sub(r'\[rbp[^\]]*\]',lambda m:re.sub(r'\b(eax|ebx|ecx|edx|esi|edi)\b',lambda r:'r'+r[1][1:],m[0]),text)
 text=re.sub(r'jmp \[(e\w+)\*4\+(DATA_\d+)\]',lambda m:'mov r11d,DWORD PTR [r'+m[1][1:]+'*4+'+m[2]+']\njmp r11',text)
 text=re.sub(r'call QWORD PTR \[(DATA_\d+)\]',r'mov r11d,DWORD PTR [\1]\ncall r11',text)
 for n in NUMBERS:text=text.replace('FUNC_%06d:\n'%n,'FUNC_%06d:\n'%n+trace(n),1)
 boundaries=[]
 for n,argc in [(48,3),(85,2),(96,3),(106,1),(392,2),(461,1),(649,1),(658,1),(857,2),(870,1),(871,1),(909,2),(1476,0)]:
  loads=['xor esi,esi','xor edx,edx','xor ecx,ecx','xor r8d,r8d','xor r9d,r9d','mov QWORD PTR [e_extra3],0','mov QWORD PTR [e_extra4],0']
  if argc:loads.append('mov esi,DWORD PTR [rbp+16]')
  if argc>1:loads.append('mov edx,DWORD PTR [rbp+24]')
  if argc>2:loads.append('mov ecx,DWORD PTR [rbp+32]')
  if n==461:loads+=['mov esi,DWORD PTR [rbp+24]','mov r8d,DWORD PTR [rbp+16]']
  if n==658:loads+=['mov r8d,DWORD PTR [rbp+24]']
  if n==870:loads+=['mov r8d,DWORD PTR [rbp+24]','mov r9d,DWORD PTR [rbp+32]','mov eax,DWORD PTR [rbp+40]','mov [e_extra3],rax','mov eax,DWORD PTR [rbp+48]','mov [e_extra4],rax']
  if n==871:loads+=['mov r8d,DWORD PTR [rbp+24]','mov r9d,DWORD PTR [rbp+48]']
  boundaries.append('FUNC_%06d:\n'%n+trace(n)+'''push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
'''+ '\n'.join(loads)+f'''\nmov edi,{n}
and rsp,-16
call e_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret
''')
 entry=r'''
.global call_kernel
call_kernel:
mov [e_saved_rsp],rsp
mov esp,OFFSET FLAT:e_stack_end
cmp edi,0
je e_call20
cmp edi,1
je e_call21
cmp edi,2
je e_call22
cmp edi,3
je e_call23
cmp edi,4
je e_call24
cmp edi,5
je e_call25
cmp edi,6
je e_call26
cmp edi,7
je e_call27
cmp edi,8
je e_call28
cmp edi,9
je e_call29
cmp edi,10
je e_call30
cmp edi,11
je e_call31
cmp edi,12
je e_call462
cmp edi,13
je e_call463
cmp edi,14
je e_call922
cmp edi,15
je e_call1530
cmp edi,16
je e_call1532
jmp e_abort
e_call20:
push OFFSET FLAT:e_ip
call FUNC_000020
jmp e_called
e_call21:
push rsi
call FUNC_000021
jmp e_called
e_call22:
push rdx
push rsi
call FUNC_000022
xor eax,eax
jmp e_called
e_call23:
push rsi
call FUNC_000023
jmp e_called
e_call24:
push rsi
call FUNC_000024
jmp e_called
e_call25:
push OFFSET FLAT:FUNC_000030
push OFFSET FLAT:e_program
call FUNC_000025
jmp e_called
e_call26:
push rdx
push OFFSET FLAT:FUNC_000030
push OFFSET FLAT:e_program
call FUNC_000026
jmp e_called
e_call27:
push rdx
mov eax,OFFSET FLAT:FUNC_000028
cmp esi,29
jne e_pred_ready
mov eax,OFFSET FLAT:FUNC_000029
e_pred_ready:
push rax
push OFFSET FLAT:e_bank
call FUNC_000027
jmp e_called
e_call28:
imul esi,esi,338
add esi,OFFSET FLAT:e_bank+116
push rsi
call FUNC_000028
jmp e_called
e_call29:
imul esi,esi,338
add esi,OFFSET FLAT:e_bank+116
push rsi
call FUNC_000029
jmp e_called
e_call30:
add esi,OFFSET FLAT:e_program
push rsi
call FUNC_000030
jmp e_called
e_call31:
push OFFSET FLAT:e_task
push OFFSET FLAT:e_ip
call FUNC_000031
jmp e_called
e_call462:
push OFFSET FLAT:e_program
call FUNC_000462
jmp e_called
e_call463:
push rsi
push OFFSET FLAT:e_program
call FUNC_000463
test eax,eax
jz e_called
sub eax,OFFSET FLAT:e_program
inc eax
jmp e_called
e_call922:
push rsi
call FUNC_000922
jmp e_called
e_call1530:
call FUNC_001530
jmp e_called
e_call1532:
push OFFSET FLAT:e_bank
push rsi
call FUNC_001532
sub eax,OFFSET FLAT:e_bank
e_called:
mov rsp,[e_saved_rsp]
ret
e_abort:
mov edi,97
mov eax,60
syscall
'''
 aliases=[]
 for key,off in meta['root_fields'].items():aliases.append('%s=e_root+%d'%(key,off))
 aliases+=['DATA_008548=e_events','DATA_008560=e_temporary']
 storage='''
.section .bss
.balign 16
e_stack:.zero 4194304
e_stack_end:
e_saved_rsp:.zero 8
 .global e_extra3,e_extra4
e_extra3:.zero 8
e_extra4:.zero 8
'''
 return '.intel_syntax noprefix\n.code64\n.section .text\n'+text+'\n.section .text\n'+entry+'\n'+'\n'.join(boundaries)+'\n.section .data\nDATA_007217:.long FUNC_000922\nDATA_007754:.long FUNC_001532\n'+'\n'.join(aliases)+storage+'\n.section .note.GNU-stack,"",@progbits\n'

C=r'''
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <setjmp.h>
#define ROOT 16384
#define TAIL 6160
#define BANK 38986
#define REGS 284
#define GLOBALS 40
#define VARS 1024
#define PROGRAM 65536
#define OWNER (ROOT+TAIL+BANK+REGS+GLOBALS+VARS+PROGRAM+12)
#define BASE (64+OWNER+512*4)
#define RECORD (64+OWNER*2+4096)
#define MAX 16
struct __attribute__((packed)) Patch{uint32_t owner,offset,size,pad;uint8_t data[64];};
struct __attribute__((packed)) Script{uint32_t kind,argc,args[6],result,outlen,patches,pad[5];struct Patch patch[12];uint8_t output[4096];};
struct __attribute__((packed)) Input{uint32_t h[16];uint8_t owner[OWNER];struct Script scripts[MAX];};
struct GuardRoot{uint8_t left[64],data[ROOT+TAIL],right[64];} g_root;
struct GuardBank{uint8_t left[64],data[BANK],right[64];} g_bank;
struct GuardRegs{uint8_t left[64],data[REGS],right[64];} g_events;
struct GuardGlobals{uint8_t left[64],data[GLOBALS],right[64];} g_globals;
struct GuardVars{uint8_t left[64],data[VARS],right[64];} g_vars;
struct GuardProgram{uint8_t left[64],data[PROGRAM],right[64];} g_program;
/* External names bind the original instruction operands to these exact owners. */
asm(".global e_root,e_bank,e_events,e_globals,e_vars,e_program\ne_root=g_root+64\ne_bank=g_bank+64\ne_events=g_events+64\ne_globals=g_globals+64\ne_vars=g_vars+64\ne_program=g_program+64");
#define e_root g_root.data
#define e_bank g_bank.data
#define e_events g_events.data
#define e_globals g_globals.data
#define e_vars g_vars.data
#define e_program g_program.data
uint8_t e_task[36],e_descriptor[32],e_market[308];uint32_t e_ip,e_global_base;int32_t e_temporary;uint32_t e_trace[512],e_trace_count;
extern uintptr_t e_extra3,e_extra4;
extern uint32_t call_kernel(uint32_t,uint32_t,uint32_t);
static struct Input input;static uint8_t output[BASE+MAX*RECORD],logical[OWNER];static uint32_t used,status;static jmp_buf e_jump;
static const uint32_t sizes[10]={ROOT,TAIL,BANK,REGS,GLOBALS,VARS,PROGRAM,4,4,4};
static const uint32_t offsets[10]={0,ROOT,ROOT+TAIL,ROOT+TAIL+BANK,ROOT+TAIL+BANK+REGS,ROOT+TAIL+BANK+REGS+GLOBALS,ROOT+TAIL+BANK+REGS+GLOBALS+VARS,OWNER-12,OWNER-8,OWNER-4};
static uint32_t get(const void*p){uint32_t n;memcpy(&n,p,4);return n;}static void put(void*p,uint32_t n){memcpy(p,&n,4);}
static uint32_t body_to_host(uint32_t n){if(!n)return 0;if(n<116||(n-116)%338||(n-116)/338>114)exit(90);return(uint32_t)(uintptr_t)(e_bank+n);}
static uint32_t body_to_logical(uint32_t n){if(!n)return 0;uintptr_t b=(uintptr_t)e_bank;if(n<b+116||n>b+116+114*338||(n-b-116)%338)exit(91);return n-(uint32_t)b;}
static void capture(uint8_t*p){memcpy(p,e_root,ROOT+TAIL);put(p+0xc8,body_to_logical(get(e_root+0xc8)));put(p+0xcc,body_to_logical(get(e_root+0xcc)));if(get(e_root+0x580c)!=(uint32_t)(uintptr_t)e_bank)exit(92);put(p+0x580c,1);memcpy(p+offsets[2],e_bank,BANK);memcpy(p+offsets[3],e_events,REGS);memcpy(p+offsets[4],e_globals,GLOBALS);memcpy(p+offsets[5],e_vars,VARS);memcpy(p+offsets[6],e_program,PROGRAM);put(p+offsets[7],e_ip-(uint32_t)(uintptr_t)e_program);put(p+offsets[8],e_global_base);put(p+offsets[9],(uint32_t)e_temporary);}
static void load(const uint8_t*p){memcpy(e_root,p,ROOT+TAIL);put(e_root+0xc8,body_to_host(get(p+0xc8)));put(e_root+0xcc,body_to_host(get(p+0xcc)));if(get(p+0x580c)!=1)exit(93);put(e_root+0x580c,(uint32_t)(uintptr_t)e_bank);memcpy(e_bank,p+offsets[2],BANK);memcpy(e_events,p+offsets[3],REGS);memcpy(e_globals,p+offsets[4],GLOBALS);memcpy(e_vars,p+offsets[5],VARS);memcpy(e_program,p+offsets[6],PROGRAM);e_ip=(uint32_t)(uintptr_t)e_program+get(p+offsets[7]);e_global_base=get(p+offsets[8]);e_temporary=(int32_t)get(p+offsets[9]);memset(e_task,0xa5,36);memset(e_descriptor,0xa5,32);put(e_descriptor+0x14,e_global_base==0xffffffff?0:(uint32_t)(uintptr_t)(e_globals+e_global_base));put(e_task+0x1c,(uint32_t)(uintptr_t)e_descriptor);put(e_task+0x20,(uint32_t)(uintptr_t)e_vars);}
static void setguards(void){memset(g_root.left,0x6d,64);memset(g_root.right,0x7b,64);memset(g_bank.left,0x6d,64);memset(g_bank.right,0x7b,64);memset(g_events.left,0x6d,64);memset(g_events.right,0x7b,64);memset(g_globals.left,0x6d,64);memset(g_globals.right,0x7b,64);memset(g_vars.left,0x6d,64);memset(g_vars.right,0x7b,64);memset(g_program.left,0x6d,64);memset(g_program.right,0x7b,64);}
static void guards(void){uint8_t*left[]={g_root.left,g_bank.left,g_events.left,g_globals.left,g_vars.left,g_program.left};uint8_t*right[]={g_root.right,g_bank.right,g_events.right,g_globals.right,g_vars.right,g_program.right};for(int i=0;i<6;i++)for(int j=0;j<64;j++)if(left[i][j]!=0x6d||right[i][j]!=0x7b)exit(94);if(memcmp(e_program,input.owner+offsets[6],PROGRAM))exit(95);}
uint32_t e_observe(uint32_t kind,uint32_t a,uint32_t b,uint32_t c,uintptr_t out1,uintptr_t out2){uint32_t argc=kind==48||kind==96?3:kind==85||kind==392||kind==857||kind==909?2:kind==1476?0:1;uint32_t args[6]={a,b,c,0,0,0};if(kind==392)args[0]=body_to_logical(a);if(argc<3)args[2]=0;if(argc<2)args[1]=0;if(!argc)args[0]=0;
 if(used>=MAX)exit(96);uint8_t*row=output+BASE+used*RECORD;put(row,kind);put(row+4,argc);memcpy(row+8,args,24);capture(row+64);
 if(used>=input.h[5]){status=1;put(row+32,0);capture(row+64+OWNER);used++;longjmp(e_jump,1);return 0;}
 struct Script*s=&input.scripts[used];if(s->kind!=kind||s->argc!=argc||memcmp(s->args,args,24))exit(98);
 capture(logical);for(uint32_t i=0;i<s->patches;i++){struct Patch*p=&s->patch[i];if(p->owner>=10||p->owner==6||p->owner==7||p->owner==8||p->size>64||p->offset+p->size>sizes[p->owner])exit(99);if(p->owner==5&&p->offset+p->size>input.h[4])exit(100);memcpy(logical+offsets[p->owner]+p->offset,p->data,p->size);}load(logical);
 uint32_t want=kind==461?4096:kind==649?(s->result?308:0):kind==658?2:kind==870?16:kind==871?8:0;if(s->outlen!=want)exit(101);put(row+32,s->result);put(row+36,s->outlen);memcpy(row+64+2*OWNER,s->output,s->outlen);
 if(kind==461||kind==658)memcpy((void*)out1,s->output,s->outlen);
 if(kind==649&&s->result)memcpy(e_market,s->output,308);
 if(kind==870){memcpy((void*)out1,s->output,4);memcpy((void*)out2,s->output+4,4);memcpy((void*)e_extra3,s->output+8,4);memcpy((void*)e_extra4,s->output+12,4);}
 if(kind==871){memcpy((void*)out1,s->output,4);memcpy((void*)out2,s->output+4,4);}
 capture(row+64+OWNER);used++;return kind==649?(s->result?(uint32_t)(uintptr_t)e_market:0):s->result;
}
int main(void){while(fread(&input,1,sizeof input,stdin)==sizeof input){if(input.h[0]>16||input.h[3]>PROGRAM||input.h[4]>VARS||input.h[5]>MAX)return 81;setguards();load(input.owner);memset(output,0,sizeof output);used=status=e_trace_count=0;volatile uint32_t result=0;if(setjmp(e_jump)==0)result=call_kernel(input.h[0],input.h[1],input.h[2]);guards();put(output,0x31e02055);put(output+4,BASE+used*RECORD);put(output+8,status);put(output+12,result);put(output+16,used);put(output+20,e_trace_count);put(output+24,input.h[0]!=2&&input.h[0]!=13&&input.h[0]!=16);capture(output+64);memcpy(output+64+OWNER,e_trace,e_trace_count*4);if(fwrite(output,1,BASE+used*RECORD,stdout)!=BASE+used*RECORD)return 82;}return 0;}
'''

def context_bytes(ctx):
 buffers=[bytes.fromhex(ctx[k])for k in CONTEXT_KEYS[:7]]
 buffers[5]=buffers[5].ljust(VARS,b'\xa5');buffers[6]=buffers[6].ljust(PROGRAM,b'\xa5')
 return b''.join(buffers)+struct.pack('<IIi',ctx['ip_u32'],ctx['module_global_offset_u32'],ctx['temporary_event_index_s32'])
def context(raw,row):
 ctx={k:raw[off:off+size].hex()for k,off,size in zip(CONTEXT_KEYS[:7],OFFSETS,SIZES)}
 ctx['task_variables']=bytes.fromhex(ctx['task_variables'])[:len(bytes.fromhex(row['context_before']['task_variables']))].hex();ctx['program']=bytes.fromhex(ctx['program'])[:len(bytes.fromhex(row['context_before']['program']))].hex()
 ctx.update(zip(CONTEXT_KEYS[7:],struct.unpack_from('<IIi',raw,OWNER-12)));return ctx

def packet(row):
 args=row.get('args',[]);a=args[0]if args else 0;b=args[1]if len(args)>1 else 0;ctx=row['context_before'];scripts=row.get('scripts',[])
 out=struct.pack('<16I',OPS.index(row['operation']),a&0xffffffff,b&0xffffffff,len(bytes.fromhex(ctx['program'])),len(bytes.fromhex(ctx['task_variables'])),len(scripts),*([0]*10))+context_bytes(ctx)
 for s in scripts:
  values=[v&0xffffffff for v in s['args']];patches=s.get('patches',[]);output=bytes.fromhex(s.get('output_hex',''))
  out+=struct.pack('<16I',s['kind'],len(values),*values,*([0]*(6-len(values))),s['return_u32'],len(output),len(patches),*([0]*5))
  for p in patches:out+=struct.pack('<4I',p['owner'],p['offset'],len(bytes.fromhex(p['hex'])),0)+bytes.fromhex(p['hex']).ljust(64,b'\0')
  out+=bytes((12-len(patches))*80)+output.ljust(4096,b'\0')
 return out+bytes((MAX_OBS-len(scripts))*5120)
def decoded_output(raw,row):
 h=struct.unpack_from('<16I',raw)
 if h[0]!=0x31e02055 or h[1]!=len(raw)or h[2]or h[4]!=len(row.get('scripts',[]))or len(raw)!=64+OWNER+MAX_TRACE*4+h[4]*(64+2*OWNER+4096):raise ValueError(('Native expression output',row['name'],h[:7]))
 base=64+OWNER+MAX_TRACE*4;stride=64+2*OWNER+4096;observations=[]
 for i in range(h[4]):
  at=base+i*stride;kind,argc=struct.unpack_from('<2I',raw,at);args=list(struct.unpack_from('<6I',raw,at+8))[:argc];outlen=struct.unpack_from('<I',raw,at+36)[0]
  observations.append({'kind':'F%d'%kind,'args':args,'before':context(raw[at+64:at+64+OWNER],row),'after':context(raw[at+64+OWNER:at+64+OWNER*2],row),'return_u32':struct.unpack_from('<I',raw,at+32)[0],'input_hex':'','output_hex':raw[at+64+2*OWNER:at+64+2*OWNER+outlen].hex()})
 return {'context_after':context(raw[64:64+OWNER],row),'return_u32':h[3],'return_defined':bool(h[6]),'source_order':['F%d'%n for n in struct.unpack_from('<%dI'%h[5],raw,64+OWNER)],'observations':observations}

def build(meta,source,folder):
 folder=Path(folder);native=assembly(source,meta);(folder/'native.s').write_text(native);(folder/'support.c').write_text(C);binary=folder/'native';r=subprocess.run(['gcc','-O1','-fno-pie','-no-pie','-fno-stack-protector','-o',str(binary),str(folder/'native.s'),str(folder/'support.c')],capture_output=True,text=True)
 if r.returncode:raise ValueError(r.stderr)
 return binary,native
def run(binary,row):return subprocess.run([str(binary)],input=packet(row),capture_output=True,check=True,timeout=30).stdout

def immediate(value):return b'\x02'+struct.pack('<I',value&0xffffffff)
def expression(selector,*values):return bytes([selector])+b''.join(v if isinstance(v,bytes)else immediate(v)for v in values)
def literal(selector,index):return bytes([selector])+struct.pack('<I',index&0xffffffff)
def list_bytes():
 out=bytearray(4096)
 for i,tag in enumerate([0x76,0x22,0x85,0x10,0x80]):
  struct.pack_into('<I',out,i*68,0x12340000+i);struct.pack_into('<I',out,i*68+4,0x500+i);struct.pack_into('<H',out,i*68+0xa,tag);struct.pack_into('<H',out,i*68+0xc,tag)
 return bytes(out)
def base_context(program=b'\x02\x00\x00\x00\x00'):
 root=bytearray((i*7+3)&255 for i in range(ROOT));tail=bytearray((i*3+1)&255 for i in range(TAIL));bank=bytearray(BANK)
 struct.pack_into('<I',root,0xc8,116+17*338);struct.pack_into('<I',root,0xcc,116+9*338);struct.pack_into('<I',tail,0x180c,1)
 for slot in range(115):
  at=116+slot*338;bank[slot]=1 if slot in [1,9,17,64,114]else 0;bank[at+0x86]=slot;struct.pack_into('<I',bank,at+0x82,0x76 if slot%2 else 0x85);struct.pack_into('<I',bank,at+0xa0,0x66770000+slot);bank[at+0x14c]=0x10 if slot in[9,64,114]else 0;bank[at+0x88]=(slot*13)&255;bank[at+0xfe]=(slot*7)&255;bank[at+0xff]=(slot*9)&255
 events=struct.pack('<71I',*((i*0x01020304+0x10203040)&0xffffffff for i in range(71)));globals=struct.pack('<10I',*((0x76540000+i*0x1111)&0xffffffff for i in range(10)));variables=struct.pack('<32I',*((0xabc00000+i*0x12345)&0xffffffff for i in range(32)))
 return {'root':root.hex(),'root_tail':tail.hex(),'bank':bank.hex(),'event_registers':events.hex(),'module_globals':globals.hex(),'task_variables':variables.hex(),'program':program.hex(),'ip_u32':0,'module_global_offset_u32':0,'temporary_event_index_s32':-7}
def cases():
 rows=[]
 def add(name,op='F31',args=None,program=None,policy=None):
  row={'name':name,'operation':op,'args':args or[],'context_before':base_context(program if program is not None else immediate(0)),'scripts':[],'policy':policy or{}};rows.append(row);return row
 for value in [0,1,0x7fffffff,0x80000000,0xffffffff,0x12345678]:add('immediate-%08x'%value,program=immediate(value));add('read-word-%08x'%value,'F20',program=struct.pack('<I',value))
 for selector in range(21):add('global-get-%02d'%selector,'F21',[selector]);add('global-expression-%02d'%selector,program=literal(3,selector))
 for selector in [21,255,0xffffffff]:add('global-get-outside-%08x'%selector,'F21',[selector])
 for selector in range(21):
  for value in [0x80000000,0x12345678]:add('global-set-%02d-%08x'%(selector,value),'F22',[selector,value])
 for value in [0,1,0xfffffff,0x10000000,0x7fffffff,0xffffffff]:add('clamped-set-%08x'%value,'F22',[1,value])
 for selector in [21,255,0xffffffff]:add('ignored-global-set-%08x'%selector,'F22',[selector,0xdeadbeef])
 for index in [0,1,22,70]:add('event-register-%d'%index,program=literal(4,index))
 for index in [0,1,9]:add('module-global-%d'%index,program=literal(5,index))
 r=add('module-global-offset-window',program=literal(5,1));r['context_before']['module_global_offset_u32']=32
 for index in [0,1,17,31]:add('task-local-%d'%index,program=literal(6,index))
 unary=[7,8,9,31,34,35,36,45,47,48,49,50,51,52,53,54,55,56,57,58,60,61,62,63,64,65,67]
 for selector in unary:
  value=17 if selector in[36,56,61,62,64,65]else 0x66770072 if selector in[51,60]else 3 if selector==50 else 5 if selector in[31,35,48]else 1 if selector==34 else 0x12345678
  add('selector-%02d'%selector,program=expression(selector,value))
 for selector in [10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,32]:
  for a,b in [(0,1),(1,1),(0x80000000,3),(0xffffffff,0x7fffffff),(0x7fffffff,0xffffffff)]:add('binary-%02d-%08x-%08x'%(selector,a,b),program=expression(selector,a,b))
 for selector in [15,16]:
  for shift in [0,31,32,33,255,0xffffffff]:add('masked-shift-%02d-%08x'%(selector,shift),program=expression(selector,0x87654321,shift))
 for selector in [11,12]:
  for a,b in [(0xffffffff,2),(0x80000000,1),(0x80000000,0x7fffffff),(0x7fffffff,0xfffffffd)]:add('signed-divmod-%02d-%08x-%08x'%(selector,a,b),program=expression(selector,a,b))
 for selector in [7,8,9]:
  for value in [0,1,0x80000000,0xffffffff]:add('unary-wrap-%02d-%08x'%(selector,value),program=expression(selector,value))
 for selector in [31,35,48]:
  for value in [0,5,6,0xffffffff]:add('indexed-owner-%02d-%08x'%(selector,value),program=expression(selector,value))
 for value in [0,1,2,3,0xffffffff]:add('condition-owner-%08x'%value,program=expression(34,value))
 for second in [99,100,137,999,1000,1037,1038,0xffffffff]:add('body-property-%08x'%second,program=expression(37,17,second))
 add('body-property-other-cargo',program=expression(37,9,1000));add('body-property-callback-mutate',program=expression(13,expression(37,17,100),literal(3,2)),policy={'F392':{'patches':[{'owner':0,'offset':0x114,'hex':'78563412'}]}})
 for selector in [46,59]:add('ternary-%02d'%selector,program=expression(selector,0xfffff123,0x80001234,0x3f))
 for value in [0,1,86399,86400,0x7fffffff,0xffffffff]:
  add('day-convert-%08x'%value,'F23',[value]);add('tick-convert-%08x'%value,'F24',[value])
 for predicate in [28,29]:
  for serial in [0,0x66770072,0x66770040,0x66770011,0xffffffff]:add('bank-search-%d-%08x'%(predicate,serial),'F27',[predicate,serial])
 for slot in [0,9,17,64,114]:add('body-flag-%d'%slot,'F28',[slot]);add('body-kind-%d'%slot,'F29',[slot]);add('bank-pointer-%d'%slot,'F1532',[slot])
 for tag in [0,0x75,0x76,0x85,0x86,0xffff]:
  record=bytearray(68);struct.pack_into('<H',record,12,tag);add('list-predicate-%04x'%tag,'F30',[0],bytes(record))
 for ordinal in [0,1,2,5,0xffffffff]:add('list-nth-%08x'%ordinal,'F26',[30,ordinal],list_bytes());add('qualifying-nth-%08x'%ordinal,'F463',[ordinal],list_bytes())
 add('list-count','F25',[30],list_bytes());add('qualifying-count','F462',program=list_bytes())
 for bound in [0,1,2,3,0x7fffffff,0xffffffff]:add('rng-bounded-%08x'%bound,'F922',[bound])
 add('rng-seed-step','F1530')
 for value in [0,999,1000,1037,1038,0xffffffff]:add('market-property-%08x'%value,program=expression(66,17,value))
 add('market-null',program=expression(66,17,1000),policy={'F649':{'return_u32':0,'output_hex':''}})
 add('list-build-failure-58',program=expression(58,0x12345678),policy={'F461':{'return_u32':1}});add('list-build-failure-63',program=expression(63,0x12345678),policy={'F461':{'return_u32':1}})
 add('empty-generated-list58',program=expression(58,17),policy={'F461':{'output_hex':bytes(4096).hex()}});add('empty-generated-list63',program=expression(63,17),policy={'F461':{'output_hex':bytes(4096).hex()}})
 add('external-reread-right-child',program=expression(13,expression(32,1,2),literal(3,2)),policy={'F85':{'patches':[{'owner':0,'offset':0x114,'hex':'44332211'}]}})
 add('callback-replaces-player-reference',program=expression(13,expression(32,1,2),literal(3,0)),policy={'F85':{'patches':[{'owner':0,'offset':0xc8,'hex':struct.pack('<I',116+64*338).hex()}]}})
 add('random-before-provider-state',program=expression(13,expression(57,17),literal(3,2)),policy={'F857':{'patches':[{'owner':0,'offset':0x114,'hex':'01000080'}]}})
 add('nested-four-level',program=expression(13,expression(10,expression(7,5),expression(14,0,0xffffffff)),expression(25,expression(8,0x12345678),expression(15,1,31))))
 return rows

def default_script(kind,args,row):
 result=0 if kind in[48,909,461,870,871]else 1 if kind==649 else 0x12345678 if kind==658 else 0xabcdef67 if kind==1476 else (0x13570000+kind)&0xffffffff
 output=list_bytes()if kind==461 else struct.pack('<77I',*(0x55660000+i for i in range(77)))if kind==649 else bytes.fromhex('efbe')if kind==658 else struct.pack('<4I',0x11223344,0x55667788,0x99aabbcc,0xddeeff00)if kind==870 else struct.pack('<2I',0xdeadbeef,0xcafebabe)if kind==871 else b''
 policy=row.get('policy',{}).get('F%d'%kind,{})
 return {'kind':kind,'args':args,'return_u32':policy.get('return_u32',result),'output_hex':policy.get('output_hex',output.hex()),'patches':copy.deepcopy(policy.get('patches',[]))}
def fill_scripts(binary,row):
 base=64+OWNER+MAX_TRACE*4;stride=64+2*OWNER+4096
 for _ in range(MAX_OBS+1):
  raw=run(binary,row);h=struct.unpack_from('<16I',raw)
  if h[2]==0:return raw
  if h[2]!=1 or h[4]!=len(row['scripts'])+1:raise ValueError(('Unexpected pending expression',row['name'],h[:7]))
  at=base+len(row['scripts'])*stride;kind,argc=struct.unpack_from('<2I',raw,at);args=list(struct.unpack_from('<6I',raw,at+8))[:argc];row['scripts'].append(default_script(kind,args,row))
 raise ValueError('Too many expression boundaries')
def pool_rows(rows):
 pool={}
 def packed(ctx):
  out=copy.deepcopy(ctx)
  for name in CONTEXT_KEYS[:7]:
   raw=bytes.fromhex(out[name]);key=sha(raw)
   if key not in pool:pool[key]={'byte_count':len(raw),'zlib_base64':base64.b64encode(zlib.compress(raw,9)).decode()}
   out[name]={'buffer_sha256':key}
  return out
 result=[]
 for row in rows:
  out={'name':row['name'],'operation':row['operation'],'args':row['args'],'context_before':packed(row['context_before']),'observations':copy.deepcopy(row['expected']['observations']),'expected':{k:copy.deepcopy(v)for k,v in row['expected'].items()if k!='observations'}}
  out['expected']['context_after']=packed(out['expected']['context_after'])
  if 'source_resource'in row:out['source_resource']=copy.deepcopy(row['source_resource'])
  for observation in out['observations']:
   observation['before']=packed(observation['before']);observation['after']=packed(observation['after'])
  result.append(out)
 return pool,result

def resource_cases():
 doc=json.loads((PROJECT/'data/ffe_mission_programs.json').read_text());raw=bytes.fromhex(doc['regions']['mission']['hex']);rows=[]
 unary={7,8,9,31,34,35,47,48,52,54,55};binary={10,*range(13,28)}
 def parse(at,module,depth=0):
  if depth>64 or at>=len(raw):raise ValueError('bounded parse')
  token=raw[at];at+=1
  if token in[2,3,4,5,6]:
   if at+4>len(raw):raise ValueError('truncated')
   value=struct.unpack_from('<I',raw,at)[0];at+=4
   if token==3 and value>20:raise ValueError('global selector')
   if token==4 and value>=71:raise ValueError('register')
   if token==5 and(module['global_owner_offset_u32']==0xffffffff or value>=module['global_words_u32']):raise ValueError('module global')
   if token==6 and value>=module['variable_words_u32']:raise ValueError('local variable')
   return at
  count=1 if token in unary else 2 if token in binary else 3 if token==59 else 0
  if not count:raise ValueError('unsupported static subset')
  for _ in range(count):at=parse(at,module,depth+1)
  return at
 for module in doc['modules']:
  found=None
  for block in module['block_offsets_u32']:
   for index,entry in enumerate(doc['blocks'][str(block)]['clause_offsets_u32']):
    try:end=parse(entry,module)
    except ValueError:continue
    found=(block,index,entry,end);break
   if found:break
  if not found:continue
  block,index,entry,end=found;ctx=base_context(raw);ctx['ip_u32']=entry;ctx['module_global_offset_u32']=module['global_owner_offset_u32'];ctx['module_globals']=doc['module_globals_initialization']['initial_hex'];ctx['task_variables']=bytes(max(8,module['variable_words_u32']*4)).hex()
  rows.append({'name':'DOS-module-%03d-block-%d-clause-%d'%(module['module_index_u32'],block,index),'operation':'F31','args':[],'context_before':ctx,'scripts':[],'policy':{},'source_resource':{'module_index_u32':module['module_index_u32'],'block_offset_u32':block,'clause_index_u32':index,'expression_entry_offset_u32':entry,'syntax_end_offset_u32':end,'actual_DOS_program_bytes':True,'static_admission_only_not_an_arithmetic_oracle':True}})
  if len(rows)>=24:break
 if len(rows)!=24:raise ValueError('Insufficient original expression corpus')
 return rows

def fault_cases(binary):
 rows=[]
 for name,program in [('signed-division-zero',expression(11,1,0)),('signed-modulo-zero',expression(12,1,0)),('signed-division-overflow',expression(11,0x80000000,0xffffffff)),('signed-modulo-overflow',expression(12,0x80000000,0xffffffff)),('unsigned-random-modulo-zero',expression(50,0))]:
  row={'name':name,'operation':'F31','args':[],'context_before':base_context(program),'scripts':[],'policy':{}};witnesses=[]
  for _ in range(MAX_OBS+1):
   done=subprocess.run([str(binary)],input=packet(row),capture_output=True,timeout=30)
   if done.returncode==-8:break
   if done.returncode:raise ValueError(('Unexpected native fault domain',name,done.returncode))
   h=struct.unpack_from('<16I',done.stdout)
   if h[2]!=1:raise ValueError('Expected original divide fault')
   at=64+OWNER+MAX_TRACE*4+len(row['scripts'])*(64+2*OWNER+4096);kind,argc=struct.unpack_from('<2I',done.stdout,at);args=list(struct.unpack_from('<6I',done.stdout,at+8))[:argc];script=default_script(kind,args,row);row['scripts'].append(script);before=context(done.stdout[at+64:at+64+OWNER],row)
   witnesses.append({'kind':'F%d'%kind,'args':args,'before':before,'after':copy.deepcopy(before),'return_u32':script['return_u32'],'input_hex':'','output_hex':script['output_hex']})
  else:raise ValueError('Fault boundary capacity exceeded')
  rows.append({'name':name,'operation':'F31','args':[],'context_before':row['context_before'],'observations':witnesses,'actual_native_process_returncode':-8,'actual_native_signal':'SIGFPE','expected_complete_native_context_after_available':False,'scope':'Original x86 divide-error domain; portable runtime rejects instead of inventing a result.'})
 return rows

def generate(meta,source,a):
 rows=cases()+resource_cases();native_text=''
 with tempfile.TemporaryDirectory(prefix='mission-expression-native-')as directory:
  binary,native_text=build(meta,source,directory)
  for index,row in enumerate(rows):
   try:raw=fill_scripts(binary,row)
   except Exception as exc:raise ValueError('Native case failed '+row['name'])from exc
   row['expected']=decoded_output(raw,row)
  faults=fault_cases(binary)
  # True repeated whole-process streams also check hidden native state reuse.
  payload=b''.join(packet(row)for row in rows);reference=b''.join(run(binary,row)for row in rows)
  for _ in range(3):
   observed=subprocess.run([str(binary)],input=payload,capture_output=True,check=True,timeout=120)
   if observed.stderr or observed.stdout!=reference:raise ValueError('Fresh native cohort differs')
  reverse=subprocess.run([str(binary)],input=b''.join(packet(row)for row in reversed(rows)),capture_output=True,check=True,timeout=120).stdout
  wanted=b''.join(run(binary,row)for row in reversed(rows))
  if reverse!=wanted:raise ValueError('Reverse native cohort differs')
 pool,output_rows=pool_rows(rows)
 for fault in faults:
  # Transport compression only; no arithmetic expectation is synthesized.
  for ctx in [fault['context_before'],*[side for observation in fault['observations']for side in [observation['before'],observation['after']]]]:
   for name in CONTEXT_KEYS[:7]:
    raw=bytes.fromhex(ctx[name]);key=sha(raw)
    pool.setdefault(key,{'byte_count':len(raw),'zlib_base64':base64.b64encode(zlib.compress(raw,9)).decode()});ctx[name]={'buffer_sha256':key}

 dependencies=['data/ffe_mission_programs.json','tools/rebuild_source_natural_contact_native.py','tools/rebuild_source_surface_contact_native.py','tools/rebuild_source_atmospheric_native.py','tools/rebuild_source_jet_fuel_native.py','tools/rebuild_ground_surface_native.py','recovered-history/ground_harness/tools/build_terrain_query_reference.py','recovered-history/ground_harness/tools/native_reference.py','validation/damage-core-2026-11-17/native-proof/instruction-proof.json']
 doc={'schema':'starfrontier-source-mission-expression-native-v1','profile':PROFILE,'source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'case_count':len(rows),'whole_procedure_count':17,'instruction_proof_sha256':sha((a.proof_dir/'instruction-proof.json').read_bytes()),'source_procedures_sha256':sha(source.encode()),'native_assembly_sha256':sha(native_text.encode()),'native_support_sha256':sha(C.encode()),'whole_instruction_count':meta['whole_instruction_count'],'source_table_variants':meta['source_table_variants'],'undefined_selector_slots_rejected':UNDEFINED,'fresh_cohort_runs':3,'reverse_repeat_cases':len(rows),'expected_arithmetic_calculated_in_python':False,'source_dependencies_sha256':{n:sha((PROJECT/n).read_bytes())for n in dependencies},'buffer_pool':pool,'cases':output_rows,'actual_DOS_resource_clause_case_count':sum('source_resource'in row for row in rows),'fault_case_count_separate':len(faults),'original_fault_domains':faults,'Main_integrated':False,'full_mission_VM_executed':False,'scope':'Whole original expression/get/set/list/bank/RNG instruction kernels with actual DOS inline tables. Explicit world/output providers remain unresolved; undefined source results, invalid pointers, division faults and malformed programs are bounded rejections rather than invented arithmetic.'}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(doc,indent=2)+'\n');(a.proof_dir/'expression-native.s').write_text(native_text);(a.proof_dir/'expression-support.c').write_text(C)
 return doc

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--reprove-original',action='store_true');a=p.parse_args()
 meta,source=reprove(a)if a.reprove_original else verify(a.proof_dir)
 doc=generate(meta,source,a)
 print(json.dumps({'proof':'verified','procedures':meta['whole_procedure_count'],'instructions':meta['whole_instruction_count'],'case_count':doc['case_count'],'sha256':sha(a.output.read_bytes())},indent=2))
