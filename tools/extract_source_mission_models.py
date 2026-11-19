#!/usr/bin/env python3
"""Capture the DOS model catalog and replay only its exact bounded byte spans."""
from __future__ import annotations
import argparse,hashlib,json,re,struct,tempfile
from pathlib import Path
from types import SimpleNamespace
from extract_source_collision_programs import Image,Archived
from extract_source_mission_programs import IDENTITIES

PROJECT=Path(__file__).resolve().parents[1]
PROOF=PROJECT/'validation/mission-tasks-2026-11-19/model-resources'
CAPTURE=PROOF/'original-spans.json'
OUTPUT=PROJECT/'data/ffe_mission_models.json'
NATIVE_PROOF=PROJECT/'validation/mission-tasks-2026-11-19/model-native-proof'
SCHEMA='starfrontier-original-mission-model-resources-v1'
CAPTURE_SCHEMA='starfrontier-original-mission-model-byte-spans-v1'
PROFILE='dos-firstenc-mission-model-catalog-v1'
DRIVE=[0,4,10,25,45,80,150,250,400,600,6,12,24,36,0]
sha=lambda b:hashlib.sha256(b).hexdigest()
def require(value,why):
    if not value:raise ValueError(why)
def encoded(value):return (json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode()
def verify_anchor(meta):
    start=meta['bindings']['DATA_004681'];end=meta['bindings']['DATA_004682']
    require(start==0x4d0cfc and end==0x4d1444 and end-start==466*4,'Actual model/string table boundary differs')
    f1538=bytes.fromhex(meta['procedures']['1538']['hex']);f1345=bytes.fromhex(meta['procedures']['1345']['hex'])
    require(f1538.count(b'\x8b\x04\x85'+struct.pack('<I',start))==1,'F1538 operand does not bind the table start')
    require(f1345.count(b'\xff\x34\x85'+struct.pack('<I',end))==1,'F1345 operand does not bind adjacent string table')
    return start,end
def capture_original(a):
    files=[a.exe,a.asm,a.data,a.mission_asm]
    require([sha(p.read_bytes())for p in files]==list(IDENTITIES.values()),'Pinned original identities differ')
    import rebuild_source_model_replace_native as M
    with tempfile.TemporaryDirectory(prefix='model-boundary-reproof-')as temp:
        meta,_=M.reprove(SimpleNamespace(exe=a.exe,asm=a.asm,data=a.data,proof_dir=Path(temp)))
    start,end=verify_anchor(meta);raw=a.exe.read_bytes();image=Image(raw);spans={}
    def keep(name,va,count):
        b=image.read(va,count);spans[name]={'virtual_address_u32':va,'executable_offset':image.offset(va,count),'bytes':count,'hex':b.hex(),'sha256':sha(b)};return b
    table=keep('model_table',start,end-start);ptrs=struct.unpack('<466I',table)
    keep('drive_mass_table',meta['bindings']['DATA_007210'],60)
    for index,pointer in enumerate(ptrs):
        if not pointer:continue
        desc=keep('descriptor_%03d'%index,pointer,68);collision,physical=struct.unpack_from('<II',desc,52)
        if collision:keep('collision_%03d'%index,collision,1)
        if physical:keep('physical_%03d'%index,physical,24)
    source=a.mission_asm.read_text();table_source=source[source.index('DATA_004681:'):]
    names=[]
    for line in table_source.splitlines()[1:]:
        line=line.split(';')[0].strip()
        if not line:continue
        if line.startswith('db '):
            raw_values=bytes(int(word.strip(),0)for word in line[3:].split(','))
            require(raw_values==bytes(4),'Unsupported numeric model-table row')
            names.append('0');continue
        match=re.fullmatch(r'dd\s+(.+)',line)
        if not match:break
        names.extend(word.strip()for word in match[1].split(','))
    require(len(names)==466 and [i for i,n in enumerate(names)if n=='0']==[149],'Named source model table shape differs')
    boundary={'start_virtual_address_u32':start,'end_virtual_address_u32':end,'model_count':466,'start_anchor_function':1538,'end_anchor_function':1345,'instruction_proof_sha256':sha(encoded(meta)),'anchor_procedures':{str(n):meta['procedures'][str(n)]for n in [1538,1345]},'bindings':{k:meta['bindings'][k]for k in ['DATA_004681','DATA_004682','DATA_007210']},'whole_original_instruction_equality':True}
    return {'schema':CAPTURE_SCHEMA,**IDENTITIES,'model_table_boundary':boundary,'source_model_labels':names,'spans':spans,'scope':'Actual descriptor68, collision first byte, optional physical24 and drive15 only. Geometry/texture/world resources pointed by other descriptor words are not silently claimed.'}
def extract(capture):
    require(capture.get('schema')==CAPTURE_SCHEMA and all(capture.get(k)==v for k,v in IDENTITIES.items()),'Model capture identity differs')
    spans=capture['spans'];boundary=capture['model_table_boundary']
    meta={'bindings':boundary['bindings'],'procedures':boundary['anchor_procedures']};start,end=verify_anchor(meta)
    require(boundary['model_count']==466 and boundary['whole_original_instruction_equality']is True,'Model boundary proof differs')
    image=Archived(capture)
    def get(name,va,count):
        row=spans[name];b=bytes.fromhex(row['hex']);require(row['virtual_address_u32']==va and row['bytes']==len(b)==count and row['sha256']==sha(b),'Invalid captured model span '+name);require(image.read(va,count)==b,'Overlapping model spans disagree');return b
    table=get('model_table',start,end-start);ptrs=list(struct.unpack('<466I',table));drive_raw=get('drive_mass_table',boundary['bindings']['DATA_007210'],60)
    require(list(struct.unpack('<15I',drive_raw))==DRIVE,'Original drive masses differ')
    require([i for i,p in enumerate(ptrs)if not p]==[149]and len(set(ptrs))==466,'Actual model pointers/nulls differ')
    models={};expected={'model_table','drive_mass_table'}
    for index,pointer in enumerate(ptrs):
        if not pointer:continue
        name='descriptor_%03d'%index;expected.add(name);desc=get(name,pointer,68);collision,physical=struct.unpack_from('<II',desc,52)
        first=0;spec=b''
        if collision:
            name='collision_%03d'%index;expected.add(name);first=get(name,collision,1)[0]
        if physical:
            name='physical_%03d'%index;expected.add(name);spec=get(name,physical,24)
            drive=struct.unpack_from('<h',spec,20)[0]
            require(drive>=0 or 0<=struct.unpack_from('<b',spec,20)[0]<15,'Physical default drive is outside source table')
        models[str(index)]={'model_index_u32':index,'original_pointer_u32':pointer,'descriptor_executable_offset':spans['descriptor_%03d'%index]['executable_offset'],'descriptor_hex':desc.hex(),'collision_present':bool(collision),'collision_first_byte_u8':first,'physical_spec_hex':spec.hex()}
    require(set(spans)==expected,'Model capture contains omitted/extra spans')
    require(len(capture['source_model_labels'])==466,'Source named table count differs')
    doc={'schema':SCHEMA,'profile':PROFILE,**IDENTITIES,'model_count':466,'nonnull_model_count':465,'null_model_indices_u32':[149],'descriptor_bytes':68,'physical_spec_bytes':24,'model_table_original_va_u32':start,'adjacent_string_table_original_va_u32':end,'model_table_hex':table.hex(),'drive_mass_table_u32':DRIVE,'drive_mass_table_original_va_u32':boundary['bindings']['DATA_007210'],'models':models,'captured_span_count':len(spans),'captured_bytes':sum(row['bytes']for row in spans.values()),'source_model_labels':capture['source_model_labels'],'full_F36_body_executed_by_resource_extraction':False,'Main_integrated':False,'scope':capture['scope']}
    # Retained catalog models must agree with the rich old resource projections.
    for relative in ['data/ffe_object_factory.json','data/ffe_effect_factory.json']:
        old=json.loads((PROJECT/relative).read_text())
        for key,row in old.get('models',{}).items():
            if key not in models:continue
            for field in ['descriptor_hex','collision_present','collision_first_byte_u8','physical_spec_hex']:
                if field in row:require(models[key][field]==row[field],'Prior model projection changed '+key+'/'+field)
    return doc
def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name,path in [('exe','/workspace/ffe-original/FIRSTENC.EXE'),('asm','/workspace/ffe-upstream/jjffe/ffe.asm'),('data','/workspace/ffe-upstream/jjffe/ffedat.asm'),('mission-asm','/workspace/ffe-upstream/jjffe/ffebmp.asm')]:p.add_argument('--'+name,type=Path,default=Path(path))
    p.add_argument('--capture',type=Path,default=CAPTURE);p.add_argument('--output',type=Path,default=OUTPUT);p.add_argument('--reprove-original',action='store_true');a=p.parse_args()
    capture=capture_original(a)if a.reprove_original else json.loads(a.capture.read_text())
    doc=extract(capture);a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_bytes(encoded(doc))
    if a.reprove_original:a.capture.parent.mkdir(parents=True,exist_ok=True);a.capture.write_bytes(encoded(capture))
    print(json.dumps({'status':'verified','model_count':doc['model_count'],'nonnull_models':len(doc['models']),'spans':doc['captured_span_count'],'bytes':doc['captured_bytes'],'resource_sha256':sha(a.output.read_bytes())},indent=2))
if __name__=='__main__':main()
