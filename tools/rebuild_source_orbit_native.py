#!/usr/bin/env python3
"""Independent host execution of the pinned JJFFE Q31 orbital kernel.

The position kernel differs from uploaded DOS FFE. This tool makes that variant
explicit: F1506/F1509/F1510 match the DOS algorithms, while F1507/F1508
are JJFFE's higher-precision implementation. No Python orbital expectation is
used. Native integer instructions produce every expected rate/phase/position.
"""
from __future__ import annotations
import argparse, hashlib, json, random, re, struct, subprocess, sys, tempfile
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
SIN_SIGNATURE=bytes.fromhex('000000003f2403007e480600be6c0900fd900c003db50f007cd91200bbfd1500')
VARIANT='jjffe-7e54034-q31-orbit'
INPUT=108
OBJECT=512
OUTPUT=20+OBJECT*2+32
NUMBERS=[1333,1338,1341,1483,1494,1496,1506,1507,1508,1509,1510,1521,1661,1914]

def sha(raw):return hashlib.sha256(raw).hexdigest()

def block(source,number):
    start=re.search(r'^FUNC_%06d(?:_[A-Za-z0-9_]+)?:'%number,source,re.M)
    if not start:raise ValueError('Missing procedure '+str(number))
    end=re.search(r'^(?:FUNC_\d+(?:_[A-Za-z0-9_]+)?|_[A-Za-z0-9_]+):',source[start.end():],re.M)
    return source[start.start():start.end()+end.start() if end else len(source)]

def f880_slice(source):
    original=block(source,880)
    start=original.index('\t\tmov word [ebp-0x4],0x5460',original.index('JUMP_003675:'))
    end=original.index('\t\tmovsx eax,byte [esi+0xc8]',start)
    return original[start:end]

def f866_orbital_slice(source):
    original=block(source,866)
    start=original.index('\t\tmov eax,[ebp+0x8]')
    flags=original.index('\t\ttest byte [ebx+0x14c],0x20',start)
    orbit=original.index('\tJUMP_003590:',flags)
    end=original.index('\tJUMP_003592:',orbit)
    # Select the ordinary orbital branch only. Shield/ship flags and surface
    # rotation are outside this kernel and are not replaced by fake helpers.
    return original[start:flags]+original[orbit:end]+'JUMP_003592:\n'

def cases():
    fixture=json.loads((PROJECT/'tests/fixtures/handcrafted_runtime_native.json').read_text())
    rows=[]
    times=[(0,0),(0x80000000,0x121cf7),(0xffffffff,0x121cf7),
           (0,0x121cf8),(1,1),(0x12345678,0x121e64),(0xffffffff,0xffffffff),
           (0xc0000000,0x121cf7),(0xc0000000,0x121e64),(0x80000000,0x13a397)]
    rng=random.Random(0x15071510)
    for control in fixture['cases']:
        if not (control['name'].endswith('/ zero destination') or control['name']=='Unmapped Riedquat diagnostic / zero'):continue
        if 'source_global_indices' not in control:continue
        for local,global_index in enumerate(control['source_global_indices']):
            raw=bytes.fromhex(control['expected']['records_hex'][local])
            if struct.unpack_from('<H',raw,10)[0]==35:continue
            for tick,day in times:
                rows.append({'origin':'native F878 packed source record','source_context':control['name'],'system_id':control.get('system_id'),'global_index':global_index,'local_index':local,'record_hex':raw.hex(),'tick_u32':tick,'day_u32':day,'interpolation_delta_u32':rng.choice([0,1,0xffff,0x10000,0xfffff,0xffffffff]),'direct_rate_u32':rng.getrandbits(32),'old_tick_u32':rng.getrandbits(32),'old_day_u32':rng.getrandbits(32),'new_tick_u32':tick,'new_day_u32':day})
    # Register-width controls intentionally include unusual orbital exponents,
    # but never a negative period mantissa: original F1496(0x8000) would loop.
    exponents=[-32768,-65,-64,-63,-33,-32,-31,-1,0,1,15,16,31,32,33,45,46,47,49,50,63,64,65,127,32767]
    phases=[0,1,0x7fff,0x8000,0xffff]
    for i in range(640):
        raw=bytearray(68)
        orbit=((exponents[i%len(exponents)]&65535)<<16)|rng.choice([0,1,0x3fff,0x4000,0x7fff,0x8000,0xffff])
        period=((rng.choice(exponents)&65535)<<16)|rng.choice([0,1,0x3fff,0x4000,0x7fff])
        struct.pack_into('<H',raw,10,3);struct.pack_into('<I',raw,14,orbit);struct.pack_into('<H',raw,18,phases[i%len(phases)]);struct.pack_into('<I',raw,20,period);struct.pack_into('<H',raw,34,rng.choice([0,1,0x7fff,0x8000,0xffff]))
        tick,day=times[i%len(times)]
        rows.append({'origin':'synthetic source-register boundary','record_hex':raw.hex(),'tick_u32':tick,'day_u32':day,'interpolation_delta_u32':rng.choice([0,1,0xffff,0x10000,0xfffff,0x100000,0x7fffffff,0x80000000,0xffffffff]),'direct_rate_u32':rng.choice([0,1,0x7fffffff,0x80000000,0xffffffff]),'old_tick_u32':rng.getrandbits(32),'old_day_u32':rng.getrandbits(32),'new_tick_u32':rng.getrandbits(32),'new_day_u32':rng.getrandbits(32)})
    return rows

def vector_add_cases(controls, output):
    """Inputs only: expected sums are always produced by actual F1661."""
    rows=[]
    for first,second in [([0,0,0],[0,0,0]),
                         ([0xffffffff,-0xffffffff,-(1<<63)],[1,-1,-1]),
                         ([(1<<63)-1,-(1<<63),-1],[1,-1,1]),
                         ([-1,0x100000000,0x7fffffff],[0x100000000,-0x100000000,0x80000001])]:
        rows.append({'origin':'signed64 carry and overflow input','parent_raw':[str(x) for x in first],'relative_raw':[str(x) for x in second]})
    lookup={(r.get('system_id'),r.get('local_index'),r['tick_u32'],r['day_u32']):i for i,r in enumerate(controls) if r['origin']=='native F878 packed source record' and r.get('system_id') is not None}
    for i,row in enumerate(controls):
        if row.get('system_id')!=44341016 or row.get('local_index') not in [15,22,52]:continue
        parent=struct.unpack_from('<H',bytes.fromhex(row['record_hex']),8)[0]-1
        index=lookup[(row['system_id'],parent,row['tick_u32'],row['day_u32'])]
        first=struct.unpack_from('<3q',output,index*OUTPUT+20+0x3e)
        second=struct.unpack_from('<3q',output,i*OUTPUT+20+0x3e)
        rows.append({'origin':'actual native source parent and child relative position','system_id':row['system_id'],'parent_global_index':controls[index]['global_index'],'child_global_index':row['global_index'],'tick_u32':row['tick_u32'],'day_u32':row['day_u32'],'parent_raw':[str(x) for x in first],'relative_raw':[str(x) for x in second]})
    rng=random.Random(0x16611333)
    for _ in range(16):
        values=struct.unpack('<6q',struct.pack('<12I',*(rng.getrandbits(32) for _ in range(12))))
        rows.append({'origin':'signed64 full-width input','parent_raw':[str(x) for x in values[:3]],'relative_raw':[str(x) for x in values[3:]]})
    return rows

def vector_packet(row):
    values=[int(x) for field in ['parent_raw','relative_raw'] for x in row[field]]
    return struct.pack('<6q',*values)+bytes(52)+struct.pack('<I',1)+bytes(4)

def epoch_cases(controls):
    clocks={(0x80000000,0x121cf7),(0xc0000000,0x121cf7),
            (0xc0000000,0x121e64),(0x80000000,0x13a397),
            (0xffffffff,0xffffffff)}
    keys=['origin','source_context','system_id','global_index','local_index',
          'record_hex','tick_u32','day_u32']
    result=[]
    for row in controls:
        if row['origin']!='native F878 packed source record' or (row['tick_u32'],row['day_u32']) not in clocks:continue
        item={key:row[key] for key in keys}
        item.update(epoch_tick_u32=0x80000000,epoch_day_u32=0x121cf7,
                    intermediate_tick_u32=0xa0000000,intermediate_day_u32=0x121cf7)
        result.append(item)
    return result

def epoch_packet(row,stepped=False):
    fields=[row['tick_u32'],row['day_u32'],0,row['epoch_tick_u32'],row['epoch_day_u32'],
            row['intermediate_tick_u32'] if stepped else row['tick_u32'],
            row['intermediate_day_u32'] if stepped else row['day_u32'],0]
    return bytes.fromhex(row['record_hex'])+struct.pack('<8I',*fields)+struct.pack('<I',3 if stepped else 2)+bytes(4)

def assembly(source):
    sys.path.insert(0,str(PROJECT/'recovered-history/ground_harness/tools'))
    from native_reference import procedures
    # Execute the source initializer itself, including its unusual timestamp
    # argument order; Python does not reconstruct or correct this instruction
    # sequence. Only entry/exit and low-address pointers are host scaffolding.
    sliced_function='''FUNC_998880:
push ebp
mov ebp,esp
add esp,byte -0x10
push ebx
push esi
mov esi,[ebp+0x8]
mov ebx,[ebp+0xc]
'''+f880_slice(source)+'''
pop esi
pop ebx
mov esp,ebp
pop ebp
ret
'''
    advance_function='''FUNC_998866:
push ebp
mov ebp,esp
add esp,byte -0x20
push ebx
push esi
push edi
'''+f866_orbital_slice(source)+'''
pop edi
pop esi
pop ebx
mov esp,ebp
pop ebp
ret
'''
    selected='\n'.join(block(source,n) for n in NUMBERS)+'\n'+sliced_function+advance_function+'\nFUNC_999999:\nret\n'
    selected=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',selected)
    lines,hashes=procedures(selected,NUMBERS+[998880,998866])
    text='\n'.join(lines)
    # F1510 releases its eight local bytes through two scratch-register pops.
    # The host has eight-byte pops, so reserve sixteen bytes for this frame;
    # the original local offsets and every arithmetic instruction stay intact.
    old_frame='FUNC_001510:\npush rbp\nmov rbp,rsp\nadd rsp,-8'
    if text.count(old_frame)!=1:raise ValueError('Unexpected F1510 adapter frame')
    text=text.replace(old_frame,'FUNC_001510:\npush rbp\nmov rbp,rsp\nadd rsp,-16')
    # The review adapter expands pushes to8bytes. F1496 mutates its argument
    # WORDs in-place; those byte offsets stayinside the adapted argument slot.
    head='''.intel_syntax noprefix
.code64
.section .text
.global _start
'''+text+f'''
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
 mov edi,OFFSET FLAT:guard_before
 mov ecx,{OBJECT+32}
 mov al,0xa5
 rep stosb
 cmp DWORD PTR [input+100],1
 je vector_add_case
 mov eax,DWORD PTR [input+14]
 mov DWORD PTR [object+0xb0],eax
 cmp DWORD PTR [input+100],2
 jae initialize_epoch
 mov eax,DWORD PTR [input+72]
 push rax
 mov eax,DWORD PTR [input+68]
 push rax
 jmp initialize_record
initialize_epoch:
 mov eax,DWORD PTR [input+84]
 push rax
 mov eax,DWORD PTR [input+80]
 push rax
initialize_record:
 push OFFSET FLAT:input
 push OFFSET FLAT:object
 call FUNC_998880
 add rsp,32
 mov eax,DWORD PTR [object+0xc2]
 mov DWORD PTR [output],eax
 mov eax,DWORD PTR [object+0xba]
 mov DWORD PTR [output+4],eax
 mov eax,DWORD PTR [object+0xbe]
 mov DWORD PTR [output+8],eax
 mov esi,OFFSET FLAT:object
 mov edi,OFFSET FLAT:output+20
 mov ecx,{OBJECT}
 rep movsb
 cmp DWORD PTR [input+100],2
 jae advance_epoch
 mov eax,DWORD PTR [input+76]
 push rax
 push OFFSET FLAT:object
 call FUNC_001508
 add rsp,16
 jmp snapshot_updated
advance_epoch:
 mov DWORD PTR [context+8],OFFSET FLAT:object
 cmp DWORD PTR [input+100],3
 jne advance_final
 mov eax,DWORD PTR [input+88]
 mov DWORD PTR [context],eax
 mov eax,DWORD PTR [input+92]
 mov DWORD PTR [context+4],eax
 push OFFSET FLAT:context
 call FUNC_998866
 add rsp,8
advance_final:
 mov eax,DWORD PTR [input+68]
 mov DWORD PTR [context],eax
 mov eax,DWORD PTR [input+72]
 mov DWORD PTR [context+4],eax
 push OFFSET FLAT:context
 call FUNC_998866
 add rsp,8
 mov eax,DWORD PTR [object+0xba]
 mov DWORD PTR [output+4],eax
 mov eax,DWORD PTR [object+0xbe]
 mov DWORD PTR [output+8],eax
snapshot_updated:
 mov esi,OFFSET FLAT:object
 mov edi,OFFSET FLAT:output+{20+OBJECT}
 mov ecx,{OBJECT}
 rep movsb
 mov eax,DWORD PTR [input+88]
 push rax
 mov eax,DWORD PTR [input+92]
 push rax
 mov eax,DWORD PTR [input+80]
 push rax
 mov eax,DWORD PTR [input+84]
 push rax
 mov eax,DWORD PTR [input+96]
 push rax
 push OFFSET FLAT:output+12
 call FUNC_001510
 add rsp,48
 jmp capture_guards
vector_add_case:
 mov edi,OFFSET FLAT:output
 mov ecx,20
 xor eax,eax
 rep stosb
 mov esi,OFFSET FLAT:input
 mov edi,OFFSET FLAT:object+0x3e
 mov ecx,24
 rep movsb
 push OFFSET FLAT:input+24
 push OFFSET FLAT:object+0x3e
 call FUNC_001661
 add rsp,16
 mov esi,OFFSET FLAT:object
 mov edi,OFFSET FLAT:output+20
 mov ecx,{OBJECT}
 rep movsb
 mov esi,OFFSET FLAT:object
 mov edi,OFFSET FLAT:output+{20+OBJECT}
 mov ecx,{OBJECT}
 rep movsb
capture_guards:
 mov esi,OFFSET FLAT:guard_before
 mov edi,OFFSET FLAT:output+{20+OBJECT*2}
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:guard_after
 mov ecx,16
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
DATA_007733: .quad FUNC_001494
DATA_007740: .quad FUNC_001506
DATA_007741: .quad FUNC_001507
DATA_007742: .quad FUNC_001508
DATA_007743: .quad FUNC_001510
DATA_007975: .incbin "sine.bin"
.section .bss
.balign 16
input: .space {INPUT}
output: .space {OUTPUT}
context: .space 12
.balign 16
guard_before: .space 16
object: .space {OBJECT}
guard_after: .space 16
.balign 16
stack: .space 524288
stack_end:
.section .note.GNU-stack,"",@progbits
'''
    return head,hashes

def packet(row):
    fields=['tick_u32','day_u32','interpolation_delta_u32','old_tick_u32','old_day_u32','new_tick_u32','new_day_u32','direct_rate_u32']
    raw=bytes.fromhex(row['record_hex'])+struct.pack('<8I',*(row[k] for k in fields))
    return raw+bytes(INPUT-len(raw))

def words(data,offset,count):return list(struct.unpack_from('<%dI'%count,data,offset))

def position(data,offset):return [words(data,offset+i*8,2) for i in range(3)]

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_orbit_native.json');args=p.parse_args()
    original=args.executable.read_bytes();source_raw=args.source.read_bytes();source=source_raw.decode().replace('\r\n','\n')
    if sha(original)!=EXE_SHA or sha(source_raw)!=ASM_SHA:raise ValueError('Unexpected original source revision')
    at=original.find(SIN_SIGNATURE)
    if at<0 or original.find(SIN_SIGNATURE,at+1)>=0:raise ValueError('Original sine table is not unique')
    sine=original[at:at+65536]
    if len(sine)!=65536:raise ValueError('Truncated source sine table')
    # These signatures distinguish actual DOS routines from JJFFE replacements.
    dos={}
    signatures={1506:(0x43a8c,0x43aed,'558bec5356578b75108b7d0c8b5d08'),1507:(0x43aed,0x43be9,'558bec83c4d0535657'),1508:(0x43be9,0x43c90,'558bec83c4d0538b5d08'),1509:(0x43c90,0x43ce2,'558bec83c4f0538b5d08'),1510:(0x43ce2,0x43d2c,'558bec83c4f8538b4d1c')}
    for n,(offset,end,signature) in signatures.items():
        expected=bytes.fromhex(signature)
        if original[offset:offset+len(expected)]!=expected:raise ValueError('DOS variant signature mismatch '+str(n))
        dos[str(n)]={'executable_offset':offset,'byte_length':end-offset,'executable_block_sha256':sha(original[offset:end]),'entry_signature':signature,'entry_signature_sha256':sha(expected),'matches_pinned_algorithm':n in [1506,1509,1510]}
    f880_offset=0x2ae31;f880_end=0x2aed8
    f880_signature=bytes.fromhex('66c745fc605466c745feeeff8b431450')
    if original[f880_offset:f880_offset+len(f880_signature)]!=f880_signature:raise ValueError('DOS F880 rate slice signature mismatch')
    f880_proof={'executable_offset':f880_offset,'byte_length':f880_end-f880_offset,
                'entry_signature':f880_signature.hex(),
                'executable_block_sha256':sha(original[f880_offset:f880_end]),
                'pinned_executed_slice_sha256':sha(f880_slice(source).encode()),
                'phase_call_word_order':'source F880 passes day as low and tick as high; source F866 delta uses ordinary tick-low/day-high order',
                'pinned_full_f880_sha256':sha(block(source,880).encode())}
    controls=cases();ordered=controls+list(reversed(controls));payload=b''.join(packet(row) for row in ordered)
    with tempfile.TemporaryDirectory(prefix='ffe-source-orbit-native-') as folder:
        folder=Path(folder);(folder/'sine.bin').write_bytes(sine);text,hashes=assembly(source);(folder/'control.s').write_text(text)
        subprocess.run(['as','--64',str(folder/'control.s'),'-o',str(folder/'control.o')],cwd=folder,check=True)
        subprocess.run(['ld','-m','elf_x86_64',str(folder/'control.o'),'-o',str(folder/'control')],check=True)
        outputs=[subprocess.run([str(folder/'control')],input=payload,stdout=subprocess.PIPE,check=True,timeout=30).stdout for _ in range(3)]
        vectors=vector_add_cases(controls,outputs[0]);vector_ordered=vectors+list(reversed(vectors))
        vector_payload=b''.join(vector_packet(row) for row in vector_ordered)
        vector_outputs=[subprocess.run([str(folder/'control')],input=vector_payload,stdout=subprocess.PIPE,check=True,timeout=30).stdout for _ in range(3)]
        epochs=epoch_cases(controls)
        epoch_packets=[epoch_packet(row) for row in epochs]+[epoch_packet(row,True) for row in epochs]
        epoch_payload=b''.join(epoch_packets+list(reversed(epoch_packets)))
        epoch_outputs=[subprocess.run([str(folder/'control')],input=epoch_payload,stdout=subprocess.PIPE,check=True,timeout=30).stdout for _ in range(3)]
    output=outputs[0]
    if any(x!=output for x in outputs[1:]) or len(output)!=len(ordered)*OUTPUT:raise ValueError('Incomplete or inconsistent native run')
    changed=set(range(0x3e,0x56))|set(range(0x8c,0x98))|set(range(0xa8,0xb4))|set(range(0xba,0xc8))
    for i,row in enumerate(controls):
        data=output[i*OUTPUT:(i+1)*OUTPUT];reverse=output[(len(ordered)-1-i)*OUTPUT:(len(ordered)-i)*OUTPUT]
        if data!=reverse:raise ValueError('Native state leaked between contexts')
        if data[-32:]!=bytes([0xa5])*32:raise ValueError('Native object canary changed')
        initial=data[20:20+OBJECT];interpolated=data[20+OBJECT:20+OBJECT*2]
        if any(initial[j]!=0xa5 for j in range(OBJECT) if j not in changed):raise ValueError('Unrelated object byte changed')
        if any(initial[j]!=interpolated[j] for j in range(OBJECT) if j not in range(0x3e,0x56)):raise ValueError('F1508 changed unrelated state')
        row['expected']={'rate_u32':words(data,0,1)[0],'phase_words':words(data,4,2),'phase_delta_words':words(data,12,2),'position_words':position(initial,0x3e),'position_raw':[str(x) for x in struct.unpack_from('<3q',initial,0x3e)],'increment_words':words(initial,0x8c,3),'interpolated_position_words':position(interpolated,0x3e),'initial_object_hex':initial.hex(),'interpolated_object_hex':interpolated.hex(),'initial_object_sha256':sha(initial),'interpolated_object_sha256':sha(interpolated)}
    vector_output=vector_outputs[0]
    if any(x!=vector_output for x in vector_outputs[1:]) or len(vector_output)!=len(vector_ordered)*OUTPUT:raise ValueError('Inconsistent native vector-add run')
    for i,row in enumerate(vectors):
        data=vector_output[i*OUTPUT:(i+1)*OUTPUT]
        reverse=vector_output[(len(vector_ordered)-1-i)*OUTPUT:(len(vector_ordered)-i)*OUTPUT]
        if data!=reverse or data[-32:]!=bytes([0xa5])*32:raise ValueError('Native vector-add state or canary changed')
        initial=data[20:20+OBJECT]
        if initial!=data[20+OBJECT:20+OBJECT*2] or any(initial[j]!=0xa5 for j in range(OBJECT) if j not in range(0x3e,0x56)):raise ValueError('Vector-add changed unrelated object bytes')
        packed=vector_packet(row)
        row['parent_words']=position(packed,0);row['relative_words']=position(packed,24)
        row['expected_words']=position(initial,0x3e)
        row['expected_raw']=[str(x) for x in struct.unpack_from('<3q',initial,0x3e)]
        row['expected_object_hex']=initial.hex()
    epoch_output=epoch_outputs[0]
    if any(x!=epoch_output for x in epoch_outputs[1:]) or len(epoch_output)!=len(epochs)*4*OUTPUT:raise ValueError('Inconsistent native epoch-update run')
    for i,row in enumerate(epochs):
        direct=epoch_output[i*OUTPUT:(i+1)*OUTPUT]
        stepped_at=len(epochs)+i
        stepped=epoch_output[stepped_at*OUTPUT:(stepped_at+1)*OUTPUT]
        for offset,data in [(i,direct),(stepped_at,stepped)]:
            reverse_at=len(epochs)*4-1-offset
            reverse=epoch_output[reverse_at*OUTPUT:(reverse_at+1)*OUTPUT]
            if data!=reverse or data[-32:]!=bytes([0xa5])*32:raise ValueError('Native epoch-update state or canary changed')
        initial=direct[20:20+OBJECT];updated=direct[20+OBJECT:20+OBJECT*2]
        if updated!=stepped[20+OBJECT:20+OBJECT*2] or direct[0:12]!=stepped[0:12]:raise ValueError('Native single-step and stepped epoch progression differ')
        if any(initial[j]!=0xa5 for j in range(OBJECT) if j not in changed):raise ValueError('Epoch initialization changed unrelated object byte')
        update_fields=set(range(0x3e,0x56))|set(range(0x8c,0x98))|set(range(0xa8,0xb0))|set(range(0xba,0xc2))
        if any(initial[j]!=updated[j] for j in range(OBJECT) if j not in update_fields):raise ValueError('F866 orbital slice changed unrelated object byte')
        row['expected']={'rate_u32':words(direct,0,1)[0],'phase_words':words(direct,4,2),
                         'position_words':position(updated,0x3e),
                         'position_raw':[str(x) for x in struct.unpack_from('<3q',updated,0x3e)],
                         'increment_words':words(updated,0x8c,3),
                         'initial_phase_words':words(initial,0xba,2),
                         'initial_object_hex':initial.hex(),'updated_object_hex':updated.hex(),
                         'stepped_matches_direct':True}
    source_rows=[r for r in controls if r['origin']=='native F878 packed source record']
    f880_proof['host_entry_sha256']=hashes.pop('998880')
    f866_proof={'pinned_executed_orbital_slice_sha256':sha(f866_orbital_slice(source).encode()),
                'pinned_full_f866_sha256':sha(block(source,866).encode()),
                'host_entry_sha256':hashes.pop('998866'),
                'scope':'Ordinary orbital branch including phase add and pinned JJFFE recompute/interpolate dispatch; excludes selection by ship flags, shields and surface rotation',
                'position_dispatch':'Pinned JJFFE jump recomputes F1507 whenever phase high word changes; F1508 interpolation arm remains present but unreachable in this pinned source'}
    report={
        'schema':1,'revision':'source-orbit-native-jjffe-q31-v1','source_variant':VARIANT,
        'source_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,
        'source_commit':'7e540341d4e09aa3c92877b87d49e7f2c143ad8d',
        'source_procedure_hashes':hashes,
        'pinned_procedure_hashes':{str(n):sha(block(source,n).encode()) for n in NUMBERS},
        'dos_entry_signatures':dos,
        'dos_f880_rate_and_initialization_slice':f880_proof,
        'pinned_f866_ordinary_orbital_slice':f866_proof,
        'packed_record_fixture':'tests/fixtures/handcrafted_runtime_native.json',
        'packed_record_fixture_sha256':sha((PROJECT/'tests/fixtures/handcrafted_runtime_native.json').read_bytes()),
        'scope':('Pinned JJFFE F1507/F1508 Q31 position/interpolation, original F1506 '
                 'radial and F1509/F1510 phase algorithms, the exact F880 rate/init slice, '
                 'direct F1661 vector addition, and the ordinary pinned F866 orbital update slice. Position variant differs from uploaded '
                 'DOS and is explicitly identified; no full F866 body policy, F880 allocation, '
                 'F1677 hierarchy traversal, radius, gravity or SI claim.'),
        'host_adaptations':['32bit stack arguments expanded to64bit host slots',
                            'original32bit computations retained',
                            'pointers and BSS stack below2GiB',
                            'F1510 local reservation8 to16bytes for two64bit scratch pops; local offsets retained'],
        'case_count':len(controls),'source_record_context_count':len(source_rows),
        'source_record_count':len({(r['source_context'],r['global_index']) for r in source_rows}),
        'vector_add_case_count':len(vectors),
        'epoch_update_case_count':len(epochs),
        'ordinary_epoch_tick_u32':0x80000000,'ordinary_epoch_day_u32':0x121cf7,
        'object_state_offsets':{'position_signed64_xyz':0x3e,'increment_u32_xyz':0x8c,
                                'tick_u32':0xa8,'day_u32':0xac,'orbit_packed':0xb0,
                                'phase_words':0xba,'rate_u32':0xc2,'inclination_s16':0xc6},
        'fresh_process_runs':3,'vector_add_fresh_process_runs':3,
        'epoch_update_fresh_process_runs':3,
        'reverse_repeat_count':len(controls),'vector_add_reverse_repeat_count':len(vectors),
        'epoch_update_reverse_repeat_count':len(epochs)*2,
        'epoch_single_step_matches_stepped':True,
        'object_canaries_unchanged':True,'non_target_object_bytes_unchanged':True,
        'native_ordered_output_sha256':sha(output),
        'native_vector_add_output_sha256':sha(vector_output),
        'native_epoch_update_output_sha256':sha(epoch_output),
        'adapted_assembly_sha256':sha(text.encode()),'sine_sha256':sha(sine),
        'cases':controls,'vector_add_cases':vectors,'epoch_update_cases':epochs,
    }
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(report,separators=(',',':'))+'\n')
    print(json.dumps({'fixture':str(args.output),'case_count':len(controls),'sha256':sha(args.output.read_bytes()),'native_output_sha256':sha(output),'source_variant':VARIANT},indent=2))

if __name__=='__main__':main()
