import datetime as dt
import hashlib
import json
import re
import shutil
import subprocess
from pathlib import Path

r=Path('/workspace/Pyton');v=r/'validation/mission-statements-2026-11-19'
summary=json.loads((r/'build/mission-statements-final-summary.json').read_text())
assert summary['status']=='passed' and summary['failures']==0
assert len(summary['suites'])==60 and len({x['name']for x in summary['suites']})==60
assert sum(x['checks']for x in summary['suites'])==summary['checks']
dest=v/'final-regression';dest.mkdir(exist_ok=False)
(dest/'logs').mkdir();(dest/'reports').mkdir()
sha=lambda raw:hashlib.sha256(raw).hexdigest()
reports=0
for row in summary['suites']:
    assert row['status']=='passed'and row['failures']==0 and row['checks']>0
    source=r/row['suite_source']['path'];assert sha(source.read_bytes())==row['suite_source']['sha256']
    log=Path(row['log']);target=dest/'logs'/log.name;shutil.copyfile(log,target);row['log']=str(target)
    candidates=set(re.findall(r'res://(build/(?:current-test-reports/)?[^"\n]+\.json)',source.read_text()))
    assert len(candidates)<=1,(source,candidates)
    if candidates:
        src=r/next(iter(candidates));doc=json.loads(src.read_text());assert doc['checks']==row['checks']and doc['failures']==0,(source,'report counts')
        assert isinstance(doc.get('sources'),dict)and doc['sources'],(source,'source map')
        for path,digest in doc['sources'].items():assert sha((r/path).read_bytes())==digest,(src,path,'stale source')
        target=dest/'reports'/(row['name']+'.json');shutil.copyfile(src,target);row['archived_report']=target.relative_to(r).as_posix();reports+=1
(dest/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
paths=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z'],cwd=r).decode().split('\0')
roots={'scripts','data','assets','scenes'};rootfiles={'project.godot','export_presets.cfg','icon.svg','icon.svg.import'}
current={n:sha((r/n).read_bytes())for n in sorted(set(paths)-{''})if n.split('/',1)[0]in roots or n in rootfiles}
prior=json.loads((r/'validation/mission-tasks-2026-11-19/runtime-freeze.json').read_text())['files_sha256']
published=json.loads((r/'validation/native-station-2026-11-16/runtime-freeze.json').read_text())['files_sha256']
assert len(prior)==585 and len(published)==475 and len(current)==593
assert set(prior)<=set(current)
changed=sorted(n for n,h in prior.items()if current[n]!=h)
assert changed==['export_presets.cfg','scripts/build_info.gd']
assert all(current[n]==h for n,h in published.items()if n not in changed)
freeze={'schema':'starfrontier-mission-statements-runtime-freeze-v1','checkpoint':'mission-statements-core-0.32.0-2026-11-19','created_utc':dt.datetime.now(dt.timezone.utc).isoformat(),'runtime_input_count':len(current),'previous_runtime_input_count':585,'unchanged_previous_runtime_input_count':583,'changed_previous_runtime_paths':changed,'unchanged_published_game_inputs':473,'added_runtime_paths':sorted(set(current)-set(prior)),'source_game_version':'0.32.0-statements-alpha1','source_android_code':57,'version_metadata_changes_only':True,'Main_integrated':False,'new_APK_produced':False,'separate_APK_build_verification_required':True,'scope':'Actual DOS F39/F40 spawn and F41 statement procedures with defined invocation scratch and owned statement/expression/task/event composition and cold replay. Only the authorized version metadata changes among prior runtime inputs. F41 executes in the composed kernel; F1344 formatting, remaining world provider bodies and Main orchestration remain separate.','files_sha256':current}
(v/'runtime-freeze.json').write_text(json.dumps(freeze,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'checks':summary['checks'],'suites':len(summary['suites']),'reports':reports,'runtime_inputs':len(current),'unchanged_previous':583,'unchanged_published':473},indent=2))
