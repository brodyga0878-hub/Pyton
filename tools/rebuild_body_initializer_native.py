#!/usr/bin/env python3
"""NEW host-only control for complete original F882 packed-record initialization.

Uses unchanged original integer instructions and original math callees; only
NASM spelling/host stack slot widths are adapted. Inputs deliberately mix real
record templates with diagnostic parameters, not a claimed procedural galaxy.
"""
from __future__ import annotations
import argparse,hashlib,json,random,re,struct,subprocess,sys,tempfile
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
SOURCE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
LUT_SHA='1bb88ff59cdc392b0c116d26a7f4ec1b9504fdfe42909f522d5ba9cbfcd02ef0'
NATIVE_NUMBERS=[882,1467,1463,1482,1483,1486,1489,1491,1515]
RECORDS=60
BUFFER_BYTES=RECORDS*68
HEADER_FIELDS=['index','parent','multiplier','distance','mass','seed_a','seed_b','depth','counter']
PACKET_BYTES=4*len(HEADER_FIELDS)+BUFFER_BYTES
OUTPUT_BYTES=BUFFER_BYTES+4

def digest(data):return hashlib.sha256(data).hexdigest()

def make_cases():
    rules=json.loads((PROJECT/'data/ffe_settlement_rules.json').read_text())
    handcrafted=json.loads((PROJECT/'data/ffe_handcrafted_records.json').read_text())
    templates=[bytes.fromhex(value) for value in rules['templates'].values()]
    root=bytearray.fromhex(handcrafted['records']['0']['record_hex'])
    planet=bytearray.fromhex(handcrafted['records']['4']['record_hex'])
    rng=random.Random(0x882)
    cases=[]
    def add(index,parent,multiplier,distance,mass,seed_a,seed_b,depth,counter,temperature,light,parent_mass,star_type=22,chain=False):
        rows={}
        if index:
            ancestor=bytearray(root)
            struct.pack_into('<I',ancestor,0,parent_mass)
            struct.pack_into('<H',ancestor,8,0)
            struct.pack_into('<H',ancestor,10,star_type)
            struct.pack_into('<I',ancestor,0x1c,light)
            struct.pack_into('<H',ancestor,0x42,seed_a&65535)
            rows[0]=ancestor
        if index>1:
            ancestor=bytearray(planet)
            struct.pack_into('<I',ancestor,0,parent_mass)
            struct.pack_into('<H',ancestor,8,1 if chain else 0)
            struct.pack_into('<I',ancestor,0xe,0x005b6000)
            struct.pack_into('<I',ancestor,0x1c,light>>1)
            struct.pack_into('<H',ancestor,0x42,seed_b&65535)
            rows[1]=ancestor
        body=bytearray(templates[len(cases)%len(templates)])
        struct.pack_into('<H',body,0x24,temperature)
        rows[index]=body
        case=dict(zip(HEADER_FIELDS,[index,parent,multiplier,distance,mass,seed_a,seed_b,depth,counter]))
        case['records']={str(key):value.hex() for key,value in sorted(rows.items())}
        cases.append(case)
    # Explicit word/register limits, zero orbit, special parent-type period
    # adjustment, zero/positive/negative source mantissas, and heating paths.
    seeds=[0,1,2,0x7fff,0x8000,0xffff,0x12345678,0x7fffffff,0x80000000,0xffffffff]
    for i,a in enumerate(seeds):
        for b in seeds:
            for branch in range(4):
                index,parent=[(0,0),(1,1),(2,2),(59,2)][branch]
                add(index,parent,[0,1,0x10000,0xffffffff][branch],
                    [0,1,0xffff,0x1234ffff][branch],a,a,b,b,a,
                    [0,288,999,1000][branch],a,[0,0x004f4000,0x004fc000,0x007f7fff][branch],
                    star_type=0 if i&1 else 22,chain=bool(i&2))
    for i in range(1024):
        index=[0,1,2,3,59][i%5]
        parent=0 if index==0 else rng.randrange(min(index,2)+1)
        add(index,parent,rng.getrandbits(32),rng.getrandbits(32),rng.getrandbits(32),
            rng.getrandbits(32),rng.getrandbits(32),rng.getrandbits(32),rng.getrandbits(32),
            [0,287,999,1000,65535][i%5],rng.getrandbits(32) if i&1 else 0,
            rng.choice([0,0x004f4000,0x004fc000,0x005b6000,0xffffffff]),
            star_type=i&1,chain=bool(i&2))
    return cases

def record_buffer(case):
    result=bytearray(BUFFER_BYTES)
    for key,value in case['records'].items():
        index=int(key);raw=bytes.fromhex(value)
        if not 0<=index<RECORDS or len(raw)!=68:raise ValueError('Invalid diagnostic record')
        result[index*68:(index+1)*68]=raw
    return bytes(result)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/rebuilt_body_initializer_native.json')
    args=parser.parse_args()
    original=args.executable.read_bytes();asm_raw=args.source.read_bytes()
    if digest(original)!=SOURCE_SHA or digest(asm_raw)!=ASM_SHA:raise ValueError('Unreviewed original source')
    # The uploaded executable confirms the disputed LOW16 sign extension.
    orientation=bytes.fromhex('f76c93040fbfc0c1f811668944bb42')
    orientation_offset=original.find(orientation)
    if orientation_offset!=0x2b367 or original.find(orientation,orientation_offset+1)>=0:
        raise ValueError('Original F882 IMUL / MOVSX AX / SAR17 sequence differs')
    start=original.find(bytes.fromhex('558bec83c4ec5356578b750c8b5d080fb74518'))
    if start!=0x2b1d0:raise ValueError('Original F882 entry signature differs')
    at=original.find(bytes.fromhex('0000a8050008cc09500ba60cdb0df70e'))
    table=original[at:at+4096]
    if at<0 or digest(table)!=LUT_SHA:raise ValueError('Original sqrt constants differ')
    sys.path.insert(0,str(PROJECT/'recovered-history/ground_harness/tools'))
    from native_reference import procedures
    source=asm_raw.decode()
    lines,hashes=procedures(source,NATIVE_NUMBERS)
    code='\n'.join(lines)
    assembly='''.intel_syntax noprefix
.code64
.section .text
.global _start
'''+code+f'''
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
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
 mov esi,OFFSET FLAT:input+36
 mov edi,OFFSET FLAT:records
 mov ecx,{BUFFER_BYTES}
 rep movsb
 mov eax,DWORD PTR [input+20]
 mov DWORD PTR [DATA_008843],eax
 mov eax,DWORD PTR [input+24]
 mov DWORD PTR [DATA_008844],eax
 mov eax,DWORD PTR [input+28]
 mov DWORD PTR [DATA_008849],eax
 mov eax,DWORD PTR [input+32]
 mov DWORD PTR [DATA_008846],eax
 mov eax,DWORD PTR [input+16]
 push rax
 mov eax,DWORD PTR [input+12]
 push rax
 mov eax,DWORD PTR [input+8]
 push rax
 mov eax,DWORD PTR [input+4]
 push rax
 mov eax,DWORD PTR [input]
 push rax
 push OFFSET FLAT:records
 call FUNC_000882
 add rsp,48
 mov eax,DWORD PTR [DATA_008846]
 mov DWORD PTR [records+{BUFFER_BYTES}],eax
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
DATA_007723: .quad FUNC_001467
DATA_007730: .quad FUNC_001463
DATA_007731: .quad FUNC_001483
DATA_007732: .quad FUNC_001491
DATA_007735: .quad FUNC_001486
DATA_007736: .quad FUNC_001489
DATA_007747: .quad FUNC_001515
DATA_007977:
'''+ '\n'.join('.short '+str(value) for value in struct.unpack('<2048H',table))+f'''
.section .bss
.align 16
input: .zero {PACKET_BYTES}
records: .zero {OUTPUT_BYTES}
DATA_008843: .zero 4
DATA_008844: .zero 4
DATA_008846: .zero 4
DATA_008849: .zero 4
.align 16
stack: .zero 65536
stack_end:
.section .note.GNU-stack,"",@progbits
'''
    cases=make_cases();ordered=cases+list(reversed(cases))
    packets=b''.join(struct.pack('<9I',*(row[field] for field in HEADER_FIELDS))+record_buffer(row) for row in ordered)
    with tempfile.TemporaryDirectory(prefix='ffe-f882-native-') as directory:
        work=Path(directory);(work/'f882.s').write_text(assembly)
        subprocess.run(['as','--64',str(work/'f882.s'),'-o',str(work/'f882.o')],check=True)
        subprocess.run(['ld','-m','elf_x86_64',str(work/'f882.o'),'-o',str(work/'f882')],check=True)
        results=[subprocess.run([str(work/'f882')],input=packets,stdout=subprocess.PIPE,check=True,timeout=30).stdout for _ in range(3)]
    if any(result!=results[0] for result in results[1:]):raise ValueError('Fresh-process F882 controls differ')
    result=results[0]
    if len(result)!=OUTPUT_BYTES*len(ordered):raise ValueError('Incomplete original F882 controls')
    for index,row in enumerate(cases):
        raw=result[index*OUTPUT_BYTES:(index+1)*OUTPUT_BYTES]
        repeat=len(ordered)-1-index
        if raw!=result[repeat*OUTPUT_BYTES:(repeat+1)*OUTPUT_BYTES]:raise ValueError('Interleaved F882 controls differ')
        target=row['index']*68;buffer=record_buffer(row)
        if raw[:target]!=buffer[:target] or raw[target+68:BUFFER_BYTES]!=buffer[target+68:]:raise ValueError('Original F882 unexpectedly changed another record')
        row['expected_record_hex']=raw[target:target+68].hex()
        row['expected_counter_u32']=struct.unpack_from('<I',raw,BUFFER_BYTES)[0]
    report={'schema':1,'revision':'new-full-f882-native-v1','source_sha256':SOURCE_SHA,'source_assembly_sha256':ASM_SHA,'source_procedure_hashes':hashes,'adapted_assembly_sha256':digest(assembly.encode()),'scope':'Complete original F882 and actual original packed arithmetic callees, with original sqrt bytes. New diagnostic inputs built from original record templates; not original F881 generation, real procedural systems, epochs, ephemerides, SI units or live Android physics. Only host stack slot widths and assembler spelling adapted.','orientation_executable_offset':hex(orientation_offset),'orientation_executable_bytes':orientation.hex(),'orientation_semantics':'IMUL full32 seed; MOVSX EAX,AX retains signed LOW16; SAR EAX,17. Not a signed32-square right shift.','record_count':RECORDS,'case_count':len(cases),'non_target_records_unchanged':True,'same_process_reverse_repeat_checks':len(cases),'fresh_process_runs':3,'fresh_process_outputs_identical':True,'native_ordered_output_sha256':digest(result),'cases':cases}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(report,separators=(',',':'))+'\n')
    print('Original complete F882 controls:',len(cases),'; three fresh processes; reverse repeats:',len(cases),'; other records unchanged')

if __name__=='__main__':main()
