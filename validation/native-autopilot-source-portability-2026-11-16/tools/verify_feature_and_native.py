#!/usr/bin/env python3
"""Verify all three code51 Main tasks and unchanged native402 controls from a fresh ZIP.

Run only after verify_source_archive.py succeeded in this same BASE. Feature
counts are derived from archived final reports, never from earlier host runs.
"""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
import zipfile

BASE = Path(__file__).resolve().parent
OUT = Path('/workspace/Pyton/validation/native-autopilot-source-portability-2026-11-16')
FINAL = Path('validation/native-autopilot-2026-11-16')
NATIVE_PROOF = Path('validation/contact-lifecycle-2026-11-15/native-proof')
FIXTURE = Path('tests/fixtures/source_contact_lifecycle_native.json')
FIXTURE_SHA = '0db723a520144a55fa3846d80a3e1cad58b42c18d2f904500688a05ebfbf1f8b'
FEATURES = [
    ('native_autopilot_main', 'tests/test_native_autopilot_main.gd', 'native-autopilot-main.json'),
    ('native_ascent_main', 'tests/test_native_ascent_main.gd', 'native-ascent-main.json'),
    ('native_orbit_main', 'tests/test_native_orbit_main.gd', 'native-orbit-main.json'),
]
BAD_LOG = re.compile(r'(?:SCRIPT ERROR:|^\s*ERROR:|ObjectDB instances leaked|Leaked instance:|resources still in use at exit|RID allocations[^\n]*(?:leak|exit)|Unicode parsing error|Traceback \(most recent call last\))', re.I | re.M)
COUNTS = re.compile(r'(?<!\d)(\d+)\s+checks,\s*(\d+)\s+failures\b')


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def write_report(name, value):
    (OUT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def main():
    previous = json.loads((OUT / 'verification.json').read_text())
    require(previous['ok'] and previous['fresh_extraction'] and previous['private_xdg'], 'Fresh import/startup must pass first')
    require(Path(previous['workspace']).resolve() == BASE, 'Prior report belongs to a different fresh workspace')
    project = Path(previous['source_project_path']).resolve()
    extracted = BASE / 'source'
    require(project.is_relative_to(extracted), 'Refuse a different source project')
    archive = Path(previous['archive_path'])
    require(sha(archive.read_bytes()) == previous['archive_sha256'], 'Source archive bytes changed')
    with zipfile.ZipFile(archive) as bundle:
        records = [row for row in bundle.infolist() if not row.is_dir()]
        require(len({row.filename for row in records}) == len(records), 'Duplicate ZIP source entry')
        files = {row.filename: sha(bundle.read(row)) for row in records}
        require(bundle.comment.decode('ascii') == previous['source_commit'], 'Wrong source Git comment')

    def changed():
        return [name for name, digest in files.items()
                if not (extracted / name).is_file() or sha((extracted / name).read_bytes()) != digest]

    require(not changed(), 'Import/startup changed an archived file')
    final_summary_path = project / FINAL / 'final-targeted-summary.json'
    final_summary = json.loads(final_summary_path.read_text())
    require(final_summary.get('status') == 'passed' and final_summary.get('failures') == 0
            and final_summary.get('passed_suites') == 32 and len(final_summary.get('suites', [])) == 32,
            'The exact source archive must include the final32-suite passing proof')
    selected = {row['test']: row for row in final_summary['suites']}
    require(len(selected) == 32, 'Duplicate archived selected test')
    base_env = os.environ.copy()
    base_env['PYTHONDONTWRITEBYTECODE'] = '1'

    def run(command, log_name, environment, timeout=900):
        start = time.monotonic()
        try:
            result = subprocess.run(command, cwd=project, env=environment,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
            raw, code, timed_out = result.stdout, result.returncode, False
        except subprocess.TimeoutExpired as exc:
            raw, code, timed_out = exc.stdout or b'', None, True
        (OUT / log_name).write_bytes(raw)
        text = raw.decode(errors='replace')
        errors = [line for line in text.splitlines() if BAD_LOG.search(line)]
        return {'command': command, 'exit_code': code, 'timed_out': timed_out,
                'duration_seconds': round(time.monotonic() - start, 6),
                'log_file': log_name, 'log_sha256': sha(raw), 'error_markers': errors}, text

    features = []
    for name, script, report_name in FEATURES:
        archived_report_path = project / FINAL / report_name
        final_report = json.loads(archived_report_path.read_text())
        expected = int(final_report['checks'])
        require(expected > 0 and final_report['failures'] == 0 and script in selected
                and selected[script]['checks'] == expected, 'Archived final report differs from the selected current suite: ' + name)
        pins = final_report.get('sources', final_report.get('source_sha256', {}))
        require(pins.get(script) == sha((project / script).read_bytes())
                and pins.get('scripts/main.gd') == sha((project / 'scripts/main.gd').read_bytes()),
                'Archived Main/test source is not the final tested source: ' + name)
        for relative, digest in pins.items():
            require(sha((project / relative).read_bytes()) == digest, 'Archived feature source pin differs: ' + relative)
        require(selected[script]['test_source_sha256'] == pins[script], 'Selected archived test source differs')
        env, private = base_env.copy(), {}
        for suffix, key in [('data', 'XDG_DATA_HOME'), ('config', 'XDG_CONFIG_HOME'), ('cache', 'XDG_CACHE_HOME')]:
            path = BASE / 'feature_main' / name / suffix
            path.mkdir(parents=True, exist_ok=False)
            env[key] = str(path)
            private[key] = str(path)
        command = ['godot', '--headless', '--audio-driver', 'Dummy', '--path', str(project),
                   '--script', 'res://' + script, '--', '--rebuild-capture']
        record, text = run(command, name.replace('_', '-') + '-feature.log', env)
        matches = COUNTS.findall(text)
        checks = int(matches[0][0]) if len(matches) == 1 else 0
        failures = int(matches[0][1]) if len(matches) == 1 else None
        modified = changed()
        feature = {'name': name, 'test': script, **record, 'checks': checks, 'failures': failures,
                   'expected_checks_from_archived_final_report': expected,
                   'archived_final_report': str(archived_report_path.relative_to(project)),
                   'archived_final_report_sha256': sha(archived_report_path.read_bytes()),
                   'declared_source_pins': pins, 'source_actual_files': len(files),
                   'all_source_files_unchanged': not modified, 'modified_files': modified,
                   'private_xdg': private, 'physical_device_tested': False,
                   'ok': record['exit_code'] == 0 and not record['timed_out'] and len(matches) == 1
                         and checks == expected and failures == 0 and not record['error_markers'] and not modified}
        features.append(feature)
        write_report(name.replace('_', '-') + '-source-feature.json', {
            'schema': 'starfrontier-source-archive-code51-task-feature-v1',
            'source_commit': previous['source_commit'], 'archive_sha256': previous['archive_sha256'], **feature})
        require(feature['ok'], 'Fresh actual Main task failed: ' + name)

    modified = changed()
    primary = features[-1]
    feature = {'schema': 'starfrontier-source-archive-native-autopilot-feature-v1',
               'source_commit': previous['source_commit'], 'archive_sha256': previous['archive_sha256'],
               'source_actual_files': len(files), 'primary_feature_script': primary['test'],
               'checks': primary['checks'], 'failures': primary['failures'],
               'expected_checks_from_archived_final_report': primary['expected_checks_from_archived_final_report'],
               'archived_final_report': primary['archived_final_report'],
               'archived_final_report_sha256': primary['archived_final_report_sha256'],
               'features': features, 'unique_feature_scripts': len(features),
               'unique_feature_checks_separate': sum(row['checks'] for row in features),
               'all_source_files_unchanged': not modified, 'modified_files': modified,
               'error_markers': [line for row in features for line in row['error_markers']],
               'private_xdg': True, 'physical_device_tested': False,
               'ok': all(row['ok'] for row in features) and not modified,
               'scope': 'Three distinct actual Main suites from one exact fresh source archive, each with new private XDG state: autoland, powered ascent, affine-space handoff/cold/report/ordinary-isolation. Primary checks refers only to the orbital Main suite; the separate aggregate is not added to the unique32 functional total. These are bounded host guidance and rotation-only velocity handoff; no circular-orbit insertion, original full dispatcher, physical Android or FPS proof.'}
    write_report('native-autopilot-main-feature.json', feature)
    require(feature['ok'], 'Fresh actual Main tasks did not all pass')

    fixture_path = project / FIXTURE
    require(sha(fixture_path.read_bytes()) == FIXTURE_SHA, 'The unchanged native402 fixture differs')
    native_fixture = json.loads(fixture_path.read_text())
    require(native_fixture['case_count'] == 402, 'Wrong native bank')
    proof = project / NATIVE_PROOF
    archived_validation = json.loads((proof / 'validation.json').read_text())
    require(archived_validation['checks'] == 6208 and archived_validation['failures'] == 0
            and archived_validation['fixture_sha256'] == FIXTURE_SHA
            and archived_validation['counts']['native_replayed_cases'] == 402,
            'Wrong archived native402/6208 proof')
    env = base_env.copy()
    temporary = BASE / 'native-validator-temp'
    temporary.mkdir(parents=True, exist_ok=False)
    env['TMPDIR'] = str(temporary)
    work = BASE / 'native-rebuild-work'
    require(not work.exists(), 'Native generator requires a fresh build directory')
    commands = []
    for name, command in [
        ('generator', ['python3', str(proof / 'rebuild_source_contact_lifecycle_native.py'), '--work', str(work)]),
        ('validator', ['python3', str(proof / 'validate_source_contact_lifecycle_native.py'), '--replay']),
    ]:
        record, _ = run(command, 'source-native-' + name + '.log', env, 600)
        record['name'] = name
        commands.append(record)
    modified = changed()
    native = json.loads((proof / 'validation.json').read_text())
    reproduced = sha(fixture_path.read_bytes()) == FIXTURE_SHA
    errors = [line for row in commands for line in row['error_markers']]
    reproduction = {'schema': 'starfrontier-source-archive-native-contact-lifecycle-reproduction-v1',
                    'source_commit': previous['source_commit'], 'archive_sha256': previous['archive_sha256'],
                    'fixture_sha256': FIXTURE_SHA, 'fixture_reproduced_byte_exact': reproduced,
                    'commands': commands, 'error_markers': errors,
                    'all_archived_files_unchanged': not modified, 'modified_archived_files': modified,
                    'archived_files': len(files), 'native_validation_checks': native['checks'],
                    'native_validation_failures': native['failures'],
                    'native_control_cases': native_fixture['case_count'],
                    'native_replayed_cases': native['counts'].get('native_replayed_cases'),
                    'native_bank_cases': {'full_F574_actor_calls': native_fixture['actor_case_count'],
                                          'corrected_body_F574_requeries': native_fixture['explicit_corrected_requery_case_count'],
                                          'restored_F1030_parked_updates': native_fixture['parked_cold_tick_case_count'],
                                          'intercepted_F1047_entry_prefixes': native_fixture['launch_entry_prefix_case_count']},
                    'new_native_oracle_claimed': False,
                    'ok': all(row['exit_code'] == 0 and not row['timed_out'] for row in commands)
                          and not errors and reproduced and not modified and native == archived_validation
                          and native['checks'] == 6208 and native['failures'] == 0
                          and native['counts'].get('native_replayed_cases') == 402,
                    'scope': 'The unchanged archived402-case original-instruction generator and6208-check --replay validator run inside the exact fresh code51 ZIP. All archived source/proof bytes remain unchanged. This reproduces the prior bounded F574/F575/park/F1047-entry bank; it does not create a new native oracle, prove full source autopilot/launch/F573 bank conversion, circular orbit, original save format or physical Android. Repeated counts are separate from the unique32 functional total.'}
    write_report('source-native-reproduction.json', reproduction)
    require(reproduction['ok'], 'Archived unchanged native bank did not reproduce byte-exact')
    print(json.dumps({'feature_ok': feature['ok'], 'feature_scripts': 3,
                      'primary_orbit_checks': feature['checks'],
                      'feature_checks_separate': feature['unique_feature_checks_separate'],
                      'native_ok': reproduction['ok'], 'native_validation_checks': 6208,
                      'native_replayed_cases': 402, 'all_archived_files_unchanged': not modified}, indent=2))


if __name__ == '__main__':
    main()
