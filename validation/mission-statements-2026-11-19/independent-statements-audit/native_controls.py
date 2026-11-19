from pathlib import Path
import sys,importlib.util,copy,tempfile,struct,json,hashlib,argparse
sys.path.insert(0,str(Path('tools').resolve()));p=Path('tools/rebuild_source_mission_statements_native.py');sp=importlib.util.spec_from_file_location('audit_statements',p);m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
parser=argparse.ArgumentParser();parser.add_argument('--proof-dir',type=Path,required=True);args=parser.parse_args();proof=args.proof_dir.resolve();meta,source=m.verify(proof);checks=[]
def check(ok,name):
 assert ok,name
 checks.append(name)
def row_for(opcode,values=None):
 payload,answers,stores=m.authored(opcode,values)
 return {'name':'independent-'+str(opcode),'context_before':m.base_context(payload),'scratch':{'seed_hex':bytes((i*17+3)&255 for i in range(156)).hex(),'defined_hex':bytes(156).hex()},'answers':answers,'stores':stores,'scripts':[],'policy':{}}
with tempfile.TemporaryDirectory(prefix='f41-private-audit-')as folder:
 binary,_=m.build(meta,source,folder)
 row=row_for(37);root=bytearray.fromhex(row['context_before']['root']);struct.pack_into('<I',root,0x10a,0xfedcba98);row['context_before']['root']=root.hex();row['policy']={'F314':{'return_u32':0xffffffff}}
 result=m.fill(binary,row);ui=next(o for o in result['observations']if o['kind']=='F314');store=next(o for o in result['observations']if o['kind']=='F37')
 check(len(ui['args'])==11 and ui['args'][9]==0x49aa16 and ui['args'][10]==0xfedcba98,'F314 has11 exact args, empty2-byte resource and arbitrary Root+10a DWORD')
 check(ui['return_u32']==0xffffffff and store['args'][1]==0xffffffff,'Arbitrary highDWORD F314 return reaches F37 without boolean conversion')
 check(ui['input_hex']=='0000' and ui['input_defined_hex']=='0101','F314 empty source resource contains exactly2 defined bytes')
 row=row_for(23);row['policy']={'F345':{'output_hex':bytes(range(48)).hex(),'output_defined_hex':bytes([1]*48).hex()}}
 result=m.fill(binary,row);after=bytes.fromhex(result['scratch_after_hex']);defined=bytes.fromhex(result['scratch_defined_hex']);seed=bytes.fromhex(row['scratch']['seed_hex'])
 check(after[20:68]==bytes(range(48)) and defined[20:68]==bytes([1]*48),'UI provider output mutates exactly its48 caller-visible bytes')
 check(after[:20]==seed[:20] and after[68:]==seed[68:] and defined[:20]==bytes(20) and defined[68:]==bytes(88),'UI output does not claim untouched formatter/outlocal/private bytes')
 row=row_for(36);out=bytes(range(20));mask=bytes(i%2 for i in range(20));row['policy']={'F1344':{'output_hex':out.hex(),'output_defined_hex':mask.hex()}}
 result=m.fill(binary,row);after=bytes.fromhex(result['scratch_after_hex']);defined=bytes.fromhex(result['scratch_defined_hex']);seed=bytes.fromhex(row['scratch']['seed_hex'])
 check(after[:20]==out and defined[:20]==mask and after[20:]==seed[20:] and defined[20:]==bytes(136),'Formatter writes20 bytes and preserves explicit partial definedness only there')
 row=row_for(53,[1,0x89abcdef,42]);out=bytes.fromhex('efbeadde');mask=bytes([1,0,1,0]);row['policy']={'F305':{'output_hex':out.hex(),'output_defined_hex':mask.hex()}}
 result=m.fill(binary,row);after=bytes.fromhex(result['scratch_after_hex']);defined=bytes.fromhex(result['scratch_defined_hex']);seed=bytes.fromhex(row['scratch']['seed_hex'])
 check(after[152:]==out and defined[152:]==mask and after[:152]==seed[:152] and defined[:152]==bytes(152),'Outlocal4 bytes preserve exact output and partial mask; other152 are untouched transport')
 check(all(result['scratch_after_hex'][i*2:i*2+2]==row['scratch']['seed_hex'][i*2:i*2+2] for i in range(68,152)),'84 private scalar-spill bytes remain seed carrier, not measured-stack claim')
print(json.dumps({'checks':len(checks),'failures':0,'controls':checks},indent=2))
