#!/usr/bin/env python3
"""Record the completed, independently verified frozen-source Android build.

Run only after build_android.sh and the APK verifier have both succeeded. The
required exit status is the caller's observed build process result, not a value
inferred from an existing artifact.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import shutil
import zipfile

ROOT = Path('/workspace/Pyton')
VALIDATION = ROOT / 'validation/mission-statements-2026-11-19'
OUTPUT = ROOT / 'deliverables/mission-statements-core-0.32.0-2026-11-19'
PROJECT = Path('/workspace/recovery/mission-statements-source-pair-fresh/source/StarFrontier-0.28.0-source')
VERSION = '0.32.0-statements-alpha1'
CODE = 57


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def read_json(path):
    raw = path.read_bytes()
    return json.loads(raw), sha(raw)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-exit-code', required=True, type=int,
                        help='Actual observed exit code of the fresh build_android.sh invocation.')
    parser.add_argument('--source-commit', required=True)
    args = parser.parse_args()
    source_commit = args.source_commit
    require(re.fullmatch(r'[0-9a-f]{40}', source_commit) is not None, 'Full immutable source commit required')
    require(args.build_exit_code == 0, 'The fresh Android export must have exited successfully')

    freeze_path = VALIDATION / 'runtime-freeze.json'
    freeze, freeze_sha = read_json(freeze_path)
    pair_path = OUTPUT / 'source-pair-verification.json'
    pair, pair_sha = read_json(pair_path)
    proof_path = OUTPUT / 'android-verification.json'
    proof, proof_sha = read_json(proof_path)
    require(pair.get('ok') is True and pair.get('status') == 'verified', 'Source pair is not verified')
    require(proof.get('status') == 'verified', 'APK is not verified')
    require(pair.get('source_commit') == proof.get('source_commit') == source_commit,
            'Source-pair/APK frozen source identity differs')
    require(pair.get('runtime_freeze_sha256') == proof.get('runtime_freeze_sha256') == freeze_sha,
            'Source-pair/APK runtime freeze binding differs')
    require(Path(pair['source_project_path']).resolve() == PROJECT.resolve(),
            'APK build project is not the verified fresh source pair')
    require(freeze.get('source_game_version') == pair.get('source_game_version') ==
            proof.get('version') == VERSION, 'Frozen source/APK version differs')
    require(freeze.get('source_android_code') == pair.get('source_android_code') ==
            proof.get('version_code') == CODE, 'Frozen source/APK version code differs')
    require(pair.get('all_runtime_inputs_match_frozen_source') is True and
            pair.get('all_source_files_unchanged') is True and
            proof.get('runtime_inputs_match_frozen_source') is True and
            proof.get('source_pair_verified') is True, 'Source ownership checks are missing')

    runtime = freeze['files_sha256']
    require(runtime and len(runtime) == freeze['runtime_input_count'] ==
            pair['runtime_inputs_verified'] == proof['runtime_inputs_verified'],
            'Runtime input inventory counts differ')
    require(sha((PROJECT / freeze_path.relative_to(ROOT)).read_bytes()) == freeze_sha,
            'The fresh project contains a different runtime freeze')
    for path, digest in runtime.items():
        require(sha((PROJECT / path).read_bytes()) == digest,
                'Frozen runtime source changed through compilation: ' + path)

    archives = {}
    for prefix in ('base', 'update'):
        path = Path(pair[prefix + '_archive_path'])
        raw = path.read_bytes()
        digest = sha(raw)
        require(digest == pair[prefix + '_archive_sha256'] and
                len(raw) == pair[prefix + '_archive_bytes'], 'Source archive changed: ' + prefix)
        archives[prefix] = {'file': path.name, 'bytes': len(raw), 'sha256': digest}

    info = (PROJECT / 'scripts/build_info.gd').read_text()
    source_version = re.search(r'^const\s+VERSION\s*:=\s*"([^"]+)"\s*$', info, re.M)
    source_code = re.search(r'^const\s+VERSION_CODE\s*:=\s*(\d+)\s*$', info, re.M)
    require(source_version and source_code and source_version[1] == VERSION and
            int(source_code[1]) == CODE, 'Fresh project BuildInfo metadata differs')
    preset = (PROJECT / 'export_presets.cfg').read_text()
    require(re.findall(r'^version/code=(\d+)\s*$', preset, re.M) == [str(CODE)] and
            re.findall(r'^version/name="([^"]+)"\s*$', preset, re.M) == [VERSION],
            'Fresh project Android preset metadata differs')
    embedded = proof['embedded_build_info']
    require(embedded.get('actual_exported_bytecode_loaded') is True and
            embedded.get('version') == source_version[1] and
            embedded.get('version_code') == int(source_code[1]), 'Embedded BuildInfo differs')

    apk = OUTPUT / 'StarFrontier-0.32.0-statements-arm64.apk'
    apk_raw = apk.read_bytes()
    apk_sha = sha(apk_raw)
    require(proof.get('apk') == apk.name and proof.get('sha256') == apk_sha and
            proof.get('bytes') == len(apk_raw), 'Actual APK differs from APK verification')
    build_apk = PROJECT / 'build/starfrontier-rebuild-arm64-alpha.apk'
    require(sha(build_apk.read_bytes()) == apk_sha, 'Published candidate differs from fresh exported APK')
    scripts = {n: h for n, h in runtime.items() if n.startswith('scripts/') and n.endswith('.gd')}
    resources = {n: h for n, h in runtime.items() if n.startswith('data/') and n.endswith('.json')}
    compiled = proof['compiled_modules']
    require(scripts and set(compiled) == set(scripts), 'Compiled source inventory differs from runtime freeze')
    require(proof['data_assets_sha256'] == resources, 'Verified JSON inventory differs from runtime freeze')
    require(proof.get('all_script_bytecode_headers_valid') is True and
            proof.get('compiled_source_correspondence_rebuilt_by_verifier') is True,
            'Independent compiled-source correspondence is missing')
    reproduction = proof['independent_android_recompilation']
    require(reproduction.get('compiled_script_count') == len(compiled) and
            reproduction.get('all_compiled_script_bytes_match') is True and
            reproduction.get('actual_engine_pack_mounted') is True,
            'Independent Android bytecode reproduction is incomplete')
    with zipfile.ZipFile(apk) as archive:
        require(archive.testzip() is None, 'Actual APK ZIP CRC failed')
        for path, digest in compiled.items():
            raw = archive.read('assets/' + path[:-3] + '.gdc')
            require(raw.startswith(b'GDSC') and sha(raw) == digest,
                    'Actual exported bytecode differs: ' + path)
        for path, digest in resources.items():
            require(sha(archive.read('assets/' + path)) == digest,
                    'Actual exported JSON differs: ' + path)
    require(proof.get('signature_verified') is True and proof.get('zipalign_16k') is True and
            proof.get('test_key_only') is True and proof.get('abi') == 'arm64-v8a',
            'APK signature/alignment/ABI verification is incomplete')
    require(proof.get('new_kernels_connected_to_Main') is False and
            proof.get('physical_device_tested') is False, 'Unexpected integration/device proof scope')

    export_log = PROJECT / 'build/android-export.log'
    log_raw = export_log.read_bytes()
    log = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', log_raw.decode(errors='replace'))
    require('[ DONE ] export' in log and 'Verifying APK...' in log and '\nSigned\n' in log,
            'Fresh export log does not record completed signing/verification/export')
    require(not re.search(r'^\s*(SCRIPT ERROR:|ERROR:)|ObjectDB instances leaked|RID allocations of type',
                          log, re.M), 'Fresh export log contains engine errors')
    target_log = VALIDATION / 'android-build.log'
    shutil.copyfile(export_log, target_log)
    require(sha(target_log.read_bytes()) == sha(log_raw), 'Archived Android build log differs')
    result = {
        'schema': 'starfrontier-mission-statements-android-build-provenance-v1',
        'status': 'verified', 'created_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
        'source_commit': source_commit, 'runtime_freeze_sha256': freeze_sha,
        'source_pair_verification_sha256': pair_sha, 'android_verification_sha256': proof_sha,
        'source_archives': archives, 'build_project': str(PROJECT),
        'command': ['sh', 'tools/build_android.sh', '--candidate'],
        'project_selection_environment': 'STARFRONTIER_PROJECT_ROOT',
        'fresh_export_exit_code': args.build_exit_code,
        'export_exit_code_source': 'Caller-observed completed build_android.sh process status',
        'build_log': target_log.name, 'build_log_sha256': sha(log_raw),
        'apk_file': apk.name, 'apk_bytes': len(apk_raw), 'apk_sha256': apk_sha,
        'version': embedded['version'], 'version_code': embedded['version_code'],
        'compiled_source_correspondence_independently_verified': True,
        'compiled_scripts': len(compiled), 'exact_JSON_resources': len(resources),
        'all_runtime_inputs_unchanged_through_compilation': True,
        'runtime_input_count': len(runtime), 'test_key_only': proof['test_key_only'],
        'Main_integrated': proof['new_kernels_connected_to_Main'],
        'physical_device_tested': proof['physical_device_tested'],
    }
    target = VALIDATION / 'android-build-provenance.json'
    target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ('status', 'version', 'version_code', 'apk_bytes',
                     'apk_sha256', 'compiled_scripts', 'exact_JSON_resources', 'runtime_input_count')}, indent=2))


if __name__ == '__main__':
    main()
