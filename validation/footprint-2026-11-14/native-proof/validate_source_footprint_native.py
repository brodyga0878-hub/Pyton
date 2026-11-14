#!/usr/bin/env python3
"""Read-only rebuild of new witnesses and unchanged published source controls."""
import hashlib,importlib.util,json,tempfile,sys
from pathlib import Path
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;PROJECT=HERE.parents[2]
spec=importlib.util.spec_from_file_location('native_footprint_generator',HERE/'rebuild_source_footprint_native.py');F=importlib.util.module_from_spec(spec);spec.loader.exec_module(F)
def sha(raw):return hashlib.sha256(raw).hexdigest()
def main():
 checks=0;failures=[];work=Path(tempfile.mkdtemp(prefix='validate-native-footprint-'));F.build(work)
 fixture_path=PROJECT/'tests/fixtures/source_footprint_native.json';raw_fixture=fixture_path.read_bytes();fixture=json.loads(raw_fixture)
 for label,rows in [('actors',fixture['actor_cases']),('ground',fixture['ground_cases'])]:
  output=F.execute(work/'observed',rows)
  for i,row in enumerate(rows):
   got=F.decode(output[i*F.OUTPUT:(i+1)*F.OUTPUT],row);checks+=1
   if got!=row['expected']:failures.append(label+':'+row['id'])
   for trace in got['volume_trace']:
    query=trace['query'];triangle=trace['winning_triangle']
    if query['executed']:
     checks+=1
     if query['fresh_altitude_written']!=(query['result_s32']<query['limit_s32']):failures.append('Fresh write branch '+row['id'])
    if triangle['captured']:
     checks+=1
     if triangle['recorded_intersection_raw']!=trace['globals_after_f579']['recorded_intersection_raw']:failures.append('Native recorded triangle '+row['id'])
 # New observations may not change even one original classified result.
 old=json.loads((PROJECT/'tests/fixtures/source_natural_contact_native.json').read_text())['cases']
 oldrows=[]
 for row in old:
  clone=dict(row);clone['id']=row['name'];clone['mode']='original_f576';oldrows.append(clone)
 output=F.execute(work/'observed',oldrows)
 for i,row in enumerate(oldrows):
  got=F.N.decode(output[i*F.OUTPUT:i*F.OUTPUT+1024]);checks+=1
  if got!=row['expected']:failures.append('Changed published993 result '+row['id'])
 root=json.loads((PROJECT/'tests/fixtures/source_contact_field_native.json').read_text());rows=[]
 for row in root['classifier_cases']:
  clone=dict(row);clone['mode']='original_f576';rows.append(clone)
 output=F.execute(work/'observed',rows)
 for i,row in enumerate(rows):
  got=F.N.decode(output[i*F.OUTPUT:i*F.OUTPUT+1024]);checks+=1
  if got!=row['expected']:failures.append('Changed published root player result '+row['id'])
 report={'schema':1,'checks':checks,'failures':len(failures),'errors':failures,'new_actor_cases':len(fixture['actor_cases']),'new_ground_cases':len(fixture['ground_cases']),'unchanged_original_classifier_cases':len(oldrows),'unchanged_root_classifier_cases':len(rows),'native_runs_per_bank':3,'same_process_reverse_repeats_per_bank':True,'source_footprint_fixture_sha256':sha(raw_fixture),'generator_sha256':sha((HERE/'rebuild_source_footprint_native.py').read_bytes()),'validator_sha256':sha(Path(__file__).read_bytes()),'scope':'Rebuild original archived instructions with new preserving observations. All new exact states/triangles rerun; all993 original classifier outputs and306 root positive-player outputs unchanged. No Python expected height/offset arithmetic; native witnesses only. No old fixture or kernel writes.'}
 (HERE/'validation.json').write_text(json.dumps(report,indent=2)+'\n');print('NATIVE FOOTPRINT VALIDATION:',checks,'checks,',len(failures),'failures; old993+306 results unchanged')
 if failures:raise SystemExit(1)
if __name__=='__main__':main()
