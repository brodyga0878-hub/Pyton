#!/usr/bin/env python3
"""Whole DOS F576/F579 and raw arithmetic with explicit observed F582 replies.
The host ELF64 ABI executes captured original instructions; Python only builds
packets and records their output, never computes expected geometry arithmetic.
"""
from __future__ import annotations
import argparse,copy,hashlib,json,random,re,struct,subprocess,tempfile
from pathlib import Path
import rebuild_source_natural_contact_native as N
import rebuild_source_frame_dispatch_native as F
PROJECT=N.PROJECT
PROOF=PROJECT/'validation/collision-programs-2026-11-17/geometry-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_collision_geometry_native.json'
NUMBERS=[576,579,1334,1341,1657,1658,1660,1670,1521]
PROFILE='dos-firstenc-f576-f579-geometry-v1'
INPUT=2048;OUTPUT=3328;MAXCALLS=16;RECORD=152
BODYAT=56;PARENTAT=394;RELAT=732;BODYDESC=756;PARENTDESC=824;CHILDAT=892;SCRIPTAT=1148
FIELDS=F.FIELDS
def sha(raw):return hashlib.sha256(raw).hexdigest()
def s32(value):return(value&0x7fffffff)-(value&0x80000000)
def reprove(a):
 raw=a.exe.read_bytes();source=a.asm.read_text();data=a.data.read_text()
 if sha(raw)!=N.EXE_SHA or sha(a.asm.read_bytes())!=N.ASM_SHA:raise ValueError('Original identities differ')
 bodies,records,dis,callbacks=N.proof(source,data,raw,a.exe,NUMBERS)
 selected='\n'.join(bodies[n]for n in NUMBERS)+'\nFUNC_999999:\nret\n'
 # The resolver's addresses are recovered again from its complete instruction
 # proof. Captured normalized opcodes and call/data targets remain authoritative.
 scope=N.__dict__.copy()
 import inspect
 method=inspect.getsource(N.proof).replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
 exec(method,scope);_,_,_,_,aliases=scope['proof'](source,data,raw,a.exe,NUMBERS)
 a.proof_dir.mkdir(parents=True,exist_ok=True)
 (a.proof_dir/'source-procedures.asm').write_text(selected)
 (a.proof_dir/'dos-disassembly.txt').write_text('\n'.join(dis.values()))
 meta={'schema':'starfrontier-f576-f579-whole-instruction-proof-v1','source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'procedures':records,'source_symbol_addresses':aliases,'source_procedures_sha256':sha(selected.encode()),'all_whole_instructions_equal':True,'callback_words':callbacks,'scope':'Whole original F576/F579 and real Int64/vector/matrix arithmetic. F582 is a strict observed full prepared-context response, not an executed geometry program in this oracle. Public Godot entry separately invokes the real program module.'}
 (a.proof_dir/'instruction-proof.json').write_text(json.dumps(meta,indent=2)+'\n');return meta,selected
def verify_archived(meta,source):
 if sha(source.encode())!=meta['source_procedures_sha256']or meta['source_executable_sha256']!=N.EXE_SHA or meta['source_assembly_sha256']!=N.ASM_SHA:raise ValueError('Archived source identity differs')
 for n in NUMBERS:
  record=meta['procedures'][str(n)];body=N.G.block(source,n)
  rows=N.C.J.instructions(N.C.compile32(body,meta['source_symbol_addresses'],'FUNC_%06d'%n,record['virtual_address']))
  if len(rows)!=record['instruction_count']or sha('\n'.join(N.canonical(rows)).encode())!=record['normalized_instruction_sha256']:raise ValueError('Instruction proof differs F'+str(n))
def capture(base):
 lines=[]
 for i,(name,symbol,size)in enumerate(FIELDS):
  lines.append(('movzx eax,BYTE PTR 'if size==1 else'mov eax,DWORD PTR ')+f'[DATA_{symbol:06d}]')
  if name=='collider_ref_u32':lines.append('call encode_ref')
  lines.append(f'mov DWORD PTR [{base}+{i*4}],eax')
 return '\n'.join(lines)
def assembly(source):
 clean=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',source)
 adapter=N.C.load('geometry_host_abi',PROJECT/'recovered-history/ground_harness/tools/native_reference.py')
 lines,_=adapter.procedures(clean,NUMBERS);text='\n'.join(lines)
 old='FUNC_001670:\npush rbp\nmov rbp,rsp\nadd rsp,-8'
 if text.count(old)!=1:raise ValueError('Changed two-pop F1670 scratch frame')
 text=text.replace(old,old.replace('rsp,-8','rsp,-16'))
 text+='\n'+WRAPPER.replace('@CAPTURE_BEFORE@',capture('r8+24')).replace('@CAPTURE_AFTER@',capture('r8+72')).replace('@CAPTURE_FINAL@',capture('r8'))
 data='\n.section .data\n.balign 8\nDATA_007756: .quad FUNC_001538\n'
 data+='\n.section .bss\n.balign 16\ninput: .zero 2048\noutput: .zero 3328\ncall_count: .zero 4\nresult_value: .zero 4\ncurrent_record: .zero 8\ncurrent_script: .zero 8\n'
 for name,symbol,size in FIELDS:data+=f'DATA_{symbol:06d}: .zero {size}\n'
 for name,size in [('body',338),('collider',338),('relative',24),('body_descriptor',68),('parent_descriptor',68),('children',256),('program',16)]:data+=f'{name}_guard_a: .zero 8\n{name}: .zero {size}\n{name}_guard_b: .zero 8\n'
 data+='stack: .zero 1048576\nstack_end:\n.section .note.GNU-stack,"",@progbits\n'
 return '.intel_syntax noprefix\n.code64\n.section .text\n.global _start\n'+text+data
WRAPPER=r'''
encode_ref:
 cmp eax,114
 jbe ref_done
 cmp eax,OFFSET FLAT:body
 je ref_body
 cmp eax,OFFSET FLAT:collider
 jne failed
 movzx eax,BYTE PTR [collider+0x86]
 ret
ref_body:
 movzx eax,BYTE PTR [body+0x86]
ref_done:
 ret
FUNC_001538:
 mov eax,DWORD PTR [rsp+8]
 cmp eax,DWORD PTR [body+0x82]
 jne parent_model
 mov eax,OFFSET FLAT:body_descriptor
 ret
parent_model:
 cmp eax,DWORD PTR [collider+0x82]
 jne failed
 mov eax,OFFSET FLAT:parent_descriptor
 ret
FUNC_000582:
 push rbp
 mov rbp,rsp
 push rbx
 push rsi
 push rdi
 mov eax,DWORD PTR [call_count]
 cmp eax,16
 jae failed
 imul ecx,eax,152
 add ecx,OFFSET FLAT:output+764
 mov QWORD PTR [current_record],rcx
 mov r8,rcx
 imul ecx,eax,56
 add ecx,OFFSET FLAT:input+1148
 mov QWORD PTR [current_script],rcx
 mov esi,DWORD PTR [rbp+24]
 lea edi,[r8]
 mov ecx,12
 rep movsb
 mov eax,DWORD PTR [rsi+8]
 mov DWORD PTR [r8+12],eax
 mov eax,DWORD PTR [rsi+12]
 mov DWORD PTR [r8+16],eax
 mov eax,DWORD PTR [rbp+48]
 mov DWORD PTR [r8+20],eax
 @CAPTURE_BEFORE@
 mov r10,QWORD PTR [current_script]
 mov eax,DWORD PTR [r10]
 mov DWORD PTR [r8+120],eax
 mov eax,DWORD PTR [r10+4]
 mov DWORD PTR [r8+124],eax
 mov edx,DWORD PTR [rbp+16]
 mov BYTE PTR [rdx],al
 lea esi,[r10+8]
 mov eax,DWORD PTR [rsi]
 mov BYTE PTR [DATA_008696],al
 mov eax,DWORD PTR [rsi+4]
 mov BYTE PTR [DATA_008697],al
 mov eax,DWORD PTR [rsi+8]
 mov BYTE PTR [DATA_008698],al
 mov eax,DWORD PTR [rsi+12]
 mov BYTE PTR [DATA_008699],al
 mov eax,DWORD PTR [rsi+16]
 mov BYTE PTR [DATA_008700],al
 mov eax,DWORD PTR [rsi+20]
 mov BYTE PTR [DATA_008701],al
 mov eax,DWORD PTR [rsi+24]
 mov DWORD PTR [DATA_008702],eax
 mov eax,DWORD PTR [rsi+28]
 mov DWORD PTR [DATA_008703],eax
 mov eax,DWORD PTR [rsi+32]
 mov DWORD PTR [DATA_008704],eax
 mov eax,DWORD PTR [rsi+36]
 mov DWORD PTR [DATA_008705],eax
 mov eax,DWORD PTR [rsi+40]
 mov DWORD PTR [DATA_008706],eax
 mov eax,DWORD PTR [rsi+44]
 mov BYTE PTR [DATA_008707],al
 @CAPTURE_AFTER@
 mov rax,QWORD PTR [rbp]
 mov esi,DWORD PTR [rax+40]
 lea edi,[r8+128]
 mov ecx,24
 rep movsb
 inc DWORD PTR [call_count]
 mov r10,QWORD PTR [current_script]
 mov eax,DWORD PTR [r10]
 pop rdi
 pop rsi
 pop rbx
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
 mov edx,2048
 sub edx,r8d
 syscall
 test eax,eax
 jle finish
 add r8d,eax
 cmp r8d,2048
 jne read_more
 cld
 mov edi,OFFSET FLAT:output
 xor eax,eax
 mov ecx,3328
 rep stosb
 mov DWORD PTR [call_count],0
 mov rax,0xa5a5a5a5a5a5a5a5
 mov QWORD PTR [body_guard_a],rax
 mov QWORD PTR [body_guard_b],rax
 mov QWORD PTR [collider_guard_a],rax
 mov QWORD PTR [collider_guard_b],rax
 mov QWORD PTR [relative_guard_a],rax
 mov QWORD PTR [relative_guard_b],rax
 mov QWORD PTR [body_descriptor_guard_a],rax
 mov QWORD PTR [body_descriptor_guard_b],rax
 mov QWORD PTR [parent_descriptor_guard_a],rax
 mov QWORD PTR [parent_descriptor_guard_b],rax
 mov QWORD PTR [children_guard_a],rax
 mov QWORD PTR [children_guard_b],rax
 mov esi,OFFSET FLAT:input+56
 mov edi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:collider
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:relative
 mov ecx,24
 rep movsb
 mov edi,OFFSET FLAT:body_descriptor
 mov ecx,68
 rep movsb
 mov edi,OFFSET FLAT:parent_descriptor
 mov ecx,68
 rep movsb
 mov edi,OFFSET FLAT:children
 mov ecx,256
 rep movsb
 mov DWORD PTR [body_descriptor+0x34],OFFSET FLAT:children+256
 mov DWORD PTR [parent_descriptor+0x34],OFFSET FLAT:program
 mov DWORD PTR [parent_descriptor+4],OFFSET FLAT:program
 mov DWORD PTR [parent_descriptor+12],OFFSET FLAT:program
 mov esi,OFFSET FLAT:input+8
 mov eax,DWORD PTR [rsi]
 mov BYTE PTR [DATA_008696],al
 mov eax,DWORD PTR [rsi+4]
 mov BYTE PTR [DATA_008697],al
 mov eax,DWORD PTR [rsi+8]
 mov BYTE PTR [DATA_008698],al
 mov eax,DWORD PTR [rsi+12]
 mov BYTE PTR [DATA_008699],al
 mov eax,DWORD PTR [rsi+16]
 mov BYTE PTR [DATA_008700],al
 mov eax,DWORD PTR [rsi+20]
 mov BYTE PTR [DATA_008701],al
 mov eax,DWORD PTR [rsi+24]
 mov DWORD PTR [DATA_008702],eax
 mov eax,DWORD PTR [rsi+28]
 mov DWORD PTR [DATA_008703],eax
 mov eax,DWORD PTR [rsi+32]
 mov DWORD PTR [DATA_008704],eax
 mov eax,DWORD PTR [rsi+36]
 mov DWORD PTR [DATA_008705],eax
 mov eax,DWORD PTR [rsi+40]
 mov DWORD PTR [DATA_008706],eax
 mov eax,DWORD PTR [rsi+44]
 mov BYTE PTR [DATA_008707],al
 mov eax,OFFSET FLAT:relative
 push rax
 mov eax,OFFSET FLAT:collider
 push rax
 mov eax,OFFSET FLAT:body
 push rax
 call FUNC_000576
 add rsp,24
 mov DWORD PTR [result_value],eax
 mov DWORD PTR [output],0x47454f4d
 mov DWORD PTR [output+4],eax
 mov eax,DWORD PTR [call_count]
 mov DWORD PTR [output+8],eax
 mov esi,OFFSET FLAT:body
 mov edi,OFFSET FLAT:output+16
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:collider
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:relative
 mov ecx,24
 rep movsb
 mov r8d,OFFSET FLAT:output+716
 @CAPTURE_FINAL@
 mov rax,0xa5a5a5a5a5a5a5a5
 cmp QWORD PTR [body_guard_a],rax
 jne failed
 cmp QWORD PTR [body_guard_b],rax
 jne failed
 cmp QWORD PTR [collider_guard_a],rax
 jne failed
 cmp QWORD PTR [collider_guard_b],rax
 jne failed
 cmp QWORD PTR [relative_guard_a],rax
 jne failed
 cmp QWORD PTR [relative_guard_b],rax
 jne failed
 cmp QWORD PTR [body_descriptor_guard_a],rax
 jne failed
 cmp QWORD PTR [body_descriptor_guard_b],rax
 jne failed
 cmp QWORD PTR [parent_descriptor_guard_a],rax
 jne failed
 cmp QWORD PTR [parent_descriptor_guard_b],rax
 jne failed
 cmp QWORD PTR [children_guard_a],rax
 jne failed
 cmp QWORD PTR [children_guard_b],rax
 jne failed
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,3328
 syscall
 cmp eax,3328
 jne failed
 jmp next_case
finish:
 mov eax,60
 xor edi,edi
 syscall
failed:
 mov eax,60
 mov edi,91
 syscall
'''
def globals_packet(state):return struct.pack('<12I',*[int(state[name])&0xffffffff for name,_,_ in FIELDS])
def globals_decode(raw):return{name:s32(v)if name.endswith('_s32')else v for(name,_,_),v in zip(FIELDS,struct.unpack('<12I',raw))}
def packet(row):
 resources=row['resources'];body=bytes.fromhex(row['body_hex']);parent=bytes.fromhex(row['collider_hex'])
 own=resources[str(struct.unpack_from('<I',body,0x82)[0])];other=resources[str(struct.unpack_from('<I',parent,0x82)[0])]
 children=bytes.fromhex(own['children_hex'])
 if len(children)>256:raise ValueError('Fixture child window too large')
 raw=struct.pack('<2I',0,0)+globals_packet(row['globals_before'])+body+parent+bytes.fromhex(row['relative_hex'])+bytes.fromhex(own['descriptor_hex'])+bytes.fromhex(other['descriptor_hex'])+bytes(256-len(children))+children
 scripts=row['scripts']
 for i in range(MAXCALLS):
  script=scripts[i]if i<len(scripts)else{'return_s32':-1,'primitive_u8':0,'globals_after':row['globals_before']}
  raw+=struct.pack('<2I',script['return_s32']&0xffffffff,script['primitive_u8'])+globals_packet(script['globals_after'])
 raw+=bytes(4)
 if len(raw)!=INPUT:raise ValueError('Native packet width changed')
 return raw
def decode(raw,row):
 if len(raw)!=OUTPUT:raise ValueError('Native output width differs')
 magic,returned,count,guard=struct.unpack_from('<4I',raw)
 if magic!=0x47454f4d or count>16 or guard:raise ValueError('Native header/canary differs')
 if raw[16:354].hex()!=row['body_hex']or raw[354:692].hex()!=row['collider_hex']or raw[692:716].hex()!=row['relative_hex']:raise ValueError('Read-only raw geometry inputs changed')
 calls=[]
 for i in range(count):
  rec=raw[764+i*RECORD:764+(i+1)*RECORD]
  calls.append({'point_xyz_s32':list(struct.unpack_from('<3i',rec)),'mesh_zoom_s32':struct.unpack_from('<i',rec,12)[0],'vector_scale_s32':struct.unpack_from('<i',rec,16)[0],'threshold_s32':struct.unpack_from('<i',rec,20)[0],'globals_before':globals_decode(rec[24:72]),'globals_after':globals_decode(rec[72:120]),'return_s32':s32(struct.unpack_from('<I',rec,120)[0]),'primitive_u8':struct.unpack_from('<I',rec,124)[0],'relative_after_hex':rec[128:152].hex()})
 return {'return_s32':s32(returned),'globals_after':globals_decode(raw[716:764]),'body_after_hex':raw[16:354].hex(),'collider_after_hex':raw[354:692].hex(),'relative_after_hex':raw[692:716].hex(),'calls':calls}
def model_json(row):
 return {'descriptor_hex':row['descriptor_hex'],'vertices_hex':'00'*16,'normals_hex':'00'*16,'collision_program_hex':'00','children_hex':'0000','children_records':[]}
def cases():
 data=json.loads((PROJECT/'data/ffe_object_factory.json').read_text())['models'];rng=random.Random(0x576579);rows=[]
 for i in range(256):
  own=[15,24,38,62][i%4];parent=[64,96,117,148][(i//4)%4]
  body=bytearray(rng.randbytes(338));collider=bytearray(rng.randbytes(338));struct.pack_into('<I',body,0x82,own);struct.pack_into('<I',collider,0x82,parent);body[0x86]=114;collider[0x86]=37;body[0x56]=37 if i%3 else 0;body[0x57]=i%2;body[0x14c]=128 if i%4 else 0
  matrices=[(0x7fffffff,0,0,0,0x7fffffff,0,0,0,0x7fffffff),(0,0,-0x7fffffff,0,0x7fffffff,0,0x7fffffff,0,0),(1518500249,0,1518500249,0,0x7fffffff,0,-1518500249,0,1518500249)]
  struct.pack_into('<9i',body,0,*matrices[i%3]);struct.pack_into('<9i',collider,0,*matrices[(i//3)%3]);struct.pack_into('<i',body,0x140,[0,1,-1,65536,0x7fffffff,-0x80000000][i%6])
  a=model_json(data[str(own)]);b=model_json(data[str(parent)])
  # Descriptor scales are explicit raw operand variants; actual pointers are
  # replaced by reviewed observer resources, never used as expected physics.
  ad=bytearray.fromhex(a['descriptor_hex']);bd=bytearray.fromhex(b['descriptor_hex']);struct.pack_into('<i',ad,0x14,[20,23,24,54,-10][i%5]);struct.pack_into('<2i',bd,0x14,*[(23,0),(30,2),(0,0),(-2,-3),(63,2)][(i//5)%5]);a['descriptor_hex']=ad.hex();b['descriptor_hex']=bd.hex()
  children=[]
  for j in range(i%4):children.append({'axis_radius_encoded_s16':[(8|0),(24|3),(32|4),(48|7)][j%4],'displacement_s16':[-32768,-100,1,32767][(i+j)%4]})
  if i%11==0 and len(children)>1:children[1]['axis_radius_encoded_s16']=46 # axis6 reuses transformed previous local
  a['children_records']=children;a['children_hex']=(b'\0\0'+b''.join(struct.pack('<hh',c['axis_radius_encoded_s16'],c['displacement_s16'])for c in reversed(children))).hex()
  vector=[rng.randrange(-(1<<50),(1<<50))for _ in range(3)]if i%3 else [[0,0,0],[0x7fffffff,-0x80000000,1],[1<<60,-(1<<60),123]][(i//3)%3]
  state={name:(rng.randrange(256)if size==1 else rng.getrandbits(32))for name,_,size in FIELDS}
  for name,_,_ in FIELDS:
   if name.endswith('_s32'):state[name]=s32(state[name])
  state['collider_ref_u32']=[0,37,114][i%3];scripts=[]
  for j in range(16):
   out=copy.deepcopy(state);out['volume_flags_u8']=[0,2,0x80,0x83][(i+j)%4];out['collision_kind_u8']=[0,1,2,255][(i//2+j)%4]
   scripts.append({'return_s32':[-1,-128,0,1,127][(i+j*2)%5]if j<len(children)else[-1,0,1][i%3],'primitive_u8':(i+j*29)&255,'globals_after':out})
  rows.append({'name':'whole-geometry/'+str(i),'body_hex':body.hex(),'collider_hex':collider.hex(),'relative_hex':struct.pack('<3q',*vector).hex(),'globals_before':state,'resources':{str(own):a,str(parent):b},'scripts':scripts})
 return rows
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--refresh-original-proof',action='store_true');a=p.parse_args()
 if a.refresh_original_proof or not(a.proof_dir/'instruction-proof.json').exists():meta,source=reprove(a)
 else:meta=json.loads((a.proof_dir/'instruction-proof.json').read_text());source=(a.proof_dir/'source-procedures.asm').read_text();verify_archived(meta,source)
 native=assembly(source);rows=cases()
 with tempfile.TemporaryDirectory(prefix='geometry-native-')as directory:
  work=Path(directory);(work/'n.s').write_text(native);subprocess.run(['as','--64','-o',str(work/'n.o'),str(work/'n.s')],check=True,capture_output=True);subprocess.run(['ld','-o',str(work/'n'),str(work/'n.o')],check=True,capture_output=True)
  def run(packet_bytes):return subprocess.run([str(work/'n')],input=packet_bytes,capture_output=True,check=True).stdout
  packets=b''.join(packet(r)for r in rows);runs=[run(packets)for _ in range(3)]
  if len(set(runs))!=1 or len(runs[0])!=len(rows)*OUTPUT:raise ValueError('Native fresh runs differ')
  reverse=run(b''.join(packet(r)for r in reversed(rows)))
  if b''.join(reverse[i*OUTPUT:(i+1)*OUTPUT]for i in reversed(range(len(rows))))!=runs[0]:raise ValueError('Reverse replay differs')
  for i,row in enumerate(rows):row['expected']=decode(runs[0][i*OUTPUT:(i+1)*OUTPUT],row)
  for i in range(32):
   row=copy.deepcopy(rows[i%16]);row['name']='consecutive/'+str(i);row['globals_before']=copy.deepcopy(rows[-1]['expected']['globals_after']);output=run(packet(row));row['expected']=decode(output,row);rows.append(row)
 pins={n:sha((PROJECT/n).read_bytes())for n in ['tools/rebuild_source_collision_geometry_native.py','tools/rebuild_source_natural_contact_native.py','tools/rebuild_source_surface_contact_native.py','tools/rebuild_source_frame_dispatch_native.py','recovered-history/ground_harness/tools/native_reference.py','data/ffe_object_factory.json']}
 fixture={'schema':'starfrontier-source-collision-geometry-native-v1','profile':PROFILE,'case_count':len(rows),'consecutive_native_steps':32,'fresh_process_runs':3,'reverse_repeat_cases':256,'all_raw_owners_readonly':True,'expected_arithmetic_calculated_in_python':False,'instruction_proof_sha256':sha((a.proof_dir/'instruction-proof.json').read_bytes()),'source_dependencies_sha256':pins,'host_assembly_sha256':sha(native.encode()),'scope':meta['scope'],'cases':rows}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(fixture,indent=2)+'\n');(a.proof_dir/'geometry-native.s').write_text(native)
 print(json.dumps({'case_count':len(rows),'fixture_sha256':sha(a.output.read_bytes()),'output':str(a.output)},indent=2))
if __name__=='__main__':main()
