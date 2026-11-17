#!/usr/bin/env python3
"""Verify the exact full0.28 source plus cumulative player-dispatch update.

No Git metadata or private original executable/source is required. The update
alone is intentionally incomplete. Tests, import and native generators operate
only on the safely extracted pair; reports/logs are separate from source.
"""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import time
import zipfile

BASE_SHA = '830e7219879f694a24e41f579417986f936902f6592926ff8e84dc99217b6c2d'
BASE_BYTES = 33543341
BASE_COMMIT = 'de8eb18a687d007781321436910187dff3785775'
BASE_FILES = 1660
BASE_ENTRIES = 1829
PREFIX = 'StarFrontier-0.28.0-source/'
MANIFEST_NAME = 'SOURCE_UPDATE_MANIFEST.json'
PREVIOUS_V = 'validation/reference-bank-2026-11-17/'
V = 'validation/player-dispatch-2026-11-17/'
FREEZE = V + 'runtime-freeze.json'
OLD_FREEZE = 'validation/native-station-2026-11-16/runtime-freeze.json'
FEATURES = {
    'source_reference_bank': ('tests/test_source_reference_bank.gd', 'source-reference-bank.json'),
    'source_angular_motion': ('tests/test_source_angular_motion.gd', 'source-angular-motion.json'),
    'source_clock_pipeline': ('tests/test_source_clock_pipeline.gd', 'source-clock-pipeline.json'),
    'source_flight_state': ('tests/test_source_flight_state.gd', 'source-flight-state.json'),
    'source_object_factory': ('tests/test_source_object_factory.gd', 'source-object-factory.json'),
    'source_object_cadence': ('tests/test_source_object_cadence.gd', 'source-object-cadence.json'),
    'source_player_dispatch': ('tests/test_source_player_dispatch.gd', 'source-player-dispatch.json'),
    'source_frame_dispatch': ('tests/test_source_frame_dispatch.gd', 'source-frame-dispatch.json'),
    'source_player_dispatch_state': ('tests/test_source_player_dispatch_state.gd', 'source-player-dispatch-state.json'),
}
NATIVE = {
    'reference_bank': ('tools/rebuild_source_reference_bank_native.py', 'tests/fixtures/source_reference_bank_native.json'),
    'angular': ('tools/rebuild_source_angular_native.py', 'tests/fixtures/source_angular_native.json'),
    'clock': ('tools/rebuild_source_clock_pipeline_native.py', 'tests/fixtures/source_clock_pipeline_native.json'),
    'object_factory': ('tools/rebuild_source_object_factory_native.py', 'tests/fixtures/source_object_factory_native.json'),
    'object_cadence': ('tools/rebuild_source_object_cadence_native.py', 'tests/fixtures/source_object_cadence_native.json'),
    'player_dispatch': ('tools/rebuild_source_player_dispatch_native.py', 'tests/fixtures/source_player_dispatch_native.json'),
    'frame_dispatch': ('tools/rebuild_source_frame_dispatch_native.py', 'tests/fixtures/source_frame_dispatch_native.json'),
}
BAD_LOG = re.compile(r'(?:SCRIPT ERROR:|^\s*ERROR:|ObjectDB instances leaked|Leaked instance:|resources still in use at exit|RID allocations[^\n]*(?:leak|exit)|Unicode parsing error|Traceback \(most recent call last\))', re.I | re.M)
COUNTS = re.compile(r'(?<!\d)(\d+)\s+checks,\s*(\d+)\s+failures\b')


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def safe(name):
    require(isinstance(name, str) and name and '\\' not in name
            and all(ord(c) >= 32 for c in name), 'Unsafe archive path: ' + repr(name))
    path = PurePosixPath(name)
    require(not path.is_absolute() and '..' not in path.parts and '.' not in path.parts
            and path.as_posix() == name, 'Noncanonical archive path: ' + repr(name))
    return path


def file_inventory(archive, *, base, source_commit):
    raw = archive.read_bytes()
    if base:
        require(len(raw) == BASE_BYTES and sha(raw) == BASE_SHA, 'The complete required0.28 base source differs')
    inventory = {}
    with zipfile.ZipFile(archive) as bundle:
        require(bundle.testzip() is None, 'ZIP CRC failed: ' + str(archive))
        require(bundle.comment.decode('ascii') == (BASE_COMMIT if base else source_commit), 'Wrong ZIP source commit comment')
        records = bundle.infolist()
        if base:
            require(len(records) == BASE_ENTRIES, 'Base ZIP entry count differs')
        require(len({row.filename for row in records}) == len(records), 'Duplicate ZIP archive entry')
        for row in records:
            mode = row.external_attr >> 16
            kind = stat.S_IFMT(mode)
            require(kind in (0, stat.S_IFREG, stat.S_IFDIR), 'Symbolic link or special ZIP entry rejected')
            name = row.filename.rstrip('/') if row.is_dir() else row.filename
            safe(name)
            if row.is_dir():
                require(row.filename.startswith(PREFIX), 'ZIP directory outside the shared source prefix')
                continue
            if not base and row.filename == MANIFEST_NAME:
                inventory[MANIFEST_NAME] = bundle.read(row)
                continue
            require(row.filename.startswith(PREFIX), 'ZIP file outside required shared source prefix')
            relative = row.filename[len(PREFIX):]
            safe(relative)
            require(relative not in inventory and not relative.startswith('.git/'), 'Unsafe or duplicate source path')
            inventory[relative] = bundle.read(row)
    if base:
        require(len(inventory) == BASE_FILES and OLD_FREEZE in inventory, 'The base source inventory is incomplete')
    return inventory, len(records)


def execute(args):
    source_commit = args.source_commit
    require(re.fullmatch(r'[0-9a-f]{40}', source_commit) is not None, 'Provide an immutable40-character source commit')
    require(re.fullmatch(r'[0-9a-f]{64}', args.update_sha256) is not None, 'Provide the exact update SHA256')
    base_path, update_path = args.base_archive.resolve(), args.update_archive.resolve()
    work = args.workdir.resolve()
    report = args.report.resolve()
    require(not work.exists(), 'Fresh verification workdir already exists')
    require(not report.exists(), 'Refusing to overwrite an existing verification report')
    require(not report.is_relative_to(work), 'Public report/log directory must be outside the private fresh workspace')
    require(sha(update_path.read_bytes()) == args.update_sha256, 'Source update bytes differ from the requested SHA256')
    base, base_entries = file_inventory(base_path, base=True, source_commit=source_commit)
    patch, update_entries = file_inventory(update_path, base=False, source_commit=source_commit)
    require(MANIFEST_NAME in patch, 'Source-update manifest missing')
    manifest_raw = patch.pop(MANIFEST_NAME)
    manifest = json.loads(manifest_raw)
    require(manifest.get('schema') == 'starfrontier-player-dispatch-source-update-v1'
            and manifest.get('source_commit') == source_commit
            and manifest.get('project_prefix') == PREFIX
            and manifest.get('base_archive_sha256') == BASE_SHA
            and manifest.get('base_source_commit') == BASE_COMMIT
            and manifest.get('required_archive_count') == 2, 'Wrong required source-pair manifest')
    require(manifest.get('new_APK_produced') is False and manifest.get('new_playable_release_claimed') is False,
            'The raw foundation update must not claim a new playable APK')
    required = manifest.get('required_archives')
    require(isinstance(required, list) and len(required) == 2, 'Exactly two required source archives are expected')
    base_record = next((row for row in required if row.get('role') == 'full_base_source'), {})
    update_record = next((row for row in required if row.get('role') == 'source_update'), {})
    require(base_record.get('bytes') == BASE_BYTES and base_record.get('sha256') == BASE_SHA
            and base_record.get('source_commit') == BASE_COMMIT
            and update_record.get('source_commit') == source_commit, 'Required archive identities differ')
    declared = manifest.get('project_payloads')
    require(isinstance(declared, dict) and len(declared) == manifest.get('project_payload_count')
            and set(declared) == set(patch), 'Update source payload inventory differs')
    for name, record in declared.items():
        safe(name)
        require(isinstance(record, dict) and record.get('bytes') == len(patch[name])
                and record.get('sha256') == sha(patch[name]), 'Update payload SHA/length differs: ' + name)
    merged = dict(base)
    merged.update(patch)
    require(len(merged) == manifest.get('merged_actual_project_file_count')
            and manifest.get('all_base_files_retained') is True
            and manifest.get('deleted_source_paths') == [] and set(base) <= set(merged),
            'The source pair deleted a base file or has a different merged inventory')
    require(FREEZE in merged and sha(merged[FREEZE]) == manifest.get('runtime_freeze_sha256'), 'Runtime freeze bytes differ')
    freeze, previous = json.loads(merged[FREEZE]), json.loads(base[OLD_FREEZE])
    runtime, old_runtime = freeze.get('files_sha256'), previous.get('files_sha256')
    require(isinstance(runtime, dict) and len(runtime) == 492
            and runtime == manifest.get('runtime_files_sha256')
            and isinstance(old_runtime, dict) and len(old_runtime) == 475
            and set(old_runtime) <= set(runtime), 'Wrong492/475 runtime inventory')
    for name, digest in runtime.items():
        safe(name)
        require(name in merged and sha(merged[name]) == digest, 'Source-pair runtime hash differs: ' + name)
    require(all(runtime[name] == digest for name, digest in old_runtime.items()), 'An existing published runtime input changed')
    for name in ('scripts/main.gd', 'scripts/build_info.gd', 'export_presets.cfg'):
        require(merged[name] == base[name], 'Published Main/version/export changed')
    expected_files = {name: sha(raw) for name, raw in merged.items()}
    work.mkdir(parents=True, exist_ok=False)
    project = work / 'source' / PREFIX.rstrip('/')
    project.mkdir(parents=True, exist_ok=False)
    for name, raw in merged.items():
        target = project.joinpath(*safe(name).parts)
        require(target.resolve().is_relative_to(project.resolve()), 'Extraction path escapes fresh project')
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open('xb') as output:
            output.write(raw)
    (work / MANIFEST_NAME).write_bytes(manifest_raw)
    report.parent.mkdir(parents=True, exist_ok=True)

    def unchanged():
        return [name for name, digest in expected_files.items()
                if not (project / name).is_file() or sha((project / name).read_bytes()) != digest]

    def xdg(label):
        env = os.environ.copy()
        env['PYTHONDONTWRITEBYTECODE'] = '1'
        for key, suffix in [('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]:
            target = work / 'private-xdg' / label / suffix
            target.mkdir(parents=True, exist_ok=False)
            env[key] = str(target)
        return env

    def run(command, label, env, timeout=240):
        start = time.monotonic()
        try:
            completed = subprocess.run(command, cwd=project, env=env, stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT, timeout=timeout)
            raw, code, timed_out = completed.stdout, completed.returncode, False
        except subprocess.TimeoutExpired as error:
            raw, code, timed_out = error.stdout or b'', None, True
        target = report.parent / (label + '.log')
        with target.open('xb') as output:
            output.write(raw)
        text = raw.decode('utf-8', errors='replace')
        record = {'command': command, 'exit_code': code, 'timed_out': timed_out,
                  'duration_seconds': round(time.monotonic() - start, 6),
                  'log_file': target.name, 'log_sha256': sha(raw),
                  'error_markers': [line for line in text.splitlines() if BAD_LOG.search(line)]}
        require(code == 0 and not timed_out and not record['error_markers'], 'Fresh command failed: ' + label)
        require(not unchanged(), 'An archived source file changed during: ' + label)
        return record, text

    require(not unchanged(), 'Initial safe extraction differs from the exact source pair')
    godot = shutil.which('godot')
    require(bool(godot), 'Godot is required for the clean import and source feature checks')
    imported, _ = run([godot, '--headless', '--editor', '--audio-driver', 'Dummy', '--path', str(project),
                       '--import', '--quit'], 'source-pair-import', xdg('import'))
    startup, text = run([godot, '--headless', '--audio-driver', 'Dummy', '--path', str(project),
                         '--script', 'res://tests/test_source_full_startup.gd', '--', '--source-startup-isolated'],
                        'source-pair-startup', xdg('source_full_startup'))
    matches = COUNTS.findall(text)
    require(matches == [('10', '0')], 'Fresh normal startup must report exactly10checks/0failures')
    summary = json.loads((project / V / 'final-targeted-summary.json').read_text())
    require(summary.get('status') == 'passed' and summary.get('failures') == 0,
            'Archived final functional proof does not pass')
    selected = {row['name']: row for row in summary.get('suites', [])}
    require(len(selected) == len(summary.get('suites', [])) and set(FEATURES) <= set(selected), 'Missing or duplicate archived unique feature suite')
    features = []
    for name, (script, archived_report) in FEATURES.items():
        row = selected[name]
        source_report = json.loads((project / V / archived_report).read_text())
        expected = source_report.get('checks')
        require(row.get('status') == 'passed' and row.get('failures') == 0
                and type(expected) is int and expected > 0 and expected == row.get('checks')
                and source_report.get('failures') == 0, 'Archived feature expected count differs: ' + name)
        pins = source_report.get('sources')
        require(isinstance(pins, dict) and pins.get(script) == sha((project / script).read_bytes())
                and row.get('suite_source', {}).get('sha256') == pins[script], 'Archived feature script pin differs: ' + name)
        for relative, digest in pins.items():
            safe(relative)
            require(relative in expected_files and sha((project / relative).read_bytes()) == digest, 'Archived feature input pin differs: ' + relative)
        execution, text = run([godot, '--headless', '--audio-driver', 'Dummy', '--path', str(project),
                               '--script', 'res://' + script], name.replace('_', '-') + '-feature', xdg(name))
        matches = COUNTS.findall(text)
        require(matches == [(str(expected), '0')], 'Fresh feature result differs from archived unique suite: ' + name)
        features.append({'name': name, 'test': script, 'checks': expected, 'failures': 0,
                         'sources': pins, 'archived_report': V + archived_report,
                         'archived_report_sha256': sha((project / V / archived_report).read_bytes()),
                         'all_source_files_unchanged': True, 'ok': True, **execution})

    require(len(FEATURES) == 9 and len(NATIVE) == 7, 'Expected nine raw feature suites and seven native generators')
    archived_native_cases = sum(int(json.loads((project / fixture).read_text())['case_count']) for _, fixture in NATIVE.values())
    require(archived_native_cases == 3793, 'The seven archived DOS native fixture totals differ')
    factory_resource_path = project / 'data/ffe_object_factory.json'
    factory_resource = json.loads(factory_resource_path.read_text())
    factory_fixture = json.loads((project / 'tests/fixtures/source_object_factory_native.json').read_text())
    require(factory_resource.get('schema') == 'starfrontier-source-object-factory-resources-v1'
            and factory_resource.get('model_count') == 149
            and isinstance(factory_resource.get('models'), dict)
            and set(factory_resource['models']) == {str(index) for index in range(149)}
            and factory_fixture.get('resources_sha256') == sha(factory_resource_path.read_bytes()),
            'The complete original149-model factory resource differs from its native fixture')
    native = []
    missing = work / 'private-original-inputs-deliberately-absent'
    require(not missing.exists(), 'Portable proof sentinel must remain absent')
    native_env = xdg('native')
    for name, (script, fixture) in NATIVE.items():
        output = work / 'native' / (name + '.json')
        command = [shutil.which('python3') or 'python3', script, '--output', str(output)]
        if name == 'reference_bank':
            command += ['--exe', str(missing / 'FIRSTENC.EXE'), '--source', str(missing / 'ffe.asm'), '--data', str(missing / 'ffedat.asm')]
        elif name == 'angular':
            proof_copy = work / 'native' / 'angular-proof'
            shutil.copytree(project / PREVIOUS_V / 'angular-native-proof', proof_copy)
            command += ['--proof-dir', str(proof_copy), '--exe', str(missing / 'FIRSTENC.EXE'),
                        '--asm', str(missing / 'ffe.asm'), '--data', str(missing / 'ffedat.asm')]
        elif name == 'clock':
            command += ['--executable', str(missing / 'FIRSTENC.EXE'), '--source', str(missing / 'ffe.asm'),
                        '--proof-dir', str(project / PREVIOUS_V / 'clock-native-proof'),
                        '--validation-dir', str(work / 'native' / 'clock-proof')]
        elif name == 'player_dispatch':
            proof_copy = work / 'native' / 'player-proof'
            shutil.copytree(project / V / 'player-native-proof', proof_copy)
            command += ['--proof-dir', str(proof_copy), '--exe', str(missing / 'FIRSTENC.EXE'),
                        '--asm', str(missing / 'ffe.asm'), '--data', str(missing / 'ffedat.asm')]
        elif name == 'object_factory':
            command += ['--exe', str(missing / 'FIRSTENC.EXE'), '--asm', str(missing / 'ffe.asm'),
                        '--data', str(missing / 'ffedat.asm')]
        else:
            command += ['--exe', str(missing / 'FIRSTENC.EXE'), '--source', str(missing / 'ffe.asm'),
                        '--data', str(missing / 'ffedat.asm')]
        execution, _ = run(command, 'source-native-' + name, native_env)
        require(output.read_bytes() == (project / fixture).read_bytes(), 'Portable native fixture is not byte-exact: ' + name)
        doc = json.loads(output.read_text())
        expected = json.loads((project / fixture).read_text())
        count = int(doc['case_count'])
        require(count == int(expected['case_count']) and count > 0, 'Portable native case count differs: ' + name)
        native.append({'name': name, 'generator': script, 'fixture': fixture,
                       'fixture_sha256': sha(output.read_bytes()), 'case_count': count,
                       'diagnostic_case_count_separate': int(doc.get('diagnostic_case_count', 0)),
                       'fixture_byte_exact': True, 'private_original_inputs_deliberately_absent': True,
                       'all_source_files_unchanged': True, 'ok': True, **execution})
    # The two actual F606→F1041 compositions are a supplemental bank. They
    # must never inflate the seven main native fixture case totals.
    supplement_path = project / V / 'player-native-proof/player-frame-chain.json'
    supplement_raw = supplement_path.read_bytes()
    require(sha(supplement_raw) == '4b14fb995c23a3ffe8de2f3f324e9a14b052a7de2a3da9092ecfec2edb48f69e',
            'Archived supplemental native player/frame bank differs')
    supplement_expected = json.loads(supplement_raw)
    require(supplement_expected.get('schema') == 'starfrontier-native-player-frame-chain-v1'
            and supplement_expected.get('case_count') == 2
            and supplement_expected.get('supplemental_controls_added_to_main_case_totals') is False
            and supplement_expected.get('private_original_inputs_needed') is False,
            'Supplemental native composition scope/count differs')
    supplement_pins = supplement_expected.get('source_pins')
    require(isinstance(supplement_pins, dict) and bool(supplement_pins),
            'Supplemental native source pins are missing')
    for relative, digest in supplement_pins.items():
        safe(relative)
        require(relative in expected_files and sha((project / relative).read_bytes()) == digest,
                'Supplemental native source pin differs: ' + relative)
    supplement_script = 'tools/rebuild_source_player_frame_chain_native.py'
    supplement_output = work / 'native' / 'player-frame-chain.json'
    supplement_execution, _ = run([shutil.which('python3') or 'python3', supplement_script,
                                   '--output', str(supplement_output)],
                                  'source-native-player-frame-chain-supplement', native_env)
    require(supplement_output.read_bytes() == supplement_raw,
            'Actual native player/frame composition is not byte-exact')
    supplement_record = {'name': 'player_frame_chain', 'generator': supplement_script,
                         'fixture': V + 'player-native-proof/player-frame-chain.json',
                         'fixture_sha256': sha(supplement_raw), 'case_count_separate': 2,
                         'source_pins': supplement_pins, 'fixture_byte_exact': True,
                         'private_original_inputs_needed': False,
                         'added_to_main_native_case_total': False,
                         'all_source_files_unchanged': True, 'ok': True,
                         **supplement_execution}
    require(sum(row['case_count'] for row in native) == 3793
            and sum(row['diagnostic_case_count_separate'] for row in native) == 16, 'Original native bank totals differ')
    require(not unchanged() and not missing.exists(), 'Source pair changed or a private original input appeared')
    result = {
        'schema': 'starfrontier-player-dispatch-source-pair-portability-v1', 'status': 'verified', 'ok': True,
        'completed_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
        'source_commit': source_commit, 'required_archive_count': 2,
        'base_archive_path': str(base_path), 'base_archive_sha256': BASE_SHA,
        'base_archive_bytes': BASE_BYTES, 'base_source_commit': BASE_COMMIT,
        'base_archive_actual_files': len(base), 'base_archive_zip_entries': base_entries,
        'update_archive_path': str(update_path), 'update_archive_sha256': args.update_sha256,
        'update_archive_bytes': update_path.stat().st_size, 'update_archive_zip_entries': update_entries,
        'update_project_payload_files': len(patch), 'update_manifest_sha256': sha(manifest_raw),
        'source_project_path': str(project), 'workspace': str(work), 'fresh_extraction': True,
        'source_actual_files': len(expected_files), 'all_base_files_retained': True,
        'runtime_inputs_verified': len(runtime), 'unchanged_published0_28_runtime_inputs': len(old_runtime),
        'runtime_freeze_sha256': sha(merged[FREEZE]), 'all_runtime_inputs_match_frozen_source': True,
        'safe_archive_entries_verified': True, 'both_ZIP_CRC_verified': True, 'source_commit_comments_verified': True,
        'private_xdg': True, 'import': imported, 'startup': startup, 'startup_checks': 10, 'startup_failures': 0,
        'features': features, 'unique_feature_scripts_separate': len(features),
        'native_generator_count': len(native) + 1, 'main_native_generator_count': len(native),
        'supplemental_native_generator_count': 1, 'supplemental_native_composition_cases_separate': 2,
        'supplemental_native_reproductions': [supplement_record],
        'previous_DOS_native_cases_separate': 1921,
        'new_DOS_native_cases_separate': 1872,
        'unique_feature_checks_separate': sum(row['checks'] for row in features), 'feature_failures': 0,
        'native_reproductions': native, 'native_DOS_control_cases_separate': 3793,
        'native_JJFFE_copy_diagnostics_separate': 16, 'all_native_fixtures_byte_exact': True,
        'all_source_files_unchanged': True, 'modified_source_files': [], 'git_metadata_required': False,
        'new_APK_produced': False, 'new_playable_release_claimed': False, 'physical_device_tested': False,
        'factory_resource_sha256': sha((project / 'data/ffe_object_factory.json').read_bytes()),
        'original_factory_model_count': int(json.loads((project / 'data/ffe_object_factory.json').read_text())['model_count']),
        'full_collision_VM_claimed': False, 'full_F597_autopilot_claimed': False,
        'verifier_sha256': sha(Path(__file__).read_bytes()),
        'scope': 'Fresh exact full0.28 source plus immutable cumulative player-dispatch update. Isolated Godot import, normal10-check startup and nine current raw core suites. Seven main included original native generators reproduce3793DOS cases plus16separate JJFFE controlled-copy diagnostics with deliberately nonexistent private-original inputs. An eighth native generator independently reproduces two supplemental actual F606-to-F1041 compositions; these are not added to the main3793-case total. All archived source files and492runtime inputs remain byte-exact. These portability repeats are not added to the current unique functional results, and do not establish a new integrated playable APK, full collision VM/F1418/F597/F866/effects/AI route or physical Android/FPS proof.'}
    with report.open('x') as stream:
        stream.write(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'ok': True, 'report': str(report), 'source_actual_files': len(expected_files),
                      'runtime_inputs': len(runtime), 'startup_checks': 10,
                      'fresh_feature_checks_separate': result['unique_feature_checks_separate'],
                      'native_DOS_cases_separate': 3793, 'native_JJFFE_diagnostics_separate': 16,
                      'native_generator_commands': 8, 'supplemental_native_compositions_separate': 2}, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base-archive', type=Path, required=True)
    parser.add_argument('--update-archive', type=Path, required=True)
    parser.add_argument('--workdir', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--source-commit', required=True)
    parser.add_argument('--update-sha256', required=True)
    execute(parser.parse_args())


if __name__ == '__main__':
    main()
