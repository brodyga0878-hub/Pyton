#!/usr/bin/env python3
"""Build bounded original-ASM system-information/text controls on a low host stack.

Expected strings and page arguments are produced by original procedures, never a
Python translation of their semantics. The host supplies an already selected DOS
metadata row (F868 is deliberately outside this oracle), source body records,
and GUI callbacks; it records original F843 output without emulating its GUI.
Unsupported code domains and unselected GUI branches terminate the process.
"""
from __future__ import annotations
import argparse, hashlib, json, re, struct, subprocess, sys, tempfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
import rebuild_source_names_native as names

EXTRA = [613,830,831,843,869,870,895,1344,1346,1349,1365,
         *range(1369,1392),1482,1494,1515,1544,1545]
INPUT_BYTES = 2384
HEADER_BYTES = 64
TEXT_BYTES = 8192
CALL_BYTES = 48
MAX_CALLS = 40
OUTPUT_BYTES = HEADER_BYTES + TEXT_BYTES + CALL_BYTES * MAX_CALLS
SOURCE_COMMIT = '7e540341d4e09aa3c92877b87d49e7f2c143ad8d'


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def source_proc(source: str, number: int) -> str:
    match = re.search(r'^FUNC_%06d(?:_[A-Za-z0-9_]+)?:.*?(?=^FUNC_\d+(?:_[A-Za-z0-9_]+)?:|\Z)' % number, source, re.M|re.S)
    if not match:
        raise ValueError('Missing original procedure ' + str(number))
    return match[0]


def cstrings(data_source: str, start: int, stop: int) -> dict[int,bytes]:
    result = {}
    for number in range(start, stop):
        match = re.search(r'^DATA_%06d:[^\n]*\n(.*?)(?=^DATA_\d+:|\Z)' % number, data_source, re.M|re.S)
        raw = bytearray()
        for line in match[1].splitlines():
            line = line.split(';', 1)[0].strip()
            if not line:
                continue
            if not line.startswith('db '):
                break
            for token in names._tokens(line[3:]):
                if token.startswith(("'", '"')):
                    raw.extend(token[1:-1].encode('latin1'))
                else:
                    raw.append(int(token,0)&255)
        if 0 not in raw:
            raise ValueError('Missing first NUL at DATA' + str(number))
        result[number] = bytes(raw[:raw.index(0)+1])
    return result


def original_resources(data_source: str, original: bytes) -> dict:
    system = json.loads((PROJECT/'data/ffe_system_names.json').read_text())
    short = {int(label): bytes.fromhex(raw) for label,raw in zip(system['pointer_labels'],system['strings_hex'])}
    short_asm = cstrings(data_source,6830,7097)
    if short != short_asm:
        raise ValueError('System strings differ from pinned source')
    short_blob = b''.join(short.values())
    if original[system['text_executable_offset']:system['text_executable_offset']+len(short_blob)] != short_blob:
        raise ValueError('System text differs from original executable')
    separators=cstrings(data_source,7099,7101)
    for number,offset in [(7099,855397),(7100,855399)]:
        raw=separators[number]
        if original[offset:offset+len(raw)]!=raw:raise ValueError('Body-page separator differs from original executable')
    long = cstrings(data_source,7139,7183)
    long_blob = b''.join(long.values())
    if len(long_blob)!=6333 or sha(long_blob)!='7a8eb24a707f5feabe1a99cc0cda5a96e934d33b6ba01e2dd6471bf64144b8c6':
        raise ValueError('Unreviewed first-NUL long description block')
    if original[876496:876496+len(long_blob)] != long_blob:
        raise ValueError('Long descriptions differ from original executable')
    cursor=0
    for observed,raw in zip(struct.unpack_from('<44I',original,873780),long.values()):
        if observed!=0x4ec3d0+cursor:raise ValueError('Original long-description pointer ordering differs')
        cursor+=len(raw)
    metadata = json.loads((PROJECT/'data/ffe_system_metadata.json').read_text())
    dos = bytes.fromhex(metadata['dos_metadata_hex'])
    at=int(metadata['metadata_executable_offset'])
    if original[at:at+len(dos)]!=dos:raise ValueError('DOS policy bytes differ from original executable')
    if len(dos)!=18268 or dos[:18198]!=bytes.fromhex(metadata['metadata_hex'])[:18198]:
        raise ValueError('Unreviewed DOS metadata layout')
    # DATA6162 commodity pointer array is not reimplemented by the host.
    match = re.search(r'^DATA_006162:[^\n]*\n(.*?)(?=^DATA_\d+:)',data_source,re.M|re.S)
    commodity_labels = [int(m) for m in re.findall(r'dd DATA_(\d+)',match[1])]
    commodities = cstrings(data_source,min(commodity_labels),max(commodity_labels)+1)
    return {'short':short,'long':long,'dos':dos,'system':system,'separators':separators,
            'commodities':commodities,'commodity_labels':commodity_labels}


def library(source: str, data_source: str, original: bytes) -> tuple[str,dict]:
    native,meta = names.library_assembly(source,original,data_source)
    sys.path.insert(0,str(PROJECT/'recovered-history/ground_harness/tools'))
    from native_reference import procedures
    normalized = re.sub(r'FUNC_(\d{6})_[A-Za-z0-9_]+',r'FUNC_\1',source)
    normalized = re.sub(r'\[ebp\+0x([89a-f][0-9a-f]{7})\]',lambda m:'[ebp-0x%x]'%(0x100000000-int(m[1],16)),normalized)
    normalized = re.sub(r'add esp,0x([89a-f][0-9a-f]{7})',lambda m:'add esp,-0x%x'%(0x100000000-int(m[1],16)),normalized)
    for number in EXTRA:
        # These labels were non-returning gates in the reused naming library.
        if number in [1344,1377]:
            native = native.replace('FUNC_%06d:\n'%number,'')
    extra,_ = procedures(normalized,EXTRA)
    adapted='\n'.join(extra).replace('[rbp+edi-', '[rbp+rdi-')
    # F830 releases its8-byte local allocation using two POP ECX; host slots are8 bytes.
    adapted=adapted.replace('FUNC_000830:\npush rbp\nmov rbp,rsp\nadd rsp,-8', 'FUNC_000830:\npush rbp\nmov rbp,rsp\nadd rsp,-16')
    adapted=re.sub(r'(mov DWORD PTR \[[^\]]+\],)(DATA_\d+)',r'\1OFFSET FLAT:\2',adapted)
    adapted=re.sub(r'^((?:add|sub|cmp) [^,\n]+,)(DATA_\d+)$',r'\1OFFSET FLAT:\2',adapted,flags=re.M)
    native += '\n.section .text\n'+adapted+'\n'
    meta['source_procedure_hashes'].update({str(n):sha(source_proc(source,n).encode()) for n in EXTRA})
    resources=original_resources(data_source,original)
    ff30 = [1349,1376,1375,1374,1378,1379,1380,1381,1382,1383,1384,1385,1386,
            None,None,None,None,None,None,None,None,None,1364,1365,1391,1390,1389,1388,1387,1372,1373,1371,1370,1369]
    native = re.sub(r'DATA_007652_PLUS_52:\n.*?DATA_006272:',
        'DATA_007652_PLUS_52:\n.long '+','.join('FUNC_%06d'%n if n else 'names_unreachable' for n in ff30+[None]*(64-len(ff30)))+
        '\nDATA_007649:\n.long '+','.join({0:'FUNC_000895',2:'FUNC_000831',7:'FUNC_000613'}.get(i,'names_unreachable') for i in range(64))+
        '\nDATA_006272:',native,count=1,flags=re.S)
    # Add only exact DOS strings to original data-pointer dispatchers.
    native+='\n.section .rodata\nDATA_006796:\n.long '+','.join('DATA_%06d'%n for n in resources['short'])+'\n'
    native+='DATA_007117:\n.long '+','.join('DATA_%06d'%n for n in resources['long'])+'\n'
    native+='DATA_006162:\n.long '+','.join('DATA_%06d'%n for n in resources['commodity_labels'])+'\n'
    for number,raw in {**resources['short'],**resources['long'],**resources['commodities'],**resources['separators']}.items():
        native+='DATA_%06d: .byte '%number+','.join(map(str,raw))+'\n'
    native+='DATA_007106: .byte '+','.join(map(str,resources['dos']))+'\n'
    for n,offset in {7110:432,7111:436,7112:442,7113:444,7114:445,7115:476}.items():
        native+='.equ DATA_%06d,DATA_007106+%d\n'%(n,offset)
    native+='''
DATA_006826: .zero 20
DATA_006827: .zero 20
.align 8
DATA_007672: .quad host_action
DATA_007673: .quad names_unreachable
DATA_007676: .quad names_unreachable
DATA_007644: .quad host_wrap
DATA_007733: .quad FUNC_001494
DATA_007747: .quad FUNC_001515
# Source F830's procedural-system-name dependencies are outside this bounded oracle.
.equ DATA_006799,0
.equ DATA_006800,0
.equ DATA_006802,0
.equ DATA_006823,0
.equ DATA_007097,0
.equ DATA_007098,0
.section .bss
DATA_008627: .zero 1
DATA_008809: .zero 1
DATA_008953: .zero 1
DATA_008965: .zero 1
DATA_008847: .zero 1
DATA_008958: .zero 3
DATA_008959: .zero 1
DATA_008961: .zero 4
DATA_008962: .zero 4
DATA_009147: .zero 8192
body_before: .zero 8
body_prefix: .zero 196
body: .zero 272
body_after: .zero 8
.equ DATA_008776,body_prefix
.equ DATA_008777,body-58
.equ DATA_008778,body
.equ DATA_008779,body+4
.equ DATA_008780,body+8
.equ DATA_008781,body+10
.equ DATA_008782,body+14
.equ DATA_008783,body+20
.equ DATA_008784,body+22
.equ DATA_008785,body+32
.equ DATA_008786,body+34
.equ DATA_008787,body+36
.equ DATA_008788,body+38
.equ DATA_008789,body+78
DATA_008790: .zero 37
.equ DATA_008791,DATA_008790+32
# Important: source DATA8791 is +32, NOT commodity +1.
# Original F870 overwrites byte32 with0x0d after copying31 bytes.
'''
    # Unselected original UI actions trap; selected FA/F9/body/FF run unchanged.
    referenced=set(re.findall(r'\b(FUNC_\d{6})\b',native))
    defined=set(re.findall(r'^(FUNC_\d{6}):',native,re.M))
    native+='\n.section .text\n'
    for name in sorted(referenced-defined):
        native+=name+':\n jmp names_unreachable\n'
    # Host gates for lookups/rendering are explicit fixture metadata, not source semantics.
    native+='''
FUNC_000868:
 mov eax,DWORD PTR [input+8]
 ret
FUNC_000262:
FUNC_000850:
FUNC_001637:
 ret
host_action:
 mov eax,DWORD PTR [input+12]
 ret
FUNC_000854:
 push rbp
 mov rbp,rsp
 push rbx
 push rsi
 push rdi
 mov eax,DWORD PTR [rbp+16]
 mov edx,DWORD PTR [rbp+48]
 mov ecx,DWORD PTR [rbp+56]
 mov r8d,DWORD PTR [rbp+40]
 mov r9d,DWORD PTR [rbp+24]
 mov r10d,0
 call record_call
 push QWORD PTR [rbp+32]
 push QWORD PTR [rbp+16]
 push rdi
 push QWORD PTR [rbp+24]
 # F830 ABI is code, vars, dest, system_id; reorder explicitly below.
 add rsp,32
 push QWORD PTR [rbp+32]
 push rdi
 push QWORD PTR [rbp+24]
 push QWORD PTR [rbp+16]
 call FUNC_000830
 add rsp,32
 call end_call
 pop rdi
 pop rsi
 pop rbx
 pop rbp
 ret
host_wrap:
 push rbp
 mov rbp,rsp
 push rbx
 push rsi
 push rdi
 mov eax,DWORD PTR [rbp+16]
 mov edx,DWORD PTR [rbp+48]
 mov ecx,DWORD PTR [rbp+56]
 mov r8d,DWORD PTR [rbp+40]
 mov r9d,DWORD PTR [rbp+24]
 mov r10d,1
 call record_call
 push QWORD PTR [rbp+24]
 push QWORD PTR [rbp+16]
 push rdi
 call FUNC_001344
 add rsp,24
 call end_call
 pop rdi
 pop rsi
 pop rbx
 pop rbp
 ret
FUNC_001589:
 push rbp
 mov rbp,rsp
 push rbx
 push rsi
 push rdi
 mov eax,0xffffffff
 mov edx,DWORD PTR [rbp+32]
 mov ecx,DWORD PTR [rbp+40]
 mov r8d,DWORD PTR [rbp+24]
 xor r9d,r9d
 mov r10d,2
 call record_call
 mov esi,DWORD PTR [rbp+16]
copy_literal:
 lodsb
 stosb
 test al,al
 jnz copy_literal
 mov eax,edi
 call end_call
 pop rdi
 pop rsi
 pop rbx
 pop rbp
 ret
# Inputs eax code, edx y, ecx color, r8 x, r9 vars pointer, r10 kind.
# Output ebx record, edi text destination. Host callback preserves source callee-saved regs.
record_call:
 mov ebx,DWORD PTR [output+4]
 cmp ebx,40
 jae failed
 imul ebx,ebx,48
 add ebx,OFFSET FLAT:output+8256
 mov DWORD PTR [rbx],eax
 mov DWORD PTR [rbx+4],r8d
 mov DWORD PTR [rbx+8],edx
 mov DWORD PTR [rbx+12],ecx
 mov DWORD PTR [rbx+44],r10d
 test r9d,r9d
 jz no_vars
 mov esi,r9d
 lea rdi,[rbx+16]
 mov ecx,5
 rep movsd
no_vars:
 mov edi,DWORD PTR [output+8]
 cmp edi,6144
 ja failed
 mov DWORD PTR [rbx+36],edi
 add edi,OFFSET FLAT:output+64
 inc DWORD PTR [output+4]
 ret
end_call:
 mov esi,OFFSET FLAT:output+64
 add esi,DWORD PTR [rbx+36]
 push rsi
 call _strlen
 pop rsi
 inc eax
 mov DWORD PTR [rbx+40],eax
 add eax,DWORD PTR [rbx+36]
 mov DWORD PTR [output+8],eax
 ret
_strcat:
 push rsi
 push rdi
 mov edi,DWORD PTR [rsp+24]
 mov esi,DWORD PTR [rsp+32]
 mov eax,edi
strcat_seek:
 cmp BYTE PTR [rdi],0
 je strcat_copy
 inc edi
 jmp strcat_seek
strcat_copy:
 mov dl,BYTE PTR [rsi]
 mov BYTE PTR [rdi],dl
 inc esi
 inc edi
 test dl,dl
 jnz strcat_copy
 pop rdi
 pop rsi
 ret
_strcpy:
 jmp names_unreachable
'''
    # Remove previously generated trap labels for our host callbacks.
    for n in [262,850,854,868,1589,1637]:
        native=native.replace('FUNC_%06d:\n jmp names_unreachable\n'%n,'',1)
    meta['resource_hashes']={'short':sha(b''.join(resources['short'].values())),
        'long':sha(b''.join(resources['long'].values())),'dos_metadata':sha(resources['dos']),
        'body_separator_bytes':{str(number):raw.hex() for number,raw in resources['separators'].items()}}
    meta['dos_metadata']=resources['dos']
    return native,meta


def entry() -> str:
    return '''
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
 mov edx,2384
 sub edx,r8d
 syscall
 test eax,eax
 jz finished
 js failed
 add r8d,eax
 cmp r8d,2384
 jb read_more
 mov rax,0x494e464f424e4453
 mov QWORD PTR [body_before],rax
 mov QWORD PTR [body_after],rax
 mov QWORD PTR [output_before],rax
 mov QWORD PTR [output_after],rax
 mov edi,OFFSET FLAT:output
 xor eax,eax
 mov ecx,10176
 rep stosb
 mov edi,OFFSET FLAT:output+64
 mov al,0xa5
 mov ecx,8192
 rep stosb
 mov esi,OFFSET FLAT:input+20
 mov edi,OFFSET FLAT:variables
 mov ecx,20
 rep movsb
 mov eax,DWORD PTR [input+40]
 test eax,1
 jz no_string4
 mov DWORD PTR [variables+12],OFFSET FLAT:input+1600
no_string4:
 test eax,2
 jz no_string5
 mov DWORD PTR [variables+16],OFFSET FLAT:input+1856
no_string5:
 mov eax,DWORD PTR [input+16]
 mov DWORD PTR [DATA_008958],eax
 mov eax,DWORD PTR [input+44]
 mov DWORD PTR [DATA_008962],eax
 mov BYTE PTR [DATA_008627],0
 mov DWORD PTR [DATA_009149],OFFSET FLAT:variables
 mov edi,OFFSET FLAT:body_prefix
 xor eax,eax
 mov ecx,196
 rep stosb
 mov esi,OFFSET FLAT:input+2112
 mov edi,OFFSET FLAT:body
 mov ecx,272
 rep movsb
 mov DWORD PTR [output+12],0xabcdef13
 cmp DWORD PTR [input],0
 je code_case
 cmp DWORD PTR [input],1
 je raw_case
 cmp DWORD PTR [input],2
 je gui_case
 cmp DWORD PTR [input],3
 je policy_case
 cmp DWORD PTR [input],4
 je number_case
 jmp failed
code_case:
 push OFFSET FLAT:variables
 push QWORD PTR [input+4]
 push OFFSET FLAT:output+64
 call FUNC_001344
 add rsp,24
 sub eax,OFFSET FLAT:output+64
 mov DWORD PTR [output],eax
 jmp emit
raw_case:
 push OFFSET FLAT:input+64
 push OFFSET FLAT:output+64
 call FUNC_001348
 add rsp,16
 sub eax,OFFSET FLAT:output+64
 mov DWORD PTR [output],eax
 jmp emit
gui_case:
 call FUNC_000843
 jmp emit
policy_case:
 push OFFSET FLAT:output+28
 push OFFSET FLAT:output+24
 push OFFSET FLAT:output+20
 push OFFSET FLAT:output+16
 push QWORD PTR [input+16]
 call FUNC_000870
 add rsp,40
 mov esi,OFFSET FLAT:DATA_008790
 mov edi,OFFSET FLAT:output+64
 mov ecx,37
 rep movsb
 mov DWORD PTR [output+16],0
 jmp emit
number_case:
 push QWORD PTR [input+4]
 push QWORD PTR [input+20]
 push OFFSET FLAT:output+64
 call FUNC_001377
 add rsp,24
 sub eax,OFFSET FLAT:output+64
 mov DWORD PTR [output],eax
emit:
 mov rax,0x494e464f424e4453
 cmp QWORD PTR [body_before],rax
 jne failed
 cmp QWORD PTR [body_after],rax
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
 mov edx,10176
 sub edx,r8d
 syscall
 test eax,eax
 jle failed
 add r8d,eax
 cmp r8d,10176
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
input: .zero 2384
variables: .zero 20
output_before: .zero 8
output: .zero 10176
output_after: .zero 8
.align 16
stack: .zero 1048576
stack_end:
'''


def cases(dos:bytes) -> list[dict]:
    rows=[]
    def add(**kw):
        row={'operation':0,'code':0,'metadata_index':0,'action':0,'system_id':0x02a49718,
             'variables':[0,0,0,0,0],'flags':0,'known':1}
        row.update(kw);rows.append(row)
    add(code=0x8438,domain='source_bracket_name')
    for value in [b'M[nich\0',b'Kr[ger 60\0',b'\xd5apostrophe\0']:
        add(code=0x3016,flags=1,string4_hex=value.hex(),domain='bracket_outer_pass')
    # Every source page name/classification, including strings with their original control bytes.
    for code in range(0x8476,0x850c):
        add(code=code,variables=([0x84cb,0x84bb,0x84b7,0x84db,0] if code==0x84b5 else [12345,67890,0x84b7,0x84db,0x84b8]),domain='source_page_text')
    for code in range(0x8000,0x802c):
        add(code=code,domain='long_description')
    for code in [0x3001,0x3002,0x3003,0x3004,0x3005,0x3006,0x3007,0x3008,0x3009,0x300a,0x300b,0x300c,0x301d,0x301e,0x301f,0x3020,0x3021]:
        for value in [0,1,-1,9,-9,10,-10,99,-99,100,-100,2147483647,-2147483648]:
            add(code=code,variables=[value]*5,domain='numeric')
    for code,slot in [(0x3018,0),(0x3019,1),(0x301a,2),(0x301b,3),(0x301c,4)]:
        for child in [0x84b7,0x84bb,0x84cb,0x84db,0x3001]:
            values=[12345]*5;values[slot]=child
            if child==0x3001 and slot==0:continue # Source recursion has no cycle bound.
            add(code=code,variables=values,domain='recursive_3018_301c')
    for raw in [b'plain\0',b'A\xfe\x17\x49B\xfd\x41C\0',b'A\xff\x30\x01Z\0',
                b'A\xff\x30\x18Z\0',b'\xd5apostrophe\0',b'M[nich\0',b'Kr[ger 60\0',
                b'A\xff\x30\x16Z\0']:
        add(operation=1,raw_hex=raw.hex(),variables=[0x84b7,0,0,0,0],flags=1,string4_hex=b'X\xff\x30\x02Y\0'.hex(),domain='raw_ff_fe_fd')
    for code in [0x3016,0x3017]:
        add(code=code,variables=[17,29,0,0,0],flags=3,string4_hex=b'V4\xff\x30\x01\0'.hex(),string5_hex=b'V5\xfe\x21\x44\xfd\x42\0'.hex(),domain='inserted_strings')
    for value in [0,1,-1,10,-10,100,-100,-2147483648,2147483647]:
        for dp in [1,2,3]:add(operation=4,code=dp,variables=[value,0,0,0,0],domain='direct_fraction')
    # All eight procedural policies and329 original authored rows, no ten JJFFE additions.
    for index in range(-8,329):
        at=(index+8)*54;system_id=struct.unpack_from('<I',dos,at)[0]
        add(operation=3,metadata_index=index,system_id=system_id,domain='policy_copy')
        add(operation=2,metadata_index=index,system_id=system_id,action=0xfa,domain='demographic_page')
        add(operation=2,metadata_index=index,system_id=system_id,action=0xf9,domain='trade_page')
    for action in [0xf9,0xfa]:add(operation=2,action=action,known=0,domain='unknown_policy_page')
    # Isolated original records test all period-unit thresholds and source mass/temp formatting.
    for exponent in [0,19,20,27,28,35]:
        record=bytearray(68*4)
        struct.pack_into('<I',record,0,0x0044ab55)
        struct.pack_into('<I',record,4,0x12345678)
        struct.pack_into('<HH',record,8,0,9)
        struct.pack_into('<I',record,14,0x00310000|0x9123)
        struct.pack_into('<I',record,20,(exponent<<16)|0x9234)
        struct.pack_into('<HHH',record,32,123,32768,288)
        record[38:44]=b'EARTH\0'
        add(operation=2,action=0x80,body_hex=record.hex(),domain='body_page')
    # Real original F881-generated banks are inputs, not calculated expected pages.
    controls=json.loads((PROJECT/'tests/fixtures/source_system_native.json').read_text())
    selected=0
    for original_case in controls['system_cases']:
        records=original_case['expected_records']
        if not all(str(i) in records for i in range(4)):continue
        if any(int.from_bytes(bytes.fromhex(records[str(i)])[10:12],'little')==35 for i in range(4)):continue
        bank=b''.join(bytes.fromhex(records[str(i)]) for i in range(4))
        for index in [1,2]:
            if not 0<int.from_bytes(bank[index*68+10:index*68+12],'little')<32:continue
            add(operation=2,action=0x80+index,body_hex=bank.hex(),domain='source_generated_body_page',
                input_source_case=selected,input_source_bank_sha256=original_case['expected_bank_sha256'])
        selected+=1
        if selected>=32:break
    # Exercise both co-orbital branches and original contiguous ground-port joining.
    for binary in [False,True]:
        bank=bytearray(272)
        struct.pack_into('<I',bank,0,0x0044ab55)
        struct.pack_into('<H',bank,10,0 if binary else 18)
        for index in [1,2]:
            struct.pack_into('<I',bank,index*68,0x0030ab55)
            struct.pack_into('<HH',bank,index*68+8,1,9)
            struct.pack_into('<I',bank,index*68+14,0x00319123)
            struct.pack_into('<I',bank,index*68+20,0x001a9234)
            struct.pack_into('<HHH',bank,index*68+32,123,32768,288)
            bank[index*68+38:index*68+43]=b'BODY\0'
        for index in [1,2]:add(operation=2,action=0x80+index,body_hex=bank.hex(),domain='coorbital_boundary')
    for names_count in [0,1,2]:
        bank=bytearray(272)
        struct.pack_into('<I',bank,0,0x0044ab55);struct.pack_into('<H',bank,10,9);struct.pack_into('<H',bank,36,288)
        bank[38:44]=b'EARTH\0'
        for index in range(1,names_count+1):
            struct.pack_into('<I',bank,index*68,1);struct.pack_into('<H',bank,index*68+10,35)
            name=('PORT'+str(index)).encode()+b'\0';bank[index*68+38:index*68+38+len(name)]=name
        add(operation=2,action=0x80,body_hex=bank.hex(),domain='ground_port_list')
    for row in rows:
        if row.get('body_hex'):
            index=row['action']-0x80;row['record_index']=index;row['bank_hex']=row['body_hex']
            row['record_hex']=row['body_hex'][index*136:(index+1)*136]
    return rows


def packet(row:dict) -> bytes:
    values=[row['operation'],row['code'],row['metadata_index']&0xffffffff,row['action'],row['system_id'],
            *(v&0xffffffff for v in row['variables']),row['flags'],row['known'],0,0,0,0]
    raw=bytes.fromhex(row.get('raw_hex','00'));v4=bytes.fromhex(row.get('string4_hex','00'));v5=bytes.fromhex(row.get('string5_hex','00'))
    body=bytes.fromhex(row.get('body_hex',''))
    if len(raw)>1536 or len(v4)>256 or len(v5)>256 or len(body)>272:raise ValueError('Input too long')
    return struct.pack('<16I',*values)+raw.ljust(1536,b'\0')+v4.ljust(256,b'\0')+v5.ljust(256,b'\0')+body.ljust(272,b'\0')


def result(row:dict,raw:bytes) -> dict:
    length,count,used,guard=struct.unpack_from('<4I',raw)
    if guard!=0xabcdef13 or count>MAX_CALLS or used>TEXT_BYTES:raise ValueError('Output bounds')
    out={}
    text=raw[64:64+TEXT_BYTES]
    if row['operation'] in [0,1,4]:
        if not 1<=length<TEXT_BYTES or text[length-1]!=0:raise ValueError('Invalid end/NUL: '+str(row))
        out['expected_end_offset']=length
        out['expected_hex']=text[:length].hex()
        out['expected_ascii']=text[:length-1].decode('latin1')
    if row['operation']==3:
        out['expected_policy_values']=list(struct.unpack_from('<3I',raw,20))
        out['expected_commodity_flags_hex']=text[:37].hex()
    if row['operation']==2:
        calls=[]
        for i in range(count):
            v=struct.unpack_from('<12I',raw,64+TEXT_BYTES+i*48)
            code,x,y,color,*tail=v
            variables=tail[:5];offset,n,kind=tail[5:]
            if not 1<=n<=TEXT_BYTES or offset+n>used or text[offset+n-1]!=0:raise ValueError('Call buffer bounds')
            calls.append({'code':code,'x':x,'y':y,'color':color,'variables':variables,'kind':kind,
                          'expected_hex':text[offset:offset+n].hex(),'expected_ascii':text[offset:offset+n-1].decode('latin1')})
        out['expected_calls']=calls
    return out


def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--data-source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'))
    parser.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_information_native.json')
    args=parser.parse_args()
    source_raw=args.source.read_bytes();data_raw=args.data_source.read_bytes();original=args.executable.read_bytes()
    if sha(source_raw)!=names.ASM_SHA or sha(data_raw)!=names.DATA_SHA or sha(original)!=names.SOURCE_SHA:raise ValueError('Unreviewed source bytes')
    native,meta=library(source_raw.decode(),data_raw.decode(),original);native+=entry()
    rows=cases(meta['dos_metadata']);ordered=rows+list(reversed(rows));packets=b''.join(map(packet,ordered))
    with tempfile.TemporaryDirectory(prefix='ffe-information-native-') as directory:
        work=Path(directory);(work/'native.s').write_text(native)
        for command in [['as','--64',str(work/'native.s'),'-o',str(work/'native.o')],['ld','-m','elf_x86_64',str(work/'native.o'),'-o',str(work/'native')]]:
            process=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
            if process.returncode:
                debug=Path('/workspace/recovery/information-native-debug');debug.mkdir(parents=True,exist_ok=True)
                (debug/'native.s').write_text(native)
                raise ValueError(process.stderr.decode())
        outputs=[]
        for _ in range(3):
            process=subprocess.run([str(work/'native')],input=packets,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=45)
            if process.returncode:
                import shutil
                index=len(process.stdout)//OUTPUT_BYTES
                debug=Path('/workspace/recovery/information-native-debug');debug.mkdir(parents=True,exist_ok=True)
                for name in ['native.s','native']:shutil.copyfile(work/name,debug/name)
                (debug/'input.bin').write_bytes(packets[index*INPUT_BYTES:(index+1)*INPUT_BYTES])
                raise ValueError('Native failure at '+str(ordered[index])+' exit='+str(process.returncode)+' stderr='+repr(process.stderr))
            outputs.append(process.stdout)
    if len(outputs[0])!=len(ordered)*OUTPUT_BYTES or any(value!=outputs[0] for value in outputs[1:]):raise ValueError('Incomplete or process-dependent outputs')
    output=outputs[0]
    for i,row in enumerate(rows):
        raw=output[i*OUTPUT_BYTES:(i+1)*OUTPUT_BYTES];reverse=len(ordered)-1-i
        if raw!=output[reverse*OUTPUT_BYTES:(reverse+1)*OUTPUT_BYTES]:raise ValueError('Case-order dependence at '+str(row))
        row.update(result(row,raw))
    fixture={'schema':1,'revision':'original-dos-system-information-native-v1','source_commit':SOURCE_COMMIT,
             'source_variant':'pinned-JJFFE-unmodified-procedures-with-original-DOS-metadata-and-text',
             'source_sha256':names.SOURCE_SHA,'source_assembly_sha256':names.ASM_SHA,'source_data_sha256':names.DATA_SHA,
             'case_count':len(rows),'fresh_process_runs':3,'reverse_repeat_count':len(rows),
             'domain_counts':{domain:sum(r['domain']==domain for r in rows) for domain in sorted({r['domain'] for r in rows})},
             'source_procedure_hashes':meta['source_procedure_hashes'],'resource_hashes':meta['resource_hashes'],
             'adapted_assembly_sha256':sha(native.encode()),'input_packets_sha256':sha(packets),'native_output_sha256':sha(output),
             'canaries_unchanged':True,'input_body_fixture_sha256':sha((PROJECT/'tests/fixtures/source_system_native.json').read_bytes()),
             'scope':'Original F1343/44/47/48, F830/831, F895, F613 and signed integer/fraction/tons formatting. Original F843 FA/F9 and selected body-page branch with original DOS F869/F870 data interpretation. Host supplies F868-selected row, action and body bank; F850 hierarchy draw and console flip are no-ops; draw callbacks record strings/positions. Other GUI, generated-system-name and stateful bracket branches trap. No native GUI or full F868 parity claim.',
             'known_source_quirks':['F870 DATA8791 is +32: commodity32 becomes0x0d; it is not commodity1.',
                 'F1377 inserts point using signed F1545 byte length: negative fractions retain original unusual formatting.',
                 'INT_MIN decimal output follows signed NEG/IDIV source behavior rather than a corrected formatter.',
                 'DATA7182 is a blank first-NUL description; trailing names are excluded.'],
             'cases':rows}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(fixture,ensure_ascii=True,separators=(',',':'))+'\n')
    print(json.dumps({k:fixture[k] for k in ['case_count','domain_counts','native_output_sha256','scope']},indent=2))

if __name__=='__main__':main()
