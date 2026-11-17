#!/usr/bin/env python3
"""Whole DOS F580 native transform controls; recursive F582 is an observer.

The embedded six-DWORD dispatch table is verified as original bytes as well as
all executable instructions. Python serialises input and never computes expected
coordinate or threshold arithmetic. Portable replay needs captured proof only.
"""
from __future__ import annotations
import argparse,copy,hashlib,json,random,re,struct,subprocess,tempfile
from pathlib import Path
import rebuild_source_surface_contact_native as C
PROJECT=C.PROJECT
PROOF=PROJECT/'validation/collision-programs-2026-11-17/transform-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_collision_transform_native.json'
PROFILE='dos-firstenc-f580-nested-model-transform-v1'
EXE_SHA=C.EXE_SHA;ASM_SHA=C.ASM_SHA
ENTRY=0x428430;END=0x4285ec;TABLE=0x428539
ALIASES={'DATA_007756':0x501848,'FUNC_000582':0x428bf4}
INPUT=1216;OUTPUT=1280
OLDVERT=384;NEWVERT=192;NORMALS=96;PROGRAM=64;BODY=338

def sha(raw):return hashlib.sha256(raw).hexdigest()
def s32(value):return (value&0x7fffffff)-(value&0x80000000)
def canonical(rows):
 labels={at:i for i,(at,_,_)in enumerate(rows)};result=[]
 for at,op,args in rows:
  args=re.sub(r'\s+','',args.lower())
  if op.startswith('j') and '['not in args:
   target=int(args,16)
   if target not in labels:raise ValueError('Jump outside original F580')
   args='instruction:'+str(labels[target])
  if op=='call'and re.fullmatch(r'(?:0x)?[0-9a-f]+',args):args=hex(int(args,16))
  result.append(op+' '+args)
 return result

def compile32(source):
 text='.intel_syntax noprefix\n.code32\n.section .text\n'+''.join('.equ %s,0x%x\n'%(n,v)for n,v in ALIASES.items())+C.A.gas32(source)
 with tempfile.TemporaryDirectory(prefix='collision-transform-proof-')as d:
  p=Path(d);(p/'proof.s').write_text(text)
  subprocess.run(['as','--32',str(p/'proof.s'),'-o',str(p/'proof.o')],capture_output=True,check=True)
  subprocess.run(['ld','-m','elf_i386','-e','FUNC_000580','--section-start=.text='+hex(ENTRY),str(p/'proof.o'),'-o',str(p/'proof')],capture_output=True,check=True)
  subprocess.run(['objcopy','--dump-section','.text='+str(p/'proof.bin'),str(p/'proof')],capture_output=True,check=True)
  dis='\n'.join(subprocess.run(['objdump','-d','-Mintel','--no-show-raw-insn','--start-address='+hex(start),'--stop-address='+hex(end),str(p/'proof')],capture_output=True,text=True,check=True).stdout for start,end in [(ENTRY,TABLE),(TABLE+24,END)])
  return(p/'proof.bin').read_bytes(),dis

def source_block(source):
 body=C.J.block(source,580)
 body=re.sub(r'^SECTION \\.\w+\s*$','',body,flags=re.M)
 body=re.sub(r'^SECTION \.\w+\s*$','',body,flags=re.M)
 body=re.sub(r'^\s*dd\s+(.+)$',r'.long \1',body,flags=re.M)
 return body

def reprove(a):
 raw=a.exe.read_bytes();src=a.asm.read_bytes()
 if sha(raw)!=EXE_SHA or sha(src)!=ASM_SHA:raise ValueError('Original executable/assembly differs')
 selected=source_block(src.decode().replace('\r\n','\n'))
 compiled,dis=compile32(selected);image=C.G.Image(raw);begin=image.offset(ENTRY,1);end=image.offset(END,1);expected=raw[begin:end]
 rows=C.original_rows(a.exe,ENTRY,end=TABLE)+C.original_rows(a.exe,TABLE+24,end=END)
 if len(compiled)!=len(expected) or canonical(C.J.instructions(dis))!=canonical(rows):
  raise ValueError('Whole F580 instructions differ '+str([(i,a,b)for i,(a,b)in enumerate(zip(canonical(C.J.instructions(dis)),canonical(rows)))if a!=b][:8]))
 table_at=TABLE-ENTRY;table=compiled[table_at:table_at+24];targets=list(struct.unpack('<6I',table))
 if targets!=[0x428551,0x428565,0x428579,0x42858d,0x4285a1,0x4285b5]:raise ValueError('Original six-permutation table differs')
 rows=C.original_rows(a.exe,ENTRY,end=TABLE)+C.original_rows(a.exe,TABLE+24,end=END)
 meta={'schema':'starfrontier-original-collision-transform-proof-v1','source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'source_procedures_sha256':sha(selected.encode()),'bindings':ALIASES,'procedures':{'580':{'virtual_address':ENTRY,'executable_offset':begin,'byte_length':len(expected),'hex':expected.hex(),'sha256':sha(expected),'instruction_count':len(rows),'normalized_instruction_sha256':sha('\n'.join(canonical(rows)).encode()),'equivalent_MOV_encoding_only':True,'all_whole_instructions_equal':True}},'embedded_table':{'virtual_address':TABLE,'hex':table.hex(),'targets_u32':targets,'sha256':sha(table)},'host_adaptations':['Reviewed64 cdecl stack/register adaptation, raw32 arithmetic and low-address source buffers','Six original DWORD table slots retained; host jump loads32-bit target into EAX then jumps RAX','F1538 returns an explicitly supplied full model descriptor; F582 records the exact full transformed context/threshold/body and supplied signed-byte return'],'scope':'Whole original F580 coordinate preparation and exact recursive F582 request. No F582 program execution, universal model geometry, Main or Android claim.'}
 a.proof_dir.mkdir(parents=True,exist_ok=True);(a.proof_dir/'source-procedures.asm').write_text(selected);(a.proof_dir/'instruction-proof.json').write_text(json.dumps(meta,indent=2)+'\n');(a.proof_dir/'dos-disassembly.txt').write_text('\n'.join('%08x: %s %s'%r for r in rows)+'\n')
 return meta,selected

def verify(proof):
 meta=json.loads((proof/'instruction-proof.json').read_text());source=(proof/'source-procedures.asm').read_text();record=meta['procedures']['580']
 if meta['source_executable_sha256']!=EXE_SHA or meta['source_assembly_sha256']!=ASM_SHA or meta['bindings']!=ALIASES or sha(source.encode())!=meta['source_procedures_sha256']:raise ValueError('Archived transform proof identity differs')
 raw,dis=compile32(source)
 if sha(bytes.fromhex(record['hex']))!=record['sha256'] or sha('\n'.join(canonical(C.J.instructions(dis))).encode())!=record['normalized_instruction_sha256']:raise ValueError('Archived whole F580 instructions differ')
 at=TABLE-ENTRY
 if raw[at:at+24].hex()!=meta['embedded_table']['hex']or list(struct.unpack('<6I',raw[at:at+24]))!=meta['embedded_table']['targets_u32']:raise ValueError('Archived jump table differs')
 return meta,source

def packet(row):
 c=row['context_before'];m=row['model_resource'];raw=struct.pack('<3i2i4I',*c['point_xyz_s32'],c['mesh_zoom_s32'],c['vector_scale_s32'],c['vertex_origin_u32'],row['vertex_u8'],row['orientation_u8'],row['threshold_s32']&0xffffffff)
 raw+=bytes.fromhex(m['descriptor_hex'])+bytes.fromhex(c['vertices_hex'])+bytes.fromhex(m['normals_hex'])+bytes.fromhex(m['vertices_hex'])+bytes.fromhex(m['collision_program_hex'])+bytes.fromhex(row['body_hex'])
 raw+=struct.pack('<4I',row['recursive_return_u32'],row['recursive_primitive_u8'],m['vertex_origin_u32'],m['normal_origin_u32'])
 if len(raw)>INPUT:raise ValueError('Input packet exceeds fixed native owner')
 return raw+bytes(INPUT-len(raw))

def assembly(source):
 adapter=C.load('collision_transform_abi',PROJECT/'recovered-history/ground_harness/tools/native_reference.py')
 lines,_=adapter.procedures(source+'\nFUNC_999999:\nret\n',[580]);text='\n'.join(lines)
 marker='jmp [eax*4+DATA_000028]'
 if text.count(marker)!=1:raise ValueError('Original table jump changed')
 text=text.replace(marker,'mov eax,DWORD PTR [eax*4+DATA_000028]\njmp rax')
 return '.intel_syntax noprefix\n.code64\n.section .text\n.global _start\n'+text+'\n'+WRAPPER

def decode(raw,row):
 if len(raw)!=OUTPUT or struct.unpack_from('<I',raw)[0]!=0x54524e53 or raw[-64:]!=b'\xa5'*64:raise ValueError('Native transform owner/canary failed')
 words=struct.unpack_from('<12I',raw)
 if words[3:6]!=(1,2,3):raise ValueError('Native model pointer identity changed')
 return {'point_xyz_s32':[s32(x)for x in words[9:12]],'mesh_zoom_s32':s32(words[7]),'vector_scale_s32':s32(words[8]),'threshold_s32':s32(words[6]),'return_s32':s32(words[1]),'primitive_u8':words[2],'body_after_hex':raw[48:386].hex(),'old_vertices_after_hex':raw[386:770].hex(),'new_vertices_after_hex':raw[770:962].hex(),'new_normals_after_hex':raw[962:1058].hex(),'program_after_hex':raw[1058:1122].hex(),'descriptor_after_hex':raw[1122:1190].hex()}

def rows():
 rng=random.Random(5800017);result=[]
 shifts=[-0x80000000,-65,-33,-32,-31,-17,-1,0,1,7,16,31,32,33,65,0x7fffffff]
 for i in range(384):
  descriptor=bytearray(rng.randbytes(68));struct.pack_into('<i',descriptor,20,[-0x80000000,-1234,0,1,31,0x7fffffff][i%6]);struct.pack_into('<i',descriptor,24,[-1,0,1,0x7fffffff,-0x80000000][i%5])
  oldvertices=rng.randbytes(OLDVERT);vertices=rng.randbytes(NEWVERT);normals=rng.randbytes(NORMALS);program=rng.randbytes(PROGRAM);body=rng.randbytes(BODY)
  vertexcodes=list(range(0,64))+list(range(192,256));vertex=vertexcodes[i%len(vertexcodes)]
  axes=(i%6)|(((i//6)%8)<<3)|([0,0x40,0x80,0xc0][i%4])
  row={'name':'nested/'+str(i),'context_before':{'point_xyz_s32':[s32(rng.getrandbits(32))for _ in range(3)],'mesh_zoom_s32':shifts[i%len(shifts)],'vector_scale_s32':[-31,0,1,31,0x7fffffff,-0x80000000][i%6],'vertex_origin_u32':192,'normals_hex':'','vertices_hex':oldvertices.hex()},'model_resource':{'descriptor_hex':descriptor.hex(),'normals_hex':normals.hex(),'vertices_hex':vertices.hex(),'collision_program_hex':program.hex(),'vertex_origin_u32':[0,6,96,192][i%4],'normal_origin_u32':[0,6,48,96][i%4]},'vertex_u8':vertex,'orientation_u8':axes,'threshold_s32':[-0x80000000,-1,0,1,0x7fffffff][i%5],'body_hex':body.hex(),'recursive_return_u32':[0,1,0x7f,0x80,0xff,0x12345678,0xffffffff][i%7],'recursive_primitive_u8':i&255}
  result.append(row)
 return result

def generate(a,meta,source):
 native=assembly(source);cases=rows();runs=[]
 with tempfile.TemporaryDirectory(prefix='collision-transform-native-')as d:
  p=Path(d);(p/'native.s').write_text(native)
  subprocess.run(['as','--64',str(p/'native.s'),'-o',str(p/'native.o')],capture_output=True,check=True);subprocess.run(['ld',str(p/'native.o'),'-o',str(p/'native')],capture_output=True,check=True)
  # Build a genuinely dependent native chain before final batch/reverse
  # repeats. Python only copies complete outputs into the next input packet.
  previous=None
  for step in range(32):
   row=copy.deepcopy(cases[step]);row['name']='consecutive/'+str(step);row['sequence_index']=step
   if previous is not None:
    row['context_before']['point_xyz_s32']=previous['point_xyz_s32']
    row['context_before']['mesh_zoom_s32']=previous['mesh_zoom_s32']
    row['context_before']['vector_scale_s32']=previous['vector_scale_s32']
    row['context_before']['vertices_hex']=previous['new_vertices_after_hex']+bytes(192).hex()
    row['context_before']['vertex_origin_u32']=cases[-1]['model_resource']['vertex_origin_u32']
    row['vertex_u8']=254 if row['context_before']['vertex_origin_u32']>=192 else 0
   observed=subprocess.run([str(p/'native')],input=packet(row),capture_output=True,check=True).stdout
   previous=decode(observed,row);cases.append(row)
  packets=b''.join(packet(r)for r in cases)
  for repeat in range(3):
   done=subprocess.run([str(p/'native')],input=packets,capture_output=True,check=True);runs.append(done.stdout)
  if len(set(runs))!=1 or len(runs[0])!=len(cases)*OUTPUT:raise ValueError('Native fresh-process instability')
  reverse=subprocess.run([str(p/'native')],input=b''.join(packet(r)for r in reversed(cases)),capture_output=True,check=True).stdout
  if len(reverse)!=len(cases)*OUTPUT:raise ValueError('Native reversed size differs')
  for i,row in enumerate(cases):
   raw=runs[0][i*OUTPUT:(i+1)*OUTPUT]
   if raw!=reverse[(len(cases)-1-i)*OUTPUT:(len(cases)-i)*OUTPUT]:raise ValueError('Native order-dependent uninitialized data')
   expected=decode(raw,row)
   for key,initial in [('body_after_hex',row['body_hex']),('old_vertices_after_hex',row['context_before']['vertices_hex']),('new_vertices_after_hex',row['model_resource']['vertices_hex']),('new_normals_after_hex',row['model_resource']['normals_hex']),('program_after_hex',row['model_resource']['collision_program_hex']),('descriptor_after_hex',row['model_resource']['descriptor_hex'])]:
    if expected[key]!=initial:raise ValueError('Readonly native source buffer changed '+key)
   row['expected']=expected
 proof={'source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'instruction_proof_sha256':sha((a.proof_dir/'instruction-proof.json').read_bytes()),'source_procedures_sha256':sha(source.encode()),'host_assembly_sha256':sha(native.encode()),'fresh_process_runs':3,'consecutive_native_steps':32,'reverse_repeat_cases':len(cases),'all_input_body_model_context_canaries_unchanged':True,'expected_arithmetic_calculated_in_Python':False,'source_dependencies_sha256':{path:sha((PROJECT/path).read_bytes())for path in ['tools/rebuild_source_collision_transform_native.py','tools/rebuild_source_surface_contact_native.py','recovered-history/ground_harness/tools/native_reference.py']},'scope':meta['scope']}
 fixture={'schema':'starfrontier-source-collision-transform-native-v1','profile':PROFILE,'case_count':len(cases),'proof':proof,'cases':cases}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(fixture,indent=2)+'\n');(a.proof_dir/'transform-native.s').write_text(native)
 print(json.dumps({'status':'verified','case_count':len(cases),'fixture_sha256':sha(a.output.read_bytes()),'bytes':a.output.stat().st_size},indent=2))

WRAPPER=r'''FUNC_001538:
 cmp DWORD PTR [rsp+8],37
 jne failed
 mov eax,OFFSET FLAT:descriptor
 ret
FUNC_000582:
 push rbp
 mov rbp,rsp
 mov esi,DWORD PTR [rbp+24]
 mov eax,DWORD PTR [rsi]
 mov DWORD PTR [output+36],eax
 mov eax,DWORD PTR [rsi+4]
 mov DWORD PTR [output+40],eax
 mov eax,DWORD PTR [rsi+8]
 mov DWORD PTR [output+44],eax
 mov eax,DWORD PTR [rsi+20]
 mov DWORD PTR [output+28],eax
 mov eax,DWORD PTR [rsi+24]
 mov DWORD PTR [output+32],eax
 mov eax,DWORD PTR [rsi+12]
 mov edx,OFFSET FLAT:normals
 add edx,DWORD PTR [input+1190]
 cmp eax,edx
 jne failed
 mov DWORD PTR [output+12],1
 mov eax,DWORD PTR [rsi+16]
 mov edx,OFFSET FLAT:newvertices
 add edx,DWORD PTR [input+1186]
 cmp eax,edx
 jne failed
 mov DWORD PTR [output+16],2
 mov eax,DWORD PTR [rbp+32]
 cmp eax,OFFSET FLAT:program
 jne failed
 mov DWORD PTR [output+20],3
 mov eax,DWORD PTR [rbp+40]
 cmp eax,OFFSET FLAT:body
 jne failed
 mov eax,DWORD PTR [rbp+48]
 mov DWORD PTR [output+24],eax
 mov edi,DWORD PTR [rbp+16]
 mov al,BYTE PTR [input+1182]
 mov BYTE PTR [rdi],al
 mov eax,DWORD PTR [input+1178]
 pop rbp
 ret
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 mov esp,OFFSET FLAT:stack_end
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:input
 add rsi,r8
 mov edx,1216
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,1216
 jne read_more
 cld
 mov edi,OFFSET FLAT:output
 mov ecx,1280
 mov al,0xa5
 rep stosb
 mov DWORD PTR [output],0x54524e53
 mov rax,0xa5a5a5a5a5a5a5a5
 mov QWORD PTR [oldcontext_guard_a],rax
 mov QWORD PTR [oldcontext_guard_b],rax
 mov QWORD PTR [context_before_guard_a],rax
 mov QWORD PTR [context_before_guard_b],rax
 mov QWORD PTR [descriptor_guard_a],rax
 mov QWORD PTR [descriptor_guard_b],rax
 mov QWORD PTR [descriptor_before_guard_a],rax
 mov QWORD PTR [descriptor_before_guard_b],rax
 mov QWORD PTR [oldnormals_guard_a],rax
 mov QWORD PTR [oldnormals_guard_b],rax
 mov QWORD PTR [oldvertices_guard_a],rax
 mov QWORD PTR [oldvertices_guard_b],rax
 mov QWORD PTR [newvertices_guard_a],rax
 mov QWORD PTR [newvertices_guard_b],rax
 mov QWORD PTR [normals_guard_a],rax
 mov QWORD PTR [normals_guard_b],rax
 mov QWORD PTR [program_guard_a],rax
 mov QWORD PTR [program_guard_b],rax
 mov QWORD PTR [body_guard_a],rax
 mov QWORD PTR [body_guard_b],rax
 mov QWORD PTR [primitive_guard_a],rax
 mov QWORD PTR [primitive_guard_b],rax
 mov esi,OFFSET FLAT:input+36
 mov edi,OFFSET FLAT:descriptor
 mov ecx,68
 rep movsb
 mov esi,OFFSET FLAT:input+104
 mov edi,OFFSET FLAT:oldvertices
 mov ecx,384
 rep movsb
 mov esi,OFFSET FLAT:input+488
 mov edi,OFFSET FLAT:normals
 mov ecx,96
 rep movsb
 mov esi,OFFSET FLAT:input+584
 mov edi,OFFSET FLAT:newvertices
 mov ecx,192
 rep movsb
 mov esi,OFFSET FLAT:input+776
 mov edi,OFFSET FLAT:program
 mov ecx,64
 rep movsb
 mov esi,OFFSET FLAT:input+840
 mov edi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:input
 mov edi,OFFSET FLAT:oldcontext
 mov ecx,12
 rep movsb
 mov DWORD PTR [oldcontext+12],OFFSET FLAT:oldnormals
 mov eax,DWORD PTR [input+20]
 add eax,OFFSET FLAT:oldvertices
 mov DWORD PTR [oldcontext+16],eax
 mov eax,DWORD PTR [input+12]
 mov DWORD PTR [oldcontext+20],eax
 mov eax,DWORD PTR [input+16]
 mov DWORD PTR [oldcontext+24],eax
 mov eax,DWORD PTR [input+1186]
 add eax,OFFSET FLAT:newvertices
 mov DWORD PTR [descriptor+4],eax
 mov eax,DWORD PTR [input+1190]
 add eax,OFFSET FLAT:normals
 mov DWORD PTR [descriptor+12],eax
 mov DWORD PTR [descriptor+52],OFFSET FLAT:program
 mov esi,OFFSET FLAT:descriptor
 mov edi,OFFSET FLAT:descriptor_before
 mov ecx,68
 rep movsb
 mov esi,OFFSET FLAT:oldcontext
 mov edi,OFFSET FLAT:context_before
 mov ecx,28
 rep movsb
 mov BYTE PTR [primitive],0x77
 push OFFSET FLAT:body
 mov eax,DWORD PTR [input+32]
 push rax
 mov eax,DWORD PTR [input+28]
 push rax
 mov eax,DWORD PTR [input+24]
 push rax
 push 37
 push OFFSET FLAT:oldcontext
 push OFFSET FLAT:primitive
 call FUNC_000580
 add rsp,56
 mov DWORD PTR [output+4],eax
 movzx eax,BYTE PTR [primitive]
 mov DWORD PTR [output+8],eax
 mov rax,0xa5a5a5a5a5a5a5a5
 cmp QWORD PTR [oldcontext_guard_a],rax
 jne failed
 cmp QWORD PTR [oldcontext_guard_b],rax
 jne failed
 cmp QWORD PTR [context_before_guard_a],rax
 jne failed
 cmp QWORD PTR [context_before_guard_b],rax
 jne failed
 cmp QWORD PTR [descriptor_guard_a],rax
 jne failed
 cmp QWORD PTR [descriptor_guard_b],rax
 jne failed
 cmp QWORD PTR [descriptor_before_guard_a],rax
 jne failed
 cmp QWORD PTR [descriptor_before_guard_b],rax
 jne failed
 cmp QWORD PTR [oldnormals_guard_a],rax
 jne failed
 cmp QWORD PTR [oldnormals_guard_b],rax
 jne failed
 cmp QWORD PTR [oldvertices_guard_a],rax
 jne failed
 cmp QWORD PTR [oldvertices_guard_b],rax
 jne failed
 cmp QWORD PTR [newvertices_guard_a],rax
 jne failed
 cmp QWORD PTR [newvertices_guard_b],rax
 jne failed
 cmp QWORD PTR [normals_guard_a],rax
 jne failed
 cmp QWORD PTR [normals_guard_b],rax
 jne failed
 cmp QWORD PTR [program_guard_a],rax
 jne failed
 cmp QWORD PTR [program_guard_b],rax
 jne failed
 cmp QWORD PTR [body_guard_a],rax
 jne failed
 cmp QWORD PTR [body_guard_b],rax
 jne failed
 cmp QWORD PTR [primitive_guard_a],rax
 jne failed
 cmp QWORD PTR [primitive_guard_b],rax
 jne failed
 mov esi,OFFSET FLAT:descriptor
 mov edi,OFFSET FLAT:descriptor_before
 mov ecx,68
 repe cmpsb
 jne failed
 mov esi,OFFSET FLAT:oldcontext
 mov edi,OFFSET FLAT:context_before
 mov ecx,28
 repe cmpsb
 jne failed
 mov esi,OFFSET FLAT:body
 mov edi,OFFSET FLAT:output+48
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:oldvertices
 mov edi,OFFSET FLAT:output+386
 mov ecx,384
 rep movsb
 mov esi,OFFSET FLAT:newvertices
 mov edi,OFFSET FLAT:output+770
 mov ecx,192
 rep movsb
 mov esi,OFFSET FLAT:normals
 mov edi,OFFSET FLAT:output+962
 mov ecx,96
 rep movsb
 mov esi,OFFSET FLAT:program
 mov edi,OFFSET FLAT:output+1058
 mov ecx,64
 rep movsb
 mov esi,OFFSET FLAT:input+36
 mov edi,OFFSET FLAT:output+1122
 mov ecx,68
 rep movsb
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,1280
 syscall
 cmp eax,1280
 jne failed
 jmp next_case
failed:
 mov eax,60
 mov edi,9
 syscall
finished:
 mov eax,60
 xor edi,edi
 syscall
.section .data
.balign 8
DATA_007756: .quad FUNC_001538
.section .bss
.balign 16
input: .zero 1216
output: .zero 1280
oldcontext_guard_a: .zero 8
oldcontext: .zero 28
oldcontext_guard_b: .zero 8
context_before_guard_a: .zero 8
context_before: .zero 28
context_before_guard_b: .zero 8
descriptor_guard_a: .zero 8
descriptor: .zero 68
descriptor_guard_b: .zero 8
descriptor_before_guard_a: .zero 8
descriptor_before: .zero 68
descriptor_before_guard_b: .zero 8
oldnormals_guard_a: .zero 8
oldnormals: .zero 6
oldnormals_guard_b: .zero 8
oldvertices_guard_a: .zero 8
oldvertices: .zero 384
oldvertices_guard_b: .zero 8
newvertices_guard_a: .zero 8
newvertices: .zero 192
newvertices_guard_b: .zero 8
normals_guard_a: .zero 8
normals: .zero 96
normals_guard_b: .zero 8
program_guard_a: .zero 8
program: .zero 64
program_guard_b: .zero 8
body_guard_a: .zero 8
body: .zero 338
body_guard_b: .zero 8
primitive_guard_a: .zero 8
primitive: .zero 1
primitive_guard_b: .zero 8
.balign 16
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
'''

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--reprove-original',action='store_true');p.add_argument('--proof-only',action='store_true');a=p.parse_args()
 if a.reprove_original or not(a.proof_dir/'instruction-proof.json').exists():reprove(a)
 meta,source=verify(a.proof_dir)
 if a.proof_only:print(json.dumps({'status':'verified','procedures':meta['procedures'],'proof_dir':str(a.proof_dir)},indent=2));return
 generate(a,meta,source)

if __name__=='__main__':main()
