#!/usr/bin/env python3
"""New native controls for the recovered orientation primitive, not a full F866.

F1675/F1914/F1521 execute unchanged. F880's initialization instructions and
F866's timestamp/spin instructions are exact source slices. Original orbital
phase and animation regions are omitted explicitly; no output/math stub stands
in for those unvalidated effects. This host-only tool is not an Android emulator.
"""
from pathlib import Path
import argparse,hashlib,json,random,re,struct,subprocess,sys,tempfile

EXPECTED='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_EXPECTED='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
SIN_SIGNATURE=bytes.fromhex('000000003f2403007e480600be6c0900fd900c003db50f007cd91200bbfd1500')
INPUT_SIZE=68
OUTPUT_SIZE=104

def sha(data):return hashlib.sha256(data).hexdigest()

def block(source,number):
 match=re.search(rf'^FUNC_{number:06d}(?:_[A-Za-z0-9_]+)?:',source,re.M)
 if not match:raise ValueError('Missing procedure '+str(number))
 end=re.search(r'^(?:FUNC_\d+(?:_[A-Za-z0-9_]+)?|_[A-Za-z0-9_]+):',source[match.end():],re.M)
 return source[match.start():match.end()+end.start() if end else len(source)]

def slices(source):
 f880=block(source,880);f866=block(source,866)
 stamp='\t\tmov eax,[ebp+0x10]\n\t\tmov [esi+0xa8],eax\n\t\tmov eax,[ebp+0x14]\n\t\tmov [esi+0xac],eax\n'
 if f880.count(stamp)!=1:raise ValueError('Unexpected F880 timestamp initialization')
 start=f880.index('\t\tmovsx eax,byte [esi+0xc8]')
 end=f880.index('\tJUMP_003676:',start)
 initial=f880[start:end]
 if initial.count('call FUNC_001675_MatBuildYZT')!=1 or initial.count('add esp,byte +0xc')!=1:raise ValueError('Unexpected F880 orientation slice')
 test='\t\ttest byte [ebx+0x14c],0x20\n\t\tjz JUMP_003590\n'
 a=f866.index(test);head=f866[:a];spin=f866[f866.index('\tJUMP_003593:'):]
 # The actual timestamp/ground decision and the final jump are retained.
 # Nonground jumps directly to the actual spin block. Orbital integration and
 # station animation are absent; their effects are NOT simulated by stubs.
 selected=head+test+'\t\tjmp JUMP_003596\n\tJUMP_003590:\n'+spin
 if any(x in selected for x in ['call FUNC_000865','DATA_007741','DATA_007742','DATA_007743']):raise ValueError('Unvalidated effect leaked into selected primitive')
 if selected.count('call FUNC_001675_MatBuildYZT')!=2:raise ValueError('Unexpected F866 matrix call paths')
 init_wrapper='FUNC_999880:\npush ebp\nmov ebp,esp\npush esi\nmov esi,[ebp+0x8]\n'+stamp+initial+'pop esi\npop ebp\nret\n'
 return selected,init_wrapper,{'f880_initialization_slice_sha256':sha(initial.encode()),'f880_timestamp_slice_sha256':sha(stamp.encode()),'f866_timestamp_head_sha256':sha(head.encode()),'f866_spin_slice_sha256':sha(spin.encode()),'full_f866_source_sha256':sha(f866.encode()),'full_f880_source_sha256':sha(f880.encode())}

def assembly(source,sine_path):
 sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'recovered-history/ground_harness/tools'))
 from native_reference import procedures
 selected,initializer,metadata=slices(source)
 joined='\n'.join([block(source,1521),block(source,1675),block(source,1914),selected,initializer])+'\nFUNC_999999:\nret\n'
 joined=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',joined)
 adapted,_=procedures(joined,[1521,1675,1914,866,999880])
 traced=[]
 for line in adapted:
  traced.append(line)
  if line=='FUNC_001675:':
   # Observe actual arguments without changing any original register/flags or
   # the stack visible on entry to the real F1675 instructions.
   traced.extend('''pushfq
push rax
push rdx
mov edx,DWORD PTR [mode]
inc DWORD PTR [matrix_calls+rdx*4]
shl edx,3
mov eax,DWORD PTR [rsp+40]
mov DWORD PTR [argument_trace+rdx],eax
mov eax,DWORD PTR [rsp+48]
mov DWORD PTR [argument_trace+rdx+4],eax
pop rdx
pop rax
popfq'''.splitlines())
 text='\n'.join(['.intel_syntax noprefix','.code64','.section .text','.global _start',*traced])+f'''
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
 mov edx,{INPUT_SIZE}
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,{INPUT_SIZE}
 jne read_more
 mov edi,OFFSET FLAT:object
 xor eax,eax
 mov ecx,128
 rep stosd
 mov edi,OFFSET FLAT:argument_trace
 mov ecx,6
 rep stosd
 mov eax,DWORD PTR [input]
 mov BYTE PTR [object+0xc8],al
 mov eax,DWORD PTR [input+4]
 mov WORD PTR [object+0xcc],ax
 mov eax,DWORD PTR [input+8]
 mov BYTE PTR [object+0x14c],al
 mov DWORD PTR [mode],0
 mov eax,DWORD PTR [input+20]
 push rax
 mov eax,DWORD PTR [input+12]
 push rax
 push 0
 push OFFSET FLAT:object
 call FUNC_999880
 add rsp,32
 mov esi,OFFSET FLAT:object
 mov edi,OFFSET FLAT:output
 mov ecx,9
 rep movsd
 cmp DWORD PTR [input+28],0
 je no_override
 mov esi,OFFSET FLAT:input+32
 mov edi,OFFSET FLAT:object
 mov ecx,9
 rep movsd
no_override:
 mov eax,DWORD PTR [input+16]
 mov DWORD PTR [context],eax
 mov eax,DWORD PTR [input+24]
 mov DWORD PTR [context+4],eax
 mov DWORD PTR [context+8],OFFSET FLAT:object
 mov DWORD PTR [mode],1
 push OFFSET FLAT:context
 call FUNC_000866
 add rsp,8
 mov esi,OFFSET FLAT:object
 mov edi,OFFSET FLAT:output+36
 mov ecx,9
 rep movsd
 mov eax,DWORD PTR [object+0xa8]
 mov DWORD PTR [output+72],eax
 mov eax,DWORD PTR [object+0xac]
 mov DWORD PTR [output+76],eax
 mov esi,OFFSET FLAT:argument_trace
 mov edi,OFFSET FLAT:output+80
 mov ecx,6
 rep movsd
 mov esi,OFFSET FLAT:output
 mov edx,{OUTPUT_SIZE}
 call write_all
 jmp next_case
write_all:
 mov eax,1
 mov edi,1
 syscall
 test eax,eax
 jle failed
 add esi,eax
 sub edx,eax
 jnz write_all
 ret
failed:
 mov edi,73
 jmp exit
finished:
 xor edi,edi
exit:
 mov eax,60
 syscall
.section .data
DATA_007975:
 .incbin "sine.bin"
.section .bss
.balign 16
input: .space {INPUT_SIZE}
output: .space {OUTPUT_SIZE}
context: .space 12
mode: .space 4
argument_trace: .space 16
matrix_calls: .space 8
object: .space 512
.balign 16
stack: .space 524288
stack_end:
.section .note.GNU-stack,"",@progbits
'''
 return text,metadata

def cases():
 result=[];pairs=[(0,0),(0,0x100000),(0x7fffffff,0x80000000),(0xffffffff,0),(0xffff,0x10000),(0x1fffff,0x200000),(0,0xffffffff),(0xffe00000,0xfff00000)]
 tilts=[-32768,-16384,-1,0,1,12345,16383,16384,32767]
 sentinel=[11,22,33,44,55,66,77,88,99]
 for raw in range(256):
  for flagindex,flags in enumerate([0,0x10,0x20,0x30]):
   old,new=pairs[(raw+flagindex)%len(pairs)]
   result.append({'origin':'all_rotation_bytes_and_primary_flags','rotation_raw':raw,'tilt_i16':tilts[(raw+flagindex)%len(tilts)],'flags_u8':flags,'old_tick_u32':old,'new_tick_u32':new,'old_day_u32':raw,'new_day_u32':0xffffffff-raw,'previous_matrix_override':sentinel if (raw*4+flagindex)%61==0 else None})
 rng=random.Random(8661675)
 for _ in range(512):
  result.append({'origin':'deterministic_random','rotation_raw':rng.randrange(256),'tilt_i16':rng.randrange(-32768,32768),'flags_u8':rng.randrange(256),'old_tick_u32':rng.randrange(1<<32),'new_tick_u32':rng.randrange(1<<32),'old_day_u32':rng.randrange(1<<32),'new_day_u32':rng.randrange(1<<32),'previous_matrix_override':None})
 for raw in [-1,256,257,273,0x1234,-128]:
  result.append({'origin':'abi_width_wrapping','rotation_raw':raw,'tilt_i16':65535,'flags_u8':0x110,'old_tick_u32':-1,'new_tick_u32':0x100100001,'old_day_u32':-1,'new_day_u32':0x100000004,'previous_matrix_override':sentinel})
 return result

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]/'tests/fixtures/rebuild_body_rotation_native.json');a=p.parse_args()
 exe=a.executable.read_bytes();source_raw=a.source.read_bytes()
 if sha(exe)!=EXPECTED:raise ValueError('Unsupported uploaded EXE revision')
 if sha(source_raw)!=ASM_EXPECTED:raise ValueError('Unsupported reviewed ASM revision')
 source=a.source.read_text();at=exe.find(SIN_SIGNATURE)
 if at<0 or exe.find(SIN_SIGNATURE,at+1)>=0:raise ValueError('Missing/ambiguous original sine table')
 sine=exe[at:at+65536]
 if len(sine)!=65536:raise ValueError('Truncated sine table')
 bitmap=a.source.with_name('ffebmp.asm').read_text();start=bitmap.index('DATA_007975:');tail=bitmap[start:];end=re.search(r'^DATA_\d+:',tail[1:],re.M);span=tail[:end.start()+1] if end else tail
 source_bytes=bytes(int(v.strip(),0) for line in span.splitlines() if line.strip().startswith('db ') for v in line.strip()[3:].split(','))
 if source_bytes!=sine:raise ValueError('Original source/EXE sine resources disagree')
 control_cases=cases();ordered=control_cases+list(reversed(control_cases));payload=bytearray()
 for row in ordered:
  values=[row[k]&0xffffffff for k in ['rotation_raw','tilt_i16','flags_u8','old_tick_u32','new_tick_u32','old_day_u32','new_day_u32']]
  override=row['previous_matrix_override'];payload.extend(struct.pack('<8I9i',*values,int(override is not None),*(override or [0]*9)))
 with tempfile.TemporaryDirectory(prefix='ffe-body-rotation-native-') as directory:
  directory=Path(directory);sine_path=directory/'sine.bin';sine_path.write_bytes(sine)
  text,metadata=assembly(source,sine_path);(directory/'control.s').write_text(text)
  subprocess.run(['as','--64',str(directory/'control.s'),'-o',str(directory/'control.o')],cwd=directory,check=True)
  subprocess.run(['ld','-m','elf_x86_64',str(directory/'control.o'),'-o',str(directory/'control')],check=True)
  def run():return subprocess.run([str(directory/'control')],input=bytes(payload),stdout=subprocess.PIPE,check=True,timeout=15).stdout
  output=run();repeated=run()
  if output!=repeated:raise ValueError('Fresh process reproduction failed')
 if len(output)!=len(ordered)*OUTPUT_SIZE:raise ValueError('Incomplete native output')
 updates=0
 for index,row in enumerate(control_cases):
  data=output[index*OUTPUT_SIZE:(index+1)*OUTPUT_SIZE];reverse=output[(len(ordered)-1-index)*OUTPUT_SIZE:(len(ordered)-index)*OUTPUT_SIZE]
  if data!=reverse:raise ValueError('Native state leaked between cases')
  row['initial_matrix_q31']=list(struct.unpack_from('<9i',data));row['updated_matrix_q31']=list(struct.unpack_from('<9i',data,36));row['stored_tick_u32'],row['stored_day_u32']=struct.unpack_from('<2I',data,72)
  row['initial_args_i32']=list(struct.unpack_from('<2i',data,80));row['initial_matrix_calls'],row['matrix_update_calls']=struct.unpack_from('<2I',data,96)
  row['updated_args_i32']=list(struct.unpack_from('<2i',data,88)) if row['matrix_update_calls'] else None
  if row['initial_matrix_calls']!=1 or row['matrix_update_calls'] not in [0,1]:raise ValueError('Unexpected matrix execution count')
  updates+=row['matrix_update_calls']
 report={'schema':1,'revision':'rebuild-body-rotation-native-slice-v1','source_executable_sha256':sha(exe),'source_asm_sha256':sha(source_raw),'source_url':'https://github.com/videogamepreservation/jjffe','source_commit':'7e540341d4e09aa3c92877b87d49e7f2c143ad8d','scope':'Exact F1675/F1914/F1521 and extracted F880 init / F866 timestamp+spin instructions. Original orbital-phase and animation regions are omitted, not validated and not represented by output stubs. Does not validate clock epoch, live world spin, physical parent transforms or full F880/F866.','source_slices':metadata,'sine_sha256':sha(sine),'sine_bytes_verified_against_source':True,'native_assembly_sha256':sha(text.encode()),'host_adaptations':{'stack_arguments_4_to_8_bytes':True,'low_32bit_pointer_buffers':True,'matrix_argument_trace_preserves_original_registers_flags_and_stack':True,'omitted_effects':['orbital_phase_region','station_animation_region','ground_animation_region']},'random_seed':8661675,'case_count':len(control_cases),'matrix_updates':updates,'fresh_process_reproduction_verified':True,'reversed_interleaving_checks':len(control_cases),'cases':control_cases}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(report,separators=(',',':'))+'\n')
 print(json.dumps({'fixture':str(a.output),'case_count':len(control_cases),'updates':updates,'sha256':sha(a.output.read_bytes()),'scope':'orientation primitive only'},indent=2))

if __name__=='__main__':main()
