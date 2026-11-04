#!/usr/bin/env python3
"""Original F881 execution on its bounded high-mass/stellar domain.

This does not simulate naming/classification results in Python. Actual F881,
F882, remnant callbacks, RNG and packed math run as host-native instructions.
Unsupported planetary callbacks and F893 trap instead of returning fake data.
"""
from __future__ import annotations
import argparse,hashlib,json,random,re,struct,subprocess,sys,tempfile
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
SOURCE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
DATA_SHA='34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850'
TABLES={7119:'type_codes',7120:'model_indices',7121:'mass_thresholds',7122:'return_words',7123:'temperatures',7124:'light_outputs',7125:'callback_ids'}
FIELDS=['index','parent','multiplier','distance','mass','seed_a','seed_b','depth','counter','body_count_byte','star_count_byte','planet_counter','moon_counter','third_counter']
OUTPUT_FIELDS=['next_index','return_word','seed_a','seed_b','depth','counter','body_count_byte','star_count_byte','planet_counter','moon_counter','third_counter']
RECORD_BYTES=60*68
PACKET_BYTES=len(FIELDS)*4+64+RECORD_BYTES
OUTPUT_BYTES=RECORD_BYTES+len(OUTPUT_FIELDS)*4
NUMBERS=[881,882,888,889,890,894,1467,1463,1482,1483,1486,1489,1491,1515]

def digest(value):return hashlib.sha256(value).hexdigest()
def constants(source,original):
    tables={};raw=[]
    for number,name in TABLES.items():
        block=re.search(r'^DATA_%06d:[^\n]*\n(.*?)(?=^DATA_\d+:)'%number,source,re.M|re.S)[1]
        data=bytearray()
        for line in block.splitlines():
            line=line.split(';')[0].strip()
            if line.startswith('db '):data.extend(int(x.strip(),0) for x in line[3:].split(','))
            elif line.startswith('dd '):
                value=int(re.search(r'FUNC_(\d+)',line)[1]) if 'FUNC_' in line else int(line[3:],0)
                data.extend(struct.pack('<I',value))
        tables[name]=list(struct.unpack('<%dI'%(len(data)//4),data))
        if number!=7125:raw.append(data)
    blob=b''.join(raw);offset=original.find(blob)
    if len(blob)!=556 or offset<0 or original.find(blob,offset+1)>=0:raise ValueError('Original class constants do not match executable uniquely')
    return {'schema':1,'source_sha256':SOURCE_SHA,'source_assembly_sha256':ASM_SHA,'source_data_sha256':DATA_SHA,'constant_block_executable_offset':offset,'constant_block_sha256':digest(blob),'tables':tables}

def make_cases(data):
    rng=random.Random(0xF881)
    handcrafted=json.loads((PROJECT/'data/ffe_handcrafted_records.json').read_text())
    root=bytes.fromhex(handcrafted['records']['0']['record_hex'])
    template=bytes.fromhex(handcrafted['records']['4']['record_hex'])
    cases=[]
    def add(mass,index,parent,multiplier,distance,seed_a,seed_b,depth,counter,body_count,star_count,planet_count=0):
        records={}
        if index>0:
            star=bytearray(root);star[38:62]=b'Parent\0'+bytes(17);star[8:10]=b'\0\0'
            records['0']=star.hex()
        if index>1:
            other=bytearray(root);other[38:62]=b'Secondary\0'+bytes(14);other[8:10]=b'\1\0'
            records['1']=other.hex()
        if index<60:records[str(index)]=template.hex()
        row=dict(zip(FIELDS,[index,parent,multiplier,distance,mass,seed_a,seed_b,depth,counter,body_count,star_count,planet_count,7,11]))
        row['system_name']=['Achenar','Alpha Centauri','Sol','', '123456789012345678901'][len(cases)%5]
        row['records']=records;cases.append(row)
    masses={0x01036640,0xfffffffe}
    for bound in data['tables']['mass_thresholds']:
        for delta in [-1,0,1]:
            if 0x01036640<=bound+delta<=0xfffffffe:masses.add(bound+delta)
    seeds=[0,1,0x7fff,0x8000,0xffff,0x12345678,0x80000000,0xffffffff]
    for i,mass in enumerate(sorted(masses)):
        for branch in range(8):
            index=[0,1,2,3,59,0,2,60][branch];parent=0 if index in [0,60] else min(index,1+(branch&1))
            add(mass,index,parent,[0,1,0x10000,0xffffffff][branch%4],[0,1,0xffff,0x1234ffff][branch%4],seeds[branch],seeds[(branch+3)%8],branch,[0,1,2,3,0x7fffffff,0x80000000,0xffffffff,19][branch],branch*43&255,[0,1,25,26,254,255,127,128][branch])
    for i in range(512):
        index=rng.choice([0,1,2,3,59]);parent=0 if index==0 else rng.randrange(min(index,2)+1)
        add(rng.randrange(0x01036640,0xffffffff),index,parent,rng.getrandbits(32),rng.getrandbits(32),rng.getrandbits(32),rng.getrandbits(32),rng.getrandbits(32),rng.getrandbits(32),rng.randrange(256),rng.randrange(256),rng.getrandbits(32))
    return cases

def buffer(row):
    result=bytearray(RECORD_BYTES)
    for key,hex_value in row['records'].items():result[int(key)*68:(int(key)+1)*68]=bytes.fromhex(hex_value)
    return bytes(result)

def assembly(source,original,data):
    sys.path.insert(0,str(PROJECT/'recovered-history/ground_harness/tools'))
    from native_reference import procedures
    lines,hashes=procedures(source,NUMBERS)
    text='\n'.join(lines)
    # Two original 4-byte local stack pops become 8-byte host pops. Their
    # actual local addresses remain unchanged inside the larger reserved area.
    text=text.replace('FUNC_000881:\npush rbp\nmov rbp,rsp\nadd esp, -0x8','FUNC_000881:\npush rbp\nmov rbp,rsp\nadd rsp,-16')
    text=text.replace('FUNC_000881:\npush rbp\nmov rbp,rsp\nadd rsp,-8','FUNC_000881:\npush rbp\nmov rbp,rsp\nadd rsp,-16')
    # F881 stores a DWORD pointer next to its return WORD; reading QWORD would
    # mix unrelated locals. r11 is outside the original32-register namespace.
    text=text.replace('call QWORD PTR [rbp-0x8]','mov r11d,DWORD PTR [rbp-0x8]\ncall r11')
    if 'mov r11d,DWORD PTR [rbp-0x8]' not in text:raise ValueError('Local callback adaptation did not apply')
    if 'FUNC_000881:\npush rbp\nmov rbp,rsp\nadd rsp,-16' not in text:raise ValueError('Host local allocation adaptation did not apply')
    marker=bytes.fromhex('0000a8050008cc09500ba60cdb0df70e');at=original.find(marker)
    sqrt=original[at:at+4096]
    if digest(sqrt)!='1bb88ff59cdc392b0c116d26a7f4ec1b9504fdfe42909f522d5ba9cbfcd02ef0':raise ValueError('Original sqrt mismatch')
    head=f'''.intel_syntax noprefix
.code64
.section .text
.global _start
'''+text+f'''
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
 mov esi,OFFSET FLAT:input+120
 mov edi,OFFSET FLAT:records
 mov ecx,{RECORD_BYTES}
 rep movsb
'''
    globals_map={'index':'next_index','seed_a':'DATA_008843','seed_b':'DATA_008844','depth':'DATA_008849','counter':'DATA_008846','body_count_byte':'DATA_008847','star_count_byte':'DATA_008848','planet_counter':'planet_counter','moon_counter':'moon_counter','third_counter':'third_counter'}
    for name,label in globals_map.items():head+=f' mov eax,DWORD PTR [input+{FIELDS.index(name)*4}]\n mov DWORD PTR [{label}],eax\n'
    head+=''' push OFFSET FLAT:third_counter
 push OFFSET FLAT:moon_counter
 push OFFSET FLAT:planet_counter
 push OFFSET FLAT:name_context
 push OFFSET FLAT:input+56
 mov eax,DWORD PTR [input+12]
 push rax
 mov eax,DWORD PTR [input+8]
 push rax
 mov eax,DWORD PTR [input+4]
 push rax
 mov eax,DWORD PTR [input+16]
 push rax
 push OFFSET FLAT:next_index
 push OFFSET FLAT:records
 call FUNC_000881
 add rsp,88
 movzx eax,ax
 mov DWORD PTR [return_word],eax
'''
    for i,name in enumerate(OUTPUT_FIELDS):
        label=globals_map.get(name,name)
        head+=f' mov eax,DWORD PTR [{label}]\n mov DWORD PTR [records+{RECORD_BYTES+i*4}],eax\n'
    head+=f''' mov esi,OFFSET FLAT:records
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
# Exact byte string primitives from the C ABI, not FFE naming substitutions.
_strlen:
 mov eax,DWORD PTR [rsp+8]
 mov edx,eax
strlen_loop:
 cmp BYTE PTR [rax],0
 je strlen_end
 inc eax
 jmp strlen_loop
strlen_end:
 sub eax,edx
 ret
_strcat:
 mov eax,DWORD PTR [rsp+8]
 mov r9d,eax
 mov edx,DWORD PTR [rsp+16]
strcat_scan:
 cmp BYTE PTR [rax],0
 je strcat_copy
 inc eax
 jmp strcat_scan
strcat_copy:
 mov cl,BYTE PTR [rdx]
 mov BYTE PTR [rax],cl
 inc eax
 inc edx
 test cl,cl
 jne strcat_copy
 mov eax,r9d
 ret
FUNC_000883:
FUNC_000884:
FUNC_000885:
FUNC_000886:
FUNC_000887:
FUNC_000893:
 # No unsupported naming/planetary branch may silently manufacture a result.
 mov eax,60
 mov edi,93
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
DATA_007183: .byte 32,0
DATA_007184: .byte 32,0
'''
    for number,name in TABLES.items():
        head+=f'DATA_{number:06d}:\n'
        for value in data['tables'][name]:head+=('.long FUNC_%06d\n'%value if number==7125 and value else '.long %d\n'%value)
    head+='DATA_007977:\n'+''.join('.short %d\n'%x for x in struct.unpack('<2048H',sqrt))
    head+=f'''.section .bss
.align 16
input: .zero {PACKET_BYTES}
records: .zero {OUTPUT_BYTES}
next_index: .zero 4
return_word: .zero 4
planet_counter: .zero 4
moon_counter: .zero 4
third_counter: .zero 4
name_context: .zero 64
DATA_008843: .zero 4
DATA_008844: .zero 4
DATA_008846: .zero 4
DATA_008847: .zero 4
DATA_008848: .zero 4
DATA_008849: .zero 4
.align 16
stack: .zero 65536
stack_end:
.section .note.GNU-stack,"",@progbits
'''
    return head,hashes

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    p.add_argument('--data-source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'))
    p.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    p.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/rebuilt_world_factory_native.json')
    args=p.parse_args();original=args.executable.read_bytes();raw=args.source.read_bytes();data_raw=args.data_source.read_bytes()
    if digest(original)!=SOURCE_SHA or digest(raw)!=ASM_SHA or digest(data_raw)!=DATA_SHA:raise ValueError('Unreviewed original sources')
    data=constants(data_raw.decode(),original)
    native,hashes=assembly(raw.decode(),original,data)
    cases=make_cases(data);ordered=cases+list(reversed(cases))
    packets=b''.join(struct.pack('<14I',*(row[k] for k in FIELDS))+row['system_name'].encode('ascii').ljust(64,b'\0')+buffer(row) for row in ordered)
    with tempfile.TemporaryDirectory(prefix='ffe-stellar-f881-') as directory:
        work=Path(directory);(work/'native.s').write_text(native)
        subprocess.run(['as','--64',str(work/'native.s'),'-o',str(work/'native.o')],check=True)
        subprocess.run(['ld','-m','elf_x86_64',str(work/'native.o'),'-o',str(work/'native')],check=True)
        outputs=[subprocess.run([str(work/'native')],input=packets,stdout=subprocess.PIPE,check=True,timeout=30).stdout for _ in range(3)]
    if any(o!=outputs[0] for o in outputs[1:]):raise ValueError('Fresh-process native factory outputs differ')
    output=outputs[0]
    if len(output)!=len(ordered)*OUTPUT_BYTES:raise ValueError('Incomplete factory outputs')
    for i,row in enumerate(cases):
        result=output[i*OUTPUT_BYTES:(i+1)*OUTPUT_BYTES]
        opposite=len(ordered)-1-i
        if result!=output[opposite*OUTPUT_BYTES:(opposite+1)*OUTPUT_BYTES]:raise ValueError('Reverse-order native factory outputs differ')
        target=row['index']*68;before=buffer(row)
        if row['index']<60:
            if result[:target]!=before[:target] or result[target+68:RECORD_BYTES]!=before[target+68:]:raise ValueError('Factory changed another record')
            row['expected_record_hex']=result[target:target+68].hex()
        elif result[:RECORD_BYTES]!=before:raise ValueError('Capacity sentinel changed records')
        row['expected']=dict(zip(OUTPUT_FIELDS,struct.unpack_from('<11I',result,RECORD_BYTES)))
    fixture={'schema':1,'revision':'new-bounded-stellar-f881-native-v1','source_sha256':SOURCE_SHA,'source_assembly_sha256':ASM_SHA,'source_procedure_hashes':hashes,'adapted_assembly_sha256':digest(native.encode()),'scope':'Unmodified F881 control flow on0x01036640..0xfffffffe stellar domain, realF882/all original packed math/remnant callbacksF888-F890/RNG894. Unsupported lower-mass callbacks and F893 abort; no claimed full planetary factory, populated naming, star-system generation or live integration.','minimum_mass':0x01036640,'maximum_mass':0xfffffffe,'source_constants':data,'case_count':len(cases),'non_target_records_unchanged':True,'reverse_repeat_count':len(cases),'fresh_process_runs':3,'native_ordered_output_sha256':digest(output),'cases':cases}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(fixture,separators=(',',':'))+'\n')
    (PROJECT/'data/ffe_stellar_factory.json').write_text(json.dumps(data,separators=(',',':'))+'\n')
    print('Native stellar F881:',len(cases),'cases; original records/state; three fresh processes and reverse repeats identical')

if __name__=='__main__':main()
