#!/usr/bin/env python3
"""Rerun exact new frame/caller witnesses and unchanged 0.23 footprint output."""
import hashlib,importlib.util,json,sys,tempfile
from pathlib import Path
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;PROJECT=HERE.parents[2]
spec=importlib.util.spec_from_file_location('native_contact_frame_generator',HERE/'rebuild_source_contact_frame_native.py');M=importlib.util.module_from_spec(spec);spec.loader.exec_module(M)
def sha(raw):return hashlib.sha256(raw).hexdigest()
def main():
 work=Path(tempfile.mkdtemp(prefix='validate-contact-frame-'));M.build_frame(work);M.build_caller(work);fixture_path=PROJECT/'tests/fixtures/source_contact_frame_native.json';raw_fixture=fixture_path.read_bytes();fixture=json.loads(raw_fixture);checks=0;errors=[]
 rows=fixture['frame_cases'];ordered=rows+list(reversed(rows));output=M.execute(work/'frames',b''.join(M.F.packet(row)for row in ordered),M.OUTPUT,len(rows))
 for i,row in enumerate(rows):
  got=M.decode_frame(output[i*M.OUTPUT:(i+1)*M.OUTPUT],row);checks+=1
  if got!=row['expected']:errors.append('frame '+row['id'])
 calls=fixture['caller_cases'];ordered=calls+list(reversed(calls));output=M.execute(work/'caller',b''.join(M.caller_packet(row)for row in ordered),256,len(calls))
 for i,row in enumerate(calls):
  got=M.caller_decode(output[i*256:(i+1)*256]);checks+=1
  if got!=row['expected']:errors.append('caller '+row['id'])
 old=json.loads((PROJECT/'tests/fixtures/source_footprint_native.json').read_text());rows=old['actor_cases']+old['ground_cases'];ordered=rows+list(reversed(rows));output=M.execute(work/'frames',b''.join(M.F.packet(row)for row in ordered),M.OUTPUT,len(rows))
 for i,row in enumerate(rows):
  got=M.F.decode(output[i*M.OUTPUT:i*M.OUTPUT+2048],row);checks+=1
  if got!=row['expected']:errors.append('changed0.23 '+row['id'])
 proofs=json.loads((HERE/'caller-instruction-proofs.json').read_text());report={'schema':1,'checks':checks,'failures':len(errors),'errors':errors,'frame_case_count':len(fixture['frame_cases']),'caller_case_count':len(calls),'unchanged_0_23_footprint_cases':len(rows),'fresh_runs_per_bank':3,'reverse_repeats':True,'static_instruction_procedure_count':len(proofs['byte_instruction_proofs']),'adapted_native_caller_procedure_numbers':proofs['adapted_native_procedure_numbers'],'fixture_sha256':sha(raw_fixture),'generator_sha256':sha((HERE/'rebuild_source_contact_frame_native.py').read_bytes()),'validator_sha256':sha(Path(__file__).read_bytes()),'scope':'Actual observed frame/caller records rerun and unchanged158originalfootprintrecords. F575entryisobserverinterceptiononly; no fullF575pipeline/worldconversion/GPU/liveexecution claim.'};(HERE/'validation.json').write_text(json.dumps(report,indent=2)+'\n');print('NATIVE CONTACT FRAME VALIDATION:',checks,'checks;',len(errors),'failures;old158unchanged')
 if errors:raise SystemExit(1)
if __name__=='__main__':main()
