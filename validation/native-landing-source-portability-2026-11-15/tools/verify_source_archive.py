#!/usr/bin/env python3
"""Verify a frozen source ZIP in a fresh project and isolated XDG directories."""
from __future__ import annotations
import argparse,datetime,hashlib,json,os,re,stat,subprocess,time,zipfile
from pathlib import Path
BASE=Path(__file__).resolve().parent
def sha(raw):return hashlib.sha256(raw).hexdigest()
def utc():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('archive',type=Path);parser.add_argument('--sha256',required=True);parser.add_argument('--source-commit',required=True);parser.add_argument('--report',type=Path,required=True)
 parser.add_argument('--execution-policy',choices=['restricted','require_escalated'],default='restricted');parser.add_argument('--prior-report',type=Path)
 args=parser.parse_args();started=utc();archive=args.archive.resolve();raw=archive.read_bytes();digest=sha(raw)
 if digest!=args.sha256:raise ValueError('Source archive SHA differs from frozen expected bytes')
 extracted=BASE/'source';xdg=BASE/'source_full_startup'
 if extracted.exists() or xdg.exists():raise ValueError('Fresh source and XDG directories are required; refuse cache reuse')
 report={'schema':'starfrontier-source-archive-portability-v1','started_utc':started,'archive_path':str(archive),'archive_sha256':digest,'expected_archive_sha256':args.sha256,'archive_bytes':len(raw),'source_commit':args.source_commit,'workspace':str(BASE),'source_project_path':'','fresh_extraction':True,'private_xdg':True,'apk_built':False,'host_sdk_copied':False,'commands':[],'ok':False}
 report['execution_policy']=args.execution_policy
 if args.prior_report:report['prior_attempt_report']={'path':str(args.prior_report),'sha256':sha(args.prior_report.read_bytes())}
 args.report.parent.mkdir(parents=True,exist_ok=True)
 def save_report():args.report.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 save_report()
 with zipfile.ZipFile(archive)as bundle:
  entries=bundle.infolist();bad=bundle.testzip()
  if bad:raise ValueError('ZIP CRC failure: '+bad)
  comment=bundle.comment.decode('ascii')
  if comment!=args.source_commit:raise ValueError('ZIP commit comment differs from frozen expected commit')
  report['archive_commit_comment']=comment
  files={}
  for entry in entries:
   path=Path(entry.filename)
   if path.is_absolute()or '..'in path.parts or stat.S_IFMT(entry.external_attr>>16)==stat.S_IFLNK:raise ValueError('Unsafe archive path')
   if '.godot'in path.parts or '.git'in path.parts:raise ValueError('Archive includes pre-existing import or Git cache')
   if not entry.is_dir():files[entry.filename]=sha(bundle.read(entry))
  extracted.mkdir(parents=True)
  bundle.extractall(extracted)
 roots=list(extracted.rglob('project.godot'))
 if not roots:raise ValueError('Expected extracted Godot project')
 shallowest=min(len(root.relative_to(extracted).parts)for root in roots)
 primary=[root for root in roots if len(root.relative_to(extracted).parts)==shallowest]
 if len(primary)!=1:raise ValueError('Expected one unambiguous top-level Godot project')
 project=primary[0].parent
 report['nested_historical_godot_projects']=[str(root.relative_to(extracted))for root in roots if root!=primary[0]]
 # This release also includes the explicitly scoped static parity audit.
 # Presence/counts are packaging checks, not semantic or full-game proof.
 audit_dir=project/'validation/parity-audit-2026-11-07'
 catalog=json.loads((audit_dir/'original-function-catalog.json').read_text())
 data_catalog=json.loads((audit_dir/'original-data-block-catalog.json').read_text())
 required=list(catalog['semantic_review_documents'])+['tools/audit_original_parity.py','validation/parity-audit-2026-11-07/original-function-catalog.json','validation/parity-audit-2026-11-07/original-function-catalog.csv','validation/parity-audit-2026-11-07/original-data-block-catalog.json','validation/parity-audit-2026-11-07/resource-inventory.json']
 audit_files={name:sha((project/name).read_bytes())for name in required}
 if catalog['function_count']!=1615 or len(catalog['functions'])!=1615 or len(catalog['upstream_file_inventory'])!=50:raise ValueError('Unexpected static source inventory counts')
 if data_catalog['labelled_data_declarations']!=len(data_catalog['blocks']) or data_catalog['labelled_data_declarations']!=8649:raise ValueError('Unexpected static DATA inventory count')
 if catalog.get('mentions_and_fixtures_are_not_full_port_counts')is not True or catalog['reference_source'].get('jjffe_is_identical_to_user_dos_executable')is not False:raise ValueError('Static audit scope declarations missing')
 normalized_doc=re.sub(r'[*_`]','',(project/'docs/PARITY_AUDIT_RU.md').read_text())
 disclaimer=bool(re.search(r'не\s+является\s+100\s*%\s*клоном',normalized_doc))
 if not disclaimer:raise ValueError('Main parity audit does not retain the full-game incompleteness statement')
 report['static_audit_packaging']={'scope':'Presence, file hashes, counts and explicit limitations only; not semantic review or full-game equivalence.','required_files_sha256':audit_files,'function_definitions':len(catalog['functions']),'upstream_source_inventory_entries':len(catalog['upstream_file_inventory']),'data_declarations':len(data_catalog['blocks']),'mentions_are_not_full_port_counts':True,'jjffe_dos_equivalence_claim':False,'full_game_incompleteness_statement_present':disclaimer}
 report.update({'source_project_path':str(project),'archive_file_count':len(files),'archive_crc_ok':True,'archive_source_inventory_sha256':sha(json.dumps(files,sort_keys=True,separators=(',',':')).encode()),'import_cache_before':(project/'.godot').exists(),'project_godot_sha256':sha((project/'project.godot').read_bytes()),'startup_test_sha256':sha((project/'tests/test_source_full_startup.gd').read_bytes()),'main_source_sha256':sha((project/'scripts/main.gd').read_bytes())})
 env=os.environ.copy();private={}
 for suffix,name in [('data','XDG_DATA_HOME'),('config','XDG_CONFIG_HOME'),('cache','XDG_CACHE_HOME')]:
  folder=xdg/suffix;folder.mkdir(parents=True);env[name]=str(folder);private[name]=str(folder)
 report['private_environment_overrides']=private
 report['godot_version']=subprocess.run(['godot','--version'],capture_output=True,text=True,check=True).stdout.strip()
 def run(name,command,timeout=300):
  log=args.report.parent/(name+'.log');begin=utc();clock=time.monotonic()
  try:
   completed=subprocess.run(command,cwd=project,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
   output=completed.stdout;returncode=completed.returncode;timed_out=False
  except subprocess.TimeoutExpired as exc:output=exc.stdout or b'';returncode=None;timed_out=True
  log.write_bytes(output);text=output.decode(errors='replace')
  markers=[line for line in text.splitlines()if re.match(r'^(?:ERROR:|SCRIPT ERROR:)',line)]
  metadata={'name':name,'started_utc':begin,'finished_utc':utc(),'duration_seconds':round(time.monotonic()-clock,6),'command':command,'exit_code':returncode,'timed_out':timed_out,'log_path':str(log),'log_sha256':sha(output),'log_bytes':len(output),'error_markers':markers}
  report['commands'].append(metadata);save_report();return metadata,text
 imported,_=run('source-archive-import',['godot','--headless','--audio-driver','Dummy','--editor','--quit','--path',str(project)])
 if imported['exit_code']==0 and not imported['error_markers']:
  startup,text=run('source-archive-startup',['godot','--headless','--audio-driver','Dummy','--path',str(project),'--script','res://tests/test_source_full_startup.gd','--','--source-startup-isolated'])
  match=re.search(r'SOURCE FULL STARTUP TESTS:\s*(\d+) checks,\s*(\d+) failures',text)
  if match:report['startup_checks']=int(match[1]);report['startup_failures']=int(match[2])
 else:startup=None
 changed=[name for name,digest in files.items()if not(extracted/name).is_file()or sha((extracted/name).read_bytes())!=digest]
 report.update({'import_cache_after':(project/'.godot').exists(),'extracted_archive_files_unchanged':not changed,'modified_archive_files':changed,'finished_utc':utc()})
 report['ok']=bool(imported['exit_code']==0 and not imported['error_markers']and startup is not None and startup['exit_code']==0 and not startup['error_markers']and report.get('startup_checks',0)>0 and report.get('startup_failures')==0 and not changed)
 save_report();print(json.dumps({'ok':report['ok'],'report':str(args.report),'archive_sha256':report['archive_sha256'],'startup_checks':report.get('startup_checks'),'startup_failures':report.get('startup_failures')},ensure_ascii=False));return 0 if report['ok']else 1
if __name__=='__main__':raise SystemExit(main())
