#!/usr/bin/env python3
"""Native source controls for an explicitly adapted, fixed-probe terrain policy.

The source query depends on observer distance and detail. A stable body-fixed
provider must choose both. This research policy uses a fixed 5/4 static-axis
radius and source graphics level 12; it preserves unitless source relief and
does not establish the original physical radius or SI scale.
"""
import argparse
import hashlib
import itertools
import json
import math
import struct
import subprocess
import tempfile
from pathlib import Path

import build_terrain_game_query_reference as game

ROOT = Path(__file__).resolve().parents[1]
UNIFORM_MODELS = list(range(118, 134))


def uid_representatives(project):
    """Use actual original body UID/model pairs wherever source controls exist."""
    result = {}
    handcrafted_path = project/'data/ffe_handcrafted_records.json'
    handcrafted = json.loads(handcrafted_path.read_text())
    for slot, row in handcrafted['records'].items():
        model = row['model_index']
        if model in UNIFORM_MODELS and model not in result:
            result[model] = {'seed': row['seed_u32'], 'kind': 'original_F875_record',
                             'path': 'data/ffe_handcrafted_records.json', 'slot': int(slot),
                             'name_en': row['name_en'], 'record_hex': row['record_hex']}
    for name in ['inhabited_system_reference', 'special_system_reference']:
        path = project/f'tests/fixtures/{name}.json'
        document = json.loads(path.read_text())
        for case_index, case in enumerate(document['cases']):
            for record_index, raw_hex in enumerate(case['result']['records']):
                raw = bytes.fromhex(raw_hex)
                model = struct.unpack_from('<H', raw, 12)[0]
                if model in UNIFORM_MODELS and model not in result:
                    result[model] = {'seed': struct.unpack_from('<I', raw, 4)[0],
                                     'kind': 'original_generator_record',
                                     'path': f'tests/fixtures/{name}.json',
                                     'case_index': case_index, 'record_index': record_index,
                                     'record_hex': raw_hex}
    for model in UNIFORM_MODELS:
        result.setdefault(model, {'seed': 1, 'kind': 'explicit_synthetic_seed',
                                   'reason': 'No actual UID/model pair in current native body controls'})
    return result


def directions():
    result = [list(row) for row in itertools.product([-1, 0, 1], repeat=3) if any(row)]
    result += [[.3, .7, .8], [.7, -.4, .6], [-.5, -.6, -.7],
               [.0889442089999, .915405324379, .392583774225]]
    return result


def cases_for(models, representatives):
    cases = []
    probes = directions()

    def append(model, seed, direction_index, multiplier, detail, kind):
        row = models[str(model)]
        direction = probes[direction_index]
        norm = math.sqrt(sum(value*value for value in direction))
        radius = row['terrain_radius_parameter_raw']
        cases.append({'model_index': model, 'model_slot': row['slot'], 'seed': seed,
                      'observer_model_local_raw': [round(value/norm*radius*multiplier) for value in direction],
                      'base_radius_raw': radius, 'mesh_zoom': row['mesh_zoom'],
                      'vector_scale': row['vector_scale'], 'graphics_level_raw': detail,
                      'direction_probe_index': direction_index, 'observer_radius_multiplier': multiplier,
                      'control_kind': kind})

    for model in UNIFORM_MODELS:
        for seed in [representatives[model]['seed'], 0x12345678]:
            for direction_index in range(len(probes)):
                append(model, seed, direction_index, 1.25, 12, 'fixed_provider_policy')
    # Preserve the source's distance/detail dependence as explicit evidence,
    # rather than pretending the query is intrinsically one static height field.
    for model in [119, 125, 129, 133]:
        for direction_index in [26, 29]:
            for multiplier in [1.01, 1.1, 1.25, 1.5, 2.0]:
                for detail in [1, 12]:
                    append(model, representatives[model]['seed'], direction_index, multiplier, detail,
                           'observer_detail_sensitivity')
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('executable', type=Path)
    parser.add_argument('--data-source', type=Path)
    parser.add_argument('--project', type=Path, default=ROOT)
    parser.add_argument('--inputs-project', type=Path, default=ROOT)
    parser.add_argument('--fixture-name', default='terrain_provider_reference.json')
    args = parser.parse_args()
    source = args.source.read_text()
    data = (args.data_source or args.source.with_name('ffedat.asm')).read_text()
    executable = args.executable.read_bytes()
    query = game.query
    old_numbers, old_frames = query.NUMBERS, query.WIDENED_FRAMES
    try:
        query.NUMBERS = old_numbers+game.EXTRA_PROCEDURES
        query.WIDENED_FRAMES = old_frames+[1669]
        hashes = query.function_hashes(source)
        assembly, resources = query.adapt_assembly(source, data, executable)
    finally:
        query.NUMBERS, query.WIDENED_FRAMES = old_numbers, old_frames
    models, model_assembly = game.model_data(executable, UNIFORM_MODELS)
    start = game.START.replace('mov edx,20', 'mov edx,24').replace('cmp r8d,20', 'cmp r8d,24')
    start = start.replace('mov DWORD PTR [DATA_008812],1',
                          'mov eax,DWORD PTR [input+20]\n mov DWORD PTR [DATA_008812],eax\n'
                          ' mov DWORD PTR [DATA_008703],0\n mov DWORD PTR [DATA_008704],0')
    start = start.replace('mov DWORD PTR [query_count],0',
                          'mov DWORD PTR [query_count],0\n mov DWORD PTR [query_depth],-1')
    start = start.replace('mov DWORD PTR [output+20],eax',
                          'mov DWORD PTR [output+20],eax\n mov eax,DWORD PTR [query_depth]\n mov DWORD PTR [output+80],eax')
    start = start.replace('mov edx,80', 'mov edx,84')
    assembly = assembly.replace('FUNC_001876:', 'OriginalTerrainQuery:')
    # Read-only instrumentation: record the last processed original loop level.
    # The following original instruction is CMP, so flags are not observed.
    assembly = assembly.replace('JUMP_007977:', 'JUMP_007977:\n push rax\n'
                                ' mov eax,DWORD PTR [rbp-0x10]\n mov DWORD PTR [query_depth],eax\n pop rax')
    begin = assembly.index('_start:')
    end = assembly.index('.section .bss', begin)
    assembly = assembly[:begin]+start+'\n'+'\n'.join(model_assembly)+'\n'+assembly[end:]
    assembly = assembly.replace('input: .zero 56', 'input: .zero 24')
    assembly = assembly.replace('output: .zero 24',
                                'output: .zero 84\ncollinfo: .zero 28\nrval:.zero 4\nquery_count:.zero 4\nquery_depth:.zero 4')
    representatives = uid_representatives(args.inputs_project)
    cases = cases_for(models, representatives)
    ordered = cases+list(reversed(cases))
    payload = b''.join(struct.pack('<6I', row['model_slot'], row['seed'],
                                  *(value&0xffffffff for value in row['observer_model_local_raw']),
                                  row['graphics_level_raw']) for row in ordered)
    with tempfile.TemporaryDirectory(prefix='ffe-terrain-provider-') as directory:
        work = Path(directory)
        (work/'query.s').write_text(assembly)
        subprocess.run(['as', '--64', str(work/'query.s'), '-o', str(work/'query.o')], check=True)
        undefined = subprocess.check_output(['nm', '-u', str(work/'query.o')], text=True)
        adapter, adapter_metadata = query.unresolved_adapter(undefined, data)
        (work/'excluded.s').write_text(adapter)
        subprocess.run(['as', '--64', str(work/'excluded.s'), '-o', str(work/'excluded.o')], check=True)
        subprocess.run(['ld', '-m', 'elf_x86_64', str(work/'query.o'), str(work/'excluded.o'),
                        '-o', str(work/'query')], check=True)
        output = subprocess.run([str(work/'query')], input=payload, capture_output=True,
                                check=True, timeout=30).stdout
        fresh = subprocess.run([str(work/'query')], input=payload, capture_output=True,
                               check=True, timeout=30).stdout
    if output != fresh or len(output) != 84*len(ordered):
        raise ValueError('Original provider controls did not reproduce completely')
    ranges = {str(model): {'min_ratio': math.inf, 'max_ratio': -math.inf,
                           'min_clearance_raw': 0x7fffffff, 'max_clearance_raw': -0x80000000,
                           'query_limit_clamp_count': 0} for model in UNIFORM_MODELS}
    for index, row in enumerate(cases):
        values = struct.unpack_from('<21i', output, index*84)
        repeated = struct.unpack_from('<21i', output, (len(ordered)-1-index)*84)
        if values != repeated:
            raise ValueError(f'Provider result depends on earlier query order: case {index} {row}, first={values}, repeat={repeated}')
        if values[5] != 1 or values[4] != 0:
            raise ValueError('Original caller skipped or failed to complete terrain')
        result = dict(zip(game.OUTPUT_KEYS, values[:6]))
        result['altitude_low_u32'] &= 0xffffffff
        result.update(query_matrix_raw=list(values[6:15]), query_center_raw=list(values[15:18]),
                      query_style_raw=values[18], query_limit_raw=values[19])
        result['altitude_raw_i64'] = (values[2]<<32)+(values[1]&0xffffffff)
        result['altitude_written'] = values[3] < values[19] or values[0] == 0
        result['last_original_subdivision_level_raw'] = values[20]
        result['source_surface_radius_raw'] = values[17]-values[3]
        result['surface_radius_ratio'] = result['source_surface_radius_raw']/row['base_radius_raw']
        row['result'] = result
        if row['control_kind'] == 'fixed_provider_policy':
            interval = ranges[str(row['model_index'])]
            interval['min_ratio'] = min(interval['min_ratio'], result['surface_radius_ratio'])
            interval['max_ratio'] = max(interval['max_ratio'], result['surface_radius_ratio'])
            interval['min_clearance_raw'] = min(interval['min_clearance_raw'], values[3])
            interval['max_clearance_raw'] = max(interval['max_clearance_raw'], values[3])
            interval['query_limit_clamp_count'] += int(values[3] >= values[19])
    report = {'schema': 1, 'revision': 'terrain-fixed-provider-native-v1',
              'scope': __doc__.strip(), 'source_sha256': hashlib.sha256(executable).hexdigest(),
              'source_procedure_hashes': hashes, 'assembly_sha256': hashlib.sha256(assembly.encode()).hexdigest(),
              'unreached_adapter_sha256': hashlib.sha256(adapter.encode()).hexdigest(),
              'original_resources': resources, 'host_adapter': adapter_metadata, 'models': models,
              'uid_representatives': {str(key): value for key, value in representatives.items()},
              'directions': directions(), 'case_count': len(cases),
              'same_process_interleaved_repeat_checks': len(cases), 'fresh_process_reproduction_verified': True,
              'policy': {'observer_radius_numerator': 5, 'observer_radius_denominator': 4,
                         'graphics_level_raw': 12, 'base_axis_shift': 14,
                         'radius_formula': '(source_query_center_z - recorded_intersection_raw) / source_base_radius_raw',
                         'physical_units': 'Explicit adaptation to the existing game body radius; original SI radius unproven',
                         'nonuniform_model117_excluded': True},
              'caller_altitude_initial_state_raw': 0,
              'read_only_instrumentation': 'Records original F1876 loop level at JUMP_007977 without changing input, geometry, source arithmetic or branch flags',
              'caller_altitude_write_rule': 'F581 may leave altitude unwritten when intersection >= query limit; each control initializes the output to zero and reports altitude_written explicitly',
              'sampled_model_ranges': ranges, 'cases': cases}
    destination = args.project/'tests/fixtures'/args.fixture_name
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, separators=(',', ':'))+'\n')
    print('Fixed source policy controls:', len(cases), '; models:', len(models), '; ranges:', ranges)


if __name__ == '__main__':
    main()
