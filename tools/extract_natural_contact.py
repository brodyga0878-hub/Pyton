#!/usr/bin/env python3
"""Extract bounded F576 player-shape data from the uploaded FIRSTENC.EXE.

The three complete backwards child lists are original bytes. Natural parent
programs/vertices remain in the immutable ground/fuel resources; this resource
indexes and validates those bytes instead of creating a second terrain table.
Source fragment hashes are provenance, not a DOS/JJFFE equivalence claim.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import struct

from extract_system_information import ASM_SHA, COMMIT, DATA_SHA, EXE_SHA, sha
from rebuild_ground_surface_native import Image, block

PROJECT = Path(__file__).resolve().parents[1]
SHIP_MODELS = (24, 38, 15)
NATURAL_MODELS = tuple(range(117, 149))
IMMUTABLE_RESOURCES = {
    'ffe_runtime_model_descriptors': 'cf9c673c2bba22f0c865e77e3a7ceed5497053cdb444b80f31d7439176446818',
    'ffe_hyperdrive': '17fe376bf480aa34fe8278193c558a8a30d198fa06354caf3c9692de34b1cf47',
    'ffe_fuel': '4d35dfd7047e7c3878ab92e25dcd9fde67697d7a93d46e53e57d0e1c7b71f14f',
    'ffe_ground_collision': '2dbf44a94422907b1bb29b34df1d795cef819cecf267b1591f3d82ea6326d018',
}
EXPECTED_CHILDREN = {
    24: (0x8a2a8, '0000', []),
    38: (0x8d894, '00007805903379059033', [(13200, 1401), (13200, 1400)]),
    15: (0x88dea, '0000840c803e', [(16000, 3204)]),
}
PROCEDURES = (576, 579, 580, 581, 582, 583, 1495, 1533)


def source_bytes(executable: bytes, at: int, count: int) -> bytes:
    if at < 0 or count < 0 or at + count > len(executable):
        raise ValueError('Truncated original byte window')
    return executable[at:at + count]


def decode_children(executable: bytes, collision_file_offset: int,
                    max_records: int = 32) -> dict:
    """Read F576's ptr-2 displacement, ptr-4 encoded axis/radius, then repeat.

    The zero displacement terminator occupies two bytes and has no following
    encoded word. Records are returned in traversal order, opposite file order.
    """
    if max_records < 0:
        raise ValueError('Invalid child-list bound')
    cursor = collision_file_offset
    records = []
    while True:
        cursor -= 2
        displacement_at = cursor
        displacement = struct.unpack('<h', source_bytes(executable, cursor, 2))[0]
        if displacement == 0:
            break
        if len(records) >= max_records:
            raise ValueError('Unterminated or oversized original child list')
        cursor -= 2
        encoded = struct.unpack('<h', source_bytes(executable, cursor, 2))[0]
        axis = (encoded & 6) >> 1
        if axis == 3:
            raise ValueError('Unsupported original child axis6 retains prior local matrix')
        records.append({
            'radius_s16': displacement,
            'displacement_s16': displacement,
            'axis_radius_encoded_s16': encoded,
            'axis_index': axis,
            'axis_negative': bool(encoded & 1),
            'radius_word_u16': encoded & 0xfff8,
            'displacement_file_offset': displacement_at,
            'axis_radius_file_offset': cursor,
        })
    raw = source_bytes(executable, cursor, collision_file_offset - cursor)
    return {'file_offset': cursor, 'byte_length': len(raw), 'hex': raw.hex(),
            'sha256': sha(raw), 'terminator_file_offset': cursor,
            'terminator_s16': 0, 'records': records}


def decode_natural_program(executable: bytes, collision_file_offset: int) -> dict:
    """Validate the complete reviewed natural F582/F581 stream and its tail."""
    at = collision_file_offset
    prefix = source_bytes(executable, at, 3)
    if prefix not in (bytes.fromhex('1082ff'), bytes.fromhex('1083ff')):
        raise ValueError('Unreviewed natural terrain primitive')
    # F581 passes the six-byte terrain header and zero-terminated 16-byte
    # feature records to F1876. Its return pointer precedes F582's tail.
    end = at + 9
    features = []
    while struct.unpack('<H', source_bytes(executable, end, 2))[0]:
        if len(features) >= 256:
            raise ValueError('Unbounded original natural feature list')
        features.append({'file_offset': end, 'hex': source_bytes(executable, end, 16).hex()})
        end += 16
    if source_bytes(executable, end + 2, 5) != bytes.fromhex('5080000000'):
        raise ValueError('Unreviewed natural collision tail')
    raw = source_bytes(executable, at, end + 7 - at)
    return {
        'collision_file_offset': at, 'byte_length': len(raw),
        'sha256': sha(raw), 'opcode_u8': prefix[0],
        'primitive_flags_u8': prefix[1], 'primitive_selector_u8': prefix[2],
        'terrain_payload_file_offset': at + 3,
        'terrain_payload_byte_length': end + 2 - (at + 3),
        'terrain_style_raw': executable[at + 7],
        'feature_count': len(features),
        'feature_offsets': [row['file_offset'] for row in features],
        'feature_terminator_file_offset': end,
        'tail_file_offset': end + 2, 'tail_hex': '5080000000',
        'scope': 'One original natural terrain primitive and its original collision tail; no city/model VM claim.',
    }


def _descriptor(executable: bytes, image: Image, model: int, old: dict) -> tuple[int, bytes, tuple]:
    slot = 0xba8fc + model * 4
    pointer = struct.unpack('<I', source_bytes(executable, slot, 4))[0]
    at = image.offset(pointer, 68)
    raw = source_bytes(executable, at, 68)
    if old['descriptor_executable_offset'] != at or old['descriptor_hex'] != raw.hex() or old['descriptor_sha256'] != sha(raw):
        raise ValueError('Immutable runtime descriptor differs ' + str(model))
    return at, raw, struct.unpack('<17I', raw)


def _shift_signed(value: int, exponent: int) -> int:
    return value << exponent if exponent >= 0 else value >> -exponent


def ship_rows(executable: bytes, descriptors: dict, hyperdrive: dict) -> dict:
    image = Image(executable)
    result = {}
    for model in SHIP_MODELS:
        at, raw, words = _descriptor(executable, image, model, descriptors['models'][str(model)])
        collision_at = image.offset(words[13], 8)
        prefix = source_bytes(executable, collision_at, 8)
        children = decode_children(executable, collision_at)
        expected_at, expected_hex, expected_pairs = EXPECTED_CHILDREN[model]
        if (children['file_offset'], children['hex'], [(r['radius_s16'], r['axis_radius_encoded_s16']) for r in children['records']]) != (expected_at, expected_hex, expected_pairs):
            raise ValueError('Unreviewed original player child list ' + str(model))
        spec_at = image.offset(words[14], 24)
        spec = source_bytes(executable, spec_at, 24)
        old = hyperdrive['ship_specs'][str(model)]
        if old['descriptor_file_offset'] != at or old['spec_file_offset'] != spec_at or old['original_spec_pointer_u32'] != words[14] or old['spec_hex'] != spec.hex() or old['spec_sha256'] != sha(spec):
            raise ValueError('Immutable physical specification differs ' + str(model))
        exponent = words[5] + words[6] - 8
        outer = struct.unpack_from('<h', raw, 0x2c)[0]
        inner = struct.unpack_from('<h', raw, 0x30)[0]
        result[str(model)] = {
            'model_index': model, 'name_en': old['name_en'],
            'descriptor_file_offset': at, 'descriptor_hex': raw.hex(), 'descriptor_sha256': sha(raw),
            'physical_spec_pointer_u32': words[14], 'physical_spec_file_offset': spec_at,
            'physical_spec_hex': spec.hex(), 'physical_spec_sha256': sha(spec),
            'scale_raw': words[5], 'scale2_raw': words[6],
            'outer_radius_raw': words[11], 'inner_radius_raw': words[12],
            'f1533_radii': {'exponent_s32': exponent,
                            'outer_s64': _shift_signed(outer, exponent),
                            'inner_s64': _shift_signed(inner, exponent)},
            'collision_pointer_u32': words[13], 'collision_file_offset': collision_at,
            'collision_prefix_hex': prefix.hex(), 'collision_prefix_sha256': sha(prefix),
            'collision_prefix_scope': 'Only first8 source bytes; F576 reads player shape from preceding_children, not this ship collision program.',
            'initial_object_flags_14c_u8': ((words[9] >> 4) & 7) | (0x80 if prefix[0] else 0),
            'preceding_children': children,
        }
    if [result[str(m)]['f1533_radii']['inner_s64'] for m in SHIP_MODELS] != [5200, 9600, 1920]:
        raise ValueError('Unreviewed original F1533 player radii')
    return result


def parent_rows(executable: bytes, descriptors: dict, ground: dict, fuel: dict) -> dict:
    image = Image(executable)
    result = {}
    for model in NATURAL_MODELS:
        at, raw, words = _descriptor(executable, image, model, descriptors['models'][str(model)])
        source_name = 'ffe_ground_collision' if model <= 133 else 'ffe_fuel'
        old = (ground if model <= 133 else fuel)['models'][str(model)]
        stream_key = 'collision_bytes_hex' if model <= 133 else 'collision_stream_hex'
        stream_at_key = 'collision_offset' if model <= 133 else 'collision_stream_offset'
        collision_at = image.offset(words[13], 3)
        program = decode_natural_program(executable, collision_at)
        vertices_at = image.offset(words[1], 24)
        vertices = source_bytes(executable, vertices_at, 24)
        if old['descriptor_hex'] != raw.hex() or old['descriptor_sha256'] != sha(raw) or old['vertices_hex'] != vertices.hex() or old['vertices_sha256'] != sha(vertices) or int(old['vertices_offset'], 16) != vertices_at:
            raise ValueError('Immutable natural descriptor/vertices differ ' + str(model))
        if int(old[stream_at_key], 16) != collision_at or old[stream_key] != source_bytes(executable, collision_at, program['byte_length']).hex():
            raise ValueError('Immutable complete natural program differs ' + str(model))
        result[str(model)] = {
            'model_index': model, 'resource': source_name, 'model_path': 'models.' + str(model),
            'descriptor_file_offset': at, 'descriptor_sha256': sha(raw),
            'vertices_file_offset': vertices_at, 'vertices_sha256': sha(vertices),
            'descriptor_zoom_s32': words[5] + words[6],
            'non_spherical_source_model': model == 117,
            'program': program,
        }
    return result


def extract(executable: bytes, asm_bytes: bytes, data_bytes: bytes,
            previous_resources: dict[str, bytes]) -> dict:
    if (sha(executable), sha(asm_bytes), sha(data_bytes)) != (EXE_SHA, ASM_SHA, DATA_SHA):
        raise ValueError('Pinned DOS/JJFFE source SHA256 mismatch')
    if set(previous_resources) != set(IMMUTABLE_RESOURCES) or any(sha(previous_resources[key]) != expected for key, expected in IMMUTABLE_RESOURCES.items()):
        raise ValueError('Immutable previous resource differs')
    previous = {name: json.loads(value) for name, value in previous_resources.items()}
    descriptors = previous['ffe_runtime_model_descriptors']
    if descriptors.get('source_sha256') != EXE_SHA or descriptors.get('model_count') != 149 or set(descriptors.get('models', {})) != {str(n) for n in range(149)}:
        raise ValueError('Incomplete original runtime descriptor table')
    source = asm_bytes.decode().replace('\r\n', '\n')
    return {
        'schema': 1, 'profile': 'dos-firstenc-natural-contact-v1',
        'source_sha256': EXE_SHA, 'source_assembly_sha256': ASM_SHA,
        'source_data_sha256': DATA_SHA, 'source_commit': COMMIT,
        'immutable_resources': {name + '_sha256': value for name, value in IMMUTABLE_RESOURCES.items()},
        'ship_models': ship_rows(executable, descriptors, previous['ffe_hyperdrive']),
        'natural_parent_programs': parent_rows(executable, descriptors, previous['ffe_ground_collision'], previous['ffe_fuel']),
        'pinned_source_procedure_sha256': {str(n): sha(block(source, n).encode()) for n in PROCEDURES},
        'source_newlines_normalized_for_fragment_hashes': True,
        'proof_scope': 'Original data extraction and pinned JJFFE source fragment provenance. Native instruction execution/equivalence belongs to the separate reviewed native fixture; no full F576..F583/DOS-JJFFE equivalence is asserted here.',
        'field_layout': {'object_bytes': 338, 'descriptor_bytes': 68, 'physical_spec_bytes': 24,
                         'object_model_u32': 0x82, 'outer_s64': 0x138, 'inner_s64': 0x140,
                         'collision_flags_u8': 0x14c, 'descriptor_scale_u32': 0x14,
                         'descriptor_scale2_u32': 0x18, 'descriptor_collision_pointer_u32': 0x34,
                         'descriptor_physical_spec_pointer_u32': 0x38},
        'child_stream_contract': {
            'traversal': 'Predecrement descriptor+0x34 pointer by2; signed16 zero terminates. Nonzero signed16 is displacement/radius operand inEAX. Predecrement by2 again for encoded axis/radius inEBX; repeat backwards.',
            'axis': '(encoded_word&6):0 first matrix row,2 second,4 third; bit0 negates each signed32 element before SAR16 and multiply. Axis6 is not present in these three original lists.',
            'radius': 'EBX=(encoded_word&0xfff8)<<15 modulo32; if23-descriptor_scale is nonzero, SAR by x86-masked count. EAX displacements are applied to the original caller relative vector for every child.',
            'f1533_bounds': 'Signed16 descriptor+2C/+30 scaled by descriptor+14+18-8 using F1495; bounds are source units, not inferred SI radii.',
            'natural_resources': 'Reuse exact immutable ground117..133 and fuel134..148 descriptors, firstfour source vertices and complete natural collision programs. No modern planet radii substituted.',
            'model117': 'Original nonspherical layout retained. Caller-specific correction and DOS/JJFFE instruction variants require separate evidence; no spherical conversion or generic caller equivalence.',
            'limits': ['No city/ship-parent/nested-model collision VM.', 'No damage/landing/docking policy or full live original object bank.'],
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe', type=Path, default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--source', type=Path, default=Path('/workspace/ffe-upstream/jjffe'))
    parser.add_argument('--resources', type=Path, default=PROJECT / 'data')
    parser.add_argument('--output', type=Path, default=PROJECT / 'data/ffe_natural_contact.json')
    args = parser.parse_args()
    result = extract(args.exe.read_bytes(), (args.source / 'ffe.asm').read_bytes(),
                     (args.source / 'ffedat.asm').read_bytes(),
                     {name: (args.resources / (name + '.json')).read_bytes() for name in IMMUTABLE_RESOURCES})
    encoded = (json.dumps(result, ensure_ascii=False, indent=2) + '\n').encode()
    args.output.write_bytes(encoded)
    print(json.dumps({'resource_sha256': sha(encoded), 'ship_models': len(result['ship_models']),
                      'natural_parent_programs': len(result['natural_parent_programs'])}))


if __name__ == '__main__':
    main()
