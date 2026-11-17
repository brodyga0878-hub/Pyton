#!/usr/bin/env python3
"""Whole DOS F1019/F1021 instruction oracle, with typed world-call observations.

The verified original arithmetic closure executes, including the source F1046
drift at its distinct place in each phase. World/input/event/audio procedures
remain observed boundaries. Expected arithmetic is never calculated in Python.
"""
from __future__ import annotations
import argparse, hashlib, inspect, json, random, re, struct, subprocess, tempfile
from pathlib import Path
import rebuild_source_player_dispatch_native as P
PROJECT=P.PROJECT
PROOF=PROJECT/'validation/player-cycle-2026-11-17/phase-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_player_phase_native.json'
NUMBERS=P.NUMBERS+[1019,1021,1042,1046]
ROOT=0x4000; BODY=338; MAXOBS=16; MAXTRACE=128; EXT=40
SCRIPT=296; HEADER=4+EXT+BODY*3+ROOT; INPUT=HEADER+MAXOBS*SCRIPT
CONTEXT=BODY+ROOT+EXT; RECORD=24+CONTEXT*2
OUTPUT=32+CONTEXT+MAXTRACE*4+MAXOBS*RECORD+64
OPS={'phase_f1019':1019,'phase_f1021':1021}
FIELDS=['frame_ticks_u32','forward_key_u8','reverse_key_u8','spin_xyz_s32','transfer_state_u32','saved_flight_flags_u32','effect_gate_s32']
BOUNDARIES=[1033,1035,1037,1039,1014,1018,1120,1117,1116,995,726,652,657,1022,48,1906,1910,939,606]
TRACE=list(dict.fromkeys(P.TRACE+[1019,1021,1042,1046,601,602]+BOUNDARIES))
PROFILE='dos-firstenc-whole-player-phases-v1'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def reprove(args):
    namespace=P.__dict__.copy();namespace['NUMBERS']=NUMBERS
    code=inspect.getsource(P.reprove).replace(" ns=n.__dict__.copy();exec(resolver,ns)"," resolver=resolver.replace(\"bind('FUNC_001041',0x441ee8)\",\"bind('FUNC_001041',0x441ee8)\\n bind('FUNC_001019',0x440c48)\\n bind('FUNC_001021',0x440e9c)\")\n ns=n.__dict__.copy();exec(resolver,ns)")
    exec(code,namespace);metadata,source=namespace['reprove'](args)
    base=metadata['bindings']['DATA_008804']
    metadata.update(schema='starfrontier-original-player-phase-instruction-proof-v1',root_bytes=ROOT,root_alias_offsets={k:v-base for k,v in metadata['bindings'].items()if k.startswith('DATA_')and base<=v<base+ROOT},scope='Whole original DOS F1019/F1021 including F1041, F1042, F1046 and real angular/gravity/motor/drift closure. Input, contact, frame/control, world events, vector F726 and presentation callbacks are explicit matched observations. No full world scheduler, collision, docking, UI or live Main route claim.')
    metadata['host_adaptations']+=['F1019/F1021 scratch local allocation8→16 for original two host-width epilogue pops, keeping logical local field offsets and four-byte collider slot unchanged','F1019/F1021 local collider pointer remains a four-byte low-address pointer; F1033 observer writes that exact width','All original DATA aliases inside the 16KiB GameRoot bind to the same bytes, not duplicated globals','C8/CC pointer cells normalize to logical player114/collider37 references for portable full-Root comparison','Every observed call records entire before/after body338, Root16384 and external state; scripts apply only explicitly supplied byte patches']
    (args.proof_dir/'instruction-proof.json').write_text(json.dumps(metadata,indent=2)+'\n')
    return metadata,source
def verify(metadata,source):
    namespace=P.__dict__.copy();namespace['NUMBERS']=NUMBERS
    exec(inspect.getsource(P.verify_archived),namespace);namespace['verify_archived'](metadata,source)
    base=metadata['bindings']['DATA_008804']
    actual={k:v-base for k,v in metadata['bindings'].items()if k.startswith('DATA_')and base<=v<base+ROOT}
    if actual!=metadata['root_alias_offsets']:raise ValueError('Root alias bindings changed')
def trace(k):
    return f'pushfq\npush rax\npush rcx\nmov ecx,DWORD PTR [trace_count]\ncmp ecx,{MAXTRACE}\njae bad_trace\nmov DWORD PTR [trace_codes+rcx*4],{k}\ninc DWORD PTR [trace_count]\npop rcx\npop rax\npopfq\n'
def external_packet(g):
    cells=[g['frame_ticks_u32'],g['forward_key_u8'],g['reverse_key_u8'],*g['spin_xyz_s32'],g['transfer_state_u32'],g['saved_flight_flags_u32'],0,g['effect_gate_s32']]
    return struct.pack('<10I',*[v&0xffffffff for v in cells])
def external_decode(raw):
    v=struct.unpack('<10I',raw)
    if v[8]!=0:raise ValueError('External reserved native guard changed')
    return dict(frame_ticks_u32=v[0],forward_key_u8=v[1],reverse_key_u8=v[2],spin_xyz_s32=[P.s32(x)for x in v[3:6]],transfer_state_u32=v[6],saved_flight_flags_u32=v[7],effect_gate_s32=P.s32(v[9]))
def patches(raw,base=None):
    if base is None:base=b'\xa5'*len(raw)
    rows=[];start=None
    for i,(a,b)in enumerate(zip(raw,base)):
        if a!=b and start is None:start=i
        if a==b and start is not None:rows.append([start,raw[start:i].hex()]);start=None
    if start is not None:rows.append([start,raw[start:].hex()])
    return rows
def unpatch(rows,base=None):
    result=bytearray(b'\xa5'*ROOT if base is None else base)
    for at,raw in rows:result[at:at+len(bytes.fromhex(raw))]=bytes.fromhex(raw)
    return bytes(result)
def packet(row):
    raw=struct.pack('<I',OPS[row['operation']])+external_packet(row['external_before'])+bytes.fromhex(row['body_before_hex'])+bytes.fromhex(row['parent_hex'])+bytes.fromhex(row['collider_hex'])+unpatch(row['root_before_patch'])
    scripts=row.get('scripts',[])
    for i in range(MAXOBS):
        script=scripts[i]if i<len(scripts)else{}
        raw+=struct.pack('<II',script.get('kind',0),script.get('return_u32',0))
        for name in ('root','body','external'):
            cells=[(at+j,b)for at,value in script.get(name+'_patch',[])for j,b in enumerate(bytes.fromhex(value))]
            if len(cells)>12:raise ValueError('Too many explicit boundary writes')
            raw+=b''.join(struct.pack('<II',*cells[j])if j<len(cells)else struct.pack('<II',0xffffffff,0)for j in range(12))
    assert len(raw)==INPUT
    return raw
def normalized_root(raw,player,collider):
    result=bytearray(raw)
    for at in (0xc8,0xcc):
        ptr=struct.unpack_from('<I',result,at)[0]
        if ptr not in(0,player,collider):raise ValueError('Native logical reference escaped')
        struct.pack_into('<I',result,at,114 if ptr==player else 37 if ptr==collider else 0)
    return bytes(result)
def decode_context(raw,player,collider):
    body=raw[:BODY];root=normalized_root(raw[BODY:BODY+ROOT],player,collider);external=external_decode(raw[BODY+ROOT:])
    return {'body_hex':body.hex(),'root_patch':patches(root),'root_sha256':sha(root),'external':external}
def decode(raw,row):
    magic,ntrace,nobs,player,collider,bank_change,guard,reserved=struct.unpack_from('<8I',raw)
    if magic!=0x50484153 or ntrace>MAXTRACE or nobs>MAXOBS or bank_change or guard or reserved or raw[-64:]!=b'\xa5'*64:raise ValueError('Native phase ownership/trace guard failed '+row['name'])
    final=decode_context(raw[32:32+CONTEXT],player,collider)
    at=32+CONTEXT;order=['F'+str(x)for x in struct.unpack_from('<%dI'%MAXTRACE,raw,at)[:ntrace]];at+=MAXTRACE*4
    observations=[]
    for i in range(nobs):
        item=raw[at+i*RECORD:at+(i+1)*RECORD];kind,a,b,c,d,returned=struct.unpack_from('<6I',item)
        counts={1033:2,1035:1,1037:1,1039:1,1014:1,1018:0,1120:0,1117:0,1116:0,995:0,726:4,652:2,657:2,1022:1,48:3,1906:1,1910:3,939:3,606:2}
        before=decode_context(item[24:24+CONTEXT],player,collider);after=decode_context(item[24+CONTEXT:],player,collider)
        obs={'kind':'F'+str(kind),'args':[a,b,c,d][:counts[kind]],'before':before,'after':after,'return_u32':returned}
        if kind==1033:obs['collider_hex']=row['collider_hex'];obs['collider_index']=37
        observations.append(obs)
    return {'body_after_hex':final['body_hex'],'root_after_patch':final['root_patch'],'root_after_sha256':final['root_sha256'],'external_after':final['external'],'source_order':order,'observations':observations}
def assembly(source,metadata):
    namespace=P.__dict__.copy();namespace.update(NUMBERS=NUMBERS,TRACE=TRACE,trace=trace,WRAPPER='')
    exec(inspect.getsource(P.assembly),namespace);native=namespace['assembly'](source)
    for number in (1019,1021):
        old=f'FUNC_{number:06d}:\n'+trace(number)+'\npush rbp\nmov rbp,rsp\nadd rsp,-8'
        if native.count(old)!=1:raise ValueError('Unreviewed phase two-pop scratch frame')
        native=native.replace(old,old.replace('rsp,-8','rsp,-16'))
    stubs=[]
    for kind in BOUNDARIES:
        stubs.append(stub(kind))
    data=P.WRAPPER[P.WRAPPER.index('.section .data'):P.WRAPPER.index('.section .bss')].replace('@BANK@',str(P.BANK))
    data+='\nDATA_006142: .quad FUNC_000601\nDATA_006152: .quad FUNC_000602\n'
    aliases='\n'.join('.set %s,root+%d'%(key,offset)for key,offset in metadata['root_alias_offsets'].items())
    external_aliases='\n'.join('.set %s,external+%d'%(key,offset)for key,offset in {'DATA_009155':0,'DATA_007692':4,'DATA_007694':8,'DATA_008708':12,'DATA_008709':16,'DATA_008710':20,'DATA_009138':24,'DATA_009135':28,'DATA_009116':36}.items())
    wrapper=WRAPPER
    guard='\n'.join('cmp DWORD PTR [%s+%d],0xa5a5a5a5\njne bad_pointer'%(name,offset)for name in('body_before','body_after','root_before','root_after','bank_before','bank_after','collider_before','collider_after')for offset in range(0,16,4))
    wrapper=wrapper.replace('@GUARDCHECK@',guard)
    values={'INPUT':INPUT,'OUTPUT':OUTPUT,'HEADER':HEADER,'SCRIPT':SCRIPT,'ROOT':ROOT,'BANK':P.BANK,'CONTEXT':CONTEXT,'RECORD':RECORD,'OBSBASE':32+CONTEXT+MAXTRACE*4,'TRACEBASE':32+CONTEXT,'BODYAT':44,'PARENTAT':44+BODY,'COLLIDERAT':44+BODY*2,'ROOTAT':44+BODY*3}
    for key,value in values.items():wrapper=wrapper.replace('@'+key+'@',str(value))
    return native+'\n'+P.WRAPPER[P.WRAPPER.index('_abs:'):P.WRAPPER.index('FUNC_000606:')]+'\n'+'\n'.join(stubs)+'\n'+wrapper+'\n'+data+'\n'+aliases+'\n'+external_aliases+'\n'+BSS.replace('@INPUT@',str(INPUT)).replace('@OUTPUT@',str(OUTPUT)).replace('@BANK@',str(P.BANK))
def stub(kind):
    args={1033:[114,1],1035:[114],1037:[114],1039:[114],1014:[114],1022:[37],606:[114,1],939:[114,0x3e,0]}.get(kind,[])
    setup='\n'.join(f'mov DWORD PTR [obs_args+{i*4}],{value}'for i,value in enumerate(args))
    if kind in(48,1906,1910):
        setup='\n'.join(f'mov eax,DWORD PTR [rbp+{16+i*8}]\nmov DWORD PTR [obs_args+{i*4}],eax'for i in range({48:3,1906:1,1910:3}[kind]))
    if kind in(652,657):setup='mov eax,DWORD PTR [rbp+16]\n'+('and eax,255\n'if kind==652 else'')+'mov DWORD PTR [obs_args],eax\nmov DWORD PTR [obs_args+4],37'
    if kind==726:
        setup='''mov eax,DWORD PTR [rbp+16]
cmp eax,OFFSET FLAT:body+0x8c
sete al
movzx eax,al
xor eax,3
mov DWORD PTR [obs_args],eax
mov eax,DWORD PTR [rbp+24]
cmp eax,OFFSET FLAT:body+0x8c
sete al
movzx eax,al
xor eax,3
mov DWORD PTR [obs_args+4],eax
mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [obs_args+8],eax
mov eax,DWORD PTR [rbp+40]
mov DWORD PTR [obs_args+12],eax'''
    post=''
    if kind==1033:post='''mov eax,DWORD PTR [rbp+32]
mov DWORD PTR [rax],OFFSET FLAT:collider
mov eax,DWORD PTR [rbp+40]
mov BYTE PTR [rax],0
mov eax,DWORD PTR [rbp+48]
mov BYTE PTR [rax],0
'''
    return f'''FUNC_{kind:06d}:
{trace(kind)}push rbp
mov rbp,rsp
pushfq
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push r8
push r9
push r10
push r11
mov DWORD PTR [obs_kind],{kind}
mov DWORD PTR [obs_args],0
mov DWORD PTR [obs_args+4],0
mov DWORD PTR [obs_args+8],0
mov DWORD PTR [obs_args+12],0
{setup}
call observe
{post}
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
popfq
mov eax,DWORD PTR [obs_return]
pop rbp
ret
'''
def base_row(rng,i,op):
    origin=P.base_row(rng,i,'prepare_f1041');body=bytearray.fromhex(origin['body_before_hex']);parent=bytearray.fromhex(origin['parent_hex']);g=origin['globals_before']
    root=bytearray(b'\xa5'*ROOT)
    def put(at,fmt,*values):struct.pack_into('<'+fmt,root,at,*values)
    put(0x88,'3i',*g['reference_velocity_s32']);put(0x94,'i',0x12345678);put(0xc0,'I',114);put(0xc5,'B',37);put(0xc6,'H',128 if i%3 else 0);put(0xc8,'II',114,0)
    put(0xd8,'i',-700);put(0xdc,'i',g['spin_elapsed_s32']);put(0xe0,'II',g['drift_ticks_low_u32'],g['drift_ticks_high_u32']);put(0xe8,'4B',2 if op=='phase_f1019'else 0,g['flight_flags_u8'],0,0x91);put(0x106,'I',0);put(0x1b8,'i',g['set_speed_s32']);put(0x210,'h',g['player_roll_s16']);root[0x3fb6]=0;root[0x3f5e]=i%2
    body[0x14d]=1 if i%4 else 0;body[0x14e]=i%2
    collider=bytearray(b'\xa5'*BODY);collider[0x86]=37;collider[0x14c]=[0,0x10,0x20,0x40,0x70][i%5]
    external={key:g[key]for key in('frame_ticks_u32','forward_key_u8','reverse_key_u8','spin_xyz_s32')};external.update(transfer_state_u32=1,saved_flight_flags_u32=i%2,effect_gate_s32=-1)
    flags=[0,1,0x20,0x21,0x40,0x60,0x61,0xe0,0xc0][i%9]
    scripts=[{'kind':1033,'return_u32':flags},{'kind':657,'return_u32':i%2}]
    # Input/frame/control remain explicit observed responses. These directed
    # writes exercise alias changes before the subsequent real arithmetic.
    if i%7==0:scripts.append({'kind':1037,'root_patch':[[0x1b8,struct.pack('<i',1234).hex()],[0xe9,'01']]})
    if i%11==0:scripts.append({'kind':606,'root_patch':[[0xe8,'24'if i==44 else'00'],[0xe9,'00'if i%88==0 else'01'],[0x1b8,struct.pack('<i',-7654).hex()]],'body_patch':[[0x8c,struct.pack('<3i',17,-29,41).hex()]]})
    if i%13==0:scripts[0]['root_patch']=[[0xe8,'2c']]
    if i%5==0:root[0x3fb6]=2;external['transfer_state_u32']=i%2
    if i%17==1:external['transfer_state_u32']=0
    if op=='phase_f1021'and i%10==5:root[0xe8]=2
    if op=='phase_f1021'and i%19==3:root[0xe8]=0x24
    if i%17==0:scripts.append({'kind':1035,'body_patch':[[0xb6,'000000000010']]})
    return dict(name=op+'/'+str(i),operation=op,body_before_hex=body.hex(),parent_hex=parent.hex(),collider_hex=collider.hex(),root_before_patch=patches(root),external_before=external,scripts=scripts)
def generate(args):
    metadata=json.loads((args.proof_dir/'instruction-proof.json').read_text());source=(args.proof_dir/'source-procedures.s').read_text();verify(metadata,source)
    native=assembly(source,metadata);rng=random.Random(0x10191021);rows=[base_row(rng,i,op)for op in OPS for i in range(128)]
    with tempfile.TemporaryDirectory(prefix='whole-player-phases-')as directory:
        path=Path(directory);(path/'oracle.s').write_text(native)
        subprocess.run(['as','--64','-o',str(path/'oracle.o'),str(path/'oracle.s')],check=True);subprocess.run(['ld','-o',str(path/'oracle'),str(path/'oracle.o')],check=True)
        def run(items):
            p=subprocess.run([str(path/'oracle')],input=b''.join(packet(r)for r in items),capture_output=True,timeout=120)
            if p.returncode or p.stderr or len(p.stdout)!=len(items)*OUTPUT:raise ValueError('Native phase execution failed '+str((p.returncode,p.stderr,len(p.stdout),len(items)*OUTPUT)))
            return p.stdout
        # Small batches avoid retaining three several-hundred-MB controls.
        outputs=[]
        for start in range(0,len(rows),16):
            batch=rows[start:start+16];first=run(batch)
            if run(batch)!=first or run(batch)!=first:raise ValueError('Unstable fresh-process result')
            backwards=run(list(reversed(batch)))
            if backwards!=b''.join(first[i*OUTPUT:(i+1)*OUTPUT]for i in reversed(range(len(batch)))):raise ValueError('Case-order contamination')
            for i,row in enumerate(batch):row['expected']=decode(first[i*OUTPUT:(i+1)*OUTPUT],row)
            outputs.append(sha(first))
        previous=base_row(rng,1,'phase_f1021');previous['external_before'].update(frame_ticks_u32=49710,transfer_state_u32=1);root=bytearray(unpatch(previous['root_before_patch']));root[0x3fb6]=0;root[0x3f5e]=0;root[0xe8]=0;root[0xe9]=1;struct.pack_into('<II',root,0xe0,49710,0);previous['root_before_patch']=patches(root);previous['scripts']=[{'kind':1033,'return_u32':0}]
        sequence_outputs=[]
        for index in range(32):
            row=json.loads(json.dumps(previous));row.update(name='consecutive-native/'+str(index),sequence_step=index)
            raw=run([row])
            if run([row])!=raw or run([row])!=raw:raise ValueError('Unstable consecutive fresh-process result')
            sequence_outputs.append(raw);row['expected']=decode(raw,row);rows.append(row);outputs.append(sha(raw))
            previous=row.copy();previous['body_before_hex']=row['expected']['body_after_hex'];previous['root_before_patch']=row['expected']['root_after_patch'];previous['external_before']=row['expected']['external_after'];previous.pop('expected',None)
        if run(list(reversed(rows[-32:])))!=b''.join(reversed(sequence_outputs)):raise ValueError('Consecutive native case-order contamination')
    result=dict(schema='starfrontier-source-player-phase-native-v1',profile=PROFILE,source_executable_sha256=P.EXE_SHA,source_assembly_sha256=P.ASM_SHA,instruction_proof_sha256=sha((args.proof_dir/'instruction-proof.json').read_bytes()),source_procedures_sha256=sha(source.encode()),host_assembly_sha256=sha(native.encode()),input_packets_sha256=sha(b''.join(packet(r)for r in rows)),native_batch_output_sha256=outputs,case_count=len(rows),case_counts_by_operation={op:sum(r['operation']==op for r in rows)for op in OPS},fresh_process_runs=3,reverse_repeat_cases=len(rows),consecutive_native_steps=32,root_bytes=ROOT,all_body_root_parent_bank_canaries_unchanged=True,expected_arithmetic_calculated_in_python=False,scope=metadata['scope'],callback_policy='Full matched before/after body, Root and external states at each observed call; no body of input/contact/frame/event/UI/audio/F726 executed. The real F1046→F1045→F1512 drift executes in original order.',cases=rows)
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,indent=2)+'\n');(args.proof_dir/'player-phase-native.s').write_text(native)
    print(json.dumps(dict(case_count=len(rows),fixture_sha256=sha(args.output.read_bytes()),fixture_bytes=args.output.stat().st_size,output=str(args.output)),indent=2))
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--refresh-original-proof',action='store_true');args=p.parse_args()
    if args.refresh_original_proof:reprove(args)
    generate(args)

WRAPPER=r'''
observe:
 mov eax,DWORD PTR [obs_count]
 cmp eax,16
 jae bad_trace
 imul eax,@RECORD@
 add eax,OFFSET FLAT:output+@OBSBASE@
 mov DWORD PTR [record_address],eax
 mov edi,eax
 mov esi,OFFSET FLAT:obs_kind
 mov ecx,20
 rep movsb
 mov DWORD PTR [obs_return],0
 mov edi,DWORD PTR [record_address]
 add edi,24
 call copy_context
 mov ebx,OFFSET FLAT:input+@HEADER@
 mov edx,16
find_script:
 mov eax,DWORD PTR [obs_kind]
 cmp DWORD PTR [rbx],eax
 je found_script
 add ebx,@SCRIPT@
 dec edx
 jnz find_script
 jmp script_done
found_script:
 mov eax,DWORD PTR [rbx+4]
 mov DWORD PTR [obs_return],eax
 lea esi,[rbx+8]
 mov edi,OFFSET FLAT:root
 call apply_bytes
 mov edi,OFFSET FLAT:body
 call apply_bytes
 mov edi,OFFSET FLAT:external
 call apply_bytes
script_done:
 mov edi,DWORD PTR [record_address]
 mov eax,DWORD PTR [obs_return]
 mov DWORD PTR [rdi+20],eax
 add edi,24+@CONTEXT@
 call copy_context
 inc DWORD PTR [obs_count]
 ret
apply_bytes:
 mov ecx,12
apply_next:
 lodsd
 mov edx,eax
 lodsd
 cmp edx,-1
 je skip_byte
 mov BYTE PTR [rdi+rdx],al
skip_byte:
 loop apply_next
 ret
copy_context:
 mov esi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:root
 mov ecx,@ROOT@
 rep movsb
 mov esi,OFFSET FLAT:external
 mov ecx,40
 rep movsb
 ret
bad_trace:
 mov edi,91
 jmp finish
bad_pointer:
 mov edi,92
 jmp finish
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
 mov edi,OFFSET FLAT:body_before
 mov ecx,370
 mov al,0xa5
 rep stosb
 mov edi,OFFSET FLAT:root_before
 mov ecx,@ROOT@+32
 rep stosb
 mov edi,OFFSET FLAT:bank_before
 mov ecx,@BANK@+32
 rep stosb
 mov edi,OFFSET FLAT:collider_before
 mov ecx,370
 rep stosb
 mov esi,OFFSET FLAT:input+4
 mov edi,OFFSET FLAT:external
 mov ecx,40
 rep movsb
 mov esi,OFFSET FLAT:input+@BODYAT@
 mov edi,OFFSET FLAT:body
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:input+@COLLIDERAT@
 mov edi,OFFSET FLAT:collider
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:input+@ROOTAT@
 mov edi,OFFSET FLAT:root
 mov ecx,@ROOT@
 rep movsb
 cmp DWORD PTR [root+0xc8],114
 jne bad_pointer
 mov DWORD PTR [root+0xc8],OFFSET FLAT:body
 cmp DWORD PTR [root+0xcc],0
 je root_pointer_done
 cmp DWORD PTR [root+0xcc],37
 jne bad_pointer
 mov DWORD PTR [root+0xcc],OFFSET FLAT:collider
root_pointer_done:
 movzx eax,BYTE PTR [body+0x56]
 imul eax,338
 add eax,OFFSET FLAT:bank+0x74
 mov edi,eax
 mov esi,OFFSET FLAT:input+@PARENTAT@
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:bank
 mov edi,OFFSET FLAT:bank_copy
 mov ecx,@BANK@
 rep movsb
 mov edi,OFFSET FLAT:output
 mov ecx,@OUTPUT@
 xor eax,eax
 rep stosb
 mov DWORD PTR [trace_count],eax
 mov DWORD PTR [obs_count],eax
 mov edi,OFFSET FLAT:trace_codes
 mov ecx,512
 rep stosb
 push OFFSET FLAT:body
 cmp DWORD PTR [input],1019
 je operation1019
 cmp DWORD PTR [input],1021
 jne bad_trace
 call FUNC_001021
 jmp operation_done
operation1019:
 call FUNC_001019
operation_done:
 add rsp,8
 mov DWORD PTR [output],0x50484153
 mov eax,DWORD PTR [trace_count]
 mov DWORD PTR [output+4],eax
 mov eax,DWORD PTR [obs_count]
 mov DWORD PTR [output+8],eax
 mov DWORD PTR [output+12],OFFSET FLAT:body
 mov DWORD PTR [output+16],OFFSET FLAT:collider
 mov edi,OFFSET FLAT:output+32
 call copy_context
 mov esi,OFFSET FLAT:trace_codes
 mov edi,OFFSET FLAT:output+@TRACEBASE@
 mov ecx,512
 rep movsb
 mov esi,OFFSET FLAT:bank
 mov edi,OFFSET FLAT:bank_copy
 mov ecx,@BANK@
 repe cmpsb
 sete al
 xor al,1
 movzx eax,al
 mov DWORD PTR [output+20],eax
 mov edi,OFFSET FLAT:output+@OUTPUT@-64
 mov esi,OFFSET FLAT:body_before
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:body_after
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:root_before
 mov ecx,16
 rep movsb
 mov esi,OFFSET FLAT:root_after
 mov ecx,16
 rep movsb
@GUARDCHECK@
 mov esi,OFFSET FLAT:output
 mov edx,@OUTPUT@
write_more:
 mov eax,1
 mov edi,1
 syscall
 test eax,eax
 jle write_failed
 add esi,eax
 sub edx,eax
 jnz write_more
 jmp next_case
write_failed:
 mov edi,93
 jmp finish
finished:
 xor edi,edi
finish:
 mov eax,60
 syscall
'''
BSS=r'''
.section .bss
.balign 16
input: .zero @INPUT@
body_before: .zero 16
body: .zero 338
body_after: .zero 16
root_before: .zero 16
root: .zero 16384
root_after: .zero 16
collider_before: .zero 16
collider: .zero 338
collider_after: .zero 16
bank_before: .zero 16
bank: .zero @BANK@
bank_after: .zero 16
bank_copy: .zero @BANK@
output: .zero @OUTPUT@
external: .zero 40
trace_codes: .zero 512
trace_count: .zero 4
obs_count: .zero 4
obs_kind: .zero 4
obs_args: .zero 16
obs_return: .zero 4
record_address: .zero 4
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
'''
if __name__=='__main__':main()
