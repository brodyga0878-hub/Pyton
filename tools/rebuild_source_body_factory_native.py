#!/usr/bin/env python3
"""Execute original F881 across its stellar and low-mass ordinal-name paths.

F881/F882, all original classification/remnant callbacks, RNG and packed math
run as native host instructions. F891/F892/F893 are non-returning boundaries;
their partial records/state are never published as accepted fixture results.
The host ELF is a test oracle only and is not part of the Android runtime.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import random
import re
import struct
import subprocess
import tempfile

PROJECT=Path(__file__).resolve().parents[1]
SPEC=importlib.util.spec_from_file_location('ffe_stellar_oracle',PROJECT/'tools/rebuild_world_factory_native.py')
BASE=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BASE)
SOURCE_SHA=BASE.SOURCE_SHA
ASM_SHA=BASE.ASM_SHA
DATA_SHA=BASE.DATA_SHA
FIELDS=BASE.FIELDS+['population_raw','system_id']
STATE_FIELDS=BASE.OUTPUT_FIELDS.copy()
OUTPUT_FIELDS=['supported','helper_id']+STATE_FIELDS
RECORD_BYTES=60*68
NAME_OFFSET=len(FIELDS)*4
RECORD_OFFSET=NAME_OFFSET+64
PACKET_BYTES=RECORD_OFFSET+RECORD_BYTES
OUTPUT_BYTES=RECORD_BYTES+len(OUTPUT_FIELDS)*4
GUARD=0x4f5241434c453838

def digest(value:bytes)->str:return hashlib.sha256(value).hexdigest()

def buffer_for(row:dict)->bytes:
    data=bytearray(RECORD_BYTES)
    for key,encoded in row['records'].items():
        index=int(key)
        assert 0<=index<60
        raw=bytes.fromhex(encoded)
        assert len(raw)==68
        data[index*68:(index+1)*68]=raw
    return bytes(data)

def make_cases(data:dict)->list[dict]:
    rows=[]
    # Retain the independently established stellar domain as composition controls.
    for original in BASE.make_cases(data):
        row=original.copy();row.update(population_raw=0,system_id=0x02a49718)
        row['group']='stellar_regression';rows.append(row)
    rng=random.Random(0x881883887)
    source=json.loads((PROJECT/'data/ffe_handcrafted_records.json').read_text())['records']
    template=bytes.fromhex(source['4']['record_hex'])
    def add(mass:int,*,index=2,parent=1,depth=0,planet=0,moon=0,third=0,
            multiplier=0x01000000,distance=16,light=0,population=0,
            seed_a=0x12345678,seed_b=0x89abcdef,parent_named=False,
            parent_name='Parent',system=0x02a49718,group='low_boundary'):
        records={}
        for i in range(min(index,2)):
            record=bytearray(68)
            # Input values, not predicted results. A valid packed solar-parent
            # mass and controllable luminosity exercise the real F882 heating.
            struct.pack_into('<I',record,0,0x005b5f5e if i==0 else 0x00494ac0)
            struct.pack_into('<H',record,8,0 if i==0 else 1)
            struct.pack_into('<H',record,10,22 if i==0 else 10)
            struct.pack_into('<I',record,0x1c,light if i==0 else 0)
            text=(parent_name if i==parent-1 else 'Ancestor').encode('ascii')
            assert len(text)<=21 and all(32<=x<=126 for x in text)
            record[0x26:0x26+len(text)+1]=text+b'\0'
            if i==parent-1 and parent_named:record[0x3f]=0x80
            records[str(i)]=record.hex()
        if index<60:records[str(index)]=template.hex()
        row=dict(zip(FIELDS,[index,parent,multiplier,distance,mass,seed_a,seed_b,
                            depth,rng.getrandbits(32),rng.randrange(256),rng.randrange(256),
                            planet,moon,third,population,system]))
        row.update(system_name='System',records=records,group=group)
        rows.append(row)
    masses={0,16999999}
    for bound in data['tables']['mass_thresholds'][:11]:
        for delta in [-1,0,1]:
            if 0<=bound+delta<0x01036640:masses.add(bound+delta)
    counts=[0,8,9,10,18,19,20,127,254,255,256,0x7fffffff,0xfffffffe,0xffffffff]
    depths=[0,1,2,255,256,257,258,0xffffffff]
    for mass in sorted(masses):
        for i,depth in enumerate(depths):
            count=counts[(mass+i)%len(counts)]
            add(mass,depth=depth,planet=count,moon=count,third=count,
                index=[1,2,3,59][i%4],parent=1 if i%2==0 else 2,
                multiplier=[0,1,0x10000,0xffffffff][i%4],
                distance=[0,1,0xffff,0x1234ffff][i%4])
            # index1 has only one valid parent; fix requests before execution.
            if rows[-1]['parent']>rows[-1]['index']:raise AssertionError('Invalid parent domain')
    # Exact source ordinal code is deliberately not a generic decimal formatter.
    for depth in depths:
        for count in counts:
            add(100000,depth=depth,planet=count,moon=count,third=count,
                parent_name='123456789012345678901',group='ordinal_bytes')
    populations=[0,3,4,6,7,8,9,15,16,29,30,50,51,79,80,119,120,149,150,199,200,249,250,0x7fffffff,0x80000000,0xffffffff]
    for mass in [0,1,4,5,11,12,49,50,199,200,1799,1800,19999,20000,99999,100000,799999,800000,1999999,2000000,16999999]:
        for light in [0,1,2,4,5,8,10,12,16,100]:
            for population in [0,4,200]:
                add(mass,light=light,population=population,
                    seed_a=rng.getrandbits(32),seed_b=rng.getrandbits(32),group='classification_heating')
    for mass in [1,5,12,50,200,1800,20000,100000,800000,2000000]:
        for depth in [0,1,2,256,0xffffffff]:
            add(mass,depth=depth,parent_named=True,group='parent_named_gate')
    for system,uid in [(0x1aa89738,0),(0x02ae1718,0x5b5ff290),(0x0eb6973d,0x70740190)]:
        for light in [2,3,4,5]:
            for population in [0,3,199,200]:
                add(200,light=light,population=population,system=system,
                    seed_b=uid,group='special_port_gate')
    for mass in [0,1,50,200,1799,20000,16999999,17000000,0xfffffffe]:
        add(mass,index=60,parent=0,planet=0xffffffff,moon=0xffffffff,
            third=0xffffffff,parent_named=True,group='capacity')
    for _ in range(640):
        add(rng.randrange(0x01036640),index=rng.choice([2,3,59]),parent=rng.choice([1,2]),
            depth=rng.choice(depths),planet=rng.getrandbits(32),moon=rng.getrandbits(32),
            third=rng.getrandbits(32),multiplier=rng.getrandbits(32),distance=rng.getrandbits(32),
            light=rng.choice([0,1,4,10,100,0xffff,0xffffffff]),population=rng.choice(populations),
            seed_a=rng.getrandbits(32),seed_b=rng.getrandbits(32),
            parent_named=rng.randrange(13)==0,group='random_registers')
    return rows

def assembly(source:str,original:bytes,data:dict)->tuple[str,dict]:
    # Reuse the reviewed ABI adaptation, then extend the included ORIGINAL
    # procedure set and boundary/report wrapper. No original decision is mocked.
    BASE.NUMBERS=[881,882,883,884,885,886,887,888,889,890,894,1467,1463,1482,1483,1486,1489,1491,1515]
    BASE.FIELDS=FIELDS
    BASE.OUTPUT_FIELDS=OUTPUT_FIELDS
    BASE.PACKET_BYTES=PACKET_BYTES
    BASE.OUTPUT_BYTES=OUTPUT_BYTES
    text,hashes=BASE.assembly(source,original,data)
    for old,new in [('input+120','input+'+str(RECORD_OFFSET)),('input+56','input+'+str(NAME_OFFSET))]:
        assert old in text,old
        text=text.replace(old,new)
    text=text.replace('next_case:\n xor r8d,r8d','next_case:\n mov esp,OFFSET FLAT:stack_end\n xor r8d,r8d',1)
    before=' push OFFSET FLAT:third_counter\n'
    setup=f''' mov eax,DWORD PTR [input+{FIELDS.index('population_raw')*4}]
 mov DWORD PTR [DATA_008854],eax
 mov eax,DWORD PTR [input+{FIELDS.index('system_id')*4}]
 mov DWORD PTR [DATA_008853],eax
 mov DWORD PTR [supported],1
 mov DWORD PTR [helper_id],0
 mov DWORD PTR [return_word],0
 mov rax,{GUARD}
 mov QWORD PTR [record_guard_before],rax
 mov QWORD PTR [record_guard_after],rax
'''
    assert text.count(before)==1
    text=text.replace(before,setup+before,1)
    marker=' mov DWORD PTR [return_word],eax\n'
    emit=f'''emit_result:
 mov rax,{GUARD}
 cmp QWORD PTR [record_guard_before],rax
 jne canary_failed
 cmp QWORD PTR [record_guard_after],rax
 jne canary_failed
 mov esi,OFFSET FLAT:records
 mov edi,OFFSET FLAT:output
 mov ecx,{RECORD_BYTES}
 rep movsb
'''
    assert text.count(marker)==1
    text=text.replace(marker,marker+emit,1)
    text=re.sub(r'\[records\+(\d+)\]',lambda m:'[output+'+m[1]+']' if int(m[1])>=RECORD_BYTES else m[0],text)
    writer=f' mov esi,OFFSET FLAT:records\n mov edx,{OUTPUT_BYTES}\nwrite_more:'
    assert writer in text
    text=text.replace(writer,f' mov esi,OFFSET FLAT:output\n mov edx,{OUTPUT_BYTES}\nwrite_more:',1)
    stub_start=text.index('FUNC_000883:\nFUNC_000884:\n')
    stub_end=text.index('.section .data',stub_start)
    gates=''
    for helper in [891,892,893]:
        gates+=f'FUNC_{helper:06d}:\n mov DWORD PTR [helper_id],{helper}\n jmp unsupported_gate\n'
    gates+='''unsupported_gate:
 # Never return to an unfinished source callback. Only its identity is public.
 mov DWORD PTR [supported],0
 mov esp,OFFSET FLAT:stack_end
 jmp emit_result
canary_failed:
 mov eax,60
 mov edi,94
 syscall
'''
    text=text[:stub_start]+gates+text[stub_end:]
    old=f'records: .zero {OUTPUT_BYTES}'
    new=f'record_guard_before: .zero 8\nrecords: .zero {RECORD_BYTES}\nrecord_guard_after: .zero 8\noutput: .zero {OUTPUT_BYTES}'
    assert old in text
    text=text.replace(old,new,1)
    bss='name_context: .zero 64'
    assert bss in text
    text=text.replace(bss,bss+'\nsupported: .zero 4\nhelper_id: .zero 4\nDATA_008853: .zero 4\nDATA_008854: .zero 4',1)
    return text,hashes

def main()->None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--data-source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'))
    parser.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_body_factory_native.json')
    args=parser.parse_args()
    original=args.executable.read_bytes();raw=args.source.read_bytes();data_raw=args.data_source.read_bytes()
    if digest(original)!=SOURCE_SHA or digest(raw)!=ASM_SHA or digest(data_raw)!=DATA_SHA:raise ValueError('Unreviewed original sources')
    data=BASE.constants(data_raw.decode(),original)
    cases=make_cases(data)
    native,hashes=assembly(raw.decode(),original,data)
    ordered=cases+list(reversed(cases))
    packets=b''.join(struct.pack('<16I',*(row[k] for k in FIELDS))+row['system_name'].encode('ascii').ljust(64,b'\0')+buffer_for(row) for row in ordered)
    with tempfile.TemporaryDirectory(prefix='ffe-full-f881-') as directory:
        work=Path(directory);(work/'native.s').write_text(native)
        subprocess.run(['as','--64',str(work/'native.s'),'-o',str(work/'native.o')],check=True)
        subprocess.run(['ld','-m','elf_x86_64',str(work/'native.o'),'-o',str(work/'native')],check=True)
        outputs=[subprocess.run([str(work/'native')],input=packets,stdout=subprocess.PIPE,check=True,timeout=60).stdout for _ in range(3)]
    if any(value!=outputs[0] for value in outputs[1:]):raise ValueError('Fresh native processes differ')
    output=outputs[0]
    if len(output)!=len(ordered)*OUTPUT_BYTES:raise ValueError('Incomplete native outputs')
    accepted=0;blocked={};bins={};groups={};capacities=0
    for i,row in enumerate(cases):
        result=output[i*OUTPUT_BYTES:(i+1)*OUTPUT_BYTES]
        reverse=len(ordered)-1-i
        if result!=output[reverse*OUTPUT_BYTES:(reverse+1)*OUTPUT_BYTES]:raise ValueError('Reverse order changes native output')
        before=buffer_for(row);at=row['index']*68
        if row['index']<60:
            if result[:at]!=before[:at] or result[at+68:RECORD_BYTES]!=before[at+68:]:raise ValueError('Native factory wrote another record')
        elif result[:RECORD_BYTES]!=before:raise ValueError('Capacity case changed records')
        fields=dict(zip(OUTPUT_FIELDS,struct.unpack_from('<'+str(len(OUTPUT_FIELDS))+'I',result,RECORD_BYTES)))
        expected={'supported':bool(fields['supported']),'helper_id':fields['helper_id']}
        if fields['supported']:
            if fields['helper_id']:raise ValueError('Accepted case reached unsupported helper')
            expected.update({key:fields[key] for key in STATE_FIELDS})
            if row['index']<60:row['expected_record_hex']=result[at:at+68].hex()
            else:capacities+=1
            accepted+=1
        else:
            helper=str(fields['helper_id'])
            if helper not in ['891','892','893']:raise ValueError('Unexpected blocked helper')
            blocked[helper]=blocked.get(helper,0)+1
        row['expected']=expected
        mass=row['mass'];mass_bin=0
        while data['tables']['mass_thresholds'][mass_bin] and mass>=data['tables']['mass_thresholds'][mass_bin]:mass_bin+=1
        bins[str(mass_bin)]=bins.get(str(mass_bin),0)+1
        groups[row['group']]=groups.get(row['group'],0)+1
    fixture={'schema':1,'revision':'original-f881-ordinal-and-stellar-native-v1','source_sha256':SOURCE_SHA,'source_assembly_sha256':ASM_SHA,'source_procedure_hashes':hashes,'adapted_assembly_sha256':digest(native.encode()),'source_constant_block_sha256':data['constant_block_sha256'],'scope':'Actual F881 across all23 mass bins, exact ordinal names and F882/classification/remnant callbacks/RNG. Unfinished F891/F892/F893 paths leave through non-returning gates; partial state/records are omitted from expectations. No full populated naming, system hierarchy, SI ephemerides or live-world generation claim.','case_count':len(cases),'supported_case_count':accepted,'unsupported_case_count':len(cases)-accepted,'unsupported_helper_counts':blocked,'mass_bin_counts':bins,'case_groups':groups,'capacity_cases':capacities,'name_field_bound_bytes':21,'records_buffer_guard_canaries_unchanged':True,'non_target_records_unchanged':True,'fresh_process_runs':3,'reverse_repeat_count':len(cases),'native_ordered_output_sha256':digest(output),'input_packets_sha256':digest(packets),'cases':cases}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(fixture,separators=(',',':'))+'\n')
    print(json.dumps({key:fixture[key] for key in ['case_count','supported_case_count','unsupported_case_count','unsupported_helper_counts','mass_bin_counts','case_groups','capacity_cases','native_ordered_output_sha256']},indent=2))

if __name__=='__main__':main()
