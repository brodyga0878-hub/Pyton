#!/usr/bin/env python3
"""Independent original F891/F892 appended-record controls, including real names.

The names module supplies extracted F893/F791 text-expansion instructions/data.
No name, settlement model or period is computed as an expected result in Python.
The emitted ELF is only a host-side oracle, never part of the Android runtime.
"""
from __future__ import annotations
import argparse,hashlib,importlib.util,json,random,re,struct,subprocess,sys,tempfile
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
SOURCE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
DATA_SHA='34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850'
COMMIT='7e540341d4e09aa3c92877b87d49e7f2c143ad8d'
VARIANT='jjffe-7e54034-settlements-v1'
FIELDS=['operation','index','seed_a','seed_b','population_raw','ordinal_counter','port_count_byte','orbital_count_byte','language','model_offset','count_scale','port_type','parent_index']
OUTPUT_FIELDS=['index','seed_a','seed_b','ordinal_counter','port_count_byte','orbital_count_byte']
BANK=60*68
INPUT=len(FIELDS)*4+BANK
OUTPUT=BANK+len(OUTPUT_FIELDS)*4
CANARY=0x534554544c454d54

def sha(raw):return hashlib.sha256(raw).hexdigest()

def module(path,name):
    spec=importlib.util.spec_from_file_location(name,path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result)
    return result

def record_bank(row,slots=60):
    result=bytearray([row.get('fill_byte',0)])*(slots*68)
    for key,value in row.get('records',{}).items():
        record=bytes.fromhex(value)
        assert len(record)==68
        index=int(key);assert 0<=index<slots
        result[index*68:(index+1)*68]=record
    return bytes(result)

def make_cases(rules):
    rng=random.Random(0x891892)
    rows=[]
    def add(operation,**extra):
        index=extra.pop('index',rng.choice([0,1,5,20,55]))
        parent=extra.pop('parent_index',rng.choice([1,index+1]))
        record=bytearray.fromhex(rules['templates']['2'])
        mass=extra.pop('parent_mass',rng.choice([0x005b5f5e,0x00494ac0,0x00427000,0,0x00017fff,0xffff7fff,0x00498000]))
        struct.pack_into('<I',record,0,mass)
        record[38:62]=b'Parent\0'+bytes(17)
        row=dict(operation=operation,index=index,seed_a=rng.getrandbits(32),seed_b=rng.getrandbits(32),population_raw=rng.getrandbits(32),ordinal_counter=rng.getrandbits(32),port_count_byte=rng.choice([0,1,14,15,16,17,18,19,127,128,254,255]),orbital_count_byte=rng.randrange(256),language=rng.choice([0,1,2,3,0xffffffff]),model_offset=rng.choice([0,12,24,36]),count_scale=rng.choice([0,1,3,7,31,0x7fffffff,0x80000000,0xffffffff]),port_type=rng.randrange(5),parent_index=parent,fill_byte=rng.randrange(256),records={str(parent-1):record.hex()},group='register_context')
        row.update(extra);rows.append(row)
    for port_count in [0,1,14,15,16,17,18,19,127,128,129,254,255]:
        for seed_b in [0,1,0x7fff,0x8000,0xffff,0xffffffff]:
            for scale in [0,1,3,7,31,0x10000,0x7fffffff,0x80000000,0xffffffff]:
                add(0,port_count_byte=port_count,seed_b=seed_b,count_scale=scale,group='ground_count_and_port_gate')
    for ordinal in [0,1,14,15,16,17,0x7fffffff,0xfffffffe,0xffffffff]:
        for offset in [0,12,24,36]:
            for language in [0,3]:
                add(0,ordinal_counter=ordinal,model_offset=offset,port_count_byte=0,count_scale=7,seed_b=0xffff,language=language,group='ground_coords_models_and_language')
    for port_type in [0,1,2,3,4,5,6,0x7fffffff,0x80000000,0xffffffff]:
        for choice in range(4):
            for port_count in [0,17,18,127,128,255]:
                add(1,port_type=port_type,port_count_byte=port_count,seed_a=(rng.getrandbits(32)&~0x300)|(choice<<8),group='orbital_type_model_and_port_gate')
    for mass in [0,1,0x00390000,0x005b5f5e,0x00494ac0,0x00427000,0x7fff7fff,0xffff7fff,0x00498000,0xffffffff]:
        for kind in range(5):
            add(1,parent_mass=mass,port_type=kind,port_count_byte=0,group='orbital_original_period')
    for index in [56,57,58]:
        add(0,index=index,parent_index=1,port_count_byte=17,group='last_available_ground_slot')
        add(1,index=index,parent_index=1,port_count_byte=17,group='last_available_orbital_slot')
    for _ in range(256):add(rng.randrange(2))
    return rows

def make_wide_cases(rules):
    """Inputs beyond the old60-slot wrapper, not fabricated body expectations."""
    base=make_cases(rules)[0];rows=[]
    for operation in [0,1]:
        for index in [58,59,60,63,64,123,126,127]:
            for port_count in [0,17,18,127,128,255]:
                for scale in [0,7]:
                    # The original helpers do not check the caller's allocation.
                    # Keep only in-bank native inputs; rejection of an unsafe
                    # bounded API input is tested separately without corruption.
                    gated=18<=port_count<128
                    count=0 if gated else (1 if operation==1 or scale==0 or port_count==17 else 4)
                    if index+count>=128:continue
                    row=base.copy();row.update(operation=operation,index=index,port_count_byte=port_count,count_scale=scale,seed_b=0xffff,seed_a=0xe3d24ac9,ordinal_counter=0xffffffff,orbital_count_byte=255,model_offset=[0,12,24,36][index%4],language=3,port_type=(index+port_count+scale)%5,parent_index=1,group='wide128_original_append')
                    row['records']=base['records'].copy();rows.append(row)
    return rows

def run_native(source,original,data_source,rules,cases,slots):
    bank=slots*68;input_size=len(FIELDS)*4+bank;output_size=bank+len(OUTPUT_FIELDS)*4
    native,hashes,naming=assembly(source,original,data_source,rules,slots)
    ordered=cases+list(reversed(cases))
    packets=b''.join(struct.pack('<'+str(len(FIELDS))+'I',*(row[k] for k in FIELDS))+record_bank(row,slots) for row in ordered)
    with tempfile.TemporaryDirectory(prefix='ffe-settlement-oracle-',dir='/tmp') as directory:
        work=Path(directory);(work/'native.s').write_text(native)
        subprocess.run(['as','--64',str(work/'native.s'),'-o',str(work/'native.o')],check=True)
        subprocess.run(['ld','-m','elf_x86_64',str(work/'native.o'),'-o',str(work/'native')],check=True)
        outputs=[]
        for _run in range(3):
            result=subprocess.run([str(work/'native')],input=packets,stdout=subprocess.PIPE,timeout=60)
            if result.returncode:
                failed=len(result.stdout)//output_size
                raise ValueError('Native source exit %d at case %d: %s'%(result.returncode,failed,json.dumps({key:value for key,value in ordered[failed].items() if key!='records'})))
            outputs.append(result.stdout)
    if any(value!=outputs[0] for value in outputs[1:]):raise ValueError('Fresh native processes differ')
    output=outputs[0]
    if len(output)!=len(ordered)*output_size:raise ValueError('Incomplete native output')
    appended_total=0
    for index,row in enumerate(cases):
        result=output[index*output_size:(index+1)*output_size];reverse=len(ordered)-1-index
        if result!=output[reverse*output_size:(reverse+1)*output_size]:raise ValueError('Reverse native order differs')
        fields=dict(zip(OUTPUT_FIELDS,struct.unpack_from('<'+str(len(OUTPUT_FIELDS))+'I',result,bank)))
        appended=fields['index']-row['index']
        if not 0<=appended<=4 or (row['operation']==1 and appended>1):raise ValueError('Unexpected append count')
        before=record_bank(row,slots);first=(row['index']+1)*68;last=(fields['index']+1)*68
        if result[:first]!=before[:first] or result[last:bank]!=before[last:]:raise ValueError('Non-appended record bytes changed')
        for key in ['seed_a','seed_b']:
            if fields[key]!=row[key]:raise ValueError('Settlement unexpectedly changed global RNG')
        row['expected']={**fields,'appended_count':appended,'records':{str(slot):result[slot*68:(slot+1)*68].hex() for slot in range(row['index']+1,fields['index']+1)},'whole_bank_sha256':sha(result[:bank])}
        appended_total+=appended
    return {'native':native,'hashes':hashes,'naming':naming,'output_sha256':sha(output),'appended_records':appended_total}

def settlement_library_assembly(source:str,rules:dict|None=None)->tuple[str,dict]:
    """F891/F892 and their source constants, without wrappers/shared helpers.

    The caller links real F893/F791, F1463/F1467/F1482/F1483, C memcpy and
    globals8843/8844/8846/8854/8855/8856 itself. This avoids duplicate copies
    when the complete procedural system oracle already contains packed math.
    """
    if rules is None:rules=json.loads((PROJECT/'data/ffe_settlement_rules.json').read_text())
    sys.path.insert(0,str(PROJECT/'recovered-history/ground_harness/tools'))
    from native_reference import procedures
    lines,hashes=procedures(source,[891,892]);text='\n'.join(lines)
    text=text.replace('SECTION .data','.section .data').replace('SECTION .text','.section .text')
    text=re.sub(r'^dd (JUMP_\d+)$',r'.quad \1',text,flags=re.M)
    text=text.replace('jmp [eax*4+DATA_000036]','jmp QWORD PTR [rax*8+DATA_000036]')
    text='\n.section .text\n'+text+'\n.section .data\n'
    for label,key in [('DATA_008794','2'),('DATA_008795','12'),('DATA_008796','16'),('DATA_008797','17')]:
        text+=label+': .byte '+','.join(str(x) for x in bytes.fromhex(rules['templates'][key]))+'\n'
    coords=rules['tables']['ground_coordinates']
    text+='DATA_007130: .long '+str(coords[0])+'\nDATA_007131: .long '+','.join(str(x) for x in coords[1:])+'\n'
    text+='DATA_007132: .long '+','.join(str(x) for x in rules['tables']['ground_models'])+'\n'
    for i in range(3):text+='DATA_%06d: .long '%(7136+i)+','.join(str(x) for x in rules['tables']['orbital_models'][i*4:i*4+4])+'\n'
    text+='DATA_007185: .byte 63,63,63,63,0,0\n'
    metadata={'source_procedure_hashes':hashes,'settlement_rules_sha256':sha((PROJECT/'data/ffe_settlement_rules.json').read_bytes()),'scope':'Actual F891/F892 plus original templates/model/coordinate tables; shared real naming/math/globals are linked by the caller.'}
    return text,metadata

def assembly(source,original,data_source,rules,slots=60):
    bank=slots*68;input_size=len(FIELDS)*4+bank;output_size=bank+len(OUTPUT_FIELDS)*4
    names=module(PROJECT/'tools/rebuild_source_names_native.py','source_names_oracle')
    library,metadata=names.library_assembly(source,original,data_source)
    sys.path.insert(0,str(PROJECT/'recovered-history/ground_harness/tools'))
    from native_reference import procedures
    numbers=[891,892,1463,1467,1482,1483]
    lines,hashes=procedures(source,numbers)
    text='\n'.join(lines)
    text=text.replace('SECTION .data','.section .data').replace('SECTION .text','.section .text')
    text=re.sub(r'^dd (JUMP_\d+)$',r'.quad \1',text,flags=re.M)
    text=text.replace('jmp [eax*4+DATA_000036]','jmp QWORD PTR [rax*8+DATA_000036]')
    if 'jmp QWORD PTR [rax*8+DATA_000036]' not in text:raise ValueError('Missing F892 host jump-table ABI adaptation')
    sqrt_at=original.find(bytes.fromhex('0000a8050008cc09500ba60cdb0df70e'));sqrt=original[sqrt_at:sqrt_at+4096]
    if sha(sqrt)!='1bb88ff59cdc392b0c116d26a7f4ec1b9504fdfe42909f522d5ba9cbfcd02ef0':raise ValueError('Unreviewed sqrt LUT')
    head='.intel_syntax noprefix\n.code64\n'+library+'\n.section .text\n'+text+'\n.global _start\n_start:\n mov esp,OFFSET FLAT:settlement_stack_end\nnext_settlement:\n mov esp,OFFSET FLAT:settlement_stack_end\n xor r8d,r8d\n'
    head+=f'''read_settlement:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:settlement_input
 add rsi,r8
 mov edx,{input_size}
 sub edx,r8d
 syscall
 test eax,eax
 jle settlement_finished
 add r8d,eax
 cmp r8d,{input_size}
 jne read_settlement
 cld
 mov esi,OFFSET FLAT:settlement_input+{len(FIELDS)*4}
 mov edi,OFFSET FLAT:settlement_records
 mov ecx,{bank}
 rep movsb
 mov rax,{CANARY}
 mov QWORD PTR [settlement_guard_before],rax
 mov QWORD PTR [settlement_guard_after],rax
 mov edi,OFFSET FLAT:settlement_name_context
 xor eax,eax
 mov ecx,64
 rep stosb
'''
    globals_map={'index':'settlement_index','seed_a':'DATA_008843','seed_b':'DATA_008844','population_raw':'DATA_008854','ordinal_counter':'DATA_008846','port_count_byte':'DATA_008855','orbital_count_byte':'DATA_008856','language':'DATA_007128'}
    for field,label in globals_map.items():head+=f' mov eax,DWORD PTR [settlement_input+{FIELDS.index(field)*4}]\n mov DWORD PTR [{label}],eax\n'
    at=lambda key:FIELDS.index(key)*4
    head+=f''' cmp DWORD PTR [settlement_input],0
 jne settlement_orbital
 push OFFSET FLAT:settlement_name_context
 mov eax,DWORD PTR [settlement_input+{at('count_scale')}]
 push rax
 mov eax,DWORD PTR [settlement_input+{at('model_offset')}]
 push rax
 push OFFSET FLAT:settlement_index
 push OFFSET FLAT:settlement_records
 call FUNC_000891
 add rsp,40
 jmp settlement_emit
settlement_orbital:
 mov eax,DWORD PTR [settlement_input+{at('parent_index')}]
 push rax
 push OFFSET FLAT:settlement_name_context
 mov eax,DWORD PTR [settlement_input+{at('port_type')}]
 push rax
 push OFFSET FLAT:settlement_index
 push OFFSET FLAT:settlement_records
 call FUNC_000892
 add rsp,40
settlement_emit:
 mov rax,{CANARY}
 cmp QWORD PTR [settlement_guard_before],rax
 jne settlement_canary_failed
 cmp QWORD PTR [settlement_guard_after],rax
 jne settlement_canary_failed
 mov esi,OFFSET FLAT:settlement_records
 mov edi,OFFSET FLAT:settlement_output
 mov ecx,{bank}
 rep movsb
'''
    for index,field in enumerate(OUTPUT_FIELDS):head+=f' mov eax,DWORD PTR [{globals_map[field]}]\n mov DWORD PTR [settlement_output+{bank+index*4}],eax\n'
    head+=f''' mov esi,OFFSET FLAT:settlement_output
 mov edx,{output_size}
write_settlement:
 mov eax,1
 mov edi,1
 syscall
 test eax,eax
 jle settlement_write_failed
 add esi,eax
 sub edx,eax
 jnz write_settlement
 jmp next_settlement
settlement_canary_failed:
 mov eax,60
 mov edi,94
 syscall
settlement_write_failed:
 mov eax,60
 mov edi,72
 syscall
settlement_finished:
 mov eax,60
 xor edi,edi
 syscall
'''
    # FFE calls the ordinary C byte-copy primitive. Preserve its callee-saved
    # registers and return destination, exactly as required by its callers.
    if not re.search(r'^_memcpy:',library,re.M):head+='''_memcpy:
 push rsi
 push rdi
 mov eax,DWORD PTR [rsp+24]
 mov edi,eax
 mov esi,DWORD PTR [rsp+32]
 mov ecx,DWORD PTR [rsp+40]
 rep movsb
 pop rdi
 pop rsi
 ret
'''
    head+='\n.section .data\n.align 8\nDATA_007723: .quad FUNC_001467\nDATA_007730: .quad FUNC_001463\nDATA_007731: .quad FUNC_001483\n'
    for key,record in [('DATA_008794','2'),('DATA_008795','12'),('DATA_008796','16'),('DATA_008797','17')]:head+=key+':\n.byte '+','.join(str(x) for x in bytes.fromhex(rules['templates'][record]))+'\n'
    coords=rules['tables']['ground_coordinates'];head+='DATA_007130: .long '+str(coords[0])+'\nDATA_007131:\n.long '+','.join(str(x) for x in coords[1:])+'\n'
    head+='DATA_007132:\n.long '+','.join(str(x) for x in rules['tables']['ground_models'])+'\n'
    for i in range(3):head+='DATA_%06d:\n.long '%(7136+i)+','.join(str(x) for x in rules['tables']['orbital_models'][i*4:i*4+4])+'\n'
    head+='DATA_007185: .byte 63,63,63,63,0,0\nDATA_007977:\n.short '+','.join(str(x) for x in struct.unpack('<2048H',sqrt))+'\n'
    head+='\n.section .bss\n.align 16\n'
    for label in ['DATA_008843','DATA_008844','DATA_008854','DATA_008846','DATA_008855','DATA_008856']:
        if not re.search(r'^'+label+':',library,re.M):head+=label+': .zero 4\n'
    if not re.search(r'^DATA_007128:',library,re.M):head+='DATA_007128: .zero 4\n'
    head+=f'''settlement_index: .zero 4
settlement_name_context: .zero 64
settlement_input: .zero {input_size}
settlement_guard_before: .zero 8
settlement_records: .zero {bank}
settlement_guard_after: .zero 8
settlement_output: .zero {output_size}
.align 16
settlement_stack: .zero 131072
settlement_stack_end:
.section .note.GNU-stack,"",@progbits
'''
    return head,hashes,metadata

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--data-source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'))
    parser.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_settlements_native.json')
    args=parser.parse_args();source_raw=args.source.read_bytes();data_raw=args.data_source.read_bytes();original=args.executable.read_bytes()
    if sha(source_raw)!=ASM_SHA or sha(data_raw)!=DATA_SHA or sha(original)!=SOURCE_SHA:raise ValueError('Unreviewed source material')
    rules_path=PROJECT/'data/ffe_settlement_rules.json';rules=json.loads(rules_path.read_bytes());assert rules['source_sha256']==SOURCE_SHA
    handcrafted=json.loads((PROJECT/'data/ffe_handcrafted_records.json').read_bytes())['records']
    for name,template in rules['templates'].items():assert handcrafted[name]['record_hex']==template
    cases=make_cases(rules);wide_cases=make_wide_cases(rules)
    primary=run_native(source_raw.decode(),original,data_raw.decode(),rules,cases,60)
    wide=run_native(source_raw.decode(),original,data_raw.decode(),rules,wide_cases,128)
    groups={};operations={}
    for row in cases:
        groups[row['group']]=groups.get(row['group'],0)+1
        operations[str(row['operation'])]=operations.get(str(row['operation']),0)+1
    fixture={'schema':1,'revision':'native-source-settlement-builders-v1','source_variant':VARIANT,'source_sha256':SOURCE_SHA,'source_assembly_sha256':ASM_SHA,'source_data_sha256':DATA_SHA,'source_commit':COMMIT,'source_procedure_hashes':primary['hashes'],'naming_library':primary['naming'],'settlement_rules_sha256':sha(rules_path.read_bytes()),'adapted_assembly_sha256':sha(primary['native'].encode()),'scope':'Actual original F891/F892 including real F893/F791 naming and packed period math; preserved60-record bounded API plus explicit128-record source-system bank. Not a complete procedural hierarchy or live surface/docking integration.','case_count':len(cases),'operation_counts':operations,'groups':groups,'appended_records':primary['appended_records'],'records_buffer_guard_canaries_unchanged':True,'non_target_records_unchanged':True,'global_rng_unchanged':True,'fresh_process_runs':3,'reverse_repeat_count':len(cases),'native_ordered_output_sha256':primary['output_sha256'],'wide_bank_slots':128,'wide_case_count':len(wide_cases),'wide_appended_records':wide['appended_records'],'wide_fresh_process_runs':3,'wide_reverse_repeat_count':len(wide_cases),'wide_adapted_assembly_sha256':sha(wide['native'].encode()),'wide_native_ordered_output_sha256':wide['output_sha256'],'cases':cases,'wide_cases':wide_cases}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(fixture,separators=(',',':'))+'\n')
    print('Native F891/F892:',len(cases),'60-slot +',len(wide_cases),'128-slot contexts;',primary['appended_records']+wide['appended_records'],'appended records; real names/period, fresh/reverse/canaries pass')

if __name__=='__main__':main()
