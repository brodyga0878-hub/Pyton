#!/usr/bin/env python3
"""Run original F883--F887 callbacks and F894 as host-native controls.

Accepted cases execute complete original callbacks. F891/F892/F893 are
non-returning unsupported-path gates: no fake callback return is supplied, and
no partial classified record is published as an expected result.
"""
from __future__ import annotations
import argparse, hashlib, json, random, struct, subprocess, sys, tempfile
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
SOURCE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
FIELDS=['callback','index','mass','population_raw','system_id','seed_a','seed_b']
RECORD_BYTES=60*68
PACKET_BYTES=7*4+68
OUTPUT_BYTES=RECORD_BYTES+5*4
NUMBERS=[883,884,885,886,887,894]

def digest(data:bytes)->str:return hashlib.sha256(data).hexdigest()

def make_cases():
    rng=random.Random(0x883887)
    records=json.loads((PROJECT/'data/ffe_handcrafted_records.json').read_text())
    template=bytes.fromhex(records['records']['4']['record_hex'])
    rows=[]
    populations=[0,3,4,6,7,8,9,15,16,29,30,44,45,50,51,79,80,119,120,149,150,169,170,179,180,199,200,241,242,249,250,0x7fffffff,0x80000000,0xffffffff]
    masses=[0,1,0xffff,0x10000,0x1000000,0x7fffffff,0x80000000,0xffffffff]
    seeds=[0,1,0xffff,0x80000000,0xffffffff,0x12345678,0x89abcdef]
    temperatures=sorted({t+d for t in [0,66,123,135,150,160,170,180,200,215,220,250,258,279,280,295,308,313,338,500,530,65535] for d in [-1,0,1] if 0<=t+d<=65535})
    def add(callback,temp,population,mass,system=0x02a49718,uid=None):
        i=len(rows);body=bytearray(template)
        struct.pack_into('<H',body,0x24,temp)
        struct.pack_into('<H',body,2,[0,70,71,72,0x7fff,0x8000,0xffff][i%7])
        struct.pack_into('<I',body,4,rng.getrandbits(32) if uid is None else uid)
        rows.append(dict(zip(FIELDS,[callback,[0,1,59][i%3],mass,population,system,seeds[i%len(seeds)] if i%3 else rng.getrandbits(32),seeds[(i+3)%len(seeds)] if i%4 else rng.getrandbits(32)]),record_hex=body.hex()))
    for callback in range(883,888):
        for i,temp in enumerate(temperatures):
            for branch,pop in enumerate([0,3,populations[(i*3+callback)%len(populations)],populations[(i*7+11)%len(populations)],0xffffffff]):
                add(callback,temp,pop,masses[(i+branch)%len(masses)])
    for callback in range(883,888):
        for pop in populations:
            for temp in [170,215,220,279,313]:add(callback,temp,pop,masses[(pop+temp)%len(masses)])
    for system,uid in [(0x1aa89738,0),(0x02ae1718,0x5b5ff290),(0x0eb6973d,0x70740190)]:
        for temp in [169,170,190,215,216]:
            for population in [0,3,199,200]:add(883,temp,population,0xffffffff,system,uid)
    for _ in range(600):add(rng.randrange(883,888),rng.randrange(65536),rng.choice(populations),rng.getrandbits(32),rng.getrandbits(32))
    return rows

def initial_buffer(row):
    data=bytearray([0xa5])*RECORD_BYTES
    target=int(row['index'])*68
    data[target:target+68]=bytes.fromhex(row['record_hex'])
    return bytes(data)

def assembly(source):
    sys.path.insert(0,str(PROJECT/'recovered-history/ground_harness/tools'))
    from native_reference import procedures
    lines,hashes=procedures(source,NUMBERS)
    text='\n'.join(lines)
    head='''.intel_syntax noprefix
.code64
.section .text
.global _start
'''+text+f'''
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
 mov edx,{PACKET_BYTES}
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,{PACKET_BYTES}
 jne read_more
 cld
 mov edi,OFFSET FLAT:records
 mov ecx,{RECORD_BYTES}
 mov al,0xa5
 rep stosb
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [target_index],eax
 imul eax,eax,68
 mov edi,OFFSET FLAT:records
 add edi,eax
 mov esi,OFFSET FLAT:input+28
 mov ecx,68
 rep movsb
 mov eax,DWORD PTR [input+12]
 mov DWORD PTR [DATA_008854],eax
 mov eax,DWORD PTR [input+16]
 mov DWORD PTR [DATA_008853],eax
 mov eax,DWORD PTR [input+20]
 mov DWORD PTR [DATA_008843],eax
 mov eax,DWORD PTR [input+24]
 mov DWORD PTR [DATA_008844],eax
 mov DWORD PTR [supported],1
 mov DWORD PTR [helper_id],0
 push OFFSET FLAT:name_context
 mov eax,DWORD PTR [input+8]
 push rax
 push OFFSET FLAT:target_index
 push OFFSET FLAT:records
 mov eax,DWORD PTR [input]
 sub eax,883
 mov eax,DWORD PTR [callback_table+rax*4]
 call rax
 add rsp,32
 jmp emit_result
FUNC_000891:
 mov DWORD PTR [helper_id],891
 jmp unsupported_gate
FUNC_000892:
 mov DWORD PTR [helper_id],892
 jmp unsupported_gate
FUNC_000893:
 mov DWORD PTR [helper_id],893
unsupported_gate:
 # This gate NEVER returns to a source callback. The callback did not finish;
 # only its unsupported-callee identity is exposed to fixture consumers.
 mov DWORD PTR [supported],0
 mov esp,OFFSET FLAT:stack_end
emit_result:
 mov eax,DWORD PTR [supported]
 mov DWORD PTR [records+{RECORD_BYTES}],eax
 mov eax,DWORD PTR [helper_id]
 mov DWORD PTR [records+{RECORD_BYTES+4}],eax
 mov eax,DWORD PTR [DATA_008843]
 mov DWORD PTR [records+{RECORD_BYTES+8}],eax
 mov eax,DWORD PTR [DATA_008844]
 mov DWORD PTR [records+{RECORD_BYTES+12}],eax
 mov eax,DWORD PTR [target_index]
 mov DWORD PTR [records+{RECORD_BYTES+16}],eax
 mov esi,OFFSET FLAT:records
 mov edx,{OUTPUT_BYTES}
write_more:
 mov eax,1
 mov edi,1
 syscall
 test eax,eax
 jle write_failed
 add esi,eax
 sub edx,eax
 jnz write_more
 jmp next_case
write_failed:
 mov eax,60
 mov edi,72
 syscall
finished:
 mov eax,60
 xor edi,edi
 syscall
.section .data
.align 8
callback_table: .long FUNC_000883,FUNC_000884,FUNC_000885,FUNC_000886,FUNC_000887
.section .bss
.align 16
input: .zero {PACKET_BYTES}
records: .zero {OUTPUT_BYTES}
target_index: .zero 4
supported: .zero 4
helper_id: .zero 4
DATA_008843: .zero 4
DATA_008844: .zero 4
DATA_008853: .zero 4
DATA_008854: .zero 4
name_context: .zero 256
.align 16
stack: .zero 65536
stack_end:
.section .note.GNU-stack,"",@progbits
'''
    return head,hashes

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/rebuilt_planet_classification_native.json')
    args=parser.parse_args()
    original=args.executable.read_bytes();raw=args.source.read_bytes()
    if digest(original)!=SOURCE_SHA or digest(raw)!=ASM_SHA:raise ValueError('Unreviewed original sources')
    source,hashes=assembly(raw.decode())
    cases=make_cases();ordered=cases+list(reversed(cases))
    packets=b''.join(struct.pack('<7I',*(row[k] for k in FIELDS))+bytes.fromhex(row['record_hex']) for row in ordered)
    with tempfile.TemporaryDirectory(prefix='ffe-planet-classifiers-') as directory:
        work=Path(directory);(work/'native.s').write_text(source)
        subprocess.run(['as','--64',str(work/'native.s'),'-o',str(work/'native.o')],check=True)
        subprocess.run(['ld','-m','elf_x86_64',str(work/'native.o'),'-o',str(work/'native')],check=True)
        outputs=[subprocess.run([str(work/'native')],input=packets,stdout=subprocess.PIPE,check=True,timeout=45).stdout for _ in range(3)]
    if any(output!=outputs[0] for output in outputs[1:]):raise ValueError('Fresh native processes differ')
    output=outputs[0]
    if len(output)!=len(ordered)*OUTPUT_BYTES:raise ValueError('Incomplete native classifier output')
    supported_count=0;gates={};callbacks={}
    for i,row in enumerate(cases):
        result=output[i*OUTPUT_BYTES:(i+1)*OUTPUT_BYTES]
        reverse=len(ordered)-1-i
        if result!=output[reverse*OUTPUT_BYTES:(reverse+1)*OUTPUT_BYTES]:raise ValueError('Reverse interleaving differs')
        at=row['index']*68;before=initial_buffer(row)
        if result[:at]!=before[:at] or result[at+68:RECORD_BYTES]!=before[at+68:]:raise ValueError('Classifier changed a non-target record')
        supported,helper,seed_a,seed_b,index=struct.unpack_from('<5I',result,RECORD_BYTES)
        if index!=row['index']:raise ValueError('Classifier changed the record index')
        expected={'supported':bool(supported),'helper_id':helper}
        if supported:
            if helper:raise ValueError('Accepted native case reached an unsupported helper')
            expected.update(record_hex=result[at:at+68].hex(),seed_a=seed_a,seed_b=seed_b)
            supported_count+=1
        else:
            if helper not in [891,892,893]:raise ValueError('Unknown unsupported-callee gate')
            gates[str(helper)]=gates.get(str(helper),0)+1
        row['expected']=expected;callbacks[str(row['callback'])]=callbacks.get(str(row['callback']),0)+1
    fixture={'schema':1,'revision':'original-planet-classification-callbacks-native-v1','source_sha256':SOURCE_SHA,'source_assembly_sha256':ASM_SHA,'source_procedure_hashes':hashes,'adapted_assembly_sha256':digest(source.encode()),'scope':'Complete original F883-F887 with real F894 when no unresolved naming/settlement call occurs. F891/F892/F893 are non-returning unsupported-path gates; partial records from gated paths are not expected classified results. No full F881 naming, populated world factory or live-world integration.','case_count':len(cases),'supported_case_count':supported_count,'unsupported_case_count':len(cases)-supported_count,'unsupported_helper_counts':gates,'callback_counts':callbacks,'non_target_records_unchanged':True,'index_unchanged':True,'fresh_process_runs':3,'reverse_repeat_count':len(cases),'native_ordered_output_sha256':digest(output),'input_packets_sha256':digest(packets),'cases':cases}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(fixture,separators=(',',':'))+'\n')
    print(json.dumps({k:fixture[k] for k in ['case_count','supported_case_count','unsupported_case_count','unsupported_helper_counts','callback_counts','native_ordered_output_sha256']},indent=2))

if __name__=='__main__':main()
