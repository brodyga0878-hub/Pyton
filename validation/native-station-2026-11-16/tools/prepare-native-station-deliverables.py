#!/usr/bin/env python3
"""Validate frozen code53 evidence, then seal its public bundle exactly once.

No tests, builds, network or Git mutations. --check-only validates every gate
without writing. All existing outputs are checked before the first copy.
"""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import struct
import subprocess
import zipfile

VERSION = '0.28.0-native-station-alpha1'
CODE = 53
APK = 'StarFrontier-0.28.0-native-station-arm64.apk'
SOURCE = 'StarFrontier-0.28.0-native-station-source.zip'
REPORT = 'sample-native-station-include-save-report.zip'
APK_BYTES = 50482957
APK_SHA = '936bbd78769e1e22f754bcab020de89ea72f457eea4c829448391dd5771538bf'
FIXTURE = 'tests/fixtures/source_contact_lifecycle_native.json'
FIXTURE_SHA = '0db723a520144a55fa3846d80a3e1cad58b42c18d2f904500688a05ebfbf1f8b'
NATIVE_PROOF = 'validation/contact-lifecycle-2026-11-15/native-proof'
VNAME = 'validation/native-station-2026-11-16'
PNAME = 'validation/native-station-source-portability-2026-11-16'
PREVIOUS_FREEZE = 'validation/native-return-2026-11-16/runtime-freeze.json'
PREVIOUS_COMMIT = '837ad517d098b4a82aaff75a48dca89c4a157d06'
CHANGED = {'scripts/main.gd', 'scripts/build_info.gd', 'export_presets.cfg'}
ADDED = {'scripts/' + name + suffix for name in ('native_station_frame', 'native_station_trial')
         for suffix in ('.gd', '.gd.uid')}
TASKS = {'tests/test_native_station_frame.gd': 'pure_kernel',
         'tests/test_native_station_trial.gd': 'pure_kernel',
         'tests/test_native_station_main.gd': 'actual_Main'}
MAIN_TEST = 'tests/test_native_station_main.gd'
FRAME_NAMES = ['01-earth-station-selection-1440x720.png', '02-native-station-approach-1440x720.png',
               '03-native-station-services-960x432.png', '04-native-station-reverse-960x432.png']
FRAME_PHASES = ['station_selection', 'station_approach', 'station_services', 'body_frame_return']


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    value = json.loads(path.read_text())
    require(isinstance(value, dict), 'Expected JSON object: ' + str(path))
    return value


def safe(name):
    require(isinstance(name, str) and name, 'Empty/non-string payload path')
    path = PurePosixPath(name)
    require(not path.is_absolute() and '..' not in path.parts and str(path) == name
            and '\\' not in name and all(ord(char) >= 32 for char in name),
            'Unsafe payload path: ' + repr(name))
    return path


def git(root, *args, raw=None):
    return subprocess.check_output(['git', '-C', str(root), *args], input=raw)


def verify_git_runtime(root, commit, freeze_raw, frozen):
    require(git(root, 'rev-parse', commit).decode().strip() == commit, 'Source commit unavailable in Git')
    require(git(root, 'show', commit + ':' + VNAME + '/runtime-freeze.json') == freeze_raw,
            'Git source commit does not contain the exact validated runtime freeze')
    names = sorted(frozen)
    raw = git(root, 'cat-file', '--batch', raw=''.join(commit + ':' + name + '\n' for name in names).encode())
    offset = 0
    for name in names:
        end = raw.index(b'\n', offset)
        header = raw[offset:end].split()
        offset = end + 1
        require(len(header) == 3 and header[1] == b'blob', 'Missing Git runtime blob: ' + name)
        size = int(header[2])
        body = raw[offset:offset + size]
        offset += size
        require(raw[offset:offset + 1] == b'\n', 'Malformed Git runtime batch stream')
        offset += 1
        require(hashlib.sha256(body).hexdigest() == frozen[name], 'Git runtime differs from freeze: ' + name)
    require(offset == len(raw), 'Unexpected trailing Git runtime batch data')


def public_files(folder, prefix=''):
    private = {'state', 'xdg', 'private-xdg', 'private_xdg', 'private-state', 'private_state',
               'runlogs', 'run-logs', '__pycache__', 'report-cache', 'test-report-cache',
               'test_report_cache', 'testreportcache', '.git', '.godot', '.aws', '.codex'}
    suffixes = {'.json', '.log', '.md', '.txt', '.png', '.zip', '.py', '.s', '.asm', '.c', '.sh', '.gd', '.uid'}
    result = {}
    for path in sorted(folder.rglob('*')):
        relative = path.relative_to(folder)
        if not path.is_file():
            continue
        if any(part.lower() in private or part.lower().startswith('intermediate') for part in relative.parts):
            continue
        if path.name == 'android-verification.log' or any(value in path.name.lower() for value in ('runner', 'rerun')):
            continue
        if path.suffix.lower() not in suffixes:
            continue
        require(not path.is_symlink(), 'Symlink in final public proof tree: ' + str(path))
        name = prefix + relative.as_posix()
        safe(name)
        result[name] = path
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=Path('/workspace/Pyton'))
    parser.add_argument('--apk-source', type=Path, help='Default: build/starfrontier-rebuild-arm64-alpha.apk')
    parser.add_argument('--source-commit', help='Optional full immutable SHA, checked against source ZIP comment and Git freeze')
    parser.add_argument('--check-only', action='store_true')
    args = parser.parse_args()
    root = args.project.resolve()
    v, p, dest = root / VNAME, root / PNAME, root / 'deliverables' / VERSION
    apk = args.apk_source.resolve() if args.apk_source else root / 'build/starfrontier-rebuild-arm64-alpha.apk'
    bundle = dest / SOURCE
    require(not (dest / 'manifest.json').exists(), 'Refuse replacing an already sealed release manifest')
    require(dest.is_dir() and not dest.is_symlink() and dest.resolve().is_relative_to(root / 'deliverables'),
            'Unsafe new release directory')
    require(apk.is_file() and bundle.is_file() and not apk.is_symlink() and not bundle.is_symlink(),
            'Exact APK and existing nonsymlink source ZIP required')
    android, summary = read(v / 'android-verification.json'), read(v / 'final-targeted-summary.json')
    freeze_raw = (v / 'runtime-freeze.json').read_bytes()
    freeze, previous = json.loads(freeze_raw), read(root / PREVIOUS_FREEZE)
    packaging = read(v / 'packaging.json')
    capture, review = read(v / 'screenshots/capture-manifest.json'), read(v / 'screenshots/visual-review.json')
    fresh, feature, reproduction = read(p / 'verification.json'), read(p / 'native-station-feature.json'), read(p / 'source-native-reproduction.json')
    native, native_validation = read(root / FIXTURE), read(root / NATIVE_PROOF / 'validation.json')
    require(apk.stat().st_size == android['bytes'] == APK_BYTES and sha(apk) == android['sha256'] == APK_SHA,
            'Frozen actual APK bytes/SHA differ')
    require(android['version'] == VERSION and android['version_code'] == CODE and android['abi'] == 'arm64-v8a'
            and android['min_sdk'] == 24 and android['target_sdk'] == 36 and android['signature_verified']
            and android['test_key_only'] and not android['debuggable'] and android['zipalign_16k']
            and android['forbidden_permissions_absent'], 'APK identity/TEST/ARM64/SDK/signature gate failed')
    require(android['elf_load_alignment'] and all(value >= 16384 for values in android['elf_load_alignment'].values() for value in values),
            'ELF16KiB alignment gate failed')
    require(not any(android[key] for key in ('physical_device_tested', 'publication_ready', 'production_signing_key_configured', 'full_original_port_complete')),
            'Unsupported physical-device or release-ready claim')
    assets = android['native_station_assets']
    functions, scope = assets['protected_functions'], assets['station_continuation_scope']
    require(assets['version'] == VERSION and assets['version_code'] == CODE and assets['compiled_module_count'] == len(assets['compiled_modules']) == 2
            and assets['integration_compiled_module_count'] == len(assets['integration_compiled_modules']) == 58
            and set(assets['compiled_modules']) == {'native_station_frame', 'native_station_trial'}
            and len(assets['audited_local_source_sha256']) == 58, 'Actual two-new/58-core SDK audit failed')
    require(functions['unchanged_code52_core_source_count'] == len(functions['unchanged_code52_core_source_sha256']) == 55
            and functions['all_previous_nonMain_core_sources_byte_exact'], 'Protected previous55 core source audit failed')
    require(all(scope[key] for key in ('source_ephemeris_origin_difference_before_float', 'source_clock_sampled_origin_velocity',
            'float64_position_carry_used', 'private_source_clearance_and_atmosphere_checked', 'boundary_preserves_actual_pose_clock_hp_fuel',
            'atomic_existing_station_motion_and_source_fuel', 'authoritative_dock_launch_commands_retained', 'actual_paid_service_owner_retained',
            'station_float64_position_carry_preserved', 'canonical_body_hazard_observer_used', 'strict_typed_station_snapshot',
            'cold_source_spin_and_angular_history_replayed', 'reverse_preserves_current_motion_and_original_orbit_lineage',
            'actual_station_controls_connected', 'actual_paid_service_controls_connected', 'Main_preserves_station_spin_on_render_refresh',
            'station_payload_and_strict_decoder_connected', 'ordinary_progress_and_trial_saves_isolated', 'station_trial_connection_supported'))
            and not any(scope[key] for key in ('full_original_F570_F606_object_bank_proved', 'full_original_F597_autopilot_proved',
            'circular_orbit_insertion_proved', 'physical_device_tested', 'full_original_port_complete', 'new_original_autopilot_claimed'))
            and scope['same_parent_station_handoff_limit_m'] == 100000
            and scope['velocity_policy'] == 'source-ephemeris-origin-derivative-one-second-v1'
            and scope['ongoing_law'] == 'existing-station-following-mobile-flight-not-inertial-trajectory-equivalence',
            'Bounded station source/velocity/consumer scope differs')
    retained = assets['retained_runtime_inputs']
    require(retained['baseline_version_code'] == 52 and retained['previous_runtime_file_count'] == 471
            and retained['unchanged_runtime_file_count'] == 468 and retained['changed_runtime_file_count'] == 3
            and retained['all_old_undeclared_runtime_inputs_byte_exact'], 'SDK prior471 runtime protection failed')
    require(assets['metadata']['ui_and_preset_match'] and assets['metadata']['version'] == VERSION
            and assets['metadata']['version_code'] == CODE, 'UI/preset SDK metadata differ')
    rows = summary['suites']
    selected = {row['test']: row for row in rows}
    require(summary['version'] == VERSION and summary['version_code'] == CODE and summary['status'] == 'passed'
            and summary['failures'] == 0 and summary['passed_suites'] == len(rows) == len(selected) == 47
            and sum(row['checks'] for row in rows) == summary['checks']
            and all(row['checks'] > 0 and row['failures'] == 0 for row in rows)
            and summary['all_suite_source_fingerprints_verified'] and summary['declared_report_source_pins_verified']
            and summary['runtime_unchanged_during_consolidation'], '47 distinct final passing suites required')
    require(not any(summary.get(key, False) for key in ('historical_totals_added', 'failed_development_runs_added',
            'fresh_process_repeats_added', 'portability_repeats_added', 'capture_checks_added', 'python_checks_added',
            'native_control_case_counts_added', 'native_validator_checks_added', 'new_original_native_oracle_claimed')),
            'Repeated checks or unproved original oracle were added')
    require(packaging['version'] == VERSION and packaging['version_code'] == CODE
            and packaging['unit_test_count'] == packaging['unique_test_id_count'] == sum(packaging['unit_test_modules'].values()) == 431
            and len(packaging['unit_test_modules']) == 16
            and packaging['unit_test_failures'] == packaging['unit_test_errors'] == packaging['unit_test_skipped'] == packaging['test_exit_code'] == 0
            and packaging['tests_run_against_unmodified_project'] and not packaging['in_memory_pin_overrides'],
            '431 distinct successful packaging tests in16 modules required')
    frozen, old = freeze['files_sha256'], previous['files_sha256']
    changed = {name for name, digest in old.items() if frozen.get(name) != digest}
    added = set(frozen) - set(old)
    require(freeze['version'] == VERSION and freeze['version_code'] == CODE
            and freeze['files'] == freeze['frozen_file_count'] == len(frozen) == 475 and len(old) == 471
            and changed == CHANGED and added == ADDED and set(old) <= set(frozen)
            and freeze['unchanged_previous_files'] == 468 and set(freeze['changed_previous_files']) == changed
            and set(freeze['added_files']) == added and not freeze['removed_previous_files']
            and freeze['previous_code52_commit'] == assets['baseline_source_commit'] == PREVIOUS_COMMIT,
            'Frozen475 delta differs from exact471 code52 checkpoint')
    pins = {}
    def add_pins(values):
        for name, digest in values.items():
            safe(name)
            require(isinstance(digest, str) and re.fullmatch('[0-9a-f]{64}', digest), 'Malformed source digest: ' + name)
            require(name not in pins or pins[name] == digest, 'Conflicting source/proof pin: ' + name)
            require((root / name).is_file() and not (root / name).is_symlink() and sha(root / name) == digest,
                    'Changed frozen source/proof: ' + name)
            pins[name] = digest
    for values in (frozen, assets['audited_local_source_sha256'], assets['metadata']['source_sha256'],
                   functions['unchanged_code52_core_source_sha256'], packaging['source_sha256'], capture['source_sha256']):
        add_pins(values)
    require(sha(v / 'packaging-unit-tests.log') == packaging['log_sha256'], 'Packaging log changed')
    for values in summary.get('selected_report_source_pins', {}).values():
        add_pins(values)
    add_pins({row['test']: row['test_source_sha256'] for row in rows})
    add_pins(summary['proofs_sha256'])
    require(sha(root / FIXTURE) == FIXTURE_SHA and native['case_count'] == 402
            and native_validation['checks'] == 6208 and native_validation['failures'] == 0
            and native_validation['fixture_sha256'] == FIXTURE_SHA
            and native_validation['counts']['native_replayed_cases'] == 402, 'Original402/6208 native bank differs')
    add_pins({FIXTURE: FIXTURE_SHA})
    require(bundle.stat().st_size < 32 * 1024 * 1024, 'Source ZIP exceeds32MiB chat-upload bound')
    for path in (apk, bundle, v / REPORT):
        with zipfile.ZipFile(path) as archive:
            require(archive.testzip() is None, 'Archive CRC failed: ' + path.name)
    with zipfile.ZipFile(bundle) as archive:
        commit = archive.comment.decode('ascii')
        require(re.fullmatch('[0-9a-f]{40}', commit), 'Source ZIP requires a full Git commit comment')
        require(args.source_commit is None or args.source_commit == commit, 'Expected source commit differs from ZIP')
        entries = archive.infolist()
        actual_files = sum(not row.is_dir() for row in entries)
        require(len({row.filename for row in entries}) == len(entries), 'Duplicate source ZIP entry')
        for row in entries:
            safe(row.filename.rstrip('/'))
            require(stat.S_IFMT(row.external_attr >> 16) != stat.S_IFLNK, 'Source ZIP symlink')
        projects = [PurePosixPath(row.filename) for row in entries if PurePosixPath(row.filename).name == 'project.godot']
        require(projects, 'Missing source project')
        depth = min(len(path.parts) for path in projects)
        primary = [path for path in projects if len(path.parts) == depth]
        require(len(primary) == 1, 'Ambiguous source root')
        prefix = '' if str(primary[0].parent) == '.' else str(primary[0].parent) + '/'
        verify_git_runtime(root, commit, freeze_raw, frozen)
        require(fresh['ok'] and fresh['source_commit'] == fresh['archive_commit_comment'] == commit
                and fresh['archive_sha256'] == sha(bundle) and fresh['archive_bytes'] == bundle.stat().st_size
                and fresh['archive_file_count'] == actual_files and fresh['fresh_extraction'] and fresh['private_xdg']
                and fresh['startup_checks'] == 10 and fresh['startup_failures'] == 0 and fresh['archive_crc_ok']
                and fresh['extracted_archive_files_unchanged'] and not fresh['modified_archive_files'], 'Fresh source import/startup failed')
        require(feature['ok'] and feature['source_commit'] == commit and feature['archive_sha256'] == sha(bundle)
                and feature['source_actual_files'] == actual_files and feature['unique_feature_scripts'] == len(feature['features']) == 3
                and {row['test']: row['layer'] for row in feature['features']} == TASKS
                and feature['pure_kernel_feature_scripts'] == 2 and feature['actual_Main_feature_scripts'] == 1
                and feature['primary_feature_script'] == MAIN_TEST
                and feature['unique_feature_checks_separate'] == sum(row['checks'] for row in feature['features'])
                and feature['pure_kernel_feature_checks_separate'] == sum(row['checks'] for row in feature['features'] if row['layer'] == 'pure_kernel')
                and feature['actual_Main_feature_checks_separate'] == feature['checks'] == feature['expected_checks_from_archived_final_report'] == selected[MAIN_TEST]['checks']
                and feature['pinned_runtime_inputs_verified'] == 475 and feature['runtime_freeze_sha256'] == hashlib.sha256(freeze_raw).hexdigest()
                and feature['all_runtime_inputs_match_frozen_source'] and feature['all_source_files_unchanged']
                and not feature['modified_files'] and not feature['error_markers'] and feature['failures'] == 0,
                'Fresh proof requires two pure kernels plus one actual Main, counted separately')
        for row in feature['features']:
            require(row['ok'] and row['exit_code'] == row['failures'] == 0 and not row['timed_out'] and not row['error_markers']
                    and row['private_xdg'] and row['all_source_files_unchanged'] and not row['modified_files']
                    and row['source_actual_files'] == actual_files
                    and row['checks'] == row['expected_checks_from_archived_final_report'] == selected[row['test']]['checks'],
                    'Fresh feature differs from archived selected proof: ' + row['test'])
            add_pins(row['declared_source_pins'])
        for name, digest in pins.items():
            require(prefix + name in archive.namelist() and hashlib.sha256(archive.read(prefix + name)).hexdigest() == digest,
                    'Archived source/proof input differs: ' + name)
        required = [VNAME + '/runtime-freeze.json', VNAME + '/final-targeted-summary.json', NATIVE_PROOF + '/validation.json',
                    *summary['standalone_report_paths'].values()]
        for name in required:
            require(prefix + name in archive.namelist() and hashlib.sha256(archive.read(prefix + name)).hexdigest() == sha(root / name),
                    'Archived final functional evidence differs: ' + name)
    require(reproduction['ok'] and reproduction['source_commit'] == commit and reproduction['archive_sha256'] == sha(bundle)
            and reproduction['fixture_sha256'] == FIXTURE_SHA and reproduction['fixture_reproduced_byte_exact']
            and reproduction['archived_files'] == actual_files and reproduction['all_archived_files_unchanged']
            and not reproduction['modified_archived_files'] and reproduction['native_control_cases'] == reproduction['native_replayed_cases'] == 402
            and reproduction['native_validation_checks'] == 6208 and reproduction['native_validation_failures'] == 0
            and reproduction['pinned_runtime_inputs_verified'] == 475 and reproduction['all_runtime_inputs_match_frozen_source']
            and not reproduction.get('new_native_oracle_claimed', False) and not reproduction['error_markers']
            and all(row['exit_code'] == 0 and not row['timed_out'] and not row['error_markers'] for row in reproduction['commands']),
            'Fresh native402/6208 byte-exact reproduction failed')
    # The capture bootstrap is provenance, never a substitute final suite proof.
    pin_input_name = capture['runtime_pin_input']
    safe(pin_input_name)
    pin_input = root / pin_input_name
    require(pin_input.is_file() and not pin_input.is_symlink()
            and sha(pin_input) == capture['runtime_pin_inventory_sha256'], 'Capture input inventory bytes changed')
    capture_runtime = read(pin_input)
    require(capture_runtime['version_code'] == CODE and capture_runtime['files_sha256'] == frozen
            and capture['runtime_pinned_files'] == len(frozen)
            and all(capture['source_sha256'].get(name) == digest for name, digest in frozen.items()),
            'Capture must use the exact final475 runtime path/hash map')
    if capture['runtime_pin_is_final_suite_proof']:
        require(pin_input_name == VNAME + '/runtime-freeze.json' and pin_input.read_bytes() == freeze_raw,
                'Capture final-suite provenance is not the actual final runtime freeze')
    copied_capture_input = v / 'capture-runtime-inputs.json'
    require(copied_capture_input.is_file() and copied_capture_input.read_bytes() == pin_input.read_bytes(),
            'Public copy of honest capture bootstrap inventory differs')
    require(capture['version'] == VERSION and capture['checks'] > 0 and not capture['failures']
            and capture['display_server'] != 'headless' and capture['atmospheric_shielding_from_real_service']
            and len(capture['frames']) == 4, 'Four actual successful rendered captures required')
    frames = capture['frames']
    require([row['file'] for row in frames] == FRAME_NAMES and [row['phase'] for row in frames] == FRAME_PHASES
            and [row['viewport'] for row in frames] == [[1440, 720], [1440, 720], [960, 432], [960, 432]]
            and [row['screen'] for row in frames] == ['station_selection', 'flight', 'station_services', 'flight'],
            'Actual four station frame names/phases/dimensions/screens differ')
    require(review['visually_inspected_desktop_frames'] == 4 and set(review['files']) == set(FRAME_NAMES),
            'All four exact desktop frames must be independently visually reviewed')
    for row in frames:
        path = v / 'screenshots' / row['file']
        raw = path.read_bytes()
        require(not path.is_symlink() and sha(path) == row['sha256'] == review['files'][row['file']]
                and raw[:8] == b'\x89PNG\r\n\x1a\n' and list(struct.unpack('>II', raw[16:24])) == row['viewport'],
                'Actual reviewed PNG bytes/dimensions changed: ' + row['file'])
        require(row['scene'] == 'scenes/main.tscn' and not any(row[key] for key in ('composited',
                'physical_android_capture', 'performance_benchmark', 'planet_to_station_transit_flown',
                'circular_orbit_claim', 'full_original_frame_bank_claim'))
                and 0 <= row['camera_residual_m'] <= row['camera_float32_bound_m']
                and row['hull_percent'] == 100 and row['atmospheric_shielding_installed'],
                'Unsupported capture claim, camera discrepancy or patched hull')
    require([row['native_state']['phase'] for row in frames] == ['orbital_flight', 'station_flight', 'station_flight', 'orbital_flight']
            and all(row['native_state']['active'] for row in frames)
            and not frames[0]['station_flight'] and not frames[3]['station_flight']
            and frames[1]['station_flight']['autopilot'] and not frames[1]['station_flight']['flight']['docked']
            and frames[2]['station_flight']['flight']['docked']
            and all(row['station_flight']['station']['entry_receipt'] == capture['handoff'] for row in frames[1:3]),
            'Rendered actual native/approach/dock/reverse owner states differ')
    flown = capture['flown_phases']
    require([row['phase'] for row in flown] == ['protected_20km_outbound', 'active_source_station_approach',
            'healthy_source_dock', 'physical_source_departure']
            and all(row['completed'] and row['accepted_command_intervals'] > 0 and row['seconds_per_interval'] == 0.1
            and row['hull_percent'] == 100 and row['days_before_f64_hex'] != row['days_after_f64_hex']
            and row['fuel_before'] != row['fuel_after'] and not row['source_contact_error'] for row in flown),
            'Each declared flown phase requires accepted real time/fuel intervals')
    equipment, placement, paid = capture['equipment_service'], capture['near_station_fixture'], capture['paid_services']
    require(equipment['actual_bay_UI_purchase'] and equipment['atmospheric_shielding_installed']
            and equipment['credits_before'] - equipment['credits_after'] == equipment['credits_spent'] == 100
            and not equipment['hull_or_heat_patched'], 'Shielding must be bought through the actual100-credit service')
    handoff, reverse = capture['handoff'], capture['reverse']
    candidates = capture['station_candidates']
    require(len(candidates) == len({row['site_id'] for row in candidates}) == 3
            and all(row['distance_m'] > 100000 and re.fullmatch('[0-9a-f]{136}', row['record_hex']) for row in candidates),
            'Three original genuinely distant station records required')
    require(placement['explicit_near_station_fixture'] and placement['placement_is_fixture_not_flown']
            and placement['outbound_original_lineage_retained'] and placement['closed_door_is_explicit_fixture']
            and placement['no_game_pose_patch_after_station_handoff'] and not placement['planet_to_station_journey_flown']
            and placement['site_id'] == handoff['site_id'] and placement['parent_id'] == handoff['body_id']
            and placement['distance_to_station_m'] == handoff['distance_to_station_m'] <= 100000
            and len(placement['source_approach_waypoint_m']) == len(placement['actual_station_local_position_m']) == 3
            and placement['actual_station_local_position_m'][:2] == placement['source_approach_waypoint_m'][:2]
            and abs(placement['actual_station_local_position_m'][2] - placement['source_approach_waypoint_m'][2] - 100) < 0.001
            and any(row['site_id'] == placement['site_id'] and row['parent_id'] == placement['parent_id']
                    and row['source_model_index'] == placement['source_model_index'] for row in candidates),
            'Capture must retain honest source outer-waypoint-plus100m fixture provenance')
    require(handoff['schema'] == 'starfrontier-native-station-frame-handoff-v1'
            and handoff['policy'] == 'bounded-source-station-origin-handoff-v1'
            and handoff['velocity_policy'] == scope['velocity_policy']
            and handoff['ongoing_station_law'] == scope['ongoing_law']
            and not handoff['source_atmosphere']['apply_f1014']
            and not any(handoff[key] for key in ('clock_advanced', 'fuel_advanced', 'hp_applied', 'position_snapped', 'full_original_object_bank'))
            and reverse['schema'] == 'starfrontier-native-station-reverse-v1'
            and reverse['policy'] == 'bounded-native-station-following-atomic-flight-v1'
            and reverse['physical_departure_axis_m'] > 250
            and not any(reverse[key] for key in ('clock_advanced', 'fuel_advanced', 'hp_applied', 'position_snapped')),
            'Actual bounded handoff or physical departure/reverse evidence differs')
    require(paid['actual_routed_UI_transactions'] and paid['atmospheric_shielding_installed']
            and paid['hydrogen_after'] == paid['hydrogen_before'] + 1
            and paid['credits_after_refuel'] < paid['credits_before']
            and paid['credits_before_reinstall'] > paid['credits_after_refuel']
            and paid['credits_before_reinstall'] - paid['credits_after'] == paid['shield_reinstall_cost'] == 100
            and not paid['clock_advanced'] and not paid['hull_or_heat_patched'],
            'Actual paid refuel/refund/shield reinstall owner transaction differs')
    evidence = capture['archive']
    require(evidence['file'] == VNAME + '/' + REPORT and evidence['included_save']
            and evidence['full_native_station_session'] and evidence['full_source_angular_history']
            and evidence['active_station_autopilot'] and evidence['whole_game_cold_decoder_accepted']
            and evidence['sha256'] == sha(v / REPORT) and evidence['bytes'] == (v / REPORT).stat().st_size,
            'Actual full station include-save report ZIP binding failed')
    with zipfile.ZipFile(v / REPORT) as report_zip:
        require(report_zip.testzip() is None, 'Actual station report ZIP CRC failed')
        diagnostic = json.loads(report_zip.read('report.json'))
        saved_raw = report_zip.read('game-save.json')
        saved = json.loads(saved_raw)
        report_manifest = json.loads(report_zip.read('manifest.json'))
        session = saved['native_station_session']
        require(diagnostic['version'] == VERSION and diagnostic['included_save']
                and saved['schema'] == 'starfrontier-rebuild-game-v1' and not saved['surface']['active']
                and session['schema'] == 'starfrontier-native-station-trial-v1'
                and session['motion']['autopilot'] and session['motion_history']
                and {'basis_f32_hex', 'previous_basis_f32_hex', 'step_f64_hex', 'angular_f32_hex',
                     'ship_angular_f32_hex', 'sample_valid', 'motion_pending', 'last_collision'} <= session['motion'].keys()
                and session['entry_receipt'] == handoff and 'gear_session' in saved
                and not {'native_orbit_session', 'motion_session', 'native_autopilot_session'} & saved.keys()
                and b'[depth limit]' not in saved_raw and b'[unsupported value]' not in saved_raw,
                'Actual report truncates or omits current native station/angular/autopilot save')
        names = {entry['name'] for entry in report_manifest['files']}
        require(len(names) == len(report_manifest['files']) and set(report_zip.namelist()) == names | {'manifest.json'}
                and evidence['manifest_files'] == report_manifest['files'], 'Report exact checksum manifest differs')
        for entry in report_manifest['files']:
            safe(entry['name'])
            raw = report_zip.read(entry['name'])
            require(len(raw) == entry['bytes'] and hashlib.sha256(raw).hexdigest() == entry['sha256'],
                    'Actual production report checksum differs: ' + entry['name'])
    copies = public_files(v)
    for name, path in public_files(p, 'source-portability/').items():
        require(name not in copies, 'Duplicate public proof payload: ' + name)
        copies[name] = path
    require(not set(copies) & {APK, SOURCE, 'README_RU.md', 'DOWNLOAD_RU.txt', 'manifest.json'},
            'Public proof collides with a reserved release payload')
    require({name for name in copies if PurePosixPath(name).suffix.lower() == '.png'} == {'screenshots/' + name for name in FRAME_NAMES}
            and {REPORT, 'screenshots/visual-review.json', 'capture-runtime-inputs.json', 'packaging.json',
                 'runtime-freeze.json', 'final-targeted-summary.json', 'source-portability/native-station-feature.json'} <= copies.keys(),
            'Unexpected PNG or missing reviewed proof/report/provenance payload')
    note = f'''# StarFrontier 0.28 — исходный орбитальный полёт и стыковка

**PREPUB: {VERSION} / Android ARM64 TEST / code {CODE}.** Постоянные HTTPS-ссылки
будут проверены отдельно после публикации; этот запечатанный пакет такой
проверки ещё не заявляет.

1. В отдельном испытании исходной посадки добавлен ограниченный переход
из исходного орбитального полёта к станции того же родительского тела:
не дальше 100 км, вне атмосферы и с исходной проверкой высоты. Положение
переносится через исходные целочисленные координаты до перевода в метры,
скорость — по явно указанной производной исходной эфемериды.
2. После перехода действуют прежние движение вращающейся станции, подход,
физическая дверь, захват доком, платные службы и вылет. Это существующий
мобильный закон движения относительно станции, а не доказательство полного
исходного инерциального диспетчера F570/F606 или автопилота F597.
3. Сохранение содержит текущую станционную сессию, вращение и предыдущее
угловое состояние. Реальный вылет позволяет вернуться в исходный орбитальный
сеанс без сброса времени, топлива, корпуса, текущей позиции и скорости.
Обычный прогресс и отдельное испытание сохраняются раздельно.

В четырёх настоящих desktop-кадрах сначала показаны исходные станции Земли
на реальных расстояниях в десятки тысяч километров. Затем применена явно
обозначенная тестовая установка: исходная внешняя точка подхода плюс100 м,
{placement['distance_to_station_m']:.5f} м от станции. Дальний перелёт от планеты
до станции не пройден. После этой установки выполнены настоящий автоподход,
стыковка, платные службы, физический вылет и обратный перевод системы отсчёта.
Ни изображения, ни записи не объявляются проверкой Samsung или FPS.

- [APK]({APK}): {apk.stat().st_size} байт; SHA256 `{sha(apk)}`.
- [Исходники ZIP]({SOURCE}): {bundle.stat().st_size} байт; SHA256 `{sha(bundle)}`.
- [Настоящий отчёт с полным сохранением станционного полёта]({REPORT}).
- [Четыре настоящих desktop-кадра](screenshots/).

Source commit: `{commit}`. ZIP содержит {actual_files} файлов/{len(entries)}
записей, меньше32 МиБ. Проверены CRC, Git-комментарий, все475 runtime-входов
и {len(pins)} source/proof-входов. Состав и исторические QA-исключения описаны
в SOURCE_ARCHIVE_RU.md. Текущие runtime/assets не исключены; снимки и часть
метаданных захвата доставляются в этом пакете без дублирования внутри ZIP.
Свежие импорт/запуск: {fresh['startup_checks']}/0. Из чистого ZIP отдельно:
два чистых ядра — {feature['pure_kernel_feature_checks_separate']}/0,
один настоящий Main-сценарий — {feature['actual_Main_feature_checks_separate']}/0.
Все {actual_files} исходных файлов после проверки остались побайтно прежними.

Уникальные функциональные проверки: **{summary['checks']} / {len(rows)} групп / 0 ошибок**.
Отдельно: {packaging['unit_test_count']} Python-тест /16 модулей; прежний
исходный банк402 случая/6208 проверок; {capture['checks']} capture-проверок.
Повторы и вспомогательные числа к функциональной сумме не прибавлены.

APK использует прежнюю TEST-подпись, min SDK24 / target SDK36 и ZIP/ELF16 КиБ.
Полный исходный frame/object bank, универсальный рельеф, полный клон,
полная русификация и магазинный релиз не завершены. Круговая орбита
автоматически не формируется. Физический Samsung S23 Ultra / Android17 /
One UI9 и FPS не проверены.

После публикации планируются9 полных HTTPS-скачиваний: manifest, APK,
sourceZIP, capture-manifest,4 PNG и sample-reportZIP. Остальные payload
проверены локальными SHA и не объявляются отдельно скачанными.
'''
    note = '\n'.join(line.rstrip() for line in note.splitlines()) + '\n'
    generated = {'README_RU.md': note.encode(), 'DOWNLOAD_RU.txt': note.encode()}
    allowed = set(copies) | {APK, SOURCE, *generated, 'manifest.json'}
    require(not {path.relative_to(dest).as_posix() for path in dest.rglob('*') if path.is_file()} - allowed,
            'Unexpected existing files in new release directory')
    payloads = {}
    for name, source in {APK: apk, **copies}.items():
        target = dest / name
        require(target.resolve().is_relative_to(dest.resolve()) and not target.is_symlink()
                and (not target.exists() or sha(target) == sha(source)), 'Refuse replacing different/unsafe existing payload: ' + name)
        payloads[name] = {'bytes': source.stat().st_size, 'sha256': sha(source)}
    payloads[SOURCE] = {'bytes': bundle.stat().st_size, 'sha256': sha(bundle)}
    for name, raw in generated.items():
        target = dest / name
        require(target.resolve().is_relative_to(dest.resolve()) and not target.is_symlink()
                and (not target.exists() or target.read_bytes() == raw), 'Refuse replacing different/unsafe existing instructions: ' + name)
        payloads[name] = {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}
    manifest = {'version': VERSION, 'version_code': CODE, 'source_commit': commit,
        'created_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
        'source_archive_files': len(entries), 'source_archive_actual_files': actual_files, 'source_actual_files': actual_files,
        'source_archive_bytes': bundle.stat().st_size, 'source_archive_below_32MiB': True,
        'source_archive_crc_verified': True, 'source_archive_git_runtime_freeze_verified': True,
        'source_archive_fresh_import_passed': True, 'source_archive_isolated_startup_checks_separate': fresh['startup_checks'],
        'source_archive_unique_feature_scripts_separate': len(feature['features']),
        'source_archive_unique_Main_feature_scripts_separate': feature['actual_Main_feature_scripts'],
        'source_archive_pure_kernel_feature_scripts_separate': feature['pure_kernel_feature_scripts'],
        'source_archive_Main_feature_checks_separate': feature['actual_Main_feature_checks_separate'],
        'source_archive_pure_kernel_feature_checks_separate': feature['pure_kernel_feature_checks_separate'],
        'source_archive_feature_checks_separate': feature['unique_feature_checks_separate'],
        'source_archive_all_actual_files_unchanged': actual_files,
        'source_archive_pinned_runtime_inputs_verified': len(frozen), 'source_archive_pinned_source_proof_inputs_verified': len(pins),
        'runtime_frozen_files': len(frozen), 'unchanged_previous_runtime_files': 468,
        'changed_previous_runtime_files': sorted(changed), 'added_runtime_files': sorted(added),
        'functional_checks': summary['checks'], 'functional_groups': len(rows), 'functional_failures': 0,
        'functional_report': 'final-targeted-summary.json', 'python_packaging_tests_separate': packaging['unit_test_count'],
        'python_packaging_modules': len(packaging['unit_test_modules']), 'new_native_control_cases': 0,
        'reused_native_control_cases': 402, 'native_reproduction_validator_checks_separate': 6208,
        'new_original_native_oracle_claimed': False, 'capture_checks_separate': capture['checks'],
        'desktop_frames_visually_inspected': 4, 'capture_scope': capture['scope'],
        'compiled_new_modules': 2, 'compiled_integration_modules': 58,
        'protected_previous_Main_function_count': len(functions['preserved']['scripts/main.gd']),
        'modified_previous_Main_function_count': len(functions['modified']['scripts/main.gd']),
        'added_Main_function_count': len(functions['added']['scripts/main.gd']),
        'unchanged_code52_core_compiled_source_count': 55, 'native_station_assets': assets,
        'package': android['package'], 'abi': android['abi'], 'min_sdk': android['min_sdk'], 'target_sdk': android['target_sdk'],
        'test_key_only': True, 'certificate_sha256': android['certificate_sha256'], 'debuggable': False,
        'zip_and_elf_alignment_16k': True, 'physical_device_tested': False, 'screenshots_are_phone_captures': False,
        'production_signing_key_configured': False, 'production_release_ready': False, 'release_ready': False,
        'full_original_port_complete': False, 'full_clone_complete': False, 'full_russian_localization_complete': False,
        'continuous_native_trial_to_station_transfer_connected': True, 'same_parent_station_handoff_limit_m': 100000,
        'planet_to_station_transit_flown': False, 'full_original_F570_F606_object_bank_proved': False,
        'new_dock_autopilot_implemented': False, 'existing_dock_autopilot_unchanged': True,
        'new_original_F597_autopilot_proved': False, 'station_continuation_law': scope['ongoing_law'],
        'velocity_policy': scope['velocity_policy'], 'circular_orbit_inserted': False, 'whole_mesh_certified': False,
        'default_physical_terrain_revision': 'sphere-source-ground-v4', 'actual_collector_report_ZIP': REPORT,
        'actual_collector_report_included_save': True, 'actual_collector_full_station_save_cold_decoder_accepted': True,
        'capture_shielding_bought_through_actual_service': True, 'capture_shielding_price_credits': equipment['credits_spent'],
        'capture_station_service_shield_reinstall_price_credits': paid['shield_reinstall_cost'],
        'capture_runtime_pin_provenance': {'source_path': pin_input_name,
            'source_sha256': capture['runtime_pin_inventory_sha256'],
            'was_final_suite_proof': capture['runtime_pin_is_final_suite_proof'], 'files_sha256_equal_final_freeze': True,
            'runtime_files': len(frozen), 'public_provenance_file': 'capture-runtime-inputs.json'},
        'planned_HTTPS_verification_download_count': 9, 'immutable_HTTPS_verified_at_packaging': False,
        'other_auxiliary_payloads_verified_by_local_manifest_only': True, 'packaging_helper_sha256': sha(Path(__file__)),
        'files': dict(sorted(payloads.items()))}
    if not args.check_only:
        # All gates and every pre-existing output are checked before the first write.
        for name, source in {APK: apk, **copies}.items():
            target = dest / name
            target.parent.mkdir(parents=True, exist_ok=True)
            if not target.exists():
                shutil.copy2(source, target)
        for name, raw in generated.items():
            if not (dest / name).exists():
                (dest / name).write_bytes(raw)
        for name, expected in manifest['files'].items():
            require((dest / name).stat().st_size == expected['bytes'] and sha(dest / name) == expected['sha256'],
                    'Copied payload mismatch: ' + name)
        require(sha(bundle) == payloads[SOURCE]['sha256'], 'Source ZIP changed during packaging')
        with (dest / 'manifest.json').open('x') as stream:
            stream.write(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'written': not args.check_only, 'version': VERSION, 'source_commit': commit,
        'payloads': len(payloads), 'functional_checks': summary['checks'], 'groups': len(rows),
        'runtime_files': len(frozen), 'source_files': actual_files,
        'fresh_feature_scripts_separate': len(feature['features']), 'fresh_Main_checks_separate': feature['actual_Main_feature_checks_separate'],
        'fresh_pure_kernel_checks_separate': feature['pure_kernel_feature_checks_separate'],
        'capture_checks_separate': capture['checks']}, indent=2))


if __name__ == '__main__':
    main()
