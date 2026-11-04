#!/usr/bin/env python3
"""Extend native F581→F1876 controls to the remaining audited terrain models.

The four-model baseline fixture is unchanged. Nonuniform model 117 is included
as a raw-query control; its largest static axis only selects outside-observer
probes and a broad synthetic branch-forcing bound, not a spherical SI radius.
"""
import argparse
import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDITIONAL_MODELS = [number for number in range(117, 134) if number not in [119, 125, 129, 133]]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('executable', type=Path)
    parser.add_argument('--data-source', type=Path)
    parser.add_argument('--project', type=Path, default=ROOT)
    parser.add_argument('--fixture-name', default='terrain_additional_query_reference.json')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='ffe-terrain-additional-') as directory:
        output = Path(directory)
        command = [sys.executable, str(ROOT/'tools/build_terrain_game_query_reference.py'),
                   str(args.source), str(args.executable), '--project', str(output),
                   '--model-ids', ','.join(str(number) for number in ADDITIONAL_MODELS),
                   '--largest-axis-probes']
        if args.data_source is not None:
            command += ['--data-source', str(args.data_source)]
        subprocess.run(command, check=True, capture_output=True, timeout=45)
        report = json.loads((output/'tests/fixtures/terrain_game_query_reference.json').read_text())
    report['revision'] = 'terrain-additional-query-raw-v1'
    report['scope'] += (' Additional audited source models 117..133 excluding the four-model baseline '
                        '119/125/129/133. Collision prefixes 1082ff and 1083ff both retain their actual '
                        'source command payload. The largest static basis axis selects raw outside-observer '
                        'probe distance and synthetic outer bound only. Model117 has nonuniform static '
                        'axes; these controls do not make it eligible for a spherical runtime provider.')
    report['additional_models'] = ADDITIONAL_MODELS
    report['baseline_models_not_duplicated'] = [119, 125, 129, 133]
    report['probe_radius_policy'] = 'Largest absolute static axis, only for fixture input generation'
    report['builder_sha256'] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    destination = args.project/'tests/fixtures'/args.fixture_name
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, separators=(',', ':'))+'\n')
    print('Additional original F581 terrain queries:', len(report['cases']),
          '; models:', ADDITIONAL_MODELS,
          '; interleaved repeats:', report['same_process_interleaved_repeat_checks'])


if __name__ == '__main__':
    main()
