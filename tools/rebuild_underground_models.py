#!/usr/bin/env python3
"""Extract original model96 and its reachable geometry without editing base assets."""
from __future__ import annotations
import argparse,hashlib,importlib.util,json,sys,types
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
EXPECTED='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'

def extract(executable:Path)->dict:
    original=executable.read_bytes()
    if hashlib.sha256(original).hexdigest()!=EXPECTED:raise ValueError('Unreviewed original EXE')
    # The preserved extractor imports only a fixed digest from its missing
    # galaxy module. No galaxy implementation or geometry result is supplied.
    guard=types.ModuleType('extract_galaxy');guard.EXPECTED=EXPECTED
    sys.modules['extract_galaxy']=guard
    folder=PROJECT/'recovered-history/ground_harness/tools'
    sys.path.insert(0,str(folder))
    spec=importlib.util.spec_from_file_location('original_underground_assets',folder/'extract_world_models.py')
    source=importlib.util.module_from_spec(spec);spec.loader.exec_module(source)
    # Compare the same JSON representation (opcode histogram keys become text).
    result=json.loads(json.dumps(source.extract(executable,[96])))
    base=json.loads((PROJECT/'data/ffe_world_models.json').read_bytes())['models']
    for key,row in result['models'].items():
        if key in base and row!=base[key]:raise ValueError('Existing source model differs: '+key)
    result['revision']='underground-model-assets-v1'
    result['new_model_indices']=sorted(int(key) for key in result['models'] if key not in base)
    result['base_models_source_sha256']=EXPECTED
    result['scope']='Actual model96 and its reachable source model records. Separate append-only lookup fallback; no guessed landing pad or fabricated cave geometry.'
    result['extractor_source_sha256']=hashlib.sha256((folder/'extract_world_models.py').read_bytes()).hexdigest()
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--output',type=Path,default=PROJECT/'data/ffe_underground_models.json')
    args=parser.parse_args();result=extract(args.executable)
    args.output.write_text(json.dumps(result,separators=(',',':'))+'\n')
    print('Original underground geometry:',len(result['models']),'models;',result['new_model_indices'],'new keys, all existing model bytes unchanged')

if __name__=='__main__':main()
