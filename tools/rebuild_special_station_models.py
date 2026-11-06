#!/usr/bin/env python3
"""Extract exact original special orbital port69 closure into a new resource."""
from __future__ import annotations
import argparse,hashlib,importlib.util,json,sys,types
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
EXPECTED='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--output',type=Path,default=PROJECT/'data/ffe_special_station_models.json')
    args=parser.parse_args();raw=args.executable.read_bytes()
    if hashlib.sha256(raw).hexdigest()!=EXPECTED:raise ValueError('Unreviewed original EXE')
    guard=types.ModuleType('extract_galaxy');guard.EXPECTED=EXPECTED;sys.modules['extract_galaxy']=guard
    folder=PROJECT/'recovered-history/ground_harness/tools';sys.path.insert(0,str(folder))
    spec=importlib.util.spec_from_file_location('original_special_station_assets',folder/'extract_world_models.py')
    extractor=importlib.util.module_from_spec(spec);spec.loader.exec_module(extractor)
    result=json.loads(json.dumps(extractor.extract(args.executable,[69])))
    base=json.loads((PROJECT/'data/ffe_world_models.json').read_bytes())['models']
    for key,row in result['models'].items():
        if key in base and row!=base[key]:raise ValueError('Existing source model differs: '+key)
    result['revision']='special-station-model-assets-v1'
    result['new_model_indices']=sorted(int(key) for key in result['models'] if key not in base)
    result['scope']='Actual original F892 kind3 special orbital root69 and reachable model resources; separate append-only lookup. Docking geometry/collision and source model execution are independently assessed, not fabricated by extraction.'
    result['extractor_source_sha256']=hashlib.sha256((folder/'extract_world_models.py').read_bytes()).hexdigest()
    args.output.write_text(json.dumps(result,separators=(',',':'))+'\n')
    print('SPECIAL SOURCE PORT69:',len(result['models']),'models;',result['new_model_indices'],'new keys')
if __name__=='__main__':main()
