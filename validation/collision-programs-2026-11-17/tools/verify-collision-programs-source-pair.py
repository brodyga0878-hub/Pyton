#!/usr/bin/env python3
"""Fresh safe exact0.28+collision-programs source-pair portability verification.

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
PREVIOUS_V='validation/contact-classifier-2026-11-17/'
CURRENT_V='validation/collision-programs-2026-11-17/'
PROOF_PREFIXES=(REFERENCE_V,DISPATCH_V,CYCLE_V,PREVIOUS_V,CURRENT_V)
PREVIOUS_FREEZE=PREVIOUS_V+'runtime-freeze.json'
FREEZE=CURRENT_V+'runtime-freeze.json'
BASE_FREEZE='validation/native-station-2026-11-16/runtime-freeze.json'
SUMMARY=CURRENT_V+'final-regression/summary.json'
PREVIOUS_SUMMARY=PREVIOUS_V+'final-regression/summary.json'
UPDATE_NAME='StarFrontier-collision-programs-core-update.zip'
UPDATE_RELATIVE='deliverables/collision-programs-core-2026-11-17/'+UPDATE_NAME
MANIFEST='SOURCE_UPDATE_MANIFEST.json';LIMIT_BYTES=33554432
CORE_ROOTS=frozenset({'assets','data','scripts','scenes','tests','tools','docs','recovered-history'})
RUNTIME_ROOTS=frozenset({'assets','data','scripts','scenes'})
RUNTIME_ROOT_FILES=frozenset({'export_presets.cfg','icon.svg','icon.svg.import','project.godot'})
PRIVATE_COMPONENTS=frozenset({'.git','.godot','__pycache__','node_modules','private','runner-state','runner_state','state','xdg','user_data','app_userdata','.cache','.config','.local','.codex','.aws'})
TEXT_PROOF_SUFFIXES=frozenset({'.json','.log','.txt','.md','.py','.s','.asm','.ld','.c','.h','.sh','.gd','.uid','.cfg','.csv','.ini','.tsv','.toml','.yaml','.yml'})
SECRET_SUFFIXES=frozenset({'.key','.pem','.keystore','.jks','.p12','.pfx'})
COMPILED_SUFFIXES=frozenset({'.apk','.exe','.dll','.so','.o','.a','.pck','.gdc','.jar','.class','.pyc','.keystore','.jks'})
UNCHANGED_METADATA=('scripts/main.gd','scripts/build_info.gd','export_presets.cfg')
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
 {'name':'contact_classifier','generator':'tools/rebuild_source_contact_classifier_native.py','fixture':'tests/fixtures/source_contact_classifier_native.json','kind':'proof_asm','proof_dir':PREVIOUS_V+'native-proof'},
 {'name':'pair_response','generator':'tools/rebuild_source_pair_response_native.py','fixture':'tests/fixtures/source_pair_response_native.json','kind':'proof_asm','proof_dir':PREVIOUS_V+'pair-native-proof'},
 {'name':'contact_scan','generator':'tools/rebuild_source_contact_scan_native.py','fixture':'tests/fixtures/source_contact_scan_native.json','kind':'proof_asm','proof_dir':PREVIOUS_V+'scan-native-proof','supplemental':True},
 *[{'name':'collision_'+n,'generator':'tools/rebuild_source_collision_'+n+'_native.py','fixture':'tests/fixtures/source_collision_'+n+'_native.json','kind':'proof_asm','proof_dir':CURRENT_V+n+'-native-proof'}for n in ['planes','transform','program','geometry']],
]
# Exact byte-span extraction is a resource replay, not a native case bank.
RESOURCE_REPLAY={
 'name':'collision_program_resources',
 'generator':'tools/extract_source_collision_programs.py',
 'resource':'data/ffe_collision_programs.json',
 'capture':CURRENT_V+'resources/original-spans.json',
 'kind':'archived_byte_spans',
}
ALLOWED_CHANGED_PREVIOUS_RUNTIME=frozenset({'scripts/source_contact_scan.gd','scripts/source_contact_scan_state.gd'})
REQUIRED_NEW_RUNTIME={'data/ffe_collision_programs.json',*{'scripts/source_collision_'+n+suffix for n in ['planes','transform','program','geometry','contact']for suffix in ['.gd','.gd.uid']}}
REQUIRED_NEW_TESTS={'tests/test_source_collision_'+n+'.gd'for n in ['resources','planes','transform','program','geometry','contact']}

BASE_FILES=BASE_ACTUAL_FILES;BASE_ENTRIES=BASE_ZIP_ENTRIES
MANIFEST_NAME=MANIFEST;OLD_FREEZE=BASE_FREEZE

BAD_LOG=re.compile(r'(?:SCRIPT ERROR:|^\s*ERROR:|ObjectDB instances leaked|Leaked instance:|resources still in use at exit|RID allocations[^\n]*(?:leak|exit)|Unicode parsing error|Traceback \(most recent call last\))',re.I|re.M)
COUNTS=re.compile(r'(?<!\d)(\d+)\s+checks,\s*(\d+)\s+failures\b')

def require(value, message):
    if not value:
        raise ValueError(message)


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
    require(m.get('schema')=='starfrontier-collision-programs-source-update-v1'and m.get('source_commit')==commit and m.get('project_prefix')==PREFIX and m.get('required_archive_count')==2 and m.get('base_archive_sha256')==BASE_SHA and m.get('base_source_commit')==BASE_COMMIT,'Source pair identity differs')
    require(m.get('new_APK_produced')is False and m.get('new_playable_release_claimed')is False,'Source update must not claim newAPK')
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
    require(isinstance(prior,dict)and len(prior)==513 and isinstance(old,dict)and len(old)==475,'Pinned513/475 previous runtime inventories differ')
    derived={n:sha(raw)for n,raw in merged.items()if n.split('/',1)[0]in RUNTIME_ROOTS or n in RUNTIME_ROOT_FILES}
    require(runtime==derived,'Freeze does not cover every merged runtime path exactly')
    require(set(prior)<=set(runtime),'A previous runtime path disappeared')
    changed_prior=sorted(n for n,digest in prior.items()if runtime[n]!=digest)
    require(set(changed_prior)<=ALLOWED_CHANGED_PREVIOUS_RUNTIME,'A prior runtime input changed outside the pending-API allowance')
    require(m.get('changed_previous_backend_runtime_inputs')==changed_prior and m.get('unchanged_previous_backend_runtime_inputs')==len(prior)-len(changed_prior) and m.get('allowed_changed_previous_backend_runtime_inputs')==sorted(ALLOWED_CHANGED_PREVIOUS_RUNTIME),'Previous runtime change inventory differs')
    require(all(runtime.get(n)==digest for n,digest in old.items()),'A published0.28 runtime input changed or disappeared')
    for name in UNCHANGED_METADATA:require(merged[name]==base[name],'Published Main/version/export changed: '+name)
    require(REQUIRED_NEW_RUNTIME<=set(runtime),'A new planes/transform/program/geometry/resources/contact resource was omitted')
    require(SUMMARY in merged and m.get('final_summary_path')==SUMMARY and sha(merged[SUMMARY])==m.get('final_summary_sha256'),'Final summary identity differs')
    summary=json.loads(merged[SUMMARY]);require(summary.get('status')=='passed'and summary.get('failures')==0,'Archived final summary must pass')
    suites=summary.get('suites');require(isinstance(suites,list)and bool(suites),'Archived final suites missing')
    scripts=[suite_path(r)for r in suites];names=[r.get('name')for r in suites]
    require(len(set(scripts))==len(scripts)and len(set(names))==len(names),'Duplicate suite/script would inflate checks')
    require(sum(r.get('checks',0)for r in suites)==summary.get('checks')==m.get('unique_feature_checks')and len(suites)==m.get('unique_feature_scripts'),'Actualsummary totals differ')
    require(REQUIRED_NEW_TESTS<=set(scripts),'Current summary lacks new planes/transform/program/geometry/resources/contact suite')
    if 'scripts/source_contact_scan_state.gd'in runtime:
        require('scripts/source_contact_scan_state.gd.uid'in runtime and 'tests/test_source_contact_scan_state.gd'in scripts,'Optional state module lacks its UID or current suite')
    require(PREVIOUS_SUMMARY in merged,'Previous regression source summary missing')
    previous_summary=json.loads(merged[PREVIOUS_SUMMARY]);previous_scripts={suite_path(r)for r in previous_summary.get('suites',[])}
    require(previous_summary.get('status')=='passed'and bool(previous_scripts)and previous_scripts<=set(scripts),'Current summary omitted a previously selected regression suite')
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
    require(isinstance(resource_records,list)and len(resource_records)==1 and m.get('resource_replay_count')==1 and m.get('resource_replays_added_to_native_totals')is False,'Separate resource replay inventory differs')
    resource_row=resource_records[0]
    require(isinstance(resource_row,dict)and all(resource_row.get(key)==value for key,value in RESOURCE_REPLAY.items()),'Resource replay command specification differs')
    resource_inputs={RESOURCE_REPLAY[key]for key in ['generator','resource','capture']}
    require(set(m.get('required_resource_replay_inputs',[]))==resource_inputs and resource_inputs<=set(merged),'Resource replay source or original span capture missing')
    resource_pins=resource_row.get('source_dependencies_sha256')
    require(isinstance(resource_pins,dict)and set(resource_pins)==resource_inputs and all(sha(merged[name])==digest for name,digest in resource_pins.items()),'Resource replay source pin differs')
    resource_raw=merged[RESOURCE_REPLAY['resource']]
    require(resource_row.get('resource_sha256')==sha(resource_raw)and resource_row.get('resource_bytes')==len(resource_raw),'Declared resource bytes/SHA differ')
    resource_doc=json.loads(resource_raw);capture_doc=json.loads(merged[RESOURCE_REPLAY['capture']])
    require(resource_doc.get('schema')=='starfrontier-original-collision-program-resources-v1'and capture_doc.get('schema')=='starfrontier-original-collision-byte-spans-v1','Resource replay input schema differs')
    for key in ['source_executable_sha256','source_assembly_sha256','source_data_sha256']:
        require(resource_doc.get(key)==capture_doc.get(key)and isinstance(resource_doc.get(key),str)and re.fullmatch('[0-9a-f]{64}',resource_doc[key])is not None,'Resource source identity differs: '+key)

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
        execution,_=run(command,'source-resource-'+row['name'],native_env)
        require(output.read_bytes()==merged[row['resource']],'Archive-only resource replay not byteexact: '+row['name'])
        resource_reproductions.append({'name':row['name'],'generator':row['generator'],'resource':row['resource'],'resource_sha256':sha(output.read_bytes()),'resource_bytes':output.stat().st_size,'source_dependencies_sha256':dict(row['source_dependencies_sha256']),'resource_byte_exact':True,'private_original_inputs_deliberately_absent':True,'all_source_files_unchanged':True,'native_execution_claimed':False,'added_to_native_case_totals':False,'ok':True,**execution})
    primary=[r for r in native if not r['supplemental']];supplements=[r for r in native if r['supplemental']]
    native_total=sum(r['case_count']for r in primary);diagnostics=sum(r['diagnostic_case_count_separate']for r in primary);separate=sum(r['case_count']for r in supplements)
    require(native_total==m.get('native_DOS_control_cases_separate')and diagnostics==m.get('native_JJFFE_diagnostics_separate')and separate==m.get('supplemental_native_composition_cases_separate'),'Dynamic native totals differ')
    require(not unchanged()and not missing.exists(),'Source pair changed or absentoriginal appeared')
    result={'schema':'starfrontier-collision-programs-source-pair-portability-v1','status':'verified','ok':True,'completed_utc':dt.datetime.now(dt.timezone.utc).isoformat(),'source_commit':commit,'required_archive_count':2,'base_archive_path':str(base_path),'base_archive_sha256':BASE_SHA,'base_archive_bytes':BASE_BYTES,'base_source_commit':BASE_COMMIT,'base_artifact_commit':BASE_ARTIFACT_COMMIT,'base_archive_actual_files':len(base),'base_archive_zip_entries':base_entries,'update_archive_path':str(update_path),'update_archive_sha256':a.update_sha256,'update_archive_bytes':update_path.stat().st_size,'update_archive_zip_entries':update_entries,'update_project_payload_files':len(patch),'update_manifest_sha256':sha(manifest_raw),'source_project_path':str(project),'workspace':str(work),'fresh_extraction':True,'source_actual_files':len(expected_files),'all_base_files_retained':True,'runtime_inputs_verified':len(runtime),'previous_backend_runtime_inputs':len(prior),'unchanged_previous_backend_runtime_inputs':len(prior)-len(changed_prior),'changed_previous_backend_runtime_inputs':changed_prior,'unchanged_published0_28_runtime_inputs':len(old),'runtime_freeze_sha256':sha(merged[FREEZE]),'all_runtime_inputs_match_frozen_source':True,'safe_archive_entries_verified':True,'both_ZIP_CRC_verified':True,'source_commit_comments_verified':True,'private_xdg':True,'import':imported,'startup':startup,'startup_checks':int(startup_counts[0][0]),'startup_failures':0,'final_summary_path':SUMMARY,'final_summary_sha256':sha(merged[SUMMARY]),'features':features,'unique_feature_scripts_separate':len(features),'unique_feature_checks_separate':sum(r['checks']for r in features),'feature_failures':0,'native_generator_count':len(native),'main_native_generator_count':len(primary),'supplemental_native_generator_count':len(supplements),'native_reproductions':native,'resource_replay_count':len(resource_reproductions),'resource_reproductions':resource_reproductions,'all_resource_replays_byte_exact':True,'resource_replays_added_to_native_totals':False,'native_DOS_control_cases_separate':native_total,'native_JJFFE_copy_diagnostics_separate':diagnostics,'supplemental_native_composition_cases_separate':separate,'supplemental_controls_added_to_main_native_totals':False,'all_native_fixtures_byte_exact':True,'all_source_files_unchanged':True,'modified_source_files':[],'git_metadata_required':False,'new_APK_produced':False,'new_playable_release_claimed':False,'physical_device_tested':False,'full_collision_VM_claimed':False,'full_F597_autopilot_claimed':False,'verifier_sha256':sha(Path(__file__).read_bytes()),'scope':'Fresh exact0.28 base plus cumulative collision-programs source update, safely extracted without Git. Isolated import/startup, one current repeat per unique archived suite and all declared portable native commands plus the separate archive-only byte-span resource replay. Actual fixture/summary counts are read dynamically; supplemental controls stay separate. All513 previous paths are retained; only the optional real-geometry Scan and State routes may change, and all475 published game inputs retain exact bytes. Portability repeats do not add to unique functional totals and do not establish a newAPK, integrated Main route, full collision/effects/AI bank or physical Android/FPS result.'}
    with report.open('x')as f:f.write(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'ok':True,'report':str(report),'source_actual_files':len(expected_files),'runtime_inputs':len(runtime),'startup_checks':result['startup_checks'],'fresh_feature_suites_separate':len(features),'fresh_feature_checks_separate':result['unique_feature_checks_separate'],'native_DOS_cases_separate':native_total,'native_JJFFE_diagnostics_separate':diagnostics,'native_generator_commands':len(native),'resource_replay_commands':len(resource_reproductions),'supplemental_native_compositions_separate':separate},indent=2))

def main():
    p=argparse.ArgumentParser(description=__doc__)
    for flag in ['base-archive','update-archive','workdir','report']:p.add_argument('--'+flag,type=Path,required=True)
    p.add_argument('--source-commit',required=True);p.add_argument('--update-sha256',required=True);execute(p.parse_args())
if __name__=='__main__':main()
