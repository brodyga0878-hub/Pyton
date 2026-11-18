#!/usr/bin/env python3
"""Independent whole DOS event tree, snapshot dispatch and task scheduler oracle.

Only declared VM callbacks are external. Logical heap identities never contain
host addresses. Expected tree, arena and dispatch state comes from original code.
"""
from __future__ import annotations
import argparse,base64,copy,hashlib,inspect,json,random,re,struct,subprocess,tempfile,zlib
from pathlib import Path
import rebuild_source_damage_native as H
N=H.N;PROJECT=N.PROJECT
PROOF=PROJECT/'validation/events-messages-2026-11-18/events-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_events_native.json'
NUMBERS=[42,43,44,45,46,48,49,50,51,54,55,56]
OPERATIONS=['F42','F43','F44','F45','F46','F48','F50','F51','F54','F55','F56']
PROFILE='dos-firstenc-events-tree-v1'
KIND_IDS={'event_callback':48000,'F53':53,'F41':41,'F52':52}
OWNER_KEYS=['root','bank','event_registers','arena','temporary_event_index_s32','scratch_words']
OWNER_SIZES=[16384,38986,284,5400,4,32]
sha=H.sha;s32=H.s32

def adapt(source):
 source=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',source)
 source=re.sub(r'\+0x(f[0-9a-f]{7})',lambda m:'-0x%x'%(0x100000000-int(m[1],16)),source)
 lines,_=N.Q.procedures(source,NUMBERS);text='\n'.join(lines)
 text=re.sub(r'\[rbp[^\]]*\]',lambda m:re.sub(r'\b(eax|ebx|ecx|edx|esi|edi)\b',lambda r:'r'+r[1][1:],m[0]),text)
 text=re.sub(r'(,\s*)(DATA_\d+|FUNC_\d+)$',r'\1OFFSET FLAT:\2',text,flags=re.M)
 for n,kind in [(44,'node'),(46,'snapshot'),(51,'variables')]:
  begin=text.index('FUNC_%06d:'%n);end=text.find('\nFUNC_',begin+1);end=len(text)if end<0 else end
  body=text[begin:end]
  if body.count('call _malloc')!=1:raise ValueError('Reviewed event malloc call changed F%d'%n)
  text=text[:begin]+body.replace('call _malloc','call bridge_alloc_'+kind)+text[end:]
 text=text.replace('call _free','call bridge_free')
 if text.count('call QWORD PTR [ebx+0x4]')!=1:raise ValueError('F48 callback slot changed')
 text=text.replace('call QWORD PTR [ebx+0x4]','mov r11d,DWORD PTR [rbx+0x4]\ncall bridge_event_callback')
 for n in NUMBERS:text=text.replace('FUNC_%06d:'%n,'FUNC_%06d:\ncall trace_%d'%(n,n),1)
 text=text.replace('JUMP_000494:','JUMP_000494:\ncall scheduler_guard',1)
 return '.intel_syntax noprefix\n.code64\n.section .text\n'+text+'\n'+adapter()

def reprove(a):
 raw=a.exe.read_bytes();source=a.asm.read_text();data=a.data.read_text()
 if sha(raw)!=N.EXE_SHA or sha(a.asm.read_bytes())!=N.ASM_SHA:raise ValueError('Pinned original identity differs')
 method=inspect.getsource(N.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_000048',0x414044)")
 method=method.replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases').replace("syms.update(['_abs','_SetJmp','_LongJmp','_memcpy'])","syms.update(['_abs','_SetJmp','_LongJmp','_memcpy','_malloc','_free'])")
 ns=N.__dict__.copy();exec(method,ns);bodies,records,dis,_,aliases=ns['proof'](source,data,raw,a.exe,NUMBERS)
 assert [aliases['DATA_%06d'%(8550+i)]for i in range(8)]==[0x60bf24+i*4 for i in range(8)]
 selected='\n'.join(bodies[n]for n in NUMBERS)+'\nFUNC_999999:\nret\n';kernel=adapt(selected)
 a.proof_dir.mkdir(parents=True,exist_ok=True)
 for name,value in [('source-procedures.asm',selected),('events-native.s',kernel),('events-host.c',HOST_C),('dos-disassembly.txt','\n'.join(dis.values()))]:(a.proof_dir/name).write_text(value)
 meta={'schema':'starfrontier-original-events-instruction-proof-v1','source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'source_data_sha256':sha(a.data.read_bytes()),'procedures':records,'source_symbol_addresses':aliases,'source_procedures_sha256':sha(selected.encode()),'host_assembly_sha256':sha(kernel.encode()),'host_c_sha256':sha(HOST_C.encode()),'dos_disassembly_sha256':sha((a.proof_dir/'dos-disassembly.txt').read_bytes()),'all_whole_instructions_equal':True,'scratch_owner_alias':{'event_registers_virtual_address':0x60be08,'event_registers_bytes':284,'scratch_words_virtual_address':0x60bf24,'scratch_words_bytes':32,'scratch_is_outside_event_registers':True,'temporary_event_index_virtual_address':0x60bf4c},'host_adaptations':['Complete original IA32 procedures independently reassembled and normalized instruction-equal before ELF64 ABI adaptation.','Source cdecl32 argument slots expanded to host8-byte stack slots; source local pointers remain low32 addresses on an isolated low stack.','Original function-token words remain unmodified in tree keys and16-byte snapshots; only the F48 indirect control transfer is bridged to an explicitly typed provider.','Separate reviewed node32, snapshot16 and variable allocators; monotonically increasing logical IDs with no reuse in the bounded512-allocation profile. Fresh variable bytes use deterministic A5 allocator policy; original F51 writes only its first8 bytes.','Original F42 subtraction wrap/order, duplicate-right insertion, F45 predecessor deletion, F46 subtree snapshot traversal and F54 signed highest-state selection run unchanged.','Readonly normalized module definitions provide the actual pointer-load structure for F54 cleanup and F51 variable sizes; no original VM program execution is claimed.','Host callbacks normalize pointers to arena slots and logical variables; mutable registry actions invoke actual original F44/F45/F50; temporary callback snapshots are not externally mutable.','Semantically undefined EAX returns of source void workers are excluded; compare results and task allocation pointer/packed-handle distinction remain explicit.'],'scope':'Bounded whole F42/F43/F44/F45/F46/F48/F49/F50/F51/F54/F55/F56 with explicit event callback/F53/F41/F52 providers. No full F41 VM, F47 body, F52 argument interpreter, Main or APK claim.'}
 (a.proof_dir/'instruction-proof.json').write_text(json.dumps(meta,indent=2)+'\n');return meta,selected,kernel,HOST_C

def verify(proof=PROOF):
 meta=json.loads((proof/'instruction-proof.json').read_text());source=(proof/'source-procedures.asm').read_text();kernel=(proof/'events-native.s').read_text();host=(proof/'events-host.c').read_text()
 if meta['source_executable_sha256']!=N.EXE_SHA or meta['source_assembly_sha256']!=N.ASM_SHA or sha(source.encode())!=meta['source_procedures_sha256']or sha(kernel.encode())!=meta['host_assembly_sha256']or sha(host.encode())!=meta['host_c_sha256']or sha((proof/'dos-disassembly.txt').read_bytes())!=meta['dos_disassembly_sha256']:raise ValueError('Archived event proof differs')
 for n in NUMBERS:
  r=meta['procedures'][str(n)];rows=N.C.J.instructions(N.C.compile32(N.G.block(source,n),meta['source_symbol_addresses'],'FUNC_%06d'%n,r['virtual_address']))
  if len(rows)!=r['instruction_count']or sha('\n'.join(N.canonical(rows)).encode())!=r['normalized_instruction_sha256']:raise ValueError('Archived events DOS instructions differ F%d'%n)
 return meta,source,kernel,host

def adapter():
 out=['.section .text','.global run_low','run_low:','push rbx','push rbp','push r12','push r13','push r14','push r15','mov r12,rsp','mov rsp,OFFSET FLAT:low_stack_end','and rsp,-16','call c_run_case','mov rsp,r12','pop r15','pop r14','pop r13','pop r12','pop rbp','pop rbx','ret',
 '.global invoke_original','invoke_original:','push rbx','mov r11,rdi','mov ebx,esi','shl ebx,3','mov ecx,esi','test ecx,ecx','jz invoke_go','invoke_push:','dec ecx','mov eax,DWORD PTR [rdx+rcx*4]','push rax','test ecx,ecx','jnz invoke_push','invoke_go:','call r11','add rsp,rbx','pop rbx','ret']
 # Function-entry observation preserves every source register and flags.
 regs=['rax','rbx','rcx','rdx','rsi','rdi','rbp','r8','r9','r10','r11','r12','r13','r14','r15']
 for n in NUMBERS:
  out+=['trace_%d:'%n,'pushfq']+['push '+r for r in regs]+['mov r15,rsp','and rsp,-16','mov edi,%d'%n,'call c_trace','mov rsp,r15']+['pop '+r for r in reversed(regs)]+['popfq','ret']
 out+=['scheduler_guard:','pushfq']+['push '+r for r in regs]+['mov r15,rsp','and rsp,-16','call c_scheduler_guard','mov rsp,r15']+['pop '+r for r in reversed(regs)]+['popfq','ret']
 def bridge(label,function,loads):
  return [label+':','push rbp','mov rbp,rsp','push rbx','push rsi','push rdi','push r12','push r13','push r14','push r15','mov r12,rsp',*loads,'and rsp,-16','call '+function,'mov rsp,r12','pop r15','pop r14','pop r13','pop r12','pop rdi','pop rsi','pop rbx','pop rbp','ret']
 for kind in ['node','snapshot','variables']:out+=bridge('bridge_alloc_'+kind,'c_alloc_'+kind,['mov edi,DWORD PTR [rbp+16]'])
 out+=bridge('bridge_free','c_free',['mov edi,DWORD PTR [rbp+16]'])
 out+=bridge('bridge_event_callback','c_event_callback',['mov edi,r11d','mov esi,DWORD PTR [rbp+16]','mov edx,DWORD PTR [rbp+24]'])
 out+=bridge('FUNC_000053','c_f53',['mov edi,DWORD PTR [rbp+16]'])
 out+=bridge('FUNC_000041','c_f41',['mov edi,DWORD PTR [rbp+16]','mov esi,DWORD PTR [rbp+24]'])
 out+=bridge('FUNC_000052','c_f52',['mov edi,DWORD PTR [rbp+16]','mov esi,DWORD PTR [rbp+24]','mov edx,DWORD PTR [rbp+32]','mov ecx,DWORD PTR [rbp+40]'])
 for n in NUMBERS:out+=['.global FUNC_%06d'%n]
 out+=['s_root=g_root+8','s_bank=g_bank+8','s_events=g_events+8','s_arena=g_arena+8','s_scratch_words=g_scratch+8','DATA_008564=s_registry_root','DATA_008561=s_arena','DATA_008562=s_arena+0x18','DATA_008563=s_arena+0x20','DATA_001697=s_module_table']
 for i in range(8):out+=['DATA_%06d=s_scratch_words+%d'%(8550+i,i*4)]
 out+=['.section .bss','.balign 16','low_stack: .zero 2097152','low_stack_end:','.section .note.GNU-stack,"",@progbits']
 return '\n'.join(out)+'\n'

HOST_C=r'''
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <setjmp.h>
#define CAP 512
#define OUTCAP (512u*1024u*1024u)
#define CHECK(x) do{if(!(x)){fprintf(stderr,"events-native-check:%d\n",__LINE__);exit(97);}}while(0)
#define GUARD UINT64_C(0xa5a5a5a5a5a5a5a5)
#define GUARDED(name,N) struct __attribute__((packed)){uint64_t guard_a;uint8_t data[N];uint64_t guard_b;} name __attribute__((aligned(16)))
GUARDED(g_root,16384);GUARDED(g_bank,38986);GUARDED(g_events,284);GUARDED(g_arena,5400);GUARDED(g_scratch,32);
#define s_root g_root.data
#define s_bank g_bank.data
#define s_events g_events.data
#define s_arena g_arena.data
#define s_scratch_words g_scratch.data
uint32_t s_registry_root,s_module_table[256];
static uint8_t node_pool[CAP][32],snapshot_pool[CAP][16],variable_pool[CAP][1024];
static uint8_t node_live[CAP],snapshot_live[CAP],variable_live[CAP],definition_live[256];
static uint32_t variable_length[CAP],definitions[256][32],definition_original[256][32],cleanup_words[256],cleanup_original[256],definition_refs[256];
static uint32_t next_node,next_variable,snapshot_count,temporary_index,scheduler_steps;
static uint8_t input[4*1024*1024],output[OUTCAP];static uint32_t input_size,outpos;
static uint32_t operation,args[12],trace_words[65536],trace_count,script_count,script_used,status,result_word,allocated_slot,allocated_handle;
static uint32_t captured[CAP][3],captured_count,records_count,pending_kind,pending_argc,pending_args[4];
static uint8_t *script_cursor,*input_end;static jmp_buf case_env;
extern void run_low(void);extern uint32_t invoke_original(void*,uint32_t,uint32_t*);
extern void FUNC_000042(void),FUNC_000043(void),FUNC_000044(void),FUNC_000045(void),FUNC_000046(void),FUNC_000048(void),FUNC_000050(void),FUNC_000051(void),FUNC_000054(void),FUNC_000055(void),FUNC_000056(void);
static uint32_t word(const void*p){uint32_t x;memcpy(&x,p,4);return x;}
static void setword(void*p,uint32_t x){memcpy(p,&x,4);}
static uint32_t ptr(const void*p){CHECK((uintptr_t)p<=0xffffffffu);return(uint32_t)(uintptr_t)p;}
static uint32_t read32(uint8_t**p){CHECK(*p+4<=input_end);uint32_t x=word(*p);*p+=4;return x;}
static void copyin(uint8_t**p,void*d,uint32_t n){CHECK(*p+n<=input_end);memcpy(d,*p,n);*p+=n;}
static void put32(uint32_t x){CHECK(outpos+4<=OUTCAP);setword(output+outpos,x);outpos+=4;}
static void putbytes(const void*p,uint32_t n){CHECK(outpos+n<=OUTCAP);memcpy(output+outpos,p,n);outpos+=n;}
static uint32_t nodeptr(uint32_t id){CHECK(id<=CAP);return id?ptr(node_pool[id-1]):0;}
static uint32_t nodeid(uint32_t address){if(!address)return 0;CHECK(address>=ptr(node_pool)&&address<ptr(node_pool)+sizeof node_pool);uint32_t n=address-ptr(node_pool);CHECK(n%32==0);return n/32+1;}
static uint32_t variableid(uint32_t address){if(!address)return 0;if(address>=ptr(variable_pool)&&address<ptr(variable_pool)+sizeof variable_pool){uint32_t n=address-ptr(variable_pool);CHECK(n%1024==0);return n/1024+1;}return address;}
static uint32_t variableptr(uint32_t id){return id>0&&id<next_variable?ptr(variable_pool[id-1]):id;}
static uint32_t descriptor_token(uint32_t address){for(uint32_t i=0;i<256;i++)if(definition_live[i]&&address==ptr(definitions[i]))return definition_refs[i];return address;}
static uint32_t descriptor_pointer(uint32_t token){for(uint32_t i=0;i<256;i++)if(definition_live[i]&&token==definition_refs[i])return ptr(definitions[i]);return token;}
static void import_arena(void){for(uint32_t i=0;i<150;i++){uint8_t*p=s_arena+i*36;uint32_t v=word(p+32);if(v>0&&v<next_variable)setword(p+32,variableptr(v));setword(p+28,descriptor_pointer(word(p+28)));}}
static void emit_context(void){
 uint32_t start=outpos;put32(0);put32(next_node);put32(nodeid(s_registry_root));put32(next_variable);put32(temporary_index);
 putbytes(s_root,sizeof s_root);putbytes(s_bank,sizeof s_bank);putbytes(s_events,sizeof s_events);
 uint8_t arena[5400];memcpy(arena,s_arena,sizeof arena);for(uint32_t i=0;i<150;i++){uint8_t*p=arena+i*36;setword(p+32,variableid(word(p+32)));setword(p+28,descriptor_token(word(p+28)));}putbytes(arena,sizeof arena);putbytes(s_scratch_words,32);
 uint32_t count=0;for(uint32_t i=0;i<CAP;i++)if(node_live[i])count++;put32(count);
 for(uint32_t i=0;i<CAP;i++)if(node_live[i]){put32(i+1);put32(nodeid(word(node_pool[i])));put32(nodeid(word(node_pool[i]+4)));put32(1);putbytes(node_pool[i]+8,24);}
 count=0;for(uint32_t i=0;i<CAP;i++)if(variable_live[i])count++;put32(count);
 for(uint32_t i=0;i<CAP;i++)if(variable_live[i]){put32(i+1);put32(variable_length[i]);putbytes(variable_pool[i],variable_length[i]);}
 setword(output+start,outpos-start);
}
void c_scheduler_guard(void){CHECK(++scheduler_steps<=1024);}
void c_trace(uint32_t id){CHECK(trace_count<65536);trace_words[trace_count++]=id;}
uint32_t c_alloc_node(uint32_t n){CHECK(n==32&&next_node<=CAP);uint32_t id=next_node++;node_live[id-1]=1;memset(node_pool[id-1],0xa5,32);return nodeptr(id);}
uint32_t c_alloc_snapshot(uint32_t n){CHECK(n==16&&snapshot_count<CAP);uint32_t id=snapshot_count++;snapshot_live[id]=1;memset(snapshot_pool[id],0xa5,16);return ptr(snapshot_pool[id]);}
uint32_t c_alloc_variables(uint32_t n){CHECK(n>=8&&n<=1024&&n%4==0&&next_variable<=CAP);uint32_t id=next_variable++;variable_live[id-1]=1;variable_length[id-1]=n;memset(variable_pool[id-1],0xa5,n);return ptr(variable_pool[id-1]);}
void c_free(uint32_t address){
 if(!address)return;
 if(address>=ptr(node_pool)&&address<ptr(node_pool)+sizeof node_pool){uint32_t id=nodeid(address);CHECK(node_live[id-1]);node_live[id-1]=0;return;}
 if(address>=ptr(snapshot_pool)&&address<ptr(snapshot_pool)+sizeof snapshot_pool){uint32_t n=address-ptr(snapshot_pool);CHECK(n%16==0&&snapshot_live[n/16]);snapshot_live[n/16]=0;return;}
 uint32_t id=variableid(address);CHECK(id>0&&id<next_variable&&id<=CAP&&variable_live[id-1]);variable_live[id-1]=0;
}
static void validate_definitions(void){
 CHECK(g_root.guard_a==GUARD&&g_root.guard_b==GUARD&&g_bank.guard_a==GUARD&&g_bank.guard_b==GUARD&&g_events.guard_a==GUARD&&g_events.guard_b==GUARD&&g_arena.guard_a==GUARD&&g_arena.guard_b==GUARD&&g_scratch.guard_a==GUARD&&g_scratch.guard_b==GUARD);
 for(uint32_t i=0;i<256;i++)if(definition_live[i]){CHECK(s_module_table[i]==ptr(definitions[i]));CHECK(memcmp(definitions[i],definition_original[i],128)==0);CHECK(cleanup_words[i]==cleanup_original[i]);}
}
static void action(uint32_t op,uint32_t argc,uint32_t*a){
 if(op==44){CHECK(argc==6);invoke_original(FUNC_000044,6,a);}
 else if(op==45){CHECK(argc==6);invoke_original(FUNC_000045,6,a);}
 else{CHECK(op==50&&argc==0);invoke_original(FUNC_000050,0,a);}
}
static uint32_t external(uint32_t kind,uint32_t argc,uint32_t*a){
 c_trace(kind);CHECK(argc<=4);
 if(script_used>=script_count){status=1;pending_kind=kind;pending_argc=argc;memcpy(pending_args,a,argc*4);longjmp(case_env,1);}
 uint8_t*p=script_cursor;CHECK(read32(&p)==kind);CHECK(read32(&p)==argc);for(uint32_t i=0;i<argc;i++)CHECK(read32(&p)==a[i]);uint32_t ret=read32(&p);
 put32(1);put32(kind);put32(argc);for(uint32_t i=0;i<argc;i++)put32(a[i]);put32(ret);emit_context();
 uint32_t patches=read32(&p);CHECK(patches<=32);
 for(uint32_t i=0;i<patches;i++){
  uint32_t owner=read32(&p),ref=read32(&p),off=read32(&p),len=read32(&p);uint8_t*dst=0;uint32_t size=0;
  if(owner==0){dst=s_root;size=sizeof s_root;}else if(owner==1){dst=s_bank;size=sizeof s_bank;}else if(owner==2){dst=s_events;size=sizeof s_events;}else if(owner==3){dst=s_arena;size=sizeof s_arena;}else if(owner==4){dst=(uint8_t*)&temporary_index;size=4;}else if(owner==5){dst=s_scratch_words;size=32;}else{CHECK(owner==6&&ref>0&&ref<next_variable&&variable_live[ref-1]);dst=variable_pool[ref-1];size=variable_length[ref-1];}
  CHECK(len<=64&&off<=size&&len<=size-off);copyin(&p,dst+off,len);
 }
 import_arena();uint32_t actions=read32(&p);CHECK(actions<=64);
 for(uint32_t i=0;i<actions;i++){uint32_t op=read32(&p),n=read32(&p),values[6];CHECK(n<=6);for(uint32_t j=0;j<n;j++)values[j]=read32(&p);action(op,n,values);}
 script_cursor=p;script_used++;emit_context();records_count++;return ret;
}
uint32_t c_event_callback(uint32_t code,uint32_t a,uint32_t b){CHECK(code!=0&&captured_count<CAP);captured[captured_count][0]=code;captured[captured_count][1]=a;captured[captured_count++][2]=b;uint32_t v[3]={code,a,b};return external(48000,3,v);}
uint32_t c_f53(uint32_t task){CHECK(task>=ptr(s_arena)&&task<ptr(s_arena)+sizeof s_arena&&(task-ptr(s_arena))%36==0);uint32_t slot=(task-ptr(s_arena))/36;uint32_t a[2]={slot,word(s_arena+slot*36+4)};return external(53,2,a);}
uint32_t c_f41(uint32_t instruction_pointer,uint32_t task){CHECK(task>=ptr(s_arena)&&task<ptr(s_arena)+sizeof s_arena&&(task-ptr(s_arena))%36==0);uint32_t a[2]={(task-ptr(s_arena))/36,word((void*)(uintptr_t)instruction_pointer)};return external(41,2,a);}
uint32_t c_f52(uint32_t a,uint32_t b,uint32_t c,uint32_t d){uint32_t values[4]={a,b,c,d};return external(52,4,values);}
static void load_case(uint8_t*p){
 g_root.guard_a=g_root.guard_b=g_bank.guard_a=g_bank.guard_b=g_events.guard_a=g_events.guard_b=g_arena.guard_a=g_arena.guard_b=g_scratch.guard_a=g_scratch.guard_b=GUARD;
 operation=read32(&p);CHECK(operation<11);for(uint32_t i=0;i<12;i++)args[i]=read32(&p);
 next_node=read32(&p);uint32_t root_id=read32(&p);next_variable=read32(&p);temporary_index=read32(&p);CHECK(next_node>=1&&next_node<=513&&next_variable>=1&&next_variable<=513);
 copyin(&p,s_root,sizeof s_root);copyin(&p,s_bank,sizeof s_bank);copyin(&p,s_events,sizeof s_events);copyin(&p,s_arena,sizeof s_arena);copyin(&p,s_scratch_words,32);
 memset(node_live,0,sizeof node_live);memset(snapshot_live,0,sizeof snapshot_live);memset(variable_live,0,sizeof variable_live);memset(definition_live,0,sizeof definition_live);memset(s_module_table,0,sizeof s_module_table);memset(node_pool,0xa5,sizeof node_pool);memset(variable_pool,0xa5,sizeof variable_pool);
 uint32_t count=read32(&p);CHECK(count<=CAP);
 for(uint32_t i=0;i<count;i++){uint32_t id=read32(&p),left=read32(&p),right=read32(&p),generation=read32(&p);CHECK(id>0&&id<next_node&&generation==1);node_live[id-1]=1;setword(node_pool[id-1],nodeptr(left));setword(node_pool[id-1]+4,nodeptr(right));copyin(&p,node_pool[id-1]+8,24);}
 s_registry_root=nodeptr(root_id);count=read32(&p);CHECK(count<=CAP);
 for(uint32_t i=0;i<count;i++){uint32_t id=read32(&p),len=read32(&p);CHECK(id>0&&id<next_variable&&len>=8&&len<=1024&&len%4==0);variable_live[id-1]=1;variable_length[id-1]=len;copyin(&p,variable_pool[id-1],len);}
 count=read32(&p);CHECK(count<=256);
 for(uint32_t i=0;i<count;i++){uint32_t id=read32(&p),ref=read32(&p),cleanup=read32(&p),words=read32(&p);CHECK(id<256&&words>=2&&words<=256);definition_live[id]=1;definition_refs[id]=ref;memset(definitions[id],0xa5,sizeof definitions[id]);definitions[id][3]=0;definitions[id][4]=words;cleanup_words[id]=cleanup;definitions[id][7]=ptr(cleanup_words+id);s_module_table[id]=ptr(definitions[id]);memcpy(definition_original[id],definitions[id],128);cleanup_original[id]=cleanup;}
 import_arena();script_count=read32(&p);CHECK(script_count<=256);script_cursor=p;
}
void c_run_case(void){
 trace_count=script_used=snapshot_count=status=records_count=captured_count=scheduler_steps=0;result_word=0;allocated_slot=0xffffffffu;allocated_handle=0;pending_kind=pending_argc=0;outpos=24;
 if(setjmp(case_env)==0){
  uint32_t returned=0;
  if(operation<=1){uint32_t a[2]={ptr(args),ptr(args+6)};returned=invoke_original(operation==0?FUNC_000042:FUNC_000043,2,a);result_word=returned;}
  else if(operation==2)invoke_original(FUNC_000044,6,args);
  else if(operation==3)invoke_original(FUNC_000045,6,args);
  else if(operation==4){uint32_t first=0,tail=ptr(&first),a[3]={ptr(&tail),s_registry_root,ptr(args)};invoke_original(FUNC_000046,3,a);uint32_t cursor=first;while(cursor){CHECK(captured_count<CAP);memcpy(captured[captured_count++],(void*)(uintptr_t)(cursor+4),12);uint32_t next=word((void*)(uintptr_t)cursor);c_free(cursor);cursor=next;}}
  else if(operation==5)invoke_original(FUNC_000048,3,args);
  else if(operation==6)invoke_original(FUNC_000050,0,args);
  else if(operation==7){uint32_t free_slot=0;for(uint32_t i=0;i<150;i++)if(word(s_arena+i*36)==0)free_slot=1;if(free_slot)CHECK(args[0]<256&&definition_live[args[0]]);returned=invoke_original(FUNC_000051,2,args);if(returned){CHECK(returned>=ptr(s_arena)&&returned<ptr(s_arena)+sizeof s_arena);allocated_slot=(returned-ptr(s_arena))/36;allocated_handle=word((void*)(uintptr_t)(returned+4));}}
  else if(operation==8)invoke_original(FUNC_000054,0,args);
  else if(operation==9)invoke_original(FUNC_000055,0,args);
  else invoke_original(FUNC_000056,0,args);
 }
 CHECK(script_used==script_count);validate_definitions();
 put32(2);put32(trace_count);for(uint32_t i=0;i<trace_count;i++)put32(trace_words[i]);emit_context();put32(captured_count);for(uint32_t i=0;i<captured_count;i++)putbytes(captured[i],12);
 if(status){put32(3);put32(pending_kind);put32(pending_argc);for(uint32_t i=0;i<pending_argc;i++)put32(pending_args[i]);}
 setword(output,0x45564e54);setword(output+4,outpos);setword(output+8,status);setword(output+12,result_word);setword(output+16,allocated_slot);setword(output+20,allocated_handle);
}
int main(void){while(fread(&input_size,4,1,stdin)==1){CHECK(input_size>=4&&input_size<=sizeof input);CHECK(fread(input,input_size-4,1,stdin)==1);input_end=input+input_size-4;load_case(input);run_low();CHECK(fwrite(output,outpos,1,stdout)==1);}return 0;}
'''

def u32(value):return struct.pack('<I',int(value)&0xffffffff)
def words(values):return b''.join(u32(x)for x in values)
def raw_buffer(value):return bytes.fromhex(value)if isinstance(value,str)else bytes(value)

def context_packet(c):
 raw=words([c['next_node_id_u32'],c['tree_root_u32'],c['next_variable_id_u32'],c['temporary_event_index_s32']])
 for k,n in [('root',16384),('bank',38986),('event_registers',284),('arena',5400),('scratch_words',32)]:
  b=raw_buffer(c[k])
  if len(b)!=n:raise ValueError('Event context buffer differs '+k)
  raw+=b
 raw+=u32(len(c['nodes']))
 for key,node in sorted(c['nodes'].items(),key=lambda p:int(p[0])):raw+=words([int(key),node['left_u32'],node['right_u32'],node['generation_u32'],*node['key_u32']])
 raw+=u32(len(c['task_variables']))
 for key,value in sorted(c['task_variables'].items(),key=lambda p:int(p[0])):
  b=raw_buffer(value);raw+=words([int(key),len(b)])+b
 raw+=u32(len(c['definitions']))
 for key,d in sorted(c['definitions'].items(),key=lambda p:int(p[0])):raw+=words([int(key),d['descriptor_ref_u32'],d['cleanup_instruction_u32'],d['variable_words_u32']])
 return raw

def packet(row,scripts=None):
 scripts=row.get('_scripts',[])if scripts is None else scripts
 args=row['args'];flat=sum(args,[])if row['operation']in ['F42','F43']else args
 raw=words([OPERATIONS.index(row['operation']),*(flat+[0]*12)[:12]])+context_packet(row['context_before'])+u32(len(scripts))
 for script in scripts:
  raw+=words([KIND_IDS[script['kind']],len(script['args']),*script['args'],script.get('return_u32',0)])
  patches=script.get('patches',[]);raw+=u32(len(patches))
  for p in patches:
   owner=p['owner'];ref=int(p.get('variable_id_u32',0));number=6 if owner=='task_variables'else OWNER_KEYS.index(owner);b=bytes.fromhex(p['bytes_hex']);raw+=words([number,ref,p['offset_u32'],len(b)])+b
  actions=script.get('registry_actions',[]);raw+=u32(len(actions))
  for a in actions:raw+=words([int(a['operation'][1:]),len(a['args']),*a['args']])
 return u32(len(raw)+4)+raw

class Reader:
 def __init__(self,data):self.data=data;self.at=0
 def word(self):
  v=struct.unpack_from('<I',self.data,self.at)[0];self.at+=4;return v
 def take(self,n):v=self.data[self.at:self.at+n];self.at+=n;return v
 def context(self,row):
  start=self.at;size=self.word();next_node=self.word();root=self.word();next_var=self.word();temp=self.word()
  c={'next_node_id_u32':next_node,'tree_root_u32':root,'next_variable_id_u32':next_var,'temporary_event_index_s32':s32(temp)}
  for k,n in [('root',16384),('bank',38986),('event_registers',284),('arena',5400),('scratch_words',32)]:c[k]=self.take(n).hex()
  c['nodes']={}
  for _ in range(self.word()):
   i=self.word();left=self.word();right=self.word();generation=self.word();key=[self.word()for _ in range(6)];c['nodes'][str(i)]={'left_u32':left,'right_u32':right,'generation_u32':generation,'key_u32':key}
  c['task_variables']={}
  for _ in range(self.word()):i=self.word();n=self.word();c['task_variables'][str(i)]=self.take(n).hex()
  c['definitions']=copy.deepcopy(row['context_before']['definitions'])
  if self.at-start!=size:raise ValueError('Event native snapshot boundary differs')
  return c

def decode(raw,row):
 r=Reader(raw);magic,size,status,ret,slot,handle=[r.word()for _ in range(6)]
 if magic!=0x45564e54 or size!=len(raw)or status>1:raise ValueError('Event native output differs')
 observations=[];pending=None;context=None;captured=[];order=[]
 ids={**{n:'F%d'%n for n in NUMBERS},**{v:k for k,v in KIND_IDS.items()}}
 while r.at<len(raw):
  tag=r.word()
  if tag==1:
   kind=ids[r.word()];args=[r.word()for _ in range(r.word())];returned=r.word();before=r.context(row);after=r.context(row)
   observations.append({'kind':kind,'args':args,'before':before,'after':after,'return_u32':returned})
  elif tag==2:
   order=[ids[r.word()]for _ in range(r.word())];context=r.context(row);captured=[[r.word(),r.word(),r.word()]for _ in range(r.word())]
  elif tag==3:kind=ids[r.word()];args=[r.word()for _ in range(r.word())];pending={'kind':kind,'args':args,'before':copy.deepcopy(context)}
  else:raise ValueError('Unknown native event tag')
 if context is None:raise ValueError('Missing native final context')
 expected={'context_after':context,'source_order':order,'observations_used':len(observations),'captured_callbacks':captured,'return_defined':row['operation']in ['F42','F43']}
 if row['operation']in ['F42','F43']:expected.update(return_u32=ret,return_s32=s32(ret))
 if row['operation']=='F51':expected.update(allocated_slot_s32=s32(slot),allocated_handle_u32=handle)
 return {'status':status,'expected':expected,'observations':observations,'pending':pending}

def patch(owner,offset,value,variable_id=None):
 p={'owner':owner,'offset_u32':offset,'bytes_hex':value.hex()}
 if variable_id is not None:p['variable_id_u32']=variable_id
 return p

def p32(owner,offset,value):return patch(owner,offset,u32(value))

def baseline():
 return {'root':(b'\xa5'*16384).hex(),'bank':(b'\x5a'*38986).hex(),'event_registers':bytes((i*13+7)&255 for i in range(284)).hex(),'scratch_words':bytes(range(1,33)).hex(),'arena':bytes(5400).hex(),'temporary_event_index_s32':-1,'tree_root_u32':0,'nodes':{},'next_node_id_u32':1,'task_variables':{},'next_variable_id_u32':1,'definitions':{'0':{'descriptor_ref_u32':0x70000000,'cleanup_instruction_u32':0x60000000,'variable_words_u32':4},'1':{'descriptor_ref_u32':0x70001000,'cleanup_instruction_u32':0x60001000,'variable_words_u32':2},'2':{'descriptor_ref_u32':0x70002000,'cleanup_instruction_u32':0x60002000,'variable_words_u32':256}}}

def node(key,left=0,right=0):return {'left_u32':left,'right_u32':right,'generation_u32':1,'key_u32':list(key)}

def tree_context(keys,links):
 c=baseline();c['nodes']={str(i+1):node(k,*links[i])for i,k in enumerate(keys)};c['next_node_id_u32']=len(keys)+1;c['tree_root_u32']=1 if keys else 0;return c

def build_rows():
 rows=[]
 def add(name,op,args=None,c=None,policy=None):
  r={'name':name,'operation':op,'args':copy.deepcopy(args or[]),'context_before':copy.deepcopy(c or baseline()),'_policy':policy or{}};rows.append(r);return r
 pairs=[(0,0),(0,1),(1,0),(0x7fffffff,0xffffffff),(0x80000000,0),(0xffffffff,0x7fffffff),(0,0x80000000)]
 for op,count in [('F42',6),('F43',3)]:
  for index in range(count):
   for i,(a,b)in enumerate(pairs):
    first=[0]*6;second=[0]*6;first[index]=a;second[index]=b;add('compare/%s/%d/%d'%(op,index,i),op,[first,second])
 key=[2,0,12,0x414000,1,0]
 # Sequential insertion uses actual preceding native tree topology.
 for i in range(24):
  k=key.copy();k[[0,1,2,4,5,3][i%6]]=[0,1,0x80000000,0xffffffff][i%4];r=add('insert-stream/%02d'%i,'F44',k);r['_carry_previous']=i>0
 fixtures=[
  ('leaf',[key],[(0,0)],key),
  ('left-only',[key,[1,0,12,0x414001,2,0]],[(2,0),(0,0)],key),
  ('right-only',[key,[3,0,12,0x414002,3,0]],[(0,2),(0,0)],key),
  ('both-immediate',[key,[1,0,12,0x414001,2,0],[3,0,12,0x414002,3,0]],[(2,3),(0,0),(0,0)],key),
  ('both-deep',[key,[1,0,12,0x414001,2,0],[3,0,12,0x414002,3,0],[1,1,12,0x414003,4,0],[1,0,13,0x414004,5,0]],[(2,3),(0,4),(0,0),(5,0),(0,0)],key),
  ('duplicate',[key,key,key],[(0,2),(0,3),(0,0)],key),
  ('no-match',[key],[(0,0)],[2,0,13,0x414000,1,0]),
 ]
 for name,keys,links,wanted in fixtures:add('remove/'+name,'F45',wanted,tree_context(keys,links))
 for value in [0,1,0x7fffffff,0x80000000,0xffffffff]:
  keys=[[value,0,12,0x414000,1,0],[0,0,12,0x414001,2,0],[0xffffffff,0,12,0x414002,3,0]];add('wrapped-remove/%08x'%value,'F45',keys[1],tree_context(keys,[(2,3),(0,0),(0,0)]))
 group=[[2,0,12,0x414000+i,i+1,0]for i in [2,1,3,0,4]]
 c=tree_context(group,[(2,3),(4,0),(0,5),(0,0),(0,0)])
 for op in ['F46','F48']:
  for key3 in [[2,0,12],[2,0,13],[0,0,0],[0xffffffff,0,12]]:add('snapshot/%s/%s'%(op,'-'.join(map(str,key3))),op,key3,c)
 for name,actions in [('clear',[{'operation':'F50','args':[]}]),('remove-future',[{'operation':'F45','args':group[2]}]),('insert-new',[{'operation':'F44','args':[2,0,12,0x414100,99,88]}]),('remove-and-insert',[{'operation':'F45','args':group[1]},{'operation':'F44','args':[2,0,12,0x414101,77,66]}])]:
  add('callback-registry/'+name,'F48',[2,0,12],c,{'event_callback:1':{'registry_actions':actions}})
 add('callback-owners','F48',[2,0,12],c,{'event_callback:1':{'patches':[p32('event_registers',12*4,0xffffffff),p32('temporary_event_index_s32',0,37),patch('bank',117,b'changed'),p32('root',0x24,0xdeadbeef),p32('scratch_words',0,0x87654321)]}})
 # Found-subtree only traversal differs from a whole-tree prefix filter when
 # source wrapped comparators are non-transitive.
 wrapped=tree_context([[0x80000000,0,0,0x414000,1,0],[0,0,0,0x414001,2,0],[0,0,0,0x414002,3,0]],[(2,3),(0,0),(0,0)])
 add('snapshot-wrapped-subtree','F48',[0,0,0],wrapped)
 for initial in [0,1,65535]:
  for module in [0,1,2]:
   ctx=baseline();a=bytearray.fromhex(ctx['arena']);struct.pack_into('<H',a,6,initial);ctx['arena']=a.hex();add('allocate/%d/%d'%(initial,module),'F51',[module,0x89abcdef],ctx)
 ctx=baseline();a=bytearray.fromhex(ctx['arena'])
 for i in range(150):struct.pack_into('<i',a,i*36,1)
 ctx['arena']=a.hex();add('allocate-full-arena','F51',[0,0],ctx)
 unloaded=copy.deepcopy(ctx);unloaded['definitions']={};add('allocate-full-arena-unused-definition','F51',[255,0],unloaded)
 for free in [1,74,149]:
  ctx=baseline();a=bytearray.fromhex(ctx['arena'])
  for i in range(free):struct.pack_into('<i',a,i*36,1)
  ctx['arena']=a.hex();add('allocate-first-hole/%d'%free,'F51',[0,free],ctx)
 def task_context(states):
  ctx=baseline();a=bytearray.fromhex(ctx['arena'])
  for index,state in states:
   struct.pack_into('<i',a,index*36,state);struct.pack_into('<I',a,index*36+4,(7<<16)|index);struct.pack_into('<I',a,index*36+24,index%3);struct.pack_into('<I',a,index*36+28,ctx['definitions'][str(index%3)]['descriptor_ref_u32']);struct.pack_into('<I',a,index*36+32,index+1);ctx['task_variables'][str(index+1)]=words([(7<<16)|index,0xf00d]).hex()
  ctx['next_variable_id_u32']=max([i+2 for i,_ in states]+[1]);ctx['arena']=a.hex();return ctx
 for states in [[],[(0,4)],[(0,5)],[(0,6)],[(1,4),(5,4)],[(0,4),(1,6),(2,5)],[(149,5)],[(0,-1)],[(0,1),(1,2),(2,3)],[(0,6),(1,6),(2,6)],[(0,4),(149,4)]]:add('scheduler/'+str(states),'F54',[],task_context(states))
 for states in [[],[(0,4),(1,5)],[(0,6)],[(0,-1)],[(0,1),(1,2),(2,3)]]:add('clear-all/'+str(states),'F56',[],task_context(states)|{'tree_root_u32':c['tree_root_u32'],'nodes':copy.deepcopy(c['nodes']),'next_node_id_u32':c['next_node_id_u32']})
 for states in [[],[(0,4)],[(0,5)],[(0,6)]]:add('initialize/'+str(states),'F55',[],task_context(states))
 add('clear-empty','F50');add('clear-tree','F50',[],c)
 # Allocation/free reuse keeps physical task slots and increments their16-bit
 # generations, while logical variable IDs never repeat under this profile.
 for i in range(20):
  op='F51'if i%2==0 else'F56';r=add('task-reuse-stream/%02d'%i,op,[0,i]if op=='F51'else[]);r['_carry_previous']=i>0
 return rows

def encode_context(context,pool):
 out=copy.deepcopy(context)
 for k in ['root','bank','event_registers','arena','scratch_words']:
  data=raw_buffer(out[k]);key=sha(data)
  if key not in pool:pool[key]={'byte_count':len(data),'zlib_base64':base64.b64encode(zlib.compress(data,9)).decode()}
  out[k]=key
 for k,value in out['task_variables'].items():
  data=raw_buffer(value);key=sha(data)
  if key not in pool:pool[key]={'byte_count':len(data),'zlib_base64':base64.b64encode(zlib.compress(data,9)).decode()}
  out['task_variables'][k]=key
 return out

def hydrate_buffer(fixture,key):
 v=fixture['buffers'][key];raw=zlib.decompress(base64.b64decode(v['zlib_base64']))
 if len(raw)!=v['byte_count']or sha(raw)!=key:raise ValueError('Event context pooled buffer differs')
 return raw

def hydrate_context(fixture,context):
 out=copy.deepcopy(context)
 for k in ['root','bank','event_registers','arena','scratch_words']:out[k]=hydrate_buffer(fixture,out[k]).hex()
 for k,v in out['task_variables'].items():out['task_variables'][k]=hydrate_buffer(fixture,v).hex()
 return out

def raw_row(fixture,row):
 out={k:copy.deepcopy(row[k])for k in ['name','operation','args']};out['context_before']=hydrate_context(fixture,row['context_before']);out['_scripts']=[]
 for o in row['observations']:
  out['_scripts'].append({k:copy.deepcopy(o[k])for k in ['kind','args','return_u32','registry_actions','authored_patches']})
  out['_scripts'][-1]['patches']=out['_scripts'][-1].pop('authored_patches')
 return out

def compile_native(kernel,host,directory):
 d=Path(directory);(d/'kernel.s').write_text(kernel);(d/'host.c').write_text(host)
 commands=[['as','--64',str(d/'kernel.s'),'-o',str(d/'kernel.o')],['gcc','-std=c11','-O2','-fno-pie','-fno-stack-protector','-no-pie',str(d/'host.c'),str(d/'kernel.o'),'-o',str(d/'native')]]
 for cmd in commands:
  p=subprocess.run(cmd,capture_output=True,text=True)
  if p.returncode:raise ValueError('Native event build failed '+p.stderr)
 return d/'native'

def generate(a):
 if a.reprove_original or not(a.proof_dir/'instruction-proof.json').exists():reprove(a)
 meta,source,kernel,host=verify(a.proof_dir);rows=build_rows();pool={};native_hash=hashlib.sha256();serialized=[];counts={k:0 for k in KIND_IDS}
 with tempfile.TemporaryDirectory(prefix='source-events-native-')as directory:
  executable=compile_native(kernel,host,directory)
  def run(row,scripts):
   p=subprocess.run([str(executable)],input=packet(row,scripts),capture_output=True,timeout=15)
   if p.returncode or p.stderr:raise ValueError('Events native failed '+row['name']+' code'+str(p.returncode)+' '+p.stderr.decode())
   return p.stdout
  final_raw=[];previous=None
  for row in rows:
   if row.get('_carry_previous'):row['context_before']=copy.deepcopy(previous['expected']['context_after'])
   scripts=[];occurrences={k:0 for k in KIND_IDS}
   for step in range(257):
    raw=run(row,scripts);value=decode(raw,row)
    if not value['status']:break
    pending=value['pending'];kind=pending['kind'];occurrences[kind]+=1;policy=row.get('_policy',{}).get(kind+':'+str(occurrences[kind]),{});patches=copy.deepcopy(policy.get('patches',[]))
    if kind=='F53':patches=[p32('arena',pending['args'][0]*36,3),*patches]
    scripts.append({'kind':kind,'args':pending['args'],'return_u32':0x12345678,'patches':patches,'registry_actions':copy.deepcopy(policy.get('registry_actions',[]))})
   else:raise ValueError('Events callback discovery exceeded bounded profile')
   for k in row.get('_policy',{}):
    kind,n=k.rsplit(':',1)
    if occurrences[kind]<int(n):raise ValueError('Directed event policy not executed '+row['name']+'/'+k)
   runs=[raw]+[run(row,scripts)for _ in range(2)]
   if len(set(runs))!=1:raise ValueError('Events fresh process results differ')
   row['_scripts']=scripts;row['_decoded']=value;previous=value;native_hash.update(raw);final_raw.append(raw)
  p=subprocess.run([str(executable)],input=b''.join(packet(r)for r in reversed(rows)),capture_output=True,check=True,timeout=120);cursor=0
  if p.stderr:raise ValueError(p.stderr.decode())
  for wanted in reversed(final_raw):
   if p.stdout[cursor:cursor+len(wanted)]!=wanted:raise ValueError('Events reverse-order process differs')
   cursor+=len(wanted)
  if cursor!=len(p.stdout):raise ValueError('Events reverse result length differs')
 for row in rows:
  decoded=row['_decoded'];obs=[]
  for o,script in zip(decoded['observations'],row['_scripts']):
   counts[o['kind']]+=1;obs.append({'kind':o['kind'],'args':o['args'],'before':encode_context(o['before'],pool),'after':encode_context(o['after'],pool),'return_u32':o['return_u32'],'registry_actions':script['registry_actions'],'authored_patches':script['patches']})
  expected=copy.deepcopy(decoded['expected']);expected['context_after']=encode_context(expected['context_after'],pool)
  serialized.append({k:copy.deepcopy(row[k])for k in ['name','operation','args']}|{'context_before':encode_context(row['context_before'],pool),'observations':obs,'expected':expected,'carries_previous_native_state':bool(row.get('_carry_previous')),'input_provenance':'Authored normalized raw owner/tree/arena operands; all expected operations and callback states measured from original instructions.'})
 dependencies=['tools/rebuild_source_events_native.py','tools/rebuild_source_damage_native.py','tools/rebuild_source_natural_contact_native.py','tools/rebuild_source_surface_contact_native.py','recovered-history/ground_harness/tools/build_terrain_query_reference.py','recovered-history/ground_harness/tools/native_reference.py']
 fixture={'schema':'starfrontier-source-events-native-v1','profile':PROFILE,'case_count':len(rows),'fresh_process_runs':3,'reverse_repeat_cases':len(rows),'consecutive_shared_state_steps':sum(bool(r.get('_carry_previous'))for r in rows),'source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'instruction_proof_sha256':sha((a.proof_dir/'instruction-proof.json').read_bytes()),'native_output_sha256':native_hash.hexdigest(),'expected_arithmetic_calculated_in_python':False,'all_external_results_explicit':True,'external_requests':counts,'source_dependencies_sha256':{p:sha((PROJECT/p).read_bytes())for p in dependencies},'buffer_codec':'sha256-keyed zlib_base64; decoded byte count and SHA256 checked','buffers':pool,'scope':meta['scope'],'cases':serialized}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(fixture,indent=2)+'\n');print(json.dumps({'case_count':len(rows),'external_requests':counts,'sha256':sha(a.output.read_bytes()),'bytes':a.output.stat().st_size,'output':str(a.output)},indent=2))

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--reprove-original',action='store_true');generate(p.parse_args())
if __name__=='__main__':main()
