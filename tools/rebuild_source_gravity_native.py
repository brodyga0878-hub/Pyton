#!/usr/bin/env python3
"""Execute pinned source F603 gravity and F1511/F1512 integration on the host.

Expected arithmetic comes from extracted source instructions, not Python/GDScript.
The object lookup is actual F1532, with an isolated source-layout object bank.
Only host stack/pointer ABI spelling and a proven DOS CRT abs entry are adapted.
"""
from __future__ import annotations
import argparse, hashlib, json, random, re, struct, subprocess, sys, tempfile
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
COMMIT='7e540341d4e09aa3c92877b87d49e7f2c143ad8d'
VARIANT='jjffe-7e54034-gravity'
NUMBERS=[603,1333,1338,1466,1482,1483,1496,1502,1511,1512,1521,1532,1656,1657,1658,1660,1661]
OBJECT=338
BANK=0x74+256*OBJECT
INPUT=16+OBJECT*2+68
BASE_OUTPUT=OBJECT*2+24+16+64+4
TRACE_FIELDS=['truncate_shift','norm_u32','radius_packed','square_packed','cube_like_packed','ratio_packed','normalized_step_s32','factor_s32','update_path','final_exponent_s16']
OUTPUT=BASE_OUTPUT+len(TRACE_FIELDS)*4
SCRATCH=[0x5a5a5a5a]*3
ABS_DOS=bytes.fromhex('558bec8b450885c07d068bd0f7daeb028bd08bc25dc3')

def sha(raw):return hashlib.sha256(raw).hexdigest()

def block(source,number):
    start=re.search(r'^FUNC_%06d(?:_[A-Za-z0-9_]+)?:'%number,source,re.M)
    if not start:raise ValueError('Missing procedure '+str(number))
    end=re.search(r'^(?:FUNC_\d+(?:_[A-Za-z0-9_]+)?|_[A-Za-z0-9_]+):',source[start.end():],re.M)
    return source[start.start():start.end()+end.start() if end else len(source)]

def f880_mass_slice(source):
    original=block(source,880)
    start=original.index('\t\tmov word [ebp-0x4],0x4082')
    end=original.index('\t\tmov eax,[esi+0xa4]',start)
    return original[start:end]

def traced_gravity(source):
    # Observational copy only; untouched F603 is executed separately and all
    # object/debug outputs must agree. MOV/PUSH/POP preserve source flags.
    original=block(source,603).replace('FUNC_000603:','FUNC_998603:')
    original=re.sub(r'JUMP_(\d+)',r'GRAVITY_TRACE_\1',original)
    substitutions=[
        ('\t\tmov [ebp-0x14],eax','\t\tmov [gravity_trace],eax'),
        ('\t\tmov [ebp-0x4],ax','\t\tmov [gravity_trace+4],eax'),
        ('\t\tmov [ebp-0x4],eax','\t\tmov [gravity_trace+8],eax'),
        ('\t\tmov [ebp-0x10],eax','\t\tmov [gravity_trace+12],eax'),
        ('\t\tmov [ebp-0x8],eax','\t\tmov [gravity_trace+20],eax'),
        ('\t\tneg eax\n\t\tmov edx,eax','\t\tmov [gravity_trace+28],eax'),
    ]
    for marker,extra in substitutions:
        if original.count(marker)!=1:raise ValueError('Unexpected trace point '+marker)
        original=original.replace(marker,marker+'\n'+extra)
    marker='\t\tpop ecx\n\t\tpush eax\n\t\tmov eax,[edi+0xa4]'
    if original.count(marker)!=1:raise ValueError('Missing cube trace point')
    original=original.replace(marker,'\t\tpop ecx\n\t\tmov [gravity_trace+16],eax\n\t\tpush eax\n\t\tmov eax,[edi+0xa4]')
    marker='\tGRAVITY_TRACE_002658:'
    original=original.replace(marker,marker+'\n\t\tmov [gravity_trace+24],ebx')
    marker='\t\tmov ax,[ebp-0x6]\n\t\ttest ax,ax'
    if original.count(marker)!=1:raise ValueError('Missing exponent trace point')
    original=original.replace(marker,'\t\tpush eax\n\t\tmovsx eax,word [ebp-0x6]\n\t\tmov [gravity_trace+36],eax\n\t\tpop eax\n'+marker)
    for label,value in [('002659',1),('002660',2)]:
        marker='\tGRAVITY_TRACE_'+label+':'
        original=original.replace(marker,marker+'\n\t\tmov dword [gravity_trace+32],'+str(value))
    return original

def verify_dos_f603(source,executable,folder):
    """Compare all180 DOS/source F603 instructions after encoding-only cleanup.

    Assemble source as32bit without execution/ABI changes. Known original
    callees/globals are linked at their DOS addresses. Branches are compared
    by target instruction ordinal, allowing short/near assembler encodings.
    """
    lines=[]
    for line in block(source,603).splitlines():
        line=line.split(';')[0].strip()
        if not line:continue
        line=re.sub(r'\b(?:near|short)\s+','',line)
        line=re.sub(r'\b(byte|word|dword)\s*\[',lambda m:m[1].upper()+' PTR [',line)
        line=re.sub(r'\b(?:byte|word|dword)\s+(?=[+\-0-9])','',line)
        line=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',line)
        lines.append(line)
    bindings={'FUNC_001658':0x4a8d0,'FUNC_001466':0x41cf7,'FUNC_001482':0x433e1,
              'DATA_007754':0x501840,'DATA_007722':0x501310,'DATA_007731':0x50134c,
              'DATA_008708':0x633ee8,'DATA_008709':0x633eec,'DATA_008710':0x633ef0}
    text='.intel_syntax noprefix\n.code32\n.section .text\n.global FUNC_000603\n'+'\n'.join('.set '+k+','+hex(v) for k,v in bindings.items())+'\n'+'\n'.join(lines)+'\n'
    (folder/'source32.s').write_text(text)
    subprocess.run(['as','--32',str(folder/'source32.s'),'-o',str(folder/'source32.o')],check=True)
    subprocess.run(['ld','-m','elf_i386','-Ttext=0x1b320','-e','FUNC_000603',str(folder/'source32.o'),'-o',str(folder/'source32')],check=True)
    ours=subprocess.check_output(['objdump','-d','-M','intel',str(folder/'source32')],text=True)
    theirs=subprocess.check_output(['objdump','-D','-b','binary','-m','i386','-M','intel','--start-address=0x1b320','--stop-address=0x1b56d',str(executable)],text=True)
    def normalized(disassembly):
        rows=[]
        for line in disassembly.splitlines():
            found=re.match(r'\s*([0-9a-f]+):\t(?:[0-9a-f]{2} ?)+\s*\t([^\n]+)',line)
            if not found:continue
            text=found[2].split(' <')[0];text=re.sub(r'\s+',' ',text).strip()
            text=text.replace('DWORD PTR ds:','ds:')
            text=re.sub(r'^(j[a-z]+|call) 0x',r'\1 ',text)
            rows.append((int(found[1],16),text))
        offsets={at:i for i,(at,_) in enumerate(rows)};result=[]
        for _,text in rows:
            branch=re.match(r'(j[a-z]+) ([0-9a-f]+)$',text)
            if branch:text=branch[1]+' instruction_'+str(offsets[int(branch[2],16)])
            result.append(text)
        return result
    first=normalized(ours);second=normalized(theirs)
    if len(first)!=180 or first!=second:raise ValueError('Pinned F603 instructions differ from uploaded DOS')
    raw=executable.read_bytes()[0x1b320:0x1b56d]
    return {'executable_offset':0x1b320,'byte_length':len(raw),'executable_block_sha256':sha(raw),
            'normalized_instruction_count':len(first),'normalized_instructions_sha256':sha(('\n'.join(first)+'\n').encode()),
            'pinned_f603_matches_uploaded_dos_instructions':True,
            'scope':'Complete F603 instruction/control-flow body only; helpers and runtime variants remain separately pinned',
            'encoding_cleanup':['Equivalent32bit MOV absolute encoding/syntax','Short/near jump target by instruction ordinal','Identical source callees/globals rebound to original DOS addresses'],
            'callee_and_global_bindings':bindings}

def assembly(source):
    sys.path.insert(0,str(PROJECT/'recovered-history/ground_harness/tools'))
    from native_reference import procedures
    mass='''FUNC_998880:
push ebp
mov ebp,esp
add esp,byte -0x4
push ebx
push esi
mov esi,[ebp+0x8]
mov ebx,[ebp+0xc]
'''+f880_mass_slice(source)+'''
pop esi
pop ebx
mov esp,ebp
pop ebp
ret
'''
    selected='\n'.join(block(source,n) for n in NUMBERS)+'\n'+mass+'\n'+traced_gravity(source)+'\nFUNC_999999:\nret\n'
    selected=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',selected)
    lines,hashes=procedures(selected,NUMBERS+[998880,998603])
    # This CRT entry is separately pinned to uploaded DOS bytes. Arithmetic and
    # source register clobbers are transcribed intact; only argument ABI changes.
    text='''.intel_syntax noprefix
.code64
.section .text
.global _start
'''+ '\n'.join(lines)+f'''
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
 mov edi,OFFSET FLAT:body_guard_before
 mov ecx,{OBJECT+32}
 mov al,0xa5
 rep stosb
 mov edi,OFFSET FLAT:bank_guard_before
 mov ecx,{BANK+32}
 mov al,0xa5
 rep stosb
 mov esi,OFFSET FLAT:input+16
 mov edi,OFFSET FLAT:body
 mov ecx,{OBJECT}
 rep movsb
 movzx eax,BYTE PTR [body+0x56]
 imul eax,{OBJECT}
 add eax,OFFSET FLAT:bank+0x74
 mov DWORD PTR [parent_address],eax
 mov edi,eax
 mov esi,OFFSET FLAT:input+{16+OBJECT}
 mov ecx,{OBJECT}
 rep movsb
 mov esi,OFFSET FLAT:bank
 mov edi,OFFSET FLAT:bank_backup
 mov ecx,{BANK}
 rep movsb
 mov DWORD PTR [DATA_008708],0x5a5a5a5a
 mov DWORD PTR [DATA_008709],0x5a5a5a5a
 mov DWORD PTR [DATA_008710],0x5a5a5a5a
 mov edi,OFFSET FLAT:gravity_trace
 mov eax,0xffffffff
 mov ecx,{len(TRACE_FIELDS)}
 rep stosd
 mov DWORD PTR [output+{OBJECT*2+24}],0
 mov esi,OFFSET FLAT:body+0x3e
 mov edi,OFFSET FLAT:output+{OBJECT*2}
 mov ecx,24
 rep movsb
 cmp DWORD PTR [input],1
 je mass_case
 cmp DWORD PTR [input],2
 je integration_case
 cmp DWORD PTR [input],3
 je traced_gravity_case
 mov eax,DWORD PTR [input+4]
 push rax
 push OFFSET FLAT:bank
 push OFFSET FLAT:body
 call FUNC_000603
 add rsp,24
 jmp capture
traced_gravity_case:
 mov eax,DWORD PTR [input+4]
 push rax
 push OFFSET FLAT:bank
 push OFFSET FLAT:body
 call FUNC_998603
 add rsp,24
 jmp capture
mass_case:
 push OFFSET FLAT:input+{16+OBJECT*2}
 mov eax,DWORD PTR [parent_address]
 push rax
 call FUNC_998880
 add rsp,16
 mov eax,DWORD PTR [parent_address]
 mov eax,DWORD PTR [eax+0xa4]
 mov DWORD PTR [output+{OBJECT*2+24}],eax
 # F880 is allowed to write parent.a4; compare the rest of the bank unchanged.
 mov eax,DWORD PTR [parent_address]
 sub eax,OFFSET FLAT:bank
 mov edx,DWORD PTR [parent_address]
 mov edx,DWORD PTR [edx+0xa4]
 mov DWORD PTR [bank_backup+rax+0xa4],edx
 jmp capture
integration_case:
 mov eax,DWORD PTR [input+8]
 push rax
 mov eax,DWORD PTR [input+12]
 push rax
 push OFFSET FLAT:body
 call FUNC_001512
 add rsp,24
 push OFFSET FLAT:input+16+0x8c
 mov eax,DWORD PTR [input+8]
 push rax
 mov eax,DWORD PTR [input+12]
 push rax
 push OFFSET FLAT:output+{OBJECT*2}
 call FUNC_001511
 add rsp,32
capture:
 mov esi,OFFSET FLAT:body
 mov edi,OFFSET FLAT:output
 mov ecx,{OBJECT}
 rep movsb
 mov esi,DWORD PTR [parent_address]
 mov ecx,{OBJECT}
 rep movsb
 mov eax,DWORD PTR [DATA_008708]
 mov DWORD PTR [output+{OBJECT*2+28}],eax
 mov eax,DWORD PTR [DATA_008709]
 mov DWORD PTR [output+{OBJECT*2+32}],eax
 mov eax,DWORD PTR [DATA_008710]
 mov DWORD PTR [output+{OBJECT*2+36}],eax
 mov edi,OFFSET FLAT:output+{OBJECT*2+40}
 mov esi,OFFSET FLAT:body_guard_before
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:body_guard_after
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:bank_guard_before
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:bank_guard_after
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:bank
 mov edi,OFFSET FLAT:bank_backup
 mov ecx,{BANK}
 repe cmpsb
 sete al
 movzx eax,al
 mov DWORD PTR [output+{OBJECT*2+104}],eax
 mov esi,OFFSET FLAT:gravity_trace
 mov edi,OFFSET FLAT:output+{BASE_OUTPUT}
 mov ecx,{len(TRACE_FIELDS)*4}
 rep movsb
 mov esi,OFFSET FLAT:output
 mov edx,{OUTPUT}
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
DATA_007722: .quad FUNC_001496
DATA_007731: .quad FUNC_001483
DATA_007738: .quad FUNC_001502
DATA_007754: .quad FUNC_001532
DATA_008708: .long 0
DATA_008709: .long 0
DATA_008710: .long 0
.section .bss
.balign 16
input: .space {INPUT}
output: .space {OUTPUT}
parent_address: .space 4
gravity_trace: .space {len(TRACE_FIELDS)*4}
.balign 16
body_guard_before: .space 16
body: .space {OBJECT}
body_guard_after: .space 16
.balign 16
bank_guard_before: .space 16
bank: .space {BANK}
bank_guard_after: .space 16
bank_backup: .space {BANK}
.balign 16
stack: .space 524288
stack_end:
.section .note.GNU-stack,"",@progbits
'''
    return text,hashes

def body(position=(0,0,0),velocity=(0,0,0),fractions=(0,0,0),parent=1,seed=0):
    rng=random.Random(seed)
    raw=bytearray(rng.randbytes(OBJECT));raw[0x56]=parent
    struct.pack_into('<3q',raw,0x3e,*position)
    struct.pack_into('<3i',raw,0x8c,*velocity)
    struct.pack_into('<3H',raw,0xec,*fractions)
    return bytes(raw)

def parent(a4=0,seed=1):
    raw=bytearray(random.Random(seed).randbytes(OBJECT));struct.pack_into('<I',raw,0xa4,a4);return bytes(raw)

def packet(mode,row):
    step=row.get('step_s32',0);low,high=row.get('step_words',[0,0])
    return struct.pack('<IiII',mode,step,low,high)+bytes.fromhex(row['body_hex'])+bytes.fromhex(row['parent_hex'])+bytes.fromhex(row.get('record_hex','00'*68))

def mass_cases():
    packed=json.loads((PROJECT/'tests/fixtures/handcrafted_runtime_native.json').read_text())
    rows=[];seen=set()
    for control in packed['cases']:
        if not (control['name'].endswith('/ zero destination') or control['name']=='Unmapped Riedquat diagnostic / zero'):continue
        for raw in control['expected']['records_hex']:
            if raw in seen:continue
            seen.add(raw);rows.append({'name':control['name']+' / '+str(len(rows)),'origin':'actual native F878 output record','record_hex':raw,'body_hex':body(seed=len(rows)).hex(),'parent_hex':parent(seed=len(rows)+1000).hex()})
    for exponent in [-32768,-64,-43,-1,0,1,15,16,31,32,63,32767]:
        for mantissa in [0,1,0x3fff,0x4000,0x7fff]:
            raw=bytearray(68);struct.pack_into('<I',raw,0,((exponent&65535)<<16)|mantissa)
            rows.append({'name':'packed mass boundary %d/%d'%(exponent,mantissa),'origin':'synthetic packed register input','record_hex':raw.hex(),'body_hex':body(seed=len(rows)).hex(),'parent_hex':parent(seed=len(rows)+1000).hex()})
    return rows

def gravity_cases(masses):
    coefficients={row['record_hex']:row['expected_a4_u32'] for row in masses}
    controls=json.loads((PROJECT/'tests/fixtures/source_orbit_native.json').read_text())['epoch_update_cases']
    packed=json.loads((PROJECT/'tests/fixtures/handcrafted_runtime_native.json').read_text())['cases']
    banks={row['name']:row['expected']['records_hex'] for row in packed if row['name'].endswith('/ zero destination') or row['name']=='Unmapped Riedquat diagnostic / zero'}
    rows=[]
    def add(name,position,a4,step,velocity=(0,0,0),fractions=(0,0,0),parent_id=1,origin='synthetic source-register control'):
        rows.append({'name':name,'origin':origin,'body_hex':body(position,velocity,fractions,parent_id,len(rows)).hex(),'parent_hex':parent(a4,len(rows)+5000).hex(),'step_s32':step,'initial_scratch_s32':SCRATCH})
    steps=[0,1,-1,497,2485,49700,-49700,32767,32768,-32768,-32769,0x7fffffff,-0x80000000]
    for row in controls:
        if row['tick_u32']!=0x80000000 or row['day_u32']!=0x121cf7:continue
        record=bytes.fromhex(row['record_hex']);pid=struct.unpack_from('<H',record,8)[0]
        a4=coefficients[banks[row['source_context']][pid-1]] if pid else 0
        for step in [1,497,2485,49700]:
            add(row['source_context']+' / object%d / dt%d'%(row['local_index'],step),[int(x) for x in row['expected']['position_raw']],a4,step,parent_id=pid,origin='native F878/F880 orbital position and native F880 parent coefficient')
    # Explicit guard and signed64 sign-extension cases must reach the norm
    # path with a nonzero parent coefficient (rather than parent-id0 guard).
    earth_record=banks['Sol / zero destination'][4]
    earth_a4=coefficients[earth_record]
    for i,position in enumerate([(0,0,0),(1,0,0),(-1,0,0),
                                  (1<<32,0,0),(-(1<<32),0,0),
                                  (-(1<<32),-(1<<32),-(1<<32)),
                                  (0x80000000,0,0),(-0x80000000,0,0),
                                  (-(1<<63),0,0),((1<<63)-1,0,0)]):
        for step in [0,1,-1,2485,49700]:
            add('zero/sign-extension guard%d / dt%d'%(i,step),position,earth_a4,step,
                fractions=(0xffff,0x8000,1),origin='explicit source norm/sign-extension boundary; native Earth coefficient')
    # These are labelled input probes around the CURRENT analytic Earth radius,
    # not claims that F879's actual surface radius or an SI bridge is restored.
    metres_per_raw=16785/16777216
    for radius_metres in [6371000,12742000,63710000]:
        distance=round(radius_metres/metres_per_raw)
        for direction in [1,-1]:
            for step in [1,497,2485,49700]:
                add('legacy Earth radius input %dm / sign%d / dt%d'%(radius_metres,direction,step),
                    (distance*direction,0,0),earth_a4,step,
                    origin='input-only analytic-radius calibration probe; expected update from native F603')
    for vector in [(8192,8192,8192),(10000,10000,10000),
                   (8192,0,0),(14188,0,0),(16383,0,0),(16384,0,0),
                   (16383,1,0),(16383,200,0),(10000,10000,0),
                   (-8192,-8192,-8192),(-10000,-10000,-10000)]:
        for scale in [1,1<<15,1<<30]:
            add('native norm threshold %s / scale%d'%(vector,scale),tuple(x*scale for x in vector),earth_a4,49700,
                origin='explicit normalization threshold and directional-discontinuity control')
    rng=random.Random(0x6031512)
    positions=[(0,0,0),(1,0,0),(-1,1,0),(8191,-8192,8192),(8192,16384,-32768),(0xffffffff,-0xffffffff,1),((1<<63)-1,-(1<<63),-1),(1<<40,-(1<<41),1<<42)]
    for exponent in [-32768,-40,-16,-1,0,1,15,16,17,31,32,48,63,32767]:
        for i,p in enumerate(positions):
            add('gravity exponent%d / p%d'%(exponent,i),p,((exponent&65535)<<16)|[0,1,0x4000,0x7fff][i%4],steps[(exponent+i)%len(steps)],velocity=[rng.choice([-0x80000000,-1,0,1,0x7fffffff]) for _ in range(3)],fractions=[rng.randrange(65536) for _ in range(3)],parent_id=[0,1,2,17,255][i%5])
    for i in range(512):
        shift=rng.randrange(0,62)
        p=[rng.randrange(-8192,8192)<<shift for _ in range(3)]
        p=[((x+(1<<63))%(1<<64))-(1<<63) for x in p]
        add('full-width position/control %d'%i,p,((rng.randrange(-48,65)&65535)<<16)|rng.choice([0,1,0x3fff,0x4000,0x7fff]),rng.choice(steps),[rng.randrange(-(1<<31),1<<31) for _ in range(3)],[rng.randrange(65536) for _ in range(3)],[0,1,2,17,255][i%5])
    return rows

def integration_cases():
    rng=random.Random(0x15111512);rows=[]
    clocks=[(0,0),(1,0),(127,0),(128,0),(512,0),(49700,0),(0xffffffff,0),(0,1),(0xffffffff,0xffffffff),(0,0x80000000),(0x80000000,0),(0x12345678,0x12345678)]
    velocities=[(0,0,0),(1,-1,2),(-0x80000000,0x7fffffff,-1),(0x10000,-0x10000,0x7fff)]
    for i,words in enumerate(clocks):
        for v in velocities:
            position=tuple(struct.unpack('<3q',rng.randbytes(24)))
            rows.append({'name':'integration clock%d / velocity%d'%(i,len(rows)%len(velocities)),'body_hex':body(position,v,(65535,32768,1),1,len(rows)).hex(),'parent_hex':parent(seed=len(rows)).hex(),'step_words':list(words)})
    for i in range(256):
        rows.append({'name':'integration full-width %d'%i,'body_hex':body(struct.unpack('<3q',rng.randbytes(24)),struct.unpack('<3i',rng.randbytes(12)),[rng.randrange(65536) for _ in range(3)],1,len(rows)).hex(),'parent_hex':parent(seed=len(rows)).hex(),'step_words':[rng.getrandbits(32),rng.getrandbits(32)]})
    return rows

def execute(binary,mode,rows):
    ordered=rows+list(reversed(rows));payload=b''.join(packet(mode,row) for row in ordered)
    outputs=[subprocess.run([str(binary)],input=payload,stdout=subprocess.PIPE,check=True,timeout=45).stdout for _ in range(3)]
    output=outputs[0]
    if len(output)!=len(ordered)*OUTPUT or any(other!=output for other in outputs[1:]):raise ValueError('Native output incomplete/nonrepeatable')
    allowed=set(range(0x8c,0x98))|set(range(0xec,0xf2)) if mode in [0,3] else set(range(0x3e,0x56)) if mode==2 else set()
    for i,row in enumerate(rows):
        raw=output[i*OUTPUT:(i+1)*OUTPUT];reverse=output[(len(ordered)-1-i)*OUTPUT:(len(ordered)-i)*OUTPUT]
        if raw!=reverse:raise ValueError('Native reverse-order state leak')
        if raw[OBJECT*2+40:OBJECT*2+104]!=bytes([0xa5])*64 or struct.unpack_from('<I',raw,OBJECT*2+104)[0]!=1:raise ValueError('Native memory boundary/bank mutation')
        before=bytes.fromhex(row['body_hex']);after=raw[:OBJECT]
        if any(before[j]!=after[j] for j in range(OBJECT) if j not in allowed):raise ValueError('Unrelated object field changed')
        before_parent=bytes.fromhex(row['parent_hex']);after_parent=raw[OBJECT:OBJECT*2]
        parent_allowed=set(range(0xa4,0xa8)) if mode==1 else set()
        if any(before_parent[j]!=after_parent[j] for j in range(OBJECT) if j not in parent_allowed):raise ValueError('Unrelated parent field changed')
        if mode in [0,3]:
            row['expected']={'body_hex':after.hex(),'parent_hex':after_parent.hex(),'velocity_s32':list(struct.unpack_from('<3i',after,0x8c)),'fraction_u16':list(struct.unpack_from('<3H',after,0xec)),'scratch_s32':list(struct.unpack_from('<3i',raw,OBJECT*2+28))}
            if mode==3:
                values=struct.unpack_from('<%dI'%len(TRACE_FIELDS),raw,BASE_OUTPUT)
                row['native_trace']={key:(value-(1<<32) if key in ['normalized_step_s32','factor_s32','final_exponent_s16'] and value>=1<<31 else value) for key,value in zip(TRACE_FIELDS,values)}
        elif mode==1:
            row['expected_a4_u32']=struct.unpack_from('<I',raw,OBJECT*2+24)[0];row['expected_parent_hex']=after_parent.hex()
        else:
            if after[0x3e:0x56]!=raw[OBJECT*2:OBJECT*2+24]:raise ValueError('F1512 and direct F1511 differ')
            words=[list(struct.unpack_from('<2I',after,0x3e+axis*8)) for axis in range(3)]
            row.update(expected_body_hex=after.hex(),expected_position_words=words,expected_position_raw=[str(x) for x in struct.unpack_from('<3q',after,0x3e)],direct_f1511_position_words=words)
    return sha(output),output

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_gravity_native.json');args=p.parse_args()
    asm_raw=args.source.read_bytes();exe=args.executable.read_bytes()
    if sha(asm_raw)!=ASM_SHA or sha(exe)!=EXE_SHA:raise ValueError('Unexpected source revision')
    if exe[0x67038:0x67038+len(ABS_DOS)]!=ABS_DOS:raise ValueError('DOS CRT abs entry differs')
    source=asm_raw.decode().replace('\r\n','\n');text,hashes=assembly(source)
    masses=mass_cases();integrations=integration_cases()
    with tempfile.TemporaryDirectory(prefix='ffe-source-gravity-') as folder:
        folder=Path(folder);(folder/'control.s').write_text(text)
        dos_f603=verify_dos_f603(source,args.executable,folder)
        subprocess.run(['as','--64',str(folder/'control.s'),'-o',str(folder/'control.o')],check=True)
        subprocess.run(['ld','-m','elf_x86_64',str(folder/'control.o'),'-o',str(folder/'control')],check=True)
        mass_digest,_=execute(folder/'control',1,masses)
        gravity=gravity_cases(masses);gravity_digest,ordinary=execute(folder/'control',0,gravity)
        trace_digest,observed=execute(folder/'control',3,gravity)
        for i in range(len(gravity)*2):
            if ordinary[i*OUTPUT:i*OUTPUT+BASE_OUTPUT]!=observed[i*OUTPUT:i*OUTPUT+BASE_OUTPUT]:raise ValueError('Observed gravity differs from untouched F603')
        integration_digest,_=execute(folder/'control',2,integrations)
    mass_proof={'pinned_full_f880_sha256':sha(block(source,880).encode()),'pinned_executed_slice_sha256':sha(f880_mass_slice(source).encode()),'host_entry_sha256':hashes.pop('998880'),'scope':'Exact F880 packed coefficient initialization only; excludes allocation and da frame-selection adjustments'}
    trace_hash=hashes.pop('998603')
    report={'schema':1,'revision':'source-gravity-native-v1','source_variant':VARIANT,'source_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'source_commit':COMMIT,'source_procedure_hashes':hashes,'pinned_procedure_hashes':{str(n):sha(block(source,n).encode()) for n in NUMBERS},'F880_coefficient_slice':mass_proof,'dos_f603_instruction_comparison':dos_f603,'dos_abs_entry':{'file_offset':0x67038,'bytes':ABS_DOS.hex(),'sha256':sha(ABS_DOS)},'native_observation':{'instrumented_copy_sha256':trace_hash,'registers_and_flags_preserved':True,'observed_matches_untouched_complete_outputs':True,'trace_fields':TRACE_FIELDS,'native_output_sha256':trace_digest,'scope':'MOV/PUSH/POP observations of original F603 locals in separately executed source copy; full object, parent, scratch and canary outputs agree with untouched F603 for every case'},'scope':'Complete pinned F603 velocity/fraction update with actual F1532 parent lookup, F880 coefficient slice, complete F1511 and F1512 position integration. No complete world physics/frame selection, surface radius, source timer or SI bridge claim.','host_adaptations':['Original32bit integer arithmetic retained; original stack arguments expanded to64bit host slots','All pointers/source-layout object bank/BSS stack below2GiB','DOS CRT abs instruction sequence transcribed with host argument ABI; exact original bytes pinned','Isolated full256slot F1532 object bank initialized/canary checked; actual lookup instructions executed','Separately instrumented F603 copy observes original locals using register/flag preserving memory writes; outputs compared with untouched source'],'object_bytes':OBJECT,'object_bank_stride_bytes':OBJECT,'object_bank_header_bytes':0x74,'object_state_offsets':{'position_signed64_xyz':0x3e,'parent_index_u8':0x56,'velocity_signed32_xyz':0x8c,'gravity_coefficient_packed':0xa4,'velocity_fraction_u16_xyz':0xec},'case_count':len(gravity),'mass_case_count':len(masses),'integration_case_count':len(integrations),'fresh_process_runs':3,'reverse_repeat_count':len(gravity),'mass_reverse_repeat_count':len(masses),'integration_reverse_repeat_count':len(integrations),'object_canaries_unchanged':True,'parent_bank_unchanged_except_mass_initializer':True,'non_target_object_bytes_unchanged':True,'native_gravity_output_sha256':gravity_digest,'native_mass_output_sha256':mass_digest,'native_integration_output_sha256':integration_digest,'adapted_assembly_sha256':sha(text.encode()),'input_fixtures_sha256':{name:sha((PROJECT/name).read_bytes()) for name in ['tests/fixtures/handcrafted_runtime_native.json','tests/fixtures/source_orbit_native.json']},'cases':gravity,'mass_cases':masses,'integration_cases':integrations}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(report,separators=(',',':'))+'\n')
    print(json.dumps({'fixture':str(args.output),'case_count':len(gravity),'mass_case_count':len(masses),'integration_case_count':len(integrations),'sha256':sha(args.output.read_bytes())},indent=2))

if __name__=='__main__':main()
