#!/usr/bin/env python3
"""Whole DOS F583/F1656 packed plane controls, reviewed ELF64 stack adapter.

Only input bytes and scripts are constructed in Python. All expected geometry
and observed intermediates come from the verified original instruction bodies.
Default replay uses captured text; --reprove-original checks the uploaded EXE.
"""
from __future__ import annotations
import argparse,hashlib,json,random,re,struct,subprocess,tempfile
from pathlib import Path
import rebuild_source_surface_contact_native as C

PROJECT=Path(__file__).resolve().parents[1]
PROOF=PROJECT/'validation/collision-programs-2026-11-17/planes-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_collision_planes_native.json'
PROFILE='dos-firstenc-f583-packed-plane-v1'
EXE_SHA=C.EXE_SHA;ASM_SHA=C.ASM_SHA
NUMBERS=[583,1656]
ALIASES={'FUNC_001656':0x4599b4,'_abs':0x476238}
ADDRESSES={583:0x428e84,1656:0x4599b4}
INPUT=2096;OUTPUT=2176;BUFFER=1024
def sha(raw):return hashlib.sha256(raw).hexdigest()
def s32(value):return (value&0x7fffffff)-(value&0x80000000)

def reprove(a):
    exe=a.exe.read_bytes();source=a.asm.read_text()
    if sha(exe)!=EXE_SHA or sha(a.asm.read_bytes())!=ASM_SHA:raise ValueError('Original EXE/ASM identity differs')
    bodies={n:C.J.block(source,n)for n in NUMBERS};records={};dis=[];image=C.G.Image(exe)
    for n,body in bodies.items():
        rows=C.J.instructions(C.compile32(body,ALIASES,'FUNC_%06d'%n,ADDRESSES[n]))
        original=C.original_rows(a.exe,ADDRESSES[n],count=len(rows))
        if C.J.canonical(rows)!=C.J.canonical(original):raise ValueError('Whole DOS F%d differs'%n)
        if not original or original[-1][1]!='ret':raise ValueError('Whole function return boundary differs')
        at=image.offset(ADDRESSES[n],1);end=image.offset(original[-1][0],1)+1;raw=exe[at:end]
        records[str(n)]={'virtual_address':ADDRESSES[n],'executable_offset':at,'byte_length':len(raw),'hex':raw.hex(),'sha256':sha(raw),'instruction_count':len(rows),'normalized_instruction_sha256':sha('\n'.join(C.J.canonical(original)).encode()),'all_full_procedure_instructions_equal':True}
        dis.extend('%08x: %s %s'%r for r in original)
    if exe[0x67038:0x67038+len(C.G.ABS_DOS)]!=C.G.ABS_DOS:raise ValueError('Watcom abs identity differs')
    text='\n'.join(bodies[n]for n in NUMBERS)+'\nFUNC_999999:\nret\n'
    meta={'schema':'starfrontier-original-collision-planes-proof-v1','source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'source_procedures_sha256':sha(text.encode()),'bindings':ALIASES,'procedures':records,'abs_hex':C.G.ABS_DOS.hex(),'host_adaptations':['Reviewed ELF64 cdecl stack-slot/register adapter; original geometry operations remain signed32','Low-address raw point, normal and vertex buffers; source pointers remain four-byte fields','MOV-only observation before SETNL preserves all source arithmetic and flags','Abs/FindMSB entry counters preserve original instruction-visible values'],'scope':'Whole DOS F583 packed-plane predicate and F1656 FindMSB, original Watcom abs behavior. No stream decoder, F580 recursion, F576 classifier, Main or physical Android claim.'}
    a.proof_dir.mkdir(parents=True,exist_ok=True)
    (a.proof_dir/'source-procedures.asm').write_text(text)
    (a.proof_dir/'instruction-proof.json').write_text(json.dumps(meta,indent=2)+'\n')
    (a.proof_dir/'dos-disassembly.txt').write_text('\n'.join(dis)+'\n')

def verify(proof):
    meta=json.loads((proof/'instruction-proof.json').read_text());source=(proof/'source-procedures.asm').read_text()
    if meta['source_executable_sha256']!=EXE_SHA or meta['source_assembly_sha256']!=ASM_SHA or meta['bindings']!=ALIASES or meta['abs_hex']!=C.G.ABS_DOS.hex()or sha(source.encode())!=meta['source_procedures_sha256']:raise ValueError('Captured source identity differs')
    for n in NUMBERS:
        record=meta['procedures'][str(n)];body=C.J.block(source,n)
        rows=C.J.instructions(C.compile32(body,ALIASES,'FUNC_%06d'%n,ADDRESSES[n]))
        if len(rows)!=record['instruction_count']or sha('\n'.join(C.J.canonical(rows)).encode())!=record['normalized_instruction_sha256']or sha(bytes.fromhex(record['hex']))!=record['sha256']or not record['all_full_procedure_instructions_equal']:raise ValueError('Archived DOS instruction proof differs F%d'%n)
    return meta,source

def assembly(source):
    adapter=C.load('plane_host_abi',PROJECT/'recovered-history/ground_harness/tools/native_reference.py')
    normalized=re.sub(r'(FUNC_\d{6})_[A-Za-z0-9_]+',r'\1',source)
    lines,_=adapter.procedures(normalized,NUMBERS);text='\n'.join(lines)
    marker='setnl al'
    if text.count(marker)!=1:raise ValueError('F583 comparison observation changed')
    observed=[]
    for at,offset in zip([0x1c,0x18,0x14,0x28,0x24,0x20],range(16,40,4)):
        observed+=['mov r11d,DWORD PTR [rbp-0x%x]'%at,'mov DWORD PTR [output+%d],r11d'%offset]
    observed+=['mov DWORD PTR [output+40],ecx','mov DWORD PTR [output+44],edx','mov DWORD PTR [output+48],eax',marker]
    text=text.replace(marker,'\n'.join(observed))
    text=text.replace('FUNC_001656:','FUNC_001656:\npushfq\ninc DWORD PTR [msb_count]\npopfq',1)
    return '.intel_syntax noprefix\n.code64\n.section .text\n.global _start\n'+text+'\n'+WRAPPER

def packet(row):
    ctx=row['context'];normals=bytes.fromhex(ctx['normals_hex']);vertices=bytes.fromhex(ctx['vertices_hex'])
    if len(normals)!=BUFFER or len(vertices)!=BUFFER:raise ValueError('Native raw buffer length differs')
    cells=[row['threshold_s32'],row['plane_u8'],*ctx['point_xyz_s32'],ctx['mesh_zoom_s32'],ctx['vector_scale_s32'],ctx['normal_origin_u32'],ctx['vertex_origin_u32'],BUFFER,BUFFER,0]
    raw=struct.pack('<12I',*[v&0xffffffff for v in cells])+normals+vertices
    assert len(raw)==INPUT
    return raw
def decode(raw,row):
    fields=struct.unpack_from('<16I',raw)
    if len(raw)!=OUTPUT or fields[0]!=0x504c414e or fields[1]>1 or fields[2:4]!=(3,1)or any(fields[13:])or raw[-64:]!=b'\xa5'*64:raise ValueError('Native plane guard/call counters differ '+row['name'])
    if raw[64:1088].hex()!=row['context']['normals_hex']or raw[1088:2112].hex()!=row['context']['vertices_hex']:raise ValueError('Native plane changed raw input buffers')
    return {'value_s32':fields[1],'normal_q8_s32':[s32(v)for v in fields[4:7]],'delta_s32':[s32(v)for v in fields[7:10]],'truncate_shift_u32':fields[10],'distance_s32':s32(fields[11]),'threshold_after_s32':s32(fields[12]),'source_order':['F583','_abs','_abs','_abs','F1656']}

def generate(a):
    meta,source=verify(a.proof_dir);native=assembly(source);rng=random.Random(0x583FACE);rows=[]
    values=[0,1,-1,127,-128,8191,-8192,8192,-8193,0x7fffffff,-0x80000000,0x40000000,-0x40000000]
    shifts=[-65,-64,-63,-33,-32,-31,-16,-1,0,1,7,15,23,30,31,32,33,63,64,65,-0x80000000,0x7fffffff]
    for i in range(640):
        code=i%256;normal_origin=[6,13,24,32][i%4];vertex_origin=[0,8,17][i%3]
        normals=bytearray(rng.randbytes(BUFFER));vertices=bytearray(rng.randbytes(BUFFER));at=normal_origin+(code>>1)*6-6
        vertex_code=(i*37+i//2)&255;normals[at]=vertex_code
        for axis in range(3):normals[at+2+axis]=[0,1,127,128,255,rng.randrange(256)][(i+axis)%6]
        va=vertex_origin+(vertex_code>>1)*6
        for axis in range(3):vertices[va+2+axis]=[0,1,127,128,255,rng.randrange(256)][(i//6+axis)%6]
        point=[rng.choice(values)for _ in range(3)];mesh=shifts[i%len(shifts)];scale=0
        if i>=512:mesh=rng.choice(values);scale=rng.choice(values)
        rows.append({'name':'packed-plane/%03d'%i,'plane_u8':code,'threshold_s32':rng.choice(values),'context':{'point_xyz_s32':point,'mesh_zoom_s32':mesh,'vector_scale_s32':scale,'normal_origin_u32':normal_origin,'vertex_origin_u32':vertex_origin,'normals_hex':normals.hex(),'vertices_hex':vertices.hex()}})
    with tempfile.TemporaryDirectory(prefix='collision-planes-native-')as directory:
        work=Path(directory);(work/'native.s').write_text(native)
        subprocess.run(['as','--64','-o',str(work/'native.o'),str(work/'native.s')],capture_output=True,check=True)
        subprocess.run(['ld','-o',str(work/'native'),str(work/'native.o')],capture_output=True,check=True)
        def run(items):
            done=subprocess.run([str(work/'native')],input=b''.join(packet(r)for r in items),capture_output=True,check=True,timeout=30)
            if done.stderr or len(done.stdout)!=OUTPUT*len(items):raise ValueError('Native plane output length/stderr differs')
            return done.stdout
        outputs=[run(rows)for _ in range(3)]
        if len(set(outputs))!=1:raise ValueError('Fresh native process output differs')
        reverse=run(list(reversed(rows)))
        if b''.join(reverse[i*OUTPUT:(i+1)*OUTPUT]for i in reversed(range(len(rows))))!=outputs[0]:raise ValueError('Reversed native result differs')
        for i,row in enumerate(rows):row['expected']=decode(outputs[0][i*OUTPUT:(i+1)*OUTPUT],row)
    paths=['tools/rebuild_source_collision_planes_native.py','tools/rebuild_source_surface_contact_native.py','tools/rebuild_source_atmospheric_native.py','tools/rebuild_ground_surface_native.py','recovered-history/ground_harness/tools/native_reference.py']
    pins={p:sha((PROJECT/p).read_bytes())for p in paths}
    result={'schema':'starfrontier-source-collision-planes-native-v1','profile':PROFILE,'case_count':len(rows),'source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'instruction_proof_sha256':sha((a.proof_dir/'instruction-proof.json').read_bytes()),'source_procedures_sha256':sha(source.encode()),'host_assembly_sha256':sha(native.encode()),'fresh_process_runs':3,'reverse_repeat_cases':len(rows),'all_raw_buffer_and_context_canaries_unchanged':True,'expected_arithmetic_calculated_in_python':False,'source_dependencies_sha256':pins,'scope':meta['scope'],'cases':rows}
    a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,indent=2)+'\n');(a.proof_dir/'planes-native.s').write_text(native)
    print(json.dumps({'case_count':len(rows),'fixture_sha256':sha(a.output.read_bytes()),'procedures':len(meta['procedures']),'instructions':sum(r['instruction_count']for r in meta['procedures'].values())}))

WRAPPER=r'''
_abs:
 push rbp
 mov rbp,rsp
 inc DWORD PTR [abs_count]
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
_start:
 mov esp,OFFSET FLAT:stack_end
 cld
next_case:
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 lea rsi,[input+r8]
 mov edx,2096
 sub edx,r8d
 syscall
 test eax,eax
 jz finished
 js failed
 add r8d,eax
 cmp r8d,2096
 jb read_more
 mov edi,OFFSET FLAT:output
 xor eax,eax
 mov ecx,2112
 rep stosb
 mov edi,OFFSET FLAT:output+2112
 mov al,0xa5
 mov ecx,64
 rep stosb
 mov DWORD PTR [abs_count],0
 mov DWORD PTR [msb_count],0
 mov esi,OFFSET FLAT:input+48
 mov edi,OFFSET FLAT:normals
 mov ecx,1024
 rep movsb
 mov edi,OFFSET FLAT:vertices
 mov ecx,1024
 rep movsb
 mov QWORD PTR [normals_guard_a],-1
 mov QWORD PTR [normals_guard_b],-1
 mov QWORD PTR [vertices_guard_a],-1
 mov QWORD PTR [vertices_guard_b],-1
 mov esi,OFFSET FLAT:input+8
 mov edi,OFFSET FLAT:context
 mov ecx,12
 rep movsb
 mov eax,DWORD PTR [input+28]
 add eax,OFFSET FLAT:normals
 mov DWORD PTR [context+12],eax
 mov eax,DWORD PTR [input+32]
 add eax,OFFSET FLAT:vertices
 mov DWORD PTR [context+16],eax
 mov eax,DWORD PTR [input+20]
 mov DWORD PTR [context+20],eax
 mov eax,DWORD PTR [input+24]
 mov DWORD PTR [context+24],eax
 mov esi,OFFSET FLAT:context
 mov edi,OFFSET FLAT:context_before
 mov ecx,28
 rep movsb
 push OFFSET FLAT:context
 mov eax,DWORD PTR [input+4]
 push rax
 mov eax,DWORD PTR [input]
 push rax
 call FUNC_000583
 add rsp,24
 mov DWORD PTR [output+4],eax
 mov DWORD PTR [output],0x504c414e
 mov eax,DWORD PTR [abs_count]
 mov DWORD PTR [output+8],eax
 mov eax,DWORD PTR [msb_count]
 mov DWORD PTR [output+12],eax
 cmp QWORD PTR [normals_guard_a],-1
 jne failed
 cmp QWORD PTR [normals_guard_b],-1
 jne failed
 cmp QWORD PTR [vertices_guard_a],-1
 jne failed
 cmp QWORD PTR [vertices_guard_b],-1
 jne failed
 mov esi,OFFSET FLAT:context
 mov edi,OFFSET FLAT:context_before
 mov ecx,28
 repe cmpsb
 jne failed
 mov esi,OFFSET FLAT:normals
 mov edi,OFFSET FLAT:output+64
 mov ecx,1024
 rep movsb
 mov esi,OFFSET FLAT:vertices
 mov ecx,1024
 rep movsb
 xor r8d,r8d
write_more:
 mov eax,1
 mov edi,1
 lea rsi,[output+r8]
 mov edx,2176
 sub edx,r8d
 syscall
 test eax,eax
 jle failed
 add r8d,eax
 cmp r8d,2176
 jb write_more
 jmp next_case
finished:
 mov eax,60
 xor edi,edi
 syscall
failed:
 mov eax,60
 mov edi,91
 syscall
.section .bss
.balign 16
input: .zero 2096
output: .zero 2176
abs_count: .zero 4
msb_count: .zero 4
context: .zero 28
context_before: .zero 28
normals_guard_a: .zero 8
normals: .zero 1024
normals_guard_b: .zero 8
vertices_guard_a: .zero 8
vertices: .zero 1024
vertices_guard_b: .zero 8
.balign 16
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
'''
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--output',type=Path,default=FIXTURE)
    p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'))
    p.add_argument('--reprove-original',action='store_true');a=p.parse_args()
    if a.reprove_original or not(a.proof_dir/'instruction-proof.json').exists():reprove(a)
    generate(a)
if __name__=='__main__':main()
