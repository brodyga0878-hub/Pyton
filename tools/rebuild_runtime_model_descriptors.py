#!/usr/bin/env python3
"""Extract original model descriptors used by the source system catalogue.

This is a byte extractor, not a geometry or physical-radius reconstruction.
All 149 original model-table slots through the last stellar factory model are
retained, including unrelated slots; runtime records select their own model.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import struct
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
EXE_SHA = 'd919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
TABLE_OFFSET = 0xba8fc
MODEL_COUNT = 149

def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()

def extract(raw: bytes) -> dict:
    if sha(raw) != EXE_SHA:
        raise ValueError('Unexpected original FIRSTENC.EXE hash')
    pe = struct.unpack_from('<I', raw, 60)[0]
    base = struct.unpack_from('<I', raw, pe + 52)[0]
    section_count = struct.unpack_from('<H', raw, pe + 6)[0]
    section_start = pe + 24 + struct.unpack_from('<H', raw, pe + 20)[0]
    sections = [struct.unpack_from('<4I', raw, section_start + i * 40 + 8)
                for i in range(section_count)]
    def offset(pointer: int, length: int) -> int:
        for _, address, size, file_offset in sections:
            delta = pointer - base - address
            if 0 <= delta and delta + length <= size:
                result = file_offset + delta
                if result + length <= len(raw):
                    return result
        raise ValueError('Unmapped original descriptor pointer ' + hex(pointer))
    models = {}
    for index in range(MODEL_COUNT):
        slot = TABLE_OFFSET + index * 4
        pointer = struct.unpack_from('<I', raw, slot)[0]
        at = offset(pointer, 68)
        descriptor = raw[at:at + 68]
        words = struct.unpack('<17I', descriptor)
        models[str(index)] = {
            'model_index': index, 'table_slot_executable_offset': slot,
            'original_pointer_u32': pointer, 'descriptor_executable_offset': at,
            'descriptor_hex': descriptor.hex(), 'descriptor_sha256': sha(descriptor),
            'scale_raw': words[5], 'scale2_raw': words[6],
            'model_scale_raw': words[5] + words[6] - 8,
            'outer_radius_u32': words[11], 'inner_radius_u32': words[12],
            'outer_radius_s16': struct.unpack_from('<h', descriptor, 44)[0],
            'inner_radius_s16': struct.unpack_from('<h', descriptor, 48)[0],
            'source_flags_u32': words[9], 'physical_spec_pointer_u32': words[14],
        }
    table = raw[TABLE_OFFSET:TABLE_OFFSET + MODEL_COUNT * 4]
    return {
        'schema': 1, 'source_variant': 'original-runtime-model-descriptors-v1',
        'source_sha256': EXE_SHA, 'model_count': MODEL_COUNT,
        'model_table_executable_offset': TABLE_OFFSET,
        'model_table_hex': table.hex(), 'model_table_sha256': sha(table),
        'scope': 'Original 68-byte descriptors for model-table slots0..148. '
                 'Descriptor spheres are bounds, not natural terrain radii. '
                 'No mesh programs, modern planetary values or physics are substituted.',
        'models': models,
    }

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe', type=Path, default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--output', type=Path, default=PROJECT / 'data/ffe_runtime_model_descriptors.json')
    args = parser.parse_args()
    data = extract(args.exe.read_bytes())
    encoded = (json.dumps(data, ensure_ascii=False, indent=2) + '\n').encode()
    args.output.write_bytes(encoded)
    print(json.dumps({'models': data['model_count'], 'resource_sha256': sha(encoded),
                      'model_table_sha256': data['model_table_sha256']}))

if __name__ == '__main__':
    main()
