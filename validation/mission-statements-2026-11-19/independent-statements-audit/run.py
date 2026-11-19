#!/usr/bin/env python3
"""Independent copied-proof replay and caller-visible native interface controls."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
PROOF = Path('validation/mission-statements-2026-11-19/statements-native-proof')
GENERATOR = 'tools/rebuild_source_mission_statements_native.py'
FIXTURE = 'tests/fixtures/source_mission_statements_native.json'


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def command(args, root):
    done = subprocess.run(args, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if done.returncode != 0:
        raise ValueError(done.stdout)
    return done.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=HERE.parents[2])
    parser.add_argument('--exe', type=Path, help='Optional explicit original PE reproof; absent by default.')
    parser.add_argument('--output', type=Path, default=HERE / 'verification.json')
    args = parser.parse_args()
    root = args.repo.resolve()
    source_fixture = (root / FIXTURE).read_bytes()
    fixture = json.loads(source_fixture)
    dependencies = dict(fixture['source_dependencies_sha256'])
    for name, digest in dependencies.items():
        assert sha((root / name).read_bytes()) == digest, 'Stale native source pin: ' + name
    proof_before = {p.name: sha(p.read_bytes()) for p in (root / PROOF).iterdir() if p.is_file()}
    generator_before = sha((root / GENERATOR).read_bytes())
    with tempfile.TemporaryDirectory(prefix='independent-statements-replay-') as temp:
        work = Path(temp)
        copied = work / 'proof'
        shutil.copytree(root / PROOF, copied)
        absent = work / 'absent-originals'
        rebuilt = work / 'fixture.json'
        replay_args = [sys.executable, str(root / GENERATOR), '--proof-dir', str(copied),
            '--output', str(rebuilt), '--exe', str(absent / 'FIRSTENC.EXE'),
            '--asm', str(absent / 'ffe.asm'), '--data', str(absent / 'ffedat.asm'),
            '--mission-asm', str(absent / 'ffebmp.asm')]
        replay_output = command(replay_args, root)
        assert rebuilt.read_bytes() == source_fixture, 'Copied native replay differs from frozen fixture'
        copied_after = {p.name: sha(p.read_bytes()) for p in copied.iterdir() if p.is_file()}
        assert proof_before == copied_after and not absent.exists(), 'Copied proof or absent paths changed'
        controls_output = command([sys.executable, str(HERE / 'native_controls.py'),
                                   '--proof-dir', str(copied)], root)
        controls = json.loads(controls_output)
        assert controls['failures'] == 0
    original_performed = args.exe is not None
    if original_performed:
        original_output = args.output.with_name('original-verification.json')
        command([sys.executable, str(HERE / 'raw_original.py'), '--exe', str(args.exe.resolve()),
                 '--output', str(original_output)], root)
    proof_after = {p.name: sha(p.read_bytes()) for p in (root / PROOF).iterdir() if p.is_file()}
    assert proof_before == proof_after
    assert sha((root / GENERATOR).read_bytes()) == generator_before
    assert sha((root / FIXTURE).read_bytes()) == sha(source_fixture)
    for name, digest in dependencies.items():
        assert sha((root / name).read_bytes()) == digest, 'Input changed during independent audit: ' + name
    report = {'schema': 'starfrontier-independent-statements-audit-v1', 'status': 'verified',
        'copied_proof_replay': {'fixture_sha256': sha(source_fixture),
            'case_count': fixture['case_count'], 'typed_boundaries': fixture['typed_boundary_count'],
            'proof_files_sha256': proof_before, 'four_private_original_paths_deliberately_absent': True,
            'copied_proof_files_unchanged': True, 'original_proof_files_unchanged': True,
            'fixture_byte_exact': True},
        'generator_sha256': generator_before, 'source_dependencies_sha256': dependencies,
        'native_interface_controls': controls,
        'original_PE_reproof_performed_in_this_run': original_performed,
        'carrier_bytes': 156, 'caller_visible_bytes': 72, 'formatter_parameter_bytes': 20,
        'UI_record_bytes': 48, 'outlocal_bytes': 4, 'private_scalar_spill_seed_carrier_bytes': 84,
        'full156_original_stack_bytes_measured': False,
        'strlen_owned_span_preflight_required': True,
        'scope': 'Whole original F41/helper captures and all dispatch words are independently PE-audited when --exe is supplied. Portable replay opens copied captures and public resources only. Additional native controls cover exact11-argument UI calls, arbitrary DWORD returns and caller-visible byte masks. F1344/world bodies and Main remain outside the proof.',
        'counted_in_functional_totals': False, 'Main_integrated': False,
        'private_source_or_fixture_inputs_changed': False}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    args.output.with_name('replay-stdout.txt').write_text(replay_output)
    args.output.with_name('controls-stdout.json').write_text(controls_output)
    print(json.dumps({'status': 'verified', 'replayed_native_cases': fixture['case_count'],
        'typed_boundaries': fixture['typed_boundary_count'], 'additional_interface_controls': controls['checks'],
        'original_PE_reproof': original_performed, 'all_source_proof_fixture_inputs_unchanged': True}))


if __name__ == '__main__':
    main()
