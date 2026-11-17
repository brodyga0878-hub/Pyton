#!/usr/bin/env python3
"""Whole actual DOS F578 native instruction controls; F953 is a matched boundary.

JJFFE replaced this body. Restore the uploaded DOS disassembly, independently
reassemble all114 instructions, then run a reviewed ELF64 stack-ABI adapter.
Python builds raw input/response patches and never computes expected physics.
"""
from __future__ import annotations
import argparse,copy,hashlib,json,random,re,struct,subprocess,tempfile
from pathlib import Path
import rebuild_source_surface_contact_native as C
PROJECT=Path(__file__).resolve().parents[1]
PROOF=PROJECT/'validation/contact-classifier-2026-11-17/pair-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_pair_response_native.json'
PROFILE='dos-firstenc-pair-response-v1'
BODY=338;CONTEXT=BODY*2+8;RECORD=16+CONTEXT*2;INPUT=8+BODY*2+256;OUTPUT=16+CONTEXT+RECORD*2+64
EXE_SHA=C.EXE_SHA;ASM_SHA=C.ASM_SHA
ALIASES={'DATA_008696':0x633ec8,'DATA_008700':0x633ecc,'FUNC_000953':0x43df7c,'_abs':0x476238}
def sha(raw):return hashlib.sha256(raw).hexdigest()
def restore(rows):
    rev={v:k for k,v in ALIASES.items()};lines=['FUNC_000578: ; Pos = 283b0, restored from actual DOS']
    for at,op,args in rows:
        lines.append('DOS_PAIR_%x:'%at);args=re.sub(r'\s*,\s*',',',args)
        if op.startswith('j'):args='DOS_PAIR_%x'%int(args,16)
        elif op=='call':args=rev[int(args,16)]
        else:args=re.sub(r'ds:0x([0-9a-f]+)',lambda m:'['+rev[int(m[1],16)]+']',args)
        args=re.sub(r'\b(BYTE|WORD|DWORD) PTR ',lambda m:m[1].lower()+' ',args);lines.append(op+' '+args)
    return '\n'.join(lines)+'\n'
def reprove(args):
    exe=args.exe.read_bytes();source=args.asm.read_bytes()
    if sha(exe)!=EXE_SHA or sha(source)!=ASM_SHA:raise ValueError('Unreviewed original identities')
    rows=C.original_rows(args.exe,0x4281b8,end=0x428358);text=restore(rows)
    compiled=C.J.instructions(C.compile32(text,ALIASES,'FUNC_000578',0x4281b8))
    if C.J.canonical(rows)!=C.J.canonical(compiled):raise ValueError('Restored DOS body differs')
    image=C.G.Image(exe);at=image.offset(0x4281b8,1);end=image.offset(0x428358,1);raw=exe[at:end]
    if exe[0x67038:0x67038+len(C.G.ABS_DOS)]!=C.G.ABS_DOS:raise ValueError('DOS abs differs')
    metadata={'schema':'starfrontier-original-pair-response-instruction-proof-v1','source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'source_procedures_sha256':sha(text.encode()),'bindings':ALIASES,'procedures':{'578':{'virtual_address':0x4281b8,'executable_offset':at,'byte_length':len(raw),'hex':raw.hex(),'sha256':sha(raw),'instruction_count':len(rows),'normalized_instruction_sha256':sha('\n'.join(C.J.canonical(rows)).encode()),'all_full_procedure_instructions_equal':True}},'abs_hex':C.G.ABS_DOS.hex(),'scope':'Whole actual DOS F578 only. JJFFE replaced pair response arithmetic; source reconstructed directly from verified DOS disassembly. F953 damage/world effects remain matched observer boundaries.'}
    args.proof_dir.mkdir(parents=True,exist_ok=True);(args.proof_dir/'source-procedures.s').write_text(text);(args.proof_dir/'instruction-proof.json').write_text(json.dumps(metadata,indent=2)+'\n');(args.proof_dir/'dos-disassembly.txt').write_text('\n'.join('%08x: %s %s'%r for r in rows)+'\n')
def verify(proof):
    metadata=json.loads((proof/'instruction-proof.json').read_text());text=(proof/'source-procedures.s').read_text();record=metadata['procedures']['578']
    if metadata['source_executable_sha256']!=EXE_SHA or metadata['source_assembly_sha256']!=ASM_SHA or metadata['bindings']!=ALIASES or sha(text.encode())!=metadata['source_procedures_sha256']or metadata['abs_hex']!=C.G.ABS_DOS.hex():raise ValueError('Archived original proof identity differs')
    rows=C.J.instructions(C.compile32(text,ALIASES,'FUNC_000578',0x4281b8))
    if len(rows)!=114 or sha('\n'.join(C.J.canonical(rows)).encode())!=record['normalized_instruction_sha256']or sha(bytes.fromhex(record['hex']))!=record['sha256']or not record['all_full_procedure_instructions_equal']:raise ValueError('Archived whole DOS instruction proof differs')
    return metadata,text

def packet(row):
    g=row['globals_before'];raw=struct.pack('<II',g['collision_flags_u8'],g['collision_enabled_u8'])+bytes.fromhex(row['body_before_hex'])+bytes.fromhex(row['collider_before_hex'])
    for index in range(2):
        patch=row.get('scripts',[])[index]if index<len(row.get('scripts',[]))else[]
        if len(patch)>16:raise ValueError('Patch cap')
        for i in range(16):
            at,val=patch[i]if i<len(patch)else(0xffffffff,0)
            if at!=0xffffffff and not(0<=at<CONTEXT and 0<=val<=255):raise ValueError('Patch outside raw context')
            raw+=struct.pack('<II',at,val)
    assert len(raw)==INPUT
    return raw

def context(raw):
    a,b=struct.unpack_from('<II',raw,BODY*2)
    if a>255 or b>255:raise ValueError('Global alias high bytes changed')
    return {'body_hex':raw[:BODY].hex(),'collider_hex':raw[BODY:BODY*2].hex(),'globals':{'collision_flags_u8':a,'collision_enabled_u8':b}}
def decode(raw,row):
    magic,count,abscount,guard=struct.unpack_from('<4I',raw)
    if magic!=0x50414952 or count>2 or abscount not in(0,3)or guard or raw[-64:]!=b'\xa5'*64:raise ValueError('Native guards failed '+row['name'])
    result=context(raw[16:16+CONTEXT]);observations=[]
    for index in range(count):
        record=raw[16+CONTEXT+index*RECORD:16+CONTEXT+(index+1)*RECORD];target,damage,attacker,reserved=struct.unpack_from('<4I',record)
        if target not in(1,2)or reserved:raise ValueError('Invalid native body reference')
        observations.append({'kind':'F953','target':'body'if target==1 else'collider','args':[damage,attacker],'before':context(record[16:16+CONTEXT]),'after':context(record[16+CONTEXT:])})
    return {'body_after_hex':result['body_hex'],'collider_after_hex':result['collider_hex'],'globals_after':result['globals'],'observations':observations,'source_order':['F578']+['_abs']*abscount+['F953']*count}
def assembly(source):
    abi=C.load('pair_host_adapter',PROJECT/'recovered-history/ground_harness/tools/native_reference.py')
    lines,_=abi.procedures(source+'\nFUNC_999999:\nret\n',[578])
    header='.intel_syntax noprefix\n.code64\n.section .text\n.global _start\n'
    native=header+'\n'.join(lines)+'\n'+WRAPPER
    return native.replace('@INPUT@',str(INPUT)).replace('@OUTPUT@',str(OUTPUT)).replace('@CONTEXT@',str(CONTEXT)).replace('@RECORD@',str(RECORD))

def generate(proof,output):
    metadata,source=verify(proof);native=assembly(source);rng=random.Random(0x578F953);rows=[]
    ints=[0,1,-1,3,-3,4,-4,255,-255,0x7fffffff,-0x80000000,0x40000000,-0x40000000]
    for i in range(288):
        body=bytearray(rng.randbytes(BODY));parent=bytearray(rng.randbytes(BODY));body[0x86]=114;parent[0x86]=37
        body[0x56]=37 if i%4==0 else 0;parent[0x87]=1 if i%4==1 else 3
        struct.pack_into('<I',body,0x82,[0,13,14,24,0xffffffff][i%5]);struct.pack_into('<I',parent,0x82,[0xffffffff,24,14,13,0][(i//5)%5])
        struct.pack_into('<3i',body,0x8c,*[rng.choice(ints)for _ in range(3)]);struct.pack_into('<3i',parent,0x8c,*[rng.choice(ints)for _ in range(3)])
        hp=[0,1,255,256,32767,32768,65534,65535];struct.pack_into('<H',body,0xe4,hp[i%8]);struct.pack_into('<H',parent,0xe4,hp[(i//8)%8])
        g={'collision_flags_u8':[0,1,127,128,255][i%5],'collision_enabled_u8':[0,1,255][(i//3)%3]};scripts=[]
        if i%3==0:
            # Explicit observer inputs, not expected collision arithmetic.
            scripts=[[[0xe4,rng.randrange(256)],[0xe5,rng.randrange(256)],[BODY+0xe4,rng.randrange(256)],[BODY+0xe5,rng.randrange(256)],[BODY+0x86,rng.choice([0,37,99,255])],[CONTEXT-8,rng.randrange(256)],[CONTEXT-4,rng.choice([0,1,255])]],[]]
        rows.append({'name':'pair/'+str(i),'body_before_hex':body.hex(),'collider_before_hex':parent.hex(),'globals_before':g,'scripts':scripts})
    with tempfile.TemporaryDirectory(prefix='pair-response-native-')as d:
        p=Path(d);(p/'native.s').write_text(native);subprocess.run(['as','--64','-o',str(p/'native.o'),str(p/'native.s')],capture_output=True,check=True);subprocess.run(['ld','-o',str(p/'native'),str(p/'native.o')],capture_output=True,check=True)
        def run(items):
            result=subprocess.run([str(p/'native')],input=b''.join(packet(r)for r in items),capture_output=True,check=True,timeout=60)
            if result.stderr or len(result.stdout)!=len(items)*OUTPUT:raise ValueError('Native output length/stderr differs')
            return result.stdout
        first=run(rows);again=run(rows);third=run(rows)
        if first!=again or first!=third:raise ValueError('Fresh native process mismatch')
        reverse=run(list(reversed(rows)))
        if b''.join(reverse[i*OUTPUT:(i+1)*OUTPUT]for i in reversed(range(len(rows))))!=first:raise ValueError('Reverse native mismatch')
        for i,row in enumerate(rows):row['expected']=decode(first[i*OUTPUT:(i+1)*OUTPUT],row)
        original_rows=list(rows);continuations=[];last=copy.deepcopy(rows[100])
        for i in range(32):
            last['name']='consecutive/'+str(i);last['scripts']=[];last.pop('expected',None)
            raw=run([last]);last['expected']=decode(raw,last);continuations.append(copy.deepcopy(last))
            last['body_before_hex']=last['expected']['body_after_hex'];last['collider_before_hex']=last['expected']['collider_after_hex'];last['globals_before']=last['expected']['globals_after']
        rows+=continuations
    paths=['tools/rebuild_source_pair_response_native.py','tools/rebuild_source_surface_contact_native.py','tools/rebuild_source_atmospheric_native.py','tools/rebuild_ground_surface_native.py','recovered-history/ground_harness/tools/native_reference.py']
    pins={name:sha((PROJECT/name).read_bytes())for name in paths}
    result={'schema':'starfrontier-source-pair-response-native-v1','profile':PROFILE,'case_count':len(rows),'source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'instruction_proof_sha256':sha((proof/'instruction-proof.json').read_bytes()),'source_procedures_sha256':sha(source.encode()),'host_assembly_sha256':sha(native.encode()),'fresh_process_runs':3,'reverse_repeat_cases':len(original_rows),'consecutive_native_steps':32,'all_context_output_canaries_unchanged':True,'expected_arithmetic_calculated_in_python':False,'source_dependencies_sha256':pins,'callback_policy':'F953 exact target/amount/attacker/full-before/full-after observed; damage body and world effects are not executed. Source reloads after first callback are preserved.','cases':rows}
    output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(result,indent=2)+'\n');(proof/'pair-response-native.s').write_text(native)
    print(json.dumps({'case_count':len(rows),'fixture_sha256':sha(output.read_bytes()),'native_processes':4,'scope':metadata['scope']}))

WRAPPER=r'''
_abs:
 push rbp
 mov rbp,rsp
 inc DWORD PTR [abs_count]
 mov eax,DWORD PTR [rbp+16]
 test eax,eax
 jge abs_positive
 mov edx,eax
 neg edx
 jmp abs_done
abs_positive:
 mov edx,eax
abs_done:
 mov eax,edx
 pop rbp
 ret
FUNC_000953:
 push rbp
 mov rbp,rsp
 pushfq
 push rax
 push rbx
 push rcx
 push rdx
 push rsi
 push rdi
 mov ecx,DWORD PTR [request_count]
 cmp ecx,2
 jae failed
 imul ecx,ecx,@RECORD@
 lea rdi,[output+16+@CONTEXT@+rcx]
 mov eax,DWORD PTR [rbp+16]
 cmp eax,OFFSET FLAT:body
 je target_body
 cmp eax,OFFSET FLAT:collider
 jne failed
 mov DWORD PTR [rdi],2
 jmp target_ready
target_body:
 mov DWORD PTR [rdi],1
target_ready:
 mov eax,DWORD PTR [rbp+24]
 mov DWORD PTR [rdi+4],eax
 mov eax,DWORD PTR [rbp+32]
 mov DWORD PTR [rdi+8],eax
 mov QWORD PTR [record_pointer],rdi
 add rdi,16
 mov esi,OFFSET FLAT:live
 mov ecx,@CONTEXT@
 rep movsb
 mov ecx,DWORD PTR [request_count]
 shl ecx,7
 lea rsi,[input+684+rcx]
 mov ecx,16
patch_more:
 mov eax,DWORD PTR [rsi]
 cmp eax,0xffffffff
 je patch_skip
 cmp eax,@CONTEXT@
 jae failed
 mov dl,BYTE PTR [rsi+4]
 mov BYTE PTR [live+rax],dl
patch_skip:
 add rsi,8
 loop patch_more
 mov rdi,QWORD PTR [record_pointer]
 add rdi,16+@CONTEXT@
 mov esi,OFFSET FLAT:live
 mov ecx,@CONTEXT@
 rep movsb
 inc DWORD PTR [request_count]
 pop rdi
 pop rsi
 pop rdx
 pop rcx
 pop rbx
 pop rax
 popfq
 pop rbp
 ret
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 lea rsi,[input+r8]
 mov edx,@INPUT@
 sub edx,r8d
 syscall
 test eax,eax
 jz finished
 js failed
 add r8d,eax
 cmp r8d,@INPUT@
 jb read_more
 mov edi,OFFSET FLAT:output
 mov ecx,@OUTPUT@
 mov al,0xa5
 rep stosb
 mov edi,OFFSET FLAT:output
 mov ecx,16+@CONTEXT@+2*@RECORD@
 xor eax,eax
 rep stosb
 mov DWORD PTR [request_count],0
 mov DWORD PTR [abs_count],0
 mov esi,OFFSET FLAT:input+8
 mov edi,OFFSET FLAT:live
 mov ecx,676
 rep movsb
 mov eax,DWORD PTR [input]
 mov DWORD PTR [DATA_008696],eax
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [DATA_008700],eax
 mov rax,0xa5a5a5a5a5a5a5a5
 mov QWORD PTR [live_before],rax
 mov QWORD PTR [live_after],rax
 push OFFSET FLAT:collider
 push OFFSET FLAT:body
 call FUNC_000578
 add rsp,16
 mov rax,0xa5a5a5a5a5a5a5a5
 cmp QWORD PTR [live_before],rax
 jne failed
 cmp QWORD PTR [live_after],rax
 jne failed
 mov DWORD PTR [output],0x50414952
 mov eax,DWORD PTR [request_count]
 mov DWORD PTR [output+4],eax
 mov eax,DWORD PTR [abs_count]
 mov DWORD PTR [output+8],eax
 mov esi,OFFSET FLAT:live
 mov edi,OFFSET FLAT:output+16
 mov ecx,@CONTEXT@
 rep movsb
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,@OUTPUT@
 syscall
 cmp eax,@OUTPUT@
 jne failed
 jmp next_case
finished:
 test r8d,r8d
 jne failed
 mov eax,60
 xor edi,edi
 syscall
failed:
 mov eax,60
 mov edi,87
 syscall
.section .bss
.balign 16
input:.skip @INPUT@
output:.skip @OUTPUT@
live_before:.skip 8
live:.skip @CONTEXT@
live_after:.skip 8
.set body,live
.set collider,live+338
.set DATA_008696,live+676
.set DATA_008700,live+680
request_count:.skip 4
abs_count:.skip 4
record_pointer:.skip 8
.balign 16
stack:.skip 65536
stack_end:
'''
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path);p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--refresh-original-proof',action='store_true');a=p.parse_args()
    if a.refresh_original_proof:reprove(a)
    generate(a.proof_dir,a.output)
