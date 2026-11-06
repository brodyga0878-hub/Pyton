#!/usr/bin/env python3
"""Extract model112 and execute independent original leaf-vertex controls.

This is an offline feasibility fixture. It does not enable landability, change
runtime resources or claim that a render triangle is the original collider.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
import rebuild_model_vertices_native as native
from rebuild_original_data import load_extractors


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe', type=Path, default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--source', type=Path, default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--output', type=Path,
                        default=PROJECT / 'tests/fixtures/source_asteroid_mesh_spike.json')
    args = parser.parse_args()
    raw = args.exe.read_bytes()
    asm_raw = args.source.read_bytes()
    if sha(raw) != native.EXE_SHA or sha(asm_raw) != native.ASM_SHA:
        raise ValueError('Unreviewed executable or assembly revision')

    extractors = load_extractors()
    assets = extractors['extract_world_models'].extract(args.exe, [112])
    if list(assets['models']) != ['112']:
        raise ValueError('Model112 closure unexpectedly changed')
    asset = assets['models']['112']
    if set(asset['opcodes']) != {0, 3, 4, 6}:
        raise ValueError('Unexpected model112 render-program domain')

    image = extractors['extract_ship_registry'].Image(raw)
    at = asset['descriptor_offset']
    words = struct.unpack_from('<17I', raw, at)
    collision_at = image.offset(words[13], 1)
    vertices_at = image.offset(words[1], 1)
    if vertices_at - collision_at != 42:
        raise ValueError('Model112 collision boundary changed')
    collision = raw[collision_at:vertices_at]
    if not collision.startswith(bytes.fromhex('d080')) or not collision.endswith(bytes.fromhex('50800000')):
        raise ValueError('Model112 is not the reviewed plane-volume stream')
    spec_at = image.offset(words[14], 24)

    # Only this imported oracle instance changes its selection. The original
    # source tool and its existing reference fixture remain untouched.
    native.LEAVES = [112]
    models = native.original_models(raw)
    contexts = native.contexts()[::3]  # Four Q31 matrices; no irrelevant door repeats.
    text, hashes = native.assembly(args.source.read_text())
    packets = [native.packet(models[112], context) for context in contexts]
    with tempfile.TemporaryDirectory(prefix='source-asteroid112-native-') as directory:
        work = Path(directory)
        (work / 'native.s').write_text(text)
        subprocess.run(['as', '--64', '-o', str(work / 'native.o'), str(work / 'native.s')], check=True)
        subprocess.run(['ld', '-o', str(work / 'native'), str(work / 'native.o')], check=True)
        runs = [subprocess.run([str(work / 'native')], input=b''.join(packets),
                               capture_output=True, check=True).stdout for _ in range(3)]
        if len(set(runs)) != 1 or len(runs[0]) != len(contexts) * native.OUTPUT:
            raise ValueError('Unstable or truncated native vertex output')
        reverse = subprocess.run([str(work / 'native')], input=b''.join(reversed(packets)),
                                 capture_output=True, check=True).stdout
        expected_reverse = b''.join(runs[0][i * native.OUTPUT:(i + 1) * native.OUTPUT]
                                    for i in reversed(range(len(contexts))))
        if reverse != expected_reverse:
            raise ValueError('Native state leaked between cases')

    cases = []
    for index, context in enumerate(contexts):
        output = runs[0][index * native.OUTPUT:(index + 1) * native.OUTPUT]
        if struct.unpack_from('<2Q', output, 776) != (native.GUARD, native.GUARD):
            raise ValueError('Native output guard changed')
        count = models[112]['vertex_count']
        if struct.unpack_from('<I', output, 792)[0] != count:
            raise ValueError('Native vertex count changed')
        cases.append({'context': context,
                      'vertices_local_raw': [list(struct.unpack_from('<3i', output, j * 12))
                                             for j in range(count)],
                      'final_random_state_u32': list(struct.unpack_from('<2I', output, 768))})

    result = {
        'schema': 1,
        'revision': 'source-asteroid112-offline-spike-v1',
        'scope': 'Exact model112 program/descriptor/vertices/plane-volume bytes plus actual original F1470/F1478 unprojected native vertex outputs. No F574/F582/F583 native collider execution, live landing, mobile renderer, mining or comet implementation claim.',
        'source_executable_sha256': sha(raw),
        'source_assembly_sha256': sha(asm_raw),
        'source_commit': '7e540341d4e09aa3c92877b87d49e7f2c143ad8d',
        'source_procedure_hashes': hashes,
        'adapted_native_assembly_sha256': sha(text.encode()),
        'native_ordered_output_sha256': sha(runs[0]),
        'native_fresh_process_runs': 3,
        'native_reverse_repeat_count': len(contexts),
        'native_guard_canaries_unchanged': True,
        'assets': assets,
        'physical_specification_pointer_u32': words[14],
        'physical_specification_executable_offset': spec_at,
        'physical_specification_first24_hex': raw[spec_at:spec_at + 24].hex(),
        'collision_executable_offset': collision_at,
        'collision_bytes_hex': collision.hex(),
        'collision_bytes_sha256': sha(collision),
        'collision_kind': 'F582 plane-volume groups evaluated by F583; no F581 heightfield marker',
        'cases': cases,
        'runtime_enabled': False,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'fixture': str(args.output.relative_to(PROJECT)),
                      'native_contexts': len(cases),
                      'native_vertex_points': sum(len(case['vertices_local_raw']) for case in cases),
                      'fixture_sha256': sha(args.output.read_bytes()),
                      'runtime_enabled': False}))


if __name__ == '__main__':
    main()
