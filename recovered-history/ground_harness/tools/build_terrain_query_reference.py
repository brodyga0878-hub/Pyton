#!/usr/bin/env python3
"""Execute original F1876 terrain-query controls without a geographic adapter.

This research fixture supplies raw matrices and observer vectors to the original
query mode with an empty feature list. It does not assign latitude/longitude,
physical metres, planetary spin, or runtime rendering semantics to those inputs.
"""
import argparse
import hashlib
import json
import re
import struct
import subprocess
import tempfile
from pathlib import Path

from native_reference import procedures

NUMBERS = [1335, 1339, 1465, 1467, 1521, 1656, *range(1816, 1828),
           1829, 1831, 1832, 1833, 1834, 1836, 1841, 1843, 1846, 1848,
           *range(1849, 1868), 1875, 1876]
WIDENED_FRAMES = [1849, 1851, 1853, 1855, 1857, 1866, 1867]
SQRT_SIGNATURE = bytes.fromhex('0000a8050008cc09500ba60cdb0df70e')
OUTPUT_KEYS = ['query_result_raw', 'recorded_intersection_raw', 'pending_query_flag',
               'query_limit_raw', 'vertex_pool_count_after_return', 'depth_control_raw']


def function_hashes(source):
    hashes = {}
    for number in NUMBERS:
        match = re.search(rf'^FUNC_{number:06d}(?:_[A-Za-z0-9_]+)?:', source, re.M)
        if match is None:
            raise ValueError('Missing original function '+str(number))
        end = re.search(r'^FUNC_\d+(?:_[A-Za-z0-9_]+)?:', source[match.end():], re.M)
        block = source[match.start():match.end()+end.start() if end else len(source)]
        hashes[str(number)] = hashlib.sha256(block.encode()).hexdigest()
    return hashes


def data_block(data, number):
    start = data.index(f'DATA_{number:06d}:')
    end = re.search(r'^DATA_\d+:', data[start+1:], re.M)
    return data[start:start+1+end.start() if end else len(data)]


def byte_block(block):
    result = bytearray()
    for line in block.splitlines():
        line = line.split(';')[0].strip()
        if not line or line.startswith(('DATA_', 'align')):
            continue
        if not line.startswith('db '):
            raise ValueError('Expected a non-pointer original byte resource')
        result.extend(int(value, 0) & 255 for value in line[3:].split(','))
    return bytes(result)


def resource_assembly(data, executable):
    begin = data.index('DATA_007835:')
    end = data.index('DATA_007895:')
    region = data[begin:end]
    prefix = byte_block(data_block(data, 7835))
    base = executable.find(prefix)
    if base < 0 or executable.find(prefix, base+1) >= 0:
        raise ValueError('Missing or ambiguous original terrain table signature')
    cursor = 0
    resource_bytes = bytearray()
    per_table = {}
    current = None
    assembly = ['.section .data']
    for line in region.splitlines():
        clean = line.split(';')[0].strip()
        if not clean:
            continue
        if clean.startswith('DATA_'):
            current = clean[:-1]
            per_table[current] = {'source_block_sha256': hashlib.sha256(data_block(data, int(current[5:])).encode()).hexdigest(),
                                  'exe_offset': hex(base+cursor), 'non_pointer_bytes': 0, 'pointer_words': 0}
            assembly.append(clean)
        elif clean.startswith('db '):
            raw = bytes(int(value, 0) & 255 for value in clean[3:].split(','))
            if executable[base+cursor:base+cursor+len(raw)] != raw:
                raise ValueError('Original terrain table differs from executable at '+hex(base+cursor))
            resource_bytes.extend(raw)
            per_table[current]['non_pointer_bytes'] += len(raw)
            cursor += len(raw)
            assembly.append('.byte '+clean[3:])
        elif clean.startswith('dd '):
            words = clean[3:].split(',')
            cursor += len(words)*4
            per_table[current]['pointer_words'] += len(words)
            assembly.append('.long '+re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+', r'\1', clean[3:]))
        else:
            raise ValueError('Unexpected terrain resource directive '+clean)
    auxiliary = {}
    # The original default feature-map resources are constants, not zero-filled
    # BSS stand-ins. The tested empty-list queries do not supply custom patches.
    for number in [7637, 7638]:
        block = data_block(data, number)
        raw = byte_block(block)
        at = executable.find(raw)
        if at < 0:
            raise ValueError('Missing original feature-map resource '+str(number))
        auxiliary[f'DATA_{number:06d}'] = {'source_block_sha256': hashlib.sha256(block.encode()).hexdigest(),
                                         'bytes_sha256': hashlib.sha256(raw).hexdigest(),
                                         'bytes': len(raw), 'exe_offset': hex(at)}
        assembly.append(f'DATA_{number:06d}:')
        for index in range(0, len(raw), 64):
            assembly.append('.byte '+','.join(str(value) for value in raw[index:index+64]))
    sqrt_at = executable.find(SQRT_SIGNATURE)
    if sqrt_at < 0 or executable.find(SQRT_SIGNATURE, sqrt_at+1) >= 0:
        raise ValueError('Missing or ambiguous original integer sqrt table')
    raw_sqrt = executable[sqrt_at:sqrt_at+4096]
    if len(raw_sqrt) != 4096:
        raise ValueError('Truncated original integer sqrt table')
    assembly.extend(['DATA_007723: .quad FUNC_001467', 'DATA_007724: .quad FUNC_001465', 'DATA_007977:'])
    assembly.extend('.short '+str(value) for value in struct.unpack('<2048H', raw_sqrt))
    metadata = {'source_region_sha256': hashlib.sha256(region.encode()).hexdigest(),
                'exe_region_offset': hex(base), 'region_bytes': cursor,
                'non_pointer_bytes_verified': len(resource_bytes),
                'non_pointer_bytes_sha256': hashlib.sha256(resource_bytes).hexdigest(),
                'tables': per_table, 'default_feature_maps': auxiliary,
                'sqrt_table': {'exe_offset': hex(sqrt_at), 'bytes': len(raw_sqrt),
                               'sha256': hashlib.sha256(raw_sqrt).hexdigest()}}
    return assembly, metadata


def adapt_assembly(source, data, executable):
    source = re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+', r'\1', source)
    source = re.sub(r'\+0x(f[0-9a-f]{7})', lambda match: '-0x%x' % (0x100000000-int(match[1], 16)), source)
    source = re.sub(r'add esp,0x(f[0-9a-f]{7})', lambda match: 'add esp,-0x%x' % (0x100000000-int(match[1], 16)), source)
    for number in WIDENED_FRAMES:
        start = source.index(f'FUNC_{number:06d}:')
        end = start+1+re.search(r'^FUNC_\d+:', source[start+1:], re.M).start()
        block = source[start:end]
        if block.count('add esp,byte -0x8') != 1:
            raise ValueError('Unexpected frame in original terrain worker '+str(number))
        block = block.replace('add esp,byte -0x8', 'add esp,byte -0x10')
        source = source[:start]+block+source[end:]
    lines, _ = procedures(source, NUMBERS)
    text = '\n'.join(lines)
    text = re.sub(r'\[rbp[^\]]*\]', lambda match: re.sub(r'\b(eax|ebx|ecx|edx|esi|edi)\b', lambda register: 'r'+register[1][1:], match[0]), text)
    text = re.sub(r'(,\s*)(DATA_\d+|FUNC_\d+)$', r'\1OFFSET FLAT:\2', text, flags=re.M)
    text = re.sub(r'call QWORD PTR \[([^\]]+)\]', lambda match: 'mov eax,DWORD PTR ['+match[1]+']\ncall rax', text)
    resources, metadata = resource_assembly(data, executable)
    assembly = ['.intel_syntax noprefix', '.code64', '.section .text', '.global _start', text, *resources]
    assembly.append('''
.section .text
_SetJmp:
 xor eax,eax
 ret
_LongJmp:
 mov eax,60
 mov edi,96
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
 mov edx,56
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,56
 jne read_more
 mov eax,DWORD PTR [input]
 mov DWORD PTR [object+0xa0],eax
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [center+8],eax
 mov eax,DWORD PTR [input+52]
 mov DWORD PTR [DATA_008812],eax
 mov DWORD PTR [result],-1
 push 1
 push 0
 push 0
 push 0
 mov eax,DWORD PTR [input+44]
 push rax
 push OFFSET FLAT:input+8
 push OFFSET FLAT:center
 push OFFSET FLAT:patches
 push 0
 push OFFSET FLAT:object
 mov eax,DWORD PTR [input+48]
 push rax
 push OFFSET FLAT:result
 call FUNC_001876
 add rsp,96
 mov eax,DWORD PTR [result]
 mov DWORD PTR [output],eax
 mov eax,DWORD PTR [DATA_009283]
 mov DWORD PTR [output+4],eax
 mov eax,DWORD PTR [DATA_009284]
 mov DWORD PTR [output+8],eax
 mov eax,DWORD PTR [DATA_009285]
 mov DWORD PTR [output+12],eax
 mov eax,DWORD PTR [DATA_009273]
 mov DWORD PTR [output+16],eax
 mov eax,DWORD PTR [DATA_009269]
 mov DWORD PTR [output+20],eax
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,24
 syscall
 jmp next_case
finished:
 mov eax,60
 xor edi,edi
 syscall
.section .bss
input: .zero 56
object: .zero 512
center: .zero 12
patches: .zero 256
result: .zero 4
output: .zero 24
.balign 16
stack: .zero 8388608
stack_end:
''')
    return '\n'.join(assembly)+'\n', metadata


def unresolved_adapter(undefined, data):
    assembly = ['.intel_syntax noprefix', '.code64']
    metadata = {'unreached_function_traps': [], 'bss_sizes': {}}
    for symbol in sorted(line.split()[-1] for line in undefined.splitlines() if line.strip()):
        if symbol.startswith(('FUNC_', '_')):
            assembly.extend(['.section .text', '.global '+symbol, symbol+':', 'mov eax,60', 'mov edi,97', 'syscall'])
            metadata['unreached_function_traps'].append(symbol)
        elif symbol.startswith('DATA_'):
            match = re.search(r'^'+symbol+r':\s*\n\s*resb\s+(\d+)', data, re.M)
            if match is None:
                raise ValueError('An unresolved terrain constant must not be replaced with BSS: '+symbol)
            size = int(match[1])
            assembly.extend(['.section .bss', '.global '+symbol, symbol+': .zero '+str(size)])
            metadata['bss_sizes'][symbol] = size
        else:
            raise ValueError('Unexpected native query symbol '+symbol)
    return '\n'.join(assembly)+'\n', metadata


def build_cases():
    cases = []
    for seed in [0, 1, 0x12345678, 0xffffffff]:
        for style in range(14):
            for radius in [65536, 1048576]:
                orientations = [
                    [-radius, 0, 0, 0, radius, 0, 0, 0, radius],
                    [0, 0, radius, 0, radius, 0, radius, 0, 0],
                    [-radius, 0, 0, 0, 0, -radius, 0, radius, 0],
                ]
                for orientation, matrix in enumerate(orientations):
                    cases.append({'seed': seed, 'style': style, 'radius_parameter_raw': radius,
                                  'matrix_raw': matrix, 'center_raw': [0, 0, radius+radius//10],
                                  'query_limit_raw': 4*radius, 'graphics_level_raw': 1,
                                  'orientation_index': orientation})
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('executable', type=Path)
    parser.add_argument('--data-source', type=Path)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--fixture-name', default='terrain_query_reference.json')
    args = parser.parse_args()
    original_source = args.source.read_text()
    original_data = (args.data_source or args.source.with_name('ffedat.asm')).read_text()
    executable = args.executable.read_bytes()
    hashes = function_hashes(original_source)
    assembly, resources = adapt_assembly(original_source, original_data, executable)
    cases = build_cases()
    # Every query runs again after all later queries in the same native process.
    # This retains the original allocator/free-list state rather than clearing it.
    ordered_cases = cases+list(reversed(cases))
    payload = b''.join(struct.pack('<14I', case['seed'], case['center_raw'][2],
                                  *(value & 0xffffffff for value in case['matrix_raw']),
                                  case['style'], case['query_limit_raw'], case['graphics_level_raw'])
                       for case in ordered_cases)
    with tempfile.TemporaryDirectory(prefix='ffe-terrain-query-') as directory:
        work = Path(directory)
        (work/'query.s').write_text(assembly)
        subprocess.run(['as', '--64', str(work/'query.s'), '-o', str(work/'query.o')], check=True)
        undefined = subprocess.check_output(['nm', '-u', str(work/'query.o')], text=True)
        adapter, adapter_metadata = unresolved_adapter(undefined, original_data)
        (work/'excluded.s').write_text(adapter)
        subprocess.run(['as', '--64', str(work/'excluded.s'), '-o', str(work/'excluded.o')], check=True)
        subprocess.run(['ld', '-m', 'elf_x86_64', str(work/'query.o'), str(work/'excluded.o'), '-o', str(work/'query')], check=True)
        result = subprocess.run([str(work/'query')], input=payload, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
        if result.returncode != 0:
            raise RuntimeError('Original raw terrain control failed with status '+str(result.returncode)+', complete records '+str(len(result.stdout)//24))
        output = result.stdout
        # A clean second process verifies that no first-run initialization leaks
        # into the captured query results either.
        fresh = subprocess.run([str(work/'query')], input=payload, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, timeout=30).stdout
    if output != fresh:
        raise ValueError('Fresh-process native query controls did not reproduce')
    if len(output) != 24*len(ordered_cases):
        raise ValueError('Incomplete original terrain query output')
    for index, case in enumerate(cases):
        values = struct.unpack_from('<6i', output, index*24)
        repeat_index = len(ordered_cases)-1-index
        repeated = struct.unpack_from('<6i', output, repeat_index*24)
        if values != repeated:
            raise ValueError('Terrain query depends on earlier raw queries at '+str(index))
        case['result'] = dict(zip(OUTPUT_KEYS, values))
    report = {'schema': 1, 'revision': 'terrain-query-raw-v1',
              'scope': ('Original F1876 query flag 1 with its real selected integer terrain workers, sqrt and Q31 math. '
                        'Raw matrix/observer inputs only; empty feature list. No height or geometry function is substituted. '
                        'SetJmp returns the initial zero path; LongJmp and unreachable render/feature paths abort. '
                        'This does not validate canonical geographic direction, physical scale, planetary spin, '
                        'original city features, or Android terrain integration.'),
              'source_sha256': hashlib.sha256(executable).hexdigest(),
              'source_procedure_hashes': hashes,
              'assembly_sha256': hashlib.sha256(assembly.encode()).hexdigest(),
              'unreached_adapter_sha256': hashlib.sha256(adapter.encode()).hexdigest(),
              'stack_adaptations': {'encoded_negative_frame_offsets_normalized': True,
                                    'two_pop_local_frames_widened_to_16_bytes': WIDENED_FRAMES,
                                    'original_32bit_callback_tables_retained': True,
                                    'callback_load_then_indirect_call': True},
              'original_resources': resources, 'host_adapter': adapter_metadata,
              'native_outputs': OUTPUT_KEYS, 'case_count': len(cases),
              'same_process_interleaved_repeat_checks': len(cases),
              'fresh_process_reproduction_verified': True,
              'query_mode': 1, 'feature_list_empty': True, 'cases': cases}
    destination = args.project/'tests/fixtures'/args.fixture_name
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, separators=(',', ':'))+'\n')
    print('Original raw terrain queries:', len(cases), '; interleaved repeats:', len(cases),
          '; styles:', sorted({case['style'] for case in cases}),
          '; original non-pointer table bytes verified:', resources['non_pointer_bytes_verified'])


if __name__ == '__main__':
    main()
