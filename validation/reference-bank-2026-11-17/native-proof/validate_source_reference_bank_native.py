#!/usr/bin/env python3
"""Replay the archived integer oracle and compare its complete fixture bytes."""
from __future__ import annotations
import argparse, hashlib, json, subprocess, sys, tempfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def require(condition,message):
    if not condition:raise ValueError(message)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture',type=Path,default=ROOT/'tests/fixtures/source_reference_bank_native.json')
    parser.add_argument('--report',type=Path,default=HERE/'validation.json')
    args=parser.parse_args();before=args.fixture.read_bytes();fixture=json.loads(before)
    proof=HERE/'instruction-proof.json';kernel=HERE/'reference-bank-observed-kernel.s'
    metadata=json.loads(proof.read_text());checks=0
    def check(value,message):
        nonlocal checks
        checks+=1;require(value,message)
    check(sha(proof)==fixture['instruction_proof_sha256'],'Instruction proof hash')
    check(sha(kernel)==fixture['host_assembly_sha256']==metadata['host_assembly_sha256'],'Observed kernel hash')
    check(fixture['case_count']==len(fixture['cases'])==444,'DOS case count')
    check(fixture['diagnostic_case_count']==len(fixture['JJFFE_COPY_boundary_diagnostics'])==16,'Separate boundary count')
    check(fixture['profile']=='dos-firstenc','DOS profile')
    check(metadata['F866_body_executed'] is False and metadata['F148_body_executed'] is False,'Interception scope')
    check(len(metadata['whole_procedure_instruction_equality'])==21 and all(row['all_instructions_equal'] for row in metadata['whole_procedure_instruction_equality'].values()),'Whole procedure original instruction comparison')
    with tempfile.TemporaryDirectory(prefix='reference-bank-verify-') as temporary:
        candidate=Path(temporary)/'fixture.json'
        result=subprocess.run([sys.executable,str(ROOT/'tools/rebuild_source_reference_bank_native.py'),'--output',str(candidate)],capture_output=True,text=True,timeout=180)
        check(result.returncode==0,'Archived native replay: '+result.stderr)
        check(candidate.read_bytes()==before,'Exact native fixture reproduction')
    check(args.fixture.read_bytes()==before,'Input fixture unchanged')
    operations={}
    changed_cache_records=0;future_calls=0
    for row in fixture['cases']:
        operation=row['operation'];operations[operation]=operations.get(operation,0)+1
        check(row['expected_flags_hex']==row['flags_hex'],'Bank flags '+row['name'])
        check(len(bytes.fromhex(row['body_hex']))==len(bytes.fromhex(row['expected_body_hex']))==338,'Player record '+row['name'])
        check(set(row['expected_objects_by_index'])==set(row['objects_by_index']),'Sparse bank keys '+row['name'])
        for index,old_hex in row['objects_by_index'].items():
            old=bytes.fromhex(old_hex);new=bytes.fromhex(row['expected_objects_by_index'][index])
            check(len(new)==len(old)==338,'Bank record '+row['name'])
            changed=[i for i,(a,b) in enumerate(zip(old,new)) if a!=b]
            check(not changed or operation=='select_parent' and all(0x25<=i<0x3e for i in changed),'Only original F1677 cache writes '+row['name'])
            changed_cache_records+=bool(changed)
        if operation=='parent_velocity':
            parent=bytes.fromhex(row['parent_hex'])
            if parent[0x87]==1:check(row['expected_parent_velocity_s32']==[0,0,0],'Original DOS natural parent velocity '+row['name'])
        future_calls+=row['expected_future_copy_calls']
        check(row['expected_copy_calls']==row['expected_future_copy_calls'],'F1533/F866 copy pairing '+row['name'])
        check(row['expected_future_clock'] is not None if row['expected_future_copy_calls'] else row['expected_future_clock'] is None,'Future source clock capture '+row['name'])
    check(changed_cache_records>0 and future_calls>0,'Cache and COPY branches actually exercised')
    check(any(row['expected_parent_velocity_s32']!=[0,0,0] for row in fixture['JJFFE_COPY_boundary_diagnostics']),'COPY load diagnostic differs from DOS natural zero')
    report={'schema':'starfrontier-reference-bank-native-replay-validation-v1','status':'passed','checks':checks,'failures':0,
      'DOS_cases':len(fixture['cases']),'separate_JJFFE_COPY_boundary_diagnostics':len(fixture['JJFFE_COPY_boundary_diagnostics']),
      'operations':operations,'changed_cache_records':changed_cache_records,'future_COPY_callbacks':future_calls,
      'fixture_sha256':sha(args.fixture),'instruction_proof_sha256':sha(proof),'host_assembly_sha256':sha(kernel),
      'fixture_byte_exact':True,'input_fixture_unchanged':True,'F866_body_executed':False,'F148_body_executed':False,
      'scope':'Original instruction arithmetic replay only. Three forward native processes plus reverse460 in each reproduction. F606 cache writes preserved; COPY and event observers explicit. No live Main, physical Android, full F570/F866/event/AI bank or full original clone claim.'}
    args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
if __name__=='__main__':main()
