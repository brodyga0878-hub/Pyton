#!/usr/bin/env python3
"""Independent source F575 final contact slice, not its collision provider.

Actual F575 velocity-sum/alignment/gear instructions and F1521 execute on
the host. Supplied normals are explicit inputs; no geometry/collision stub
stands in for an unexecuted normal provider. Android never runs this ELF.
"""
from __future__ import annotations
import argparse, hashlib, json, random, re, struct, subprocess, sys, tempfile
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
COMMIT='7e540341d4e09aa3c92877b87d49e7f2c143ad8d'
ABS_DOS=bytes.fromhex('558bec8b450885c07d068bd0f7daeb028bd08bc25dc3')
INPUT=52
OUTPUT=20+338+32
sha=lambda raw:hashlib.sha256(raw).hexdigest()

def block(source,number):
    start=re.search(r'^FUNC_%06d(?:_[A-Za-z0-9_]+)?:'%number,source,re.M)
    if not start:raise ValueError('Missing source procedure '+str(number))
    end=re.search(r'^(?:FUNC_\d+(?:_[A-Za-z0-9_]+)?|_[A-Za-z0-9_]+):',source[start.end():],re.M)
    return source[start.start():start.end()+end.start() if end else len(source)]

def assembly(source):
    original=block(source,575)
    start=original.index('\t\tmov eax,[ebx+0x8c]')
    end=original.index('\t\tcmp byte [DATA_008707]',start)
    velocity=original[start:end]
    start=original.index('\tJUMP_002412:')
    end=original.index('\tJUMP_002414:',start)+len('\tJUMP_002414:')
    contact=original[start:end]
    observed=contact.replace('\t\tmov eax,esi','\t\tmov eax,esi\n\t\tmov [alignment_observation],eax')
    observed=observed.replace('\t\tor byte [DATA_008696],0x40','\t\tor byte [DATA_008696],0x40\n\t\tmov dword [accepted_observation],0x1')
    wrapper='''FUNC_999575:
 push ebp
 mov ebp,esp
 add esp,-0x90
 push ebx
 push esi
 push edi
 mov ebx,[ebp+0x8]
 mov esi,[ebp+0xc]
 lea edi,[ebp-0x80]
 mov ecx,3
 rep movsd
'''+velocity+'\n mov [l1_observation],esi\n'+observed+'''
 pop edi
 pop esi
 pop ebx
 mov esp,ebp
 pop ebp
 ret
FUNC_999999:
 ret
'''
    joined=block(source,865)+'\n'+block(source,1521)+'\n'+wrapper
    joined=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',joined)
    sys.path.insert(0,str(PROJECT/'recovered-history/ground_harness/tools'))
    from native_reference import procedures
    lines,hashes=procedures(joined,[865,1521,999575])
    text='\n'.join(['.intel_syntax noprefix','.code64','.section .text','.global _start',*lines])+f'''
_abs:
 push rbp
 mov rbp,rsp
 mov eax,DWORD PTR [rbp+16]
 test eax,eax
 jge abs_positive
 mov edx,eax
 neg edx
 jmp abs_return
abs_positive:
 mov edx,eax
abs_return:
 mov eax,edx
 pop rbp
 ret
_start:
 mov esp,OFFSET FLAT:stack_end
 cld
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
 mov edi,OFFSET FLAT:object_canary_before
 mov eax,0xa5
 mov ecx,370
 rep stosb
 mov esi,OFFSET FLAT:input
 mov edi,OFFSET FLAT:object+0xc
 mov ecx,3
 rep movsd
 mov esi,OFFSET FLAT:input+24
 mov edi,OFFSET FLAT:object+0x8c
 mov ecx,3
 rep movsd
 mov eax,DWORD PTR [input+36]
 mov WORD PTR [object+0x9e],ax
 mov eax,DWORD PTR [input+40]
 mov BYTE PTR [DATA_008696],al
 mov eax,DWORD PTR [input+44]
 mov BYTE PTR [DATA_008700],al
 mov BYTE PTR [DATA_008699],0x5a
 mov DWORD PTR [accepted_observation],0
 mov DWORD PTR [l1_observation],0
 mov DWORD PTR [alignment_observation],0
 cmp DWORD PTR [input+48],1
 je door_case
 push OFFSET FLAT:input+12
 push OFFSET FLAT:object
 call FUNC_999575
 add rsp,16
 jmp capture_case
door_case:
 mov eax,DWORD PTR [input+40]
 mov BYTE PTR [object+0xc9],al
 mov eax,DWORD PTR [input+44]
 mov DWORD PTR [DATA_009155],eax
 push OFFSET FLAT:object
 call FUNC_000865
 add rsp,8
capture_case:
 mov eax,DWORD PTR [l1_observation]
 mov DWORD PTR [output],eax
 mov eax,DWORD PTR [alignment_observation]
 mov DWORD PTR [output+4],eax
 movzx eax,BYTE PTR [DATA_008696]
 mov DWORD PTR [output+8],eax
 movzx eax,BYTE PTR [DATA_008699]
 mov DWORD PTR [output+12],eax
 mov eax,DWORD PTR [accepted_observation]
 mov DWORD PTR [output+16],eax
 mov esi,OFFSET FLAT:object_canary_before
 mov edi,OFFSET FLAT:output+20
 mov ecx,370
 rep movsb
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,{OUTPUT}
 syscall
 jmp next_case
finished:
 mov eax,60
 xor edi,edi
 syscall
.section .bss
.balign 16
input:.skip {INPUT}
output:.skip {OUTPUT}
object_canary_before:.skip 16
object:.skip 338
object_canary_after:.skip 16
DATA_008696:.skip 4
DATA_008699:.skip 4
DATA_008700:.skip 4
DATA_009155:.skip 4
accepted_observation:.skip 4
l1_observation:.skip 4
alignment_observation:.skip 4
.balign 16
stack:.skip 65536
stack_end:
'''
    return text,{'full_f575_source_sha256':sha(original.encode()),'velocity_slice_sha256':sha(velocity.encode()),'contact_slice_sha256':sha(contact.encode()),'observation_writes_preserve_registers_and_flags':True,'adapted_procedure_hashes':hashes}

def cases():
    rows=[]
    def add(name,up,normal,velocity,gear=65535,flags=0,damage=255):
        rows.append({'name':name,'up_q31':list(up),'normal_q31':list(normal),'velocity_s32':list(velocity),'gear_u16':gear,'initial_flags_u8':flags,'damage_enabled_u8':damage})
    one=0x7fffffff
    for up in [(0,one,0),(0,0,one),(0,-one,0),(one,0,0),(0,0,0)]:
        for speed in [0,599,600,601,-600,-601,-0x80000000,0x7fffffff]:
            for gear in [0,65535]:add('axis/speed/gear %d'%len(rows),up,(0,one,0),(speed,0,0),gear)
    for value in [0x77ffffff,0x78000000,0x78000001,0x78000002,0x7fffffff]:
        for flags in [0,0x20,0x80,0xff]:add('alignment threshold %d'%len(rows),(value,0,0),(one,0,0),(200,200,200),flags=flags)
    rng=random.Random(0x5751675)
    for i in range(384):
        up=struct.unpack('<3i',rng.randbytes(12));normal=struct.unpack('<3i',rng.randbytes(12))
        velocity=tuple(rng.choice([-0x80000000,-601,-600,-1,0,1,200,600,601,0x7fffffff]) for _ in range(3))
        add('register control %d'%i,up,normal,velocity,rng.choice([0,1,65535]),rng.randrange(256),rng.randrange(256))
    return rows

def encode(row):
    if 'door_u16' in row:return struct.pack('<9i4I',*([0]*9),row['door_u16'],row['status_u8'],row['step_u32'],1)
    return struct.pack('<9i4I',*row['up_q31'],*row['normal_q31'],*row['velocity_s32'],row['gear_u16'],row['initial_flags_u8'],row['damage_enabled_u8'],0)

def original_body(row):
    data=bytearray([0xa5]*338)
    if 'door_u16' in row:
        struct.pack_into('<3i',data,0xc,0,0,0);struct.pack_into('<3i',data,0x8c,0,0,0)
        struct.pack_into('<H',data,0x9e,row['door_u16']);data[0xc9]=row['status_u8'];return bytes(data)
    struct.pack_into('<3i',data,0xc,*row['up_q31']);struct.pack_into('<3i',data,0x8c,*row['velocity_s32']);struct.pack_into('<H',data,0x9e,row['gear_u16'])
    return bytes(data)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--assembly',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_station_native.json')
    args=parser.parse_args();raw=args.assembly.read_bytes();exe=args.executable.read_bytes()
    assert sha(raw)==ASM_SHA and sha(exe)==EXE_SHA and exe[0x67038:0x67038+len(ABS_DOS)]==ABS_DOS
    text,provenance=assembly(raw.decode().replace('\r\n','\n'));contacts=cases()
    doors=[{'name':'source F865 door%d/status%d/step%d'%(door,status,step),'door_u16':door,'status_u8':status,'step_u32':step} for door in [0,1,32768,65534,65535] for status in [0,1,2,3,127,128,254,255] for step in [0,1,2,3,65535,65536,131070,131071,0xffffffff]]
    rows=contacts+doors;payload=b''.join(encode(row) for row in rows)
    with tempfile.TemporaryDirectory(prefix='station-contact-native-') as folder:
        root=Path(folder);(root/'native.s').write_text(text)
        subprocess.run(['as','--64',str(root/'native.s'),'-o',str(root/'native.o')],check=True)
        subprocess.run(['ld','-m','elf_x86_64','-Ttext=0x400000','-o',str(root/'native'),str(root/'native.o')],check=True)
        outputs=[subprocess.check_output([str(root/'native')],input=payload) for _ in range(3)]
        assert all(value==outputs[0] for value in outputs) and len(outputs[0])==len(rows)*OUTPUT
        reverse=subprocess.check_output([str(root/'native')],input=b''.join(encode(row) for row in reversed(rows)))
        assert reverse==b''.join(outputs[0][i*OUTPUT:(i+1)*OUTPUT] for i in reversed(range(len(rows))))
    for i,row in enumerate(rows):
        output=outputs[0][i*OUTPUT:(i+1)*OUTPUT];l1,dot,flags,damage,accepted=struct.unpack_from('<iiIII',output)
        assert output[20:36]==b'\xa5'*16 and output[-16:]==b'\xa5'*16
        if 'door_u16' in row:
            body=output[36:-16];original=bytearray(original_body(row));original[0x9e:0xa0]=body[0x9e:0xa0];original[0xc9]=body[0xc9];assert body==bytes(original)
            row['expected']={'door_u16':struct.unpack_from('<H',body,0x9e)[0],'status_u8':body[0xc9]}
        else:
            assert output[36:-16]==original_body(row)
            row['expected']={'l1_speed_s32':l1,'alignment_q31':dot,'flags_u8':flags,'damage_enabled_u8':damage,'accepted':bool(accepted)}
    report={'schema':1,'revision':'source-station-contact-native-v1','source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'source_commit':COMMIT,
            'scope':'Actual F575 final velocity/alignment/gear contact slice and F1521, plus complete F865 door update; supplied raw contact normals. Does not execute collision-provider, F582 station program, complete docking AI or SI bridge.',
            'source_slices':provenance,'full_f865_source_sha256':sha(block(raw.decode().replace('\r\n','\n'),865).encode()),'dos_abs_entry':{'file_offset':0x67038,'bytes':ABS_DOS.hex(),'sha256':sha(ABS_DOS)},'case_count':len(contacts),'door_case_count':len(doors),'fresh_process_runs':3,'reverse_repeat_count':len(contacts),'door_reverse_repeat_count':len(doors),'body_readonly_verified':True,'door_non_target_bytes_unchanged':True,'canaries_unchanged':True,
            'native_output_sha256':sha(outputs[0]),'adapted_assembly_sha256':sha(text.encode()),'cases':contacts,'door_cases':doors}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(report,separators=(',',':'))+'\n')
    print(json.dumps({'cases':len(contacts),'door_cases':len(doors),'accepted':sum(row['expected']['accepted'] for row in contacts),'fixture_sha256':sha(args.output.read_bytes())}))

if __name__=='__main__':main()
