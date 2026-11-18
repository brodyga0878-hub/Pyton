#!/usr/bin/env python3
"""Original F1533 initialization for the captured cargo153/explosion155 models.

Only those two additional table entries are admitted. Slot149 is proven null;
the largest selected index is not claimed to be the full original inventory.
Expected records are produced only by the original DOS-checked instructions.
"""
from __future__ import annotations
import argparse,hashlib,importlib.util,json,random,struct,subprocess,tempfile
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
PROOF=PROJECT/'validation/equipment-effects-2026-11-18/factory-native-proof'
DATA=PROJECT/'data/ffe_effect_factory.json'
FIXTURE=PROJECT/'tests/fixtures/source_effect_factory_native.json'
PROFILE='dos-firstenc-effect-factory-v1'
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
BASE_PROOF=PROJECT/'validation/player-dispatch-2026-11-17/factory-native-proof'
SELECTED=(153,155);TABLE_AT=0xba8fc

def sha(raw):return hashlib.sha256(raw).hexdigest()
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
F=load('effect_factory_original',PROJECT/'tools/rebuild_source_object_factory_native.py')

def require(value,message):
    if not value:raise ValueError(message)

def image_offset(raw,pointer,length):
    pe=struct.unpack_from('<I',raw,60)[0];base=struct.unpack_from('<I',raw,pe+52)[0]
    start=pe+24+struct.unpack_from('<H',raw,pe+20)[0]
    for i in range(struct.unpack_from('<H',raw,pe+6)[0]):
        _,address,size,offset=struct.unpack_from('<4I',raw,start+i*40+8);delta=pointer-base-address
        if 0<=delta and delta+length<=size and offset+delta+length<=len(raw):return offset+delta
    raise ValueError('Unmapped original effect resource '+hex(pointer))

def capture_resources(exe):
    require(sha(exe)==EXE_SHA,'Unreviewed original executable')
    spans=[];bindings={}
    def take(role,at,count):
        raw=exe[at:at+count];require(len(raw)==count,'Truncated original resource')
        spans.append({'role':role,'file_offset':at,'byte_count':count,'hex':raw.hex(),'sha256':sha(raw)})
        return raw
    take('null-model149-slot',TABLE_AT+149*4,4)
    require(struct.unpack_from('<I',exe,TABLE_AT+149*4)[0]==0,'Original slot149 is not null')
    old=json.loads((PROJECT/'data/ffe_object_factory.json').read_text())
    drive_at=old['drive_mass_table_original_file_offset'];take('drive-mass-table15',drive_at,60)
    for index in SELECTED:
        pointer=struct.unpack('<I',take(f'model{index}-slot',TABLE_AT+index*4,4))[0]
        at=image_offset(exe,pointer,68);desc=take(f'model{index}-descriptor',at,68)
        collision,physical=struct.unpack_from('<II',desc,0x34)
        bindings[str(index)]={'table_slot_file_offset':TABLE_AT+index*4,'descriptor_pointer_u32':pointer,'descriptor_file_offset':at}
        if collision:take(f'model{index}-collision-first-byte',image_offset(exe,collision,1),1)
        if physical:take(f'model{index}-physical24',image_offset(exe,physical,24),24)
    return {'schema':'starfrontier-effect-factory-original-spans-v1','source_executable_sha256':EXE_SHA,'selected_model_indices':list(SELECTED),'model_bindings':bindings,'spans':spans,'scope':'Exact selected model-table bindings, descriptors, physical records, collision first bytes and drive masses. This is not the full original model inventory.'}

def resources_from_capture(capture):
    require(capture['source_executable_sha256']==EXE_SHA and capture['selected_model_indices']==list(SELECTED),'Resource capture identity differs')
    rows={}
    for row in capture['spans']:
        raw=bytes.fromhex(row['hex']);require(len(raw)==row['byte_count']and sha(raw)==row['sha256'],'Original resource span differs')
        require(row['role']not in rows,'Duplicate resource span');rows[row['role']]=raw
    require(rows['null-model149-slot']==bytes(4),'Original null slot changed')
    drive=list(struct.unpack('<15I',rows['drive-mass-table15']))
    models={}
    for index in SELECTED:
        desc=rows[f'model{index}-descriptor'];collision,physical=struct.unpack_from('<II',desc,0x34)
        require(len(desc)==68 and struct.unpack('<I',rows[f'model{index}-slot'])[0]==capture['model_bindings'][str(index)]['descriptor_pointer_u32'],'Original descriptor binding differs')
        models[str(index)]={'descriptor_hex':desc.hex(),'collision_present':bool(collision),'collision_first_byte_u8':rows[f'model{index}-collision-first-byte'][0]if collision else 0,'physical_spec_hex':rows[f'model{index}-physical24'].hex()if physical else'','drive_mass_table_u32':drive}
    return {'schema':'starfrontier-effect-factory-resources-v1','profile':PROFILE,'source_executable_sha256':EXE_SHA,'selected_model_indices':list(SELECTED),'selected_model_count':len(SELECTED),'null_model_indices':[149],'descriptor_bytes':68,'physical_spec_bytes':24,'models':models,'model_bindings':capture['model_bindings'],'original_spans_sha256':sha((json.dumps(capture,indent=2)+'\n').encode()),'scope':'Only original model153 cargo and155 explosion supplement the unchanged0..148 factory catalog. Slot149 is null. No maximum table count or full effects renderer is inferred.'}

def verify_token_use(captured):
    prefix=captured.split('FUNC_001533:',1)[1].split('mov esi,eax',1)[0]
    uses=[line.split(';',1)[0].strip()for line in prefix.splitlines()if 'esi'in line.split(';',1)[0]]
    expected=['push esi','mov esi,[ebp+0x10]','test esi,esi','test esi,esi','mov [ebx+0x82],esi','push esi']
    require(uses==expected,'F1533 model-token use no longer supports the reviewed parametric adapter')
    return uses

def verify(proof=PROOF):
    info=json.loads((proof/'instruction-proof.json').read_text());captured=(proof/'source-procedures.asm').read_text()
    require(sha(captured.encode())==info['source_procedures_sha256'],'Captured procedures changed')
    require(verify_token_use(captured)==info['model_token_uses_before_descriptor_lookup'],'Model-token proof differs')
    F.verify_archived_instructions(info,captured)
    capture=json.loads((proof/'resource-spans.json').read_text());resources=resources_from_capture(capture)
    raw=(json.dumps(resources,indent=2)+'\n').encode();require(sha(raw)==info['resources_sha256']and raw==DATA.read_bytes(),'Resource replay differs')
    return info,captured,resources

def assembly(captured):
    text=F.assembly(captured)
    require(text.count('mov ecx,149')==1 and text.count('DATA_004681: .zero 596')==1,'Original reviewed host table layout changed')
    return text.replace('mov ecx,149','mov ecx,156').replace('DATA_004681: .zero 596','DATA_004681: .zero 624')

def cases(resources):
    rng=random.Random(0xe1533155);rows=[]
    old=json.loads((PROJECT/'data/ffe_object_factory.json').read_text())['models']
    def add(name,index,copy,slot=1,kind=None,tick=None,day=None):
        body=bytearray(rng.randbytes(338));source=bytearray(rng.randbytes(338));body[0x86]=slot
        if kind is not None:body[0x87]=kind;source[0x87]=kind
        rows.append({'name':name,'copy_source':copy,'model_index_u32':index,'clock':{'tick_u32':rng.choice([0,1,0xffffffff,0x80000000])if tick is None else tick,'day_u32':rng.choice([0,1,0xffffffff])if day is None else day},'before_body_hex':body.hex(),'source_body_hex':source.hex(),'resources':json.loads(json.dumps(resources['models'].get(str(index),old.get(str(index)))))})
    for index in SELECTED:
        for copy in [False,True]:
            for slot in [0,1,114,127,128,255]:add(f'original-model{index}-copy{int(copy)}-slot{slot}',index,copy,slot)
            for tick in [0,1,0x80000000,0xffffffff]:
                for day in [0,0x121cf7,0xffffffff]:add(f'original-model{index}-copy{int(copy)}-clock{tick}-{day}',index,copy,tick=tick,day=day)
        for kind in range(256):add(f'original-model{index}-type87-{kind:03d}',index,bool(kind&1),kind=kind)
    for index in [0,1,38,148]:
        for copy in [False,True]:add(f'preserved-base-model{index}-copy{int(copy)}',index,copy)
    return rows

def packet(row):return F.packet(row)
def decode(raw,row):
    magic,error,lookup,copied=struct.unpack_from('<4I',raw)
    require(magic==0x1533fac7 and error==0 and raw[-64:]==b'\xa5'*64,'Native record/canary failure')
    require(raw[354:692]==bytes.fromhex(row['source_body_hex'])and raw[692:760]==bytes.fromhex(row['resources']['descriptor_hex'])and raw[760:784]==bytes.fromhex(row['resources']['physical_spec_hex']).ljust(24,b'\0'),'Source or resource bytes changed')
    return {'expected_body_hex':raw[16:354].hex(),'expected_source_body_hex':raw[354:692].hex(),'copy_calls':copied,'lookup_calls':lookup}

def generate(info,captured,resources,output,proof):
    native=assembly(captured);rows=cases(resources)
    with tempfile.TemporaryDirectory(prefix='effect-factory-native-')as temp:
        p=Path(temp);(p/'factory.s').write_text(native);subprocess.run(['as','--64','-o',str(p/'factory.o'),str(p/'factory.s')],check=True);subprocess.run(['ld','-o',str(p/'factory'),str(p/'factory.o')],check=True)
        def run(raw):
            result=subprocess.run([str(p/'factory')],input=raw,capture_output=True,check=True,timeout=60)
            require(not result.stderr and len(result.stdout)==len(raw)//F.INPUT*F.OUTPUT,'Native transport differs');return result.stdout
        prior=rows[0].copy();seed=decode(run(packet(prior)),prior);prior['before_body_hex']=seed['expected_body_hex'];prior['source_body_hex']=seed['expected_body_hex']
        for index in range(24):
            row=json.loads(json.dumps(prior));model=(153,155,0,38)[index%4];row.update(name=f'consecutive-original-{index:02d}',model_index_u32=model,copy_source=bool(index&1));row['resources']=json.loads(json.dumps(resources['models'].get(str(model),json.loads((PROJECT/'data/ffe_object_factory.json').read_text())['models'].get(str(model)))))
            measured=decode(run(packet(row)),row);row['input_provenance']='previous complete native output';rows.append(row);prior=row.copy();prior['before_body_hex']=measured['expected_body_hex'];prior['source_body_hex']=measured['expected_body_hex']
        payload=b''.join(packet(row)for row in rows);runs=[run(payload)for _ in range(3)];require(len(set(runs))==1,'Fresh native process differs')
        reverse=run(b''.join(packet(row)for row in reversed(rows)));require(reverse==b''.join(runs[0][i*F.OUTPUT:(i+1)*F.OUTPUT]for i in reversed(range(len(rows)))),'Native execution order leaks')
        for i,row in enumerate(rows):row.update(decode(runs[0][i*F.OUTPUT:(i+1)*F.OUTPUT],row))
    dependencies={n:sha((PROJECT/n).read_bytes())for n in ['tools/rebuild_source_effect_factory_native.py','tools/rebuild_source_object_factory_native.py','tools/rebuild_source_natural_contact_native.py','recovered-history/ground_harness/tools/native_reference.py','data/ffe_object_factory.json','data/ffe_effect_factory.json']}
    fixture={'schema':'starfrontier-effect-factory-native-v1','profile':PROFILE,'case_count':len(rows),'selected_real_model_indices':list(SELECTED),'null_model_indices':[149],'source_executable_sha256':EXE_SHA,'instruction_proof_sha256':sha((proof/'instruction-proof.json').read_bytes()),'resources_sha256':sha(DATA.read_bytes()),'source_procedures_sha256':sha(captured.encode()),'host_adapted_assembly_sha256':sha(native.encode()),'fresh_process_runs':3,'reverse_repeat_cases':len(rows),'consecutive_original_steps':24,'all_type87_values_per_selected_model':256,'source_dependencies_sha256':dependencies,'all_readonly_inputs_and_canaries_unchanged':True,'expected_arithmetic_calculated_in_python':False,'native_output_sha256':sha(runs[0]),'scope':'Whole original F1533/F1538/F1495/F1341 with captured additional models153/155, strict null149, original body/source identity and clocks. No slot allocation, explosion/debris orchestration, renderer or Main claim.','cases':rows}
    output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(fixture,indent=2)+'\n');(proof/'factory-native.s').write_text(native)
    print(json.dumps({'case_count':len(rows),'fixture_sha256':sha(output.read_bytes()),'resources_sha256':sha(DATA.read_bytes())}))

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--reprove-original',action='store_true');args=p.parse_args();proof=args.proof_dir
    if args.reprove_original:
        exe=args.exe.read_bytes();capture=capture_resources(exe);resources=resources_from_capture(capture);proof.mkdir(parents=True,exist_ok=True)
        captured=(BASE_PROOF/'source-procedures.s').read_text();base=json.loads((BASE_PROOF/'instruction-proof.json').read_text())
        require(sha(exe)==base['source_executable_sha256']and sha(args.asm.read_bytes())==base['source_assembly_sha256'],'Original executable/assembly identity differs')
        for row in base['procedures'].values():require(exe[row['executable_offset']:row['executable_offset']+row['byte_length']].hex()==row['hex'],'Current executable procedure differs')
        (proof/'resource-spans.json').write_text(json.dumps(capture,indent=2)+'\n');DATA.write_text(json.dumps(resources,indent=2)+'\n')
        info=base.copy();info['schema']='starfrontier-effect-factory-instruction-proof-v1';info['resources_sha256']=sha(DATA.read_bytes());info['model_token_uses_before_descriptor_lookup']=verify_token_use(captured);info['additional_model_table_entries']=list(SELECTED);info['source_model149_pointer_u32']=0;info['host_adaptations']=base['host_adaptations']+['Host provided-resource pointer table grows149→156 slots solely to admit captured sourceindices153/155.','Nonzero model token influences only zero gate, descriptor selection and body+82 before descriptor pointer replacesESI; reviewed runtime adapter usesexactresource and restoresactual body+82.'];(proof/'instruction-proof.json').write_text(json.dumps(info,indent=2)+'\n');(proof/'source-procedures.asm').write_text(captured);(proof/'dos-disassembly.txt').write_bytes((BASE_PROOF/'dos-disassembly.txt').read_bytes())
    info,captured,resources=verify(proof);generate(info,captured,resources,args.output,proof)

if __name__=='__main__':main()
