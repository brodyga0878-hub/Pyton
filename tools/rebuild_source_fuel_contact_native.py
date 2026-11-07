#!/usr/bin/env python3
"""Actual original F1533/F574 natural contact controls for gas/star models.

Reuses the reviewed original ground-height instruction harness, extending only
its caller's descriptor domain. No height callback or enclosing-radius stand-in
is used. Damage/player callbacks remain explicit traps.
"""
from __future__ import annotations
import argparse,importlib.util,json,math,re,struct,subprocess,tempfile,types
from pathlib import Path
import rebuild_ground_surface_native as base

PROJECT=base.PROJECT
def expanded_helper():
 raw=(PROJECT/'tools/rebuild_ground_surface_native.py').read_text()
 old='parent_models.update(range(117,134))';assert raw.count(old)==1
 module=types.ModuleType('fuel_contact_original_harness');module.__file__=str(PROJECT/'tools/rebuild_ground_surface_native.py')
 exec(compile(raw.replace(old,'parent_models.update(range(117,149))'),module.__file__,'exec'),module.__dict__)
 return module

def build(helper,source,data,exe,model_lines,work):
 at=exe.find(helper.SIN_SIGNATURE);assert at>=0 and exe.find(helper.SIN_SIGNATURE,at+1)<0
 sine=exe[at:at+65536];(work/'sine.bin').write_bytes(sine)
 text,hashes,terrain,q=helper.assembly(source,data,exe,work/'sine.bin',model_lines)
 (work/'reference.s').write_text(text);subprocess.run(['as','--64',str(work/'reference.s'),'-o',str(work/'reference.o')],cwd=work,check=True)
 undefined=subprocess.check_output(['nm','-u',str(work/'reference.o')],text=True);adapter,metadata=q.unresolved_adapter(undefined,data)
 assert exe[0x67038:0x67038+len(helper.ABS_DOS)]==helper.ABS_DOS
 adapter=adapter.replace('_abs:\nmov eax,60\nmov edi,97\nsyscall','''_abs:
push rbp
mov rbp,rsp
mov eax,DWORD PTR [rbp+16]
test eax,eax
jge fuel_contact_abs_positive
neg eax
fuel_contact_abs_positive:
pop rbp
ret''')
 metadata['unreached_function_traps'].remove('_abs')
 (work/'excluded.s').write_text(adapter);subprocess.run(['as','--64',str(work/'excluded.s'),'-o',str(work/'excluded.o')],check=True)
 subprocess.run(['ld','-m','elf_x86_64',str(work/'reference.o'),str(work/'excluded.o'),'-o',str(work/'reference')],check=True)
 return text,hashes,metadata,base.sha(sine)

def controls(resources):
 rows=[]
 for model in range(134,149):
  entry=resources['models'][str(model)];vertices=bytes.fromhex(entry['vertices_hex']);zoom=entry['scale']+entry['scale2'];axis=abs(struct.unpack_from('<b',vertices,2)[0]);reference=axis<<zoom;outer=entry['outer_radius_raw']<<entry['model_scale_raw']
  for seed in [1,0x12345678]:
   for direction in [(1,0,0),(0,1,0),(1,1,1)]:
    length=math.sqrt(sum(x*x for x in direction))
    for offset in [-20000000,0,20000000]:
     radius=reference+offset;point=[round(radius*x/length)for x in direction]
     port=bytearray(base.OBJECT);port[0x56]=1;port[0x57]=1;port[0x86]=2;struct.pack_into('<3q',port,0x3e,*point)
     parent=bytearray(base.OBJECT);parent[0x86]=1;struct.pack_into('<I',parent,0xa0,seed)
     for i in range(3):struct.pack_into('<I',parent,i*16,0x7fffffff)
     rows.append({'mode':'height_query','origin':'Original gas/star descriptor and synthetic zero-inner-bound model84 source query probe; source F1533 initializes both unchanged.','parent_model':model,'port_model':84,'parent_index':1,'parent_uid_u32':seed,'direction_integer':list(direction),'reference_static_radius_raw':str(reference),'sample_offset_raw':offset,'point_input_raw':[str(x)for x in point],'port_object_input_hex':port.hex(),'parent_object_input_hex':parent.hex(),'phase_u16':0,'inclination_u16':0,'graphics_level':1,'initial_globals':{name:0 for name,_,_ in base.GLOBAL_FIELDS}})
  for factor in [0.0,0.25,1.0,3.0]:
   point=[round(outer*factor),0,0];port=bytearray(base.OBJECT);port[0x56]=1;port[0x57]=1;port[0x86]=2;struct.pack_into('<3q',port,0x3e,*point)
   parent=bytearray(base.OBJECT);parent[0x86]=1;struct.pack_into('<I',parent,0xa0,1)
   for i in range(3):struct.pack_into('<I',parent,i*16,0x7fffffff)
   rows.append({'mode':'height_query','origin':'Original broad/inner/outer bound branches, not a surface-radius replacement.','parent_model':model,'port_model':84,'parent_index':1,'parent_uid_u32':1,'direction_integer':[1,0,0],'reference_static_radius_raw':str(reference),'sample_outer_factor':factor,'point_input_raw':[str(x)for x in point],'port_object_input_hex':port.hex(),'parent_object_input_hex':parent.hex(),'phase_u16':0,'inclination_u16':0,'graphics_level':1,'initial_globals':{name:0 for name,_,_ in base.GLOBAL_FIELDS}})
 return rows

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_fuel_contact_native.json');a=p.parse_args()
 source_raw=a.source.read_bytes();exe=a.executable.read_bytes();assert base.sha(source_raw)==base.ASM_SHA and base.sha(exe)==base.EXE_SHA
 source=source_raw.decode();data=a.source.with_name('ffedat.asm').read_text();helper=expanded_helper();resources,lines=helper.resources(exe);rows=controls(resources);packets=[helper.packet(row)for row in rows];ordered=packets+list(reversed(packets))
 with tempfile.TemporaryDirectory(prefix='fuel-contact-native-',dir='/tmp')as d:
  work=Path(d);text,hashes,metadata,sine=build(helper,source,data,exe,lines,work);outputs=[]
  for _ in range(3):
   run=subprocess.run([str(work/'reference')],input=b''.join(ordered),cwd=work,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
   if run.returncode:raise ValueError('Original native excluded branch/trap reached: '+str(run.returncode))
   assert len(run.stdout)==len(ordered)*helper.OUTPUT;outputs.append(run.stdout)
  assert outputs[0]==outputs[1]==outputs[2];helper.decode(rows,outputs[0],query=True)
 result={'schema':1,'source_contract':'source-gas-star-f574-f581-readonly-contact-v1','source_sha256':base.EXE_SHA,'asm_sha256':base.ASM_SHA,'original_host_harness_sha256':base.sha((PROJECT/'tools/rebuild_ground_surface_native.py').read_bytes()),'scope':'Actual original F1533 initialization then F574/F575/F576/F579/F582/F581/F1876 gas/star natural geometry using real source descriptors/vertices/styles. Synthetic non-player model84 zero-inner probe; not full player collisions, SI world frames, damage or timer.','case_count':len(rows),'models':list(range(134,149)),'fresh_process_runs':3,'reverse_repeat_count':len(rows),'canaries_unchanged':True,'parent_bank_unchanged':True,'native_output_sha256':base.sha(outputs[0]),'adapted_asm_sha256':base.sha(text.encode()),'source_procedures':hashes,'host_adapter':metadata,'sine_sha256':sine,'cases':rows}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,separators=(',',':'))+'\n');print(json.dumps({k:result[k]for k in ['case_count','models','fresh_process_runs','native_output_sha256']}));return 0
if __name__=='__main__':raise SystemExit(main())
