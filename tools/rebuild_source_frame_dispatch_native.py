#!/usr/bin/env python3
"""Whole DOS F568/F569/F570 caller with real frame rotations/cache arithmetic.

F575 is an explicitly observed mutable callback boundary. Scripted replies are
fixture inputs, not Python collision results or an implementation of F575.
Default replay needs only the captured source proof and reviewed host kernel.
"""
from __future__ import annotations
import argparse, copy, hashlib, importlib.util, inspect, json, random, re, struct, subprocess, tempfile
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
PROOF=PROJECT/'validation/player-dispatch-2026-11-17/frame-native-proof'
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
PROFILE='dos-firstenc-f569-f570-trace-v1'
OBJECT=338;BANK=0x74+115*OBJECT;MAX_CALLS=115;SCRIPT_BYTES=72;TRACE_BYTES=1488
INPUT=64+OBJECT+BANK+MAX_CALLS*SCRIPT_BYTES
OUTPUT=80+OBJECT+BANK+MAX_CALLS*TRACE_BYTES+64
NUMBERS=[568,569,570,572,573,1333,1335,1517,1521,1531,1532,1657,1658,1660,1661,1662,1663,1669,1670,1672,1673,1677,1678]
FIELDS=[('collision_flags_u8',8696,1),('volume_flags_u8',8697,1),('collider_index_u8',8698,1),
 ('collision_active_u8',8699,1),('collision_enabled_u8',8700,1),('primitive_flags_u8',8701,1),
 ('collider_ref_u32',8702,4),('altitude_low_u32',8703,4),('altitude_high_s32',8704,4),
 ('previous_altitude_low_u32',8705,4),('previous_altitude_high_s32',8706,4),('collision_kind_u8',8707,1)]

def sha(raw):return hashlib.sha256(raw).hexdigest()
def s32(value):return (value&0x7fffffff)-(value&0x80000000)
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def capture(base,offset):
    lines=[]
    for i,(name,symbol,size) in enumerate(FIELDS):
        lines.append(('movzx eax,BYTE PTR ' if size==1 else 'mov eax,DWORD PTR ')+f'[DATA_{symbol:06d}]')
        if name=='collider_ref_u32':lines.append('call encode_ref')
        lines.append(f'mov DWORD PTR [{base}+{offset+i*4}],eax')
    return '\n'.join(lines)
def initialize_globals():
    lines=[]
    for i,(name,symbol,size) in enumerate(FIELDS):
        lines.append(f'mov eax,DWORD PTR [input+{16+i*4}]')
        if name=='collider_ref_u32':lines.append('call decode_ref')
        lines.append(f'mov {"BYTE" if size==1 else "DWORD"} PTR [DATA_{symbol:06d}],'+('al' if size==1 else 'eax'))
    return '\n'.join(lines)
def apply_globals():
    lines=[]
    for i,(name,symbol,size) in enumerate(FIELDS):
        lines += [f'test DWORD PTR [r9],{1<<i}',f'jz script_global_done_{i}',f'mov eax,DWORD PTR [r9+{4+i*4}]']
        if name=='collider_ref_u32':lines.append('call decode_ref')
        lines += [f'mov {"BYTE" if size==1 else "DWORD"} PTR [DATA_{symbol:06d}],'+('al' if size==1 else 'eax'),f'script_global_done_{i}:']
    return '\n'.join(lines)

def reprove(args):
    n=load('frame_dispatch_original_proof',PROJECT/'tools/rebuild_source_natural_contact_native.py')
    source=args.source.read_text();raw=args.exe.read_bytes();data=args.data.read_text()
    if sha(raw)!=EXE_SHA or sha(args.source.read_bytes())!=ASM_SHA:raise ValueError('Unsupported original source')
    ns=dict(n.__dict__)
    method=inspect.getsource(n.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_000570',0x4272a0)")
    method=method.replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
    exec(method,ns)
    bodies,records,dis,callbacks,aliases=ns['proof'](source,data,raw,args.exe,NUMBERS)
    selected='\n'.join(bodies[n] for n in NUMBERS)+'\nFUNC_999999:\nret\n'
    selected=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',selected)
    selected=re.sub(r'add esp,0x(f[0-9a-f]{7})',lambda m:'add esp,-0x%x'%(0x100000000-int(m[1],16)),selected)
    lines,_=n.Q.procedures(selected,NUMBERS);text='\n'.join(lines)
    for number in (1669,1670):
        before=f'FUNC_{number:06d}:\npush rbp\nmov rbp,rsp\nadd rsp,-8'
        if text.count(before)!=1:raise ValueError('Changed two-pop scratch frame')
        text=text.replace(before,before.replace('rsp,-8','rsp,-16'))
    kernel='.intel_syntax noprefix\n.code64\n.section .text\n.global _start\n'+text+'\n'+wrapper()
    PROOF.mkdir(parents=True,exist_ok=True)
    for number,body in dis.items():(PROOF/f'dos-F{number}.txt').write_text(body)
    (PROOF/'source-procedures.asm').write_text(selected)
    (PROOF/'frame-dispatch-observed-kernel.s').write_text(kernel)
    meta={'schema':'starfrontier-source-frame-dispatch-instruction-proof-v1','source_executable_sha256':EXE_SHA,
      'source_assembly_sha256':ASM_SHA,'whole_procedure_instruction_equality':records,'original_callback_words':callbacks,
      'original_symbol_addresses':aliases,'source_procedure_sha256':{str(k):sha(v.encode())for k,v in bodies.items()},
      'host_assembly_sha256':sha(kernel.encode()),'source_procedures_sha256':sha(selected.encode()),
      'host_adaptations':['Whole original32-bit DOS instruction equality before host adaptation',
        'Reviewed64-bit cdecl stack-slot and saved-register adapter; all raw arithmetic remains32-bit',
        'F1669/F1670 scratch-local8→16 for two64-bit epilogue pops','Low-address stack/bank; host callback-pointer slots widened only',
        'F575 observed callback boundary records full request and applies supplied reply script; no classifier body executed'],
      'scope':'Whole DOS F568/F569/F570, actual F572/F573 and F1677/F1678/Vec64 math; exact source scan/cooldown/rotation/cache and outputs. F575 effects are explicit supplied callback observations, not a full classifier, world, HP/fuel/time/Main or Android proof.'}
    (PROOF/'instruction-proof.json').write_text(json.dumps(meta,indent=2)+'\n')
    return meta,kernel

def record(rng,index,parent=0,rotating=0):
    b=bytearray(rng.randbytes(OBJECT));b[0x25]=0;b[0x56]=parent;b[0x57]=rotating;b[0x58]=0;b[0x86]=index;b[0x87]=0;b[0x8b]=0
    struct.pack_into('<9i',b,0,0x7fffffff,0,0,0,0x7fffffff,0,0,0,0x7fffffff)
    struct.pack_into('<3q',b,0x26,0,0,0);struct.pack_into('<3q',b,0x3e,0,0,0)
    struct.pack_into('<I',b,0x82,38);struct.pack_into('<3i',b,0x8c,1234567,-7654321,13579);struct.pack_into('<I',b,0x148,0)
    return b
def global_state(rng,indices):
    result={}
    for name,_,size in FIELDS:
        result[name]=rng.randrange(256) if size==1 else rng.getrandbits(32)
        if name.endswith('_s32'):result[name]=s32(result[name])
    result['collider_ref_u32']=rng.choice([0,*indices]);return result
def script(rng,indices,index,return_value=None,mode='mixed'):
    values=global_state(rng,indices);mask=0
    if mode=='mixed':
        for i,(name,_,_) in enumerate(FIELDS):
            if rng.randrange(3)==0:mask|=1<<i
    values['altitude_low_u32']=rng.choice([0,1,0x7fffffff,0x80000000,0xffffffff])
    values['altitude_high_s32']=rng.choice([-1,0,1])
    return {'mask_u32':mask,'globals':values,'return_u8':rng.choice([0,1,2,3,0x40,0x80,255]) if return_value is None else return_value,
            'subject_xor_offset':0x8c if index%7==0 and mode=='mixed' else 0xffffffff,'subject_xor_u8':(index*13+1)&255,
            'collider_xor_offset':0x3e if index%11==0 and mode=='mixed' else 0xffffffff,'collider_xor_u8':(index*17+1)&255}
def cases():
    rng=random.Random(0x569570);rows=[]
    # Exact boundary combinations for signed half-time, both frame changes,
    # and preserved source residue/cache bytes. Primary reply is explicit.
    ticks=[0,1,2,3,4,0x7f,0x100,0x7fffffff,0x80000000,0xfffffffd,0xfffffffe,0xffffffff]
    cooldowns=[0,1,2,127,0x7fffffff,0x80000000,0xffffffff]
    for i in range(168):
        own=114;parent=1;body=record(rng,own,parent,i%2);p=record(rng,parent)
        struct.pack_into('<3q',body,0x3e,*[(1<<44)+i,-(1<<39)-i,123456789+i])
        struct.pack_into('<I',body,0x148,cooldowns[(i//24)%len(cooldowns)])
        if i%3==1:struct.pack_into('<9i',p,0,0,0,-2147483648,0,2147483647,0,2147483647,0,0)
        elif i%3==2:struct.pack_into('<9i',p,0,1518500249,0,1518500249,0,2147483647,0,-1518500249,0,1518500249)
        flags=bytearray(115);flags[own]=4
        enabled=bool(i%2);state=global_state(rng,[own,parent]);responses=[script(rng,[own,parent],n,return_value=(i//2)%4 if n==0 else None,mode='mixed')for n in range(MAX_CALLS)]
        rows.append({'name':f'primary-{i:03d}','enabled':enabled,'player_hex':body.hex(),'objects_by_index':{str(parent):p.hex()},'flags_hex':flags.hex(),'globals':state,'frame_ticks_u32':ticks[i%len(ticks)],'source_frame_byte':[0,1,2,127,255][i%5],'response_scripts':responses})
    # Sparse scan through all index positions. Every skip condition has a
    # directed candidate; different rotation bytes exercise original F1677.
    for i in range(128):
        own=114;parent=1 if i%4 else 0;body=record(rng,own,parent,i%2);objects={};flags=bytearray(115);flags[own]=4
        if parent:objects['1']=record(rng,1)
        struct.pack_into('<3q',body,0x3e,0x123456789+i,-0x23456789-i,0x3456789+i)
        for j,index in enumerate([113,97,65,33,7,2]):
            other=record(rng,index,parent,(i+j)%2);struct.pack_into('<3q',other,0x3e,1000+j*300+i,-2000+j*200,3000-j*100)
            objects[str(index)]=other;flags[index]=[4,0,4,4,4,4][j]
            if j==2 and i%3==0:other[0x8b]=1
            if j==3 and i%3==1:other[0x56]=0 if parent else 1
            if j==3 and i%3==1 and not parent and '1' not in objects:objects['1']=record(rng,1)
            if j==4:struct.pack_into('<I',other,0x82,0x99)
            if i%5==0:other[0x25]=[0,1,2,127,255][i%5];struct.pack_into('<3q',other,0x26,123+i,456+j,789-j)
        if i%2:struct.pack_into('<I',body,0x82,0x99)
        if i%4==1 and parent:objects['1'][0x56]=3;objects['3']=record(rng,3);struct.pack_into('<3q',objects['1'],0x3e,1<<35,-(1<<32),1<<30)
        indices=[own,*map(int,objects)]
        responses=[script(rng,indices,n,mode='mixed') for n in range(MAX_CALLS)]
        if parent:responses[0]['return_u8']=2 if i%3==0 else 0
        rows.append({'name':f'scan-{i:03d}','enabled':bool(i%2),'player_hex':body.hex(),'objects_by_index':{k:bytes(v).hex()for k,v in objects.items()},'flags_hex':flags.hex(),'globals':global_state(rng,indices),'frame_ticks_u32':ticks[i%len(ticks)],'source_frame_byte':[0,1,2,127,255][i%5],'response_scripts':responses})
    # Root with no eligible contacts preserves stale typed reference/HIGH and
    # still performs the original final output projection.
    for i in range(16):
        body=record(rng,114);flags=bytearray(115);flags[114]=4
        rows.append({'name':f'no-contacts-{i:02d}','enabled':bool(i%2),'player_hex':body.hex(),'objects_by_index':{},'flags_hex':flags.hex(),'globals':global_state(rng,[114]),'frame_ticks_u32':ticks[i%len(ticks)],'source_frame_byte':i,'response_scripts':[script(rng,[114],n,mode='passthrough')for n in range(MAX_CALLS)]})
    for i in range(4):
        row=copy.deepcopy(rows[-1]);row['name']=f'stale-unprovided-reference-{i}'
        row['globals']['collider_ref_u32']=[1,17,113,0][i]
        row['globals']['altitude_high_s32']=[-1,0,1,0x7fffffff][i]
        rows.append(row)
    own=13;body=record(rng,own);flags=bytearray([4]*115);flags[0]=0;objects={}
    for index in range(1,115):
        if index==own:continue
        other=record(rng,index,0,index%2)
        struct.pack_into('<3q',other,0x3e,index*12345,-index*45678,index*78901)
        objects[str(index)]=other.hex()
    indices=[own,*map(int,objects)]
    rows.append({'name':'all113-other-slots-descending','enabled':True,'player_hex':body.hex(),
      'objects_by_index':objects,'flags_hex':flags.hex(),'globals':global_state(rng,indices),
      'frame_ticks_u32':49710,'source_frame_byte':93,
      'response_scripts':[script(rng,indices,n,mode='mixed')for n in range(MAX_CALLS)]})
    return rows

def packet(row):
    bank=bytearray(BANK);bank[:115]=bytes.fromhex(row['flags_hex'])
    for index,body in row['objects_by_index'].items():
        at=0x74+int(index)*OBJECT;bank[at:at+OBJECT]=bytes.fromhex(body)
    header=struct.pack('<16I',int(row['enabled']),row['frame_ticks_u32'],row['source_frame_byte'],len(row['response_scripts']),*[int(row['globals'][name])&0xffffffff for name,_,_ in FIELDS])
    responses=b''
    for r in row['response_scripts']:
        responses+=struct.pack('<18I',r['mask_u32'],*[int(r['globals'][name])&0xffffffff for name,_,_ in FIELDS],r['return_u8'],r['subject_xor_offset'],r['subject_xor_u8'],r['collider_xor_offset'],r['collider_xor_u8'])
    raw=header+bytes.fromhex(row['player_hex'])+bank+responses
    if len(raw)!=INPUT:raise ValueError('Unexpected native packet size')
    return raw
def globals_at(raw,offset):
    words=struct.unpack_from('<12I',raw,offset)
    return {name:s32(value) if name.endswith('_s32') else value for (name,_,_),value in zip(FIELDS,words)}
def decode(raw,row):
    if len(raw)!=OUTPUT or struct.unpack_from('<I',raw,76)[0] or raw[-64:]!=bytes([0xa5])*64:raise ValueError('Native source owner/ABI/canary failure')
    count=struct.unpack_from('<I',raw,72)[0]
    if count>MAX_CALLS:raise ValueError('Too many native callbacks')
    body=raw[80:80+OBJECT];bank=raw[80+OBJECT:80+OBJECT+BANK];trace=[];base=80+OBJECT+BANK
    for i in range(count):
        t=raw[base+i*TRACE_BYTES:base+(i+1)*TRACE_BYTES];subject_id,collider_id,returned,reserved=struct.unpack_from('<4I',t)
        if subject_id!=body[0x86] or reserved:raise ValueError('Native trace reference differs')
        trace.append({'subject_before_hex':t[136:474].hex(),'collider_index_u8':collider_id,'collider_before_hex':t[474:812].hex(),
          'relative_before_hex':t[112:136].hex(),'globals_before':globals_at(t,16),'subject_after_hex':t[812:1150].hex(),
          'collider_after_hex':t[1150:1488].hex(),'globals_after':globals_at(t,64),'return_u8':returned})
    outputs=dict(zip(['flags_u8','collider_index_u8','collider_ref_u32','altitude_s32','material_u8','return_u8'],struct.unpack_from('<6I',raw,48)))
    outputs['altitude_s32']=s32(outputs['altitude_s32'])
    original=bytearray(packet(row)[64+OBJECT:64+OBJECT+BANK])
    for index in row['objects_by_index']:
        at=0x74+int(index)*OBJECT;original[at:at+OBJECT]=bank[at:at+OBJECT]
    if bytes(original)!=bank or bank[:115]!=bytes.fromhex(row['flags_hex']):raise ValueError('Unowned bank or flags changed')
    return trace,{'player_hex':body.hex(),'objects_by_index':{index:bank[0x74+int(index)*OBJECT:0x74+(int(index)+1)*OBJECT].hex()for index in row['objects_by_index']},'flags_hex':bank[:115].hex(),'globals':globals_at(raw,0),'outputs':outputs}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'))
    parser.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_frame_dispatch_native.json')
    parser.add_argument('--reprove-original',action='store_true');args=parser.parse_args()
    if args.reprove_original:metadata,kernel=reprove(args)
    else:
        metadata=json.loads((PROOF/'instruction-proof.json').read_text());kernel=(PROOF/'frame-dispatch-observed-kernel.s').read_text()
        if sha(kernel.encode())!=metadata['host_assembly_sha256']:raise ValueError('Changed captured source kernel')
    rows=cases();packets=[packet(r)for r in rows]
    with tempfile.TemporaryDirectory(prefix='frame-dispatch-native-') as directory:
        p=Path(directory);(p/'native.s').write_text(kernel)
        subprocess.run(['as','--64','-o',str(p/'native.o'),str(p/'native.s')],check=True)
        subprocess.run(['ld','-o',str(p/'native'),str(p/'native.o')],check=True)
        runs=[subprocess.run([str(p/'native')],input=b''.join(packets),capture_output=True,check=True,timeout=120).stdout for _ in range(3)]
        if len(set(runs))!=1 or len(runs[0])!=len(rows)*OUTPUT:raise ValueError('Unstable/truncated native output')
        reverse=subprocess.run([str(p/'native')],input=b''.join(reversed(packets)),capture_output=True,check=True,timeout=120).stdout
        if reverse!=b''.join(runs[0][i*OUTPUT:(i+1)*OUTPUT]for i in reversed(range(len(rows)))):raise ValueError('Native callback state leaked across cases')
    call_count=0;record_changes=0;cache_changes=0;cache_cases=0;rotations=0
    for i,row in enumerate(rows):
        trace,expected=decode(runs[0][i*OUTPUT:(i+1)*OUTPUT],row);row['trace']=trace;row['expected']=expected
        # Scripts remain generator inputs; the literal observed trace is the
        # sole runtime callback dependency. Unused scripted slots are omitted.
        row['response_scripts']=row['response_scripts'][:len(trace)]
        call_count+=len(trace)
        record_changes+=sum(v!=row['objects_by_index'][k]for k,v in expected['objects_by_index'].items())
        changed_cache=sum(bytes.fromhex(v)[0x25:0x3e]!=bytes.fromhex(row['objects_by_index'][k])[0x25:0x3e]for k,v in expected['objects_by_index'].items())
        cache_changes+=changed_cache;cache_cases+=int(changed_cache>0)
        rotations+=int(bytes.fromhex(row['player_hex'])[0x57]!=bytes.fromhex(expected['player_hex'])[0x57])
    fixture={'schema':'starfrontier-source-frame-dispatch-native-v1','profile':PROFILE,'source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,
      'instruction_proof_sha256':sha((PROOF/'instruction-proof.json').read_bytes()),'host_assembly_sha256':sha(kernel.encode()),'input_packets_sha256':sha(b''.join(packets)),
      'native_output_sha256':sha(runs[0]),'case_count':len(rows),'fresh_process_runs':3,'reverse_repeat_cases':len(rows),'observed_F575_callbacks':call_count,
      'candidate_record_changes':record_changes,'candidate_cache_byte_record_changes':cache_changes,'candidate_cache_byte_change_cases':cache_cases,
      'actual_frame_conversion_cases':rotations,'all_owner_canaries_unchanged':True,'expected_arithmetic_computed_in_Python':False,
      'scope':metadata['scope'],'cases':rows}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(fixture,indent=2)+'\n')
    result={'status':'native-replayed','case_count':len(rows),'callbacks':call_count,'candidate_record_changes':record_changes,'cache_byte_record_changes':cache_changes,'cache_byte_change_cases':cache_cases,'actual_frame_conversions':rotations,'fixture_sha256':sha(args.output.read_bytes()),'bytes':args.output.stat().st_size}
    (PROOF/'reproduction.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))

def wrapper():
    return WRAPPER.replace('@INPUT@',str(INPUT)).replace('@OUTPUT@',str(OUTPUT)).replace('@BANK@',str(BANK)).replace('@MAX_CALLS@',str(MAX_CALLS)).replace('@SCRIPT_BYTES@',str(SCRIPT_BYTES)).replace('@TRACE_BYTES@',str(TRACE_BYTES)).replace('@TRACE_OFFSET@',str(80+OBJECT+BANK)).replace('@SCRIPT_OFFSET@',str(64+OBJECT+BANK)).replace('@INITIALIZE_GLOBALS@',initialize_globals()).replace('@CAPTURE_FINAL@',capture('r8',0)).replace('@CAPTURE_BEFORE@',capture('r8',16)).replace('@CAPTURE_AFTER@',capture('r8',64)).replace('@APPLY_GLOBALS@',apply_globals())

WRAPPER=r'''
decode_ref:
 test eax,eax
 jz ref_decode_done
 movzx edx,BYTE PTR [player+0x86]
 cmp eax,edx
 je ref_decode_player
 cmp eax,114
 ja failed
 imul eax,338
 add eax,OFFSET FLAT:bank+0x74
 ret
ref_decode_player:
 mov eax,OFFSET FLAT:player
ref_decode_done:
 ret
encode_ref:
 test eax,eax
 jz ref_encode_done
 cmp eax,OFFSET FLAT:player
 je ref_encode_player
 sub eax,OFFSET FLAT:bank+0x74
 xor edx,edx
 mov ecx,338
 div ecx
 test edx,edx
 jnz failed
 cmp eax,114
 ja failed
 ret
ref_encode_player:
 movzx eax,BYTE PTR [player+0x86]
ref_encode_done:
 ret
FUNC_000575:
 push rbp
 mov rbp,rsp
 push rbx
 push rsi
 push rdi
 mov eax,DWORD PTR [call_count]
 cmp eax,DWORD PTR [input+12]
 jae failed
 cmp eax,@MAX_CALLS@
 jae failed
 imul eax,@TRACE_BYTES@
 add eax,OFFSET FLAT:output+@TRACE_OFFSET@
 mov r8d,eax
 mov eax,DWORD PTR [call_count]
 imul eax,@SCRIPT_BYTES@
 add eax,OFFSET FLAT:input+@SCRIPT_OFFSET@
 mov r9d,eax
 mov esi,DWORD PTR [rbp+24]
 movzx eax,BYTE PTR [rsi+0x86]
 mov DWORD PTR [r8],eax
 mov esi,DWORD PTR [rbp+32]
 movzx eax,BYTE PTR [rsi+0x86]
 mov DWORD PTR [r8+4],eax
 mov eax,DWORD PTR [r9+52]
 and eax,255
 mov DWORD PTR [r8+8],eax
 mov DWORD PTR [r8+12],0
 @CAPTURE_BEFORE@
 mov esi,DWORD PTR [rbp+16]
 lea edi,[r8+112]
 mov ecx,24
 rep movsb
 mov esi,DWORD PTR [rbp+24]
 lea edi,[r8+136]
 mov ecx,338
 rep movsb
 mov esi,DWORD PTR [rbp+32]
 lea edi,[r8+474]
 mov ecx,338
 rep movsb
 @APPLY_GLOBALS@
 mov eax,DWORD PTR [r9+56]
 cmp eax,338
 jae no_subject_xor
 mov esi,DWORD PTR [rbp+24]
 mov dl,BYTE PTR [r9+60]
 xor BYTE PTR [rsi+rax],dl
no_subject_xor:
 mov eax,DWORD PTR [r9+64]
 cmp eax,338
 jae no_collider_xor
 mov esi,DWORD PTR [rbp+32]
 mov dl,BYTE PTR [r9+68]
 xor BYTE PTR [rsi+rax],dl
no_collider_xor:
 @CAPTURE_AFTER@
 mov esi,DWORD PTR [rbp+24]
 lea edi,[r8+812]
 mov ecx,338
 rep movsb
 mov esi,DWORD PTR [rbp+32]
 lea edi,[r8+1150]
 mov ecx,338
 rep movsb
 inc DWORD PTR [call_count]
 mov eax,DWORD PTR [r8+8]
 pop rdi
 pop rsi
 pop rbx
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
 mov edx,@INPUT@
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,@INPUT@
 jne read_more
 cld
 mov edi,OFFSET FLAT:player_before
 mov ecx,370
 mov al,0xa5
 rep stosb
 mov edi,OFFSET FLAT:bank_before
 mov ecx,@BANK@+32
 mov al,0xa5
 rep stosb
 mov edi,OFFSET FLAT:output
 mov ecx,@OUTPUT@
 xor eax,eax
 rep stosb
 mov esi,OFFSET FLAT:input+64
 mov edi,OFFSET FLAT:player
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:bank
 mov ecx,@BANK@
 rep movsb
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [DATA_009155],eax
 mov eax,DWORD PTR [input+8]
 mov BYTE PTR [DATA_008811],al
 mov DWORD PTR [call_count],0
 @INITIALIZE_GLOBALS@
 push OFFSET FLAT:out_material
 push OFFSET FLAT:out_altitude
 push OFFSET FLAT:out_reference
 push OFFSET FLAT:out_index
 push OFFSET FLAT:out_flags
 push OFFSET FLAT:bank
 push OFFSET FLAT:player
 cmp DWORD PTR [input],0
 je call_disabled
 call FUNC_000569
 jmp called
call_disabled:
 call FUNC_000568
called:
 add rsp,56
 and eax,255
 mov DWORD PTR [output+68],eax
 mov r8d,OFFSET FLAT:output
 @CAPTURE_FINAL@
 movzx eax,BYTE PTR [out_flags]
 mov DWORD PTR [output+48],eax
 movzx eax,BYTE PTR [out_index]
 mov DWORD PTR [output+52],eax
 mov eax,DWORD PTR [out_reference]
 call encode_ref
 mov DWORD PTR [output+56],eax
 mov eax,DWORD PTR [out_altitude]
 mov DWORD PTR [output+60],eax
 movzx eax,BYTE PTR [out_material]
 mov DWORD PTR [output+64],eax
 mov eax,DWORD PTR [call_count]
 mov DWORD PTR [output+72],eax
 mov esi,OFFSET FLAT:player
 mov edi,OFFSET FLAT:output+80
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:bank
 mov ecx,@BANK@
 rep movsb
 mov edi,OFFSET FLAT:output+@OUTPUT@-64
 mov esi,OFFSET FLAT:player_before
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:player_after
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:bank_before
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:bank_after
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:output
 mov edx,@OUTPUT@
write_more:
 mov eax,1
 mov edi,1
 syscall
 test eax,eax
 jle failed
 add esi,eax
 sub edx,eax
 jnz write_more
 jmp next_case
failed:
 mov edi,95
 jmp exit
finished:
 xor edi,edi
exit:
 mov eax,60
 syscall
.section .data
DATA_007749: .quad FUNC_001517
DATA_007753: .quad FUNC_001531
DATA_007754: .quad FUNC_001532
DATA_007758: .long bank
DATA_007800: .long 0
DATA_007801: .long 0
DATA_007802: .quad FUNC_001677
.section .bss
.balign 16
input: .zero @INPUT@
player_before: .zero 16
player: .zero 338
player_after: .zero 16
bank_before: .zero 16
bank: .zero @BANK@
bank_after: .zero 16
output: .zero @OUTPUT@
out_flags: .zero 4
out_index: .zero 4
out_reference: .zero 4
out_altitude: .zero 4
out_material: .zero 4
call_count: .zero 4
DATA_008696: .zero 1
DATA_008697: .zero 1
DATA_008698: .zero 1
DATA_008699: .zero 1
DATA_008700: .zero 1
DATA_008701: .zero 1
DATA_008702: .zero 4
DATA_008703: .zero 4
DATA_008704: .zero 4
DATA_008705: .zero 4
DATA_008706: .zero 4
DATA_008707: .zero 1
DATA_008811: .zero 1
DATA_009155: .zero 4
.balign 16
stack: .zero 8388608
stack_end:
.section .note.GNU-stack,"",@progbits
'''
if __name__=='__main__':main()
