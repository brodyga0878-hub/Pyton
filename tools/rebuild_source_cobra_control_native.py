#!/usr/bin/env python3
"""Execute original F601 using real Cobra38 thrust words from FIRSTENC.EXE.

The source kernel, not a controller implementation, produces every expected
object/velocity. F1533's six word assignments are explicitly reviewed input
preparation; F1533 itself is not executed by this narrow oracle.
"""
from __future__ import annotations
import argparse,hashlib,importlib.util,json,re,struct,subprocess,tempfile
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
SPEC_SHA='b0f77d55db624b023accc8542f6b990d95515ab3e4c23bdd4e1d6e30c4cf2656'
INPUT=342
OUTPUT=354
GUARD=0x434f425241333846

def sha(raw):return hashlib.sha256(raw).hexdigest()
def block(source,number):
    a=re.search(r'^FUNC_%06d(?:_[A-Za-z0-9_]+)?:'%number,source,re.M)
    b=re.search(r'^(?:FUNC_\d+(?:_[A-Za-z0-9_]+)?|_[A-Za-z0-9_]+):',source[a.end():],re.M)
    return source[a.start():a.end()+b.start() if b else len(source)]
def original_spec(raw):
    pe=struct.unpack_from('<I',raw,60)[0];base=struct.unpack_from('<I',raw,pe+52)[0]
    start=pe+24+struct.unpack_from('<H',raw,pe+20)[0]
    sections=[struct.unpack_from('<4I',raw,start+i*40+8)for i in range(struct.unpack_from('<H',raw,pe+6)[0])]
    def offset(pointer,length):
        for _,address,size,at in sections:
            delta=pointer-base-address
            if 0<=delta and delta+length<=size and at+delta+length<=len(raw):return at+delta
        raise ValueError('Unmapped original Cobra pointer')
    descriptor_at=offset(struct.unpack_from('<I',raw,0xba8fc+38*4)[0],68)
    spec_at=offset(struct.unpack_from('<I',raw,descriptor_at+56)[0],24)
    spec=raw[spec_at:spec_at+24]
    if sha(spec)!=SPEC_SHA:raise ValueError('Unexpected Cobra38 original specification')
    return spec,descriptor_at,spec_at
def assembly(source):
    path=PROJECT/'recovered-history/ground_harness/tools/native_reference.py'
    spec=importlib.util.spec_from_file_location('cobra_control_host_abi',path)
    adapter=importlib.util.module_from_spec(spec);spec.loader.exec_module(adapter)
    lines,_=adapter.procedures(block(source,601)+'\nFUNC_999999:\nret\n',[601])
    return '.intel_syntax noprefix\n.code64\n.section .text\n.global _start\n'+'\n'.join(lines)+f'''
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
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
 mov rax,{GUARD}
 mov QWORD PTR [before],rax
 mov QWORD PTR [after],rax
 mov esi,OFFSET FLAT:input
 mov edi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 mov eax,DWORD PTR [input+338]
 push rax
 push OFFSET FLAT:body
 call FUNC_000601
 add rsp,16
 mov rax,{GUARD}
 cmp QWORD PTR [before],rax
 jne failed
 cmp QWORD PTR [after],rax
 jne failed
 mov esi,OFFSET FLAT:body
 mov edi,OFFSET FLAT:output
 mov ecx,338
 rep movsb
 mov QWORD PTR [output+338],rax
 mov QWORD PTR [output+346],rax
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,{OUTPUT}
 syscall
 jmp next_case
failed:
 mov edi,94
 mov eax,60
 syscall
finished:
 xor edi,edi
 mov eax,60
 syscall
.section .bss
input: .zero {INPUT}
before: .zero 8
body: .zero 338
after: .zero 8
output: .zero {OUTPUT}
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
'''
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_cobra_control_native.json')
    args=parser.parse_args();exe=args.exe.read_bytes();source_raw=args.source.read_bytes()
    if sha(exe)!=EXE_SHA or sha(source_raw)!=ASM_SHA:raise ValueError('Unexpected source revision')
    source=args.source.read_text();spec,descriptor_at,spec_at=original_spec(exe)
    forward,reverse=struct.unpack_from('<hh',spec)
    axes=[('x_positive',0,-reverse),('x_negative',0,reverse),('y_positive',1,-reverse),('y_negative',1,reverse),('z_positive_main',2,forward),('z_negative_retro',2,reverse)]
    rows=[];packets=[]
    for ticks in [8,49700,49710]:
        for name,axis,raw in axes:
            body=bytearray(338);struct.pack_into('<9i',body,0,2147483647,0,0,0,2147483647,0,0,0,2147483647)
            struct.pack_into('<6h',body,0xbc,-reverse,reverse,-reverse,reverse,forward,reverse)
            struct.pack_into('<h',body,0xb6+axis*2,raw)
            struct.pack_into('<H',body,0xe4,struct.unpack_from('<H',spec,6)[0]*4)
            packets.append(bytes(body)+struct.pack('<I',ticks))
            rows.append({'axis':name,'axis_index':axis,'raw_thrust_s16':raw,'step_ticks':ticks,'initial_body_hex':body.hex()})
    text=assembly(source)
    with tempfile.TemporaryDirectory(prefix='actual-cobra-f601-')as directory:
        work=Path(directory);(work/'native.s').write_text(text)
        subprocess.run(['as','--64','-o',str(work/'native.o'),str(work/'native.s')],check=True)
        subprocess.run(['ld','-o',str(work/'native'),str(work/'native.o')],check=True)
        outputs=[subprocess.run([str(work/'native')],input=b''.join(packets),capture_output=True,check=True).stdout for _ in range(3)]
        if len(set(outputs))!=1 or len(outputs[0])!=OUTPUT*len(rows):raise ValueError('Unstable original F601 output')
        reverse_output=subprocess.run([str(work/'native')],input=b''.join(reversed(packets)),capture_output=True,check=True).stdout
        if reverse_output!=b''.join(outputs[0][i*OUTPUT:(i+1)*OUTPUT]for i in reversed(range(len(rows)))):raise ValueError('Source F601 native case order leaked state')
    velocity_unit=16785.0/172800.0;ticks_per_second=4294967296.0/86400.0
    changed_offsets=set(range(0x8c,0x98))|set(range(0xec,0xf2))
    for i,row in enumerate(rows):
        output=outputs[0][i*OUTPUT:(i+1)*OUTPUT]
        if struct.unpack_from('<2Q',output,338)!=(GUARD,GUARD):raise ValueError('Native object guard failed')
        original=bytes.fromhex(row['initial_body_hex'])
        if any(original[k]!=output[k]for k in range(338)if k not in changed_offsets):raise ValueError('Unexpected source F601 object write')
        velocity=list(struct.unpack_from('<3i',output,0x8c));fractions=list(struct.unpack_from('<3H',output,0xec))
        combined=[velocity[k]*65536+fractions[k]for k in range(3)]
        duration=row['step_ticks']/ticks_per_second
        row['expected']={'body_hex':output[:338].hex(),'velocity_s32':velocity,'fraction_u16':fractions,'velocity_q16':combined,'acceleration_mps2':[value/65536.0*velocity_unit/duration for value in combined]}
    fixture={'schema':1,'source_variant':'actual-cobra38-f601-nominal-control-v1','source_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'source_f601_sha256':sha(block(source,601).encode()),'reviewed_f1533_initializer_sha256':sha(block(source,1533).encode()),'initializer_scope':'Inputs follow reviewed original F1533 word assignments; the native instruction oracle executes F601 only.','descriptor_executable_offset':descriptor_at,'spec_executable_offset':spec_at,'spec_hex':spec.hex(),'spec_sha256':SPEC_SHA,'source_mass_tonnes':struct.unpack_from('<H',spec,6)[0],'source_internal_capacity_tonnes':struct.unpack_from('<H',spec,8)[0],'adapted_assembly_sha256':sha(text.encode()),'input_packets_sha256':sha(b''.join(packets)),'native_ordered_output_sha256':sha(outputs[0]),'fresh_process_runs':3,'reverse_repeat_count':len(rows),'object_canaries_unchanged':True,'nonvelocity_object_bytes_unchanged':True,'nominal_ticks_per_second':ticks_per_second,'velocity_unit_mps':velocity_unit,'reference_step_ticks':49710,'case_count':len(rows),'cases':rows,'scope':'Original Cobra38 six signed thrust directions with identity Q31 at8,49700,49710 ticks. Conservative phone profile selects the weakest nominal49710 magnitude. No full original controller, fuel, cargo-dependent loadout catalogue, equipment boost or Android native emulation.'}
    args.output.write_text(json.dumps(fixture,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'case_count':len(rows),'fixture_sha256':sha(args.output.read_bytes()),'reference_axis_accelerations':[row['expected']['acceleration_mps2'][row['axis_index']]for row in rows if row['step_ticks']==49710]}))
if __name__=='__main__':main()
