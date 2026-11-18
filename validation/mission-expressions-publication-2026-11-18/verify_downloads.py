"""Verify all declared immutable source and optional APK HTTPS payloads."""
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

CHECKPOINT = 'mission-expressions-core-0.30.0-2026-11-18'
UPDATE_NAME = 'StarFrontier-0.30.0-mission-expressions-source-update.zip'
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

def declared_payloads(manifest):
    files=manifest.get('files');require(isinstance(files,dict),'Missing payload inventory')
    apk=manifest.get('apk')
    expected=set(PAYLOADS)
    if apk is not None:
        require(isinstance(apk,dict)and re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*\.apk',str(apk.get('file','')))is not None and apk.get('verification_file')=='android-verification.json','Unsafe APK declaration')
        require(apk.get('version')=='0.30.0-missions-alpha1'and apk.get('version_code')==55 and apk.get('package')=='org.starfrontier.rebuild'and apk.get('abi')=='arm64-v8a'and apk.get('certificate_sha256')=='16f47f20a2d2aca3de1fe893ddfa01e90acf2d6b98b32ca772bb914c9ee21e25'and apk.get('signature_aapt_zipalign_rechecked_at_packaging')is True,'Declared APK identity differs')
        expected.update([apk['file'],apk['verification_file']])
    require(set(files)==expected and manifest.get('new_APK_produced')is(apk is not None),'Source/optional APK payload inventory differs')
    if apk is not None:require(files[apk['file']]=={'bytes':apk.get('bytes'),'sha256':apk.get('sha256')}and apk.get('source_commit')==manifest.get('source_commit'),'APK declaration and payload/source identity differ')
    require(manifest.get('game_version')=='0.30.0-missions-alpha1'and manifest.get('Android_version_code')==55 and manifest.get('new_kernels_connected_to_Main')is False and manifest.get('version_metadata_changes_only')is True,'Source version/Main binding differs')
    return expected,apk


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifact-commit', required=True)
    parser.add_argument('--repo', type=Path, default=Path('/workspace/Pyton'))
    parser.add_argument('--output-dir', type=Path, default=Path('/workspace/recovery/mission-expressions-downloads-final'))
    parser.add_argument('--report-dir', type=Path)
    args = parser.parse_args()
    require(re.fullmatch('[0-9a-f]{40}', args.artifact_commit) is not None, 'Full immutable artifact commit required')
    root = args.repo.resolve()
    release = root / 'deliverables' / CHECKPOINT
    output = args.output_dir.resolve()
    report_dir = args.report_dir.resolve() if args.report_dir else root / 'validation/mission-expressions-publication-2026-11-18'
    require(not output.exists() and not report_dir.exists(), 'Download output and public report directory must be new')
    local_raw = (release / 'manifest.json').read_bytes()
    manifest = json.loads(local_raw)
    require(manifest.get('schema') == 'starfrontier-mission-expressions-core-0.30.0-source-checkpoint-v1' and manifest.get('checkpoint') == CHECKPOINT and manifest.get('required_archive_count') == 2 and manifest.get('previous_update_archive_required') is False, 'Sealed manifest identity differs')
    require(re.fullmatch('[0-9a-f]{40}', manifest.get('source_commit', '')) is not None , 'Manifest source/payload inventory differs')
    payloads,apk_info=declared_payloads(manifest);expected_count=len(payloads)+2
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
        if name.endswith('.apk'):
            with zipfile.ZipFile(target)as archive:require(archive.testzip()is None,'Downloaded APK CRC failed')
            row['APK_CRC_verified']=True
        print(name + ': verified', flush=True)
        return row

    records = [fetch('manifest.json', public_base + 'manifest.json', {'bytes': len(local_raw), 'sha256': sha(local_raw)})]
    require((output / 'manifest.json').read_bytes() == local_raw, 'Published manifest bytes differ')
    jobs = [(name, public_base + name, expected, manifest['source_commit'] if name.endswith('.zip') else None) for name, expected in manifest['files'].items()]
    jobs.append((BASE_NAME, base['url'], base, base['source_commit']))
    with ThreadPoolExecutor(max_workers=3) as pool:
        records += list(pool.map(lambda values: fetch(*values), jobs))
    require(len(records)==expected_count and len({row['url']for row in records})==expected_count,'All declared unique HTTPS downloads required')
    freeze_path = root / 'validation/mission-expressions-2026-11-18/runtime-freeze.json'
    freeze = json.loads(freeze_path.read_text())
    inputs = freeze.get('files_sha256')
    require(isinstance(inputs, dict) and len(inputs) == manifest.get('runtime_inputs') and len(inputs) > 563, 'Current runtime inventory differs')
    for name, digest in inputs.items():
        require(sha((root / name).read_bytes()) == digest, 'Current runtime source differs: ' + name)
    fresh = json.loads((release / 'source-pair-verification.json').read_text())
    require(fresh.get('source_commit') == manifest['source_commit'] and fresh.get('runtime_freeze_sha256') == sha(freeze_path.read_bytes()), 'Fresh source/freeze publication identity differs')
    require(fresh.get('source_game_version')=='0.30.0-missions-alpha1'and fresh.get('source_android_code')==55 and fresh.get('version_metadata_changes_only')is True,'Fresh source version binding differs')
    if apk_info is not None:
        android=json.loads((output/apk_info['verification_file']).read_text())
        require(android.get('source_commit')==manifest['source_commit']and android.get('runtime_freeze_sha256')==sha(freeze_path.read_bytes())and android.get('runtime_inputs_match_frozen_source')is True,'Downloaded APK proof does not bind exact source/freeze')
        require(android.get('sha256')==apk_info['sha256']and android.get('bytes')==apk_info['bytes']and android.get('version')==apk_info['version']and android.get('version_code')==55 and android.get('signature_verified')is True and android.get('certificate_sha256')==apk_info['certificate_sha256']and android.get('new_kernels_connected_to_Main')is False,'Downloaded APK proof identity/scope differs')
    proof = {
        'schema': 'starfrontier-mission-expressions-core-0.30.0-source-publication-v1',
        'status': 'verified',
        'completed_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
        'checkpoint': manifest['checkpoint'],
        'artifact_commit': args.artifact_commit,
        'source_commit': manifest['source_commit'],
        'files': records,
        'actual_complete_HTTPS_downloads': len(records),
        'all_manifest_payloads_downloaded': True,
        'manifest_payload_count': len(payloads),
        'required_source_archives_downloaded': 2,
        'runtime_inputs_verified': len(inputs),
        'runtime_freeze_sha256': sha(freeze_path.read_bytes()),
        'all_current_runtime_inputs_match_frozen_source': True,
        'new_APK_produced': apk_info is not None,
        'apk': apk_info,
        'new_kernels_connected_to_Main': False,
        'physical_device_tested': False,
        'full_original_port_complete': False,
        'scope': 'All declared complete immutable HTTPS downloads: source payloads, optional technically verified APK/proof and exact0.28 base. SHA/lengths, source ZIP CRCs/comments, APK CRC when supplied and frozen runtime inputs pass. Source version0.30/code55 metadata changes are authorized; new kernels remain separate from Main and no on-device/full-port result is claimed.',
    }
    report_dir.mkdir(parents=True, exist_ok=False)
    (report_dir / 'verification.json').write_text(json.dumps(proof, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'status': 'verified', 'actual_complete_HTTPS_downloads': expected_count, 'required_source_archives_downloaded': 2, 'runtime_inputs': len(inputs)}))

if __name__ == '__main__':
    main()
