#!/usr/bin/env python3
"""Replay whole DOS F1008/F1009/F1010 with observed callback responses.

Portable default uses archived original instruction proof and the raw DOS table.
No installed game, expected arithmetic in Python, or original handler bodies are
needed. The reviewed 64-bit adapter retains all original 32-bit arithmetic.
"""
from __future__ import annotations
import argparse,hashlib,importlib.util,inspect,json,random,re,struct,subprocess,tempfile
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
PROOF=PROJECT/'validation/player-cycle-2026-11-17/mode-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_player_mode_native.json'
TABLE=PROJECT/'data/ffe_player_modes.json'
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
DATA_SHA='34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850'
NUMBERS=[1008,1009,1010];BODY=338;ROOT=0x4000;STATE=BODY+ROOT+12
MAX_MUT=32;INPUT=12+STATE+4+MAX_MUT*16;RECORD=20+STATE*2;OUTPUT=8+STATE+4*RECORD+64
OPS={'housekeeping_f1008':0,'control_f1009':1,'post_f1010':2}
KINDS={1:'F1116',2:'F1097',3:'F1062',4:'F1064',5:'control_phase',6:'post_phase'}
FIELDS=['frame_ticks_u32','action_a_u32','action_b_u32']
def sha(raw):return hashlib.sha256(raw).hexdigest()
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def reprove(args):
 n=load('mode_dos_proof',PROJECT/'tools/rebuild_source_natural_contact_native.py')
 exe=args.exe.read_bytes();raw=args.asm.read_bytes()
 if sha(exe)!=EXE_SHA or sha(raw)!=ASM_SHA:raise ValueError('Unreviewed original executable/assembly')
 source=raw.decode().replace('\r\n','\n');data_raw=args.data.read_bytes();data=data_raw.decode().replace('\r\n','\n')
 if sha(data_raw)!=DATA_SHA:raise ValueError('Unreviewed original table source')
 resolver=inspect.getsource(n.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_001009',0x4408c4)").replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
 ns=n.__dict__.copy();exec(resolver,ns)
 bodies,records,dis,_,aliases=ns['proof'](source,data,exe,args.exe,NUMBERS)
 for k,v in records.items():v['hex']=exe[v['executable_offset']:v['executable_offset']+v['byte_length']].hex()
 selected='\n'.join(bodies[k]for k in NUMBERS)
 symbols=set(re.findall(r'\b(?:DATA_\d+|FUNC_\d+)(?:_[A-Za-z0-9_]+)?',selected));bindings={s:aliases[s]for s in sorted(symbols)}
 table=json.loads(TABLE.read_text());at=n.G.Image(exe).offset(aliases['DATA_007255'],240)
 labels=[int(x)for x in re.findall(r'dd FUNC_(\d+)',data[data.index('DATA_007255:'):data.index('DATA_007257:')])]
 if labels!=[v for row in table['modes']for v in [row['control_function_id'],row['post_function_id']]]:raise ValueError('Logical DOS phase labels changed')
 if exe[at:at+240].hex()!=table['table_hex']:raise ValueError('DOS table/resource mismatch')
 args.proof_dir.mkdir(parents=True,exist_ok=True)
 (args.proof_dir/'source-procedures.asm').write_text(selected)
 metadata=proof_metadata(records,bindings,selected,table)
 (args.proof_dir/'instruction-proof.json').write_text(json.dumps(metadata,indent=2)+'\n')
 (args.proof_dir/'dos-disassembly.txt').write_text('\n'.join('F'+k+'\n'+v for k,v in dis.items()))

def proof_metadata(records,bindings,selected,table):
 return {'schema':'starfrontier-original-player-mode-instruction-proof-v1','source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'source_data_sha256':DATA_SHA,'table_function_ids':[v for row in table['modes']for v in [row['control_function_id'],row['post_function_id']]],'procedures':records,'bindings':bindings,'source_procedures_sha256':sha(selected.encode()),'table_sha256':table['table_sha256'],'table_resource_sha256':sha(TABLE.read_bytes()),'all_full_procedure_instructions_equal':True,'original_instruction_count':sum(v['instruction_count']for v in records.values()),'host_adaptations':['Reviewed64 cdecl register/stack ABI with raw32 arithmetic and low-address body/root/stack','Original32 phase table retains DWORD slots and original scale8; host observer stubs are low-address32 targets','Root aliases remain overlapping actual offsets inside a copied16384-byte raw window','FX and selected phase functions are explicit typed observers with raw supplied state responses; no handler body claim'],'scope':'Whole original DOS F1008/F1009/F1010 and all29 control/post pairs including positive odd modes. Complete338-byte body,16384-byte raw root window and three external globals compared after each call. Selected phase handlers and FX callbacks remain observed request/response boundaries; no completeGameRoot, world scheduler or liveMain route claim.'}

def verify_archived(meta,source):
 table=json.loads(TABLE.read_text())
 if meta['source_executable_sha256']!=EXE_SHA or meta['source_assembly_sha256']!=ASM_SHA or meta['source_data_sha256']!=DATA_SHA or meta['table_function_ids']!=[v for row in table['modes']for v in [row['control_function_id'],row['post_function_id']]] or sha(source.encode())!=meta['source_procedures_sha256'] or meta['table_resource_sha256']!=sha(TABLE.read_bytes()) or meta['table_sha256']!=sha(bytes.fromhex(table['table_hex'])) or not meta['all_full_procedure_instructions_equal'] or set(meta['procedures'])!=set(map(str,NUMBERS)):raise ValueError('Archived mode proof/resource changed')
 n=load('mode_archived_replay',PROJECT/'tools/rebuild_source_natural_contact_native.py')
 for k in NUMBERS:
  record=meta['procedures'][str(k)];body=n.G.block(source,k)
  compiled=n.C.J.instructions(n.C.compile32(body,meta['bindings'],'FUNC_%06d'%k,record['virtual_address']))
  if sha('\n'.join(n.canonical(compiled)).encode())!=record['normalized_instruction_sha256'] or sha(bytes.fromhex(record['hex']))!=record['sha256']:raise ValueError('Archived DOS instructions differ F'+str(k))
 if len(table['modes'])!=29 or len(bytes.fromhex(table['table_hex']))!=240:raise ValueError('Incomplete original phase table')
 for i,row in enumerate(table['modes']):
  if row['phase_u8']!=i*2 or struct.unpack_from('<2I',bytes.fromhex(table['table_hex']),i*8)!=(row['control_va_u32'],row['post_va_u32']):raise ValueError('DOS table word mismatch')

def sparse(raw):
 fill=max(set(raw),key=raw.count)
 return {'fill_u8':fill,'patches':[[i,b]for i,b in enumerate(raw)if b!=fill]}
def expand(spec):
 raw=bytearray([spec['fill_u8']])*ROOT
 for offset,value in spec['patches']:raw[offset]=value
 return bytes(raw)
def globals_from(raw):return dict(zip(FIELDS,struct.unpack('<3I',raw)))
def packet(row):
 mut=row.get('native_mutations',[])
 return struct.pack('<3I',OPS[row['operation']],row['clock']['tick_u32'],row['clock']['day_u32'])+bytes.fromhex(row['body_before_hex'])+expand(row['root_before'])+struct.pack('<3I',*[row['externals_before'][k]for k in FIELDS])+struct.pack('<I',len(mut))+b''.join(struct.pack('<4I',*x)for x in mut)+bytes((MAX_MUT-len(mut))*16)

def assembly(source,table):
 abi=load('mode_abi',PROJECT/'recovered-history/ground_harness/tools/native_reference.py')
 selected=source+'\nFUNC_999999:\nret\n';lines,_=abi.procedures(selected,NUMBERS)
 stubs=[];entries=[]
 for row in table['modes']:
  entries.extend(['mode_control_'+str(row['control_function_id']),'mode_post_'+str(row['post_function_id'])])
 targets={(5,row['control_function_id'],'mode_control_'+str(row['control_function_id']))for row in table['modes']}|{(6,row['post_function_id'],'mode_post_'+str(row['post_function_id']))for row in table['modes']}|{(1,1116,'FUNC_001116'),(2,1097,'FUNC_001097'),(3,1062,'FUNC_001062'),(4,1064,'FUNC_001064')}
 regs=['rax','rcx','rdx','rbx','rbp','rsi','rdi','r8','r9','r10','r11','r12','r13','r14','r15']
 for kind,fid,label in sorted(targets):
  stubs.append(label+':\npushfq\n'+'\n'.join('push '+r for r in regs)+'\nlea rdx,[rsp+128]\nmov edi,%d\nmov esi,%d\ncall observe\n'%(kind,fid)+'\n'.join('pop '+r for r in reversed(regs))+'\npopfq\nret')
 text='.intel_syntax noprefix\n.code64\n.section .text\n.global _start\n'+'\n'.join(lines)+'\n'+'\n'.join(stubs)+'\n'+WRAPPER
 text=text.replace('@TABLE@','\n'.join('.long '+','.join(entries[i:i+2])for i in range(0,len(entries),2)))
 for key,value in {'INPUT':INPUT,'OUTPUT':OUTPUT,'STATE':STATE,'RECORD':RECORD,'BODY':BODY,'ROOT':ROOT,'MUTPOS':12+STATE+4,'MUTCOUNT':12+STATE,'EXT':BODY+ROOT}.items():text=text.replace('@'+key+'@',str(value))
 return text

def base(rng,i,op):
 body=bytearray(rng.randbytes(BODY));fill=[0,0xa5,0x5a,0xff][i%4];root=bytearray([fill])*ROOT
 for at in [0,0x88,0xc6,0xc8,0xcc,0xd8,0xdc,0xe0,0xe4,0xe8,0x1b8,ROOT-8]:root[at:at+4]=rng.randbytes(4)
 root[0xe8]=(i%29)*2;root[0xe9]=[0,1,2,3,0xff][i%5];root[0xea]=[0,1,4,5,6,7,255][i%7]
 struct.pack_into('<i',root,0xd8,[-2147483648,-1,0,99999,100000,100001,2147483647][i%7])
 struct.pack_into('<H',root,0xc6,[0,1,2,0xffff][i%4])
 struct.pack_into('<H',body,0xe8,[0,1,2,3,32768,65534,65535][i%7]);struct.pack_into('<H',body,0x9e,[0,1,2,3,32767,65534,65535][i%7]);body[0xff]=[0,1,29,30,31,255][i%6]
 ticks=[0,1,2,3,65534,65535,65536,0x7fffffff,0x80000000,0xfffffffe,0xffffffff]
 return {'name':op+'/'+str(i),'operation':op,'body_before_hex':body.hex(),'root_before':sparse(root),'externals_before':dict(zip(FIELDS,[ticks[i%len(ticks)],[0,1,0xffffffff][i%3],[0,1,0xffffffff][(i//3)%3]])),'clock':{'tick_u32':ticks[(i+3)%len(ticks)],'day_u32':[0,1,0x7fffffff,0xffffffff][i%4]},'native_mutations':[],'trace':[]}
def patch_root(row,at,value):
 raw=bytearray(expand(row['root_before']));raw[at]=value;row['root_before']=sparse(raw)
def patch_body(row,at,fmt,value):
 raw=bytearray.fromhex(row['body_before_hex']);struct.pack_into(fmt,raw,at,value);row['body_before_hex']=raw.hex()

def decode(raw,row):
 magic,count=struct.unpack_from('<2I',raw)
 if magic!=0x504d444f or count>4 or raw[-64:]!=bytes([0xa5])*64:raise ValueError('Native guard failure '+row['name'])
 final=raw[8:8+STATE];requests=[];trace=[]
 for i in range(count):
  at=8+STATE+i*RECORD;kind,fid,a,b,bodyarg=struct.unpack_from('<5I',raw,at)
  if kind not in KINDS:raise ValueError('Unknown callback kind')
  request={'kind':KINDS[kind],'function_id_u32':fid,'args_u32':[a,b]if kind==2 else[],'body_argument':bool(bodyarg)};requests.append(request)
  before=raw[at+20:at+20+STATE];after=raw[at+20+STATE:at+20+STATE*2]
  if row['native_mutations']:
   trace.append({'request':request,'body_before_hex':before[:BODY].hex(),'root_before_hex':before[BODY:BODY+ROOT].hex(),'externals_before':globals_from(before[-12:]),'body_after_hex':after[:BODY].hex(),'root_after_hex':after[BODY:BODY+ROOT].hex(),'externals_after':globals_from(after[-12:])})
 expected={'body_after_hex':final[:BODY].hex(),'root_after':sparse(final[BODY:BODY+ROOT]),'root_after_sha256':sha(final[BODY:BODY+ROOT]),'externals_after':globals_from(final[-12:]),'requests':requests}
 return expected,trace

def generate(proof,output):
 metadata=json.loads((proof/'instruction-proof.json').read_text());source=(proof/'source-procedures.asm').read_text();verify_archived(metadata,source);table=json.loads(TABLE.read_text());native=assembly(source,table);rng=random.Random(0x10081009)
 rows=[base(rng,i,op)for op,n in [('housekeeping_f1008',264),('control_f1009',116),('post_f1010',116)]for i in range(n)]
 # Every valid signed-byte mode, including positive odd values, reaches its DOS pair.
 for op in ['control_f1009','post_f1010']:
  for i,row in enumerate(r for r in rows if r['operation']==op):patch_root(row,0xe8,i%58)
 # Directed mode2 depletion/toggle branches over all frame tick edges.
 for i,row in enumerate(rows[:132]):patch_root(row,0xe8,2)
 # Exhaustive threshold and notification branches with identity responses.
 for i,row in enumerate(rows[132:264]):patch_root(row,0xe8,[0,4,36][i%3])
 # Original clock low-word borrow and high-word wrap, supplied as raw input.
 controls=[r for r in rows if r['operation']=='control_f1009']
 for i,row in enumerate(controls):
  values=[0,1,0x7fffffff,0x80000000,0xfffffffe,0xffffffff]
  patch_body(row,0xa8,'<I',values[i%6]);patch_body(row,0xac,'<I',values[(i//6)%6]);row['clock']={'tick_u32':values[(i+2)%6],'day_u32':values[(i//6+3)%6]}
 # Responses mutate live raw state at exact request ordinal; subsequent original
 # instructions and table selection run on that response, never a cached value.
 for i in range(24):
  row=base(rng,1000+i,'post_f1010');row['name']='resume-post/'+str(i);patch_root(row,0xea,0);patch_root(row,0xe8,0);row['externals_before'].update(action_a_u32=1,action_b_u32=1)
  mut=[[1,1,0xe8,(i*7)%58]]
  if i%3==0:mut.extend([[1,2,8,0],[1,2,9,0],[1,2,10,0],[1,2,11,0]])
  if i%3==1:mut.append([1,1,0xea,5])
  if i%3==2:mut.append([2,1,0xe8,(i*11)%58])
  row['native_mutations']=mut;rows.append(row)
 for i in range(16):
  row=base(rng,1100+i,'control_f1009');row['name']='resume-fx/'+str(i);patch_root(row,0xe8,2 if i<8 else 0);patch_root(row,0xe9,2 if i<8 else 0);patch_root(row,0xc6,0);patch_body(row,0xff,'<B',31 if i%2 else 30)
  root=bytearray(expand(row['root_before']));struct.pack_into('<i',root,0xd8,100000);row['root_before']=sparse(root)
  row['native_mutations']=[[1,1,0xe8,(i*3)%58],[1,1,0xe9,[0,2,255,1][i%4]],[1,1,0xc6,0x95],[1,1,0xc7,0x73],[1,0,0x9e,0x34],[1,0,0x9f,0x12],[1,2,0,6],[1,2,1,0],[1,2,2,0],[1,2,3,0]];rows.append(row)
 with tempfile.TemporaryDirectory(prefix='player-mode-native-')as d:
  p=Path(d);(p/'kernel.s').write_text(native);subprocess.run(['as','--64','-o',str(p/'kernel.o'),str(p/'kernel.s')],check=True);subprocess.run(['ld','-o',str(p/'kernel'),str(p/'kernel.o')],check=True)
  def run(items):
   result=subprocess.run([str(p/'kernel')],input=b''.join(packet(r)for r in items),capture_output=True,check=True,timeout=90)
   if result.stderr or len(result.stdout)!=len(items)*OUTPUT:raise ValueError('Native output length mismatch')
   return result.stdout
  # Consecutive state uses only prior native output, with supplied subsequent
  # raw clocks; the host does not implement mode arithmetic.
  prior=base(rng,1200,'control_f1009');patch_root(prior,0xe8,2)
  for i in range(32):
   row=json.loads(json.dumps(prior));row['name']='consecutive-native/'+str(i);row['clock']={'tick_u32':(0xffffff00+i*97)&0xffffffff,'day_u32':i//3};rows.append(row)
   expected,_=decode(run([row]),row);prior=row.copy();prior['body_before_hex']=expected['body_after_hex'];prior['root_before']=expected['root_after'];prior['externals_before']=expected['externals_after']
  results=[run(rows)for _ in range(3)]
  if len({sha(x)for x in results})!=1:raise ValueError('Fresh-process native state differs')
  reversed_result=run(list(reversed(rows)))
  if reversed_result!=b''.join(results[0][i*OUTPUT:(i+1)*OUTPUT]for i in reversed(range(len(rows)))):raise ValueError('Case order leakage')
  for i,row in enumerate(rows):row['expected'],row['trace']=decode(results[0][i*OUTPUT:(i+1)*OUTPUT],row)
 proof.joinpath('player-mode-native.s').write_text(native)
 dependencies=['tools/rebuild_source_player_mode_native.py','validation/player-cycle-2026-11-17/mode-native-proof/instruction-proof.json','validation/player-cycle-2026-11-17/mode-native-proof/source-procedures.asm','data/ffe_player_modes.json','tools/rebuild_source_natural_contact_native.py','tools/rebuild_source_surface_contact_native.py','tools/rebuild_source_atmospheric_native.py','tools/rebuild_source_jet_fuel_native.py','tools/rebuild_ground_surface_native.py','recovered-history/ground_harness/tools/build_terrain_query_reference.py','recovered-history/ground_harness/tools/native_reference.py']
 result={'schema':'starfrontier-source-player-mode-native-v1','profile':table['profile'],'case_count':len(rows),'case_counts_by_operation':{op:sum(r['operation']==op for r in rows)for op in OPS},'consecutive_native_steps':32,'callback_response_cases':sum(bool(r['native_mutations'])for r in rows),'proof':{'source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'source_data_sha256':DATA_SHA,'instruction_proof_sha256':sha((proof/'instruction-proof.json').read_bytes()),'source_procedures_sha256':sha(source.encode()),'host_assembly_sha256':sha(native.encode()),'input_packets_sha256':sha(b''.join(packet(r)for r in rows)),'native_output_sha256':sha(results[0]),'fresh_process_runs':3,'reverse_repeat_cases':len(rows),'all_body_root_external_canaries_unchanged':True,'expected_arithmetic_calculated_in_python':False,'source_dependencies_sha256':{s:sha((PROJECT/s).read_bytes())for s in dependencies}},'scope':metadata['scope'],'cases':rows}
 output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'case_count':len(rows),'fixture_sha256':sha(output.read_bytes()),'callback_response_cases':result['callback_response_cases'],'output':str(output)},indent=2))

WRAPPER=r'''
observe:
 mov eax,DWORD PTR [output+4]
 cmp eax,4
 jae bad
 mov r8d,eax
 imul eax,@RECORD@
 add eax,OFFSET FLAT:output+8+@STATE@
 mov r12d,eax
 mov DWORD PTR [r12],edi
 mov DWORD PTR [r12+4],esi
 cmp edi,2
 jne no_fx_args
 mov eax,DWORD PTR [rdx+8]
 cmp eax,0x98ce
 jne bad
 mov DWORD PTR [r12+8],eax
 mov eax,DWORD PTR [rdx+16]
 cmp eax,-1
 jne bad
 mov DWORD PTR [r12+12],eax
no_fx_args:
 cmp edi,5
 jne no_body_arg
 cmp DWORD PTR [rdx+8],OFFSET FLAT:body
 jne bad
 mov DWORD PTR [r12+16],1
no_body_arg:
 mov esi,OFFSET FLAT:body
 lea edi,[r12+20]
 mov ecx,@STATE@
 rep movsb
 inc r8d
 xor r9d,r9d
mutation_next:
 cmp r9d,DWORD PTR [input+@MUTCOUNT@]
 jae mutation_done
 mov eax,r9d
 shl eax,4
 lea r10d,[input+@MUTPOS@+eax]
 cmp DWORD PTR [r10],r8d
 jne mutation_skip
 mov edi,OFFSET FLAT:body
 mov eax,DWORD PTR [r10+4]
 cmp eax,0
 je mutation_base
 mov edi,OFFSET FLAT:root
 cmp eax,1
 je mutation_base
 mov edi,OFFSET FLAT:externals
mutation_base:
 add edi,DWORD PTR [r10+8]
 mov eax,DWORD PTR [r10+12]
 mov BYTE PTR [rdi],al
mutation_skip:
 inc r9d
 jmp mutation_next
mutation_done:
 mov esi,OFFSET FLAT:body
 lea edi,[r12+20+@STATE@]
 mov ecx,@STATE@
 rep movsb
 inc DWORD PTR [output+4]
 ret
bad:
 mov edi,93
 jmp finish
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 mov esp,OFFSET FLAT:stack_end
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 lea esi,[input+r8d]
 mov edx,@INPUT@
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,@INPUT@
 jne read_more
 cld
 mov edi,OFFSET FLAT:guard_before
 mov ecx,64+@STATE@+64
 mov eax,0xa5
 rep stosb
 mov esi,OFFSET FLAT:input+12
 mov edi,OFFSET FLAT:body
 mov ecx,@STATE@
 rep movsb
 mov edi,OFFSET FLAT:output
 mov ecx,@OUTPUT@
 xor eax,eax
 rep stosb
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [context],eax
 mov eax,DWORD PTR [input+8]
 mov DWORD PTR [context+4],eax
 mov DWORD PTR [context+8],OFFSET FLAT:body
 mov eax,DWORD PTR [input]
 cmp eax,0
 je run1008
 cmp eax,1
 je run1009
 cmp eax,2
 jne bad
 call FUNC_001010
 jmp operation_done
run1008:
 push OFFSET FLAT:body
 call FUNC_001008
 add rsp,8
 jmp operation_done
run1009:
 push OFFSET FLAT:context
 call FUNC_001009
 add rsp,8
operation_done:
 mov esi,OFFSET FLAT:guard_before
 mov ecx,64
check_before:
 cmp BYTE PTR [rsi],0xa5
 jne bad
 inc esi
 loop check_before
 mov esi,OFFSET FLAT:guard_after
 mov ecx,64
check_after:
 cmp BYTE PTR [rsi],0xa5
 jne bad
 inc esi
 loop check_after
 mov DWORD PTR [output],0x504d444f
 mov esi,OFFSET FLAT:body
 mov edi,OFFSET FLAT:output+8
 mov ecx,@STATE@
 rep movsb
 mov esi,OFFSET FLAT:guard_after
 mov edi,OFFSET FLAT:output+@OUTPUT@-64
 mov ecx,64
 rep movsb
 xor r8d,r8d
write_more:
 mov eax,1
 mov edi,1
 lea esi,[output+r8d]
 mov edx,@OUTPUT@
 sub edx,r8d
 syscall
 test eax,eax
 jle bad
 add r8d,eax
 cmp r8d,@OUTPUT@
 jne write_more
 jmp next_case
finished:
 xor edi,edi
finish:
 mov eax,60
 syscall
.section .data
.align 4
DATA_007255:
@TABLE@
.long 0,0
.set DATA_007256,DATA_007255+4
.section .bss
.align 16
input:.skip @INPUT@
output:.skip @OUTPUT@
context:.skip 12
guard_before:.skip 64
body:.skip @BODY@
root:.skip @ROOT@
externals:.skip 12
guard_after:.skip 64
.set DATA_008804,root
.set DATA_008868,root+0xe0
.set DATA_008869,root+0xe4
.set DATA_008870,root+0xe8
.set DATA_008872,root+0xea
.set DATA_009155,externals
.set DATA_007246,externals+4
.set DATA_007247,externals+8
.align 16
stack:.skip 65536
stack_end:
'''
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--refresh-original-proof',action='store_true');a=p.parse_args()
 if a.refresh_original_proof:reprove(a)
 generate(a.proof_dir,a.output)
if __name__=='__main__':main()
