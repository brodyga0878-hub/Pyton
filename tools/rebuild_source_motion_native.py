#!/usr/bin/env python3
"""Execute pinned original thrust/set-speed/kick/drift procedures on the host.

Expected bytes come only from the original instruction bodies. The wrapper
selects fixed-parent/fixed-attitude calls; it does not execute the whole player
event chain, reference-frame chooser, orientation, atmosphere, fuel or collision.
"""
from __future__ import annotations
import argparse,hashlib,importlib.util,json,random,re,struct,subprocess,tempfile
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
OBJECT=338;BANK=0x74+256*OBJECT;INPUT=28+OBJECT*2;OUTPUT=OBJECT*2+12+64+4
NUMBERS=[598,599,600,601,602,603,607,1333,1338,1466,1482,1483,1496,1502,1511,1512,1515,1516,1521,1523,1532,1656,1657,1658,1660,1661,1670]

def sha(raw):return hashlib.sha256(raw).hexdigest()
def block(source,n):
 a=re.search(r'^FUNC_%06d(?:_[A-Za-z0-9_]+)?:'%n,source,re.M)
 if not a:raise ValueError('Missing source procedure '+str(n))
 b=re.search(r'^(?:FUNC_\d+(?:_[A-Za-z0-9_]+)?|_[A-Za-z0-9_]+):',source[a.end():],re.M)
 return source[a.start():a.end()+b.start() if b else len(source)]
def assembly(source):
 path=PROJECT/'recovered-history/ground_harness/tools/native_reference.py'
 spec=importlib.util.spec_from_file_location('motion_native_abi',path);abi=importlib.util.module_from_spec(spec);spec.loader.exec_module(abi)
 selected='\n'.join(block(source,n) for n in NUMBERS)+'\nFUNC_999999:\nret\n'
 selected=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',selected)
 lines,_=abi.procedures(selected,NUMBERS);text='\n'.join(lines)
 # Original F1670 frees eight scratch-local bytes with two 32-bit pops.
 # Host pops are 64-bit, so reserve sixteen bytes; local arithmetic offsets
 # and all actual source calculations remain unchanged.
 old='FUNC_001670:\npush rbp\nmov rbp,rsp\nadd rsp,-8'
 if text.count(old)!=1:raise ValueError('Unexpected F1670 scratch frame')
 text=text.replace(old,old.replace('rsp,-8','rsp,-16'))
 return '.intel_syntax noprefix\n.code64\n.section .text\n.global _start\n'+text+f'''
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
 mov edi,OFFSET FLAT:bank_before
 mov ecx,{BANK+32}
 mov al,0xa5
 rep stosb
 mov esi,OFFSET FLAT:input+28
 mov edi,OFFSET FLAT:body
 mov ecx,{OBJECT}
 rep movsb
 movzx eax,BYTE PTR [body+0x56]
 imul eax,{OBJECT}
 add eax,OFFSET FLAT:bank+0x74
 mov DWORD PTR [parent_address],eax
 mov edi,eax
 mov esi,OFFSET FLAT:input+{28+OBJECT}
 mov ecx,{OBJECT}
 rep movsb
 mov esi,OFFSET FLAT:bank
 mov edi,OFFSET FLAT:bank_backup
 mov ecx,{BANK}
 rep movsb
 mov edi,OFFSET FLAT:command_out
 mov eax,0x5a5a5a5a
 mov ecx,3
 rep stosd
 mov eax,DWORD PTR [input]
 cmp eax,3
 je set_speed_only
 cmp eax,4
 je capped_only
 cmp eax,5
 je uncapped_only
 cmp eax,6
 je composed
 cmp eax,7
 je composed
 push OFFSET FLAT:command_out
 push OFFSET FLAT:input+16
 push OFFSET FLAT:body
 cmp eax,0
 je maximum_thrust
 cmp eax,1
 je limited_thrust
 call FUNC_000600
 jmp command_done
maximum_thrust:
 call FUNC_000598
 jmp command_done
limited_thrust:
 call FUNC_000599
command_done:
 add rsp,24
 jmp capture
set_speed_only:
 push OFFSET FLAT:command_out
 mov eax,DWORD PTR [input+12]
 push rax
 push OFFSET FLAT:body
 call FUNC_000607
 add rsp,24
 jmp capture
capped_only:
 mov eax,DWORD PTR [input+4]
 push rax
 push OFFSET FLAT:body
 call FUNC_000601
 add rsp,16
 jmp capture
uncapped_only:
 mov eax,DWORD PTR [input+4]
 push rax
 push OFFSET FLAT:body
 call FUNC_000602
 add rsp,16
 jmp capture
composed:
 mov eax,DWORD PTR [input+4]
 push rax
 push OFFSET FLAT:bank
 push OFFSET FLAT:body
 call FUNC_000603
 add rsp,24
 cmp DWORD PTR [input],7
 je manual_command
 push OFFSET FLAT:command_intent
 mov eax,DWORD PTR [input+12]
 push rax
 push OFFSET FLAT:body
 call FUNC_000607
 add rsp,24
 mov eax,OFFSET FLAT:command_intent
 jmp command_pointer_ready
manual_command:
 mov eax,OFFSET FLAT:input+16
command_pointer_ready:
 push OFFSET FLAT:command_out
 push rax
 push OFFSET FLAT:body
 call FUNC_000599
 add rsp,24
 mov eax,DWORD PTR [input+4]
 push rax
 push OFFSET FLAT:body
 cmp DWORD PTR [input],7
 je composed_uncapped
 call FUNC_000601
 jmp composed_kick_done
composed_uncapped:
 call FUNC_000602
composed_kick_done:
 add rsp,16
 mov eax,DWORD PTR [input+4]
 push rax
 mov eax,DWORD PTR [input+8]
 push rax
 push OFFSET FLAT:body
 call FUNC_001512
 add rsp,24
capture:
 mov esi,OFFSET FLAT:body
 mov edi,OFFSET FLAT:output
 mov ecx,{OBJECT}
 rep movsb
 mov esi,DWORD PTR [parent_address]
 mov ecx,{OBJECT}
 rep movsb
 mov esi,OFFSET FLAT:command_out
 mov ecx,12
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
 mov esi,OFFSET FLAT:bank
 mov edi,OFFSET FLAT:bank_backup
 mov ecx,{BANK}
 repe cmpsb
 sete al
 movzx eax,al
 mov DWORD PTR [output+{OUTPUT-4}],eax
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
DATA_007722: .quad FUNC_001496
DATA_007731: .quad FUNC_001483
DATA_007738: .quad FUNC_001502
DATA_007747: .quad FUNC_001515
DATA_007748: .quad FUNC_001516
DATA_007754: .quad FUNC_001532
DATA_008708: .long 0
DATA_008709: .long 0
DATA_008710: .long 0
.section .bss
.balign 16
input: .zero {INPUT}
body_before: .zero 16
body: .zero {OBJECT}
body_after: .zero 16
bank_before: .zero 16
bank: .zero {BANK}
bank_after: .zero 16
bank_backup: .zero {BANK}
parent_address: .zero 4
command_out: .zero 12
command_intent: .zero 12
output: .zero {OUTPUT}
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
'''

def cases():
 rng=random.Random(0x6011512);rows=[]
 matrices=[(2147483647,0,0,0,2147483647,0,0,0,2147483647),(0,0,-2147483648,0,2147483647,0,2147483647,0,0),(0,2147483647,0,-2147483648,0,0,0,0,2147483647),(1518500249,0,1518500249,0,2147483647,0,-1518500249,0,1518500249)]
 limits=[(3815,-3815,3815,-3815,10900,-3815),(32767,-32768,1,-1,100,-101),(0,0,0,0,0,0),(10,20,-30,-40,50,-60)]
 commands=[(0,0,0),(1,-1,1),(-1,1,-1),(3815,-3815,10900),(3816,-3816,10901),(-32768,32767,32767),(2147483647,-2147483648,0),(-2147483648,0,2147483647),(100000,200000,-300000)]
 ticks=[0,1,7,8,100,4970,49700,49710,131224-1,131224,131232,262136,262144,524288,2147483647,4294967295]
 def body_for(index):
  b=bytearray(rng.randbytes(OBJECT));struct.pack_into('<9i',b,0,*matrices[index%len(matrices)])
  struct.pack_into('<3q',b,0x3e,1000000000,-500000000,250000000);b[0x56]=0
  struct.pack_into('<6h',b,0xbc,*limits[index%len(limits)])
  struct.pack_into('<3i',b,0x8c,*[rng.choice([0,1,-1,100,-100,0x7fffffff,-0x80000000])for _ in range(3)])
  struct.pack_into('<3H',b,0xec,*[rng.choice([0,1,32767,65535])for _ in range(3)])
  struct.pack_into('<3i',b,0xf2,*[rng.choice([0,1,-1,100,-100,0x7fffffff,-0x80000000])for _ in range(3)])
  struct.pack_into('<3h',b,0xb6,*[rng.choice([-32768,-3815,-1,0,1,3815,10900,32767])for _ in range(3)])
  return b
 def add(op,b,tick=49710,speed=0,command=(0,0,0),parent=None,days=0,origin='fixed-register boundary'):
  parent=parent or bytes(OBJECT)
  rows.append({'operation':op,'ticks_u32':tick,'days_u32':days,'set_speed_s32':speed,'command_s32':list(command),'initial_body_hex':bytes(b).hex(),'parent_hex':bytes(parent).hex(),'origin':origin})
 for op in range(3):
  for i in range(120):add(op,body_for(i),command=commands[i%len(commands)] if i<90 else tuple(rng.randint(-2147483648,2147483647)for _ in range(3)))
 for i in range(180):add(3,body_for(i),speed=[0,1,-1,100,-100,65535,-65535,2147483647,-2147483648][i%9])
 for op in [4,5]:
  for i in range(192):add(op,body_for(i),tick=ticks[i%len(ticks)])
 controls=json.loads((PROJECT/'tests/fixtures/source_physics_bridge_native.json').read_text())['cases']
 for op in [6,7]:
  for i in range(144):
   b=body_for(i);p=bytes(OBJECT)
   if i%3:
    g=controls[(i*11)%len(controls)];p=bytes.fromhex(g['parent_hex']);gbody=bytes.fromhex(g['body_hex'])
    b[0x3e:0x56]=gbody[0x3e:0x56];b[0x56]=gbody[0x56]
   add(op,b,tick=[0,8,4970,49700,49710,131224,262144,524288][i%8],speed=[0,1,-1,10000,-10000,1000000][i%6],command=commands[i%len(commands)],parent=p,days=1 if i%19==0 else 0,origin='composed original fixed-frame kick/thrust/drift')
 return rows
def packet(row):return struct.pack('<IIIi3i',row['operation'],row['ticks_u32'],row['days_u32'],row['set_speed_s32'],*row['command_s32'])+bytes.fromhex(row['initial_body_hex'])+bytes.fromhex(row['parent_hex'])
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));parser.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_motion_native.json');args=parser.parse_args()
 raw=args.source.read_bytes()
 if sha(raw)!=ASM_SHA:raise ValueError('Unexpected original assembly')
 source=raw.decode();rows=cases();packets=[packet(r)for r in rows];text=assembly(source)
 with tempfile.TemporaryDirectory(prefix='original-source-motion-')as directory:
  work=Path(directory);(work/'native.s').write_text(text);subprocess.run(['as','--64','-o',str(work/'native.o'),str(work/'native.s')],check=True);subprocess.run(['ld','-o',str(work/'native'),str(work/'native.o')],check=True)
  first=subprocess.run([str(work/'native')],input=b''.join(packets),capture_output=True,check=True,timeout=60).stdout
  # The next states are ORIGINAL native output, never generated by GDScript.
  # These dependent cases prove continuation and save/resume of fraction words.
  if len(first)!=len(rows)*OUTPUT:raise ValueError('Initial native motion output truncated')
  for op in [6,7]:
   indices=[i for i,r in enumerate(rows)if r['operation']==op][:12]
   for index in indices:
    row=dict(rows[index]);row['initial_body_hex']=first[index*OUTPUT:index*OUTPUT+OBJECT].hex();row['ticks_u32']=49710;row['days_u32']=0;row['follows_native_case']=index;row['origin']='second original native step including integer/fraction continuation';rows.append(row)
  packets=[packet(r)for r in rows]
  runs=[subprocess.run([str(work/'native')],input=b''.join(packets),capture_output=True,check=True,timeout=60).stdout for _ in range(3)]
  if len(set(runs))!=1 or len(runs[0])!=len(rows)*OUTPUT:raise ValueError('Original motion output unstable or truncated')
  reverse=subprocess.run([str(work/'native')],input=b''.join(reversed(packets)),capture_output=True,check=True,timeout=60).stdout
  if reverse!=b''.join(runs[0][i*OUTPUT:(i+1)*OUTPUT]for i in reversed(range(len(rows)))):raise ValueError('Native order leaked state')
 for i,row in enumerate(rows):
  out=runs[0][i*OUTPUT:(i+1)*OUTPUT]
  if out[OBJECT:OBJECT*2]!=bytes.fromhex(row['parent_hex']) or out[-68:-4]!=b'\xa5'*64 or struct.unpack_from('<I',out,OUTPUT-4)[0]!=1:raise ValueError('Native parent/canary changed')
  row['expected']={'body_hex':out[:OBJECT].hex(),'command_s32':list(struct.unpack_from('<3i',out,OBJECT*2))}
 fixture={'schema':1,'profile':'source-fixed-frame-linear-motion-v1','source_assembly_sha256':ASM_SHA,'source_executable_sha256':EXE_SHA,'source_commit':'7e540341d4e09aa3c92877b87d49e7f2c143ad8d','source_procedure_sha256':{str(n):sha(block(source,n).encode())for n in NUMBERS},'host_assembly_sha256':sha(text.encode()),'input_packets_sha256':sha(b''.join(packets)),'native_output_sha256':sha(runs[0]),'case_count':len(rows),'fresh_process_runs':3,'reverse_case_count':len(rows),'body_and_bank_canaries_unchanged':True,'parent_bank_unchanged':True,'host_adaptations':['Reviewed 32-bit cdecl stack arguments and saved registers expanded to host widths','F1670 scratch-local reservation8→16 for two host pops; source arithmetic/offsets unchanged','Pinned CRT abs body with host argument ABI','Low-address object bank and stack'], 'scope':'Original F598/F599/F600 controls, F607 set-speed, complete F601/F602 velocity and fixed-frame F603→thrust→kick→F1512 compositions. No full F585/F606/atmosphere/collision/fuel/player event pipeline.','cases':rows}
 args.output.write_text(json.dumps(fixture,ensure_ascii=False,indent=2)+'\n');print(json.dumps({'cases':len(rows),'fixture_bytes':args.output.stat().st_size,'fixture_sha256':sha(args.output.read_bytes()),'fresh_process_runs':3,'reverse_cases':len(rows)}))
if __name__=='__main__':main()
