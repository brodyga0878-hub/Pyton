#!/usr/bin/env python3
"""Consolidate successful, fully downloaded code53 publication evidence.

No network, Git, build, artifact or source writes occur. Run only after the
actual immutable HTTPS downloader succeeded. The sole output is the final
validation/native-station-publication-2026-11-16/verification.json proof.
"""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import stat
import zipfile

VERSION = '0.28.0-native-station-alpha1'
SOURCE_COMMIT = 'de8eb18a687d007781321436910187dff3785775'
FREEZE = 'validation/native-station-2026-11-16/runtime-freeze.json'
FREEZE_SHA = 'e4f8fa4a37f154c8fef97851e0203c7a8a1aec619a331ba7cc417fc2e6308d99'
OUTPUT = 'validation/native-station-publication-2026-11-16/verification.json'
SOURCE_PREFIX = 'StarFrontier-0.28.0-source/'
REPORT_ZIP = 'sample-native-station-include-save-report.zip'
EXPECTED_RUNTIME_COUNT = 475
LIMIT_BYTES = 33554432


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def safe_name(name):
    require(isinstance(name, str) and name and '\x00' not in name, 'Invalid manifest/download path')
    path = PurePosixPath(name)
    require(not path.is_absolute() and '..' not in path.parts and str(path) == name,
            'Unsafe manifest/download path: ' + str(name))
    return name


def checked_bytes(folder, name):
    safe_name(name)
    path = folder / name
    require(path.is_file() and not path.is_symlink()
            and path.resolve().is_relative_to(folder.resolve()), 'Unsafe or missing local file: ' + name)
    return path.read_bytes()


def expected_row(row, label):
    require(isinstance(row, dict) and type(row.get('bytes')) is int and row['bytes'] >= 0
            and isinstance(row.get('sha256'), str)
            and re.fullmatch(r'[0-9a-f]{64}', row['sha256']) is not None,
            'Invalid byte/hash metadata: ' + label)


def verify_bytes(raw, expected, label):
    expected_row(expected, label)
    require(len(raw) == expected['bytes'] and digest(raw) == expected['sha256'],
            'Actual bytes/length/SHA mismatch: ' + label)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path('/workspace/Pyton'))
    parser.add_argument('--downloads', type=Path,
                        default=Path('/workspace/recovery/native-station-downloads-final'))
    parser.add_argument('--artifact-commit', help='Optional full immutable artifact SHA; otherwise read the actual downloader report')
    args = parser.parse_args()
    root = args.root.resolve()
    downloads = args.downloads.resolve()
    release = root / 'deliverables' / VERSION
    raw_report = checked_bytes(downloads, 'verification.json')
    report = json.loads(raw_report)
    require(isinstance(report, dict) and report.get('status') == 'verified',
            'Actual complete HTTPS download verification must succeed first')
    require(report.get('version') == VERSION, 'Wrong actual HTTP release version')
    artifact = report.get('artifact_commit', '')
    require(isinstance(artifact, str) and re.fullmatch(r'[0-9a-f]{40}', artifact) is not None,
            'The actual HTTP report requires a full immutable artifact SHA')
    if args.artifact_commit:
        require(re.fullmatch(r'[0-9a-f]{40}', args.artifact_commit) is not None
                and args.artifact_commit == artifact, 'Requested artifact differs from actual downloaded commit')
    require(report.get('source_commit') == SOURCE_COMMIT, 'Wrong exact source commit in actual HTTP proof')
    manifest_raw = checked_bytes(release, 'manifest.json')
    manifest = json.loads(manifest_raw)
    require(manifest.get('version') == VERSION and manifest.get('version_code') == 53
            and manifest.get('source_commit') == SOURCE_COMMIT, 'Wrong sealed code53 manifest identity')
    payloads = manifest.get('files')
    require(isinstance(payloads, dict) and payloads, 'Missing sealed manifest payload inventory')
    for name, expected in payloads.items():
        verify_bytes(checked_bytes(release, name), expected, 'local payload ' + name)
    apk_names = [name for name in payloads if name.endswith('.apk')]
    source_names = [name for name in payloads if name.endswith('-source.zip')]
    capture_names = [name for name in payloads if name.endswith('capture-manifest.json')]
    png_names = sorted(name for name in payloads if name.endswith('.png'))
    require(len(apk_names) == len(source_names) == len(capture_names) == 1 and len(png_names) == 4
            and REPORT_ZIP in payloads, 'Expected exact APK, source ZIP, capture manifest, four PNGs and production report ZIP')
    expected_names = {'manifest.json', *apk_names, *source_names, *capture_names, *png_names, REPORT_ZIP}
    require(len(expected_names) == 9, 'The public download subset must contain exactly nine distinct files')
    downloaded = report.get('files')
    require(isinstance(downloaded, list) and len(downloaded) == 9, 'Nine actual full HTTPS downloads are required')
    base = ('https://raw.githubusercontent.com/brodyga0878-hub/Pyton/' + artifact
            + '/deliverables/' + VERSION + '/')
    names = set()
    source_archive = downloads / source_names[0]
    for entry in downloaded:
        require(isinstance(entry, dict), 'Malformed actual HTTP entry')
        name = safe_name(entry.get('file'))
        require(name not in names and name in expected_names, 'Duplicate or unexpected actual HTTP file: ' + name)
        names.add(name)
        require(entry.get('http_status') == 200 and entry.get('url') == base + name,
                'Actual HTTP status or immutable URL mismatch: ' + name)
        expected = {'bytes': len(manifest_raw), 'sha256': digest(manifest_raw)} if name == 'manifest.json' else payloads[name]
        require(entry.get('bytes') == expected['bytes'] and entry.get('sha256') == expected['sha256'],
                'Actual downloader record differs from sealed metadata: ' + name)
        raw = checked_bytes(downloads, name)
        verify_bytes(raw, expected, 'actual downloaded file ' + name)
        if name == 'manifest.json':
            require(raw == manifest_raw, 'The downloaded manifest differs from its locally sealed bytes')
        if name.endswith(('.zip', '.apk')):
            require(entry.get('zip_crc_verified') is True, 'The actual downloader did not verify archive CRC: ' + name)
            with zipfile.ZipFile(downloads / name) as archive:
                require(archive.testzip() is None, 'Downloaded archive CRC failed: ' + name)
                if name == source_names[0]:
                    require(entry.get('source_commit_in_zip_comment') == SOURCE_COMMIT
                            and archive.comment.decode('ascii') == SOURCE_COMMIT,
                            'The exact source ZIP Git comment differs')
                    require(len(archive.infolist()) == manifest.get('source_archive_files'),
                            'Downloaded source ZIP entry count differs from its sealed manifest')
        if name.endswith('.png'):
            require(raw.startswith(b'\x89PNG\r\n\x1a\n'), 'Downloaded frame is not a PNG: ' + name)
    require(names == expected_names, 'A required complete HTTP download is absent')
    require((downloads / source_names[0]).stat().st_size < LIMIT_BYTES,
            'Downloaded source ZIP exceeds the chat-upload limit')
    freeze_raw = checked_bytes(root, FREEZE)
    require(digest(freeze_raw) == FREEZE_SHA, 'The original exact code53 runtime freeze changed')
    freeze = json.loads(freeze_raw)
    require(freeze.get('version') == VERSION and freeze.get('version_code') == 53, 'Wrong code53 runtime freeze identity')
    runtime = freeze.get('files_sha256')
    require(isinstance(runtime, dict) and len(runtime) == EXPECTED_RUNTIME_COUNT,
            'Exactly475 frozen current runtime inputs are required')
    for name, sha in runtime.items():
        require(isinstance(sha, str) and re.fullmatch(r'[0-9a-f]{64}', sha) is not None,
                'Invalid frozen runtime SHA: ' + name)
        require(digest(checked_bytes(root, name)) == sha, 'Live runtime changed after freeze: ' + name)
    with zipfile.ZipFile(source_archive) as archive:
        require(archive.read(SOURCE_PREFIX + FREEZE) == freeze_raw,
                'The downloaded source ZIP does not embed the original exact runtime freeze')
        actual_files = [entry for entry in archive.infolist() if not entry.is_dir()]
        for entry in actual_files:
            safe_name(entry.filename)
            require(stat.S_IFMT(entry.external_attr >> 16) != stat.S_IFLNK,
                    'A downloaded source ZIP entry is a symlink')
        for name, sha in runtime.items():
            require(digest(archive.read(SOURCE_PREFIX + name)) == sha,
                    'Downloaded source runtime differs from the current frozen source: ' + name)
    payload_count = len(payloads)
    remaining = payload_count - (len(downloaded) - 1)
    require(remaining >= 0, 'Impossible remaining auxiliary payload count')
    output = dict(report)
    output.update({
        'schema': 'starfrontier-native-station-publication-v1',
        'all_manifest_payloads_downloaded': False,
        'local_manifest_payload_count': payload_count,
        'all_local_manifest_payload_hashes_verified': True,
        'auxiliary_payloads_not_individually_downloaded': remaining,
        'local_manifest_sha256': digest(manifest_raw),
        'actual_HTTP_download_report_sha256': digest(raw_report),
        'release_download_verifier_sha256': digest(checked_bytes(root, 'tools/verify_release_downloads.py')),
        'runtime_freeze_sha256': digest(freeze_raw),
        'runtime_inputs_verified': EXPECTED_RUNTIME_COUNT,
        'all_current_runtime_inputs_match_frozen_inputs': True,
        'downloaded_source_archive_runtime_inputs_verified': EXPECTED_RUNTIME_COUNT,
        'downloaded_source_archive_actual_files': len(actual_files),
        'downloaded_source_archive_crc_and_comment_reverified': True,
        'local_reverification_completed_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
        'physical_device_tested': False,
        'production_release_ready': False,
        'full_clone_completed': False,
        'sealed_manifest_keeps_prepublication_status': True,
        'source_documents_keep_source_commit_prepublication_status': True,
        'station_handoff_max_distance_m': 100000,
        'full_35Mm_surface_to_station_transit_flown': False,
        'ongoing_inertial_trajectory_equivalence_claimed': False,
        'publication_scope': (
            'Nine actual complete immutable HTTPS downloads: manifest, APK, exact source ZIP, capture manifest, '
            'four actual framebuffer PNGs and production include-save report ZIP. All local manifest payloads '
            'and all475 runtime inputs verified, including embedded downloaded source bytes. Auxiliary count '
            'explicitly records files not individually downloaded. Bounded same-parent station handoff within100km '
            'uses sampled original-ephemeris origin translation/velocity. Subsequent flight retains the existing '
            'station-following mobile law. Near-station fixtures do not prove a flown35Mm planetary-to-station '
            'transit or full F570/F606 dispatcher. No physical Android, FPS, full-clone or production-release claim.'
        ),
    })
    # Keep all fields from the actual HTTP verifier byte-for-value intact.
    require(all(output[key] == value for key, value in report.items()), 'Actual HTTP verifier fields changed')
    path = root / OUTPUT
    require(not path.is_symlink(), 'Publication proof output must not be a symlink')
    require(not path.exists(), 'Refuse to overwrite an existing publication proof')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'status': 'verified', 'version': VERSION, 'artifact_commit': artifact,
                      'source_commit': SOURCE_COMMIT, 'actual_complete_HTTPS_downloads': len(downloaded),
                      'local_payloads_verified': payload_count, 'auxiliary_payloads_not_individually_downloaded': remaining,
                      'runtime_inputs_verified': EXPECTED_RUNTIME_COUNT, 'output': str(path)}, indent=2))


if __name__ == '__main__':
    main()
