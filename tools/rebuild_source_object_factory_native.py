#!/usr/bin/env python3
"""Independent whole DOS F1533 raw object initialization controls.

Default replay needs only the included DOS-checked procedure/resource captures.
The original file is used only with --refresh-original-proof. Expected object
bytes come from original instructions through the reviewed host ABI adapter.
"""
from __future__ import annotations
import argparse, hashlib, importlib.util, inspect, json, random, re, struct, subprocess, tempfile
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
PROOF=PROJECT/'validation/player-dispatch-2026-11-17/factory-native-proof'
DATA=PROJECT/'data/ffe_object_factory.json'
FIXTURE=PROJECT/'tests/fixtures/source_object_factory_native.json'
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
PROFILE='dos-firstenc-raw-object-factory-v1'
NUMBERS=[1533,1538,1495,1341]
OBJECT=338;INPUT=800;OUTPUT=848
def sha(raw):return hashlib.sha256(raw).hexdigest()
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def packed_resource(exe,image,index,entry,drive):
    at=int(entry['descriptor_executable_offset']);desc=exe[at:at+68]
    table_pointer=struct.unpack_from('<I',exe,0xba8fc+index*4)[0]
    if table_pointer!=entry['original_pointer_u32'] or image.offset(table_pointer,68)!=at:raise ValueError('Original model table binding differs')
    if desc.hex()!=entry['descriptor_hex']:raise ValueError('Real descriptor differs')
    collision,physical=struct.unpack_from('<II',desc,0x34)
    spec=exe[image.offset(physical,24):image.offset(physical,24)+24] if physical else b''
    first=exe[image.offset(collision,1)] if collision else 0
    if spec and struct.unpack_from('<h',spec,20)[0]<0 and not 0<=struct.unpack_from('<b',spec,20)[0]<15:raise ValueError('Physical default drive leaves original table')
    return {'descriptor_hex':desc.hex(),'collision_present':bool(collision),'collision_first_byte_u8':first,'physical_spec_hex':spec.hex(),'drive_mass_table_u32':drive}
def prepare(args):
    N=load('object_factory_original',PROJECT/'tools/rebuild_source_natural_contact_native.py')
    exe=args.exe.read_bytes();raw=args.asm.read_bytes()
    if sha(exe)!=EXE_SHA or sha(raw)!=ASM_SHA:raise ValueError('Pinned original differs')
    source=raw.decode().replace('\r\n','\n');data=args.data.read_text()
    signature=bytes.fromhex('558bec515356578b75108b450c8b5d080fb6bb86000000')
    if exe.find(signature)!=0x44538 or exe.find(signature,0x44539)>=0:raise ValueError('Original F1533 entry not unique')
    resolver=inspect.getsource(N.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_001533',0x453738)")
    resolver=resolver.replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
    namespace=N.__dict__.copy();exec(resolver,namespace)
    bodies,records,dis,_,aliases=namespace['proof'](source,data,exe,args.exe,NUMBERS)
    image=N.G.Image(exe)
    drive_at=image.offset(aliases['DATA_007210'],60);drive_raw=exe[drive_at:drive_at+60]
    drive=list(struct.unpack('<15I',drive_raw))
    if drive!=[0,4,10,25,45,80,150,250,400,600,6,12,24,36,0]:raise ValueError('Original drive masses changed')
    descriptor_resource=PROJECT/'data/ffe_runtime_model_descriptors.json'
    if sha(descriptor_resource.read_bytes())!='cf9c673c2bba22f0c865e77e3a7ceed5497053cdb444b80f31d7439176446818':raise ValueError('Pinned descriptor resource changed')
    models=json.loads(descriptor_resource.read_text())
    if models['source_sha256']!=EXE_SHA or len(models['models'])!=149:raise ValueError('Unreviewed model descriptor inventory')
    resources={str(i):packed_resource(exe,image,i,models['models'][str(i)],drive) for i in range(149)}
    doc={'schema':'starfrontier-source-object-factory-resources-v1','profile':PROFILE,'source_executable_sha256':EXE_SHA,'model_count':149,
         'descriptor_bytes':68,'physical_spec_bytes':24,'drive_mass_table_hex':drive_raw.hex(),'drive_mass_table_original_file_offset':drive_at,
         'models':resources,'scope':'Pinned complete model descriptors, collision first-byte/null branch, 24-byte physical specifications and original15-entry drive masses. Historical pointer words are opaque references, never host addresses. F1533 copies a supplied raw template and does not allocate a player, set type87 or invent a pose.'}
    DATA.write_text(json.dumps(doc,indent=2)+'\n')
    captured='\n'.join(bodies[n] for n in NUMBERS)
    PROOF.mkdir(parents=True,exist_ok=True)
    bindings={re.sub(r'(FUNC_\d+)_\w+',r'\1',k):v for k,v in aliases.items()}
    for k,r in records.items():
        at=r['executable_offset'];r['hex']=exe[at:at+r['byte_length']].hex()
    info={'schema':'starfrontier-object-factory-original-proof-v1','source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,
          'source_procedure_sha256':{str(n):sha(bodies[n].encode()) for n in NUMBERS},'procedures':records,'original_symbol_bindings':bindings,
          'source_procedures_sha256':sha(captured.encode()),'resources_sha256':sha(DATA.read_bytes()),'full_original_instruction_equality':True,
          'host_adaptations':['Reviewed original cdecl32 stack/register plumbing expanded to64-bit; original32-bit object arithmetic retained.',
             'F1495 scratch reservation8→16 for two host epilogue pops; source32-bit scratch offsets unchanged.',
             'Model pointer table retains32-bit low-address entries; indirect function call pointer widened only for host.',
             'F1538 entry lookup observer saves/restores flags around a counter; original procedure body is unchanged.',
             'Original memcpy boundary copies338bytes and returns destination; numeric expected state is never computed in Python.'],
          'scope':'Whole original F1533/F1538/F1495/F1341 model/copy/physical-spec initialization, explicit raw caller template and clocks. No bank allocation F928/F1531, original player creation, SI pose reconstruction or live Main integration.'}
    (PROOF/'source-procedures.s').write_text(captured)
    (PROOF/'instruction-proof.json').write_text(json.dumps(info,indent=2)+'\n')
    (PROOF/'dos-disassembly.txt').write_text(''.join('F'+n+'\n'+text for n,text in dis.items()))
    return info,captured,doc
def assembly(captured):
    N=load('object_factory_abi',PROJECT/'tools/rebuild_source_natural_contact_native.py')
    selected=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',captured)+'\nFUNC_999999:\nret\n'
    lines,_=N.Q.procedures(selected,NUMBERS);text='\n'.join(lines)
    old='FUNC_001495:\npush rbp\nmov rbp,rsp\nadd rsp,-8'
    if text.count(old)!=1:raise ValueError('F1495 two-pop local layout changed')
    text=text.replace(old,old.replace('rsp,-8','rsp,-16'))
    text=text.replace('FUNC_001538:\n','FUNC_001538:\npushfq\ninc DWORD PTR [lookup_calls]\npopfq\n',1)
    return '.intel_syntax noprefix\n.code64\n.section .text\n.global _start\n'+text+'\n'+WRAPPER
def cases(resources):
    rng=random.Random(0x1533);rows=[]
    def add(name,model,copy,resource=None):
        b=rng.randbytes(338);s=rng.randbytes(338)
        rows.append({'name':name,'copy_source':copy,'model_index_u32':model,'clock':{'tick_u32':rng.choice([0,1,0xffffffff,0xfffffff0,0x80000000]),'day_u32':rng.choice([0,1,0xffffffff,0x121cf7])},
                     'before_body_hex':b.hex(),'source_body_hex':s.hex(),'resources':json.loads(json.dumps(resource or resources[str(model)]))})
    for model in range(149):
        for copy in (False,True):add(f'real-model{model:03d}-'+('copy' if copy else 'inplace'),model,copy)
    for copy in (False,True):
        for index in (0,1,114,127,128,255):
            add('modelzero-index%d-%s'%(index,copy),0,copy)
            b=bytearray.fromhex(rows[-1]['before_body_hex']);b[0x86]=index;rows[-1]['before_body_hex']=b.hex()
    for i,exponent in enumerate((-32768,-65,-64,-63,-33,-32,-31,-1,0,1,31,32,33,63,64,65,32767)):
        r=json.loads(json.dumps(resources['38']));desc=bytearray.fromhex(r['descriptor_hex'])
        struct.pack_into('<h',desc,0x14,exponent);struct.pack_into('<h',desc,0x18,0)
        struct.pack_into('<h',desc,0x2c,(-32768,-1,0,32767)[i%4]);struct.pack_into('<h',desc,0x30,(32767,0,-1,-32768)[i%4]);r['descriptor_hex']=desc.hex()
        add('synthetic-f1495-exponent%d'%exponent,38,bool(i%2),r)
    for i,reverse in enumerate((-32768,-32767,-4910,-4905,-2725,-2724,-1,0,1,2725,4910,32767)):
        r=json.loads(json.dumps(resources['38']));spec=bytearray.fromhex(r['physical_spec_hex']);struct.pack_into('<h',spec,2,reverse)
        struct.pack_into('<H',spec,6,(0,1,0x4000,0xffff)[i%4]);r['physical_spec_hex']=spec.hex();add('synthetic-reverse%d'%reverse,38,bool(i%2),r)
    for drive in range(15):
        r=json.loads(json.dumps(resources['38']));spec=bytearray.fromhex(r['physical_spec_hex']);struct.pack_into('<H',spec,20,0x8000|drive);r['physical_spec_hex']=spec.hex()
        add('synthetic-negative-drive%d'%drive,38,bool(drive%2),r)
    for collision in (None,0,1,255):
        for physical in (False,True):
            r=json.loads(json.dumps(resources['38']));desc=bytearray.fromhex(r['descriptor_hex'])
            struct.pack_into('<I',desc,0x34,0 if collision is None else 1);struct.pack_into('<I',desc,0x38,1 if physical else 0)
            r.update(descriptor_hex=desc.hex(),collision_present=collision is not None,collision_first_byte_u8=collision or 0,physical_spec_hex=r['physical_spec_hex'] if physical else '')
            add('synthetic-reference-%s-%s'%(collision,physical),38,True,r)
    for object_type in range(256):
        add('all-type87-preserved-%03d'%object_type,38,bool(object_type%2))
        for key in ('before_body_hex','source_body_hex'):
            body=bytearray.fromhex(rows[-1][key]);body[0x87]=object_type;rows[-1][key]=body.hex()
    return rows
def packet(row):
    r=row['resources'];header=struct.pack('<8I',row['copy_source'],row['model_index_u32'],row['clock']['tick_u32'],row['clock']['day_u32'],r['collision_present'],bool(r['physical_spec_hex']),r['collision_first_byte_u8'],0)
    return header+bytes.fromhex(row['before_body_hex'])+bytes.fromhex(row['source_body_hex'])+bytes.fromhex(r['descriptor_hex'])+bytes.fromhex(r['physical_spec_hex']).ljust(24,b'\0')
def verify_archived_instructions(info,captured):
    N=load('object_factory_archived_proof',PROJECT/'tools/rebuild_source_natural_contact_native.py')
    if set(info['procedures'])!=set(map(str,NUMBERS)) or info['source_executable_sha256']!=EXE_SHA or not info['full_original_instruction_equality']:raise ValueError('Unreviewed archived factory instruction profile')
    with tempfile.TemporaryDirectory(prefix='object-factory-source32-') as temp:
        work=Path(temp)
        for number in NUMBERS:
            row=info['procedures'][str(number)];raw=bytes.fromhex(row['hex'])
            if not row['all_instructions_equal'] or sha(raw)!=row['sha256']:raise ValueError('Captured DOS factory bytes changed')
            body=N.G.block(captured,number)
            compiled=N.C.J.instructions(N.C.compile32(body,info['original_symbol_bindings'],'FUNC_%06d'%number,row['virtual_address']))
            path=work/('F%d.bin'%number);path.write_bytes(raw)
            original=N.C.J.instructions(subprocess.check_output(['objdump','-D','-b','binary','-m','i386','-Mintel','--no-show-raw-insn','--adjust-vma='+hex(row['virtual_address']),str(path)],text=True))
            if len(original)!=row['instruction_count'] or N.canonical(original)!=N.canonical(compiled):raise ValueError('Fresh archived DOS factory comparison differsF%d'%number)
def generate(info,captured,resource_doc,output):
    if sha(captured.encode())!=info['source_procedures_sha256'] or sha(DATA.read_bytes())!=info['resources_sha256']:raise ValueError('Archived source/resource proof changed')
    verify_archived_instructions(info,captured)
    native=assembly(captured);rows=cases(resource_doc['models'])
    with tempfile.TemporaryDirectory(prefix='object-factory-native-') as temp:
        p=Path(temp);(p/'factory.s').write_text(native)
        subprocess.run(['as','--64','-o',str(p/'factory.o'),str(p/'factory.s')],check=True)
        subprocess.run(['ld','-o',str(p/'factory'),str(p/'factory.o')],check=True)
        def run(raw):
            result=subprocess.run([str(p/'factory')],input=raw,capture_output=True,check=True,timeout=60)
            if result.stderr or len(result.stdout)!=len(raw)//INPUT*OUTPUT:raise ValueError('Native output domain differs')
            return result.stdout
        prior=rows[76].copy()
        for index in range(32):
            row=json.loads(json.dumps(prior));row['name']='consecutive-native-%02d'%index
            row['model_index_u32']=(38,24,112,0,15,117)[index%6]
            row['resources']=json.loads(json.dumps(resource_doc['models'][str(row['model_index_u32'])]));row['copy_source']=bool(index%2)
            raw=run(packet(row));rows.append(row)
            prior=row.copy();prior['before_body_hex']=raw[16:354].hex();prior['source_body_hex']=raw[16:354].hex()
        payload=b''.join(packet(r) for r in rows)
        runs=[run(payload) for _ in range(3)]
        if len(set(runs))!=1:raise ValueError('Native fresh process differs')
        reverse=run(b''.join(packet(r) for r in reversed(rows)))
        if reverse!=b''.join(runs[0][i*OUTPUT:(i+1)*OUTPUT] for i in reversed(range(len(rows)))):raise ValueError('Native order leakage')
        for i,row in enumerate(rows):
            raw=runs[0][i*OUTPUT:(i+1)*OUTPUT];magic,error,lookup,copied=struct.unpack_from('<4I',raw)
            if magic!=0x1533fac7 or error or raw[-64:]!=b'\xa5'*64:raise ValueError('Native guards differ: '+row['name'])
            if raw[354:692]!=bytes.fromhex(row['source_body_hex']) or raw[692:760]!=bytes.fromhex(row['resources']['descriptor_hex']) or raw[760:784]!=bytes.fromhex(row['resources']['physical_spec_hex']).ljust(24,b'\0'):raise ValueError('Factory input resource mutated')
            row.update(expected_body_hex=raw[16:354].hex(),expected_source_body_hex=raw[354:692].hex(),copy_calls=copied,lookup_calls=lookup)
    fixture={'schema':'starfrontier-source-object-factory-native-v1','profile':PROFILE,'source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,
             'source_instruction_proof_sha256':sha((PROOF/'instruction-proof.json').read_bytes()),'resources_sha256':sha(DATA.read_bytes()),'host_adapted_assembly_sha256':sha(native.encode()),
             'input_packets_sha256':sha(payload),'native_output_sha256':sha(runs[0]),'case_count':len(rows),'real_model_count':149,'fresh_process_runs':3,'reverse_repeat_cases':len(rows),
             'consecutive_original_steps':32,'all_type87_byte_values_preserved':256,'all_body_source_resource_canaries_unchanged':True,'expected_arithmetic_calculated_in_python':False,'scope':info['scope'],'cases':rows}
    output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(fixture,indent=2)+'\n')
    (PROOF/'factory-native.s').write_text(native)
    (PROOF/'validation.json').write_text(json.dumps({'status':'verified','case_count':len(rows),'source_model_count':149,'fixture_sha256':sha(output.read_bytes()),'resources_sha256':sha(DATA.read_bytes()),'source_executable_sha256':EXE_SHA,'source_instruction_proofs':info['procedures'],'fresh_process_runs':3,'reverse_repeat_cases':len(rows),'all_canaries_unchanged':True,'scope':info['scope']},indent=2)+'\n')
    print(json.dumps({'status':'verified','case_count':len(rows),'fixture_sha256':sha(output.read_bytes()),'resources_sha256':sha(DATA.read_bytes())},indent=2))
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--refresh-original-proof',action='store_true');args=p.parse_args()
    if args.refresh_original_proof:info,captured,resources=prepare(args)
    else:info=json.loads((PROOF/'instruction-proof.json').read_text());captured=(PROOF/'source-procedures.s').read_text();resources=json.loads(DATA.read_text())
    generate(info,captured,resources,args.output)

WRAPPER=r'''
_memcpy:
 push rbp
 mov rbp,rsp
 push rsi
 push rdi
 inc DWORD PTR [copy_calls]
 mov edi,DWORD PTR [rbp+16]
 mov esi,DWORD PTR [rbp+24]
 mov ecx,DWORD PTR [rbp+32]
 mov eax,edi
 cld
 rep movsb
 pop rdi
 pop rsi
 pop rbp
 ret
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 mov esp,OFFSET FLAT:stack_end
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:input
 add rsi,r8
 mov edx,800
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,800
 jne read_more
 cld
 mov edi,OFFSET FLAT:guarded_before
 mov ecx,832
 mov al,0xa5
 rep stosb
 mov esi,OFFSET FLAT:input+32
 mov edi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:source
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:descriptor
 mov ecx,68
 rep movsb
 mov edi,OFFSET FLAT:physical
 mov ecx,24
 rep movsb
 mov eax,DWORD PTR [input+8]
 mov DWORD PTR [DATA_008804],eax
 mov eax,DWORD PTR [input+12]
 mov DWORD PTR [DATA_008807],eax
 mov eax,DWORD PTR [input+24]
 mov BYTE PTR [collision],al
 mov DWORD PTR [copy_calls],0
 mov DWORD PTR [lookup_calls],0
 mov DWORD PTR [descriptor+0x34],0
 cmp DWORD PTR [input+16],0
 je collision_ready
 mov DWORD PTR [descriptor+0x34],OFFSET FLAT:collision
collision_ready:
 mov DWORD PTR [descriptor+0x38],0
 cmp DWORD PTR [input+20],0
 je physical_ready
 mov DWORD PTR [descriptor+0x38],OFFSET FLAT:physical
physical_ready:
 mov edi,OFFSET FLAT:DATA_004681
 mov ecx,149
 mov eax,OFFSET FLAT:descriptor
 rep stosd
 mov eax,DWORD PTR [input+4]
 push rax
 mov eax,OFFSET FLAT:body
 cmp DWORD PTR [input],0
 je same_source
 mov eax,OFFSET FLAT:source
same_source:
 push rax
 push OFFSET FLAT:body
 call FUNC_001533
 add rsp,24
 mov eax,DWORD PTR [input+708+0x34]
 mov DWORD PTR [descriptor+0x34],eax
 mov eax,DWORD PTR [input+708+0x38]
 mov DWORD PTR [descriptor+0x38],eax
 mov DWORD PTR [output],0x1533fac7
 mov DWORD PTR [output+4],0
 mov eax,DWORD PTR [lookup_calls]
 mov DWORD PTR [output+8],eax
 mov eax,DWORD PTR [copy_calls]
 mov DWORD PTR [output+12],eax
 mov esi,OFFSET FLAT:body
 mov edi,OFFSET FLAT:output+16
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:source
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:descriptor
 mov ecx,68
 rep movsb
 mov esi,OFFSET FLAT:physical
 mov ecx,24
 rep movsb
 mov esi,OFFSET FLAT:guarded_before
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:body_after
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:source_before
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:source_after
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:descriptor_before
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:descriptor_after
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:physical_before
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:physical_after
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:output
 mov edx,848
write_more:
 mov eax,1
 mov edi,1
 syscall
 test eax,eax
 jle failed
 add esi,eax
 sub edx,eax
 jnz write_more
 jmp next_case
failed:
 mov edi,99
 jmp leave
finished:
 xor edi,edi
leave:
 mov eax,60
 syscall
.section .data
DATA_007734: .quad FUNC_001495
DATA_007210: .long 0,4,10,25,45,80,150,250,400,600,6,12,24,36,0
DATA_008804: .long 0
DATA_008807: .long 0
.section .bss
.balign 16
input: .zero 800
output: .zero 848
guarded_before: .zero 8
body: .zero 338
body_after: .zero 8
source_before: .zero 8
source: .zero 338
source_after: .zero 8
descriptor_before: .zero 8
descriptor: .zero 68
descriptor_after: .zero 8
physical_before: .zero 8
physical: .zero 24
physical_after: .zero 8
collision: .zero 1
copy_calls: .zero 4
lookup_calls: .zero 4
DATA_004681: .zero 596
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
'''
if __name__=='__main__':main()
