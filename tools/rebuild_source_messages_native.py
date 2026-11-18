#!/usr/bin/env python3
"""Whole original message routing and real F271 ring backend; explicit text/UI providers."""
from __future__ import annotations
import argparse,base64,copy,hashlib,inspect,json,random,re,struct,subprocess,tempfile,zlib
from pathlib import Path
import rebuild_source_natural_contact_native as N
import rebuild_source_equipment_native as E
PROJECT=N.PROJECT;PROOF=PROJECT/'validation/events-messages-2026-11-18/messages-native-proof';FIXTURE=PROJECT/'tests/fixtures/source_messages_native.json'
NUMBERS=[349,350,351,352,271];PROFILE='dos-firstenc-message-backend-v1'
KEYS=['root','bank','packet','queue_records','queue_control','fallback_name'];SIZES=[16384,38986,48,10380,36,612];OWNER=sum(SIZES)
BASE=64+OWNER+512*4;SCRIPT=4096;MAX=16;TRACE=48+2*OWNER+2048;INPUT=64+OWNER+1024+MAX*SCRIPT
sha=lambda raw:hashlib.sha256(raw).hexdigest()
def canonical(rows):
 result=[]
 for line in N.canonical(rows):
  match=re.fullmatch(r'xchg ([a-z]+),([a-z]+)',line)
  result.append('xchg '+','.join(sorted(match.groups()))if match else line)
 return result
def prepare(a):
 exe=a.exe.read_bytes();asm=a.asm.read_bytes()
 if sha(exe)!=N.EXE_SHA or sha(asm)!=N.ASM_SHA:raise ValueError('Original message input identities differ')
 anchor=E.verify()[0]['source_symbol_addresses']['FUNC_000349'];resolver=inspect.getsource(N.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_000349',%d)"%anchor).replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
 ns=N.__dict__.copy();ns['canonical']=canonical;exec(resolver,ns);bodies,records,dis,_,aliases=ns['proof'](asm.decode().replace('\r\n','\n'),a.data.read_text(),exe,a.exe,NUMBERS)
 source='\n'.join(bodies[n]for n in NUMBERS)
 if aliases['DATA_008870']!=aliases['DATA_008804']+0xe8 or aliases['DATA_008807']!=aliases['DATA_008804']+4:raise ValueError('Actual DOS Root mode/clock aliases differ')
 for r in records.values():r['hex']=exe[r['executable_offset']:r['executable_offset']+r['byte_length']].hex()
 meta={'schema':'starfrontier-message-original-proof-v1','source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'source_procedures_sha256':sha(source.encode()),'bindings':aliases,'procedures':records,'all_whole_instructions_equal':True,'host_adaptations':['Original complete procedures independently assembled asIA32 and compared with original DOS.','Reviewed ELF64 cdecl8byte argument slots and low-address source32 buffers; sourceinteger/byte/packedqueue arithmetic retained.','Message+1c actor bodyoffset temporarily binds to suppliedbank pointer and normalizes in snapshots; opaqueunused words remainopaque.','F1344 observes5fullyspecifiedformatterwords plus typedactornamebinding; no uninitialized output scratch is read.','F1398 observes copiedwrapped scratch; originalunwrapped formatter input is separately retained by actual F271.','Whole F271 original10record/1038byte ring and control words execute, with sourceRootclock and separateanimationclock owners.','Menu selection F217, sound F1906, formatting F1344 and wrapping F1398 remain explicit typed provider bodies.','EAX from void message entrypoints is intentionally excluded from portable outputs; no hostpointer return is serialized.']}
 meta['host_adaptations']+=['The two original XCHG EDI/ESI instructions admit symmetric register-operand encodings; those pure register swaps are normalized before exact instruction comparison.','Original symbol-immediate address additions use explicit GAS OFFSET syntax; source absolute data loads remain loads.']
 meta['packet_input_policy']='Explicitly fully specified48-byte raw caller packet; not invented initialization of unspecified words in legacy equipment/bounty/rank caller stack packets.'
 meta['queue_control_symbols']=['DATA_%06d'%n for n in [5092,5093,5094,5096,5097,5098,5099,8677,8799]]
 meta['original_callback_words']=[]
 image=N.G.Image(exe)
 for symbol,target in [('DATA_004920','FUNC_000217'),('DATA_007639','FUNC_001344'),('DATA_007643','FUNC_001398')]:
  offset=image.offset(aliases[symbol],4);value=struct.unpack_from('<I',exe,offset)[0]
  if value!=aliases[target]:raise ValueError('Original message callback word differs '+symbol)
  meta['original_callback_words'].append({'symbol':symbol,'virtual_address':aliases[symbol],'file_offset':offset,'target':target,'target_virtual_address':value})
 a.proof_dir.mkdir(parents=True,exist_ok=True);(a.proof_dir/'source-procedures.asm').write_text(source);(a.proof_dir/'instruction-proof.json').write_text(json.dumps(meta,indent=2)+'\n');(a.proof_dir/'dos-disassembly.txt').write_text(''.join('F'+n+'\n'+s for n,s in dis.items()))
 return meta,source
def verify(proof=PROOF):
 m=json.loads((proof/'instruction-proof.json').read_text());s=(proof/'source-procedures.asm').read_text()
 if m['source_executable_sha256']!=N.EXE_SHA or m['source_assembly_sha256']!=N.ASM_SHA or sha(s.encode())!=m['source_procedures_sha256']:raise ValueError('Archived message proof differs')
 for n in NUMBERS:
  r=m['procedures'][str(n)];rows=N.C.J.instructions(N.C.compile32(N.G.block(s,n),m['bindings'],'FUNC_%06d'%n,r['virtual_address']))
  if len(rows)!=r['instruction_count']or sha('\n'.join(canonical(rows)).encode())!=r['normalized_instruction_sha256']:raise ValueError('Original message instructions differ F%d'%n)
 return m,s
def trace(n):return 'pushfq\npush rax\npush rcx\nmov ecx,DWORD PTR [m_order_count]\ncmp ecx,512\njae m_abort\nmov DWORD PTR [m_order+rcx*4],%d\ninc DWORD PTR [m_order_count]\npop rcx\npop rax\npopfq\n'%n
def assembly(source):
 source=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',source)
 source=re.sub(r'\+0x(f[0-9a-f]{7})',lambda m:'-0x%x'%(0x100000000-int(m[1],16)),source)
 source=re.sub(r'add esp,0x(f[0-9a-f]{7})',lambda m:'add esp,-0x%x'%(0x100000000-int(m[1],16)),source)
 lines,_=N.Q.procedures(source+'\nFUNC_999999:\nret\n',NUMBERS);text='\n'.join(lines)
 text=re.sub(r'(,\s*)(DATA_\d+|FUNC_\d+)$',r'\1OFFSET FLAT:\2',text,flags=re.M)
 for n in NUMBERS:text=text.replace('FUNC_%06d:\n'%n,'FUNC_%06d:\n'%n+trace(n),1)
 # SourceF350 makes its branch before the formatter call; record that branch's
 # pointer type without replacing its actual parameter construction.
 text=text.replace('FUNC_000350:\n','FUNC_000350:\n'+'''pushfq
push rax
mov eax,DWORD PTR [rsp+24]
mov eax,DWORD PTR [rax+24]
shr eax,31
mov DWORD PTR [m_actor_mode],eax
mov eax,DWORD PTR [rsp+24]
mov eax,DWORD PTR [rax+24]
or DWORD PTR [m_actor_mode],eax
and DWORD PTR [m_actor_mode],0x80000001
pop rax
popfq
''',1)
 support=[]
 for n,argc in [(217,0),(1906,1),(1344,3),(1398,2)]:
  loads=['xor esi,esi','xor edx,edx','xor ecx,ecx']
  for i,reg in enumerate(['esi','edx','ecx'][:argc]):loads.append('mov %s,DWORD PTR [rbp+%d]'%(reg,16+8*i))
  support.append('FUNC_%06d:\n'%n+'''push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
'''+ '\n'.join(loads)+'''\nmov edi,%d
and rsp,-16
call m_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret
'''%n)
 aliases=[];at=8
 for key,size in zip(KEYS,SIZES):aliases.append('m_%s=m_store+%d'%(key,at));at+=size
 aliases+=['DATA_008804=m_root','DATA_008807=m_root+4','DATA_008870=m_root+0xe8','DATA_009148=m_fallback_name','DATA_008678=m_queue_records','DATA_008679=m_queue_records+4','DATA_008680=m_queue_records+8','DATA_008681=m_queue_records+9','DATA_008682=m_queue_records+1034','DATA_005092=m_queue_control','DATA_005093=m_queue_control+4','DATA_005094=m_queue_control+8','DATA_005096=m_queue_control+12','DATA_005097=m_queue_control+16','DATA_005098=m_queue_control+20','DATA_005099=m_queue_control+24','DATA_008677=m_queue_control+28','DATA_008799=m_queue_control+32']
 entry='''.global call_kernel
call_kernel:
mov [m_saved_rsp],rsp
mov esp,OFFSET FLAT:m_stack_end
cmp edi,4
je m_direct_queue
cmp edi,1
je m_direct_format
push OFFSET FLAT:m_packet
cmp edi,2
je m_notify
cmp edi,3
je m_immediate
call FUNC_000349
jmp m_leave
m_notify:call FUNC_000351
jmp m_leave
m_immediate:call FUNC_000352
jmp m_leave
m_direct_format:
push rsi
push OFFSET FLAT:m_packet
call FUNC_000350
jmp m_leave
m_direct_queue:
push 0
push 0
xor eax,eax
test edx,edx
jz m_text_ready
mov eax,OFFSET FLAT:m_text
m_text_ready:push rax
call FUNC_000271
m_leave:mov rsp,[m_saved_rsp]
ret
m_abort:mov edi,97
mov eax,60
syscall
'''
 return '.intel_syntax noprefix\n.code64\n.section .text\n'+text+'\n'+entry+'\n'+'\n'.join(support)+'\n.section .data\nDATA_004920:.quad FUNC_000217\nDATA_007639:.quad FUNC_001344\nDATA_007643:.quad FUNC_001398\n'+'\n'.join(aliases)+'\n.section .bss\n.balign 16\nm_stack:.zero 1048576\nm_stack_end:\nm_saved_rsp:.zero 8\n.section .note.GNU-stack,"",@progbits\n'

C=r'''
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define OWNER 66446
#define BASE (64+OWNER+2048)
#define TRACE (48+2*OWNER+2048)
struct __attribute__((packed)) Patch{uint32_t owner,offset,size,reserved;uint8_t data[64];};
struct __attribute__((packed)) Script{uint32_t kind,argc,args[7],result,patch_count,text_size,pad[4];uint8_t text[1024];struct Patch patches[12];uint8_t unused[2048];};
struct __attribute__((packed)) Input{uint32_t header[16];uint8_t owners[OWNER],text[1024];struct Script scripts[16];};
uint8_t m_store[OWNER+16],m_text[1024];uint32_t m_order[512],m_order_count,m_actor_mode;
extern void call_kernel(uint32_t,uint32_t,uint32_t);
static struct Input input,saved_input;static uint8_t output[BASE+16*TRACE];static uint32_t used,status,actor_bound;
static const uint32_t sizes[6]={16384,38986,48,10380,36,612},offsets[6]={0,16384,55370,55418,65798,65834};
#define ROOT (m_store+8)
#define BANK (m_store+8+16384)
#define PACKET (m_store+8+55370)
#define FALLBACK (m_store+8+65834)
static uint32_t get(const void*p){uint32_t v;memcpy(&v,p,4);return v;}static void put(void*p,uint32_t v){memcpy(p,&v,4);}
static void bind(void){uint32_t v=get(PACKET+28);actor_bound=v>=116&&v+338<=38986&&(v-116)%338==0;if(actor_bound)put(PACKET+28,(uint32_t)(uintptr_t)(BANK+v));}
static void capture(uint8_t*out){memcpy(out,m_store+8,OWNER);if(actor_bound)put(out+55370+28,get(PACKET+28)-(uint32_t)(uintptr_t)BANK);}
static uint32_t cstring(uint8_t*to,const uint8_t*from){for(uint32_t i=0;i<1024;i++){to[i]=from[i];if(!from[i])return i+1;}exit(94);}
uint32_t m_observe(uint32_t kind,uint32_t a,uint32_t b,uint32_t c){
 uint32_t args[7]={0},argc=0,in_size=0;uint8_t input_text[1024]={0};uint32_t dest=0;
 if(m_order_count>=512)exit(95);m_order[m_order_count++]=kind;
 if(kind==217)argc=0;
 else if(kind==1906){argc=1;args[0]=a;}
 else if(kind==1344){argc=7;dest=a;args[0]=b;memcpy(args+1,(void*)(uintptr_t)c,20);if(m_actor_mode==0){uintptr_t ptr=args[5];if(ptr==(uintptr_t)FALLBACK){args[5]=0;args[6]=2;}else if(ptr>=(uintptr_t)BANK+116+0x124&&ptr<(uintptr_t)BANK+38986&&(ptr-(uintptr_t)BANK-116-0x124)%338==0){args[5]=ptr-(uintptr_t)BANK;args[6]=1;}else exit(96);}}
 else if(kind==1398){argc=1;args[0]=b;dest=a;in_size=cstring(input_text,(void*)(uintptr_t)a);}
 else exit(97);
 if(used>=16)exit(98);uint8_t*row=output+BASE+used*TRACE;put(row,kind);put(row+4,argc);memcpy(row+8,args,28);put(row+40,in_size);memcpy(row+48+2*OWNER,input_text,in_size);capture(row+48);
 uint32_t result=0,out_size=0;
 if(used>=input.header[2]){status=1;if(kind==1344||kind==1398){((uint8_t*)(uintptr_t)dest)[0]=0;out_size=1;}}
 else{struct Script*s=&input.scripts[used];if(s->kind!=kind||s->argc!=argc||memcmp(s->args,args,28))exit(99);uint8_t logical[OWNER];capture(logical);for(uint32_t i=0;i<s->patch_count;i++){struct Patch*p=&s->patches[i];if(p->owner>=6||p->size>64||p->offset+p->size>sizes[p->owner])exit(100);memcpy(logical+offsets[p->owner]+p->offset,p->data,p->size);}memcpy(m_store+8,logical,OWNER);bind();result=s->result;if(kind==1344||kind==1398){if(!s->text_size||s->text_size>1024||s->text[s->text_size-1]||memchr(s->text,0,s->text_size-1))exit(101);memcpy((void*)(uintptr_t)dest,s->text,s->text_size);out_size=s->text_size;}else if(s->text_size)exit(102);}
 put(row+36,result);put(row+44,out_size);capture(row+48+OWNER);if(out_size)memcpy(row+48+2*OWNER+1024,(void*)(uintptr_t)dest,out_size);used++;return result;
}
int main(void){while(fread(&input,1,sizeof input,stdin)==sizeof input){memcpy(&saved_input,&input,sizeof input);memset(m_store,0xa5,sizeof m_store);memcpy(m_store+8,input.owners,OWNER);memcpy(m_text,input.text,1024);bind();used=status=m_order_count=0;memset(output,0,sizeof output);call_kernel(input.header[0],input.header[1],input.header[3]);if(memcmp(&input,&saved_input,sizeof input))status=2;uint8_t guard[8];memset(guard,0xa5,8);if(memcmp(m_store,guard,8)||memcmp(m_store+8+OWNER,guard,8))status=3;put(output,0x349271aa);put(output+4,BASE+used*TRACE);put(output+8,status);put(output+12,used);put(output+16,m_order_count);capture(output+64);memcpy(output+64+OWNER,m_order,m_order_count*4);if(fwrite(output,1,BASE+used*TRACE,stdout)!=BASE+used*TRACE)return 103;}return 0;}
'''
def context(raw):
 out={};at=0
 for key,size in zip(KEYS,SIZES):out[key]=raw[at:at+size].hex();at+=size
 return out
def packet(row):
 scripts=row['scripts'];text=bytes.fromhex(row.get('submitted_text_hex',''));raw=struct.pack('<16I',row['operation_u32'],row['display_mode_s32']&0xffffffff,len(scripts),bool(text),*([0]*12))+b''.join(bytes.fromhex(row['context_before'][key])for key in KEYS)+text.ljust(1024,b'\0')
 for script in scripts:
  out=bytes.fromhex(script.get('output_text_hex',''));raw+=struct.pack('<16I',script['kind'],len(script['args']),*[v&0xffffffff for v in script['args']],*([0]*(7-len(script['args']))),script.get('return_u32',0),len(script.get('patches',[])),len(out),*([0]*4))+out.ljust(1024,b'\0')
  for p in script.get('patches',[]):raw+=struct.pack('<4I',p['owner'],p['offset'],len(bytes.fromhex(p['hex'])),0)+bytes.fromhex(p['hex']).ljust(64,b'\0')
  raw+=bytes((12-len(script.get('patches',[])))*80)+bytes(2048)
 raw+=bytes((MAX-len(scripts))*SCRIPT)
 if len(raw)!=INPUT:raise ValueError(('Message packet width differs',len(raw),INPUT))
 return raw
def decode(raw,row):
 h=struct.unpack_from('<16I',raw)
 if h[0]!=0x349271aa or h[1]!=len(raw)or h[2]or h[3]!=len(row['scripts'])or len(raw)!=BASE+h[3]*TRACE:raise ValueError(('Message native guards differ',row['name'],h[:5]))
 obs=[]
 for i in range(h[3]):
  at=BASE+i*TRACE;kind,argc=struct.unpack_from('<2I',raw,at);args=list(struct.unpack_from('<7I',raw,at+8))[:argc];result,ins,outs=struct.unpack_from('<3I',raw,at+36)
  obs.append({'kind':'F'+str(kind),'args':args,'before':context(raw[at+48:at+48+OWNER]),'after':context(raw[at+48+OWNER:at+48+2*OWNER]),'return_u32':result,'input_text_hex':raw[at+48+2*OWNER:at+48+2*OWNER+ins].hex(),'output_text_hex':raw[at+48+2*OWNER+1024:at+48+2*OWNER+1024+outs].hex()})
 return {'context_after':context(raw[64:64+OWNER]),'source_order':['F'+str(v)for v in struct.unpack_from('<%dI'%h[4],raw,64+OWNER)],'observations':obs}
def build(m,s,directory):
 p=Path(directory);native=assembly(s);(p/'native.s').write_text(native);(p/'support.c').write_text(C);subprocess.run(['gcc','-O1','-fno-pie','-no-pie','-fno-stack-protector','-o',str(p/'native'),str(p/'native.s'),str(p/'support.c')],check=True);return p/'native',native
def run(binary,row,pending=False):
 p=subprocess.run([str(binary)],input=packet(row),capture_output=True,timeout=15)
 if p.returncode or p.stderr:raise ValueError(('Message native execution failed',row['name'],p.returncode,p.stderr[:200]))
 return p.stdout if pending else(p.stdout,decode(p.stdout,row))
def provider(row,kind,args):
 patches=[];name=row.get('policy','')
 def p(owner,offset,data):return {'owner':owner,'offset':offset,'hex':data.hex()}
 if name=='menu-skip'and kind==217:patches=[p(0,0xe8,b'\x2c')]
 if name=='menu-format'and kind==217:patches=[p(0,0xe8,b'\x04')]
 if name=='sound-packet-reread'and kind==1906:patches=[p(0,0xe8,b'\x2c'),p(2,0x18,struct.pack('<I',0xffffffff)),p(2,4,struct.pack('<I',0xabcdef12))]
 if name=='formatter-clock'and kind==1344:patches=[p(0,0,struct.pack('<II',0xffffffff,0x121cf8))]
 if name=='wrap-cursor'and kind==1398:patches=[p(4,24,struct.pack('<I',9)),p(4,12,struct.pack('<i',-0x80000000)),p(4,32,struct.pack('<I',0xdeadbeef))]
 text=b''
 if kind==1344:text=('Explicit message %s'%row['name']).encode()+b'\0'
 if kind==1398:text=(b'wrapped\r'*((row.get('lines',3))))+b'END\0'
 if name=='maximum-cstring'and kind==1344:text=b'A'*1023+b'\0'
 if name=='maximum-cstring'and kind==1398:text=b'\r'*1023+b'\0'
 if name=='empty-formatter'and kind in [1344,1398]:text=b'\0'
 return {'kind':kind,'args':args,'return_u32':0,'patches':patches,'output_text_hex':text.hex()}
def fill_scripts(binary,row):
 for _ in range(16):
  raw=run(binary,row,True);h=struct.unpack_from('<16I',raw)
  if h[2]==0:return raw
  if h[2]!=1 or h[3]<=len(row['scripts']):raise ValueError(('Unknown pending message status',h[:5]))
  at=BASE+len(row['scripts'])*TRACE;kind,argc=struct.unpack_from('<2I',raw,at);args=list(struct.unpack_from('<7I',raw,at+8))[:argc];row['scripts'].append(provider(row,kind,args))
 raise ValueError('Too many message boundaries')
def cases():
 rng=random.Random(0x349271);rows=[]
 for op in range(5):
  for mode in [0,4,44,255]:
   for flags in [0x80000000,0xffffffff,0,1,2,0x7fffffff]:
    root=bytearray(16384);struct.pack_into('<II',root,0,rng.getrandbits(32),rng.getrandbits(32));root[0xe8]=mode
    bank=bytearray(38986);packet_raw=bytearray(rng.randbytes(48));struct.pack_into('<I',packet_raw,0,rng.choice([0x98c8,0x98ca,0x8635,0x98cf,0x9917]));struct.pack_into('<I',packet_raw,24,flags);actor=rng.choice([0,116+338,116+114*338]);struct.pack_into('<I',packet_raw,28,actor)
    controls=bytearray(36);cursor=len(rows)%10
    for index in [4,5,6]:struct.pack_into('<I',controls,index*4,cursor)
    struct.pack_into('<i',controls,12,rng.choice([-0x80000000,-24,0,24,0x7fffffff]));struct.pack_into('<I',controls,32,rng.getrandbits(32));records=bytearray(b'\xa7'*10380);struct.pack_into('<I',records,cursor*1038+1034,len(rows)%2)
    rows.append({'name':'op%d-mode%d-flags%08x'%(op,mode,flags),'operation_u32':op,'display_mode_s32':0 if len(rows)%2 else 1,'submitted_text_hex':('input\rmessage\0'.encode().hex()if op==4 and len(rows)%3 else''),'lines':len(rows)%9,'context_before':{'root':root.hex(),'bank':bank.hex(),'packet':packet_raw.hex(),'queue_records':records.hex(),'queue_control':controls.hex(),'fallback_name':bytes(612).hex()},'scripts':[]})
 for policy in ['menu-skip','menu-format','sound-packet-reread','formatter-clock','wrap-cursor','maximum-cstring','empty-formatter']:
  row=copy.deepcopy(rows[2]);row['name']='callback-'+policy;row['policy']=policy;row['scripts']=[];r=bytearray.fromhex(row['context_before']['root']);r[0xe8]=0;row['context_before']['root']=r.hex();rows.append(row)
 for lines,offset in [(0,0x7fffffe8),(3,-0x80000000),(3,0),(0,-24)]:
  row=copy.deepcopy(rows[24]);row['name']='wrapped-height-lines%d-offset%d'%(lines,offset);row['lines']=lines;row['scripts']=[];c=bytearray.fromhex(row['context_before']['queue_control']);struct.pack_into('<i',c,12,offset);row['context_before']['queue_control']=c.hex();rows.append(row)
 for text in ['', '00']:
  row=copy.deepcopy(rows[96]);row.update(name='null-pointer-dismiss'if not text else'nonnull-empty-cstring-enqueue',submitted_text_hex=text,lines=0,scripts=[]);rows.append(row)
 for pointer in [0xffffffff,0xdeadbeef]:
  row=copy.deepcopy(rows[0]);row['name']='opaque-unused-actor-%08x'%pointer;p=bytearray.fromhex(row['context_before']['packet']);struct.pack_into('<I',p,28,pointer);row['context_before']['packet']=p.hex();row['scripts']=[];rows.append(row)
 return rows
def raw_row(row,buffers):
 r=copy.deepcopy(row)
 def ctx(v):
  x=copy.deepcopy(v)
  for k in KEYS:
   if x[k]in buffers:
    item=buffers[x[k]];b=zlib.decompress(base64.b64decode(item['zlib_base64']))
    if sha(b)!=x[k]or len(b)!=item['byte_count']:raise ValueError('Message pool buffer differs')
    x[k]=b.hex()
  return x
 r['context_before']=ctx(r['context_before'])
 if 'expected'in r:r['expected']['context_after']=ctx(r['expected']['context_after'])
 for o in r.get('observations',[]):o['before']=ctx(o['before']);o['after']=ctx(o['after'])
 return r
def generate(a):
 m,s=verify(a.proof_dir);rows=cases()
 with tempfile.TemporaryDirectory(prefix='messages-native-')as tmp:
  binary,native=build(m,s,tmp)
  for row in rows:
   raw=fill_scripts(binary,row);out=decode(raw,row);row['observations']=out.pop('observations');row['expected']=out
  previous=copy.deepcopy(rows[0]['context_before']);previous['queue_records']=bytes(10380).hex()
  for i in range(16):
   row={'name':'dependent-ring-step%02d'%i,'operation_u32':3 if i%4==0 else 4,'display_mode_s32':1,'submitted_text_hex':b'next\rentry\0'.hex()if i%4==2 else'','lines':i%7,'context_before':previous,'scripts':[],'carries_previous_native_state':True};raw=fill_scripts(binary,row);out=decode(raw,row);row['observations']=out.pop('observations');row['expected']=out;rows.append(row);previous=copy.deepcopy(out['context_after'])
  outputs=[run(binary,r)[0]for r in rows]
  for _ in range(2):
   if [run(binary,r)[0]for r in rows]!=outputs:raise ValueError('Message fresh processes differ')
  if [run(binary,r)[0]for r in reversed(rows)]!=list(reversed(outputs)):raise ValueError('Message reverse processes differ')
 buffers={}
 def ctx(v):
  out={}
  for k in KEYS:
   b=bytes.fromhex(v[k]);h=sha(b);buffers.setdefault(h,{'byte_count':len(b),'zlib_base64':base64.b64encode(zlib.compress(b,9)).decode()});out[k]=h
  return out
 for row in rows:
  row['context_before']=ctx(row['context_before']);row['expected']['context_after']=ctx(row['expected']['context_after'])
  for o in row['observations']:o['before']=ctx(o['before']);o['after']=ctx(o['after'])
 paths=['tools/rebuild_source_messages_native.py','tools/rebuild_source_natural_contact_native.py']
 doc={'schema':'starfrontier-source-messages-native-v1','profile':PROFILE,'case_count':len(rows),'whole_original_procedures':len(NUMBERS),'whole_original_instructions':sum(r['instruction_count']for r in m['procedures'].values()),'instruction_proof_sha256':sha((a.proof_dir/'instruction-proof.json').read_bytes()),'source_procedures_sha256':sha(s.encode()),'host_assembly_sha256':sha(native.encode()),'host_support_sha256':sha(C.encode()),'source_dependencies_sha256':{p:sha((PROJECT/p).read_bytes())for p in paths},'fresh_process_runs':3,'reverse_repeat_cases':len(rows),'consecutive_native_steps':16,'source_input_policy':m['packet_input_policy'],'void_return_register_ignored':True,'expected_arithmetic_calculated_in_python':False,'all_owner_canaries_and_input_bytes_unchanged':True,'buffers':buffers,'cases':rows}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(doc,indent=2)+'\n');(a.proof_dir/'messages-native.s').write_text(native);(a.proof_dir/'messages-support.c').write_text(C);print(json.dumps({'case_count':len(rows),'fixture_sha256':sha(a.output.read_bytes())}))
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--refresh-original-proof',action='store_true');a=p.parse_args()
 if a.refresh_original_proof:prepare(a)
 generate(a)
if __name__=='__main__':main()
