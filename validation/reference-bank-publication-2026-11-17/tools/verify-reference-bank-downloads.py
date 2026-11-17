from concurrent.futures import ThreadPoolExecutor
import datetime as dt
import hashlib
import json
from pathlib import Path
import urllib.request
import zipfile

ROOT=Path('/workspace/Pyton')
COMMIT='c7a0ec46371e3ac372aea6a2faaa997f38ff515e'
RELEASE=ROOT/'deliverables/reference-bank-core-2026-11-17'
OUT=Path('/workspace/recovery/reference-bank-downloads-final')
BASE_URL='https://raw.githubusercontent.com/brodyga0878-hub/Pyton/'+COMMIT+'/deliverables/reference-bank-core-2026-11-17/'
OUT.mkdir(exist_ok=False)
def sha(raw):return hashlib.sha256(raw).hexdigest()
local_raw=(RELEASE/'manifest.json').read_bytes()
manifest=json.loads(local_raw)
def fetch(name,url,expected,source_commit=None):
    assert name==Path(name).name
    target=OUT/name
    digest=hashlib.sha256();size=0
    with urllib.request.urlopen(url,timeout=45) as response,target.open('xb') as stream:
        assert response.status==200
        while True:
            block=response.read(1024*1024)
            if not block:break
            stream.write(block);digest.update(block);size+=len(block)
    assert size==expected['bytes'] and digest.hexdigest()==expected['sha256'],name
    row={'file':name,'url':url,'http_status':200,'bytes':size,'sha256':digest.hexdigest()}
    if name.endswith('.zip'):
        with zipfile.ZipFile(target) as archive:
            assert archive.testzip() is None
            assert archive.comment.decode('ascii')==source_commit
        row.update(zip_CRC_verified=True,source_commit_in_ZIP_comment=source_commit)
    print(name+': verified',flush=True)
    return row
records=[fetch('manifest.json',BASE_URL+'manifest.json',{'bytes':len(local_raw),'sha256':sha(local_raw)})]
assert (OUT/'manifest.json').read_bytes()==local_raw
jobs=[]
for name,expected in manifest['files'].items():
    local=(RELEASE/name).read_bytes()
    assert len(local)==expected['bytes'] and sha(local)==expected['sha256']
    jobs.append((name,BASE_URL+name,expected,manifest['source_commit'] if name.endswith('.zip') else None))
base=manifest['base_archive']
jobs.append(('StarFrontier-0.28.0-native-station-source.zip',base['url'],base,base['source_commit']))
with ThreadPoolExecutor(max_workers=3) as pool:
    records+=list(pool.map(lambda args:fetch(*args),jobs))
assert len(records)==7 and len(manifest['files'])==5
freeze_path=ROOT/'validation/reference-bank-2026-11-17/runtime-freeze.json'
freeze=json.loads(freeze_path.read_text())
for name,digest in freeze['files_sha256'].items():assert sha((ROOT/name).read_bytes())==digest,name
proof={'schema':'starfrontier-reference-bank-source-publication-v1','status':'verified','completed_utc':dt.datetime.now(dt.timezone.utc).isoformat(),'checkpoint':manifest['checkpoint'],'artifact_commit':COMMIT,'source_commit':manifest['source_commit'],'files':records,'actual_complete_HTTPS_downloads':len(records),'all_manifest_payloads_downloaded':True,'manifest_payload_count':5,'required_source_archives_downloaded':2,'runtime_inputs_verified':483,'runtime_freeze_sha256':sha(freeze_path.read_bytes()),'all_current_runtime_inputs_match_frozen_source':True,'new_APK_produced':False,'new_kernels_connected_to_Main':False,'physical_device_tested':False,'full_original_port_complete':False,'scope':'Seven actual complete immutable HTTPS downloads: sealed manifest, all five checkpoint payloads, and the required complete0.28 base source ZIP. Both source archive comments and CRC pass; all local payload SHA/lengths and483 frozen source inputs pass. This source foundation is not a new playable release or a flown long-range route.'}
target=ROOT/'validation/reference-bank-publication-2026-11-17'
target.mkdir(exist_ok=False)
(target/'verification.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'status':'verified','actual_complete_HTTPS_downloads':7,'required_source_archives_downloaded':2,'runtime_inputs':483}))
