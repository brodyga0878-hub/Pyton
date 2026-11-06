#!/usr/bin/env python3
"""Bounded native witnesses of original F878/F897 zero-radius nontermination.

Runs actual original full F878 with the four real F860 headers. An observing
hook at F897's loop boundary captures65 states, then exits the source call
without claiming normal return. Exactly64 original loop bodies execute.
"""
from __future__ import annotations
import argparse,hashlib,importlib.util,json,re,struct,subprocess,tempfile
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
IDS=[1919437698,44586598,44578542,111736477]
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
BANK=128*68
META=64
TRACE=65*24
OUTPUT=BANK+META+TRACE+16
GUARD=0x5a45524f4f524249
def sha(raw):return hashlib.sha256(raw).hexdigest()
def module(path,name):
    spec=importlib.util.spec_from_file_location(name,path);result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
def assembly(source,exe,data_source):
    full=module(PROJECT/'tools/rebuild_source_system_native.py','zero_orbit_actual_system')
    data=full.metadata_constants(data_source,exe)
    text,metadata=full.full_library_assembly(source,exe,data_source,data)
    marker='JUMP_003779:\nmovzx eax,si\nadd edi,eax\ncmp edi,0x10000'
    if text.count(marker)!=1:raise ValueError('Unexpected original F897 loop boundary')
    observer=f'''JUMP_003779:
pushfq
cmp WORD PTR [rbp+48],0
jne zero_unobserved
cmp DWORD PTR [zero_boundaries],0
jne zero_capture
mov r10d,DWORD PTR [rbp+24]
mov DWORD PTR [zero_index_pointer],r10d
mov r11d,DWORD PTR [r10]
mov DWORD PTR [zero_meta+44],r11d
mov r11d,DWORD PTR [rbp+48]
mov DWORD PTR [zero_meta+52],r11d
mov r11d,DWORD PTR [rbp+40]
mov DWORD PTR [zero_meta+56],r11d
mov r11d,DWORD PTR [rbp+32]
mov DWORD PTR [zero_meta+60],r11d
push rsi
push rdi
push rcx
mov esi,OFFSET FLAT:zero_bank
mov edi,OFFSET FLAT:zero_first_bank
mov ecx,{BANK}
rep movsb
pop rcx
pop rdi
pop rsi
zero_capture:
mov r10d,DWORD PTR [zero_boundaries]
imul r10d,r10d,24
add r10d,OFFSET FLAT:zero_trace
mov r11d,esi
and r11d,65535
mov DWORD PTR [r10],r11d
mov DWORD PTR [r10+4],edi
mov r11d,DWORD PTR [zero_index_pointer]
mov r11d,DWORD PTR [r11]
mov DWORD PTR [r10+8],r11d
mov DWORD PTR [r10+12],ebx
mov r11d,DWORD PTR [DATA_008843]
mov DWORD PTR [r10+16],r11d
mov r11d,DWORD PTR [DATA_008844]
mov DWORD PTR [r10+20],r11d
inc DWORD PTR [zero_boundaries]
cmp DWORD PTR [zero_boundaries],65
je zero_emit
zero_unobserved:
popfq
movzx eax,si
add edi,eax
cmp edi,0x10000'''
    text=text.replace(marker,observer)
    start=text.index('FUNC_000894:');end=text.index('\nFUNC_',start+1)
    rng=text[start:end]
    if rng.count('\nret')!=1:raise ValueError('Unexpected original F894 return')
    rng=rng.replace('\nret','''
pushfq
cmp DWORD PTR [zero_meta+4],0
jne zero_rng_done
mov DWORD PTR [zero_meta+4],1
mov DWORD PTR [zero_meta+8],eax
mov r10d,DWORD PTR [DATA_008844]
mov DWORD PTR [zero_meta+12],r10d
zero_rng_done:
popfq
ret''')
    text=text[:start]+rng+text[end:]
    text+=f'''
.section .text
.global _start
_start:
mov esp,OFFSET FLAT:zero_stack_end
zero_next:
mov esp,OFFSET FLAT:zero_stack_end
xor r8d,r8d
zero_read:
xor eax,eax
xor edi,edi
mov esi,OFFSET FLAT:zero_input
add rsi,r8
mov edx,84
sub edx,r8d
syscall
test eax,eax
jle zero_finished
add r8d,eax
cmp r8d,84
jne zero_read
cld
mov edi,OFFSET FLAT:zero_bank
mov ecx,{BANK}
xor eax,eax
rep stosb
mov edi,OFFSET FLAT:zero_output
mov ecx,{OUTPUT}
rep stosb
mov DWORD PTR [zero_boundaries],0
mov rax,{GUARD}
mov QWORD PTR [zero_before],rax
mov QWORD PTR [zero_after],rax
push OFFSET FLAT:zero_input
push OFFSET FLAT:zero_bank
call FUNC_000878
mov edi,95
mov eax,60
syscall
zero_emit:
mov esp,OFFSET FLAT:zero_stack_end
cld
mov esi,OFFSET FLAT:zero_bank
mov edi,OFFSET FLAT:zero_first_bank
mov ecx,{BANK}
repe cmpsb
jne zero_failed
mov rax,{GUARD}
cmp QWORD PTR [zero_before],rax
jne zero_failed
cmp QWORD PTR [zero_after],rax
jne zero_failed
mov QWORD PTR [zero_output+{OUTPUT-16}],rax
mov QWORD PTR [zero_output+{OUTPUT-8}],rax
mov eax,DWORD PTR [zero_boundaries]
mov DWORD PTR [zero_meta],eax
mov eax,DWORD PTR [DATA_008843]
mov DWORD PTR [zero_meta+16],eax
mov eax,DWORD PTR [DATA_008844]
mov DWORD PTR [zero_meta+20],eax
movzx eax,BYTE PTR [DATA_008847]
mov DWORD PTR [zero_meta+24],eax
movzx eax,BYTE PTR [DATA_008848]
mov DWORD PTR [zero_meta+28],eax
movzx eax,BYTE PTR [DATA_008855]
mov DWORD PTR [zero_meta+32],eax
movzx eax,BYTE PTR [DATA_008856]
mov DWORD PTR [zero_meta+36],eax
mov eax,DWORD PTR [DATA_008846]
mov DWORD PTR [zero_meta+40],eax
mov eax,DWORD PTR [zero_index_pointer]
mov eax,DWORD PTR [rax]
mov DWORD PTR [zero_meta+48],eax
mov esi,OFFSET FLAT:zero_bank
mov edi,OFFSET FLAT:zero_output
mov ecx,{BANK}
rep movsb
mov eax,1
mov edi,1
mov esi,OFFSET FLAT:zero_output
mov edx,{OUTPUT}
syscall
jmp zero_next
zero_failed:
mov edi,94
mov eax,60
syscall
zero_finished:
xor edi,edi
mov eax,60
syscall
.section .bss
zero_input: .zero 84
zero_boundaries: .zero 4
zero_index_pointer: .zero 4
zero_before: .zero 8
zero_bank: .zero {BANK}
zero_after: .zero 8
zero_first_bank: .zero {BANK}
zero_output: .zero {OUTPUT}
.set zero_meta,zero_output+{BANK}
.set zero_trace,zero_output+{BANK+META}
zero_stack: .zero 16777216
zero_stack_end:
.section .note.GNU-stack,"",@progbits
'''
    return text,metadata
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/zero_orbit_native.json')
    args=parser.parse_args();exe=args.exe.read_bytes();source_raw=args.source.read_bytes()
    if sha(exe)!=EXE_SHA or sha(source_raw)!=ASM_SHA:raise ValueError('Unexpected source revision')
    headers_path=PROJECT/'tests/fixtures/source_system_definition_native.json';headers=json.loads(headers_path.read_text())
    rows=[];packets=[]
    for id in IDS:
        row=next(row for row in headers['cases']if row['id']==id)
        if row['return_s32']!=0:raise ValueError('Invalid original witness header')
        parameters=bytes.fromhex(row['params_hex'])[:20]+bytes.fromhex(row['name_hex']).ljust(64,b'\0')
        rows.append({'system_id':id,'header_hex':parameters.hex(),'system_name_bytes_hex':row['name_hex']})
        packets.append(parameters)
    text,metadata=assembly(args.source.read_text(),exe,args.source.with_name('ffedat.asm').read_text())
    with tempfile.TemporaryDirectory(prefix='original-zero-orbit-prefix-')as directory:
        work=Path(directory);(work/'native.s').write_text(text)
        subprocess.run(['as','--64','-o',str(work/'native.o'),str(work/'native.s')],check=True)
        subprocess.run(['ld','-o',str(work/'native'),str(work/'native.o')],check=True)
        outputs=[subprocess.run([str(work/'native')],input=b''.join(packets),capture_output=True,check=True,timeout=20).stdout for _ in range(3)]
        if len(set(outputs))!=1 or len(outputs[0])!=OUTPUT*4:raise ValueError('Unstable bounded source witness')
        reverse=subprocess.run([str(work/'native')],input=b''.join(reversed(packets)),capture_output=True,check=True,timeout=20).stdout
        if reverse!=b''.join(outputs[0][i*OUTPUT:(i+1)*OUTPUT]for i in reversed(range(4))):raise ValueError('Bounded native state leaked between cases')
    names=['boundary_count','first_rng_seen','first_rng_a','first_rng_b','final_rng_a','final_rng_b','body_count_byte','star_count_byte','port_count_byte','orbital_count_byte','ordinal_counter','first_loop_index','final_loop_index','start_radius','random_value','parent_index']
    for i,row in enumerate(rows):
        output=outputs[0][i*OUTPUT:(i+1)*OUTPUT]
        if struct.unpack_from('<2Q',output,OUTPUT-16)!=(GUARD,GUARD):raise ValueError('Native bank guard failed')
        meta=dict(zip(names,struct.unpack_from('<16I',output,BANK)))
        trace=[dict(zip(['radius_u16','spacing_u32','index','candidate_mass_u32','seed_a','seed_b'],struct.unpack_from('<6I',output,BANK+META+j*24)))for j in range(65)]
        if meta['boundary_count']!=65 or (meta['start_radius']&65535)!=0 or meta['first_loop_index']!=meta['final_loop_index']:raise ValueError('Witness escaped the original zero-radius domain '+str(meta))
        if any(t['radius_u16']or t['spacing_u32']or t['index']!=meta['first_loop_index']for t in trace) or any(t['candidate_mass_u32']for t in trace[1:]):raise ValueError('Original zero-radius recurrence did not remain stationary')
        row['expected']={'metadata':meta,'loop_boundaries':trace,'completed_source_iterations':64,'bank_unchanged_during_f897':True,'bank_sha256':sha(output[:BANK]),'records128_hex':[output[j*68:(j+1)*68].hex()for j in range(128)]}
    fixture={'schema':1,'source_variant':'actual-f878-f897-zero-radius-bounded-witness-v1','source_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'source_library_metadata':metadata,'input_header_fixture_sha256':sha(headers_path.read_bytes()),'adapted_observed_assembly_sha256':sha(text.encode()),'native_output_sha256':sha(outputs[0]),'case_count':4,'fresh_process_runs':3,'reverse_repeat_count':4,'bank_canaries_unchanged':True,'bank_unchanged_during_f897':True,'observation':'F894 return hook preservesflags; F897 loop-boundary hook preserves source registers/flags, captures65boundary states then exits the source call after64complete original loop bodies. No normal source completion is claimed.','nontermination_argument':'At radius0 each source iteration computes spacing0 and candidate_mass0, appends no records and adds0 to radius; the only loop-exit comparison remains0<65536 regardless of future RNG words.','cases':rows}
    args.output.write_text(json.dumps(fixture,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'case_count':4,'completed_source_iterations_each':64,'fixture_sha256':sha(args.output.read_bytes()),'witnesses':[row['expected']['metadata']for row in rows]}))
if __name__=='__main__':main()
