#!/usr/bin/env python3
"""Original F877/F878/F881/F896/F897 hierarchy controls and source metadata.

The host ELF executes pinned source procedures. Python provides only inputs,
extracts original data and checks independent runs; it never supplies expected
planet records or names. The Android runtime uses pure GDScript modules.
"""
from __future__ import annotations
import argparse,hashlib,importlib.util,json,re,struct,subprocess,sys,tempfile,random
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
SOURCE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
DATA_SHA='34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850'
COMMIT='7e540341d4e09aa3c92877b87d49e7f2c143ad8d'
VARIANT='jjffe-7e54034-full-system-v1'
SLOTS=128
BANK=SLOTS*68
FIELDS=['operation','index','mass','parent','multiplier','distance','secondary_distance','seed_a','seed_b','depth','counter','body_count_byte','star_count_byte','port_count_byte','orbital_count_byte','planet_counter','moon_counter','third_counter','population_raw','system_id','language','star_quota','largest_mass','num_stars','callback','random_value','start_radius','mass_limit','mass_divisor']
OUTPUT_FIELDS=['index','return_word','seed_a','seed_b','depth','counter','body_count_byte','star_count_byte','planet_counter','moon_counter','third_counter','port_count_byte','orbital_count_byte','language','star_quota','largest_mass']
NAME_OFFSET=len(FIELDS)*4
RECORD_OFFSET=NAME_OFFSET+64
INPUT=RECORD_OFFSET+BANK
OUTPUT=BANK+len(OUTPUT_FIELDS)*4
GUARD=0x53595354454d3132

def sha(raw):return hashlib.sha256(raw).hexdigest()
def module(path,name):
    spec=importlib.util.spec_from_file_location(name,path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

def numeric_range(source,start,end):
    """Extract contiguous original numeric DB bytes, retaining interior aliases."""
    begin=source.index('DATA_%06d:'%start);finish=source.index('DATA_%06d:'%end,begin)
    raw=bytearray();labels={}
    for original in source[begin:finish].splitlines():
        line=original.split(';',1)[0].strip()
        match=re.match(r'DATA_(\d+):',line)
        if match:labels[int(match[1])]=len(raw);continue
        if not line:continue
        if line.startswith('db '):
            raw.extend(int(value.strip(),0)&255 for value in line[3:].split(','))
        else:raise ValueError('Non-numeric source metadata: '+line)
    return bytes(raw),labels

def metadata_constants(data_source,original):
    raw,labels=numeric_range(data_source,7106,7117)
    at=original.find(raw[:432])
    if at<0 or original.find(raw[:432],at+1)>=0:raise ValueError('Metadata prefix does not match executable uniquely')
    exceptions=raw[labels[7116]:];exception_at=original.find(exceptions)
    if exception_at<at or original.find(exceptions,exception_at+1)>=0:raise ValueError('Original metadata exceptions are not unique')
    dos=original[at:exception_at+16]
    extra=labels[7116]-(len(dos)-16)
    if extra!=540 or raw[-70:-16]!=bytes(54) or dos[-70:-16]!=bytes(54):raise ValueError('Unreviewed JJFFE metadata-row difference')
    prefix=len(dos)-70
    if raw[:prefix]!=dos[:prefix]:raise ValueError('Metadata differs before reviewed JJFFE added rows')
    if labels[7110]!=8*54:raise ValueError('Unexpected metadata negative-index stride')
    source=raw[labels[7110]:labels[7116]]
    if len(source)%54:raise ValueError('Metadata rows are not54-byte source records')
    pointers=re.search(r'^DATA_007117:[^\n]*\n(.*?)(?=^DATA_007118:)',data_source,re.M|re.S)[1]
    pointer_labels=[int(x) for x in re.findall(r'^\s*dd DATA_(\d+)\s*$',pointers,re.M)]
    if pointer_labels!=list(range(7139,7183)):raise ValueError('Unexpected F860 source-name pointer domain')
    orbit,orbit_labels=numeric_range(data_source,7129,7130)
    boundary,_=numeric_range(data_source,7130,7131)
    if len(orbit)!=256*4 or len(boundary)!=4:raise ValueError('Unreviewed F896 LUT/adjacent-coordinate layout')
    orbit+=boundary
    orbit_at=original.find(orbit)
    if orbit_at<0 or original.find(orbit,orbit_at+1)>=0 or len(orbit)!=257*4:raise ValueError('Original F896 orbit lookup mismatch')
    mapping,_=numeric_range(data_source,7133,7134)
    mapping_at=original.find(mapping)
    if mapping_at<0 or original.find(mapping,mapping_at+1)>=0:raise ValueError('Original handcrafted map mismatch')
    return {'schema':1,'source_sha256':SOURCE_SHA,'source_assembly_sha256':ASM_SHA,'source_data_sha256':DATA_SHA,
            'source_commit':COMMIT,'metadata_stride_bytes':54,'negative_rows':8,
            'metadata_hex':raw.hex(),'metadata_labels':{str(k):v for k,v in labels.items()},
            'metadata_executable_offset':at,'metadata_sha256':sha(raw),'metadata_variant':'jjffe-policy-table-with10-added-rows',
            'dos_metadata_hex':dos.hex(),'dos_metadata_sha256':sha(dos),'unchanged_dos_prefix_bytes':prefix,'jjffe_added_rows':extra//54,
            'handcoded_metadata_rows':len(source)//54,'name_pointer_labels':pointer_labels,
            'source_exception_ids':list(struct.unpack('<4I',raw[labels[7116]:])),
            'orbit_lookup_table_entries':256,'orbit_lookup_boundary_next_label':7130,'orbit_lookup_u32':list(struct.unpack('<257I',orbit)),'orbit_lookup_executable_offset':orbit_at,'orbit_lookup_sha256':sha(orbit),
            'handcrafted_mapping_hex':mapping.hex(),'handcrafted_mapping_executable_offset':mapping_at,'handcrafted_mapping_sha256':sha(mapping)}

def metadata_assembly(data,include_orbit=True,include_mapping=True):
    """Numeric original metadata library; caller supplies F868/F871 code/globals.

    DATA7117 is a pointer table and is exposed as name_pointer_labels rather
    than silently rebasing original32-bit addresses. A caller using F860 emits
    its own source string labels and that explicit host pointer table.
    """
    out='.section .rodata\n.align 4\nsource_metadata_blob:\n.byte '+','.join(str(x) for x in bytes.fromhex(data['metadata_hex']))+'\n'
    for label,offset in data['metadata_labels'].items():out+='.set DATA_%06d,source_metadata_blob+%d\n'%(int(label),offset)
    if include_orbit:out+='DATA_007129:\n.long '+','.join(str(x) for x in data['orbit_lookup_u32'])+'\n'
    if include_mapping:out+='DATA_007133:\n.byte '+','.join(str(x) for x in bytes.fromhex(data['handcrafted_mapping_hex']))+'\n'
    return out

def data_helpers(data_source,original):
    """Public extraction alias for the galaxy/system-metadata oracle."""
    return metadata_constants(data_source,original)

def metadata_native_cases(data):
    raw=bytes.fromhex(data['metadata_hex']);ids={0,1,0xffffffff,0x80000000}
    for index in range(data['handcoded_metadata_rows']):
        value=struct.unpack_from('<I',raw,432+index*54)[0]
        if value:ids.add(value)
    for value in data['source_exception_ids']:
        for child in range(64):ids.add((value&0x03ffffff)|(child<<26))
    for x in [-141,-140,-139,-18,-17,-16,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1,0,1,2,3,4,5,6,7,8,9,10,11,16,17,18,139,140,141]:
        for child in [0,1,7,8,63]:
            ids.add(((0x1718+x)&0x1fff)|(0x1524<<13)|(child<<26))
    rng=random.Random(0x868871)
    ids.update(rng.getrandbits(32) for _ in range(400))
    return [{'system_id':value,'first_value':rng.getrandbits(32),'second_value':rng.getrandbits(32)} for value in sorted(ids)]

def metadata_oracle_assembly(source,data):
    sys.path.insert(0,str(PROJECT/'recovered-history/ground_harness/tools'))
    from native_reference import procedures
    lines,hashes=procedures(source,[868,869,871])
    code='\n'.join(lines)
    text='.intel_syntax noprefix\n.code64\n.section .text\n'+code+'\n.global _start\n_start:\n mov esp,OFFSET FLAT:metadata_stack_end\nnext_metadata:\n mov esp,OFFSET FLAT:metadata_stack_end\n xor r8d,r8d\n'
    text+='''read_metadata:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:metadata_input
 add rsi,r8
 mov edx,12
 sub edx,r8d
 syscall
 test eax,eax
 jle metadata_finished
 add r8d,eax
 cmp r8d,12
 jne read_metadata
 mov eax,DWORD PTR [metadata_input+4]
 mov DWORD PTR [DATA_008912],eax
 mov eax,DWORD PTR [metadata_input+8]
 mov DWORD PTR [DATA_008913],eax
 mov eax,DWORD PTR [metadata_input]
 push rax
 call FUNC_000868
 add rsp,8
 mov DWORD PTR [metadata_output],eax
'''
    for offset in reversed(range(4,36,4)):text+=' push OFFSET FLAT:metadata_output+%d\n'%offset
    text+=' mov eax,DWORD PTR [metadata_input]\n push rax\n call FUNC_000869\n add rsp,72\n'
    for offset in reversed(range(36,60,4)):text+=' push OFFSET FLAT:metadata_output+%d\n'%offset
    text+=''' mov eax,DWORD PTR [metadata_input]
 push rax
 call FUNC_000871
 add rsp,56
 mov esi,OFFSET FLAT:metadata_output
 mov edx,60
write_metadata:
 mov eax,1
 mov edi,1
 syscall
 test eax,eax
 jle metadata_write_failed
 add esi,eax
 sub edx,eax
 jnz write_metadata
 jmp next_metadata
metadata_write_failed:
 mov eax,60
 mov edi,72
 syscall
metadata_finished:
 mov eax,60
 xor edi,edi
 syscall
'''
    text+=metadata_assembly(data,False,False)
    text+='''.section .bss
.align 16
metadata_input: .zero 12
metadata_output: .zero 60
DATA_008912: .zero 4
DATA_008913: .zero 4
metadata_stack: .zero 65536
metadata_stack_end:
.section .note.GNU-stack,"",@progbits
'''
    return text,hashes

def execute_metadata(source,data):
    text,hashes=metadata_oracle_assembly(source,data);cases=metadata_native_cases(data)
    ordered=cases+list(reversed(cases));packets=b''.join(struct.pack('<3I',row['system_id'],row['first_value'],row['second_value']) for row in ordered)
    with tempfile.TemporaryDirectory(prefix='ffe-system-metadata-') as directory:
        root=Path(directory);(root/'native.s').write_text(text)
        subprocess.run(['as','--64',str(root/'native.s'),'-o',str(root/'native.o')],check=True)
        subprocess.run(['ld','-m','elf_x86_64',str(root/'native.o'),'-o',str(root/'native')],check=True)
        outputs=[subprocess.run([str(root/'native')],input=packets,stdout=subprocess.PIPE,check=True,timeout=20).stdout for _ in range(3)]
    if any(value!=outputs[0] for value in outputs[1:]):raise ValueError('Metadata fresh-process mismatch')
    output=outputs[0]
    if len(output)!=len(ordered)*60:raise ValueError('Incomplete native metadata output')
    keys=['policy_index_u32']+['F869_'+str(i) for i in range(8)]+['nibble_low','nibble_high','nibble_max','language','first_value','second_value']
    for index,row in enumerate(cases):
        raw=output[index*60:(index+1)*60]
        reverse=len(ordered)-1-index
        if raw!=output[reverse*60:(reverse+1)*60]:raise ValueError('Metadata reverse-order mismatch')
        row['expected']=dict(zip(keys,struct.unpack('<15I',raw)))
    return {'metadata_case_count':len(cases),'metadata_cases':cases,'metadata_source_procedure_hashes':hashes,'metadata_adapted_assembly_sha256':sha(text.encode()),'metadata_native_output_sha256':sha(output),'metadata_fresh_process_runs':3,'metadata_reverse_repeat_count':len(cases)}

def full_library_assembly(source,original,data_source,data):
    """All reachable source constructors/callbacks plus real naming and tables."""
    names=module(PROJECT/'tools/rebuild_source_names_native.py','system_source_names')
    settlements=module(PROJECT/'tools/rebuild_source_settlement_native.py','system_source_settlements')
    stellar=module(PROJECT/'tools/rebuild_world_factory_native.py','system_source_stellar')
    library,name_meta=names.library_assembly(source,original,data_source)
    settlement_text,settlement_meta=settlements.settlement_library_assembly(source)
    sys.path.insert(0,str(PROJECT/'recovered-history/ground_harness/tools'))
    from native_reference import procedures
    numbers=[868,869,871,877,878,881,882,883,884,885,886,887,888,889,890,894,896,897,1463,1467,1482,1483,1486,1489,1491,1515]
    lines,hashes=procedures(source,numbers)
    code='\n'.join(lines).replace('SECTION .data','.section .rodata').replace('SECTION .text','.section .text')
    code=re.sub(r'^dd (JUMP_\d+)$',r'.quad \1',code,flags=re.M)
    # F881 has two4-byte local pops in DOS. Host slots are8bytes, while its
    # callback pointer remainsDWORD alongside an unrelated returnWORD.
    code=code.replace('FUNC_000881:\npush rbp\nmov rbp,rsp\nadd rsp,-8','FUNC_000881:\npush rbp\nmov rbp,rsp\nadd rsp,-16')
    code=code.replace('call QWORD PTR [rbp-0x8]','mov r11d,DWORD PTR [rbp-0x8]\ncall r11')
    if 'FUNC_000881:\npush rbp\nmov rbp,rsp\nadd rsp,-16' not in code:raise ValueError('F881 local-stack adaptation missing')
    # NASM bare ADD symbol is an immediate address, unlike GAS memory ADD.
    code=re.sub(r'^(add \w+,)(DATA_\d+)$',r'\1OFFSET FLAT:\2',code,flags=re.M)
    text=library+'\n.section .text\n'+code+'\n'+settlement_text+'\n'
    text+='''.section .text
_strcat:
 mov eax,DWORD PTR [rsp+8]
 mov edx,DWORD PTR [rsp+16]
 mov r9d,eax
system_strcat_find:
 cmp BYTE PTR [rax],0
 je system_strcat_copy
 inc eax
 jmp system_strcat_find
system_strcat_copy:
 mov cl,BYTE PTR [rdx]
 mov BYTE PTR [rax],cl
 inc eax
 inc edx
 test cl,cl
 jne system_strcat_copy
 mov eax,r9d
 ret
.section .data
.align 8
DATA_007723: .quad FUNC_001467
DATA_007730: .quad FUNC_001463
DATA_007731: .quad FUNC_001483
DATA_007732: .quad FUNC_001491
DATA_007735: .quad FUNC_001486
DATA_007736: .quad FUNC_001489
DATA_007747: .quad FUNC_001515
DATA_007183: .byte 32,0
DATA_007184: .byte 32,0
'''
    constants=stellar.constants(data_source,original)
    for number,key in stellar.TABLES.items():
        text+='DATA_%06d:\n'%number
        for value in constants['tables'][key]:text+=('.long FUNC_%06d\n'%value if number==7125 and value else '.long %d\n'%value)
    marker=bytes.fromhex('0000a8050008cc09500ba60cdb0df70e');at=original.find(marker);lut=original[at:at+4096]
    if sha(lut)!='1bb88ff59cdc392b0c116d26a7f4ec1b9504fdfe42909f522d5ba9cbfcd02ef0':raise ValueError('Original sqrt LUT mismatch')
    text+='DATA_007977:\n.short '+','.join(str(x) for x in struct.unpack('<2048H',lut))+'\n'
    text+=metadata_assembly(data)
    text+='\n.section .bss\n.align 16\n'
    for number in [8843,8844,8845,8846,8847,8848,8849,8850,8851,8852,8853,8854,8855,8856,8912,8913]:
        text+='DATA_%06d: .zero 8\n'%number
    text+='DATA_008792: .zero '+str(147*68)+'\n.set DATA_008793,DATA_008792+38\n'
    metadata={'source_procedure_hashes':hashes,'names':name_meta,'settlements':settlement_meta,'stellar_constant_block_sha256':constants['constant_block_sha256']}
    return text,metadata

def full_assembly(source,original,data_source,data):
    text,metadata=full_library_assembly(source,original,data_source,data)
    text+='\n.section .text\n.global _start\n_start:\n mov esp,OFFSET FLAT:system_stack_end\nnext_system:\n mov esp,OFFSET FLAT:system_stack_end\n xor r8d,r8d\n'
    text+=f'''read_system:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:system_input
 add rsi,r8
 mov edx,{INPUT}
 sub edx,r8d
 syscall
 test eax,eax
 jle system_finished
 add r8d,eax
 cmp r8d,{INPUT}
 jne read_system
 cld
 mov esi,OFFSET FLAT:system_input+{RECORD_OFFSET}
 mov edi,OFFSET FLAT:system_records
 mov ecx,{BANK}
 rep movsb
 mov rax,{GUARD}
 mov QWORD PTR [system_guard_before],rax
 mov QWORD PTR [system_guard_after],rax
 mov edi,OFFSET FLAT:system_name_context
 xor eax,eax
 mov ecx,128
 rep stosb
 mov DWORD PTR [system_return],0
'''
    mapping={'index':'system_index','seed_a':'DATA_008843','seed_b':'DATA_008844','depth':'DATA_008849','counter':'DATA_008846','body_count_byte':'DATA_008847','star_count_byte':'DATA_008848','planet_counter':'system_planet_counter','moon_counter':'system_moon_counter','third_counter':'system_third_counter','population_raw':'DATA_008854','system_id':'DATA_008853','language':'DATA_007128','star_quota':'DATA_008851','largest_mass':'DATA_008852','port_count_byte':'DATA_008855','orbital_count_byte':'DATA_008856'}
    for field,label in mapping.items():text+=' mov eax,DWORD PTR [system_input+%d]\n mov DWORD PTR [%s],eax\n'%(FIELDS.index(field)*4,label)
    text+=''' cmp DWORD PTR [system_input],3
 je source_full_system
 cmp DWORD PTR [system_input],4
 je source_full_callback
 cmp DWORD PTR [system_input],2
 je source_full_children
 cmp DWORD PTR [system_input],1
 je source_full_binary
'''
    def push_field(field):return ' mov eax,DWORD PTR [system_input+%d]\n push rax\n'%(FIELDS.index(field)*4)
    text+=' push OFFSET FLAT:system_third_counter\n push OFFSET FLAT:system_moon_counter\n push OFFSET FLAT:system_planet_counter\n push OFFSET FLAT:system_name_context\n push OFFSET FLAT:system_input+%d\n'%NAME_OFFSET
    for field in ['distance','multiplier','parent','mass']:text+=push_field(field)
    text+=' push OFFSET FLAT:system_index\n push OFFSET FLAT:system_records\n call FUNC_000881\n add rsp,88\n movzx eax,ax\n mov DWORD PTR [system_return],eax\n jmp system_emit\nsource_full_binary:\n push OFFSET FLAT:system_name_context\n push OFFSET FLAT:system_input+%d\n'%NAME_OFFSET
    for field in ['secondary_distance','distance','multiplier','mass','parent']:text+=push_field(field)
    text+=' push OFFSET FLAT:system_index\n push OFFSET FLAT:system_records\n call FUNC_000877\n add rsp,72\n movzx eax,ax\n mov DWORD PTR [system_return],eax\n jmp system_emit\nsource_full_children:\n'
    for field in ['third_counter','moon_counter','planet_counter']:text+=push_field(field)
    text+=' push OFFSET FLAT:system_name_context\n push OFFSET FLAT:system_input+%d\n'%NAME_OFFSET
    for field in ['mass_divisor','mass_limit','start_radius','random_value','parent']:text+=push_field(field)
    text+=' push OFFSET FLAT:system_index\n push OFFSET FLAT:system_records\n call FUNC_000897\n add rsp,96\n jmp system_emit\nsource_full_callback:\n push OFFSET FLAT:system_name_context\n'
    text+=push_field('mass')+' push OFFSET FLAT:system_index\n push OFFSET FLAT:system_records\n'
    text+=' mov eax,DWORD PTR [system_input+%d]\n'% (FIELDS.index('callback')*4)
    for callback in [883,884,885,886]:text+=' cmp eax,%d\n je system_callback_%d\n'%(callback,callback)
    text+=' call FUNC_000887\n jmp system_callback_done\n'
    for callback in [883,884,885,886]:text+='system_callback_%d:\n call FUNC_%06d\n jmp system_callback_done\n'%(callback,callback)
    text+='''system_callback_done:
 add rsp,32
 jmp system_emit
source_full_system:
 mov eax,DWORD PTR [system_input+'''+str(FIELDS.index('seed_a')*4)+''']
 mov DWORD PTR [system_parameters],eax
 mov eax,DWORD PTR [system_input+'''+str(FIELDS.index('mass')*4)+''']
 mov DWORD PTR [system_parameters+4],eax
 mov eax,DWORD PTR [system_input+'''+str(FIELDS.index('num_stars')*4)+''']
 mov DWORD PTR [system_parameters+8],eax
 mov eax,DWORD PTR [system_input+'''+str(FIELDS.index('system_id')*4)+''']
 mov DWORD PTR [system_parameters+12],eax
 mov eax,DWORD PTR [system_input+'''+str(FIELDS.index('population_raw')*4)+''']
 mov DWORD PTR [system_parameters+16],eax
 mov esi,OFFSET FLAT:system_input+'''+str(NAME_OFFSET)+'''
 mov edi,OFFSET FLAT:system_parameters+20
 mov ecx,64
 rep movsb
 mov esi,OFFSET FLAT:source_handcrafted_templates
 mov edi,OFFSET FLAT:DATA_008792
 mov ecx,'''+str(147*68)+'''
 rep movsb
 push OFFSET FLAT:system_parameters
 push OFFSET FLAT:system_records
 call FUNC_000878
 add rsp,16
 xor ecx,ecx
system_scan_sentinel:
 imul eax,ecx,68
 cmp DWORD PTR [system_records+eax],0
 je system_scan_done
 inc ecx
 cmp ecx,128
 jb system_scan_sentinel
system_scan_done:
 mov DWORD PTR [system_index],ecx
system_emit:
'''
    text+=f''' mov rax,{GUARD}
 cmp QWORD PTR [system_guard_before],rax
 jne system_canary_failed
 cmp QWORD PTR [system_guard_after],rax
 jne system_canary_failed
 mov esi,OFFSET FLAT:system_records
 mov edi,OFFSET FLAT:system_output
 mov ecx,{BANK}
 rep movsb
'''
    mapping.update({'return_word':'system_return','port_count_byte':'DATA_008855','orbital_count_byte':'DATA_008856'})
    byte_fields={'depth','body_count_byte','star_count_byte','port_count_byte','orbital_count_byte','star_quota'}
    for index,field in enumerate(OUTPUT_FIELDS):
        text+=(' movzx eax,BYTE PTR [%s]\n' if field in byte_fields else ' mov eax,DWORD PTR [%s]\n')%mapping[field]
        text+=' mov DWORD PTR [system_output+%d],eax\n'%(BANK+index*4)
    text+=f''' mov esi,OFFSET FLAT:system_output
 mov edx,{OUTPUT}
system_write:
 mov eax,1
 mov edi,1
 syscall
 test eax,eax
 jle system_write_failed
 add esi,eax
 sub edx,eax
 jnz system_write
 jmp next_system
system_canary_failed:
 mov eax,60
 mov edi,94
 syscall
system_write_failed:
 mov eax,60
 mov edi,72
 syscall
system_finished:
 mov eax,60
 xor edi,edi
 syscall
.section .rodata
source_handcrafted_templates:
'''
    bank=bytearray(147*68)
    records=json.loads((PROJECT/'data/ffe_handcrafted_records.json').read_text())['records']
    for key,value in records.items():bank[int(key)*68:(int(key)+1)*68]=bytes.fromhex(value['record_hex'])
    text+='.byte '+','.join(str(x) for x in bank)+'\n.section .bss\n.align 16\n'
    text+=f'''system_input: .zero {INPUT}
system_parameters: .zero 84
system_index: .zero 4
system_return: .zero 4
system_planet_counter: .zero 4
system_moon_counter: .zero 4
system_third_counter: .zero 4
system_name_context: .zero 128
.align 16
system_guard_before: .zero 8
system_records: .zero {BANK}
system_guard_after: .zero 8
system_output: .zero {OUTPUT}
.align 16
system_stack: .zero 1048576
system_stack_end:
.section .note.GNU-stack,"",@progbits
'''
    return text,metadata

def blank_case(operation,**values):
    row={key:0 for key in FIELDS};row.update(operation=operation,system_id=0x02a49718,largest_mass=200000000,mass=200000000,system_name='Control',records={},fill_byte=0)
    row.update(values);return row

def make_cases(data):
    factory=module(PROJECT/'tools/rebuild_source_body_factory_native.py','system_factory_cases')
    classification=module(PROJECT/'tools/rebuild_planet_classification_native.py','system_classification_cases')
    stellar=json.loads((PROJECT/'data/ffe_stellar_factory.json').read_text())
    rows=[];rng=random.Random(0x877878897)
    for old in factory.make_cases(stellar):
        values={key:value for key,value in old.items() if key in FIELDS or key in ['system_name','records']}
        rows.append(blank_case(0,group='full_f881_'+str(old.get('group','constructor')),**values))
    base=bytearray.fromhex(json.loads((PROJECT/'data/ffe_handcrafted_records.json').read_text())['records']['4']['record_hex'])
    # Callback controls use a genuine positive packed parent/body mass. Their
    # temperatures/exponents are INPUT perturbations, never predicted outputs.
    old_callbacks=classification.make_cases()
    for number,old in enumerate(old_callbacks):
        body=bytearray.fromhex(old['record_hex']);mantissa=0x4ac0
        exponent=struct.unpack_from('<H',body,2)[0]
        struct.pack_into('<I',body,0,(exponent<<16)|mantissa)
        index=int(old['index']);records={str(index):body.hex()}
        for prior in range(index):
            ancestor=bytearray(base);struct.pack_into('<I',ancestor,0,0x005b5f5e);struct.pack_into('<H',ancestor,8,0)
            ancestor[38:62]=b'Ancestor\0'+bytes(15);records[str(prior)]=ancestor.hex()
        values={key:value for key,value in old.items() if key in FIELDS}
        rows.append(blank_case(4,group='full_callback_thresholds',records=records,language=[0,3][number&1],port_count_byte=[0,17,18,127,128][number%5],**values))
    for mass in [0x01036640,30000000,169999999,170000000,172000000,175000000,200000000,1000000000,0xfffffffe]:
        for seed in [1,0x12345678,0x80000000,0xffffffff]:
            rows.append(blank_case(1,group='binary_source_branches',mass=mass,seed_a=seed,seed_b=rng.getrandbits(32),multiplier=0xffffffff,distance=0,secondary_distance=(seed&0xffff)>>3))
    parent=bytearray(base);struct.pack_into('<I',parent,0,0x005b5f5e);struct.pack_into('<H',parent,8,0);parent[38:62]=b'Parent\0'+bytes(17)
    for start in [8,16,0x100,0x800,0x1000,0x3fff,0x4000,0x4001,0x7fff]:
        for seed in [1,0x12345678,0xffffffff]:
            rows.append(blank_case(2,group='recursive_child_hierarchy',index=1,parent=1,records={'0':parent.hex()},seed_a=seed,seed_b=rng.getrandbits(32),random_value=seed,start_radius=start,mass_limit=200000000,mass_divisor=200000000>>8,star_quota=2))
    for stars in [0,1,2,3,4]:
        for mass in [0x01036640,50000000,172000000,200000000,1000000000,0xfffffffe]:
            for population in [0,51,200,500,0xffffffff]:
                seed=rng.getrandbits(32) or 1
                rows.append(blank_case(3,group='complete_procedural_system',mass=mass,seed_a=seed,num_stars=stars,population_raw=population,system_id=rng.choice([0x02a49718,0x02ae1718,0x1aa89738,0x12345678]),system_name='System'))
    handcrafted=json.loads((PROJECT/'data/ffe_worlds.json').read_text())
    for system in handcrafted['systems']:
        rows.append(blank_case(3,group='complete_handcrafted_dispatch',seed_a=0,mass=200000000,system_id=int(system['system_id']),system_name=str(system['name_en'])[:21]))
    rows.append(blank_case(3,group='complete_handcrafted_fallback',seed_a=0,system_id=0x01234567,system_name='Riedquat'))
    # Independently generated actual F830/F860 headers, not synthesized masses.
    definition_path=PROJECT/'tests/fixtures/source_system_definition_native.json'
    if definition_path.exists():
        definitions=json.loads(definition_path.read_text());candidates=[]
        if definitions.get('source_commit')!=COMMIT or definitions.get('source_sha256')!=SOURCE_SHA:raise ValueError('Definition provenance mismatch')
        for source_case in definitions['cases']:
            if source_case['return_s32']!=0:continue
            raw=bytes.fromhex(source_case['params_hex']);seed,mass,stars,system_id,population=struct.unpack_from('<5I',raw)
            # Source massFFFFFFFF advances F881 beyond its23classes and reads
            # DATA7126=0x1234 as a callback address. Reject that undefined path.
            if mass==0xffffffff:continue
            name=raw[20:].split(bytes([0]),1)[0].decode('ascii')
            candidates.append(blank_case(3,group='actual_f860_header',mass=mass,seed_a=seed,num_stars=stars,population_raw=population,system_id=system_id,system_name=name))
        chosen=[];seen_ids=set();seen_classes=set()
        for row in candidates:
            if row['seed_a']==0 and row['system_id'] not in seen_ids:chosen.append(row);seen_ids.add(row['system_id'])
        # Five spread body classes for each real multiplicity0..5, plus all
        # handcrafted headers. This exercises actual ordinary/binary/special
        # callers instead of spending the corpus on one rare high-mass class.
        thresholds=stellar['tables']['mass_thresholds']
        for stars in range(6):
            variants={}
            for row in candidates:
                if row['num_stars']!=stars or row['system_id'] in seen_ids:continue
                mass_bin=next(i for i,bound in enumerate(thresholds) if not bound or row['mass']<bound)
                variants.setdefault(mass_bin,row)
            available=[variants[key] for key in sorted(variants)]
            if len(available)<5:raise ValueError('Insufficient real multiplicity classes')
            for position in [0,(len(available)-1)//4,(len(available)-1)//2,3*(len(available)-1)//4,len(available)-1]:
                row=available[position];chosen.append(row);seen_ids.add(row['system_id'])
        if len(chosen)!=42:raise ValueError('Expected42 independent real system headers')
        rows.extend(chosen)
        for row in candidates:
            if row['system_id']==0x02ae1718 and row['system_id'] not in seen_ids:
                special=dict(row);special['group']='actual_f860_special_polaris';rows.append(special);break
        # Caller-only corrections to four original zero-radius F897 loops.
        # Inputs are explicit; the unchanged native F878 supplies every expected
        # output byte. The corresponding raw headers are witnessed separately.
        safe_seeds={1919437698:461500744,44586598:1382453576,44578542:3303985480,111736477:983390536}
        for row in candidates:
            if row['system_id'] not in safe_seeds:continue
            fixed=dict(row);fixed['original_seed_a']=row['seed_a'];fixed['seed_a']=safe_seeds[row['system_id']]
            fixed['group']='actual_f860_zero_radius_caller_fix';fixed['caller_correction_policy']='zero-root-orbit-radius-seed-step-v1';rows.append(fixed)
    return rows

def bank_for(row):
    bank=bytearray([row.get('fill_byte',0)])*BANK
    for key,value in row['records'].items():
        encoded=bytes.fromhex(value)
        if len(encoded)!=68 or not 0<=int(key)<SLOTS:raise ValueError('Invalid native input record')
        bank[int(key)*68:(int(key)+1)*68]=encoded
    return bytes(bank)

def packet(row):
    name=row['system_name'].encode('ascii')
    if len(name)>62 or b'\0' in name:raise ValueError('Invalid original name input')
    return struct.pack('<%dI'%len(FIELDS),*(row[key] for key in FIELDS))+name.ljust(64,b'\0')+bank_for(row)

def run_full(source,original,data_source,data,rows=None):
    native,meta=full_assembly(source,original,data_source,data)
    if rows is None:rows=make_cases(data)
    ordered=rows+list(reversed(rows));packets=b''.join(packet(row) for row in ordered)
    with tempfile.TemporaryDirectory(prefix='ffe-full-systems-') as directory:
        root=Path(directory);(root/'native.s').write_text(native)
        subprocess.run(['as','--64',str(root/'native.s'),'-o',str(root/'native.o')],check=True)
        subprocess.run(['ld','-m','elf_x86_64',str(root/'native.o'),'-o',str(root/'native')],check=True)
        outputs=[subprocess.run([str(root/'native')],input=packets,stdout=subprocess.PIPE,check=True,timeout=90).stdout for _ in range(3)]
    if any(value!=outputs[0] for value in outputs[1:]):raise ValueError('Full-system fresh-process outputs differ')
    output=outputs[0]
    if len(output)!=len(ordered)*OUTPUT:raise ValueError('Incomplete full-system native output')
    for index,row in enumerate(rows):
        result=output[index*OUTPUT:(index+1)*OUTPUT];reverse=len(ordered)-1-index
        if result!=output[reverse*OUTPUT:(reverse+1)*OUTPUT]:raise ValueError('Full-system reverse mismatch '+str(index)+' '+row['group'])
        before=bank_for(row);after=result[:BANK]
        row['expected_records']={str(i):after[i*68:(i+1)*68].hex() for i in range(SLOTS) if after[i*68:(i+1)*68]!=before[i*68:(i+1)*68]}
        row['expected_bank_sha256']=sha(after)
        row['expected']=dict(zip(OUTPUT_FIELDS,struct.unpack_from('<%dI'%len(OUTPUT_FIELDS),result,BANK)))
    return rows,{'source_procedure_hashes':meta['source_procedure_hashes'],'names_source_procedure_hashes':meta['names']['source_procedure_hashes'],'settlement_source_metadata':meta['settlements'],'adapted_assembly_sha256':sha(native.encode()),'native_ordered_output_sha256':sha(output),'input_packets_sha256':sha(packets),'fresh_process_runs':3,'reverse_repeat_count':len(rows),'guard_canaries_unchanged':True,'record_bank_slots':SLOTS,'source_f881_entry_limit':60}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--data-source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'))
    parser.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_system_native.json')
    args=parser.parse_args();source_raw=args.source.read_bytes();data_raw=args.data_source.read_bytes();original=args.executable.read_bytes()
    if sha(source_raw)!=ASM_SHA or sha(data_raw)!=DATA_SHA or sha(original)!=SOURCE_SHA:raise ValueError('Unreviewed source system inputs')
    source=source_raw.decode();data_source=data_raw.decode();data=metadata_constants(data_source,original)
    (PROJECT/'data/ffe_system_metadata.json').write_text(json.dumps(data,separators=(',',':'))+'\n')
    rows,meta=run_full(source,original,data_source,data)
    fixture={'schema':1,'source_variant':VARIANT,'source_sha256':SOURCE_SHA,'source_assembly_sha256':ASM_SHA,'source_data_sha256':DATA_SHA,'source_commit':COMMIT,'scope':'Complete pinned F877/F878/F881/F896/F897 hierarchy and F883..F893 populated callbacks; native raw records, real names/settlements and actual metadata. No original F879 surface, galaxy placement or live SI physics claim.',**meta,**execute_metadata(source,data)}
    for operation,name in enumerate(['factory_cases','binary_cases','children_cases','system_cases','callback_cases']):fixture[name]=[row for row in rows if row['operation']==operation]
    fixture['case_count']=len(rows)
    fixture['input_resources_sha256']={str(path.relative_to(PROJECT)):sha(path.read_bytes()) for path in [PROJECT/'data/ffe_handcrafted_records.json',PROJECT/'data/ffe_stellar_factory.json',PROJECT/'data/ffe_settlement_rules.json',PROJECT/'data/ffe_planet_names.json',PROJECT/'data/ffe_system_metadata.json']}
    definition_path=PROJECT/'tests/fixtures/source_system_definition_native.json'
    if definition_path.exists():fixture['definition_header_corpus']={'path':str(definition_path.relative_to(PROJECT)),'sha256':sha(definition_path.read_bytes()),'selected_native_cases':42,'undefined_source_headers_rejected':[{'system_id':0x02af3686,'mass':0xffffffff,'source_f881_out_of_bounds_callback_u32':0x1234}]}
    args.output.write_text(json.dumps(fixture,separators=(',',':'))+'\n')
    print('SOURCE SYSTEM NATIVE:',len(rows),'full constructor/hierarchy/callback cases;',fixture['metadata_case_count'],'metadata controls; threefresh/reverse agree')

if __name__=='__main__':main()
