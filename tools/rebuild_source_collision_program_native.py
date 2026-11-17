#!/usr/bin/env python3
"""Original DOS F582/F1822 program controls with real F583/F580 recursion.

F581 terrain height collection is a typed observed boundary. Python constructs
packets only; expected decisions and coordinates execute original instructions.
"""
from __future__ import annotations
import argparse,copy,hashlib,inspect,json,random,re,struct,subprocess,tempfile
from pathlib import Path
import rebuild_source_natural_contact_native as N
import rebuild_source_collision_planes_native as P
import rebuild_source_collision_transform_native as T
import rebuild_source_frame_dispatch_native as F
PROJECT=N.PROJECT;PROOF=PROJECT/'validation/collision-programs-2026-11-17/program-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_collision_program_native.json'
PROFILE='dos-firstenc-f582-collision-program-v1'
EXE_SHA=N.EXE_SHA;ASM_SHA=N.ASM_SHA
NUMBERS=[582,1822];FIELDS=F.FIELDS
BUF=1024;PROG=512;MODELS=8;SLOT=4096;MODELBASE=4096;SCRIPTBASE=MODELBASE+MODELS*SLOT
INPUT=SCRIPTBASE+1024;OUTPUT=5184
def sha(raw):return hashlib.sha256(raw).hexdigest()
def s32(v):return(v&0x7fffffff)-(v&0x80000000)
def reprove(a):
 raw=a.exe.read_bytes();source=a.asm.read_text();data=a.data.read_text()
 if sha(raw)!=EXE_SHA or sha(a.asm.read_bytes())!=ASM_SHA:raise ValueError('Original identity differs')
 method=inspect.getsource(N.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_000582',0x428bf4)")
 method=method.replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
 scope=N.__dict__.copy();exec(method,scope)
 bodies,records,dis,callbacks,aliases=scope['proof'](source,data,raw,a.exe,NUMBERS)
 text='\n'.join(bodies[n]for n in NUMBERS)+'\nFUNC_999999:\nret\n'
 meta={'schema':'starfrontier-original-collision-program-proof-v1','source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'source_procedures_sha256':sha(text.encode()),'bindings':aliases,'procedures':records,'all_whole_instructions_equal':True,'host_adaptations':['Reviewed ELF64 cdecl adapter preserving32bit program arithmetic and source four-byte pointers','F582 scratch allocation8→16 solely for its two host-width epilogue pops','F580 six original DWORD jump slots retained and loaded as low-address jump targets','MOV-only ESI/depth observation before F582 epilogue records stream cursor without changing return value','F581 matched boundary supplies local hit word, next program offset and explicit collision-global writes; no terrain geometry invented'],'scope':'Whole DOS F582 and F1822, real independently proved F583/F1656 and F580 recursive execution. Generic F581 terrain-height generation is explicit observed input. No live Main, full F576 front or Android claim.'}
 a.proof_dir.mkdir(parents=True,exist_ok=True);(a.proof_dir/'source-procedures.asm').write_text(text);(a.proof_dir/'instruction-proof.json').write_text(json.dumps(meta,indent=2)+'\n');(a.proof_dir/'dos-disassembly.txt').write_text('\n'.join(dis.values()))
 return meta,text
def verify(proof):
 meta=json.loads((proof/'instruction-proof.json').read_text());source=(proof/'source-procedures.asm').read_text()
 if meta['source_executable_sha256']!=EXE_SHA or meta['source_assembly_sha256']!=ASM_SHA or sha(source.encode())!=meta['source_procedures_sha256']:raise ValueError('Archived program identity differs')
 for n in NUMBERS:
  rec=meta['procedures'][str(n)];rows=N.C.J.instructions(N.C.compile32(N.C.J.block(source,n),meta['bindings'],'FUNC_%06d'%n,rec['virtual_address']))
  if len(rows)!=rec['instruction_count']or sha('\n'.join(N.canonical(rows)).encode())!=rec['normalized_instruction_sha256']:raise ValueError('Archived F%d instructions differ'%n)
 return meta,source
def trace(n):
 return f'pushfq\npush rax\npush rcx\nmov ecx,DWORD PTR [order_count]\ncmp ecx,128\njae failed\nmov DWORD PTR [order+rcx*4],{n}\ninc DWORD PTR [order_count]\npop rcx\npop rax\npopfq\n'
def capture(base,offset):
 lines=[]
 for i,(name,n,size)in enumerate(FIELDS):lines.extend([('movzx eax,BYTE PTR 'if size==1 else'mov eax,DWORD PTR ')+f'[DATA_{n:06d}]',f'mov DWORD PTR [{base}+{offset+i*4}],eax'])
 return '\n'.join(lines)
def assembly(source,plane_source,transform_source):
 source=source.replace('add esp,byte -0x8','add esp,-0x10',1)
 merged=source[:source.index('FUNC_999999:')]+plane_source[:plane_source.index('FUNC_999999:')]+transform_source+'\nFUNC_999999:\nret\n'
 merged=re.sub(r'(FUNC_\d{6})_[A-Za-z0-9_]+',r'\1',merged)
 adapter=N.C.load('program_host_abi',PROJECT/'recovered-history/ground_harness/tools/native_reference.py')
 lines,_=adapter.procedures(merged,[582,1822,583,1656,580]);text='\n'.join(lines)
 text=text.replace('jmp [eax*4+DATA_000028]','mov eax,DWORD PTR [eax*4+DATA_000028]\njmp rax')
 for n in [582,1822,583,580]:text=text.replace(f'FUNC_{n:06d}:',f'FUNC_{n:06d}:\n'+trace(n),1)
 marker='FUNC_000582:\n'+trace(582)+'\npush rbp\nmov rbp,rsp'
 if text.count(marker)!=1:raise ValueError('Unreviewed F582 entry')
 text=text.replace(marker,marker+'''\npushfq
push rax
push rdx
mov eax,DWORD PTR [depth]
cmp eax,16
jae failed
mov edx,DWORD PTR [rbp+32]
mov DWORD PTR [program_bases+rax*4],edx
inc DWORD PTR [depth]
pop rdx
pop rax
popfq''')
 marker='JUMP_002532:'
 if text.count(marker)!=1:raise ValueError('Unreviewed F582 epilogue')
 text=text.replace(marker,marker+'''\npushfq
push rax
push rdx
mov eax,DWORD PTR [depth]
dec eax
mov DWORD PTR [depth],eax
mov edx,esi
sub edx,DWORD PTR [program_bases+rax*4]
test eax,eax
jnz inner_cursor
mov DWORD PTR [cursor],edx
inner_cursor:
pop rdx
pop rax
popfq''')
 text+='\nFUNC_001538:\n'+trace(1538)+'''mov eax,DWORD PTR [rsp+8]
cmp eax,255
ja failed
mov eax,DWORD PTR [model_table+rax*4]
test eax,eax
jz failed
ret
_abs:
push rbp
mov rbp,rsp
mov eax,DWORD PTR [rbp+16]
test eax,eax
jge abs_nonnegative
mov edx,eax
neg edx
jmp abs_done
abs_nonnegative:
mov edx,eax
abs_done:
mov eax,edx
pop rbp
ret
'''
 text+='\n'+terrain_stub()+'\n'+wrapper()
 data='\n.section .data\nDATA_007756: .quad FUNC_001538\n.section .bss\n.balign16\ninput: .zero '+str(INPUT)+'\noutput: .zero '+str(OUTPUT)+'\norder_count: .zero4\norder: .zero512\ndepth: .zero4\nprogram_bases: .zero64\ncursor: .zero4\nobs_count: .zero4\nprimitive: .zero4\nreturned: .zero4\nactive_record: .zero8\nactive_script: .zero8\nmodel_table: .zero1024\n'
 for _,n,size in FIELDS:data+=f'DATA_{n:06d}: .zero {size}\n'
 data+='\n.balign16\nreadonly_begin:\nbody: .zero338\ncontext: .zero28\nprogram: .zero512\nnormals: .zero1024\nvertices: .zero1024\nmodels: .zero'+str(MODELS*SLOT)+'\nreadonly_end:\nreadonly_copy: .zero readonly_end-readonly_begin\n.balign16\nstack: .zero1048576\nstack_end:\n.section .note.GNU-stack,"",@progbits\n'
 data=re.sub(r'\.(zero|balign)(\d)',r'.\1 \2',data)
 return'.intel_syntax noprefix\n.code64\n.section .text\n.global _start\n'+text+data
def terrain_stub():
 text='FUNC_000581:\n'+trace(581)+'''push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov eax,DWORD PTR [obs_count]
cmp eax,8
jae failed
imul ecx,eax,80
add ecx,OFFSET FLAT:input+@SCRIPTBASE@
mov QWORD PTR [active_script],rcx
imul edx,eax,512
add edx,OFFSET FLAT:output+1024
mov QWORD PTR [active_record],rdx
mov eax,DWORD PTR [depth]
dec eax
mov ebx,DWORD PTR [program_bases+rax*4]
mov eax,DWORD PTR [rbp+24]
sub eax,ebx
mov DWORD PTR [rdx],eax
mov eax,DWORD PTR [rbp+40]
mov DWORD PTR [rdx+4],eax
mov eax,DWORD PTR [rcx]
mov DWORD PTR [rdx+8],eax
mov eax,DWORD PTR [rcx+4]
mov DWORD PTR [rdx+12],eax
mov DWORD PTR [rdx+16],ebx
mov esi,DWORD PTR [rbp+48]
lea edi,[rdx+20]
mov ecx,28
rep movsb
mov r8,QWORD PTR [active_record]
@CAPTURE_BEFORE@
mov r9,QWORD PTR [active_script]
'''
 for i,(_,n,size)in enumerate(FIELDS):text+=f'test DWORD PTR [r9+8],{1<<i}\njz terrain_write_done_{i}\nmov eax,DWORD PTR [r9+{16+i*4}]\nmov {"BYTE"if size==1 else"DWORD"} PTR [DATA_{n:06d}],'+('al'if size==1 else'eax')+f'\nterrain_write_done_{i}:\n'
 text+='''@CAPTURE_AFTER@
mov esi,DWORD PTR [rbp+32]
lea edi,[r8+144]
mov ecx,338
rep movsb
mov r9,QWORD PTR [active_script]
mov edx,DWORD PTR [rbp+16]
mov eax,DWORD PTR [r9]
mov DWORD PTR [rdx],eax
mov eax,ebx
add eax,DWORD PTR [r9+4]
inc DWORD PTR [obs_count]
pop rdi
pop rsi
pop rbx
pop rbp
ret
'''
 return text.replace('@SCRIPTBASE@',str(SCRIPTBASE)).replace('@CAPTURE_BEFORE@',capture('r8',48)).replace('@CAPTURE_AFTER@',capture('r8',96))
def wrapper():
 init=[]
 for i,(_,n,size)in enumerate(FIELDS):init.extend([f'mov eax,DWORD PTR [input+{16+i*4}]',f'mov {"BYTE"if size==1 else"DWORD"} PTR [DATA_{n:06d}],'+('al'if size==1 else'eax')])
 text=WRAPPER.replace('@INPUT@',str(INPUT)).replace('@MODELBASE@',str(MODELBASE)).replace('@CAPTURE_FINAL@',capture('output',64)).replace('@INITIALIZE@','\n'.join(init))
 return text
WRAPPER=r'''_start:
mov esp,OFFSET FLAT:stack_end
cld
next_case:
mov esp,OFFSET FLAT:stack_end
xor r8d,r8d
read_more:
xor eax,eax
xor edi,edi
lea rsi,[input+r8]
mov edx,@INPUT@
sub edx,r8d
syscall
test eax,eax
jle finished
add r8d,eax
cmp r8d,@INPUT@
jne read_more
mov edi,OFFSET FLAT:output
mov ecx,5184
mov al,0xa5
rep stosb
mov edi,OFFSET FLAT:model_table
mov ecx,1024
xor eax,eax
rep stosb
mov DWORD PTR [order_count],0
mov DWORD PTR [depth],0
mov DWORD PTR [obs_count],0
@INITIALIZE@
mov eax,DWORD PTR [input+4]
mov DWORD PTR [primitive],eax
mov esi,OFFSET FLAT:input+64
mov edi,OFFSET FLAT:body
mov ecx,338
rep movsb
mov esi,OFFSET FLAT:input+416
mov edi,OFFSET FLAT:context
mov ecx,12
rep movsb
mov eax,DWORD PTR [input+428]
mov DWORD PTR [context+20],eax
mov eax,DWORD PTR [input+432]
mov DWORD PTR [context+24],eax
mov eax,DWORD PTR [input+436]
add eax,OFFSET FLAT:normals
mov DWORD PTR [context+12],eax
mov eax,DWORD PTR [input+440]
add eax,OFFSET FLAT:vertices
mov DWORD PTR [context+16],eax
mov esi,OFFSET FLAT:input+512
mov edi,OFFSET FLAT:program
mov ecx,512
rep movsb
mov esi,OFFSET FLAT:input+1024
mov edi,OFFSET FLAT:normals
mov ecx,1024
rep movsb
mov esi,OFFSET FLAT:input+2048
mov edi,OFFSET FLAT:vertices
mov ecx,1024
rep movsb
mov esi,OFFSET FLAT:input+@MODELBASE@
mov edi,OFFSET FLAT:models
mov ecx,32768
rep movsb
xor ebx,ebx
model_loop:
cmp ebx,8
jae models_ready
mov eax,ebx
shl eax,12
add eax,OFFSET FLAT:models
cmp DWORD PTR [eax+4],0
je model_next
mov ecx,DWORD PTR [eax]
cmp ecx,255
ja failed
lea edx,[eax+8]
mov DWORD PTR [model_table+rcx*4],edx
lea edx,[eax+1664]
add edx,DWORD PTR [eax+80]
mov DWORD PTR [eax+12],edx
lea edx,[eax+640]
add edx,DWORD PTR [eax+76]
mov DWORD PTR [eax+20],edx
lea edx,[eax+128]
mov DWORD PTR [eax+60],edx
model_next:
inc ebx
jmp model_loop
models_ready:
mov esi,OFFSET FLAT:readonly_begin
mov edi,OFFSET FLAT:readonly_copy
mov ecx,readonly_end-readonly_begin
rep movsb
mov eax,DWORD PTR [input]
push rax
push OFFSET FLAT:body
push OFFSET FLAT:program
push OFFSET FLAT:context
push OFFSET FLAT:primitive
call FUNC_000582
add rsp,40
and eax,255
mov DWORD PTR [output+4],eax
mov eax,DWORD PTR [primitive]
and eax,255
mov DWORD PTR [output+8],eax
mov eax,DWORD PTR [cursor]
mov DWORD PTR [output+12],eax
mov eax,DWORD PTR [obs_count]
mov DWORD PTR [output+16],eax
mov eax,DWORD PTR [order_count]
mov DWORD PTR [output+20],eax
mov DWORD PTR [output],0x50524f47
mov DWORD PTR [output+24],0
mov DWORD PTR [output+28],0
mov DWORD PTR [output+32],OFFSET FLAT:program
mov DWORD PTR [output+36],OFFSET FLAT:normals
mov DWORD PTR [output+40],OFFSET FLAT:vertices
mov DWORD PTR [output+44],OFFSET FLAT:models
@CAPTURE_FINAL@
mov esi,OFFSET FLAT:body
mov edi,OFFSET FLAT:output+128
mov ecx,338
rep movsb
mov esi,OFFSET FLAT:order
mov edi,OFFSET FLAT:output+512
mov ecx,DWORD PTR [order_count]
shl ecx,2
rep movsb
mov esi,OFFSET FLAT:readonly_begin
mov edi,OFFSET FLAT:readonly_copy
mov ecx,readonly_end-readonly_begin
repe cmpsb
jne failed
xor r8d,r8d
write_more:
mov eax,1
mov edi,1
lea rsi,[output+r8]
mov edx,5184
sub edx,r8d
syscall
test eax,eax
jle failed
add r8d,eax
cmp r8d,5184
jb write_more
jmp next_case
failed:
mov eax,60
mov edi,91
syscall
finished:
mov eax,60
xor edi,edi
syscall
'''
def packet(row):
 raw=bytearray(INPUT);struct.pack_into('<4I',raw,0,row['threshold_s32']&0xffffffff,row.get('primitive_u8_before',0),0,0)
 for i,(name,_,_)in enumerate(FIELDS):struct.pack_into('<I',raw,16+i*4,row['globals_before'][name]&0xffffffff)
 raw[64:402]=bytes.fromhex(row['body_before_hex']);ctx=row['context']
 cells=[*ctx['point_xyz_s32'],ctx['mesh_zoom_s32'],ctx['vector_scale_s32'],ctx.get('normal_origin_u32',0),ctx.get('vertex_origin_u32',0)]
 struct.pack_into('<7I',raw,416,*[x&0xffffffff for x in cells])
 for at,field,count in [(512,'program_hex',PROG),(1024,'normals_hex',BUF),(2048,'vertices_hex',BUF)]:
  value=bytes.fromhex(row[field]if field=='program_hex'else ctx[field]);assert len(value)<=count;raw[at:at+len(value)]=value
 for slot,(mid,resource)in enumerate(sorted(row.get('resources',{}).items(),key=lambda a:int(a[0]))):
  if slot>=MODELS:raise ValueError('Too many native nested resources')
  at=MODELBASE+slot*SLOT;struct.pack_into('<2I',raw,at,int(mid),1);raw[at+8:at+76]=bytes.fromhex(resource['descriptor_hex'])
  struct.pack_into('<2I',raw,at+76,resource.get('normal_origin_u32',0),resource.get('vertex_origin_u32',0))
  for offset,field,count in [(128,'collision_program_hex',PROG),(640,'normals_hex',BUF),(1664,'vertices_hex',BUF)]:
   value=bytes.fromhex(resource[field]);assert len(value)<=count;raw[at+offset:at+offset+len(value)]=value
 for i,script in enumerate(row.get('terrain_scripts',[])):
  at=SCRIPTBASE+i*80;mask=0;values=[]
  for j,(name,_,_)in enumerate(FIELDS):
   if name in script.get('globals_after',{}):mask|=1<<j
   values.append(script.get('globals_after',{}).get(name,0)&0xffffffff)
  struct.pack_into('<16I',raw,at,script['return_s32']&0xffffffff,script['next_offset_u32'],mask,0,*values)
 return bytes(raw)
def globals_at(raw,at):
 return {name:s32(value)if name.endswith('_s32')else value for (name,_,_),value in zip(FIELDS,struct.unpack_from('<12I',raw,at))}
def decode(raw,row):
 h=struct.unpack_from('<12I',raw)
 if len(raw)!=OUTPUT or h[0]!=0x50524f47 or h[4]>8 or h[5]>128 or any(h[6:8])or raw[-64:]!=b'\xa5'*64:raise ValueError('Native program ABI/guard failure '+row['name'])
 if raw[128:466].hex()!=row['body_before_hex']:raise ValueError('Native changed body')
 observations=[]
 for index in range(h[4]):
  obs=raw[1024+index*512:1024+(index+1)*512];payload,threshold,returned,next_offset,base=struct.unpack_from('<5I',obs)
  point=list(struct.unpack_from('<3i',obs,20));normalptr,vertexptr,zoom,scale=struct.unpack_from('<4I',obs,32)
  if base==h[8]:program=row['program_hex'];normals=row['context']['normals_hex'];vertices=row['context']['vertices_hex'];normal_origin=normalptr-h[9];vertex_origin=vertexptr-h[10]
  else:
   slot=(base-h[11]-128)//SLOT;mid=sorted(row['resources'],key=int)[slot];resource=row['resources'][mid];program=resource['collision_program_hex'];normals=resource['normals_hex'];vertices=resource['vertices_hex'];normal_origin=normalptr-(h[11]+slot*SLOT+640);vertex_origin=vertexptr-(h[11]+slot*SLOT+1664)
  context={'point_xyz_s32':point,'normals_hex':normals,'vertices_hex':vertices,'mesh_zoom_s32':s32(zoom),'vector_scale_s32':s32(scale),'normal_origin_u32':normal_origin,'vertex_origin_u32':vertex_origin}
  before={'body_hex':obs[144:482].hex(),'program_hex':program,'context':context,'globals':globals_at(obs,48)}
  after=copy.deepcopy(before);after['globals']=globals_at(obs,96)
  observations.append({'kind':'F581','args':[payload,s32(threshold)],'before':before,'after':after,'return_s32':s32(returned),'next_offset_u32':next_offset})
 return{'return_s8':h[1]-256 if h[1]>=128 else h[1],'primitive_u8':h[2],'stream_cursor_u32':h[3],'globals_after':globals_at(raw,64),'body_after_hex':raw[128:466].hex(),'source_order':['F'+str(v)for v in struct.unpack_from('<%dI'%h[5],raw,512)],'observations':observations}
def base(rng,name):
 body=bytearray(rng.randbytes(338));body[0x86]=114
 state={name:(rng.randrange(256)if size==1 else rng.randrange(115)if name=='collider_ref_u32'else s32(rng.getrandbits(32))if name.endswith('_s32')else rng.getrandbits(32))for name,_,size in FIELDS}
 normals=bytearray(rng.randbytes(BUF));vertices=bytearray(rng.randbytes(BUF));normals[:6]=bytes(6)
 for code in range(128):normals[6+code*6]=code*2;normals[6+code*6+2:6+code*6+5]=bytes([1,0,0]);vertices[code*6+2:code*6+5]=bytes([0,0,0])
 return{'name':name,'body_before_hex':body.hex(),'program_hex':'00','context':{'point_xyz_s32':[0,0,0],'normals_hex':normals.hex(),'vertices_hex':vertices.hex(),'mesh_zoom_s32':0,'vector_scale_s32':0,'normal_origin_u32':6,'vertex_origin_u32':0},'threshold_s32':0,'globals_before':state,'primitive_u8_before':rng.randrange(256),'resources':{},'terrain_scripts':[]}
def build_rows():
 rng=random.Random(0x582B17);rows=[]
 # All three non-nested classes, both plane polarities, both volume bits.
 for i in range(192):
  r=base(rng,'planes/'+str(i));kind=[0x10,0x50,0xd0][i%3];volume=[0,1,0x7f,0x80,0xff][i%5];planes=[[],[2],[3],[2,3],[3,2],[2,4,6]][i%6]
  r['program_hex']=bytes([kind,volume,*planes,0,0]).hex();r['context']['point_xyz_s32']=[[0,0,0],[1,0,0],[-1,0,0],[0x7fffffff,0,0],[-0x80000000,0,0]][i%5];r['threshold_s32']=0 if kind==0xd0 and not volume&128 else [0,1,-1,0x7fffffff,-0x80000000][i%5];rows.append(r)
 # Conditional skip/inversion for every class including terrain payload stride.
 for i in range(96):
  r=base(rng,'equipment/'+str(i));kind=[0x30,0x70,0xb0,0xf0][i%4];equipment=i%16;condition=[0,1,15,31,128,129,143,159][i%8]
  body=bytearray.fromhex(r['body_before_hex']);struct.pack_into('<H',body,0x9c+equipment*2,[0,1,0xffff,0x8000][i%4]);r['body_before_hex']=body.hex()
  payload=[2,0]if kind&0xc0 in[0,0x40,0xc0]else[0,1,0,0]
  r['program_hex']=bytes([kind,0x80,equipment,condition,*payload,0]).hex()
  if kind==0xb0:
   descriptor=bytearray(68);r['resources']={'1':{'descriptor_hex':descriptor.hex(),'normals_hex':r['context']['normals_hex'],'vertices_hex':r['context']['vertices_hex'],'collision_program_hex':'d08000','normal_origin_u32':6,'vertex_origin_u32':0}}
  rows.append(r)
 # Real F580, all six permutations and all reflection bits, recursive F582.
 for i in range(64):
  r=base(rng,'nested/'+str(i));orientation=(i%6)|((i//6%8)<<3);model=17
  descriptor=bytearray(68);struct.pack_into('<ii',descriptor,0x14,[0,1,31,-1][i%4],0)
  resource={'descriptor_hex':descriptor.hex(),'normals_hex':r['context']['normals_hex'],'vertices_hex':r['context']['vertices_hex'],'collision_program_hex':bytes([0xd0,[0x80,0,0xff][i%3],2,0,0]).hex(),'normal_origin_u32':6,'vertex_origin_u32':0}
  r['resources']={str(model):resource};r['context']['point_xyz_s32']=[i*197-1000,100-i*23,-2*i];r['program_hex']=bytes([0x90,0x80,0,model,orientation,0,0]).hex();rows.append(r)
 # Actual F1822 conditional terrain skip plus observed real terrain-call seam.
 for i in range(48):
  r=base(rng,'terrain/'+str(i));body=bytearray.fromhex(r['body_before_hex']);struct.pack_into('<H',body,0x9c,1 if i%2 else 0);r['body_before_hex']=body.hex()
  prefix=[0x30,0x81,0,0,0xff]if i%2 else[0x10,0x81,0xff]
  features=bytes(16*(i%3))+bytes(2)
  # Nonzero feature starts force the original sixteen-byte skip stride.
  features=bytearray(features)
  for j in range(i%3):struct.pack_into('<H',features,j*16,j+1)
  payload=bytes(6)+features;program=bytes(prefix)+payload+bytes([0x50,0x80,0,0])
  r['program_hex']=program.hex();next_offset=len(prefix)+len(payload)
  if i%2==0:r['terrain_scripts']=[{'return_s32':[0,-1,1][i%3],'next_offset_u32':next_offset,'globals_after':{'collision_kind_u8':1,'altitude_low_u32':i*77}}]
  rows.append(r)
 # Nested F580 reaches the F581 seam with the actual transformed context.
 for i in range(16):
  r=base(rng,'nested-terrain/'+str(i));descriptor=bytearray(68);struct.pack_into('<ii',descriptor,0x14,i%4-1,0)
  program=bytes([0x10,0x81,0xff])+bytes(8)+bytes([0x50,0x80,0,0])
  r['resources']={'17':{'descriptor_hex':descriptor.hex(),'normals_hex':r['context']['normals_hex'],'vertices_hex':r['context']['vertices_hex'],'collision_program_hex':program.hex(),'normal_origin_u32':6,'vertex_origin_u32':0}}
  r['context']['point_xyz_s32']=[23*i-90,-7*i,19];r['program_hex']=bytes([0x90,0x80,0,17,i%6,0,0]).hex()
  r['terrain_scripts']=[{'return_s32':[0,-1,1][i%3],'next_offset_u32':11,'globals_after':{'collision_kind_u8':1,'altitude_low_u32':i*101}}];rows.append(r)
 # Synthetic C0 low-volume paths may read the byte following their first
 # terminator. Make these adjacent zero bytes explicit input, never implicit
 # native buffer padding; the checked runtime must not invent missing bytes.
 for row in rows:
  row['program_hex']+='0000'
  for resource in row['resources'].values():resource['collision_program_hex']+='0000'
 return rows
def generate(a):
 meta,source=verify(a.proof_dir);pm,ps=P.verify(P.PROOF);tm,ts=T.verify(T.PROOF);native=assembly(source,ps,ts);rows=build_rows()
 with tempfile.TemporaryDirectory(prefix='collision-program-native-')as directory:
  work=Path(directory);(work/'native.s').write_text(native)
  result=subprocess.run(['as','--64','-o',str(work/'native.o'),str(work/'native.s')],capture_output=True,text=True)
  if result.returncode:raise ValueError(result.stderr)
  result=subprocess.run(['ld','-o',str(work/'native'),str(work/'native.o')],capture_output=True,text=True)
  if result.returncode:raise ValueError(result.stderr)
  def run(items):
   result=subprocess.run([str(work/'native')],input=b''.join(packet(r)for r in items),capture_output=True,timeout=30)
   if result.returncode or result.stderr or len(result.stdout)!=OUTPUT*len(items):raise ValueError('Native program run failed code%d output%d/%d'%(result.returncode,len(result.stdout),OUTPUT*len(items)))
   return result.stdout
  previous=decode(run([rows[-1]]),rows[-1])
  for index in range(32):
   row=copy.deepcopy(rows[index%192]);row['name']='native-continuation/'+str(index)
   row['globals_before']=previous['globals_after'].copy();row['primitive_u8_before']=previous['primitive_u8'];row['body_before_hex']=previous['body_after_hex'];row['native_continuation_index']=index
   previous=decode(run([row]),row);rows.append(row)
  outputs=[run(rows)for _ in range(3)]
  if len(set(outputs))!=1:raise ValueError('Fresh native runs differ')
  reverse=run(list(reversed(rows)))
  if any(reverse[i*OUTPUT:(i+1)*OUTPUT]!=outputs[0][(len(rows)-i-1)*OUTPUT:(len(rows)-i)*OUTPUT]for i in range(len(rows))):raise ValueError('Reverse native order differs')
  for i,row in enumerate(rows):row['expected']=decode(outputs[0][i*OUTPUT:(i+1)*OUTPUT],row)
 dependencies=['tools/rebuild_source_collision_program_native.py','tools/rebuild_source_collision_planes_native.py','tools/rebuild_source_collision_transform_native.py','tools/rebuild_source_natural_contact_native.py','tools/rebuild_source_surface_contact_native.py','tools/rebuild_source_frame_dispatch_native.py','recovered-history/ground_harness/tools/native_reference.py','validation/collision-programs-2026-11-17/planes-native-proof/instruction-proof.json','validation/collision-programs-2026-11-17/planes-native-proof/source-procedures.asm','validation/collision-programs-2026-11-17/transform-native-proof/instruction-proof.json','validation/collision-programs-2026-11-17/transform-native-proof/source-procedures.asm']
 fixture={'schema':'starfrontier-source-collision-program-native-v1','profile':PROFILE,'case_count':len(rows),'consecutive_native_steps':32,'fresh_process_runs':3,'reverse_repeat_cases':len(rows),'expected_arithmetic_calculated_in_Python':False,'all_readonly_buffers_unchanged':True,'source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'instruction_proof_sha256':sha((a.proof_dir/'instruction-proof.json').read_bytes()),'host_assembly_sha256':sha(native.encode()),'native_output_sha256':sha(outputs[0]),'source_dependencies_sha256':{p:sha((PROJECT/p).read_bytes())for p in dependencies},'scope':meta['scope'],'cases':rows}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(fixture,indent=2)+'\n');(a.proof_dir/'program-native.s').write_text(native)
 print(json.dumps({'status':'native-replayed','case_count':len(rows),'output':str(a.output),'sha256':sha(a.output.read_bytes()),'bytes':a.output.stat().st_size},indent=2))
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--reprove-original',action='store_true');a=p.parse_args()
 if a.reprove_original or not(a.proof_dir/'instruction-proof.json').exists():reprove(a)
 generate(a)
if __name__=='__main__':main()
