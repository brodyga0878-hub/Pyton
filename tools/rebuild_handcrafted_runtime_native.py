#!/usr/bin/env python3
"""Execute the authentic F878 handcoded-record conversion suffix on the host.

This intentionally excludes F878's procedural dispatch, F871, world naming,
SI conversion, clock and ephemerides. The suffix's original instruction stream
and packed arithmetic execute natively; Python supplies inputs and compares
repetitions, never computes expected record fields.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import random
import re
import struct
import subprocess
import sys
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
EXE_SHA = 'd919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA = 'd4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
LUT_SHA = '1bb88ff59cdc392b0c116d26a7f4ec1b9504fdfe42909f522d5ba9cbfcd02ef0'
SLOTS = 60
SIZE = 68
BUFFER = SLOTS * SIZE
SOURCE_BUFFER = (SLOTS + 1) * SIZE
COUNTERS = ['body_count_byte', 'port_count_byte', 'orbital_port_count_byte']
PACKET = 12 + SOURCE_BUFFER + BUFFER
OUTPUT = BUFFER + 16
MATH_NUMBERS = [1467, 1463, 1482, 1483, 1486, 1489, 1491]


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def record(code=3, parent=0, mass=599, orbit=4458427, name='Control'):
    row = bytearray(SIZE)
    struct.pack_into('<I', row, 0, mass)
    struct.pack_into('<IHHH', row, 4, 0xbdd3aa2e, parent, code, 84 if code == 35 else 120)
    struct.pack_into('<IH', row, 14, orbit, 0x7fff)
    struct.pack_into('<HHH', row, 32, 17, 0x8000, 293)
    row[38:38+len(name)+1] = name.encode('ascii') + b'\0'
    row[62] = 1
    row[63] = 3
    struct.pack_into('<HH', row, 64, 0xfefe, 0x8000)
    return bytes(row)


def cases():
    original = json.loads((PROJECT/'data/ffe_handcrafted_records.json').read_text())['records']
    worlds = json.loads((PROJECT/'data/ffe_worlds.json').read_text())
    result = []

    def add(title, templates, pattern=False, counters=(0, 0, 0), scope='synthetic register/field control'):
        if len(templates) > 59:
            raise ValueError('Controls reserve a destination slot for the authentic mass sentinel')
        dst = bytes((index*37 + 0x5b) & 255 for index in range(BUFFER)) if pattern else bytes(BUFFER)
        result.append({'name': title, 'scope': scope, 'templates_hex': [x.hex() for x in templates],
                       'destination_hex': [dst[i:i+SIZE].hex() for i in range(0, BUFFER, SIZE)],
                       'initial_counts': dict(zip(COUNTERS, counters))})

    for system in worlds['systems']:
        templates = [bytes.fromhex(original[str(row['global_index'])]['record_hex']) for row in system['objects']]
        for pattern in [False, True]:
            add(system['name_en'] + (' / patterned destination' if pattern else ' / zero destination'), templates,
                pattern, (254, 255, 255) if pattern else (0, 0, 0),
                'actual mapped handcoded system; 0.11.8 source data')
            result[-1]['system_id'] = int(system['system_id'])
            result[-1]['source_global_indices'] = [int(row['global_index']) for row in system['objects']]
    fallback = [bytes.fromhex(original[str(row['global_index'])]['record_hex']) for row in worlds['unmatched_fallback']]
    for pattern in [False, True]:
        add('Unmapped Riedquat diagnostic' + (' / patterned' if pattern else ' / zero'), fallback, pattern,
            (255, 254, 255) if pattern else (0, 0, 0),
            'actual three F875 fallback templates; NOT a newly mapped runtime system')
        result[-1]['source_global_indices'] = [int(row['global_index']) for row in worlds['unmatched_fallback']]

    for pattern in [False, True]:
        add('Empty suffix / ' + str(pattern), [], pattern, (255, 255, 255))
    edges = [1, 2, 0x7fff, 0x8000, 0xffff, 0x10000, 0x7fffffff, 0x80000000, 0xffffffff]
    kinds = [0, 1, 3, 13, 17, 22, 32, 33, 34, 35]
    for i, mass in enumerate(edges):
        for j, code in enumerate(kinds):
            root = record(22, 0, mass, 0, 'Parent')
            child = bytearray(record(code, 1, edges[(i+j) % len(edges)], edges[(i*3+j) % len(edges)], 'Control' + str(i)))
            struct.pack_into('<I', child, 4, edges[(i+j+1) % len(edges)])
            struct.pack_into('<H', child, 18, edges[(i+j+2) % len(edges)] & 65535)
            for at in [32, 34, 36, 58, 60, 66]:
                struct.pack_into('<H', child, at, edges[(i+j+at) % len(edges)] & 65535)
            child[62] = edges[(i+j+3) % len(edges)] & 255
            child[63] = 0xa5
            # Keep each original C string terminated before the source flag fields.
            add('Register edges %d / type%d' % (i, code), [root, bytes(child)], True,
                (i*31 & 255, j*31 & 255, (i+j)*31 & 255))
    rng = random.Random(0xf878)
    for count in [1, 2, 3, 17, 53, 59]:
        templates = []
        for index in range(count):
            parent = 0 if index == 0 else rng.randrange(index+1)
            code = 22 if index == 0 else rng.choice(kinds)
            row = bytearray(record(code, parent, rng.randrange(1, 0x100000000), rng.getrandbits(32), 'Chain%d' % index))
            struct.pack_into('<I', row, 4, rng.getrandbits(32))
            templates.append(bytes(row))
        add('Capacity/tree boundary %d' % count, templates, True, (255, 255, 255))
    return result


def packet(case):
    raw = bytearray(SOURCE_BUFFER)
    for index, value in enumerate(case['templates_hex']):
        raw[index*SIZE:(index+1)*SIZE] = bytes.fromhex(value)
    return struct.pack('<3I', *(case['initial_counts'][key] for key in COUNTERS)) + raw + b''.join(bytes.fromhex(x) for x in case['destination_hex'])


def make_assembly(source, table):
    sys.path.insert(0, str(PROJECT/'recovered-history/ground_harness/tools'))
    from native_reference import procedures
    original_start = source.index('FUNC_000878:')
    original_end = source.index('FUNC_000879:', original_start)
    branch_start = source.index('\n\tJUMP_003650:', original_start)
    suffix = source[branch_start:original_end]
    # This host entry establishes only the state already established by the
    # original handcoded dispatch; no replacement generator/helper is called.
    entry = '''FUNC_000878:
 push ebp
 mov ebp,esp
 add esp,byte -0x60
 push ebx
 push esi
 push edi
 mov esi,DATA_900001
 mov edi,DATA_900002
 mov ebx,DATA_008792
 mov dword [ebp-0x40],0
 jmp JUMP_003656
'''
    restricted = source[:original_start] + entry + suffix + source[original_end:]
    lines, hashes = procedures(restricted, [878] + MATH_NUMBERS)
    # Record the ORIGINAL suffix and full function independently of the host entry.
    original_hashes = dict(hashes)
    original_hashes['878'] = digest(source[original_start:original_end].encode())
    # NASM's bare data symbol is an immediate address; GAS Intel otherwise
    # interprets this ADD operand as a memory load (e.g. the bytes 'Sol').
    lines = [re.sub(r'^(add \w+,)(DATA_\d+)$', r'\1OFFSET FLAT:\2', line) for line in lines]
    code = '\n'.join(lines)
    assembly = '''.intel_syntax noprefix
.code64
.section .text
.global _start
''' + code + f'''
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:input
 add rsi,r8
 mov edx,{PACKET}
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,{PACKET}
 jne read_more
 cld
 mov esi,OFFSET FLAT:input+12
 mov edi,OFFSET FLAT:DATA_008792
 mov ecx,{SOURCE_BUFFER}
 rep movsb
 mov esi,OFFSET FLAT:input+12+{SOURCE_BUFFER}
 mov edi,OFFSET FLAT:DATA_900001
 mov ecx,{BUFFER}
 rep movsb
 mov DWORD PTR [DATA_900002],0
 mov eax,DWORD PTR [input]
 mov BYTE PTR [DATA_008847],al
 mov eax,DWORD PTR [input+4]
 mov BYTE PTR [DATA_008855],al
 mov eax,DWORD PTR [input+8]
 mov BYTE PTR [DATA_008856],al
 call FUNC_000878
 mov eax,DWORD PTR [DATA_900002]
 mov DWORD PTR [DATA_900001+{BUFFER}],eax
 movzx eax,BYTE PTR [DATA_008847]
 mov DWORD PTR [DATA_900001+{BUFFER+4}],eax
 movzx eax,BYTE PTR [DATA_008855]
 mov DWORD PTR [DATA_900001+{BUFFER+8}],eax
 movzx eax,BYTE PTR [DATA_008856]
 mov DWORD PTR [DATA_900001+{BUFFER+12}],eax
 mov esi,OFFSET FLAT:DATA_900001
 mov edx,{OUTPUT}
write_more:
 mov eax,1
 mov edi,1
 syscall
 test eax,eax
 jle write_failed
 add esi,eax
 sub edx,eax
 jnz write_more
 jmp next_case
write_failed:
 mov eax,60
 mov edi,72
 syscall
finished:
 mov eax,60
 xor edi,edi
 syscall
_memcpy:
 push rbp
 mov rbp,rsp
 push rdi
 push rsi
 mov edi,DWORD PTR [rbp+16]
 mov esi,DWORD PTR [rbp+24]
 mov ecx,DWORD PTR [rbp+32]
 mov eax,edi
 rep movsb
 pop rsi
 pop rdi
 pop rbp
 ret
.section .data
.align 8
DATA_007723: .quad FUNC_001467
DATA_007730: .quad FUNC_001463
DATA_007731: .quad FUNC_001483
DATA_007732: .quad FUNC_001491
DATA_007735: .quad FUNC_001486
DATA_007736: .quad FUNC_001489
DATA_007977:
''' + '\n'.join('.short ' + str(x) for x in struct.unpack('<2048H', table)) + f'''
.section .bss
.align 16
input: .zero {PACKET}
DATA_008792: .zero {SOURCE_BUFFER}
.set DATA_008793,DATA_008792+38
DATA_900001: .zero {OUTPUT}
DATA_900002: .zero 4
DATA_008847: .zero 4
DATA_008855: .zero 4
DATA_008856: .zero 4
.align 16
stack: .zero 65536
stack_end:
.section .note.GNU-stack,"",@progbits
'''
    return assembly, original_hashes, digest(suffix.encode())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--executable', type=Path, default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--output', type=Path, default=PROJECT/'tests/fixtures/handcrafted_runtime_native.json')
    args = parser.parse_args()
    original = args.executable.read_bytes()
    source_raw = args.source.read_bytes()
    if digest(original) != EXE_SHA or digest(source_raw) != ASM_SHA:
        raise ValueError('Unreviewed original executable/source')
    branch_at, branch_end = 0x2a6b1, 0x2a951
    if original[branch_at:branch_at+24] != bytes.fromhex('66837b0a230f843c0200008b034850ff1574135000598b17'):
        raise ValueError('Uploaded executable handcoded F878 entry differs')
    if original[0x2a933:0x2a93c] != bytes.fromhex('833b000f8575fdffff'):
        raise ValueError('Uploaded executable F878 sentinel loop differs')
    at = original.find(bytes.fromhex('0000a8050008cc09500ba60cdb0df70e'))
    table = original[at:at+4096]
    if at < 0 or digest(table) != LUT_SHA:
        raise ValueError('Original square-root lookup differs')
    assembly, hashes, suffix_hash = make_assembly(source_raw.decode(), table)
    rows = cases()
    ordered = rows + list(reversed(rows))
    packets = b''.join(packet(row) for row in ordered)
    with tempfile.TemporaryDirectory(prefix='ffe-f878-native-') as directory:
        work = Path(directory)
        (work/'f878.s').write_text(assembly)
        subprocess.run(['as', '--64', str(work/'f878.s'), '-o', str(work/'f878.o')], check=True)
        subprocess.run(['ld', '-m', 'elf_x86_64', str(work/'f878.o'), '-o', str(work/'f878')], check=True)
        results = [subprocess.run([str(work/'f878')], input=packets, stdout=subprocess.PIPE, check=True, timeout=30).stdout for _ in range(3)]
    if any(x != results[0] for x in results[1:]):
        raise ValueError('Fresh native processes disagree')
    output = results[0]
    if len(output) != OUTPUT * len(ordered):
        raise ValueError('Incomplete native suffix output')
    for index, row in enumerate(rows):
        raw = output[index*OUTPUT:(index+1)*OUTPUT]
        repeat = len(ordered)-1-index
        if raw != output[repeat*OUTPUT:(repeat+1)*OUTPUT]:
            raise ValueError('Reverse-order native repeat differs')
        count, body, port, orbital = struct.unpack_from('<4I', raw, BUFFER)
        if count != len(row['templates_hex']):
            raise ValueError('Native sentinel reached an unexpected source record')
        before = b''.join(bytes.fromhex(x) for x in row['destination_hex'])
        if raw[count*SIZE:count*SIZE+4] != bytes(4) or raw[count*SIZE+4:BUFFER] != before[count*SIZE+4:]:
            raise ValueError('Original suffix changed data beyond its four-byte mass sentinel')
        row['expected'] = {'ok': True, 'records_hex': [raw[i:i+SIZE].hex() for i in range(0, BUFFER, SIZE)],
                           'count': count, 'next_index': count,
                           'body_count_byte': body, 'port_count_byte': port, 'orbital_port_count_byte': orbital}
    result = {'schema': 1, 'revision': 'original-f878-handcoded-suffix-v1',
              'source_sha256': EXE_SHA, 'source_assembly_sha256': ASM_SHA,
              'source_procedure_hashes': hashes, 'original_suffix_sha256': suffix_hash,
              'uploaded_executable_suffix': {'offset': hex(branch_at), 'end_exclusive': hex(branch_end), 'sha256': digest(original[branch_at:branch_end])},
              'adapted_assembly_sha256': digest(assembly.encode()),
              'scope': 'Authentic F878 handcoded conversion suffix JUMP003650..657 and genuine packed arithmetic, with explicit pre-dispatch host entry. Not full F878 dispatch, procedural world generation, F871, SI units, clocks, ephemerides or Android x86 execution.',
              'host_adaptations': ['64-bit stack argument slots', 'all pointers and host stack below2GiB', 'equivalent C memcpy bytes', 'explicit domain-entry prologue instead of unexecuted F878 procedural dispatch'],
              'output_slots': SLOTS, 'maximum_active_templates': 59,
              'mapped_systems': 11, 'mapped_original_templates': 130, 'unmapped_fallback_templates': 3,
              'case_count': len(rows), 'same_process_reverse_repeat_checks': len(rows),
              'fresh_process_runs': 3, 'fresh_process_outputs_identical': True,
              'native_ordered_output_sha256': digest(output),
              'cases': rows}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, separators=(',', ':'))+'\n')
    print('Original F878 handcoded suffix:', len(rows), 'native cases; 11mapped systems/130templates +3unmapped controls; three fresh processes; reverse repeats agree')


if __name__ == '__main__':
    main()
