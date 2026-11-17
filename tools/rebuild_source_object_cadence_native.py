#!/usr/bin/env python3
"""Execute whole DOS F149/F144 object callback cadence with observed handlers.

The published DOS instruction bodies are reassembled and compared before a
reviewed64-bit stack/pointer adapter runs them. F144 callback bodies are explicit
recorders with optional declared raw-byte effects, never original AI/physics.
Default replay needs no private EXE; --refresh-original-proof captures it again.
"""
from __future__ import annotations
import argparse, hashlib, importlib.util, json, random, re, struct, subprocess, tempfile
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
PROOF=PROJECT/'validation/player-dispatch-2026-11-17/cadence-native-proof'
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
OBJECT=338;BANK=0x74+115*OBJECT;MAX_MUTATIONS=16;HEADER=32
INPUT=HEADER+MAX_MUTATIONS*8+BANK
TRACE_BYTES=114*20
OUTPUT=64+BANK+TRACE_BYTES*2+64
SOURCE_NUMBERS=[149,144]
ORIGINAL_CALLBACK_TYPES=[1,3,5,7,11,17]

def sha(raw):return hashlib.sha256(raw).hexdigest()
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

def capture(args):
    N=load('cadence_original_proof',PROJECT/'tools/rebuild_source_natural_contact_native.py')
    raw=args.source.read_bytes();exe=args.exe.read_bytes()
    if sha(raw)!=ASM_SHA or sha(exe)!=EXE_SHA:raise ValueError('Unreviewed original source or DOS EXE')
    source=raw.decode();a=source.index('; FIX: Laser invulnerability');b=source.index('\n\t\tpop edi',a)
    source=source[:a]+source[b:]
    import inspect
    namespace=dict(N.__dict__)
    function=inspect.getsource(N.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_000149',0x41946c)")
    function=function.replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
    exec(function,namespace)
    bodies,records,dis,_,aliases=namespace['proof'](source,args.data.read_text(),exe,args.exe,SOURCE_NUMBERS)
    selected='\n'.join(bodies[n] for n in SOURCE_NUMBERS)
    image=N.G.Image(exe);table=[]
    for index in range(21):
        at=image.offset(aliases['DATA_004892']+index*4,4);address=struct.unpack_from('<I',exe,at)[0]
        entry_at=image.offset(address+20,4)
        table.append({'type_u8':index,'table_pointer_u32':address,'table_word_offset':at,
                      'event5_address_u32':struct.unpack_from('<I',exe,entry_at)[0],
                      'event5_word_offset':entry_at})
    if [r['type_u8'] for r in table if r['event5_address_u32']]!=ORIGINAL_CALLBACK_TYPES:raise ValueError('Original event5 registry differs')
    kept={k:v for k,v in aliases.items() if k in ('FUNC_000149','FUNC_000144','DATA_004892','DATA_007758')}
    meta={'schema':'starfrontier-dos-object-cadence-instruction-proof-v1','source_executable_sha256':EXE_SHA,
          'source_assembly_sha256':ASM_SHA,'aliases':kept,'whole_procedure_instruction_equality':records,
          'source_procedures_sha256':sha(selected.encode()),'original_event5_registry':table,
          'original_event5_callback_types':ORIGINAL_CALLBACK_TYPES,
          'source_procedure_sha256':{str(n):sha(N.G.block(selected,n).encode()) for n in SOURCE_NUMBERS},
          'scope':'Whole original DOS F149 and F144. The JJFFE laser-invulnerability addition is removed before DOS instruction proof. Native callbacks are request observers with optional declared byte effects, not original object handlers.'}
    PROOF.mkdir(parents=True,exist_ok=True)
    for n,t in dis.items():(PROOF/f'dos-F{n}.txt').write_text(t)
    (PROOF/'source-procedures.asm').write_text(selected)
    (PROOF/'instruction-proof.json').write_text(json.dumps(meta,indent=2)+'\n')

def verify_source(meta,source):
    N=load('cadence_portable_proof',PROJECT/'tools/rebuild_source_natural_contact_native.py')
    if meta['source_executable_sha256']!=EXE_SHA or sha(source.encode())!=meta['source_procedures_sha256']:raise ValueError('Captured DOS cadence source changed')
    for n in SOURCE_NUMBERS:
        record=meta['whole_procedure_instruction_equality'][str(n)]
        body=N.G.block(source,n)
        rows=N.C.J.instructions(N.C.compile32(body,meta['aliases'],f'FUNC_{n:06d}',record['virtual_address']))
        observed=N.C.J.instructions((PROOF/f'dos-F{n}.txt').read_text())
        if N.canonical(rows)!=N.canonical(observed) or not record['all_instructions_equal']:raise ValueError('Archived DOS cadence instructions differ '+str(n))
        if sha(body.encode())!=meta['source_procedure_sha256'][str(n)]:raise ValueError('Archived procedure bytes differ '+str(n))

def assembly(source):
    abi=load('cadence_host_abi',PROJECT/'recovered-history/ground_harness/tools/native_reference.py')
    selected=source+'\nFUNC_999999:\nret\n'
    lines,_=abi.procedures(selected,SOURCE_NUMBERS);body='\n'.join(lines)
    body=body.replace('FUNC_000144:','DOS_000144:')
    old='mov eax,[eax*4+DATA_004892]';new='mov rax,QWORD PTR [rax*8+DATA_004892]'
    if body.count(old)!=1:raise ValueError('Source F144 selector-table pointer instruction changed')
    body=body.replace(old,new)
    old='mov eax,[eax+edx*4]';new='mov rax,QWORD PTR [rax+rdx*8]'
    if body.count(old)!=1:raise ValueError('Source F144 event-table pointer instruction changed')
    body=body.replace(old,new)
    saves=['rax','rbx','rcx','rdx','rsi','rdi','rbp','r8','r9','r10','r11']
    save=' pushfq\n'+''.join(' push '+r+'\n' for r in saves)
    restore=''.join(' pop '+r+'\n' for r in reversed(saves))+' popfq\n'
    wrapper=WRAPPER.replace('@SAVE@',save).replace('@RESTORE@',restore)
    wrapper=wrapper.replace('@INPUT@',str(INPUT)).replace('@OUTPUT@',str(OUTPUT)).replace('@BANK@',str(BANK)).replace('@BANK_INPUT@',str(HEADER+MAX_MUTATIONS*8))
    wrapper=wrapper.replace('@TRACE@',str(TRACE_BYTES)).replace('@ATTEMPTS@',str(64+BANK)).replace('@CALLBACKS@',str(64+BANK+TRACE_BYTES))
    entries='\n'.join(f'callback_type_{n}:\n mov r10d,{n}\n jmp callback_common' for n in range(21))
    init=''
    for n in range(21):
        init+=f''' mov QWORD PTR [DATA_004892+{n*8}],OFFSET FLAT:callback_tables+{n*48}
 mov QWORD PTR [callback_tables+{n*48+40}],0
 test DWORD PTR [input+20],{1<<n}
 jz .Ltable_{n}_ready
 mov QWORD PTR [callback_tables+{n*48+40}],OFFSET FLAT:callback_type_{n}
.Ltable_{n}_ready:
'''
    wrapper=wrapper.replace('@ENTRIES@',entries).replace('@INIT_TABLES@',init)
    return '.intel_syntax noprefix\n.code64\n.section .text\n.global _start\n'+body+'\n'+wrapper

def make_body(rng,index,timer=0,kind=1,reload=0):
    body=bytearray(rng.randbytes(OBJECT));body[0x86]=index;body[0x87]=kind;body[0x8a]=reload;body[0x8b]=timer
    return body.hex()
def base_row(name,objects,flags=None,callbacks=None):
    flagbytes=bytearray(115)
    for key in objects:flagbytes[int(key)]=1
    if flags:
        for key,value in flags.items():flagbytes[int(key)]=value
    return {'name':name,'operation':'cadence','clock_low_u32':0x89abcdef,'clock_day_u32':0xffffffff,
            'flags_hex':flagbytes.hex(),'objects_by_index':objects,
            'callback_types_u8':list(ORIGINAL_CALLBACK_TYPES if callbacks is None else callbacks),'mutations':[],
            'dispatch_object_index_u8':0,'dispatch_type_u8':0}
def cases():
    rng=random.Random(0x149144);rows=[base_row('empty-bank',{})]
    for index in (1,2,57,113,114):
        for timer in (0,1,2,127,128,254,255):
            kind=[0,1,3,17,20][index%5]
            rows.append(base_row(f'index-{index}-timer-{timer}',{str(index):make_body(rng,index,timer,kind,(timer+17)&255)}))
    for flag in (0,1,2,3,4,16,128,254,255):
        for timer in (0,1,255):
            kind=255 if not(flag&1) or timer else 1
            rows.append(base_row(f'flag-{flag}-timer-{timer}',{'114':make_body(rng,114,timer,kind,127)},{114:flag},list(range(21))))
    indices=[1,2,7,31,57,88,110,113,114]
    rows.append(base_row('descending-entire-ready-bank',{str(i):make_body(rng,i,0,i%21,i&255) for i in indices},callbacks=list(range(21))))
    rows.append(base_row('same-ready-bank-no-handlers',{str(i):make_body(rng,i,0,i%21,i&255) for i in indices},callbacks=[]))
    for timer in (0,1,255):
        row=base_row(f'earlier-callback-replaces-later-timer-{timer}',{'1':make_body(rng,1,0,1,4),'114':make_body(rng,114,0,1,7)},callbacks=[1])
        row['mutations']=[{'trigger_index_u8':114,'target_index_u8':1,'offset_u16':0x8b,'value_u8':timer},
                          {'trigger_index_u8':1,'target_index_u8':114,'offset_u16':0x8b,'value_u8':201}]
        rows.append(row)
    for kind in range(21):
        row=base_row(f'direct-event5-selector-{kind}',{'57':make_body(rng,57,0,20,9)})
        row.update(operation='dispatch',dispatch_object_index_u8=57,dispatch_type_u8=kind)
        rows.append(row)
    for number in range(144):
        selected=sorted(rng.sample(range(1,115),rng.randrange(1,18)))
        objects={str(i):make_body(rng,i,rng.choice((0,0,1,2,127,255)),rng.randrange(21),rng.randrange(256)) for i in selected}
        flags={i:rng.choice((0,1,1,3,16,255)) for i in selected}
        row=base_row(f'seeded-sparse-{number:03d}',objects,flags,[i for i in range(21) if rng.getrandbits(1)])
        row['clock_low_u32']=rng.getrandbits(32);row['clock_day_u32']=rng.getrandbits(32)
        for _ in range(rng.randrange(5)):
            off=rng.choice((0x8a,0x8b,0x14d,0x148,0x87))
            row['mutations'].append({'trigger_index_u8':rng.choice(selected),'target_index_u8':rng.choice(selected),'offset_u16':off,'value_u8':rng.randrange(21) if off==0x87 else rng.randrange(256)})
        rows.append(row)
    return rows

def packet(row):
    mutations=row['mutations'];mask=sum(1<<i for i in row['callback_types_u8'])
    header=struct.pack('<8I',0 if row['operation']=='cadence' else 1,row['clock_low_u32'],row['clock_day_u32'],row['dispatch_object_index_u8'],row['dispatch_type_u8'],mask,0,len(mutations))
    effects=bytearray(MAX_MUTATIONS*8)
    for i,m in enumerate(mutations):struct.pack_into('<BBHB3x',effects,i*8,m['trigger_index_u8'],m['target_index_u8'],m['offset_u16'],m['value_u8'])
    bank=bytearray([0xa5])*BANK;bank[:115]=bytes.fromhex(row['flags_hex'])
    for key,value in row['objects_by_index'].items():
        index=int(key);at=0x74+index*OBJECT;bank[at:at+OBJECT]=bytes.fromhex(value)
    return header+effects+bank
def trace(raw,count,offset):
    return [dict(zip(('object_index_u8','type_u8','event_u32','clock_low_u32','clock_day_u32'),struct.unpack_from('<5I',raw,offset+i*20))) for i in range(count)]
def decode(row,raw):
    header=struct.unpack_from('<16I',raw)
    if header[0]!=0x14914444 or header[5]!=0 or raw[-64:]!=bytes([0xa5])*64:raise ValueError('Cadence native context/canary failed')
    if header[2]>114 or header[3]>114 or header[4]>MAX_MUTATIONS*114:raise ValueError('Cadence trace bound exceeded')
    result_bank=raw[64:64+BANK];original=bytearray(packet(row)[HEADER+MAX_MUTATIONS*8:]);expected={}
    for key in row['objects_by_index']:
        at=0x74+int(key)*OBJECT;expected[key]=result_bank[at:at+OBJECT].hex();original[at:at+OBJECT]=result_bank[at:at+OBJECT]
    if bytes(original)!=result_bank or row['flags_hex']!=result_bank[:115].hex():raise ValueError('Cadence changed an unprovided record or flags')
    return {'expected_objects_by_index':expected,'expected_flags_hex':result_bank[:115].hex(),
            'expected_dispatch_attempts':trace(raw,header[2],64+BANK),
            'expected_callbacks':trace(raw,header[3],64+BANK+TRACE_BYTES),
            'expected_mutations_applied':header[4],'expected_owner_global_bound_to_bank':bool(header[6])}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'))
    parser.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_object_cadence_native.json')
    parser.add_argument('--refresh-original-proof',action='store_true');args=parser.parse_args()
    if args.refresh_original_proof:capture(args)
    meta=json.loads((PROOF/'instruction-proof.json').read_text());source=(PROOF/'source-procedures.asm').read_bytes().decode()
    verify_source(meta,source);native=assembly(source);rows=cases()
    with tempfile.TemporaryDirectory(prefix='source-cadence-native-') as directory:
        p=Path(directory);(p/'native.s').write_text(native)
        subprocess.run(['as','--64',str(p/'native.s'),'-o',str(p/'native.o')],check=True)
        subprocess.run(['ld',str(p/'native.o'),'-o',str(p/'native')],check=True)
        def run(items):
            done=subprocess.run([str(p/'native')],input=b''.join(packet(r) for r in items),capture_output=True,timeout=60,check=True)
            if done.stderr or len(done.stdout)!=len(items)*OUTPUT:raise ValueError('Truncated/diagnostic cadence native output')
            return done.stdout
        seed=base_row('sequence-seed',{'1':make_body(random.Random(1),1,0,1,0),'8':make_body(random.Random(8),8,0,1,1),'114':make_body(random.Random(114),114,0,1,255)},callbacks=[1])
        for n in range(32):
            row=json.loads(json.dumps(seed));row['name']=f'consecutive-native-{n:02d}';row['sequence_step']=n
            observed=decode(row,run([row]));rows.append(row)
            seed=row.copy();seed['objects_by_index']=observed['expected_objects_by_index']
        outputs=[run(rows) for _ in range(3)]
        if len(set(outputs))!=1:raise ValueError('Cadence output differs across fresh processes')
        reverse=run(list(reversed(rows)))
        if reverse!=b''.join(outputs[0][n*OUTPUT:(n+1)*OUTPUT] for n in reversed(range(len(rows)))):raise ValueError('Cadence cross-case state leaked')
    for i,row in enumerate(rows):row.update(decode(row,outputs[0][i*OUTPUT:(i+1)*OUTPUT]))
    fixture={'schema':'starfrontier-source-object-cadence-native-v1','profile':'dos-firstenc-object-cadence-v1','source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,
             'instruction_proof_sha256':sha((PROOF/'instruction-proof.json').read_bytes()),'source_procedures_sha256':sha(source.encode()),'host_assembly_sha256':sha(native.encode()),
             'input_packets_sha256':sha(b''.join(packet(r) for r in rows)),'native_output_sha256':sha(outputs[0]),'case_count':len(rows),'fresh_process_runs':3,'reverse_case_count':len(rows),
             'consecutive_original_steps':32,'canaries_and_unprovided_bank_records_unchanged':True,'expected_arithmetic_calculated_in_Python':False,
             'original_event5_callback_types':ORIGINAL_CALLBACK_TYPES,'host_adaptations':['Reviewed cdecl stack slots and saved registers widened64bit; low-address bank/stack preserve32bit raw context pointers.','F144 two pointer-table scales4→8 and pointer loads widened only for host callback addresses.','F144 boundary observer preserves registers/flags, then tail-jumps into actual source F144.','F144 handler bodies are explicit event/context recorders plus declared raw-byte mutation effects; no original AI/physics handlers or JJFFE laser pass.'],
             'scope':'Whole DOS F149 cadence and F144 event5 table dispatch. Flagsbit1, source descending indexed order, wrapping byte8B and reload8A use actual original instructions. Explicit callback registry presence and declared raw-byte observer effects exercise aliasing. No original handler bodies, full F149 callback graph, live Main or Android execution proof.',
             'cases':rows}
    fixture_raw=(json.dumps(fixture,indent=2)+'\n').encode()
    canonical_fixture=PROJECT/'tests/fixtures/source_object_cadence_native.json'
    replay_byte_exact=canonical_fixture.exists() and canonical_fixture.read_bytes()==fixture_raw
    if canonical_fixture.exists() and not args.refresh_original_proof and not replay_byte_exact:
        raise ValueError('Native replay differs from the pinned published fixture')
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_bytes(fixture_raw)
    (PROOF/'cadence-native.s').write_text(native)
    report={'schema':'starfrontier-source-object-cadence-native-validation-v1','case_count':len(rows),'fixture_sha256':sha(args.output.read_bytes()),'native_output_sha256':fixture['native_output_sha256'],'fresh_process_runs':3,'reverse_cases':len(rows),'consecutive_original_steps':32,'all_guards_and_unprovided_records_unchanged':True,'fixture_byte_exact_replay':replay_byte_exact,'F144_callback_effects_are_explicit_observers':True}
    (PROOF/'validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))

WRAPPER=r'''
FUNC_000144:
@SAVE@
 mov r10d,DWORD PTR [rsp+104]
 mov r11d,DWORD PTR [rsp+112]
 mov edx,DWORD PTR [rsp+120]
 call append_attempt
@RESTORE@
 jmp DOS_000144
@ENTRIES@
callback_common:
@SAVE@
 mov r11d,5
 mov edx,DWORD PTR [rsp+104]
 call append_callback
 mov esi,OFFSET FLAT:input+32
 mov ecx,DWORD PTR [input+28]
.Lmutation_loop:
 test ecx,ecx
 jz .Lmutations_done
 movzx eax,BYTE PTR [esi]
 cmp eax,DWORD PTR [last_callback_index]
 jne .Lmutation_next
 movzx eax,BYTE PTR [esi+1]
 imul eax,338
 add eax,OFFSET FLAT:bank+0x74
 movzx edx,WORD PTR [esi+2]
 mov bl,BYTE PTR [esi+4]
 mov BYTE PTR [eax+edx],bl
 inc DWORD PTR [output+16]
.Lmutation_next:
 add esi,8
 dec ecx
 jmp .Lmutation_loop
.Lmutations_done:
@RESTORE@
 ret
append_attempt:
 mov r9d,OFFSET FLAT:output+@ATTEMPTS@
 mov edi,OFFSET FLAT:output+8
 jmp append_trace
append_callback:
 mov r9d,OFFSET FLAT:output+@CALLBACKS@
 mov edi,OFFSET FLAT:output+12
append_trace:
 mov r8d,edx
 mov eax,DWORD PTR [r8+8]
 sub eax,OFFSET FLAT:bank+0x74
 xor edx,edx
 mov ecx,338
 div ecx
 test edx,edx
 jnz failed
 cmp eax,1
 jb failed
 cmp eax,114
 ja failed
 mov DWORD PTR [last_callback_index],eax
 mov ecx,DWORD PTR [edi]
 cmp ecx,114
 jae failed
 inc DWORD PTR [edi]
 imul ecx,20
 add r9d,ecx
 mov DWORD PTR [r9],eax
 mov DWORD PTR [r9+4],r10d
 mov DWORD PTR [r9+8],r11d
 mov eax,DWORD PTR [r8]
 mov DWORD PTR [r9+12],eax
 mov eax,DWORD PTR [r8+4]
 mov DWORD PTR [r9+16],eax
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
 mov edx,@INPUT@
 sub edx,r8d
 syscall
 test eax,eax
 js failed
 jnz got_input
 test r8d,r8d
 jnz failed
 mov eax,60
 xor edi,edi
 syscall
got_input:
 add r8d,eax
 cmp r8d,@INPUT@
 jb read_more
 cld
 mov edi,OFFSET FLAT:output
 xor eax,eax
 mov ecx,@OUTPUT@
 rep stosb
 mov DWORD PTR [output],0x14914444
 mov eax,DWORD PTR [input]
 mov DWORD PTR [output+4],eax
 mov edi,OFFSET FLAT:bank_before
 mov eax,0xa5
 mov ecx,@BANK@+32
 rep stosb
 mov edi,OFFSET FLAT:output+@OUTPUT@-64
 mov ecx,64
 rep stosb
 mov esi,OFFSET FLAT:input+@BANK_INPUT@
 mov edi,OFFSET FLAT:bank
 mov ecx,@BANK@
 rep movsb
 mov edi,OFFSET FLAT:callback_tables
 xor eax,eax
 mov ecx,1008
 rep stosb
@INIT_TABLES@
 mov DWORD PTR [DATA_007758],0x13572468
 cmp DWORD PTR [input],0
 jne direct_dispatch
 mov eax,DWORD PTR [input+8]
 push rax
 mov eax,DWORD PTR [input+4]
 push rax
 push OFFSET FLAT:bank
 call FUNC_000149
 add rsp,24
 cmp DWORD PTR [DATA_007758],OFFSET FLAT:bank
 jne failed
 mov DWORD PTR [output+24],1
 jmp capture
direct_dispatch:
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [direct_context],eax
 mov eax,DWORD PTR [input+8]
 mov DWORD PTR [direct_context+4],eax
 mov eax,DWORD PTR [input+12]
 imul eax,338
 add eax,OFFSET FLAT:bank+0x74
 mov DWORD PTR [direct_context+8],eax
 push OFFSET FLAT:direct_context
 push 5
 mov eax,DWORD PTR [input+16]
 push rax
 call FUNC_000144
 add rsp,24
 cmp DWORD PTR [DATA_007758],0x13572468
 jne failed
capture:
 mov esi,OFFSET FLAT:bank_before
 mov ecx,16
.Lguard_before:
 cmp BYTE PTR [esi],0xa5
 jne failed
 inc esi
 loop .Lguard_before
 mov esi,OFFSET FLAT:bank_after
 mov ecx,16
.Lguard_after:
 cmp BYTE PTR [esi],0xa5
 jne failed
 inc esi
 loop .Lguard_after
 mov esi,OFFSET FLAT:bank
 mov edi,OFFSET FLAT:output+64
 mov ecx,@BANK@
 rep movsb
 xor r8d,r8d
write_more:
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 add rsi,r8
 mov edx,@OUTPUT@
 sub edx,r8d
 syscall
 test eax,eax
 jle failed
 add r8d,eax
 cmp r8d,@OUTPUT@
 jb write_more
 jmp next_case
failed:
 mov eax,60
 mov edi,93
 syscall
.section .bss
.balign 16
input: .zero @INPUT@
bank_before: .zero 16
bank: .zero @BANK@
bank_after: .zero 16
output: .zero @OUTPUT@
DATA_004892: .zero 168
callback_tables: .zero 1008
DATA_007758: .zero 4
last_callback_index: .zero 4
direct_context: .zero 12
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
'''

if __name__=='__main__':main()
