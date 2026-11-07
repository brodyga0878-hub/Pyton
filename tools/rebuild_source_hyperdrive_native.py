#!/usr/bin/env python3
"""Execute pinned original F833/F899..903/F1521, with DOS drive/spec bytes.

The host ABI only widens stack slots/addresses, loads one selected original
model specification, and bridges sqrt to x87 FSQRT. Source arithmetic, branch
selection, partial outputs and mutations execute as original instructions.
Expected results are never computed by a Python port of the hyperdrive rules.
"""
from __future__ import annotations
import argparse,hashlib,importlib.util,json,random,re,struct,subprocess,tempfile
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
DATA_SHA='34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850'
DRIVE_SHA='82659f368ab7b4298735b16b4f76276207a19d1b529526c4452c2c78569fe654'
NUMBERS=[833,899,900,901,902,903,1521,1538,2095]
OPS=['F903','F899','F901','F900','F902','F1521','F833','F833_F903']
INPUT_BYTES=426
OUTPUT_BYTES=454
GUARD=0x4859504552445249
SEEDS=[0x17385a2d,0x28496b3e,0x395a7c4f,0x4a6b8d50,0x5b7c9e61]


def sha(raw):return hashlib.sha256(raw).hexdigest()
def s32(v):return (int(v)&0x7fffffff)-(int(v)&0x80000000)
def block(source,n):
    a=re.search(r'^FUNC_%06d(?:_[A-Za-z0-9_]+)?:'%n,source,re.M)
    b=re.search(r'^FUNC_\d+(?:_[A-Za-z0-9_]+)?:',source[a.end():],re.M)
    return source[a.start():a.end()+b.start() if b else len(source)]
def byte_block(source,n):
    match=re.search(r'^DATA_%06d:[^\n]*\n(.*?)(?=^DATA_\d+:|\Z)'%n,source,re.M|re.S)
    raw=bytearray()
    for original in match[1].splitlines():
        line=original.split(';',1)[0].strip()
        if line.startswith('db '):
            for token in line[3:].split(','):raw.append(int(token.strip(),0)&255)
        elif line:raise ValueError('Unreviewed drive data directive '+line)
    return bytes(raw)


def resources(exe,data_source):
    drive=b''.join(byte_block(data_source,n)for n in [7187,7188,7189])
    if len(drive)!=240 or sha(drive)!=DRIVE_SHA or exe[884260:884500]!=drive:raise ValueError('Original DOS drive table differs')
    pe=struct.unpack_from('<I',exe,60)[0];base=struct.unpack_from('<I',exe,pe+52)[0]
    start=pe+24+struct.unpack_from('<H',exe,pe+20)[0]
    sections=[struct.unpack_from('<4I',exe,start+i*40+8)for i in range(struct.unpack_from('<H',exe,pe+6)[0])]
    def offset(pointer,n):
        for _,address,size,at in sections:
            delta=pointer-base-address
            if 0<=delta and delta+n<=size and at+delta+n<=len(exe):return at+delta
        raise ValueError('Unmapped original model/spec pointer')
    specs={}
    for model in range(15,72):
        descriptor=offset(struct.unpack_from('<I',exe,0xba8fc+model*4)[0],68)
        spec_at=offset(struct.unpack_from('<I',exe,descriptor+56)[0],24)
        raw=exe[spec_at:spec_at+24]
        specs[str(model)]={'model_index':model,'descriptor_executable_offset':descriptor,'spec_executable_offset':spec_at,
                           'spec_hex':raw.hex(),'spec_sha256':sha(raw),'mass_s16':struct.unpack_from('<h',raw,6)[0],
                           'capacity_s16':struct.unpack_from('<h',raw,8)[0]}
    return drive,specs


def assembly(source,drive):
    path=PROJECT/'recovered-history/ground_harness/tools/native_reference.py'
    spec=importlib.util.spec_from_file_location('hyperdrive_host_abi',path)
    adapter=importlib.util.module_from_spec(spec);spec.loader.exec_module(adapter)
    normalized=re.sub(r'FUNC_(\d{6})_[A-Za-z0-9_]+',r'FUNC_\1',source)
    normalized=re.sub(r'\[ebp\+0x([89a-f][0-9a-f]{7})\]',lambda m:'[ebp-0x%x]'%(0x100000000-int(m[1],16)),normalized)
    normalized=re.sub(r'add esp,0x([89a-f][0-9a-f]{7})',lambda m:'add esp,-0x%x'%(0x100000000-int(m[1],16)),normalized)
    lines,_=adapter.procedures(normalized,NUMBERS);text='\n'.join(lines)
    text=text.replace('qword [','QWORD PTR [')
    text=re.sub(r'\badd (e[a-z]{2}),DATA_(\d+)',r'add \1,OFFSET FLAT:DATA_\2',text)
    for n in [833,902,903]:
        text=text.replace('FUNC_%06d:\npush rbp\nmov rbp,rsp\nadd rsp,-8'%n,'FUNC_%06d:\npush rbp\nmov rbp,rsp\nadd rsp,-16'%n)
    # F833 pushes an inline eight-byte double, not a widened pointer argument.
    text=text.replace('call _sqrt\nadd rsp,16','call _sqrt\nadd rsp,8')
    # GAS needs a64-bit base spelling for this original stack allocation.
    text=text.replace('lea esp,[rbp-0xc]','lea rsp,[rbp-0xc]')
    return '.intel_syntax noprefix\n.code64\n.section .text\n'+text+f'''
_sqrt:
 fld QWORD PTR [rsp+8]
 fsqrt
 ret
.global _start
_start:
 mov esp,OFFSET FLAT:stack_end
 fninit
next_case:
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 lea rsi,[input+r8]
 mov edx,{INPUT_BYTES}
 sub edx,r8d
 syscall
 test eax,eax
 jz finished
 js failed
 add r8d,eax
 cmp r8d,{INPUT_BYTES}
 jb read_more
 mov rax,{GUARD}
 mov QWORD PTR [object_before],rax
 mov QWORD PTR [object_after],rax
 mov QWORD PTR [spec_before],rax
 mov QWORD PTR [spec_after],rax
 mov QWORD PTR [globals_before],rax
 mov QWORD PTR [globals_after],rax
 mov QWORD PTR [output_before],rax
 mov QWORD PTR [output_after],rax
 mov esi,OFFSET FLAT:input+64
 mov edi,OFFSET FLAT:ship_spec
 mov ecx,24
 rep movsb
 mov esi,OFFSET FLAT:input+88
 mov edi,OFFSET FLAT:object
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:output
 mov eax,0xa5a5a5a5
 mov ecx,454
 rep stosb
 mov eax,DWORD PTR [input+8]
 mov DWORD PTR [output+4],eax
 mov eax,DWORD PTR [input+12]
 mov DWORD PTR [DATA_008857],eax
 mov ax,WORD PTR [input+16]
 mov WORD PTR [DATA_008860],ax
 mov ax,WORD PTR [input+18]
 mov WORD PTR [DATA_008901],ax
 mov ax,WORD PTR [input+20]
 mov WORD PTR [DATA_008902],ax
 mov ax,WORD PTR [input+22]
 mov WORD PTR [DATA_008903],ax
 mov eax,DWORD PTR [input+24]
 mov DWORD PTR [DATA_008891],eax
 cmp DWORD PTR [input],4
 je ranges_case
 cmp DWORD PTR [input],5
 je multiply_case
 cmp DWORD PTR [input],6
 je distance_case
 cmp DWORD PTR [input],7
 je chain_distance
 jmp evaluate_case
chain_distance:
 call source_distance
 mov DWORD PTR [output+4],eax
 jmp evaluate_case
distance_case:
 call source_distance
 mov DWORD PTR [output+4],eax
 jmp return_value
source_distance:
 push QWORD PTR [input+52]
 push QWORD PTR [input+48]
 push QWORD PTR [input+44]
 push QWORD PTR [input+40]
 push QWORD PTR [input+36]
 push QWORD PTR [input+32]
 call FUNC_000833
 add rsp,48
 ret
multiply_case:
 push QWORD PTR [input+36]
 push QWORD PTR [input+32]
 call FUNC_001521
 add rsp,16
 jmp return_value
ranges_case:
 push OFFSET FLAT:output+28
 push QWORD PTR [input+28]
 call FUNC_000902
 add rsp,16
 jmp return_value
evaluate_case:
 cmp DWORD PTR [input],3
 je name_case
 push OFFSET FLAT:output+24
 push OFFSET FLAT:output+20
 push OFFSET FLAT:output+16
 push OFFSET FLAT:output+12
 push OFFSET FLAT:output+8
 push OFFSET FLAT:output+4
 push OFFSET FLAT:object
 cmp DWORD PTR [input],1
 je no_remove_wrapper
 cmp DWORD PTR [input],2
 je remove_wrapper
 pop rax
 pop rcx
 pop rdx
 pop rsi
 pop rdi
 pop r8
 pop r9
 push QWORD PTR [input+4]
 push r9
 push r8
 push rdi
 push rsi
 push rdx
 push rcx
 push rax
 call FUNC_000903
 add rsp,64
 jmp return_value
no_remove_wrapper:
 call FUNC_000899
 add rsp,56
 jmp return_value
remove_wrapper:
 call FUNC_000901
 add rsp,56
 jmp return_value
name_case:
 push OFFSET FLAT:output+24
 push OFFSET FLAT:output+8
 push OFFSET FLAT:object
 call FUNC_000900
 add rsp,24
return_value:
 mov DWORD PTR [output],eax
 mov edi,OFFSET FLAT:output+60
 mov eax,DWORD PTR [DATA_008857]
 stosd
 mov ax,WORD PTR [DATA_008860]
 stosw
 mov ax,WORD PTR [DATA_008901]
 stosw
 mov ax,WORD PTR [DATA_008902]
 stosw
 mov ax,WORD PTR [DATA_008903]
 stosw
 mov eax,DWORD PTR [DATA_008891]
 stosd
 mov esi,OFFSET FLAT:ship_spec
 mov ecx,24
 rep movsb
 mov esi,OFFSET FLAT:object
 mov ecx,338
 rep movsb
 mov rax,{GUARD}
 stosq
 stosq
 cmp QWORD PTR [object_before],rax
 jne failed
 cmp QWORD PTR [object_after],rax
 jne failed
 cmp QWORD PTR [spec_before],rax
 jne failed
 cmp QWORD PTR [spec_after],rax
 jne failed
 cmp QWORD PTR [globals_before],rax
 jne failed
 cmp QWORD PTR [globals_after],rax
 jne failed
 cmp QWORD PTR [output_before],rax
 jne failed
 cmp QWORD PTR [output_after],rax
 jne failed
 xor r8d,r8d
write_more:
 mov eax,1
 mov edi,1
 lea rsi,[output+r8]
 mov edx,{OUTPUT_BYTES}
 sub edx,r8d
 syscall
 test eax,eax
 jle failed
 add r8d,eax
 cmp r8d,{OUTPUT_BYTES}
 jb write_more
 jmp next_case
failed:
 mov eax,60
 mov edi,94
 syscall
finished:
 mov eax,60
 xor edi,edi
 syscall
.section .rodata
.align 8
DATA_007756: .quad FUNC_001538
DATA_007187: .byte '''+','.join(str(x)for x in drive)+'''
.equ DATA_007189,DATA_007187+40
# Actual F1538 executes; the host populates its bounded model slots with one
# selected descriptor pointing to this case's exact original input spec.
DATA_004681:
.rept 65536
.long descriptor
.endr
.section .data
descriptor: .zero 56
 .long ship_spec
 .zero 8
.section .bss
.align 8
input: .zero 426
object_before: .zero 8
object: .zero 338
object_after: .zero 8
spec_before: .zero 8
ship_spec: .zero 24
spec_after: .zero 8
globals_before: .zero 8
DATA_008857: .zero 4
DATA_008860: .zero 2
DATA_008901: .zero 2
DATA_008902: .zero 2
DATA_008903: .zero 2
DATA_008891: .zero 4
globals_after: .zero 8
output_before: .zero 8
output: .zero 454
output_after: .zero 8
.align 16
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
'''


def make_cases(specs,drive):
    rows=[];unsafe=[]
    def add(operation='F903',model=38,drive_index=2,distance=802,player=True,mutate_flag=1,
            fuel=65535,military=65535,waste=65534,cargo=0x12345678,status=0xa55a,player_id=None,
            spec_raw=None,domain='normal',**extra):
        spec=bytes.fromhex(specs[str(model)]['spec_hex'])if spec_raw is None else spec_raw
        body=bytearray((i*37+19)&255 for i in range(338))
        struct.pack_into('<I',body,0x82,model);body[0x86]=17 if player else 18;body[0xd0]=drive_index&255;body[0x119]=fuel&255
        row={'operation':operation,'domain':domain,'model_input_u32':model,'spec_hex':spec.hex(),'object_hex':body.hex(),
             'distance_raw_s32':s32(distance),'mutate_flag':mutate_flag,
             'globals':{'player_object_index_u32':17 if player_id is None else player_id,'status_u16':status,
                        'cargo_s32':s32(cargo),'hydrogen_u16':fuel&65535,'military_u16':military&65535,'waste_u16':waste&65535},
             'output_seed_u32':SEEDS.copy()}
        row.update(extra);rows.append(row)
    # Entire original ship family for the eight selectable F902 standard drives.
    for model in range(15,72):add('F902',model=model,domain='all_original_ship_ranges')
    original_spec=bytes.fromhex(specs['38']['spec_hex'])
    for mass in [0,1,99,100,101,32767,32768,65535]:
        for capacity in [0,5,6,7,11,12,13,23,24,25,79,80,81,149,150,151,249,250,251,399,400,401,599,600,601,32767,32768,65535]:
            raw=bytearray(original_spec);struct.pack_into('<HH',raw,6,mass,capacity)
            add('F902',spec_raw=raw,domain='signed_mass_capacity_boundaries')
    # F902 consumes only model input's LOW16, whereas F903 reads object model DWORD.
    add('F902',model_input_u32=0x12340026,domain='model_u16_argument')
    for model in [15,16,20,25,30,38,40,50,60,68,71]:
        mass=specs[str(model)]['mass_s16']
        if mass<=0:continue
        for drive_index in range(15):
            power=struct.unpack_from('<I',drive,drive_index*16)[0]
            maximum=power//mass
            for distance in sorted({0,1,maximum,max(0,maximum-1),maximum+1,802}):
                for player in [False,True]:
                    for mutate_flag in [1,2]:
                        add(model=model,drive_index=drive_index,distance=distance,player=player,mutate_flag=mutate_flag,domain='all_drive_classes')
    for drive_index in [0,1,2,9,10,12,13,14]:
        for fuel in [0,1,2,10,255,65535]:
            for player in [False,True]:
                for operation in ['F899','F901','F900']:
                    add(operation,drive_index=drive_index,player=player,fuel=fuel,military=fuel,domain='wrappers_fuel_boundaries')
    # Onlyflag2 mutates. Playeridentity is a DWORDcomparison, notlow-bytecomparison.
    for mutate_flag in [0,1,2,3,0xffffffff]:
        for drive_index in [2,10,13,14]:
            for player_id in [17,273,0xffffffff]:
                add(drive_index=drive_index,mutate_flag=mutate_flag,player_id=player_id,domain='flags_and_identity')
    # Negative distances are raw source controls, not user-facing valid routes.
    for distance in [-1,-30000,-2147483648,2147483647,65535,65536,65537,0x12345678]:
        for drive_index in [2,9,10,13,14]:
            for player in [False,True]:
                add(drive_index=drive_index,distance=distance,player=player,mutate_flag=2,domain='signed_distance_and_wrap')
    for mass in [-32768,-1,1,32767]:
        raw=bytearray(original_spec);struct.pack_into('<h',raw,6,mass)
        for drive_index in [0,2,13,14]:
            for distance in [0,1,-1,-30000,-2147483648]:
                if drive_index==0 and distance<0:continue
                add(spec_raw=raw,drive_index=drive_index,distance=distance,domain='raw_signed_mass')
    for cargo in [0,1,-1,-2147483648,2147483647]:
        for waste in [0,65534,65535]:
            for drive_index in [2,10,13,14]:
                add(drive_index=drive_index,cargo=cargo,waste=waste,mutate_flag=2,domain='cargo_waste_word_wrap')
    rng=random.Random(0x9031521)
    for a in [0,1,-1,2,-2,32767,-32768,0x3fffffff,0x40000000,0x7fffffff,-2147483648]:
        for b in [0,1,-1,32768,-32768,0x7fffffff,-2147483648]:
            add('F1521',operands_s32=[a,b],domain='fixed_multiply_boundaries')
    for _ in range(512):add('F1521',operands_s32=[s32(rng.getrandbits(32)),s32(rng.getrandbits(32))],domain='fixed_multiply_random')
    positions=[([0,0,0],[0,0,0]),([0,0,0],[65536,0,0]),([0,0,0],[0,65536,0]),([0,0,0],[0,0,65536]),
               ([0,0,0],[-65536,0,0]),([0,0,0],[65535,0,0]),([0,0,0],[65537,0,0]),
               ([0,0,0],[32767<<8]*3),([0,0,0],[32768<<8]*3),([0,0,0],[2147483647]*3),
               ([-2147483648]*3,[2147483647]*3),([0,0,0],[-2147483648]*3)]
    for value in [1,255,256,257,32767,32768,65535,65536,65537,0x7fff00,0x800000,0x800100]:
        positions.append(([0,0,0],[value,value//2,-value//3]))
    for _ in range(256):positions.append(([s32(rng.getrandbits(32))for _ in range(3)],[s32(rng.getrandbits(32))for _ in range(3)]))
    for start,end in positions:
        add('F833',from_q16=start,to_q16=end,domain='source_distance')
    for start,end in positions[:24]:
        for drive_index in [2,13,14]:
            add('F833_F903',from_q16=start,to_q16=end,drive_index=drive_index,domain='distance_to_hyperdrive')
    # Native fault controls run in their own process; no fabricated numeric result.
    for drive_index,distance in [(0,-1),(1,-1)]:
        add(drive_index=drive_index,distance=distance,domain='native_divide_fault')
        unsafe.append(rows.pop())
    raw=bytearray(original_spec);struct.pack_into('<H',raw,6,0)
    for distance in [0,1,-1]:
        add(spec_raw=raw,distance=distance,domain='native_divide_fault');unsafe.append(rows.pop())
    safe=[]
    for row in rows:
        mass=struct.unpack_from('<h',bytes.fromhex(row['spec_hex']),6)[0]
        index=bytes.fromhex(row['object_hex'])[0xd0]
        power=struct.unpack_from('<I',drive,index*16)[0]
        if row['operation']in['F903','F899','F901','F900']and (mass==0 or(row['operation']!='F900'and row['distance_raw_s32']<0 and abs(power)//abs(mass)==0)):
            row['domain']='native_divide_fault';unsafe.append(row)
        else:safe.append(row)
    return safe,unsafe


def packet(row):
    g=row['globals'];raw=bytearray(INPUT_BYTES)
    struct.pack_into('<4I4HI',raw,0,OPS.index(row['operation']),row['mutate_flag']&0xffffffff,row['distance_raw_s32']&0xffffffff,
                     g['player_object_index_u32'],g['status_u16'],g['hydrogen_u16'],g['military_u16'],g['waste_u16'],g['cargo_s32']&0xffffffff)
    struct.pack_into('<I',raw,28,row['model_input_u32'])
    if row['operation']=='F1521':struct.pack_into('<2I',raw,32,*(v&0xffffffff for v in row['operands_s32']))
    if row['operation']in['F833','F833_F903']:struct.pack_into('<6I',raw,32,*(v&0xffffffff for v in row['from_q16']+row['to_q16']))
    raw[64:88]=bytes.fromhex(row['spec_hex']);raw[88:426]=bytes.fromhex(row['object_hex'])
    # All source outputs have distinct nonzero sentinels. The host entry copies
    # these into the output slots before every call, including early failures.
    return bytes(raw)


def expected(row,raw):
    ret,dist,name,fuel,current,time,maxrange=struct.unpack_from('<7I',raw)
    globals_raw=struct.unpack_from('<I4HI',raw,60)
    out={'return_s32':s32(ret),'distance_raw_s32':s32(dist),'name_code_u32':name,'fuel_needed_s32':s32(fuel),
         'current_range_s32':s32(current),'time_raw_u32':time,'max_range_s32':s32(maxrange),
         'ranges_s32':list(struct.unpack_from('<8i',raw,28)),
         'object_hex':raw[100:438].hex(),
         'globals':dict(zip(['player_object_index_u32','status_u16','hydrogen_u16','military_u16','waste_u16','cargo_s32'],globals_raw))}
    out['globals']['cargo_s32']=s32(out['globals']['cargo_s32'])
    if raw[76:100].hex()!=row['spec_hex']or struct.unpack_from('<2Q',raw,438)!=(GUARD,GUARD):raise ValueError('Output/input guard/spec mismatch')
    changed={i for i,(a,b)in enumerate(zip(bytes.fromhex(row['object_hex']),raw[100:438]))if a!=b}
    if not changed.issubset({0x119}):raise ValueError('Unexpected object write '+str(changed))
    return out


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--data-source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'))
    parser.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_hyperdrive_native.json')
    args=parser.parse_args();source_raw=args.source.read_bytes();data_raw=args.data_source.read_bytes();exe=args.exe.read_bytes()
    if sha(source_raw)!=ASM_SHA or sha(data_raw)!=DATA_SHA or sha(exe)!=EXE_SHA:raise ValueError('Unreviewed source revision')
    source=source_raw.decode();drive,specs=resources(exe,data_raw.decode());rows,unsafe=make_cases(specs,drive)
    text=assembly(source,drive)
    # Distinct sentinels, rather than a uniform host memset, prove partial outputs.
    sentinel_code=''.join(' mov DWORD PTR [output+%d],0x%x\n'%(8+i*4,v)for i,v in enumerate(SEEDS))
    text=text.replace(' mov eax,DWORD PTR [input+8]\n',sentinel_code+' mov eax,DWORD PTR [input+8]\n',1)
    ordered=rows+list(reversed(rows));packets=b''.join(map(packet,ordered))
    with tempfile.TemporaryDirectory(prefix='ffe-hyperdrive-native-')as directory:
        work=Path(directory);(work/'native.s').write_text(text)
        for command in [['as','--64',str(work/'native.s'),'-o',str(work/'native.o')],['ld','-m','elf_x86_64',str(work/'native.o'),'-o',str(work/'native')]]:
            process=subprocess.run(command,capture_output=True)
            if process.returncode:
                debug=Path('/workspace/recovery/hyperdrive-native-debug');debug.mkdir(parents=True,exist_ok=True);(debug/'native.s').write_text(text)
                raise ValueError(process.stderr.decode())
        outputs=[]
        for _ in range(3):
            process=subprocess.run([str(work/'native')],input=packets,capture_output=True,timeout=45)
            if process.returncode:
                import shutil
                index=len(process.stdout)//OUTPUT_BYTES;debug=Path('/workspace/recovery/hyperdrive-native-debug');debug.mkdir(parents=True,exist_ok=True)
                for name in ['native.s','native']:shutil.copyfile(work/name,debug/name)
                (debug/'input.bin').write_bytes(packets[index*INPUT_BYTES:(index+1)*INPUT_BYTES])
                raise ValueError('Native failed at '+str(ordered[index])+' exit='+str(process.returncode))
            outputs.append(process.stdout)
        for row in unsafe:
            process=subprocess.run([str(work/'native')],input=packet(row),capture_output=True,timeout=5)
            if process.returncode!=-8 or process.stdout:raise ValueError('Expected original SIGFPE for '+str(row)+' got'+str(process.returncode))
            row['expected_native_signal']=8;row['expected_error']='source_divide_by_zero'
    if len(outputs[0])!=len(ordered)*OUTPUT_BYTES or any(x!=outputs[0]for x in outputs[1:]):raise ValueError('Incomplete/unstable native output')
    for i,row in enumerate(rows):
        raw=outputs[0][i*OUTPUT_BYTES:(i+1)*OUTPUT_BYTES];j=len(ordered)-1-i
        if raw!=outputs[0][j*OUTPUT_BYTES:(j+1)*OUTPUT_BYTES]:raise ValueError('Case-order dependence at '+str(row))
        row['expected']=expected(row,raw)
    fixture={'schema':1,'revision':'original-dos-hyperdrive-distance-native-v1','source_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'source_data_sha256':DATA_SHA,
             'source_commit':'7e540341d4e09aa3c92877b87d49e7f2c143ad8d','source_procedure_hashes':{str(n):sha(block(source,n).encode())for n in NUMBERS},
             'drive_table_executable_offset':884260,'drive_table_hex':drive.hex(),'drive_table_sha256':DRIVE_SHA,'drive_count':15,'ship_specs':specs,
             'case_count':len(rows),'unsafe_case_count':len(unsafe),'operation_counts':{op:sum(r['operation']==op for r in rows)for op in OPS},
             'domain_counts':{domain:sum(r['domain']==domain for r in rows)for domain in sorted({r['domain']for r in rows})},
             'fresh_process_runs':3,'reverse_repeat_count':len(rows),'canaries_unchanged':True,'nonfuel_object_bytes_unchanged':True,'specifications_unchanged':True,
             'adapted_assembly_sha256':sha(text.encode()),'input_packets_sha256':sha(packets),'native_ordered_output_sha256':sha(outputs[0]),
             'scope':'Original F899/900/901/902/903 and F1521 instructions with original DOS drive table and57 original ship specifications. F833/F2095 source distance and direct F833→F903 chain; _sqrt bridges a stack double to x87 FSQRT. Original F1538 instruction executes against a host table mapping bounded model slots to the selected per-case descriptor/spec. This is a kernel oracle, not F908 arrival scheduling, ship installation rules or live Navigation integration.',
             'fault_domain':'Original zero-mass F903 and zero-maxrange negative-distance paths SIGFPE; separate unsafe cases prove rejection boundaries. Negative or>=15 drive indices are out-of-table source accesses and must be rejected before a safe port runs.',
             'cases':rows,'unsafe_cases':unsafe}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(fixture,separators=(',',':'))+'\n')
    print(json.dumps({k:fixture[k]for k in ['case_count','unsafe_case_count','operation_counts','domain_counts','native_ordered_output_sha256']},indent=2))
if __name__=='__main__':main()
