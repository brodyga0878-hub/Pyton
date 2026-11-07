#!/usr/bin/env python3
"""Independent whole-procedure F572/F573 and composed roundtrip controls."""
from __future__ import annotations
import argparse,hashlib,importlib.util,json,random,re,struct,subprocess,tempfile
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
NUMBERS=[572,573,1517,1521,1657,1658,1660,1669,1670,1672,1673]
OBJECT=338;INPUT=8+OBJECT+36;OUTPUT=OBJECT+36+64
def sha(raw):return hashlib.sha256(raw).hexdigest()
def module(path,name):
 spec=importlib.util.spec_from_file_location(name,path);result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
def assembly(source):
 motion=module(PROJECT/'tools/rebuild_source_motion_native.py','source_frame_motion')
 abi=module(PROJECT/'recovered-history/ground_harness/tools/native_reference.py','source_frame_abi')
 selected='\n'.join(motion.block(source,n)for n in NUMBERS)+'\nFUNC_999999:\nret\n'
 selected=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',selected)
 lines,_=abi.procedures(selected,NUMBERS);text='\n'.join(lines)
 for number in [1669,1670]:
  old=f'FUNC_{number:06d}:\npush rbp\nmov rbp,rsp\nadd rsp,-8'
  if text.count(old)!=1:raise ValueError('Unexpected two-pop scratch local')
  text=text.replace(old,old.replace('rsp,-8','rsp,-16'))
 return '.intel_syntax noprefix\n.code64\n.section .text\n.global _start\n'+text+f'''
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
 mov edi,OFFSET FLAT:matrix_before
 mov ecx,68
 mov al,0xa5
 rep stosb
 mov esi,OFFSET FLAT:input+8
 mov edi,OFFSET FLAT:body
 mov ecx,{OBJECT}
 rep movsb
 mov edi,OFFSET FLAT:matrix
 mov ecx,36
 rep movsb
 mov al,BYTE PTR [input+4]
 mov BYTE PTR [DATA_008811],al
 push OFFSET FLAT:matrix
 push OFFSET FLAT:body
 test BYTE PTR [input],1
 jnz first_leave
 call FUNC_000572
 jmp first_done
first_leave:
 call FUNC_000573
first_done:
 add rsp,16
 cmp DWORD PTR [input],2
 jb capture
 push OFFSET FLAT:matrix
 push OFFSET FLAT:body
 test BYTE PTR [input],1
 jnz second_enter
 call FUNC_000573
 jmp second_done
second_enter:
 call FUNC_000572
second_done:
 add rsp,16
capture:
 mov esi,OFFSET FLAT:body
 mov edi,OFFSET FLAT:output
 mov ecx,{OBJECT}
 rep movsb
 mov esi,OFFSET FLAT:matrix
 mov ecx,36
 rep movsb
 mov esi,OFFSET FLAT:body_before
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:body_after
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:matrix_before
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:matrix_after
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
 mov edi,94
 jmp exit
finished:
 xor edi,edi
exit:
 mov eax,60
 syscall
.section .data
DATA_007749: .quad FUNC_001517
DATA_008811: .byte 0
.section .bss
.balign 16
input: .zero {INPUT}
body_before: .zero 16
body: .zero {OBJECT}
body_after: .zero 16
matrix_before: .zero 16
matrix: .zero 36
matrix_after: .zero 16
output: .zero {OUTPUT}
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
'''
def cases():
 rng=random.Random(0x572573);rows=[]
 matrices=[(2147483647,0,0,0,2147483647,0,0,0,2147483647),(0,0,-2147483648,0,2147483647,0,2147483647,0,0),(0,2147483647,0,-2147483648,0,0,0,0,2147483647),(1518500249,0,1518500249,0,2147483647,0,-1518500249,0,1518500249)]
 positions=[(0,0,0),(1,-1,2),(268435455,-268435455,0),(268435456,-268435456,1),(4294967295,-4294967296,2147483648),(-4294967296,0,0),(0x7fffffffffffffff,-0x8000000000000000,0),(1<<48,-(1<<42),123456789)]
 for mode in range(4):
  for i in range(180):
   b=bytearray(rng.randbytes(OBJECT));matrix=matrices[i%4]if i<120 else tuple(rng.randint(-2147483648,2147483647)for _ in range(9))
   struct.pack_into('<9i',b,0,*matrices[(i//4)%4]);struct.pack_into('<3q',b,0x3e,*(positions[i%8]if i<144 else tuple(rng.randint(-(1<<62),(1<<62)-1)for _ in range(3))))
   struct.pack_into('<3i',b,0x8c,*[rng.choice([0,1,-1,0x7fffffff,-0x80000000,12345678,-12345678])for _ in range(3)])
   rows.append({'operation':mode,'source_frame_byte':[0,1,2,127,255][i%5],'matrix_q31':list(matrix),'body_hex':bytes(b).hex()})
 return rows
def packet(row):return struct.pack('<II',row['operation'],row['source_frame_byte'])+bytes.fromhex(row['body_hex'])+struct.pack('<9i',*row['matrix_q31'])
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));parser.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_frame_native.json');args=parser.parse_args()
 raw=args.source.read_bytes()
 if sha(raw)!=ASM_SHA:raise ValueError('Unexpected source assembly')
 source=raw.decode();rows=cases();packets=[packet(r)for r in rows];text=assembly(source)
 with tempfile.TemporaryDirectory(prefix='original-source-frame-')as directory:
  work=Path(directory);(work/'native.s').write_text(text);subprocess.run(['as','--64','-o',str(work/'native.o'),str(work/'native.s')],check=True);subprocess.run(['ld','-o',str(work/'native'),str(work/'native.o')],check=True)
  runs=[subprocess.run([str(work/'native')],input=b''.join(packets),capture_output=True,check=True,timeout=60).stdout for _ in range(3)]
  if len(set(runs))!=1 or len(runs[0])!=len(rows)*OUTPUT:raise ValueError('Unstable/truncated native frame output')
  reverse=subprocess.run([str(work/'native')],input=b''.join(reversed(packets)),capture_output=True,check=True,timeout=60).stdout
  if reverse!=b''.join(runs[0][i*OUTPUT:(i+1)*OUTPUT]for i in reversed(range(len(rows)))):raise ValueError('Native frame order leaked state')
 for i,row in enumerate(rows):
  out=runs[0][i*OUTPUT:(i+1)*OUTPUT]
  if out[OBJECT:OBJECT+36]!=struct.pack('<9i',*row['matrix_q31']) or out[-64:]!=b'\xa5'*64:raise ValueError('Input matrix or canary changed')
  row['expected_body_hex']=out[:OBJECT].hex()
 motion=module(PROJECT/'tools/rebuild_source_motion_native.py','source_frame_metadata')
 fixture={'schema':1,'profile':'source-f572-f573-rotation-primitive-v1','source_assembly_sha256':ASM_SHA,'source_executable_sha256':EXE_SHA,'source_commit':'7e540341d4e09aa3c92877b87d49e7f2c143ad8d','source_procedure_sha256':{str(n):sha(motion.block(source,n).encode())for n in NUMBERS},'host_assembly_sha256':sha(text.encode()),'native_output_sha256':sha(runs[0]),'input_packets_sha256':sha(b''.join(packets)),'case_count':len(rows),'fresh_process_runs':3,'reverse_case_count':len(rows),'canaries_and_matrix_unchanged':True,'host_adaptations':['Reviewed32-bit cdecl stack ABI expanded to64-bit host slots','F1669/F1670 scratch reservation8→16 for two host pops','All source arithmetic, record offsets and per-term Q31 truncation unchanged'],'scope':'Whole F572/F573 rotation primitives and composed native roundtrips; no automatic FOR selection, parent-origin translation or angular surface-velocity adjustment','cases':rows}
 args.output.write_text(json.dumps(fixture,ensure_ascii=False,indent=2)+'\n');print(json.dumps({'case_count':len(rows),'fixture_bytes':args.output.stat().st_size,'fixture_sha256':sha(args.output.read_bytes())}))
if __name__=='__main__':main()
