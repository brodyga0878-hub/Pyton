#!/usr/bin/env python3
"""Whole DOS F581 with real F1876: native results, not Python geometry.

The reviewed ELF64 ABI adapter executes the captured original instruction
closure. Flat gates retain prior query words. Real queries use original
tables, maps, workers and feature records. Default replay is archive-only.
"""
from __future__ import annotations
import argparse,copy,hashlib,inspect,json,random,re,struct,subprocess,tempfile
from pathlib import Path
import rebuild_source_natural_contact_native as N
import rebuild_source_frame_dispatch_native as F

PROJECT=N.PROJECT
PROOF=PROJECT/'validation/terrain-height-2026-11-17/native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_collision_terrain_native.json'
PROFILE='dos-firstenc-collision-terrain-f581-v1'
NUMBERS=sorted(set(N.Q.NUMBERS+[581,1341,1466,1502,1523,1669]))
FIELDS=F.FIELDS
INPUT=4096;OUTPUT=4608;BUF=1024
BODYAT=128;PROGRAMAT=512;VERTEXAT=1536;NORMALAT=2560
OUT_BODY=128;OUT_PROGRAM=512;OUT_VERTICES=1536;OUT_NORMALS=2560;OUT_CONTEXT=3584;OUT_QUERY=3616
STATE_KEYS=['graphics_level_u32','recorded_intersection_raw_s32','pending_query_flag_u32']
ABS_HOST='''_abs:
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
ret'''

def sha(raw):return hashlib.sha256(raw).hexdigest()
def s32(value):return(value&0x7fffffff)-(value&0x80000000)
def globals_at(raw,at):
 values=struct.unpack_from('<12I',raw,at)
 return {name:s32(value)if name.endswith('_s32')else value for(name,_,_),value in zip(FIELDS,values)}

def reprove(a):
 raw=a.exe.read_bytes();source=a.asm.read_text();data=a.data.read_text()
 if sha(raw)!=N.EXE_SHA or sha(a.asm.read_bytes())!=N.ASM_SHA:raise ValueError('Original source identity differs')
 method=inspect.getsource(N.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_000581',0x4285ec)")
 method=method.replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
 namespace=N.__dict__.copy();exec(method,namespace)
 bodies,records,dis,callbacks,aliases=namespace['proof'](source,data,raw,a.exe,NUMBERS)
 selected='\n'.join(bodies[n]for n in NUMBERS)+'\nFUNC_999999:\nret\n'
 a.proof_dir.mkdir(parents=True,exist_ok=True)
 (a.proof_dir/'source-procedures.asm').write_text(selected)
 (a.proof_dir/'dos-disassembly.txt').write_text('\n'.join(dis.values()))
 old_numbers=N.Q.NUMBERS;old_frames=N.Q.WIDENED_FRAMES
 try:
  N.Q.NUMBERS=NUMBERS;N.Q.WIDENED_FRAMES=sorted(set(old_frames+[1669]))
  kernel,resources=N.Q.adapt_assembly(source,data,raw)
 finally:N.Q.NUMBERS=old_numbers;N.Q.WIDENED_FRAMES=old_frames
 start=kernel.index('_start:');end=kernel.index('.section .bss',start)
 kernel=kernel[:start]+wrapper()+kernel[end:]+bss()+'\n.section .data\nDATA_007738: .long FUNC_001502\n'
 marker='FUNC_001876:'
 if kernel.count(marker)!=1:raise ValueError('Changed F1876 entry')
 kernel=kernel.replace(marker,marker+'\n'+QUERY_TRACE)
 (a.proof_dir/'terrain-native.s').write_text(kernel)
 with tempfile.TemporaryDirectory(prefix='terrain-undefined-')as directory:
  path=Path(directory);(path/'kernel.s').write_text(kernel)
  subprocess.run(['as','--64','-o',str(path/'kernel.o'),str(path/'kernel.s')],check=True,capture_output=True)
  missing=subprocess.check_output(['nm','-u',str(path/'kernel.o')],text=True)
  adapter,adapter_meta=N.Q.unresolved_adapter(missing,data)
 if raw[0x67038:0x67038+len(N.G.ABS_DOS)]!=N.G.ABS_DOS:raise ValueError('Original abs differs')
 adapter=adapter.replace('_abs:\nmov eax,60\nmov edi,97\nsyscall',ABS_HOST)
 adapter_meta['unreached_function_traps'].remove('_abs')
 callback_address=aliases['DATA_007738'];callback_offset=N.G.Image(raw).offset(callback_address,4)
 callback_target=struct.unpack_from('<I',raw,callback_offset)[0]
 if callback_target!=aliases['FUNC_001502']:raise ValueError('Original F1466 callback differs')
 callbacks.append({'file_offset':callback_offset,'symbol':'FUNC_001502','address':callback_target,'pointer_symbol':'DATA_007738','pointer_virtual_address':callback_address})
 (a.proof_dir/'terrain-adapter.s').write_text(adapter)
 meta={'schema':'starfrontier-original-f581-terrain-instruction-proof-v1','source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'source_data_sha256':sha(a.data.read_bytes()),'procedures':records,'source_symbol_addresses':aliases,'source_procedures_sha256':sha(selected.encode()),'host_assembly_sha256':sha(kernel.encode()),'host_adapter_sha256':sha(adapter.encode()),'original_callback_words':callbacks,'original_terrain_resources':resources,'unresolved_adapter':adapter_meta,'all_whole_instructions_equal':True,'persistent_aliases':{'graphics_level_u32':{'symbol':'DATA_008812','virtual_address':0x64214c,'GameRoot_offset':0x10},'recorded_intersection_raw_s32':{'symbol':'DATA_009283','virtual_address':0x6c48e4},'pending_query_flag_u32':{'symbol':'DATA_009284','virtual_address':0x6c48e8}},'host_adaptations':['Original DOS procedures reassembled and all normalized instructions compared before host adaptation','Reviewed expanded cdecl argument slots and low-address stack/buffers retain source32bit arithmetic and four-byte data pointers','F1669 and original terrain worker two-pop scratch frames widened8→16 only for host-width epilogue pops','F1876 query arguments observed with saved registers/flags; query and terrain arithmetic execute real source bodies','Initial SetJmp returns0; LongJmp and unported render/helper paths are explicit abort traps','Vertex pool and raw terrain tables are private research allocations, not phone/game owners'],'scope':'Whole original F581 and real F1876 query/math/feature workers with original immutable tables/maps. Full input buffer and 12 collision words, two persistent query words and actual next-payload/hit outputs checked. No F582/F576/F575 orchestration, live Main, damage or physical Android claim.'}
 meta['dos_abs_bytes_proof']={'file_offset':0x67038,'hex':N.G.ABS_DOS.hex(),'sha256':sha(N.G.ABS_DOS),'native_clone_scope':'Exact original DOS abs instructions under expanded stack-slot ABI; INT_MIN wrap retained.'}
 meta['dos_disassembly_sha256']=sha((a.proof_dir/'dos-disassembly.txt').read_bytes())
 (a.proof_dir/'instruction-proof.json').write_text(json.dumps(meta,indent=2)+'\n')
 return meta,selected,kernel,adapter

def verify(proof=PROOF):
 meta=json.loads((proof/'instruction-proof.json').read_text());source=(proof/'source-procedures.asm').read_text();kernel=(proof/'terrain-native.s').read_text();adapter=(proof/'terrain-adapter.s').read_text()
 if meta['source_executable_sha256']!=N.EXE_SHA or meta['source_assembly_sha256']!=N.ASM_SHA or sha(source.encode())!=meta['source_procedures_sha256']or sha(kernel.encode())!=meta['host_assembly_sha256']or sha(adapter.encode())!=meta['host_adapter_sha256']:raise ValueError('Archived terrain identities differ')
 if sha((proof/'dos-disassembly.txt').read_bytes())!=meta['dos_disassembly_sha256']or meta['dos_abs_bytes_proof']['hex']!=N.G.ABS_DOS.hex()or meta['dos_abs_bytes_proof']['sha256']!=sha(N.G.ABS_DOS):raise ValueError('Archived DOS helper/disassembly differs')
 for n in NUMBERS:
  record=meta['procedures'][str(n)]
  rows=N.C.J.instructions(N.C.compile32(N.G.block(source,n),meta['source_symbol_addresses'],'FUNC_%06d'%n,record['virtual_address']))
  if len(rows)!=record['instruction_count']or sha('\n'.join(N.canonical(rows)).encode())!=record['normalized_instruction_sha256']:raise ValueError('Archived DOS instructions differ F%d'%n)
 return meta,source,kernel,adapter

def packet(row):
 raw=bytearray(b'\xa5'*INPUT);context=row['context'];state=row['terrain_state_before']
 program=bytes.fromhex(row['program_hex']);vertices=bytes.fromhex(context['vertices_hex']);normals=bytes.fromhex(context['normals_hex'])
 if max(len(program),len(vertices),len(normals))>BUF or len(bytes.fromhex(row['body_before_hex']))!=338:raise ValueError('Native transport capacity exceeded')
 struct.pack_into('<8I',raw,0,row['threshold_s32']&0xffffffff,row['offset_u32'],len(program),len(vertices),len(normals),state['graphics_level_u32'],state['recorded_intersection_raw_s32']&0xffffffff,state['pending_query_flag_u32'])
 for i,(name,_,_)in enumerate(FIELDS):struct.pack_into('<I',raw,32+i*4,row['globals_before'][name]&0xffffffff)
 struct.pack_into('<7I',raw,80,*[int(x)&0xffffffff for x in [*context['point_xyz_s32'],context['mesh_zoom_s32'],context['vector_scale_s32'],context.get('normal_origin_u32',0),context.get('vertex_origin_u32',0)]])
 raw[BODYAT:BODYAT+338]=bytes.fromhex(row['body_before_hex'])
 for at,value in [(PROGRAMAT,program),(VERTEXAT,vertices),(NORMALAT,normals)]:raw[at:at+len(value)]=value
 return bytes(raw)

def decode(raw,row):
 if len(raw)!=OUTPUT or struct.unpack_from('<I',raw)[0]!=0x54455252 or struct.unpack_from('<I',raw,84)[0]or raw[-64:]!=b'\xa5'*64:raise ValueError('Terrain ABI/input canary failed '+row['name'])
 hit,next_offset,count=struct.unpack_from('<3I',raw,4)
 if count>1 or next_offset>len(bytes.fromhex(row['program_hex'])):raise ValueError('Unexpected query count/program pointer')
 expected={'hit_s32':s32(hit),'next_offset_u32':next_offset,'query_count_u32':count,'body_after_hex':raw[OUT_BODY:OUT_BODY+338].hex(),'program_after_hex':raw[OUT_PROGRAM:OUT_PROGRAM+len(bytes.fromhex(row['program_hex']))].hex(),'globals_after':globals_at(raw,16),'terrain_state_after':dict(zip(STATE_KEYS,[struct.unpack_from('<I',raw,64)[0],s32(struct.unpack_from('<I',raw,68)[0]),struct.unpack_from('<I',raw,72)[0]])),'query_scratch_after':{'depth_control_s32':s32(struct.unpack_from('<I',raw,76)[0]),'vertex_pool_count_u32':struct.unpack_from('<I',raw,80)[0]},'source_order':['F581','F1876']if count else['F581','F1822']}
 context=copy.deepcopy(row['context']);cells=struct.unpack_from('<7I',raw,OUT_CONTEXT)
 context.update(point_xyz_s32=[s32(x)for x in cells[:3]],mesh_zoom_s32=s32(cells[3]),vector_scale_s32=s32(cells[4]),normal_origin_u32=cells[5],vertex_origin_u32=cells[6],vertices_hex=raw[OUT_VERTICES:OUT_VERTICES+len(bytes.fromhex(context['vertices_hex']))].hex(),normals_hex=raw[OUT_NORMALS:OUT_NORMALS+len(bytes.fromhex(context['normals_hex']))].hex())
 expected['context_after']=context
 if expected['body_after_hex']!=row['body_before_hex']or expected['program_after_hex']!=row['program_hex']or context!=row['context']:raise ValueError('F581 mutated a readonly owner')
 for at,value in [(OUT_PROGRAM,bytes.fromhex(row['program_hex'])),(OUT_VERTICES,bytes.fromhex(context['vertices_hex'])),(OUT_NORMALS,bytes.fromhex(context['normals_hex']))]:
  if raw[at:at+BUF]!=value+b'\xa5'*(BUF-len(value)):raise ValueError('F581 mutated unused input-buffer canary')
 if count:
  seed,style,limit=struct.unpack_from('<3I',raw,OUT_QUERY)
  expected['query_args']={'seed_u32':seed,'style_u32':style,'query_limit_s32':s32(limit),'matrix_s32':list(struct.unpack_from('<9i',raw,OUT_QUERY+12)),'center_s32':list(struct.unpack_from('<3i',raw,OUT_QUERY+48)),'features_offset_u32':struct.unpack_from('<I',raw,OUT_QUERY+60)[0]}
 return expected

QUERY_TRACE='''pushfq
push rax
push rcx
push rsi
push rdi
push r10
inc DWORD PTR [s_queries]
mov r10d,DWORD PTR [rsp+72]
mov eax,DWORD PTR [r10+0xa0]
mov DWORD PTR [s_output+3616],eax
mov eax,DWORD PTR [rsp+112]
mov DWORD PTR [s_output+3620],eax
mov eax,DWORD PTR [rsp+64]
mov DWORD PTR [s_output+3624],eax
mov esi,DWORD PTR [rsp+104]
mov edi,OFFSET FLAT:s_output+3628
mov ecx,36
rep movsb
mov esi,DWORD PTR [rsp+96]
mov edi,OFFSET FLAT:s_output+3664
mov ecx,12
rep movsb
mov eax,DWORD PTR [rsp+88]
sub eax,OFFSET FLAT:s_program
mov DWORD PTR [s_output+3676],eax
pop r10
pop rdi
pop rsi
pop rcx
pop rax
popfq
'''

def wrapper():
 init=[];capture=[]
 for i,(_,n,size)in enumerate(FIELDS):
  init+=['mov eax,DWORD PTR [s_input+%d]'%(32+i*4),'mov %s [DATA_%06d],%s'%('BYTE PTR'if size==1 else'DWORD PTR',n,'al'if size==1 else'eax')]
  capture+=[('movzx eax,BYTE PTR 'if size==1 else'mov eax,DWORD PTR ')+f'[DATA_{n:06d}]','mov DWORD PTR [s_output+%d],eax'%(16+i*4)]
 return WRAPPER.replace('@INIT@','\n'.join(init)).replace('@CAPTURE@','\n'.join(capture))

WRAPPER=r'''_start:
mov esp,OFFSET FLAT:stack_end
cld
s_next:
mov esp,OFFSET FLAT:stack_end
xor r8d,r8d
s_read:
xor eax,eax
xor edi,edi
mov esi,OFFSET FLAT:s_input
add rsi,r8
mov edx,4096
sub edx,r8d
syscall
test eax,eax
jle s_finished
add r8d,eax
cmp r8d,4096
jne s_read
mov edi,OFFSET FLAT:s_output
mov ecx,4608
mov al,0xa5
rep stosb
mov rax,0xa5a5a5a5a5a5a5a5
mov QWORD PTR [s_context_guard_a],rax
mov QWORD PTR [s_context_guard_b],rax
mov edi,OFFSET FLAT:s_body_guard_a
mov ecx,s_buffers_end-s_body_guard_a
mov al,0xa5
rep stosb
mov esi,OFFSET FLAT:s_input+128
mov edi,OFFSET FLAT:s_body
mov ecx,338
rep movsb
mov esi,OFFSET FLAT:s_input+512
mov edi,OFFSET FLAT:s_program
mov ecx,1024
rep movsb
mov esi,OFFSET FLAT:s_input+1536
mov edi,OFFSET FLAT:s_vertices
mov ecx,1024
rep movsb
mov esi,OFFSET FLAT:s_input+2560
mov edi,OFFSET FLAT:s_normals
mov ecx,1024
rep movsb
mov esi,OFFSET FLAT:s_input+80
mov edi,OFFSET FLAT:s_context
mov ecx,12
rep movsb
mov eax,DWORD PTR [s_input+92]
mov DWORD PTR [s_context+20],eax
mov eax,DWORD PTR [s_input+96]
mov DWORD PTR [s_context+24],eax
mov eax,DWORD PTR [s_input+100]
add eax,OFFSET FLAT:s_normals
mov DWORD PTR [s_context+12],eax
mov eax,DWORD PTR [s_input+104]
add eax,OFFSET FLAT:s_vertices
mov DWORD PTR [s_context+16],eax
mov eax,DWORD PTR [s_input+20]
mov DWORD PTR [DATA_008812],eax
mov eax,DWORD PTR [s_input+24]
mov DWORD PTR [DATA_009283],eax
mov eax,DWORD PTR [s_input+28]
mov DWORD PTR [DATA_009284],eax
mov DWORD PTR [DATA_009269],0xa5a5a5a5
mov DWORD PTR [DATA_009273],0xa5a5a5a5
mov DWORD PTR [s_queries],0
@INIT@
push OFFSET FLAT:s_context
mov eax,DWORD PTR [s_input]
push rax
push OFFSET FLAT:s_body
mov eax,DWORD PTR [s_input+4]
add eax,OFFSET FLAT:s_program
push rax
push OFFSET FLAT:s_hit
call FUNC_000581
add rsp,40
sub eax,OFFSET FLAT:s_program
mov DWORD PTR [s_output+8],eax
mov DWORD PTR [s_output],0x54455252
mov eax,DWORD PTR [s_hit]
mov DWORD PTR [s_output+4],eax
mov eax,DWORD PTR [s_queries]
mov DWORD PTR [s_output+12],eax
@CAPTURE@
mov eax,DWORD PTR [DATA_008812]
mov DWORD PTR [s_output+64],eax
mov eax,DWORD PTR [DATA_009283]
mov DWORD PTR [s_output+68],eax
mov eax,DWORD PTR [DATA_009284]
mov DWORD PTR [s_output+72],eax
mov eax,DWORD PTR [DATA_009269]
mov DWORD PTR [s_output+76],eax
mov eax,DWORD PTR [DATA_009273]
mov DWORD PTR [s_output+80],eax
mov DWORD PTR [s_output+84],0
mov esi,OFFSET FLAT:s_body
mov edi,OFFSET FLAT:s_output+128
mov ecx,338
rep movsb
mov esi,OFFSET FLAT:s_program
mov edi,OFFSET FLAT:s_output+512
mov ecx,1024
rep movsb
mov esi,OFFSET FLAT:s_vertices
mov edi,OFFSET FLAT:s_output+1536
mov ecx,1024
rep movsb
mov esi,OFFSET FLAT:s_normals
mov edi,OFFSET FLAT:s_output+2560
mov ecx,1024
rep movsb
mov esi,OFFSET FLAT:s_context
mov edi,OFFSET FLAT:s_output+3584
mov ecx,12
rep movsb
mov eax,DWORD PTR [s_context+20]
mov DWORD PTR [s_output+3596],eax
mov eax,DWORD PTR [s_context+24]
mov DWORD PTR [s_output+3600],eax
mov eax,DWORD PTR [s_context+12]
sub eax,OFFSET FLAT:s_normals
mov DWORD PTR [s_output+3604],eax
mov eax,DWORD PTR [s_context+16]
sub eax,OFFSET FLAT:s_vertices
mov DWORD PTR [s_output+3608],eax
mov rax,0xa5a5a5a5a5a5a5a5
cmp QWORD PTR [s_body_guard_a],rax
jne s_bad
cmp QWORD PTR [s_body_guard_b],rax
jne s_bad
cmp QWORD PTR [s_program_guard_a],rax
jne s_bad
cmp QWORD PTR [s_program_guard_b],rax
jne s_bad
cmp QWORD PTR [s_vertices_guard_a],rax
jne s_bad
cmp QWORD PTR [s_vertices_guard_b],rax
jne s_bad
cmp QWORD PTR [s_normals_guard_a],rax
jne s_bad
cmp QWORD PTR [s_normals_guard_b],rax
jne s_bad
cmp QWORD PTR [s_context_guard_a],rax
jne s_bad
cmp QWORD PTR [s_context_guard_b],rax
jne s_bad
mov eax,1
mov edi,1
mov esi,OFFSET FLAT:s_output
mov edx,4608
syscall
jmp s_next
s_bad:
mov eax,60
mov edi,93
syscall
s_finished:
mov eax,60
xor edi,edi
syscall
'''

def bss():
 text='\n.section .bss\n.balign 16\ns_input: .zero 4096\ns_output: .zero 4608\ns_context_guard_a: .zero 8\ns_context: .zero 28\ns_context_guard_b: .zero 8\ns_hit: .zero 4\ns_queries: .zero 4\n'
 for name,size in [('body',338),('program',1024),('vertices',1024),('normals',1024)]:text+=f's_{name}_guard_a: .zero 8\ns_{name}: .zero {size}\ns_{name}_guard_b: .zero 8\n'
 return text+'s_buffers_end:\n.section .note.GNU-stack,"",@progbits\n'

def build_rows():
 import rebuild_source_collision_geometry_native as G
 rng=random.Random(0x5811876);catalog=json.loads((PROJECT/'data/ffe_collision_programs.json').read_text());factory=json.loads((PROJECT/'tests/fixtures/source_object_factory_native.json').read_text())
 bodies={int(r['model_index_u32']):bytes.fromhex(r['expected_body_hex'])for r in factory['cases']if r['name'].startswith('real-model')and r['name'].endswith('-inplace')}
 rows=[];preparations=[];model_by_name={}
 identity=(0x7fffffff,0,0,0,0x7fffffff,0,0,0,0x7fffffff)
 for key,resource in catalog['models'].items():
  mid=int(key)
  if mid not in bodies:continue
  for rec in resource['program_records']:
   if rec.get('kind')!='terrain':continue
   outer=struct.unpack_from('<q',bodies[mid],0x138)[0];inner=struct.unpack_from('<q',bodies[mid],0x140)[0]
   # Authored raw poses, not expected geometry. F579 below executes native
   # arithmetic to prepare the exact F581 context for each supplied pose.
   positions=[(0,0,0),(outer*2,0,0),(inner+1,0,0),(0,outer-1,0),(0,0,(outer+inner)//2),(-inner-1,inner//4,0)]
   for index,position in enumerate(positions):
    name='catalog%d/record%d/pose%d'%(mid,rec['offset'],index)
    body=bytearray(bodies[mid]);body[0x86]=37;struct.pack_into('<9i',body,0,*identity);struct.pack_into('<I',body,0xa0,[0,1,0x12345678,0xffffffff][index%4])
    subject=bytearray(bodies[24]);subject[0x86]=114;subject[0x56]=37;subject[0x57]=1;struct.pack_into('<9i',subject,0,*identity)
    state={name:(rng.randrange(256)if size==1 else rng.randrange(115)if name=='collider_ref_u32'else s32(rng.getrandbits(32))if name.endswith('_s32')else rng.getrandbits(32))for name,_,size in FIELDS}
    initial={'graphics_level_u32':[0,1,2][index%3],'recorded_intersection_raw_s32':s32(rng.getrandbits(32)),'pending_query_flag_u32':rng.getrandbits(32)}
    before={'name':name,'body_hex':subject.hex(),'collider_hex':body.hex(),'relative_hex':struct.pack('<3q',*position).hex(),'globals_before':state,'resources':{'24':copy.deepcopy(catalog['models']['24']),str(mid):copy.deepcopy(resource)},'scripts':[{'return_s32':1,'primitive_u8':0,'globals_after':state}]}
    preparations.append(before);model_by_name[name]=(resource,rec,body.hex(),initial)
 gm=json.loads((G.PROOF/'instruction-proof.json').read_text());gs=(G.PROOF/'source-procedures.asm').read_text();G.verify_archived(gm,gs)
 kernel=G.assembly(gs)
 with tempfile.TemporaryDirectory(prefix='terrain-input-preparation-')as directory:
  work=Path(directory);(work/'prepare.s').write_text(kernel);subprocess.run(['as','--64','-o',str(work/'prepare.o'),str(work/'prepare.s')],check=True,capture_output=True);subprocess.run(['ld','-o',str(work/'prepare'),str(work/'prepare.o')],check=True,capture_output=True)
  prepared_input=b''.join(G.packet(r)for r in preparations);runs=[subprocess.run([str(work/'prepare')],input=prepared_input,capture_output=True,check=True).stdout for _ in range(3)]
  if len(set(runs))!=1 or len(runs[0])!=G.OUTPUT*len(preparations):raise ValueError('Native F579 input preparation differs')
  for i,row in enumerate(preparations):
   native=G.decode(runs[0][i*G.OUTPUT:(i+1)*G.OUTPUT],row);call=native['calls'][0];resource,rec,body,initial=model_by_name[row['name']]
   context={key:copy.deepcopy(call[key])for key in ['point_xyz_s32','mesh_zoom_s32','vector_scale_s32']};context.update(vertices_hex=resource['vertices_hex'],normals_hex=resource['normals_hex'],normal_origin_u32=resource['normals_origin_u32'],vertex_origin_u32=resource['vertices_origin_u32'])
   rows.append({'name':row['name'],'model_index_u32':int(row['name'].split('/')[0][7:]),'record_offset_u32':rec['offset'],'body_before_hex':body,'program_hex':resource['collision_program_hex'],'offset_u32':int(rec['terrain_features_offset'])-6,'context':context,'threshold_s32':call['threshold_s32'],'globals_before':row['globals_before'],'terrain_state_before':initial,'input_preparation':'actual-native-F579-on-authored-source-space-pose'})
 # Explicit source-scale and full-word graphics tests take a guaranteed
 # zero-distance outer gate; no unsupported high-detail query is invented.
 for index,scale in enumerate([-0x80000000,-65,-64,-33,-32,-31,-1,0,1,31,32,33,63,64,65,0x7fffffff]):
  row=copy.deepcopy(rows[0]);row['name']='raw-scale-flat/%d'%scale;row['context']['point_xyz_s32']=[0,0,0];row['context']['mesh_zoom_s32']=scale;row['context']['vector_scale_s32']=scale;body=bytearray.fromhex(row['body_before_hex']);struct.pack_into('<q',body,0x138,0);struct.pack_into('<q',body,0x140,0);row['body_before_hex']=body.hex();row['threshold_s32']=0;row['terrain_state_before']['graphics_level_u32']=[0xffffffff,0xa5a5a5a5,0x80000000,15][index%4];row['input_preparation']='explicit-raw-source-operands';rows.append(row)
 # Query all14 original style descriptors with real seed/map machinery.
 template=copy.deepcopy(next(r for r in rows if r['model_index_u32']==117 and r['name'].endswith('/pose4')))
 for style in range(14):
  for seed in [0,0xffffffff]:
   row=copy.deepcopy(template);row['name']='style%d/seed%08x'%(style,seed);program=bytearray.fromhex(row['program_hex']);struct.pack_into('<H',program,row['offset_u32']+4,style);row['program_hex']=program.hex();body=bytearray.fromhex(row['body_before_hex']);struct.pack_into('<I',body,0xa0,seed);row['body_before_hex']=body.hex();row['terrain_state_before']['graphics_level_u32']=1;row['input_preparation']='actual-native-F579-with-explicit-style-and-seed-operands';rows.append(row)
 for graphics in range(16):
  row=copy.deepcopy(template);row['name']='query-graphics/%d'%graphics;row['terrain_state_before']['graphics_level_u32']=graphics;row['input_preparation']='actual-native-F579-with-explicit-graphics-word';rows.append(row)
 # Deterministic arbitrary point/threshold operands and interior resource
 # pointers exercise the public low-level ABI, independently of F579 poses.
 for index in range(32):
  row=copy.deepcopy(template);row['name']='raw-context/%02d'%index
  row['context']['point_xyz_s32']=[rng.randrange(-120000000,120000001)for _ in range(3)]
  row['threshold_s32']=[-5200,-1,0,1,5200,0x7fffffff,-0x80000000,31][index%8]
  row['terrain_state_before']['graphics_level_u32']=index%4
  prefix=bytes(rng.getrandbits(8)for _ in range(index%13+1))
  row['context']['vertices_hex']=prefix.hex()+row['context']['vertices_hex'];row['context']['vertex_origin_u32']=len(prefix)
  row['context']['normals_hex']=prefix.hex()+row['context']['normals_hex'];row['context']['normal_origin_u32']=len(prefix)
  row['input_preparation']='explicit-raw-source-point-threshold-and-resource-origins';rows.append(row)
 # Authored model116 has equal inner/outer bounds: both records always take
 # a source flat gate. An explicit bound-override probe also executes their
 # real corner/style bytes through F1876 without altering those bytes.
 for base in [r for r in rows if r['model_index_u32']==116 and r['name'].endswith('/pose4')]:
  row=copy.deepcopy(base);row['name']=base['name']+'/explicit-bounds-override';body=bytearray.fromhex(row['body_before_hex']);struct.pack_into('<2q',body,0x138,16000000,0);row['body_before_hex']=body.hex();row['context']['point_xyz_s32']=[0,0,1800000];row['threshold_s32']=0;row['terrain_state_before']['graphics_level_u32']=1;row['input_preparation']='explicit-body-bounds-and-point-operands-with-original116-payload';rows.append(row)
 row=copy.deepcopy(template);row['name']='raw-scale-flat/INT_MIN-half-word-distinguisher';body=bytearray.fromhex(row['body_before_hex']);struct.pack_into('<2q',body,0x138,0x100000002,4);row['body_before_hex']=body.hex();row['context'].update(point_xyz_s32=[-2,0,0],mesh_zoom_s32=-0x80000000,vector_scale_s32=-0x80000000,vertices_hex='00'*len(bytes.fromhex(row['context']['vertices_hex'])));row['threshold_s32']=0;row['terrain_state_before']['graphics_level_u32']=0xffffffff;row['input_preparation']='explicit-two-half-shift-INT_MIN-overflow-distinguisher';rows.append(row)
 return rows

def generate(a):
 if a.reprove_original or not(a.proof_dir/'instruction-proof.json').exists():reprove(a)
 meta,source,kernel,adapter=verify(a.proof_dir);rows=build_rows()
 with tempfile.TemporaryDirectory(prefix='source-terrain-native-')as directory:
  work=Path(directory)
  for name,text in [('kernel',kernel),('adapter',adapter)]:
   (work/(name+'.s')).write_text(text);subprocess.run(['as','--64','-o',str(work/(name+'.o')),str(work/(name+'.s'))],check=True,capture_output=True)
  subprocess.run(['ld','-o',str(work/'native'),str(work/'kernel.o'),str(work/'adapter.o')],check=True,capture_output=True)
  packets=[packet(r)for r in rows];outputs=[]
  for _ in range(3):
   result=subprocess.run([str(work/'native')],input=b''.join(packets),capture_output=True,timeout=120)
   if result.returncode or result.stderr or len(result.stdout)!=OUTPUT*len(rows):raise ValueError('Native terrain failed code%d output%d/%d stderr%s'%(result.returncode,len(result.stdout),OUTPUT*len(rows),result.stderr.decode()))
   outputs.append(result.stdout)
  if len(set(outputs))!=1:raise ValueError('Fresh native results differ')
  reverse=subprocess.run([str(work/'native')],input=b''.join(reversed(packets)),capture_output=True,check=True,timeout=120).stdout
  if any(reverse[i*OUTPUT:(i+1)*OUTPUT]!=outputs[0][(len(rows)-i-1)*OUTPUT:(len(rows)-i)*OUTPUT]for i in range(len(rows))):raise ValueError('Reverse native order differs')
  for i,row in enumerate(rows):row['expected']=decode(outputs[0][i*OUTPUT:(i+1)*OUTPUT],row)
  if any(r['expected']['query_count_u32']!=1 for r in rows if r['name'].startswith(('style','query-graphics'))or r['name'].endswith('/explicit-bounds-override')):raise ValueError('Directed query coverage did not execute original F1876')
  base_count=len(rows)
  for i in range(32):
   row=copy.deepcopy(rows[(i*7)%base_count]);row['name']='consecutive/%d'%i;row['globals_before']=copy.deepcopy(rows[-1]['expected']['globals_after']);row['terrain_state_before']=copy.deepcopy(rows[-1]['expected']['terrain_state_after']);row['terrain_state_before']['graphics_level_u32']=1
   packet_bytes=packet(row);runs=[subprocess.run([str(work/'native')],input=packet_bytes,capture_output=True,check=True).stdout for _ in range(3)]
   if len(set(runs))!=1:raise ValueError('Dependent native terrain differs')
   row['expected']=decode(runs[0],row);rows.append(row)
 dependencies=['tools/rebuild_source_collision_terrain_native.py','tools/rebuild_source_natural_contact_native.py','tools/rebuild_source_surface_contact_native.py','tools/rebuild_source_frame_dispatch_native.py','tools/rebuild_source_collision_geometry_native.py','validation/collision-programs-2026-11-17/geometry-native-proof/instruction-proof.json','validation/collision-programs-2026-11-17/geometry-native-proof/source-procedures.asm','recovered-history/ground_harness/tools/build_terrain_query_reference.py','recovered-history/ground_harness/tools/native_reference.py','data/ffe_collision_programs.json','tests/fixtures/source_object_factory_native.json']
 fixture={'schema':'starfrontier-source-collision-terrain-native-v1','profile':PROFILE,'case_count':len(rows),'base_case_count':base_count,'consecutive_native_steps':32,'fresh_process_runs':3,'reverse_repeat_cases':base_count,'source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'instruction_proof_sha256':sha((a.proof_dir/'instruction-proof.json').read_bytes()),'host_assembly_sha256':sha(kernel.encode()),'host_adapter_sha256':sha(adapter.encode()),'native_output_sha256':sha(outputs[0]),'input_packets_sha256':sha(b''.join(packets)),'all_readonly_buffers_unchanged':True,'expected_arithmetic_calculated_in_python':False,'source_dependencies_sha256':{p:sha((PROJECT/p).read_bytes())for p in dependencies},'scope':meta['scope'],'cases':rows}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(fixture,indent=2)+'\n')
 print(json.dumps({'case_count':len(rows),'query_cases':sum(r['expected']['query_count_u32']for r in rows),'sha256':sha(a.output.read_bytes()),'output':str(a.output)},indent=2))

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--reprove-original',action='store_true');generate(p.parse_args())
if __name__=='__main__':main()
