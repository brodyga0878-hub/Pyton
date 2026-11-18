#!/usr/bin/env python3
"""Original player module F1103/F1102/F1101 and removal module F61.

Source-defined payload fields only: codeDWORD, body pointer, indexBYTE.
Expected Root/bank/event/temp outputs come only from original instructions.
"""
from __future__ import annotations
import argparse,base64,copy,hashlib,inspect,json,random,re,struct,subprocess,tempfile,zlib
from pathlib import Path
import rebuild_source_natural_contact_native as N
import rebuild_source_damage_native as H
PROJECT=N.PROJECT;PROOF=PROJECT/'validation/events-messages-2026-11-18/player-events-native-proof';FIXTURE=PROJECT/'tests/fixtures/source_player_events_native.json'
PROFILE='dos-firstenc-player-module-events-v1';NUMBERS=[1103,1102,1101,61]
ROOT=16384;BANK=38986;EVENTS=284;OWNER=ROOT+BANK+EVENTS+5;MAX=16;SCRIPT=1024;INPUT=64+OWNER+MAX*SCRIPT;BASE=64+OWNER+512;SNAP=40+2*OWNER
OPS=['F1103','F1102','F61'];ARITY={262:2,991:0,1097:2,1116:0,48:3,1104:1}
sha=lambda raw:hashlib.sha256(raw).hexdigest()
def s32(value):return(value&0x7fffffff)-(value&0x80000000)

def reprove(a):
 exe=a.exe.read_bytes();source=a.asm.read_text();data=a.data.read_text()
 if sha(exe)!=N.EXE_SHA or sha(a.asm.read_bytes())!=N.ASM_SHA:raise ValueError('Original source identity differs')
 registry=H.verify()[0]['original_module_registry'];p1103=registry[3]['event11_handler_va_u32'];p61=registry[20]['event11_handler_va_u32']
 method=inspect.getsource(N.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_001103',%d)\n bind('FUNC_000061',%d)"%(p1103,p61)).replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
 ns=N.__dict__.copy();exec(method,ns);bodies,records,dis,_,aliases=ns['proof'](source,data,exe,a.exe,NUMBERS);captured='\n'.join(bodies[n]for n in NUMBERS)+'\nFUNC_999999:\nret\n';image=N.G.Image(exe)
 for row in records.values():row['hex']=exe[row['executable_offset']:row['executable_offset']+row['byte_length']].hex()
 base=aliases['DATA_008804'];expected={8887:0x112,8872:0xea,8857:0xc0,8886:0x10e}
 for n,offset in expected.items():
  key='DATA_%06d'%n
  if key in aliases and aliases[key]!=base+offset:raise ValueError('Player Root alias differs '+key+' '+hex(aliases[key])+' base'+hex(base)+' delta'+hex(aliases[key]-base)+' expected'+hex(offset))
 if aliases['DATA_008560']!=0x60bf4c:raise ValueError('Temporary removal index alias differs')
 if aliases['DATA_008877']!=0x4eed84:raise ValueError('Actual DOS watched index alias differs')
 meta={'schema':'starfrontier-player-events-original-proof-v1','source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'procedures':records,'bindings':aliases,'source_procedures_sha256':sha(captured.encode()),'all_whole_instructions_equal':True,'module_registry_anchors':{'module3_event11_F1103':p1103,'module20_event11_F61':p61},'root_aliases':{str(n):{'root_offset_u32':off,'original_va_u32':base+off}for n,off in expected.items()},'watched_index':{'original_va_u32':aliases['DATA_008877'],'original_file_offset':image.offset(aliases['DATA_008877'],1),'original_initial_u8':exe[image.offset(aliases['DATA_008877'],1)],'inside_Root':False,'Root_EF_is_not_used_by_DOS_F1102':True},'temporary_event_index':{'original_va_u32':aliases['DATA_008560'],'separate_from_71_event_words':True},'payload_defined_fields':['code_u32@0','body_pointer_u32@4','index_u8@8'],'scope':'Whole original F1103/F1102/F1101/F61 with signed index tests, actual DOS external watched byte, exact target cleanup and temporary index/reset. F262/F991/F1097/F1116/F48/F1104 remain explicit typed continuations; no complete game-over/event VM/Main claim.'}
 a.proof_dir.mkdir(parents=True,exist_ok=True);(a.proof_dir/'source-procedures.asm').write_text(captured);(a.proof_dir/'instruction-proof.json').write_text(json.dumps(meta,indent=2)+'\n');(a.proof_dir/'dos-disassembly.txt').write_text('\n'.join(dis.values()))
 return meta,captured

def verify(proof=PROOF):
 meta=json.loads((proof/'instruction-proof.json').read_text());source=(proof/'source-procedures.asm').read_text()
 if meta['source_executable_sha256']!=N.EXE_SHA or sha(source.encode())!=meta['source_procedures_sha256']:raise ValueError('Archived player event proof differs')
 for n in NUMBERS:
  row=meta['procedures'][str(n)];raw=bytes.fromhex(row['hex']);compiled=N.C.J.instructions(N.C.compile32(N.G.block(source,n),meta['bindings'],'FUNC_%06d'%n,row['virtual_address']))
  if sha(raw)!=row['sha256']or len(compiled)!=row['instruction_count']or sha('\n'.join(N.canonical(compiled)).encode())!=row['normalized_instruction_sha256']:raise ValueError('Original player instructions differ')
 return meta,source

def trace(n):return 'pushfq\npush rax\npush rcx\nmov ecx,DWORD PTR [p_trace_count]\ncmp ecx,128\njae p_abort\nmov DWORD PTR [p_trace+rcx*4],%d\ninc DWORD PTR [p_trace_count]\npop rcx\npop rax\npopfq\n'%n
def assembly(source):
 selected=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',source);lines,_=N.Q.procedures(selected,NUMBERS);text='\n'.join(lines)
 for n in NUMBERS:text=text.replace('FUNC_%06d:\n'%n,'FUNC_%06d:\n'%n+trace(n),1)
 boundaries=[]
 for n,argc in ARITY.items():
  loads=['mov esi,DWORD PTR [rbp+16]'if argc else'xor esi,esi','mov edx,DWORD PTR [rbp+24]'if argc>1 else'xor edx,edx','mov ecx,DWORD PTR [rbp+32]'if argc>2 else'xor ecx,ecx']
  boundaries.append('FUNC_%06d:\n'%n+trace(n)+'''push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
'''+ '\n'.join(loads)+f'''\nmov edi,{n}
and rsp,-16
call p_observe
lea rsp,[rbp-24]
pop rdi
pop rsi
pop rbx
pop rbp
ret
''')
 entry='''
.global call_kernel
call_kernel:
mov [p_saved_rsp],rsp
mov esp,OFFSET FLAT:p_stack_end
cmp edi,1
je p_call1102
push OFFSET FLAT:p_payload
test edi,edi
jnz p_call61
call FUNC_001103
jmp p_called
p_call61:
call FUNC_000061
jmp p_called
p_call1102:
push rdx
push rsi
call FUNC_001102
p_called:
mov rsp,[p_saved_rsp]
ret
p_abort:
mov edi,97
mov eax,60
syscall
'''
 aliases=['DATA_008804=p_root','DATA_008857=p_root+0xc0','DATA_008887=p_root+0x112','DATA_008877=p_watched','DATA_008872=p_root+0xea','DATA_008886=p_root+0x10e','DATA_008560=p_temporary']
 return '.intel_syntax noprefix\n.code64\n.section .text\n'+text+'\n'+entry+'\n'+'\n'.join(boundaries)+'\n.section .bss\n.balign16\np_stack:.zero1048576\np_stack_end:\np_saved_rsp:.zero8\n'+ '\n'.join(aliases)+'\n.section .note.GNU-stack,"",@progbits\n'

C=r'''
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define ROOT 16384
#define BANK 38986
#define EVENTS 284
#define OWNER (ROOT+BANK+EVENTS+5)
#define BASE (64+OWNER+512)
#define SNAP (40+2*OWNER)
struct __attribute__((packed)) Patch{uint32_t owner,offset,size,pad;uint8_t data[64];};
struct __attribute__((packed)) Script{uint32_t kind,argc,args[6],result,patches,pad[6];struct Patch patch[12];};
struct __attribute__((packed)) Input{uint32_t h[16];uint8_t root[ROOT],bank[BANK],events[EVENTS];int32_t temporary;uint8_t watched;struct Script scripts[16];};
uint8_t p_root[ROOT],p_bank[BANK],p_events[EVENTS],p_payload[16],p_watched;int32_t p_temporary;uint32_t p_trace[128],p_trace_count;
extern uint32_t call_kernel(uint32_t,uint32_t,uint32_t);
static struct Input input;static uint8_t output[BASE+16*SNAP];static uint32_t used,status;
static uint32_t get(const void*p){uint32_t n;memcpy(&n,p,4);return n;}static void put(void*p,uint32_t n){memcpy(p,&n,4);}
static void capture(uint8_t*p){memcpy(p,p_root,ROOT);memcpy(p+ROOT,p_bank,BANK);memcpy(p+ROOT+BANK,p_events,EVENTS);memcpy(p+ROOT+BANK+EVENTS,&p_temporary,4);p[ROOT+BANK+EVENTS+4]=p_watched;}
uint32_t p_observe(uint32_t kind,uint32_t a,uint32_t b,uint32_t c){uint32_t argc=kind==48?3:(kind==262||kind==1097)?2:kind==1104?1:0,args[6]={a,b,c,0,0,0};if(!argc)memset(args,0,sizeof args);else if(argc<3)args[2]=0;if(argc<2)args[1]=0;
 if(used>=16)exit(94);uint8_t*row=output+BASE+used*SNAP;put(row,kind);put(row+4,argc);memcpy(row+8,args,24);capture(row+40);
 if(used>=input.h[4]){status=1;put(row+32,0);capture(row+40+OWNER);used++;return 0;}
 struct Script*s=&input.scripts[used];if(s->kind!=kind||s->argc!=argc||memcmp(s->args,args,24))exit(95);
 for(uint32_t i=0;i<s->patches;i++){struct Patch*p=&s->patch[i];uint8_t*dest=p->owner==0?p_root:p->owner==1?p_bank:p->owner==2?p_events:p->owner==3?(uint8_t*)&p_temporary:p->owner==4?&p_watched:0;uint32_t size=p->owner==0?ROOT:p->owner==1?BANK:p->owner==2?EVENTS:p->owner==3?4:1;if(!dest||p->size>64||p->offset+p->size>size)exit(96);memcpy(dest+p->offset,p->data,p->size);}
 put(row+32,s->result);capture(row+40+OWNER);used++;return s->result;
}
int main(void){while(fread(&input,1,sizeof input,stdin)==sizeof input){if(input.h[0]>2||input.h[2]>114||input.h[3]>255||input.h[4]>16)return 91;memcpy(p_root,input.root,ROOT);memcpy(p_bank,input.bank,BANK);memcpy(p_events,input.events,EVENTS);p_temporary=input.temporary;p_watched=input.watched;memset(output,0,sizeof output);memset(p_payload,0xa5,16);put(p_payload,input.h[1]);put(p_payload+4,(uint32_t)(uintptr_t)(p_bank+116+input.h[2]*338));p_payload[8]=input.h[3];uint8_t payload_before[16];memcpy(payload_before,p_payload,16);used=status=p_trace_count=0;uint32_t result=call_kernel(input.h[0],input.h[3]|0xa5a50000,input.h[1]);if(memcmp(payload_before,p_payload,16))return 92;uint32_t defined=!(input.h[0]==2&&input.h[1]!=0);put(output,0x110261aa);put(output+4,BASE+used*SNAP);put(output+8,status);put(output+12,defined?result:0);put(output+16,used);put(output+20,p_trace_count);put(output+24,defined);capture(output+64);memcpy(output+64+OWNER,p_trace,p_trace_count*4);if(fwrite(output,1,BASE+used*SNAP,stdout)!=BASE+used*SNAP)return 93;}return 0;}
'''

def packet(row):
 ctx=row['context_before'];payload=row['payload'];scripts=row.get('scripts',[]);out=struct.pack('<16I',OPS.index(row['operation']),payload['code_u32'],payload['body_slot_u32'],payload['index_u8'],len(scripts),*([0]*11))+bytes.fromhex(ctx['root'])+bytes.fromhex(ctx['bank'])+bytes.fromhex(ctx['event_registers'])+struct.pack('<iB',ctx['temporary_event_index_s32'],ctx['watched_index_u8'])
 for script in scripts:
  args=[x&0xffffffff for x in script['args']];patches=script.get('patches',[]);out+=struct.pack('<16I',script['kind'],len(args),*args,*([0]*(6-len(args))),script['return_u32'],len(patches),*([0]*6))
  for p in patches:out+=struct.pack('<4I',p['owner'],p['offset'],len(bytes.fromhex(p['hex'])),0)+bytes.fromhex(p['hex']).ljust(64,b'\0')
  out+=bytes((12-len(patches))*80)
 out+=bytes((MAX-len(scripts))*SCRIPT)
 if len(out)!=INPUT:raise ValueError('Native player event input layout differs')
 return out
def context(raw):return {'root':raw[:ROOT].hex(),'bank':raw[ROOT:ROOT+BANK].hex(),'event_registers':raw[ROOT+BANK:ROOT+BANK+EVENTS].hex(),'temporary_event_index_s32':struct.unpack_from('<i',raw,ROOT+BANK+EVENTS)[0],'watched_index_u8':raw[ROOT+BANK+EVENTS+4]}
def decoded_output(raw,row):
 h=struct.unpack_from('<16I',raw)
 if h[0]!=0x110261aa or h[1]!=len(raw)or h[2]or h[4]!=len(row.get('scripts',[]))or len(raw)!=BASE+h[4]*SNAP:raise ValueError(('Native player event output',row['name'],h[:7]))
 order=struct.unpack_from('<%dI'%h[5],raw,64+OWNER);observations=[]
 for i in range(h[4]):
  at=BASE+i*SNAP;kind,argc=struct.unpack_from('<2I',raw,at);args=list(struct.unpack_from('<6I',raw,at+8))[:argc]
  if kind==1104:args[0]=s32(args[0])
  if kind==48:args[2]=s32(args[2])
  observations.append({'kind':'F%d'%kind,'args':args,'before':context(raw[at+40:at+40+OWNER]),'after':context(raw[at+40+OWNER:at+40+OWNER*2]),'return_u32':struct.unpack_from('<I',raw,at+32)[0]})
 return {'context_after':context(raw[64:64+OWNER]),'return_u32':h[3],'return_defined':bool(h[6]),'source_order':['F%d'%n for n in order],'observations':observations}

def cases():
 rng=random.Random(0x110261);rows=[]
 def add(name,operation='F1103',code=1,index=17,player=17,match112=False,matchEF=False,modeEA=5,matchEC=False,matchED=False,modeE8=2):
  root=bytearray(ROOT);struct.pack_into('<I',root,0xc0,player&0xffffffff);root[0x112]=index if match112 else(index+1)&255;root[0xef]=(index+7)&255;root[0xea]=modeEA;root[0xec]=index if matchEC else(index+3)&255;root[0xed]=index if matchED else(index+4)&255;root[0xe8]=modeE8;struct.pack_into('<I',root,0x10e,0xa5a55a5a)
  bank=bytes((i*7+3)&255 for i in range(BANK));events=rng.randbytes(EVENTS)
  rows.append({'name':name,'operation':operation,'payload':{'code_u32':code,'body_slot_u32':rng.choice([0,1,17,114]),'index_u8':index},'context_before':{'root':root.hex(),'bank':bank.hex(),'event_registers':events.hex(),'temporary_event_index_s32':rng.choice([-0x80000000,-1,0,1,0x7fffffff]),'watched_index_u8':index if matchEF else(index+2)&255},'scripts':[],'policy':{}});return rows[-1]
 for index in range(256):add('damage-all-index-%03d'%index,index=index,player=(index if index<128 else index-256)&0xffffffff if index%3 else(index+1)&255)
 for index,player in [(0,0),(128,128),(255,255),(255,0xffffffff)]:add('damage-explicit-sign-%d-%d'%(index,player),'F1102',1,index,player)
 for code in [0,1,0xffffffff]:
  for index in [0,1,17,127,128,129,254,255]:add('remove-register-%d-%d'%(code,index),'F61',code,index)
 for operation in ['F1103','F1102']:
  for index in [0,17,127,128,255]:
   for mask in range(4):add('cleanup-%s-%d-%d'%(operation,index,mask),operation,0,index,player=index if index<128 else index-256,match112=bool(mask&1),matchEF=bool(mask&2),matchEC=True,matchED=True)
 for mode in [0,2,5,255]:add('cleanup-mode-%d'%mode,code=0,modeEA=mode,matchEF=True,match112=True)
 for name,patches in [('message-clear-reread',[{'owner':0,'offset':0xec,'hex':'12'}]),('message-ed-reread',[{'owner':0,'offset':0xed,'hex':'11'}]),('mode-callback-reread',[{'owner':0,'offset':0xed,'hex':'12'}])]:
  r=add(name,code=0,matchEC=True,matchED=False,player=1);r['policy']={'F1097'if name!='mode-callback-reread'else'F1116':patches}
 r=add('temporary-reset-overrides-callback','F61',0,255);r['policy']={'F48':[{'owner':3,'offset':0,'hex':'78563412'},{'owner':2,'offset':88,'hex':'efbeadde'}]}
 r=add('console-callback-target-write',code=0,matchEF=True);r['policy']={'F262':[{'owner':4,'offset':0,'hex':'11'}]}
 return rows

def build(meta,source,folder):
 folder=Path(folder);native=assembly(source);native=re.sub(r'\.balign(\d+)',r'.balign \1',native);native=re.sub(r'\.zero(\d+)',r'.zero \1',native);(folder/'native.s').write_text(native);(folder/'support.c').write_text(C);binary=folder/'native';subprocess.run(['gcc','-O1','-fno-pie','-no-pie','-fno-stack-protector','-o',str(binary),str(folder/'native.s'),str(folder/'support.c')],check=True);return binary,native
def run(binary,row):
 result=subprocess.run([str(binary)],input=packet(row),capture_output=True,check=True,timeout=30)
 if result.stderr:raise ValueError('Unexpected native stderr')
 return result.stdout
def fill_scripts(binary,row):
 for _ in range(MAX+1):
  raw=run(binary,row);h=struct.unpack_from('<16I',raw)
  if h[2]==0:return raw
  if h[2]!=1 or h[4]<=len(row['scripts']):raise ValueError('Unexpected native player pending')
  at=BASE+len(row['scripts'])*SNAP;kind,argc=struct.unpack_from('<2I',raw,at);args=list(struct.unpack_from('<6I',raw,at+8))[:argc];row['scripts'].append({'kind':kind,'args':args,'return_u32':0x13570000+kind,'patches':row['policy'].get('F%d'%kind,[])})
 raise ValueError('Native player boundary capacity exceeded')
def pool_rows(rows):
 pool={}
 def ctx(value):
  result=copy.deepcopy(value)
  for name in ['root','bank','event_registers']:
   raw=bytes.fromhex(result[name]);key=sha(raw)
   if key not in pool:pool[key]={'byte_count':len(raw),'zlib_base64':base64.b64encode(zlib.compress(raw,9)).decode()}
   result[name]=key
  return result
 out=[]
 for r in rows:
  row=copy.deepcopy(r);row.pop('policy');row['context_before']=ctx(row['context_before']);row['expected']['context_after']=ctx(row['expected']['context_after'])
  for observation in row['observations']:
   for side in ['before','after']:observation[side]=ctx(observation[side])
  out.append(row)
 return pool,out
def hydrate_context(fixture,value):
 result=copy.deepcopy(value)
 for key in ['root','bank','event_registers']:
  entry=fixture['buffers'][result[key]];raw=zlib.decompress(base64.b64decode(entry['zlib_base64']))
  if len(raw)!=entry['byte_count']or sha(raw)!=result[key]:raise ValueError('Native player buffer differs')
  result[key]=raw.hex()
 return result
def raw_row(fixture,row):
 result=copy.deepcopy(row);result['context_before']=hydrate_context(fixture,row['context_before']);result['expected']['context_after']=hydrate_context(fixture,row['expected']['context_after'])
 for o in result['observations']:
  for side in ['before','after']:o[side]=hydrate_context(fixture,o[side])
 return result
decode=decoded_output
def generate(a):
 meta,source=verify(a.proof_dir);rows=cases()
 with tempfile.TemporaryDirectory(prefix='player-events-native-')as temp:
  binary,native=build(meta,source,temp)
  outputs=[]
  for row in rows:
   raw=fill_scripts(binary,row);expected=decoded_output(raw,row);row['observations']=expected.pop('observations');row['expected']=expected;outputs.append(raw)
  for _ in range(2):
   if [run(binary,row)for row in rows]!=outputs:raise ValueError('Fresh native player run differs')
  reverse=subprocess.run([str(binary)],input=b''.join(packet(row)for row in reversed(rows)),capture_output=True,check=True,timeout=90)
  if reverse.stderr or reverse.stdout!=b''.join(reversed(outputs)):raise ValueError('Reverse native player stream differs')
 pool,packed=pool_rows(rows);paths=['tools/rebuild_source_player_events_native.py','tools/rebuild_source_natural_contact_native.py','tools/rebuild_source_damage_native.py'];fixture={'schema':'starfrontier-source-player-events-native-v1','profile':PROFILE,'case_count':len(rows),'source_executable_sha256':N.EXE_SHA,'instruction_proof_sha256':sha((a.proof_dir/'instruction-proof.json').read_bytes()),'source_dependencies_sha256':{p:sha((PROJECT/p).read_bytes())for p in paths},'fresh_process_runs':3,'reverse_repeat_cases':len(rows),'all_index_byte_values':256,'expected_arithmetic_calculated_in_python':False,'typed_boundary_count':sum(len(r['observations'])for r in rows),'buffer_codec':'sha256-zlib-base64-v1','buffers':pool,'cases':packed,'scope':meta['scope']};a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(fixture,indent=2)+'\n');(a.proof_dir/'player-events-native.s').write_text(native);(a.proof_dir/'player-events-support.c').write_text(C);print(json.dumps({'case_count':len(rows),'fixture_sha256':sha(a.output.read_bytes()),'typed_boundary_count':fixture['typed_boundary_count']}))
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--reprove-original',action='store_true');a=p.parse_args()
 if a.reprove_original:reprove(a)
 generate(a)
if __name__=='__main__':main()
