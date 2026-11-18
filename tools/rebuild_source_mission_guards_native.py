#!/usr/bin/env python3
"""Whole original DOS guard registration F32/F33 and event words F34/F35.

The native instruction oracle leaves expression evaluation and registry/world
calls as explicitly measured providers. No host pointer is a saved task token.
"""
from __future__ import annotations
import argparse,copy,hashlib,inspect,json,re,struct,subprocess,tempfile
from pathlib import Path
import rebuild_source_damage_native as H
N=H.N;PROJECT=N.PROJECT
PROOF=PROJECT/'validation/mission-expressions-2026-11-18/guards-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_mission_guards_native.json'
NUMBERS=[20,32,33,34,35]
PROFILE='dos-firstenc-mission-guards-v1'
METADATA_SHA='fa9ea4bbb6b062b426e0c56299b0aa1a646341a7355bb51aa5cad574cc8670b0'
sha=H.sha
_compile32=N.C.compile32
def compile32(body,aliases,entry,address):
 # GAS needs OFFSET for the NASM function-token immediate; width remains32.
 body=re.sub(r'push dword (FUNC_\d+)',r'push OFFSET FLAT:\1',body)
 return _compile32(body,aliases,entry,address)

def reprove(a):
 exe=a.exe.read_bytes();source=a.asm.read_text();data=a.data.read_text()
 if sha(exe)!=N.EXE_SHA or sha(a.asm.read_bytes())!=N.ASM_SHA:raise ValueError('Original source identity differs')
 method=inspect.getsource(N.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_000034',0x4124f8)")
 method=method.replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
 ns=N.__dict__.copy();exec(method,ns)
 N.C.compile32=compile32
 try:bodies,records,dis,_,aliases=ns['proof'](source,data,exe,a.exe,NUMBERS)
 finally:N.C.compile32=_compile32
 captured='\n'.join(bodies[n]for n in NUMBERS)+'\nFUNC_999999:\nret\n'
 for row in records.values():row['hex']=exe[row['executable_offset']:row['executable_offset']+row['byte_length']].hex()
 if aliases['DATA_008548']!=0x60be08:raise ValueError('Event-register alias differs')
 metadata=aliases['DATA_001701']
 if [aliases['DATA_%06d'%n] for n in range(1701,1705)]!=[metadata+i*4 for i in range(4)]:raise ValueError('Guard metadata is not one interleaved16B row table')
 metadata_hex=exe[N.G.Image(exe).offset(metadata,1088):N.G.Image(exe).offset(metadata,1088)+1088].hex()
 meta={'schema':'starfrontier-mission-guards-original-proof-v1','source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'procedures':records,'bindings':aliases,'source_procedures_sha256':sha(captured.encode()),'all_whole_instructions_equal':True,'metadata_original_va_u32':metadata,'metadata_hex':metadata_hex,'metadata_sha256':sha(bytes.fromhex(metadata_hex)),'scope':'Whole F32/F33 guard parser/registration, F34/F35 event words plus shared F20 literal helper; F31 evaluation and F44/F45/F48 registry dispatch remain explicit ordered continuations. No whole mission VM or Main claim.'}
 a.proof_dir.mkdir(parents=True,exist_ok=True)
 (a.proof_dir/'source-procedures.asm').write_text(captured);(a.proof_dir/'instruction-proof.json').write_text(json.dumps(meta,indent=2)+'\n');(a.proof_dir/'dos-disassembly.txt').write_text('\n'.join(dis.values()))
 (a.proof_dir/'guards-native.s').write_text(assembly(captured));(a.proof_dir/'guards-host.c').write_text(HOST_C)
 return meta,captured

def verify(proof=PROOF):
 meta=json.loads((proof/'instruction-proof.json').read_text());source=(proof/'source-procedures.asm').read_text()
 if meta['source_executable_sha256']!=N.EXE_SHA or sha(source.encode())!=meta['source_procedures_sha256']or meta['metadata_sha256']!=METADATA_SHA or sha(bytes.fromhex(meta['metadata_hex']))!=METADATA_SHA:raise ValueError('Archived guard proof differs')
 for n in NUMBERS:
  row=meta['procedures'][str(n)];raw=bytes.fromhex(row['hex']);compiled=N.C.J.instructions(compile32(N.G.block(source,n),meta['bindings'],'FUNC_%06d'%n,row['virtual_address']))
  if sha(raw)!=row['sha256']or len(compiled)!=row['instruction_count']or sha('\n'.join(N.canonical(compiled)).encode())!=row['normalized_instruction_sha256']:raise ValueError('Original guard instructions differ')
 if (proof/'guards-native.s').read_text()!=assembly(source)or(proof/'guards-host.c').read_text()!=HOST_C:raise ValueError('Guard host adaptation differs from archived source')
 return meta,source

def trace(n,track=False):
 regs=['rax','rbx','rcx','rdx','rsi','rdi','r8','r9','r10','r11']
 out=['pushfq']+['push '+r for r in regs]
 if track:out+=['mov eax,DWORD PTR [rsp+96]','mov DWORD PTR [g_current_ip],eax']
 out+=['mov eax,DWORD PTR [g_trace_count]','cmp eax,8192','jae g_abort','mov DWORD PTR [g_trace+rax*4],%d'%n,'inc DWORD PTR [g_trace_count]']
 return '\n'.join(out+['pop '+r for r in reversed(regs)]+['popfq'])+'\n'

def assembly(source):
 source=source.replace('add esp,byte -0x8','add esp,byte -0x10') # F32 two-pop frame: 8→16 host bytes.
 lines,_=N.Q.procedures(source,NUMBERS);text='\n'.join(lines)
 text=re.sub(r'\[rbp[^\]]*\]',lambda m:re.sub(r'\b(eax|ebx|ecx|edx|esi|edi)\b',lambda r:'r'+r[1][1:],m[0]),text)
 text=text.replace('push dword FUNC_000047','push 0x413ff4')
 # F33 loads a readonly DOS program reference: relocate only the transport
 # register, preserving both the source bytes and source processor flags.
 marker='mov eax,[eax+ebx*4+0x8]'
 if text.count(marker)!=1:raise ValueError('F33 readonly clause pointer load changed')
 text=text.replace(marker,marker+'\npushfq\nsub eax,DWORD PTR [g_source_base]\nadd eax,DWORD PTR [g_program_pointer]\npopfq')
 for n in NUMBERS:text=text.replace('FUNC_%06d:\n'%n,'FUNC_%06d:\n'%(n)+trace(n,n==32),1)
 support=[]
 for n,argc in [(31,2),(44,6),(45,6),(48,3)]:
  loads=['mov eax,DWORD PTR [rbp+%d]\nmov DWORD PTR [g_args+%d],eax'%(16+i*8,i*4)for i in range(argc)]
  if n in [44,45]:loads+=['movzx eax,bl','shl eax,4','mov eax,DWORD PTR [eax+DATA_001703]','mov DWORD PTR [g_key_a_kind],eax']
  support.append('FUNC_%06d:\n'%n+trace(n)+'''push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
'''+ '\n'.join(loads)+f'''
mov edi,{n}
and rsp,-16
call g_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
''')
 entry='''
.global call_kernel
call_kernel:
mov [g_saved_rsp],rsp
mov esp,OFFSET FLAT:g_stack_end
mov eax,DWORD PTR [g_operation]
cmp eax,3
je g_read
cmp eax,2
je g_write
mov eax,OFFSET FLAT:FUNC_000044
cmp DWORD PTR [g_registration],0
je g_registration_ready
mov eax,OFFSET FLAT:FUNC_000045
g_registration_ready:
cmp DWORD PTR [g_operation],0
jne g_block
mov ecx,DWORD PTR [g_clause]
push rcx
push rax
push OFFSET FLAT:g_task+8
push OFFSET FLAT:g_entry_ip
call FUNC_000032
jmp g_called
g_block:
push rax
push OFFSET FLAT:g_task+8
call FUNC_000033
jmp g_called
g_write:
mov eax,DWORD PTR [g_value]
push rax
mov eax,DWORD PTR [g_index]
push rax
call FUNC_000034
jmp g_called
g_read:
mov eax,DWORD PTR [g_index]
push rax
call FUNC_000035
g_called:
mov rsp,[g_saved_rsp]
ret
g_abort:
mov edi,97
mov eax,60
syscall
'''
 aliases='DATA_008548=g_events+8\nDATA_001701=g_metadata+8\nDATA_001702=g_metadata+12\nDATA_001703=g_metadata+16\nDATA_001704=g_metadata+20\n'
 return '.intel_syntax noprefix\n.code64\n.section .text\n'+text+'\n'+entry+'\n'+'\n'.join(support)+'\n'+aliases+'''
.section .bss
.balign 16
g_stack: .zero 2097152
g_stack_end:
g_saved_rsp: .zero 8
.section .note.GNU-stack,"",@progbits
'''

HOST_C=r'''
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <setjmp.h>
#define GUARD UINT64_C(0x6d697373696f6e67)
#define CHECK(x) do{if(!(x)){fprintf(stderr,"guards-native:%d\n",__LINE__);exit(97);}}while(0)
#define PROGRAM 65536
#define CAP (32*1024*1024)
struct __attribute__((packed)) GuardedEvents{uint64_t a;uint8_t data[284];uint64_t b;}g_events;
struct __attribute__((packed)) GuardedTask{uint64_t a;uint8_t data[36];uint64_t b;}g_task;
struct __attribute__((packed)) GuardedMetadata{uint64_t a;uint8_t data[1088];uint64_t b;}g_metadata;
static struct{uint64_t a;uint8_t data[PROGRAM];uint64_t b;}program;
uint32_t g_operation,g_registration,g_clause,g_index,g_value,g_entry_ip,g_current_ip,g_args[6],g_trace[8192],g_trace_count,g_source_base,g_program_pointer,g_key_a_kind;
static uint32_t task_block_relocated;
static uint32_t base,length,slot,script_count,used,status,outpos;static uint8_t input[CAP],output[CAP],*cursor,*end;
static jmp_buf env;extern uint32_t call_kernel(void);
static uint32_t get(const void*p){uint32_t x;memcpy(&x,p,4);return x;}static void put(void*p,uint32_t x){memcpy(p,&x,4);}
static uint32_t ptr(const void*p){CHECK((uintptr_t)p<=0xffffffffu);return (uint32_t)(uintptr_t)p;}
static uint32_t read32(void){CHECK(cursor+4<=end);uint32_t v=get(cursor);cursor+=4;return v;}
static void bytes(void*p,uint32_t n){CHECK(cursor+n<=end);memcpy(p,cursor,n);cursor+=n;}
static void emit32(uint32_t v){CHECK(outpos+4<CAP);put(output+outpos,v);outpos+=4;}
static void emit(const void*p,uint32_t n){CHECK(outpos+n<CAP);memcpy(output+outpos,p,n);outpos+=n;}
static uint32_t source_ref(uint32_t value){return value>=ptr(program.data)&&value<ptr(program.data)+length?base+value-ptr(program.data):value;}
static uint32_t host_ref(uint32_t value){return value>=base&&value<base+length?ptr(program.data)+value-base:value;}
static void import_task(void){uint32_t value=get(g_task.data+8);task_block_relocated=value>=base&&value<base+length;put(g_task.data+8,host_ref(value));}
static void raw_task(uint8_t*task){memcpy(task,g_task.data,36);if(task_block_relocated)put(task+8,source_ref(get(task+8)));}
static void emit_context(void){
 uint32_t current=get((void*)(uintptr_t)g_current_ip);CHECK(current>=ptr(program.data)&&current<=ptr(program.data)+length);
 emit32(current-ptr(program.data));emit(g_events.data,284);uint8_t task[36];raw_task(task);emit(task,36);
}
static uint32_t norm_task(uint32_t value){return value==ptr(g_task.data)?0x60bf50u+slot*36:value;}
uint32_t g_observe(uint32_t kind){
 uint32_t argc=kind==31?1:kind==48?3:6,args[6]={0},result=0;
 if(kind==31){CHECK(g_args[1]==ptr(g_task.data));g_current_ip=g_args[0];args[0]=slot;}
 else{memcpy(args,g_args,argc*4);if(kind==44||kind==45){if(g_key_a_kind==2)args[1]=norm_task(args[1]);args[4]=norm_task(args[4]);}}
 uint32_t row=outpos;emit32(kind);emit32(argc);emit(args,24);emit32(0);emit_context();
 if(used>=script_count){emit_context();used++;status=1;longjmp(env,1);}
 uint32_t wanted=read32(),wanted_argc=read32(),wanted_args[6];bytes(wanted_args,24);result=read32();uint32_t next_ip=read32(),patches=read32();
 CHECK(wanted==kind&&wanted_argc==argc&&!memcmp(wanted_args,args,24)&&patches<=8);
 for(uint32_t i=0;i<patches;i++){uint32_t owner=read32(),offset=read32(),size=read32();uint8_t raw[64];bytes(raw,64);uint32_t count=owner==0?284:36;CHECK(owner<=1&&size<=64&&offset+size<=count);if(owner==0)memcpy(g_events.data+offset,raw,size);else{uint8_t task[36];raw_task(task);memcpy(task+offset,raw,size);memcpy(g_task.data,task,36);import_task();}}
 if(next_ip!=0xffffffffu){CHECK(next_ip<=length);put((void*)(uintptr_t)g_current_ip,ptr(program.data)+next_ip);}
 put(output+row+32,kind==31?result:0);emit_context();used++;return result;
}
int main(void){uint32_t size;
 while(fread(&size,4,1,stdin)==1){CHECK(size<CAP&&fread(input,1,size,stdin)==size);cursor=input;end=input+size;
  g_operation=read32();base=read32();length=read32();uint32_t ip=read32();slot=read32();g_registration=read32();g_clause=read32();g_index=read32();g_value=read32();script_count=read32();
  CHECK(g_operation<4&&length>0&&length<=PROGRAM&&ip<=length&&slot<150&&g_registration<2&&script_count<=256&&g_index<71);
  bytes(g_events.data,284);bytes(g_task.data,36);bytes(program.data,length);bytes(g_metadata.data,1088);import_task();
  g_events.a=g_events.b=g_task.a=g_task.b=g_metadata.a=g_metadata.b=program.a=program.b=GUARD;
  uint8_t program_before[PROGRAM],metadata_before[1088];memcpy(program_before,program.data,length);memcpy(metadata_before,g_metadata.data,1088);
  g_source_base=base;g_program_pointer=ptr(program.data);g_entry_ip=ptr(program.data)+ip;g_current_ip=ptr(&g_entry_ip);used=status=g_trace_count=0;outpos=40;uint32_t result=0;
  if(!setjmp(env)){result=call_kernel();if(g_operation==1)g_current_ip=ptr(&g_entry_ip);CHECK(used==script_count&&cursor==end);}
  CHECK(g_events.a==GUARD&&g_events.b==GUARD&&g_task.a==GUARD&&g_task.b==GUARD&&g_metadata.a==GUARD&&g_metadata.b==GUARD&&program.a==GUARD&&program.b==GUARD&&!memcmp(program_before,program.data,length)&&!memcmp(metadata_before,g_metadata.data,1088));
  uint32_t final_at=outpos;emit_context();uint32_t trace_at=outpos;emit(g_trace,g_trace_count*4);
  put(output,0x32333435);put(output+4,outpos);put(output+8,status);put(output+12,g_operation==3?result:0);put(output+16,used);put(output+20,final_at);put(output+24,trace_at);put(output+28,g_trace_count);put(output+32,g_operation==3);put(output+36,0);
  CHECK(fwrite(output,1,outpos,stdout)==outpos);
 }
 return 0;
}
'''

OPS=['F32','F33','F34','F35']
def packet(row):
 c=row['context_before'];args=row['args'];scripts=row.get('scripts',[]);op=OPS.index(row['operation']);reg=int(args[0]=='F45')if op<2 else 0;clause=args[1]if op==0 else 0;index=args[0]if op>=2 else 0;value=args[1]if op==2 else 0
 raw=struct.pack('<10I',op,c['program_base_u32'],len(bytes.fromhex(c['program'])),c['ip_u32'],c['task_slot_u32'],reg,clause,index,value,len(scripts))+bytes.fromhex(c['event_registers'])+bytes.fromhex(c['task_record'])+bytes.fromhex(c['program'])+bytes.fromhex(c['metadata'])
 for s in scripts:
  args=s['args'];patches=s.get('patches',[]);raw+=struct.pack('<11I',s['kind'],len(args),*args,*([0]*(6-len(args))),s['return_u32'],s['ip_after_u32'],len(patches))
  for p in patches:
   b=bytes.fromhex(p['hex']);raw+=struct.pack('<3I',p['owner'],p['offset'],len(b))+b.ljust(64,b'\0')
 return struct.pack('<I',len(raw))+raw

def compact_context(raw,base):
 c=copy.deepcopy(base);c['ip_u32']=struct.unpack_from('<I',raw)[0];c['event_registers']=raw[4:288].hex();c['task_record']=raw[288:324].hex();return c

def decode(raw,row):
 h=struct.unpack_from('<10I',raw);base=row['context_before']
 if h[0]!=0x32333435 or h[1]!=len(raw)or h[2]not in [0,1]or h[4]>256 or h[5]!=40+h[4]*684 or h[6]!=h[5]+324 or len(raw)!=h[6]+h[7]*4:raise ValueError(('Native guard output layout',row['name'],h))
 observations=[]
 for i in range(h[4]):
  at=40+i*684;kind,argc=struct.unpack_from('<2I',raw,at);observations.append({'kind':'F%d'%kind,'args':list(struct.unpack_from('<6I',raw,at+8))[:argc],'return_u32':struct.unpack_from('<I',raw,at+32)[0],'before':compact_context(raw[at+36:at+360],base),'after':compact_context(raw[at+360:at+684],base)})
 return {'status':h[2],'context_after':compact_context(raw[h[5]:h[6]],base),'return_u32':h[3],'return_defined':bool(h[8]),'source_order':['F%d'%n for n in struct.unpack_from('<%dI'%h[7],raw,h[6])],'observations':observations}

def cases(meta):
 rows=[];metadata=bytes.fromhex(meta['metadata_hex']);program_base=0x4801c4
 def context(program=b'\x02\x00\x00\x00\x00',slot=7,ip=0,task=None):
  if task is None:
   task=bytearray((i*7+3)&255 for i in range(36));struct.pack_into('<I',task,8,program_base);struct.pack_into('<I',task,28,0x48b238)
  return {'event_registers':bytes((i*13+7)&255 for i in range(284)).hex(),'program':program.hex(),'program_base_u32':program_base,'ip_u32':ip,'task_record':bytes(task).hex(),'task_slot_u32':slot,'metadata':metadata.hex()}
 def add(name,op,args,c=None,answers=None,policy=None):
  r={'name':name,'operation':op,'args':args,'context_before':c or context(),'f31_answers':answers or{},'policy':policy or{},'scripts':[]};rows.append(r);return r
 for token in range(68):
  count=struct.unpack_from('<i',metadata,token*16)[0];program=bytearray([token]);answers={}
  for i in range(count if count>0 else 0):
   at=len(program);value=(0x10203040+i*0x11111111)&0xffffffff;program+=bytes([2])+struct.pack('<I',value);answers[str(at)]={'return_u32':value,'ip_after_u32':at+5}
  if count<=0:program+=struct.pack('<I',0xffffffff if token%2 else token)
  add('all-metadata-selector-%02d'%token,'F32',['F45'if token%2 else'F44',token],context(program,149 if token%3==0 else 0),answers)
 for index in [0,1,2,70]:
  for value in [0,1,0x80000000,0xffffffff]:add('event-write-%d-%x'%(index,value),'F34',[index,value])
 for index in [0,1,2,70]:add('event-read-%d'%index,'F35',[index])
 for reg in ['F44','F45']:
  program=bytearray(160);struct.pack_into('<I',program,4,2);struct.pack_into('<II',program,8,program_base+64,program_base+96)
  program[64:69]=bytes([3])+struct.pack('<I',7);program[96:101]=bytes([6])+struct.pack('<I',3)
  add('two-clause-'+reg,'F33',[reg],context(program,149,ip=15))
  # Signed negative/zero counts bypass guards and retain the caller's unrelatedIP.
  for count in [0,0xffffffff,0x80000000]:
   empty=bytearray(program);struct.pack_into('<I',empty,4,count);add('signed-count-%s-%x'%(reg,count),'F33',[reg],context(empty,0,ip=15))
  # A first registration swaps task+8; next iteration must reread the new block.
  other=bytearray(program);struct.pack_into('<I',other,36,1)
  add('block-reread-'+reg,'F33',[reg],context(other,17,ip=15),policy={reg+':0':[{'owner':1,'offset':8,'hex':struct.pack('<I',program_base+32).hex()}]})
 # Register callback IP mutation is overridden by the original saved cursor.
 r=copy.deepcopy(rows[30]);r['name']='registration-rewind-overrides-provider-ip';r['scripts']=[];r['policy']={'F44:0':[]};r['policy_ip']={'F44:0':0};r['args']=['F44',7];rows.append(r)
 # Callback byte edits are carried exactly; they do not change readonly resources.
 add('event-callback-rewrites-event-word','F34',[70,0x12345678],policy={'F48:0':[{'owner':0,'offset':280,'hex':'efbeadde'},{'owner':1,'offset':28,'hex':'78563412'}]})
 # Parent operator: a first clause callback changes the descriptor token read
 # by the second child registration, while the first key remains its old value.
 program=bytes([10,5])+struct.pack('<I',2)+bytes([5])+struct.pack('<I',3)
 add('recursive-child-rereads-descriptor','F32',['F44',9],context(program),policy={'F44:0':[{'owner':1,'offset':28,'hex':'78563412'}]})
 return rows

def build(meta,source,folder):
 d=Path(folder);(d/'guards.s').write_text(assembly(source));(d/'host.c').write_text(HOST_C);binary=d/'native'
 subprocess.run(['gcc','-O1','-fno-pie','-no-pie','-fno-stack-protector','-Wl,-Ttext-segment=0x20000000','-o',str(binary),str(d/'guards.s'),str(d/'host.c')],check=True,capture_output=True)
 return binary

def run(binary,row):
 result=subprocess.run([str(binary)],input=packet(row),capture_output=True,timeout=30)
 if result.returncode or result.stderr:raise ValueError(('Native guard process failed',row['name'],result.returncode,result.stderr.decode(errors='replace')))
 return result.stdout

def fill(binary,row):
 counts={}
 for _ in range(257):
  raw=run(binary,row);decoded=decode(raw,row)
  if decoded['status']==0:return raw
  pending=decoded['observations'][-1];key=pending['kind']+':'+str(counts.get(pending['kind'],0));counts[pending['kind']]=counts.get(pending['kind'],0)+1
  answer=row['f31_answers'].get(str(pending['before']['ip_u32']),{})if pending['kind']=='F31'else{}
  if pending['kind']=='F31'and not answer:raise ValueError(('No authored F31 provider answer',row['name'],pending['before']['ip_u32']))
  row['scripts'].append({'kind':int(pending['kind'][1:]),'args':pending['args'],'return_u32':answer.get('return_u32',0),'ip_after_u32':row.get('policy_ip',{}).get(key,answer.get('ip_after_u32',0xffffffff)),'patches':row['policy'].get(key,[])})
 raise ValueError('Guard provider limit exceeded')

def generate(a):
 meta,source=reprove(a)if a.reprove_original else verify(a.proof_dir)
 with tempfile.TemporaryDirectory(prefix='mission-guards-native-')as directory:
  binary=build(meta,source,directory);rows=cases(meta);records=[];raws=[]
  for row in rows:
   raw=fill(binary,row)
   for _ in range(2):
    if run(binary,row)!=raw:raise ValueError('Fresh native guard execution differs')
   decoded=decode(raw,row);records.append({k:row[k]for k in ['name','operation','args','context_before']}|{'expected':{k:v for k,v in decoded.items()if k not in ['status','observations']},'observations':decoded['observations']});raws.append(raw)
  previous=copy.deepcopy(rows[68]['context_before'])
  for step in range(12):
   row={'name':'dependent-event-owner-%02d'%step,'operation':'F34'if step%2==0 else'F35','args':[70,(0xffffffff-step*0x1010101)&0xffffffff]if step%2==0 else[70],'context_before':copy.deepcopy(previous),'f31_answers':{},'policy':{},'scripts':[]}
   raw=fill(binary,row)
   for _ in range(2):
    if run(binary,row)!=raw:raise ValueError('Fresh dependent native guard execution differs')
   decoded=decode(raw,row);previous=decoded['context_after'];rows.append(row);records.append({k:row[k]for k in ['name','operation','args','context_before']}|{'expected':{k:v for k,v in decoded.items()if k not in ['status','observations']},'observations':decoded['observations']});raws.append(raw)
  cohort=subprocess.run([str(binary)],input=b''.join(packet(r)for r in reversed(rows)),capture_output=True,check=True,timeout=120)
  if cohort.stderr or cohort.stdout!=b''.join(reversed(raws)):raise ValueError('Reversed native guard cohort differs')
 doc={'schema':'starfrontier-mission-guards-native-v1','profile':PROFILE,'case_count':len(records),'fresh_process_runs':3,'reverse_repeat_cases':len(records),'consecutive_native_state_transitions':12,'original_source_executable_sha256':N.EXE_SHA,'original_source_assembly_sha256':N.ASM_SHA,'expected_arithmetic_calculated_in_python':False,'source_dependencies_sha256':{p:sha((PROJECT/p).read_bytes())for p in ['tools/rebuild_source_mission_guards_native.py','tools/rebuild_source_damage_native.py','tools/rebuild_source_natural_contact_native.py','tools/rebuild_source_surface_contact_native.py','tools/rebuild_source_atmospheric_native.py','tools/rebuild_ground_surface_native.py','recovered-history/ground_harness/tools/native_reference.py','recovered-history/ground_harness/tools/build_terrain_query_reference.py']},'proofs_sha256':{name:sha((a.proof_dir/name).read_bytes())for name in ['source-procedures.asm','instruction-proof.json','guards-native.s','guards-host.c','dos-disassembly.txt']},'provider_policy':'F31 authored return/cursor observations are external inputs. F44/F45/F48 providers may mutate only event/task bytes and active cursor. Original source code decides all registration order, keys, recursion, rewinds, F33 rereads and event register results.','cases':records}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(doc,indent=2)+'\n');print(json.dumps({'case_count':len(records),'fixture_sha256':sha(a.output.read_bytes()),'whole_procedures':len(meta['procedures']),'whole_instructions':sum(r['instruction_count']for r in meta['procedures'].values())},indent=2))

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--reprove-original',action='store_true');generate(p.parse_args())
