#!/usr/bin/env python3
"""Fresh safe exact0.28+mission-expressions-core-0.30.0 source-pair portability verification.

No Git metadata, original game executable or JJFFE checkout is used. Run isolated
import/startup, each unique suite declared by the archived current summary and
all declared portable native commands. Counts come from actual reports/fixtures.
"""
from __future__ import annotations
import argparse,datetime as dt,hashlib,json,os,re,shutil,stat,subprocess,time,zipfile
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

BASE_FILES=BASE_ACTUAL_FILES;BASE_ENTRIES=BASE_ZIP_ENTRIES
MANIFEST_NAME=MANIFEST;OLD_FREEZE=BASE_FREEZE

BAD_LOG=re.compile(r'(?:SCRIPT ERROR:|^\s*ERROR:|ObjectDB instances leaked|Leaked instance:|resources still in use at exit|RID allocations[^\n]*(?:leak|exit)|Unicode parsing error|Traceback \(most recent call last\))',re.I|re.M)
COUNTS=re.compile(r'(?<!\d)(\d+)\s+checks,\s*(\d+)\s+failures\b')

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
    require(isinstance(name, str) and name and '\\' not in name
            and all(ord(c) >= 32 for c in name), 'Unsafe archive path: ' + repr(name))
    path = PurePosixPath(name)
    require(not path.is_absolute() and '..' not in path.parts and '.' not in path.parts
            and path.as_posix() == name, 'Noncanonical archive path: ' + repr(name))
    return path


def file_inventory(archive, *, base, source_commit):
    raw = archive.read_bytes()
    if base:
        require(len(raw) == BASE_BYTES and sha(raw) == BASE_SHA, 'The complete required0.28 base source differs')
    inventory = {}
    with zipfile.ZipFile(archive) as bundle:
        require(bundle.testzip() is None, 'ZIP CRC failed: ' + str(archive))
        require(bundle.comment.decode('ascii') == (BASE_COMMIT if base else source_commit), 'Wrong ZIP source commit comment')
        records = bundle.infolist()
        if base:
            require(len(records) == BASE_ENTRIES, 'Base ZIP entry count differs')
        require(len({row.filename for row in records}) == len(records), 'Duplicate ZIP archive entry')
        for row in records:
            mode = row.external_attr >> 16
            kind = stat.S_IFMT(mode)
            require(kind in (0, stat.S_IFREG, stat.S_IFDIR), 'Symbolic link or special ZIP entry rejected')
            name = row.filename.rstrip('/') if row.is_dir() else row.filename
            safe(name)
            if row.is_dir():
                require(row.filename.startswith(PREFIX), 'ZIP directory outside the shared source prefix')
                continue
            if not base and row.filename == MANIFEST_NAME:
                inventory[MANIFEST_NAME] = bundle.read(row)
                continue
            require(row.filename.startswith(PREFIX), 'ZIP file outside required shared source prefix')
            relative = row.filename[len(PREFIX):]
            safe(relative)
            require(relative not in inventory and not relative.startswith('.git/'), 'Unsafe or duplicate source path')
            inventory[relative] = bundle.read(row)
    if base:
        require(len(inventory) == BASE_FILES and OLD_FREEZE in inventory, 'The base source inventory is incomplete')
    return inventory, len(records)


def suite_path(row):
    source=row.get('suite_source',{})
    name=source.get('path')or row.get('test')or row.get('script')
    require(isinstance(name,str),'Archived suite path missing')
    name=name.removeprefix('res://');safe(name)
    require(name.startswith('tests/')and name.endswith('.gd'),'Suite is not a source test')
    return name

def suite_reports(project,row,script):
    """Report locations changed across checkpoints; source pins remain exact."""
    candidates=[]
    for key in ['report','report_path','archived_report','report_file']:
        value=row.get(key)
        if isinstance(value,dict):value=value.get('path')
        if isinstance(value,str):
            if value.startswith('res://'):value=value[6:]
            if value.startswith('/workspace/Pyton/'):value=value[len('/workspace/Pyton/'):]
            if not Path(value).is_absolute():
                safe(value);candidates.extend([value,CURRENT_V+value,CURRENT_V+'final-regression/'+value])
    source=(project/script).read_text()
    match=re.search(r'const\s+REPORT\s*:?=\s*"res://([^\"]+)"',source)
    basename=PurePosixPath(match[1]).name if match else row['name'].replace('_','-')+'.json'
    candidates.extend([CURRENT_V+basename,CURRENT_V+'final-regression/'+basename,CURRENT_V+'final-regression/reports/'+basename])
    result=[]
    for name in dict.fromkeys(candidates):
        if(project/name).is_file():result.append(name)
    return result

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


def execute(a):
    commit=a.source_commit
    require(re.fullmatch('[0-9a-f]{40}',commit)is not None and re.fullmatch('[0-9a-f]{64}',a.update_sha256)is not None,'Immutable source commit and exact updateSHA required')
    base_path=a.base_archive.resolve();update_path=a.update_archive.resolve();work=a.workdir.resolve();report=a.report.resolve()
    require(not work.exists()and not report.exists(),'Fresh workdir/report must not already exist')
    require(not report.is_relative_to(work),'Public report/logs must be outside private verification workspace')
    require(sha(update_path.read_bytes())==a.update_sha256,'Requested updateSHA differs')
    base,base_entries=file_inventory(base_path,base=True,source_commit=commit)
    patch,update_entries=file_inventory(update_path,base=False,source_commit=commit)
    require(MANIFEST in patch,'Source update manifest missing');manifest_raw=patch.pop(MANIFEST);m=json.loads(manifest_raw)
    require(m.get('schema')=='starfrontier-mission-expressions-core-0.30.0-source-update-v1'and m.get('source_commit')==commit and m.get('project_prefix')==PREFIX and m.get('required_archive_count')==2 and m.get('base_archive_sha256')==BASE_SHA and m.get('base_source_commit')==BASE_COMMIT,'Source pair identity differs')
    require(m.get('new_APK_produced')is False and m.get('new_playable_release_claimed')is False,'Source update must not claim newAPK')
    require(m.get('source_game_version')==SOURCE_VERSION and m.get('source_android_code')==SOURCE_CODE and m.get('version_metadata_changes_only')is True and m.get('version_metadata_paths')==sorted(VERSION_METADATA) and m.get('Main_unchanged')is True,'Source version metadata contract differs')
    records=m.get('required_archives');require(isinstance(records,list)and len(records)==2,'Exactlytwo archives required')
    base_record=next((r for r in records if r.get('role')=='full_base_source'),{});update_record=next((r for r in records if r.get('role')=='source_update'),{})
    require(base_record.get('sha256')==BASE_SHA and base_record.get('bytes')==BASE_BYTES and base_record.get('source_commit')==BASE_COMMIT and update_record.get('source_commit')==commit,'Declared archive identities differ')
    declared=m.get('project_payloads');require(isinstance(declared,dict)and len(declared)==m.get('project_payload_count')and set(declared)==set(patch),'Update payload inventory differs')
    for name,record in declared.items():safe(name);require(record.get('bytes')==len(patch[name])and record.get('sha256')==sha(patch[name]),'Payload bytes/SHA differ: '+name)
    merged=dict(base);merged.update(patch)
    require(len(merged)==m.get('merged_actual_project_file_count')and set(base)<=set(merged)and m.get('all_base_files_retained')is True and m.get('deleted_source_paths')==[],'Merged source path inventory differs')
    require(FREEZE in merged and sha(merged[FREEZE])==m.get('runtime_freeze_sha256'),'Runtime freeze identity differs')
    runtime=json.loads(merged[FREEZE]).get('files_sha256');prior=json.loads(merged[PREVIOUS_FREEZE]).get('files_sha256');old=json.loads(base[BASE_FREEZE]).get('files_sha256')
    require(isinstance(runtime,dict)and runtime==m.get('runtime_files_sha256')and len(runtime)==m.get('runtime_input_count'),'Current runtime inventory differs')
    require(isinstance(prior,dict)and len(prior)==563 and isinstance(old,dict)and len(old)==475,'Pinned563/475 previous runtime inventories differ')
    derived={n:sha(raw)for n,raw in merged.items()if n.split('/',1)[0]in RUNTIME_ROOTS or n in RUNTIME_ROOT_FILES}
    require(runtime==derived,'Freeze does not cover every merged runtime path exactly')
    require(set(prior)<=set(runtime),'A previous runtime path disappeared')
    changed_prior=sorted(n for n,digest in prior.items()if runtime[n]!=digest)
    require(set(changed_prior)==VERSION_METADATA,'Only the two authorized version metadata inputs must change')
    require(m.get('changed_previous_backend_runtime_inputs')==changed_prior and m.get('unchanged_previous_backend_runtime_inputs')==len(prior)-len(changed_prior) and m.get('allowed_changed_previous_backend_runtime_inputs')==sorted(ALLOWED_CHANGED_PREVIOUS_RUNTIME),'Previous runtime change inventory differs')
    require(all(runtime.get(n)==digest for n,digest in old.items()if n not in VERSION_METADATA),'A published non-version0.28 input changed or disappeared')
    for name in VERSION_METADATA:
        verify_version_chain(name,base[name],merged[name],prior.get(name),old.get(name))
    for name in UNCHANGED_METADATA:require(merged[name]==base[name],'Published Main/version/export changed: '+name)
    require(REQUIRED_NEW_RUNTIME<=set(runtime),'A new equipment/effects runtime input was omitted')
    require(SUMMARY in merged and m.get('final_summary_path')==SUMMARY and sha(merged[SUMMARY])==m.get('final_summary_sha256'),'Final summary identity differs')
    summary=json.loads(merged[SUMMARY]);require(summary.get('status')=='passed'and summary.get('failures')==0,'Archived final summary must pass')
    suites=summary.get('suites');require(isinstance(suites,list)and bool(suites),'Archived final suites missing')
    scripts=[suite_path(r)for r in suites];names=[r.get('name')for r in suites]
    require(len(set(scripts))==len(scripts)and len(set(names))==len(names),'Duplicate suite/script would inflate checks')
    require(sum(r.get('checks',0)for r in suites)==summary.get('checks')==m.get('unique_feature_checks')and len(suites)==m.get('unique_feature_scripts'),'Actualsummary totals differ')
    require(REQUIRED_NEW_TESTS<=set(scripts),'Current summary lacks new mission resource/expression/guard/state suite')
    if 'scripts/source_contact_scan_state.gd'in runtime:
        require('scripts/source_contact_scan_state.gd.uid'in runtime and 'tests/test_source_contact_scan_state.gd'in scripts,'Optional state module lacks its UID or current suite')
    require(PREVIOUS_SUMMARY in merged,'Previous regression source summary missing')
    previous_summary=json.loads(merged[PREVIOUS_SUMMARY]);previous_scripts={suite_path(r)for r in previous_summary.get('suites',[])}
    require(previous_summary.get('status')=='passed'and previous_summary.get('failures')==0 and len(previous_scripts)==49 and previous_summary.get('checks')==257714,'Pinned previous49-suite regression summary differs')
    require(previous_scripts<=set(scripts),'Current summary omitted a previously selected regression suite')
    native_specs=list(NATIVE);spec_sources=m.get('supplemental_native_spec_sources',{})
    require(isinstance(spec_sources,dict),'Supplemental native spec inventory must be an object')
    for relative,digest in spec_sources.items():
        safe(relative);require(relative.startswith(CURRENT_V)and relative.endswith('.json')and relative in merged and sha(merged[relative])==digest,'Supplemental native specification source differs')
        native_specs.append(supplemental_spec(json.loads(merged[relative])))
    require(len({r['name']for r in native_specs})==len(native_specs),'Duplicate native command name')
    spec_by_name={r['name']:r for r in native_specs};native_records=m.get('native_replays')
    require(isinstance(native_records,list)and len(native_records)==len(native_specs)and {r.get('name')for r in native_records}==set(spec_by_name),'Portable nativecommand inventory differs')
    for row in native_records:
        spec=spec_by_name[row['name']]
        require(all(row.get(k)==v for k,v in spec.items()),'Native command specification differs: '+row['name'])
        require(row['fixture']in merged and sha(merged[row['fixture']])==row.get('fixture_sha256'),'Native fixtureSHA differs')
        fixture=json.loads(merged[row['fixture']]);require(type(fixture.get('case_count'))is int and fixture['case_count']>0 and fixture['case_count']==row.get('case_count'),'Actual native fixturecount differs')
    require(set(m.get('required_native_replay_inputs',[]))<=set(merged),'A native replay source/linker input is absent')
    resource_records=m.get('resource_replays')
    require(isinstance(resource_records,list)and len(resource_records)==len(RESOURCE_REPLAYS)and m.get('resource_replay_count')==len(RESOURCE_REPLAYS)and m.get('resource_replays_added_to_native_totals')is False,'Separate resource replay inventory differs')
    require({r.get('name')for r in resource_records}=={r['name']for r in RESOURCE_REPLAYS},'Resource replay names differ')
    resource_inputs=set()
    for spec in RESOURCE_REPLAYS:
        resource_row=next(r for r in resource_records if r.get('name')==spec['name'])
        require(isinstance(resource_row,dict)and all(resource_row.get(key)==value for key,value in spec.items()),'Resource replay command specification differs')
        inputs={spec[key]for key in ['generator','resource','capture']};resource_inputs.update(inputs)
        require(inputs<=set(merged),'Resource replay source or original span capture missing')
        resource_pins=resource_row.get('source_dependencies_sha256')
        require(isinstance(resource_pins,dict)and set(resource_pins)==inputs and all(sha(merged[name])==digest for name,digest in resource_pins.items()),'Resource replay source pin differs')
        resource_raw=merged[spec['resource']]
        require(resource_row.get('resource_sha256')==sha(resource_raw)and resource_row.get('resource_bytes')==len(resource_raw),'Declared resource bytes/SHA differ')
        validate_resource_documents(spec,json.loads(resource_raw),json.loads(merged[spec['capture']]))
    require(set(m.get('required_resource_replay_inputs',[]))==resource_inputs,'Resource replay input inventory differs')

    require(set(m.get('included_text_proof_prefixes',[]))==set(PROOF_PREFIXES),'Cumulative proof prefixes differ')
    expected_files={n:sha(raw)for n,raw in merged.items()};work.mkdir(parents=True,exist_ok=False);project=work/'source'/PREFIX.rstrip('/');project.mkdir(parents=True,exist_ok=False)
    for name,raw in merged.items():
        target=project.joinpath(*safe(name).parts);require(target.resolve().is_relative_to(project.resolve()),'Extraction escape');target.parent.mkdir(parents=True,exist_ok=True)
        with target.open('xb')as f:f.write(raw)
    (work/MANIFEST).write_bytes(manifest_raw);report.parent.mkdir(parents=True,exist_ok=True)
    def unchanged():return[n for n,digest in expected_files.items()if not(project/n).is_file()or sha((project/n).read_bytes())!=digest]
    def env_for(label):
        env=os.environ.copy();env['PYTHONDONTWRITEBYTECODE']='1'
        for key,suffix in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
            target=work/'private-xdg'/label/suffix;target.mkdir(parents=True,exist_ok=False);env[key]=str(target)
        return env
    def run(command,label,env,timeout=300):
        start=time.monotonic()
        try:done=subprocess.run(command,cwd=project,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout);raw=done.stdout;code=done.returncode;timed=False
        except subprocess.TimeoutExpired as error:raw=error.stdout or b'';code=None;timed=True
        logfile=report.parent/(label+'.log')
        with logfile.open('xb')as f:f.write(raw)
        text=raw.decode('utf-8',errors='replace');bad=[s for s in text.splitlines()if BAD_LOG.search(s)]
        result={'command':command,'exit_code':code,'timed_out':timed,'duration_seconds':round(time.monotonic()-start,6),'log_file':logfile.name,'log_sha256':sha(raw),'error_markers':bad}
        require(code==0 and not timed and not bad,'Fresh command failed: '+label);require(not unchanged(),'Archived source mutated during: '+label)
        return result,text
    require(not unchanged(),'Initial extracted source differs')
    godot=shutil.which('godot')or shutil.which('godot4');require(godot,'Godot required')
    imported,_=run([godot,'--headless','--editor','--audio-driver','Dummy','--path',str(project),'--import','--quit'],'source-pair-import',env_for('import'))
    startup,text=run([godot,'--headless','--audio-driver','Dummy','--path',str(project),'--script','res://tests/test_source_full_startup.gd','--','--source-startup-isolated'],'source-pair-startup',env_for('source_full_startup'))
    startup_counts=COUNTS.findall(text);require(len(startup_counts)==1 and int(startup_counts[0][0])>0 and startup_counts[0][1]=='0','Isolatedstartup must pass exactlyone declared summary')
    features=[]
    for row,script in zip(suites,scripts):
        name=row['name'];require(isinstance(name,str)and re.fullmatch('[A-Za-z0-9_-]+',name),'Unsafe suite label')
        count=row.get('checks');require(row.get('status')in('passed','verified')and row.get('failures')==0 and type(count)is int and count>0,'Archivedsuite must pass')
        pin=row.get('suite_source',{}).get('sha256');require(isinstance(pin,str)and pin==sha((project/script).read_bytes()),'Suite sourcepin differs: '+name)
        archived_reports=[]
        for relative in suite_reports(project,row,script):
            doc=json.loads((project/relative).read_text());require(doc.get('checks')==count and doc.get('failures')==0,'Archived detailed report counts differ: '+relative)
            pins=doc.get('sources',{})
            require(isinstance(pins,dict),'Archivedreport sourcepins malformed')
            for source,digest in pins.items():safe(source);require(source in expected_files and expected_files[source]==digest,'Archivedreport source pin differs: '+source)
            archived_reports.append({'path':relative,'sha256':sha((project/relative).read_bytes())})
        execution,text=run([godot,'--headless','--audio-driver','Dummy','--path',str(project),'--script','res://'+script],name.replace('_','-')+'-feature',env_for(name))
        require(COUNTS.findall(text)==[(str(count),'0')],'Freshsuite count differs: '+name)
        features.append({'name':name,'test':script,'checks':count,'failures':0,'suite_sha256':pin,'archived_reports':archived_reports,'all_source_files_unchanged':True,'ok':True,**execution})
    native=[];missing=work/'private-original-inputs-deliberately-absent';require(not missing.exists(),'Absentoriginal sentinel exists');native_env=env_for('native');python=shutil.which('python3')or'python3'
    for row in native_records:
        name=row['name'];output=work/'native'/(name+'.json');output.parent.mkdir(parents=True,exist_ok=True);command=[python,row['generator'],'--output',str(output)];kind=row['kind']
        if kind=='reference_bank':command+=['--exe',str(missing/'FIRSTENC.EXE'),'--source',str(missing/'ffe.asm'),'--data',str(missing/'ffedat.asm')]
        elif kind=='clock':command+=['--executable',str(missing/'FIRSTENC.EXE'),'--source',str(missing/'ffe.asm'),'--proof-dir',str(project/row['proof_dir']),'--validation-dir',str(work/'native'/'clock-proof')]
        elif kind=='proof_asm':
            proof=work/'native'/(name+'-proof');shutil.copytree(project/row['proof_dir'],proof);command+=['--proof-dir',str(proof),'--exe',str(missing/'FIRSTENC.EXE'),'--asm',str(missing/'ffe.asm'),'--data',str(missing/'ffedat.asm')]
        elif kind=='asm':command+=['--exe',str(missing/'FIRSTENC.EXE'),'--asm',str(missing/'ffe.asm'),'--data',str(missing/'ffedat.asm')]
        elif kind=='source':command+=['--exe',str(missing/'FIRSTENC.EXE'),'--source',str(missing/'ffe.asm'),'--data',str(missing/'ffedat.asm')]
        elif kind!='supplemental':raise ValueError('Unreviewed native command kind')
        execution,_=run(command,'source-native-'+name,native_env)
        require(output.read_bytes()==(project/row['fixture']).read_bytes(),'Portable native fixture not byteexact: '+name)
        doc=json.loads(output.read_text());require(doc.get('case_count')==row['case_count'],'Portable native count changed')
        native.append({'name':name,'generator':row['generator'],'fixture':row['fixture'],'fixture_sha256':sha(output.read_bytes()),'case_count':doc['case_count'],'diagnostic_case_count_separate':int(doc.get('diagnostic_case_count',0)),'supplemental':bool(row.get('supplemental')),'fixture_byte_exact':True,'private_original_inputs_deliberately_absent':True,'all_source_files_unchanged':True,'ok':True,**execution})
    resource_reproductions=[]
    for row in resource_records:
        output=work/'resource-replays'/(row['name']+'.json');output.parent.mkdir(parents=True,exist_ok=True)
        command=[python,row['generator'],'--output',str(output),'--capture',str(project/row['capture']),'--exe',str(missing/'FIRSTENC.EXE'),'--asm',str(missing/'ffe.asm'),'--data',str(missing/'ffedat.asm')]
        if row['kind']=='archived_mission_byte_spans':command+=['--mission-asm',str(missing/'ffebmp.asm')]
        execution,_=run(command,'source-resource-'+row['name'],native_env)
        require(output.read_bytes()==merged[row['resource']],'Archive-only resource replay not byteexact: '+row['name'])
        resource_reproductions.append({'name':row['name'],'generator':row['generator'],'resource':row['resource'],'resource_sha256':sha(output.read_bytes()),'resource_bytes':output.stat().st_size,'source_dependencies_sha256':dict(row['source_dependencies_sha256']),'resource_byte_exact':True,'private_original_inputs_deliberately_absent':True,'all_source_files_unchanged':True,'native_execution_claimed':False,'added_to_native_case_totals':False,'ok':True,**execution})
    primary=[r for r in native if not r['supplemental']];supplements=[r for r in native if r['supplemental']]
    native_total=sum(r['case_count']for r in primary);diagnostics=sum(r['diagnostic_case_count_separate']for r in primary);separate=sum(r['case_count']for r in supplements)
    require(native_total==m.get('native_DOS_control_cases_separate')and diagnostics==m.get('native_JJFFE_diagnostics_separate')and separate==m.get('supplemental_native_composition_cases_separate'),'Dynamic native totals differ')
    require(not unchanged()and not missing.exists(),'Source pair changed or absentoriginal appeared')
    result={'schema':'starfrontier-mission-expressions-core-0.30.0-source-pair-portability-v1','status':'verified','ok':True,'completed_utc':dt.datetime.now(dt.timezone.utc).isoformat(),'source_commit':commit,'required_archive_count':2,'base_archive_path':str(base_path),'base_archive_sha256':BASE_SHA,'base_archive_bytes':BASE_BYTES,'base_source_commit':BASE_COMMIT,'base_artifact_commit':BASE_ARTIFACT_COMMIT,'base_archive_actual_files':len(base),'base_archive_zip_entries':base_entries,'update_archive_path':str(update_path),'update_archive_sha256':a.update_sha256,'update_archive_bytes':update_path.stat().st_size,'update_archive_zip_entries':update_entries,'update_project_payload_files':len(patch),'update_manifest_sha256':sha(manifest_raw),'source_project_path':str(project),'workspace':str(work),'fresh_extraction':True,'source_actual_files':len(expected_files),'all_base_files_retained':True,'runtime_inputs_verified':len(runtime),'previous_backend_runtime_inputs':len(prior),'unchanged_previous_backend_runtime_inputs':len(prior)-len(changed_prior),'changed_previous_backend_runtime_inputs':changed_prior,'published0_28_runtime_inputs':len(old),'unchanged_published0_28_runtime_inputs':len(old)-len(VERSION_METADATA),'version_metadata_changes_only':True,'source_game_version':SOURCE_VERSION,'source_android_code':SOURCE_CODE,'runtime_freeze_sha256':sha(merged[FREEZE]),'all_runtime_inputs_match_frozen_source':True,'safe_archive_entries_verified':True,'both_ZIP_CRC_verified':True,'source_commit_comments_verified':True,'private_xdg':True,'import':imported,'startup':startup,'startup_checks':int(startup_counts[0][0]),'startup_failures':0,'final_summary_path':SUMMARY,'final_summary_sha256':sha(merged[SUMMARY]),'features':features,'unique_feature_scripts_separate':len(features),'unique_feature_checks_separate':sum(r['checks']for r in features),'feature_failures':0,'native_generator_count':len(native),'main_native_generator_count':len(primary),'supplemental_native_generator_count':len(supplements),'native_reproductions':native,'resource_replay_count':len(resource_reproductions),'resource_reproductions':resource_reproductions,'all_resource_replays_byte_exact':True,'resource_replays_added_to_native_totals':False,'native_DOS_control_cases_separate':native_total,'native_JJFFE_copy_diagnostics_separate':diagnostics,'supplemental_native_composition_cases_separate':separate,'supplemental_controls_added_to_main_native_totals':False,'all_native_fixtures_byte_exact':True,'all_source_files_unchanged':True,'modified_source_files':[],'git_metadata_required':False,'new_APK_produced':False,'separate_APK_may_be_produced':True,'new_playable_release_claimed':False,'physical_device_tested':False,'full_F41_VM_claimed':False,'full_collision_VM_claimed':False,'full_F597_autopilot_claimed':False,'verifier_sha256':sha(Path(__file__).read_bytes()),'scope':'Fresh exact0.28 base plus cumulative mission-expressions-core-0.30.0 source update, safely extracted without Git. Isolated import/startup, one current repeat per unique archived suite and all declared portable native commands plus the two separate archive-only byte-span resource replays. Actual fixture/summary counts are read dynamically; supplemental controls stay separate. Only the authorized version name/code lines change in BuildInfo/export (0.30.0/code55); all561 other previous and473 published game inputs remain exact. Portability repeats do not add to unique functional totals and do not establish a newAPK, integrated Main route, full mission VM/world or physical Android/FPS result.'}
    with report.open('x')as f:f.write(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'ok':True,'report':str(report),'source_actual_files':len(expected_files),'runtime_inputs':len(runtime),'startup_checks':result['startup_checks'],'fresh_feature_suites_separate':len(features),'fresh_feature_checks_separate':result['unique_feature_checks_separate'],'native_DOS_cases_separate':native_total,'native_JJFFE_diagnostics_separate':diagnostics,'native_generator_commands':len(native),'resource_replay_commands':len(resource_reproductions),'supplemental_native_compositions_separate':separate},indent=2))

def main():
    p=argparse.ArgumentParser(description=__doc__)
    for flag in ['base-archive','update-archive','workdir','report']:p.add_argument('--'+flag,type=Path,required=True)
    p.add_argument('--source-commit',required=True);p.add_argument('--update-sha256',required=True);execute(p.parse_args())
if __name__=='__main__':main()
