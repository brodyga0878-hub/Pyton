#!/usr/bin/env python3
"""Download and verify a published immutable StarFrontier checkpoint."""
import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import urllib.request
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('release', type=Path)
    parser.add_argument('artifact_commit')
    parser.add_argument('output', type=Path)
    parser.add_argument('--include-file', action='append', default=[],
                        help='Also download this exact payload path from the immutable manifest; may be repeated.')
    args = parser.parse_args()
    if not re.fullmatch(r'[0-9a-f]{40}', args.artifact_commit):
        parser.error('A full immutable Git commit is required')
    release = args.release.resolve()
    local = (release/'manifest.json').read_bytes()
    manifest = json.loads(local)
    base = ('https://raw.githubusercontent.com/brodyga0878-hub/Pyton/'
            + args.artifact_commit + '/deliverables/' + release.name + '/')
    args.output.mkdir(parents=True, exist_ok=True)
    report = {'started_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
              'version': manifest['version'], 'artifact_commit': args.artifact_commit,
              'source_commit': manifest['source_commit'], 'files': [], 'status': 'running',
              'requested_extra_files': args.include_file,
              'scope': 'Actual complete HTTPS downloads; immutable manifest bytes, payload SHA256/length, ZIP CRC, source archive Git comment and screenshot hashes. Not physical Android execution.'}
    def download(name, expected):
        path = PurePosixPath(name)
        if path.is_absolute() or '..' in path.parts:
            raise ValueError('Unsafe manifest path')
        url = base+name
        with urllib.request.urlopen(url, timeout=90) as response:
            if response.status != 200:
                raise ValueError('Unexpected HTTP status')
            raw = response.read()
        digest = hashlib.sha256(raw).hexdigest()
        if len(raw) != expected['bytes'] or digest != expected['sha256']:
            raise ValueError('Downloaded size/hash mismatch: '+name)
        target = args.output/name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)
        result = {'file': name, 'url': url, 'http_status': 200,
                  'bytes': len(raw), 'sha256': digest}
        if target.suffix in ('.zip', '.apk'):
            with zipfile.ZipFile(target) as archive:
                if archive.testzip() is not None:
                    raise ValueError('Downloaded archive CRC mismatch: '+name)
                result['zip_crc_verified'] = True
                if name.endswith('-source.zip'):
                    if archive.comment.decode('ascii') != manifest['source_commit']:
                        raise ValueError('Source commit mismatch')
                    if len(archive.infolist()) != manifest['source_archive_files']:
                        raise ValueError('Source archive file count mismatch')
                    result['source_commit_in_zip_comment'] = archive.comment.decode('ascii')
        report['files'].append(result)
        print(name+': verified', flush=True)
        return raw
    try:
        if download('manifest.json', {'bytes': len(local), 'sha256': hashlib.sha256(local).hexdigest()}) != local:
            raise ValueError('Remote manifest differs from local checkpoint')
        names = [name for name in manifest['files'] if name.endswith(('.apk', '-source.zip'))]
        if len(names) != 2:
            raise ValueError('Expected one APK and one source ZIP')
        names += [name for name in manifest['files'] if name.endswith('capture-manifest.json')]
        frames = [name for name in manifest['files'] if name.endswith('.png')]
        names += frames
        for name in args.include_file:
            if name not in manifest['files']:
                raise ValueError('Extra file is absent from the immutable manifest: '+name)
            if name not in names:
                names.append(name)
        for name in names:
            download(name, manifest['files'][name])
        report['status'] = 'verified'
    except Exception as error:
        report['status'] = 'failed'
        report['error'] = str(error)
    report['completed_utc'] = dt.datetime.now(dt.timezone.utc).isoformat()
    (args.output/'verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    return 0 if report['status'] == 'verified' else 1


if __name__ == '__main__':
    raise SystemExit(main())
