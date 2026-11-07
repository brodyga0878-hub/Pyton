#!/usr/bin/env python3
"""Native pinned JJFFE F1099 speed fragment/F1475/F1466/F1502 controls.

This executes original source instructions with the reviewed 64-bit host ABI.
It is not a whole-DOS-binary equivalence claim or a physical frame selector.
"""
from __future__ import annotations
import argparse,hashlib,importlib.util,json,random,re,struct,subprocess,tempfile
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
NUMBERS=[1466,1475,1502,1521,1656,999109]
def sha(raw):return hashlib.sha256(raw).hexdigest()
def function(source,n):
 a=re.search(r'^FUNC_%06d(?:_[A-Za-z0-9_]+)?:'%n,source,re.M);b=re.search(r'^FUNC_\d+(?:_[A-Za-z0-9_]+)?:',source[a.end():],re.M)
 return source[a.start():a.end()+b.start()if b else len(source)]
def native_assembly(source):
 original=function(source,1099);begin=original.index('\t\tmov eax,[ebx+0xc8]\n\t\tadd eax,0x8c\n\t\tpush eax\n\t\tlea eax,[ebp-0x44]');end=original.index('\n\t\tmov byte [DATA_009124]',begin);fragment=original[begin:end]
 extra='FUNC_999109:\n push ebp\n mov ebp,esp\n add esp,-0x44\n push ebx\n push esi\n mov ebx,[ebp+0x8]\n'+fragment+'\n pop esi\n pop ebx\n mov esp,ebp\n pop ebp\n ret\nFUNC_999999:\n ret\n'
 normalized=re.sub(r'FUNC_(\d{6})_[A-Za-z0-9_]+',r'FUNC_\1',source)+'\n'+extra
 spec=importlib.util.spec_from_file_location('atmosphere_speed_host_abi',PROJECT/'recovered-history/ground_harness/tools/native_reference.py');abi=importlib.util.module_from_spec(spec);spec.loader.exec_module(abi);lines,_=abi.procedures(normalized,NUMBERS)
 return '.intel_syntax noprefix\n.code64\n.section .text\n'+'\n'.join(lines)+'''
_abs:
 mov eax,DWORD PTR [rsp+8]
 test eax,eax
 jge abs_nonnegative
 neg eax
abs_nonnegative:
 ret
.global _start
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 lea rsi,[input+r8]
 mov edx,12
 sub edx,r8d
 syscall
 test eax,eax
 jz finished
 js failed
 add r8d,eax
 cmp r8d,12
 jb read_more
 mov eax,DWORD PTR [input]
 mov DWORD PTR [object+0x8c],eax
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [object+0x90],eax
 mov eax,DWORD PTR [input+8]
 mov DWORD PTR [object+0x94],eax
 push OFFSET FLAT:game
 call FUNC_999109
 add rsp,8
 mov eax,DWORD PTR [game+0xd8]
 mov DWORD PTR [output],eax
 mov eax,DWORD PTR [game+0xd4]
 mov DWORD PTR [output+4],eax
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,8
 syscall
 cmp eax,8
 jne failed
 jmp next_case
finished:
 mov eax,60
 xor edi,edi
 syscall
failed:
 mov eax,60
 mov edi,91
 syscall
.section .data
DATA_007738: .quad FUNC_001502
game: .space 0xc8
 .quad object
 .space 0x10
.section .bss
input: .space 12
output: .space 8
object: .space 338
.align 16
stack: .space 65536
stack_end:
''',fragment
def controls():
 result=[]
 for value in [0,1,-1,2999,3000,8999,9000,16383,16384,16385,32767,32768,65535,65536,0x3fffffff,0x40000000,0x7fffffff,-0x80000000]:
  for axis in range(3):
   row=[0,0,0];row[axis]=value;result.append(row)
 result+=[[9000,9000,0],[9000,9000,9000],[-9000,-9000,-9000],[0x7fffffff]*3,[-0x80000000]*3]
 rng=random.Random(0x10141475)
 for _ in range(180):result.append([rng.randrange(-0x80000000,0x80000000)for axis in range(3)])
 return result
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_atmosphere_speed_native.json');a=p.parse_args();raw=a.source.read_bytes();assert sha(raw)==ASM_SHA;source=raw.decode().replace('\r\n','\n');assembly,fragment=native_assembly(source);rows=controls();inputs=[struct.pack('<3i',*row)for row in rows]
 with tempfile.TemporaryDirectory(prefix='atmosphere-speed-native-',dir='/tmp')as d:
  work=Path(d);(work/'reference.s').write_text(assembly);subprocess.run(['as','--64',str(work/'reference.s'),'-o',str(work/'reference.o')],check=True);subprocess.run(['ld','-m','elf_x86_64',str(work/'reference.o'),'-o',str(work/'reference')],check=True)
  outputs=[]
  for order in [list(range(len(rows))),list(reversed(range(len(rows)))),list(range(len(rows)))]:
   run=subprocess.run([str(work/'reference')],input=b''.join(inputs[i]for i in order),stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True);assert len(run.stdout)==len(rows)*8;outputs.append({index:run.stdout[i*8:(i+1)*8]for i,index in enumerate(order)})
  assert outputs[0]==outputs[1]==outputs[2]
 cases=[{'velocity_s32':row,'speed_s32':struct.unpack('<2i',outputs[0][i])[0],'source_shift':struct.unpack('<2i',outputs[0][i])[1]}for i,row in enumerate(rows)]
 fixture={'schema':1,'asm_sha256':ASM_SHA,'source_contract':'pinned-jjffe-f1099-f1475-f1466-speed-v1','source_variant':'pinned_JJFFE_original_source_instructions_host_ABI','whole_DOS_binary_equivalence':False,'source_newlines_normalized_for_procedure_hashes':True,'source_fragment_sha256':sha(fragment.encode()),'source_procedures_sha256':{str(n):sha(function(source,n).encode())for n in [1466,1475,1502,1521,1656]},'fresh_process_runs':3,'reverse_repeat_count':len(rows),'case_count':len(rows),'native_output_sha256':sha(b''.join(outputs[0][i]for i in range(len(rows)))),'host_assembly_sha256':sha(assembly.encode()),'scope':'Original speed extraction instructions; actual reference-frame selection, SI conversion and thermal integrator are outside this fixture.','cases':cases};a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(fixture,separators=(',',':'))+'\n');print(json.dumps({k:fixture[k]for k in ['case_count','fresh_process_runs','native_output_sha256']}));return 0
if __name__=='__main__':raise SystemExit(main())
