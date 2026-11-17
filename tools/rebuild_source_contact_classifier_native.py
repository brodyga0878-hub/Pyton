#!/usr/bin/env python3
"""Whole original DOS F575, real F577/F578/math, matched F576/F953 boundaries.
Expected arithmetic comes only from captured original instructions under the
reviewed ELF64 ABI. Private originals are required only for --reprove-original.
"""
from __future__ import annotations
import argparse,copy,hashlib,inspect,json,random,re,struct,subprocess,tempfile
from pathlib import Path
import rebuild_source_surface_contact_native as C
import rebuild_source_spherical_contact_native as S
import rebuild_source_natural_contact_native as N
import rebuild_source_frame_dispatch_native as F
PROJECT=C.PROJECT;PROOF=PROJECT/'validation/contact-classifier-2026-11-17/native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_contact_classifier_native.json'
PROFILE='dos-firstenc-whole-f575-classifier-v1'
FIELDS=F.FIELDS+[('player_index_u32',8857,4)]
NUMBERS=C.HELPERS+[575,577,578,1332,1341,1664]
TRACED=[575,1664,576,577,578,1538,571,1520,953]
INPUT=2048;OUTPUT=14336;CONTEXT=776;OBS=1576;MAXOBS=8
PAIR=PROJECT/'validation/contact-classifier-2026-11-17/pair-native-proof/source-procedures.s'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def s32(value):return (value&0x7fffffff)-(value&0x80000000)
def clean(body):
 body=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',body)
 body=re.sub(r'\[ebp\+0x([89a-f][0-9a-f]{7})\]',lambda m:'[ebp-0x%x]'%(0x100000000-int(m[1],16)),body)
 return re.sub(r'add esp,0x([89a-f][0-9a-f]{7})',lambda m:'add esp,-0x%x'%(0x100000000-int(m[1],16)),body)
def reprove(a):
 raw=a.exe.read_bytes();source=a.asm.read_text();data=a.data.read_text()
 if sha(raw)!=C.EXE_SHA or sha(a.asm.read_bytes())!=C.ASM_SHA:raise ValueError('Original identity differs')
 method=inspect.getsource(N.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_000575',0x4276a0)")
 method=method.replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
 method=method.replace("syms=set(re.findall", "bodies[577]=sphere_body\n bodies[578]=pair_body\n syms=set(re.findall")
 scope=N.__dict__.copy();scope.update(sphere_body=S.dos_body(source)[0],pair_body=PAIR.read_text());exec(method,scope)
 bodies,records,dis,callbacks,aliases=scope['proof'](source,data,raw,a.exe,NUMBERS)
 a.proof_dir.mkdir(parents=True,exist_ok=True)
 selected='\n'.join(bodies[n]for n in NUMBERS)+'\nFUNC_999999:\nret\n'
 (a.proof_dir/'source-procedures.asm').write_text(selected)
 (a.proof_dir/'dos-disassembly.txt').write_text('\n'.join(dis.values()))
 models={};image=C.G.Image(raw)
 for model in range(149):
  at=image.pointer(0xba8fc+model*4,68);descriptor=raw[at:at+68];ptr=struct.unpack_from('<I',descriptor,56)[0]
  spec=raw[image.offset(ptr,24):image.offset(ptr,24)+24]if ptr else bytes(24)
  models[str(model)]={'descriptor_hex':descriptor.hex(),'spec_hex':spec.hex(),'descriptor_sha256':sha(descriptor),'spec_sha256':sha(spec)}
 if any(raw[image.offset(aliases['DATA_%06d'%n],4):image.offset(aliases['DATA_%06d'%n],4)+4]!=bytes(4)for n in [7635,7636]):raise ValueError('Original Int64 zero constant differs')
 absraw=raw[0x67038:0x67038+len(C.G.ABS_DOS)]
 if absraw!=C.G.ABS_DOS:raise ValueError('Original DOS Watcom abs differs')
 meta={'source_symbol_addresses':aliases,'abs_hex':absraw.hex(),'abs_sha256':sha(absraw),'schema':'starfrontier-whole-contact-classifier-proof-v1','source_executable_sha256':C.EXE_SHA,'source_assembly_sha256':C.ASM_SHA,'procedures':records,'all_whole_instructions_equal':True,'source_procedures_sha256':sha(selected.encode()),'models':models,'source_callback_words':callbacks,'scope':'Whole DOS F575, actual F577 sphere and restored DOS F578 pair response, real original arithmetic/descriptor/basis closure. F576 generic geometry/VM and F953 damage effects are strict typed observations. Not full geometry, world, Main, Android or full F569 scan.'}
 (a.proof_dir/'instruction-proof.json').write_text(json.dumps(meta,indent=2)+'\n');return meta,selected

def verify_archived(meta,source):
 if sha(source.encode())!=meta['source_procedures_sha256'] or meta['source_executable_sha256']!=C.EXE_SHA or meta['source_assembly_sha256']!=C.ASM_SHA:raise ValueError('Archived original identity changed')
 if bytes.fromhex(meta['abs_hex'])!=C.G.ABS_DOS:raise ValueError('Archived actual DOS abs identity changed')
 for n in NUMBERS:
  body=C.J.block(source,n);record=meta['procedures'][str(n)];rows=C.J.instructions(C.compile32(body,meta['source_symbol_addresses'],'FUNC_%06d'%n,record['virtual_address']))
  if len(rows)!=record['instruction_count'] or sha('\n'.join(N.canonical(rows)).encode())!=record['normalized_instruction_sha256']:raise ValueError('Archived instruction proof differs F'+str(n))
 for model in meta['models'].values():
  if sha(bytes.fromhex(model['descriptor_hex']))!=model['descriptor_sha256'] or sha(bytes.fromhex(model['spec_hex']))!=model['spec_sha256']:raise ValueError('Archived original model resource changed')

def trace(k):return f'pushfq\npush rax\npush rcx\nmov ecx,DWORD PTR [order_count]\ncmp ecx,128\njae failed\nmov DWORD PTR [order+rcx*4],{k}\ninc DWORD PTR [order_count]\npop rcx\npop rax\npopfq\n'
def capture(base):
 lines=[f'lea rdi,[{base}]','mov esi,OFFSET FLAT:object','mov ecx,338','rep movsb','mov esi,OFFSET FLAT:parent','mov ecx,338','rep movsb','mov esi,DWORD PTR [local_relative]','mov ecx,24','rep movsb','mov esi,OFFSET FLAT:relative','mov ecx,24','rep movsb']
 for name,n,size in FIELDS:
  lines.append(('movzx eax,BYTE PTR 'if size==1 else'mov eax,DWORD PTR ')+f'[DATA_{n:06d}]')
  if name=='collider_ref_u32':lines.append('call encode_ref')
  lines+=['mov DWORD PTR [rdi],eax','add rdi,4']
 return '\n'.join(lines)
def assembly(selected):
 bodies={n:C.J.block(selected,n)for n in NUMBERS}
 # F577 has six contiguous DWORD value arguments. Expanded host argument slots
 # need a private contiguous buffer, preserving every original arithmetic op.
 p=bodies[577].replace('add esp,byte -0x10','add esp,-0x40',1)
 for at in range(0x14,0x2c,4):p=p.replace('[ebp+0x%x]'%at,'[ebp-0x%x]'%(0x40-(at-0x14)))
 p=p.replace('push edi\n','push edi\n'+''.join('mov eax,[ebp+0x%x]\nmov [ebp-0x%x],eax\n'%(at,0x40-(at-0x14))for at in range(0x14,0x2c,4)),1)
 bodies[577]=p
 source=clean('\n'.join(bodies[n]for n in NUMBERS)+'\nFUNC_999999:\nret\n')
 adapter=C.load('classifier_host_abi',PROJECT/'recovered-history/ground_harness/tools/native_reference.py')
 lines,_=adapter.procedures(source,NUMBERS);text='\n'.join(lines).replace('call _abs','call dos_abs')
 for n in TRACED:
  if n in NUMBERS:text=text.replace(f'FUNC_{n:06d}:',f'FUNC_{n:06d}:\n'+trace(n),1)
 # Capture original signed local copy exactly after the entry REP MOVSD.
 marker='rep movsd\npop rdi\npop rsi'
 if text.count(marker)!=1:raise ValueError('Changed F575 signed local-copy boundary')
 text=text.replace(marker,'rep movsd\nlea eax,[rbp-0x38]\nmov DWORD PTR [local_relative],eax\npop rdi\npop rsi')
 for label,kind in [('FUNC_000576',576),('FUNC_000953',953)]:text+='\n'+stub(label,kind)
 text+='\ndos_abs:\npush rbp\nmov rbp,rsp\nmov eax,DWORD PTR [rbp+16]\ntest eax,eax\njge abs_nonnegative\nmov edx,eax\nneg edx\njmp abs_done\nabs_nonnegative:\nmov edx,eax\nabs_done:\nmov eax,edx\npop rbp\nret\n'
 text+='\n'+wrapper()
 data='\n.section .data\n.balign 8\nDATA_007719: .quad FUNC_001520\nDATA_007737: .quad FUNC_001522\nDATA_007738: .quad FUNC_001502\nDATA_007756: .quad FUNC_001538\nDATA_007635: .long 0\nDATA_007636: .long 0\n.section .bss\n.balign 16\ninput: .zero 2048\noutput: .zero 14336\norder_count: .zero 4\norder: .zero 512\nobs_count: .zero 4\nlocal_relative: .zero 4\nreturn_value: .zero 4\nactive_script: .zero 8\nactive_record: .zero 8\nDATA_004681: .zero 600\n'
 for name,n,size in FIELDS:data+=f'DATA_{n:06d}: .zero {size}\n'
 for label,size in [('object',338),('parent',338),('relative',24),('body_descriptor',68),('parent_descriptor',68),('body_spec',24),('parent_spec',24)]:data+=f'{label}_guard_a: .zero 8\n{label}: .zero {size}\n{label}_guard_b: .zero 8\n'
 data+='\n.balign 16\nstack: .zero 1048576\nstack_end:\n.section .note.GNU-stack,"",@progbits\n'
 return '.intel_syntax noprefix\n.code64\n.section .text\n.global _start\n'+text+data

def stub(label,kind):
 text=f'{label}:\n'+trace(kind)+'''push rbp
mov rbp,rsp
push rbx
push rsi
push rdi
mov eax,DWORD PTR [obs_count]
cmp eax,8
jae failed
imul ecx,eax,104
add ecx,OFFSET FLAT:input+968
mov QWORD PTR [active_script],rcx
imul edx,eax,1576
add edx,OFFSET FLAT:output+1320
mov QWORD PTR [active_record],rdx
'''
 text+=f'mov DWORD PTR [rdx],{kind}\n'
 if kind==576:text+='mov DWORD PTR [rdx+4],2\nmovzx eax,BYTE PTR [object+0x86]\nmov DWORD PTR [rdx+8],eax\nmovzx eax,BYTE PTR [parent+0x86]\nmov DWORD PTR [rdx+12],eax\n'
 else:text+='''mov DWORD PTR [rdx+4],3
mov eax,DWORD PTR [rbp+16]
call encode_ref
mov DWORD PTR [rdx+8],eax
mov eax,DWORD PTR [rbp+24]
mov DWORD PTR [rdx+12],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [rdx+16],eax
'''
 text+=capture('rdx+24')+'\nmov r10,QWORD PTR [active_script]\n'
 for i,(name,n,size)in enumerate(FIELDS):
  text+=f'test DWORD PTR [r10+4],{1<<i}\njz {label}_skip_{i}\nmov eax,DWORD PTR [r10+{12+i*4}]\n'
  if name=='collider_ref_u32':text+='call decode_ref\n'
  text+=f'mov {"BYTE"if size==1 else"DWORD"} PTR [DATA_{n:06d}],'+('al'if size==1 else'eax')+f'\n{label}_skip_{i}:\n'
 if kind==576:text+='''test DWORD PTR [r10],1
jz no_local_write
mov esi,r10d
add esi,64
mov edi,DWORD PTR [local_relative]
mov ecx,24
rep movsb
no_local_write:
'''
 for bit,target,off in [(2,'object',88),(4,'parent',96)]:text+=f'test DWORD PTR [r10],{bit}\njz {label}_{target}_skip\nmov eax,DWORD PTR [r10+{off}]\ncmp eax,338\njae failed\nmov edx,DWORD PTR [r10+{off+4}]\nxor BYTE PTR [{target}+rax],dl\n{label}_{target}_skip:\n'
 text+='mov rdx,QWORD PTR [active_record]\n'+capture('rdx+800')+'\nmov r10,QWORD PTR [active_script]\nmov eax,DWORD PTR [r10+8]\nmov rdx,QWORD PTR [active_record]\nmov DWORD PTR [rdx+20],eax\ninc DWORD PTR [obs_count]\npop rdi\npop rsi\npop rbx\npop rbp\nret\n';return text

def wrapper():
 text='''encode_ref:
cmp eax,114
jbe ref_done
cmp eax,OFFSET FLAT:object
je ref_object
cmp eax,OFFSET FLAT:parent
jne failed
movzx eax,BYTE PTR [parent+0x86]
ret
ref_object:
movzx eax,BYTE PTR [object+0x86]
ref_done:
ret
decode_ref:
test eax,eax
jz decode_done
movzx edx,BYTE PTR [object+0x86]
cmp eax,edx
je decode_object
movzx edx,BYTE PTR [parent+0x86]
cmp eax,edx
je decode_parent
cmp eax,114
ja failed
ret
decode_parent:
mov eax,OFFSET FLAT:parent
ret
decode_object:
mov eax,OFFSET FLAT:object
decode_done:
ret
_start:
mov esp,OFFSET FLAT:stack_end
cld
next_case:
xor r8d,r8d
read_more:
xor eax,eax
xor edi,edi
lea rsi,[input+r8]
mov edx,2048
sub edx,r8d
syscall
test eax,eax
jz finished
js failed
add r8d,eax
cmp r8d,2048
jb read_more
mov edi,OFFSET FLAT:output
xor eax,eax
mov ecx,14336
rep stosb
mov DWORD PTR [order_count],0
mov DWORD PTR [obs_count],0
mov edi,OFFSET FLAT:order
xor eax,eax
mov ecx,512
rep stosb
'''
 for label,at,size in [('object',84,338),('parent',422,338),('relative',760,24),('body_descriptor',784,68),('parent_descriptor',852,68),('body_spec',920,24),('parent_spec',944,24)]:text+=f'mov esi,OFFSET FLAT:input+{at}\nmov edi,OFFSET FLAT:{label}\nmov ecx,{size}\nrep movsb\nmov QWORD PTR [{label}_guard_a],-1\nmov QWORD PTR [{label}_guard_b],-1\n'
 for i,(name,n,size)in enumerate(FIELDS):
  text+=f'mov eax,DWORD PTR [input+{32+i*4}]\n'
  if name=='collider_ref_u32':text+='call decode_ref\n'
  text+=f'mov {"BYTE"if size==1 else"DWORD"} PTR [DATA_{n:06d}],'+('al'if size==1 else'eax')+'\n'
 text+='''mov eax,DWORD PTR [object+0x82]
cmp eax,149
jae failed
mov DWORD PTR [DATA_004681+rax*4],OFFSET FLAT:body_descriptor
mov eax,DWORD PTR [parent+0x82]
cmp eax,149
jae failed
mov DWORD PTR [DATA_004681+rax*4],OFFSET FLAT:parent_descriptor
mov DWORD PTR [body_descriptor+0x38],OFFSET FLAT:body_spec
mov DWORD PTR [parent_descriptor+0x38],OFFSET FLAT:parent_spec
push OFFSET FLAT:parent
push OFFSET FLAT:object
push OFFSET FLAT:relative
call FUNC_000575
add rsp,24
movzx eax,al
mov DWORD PTR [output],eax
'''+capture('output+32')+'''
mov eax,DWORD PTR [obs_count]
mov DWORD PTR [output+4],eax
mov eax,DWORD PTR [order_count]
mov DWORD PTR [output+8],eax
mov esi,OFFSET FLAT:order
mov edi,OFFSET FLAT:output+808
mov ecx,512
rep movsb
'''
 for label in ['object','parent','relative','body_descriptor','parent_descriptor','body_spec','parent_spec']:text+=f'cmp QWORD PTR [{label}_guard_a],-1\njne failed\ncmp QWORD PTR [{label}_guard_b],-1\njne failed\n'
 for label,at,size,skip in [('body_descriptor',784,68,True),('parent_descriptor',852,68,True),('body_spec',920,24,False),('parent_spec',944,24,False)]:
  for offset in range(size):
   if skip and 56<=offset<60:continue
   text+=f'mov al,BYTE PTR [{label}+{offset}]\ncmp al,BYTE PTR [input+{at+offset}]\njne failed\n'
 text+='''mov QWORD PTR [output+14320],-1
mov QWORD PTR [output+14328],-1
xor r8d,r8d
write_more:
mov eax,1
mov edi,1
lea rsi,[output+r8]
mov edx,14336
sub edx,r8d
syscall
test eax,eax
jle failed
add r8d,eax
cmp r8d,14336
jb write_more
jmp next_case
finished:
mov eax,60
xor edi,edi
syscall
failed:
mov eax,60
mov edi,95
syscall
''';return text
def cases(models):
 rng=random.Random(575577578);rows=[]
 for i in range(360):
  body=bytearray(rng.randbytes(338));parent=bytearray(rng.randbytes(338));point=[0,1<<40,0]if i<180 else [0,100+(i%7)*250,0]
  for b,mid,idx in [(body,[15,24,38][i%3],17),(parent,[117,118,121,130,134,140][i%6]if i<180 else[38,81,96][i%3],9)]:
   struct.pack_into('<9i',b,0,0x7fffffff,0,0,0,0x7fffffff,0,0,0,0x7fffffff);struct.pack_into('<I',b,0x82,mid);b[0x86]=idx;b[0x25]=0
   struct.pack_into('<q',b,0x138,(1<<45)if i<180 else 1000);struct.pack_into('<q',b,0x140,5000 if i<180 else 1000)
  body[0x56]=9 if i%3 else 0;body[0x87]=[3,11,14,1][i%4];parent[0x87]=[1,2,3][i%3];parent[0x14c]=0x80 if i<180 else 0
  struct.pack_into('<3i',body,0x8c,*[[0,0,0],[0,-600,0],[601,0,0],[0,10000,0],[999,-3000,32]][i%5]);struct.pack_into('<3i',parent,0x8c,1,-2,3);struct.pack_into('<H',body,0x9e,65535 if i%3 else 0)
  struct.pack_into('<3q',body,0x3e,100000,-200000,300000)
  if i%6==2:point=[-point[1],0,0]
  if i%6==3:point=[0,-point[1],0]
  if i%12==7:point=[1<<60,-(1<<60),1<<60]
  if i%12==8:point=[-(1<<63),0,0]
  g={name:0 for name,_,_ in FIELDS};g.update(player_index_u32=17 if i%4 else 114,collision_flags_u8=[0,1,0x40,0x80,255][i%5],collision_enabled_u8=[0,1,255][i%3],altitude_low_u32=0xffffffff,previous_altitude_low_u32=[0,1234,0xffffffff][i%3],previous_altitude_high_s32=[0,0,-1][i%3],collider_ref_u32=[0,9,17][i%3])
  scripts=[{'return_u32':0,'globals':{},'relative_after_hex':''}for _ in range(MAXOBS)]
  scripts[0]={'return_u32':1 if i%7==0 or (i<180 and i%3==2)else 0,'globals':{'collision_kind_u8':[0,1,2][i%3],'collision_flags_u8':int(g['collision_flags_u8'])|[0,2,0x20][i%3]},'relative_after_hex':struct.pack('<3q',*point).hex()if i%11==0 else''}
  if i<180 and i%13==0:scripts[1]={'return_u32':0,'globals':{'collision_enabled_u8':0},'body_xor':[0x9c,7]}
  rows.append({'name':f'whole-f575-{i:03d}','body_before_hex':body.hex(),'collider_before_hex':parent.hex(),'relative_before_hex':struct.pack('<3q',*point).hex(),'globals_before':g,'scripts':scripts})
 return rows

def packet(row,models):
 out=bytearray(INPUT);g=row['globals_before'];struct.pack_into('<13I',out,32,*[int(g[k])&0xffffffff for k,_,_ in FIELDS]);body=bytes.fromhex(row['body_before_hex']);parent=bytes.fromhex(row['collider_before_hex']);out[84:422]=body;out[422:760]=parent;out[760:784]=bytes.fromhex(row['relative_before_hex'])
 for b,at,sat in [(body,784,920),(parent,852,944)]:
  m=models[str(struct.unpack_from('<I',b,0x82)[0])];out[at:at+68]=bytes.fromhex(m['descriptor_hex']);out[sat:sat+24]=bytes.fromhex(m['spec_hex'])
 for i,s in enumerate(row['scripts']):
  at=968+i*104;flags=0;mask=0;after=s.get('globals',{})
  for j,(name,n,size)in enumerate(FIELDS):
   if name in after:mask|=1<<j;struct.pack_into('<I',out,at+12+j*4,int(after[name])&0xffffffff)
  if s.get('relative_after_hex'):flags|=1;out[at+64:at+88]=bytes.fromhex(s['relative_after_hex'])
  for k,bit,off in [('body_xor',2,88),('collider_xor',4,96)]:
   if k in s:flags|=bit;struct.pack_into('<II',out,at+off,*s[k])
  struct.pack_into('<III',out,at,flags,mask,s.get('return_u32',0))
 return bytes(out)
def globals_decode(raw):
 values=struct.unpack('<13I',raw);return {name:s32(v)if name.endswith('_s32')else v for(name,_,_),v in zip(FIELDS,values)}
def context_decode(raw):return {'body_hex':raw[:338].hex(),'collider_hex':raw[338:676].hex(),'relative_hex':raw[676:700].hex(),'caller_relative_hex':raw[700:724].hex(),'globals':globals_decode(raw[724:776])}
def decode(raw,row):
 if raw[-16:]!=b'\xff'*16:raise ValueError('Native canary failed')
 returned,count,norder=struct.unpack_from('<3I',raw);state=context_decode(raw[32:808]);obs=[]
 for i in range(count):
  at=1320+i*OBS;kind,argc,a,b,c,rv=struct.unpack_from('<6I',raw,at);args=[a,b,c][:argc]
  if kind==953:args[1]=s32(args[1])
  obs.append({'kind':'F'+str(kind),'args':args,'before':context_decode(raw[at+24:at+800]),'after':context_decode(raw[at+800:at+1576]),'return_u32':rv})
 return {'body_after_hex':state['body_hex'],'collider_after_hex':state['collider_hex'],'relative_after_hex':state['caller_relative_hex'],'globals_after':state['globals'],'return_u8':returned,'source_order':['F'+str(n)for n in struct.unpack_from('<128I',raw,808)[:norder]],'observations':obs}
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--reprove-original',action='store_true');a=p.parse_args()
 if a.reprove_original:meta,source=reprove(a)
 else:
  meta=json.loads((a.proof_dir/'instruction-proof.json').read_text());source=(a.proof_dir/'source-procedures.asm').read_text()
  if sha(source.encode())!=meta['source_procedures_sha256']:raise ValueError('Captured source changed')
 verify_archived(meta,source)
 native=assembly(source);rows=cases(meta['models']);packets=[packet(row,meta['models'])for row in rows]
 with tempfile.TemporaryDirectory(prefix='whole-f575-native-')as directory:
  d=Path(directory);(d/'n.s').write_text(native);subprocess.run(['as','--64',str(d/'n.s'),'-o',str(d/'n.o')],check=True);subprocess.run(['ld','-o',str(d/'n'),str(d/'n.o')],check=True)
  runs=[subprocess.run([str(d/'n')],input=b''.join(packets),capture_output=True,check=True,timeout=60).stdout for _ in range(3)]
  if len(set(runs))!=1 or len(runs[0])!=len(rows)*OUTPUT:raise ValueError('Native repeat/truncation failed')
  chunks=[runs[0][i*OUTPUT:(i+1)*OUTPUT]for i in range(len(rows))]
  previous=decode(chunks[151],rows[151]);seed=copy.deepcopy(rows[151])
  for step in range(32):
   row=copy.deepcopy(seed);row['name']='consecutive-f575-%02d'%step;row['sequence_index']=step
   row['body_before_hex']=previous['body_after_hex'];row['collider_before_hex']=previous['collider_after_hex'];row['globals_before']=previous['globals_after']
   packed=packet(row,meta['models']);continuations=[subprocess.run([str(d/'n')],input=packed,capture_output=True,check=True,timeout=60).stdout for _ in range(3)]
   if len(set(continuations))!=1 or len(continuations[0])!=OUTPUT:raise ValueError('Unstable consecutive original step')
   rows.append(row);packets.append(packed);chunks.append(continuations[0]);previous=decode(continuations[0],row)
  runs=[b''.join(chunks)]
  reverse=subprocess.run([str(d/'n')],input=b''.join(reversed(packets)),capture_output=True,check=True,timeout=60).stdout
  if reverse!=b''.join(runs[0][i*OUTPUT:(i+1)*OUTPUT]for i in reversed(range(len(rows)))):
   mismatches=[]
   for j,i in enumerate(reversed(range(len(rows)))):
    x=runs[0][i*OUTPUT:(i+1)*OUTPUT];y=reverse[j*OUTPUT:(j+1)*OUTPUT]
    if x!=y:mismatches.append((rows[i]['name'],[(k,a,b)for k,(a,b)in enumerate(zip(x,y))if a!=b][:8]))
   raise ValueError('Native order contamination '+str(mismatches[:10]))
 for i,row in enumerate(rows):row['expected']=decode(runs[0][i*OUTPUT:(i+1)*OUTPUT],row);row.pop('scripts')
 dependencies={n:sha((PROJECT/n).read_bytes())for n in ['tools/rebuild_source_contact_classifier_native.py','tools/rebuild_source_surface_contact_native.py','tools/rebuild_source_spherical_contact_native.py','tools/rebuild_source_natural_contact_native.py','tools/rebuild_source_frame_dispatch_native.py','recovered-history/ground_harness/tools/native_reference.py','validation/contact-classifier-2026-11-17/native-proof/source-procedures.asm','validation/contact-classifier-2026-11-17/native-proof/instruction-proof.json']}
 result={'schema':'starfrontier-source-contact-classifier-native-v1','profile':PROFILE,'case_count':len(rows),'source_executable_sha256':C.EXE_SHA,'source_assembly_sha256':C.ASM_SHA,'instruction_proof_sha256':sha((a.proof_dir/'instruction-proof.json').read_bytes()),'host_assembly_sha256':sha(native.encode()),'fresh_process_runs':3,'reverse_repeat_cases':len(rows),'consecutive_native_steps':32,'expected_arithmetic_computed_in_Python':False,'source_dependencies_sha256':dependencies,'cases':rows,'scope':meta['scope']}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,indent=2)+'\n');(a.proof_dir/'classifier-native.s').write_text(native);print(json.dumps({'cases':len(rows),'fixture_sha256':sha(a.output.read_bytes())}))
if __name__=='__main__':main()
