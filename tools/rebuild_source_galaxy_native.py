#!/usr/bin/env python3
"""Execute original F841/F853/F856/F861 sector generation on the host.

Controls execute source instructions, not a Python galaxy implementation.
Rendering is disabled as supported by F841's own parameter. Rendering
callbacks are non-returning traps, so reaching one rejects the oracle run.
"""
from __future__ import annotations

import argparse, hashlib, json, random, re, struct, subprocess, sys, tempfile
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
DATA_SHA='34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850'
NUMBERS=[841,853,856,861]
OBJECT_SIZE=338
STAR_BYTES=64*6
PACKET=16+OBJECT_SIZE+STAR_BYTES
POSITION_BYTES=64*12
OUTPUT=12+OBJECT_SIZE+STAR_BYTES+POSITION_BYTES+8

def sha(raw):return hashlib.sha256(raw).hexdigest()

def numeric_block(source,first,last):
    start=source.index(f'DATA_{first:06d}:');end=source.index(f'DATA_{last:06d}:',start)
    raw=bytearray();labels={}
    for line in source[start:end].splitlines():
        code=line.split(';')[0].strip()
        label=re.fullmatch(r'DATA_(\d+):',code)
        if label:labels[int(label[1])]=len(raw);continue
        if not code:continue
        if not code.startswith('db '):raise ValueError('Non-numeric data in '+code)
        raw.extend(int(x.strip(),0) for x in code[3:].split(','))
    return bytes(raw),labels

def resource(data_source,original):
    groups=[];blocks={}
    for first,last in [(6793,6795),(6795,6796),(6799,6812)]:
        raw,labels=numeric_block(data_source,first,last)
        offset=original.find(raw)
        if offset<0 or original.find(raw,offset+1)>=0:raise ValueError(f'Non-unique source table {first}')
        groups.append({'first_label':first,'exclusive_end_label':last,'executable_offset':offset,'bytes':len(raw),'sha256':sha(raw)})
        keys=sorted(labels)
        for i,key in enumerate(keys):blocks[str(key)]=raw[labels[key]:labels[keys[i+1]] if i+1<len(keys) else len(raw)].hex()
    vectors=bytes.fromhex(blocks['6793'])+bytes.fromhex(blocks['6794'])
    starts=bytes.fromhex(blocks['6800'])+bytes.fromhex(blocks['6801'])
    density=b''.join(bytes.fromhex(blocks[str(k)]) for k in [6806,6807,6808,6809])
    return {'schema':1,'source_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'source_data_sha256':DATA_SHA,
            'tables_hex':blocks,'source_blocks':groups,'handcrafted_vectors':len(vectors)//6,
            'handcrafted_sectors':len(bytes.fromhex(blocks['6799']))//4,'sector_end_count':len(starts)//4,
            'density_bytes':len(density),'scope':'Original sector density, positions and type tables; source strings and political data are separate.'}

def cases(data):
    coordinates=bytes.fromhex(data['tables_hex']['6799']);rows=[]
    for i in range(0,len(coordinates),4):
        x,y=struct.unpack_from('<HH',coordinates,i);rows.append({'x':x,'y':y,'group':'all_handcrafted_sectors'})
    for x,y in [(5912,5412),(0,0),(8191,8191),(4096,4096),(4000,5400),(5912,5600),(5913,5411)]:rows.append({'x':x,'y':y,'group':'known_or_boundaries'})
    rng=random.Random(0x841853856)
    for _ in range(256):rows.append({'x':rng.randrange(8192),'y':rng.randrange(8192),'group':'whole_galaxy'})
    for _ in range(192):rows.append({'x':rng.randrange(5700,6125),'y':rng.randrange(5200,5650),'group':'inhabited_neighbourhood'})
    for i,row in enumerate(rows):
        row['seed_a_u32']=rng.getrandbits(32);row['seed_b_u32']=rng.getrandbits(32)
        row['object_hex']=bytes((j*37+i*11+0x53)&255 for j in range(OBJECT_SIZE)).hex()
        row['stars_hex']=bytes((j*23+i*7+0xa9)&255 for j in range(STAR_BYTES)).hex()
    return rows

def assembly(source,data):
    sys.path.insert(0,str(PROJECT/'recovered-history/ground_harness/tools'))
    from native_reference import procedures
    lines,hashes=procedures(source,NUMBERS)
    code='\n'.join(lines)
    tables=[]
    for key,value in sorted(data['tables_hex'].items(),key=lambda x:int(x[0])):
        tables.append('DATA_%06d:\n .byte '%int(key)+','.join(str(v) for v in bytes.fromhex(value)))
    return '''.intel_syntax noprefix
.code64
.section .text
.global _start
'''+code+f'''
render_trap:
 ud2
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
 mov edx,{PACKET}
 sub rdx,r8
 syscall
 test rax,rax
 jle end_input
 add r8,rax
 cmp r8,{PACKET}
 jb read_more
 mov eax,DWORD PTR [input+8]
 mov DWORD PTR [DATA_008947],eax
 mov eax,DWORD PTR [input+12]
 mov DWORD PTR [DATA_008948],eax
 mov esi,OFFSET FLAT:input+16
 mov edi,OFFSET FLAT:object
 mov ecx,{OBJECT_SIZE}
 rep movsb
 mov esi,OFFSET FLAT:input+16+{OBJECT_SIZE}
 mov edi,OFFSET FLAT:stars
 mov ecx,{STAR_BYTES}
 rep movsb
 mov DWORD PTR [before_object],0x4f524143
 mov DWORD PTR [after_object],0x4f524143
 mov DWORD PTR [before_stars],0x4f524143
 mov DWORD PTR [after_stars],0x4f524143
 push 0
 mov eax,DWORD PTR [input+4]
 shl eax,16
 push rax
 mov eax,DWORD PTR [input]
 shl eax,16
 push rax
 push OFFSET FLAT:object
 push OFFSET FLAT:stars
 call FUNC_000841
 add rsp,40
 mov DWORD PTR [output],eax
 mov eax,DWORD PTR [DATA_008947]
 mov DWORD PTR [output+4],eax
 mov eax,DWORD PTR [DATA_008948]
 mov DWORD PTR [output+8],eax
 mov esi,OFFSET FLAT:object
 mov edi,OFFSET FLAT:output+12
 mov ecx,{OBJECT_SIZE}
 rep movsb
 mov esi,OFFSET FLAT:stars
 mov ecx,{STAR_BYTES}
 rep movsb
 push rdi
 xor eax,eax
 mov ecx,{POSITION_BYTES}
 rep stosb
 pop rdi
 xor r8d,r8d
position_loop:
 cmp r8d,DWORD PTR [output]
 jge positions_done
 imul eax,r8d,12
 add eax,OFFSET FLAT:output+12+{OBJECT_SIZE}+{STAR_BYTES}
 push rax
 imul eax,r8d,6
 add eax,OFFSET FLAT:stars
 push rax
 mov eax,DWORD PTR [input+4]
 shl eax,16
 push rax
 mov eax,DWORD PTR [input]
 shl eax,16
 push rax
 call FUNC_000856
 add rsp,32
 inc r8d
 jmp position_loop
positions_done:
 push 0
 mov eax,DWORD PTR [input+4]
 push rax
 mov eax,DWORD PTR [input]
 push rax
 call FUNC_000853
 add rsp,24
 mov DWORD PTR [output+{OUTPUT-8}],eax
 xor eax,eax
 cmp DWORD PTR [before_object],0x4f524143
 jne bad_guard
 cmp DWORD PTR [after_object],0x4f524143
 jne bad_guard
 cmp DWORD PTR [before_stars],0x4f524143
 jne bad_guard
 cmp DWORD PTR [after_stars],0x4f524143
 jne bad_guard
 mov eax,1
bad_guard:
 mov DWORD PTR [output+{OUTPUT-4}],eax
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,{OUTPUT}
 syscall
 cmp eax,{OUTPUT}
 jne failure
 jmp next_case
end_input:
 test r8,r8
 jne failure
 xor edi,edi
 jmp exit_now
failure:
 mov edi,1
exit_now:
 mov eax,60
 syscall
.section .data
DATA_007808: .quad render_trap
DATA_007807: .quad render_trap
'''+ '\n'.join(tables)+f'''
.section .bss
.align 16
DATA_008947: .zero 4
DATA_008948: .zero 4
DATA_008776: .zero 256
input: .zero {PACKET}
output: .zero {OUTPUT}
before_object: .zero 4
object: .zero {OBJECT_SIZE}
after_object: .zero 4
before_stars: .zero 4
stars: .zero {STAR_BYTES}
after_stars: .zero 4
.align 16
stack: .zero 65536
stack_end:
''',hashes

def packet(row):return struct.pack('<4I',row['x'],row['y'],row['seed_a_u32'],row['seed_b_u32'])+bytes.fromhex(row['object_hex'])+bytes.fromhex(row['stars_hex'])

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));parser.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));parser.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));args=parser.parse_args()
    raw=args.exe.read_bytes();asm=args.asm.read_bytes();dat=args.data.read_bytes()
    assert sha(raw)==EXE_SHA and sha(asm)==ASM_SHA and sha(dat)==DATA_SHA,'Pinned source mismatch'
    data=resource(dat.decode(),raw);rows=cases(data);text,hashes=assembly(asm.decode(),data)
    def execute(path,items):
        result=subprocess.run([str(path)],input=b''.join(packet(x) for x in items),stdout=subprocess.PIPE,check=True,timeout=30)
        assert len(result.stdout)==len(items)*OUTPUT
        return [result.stdout[i*OUTPUT:(i+1)*OUTPUT] for i in range(len(items))]
    with tempfile.TemporaryDirectory(prefix='ffe-galaxy-native-',dir='/workspace') as work:
        work=Path(work);(work/'oracle.s').write_text(text)
        subprocess.run(['as','--64','-o',str(work/'oracle.o'),str(work/'oracle.s')],check=True)
        subprocess.run(['ld','-o',str(work/'oracle'),str(work/'oracle.o')],check=True)
        outputs=execute(work/'oracle',rows)
        for _ in range(2):assert execute(work/'oracle',rows)==outputs
        assert execute(work/'oracle',list(reversed(rows)))==list(reversed(outputs))
    for row,out in zip(rows,outputs):
        count,seed_a,seed_b=struct.unpack_from('<3I',out);assert count<=62 and struct.unpack_from('<I',out,OUTPUT-4)[0]==1
        obj=out[12:12+OBJECT_SIZE];stars=out[12+OBJECT_SIZE:12+OBJECT_SIZE+STAR_BYTES]
        allowed=set(range(0x82,0x86))|set(range(0xa0,0xa6+count*2))
        original=bytes.fromhex(row['object_hex']);assert all(a==b or i in allowed for i,(a,b) in enumerate(zip(original,obj)))
        original_stars=bytes.fromhex(row['stars_hex']);assert stars[count*6:]==original_stars[count*6:]
        positions=[]
        for i in range(count):
            point=struct.unpack_from('<3i',out,12+OBJECT_SIZE+STAR_BYTES+i*12)
            positions.append({'record_hex':stars[i*6:(i+1)*6].hex(),'type_pair':list(obj[0xa6+i*2:0xa8+i*2]),'position_q16':list(point)})
        row['expected']={'count':count,'density_u32':struct.unpack_from('<I',out,OUTPUT-8)[0],'seed_a_u32':seed_a,'seed_b_u32':seed_b,'object_hex':obj.hex(),'stars_hex':stars.hex(),'stars':positions}
    output={'schema':1,'source_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'source_data_sha256':DATA_SHA,'source_commit':'7e540341d4e09aa3c92877b87d49e7f2c143ad8d','scope':'Actual F841 sector records/type tables, F853 density and F856 positions, render=false; callbacks trap if reached.','source_procedure_hashes':hashes,'adapted_assembly_sha256':sha(text.encode()),'native_ordered_output_sha256':sha(b''.join(outputs)),'case_count':len(rows),'position_case_count':sum(x['expected']['count'] for x in rows),'fresh_process_runs':3,'reverse_repeat_count':len(rows),'canaries_unchanged':True,'non_target_bytes_unchanged':True,'resource_sha256':sha((json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode()),'cases':rows}
    (PROJECT/'data/ffe_galaxy.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n');(PROJECT/'tests/fixtures/source_galaxy_native.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n')
    print(f'Native galaxy: {len(rows)} sectors, 3 fresh/reverse runs, complete record buffers and guards agree')

if __name__=='__main__':main()
