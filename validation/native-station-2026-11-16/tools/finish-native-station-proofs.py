#!/usr/bin/env python3
"""Verify/consolidate one final code53 curated run; never run tests or builds.

Use --check-only for a read-only preflight. Otherwise exact runner/log/report
bytes and the derived unique summary/runtime freeze are copied to --output.
Native402/6208, packaging, capture and source-archive repetitions stay separate.
"""
from __future__ import annotations
import argparse
import ast
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

BASELINE = '837ad517d098b4a82aaff75a48dca89c4a157d06'
BASELINE_FREEZE = 'validation/native-return-2026-11-16/runtime-freeze.json'
FIXTURE = 'tests/fixtures/source_contact_lifecycle_native.json'
FIXTURE_SHA = '0db723a520144a55fa3846d80a3e1cad58b42c18d2f904500688a05ebfbf1f8b'
NATIVE_VALIDATION = 'validation/contact-lifecycle-2026-11-15/native-proof/validation.json'
FOLDERS = ('scripts', 'scenes', 'data', 'assets')
ROOTS = ('project.godot', 'export_presets.cfg', 'icon.svg', 'icon.svg.import')
CHANGED = {'scripts/main.gd','scripts/build_info.gd','export_presets.cfg'}
ADDED = {'scripts/'+name+suffix for name in ('native_station_frame','native_station_trial') for suffix in ('.gd','.gd.uid')}
PRIOR_REPORTS = {'source_natural_park': 'source-natural-park.json', 'source_natural_contact_session': 'source-natural-contact-session.json', 'source_native_surface_provider': 'source-native-surface-provider.json', 'source_native_surface_visual': 'source-native-surface-visual.json', 'native_surface_model': 'native-surface-model.json', 'native_landing_trial': 'native-landing-trial.json', 'native_landing_trial_integration': 'native-landing-trial-integration.json', 'native_landing_trial_main': 'native-landing-trial-main.json', 'native_surface_autopilot': 'native-surface-autopilot.json', 'native_surface_ascent': 'native-surface-ascent.json', 'native_orbit_trial': 'native-orbit-trial.json', 'native_autopilot_main': 'native-autopilot-main.json', 'native_ascent_main': 'native-ascent-main.json', 'native_orbit_main': 'native-orbit-main.json', 'native_orbit_return': 'native-orbit-return.json', 'native_return_main': 'native-return-main.json', 'native_return_descent': 'native-return-descent.json', 'native_return_descent_main': 'native-return-descent-main.json', 'dock_approach_guidance': 'dock-approach-guidance.json'}
NEW_REPORTS = {'native_station_frame': 'native-station-frame.json', 'native_station_trial': 'native-station-trial.json', 'native_station_main': 'native-station-main.json'}
COUNTS = re.compile(r'(?<!\d)(\d+)\s+checks,\s*(\d+)\s+failures\b')
BAD_LOG = re.compile(r'(?:SCRIPT ERROR:|^\s*ERROR:|ObjectDB instances leaked|Leaked instance:|'
                     r'resources still in use at exit|WARNING:[^\n]*\bleak(?:ed|s)?\b|'
                     r'RID allocations[^\n]*(?:leak|exit)|Unicode parsing error|'
                     r'Traceback \(most recent call last\))', re.I | re.M)


def require(ok, message):
    if not ok:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    value = json.loads(path.read_text())
    require(isinstance(value, dict), 'Expected a JSON object: '+str(path))
    return value


def file_at(project, name):
    path = (project/name).resolve()
    require(path.is_relative_to(project) and path.is_file() and not (project/name).is_symlink(),
            'Missing/unsafe project input: '+str(name))
    return path


def evidence_file(project, value):
    path = Path(value)
    path = (path if path.is_absolute() else project/path).resolve()
    require(path.is_file() and any(path.is_relative_to(root) for root in
            (project, Path('/workspace/recovery'), Path('/tmp'))), 'Missing/unsafe evidence: '+str(value))
    return path


def git(project, *args):
    return subprocess.check_output(['git', '-C', str(project), *args])


def runtime_name(name):
    return name in ROOTS or any(name.startswith(folder+'/') for folder in FOLDERS)


def runtime_files(project):
    names = git(project, 'ls-files', '-z', '--cached', '--others', '--exclude-standard',
                '--', *ROOTS, *FOLDERS).decode().split('\0')
    return {name: digest(file_at(project, name)) for name in sorted(set(filter(None, names)))}


def baseline_files(project):
    require(git(project, 'rev-parse', BASELINE).decode().strip() == BASELINE, 'Missing exact code52 baseline')
    names = git(project, 'ls-tree', '-r', '--name-only', '-z', BASELINE).decode().split('\0')
    files = {name: hashlib.sha256(git(project, 'show', BASELINE+':'+name)).hexdigest()
             for name in sorted(filter(None, names)) if runtime_name(name)}
    freeze = json.loads(git(project, 'show', BASELINE+':'+BASELINE_FREEZE))
    require(len(files) == 471 and files == freeze['files_sha256'], 'Code52 actual Git bytes differ from its471-input freeze')
    return files


def registry(project):
    path = file_at(project, 'tools/validate_rebuild.py')
    entries = {}
    for node in ast.walk(ast.parse(path.read_text())):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == 'Suite' and len(node.args) >= 2:
            if all(isinstance(arg, ast.Constant) and isinstance(arg.value, str) for arg in node.args[:2]):
                name, script = (arg.value for arg in node.args[:2])
                require(name not in entries, 'Duplicate suite registry name: '+name)
                entries[name] = script
    for name in NEW_REPORTS:
        require(entries.get(name) == 'tests/test_'+name+'.gd', 'Missing/changed new suite registration: '+name)
    return entries


def declared_pins(project, report, source):
    pins = report.get('sources', report.get('source_sha256', {}))
    require(isinstance(pins, dict), 'Invalid declared source pins: '+str(source))
    for name, expected in pins.items():
        require(isinstance(name, str) and isinstance(expected, str) and re.fullmatch('[0-9a-f]{64}', expected), 'Malformed declared source hash')
        require(digest(file_at(project, name)) == expected, 'Stale source pin: '+name+' in '+str(source))
    return dict(sorted(pins.items()))


def build(project, output, summary_path, freeze_path):
    known = registry(project)
    runner = read(summary_path)
    require(runner.get('schema') == 1 and runner.get('project') == str(project), 'Wrong runner schema/project')
    require(runner.get('status') in ('passed', 'passed_with_coverage_limitations') and runner.get('failures') == 0
            and not runner.get('failed_suites') and not runner.get('unavailable_suites'), 'Curated runner is not fully passing')
    require(isinstance(runner.get('suites'), list) and runner['suites'], 'Empty selected suite list')
    rows, tests, copies = {}, set(), [(summary_path, output/'regression-summary.json')]
    proof_hashes = {(output/'regression-summary.json').relative_to(project).as_posix(): digest(summary_path)}
    registry_path = file_at(project, 'tools/validate_rebuild.py')
    proof_hashes['tools/validate_rebuild.py'] = digest(registry_path)
    for row in runner['suites']:
        name = row.get('name')
        require(name in known and name not in rows, 'Unregistered/duplicate selected suite: '+str(name))
        require(row.get('status') == 'passed' and row.get('exit_code') == 0 and row.get('failures') == 0
                and not row.get('timed_out') and not row.get('diagnostics'), 'Nonpassing selected suite: '+name)
        require(type(row.get('checks')) is int and row['checks'] > 0 and row.get('summary_lines') == 1, 'Ambiguous/missing positive summary: '+name)
        source = row.get('suite_source', {})
        require(source.get('path') == known[name] and source['path'] not in tests, 'Foreign/duplicate test source: '+name)
        test = file_at(project, source['path'])
        require(source.get('sha256') == digest(test) and source.get('bytes') == test.stat().st_size, 'Test source changed: '+name)
        tests.add(source['path'])
        log = evidence_file(project, row['log'])
        text = log.read_text(errors='replace')
        require(not BAD_LOG.search(text) and COUNTS.findall(text) == [(str(row['checks']), '0')], 'Error/leak/ambiguous count in final selected log: '+name)
        target = output/'regression'/'logs'/(name+'.log')
        copies.append((log, target)); proof_hashes[target.relative_to(project).as_posix()] = digest(log)
        rows[name] = {'name': name, 'test': source['path'], 'checks': row['checks'], 'failures': 0,
                      'executed_utc': row.get('executed_utc'), 'test_source_sha256': source['sha256'],
                      'proof': (output/'regression-summary.json').relative_to(project).as_posix(),
                      'log': target.relative_to(project).as_posix()}
    require(set(NEW_REPORTS) <= set(rows), 'All three new code53 suites must be present')
    require(sum(row['checks'] for row in rows.values()) == runner.get('checks')
            and len(rows) == runner.get('passed_suites'), 'Runner unique totals do not match selected rows')
    report_pins, unpinned, standalone_paths = {}, [], {}
    for name, filename in {**PRIOR_REPORTS, **NEW_REPORTS}.items():
        if name not in rows:
            continue
        path = file_at(project, 'build/current-test-reports/'+filename)
        report = read(path)
        require(report.get('checks') == rows[name]['checks'] and report.get('failures') == 0, 'Standalone/runner count mismatch: '+name)
        pins = declared_pins(project, report, path)
        if pins:
            require(pins.get(rows[name]['test']) == rows[name]['test_source_sha256'], 'Standalone test itself is not pinned: '+name)
        else:
            unpinned.append(name)
        destination = output/filename
        copies.append((path, destination)); proof_hashes[destination.relative_to(project).as_posix()] = digest(path)
        report_pins[name] = pins; standalone_paths[name] = destination.relative_to(project).as_posix()
    fixture = file_at(project, FIXTURE); native_validation = file_at(project, NATIVE_VALIDATION)
    native, bank = read(fixture), read(native_validation)
    require(digest(fixture) == FIXTURE_SHA and native.get('case_count') == 402 and bank.get('checks') == 6208
            and bank.get('failures') == 0 and bank.get('fixture_sha256') == FIXTURE_SHA
            and bank.get('counts', {}).get('native_replayed_cases') == 402, 'Reused native bank is not the unchanged published402/6208 fixture')
    proof_hashes[FIXTURE] = FIXTURE_SHA; proof_hashes[NATIVE_VALIDATION] = digest(native_validation)
    current, old = runtime_files(project), baseline_files(project)
    removed = sorted(set(old)-set(current)); changed = sorted(name for name in old if current.get(name) != old[name]); added = sorted(set(current)-set(old))
    require(not removed and set(changed) == CHANGED and set(added) == ADDED and len(current) == 475,
            'Unexpected runtime delta: changed='+str(changed)+' added='+str(added)+' removed='+str(removed)+' count='+str(len(current)))
    info = file_at(project, 'scripts/build_info.gd').read_text()
    version = re.search(r'^const VERSION\s*:?=\s*"([^"]+)"\s*$', info, re.M)
    code = re.search(r'^const VERSION_CODE\s*:?=\s*(\d+)\s*$', info, re.M)
    require(version and code and int(code.group(1)) == 53 and 'native-station' in version.group(1), 'Metadata is not native-station code53')
    require(runtime_files(project) == current, 'Runtime changed during evidence consolidation')
    created = dt.datetime.now(dt.timezone.utc).isoformat()
    common = {'version': version.group(1), 'version_code': 53, 'created_utc': created,
              'bounded_host_guidance': True, 'affine_space_handoff': True, 'inverse_affine_return': True,
              'velocity_transform_policy': 'same-time-nonrotating-frame-offset-and-source-ephemeris-origin-velocity-v1',
              'prior_surface_orbit_velocity_policy': 'rotate-bodyfixed-phone-velocity-no-added-omega-cross-radius-v1',
              'station_origin_velocity_sampler': 'source-clock-central-plus-minus-0.5-seconds-with-one-sided-boundaries',
              'continuing_station_flight_law': 'existing-mobile-station-following',
              'full_inertial_trajectory_equivalence_proven': False,
              'circular_orbit_inserted': False, 'full_original_object_bank': False,
              'original_autopilot_fully_ported': False, 'physical_device_tested': False,
              'production_release_ready': False, 'full_original_port_complete': False}
    final = dict(common, schema='starfrontier-native-station-unique-targeted-summary-v1', status='passed',
                 checks=sum(row['checks'] for row in rows.values()), failures=0, passed_suites=len(rows),
                 new_suites=len(NEW_REPORTS), prior_native_suites=len(set(rows)&set(PRIOR_REPORTS)),
                 old_suites=len(set(rows)-set(PRIOR_REPORTS)-set(NEW_REPORTS)), suites=list(rows.values()),
                 proofs_sha256=dict(sorted(proof_hashes.items())), selected_report_source_pins=report_pins,
                 standalone_report_paths=standalone_paths, standalone_reports_without_internal_runtime_pins=unpinned,
                 current_runtime_source_sha256={name: current[name] for name in sorted(CHANGED | {name for name in ADDED if name.endswith('.gd')})},
                 all_suite_source_fingerprints_verified=True, declared_report_source_pins_verified=True,
                 runtime_unchanged_during_consolidation=True, historical_totals_added=False,
                 failed_development_runs_added=False, fresh_process_repeats_added=False,
                 portability_repeats_added=False, capture_checks_added=False, python_checks_added=False,
                 new_native_control_cases=0, reused_native_control_cases=402,
                 reused_native_fixture_sha256=FIXTURE_SHA, native_reproduction_validator_checks_separate=6208,
                 native_control_case_counts_added=False, native_validator_checks_added=False,
                 new_original_native_oracle_claimed=False, default_v4_terrain_retained=True,
                 scope='Exactly one current passing result per selected unique registered script. Three new station-frame, atomic station-trial and actual Main suites are mandatory. Source fingerprints, declared source pins and logs verified; old native402/6208, Python packaging, GPU frames and clean-source repeats remain separate. The bounded same-time handoff and reverse, and existing station-following mobile flight law do not prove continuing inertial-trajectory equivalence, full F570/F606/F597/AI, the full original frame bank, circular orbit, universal terrain, a flown35Mm transit, Android/FPS or full-clone completion.')
    freeze = dict(common, schema='starfrontier-native-station-runtime-freeze-v1', files_sha256=current,
                  files=len(current), frozen_file_count=len(current), previous_code52_commit=BASELINE,
                  previous_code52_files=len(old), unchanged_previous_files=len(old)-len(changed),
                  changed_previous_files=changed, added_files=added, removed_previous_files=removed,
                  default_v4_physics_preserved=True,
                  collection_policy='Git tracked+untracked nonignored regular files under scripts/scenes/data/assets and project.godot/export_presets.cfg/icon.svg/icon.svg.import; no tests/tools/docs/private caches.',
                  scope='Actual475 current runtime inputs versus the actual471 published code52 inputs:468 unchanged; only Main/BuildInfo/export changed; two new modules plus theirUID. Existing source contact/physics/fuel/HP/gear/station kernels and assets stay byte-exact.')
    copies += [(None, output/'final-targeted-summary.json'), (None, freeze_path)]
    return copies, final, freeze


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=Path('/workspace/Pyton'))
    parser.add_argument('--summary', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=Path('validation/native-station-2026-11-16'))
    parser.add_argument('--freeze', type=Path, help='Freeze JSON path inside --output; default: --output/runtime-freeze.json')
    parser.add_argument('--check-only', action='store_true')
    args = parser.parse_args()
    project = args.project.resolve(); output = (project/args.output).resolve()
    require(output.is_relative_to(project/'validation') and output != project/'validation', '--output must be a current validation subdirectory')
    freeze_path = (project/args.freeze).resolve() if args.freeze else output/'runtime-freeze.json'
    require(freeze_path.is_relative_to(output), '--freeze must be inside --output')
    summary_path = evidence_file(project, args.summary)
    copies, final, freeze = build(project, output, summary_path, freeze_path)
    if not args.check_only:
        for source, target in copies:
            if source is not None and source != target:
                target.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(source, target)
        for target, content in [(output/'final-targeted-summary.json', final), (freeze_path, freeze)]:
            target.parent.mkdir(parents=True, exist_ok=True); target.write_text(json.dumps(content, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps({'written': not args.check_only, 'checks': final['checks'], 'suites': final['passed_suites'],
                      'new_suites': final['new_suites'], 'runtime_inputs': freeze['files'],
                      'unchanged_previous': freeze['unchanged_previous_files'],
                      'changed_code52_files': freeze['changed_previous_files'], 'added_runtime_files': freeze['added_files']}, indent=2))


if __name__ == '__main__':
    main()
