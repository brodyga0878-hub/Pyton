#!/usr/bin/env python3
"""Independent PE/capture comparison; opens an original only with explicit --exe."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import struct
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    proof = Path('validation/mission-statements-2026-11-19/statements-native-proof')
    meta = json.loads((proof / 'instruction-proof.json').read_text())
    raw = args.exe.read_bytes()
    sha = lambda data: hashlib.sha256(data).hexdigest()
    assert sha(raw) == meta['source_executable_sha256']
    pe = struct.unpack_from('<I', raw, 60)[0]
    opt = pe + 24
    image_base = struct.unpack_from('<I', raw, opt + 28)[0]
    table = opt + struct.unpack_from('<H', raw, pe + 20)[0]
    sections = [struct.unpack_from('<IIII', raw, table + i * 40 + 8)
                for i in range(struct.unpack_from('<H', raw, pe + 6)[0])]

    def read(va, size):
        for virtual_size, start, stored_size, offset in sections:
            if start <= va - image_base and va - image_base + size <= start + stored_size:
                return raw[offset + va - image_base - start:offset + va - image_base - start + size]
        raise ValueError('Unowned original PE span: ' + hex(va))

    checks = []
    instructions = []
    regions = []
    with tempfile.TemporaryDirectory(prefix='independent-statements-pe-') as temp:
        for name, procedure in meta['procedures'].items():
            for index, region in enumerate(procedure['code_regions']):
                code = bytes.fromhex(region['hex'])
                assert read(region['virtual_address'], len(code)) == code
                assert sha(code) == region['sha256']
                path = Path(temp) / ('body-' + name + '-' + str(index))
                path.write_bytes(code)
                output = subprocess.check_output([
                    'objdump', '-D', '-b', 'binary', '-m', 'i386', '-Mintel',
                    '--no-show-raw-insn', '--adjust-vma=' + hex(region['virtual_address']), str(path)
                ], text=True)
                rows = []
                for line in output.splitlines():
                    match = re.match(r'^\s*([0-9a-f]+):\s+([a-z].*)$', line)
                    if match:
                        rows.append((int(match[1], 16), match[2]))
                assert len(rows) == region['instruction_count']
                instructions.extend(rows)
                checks.append('raw-code-' + name + '-' + str(index))
                regions.append({'procedure': name, 'va_u32': region['virtual_address'],
                                'bytes': len(code), 'sha256': sha(code), 'instructions': len(rows)})
            for inline in procedure['inline_tables']:
                code = bytes.fromhex(inline['hex'])
                assert read(inline['virtual_address'], len(code)) == code
                assert sha(code) == inline['sha256']
                targets = list(struct.unpack('<' + str(inline['entry_count']) + 'I', code))
                assert targets == inline['target_original_va_u32']
                assert all(target in dict(instructions) for target in targets)
                checks.append('raw-inline-' + inline['symbol'])
    assert len(instructions) == 1509 and meta['procedures']['41']['instruction_count'] == 1430
    assert meta['procedures']['41']['inline_tables'][0]['entry_count'] == 61
    assert read(0x49aa16, 2) == b'\0\0'
    checks.append('empty-resource-two-zero-bytes')
    programs = json.loads(Path('data/ffe_mission_programs.json').read_text())
    vectors = bytes.fromhex(programs['regions']['vectors']['hex'])
    assert len(vectors) == 324 and read(0x48f07c, 324) == vectors
    checks.append('original-vector-resource-324-bytes')
    assert meta['root_original_va_u32'] == 0x64213c
    assert meta['root_fields'] == {'DATA_008861': 0xc8, 'DATA_008862': 0xcc,
        'DATA_008885': 0x10a, 'DATA_008896': 0x134, 'DATA_009133': 0x580c}
    assert meta['append_cursor_original_va_u32'] == 0x60bf44
    checks.append('source-owner-aliases')
    # These narrow byte interfaces corroborate transport normalization only.
    # No complete F304/F305/F306/F664 body is added to the seven-body proof.
    interfaces = []
    for name, va, expected in [
        ('F304-first-byte', 0x420162, '8a4508'),
        ('F305-first-byte', 0x4201a6, '8a4508'),
        ('F664-third-byte', 0x42cb73, '0fbe4510'),
        ('F306-first-signed-low-byte', 0x4201fa, '84db'),
    ]:
        code = read(va, len(bytes.fromhex(expected)))
        assert code.hex() == expected
        interfaces.append({'name': name, 'va_u32': va, 'hex': code.hex(), 'sha256': sha(code)})
    operands = [{'va_u32': va, 'instruction': operation} for va, operation in instructions
                if any(token in operation for token in ['0x60bf44', '0x48f07c', '0x48f080',
                    '0x48f084', '0x49aa16', '0x642204', '0x642208', '0x642246', '0x642270', '0x647948'])]
    report = {'schema': 'starfrontier-independent-statements-original-audit-v1',
        'checks': len(checks), 'failures': 0, 'controls': checks,
        'source_executable_sha256': sha(raw), 'regions': regions,
        'whole_bodies': 7, 'instructions': 1509, 'F41_instructions': 1430,
        'inline_targets': 61, 'vectors_bytes': 324, 'empty_resource_bytes': 2,
        'observed_alias_operands': operands, 'narrow_external_byte_interfaces': interfaces,
        'extra_whole_external_bodies_claimed': False, 'counted_in_functional_totals': False}
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'raw_checks': len(checks), 'failures': 0, 'whole_bodies': 7, 'instructions': 1509}))


if __name__ == '__main__':
    main()
