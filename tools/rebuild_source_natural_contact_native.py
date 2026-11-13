#!/usr/bin/env python3
"""Direct original F576 player/natural classifier, with actual native F1876.

The source x86 instructions are compared against uploaded DOS before adapting
stack slots and pointers for a low-address x86_64 research harness. This is not
an Android emulator. F580/F583, city streams and render paths are explicit traps.
No expected contact or height arithmetic is calculated in Python.
"""
from __future__ import annotations
import argparse,hashlib,importlib.util,json,random,re,struct,subprocess,sys,tempfile
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
COMMIT='7e540341d4e09aa3c92877b87d49e7f2c143ad8d'
INPUT=800;OUTPUT=1024;GUARD=0x4e41545552414c32
GLOBAL_FIELDS=[('collision_flags_u8',8696,1),('volume_flags_u8',8697,1),('collider_index_u8',8698,1),('collision_active_u8',8699,1),('collision_enabled_u8',8700,1),('primitive_flags_u8',8701,1),('altitude_low_u32',8703,4),('altitude_high_s32',8704,4),('previous_altitude_low_u32',8705,4),('previous_altitude_high_s32',8706,4),('collision_kind_u8',8707,1)]
EXTRA=[576,579,581,582,1334,1341,1466,1495,1502,1523,1533,1538,1657,1658,1660,1669,1670]

def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
C=load('natural_surface_proof',PROJECT/'tools/rebuild_source_surface_contact_native.py');G=C.G
sys.path.insert(0,str(PROJECT/'recovered-history/ground_harness/tools'))
import build_terrain_query_reference as Q

def sha(raw):return hashlib.sha256(raw).hexdigest()
def canonical(rows):
 # GAS may choose the equivalent moffs encoding for EAX absolute MOV. EAX fixes
 # operand width; disassembler's redundant DWORD PTR on ds: is syntax only.
 return [s.replace('dwordptrds:','ds:') for s in C.J.canonical(rows)]

def proof(source,data,exe,exe_path,numbers):
 """Resolve actual calls/data operands, then independently reassemble all bodies."""
 image=G.Image(exe);bodies={n:re.sub(r'SECTION \.data.*?SECTION \.text','',G.block(source,n),flags=re.S)for n in numbers}
 syms=set(re.findall(r'\b(?:DATA_\d+|FUNC_\d+)(?:_[A-Za-z0-9_]+)?','\n'.join(bodies.values())))
 syms.update(['_abs','_SetJmp','_LongJmp','_memcpy'])
 syms={re.sub(r'(FUNC_\d{6})_[A-Za-z0-9_]+',r'\1',s)for s in syms}
 aliases={s:0x71000000+i*0x1000 for i,s in enumerate(sorted(syms))};fakes=dict(aliases);addresses={};known=set();records={};disassembly={}
 def bind(sym,value):
  if sym in known and aliases[sym]!=value:raise ValueError('Inconsistent original binding '+sym)
  aliases[sym]=value;known.add(sym)
  if sym.startswith('FUNC_'):addresses[int(sym[5:])]=value
 bind('FUNC_000576',0x427e78)
 # Original callback words are verified as addresses, in addition to the old
 # terrain harness's byte-for-byte non-pointer-resource verification.
 region=data[data.index('DATA_007835:'):data.index('DATA_007895:')]
 signature=Q.byte_block(Q.data_block(data,7835));cursor=exe.find(signature)
 if cursor<0 or exe.find(signature,cursor+1)>=0:raise ValueError('Terrain table anchor is ambiguous')
 callback_words=[]
 for line in region.splitlines():
  line=line.split(';')[0].strip()
  if line.startswith('DATA_'):bind(line[:-1],0x416400+cursor)
  elif line.startswith('db '):cursor+=len(line[3:].split(','))
  elif line.startswith('dd '):
   for word in line[3:].split(','):
    value=struct.unpack_from('<I',exe,cursor)[0];symbol=re.sub(r'(FUNC_\d+)_\w+',r'\1',word.strip())
    if symbol.startswith(('FUNC_','DATA_')):bind(symbol,value);callback_words.append({'file_offset':cursor,'symbol':symbol,'address':value})
    cursor+=4
 while len(records)<len(numbers):
  n=next((n for n in numbers if str(n) not in records and n in addresses),None);anchor=None
  if n is None:
   n=next(n for n in numbers if str(n) not in records)
   pos=lambda k:int(re.search(r'; Pos = ([0-9a-f]+)',bodies[k])[1],16)
   anchor=min(map(int,records),key=lambda k:abs(pos(k)-pos(n)))
   bind('FUNC_%06d'%n,addresses[anchor]+pos(n)-pos(anchor))
  name='FUNC_%06d'%n;body=bodies[n];address=addresses[n]
  compiled=C.J.instructions(C.compile32(body,aliases,name,address));original=C.original_rows(exe_path,address,count=len(compiled))
  if len(original)!=len(compiled):raise ValueError('Original function boundary changed '+str(n))
  for cr,orr in zip(compiled,original):
   cn=re.findall('0x[0-9a-f]+',cr[2]);on=re.findall('0x[0-9a-f]+',orr[2])
   if len(cn)!=len(on):continue
   for cv,ov in zip(map(lambda s:int(s,16),cn),map(lambda s:int(s,16),on)):
    for sym,fv in fakes.items():
     if sym not in known and -256<=cv-fv<256:bind(sym,ov-(cv-fv));break
  source_calls=[]
  for line in body.splitlines():
   match=re.match(r'\s*call(?: near)?\s+(\[DATA_\d+\]|FUNC_\d+(?:_[A-Za-z0-9_]+)?|_\w+)',line)
   if match:source_calls.append(re.sub(r'(FUNC_\d+)_\w+',r'\1',match[1].strip('[]')))
   elif re.match(r'\s*call\s+',line):source_calls.append(None)
  original_calls=[r for r in original if r[1]=='call']
  if len(source_calls)!=len(original_calls):raise ValueError('Original call count differs '+str(n))
  for sym,row in zip(source_calls,original_calls):
   if sym is None:continue
   value=int(re.search('0x([0-9a-f]+)',row[2])[1],16);bind(sym,value)
   if sym.startswith('DATA_'):
    try:target=struct.unpack_from('<I',exe,image.offset(value,4))[0]
    except ValueError:continue # Runtime callback pointer stored in BSS.
    for line in body.splitlines():
     if sym in line and 'call' in line:
      match=re.search(r';\s*FUNC_(\d+)',line)
      if match:bind('FUNC_%06d'%int(match[1]),target)
  compiled=C.J.instructions(C.compile32(body,aliases,name,address));a=canonical(original);b=canonical(compiled)
  if a!=b:raise ValueError('DOS/JJFFE mismatch F%d %s'%(n,[(i,x,y)for i,(x,y)in enumerate(zip(a,b))if x!=y][:8]))
  begin=image.offset(address,1);end=image.offset(original[-1][0],1)+len(bytes.fromhex('c3'))
  # Last instructions can be NOP/padding in the original function block. Use
  # the next original instruction address to capture the exact whole span.
  following=C.original_rows(exe_path,address,count=len(original)+1)
  if len(following)>len(original):end=image.offset(following[-1][0],1)
  records[str(n)]={'virtual_address':address,'executable_offset':begin,'byte_length':end-begin,'sha256':sha(exe[begin:end]),'instruction_count':len(original),'normalized_instruction_sha256':sha('\n'.join(a).encode()),'all_instructions_equal':True,'entry_anchor':'actual call/pointer target' if anchor is None else 'neighbor%d Pos delta, then full instruction comparison'%anchor}
  disassembly[str(n)]='\n'.join('%08x: %s %s'%r for r in original)+'\n'
 return bodies,records,disassembly,callback_words

def resources(exe):
 image=G.Image(exe);lines=['.section .data'];metadata={}
 children={24:'0000',38:'00007805903379059033',15:'0000840c803e'}
 for mid in [15,24,38,*range(117,149)]:
  at=image.pointer(0xba8fc+mid*4,68);raw=exe[at:at+68];fields=struct.unpack('<17I',raw)
  collision=image.offset(fields[13],1);vertices_at=image.offset(fields[1],24);vertices=exe[vertices_at:vertices_at+24]
  if mid>=117:
   before=exe[collision-2:collision]
   if before!=bytes(2)or exe[collision:collision+3]not in [bytes.fromhex('1082ff'),bytes.fromhex('1083ff')]:raise ValueError('Unsupported natural stream')
   end=collision+9
   while struct.unpack_from('<H',exe,end)[0]:
    end+=16
    if end>collision+4096:raise ValueError('Unbounded features')
   if exe[end+2:end+7]!=bytes.fromhex('5080000000'):raise ValueError('Unsupported natural tail')
   stream=exe[collision:end+7];physical=b''
  else:
   before=bytes.fromhex(children[mid])
   if exe[collision-len(before):collision]!=before:raise ValueError('Actual player child stream differs')
   stream=exe[collision:collision+64]
   spec=image.offset(fields[14],32);physical=exe[spec:spec+32]
  lines += [f'vertices_{mid}:','.byte '+','.join(map(str,vertices)),f'collision_before_{mid}:','.byte '+','.join(map(str,before)),f'collision_{mid}:','.byte '+','.join(map(str,stream))]
  if physical:lines += [f'physical_{mid}:','.byte '+','.join(map(str,physical))]
  lines += [f'descriptor_{mid}:']
  for index,value in enumerate(fields):
   replacement=f'vertices_{mid}' if index==1 else f'collision_{mid}' if index==13 else f'physical_{mid}' if index==14 and physical else str(value)
   lines.append('.long '+replacement)
  metadata[str(mid)]={'descriptor_offset':at,'descriptor_hex':raw.hex(),'descriptor_sha256':sha(raw),'collision_offset':collision,'preceding_children_hex':before.hex(),'collision_hex':stream.hex(),'collision_sha256':sha(stream),'vertices_offset':vertices_at,'vertices_hex':vertices.hex(),'vertices_sha256':sha(vertices),'physical_spec_hex':physical.hex(),'scope':'complete natural stream/features/tail' if mid>=117 else 'complete backwards F576 child list + bounded64-byte unused ship stream prefix'}
 lines.append('DATA_004681:')
 for mid in range(150):lines.append('.long '+(f'descriptor_{mid}' if str(mid)in metadata else '0'))
 return lines,metadata

def assembly(source,data,exe,model_lines):
 oldn=Q.NUMBERS;oldf=Q.WIDENED_FRAMES
 try:
  Q.NUMBERS=sorted(set(oldn+EXTRA));Q.WIDENED_FRAMES=oldf+[582,1495,1669,1670]
  text,terrain_resources=Q.adapt_assembly(source,data,exe)
 finally:Q.NUMBERS=oldn;Q.WIDENED_FRAMES=oldf
 start=text.index('_start:');end=text.index('.section .bss',start)
 text=text[:start]+WRAPPER+text[end:]
 text=text.replace('FUNC_000579:','OriginalF579:')
 text=text.replace('FUNC_001876:','FUNC_001876:\npushfq\ninc DWORD PTR [query_count_full]\npopfq')
 capture=['mov eax,DWORD PTR [DATA_009283]','mov DWORD PTR [output_full+60],eax','mov eax,DWORD PTR [DATA_009284]','mov DWORD PTR [output_full+764],eax'];initialize=['mov eax,DWORD PTR [input_full+52]','mov DWORD PTR [DATA_009283],eax','mov eax,DWORD PTR [input_full+56]','mov DWORD PTR [DATA_009284],eax']
 for index,(_,number,size)in enumerate(GLOBAL_FIELDS):
  src='BYTE PTR'if size==1 else'DWORD PTR'
  initialize+=['mov eax,DWORD PTR [input_full+%d]'%(8+index*4),'mov %s [DATA_%06d],%s'%(src,number,'al'if size==1 else'eax')]
  capture+=['movzx eax,BYTE PTR [DATA_%06d]'%number if size==1 else'mov eax,DWORD PTR [DATA_%06d]'%number,'mov DWORD PTR [output_full+%d],eax'%(16+index*4)]
 text=text.replace('@INITIALIZE_GLOBALS@','\n'.join(initialize)).replace('@CAPTURE_GLOBALS@','\n'.join(capture))
 # These exact original constants are consumed by F1533 initial fixture setup.
 drive=Q.byte_block(Q.data_block(data,7210))
 if exe.find(drive)<0:raise ValueError('Original hyperdrive resource missing')
 text+='\n.section .text\n'+TRACE_F579+'\n.section .data\nDATA_007754: .long FUNC_001532\nDATA_007756: .long FUNC_001538\nDATA_007734: .long FUNC_001495\nDATA_007738: .long FUNC_001502\nDATA_007210: .byte '+','.join(map(str,drive))+'\n'+'\n'.join(model_lines)+'\nDATA_008804: .long 0\nDATA_008807: .long 0\n'
 text+='''\n.section .bss
.balign 16
input_full: .zero 800
output_guard_before: .zero 8
output_full: .zero 1024
output_guard_after: .zero 8
player_guard_before: .zero 8
player: .zero 338
player_guard_after: .zero 8
parent_guard_before: .zero 8
parent: .zero 338
parent_guard_after: .zero 8
relative_guard_before: .zero 8
relative: .zero 24
relative_guard_after: .zero 8
query_count_full: .zero 4
volume_count: .zero 4
'''
 return text,terrain_resources

WRAPPER=r'''_start:
 mov esp,OFFSET FLAT:stack_end
 cld
next_full:
 xor r8d,r8d
read_full:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:input_full
 add rsi,r8
 mov edx,800
 sub edx,r8d
 syscall
 test eax,eax
 jle finish_full
 add r8d,eax
 cmp r8d,800
 jne read_full
 mov rax,0x4e41545552414c32
 mov QWORD PTR [output_guard_before],rax
 mov QWORD PTR [output_guard_after],rax
 mov QWORD PTR [player_guard_before],rax
 mov QWORD PTR [player_guard_after],rax
 mov QWORD PTR [parent_guard_before],rax
 mov QWORD PTR [parent_guard_after],rax
 mov QWORD PTR [relative_guard_before],rax
 mov QWORD PTR [relative_guard_after],rax
 mov esi,OFFSET FLAT:input_full+64
 mov edi,OFFSET FLAT:player
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:parent
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:relative
 mov ecx,24
 rep movsb
 mov edi,OFFSET FLAT:output_full
 xor eax,eax
 mov ecx,256
 rep stosd
 mov DWORD PTR [query_count_full],0
 mov DWORD PTR [volume_count],0
 mov DWORD PTR [DATA_008702],0
@INITIALIZE_GLOBALS@
 mov eax,DWORD PTR [input_full+4]
 mov DWORD PTR [DATA_008812],eax
 test DWORD PTR [input_full],1
 jz classify_full
 mov eax,DWORD PTR [player+0x82]
 push rax
 push OFFSET FLAT:player
 push OFFSET FLAT:player
 call FUNC_001533
 add rsp,24
 mov eax,DWORD PTR [parent+0x82]
 push rax
 push OFFSET FLAT:parent
 push OFFSET FLAT:parent
 call FUNC_001533
 add rsp,24
 xor eax,eax
 jmp capture_full
classify_full:
 push OFFSET FLAT:relative
 push OFFSET FLAT:parent
 push OFFSET FLAT:player
 call FUNC_000576
 add rsp,24
capture_full:
 mov DWORD PTR [output_full],eax
 mov eax,DWORD PTR [query_count_full]
 mov DWORD PTR [output_full+4],eax
 mov eax,DWORD PTR [volume_count]
 mov DWORD PTR [output_full+8],eax
 mov eax,DWORD PTR [DATA_008702]
 cmp eax,OFFSET FLAT:parent
 sete al
 movzx eax,al
 mov DWORD PTR [output_full+12],eax
@CAPTURE_GLOBALS@
 mov esi,OFFSET FLAT:player
 mov edi,OFFSET FLAT:output_full+64
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:parent
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:relative
 mov ecx,24
 rep movsb
 mov rax,0x4e41545552414c32
 mov QWORD PTR [output_full+1008],rax
 mov QWORD PTR [output_full+1016],rax
 cmp QWORD PTR [output_guard_before],rax
 jne invalid_canary
 cmp QWORD PTR [output_guard_after],rax
 jne invalid_canary
 cmp QWORD PTR [player_guard_before],rax
 jne invalid_canary
 cmp QWORD PTR [player_guard_after],rax
 jne invalid_canary
 cmp QWORD PTR [parent_guard_before],rax
 jne invalid_canary
 cmp QWORD PTR [parent_guard_after],rax
 jne invalid_canary
 cmp QWORD PTR [relative_guard_before],rax
 jne invalid_canary
 cmp QWORD PTR [relative_guard_after],rax
 jne invalid_canary
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output_full
 mov edx,1024
 syscall
 jmp next_full
invalid_canary:
 mov eax,60
 mov edi,94
 syscall
finish_full:
 mov eax,60
 xor edi,edi
 syscall
'''
TRACE_F579=r'''FUNC_000579:
 push rbp
 mov rbp,rsp
 push rbx
 push rsi
 push rdi
 pushfq
 mov ebx,DWORD PTR [volume_count]
 cmp ebx,3
 jae invalid_trace
 shl ebx,6
 add ebx,OFFSET FLAT:output_full+768
 mov eax,DWORD PTR [rbp+48]
 mov DWORD PTR [rbx],eax
 mov esi,DWORD PTR [rbp+40]
 lea edi,[rbx+4]
 mov ecx,6
 rep movsd
 mov eax,DWORD PTR [query_count_full]
 mov DWORD PTR [rbx+56],eax
 popfq
 push QWORD PTR [rbp+48]
 push QWORD PTR [rbp+40]
 push QWORD PTR [rbp+32]
 push QWORD PTR [rbp+24]
 push QWORD PTR [rbp+16]
 call OriginalF579
 lea rsp,[rsp+40]
 pushfq
 push rax
 push rcx
 mov DWORD PTR [rbx+52],eax
 mov esi,DWORD PTR [rbp+40]
 lea edi,[rbx+28]
 mov ecx,6
 rep movsd
 mov eax,DWORD PTR [query_count_full]
 sub eax,DWORD PTR [rbx+56]
 mov DWORD PTR [rbx+56],eax
 inc DWORD PTR [volume_count]
 pop rcx
 pop rax
 popfq
 pop rdi
 pop rsi
 pop rbx
 pop rbp
 ret
invalid_trace:
 mov eax,60
 mov edi,95
 syscall
'''

def globals_for(index):
 result={name:(([0xa5,0x5a,77,1,1,0x6d,0x89abcdef,-0x1234567,0x76543210,-0x2345678,0x7e][i])if index%3 else 0)for i,(name,_,_)in enumerate(GLOBAL_FIELDS)}
 result.update(recorded_intersection_raw=0x12345678 if index%3 else 0,pending_query_flag=0x6543210 if index%3 else 0);return result

def packet(row,initialize=False):
 raw=bytearray(INPUT);struct.pack_into('<2I',raw,0,int(initialize),int(row['context']['graphics_level']))
 for index,(name,_,_)in enumerate(GLOBAL_FIELDS):struct.pack_into('<I',raw,8+index*4,int(row['context']['initial_globals'].get(name,0))&0xffffffff)
 struct.pack_into('<2i',raw,52,int(row['context']['initial_globals'].get('recorded_intersection_raw',0)),int(row['context']['initial_globals'].get('pending_query_flag',0)))
 raw[64:402]=bytes.fromhex(row['player_object_hex']);raw[402:740]=bytes.fromhex(row['parent_object_hex']);raw[740:764]=bytes.fromhex(row['relative_before_hex'])
 return bytes(raw)

def decode(raw):
 values=struct.unpack_from('<11i',raw,16);state={name:(value&0xffffffff if name.endswith('_u32')else value)for(name,_,_),value in zip(GLOBAL_FIELDS,values)}
 state['recorded_intersection_raw']=struct.unpack_from('<i',raw,60)[0];state['pending_query_flag']=struct.unpack_from('<i',raw,764)[0]
 state['collider_parent_selected']=bool(struct.unpack_from('<I',raw,12)[0]);traces=[]
 calls=struct.unpack_from('<I',raw,8)[0]
 for i in range(calls):
  at=768+i*64;traces.append({'threshold_s32':struct.unpack_from('<i',raw,at)[0],'relative_before_hex':raw[at+4:at+28].hex(),'relative_after_hex':raw[at+28:at+52].hex(),'f579_return_s32':struct.unpack_from('<i',raw,at+52)[0],'terrain_query_calls':struct.unpack_from('<I',raw,at+56)[0]})
 if struct.unpack_from('<2Q',raw,1008)!=(GUARD,GUARD):raise ValueError('Output canary changed')
 return {'f576_return_s32':struct.unpack_from('<i',raw)[0],'terrain_query_calls':struct.unpack_from('<I',raw,4)[0],'f579_calls':calls,'globals':state,'player_hex':raw[64:402].hex(),'parent_hex':raw[402:740].hex(),'relative_after_hex':raw[740:764].hex(),'volume_trace':traces}

def initial_rows():
 rows=[]
 for i,mid in enumerate([15,24,38,*range(117,149)]):
  obj=bytearray(338);struct.pack_into('<9i',obj,0,0x7fffffff,0,0,0,0x7fffffff,0,0,0,0x7fffffff);struct.pack_into('<I',obj,0x82,mid);obj[0x86]=9;struct.pack_into('<I',obj,0xa0,0x12345678)
  parent=bytearray(obj);struct.pack_into('<I',parent,0x82,mid if mid>=117 else 122)
  rows.append({'player_object_hex':obj.hex(),'parent_object_hex':parent.hex(),'relative_before_hex':bytes(24).hex(),'context':{'graphics_level':1,'initial_globals':globals_for(i)}})
 return rows

def controls(initialized):
 rows=[];index=0
 for model in range(117,149):
  parent_base=bytes.fromhex(initialized[model]);inner=struct.unpack_from('<q',parent_base,0x140)[0];outer=struct.unpack_from('<q',parent_base,0x138)[0]
  for ship in [24,38,15]:
   player_base=bytes.fromhex(initialized[ship]);radius=struct.unpack_from('<i',player_base,0x140)[0]
   # Raw source coordinates, no physical-SI interpretation. Boundary positions
   # are input selection only; all expected classification/height is native.
   for kind,distance in [('center',0),('inner_minus',inner+radius-1),('inner_equal',inner+radius),('inner_plus',inner+radius+1),('shell_mid',(inner+outer)//2),('outer_minus',outer+radius-1),('outer_equal',outer+radius),('outer_plus',outer+radius+1),('far',outer*2)]:
    player=bytearray(player_base);parent=bytearray(parent_base)
    player[0x56]=parent[0x86];player[0x57]=1 if kind in ['inner_equal','outer_equal']else 0
    # Preserve realistic exact initialized model bounds. Sign/cyclic axes
    # exercise F1670 and positive/negative planet-frame orientations.
    axis=index%3;vector=[0,0,0];vector[axis]=distance*(-1 if index%2 else 1)
    if kind=='shell_mid':vector=[distance//3,distance//4,distance]
    row={'name':f'natural{model}/ship{ship}/{kind}/axis{axis}','parent_model':model,'player_model':ship,'selection':kind,'player_object_hex':player.hex(),'parent_object_hex':parent.hex(),'relative_before_hex':struct.pack('<3q',*vector).hex(),'context':{'graphics_level':1,'initial_globals':globals_for(index)}}
    rows.append(row);index+=1
 # Literal sign/high-word/same-frame and matrix variations retain actual radii.
 rng=random.Random(0x576581)
 for model in [117,118,122,128,133,134,140,148]:
  for ship in [24,38,15]:
   for variant in range(4):
    player=bytearray.fromhex(initialized[ship]);parent=bytearray.fromhex(initialized[model]);outer=struct.unpack_from('<q',parent,0x138)[0]
    if variant==1:struct.pack_into('<9i',parent,0,0,0,-0x7fffffff,0,0x7fffffff,0,0x7fffffff,0,0)
    if variant==2:struct.pack_into('<9i',player,0,-0x7fffffff,0,0,0,-0x7fffffff,0,0,0,0x7fffffff)
    if variant==3:player[0x57]=1;player[0x56]=parent[0x86]
    vector=[rng.randrange(-outer,outer+1)for _ in range(3)]
    rows.append({'name':f'natural{model}/ship{ship}/matrix_sentinel{variant}','parent_model':model,'player_model':ship,'selection':'matrix_sentinel','player_object_hex':player.hex(),'parent_object_hex':parent.hex(),'relative_before_hex':struct.pack('<3q',*vector).hex(),'context':{'graphics_level':1,'initial_globals':globals_for(index)}});index+=1
 # Exact unit-axis source distance around natural117's source-selected zero vertex.
 # Parent radii below are explicit raw-operand variants; player radius stays
 # the actual F1533 radius. These isolate source >= outer / <= inner gates.
 for ship in [24,38,15]:
  radius=struct.unpack_from('<i',bytes.fromhex(initialized[ship]),0x140)[0]
  for gate in ['outer','inner']:
   for delta in [-1,0,1]:
    player=bytearray.fromhex(initialized[ship]);parent=bytearray.fromhex(initialized[117]);player[0x57]=1;player[0x56]=parent[0x86]
    struct.pack_into('<q',parent,0x138,(1<<20)-radius+delta if gate=='outer'else 1<<21)
    struct.pack_into('<q',parent,0x140,(1<<20)-radius+delta if gate=='inner'else 0)
    rows.append({'name':f'natural117/ship{ship}/exact_{gate}_gate_delta{delta}','parent_model':117,'player_model':ship,'selection':'explicit_raw_parent_bounds_'+gate,'player_object_hex':player.hex(),'parent_object_hex':parent.hex(),'relative_before_hex':struct.pack('<3q',(1<<20),0,0).hex(),'context':{'graphics_level':1,'initial_globals':globals_for(index)}});index+=1
 # Target actual backwards child entries: Cobra negativeX then positiveX;
 # Shuttle positiveZ. Parentbounds are explicit source-operand test variants.
 for ship,sign,axis in [(38,1,0),(38,-1,0),(15,-1,2)]:
  player=bytearray.fromhex(initialized[ship]);parent=bytearray.fromhex(initialized[117]);radius=struct.unpack_from('<i',player,0x140)[0];player[0x57]=1;player[0x56]=parent[0x86]
  struct.pack_into('<q',parent,0x138,(1<<20)-radius);struct.pack_into('<q',parent,0x140,(1<<20)-(14000 if ship==38 else 2500))
  vector=[0,0,0];vector[axis]+=sign*(1<<20)
  rows.append({'name':f'natural117/ship{ship}/target_child_hit_{sign}_{axis}','parent_model':117,'player_model':ship,'selection':'explicit_raw_parent_bounds_child_hit','player_object_hex':player.hex(),'parent_object_hex':parent.hex(),'relative_before_hex':struct.pack('<3q',*vector).hex(),'context':{'graphics_level':1,'initial_globals':globals_for(index)}});index+=1
 for ship in [38,15]:
  player=bytearray.fromhex(initialized[ship]);parent=bytearray.fromhex(initialized[117]);player[0x14c]&=0x7f
  outer=struct.unpack_from('<q',parent,0x138)[0]
  rows.append({'name':f'natural117/ship{ship}/child_flag_cleared_outside','parent_model':117,'player_model':ship,'selection':'actual_children_disabled_by_body_flag','player_object_hex':player.hex(),'parent_object_hex':parent.hex(),'relative_before_hex':struct.pack('<3q',outer*2,0,0).hex(),'context':{'graphics_level':1,'initial_globals':globals_for(index)}});index+=1
 # Literal query-root input selected by original-native bisection, then
 # rerun independently. The positive real ship threshold>>16 is zero here;
 # native height -1/0/+3 exposes the strict terrain equality boundary.
 for ship in [24,38,15]:
  for delta in [-1,0,1]:
   player=bytearray.fromhex(initialized[ship]);parent=bytearray.fromhex(initialized[117]);player[0x57]=1;player[0x56]=parent[0x86]
   rows.append({'name':f'natural117/ship{ship}/native_query_zero_delta{delta}','parent_model':117,'player_model':ship,'selection':'original_native_selected_terrain_equality','player_object_hex':player.hex(),'parent_object_hex':parent.hex(),'relative_before_hex':struct.pack('<3q',0,192937978+delta,0).hex(),'context':{'graphics_level':1,'initial_globals':globals_for(index)}});index+=1
 # Fixed model120 Moon record-UID and exact input from the visual provider's
 # latitude/longitude point. The expected result is independently original DOS.
 player=bytearray.fromhex(initialized[38]);parent=bytearray.fromhex(initialized[120]);player[0x57]=1;player[0x56]=parent[0x86];struct.pack_into('<I',parent,0xa0,0x12340000)
 rows.append({'name':'natural120/ship38/visual_surface_raw_probe_9_6m','parent_model':120,'player_model':38,'selection':'visual_provider_mismatch_probe','input_provenance':{'runtime_record_hex':'007042000000341205000300780080592700aa6a8b48160000000000000000003600a003fd004d6f6f6e0000000000000000000000000000000000000000000000000000','raw_input_selection':'Visual globe height at current latitude/longitude plus9.6m, converted once to bodyfixed rawpoint; runtime rendering is not validated by this classifier oracle.'},'player_object_hex':player.hex(),'parent_object_hex':parent.hex(),'relative_before_hex':struct.pack('<3q',-1783203560,-3143996326,1350981885).hex(),'context':{'graphics_level':1,'initial_globals':globals_for(index)}})
 return rows

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));ap.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));ap.add_argument('--work',type=Path);args=ap.parse_args()
 raw_source=args.source.read_bytes();source=raw_source.decode().replace('\r\n','\n');data=args.source.with_name('ffedat.asm').read_text();exe=args.executable.read_bytes()
 if sha(raw_source)!=ASM_SHA or sha(exe)!=EXE_SHA:raise ValueError('Unsupported pinned original source/executable')
 work=args.work or Path(tempfile.mkdtemp(prefix='ffe-natural-native-'));work.mkdir(parents=True,exist_ok=True)
 numbers=sorted(set(Q.NUMBERS+EXTRA+[583]));_,proofs,disassembly,callback_words=proof(source,data,exe,args.executable,numbers)
 model_lines,model_metadata=resources(exe);text,terrain_metadata=assembly(source,data,exe,model_lines)
 (work/'natural.s').write_text(text);subprocess.run(['as','--64',str(work/'natural.s'),'-o',str(work/'natural.o')],check=True)
 undefined=subprocess.check_output(['nm','-u',str(work/'natural.o')],text=True);adapter,adapter_metadata=Q.unresolved_adapter(undefined,data)
 if exe[0x67038:0x67038+len(G.ABS_DOS)]!=G.ABS_DOS:raise ValueError('Original abs differs')
 adapter=adapter.replace('_abs:\nmov eax,60\nmov edi,97\nsyscall','''_abs:
push rbp
mov rbp,rsp
mov eax,DWORD PTR [rbp+16]
test eax,eax
jge source_abs_positive
mov edx,eax
neg edx
jmp source_abs_return
source_abs_positive:
mov edx,eax
source_abs_return:
mov eax,edx
pop rbp
ret''')
 trap_codes={}
 def trap(m):
  code=100+len(trap_codes);trap_codes[code]=m[1];return m[1]+':\nmov eax,60\nmov edi,'+str(code)+'\nsyscall'
 adapter_metadata['unreached_function_traps'].remove('_abs')
 adapter=re.sub(r'((?:FUNC_\d+|_[A-Za-z0-9_]+)):\nmov eax,60\nmov edi,97\nsyscall',trap,adapter)
 (work/'excluded.s').write_text(adapter);subprocess.run(['as','--64',str(work/'excluded.s'),'-o',str(work/'excluded.o')],check=True);subprocess.run(['ld','-m','elf_x86_64',str(work/'natural.o'),str(work/'excluded.o'),'-o',str(work/'natural')],check=True)
 def execute(rows,initialize=False,repeated=True):
  ordered=rows+list(reversed(rows))if repeated else rows;payload=b''.join(packet(r,initialize)for r in ordered);outputs=[]
  for _ in range(3 if repeated else 1):
   result=subprocess.run([str(work/'natural')],input=payload,capture_output=True,timeout=180)
   if result.returncode:raise RuntimeError('Native failed%d(%s) after%drecords; work%s'%(result.returncode,trap_codes.get(result.returncode,'native fault'),len(result.stdout)//OUTPUT,work))
   if len(result.stdout)!=len(ordered)*OUTPUT:raise ValueError('Incomplete native output')
   outputs.append(result.stdout)
  if any(o!=outputs[0]for o in outputs[1:]):raise ValueError('Fresh process mismatch')
  if repeated:
   for i in range(len(rows)):
    if outputs[0][i*OUTPUT:(i+1)*OUTPUT]!=outputs[0][(len(ordered)-1-i)*OUTPUT:(len(ordered)-i)*OUTPUT]:raise ValueError('Order/repeat mismatch '+rows[i].get('name',str(i)))
  return outputs[0]
 initial=initial_rows();initraw=execute(initial,True);initialized={}
 for i,mid in enumerate([15,24,38,*range(117,149)]):initialized[mid]=decode(initraw[i*OUTPUT:(i+1)*OUTPUT])['player_hex']
 for ship,value in [(24,5200),(38,9600),(15,1920)]:
  if struct.unpack_from('<q',bytes.fromhex(initialized[ship]),0x140)[0]!=value:raise ValueError('Actual player radius differs')
 rows=controls(initialized);output=execute(rows)
 for i,row in enumerate(rows):
  row['expected']=decode(output[i*OUTPUT:(i+1)*OUTPUT])
  if row['expected']['player_hex']!=row['player_object_hex']or row['expected']['parent_hex']!=row['parent_object_hex']or row['expected']['relative_after_hex']!=row['relative_before_hex']:raise ValueError('Classifier modified caller-owned buffers')
 interceptions=[]
 # Actual ship parent streams deliberately reach excluded general-VM commands.
 # These are process-abort controls, separate from supported natural cases and
 # separate again from pure-module input validation guards.
 for parent_mid,callee,status in [(15,'FUNC_000583',101),(24,'FUNC_000580',100)]:
  interception=dict(rows[0]);interception['parent_object_hex']=initialized[parent_mid]
  aborted=subprocess.run([str(work/'natural')],input=packet(interception),capture_output=True,timeout=10)
  if aborted.returncode!=status or aborted.stdout:raise ValueError('General VM branch did not abort explicitly '+callee)
  interceptions.append({'name':f'excluded_general_vm_parent{parent_mid}','parent_model':parent_mid,'player_object_hex':interception['player_object_hex'],'parent_object_hex':interception['parent_object_hex'],'relative_before_hex':interception['relative_before_hex'],'context':interception['context'],'expected_native_exit_status':status,'intercepted_original_callee':callee,'completed_output_records':0,'separate_from_supported_natural_cases':True})
 dependencies={str(path.relative_to(PROJECT)):sha(path.read_bytes()) for path in [PROJECT/'tools/rebuild_source_surface_contact_native.py',PROJECT/'tools/rebuild_ground_surface_native.py',PROJECT/'tools/rebuild_source_atmospheric_native.py',PROJECT/'recovered-history/ground_harness/tools/build_terrain_query_reference.py',PROJECT/'recovered-history/ground_harness/tools/native_reference.py']}
 report={'schema':1,'revision':'source-natural-contact-native-v1','source_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'source_data_assembly_sha256':sha(args.source.with_name('ffedat.asm').read_bytes()),'source_commit':COMMIT,'scope':'Direct full originalF576/F579, bounded natural117..148 F582 records1082/1083ff and5080000000tail, fullF581 with actualnativeF1876 and original integer terrain workers/resources. Positive initialized playerbounds and complete actual backwards child lists for Eagle24,Cobra38,Shuttle15. F580/F583/city/generalVM/render are explicit abort traps. Descriptor initialization is fixture input setup only. No F575 response, scanner, damage, city, full game or Android integration claim.','case_count':len(rows),'fresh_process_runs':3,'reverse_repeat_count':len(rows),'output_canaries_unchanged':True,'caller_buffers_unchanged':True,'native_expected_arithmetic_in_python':False,'byte_instruction_proofs':proofs,'source_procedure_hashes':{str(n):sha(G.block(source,n).encode())for n in numbers},'generator_dependency_sha256':dependencies,'unsupported_vm_interception_count':len(interceptions),'unsupported_vm_interceptions':interceptions,'dos_abs_bytes_proof':{'file_offset':0x67038,'hex':G.ABS_DOS.hex(),'sha256':sha(G.ABS_DOS),'native_clone_scope':'Exact uploaded DOS integer abs instructions under expanded stack-slot host ABI; INT_MIN wrap retained.'},'byteproof_normalizations':['branch destinations by instruction index','redundant DWORD PTR ds: omitted for EAX absolute MOV; moffs/modrm equivalent instructions'],'dos_jjffe_behavior_differences':[],'original_callback_pointer_words':callback_words,'original_model_resources':model_metadata,'original_terrain_resources':terrain_metadata,'host_adapter':adapter_metadata,'host_trap_codes':trap_codes,'host_adaptations':{'low_address_buffers_and_stack':True,'expanded_argument_slots':True,'two_pop_frames_widened':[582,1495,1669,1670,*Q.WIDENED_FRAMES],'observational_F579_wrapper_preserves_original_registers_and_flags':True,'SetJmp_initial_zero_only_LongJmp_aborts':True},'generator_sha256':sha(Path(__file__).read_bytes()),'native_assembly_sha256':sha(text.encode()),'native_adapter_sha256':sha(adapter.encode()),'native_ordered_output_sha256':sha(output),'cases':rows}
 destination=PROJECT/'tests/fixtures/source_natural_contact_native.json';destination.write_text(json.dumps(report,separators=(',',':'))+'\n')
 proofdir=PROJECT/'validation/natural-2026-11-13/nativeproof';proofdir.mkdir(parents=True,exist_ok=True)
 for n,body in disassembly.items():(proofdir/f'dos-F{n}.txt').write_text(body)
 (proofdir/'instruction-proofs.json').write_text(json.dumps({'byte_instruction_proofs':proofs,'source_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'dos_jjffe_behavior_differences':[],'callback_pointer_words':callback_words},indent=2)+'\n')
 (proofdir/'natural-native.s').write_text(text);(proofdir/'excluded-native.s').write_text(adapter)
 (proofdir/'summary.json').write_text(json.dumps({k:v for k,v in report.items()if k not in ['cases','original_model_resources','original_terrain_resources']},indent=2)+'\n')
 print('SOURCE NATURAL NATIVE:',len(rows),'cases;3fresh+reverse;DOSproofs',len(proofs),'querycases',sum(r['expected']['terrain_query_calls']>0 for r in rows),'childcases',sum(r['expected']['f579_calls']>1 for r in rows),'work',work)
if __name__=='__main__':main()
