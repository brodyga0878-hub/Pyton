#!/usr/bin/env python3
"""Reproduce raw angular controls from independently DOS-checked instructions.

Expected state is emitted by native original arithmetic, never Python math.
The host lacks IA32 execution: the established cdecl stack/register adapter
expands only pointer/stack plumbing to64bits, retaining32bit calculations.
Fresh reproduction can use the archived independently checked source/proof.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import inspect
import json
from pathlib import Path
import random
import re
import struct
import subprocess
import tempfile

PROJECT=Path(__file__).resolve().parents[1]
PROFILE='dos-firstenc-angular-motion-v1'
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
NUMBERS=[585,584,611,609,1520,1519,1552,1466,1656,1523,1521,1502]
OBJECT=338
INPUT=52+OBJECT
OUTPUT=384
PROOF=PROJECT/'validation/reference-bank-2026-11-17/angular-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_angular_native.json'

def sha(raw):return hashlib.sha256(raw).hexdigest()
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    result=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result

def prepare_proof(asm_path,data_path,exe_path,proof):
    N=load('angular_original_proof',PROJECT/'tools/rebuild_source_natural_contact_native.py')
    exe=exe_path.read_bytes();asm_raw=asm_path.read_bytes()
    if sha(exe)!=EXE_SHA or sha(asm_raw)!=ASM_SHA:raise ValueError('Pinned original executable/source differs')
    source=asm_raw.decode().replace('\r\n','\n');data=data_path.read_text()
    signature=bytes.fromhex('558bec83c4f85356578b45148b750c8b5d088d7dfc8b9382000000')
    if exe.find(signature)!=0x19ea4 or exe.find(signature,0x19ea5)>=0:raise ValueError('Ambiguous originalF585 entry')
    # Reuse the existing independently reviewed resolver. Seed is anchored by
    # unique executable bytes, then every full body is compared instructionwise.
    resolver=inspect.getsource(N.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_000585',0x4290a4)")
    resolver=resolver.replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
    namespace=N.__dict__.copy();exec(resolver,namespace)
    bodies,records,disassembly,_,aliases=namespace['proof'](source,data,exe,exe_path,NUMBERS)
    image=N.G.Image(exe)
    raw_tables=exe[image.offset(aliases['DATA_006159'],12):image.offset(aliases['DATA_006159'],12)+12]
    if raw_tables!=bytes.fromhex('120303030502010101010000'):raise ValueError('OriginalF611 table differs')
    useful_symbols=set(re.findall(r'\b(?:DATA_\d+|FUNC_\d+)(?:_[A-Za-z0-9_]+)?|_abs','\n'.join(bodies.values())))
    useful_symbols={re.sub(r'(FUNC_\d{6})_[A-Za-z0-9_]+',r'\1',s) for s in useful_symbols}
    bindings={key:aliases[key] for key in sorted(useful_symbols)}
    for number,record in records.items():
        at=record['executable_offset'];raw=exe[at:at+record['byte_length']]
        record['hex']=raw.hex()
    abs_raw=N.G.ABS_DOS
    if exe[0x67038:0x67038+len(abs_raw)]!=abs_raw:raise ValueError('Pinned DOSabs differs')
    extracted='\n'.join(bodies[n] for n in NUMBERS)
    proof.mkdir(parents=True,exist_ok=True)
    (proof/'source-procedures.s').write_text(extracted)
    report={'schema':'starfrontier-original-angular-instruction-proof-v1',
        'source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,
        'source_procedure_sha256':{str(n):sha(bodies[n].encode()) for n in NUMBERS},
        'procedures':records,'bindings':bindings,'source_procedures_sha256':sha(extracted.encode()),
        'decrement_table_hex':raw_tables.hex(),'decrement_table_executable_offset':image.offset(aliases['DATA_006159'],12),
        'abs':{'virtual_address':0x476238,'executable_offset':0x67038,'hex':abs_raw.hex(),'sha256':sha(abs_raw)},
        'all_full_procedure_instructions_equal':True,
        'scope':'Full independent32bit reassembly versus originalDOS instructions, including realF1520/F1519/F1552 normalization. Actual branch destinations normalized; no live player scheduling/world pipeline is implied.'}
    (proof/'instruction-proof.json').write_text(json.dumps(report,indent=2)+'\n')
    (proof/'dos-disassembly.txt').write_text('\n'.join('F'+n+'\n'+s for n,s in disassembly.items()))

def assembly(source):
    abi=load('angular_host_adapter',PROJECT/'recovered-history/ground_harness/tools/native_reference.py')
    selected=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',source)+'\nFUNC_999999:\nret\n'
    lines,_=abi.procedures(selected,NUMBERS);text='\n'.join(lines)
    old='FUNC_000585:\npush rbp\nmov rbp,rsp\nadd rsp,-8'
    if text.count(old)!=1:raise ValueError('UnreviewedF585 two-pop local reservation')
    text=text.replace(old,old.replace('rsp,-8','rsp,-16'))
    if text.count('[rbp+ebx-0xe]')!=1:raise ValueError('UnreviewedF611 local table index')
    text=text.replace('[rbp+ebx-0xe]','[rbp+rbx-0xe]')
    return '.intel_syntax noprefix\n.code64\n.section .text\n.global _start\n'+text+f'''
_abs:
 push rbp
 mov rbp,rsp
 mov eax,DWORD PTR [rbp+16]
 test eax,eax
 jge abs_nonnegative
 mov edx,eax
 neg edx
 jmp abs_return
abs_nonnegative:
 mov edx,eax
abs_return:
 mov eax,edx
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
 add rsi,r8
 mov edx,{INPUT}
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,{INPUT}
 jne read_more
 cld
 mov edi,OFFSET FLAT:body_before
 mov ecx,{OBJECT+32}
 mov al,0xa5
 rep stosb
 mov esi,OFFSET FLAT:input+52
 mov edi,OFFSET FLAT:body
 mov ecx,{OBJECT}
 rep movsb
 mov eax,DWORD PTR [input+16]
 mov DWORD PTR [DATA_008857],eax
 mov ax,WORD PTR [input+20]
 mov WORD PTR [DATA_008933],ax
 mov eax,DWORD PTR [input+40]
 mov DWORD PTR [DATA_008708],eax
 mov eax,DWORD PTR [input+44]
 mov DWORD PTR [DATA_008709],eax
 mov eax,DWORD PTR [input+48]
 mov DWORD PTR [DATA_008710],eax
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [quantized],eax
 mov DWORD PTR [quantized_shift],0
 mov eax,DWORD PTR [input]
 cmp eax,1
 je quantize
 cmp eax,2
 je rotate_pair
 cmp eax,3
 je spin_command
 cmp eax,4
 je normalize
 push QWORD PTR [input+12]
 push QWORD PTR [input+8]
 push QWORD PTR [input+4]
 push OFFSET FLAT:body
 call FUNC_000585
 add rsp,32
 jmp capture
quantize:
 push OFFSET FLAT:quantized_shift
 push OFFSET FLAT:quantized
 call FUNC_000584
 add rsp,16
 jmp capture
rotate_pair:
 mov eax,DWORD PTR [input+36]
 push rax
 mov eax,0x70
 cmp DWORD PTR [input+32],0
 je pair_flag_ready
 mov eax,0x6d
pair_flag_ready:
 push rax
 mov eax,DWORD PTR [input+28]
 add eax,OFFSET FLAT:body
 push rax
 mov eax,DWORD PTR [input+24]
 add eax,OFFSET FLAT:body
 push rax
 push OFFSET FLAT:body
 call FUNC_000611
 add rsp,40
 jmp capture
spin_command:
 push OFFSET FLAT:body
 call FUNC_000609
 add rsp,8
 jmp capture
normalize:
 push OFFSET FLAT:body
 call FUNC_001520
 add rsp,8
capture:
 mov esi,OFFSET FLAT:body
 mov edi,OFFSET FLAT:output
 mov ecx,{OBJECT}
 rep movsb
 mov ax,WORD PTR [DATA_008933]
 mov WORD PTR [output+338],ax
 mov eax,DWORD PTR [DATA_008857]
 mov DWORD PTR [output+340],eax
 mov eax,DWORD PTR [quantized]
 mov DWORD PTR [output+344],eax
 mov eax,DWORD PTR [quantized_shift]
 mov DWORD PTR [output+348],eax
 mov edi,OFFSET FLAT:output+352
 mov esi,OFFSET FLAT:body_before
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:body_after
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:output
 mov edx,{OUTPUT}
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
failed:
 mov edi,95
 jmp exit
finished:
 xor edi,edi
exit:
 mov eax,60
 syscall
.section .data
DATA_006159: .byte 18,3,3,3
DATA_006160: .byte 5,2,1,1
DATA_006161: .byte 1,1,0,0
DATA_007719: .quad FUNC_001520
DATA_007738: .quad FUNC_001502
.section .bss
.balign 16
input: .zero {INPUT}
body_before: .zero 16
body: .zero {OBJECT}
body_after: .zero 16
output: .zero {OUTPUT}
DATA_008708: .zero 4
DATA_008709: .zero 4
DATA_008710: .zero 4
DATA_008857: .zero 4
DATA_008933: .zero 2
quantized: .zero 4
quantized_shift: .zero 4
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
'''

MATRICES=[(2147483647,0,0,0,2147483647,0,0,0,2147483647),
    (0,0,-2147483648,0,2147483647,0,2147483647,0,0),
    (0,2147483647,0,-2147483648,0,0,0,0,2147483647),
    (1518500249,0,1518500249,0,2147483647,0,-1518500249,0,1518500249)]

def make_case(rng,index,operation):
    body=bytearray(rng.randbytes(OBJECT))
    struct.pack_into('<9i',body,0,*MATRICES[index%len(MATRICES)])
    body[0x24]=[0,1,18,60,127,128,255][index%7]
    struct.pack_into('<I',body,0x82,[0,15,24,38,52,53,58,59,149,0xffffffff][index%10])
    body[0x86]=index%3
    residuals=[-32768,-2555,-1297,-651,-326,-163,-82,-41,-20,-15,-14,-1,0,1,14,15,19,20,21,40,41,82,163,326,651,1297,2555,32767]
    for axis in range(3):
        struct.pack_into('<h',body,0xb0+axis*2,residuals[(index+axis*7)%len(residuals)])
        struct.pack_into('<h',body,0x110+axis*2,[-32768,-16384,-1,0,1,16384,32767][(index+axis*3)%7])
    budgets=[0,14,15,19,20,41,82,163,326,651,1297,2555,32767,32768,0x7fffffff,-1,-0x80000000]
    ticks=[0,1,32766,32767,32768,65535,0x7fffffff,-1,-0x80000000]
    return {'name':f'op{operation}-{index:04d}','operation':operation,'budget_s32':budgets[index%len(budgets)],
        'accumulate':bool(index%2),'elapsed_ticks_s32':ticks[(index//2)%len(ticks)],
        'globals_before':{'player_index_u32':[0,1,2,255,0xffffffff][index%5],'player_roll_s16':[-32768,-2555,-1,0,1,2555,32767][index%7]},
        'first_offset':(index%3)*12,'second_offset':((index+1+index//3%2)%3)*12,
        'positive':bool(index%2),'shift_s32':index%8+2,
        'spin_xyz_s32':[rng.choice([0,1,-1,0x7fffffff,-0x80000000,65536,-65536]) for _ in range(3)],
        'body_before_hex':body.hex()}

def packet(case):
    first,second=case['first_offset'],case['second_offset']
    if first==second:second=(first+12)%36
    case['second_offset']=second
    state=case['globals_before']
    return struct.pack('<iiiiIiIIIIiii',case['operation'],case['budget_s32'],int(case['accumulate']),case['elapsed_ticks_s32'],
        state['player_index_u32'],state['player_roll_s16'],first,second,0 if case['positive'] else 1,case['shift_s32'],*case['spin_xyz_s32'])+bytes.fromhex(case['body_before_hex'])

def decode(raw):
    if len(raw)!=OUTPUT or raw[352:]!=b'\xa5'*32:raise ValueError('Native original angular body canary changed')
    return {'body_after_hex':raw[:OBJECT].hex(),
        'globals_after':{'player_roll_s16':struct.unpack_from('<h',raw,338)[0],'player_index_u32':struct.unpack_from('<I',raw,340)[0]},
        'quantized_amount_s32':struct.unpack_from('<i',raw,344)[0],'quantized_shift_s32':struct.unpack_from('<i',raw,348)[0],
        'body_canaries_unchanged':True}

def verify_archived_instructions(reference,source):
    # Fresh source archives need no private DOS executable. Reassemble the
    # archived original procedures at their real32bit addresses and compare
    # them with the independently captured original executable bytes again.
    N=load('angular_archived_instruction_verifier',PROJECT/'tools/rebuild_source_natural_contact_native.py')
    if reference['decrement_table_hex']!='120303030502010101010000' or bytes.fromhex(reference['abs']['hex'])!=N.G.ABS_DOS:raise ValueError('Archived original angular constants differ')
    aliases=reference['bindings']
    with tempfile.TemporaryDirectory(prefix='source-angular-instruction-replay-') as tmp:
        work=Path(tmp)
        for number in NUMBERS:
            row=reference['procedures'][str(number)];body=N.G.block(source,number)
            compiled=N.C.J.instructions(N.C.compile32(body,aliases,'FUNC_%06d'%number,row['virtual_address']))
            raw_path=work/('F'+str(number)+'.bin');raw_path.write_bytes(bytes.fromhex(row['hex']))
            text=subprocess.check_output(['objdump','-D','-b','binary','-m','i386','-Mintel','--no-show-raw-insn',
                '--adjust-vma='+hex(row['virtual_address']),str(raw_path)],text=True)
            actual=N.C.J.instructions(text)
            if len(actual)!=row['instruction_count'] or N.canonical(actual)!=N.canonical(compiled):raise ValueError('Archived angular DOS instruction comparison differsF'+str(number))

def generate(proof,output):
    reference=json.loads((proof/'instruction-proof.json').read_text());source=(proof/'source-procedures.s').read_text()
    if sha(source.encode())!=reference['source_procedures_sha256'] or reference['source_executable_sha256']!=EXE_SHA or not reference['all_full_procedure_instructions_equal']:raise ValueError('Archived angular original proof differs')
    if set(reference['procedures'])!=set(map(str,NUMBERS)) or any(not row['all_instructions_equal'] or sha(bytes.fromhex(row['hex']))!=row['sha256'] for row in reference['procedures'].values()):raise ValueError('Archived original angular instruction set differs')
    verify_archived_instructions(reference,source)
    native=assembly(source);rng=random.Random(0x585611)
    cases=[make_case(rng,index,0) for index in range(272)]
    cases += [make_case(rng,index,operation) for operation,count in [(1,65),(2,128),(3,80),(4,32)] for index in range(count)]
    quantizer_boundaries=[-0x80000000,-1,0,14,15,19,20,21,40,41,42,81,82,83,162,163,164,325,326,327,650,651,652,1296,1297,1298,2554,2555,2556,32766,32767,32768,0x7fffffff]
    for index,case in enumerate(row for row in cases if row['operation']==1):case['budget_s32']=quantizer_boundaries[index%len(quantizer_boundaries)]
    for index,case in enumerate(row for row in cases if row['operation']==2):
        first=index//16%3
        case.update(positive=bool(index//8%2),first_offset=first*12,second_offset=((first+1+index//48%2)%3)*12)
    with tempfile.TemporaryDirectory(prefix='source-angular-native-') as tmp:
        work=Path(tmp);(work/'angular.s').write_text(native)
        subprocess.run(['as','--64',str(work/'angular.s'),'-o',str(work/'angular.o')],check=True)
        subprocess.run(['ld',str(work/'angular.o'),'-o',str(work/'angular')],check=True)
        def run(payload):
            completed=subprocess.run([str(work/'angular')],input=payload,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=60,check=True)
            if completed.stderr or len(completed.stdout)!=len(payload)//INPUT*OUTPUT:raise ValueError('Native angular output domain differs')
            return completed.stdout
        # Consecutive inputs are taken only from the previous actual native
        # output, preserving original word residues and normalized matrices.
        previous=make_case(rng,1000,0);previous['budget_s32']=1000;previous['elapsed_ticks_s32']=1000;previous['accumulate']=True
        body=bytearray(bytes.fromhex(previous['body_before_hex']));body[0x86]=0;struct.pack_into('<I',body,0x82,24);struct.pack_into('<3h',body,0xb0,0,0,0);struct.pack_into('<3h',body,0x110,32767,-32768,16384);previous['body_before_hex']=body.hex();previous['globals_before']={'player_index_u32':0,'player_roll_s16':32767}
        for index in range(64):
            case=json.loads(json.dumps(previous));case['name']=f'consecutive-native-{index:03d}';case['sequence_step']=index
            result=decode(run(packet(case)));cases.append(case)
            previous=case.copy();previous['body_before_hex']=result['body_after_hex'];previous['globals_before']=result['globals_after']
        payload=b''.join(packet(case) for case in cases)
        runs=[run(payload) for _ in range(3)]
        if runs[0]!=runs[1] or runs[0]!=runs[2]:raise ValueError('Original angular output differs between fresh processes')
        reverse=run(b''.join(packet(case) for case in reversed(cases)))
        if reverse!=b''.join(runs[0][index*OUTPUT:(index+1)*OUTPUT] for index in reversed(range(len(cases)))):raise ValueError('Original angular process state leaked across cases')
        for index,case in enumerate(cases):case.update(decode(runs[0][index*OUTPUT:(index+1)*OUTPUT]))
    # Provenance identifies the logical archived source files, independent of
    # where a caller copies their SHA-checked proof for an isolated replay.
    # The hashes still come from the actual supplied files. A private replay
    # directory must neither raise relative_to() nor change fixture bytes.
    pins={str((PROOF/name).relative_to(PROJECT)):sha((proof/name).read_bytes()) for name in ('instruction-proof.json','source-procedures.s')}
    abi_path=PROJECT/'recovered-history/ground_harness/tools/native_reference.py'
    pins[str(abi_path.relative_to(PROJECT))]=sha(abi_path.read_bytes())
    report={'schema':1,'profile':PROFILE,'source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,
        'original_provenance_sha256':pins,'source_procedure_sha256':reference['source_procedure_sha256'],
        'host_adapted_assembly_sha256':sha(native.encode()),'input_packets_sha256':sha(payload),'native_output_sha256':sha(runs[0]),
        'case_count':len(cases),'case_counts_by_operation':{str(op):sum(case['operation']==op for case in cases) for op in range(5)},
        'consecutive_original_steps':64,'fresh_process_runs':3,'reverse_repeat_cases':len(cases),'all_body_canaries_unchanged':True,
        'expected_arithmetic_calculated_in_python':False,
        'host_adaptations':['Reviewed original32bit cdecl saved registers/stack arguments expanded to64bit host widths; pointers constrained low32bit.',
            'F585 original8byte local reservation expanded to16bytes for its two64bit epilogue pops; original4byte scratch arithmetic offsets unchanged.',
            'F611 local decrement-table address uses RBX rather than EBX as a64bit host stack index; source shift value2..9 is unchanged.',
            'Original indirect function-pointer slots use host8byte pointers; mathematical tables and raw338byte fields retain original widths.',
            'Exact DOS abs sign/INT_MIN semantics retained in a minimal host ABI wrapper.'],
        'scope':'Whole originalF584/F585/F609/F611 plus actualF1520/F1519/F1552 normalization and original math helpers; independent full DOS instruction equality before reviewed host ABI adaptation. Explicit raw angular step only; no automatic F1019/F1041 player scheduling, universal angular/linear order, full frame bank, fuel/time/collision/AI integration or Androidx86 execution claim.',
        'cases':cases}
    output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(report,indent=2)+'\n')
    (proof/'angular-native.s').write_text(native)
    print(json.dumps({'case_count':len(cases),'output':str(output),'sha256':sha(output.read_bytes()),'scope':report['scope']},indent=2))

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'))
    parser.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--proof-dir',type=Path,default=PROOF)
    parser.add_argument('--output',type=Path,default=FIXTURE)
    parser.add_argument('--refresh-original-proof',action='store_true')
    args=parser.parse_args()
    if args.refresh_original_proof or not (args.proof_dir/'instruction-proof.json').is_file():prepare_proof(args.asm,args.data,args.exe,args.proof_dir)
    generate(args.proof_dir,args.output)

if __name__=='__main__':main()
