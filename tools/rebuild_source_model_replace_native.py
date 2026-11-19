#!/usr/bin/env python3
"""Whole DOS F36 model replacement and exact readonly model resources.

Expected body bytes come only from original instructions through the reviewed
ELF64 ABI adapter. This offline proof is never exported into Android.
"""
from __future__ import annotations
import argparse,copy,hashlib,inspect,json,random,re,struct,subprocess,tempfile
from pathlib import Path
import rebuild_source_natural_contact_native as N
import rebuild_source_object_factory_native as F

PROJECT=N.PROJECT
PROOF=PROJECT/'validation/mission-tasks-2026-11-19/model-native-proof'
RESOURCE=PROJECT/'data/ffe_mission_models.json'
FIXTURE=PROJECT/'tests/fixtures/source_model_replace_native.json'
PROFILE='dos-firstenc-model-replacement-v1'
NUMBERS=[36,1538,1495,1341]
PROOF_NUMBERS=NUMBERS+[1345]
INPUT=800;OUTPUT=848
sha=lambda raw:hashlib.sha256(raw).hexdigest()
def require(value,reason):
    if not value:raise ValueError(reason)
def model_resource(doc,index):
    row=doc['models'].get(str(index))
    if row is None:return {}
    return {k:copy.deepcopy(row[k])for k in ['descriptor_hex','collision_present','collision_first_byte_u8','physical_spec_hex']}|{'drive_mass_table_u32':list(doc['drive_mass_table_u32'])}
def source_va(image,offset):
    values=[image.base+rva+offset-at for _,rva,size,at in image.sections if at<=offset<at+size]
    require(len(values)==1,'Ambiguous original code offset');return values[0]
def reprove(a):
    exe=a.exe.read_bytes();assembly=a.asm.read_bytes();data=a.data.read_text()
    require(sha(exe)==N.EXE_SHA and sha(assembly)==N.ASM_SHA,'Original identity differs')
    image=N.G.Image(exe)
    def unique(raw):
        at=exe.find(raw);require(at>=0 and exe.find(raw,at+1)<0,'Original entry anchor is not unique');return source_va(image,at)
    f36=unique(bytes.fromhex('558bec5153568b450c8b5d0889838200000050ff15'))
    f1345=unique(bytes.fromhex('558bec8b450c25ff3f0000ff3485'))
    method=inspect.getsource(N.proof).replace("bind('FUNC_000576',0x427e78)",f"bind('FUNC_000036',{f36})\n bind('FUNC_001345',{f1345})").replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
    namespace=N.__dict__.copy();exec(method,namespace)
    bodies,records,disassembly,_,aliases=namespace['proof'](assembly.decode().replace('\r\n','\n'),data,exe,a.exe,PROOF_NUMBERS)
    for record in records.values():record['hex']=exe[record['executable_offset']:record['executable_offset']+record['byte_length']].hex()
    require(aliases['DATA_004681']==0x4d0cfc and aliases['DATA_004682']==0x4d1444,'Actual model-table boundary differs')
    require((aliases['DATA_004682']-aliases['DATA_004681'])//4==466,'Actual model-table count differs')
    require(image.offset(aliases['DATA_007210'],60)==886300,'Actual drive table binding differs')
    captured='\n'.join(bodies[n]for n in PROOF_NUMBERS)+'\nFUNC_999999:\nret\n'
    meta={'schema':'starfrontier-model-replacement-original-proof-v1','source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'procedures':records,'bindings':aliases,'source_procedures_sha256':sha(captured.encode()),'whole_replacement_procedure_count':4,'whole_replacement_instruction_count':sum(records[str(n)]['instruction_count']for n in NUMBERS),'resource_boundary_anchor_procedure':1345,'all_whole_instructions_equal':True,'original_model_table':{'virtual_address_u32':aliases['DATA_004681'],'end_va_u32':aliases['DATA_004682'],'count':466,'start_binding':'whole F1538 indexed operand','end_binding':'whole F1345 indexed ship-string operand'},'scope':'Whole F36/F1538/F1495/F1341 replacement over one explicit338-byte body and exact descriptor graph; F1345 is an independent resource-boundary anchor only. No source memcpy, clock, allocation, Main integration or full VM.'}
    a.proof_dir.mkdir(parents=True,exist_ok=True)
    (a.proof_dir/'source-procedures.asm').write_text(captured)
    (a.proof_dir/'instruction-proof.json').write_text(json.dumps(meta,indent=2)+'\n')
    (a.proof_dir/'dos-disassembly.txt').write_text('\n'.join(disassembly.values()))
    return meta,captured
def verify(proof):
    meta=json.loads((proof/'instruction-proof.json').read_text());source=(proof/'source-procedures.asm').read_text()
    require(meta['source_executable_sha256']==N.EXE_SHA and meta['source_assembly_sha256']==N.ASM_SHA and sha(source.encode())==meta['source_procedures_sha256'],'Archived replacement proof differs')
    for number in PROOF_NUMBERS:
        row=meta['procedures'][str(number)];raw=bytes.fromhex(row['hex'])
        compiled=N.C.J.instructions(N.C.compile32(N.G.block(source,number),meta['bindings'],'FUNC_%06d'%number,row['virtual_address']))
        require(sha(raw)==row['sha256'] and len(compiled)==row['instruction_count'] and sha('\n'.join(N.canonical(compiled)).encode())==row['normalized_instruction_sha256'],'Archived replacement instruction proof differs F'+str(number))
        with tempfile.TemporaryDirectory(prefix='model-replace-source32-')as directory:
            path=Path(directory)/'source.bin';path.write_bytes(raw)
            original=N.C.J.instructions(subprocess.check_output(['objdump','-D','-b','binary','-m','i386','-Mintel','--no-show-raw-insn','--adjust-vma='+hex(row['virtual_address']),str(path)],text=True))
            require(len(original)==row['instruction_count'] and N.canonical(original)==N.canonical(compiled),'Captured original bytes and reassembly differ F'+str(number))
    return meta,source
def assembly(source):
    selected=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',source)
    lines,_=N.Q.procedures(selected,NUMBERS);text='\n'.join(lines)
    old='FUNC_001495:\npush rbp\nmov rbp,rsp\nadd rsp,-8'
    require(text.count(old)==1,'Original F1495 local frame changed')
    text=text.replace(old,old.replace('rsp,-8','rsp,-16'))
    text=text.replace('FUNC_001538:\n','FUNC_001538:\npushfq\ninc DWORD PTR [lookup_calls]\npopfq\n',1)
    wrapper=F.WRAPPER
    start=wrapper.index(' mov eax,DWORD PTR [input+4]\n push rax\n mov eax,OFFSET FLAT:body')
    end=wrapper.index(' mov eax,DWORD PTR [input+708+0x34]',start)
    wrapper=wrapper[:start]+''' cmp DWORD PTR [input+28],0
 je resource_ready
 mov DWORD PTR [DATA_004681+149*4],0
resource_ready:
 mov eax,DWORD PTR [input+4]
 push rax
 cmp DWORD PTR [input],1
 je lookup_only
 push OFFSET FLAT:body
 call FUNC_000036
 add rsp,16
 mov DWORD PTR [pointer_result],0
 jmp replacement_done
lookup_only:
 call FUNC_001538
 add rsp,8
 test eax,eax
 setnz al
 movzx eax,al
 mov DWORD PTR [pointer_result],eax
replacement_done:
'''+wrapper[end:]
    wrapper=wrapper.replace('mov ecx,149','mov ecx,466').replace('DATA_004681: .zero 596','DATA_004681: .zero 1864')
    wrapper=wrapper.replace(' mov eax,DWORD PTR [copy_calls]\n mov DWORD PTR [output+12],eax',' mov eax,DWORD PTR [pointer_result]\n mov DWORD PTR [output+12],eax')
    wrapper=wrapper.replace('DATA_007734: .quad FUNC_001495','DATA_007734: .quad FUNC_001495\nDATA_007756: .quad FUNC_001538').replace('lookup_calls: .zero 4','lookup_calls: .zero 4\npointer_result: .zero 4')
    return '.intel_syntax noprefix\n.code64\n.section .text\n.global _start\n'+text+'\n'+wrapper
def packet(row):
    resource=row['resource'];null=not resource
    desc=bytes(68)if null else bytes.fromhex(resource['descriptor_hex'])
    physical=b''if null else bytes.fromhex(resource['physical_spec_hex'])
    header=struct.pack('<8I',row['operation']=='F1538',row['model_index_u32'],0,0,False if null else resource['collision_present'],bool(physical),0 if null else resource['collision_first_byte_u8'],null)
    return header+bytes.fromhex(row['before_body_hex'])+bytes.fromhex(row['unused_source_hex'])+desc+physical.ljust(24,b'\0')
def cases(doc):
    rng=random.Random(0x36f1538);rows=[]
    def add(name,index,resource=None,operation='F36'):
        r=model_resource(doc,index)if resource is None else resource
        rows.append({'name':name,'operation':operation,'model_index_u32':index,'resource':copy.deepcopy(r),'before_body_hex':rng.randbytes(338).hex(),'unused_source_hex':rng.randbytes(338).hex()});return rows[-1]
    for index in range(466):
        if index!=149:add('original-model-%03d'%index,index)
    for index in [0,148,149,150,465]:add('original-lookup-%03d'%index,index,operation='F1538')
    for index,scale in enumerate([-32768,-65,-64,-63,-33,-32,-31,-1,0,1,31,32,33,63,64,65,32767]):
        r=model_resource(doc,38);raw=bytearray.fromhex(r['descriptor_hex']);struct.pack_into('<h',raw,20,scale);struct.pack_into('<h',raw,24,0)
        struct.pack_into('<h',raw,44,[-32768,-1,0,32767][index%4]);struct.pack_into('<h',raw,48,[32767,0,-1,-32768][index%4]);r['descriptor_hex']=raw.hex();add('witness-radius-scale-%d'%scale,38,r)
    for scale_a,scale_b in [(32767,32767),(-32768,-32768),(32767,1),(-32768,-1)]:
        r=model_resource(doc,38);raw=bytearray.fromhex(r['descriptor_hex']);struct.pack_into('<hh',raw,20,scale_a,0);struct.pack_into('<h',raw,24,scale_b);r['descriptor_hex']=raw.hex();add('witness-wrapped-scale-%d-%d'%(scale_a,scale_b),38,r)
    for reverse in [-32768,-32767,-4910,-4905,-2725,-2724,-1,0,1,2725,4910,32767]:
        r=model_resource(doc,38);raw=bytearray.fromhex(r['physical_spec_hex']);struct.pack_into('<h',raw,2,reverse);struct.pack_into('<H',raw,6,0xffff);r['physical_spec_hex']=raw.hex();add('witness-physical-reverse-%d'%reverse,38,r)
    for drive in range(15):
        r=model_resource(doc,38);raw=bytearray.fromhex(r['physical_spec_hex']);struct.pack_into('<H',raw,20,0x8000|drive);r['physical_spec_hex']=raw.hex();add('witness-drive-%d'%drive,38,r)
    for collision in [None,0,1,255]:
        for physical in [False,True]:
            r=model_resource(doc,38);raw=bytearray.fromhex(r['descriptor_hex']);struct.pack_into('<I',raw,52,0 if collision is None else 1);struct.pack_into('<I',raw,56,1 if physical else 0)
            r.update(descriptor_hex=raw.hex(),collision_present=collision is not None,collision_first_byte_u8=collision or 0,physical_spec_hex=r['physical_spec_hex']if physical else'');add('witness-null-references-%s-%s'%(collision,physical),38,r)
    for kind in [0,1,2,3,15,127,128,255]:
        row=add('witness-preserved-type-%d'%kind,38);raw=bytearray.fromhex(row['before_body_hex']);raw[0x87]=kind;row['before_body_hex']=raw.hex()
    return rows
def run(binary,payload):
    result=subprocess.run([str(binary)],input=payload,capture_output=True,check=True,timeout=60)
    require(not result.stderr and len(result.stdout)==len(payload)//INPUT*OUTPUT,'Native replacement transport differs');return result.stdout
def generate(a,meta,source):
    doc=json.loads(RESOURCE.read_text());require(doc['schema']=='starfrontier-original-mission-model-resources-v1'and doc['model_count']==466,'Model catalog differs')
    native=assembly(source);rows=cases(doc)
    with tempfile.TemporaryDirectory(prefix='model-replacement-native-')as temp:
        work=Path(temp);(work/'native.s').write_text(native)
        subprocess.run(['as','--64','-o',str(work/'native.o'),str(work/'native.s')],check=True);subprocess.run(['ld','-o',str(work/'native'),str(work/'native.o')],check=True)
        prior=rows[38]
        for step in range(32):
            model=[38,0,112,153,155,117,465,24][step%8];row={'name':'dependent-replacement-%02d'%step,'operation':'F36','model_index_u32':model,'resource':model_resource(doc,model),'before_body_hex':prior['before_body_hex'],'unused_source_hex':prior['unused_source_hex']}
            if step:row['before_body_hex']=actual[16:354].hex()
            actual=run(work/'native',packet(row));rows.append(row);prior=row
        payload=b''.join(packet(row)for row in rows);runs=[run(work/'native',payload)for _ in range(3)]
        require(runs[0]==runs[1]==runs[2],'Fresh native process outputs differ')
        reverse=run(work/'native',b''.join(packet(row)for row in reversed(rows)))
        require(reverse==b''.join(runs[0][i*OUTPUT:(i+1)*OUTPUT]for i in reversed(range(len(rows)))),'Native replacement order leakage')
        for index,row in enumerate(rows):
            raw=runs[0][index*OUTPUT:(index+1)*OUTPUT];header=struct.unpack_from('<4I',raw)
            require(header[0]==0x1533fac7 and header[1]==0 and header[2]==1 and raw[-64:]==b'\xa5'*64,'Native replacement canary/call count differs')
            require(raw[354:692].hex()==row['unused_source_hex'],'Unused source witness changed')
            resource=row['resource'];desc=bytes(68)if not resource else bytes.fromhex(resource['descriptor_hex']);physical=b''if not resource else bytes.fromhex(resource['physical_spec_hex'])
            require(raw[692:760]==desc and raw[760:784]==physical.ljust(24,b'\0'),'Readonly replacement resource changed')
            row['expected_body_hex']=raw[16:354].hex();row['lookup_calls']=header[2];row['pointer_return_defined']=row['operation']=='F1538';row['pointer_is_nonnull']=bool(header[3])if row['operation']=='F1538'else False
        fault_row={'name':'original-model149-null-dereference','operation':'F36','model_index_u32':149,'resource':{},'before_body_hex':bytes(338).hex(),'unused_source_hex':bytes(338).hex()}
        fault=subprocess.run([str(work/'native')],input=packet(fault_row),capture_output=True,timeout=30)
        require(fault.returncode==-11 and not fault.stdout,'Original F36 NULL-model domain did not fault at the actual dereference')
    dependencies={n:sha((PROJECT/n).read_bytes())for n in ['tools/rebuild_source_model_replace_native.py','tools/rebuild_source_object_factory_native.py','tools/rebuild_source_natural_contact_native.py','data/ffe_mission_models.json']}
    fixture={'schema':'starfrontier-model-replacement-native-v1','profile':PROFILE,'source_executable_sha256':N.EXE_SHA,'source_assembly_sha256':N.ASM_SHA,'source_instruction_proof_sha256':sha((a.proof_dir/'instruction-proof.json').read_bytes()),'source_dependencies_sha256':dependencies,'case_count':len(rows),'original_model_count':465,'null_model_index_u32':149,'native_fault_domains_separate':[{'name':fault_row['name'],'operation':'F36','model_index_u32':149,'actual_native_signal':'SIGSEGV','normal_case_count_includes_fault':False,'after_body_claimed':False}],'fresh_process_runs':3,'reverse_repeat_cases':len(rows),'dependent_original_replacements':32,'input_packets_sha256':sha(payload),'native_output_sha256':sha(runs[0]),'host_adapted_assembly_sha256':sha(native.encode()),'expected_arithmetic_calculated_in_python':False,'F36_void_EAX_ignored':True,'cases':rows,'scope':meta['scope']}
    a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(fixture,indent=2)+'\n');(a.proof_dir/'model-replace-native.s').write_text(native)
    print(json.dumps({'status':'verified','case_count':len(rows),'fixture_sha256':sha(a.output.read_bytes())},indent=2))
def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name,default in [('exe','/workspace/ffe-original/FIRSTENC.EXE'),('asm','/workspace/ffe-upstream/jjffe/ffe.asm'),('data','/workspace/ffe-upstream/jjffe/ffedat.asm'),('mission-asm','/workspace/ffe-upstream/jjffe/ffebmp.asm')]:p.add_argument('--'+name,type=Path,default=Path(default))
    p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--reprove-original',action='store_true');a=p.parse_args()
    meta,source=reprove(a)if a.reprove_original else verify(a.proof_dir);generate(a,meta,source)
if __name__=='__main__':main()
