#!/usr/bin/env python3
"""Build an immutable cumulative mission-expressions-core-0.30.0 SOURCE UPDATE over exact0.28.

Read committed Git blobs only. Preserve every base path and all563 previous runtime paths
(only the authorized version name/code lines may change); derive the current inventory from committed runtime roots.
No APK build/publish step, private runner files or compiled native programs.
"""
from __future__ import annotations
import argparse,datetime as dt,hashlib,json,re,stat,subprocess,tempfile,zipfile
from pathlib import Path,PurePosixPath
BASE_NAME='StarFrontier-0.28.0-native-station-source.zip'
BASE_RELATIVE='deliverables/0.28.0-native-station-alpha1/'+BASE_NAME
BASE_SHA='830e7219879f694a24e41f579417986f936902f6592926ff8e84dc99217b6c2d'
BASE_BYTES=33543341
BASE_COMMIT='de8eb18a687d007781321436910187dff3785775'
BASE_ARTIFACT_COMMIT='f6d802e5f34f735eef91fdc2670bc8850443511a'
BASE_ACTUAL_FILES=1660;BASE_ZIP_ENTRIES=1829
PREFIX='StarFrontier-0.28.0-source/'
REFERENCE_V='validation/reference-bank-2026-11-17/'
DISPATCH_V='validation/player-dispatch-2026-11-17/'
CYCLE_V='validation/player-cycle-2026-11-17/'
CLASSIFIER_V='validation/contact-classifier-2026-11-17/'
COLLISION_V='validation/collision-programs-2026-11-17/'
TERRAIN_V='validation/terrain-height-2026-11-17/'
DAMAGE_V='validation/damage-core-2026-11-17/'
EQUIPMENT_V='validation/equipment-effects-2026-11-18/'
PREVIOUS_V='validation/events-messages-2026-11-18/'
CURRENT_V='validation/mission-expressions-2026-11-18/'
PROOF_PREFIXES=(REFERENCE_V,DISPATCH_V,CYCLE_V,CLASSIFIER_V,COLLISION_V,TERRAIN_V,DAMAGE_V,EQUIPMENT_V,PREVIOUS_V,CURRENT_V)
PREVIOUS_FREEZE=PREVIOUS_V+'runtime-freeze.json'
FREEZE=CURRENT_V+'runtime-freeze.json'
BASE_FREEZE='validation/native-station-2026-11-16/runtime-freeze.json'
SUMMARY=CURRENT_V+'final-regression/summary.json'
PREVIOUS_SUMMARY=PREVIOUS_V+'final-regression/summary.json'
UPDATE_NAME='StarFrontier-0.30.0-mission-expressions-source-update.zip'
UPDATE_RELATIVE='deliverables/mission-expressions-core-0.30.0-2026-11-18/'+UPDATE_NAME
MANIFEST='SOURCE_UPDATE_MANIFEST.json';LIMIT_BYTES=33554432
CORE_ROOTS=frozenset({'assets','data','scripts','scenes','tests','tools','docs','recovered-history'})
RUNTIME_ROOTS=frozenset({'assets','data','scripts','scenes'})
RUNTIME_ROOT_FILES=frozenset({'export_presets.cfg','icon.svg','icon.svg.import','project.godot'})
PRIVATE_COMPONENTS=frozenset({'.git','.godot','__pycache__','node_modules','private','runner-state','runner_state','state','xdg','user_data','app_userdata','.cache','.config','.local','.codex','.aws'})
TEXT_PROOF_SUFFIXES=frozenset({'.json','.log','.txt','.md','.py','.s','.asm','.ld','.c','.h','.sh','.gd','.uid','.cfg','.csv','.ini','.tsv','.toml','.yaml','.yml'})
SECRET_SUFFIXES=frozenset({'.key','.pem','.keystore','.jks','.p12','.pfx'})
COMPILED_SUFFIXES=frozenset({'.apk','.exe','.dll','.so','.o','.a','.pck','.gdc','.jar','.class','.pyc','.keystore','.jks'})
UNCHANGED_METADATA=('scripts/main.gd',)
VERSION_METADATA=frozenset({'scripts/build_info.gd','export_presets.cfg'})
BASE_VERSION='0.28.0-native-station-alpha1';BASE_CODE=53
PREVIOUS_VERSION='0.29.0-events-alpha1';PREVIOUS_CODE=54
SOURCE_VERSION='0.30.0-missions-alpha1';SOURCE_CODE=55
# The supplemental native composition remains separate from primary-bank totals.
NATIVE=[
 {'name':'reference_bank','generator':'tools/rebuild_source_reference_bank_native.py','fixture':'tests/fixtures/source_reference_bank_native.json','kind':'reference_bank'},
 {'name':'angular','generator':'tools/rebuild_source_angular_native.py','fixture':'tests/fixtures/source_angular_native.json','kind':'proof_asm','proof_dir':REFERENCE_V+'angular-native-proof'},
 {'name':'clock','generator':'tools/rebuild_source_clock_pipeline_native.py','fixture':'tests/fixtures/source_clock_pipeline_native.json','kind':'clock','proof_dir':REFERENCE_V+'clock-native-proof'},
 {'name':'object_factory','generator':'tools/rebuild_source_object_factory_native.py','fixture':'tests/fixtures/source_object_factory_native.json','kind':'asm'},
 {'name':'object_cadence','generator':'tools/rebuild_source_object_cadence_native.py','fixture':'tests/fixtures/source_object_cadence_native.json','kind':'source'},
 {'name':'player_dispatch','generator':'tools/rebuild_source_player_dispatch_native.py','fixture':'tests/fixtures/source_player_dispatch_native.json','kind':'proof_asm','proof_dir':DISPATCH_V+'player-native-proof'},
 {'name':'frame_dispatch','generator':'tools/rebuild_source_frame_dispatch_native.py','fixture':'tests/fixtures/source_frame_dispatch_native.json','kind':'source'},
 {'name':'player_frame_chain','generator':'tools/rebuild_source_player_frame_chain_native.py','fixture':DISPATCH_V+'player-native-proof/player-frame-chain.json','kind':'supplemental','supplemental':True},
 *[{'name':'player_'+n,'generator':'tools/rebuild_source_player_'+n+'_native.py','fixture':'tests/fixtures/source_player_'+n+'_native.json','kind':'proof_asm','proof_dir':CYCLE_V+n+'-native-proof'}for n in ['mode','input','motion','phase']],
 {'name':'player_cycle','generator':'tools/rebuild_source_player_cycle_native.py','fixture':'tests/fixtures/source_player_cycle_native.json','kind':'proof_asm','proof_dir':CYCLE_V+'cycle-native-proof','supplemental':True},
 {'name':'contact_classifier','generator':'tools/rebuild_source_contact_classifier_native.py','fixture':'tests/fixtures/source_contact_classifier_native.json','kind':'proof_asm','proof_dir':CLASSIFIER_V+'native-proof'},
 {'name':'pair_response','generator':'tools/rebuild_source_pair_response_native.py','fixture':'tests/fixtures/source_pair_response_native.json','kind':'proof_asm','proof_dir':CLASSIFIER_V+'pair-native-proof'},
 {'name':'contact_scan','generator':'tools/rebuild_source_contact_scan_native.py','fixture':'tests/fixtures/source_contact_scan_native.json','kind':'proof_asm','proof_dir':CLASSIFIER_V+'scan-native-proof','supplemental':True},
 *[{'name':'collision_'+n,'generator':'tools/rebuild_source_collision_'+n+'_native.py','fixture':'tests/fixtures/source_collision_'+n+'_native.json','kind':'proof_asm','proof_dir':COLLISION_V+n+'-native-proof'}for n in ['planes','transform','program','geometry']],
 {'name':'collision_contact','generator':'tools/rebuild_source_collision_contact_native.py','fixture':'tests/fixtures/source_collision_contact_native.json','kind':'proof_asm','proof_dir':COLLISION_V+'contact-native-proof','supplemental':True},
 {'name':'collision_terrain','generator':'tools/rebuild_source_collision_terrain_native.py','fixture':'tests/fixtures/source_collision_terrain_native.json','kind':'proof_asm','proof_dir':TERRAIN_V+'native-proof'},
 {'name':'collision_surface','generator':'tools/rebuild_source_collision_surface_native.py','fixture':'tests/fixtures/source_collision_surface_native.json','kind':'proof_asm','proof_dir':TERRAIN_V+'surface-native-proof','supplemental':True},
 {'name':'damage','generator':'tools/rebuild_source_damage_native.py','fixture':'tests/fixtures/source_damage_native.json','kind':'proof_asm','proof_dir':DAMAGE_V+'native-proof'},
 {'name':'object_slots','generator':'tools/rebuild_source_object_slots_native.py','fixture':'tests/fixtures/source_object_slots_native.json','kind':'proof_asm','proof_dir':DAMAGE_V+'slots-native-proof'},
 {'name':'damage_contact','generator':'tools/rebuild_source_damage_contact_native.py','fixture':'tests/fixtures/source_damage_contact_native.json','kind':'proof_asm','proof_dir':DAMAGE_V+'contact-native-proof','supplemental':True},
 {'name':'equipment','generator':'tools/rebuild_source_equipment_native.py','fixture':'tests/fixtures/source_equipment_native.json','kind':'proof_asm','proof_dir':EQUIPMENT_V+'equipment-native-proof'},
 {'name':'effect_factory','generator':'tools/rebuild_source_effect_factory_native.py','fixture':'tests/fixtures/source_effect_factory_native.json','kind':'proof_asm','proof_dir':EQUIPMENT_V+'factory-native-proof'},
 {'name':'destruction','generator':'tools/rebuild_source_destruction_native.py','fixture':'tests/fixtures/source_destruction_native.json','kind':'proof_asm','proof_dir':EQUIPMENT_V+'destruction-native-proof'},
 {'name':'damage_effects','generator':'tools/rebuild_source_damage_effects_native.py','fixture':'tests/fixtures/source_damage_effects_native.json','kind':'proof_asm','proof_dir':EQUIPMENT_V+'effects-native-proof','supplemental':True},
 {'name':'events','generator':'tools/rebuild_source_events_native.py','fixture':'tests/fixtures/source_events_native.json','kind':'proof_asm','proof_dir':PREVIOUS_V+'events-native-proof'},
 {'name':'messages','generator':'tools/rebuild_source_messages_native.py','fixture':'tests/fixtures/source_messages_native.json','kind':'proof_asm','proof_dir':PREVIOUS_V+'messages-native-proof'},
 {'name':'player_events','generator':'tools/rebuild_source_player_events_native.py','fixture':'tests/fixtures/source_player_events_native.json','kind':'proof_asm','proof_dir':PREVIOUS_V+'player-events-native-proof'},
 {'name':'event_services','generator':'tools/rebuild_source_event_services_native.py','fixture':'tests/fixtures/source_event_services_native.json','kind':'proof_asm','proof_dir':PREVIOUS_V+'services-native-proof','supplemental':True},
 {'name':'mission_expression','generator':'tools/rebuild_source_mission_expression_native.py','fixture':'tests/fixtures/source_mission_expression_native.json','kind':'proof_asm','proof_dir':CURRENT_V+'expression-native-proof'},
 {'name':'mission_guards','generator':'tools/rebuild_source_mission_guards_native.py','fixture':'tests/fixtures/source_mission_guards_native.json','kind':'proof_asm','proof_dir':CURRENT_V+'guards-native-proof'},
]
# Exact byte-span extraction is a resource replay, not a native case bank.
RESOURCE_REPLAYS=[
 {'name':'collision_program_resources','generator':'tools/extract_source_collision_programs.py','resource':'data/ffe_collision_programs.json','capture':COLLISION_V+'resources/original-spans.json','kind':'archived_byte_spans','resource_schema':'starfrontier-original-collision-program-resources-v1','capture_schema':'starfrontier-original-collision-byte-spans-v1','identity_keys':['source_executable_sha256','source_assembly_sha256','source_data_sha256']},
 {'name':'mission_program_resources','generator':'tools/extract_source_mission_programs.py','resource':'data/ffe_mission_programs.json','capture':CURRENT_V+'resources/original-spans.json','kind':'archived_mission_byte_spans','resource_schema':'starfrontier-original-mission-program-resources-v1','capture_schema':'starfrontier-original-mission-byte-spans-v1','identity_keys':['source_executable_sha256','source_assembly_sha256','source_data_sha256','source_mission_assembly_sha256']},
]
ALLOWED_CHANGED_PREVIOUS_RUNTIME=VERSION_METADATA
REQUIRED_NEW_RUNTIME={f'scripts/source_{name}.gd{suffix}'for name in ['mission_programs','mission_expression','mission_guards','mission_services','mission_services_state']for suffix in ['', '.uid']}|{'data/ffe_mission_programs.json'}
REQUIRED_NEW_TESTS={f'tests/test_source_{name}.gd'for name in ['mission_programs','mission_expression','mission_guards','mission_services']}|{'tests/test_build_version.gd'}

def require(value, message):
    if not value:
        raise ValueError(message)



def version_fields(name,version,code):
    require(name in VERSION_METADATA,'Unknown version metadata path')
    return [('const VERSION:=','"'+version+'"'),('const VERSION_CODE:=',str(code))]if name=='scripts/build_info.gd'else[('version/name=','"'+version+'"'),('version/code=',str(code))]


def version_metadata_from_base(name,before,version,code):
    """Reconstruct an exact permitted metadata version, preserving other bytes."""
    old=version_fields(name,BASE_VERSION,BASE_CODE);new=version_fields(name,version,code)
    lines=before.decode('utf-8').splitlines(keepends=True)
    for (prefix,old_value),(_,new_value)in zip(old,new):
        hits=[i for i,line in enumerate(lines)if line.rstrip('\r\n')==prefix+old_value]
        require(len(hits)==1,'Exact base version field missing: '+name)
        i=hits[0];ending=lines[i][len(lines[i].rstrip('\r\n')):];lines[i]=prefix+new_value+ending
    return ''.join(lines).encode('utf-8')


def verify_version_metadata(name,before,after,old_version=BASE_VERSION,old_code=BASE_CODE):
    """Permit exactly the version values; retain every other byte and line."""
    fields=zip(version_fields(name,old_version,old_code),version_fields(name,SOURCE_VERSION,SOURCE_CODE))
    old=before.decode('utf-8').splitlines(keepends=True);new=after.decode('utf-8').splitlines(keepends=True)
    for (prefix,old_value),(_,new_value)in fields:
        old_hits=[i for i,line in enumerate(old)if line.rstrip('\r\n')==prefix+old_value]
        new_hits=[i for i,line in enumerate(new)if line.rstrip('\r\n')==prefix+new_value]
        require(len(old_hits)==len(new_hits)==1,'Version metadata must contain each exact old/new field once: '+name)
        for lines,index in [(old,old_hits[0]),(new,new_hits[0])]:
            line=lines[index];ending=line[len(line.rstrip('\r\n')):];lines[index]=prefix+'<VERSION_VALUE>'+ending
    require(old==new,'A non-version byte/line changed in '+name)


def verify_version_chain(name,base,current,previous_hash,published_hash):
    """Verify both cumulative 0.28→0.30 and previous 0.29→0.30 deltas."""
    require(published_hash==sha(base),'Published metadata hash differs from exact0.28 base: '+name)
    previous=version_metadata_from_base(name,base,PREVIOUS_VERSION,PREVIOUS_CODE)
    require(previous_hash==sha(previous),'Previous0.29 metadata cannot be reconstructed exactly: '+name)
    verify_version_metadata(name,base,current)
    verify_version_metadata(name,previous,current,PREVIOUS_VERSION,PREVIOUS_CODE)


RESOURCE_SOURCE_IDENTITIES={
 'source_executable_sha256':'d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72',
 'source_assembly_sha256':'d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a',
 'source_data_sha256':'34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850',
 'source_mission_assembly_sha256':'6f9732f6f881f038a9780460e287437d4d0b6b4b6df739d8a24e19a80e687a33',
}


def validate_resource_documents(spec,resource_doc,capture_doc):
    require(resource_doc.get('schema')==spec['resource_schema']and capture_doc.get('schema')==spec['capture_schema'],'Resource replay input schema differs: '+spec['name'])
    for key in spec['identity_keys']:
        require(resource_doc.get(key)==capture_doc.get(key)==RESOURCE_SOURCE_IDENTITIES[key],'Resource source identity differs: '+spec['name']+' '+key)


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


def summary_suites(doc):
    require(doc.get('status')=='passed' and doc.get('failures')==0,'Final current regression summary must pass')
    suites=doc.get('suites')
    require(isinstance(suites,list) and bool(suites),'Final regression suite rows are missing')
    names=set();scripts=set();total=0
    for row in suites:
        source=row.get('suite_source',{})
        script=source.get('path') or row.get('test') or row.get('script')
        require(isinstance(script,str),'Final suite script path missing')
        if script.startswith('res://'):script=script[6:]
        safe(script)
        require(script.startswith('tests/') and script.endswith('.gd'),'Final suite script is not a source test')
        require(row.get('status') in ('passed','verified') and row.get('failures')==0 and type(row.get('checks'))is int and row['checks']>0,'A final suite is not passing')
        require(row.get('name') not in names and script not in scripts,'Duplicate suite or script in final summary')
        names.add(row['name']);scripts.add(script);total+=row['checks']
    require(doc.get('checks')==total,'Final suite checks do not sum to summary total')
    return suites,scripts


def supplemental_spec(value):
    """Only a committed, pinned supplemental native source can extend replay."""
    require(isinstance(value,dict)and set(value)=={'name','generator','fixture','kind','proof_dir','supplemental'},'Supplemental native specification shape differs')
    require(isinstance(value['name'],str)and re.fullmatch(r'[a-z][a-z0-9_]*',value['name'])is not None,'Unsafe supplemental native name')
    require(isinstance(value['generator'],str)and re.fullmatch(r'tools/rebuild_source_[a-z0-9_]+_native\.py',value['generator'])is not None,'Unsafe supplemental native generator')
    require(isinstance(value['fixture'],str)and re.fullmatch(r'tests/fixtures/source_[a-z0-9_]+_native\.json',value['fixture'])is not None,'Unsafe supplemental native fixture')
    require(value['kind']=='proof_asm'and value['supplemental']is True,'Additional native proof must be an observed supplemental composition')
    proof=value['proof_dir'];require(isinstance(proof,str)and proof.startswith(CURRENT_V)and not proof.endswith('/'),'Supplemental proof must be inside current checkpoint')
    path=safe(proof);require(not PRIVATE_COMPONENTS.intersection(path.parts),'Private supplemental proof path')
    return dict(value)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source-commit',required=True);p.add_argument('--repo',type=Path,default=Path('/workspace/Pyton'))
    p.add_argument('--base',type=Path);p.add_argument('--output',type=Path)
    p.add_argument('--supplemental-native-spec',action='append',default=[],metavar='COMMITTED_JSON_PATH',help='Optional current-checkpoint JSON source spec for an implemented supplemental composition; repeat for separate specs.')
    p.add_argument('--policy',type=Path,default=Path('/workspace/recovery/mission-expressions-update-policy.json'))
    a=p.parse_args();repo=a.repo.resolve();commit=a.source_commit
    require(re.fullmatch('[0-9a-f]{40}',commit)is not None,'Provide full immutable40-character source commit')
    require(git(repo,'cat-file','-t',commit).strip()==b'commit' and git(repo,'rev-parse',commit).decode().strip()==commit,'Source commit must resolve exactly')
    target=a.output.resolve()if a.output else repo/UPDATE_RELATIVE
    require(not target.exists(),'Refusing to overwrite existing source update')
    base_path=a.base.resolve()if a.base else repo/BASE_RELATIVE;base=baseline(base_path);current=tree(repo,commit)
    require(set(base)<=set(current),'Base path deletion unsupported')
    core={n for n in current if is_core(n)};proofs=set();omitted={}
    for name in current:
        if not name.startswith(PROOF_PREFIXES):continue
        if private(name):omitted[name]='private runner state/cache'
        elif PurePosixPath(name).suffix.lower() not in TEXT_PROOF_SUFFIXES:omitted[name]='compiled binary or nontext media'
        else:proofs.add(name)
    require({FREEZE,PREVIOUS_FREEZE,SUMMARY,PREVIOUS_SUMMARY}<=proofs,'Committed current/previous freeze and final-regression summary are required')
    committed=blobs(repo,commit,core|proofs|set(base))
    for name in core:
        path=safe(name);raw=committed[name]
        require(not private(name) and path.suffix.lower() not in SECRET_SUFFIXES and path.name not in {'.env','.env.local','.env.production'},'Private/cache/signing core file: '+name)
        require(path.suffix.lower() not in COMPILED_SUFFIXES and not raw.startswith(b'\x7fELF'),'Compiled core file: '+name)
    for name in proofs:
        raw=committed[name];raw.decode('utf-8')
        require(b'\0'not in raw and not raw.startswith((b'\x7fELF',b'MZ',b'PK\x03\x04')),'Nontext proof: '+name)
    changed={n for n in core if base.get(n)!=committed[n]};selected=changed|proofs
    require(all(committed[n]==raw or n in selected for n,raw in base.items()),'A changed historical base file would be omitted')
    runtime=json.loads(committed[FREEZE]).get('files_sha256');prior=json.loads(committed[PREVIOUS_FREEZE]).get('files_sha256');published=json.loads(base[BASE_FREEZE]).get('files_sha256')
    require(isinstance(prior,dict) and len(prior)==563 and isinstance(published,dict) and len(published)==475,'Pinned previous/published runtime inventories differ')
    derived={n:sha(committed[n])for n in core if n.split('/',1)[0]in RUNTIME_ROOTS or n in RUNTIME_ROOT_FILES}
    require(isinstance(runtime,dict) and runtime==derived,'Committed new freeze must cover every current runtime root/file exactly')
    require(set(prior)<=set(runtime),'A previous runtime input was deleted')
    changed_prior=sorted(n for n,digest in prior.items()if runtime[n]!=digest)
    require(set(changed_prior)==VERSION_METADATA,'Only the two authorized version metadata inputs must change: '+str(changed_prior))
    require(set(published)<=set(runtime) and all(runtime[n]==digest for n,digest in published.items()if n not in VERSION_METADATA),'All473 published non-version game inputs must remain unchanged')
    for name in VERSION_METADATA:
        verify_version_chain(name,base[name],committed[name],prior.get(name),published.get(name))
    require(REQUIRED_NEW_RUNTIME<=set(runtime),'A new mission resource/expression/guard/state runtime input is missing')
    for name in UNCHANGED_METADATA:require(committed[name]==base[name],'Published Main/BuildInfo/export changed')
    summary=json.loads(committed[SUMMARY]);suites,suite_scripts=summary_suites(summary)
    required_tests=set(REQUIRED_NEW_TESTS)
    if 'scripts/source_contact_scan_state.gd'in runtime:
        require('scripts/source_contact_scan_state.gd.uid'in runtime,'Optional state module lacks its UID');required_tests.add('tests/test_source_contact_scan_state.gd')
    previous_summary=json.loads(committed[PREVIOUS_SUMMARY]);previous_suites,previous_scripts=summary_suites(previous_summary)
    require(len(previous_suites)==49 and previous_summary['checks']==257714,'Pinned previous49-suite regression summary differs')
    require(previous_scripts<=suite_scripts,'Final summary omitted a previously selected regression suite')
    require(required_tests<=suite_scripts,'Final summary lacks a new mission resource/expression/guard/state suite')
    native_specs=list(NATIVE);spec_sources={}
    for relative in a.supplemental_native_spec:
        safe(relative);require(relative.startswith(CURRENT_V)and relative.endswith('.json')and relative in committed and relative not in spec_sources,'Supplemental spec must be a unique committed current-checkpoint JSON')
        native_specs.append(supplemental_spec(json.loads(committed[relative])));spec_sources[relative]=sha(committed[relative])
    require(len({r['name']for r in native_specs})==len(native_specs),'Duplicate native command name')
    native=[];required_inputs={FREEZE,PREVIOUS_FREEZE,SUMMARY,PREVIOUS_SUMMARY,*spec_sources}
    required_inputs.update({REFERENCE_V+'clock-native-proof/'+n for n in ['clock-source32.S','clock-observed.S','clock-observed.ld','dos-clock-admission.txt','jjffe-clock-admission-reference.asm']})
    for spec in native_specs:
        require(spec['generator']in core and spec['fixture']in committed,'Native generator or fixture missing: '+spec['name'])
        raw=committed[spec['fixture']];doc=json.loads(raw);count=doc.get('case_count')
        require(type(count)is int and count>0,'Native fixture case count missing: '+spec['name'])
        record={**spec,'case_count':count,'fixture_sha256':sha(raw),'diagnostic_case_count_separate':int(doc.get('diagnostic_case_count',0))}
        if spec.get('proof_dir'):
            prefix=spec['proof_dir']+'/'
            captures={n for n in proofs if n.startswith(prefix) and PurePosixPath(n).suffix.lower()in {'.s','.asm','.ld','.json','.txt'}}
            require(bool(captures),'Native proof capture/linker sources missing: '+prefix);required_inputs.update(captures)
        for name,digest in doc.get('source_pins',{}).items():
            safe(name);require(name in committed and sha(committed[name])==digest,'Supplemental source pin differs: '+name);required_inputs.add(name)
        native.append(record)
    require(required_inputs<=set(committed),'Required native replay input would be omitted')
    resource_inputs=set();resource_replays=[]
    for spec in RESOURCE_REPLAYS:
        inputs={spec[key]for key in ['generator','resource','capture']};resource_inputs.update(inputs)
        require(spec['generator']in core and spec['resource']in core and spec['capture']in proofs,'Resource replay generator, complete resources or original span capture missing: '+spec['name'])
        require(inputs<=set(committed),'Required resource replay input would be omitted')
        validate_resource_documents(spec,json.loads(committed[spec['resource']]),json.loads(committed[spec['capture']]))
        resource_replays.append({**spec,'resource_sha256':sha(committed[spec['resource']]),'resource_bytes':len(committed[spec['resource']]),'source_dependencies_sha256':{name:sha(committed[name])for name in sorted(inputs)}})

    for row in suites:
        record=row.get('suite_source',{});name=record.get('path')or row.get('test')or row.get('script')
        name=name.removeprefix('res://')
        require(name in committed,'Regression suite source absent')
        if record.get('sha256'):require(record['sha256']==sha(committed[name]),'Regression suite source pin changed: '+name)
    layered=dict(base);layered.update({n:committed[n]for n in selected})
    require(all(layered.get(n)==committed[n]for n in core|proofs),'Actual pair would not reproduce entire current core/proof tree')
    created=dt.datetime.fromtimestamp(int(git(repo,'show','-s','--format=%ct',commit)),dt.timezone.utc)
    payloads={n:{'bytes':len(committed[n]),'sha256':sha(committed[n])}for n in sorted(selected)}
    added=sorted(set(runtime)-set(prior));native_primary=[r for r in native if not r.get('supplemental')];supplements=[r for r in native if r.get('supplemental')]
    manifest={'schema':'starfrontier-mission-expressions-core-0.30.0-source-update-v1','checkpoint':'mission-expressions-core-0.30.0-2026-11-18','delivery_kind':'source-update-only','profile':'dos-firstenc-cumulative-mission-expressions-core-0.30.0-over-published0.28','source_commit':commit,'source_commit_utc':created.isoformat(),'project_prefix':PREFIX,'required_archive_count':2,'cumulative_update':True,'previous_update_archive_required':False,'previous_source_checkpoint':'events-messages-core-0.29.0-2026-11-18','required_archives':[
      {'role':'full_base_source','file':BASE_NAME,'repository_path':BASE_RELATIVE,'bytes':BASE_BYTES,'sha256':BASE_SHA,'source_commit':BASE_COMMIT,'artifact_commit':BASE_ARTIFACT_COMMIT,'actual_files':BASE_ACTUAL_FILES,'zip_entries':BASE_ZIP_ENTRIES},
      {'role':'source_update','file':target.name,'repository_path':UPDATE_RELATIVE,'source_commit':commit,'own_archive_sha256':'Recorded externally in source-update policy; no self SHA256'}],
      'usage':'Download both archives. Extract the complete0.28 base, then this cumulative update into the SAME parent directory. Allow matching StarFrontier-0.28.0-source/ source paths to replace. The update alone is incomplete.',
      'base_archive_sha256':BASE_SHA,'base_source_commit':BASE_COMMIT,'project_payload_count':len(payloads),'project_payloads':payloads,'changed_existing_core_paths':sorted(changed&set(base)),'added_core_paths':sorted(changed-set(base)),'current_text_proof_paths':sorted(proofs),'included_text_proof_prefixes':list(PROOF_PREFIXES),'required_native_replay_inputs':sorted(required_inputs),'resource_replays':resource_replays,'resource_replay_count':len(resource_replays),'required_resource_replay_inputs':sorted(resource_inputs),'resource_replays_added_to_native_totals':False,'supplemental_native_spec_sources':spec_sources,'native_replays':native,'native_generator_count':len(native),'main_native_generator_count':len(native_primary),'native_DOS_control_cases_separate':sum(r['case_count']for r in native_primary),'native_JJFFE_diagnostics_separate':sum(r['diagnostic_case_count_separate']for r in native_primary),'supplemental_native_composition_cases_separate':sum(r['case_count']for r in supplements),'supplemental_controls_added_to_main_native_totals':False,
      'final_summary_path':SUMMARY,'final_summary_sha256':sha(committed[SUMMARY]),'unique_feature_scripts':len(suites),'unique_feature_checks':sum(r['checks']for r in suites),'all_current_core_and_root_files_exact_after_overlay':True,'current_core_and_root_file_count':len(core),'merged_actual_project_file_count':len(layered),'all_base_files_retained':True,'deleted_source_paths':[],'runtime_input_count':len(runtime),'runtime_files_sha256':dict(sorted(runtime.items())),'runtime_freeze_path':FREEZE,'runtime_freeze_sha256':sha(committed[FREEZE]),'previous_backend_freeze_path':PREVIOUS_FREEZE,'previous_backend_freeze_sha256':sha(committed[PREVIOUS_FREEZE]),'previous_backend_runtime_inputs':len(prior),'unchanged_previous_backend_runtime_inputs':len(prior)-len(changed_prior),'changed_previous_backend_runtime_inputs':changed_prior,'allowed_changed_previous_backend_runtime_inputs':sorted(ALLOWED_CHANGED_PREVIOUS_RUNTIME),'added_runtime_inputs_since_previous_backend':added,'published0_28_runtime_inputs':len(published),'unchanged_published0_28_runtime_inputs':len(published)-len(VERSION_METADATA),'omitted_current_private_or_binary_proof_paths':dict(sorted(omitted.items())),'Main_unchanged':True,'version_metadata_changes_only':True,'version_metadata_paths':sorted(VERSION_METADATA),'source_game_version':SOURCE_VERSION,'source_android_code':SOURCE_CODE,'new_APK_produced':False,'separate_APK_may_be_produced':True,'new_playable_release_claimed':False,'full_original_port_complete':False,'physical_device_tested':False,'archive_builder_sha256':sha(Path(__file__).read_bytes()),'scope':'Immutable cumulative raw mission-expressions-core-0.30.0 source checkpoint. Only the authorized version name/code lines change in BuildInfo/export (0.30.0/code55); all561 other previous and473 published game inputs remain exact. Current runtime inputs are derived and frozen. Whole DOS bounded procedures and explicit external boundaries do not establish live Main integration, a complete mission VM/world, a new playable APK or physical Android/FPS proof.'}
    manifest_raw=(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode();target.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='mission-expressions-core-0.30.0-update-',dir=target.parent)as directory:
        candidate=Path(directory)/target.name
        subprocess.run(['git','--literal-pathspecs','archive','--format=zip','-9','--prefix='+PREFIX,'-o',str(candidate),commit,'--',*sorted(selected)],cwd=repo,check=True)
        with zipfile.ZipFile(candidate,'a',compression=zipfile.ZIP_DEFLATED,compresslevel=9)as archive:
            require(archive.comment.decode()==commit,'Git archive comment differs');info=zipfile.ZipInfo(MANIFEST,date_time=created.timetuple()[:6]);info.create_system=3;info.external_attr=0o100644<<16;archive.writestr(info,manifest_raw,compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
        actual={}
        with zipfile.ZipFile(candidate)as archive:
            require(archive.testzip()is None and archive.comment.decode()==commit and len(set(archive.namelist()))==len(archive.infolist()),'ZIP CRC/comment/unique paths failed')
            require(archive.read(MANIFEST)==manifest_raw,'Manifest bytes changed')
            for info in archive.infolist():
                if info.is_dir()or info.filename==MANIFEST:continue
                require(info.filename.startswith(PREFIX),'Payload outside shared prefix');n=info.filename[len(PREFIX):];safe(n);actual[n]=archive.read(info)
            require(set(actual)==selected and all(actual[n]==committed[n]for n in selected),'Archived source blobs differ')
            entries=len(archive.infolist())
        raw=candidate.read_bytes();require(len(raw)<LIMIT_BYTES,'Source update must remain below32MiB')
        with target.open('xb')as f:f.write(raw)
    policy={**manifest,'schema':'starfrontier-mission-expressions-core-0.30.0-source-update-policy-v1','status':'verified','base_archive_path':str(base_path),'update_archive_path':str(target),'update_archive_repository_path':UPDATE_RELATIVE,'update_archive_bytes':len(raw),'update_archive_sha256':sha(raw),'update_archive_zip_entries':entries,'manifest_sha256':sha(manifest_raw),'strictly_below32MiB':True,'base_ZIP_CRC_verified':True,'update_ZIP_CRC_verified':True,'all_current_text_proofs_included':True}
    a.policy.parent.mkdir(parents=True,exist_ok=True);a.policy.write_text(json.dumps(policy,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:policy[k]for k in ['status','source_commit','update_archive_path','update_archive_bytes','update_archive_sha256','runtime_input_count','native_generator_count','unique_feature_scripts','resource_replay_count']},indent=2))

if __name__=='__main__':main()
