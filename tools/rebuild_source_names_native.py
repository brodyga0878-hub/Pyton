#!/usr/bin/env python3
"""Execute original F893/F791 populated-body names with original string data.

The bounded name domain is F791 categories0..22. Model/system lookups23..25
are separate callers, not procedural body naming. Their unreachable native
dependencies terminate instead of supplying invented names.
"""
from __future__ import annotations
import argparse,hashlib,json,re,struct,subprocess,sys,tempfile
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
SOURCE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
DATA_SHA='34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850'
SOURCE_VARIANT='jjffe-7e54034-names-original-text'
NUMBERS=[76,77,93,94,791,792,793,794,795,796,797,798,799,800,893,921,1343,1347,1348,1364]
NAME_BYTES=512
PACKET_BYTES=16+68
OUTPUT_BYTES=4+68+NAME_BYTES

def digest(raw:bytes)->str:return hashlib.sha256(raw).hexdigest()

def _tokens(text:str)->list[str]:
    result=[];start=0;quote=''
    for i,char in enumerate(text):
        if quote:
            if char==quote:quote=''
        elif char in "'\"":quote=char
        elif char==',':result.append(text[start:i].strip());start=i+1
    result.append(text[start:].strip())
    return result

def data_blocks(source:str)->dict[int,bytes|list[int]]:
    result={}
    for match in re.finditer(r'^DATA_(\d+):[^\n]*\n(.*?)(?=^DATA_\d+:|\Z)',source,re.M|re.S):
        number=int(match[1]);raw=bytearray();pointers=[]
        if not (6272<=number<=6790 or number in range(2301,2308) or number==102307):continue
        for original in match[2].splitlines():
            line=original.split(';',1)[0].strip()
            if line.startswith('db '):
                for token in _tokens(line[3:]):
                    if token.startswith(("'",'"')):raw.extend(token[1:-1].encode('latin1'))
                    else:raw.append(int(token,0)&255)
            elif line.startswith('dd '):
                for token in _tokens(line[3:]):
                    if token.startswith('DATA_'):pointers.append(int(token[5:]))
                    elif token.startswith('FUNC_'):break
                    else:raw.extend(struct.pack('<I',int(token,0)))
            elif line and not line.startswith((';','SECTION')):break
        result[number]=pointers if pointers else bytes(raw)
    return result

def constants(data_source:str,original:bytes)->dict:
    blocks=data_blocks(data_source);pointers=blocks[6272]
    if not isinstance(pointers,list) or len(pointers)!=510:raise ValueError('Expected510 original name pointers')
    strings=[blocks[number] for number in pointers]
    if not all(isinstance(x,bytes) and x.endswith(b'\0') and x.count(b'\0')==1 for x in strings):raise ValueError('Invalid original name strings')
    pinned_blob=b''.join(blocks[number] for number in range(6280,6790))
    at=original.find(pinned_blob[:64])
    if at<0 or original.find(pinned_blob[:64],at+1)>=0:raise ValueError('Name text prefix does not uniquely identify executable block')
    blob=original[at:at+len(pinned_blob)]
    differences=[{'offset':i,'pinned_byte':a,'original_byte':b} for i,(a,b) in enumerate(zip(pinned_blob,blob)) if a!=b]
    if differences!=[{'offset':1354,'pinned_byte':101,'original_byte':131}]:raise ValueError('Unreviewed pinned/original name text difference')
    by_label={};cursor=0
    for number in range(6280,6790):
        size=len(blocks[number]);by_label[number]=blob[cursor:cursor+size];cursor+=size
    strings=[by_label[number] for number in pointers]
    raw=bytes(blocks[6274])+bytes(blocks[6275])+bytes(blocks[6276])+bytes(blocks[6277])+bytes(blocks[6278])+bytes(blocks[6279])
    at_rules=original.find(raw)
    if at_rules<0 or original.find(raw,at_rules+1)>=0:raise ValueError('Name offset/range block differs from executable')
    offsets=list(struct.unpack_from('<15I',raw,0))
    ranges=list(struct.unpack_from('<15I',raw,48))
    special_offsets=list(struct.unpack_from('<2I',raw,64))
    special_ranges=list(struct.unpack_from('<2I',raw,112))
    bracket=b''.join(bytes(blocks[n]) for n in range(2301,2308))+bytes(blocks[102307])
    bracket_at=original.find(bracket)
    if bracket_at<0 or original.find(bracket,bracket_at+1)>=0:raise ValueError('Bracket keyword block differs from executable')
    return {'schema':1,'source_variant':SOURCE_VARIANT,'source_sha256':SOURCE_SHA,'source_assembly_sha256':ASM_SHA,'source_data_sha256':DATA_SHA,
            'name_pointer_labels':pointers,'strings_hex':[x.hex() for x in strings],
            'type_offsets':offsets,'type_ranges':ranges,'special_offsets':special_offsets,'special_ranges':special_ranges,
            'text_executable_offset':at,'text_bytes':len(blob),'text_sha256':digest(blob),
            'pinned_text_sha256':digest(pinned_blob),'pinned_text_differences':differences,
            'rule_executable_offset':at_rules,'rule_bytes':len(raw),'rules_sha256':digest(raw),
            'bracket_executable_offset':bracket_at,'bracket_block_hex':bracket.hex(),'bracket_block_sha256':digest(bracket),
            'charset':'original byte strings; display decoding is separate from exact name bytes',
            'scope':'Original F791 categories0..22 and F893 body naming; modes23..25 model/system lookups excluded.'}

def library_assembly(source:str,original:bytes,data_source:str)->tuple[str,dict]:
    """Return native procedure/data library without entry point or I/O buffers."""
    sys.path.insert(0,str(PROJECT/'recovered-history/ground_harness/tools'))
    from native_reference import procedures
    resource=constants(data_source,original)
    normalized=re.sub(r'FUNC_(\d{6})_[A-Za-z0-9_]+',r'FUNC_\1',source)
    normalized=re.sub(r'\[ebp\+0x([89a-f][0-9a-f]{7})\]',lambda m:'[ebp-0x%x]'%(0x100000000-int(m[1],16)),normalized)
    normalized=re.sub(r'add esp,0x([89a-f][0-9a-f]{7})',lambda m:'add esp,-0x%x'%(0x100000000-int(m[1],16)),normalized)
    lines,_=procedures(normalized,NUMBERS);text='\n'.join(lines)
    hashes={}
    for number in NUMBERS:
        match=re.search(r'^FUNC_%06d(?:_[A-Za-z0-9_]+)?:.*?(?=^FUNC_\d+(?:_[A-Za-z0-9_]+)?:|\Z)'%number,source,re.M|re.S)
        if not match:raise ValueError('Missing source procedure '+str(number))
        hashes[str(number)]=digest(match[0].encode())
    text=text.replace('SECTION .data','.section .rodata').replace('SECTION .text','.section .text')
    text=re.sub(r'\.section \.rodata\npAsmLog.*?\.section \.text','',text,flags=re.S)
    text=re.sub(r'^dd (JUMP_\d+)$',r'.quad \1',text,flags=re.M)
    text=text.replace('jmp [eax*4+DATA_000031]','jmp QWORD PTR [rax*8+DATA_000031]')
    # GAS encodes the indirect source call through low32 function pointers.
    text=text.replace('mov eax,DWORD PTR [eax*4+DATA_007652_PLUS_52]','mov eax,DWORD PTR [eax*4+DATA_007652_PLUS_52]')
    # All compiler-generated original locals are DWORD. Positive argument
    # slots expand to host stack width; negative local slots remain source32.
    # Original0xfffff800 is a signed local-stack reservation, not4GiB allocation.
    text=text.replace('add rsp,4294965248','add rsp,-2048').replace('add rsp,4294963204','add rsp,-4092')
    body='.intel_syntax noprefix\n.code64\n.section .text\n'+text+'\n'
    body+='''
# Non-returning gates outside the bounded source naming domain.
FUNC_000064:
FUNC_000074:
FUNC_000075:
FUNC_000304:
FUNC_000305:
FUNC_000461:
FUNC_000462:
FUNC_000463:
FUNC_000464:
FUNC_000465:
FUNC_000858:
FUNC_000860:
FUNC_001538:
FUNC_001344_StringExpandFFCode:
FUNC_001345_StringExpandFF40Code:
FUNC_001358_StringConvertDate:
FUNC_001377_StringConvertFraction:
_sprintf:
 call names_unreachable
names_unreachable:
 mov eax,60
 mov edi,93
 syscall
_strlen:
 mov eax,DWORD PTR [rsp+8]
 mov edx,eax
strlen_loop:
 cmp BYTE PTR [rax],0
 je strlen_done
 inc eax
 jmp strlen_loop
strlen_done:
 sub eax,edx
 ret
_memcpy:
 push rsi
 push rdi
 mov edi,DWORD PTR [rsp+24]
 mov esi,DWORD PTR [rsp+32]
 mov ecx,DWORD PTR [rsp+40]
 mov eax,edi
 rep movsb
 pop rdi
 pop rsi
 ret
.section .rodata
.align 8
DATA_007216: .quad FUNC_000921
DATA_007641: .quad FUNC_001347_StringExpandArrayIndex
DATA_007642: .quad FUNC_001348_StringExpand
DATA_007640: .quad FUNC_001345_StringExpandFF40Code
DATA_007756: .quad FUNC_001538
DATA_007639: .quad FUNC_001344_StringExpandFFCode
DATA_007652_PLUS_52:
'''
    body+='.long '+','.join('FUNC_001364_FF30WriteStringV4' if i==22 else 'names_unreachable' for i in range(64))+'\n'
    body+='DATA_007649: .zero 256\nDATA_006272:\n'
    body+='\n'.join('.long DATA_%06d'%number for number in resource['name_pointer_labels'])+'\n'
    blocks=data_blocks(data_source)
    for number in range(6274,6791):
        if number in [6274,6275,6276,6277,6278,6279] or number>=6280:
            raw=bytes.fromhex(resource['strings_hex'][number-6280]) if 6280<=number<6790 else blocks[number]
            body+='DATA_%06d: .byte '%number+','.join(str(x) for x in raw)+'\n'
    body+='DATA_002301: .byte '+','.join(str(x) for x in bytes.fromhex(resource['bracket_block_hex']))+'\n'
    # These globals are read only by bracket protocols absent from source
    # name data. Bind them to unmapped address0 so a domain mistake fails.
    for number in [2289,2290,2291,2295,2296,2297,5110,7107,7108,7109,8428,8567,8807,8861,8885,8888,8911]:
        body+='.equ DATA_%06d,0\n'%number
    body+='''
.section .bss
.align 8
DATA_007128: .zero 4
DATA_008919: .zero 256
DATA_009149: .zero 8
DATA_008568: .zero 64
'''
    body=re.sub(r'FUNC_(\d{6})_[A-Za-z0-9_]+',r'FUNC_\1',body)
    metadata={'source_procedure_hashes':hashes,'resource':resource,'scope':resource['scope']}
    return body,metadata

def cases()->list[dict]:
    rows=[]
    for category in range(23):
        for language in [0,3]:
            for uid in [0,1,24,25,0x7fff,0xffff,0x12345678,0x80000000,0xffffffff,0xe3d24ac9]:
                rows.append({'category':category,'language':language,'uid':uid,'operation':0})
    import random
    rng=random.Random(0x893791)
    for _ in range(512):rows.append({'category':rng.randrange(23),'language':rng.choice([0,1,2,3,4]),'uid':rng.getrandbits(32),'operation':0})
    for category in range(6,11):
        for language in [0,3]:
            for uid in [0,1,0x12345678,0xffffffff,0xe3d24ac9]:rows.append({'category':category,'language':language,'uid':uid,'operation':1})
    for _ in range(768):rows.append({'category':rng.randrange(6,11),'language':rng.randrange(5),'uid':rng.getrandbits(32),'operation':1})
    for first in [0,1,24,25,0x12345678,0x80000000,0xffffffff]:
        for second in [0,1,0x12345678,0xffffffff]:
            for bound in [0,1,10,26,88,105,138,255,0x10000,0xffffffff]:rows.append({'category':bound,'language':second,'uid':first,'operation':2})
    for _ in range(128):rows.append({'category':0,'language':rng.getrandbits(32),'uid':rng.getrandbits(32),'operation':3})
    for first in [0,1,24,25,255,256,0xffffffff,0x80000000]:
        for second in [0,1,0xffffffff]:rows.append({'category':0,'language':second,'uid':first,'operation':3})
    for row in rows:
        record=bytearray([0x5a]*68);struct.pack_into('<I',record,4,row['uid']);record[0x3f]=0x41
        row['record_hex']=record.hex()
    return rows

def main()->None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--data-source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'))
    parser.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_names_native.json')
    parser.add_argument('--resource',type=Path,default=PROJECT/'data/ffe_planet_names.json')
    args=parser.parse_args();raw=args.source.read_bytes();original=args.executable.read_bytes();data_raw=args.data_source.read_bytes()
    if digest(raw)!=ASM_SHA or digest(original)!=SOURCE_SHA or digest(data_raw)!=DATA_SHA:raise ValueError('Unreviewed source')
    native,metadata=library_assembly(raw.decode(),original,data_raw.decode());rows=cases()
    entry='''
.section .text
.global _start
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 lea rsi,[input+r8]
 mov edx,84
 sub edx,r8d
 syscall
 test eax,eax
 jz finished
 js failed
 add r8d,eax
 cmp r8d,84
 jb read_more
 mov DWORD PTR [DATA_007128],0
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [DATA_007128],eax
 mov rax,0x4e414d4553424e44
 mov QWORD PTR [record_before],rax
 mov QWORD PTR [record_after],rax
 mov QWORD PTR [output_before],rax
 mov QWORD PTR [output_after],rax
 mov edi,OFFSET FLAT:context
 xor eax,eax
 mov ecx,64
 rep stosb
 mov edi,OFFSET FLAT:DATA_008919
 mov BYTE PTR [rdi],0
 mov esi,OFFSET FLAT:input+16
 mov edi,OFFSET FLAT:record
 mov ecx,68
 rep movsb
 mov edi,OFFSET FLAT:output
 mov al,0xa5
 mov ecx,584
 rep stosb
 cmp DWORD PTR [input+12],2
 je rng_case
 cmp DWORD PTR [input+12],3
 je surname_case
 cmp DWORD PTR [input+12],0
 jne rename
 push OFFSET FLAT:output+72
 push QWORD PTR [input+8]
 push OFFSET FLAT:context
 push QWORD PTR [input]
 call FUNC_000791
 add rsp,32
 sub eax,OFFSET FLAT:output+72
 mov DWORD PTR [output],eax
 jmp emit
rng_case:
 mov eax,DWORD PTR [input+8]
 mov DWORD PTR [context],eax
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [context+4],eax
 push OFFSET FLAT:context+4
 push OFFSET FLAT:context
 push QWORD PTR [input]
 call FUNC_000921
 add rsp,24
 mov DWORD PTR [output],eax
 mov eax,DWORD PTR [context]
 mov DWORD PTR [record],eax
 mov eax,DWORD PTR [context+4]
 mov DWORD PTR [record+4],eax
 jmp emit
surname_case:
 mov eax,DWORD PTR [input+8]
 mov DWORD PTR [context+20],eax
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [context+24],eax
 push OFFSET FLAT:context+24
 push OFFSET FLAT:context+20
 push OFFSET FLAT:context
 push 0
 push OFFSET FLAT:output+72
 call FUNC_000793
 add rsp,40
 sub eax,OFFSET FLAT:output+72
 mov DWORD PTR [output],eax
 mov eax,DWORD PTR [context+20]
 mov DWORD PTR [record],eax
 mov eax,DWORD PTR [context+24]
 mov DWORD PTR [record+4],eax
 jmp emit
rename:
 push OFFSET FLAT:context
 push QWORD PTR [input]
 push 0
 push OFFSET FLAT:record
 call FUNC_000893
 add rsp,32
 sub eax,OFFSET FLAT:record+38
 mov DWORD PTR [output],eax
 mov esi,OFFSET FLAT:record+38
 mov edi,OFFSET FLAT:output+72
copy_name:
 lodsb
 stosb
 test al,al
 jnz copy_name
emit:
 mov rax,0x4e414d4553424e44
 cmp QWORD PTR [record_before],rax
 jne failed
 cmp QWORD PTR [record_after],rax
 jne failed
 cmp QWORD PTR [output_before],rax
 jne failed
 cmp QWORD PTR [output_after],rax
 jne failed
 mov esi,OFFSET FLAT:record
 mov edi,OFFSET FLAT:output+4
 mov ecx,68
 rep movsb
 xor r8d,r8d
write_more:
 mov eax,1
 mov edi,1
 lea rsi,[output+r8]
 mov edx,584
 sub edx,r8d
 syscall
 test eax,eax
 jle failed
 add r8d,eax
 cmp r8d,584
 jb write_more
 jmp next_case
finished:
 mov eax,60
 xor edi,edi
 syscall
failed:
 mov eax,60
 mov edi,94
 syscall
.section .bss
.align 8
input: .zero 84
record_before: .zero 8
record: .zero 68
record_after: .zero 8
context: .zero 64
output_before: .zero 8
output: .zero 584
output_after: .zero 8
.align 16
stack: .zero 1048576
stack_end:
'''
    native+=entry
    ordered=rows+list(reversed(rows));packets=b''.join(struct.pack('<4I',r['category'],r['language'],r['uid'],r['operation'])+bytes.fromhex(r['record_hex']) for r in ordered)
    with tempfile.TemporaryDirectory(prefix='ffe-source-names-') as directory:
        work=Path(directory);(work/'native.s').write_text(native)
        subprocess.run(['as','--64',str(work/'native.s'),'-o',str(work/'native.o')],check=True)
        subprocess.run(['ld','-m','elf_x86_64',str(work/'native.o'),'-o',str(work/'native')],check=True)
        outputs=[]
        for _ in range(3):
            process=subprocess.run([str(work/'native')],input=packets,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30)
            if process.returncode:
                import shutil
                debug=Path('/workspace/recovery/names-native-debug');debug.mkdir(parents=True,exist_ok=True)
                for name in ['native.s','native']:shutil.copyfile(work/name,debug/name)
                index=len(process.stdout)//OUTPUT_BYTES
                (debug/'input.bin').write_bytes(packets[index*PACKET_BYTES:(index+1)*PACKET_BYTES]);(debug/'stderr.bin').write_bytes(process.stderr)
                raise ValueError('Native name case failed '+str(ordered[index])+' exit='+str(process.returncode)+' observed='+repr(process.stderr))
            outputs.append(process.stdout)
    if any(x!=outputs[0] for x in outputs[1:]):raise ValueError('Fresh name processes differ')
    output=outputs[0]
    if len(output)!=len(ordered)*OUTPUT_BYTES:raise ValueError('Incomplete native name results')
    for index,row in enumerate(rows):
        result=output[index*OUTPUT_BYTES:(index+1)*OUTPUT_BYTES]
        reverse=len(ordered)-1-index
        if result!=output[reverse*OUTPUT_BYTES:(reverse+1)*OUTPUT_BYTES]:raise ValueError('Name case depends on previouscase')
        if row['operation'] in [2,3]:
            row['expected_rng']={'first':struct.unpack_from('<I',result,4)[0],'second':struct.unpack_from('<I',result,8)[0]}
        if row['operation']==2:
            row['expected_rng']['value']=struct.unpack_from('<I',result)[0]
            continue
        length=struct.unpack_from('<I',result)[0]
        if not 1<=length<NAME_BYTES or result[72+length-1]!=0:raise ValueError('Bad native NUL/end result')
        row['expected_name_hex']=result[72:72+length].hex();row['expected_end_offset']=length
        row['expected_record_hex']=result[4:72].hex()
        name_buffer=result[72:72+NAME_BYTES]
        write_end=max(i for i,value in enumerate(name_buffer) if value!=0xa5)+1
        if name_buffer[write_end:]!=bytes([0xa5])*(NAME_BYTES-write_end):raise ValueError('Unexpected name write gaps')
        row['expected_write_hex']=name_buffer[:write_end].hex()
    fixture={'schema':1,'revision':'original-source-populated-names-v1','source_variant':SOURCE_VARIANT,'source_sha256':SOURCE_SHA,'source_assembly_sha256':ASM_SHA,'source_data_sha256':DATA_SHA,'source_commit':'7e540341d4e09aa3c92877b87d49e7f2c143ad8d','case_count':len(rows),'case_operation_counts':{str(n):sum(r['operation']==n for r in rows) for n in range(4)},'fresh_process_runs':3,'reverse_repeat_count':len(rows),'source_procedure_hashes':metadata['source_procedure_hashes'],'adapted_assembly_sha256':digest(native.encode()),'input_packets_sha256':digest(packets),'native_output_sha256':digest(output),'record_and_name_buffer_canaries_unchanged':True,'resource_text_sha256':metadata['resource']['text_sha256'],'resource_rules_sha256':metadata['resource']['rules_sha256'],'resource_bracket_block_sha256':metadata['resource']['bracket_block_sha256'],'scope':metadata['scope'],'cases':rows}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(fixture,separators=(',',':'))+'\n');args.resource.write_text(json.dumps(metadata['resource'],ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:fixture[k] for k in ['case_count','native_output_sha256','scope']},indent=2))

if __name__=='__main__':main()
