"""Verify seven complete immutable HTTPS downloads after artifact publication."""
from __future__ import annotations
import argparse
from concurrent.futures import ThreadPoolExecutor
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import urllib.request
import zipfile

CHECKPOINT = 'equipment-effects-core-2026-11-18'
UPDATE_NAME = 'StarFrontier-equipment-effects-core-update.zip'
BASE_NAME = 'StarFrontier-0.28.0-native-station-source.zip'
BASE_SHA = '830e7219879f694a24e41f579417986f936902f6592926ff8e84dc99217b6c2d'
BASE_BYTES = 33543341
BASE_COMMIT = 'de8eb18a687d007781321436910187dff3785775'
BASE_URL = 'https://raw.githubusercontent.com/brodyga0878-hub/Pyton/f6d802e5f34f735eef91fdc2670bc8850443511a/deliverables/0.28.0-native-station-alpha1/' + BASE_NAME
PAYLOADS = {'README_RU.md', UPDATE_NAME, 'functional-summary.json', 'source-pair-verification.json', 'source-update-policy.json'}

def require(ok, reason):
    if not ok:
        raise ValueError(reason)

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifact-commit', required=True)
    parser.add_argument('--repo', type=Path, default=Path('/workspace/Pyton'))
    parser.add_argument('--output-dir', type=Path, default=Path('/workspace/recovery/equipment-effects-downloads-final'))
    parser.add_argument('--report-dir', type=Path)
    args = parser.parse_args()
    require(re.fullmatch('[0-9a-f]{40}', args.artifact_commit) is not None, 'Full immutable artifact commit required')
    root = args.repo.resolve()
    release = root / 'deliverables' / CHECKPOINT
    output = args.output_dir.resolve()
    report_dir = args.report_dir.resolve() if args.report_dir else root / 'validation/equipment-effects-publication-2026-11-18'
    require(not output.exists() and not report_dir.exists(), 'Download output and public report directory must be new')
    local_raw = (release / 'manifest.json').read_bytes()
    manifest = json.loads(local_raw)
    require(manifest.get('schema') == 'starfrontier-equipment-effects-core-source-checkpoint-v1' and manifest.get('checkpoint') == CHECKPOINT and manifest.get('required_archive_count') == 2 and manifest.get('previous_update_archive_required') is False, 'Sealed manifest identity differs')
    require(re.fullmatch('[0-9a-f]{40}', manifest.get('source_commit', '')) is not None and set(manifest.get('files', {})) == PAYLOADS, 'Manifest source/payload inventory differs')
    base = manifest.get('base_archive', {})
    require(base.get('url') == BASE_URL and base.get('sha256') == BASE_SHA and base.get('bytes') == BASE_BYTES and base.get('source_commit') == BASE_COMMIT, 'Pinned full source base differs')
    for name, expected in manifest['files'].items():
        raw = (release / name).read_bytes()
        require(len(raw) == expected.get('bytes') and sha(raw) == expected.get('sha256'), 'Local sealed payload differs: ' + name)
    output.mkdir(parents=True, exist_ok=False)
    public_base = 'https://raw.githubusercontent.com/brodyga0878-hub/Pyton/' + args.artifact_commit + '/deliverables/' + CHECKPOINT + '/'

    def fetch(name, url, expected, source_commit=None):
        require(name == Path(name).name and bool(name), 'Unsafe download basename')
        require(type(expected.get('bytes')) is int and expected['bytes'] > 0 and re.fullmatch('[0-9a-f]{64}', expected.get('sha256', '')) is not None, 'Invalid declared payload identity')
        target = output / name
        digest = hashlib.sha256()
        size = 0
        with urllib.request.urlopen(url, timeout=45) as response, target.open('xb') as stream:
            require(response.status == 200, 'HTTPS status differs: ' + name)
            while True:
                block = response.read(1024 * 1024)
                if not block:
                    break
                stream.write(block)
                digest.update(block)
                size += len(block)
        require(size == expected['bytes'] and digest.hexdigest() == expected['sha256'], 'Downloaded SHA/length differs: ' + name)
        row = {'file': name, 'url': url, 'http_status': 200, 'bytes': size, 'sha256': digest.hexdigest()}
        if name.endswith('.zip'):
            with zipfile.ZipFile(target) as archive:
                require(archive.testzip() is None and archive.comment.decode('ascii') == source_commit, 'Downloaded ZIP CRC/source comment differs: ' + name)
            row.update(zip_CRC_verified=True, source_commit_in_ZIP_comment=source_commit)
        print(name + ': verified', flush=True)
        return row

    records = [fetch('manifest.json', public_base + 'manifest.json', {'bytes': len(local_raw), 'sha256': sha(local_raw)})]
    require((output / 'manifest.json').read_bytes() == local_raw, 'Published manifest bytes differ')
    jobs = [(name, public_base + name, expected, manifest['source_commit'] if name.endswith('.zip') else None) for name, expected in manifest['files'].items()]
    jobs.append((BASE_NAME, base['url'], base, base['source_commit']))
    with ThreadPoolExecutor(max_workers=3) as pool:
        records += list(pool.map(lambda values: fetch(*values), jobs))
    require(len(records) == 7 and len({row['url'] for row in records}) == 7 and len(manifest['files']) == 5, 'Seven complete unique HTTPS downloads required')
    freeze_path = root / 'validation/equipment-effects-2026-11-18/runtime-freeze.json'
    freeze = json.loads(freeze_path.read_text())
    inputs = freeze.get('files_sha256')
    require(isinstance(inputs, dict) and len(inputs) == manifest.get('runtime_inputs') and len(inputs) > 538, 'Current runtime inventory differs')
    for name, digest in inputs.items():
        require(sha((root / name).read_bytes()) == digest, 'Current runtime source differs: ' + name)
    fresh = json.loads((release / 'source-pair-verification.json').read_text())
    require(fresh.get('source_commit') == manifest['source_commit'] and fresh.get('runtime_freeze_sha256') == sha(freeze_path.read_bytes()), 'Fresh source/freeze publication identity differs')
    proof = {
        'schema': 'starfrontier-equipment-effects-core-source-publication-v1',
        'status': 'verified',
        'completed_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
        'checkpoint': manifest['checkpoint'],
        'artifact_commit': args.artifact_commit,
        'source_commit': manifest['source_commit'],
        'files': records,
        'actual_complete_HTTPS_downloads': len(records),
        'all_manifest_payloads_downloaded': True,
        'manifest_payload_count': 5,
        'required_source_archives_downloaded': 2,
        'runtime_inputs_verified': len(inputs),
        'runtime_freeze_sha256': sha(freeze_path.read_bytes()),
        'all_current_runtime_inputs_match_frozen_source': True,
        'new_APK_produced': False,
        'new_kernels_connected_to_Main': False,
        'physical_device_tested': False,
        'full_original_port_complete': False,
        'scope': 'Seven actual complete immutable HTTPS downloads: sealed manifest, all five checkpoint payloads and the complete0.28 base source ZIP. SHA/lengths, both ZIP CRCs/source comments and all declared frozen runtime inputs pass. The equipment/effects/resource kernels and their state owners are separate from Main; this is not a new APK, a complete world/damage engine or an on-device result.',
    }
    report_dir.mkdir(parents=True, exist_ok=False)
    (report_dir / 'verification.json').write_text(json.dumps(proof, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'status': 'verified', 'actual_complete_HTTPS_downloads': 7, 'required_source_archives_downloaded': 2, 'runtime_inputs': len(inputs)}))

if __name__ == '__main__':
    main()
