#!/usr/bin/env python3
"""Build the exact portable code53 source ZIP from a pinned committed tree.

Preparation is non-mutating. Run only after the intended source commit has been
provided. All archive contents come from that immutable commit; working-tree
edits, caches, credentials, generated APKs and private user:// files are never
consulted for selection or runtime validation.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import tempfile
import zipfile

VERSION = '0.28.0-native-station-alpha1'
VERSION_CODE = 53
ARCHIVE_PREFIX = 'StarFrontier-0.28.0-source/'
LIMIT_BYTES = 33554432
EXPECTED_RUNTIME_FILES = 475
CORE_ROOTS = frozenset({'assets', 'data', 'scripts', 'scenes', 'tests', 'tools',
                        'docs', 'recovered-history'})
CURRENT_PROOFS = 'validation/native-station-2026-11-16/'
CODE52_QA = 'validation/native-return-2026-11-16/'
CODE52_FREEZE = CODE52_QA + 'runtime-freeze.json'
CODE52_PORTABILITY = 'validation/native-return-source-portability-2026-11-16/'
CURRENT_FREEZE = CURRENT_PROOFS + 'runtime-freeze.json'
SEPARATE_APK_AUDIT = CURRENT_PROOFS + 'android-verification.json'
SEPARATE_CAPTURE_AND_LOG_PROOFS = frozenset({
    CURRENT_PROOFS + 'capture-runtime-inputs.json',
    CURRENT_PROOFS + 'capture.log',
    CURRENT_PROOFS + 'packaging-unit-tests.log',
})


def separately_delivered_current_proof(name: str) -> bool:
    return (name == SEPARATE_APK_AUDIT or name in SEPARATE_CAPTURE_AND_LOG_PROOFS
            or name.startswith(CURRENT_PROOFS + 'screenshots/'))
PRIOR_RELATIVE = ('deliverables/0.27.0-native-return-alpha1/'
                  'StarFrontier-0.27.0-native-return-source.zip')
PRIOR_SOURCE_COMMIT = '1909e283fa6a9d4dfd2d57245ce3af82eebd7a45'
PRIOR_ZIP_SHA256 = '673ec87cdfb9434c778f11fb70fb0b443fb6811ca0e96f0eea534b02cbca391b'
PRIOR_ACTUAL_FILES = 1641
PRIOR_ZIP_ENTRIES = 1810
FORBIDDEN_SOURCE_SUFFIXES = frozenset({'.apk', '.zip', '.rar', '.exe', '.dll',
                                      '.so', '.pck', '.gdc', '.o', '.a',
                                      '.class', '.jar', '.keystore', '.jks',
                                      '.pem', '.key', '.pyc'})
CURRENT_PROOF_MEDIA_SUFFIXES = frozenset({'.png', '.jpg', '.jpeg', '.webp',
                                        '.zip', '.apk', '.rar'})


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git(repo: Path, *args: str) -> bytes:
    return subprocess.check_output(['git', '--literal-pathspecs', *args], cwd=repo)


def safe_path(value: str) -> bool:
    path = PurePosixPath(value)
    return (value and not path.is_absolute() and '..' not in path.parts
            and '.' not in path.parts and '\\' not in value and '\x00' not in value
            and path.as_posix() == value)


def read_tree(repo: Path, commit: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for entry in git(repo, 'ls-tree', '-r', '-z', '--full-tree', commit).split(b'\0'):
        if not entry:
            continue
        header, raw_path = entry.split(b'\t', 1)
        mode, kind, raw_oid = header.split(b' ', 2)
        name = raw_path.decode('utf-8')
        if not safe_path(name):
            raise ValueError('Unsafe committed source path: ' + repr(name))
        if kind != b'blob' or mode not in (b'100644', b'100755'):
            raise ValueError('Source tree contains a symlink or non-file: ' + name)
        if name in result:
            raise ValueError('Duplicate committed source path: ' + name)
        result[name] = raw_oid.decode('ascii')
    return result


def forbidden_selected_path(name: str) -> bool:
    parts = PurePosixPath(name).parts
    return (any(part in {'.git', '.godot', '__pycache__', 'node_modules'} for part in parts)
            or parts[0] in {'build', 'deliverables', 'private', 'user', 'user_data',
                            'app_userdata', '.codex', '.aws'}
            or PurePosixPath(name).suffix.lower() in FORBIDDEN_SOURCE_SUFFIXES)


def archive_inventory(prior: Path) -> tuple[set[str], dict]:
    raw = prior.read_bytes()
    if sha256(raw) != PRIOR_ZIP_SHA256:
        raise ValueError('The code52 source baseline ZIP SHA does not match its sealed publication')
    files: set[str] = set()
    with zipfile.ZipFile(prior) as archive:
        if len(archive.infolist()) != PRIOR_ZIP_ENTRIES:
            raise ValueError('The pinned code52 source ZIP entry count changed')
        if archive.testzip() is not None:
            raise ValueError('The code52 source baseline ZIP failed CRC verification')
        if archive.comment.decode('ascii') != PRIOR_SOURCE_COMMIT:
            raise ValueError('The code52 baseline ZIP has the wrong source commit comment')
        roots = {PurePosixPath(info.filename).parts[0] for info in archive.infolist()}
        if len(roots) != 1:
            raise ValueError('The code52 source ZIP must have exactly one source root')
        root = next(iter(roots)) + '/'
        for info in archive.infolist():
            if info.is_dir():
                continue
            if not info.filename.startswith(root):
                raise ValueError('A code52 inventory file lies outside its source root')
            name = info.filename[len(root):]
            if not safe_path(name) or name in files:
                raise ValueError('Unsafe or duplicate code52 source inventory path')
            files.add(name)
        if len(files) != PRIOR_ACTUAL_FILES:
            raise ValueError('The prior actual-file inventory count changed')
        metadata = {'path': PRIOR_RELATIVE, 'source_commit': PRIOR_SOURCE_COMMIT,
                    'sha256': sha256(raw), 'bytes': len(raw),
                    'actual_file_count': len(files), 'zip_entries': len(archive.infolist()),
                    'zip_crc_verified': True}
    return files, metadata


def omitted_reason(name: str, prior_files: set[str]) -> str:
    if name == SEPARATE_APK_AUDIT:
        return 'APK_technical_report_delivered_with_exact_APK_bundle_not_required_for_source_build'
    if separately_delivered_current_proof(name):
        return 'capture_media_provenance_or_full_packaging_log_delivered_with_artifact_bundle_not_source_dependency'
    if name.startswith(CODE52_QA) and name != CODE52_FREEZE:
        return 'historical_code52_QA_duplicate_kept_in_Git_and_sealed_0.27_source'
    if name.startswith(CODE52_PORTABILITY):
        return 'historical_code52_portability_duplicate_kept_in_Git_and_artifact_bundle'
    if name.startswith(CURRENT_PROOFS) and PurePosixPath(name).suffix.lower() in CURRENT_PROOF_MEDIA_SUFFIXES:
        return 'current_binary_artifact_or_capture_delivered_separately'
    if name.startswith('deliverables/'):
        return 'published_artifact_bundle_not_source'
    if name not in prior_files:
        return 'existing_prior_archive_policy_omission_retained'
    return 'not_selected_by_portable_source_policy'


def build(args: argparse.Namespace) -> dict:
    repo = args.repo.resolve()
    commit = args.source_commit
    if not re.fullmatch(r'[0-9a-f]{40}', commit):
        raise ValueError('Provide the full immutable 40-character source commit SHA')
    if git(repo, 'cat-file', '-t', commit).strip() != b'commit':
        raise ValueError('The provided source object is not a Git commit')
    tree = read_tree(repo, commit)
    prior_files, prior = archive_inventory(repo / PRIOR_RELATIVE)
    selected: set[str] = set()
    selection_rules: dict[str, str] = {}
    for name in sorted(tree):
        if separately_delivered_current_proof(name):
            continue
        historical_omission = ((name.startswith(CODE52_QA) and name != CODE52_FREEZE)
                               or name.startswith(CODE52_PORTABILITY))
        if historical_omission:
            continue
        top = name.split('/', 1)[0]
        if top in CORE_ROOTS or '/' not in name:
            rule = 'complete_current_source_root_or_root_file'
        elif name.startswith(CURRENT_PROOFS):
            if PurePosixPath(name).suffix.lower() in CURRENT_PROOF_MEDIA_SUFFIXES:
                continue
            rule = 'complete_current_textual_proofs'
        elif name in prior_files:
            rule = 'prior_selected_existing_path_preserved'
        else:
            continue
        if forbidden_selected_path(name):
            raise ValueError('Forbidden binary/cache/private file would enter source: ' + name)
        selected.add(name)
        selection_rules[name] = rule
    if CURRENT_FREEZE not in selected or CODE52_FREEZE not in selected:
        raise ValueError('The new runtime freeze and retained code52 freeze must both be present')
    freeze_raw = git(repo, 'show', commit + ':' + CURRENT_FREEZE)
    freeze = json.loads(freeze_raw)
    runtime = freeze.get('files_sha256')
    if not isinstance(runtime, dict) or len(runtime) != EXPECTED_RUNTIME_FILES:
        raise ValueError('The committed runtime freeze must contain exactly475 input hashes')
    for name, digest in runtime.items():
        if not safe_path(name) or name not in selected or name not in tree:
            raise ValueError('A frozen runtime input is missing from source selection: ' + name)
        if not isinstance(digest, str) or not re.fullmatch(r'[0-9a-f]{64}', digest):
            raise ValueError('Invalid runtime input digest: ' + name)
    core_files = {name for name in tree if name.split('/', 1)[0] in CORE_ROOTS or '/' not in name}
    if not core_files.issubset(selected):
        raise ValueError('At least one current source/core/root file was omitted')
    preserved_prior = {name for name in prior_files & tree.keys()
                       if not ((name.startswith(CODE52_QA) and name != CODE52_FREEZE)
                               or name.startswith(CODE52_PORTABILITY))}
    if not preserved_prior.issubset(selected):
        raise ValueError('At least one prior-selected file was unintentionally omitted')
    prior_native_proofs = {name for name in prior_files & tree.keys() if '/native-proof/' in name}
    if not prior_native_proofs.issubset(selected):
        raise ValueError('A retained original native-proof dependency would be omitted')
    target = (repo / 'deliverables' / VERSION / 'StarFrontier-0.28.0-native-station-source.zip')
    if target.exists():
        raise FileExistsError('Refusing to overwrite an existing source artifact: ' + str(target))
    target.parent.mkdir(parents=True, exist_ok=True)
    args.policy.parent.mkdir(parents=True, exist_ok=True)
    policy = {
        'schema': 'starfrontier-native-station-source-archive-policy-v1',
        'version': VERSION, 'version_code': VERSION_CODE,
        'source_commit': commit, 'created_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
        'status': 'preparing', 'prior_source_inventory': prior,
        'archive_prefix': ARCHIVE_PREFIX,
        'source_file_count': len(selected), 'selected_files': sorted(selected),
        'selection_rule_by_path': selection_rules,
        'source_tree_file_count': len(tree),
        'omitted_source_tree_files': {name: omitted_reason(name, prior_files)
                                      for name in sorted(tree.keys() - selected)},
        'prior_inventory_files_no_longer_in_source_tree': sorted(prior_files - tree.keys()),
        'omitted_historical_code52_QA_files': sorted(name for name in prior_files & tree.keys()
                                                    if name not in selected and name.startswith(CODE52_QA)),
        'retained_code52_freeze': CODE52_FREEZE,
        'all_prior_selected_existing_nonduplicate_paths_retained': True,
        'all_current_core_and_root_files_included': True,
        'all_current_functional_proofs_included': True,
        'all_current_textual_proofs_included': False,
        'separately_delivered_current_APK_audit': SEPARATE_APK_AUDIT,
        'separately_delivered_current_capture_and_log_proofs': sorted(name for name in tree
            if separately_delivered_current_proof(name) and name != SEPARATE_APK_AUDIT),
        'retained_original_native_proof_files': sorted(prior_native_proofs),
        'current_runtime_freeze_path': CURRENT_FREEZE,
        'current_runtime_freeze_sha256': sha256(freeze_raw),
        'required_runtime_inputs': EXPECTED_RUNTIME_FILES,
        'archive_limit_bytes': LIMIT_BYTES,
        'archive_builder_sha256': sha256(Path(__file__).read_bytes()),
        'scope': 'Gitarchive of exact individually selected committed source files. Complete current core/assets/data/tests/tools/docs/history plus prior selected dependencies and current functional proofs. Declared duplicated historical QA, separately delivered APK audit, capture media/provenance and full packaging log are omitted; current packaging summary remains. No Git metadata, imported caches, compiled programs, signing keys or private user state.'}
    try:
        with tempfile.TemporaryDirectory(prefix='native-station-source-', dir='/workspace/recovery') as temporary:
            candidate = Path(temporary) / target.name
            subprocess.run(['git', '--literal-pathspecs', 'archive', '--format=zip', '-9',
                            '--prefix=' + ARCHIVE_PREFIX, '-o', str(candidate), commit,
                            '--', *sorted(selected)], cwd=repo, check=True)
            archive_raw = candidate.read_bytes()
            policy.update({'archive_bytes': len(archive_raw), 'archive_sha256': sha256(archive_raw)})
            with zipfile.ZipFile(candidate) as archive:
                if archive.testzip() is not None:
                    raise ValueError('The new source ZIP failed CRC verification')
                if archive.comment.decode('ascii') != commit:
                    raise ValueError('The new source ZIP Git comment differs from the source commit')
                actual_files = {info.filename[len(ARCHIVE_PREFIX):] for info in archive.infolist()
                                if not info.is_dir() and info.filename.startswith(ARCHIVE_PREFIX)}
                if actual_files != selected:
                    raise ValueError('The Gitarchive inventory differs from the exact selected file list')
                if len([info for info in archive.infolist() if not info.is_dir()]) != len(selected):
                    raise ValueError('Unexpected duplicate or outside-root ZIP entry')
                for name, expected in runtime.items():
                    if sha256(archive.read(ARCHIVE_PREFIX + name)) != expected:
                        raise ValueError('Committed/archived runtime input SHA mismatch: ' + name)
                policy.update({'archive_zip_entries': len(archive.infolist()),
                               'archive_actual_files': len(actual_files),
                               'zip_crc_verified': True, 'git_source_comment_verified': True,
                               'verified_runtime_inputs': len(runtime),
                               'all_runtime_input_hashes_match_committed_freeze': True})
            if len(archive_raw) >= LIMIT_BYTES:
                raise ValueError('The source ZIP must remain strictly smaller than32MiB')
            os.replace(candidate, target)
        policy.update({'status': 'verified', 'archive_path': str(target),
                       'archive_below_32MiB': True,
                       'completed_utc': dt.datetime.now(dt.timezone.utc).isoformat()})
        args.policy.write_text(json.dumps(policy, ensure_ascii=False, indent=2) + '\n')
        return policy
    except Exception as error:
        policy.update({'status': 'failed', 'error': str(error),
                       'completed_utc': dt.datetime.now(dt.timezone.utc).isoformat()})
        args.policy.write_text(json.dumps(policy, ensure_ascii=False, indent=2) + '\n')
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source_commit', help='Full immutable40-character source commit SHA supplied by root')
    parser.add_argument('--repo', type=Path, default=Path('/workspace/Pyton'))
    parser.add_argument('--policy', type=Path,
                        default=Path('/workspace/recovery/native-station-source-archive-policy.json'))
    args = parser.parse_args()
    policy = build(args)
    print(json.dumps({key: policy[key] for key in ('status', 'source_commit', 'archive_path',
                                                   'archive_bytes', 'archive_sha256',
                                                   'archive_actual_files', 'archive_zip_entries',
                                                   'verified_runtime_inputs')}, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
