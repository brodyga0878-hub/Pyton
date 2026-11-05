#!/usr/bin/env python3
"""Independent original F1357 calendar / F1363 time display controls.

The reviewed integer instructions execute in a host x86_64 ELF. Only host ABI
stack widths and standard C sprintf/strlen calls are adapted. No native code or
x86 interpreter is part of the Android runtime.
"""
from __future__ import annotations
import argparse,hashlib,json,random,re,struct,subprocess,sys,tempfile
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
DAT_SHA='34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850'
EPOCH_DAY=0x121cf7
EPOCH_TICK=0x80000000

def sha(raw):return hashlib.sha256(raw).hexdigest()
def procedure(source,number):
 match=re.search(rf'^FUNC_{number:06d}(?:_[A-Za-z0-9_]+)?:',source,re.M)
 if not match:raise ValueError('Missing source function '+str(number))
 end=re.search(r'^FUNC_\d+(?:_[A-Za-z0-9_]+)?:',source[match.end():],re.M)
 if not end:raise ValueError('Missing next procedure')
 return source[match.start():match.end()+end.start()]

def make_cases():
 cases=[];seen=set()
 def add(day,tick,origin):
  if not 0<=day<=0xffffffff or not 0<=tick<=0xffffffff or (day,tick) in seen:return
  seen.add((day,tick));cases.append({'day_u32':day,'tick_u32':tick,'origin':origin})
 ticks=[0,1,49709,49710,49711,0x7fffffff,0x80000000,0xfffffffe,0xffffffff,49710*86400-1,49710*86400]
 for day in [0,1,30,31,58,59,60,365,366,730,731,1095,1096,1460,1461,EPOCH_DAY-1,EPOCH_DAY,EPOCH_DAY+1,0x7fffffff,0x80000000,0xfffffffe,0xffffffff]:
  for tick in ticks:add(day,tick,'calendar_and_tick_boundaries')
 for year in [0,1,3,4,99,100,399,400,1599,1600,1899,1900,1999,2000,3199,3200,3248,3249,3250,3251,3252,3260,10000,1000000]:
  cycles,rest=divmod(year,4);start=cycles*1461+(0 if rest==0 else 366+(rest-1)*365)
  for offset in [-1,0,1,58,59,60,364,365,366]:add(start+offset,EPOCH_TICK,'leap_year_first_and_century_boundaries')
 for seconds in [0,1,59,60,61,3599,3600,43200,86399,86400]:
  for delta in [-1,0,1]:add(EPOCH_DAY,seconds*49710+delta,'display_second_boundaries')
 rng=random.Random(13571363)
 for _ in range(1024):add(rng.getrandbits(32),rng.getrandbits(32),'fixed_seed_random_u32')
 return cases

def native_assembly(source):
 selected=[procedure(source,n) for n in [1357,1363]]
 joined='\n'.join(selected)+'\nFUNC_999999:\nret\n'
 joined=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',joined)
 sys.path.insert(0,str(PROJECT/'recovered-history/ground_harness/tools'))
 from native_reference import procedures
 lines,_=procedures(joined,[1357,1363])
 lines=[re.sub(r'^(sub \w+,)(DATA_\d+)$',r'\1OFFSET FLAT:\2',line) for line in lines]
 # F1357 releases its two32bit local slots with two POP ECX instructions.
 # Host POPs are64bit, so reserve16bytes while preserving local field offsets.
 if lines.count('add rsp,-8')!=1:raise ValueError('Unexpected calendar local stack')
 lines=[('add rsp,-16' if line=='add rsp,-8' else line) for line in lines]
 return '''.intel_syntax noprefix
.code64
.section .text
.global _start
'''+ '\n'.join(lines)+'''
_sprintf:
 push rbp
 mov rbp,rsp
 push rsi
 push rdi
 and rsp,-16
 mov rdi,QWORD PTR [rbp+16]
 mov rsi,QWORD PTR [rbp+24]
 mov edx,DWORD PTR [rbp+32]
 mov ecx,DWORD PTR [rbp+40]
 mov r8d,DWORD PTR [rbp+48]
 xor eax,eax
 call sprintf@PLT
 mov rsi,QWORD PTR [rbp-8]
 mov rdi,QWORD PTR [rbp-16]
 mov rsp,rbp
 pop rbp
 ret
_strlen:
 mov rax,QWORD PTR [rsp+8]
 xor ecx,ecx
.length_loop:
 cmp BYTE PTR [rax+rcx],0
 je .length_done
 inc ecx
 jmp .length_loop
.length_done:
 mov eax,ecx
 ret
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:input
 add rsi,r8
 mov edx,8
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,8
 jne read_more
 push OFFSET FLAT:output+8
 push OFFSET FLAT:output+4
 push OFFSET FLAT:output
 mov eax,DWORD PTR [input]
 push rax
 call FUNC_001357
 add rsp,32
 mov eax,DWORD PTR [input+4]
 push rax
 push OFFSET FLAT:output+12
 call FUNC_001363
 add rsp,16
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,20
 syscall
 jmp next_case
finished:
 mov eax,60
 xor edi,edi
 syscall
.section .data
DATA_007650:
 .byte 31
DATA_007651:
 .byte 28,31,30,31,30,31,31,30,31,30,31
DATA_007670:
 .asciz "%02i:%02i:%02i"
.section .bss
.balign 16
input: .skip 8
output: .skip 32
 .skip 65536
stack_end:
.section .note.GNU-stack,"",@progbits
''', {str(n):sha(block.encode()) for n,block in zip([1357,1363],selected)}

def run_oracle(binary,payload,expected):
 result=subprocess.run([str(binary)],input=payload,stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True,timeout=30)
 if len(result.stdout)!=expected:raise ValueError('Incomplete native output')
 return result.stdout

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
 parser.add_argument('--data-source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'))
 parser.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
 parser.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_clock_native.json')
 args=parser.parse_args();original=args.executable.read_bytes();asm_raw=args.source.read_bytes();data_raw=args.data_source.read_bytes()
 if (sha(original),sha(asm_raw),sha(data_raw))!=(EXE_SHA,ASM_SHA,DAT_SHA):raise ValueError('Unreviewed original source')
 signatures={'calendar_entry':(0x3fa96,bytes.fromhex('558bec83c4f85356578b750c8b7d0866c745fe6d01')),'time_entry':(0x3fc3b,bytes.fromhex('558bec5356578b5d0c8b7508b92ec20000')),'month_lengths':(0xe9aec,bytes([31,28,31,30,31,30,31,31,30,31,30,31])),'initial_clock_words':(0xa1da,bytes.fromhex('c7053c21640000000080c70540216400f71c1200'))}
 verified={}
 for name,(offset,raw) in signatures.items():
  if original.find(raw)!=offset or original.find(raw,offset+1)>=0:raise ValueError('Original EXE signature differs: '+name)
  verified[name]={'offset':hex(offset),'bytes_hex':raw.hex()}
 format_bytes=b'%02i:%02i:%02i\0';format_at=original.find(format_bytes)
 if format_at<0 or original.find(format_bytes,format_at+1)>=0:raise ValueError('Original time format differs')
 verified['time_format']={'offset':hex(format_at),'bytes_hex':format_bytes.hex()}
 cases=make_cases();text,hashes=native_assembly(asm_raw.decode());payload=b''.join(struct.pack('<II',row['day_u32'],row['tick_u32']) for row in cases)
 with tempfile.TemporaryDirectory(prefix='ffe-source-clock-',dir='/tmp') as tmp:
  directory=Path(tmp);source=directory/'oracle.S';binary=directory/'oracle';source.write_text(text)
  subprocess.run(['gcc','-nostartfiles','-no-pie','-Wl,-e,_start',str(source),'-o',str(binary)],check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  buffer=run_oracle(binary,payload,len(cases)*20)
  if any(run_oracle(binary,payload,len(buffer))!=buffer for _ in range(2)):raise ValueError('Fresh native processes disagree')
  backwards=b''.join(struct.pack('<II',row['day_u32'],row['tick_u32']) for row in reversed(cases))
  reverse_buffer=run_oracle(binary,payload+backwards,len(buffer)*2)
  if reverse_buffer[:len(buffer)]!=buffer or [reverse_buffer[len(buffer)+i*20:len(buffer)+(i+1)*20] for i in range(len(cases))]!=[buffer[i*20:(i+1)*20] for i in reversed(range(len(cases)))]:raise ValueError('Native interleaving changed calendar state')
 for i,row in enumerate(cases):
  day,month,year=struct.unpack_from('<III',buffer,i*20);clock=buffer[i*20+12:i*20+20].decode('ascii')
  row.update(day=day,month=month,year=year,time_ascii=clock,hour=int(clock[:2]),minute=int(clock[3:5]),second=int(clock[6:8]))
 report={'schema':1,'revision':'source-f1357-f1363-clock-native-v1','source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'source_data_sha256':DAT_SHA,'source_commit':'7e540341d4e09aa3c92877b87d49e7f2c143ad8d','source_procedure_sha256':hashes,'native_assembly_sha256':sha(text.encode()),'binary_signature_verification':verified,'scope':'Complete original F1357 day/month/year conversion and F1363 time formatting; host ABI and standard C formatter only adapted. Not original simulation-time accumulation, scheduling, ephemerides or live physics.','native_formatter':'libc sprintf with original verified %02i:%02i:%02i; strlen equivalent byte scan','host_adaptations':{'stack_arguments_and_saved_registers_4_to_8_bytes':True,'calendar_local_reservation_8_to_16_for_two_host_pops':True,'gnu_assembler_address_immediate_spelling':True,'standard_formatter_cdecl_to_systemv_wrapper':True,'calendar_and_display_integer_operations_unchanged':True},'epoch_day_u32':EPOCH_DAY,'epoch_tick_u32':EPOCH_TICK,'ticks_per_display_second':49710,'fresh_process_runs':3,'fresh_process_outputs_identical':True,'reverse_interleaving_cases':len(cases),'native_output_sha256':sha(buffer),'case_count':len(cases),'cases':cases}
 args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(report,ensure_ascii=False,separators=(',',':'))+'\n')
 print(f'SOURCE CLOCK NATIVE PASS: {len(cases)} cases; three fresh processes and reversed interleaving; F1357/F1363, no live-clock claim')

if __name__=='__main__':main()
