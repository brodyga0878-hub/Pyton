#!/usr/bin/env python3
"""Original DOS F1046/F1033/F1034, archived whole-procedure instruction proof.

Default rebuild uses the checked-in original body capture, with no game EXE or
JJFFE download required. A native64 cdecl stack adapter retains original32-bit
math; F569, particles, UI, audio and destruction are explicit observers. Python
serializes and decodes bytes only, never computes expected flight/scoop math.
"""
from __future__ import annotations
import argparse,hashlib,importlib.util,inspect,json,random,re,struct,subprocess,tempfile
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
PROOF=PROJECT/'validation/player-cycle-2026-11-17/motion-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_player_motion_native.json'
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
PROFILE='dos-firstenc-player-motion-contact-v1'
CONTACT='dos-firstenc-f569-explicit-observation-v1'
NUMBERS=[1046,1033,1034,1045,1512,1511,1338,1656,1661,1333]
TRACE=[1046,1033,1034,1045,1512,1511]
OPS={'effects_f1046':0,'contact_f1033':1,'decay_f1034':2}
FIELDS=['effect_gate_s32','sound_mode_s8','step_u32']
ROOT=0x4000;PREFIX=544;BODY=338;INPUT=64+PREFIX+BODY*3
ROOT_AT=64;BODY_AT=ROOT_AT+ROOT;COLLIDER_AT=BODY_AT+BODY;GLOBALS_AT=COLLIDER_AT+BODY
TRACE_AT=GLOBALS_AT+16;REQUEST_AT=TRACE_AT+128;SNAPSHOT_AT=REQUEST_AT+192
OUTPUT=SNAPSHOT_AT+BODY*2+64
GUARD=0x4d4f54494f4e3332

def sha(raw):return hashlib.sha256(raw).hexdigest()
def s32(x):return (x&0x7fffffff)-(x&0x80000000)
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def reprove(args):
 n=load('motion_contact_dos_proof',PROJECT/'tools/rebuild_source_natural_contact_native.py')
 exe=args.exe.read_bytes();raw=args.asm.read_bytes()
 if sha(exe)!=EXE_SHA or sha(raw)!=ASM_SHA:raise ValueError('Unreviewed original upload/source')
 source=raw.decode().replace('\r\n','\n');data=args.data.read_text()
 # JJFFE added this message-stack initialization after the uploaded DOS.
 start=source.index('FUNC_001033:');end=source.index('FUNC_001034:',start)
 body=source[start:end]
 if body.count('\t\tmov dword [ebp-0x20],0xffffffff\n')!=1:raise ValueError('Unreviewed F1033 message initialization')
 source=source[:start]+body.replace('\t\tmov dword [ebp-0x20],0xffffffff\n','')+source[end:]
 for signature,offset in [('558bec538b5d0880bb4e01000000',0x32fd8),('558bec83c4c85356578b5d108b7d08',0x32560)]:
  token=bytes.fromhex(signature)
  if exe.find(token)!=offset or exe.find(token,offset+1)>=0:raise ValueError('Unreviewed original procedure entry')
 resolver=inspect.getsource(n.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_001046',0x4421d8)\n bind('FUNC_001033',0x441760)").replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
 ns=n.__dict__.copy();exec(resolver,ns)
 bodies,records,dis,_,aliases=ns['proof'](source,data,exe,args.exe,NUMBERS)
 for record in records.values():
  at=record['executable_offset'];record['hex']=exe[at:at+record['byte_length']].hex()
 selected='\n'.join(bodies[k]for k in NUMBERS)
 symbols={re.sub(r'(FUNC_\d{6})_[A-Za-z0-9_]+',r'\1',s)for s in re.findall(r'\b(?:DATA_\d+|FUNC_\d+)(?:_[A-Za-z0-9_]+)?',selected)}
 metadata={'schema':'starfrontier-original-player-motion-instruction-proof-v1','source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'procedures':records,'bindings':{s:aliases[s]for s in sorted(symbols)},'source_procedure_sha256':{str(k):sha(n.G.block(selected,k).encode())for k in NUMBERS},'source_procedures_sha256':sha(selected.encode()),'all_full_procedure_instructions_equal':True,'DOS_restoration':'F1033 excludes JJFFE-only mov dword [ebp-0x20],0xffffffff. Uploaded DOS initializes only message code and amount at this call; uninitialized packet bytes are not asserted.','host_adaptations':['Reviewed native64 cdecl stack/register ABI, original32-bit arithmetic and low-address pointers retained','Indirect callback pointer storage widened to8bytes only','RootDATA aliases share the same0x4000byte window, never independent clock/flag copies','F569 explicit observed response writes exact original out pointers and supplies body response; no geometry calculated','F939/F1910/F1116/F349/F148/F1906/F953 preserve arguments and pointer identity as no-effect request observers'],'scope':'Whole original F1046,F1033,F1034 and F1045/F1512/F1511 integer drift closure. F569 geometry, particle RNG/allocation, UI/message/audio and destruction bodies remain explicit observed boundaries. No full collision, scheduler or live Main route claim.'}
 args.proof_dir.mkdir(parents=True,exist_ok=True)
 (args.proof_dir/'source-procedures.s').write_text(selected)
 (args.proof_dir/'instruction-proof.json').write_text(json.dumps(metadata,indent=2)+'\n')
 (args.proof_dir/'dos-disassembly.txt').write_text('\n'.join('F'+k+'\n'+v for k,v in dis.items()))

def verify_archived(meta,source):
 if meta.get('schema')!='starfrontier-original-player-motion-instruction-proof-v1' or sha(source.encode())!=meta['source_procedures_sha256'] or meta['source_executable_sha256']!=EXE_SHA or meta['source_assembly_sha256']!=ASM_SHA or not meta['all_full_procedure_instructions_equal'] or set(meta['procedures'])!=set(map(str,NUMBERS)):raise ValueError('Archived source motion identity changed')
 n=load('motion_contact_replay_proof',PROJECT/'tools/rebuild_source_natural_contact_native.py')
 for k in NUMBERS:
  body=n.G.block(source,k);record=meta['procedures'][str(k)]
  compiled=n.C.J.instructions(n.C.compile32(body,meta['bindings'],'FUNC_%06d'%k,record['virtual_address']))
  if sha(body.encode())!=meta['source_procedure_sha256'][str(k)] or sha('\n'.join(n.canonical(compiled)).encode())!=record['normalized_instruction_sha256'] or sha(bytes.fromhex(record['hex']))!=record['sha256']:raise ValueError('Archived original instructions changed F'+str(k))

def trace(k):return f'''pushfq
push rax
push rcx
mov ecx,DWORD PTR [trace_count]
cmp ecx,32
jae bad_trace
mov DWORD PTR [trace_codes+rcx*4],{k}
inc DWORD PTR [trace_count]
pop rcx
pop rax
popfq
'''

def assembly(source):
 abi=load('motion_contact_host_adapter',PROJECT/'recovered-history/ground_harness/tools/native_reference.py')
 selected=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',source)+'\nFUNC_999999:\nret\n'
 lines,_=abi.procedures(selected,NUMBERS);text='\n'.join(lines)
 for k in TRACE:text=text.replace(f'FUNC_{k:06d}:',f'FUNC_{k:06d}:\n'+trace(k))
 wrapper=WRAPPER
 replacements={'@INPUT@':INPUT,'@OUTPUT@':OUTPUT,'@ROOT_AT@':ROOT_AT,'@BODY_AT@':BODY_AT,'@COLLIDER_AT@':COLLIDER_AT,'@GLOBALS_AT@':GLOBALS_AT,'@TRACE_AT@':TRACE_AT,'@REQUEST_AT@':REQUEST_AT,'@SNAPSHOT_AT@':SNAPSHOT_AT,'@GUARD_AT@':OUTPUT-64,'@GUARD@':GUARD}
 for key,value in replacements.items():wrapper=wrapper.replace(key,str(value))
 return '.intel_syntax noprefix\n.code64\n.section .text\n.global _start\n'+text+'\n'+wrapper

def base_row(rng,i,op):
 root=bytearray(rng.randbytes(PREFIX));body=bytearray(rng.randbytes(BODY));collider=bytearray(rng.randbytes(BODY))
 body[0x86]=114;body[0x56]=1;body[0x57]=0;collider[0x86]=1
 struct.pack_into('<II',root,0xc8,114,[0,1,114][i%3])
 root[0xe8]=[0,2,0x2c,0xff][i%4];struct.pack_into('<H',root,0xc6,[0,0x40,0x80,0xffff][i%4])
 ticks=[0,1,2,127,128,129,49710,65536,0x7fffffff,0x80000000,0xfffffffe,0xffffffff]
 struct.pack_into('<II',root,0xe0,ticks[i%len(ticks)],[0,1,0x7fffffff,0x80000000,0xffffffff][i%5])
 struct.pack_into('<3i',body,0x8c,*[rng.choice([0,1,-1,256,-256,32767,-32768,0x7fffffff,-0x80000000])for _ in range(3)])
 struct.pack_into('<3h',body,0xb6,*[rng.choice([0,1,-1,544,-544,545,-545,546,-546,32767,-32768])for _ in range(3)])
 body[0x14e]=[0,0,1,255][i%4]
 globals={'effect_gate_s32':[-0x80000000,-1,0,1,0x7fffffff][(i//3)%5],'sound_mode_s8':[-128,-1,0,127][i%4],'step_u32':ticks[(i+3)%len(ticks)]}
 boundary={}
 if op=='effects_f1046' and body[0x14e]:boundary={'trail_policy':'observe_only'}
 if op=='contact_f1033':
  model=[24,133,134,135,136,137,139,140,148,149,0xffffffff][i%11];struct.pack_into('<I',collider,0x82,model)
  body[0xca]=[0,2,0x10,0x12][(i//11)%4]
  struct.pack_into('<i',root,0xd8,[8999,9000,9001,0x7fffffff,-0x80000000][i%5])
  struct.pack_into('<II',root,0x118,[0,1,10,0x7fffffff,0x80000000][(i//5)%5],[0,1,9,0x7fffffff,0x80000000][(i//7)%5])
  struct.pack_into('<I',root,0x1e8,[0,1,149130,0xffffffff][(i//3)%4]);struct.pack_into('<I',root,0x1ec,[0,0x7ffffffe,0x7fffffff,0x80000000,0xffffffff][i%5])
  for off in [0x14c,0x146,0x14a,0x13c,0x15a]:struct.pack_into('<H',root,off,[0,1,65534,65535][i%4])
  flags=[0,1,0x20,0x41,0x80,0xff][i%6];ref=1 if flags&1 else [0,1,114][i%3]
  after=body.copy()
  if i%4==0:struct.pack_into('<i',after,0x8c,rng.randint(-0x80000000,0x7fffffff))
  boundary={'caller_profile':CONTACT,'body_before_hex':body.hex(),'body_after_hex':after.hex(),'flags_u8':flags,'altitude_raw_s32':[-1,0,11999999,12000000,12000001,30000000,30000001,-0x80000000,0x7fffffff][i%9],'collider_ref_u32':ref,'collider_index_u8':[0,1,114,255][i%4],'material_u8':[0,1,31,255][i%4],'collider_body_hex':collider.hex()}
 if op=='decay_f1034':
  body[0xca]=[0,1,2,0x10,0xff][i%5]
  for j,off in enumerate([0x14c,0x146,0x14a,0x13c]):struct.pack_into('<H',root,off,[0,1,65534,65535][(i+j)%4])
 return {'name':op+'/'+str(i),'operation':op,'root_prefix_before_hex':root.hex(),'root_tail_fill_u8':[0,0xa7,0xff][i%3],'effects_enabled_root_u8':[0,1,255][i%3],'body_before_hex':body.hex(),'globals_before':globals,'boundary':boundary}

def packet(row):
 g=row['globals_before'];b=row['boundary'];header=[OPS[row['operation']],row['effects_enabled_root_u8'],*[g[k]for k in FIELDS],b.get('flags_u8',0),b.get('altitude_raw_s32',0),b.get('collider_ref_u32',0),b.get('collider_index_u8',0),b.get('material_u8',0),row['root_tail_fill_u8']]+[0]*5
 assert len(header)==16
 before=bytes.fromhex(row['body_before_hex'])
 return struct.pack('<16I',*[v&0xffffffff for v in header])+bytes.fromhex(row['root_prefix_before_hex'])+before+bytes.fromhex(b.get('body_after_hex',row['body_before_hex']))+bytes.fromhex(b.get('collider_body_hex','00'*BODY))

def decode(raw,row):
 magic,returned,nt,nr,ref,index,material,flags,altitude=struct.unpack_from('<9I',raw)
 if magic!=0x4d4f444f or nt>32 or nr>8 or raw[-64:]!=b'\xa5'*64:raise ValueError('Native output guard/count differs '+row['name'])
 root=raw[ROOT_AT:BODY_AT];body=raw[BODY_AT:COLLIDER_AT]
 expected_tail=bytearray([row['root_tail_fill_u8']])*(ROOT-PREFIX);expected_tail[0x3f5e-PREFIX]=row['effects_enabled_root_u8']
 if root[PREFIX:]!=expected_tail:raise ValueError('Native root tail changed')
 b=row['boundary'];collider=bytes.fromhex(b.get('collider_body_hex','00'*BODY))
 if raw[COLLIDER_AT:GLOBALS_AT]!=collider:raise ValueError('Native collider changed')
 state=dict(zip(FIELDS,struct.unpack_from('<3I',raw,GLOBALS_AT+4)));state['effect_gate_s32']=s32(state['effect_gate_s32']);state['sound_mode_s8']=s32(state['sound_mode_s8'])
 requests=[]
 for i in range(nr):
  kind,a,c,d,hasbody,slot=struct.unpack_from('<6I',raw,REQUEST_AT+i*24)
  snapshot=raw[SNAPSHOT_AT+slot*BODY:SNAPSHOT_AT+(slot+1)*BODY].hex()if hasbody else''
  if kind==939:request={'kind':'F939','body_hex_at_call':snapshot,'position_hex_at_call':bytes.fromhex(snapshot)[0x3e:0x56].hex(),'flags_u32':a}
  elif kind==1910:request={'kind':'F1910','args':[s32(a),s32(c),s32(d)],'body_hex_at_call':snapshot}
  elif kind==569:
   if snapshot!=row['body_before_hex']:raise ValueError('Native F569 before body differs')
   request={'kind':'F569','body_hex_at_call':snapshot,'response':b}
  elif kind==1116:request={'kind':'F1116'}
  elif kind==349:request={'kind':'F349','message_code_u32':a,'message_amount_u32':c}
  elif kind==148:request={'kind':'F148','args':[s32(a),s32(c)]}
  elif kind==1906:request={'kind':'F1906','args':[s32(a)]}
  elif kind==953:request={'kind':'F953','args':[s32(a),s32(c)],'body_hex_at_call':snapshot}
  else:raise ValueError('Unknown native request '+str(kind))
  requests.append(request)
 order=['F'+str(k)for k in struct.unpack_from('<32I',raw,TRACE_AT)[:nt]]
 outputs={'flags_u8':flags,'altitude_s32':s32(altitude),'collider_ref_u32':ref,'collider_index_u8':index,'material_u8':material}if row['operation']=='contact_f1033'else{}
 return {'root_prefix_after_hex':root[:PREFIX].hex(),'root_after_sha256':sha(root),'body_after_hex':body.hex(),'globals_after':state,'requests':requests,'source_order':order,'return_s32':s32(returned)if row['operation']=='contact_f1033'else 0,'outputs':outputs}

def generate(proof,output):
 meta=json.loads((proof/'instruction-proof.json').read_text());source=(proof/'source-procedures.s').read_text();verify_archived(meta,source)
 native=assembly(source);rng=random.Random(0x10461033)
 rows=[base_row(rng,i,op)for op,count in [('effects_f1046',192),('contact_f1033',264),('decay_f1034',64)]for i in range(count)]
 # Directed source boundary paths that the randomized initial states might
 # otherwise miss: successful scoop, timer skip, heat signed wrap, refresh.
 for i in range(32):
  r=base_row(rng,1000+i,'contact_f1033');root=bytearray.fromhex(r['root_prefix_before_hex']);body=bytearray.fromhex(r['body_before_hex']);body[0xca]=0x10 if i<16 else 0
  r['globals_before'].update(step_u32=[0,1024,0xffffffff][i%3],sound_mode_s8=-1)
  struct.pack_into('<i',root,0xd8,9000);struct.pack_into('<II',root,0x118,10,0);struct.pack_into('<I',root,0x1e8,0);struct.pack_into('<I',root,0x1ec,0x7fffffff);root[0xc6]|=0x40
  r['root_prefix_before_hex']=root.hex();r['body_before_hex']=body.hex();r['boundary'].update(body_before_hex=body.hex(),body_after_hex=body.hex(),flags_u8=1,altitude_raw_s32=12000000,collider_ref_u32=1)
  collider=bytearray.fromhex(r['boundary']['collider_body_hex']);struct.pack_into('<I',collider,0x82,[134,137,140,148][i%4]);r['boundary']['collider_body_hex']=collider.hex();r['name']='directed-contact/'+str(i);rows.append(r)
 with tempfile.TemporaryDirectory(prefix='player-motion-native-')as directory:
  p=Path(directory);(p/'kernel.s').write_text(native)
  subprocess.run(['as','--64','-o',str(p/'kernel.o'),str(p/'kernel.s')],check=True);subprocess.run(['ld','-o',str(p/'kernel'),str(p/'kernel.o')],check=True)
  def run(items):
   r=subprocess.run([str(p/'kernel')],input=b''.join(packet(row)for row in items),capture_output=True,check=True,timeout=90)
   if r.stderr or len(r.stdout)!=len(items)*OUTPUT:raise ValueError('Native output size/stderr changed')
   return r.stdout
  for op in OPS:
   prior=base_row(rng,1777,op)
   for i in range(16):
    row=json.loads(json.dumps(prior));row['name']='consecutive-'+op+'/'+str(i);row['sequence_step']=i;rows.append(row)
    actual=decode(run([row]),row);prior=row.copy();prior['root_prefix_before_hex']=actual['root_prefix_after_hex'];prior['body_before_hex']=actual['body_after_hex'];prior['globals_before']=actual['globals_after']
    if op=='contact_f1033':prior['boundary']=json.loads(json.dumps(row['boundary']));prior['boundary'].update(body_before_hex=actual['body_after_hex'],body_after_hex=actual['body_after_hex'])
  outputs=[run(rows)for _ in range(3)]
  if len(set(outputs))!=1:raise ValueError('Fresh native processes differ')
  reverse=run(list(reversed(rows)))
  if reverse!=b''.join(outputs[0][i*OUTPUT:(i+1)*OUTPUT]for i in reversed(range(len(rows)))):raise ValueError('Native order leakage')
  for i,row in enumerate(rows):row['expected']=decode(outputs[0][i*OUTPUT:(i+1)*OUTPUT],row)
 output.parent.mkdir(parents=True,exist_ok=True)
 result={'schema':'starfrontier-source-player-motion-native-v1','profile':PROFILE,'source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'instruction_proof_sha256':sha((proof/'instruction-proof.json').read_bytes()),'source_procedures_sha256':sha(source.encode()),'host_assembly_sha256':sha(native.encode()),'input_packets_sha256':sha(b''.join(packet(r)for r in rows)),'native_output_sha256':sha(outputs[0]),'case_count':len(rows),'case_counts_by_operation':{op:sum(r['operation']==op for r in rows)for op in OPS},'consecutive_native_steps':48,'fresh_process_runs':3,'reverse_repeat_cases':len(rows),'all_root_body_collider_canaries_unchanged':True,'expected_arithmetic_calculated_in_python':False,'dependencies_sha256':{name:sha((PROJECT/name).read_bytes())for name in ['recovered-history/ground_harness/tools/native_reference.py','scripts/source_fuel_scoop.gd','scripts/source_gravity.gd']},'scope':meta['scope'],'cases':rows}
 output.write_text(json.dumps(result,indent=2)+'\n');(proof/'player-motion-native.s').write_text(native)
 print(json.dumps({'case_count':len(rows),'fixture_sha256':sha(output.read_bytes()),'operations':result['case_counts_by_operation'],'output':str(output)},indent=2))

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--refresh-original-proof',action='store_true');a=p.parse_args()
 if a.refresh_original_proof:reprove(a)
 generate(a.proof_dir,a.output)

WRAPPER=r'''
# Append a24byte request using EAXkind, EDXa, ECXb, ESIc, EDIbodySlot or-1.
record_request:
 push rbx
 mov ebx,DWORD PTR [request_count]
 cmp ebx,8
 jae bad_trace
 imul ebx,ebx,24
 mov DWORD PTR [requests+rbx],eax
 mov DWORD PTR [requests+rbx+4],edx
 mov DWORD PTR [requests+rbx+8],ecx
 mov DWORD PTR [requests+rbx+12],esi
 mov DWORD PTR [requests+rbx+16],0
 test edi,edi
 js record_done
 mov DWORD PTR [requests+rbx+16],1
 mov DWORD PTR [requests+rbx+20],edi
 push rsi
 push rdi
 push rcx
 imul edi,edi,338
 add edi,OFFSET FLAT:snapshots
 mov esi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 pop rcx
 pop rdi
 pop rsi
record_done:
 inc DWORD PTR [request_count]
 pop rbx
 ret
FUNC_000939:
 push rbp
 mov rbp,rsp
 push rdi
 push rsi
 cmp DWORD PTR [rbp+16],OFFSET FLAT:body
 jne bad_pointer
 cmp DWORD PTR [rbp+24],OFFSET FLAT:body+0x3e
 jne bad_pointer
 cmp DWORD PTR [rbp+32],0
 jne bad_pointer
 call trace_939
 mov eax,939
 xor edx,edx
 xor ecx,ecx
 xor esi,esi
 xor edi,edi
 call record_request
 pop rsi
 pop rdi
 pop rbp
 ret
FUNC_001910:
 push rbp
 mov rbp,rsp
 push rdi
 push rsi
 cmp DWORD PTR [rbp+40],OFFSET FLAT:body
 jne bad_pointer
 call trace_1910
 mov eax,1910
 mov edx,DWORD PTR [rbp+16]
 mov ecx,DWORD PTR [rbp+24]
 mov esi,DWORD PTR [rbp+32]
 mov edi,1
 call record_request
 pop rsi
 pop rdi
 pop rbp
 ret
FUNC_000569:
 push rbp
 mov rbp,rsp
 push rdi
 push rsi
 cmp DWORD PTR [rbp+16],OFFSET FLAT:body
 jne bad_pointer
 cmp DWORD PTR [rbp+24],OFFSET FLAT:bank
 jne bad_pointer
 call trace_569
 mov eax,569
 xor edx,edx
 xor ecx,ecx
 xor esi,esi
 xor edi,edi
 call record_request
 mov esi,OFFSET FLAT:input+946
 mov edi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 mov eax,DWORD PTR [rbp+32]
 mov dl,BYTE PTR [input+20]
 mov BYTE PTR [rax],dl
 mov eax,DWORD PTR [rbp+40]
 mov dl,BYTE PTR [input+32]
 mov BYTE PTR [rax],dl
 mov eax,DWORD PTR [rbp+48]
 mov edx,DWORD PTR [input+28]
 test edx,edx
 jz no_collider_ref
 mov edx,OFFSET FLAT:collider
no_collider_ref:
 mov DWORD PTR [rax],edx
 mov eax,DWORD PTR [rbp+56]
 mov edx,DWORD PTR [input+24]
 mov DWORD PTR [rax],edx
 mov eax,DWORD PTR [rbp+64]
 mov dl,BYTE PTR [input+36]
 mov BYTE PTR [rax],dl
 pop rsi
 pop rdi
 pop rbp
 ret
FUNC_001116:
 push rdi
 push rsi
 call trace_1116
 mov eax,1116
 xor edx,edx
 xor ecx,ecx
 xor esi,esi
 mov edi,-1
 call record_request
 pop rsi
 pop rdi
 ret
FUNC_000349:
 push rbp
 mov rbp,rsp
 push rdi
 push rsi
 call trace_349
 mov eax,DWORD PTR [rbp+16]
 mov edx,DWORD PTR [rax]
 mov ecx,DWORD PTR [rax+4]
 mov eax,349
 xor esi,esi
 mov edi,-1
 call record_request
 pop rsi
 pop rdi
 pop rbp
 ret
FUNC_000148:
 push rbp
 mov rbp,rsp
 push rdi
 push rsi
 call trace_148
 mov eax,148
 mov edx,DWORD PTR [rbp+16]
 mov ecx,DWORD PTR [rbp+24]
 xor esi,esi
 mov edi,-1
 call record_request
 pop rsi
 pop rdi
 pop rbp
 ret
FUNC_001906:
 push rbp
 mov rbp,rsp
 push rdi
 push rsi
 call trace_1906
 mov eax,1906
 mov edx,DWORD PTR [rbp+16]
 xor ecx,ecx
 xor esi,esi
 mov edi,-1
 call record_request
 pop rsi
 pop rdi
 pop rbp
 ret
FUNC_000953:
 push rbp
 mov rbp,rsp
 push rdi
 push rsi
 cmp DWORD PTR [rbp+16],OFFSET FLAT:body
 jne bad_pointer
 call trace_953
 mov eax,953
 mov edx,DWORD PTR [rbp+24]
 mov ecx,DWORD PTR [rbp+32]
 xor esi,esi
 mov edi,1
 call record_request
 pop rsi
 pop rdi
 pop rbp
 ret
_start:
 mov esp,OFFSET FLAT:stack_end
 cld
next_packet:
 xor r8d,r8d
read_packet:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:input
 add rsi,r8
 mov edx,@INPUT@
 sub edx,r8d
 syscall
 test eax,eax
 jle finish
 add r8d,eax
 cmp r8d,@INPUT@
 jne read_packet
 mov edi,OFFSET FLAT:output
 xor eax,eax
 mov ecx,@OUTPUT@
 rep stosb
 mov edi,OFFSET FLAT:root
 mov eax,DWORD PTR [input+40]
 mov ecx,16384
 rep stosb
 mov esi,OFFSET FLAT:input+64
 mov edi,OFFSET FLAT:root
 mov ecx,544
 rep movsb
 mov edi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:input+1284
 mov edi,OFFSET FLAT:collider
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:trace_codes
 xor eax,eax
 mov ecx,32+48+169
 rep stosd
 mov DWORD PTR [trace_count],0
 mov DWORD PTR [request_count],0
 mov DWORD PTR [return_value],0
 mov DWORD PTR [collider_ref],0
 mov BYTE PTR [collider_index],0
 mov BYTE PTR [material],0
 mov eax,DWORD PTR [input+4]
 mov BYTE PTR [DATA_009030],al
 mov eax,DWORD PTR [input+8]
 mov DWORD PTR [DATA_009116],eax
 mov eax,DWORD PTR [input+12]
 mov BYTE PTR [DATA_008630],al
 mov eax,DWORD PTR [input+16]
 mov DWORD PTR [DATA_009155],eax
 mov rax,@GUARD@
 mov QWORD PTR [root_guard_before],rax
 mov QWORD PTR [root_guard_after],rax
 mov QWORD PTR [body_guard_before],rax
 mov QWORD PTR [body_guard_after],rax
 mov QWORD PTR [collider_guard_before],rax
 mov QWORD PTR [collider_guard_after],rax
 cmp DWORD PTR [input],0
 jne try_contact
 push OFFSET FLAT:body
 call FUNC_001046
 add rsp,8
 jmp capture
try_contact:
 cmp DWORD PTR [input],1
 jne try_decay
 push OFFSET FLAT:material
 push OFFSET FLAT:collider_index
 push OFFSET FLAT:collider_ref
 push OFFSET FLAT:bank
 push OFFSET FLAT:body
 call FUNC_001033
 add rsp,40
 mov DWORD PTR [return_value],eax
 jmp capture
try_decay:
 cmp DWORD PTR [input],2
 jne bad_pointer
 push OFFSET FLAT:body
 call FUNC_001034
 add rsp,8
capture:
 mov rax,@GUARD@
 cmp QWORD PTR [root_guard_before],rax
 jne bad_pointer
 cmp QWORD PTR [root_guard_after],rax
 jne bad_pointer
 cmp QWORD PTR [body_guard_before],rax
 jne bad_pointer
 cmp QWORD PTR [body_guard_after],rax
 jne bad_pointer
 cmp QWORD PTR [collider_guard_before],rax
 jne bad_pointer
 cmp QWORD PTR [collider_guard_after],rax
 jne bad_pointer
 mov DWORD PTR [output],0x4d4f444f
 mov eax,DWORD PTR [return_value]
 mov DWORD PTR [output+4],eax
 mov eax,DWORD PTR [trace_count]
 mov DWORD PTR [output+8],eax
 mov eax,DWORD PTR [request_count]
 mov DWORD PTR [output+12],eax
 mov eax,DWORD PTR [collider_ref]
 test eax,eax
 jz capture_no_ref
 cmp eax,OFFSET FLAT:collider
 jne bad_pointer
 mov eax,DWORD PTR [input+28]
capture_no_ref:
 mov DWORD PTR [output+16],eax
 movzx eax,BYTE PTR [collider_index]
 mov DWORD PTR [output+20],eax
 movzx eax,BYTE PTR [material]
 mov DWORD PTR [output+24],eax
 mov eax,DWORD PTR [input+20]
 mov DWORD PTR [output+28],eax
 mov eax,DWORD PTR [input+24]
 mov DWORD PTR [output+32],eax
 mov esi,OFFSET FLAT:root
 mov edi,OFFSET FLAT:output+@ROOT_AT@
 mov ecx,16384
 rep movsb
 mov esi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:collider
 mov ecx,338
 rep movsb
 movzx eax,BYTE PTR [DATA_009030]
 mov DWORD PTR [output+@GLOBALS_AT@],eax
 mov eax,DWORD PTR [DATA_009116]
 mov DWORD PTR [output+@GLOBALS_AT@+4],eax
 movsx eax,BYTE PTR [DATA_008630]
 mov DWORD PTR [output+@GLOBALS_AT@+8],eax
 mov eax,DWORD PTR [DATA_009155]
 mov DWORD PTR [output+@GLOBALS_AT@+12],eax
 mov esi,OFFSET FLAT:trace_codes
 mov edi,OFFSET FLAT:output+@TRACE_AT@
 mov ecx,128+192+676
 rep movsb
 mov edi,OFFSET FLAT:output+@GUARD_AT@
 mov eax,0xa5
 mov ecx,64
 rep stosb
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,@OUTPUT@
 syscall
 cmp eax,@OUTPUT@
 jne bad_pointer
 jmp next_packet
finish:
 mov eax,60
 xor edi,edi
 syscall
bad_pointer:
 mov eax,60
 mov edi,91
 syscall
bad_trace:
 mov eax,60
 mov edi,92
 syscall
.section .data
DATA_006141: .quad FUNC_000569
DATA_007744: .quad FUNC_001512
.section .bss
.balign16
input: .zero @INPUT@
output: .zero @OUTPUT@
root_guard_before: .zero8
root: .zero16384
root_guard_after: .zero8
body_guard_before: .zero8
body: .zero338
body_guard_after: .zero8
collider_guard_before: .zero8
collider: .zero338
collider_guard_after: .zero8
bank: .zero16
.equ DATA_009030,root+0x3f5e
DATA_009116: .zero4
DATA_008630: .zero1
DATA_009155: .zero4
trace_count: .zero4
request_count: .zero4
return_value: .zero4
collider_ref: .zero4
collider_index: .zero1
material: .zero1
trace_codes: .zero128
requests: .zero192
snapshots: .zero676
.equ DATA_008804,root
.equ DATA_008860,root+0xc6
.equ DATA_008868,root+0xe0
.equ DATA_008869,root+0xe4
.equ DATA_008897,root+0x13c
.equ DATA_008898,root+0x146
.equ DATA_008899,root+0x14a
.equ DATA_008900,root+0x14c
.balign16
stack: .zero131072
stack_end:
'''
# Observer entry tracing preserves all registers and flags before body logic.
for _k in [939,1910,569,1116,349,148,1906,953]:WRAPPER=WRAPPER.replace('_start:',f'trace_{_k}:\n'+trace(_k)+'ret\n_start:',1)
WRAPPER=re.sub(r'\.(zero|balign)(\d+)',r'.\1 \2',WRAPPER)
if __name__=='__main__':main()
