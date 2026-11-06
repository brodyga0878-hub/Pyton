#!/usr/bin/env python3
"""Rebuild missing leaf-vertex controls by executing actual source instructions.

F1470/F1472/F1473/F1474/F1476/F1477/F1478/F1521/F1671 execute on the
host against original EXE vertex streams. The source F1478 projection argument
is zero; attempted projected-only branches terminate, never return substitutes.
This oracle does not import SourceModelVertices, SourceModelVM or a VM export.
"""
from __future__ import annotations
import argparse, hashlib, importlib.util, json, re, struct, subprocess, tempfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
EXE_SHA = 'd919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA = 'd4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
NUMBERS = [1470, 1472, 1473, 1474, 1476, 1477, 1478, 1521, 1671]
LEAVES = [302, 312, 366, 392, 393, 394, 395, 396, 269]
INPUT = 596
OUTPUT = 800
GUARD = 0x5645525445583139

def sha(raw): return hashlib.sha256(raw).hexdigest()

def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec); spec.loader.exec_module(result)
    return result

def block(source, number):
    start = re.search(r'^FUNC_%06d(?:_[A-Za-z0-9_]+)?:' % number, source, re.M)
    end = re.search(r'^(?:FUNC_\d+(?:_[A-Za-z0-9_]+)?|_[A-Za-z0-9_]+):', source[start.end():], re.M)
    return source[start.start():start.end() + end.start() if end else len(source)]

def original_models(raw):
    pe = struct.unpack_from('<I', raw, 60)[0]
    base = struct.unpack_from('<I', raw, pe + 52)[0]
    section_start = pe + 24 + struct.unpack_from('<H', raw, pe + 20)[0]
    sections = [struct.unpack_from('<4I', raw, section_start + i * 40 + 8)
                for i in range(struct.unpack_from('<H', raw, pe + 6)[0])]
    def offset(pointer, length):
        for _, address, size, at in sections:
            delta = pointer - base - address
            if 0 <= delta and delta + length <= size and at + delta + length <= len(raw):
                return at + delta
        raise ValueError('Unmapped original model pointer')
    result = {}
    for index in LEAVES:
        pointer = struct.unpack_from('<I', raw, 0xba8fc + index * 4)[0]
        at = offset(pointer, 68); descriptor = raw[at:at + 68]
        words = struct.unpack('<17I', descriptor); count = words[2]
        if count % 2 or count > 128: raise ValueError('Unexpected paired source vertex count')
        vertex_at = offset(words[1], count * 3); vertices = raw[vertex_at:vertex_at + count * 3]
        if not set(vertices[::6]) <= {1, 5, 19}: raise ValueError('Leaf escaped native oracle domain')
        result[index] = {'descriptor_offset': at, 'descriptor_hex': descriptor.hex(),
                         'descriptor_sha256': sha(descriptor), 'vertices_offset': vertex_at,
                         'vertices_hex': vertices.hex(), 'vertices_sha256': sha(vertices),
                         'vertex_count': count, 'scale_shift_raw': words[5] + words[6]}
    return result

def assembly(source):
    adapter = module(PROJECT / 'recovered-history/ground_harness/tools/native_reference.py', 'vertex_host_adapter')
    selected = '\n'.join(block(source, n) for n in NUMBERS) + '\nFUNC_999999:\nret\n'
    selected = re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+', r'\1', selected)
    lines, _ = adapter.procedures(selected, NUMBERS)
    text = '\n'.join(lines).replace('SECTION .data', '.section .data').replace('SECTION .text', '.section .text')
    text = re.sub(r'^db ', '.byte ', text, flags=re.M)
    text = re.sub(r'^dd ', '.long ', text, flags=re.M)
    text = text.replace('jmp [eax*4+DATA_000045]', 'mov r11d,DWORD PTR [eax*4+DATA_000045]\njmp r11')
    return f'''.intel_syntax noprefix
.code64
.section .text
.global _start
{text}
FUNC_001471:
FUNC_001479:
 mov edi,93
 mov eax,60
 syscall
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:input
 add rsi,r8
 mov edx,{INPUT}
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,{INPUT}
 jne read_more
 mov edi,OFFSET FLAT:frame
 mov ecx,136
 xor eax,eax
 rep stosd
 mov edi,OFFSET FLAT:cache
 mov ecx,1152
 rep stosd
 mov edi,OFFSET FLAT:output
 mov ecx,{OUTPUT // 4}
 rep stosd
 mov rax,{GUARD}
 mov QWORD PTR [cache_before],rax
 mov QWORD PTR [cache_after],rax
 mov QWORD PTR [frame_before],rax
 mov QWORD PTR [frame_after],rax
 mov esi,OFFSET FLAT:input+8
 mov edi,OFFSET FLAT:frame+0x14
 mov ecx,9
 rep movsd
 mov esi,OFFSET FLAT:input+44
 mov edi,OFFSET FLAT:frame+0x54
 mov ecx,8
 rep movsd
 mov esi,OFFSET FLAT:input+76
 mov edi,OFFSET FLAT:entity+0x9c
 mov ecx,32
 rep movsd
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [frame+0x148],eax
 mov DWORD PTR [frame+0x14c],OFFSET FLAT:entity
 mov DWORD PTR [frame+0x150],OFFSET FLAT:input+212
 mov DWORD PTR [frame+0xf0],7
 mov eax,DWORD PTR [input+204]
 mov DWORD PTR [DATA_008818],eax
 mov eax,DWORD PTR [input+208]
 mov DWORD PTR [DATA_008820],eax
 xor r12d,r12d
vertex_loop:
 push r12
 push OFFSET FLAT:frame
 call FUNC_001470
 add rsp,16
 imul edi,r12d,12
 add edi,OFFSET FLAT:output
 mov edx,DWORD PTR [rax+0x18]
 mov DWORD PTR [rdi],edx
 mov edx,DWORD PTR [rax+0x1c]
 mov DWORD PTR [rdi+4],edx
 mov edx,DWORD PTR [rax+0x20]
 mov DWORD PTR [rdi+8],edx
 inc r12d
 cmp r12d,DWORD PTR [input]
 jb vertex_loop
 mov eax,DWORD PTR [DATA_008818]
 mov DWORD PTR [output+768],eax
 mov eax,DWORD PTR [DATA_008820]
 mov DWORD PTR [output+772],eax
 mov rax,{GUARD}
 cmp QWORD PTR [cache_before],rax
 jne guard_failure
 cmp QWORD PTR [cache_after],rax
 jne guard_failure
 cmp QWORD PTR [frame_before],rax
 jne guard_failure
 cmp QWORD PTR [frame_after],rax
 jne guard_failure
 mov QWORD PTR [output+776],rax
 mov QWORD PTR [output+784],rax
 mov DWORD PTR [output+792],r12d
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,{OUTPUT}
 syscall
 jmp next_case
guard_failure:
 mov edi,94
 mov eax,60
 syscall
finished:
 xor edi,edi
 mov eax,60
 syscall
.section .data
DATA_007727: .quad FUNC_001471
DATA_007728: .quad FUNC_001472
DATA_009200: .long cache
DATA_008818: .long 0
DATA_008820: .long 0
.section .bss
.balign 16
input: .zero {INPUT}
frame_before: .zero 8
frame: .zero 544
frame_after: .zero 8
entity: .zero 512
cache_before: .zero 8
cache: .zero 4608
cache_after: .zero 8
output: .zero {OUTPUT}
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
''', {str(n): sha(block(source, n).encode()) for n in NUMBERS}

def contexts():
    identity = [2147483647, 0, 0, 0, 2147483647, 0, 0, 0, 2147483647]
    matrices = [identity, [0,0,2147483647,0,2147483647,0,-2147483647,0,0],
                [1518500249,0,1518500249,0,2147483647,0,-1518500249,0,1518500249],
                [0,2147483647,0,0,0,-2147483647,-2147483647,0,0]]
    return [{'matrix_q31': matrix, 'frame_parameters': [0,0,door,0,0,0,0,0],
             'entity_variables_u16': [0] * 64, 'random_state_u32': [0x12345678,0x87654321]}
            for matrix in matrices for door in [0,32768,65535]]

def packet(model, context):
    data = bytearray(struct.pack('<II9i8i64H2I', model['vertex_count'], model['scale_shift_raw'],
                                *context['matrix_q31'], *context['frame_parameters'],
                                *context['entity_variables_u16'], *context['random_state_u32']))
    data.extend(bytes.fromhex(model['vertices_hex']).ljust(384, b'\0'))
    assert len(data) == INPUT
    return bytes(data)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--exe', type=Path, default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--output', type=Path, default=PROJECT/'tests/fixtures/model_vertices_reference.json')
    args = parser.parse_args(); raw = args.exe.read_bytes(); source_raw = args.source.read_bytes()
    if sha(raw) != EXE_SHA or sha(source_raw) != ASM_SHA: raise ValueError('Unexpected original revision')
    source = args.source.read_text(); models = original_models(raw); ctx = contexts(); text, hashes = assembly(source)
    order = [(index, ci) for index in LEAVES for ci in range(len(ctx))]
    packets = [packet(models[index], ctx[ci]) for index, ci in order]
    with tempfile.TemporaryDirectory(prefix='original-leaf-vertices-') as directory:
        work = Path(directory); (work/'native.s').write_text(text)
        subprocess.run(['as','--64','-o',str(work/'native.o'),str(work/'native.s')],check=True)
        subprocess.run(['ld','-o',str(work/'native'),str(work/'native.o')],check=True)
        runs = [subprocess.run([str(work/'native')],input=b''.join(packets),capture_output=True,check=True).stdout for _ in range(3)]
        if len(set(runs)) != 1 or len(runs[0]) != len(order)*OUTPUT: raise ValueError('Unstable native output')
        reverse = subprocess.run([str(work/'native')],input=b''.join(reversed(packets)),capture_output=True,check=True).stdout
        if reverse != b''.join(runs[0][i*OUTPUT:(i+1)*OUTPUT] for i in reversed(range(len(order)))): raise ValueError('State leaked between native cases')
    cases=[]
    for i,(index,ci) in enumerate(order):
        output=runs[0][i*OUTPUT:(i+1)*OUTPUT];count=models[index]['vertex_count']
        if struct.unpack_from('<2Q',output,776)!=(GUARD,GUARD) or struct.unpack_from('<I',output,792)[0]!=count: raise ValueError('Native buffer guard failed')
        cases.append({'model_index':index,'context_index':ci,'vertices_local_raw':[list(struct.unpack_from('<3i',output,j*12))for j in range(count)],'final_random_state_u32':list(struct.unpack_from('<2I',output,768))})
    result={'schema':1,'source_variant':'actual-f1470-f1478-leaf-vertices-v1','source_sha256':EXE_SHA,
            'source_assembly_sha256':ASM_SHA,'source_procedure_hashes':hashes,
            'adapted_assembly_sha256':sha(text.encode()),'input_packets_sha256':sha(b''.join(packets)),
            'native_ordered_output_sha256':sha(runs[0]),'fresh_process_runs':3,'reverse_repeat_count':len(order),
            'guard_canaries_unchanged':True,'models':{str(k):v for k,v in models.items()},'contexts':ctx,'cases':cases,
            'scope':'Actual original unprojected F1470/F1478 leaf vertices, kinds1/5/19;9original leaf models,12explicit Q31/door snapshots. Not a recovered historical fixture, full renderer, projected vertices, model-program oracle or original global-effect history.',
            'host_adaptations':{'low_address_x86_64_abi':True,'jump_table_pointers':'original32bit entries to low host labels','projection_argument':0,'projected_only_unreachable_branches_exit_code':93}}
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'cases':len(cases),'source_vertex_points':sum(len(c['vertices_local_raw'])for c in cases),'fixture_sha256':sha(args.output.read_bytes())}))

if __name__=='__main__':main()
