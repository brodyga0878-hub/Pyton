#!/usr/bin/env python3
"""Execute original F1033/F1034 against explicit F569 contact fixtures.

Only ABI pointer/stack widths are adapted. F569 geometry and UI/destruction
callbacks are labelled stubs; the original branch/arithmetic/cargo instructions
execute natively. This does not prove the caller's SI/contact bridge.
"""
from __future__ import annotations
import argparse,hashlib,importlib.util,json,random,re,struct,subprocess,tempfile
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
DATA_SHA='34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850'
GAME_BYTES=544
OBJECT_BYTES=338
INPUT_BYTES=24+GAME_BYTES+OBJECT_BYTES
OUTPUT_BYTES=4+GAME_BYTES+OBJECT_BYTES+32+64
GUARD=0x53434f4f50465545

def sha(raw):return hashlib.sha256(raw).hexdigest()
def s32(value):return (value&0x7fffffff)-(value&0x80000000)
def block(source,n):
 a=re.search(r'^FUNC_%06d(?:_[A-Za-z0-9_]+)?:'%n,source,re.M)
 b=re.search(r'^FUNC_\d+(?:_[A-Za-z0-9_]+)?:',source[a.end():],re.M)
 return source[a.start():a.end()+b.start()if b else len(source)]

def assembly(source):
 spec=importlib.util.spec_from_file_location('scoop_host_abi',PROJECT/'recovered-history/ground_harness/tools/native_reference.py');adapter=importlib.util.module_from_spec(spec);spec.loader.exec_module(adapter)
 normalized=re.sub(r'FUNC_(\d{6})_[A-Za-z0-9_]+',r'FUNC_\1',source)
 lines,_=adapter.procedures(normalized,[1033,1034]);text='\n'.join(lines)
 return '.intel_syntax noprefix\n.code64\n.section .text\n'+text+f'''
FUNC_000569:
 mov rax,QWORD PTR [rsp+24]
 mov edx,DWORD PTR [input+4]
 mov BYTE PTR [rax],dl
 mov rax,QWORD PTR [rsp+48]
 mov edx,DWORD PTR [input+8]
 mov DWORD PTR [rax],edx
 mov rax,QWORD PTR [rsp+40]
 mov DWORD PTR [rax],OFFSET FLAT:parent
 ret
FUNC_001116:
 inc DWORD PTR [events]
 ret
FUNC_000349:
 mov rax,QWORD PTR [rsp+8]
 mov edx,DWORD PTR [rax]
 mov DWORD PTR [events+16],edx
 mov edx,DWORD PTR [rax+4]
 mov DWORD PTR [events+20],edx
 ret
FUNC_000148:
 inc DWORD PTR [events+4]
 mov eax,DWORD PTR [rsp+8]
 mov DWORD PTR [events+24],eax
 mov eax,DWORD PTR [rsp+16]
 mov DWORD PTR [events+28],eax
 ret
FUNC_001906:
 inc DWORD PTR [events+8]
 ret
FUNC_000953:
 inc DWORD PTR [events+12]
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
 mov edx,{INPUT_BYTES}
 sub edx,r8d
 syscall
 test eax,eax
 jz finished
 js failed
 add r8d,eax
 cmp r8d,{INPUT_BYTES}
 jb read_more
 mov rax,{GUARD}
 mov QWORD PTR [game_before],rax
 mov QWORD PTR [game_after],rax
 mov QWORD PTR [object_before],rax
 mov QWORD PTR [object_after],rax
 mov QWORD PTR [parent_before],rax
 mov QWORD PTR [parent_after],rax
 mov QWORD PTR [events_before],rax
 mov QWORD PTR [events_after],rax
 mov esi,OFFSET FLAT:input+24
 mov edi,OFFSET FLAT:DATA_008804
 mov ecx,{GAME_BYTES}
 rep movsb
 mov esi,OFFSET FLAT:input+{24+GAME_BYTES}
 mov edi,OFFSET FLAT:object
 mov ecx,{OBJECT_BYTES}
 rep movsb
 mov eax,DWORD PTR [input+12]
 mov DWORD PTR [parent+0x82],eax
 mov eax,DWORD PTR [input+16]
 mov DWORD PTR [DATA_009155],eax
 mov eax,DWORD PTR [input+20]
 mov DWORD PTR [DATA_008630],eax
 xor eax,eax
 mov edi,OFFSET FLAT:events
 mov ecx,32
 rep stosb
 push 0
 push 0
 push OFFSET FLAT:parent_ref
 push 0
 push OFFSET FLAT:object
 call FUNC_001033
 add rsp,40
 mov DWORD PTR [output],eax
 mov esi,OFFSET FLAT:DATA_008804
 mov edi,OFFSET FLAT:output+4
 mov ecx,{GAME_BYTES}
 rep movsb
 mov esi,OFFSET FLAT:object
 mov ecx,{OBJECT_BYTES}
 rep movsb
 mov esi,OFFSET FLAT:events
 mov ecx,32
 rep movsb
 mov rax,QWORD PTR [game_before]
 stosq
 mov rax,QWORD PTR [game_after]
 stosq
 mov rax,QWORD PTR [object_before]
 stosq
 mov rax,QWORD PTR [object_after]
 stosq
 mov rax,QWORD PTR [parent_before]
 stosq
 mov rax,QWORD PTR [parent_after]
 stosq
 mov rax,QWORD PTR [events_before]
 stosq
 mov rax,QWORD PTR [events_after]
 stosq
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,{OUTPUT_BYTES}
 syscall
 cmp eax,{OUTPUT_BYTES}
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
.align 8
DATA_006141: .quad FUNC_000569
parent_ref: .quad parent
.section .bss
.align 8
input: .space {INPUT_BYTES}
output: .space {OUTPUT_BYTES}
DATA_009155: .space 4
DATA_008630: .space 4
game_before: .space 8
DATA_008804: .space {GAME_BYTES}
game_after: .space 8
object_before: .space 8
object: .space {OBJECT_BYTES}
object_after: .space 8
parent_before: .space 8
parent: .space {OBJECT_BYTES}
parent_after: .space 8
events_before: .space 8
events: .space 32
events_after: .space 8
.set DATA_008897,DATA_008804+0x13c
.set DATA_008898,DATA_008804+0x146
.set DATA_008899,DATA_008804+0x14a
.set DATA_008900,DATA_008804+0x14c
.align 16
stack: .space 65536
stack_end:
'''

def pack(case):
 state=case['state'];contact=case['contact'];game=bytearray((i*17+3)&255 for i in range(GAME_BYTES));obj=bytearray((i*23+5)&255 for i in range(OBJECT_BYTES))
 for key,offset in [('cargo_used_s32',0x120),('capacity_s32',0x118),('cooldown_u32',0x1e8),('heat_s32',0x1ec),('speed_s32',0xd8)]:struct.pack_into('<I',game,offset,state[key]&0xffffffff)
 for key,offset in [('flags_c6_u16',0xc6),('hydrogen_u16',0x15a),('goods4_u16',0x13c),('goods9_u16',0x146),('goods11_u16',0x14a),('goods12_u16',0x14c)]:struct.pack_into('<H',game,offset,state[key])
 game[0xe8]=state['view_e8_u8'];obj[0xca]=state['equipped_ca_u8']
 header=struct.pack('<6I',case['id'],contact['flags_u8'],contact['altitude_raw_s32']&0xffffffff,contact['parent_model_u32'],state['step_u32'],state['sound_mode_s8']&0xffffffff)
 return header+game+obj

def cases():
 rows=[]
 def add(group,updates=None,contact_updates=None):
  state={'flags_c6_u16':0,'view_e8_u8':0,'equipped_ca_u8':0x12,'cargo_used_s32':7,'capacity_s32':80,'hydrogen_u16':4,'cooldown_u32':0,'heat_s32':0,'speed_s32':9000,'step_u32':49710,'sound_mode_s8':0,'goods4_u16':2,'goods9_u16':3,'goods11_u16':4,'goods12_u16':5};state.update(updates or {})
  contact={'flags_u8':1,'altitude_raw_s32':30000000,'parent_model_u32':137};contact.update(contact_updates or {})
  rows.append({'id':len(rows),'group':group,'state':state,'contact':contact})
 for flag in [0,1,2,3,0x7f,0x80,0x81,0xff]:
  for model in [0,112,133,134,136,137,139,140,148,149,0xffffffff]:add('flag_model',contact_updates={'flags_u8':flag,'parent_model_u32':model})
 for altitude in [-2147483648,-2,-1,0,11999999,12000000,12000001,29999999,30000000,30000001,2147483647]:
  for oldflags in [0,0x40,0xffff]:
   for view in [0,0x2c]:add('altitude_hud',{'flags_c6_u16':oldflags,'view_e8_u8':view,'sound_mode_s8':-1}, {'altitude_raw_s32':altitude})
 for speed in [-2147483648,-1,0,8999,9000,9001,2147483647]:
  for equipped in [0,2,0x10,0x12,0xff]:add('speed_equipment',{'speed_s32':speed,'equipped_ca_u8':equipped})
 for step in [0,1,255,256,1023,1024,49710,149129,149130,149131,0x7fffffff,0x80000000,0xffffffff]:
  for cooldown in [0,1,49710,149130,0x7fffffff,0xffffffff]:
   for model in [136,137,140]:add('cooldown_step_heat',{'step_u32':step,'cooldown_u32':cooldown},{'parent_model_u32':model})
 for used,capacity in [(-2147483648,2147483647),(-1,0),(0,0),(79,80),(80,80),(81,80),(2147483646,2147483647),(2147483647,2147483647)]:
  for hydrogen in [0,65534,65535]:add('cargo',{'cargo_used_s32':used,'capacity_s32':capacity,'hydrogen_u16':hydrogen})
 for heat in [-2147483648,-1,0,65535,0x7fff0000,0x7fffffff]:
  for model in [136,137,139,140,148]:add('thermal',{'heat_s32':heat,'step_u32':0xffffffff},{'parent_model_u32':model})
 for equipped in [0,2,0x10,0x12]:
  for goods in [0,1,65535]:add('outside_spoilage',{'equipped_ca_u8':equipped,'goods4_u16':65535,'goods9_u16':65535,'goods11_u16':goods,'goods12_u16':goods},{'flags_u8':0})
 rng=random.Random(0x10331600)
 for i in range(240):
  add('random',{'flags_c6_u16':rng.randrange(65536),'view_e8_u8':rng.choice([0,0x2c,255]),'equipped_ca_u8':rng.randrange(256),'cargo_used_s32':rng.randrange(-20,101),'capacity_s32':rng.randrange(0,100),'hydrogen_u16':rng.randrange(65536),'cooldown_u32':rng.choice([0,149130,rng.randrange(2**32)]),'heat_s32':s32(rng.randrange(2**32)),'speed_s32':rng.randrange(-10000,20001),'step_u32':rng.randrange(2**32),'sound_mode_s8':rng.randrange(-128,128),'goods4_u16':rng.randrange(65536),'goods9_u16':rng.randrange(65536),'goods11_u16':rng.randrange(65536),'goods12_u16':rng.randrange(65536)},{'flags_u8':rng.randrange(256),'altitude_raw_s32':rng.randrange(-1000000,40000001),'parent_model_u32':rng.randrange(112,155)})
 return rows

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));parser.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));parser.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_fuel_scoop_native.json');args=parser.parse_args()
 raw=args.asm.read_bytes();data=args.data.read_bytes();assert sha(raw)==ASM_SHA and sha(data)==DATA_SHA
 source=raw.decode();rows=cases();inputs=[pack(row)for row in rows];asm=assembly(source)
 with tempfile.TemporaryDirectory(prefix='scoop-native-',dir='/tmp')as folder:
  folder=Path(folder);(folder/'reference.s').write_text(asm);subprocess.run(['as','--64','-o',str(folder/'reference.o'),str(folder/'reference.s')],check=True);subprocess.run(['ld','-m','elf_x86_64','-o',str(folder/'reference'),str(folder/'reference.o')],check=True)
  outputs=[]
  for order in [list(range(len(rows))),list(reversed(range(len(rows)))),list(range(len(rows)))]:
   run=subprocess.run([str(folder/'reference')],input=b''.join(inputs[i]for i in order),stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True);assert len(run.stdout)==len(rows)*OUTPUT_BYTES
   results={index:run.stdout[i*OUTPUT_BYTES:(i+1)*OUTPUT_BYTES]for i,index in enumerate(order)};outputs.append(results)
  assert outputs[0]==outputs[1]==outputs[2]
 for i,row in enumerate(rows):
  out=outputs[0][i];at=4+GAME_BYTES+OBJECT_BYTES;events=list(struct.unpack_from('<8I',out,at));guards=list(struct.unpack_from('<8Q',out,at+32));assert guards==[GUARD]*8
  row.update({'game_hex':inputs[i][24:24+GAME_BYTES].hex(),'object_hex':inputs[i][24+GAME_BYTES:].hex(),'expected':{'return_s32':struct.unpack_from('<i',out)[0],'game_hex':out[4:4+GAME_BYTES].hex(),'object_hex':out[4+GAME_BYTES:at].hex(),'events':events}})
 result={'schema':1,'scope':'Original F1033/F1034 native instruction control after explicit F569 contact fixture; UI/audio/destruction callbacks are counted stubs. Not SI geometry, actual thermal damage, timer decrement or phone execution.','asm_sha256':ASM_SHA,'data_asm_sha256':DATA_SHA,'procedures':{str(n):sha(block(source,n).encode())for n in [1033,1034]},'source_contract':'jjffe-f1033-after-f569-fuel-scoop-v1','case_count':len(rows),'fresh_process_runs':3,'reverse_order_unchanged':True,'canaries_unchanged':True,'native_input_sha256':sha(b''.join(inputs)),'native_output_sha256':sha(b''.join(outputs[0][i]for i in range(len(rows)))),'host_adapter_asm_sha256':sha(asm.encode()),'cases':rows}
 args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,separators=(',',':'))+'\n');print(json.dumps({k:result[k]for k in ['case_count','fresh_process_runs','canaries_unchanged','native_output_sha256']}))
 return 0
if __name__=='__main__':raise SystemExit(main())
