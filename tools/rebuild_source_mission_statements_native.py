#!/usr/bin/env python3
"""Whole uploaded DOS F41 statement caller and its small instruction helpers.

World/expression/store/lifecycle workers are typed continuations. Observable
invocation-local packet bytes have explicit seed and byte-definedness inputs;
uninitialized bytes are never silently advertised as source-defined zeros.
"""
from __future__ import annotations
import argparse,base64,copy,hashlib,json,re,struct,subprocess,tempfile,zlib
from pathlib import Path
import rebuild_source_mission_expression_native as E
import rebuild_source_mission_store_native as S
N=E.N;PROJECT=E.PROJECT
PROOF=PROJECT/'validation/mission-statements-2026-11-19/statements-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_mission_statements_native.json'
PROFILE='dos-firstenc-mission-statements-v1';MASK=0xffffffff
NUMBERS=[20,23,24,41,1333,1532,999980]
CONTEXT_KEYS=['root','root_tail','bank','program','program_base_u32','ip_u32','task_record','task_slot_u32','vectors','text_buffer','text_cursor_u32']
PROVIDERS={31:2,37:3,52:4,331:6,342:0,326:0,38:1,101:5,102:1,103:1,97:1,98:5,99:2,100:3,104:2,105:1,772:1,39:1,953:3,349:1,345:1,346:1,360:1,1344:3,48:3,352:1,347:1,332:2,359:0,314:11,315:1,664:5,236:3,665:2,666:2,668:2,297:5,290:5,40:9,942:2,926:2,305:3,304:3,702:2,291:2}
BODY_RETURNS=[772,664,665,666,668,297,40,926,291]
VALUE_RETURNS=[31,52,101,1344,314,*BODY_RETURNS]
OBS_KEYS=['kind','args','before','after','return_u32','input_hex','output_hex','input_defined_hex','output_defined_hex']
sha=lambda raw:hashlib.sha256(raw).hexdigest()
STRLEN='''FUNC_999980: ; Pos = 70f04
 push ebp
 mov ebp,esp
 push edi
 mov edi,[ebp+0x8]
 mov ecx,0xffffffff
 xor al,al
 cld
 repne scasb
 not ecx
 lea eax,[ecx-0x1]
 pop edi
 pop ebp
 ret
'''

def source_normalize(source):return re.sub(r'(FUNC_\d+)_\w+',r'\1',source)
def capture_body(source,n):return source_normalize(N.G.block(source,n))
def reprove(a):
 raw=a.exe.read_bytes();original=a.asm.read_bytes();source=source_normalize(original.decode().replace('\r\n','\n'))
 if sha(raw)!=N.EXE_SHA or sha(original)!=N.ASM_SHA:raise ValueError('Pinned DOS/source identity differs')
 bodies={n:capture_body(source,n)for n in NUMBERS if n!=999980};bodies[999980]=STRLEN
 positions=E.positions(source);positions.update(E.positions(STRLEN));aliases=dict(positions);aliases['FUNC_000041']=0x412c38
 # This external call is an actual entry anchor from the independently proved
 # F53/F54 captures; the complete target body is proved again below.
 task=json.loads((PROJECT/'validation/mission-tasks-2026-11-19/task-native-proof/instruction-proof.json').read_text())
 if task['bindings']['FUNC_000041']!=aliases['FUNC_000041']:raise ValueError('F41 lifecycle call anchor differs')
 used=set(re.findall(r'\b(?:DATA|FUNC|JUMP)_\d+|_strlen','\n'.join(bodies.values())))
 missing=sorted(used-set(aliases));fake={name:0x71000000+index*0x10000 for index,name in enumerate(missing)};aliases.update(fake)
 image=N.G.Image(raw)
 for attempt in range(3):
  body=bodies[41];delta=aliases['FUNC_000041']-positions['FUNC_000041']
  for m in re.finditer(r'^\s*((?:JUMP|DATA)_\d+):\s*;\s*Pos = ([0-9a-f]+)',body,re.M):aliases[m[1]]=0x400000+int(m[2],16)+delta
  for start,clean in S.chunks(body,aliases,41)[0]:
   compiled=N.C.J.instructions(N.C.compile32(clean,aliases,'proof_entry',start));actual=N.C.original_rows(a.exe,start,count=len(compiled))
   if len(compiled)!=len(actual):raise ValueError('Original F41 region boundary differs')
   for cr,orr in zip(compiled,actual):
    cv=re.findall('0x[0-9a-f]+',cr[2]);ov=re.findall('0x[0-9a-f]+',orr[2])
    if len(cv)==len(ov):
     for left,right in zip(map(lambda v:int(v,16),cv),map(lambda v:int(v,16),ov)):
      for name,value in fake.items():
       if -1024<left-value<1024:aliases[name]=right-(left-value)
   calls=[]
   for line in clean.splitlines():
    match=re.match(r'\s*call(?: near)?\s+(\[DATA_\d+\]|FUNC_\d+|_strlen)',line)
    if match:calls.append(match[1].strip('[]'))
   actual_calls=[r for r in actual if r[1]=='call']
   if len(calls)!=len(actual_calls):raise ValueError('Original F41 complete call sequence differs')
   for name,row in zip(calls,actual_calls):
    value=int(re.search(r'(?:0x)?([0-9a-f]{6,})',row[2])[1],16);aliases[name]=value
    if name.startswith('DATA_'):
     aliases['FUNC_001532'if name=='DATA_007754'else'FUNC_001344']=struct.unpack_from('<I',raw,image.offset(value,4))[0]
  aliases['FUNC_999980']=aliases['_strlen']
 if aliases['_strlen']!=0x470f04:raise ValueError('Actual F41 strlen target differs')
 # Small helper entries are actual F41 direct/indirect call targets; they are
 # not assumed from the later listing's Pos values.
 records={};dis=[];addresses=set()
 for n in NUMBERS:
  body=bodies[n];delta=aliases['FUNC_%06d'%n]-positions['FUNC_%06d'%n]
  for m in re.finditer(r'^\s*((?:JUMP|DATA)_\d+):\s*;\s*Pos = ([0-9a-f]+)',body,re.M):aliases[m[1]]=0x400000+int(m[2],16)+delta
  regions,tables=S.chunks(body,aliases,n);labels=E.source_labels(body);record={'virtual_address':aliases['FUNC_%06d'%n],'instruction_count':0,'code_regions':[],'inline_tables':[]}
  for index,(start,clean)in enumerate(regions):
   compiled=N.C.J.instructions(N.C.compile32(clean,aliases,'proof_entry',start));actual=N.C.original_rows(a.exe,start,count=len(compiled))
   if E.normalized(compiled)!=E.normalized(actual):raise ValueError(('Whole original F41/helper differs',n,[(i,x,y)for i,(x,y)in enumerate(zip(E.normalized(compiled),E.normalized(actual)))if x!=y][:8]))
   count,items=labels[index]
   if count!=len(actual)or any(aliases[label]!=actual[ordinal][0]for label,ordinal in items):raise ValueError('F41 source labels do not identify original instruction boundaries')
   end=N.C.original_rows(a.exe,start,count=len(compiled)+1)[-1][0];at=image.offset(start,1);endat=image.offset(end,1);code=raw[at:endat]
   row={'virtual_address':start,'executable_offset':at,'byte_length':len(code),'hex':code.hex(),'sha256':sha(code),'instruction_count':len(actual),'normalized_instruction_sha256':sha('\n'.join(E.normalized(actual)).encode()),'source_label_instruction_boundaries':[{'symbol':label,'instruction_index_u32':ordinal,'original_va_u32':actual[ordinal][0]}for label,ordinal in items],'all_original_instructions_equal':True}
   record['code_regions'].append(row);record['instruction_count']+=len(actual);addresses.update(r[0]for r in actual);dis+=['F%d original region%08x'%(n,start),*('%08x: %s %s'%r for r in actual)]
  for name,targets in tables:
   at=image.offset(aliases[name],len(targets)*4);data=raw[at:at+len(targets)*4];wanted=struct.pack('<%dI'%len(targets),*(aliases[t]for t in targets))
   if data!=wanted or any(aliases[t]not in addresses for t in targets):raise ValueError('Actual F41 dispatch table differs from proved targets')
   record['inline_tables'].append({'symbol':name,'virtual_address':aliases[name],'executable_offset':at,'entry_count':len(targets),'hex':data.hex(),'sha256':sha(data),'target_symbols':targets,'target_original_va_u32':[aliases[t]for t in targets],'all_targets_are_proved_instruction_boundaries':True})
  records[str(n)]=record
 if records['41']['instruction_count']!=1430 or len(records['41']['inline_tables'])!=1 or records['41']['inline_tables'][0]['entry_count']!=61:raise ValueError('Whole F41 census differs')
 captured='\n'.join(bodies[n]for n in NUMBERS)+'\nFUNC_999999:\nret\n';root=0x64213c;root_fields={name:value-root for name,value in aliases.items()if name in used and name.startswith('DATA_')and 0<=value-root<0x5810}
 required={'DATA_009133':0x580c,'DATA_008885':0x10a,'DATA_008862':0xcc,'DATA_008861':0xc8,'DATA_008896':0x134}
 if any(root_fields.get(name)!=value for name,value in required.items())or aliases['DATA_008558']!=0x60bf44 or aliases['DATA_002244']!=0x49aa16 or[aliases['DATA_%06d'%n]for n in[1705,1706,1707]]!=[0x48f07c,0x48f080,0x48f084]:raise ValueError('Actual F41 owner aliases differ')
 empty=raw[image.offset(aliases['DATA_002244'],2):image.offset(aliases['DATA_002244'],2)+2]
 if empty!=b'\0\0':raise ValueError('Actual empty-string constant differs')
 meta={'schema':'starfrontier-original-mission-statements-proof-v1','source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'source_procedures_sha256':sha(captured.encode()),'bindings':{name:aliases[name]for name in sorted(used|{'FUNC_001344'})if name in aliases},'root_fields':root_fields,'root_original_va_u32':root,'procedures':records,'whole_procedure_count':len(NUMBERS),'whole_instruction_count':sum(row['instruction_count']for row in records.values()),'F41_instruction_count':1430,'F41_dispatch_target_count':61,'all_code_regions_equal':True,'all_inline_table_bytes_and_targets_equal':True,'source_code_variants':[],'source_table_variants':[],'unmodified_JJFFE_F41_semantics_equal':True,'empty_string_resource':{'original_va_u32':0x49aa16,'hex':empty.hex(),'sha256':sha(empty)},'append_cursor_original_va_u32':0x60bf44,'strlen_original_va_u32':0x470f04,'strlen_instruction_count':13,'entry_anchor':'F41 actual target independently retained by whole F53 lifecycle call proof; all source labels and complete code/table regions are reproved here.','host_adaptations':['Original cdecl argument slots expand4→8 bytes; all original156 local offsets retain their literal byte positions.','Readonly program/vector bytes are unchanged; task+8/+16/+28, Root body references and explicit destination pointers use field/call provenance only.','Only72 caller-observable stack bytes are exposed:20-byte formatter parameters,48-byte UI record and4-byte outlocal. Other84 scalar spills are excluded and their seed bytes remain transport witnesses.','Invocation seed and per-byte00/01 definedness are explicit inputs. Original stores mark only bytes actually initialized; provider writes affect only passed pointer windows.','F664 argument2 and F304/F305 argument0 normalize low8bits consumed by the actual callee interfaces; undefined high-register/stack-address residues are not host pointers or portable scalars.','F1344 is an explicit typed continuation with destination owner/offset and20 parameter bytes. Its text-return pointer becomes a destination offset; source F41 performs its own decrement.','Original _strlen13instructions execute, using host address-size only for scasb; source program capacity and callback limits are bounded transport checks, not original clipping.'],'scope':'Whole F41 plus actual F20/F23/F24/F1333/F1532/strlen; typed expression/store/lifecycle/spawn/UI/text/world workers remain external. No complete F1344 formatter, world services or Main claim.'}
 width_evidence=[]
 for function,argument,sites in[('F664',2,[0x42cb73]),('F304',0,[0x420162]),('F305',0,[0x4201a6]),('F306-shared-byte-consumer',0,[0x4201fa,0x4201fe,0x420209,0x420219,0x420222])]:
  rows=[]
  for address in sites:
   current,following=N.C.original_rows(a.exe,address,count=2);code=raw[image.offset(address,1):image.offset(following[0],1)]
   rows.append({'original_va_u32':address,'hex':code.hex(),'mnemonic':current[1],'operands':current[2]})
  width_evidence.append({'function':function,'argument_index_u32':argument,'consumed_bits_u32':8,'signed_byte_semantics':True,'sites':rows,'whole_callee_claimed':False})
 meta['typed_argument_width_evidence']=width_evidence
 meta['bounded_strlen_admission']='Before executing the unchanged13 strlen instructions, the ABI bridge checks for NUL inside the owned immutable program span; failure is transport exit97, not an original source fault. Packet capture uses the same bounded span.'
 a.proof_dir.mkdir(parents=True,exist_ok=True)
 for name,value in [('source-procedures.asm',captured),('instruction-proof.json',json.dumps(meta,indent=2)+'\n'),('dos-disassembly.txt','\n'.join(dis)+'\n')]: (a.proof_dir/name).write_text(value)
 (a.proof_dir/'statements-native.s').write_text(assembly(captured,meta));(a.proof_dir/'statements-host.c').write_text(HOST_C)
 return meta,captured

def verify(proof=PROOF):
 meta=json.loads((proof/'instruction-proof.json').read_text());source=(proof/'source-procedures.asm').read_text();aliases=meta['bindings'];addresses=set()
 if meta['source_executable_sha256']!=N.EXE_SHA or sha(source.encode())!=meta['source_procedures_sha256']:raise ValueError('Archived statement source identity differs')
 for n in NUMBERS:
  body=N.G.block(source,n);regions,tables=S.chunks(body,aliases,n);record=meta['procedures'][str(n)]
  for index,((start,clean),row)in enumerate(zip(regions,record['code_regions'])):
   compiled=N.C.J.instructions(N.C.compile32(clean,aliases,'proof_entry',start));code=bytes.fromhex(row['hex'])
   if sha(code)!=row['sha256']or len(compiled)!=row['instruction_count']or sha('\n'.join(E.normalized(compiled)).encode())!=row['normalized_instruction_sha256']:raise ValueError('Archived complete statement code differs')
   with tempfile.TemporaryDirectory(prefix='statement-original32-')as directory:
    path=Path(directory)/'code';path.write_bytes(code);actual=N.C.J.instructions(subprocess.check_output(['objdump','-D','-b','binary','-m','i386','-Mintel','--no-show-raw-insn','--adjust-vma='+hex(start),str(path)],text=True))
   if E.normalized(actual)!=E.normalized(compiled):raise ValueError('Captured original statement bytes differ')
   count,labels=E.source_labels(body)[index];wanted=[{'symbol':name,'instruction_index_u32':ordinal,'original_va_u32':actual[ordinal][0]}for name,ordinal in labels]
   if count!=len(actual)or wanted!=row['source_label_instruction_boundaries']or any(aliases[name]!=actual[ordinal][0]for name,ordinal in labels):raise ValueError('Statement source label binding differs')
   addresses.update(r[0]for r in actual)
  for(name,targets),row in zip(tables,record['inline_tables']):
   code=struct.pack('<%dI'%len(targets),*(aliases[t]for t in targets))
   if code!=bytes.fromhex(row['hex'])or sha(code)!=row['sha256']or any(aliases[t]not in addresses for t in targets):raise ValueError('Archived statement inline table differs')
 if (proof/'statements-native.s').read_text()!=assembly(source,meta)or(proof/'statements-host.c').read_text()!=HOST_C:raise ValueError('Archived statement ABI adapter differs')
 for evidence in meta['typed_argument_width_evidence']:
  for row in evidence['sites']:
   with tempfile.TemporaryDirectory(prefix='statement-byte-abi-')as directory:
    path=Path(directory)/'code';path.write_bytes(bytes.fromhex(row['hex']));actual=N.C.J.instructions(subprocess.check_output(['objdump','-D','-b','binary','-m','i386','-Mintel','--no-show-raw-insn','--adjust-vma='+hex(row['original_va_u32']),str(path)],text=True))
   if len(actual)!=1 or actual[0][1:]!=(row['mnemonic'],row['operands']):raise ValueError('Captured actual DOS byte-argument evidence differs')
 return meta,source

def trace(number):return 'pushfq\npush rax\npush rcx\nmov ecx,DWORD PTR [s_trace_count]\nmov DWORD PTR [s_trace+rcx*4],%d\ninc DWORD PTR [s_trace_count]\npop rcx\npop rax\npopfq\n'%number
def assembly(source,meta):
 selected=source.replace('call _strlen','call FUNC_999980').replace('SECTION .data','.section .rodata').replace('SECTION .text','.section .text');selected=re.sub(r'^\s*dd\s+',r'.long ',selected,flags=re.M)
 selected=re.sub(r'\+0x(f[0-9a-f]{7})',lambda m:'-0x%x'%(0x100000000-int(m[1],16)),selected);selected=re.sub(r'add esp,0x(f[0-9a-f]{7})',lambda m:'add esp,-0x%x'%(0x100000000-int(m[1],16)),selected)
 lines,_=N.Q.procedures(selected,NUMBERS);text='\n'.join(lines);text=re.sub(r'\[rbp[^\]]*\]',lambda m:re.sub(r'\b(eax|ebx|ecx|edx|esi|edi)\b',lambda r:'r'+r[1][1:],m[0]),text)
 text=re.sub(r'jmp \[(e\w+)\*4\+(DATA_\d+)\]',lambda m:'mov r11d,DWORD PTR [r'+m[1][1:]+'*4+'+m[2]+']\njmp r11',text);text=re.sub(r'call QWORD PTR \[(DATA_\d+)\]',r'mov r11d,DWORD PTR [\1]\ncall r11',text)
 text=text.replace('repne scasb','repne scasb')
 for n in NUMBERS:text=text.replace('FUNC_%06d:\n'%n,'FUNC_%06d:\n'%n+trace(n),1)
 marker='FUNC_999980:\n'+trace(999980)
 text=text.replace(marker,marker+'''pushfq
push rax
push rcx
push rdx
push rsi
push rdi
push r11
push r12
mov r12,rsp
mov edi,DWORD PTR [rsp+72]
and rsp,-16
call s_strlen_admit
mov rsp,r12
pop r12
pop r11
pop rdi
pop rsi
pop rdx
pop rcx
pop rax
popfq
''',1)
 # Only actual writes into pointer-backed observable windows update masks.
 output=[]
 for line in text.splitlines():
  output.append(line);match=re.match(r'mov (?:DWORD PTR )?\[rbp-0x([0-9a-f]+)\],(?:eax|0x[0-9a-f]+)$',line)
  if match:
   at=156-int(match[1],16)
   if 0<=at<20 or 20<=at<68 or 152<=at<156:output.append('mov DWORD PTR [s_defined+%d],0x01010101'%at)
 text='\n'.join(output)
 marker='add rsp,-156\npush rbx\npush rsi\npush rdi'
 if text.count(marker)!=1:raise ValueError('F41 literal156-byte local frame differs')
 text=text.replace(marker,marker+'''\npush rax
push rcx
push rsi
push rdi
mov esi,OFFSET FLAT:s_seed
lea edi,[rbp-156]
mov DWORD PTR [s_frame],edi
mov ecx,156
rep movsb
pop rdi
pop rsi
pop rcx
pop rax''',1)
 # Invocation budget is an explicit host admission bound, not a source exit.
 text=text.replace('JUMP_000359:','JUMP_000359:\npushfq\ninc DWORD PTR [s_steps]\ncmp DWORD PTR [s_steps],4096\njbe s_budget_ok\nand rsp,-16\ncall s_budget_abort\ns_budget_ok:\npopfq\n',1)
 marker='movzx eax,BYTE PTR [eax]'
 if text.count(marker)!=1:raise ValueError('F41 opcode-fetch site differs')
 text=text.replace(marker,marker+'\npushfq\ninc DWORD PTR [s_opcodes+rax*4]\npopfq')
 bridges=[]
 for n,argc in PROVIDERS.items():
  loads=['mov eax,DWORD PTR [rbp+%d]\nmov DWORD PTR [s_args+%d],eax'%(16+index*8,index*4)for index in range(argc)]
  bridges.append('FUNC_%06d:\n'%n+trace(n)+'''push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
push r12
mov r12,rsp
'''+ '\n'.join(loads)+'''\nmov edi,%d
and rsp,-16
call s_observe
mov rsp,r12
pop r12
pop rdi
pop rsi
pop rbx
pop rbp
ret
'''%n)
 aliases=['%s=s_root+%d'%(name,at)for name,at in meta['root_fields'].items()]
 aliases+=['DATA_008558=s_text_pointer','DATA_001705=s_vectors','DATA_001706=s_vectors+4','DATA_001707=s_vectors+8','DATA_002244=s_empty']
 return '.intel_syntax noprefix\n.code64\n.section .text\n'+text+'\n'+''.join(bridges)+'''
.global call_kernel
call_kernel:
mov [s_saved_rsp],rsp
mov esp,OFFSET FLAT:s_stack_end
push OFFSET FLAT:s_task
push OFFSET FLAT:s_ip
call FUNC_000041
mov rsp,[s_saved_rsp]
ret
.section .data
DATA_007754:.long FUNC_001532
DATA_007639:.long FUNC_001344
s_empty:.byte 0,0
'''+ '\n'.join(aliases)+'''
.section .bss
.balign 16
s_stack:.zero 4194304
s_stack_end:
s_saved_rsp:.zero 8
.section .note.GNU-stack,"",@progbits
'''

def context_packet(ctx):
 return bytes.fromhex(ctx['root'])+bytes.fromhex(ctx['root_tail'])+bytes.fromhex(ctx['bank'])+bytes.fromhex(ctx['task_record'])+bytes.fromhex(ctx['program'])+bytes.fromhex(ctx['vectors'])+bytes.fromhex(ctx['text_buffer'])
def packet(row):
 ctx=row['context_before'];scripts=row.get('scripts',[]);scratch=row['scratch'];raw=struct.pack('<7I',ctx['program_base_u32'],len(bytes.fromhex(ctx['program'])),len(bytes.fromhex(ctx['text_buffer'])),ctx['ip_u32'],ctx['text_cursor_u32'],ctx['task_slot_u32'],len(scripts))+context_packet(ctx)+bytes.fromhex(scratch['seed_hex'])+bytes.fromhex(scratch['defined_hex'])
 for script in scripts:
  args=script['args'];patches=script.get('patches',[]);out=bytes.fromhex(script.get('output_hex',''));mask=bytes.fromhex(script.get('output_defined_hex',''))
  raw+=struct.pack('<16I',script['kind'],len(args),*args,*([0]*(11-len(args))),script['return_u32'],len(patches),len(out))
  for patch in patches:
   data=bytes.fromhex(patch['hex']);raw+=struct.pack('<3I',patch['owner'],patch['offset'],len(data))+data.ljust(64,b'\0')
  raw+=out+mask
 return struct.pack('<I',len(raw))+raw
class Reader:
 def __init__(self,raw,row):self.raw=raw;self.at=40;self.base=row['context_before'];self.size=8+22544+38986+36+len(bytes.fromhex(self.base['text_buffer']))
 def take(self,n):
  value=self.raw[self.at:self.at+n]
  if len(value)!=n:raise ValueError('Statement native output truncated')
  self.at+=n;return value
 def word(self):return struct.unpack('<I',self.take(4))[0]
 def context(self):
  value=copy.deepcopy(self.base);value['ip_u32']=self.word();value['text_cursor_u32']=self.word();value['root']=self.take(16384).hex();value['root_tail']=self.take(6160).hex();value['bank']=self.take(38986).hex();value['task_record']=self.take(36).hex();value['text_buffer']=self.take(len(bytes.fromhex(self.base['text_buffer']))).hex();return value
def decode(raw,row):
 h=struct.unpack_from('<10I',raw)
 if h[0]!=0x41ab3257 or h[1]!=len(raw)or h[2]>2:raise ValueError('Statement native header differs')
 reader=Reader(raw,row);observations=[]
 for index in range(h[4]):
  kind=reader.word();argc=reader.word();args=list(struct.unpack('<11I',reader.take(44)))[:argc];returned=reader.word();insize=reader.word();outsize=reader.word();before=reader.context();inputbytes=reader.take(insize);inputmask=reader.take(insize);after=reader.context();outbytes=reader.take(outsize);outmask=reader.take(outsize)
  observations.append({'kind':'F%d'%kind,'args':args,'before':before,'after':after,'return_u32':returned,'input_hex':inputbytes.hex(),'output_hex':outbytes.hex(),'input_defined_hex':inputmask.hex(),'output_defined_hex':outmask.hex()})
 if reader.at!=h[5]:raise ValueError('Statement native observation extent differs')
 final=reader.context();seed=reader.take(156).hex();defined=reader.take(156).hex()
 if reader.at!=h[6]:raise ValueError('Statement final context extent differs')
 order=['_strlen'if value==999980 else'F%d'%value for value in struct.unpack('<%dI'%h[7],reader.take(h[7]*4))];opcodes=list(struct.unpack('<256I',reader.take(1024)))
 if reader.at!=len(raw):raise ValueError('Statement native trailing output differs')
 result={'status':h[2],'context_after':final,'return_u32':0,'return_defined':False,'cursor_after_u32':final['ip_u32'],'source_order':order,'observations':observations,'observations_used':len(observations)-(1 if h[2]==1 else 0),'scratch_after_hex':seed,'scratch_defined_hex':defined,'opcode_counts_u32':opcodes,'dispatch_iterations_u32':h[8]}
 result['pending']=copy.deepcopy(observations[-1])if h[2]==1 else None
 if result['pending']:
  pending=result['pending'];kind=int(pending['kind'][1:]);size=48 if kind in[331,345,346,347,349,352,360]and pending['input_hex']else 20 if kind==1344 else 4 if kind in[304,305]else 0;pending['output_byte_count_u32']=size
 return result
def build(meta,source,folder):
 folder=Path(folder);folder.mkdir(parents=True,exist_ok=True);native=assembly(source,meta);(folder/'native.s').write_text(native);(folder/'host.c').write_text(HOST_C);binary=folder/'native'
 done=subprocess.run(['gcc','-O1','-fno-pie','-no-pie','-fno-stack-protector','-o',str(binary),str(folder/'native.s'),str(folder/'host.c')],capture_output=True,text=True)
 if done.returncode:raise ValueError(done.stderr)
 return binary,native
def run(binary,row):return subprocess.run([str(binary)],input=packet(row),capture_output=True,timeout=30)
def run_case(binary,row):
 result=run(binary,row)
 if result.returncode or result.stderr:raise ValueError(('Statement native run failed',row.get('name',''),result.returncode,result.stderr[:300]))
 return decode(result.stdout,row)
def measure(binary,row):return run_case(binary,row)

def patch_word(owner,offset,value):return {'owner':owner,'offset':offset,'hex':struct.pack('<I',value&MASK).hex()}
def mask(count,value=1):return bytes([value])*count
def base_context(payload=b'\0'):
 program=bytearray(4096);program[:len(payload)]=payload;base=0x4801c4
 struct.pack_into('<8I',program,0x200,base+0x280,0,0,MASK,4,0,0,base+0x300);struct.pack_into('<I',program,0x220,base+0x340)
 expr=E.base_context(program);resources=json.loads((PROJECT/'data/ffe_mission_programs.json').read_text());record=bytearray(36);struct.pack_into('<IHH7I',record,0,2,7,3,base+0x300,MASK,base+0x300,0,0,base+0x200,17)
 return {key:expr[key]for key in['root','root_tail','bank','program']}|{'program_base_u32':base,'ip_u32':0,'task_record':record.hex(),'task_slot_u32':7,'vectors':resources['regions']['vectors']['hex'],'text_buffer':(bytes([0x5a])*512).hex(),'text_cursor_u32':7}

def authored(opcode,values=None,variant=None):
 values=list(values or[]);answers={};stores={};data=bytearray([opcode])
 def expression(value):
  at=len(data);data.extend(E.immediate(value));answers[str(at)]={'return_u32':value&MASK,'ip_after_u32':at+5}
 def target():
  at=len(data);data.extend(b'\x06'+struct.pack('<I',2));stores[str(at)]=at+5
 counts={4:6,7:1,8:1,11:1,12:1,13:1,14:3,15:2,16:3,17:2,18:1,19:1,20:1,21:3,22:1,23:1,24:1,25:1,26:2,27:2,28:2,29:1,30:2,31:3,32:1,33:2,35:1,36:2,38:1,39:4,40:2,41:2,42:2,43:2,44:2,45:3,46:2,47:3,48:5,49:5,50:9,51:2,52:2,53:3,54:3,55:3,56:4,57:1,58:2,59:5,60:3}
 defaults={8:[0x00030007],19:[9],21:[9,0x12345678,0x80000000],26:[9,0x9c01],39:[1,2,0xfedcba98,MASK],40:[1,2],47:[9,0x9c02,0x12345678],49:[1,2,3,MASK,5],50:[1,9,2,3,4,5,0xffff8000,31,0xffff8001],51:[9,0x12345678],52:[0x1111,9],53:[1,0x12345680,42],54:[9,42,0x87654321],57:[9],58:[9,1002],60:[9,0xabcdef98,26]}
 if opcode==1:data.extend(struct.pack('<I',0));target()
 elif opcode==2:expression(1 if variant=='true'else 0);data.extend(struct.pack('<I',4))
 elif opcode==3:data.extend(struct.pack('<I',4))
 elif opcode==9:data.extend(struct.pack('<I',0 if variant is None else variant))
 elif opcode==10:
  data.extend(('Космос'if variant=='utf8'else''if variant=='empty'else'Literal packet').encode()+b'\0')
  for value in values or[11,22,33,44]:expression(value)
  target()
 elif opcode==37:target()
 elif opcode in counts:
  args=values or defaults.get(opcode,[(0x12345678+index*0x11111111)&MASK for index in range(counts[opcode])])
  if len(args)!=counts[opcode]:raise ValueError('Authored statement argument count differs')
  for value in args:expression(value)
  if opcode in[7,19,39,41,42,43,48,50,52,58]:target()
 data.append(0)
 return bytes(data),answers,stores

def cases():
 rows=[]
 def add(name,opcode,values=None,variant=None,policy=None,context=None,seed=None):
  payload,answers,stores=authored(opcode,values,variant);row={'name':name,'opcode_u32':opcode,'context_before':context or base_context(payload),'scratch':{'seed_hex':(bytes((index*13+7)&255 for index in range(156))if seed is None else seed).hex(),'defined_hex':bytes(156).hex()},'answers':answers,'stores':stores,'policy':policy or {},'scripts':[]};rows.append(row);return row
 for opcode in range(256):add('selector-%03d'%opcode,opcode)
 add('conditional-true',2,variant='true')
 add('inline-string-utf8-byte-length',10,variant='utf8')
 add('inline-string-empty-byte-length',10,variant='empty')
 add('nullable-F331-packet',4,[11,22,0,44,55,66])
 add('cancellation-other-handle-continues',8,[0xdeadbeef])
 for kind,opcode in[(772,19),(664,39),(665,41),(666,42),(668,43),(297,48),(40,50),(926,52),(291,58)]:add('returned-null-F%d'%kind,opcode,policy={'F%d'%kind:{'return_u32':0}})
 for op in[22,23,24,25,27,28,29,30,31,32,44,46,55,56,59]:
  add('observable-seed-00-selector%d'%op,op,seed=bytes(156));add('observable-seed-ff-selector%d'%op,op,seed=bytes([255])*156)
 for mode in[0,2,3,MASK]:add('output-local-mode-%x'%mode,53,[mode,0x89abcdef,42])
 for index in[0,1,26,0x40000000,0x80000000,0xc0000000]:add('vector-source-index-%x'%index,60,[9,0xffffffff,index])
 for slot in[0,114,0x80000000,0x80000001]:add('wrapped-body-slot-%x'%slot,57,[slot])
 for item in[999,1000,1037,1038,0xffffffff]:add('inventory-item-boundary-%x'%item,58,[17,item])
 row=add('inventory-player-zero-no-spawn',58,[17,1002]);root=bytearray.fromhex(row['context_before']['root']);struct.pack_into('<H',root,0x134+2*2,0);row['context_before']['root']=root.hex()
 add('block-transition-index1',9,variant=1)
 for index in[0x40000000,0x80000000,0xc0000000]:add('wrapped-block-transition-index-%x'%index,9,variant=index)
 add('F31-state-mutation-does-not-stop-F41',7,policy={'F31':{'patches':[patch_word(3,0,6)]}})
 add('cancellation-reloads-mutated-handle',8,[0xdeadbeef],policy={'F38':{'patches':[patch_word(3,4,0xdeadbeef)]}})
 add('captured-bank-pointer-before-expression',57,[9],policy={'F31':{'patches':[patch_word(1,0x180c,0)]}})
 # Two genuine statement streams within one invocation exercise retained local
 # packet words/masks; callback writes are visible to the following worker.
 for first,second in[(22,23),(31,24),(36,35),(53,53),(59,25)]:
  a,answers,stores=authored(first);b,answers2,stores2=authored(second);offset=len(a)-1;payload=a[:-1]+b;answers.update({str(int(key)+offset):{'return_u32':value['return_u32'],'ip_after_u32':value['ip_after_u32']+offset}for key,value in answers2.items()});stores.update({str(int(key)+offset):value+offset for key,value in stores2.items()});row=add('same-invocation-local-reuse-%d-%d'%(first,second),first,context=base_context(payload));row['answers']=answers;row['stores']=stores
  if first==53:row['policy']={'F305:0':{'output_hex':'12345678','output_defined_hex':'01010101'}}
 row=add('UI-provider-writes-accessible-record',23,policy={'F345':{'output_hex':bytes(range(48)).hex(),'output_defined_hex':bytes([1]*48).hex()}})
 row=add('formatter-writes-accessible-parameters',36,policy={'F1344':{'output_hex':bytes(range(20)).hex(),'output_defined_hex':bytes([1]*20).hex()}})
 # Real immutable original resources, source cursor and descriptor identities.
 doc=json.loads((PROJECT/'data/ffe_mission_programs.json').read_text());program=bytes.fromhex(doc['regions']['mission']['hex']);base=doc['regions']['mission']['original_va_u32'];owners={offset:module for module in doc['modules']for offset in module['block_offsets_u32']};counts={0:0,7:0}
 for block in doc['blocks'].values():
  at=block['initialization_offset_u32'];opcode=program[at]
  if opcode not in counts or counts[opcode]>=8 or(opcode==7 and program[at+1]!=2):continue
  if opcode==7 and program[block['block_offset_u32']-1]!=0:continue
  module=owners[block['block_offset_u32']];ctx=base_context();ctx['program']=program.hex();ctx['program_base_u32']=base;ctx['ip_u32']=at;task=bytearray.fromhex(ctx['task_record']);struct.pack_into('<I',task,28,base+module['descriptor_offset_u32']);ctx['task_record']=task.hex();row=add('actual-module%d-block%d-prefix'%(module['module_index_u32'],block['block_offset_u32']),opcode,context=ctx);row['answers']={};row['stores']={};row['actual_original_resource']=True
  if opcode==7:row['answers'][str(at+1)]={'return_u32':struct.unpack_from('<I',program,at+2)[0],'ip_after_u32':at+6};row['stores'][str(at+6)]=block['block_offset_u32']-1
  counts[opcode]+=1
 # Twelve exact transitions share one immutable program and complete owner set.
 payload=b'';answers={};stores={}
 for step in range(12):
  stream,a,s=authored(7,[0x11110000+step]);offset=len(payload);answers.update({str(int(k)+offset):{'return_u32':v['return_u32'],'ip_after_u32':v['ip_after_u32']+offset}for k,v in a.items()});stores.update({str(int(k)+offset):v+offset for k,v in s.items()});payload+=stream
 for step in range(12):
  row=add('dependent-owner-and-frame-%02d'%step,7,context=base_context(payload),policy={'F37':{'patches':[patch_word(0,0x180,step)]}});row['answers']=answers;row['stores']=stores;row['carries_previous_native_state']=step>0;row['carries_previous_measured_frame']=step>0
 return rows

def choose_script(row,pending,occurrence):
 kind=pending['kind'];policy=copy.deepcopy(row['policy'].get(kind+':'+str(occurrence),row['policy'].get(kind,{})));patches=policy.get('patches',[]);returned=policy.get('return_u32',0);ip=pending['before']['ip_u32'];name=int(kind[1:])
 if kind=='F31':
  answer=row['answers'].get(str(ip))
  if not answer:raise ValueError(('No authored expression continuation',row['name'],ip))
  returned=answer['return_u32'];patches=[patch_word(5,0,answer['ip_after_u32']),*patches]
 elif kind=='F37':
  if str(ip)not in row['stores']:raise ValueError(('No authored lvalue continuation',row['name'],ip))
  patches=[patch_word(5,0,row['stores'][str(ip)]),*patches]
 elif kind=='F52':returned=policy.get('return_u32',0x45670003)
 elif name in BODY_RETURNS:returned=policy.get('return_u32',116+9*338)
 elif kind in['F101','F314']:returned=policy.get('return_u32',0x76543210)
 elif kind=='F1344':
  owner,at,_=pending['args'];patches=[{'owner':4 if owner==0 else 2,'offset':at,'hex':'4f4b00'},*patches];returned=policy.get('return_u32',at+3)
 output=policy.get('output_hex','');defined=policy.get('output_defined_hex','')
 if kind in['F304','F305']and not output:output='efcdab89';defined='01010101'
 return {'kind':name,'args':pending['args'],'return_u32':returned,'patches':patches,'output_hex':output,'output_defined_hex':defined}
def fill(binary,row):
 counts={}
 for _ in range(257):
  value=run_case(binary,row)
  if value['status']==0:return value
  if value['status']!=1:raise ValueError('Unexpected bounded source loop in normal statement corpus')
  pending=value['pending'];kind=pending['kind'];occurrence=counts.get(kind,0);counts[kind]=occurrence+1;row['scripts'].append(choose_script(row,pending,occurrence))
 raise ValueError('Statement callback discovery limit')
def pool_context(ctx,pool):
 result=copy.deepcopy(ctx)
 for key in['root','root_tail','bank','program','task_record','vectors','text_buffer']:
  data=bytes.fromhex(result[key]);digest=sha(data)
  if digest not in pool:pool[digest]={'byte_count':len(data),'zlib_base64':base64.b64encode(zlib.compress(data,9)).decode()}
  result[key]=digest
 return result
def hydrate_context(doc,ctx):
 result=copy.deepcopy(ctx)
 for key in['root','root_tail','bank','program','task_record','vectors','text_buffer']:
  row=doc['buffer_pool'][result[key]];data=zlib.decompress(base64.b64decode(row['zlib_base64']))
  if len(data)!=row['byte_count']or sha(data)!=result[key]:raise ValueError('Pooled statement owner differs')
  result[key]=data.hex()
 return result
def special_domains(binary):
 domains=[]
 for name,opcode,mutate in[('null-bank-direct-body-write',57,'bank'),('null-descriptor-block-transition',9,'descriptor')]:
  payload,answers,stores=authored(opcode);ctx=base_context(payload)
  if mutate=='bank':data=bytearray.fromhex(ctx['root_tail']);struct.pack_into('<I',data,0x180c,0);ctx['root_tail']=data.hex()
  else:data=bytearray.fromhex(ctx['task_record']);struct.pack_into('<I',data,28,0);ctx['task_record']=data.hex()
  row={'name':name,'opcode_u32':opcode,'context_before':ctx,'scratch':{'seed_hex':bytes(156).hex(),'defined_hex':bytes(156).hex()},'answers':answers,'stores':stores,'policy':{},'scripts':[]}
  observations=[]
  if opcode==57:
   pending=run_case(binary,row)['pending'];script=choose_script(row,pending,0);row['scripts'].append(script);after=copy.deepcopy(pending['before']);after['ip_u32']=answers[str(pending['before']['ip_u32'])]['ip_after_u32'];observations.append({key:copy.deepcopy(pending[key])for key in['kind','args','before','input_hex','input_defined_hex']}|{'after':after,'return_u32':script['return_u32'],'output_hex':'','output_defined_hex':''})
  processes=[run(binary,row)for _ in range(3)]
  if any(p.returncode!=-11 or p.stdout for p in processes):raise ValueError(('Original statement fault domain differs',name,[(p.returncode,p.stderr[:100])for p in processes]))
  domains.append({'name':name,'context_before':ctx,'scratch':row['scratch'],'observations':observations,'actual_native_process_returncode':-11,'fresh_native_process_runs':3,'source_signal':'SIGSEGV','expected_complete_native_context_after_available':False,'after_state_claimed':False,'prefault_callbacks_are_explicit_authored_continuations':True})
 payload=bytes([3])+struct.pack('<I',MASK);row={'name':'literal-backward-jump-nontermination','context_before':base_context(payload),'scratch':{'seed_hex':bytes(156).hex(),'defined_hex':bytes(156).hex()},'scripts':[]};values=[run_case(binary,row)for _ in range(3)]
 if any(value['status']!=2 or value['dispatch_iterations_u32']!=4097 for value in values):raise ValueError('Literal F41 loop did not reach explicit host budget')
 bounded=[{'name':row['name'],'context_before':row['context_before'],'scratch':row['scratch'],'observations':[],'fresh_native_process_runs':3,'native_host_status_u32':2,'dispatch_budget_u32':4096,'source_termination_claimed':False,'after_state_claimed':False}]
 ctx=base_context();ctx['program']=b'\x0aABC'.hex();row={'name':'unterminated-literal-owned-span-rejection','context_before':ctx,'scratch':{'seed_hex':bytes(156).hex(),'defined_hex':bytes(156).hex()},'scripts':[]};processes=[run(binary,row)for _ in range(3)]
 if any(p.returncode!=97 or p.stdout for p in processes):raise ValueError('Owned literal span admission differs')
 unsupported=[{'name':row['name'],'context_before':ctx,'scratch':row['scratch'],'observations':[],'fresh_native_process_runs':3,'native_transport_exit_code':97,'original_source_fault_claimed':False,'after_state_claimed':False}]
 return domains,bounded,unsupported
def generate(a,meta,source):
 rows=cases();pool={};serialized=[];all_opcodes=set();boundary_count=0;previous=None;raws=[]
 with tempfile.TemporaryDirectory(prefix='statement-native-')as directory:
  binary,_=build(meta,source,directory)
  for index,row in enumerate(rows):
   if row.get('carries_previous_native_state'):row['context_before']=copy.deepcopy(previous['context_after'])
   if row.get('carries_previous_measured_frame'):row['scratch']={'seed_hex':previous['scratch_after_hex'],'defined_hex':previous['scratch_defined_hex']}
   value=fill(binary,row);runs=[run(binary,row)for _ in range(3)]
   if any(p.returncode or p.stderr for p in runs)or len({p.stdout for p in runs})!=1:raise ValueError('Fresh statement native process cohorts differ '+row['name'])
   raw=runs[0].stdout;raws.append(raw);previous=value;all_opcodes.update(i for i,count in enumerate(value['opcode_counts_u32'])if count);boundary_count+=len(value['observations']);observations=[]
   for observation in value['observations']:
    item=copy.deepcopy(observation);item['before']=pool_context(item['before'],pool);item['after']=pool_context(item['after'],pool);observations.append(item)
   expected={key:copy.deepcopy(value[key])for key in['context_after','return_u32','return_defined','cursor_after_u32','source_order','scratch_after_hex','scratch_defined_hex','opcode_counts_u32','dispatch_iterations_u32']};expected['context_after']=pool_context(expected['context_after'],pool)
   serialized.append({'name':row['name'],'opcode_u32':row['opcode_u32'],'context_before':pool_context(row['context_before'],pool),'scratch':row['scratch'],'observations':observations,'expected':expected,'actual_original_resource':bool(row.get('actual_original_resource')),'carries_previous_native_state':bool(row.get('carries_previous_native_state')),'carries_previous_measured_frame':bool(row.get('carries_previous_measured_frame'))})
   if index%50==0:print(index,row['name'],flush=True)
  reverse=subprocess.run([str(binary)],input=b''.join(packet(row)for row in reversed(rows)),capture_output=True,timeout=60)
  if reverse.returncode or reverse.stderr:raise ValueError(('Reverse statement process failed',reverse.returncode,reverse.stderr[:200]))
  cursor=0
  for row,wanted in zip(reversed(rows),reversed(raws)):
   actual=reverse.stdout[cursor:cursor+len(wanted)]
   if actual!=wanted:raise ValueError(('Reverse statement process cohort differs',row['name'],next((i for i,(x,y)in enumerate(zip(actual,wanted))if x!=y),-1)))
   cursor+=len(wanted)
  faults,bounded,unsupported=special_domains(binary)
 for domain in faults+bounded+unsupported:
  domain['context_before']=pool_context(domain['context_before'],pool)
  for observation in domain['observations']:
   observation['before']=pool_context(observation['before'],pool);observation['after']=pool_context(observation['after'],pool)
 if all_opcodes!=set(range(256)):raise ValueError('Statement selector byte census is incomplete')
 dependencies=['tools/rebuild_source_mission_statements_native.py','tools/rebuild_source_mission_expression_native.py','tools/rebuild_source_mission_store_native.py','data/ffe_mission_programs.json','validation/mission-tasks-2026-11-19/task-native-proof/instruction-proof.json']
 for path in json.loads(E.FIXTURE.read_text())['source_dependencies_sha256']:
  if path not in dependencies:dependencies.append(path)
 proof_files=['source-procedures.asm','instruction-proof.json','dos-disassembly.txt','statements-native.s','statements-host.c']
 document={'schema':'starfrontier-mission-statements-native-v1','profile':PROFILE,'case_count':len(serialized),'F41_instruction_count':1430,'whole_original_procedures':7,'whole_original_instructions':1509,'inline_dispatch_targets':61,'all_256_opcode_bytes_executed':True,'fresh_process_runs':3,'reverse_repeat_cases':len(rows),'typed_boundary_count':boundary_count,'actual_original_resource_cases':sum(row['actual_original_resource']for row in serialized),'consecutive_native_state_transitions':sum(row['carries_previous_native_state']for row in serialized),'consecutive_measured_frame_transitions':sum(row['carries_previous_measured_frame']for row in serialized),'source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'source_dependencies_sha256':{path:sha((PROJECT/path).read_bytes())for path in dependencies},'proofs_sha256':{name:sha((a.proof_dir/name).read_bytes())for name in proof_files},'buffer_codec':'sha256-zlib-base64-v1','buffer_pool':pool,'expected_arithmetic_calculated_in_python':False,'uninitialized_stack_bytes_have_explicit_seed_and_mask':True,'observable_scratch_byte_count':72,'source_code_variants':[],'source_table_variants':[],'original_fault_domains_separate':faults,'bounded_nontermination_domains_separate':bounded,'unsupported_transport_domains':['Unowned program/descriptor/vector spans; no claim that an original valid adjacent resource read would be a null fault.','Bank selector0 body lookup returns a literal low address and cannot be silently repaired into the owned bank.','F1344 destination capacity is bounded transport admission, not original source clipping.'],'cases':serialized,'scope':meta['scope']}
 document['unsupported_transport_cases']=unsupported
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(document,indent=2)+'\n');print(json.dumps({'case_count':len(rows),'typed_boundaries':boundary_count,'fixture_sha256':sha(a.output.read_bytes()),'bytes':a.output.stat().st_size},indent=2))

def main():
 p=argparse.ArgumentParser(description=__doc__)
 for name,default in [('exe','/workspace/ffe-original/FIRSTENC.EXE'),('asm','/workspace/ffe-upstream/jjffe/ffe.asm'),('data','/workspace/ffe-upstream/jjffe/ffedat.asm'),('mission-asm','/workspace/ffe-upstream/jjffe/ffebmp.asm')]:p.add_argument('--'+name,type=Path,default=Path(default))
 p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--reprove-original',action='store_true');a=p.parse_args();meta,source=reprove(a)if a.reprove_original else verify(a.proof_dir)
 generate(a,meta,source)
HOST_C=r'''
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <setjmp.h>
#define CAP (256u*1024u*1024u)
#define CHECK(x) do{if(!(x)){fprintf(stderr,"statement-native:%d\n",__LINE__);exit(97);}}while(0)
#define GUARD UINT64_C(0xa56d697373696f6e)
#define GUARDED(name,N) struct __attribute__((packed)){uint64_t a;uint8_t data[N];uint64_t b;}name __attribute__((aligned(16)))
GUARDED(g_root,22544);GUARDED(g_bank,38986);GUARDED(g_task,36);GUARDED(g_program,65536);GUARDED(g_vectors,324);GUARDED(g_text,65536);
asm(".global s_root,s_bank,s_task,s_program,s_vectors,s_text\ns_root=g_root+8\ns_bank=g_bank+8\ns_task=g_task+8\ns_program=g_program+8\ns_vectors=g_vectors+8\ns_text=g_text+8");
#define s_root g_root.data
#define s_bank g_bank.data
#define s_task g_task.data
#define s_program g_program.data
#define s_vectors g_vectors.data
#define s_text g_text.data
uint32_t s_ip,s_text_pointer,s_args[11],s_frame,s_steps,s_trace_count,s_trace[16384],s_opcodes[256];uint8_t s_seed[156],s_defined[156];
static uint8_t input[16*1024*1024],output[CAP],visible[156],*cursor,*end;static uint32_t base,length,text_length,slot,script_count,used,status,outpos;static jmp_buf env;
extern void call_kernel(void);
static uint32_t get(const void*p){uint32_t v;memcpy(&v,p,4);return v;}static void put(void*p,uint32_t v){memcpy(p,&v,4);}
static uint32_t ptr(const void*p){CHECK((uintptr_t)p<=0xffffffffu);return(uint32_t)(uintptr_t)p;}
static uint32_t read32(void){CHECK(cursor+4<=end);uint32_t v=get(cursor);cursor+=4;return v;}
static void bytes(void*p,uint32_t n){CHECK(cursor+n<=end);memcpy(p,cursor,n);cursor+=n;}
static void emit32(uint32_t v){CHECK(outpos+4<CAP);put(output+outpos,v);outpos+=4;}
static void emit(const void*p,uint32_t n){CHECK(outpos+n<CAP);memcpy(output+outpos,p,n);outpos+=n;}
static uint32_t body_host(uint32_t value){if(!value)return 0;CHECK(value>=116&&(value-116)%338==0&&(value-116)/338<=114);return ptr(s_bank)+value;}
static uint32_t body_raw(uint32_t value){if(!value)return 0;CHECK(value>=ptr(s_bank)+116&&value<=ptr(s_bank)+116+114*338&&(value-ptr(s_bank)-116)%338==0);return value-ptr(s_bank);}
static uint32_t source_ref(uint32_t value){return value>=ptr(s_program)&&value<ptr(s_program)+length?base+value-ptr(s_program):value;}
static uint32_t host_ref(uint32_t value){return value>=base&&value<base+length?ptr(s_program)+value-base:value;}
static void import_task(void){for(uint32_t at=8;at<=28;at+=at==16?12:8)put(s_task+at,host_ref(get(s_task+at)));}
static void raw_task(uint8_t*data){memcpy(data,s_task,36);for(uint32_t at=8;at<=28;at+=at==16?12:8)put(data+at,source_ref(get(data+at)));}
static void import_root(void){put(s_root+0xc8,body_host(get(s_root+0xc8)));put(s_root+0xcc,body_host(get(s_root+0xcc)));uint32_t bank=get(s_root+0x580c);CHECK(bank<=1);put(s_root+0x580c,bank?ptr(s_bank):0);}
static void capture(void){
 CHECK(s_ip>=ptr(s_program)&&s_ip<=ptr(s_program)+length);CHECK(s_text_pointer>=ptr(s_text)&&s_text_pointer<=ptr(s_text)+text_length);
 emit32(s_ip-ptr(s_program));emit32(s_text_pointer-ptr(s_text));uint8_t root[22544],task[36];memcpy(root,s_root,22544);put(root+0xc8,body_raw(get(root+0xc8)));put(root+0xcc,body_raw(get(root+0xcc)));uint32_t bank=get(root+0x580c);CHECK(bank==0||bank==ptr(s_bank));put(root+0x580c,bank!=0);emit(root,22544);emit(s_bank,38986);raw_task(task);emit(task,36);emit(s_text,text_length);
}
static void scratch(void){memcpy(visible,s_seed,156);if(s_frame){memcpy(visible,(void*)(uintptr_t)s_frame,68);memcpy(visible+152,(void*)(uintptr_t)(s_frame+152),4);}emit(visible,156);emit(s_defined,156);}
void s_budget_abort(void){status=2;longjmp(env,1);}
void s_strlen_admit(uint32_t pointer){CHECK(pointer>=ptr(s_program)&&pointer<ptr(s_program)+length);CHECK(memchr((void*)(uintptr_t)pointer,0,length-(pointer-ptr(s_program)))!=0);}
static uint32_t output_size(uint32_t kind,uint32_t argc,uint32_t*a,uint8_t**local){
 *local=0;
 if(kind==331){if(a[2]){*local=(uint8_t*)(uintptr_t)a[2];return 48;}return 0;}
 if(kind==345||kind==346||kind==347||kind==349||kind==352||kind==360){*local=(uint8_t*)(uintptr_t)a[0];return 48;}
 if(kind==1344){*local=(uint8_t*)(uintptr_t)a[2];return 20;}
 if(kind==304||kind==305){*local=(uint8_t*)(uintptr_t)a[1];return 4;}
 return 0;
}
uint32_t s_observe(uint32_t kind){
 uint32_t argc=0;switch(kind){
 case31:argc=1;break;case37:argc=2;break;case52:argc=3;break;
 case342:case326:case359:argc=0;break;
 case331:argc=6;break;case314:argc=11;break;case40:argc=9;break;
 case101:case98:case664:case297:case290:argc=5;break;
 case953:case48:case236:case100:case304:case305:case1344:argc=3;break;
 case99:case104:case332:case665:case666:case668:case942:case926:case702:case291:argc=2;break;
 default:argc=1;break;}
 uint32_t raw[11],a[11]={0};memcpy(raw,s_args,44);memcpy(a,raw,44);uint8_t*local=0;uint32_t local_size=output_size(kind,argc,raw,&local),input_size=local_size;uint8_t known[65536];uint8_t*input_bytes=local;
 if(local_size){CHECK((uintptr_t)local>=s_frame&&(uintptr_t)local+local_size<=s_frame+156);memcpy(known,s_defined+(uintptr_t)local-s_frame,local_size);}
 if(kind==31||kind==37||kind==52){CHECK(raw[0]==ptr(&s_ip)&&raw[1]==ptr(s_task));a[0]=slot;if(kind==37)a[1]=raw[2];if(kind==52){a[1]=raw[2];a[2]=raw[3];}}
 if(kind==331)a[2]=raw[2]?0:0xffffffffu;
 if(kind==345||kind==346||kind==347||kind==349||kind==352||kind==360)a[0]=0;
 if(kind==304||kind==305){a[0]&=255;a[1]=0;}
 if(kind==664)a[2]&=255;
 if(kind==236)a[2]=body_raw(a[2]);
 if(kind==953||kind==942||kind==702||kind==291)a[0]=body_raw(a[0]);
 if(kind==926)a[1]=body_raw(a[1]);
 if(kind==101){CHECK(raw[0]>=ptr(s_program)&&raw[0]<ptr(s_program)+length);a[0]=base+raw[0]-ptr(s_program);input_bytes=(uint8_t*)(uintptr_t)raw[0];uint8_t*last=memchr(input_bytes,0,length-(raw[0]-ptr(s_program)));CHECK(last!=0);input_size=(uint32_t)(last-input_bytes)+1;memset(known,1,input_size);}
 if(kind==314){static uint8_t empty[2]={0};a[9]=0x49aa16;input_bytes=empty;input_size=2;memset(known,1,2);}
 uint32_t destination=0;
 if(kind==1344){destination=raw[0];if(destination>=ptr(s_text)&&destination<=ptr(s_text)+text_length){a[0]=0;a[1]=destination-ptr(s_text);}else{CHECK(destination>=ptr(s_bank)&&destination<ptr(s_bank)+38986);a[0]=1;a[1]=destination-ptr(s_bank);}a[2]=raw[1];}
 for(uint32_t i=argc;i<11;i++)a[i]=0;
 uint32_t row=outpos;emit32(kind);emit32(argc);emit(a,44);emit32(0);emit32(input_size);emit32(0);capture();emit(input_bytes,input_size);emit(known,input_size);
 if(used>=script_count){capture();used++;status=1;longjmp(env,1);}
 uint32_t wanted=read32(),count=read32(),values[11];bytes(values,44);uint32_t result=read32(),patches=read32(),outsize=read32();CHECK(wanted==kind&&count==argc&&!memcmp(values,a,argc*4)&&patches<=64&&outsize<=local_size&&(outsize==0||outsize==local_size));
 for(uint32_t i=0;i<patches;i++){uint32_t owner=read32(),at=read32(),size=read32();uint8_t data[64];bytes(data,64);CHECK(size<=64);uint8_t*dst=0;uint32_t extent=0;if(owner==0){dst=s_root;extent=16384;}else if(owner==1){dst=s_root+16384;extent=6160;}else if(owner==2){dst=s_bank;extent=38986;}else if(owner==3){dst=s_task;extent=36;}else if(owner==4){dst=s_text;extent=text_length;}else{CHECK(owner==5||owner==6);extent=4;dst=owner==5?(uint8_t*)&s_ip:(uint8_t*)&s_text_pointer;}CHECK(at+size<=extent);
  if(owner==0||owner==1){uint8_t normalized[22544];memcpy(normalized,s_root,22544);put(normalized+0xc8,body_raw(get(normalized+0xc8)));put(normalized+0xcc,body_raw(get(normalized+0xcc)));uint32_t bank=get(normalized+0x580c);CHECK(bank==0||bank==ptr(s_bank));put(normalized+0x580c,bank!=0);memcpy(normalized+(owner==1?16384:0)+at,data,size);memcpy(s_root,normalized,22544);import_root();}
  else if(owner==3){uint8_t task[36];raw_task(task);memcpy(task+at,data,size);memcpy(s_task,task,36);import_task();}
  else if(owner==5||owner==6){uint32_t logical=owner==5?s_ip-ptr(s_program):s_text_pointer-ptr(s_text);memcpy((uint8_t*)&logical+at,data,size);CHECK(logical<=(owner==5?length:text_length));if(owner==5){CHECK(kind==31||kind==37||kind==52);s_ip=ptr(s_program)+logical;}else s_text_pointer=ptr(s_text)+logical;}
  else memcpy(dst+at,data,size);
 }
 if(outsize){bytes(local,outsize);bytes(s_defined+(uintptr_t)local-s_frame,outsize);for(uint32_t i=0;i<outsize;i++)CHECK(s_defined[(uintptr_t)local-s_frame+i]<=1);}
 uint32_t returned=0;switch(kind){case31:case52:case101:case314:case1344:case772:case664:case665:case666:case668:case297:case40:case926:case291:returned=result;break;default:CHECK(result==0);break;}
 put(output+row+52,returned);put(output+row+60,outsize);capture();if(outsize){emit(local,outsize);emit(s_defined+(uintptr_t)local-s_frame,outsize);}used++;
 if(kind==1344){CHECK(result<=(a[0]==0?text_length+1:38986));return(a[0]==0?ptr(s_text):ptr(s_bank))+result;}
 if(kind==772||kind==664||kind==665||kind==666||kind==668||kind==297||kind==40||kind==926||kind==291)return body_host(result);
 return result;
}
int main(void){uint32_t size;while(fread(&size,4,1,stdin)==1){CHECK(size<=sizeof input&&fread(input,1,size,stdin)==size);cursor=input;end=input+size;base=read32();length=read32();text_length=read32();uint32_t ip=read32(),textcursor=read32();slot=read32();script_count=read32();CHECK(length>0&&length<=65536&&text_length>0&&text_length<=65536&&ip<=length&&textcursor<=text_length&&slot<150&&script_count<=256);bytes(s_root,22544);bytes(s_bank,38986);bytes(s_task,36);bytes(s_program,length);bytes(s_vectors,324);bytes(s_text,text_length);bytes(s_seed,156);bytes(s_defined,156);for(uint32_t i=0;i<156;i++)CHECK(s_defined[i]<=1);import_root();import_task();s_ip=ptr(s_program)+ip;s_text_pointer=ptr(s_text)+textcursor;
 g_root.a=g_root.b=g_bank.a=g_bank.b=g_task.a=g_task.b=g_program.a=g_program.b=g_vectors.a=g_vectors.b=g_text.a=g_text.b=GUARD;uint8_t oldprogram[65536],oldvectors[324];memcpy(oldprogram,s_program,length);memcpy(oldvectors,s_vectors,324);s_trace_count=s_steps=s_frame=used=status=0;memset(s_opcodes,0,sizeof s_opcodes);outpos=40;if(!setjmp(env)){call_kernel();CHECK(used==script_count&&cursor==end);}CHECK(g_root.a==GUARD&&g_root.b==GUARD&&g_bank.a==GUARD&&g_bank.b==GUARD&&g_task.a==GUARD&&g_task.b==GUARD&&g_program.a==GUARD&&g_program.b==GUARD&&g_vectors.a==GUARD&&g_vectors.b==GUARD&&g_text.a==GUARD&&g_text.b==GUARD&&!memcmp(oldprogram,s_program,length)&&!memcmp(oldvectors,s_vectors,324));uint32_t final=outpos;capture();scratch();uint32_t traceat=outpos;emit(s_trace,s_trace_count*4);emit(s_opcodes,sizeof s_opcodes);put(output,0x41ab3257);put(output+4,outpos);put(output+8,status);put(output+12,0);put(output+16,used);put(output+20,final);put(output+24,traceat);put(output+28,s_trace_count);put(output+32,s_steps);put(output+36,0);CHECK(fwrite(output,1,outpos,stdout)==outpos);
 }return 0;}
'''
HOST_C=re.sub(r'\bcase(\d+)',r'case \1',HOST_C)
if __name__=='__main__':main()
