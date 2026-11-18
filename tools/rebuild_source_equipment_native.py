#!/usr/bin/env python3
"""Whole original equipment/cargo damage F933/F943..952 with shared Root RNG.

Expected arithmetic is measured from independently verified original code.
Message UI and non-null module handlers require explicit ordered results.
"""
from __future__ import annotations
import argparse,base64,copy,hashlib,inspect,json,random,re,struct,subprocess,tempfile,zlib
from pathlib import Path
import rebuild_source_damage_native as H
N=H.N
PROJECT=N.PROJECT
PROOF=PROJECT/'validation/equipment-effects-2026-11-18/equipment-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_equipment_native.json'
NUMBERS=[144,148,922,933,*range(943,953),1530,1538]
PROFILE='dos-firstenc-equipment-f952-v1'
INPUT=131072;SCRIPT_AT=65536;SCRIPT_SIZE=512;MAX_SCRIPTS=64
BODY_AT=128;FLAGS_AT=512;EVENT_AT=640;MODULE_AT=1024;MODELS_AT=2048;ROOT_AT=32768
OWNER_KEYS=H.OWNER_KEYS;OWNER_SIZES=H.OWNER_SIZES;OWNER_SIZE=H.OWNER_SIZE
FINAL_AT=H.FINAL_AT;ORDER_AT=H.ORDER_AT;RECORD_AT=H.RECORD_AT;RECORD_SIZE=H.RECORD_SIZE;MAX_ORDER=H.MAX_ORDER;MAX_OUTPUT=H.MAX_OUTPUT
IDS={'F%d'%n:n for n in NUMBERS}|{'F349':349,'F144_handler':14400}
BOUNDARIES=['F349','F144_handler']
OPERATIONS=['F952','F933',*[f'F{n}'for n in range(943,952)]]
sha=H.sha;s32=H.s32
def canonical(rows):
 return N.canonical([(at,'indirectjmp' if op=='jmp'and'['in args else op,args)for at,op,args in rows])

def normalize(source):return re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',source)

def compile949(body,aliases,address):
 body='\n'.join(line for line in body.splitlines()if not line.strip().startswith('SECTION '))
 body=re.sub(r'^\s*dd (.+)$',r'.long \1',body,flags=re.M)
 table=address+(0x3e11a-0x3e0fc)
 use={k:v for k,v in aliases.items()if k not in ['DATA_000038','FUNC_000949']}
 assembly='.intel_syntax noprefix\n.code32\n.section .text\n'+''.join('.equ %s,0x%x\n'%(k,v)for k,v in use.items())+N.C.A.gas32(body)
 with tempfile.TemporaryDirectory(prefix='equipment-f949-ia32-proof-')as directory:
  d=Path(directory);(d/'p.s').write_text(assembly)
  for command in [['as','--32',str(d/'p.s'),'-o',str(d/'p.o')],['ld','-m','elf_i386','-e','FUNC_000949','--section-start=.text='+hex(address),str(d/'p.o'),'-o',str(d/'p')]]:
   result=subprocess.run(command,capture_output=True,text=True)
   if result.returncode:raise ValueError(result.stderr)
  result=[]
  for first,last in [(address,table),(table+24,address+0x1000)]:
   text=subprocess.run(['objdump','-d','-Mintel','--no-show-raw-insn','--start-address='+hex(first),'--stop-address='+hex(last),str(d/'p')],capture_output=True,text=True,check=True).stdout
   result.extend(N.C.J.instructions(text))
  return result

def reprove(a):
 raw=a.exe.read_bytes();source=a.asm.read_text();data=a.data.read_text()
 if sha(raw)!=N.EXE_SHA or sha(a.asm.read_bytes())!=N.ASM_SHA:raise ValueError('Pinned original differs')
 simple=[n for n in NUMBERS if n!=949]
 method=inspect.getsource(N.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_000952',0x43df30)")
 method=method.replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
 namespace=N.__dict__.copy();exec(method,namespace)
 bodies,records,dis,_,aliases=namespace['proof'](source,data,raw,a.exe,simple)
 aliases['DATA_008935']=0x642350
 body949=N.G.block(source,949);address=aliases['FUNC_000949'];aliases['DATA_000038']=address+(0x3e11a-0x3e0fc)
 compiled=compile949(body949,aliases,address)
 original=N.C.original_rows(a.exe,address,end=aliases['DATA_000038'])+N.C.original_rows(a.exe,aliases['DATA_000038']+24,end=address+(0x3e19c-0x3e0fc))
 original=original[:len(compiled)]
 if canonical(compiled)!=canonical(original):raise ValueError('F949 source/code ranges differ '+str([(i,x,y)for i,(x,y)in enumerate(zip(canonical(compiled),canonical(original)))if x!=y][:8]))
 image=N.G.Image(raw);at=image.offset(address,1);size=0x3e19c-0x3e0fc
 table_at=image.offset(aliases['DATA_000038'],24);jump_raw=raw[table_at:table_at+24]
 targets=[address+(p-0x3e0fc)for p in [0x3e132,0x3e13d,0x3e148,0x3e153,0x3e15e,0x3e169]]
 if list(struct.unpack('<6I',jump_raw))!=targets:raise ValueError('Original six-way mount jump table differs')
 records['949']={'virtual_address':address,'executable_offset':at,'byte_length':size,'sha256':sha(raw[at:at+size]),'instruction_count':len(original),'normalized_instruction_sha256':sha('\n'.join(canonical(original)).encode()),'all_instructions_equal':True,'embedded_jump_table':{'virtual_address':aliases['DATA_000038'],'file_offset':table_at,'hex':jump_raw.hex(),'targets':targets},'entry_anchor':'Original F950 call target; two code spans plus exact embedded24-byte target table'}
 bodies[949]=body949;dis['949']='\n'.join('%08x: %s %s'%r for r in original)+'\n'
 resources={}
 for symbol,count in [('DATA_007210',15),('DATA_007211',30)]:
  pos=image.offset(aliases[symbol],count*4);captured=raw[pos:pos+count*4]
  resources[symbol]={'virtual_address':aliases[symbol],'file_offset':pos,'byte_count':len(captured),'hex':captured.hex(),'sha256':sha(captured),'words_u32':list(struct.unpack('<%dI'%count,captured))}
 registry=copy.deepcopy(H.verify()[0]['original_module_registry'])
 for r in registry:
  pos=image.offset(r['table_pointer_u32'],48)
  if raw[pos:pos+48].hex()!=r['span_hex']:raise ValueError('Original module registry resource differs')
 selected='\n'.join(bodies[n]for n in NUMBERS)+'\nFUNC_999999:\nret\n'
 kernel=adapt(selected,registry,resources,aliases)
 a.proof_dir.mkdir(parents=True,exist_ok=True)
 (a.proof_dir/'source-procedures.asm').write_text(selected)
 (a.proof_dir/'dos-disassembly.txt').write_text('\n'.join(dis.values()))
 (a.proof_dir/'equipment-native.s').write_text(kernel)
 (a.proof_dir/'original-resources.json').write_text(json.dumps({'tables':resources,'module_registry':registry},indent=2)+'\n')
 callbacks=[]
 for symbol,target in [('DATA_007752','FUNC_001530'),('DATA_007756','FUNC_001538'),('DATA_007217','FUNC_000922')]:
  pos=image.offset(aliases[symbol],4);value=struct.unpack_from('<I',raw,pos)[0]
  if value!=aliases[target]:raise ValueError('Original callback binding differs '+symbol)
  callbacks.append({'symbol':symbol,'virtual_address':aliases[symbol],'file_offset':pos,'target_symbol':target,'target_virtual_address':value})
 meta={'schema':'starfrontier-original-equipment-instruction-proof-v1','source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'source_data_sha256':sha(a.data.read_bytes()),'procedures':records,'source_symbol_addresses':aliases,'source_procedures_sha256':sha(selected.encode()),'dos_disassembly_sha256':sha((a.proof_dir/'dos-disassembly.txt').read_bytes()),'host_assembly_sha256':sha(kernel.encode()),'original_resources_sha256':sha((a.proof_dir/'original-resources.json').read_bytes()),'original_module_registry':registry,'original_callback_words':callbacks,'all_whole_instructions_equal':True,'host_adaptations':['Complete original IA32 procedure code independently assembled and compared before host adaptation.','F949 embedded six-DWORD jump table captured exactly; source code ranges verified separately from pointer bytes.','Expanded cdecl argument slots, low-address source32 buffers and actual original arithmetic; source32 indirect jump uses a host-only r11 target register.','F148 two-pop local frame widened8 to16 for host epilogue; F944 message fixed48-byte scratch retains source field offsets.','Model descriptors/physical24 specs are readonly copied resources; descriptor+38 host relocation is checked/restored before immutable comparison.','F349 observes only defined message words0/4/24, never uninitialized48-byte packet padding.','F144 source dispatcher executes original null/non-null event2/11 registry; actual handlers remain explicit, including optional mutable F148 two-word payload.','All inventory/cargo/weapon/RNG fields alias one raw16KB Root; no extra saved quantities.'],'scope':'Whole bounded F933,F943..952 equipment/cargo/drive/mount updates with actual RNG and module dispatch. F349 UI and nonnull module handler bodies remain explicit external providers. No F942 debris engine, Main, APK or physical Android claim.'}
 (a.proof_dir/'instruction-proof.json').write_text(json.dumps(meta,indent=2)+'\n')
 return meta,selected,kernel

def verify(proof=PROOF):
 meta=json.loads((proof/'instruction-proof.json').read_text());source=(proof/'source-procedures.asm').read_text();kernel=(proof/'equipment-native.s').read_text()
 if meta['source_executable_sha256']!=N.EXE_SHA or meta['source_assembly_sha256']!=N.ASM_SHA or sha(source.encode())!=meta['source_procedures_sha256']or sha(kernel.encode())!=meta['host_assembly_sha256']or sha((proof/'dos-disassembly.txt').read_bytes())!=meta['dos_disassembly_sha256']or sha((proof/'original-resources.json').read_bytes())!=meta['original_resources_sha256']:raise ValueError('Archived equipment identities differ')
 for n in NUMBERS:
  record=meta['procedures'][str(n)]
  rows=compile949(N.G.block(source,n),meta['source_symbol_addresses'],record['virtual_address'])if n==949 else N.C.J.instructions(N.C.compile32(N.G.block(source,n),meta['source_symbol_addresses'],'FUNC_%06d'%n,record['virtual_address']))
  if len(rows)!=record['instruction_count']or sha('\n'.join(canonical(rows)).encode())!=record['normalized_instruction_sha256']:raise ValueError('Archived equipment DOS instructions differ F%d'%n)
 resources=json.loads((proof/'original-resources.json').read_text())
 return meta,source,kernel,resources

def adapt(source,registry,resources,aliases):
 source=normalize(source)
 source=re.sub(r'\+0x(f[0-9a-f]{7})',lambda m:'-0x%x'%(0x100000000-int(m[1],16)),source)
 source=re.sub(r'add esp,0x(f[0-9a-f]{7})',lambda m:'add esp,-0x%x'%(0x100000000-int(m[1],16)),source)
 block=N.G.block(source,148)
 if block.count('add esp,byte -0x8')!=1:raise ValueError('F148 frame differs')
 source=source.replace(block,block.replace('add esp,byte -0x8','add esp,byte -0x10'))
 source='\n'.join(line for line in source.splitlines()if not line.strip().startswith('SECTION '))
 source=re.sub(r'^\s*dd (.+)$',r'.long \1',source,flags=re.M)
 lines,_=N.Q.procedures(source,NUMBERS);text='\n'.join(lines)
 text=re.sub(r'\[rbp[^\]]*\]',lambda m:re.sub(r'\b(eax|ebx|ecx|edx|esi|edi)\b',lambda r:'r'+r[1][1:],m[0]),text)
 text=re.sub(r'(,\s*)(DATA_\d+|FUNC_\d+)$',r'\1OFFSET FLAT:\2',text,flags=re.M)
 text=re.sub(r'call QWORD PTR \[([^\]]+)\]',lambda m:'mov eax,DWORD PTR ['+m[1]+']\ncall rax',text)
 text=re.sub(r'jmp\s+(?:DWORD PTR )?\[edx\*4\+DATA_000038\]',r'mov r11d,DWORD PTR [rdx*4+DATA_000038]\njmp r11',text)
 for n in NUMBERS:
  marker='FUNC_%06d:'%n
  if text.count(marker)!=1:raise ValueError('Equipment source entry differs')
  text=text.replace(marker,marker+'\n'+H.trace(n))
 text=text.replace('FUNC_000144:\n','FUNC_000144:\n'+'''pushfq
push rax
mov eax,DWORD PTR [rsp+24]
mov DWORD PTR [s_current_module],eax
mov eax,DWORD PTR [rsp+32]
mov DWORD PTR [s_current_event],eax
pop rax
popfq
''')
 text=text.replace('FUNC_001538:\n','FUNC_001538:\n'+'''pushfq
push rax
mov eax,DWORD PTR [rsp+24]
cmp eax,149
jae s_bad
cmp DWORD PTR [s_models+rax*4],0
je s_bad
pop rax
popfq
''')
 return '.intel_syntax noprefix\n.code64\n.section .text\n.global _start\n'+text+'\n'+native_support(registry,resources,aliases)

# Reuse the established owner/callback ABI, keeping all original32-bit bytes.
_support_source=inspect.getsource(H.native_support).replace('def native_support(registry):','def base_native_support(registry):')
_support_source=_support_source.replace('for n,argc in [(48,3),(1907,2),(942,2),(952,1)]:','for n,argc in []:')
_support_source=_support_source.replace(" text=NATIVE.replace('@BOUNDARIES@','\\n'.join(blocks))", " blocks.append(boundary(349,3,'''mov esi,DWORD PTR [rbp+16]\nmov eax,DWORD PTR [rsi]\nmov DWORD PTR [s_request+8],eax\nmov eax,DWORD PTR [rsi+4]\nmov DWORD PTR [s_request+12],eax\nmov eax,DWORD PTR [rsi+24]\nmov DWORD PTR [s_request+16],eax'''))\n text=NATIVE.replace('@BOUNDARIES@','\\n'.join(blocks))")
_support_source=_support_source.replace('s_input: .zero 65536','s_input: .zero 131072')
_support_source=_support_source.replace('DATA_007752: .long FUNC_001530','DATA_007217: .long FUNC_000922\\nDATA_007752: .long FUNC_001530')
_support_source=_support_source.replace('s_descriptors_guard_b: .zero8','s_descriptors_guard_b: .zero8\\ns_specs_guard_a: .zero8\\ns_specs: .zero 3576\\ns_specs_guard_b: .zero8')
exec(_support_source,globals())
boundary=H.boundary

def native_support(registry,resources,aliases):
 text=base_native_support(registry)
 text+='\n.section .data\n'
 checks=['mov rax,0xa5a5a5a5a5a5a5a5']
 for name,resource in resources.items():
  text+=name+'_guard_a: .quad 0xa5a5a5a5a5a5a5a5\n'+name+': .long '+','.join(str(x)for x in resource['words_u32'])+'\n'+name+'_guard_b: .quad 0xa5a5a5a5a5a5a5a5\n'
  for side in ['a','b']:checks+=['cmp QWORD PTR ['+name+'_guard_'+side+'],rax','jne s_bad']
  for i,word in enumerate(resource['words_u32']):checks+=['cmp DWORD PTR ['+name+'+%d],0x%x'%(i*4,word),'jne s_bad']
 emit='mov eax,1\nmov edi,1\nmov esi,OFFSET FLAT:s_output'
 if text.count(emit)!=1:raise ValueError('Equipment native emit hook differs')
 text=text.replace(emit,'\n'.join(checks)+'\n'+emit)
 existing={'DATA_008818','DATA_008820'}
 for symbol,address in aliases.items():
  if symbol.startswith('DATA_')and symbol not in existing and 0x64213c<=address<0x64613c:text+=symbol+'=s_root+0x%x\n'%(address-0x64213c)
 return text

NATIVE=H.NATIVE.replace('s_input+32768','s_input+65536').replace('mov edx,65536','mov edx,131072').replace('cmp r8d,65536','cmp r8d,131072').replace('s_input+16384','s_input+32768')
start=NATIVE.index('mov esi,OFFSET FLAT:s_input+2048\nmov edi,OFFSET FLAT:s_descriptors')
end=NATIVE.index('s_models_done:',start)
NATIVE=NATIVE[:start]+'''mov esi,OFFSET FLAT:s_input+2048
mov edi,OFFSET FLAT:s_descriptors
mov r12d,OFFSET FLAT:s_specs
s_model_next:
test r10d,r10d
jz s_models_done
mov r13d,esi
mov eax,DWORD PTR [rsi]
cmp eax,149
jae s_bad
mov DWORD PTR [s_models+rax*4],edi
mov r14d,edi
add esi,4
mov ecx,68
rep movsb
mov r15d,edi
mov edi,r12d
mov ecx,24
rep movsb
cmp DWORD PTR [r14+0x38],0
je s_no_physical
cmp DWORD PTR [r13+96],1
jne s_bad
mov DWORD PTR [r14+0x38],r12d
s_no_physical:
mov edi,r15d
lea esi,[r13+100]
add r12d,24
dec r10d
jmp s_model_next
'''+NATIVE[end:]
NATIVE=NATIVE.replace('mov QWORD PTR [s_descriptors_guard_b],rax','mov QWORD PTR [s_descriptors_guard_b],rax\nmov QWORD PTR [s_specs_guard_a],rax\nmov QWORD PTR [s_specs_guard_b],rax')
start=NATIVE.index('mov eax,DWORD PTR [s_input]\ntest eax,eax')
end=NATIVE.index('s_called:',start)
dispatch=['mov eax,DWORD PTR [s_input]']
for i,op in enumerate(OPERATIONS):dispatch+=['cmp eax,%d'%i,'je s_call_'+op]
dispatch+=['jmp s_bad']
for i,op in enumerate(OPERATIONS):
 n=int(op[1:]);dispatch+=['s_call_'+op+':']
 if n==944:dispatch+=['mov eax,DWORD PTR [s_input+8]','push rax','mov eax,DWORD PTR [s_input+4]','push rax','push OFFSET FLAT:s_body']
 elif n in [946,951]:
  dispatch+=['mov eax,DWORD PTR [s_input+4]','push rax']
  if n==951:dispatch+=['push OFFSET FLAT:s_body']
 else:dispatch+=['push OFFSET FLAT:s_body']
 argc=3 if n==944 else 2 if n==951 else 1
 dispatch+=['call FUNC_%06d'%n,'add rsp,%d'%(8*argc),'jmp s_called']
NATIVE=NATIVE[:start]+'\n'.join(dispatch)+'\n'+NATIVE[end:]
start=NATIVE.index('mov r10d,DWORD PTR [s_input+16]\nmov esi,OFFSET FLAT:s_input+2052',NATIVE.index('s_emit_ready:'))
end=NATIVE.index('s_model_checked:',start)
NATIVE=NATIVE[:start]+'''mov r10d,DWORD PTR [s_input+16]
mov esi,OFFSET FLAT:s_input+2048
mov edi,OFFSET FLAT:s_descriptors
mov r12d,OFFSET FLAT:s_specs
s_model_check:
test r10d,r10d
jz s_model_checked
mov r13d,esi
mov r14d,edi
mov eax,DWORD PTR [rsi+4+0x38]
test eax,eax
jz s_expect_null
cmp DWORD PTR [rdi+0x38],r12d
jne s_bad
jmp s_restore_pointer
s_expect_null:
cmp DWORD PTR [rdi+0x38],0
jne s_bad
s_restore_pointer:
mov DWORD PTR [rdi+0x38],eax
add esi,4
mov ecx,68
repe cmpsb
jne s_bad
mov r15d,edi
mov edi,r12d
mov ecx,24
repe cmpsb
jne s_bad
mov edi,r15d
lea esi,[r13+100]
add r12d,24
dec r10d
jmp s_model_check
'''+NATIVE[end:]
NATIVE=NATIVE.replace('cmp QWORD PTR [s_descriptors_guard_b],rax\njne s_bad','cmp QWORD PTR [s_descriptors_guard_b],rax\njne s_bad\ncmp QWORD PTR [s_specs_guard_a],rax\njne s_bad\ncmp QWORD PTR [s_specs_guard_b],rax\njne s_bad')

def raw_context(value):
 return H.raw_context(value)|{'physical_specs':{k:bytes.fromhex(v)for k,v in value['physical_specs_hex'].items()}}

def packet(row,scripts=None):
 scripts=row.get('_scripts',[])if scripts is None else scripts
 if len(scripts)>MAX_SCRIPTS:raise ValueError('Equipment callback capacity exceeded')
 context=raw_context(row['context_before']);raw=bytearray(b'\xa5'*INPUT)
 args=[int(x)&0xffffffff for x in row.get('args',[])];args=(args+[0,0])[:2]
 struct.pack_into('<7I',raw,0,OPERATIONS.index(row['operation']),args[0],args[1],context['module_count_s32']&0xffffffff,len(context['model_descriptors']),len(scripts),0)
 for at,value in [(BODY_AT,bytes.fromhex(row['body_before_hex'])),(ROOT_AT,context['root']),(FLAGS_AT,context['flags']),(EVENT_AT,context['event_registers']),(MODULE_AT,context['module_entries'])]:raw[at:at+len(value)]=value
 for i,(key,desc)in enumerate(sorted(context['model_descriptors'].items(),key=lambda p:int(p[0]))):
  if int(key)>=149:raise ValueError('Equipment native actual model profile ends148')
  at=MODELS_AT+i*100;spec=context['physical_specs'].get(key,b'');struct.pack_into('<I',raw,at,int(key));raw[at+4:at+72]=desc;raw[at+72:at+96]=spec.ljust(24,b'\0');struct.pack_into('<I',raw,at+96,int(bool(spec)))
 for i,script in enumerate(scripts):
  at=SCRIPT_AT+i*SCRIPT_SIZE;args=[int(v)&0xffffffff for v in script['args']]
  struct.pack_into('<8I',raw,at,IDS[script['kind']],len(args),*(args+[0]*(5-len(args))),script['return_u32'])
  patches=script.get('patches',[])
  if len(patches)>10:raise ValueError('Equipment native patch capacity exceeded')
  struct.pack_into('<I',raw,at+32,len(patches));payload=script.get('payload_after_u32');struct.pack_into('<I',raw,at+36,int(payload is not None))
  if payload is not None:
   if script['kind']!='F144_handler'or args[1]!=2 or len(payload)!=2:raise ValueError('Equipment local packet belongs only to event2')
   struct.pack_into('<2I',raw,at+40,*payload)
  for j,p in enumerate(patches):
   data=bytes.fromhex(p['bytes_hex']);owner=OWNER_KEYS.index(p['owner']);offset=p['offset_u32']
   if len(data)>32 or offset+len(data)>OWNER_SIZES[owner]:raise ValueError('Equipment native patch range exceeded')
   pos=at+64+j*44;struct.pack_into('<3I',raw,pos,owner,offset,len(data));raw[pos+12:pos+12+len(data)]=data
 return bytes(raw)

def snapshot(raw,at,row):
 value=H.snapshot(raw,at,row);value['context']['physical_specs_hex']=copy.deepcopy(row['context_before']['physical_specs_hex']);return value

_decode_source=inspect.getsource(H.decode).replace('def decode(raw,row):','def decode(raw,row):').replace("  if names[kind]=='F1907':args[1]=s32(args[1])",'')
exec(_decode_source,globals())
p8=H.p8;p16=H.p16;p32=H.p32;patch=H.patch

def build_rows():
 rng=random.Random(0x952943951);catalog=json.loads((PROJECT/'data/ffe_object_factory.json').read_text())['models'];factory=json.loads((PROJECT/'tests/fixtures/source_object_factory_native.json').read_text())
 body0=next(r['expected_body_hex']for r in factory['cases']if r['name']=='real-model024-inplace')
 models={k:catalog[k]['descriptor_hex']for k in ['0','24','113','148']};specs={k:catalog[k]['physical_spec_hex']for k in models if catalog[k]['physical_spec_hex']}
 root=bytearray(b'\xa5'*16384);struct.pack_into('<2I',root,0x24,0x12345678,0x87654321)
 struct.pack_into('<2I',root,0x118,0,0);struct.pack_into('<I',root,0x120,0);root[0x134:0x180]=bytes(76)
 modules=bytearray(rng.randbytes(168))
 for i in range(21):modules[i*8]=0
 context={'root_hex':root.hex(),'flags_hex':rng.randbytes(115).hex(),'event_registers_hex':rng.randbytes(284).hex(),'module_entries_hex':modules.hex(),'module_count_s32':20,'model_descriptors_hex':models,'physical_specs_hex':specs}
 template={'operation':'F952','args':[],'body_before_hex':body0,'context_before':context,'_policy':{}}
 def add(name,operation='F952',args=None,selector=0):
  r=copy.deepcopy(template);r['name']=name;r['operation']=operation;r['args']=list(args or[])
  b=bytearray.fromhex(r['body_before_hex']);b[0x118]=selector;b[0x86]=17;b[0xd0]=4;struct.pack_into('<I',b,0xc8,0x10200000);struct.pack_into('<I',b,0xcc,0x01020304);struct.pack_into('<I',b,0x11e,0x12345678)
  r['body_before_hex']=b.hex();rows.append(r);return r
 def root_patch(r,offset,value,width=4):
  b=bytearray.fromhex(r['context_before']['root_hex']);struct.pack_into('<H'if width==2 else'<I',b,offset,value&((1<<(width*8))-1));r['context_before']['root_hex']=b.hex()
 def body_patch(r,offset,value,width=4):
  b=bytearray.fromhex(r['body_before_hex']);struct.pack_into({1:'<B',2:'<H',4:'<I'}[width],b,offset,value&((1<<(width*8))-1));r['body_before_hex']=b.hex()
 def seeds(r,i):root_patch(r,0x24,(i*0x9e3779b9)&0xffffffff);root_patch(r,0x28,(i*0x45d9f3b)^0x12345678)
 rows=[]
 for i in range(64):
  for player in [False,True]:
   r=add('whole-f952/%02d/%s'%(i,'player'if player else'npc'),selector=255 if player else 0);seeds(r,i)
   root_patch(r,0x118,[0,1,40,0x7fffffff,0xffffffff][i%5]);root_patch(r,0x120,[0,1,5,100,0xffffffff][i%5]);body_patch(r,0xc8,[0,0xffffffff,1<<16,0x80000000][i%4]);body_patch(r,0xd0,i%15,1)
   if player:
    cargo=bytearray.fromhex(r['context_before']['root_hex'])
    for j in range(38):struct.pack_into('<H',cargo,0x134+j*2,(i+j)%4)
    r['context_before']['root_hex']=cargo.hex()
 for bit in range(32):
  r=add('equipment-bit/%02d'%bit,'F933');seeds(r,bit+1);body_patch(r,0xc8,1<<bit);r['_require_hit']=bit not in [13,14,15]
 r=add('equipment-hit-attempt29','F933');body_patch(r,0xc8,1<<16);r['_require_last_attempt_hit']=True
 for module in range(21):
  r=add('registry-event2/%02d'%module,'F943',selector=255);entries=bytearray.fromhex(r['context_before']['module_entries_hex']);entries[module*8]=2;r['context_before']['module_entries_hex']=entries.hex()
 for value in [0,0xffffffff,0x0000ffff,0xffff0000]:
  r=add('equipment-mask/%08x'%value,'F933');body_patch(r,0xc8,value)
 for selector in [0,1,254,255]:add('notify-selector/%d'%selector,'F943',selector=selector)
 for selector in [0,255]:add('message-selector/%d'%selector,'F944',[0xffffffff,0x80000000],selector)
 for amount in [-0x80000000,-65536,-1,0,1,65535,65536,0x7fffffff]:
  for initial in [0,0xffffffff,0x80000000]:
   r=add('inventory-width/%d/%08x'%(amount,initial),'F946',[amount]);root_patch(r,0x118,initial);root_patch(r,0x120,initial);root_patch(r,0x170,initial,2)
 for op in ['F947','F948']:
  for drive in range(15):
   r=add('drive/%s/player/%02d'%(op,drive),op,selector=255);body_patch(r,0xd0,drive,1)
  for drive in [0,1,14,15,127,128,254,255]:
   r=add('drive/%s/npc/%03d'%(op,drive),op);body_patch(r,0xd0,drive,1)
 for op in ['F945','F949','F950']:
  for i in range(48):
   r=add('random-helper/%s/%02d'%(op,i),op,selector=255 if i%2 else 0);seeds(r,i+100)
   for at in [0xbc,0xbe,0xc0,0xc2,0xc4,0xc6]:body_patch(r,at,0xabcd,2)
   root_patch(r,0x214,0x12345678)
 for index in range(38):
  r=add('cargo-selected/%02d'%index,'F951',[0],selector=255);root_patch(r,0x120,100);root_patch(r,0x17e-index*2,3,2)
 for total in [0,1,0xffffffff,0x7fffffff,0x80000000]:
  for idx in [-0x80000000,-1,0,1,0x7fffffff]:
   r=add('cargo-signed/%08x/%d'%(total,idx),'F951',[idx],selector=255);root_patch(r,0x120,total)
 # Every mutation is an explicit raw callback result; no replacement
 # equipment choice, refund or cargo result is calculated in Python.
 policies=[
  ('message-selector-to-npc','F944',[0x98ca,0],{'F349:1':[p8('body',0x118,0)]}),
  ('message-selector-stays-player','F944',[0x98ca,0],{'F349:1':[p8('body',0x118,255)]}),
  ('message-root-counters','F947',[],{'F349:1':[p16('root',0x170,65535),p32('root',0x118,0xffffffff),p32('root',0x120,0x80000000)]}),
  ('handler-selector-changes','F944',[0x98cb,0x99ae],{'F144_handler:1':[p8('body',0x118,0)]}),
  ('handler-next-enable','F944',[0x98cb,0x99ae],{'F144_handler:1':[p8('module_entries',20*8,2)]}),
  ('handler-next-disable','F944',[0x98cb,0x99ae],{'F144_handler:1':[p8('module_entries',20*8,0)]}),
  ('handler-body-drive','F947',[],{'F144_handler:1':[p8('body',0xd0,14),p32('body',0x11e,0xfedcba98)]}),
  ('handler-root-seeds','F944',[0x98ca,0],{'F144_handler:1':[p32('root',0x24,0xffffffff),p32('root',0x28,0)]}),
 ]
 for name,op,args,effects in policies:
  r=add('callbacks/'+name,op,args,255);r['_policy']=effects;e=bytearray.fromhex(r['context_before']['module_entries_hex'])
  for i in [2,3,20]:e[i*8]=2
  if name=='handler-next-enable':e[20*8]=0
  r['context_before']['module_entries_hex']=e.hex()
 for i in range(2):
  r=add('broadcast-local-packet/%d'%i,'F944',[0x98ca,0],255);r['_payload_policy']={'F144_handler:1':[0xdeadbeef,0x87654321]}
  if i:r['_payload_policy']['F144_handler:2']=[0xffffffff,0x80000000]
  e=bytearray.fromhex(r['context_before']['module_entries_hex'])
  for j in [2,3,20]:e[j*8]=2
  r['context_before']['module_entries_hex']=e.hex()
 for i in range(24):
  op=['F952','F946','F951','F950'][i%4];args=[1]if op in ['F946','F951']else[]
  r=add('dependent-stream/%02d'%i,op,args,255);seeds(r,i);r['_carry_previous']=i>0
 return rows

def encode_snapshot(state,pool):
 value=H.encode_snapshot(state,pool)
 for k,v in state['context']['physical_specs_hex'].items():
  raw=bytes.fromhex(v);key=sha(raw)
  if key not in pool:pool[key]={'byte_count':len(raw),'zlib_base64':base64.b64encode(zlib.compress(raw,9)).decode()}
  value['context'].setdefault('physical_specs',{})[k]=key
 value['context'].setdefault('physical_specs',{})
 return value
hydrate_buffer=H.hydrate_buffer

def hydrate_context(fixture,context):
 value=H.hydrate_context(fixture,context);value['physical_specs_hex']={k:hydrate_buffer(fixture,h).hex()for k,h in context['physical_specs'].items()};return value

def raw_row(fixture,row):
 result={k:copy.deepcopy(row[k])for k in ['name','operation','args']}
 result.update(body_before_hex=hydrate_buffer(fixture,row['body_before']).hex(),context_before=hydrate_context(fixture,row['context_before']))
 result['_scripts']=[]
 for o in row['observations']:
  script={k:copy.deepcopy(o[k])for k in ['kind','args','return_u32']};script['patches']=copy.deepcopy(o.get('authored_patches',[]))
  if 'payload_after_u32'in o:script['payload_after_u32']=list(o['payload_after_u32'])
  result['_scripts'].append(script)
 return result

def generate(a):
 if a.reprove_original or not(a.proof_dir/'instruction-proof.json').exists():reprove(a)
 meta,source,kernel,resources=verify(a.proof_dir);rows=build_rows();pool={};serialized=[];native_hash=hashlib.sha256();query_counts={k:0 for k in BOUNDARIES}
 with tempfile.TemporaryDirectory(prefix='source-equipment-native-')as directory:
  work=Path(directory);(work/'kernel.s').write_text(kernel)
  subprocess.run(['as','--64','-o',str(work/'kernel.o'),str(work/'kernel.s')],check=True,capture_output=True);subprocess.run(['ld','-o',str(work/'native'),str(work/'kernel.o')],check=True,capture_output=True)
  def execute(row,scripts):
   p=subprocess.run([str(work/'native')],input=packet(row,scripts),capture_output=True,timeout=10)
   if p.returncode or p.stderr:raise ValueError('Equipment native failed code%d %s stderr%s'%(p.returncode,row['name'],p.stderr.decode()))
   return p.stdout
  preceding=None;final_raw=[]
  for row in rows:
   if row.get('_require_hit')or row.get('_require_last_attempt_hit'):
    initial_root=bytearray.fromhex(row['context_before']['root_hex'])
    for selection_probe in range(4096):
     trial_root=initial_root.copy();struct.pack_into('<I',trial_root,0x24,(0x9e3779b9*(selection_probe+1))&0xffffffff);struct.pack_into('<I',trial_root,0x28,(0x45d9f3b*(selection_probe+1))&0xffffffff);row['context_before']['root_hex']=trial_root.hex()
     measured=decode(execute(row,[]),row)
     if measured['status']:raise ValueError('Seed selection probe unexpectedly needs a callback')
     if measured['expected']['return_u32']!=0 and (not row.get('_require_last_attempt_hit')or measured['expected']['source_order'].count('F922')==29):break
    else:raise ValueError('Native-observed seed selection did not find directed branch '+row['name'])
    row['_native_seed_selection_probes']=selection_probe+1
   if row.get('_carry_previous'):row['context_before']['root_hex']=preceding['expected']['context_after']['root_hex'];row['body_before_hex']=preceding['expected']['body_after_hex']
   scripts=[];occurrences={k:0 for k in BOUNDARIES}
   for step in range(MAX_SCRIPTS+1):
    raw=execute(row,scripts);decoded=decode(raw,row)
    if not decoded['status']:break
    pending=decoded['pending'];kind=pending['kind'];occurrences[kind]+=1;effects=row.get('_policy',{}).get(kind+':'+str(occurrences[kind]),[])
    scripts.append({'kind':kind,'args':pending['args'],'return_u32':{'F349':0x13579bdf,'F144_handler':0x2468ace0}[kind],'patches':effects})
    payload=row.get('_payload_policy',{}).get(kind+':'+str(occurrences[kind]))
    if payload is not None:scripts[-1]['payload_after_u32']=payload
   else:raise ValueError('Equipment callback discovery did not terminate')
   for key in list(row.get('_policy',{}))+list(row.get('_payload_policy',{})):
    kind,number=key.rsplit(':',1)
    if occurrences[kind]<int(number):raise ValueError('Equipment directed policy never executed '+row['name']+'/'+key)
   runs=[raw]+[execute(row,scripts)for _ in range(2)]
   if len(set(runs))!=1:raise ValueError('Equipment fresh-process results differ')
   native_hash.update(raw);final_raw.append(raw);row['_scripts']=scripts;row['_decoded']=decoded;preceding=decoded
  reverse_payload=b''.join(packet(r)for r in reversed(rows));rev=subprocess.run([str(work/'native')],input=reverse_payload,capture_output=True,check=True,timeout=120).stdout;cursor=0
  for wanted in reversed(final_raw):
   if rev[cursor:cursor+len(wanted)]!=wanted:raise ValueError('Reverse equipment native order differs')
   cursor+=len(wanted)
  if cursor!=len(rev):raise ValueError('Reverse equipment output truncated')
 for row in rows:
  decoded=row['_decoded'];initial=encode_snapshot({'body_hex':row['body_before_hex'],'context':row['context_before']},pool);observations=[]
  for native,script in zip(decoded['observations'],row['_scripts']):
   query_counts[native['kind']]+=1;o={'kind':native['kind'],'args':native['args'],'before':encode_snapshot(native['before'],pool),'after':encode_snapshot(native['after'],pool),'return_u32':native['return_u32'],'authored_patches':script['patches']}
   if 'payload_after_u32'in native:o['payload_after_u32']=native['payload_after_u32']
   observations.append(o)
  final=encode_snapshot({'body_hex':decoded['expected']['body_after_hex'],'context':decoded['expected']['context_after']},pool)
  expected={k:v for k,v in decoded['expected'].items()if k not in ['body_after_hex','context_after']};expected.update(body_after=final['body'],context_after=final['context'])
  serialized.append({k:copy.deepcopy(row[k])for k in ['name','operation','args']}|{'body_before':initial['body'],'context_before':initial['context'],'observations':observations,'expected':expected,'input_provenance':'authored raw source operands; full expected state from independent original instructions','carries_previous_native_state':bool(row.get('_carry_previous')),'native_seed_selection_probes':int(row.get('_native_seed_selection_probes',0))})
 dependencies=['tools/rebuild_source_equipment_native.py','tools/rebuild_source_damage_native.py','tools/rebuild_source_natural_contact_native.py','tools/rebuild_source_surface_contact_native.py','recovered-history/ground_harness/tools/build_terrain_query_reference.py','recovered-history/ground_harness/tools/native_reference.py','data/ffe_object_factory.json','tests/fixtures/source_object_factory_native.json']
 fixture={'schema':'starfrontier-source-equipment-native-v1','profile':PROFILE,'case_count':len(rows),'fresh_process_runs':3,'reverse_repeat_cases':len(rows),'consecutive_shared_state_cases':sum(bool(r.get('_carry_previous'))for r in rows),'source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'instruction_proof_sha256':sha((a.proof_dir/'instruction-proof.json').read_bytes()),'original_resources_sha256':meta['original_resources_sha256'],'original_module_registry':meta['original_module_registry'],'original_tables':resources['tables'],'native_output_sha256':native_hash.hexdigest(),'expected_arithmetic_calculated_in_python':False,'all_external_results_explicit':True,'external_requests':query_counts,'source_dependencies_sha256':{p:sha((PROJECT/p).read_bytes())for p in dependencies},'buffer_codec':'sha256-keyed zlib_base64; decoded byte_count and SHA256 must match','buffers':pool,'scope':meta['scope'],'cases':serialized}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(fixture,indent=2)+'\n');print(json.dumps({'case_count':len(rows),'external_requests':query_counts,'sha256':sha(a.output.read_bytes()),'bytes':a.output.stat().st_size,'output':str(a.output)},indent=2))

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--reprove-original',action='store_true');generate(p.parse_args())
if __name__=='__main__':main()
