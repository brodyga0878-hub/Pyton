#!/usr/bin/env python3
"""Whole DOS F942/F926/F927 destruction with original allocation and arithmetic.

Only UI messages, module handler bodies and string expansion are typed external
providers. Python transports input/replies and records original native results.
"""
from __future__ import annotations
import argparse,base64,copy,hashlib,inspect,json,random,re,struct,subprocess,tempfile,zlib
from pathlib import Path
import rebuild_source_natural_contact_native as N
import rebuild_source_damage_native as H

PROJECT=N.PROJECT;PROOF=PROJECT/'validation/equipment-effects-2026-11-18/destruction-native-proof';FIXTURE=PROJECT/'tests/fixtures/source_destruction_native.json'
NUMBERS=[942,926,927,928,924,144,1533,1538,1495,1341,1530,922,1675,1914,1521,1514]
TRACE_NUMBERS={942,926,927,928,924,144,1533,1538,1530,922,1675,1514}
BANK=38986;ROOT=16384;MODULE=168;OWNER=ROOT+BANK+MODULE+4
MODELS=156;MODEL_BYTES=108;SCRIPTS=64;SCRIPT=1024
INPUT=64+OWNER+MODELS*MODEL_BYTES+SCRIPTS*SCRIPT
BASE=64+OWNER+512*4;SNAP=40+2*OWNER
PROFILE='dos-firstenc-whole-f942-destruction-v1'
sha=lambda raw:hashlib.sha256(raw).hexdigest()

def prepare(a):
 exe=a.exe.read_bytes();asm=a.asm.read_bytes()
 if sha(exe)!=N.EXE_SHA or sha(asm)!=N.ASM_SHA:raise ValueError('Original destruction input identity differs')
 source=asm.decode().replace('\r\n','\n')
 anchor=H.verify()[0]['source_symbol_addresses']['FUNC_000942']
 resolver=inspect.getsource(N.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_000942',%d)"%anchor)
 resolver=resolver.replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
 ns=N.__dict__.copy();exec(resolver,ns)
 bodies,records,dis,_,aliases=ns['proof'](source,a.data.read_text(),exe,a.exe,NUMBERS)
 capture='\n'.join(bodies[n]for n in NUMBERS)
 image=N.G.Image(exe)
 sine=exe[image.offset(aliases['DATA_007975'],65536):image.offset(aliases['DATA_007975'],65536)+65536]
 cargo=exe[image.offset(aliases['DATA_007212'],32):image.offset(aliases['DATA_007212'],32)+32]
 if list(struct.unpack('<16384i',sine))!=json.loads((PROJECT/'data/ffe_ground_coordinates.json').read_text())['sin_quarter_q31']:raise ValueError('Original sine table differs')
 for r in records.values():
  at=r['executable_offset'];r['hex']=exe[at:at+r['byte_length']].hex()
 registry=H.verify()[0]['original_module_registry']
 info={'schema':'starfrontier-destruction-original-proof-v1','source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'procedures':records,'bindings':aliases,'source_procedures_sha256':sha(capture.encode()),'full_original_instruction_equality':True,'sine_table_hex':sine.hex(),'sine_table_original_va':aliases['DATA_007975'],'cargo_table_hex':cargo.hex(),'cargo_table_original_va':aliases['DATA_007212'],'original_module_registry':registry,'scope':'Whole F942/F926/F927/F928/F924/F144 with actual factory153/155, shared Root RNG, F1675 original sine and integer matrix, F1514 displacement. Message UI, nonnull module handler and F1344 string expansion bodies are explicit typed external continuations. No live Main or on-device result.'}
 info['host_adaptations']=['Every complete selected IA32 procedure is independently assembled and compared with uploaded DOS instructions before adaptation.','Reviewed ELF64 cdecl stack argument slots widened to8bytes; source32bit low-address pointers and all original integer arithmetic retained.','F1495 scratch frame widened8to16 only for two host epilogue pops; original packed local fields retain offsets.','Global function pointers alone use host64bit slots; source descriptor/data/handler table entries remain32bit low pointers.','Native Root+C8 logicalplayer slot1..114 rebinds to its supplied bank record only during execution, then snapshots normalize it back; opaque-unused words are preserved.','Original F144 null/non-null handler dispatcher executes over archived immutable original event11 entries; nonnull handlers use explicit full-owner before/after responses.','Native providers observe only defined F349 message fields and F1344 output name pointer/item, not uninitialized stack packet padding or string-variable scratch.','Observer snapshots/entry traces preserve source-visible registers and flags. Python calculates no expected gameplay, factory, RNG, matrix or bank arithmetic.']
 a.proof_dir.mkdir(parents=True,exist_ok=True)
 (a.proof_dir/'source-procedures.asm').write_text(capture);(a.proof_dir/'instruction-proof.json').write_text(json.dumps(info,indent=2)+'\n');(a.proof_dir/'dos-disassembly.txt').write_text(''.join('F'+n+'\n'+x for n,x in dis.items()))
 return info,capture

def verify(proof=PROOF):
 info=json.loads((proof/'instruction-proof.json').read_text());source=(proof/'source-procedures.asm').read_text()
 if info['source_executable_sha256']!=N.EXE_SHA or info['source_assembly_sha256']!=N.ASM_SHA or sha(source.encode())!=info['source_procedures_sha256']:raise ValueError('Archived destruction capture differs')
 for n in NUMBERS:
  r=info['procedures'][str(n)];rows=N.C.J.instructions(N.C.compile32(N.G.block(source,n),info['bindings'],'FUNC_%06d'%n,r['virtual_address']))
  if len(rows)!=r['instruction_count']or sha('\n'.join(N.canonical(rows)).encode())!=r['normalized_instruction_sha256']:raise ValueError('Whole DOS destruction instructions differ F%d'%n)
 if sha(bytes.fromhex(info['sine_table_hex']))!=sha(struct.pack('<16384i',*json.loads((PROJECT/'data/ffe_ground_coordinates.json').read_text())['sin_quarter_q31'])):raise ValueError('Sine table source differs')
 return info,source

def trace(n):return 'pushfq\npush rax\npush rcx\nmov ecx,DWORD PTR [d_trace_count]\ncmp ecx,512\njae d_abort\nmov DWORD PTR [d_trace+rcx*4],%d\ninc DWORD PTR [d_trace_count]\npop rcx\npop rax\npopfq\n'%n

def assembly(source,meta):
 selected=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',source)+'\nFUNC_999999:\nret\n'
 lines,_=N.Q.procedures(selected,NUMBERS);text='\n'.join(lines)
 marker='FUNC_001495:\npush rbp\nmov rbp,rsp\nadd rsp,-8'
 if text.count(marker)!=1:raise ValueError('Reviewed factory scratch layout differs')
 text=text.replace(marker,marker.replace('rsp,-8','rsp,-16'))
 # Original F942 reserves112 bytes; its locals remain at original offsets.
 # Native arguments expand to8-byte slots, but no pointer is stored above4GiB.
 for n in TRACE_NUMBERS:text=text.replace('FUNC_%06d:\n'%n,'FUNC_%06d:\n'%(n)+trace(n),1)
 text=text.replace('FUNC_000144:\n','FUNC_000144:\nmov eax,DWORD PTR [rsp+8]\nmov DWORD PTR [d_module],eax\n',1)
 support=[]
 for n,argc in [(349,1),(1907,2),(1344,3)]:support.append(boundary(n,argc))
 support.append(boundary(14400,1))
 data=['.section .data','.global DATA_004681','DATA_007752: .quad FUNC_001530','DATA_007217: .quad FUNC_000922','DATA_007756: .quad FUNC_001538','DATA_007755: .quad FUNC_001533','DATA_007734: .quad FUNC_001495','DATA_007746: .quad FUNC_001514','DATA_007639: .quad FUNC_001344','DATA_007198: .quad FUNC_000927','DATA_007219: .quad FUNC_000928','DATA_007758: .long d_bank','DATA_009133: .long d_bank','DATA_004681: .zero 1024','DATA_007210: .long 0,4,10,25,45,80,150,250,400,600,6,12,24,36,0','DATA_007212: .byte '+','.join(map(str,bytes.fromhex(meta['cargo_table_hex']))),'DATA_007975: .long '+','.join(map(str,struct.unpack('<16384i',bytes.fromhex(meta['sine_table_hex'])))),'DATA_004892: .long '+','.join('d_registry%d'%i for i in range(21))]
 for r in meta['original_module_registry']:
  words=struct.unpack('<12I',bytes.fromhex(r['span_hex']));data.append('d_registry%d: .long '%r['module_index_u32']+','.join('FUNC_014400'if i==11 and v else'0'for i,v in enumerate(words)))
 data+=['d_root=d_root_store+8','d_bank=d_bank_store+8','d_modules=d_module_store+8','d_module_count=d_count_store+8','DATA_008804=d_root','DATA_008807=d_root+4','DATA_008818=d_root+0x24','DATA_008820=d_root+0x28','DATA_008834=d_root+0x70','DATA_008857=d_root+0xc0','DATA_008861=d_root+0xc8','DATA_008888=d_root+0x114','DATA_008911=d_root+0x19c','DATA_008621=d_module_count','DATA_008623=d_modules','DATA_008802=d_angles','DATA_008803=d_angles+4','.section .bss','.balign 16','d_angles:.zero 8','d_low_stack:.zero 1048576','d_low_stack_end:','d_saved_rsp:.zero 8','.section .note.GNU-stack,"",@progbits']
 entry='''.global call_kernel
call_kernel:
mov [d_saved_rsp],rsp
mov esp,OFFSET FLAT:d_low_stack_end
mov eax,edi
imul eax,eax,338
add eax,OFFSET FLAT:d_bank+116
push rsi
push rax
call FUNC_000942
mov rsp,[d_saved_rsp]
ret
d_abort:
mov edi,97
mov eax,60
syscall
_memcpy:
push rbp
mov rbp,rsp
push rsi
push rdi
mov edi,DWORD PTR [rbp+16]
mov esi,DWORD PTR [rbp+24]
mov ecx,DWORD PTR [rbp+32]
mov eax,edi
rep movsb
pop rdi
pop rsi
pop rbp
ret
'''
 return '.intel_syntax noprefix\n.code64\n.section .text\n'+text+'\n'+entry+'\n'+'\n'.join(support)+'\n'+'\n'.join(data)+'\n'

def boundary(n,argc):
 loads=['mov esi,DWORD PTR [rbp+16]','xor edx,edx','xor ecx,ecx']
 if argc>=2:loads.append('mov edx,DWORD PTR [rbp+24]')
 if argc>=3:loads.append('mov ecx,DWORD PTR [rbp+32]')
 return 'FUNC_%06d:\n'%n+'''push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
'''+('\n'.join(loads))+f'''\nmov edi,{n}
and rsp,-16
call d_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret
'''

C=r'''
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define BANK 38986
#define ROOT 16384
#define OWNER (ROOT+BANK+168+4)
#define BASE (64+OWNER+2048)
#define SNAP (40+2*OWNER)
struct __attribute__((packed)) Model{uint32_t index;uint8_t descriptor[68],physical[24];uint32_t collision_present,collision_first,physical_present;};
struct __attribute__((packed)) Patch{uint32_t owner,offset,size,reserved;uint8_t data[64];};
struct __attribute__((packed)) Script{uint32_t kind,argc,args[6],result,patch_count,pad[6];struct Patch patches[12];};
struct __attribute__((packed)) Input{uint32_t header[16];uint8_t root[ROOT],bank[BANK],modules[168];int32_t count;struct Model models[156];struct Script scripts[64];};
struct __attribute__((packed)){uint8_t before[8],data[ROOT],after[8];}d_root_store;
struct __attribute__((packed)){uint8_t before[8],data[BANK],after[8];}d_bank_store;
struct __attribute__((packed)){uint8_t before[8],data[168],after[8];}d_module_store;
struct __attribute__((packed)){uint8_t before[8];int32_t data;uint8_t after[8];}d_count_store;
#define d_root (d_root_store.data)
#define d_bank (d_bank_store.data)
#define d_modules (d_module_store.data)
#define d_module_count (d_count_store.data)
uint32_t d_trace[512],d_trace_count,d_module;
uint8_t descriptors[256][68],physical[256][24],collision[256];
extern uint32_t DATA_004681[256];extern uint32_t call_kernel(uint32_t,uint32_t);
static struct Input input,saved_input;static uint8_t output[BASE+64*SNAP];static uint32_t used,status;static int pointer_bound;
static uint32_t get(const void*p){uint32_t n;memcpy(&n,p,4);return n;}static void put(void*p,uint32_t n){memcpy(p,&n,4);}
static void capture(uint8_t*out){memcpy(out,d_root,ROOT);uint32_t p=get(out+0xc8);uintptr_t first=(uintptr_t)d_bank+116,last=first+115*338;if(pointer_bound&&p>=first&&p<last&&(p-first)%338==0)put(out+0xc8,(p-first)/338);memcpy(out+ROOT,d_bank,BANK);memcpy(out+ROOT+BANK,d_modules,168);memcpy(out+ROOT+BANK+168,&d_module_count,4);}
static void bind_root(void){uint32_t n=get(d_root+0xc8);pointer_bound=n>=1&&n<=114;if(pointer_bound)put(d_root+0xc8,(uint32_t)(uintptr_t)(d_bank+116+n*338));}
static uint32_t body_offset(uint32_t p){uintptr_t first=(uintptr_t)d_bank+116;if(p<first||p>=first+115*338||(p-first)%338){status=2;return 0xffffffff;}return p-(uint32_t)(uintptr_t)d_bank;}
uint32_t d_observe(uint32_t kind,uint32_t a,uint32_t b,uint32_t c){
 if(d_trace_count>=512)exit(98);d_trace[d_trace_count++]=kind;
 uint32_t argc=0,args[6]={0};
 if(kind==349){uint8_t*p=(uint8_t*)(uintptr_t)a;argc=4;args[0]=get(p);args[1]=args[0]==0x8635;args[2]=args[1]?get(p+12):0;args[3]=get(p+24);}
 else if(kind==1907){argc=2;args[0]=a;args[1]=b;}
 else if(kind==1344){argc=2;uintptr_t first=(uintptr_t)d_bank+116+0x124;if(a<first||a>=first+115*338||(a-first)%338){status=3;return 0;}args[0]=a-(uint32_t)(uintptr_t)d_bank;args[1]=b;}
 else if(kind==14400){kind=144;argc=6;uint8_t*p=(uint8_t*)(uintptr_t)a;args[0]=d_module;args[1]=11;args[2]=get(p);args[3]=body_offset(get(p+4));args[4]=p[8];args[5]=p[9];}
 else{status=4;return 0;}
 if(used>=64){status=5;exit(95);}uint8_t*row=output+BASE+used*SNAP;put(row,kind);put(row+4,argc);memcpy(row+8,args,24);capture(row+40);
 if(used>=input.header[3]){status=1;put(row+32,0);capture(row+40+OWNER);used++;return 0;}
 struct Script*s=&input.scripts[used];if(s->kind!=kind||s->argc!=argc||memcmp(s->args,args,24)){status=6;exit(96);}
 uint8_t logical[OWNER];capture(logical);
 for(uint32_t i=0;i<s->patch_count;i++){struct Patch*p=&s->patches[i];uint8_t*base=0;uint32_t size=0;if(p->owner==0){base=logical;size=ROOT;}else if(p->owner==1){base=d_bank;size=BANK;}else if(p->owner==2){base=d_modules;size=168;}else if(p->owner==3){base=(uint8_t*)&d_module_count;size=4;}if(!base||p->size>64||p->offset+p->size>size){status=7;exit(97);}memcpy(base+p->offset,p->data,p->size);}
 memcpy(d_root,logical,ROOT);bind_root();put(row+32,s->result);capture(row+40+OWNER);used++;return s->result;
}
int main(void){while(fread(&input,1,sizeof input,stdin)==sizeof input){
 memcpy(&saved_input,&input,sizeof input);memset(&d_root_store,0xa5,sizeof d_root_store);memset(&d_bank_store,0xa5,sizeof d_bank_store);memset(&d_module_store,0xa5,sizeof d_module_store);memset(&d_count_store,0xa5,sizeof d_count_store);
 memset(output,0,sizeof output);memcpy(d_root,input.root,ROOT);memcpy(d_bank,input.bank,BANK);memcpy(d_modules,input.modules,168);d_module_count=input.count;bind_root();memset(DATA_004681,0,1024);memset(descriptors,0,sizeof descriptors);memset(physical,0,sizeof physical);memset(collision,0,sizeof collision);
 for(uint32_t i=0;i<input.header[4];i++){struct Model*m=&input.models[i];if(m->index>=256)return 91;memcpy(descriptors[m->index],m->descriptor,68);memcpy(physical[m->index],m->physical,24);collision[m->index]=m->collision_first;put(descriptors[m->index]+0x34,m->collision_present?(uint32_t)(uintptr_t)&collision[m->index]:0);put(descriptors[m->index]+0x38,m->physical_present?(uint32_t)(uintptr_t)physical[m->index]:0);DATA_004681[m->index]=(uint32_t)(uintptr_t)descriptors[m->index];}
 used=status=d_trace_count=0;uint32_t result=call_kernel(input.header[1],input.header[2]);
 uint8_t guard[8];memset(guard,0xa5,8);if(memcmp(guard,d_root_store.before,8)||memcmp(guard,d_root_store.after,8)||memcmp(guard,d_bank_store.before,8)||memcmp(guard,d_bank_store.after,8)||memcmp(guard,d_module_store.before,8)||memcmp(guard,d_module_store.after,8)||memcmp(guard,d_count_store.before,8)||memcmp(guard,d_count_store.after,8))status=8;
 if(memcmp(&input,&saved_input,sizeof input))status=9;
 for(uint32_t i=0;i<input.header[4];i++){struct Model*m=&input.models[i];uint8_t expected[68];memcpy(expected,m->descriptor,68);put(expected+0x34,m->collision_present?(uint32_t)(uintptr_t)&collision[m->index]:0);put(expected+0x38,m->physical_present?(uint32_t)(uintptr_t)physical[m->index]:0);if(memcmp(expected,descriptors[m->index],68)||memcmp(m->physical,physical[m->index],24)||collision[m->index]!=(uint8_t)m->collision_first)status=10;}
 put(output,0x942926aa);put(output+4,BASE+used*SNAP);put(output+8,status);put(output+12,result);put(output+16,used);put(output+20,d_trace_count);capture(output+64);memcpy(output+64+OWNER,d_trace,d_trace_count*4);if(fwrite(output,1,BASE+used*SNAP,stdout)!=BASE+used*SNAP)return 92;
 }return 0;}
'''

def pack_resource(index,r):return struct.pack('<I',int(index))+bytes.fromhex(r['descriptor_hex'])+bytes.fromhex(r['physical_spec_hex']).ljust(24,b'\0')+struct.pack('<3I',r['collision_present'],r['collision_first_byte_u8'],bool(r['physical_spec_hex']))
def packet(row):
 ctx=row['context_before'];models=ctx['model_resources'];scripts=row['scripts'];raw=struct.pack('<16I',0,row['body_slot_u32'],row['attacker_u32'],len(scripts),len(models),*([0]*11))
 raw+=bytes.fromhex(ctx['root'])+bytes.fromhex(ctx['bank'])+bytes.fromhex(ctx['module_entries'])+struct.pack('<i',ctx['module_count_s32'])
 raw+=b''.join(pack_resource(i,r)for i,r in models.items())+bytes((MODELS-len(models))*MODEL_BYTES)
 for s in scripts:
  raw+=struct.pack('<16I',s['kind'],len(s['args']),*[v&0xffffffff for v in s['args']],*([0]*(6-len(s['args']))),s.get('return_u32',0),len(s.get('patches',[])),*([0]*6))
  for p in s.get('patches',[]):raw+=struct.pack('<4I',p['owner'],p['offset'],len(bytes.fromhex(p['hex'])),0)+bytes.fromhex(p['hex']).ljust(64,b'\0')
  raw+=bytes((12-len(s.get('patches',[])))*80)
 raw+=bytes((SCRIPTS-len(scripts))*SCRIPT)
 if len(raw)!=INPUT:raise ValueError(('Native destruction packet length',len(raw),INPUT))
 return raw
def context(raw,models):return {'root':raw[:ROOT].hex(),'bank':raw[ROOT:ROOT+BANK].hex(),'module_entries':raw[ROOT+BANK:ROOT+BANK+168].hex(),'module_count_s32':struct.unpack_from('<i',raw,ROOT+BANK+168)[0],'model_resources':copy.deepcopy(models)}
def decode(raw,row):
 h=struct.unpack_from('<16I',raw)
 if h[0]!=0x942926aa or h[1]!=len(raw)or h[2]or h[4]!=len(row['scripts'])or len(raw)!=BASE+h[4]*SNAP:raise ValueError(('Native destruction state failed',row['name'],h[:6],len(row['scripts'])))
 model=row['context_before']['model_resources'];order=list(struct.unpack_from('<%dI'%h[5],raw,64+OWNER));observations=[]
 for i in range(h[4]):
  at=BASE+i*SNAP;kind,argc=struct.unpack_from('<2I',raw,at);args=list(struct.unpack_from('<6I',raw,at+8))[:argc]
  observations.append({'kind':{349:'F349',1907:'F1907',1344:'F1344',144:'F144_handler'}[kind],'args':args,'before':context(raw[at+40:at+40+OWNER],model),'after':context(raw[at+40+OWNER:at+40+2*OWNER],model),'return_u32':struct.unpack_from('<I',raw,at+32)[0]})
 return {'context_after':context(raw[64:64+OWNER],model),'return_u32':h[3],'source_order':['F144_handler'if v==14400 else'F'+str(v)for v in order],'observations':observations}

def resource_map():
 old=json.loads((PROJECT/'data/ffe_object_factory.json').read_text())['models'];extra=json.loads((PROJECT/'data/ffe_effect_factory.json').read_text())['models'];return {**old,**extra}
def cases():
 resources=resource_map();rng=random.Random(0x942926);rows=[]
 def add(name,model=38,slot=37,attacker=0,available=114,recyclable=False,capacity=8,mass=None,selector=0,player=1):
  root=bytearray(ROOT);struct.pack_into('<II',root,0x24,rng.getrandbits(32),rng.getrandbits(32));struct.pack_into('<II',root,0xc0,player,0);struct.pack_into('<I',root,0xc8,player);struct.pack_into('<I',root,0x19c,rng.choice([0,65535,0x7fffffff,0xffffffff]));struct.pack_into('<I',root,0x114,0xfffffff0)
  bank=bytearray(bytes([1])*115+b'\xa7'+bytes(338)*115)
  for i in range(115):bank[116+i*338+0x86]=i
  if available:bank[available]=32 if recyclable else 0
  source=bytearray(rng.randbytes(338));source[0x86]=slot;source[0x87]=3;source[0x88]=rng.randrange(256);source[0x118]=selector;struct.pack_into('<I',source,0x82,model);struct.pack_into('<H',source,0x116,capacity);struct.pack_into('<I',source,0x11a,rng.choice([0,1,0xffffffff,0x80000000]));bank[116+slot*338:116+(slot+1)*338]=source;bank[116+player*338+0xca]|=0x40
  selected={str(i):copy.deepcopy(resources[str(i)])for i in sorted(set([model,153,155,38,0,14,24,63]))}
  if mass is not None:
   spec=bytearray.fromhex(selected[str(model)]['physical_spec_hex']);struct.pack_into('<h',spec,6,mass);selected[str(model)]['physical_spec_hex']=spec.hex()
  rows.append({'name':name,'body_slot_u32':slot,'attacker_u32':attacker,'context_before':{'root':root.hex(),'bank':bank.hex(),'module_entries':bytes(168).hex(),'module_count_s32':20,'model_resources':selected},'scripts':[]})
 for model in [0,1,14,15,24,38,63,64,117]:
  for available in [0,114]:add('model%d-available%d'%(model,available),model=model,available=available)
 for mass in [-32768,-1,0,9,10,11,399,400,401,32767]:add('source-mass-%d'%mass,mass=mass)
 for capacity in [0,1,2,3,4,7,8,9,65535]:add('cargo-capacity-%d'%capacity,capacity=capacity)
 for available in [1,19,20,21,37,113,114]:
  for recyclable in [False,True]:add('recycle-slot%d-%s'%(available,recyclable),available=available,recyclable=recyclable)
 for available in [0,37,114]:add('source-alias-selected%d'%available,slot=114,available=available,recyclable=available==114)
 for attacker in [0,1,2,0xffffffff]:
  for selector in [0,251,255]:add('reward-attacker%d-selector%d'%(attacker,selector),attacker=attacker,selector=selector)
 for i in range(36):add('rng-cargo-seed-%02d'%i,slot=[1,37,114][i%3],capacity=[0,2,8,65535][i%4],attacker=i%3,selector=[0,251,255][i%3])
 for i in range(24):
  add('actual-cargo-success-seed-%02d'%i,capacity=[2,4,8,65535][i%4]);row=rows[-1];b=bytearray.fromhex(row['context_before']['bank'])
  for index in range(90,115):b[index]=0
  row['context_before']['bank']=b.hex()
 for free,recycle in [(19,20),(19,19),(0,20),(20,19),(21,20)]:
  add('reserved-cargo-free%d-recycle%d'%(free,recycle));row=rows[-1];b=bytearray.fromhex(row['context_before']['bank']);b[free]=0;b[recycle]=0x20;row['context_before']['bank']=b.hex()
 for high in [-1,0,3,11,17,20]:
  add('inclusive-active-module-highest%d'%high,available=0);row=rows[-1];m=bytearray(MODULE)
  for index in range(21):m[index*8]=4
  row['context_before']['module_entries']=m.hex();row['context_before']['module_count_s32']=high
 for policy in ['bounty-reread','rank-wrap','sound5-model','sound31-scale','handler-shrink','handler-grow','name-rng-velocity','name-current-source']:
  add('callback-'+policy,attacker=1,selector=251,mass=400 if policy=='sound31-scale'else None);row=rows[-1];row['policy']=policy;b=bytearray.fromhex(row['context_before']['bank']);r=bytearray.fromhex(row['context_before']['root']);m=bytearray(MODULE)
  for index in range(100,115):b[index]=0
  struct.pack_into('<I',b,116+row['body_slot_u32']*338+0x11a,3)
  if policy=='rank-wrap':struct.pack_into('<I',r,0x19c,65535)
  if policy in ['handler-shrink','handler-grow']:
   for index in [3,11,17,20]:m[index*8]=4
   row['context_before']['module_count_s32']=3 if policy=='handler-grow' else 20
  row['context_before']['root']=r.hex();row['context_before']['bank']=b.hex();row['context_before']['module_entries']=m.hex()
 for physical,logical in [(0,114),(37,1),(114,0),(23,114)]:
  add('physical-pointer%d-record-index%d'%(physical,logical),slot=physical);row=rows[-1];b=bytearray.fromhex(row['context_before']['bank']);b[116+physical*338+0x86]=logical;row['context_before']['bank']=b.hex()
 for pointer in [0,0xffffffff,0xdeadbeef]:
  add('unused-player-pointer-%08x'%pointer,attacker=0);r=bytearray.fromhex(rows[-1]['context_before']['root']);struct.pack_into('<I',r,0xc8,pointer);rows[-1]['context_before']['root']=r.hex()
 for low,high in [(0,0),(0xffffffff,0),(0xffffffff,0x7fffffff),(0,0x80000000),(0xffffffff,0xffffffff),(0,0xffffffff)]:
  add('cargo-position-words-%08x-%08x'%(low,high));row=rows[-1];b=bytearray.fromhex(row['context_before']['bank']);at=116+row['body_slot_u32']*338
  for index in range(90,115):b[index]=0
  for axis in range(3):struct.pack_into('<II',b,at+0x3e+axis*8,low,high)
  row['context_before']['bank']=b.hex();row['position_boundary_words']=[low,high]
 return rows

def provider_patches(row,kind,args):
 policy=row.get('policy');at=116+row['body_slot_u32']*338
 def patch(owner,offset,raw):return {'owner':owner,'offset':offset,'hex':raw.hex()}
 if policy=='bounty-reread'and kind==349 and args[0]==0x8635:return [patch(1,at+0x11a,struct.pack('<I',0xffffffff)),patch(0,0xc0,struct.pack('<I',0))]
 if policy=='sound5-model'and kind==1907 and args[0]==5:return [patch(1,at+0x82,struct.pack('<I',24))]
 if policy=='sound31-scale'and kind==1907 and args[0]==31:return [patch(1,at+0x82,struct.pack('<I',24))]
 if policy=='handler-shrink'and kind==144 and args[0]==3:return [patch(3,0,struct.pack('<i',-1)),patch(1,at+0x86,b'\x72')]
 if policy=='handler-grow'and kind==144 and args[0]==3:return [patch(3,0,struct.pack('<i',20)),patch(2,11*8,b'\x04')]
 if kind==1344:
  out=[patch(1,args[0],b'EXPLICIT ITEM\0')]
  if policy=='name-rng-velocity':out+=[patch(0,0x24,struct.pack('<II',0xffffffff,0x80000000)),patch(1,args[0]-0x124+0x8c,struct.pack('<iii',0x7fffffff,-0x80000000,-1))]
  if policy=='name-current-source':out+=[patch(1,at+0x116,struct.pack('<H',0)),patch(1,at+0x82,struct.pack('<I',14))]
  return out
 return []

def build(meta,source,directory):
 p=Path(directory);native=assembly(source,meta);(p/'native.s').write_text(native);(p/'support.c').write_text(C)
 subprocess.run(['gcc','-O1','-fno-pie','-no-pie','-fno-stack-protector','-o',str(p/'native'),str(p/'native.s'),str(p/'support.c')],check=True)
 return p/'native',native
def run(binary,row,allow_pending=False):
 done=subprocess.run([str(binary)],input=packet(row),capture_output=True,timeout=30)
 if done.returncode or done.stderr:raise ValueError(('Native execution failed',row['name'],done.returncode,done.stderr[:300]))
 raw=done.stdout
 if allow_pending:return raw
 return raw,decode(raw,row)
def fill_scripts(binary,row):
 for _ in range(64):
  raw=run(binary,row,True);h=struct.unpack_from('<16I',raw)
  if h[2]==0:return raw
  if h[2]!=1 or h[4]<len(row['scripts'])+1:raise ValueError(('Unexpected native pending',row['name'],h[:6]))
  at=BASE+len(row['scripts'])*SNAP;kind,argc=struct.unpack_from('<2I',raw,at);args=list(struct.unpack_from('<6I',raw,at+8))[:argc]
  # Explicit authored provider, never a fabricated implicit successful result.
  row['scripts'].append({'kind':kind,'args':args,'return_u32':0,'patches':provider_patches(row,kind,args)})
 raise ValueError('Too many source callbacks')
def pool_document(rows):
 buffers={}
 def intern(raw):
  key=sha(raw)
  if key not in buffers:buffers[key]={'byte_count':len(raw),'zlib_base64':base64.b64encode(zlib.compress(raw,9)).decode()}
  return key
 def ctx(c):
  r=copy.deepcopy(c)
  for key in ['root','bank','module_entries']:r[key]=intern(bytes.fromhex(r[key]))
  return r
 out=[]
 for row in rows:
  r=copy.deepcopy(row);r['context_before']=ctx(r['context_before']);r['expected']['context_after']=ctx(r['expected']['context_after'])
  for o in r['observations']:o['before']=ctx(o['before']);o['after']=ctx(o['after'])
  out.append(r)
 return buffers,out
def raw_row(row,buffers):
 def ctx(value):
  out=copy.deepcopy(value)
  for key in ['root','bank','module_entries']:
   reference=out[key]
   if reference in buffers:
    item=buffers[reference];raw=zlib.decompress(base64.b64decode(item['zlib_base64']))
    if len(raw)!=item['byte_count']or sha(raw)!=reference:raise ValueError('Native destruction pooled buffer differs')
    out[key]=raw.hex()
  return out
 out=copy.deepcopy(row);out['context_before']=ctx(out['context_before'])
 if 'expected'in out:out['expected']['context_after']=ctx(out['expected']['context_after'])
 for o in out.get('observations',[]):o['before']=ctx(o['before']);o['after']=ctx(o['after'])
 return out
def generate(a):
 meta,source=verify(a.proof_dir);rows=cases()
 with tempfile.TemporaryDirectory(prefix='destruction-native-')as d:
  binary,native=build(meta,source,d)
  for row in rows:
   if 'position_boundary_words'in row:
    seed=next(r for r in rows if r.get('expected',{}).get('source_order',[]).count('F1514')>0 and r['name'].startswith('actual-cargo-success'))
    root=bytearray.fromhex(row['context_before']['root']);root[0x24:0x2c]=bytes.fromhex(seed['context_before']['root'])[0x24:0x2c];row['context_before']['root']=root.hex();row['seed_selected_from_measured_cargo_success']=seed['name']
   raw=fill_scripts(binary,row);expected=decode(raw,row);row['observations']=expected.pop('observations');row['expected']=expected
   if 'position_boundary_words'in row and 'F1514'not in expected['source_order']:raise ValueError('Directed source F1514 edge was not executed')
  previous=copy.deepcopy(next(r['expected']['context_after']for r in rows if r['name']=='actual-cargo-success-seed-00'))
  for step in range(12):
   row={'name':'dependent-native-step-%02d'%step,'body_slot_u32':[37,114,113][step%3],'attacker_u32':0,'context_before':copy.deepcopy(previous),'scripts':[],'carries_previous_native_state':True}
   raw=fill_scripts(binary,row);expected=decode(raw,row);row['observations']=expected.pop('observations');row['expected']=expected;rows.append(row);previous=copy.deepcopy(expected['context_after'])
  # Repeat complete original programs in fresh processes, retaining explicit replies.
  outputs=[]
  for row in rows:outputs.append(run(binary,row)[0])
  for _ in range(2):
   if [run(binary,row)[0]for row in rows]!=outputs:raise ValueError('Fresh native destruction outputs differ')
  if [run(binary,row)[0]for row in reversed(rows)]!=list(reversed(outputs)):raise ValueError('Native destruction reverse outputs differ')
 buffers,encoded=pool_document(rows)
 dependencies=['tools/rebuild_source_destruction_native.py','tools/rebuild_source_natural_contact_native.py','tools/rebuild_source_damage_native.py','data/ffe_object_factory.json','data/ffe_effect_factory.json','data/ffe_ground_coordinates.json']
 doc={'schema':'starfrontier-source-destruction-native-v1','profile':PROFILE,'case_count':len(rows),'source_executable_sha256':N.EXE_SHA,'instruction_proof_sha256':sha((a.proof_dir/'instruction-proof.json').read_bytes()),'source_procedures_sha256':sha(source.encode()),'host_assembly_sha256':sha(native.encode()),'host_support_sha256':sha(C.encode()),'whole_original_procedures':len(NUMBERS),'whole_original_instructions':sum(r['instruction_count']for r in meta['procedures'].values()),'source_dependencies_sha256':{p:sha((PROJECT/p).read_bytes())for p in dependencies},'fresh_process_runs':3,'reverse_repeat_cases':len(rows),'consecutive_native_steps':12,'actual_F926_attempts':sum(r['expected']['source_order'].count('F926')for r in rows),'actual_cargo_allocations':sum(r['expected']['source_order'].count('F1514')for r in rows),'actual_explosion_matrices':sum(r['expected']['source_order'].count('F1675')for r in rows),'position_boundary_controls':sum('position_boundary_words'in r for r in rows),'all_owner_boundary_canaries_unchanged':True,'all_readonly_input_resource_bytes_unchanged':True,'expected_arithmetic_calculated_in_python':False,'cargo_table_hex':meta['cargo_table_hex'],'external_callback_count':sum(len(r['observations'])for r in rows),'buffer_codec':'sha256-zlib-base64-v1','buffers':buffers,'scope':meta['scope'],'cases':encoded}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(doc,indent=2)+'\n');(a.proof_dir/'destruction-native.s').write_text(native);(a.proof_dir/'destruction-support.c').write_text(C)
 print(json.dumps({'case_count':len(rows),'fixture_sha256':sha(a.output.read_bytes()),'callbacks':doc['external_callback_count'],'cargo_table_hex':meta['cargo_table_hex']}))
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--refresh-original-proof',action='store_true');a=p.parse_args()
 if a.refresh_original_proof:prepare(a)
 generate(a)
if __name__=='__main__':main()
