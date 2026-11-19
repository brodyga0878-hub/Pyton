#!/usr/bin/env python3
"""Whole original F37 lvalue procedure with actual selector bytes and jump targets.

Native instructions supply outputs. Typed dependent game procedures remain
explicit continuations; this offline ELF64 bridge is not an Android emulator.
"""
from __future__ import annotations
import argparse,base64,copy,hashlib,json,re,struct,subprocess,tempfile,zlib
from pathlib import Path
import rebuild_source_mission_expression_native as E
N=E.N;PROJECT=N.PROJECT
PROOF=PROJECT/'validation/mission-tasks-2026-11-19/store-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_mission_store_native.json'
NUMBERS=[20,37,1532]
PROFILE='dos-firstenc-mission-store-v1'
ROOT=16384;TAIL=6160;BANK=38986;REGS=284;GLOBALS=40;VARS=1024;PROGRAM=65536;MARKET=308
CONTEXT_KEYS=E.CONTEXT_KEYS+['task_slot_u32','descriptor_ref_u32','market_buffer']
SIZES=E.SIZES+[4,4,MARKET]
OFFSETS=[];at=0
for count in SIZES:OFFSETS.append(at);at+=count
OWNER=at
MAX_OBS=64;MAX_TRACE=1024
BASE=64+OWNER+MAX_TRACE*4
RECORD=64+OWNER*2
sha=E.sha
s32=E.s32
normalized=E.normalized
positions=E.positions
source_labels=E.source_labels

def chunks(body,aliases,n):
 result=[];tables=[]
 for piece in re.split(r'(SECTION \.data.*?SECTION \.text)',body,flags=re.S):
  if piece.startswith('SECTION .data'):
   labels=list(re.finditer(r'^(DATA_\d+):.*$',piece,re.M))
   for i,label in enumerate(labels):
    part=piece[label.end():labels[i+1].start()if i+1<len(labels)else len(piece)]
    targets=re.findall(r'^\s*dd\s+(JUMP_\d+)',part,re.M)
    if targets:tables.append((label[1],targets))
   continue
  if not piece.strip():continue
  m=re.search(r'((?:FUNC|JUMP)_\d+):\s*;\s*Pos = ([0-9a-f]+)',piece)
  if not m:raise ValueError('Missing original code anchor')
  clean=re.sub(r'^\s*(?:FUNC|JUMP)_\d+:.*$','',piece,flags=re.M)
  clean=re.sub(r'push dword (FUNC_\d+)',r'push OFFSET FLAT:\1',clean)
  result.append((aliases[m[1]],'proof_entry:\n'+clean))
 return result,tables

def reprove(a):
 exe=a.exe.read_bytes();source=a.asm.read_text()
 if sha(exe)!=N.EXE_SHA or sha(a.asm.read_bytes())!=N.ASM_SHA:raise ValueError('Original identity differs')
 bodies={n:N.G.block(source,n)for n in NUMBERS}
 original_later_body=bodies[37]
 later_gate='''		mov edi,eax
		mov eax,[edi+0x82]
		push eax
		call near [DATA_007756]    ; FUNC_001538
		pop ecx
		cmp dword [eax+0x38],byte +0x0
		jz near JUMP_000353
		mov al,[ebp+0x10]
		mov [edi+0xff],al'''
 original_store='''		mov dl,[ebp+0x10]
		mov [eax+0xff],dl'''
 if bodies[37].count(later_gate)!=1:raise ValueError('Expected later-only F37 physical gate changed')
 bodies[37]=bodies[37].replace(later_gate,original_store)
 for old,new in [('Pos = 12a4a','Pos = 12a30'),('Pos = 12a74','Pos = 12a5a'),('Pos = 12ac4','Pos = 12aaa')]:bodies[37]=bodies[37].replace(old,new)
 pos=positions(source);pos.update(positions(bodies[37]));aliases=dict(pos)
 syms=set(re.findall(r'\bDATA_\d+','\n'.join(bodies.values())))
 fake={n:0x71000000+i*0x10000 for i,n in enumerate(sorted(syms))if n not in aliases};aliases.update(fake)
 previous=json.loads((PROJECT/'validation/damage-core-2026-11-17/native-proof/instruction-proof.json').read_text())
 # The original callback table, not later source Pos labels, anchors these helpers.
 aliases['FUNC_001532']=json.loads((PROJECT/'validation/mission-expressions-2026-11-18/expression-native-proof/instruction-proof.json').read_text())['procedures']['1532']['virtual_address']
 image=N.G.Image(exe)
 events=json.loads((PROJECT/'validation/events-messages-2026-11-18/events-native-proof/instruction-proof.json').read_text())
 anchor52=events['source_symbol_addresses']['FUNC_000052']
 calls=[row for row in N.C.original_rows(a.exe,anchor52,count=50)if row[1]=='call']
 aliases['FUNC_000037']=int(re.search(r'(?:0x)?([0-9a-f]{6,})',calls[2][2])[1],16)
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
    if len(actual_calls)!=len(source_calls):raise ValueError(('Call sequence differs',n,hex(start),len(compiled),source_calls,actual_calls))
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
 selector_source=re.search(r'DATA_000003:.*?\n(.*?)DATA_000004:',bodies[37],re.S)[1]
 selector_values=bytes(int(v,0)for line in selector_source.splitlines()if re.match(r'\s*db\s',line)for v in line.split('db',1)[1].split(','))
 selector_at=image.offset(aliases['DATA_000003'],67);selector_actual=exe[selector_at:selector_at+67]
 if len(selector_values)!=67 or selector_actual!=selector_values:raise ValueError('Original F37 byte-selector table differs')
 selector={'symbol':'DATA_000003','virtual_address':aliases['DATA_000003'],'executable_offset':selector_at,'entry_count':67,'hex':selector_actual.hex(),'sha256':sha(selector_actual),'all_bytes_equal':True}
 captured='\n'.join(bodies[n]for n in NUMBERS)+'\nFUNC_999999:\nret\n'
 used=set(re.findall(r'\b(?:DATA|FUNC|JUMP)_\d+','\n'.join(bodies.values())))
 bindings={k:aliases[k]for k in sorted(used)if k in aliases}
 root=0x64213c;root_fields={k:aliases[k]-root for k in sorted(syms)if 0<=aliases[k]-root<0x5810}
 expected={'DATA_009093':0x50e0,'DATA_009095':0x50f8,'DATA_009133':0x580c,'DATA_008861':0xc8,'DATA_008896':0x134,'DATA_008908':0x184}
 if root!=0x64213c or any(root_fields.get(k)!=v for k,v in expected.items()):raise ValueError('Actual DOS owner bindings differ')
 meta={'schema':'starfrontier-original-mission-store-proof-v1','source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'source_procedures_sha256':sha(captured.encode()),'bindings':bindings,'selector_table':selector,'source_code_variants':[{'procedure_u32':37,'selector_u32':62,'DOS_store_original_va_u32':0x412a18,'JJFFE_only_physical_spec_gate':True,'actual_DOS_unconditional_FF_store':True,'JJFFE_source_sha256':sha(original_later_body.encode()),'original_capture_sha256':sha(bodies[37].encode())}],'procedures':records,'whole_procedure_count':len(NUMBERS),'whole_instruction_count':sum(r['instruction_count']for r in records.values()),'all_code_regions_equal':True,'all_source_label_instruction_boundaries_equal':True,'all_inline_table_bytes_and_targets_equal':True,'source_table_variants':variants,'unmodified_JJFFE_tables_all_equal':False,'table_target_order_same_as_JJFFE':not bool(variants),'root_original_va_u32':root,'root_fields':root_fields,'event_registers_original_va_u32':0x60be08,'module_globals_original_va_u32':0x60bde0,'temporary_original_va_u32':0x60bf4c,'source_diagnostics':'F37 caller bodies execute; F31/F22/F34/F36/F48 and world operations remain exact typed continuations. Void EAX is ignored.'}
 a.proof_dir.mkdir(parents=True,exist_ok=True);(a.proof_dir/'source-procedures.asm').write_text(captured);(a.proof_dir/'instruction-proof.json').write_text(json.dumps(meta,indent=2)+'\n');(a.proof_dir/'dos-disassembly.txt').write_text('\n'.join(disassembly)+'\n');(a.proof_dir/'store-native.s').write_text(assembly(captured,meta));(a.proof_dir/'store-support.c').write_text(C)
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
 selector=meta['selector_table'];raw=bytes.fromhex(selector['hex'])
 actual=re.search(r'DATA_000003:.*?\n(.*?)DATA_000004:',source,re.S)[1]
 values=bytes(int(v,0)for line in actual.splitlines()if re.match(r'\s*db\s',line)for v in line.split('db',1)[1].split(','))
 if raw!=values or len(raw)!=67 or sha(raw)!=selector['sha256']:raise ValueError('Archived selector-byte proof differs')
 return meta,source


def trace(n):
 return 'pushfq\npush rax\npush rcx\nmov ecx,DWORD PTR [s_trace_count]\ncmp ecx,1024\njae s_abort\nmov DWORD PTR [s_trace+rcx*4],%d\ninc DWORD PTR [s_trace_count]\npop rcx\npop rax\npopfq\n'%n

def assembly(source,meta):
 selected=source.replace('SECTION .data','.section .rodata').replace('SECTION .text','.section .text')
 selected=re.sub(r'^\s*db\s+',r'.storebytes ',selected,flags=re.M)
 selected=re.sub(r'^\s*dd\s+',r'.long ',selected,flags=re.M)
 lines,_=N.Q.procedures(selected,NUMBERS);text='\n'.join(lines).replace('.storebytes ','.byte ')
 text=re.sub(r'\[rbp[^\]]*\]',lambda m:re.sub(r'\b(eax|ebx|ecx|edx|esi|edi)\b',lambda r:'r'+r[1][1:],m[0]),text)
 text=re.sub(r'jmp \[(e\w+)\*4\+(DATA_\d+)\]',lambda m:'mov r11d,DWORD PTR [r'+m[1][1:]+'*4+'+m[2]+']\njmp r11',text)
 text=re.sub(r'call QWORD PTR \[(DATA_\d+)\]',r'mov r11d,DWORD PTR [\1]\ncall r11',text)
 for n in NUMBERS:text=text.replace('FUNC_%06d:\n'%n,'FUNC_%06d:\n'%n+trace(n),1)
 providers=[(22,2),(31,2),(34,2),(36,2),(48,3),(390,2),(391,2),(392,2),(441,3),(649,1)]
 boundaries=[]
 for n,argc in providers:
  loads=['mov esi,DWORD PTR [rbp+16]','mov edx,DWORD PTR [rbp+24]'if argc>1 else'xor edx,edx','mov ecx,DWORD PTR [rbp+32]'if argc>2 else'xor ecx,ecx']
  boundaries.append('FUNC_%06d:\n'%n+trace(n)+'''push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
'''+ '\n'.join(loads)+f'''
mov edi,{n}
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
''')
 aliases=['%s=s_root+%d'%(key,off)for key,off in meta['root_fields'].items()]
 return '.intel_syntax noprefix\n.code64\n.section .text\n'+text+'\n.section .text\n'+'''
.global call_kernel
call_kernel:
mov [s_saved_rsp],rsp
mov esp,OFFSET FLAT:s_stack_end
push rdi
push OFFSET FLAT:s_task
push OFFSET FLAT:s_ip
call FUNC_000037
xor eax,eax
mov rsp,[s_saved_rsp]
ret
s_abort:
mov edi,97
mov eax,60
syscall
'''+ '\n'.join(boundaries)+'\n.section .data\nDATA_007754:.long FUNC_001532\n'+ '\n'.join(aliases)+'''
.section .bss
.balign 16
s_stack:.zero 2097152
s_stack_end:
s_saved_rsp:.zero 8
.section .note.GNU-stack,"",@progbits
'''

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
#define MARKET 308
#define OWNER (ROOT+TAIL+BANK+REGS+GLOBALS+VARS+PROGRAM+12+8+MARKET)
#define BASE (64+OWNER+1024*4)
#define RECORD (64+OWNER*2)
#define MAX 64
struct __attribute__((packed)) Patch{uint32_t owner,offset,size,pad;uint8_t data[64];};
struct __attribute__((packed)) Script{uint32_t kind,argc,args[6],result,patches,pad[6];struct Patch patch[12];};
struct __attribute__((packed)) Input{uint32_t h[16];uint8_t owner[OWNER];struct Script scripts[MAX];};
struct GuardRoot{uint8_t left[64],data[ROOT+TAIL],right[64];} g_root;
struct GuardBank{uint8_t left[64],data[BANK],right[64];} g_bank;
struct GuardRegs{uint8_t left[64],data[REGS],right[64];} g_events;
struct GuardGlobals{uint8_t left[64],data[GLOBALS],right[64];} g_globals;
struct GuardVars{uint8_t left[64],data[VARS],right[64];} g_vars;
struct GuardProgram{uint8_t left[64],data[PROGRAM],right[64];} g_program;
struct GuardMarket{uint8_t left[64],data[MARKET],right[64];} g_market;
asm(".global s_root,s_bank,s_events,s_globals,s_vars,s_program,s_market\ns_root=g_root+64\ns_bank=g_bank+64\ns_events=g_events+64\ns_globals=g_globals+64\ns_vars=g_vars+64\ns_program=g_program+64\ns_market=g_market+64");
#define s_root g_root.data
#define s_bank g_bank.data
#define s_events g_events.data
#define s_globals g_globals.data
#define s_vars g_vars.data
#define s_program g_program.data
#define s_market g_market.data
uint8_t s_task[36],s_descriptor[32];uint32_t s_ip,s_global_base,s_slot,s_descriptor_ref;int32_t s_temporary;uint32_t s_trace[1024],s_trace_count;
extern uint32_t call_kernel(uint32_t);
static struct Input input;static uint8_t output[BASE+MAX*RECORD],logical[OWNER];static uint32_t used,status;static jmp_buf jump;
static const uint32_t sizes[13]={ROOT,TAIL,BANK,REGS,GLOBALS,VARS,PROGRAM,4,4,4,4,4,MARKET};
static const uint32_t offsets[13]={0,ROOT,ROOT+TAIL,ROOT+TAIL+BANK,ROOT+TAIL+BANK+REGS,ROOT+TAIL+BANK+REGS+GLOBALS,ROOT+TAIL+BANK+REGS+GLOBALS+VARS,OWNER-12-8-MARKET,OWNER-8-8-MARKET,OWNER-4-8-MARKET,OWNER-8-MARKET,OWNER-4-MARKET,OWNER-MARKET};
static uint32_t get(const void*p){uint32_t n;memcpy(&n,p,4);return n;}static void put(void*p,uint32_t n){memcpy(p,&n,4);}
static uint32_t body_to_host(uint32_t n){if(!n)return 0;if(n<116||(n-116)%338||(n-116)/338>114)exit(90);return(uint32_t)(uintptr_t)(s_bank+n);}
static uint32_t body_to_logical(uint32_t n){if(!n)return 0;uintptr_t b=(uintptr_t)s_bank;if(n<b+116||n>b+116+114*338||(n-b-116)%338)exit(91);return n-(uint32_t)b;}
static uint32_t body_slot(uint32_t n){uint32_t off=body_to_logical(n);if(off<116)exit(92);return(off-116)/338;}
static void capture(uint8_t*p){memcpy(p,s_root,ROOT+TAIL);put(p+0xc8,body_to_logical(get(s_root+0xc8)));put(p+0xcc,body_to_logical(get(s_root+0xcc)));if(get(s_root+0x580c)!=(uint32_t)(uintptr_t)s_bank)exit(93);put(p+0x580c,1);memcpy(p+offsets[2],s_bank,BANK);memcpy(p+offsets[3],s_events,REGS);memcpy(p+offsets[4],s_globals,GLOBALS);memcpy(p+offsets[5],s_vars,VARS);memcpy(p+offsets[6],s_program,PROGRAM);put(p+offsets[7],s_ip-(uint32_t)(uintptr_t)s_program);put(p+offsets[8],s_global_base);put(p+offsets[9],(uint32_t)s_temporary);put(p+offsets[10],s_slot);put(p+offsets[11],s_descriptor_ref);memcpy(p+offsets[12],s_market,MARKET);}
static void load(const uint8_t*p){memcpy(s_root,p,ROOT+TAIL);put(s_root+0xc8,body_to_host(get(p+0xc8)));put(s_root+0xcc,body_to_host(get(p+0xcc)));if(get(p+0x580c)!=1)exit(94);put(s_root+0x580c,(uint32_t)(uintptr_t)s_bank);memcpy(s_bank,p+offsets[2],BANK);memcpy(s_events,p+offsets[3],REGS);memcpy(s_globals,p+offsets[4],GLOBALS);memcpy(s_vars,p+offsets[5],VARS);memcpy(s_program,p+offsets[6],PROGRAM);s_ip=(uint32_t)(uintptr_t)s_program+get(p+offsets[7]);s_global_base=get(p+offsets[8]);s_temporary=(int32_t)get(p+offsets[9]);s_slot=get(p+offsets[10]);s_descriptor_ref=get(p+offsets[11]);memcpy(s_market,p+offsets[12],MARKET);memset(s_task,0xa5,36);memset(s_descriptor,0xa5,32);put(s_descriptor+0x14,s_global_base==0xffffffff?0:(uint32_t)(uintptr_t)(s_globals+s_global_base));put(s_task+0x1c,(uint32_t)(uintptr_t)s_descriptor);put(s_task+0x20,(uint32_t)(uintptr_t)s_vars);}
static void setguards(void){memset(g_root.left,0x6d,64);memset(g_root.right,0x7b,64);memset(g_bank.left,0x6d,64);memset(g_bank.right,0x7b,64);memset(g_events.left,0x6d,64);memset(g_events.right,0x7b,64);memset(g_globals.left,0x6d,64);memset(g_globals.right,0x7b,64);memset(g_vars.left,0x6d,64);memset(g_vars.right,0x7b,64);memset(g_program.left,0x6d,64);memset(g_program.right,0x7b,64);memset(g_market.left,0x6d,64);memset(g_market.right,0x7b,64);}
static void guards(void){uint8_t*left[]={g_root.left,g_bank.left,g_events.left,g_globals.left,g_vars.left,g_program.left,g_market.left};uint8_t*right[]={g_root.right,g_bank.right,g_events.right,g_globals.right,g_vars.right,g_program.right,g_market.right};for(int i=0;i<7;i++)for(int j=0;j<64;j++)if(left[i][j]!=0x6d||right[i][j]!=0x7b)exit(95);if(memcmp(s_program,input.owner+offsets[6],PROGRAM))exit(96);if(memcmp(s_vars+input.h[2],input.owner+offsets[5]+input.h[2],VARS-input.h[2]))exit(107);if(get(s_task+28)!=(uint32_t)(uintptr_t)s_descriptor||get(s_task+32)!=(uint32_t)(uintptr_t)s_vars||get(s_descriptor+20)!=(s_global_base==0xffffffff?0:(uint32_t)(uintptr_t)(s_globals+s_global_base)))exit(108);}
uint32_t s_observe(uint32_t kind,uint32_t a,uint32_t b,uint32_t c){uint32_t argc=kind==48||kind==441?3:kind==31||kind==649?1:2,args[6]={a,b,c,0,0,0};
 if(kind==31){if(a!=(uint32_t)(uintptr_t)&s_ip||b!=(uint32_t)(uintptr_t)s_task)exit(97);args[0]=s_slot;args[1]=0;}
 if(kind==36||kind==390||kind==391||kind==392||kind==441)args[0]=body_slot(a);
 if(kind==48&&a==3){if(b!=(uint32_t)(uintptr_t)s_descriptor)exit(98);args[1]=s_descriptor_ref;}
 if(kind==48&&a==4){if(b!=(uint32_t)(uintptr_t)s_task)exit(99);args[1]=0x60bf50+s_slot*36;}
 if(argc<3)args[2]=0;if(argc<2)args[1]=0;
 if(used>=MAX)exit(100);uint8_t*row=output+BASE+used*RECORD;put(row,kind);put(row+4,argc);memcpy(row+8,args,24);capture(row+64);
 if(used>=input.h[3]){status=1;capture(row+64+OWNER);used++;longjmp(jump,1);return 0;}
 struct Script*s=&input.scripts[used];if(s->kind!=kind||s->argc!=argc||memcmp(s->args,args,24))exit(101);
 capture(logical);for(uint32_t i=0;i<s->patches;i++){struct Patch*p=&s->patch[i];if(p->owner>=13||p->owner==6||p->owner==8||p->owner==10||p->owner==11||p->size>64||p->offset+p->size>sizes[p->owner])exit(102);if(p->owner==7&&kind!=31)exit(103);if(p->owner==5&&p->offset+p->size>input.h[2])exit(104);memcpy(logical+offsets[p->owner]+p->offset,p->data,p->size);}load(logical);
 if((kind==22||kind==34||kind==36||kind==48||kind==441)&&s->result)exit(105);if(kind==649&&s->result>1)exit(106);
 put(row+32,s->result);capture(row+64+OWNER);used++;return kind==649?(s->result?(uint32_t)(uintptr_t)s_market:0):s->result;
}
int main(void){while(fread(&input,1,sizeof input,stdin)==sizeof input){if(input.h[1]>PROGRAM||input.h[2]>VARS||input.h[3]>MAX)return 81;setguards();load(input.owner);memset(output,0,sizeof output);used=status=s_trace_count=0;if(setjmp(jump)==0)call_kernel(input.h[0]);guards();put(output,0x37f02056);put(output+4,BASE+used*RECORD);put(output+8,status);put(output+12,0);put(output+16,used);put(output+20,s_trace_count);capture(output+64);memcpy(output+64+OWNER,s_trace,s_trace_count*4);if(fwrite(output,1,BASE+used*RECORD,stdout)!=BASE+used*RECORD)return 82;}return 0;}
'''

def context_bytes(ctx):
 buffers=[bytes.fromhex(ctx[k])for k in CONTEXT_KEYS[:7]]
 buffers[5]=buffers[5].ljust(VARS,b'\xa5');buffers[6]=buffers[6].ljust(PROGRAM,b'\xa5')
 return b''.join(buffers)+struct.pack('<IIiII',ctx['ip_u32'],ctx['module_global_offset_u32'],ctx['temporary_event_index_s32'],ctx['task_slot_u32'],ctx['descriptor_ref_u32'])+bytes.fromhex(ctx['market_buffer'])
def context(raw,row):
 result={k:raw[o:o+n].hex()for k,o,n in zip(CONTEXT_KEYS[:7],OFFSETS,SIZES)}
 result['task_variables']=bytes.fromhex(result['task_variables'])[:len(bytes.fromhex(row['context_before']['task_variables']))].hex()
 result['program']=bytes.fromhex(result['program'])[:len(bytes.fromhex(row['context_before']['program']))].hex()
 result.update(zip(CONTEXT_KEYS[7:12],struct.unpack_from('<IIiII',raw,OFFSETS[7])))
 result['market_buffer']=raw[OFFSETS[12]:OFFSETS[12]+MARKET].hex();return result

def packet(row):
 scripts=row.get('scripts',[]);ctx=row['context_before'];out=struct.pack('<16I',row['value_u32'],len(bytes.fromhex(ctx['program'])),len(bytes.fromhex(ctx['task_variables'])),len(scripts),*([0]*12))+context_bytes(ctx)
 for script in scripts:
  args=[v&0xffffffff for v in script['args']];patches=script.get('patches',[])
  out+=struct.pack('<16I',script['kind'],len(args),*args,*([0]*(6-len(args))),script['return_u32'],len(patches),*([0]*6))
  for patch in patches:out+=struct.pack('<4I',patch['owner'],patch['offset'],len(bytes.fromhex(patch['hex'])),0)+bytes.fromhex(patch['hex']).ljust(64,b'\0')
  out+=bytes((12-len(patches))*80)
 return out+bytes((MAX_OBS-len(scripts))*1024)

def decoded_output(raw,row):
 h=struct.unpack_from('<16I',raw)
 if h[0]!=0x37f02056 or h[1]!=len(raw)or h[2]or h[4]!=len(row.get('scripts',[]))or len(raw)!=BASE+h[4]*RECORD:raise ValueError(('Native store output',row['name'],h[:7]))
 observations=[]
 for i in range(h[4]):
  at=BASE+i*RECORD;kind,argc=struct.unpack_from('<2I',raw,at);args=list(struct.unpack_from('<6I',raw,at+8))[:argc]
  observations.append({'kind':'F%d'%kind,'args':args,'before':context(raw[at+64:at+64+OWNER],row),'after':context(raw[at+64+OWNER:at+64+OWNER*2],row),'return_u32':struct.unpack_from('<I',raw,at+32)[0],'input_hex':'','output_hex':''})
 return {'context_after':context(raw[64:64+OWNER],row),'return_u32':0,'return_defined':False,'void_return_register_ignored':True,'source_order':['F%d'%n for n in struct.unpack_from('<%dI'%h[5],raw,64+OWNER)],'observations':observations}
def build(meta,source,folder):
 folder=Path(folder);native=assembly(source,meta);(folder/'native.s').write_text(native);(folder/'support.c').write_text(C);binary=folder/'native';done=subprocess.run(['gcc','-O1','-fno-pie','-no-pie','-fno-stack-protector','-o',str(binary),str(folder/'native.s'),str(folder/'support.c')],capture_output=True,text=True)
 if done.returncode:raise ValueError(done.stderr)
 return binary,native
def run(binary,row):return subprocess.run([str(binary)],input=packet(row),capture_output=True,check=True,timeout=30).stdout

def literal(v):return b'\x02'+struct.pack('<I',v&0xffffffff)
ACTIVE={3:'global',4:'register',5:'static',6:'local',31:'tail21',35:'tail10',36:'serial',37:'property',48:'root17',56:'body-a0',61:'model',62:'body-ff',65:'body-fe',66:'market'}
def authored_program(token,values=None,index=1):
 if token in[3,4,5,6]:return bytes([token])+struct.pack('<I',index&0xffffffff)
 return bytes([token])+b''.join(literal(v)for v in(values or[]))
def base_context(program):
 result=E.base_context(program);root=bytearray.fromhex(result['root'])
 struct.pack_into('<I',root,0x118,100);struct.pack_into('<I',root,0x120,40)
 for i in range(38):struct.pack_into('<H',root,0x134+i*2,2)
 result['root']=root.hex();result.update(task_slot_u32=17,descriptor_ref_u32=0x4801c4+22330,market_buffer=struct.pack('<77I',*(0x55660000+i for i in range(77))).hex())
 return result

def cases():
 rows=[]
 def add(name,token=0,value=0x12345678,values=None,index=1,policy=None):
  if values is None:values=[17,100]if token==37 else[23,1002]if token==66 else[2]if token in[31,35,48]else[17]if token in[36,56,61,62,65]else[]
  row={'name':name,'operation':'F37','value_u32':value&0xffffffff,'context_before':base_context(authored_program(token,values,index)),'scripts':[],'expression_values':list(values),'policy':policy or{}}
  rows.append(row);return row
 for token in range(256):add('all-byte-selectors-%03d'%token,token)
 for token in[3,4,5,6,31,35,48,56,62,65]:
  for value in[0,1,0x7fffffff,0x80000000,0xffffffff,0x12345678]:add('value-boundary-%d-%08x'%(token,value),token,value)
 for token,indices in [(3,[0,20,21,0xffffffff]),(4,[0,70]),(5,[0,1,9]),(6,[0,1,31])]:
  for index in indices:add('direct-index-%d-%08x'%(token,index),token,index=index)
 row=add('static-offset-last-word',5,index=1);row['context_before']['module_global_offset_u32']=32
 for token in[31,35,48]:
  for index in[0,5,6,0x7fffffff,0x80000000,0xffffffff]:add('signed-owner-index-%d-%08x'%(token,index),token,values=[index])
 for token in[36,56,61,62,65]:
  for slot in[0,1,9,17,64,114]:add('body-slot-%d-%d'%(token,slot),token,values=[slot])
 for model in[0,149,0xffffffff]:
  row=add('DOS-unconditional-FF-model-%08x'%model,62)
  bank=bytearray.fromhex(row['context_before']['bank']);struct.pack_into('<I',bank,116+17*338+0x82,model);row['context_before']['bank']=bank.hex()
 for prop in[99,100,137,999,1000,1037,1038,0x7fffffff,0x80000000,0xffffffff]:add('property-domain-%08x'%prop,37,value=7,values=[17,prop])
 for slot in[0,9,64,114]:add('other-body-cargo-%d'%slot,37,value=7,values=[slot,1000])
 for name,old,cap,used,target in[
  ('gain',2,100,40,15),('clamp-negative-delta',7,20,25,15),('negative-clear',7,20,25,0xffffffff),('drop',12,100,40,3),('unchanged',2,100,40,2),('zero-capacity',0,0,0,5),('unsigned-word-large',0xffff,100,25,1),('used-wrap',1,0x7fffffff,0x7fffffff,10),('signed-cap-min',3,0x80000000,0x7fffffff,15),('target-min',3,100,40,0x80000000),('target-max',3,0xffffffff,0xffffffff,0x7fffffff),('sum-signed-wrap',0,0x7fffffff,0x7ffffff0,32)]:
  row=add('cargo-'+name,37,value=target,values=[17,1000]);root=bytearray.fromhex(row['context_before']['root']);struct.pack_into('<H',root,0x134,old);struct.pack_into('<I',root,0x118,cap);struct.pack_into('<I',root,0x120,used);row['context_before']['root']=root.hex()
 add('equipment-gain-all-three',37,value=5,values=[17,100],policy={'F392':{'return_u32':2},'F390':{'return_u32':0}})
 add('equipment-remove-all-three',37,value=2,values=[17,100],policy={'F392':{'return_u32':5},'F391':{'return_u32':0}})
 add('equipment-first-gain-fails',37,value=5,values=[17,100],policy={'F392':{'return_u32':2},'F390':{'return_u32':1}})
 add('equipment-second-gain-fails',37,value=8,values=[17,100],policy={'F392':{'return_u32':2},'F390':{'returns':[0,1]}})
 add('equipment-first-remove-fails',37,value=2,values=[17,100],policy={'F392':{'return_u32':5},'F391':{'return_u32':1}})
 add('equipment-no-delta',37,value=2,values=[17,100],policy={'F392':{'return_u32':2}})
 for kind in[0,999,1000,1037,1038,0xffffffff]:add('market-index-%08x'%kind,66,values=[23,kind])
 add('market-null-return',66,values=[23,1000],policy={'F649':{'return_u32':0,'patches':[{'owner':0,'offset':0x124,'hex':'efbeadde'}]}})
 add('market-invalid-still-calls',66,values=[23,1038],policy={'F649':{'patches':[{'owner':12,'offset':0,'hex':'12345678'}]}})
 add('market-notify-reread',66,values=[23,1000],policy={'F48':{'patches':[{'owner':12,'offset':8,'hex':'11223344'}]}})
 add('serial-rereads-after-expression',36,policy={'F31':{'patches':[{'owner':2,'offset':116+17*338+0xa0,'hex':'12345678'}]}})
 add('cargo-player-changed-by-expression',37,value=8,values=[17,1000],policy={'F31':{'occurrence_patches':{1:[{'owner':0,'offset':0xc8,'hex':struct.pack('<I',116+9*338).hex()}]}}})
 add('cargo-capacity-reread',37,value=20,values=[17,1000],policy={'F31':{'occurrence_patches':{1:[{'owner':0,'offset':0x118,'hex':struct.pack('<I',41).hex()}]}}})
 for token in[5,6]:add('event-callback-mutates-local-%d'%token,token,value=0xdeadbeef,policy={'F48':{'patches':[{'owner':5,'offset':4,'hex':'12345678'},{'owner':4,'offset':0,'hex':'aabbccdd'},{'owner':1,'offset':0x10e0,'hex':'efbeadde'}]}})
 add('model-zero-caller',61,value=0)
 return rows

def default_script(kind,args,row):
 count=sum(s['kind']==kind for s in row['scripts']);ctx=row.get('_pending_context',row['context_before']);patches=[]
 result=0 if kind in[22,34,36,48,441]else 1 if kind in[390,391,649]else 2
 if kind==31:
  result=row['expression_values'][count]&0xffffffff
  patches=[{'owner':7,'offset':0,'hex':struct.pack('<I',ctx['ip_u32']+5).hex()}]
 policy=row.get('policy',{}).get('F%d'%kind,{})
 if 'returns'in policy:result=policy['returns'][min(count,len(policy['returns'])-1)]
 else:result=policy.get('return_u32',result)
 patches+=copy.deepcopy(policy.get('patches',[]));patches+=copy.deepcopy(policy.get('occurrence_patches',{}).get(count,[]))
 return {'kind':kind,'args':args,'return_u32':result&0xffffffff,'patches':patches}
def fill_scripts(binary,row):
 for _ in range(MAX_OBS+1):
  raw=run(binary,row);h=struct.unpack_from('<16I',raw)
  if h[2]==0:return raw
  if h[2]!=1 or h[4]!=len(row['scripts'])+1:raise ValueError(('Unexpected pending store',row['name'],h[:7]))
  at=BASE+len(row['scripts'])*RECORD;kind,argc=struct.unpack_from('<2I',raw,at);args=list(struct.unpack_from('<6I',raw,at+8))[:argc]
  row['_pending_context']=context(raw[at+64:at+64+OWNER],row);row['scripts'].append(default_script(kind,args,row))
 raise ValueError('Native store callback profile exceeded')

def resource_cases():
 doc=json.loads((PROJECT/'data/ffe_mission_programs.json').read_text());raw=bytes.fromhex(doc['regions']['mission']['hex']);rows=[]
 for module in doc['modules']:
  if not module['argument_count_u32']:continue
  at=module['argument_targets_offset_u32'];token=raw[at];index=struct.unpack_from('<I',raw,at+1)[0]
  if token!=6 or index>=module['variable_words_u32']:raise ValueError('Actual module first argument lvalue profile changed')
  ctx=base_context(raw);ctx['ip_u32']=at;ctx['task_variables']=bytes(module['variable_words_u32']*4).hex();ctx['module_global_offset_u32']=module['global_owner_offset_u32'];ctx['descriptor_ref_u32']=doc['regions']['mission']['original_va_u32']+module['descriptor_offset_u32'];ctx['module_globals']=doc['module_globals_initialization']['initial_hex']
  rows.append({'name':'actual-DOS-module-%03d-first-argument-target'%module['module_index_u32'],'operation':'F37','value_u32':0x31410000+module['module_index_u32'],'context_before':ctx,'scripts':[],'expression_values':[],'policy':{},'source_resource':{'module_index_u32':module['module_index_u32'],'lvalue_entry_offset_u32':at,'actual_DOS_program_bytes':True}})
 return rows

def dependent_rows(binary):
 values=[0x11,0x22,0x33,0x44,0x55]
 code=authored_program(5,index=0)+authored_program(6,index=1)+authored_program(31,[2])+authored_program(56,[17])+authored_program(66,[23,1002])
 current=base_context(code);rows=[]
 for i,(token,value,expr)in enumerate(zip([5,6,31,56,66],values,[[],[],[2],[17],[23,1002]])):
  row={'name':'shared-store-transition-%02d'%i,'operation':'F37','value_u32':value,'context_before':copy.deepcopy(current),'scripts':[],'expression_values':expr,'policy':{},'shared_owner_sequence':'same-program-five-stores','shared_step_u32':i}
  raw=fill_scripts(binary,row);row['expected']=decoded_output(raw,row);current=copy.deepcopy(row['expected']['context_after']);rows.append(row)
 return rows

def pool_rows(rows):
 pool={};buffers=CONTEXT_KEYS[:7]+['market_buffer']
 def packed(ctx):
  out=copy.deepcopy(ctx)
  for name in buffers:
   raw=bytes.fromhex(out[name]);key=sha(raw)
   pool.setdefault(key,{'byte_count':len(raw),'zlib_base64':base64.b64encode(zlib.compress(raw,9)).decode()});out[name]={'buffer_sha256':key}
  return out
 out=[]
 for row in rows:
  item={key:copy.deepcopy(row[key])for key in ['name','operation','value_u32']};item['context_before']=packed(row['context_before']);item['observations']=copy.deepcopy(row['expected']['observations']);item['expected']={k:copy.deepcopy(v)for k,v in row['expected'].items()if k!='observations'};item['expected']['context_after']=packed(item['expected']['context_after'])
  for observation in item['observations']:
   observation['before']=packed(observation['before']);observation['after']=packed(observation['after'])
  for field in ['source_resource','shared_owner_sequence','shared_step_u32']:
   if field in row:item[field]=copy.deepcopy(row[field])
  out.append(item)
 return pool,out

def fault_cases(binary):
 row={'name':'null-static-global-pointer','operation':'F37','value_u32':0x31415926,'context_before':base_context(authored_program(5,index=0)),'scripts':[],'expression_values':[],'policy':{}}
 row['context_before']['module_global_offset_u32']=0xffffffff
 for _ in range(3):
  done=subprocess.run([str(binary)],input=packet(row),capture_output=True,timeout=30)
  if done.returncode!=-11:raise ValueError(('Expected original null static pointer SIGSEGV',done.returncode))
 return [{'name':row['name'],'operation':'F37','value_u32':row['value_u32'],'context_before':row['context_before'],'observations':[],'actual_native_process_returncode':-11,'actual_native_signal':'SIGSEGV','fresh_native_process_runs':3,'expected_complete_native_context_after_available':False,'scope':'Original descriptor-global NULL write fault; portable profile rejects, no after-state invented.'}]

def generate(meta,source,a):
 rows=cases()+resource_cases()
 with tempfile.TemporaryDirectory(prefix='mission-store-native-')as directory:
  binary,native=build(meta,source,directory)
  for row in rows:
   try:raw=fill_scripts(binary,row);row['expected']=decoded_output(raw,row)
   except Exception as exc:raise ValueError('Native F37 case '+row['name'])from exc
  rows+=dependent_rows(binary)
  faults=fault_cases(binary)
  reference=b''.join(run(binary,row)for row in rows);payload=b''.join(packet(row)for row in rows)
  for _ in range(3):
   done=subprocess.run([str(binary)],input=payload,capture_output=True,check=True,timeout=180)
   if done.stderr or done.stdout!=reference:raise ValueError('Fresh native store cohort differs')
  reverse=subprocess.run([str(binary)],input=b''.join(packet(row)for row in reversed(rows)),capture_output=True,check=True,timeout=180).stdout
  if reverse!=b''.join(run(binary,row)for row in reversed(rows)):raise ValueError('Reversed native store cohort differs')
 pool,output_rows=pool_rows(rows)
 for fault in faults:
  for name in CONTEXT_KEYS[:7]+['market_buffer']:
   raw=bytes.fromhex(fault['context_before'][name]);key=sha(raw);pool.setdefault(key,{'byte_count':len(raw),'zlib_base64':base64.b64encode(zlib.compress(raw,9)).decode()});fault['context_before'][name]={'buffer_sha256':key}
 dependencies=['data/ffe_mission_programs.json','tools/rebuild_source_mission_expression_native.py','validation/mission-expressions-2026-11-18/expression-native-proof/instruction-proof.json','tools/rebuild_source_natural_contact_native.py','tools/rebuild_source_surface_contact_native.py','tools/rebuild_source_atmospheric_native.py','tools/rebuild_source_jet_fuel_native.py','tools/rebuild_ground_surface_native.py','recovered-history/ground_harness/tools/build_terrain_query_reference.py','recovered-history/ground_harness/tools/native_reference.py','validation/events-messages-2026-11-18/events-native-proof/instruction-proof.json']
 doc={'schema':'starfrontier-source-mission-store-native-v1','profile':PROFILE,'source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'case_count':len(rows),'whole_procedure_count':len(NUMBERS),'whole_instruction_count':meta['whole_instruction_count'],'instruction_proof_sha256':sha((a.proof_dir/'instruction-proof.json').read_bytes()),'source_procedures_sha256':sha(source.encode()),'native_assembly_sha256':sha(native.encode()),'native_support_sha256':sha(C.encode()),'source_code_variants':meta['source_code_variants'],'selector_table_u8':list(bytes.fromhex(meta['selector_table']['hex'])),'jump_target_symbols':meta['procedures']['37']['inline_tables'][0]['target_symbols'],'all_256_byte_selectors_tested':True,'fresh_cohort_runs':3,'reverse_repeat_cases':len(rows),'expected_arithmetic_calculated_in_python':False,'actual_DOS_resource_assignment_cases':sum('source_resource'in row for row in rows),'dependent_native_transition_count':5,'shared_continuation_edges':4,'source_dependencies_sha256':{n:sha((PROJECT/n).read_bytes())for n in dependencies},'fault_case_count_separate':len(faults),'original_fault_domains':faults,'buffer_pool':pool,'cases':output_rows,'Main_integrated':False,'full_mission_VM_executed':False,'scope':'Whole original F37 caller with actual byte selector and jump tables, original unconditional FF write and actual F20/F1532 helpers. Typed expression/global/register/model/equipment/market continuations are not complete world or F41 bodies. Persisted market buffer is an explicit single-market witness per invocation.'}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(doc,indent=2)+'\n');a.proof_dir.mkdir(parents=True,exist_ok=True);(a.proof_dir/'store-native.s').write_text(native);(a.proof_dir/'store-support.c').write_text(C)
 return doc

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--reprove-original',action='store_true');a=p.parse_args()
 meta,source=reprove(a)if a.reprove_original else verify(a.proof_dir)
 doc=generate(meta,source,a)
 print(json.dumps({'proof':'verified','procedures':meta['whole_procedure_count'],'instructions':meta['whole_instruction_count'],'case_count':doc['case_count'],'sha256':sha(a.output.read_bytes())},indent=2))
