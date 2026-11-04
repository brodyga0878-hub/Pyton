#!/usr/bin/env python3
"""Host-only F1467 controls from reviewed original asm and original EXE bytes.

This executable is a development reference. Android uses pure GDScript and has
no x86/emulator dependency. The only adaptations are NASM to GAS spelling and
64-bit stack-slot width; original integer instructions and branches are kept.
"""
import argparse
import hashlib
import json
import math
import random
import re
import struct
import subprocess
import tempfile
from pathlib import Path

SOURCE_SHA = 'd919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA = 'd4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
LUT_SHA = '1bb88ff59cdc392b0c116d26a7f4ec1b9504fdfe42909f522d5ba9cbfcd02ef0'
SIGNATURE = bytes.fromhex('0000a8050008cc09500ba60cdb0df70e')
NUMBERS = [1467, 1463, 1482, 1483, 1486, 1489, 1491, 1515]
OPERATIONS = ['integer_sqrt', 'from_uint', 'multiply', 'divide', 'add',
              'to_integer', 'square_root', 'fixed_multiply', 'period', 'shift']


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def procedure(source, number):
    start = source.index(f'FUNC_{number:06d}:')
    end = start+1+re.search(r'^FUNC_\d+:', source[start+1:], re.M).start()
    block = source[start:end]
    adapted = []
    for line in block.splitlines():
        line = line.split(';')[0].strip()
        if not line:
            continue
        line = re.sub(r'\b(?:near|short)\s+', '', line)
        line = re.sub(r'\b(byte|word|dword)\s*\[', lambda m: m[1].upper()+' PTR [', line)
        line = re.sub(r'\b(?:byte|word|dword)\s+(?=[+\-0-9])', '', line)
        line = re.sub(r'\[ebp\+0x([0-9a-f]+)\]',
                      lambda m: '[rbp+%d]' % (16+((int(m[1],16)-8)//4)*8+(int(m[1],16)-8)%4), line)
        line = line.replace('[ebp', '[rbp').replace('mov ebp,esp', 'mov rbp,rsp')
        if line.startswith(('push ', 'pop ')):
            for old, new in [('ebp','rbp'),('ebx','rbx'),('eax','rax'),('ecx','rcx'),('edx','rdx')]:
                line = re.sub(r'\b'+old+r'\b', new, line)
        line = line.replace('call [DATA_007723]', 'call FUNC_001467')
        adapted.append(line)
    return '\n'.join(adapted), digest(block.encode())


def inputs():
    values = {0, 1, 2, 3, 4, 0xffffffff, 0x80000000, 0x7fffffff}
    ranges = [(0x400, 3), (0x4000, 7), (0x40000, 11), (0x400000, 15),
              (0x4000000, 17), (0x10000000, 19), (0x40000000, 21)]
    # Every small input, every address transition in every LUT branch, and
    # values immediately around all eight unsigned branch thresholds.
    values.update(range(0x400))
    for begin, shift in ranges:
        for delta in range(-3, 4):
            values.add(begin+delta)
        for index in range(2048):
            at = index << shift
            if at >= begin:
                values.update((at-1, at, at+1))
    rng = random.Random(0x1467)
    values.update(rng.randrange(1 << 32) for _ in range(16384))
    return sorted(value for value in values if 0 <= value <= 0xffffffff)


def packed_inputs():
    rng = random.Random(0x1482)
    controls = []
    special = [0, 1, 2, 0xffff, 0x10000, 0x7fffffff, 0x80000000,
               0xffffffff, 0xfff90000, 0x00014000, 0x0001c000, 0x007f7fff]
    values = special+[rng.randrange(1 << 32) for _ in range(2048)]
    for value in values:
        for operation in [1, 5, 6]:
            controls.append((operation, value, 0))
    for operation in [2, 3, 4, 7, 8, 9]:
        controls.extend((operation, first, second) for first in special for second in special)
        controls.extend((operation, rng.randrange(1 << 32), rng.randrange(1 << 32)) for _ in range(4096))
    # Focus original exponent alignment and x86 shift-count boundaries.
    for first_exp in [-32768, -100, -33, -32, -31, -7, 0, 1, 15, 31, 32, 127, 32767]:
        for second_exp in [first_exp-32, first_exp-31, first_exp, first_exp+31, first_exp+32]:
            for first_mant in [-32768, -16384, -1, 0, 1, 16383, 16384, 32767]:
                for second_mant in [-32768, -16384, 0, 16384, 32767]:
                    first = ((first_exp&65535)<<16)|(first_mant&65535)
                    second = ((second_exp&65535)<<16)|(second_mant&65535)
                    controls.append((4, first, second))
    return controls


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--asm', type=Path, default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--exe', type=Path, default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--output', type=Path, default=Path('tests/fixtures/rebuilt_ffe_math_native.json'))
    args = parser.parse_args()
    original = args.exe.read_bytes()
    asm_raw = args.asm.read_bytes()
    if digest(original) != SOURCE_SHA or digest(asm_raw) != ASM_SHA:
        raise ValueError('Original source provenance mismatch')
    offset = original.find(SIGNATURE)
    if offset < 0 or original.find(SIGNATURE, offset+1) >= 0:
        raise ValueError('Missing or ambiguous original square-root table')
    table = original[offset:offset+4096]
    if digest(table) != LUT_SHA:
        raise ValueError('Original square-root table mismatch')
    chunks = [procedure(asm_raw.decode(), number) for number in NUMBERS]
    code = '\n'.join(first for first, _ in chunks)
    block_shas = {str(number): chunk[1] for number, chunk in zip(NUMBERS, chunks)}
    assembly = '''.intel_syntax noprefix
.code64
.section .text
.global _start
'''+code+'''
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:input
 add rsi,r8
 mov edx,12
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,12
 jne read_more
 mov eax,DWORD PTR [input+8]
 push rax
 mov eax,DWORD PTR [input+4]
 push rax
 mov eax,DWORD PTR [input]
 call QWORD PTR [rax*8+native_dispatch]
 add rsp,16
 mov DWORD PTR [output],eax
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,4
 syscall
 jmp next_case
finished:
 mov eax,60
 xor edi,edi
 syscall
native_shift:
 push rbp
 mov rbp,rsp
 mov dx,WORD PTR [rbp+24]
 add WORD PTR [rbp+18],dx
 mov eax,DWORD PTR [rbp+16]
 pop rbp
 ret
native_period:
 push rbp
 mov rbp,rsp
 push QWORD PTR [rbp+24]
 push QWORD PTR [rbp+16]
 push QWORD PTR [rbp+16]
 push QWORD PTR [rbp+16]
 call FUNC_001482
 add rsp,16
 push rax
 call FUNC_001482
 add rsp,16
 push rax
 call FUNC_001483
 add rsp,16
 push rax
 call FUNC_001463
 add rsp,8
 mov edx,eax
 movsx eax,ax
 imul eax,eax,0x5edb
 sar eax,0xf
 mov dx,ax
 mov eax,edx
 pop rbp
 ret
.section .rodata
.align 8
native_dispatch:
.quad FUNC_001467,FUNC_001489,FUNC_001482,FUNC_001483,FUNC_001486
.quad FUNC_001491,FUNC_001463,FUNC_001515,native_period,native_shift
DATA_007977:
'''+ '\n'.join('.short '+str(value) for value in struct.unpack('<2048H', table))+'''
.section .bss
.align 16
input: .zero 12
output: .zero 4
.align 16
stack: .zero 65536
stack_end:
.section .note.GNU-stack,"",@progbits
'''
    values = inputs()
    packed_controls = packed_inputs()
    packets = [(0, value, 0) for value in values]+packed_controls
    with tempfile.TemporaryDirectory(prefix='ffe-math-reference-') as work:
        work = Path(work)
        (work/'math.S').write_text(assembly)
        subprocess.run(['gcc', '-nostdlib', '-no-pie', '-o', str(work/'math'), str(work/'math.S')], check=True)
        response = subprocess.run([str(work/'math')], input=b''.join(struct.pack('<III', *packet) for packet in packets),
                                  stdout=subprocess.PIPE, check=True).stdout
    if len(response) != len(packets)*4:
        raise ValueError('Incomplete native F1467 response')
    outputs = struct.unpack('<%dI' % len(packets), response)
    real_controls = []
    for exponent in [-32768, -1100, -1075, -1074, -1073, -1060, -1059, -1022,
                     -100, -7, 0, 1, 15, 31, 63, 100, 1023, 1024, 1038, 1039, 32767]:
        for mantissa in [-32768, -16384, -1, 0, 1, 16383, 16384, 32767]:
            packed = ((exponent&65535)<<16)|(mantissa&65535)
            try:
                expected = math.ldexp(mantissa, exponent-15)
            except OverflowError:
                expected = math.copysign(math.inf, mantissa)
            real_controls.append([packed, struct.pack('<d', expected).hex()])
    payload = {'schema': 1, 'scope': 'Independent native original F1467 controls; reconstructed runtime separately tested.',
               'jjffe_commit': '7e540341d4e09aa3c92877b87d49e7f2c143ad8d',
               'exe_sha256': SOURCE_SHA, 'ffe_asm_sha256': ASM_SHA,
               'function_block_sha256': block_shas, 'sqrt_table_offset': hex(offset),
               'sqrt_table_sha256': LUT_SHA, 'random_seed': '0x1467',
               'operations': OPERATIONS,
               'real_scope': 'Independent binary64 display conversion of signed16(M)*2**(signed16(E)-15), checked using Python math.ldexp, not an original floating-point execution claim.',
               'real_cases': real_controls,
               'period_scope': 'Composition of original F1482/F1483/F1463 and the F879/F882 mantissa factor, not execution of the complete body factory.',
               'cases': [[first, second] for first, second in zip(values, outputs)],
               'packed_cases': [[*control, expected] for control, expected in zip(packed_controls, outputs[len(values):])]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, separators=(',', ':'))+'\n')
    print(json.dumps({'fixture': str(args.output), 'sqrt_cases': len(values), 'packed_cases': len(packed_controls),
                      'sha256': digest(args.output.read_bytes())}))


if __name__ == '__main__':
    main()
