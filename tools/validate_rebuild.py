#!/usr/bin/env python3
"""Run a curated set of current rebuilt suites, once each, with bounded logs.

This checks standalone logic and native-reference controls. App smoke, Android
package verification, and physical-device validation remain separate checks.
The recovered-history tree is never scanned or imported: the one selected pad
test is loaded explicitly, and the terrain tool builds an isolated project.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import dataclasses
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import selectors
import shutil
import signal
import subprocess
import sys
import time

PROJECT = Path(__file__).resolve().parents[1]
COUNTS = re.compile(r'(?<!\d)(\d+)\s+checks,\s*(\d+)\s+failures\b')
DIAGNOSTIC = re.compile(
    r'(?:SCRIPT ERROR:|^\s*ERROR:|ObjectDB instances leaked|Leaked instance:|'
    r'resources still in use at exit|WARNING:[^\n]*\bleak(?:ed|s)?\b|'
    r'RID allocations[^\n]*(?:leak|exit))', re.I | re.M)


@dataclasses.dataclass(frozen=True)
class Suite:
    name: str
    script: str
    scope: str
    kind: str = 'godot'
    timeout: int = 180
    optional: bool = False
    user_args: tuple[str, ...] = ()


SUITES = [
    Suite('math', 'tests/test_rebuilt_ffe_math.gd', 'Reconstructed source integer and packed arithmetic, independent native controls.'),
    Suite('body_initializer', 'tests/test_rebuilt_body_initializer.gd', 'Complete original F882 packed-record initialization versus 1424 native contexts; isolated from the live analytic world and ephemerides.'),
    Suite('body_rotation', 'tests/test_rebuilt_body_rotation.gd', 'Exact F880 initialization/F866 orientation slice with F1675/F1914/F1521 versus 1542 native contexts; excludes full F866, original clock epoch, animations and orbital updates.'),
    Suite('stellar_factory', 'tests/test_stellar_body_factory.gd', 'Bounded original F881 stellar-name domain plus F882/remnant callbacks/F894 against 760 independent native contexts; excludes planetary generation, brown-dwarf naming and live-world integration.'),
    Suite('planetary_classifier', 'tests/test_planetary_classifier.gd', 'Original bounded F883..887 planetary classification versus 3060 native controls; supported paths match full records/RNG, naming and settlement paths reject atomically.'),
    Suite('worlds', 'tests/test_rebuilt_worlds.gd', 'Handcrafted original records and explicit analytic world/navigation adapter.'),
    Suite('flight', 'tests/test_rebuilt_flight.gd', 'Rebuilt flight, phone steering inputs, adapted training economy, atomic flight saves.'),
    Suite('cities', 'tests/test_rebuilt_cities.gd', 'Source3 city geometry, pad selection, collision, landing/takeoff/restore integration.'),
    Suite('city_runtime', 'tests/test_source_city_runtime.gd', 'Original city runtime and analytic ellipsoid collision controls.'),
    Suite('city_view', 'tests/test_source_city_view.gd', 'City rendering lifetime and presentation contract with synthetic geometry.'),
    Suite('triangle_ccd', 'tests/test_segment_triangle.gd', 'Independent triangle/edge/vertex swept ellipsoid collision controls.'),
    Suite('ground_pads', 'recovered-history/ground_harness/tests/test_source_ground_pads.gd', 'Preserved test explicitly loaded against current scripts and regenerated native F650 controls.'),
    Suite('terrain_native', 'tools/data_validate_terrain.py', 'Isolated preserved terrain research modules versus 336 raw and 630 native caller controls; not live terrain integration.', kind='python', timeout=300),
    Suite('save_touch', 'tests/test_rebuilt_save_touch.gd', 'Current complete save-store decoding, atomic writes/fallback and multi-finger phone input/release behavior; separate from app/device smoke.'),
    Suite('app_transitions', 'tests/test_rebuilt_app_transitions.gd', 'Actual Main transition locks, pending-save resume and asynchronous New Moscow entry; capture mode disables user progress loading/writing.', user_args=('--rebuild-capture',)),
    Suite('graphics_ship', 'tests/test_ship_graphics.gd', 'Authored detailed ship geometry, normal/span contracts, cache/lifecycle, exhaust, and landing gear; not the complete original ship catalogue or device rendering.'),
    Suite('graphics_environment', 'tests/test_graphics_space_environment.gd', 'Batched orbital-station geometry, deterministic asteroid placement, clear approach/planet-view cones and distance/quality LOD; visual scenery only.'),
    Suite('graphics_integration', 'tests/test_graphics_integration.gd', 'Actual Main graphics-flight entry/return, isolated original progress/save bytes, save-failure guard, controls/quality and native city return; private test save directory.', user_args=('--rebuild-capture',)),
    Suite('material_library', 'tests/test_material_library.gd', 'Original PBR map import, dimensions, shared-resource lifetime and material binding contracts; not visual-quality or phone-performance proof.'),
    Suite('space_materials', 'tests/test_space_material_bindings.gd', 'Real hull/station material map assignments, palette/finish and quality isolation on existing geometry.'),
    Suite('world_materials', 'tests/test_world_materials.gd', 'City palette and mesh preservation, real terrain/fallback maps and quality propagation.'),
    Suite('graphics_scope', 'tests/test_graphics_scope.gd', 'Actual Main normal flight excludes decorative asteroid scenery, preserves flight/navigation/surface data and restores optional graphics preview.', user_args=('--rebuild-capture',)),
    Suite('diagnostics', 'tests/test_game_diagnostics.gd', 'Bounded persistent diagnostics, real isolated engine/script errors, archive CRC/hash/retention, session markers and explicit save opt-in.'),
    Suite('report_export', 'tests/test_report_export.gd', 'Checked multiblock ZIP export, errors/cancel/retry, source preservation; Android SAF separately source-verified, physical device untested.'),
    Suite('bug_report_ui', 'tests/test_bug_report_ui.gd', 'Actual Main report buttons, report description/context/save opt-in, verified export callback, direct retry and original progress isolation.', user_args=('--rebuild-capture',)),
]


class Inspector:
    """Inspect the entire output while storing only bounded context and counts."""

    def __init__(self, max_bytes: int):
        self.max_bytes = max_bytes
        self.prefix = bytearray()
        self.tail = bytearray()
        self.total_bytes = 0
        self.pending = ''
        self.counts: list[tuple[int, int]] = []
        self.diagnostics: list[str] = []

    def line(self, value: str):
        for match in COUNTS.finditer(value):
            self.counts.append((int(match[1]), int(match[2])))
        if DIAGNOSTIC.search(value) and value.strip() not in self.diagnostics and len(self.diagnostics) < 20:
            self.diagnostics.append(value.strip()[:1000])

    def feed(self, raw: bytes):
        self.total_bytes += len(raw)
        prefix_limit = self.max_bytes*3//4
        tail_limit = self.max_bytes-prefix_limit
        if len(self.prefix) < prefix_limit:
            take = min(len(raw), prefix_limit-len(self.prefix))
            self.prefix.extend(raw[:take])
            raw_for_tail = raw[take:]
        else:
            raw_for_tail = raw
        self.tail.extend(raw_for_tail)
        if len(self.tail) > tail_limit:
            del self.tail[:-tail_limit]
        # Diagnostics are matched before line buffering is bounded. Godot's
        # summaries/diagnostics are ASCII, so split UTF8 does not affect them.
        value = self.pending+raw.decode('utf-8', errors='replace')
        lines = value.split('\n')
        self.pending = lines.pop()
        for line in lines:
            self.line(line)
        if len(self.pending) > 16384:
            self.line(self.pending[:-1024])
            self.pending = self.pending[-1024:]

    def finish(self):
        if self.pending:
            self.line(self.pending)
            self.pending = ''

    def log(self) -> str:
        omitted = self.total_bytes-len(self.prefix)-len(self.tail)
        middle = ('\n... %d output bytes omitted; diagnostics inspected throughout ...\n' % omitted).encode() if omitted > 0 else b''
        return (self.prefix+middle+self.tail).decode('utf-8', errors='replace')


def fingerprint(path: Path) -> dict:
    raw = path.read_bytes()
    return {'path': str(path.relative_to(PROJECT)), 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}


def engine_version(value: str) -> str:
    # Startup font-cache diagnostics can appear on stderr before --version.
    # Compare the actual version line, not the unrelated combined probe output.
    candidates = [line.strip() for line in value.splitlines()
                  if re.fullmatch(r'\d+\.\d+(?:\.[A-Za-z0-9_+-]+)*', line.strip())]
    if len(candidates) != 1:
        raise ValueError('Godot did not return one unambiguous engine version')
    return candidates[0]


def run_suite(suite: Suite, godot: str, output: Path, max_bytes: int) -> dict:
    script = PROJECT/suite.script
    result = {'name': suite.name, 'scope': suite.scope, 'status': 'failed', 'checks': 0, 'failures': 0,
              'executed_utc': dt.datetime.now(dt.timezone.utc).isoformat()}
    if not script.is_file():
        result.update(status='unavailable' if suite.optional else 'failed', reason='Suite file is unavailable: '+suite.script)
        return result
    result['suite_source'] = fingerprint(script)
    command = ([sys.executable, str(script), '--godot', godot] if suite.kind == 'python' else
               [godot, '--headless', '--path', str(PROJECT), '--script', 'res://'+suite.script])
    if suite.user_args:
        command.extend(['--', *suite.user_args])
    state = output/'state'/suite.name
    environment = dict(os.environ, XDG_DATA_HOME=str(state/'data'), XDG_CACHE_HOME=str(state/'cache'),
                       XDG_CONFIG_HOME=str(state/'config'))
    result['command'] = command
    inspector = Inspector(max_bytes)
    started = time.monotonic()
    timed_out = False
    process = None
    try:
        process = subprocess.Popen(command, cwd=PROJECT, env=environment, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        with selectors.DefaultSelector() as poller:
            poller.register(process.stdout, selectors.EVENT_READ)
            while poller.get_map():
                remaining = suite.timeout-(time.monotonic()-started)
                if remaining <= 0:
                    timed_out = True
                    os.killpg(process.pid, signal.SIGKILL)
                    break
                for key, _ in poller.select(timeout=min(remaining, 0.25)):
                    raw = os.read(key.fileobj.fileno(), 8192)
                    if not raw:
                        poller.unregister(key.fileobj)
                    else:
                        inspector.feed(raw)
            if timed_out:
                # The process group was killed; draining the pipe cannot wait
                # for an orphaned terrain Godot child to finish by itself.
                for raw in iter(lambda: process.stdout.read(8192), b''):
                    inspector.feed(raw)
        result['exit_code'] = process.wait(timeout=5)
    except (OSError, subprocess.SubprocessError) as error:
        result['reason'] = str(error)
    finally:
        if process is not None:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait(timeout=5)
            if process.stdout is not None:
                process.stdout.close()
    inspector.finish()
    result['duration_seconds'] = round(time.monotonic()-started, 3)
    result['timed_out'] = timed_out
    result['output_bytes'] = inspector.total_bytes
    result['log_truncated'] = inspector.total_bytes > max_bytes
    result['diagnostics'] = inspector.diagnostics
    log = output/'logs'/(suite.name+'.log')
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text(inspector.log(), encoding='utf-8')
    result['log'] = str(log)
    result['summary_lines'] = len(inspector.counts)
    if len(inspector.counts) == 1:
        result['checks'], result['failures'] = inspector.counts[0]
    problems = []
    if timed_out:
        problems.append('Suite exceeded %d seconds' % suite.timeout)
    if result.get('exit_code') != 0:
        problems.append('Process did not exit successfully')
    if len(inspector.counts) != 1:
        problems.append('Expected exactly one current checks/failures summary, got %d' % len(inspector.counts))
    elif result['checks'] <= 0 or result['failures'] != 0:
        problems.append('No positive passing check count')
    if inspector.diagnostics:
        problems.append('Engine error or leaked resource diagnostic')
    if fingerprint(script) != result['suite_source']:
        problems.append('Suite source changed during its execution')
    if result.get('reason'):
        problems.append(result['reason'])
    if problems:
        result['reason'] = '; '.join(problems)
    else:
        result['status'] = 'passed'
    return result


def limitations() -> list[dict]:
    items = [{
        'scope': 'Full original model-mesh leaf native controls',
        'status': 'unavailable' if not (PROJECT/'tests/fixtures/model_vertices_reference.json').is_file() else 'not_in_this_curated_run',
        'reason': 'The preserved tests/test_source_model_mesh.gd requires model_vertices_reference.json; original city geometry is exercised by the current city suites, which does not replace this missing independent leaf fixture.',
    }]
    items.append({'scope': 'Full application, Android installation and physical Samsung S23 Ultra', 'status': 'separate_validation',
                  'reason': 'This runner covers current standalone suites and isolated native terrain controls only.'})
    return items


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--suite', action='append', choices=[suite.name for suite in SUITES], help='Run a named subset; repeated names are deduplicated.')
    parser.add_argument('--jobs', type=int, default=3)
    parser.add_argument('--output', type=Path, default=PROJECT/'build/validation')
    parser.add_argument('--summary', type=Path, default=PROJECT/'build/validation-summary.json')
    parser.add_argument('--extend', action='store_true', help='Add only new/unavailable/failed named suites to this same-day report without rerunning passed suites.')
    parser.add_argument('--log-max-kib', type=int, default=128)
    parser.add_argument('--list', action='store_true', help='List the explicit suites without executing any tests.')
    args = parser.parse_args()
    if args.list:
        print(json.dumps([dict(dataclasses.asdict(suite), available=(PROJECT/suite.script).is_file()) for suite in SUITES], indent=2))
        return 0
    if not 1 <= args.jobs <= 8 or not 8 <= args.log_max_kib <= 1024:
        parser.error('--jobs must be 1..8 and --log-max-kib must be 8..1024')
    godot = shutil.which(args.godot)
    if godot is None:
        parser.error('Godot executable is unavailable: '+args.godot)
    selected = [suite for suite in SUITES if not args.suite or suite.name in args.suite]
    previous = None
    if args.extend:
        if not args.suite or not args.summary.is_file():
            parser.error('--extend requires --suite and an existing --summary')
        previous = json.loads(args.summary.read_text(encoding='utf-8'))
        if previous.get('project') != str(PROJECT) or previous.get('schema') != 1:
            parser.error('Existing summary belongs to another project or schema')
        previous_time = dt.datetime.fromisoformat(previous['started_utc'])
        age = (dt.datetime.now(dt.timezone.utc)-previous_time).total_seconds()
        if age < 0 or age > 86400:
            parser.error('--extend accepts only a current report from the last 24 hours; historical totals cannot be imported')
        for row in previous['suites']:
            if row['status'] == 'passed' and row['name'] in args.suite:
                parser.error('Passed suite %s would run twice; select only newly added, unavailable or failed suites' % row['name'])
            if row['status'] == 'passed' and fingerprint(PROJECT/row['suite_source']['path']) != row['suite_source']:
                parser.error('Previously tested suite source changed: %s; start a fresh relevant validation run' % row['name'])
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    probe_state = output/'state'/'runner'
    for name in ['data', 'cache', 'config']:
        (probe_state/name).mkdir(parents=True, exist_ok=True)
    probe_env = dict(os.environ, XDG_DATA_HOME=str(probe_state/'data'), XDG_CACHE_HOME=str(probe_state/'cache'),
                     XDG_CONFIG_HOME=str(probe_state/'config'))
    version = engine_version(subprocess.run([godot, '--version'], env=probe_env, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=10, check=True).stdout)
    if previous is not None and engine_version(previous.get('godot_version', '')) != version:
        parser.error('Existing summary used another Godot version; start a fresh validation run')
    started_utc = dt.datetime.now(dt.timezone.utc).isoformat()
    started = time.monotonic()
    results = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as executor:
        futures = {executor.submit(run_suite, suite, godot, output, args.log_max_kib*1024): suite for suite in selected}
        for future in concurrent.futures.as_completed(futures):
            suite = futures[future]
            try:
                result = future.result()
            except Exception as error:
                result = {'name': suite.name, 'scope': suite.scope, 'status': 'failed', 'checks': 0, 'failures': 0,
                          'reason': 'Validation infrastructure error: '+str(error)}
            results[suite.name] = result
            print('%s: %s; %d checks, %d failures%s' %
                  (suite.name, result['status'], result['checks'], result['failures'],
                   '; '+result['reason'] if result.get('reason') else ''), flush=True)
    executed_names = [suite.name for suite in selected]
    if previous is not None:
        old = {row['name']: row for row in previous['suites']}
        old.update(results)
        results = old
    ordered = [results[suite.name] for suite in SUITES if suite.name in results]
    unavailable = [row['name'] for row in ordered if row['status'] == 'unavailable']
    failed = [row['name'] for row in ordered if row['status'] == 'failed']
    # A missing optional new suite is a visible coverage limitation, not a pass.
    batch_duration = round(time.monotonic()-started, 3)
    batches = [] if previous is None else previous.get('validation_batches', [{'started_utc': previous['started_utc'],
                 'duration_seconds': previous['duration_seconds'],
                 'requested_suites': [row['name'] for row in previous['suites']],
                 'executed_suites': [row['name'] for row in previous['suites'] if row.get('command')]}])
    batches.append({'started_utc': started_utc, 'duration_seconds': batch_duration,
                    'requested_suites': executed_names,
                    'executed_suites': [name for name in executed_names if results[name].get('command')]})
    coverage = limitations()
    report = {'schema': 1, 'scope': 'Current rebuilt standalone suites and native-reference controls only; historical totals excluded. Per-suite execution times identify bounded supplemental runs; this is not an atomic repository snapshot.',
              'started_utc': previous['started_utc'] if previous else started_utc,
              'updated_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
              'duration_seconds': round(sum(batch['duration_seconds'] for batch in batches), 3), 'validation_batches': batches,
              'godot_version': version, 'project': str(PROJECT), 'jobs': args.jobs,
              'status': 'failed' if failed else 'passed_with_coverage_limitations' if unavailable or any(item['status'] == 'unavailable' for item in coverage) else 'passed',
              'passed_suites': sum(row['status'] == 'passed' for row in ordered),
              'failed_suites': failed, 'unavailable_suites': unavailable,
              'checks': sum(row['checks'] for row in ordered), 'failures': sum(row['failures'] for row in ordered),
              'suites': ordered, 'coverage_limitations': coverage}
    args.summary.parent.mkdir(parents=True, exist_ok=True)
    args.summary.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('Validation %s: %d current checks; %d passed suites; %d failed; %d unavailable. Report: %s' %
          (report['status'], report['checks'], report['passed_suites'], len(failed), len(unavailable), args.summary), flush=True)
    return 1 if failed else 0


if __name__ == '__main__':
    raise SystemExit(main())
