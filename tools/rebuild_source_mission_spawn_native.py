#!/usr/bin/env python3
"""Whole original DOS F39 identity / F40 spawn with real phase and matrix helpers.

F927 allocation and the original-DOS F1507 position worker remain exact typed
continuations. Expected arithmetic and owner bytes come from native instructions.
"""
from __future__ import annotations
import argparse,base64,copy,hashlib,inspect,json,random,re,struct,subprocess,tempfile,zlib
from pathlib import Path
import rebuild_source_mission_store_native as S
N=S.N;PROJECT=S.PROJECT
PROOF=PROJECT/'validation/mission-statements-2026-11-19/spawn-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_mission_spawn_native.json'
PROFILE='dos-firstenc-mission-spawn-v1'
NUMBERS=[39,40,1532,1510,1509,1338,1675,1914,1521]
OPS=['F39','F40'];KEYS=['root','root_tail','bank'];SIZES=[16384,6160,38986];OFFSETS=[0,16384,22544];OWNER=sum(SIZES)
MASK=0xffffffff;MAX=8;TRACE=64;BASE=64+OWNER+TRACE*4;RECORD=64+OWNER*2+4
sha=lambda raw:hashlib.sha256(raw).hexdigest()

def reprove(a):
 exe=a.exe.read_bytes();source=a.asm.read_text();data=a.data.read_text()
 if sha(exe)!=N.EXE_SHA or sha(a.asm.read_bytes())!=N.ASM_SHA:raise ValueError('Original input identity differs')
 method=inspect.getsource(N.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_000039',0x412b14)\n bind('FUNC_000040',0x412b1c)")
 method=method.replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
 ns=N.__dict__.copy();exec(method,ns);bodies,records,dis,_,aliases=ns['proof'](source,data,exe,a.exe,NUMBERS)
 image=N.G.Image(exe)
 for row in records.values():row['hex']=exe[row['executable_offset']:row['executable_offset']+row['byte_length']].hex()
 if aliases['DATA_008804']!=0x64213c or aliases['DATA_008807']!=0x642140 or aliases['DATA_009133']!=0x647948:raise ValueError('Original Root/time/bank operands differ')
 sine=exe[image.offset(aliases['DATA_007975'],65536):image.offset(aliases['DATA_007975'],65536)+65536]
 archive=json.loads((PROJECT/'validation/equipment-effects-2026-11-18/destruction-native-proof/instruction-proof.json').read_text())
 if sine.hex()!=archive['sine_table_hex']:raise ValueError('Actual sine table differs from independently proved source')
 for n in [1675,1914,1521]:
  if records[str(n)]['hex']!=archive['procedures'][str(n)]['hex']:raise ValueError('Original matrix helper capture differs')
 anchors={}
 for n in [39,40]:
  wanted=records[str(n)]['virtual_address'];hits=[]
  for va in range(0x412c38,0x413d98-4):
   at=image.offset(va,5)
   if exe[at]==0xe8 and (va+5+struct.unpack_from('<i',exe,at+1)[0])&MASK==wanted:
    rows=N.C.original_rows(a.exe,va,count=1)
    if len(rows)==1 and rows[0][1]=='call':hits.append({'caller':'F41','call_va_u32':va,'target_va_u32':wanted,'hex':exe[at:at+5].hex()})
  if not hits:raise ValueError('F39/F40 original entry lacks actual caller anchor')
  anchors['F%d'%n]=hits
 captured='\n'.join(bodies[n]for n in NUMBERS)+'\nFUNC_999999:\nret\n'
 meta={'schema':'starfrontier-mission-spawn-original-proof-v1','source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'source_data_sha256':sha(a.data.read_bytes()),'procedures':records,'bindings':aliases,'source_procedures_sha256':sha(captured.encode()),'whole_procedure_count':len(NUMBERS),'whole_instruction_count':sum(r['instruction_count']for r in records.values()),'all_whole_instructions_equal':True,'actual_F41_entry_anchors':anchors,'sine_table_original_va_u32':aliases['DATA_007975'],'sine_table_hex':sine.hex(),'sine_table_sha256':sha(sine),'root_original_va_u32':0x64213c,'root_tick_offset_u32':0,'root_day_offset_u32':4,'root_bank_pointer_offset_u32':0x580c,'F39_is_scalar_identity':True,'F40_is_nine_argument_body_spawn':True,'F1507_original_variant_is_external':True,'host_adaptations':['Source cdecl32 stack arguments widen to8-byte host slots; source locals retain low-address offsets.','F1510 eight-byte local frame widens to16 only for its two64-bit epilogue pops.','Only bank/global-function pointers translate to host addresses; body scalars and all nine arguments remain u32.','F927 outlocal input is uninitialized and never read by F40; only optional explicit four-byte provider output is recorded.','F1510/F1509/F1338 and F1675/F1914/F1521 execute actual original arithmetic with original readonly sine bytes.','F927 and original-DOS F1507 are typed mutable whole-owner observations; void EAX ignored.'],'scope':'Whole F39/F40 and real F1532/phase/matrix closure over Root/tail/bank. F927 and original-DOS F1507 remain typed external calls. No F41, formatting, world allocation implementation or Main claim.'}
 a.proof_dir.mkdir(parents=True,exist_ok=True)
 (a.proof_dir/'source-procedures.asm').write_text(captured);(a.proof_dir/'instruction-proof.json').write_text(json.dumps(meta,indent=2)+'\n');(a.proof_dir/'dos-disassembly.txt').write_text('\n'.join(dis.values()))
 return meta,captured

def verify(proof=PROOF):
 meta=json.loads((proof/'instruction-proof.json').read_text());source=(proof/'source-procedures.asm').read_text()
 if meta['source_executable_sha256']!=N.EXE_SHA or meta['source_assembly_sha256']!=N.ASM_SHA or sha(source.encode())!=meta['source_procedures_sha256']:raise ValueError('Archived spawn proof identity differs')
 for n in NUMBERS:
  row=meta['procedures'][str(n)];raw=bytes.fromhex(row['hex']);compiled=N.C.J.instructions(N.C.compile32(N.G.block(source,n),meta['bindings'],'FUNC_%06d'%n,row['virtual_address']))
  if sha(raw)!=row['sha256']or len(compiled)!=row['instruction_count']or sha('\n'.join(N.canonical(compiled)).encode())!=row['normalized_instruction_sha256']:raise ValueError('Spawn original instruction proof differs F'+str(n))
  with tempfile.TemporaryDirectory(prefix='spawn-proof-raw-')as folder:
   path=Path(folder)/'raw';path.write_bytes(raw);actual=N.C.J.instructions(subprocess.check_output(['objdump','-D','-b','binary','-m','i386','-Mintel','--no-show-raw-insn','--adjust-vma='+hex(row['virtual_address']),str(path)],text=True))
  if N.canonical(actual)!=N.canonical(compiled):raise ValueError('Original raw spawn instructions differ')
 for rows in meta['actual_F41_entry_anchors'].values():
  for row in rows:
   raw=bytes.fromhex(row['hex'])
   if len(raw)!=5 or raw[0]!=0xe8 or (row['call_va_u32']+5+struct.unpack_from('<i',raw,1)[0])&MASK!=row['target_va_u32']:raise ValueError('Captured actual F41 call anchor differs')
 if sha(bytes.fromhex(meta['sine_table_hex']))!=meta['sine_table_sha256']:raise ValueError('Captured sine bytes differ')
 return meta,source

def trace(number):
 return 'pushfq\npush rax\npush rcx\nmov ecx,DWORD PTR [p_trace_count]\ncmp ecx,64\njae p_abort\nmov DWORD PTR [p_trace+rcx*4],%d\ninc DWORD PTR [p_trace_count]\npop rcx\npop rax\npopfq\n'%number

def assembly(source,meta):
 selected=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',source)
 lines,_=N.Q.procedures(selected,NUMBERS);text='\n'.join(lines)
 text=re.sub(r'\[rbp[^\]]*\]',lambda m:re.sub(r'\b(eax|ebx|ecx|edx|esi|edi)\b',lambda r:'r'+r[1][1:],m[0]),text)
 marker='FUNC_001510:\npush rbp\nmov rbp,rsp\nadd rsp,-8'
 if text.count(marker)!=1:raise ValueError('F1510 two-pop local frame differs')
 text=text.replace(marker,marker.replace('rsp,-8','rsp,-16'))
 for n in NUMBERS:text=text.replace('FUNC_%06d:\n'%n,'FUNC_%06d:\n'%n+trace(n),1)
 bridges=[]
 for n in [927,1507]:
  bridges.append('FUNC_%06d:\n'%n+trace(n)+'''push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
mov esi,DWORD PTR [rbp+16]
mov edx,DWORD PTR [rbp+24]
mov ecx,DWORD PTR [rbp+32]
mov r8d,DWORD PTR [rbp+40]
'''+('mov r9d,DWORD PTR [rbp+48]\n'if n==927 else'xor r9d,r9d\n')+f'''mov edi,{n}
and rsp,-16
call p_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
''')
 return '.intel_syntax noprefix\n.code64\n.section .text\n'+text+'\n'+''.join(bridges)+'''
.global call_kernel
call_kernel:
mov [p_saved_rsp],rsp
mov esp,OFFSET FLAT:p_stack_end
mov edx,esi
test edi,edi
jz p_identity
mov ecx,8
p_push_args:
mov eax,DWORD PTR [rdx+rcx*4]
push rax
dec ecx
jns p_push_args
call FUNC_000040
jmp p_return
p_identity:
mov eax,DWORD PTR [rdx]
push rax
call FUNC_000039
p_return:
mov rsp,[p_saved_rsp]
ret
p_abort:
mov edi,97
mov eax,60
syscall
.section .data
p_root=p_root_store+8
p_bank=p_bank_store+8
DATA_007754:.quad FUNC_001532
DATA_007198:.quad FUNC_000927
DATA_007743:.quad FUNC_001510
DATA_007741:.quad FUNC_001507
DATA_008804=p_root
DATA_008807=p_root+4
DATA_009133=p_root+22540
DATA_007975:.long '''+','.join(map(str,struct.unpack('<16384i',bytes.fromhex(meta['sine_table_hex']))))+'''
.section .bss
.balign 16
p_stack:.zero 2097152
p_stack_end:
p_saved_rsp:.zero 8
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
#define OWNER (ROOT+TAIL+BANK)
#define MAX 8
#define TRACE 64
#define BASE (64+OWNER+TRACE*4)
#define RECORD (64+OWNER*2+4)
#define GUARD UINT64_C(0xa5a5a5a5a5a5a5a5)
#define CHECK(x) do{if(!(x)){fprintf(stderr,"spawn-native-check:%d\n",__LINE__);exit(97);}}while(0)
struct __attribute__((packed)){uint64_t a;uint8_t data[ROOT+TAIL];uint64_t b;}p_root_store;
struct __attribute__((packed)){uint64_t a;uint8_t data[BANK];uint64_t b;}p_bank_store;
#define p_root p_root_store.data
#define p_bank p_bank_store.data
uint32_t p_trace[TRACE],p_trace_count;
#pragma pack(push,1)
struct Patch{uint32_t owner,offset,size,unused;uint8_t data[64];};
struct Script{uint32_t h[16];struct Patch patch[12];uint8_t output[4];};
struct Input{uint32_t h[16];uint8_t owner[OWNER];struct Script scripts[MAX];};
#pragma pack(pop)
static struct Input input;static uint8_t output[BASE+MAX*RECORD],logical[OWNER];
static uint32_t used,status;static jmp_buf jump;
extern uint32_t call_kernel(uint32_t,uint32_t*);
static uint32_t get(const void*p){uint32_t n;memcpy(&n,p,4);return n;}
static void put(void*p,uint32_t n){memcpy(p,&n,4);}
static uint32_t ptr(const void*p){CHECK((uintptr_t)p<=0xffffffffu);return(uint32_t)(uintptr_t)p;}
static int body_ref(uint32_t n){return n==0||(n>=116&&(n-116)%338==0&&(n-116)/338<=114);}
static uint32_t to_host(uint32_t n){CHECK(body_ref(n));return n?ptr(p_bank)+n:0;}
static uint32_t to_ref(uint32_t n){CHECK(n==0||(n>=ptr(p_bank)+116&&n<=ptr(p_bank)+116+114*338&&(n-ptr(p_bank)-116)%338==0));return n?n-ptr(p_bank):0;}
static void capture(uint8_t*p){memcpy(p,p_root,ROOT+TAIL);put(p+0xc8,to_ref(get(p_root+0xc8)));put(p+0xcc,to_ref(get(p_root+0xcc)));CHECK(get(p_root+0x580c)==ptr(p_bank));put(p+0x580c,1);memcpy(p+ROOT+TAIL,p_bank,BANK);}
static void load(const uint8_t*p){memcpy(p_root,p,ROOT+TAIL);put(p_root+0xc8,to_host(get(p+0xc8)));put(p_root+0xcc,to_host(get(p+0xcc)));CHECK(get(p+0x580c)==1);put(p_root+0x580c,ptr(p_bank));memcpy(p_bank,p+ROOT+TAIL,BANK);}
static void canaries(void){CHECK(p_root_store.a==GUARD&&p_root_store.b==GUARD&&p_bank_store.a==GUARD&&p_bank_store.b==GUARD);}
uint32_t p_observe(uint32_t kind,uint32_t a,uint32_t b,uint32_t c,uint32_t d,uintptr_t outlocal){
 uint32_t args[6]={0};
 if(kind==927){CHECK(a==ptr(p_bank));args[0]=1;args[1]=to_ref(b);args[2]=c;args[3]=d;}
 else{CHECK(kind==1507);args[0]=to_ref(a);args[1]=b;args[2]=c;args[3]=d;}
 CHECK(used<MAX);uint8_t*row=output+BASE+used*RECORD;put(row,kind);put(row+4,4);memcpy(row+8,args,24);capture(row+64);
 if(used>=input.h[10]){status=1;capture(row+64+OWNER);used++;longjmp(jump,1);return 0;}
 struct Script*s=&input.scripts[used];CHECK(s->h[0]==kind&&s->h[1]==4&&!memcmp(s->h+2,args,24));uint32_t returned=s->h[8],patches=s->h[9],outlen=s->h[10];CHECK(patches<=12);
 capture(logical);
 uint32_t sizes[3]={ROOT,TAIL,BANK},offsets[3]={0,ROOT,ROOT+TAIL};
 for(uint32_t i=0;i<patches;i++){struct Patch*p=&s->patch[i];CHECK(p->owner<3&&p->size<=64&&p->offset<=sizes[p->owner]&&p->size<=sizes[p->owner]-p->offset);memcpy(logical+offsets[p->owner]+p->offset,p->data,p->size);}
 load(logical);
 if(kind==927){CHECK(body_ref(returned)&&(outlen==0||outlen==4));if(outlen){CHECK(outlocal!=0);memcpy((void*)outlocal,s->output,4);memcpy(row+64+OWNER*2,(void*)outlocal,4);}}
 else CHECK(returned==0&&outlen==0);
 put(row+32,returned);put(row+36,outlen);capture(row+64+OWNER);used++;return kind==927?to_host(returned):0;
}
int main(void){
 while(fread(&input,1,sizeof input,stdin)==sizeof input){
  CHECK(input.h[0]<2&&input.h[10]<=MAX);if(input.h[0]==1)CHECK(input.h[2]<=114);
  p_root_store.a=p_root_store.b=p_bank_store.a=p_bank_store.b=GUARD;load(input.owner);memset(output,0,sizeof output);used=status=p_trace_count=0;volatile uint32_t returned=0;
  if(!setjmp(jump))returned=call_kernel(input.h[0],input.h+1);
  if(!status)CHECK(used==input.h[10]);canaries();put(output,0x40fa1739);put(output+4,BASE+used*RECORD);put(output+8,status);put(output+12,status?0:input.h[0]==0?returned:to_ref(returned));put(output+16,used);put(output+20,p_trace_count);put(output+24,input.h[0]==0);put(output+28,input.h[0]==1);capture(output+64);memcpy(output+64+OWNER,p_trace,p_trace_count*4);
  CHECK(fwrite(output,1,BASE+used*RECORD,stdout)==BASE+used*RECORD);
 }
 return 0;
}
'''

def context_bytes(ctx):return b''.join(bytes.fromhex(ctx[k])for k in KEYS)
def context(raw):return{k:raw[o:o+n].hex()for k,o,n in zip(KEYS,OFFSETS,SIZES)}
def packet(row):
 args=[v&MASK for v in row['args']];scripts=row.get('scripts',[])
 raw=struct.pack('<16I',OPS.index(row['operation']),*args,*([0]*(9-len(args))),len(scripts),*([0]*5))+context_bytes(row['context_before'])
 for script in scripts:
  out=bytes.fromhex(script.get('output_hex',''));values=script['args'];patches=script.get('patches',[])
  if len(out)>4 or len(patches)>12:raise ValueError('Typed spawn script extent differs')
  raw+=struct.pack('<16I',script['kind'],len(values),*values,*([0]*(6-len(values))),script['return_u32'],len(patches),len(out),*([0]*5))
  for patch in patches:
   data=bytes.fromhex(patch['hex']);raw+=struct.pack('<4I',patch['owner'],patch['offset'],len(data),0)+data.ljust(64,b'\0')
  raw+=bytes((12-len(patches))*80)+out.ljust(4,b'\0')
 return raw+bytes((MAX-len(scripts))*1028)
def decode(raw,row):
 h=struct.unpack_from('<16I',raw)
 if h[0]!=0x40fa1739 or h[1]!=len(raw)or h[2]not in[0,1]or h[4]>MAX or h[5]>TRACE or len(raw)!=BASE+h[4]*RECORD:raise ValueError(('Spawn output differs',row['name'],h[:8]))
 observations=[]
 for i in range(h[4]):
  at=BASE+i*RECORD;kind,argc=struct.unpack_from('<2I',raw,at);n=struct.unpack_from('<I',raw,at+36)[0]
  observations.append({'kind':'F%d'%kind,'args':list(struct.unpack_from('<6I',raw,at+8))[:argc],'before':context(raw[at+64:at+64+OWNER]),'after':context(raw[at+64+OWNER:at+64+OWNER*2]),'return_u32':struct.unpack_from('<I',raw,at+32)[0],'input_hex':'','output_hex':raw[at+64+OWNER*2:at+64+OWNER*2+n].hex()})
 return {'status':h[2],'context_after':context(raw[64:64+OWNER]),'return_u32':h[3],'return_defined':True,'scalar_return_defined':bool(h[6]),'pointer_return_defined':bool(h[7]),'pointer_result_kind':'logical_bank_offset'if h[7]else'','source_order':['F%d'%n for n in struct.unpack_from('<%dI'%h[5],raw,64+OWNER)],'observations':observations,'pending':observations[-1]if h[2]else None}
def build(meta,source,folder):
 folder=Path(folder);native=assembly(source,meta);(folder/'native.s').write_text(native);(folder/'host.c').write_text(C);binary=folder/'native'
 result=subprocess.run(['gcc','-O1','-fno-pie','-no-pie','-fno-stack-protector','-o',str(binary),str(folder/'native.s'),str(folder/'host.c')],capture_output=True)
 if result.returncode:raise ValueError(result.stderr.decode())
 return binary,native
def run(binary,row):
 process=subprocess.run([str(binary)],input=packet(row),capture_output=True,timeout=30)
 if process.returncode or process.stderr:raise ValueError(('Spawn native failed',row['name'],process.returncode,process.stderr[:300]))
 return process.stdout

def base_context():
 root=bytearray((i*13+7)&255 for i in range(SIZES[0]));tail=bytearray((i*11+3)&255 for i in range(SIZES[1]));bank=bytes((i*37+11)&255 for i in range(SIZES[2]))
 struct.pack_into('<2I',root,0,0x12345678,0x121cf7);struct.pack_into('<2I',root,0xc8,454,792);struct.pack_into('<I',tail,0x180c,1)
 return {'root':root.hex(),'root_tail':tail.hex(),'bank':bank.hex()}
def patch(owner,offset,*values):return {'owner':owner,'offset':offset,'hex':struct.pack('<%dI'%len(values),*(v&MASK for v in values)).hex()}
def cases():
 rows=[]
 def add(name,args=None,operation='F40',ctx=None,policy=None):
  rows.append({'name':name,'operation':operation,'args':args or[38,1,0x11223344,0x00154000,0x56,0x01020304,0x7fff,13,0x1234],'context_before':copy.deepcopy(ctx or base_context()),'policy':policy or {},'scripts':[]});return rows[-1]
 for value in list(range(256))+[0x7fffffff,0x80000000,MASK,116,38648,0x64213c,0x647948]:add('F39-identity-%08x'%value,[value],'F39')
 for parent in [0,1,114]:
  add('F40-null-allocation-parent%d'%parent,[38,parent,0,0,0,0,0,0,0],policy={'allocation_ref':0})
  add('F40-null-allocation-world-mutation-parent%d'%parent,[38,parent,0,0,0,0,0,0,0],policy={'allocation_ref':0,'F927':{'patches':[patch(0,0x300,0xdeadbeef),patch(1,0x10,0x12345678)],'output_hex':''}})
 for body in [0,1,17,64,114]:
  for parent in [0,1,114]:
   row=add('F40-selected%d-parent%d'%(body,parent));row['args'][1]=parent;row['policy']['allocation_ref']=116+body*338
 for shift in range(256):
  row=add('F40-all-byte-shifts-%03d'%shift);row['args'][7]=shift
 for word in [0,1,0x7fff,0x8000,0xffff,0x10000,0x12348000,0x7fffffff,0x80000000,MASK]:
  for argument in [0,2,3,4,5,6,7,8]:
   row=add('F40-argument%d-%08x'%(argument,word));row['args'][argument]=word
 for tick,day in [(0,0),(0,1),(1,0),(0x12345678,0x9abcdef0),(MASK,0),(0,MASK),(MASK,MASK),(0x80000000,0x7fffffff),(0x7fffffff,0x80000000)]:
  for rate in [0,1,0x80000000,MASK]:
   ctx=base_context();root=bytearray.fromhex(ctx['root']);struct.pack_into('<2I',root,0,tick,day);ctx['root']=root.hex()
   row=add('F40-clock-%08x-%08x-rate%08x'%(tick,day,rate),ctx=ctx);row['args'][5]=rate
 for slot in [0,17,114]:
  at=116+slot*338
  add('F40-clock-reread-after-allocation-slot%d'%slot,policy={'allocation_ref':at,'F927':{'patches':[patch(0,0,0xfedcba98,0x76543210),patch(2,at+0x124,0x52555321,0x414c4941)],'output_hex':'efbeadde'}})
  add('F40-held-body-clock-and-neighbor-reread-slot%d'%slot,policy={'allocation_ref':at,'F1507':{'patches':[patch(2,at+0xa8,0xf1234567,0xfedcba98),patch(0,0,0xaabbccdd,0x11223344),patch(0,0xc8,116+9*338,116+64*338),patch(1,0x20,0x12345678),patch(2,116+9*338+0x124,0x616c6961)],'output_hex':''}})
 add('F40-allocation-local-output-absent',policy={'F927':{'output_hex':''}})
 add('F40-allocation-local-output-zero',policy={'F927':{'output_hex':'00000000'}})
 add('F40-position-overwritten-field-widths',policy={'F1507':{'patches':[{'owner':2,'offset':116+17*338,'hex':'ab'*36},patch(2,116+17*338+0xc8,0xdeadbeef,0x01234567)]}})
 return rows
def response(pending,row):
 kind=int(pending['kind'][1:]);policy=row.get('policy',{});provider=policy.get('F%d'%kind,{})
 return {'kind':kind,'args':pending['args'],'return_u32':policy.get('allocation_ref',116+17*338)if kind==927 else 0,'patches':copy.deepcopy(provider.get('patches',[])),'output_hex':provider.get('output_hex','78563412'if kind==927 else'')}
def fill(binary,row):
 for _ in range(MAX+1):
  raw=run(binary,row);value=decode(raw,row)
  if not value['status']:return raw
  row['scripts'].append(response(value['pending'],row))
 raise ValueError('Spawn continuation bound exceeded')
def dependent_rows(binary):
 result=[];current=base_context()
 for step,(slot,rate,shift,tilt)in enumerate([(17,1,0,0),(64,MASK,31,0xffff),(17,0x80000000,32,0x8000),(114,7,255,0x7fff),(-1,0,0,0),(0,9,17,0x1234),(1,0,63,1),(17,3,128,0xfffe)]):
  args=[38,1,0x11220000+step,0x00154000,step*0x1111,rate,0x8000+step,shift,tilt]
  row={'name':'shared-world-spawn-%02d'%step,'operation':'F40','args':args,'context_before':copy.deepcopy(current),'policy':{'allocation_ref':0 if slot<0 else 116+slot*338,'F927':{'patches':[patch(0,0,0x10203040+step,0x11223344-step)]}},'scripts':[],'shared_owner_sequence':'eight-ordered-spawns','shared_step_u32':step}
  raw=fill(binary,row);row['expected']=decode(raw,row);current=copy.deepcopy(row['expected']['context_after']);result.append(row)
 return result
def pool_rows(rows):
 pool={}
 def packed(ctx):
  value=copy.deepcopy(ctx)
  for key in KEYS:
   raw=bytes.fromhex(value[key]);name=sha(raw);pool.setdefault(name,{'byte_count':len(raw),'zlib_base64':base64.b64encode(zlib.compress(raw,9)).decode()});value[key]={'buffer_sha256':name}
  return value
 result=[]
 for row in rows:
  value={key:copy.deepcopy(row[key])for key in ['name','operation','args']};value['context_before']=packed(row['context_before']);value['observations']=copy.deepcopy(row['expected']['observations']);value['expected']={key:copy.deepcopy(content)for key,content in row['expected'].items()if key not in ['observations','pending','status']};value['expected']['context_after']=packed(value['expected']['context_after'])
  for observation in value['observations']:
   observation['before']=packed(observation['before']);observation['after']=packed(observation['after'])
  for key in ['shared_owner_sequence','shared_step_u32']:
   if key in row:value[key]=row[key]
  result.append(value)
 return pool,result
def generate(a,meta,source):
 rows=cases()
 with tempfile.TemporaryDirectory(prefix='spawn-native-')as directory:
  binary,native=build(meta,source,directory)
  # Identity must not turn opaque scalar words into translated host pointers.
  symbols=subprocess.check_output(['nm','-n',str(binary)],text=True);address=int(next(line.split()[0]for line in symbols.splitlines()if line.endswith(' p_bank_store')),16)+8+116
  rows.append({'name':'F39-opaque-native-body-address','operation':'F39','args':[address],'context_before':base_context(),'policy':{},'scripts':[]})
  for row in rows:row['expected']=decode(fill(binary,row),row)
  rows+=dependent_rows(binary);payload=b''.join(packet(row)for row in rows);cohorts=[]
  for cohort in range(3):
   completed=subprocess.run([str(binary)],input=payload,capture_output=True,timeout=120)
   if completed.returncode or completed.stderr:raise ValueError(('Native fresh cohort failed',completed.returncode,completed.stderr[:200]))
   if cohort==0:first=completed.stdout
   elif completed.stdout!=first:raise ValueError('Native fresh process cohort differs')
   cohorts.append(sha(completed.stdout))
  at=0
  for row in rows:
   size=struct.unpack_from('<I',first,at+4)[0];value=decode(first[at:at+size],row);at+=size
   if value!=row['expected']:raise ValueError('Native bulk/fresh result differs '+row['name'])
  if at!=len(first):raise ValueError('Native cohort output has trailing bytes')
  reverse=subprocess.run([str(binary)],input=b''.join(packet(row)for row in reversed(rows)),capture_output=True,timeout=120)
  if reverse.returncode or reverse.stderr:raise ValueError('Native reverse cohort failed')
  at=0
  for row in reversed(rows):
   size=struct.unpack_from('<I',reverse.stdout,at+4)[0];value=decode(reverse.stdout[at:at+size],row);at+=size
   if value!=row['expected']:raise ValueError('Native reverse result differs '+row['name'])
  if at!=len(reverse.stdout):raise ValueError('Native reverse trailing output')
 a.proof_dir.mkdir(parents=True,exist_ok=True);(a.proof_dir/'spawn-native.s').write_text(native);(a.proof_dir/'spawn-host.c').write_text(C)
 pool,packed=pool_rows(rows);deps=['tools/rebuild_source_mission_spawn_native.py','tools/rebuild_source_mission_store_native.py','tools/rebuild_source_mission_expression_native.py','tools/rebuild_source_natural_contact_native.py','tools/rebuild_source_damage_native.py','recovered-history/ground_harness/tools/native_reference.py','recovered-history/ground_harness/tools/build_terrain_query_reference.py','validation/equipment-effects-2026-11-18/destruction-native-proof/instruction-proof.json']
 proofs={name:sha((a.proof_dir/name).read_bytes())for name in ['instruction-proof.json','source-procedures.asm','dos-disassembly.txt','spawn-native.s','spawn-host.c']}
 document={'schema':'starfrontier-mission-spawn-native-v1','profile':PROFILE,'source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'source_dependencies_sha256':{path:sha((PROJECT/path).read_bytes())for path in deps},'proofs_sha256':proofs,'case_count':len(rows),'whole_original_procedures':len(NUMBERS),'whole_original_instructions':meta['whole_instruction_count'],'fresh_process_runs':3,'fresh_output_sha256':cohorts,'reverse_repeat_cases':len(rows),'dependent_native_transitions':8,'shared_continuation_edges':7,'all_F39_low_byte_values_tested':True,'all_F40_low_byte_shift_values_tested':True,'original_fault_domains_separate':[],'bounded_profile_restrictions':['F40 parent index is transported only in0..114; F1532 source pointer arithmetic itself has no bounds guard.','F927 callback returns NULL or a canonical body offset; arbitrary invalid pointers are outside the typed profile.','Uninitialized and unconsumed F927 outlocal input is not asserted; explicit4-byte output writes remain observable.'],'expected_arithmetic_calculated_in_python':False,'all_owner_canaries_unchanged':True,'original_sine_table_sha256':meta['sine_table_sha256'],'F1507_original_DOS_body_executed':False,'JJFFE_F1507_substituted':False,'native_F1510_and_F1675_bodies_executed':True,'typed_world_callbacks':['F927','F1507'],'buffer_codec':'sha256-zlib-base64-v1','buffer_pool':pool,'cases':packed,'Main_integrated':False,'full_F41_VM_executed':False,'scope':meta['scope']}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(document,indent=2)+'\n')
 print(json.dumps({'case_count':len(rows),'fixture_sha256':sha(a.output.read_bytes()),'bytes':a.output.stat().st_size,'whole_original_instructions':meta['whole_instruction_count']},indent=2))
def main():
 p=argparse.ArgumentParser(description=__doc__)
 for name,default in [('exe','/workspace/ffe-original/FIRSTENC.EXE'),('asm','/workspace/ffe-upstream/jjffe/ffe.asm'),('data','/workspace/ffe-upstream/jjffe/ffedat.asm')]:p.add_argument('--'+name,type=Path,default=Path(default))
 p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--reprove-original',action='store_true');a=p.parse_args();meta,source=reprove(a)if a.reprove_original else verify(a.proof_dir);generate(a,meta,source)
if __name__=='__main__':main()
