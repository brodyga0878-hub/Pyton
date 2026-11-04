#!/usr/bin/env python3
"""Check, build, verify and package a local Android test candidate; never publish it."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import uuid
import zipfile

from verify_android import verify


EXCLUDED_DIRS = {
    '.git', '.godot', 'build', '__pycache__', '.venv', 'venv', 'keys',
    '.aws', '.codex', '.agents', '.ssh', '.gnupg', 'node_modules',
}
EXCLUDED_SUFFIXES = {
    '.exe', '.asm', '.pyc', '.keystore', '.jks', '.key', '.pem', '.p12', '.pfx',
    '.dmp', '.rar', '.7z', '.zip', '.apk', '.aab', '.argosmodel',
}
ANSI = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')


def sha256(path: Path) -> str:
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(block)
    return result.hexdigest()


def write_json(path: Path, value: object) -> None:
    temporary = path.with_name(path.name + '.partial')
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n')
    temporary.replace(path)


def project_version(project: Path) -> tuple[str, int]:
    presets = (project / 'export_presets.cfg').read_text()
    name = re.search(r'^version/name="([^"]+)"\s*$', presets, re.M)
    code = re.search(r'^version/code=(\d+)\s*$', presets, re.M)
    if not name or not code:
        raise ValueError('Cannot read Android version/name and version/code from export_presets.cfg')
    return name[1], int(code[1])


def reject_engine_errors(value: str, stage: str) -> None:
    text = ANSI.sub('', value)
    pattern = (
        r'^\s*(?:SCRIPT ERROR:|ERROR:|FAIL:|FAILED(?:\s|$))'
        r'|ObjectDB instances leaked|RID allocations of type|\bSMOKE FAILED:'
        r'|\b[1-9]\d* failures\b'
    )
    if re.search(pattern, text, re.M):
        raise ValueError(f'{stage} reported errors, failures or leaked engine objects')


def parse_validation(log_text: str, check_script: str) -> dict:
    text = ANSI.sub('', log_text)
    reject_engine_errors(text, 'Validation')
    python_counts = re.findall(r'^Ran (\d+) tests? in ', text, re.M)
    if len(python_counts) != 1 or not re.search(r'^OK(?: \([^\n]*\))?$', text, re.M):
        raise ValueError('Validation lacks one successful Python unittest summary')
    expected = re.search(r'for suite in (.*?); do', check_script, re.S)
    if not expected:
        raise ValueError('Cannot determine required Godot suites from tools/check.sh')
    expected_suites = shlex.split(expected[1])
    expected_smokes = re.findall(r'^run_godot[^\n]*\s--\s(--[a-z0-9-]+)\s*$', check_script, re.M)
    rows = re.findall(r'^([A-Z0-9 /_-]+ TESTS): (\d+) checks, (\d+) failures', text, re.M)
    suites = {name: int(count) for name, count, _ in rows}
    smokes = re.findall(r'^([A-Z0-9 /_-]*SMOKE) PASS:', text, re.M)
    if len(rows) != len(suites) or len(suites) != len(expected_suites):
        raise ValueError(f'Expected {len(expected_suites)} distinct Godot suite summaries; found {len(suites)}')
    if not expected_smokes or len(smokes) != len(expected_smokes) or len(set(smokes)) != len(smokes):
        raise ValueError(f'Expected {len(expected_smokes)} distinct smoke passes; found {len(smokes)}')
    if any(int(failures) for _, _, failures in rows):
        raise ValueError('Godot validation has failing assertions')
    python_tests = int(python_counts[0])
    return {
        'python_tests': python_tests,
        'godot_suites': len(suites),
        'godot_assertions': sum(suites.values()),
        'checks_and_assertions': python_tests + sum(suites.values()),
        'smoke_scenarios': len(smokes),
        'failures': 0,
        'godot_suite_counts': suites,
        'smoke_names': smokes,
    }


def source_files(project: Path, destinations: tuple[Path, ...]) -> list[Path]:
    result = []
    for path in sorted(project.rglob('*')):
        relative = path.relative_to(project)
        if path.is_symlink() or not path.is_file():
            continue
        if not path.resolve().is_relative_to(project):
            continue
        if any(part.lower() in EXCLUDED_DIRS for part in relative.parts):
            continue
        if any(path.is_relative_to(destination) for destination in destinations):
            continue
        if path.suffix.lower() in EXCLUDED_SUFFIXES or path.name == 'core':
            continue
        if any(part.lower().startswith('.env') for part in relative.parts):
            continue
        result.append(path)
    if not result:
        raise ValueError('Source package would be empty')
    return result


def fingerprint(paths: list[Path], project: Path) -> str:
    result = hashlib.sha256()
    for path in paths:
        # Godot may create these generated selectors while exporting. They do not
        # change the checked implementation; they are still included in the ZIP.
        if path.suffix in {'.uid', '.import'}:
            continue
        result.update(path.relative_to(project).as_posix().encode())
        result.update(b'\0')
        result.update(bytes.fromhex(sha256(path)))
    return result.hexdigest()


def run_logged(command: list[str], project: Path, log: Path, stage: str) -> None:
    print(f'{stage}: {log}', flush=True)
    with log.open('w') as output:
        result = subprocess.run(command, cwd=project, stdout=output, stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError(f'{stage} exited with code {result.returncode}; see {log}')
    reject_engine_errors(log.read_text(errors='replace'), stage)


def build_candidate(project: Path, log: Path) -> Path:
    target = project / 'build/starfrontier-arm64-rc.apk'
    backup = target.with_name('.candidate-previous-' + uuid.uuid4().hex + '.apk')
    if target.is_symlink():
        raise ValueError('Candidate build target must not be a symlink')
    had_previous = target.exists()
    if had_previous:
        target.replace(backup)
    try:
        run_logged(['sh', str(project / 'tools/build_android.sh'), '--candidate'], project, log, 'Android build')
        if not target.is_file() or target.is_symlink():
            raise ValueError('Android export did not create a new regular APK')
    except BaseException:
        if target.exists() and not target.is_symlink():
            target.unlink()
        if had_previous:
            backup.replace(target)
        raise
    else:
        if had_previous:
            backup.unlink()
    return target


def make_zip(target: Path, entries: list[tuple[Path, str]]) -> None:
    temporary = target.with_name(target.name + '.partial')
    try:
        with zipfile.ZipFile(temporary, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for path, name in entries:
                archive.write(path, name)
        with zipfile.ZipFile(temporary) as archive:
            broken = archive.testzip()
            if broken:
                raise ValueError(f'ZIP verification failed for {broken}')
        temporary.replace(target)
    finally:
        if temporary.exists():
            temporary.unlink()


def describe(path: Path) -> dict:
    return {'file': path.name, 'bytes': path.stat().st_size, 'sha256': sha256(path)}


def prepare(args: argparse.Namespace) -> Path:
    project, output, logs = args.project.resolve(), args.output.resolve(), args.logs.resolve()
    for destination in (output, logs):
        if project.is_relative_to(destination):
            raise ValueError('Output/log directories must not contain the entire project')
        destination.mkdir(parents=True, exist_ok=True)
    if args.previous and (not args.previous.is_file() or args.previous.is_symlink()):
        raise ValueError('Previous APK must be a regular file')
    for program in ('apksigner', 'zipalign', 'aapt'):
        if not (args.build_tools / program).is_file():
            raise ValueError(f'Missing Android verification tool: {args.build_tools / program}')
    manifest_path = output / f'{args.label}-artifact.json'
    if manifest_path.exists():
        raise ValueError('This label already has a completed candidate; choose a new label')
    version, version_code = project_version(project)
    destinations = (output, logs)
    initial_fingerprint = fingerprint(source_files(project, destinations), project)
    validation_log = logs / f'{args.label}-validation.log'
    run_logged(['sh', str(project / 'tools/check.sh')], project, validation_log, 'Full validation')
    summary = parse_validation(validation_log.read_text(), (project / 'tools/check.sh').read_text())
    write_json(logs / f'{args.label}-validation-summary.json', summary)
    apk = build_candidate(project, logs / f'{args.label}-android-build.log')
    print('Verifying APK signature, package, assets and alignment', flush=True)
    verified = verify(apk, args.build_tools.resolve(), args.previous.resolve() if args.previous else None)
    if verified['version'] != version or verified['version_code'] != version_code or verified['debuggable']:
        raise ValueError('Verified APK does not match the configured release candidate')
    write_json(logs / f'{args.label}-apk-verification.json', verified)
    paths = source_files(project, destinations)
    if fingerprint(paths, project) != initial_fingerprint:
        raise ValueError('Project files changed during checks/build; rerun against a stable project')
    readiness = json.loads((project / 'docs/release_readiness.json').read_text())
    blockers = list(readiness.get('remaining', []))
    for flag in ('full_original_port_complete', 'full_russian_localization_complete',
                 'physical_device_tested', 'production_signing_key_configured'):
        if readiness.get(flag) is not True:
            blockers.append(flag)
    apk_output = output / f'starfrontier-{args.label}-arm64-alpha.apk'
    source_output = output / f'starfrontier-{args.label}-source.zip'
    report_output = output / f'starfrontier-{args.label}-report.zip'
    print('Packaging APK, source and verification report', flush=True)
    temporary_apk = apk_output.with_name(apk_output.name + '.partial')
    shutil.copy2(apk, temporary_apk)
    if sha256(temporary_apk) != verified['sha256']:
        temporary_apk.unlink()
        raise ValueError('Copied APK checksum differs from the verified binary')
    temporary_apk.replace(apk_output)
    make_zip(source_output, [(path, path.relative_to(project).as_posix()) for path in paths])
    report_entries = [(path, path.relative_to(project).as_posix()) for path in paths
                      if path.is_relative_to(project / 'docs') or path == project / 'README.md']
    for path in sorted(logs.glob(args.label + '*')):
        if path.is_file() and not path.is_symlink() and path.suffix in {'.log', '.json', '.txt', '.png'}:
            report_entries.append((path, 'verification/' + path.name))
    for path in sorted(output.glob(args.label + '*.png')):
        if path.is_file() and not path.is_symlink():
            report_entries.append((path, 'screenshots/' + path.name))
    make_zip(report_output, report_entries)
    if fingerprint(source_files(project, destinations), project) != initial_fingerprint:
        raise ValueError('Project files changed while packaging; no completed manifest was written')
    manifest = {
        'label': args.label,
        'created_utc': datetime.now(timezone.utc).isoformat(),
        'version': version,
        'version_code': version_code,
        'new_apk_built': True,
        **summary,
        'source_snapshot_sha256': initial_fingerprint,
        'source_snapshot_excludes_generated_uid_and_import_selectors': True,
        'apk_verification': verified,
        'readiness_snapshot': readiness,
        'release_blockers': blockers,
        'publication_ready': False,
        'published': False,
        'scope': 'Local test candidate only; this pipeline never grants release readiness or publishes.',
        'artifacts': [describe(path) for path in (apk_output, source_output, report_output)],
    }
    write_json(manifest_path, manifest)
    print(json.dumps({'manifest': str(manifest_path), 'version': version,
                      'python_tests': summary['python_tests'], 'godot_assertions': summary['godot_assertions'],
                      'smoke_scenarios': summary['smoke_scenarios'], 'publication_ready': False,
                      'artifacts': manifest['artifacts']}, indent=2), flush=True)
    return manifest_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True, help='Unique artifact label, for example stage10-19-20')
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path, default=Path('/workspace/deliverables'))
    parser.add_argument('--logs', type=Path, default=Path('/workspace/ffe-review'))
    parser.add_argument('--previous', type=Path, help='Previously delivered APK for certificate continuity')
    parser.add_argument('--build-tools', type=Path, default=Path('/workspace/toolchains/android-sdk/build-tools/35.0.1'))
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z0-9][a-z0-9_.-]*', args.label):
        parser.error('--label must contain only lowercase letters, digits, dots, underscores and hyphens')
    try:
        prepare(args)
    except (OSError, ValueError, RuntimeError, AssertionError, subprocess.SubprocessError) as error:
        print(f'Candidate preparation failed: {error}', file=sys.stderr, flush=True)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
