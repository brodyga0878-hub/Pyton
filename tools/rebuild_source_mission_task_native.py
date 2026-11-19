#!/usr/bin/env python3
"""Whole uploaded-DOS F38/F47/F52/F53 lifecycle instruction oracle.

F38 and F47 intentionally preserve the uploaded DOS bodies, whose admission
guards differ from the later JJFFE listing. External expression/store/statement
and registration/allocation workers are exact typed input continuations.
"""
from __future__ import annotations
import argparse,base64,copy,hashlib,inspect,json,re,struct,subprocess,tempfile,zlib
from pathlib import Path
import rebuild_source_damage_native as H
N=H.N;PROJECT=N.PROJECT
PROOF=PROJECT/'validation/mission-tasks-2026-11-19/task-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_mission_task_native.json'
PROFILE='dos-firstenc-mission-task-v1'
NUMBERS=[38,47,52,53];OPS=['F38','F47','F52','F53'];MASK=0xffffffff
sha=H.sha;_compile32=N.C.compile32

DOS_F47='''FUNC_000047: ; Pos = 14018
 push ebp
 mov ebp,esp
 push ecx
 push ebx
 mov ebx,[ebp+0x8]
 cmp dword [ebx],byte +0x1
 jnz JUMP_000473
 mov eax,[ebx+0x8]
 mov edx,[ebp+0xc]
 mov eax,[eax+edx*4+0x8]
 mov [ebp-0x4],eax
 push ebx
 lea eax,[ebp-0x4]
 push eax
 call FUNC_000031
 add esp,byte +0x8
 test eax,eax
 jz JUMP_000473
 mov dword [ebx],0x2
 push ebx
 lea eax,[ebp-0x4]
 push eax
 call FUNC_000041
 add esp,byte +0x8
 cmp dword [ebx],byte +0x2
 jnz JUMP_000473
 mov dword [ebx],0x1
JUMP_000473:
 pop ebx
 pop ecx
 pop ebp
 ret
'''
def compile32(body,aliases,entry,address):
 return _compile32(re.sub(r'push dword (FUNC_\d+)',r'push OFFSET FLAT:\1',body),aliases,entry,address)
def reprove(a):
 exe=a.exe.read_bytes();source=a.asm.read_text();data=a.data.read_text()
 if sha(exe)!=N.EXE_SHA or sha(a.asm.read_bytes())!=N.ASM_SHA:raise ValueError('Original source identity differs')
 source=source.replace(N.G.block(source,47),DOS_F47+'\n\n')
 guard='\t\tcmp dword [ebx],byte +0x0\n\t\tjng JUMP_000356\n\t\tcmp dword [ebx],byte +0x5\n\t\tjnl JUMP_000356\n'
 if source.count(guard)!=1:raise ValueError('Later F38 state guard changed')
 source=source.replace(guard,'')
 method=inspect.getsource(N.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_000038',0x412ab0)\n bind('FUNC_000047',0x413ff4)\n bind('FUNC_000052',0x4141c0)\n bind('FUNC_000053',0x41423c)")
 method=method.replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
 ns=N.__dict__.copy();exec(method,ns);N.C.compile32=compile32
 try:bodies,records,dis,_,aliases=ns['proof'](source,data,exe,a.exe,NUMBERS)
 finally:N.C.compile32=_compile32
 captured='\n'.join(bodies[n]for n in NUMBERS)+'\nFUNC_999999:\nret\n'
 for row in records.values():
  row['hex']=exe[row['executable_offset']:row['executable_offset']+row['byte_length']].hex()
  row['entry_anchor']='Known uploaded-DOS entry verified by complete independent instruction equality; see call/pointer evidence.'
 if aliases['DATA_008561']!=0x60bf50 or aliases['DATA_001697']!=0x48e0f8:raise ValueError('Actual lifecycle memory binding differs')
 image=N.G.Image(exe);anchors={}
 old=json.loads((PROJECT/'validation/events-messages-2026-11-18/events-native-proof/instruction-proof.json').read_text())
 for callee,caller,begin,end in [(38,41,0x412c38,0x413d98),(52,55,old['procedures']['55']['virtual_address'],old['procedures']['55']['virtual_address']+old['procedures']['55']['byte_length']),(53,54,old['procedures']['54']['virtual_address'],old['procedures']['54']['virtual_address']+old['procedures']['54']['byte_length'])]:
  wanted=records[str(callee)]['virtual_address'];sites=[]
  for address in range(begin,end-4):
   at=image.offset(address,5)
   if exe[at]==0xe8 and (address+5+struct.unpack_from('<i',exe,at+1)[0])&MASK==wanted:
    rows=N.C.original_rows(a.exe,address,count=1)
    if len(rows)==1 and rows[0][1]=='call':sites.append({'caller':'F%d'%caller,'call_va_u32':address,'target_va_u32':wanted,'hex':exe[at:at+5].hex()})
  if not sites:raise ValueError('Original lifecycle entry has no reviewed call anchor')
  anchors['F%d'%callee]=sites
 guard=json.loads((PROJECT/'validation/mission-expressions-2026-11-18/guards-native-proof/instruction-proof.json').read_text())
 raw32=bytes.fromhex(guard['procedures']['32']['hex']);start=guard['procedures']['32']['virtual_address'];needle=b'\x68'+struct.pack('<I',0x413ff4);at=raw32.find(needle)
 if at<0 or exe[image.offset(start+at,5):image.offset(start+at,5)+5]!=needle:raise ValueError('Original F47 function-word anchor differs')
 anchors['F47']=[{'caller':'F32','push_va_u32':start+at,'function_word_u32':0x413ff4,'hex':needle.hex()}]
 meta={'schema':'starfrontier-mission-task-original-proof-v1','source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'procedures':records,'bindings':aliases,'entry_anchor_evidence':anchors,'source_procedures_sha256':sha(captured.encode()),'all_whole_instructions_equal':True,'whole_procedure_count':4,'whole_instruction_count':sum(r['instruction_count']for r in records.values()),'source_variants':[{'procedure':'F38','uploaded_DOS':'Compare packed handle only; no state1..4 admission guard.','later_JJFFE':'Adds two state comparisons and branches.'},{'procedure':'F47','uploaded_DOS':'State1 gate followed by unchecked clause-pointer load; no declared-count comparison.','later_JJFFE':'Adds clause-count guard and reordered pointer loads.'}],'host_adaptations':['Original cdecl four-byte argument positions become eight-byte host stack slots; source locals remain exact low-address offsets.','Read-only program bytes are never rewritten; five reviewed resource-pointer load sites translate only source resource addresses to the fixed host program window.','The host program owner is placed at0x60000000 (data0x60000008), so opaque-word collision controls are deterministic, not compiler-layout-dependent.','Arena fields+8/+16/+28 use field provenance during source/host translation; task+20 remains an uninterpreted u32 variable token.','Native callback results normalize physical F51 allocation pointers to slot0..149 orFFFFFFFF=NULL; valid F52 handle0 is a defined scalar.','Each F31/F37/F41 continuation records its real private cursor independently from the persistent F52 caller cursor. F33/F51 have no cursor argument.','Semantically unconsumed EAX values from void workers are excluded; original F52 NULL allocation fault is verified separately without an after-state.'],'transport_scope':'Original resource VA tokens and arena slots; opaque task+20 variable IDs are not dereferenced or relocated by this kernel. Typed external providers own all Root/heap/world effects.','scope':'Whole uploaded DOS F38/F47/F52/F53 with explicitly observed F31/F37/F41/F51/F33. No full F41 statement VM, world services or Main claim.'}
 a.proof_dir.mkdir(parents=True,exist_ok=True)
 (a.proof_dir/'source-procedures.asm').write_text(captured);(a.proof_dir/'instruction-proof.json').write_text(json.dumps(meta,indent=2)+'\n');(a.proof_dir/'dos-disassembly.txt').write_text('\n'.join(dis.values()))
 (a.proof_dir/'task-native.s').write_text(assembly(captured));(a.proof_dir/'task-host.c').write_text(HOST_C)
 return meta,captured
def verify(proof=PROOF):
 meta=json.loads((proof/'instruction-proof.json').read_text());source=(proof/'source-procedures.asm').read_text()
 if meta['source_executable_sha256']!=N.EXE_SHA or sha(source.encode())!=meta['source_procedures_sha256']:raise ValueError('Archived lifecycle proof differs')
 for n in NUMBERS:
  row=meta['procedures'][str(n)];compiled=N.C.J.instructions(compile32(N.G.block(source,n),meta['bindings'],'FUNC_%06d'%n,row['virtual_address']))
  if sha(bytes.fromhex(row['hex']))!=row['sha256']or len(compiled)!=row['instruction_count']or sha('\n'.join(N.canonical(compiled)).encode())!=row['normalized_instruction_sha256']:raise ValueError('Original lifecycle instructions differ')
 for name,entries in meta['entry_anchor_evidence'].items():
  target=meta['procedures'][name[1:]]['virtual_address']
  for entry in entries:
   raw=bytes.fromhex(entry['hex'])
   if 'call_va_u32'in entry:
    if len(raw)!=5 or raw[0]!=0xe8 or(entry['call_va_u32']+5+struct.unpack_from('<i',raw,1)[0])&MASK!=target:raise ValueError('Captured lifecycle call anchor differs')
   elif raw!=b'\x68'+struct.pack('<I',target):raise ValueError('Captured lifecycle function-word anchor differs')
 if meta['bindings']['DATA_008561']!=0x60bf50 or meta['bindings']['DATA_001697']!=0x48e0f8:raise ValueError('Captured lifecycle owner binding differs')
 if (proof/'task-native.s').read_text()!=assembly(source)or(proof/'task-host.c').read_text()!=HOST_C:raise ValueError('Lifecycle ABI adaptation differs')
 return meta,source

def trace(n):
 regs=['rax','rbx','rcx','rdx','rsi','rdi','r8','r9','r10','r11','r12']
 return '\n'.join(['pushfq']+['push '+r for r in regs]+['mov edi,%d'%n,'mov r12,rsp','and rsp,-16','call t_trace','mov rsp,r12']+['pop '+r for r in reversed(regs)]+['popfq'])+'\n'
def relocate_eax():
 return 'call t_translate_eax\n'
def assembly(source):
 lines,_=N.Q.procedures(source,NUMBERS);text='\n'.join(lines)
 text=re.sub(r'\[rbp[^\]]*\]',lambda m:re.sub(r'\b(eax|ebx|ecx|edx|esi|edi)\b',lambda r:'r'+r[1][1:],m[0]),text)
 text=re.sub(r'(,\s*)(DATA_\d+|FUNC_\d+)$',r'\1OFFSET FLAT:\2',text,flags=re.M)
 text=text.replace('push dword FUNC_000045','push 45').replace('push dword FUNC_000044','push 44')
 # These are precisely the source loads of resource pointers. No program
 # bytes are rewritten and no scalar data is treated as a host address.
 markers=['mov eax,[eax+edx*4+0x8]','mov eax,[eax+esi*4+0x8]','mov eax,[eax+0x1c]']
 for marker in markers:
  if text.count(marker)!=1:raise ValueError('Lifecycle pointer-load site differs: '+marker)
  text=text.replace(marker,marker+'\n'+relocate_eax())
 # Both F52 argument-target and F53 initialization pointers are loaded here.
 marker='mov eax,[eax]'
 if text.count(marker)!=2:raise ValueError('Lifecycle direct resource-pointer loads differ')
 text=text.replace(marker,marker+'\n'+relocate_eax())
 for n in NUMBERS:text=text.replace('FUNC_%06d:\n'%n,'FUNC_%06d:\n'%n+trace(n),1)
 text=text.replace('JUMP_000490:','JUMP_000490:\n'+trace(53000),1)
 bridges=[]
 for n,argc in [(31,2),(37,3),(41,2),(51,2),(33,2)]:
  loads=['mov eax,DWORD PTR [rbp+%d]\nmov DWORD PTR [t_args+%d],eax'%(16+i*8,i*4)for i in range(argc)]
  bridges.append('FUNC_%06d:\n'%n+trace(n)+'''push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
'''+ '\n'.join(loads)+f'''
mov edi,{n}
and rsp,-16
call t_observe
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
mov [t_saved_rsp],rsp
mov esp,OFFSET FLAT:t_stack_end
mov eax,DWORD PTR [t_operation]
test eax,eax
jz t_cancel
cmp eax,1
je t_callback
cmp eax,2
je t_create
mov eax,DWORD PTR [t_command]
imul eax,eax,36
add eax,OFFSET FLAT:t_arena+8
push rax
call FUNC_000053
jmp t_called
t_cancel:
mov eax,DWORD PTR [t_command]
push rax
call FUNC_000038
jmp t_called
t_callback:
mov eax,DWORD PTR [t_command+4]
push rax
mov eax,DWORD PTR [t_command]
imul eax,eax,36
add eax,OFFSET FLAT:t_arena+8
push rax
call FUNC_000047
jmp t_called
t_create:
mov eax,DWORD PTR [t_command+8]
push rax
mov eax,DWORD PTR [t_command+4]
push rax
mov eax,DWORD PTR [t_command]
cmp eax,0xffffffff
je t_null_task
imul eax,eax,36
add eax,OFFSET FLAT:t_arena+8
jmp t_task_ready
t_null_task:
xor eax,eax
t_task_ready:
push rax
xor eax,eax
cmp DWORD PTR [t_caller_ip],0
je t_null_cursor
mov eax,OFFSET FLAT:t_caller_ip
t_null_cursor:
push rax
call FUNC_000052
t_called:
mov rsp,[t_saved_rsp]
ret
t_translate_eax:
pushfq
push r11
cmp eax,DWORD PTR [t_base]
jb t_translate_done
mov r11d,DWORD PTR [t_base]
add r11d,DWORD PTR [t_length]
cmp eax,r11d
ja t_translate_done
sub eax,DWORD PTR [t_base]
add eax,DWORD PTR [t_program_ptr]
t_translate_done:
pop r11
popfq
ret
'''
 return '.intel_syntax noprefix\n.code64\n.section .text\n'+text+'\n'+entry+'\n'+'\n'.join(bridges)+'''
DATA_008561=t_arena+8
DATA_001697=t_module_table
.section .bss
.balign 16
t_stack: .zero 2097152
t_stack_end:
t_saved_rsp: .zero 8
.section .note.GNU-stack,"",@progbits
'''

HOST_C=r'''
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <setjmp.h>
#define CAP (64*1024*1024)
#define PROGRAM 65536
#define GUARD UINT64_C(0x7461736b6e617469)
#define CHECK(x) do{if(!(x)){fprintf(stderr,"task-native:%d\n",__LINE__);exit(97);}}while(0)
struct __attribute__((packed)){uint64_t a;uint8_t data[5400];uint64_t b;}t_arena;
static struct{uint64_t a;uint8_t data[PROGRAM];uint64_t b;}program __attribute__((section(".task_program_owner")));
uint32_t t_operation,t_command[4],t_base,t_program_ptr,t_caller_ip,t_module_table[256],t_args[4],t_length;
static uint32_t refs[256],length,script_count,used,status,outpos,trace_count,steps;
static uint32_t trace_words[16384],field_raw[150][3],field_host[150][3];static uint8_t field_kind[150][3];
static uint8_t input[CAP],output[CAP],*cursor,*end;static jmp_buf env;
extern uint32_t call_kernel(void);
static uint32_t get(const void*p){uint32_t x;memcpy(&x,p,4);return x;}
static void put(void*p,uint32_t x){memcpy(p,&x,4);}
static uint32_t ptr(const void*p){CHECK((uintptr_t)p<=0xffffffffu);return(uint32_t)(uintptr_t)p;}
static uint32_t read32(void){CHECK(cursor+4<=end);uint32_t x=get(cursor);cursor+=4;return x;}
static void bytes(void*p,uint32_t n){CHECK(cursor+n<=end);memcpy(p,cursor,n);cursor+=n;}
static void emit32(uint32_t x){CHECK(outpos+4<CAP);put(output+outpos,x);outpos+=4;}
static void emit(const void*p,uint32_t n){CHECK(outpos+n<CAP);memcpy(output+outpos,p,n);outpos+=n;}
static uint32_t is_source(uint32_t p){return p>=t_base&&p<=t_base+length;}
static uint32_t is_host(uint32_t p){return p>=t_program_ptr&&p<=t_program_ptr+length;}
static uint32_t tohost(uint32_t p){return is_source(p)?t_program_ptr+p-t_base:p;}
static uint32_t source(uint32_t p){return is_host(p)?t_base+p-t_program_ptr:p;}
static const uint32_t fields[3]={8,16,28};
static void import_arena(void){for(uint32_t i=0;i<150;i++)for(uint32_t j=0;j<3;j++){uint8_t*p=t_arena.data+i*36+fields[j];uint32_t v=get(p);field_raw[i][j]=v;field_kind[i][j]=is_source(v);field_host[i][j]=tohost(v);put(p,field_host[i][j]);}}
static void raw_arena(uint8_t*out){memcpy(out,t_arena.data,5400);for(uint32_t i=0;i<150;i++)for(uint32_t j=0;j<3;j++){uint8_t*p=out+i*36+fields[j];uint32_t v=get(p);if(is_host(v)&&(field_kind[i][j]||v!=field_host[i][j]))put(p,source(v));}}
static uint32_t offset(uint32_t p){if(!p)return 0xffffffffu;CHECK(p>=t_program_ptr&&p<=t_program_ptr+length);return p-t_program_ptr;}
static void emit_context(void){emit32(offset(t_caller_ip));uint8_t arena[5400];raw_arena(arena);emit(arena,5400);}
static uint32_t slot(uint32_t p){if(!p)return 0xffffffffu;CHECK(p>=ptr(t_arena.data)&&p<ptr(t_arena.data)+5400&&(p-ptr(t_arena.data))%36==0);return(p-ptr(t_arena.data))/36;}
void t_trace(uint32_t n){CHECK(trace_count<16384);if(n==53000){CHECK(++steps<=1024);return;}trace_words[trace_count++]=n;}
uint32_t t_observe(uint32_t kind){
 uint32_t argc=kind==37||kind==51||kind==33?2:1,args[4]={0},cursor_kind=0,ip_pointer=0;
 if(kind==31||kind==41){args[0]=slot(t_args[1]);ip_pointer=t_args[0];cursor_kind=kind==31&&t_operation==2?1:3;}
 else if(kind==37){args[0]=slot(t_args[1]);args[1]=t_args[2];ip_pointer=t_args[0];cursor_kind=2;}
 else if(kind==51){args[0]=t_args[0];args[1]=t_args[1];}
 else{CHECK(kind==33);args[0]=slot(t_args[0]);args[1]=t_args[1];}
 uint32_t before=cursor_kind?offset(get((void*)(uintptr_t)ip_pointer)):0xffffffffu;
 uint32_t row=outpos;emit32(kind);emit32(argc);emit(args,16);emit32(0);emit32(cursor_kind);emit32(before);emit32(before);emit_context();
 if(used>=script_count){emit_context();used++;status=1;longjmp(env,1);}
 uint32_t wanted=read32(),wanted_argc=read32(),wanted_args[4];bytes(wanted_args,16);uint32_t result=read32(),wanted_cursor=read32(),after=read32(),patches=read32();
 CHECK(kind==wanted&&argc==wanted_argc&&!memcmp(args,wanted_args,16)&&cursor_kind==wanted_cursor&&patches<=32);
 for(uint32_t i=0;i<patches;i++){uint32_t at=read32(),size=read32();uint8_t data[64];bytes(data,64);CHECK(size<=64&&at+size<=5400);uint8_t arena[5400];raw_arena(arena);memcpy(arena+at,data,size);memcpy(t_arena.data,arena,5400);import_arena();}
 if(cursor_kind){CHECK(after<=length);put((void*)(uintptr_t)ip_pointer,t_program_ptr+after);}else CHECK(after==0xffffffffu);
 put(output+row+24,kind==31||kind==51?result:0);put(output+row+36,after);emit_context();used++;
 if(kind==51){if(result==0xffffffffu)return 0;CHECK(result<150);return ptr(t_arena.data)+result*36;}
 return result;
}
int main(void){uint32_t size;
 while(fread(&size,4,1,stdin)==1){CHECK(size<CAP&&fread(input,1,size,stdin)==size);cursor=input;end=input+size;
  t_operation=read32();bytes(t_command,16);t_base=read32();length=read32();t_length=length;uint32_t caller=read32(),count=read32();CHECK(t_operation<4&&length>0&&length<=PROGRAM&&t_base+length>t_base&&count<=256);
  memset(refs,0,sizeof refs);memset(t_module_table,0,sizeof t_module_table);for(uint32_t i=0;i<count;i++){uint32_t id=read32(),ref=read32();CHECK(id<256);refs[id]=ref;}
  bytes(t_arena.data,5400);bytes(program.data,length);t_program_ptr=ptr(program.data);for(uint32_t i=0;i<256;i++)if(refs[i]){CHECK(is_source(refs[i]));t_module_table[i]=tohost(refs[i]);}
  import_arena();t_caller_ip=caller==0xffffffffu?0:t_program_ptr+caller;CHECK(caller==0xffffffffu||caller<=length);script_count=read32();CHECK(script_count<=256);
  t_arena.a=t_arena.b=program.a=program.b=GUARD;uint8_t before_program[PROGRAM];memcpy(before_program,program.data,length);
  trace_count=used=status=steps=0;outpos=40;uint32_t result=0;
  if(!setjmp(env)){result=call_kernel();CHECK(used==script_count&&cursor==end);}
  CHECK(t_arena.a==GUARD&&t_arena.b==GUARD&&program.a==GUARD&&program.b==GUARD&&!memcmp(before_program,program.data,length));
  uint32_t final=outpos;emit_context();uint32_t trace_at=outpos;emit(trace_words,trace_count*4);
  put(output,0x38475253);put(output+4,outpos);put(output+8,status);put(output+12,t_operation==2?result:0);put(output+16,used);put(output+20,final);put(output+24,trace_at);put(output+28,trace_count);put(output+32,t_operation==2);put(output+36,0);
  CHECK(fwrite(output,1,outpos,stdout)==outpos);
 }
 return 0;
}
'''

CURSORS=['none','caller','callee','local']
def packet(row):
 c=row['context_before'];args=[x&MASK for x in row['args']];scripts=row.get('scripts',[])
 raw=struct.pack('<8I',OPS.index(row['operation']),*args,*([0]*(4-len(args))),c['program_base_u32'],len(bytes.fromhex(c['program'])),c['caller_ip_u32'])
 raw+=struct.pack('<I',len(c['module_refs']))
 for key,value in c['module_refs'].items():raw+=struct.pack('<2I',int(key),value)
 raw+=bytes.fromhex(c['arena'])+bytes.fromhex(c['program'])+struct.pack('<I',len(scripts))
 for script in scripts:
  values=[x&MASK for x in script['args']];patches=script.get('patches',[])
  raw+=struct.pack('<10I',script['kind'],len(values),*values,*([0]*(4-len(values))),script['return_u32'],CURSORS.index(script['cursor_kind']),script['cursor_after_u32'],len(patches))
  for patch in patches:
   b=bytes.fromhex(patch['hex']);raw+=struct.pack('<2I',patch['offset'],len(b))+b.ljust(64,b'\0')
 return struct.pack('<I',len(raw))+raw
def compact_context(raw,base):
 result=copy.deepcopy(base);result['caller_ip_u32']=struct.unpack_from('<I',raw)[0];result['arena']=raw[4:5404].hex();return result
def decode(raw,row):
 h=struct.unpack_from('<10I',raw);base=row['context_before'];stride=40+5404*2
 if h[0]!=0x38475253 or h[1]!=len(raw)or h[2]not in[0,1]or h[5]!=40+h[4]*stride or h[6]!=h[5]+5404 or len(raw)!=h[6]+h[7]*4:raise ValueError(('Native lifecycle output differs',row['name'],h))
 observations=[]
 for index in range(h[4]):
  at=40+index*stride;kind,argc=struct.unpack_from('<2I',raw,at);kind_name='F%d'%kind;values=list(struct.unpack_from('<4I',raw,at+8))[:argc]
  observations.append({'kind':kind_name,'args':values,'return_u32':struct.unpack_from('<I',raw,at+24)[0],'cursor_kind':CURSORS[struct.unpack_from('<I',raw,at+28)[0]],'cursor_before_u32':struct.unpack_from('<I',raw,at+32)[0],'cursor_after_u32':struct.unpack_from('<I',raw,at+36)[0],'before':compact_context(raw[at+40:at+5444],base),'after':compact_context(raw[at+5444:at+10848],base)})
 return {'status':h[2],'context_after':compact_context(raw[h[5]:h[6]],base),'return_u32':h[3],'return_defined':bool(h[8]),'source_order':['F%d'%n for n in struct.unpack_from('<%dI'%h[7],raw,h[6])],'observations':observations}
def build(source,folder):
 folder=Path(folder);native=assembly(source);(folder/'native.s').write_text(native);(folder/'host.c').write_text(HOST_C);binary=folder/'native'
 subprocess.run(['gcc','-O1','-fno-pie','-no-pie','-fno-stack-protector','-Wl,--section-start=.task_program_owner=0x60000000','-o',str(binary),str(folder/'native.s'),str(folder/'host.c')],check=True)
 return binary,native
def run(binary,row):return subprocess.run([str(binary)],input=packet(row),stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30)
def run_raw(binary,row):
 done=run(binary,row)
 if done.returncode or done.stderr:raise ValueError(('Native lifecycle run failed',row['name'],done.returncode,done.stderr[:200]))
 return done.stdout
def hydrate_context(doc,value):
 result=copy.deepcopy(value)
 for key in ['arena','program']:
  entry=doc['buffer_pool'][result[key]];raw=zlib.decompress(base64.b64decode(entry['zlib_base64']))
  if len(raw)!=entry['byte_count']or sha(raw)!=result[key]:raise ValueError('Pooled lifecycle owner bytes differ')
  result[key]=raw.hex()
 return result

def bytes_patch(offset,raw):return {'offset':offset,'hex':bytes(raw).hex()}
def word_patch(offset,value):return bytes_patch(offset,struct.pack('<I',value&MASK))
def task_bytes(slot,state=1,generation=3,module=0,descriptor=0x4802c4,block=0x4804c4):
 data=bytearray(36);struct.pack_into('<IHH7I',data,0,state&MASK,slot,generation,block,MASK,block,0,module,descriptor,1);return data
def synthetic_context(slot=7,state=1,generation=3,cleanup=-1,count=2,argc=0,caller=16):
 base=0x4801c4;program=bytearray(1024);arena=bytearray(5400)
 # Four real-shape descriptors and four blocks allow callback retarget/rereads.
 for module in range(4):
  at=0x100+module*64;block=0x300+module*64
  struct.pack_into('<7I',program,at,base+0x200,0,argc if module==0 else 0,cleanup&MASK if module==0 else (0 if module==1 else MASK),4,0,0)
  struct.pack_into('<I',program,at+28,base+block)
  struct.pack_into('<2I',program,block,base+0x10+module*4,(count if module==0 else (1 if module==1 else 0))&MASK)
  for index in range(8):struct.pack_into('<I',program,block+8+index*4,base+0x50+index*8)
 for at in range(0x10,0x100,8):program[at:at+5]=b'\x02\x01\x00\x00\x00'
 program[0x200:0x220]=b'\x06\x02\x00\x00\x00'*6+b'\x00\x00'
 arena[slot*36:slot*36+36]=task_bytes(slot,state,generation)
 return {'arena':arena.hex(),'program':program.hex(),'program_base_u32':base,'module_refs':{str(i):base+0x100+i*64 for i in range(4)},'caller_ip_u32':caller}
def cases():
 rows=[]
 def add(name,operation,args,ctx=None,policy=None):
  row={'name':name,'operation':operation,'args':args,'context_before':ctx or synthetic_context(),'policy':policy or {},'scripts':[]};rows.append(row);return row
 for state in [0,1,2,3,4,5,6,7,0xffffffff,0x80000000]:
  for cleanup in [-1,0]:
   for active in [False,True]:
    c=synthetic_context(state=state,cleanup=cleanup)
    if not active:
     a=bytearray.fromhex(c['arena']);struct.pack_into('<I',a,7*36+8,0);c['arena']=a.hex()
    add('cancel-state-%08x-cleanup%d-block%d'%(state,cleanup,active),'F38',[(3<<16)|7],c)
 for slot in [0,1,149]:
  for gen in [0,1,0xffff]:
   c=synthetic_context(slot=slot,generation=gen)
   add('cancel-generation-%d-%d'%(slot,gen),'F38',[(gen<<16)|slot],c)
   add('cancel-stale-%d-%d'%(slot,gen),'F38',[(((gen+1)&65535)<<16)|slot],copy.deepcopy(c))
 c=synthetic_context();add('cancel-unregister-changes-descriptor','F38',[(3<<16)|7],c,{'F33':{'patches':[word_patch(7*36+28,c['program_base_u32']+0x140)]}})
 c=synthetic_context();add('cancel-unregister-changes-generation','F38',[(3<<16)|7],c,{'F33':{'patches':[bytes_patch(7*36+6,b'\xff\xff')]}})
 c=synthetic_context();add('cancel-unregister-state-overridden','F38',[(3<<16)|7],c,{'F33':{'patches':[word_patch(7*36,0xdeadbeef)]}})
 for state in [0,1,2,3,5,6,0xffffffff]:
  for answer in [0,1,MASK]:add('callback-state-%08x-answer-%x'%(state,answer),'F47',[7,0],synthetic_context(state=state),{'F31':{'return_u32':answer}})
 for count,clause in [(-1,0),(0,0),(1,1),(1,2),(2,2),(4,3)]:
  add('callback-unchecked-count-%d-clause%d'%(count,clause),'F47',[7,clause],synthetic_context(count=count),{'F31':{'return_u32':1}})
 for state in [0,1,2,3,4,5,6,MASK]:
  add('callback-F41-state-%x'%state,'F47',[7,1],policy={'F31':{'return_u32':1},'F41':{'patches':[word_patch(7*36,state)]}})
 add('callback-F31-state-is-overridden','F47',[7,0],policy={'F31':{'return_u32':1,'patches':[word_patch(7*36,5)]}})
 for slot,gen in [(0,0xffff),(0,0),(7,3),(149,0xffff)]:
  for argc in [0,1,2,4]:
   c=synthetic_context(argc=argc,caller=32);a=bytearray.fromhex(c['arena']);a[slot*36:slot*36+36]=bytes(36);c['arena']=a.hex()
   add('create-slot%d-gen%d-argc%d'%(slot,gen,argc),'F52',[7,0,0x12345678],c,{'allocation_slot':slot,'allocation_generation':gen})
 for caller_slot,caller_ip in [(-1,MASK),(-1,16),(7,MASK),(7,0)]:
  c=synthetic_context(argc=0,caller=caller_ip);add('create-empty-nullability-%d-%x'%(caller_slot,caller_ip),'F52',[caller_slot,0,MASK],c,{'allocation_slot':149,'allocation_generation':0xffff})
 c=synthetic_context(argc=2);add('create-caller-state-mutations','F52',[7,0,9],c,{'allocation_slot':17,'allocation_generation':6,'F31':{'patches':[word_patch(7*36,6)]}})
 c=synthetic_context(argc=2);add('create-callee-state-mutations','F52',[7,0,9],c,{'allocation_slot':17,'allocation_generation':6,'F37':{'patches':[word_patch(17*36,2)]}})
 for count in [-1,0,1,2,3]:
  for active in [False,True]:
   c=synthetic_context(state=4,count=count)
   if not active:
    a=bytearray.fromhex(c['arena']);struct.pack_into('<I',a,7*36+8,0);c['arena']=a.hex()
   add('schedule-count%d-oldblock%d'%(count,active),'F53',[7],c)
 for state in [0,1,2,4,5,6,MASK]:
  add('schedule-initializer-stops-state%x'%state,'F53',[7],synthetic_context(state=4),{'initial_state':state})
 add('schedule-rescan-starts-one','F53',[7],synthetic_context(state=4,count=3),{'rescan':True})
 add('schedule-F31-state-change-still-executes-F41','F53',[7],synthetic_context(state=4),{'F31':{'return_u32':1,'patches':[word_patch(7*36,5)]},'F41_after_condition_state':6})
 c=synthetic_context(state=4);add('schedule-unregister-retargets-current-block','F53',[7],c,{'F33_first':{'patches':[word_patch(7*36+16,c['program_base_u32']+0x340)]}})
 c=synthetic_context(state=4,count=3);add('schedule-F31-retargets-current-block','F53',[7],c,{'F31_first':{'patches':[word_patch(7*36+16,c['program_base_u32']+0x340)]}})
 add('schedule-registration-state-final-overwrite','F53',[7],synthetic_context(state=4,count=0),{'F33_register':{'patches':[word_patch(7*36,5)]}})
 # Actual descriptor/initialization/condition pointers, without asserting that
 # the external F31/F41 bodies have run in this standalone kernel.
 resource=json.loads((PROJECT/'data/ffe_mission_programs.json').read_text());base=resource['regions']['mission']['original_va_u32'];program=resource['regions']['mission']['hex']
 refs={str(m['module_index_u32']):base+m['descriptor_offset_u32']for m in resource['modules']}
 for module in resource['modules']:
  index=module['module_index_u32'];slot=index%150;block=base+module['block_offsets_u32'][0];a=bytearray(5400);a[slot*36:slot*36+36]=task_bytes(slot,4,3,index,refs[str(index)],block)
  c={'arena':a.hex(),'program':program,'program_base_u32':base,'module_refs':refs,'caller_ip_u32':MASK}
  add('original-module-%03d-initialization'%index,'F53',[slot],c)
 return rows

def choose_script(row,pending):
 kind=pending['kind'];policy=row['policy'];script={'kind':int(kind[1:]),'args':pending['args'],'return_u32':0,'cursor_kind':pending['cursor_kind'],'cursor_after_u32':pending['cursor_before_u32'],'patches':[]}
 count=sum(s['kind']==script['kind']for s in row['scripts'])
 if kind=='F51':
  slot=policy.get('allocation_slot',17);generation=(policy.get('allocation_generation',3)+1)&65535;module=script['args'][0];base=row['context_before']['program_base_u32'];ref=row['context_before']['module_refs'][str(module)]
  task=task_bytes(slot,4,generation,module,ref,0);struct.pack_into('<I',task,16,0);struct.pack_into('<I',task,20,MASK)
  script['return_u32']=slot;script['patches']=[bytes_patch(slot*36,task)]
 elif kind=='F31':
  script['return_u32']=(0x10000+count*0x1001)&MASK if row['operation']=='F52' else 0
  script['cursor_after_u32']=pending['cursor_before_u32']+5
  if policy.get('rescan'):
   ip=pending['cursor_before_u32'];earlier=sum(s['kind']==31 and s.get('source_cursor')==ip for s in row['scripts']);script['return_u32']=int(ip in [0x50,0x58]and earlier==0)
 elif kind=='F37':script['cursor_after_u32']=pending['cursor_before_u32']+5
 elif kind=='F41':
  if row['operation']=='F53'and count==0 and 'initial_state'in policy:script['patches']=[word_patch(row['args'][0]*36,policy['initial_state'])]
  if row['operation']=='F53'and count>0 and 'F41_after_condition_state'in policy:script['patches']=[word_patch(row['args'][0]*36,policy['F41_after_condition_state'])]
 for key in [kind,kind+'_first'if count==0 else'', 'F33_register'if kind=='F33'and pending['args'][1]==44 else'']:
  if key and key in policy:
   value=policy[key]
   if 'return_u32'in value:script['return_u32']=value['return_u32']
   if 'patches'in value:script['patches']=value['patches']
 script['source_cursor']=pending['cursor_before_u32'];return script
def fill(binary,row):
 for attempt in range(257):
  done=run(binary,row)
  if done.returncode:raise ValueError(('Native lifecycle process failed',row['name'],done.returncode,done.stderr[:200]))
  value=decode(done.stdout,row)
  if value['status']==0:return done.stdout,value
  if len(value['observations'])<=len(row['scripts']):raise ValueError('Missing lifecycle pending observation')
  row['scripts'].append(choose_script(row,value['observations'][-1]))
 raise ValueError(('Lifecycle provider profile exceeded',row['name']))
def pool_cases(rows):
 pool={}
 def context(value):
  out=copy.deepcopy(value)
  for key in ['arena','program']:
   raw=bytes.fromhex(out[key]);digest=sha(raw)
   if digest not in pool:pool[digest]={'byte_count':len(raw),'zlib_base64':base64.b64encode(zlib.compress(raw,9)).decode()}
   out[key]=digest
  return out
 out=[]
 for row in rows:
  packed=copy.deepcopy(row);packed['context_before']=context(row['context_before']);packed['expected']['context_after']=context(row['expected']['context_after'])
  for obs in packed['observations']:obs['before']=context(obs['before']);obs['after']=context(obs['after'])
  out.append(packed)
 return pool,out
def generate(a):
 meta,source=reprove(a)if a.reprove_original else verify(a.proof_dir)
 records=[];raws=[];rows=cases()
 with tempfile.TemporaryDirectory(prefix='mission-task-native-')as directory:
  binary,native=build(source,directory)
  # Inactive/stale pointer fields are raw source words, even if their numeric
  # values happen to equal this adapter's own program address.
  symbols=subprocess.check_output(['nm','-n',str(binary)],text=True)
  program_address=int(re.search(r'^([0-9a-f]+) [bBdD] program$',symbols,re.M)[1],16)+8
  if program_address!=0x60000008:raise ValueError('Fixed transport program section differs')
  for operation in ['F47','F38']:
   c=synthetic_context(state=0);arena=bytearray.fromhex(c['arena'])
   for offset in [8,16,28,32]:struct.pack_into('<I',arena,7*36+offset,program_address)
   c['arena']=arena.hex();args=[7,0]if operation=='F47'else[(4<<16)|7]
   rows.append({'name':'opaque-unused-host-collision-'+operation,'operation':operation,'args':args,'context_before':c,'policy':{},'scripts':[]})
  for row in rows:
   raw,value=fill(binary,row)
   for repeat in range(2):
    done=run(binary,row)
    if done.returncode or done.stderr or done.stdout!=raw:raise ValueError(('Fresh lifecycle execution differs',row['name']))
   records.append({k:row[k]for k in ['name','operation','args','context_before']}|{'observations':value['observations'],'expected':{k:v for k,v in value.items()if k not in ['status','observations']}});raws.append(raw)
  previous=synthetic_context(slot=149,generation=0xfff9,cleanup=-1)
  for step in range(12):
   handle=struct.unpack_from('<I',bytes.fromhex(previous['arena']),149*36+4)[0]
   row={'name':'dependent-cancel-generation-%02d'%step,'operation':'F38','args':[handle],'context_before':copy.deepcopy(previous),'policy':{},'scripts':[]}
   raw,value=fill(binary,row)
   for repeat in range(2):
    done=run(binary,row)
    if done.returncode or done.stderr or done.stdout!=raw:raise ValueError('Fresh dependent lifecycle execution differs')
   previous=value['context_after'];rows.append(row)
   records.append({k:row[k]for k in ['name','operation','args','context_before']}|{'observations':value['observations'],'expected':{k:v for k,v in value.items()if k not in ['status','observations']}});raws.append(raw)
  reversed_run=subprocess.run([str(binary)],input=b''.join(packet(r)for r in reversed(rows)),stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True,timeout=120)
  if reversed_run.stderr or reversed_run.stdout!=b''.join(reversed(raws)):raise ValueError('Reversed native lifecycle cohort differs')
  # A real original null-allocation dereference; no after-state is fabricated.
  fault={'name':'F52-full-arena-null-allocation','operation':'F52','args':[-1,0,0],'context_before':synthetic_context(argc=0,caller=MASK),'scripts':[{'kind':51,'args':[0,0],'return_u32':MASK,'cursor_kind':'none','cursor_after_u32':MASK,'patches':[]}]}
  fault['context_before']['arena']=b''.join(task_bytes(slot,1,3)for slot in range(150)).hex()
  f=run(binary,fault)
  if f.returncode!=-11:raise ValueError(('Original F52 NULL fault differs',f.returncode,f.stderr))
 pool,packed=pool_cases(records)
 dependencies=['tools/rebuild_source_mission_task_native.py','tools/rebuild_source_damage_native.py','tools/rebuild_source_natural_contact_native.py','tools/rebuild_source_surface_contact_native.py','tools/rebuild_source_atmospheric_native.py','tools/rebuild_ground_surface_native.py','recovered-history/ground_harness/tools/native_reference.py','recovered-history/ground_harness/tools/build_terrain_query_reference.py','data/ffe_mission_programs.json','validation/events-messages-2026-11-18/events-native-proof/instruction-proof.json','validation/mission-expressions-2026-11-18/guards-native-proof/instruction-proof.json']
 doc={'schema':'starfrontier-mission-task-native-v1','profile':PROFILE,'case_count':len(records),'buffer_codec':'sha256-zlib-base64-v1','buffer_pool':pool,'source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'source_dependencies_sha256':{p:sha((PROJECT/p).read_bytes())for p in dependencies},'proofs_sha256':{p:sha((a.proof_dir/p).read_bytes())for p in ['source-procedures.asm','instruction-proof.json','task-native.s','task-host.c','dos-disassembly.txt']},'fresh_process_runs':3,'reverse_repeat_cases':len(records),'consecutive_native_state_transitions':12,'whole_original_procedures':4,'whole_original_instructions':177,'actual_original_module_cases':105,'typed_boundary_count':sum(len(r['observations'])for r in records),'F51_NULL_transport_token_u32':MASK,'F52_zero_handle_is_defined':True,'bounded_profile_restrictions':['Task slots are admitted only in0..149 before host access.','F47 transported clause indices are0..16383; declared source clause count is intentionally not a gate.','For argc>0 the bounded F52 transport requires a nonnull caller task/cursor; a null task with constant arguments is not claimed to be a universal source fault.','External callbacks are limited to256 observations; genuine unbounded F53 rescan is not claimed to terminate.'],'original_fault_domains_separate':[{'name':fault['name'],'operation':'F52','source_signal':'SIGSEGV','native_returncode':-11,'after_state_claimed':False}],'expected_arithmetic_calculated_in_python':False,'cases':packed,'scope':meta['scope']}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(doc,indent=2)+'\n')
 print(json.dumps({'case_count':len(records),'fixture_sha256':sha(a.output.read_bytes()),'fixture_bytes':a.output.stat().st_size,'typed_boundaries':doc['typed_boundary_count'],'fault_domains_separate':1},indent=2))

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--reprove-original',action='store_true');generate(p.parse_args())
