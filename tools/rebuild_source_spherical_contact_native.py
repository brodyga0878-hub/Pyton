#!/usr/bin/env python3
"""Actual uploaded-DOS full F577 spherical classifier instruction controls.

Canonical DOS uses parent+138 in the nonpositive-shift radius branch. Pinned
JJFFE's documented collision-radius edit uses parent+140. Both are statically
compared; only one isolated counterfactual executes JJFFE. No F575/F569 scanner,
contact response, descriptor initialization or reference-frame engine is claimed.
"""
from __future__ import annotations
import argparse,hashlib,importlib.util,json,random,re,struct,subprocess,tempfile
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
COMMIT='7e540341d4e09aa3c92877b87d49e7f2c143ad8d'
HELPERS=[1333,1341,1502,1522,1656,1660]
ADDRESSES={1333:0x44e816,1341:0x44e958,1502:0x452aff,1522:0x453489,1656:0x4599b4,1660:0x459c58}
ALIASES={'FUNC_%06d'%n:v for n,v in ADDRESSES.items()}
ALIASES.update({'DATA_007737':0x50137c,'DATA_007738':0x501380,'DATA_008696':0x633ec8,'DATA_008703':0x633ed4,'DATA_008704':0x633ed8})
INPUT=768;OUTPUT=832;GUARD=0x5350484552453537

def load(name,path):
 sp=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m);return m
C=load('spherical_original_surface_proof',PROJECT/'tools/rebuild_source_surface_contact_native.py');J=C.J

def sha(raw):return hashlib.sha256(raw).hexdigest()
def s32(v):return (int(v)&0x7fffffff)-(int(v)&0x80000000)
def s64(v):return (int(v)&0x7fffffffffffffff)-(int(v)&0x8000000000000000)
def abs64(v):return s64(-v)if v<0 else v

def dos_body(source):
 original=J.block(source,577)
 changed,count=re.subn(r'(?m)^[ \t]*add eax,\[esi\+0x140\][ \t]*$', '\t\tadd eax,[esi+0x138]',original)
 if count!=1:raise ValueError('Unreviewed pinned-JJFFE F577 radius edit')
 return changed,original

def proof(source,exe,exe_path):
 canonical,jjffe=dos_body(source);bodies={n:J.block(source,n)for n in HELPERS};records={};disassembly={}
 expected_rows=C.original_rows(exe_path,0x42804c,end=0x4281b7)
 expected=J.canonical(expected_rows)
 for label,body in [('DOS',canonical),('JJFFE',jjffe)]:
  compiled=J.canonical(J.instructions(C.compile32(body,ALIASES,'FUNC_000577',0x42804c)))
  differences=[{'instruction':i,'dos':a,'pinned_jjffe':b}for i,(a,b)in enumerate(zip(expected,compiled))if a!=b]
  if label=='DOS'and expected!=compiled:raise ValueError('Canonical full F577 does not match DOS '+str(differences))
  if label=='JJFFE'and(len(compiled)!=len(expected)or len(differences)!=1 or differences[0]['dos']!='add eax,dwordptr[esi+0x138]'or differences[0]['pinned_jjffe']!='add eax,dwordptr[esi+0x140]'):raise ValueError('Unreviewed F577 DOS/JJFFE difference '+str(differences))
  if label=='JJFFE':variant={'difference_count':1,'differences':differences,'all_other_instructions_equal':True,'canonical_applied_edit':'Restore documented ADD parent+138 from uploaded DOS; never silently adopt JJFFE+140.'}
 raw=exe[0x18e4c:0x18fb7]
 records['577']={'executable_offset':0x18e4c,'virtual_address':0x42804c,'byte_length':len(raw),'sha256':sha(raw),'instruction_count':len(expected_rows),'normalized_instruction_sha256':sha('\n'.join(expected).encode()),'all_instructions_equal_after_branch_destination_normalization':True}
 disassembly['577']='\n'.join('%08x: %s %s'%r for r in expected_rows)
 image=C.G.Image(exe)
 # Check the actual DOS dispatch pointers rather than assuming neighboring helpers.
 if struct.unpack_from('<I',exe,image.offset(0x50137c,4))[0]!=ADDRESSES[1522]or struct.unpack_from('<I',exe,image.offset(0x501380,4))[0]!=ADDRESSES[1502]:raise ValueError('Original integer square/root dispatch differs')
 for n,body in bodies.items():
  name='FUNC_%06d'%n;compiled=J.instructions(C.compile32(body,ALIASES,name,ADDRESSES[n]));rows=C.original_rows(exe_path,ADDRESSES[n],count=len(compiled))
  if not rows or rows[-1][1]!='ret'or J.canonical(rows)!=J.canonical(compiled):raise ValueError('Required DOS helper differs '+str(n))
  at=image.offset(ADDRESSES[n],1);end=image.offset(rows[-1][0],1)+1;raw=exe[at:end]
  records[str(n)]={'executable_offset':at,'virtual_address':ADDRESSES[n],'byte_length':len(raw),'sha256':sha(raw),'instruction_count':len(rows),'normalized_instruction_sha256':sha('\n'.join(J.canonical(rows)).encode()),'all_instructions_equal_after_branch_destination_normalization':True}
  disassembly[str(n)]='\n'.join('%08x: %s %s'%r for r in rows)
 return canonical,jjffe,bodies,records,variant,disassembly

def native(primary,helpers):
 adapter=load('spherical_host_abi',PROJECT/'recovered-history/ground_harness/tools/native_reference.py')
 primary=primary.replace('add esp,byte -0x10','add esp,-0x40',1)
 # Six by-value DWORDs are contiguous in original x86. The standard host ABI
 # widens argument slots, so preserve a private contiguous copy for F1660.
 for offset in range(0x14,0x2c,4):primary=primary.replace('[ebp+0x%x]'%offset,'[ebp-0x%x]'%(0x40-(offset-0x14)))
 before='''push edi
'''
 initialize='push edi\n'+''.join('mov eax,[ebp+0x%x]\nmov [ebp-0x%x],eax\n'%(offset,0x40-(offset-0x14))for offset in range(0x14,0x2c,4))
 primary=primary.replace(before,initialize,1)
 # MOV-only observations retain original registers and flags. Return EAX is
 # captured before reading scratch state, then restored for the caller.
 observation='''JUMP_002453:
mov [output],eax
mov [output+12],ebx
mov eax,[ebp-0x8]
mov [output+16],eax
mov eax,[ebp-0x40]
mov [output+40],eax
mov eax,[ebp-0x3c]
mov [output+44],eax
mov eax,[ebp-0x38]
mov [output+48],eax
mov eax,[ebp-0x34]
mov [output+52],eax
mov eax,[ebp-0x30]
mov [output+56],eax
mov eax,[ebp-0x2c]
mov [output+60],eax
mov eax,[output]
'''
 primary=primary.replace('JUMP_002453:',observation.rstrip(),1)
 source='\n'.join(helpers.values())+'\n'+primary+'\nFUNC_999999:\nret\n'
 source=re.sub(r'FUNC_(\d{6})_[A-Za-z0-9_]+',r'FUNC_\1',source)
 source=re.sub(r'add esp,0x([89a-f][0-9a-f]{7})',lambda m:'add esp,-0x%x'%(0x100000000-int(m[1],16)),source)
 lines,_=adapter.procedures(source,HELPERS+[577]);text='\n'.join(lines)
 text+='''
.global _start
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 lea rsi,[input+r8]
 mov edx,768
 sub edx,r8d
 syscall
 test eax,eax
 jz finished
 js failed
 add r8d,eax
 cmp r8d,768
 jb read_more
 mov rax,0x5350484552453537
'''
 guards=[stem+'_'+side for stem in ['object','parent','relative','absolute','output']for side in ['before','after']]
 text+=''.join(' mov QWORD PTR [%s],rax\n'%name for name in guards)
 text+='''
 mov esi,OFFSET FLAT:input+64
 mov edi,OFFSET FLAT:object
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:parent
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:input+16
 mov edi,OFFSET FLAT:relative
 mov ecx,24
 rep movsb
 mov edi,OFFSET FLAT:absolute
 mov ecx,24
 rep movsb
 mov eax,DWORD PTR [input+4]
 mov BYTE PTR [DATA_008696],al
 mov eax,DWORD PTR [input+8]
 mov DWORD PTR [DATA_008703],eax
 mov eax,DWORD PTR [input+12]
 mov DWORD PTR [DATA_008704],eax
 mov edi,OFFSET FLAT:output
 xor eax,eax
 mov ecx,832
 rep stosb
 mov DWORD PTR [iteration],0
run_repeat:
 push OFFSET FLAT:absolute
 # The original by-value6DWORD argument values live in expanded host slots.
 mov eax,DWORD PTR [relative+20]
 push rax
 mov eax,DWORD PTR [relative+16]
 push rax
 mov eax,DWORD PTR [relative+12]
 push rax
 mov eax,DWORD PTR [relative+8]
 push rax
 mov eax,DWORD PTR [relative+4]
 push rax
 mov eax,DWORD PTR [relative]
 push rax
 push OFFSET FLAT:parent
 push OFFSET FLAT:object
 push OFFSET FLAT:distance_squared
 call FUNC_000577
 add rsp,80
 inc DWORD PTR [iteration]
 mov eax,DWORD PTR [iteration]
 cmp eax,DWORD PTR [input]
 jb run_repeat
 mov DWORD PTR [output+8],eax
 mov eax,DWORD PTR [distance_squared]
 mov DWORD PTR [output+4],eax
 # Original F1522 is executed again solely for diagnostic radius squared.
 mov eax,DWORD PTR [output+16]
 push rax
 call FUNC_001522
 add rsp,8
 mov DWORD PTR [output+20],eax
 movzx eax,BYTE PTR [DATA_008696]
 mov DWORD PTR [output+24],eax
 mov eax,DWORD PTR [DATA_008703]
 mov DWORD PTR [output+28],eax
 mov eax,DWORD PTR [DATA_008704]
 mov DWORD PTR [output+32],eax
 mov DWORD PTR [output+36],0x577363
 mov esi,OFFSET FLAT:object
 mov edi,OFFSET FLAT:output+64
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:parent
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:relative
 mov ecx,24
 rep movsb
 mov esi,OFFSET FLAT:absolute
 mov ecx,24
 rep movsb
 mov rax,0x5350484552453537
 mov QWORD PTR [output+816],rax
 mov QWORD PTR [output+824],rax
'''
 text+=''.join(' cmp QWORD PTR [%s],rax\n jne failed\n'%name for name in guards)
 text+='''
 xor r8d,r8d
write_more:
 mov eax,1
 mov edi,1
 lea rsi,[output+r8]
 mov edx,832
 sub edx,r8d
 syscall
 test eax,eax
 jle failed
 add r8d,eax
 cmp r8d,832
 jb write_more
 jmp next_case
finished:
 mov eax,60
 xor edi,edi
 syscall
failed:
 mov eax,60
 mov edi,94
 syscall
.section .data
.align 8
DATA_007737: .quad FUNC_001522
DATA_007738: .quad FUNC_001502
.section .bss
.align 8
input: .zero 768
iteration: .zero 4
distance_squared: .zero 4
DATA_008696: .zero 1
DATA_008703: .zero 4
DATA_008704: .zero 4
'''
 for stem,size in [('object',338),('parent',338),('relative',24),('absolute',24),('output',OUTPUT)]:text+=f'{stem}_before: .zero 8\n{stem}: .zero {size}\n{stem}_after: .zero 8\n'
 text+='''
.align 16
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
'''
 return '.intel_syntax noprefix\n.code64\n.section .text\n'+text

def model_resources(exe):
 image=C.G.Image(exe);result={}
 for model in [15,24,38,81,96,117,118,134]:
  at=image.pointer(0xba8fc+model*4,68);descriptor=exe[at:at+68];exponent=struct.unpack_from('<I',descriptor,20)[0]+struct.unpack_from('<I',descriptor,24)[0]-8
  values=[struct.unpack_from('<h',descriptor,offset)[0]for offset in [44,48]]
  bounds=[s64(value<<exponent)if exponent>=0 else value>>-exponent for value in values]
  result[str(model)]={'descriptor_file_offset':at,'descriptor_hex':descriptor.hex(),'descriptor_sha256':sha(descriptor),'bounds_input_derivation':'Source F1533 radius16/exponent input formula only; full initialization not executed by this classifier oracle.','scale_exponent':exponent,'outer_bound_s64_hex':struct.pack('<q',bounds[0]).hex(),'inner_bound_s64_hex':struct.pack('<q',bounds[1]).hex()}
 return result

def cases(models):
 rows=[]
 def add(domain='raw_operand_control',body_outer=50,body_inner=10,parent_outer=100,parent_inner=20,relative=None,absolute=None,flags=0,altitude=123456789,repeat=1,body_model=38,parent_model=117):
  point=relative if relative is not None else [60,0,0];abs_point=absolute if absolute is not None else [abs64(value)for value in point]
  body=bytearray((i*43+7)&255 for i in range(338));parent=bytearray((i*59+11)&255 for i in range(338))
  struct.pack_into('<I',body,0x82,body_model);struct.pack_into('<I',parent,0x82,parent_model)
  struct.pack_into('<q',body,0x138,body_outer);struct.pack_into('<q',body,0x140,body_inner);struct.pack_into('<q',parent,0x138,parent_outer);struct.pack_into('<q',parent,0x140,parent_inner)
  context={'relative_position_s64':point,'relative_position_s64_hex':struct.pack('<3q',*point).hex(),'absolute_position_s64':abs_point,'absolute_position_s64_hex':struct.pack('<3q',*abs_point).hex(),'globals':{'collision_flags_u8':flags,'altitude_s64':altitude,'altitude_s64_hex':struct.pack('<q',altitude).hex()}}
  rows.append({'operation':'F577','input_domain':domain,'absolute_input_policy':'caller-consistent-F1664-absolute-invariant'if absolute is None else'independent-raw-pointer-operand','body_hex':body.hex(),'parent_hex':parent.hex(),'context':context,'repeat_count':repeat})
 # DOS/JJFFE discriminator is independently hand-derived and locked below.
 add(domain='dos_vs_jjffe_radius_canary')
 for radius in [0,1,2,3,10,100,32767,65535,0x1fffffff,0x20000000,0x3fffffff,0x40000000,0x7fffffff,0x80000000,0xffffffff]:
  for distance in sorted({0,1,max(0,radius-1),radius,radius+1}):
   for sign in [-1,1]:add(domain='radius_distance_equality_unsigned',body_inner=0,parent_outer=radius,parent_inner=radius,relative=[sign*distance,0,0])
 for magnitude in [0,1,1<<28,(1<<29)-1,1<<29,(1<<30)-1,1<<30,(1<<31)-1,1<<31,(1<<32)-1,1<<32,(1<<33)-1,1<<33,1<<40,(1<<62)-1,1<<62,(1<<63)-1]:
  for axis in range(3):
   for sign in [-1,1]:
    point=[0,0,0];point[axis]=sign*magnitude
    add(domain='both_scaling_branches_signed64',relative=point,body_outer=200,parent_outer=1<<32,parent_inner=123)
 for outer in [0,1,0xffffffff,1<<32,(1<<32)+1,(1<<63)-1,-1,-(1<<63)]:
  for inner in [0,1,10,-1,0x7fffffff,0x80000000]:
   add(domain='positive_shift_radius64_wrap',body_outer=outer,body_inner=inner,parent_outer=outer,parent_inner=inner,relative=[1<<40,-(1<<42),1<<43])
 for point in [[-1,-1,-1],[-(1<<63),0,0],[-(1<<63),-(1<<63),-(1<<63)],[(1<<63)-1,(1<<63)-1,(1<<63)-1],[-4294967297,4294967297,-2147483649],[0,0,0]]:
  for absolute in [[0,0,0],[1,1,1],[-1,-1,-1],[-(1<<63),0,0],[(1<<63)-1,0,0]]:
   add(domain='independent_abs_pointer_raw_operand',relative=point,absolute=absolute)
 for body_model in [15,24,38]:
  for parent_model in [15,24,38,81,96,117,118,134]:
   b=models[str(body_model)];p=models[str(parent_model)];bo=struct.unpack('<q',bytes.fromhex(b['outer_bound_s64_hex']))[0];bi=struct.unpack('<q',bytes.fromhex(b['inner_bound_s64_hex']))[0];po=struct.unpack('<q',bytes.fromhex(p['outer_bound_s64_hex']))[0];pi=struct.unpack('<q',bytes.fromhex(p['inner_bound_s64_hex']))[0]
   for distance in sorted({0,1,max(0,bi+po-1),bi+po,bi+po+1,bo+po,2*(bo+po)}):
    add(domain='actual_source_model_bounds_inputs',body_model=body_model,parent_model=parent_model,body_outer=bo,body_inner=bi,parent_outer=po,parent_inner=pi,relative=[distance,0,0])
 for flags in [0,1,2,3,0x40,0x80,255]:
  for altitude in [0,1,-1,0x7fffffff,0x80000000,0xffffffff,1<<32,-(1<<63),(1<<63)-1]:
   for inside in [False,True]:add(domain='globals_preservation_and_overwrite',relative=[60 if inside else 200,0,0],flags=flags,altitude=altitude)
 for repeat in [2,3,8]:
  for relative in [[60,0,0],[200,0,0],[-1,0,0],[1<<40,1<<42,-(1<<45)]]:add(domain='repeat_same_raw_context',relative=relative,repeat=repeat)
 add(domain='literal_int32_min_square',relative=[256,0,0],absolute=[0,0,0])
 add(domain='literal_left_highword_preservation',relative=[(1<<32)+1,0,0],absolute=[0,0,0])
 add(domain='literal_positive_branch_outer_radius',body_outer=1<<40,body_inner=10,parent_outer=1<<40,parent_inner=20,relative=[1<<40,0,0])
 add(domain='literal_positive_branch_ignores_inner_radius',body_outer=1<<40,body_inner=1000000,parent_outer=1<<40,parent_inner=9000000,relative=[1<<40,0,0])
 rng=random.Random(0x57720)
 for _ in range(512):
  point=[s64(rng.getrandbits(64))for _ in range(3)]
  add(domain='seeded_full_raw64',relative=point,absolute=[s64(rng.getrandbits(64))for _ in range(3)]if rng.getrandbits(1)else None,body_outer=s64(rng.getrandbits(64)),body_inner=s64(rng.getrandbits(64)),parent_outer=s64(rng.getrandbits(64)),parent_inner=s64(rng.getrandbits(64)),flags=rng.randrange(256),altitude=s64(rng.getrandbits(64)))
 return rows

def pack(row):
 c=row['context'];g=c['globals'];out=bytearray(INPUT);struct.pack_into('<2I',out,0,row['repeat_count'],g['collision_flags_u8']);out[8:16]=bytes.fromhex(g['altitude_s64_hex']);out[16:40]=bytes.fromhex(c['relative_position_s64_hex']);out[40:64]=bytes.fromhex(c['absolute_position_s64_hex']);out[64:402]=bytes.fromhex(row['body_hex']);out[402:740]=bytes.fromhex(row['parent_hex']);return bytes(out)

def parse(row,raw):
 if len(raw)!=OUTPUT or struct.unpack_from('<2Q',raw,816)!=(GUARD,GUARD):raise ValueError('Native classifier canaries')
 if struct.unpack_from('<I',raw,36)[0]!=0x577363:raise ValueError('Native classifier sentinel')
 body=raw[64:402];parent=raw[402:740];relative=raw[740:764];absolute=raw[764:788];c=row['context']
 if body.hex()!=row['body_hex']or parent.hex()!=row['parent_hex']or relative.hex()!=c['relative_position_s64_hex']or absolute.hex()!=c['absolute_position_s64_hex']:raise ValueError('Read-only F577 input buffer changed')
 result=s32(struct.unpack_from('<I',raw,0)[0])
 return {'return_s32':result,'inside_sphere':result==0,'distance_squared_s32':s32(struct.unpack_from('<I',raw,4)[0]),'globals':{'collision_flags_u8':struct.unpack_from('<I',raw,24)[0],'altitude_s64_hex':raw[28:36].hex()},'body_hex':body.hex(),'parent_hex':parent.hex(),'relative_position_s64_hex':relative.hex(),'absolute_position_s64_hex':absolute.hex(),'shift_s32':s32(struct.unpack_from('<I',raw,12)[0]),'radius_s32':s32(struct.unpack_from('<I',raw,16)[0]),'radius_squared_s32':s32(struct.unpack_from('<I',raw,20)[0]),'scaled_position_s64_hex':raw[40:64].hex(),'repeat_count':struct.unpack_from('<I',raw,8)[0]}

def execute(assembly,rows):
 with tempfile.TemporaryDirectory(prefix='spherical-contact-native-')as d:
  p=Path(d);(p/'native.s').write_text(assembly)
  r=subprocess.run(['as','--64',str(p/'native.s'),'-o',str(p/'native.o')],capture_output=True,text=True)
  if r.returncode:raise ValueError(r.stderr)
  subprocess.run(['ld','-m','elf_x86_64',str(p/'native.o'),'-o',str(p/'native')],capture_output=True,check=True)
  payload=b''.join(pack(row)for row in rows);runs=[]
  for _ in range(3):
   r=subprocess.run([str(p/'native')],input=payload,capture_output=True,timeout=30)
   if r.returncode or len(r.stdout)!=len(rows)*OUTPUT:raise ValueError('Native F577 execution '+str((r.returncode,len(r.stdout),len(rows)*OUTPUT)))
   runs.append(r.stdout)
  if len(set(runs))!=1:raise ValueError('Fresh F577 process mismatch')
  r=subprocess.run([str(p/'native')],input=b''.join(pack(row)for row in reversed(rows)),capture_output=True,timeout=30)
  if r.returncode or r.stdout!=b''.join(runs[0][i*OUTPUT:(i+1)*OUTPUT]for i in range(len(rows)-1,-1,-1)):raise ValueError('F577 reverse case-order contamination')
 return [parse(row,runs[0][i*OUTPUT:(i+1)*OUTPUT])for i,row in enumerate(rows)]

def literal_controls(rows,counterfactual):
 result=[]
 def check(name,row,observe,literal):
  actual=observe(row['expected'])
  if actual!=literal:raise ValueError('F577 independent literal control failed '+name+str((actual,literal)))
  result.append({'name':name,'case_id':row['id'],'literal_expected':literal,'observed':actual,'passed':True})
 discriminator=rows[0]
 check('DOS-parent-outer110-inside60',discriminator,lambda e:[e['return_s32'],e['shift_s32'],e['radius_s32'],e['globals']],[0,-23,110<<23,{'collision_flags_u8':0,'altitude_s64_hex':struct.pack('<q',123456789).hex()}])
 check('JJFFE-parent-inner30-outside60',counterfactual,lambda e:[e['return_s32'],e['radius_s32']],[-1,30<<23])
 def unique(predicate):
  found=[row for row in rows if predicate(row)]
  if len(found)!=1:raise ValueError('Literal input selection ambiguous')
  return found[0]
 equal=unique(lambda r:r['input_domain']=='radius_distance_equality_unsigned'and r['context']['relative_position_s64']==[100,0,0]and struct.unpack_from('<q',bytes.fromhex(r['parent_hex']),0x138)[0]==100)
 check('radius-equality-is-outside',equal,lambda e:[e['return_s32'],e['globals']['collision_flags_u8']],[-1,2])
 negative=unique(lambda r:r['input_domain']=='independent_abs_pointer_raw_operand'and r['context']['relative_position_s64']==[-1,-1,-1]and r['context']['absolute_position_s64']==[0,0,0])
 check('left-shift-keeps-highwords',negative,lambda e:e['scaled_position_s64_hex'],struct.pack('<3q',-(1<<23),-(1<<23),-(1<<23)).hex())
 square=unique(lambda r:r['input_domain']=='literal_int32_min_square')
 check('signed-INT32-MIN-square-highword',square,lambda e:[e['distance_squared_s32'],e['scaled_position_s64_hex']],[0x40000000,struct.pack('<3q',0x80000000,0,0).hex()])
 highword=unique(lambda r:r['input_domain']=='literal_left_highword_preservation')
 check('left-shift-does-not-propagate-lowword-carry',highword,lambda e:e['scaled_position_s64_hex'],struct.pack('<3q',(1<<32)+(1<<23),0,0).hex())
 for domain in ['literal_positive_branch_outer_radius','literal_positive_branch_ignores_inner_radius']:
  row=unique(lambda r:r['input_domain']==domain)
  check(domain,row,lambda e:[e['shift_s32'],e['radius_s32'],e['return_s32']],[11,1<<30,0])
 shifts={r['expected']['shift_s32']for r in rows}
 if not {-29,0,1,31,32,34}<=shifts:raise ValueError('Required F577 shift domains absent')
 return result

def main():
 p=argparse.ArgumentParser();p.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_spherical_contact_native.json');p.add_argument('--validation-dir',type=Path,default=PROJECT/'validation/spherical-2026-11-08/nativeproof');args=p.parse_args()
 source=args.source.read_text();exe=args.executable.read_bytes()
 if sha(exe)!=EXE_SHA or sha(args.source.read_bytes())!=ASM_SHA:raise ValueError('Unreviewed original F577 reference')
 primary,jjffe,helpers,proofs,variant,disassembly=proof(source,exe,args.executable);models=model_resources(exe);assembly=native(primary,helpers);rows=cases(models);outputs=execute(assembly,rows)
 for i,(row,result)in enumerate(zip(rows,outputs)):row['id']='dos-spherical-contact-%04d'%i;row['expected']=result
 counterfactual=json.loads(json.dumps(rows[0]));counterfactual['id']='jjffe-counterfactual-radius-only';counterfactual['expected']=execute(native(jjffe,helpers),[counterfactual])[0]
 controls=literal_controls(rows,counterfactual)
 doc={'schema_version':1,'reference':'uploaded DOS FIRSTENC.EXE','executable_sha256':EXE_SHA,'pinned_asm_sha256':ASM_SHA,'source_commit':COMMIT,'case_count':len(rows),'byte_instruction_proofs':proofs,'known_jjffe_variant':variant,'jjffe_counterfactual_case':counterfactual,'independent_literal_controls':controls,'models':models,'observed_shift_s32_values':sorted({r['expected']['shift_s32']for r in rows}),'execution_checks':{'fresh_identical_processes':3,'reverse_case_order_identical':True,'object_parent_relative_absolute_output_canaries':True,'all_input_buffers_unchanged':True,'expected_transitions_computed_by_python':False},'host_abi_adaptation':{'by_value_relative_six_dwords':'Copied from expanded host argument slots into a private contiguous24B stack shadow. All original F577 relative accesses and F1660 pointer use that same shadow. Source arithmetic unchanged.','observers':'MOV-only output captures retain all original registers/flags; no synthetic square/root callback.'},'scope':['Complete actual-DOS F577 plus all six required integer helpers.','Object bounds and separate relative/absolute vectors are explicit raw inputs. Caller-consistent cases handcraft the F1664 two-complement absolute invariant; this tool does not execute F1664.','Actual source descriptor bounds are fixture input construction only; no whole F1533 initialization or complete model collision-engine claim.','No F569/F575/F576/F578 scanner/contact response, damage, frame selection or SI bridge executes.','Return0 is inside sphere; return−1 is outside/equality. F577 does not publish collisionkind/previousheight.','ExactLEhex carries64-bit inputs/outputs; JSON decimal previews must not be used as lossy machine inputs.'],'invalid_domains_not_executed':['Malformed raw338 objects or missing3×s64 vectors; invalid initialflags/altitude field domains.'],'cases':rows}
 args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(doc,indent=2)+'\n');args.validation_dir.mkdir(parents=True,exist_ok=True)
 report={k:v for k,v in doc.items()if k!='cases'};report.update(fixture_sha256=sha(args.output.read_bytes()),tool_sha256=sha(Path(__file__).read_bytes()),native_assembly_sha256=sha(assembly.encode()))
 (args.validation_dir/'source-spherical-contact-native-proof.json').write_text(json.dumps(report,indent=2)+'\n');(args.validation_dir/'dos-source-spherical-contact-disassembly.txt').write_text('\n\n'.join('F'+name+'\n'+text for name,text in disassembly.items()))
 print(json.dumps({'cases':len(rows),'fixture_sha256':report['fixture_sha256'],'primary_bytes':proofs['577']['byte_length'],'primary_instructions':proofs['577']['instruction_count'],'proofs':len(proofs),'fresh_runs':3,'reverse_order':True,'JJFFE_counterfactual_cases':1}))
 build_pipeline(args,source,exe,primary,helpers,proofs)

def pipeline_proof(source,exe,exe_path,primary_proofs):
 old_helpers,old_fragment,aliases,old_proofs,_=C.proof(source,exe,exe_path)
 aliases.update(ALIASES);aliases.update({'FUNC_000576':0x427e78,'FUNC_000577':0x42804c,'FUNC_000578':0x4281b8,'FUNC_001664':0x459e1c})
 extra={n:J.block(source,n)for n in [1332,1341,1664]};image=C.G.Image(exe);records=dict(old_proofs)
 source1664=extra[1664];aliases['FUNC_001332']=0;aliases['DATA_007635']=0;aliases['DATA_007636']=0
 test_rows=J.instructions(C.compile32(source1664,aliases,'FUNC_001664',0x459e1c));actual=C.original_rows(exe_path,0x459e1c,count=len(test_rows))
 calls=[args for _,op,args in actual if op=='call'];targets={int(re.search(r'0x([0-9a-f]+)',value)[1],16)for value in calls}
 if len(targets)!=1:raise ValueError('Original F1664 abs callee differs')
 aliases['FUNC_001332']=next(iter(targets))
 n=1332;compiled=J.instructions(C.compile32(extra[n],aliases,'FUNC_001332',aliases['FUNC_001332']));actual=C.original_rows(exe_path,aliases['FUNC_001332'],count=len(compiled))
 pushes=[int(re.search(r'ds:0x([0-9a-f]+)',args)[1],16)for _,op,args in actual if op=='push'and'ds:0x'in args]
 if len(pushes)!=2:raise ValueError('Original abs zero64 operands differ')
 aliases['DATA_007636'],aliases['DATA_007635']=pushes
 constants={key:{'virtual_address':aliases[key],'hex':exe[image.offset(aliases[key],4):image.offset(aliases[key],4)+4].hex()}for key in ['DATA_007635','DATA_007636']}
 if any(value['hex']!='00000000'for value in constants.values()):raise ValueError('Original F1332 zero64 globals differ')
 for n in [1332,1341,1664]:
  name='FUNC_%06d'%n;at=aliases[name];compiled=J.instructions(C.compile32(extra[n],aliases,name,at));actual=C.original_rows(exe_path,at,count=len(compiled))
  if actual[-1][1]!='ret'or J.canonical(actual)!=J.canonical(compiled):raise ValueError('Required full-chain helper differs '+str(n))
  start=image.offset(at,1);end=image.offset(actual[-1][0],1)+1;raw=exe[start:end]
  records[str(n)]={'executable_offset':start,'virtual_address':at,'byte_length':len(raw),'sha256':sha(raw),'instruction_count':len(actual),'normalized_instruction_sha256':sha('\n'.join(J.canonical(actual)).encode()),'all_instructions_equal_after_branch_destination_normalization':True}
 aliases.pop('JUMP_002432',None)
 full=J.block(source,575);actual=C.original_rows(exe_path,0x4276a0,end=0x427e75);compiled=J.instructions(C.compile32(full,aliases,'FUNC_000575',0x4276a0))
 if J.canonical(actual)!=J.canonical(compiled):raise ValueError('Full original F575 instruction proof differs '+str([(i,a,b)for i,(a,b)in enumerate(zip(J.canonical(actual),J.canonical(compiled)))if a!=b][:10]))
 records.pop('575_postclassification');raw=exe[0x184a0:0x18c75]
 records['575']={'executable_offset':0x184a0,'virtual_address':0x4276a0,'byte_length':len(raw),'sha256':sha(raw),'instruction_count':len(actual),'normalized_instruction_sha256':sha('\n'.join(J.canonical(actual)).encode()),'all_instructions_equal_after_branch_destination_normalization':True,'executed_domain':'Canonical player, coarse test and simple-parent F577 continuation only; F576/F578 are forbidden host guards.'}
 records['577']=primary_proofs['577']
 return old_helpers,old_fragment,extra,full,records,constants

def pipeline_native(old_helpers,old_fragment,extra,full,primary,helpers):
 base=C.native(old_helpers,old_fragment)
 start=base.index('FUNC_900575:\n');end=base.index('FUNC_900997:\n',start);base=base[:start]+base[end:]
 # Reuse actual original F577's contiguous private argument shadow, dropping
 # standalone diagnostic observers which share the pipeline output header.
 entire=native(primary,helpers);start=entire.index('FUNC_000577:\n');end=entire.index('.global _start',start);classifier=entire[start:end]
 classifier=re.sub(r'JUMP_002453:\n.*?(?=pop rdi\n)','JUMP_002453:\n',classifier,flags=re.S)
 classifier=classifier.replace('FUNC_000577:\n','''FUNC_000577:
 pushfq
 push rax
 mov eax,DWORD PTR [output+88]
 lea eax,[eax+1]
 mov DWORD PTR [output+88],eax
 mov DWORD PTR [output+92],1
 pop rax
 popfq
''',1)
 full=full.replace('mov [ebp-0x10],esi','mov [ebp-0x10],esi\nmov [output+32],esi',1)
 full=full.replace('or byte [DATA_008696],0x40','or byte [DATA_008696],0x40\nmov dword [output+40],1',1)
 full=full.replace('JUMP_002410:','JUMP_002410:\nmov dword [output+92],2',1)
 source='\n'.join(extra.values())+'\n'+full+'\nFUNC_999999:\nret\n';source=re.sub(r'FUNC_(\d{6})_[A-Za-z0-9_]+',r'FUNC_\1',source)
 source=re.sub(r'add esp,0x([89a-f][0-9a-f]{7})',lambda m:'add esp,-0x%x'%(0x100000000-int(m[1],16)),source)
 source=re.sub(r'\[ebp\+0x([89a-f][0-9a-f]{7})\]',lambda m:'[ebp-0x%x]'%(0x100000000-int(m[1],16)),source)
 adapter=load('spherical_pipeline_host_abi',PROJECT/'recovered-history/ground_harness/tools/native_reference.py');lines,_=adapter.procedures(source,[1332,1341,1664,575]);procedures='\n'.join(lines).replace('call _abs','call FUNC_900997')
 base=base.replace('.global _start',procedures+'\n'+classifier+'\n.global _start',1)
 base=base.replace(' mov DWORD PTR [iteration],0',''' mov eax,DWORD PTR [input+48]
 mov DWORD PTR [DATA_008703],eax
 mov eax,DWORD PTR [input+52]
 mov DWORD PTR [DATA_008704],eax
 mov DWORD PTR [iteration],0''',1)
 old=''' mov DWORD PTR [output+40],0
 call FUNC_900575'''
 new=''' mov DWORD PTR [output+40],0
 mov DWORD PTR [output+92],0
 mov QWORD PTR [pipe_stack],rsp
 mov QWORD PTR [pipe_rbp],rbp
 mov QWORD PTR [pipe_rbx],rbx
 mov QWORD PTR [pipe_rsi],rsi
 mov QWORD PTR [pipe_rdi],rdi
 # Repeated source calls share the same mutable candidate vector. F1664
 # replaces its first contents with abs; later invocations consume that abs.
 push OFFSET FLAT:parent
 push OFFSET FLAT:object
 push OFFSET FLAT:relative
 call FUNC_000575
 add rsp,24
PIPE_after_call:
 movzx eax,al
 mov DWORD PTR [output],eax'''
 if old not in base:raise ValueError('Frozen source response host wrapper changed')
 base=base.replace(old,new,1)
 base=base.replace(' mov DWORD PTR [output+12],0x5752410',''' mov DWORD PTR [output+12],0x5752410
 mov eax,DWORD PTR [DATA_008703]
 mov DWORD PTR [output+80],eax
 mov eax,DWORD PTR [DATA_008704]
 mov DWORD PTR [output+84],eax''',1)
 base+='''
.section .text
FUNC_000576:
 mov DWORD PTR [output+96],576
 jmp PIPE_unsupported
FUNC_000578:
 mov DWORD PTR [output+96],578
PIPE_unsupported:
 mov rsp,QWORD PTR [pipe_stack]
 mov rbp,QWORD PTR [pipe_rbp]
 mov rbx,QWORD PTR [pipe_rbx]
 mov rsi,QWORD PTR [pipe_rsi]
 mov rdi,QWORD PTR [pipe_rdi]
 xor eax,eax
 jmp PIPE_after_call
.section .data
DATA_007635: .long 0
DATA_007636: .long 0
.section .bss
.align 8
DATA_008703: .zero 4
DATA_008704: .zero 4
pipe_stack: .zero 8
pipe_rbp: .zero 8
pipe_rbx: .zero 8
pipe_rsi: .zero 8
pipe_rdi: .zero 8
'''
 return base

def pipeline_models(exe):
 models=C.resources(exe);image=C.G.Image(exe)
 for model in list(range(4,14))+[101]:
  at=image.pointer(0xba8fc+model*4,68);raw=exe[at:at+68];pointer=struct.unpack_from('<I',raw,52)[0];first=exe[image.offset(pointer,1)]if pointer else 0
  if first!=0:raise ValueError('Requested simple source model has collision stream')
  models[str(model)]={'model_index':model,'descriptor_file_offset':at,'descriptor_hex':raw.hex(),'descriptor_sha256':sha(raw),'spec_hex':bytes(24).hex(),'simple_collision_prefix_u8':first,'spec_file_offset':None,'spec_sha256':sha(bytes(24)),'actual_source_spec_pointer_u32':struct.unpack_from('<I',raw,56)[0]}
 return models

def pipeline_cases(models):
 rows=[];q=0x7fffffff
 def bounds(model):
  d=bytes.fromhex(models[str(model)]['descriptor_hex']);e=struct.unpack_from('<I',d,20)[0]+struct.unpack_from('<I',d,24)[0]-8
  return [s64(struct.unpack_from('<h',d,o)[0]<<e)if e>=0 else struct.unpack_from('<h',d,o)[0]>>-e for o in [44,48]]
 def add(body_model=38,parent_model=4,branch='inside',gear=65535,velocity=None,up=None,flags=0,enabled=1,selected_parent=True,complex_parent=False,repeat=1):
  bo,bi=bounds(body_model);po,pi=bounds(parent_model);radius=bi+po
  distance=3*(bo+po)if branch=='coarse'else(radius if branch=='equal'else(radius+maxi(2,radius//2)if branch=='outside'else max(1,radius//2)))
  row={'operation':'F575_simple_parent_pipeline','domain':'actual_simple_parent_'+branch,'repeat_count':repeat}
  body=bytearray((i*43+7)&255 for i in range(338));parent=bytearray((i*59+11)&255 for i in range(338))
  struct.pack_into('<9i',body,0,q,0,0,*(up or [0,q,0]),0,0,q);struct.pack_into('<I',body,0x82,body_model);body[0x86]=17;body[0x87]=3;body[0x56]=9 if selected_parent else 7
  struct.pack_into('<H',body,0x9e,gear);struct.pack_into('<3i',body,0x8c,*(velocity or [0,0,0]));struct.pack_into('<3q',body,0x3e,100000,-200000,300000);struct.pack_into('<q',body,0x138,bo);struct.pack_into('<q',body,0x140,bi)
  struct.pack_into('<9i',parent,0,q,0,0,0,q,0,0,0,q);struct.pack_into('<I',parent,0x82,parent_model);parent[0x86]=9;parent[0x14c]=0x86 if complex_parent else 6;struct.pack_into('<q',parent,0x138,po);struct.pack_into('<q',parent,0x140,pi)
  point=[0,distance,0]
  globals={'collision_flags_u8':flags,'collider_index_u8':0,'collision_active_u8':0,'collision_enabled_u8':enabled,'previous_altitude_s64':123,'previous_altitude_s64_hex':struct.pack('<q',123).hex(),'collision_kind_u8':7,'player_object_index_u32':17,'collider_parent_selected':False,'altitude_s64':987654321,'altitude_s64_hex':struct.pack('<q',987654321).hex()}
  context={'relative_position_s64':point,'relative_position_s64_hex':struct.pack('<3q',*point).hex(),'distance_squared_s32':0,'globals':globals,'body_descriptor_hex':models[str(body_model)]['descriptor_hex'],'parent_descriptor_hex':models[str(parent_model)]['descriptor_hex'],'body_spec_hex':models[str(body_model)]['spec_hex']}
  row.update(body_hex=body.hex(),parent_hex=parent.hex(),context=context)
  if complex_parent:row['domain']='forbidden_hierarchical_parent_guard'
  if not selected_parent and branch=='inside':row['domain']='forbidden_nonparent_overlap_guard'
  rows.append(row)
 # All positive radii in this fixture originate in immutable source descriptors.
 for body in [15,24,38]:
  for parent in [4,5,6,7,8,9,10,11,12,13,101]:
   for branch in ['coarse','outside','equal','inside']:add(body,parent,branch)
   add(body,parent,'inside',gear=0,velocity=[0,-600,0])
   add(body,parent,'inside',gear=65535,velocity=[601,0,0])
 for parent in [4,5,101]:
  add(parent_model=parent,complex_parent=True)
  add(parent_model=parent,selected_parent=False)
  add(parent_model=parent,branch='outside',selected_parent=False)
  add(parent_model=parent,branch='coarse',complex_parent=True)
 for repeat in [2,3,8]:add(parent_model=101,gear=0,velocity=[7,-9,3],repeat=repeat)
 return rows

def maxi(a,b):return max(a,b)

def pipeline_pack(row):
 result=bytearray(C.pack(row));result[48:56]=bytes.fromhex(row['context']['globals']['altitude_s64_hex']);return bytes(result)

def pipeline_parse(row,raw):
 if len(raw)!=C.OUTPUT or struct.unpack_from('<2Q',raw,3088)!=(C.GUARD,C.GUARD):raise ValueError('Whole-chain output canary')
 if struct.unpack_from('<I',raw,12)[0]!=0x5752410:raise ValueError('Whole-chain sentinel')
 body=raw[128:466];parent=raw[466:804];absolute=raw[804:828];g=row['context']['globals'];before=pipeline_pack(row)
 if parent.hex()!=row['parent_hex']:raise ValueError('F575 player route changed parent')
 if raw[828:896]!=before[804:872]or raw[896:964]!=before[872:940]or raw[964:988]!=before[940:964]:raise ValueError('Whole-chain descriptor/spec mutation')
 allowed=set(range(36))|set(range(0x3e,0x56))|set(range(0x8c,0x98))
 if any(a!=b and i not in allowed for i,(a,b)in enumerate(zip(bytes.fromhex(row['body_hex']),body))):raise ValueError('Whole-chain unrelated body mutation')
 words=struct.unpack_from('<25I',raw);unsupported=words[24];stage=words[23];calls=words[22]
 globals_after={'collision_flags_u8':words[11],'collider_index_u8':words[12],'collision_active_u8':words[13],'collision_enabled_u8':words[14],'previous_altitude_s64':struct.unpack_from('<q',raw,68)[0],'previous_altitude_s64_hex':raw[68:76].hex(),'collision_kind_u8':words[15],'player_object_index_u32':words[16],'collider_parent_selected':bool(words[19]),'altitude_s64':struct.unpack_from('<q',raw,80)[0],'altitude_s64_hex':raw[80:88].hex()}
 events=[list(struct.unpack_from('<4I',raw,1024+i*16))for i in range(words[1])]
 expected={'ok':unsupported==0,'error':'','branch':'coarse_rejected'if stage==0 else('sphere_external_or_equal'if stage==1 else'simple_parent_player_response'),'body_hex':body.hex(),'parent_hex':parent.hex(),'globals':globals_after,'return_flags_u8':words[0],'relative_after_hex':absolute.hex(),'damage_calls':[{'amount_s32':s32(e[1]),'attacker_u32':e[2]}for e in events],'callbacks_raw_u32':events,'F577_calls':calls,'response_applied':stage==2,'classification_applied':calls>0,'landing_accepted':bool(words[10]),'repeat_count':words[2]}
 if unsupported:
  expected.update(error='hierarchical_collision_stream_requires_f576'if unsupported==576 else'other_pair_response_requires_f578',branch='unsupported_atomic_adapter_guard',body_hex=row['body_hex'],parent_hex=row['parent_hex'],globals=json.loads(json.dumps(g)),return_flags_u8=None,damage_calls=[],callbacks_raw_u32=[],response_applied=False,classification_applied=False,landing_accepted=False)
  expected['raw_private_source_observation']={'forbidden_call':unsupported,'partial_globals':globals_after,'relative_after_hex':absolute.hex(),'F577_calls':calls}
 return expected

def pipeline_execute(assembly,rows):
 with tempfile.TemporaryDirectory(prefix='bounded-f575-pipeline-native-')as d:
  p=Path(d);(p/'p.s').write_text(assembly);r=subprocess.run(['as','--64',str(p/'p.s'),'-o',str(p/'p.o')],capture_output=True,text=True)
  if r.returncode:raise ValueError(r.stderr)
  subprocess.run(['ld','-m','elf_x86_64',str(p/'p.o'),'-o',str(p/'p')],capture_output=True,check=True)
  payload=b''.join(pipeline_pack(row)for row in rows);runs=[]
  for _ in range(3):
   r=subprocess.run([str(p/'p')],input=payload,capture_output=True,timeout=30)
   if r.returncode or len(r.stdout)!=len(rows)*C.OUTPUT:raise ValueError('Pipeline native failure '+str((r.returncode,len(r.stdout),len(rows)*C.OUTPUT)))
   runs.append(r.stdout)
  if len(set(runs))!=1:raise ValueError('Pipeline fresh process mismatch')
  r=subprocess.run([str(p/'p')],input=b''.join(pipeline_pack(row)for row in reversed(rows)),capture_output=True,timeout=30)
  if r.returncode or r.stdout!=b''.join(runs[0][i*C.OUTPUT:(i+1)*C.OUTPUT]for i in range(len(rows)-1,-1,-1)):raise ValueError('Pipeline reverse order mismatch')
 return [pipeline_parse(row,runs[0][i*C.OUTPUT:(i+1)*C.OUTPUT])for i,row in enumerate(rows)]

def pipeline_literal_controls(rows):
 result=[]
 def check(name,index,observe,literal):
  row=rows[index];actual=observe(row['expected'])
  if actual!=literal:raise ValueError('Pipeline independent source control failed '+name+str((actual,literal)))
  result.append({'name':name,'case_id':row['id'],'literal_expected':literal,'observed':actual,'passed':True})
 check('coarse-reject-precedes-classification',0,lambda e:[e['branch'],e['F577_calls'],e['return_flags_u8'],e['globals']['collision_kind_u8'],e['globals']['altitude_s64_hex'],e['damage_calls']],['coarse_rejected',0,0,7,struct.pack('<q',987654321).hex(),[]])
 check('external-classifier-has-no-response',1,lambda e:[e['branch'],e['F577_calls'],e['classification_applied'],e['response_applied'],e['damage_calls']],['sphere_external_or_equal',1,True,False,[]])
 check('equality-classifier-has-no-response',2,lambda e:[e['branch'],e['F577_calls'],e['response_applied'],e['damage_calls']],['sphere_external_or_equal',1,False,[]])
 check('inside-selected-parent-enters-clean-response',3,lambda e:[e['branch'],e['F577_calls'],e['globals']['collision_kind_u8'],e['landing_accepted'],e['return_flags_u8'],e['damage_calls']],['simple_parent_player_response',1,2,True,0x42,[]])
 check('speed601-has-source-mass-floor',5,lambda e:[e['landing_accepted'],e['return_flags_u8'],e['damage_calls']],[False,0x82,[{'amount_s32':8,'attacker_u32':0}]])
 check('hierarchical-parent-does-not-call-sphere',198,lambda e:[e['ok'],e['error'],e['F577_calls'],e['raw_private_source_observation']['forbidden_call']],[False,'hierarchical_collision_stream_requires_f576',0,576])
 check('nonparent-overlap-intercepts-pair-handler',199,lambda e:[e['ok'],e['error'],e['F577_calls'],e['raw_private_source_observation']['forbidden_call']],[False,'other_pair_response_requires_f578',1,578])
 check('nonparent-external-pair-exits-before-pair-handler',200,lambda e:[e['ok'],e['branch'],e['F577_calls']],[True,'sphere_external_or_equal',1])
 check('hierarchical-coarse-reject-exits-before-stream-handler',201,lambda e:[e['ok'],e['branch'],e['F577_calls']],[True,'coarse_rejected',0])
 return result

def build_pipeline(args,source,exe,primary,helpers,primary_proofs):
 old,fragment,extra,full,proofs,constants=pipeline_proof(source,exe,args.executable,primary_proofs);models=pipeline_models(exe);assembly=pipeline_native(old,fragment,extra,full,primary,helpers);rows=pipeline_cases(models);results=pipeline_execute(assembly,rows)
 for i,(row,result)in enumerate(zip(rows,results)):row['id']='dos-simple-parent-pipeline-%04d'%i;row['expected']=result
 controls=pipeline_literal_controls(rows)
 output=args.output.with_name('source_spherical_contact_pipeline_native.json')
 doc={'schema_version':1,'reference':'uploaded DOS FIRSTENC.EXE bounded player/simple-parent route','executable_sha256':EXE_SHA,'pinned_asm_sha256':ASM_SHA,'source_commit':COMMIT,'case_count':len(rows),'supported_case_count':sum(row['expected']['ok']for row in rows),'unsupported_guard_case_count':sum(not row['expected']['ok']for row in rows),'canonical_classifier_fixture_sha256':sha(args.output.read_bytes()),'independent_literal_controls':controls,'byte_instruction_proofs':proofs,'source_zero64_constants':constants,'models':models,'execution_checks':{'fresh_identical_processes':3,'reverse_case_order_identical':True,'raw338_parent_descriptor_spec_output_canaries':True,'unrelated_body_bytes_unchanged':True,'parent_descriptors_specs_unchanged':True,'expected_source_transitions_computed_by_python':False},'repeat_observation_contract':{'body_and_globals':'Native in-place candidate state is reused.','relative':'The same candidate RELbuffer is reused: first F1664 replaces it with wrapped abs; later calls consume that abs. No caller input is mutated by the pure API.','F577_calls_and_damage_callbacks':'Aggregated across all invocations.','branch_response_applied_landing_accepted':'Last invocation.','classification_applied':'Any observed F577 call; all repeated fixture rows classify on every invocation.'},'complete_original_F575_behavior':False,'F576_F578_engine_executed':False,'full_F569_scanner':False,'scope':['Actual entire F575 instructions plus actual canonical-DOS F577 and required original math helpers. Executed domain is bounded to canonical player/simple-parent branches only.','F576/F578 do not execute. Six forbidden-call interception controls are not counted as supported original engine cases: returned public body/globals are rolled back atomically by explicit adapter policy, while private source partial observations are preserved separately.','F953 calls are only observed; damage/HP/equipment/RNG is not executed.','No complete F569 scanner, complex collision streams, pair response, automatic frame selection, universal collision parity or live UI behavior is inferred.','Repeated source calls reuse body/globals/RELbuffer; this is not an entire-frame source simulator.','ReturnAL only is observed on completed source paths; no garbage upper-EAX parity claim.'],'cases':rows}
 output.write_text(json.dumps(doc,indent=2)+'\n');report={k:v for k,v in doc.items()if k!='cases'};report.update(fixture_sha256=sha(output.read_bytes()),tool_sha256=sha(Path(__file__).read_bytes()),native_assembly_sha256=sha(assembly.encode()),branch_counts={branch:sum(r['expected']['branch']==branch for r in rows)for branch in sorted({r['expected']['branch']for r in rows})})
 (args.validation_dir/'source-spherical-contact-pipeline-native-proof.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({'pipeline_cases':len(rows),'fixture_sha256':report['fixture_sha256'],'branches':report['branch_counts'],'proof_records':len(proofs)}))

if __name__=='__main__':main()
