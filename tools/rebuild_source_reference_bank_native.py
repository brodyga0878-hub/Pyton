#!/usr/bin/env python3
"""DOS F595/F604/F605/F606 raw-reference-bank instruction oracle.

Default replay uses the archived reviewed kernel, without the retail EXE.
--reprove-original reconstructs the kernel after whole-procedure DOS instruction
comparison. F866 is an explicit COPY-only call-boundary probe; F148 records the
request. Neither the ephemeris body nor the event scheduler is claimed here.
"""
from __future__ import annotations
import argparse, copy, hashlib, importlib.util, inspect, json, random, re, struct, subprocess, tempfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
PROOF = PROJECT / 'validation/reference-bank-2026-11-17/native-proof'
EXE_SHA = 'd919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA = 'd4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
OBJECT = 338
BANK = 0x74 + 115 * OBJECT
INPUT = 28 + OBJECT + BANK
OUTPUT = 64 + OBJECT + BANK + 64
NUMBERS = [595,604,605,606,590,1333,1335,1517,1521,1531,1532,1533,
           1657,1658,1660,1661,1662,1663,1669,1677,1678]
OPS = {'parent_velocity':0,'leave_parent':1,'enter_parent':2,
       'leave_then_enter':3,'select_parent':4,'jjffe_copy_boundary_probe':9}

def sha(raw): return hashlib.sha256(raw).hexdigest()
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
def s32(value): return (value & 0x7fffffff) - (value & 0x80000000)

def dos_source(source):
    begin=source.index('; FIX: Linear FOR switch velocity')
    end=source.index('\n\t\tneg dword [ebp+0xfffffe8c]',begin)
    original=[line[1:] for line in source[begin:end].splitlines() if line.startswith(';\t\t')]
    if len(original)!=6: raise ValueError('DOS F595 reversion changed')
    source=source[:begin]+'; Actual DOS F595 EBX loads\n'+'\n'.join(original)+'\n'+source[end:]
    begin=source.index('FUNC_FindFORNew:');end=source.index('FUNC_000606:',begin)
    return source[:begin]+source[end:],original

def reprove(args):
    N=load('reference_bank_original_proof',PROJECT/'tools/rebuild_source_natural_contact_native.py')
    raw=args.source.read_bytes();exe=args.exe.read_bytes()
    if sha(raw)!=ASM_SHA or sha(exe)!=EXE_SHA:raise ValueError('Unsupported original source/EXE')
    source,reverted=dos_source(raw.decode());data=args.data.read_text()
    namespace=dict(N.__dict__)
    function=inspect.getsource(N.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_000595',0x429864)")
    function=function.replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
    exec(function,namespace)
    bodies,records,dis,callbacks,aliases=namespace['proof'](source,data,exe,args.exe,NUMBERS)
    constants={}
    image=N.G.Image(exe)
    for symbol in ('DATA_007800','DATA_007801'):
        at=image.offset(aliases[symbol],4);value=exe[at:at+4]
        if value!=bytes(4):raise ValueError('Original Vec64 negative-zero constant changed')
        constants[symbol]={'address':aliases[symbol],'offset':at,'hex':value.hex()}
    PROOF.mkdir(parents=True,exist_ok=True)
    for number,text in dis.items():(PROOF/f'dos-F{number}.txt').write_text(text)
    selected='\n'.join(bodies[n] for n in NUMBERS)
    # This separate diagnostic intentionally uses JJFFE's COPY loads. It does
    # not import JJFFE orbital math into the DOS runtime profile.
    original595=N.G.block(raw.decode(),595)
    probe=original595.replace('FUNC_000595:','FUNC_999595:')
    probe=re.sub(r'JUMP_(\d+)',r'JJUMP_\1',probe)
    selected+='\n'+probe+'\nFUNC_999999:\nret\n'
    selected=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',selected)
    selected=re.sub(r'add esp,0x(f[0-9a-f]{7})',lambda m:'add esp,-0x%x'%(0x100000000-int(m[1],16)),selected)
    # The large F595 frame spells signed32 LOCAL displacements as +ffff....
    # Normalize their sign before the reviewed ABI adapter classifies positive
    # EBP offsets as arguments. Raw338-byte structure displacements are intact.
    selected=re.sub(r'\[ebp\+0x(f[0-9a-f]{7})(?=[+\]])',lambda m:'[ebp-0x%x'%(0x100000000-int(m[1],16)),selected)
    lines,_=N.Q.procedures(selected,NUMBERS+[999595]);text='\n'.join(lines)
    expected='FUNC_001669:\npush rbp\nmov rbp,rsp\nadd rsp,-8'
    if text.count(expected)!=1:raise ValueError('Unexpected F1669 scratch-local layout')
    text=text.replace(expected,expected.replace('rsp,-8','rsp,-16'))
    kernel='.intel_syntax noprefix\n.code64\n.section .text\n.global _start\n'+text+'\n'+WRAPPER
    kernel=kernel.replace('@INPUT@',str(INPUT)).replace('@OUTPUT@',str(OUTPUT)).replace('@BANK@',str(BANK))
    (PROOF/'reference-bank-observed-kernel.s').write_text(kernel)
    metadata={'schema':'starfrontier-dos-reference-bank-instruction-proof-v1',
      'source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,
      'source_commit':'7e540341d4e09aa3c92877b87d49e7f2c143ad8d',
      'whole_procedure_instruction_equality':records,
      'original_callback_words':callbacks,'original_symbol_addresses':aliases,
      'original_constant_bytes':constants,
      'source_procedure_sha256':{str(n):sha(bodies[n].encode()) for n in NUMBERS},
      'DOS_F595_reversion_lines':reverted,'F866_body_executed':False,'F148_body_executed':False,
      'host_assembly_sha256':sha(kernel.encode()),
      'host_adaptations':['Whole32-bit DOS instructions independently compared before adaptation',
        'Host has no IA32 execution support; reviewed64-bit cdecl stack-slot and saved-register adapter',
        '32-bit arithmetic, raw338-byte records and original instruction order retained',
        'F1669 scratch reservation8 to16 for two host pops',
        'Low-address bank and explicit low-address stack; callback pointers widened only for host calls',
        'F1533 copy-only branch uses a byte-copy host CRT adapter; full model initialization traps',
        'F866 explicit call-boundary probe verifies separate COPY, records future raw timestamp and changes COPY position low DWORDs',
        'F148 explicit request observer checks(11,0); event body not executed'],
      'scope':'Whole DOS F595,F604,F605,F606 plus F590/F1677/F1678 and exact integer helper closure. F606 includes original cache writes. F866 ephemeris, F148 events, F570 dispatcher, live gameplay integration and full original frame bank are outside this proof.'}
    (PROOF/'instruction-proof.json').write_text(json.dumps(metadata,indent=2)+'\n')
    return metadata,kernel

def record(rng,index,parent=0):
    raw=bytearray(rng.randbytes(OBJECT))
    raw[0x25]=0;raw[0x56]=parent;raw[0x57]=0;raw[0x86]=index;raw[0x87]=0
    raw[0x14c]=0
    struct.pack_into('<9i',raw,0,0x7fffffff,0,0,0,0x7fffffff,0,0,0,0x7fffffff)
    struct.pack_into('<3q',raw,0x3e,0,0,0)
    struct.pack_into('<h',raw,0xda,0)
    return raw

def cases():
    rng=random.Random(0x595604606);rows=[]
    extremes=[0,1,-1,0x7fffffff,-0x80000000,0x100000000,-0x100000000,
              0x7fffffffffffffff,-0x8000000000000000,12345678901234,-12345678901234]
    def make(operation,i):
        body=record(rng,114);parent=record(rng,1)
        struct.pack_into('<3q',body,0x3e,*(extremes[(i+j)%len(extremes)] for j in range(3)))
        struct.pack_into('<3q',parent,0x3e,*(extremes[(i+3+j)%len(extremes)] for j in range(3)))
        for at in (0x8c,0x90,0x94):
            struct.pack_into('<i',body,at,rng.choice([0,1,-1,0x7fffffff,-0x80000000,rng.randint(-2**31,2**31-1)]))
            struct.pack_into('<i',parent,at,rng.choice([0,1,-1,0x7fffffff,-0x80000000,rng.randint(-2**31,2**31-1)]))
        parent[0x87]=[0,1,1,1,2,255][i%6];parent[0x14c]=[0,0,0x20,0xff,0x10,0][i%6]
        struct.pack_into('<II',parent,0xa8,[0,1,0xfff7d3ff,0xfff7d400,0xffffffff][i%5],rng.getrandbits(32))
        body[0x56]=1 if operation in ('leave_parent','leave_then_enter') else 0
        parent[0x56]=0
        flags=bytearray(115);flags[1]=0x10
        future=[s32(rng.getrandbits(32)) for _ in range(3)]
        return {'name':f'{operation}/{i}','operation':operation,'profile':'dos-firstenc',
          'body_hex':body.hex(),'parent_hex':parent.hex(),'parent_index_u8':1,'target_index_u8':1,
          'source_frame_byte':1,'flags_hex':flags.hex(),'objects_by_index':{'1':parent.hex()},
          'future_copy_position_low_s32':future}
    for operation,count in [('parent_velocity',72),('leave_parent',72),('enter_parent',72),('leave_then_enter',36)]:
        for i in range(count):rows.append(make(operation,i))
    # The selector sees real source bank slots1..114 and the original descending
    # flag scan. Inputs deliberately cover cache hits, overflow, rotating parents,
    # escape to a grandparent, sibling competition and unchanged rotating players.
    for i in range(192):
        body=record(rng,114);flags=bytearray(115);objects={}
        indices=[1,2,3,17,63,113]
        for j,index in enumerate(indices):
            parent=0 if j==0 else indices[(j-1)//2]
            item=record(rng,index,parent)
            exponent=[0,8,15,22,30,40,55,62][(i+j)%8]
            coords=[rng.randint(-8191,8191)*(1<<min(exponent,48)) for _ in range(3)]
            # Keep graph coordinates within signed64 while retaining overflow
            # boundaries in the independent translation cases above.
            struct.pack_into('<3q',item,0x3e,*coords)
            struct.pack_into('<h',item,0xda,rng.choice([-32768,-128,-1,0,1,8,32,127,32767]))
            item[0x87]=[0,1,1,2][(i+j)%4];item[0x14c]=[0,0,0x20,0][(i+j)%4]
            item[0x57]=1 if (i+j)%11==0 and parent else 0
            item[0x25]=[0,1,127,255][(i+j)%4]
            struct.pack_into('<3q',item,0x26,*(rng.randint(-(1<<50),1<<50) for _ in range(3)))
            flags[index]=0x10 if (i+j)%5!=0 else 1
            objects[str(index)]=item.hex()
        body[0x56]=[0,1,2,3,17,63,113][i%7]
        body[0x57]=1 if i%9==0 else 0
        struct.pack_into('<3q',body,0x3e,*(rng.randint(-(1<<45),1<<45) for _ in range(3)))
        struct.pack_into('<3i',body,0x8c,*(rng.randint(-2**31,2**31-1) for _ in range(3)))
        body[0x25]=0
        row={'name':f'select_parent/{i}','operation':'select_parent','profile':'dos-firstenc',
          'body_hex':body.hex(),'parent_index_u8':int(body[0x56]),'target_index_u8':1,
          'source_frame_byte':[1,127,255][i%3],'flags_hex':flags.hex(),
          'objects_by_index':objects,'future_copy_position_low_s32':[s32(rng.getrandbits(32)) for _ in range(3)]}
        rows.append(row)
    probes=[]
    for i in range(16):
        row=make('parent_velocity',i);p=bytearray.fromhex(row['parent_hex']);p[0x87]=1;p[0x14c]=0
        row.update({'operation':'jjffe_copy_boundary_probe','name':f'JJFFE_COPY_boundary_only/{i}',
                    'profile':'jjffe-F595-COPY-boundary-probe-only','parent_hex':p.hex(),
                    'objects_by_index':{'1':p.hex()}});probes.append(row)
    return rows,probes

def packet(row):
    bank=bytearray([0xa5])*BANK;bank[:115]=bytes.fromhex(row['flags_hex'])
    for index,value in row['objects_by_index'].items():
        at=0x74+int(index)*OBJECT;bank[at:at+OBJECT]=bytes.fromhex(value)
    return struct.pack('<4I3i',OPS[row['operation']],row['parent_index_u8'],row['target_index_u8'],row['source_frame_byte'],*row['future_copy_position_low_s32'])+bytes.fromhex(row['body_hex'])+bank

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'))
    parser.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_reference_bank_native.json')
    parser.add_argument('--reprove-original',action='store_true');args=parser.parse_args()
    if args.reprove_original:metadata,kernel=reprove(args)
    else:
        metadata=json.loads((PROOF/'instruction-proof.json').read_text());kernel=(PROOF/'reference-bank-observed-kernel.s').read_text()
        if sha(kernel.encode())!=metadata['host_assembly_sha256']:raise ValueError('Archived observed kernel changed')
    rows,probes=cases();all_rows=rows+probes;packets=[packet(r) for r in all_rows]
    with tempfile.TemporaryDirectory(prefix='reference-bank-native-') as directory:
        p=Path(directory);(p/'native.s').write_text(kernel)
        subprocess.run(['as','--64','-o',str(p/'native.o'),str(p/'native.s')],check=True)
        subprocess.run(['ld','-o',str(p/'native'),str(p/'native.o')],check=True)
        runs=[subprocess.run([str(p/'native')],input=b''.join(packets),capture_output=True,check=True,timeout=120).stdout for _ in range(3)]
        if len(set(runs))!=1 or len(runs[0])!=len(all_rows)*OUTPUT:raise ValueError('Unstable/truncated native output')
        reverse=subprocess.run([str(p/'native')],input=b''.join(reversed(packets)),capture_output=True,check=True,timeout=120).stdout
        if reverse!=b''.join(runs[0][i*OUTPUT:(i+1)*OUTPUT] for i in reversed(range(len(all_rows)))):raise ValueError('Native case-order leakage')
    for i,row in enumerate(all_rows):
        output=runs[0][i*OUTPUT:(i+1)*OUTPUT];header=struct.unpack_from('<16I',output)
        if header[0]!=0x52454642 or header[7] or output[-64:]!=bytes([0xa5])*64:raise ValueError('Native pointer/ABI/canary guard failed '+row['name'])
        expected_body=output[64:64+OBJECT];expected_bank=output[64+OBJECT:64+OBJECT+BANK]
        row['expected_body_hex']=expected_body.hex();row['expected_flags_hex']=expected_bank[:115].hex()
        row['expected_objects_by_index']={index:expected_bank[0x74+int(index)*OBJECT:0x74+(int(index)+1)*OBJECT].hex() for index in row['objects_by_index']}
        row['expected_parent_velocity_s32']=[s32(x) for x in header[8:11]]
        row['expected_events']=[[11,0]]*header[1]
        row['expected_copy_calls']=header[2];row['expected_future_copy_calls']=header[3]
        row['expected_future_clock']={'tick_u32':header[4],'day_u32':header[5]} if header[3] else None
        row['expected_bank_changed']=expected_bank!=packet(row)[28+OBJECT:]
        # No unprovided slot, bank flag or canary may change under these bounded
        # whole-procedure inputs. Cache changes are retained on provided slots.
        original=bytearray(packet(row)[28+OBJECT:])
        for index in row['objects_by_index']:
            at=0x74+int(index)*OBJECT;original[at:at+OBJECT]=expected_bank[at:at+OBJECT]
        if bytes(original)!=expected_bank or row['flags_hex']!=row['expected_flags_hex']:raise ValueError('Unowned bank slot/flag changed')
    fixture={'schema':'starfrontier-source-reference-bank-native-v1','profile':'dos-firstenc',
      'source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,
      'instruction_proof_sha256':sha((PROOF/'instruction-proof.json').read_bytes()),
      'host_assembly_sha256':sha(kernel.encode()),'input_packets_sha256':sha(b''.join(packets)),
      'native_output_sha256':sha(runs[0]),'case_count':len(rows),'diagnostic_case_count':len(probes),
      'fresh_process_runs':3,'reverse_case_count':len(all_rows),'guards_and_bank_flags_unchanged':True,
      'scope':metadata['scope'],'cases':rows,'JJFFE_COPY_boundary_diagnostics':probes}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(fixture,ensure_ascii=False,indent=2)+'\n')
    result={'case_count':len(rows),'diagnostic_cases':len(probes),'bytes':args.output.stat().st_size,
            'fixture_sha256':sha(args.output.read_bytes()),'native_cases_total':len(all_rows),
            'native_output_sha256':fixture['native_output_sha256'],'status':'native-replayed-and-guards-verified'}
    (PROOF/'reproduction.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))

WRAPPER=r'''
FUNC_001538:
FUNC_001495:
 mov edi,97
 jmp exit
_memcpy:
 push rbp
 mov rbp,rsp
 push rsi
 push rdi
 mov edi,DWORD PTR [rbp+16]
 mov esi,DWORD PTR [rbp+24]
 mov ecx,DWORD PTR [rbp+32]
 mov eax,edi
 cld
 rep movsb
 inc DWORD PTR [copy_calls]
 pop rdi
 pop rsi
 pop rbp
 ret
FUNC_000148:
 push rbp
 mov rbp,rsp
 cmp DWORD PTR [rbp+16],11
 jne bad_request
 cmp DWORD PTR [rbp+24],0
 jne bad_request
 inc DWORD PTR [event_calls]
 pop rbp
 ret
bad_request:
 or DWORD PTR [guard_error],1
 pop rbp
 ret
FUNC_000866:
 push rbp
 mov rbp,rsp
 push rbx
 push rsi
 mov eax,DWORD PTR [rbp+16]
 mov ebx,DWORD PTR [eax+8]
 cmp ebx,OFFSET FLAT:stack
 jb bad_copy
 lea edx,[ebx+338]
 cmp edx,OFFSET FLAT:stack_end
 ja bad_copy
 cmp BYTE PTR [ebx+0x86],0
 jne bad_copy
 mov edx,DWORD PTR [eax]
 mov DWORD PTR [future_tick],edx
 mov DWORD PTR [ebx+0xa8],edx
 mov edx,DWORD PTR [eax+4]
 mov DWORD PTR [future_day],edx
 mov DWORD PTR [ebx+0xac],edx
 mov edx,DWORD PTR [input+16]
 mov DWORD PTR [ebx+0x3e],edx
 mov edx,DWORD PTR [input+20]
 mov DWORD PTR [ebx+0x46],edx
 mov edx,DWORD PTR [input+24]
 mov DWORD PTR [ebx+0x4e],edx
 inc DWORD PTR [future_calls]
 jmp future_done
bad_copy:
 or DWORD PTR [guard_error],2
future_done:
 pop rsi
 pop rbx
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
 add esi,r8d
 mov edx,@INPUT@
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,@INPUT@
 jne read_more
 cld
 mov edi,OFFSET FLAT:body_before
 mov ecx,370
 mov al,0xa5
 rep stosb
 mov edi,OFFSET FLAT:bank_before
 mov ecx,@BANK@+32
 mov al,0xa5
 rep stosb
 mov edi,OFFSET FLAT:output
 mov ecx,@OUTPUT@
 xor eax,eax
 rep stosb
 mov esi,OFFSET FLAT:input+28
 mov edi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:bank
 mov ecx,@BANK@
 rep movsb
 mov edi,OFFSET FLAT:event_calls
 xor eax,eax
 mov ecx,10
 rep stosd
 mov al,BYTE PTR [input+12]
 mov BYTE PTR [DATA_008811],al
 mov eax,DWORD PTR [input]
 cmp eax,0
 je parent_velocity
 cmp eax,1
 je leave_parent
 cmp eax,2
 je enter_parent
 cmp eax,3
 je compose
 cmp eax,4
 je select_parent
 cmp eax,9
 je jjffe_probe
 mov edi,96
 jmp exit
parent_velocity:
 push OFFSET FLAT:velocity_result
 call parent_pointer
 push rax
 call FUNC_000595
 add rsp,16
 jmp capture
jjffe_probe:
 push OFFSET FLAT:velocity_result
 call parent_pointer
 push rax
 call FUNC_999595
 add rsp,16
 jmp capture
leave_parent:
 call parent_pointer
 push rax
 push OFFSET FLAT:body
 call FUNC_000604
 add rsp,16
 jmp capture
enter_parent:
 mov eax,DWORD PTR [input+8]
 push rax
 push OFFSET FLAT:bank
 push OFFSET FLAT:body
 call FUNC_000605
 add rsp,24
 jmp capture
compose:
 call parent_pointer
 push rax
 push OFFSET FLAT:body
 call FUNC_000604
 add rsp,16
 jmp enter_parent
select_parent:
 push OFFSET FLAT:bank
 push OFFSET FLAT:body
 call FUNC_000606
 add rsp,16
capture:
 mov DWORD PTR [output],0x52454642
 mov esi,OFFSET FLAT:event_calls
 mov edi,OFFSET FLAT:output+4
 mov ecx,28
 rep movsb
 mov esi,OFFSET FLAT:velocity_result
 mov edi,OFFSET FLAT:output+32
 mov ecx,12
 rep movsb
 mov esi,OFFSET FLAT:body
 mov edi,OFFSET FLAT:output+64
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:bank
 mov ecx,@BANK@
 rep movsb
 mov esi,OFFSET FLAT:body_before
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:body_after
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:bank_before
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:bank_after
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:output
 mov edx,@OUTPUT@
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
parent_pointer:
 mov eax,DWORD PTR [input+4]
 imul eax,338
 add eax,OFFSET FLAT:bank+0x74
 ret
failed:
 mov edi,94
 jmp exit
finished:
 xor edi,edi
exit:
 mov eax,60
 syscall
.section .data
DATA_007753: .quad FUNC_001531
DATA_007754: .quad FUNC_001532
DATA_007755: .quad FUNC_001533
DATA_007749: .quad FUNC_001517
DATA_007802: .quad FUNC_001677
DATA_007803: .quad FUNC_001678
DATA_007800: .long 0
DATA_007801: .long 0
DATA_007734: .quad FUNC_001495
DATA_007758: .long bank
DATA_008811: .byte 0
DATA_008804: .long 0
DATA_008807: .long 0
DATA_007210: .zero 64
.section .bss
.balign 16
input: .zero @INPUT@
body_before: .zero 16
body: .zero 338
body_after: .zero 16
bank_before: .zero 16
bank: .zero @BANK@
bank_after: .zero 16
output: .zero @OUTPUT@
event_calls: .zero 4
copy_calls: .zero 4
future_calls: .zero 4
future_tick: .zero 4
future_day: .zero 4
unused: .zero 4
guard_error: .zero 4
velocity_result: .zero 12
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
'''
if __name__=='__main__':main()
