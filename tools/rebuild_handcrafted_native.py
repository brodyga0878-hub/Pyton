#!/usr/bin/env python3
"""Execute the actual reviewed JJFFE F872/F873/F874/F875 on a host control.

This is a new research wrapper. It is not Android code, an x86 interpreter or a
recovered old builder. Source constructors are retained; only host stack slots
and equivalent signed immediate encodings are adapted.
"""
from pathlib import Path
import argparse,ast,hashlib,json,re,struct,subprocess,sys,types

EXPECTED='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
SOURCE=Path('/workspace/ffe-upstream/jjffe/ffe.asm')
EXE=Path('/workspace/ffe-original/FIRSTENC.EXE')
OUT=Path('/workspace/ffe-reference-controls')
PROJECT=Path(__file__).resolve().parents[1]
TOOLS=PROJECT/'recovered-history/ground_harness/tools'
SLOTS=147
BYTES=SLOTS*68

def digest(data):return hashlib.sha256(data).hexdigest()

def main():
 global SOURCE,EXE,OUT
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--source',type=Path,default=SOURCE)
 parser.add_argument('--executable',type=Path,default=EXE)
 parser.add_argument('--output',type=Path,default=OUT)
 args=parser.parse_args();SOURCE=args.source;EXE=args.executable;OUT=args.output
 OUT.mkdir(parents=True,exist_ok=True)
 # The missing galaxy extractor provided this one revision constant to Image.
 # This explicit import shim does not implement or fabricate a galaxy dataset.
 shim=types.ModuleType('extract_galaxy');shim.EXPECTED=EXPECTED
 sys.modules['extract_galaxy']=shim;sys.path.insert(0,str(TOOLS))
 sys.path.insert(1,str(PROJECT/'recovered-history/world_gap_audit/tools'))
 from extract_ship_registry import Image
 from native_reference import procedures
 from extract_worlds import extract
 executable=EXE.read_bytes();image=Image(executable)
 world_data=extract(EXE)
 constructors={r['global_index']:r for s in world_data['systems'] for r in s['objects']}
 constructors.update({r['global_index']:r for r in world_data['unmatched_fallback']})
 source=SOURCE.read_text()
 if digest(SOURCE.read_bytes())!='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a':raise ValueError('Unreviewed JJFFE source revision')
 blocks={}
 for number in [872,873,874,875]:
  start=source.index(f'FUNC_{number:06d}:')
  match=re.search(r'^FUNC_\d+:',source[start+1:],re.M)
  blocks[number]=source[start:start+1+match.start()]
 source_hashes={str(k):digest(v.encode()) for k,v in blocks.items()}
 offsets=[int(x,16) for x in re.findall(r'\[esi\+0x([0-9a-f]+)\]',blocks[875])]
 pos=0x28568+5
 if executable[pos]!=0xbb or executable[pos+5]!=0xbe:raise ValueError('Unexpected EXE F875 register initialization')
 original_buffer=struct.unpack_from('<I',executable,pos+1)[0]
 name_address=struct.unpack_from('<I',executable,pos+6)[0]
 name_at=image.offset(name_address,max(offsets)+64)
 names=executable[name_at:name_at+max(offsets)+64]
 # Each F875 source name reference must land at the exact independently parsed
 # uploaded-EXE label. Intervening pointer words are copied verbatim, not padded.
 literal_names=[]
 for offset in offsets:
  end=names.find(b'\0',offset)
  if end<0:raise ValueError('Unterminated source constructor name')
  literal_names.append(names[offset:end].decode('ascii'))
 if sorted(literal_names)!=sorted(row['name_en'] for row in constructors.values()):
  raise ValueError('Reviewed source and uploaded EXE constructor name sets disagree')
 names_path=OUT/'handcrafted_names.bin';names_path.write_bytes(names)
 combined='\n'.join(blocks.values())+'\nFUNC_999999:\nret\n'
 adapted,_=procedures(combined,[872,873,874,875])
 immediate_reencodings=[]
 for index,line in enumerate(adapted):
  match=re.fullmatch(r'push (0x[0-9a-fA-F]+)',line)
  if match and int(match[1],16)>=0x80000000:
   value=int(match[1],16)
   if value>0xffffffff:raise ValueError('Source immediate is not 32-bit')
   adapted[index]='push '+str(value-0x100000000)
   immediate_reencodings.append({'unsigned_u32':value,'signed_i32':value-0x100000000})
 text='\n'.join(['.intel_syntax noprefix','.code64','.section .text','.global _start',*adapted])+f'''
_start:
 mov esp,OFFSET FLAT:stack_end
 xor ebp,ebp
 cld
 call FUNC_000875
 mov esi,OFFSET FLAT:DATA_008792
 mov edx,{BYTES}
 call write_all
 mov esi,OFFSET FLAT:DATA_007126
 mov edx,8
 call write_all
 mov eax,60
 xor edi,edi
 syscall
write_all:
 mov eax,1
 mov edi,1
 syscall
 test eax,eax
 jle write_failed
 add esi,eax
 sub edx,eax
 jnz write_all
 ret
write_failed:
 mov eax,60
 mov edi,71
 syscall
.section .data
.balign 4
DATA_007126: .long 0x1234
DATA_007127: .long 0x5678
DATA_007139:
 .incbin "{names_path.as_posix()}"
.section .bss
.balign 16
DATA_008792: .space {BYTES}
.balign 16
stack: .space 524288
stack_end:
.section .note.GNU-stack,"",@progbits
'''
 assembly=OUT/'handcrafted.s';assembly.write_text(text)
 obj=OUT/'handcrafted.o';binary=OUT/'handcrafted-native'
 subprocess.run(['as','--64',str(assembly),'-o',str(obj)],check=True)
 subprocess.run(['ld','-m','elf_x86_64',str(obj),'-o',str(binary)],check=True)
 symbol_data=subprocess.check_output(['nm','-n',str(binary)],text=True)
 for line in symbol_data.splitlines():
  fields=line.split()
  if len(fields)==3 and fields[2] in ['DATA_007126','DATA_007139','DATA_008792','stack_end']:
   if int(fields[0],16)>=0x80000000:raise ValueError('Host pointer outside supported low address space')
 results=[subprocess.run([str(binary)],stdout=subprocess.PIPE,check=True,timeout=5).stdout for _ in range(3)]
 if any(value!=results[0] for value in results):raise ValueError('Fresh process controls differ')
 raw=results[0]
 if len(raw)!=BYTES+8:raise ValueError('Native output length mismatch')
 (OUT/'handcrafted-native-slots.bin').write_bytes(raw[:BYTES])
 records={};empty=[]
 for index in range(SLOTS):
  row=raw[index*68:(index+1)*68]
  if index not in constructors:
   if row!=bytes(68):raise ValueError('Nonzero uninitialized/terminator slot '+str(index))
   empty.append(index);continue
  parameters=constructors[index]
  if not struct.unpack_from('<I',row)[0]:raise ValueError('Actual constructor left zero mass sentinel')
  kind,model=struct.unpack_from('<HH',row,10)
  if kind!=parameters['type_code'] or model!=parameters['model_index']:raise ValueError('Constructor type/model disagree')
  name=row[38:].split(b'\0',1)[0].decode('ascii')
  if name!=parameters['name_en']:raise ValueError('Constructor name disagrees at '+str(index))
  records[str(index)]={'record_hex':row.hex(),'source_seed':struct.unpack_from('<I',row,4)[0],
                       'model_index':model,'type_code':kind,'name_en':name,
                       'source_rotation_raw':row[62],'source_orientation_u16':struct.unpack_from('<H',row,66)[0]}
 if len(records)!=133:raise ValueError('Unexpected initialized record count')
 report={'schema':1,'scope':'New host-native F872/F873/F874/F875 reproduction. Uploaded EXE supplies constant constructor arguments and exact original name bytes. This is not a complete native engine or a claim of every source procedure being binary-identical to EXE.',
         'source_sha256':digest(executable),'source_procedure_hashes':source_hashes,
         'source_commit':subprocess.check_output(['git','-C',str(SOURCE.parent),'rev-parse','HEAD'],text=True).strip(),
         'assembly_sha256':digest(text.encode()),'binary_sha256':digest(binary.read_bytes()),
         'names_resource':{'source_exe_offset':hex(name_at),'source_virtual_address':hex(name_address),'bytes':len(names),'sha256':digest(names),'all_133_name_arguments_verified':True},
         'original_record_buffer_virtual_address':hex(original_buffer),
         'host_adaptations':{'stack_slots_4_to_8_bytes':True,'all_pointer_buffers_below_2GiB':True,'negative_32bit_push_immediates_equivalent_signed_encoding':immediate_reencodings,'no_constructor_or_rng_stubs':True,'initial_record_buffer':'zeroed ELF BSS, matching fresh initialization','note':'147slots include explicit terminator146 after last initialized record145'},
         'source_seed_words_initial':[0x1234,0x5678],'source_seed_words_final':list(struct.unpack_from('<II',raw,BYTES)),
         'fresh_process_repetitions_identical':3,'slots':SLOTS,'initialized_records':len(records),'zero_slots':empty,
         'slots_sha256':digest(raw[:BYTES]),'records':records}
 preserved_path=PROJECT/'recovered-history/city_integration_checks/partial/data/ffe_handcrafted_records.selected-native-records.txt'
 if preserved_path.exists():
  preserved=ast.literal_eval(preserved_path.read_text());checks=[]
  for index,old in preserved.items():
   current=records[index]
   same=current['record_hex']==old['record_hex'] and current['source_seed']==old['seed_u32']
   if not same:raise ValueError('Native output disagrees with preserved historical native record '+index)
   checks.append({'global_index':int(index),'name':old['name_en'],'full_68_byte_record_and_uid_match':True})
  report['preserved_old_native_records_exact_matches']=checks
  report['preserved_old_native_records_text_sha256']=digest(preserved_path.read_bytes())
 (OUT/'handcrafted-native-reference.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({k:report[k] for k in ['source_sha256','source_commit','initialized_records','slots','zero_slots','slots_sha256','source_seed_words_final','fresh_process_repetitions_identical']},ensure_ascii=False,indent=2))

if __name__=='__main__':main()
