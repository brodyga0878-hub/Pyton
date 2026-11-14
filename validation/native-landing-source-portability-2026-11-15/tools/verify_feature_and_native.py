#!/usr/bin/env python3
"""Replay the native landing feature and archived lifecycle controls from a fresh ZIP."""
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
OUT = Path('/workspace/Pyton/validation/native-landing-source-portability-2026-11-15')
LIFECYCLE = Path('validation/contact-lifecycle-2026-11-15')
FIXTURE = Path('tests/fixtures/source_contact_lifecycle_native.json')
FIXTURE_SHA256 = '0db723a520144a55fa3846d80a3e1cad58b42c18d2f904500688a05ebfbf1f8b'


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def write_report(name: str, value: dict) -> None:
    (OUT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def main() -> None:
    previous = json.loads((OUT / 'verification.json').read_text())
    assert previous['ok'], 'Fresh-source import/startup must pass first'
    assert Path(previous['workspace']).resolve() == BASE
    project = Path(previous['source_project_path']).resolve()
    extracted = BASE / 'source'
    assert project.is_relative_to(extracted), 'Refuse a different source project'
    archive = Path(previous['archive_path'])
    assert sha(archive.read_bytes()) == previous['archive_sha256']
    with zipfile.ZipFile(archive) as bundle:
        records = [row for row in bundle.infolist() if not row.is_dir()]
        assert len({row.filename for row in records}) == len(records)
        files = {row.filename: sha(bundle.read(row)) for row in records}

    def changed() -> list[str]:
        return [name for name, digest in files.items()
                if not (extracted / name).is_file()
                or sha((extracted / name).read_bytes()) != digest]

    assert not changed(), 'Import/startup changed an archived file'
    final_feature_path = project / LIFECYCLE / 'native-landing-trial-main.json'
    final_feature = json.loads(final_feature_path.read_text())
    expected_checks = int(final_feature['checks'])
    assert expected_checks > 0 and final_feature['failures'] == 0
    assert final_feature['sources']['tests/test_native_landing_trial_main.gd'] == sha(
        (project / 'tests/test_native_landing_trial_main.gd').read_bytes())
    assert final_feature['sources']['scripts/main.gd'] == sha(
        (project / 'scripts/main.gd').read_bytes())

    env = os.environ.copy()
    env['PYTHONDONTWRITEBYTECODE'] = '1'
    private_xdg = {}
    for suffix, name in [('data', 'XDG_DATA_HOME'),
                         ('config', 'XDG_CONFIG_HOME'),
                         ('cache', 'XDG_CACHE_HOME')]:
        folder = BASE / 'feature_main' / suffix
        folder.mkdir(parents=True, exist_ok=False)
        env[name] = str(folder)
        private_xdg[name] = str(folder)
    temporary = BASE / 'native-validator-temp'
    temporary.mkdir(parents=True, exist_ok=False)
    env['TMPDIR'] = str(temporary)

    def run(command: list[str], log_name: str, timeout: int = 300) -> tuple:
        clock = time.monotonic()
        try:
            result = subprocess.run(command, cwd=project, env=env,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    timeout=timeout)
            raw = result.stdout
            return_code = result.returncode
            timed_out = False
        except subprocess.TimeoutExpired as exc:
            raw = exc.stdout or b''
            return_code = None
            timed_out = True
        (OUT / log_name).write_bytes(raw)
        text = raw.decode(errors='replace')
        errors = [line for line in text.splitlines()
                  if re.search(r'^(?:ERROR:|SCRIPT ERROR:)|ObjectDB instances leaked|'
                               r'resources still in use at exit|Traceback \(most recent call last\)', line)]
        record = {'command': command, 'exit_code': return_code,
                  'timed_out': timed_out,
                  'duration_seconds': round(time.monotonic() - clock, 6),
                  'log_sha256': sha(raw), 'log_file': log_name,
                  'error_markers': errors}
        return record, text

    command = ['godot', '--headless', '--audio-driver', 'Dummy', '--path', str(project),
               '--script', 'res://tests/test_native_landing_trial_main.gd',
               '--', '--rebuild-capture']
    record, output = run(command, 'native-landing-main-feature.log')
    match = re.search(r'Native landing trial Main:\s*(\d+) checks,\s*(\d+) failures', output)
    checks = int(match[1]) if match else 0
    failures = int(match[2]) if match else None
    modified = changed()
    feature = {
        'schema': 'starfrontier-source-archive-native-landing-feature-v1',
        'source_commit': previous['source_commit'],
        'archive_sha256': previous['archive_sha256'], **record,
        'checks': checks, 'failures': failures,
        'expected_checks_from_archived_final_report': expected_checks,
        'archived_final_report': str(final_feature_path.relative_to(project)),
        'archived_final_report_sha256': sha(final_feature_path.read_bytes()),
        'source_actual_files': len(files),
        'all_source_files_unchanged': not modified, 'modified_files': modified,
        'private_xdg': private_xdg, 'physical_device_tested': False,
        'ok': record['exit_code'] == 0 and not record['timed_out']
              and checks == expected_checks and failures == 0
              and not record['error_markers'] and not modified,
        'scope': 'Actual production Main native manual landing, separate save/cold factory, '
                 'queued takeoff, exact ordinary return, frame scheduling and optional report '
                 'ZIP from the exact fresh source archive. Repeated portability checks are '
                 'excluded from distinct functional totals; no Android execution.'}
    write_report('native-landing-main-feature.json', feature)
    assert feature['ok'], feature

    fixture_path = project / FIXTURE
    expected_fixture = sha(fixture_path.read_bytes())
    assert expected_fixture == FIXTURE_SHA256
    archived_fixture = json.loads(fixture_path.read_text())
    assert archived_fixture['case_count'] == 402
    proof = project / LIFECYCLE / 'native-proof'
    archived_validation = json.loads((proof / 'validation.json').read_text())
    assert archived_validation['checks'] == 6208 and archived_validation['failures'] == 0
    assert archived_validation['fixture_sha256'] == expected_fixture
    assert archived_validation['counts']['native_replayed_cases'] == 402
    work = BASE / 'native-rebuild-work'
    assert not work.exists(), 'Native generator must use a fresh build directory'
    native_commands = []
    for name, command in [
        ('generator', ['python3', str(proof / 'rebuild_source_contact_lifecycle_native.py'),
                       '--work', str(work)]),
        ('validator', ['python3', str(proof / 'validate_source_contact_lifecycle_native.py'),
                       '--replay']),
    ]:
        native_record, _ = run(command, 'source-native-' + name + '.log')
        native_record['name'] = name
        native_commands.append(native_record)
    modified = changed()
    reproduced = sha(fixture_path.read_bytes()) == expected_fixture
    native = json.loads((proof / 'validation.json').read_text())
    errors = [line for row in native_commands for line in row['error_markers']]
    reproduction = {
        'schema': 'starfrontier-source-archive-native-contact-lifecycle-reproduction-v1',
        'source_commit': previous['source_commit'],
        'archive_sha256': previous['archive_sha256'],
        'fixture_sha256': expected_fixture,
        'fixture_reproduced_byte_exact': reproduced, 'commands': native_commands,
        'error_markers': errors, 'all_archived_files_unchanged': not modified,
        'modified_archived_files': modified, 'archived_files': len(files),
        'native_validation_checks': native['checks'],
        'native_validation_failures': native['failures'],
        'native_control_cases': archived_fixture['case_count'],
        'native_replayed_cases': native['counts'].get('native_replayed_cases', 0),
        'native_bank_cases': {
            'full_F574_actor_calls': archived_fixture['actor_case_count'],
            'corrected_body_F574_requeries': archived_fixture['explicit_corrected_requery_case_count'],
            'restored_F1030_parked_updates': archived_fixture['parked_cold_tick_case_count'],
            'intercepted_F1047_entry_prefixes': archived_fixture['launch_entry_prefix_case_count']},
        'ok': all(row['exit_code'] == 0 and not row['timed_out'] for row in native_commands)
              and not errors and reproduced and not modified
              and native == archived_validation
              and native['checks'] == 6208 and native['failures'] == 0
              and native['counts'].get('native_replayed_cases') == 402,
        'scope': 'Archived original-instruction generator and --replay validator executed '
                 'inside the exact freshly extracted ZIP. All402 bounded F574/requery/'
                 'F1030/F1047-entry witnesses and the6208 validation checks replay; the '
                 'fixture and every archived source/proof file remain byte-exact. This '
                 'does not prove enabled-damage full F569/F570, complete launch, original '
                 'save format, Android lifecycle or physical device performance. '
                 'Repeated reproduction totals are excluded from distinct functional counts.'}
    write_report('source-native-reproduction.json', reproduction)
    assert reproduction['ok'], reproduction
    print(json.dumps({'feature_ok': feature['ok'], 'checks': checks,
                      'native_ok': reproduction['ok'],
                      'native_validation_checks': native['checks'],
                      'native_replayed_cases': native['counts']['native_replayed_cases'],
                      'all_archived_files_unchanged': not modified}, indent=2))


if __name__ == '__main__':
    main()
