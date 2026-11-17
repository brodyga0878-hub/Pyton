#!/usr/bin/env python3
"""Build a pinned Git-only SOURCE UPDATE over the exact complete0.28 source ZIP.

No APK is built or published. The base archive must be retained: extracting only
the update is intentionally not a complete project. Every current core/root
file, all current textual proof files and all492 runtime inputs are checked
against the merged base+update. Existing base source files are never removed.
"""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tempfile
import zipfile

BASE_NAME = 'StarFrontier-0.28.0-native-station-source.zip'
BASE_RELATIVE = 'deliverables/0.28.0-native-station-alpha1/' + BASE_NAME
BASE_SHA = '830e7219879f694a24e41f579417986f936902f6592926ff8e84dc99217b6c2d'
BASE_BYTES = 33543341
BASE_COMMIT = 'de8eb18a687d007781321436910187dff3785775'
BASE_ACTUAL_FILES = 1660
BASE_ZIP_ENTRIES = 1829
PREFIX = 'StarFrontier-0.28.0-source/'
PREVIOUS_V = 'validation/reference-bank-2026-11-17/'
CURRENT_V = 'validation/player-dispatch-2026-11-17/'
PROOF_PREFIXES = (PREVIOUS_V, CURRENT_V)
PREVIOUS_FREEZE = PREVIOUS_V + 'runtime-freeze.json'
FREEZE = CURRENT_V + 'runtime-freeze.json'
BASE_FREEZE = 'validation/native-station-2026-11-16/runtime-freeze.json'
UPDATE_NAME = 'StarFrontier-player-dispatch-core-update.zip'
UPDATE_RELATIVE = 'deliverables/player-dispatch-core-2026-11-17/' + UPDATE_NAME
MANIFEST = 'SOURCE_UPDATE_MANIFEST.json'
LIMIT_BYTES = 33554432
CORE_ROOTS = frozenset({'assets','data','scripts','scenes','tests','tools','docs','recovered-history'})
PRIVATE_COMPONENTS = frozenset({'.git','.godot','__pycache__','node_modules',
    'private','runner-state','runner_state','state','xdg','user_data','app_userdata',
    '.cache','.config','.local','.codex','.aws'})
TEXT_PROOF_SUFFIXES = frozenset({'.json','.log','.txt','.md','.py','.s','.asm','.ld',
    '.c','.h','.sh','.gd','.uid','.cfg','.csv','.ini','.tsv','.toml','.yaml','.yml'})
SECRET_SUFFIXES = frozenset({'.key','.pem','.keystore','.jks','.p12','.pfx'})
COMPILED_SUFFIXES = frozenset({'.apk','.exe','.dll','.so','.o','.a','.pck',
    '.gdc','.jar','.class','.pyc','.keystore','.jks'})
UNCHANGED_METADATA = ('scripts/main.gd','scripts/build_info.gd','export_presets.cfg')


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def safe(name):
    require(isinstance(name,str) and bool(name), 'Empty/non-string source path')
    path = PurePosixPath(name)
    require(not path.is_absolute() and '..' not in path.parts and '.' not in path.parts
        and path.as_posix()==name and '\\' not in name
        and all(ord(c)>=32 for c in name), 'Unsafe source path: '+repr(name))
    return path


def is_core(name):
    return '/' not in name or name.split('/',1)[0] in CORE_ROOTS


def private(name):
    return bool(PRIVATE_COMPONENTS.intersection(safe(name).parts))


def git(repo, *arguments, input=None):
    return subprocess.check_output(['git','--literal-pathspecs',*arguments], cwd=repo, input=input)


def tree(repo, commit):
    result = {}
    for row in git(repo,'ls-tree','-r','-z','--full-tree',commit).split(b'\0'):
        if not row:
            continue
        header, raw_name = row.split(b'\t',1)
        mode, kind, oid = header.split()
        name = raw_name.decode('utf-8'); safe(name)
        require(kind==b'blob' and mode in (b'100644',b'100755'),
            'Refuse symbolic link/submodule/non-regular committed file: '+name)
        require(name not in result,'Duplicate Git source path: '+name)
        result[name] = oid.decode('ascii')
    return result


def blobs(repo, commit, names):
    ordered = sorted(names)
    raw = git(repo,'cat-file','--batch',input=''.join(commit+':'+name+'\n' for name in ordered).encode())
    result = {}; offset = 0
    for name in ordered:
        end = raw.index(b'\n',offset)
        header = raw[offset:end].split(); offset = end+1
        require(len(header)==3 and header[1]==b'blob','Missing committed source blob: '+name)
        size = int(header[2]); result[name] = raw[offset:offset+size]
        require(len(result[name])==size and raw[offset+size:offset+size+1]==b'\n',
            'Truncated committed source blob: '+name)
        offset += size+1
    require(offset==len(raw),'Trailing bytes in committed blob stream')
    return result


def baseline(path):
    raw = path.read_bytes()
    require(len(raw)==BASE_BYTES and sha(raw)==BASE_SHA,'The required full0.28 base ZIP differs')
    files = {}
    with zipfile.ZipFile(path) as archive:
        require(archive.testzip() is None,'Base source ZIP CRC failed')
        require(archive.comment.decode('ascii')==BASE_COMMIT,'Base ZIP source commit comment differs')
        require(len(archive.infolist())==BASE_ZIP_ENTRIES,'Base ZIP entry count differs')
        seen = set()
        for info in archive.infolist():
            require(info.filename not in seen,'Duplicate base ZIP entry')
            seen.add(info.filename)
            require(info.filename.startswith(PREFIX),'Base source entry outside required project prefix')
            if info.is_dir():
                continue
            name = info.filename[len(PREFIX):]; safe(name)
            require(name not in files,'Duplicate base source file')
            files[name] = archive.read(info)
    require(len(files)==BASE_ACTUAL_FILES,'Base actual-file inventory differs')
    require(BASE_FREEZE in files,'Base source ZIP lacks its475-input freeze')
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-commit',required=True)
    parser.add_argument('--repo',type=Path,default=Path('/workspace/Pyton'))
    parser.add_argument('--base',type=Path)
    parser.add_argument('--policy',type=Path,default=Path('/workspace/recovery/player-dispatch-update-policy.json'))
    args = parser.parse_args(); repo = args.repo.resolve(); commit = args.source_commit
    require(re.fullmatch(r'[0-9a-f]{40}',commit) is not None,'Provide the full40-character immutable source commit')
    require(git(repo,'cat-file','-t',commit).strip()==b'commit','Source object is not a Git commit')
    require(git(repo,'rev-parse',commit).decode().strip()==commit,'Source commit did not resolve exactly')
    target = repo / UPDATE_RELATIVE
    require(not target.exists(),'Refusing to overwrite an existing source-update ZIP: '+str(target))
    base_path = args.base.resolve() if args.base else repo / BASE_RELATIVE
    base = baseline(base_path)
    current_tree = tree(repo,commit)
    require(set(base)<=set(current_tree),'A base source path was deleted from the source commit; deletion updates are unsupported')
    core = {name for name in current_tree if is_core(name)}
    require(bool(core),'No current core source files')
    proof_files = set(); omitted_proofs = {}
    for name in current_tree:
        if not name.startswith(PROOF_PREFIXES):
            continue
        if private(name):
            omitted_proofs[name] = 'private runner state or cache'
        elif PurePosixPath(name).suffix.lower() not in TEXT_PROOF_SUFFIXES:
            omitted_proofs[name] = 'compiled binary or separately delivered nontext media'
        else:
            proof_files.add(name)
    require(FREEZE in proof_files,'The committed492-input runtime freeze is required')
    # The update is cumulative over0.28. All three previous native banks and
    # all four new ones must replay without the earlier small update archive.
    required_native_inputs = {
        PREVIOUS_V + 'native-proof/instruction-proof.json',
        PREVIOUS_V + 'native-proof/reference-bank-observed-kernel.s',
        PREVIOUS_V + 'angular-native-proof/instruction-proof.json',
        PREVIOUS_V + 'angular-native-proof/source-procedures.s',
        PREVIOUS_V + 'clock-native-proof/clock-source32.S',
        PREVIOUS_V + 'clock-native-proof/clock-observed.S',
        PREVIOUS_V + 'clock-native-proof/clock-observed.ld',
        PREVIOUS_V + 'clock-native-proof/dos-clock-admission.txt',
        PREVIOUS_V + 'clock-native-proof/jjffe-clock-admission-reference.asm',
        CURRENT_V + 'factory-native-proof/instruction-proof.json',
        CURRENT_V + 'factory-native-proof/source-procedures.s',
        CURRENT_V + 'factory-native-proof/factory-native.s',
        CURRENT_V + 'cadence-native-proof/instruction-proof.json',
        CURRENT_V + 'cadence-native-proof/source-procedures.asm',
        CURRENT_V + 'cadence-native-proof/dos-F149.txt',
        CURRENT_V + 'cadence-native-proof/dos-F144.txt',
        CURRENT_V + 'cadence-native-proof/cadence-native.s',
        CURRENT_V + 'player-native-proof/instruction-proof.json',
        CURRENT_V + 'player-native-proof/source-procedures.s',
        CURRENT_V + 'player-native-proof/player-dispatch-native.s',
        CURRENT_V + 'player-native-proof/player-frame-chain.json',
        CURRENT_V + 'frame-native-proof/instruction-proof.json',
        CURRENT_V + 'frame-native-proof/source-procedures.asm',
        CURRENT_V + 'frame-native-proof/frame-dispatch-observed-kernel.s',
        PREVIOUS_FREEZE,
    }
    require(required_native_inputs <= proof_files,
            'A required native replay source or linker input would be omitted')
    read_names = core | proof_files | set(base)
    committed = blobs(repo,commit,read_names)
    for name in core:
        path = safe(name)
        require(not private(name) and path.suffix.lower() not in SECRET_SUFFIXES
            and path.name not in {'.env','.env.local','.env.production'},
            'Private/cache/signing file would enter source update: '+name)
        require(path.suffix.lower() not in COMPILED_SUFFIXES
            and not committed[name].startswith(b'\x7fELF'),
            'Compiled program/cache is not a source core file: '+name)
    for name in proof_files:
        require(b'\0' not in committed[name],'NUL-containing proof file is not textual: '+name)
        committed[name].decode('utf-8')
        require(not committed[name].startswith((b'\x7fELF',b'MZ',b'PK\x03\x04')),
            'Binary disguised as textual proof: '+name)
    # A core/root file enters the update exactly when its committed bytes differ
    # from the base. All current text proofs are included, independently of their
    # earlier existence. No working-tree source bytes are used.
    changed_core = {name for name in core if base.get(name)!=committed[name]}
    selected = changed_core | proof_files
    require(bool(selected),'Source update would be empty')
    for name in base:
        require(committed[name]==base[name] or name in selected,
            'Changed historical base source/proof is not in this permitted update: '+name)
    freeze = json.loads(committed[FREEZE]); old_freeze = json.loads(base[BASE_FREEZE])
    prior_backend_freeze = json.loads(committed[PREVIOUS_FREEZE])
    runtime = freeze.get('files_sha256'); previous = old_freeze.get('files_sha256')
    require(isinstance(runtime,dict) and len(runtime)==492,'New committed runtime freeze must contain exactly492 inputs')
    require(isinstance(previous,dict) and len(previous)==475,'Required base freeze must contain exactly475 inputs')
    require(set(previous)<=set(runtime) and all(runtime[name]==digest for name,digest in previous.items()),
        'An existing0.28 runtime input changed or disappeared')
    prior_backend = prior_backend_freeze.get('files_sha256')
    require(isinstance(prior_backend,dict) and len(prior_backend)==483,
            'The previous backend freeze must retain exactly483 inputs')
    require(set(prior_backend)<=set(runtime),'A previous backend source input disappeared')
    changed_backend = sorted(name for name,digest in prior_backend.items()
                             if runtime[name]!=digest)
    added_backend = sorted(set(runtime)-set(prior_backend))
    require(changed_backend==['scripts/source_flight_state.gd'] and len(added_backend)==9,
            'Expected one existing backend integration change and nine added source inputs')
    require(sum(runtime[name]==digest for name,digest in prior_backend.items())==482,
            'Exactly482 prior backend inputs must remain unchanged')
    require(set(runtime)<=core,'Every runtime input must be included in a current source core/root')
    for name,digest in runtime.items():
        safe(name)
        require(isinstance(digest,str) and re.fullmatch(r'[0-9a-f]{64}',digest)
            and sha(committed[name])==digest,'Committed runtime input differs from freeze: '+name)
    for name in UNCHANGED_METADATA:
        require(name in previous and name in base and committed[name]==base[name],
            'Main/BuildInfo/export must stay exact published0.28 bytes: '+name)
    new_runtime = sorted(set(runtime)-set(previous))
    require(len(new_runtime)==17 and set(new_runtime)<=selected,
            'The cumulative update must deliver all17 added runtime inputs since0.28')
    require('data/ffe_object_factory.json' in core and 'data/ffe_object_factory.json' in added_backend,
            'The independently checked object-factory resource must be included as a new runtime input')
    factory = json.loads(committed['data/ffe_object_factory.json'])
    require(factory.get('schema')=='starfrontier-source-object-factory-resources-v1'
            and factory.get('source_executable_sha256')=='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
            and factory.get('model_count')==149 and isinstance(factory.get('models'),dict)
            and set(factory['models'])=={str(i) for i in range(149)},
            'The cumulative source must retain the pinned complete149-model factory resource')
    native_generators = [
        'tools/rebuild_source_reference_bank_native.py',
        'tools/rebuild_source_angular_native.py',
        'tools/rebuild_source_clock_pipeline_native.py',
        'tools/rebuild_source_object_factory_native.py',
        'tools/rebuild_source_object_cadence_native.py',
        'tools/rebuild_source_player_dispatch_native.py',
        'tools/rebuild_source_frame_dispatch_native.py',
    ]
    require(set(native_generators)<=core,
            'At least one of the seven portable native generators is missing')
    supplemental_generators = ['tools/rebuild_source_player_frame_chain_native.py']
    require(set(supplemental_generators)<=core,
            'The supplemental player/frame native composition generator is missing')
    supplemental_path = CURRENT_V + 'player-native-proof/player-frame-chain.json'
    require(sha(committed[supplemental_path])=='4b14fb995c23a3ffe8de2f3f324e9a14b052a7de2a3da9092ecfec2edb48f69e',
            'The separately pinned player/frame native composition proof changed')
    supplemental = json.loads(committed[supplemental_path])
    require(supplemental.get('schema')=='starfrontier-native-player-frame-chain-v1'
            and supplemental.get('case_count')==2
            and isinstance(supplemental.get('cases'),list) and len(supplemental['cases'])==2
            and isinstance(supplemental.get('source_pins'),dict) and bool(supplemental['source_pins'])
            and supplemental.get('supplemental_controls_added_to_main_case_totals') is False
            and supplemental.get('private_original_inputs_needed') is False
            and supplemental.get('expected_arithmetic_calculated_in_python') is False,
            'The two supplemental native controls must remain separate from the seven main banks')
    for name,digest in supplemental.get('source_pins',{}).items():
        safe(name)
        require(name in committed and sha(committed[name])==digest,
                'A supplemental native composition source dependency is absent or changed: '+name)
    require(supplemental.get('source_kernel_sha256')=={
                'player':sha(committed[CURRENT_V+'player-native-proof/player-dispatch-native.s']),
                'reference_bank':sha(committed[PREVIOUS_V+'native-proof/reference-bank-observed-kernel.s'])},
            'Supplemental composition kernel pins differ from the retained whole native kernels')
    # Validate the composition before writing: every base file is retained and
    # every current core/root/proof path resolves to the exact committed blob.
    layered = dict(base)
    layered.update({name:committed[name] for name in selected})
    require(set(base)<=set(layered),'Layered source lost a base file')
    require(all(layered.get(name)==committed[name] for name in core|proof_files),
        'Base+update does not reproduce the entire current core/root/proof set')
    require(all(sha(layered[name])==digest for name,digest in runtime.items()),'Layered runtime differs from frozen source')
    created = dt.datetime.fromtimestamp(int(git(repo,'show','-s','--format=%ct',commit)),dt.timezone.utc)
    payloads = {name:{'bytes':len(committed[name]),'sha256':sha(committed[name])} for name in sorted(selected)}
    manifest = {
      'schema':'starfrontier-player-dispatch-source-update-v1',
      'checkpoint':'player-dispatch-core-2026-11-17','delivery_kind':'source-update-only',
      'profile':'dos-firstenc-cumulative-player-dispatch-over-published0.28','source_commit':commit,
      'source_commit_utc':created.isoformat(),'project_prefix':PREFIX,
      'required_archive_count':2,
      'cumulative_update':True,'previous_update_archive_required':False,
      'previous_source_checkpoint':'reference-bank-core-2026-11-17',
      'required_archives':[
        {'role':'full_base_source','file':BASE_NAME,'repository_path':BASE_RELATIVE,
         'bytes':BASE_BYTES,'sha256':BASE_SHA,'source_commit':BASE_COMMIT,
         'actual_files':BASE_ACTUAL_FILES,'zip_entries':BASE_ZIP_ENTRIES},
        {'role':'source_update','file':UPDATE_NAME,'repository_path':UPDATE_RELATIVE,
         'source_commit':commit,'own_archive_sha256':'Recorded externally in player-dispatch-update-policy.json; a ZIP cannot contain its own SHA256'}],
      'usage':'Download both archives. Extract the complete0.28 base, then extract this update into the SAME parent directory, allowing the shared StarFrontier-0.28.0-source/ paths to replace matching source files. The top-level manifest is outside the Godot project. The update alone is incomplete.',
      'base_archive_sha256':BASE_SHA,'base_source_commit':BASE_COMMIT,
      'project_payload_count':len(payloads),'project_payloads':payloads,
      'changed_existing_core_paths':sorted(name for name in changed_core if name in base),
      'added_core_paths':sorted(changed_core-set(base)),
      'current_text_proof_paths':sorted(proof_files),
      'included_text_proof_prefixes':list(PROOF_PREFIXES),
      'native_generator_groups':native_generators,
      'supplemental_native_composition_generators':supplemental_generators,
      'supplemental_native_compositions_separate':2,
      'supplemental_controls_added_to_main_native_totals':False,
      'supplemental_native_composition_proof':supplemental_path,
      'supplemental_native_composition_proof_sha256':sha(committed[supplemental_path]),
      'required_native_replay_inputs':sorted(required_native_inputs),
      'factory_resource_path':'data/ffe_object_factory.json',
      'factory_resource_models':149,
      'factory_resource_sha256':sha(committed['data/ffe_object_factory.json']),
      'omitted_current_private_or_binary_proof_paths':dict(sorted(omitted_proofs.items())),
      'current_core_and_root_file_count':len(core),'all_current_core_and_root_files_exact_after_overlay':True,
      'retained_base_source_file_count':len(base),'all_base_files_retained':True,'deleted_source_paths':[],
      'merged_actual_project_file_count':len(layered),
      'runtime_input_count':len(runtime),'unchanged_published0_28_runtime_inputs':len(previous),
      'previous_backend_runtime_inputs':len(prior_backend),
      'unchanged_previous_backend_runtime_inputs':482,
      'changed_previous_backend_runtime_inputs':changed_backend,
      'added_runtime_inputs_since_previous_backend':added_backend,
      'previous_backend_freeze_path':PREVIOUS_FREEZE,
      'previous_backend_freeze_sha256':sha(committed[PREVIOUS_FREEZE]),
      'added_runtime_inputs':new_runtime,'runtime_files_sha256':dict(sorted(runtime.items())),
      'runtime_freeze_path':FREEZE,'runtime_freeze_sha256':sha(committed[FREEZE]),
      'unchanged_game_version':'0.28.0-native-station-alpha1','unchanged_android_code':53,
      'Main_BuildInfo_export_unchanged':True,'new_APK_produced':False,
      'new_playable_release_claimed':False,'full_original_port_complete':False,
      'physical_device_tested':False,'archive_builder_sha256':sha(Path(__file__).read_bytes()),
      'scope':'Immutable cumulative player-dispatch source foundation over the exact complete0.28 source archive; no earlier small update ZIP is needed. All current core/assets/data/tests/tools/docs/history and textual proof files for both backend stages are reproduced. All492 current runtime inputs are checked: all475 original game inputs unchanged;482 of483 previous backend inputs unchanged, only SourceFlightState integrated, and9 added. The complete149-model source factory resource, all seven primary portable native-generator groups, and the separate two-control player/frame composition generator/proof dependencies are retained. The two supplemental controls are not added to the primary native-bank totals. Raw factory, cadence, bounded player-control and F570 caller work with explicit callback observations does not establish a newly integrated playable build, full collision/ephemeris/event/AI bank, long-range route or full clone.'}
    manifest_raw=(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode('utf-8')
    target.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='player-dispatch-update-',dir=str(target.parent)) as temporary:
        candidate=Path(temporary)/UPDATE_NAME
        subprocess.run(['git','--literal-pathspecs','archive','--format=zip','-9',
            '--prefix='+PREFIX,'-o',str(candidate),commit,'--',*sorted(selected)],cwd=repo,check=True)
        with zipfile.ZipFile(candidate,'a',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
            require(archive.comment.decode('ascii')==commit,'Git update archive has wrong source comment')
            require(MANIFEST not in archive.namelist(),'Reserved top-level update manifest collision')
            info=zipfile.ZipInfo(MANIFEST,date_time=created.timetuple()[:6])
            info.create_system=3;info.external_attr=0o100644<<16;info.compress_type=zipfile.ZIP_DEFLATED
            archive.writestr(info,manifest_raw,compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
        actual_payloads={}
        with zipfile.ZipFile(candidate) as archive:
            require(archive.testzip() is None,'Update ZIP CRC failed')
            require(archive.comment.decode('ascii')==commit,'Update ZIP Git comment changed')
            require(len(set(archive.namelist()))==len(archive.infolist()),'Duplicate update ZIP entries')
            require(archive.read(MANIFEST)==manifest_raw,'Update manifest bytes changed')
            for info in archive.infolist():
                if info.is_dir() or info.filename==MANIFEST:
                    continue
                require(info.filename.startswith(PREFIX),'Update payload outside the required project prefix')
                name=info.filename[len(PREFIX):];safe(name)
                require(name in selected,'Unexpected source update file: '+name)
                raw=archive.read(info)
                require(raw==committed[name],'Archived payload is not the exact committed Git blob: '+name)
                actual_payloads[name]=raw
            require(set(actual_payloads)==selected,'At least one selected committed payload is missing')
            layered_archive=dict(base);layered_archive.update(actual_payloads)
            require(all(layered_archive.get(name)==committed[name] for name in core|proof_files),
                'Actual archived base+update is not the entire exact current source set')
            require(all(sha(layered_archive[name])==digest for name,digest in runtime.items()),
                'Actual archived base+update has a frozen runtime mismatch')
            archive_entries=len(archive.infolist())
        archive_raw=candidate.read_bytes()
        require(len(archive_raw)<LIMIT_BYTES,'Source update must remain strictly smaller than32MiB')
        require(not target.exists(),'Source update appeared while preparing; refuse overwrite')
        # Exclusive creation keeps a pre-existing immutable artifact intact.
        with target.open('xb') as stream:
            stream.write(archive_raw)
    policy={
      'schema':'starfrontier-player-dispatch-source-update-policy-v1','status':'verified',
      'source_commit':commit,'source_commit_utc':created.isoformat(),
      'base_archive_path':str(base_path),'base_archive_repository_path':BASE_RELATIVE,
      'base_archive_bytes':BASE_BYTES,'base_archive_sha256':BASE_SHA,'base_source_commit':BASE_COMMIT,
      'update_archive_path':str(target),'update_archive_repository_path':UPDATE_RELATIVE,
      'update_archive_bytes':len(archive_raw),'update_archive_sha256':sha(archive_raw),
      'update_archive_zip_entries':archive_entries,'update_actual_project_payload_files':len(selected),
      'top_level_metadata_files':1,'manifest_file':MANIFEST,'manifest_sha256':sha(manifest_raw),
      'update_ZIP_CRC_verified':True,'base_ZIP_CRC_verified':True,'source_commit_comment_verified':True,
      'strictly_below32MiB':True,'requires_exact_base_archive':True,'required_archive_count':2,
      'cumulative_update':True,'previous_update_archive_required':False,
      'previous_source_checkpoint':'reference-bank-core-2026-11-17',
      'all_current_core_and_root_files_exact_after_overlay':True,'all_current_text_proofs_included':True,
      'all_base_source_paths_retained':True,'deleted_paths':[],
      'current_core_and_root_file_count':len(core),'retained_base_source_file_count':len(base),
      'merged_actual_project_file_count':len(layered),'runtime_inputs_verified':len(runtime),
      'unchanged_published0_28_runtime_inputs':len(previous),'new_runtime_inputs':new_runtime,
      'previous_backend_runtime_inputs':len(prior_backend),
      'unchanged_previous_backend_runtime_inputs':482,
      'changed_previous_backend_runtime_inputs':changed_backend,
      'added_runtime_inputs_since_previous_backend':added_backend,
      'previous_backend_freeze_path':PREVIOUS_FREEZE,
      'previous_backend_freeze_sha256':sha(committed[PREVIOUS_FREEZE]),
      'included_text_proof_prefixes':list(PROOF_PREFIXES),
      'native_generator_groups':native_generators,
      'supplemental_native_composition_generators':supplemental_generators,
      'supplemental_native_compositions_separate':2,
      'supplemental_controls_added_to_main_native_totals':False,
      'supplemental_native_composition_proof':supplemental_path,
      'supplemental_native_composition_proof_sha256':sha(committed[supplemental_path]),
      'required_native_replay_inputs':sorted(required_native_inputs),
      'factory_resource_path':'data/ffe_object_factory.json','factory_resource_models':149,
      'factory_resource_sha256':sha(committed['data/ffe_object_factory.json']),
      'runtime_freeze_sha256':sha(committed[FREEZE]),'payloads':payloads,
      'omitted_current_private_or_binary_proof_paths':dict(sorted(omitted_proofs.items())),
      'new_APK_produced':False,'new_playable_release_claimed':False,'physical_device_tested':False,
      'archive_builder_sha256':sha(Path(__file__).read_bytes()),
      'scope':manifest['scope']}
    args.policy.parent.mkdir(parents=True,exist_ok=True)
    args.policy.write_text(json.dumps(policy,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({key:policy[key] for key in ('status','source_commit','update_archive_path',
        'update_archive_bytes','update_archive_sha256','update_actual_project_payload_files',
        'merged_actual_project_file_count','runtime_inputs_verified','unchanged_published0_28_runtime_inputs',
        'required_archive_count','new_APK_produced')},indent=2))


if __name__=='__main__':
    main()
