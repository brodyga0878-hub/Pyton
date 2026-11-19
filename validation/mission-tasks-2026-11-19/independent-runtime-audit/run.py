#!/usr/bin/env python3
"""Repeat the independent ownership/replay audit without private DOS inputs."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
DEPENDENCIES = [
    'scripts/source_mission_runtime.gd', 'scripts/source_mission_runtime_state.gd',
    'scripts/source_mission_models.gd', 'scripts/source_mission_store.gd',
    'scripts/source_mission_task.gd', 'scripts/source_mission_programs.gd',
    'scripts/source_mission_expression.gd', 'scripts/source_mission_guards.gd',
    'scripts/source_events.gd', 'scripts/source_mission_services.gd',
    'scripts/source_clock_pipeline.gd', 'scripts/source_contact_scan.gd',
    'scripts/source_frame_dispatch.gd', 'data/ffe_mission_programs.json',
    'data/ffe_mission_models.json',
]


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=HERE.parents[2])
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--output', type=Path, default=HERE / 'verification.json')
    args = parser.parse_args()
    root = args.repo.resolve()
    before = {name: sha((root / name).read_bytes()) for name in DEPENDENCIES}
    probe = (HERE / 'probe.gd.txt').read_bytes()
    with tempfile.TemporaryDirectory(prefix='mission-runtime-independent-') as temp:
        script = Path(temp) / 'audit.gd'
        script.write_bytes(probe)
        command = [args.godot, '--headless', '--path', str(root), '--script', str(script)]
        process = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    output = process.stdout
    print(output, end='')
    match = re.search(r'^INDEPENDENT_RUNTIME_AUDIT (\d+) checks (\d+) failures$', output, re.M)
    after = {name: sha((root / name).read_bytes()) for name in DEPENDENCIES}
    if process.returncode != 0 or match is None or int(match[2]) != 0 or before != after:
        raise SystemExit('Independent runtime audit failed or its inputs changed during execution')
    report = {
        'schema': 'starfrontier-independent-mission-runtime-audit-v1',
        'checks': int(match[1]), 'failures': int(match[2]),
        'source_inputs_unchanged_during_probe': True,
        'source_dependencies_sha256': before,
        'probe_sha256': sha(probe), 'runner_sha256': sha(Path(__file__).read_bytes()),
        'stdout_sha256': sha(output.encode()),
        'private_original_inputs_opened': False,
        'counted_in_final_functional_sum': False,
        'native_execution_proof': False,
        'Main_integrated': False, 'full_F41_executed': False,
        'scope': 'Independent actual-image selected-frame, cold numeric ownership, typed F41, cyclic/deep preflight, prepare/commit/restore, actual F54/F53/F33/F44 journal, F51 handle wrap and F54 release controls. Separate from frozen suite and native composition totals.',
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    args.output.with_name('stdout.txt').write_text(output)


if __name__ == '__main__':
    main()
