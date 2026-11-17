#!/usr/bin/env python3
"""Whole DOS F953 damage, F34/F35 event registers, F148 and shared Root RNG.

Expected arithmetic comes from the original instructions. External module,
event, audio, equipment and destruction boundaries require explicit ordered
observations. Captured source/proofs replay without the private DOS files.
"""
from __future__ import annotations
import argparse,base64,copy,hashlib,inspect,json,random,re,struct,subprocess,tempfile,zlib
from pathlib import Path
import rebuild_source_natural_contact_native as N

PROJECT=N.PROJECT
PROOF=PROJECT/'validation/damage-core-2026-11-17/native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_damage_native.json'
NUMBERS=[34,35,144,148,922,953,1530,1538]
PROFILE='dos-firstenc-damage-f953-v1'
INPUT=65536;SCRIPT_AT=32768;SCRIPT_SIZE=512;MAX_SCRIPTS=64
BODY_AT=128;FLAGS_AT=512;EVENT_AT=640;MODULE_AT=1024;MODELS_AT=2048;ROOT_AT=16384
OWNER_KEYS=['body','root','flags','event_registers','module_entries','module_count_s32']
OWNER_SIZES=[338,16384,115,284,168,4]
OWNER_SIZE=sum(OWNER_SIZES)
FINAL_AT=64;ORDER_AT=17408;RECORD_AT=17920;RECORD_SIZE=34640;MAX_ORDER=128
MAX_OUTPUT=RECORD_AT+MAX_SCRIPTS*RECORD_SIZE
IDS={'F34':34,'F35':35,'F48':48,'F144':144,'F144_handler':14400,'F148':148,'F922':922,'F942':942,'F952':952,'F953':953,'F1530':1530,'F1538':1538,'F1907':1907}
BOUNDARIES=['F48','F144_handler','F1907','F942','F952']

def sha(raw):return hashlib.sha256(raw).hexdigest()
def s32(v):return(v&0x7fffffff)-(v&0x80000000)

def adapt(source,registry):
 source=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',source)
 source=re.sub(r'\+0x(f[0-9a-f]{7})',lambda m:'-0x%x'%(0x100000000-int(m[1],16)),source)
 source=re.sub(r'add esp,0x(f[0-9a-f]{7})',lambda m:'add esp,-0x%x'%(0x100000000-int(m[1],16)),source)
 block=N.G.block(source,148)
 if block.count('add esp,byte -0x8')!=1:raise ValueError('F148 source frame changed')
 source=source.replace(block,block.replace('add esp,byte -0x8','add esp,byte -0x10'))
 lines,_=N.Q.procedures(source,NUMBERS);text='\n'.join(lines)
 text=re.sub(r'\[rbp[^\]]*\]',lambda m:re.sub(r'\b(eax|ebx|ecx|edx|esi|edi)\b',lambda r:'r'+r[1][1:],m[0]),text)
 text=re.sub(r'(,\s*)(DATA_\d+|FUNC_\d+)$',r'\1OFFSET FLAT:\2',text,flags=re.M)
 text=re.sub(r'call QWORD PTR \[([^\]]+)\]',lambda m:'mov eax,DWORD PTR ['+m[1]+']\ncall rax',text)
 for n in NUMBERS:
  marker='FUNC_%06d:'%n
  if text.count(marker)!=1:raise ValueError('Source entry changed')
  text=text.replace(marker,marker+'\n'+trace(n))
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
 return '.intel_syntax noprefix\n.code64\n.section .text\n.global _start\n'+text+'\n'+native_support(registry)

def reprove(a):
 raw=a.exe.read_bytes();source=a.asm.read_text();data=a.data.read_text()
 if sha(raw)!=N.EXE_SHA or sha(a.asm.read_bytes())!=N.ASM_SHA:raise ValueError('Original source identity differs')
 method=inspect.getsource(N.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_000953',0x43df7c)")
 method=method.replace("bind('FUNC_000953',0x43df7c)","bind('FUNC_000953',0x43df7c)\n bind('FUNC_000922',0x43c708)")
 method=method.replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
 namespace=N.__dict__.copy();exec(method,namespace)
 bodies,records,dis,_,aliases=namespace['proof'](source,data,raw,a.exe,NUMBERS)
 selected='\n'.join(bodies[n]for n in NUMBERS)+'\nFUNC_999999:\nret\n'
 callbacks=[]
 for symbol,target in [('DATA_007752','FUNC_001530'),('DATA_007756','FUNC_001538')]:
  offset=N.G.Image(raw).offset(aliases[symbol],4);value=struct.unpack_from('<I',raw,offset)[0]
  if value!=aliases[target]:raise ValueError('Original callback target differs')
  callbacks.append({'pointer_symbol':symbol,'pointer_virtual_address':aliases[symbol],'file_offset':offset,'target_symbol':target,'target_virtual_address':value})
 registry=[];image=N.G.Image(raw)
 for i in range(21):
  at=image.offset(aliases['DATA_004892']+i*4,4);address=struct.unpack_from('<I',raw,at)[0];span_at=image.offset(address,48);span=raw[span_at:span_at+48]
  registry.append({'module_index_u32':i,'table_pointer_u32':address,'pointer_file_offset':at,'table_file_offset':span_at,'span_hex':span.hex(),'span_sha256':sha(span),'event2_handler_va_u32':struct.unpack_from('<I',span,8)[0],'event11_handler_va_u32':struct.unpack_from('<I',span,44)[0]})
 if [r['module_index_u32']for r in registry if r['event11_handler_va_u32']]!=[3,11,17,20]or[r['module_index_u32']for r in registry if r['event2_handler_va_u32']]!=[2,3,4,7,11,12,14,15,17,18,19,20]:raise ValueError('Original module registry differs')
 kernel=adapt(selected,registry);a.proof_dir.mkdir(parents=True,exist_ok=True)
 (a.proof_dir/'source-procedures.asm').write_text(selected);(a.proof_dir/'dos-disassembly.txt').write_text('\n'.join(dis.values()));(a.proof_dir/'damage-native.s').write_text(kernel)
 meta={'schema':'starfrontier-original-damage-instruction-proof-v1','source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'source_data_sha256':sha(a.data.read_bytes()),'procedures':records,'source_symbol_addresses':aliases,'source_procedures_sha256':sha(selected.encode()),'dos_disassembly_sha256':sha((a.proof_dir/'dos-disassembly.txt').read_bytes()),'host_assembly_sha256':sha(kernel.encode()),'original_callback_words':callbacks,'all_whole_instructions_equal':True,'root_aliases':{'DATA_008818':{'virtual_address':0x642160,'root_offset_u32':0x24},'DATA_008820':{'virtual_address':0x642164,'root_offset_u32':0x28}},'host_adaptations':['Original complete procedures independently assembled as IA32 and every normalized instruction compared before host adaptation','Expanded cdecl argument slots and low-address source32 pointers/owners','F148 two-pop local scratch frame widened8 to16 bytes only for host-width epilogue','F34/F35 actual71-word event table owner; F148 fixed21-module source loop; F1538 actual model descriptor pointer lookup','F48/F144/F1907/F942/F952 are explicit ordered external boundaries with full before/after native owner observations and authored return words','F1530/F922 share exactly Root+0x24/+0x28, no seed copies','Observational function-entry traces preserve all source registers and flags'],'scope':'Whole F953,F34,F35,F148,F1538,F1530,F922. Event dispatch,module implementations,audio,equipment destruction and fatal response remain explicit external providers. No F575 orchestration, live Main or Android claim.'}
 meta['original_module_registry']=registry
 meta['procedures']['922']['entry_anchor']='Unique original DOS seed-load prefix, then complete procedure instruction comparison'
 meta['procedures']['953']['entry_anchor']='Actual F575 call target from independently verified classifier closure, then complete procedure comparison'
 meta['host_adaptations']=[x.replace('F48/F144/F1907','F48/non-null-F144_handler/F1907')for x in meta['host_adaptations']]
 meta['host_adaptations'].append('Optional event2 handler payload_after_u32 writes the actual F148 shared stack packet; subsequent F144 handlers reread those source locals')
 meta['scope']='Whole F953,F34,F35,F144,F148,F1538,F1530,F922. Actual immutable original event2/11 null/non-null dispatch executes; nonnull module handlers,event dispatch,audio,equipment destruction and fatal response remain explicit external providers. No F575 orchestration,live Main or Android claim.'
 (a.proof_dir/'instruction-proof.json').write_text(json.dumps(meta,indent=2)+'\n')
 return meta,selected,kernel

def verify(proof=PROOF):
 meta=json.loads((proof/'instruction-proof.json').read_text());source=(proof/'source-procedures.asm').read_text();kernel=(proof/'damage-native.s').read_text()
 if meta['source_executable_sha256']!=N.EXE_SHA or meta['source_assembly_sha256']!=N.ASM_SHA or sha(source.encode())!=meta['source_procedures_sha256']or sha(kernel.encode())!=meta['host_assembly_sha256']or sha((proof/'dos-disassembly.txt').read_bytes())!=meta['dos_disassembly_sha256']:raise ValueError('Archived damage identities differ')
 for n in NUMBERS:
  record=meta['procedures'][str(n)];rows=N.C.J.instructions(N.C.compile32(N.G.block(source,n),meta['source_symbol_addresses'],'FUNC_%06d'%n,record['virtual_address']))
  if len(rows)!=record['instruction_count']or sha('\n'.join(N.canonical(rows)).encode())!=record['normalized_instruction_sha256']:raise ValueError('Archived DOS instructions differ F%d'%n)
 return meta,source,kernel

def trace(n):
 return '''pushfq
push rax
push rcx
mov eax,DWORD PTR [s_order_count]
cmp eax,128
jae s_bad
mov DWORD PTR [s_output+17408+rax*4],%d
inc DWORD PTR [s_order_count]
pop rcx
pop rax
popfq
'''%n

def boundary(n,argc,loads):
 return '''FUNC_%06d:
%spush rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov DWORD PTR [s_request],%d
mov DWORD PTR [s_request+4],%d
mov edi,OFFSET FLAT:s_request+8
xor eax,eax
mov ecx,5
rep stosd
%s
call s_boundary
pop rdi
pop rsi
pop rbx
pop rbp
ret
'''%(n,trace(n),n,argc,loads)

def native_support(registry):
 blocks=[]
 for n,argc in [(48,3),(1907,2),(942,2),(952,1)]:
  loads=[]
  for i in range(argc):
   loads.append('mov eax,DWORD PTR [rbp+%d]'%(16+i*8))
   if n in [942,952]and i==0:loads+=['cmp eax,OFFSET FLAT:s_body','jne s_bad','movzx eax,BYTE PTR [s_body+0x86]']
   loads.append('mov DWORD PTR [s_request+%d],eax'%(8+i*4))
  blocks.append(boundary(n,argc,'\n'.join(loads)))
 blocks.append(boundary(14400,4,'''mov eax,DWORD PTR [s_current_module]
mov DWORD PTR [s_request+8],eax
mov eax,DWORD PTR [s_current_event]
mov DWORD PTR [s_request+12],eax
mov esi,DWORD PTR [rbp+16]
mov DWORD PTR [s_current_payload],esi
mov edx,DWORD PTR [rsi]
mov DWORD PTR [s_request+16],edx
cmp eax,11
jne s_module_broadcast
cmp DWORD PTR [rsi+4],OFFSET FLAT:s_body
jne s_bad
movzx eax,BYTE PTR [rsi+8]
jmp s_module_ready
s_module_broadcast:
cmp eax,2
jne s_bad
mov eax,DWORD PTR [rsi+4]
s_module_ready:
mov DWORD PTR [s_request+20],eax'''))
 text=NATIVE.replace('@BOUNDARIES@','\n'.join(blocks))
 # Source-owned ranges are adjacent only in observations, not aliased.
 offsets=[];at=0
 for name,size in zip(OWNER_KEYS,OWNER_SIZES):offsets.append((name,size,at));at+=size
 capture=[]
 for name,size,at in offsets:capture+=['mov esi,OFFSET FLAT:s_'+name,'lea rdi,[r8+%d]'%at,'mov ecx,%d'%size,'rep movsb']
 text=text.replace('@CAPTURE@','\n'.join(capture))
 text+='\n.section .data\nDATA_007752: .long FUNC_001530\nDATA_007756: .long FUNC_001538\nDATA_007758: .long s_flags\ns_owner_bases: .quad '+','.join('s_'+n for n in OWNER_KEYS)+'\ns_owner_sizes: .long '+','.join(map(str,OWNER_SIZES))+'\n'
 text+='DATA_004892: .long '+','.join('s_registry_%d'%i for i in range(21))+'\n'
 for r in registry:
  words=['FUNC_014400'if j in [2,11]and struct.unpack_from('<I',bytes.fromhex(r['span_hex']),j*4)[0]else'0'for j in range(12)]
  text+='s_registry_%d: .long '%r['module_index_u32']+','.join(words)+'\n'
 text+='\n.section .bss\n.balign 16\ns_input: .zero 65536\ns_output: .zero %d\ns_stack: .zero 1048576\ns_stack_end:\ns_request: .zero32\ns_script_count: .zero4\ns_used: .zero4\ns_order_count: .zero4\ns_return: .zero4\ns_status: .zero4\ns_current_module: .zero4\ns_current_event: .zero4\ns_current_payload: .zero4\ns_models: .zero 1024\ns_descriptors_guard_a: .zero8\ns_descriptors: .zero 10132\ns_descriptors_guard_b: .zero8\n'%MAX_OUTPUT
 for name,size,_ in offsets:text+='s_%s_guard_a: .zero8\ns_%s: .zero%d\ns_%s_guard_b: .zero8\n'%(name,name,size,name)
 text+='DATA_008548=s_event_registers\nDATA_008621=s_module_count_s32\nDATA_008623=s_module_entries\nDATA_008818=s_root+0x24\nDATA_008820=s_root+0x28\nDATA_004681=s_models\n.section .note.GNU-stack,"",@progbits\n'
 return re.sub(r'\.zero(\d+)',r'.zero \1',text)

NATIVE=r'''
.section .text
@BOUNDARIES@
s_boundary:
mov eax,DWORD PTR [s_used]
cmp eax,DWORD PTR [s_script_count]
jae s_pending
imul ebx,eax,512
add ebx,OFFSET FLAT:s_input+32768
mov esi,OFFSET FLAT:s_request
mov edi,ebx
mov ecx,7
repe cmpsd
jne s_bad
mov eax,DWORD PTR [s_used]
imul eax,eax,34640
add eax,OFFSET FLAT:s_output+17920
mov r9d,eax
mov esi,OFFSET FLAT:s_request
mov edi,r9d
mov ecx,28
rep movsb
mov eax,DWORD PTR [rbx+28]
mov DWORD PTR [r9+28],eax
mov DWORD PTR [r9+34620],0
lea r8,[r9+32]
call s_capture
mov r10d,DWORD PTR [rbx+32]
cmp r10d,10
ja s_bad
lea r11,[rbx+64]
s_patch_next:
test r10d,r10d
jz s_patch_done
mov eax,DWORD PTR [r11]
cmp eax,5
ja s_bad
mov rdi,QWORD PTR [s_owner_bases+rax*8]
mov edx,DWORD PTR [s_owner_sizes+rax*4]
mov eax,DWORD PTR [r11+4]
mov ecx,DWORD PTR [r11+8]
cmp ecx,32
ja s_bad
add eax,ecx
jc s_bad
cmp eax,edx
ja s_bad
add edi,DWORD PTR [r11+4]
lea rsi,[r11+12]
rep movsb
add r11,44
dec r10d
jmp s_patch_next
s_patch_done:
cmp DWORD PTR [rbx+36],0
je s_payload_done
cmp DWORD PTR [rbx+36],1
jne s_bad
cmp DWORD PTR [s_request],14400
jne s_bad
cmp DWORD PTR [s_current_event],2
jne s_bad
mov edi,DWORD PTR [s_current_payload]
mov eax,DWORD PTR [rbx+40]
mov DWORD PTR [rdi],eax
mov DWORD PTR [r9+34624],eax
mov eax,DWORD PTR [rbx+44]
mov DWORD PTR [rdi+4],eax
mov DWORD PTR [r9+34628],eax
mov DWORD PTR [r9+34620],1
s_payload_done:
lea r8,[r9+17325]
call s_capture
inc DWORD PTR [s_used]
mov eax,DWORD PTR [rbx+28]
ret
s_pending:
mov DWORD PTR [s_status],1
jmp s_emit
s_capture:
@CAPTURE@
ret
_start:
cld
s_next:
mov esp,OFFSET FLAT:s_stack_end
xor r8d,r8d
s_read:
xor eax,eax
xor edi,edi
mov esi,OFFSET FLAT:s_input
add rsi,r8
mov edx,65536
sub edx,r8d
syscall
test eax,eax
jle s_finished
add r8d,eax
cmp r8d,65536
jne s_read
mov edi,OFFSET FLAT:s_output
mov ecx,%d
mov al,0xa5
rep stosb
mov DWORD PTR [s_used],0
mov DWORD PTR [s_order_count],0
mov DWORD PTR [s_status],0
mov DWORD PTR [s_return],0xa5a5a5a5
mov edi,OFFSET FLAT:s_request
mov ecx,8
xor eax,eax
rep stosd
mov eax,DWORD PTR [s_input+20]
cmp eax,64
ja s_bad
mov DWORD PTR [s_script_count],eax
mov esi,OFFSET FLAT:s_input+128
mov edi,OFFSET FLAT:s_body
mov ecx,338
rep movsb
mov esi,OFFSET FLAT:s_input+512
mov edi,OFFSET FLAT:s_flags
mov ecx,115
rep movsb
mov esi,OFFSET FLAT:s_input+640
mov edi,OFFSET FLAT:s_event_registers
mov ecx,284
rep movsb
mov esi,OFFSET FLAT:s_input+1024
mov edi,OFFSET FLAT:s_module_entries
mov ecx,168
rep movsb
mov esi,OFFSET FLAT:s_input+16384
mov edi,OFFSET FLAT:s_root
mov ecx,16384
rep movsb
mov eax,DWORD PTR [s_input+12]
mov DWORD PTR [s_module_count_s32],eax
mov edi,OFFSET FLAT:s_models
mov ecx,256
xor eax,eax
rep stosd
mov r10d,DWORD PTR [s_input+16]
cmp r10d,149
ja s_bad
mov esi,OFFSET FLAT:s_input+2048
mov edi,OFFSET FLAT:s_descriptors
s_model_next:
test r10d,r10d
jz s_models_done
mov eax,DWORD PTR [rsi]
cmp eax,256
jae s_bad
mov DWORD PTR [s_models+rax*4],edi
add esi,4
mov ecx,68
rep movsb
dec r10d
jmp s_model_next
s_models_done:
mov rax,0xa5a5a5a5a5a5a5a5
mov QWORD PTR [s_descriptors_guard_a],rax
mov QWORD PTR [s_descriptors_guard_b],rax
%s
mov eax,DWORD PTR [s_input]
test eax,eax
jz s_damage
cmp eax,1
je s_rng1530
cmp eax,2
jne s_bad
mov eax,DWORD PTR [s_input+24]
push rax
call FUNC_000922
add rsp,8
jmp s_called
s_rng1530:
call FUNC_001530
jmp s_called
s_damage:
mov eax,DWORD PTR [s_input+8]
push rax
mov eax,DWORD PTR [s_input+4]
push rax
push OFFSET FLAT:s_body
call FUNC_000953
add rsp,24
s_called:
mov DWORD PTR [s_return],eax
s_emit:
mov esp,OFFSET FLAT:s_stack_end
mov eax,DWORD PTR [s_used]
cmp eax,DWORD PTR [s_script_count]
jne s_bad
cmp DWORD PTR [s_status],1
ja s_bad
s_emit_ready:
mov DWORD PTR [s_output],0x44414d47
mov eax,DWORD PTR [s_used]
imul eax,eax,34640
add eax,17920
mov DWORD PTR [s_output+4],eax
mov eax,DWORD PTR [s_status]
mov DWORD PTR [s_output+8],eax
mov eax,DWORD PTR [s_return]
mov DWORD PTR [s_output+12],eax
mov eax,DWORD PTR [s_used]
mov DWORD PTR [s_output+16],eax
mov eax,DWORD PTR [s_order_count]
mov DWORD PTR [s_output+20],eax
mov esi,OFFSET FLAT:s_request
mov edi,OFFSET FLAT:s_output+24
mov ecx,28
rep movsb
mov r8d,OFFSET FLAT:s_output+64
call s_capture
mov r10d,DWORD PTR [s_input+16]
mov esi,OFFSET FLAT:s_input+2052
mov edi,OFFSET FLAT:s_descriptors
s_model_check:
test r10d,r10d
jz s_model_checked
mov ecx,68
repe cmpsb
jne s_bad
add esi,4
dec r10d
jmp s_model_check
s_model_checked:
mov rax,0xa5a5a5a5a5a5a5a5
cmp QWORD PTR [s_descriptors_guard_a],rax
jne s_bad
cmp QWORD PTR [s_descriptors_guard_b],rax
jne s_bad
%s
mov eax,1
mov edi,1
mov esi,OFFSET FLAT:s_output
mov edx,DWORD PTR [s_output+4]
syscall
jmp s_next
s_bad:
mov eax,60
mov edi,97
syscall
s_finished:
mov eax,60
xor edi,edi
syscall
'''
_guard_init=[];_guard_check=[]
for _name in OWNER_KEYS:
 for _side in ['a','b']:
  _guard_init.append('mov QWORD PTR [s_%s_guard_%s],rax'%(_name,_side))
  _guard_check+=['cmp QWORD PTR [s_%s_guard_%s],rax'%(_name,_side),'jne s_bad']
NATIVE=NATIVE%(MAX_OUTPUT,'\n'.join(_guard_init),'\n'.join(_guard_check))

def raw_context(context):
 return {k:bytes.fromhex(context[k+'_hex'])for k in ['root','flags','event_registers','module_entries']}|{'module_count_s32':context['module_count_s32'],'model_descriptors':{str(k):bytes.fromhex(v)for k,v in context['model_descriptors_hex'].items()}}

def packet(row,scripts=None):
 scripts=row.get('_scripts',[])if scripts is None else scripts
 if len(scripts)>MAX_SCRIPTS:raise ValueError('Native boundary capacity exceeded')
 context=raw_context(row['context_before']);raw=bytearray(b'\xa5'*INPUT)
 for name,size in zip(OWNER_KEYS,OWNER_SIZES):
  if name=='module_count_s32':continue
  value=bytes.fromhex(row['body_before_hex'])if name=='body'else context[name]
  if len(value)!=size:raise ValueError('Native owner length differs '+name)
 operation={'damage':0,'rng1530':1,'rng922':2}[row['operation']]
 struct.pack_into('<7I',raw,0,operation,row.get('damage_s32',0)&0xffffffff,row.get('attacker_u32',0),context['module_count_s32']&0xffffffff,len(context['model_descriptors']),len(scripts),row.get('bound_s32',0)&0xffffffff)
 for at,value in [(BODY_AT,bytes.fromhex(row['body_before_hex'])),(ROOT_AT,context['root']),(FLAGS_AT,context['flags']),(EVENT_AT,context['event_registers']),(MODULE_AT,context['module_entries'])]:raw[at:at+len(value)]=value
 for i,(key,value)in enumerate(sorted(context['model_descriptors'].items(),key=lambda p:int(p[0]))):struct.pack_into('<I',raw,MODELS_AT+i*72,int(key));raw[MODELS_AT+i*72+4:MODELS_AT+(i+1)*72]=value
 for i,script in enumerate(scripts):
  at=SCRIPT_AT+i*SCRIPT_SIZE;args=[int(v)&0xffffffff for v in script['args']]
  struct.pack_into('<8I',raw,at,IDS[script['kind']],len(args),*(args+[0]*(5-len(args))),script['return_u32'])
  patches=script.get('patches',[])
  if len(patches)>10:raise ValueError('Native patch capacity exceeded')
  struct.pack_into('<I',raw,at+32,len(patches))
  payload=script.get('payload_after_u32')
  struct.pack_into('<I',raw,at+36,int(payload is not None))
  if payload is not None:
   if script['kind']!='F144_handler'or args[1]!=2 or len(payload)!=2:raise ValueError('Payload mutation belongs only to event2 handler')
   struct.pack_into('<2I',raw,at+40,*payload)
  for j,patch in enumerate(patches):
   value=bytes.fromhex(patch['bytes_hex']);owner=OWNER_KEYS.index(patch['owner']);offset=patch['offset_u32']
   if len(value)>32 or offset+len(value)>OWNER_SIZES[owner]:raise ValueError('Native patch range exceeded')
   pos=at+64+j*44;struct.pack_into('<3I',raw,pos,owner,offset,len(value));raw[pos+12:pos+12+len(value)]=value
 return bytes(raw)

def snapshot(raw,at,row):
 owner={};position=at
 for key,size in zip(OWNER_KEYS,OWNER_SIZES):owner[key]=raw[position:position+size];position+=size
 if position>len(raw):raise ValueError('Truncated native snapshot')
 context={key+'_hex':owner[key].hex()for key in ['root','flags','event_registers','module_entries']}
 context['module_count_s32']=s32(struct.unpack('<I',owner['module_count_s32'])[0]);context['model_descriptors_hex']=copy.deepcopy(row['context_before']['model_descriptors_hex'])
 return {'body_hex':owner['body'].hex(),'context':context}

def decode(raw,row):
 if len(raw)<RECORD_AT or struct.unpack_from('<I',raw)[0]!=0x44414d47:raise ValueError('Damage native magic/length failed')
 size,status,result,used,order_count=struct.unpack_from('<5I',raw,4)
 if size!=len(raw)or used>MAX_SCRIPTS or size!=RECORD_AT+used*RECORD_SIZE or order_count>MAX_ORDER:raise ValueError('Damage native transport failed')
 order=list(struct.unpack_from('<%dI'%order_count,raw,ORDER_AT));names={v:k for k,v in IDS.items()}
 expected={'return_u32':result,'return_s32':s32(result),'observations_used':used,'source_order':[names[x]for x in order]}
 state=snapshot(raw,FINAL_AT,row);expected.update(body_after_hex=state['body_hex'],context_after=state['context'])
 observations=[]
 for i in range(used):
  at=RECORD_AT+i*RECORD_SIZE;kind,argc=struct.unpack_from('<2I',raw,at);args=list(struct.unpack_from('<5I',raw,at+8))[:argc];ret=struct.unpack_from('<I',raw,at+28)[0]
  if argc>5 or kind not in names or names[kind]not in BOUNDARIES:raise ValueError('Native boundary capture invalid')
  if names[kind]=='F1907':args[1]=s32(args[1])
  observation={'kind':names[kind],'args':args,'before':snapshot(raw,at+32,row),'after':snapshot(raw,at+32+OWNER_SIZE,row),'return_u32':ret}
  payload_present=struct.unpack_from('<I',raw,at+34620)[0]
  if payload_present>1:raise ValueError('Native payload observation invalid')
  if payload_present:observation['payload_after_u32']=list(struct.unpack_from('<2I',raw,at+34624))
  observations.append(observation)
 expected['requests']=[{'kind':o['kind'],'args':o['args']}for o in observations]
 pending=None
 if status:
  kind,argc=struct.unpack_from('<2I',raw,24);args=list(struct.unpack_from('<5I',raw,32))[:argc]
  if argc>5 or kind not in names or names[kind]not in BOUNDARIES:raise ValueError('Native pending capture invalid')
  if names[kind]=='F1907':args[1]=s32(args[1])
  pending={'kind':names[kind],'args':args,'before':state}
 return {'status':status,'expected':expected,'observations':observations,'pending':pending}

def patch(owner,offset,value):return {'owner':owner,'offset_u32':offset,'bytes_hex':value.hex()}
def p8(owner,offset,value):return patch(owner,offset,bytes([value&255]))
def p16(owner,offset,value):return patch(owner,offset,struct.pack('<H',value&65535))
def p32(owner,offset,value):return patch(owner,offset,struct.pack('<I',value&0xffffffff))

def build_rows():
 rng=random.Random(0x95334148);catalog=json.loads((PROJECT/'data/ffe_collision_programs.json').read_text());factory=json.loads((PROJECT/'tests/fixtures/source_object_factory_native.json').read_text())
 bodies={int(r['model_index_u32']):r['expected_body_hex']for r in factory['cases']if r['name'].startswith('real-model')and r['name'].endswith('-inplace')}
 descriptors={str(k):catalog['models'][str(k)]['descriptor_hex']for k in range(149)}
 root=bytearray(b'\xa5'*16384);struct.pack_into('<2I',root,0x24,0x12345678,0x87654321)
 events=bytes(rng.getrandbits(8)for _ in range(284));modules=bytearray(rng.getrandbits(8)for _ in range(168))
 for i in range(21):modules[i*8]=0
 context={'root_hex':root.hex(),'flags_hex':bytes(rng.randrange(256)&~16 for _ in range(115)).hex(),'event_registers_hex':events.hex(),'module_entries_hex':modules.hex(),'module_count_s32':0,'model_descriptors_hex':descriptors}
 template={'operation':'damage','body_before_hex':bodies[24],'context_before':context,'damage_s32':0,'attacker_u32':114,'bound_s32':0,'_policy':{}}
 def row(name,shield=40,hull=200,damage=1,kind=3,volume=0,target=0):
  r=copy.deepcopy(template);r['name']=name;b=bytearray.fromhex(r['body_before_hex']);b[0x86]=target;b[0x87]=kind;b[0x88]=volume&255;b[0x118]=0xff;b[0x14e]=0x75;b[0x151]=0xaa;struct.pack_into('<H',b,0xe0,shield);struct.pack_into('<H',b,0xe4,hull);r['body_before_hex']=b.hex();r['damage_s32']=s32(damage);r['attacker_u32']=rng.getrandbits(32);return r
 rows=[]
 # Authored operands cover every exact shield/armour boundary and equality.
 for i,(shield,hull)in enumerate([(0,0),(0,1),(0,3),(0,4),(1,4),(40,200),(65535,65535),(32768,32768),(7,9),(255,256),(0,65535),(65535,1)]):
  damage_values=[-0x80000000,-1,0,1,max(0,shield-1),shield,shield+1,shield+max(0,hull-1),shield+hull,min(0x7fffffff,shield+hull+1),0x7fffffff,17]
  for j,damage in enumerate(damage_values):rows.append(row('bounds/%02d/%02d'%(i,j),shield,hull,damage,volume=[-128,-1,0,127][j%4],target=(i*11+j)%115))
 # Class/flag/descriptor eligibility uses actual immutable source resources.
 for index in range(40):
  kind=[0,1,2,3,4,10,11,12,127,255][index%10];r=row('eligibility/%02d'%index,20,100,27,kind,[-128,-1,0,127][index%4],index%115);body=bytearray.fromhex(r['body_before_hex']);struct.pack_into('<I',body,0x82,[0,24,113,148][(index//10)%4]);r['body_before_hex']=body.hex();flags=bytearray.fromhex(r['context_before']['flags_hex']);flags[index%115]=(flags[index%115]&~16)|(16 if index%3==0 else 0);r['context_before']['flags_hex']=flags.hex();rows.append(r)
 # Explicit callback effects are raw authored byte patches, not replacement
 # damage or probability calculations. Pending native requests choose order.
 policies=[
  ('filter-negative',{'F48:3':[p32('event_registers',12*4,-1)]}),
  ('filter-zero',{'F48:3':[p32('event_registers',12*4,0)]}),
  ('filter-intmin',{'F48:3':[p32('event_registers',12*4,-0x80000000)]}),
  ('filter-intmax',{'F48:3':[p32('event_registers',12*4,0x7fffffff)]}),
  ('writeback-order',{'F48:1':[p32('event_registers',13*4,114)],'F48:2':[p32('event_registers',14*4,0xdeadbeef)],'F48:3':[p32('event_registers',12*4,2)]}),
  ('eligibility-body-kind',{'F48:3':[p8('body',0x87,0)]}),
  ('eligibility-body-index',{'F48:3':[p8('body',0x86,114),p8('body',0x87,11),p8('flags',114,16)]}),
  ('shield-reread',{'F48:3':[p16('body',0xe0,0)]}),
  ('hull-reread',{'F48:3':[p16('body',0xe4,1)]}),
  ('model-reread',{'F48:3':[p8('body',0x87,11),p32('body',0x82,0)]}),
  ('sound-hull-quarter',{'F1907:1':[p16('body',0xe4,1000)]}),
  ('sound-flags-reread',{'F1907:1':[p8('body',0x151,0x80)]}),
  ('sound-no-player-broadcast',{'F1907:1':[p8('body',0x118,0)]}),
  ('sound-start-player-broadcast',{'F1907:1':[p8('body',0x118,255)]}),
  ('sound-rng-owner',{'F1907:1':[p32('root',0x24,0xffffffff),p32('root',0x28,0)]}),
  ('event-root-non-rng',{'F48:2':[patch('root',0x30,bytes.fromhex('123456789abcdef0'))]}),
  ('module-shrink',{'F144_handler:1':[p32('module_count_s32',0,0)]}),
  ('module-grow',{'F144_handler:1':[p32('module_count_s32',0,21),p8('module_entries',20*8,4)]}),
  ('module-next-flag',{'F144_handler:1':[p8('module_entries',11*8,0),p8('module_entries',17*8,4)]}),
  ('module-body-index',{'F144_handler:1':[p8('body',0x86,114)]}),
  ('module-body-kind',{'F144_handler:1':[p8('body',0x87,0)]}),
  ('broadcast-next-flag',{'F144_handler:4':[p8('module_entries',20*8,2)]}),
  ('fatal-return-root',{'F942:1':[p32('root',0x24,0x1234567f),p8('body',0x151,0x5a)]}),
  ('equipment-return-root',{'F952:1':[p32('root',0x28,0x89abcdef),p8('flags',0,0xff)]})]
 for index,(name,effects)in enumerate(policies):
  damage=0x7fffffff if name=='fatal-return-root' else 100 if name=='equipment-return-root' else 1 if name=='sound-flags-reread' else 50
  r=row('callbacks/'+name,40,200,damage,volume=-128);r['_policy']=effects
  if name=='sound-start-player-broadcast':body=bytearray.fromhex(r['body_before_hex']);body[0x118]=0;r['body_before_hex']=body.hex()
  entries=bytearray.fromhex(r['context_before']['module_entries_hex'])
  if name.startswith(('module','broadcast')):
   r['context_before']['module_count_s32']=18
   for k in [3,11,17]:entries[k*8]=6
   entries[20*8]=2
  else:entries[20*8]=2
  if name=='broadcast-next-flag':entries[20*8]=0
  r['context_before']['module_entries_hex']=entries.hex();rows.append(r)
 for kind,damage in [('F942',0x7fffffff),('F952',100)]:
  for value in [0,0xffffffff,0x80000000,0x7fffffff]:
   r=row('return-word/%s/%08x'%(kind,value),40,200,damage);r['_return_policy']={kind:value};rows.append(r)
 # Fixed21 broadcast must see module20 independently of the dynamic damage
 # loop limit, and signed-negative counts skip only the latter.
 for count in [-0x80000000,-1,0,1,20,21]:
  r=row('module-count/%d'%count,40,200,1);r['context_before']['module_count_s32']=count;e=bytearray.fromhex(r['context_before']['module_entries_hex']);e[0]=6;e[20*8]=6;r['context_before']['module_entries_hex']=e.hex();rows.append(r)
 for module in range(21):
  r=row('original-dispatch-table/%02d'%module,40,200,1,target=module);r['context_before']['module_count_s32']=21;e=bytearray.fromhex(r['context_before']['module_entries_hex']);e[module*8]=6;r['context_before']['module_entries_hex']=e.hex();rows.append(r)
 for i in range(2):
  r=row('broadcast-shared-payload/%d'%i,40,200,1);r['_payload_policy']={'F144_handler:1':[0xdeadbeef,0x87654321]}
  if i:r['_payload_policy']['F144_handler:2']=[0xffffffff,0x80000000]
  e=bytearray.fromhex(r['context_before']['module_entries_hex'])
  for module in [2,3,20]:e[module*8]=2
  r['context_before']['module_entries_hex']=e.hex();rows.append(r)
 # RNG corpus combines source-global operations and whole damage calls on
 # the exact preceding native Root state; full bound words test low32 IMUL.
 for i in range(64):
  r=row('rng-stream/%02d'%i,0,65535,1)
  r['operation']=['rng1530','rng922','damage','rng922'][i%4];r['bound_s32']=[-0x80000000,-1,0,1,2,65535,65536,0x7fffffff][(i//2)%8]
  r['_carry_previous']=i>0;root=bytearray.fromhex(r['context_before']['root_hex'])
  if i==0:struct.pack_into('<2I',root,0x24,0xffffffff,0x1234567f)
  r['context_before']['root_hex']=root.hex();rows.append(r)
 return rows

def encode_snapshot(state,pool):
 def put(raw):
  key=sha(raw)
  if key not in pool:pool[key]={'byte_count':len(raw),'zlib_base64':base64.b64encode(zlib.compress(raw,9)).decode()}
  return key
 c=state['context'];out={'body':put(bytes.fromhex(state['body_hex'])),'context':{k:put(bytes.fromhex(c[k+'_hex']))for k in ['root','flags','event_registers','module_entries']}}
 out['context']['module_count_s32']=c['module_count_s32'];out['context']['model_descriptors']={k:put(bytes.fromhex(v))for k,v in c['model_descriptors_hex'].items()}
 return out

def hydrate_buffer(fixture,key):
 record=fixture['buffers'][key];raw=zlib.decompress(base64.b64decode(record['zlib_base64']))
 if len(raw)!=record['byte_count']or sha(raw)!=key:raise ValueError('Damage fixture buffer identity differs')
 return raw

def hydrate_context(fixture,context):
 return {k+'_hex':hydrate_buffer(fixture,context[k]).hex()for k in ['root','flags','event_registers','module_entries']}|{'module_count_s32':context['module_count_s32'],'model_descriptors_hex':{k:hydrate_buffer(fixture,v).hex()for k,v in context['model_descriptors'].items()}}

def raw_row(fixture,row):
 result={k:copy.deepcopy(row[k])for k in ['name','operation','damage_s32','attacker_u32','bound_s32']}
 result.update(body_before_hex=hydrate_buffer(fixture,row['body_before']).hex(),context_before=hydrate_context(fixture,row['context_before']))
 scripts=[]
 for observation in row['observations']:
  script={k:copy.deepcopy(observation[k])for k in ['kind','args','return_u32']};script['patches']=copy.deepcopy(observation.get('authored_patches',[]))
  if 'payload_after_u32'in observation:script['payload_after_u32']=list(observation['payload_after_u32'])
  scripts.append(script)
 result['_scripts']=scripts
 return result

def generate(a):
 if a.reprove_original or not(a.proof_dir/'instruction-proof.json').exists():reprove(a)
 meta,source,kernel=verify(a.proof_dir);rows=build_rows();pool={};serialized=[];native_hash=hashlib.sha256();query_counts={k:0 for k in BOUNDARIES}
 with tempfile.TemporaryDirectory(prefix='source-damage-native-')as directory:
  work=Path(directory);(work/'kernel.s').write_text(kernel)
  subprocess.run(['as','--64','-o',str(work/'kernel.o'),str(work/'kernel.s')],check=True,capture_output=True);subprocess.run(['ld','-o',str(work/'native'),str(work/'kernel.o')],check=True,capture_output=True)
  def execute(row,scripts):
   result=subprocess.run([str(work/'native')],input=packet(row,scripts),capture_output=True,timeout=10)
   if result.returncode or result.stderr:raise ValueError('Damage native failed code%d %s stderr%s'%(result.returncode,row['name'],result.stderr.decode()))
   return result.stdout
  preceding=None;final_raw=[]
  for row in rows:
   if row.get('_carry_previous'):
    row['context_before']['root_hex']=preceding['expected']['context_after']['root_hex']
   scripts=[];occurrences={k:0 for k in BOUNDARIES}
   for step in range(MAX_SCRIPTS+1):
    raw=execute(row,scripts);decoded=decode(raw,row)
    if not decoded['status']:break
    pending=decoded['pending'];kind=pending['kind'];occurrences[kind]+=1
    effects=row.get('_policy',{}).get(kind+':'+str(occurrences[kind]),[])
    returns={'F48':0x13579bdf,'F144_handler':0x2468ace0,'F1907':0x99aabbcc,'F942':0x87654321,'F952':0xfedcba98}
    returns.update(row.get('_return_policy',{}))
    scripts.append({'kind':kind,'args':pending['args'],'return_u32':returns[kind],'patches':effects})
    payload=row.get('_payload_policy',{}).get(kind+':'+str(occurrences[kind]))
    if payload is not None:scripts[-1]['payload_after_u32']=payload
   else:raise ValueError('Native boundary discovery did not terminate')
   for key in list(row.get('_policy',{}))+list(row.get('_payload_policy',{})):
    kind,number=key.rsplit(':',1)
    if occurrences[kind]<int(number):raise ValueError('Directed callback policy never executed '+row['name']+'/'+key)
   runs=[raw]+[execute(row,scripts)for _ in range(2)]
   if len(set(runs))!=1:raise ValueError('Fresh damage native results differ')
   native_hash.update(raw);final_raw.append(raw);row['_scripts']=scripts;row['_decoded']=decoded;preceding=decoded
  # A reversed fresh process order must reproduce the entire captured
  # responses, including Root/event/module state and every callback snapshot.
  reverse_payload=b''.join(packet(r)for r in reversed(rows));reversed_output=subprocess.run([str(work/'native')],input=reverse_payload,capture_output=True,check=True,timeout=60).stdout;cursor=0
  for wanted in reversed(final_raw):
   if reversed_output[cursor:cursor+len(wanted)]!=wanted:raise ValueError('Reverse damage native order differs')
   cursor+=len(wanted)
  if cursor!=len(reversed_output):raise ValueError('Reverse damage output truncated')
 for row in rows:
  decoded=row['_decoded'];initial=encode_snapshot({'body_hex':row['body_before_hex'],'context':row['context_before']},pool);observations=[]
  for native,script in zip(decoded['observations'],row['_scripts']):
   query_counts[native['kind']]+=1;observation={'kind':native['kind'],'args':native['args'],'before':encode_snapshot(native['before'],pool),'after':encode_snapshot(native['after'],pool),'return_u32':native['return_u32'],'authored_patches':script['patches']}
   if 'payload_after_u32'in native:observation['payload_after_u32']=native['payload_after_u32']
   observations.append(observation)
  final=encode_snapshot({'body_hex':decoded['expected']['body_after_hex'],'context':decoded['expected']['context_after']},pool)
  expected={k:v for k,v in decoded['expected'].items()if k not in ['body_after_hex','context_after']};expected.update(body_after=final['body'],context_after=final['context'])
  serialized.append({k:copy.deepcopy(row[k])for k in ['name','operation','damage_s32','attacker_u32','bound_s32']}|{'body_before':initial['body'],'context_before':initial['context'],'observations':observations,'expected':expected,'input_provenance':'authored raw source operands; expected results and all callback snapshots from original native instructions','carries_previous_native_root':bool(row.get('_carry_previous'))})
 dependencies=['tools/rebuild_source_damage_native.py','tools/rebuild_source_natural_contact_native.py','tools/rebuild_source_surface_contact_native.py','recovered-history/ground_harness/tools/build_terrain_query_reference.py','recovered-history/ground_harness/tools/native_reference.py','data/ffe_collision_programs.json','tests/fixtures/source_object_factory_native.json']
 fixture={'schema':'starfrontier-source-damage-native-v1','profile':PROFILE,'case_count':len(rows),'fresh_process_runs':3,'reverse_repeat_cases':len(rows),'consecutive_shared_root_cases':sum(bool(r.get('_carry_previous'))for r in rows),'source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'instruction_proof_sha256':sha((a.proof_dir/'instruction-proof.json').read_bytes()),'original_module_registry':meta['original_module_registry'],'native_output_sha256':native_hash.hexdigest(),'expected_arithmetic_calculated_in_python':False,'all_external_results_explicit':True,'external_requests':query_counts,'source_dependencies_sha256':{p:sha((PROJECT/p).read_bytes())for p in dependencies},'buffer_codec':'sha256-keyed zlib_base64; decoded byte_count and SHA256 must match','buffers':pool,'scope':meta['scope'],'cases':serialized}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(fixture,indent=2)+'\n');print(json.dumps({'case_count':len(rows),'external_requests':query_counts,'sha256':sha(a.output.read_bytes()),'bytes':a.output.stat().st_size,'output':str(a.output)},indent=2))

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--reprove-original',action='store_true');generate(p.parse_args())
if __name__=='__main__':main()
