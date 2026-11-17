#!/usr/bin/env python3
"""Whole DOS F928 allocation and F924/F925 freeing with the real F1533 factory.

Expected bank bytes are measured from original instructions. F144 remains an
explicit, matched module-event boundary with bounded raw mutation replies.
"""
from __future__ import annotations
import argparse,inspect,json,random,re,struct,subprocess,tempfile
from pathlib import Path
import rebuild_source_object_factory_native as F
import rebuild_source_natural_contact_native as N

PROJECT=Path(__file__).resolve().parents[1]
PROOF=PROJECT/'validation/damage-core-2026-11-17/slots-native-proof'
FIXTURE=PROJECT/'tests/fixtures/source_object_slots_native.json'
PROFILE='dos-firstenc-object-slots-v1'
EXE_SHA=F.EXE_SHA;ASM_SHA=F.ASM_SHA;NUMBERS=[928,924,925,1533,1538,1495,1341]
BANK=116+115*338;TABLE=168;MAX=21;SCRIPT=344;TRACE=40+BANK+TABLE
SOURCE_AT=64+BANK;TABLE_AT=SOURCE_AT+338;DESC_AT=TABLE_AT+TABLE
PHYS_AT=DESC_AT+68;RESOURCE_AT=PHYS_AT+24;SCRIPTS_AT=RESOURCE_AT+12
INPUT=SCRIPTS_AT+MAX*SCRIPT;FIXED=64+BANK+338+TABLE+68+24+80
sha=F.sha
def reprove(a):
    exe=a.exe.read_bytes();raw=a.asm.read_bytes();source=raw.decode().replace('\r\n','\n')
    if sha(exe)!=EXE_SHA or sha(raw)!=ASM_SHA:raise ValueError('Pinned original EXE/ASM identity differs')
    signature=bytes.fromhex('558bec5356578b55108b7508bb72000000')
    if exe.find(signature)!=0x2d894 or exe.find(signature,0x2d895)>=0:raise ValueError('F928 original anchor differs')
    resolver=inspect.getsource(N.proof).replace("bind('FUNC_000576',0x427e78)","bind('FUNC_000928',0x43ca94)")
    resolver=resolver.replace('return bodies,records,disassembly,callback_words','return bodies,records,disassembly,callback_words,aliases')
    ns=N.__dict__.copy();exec(resolver,ns)
    bodies,records,dis,_,aliases=ns['proof'](source,a.data.read_text(),exe,a.exe,NUMBERS)
    captured='\n'.join(bodies[n] for n in NUMBERS)
    for record in records.values():
        at=record['executable_offset'];record['hex']=exe[at:at+record['byte_length']].hex()
    info={'schema':'starfrontier-object-slots-original-proof-v1','source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,
      'source_procedures_sha256':sha(captured.encode()),'bindings':aliases,'procedures':records,'full_original_instruction_equality':True,
      'resources_sha256':sha(F.DATA.read_bytes()),'bank_bytes':BANK,'module_flag_window_bytes':TABLE,
      'host_adaptations':['Reviewed ELF64 stack/register argument adapter; original integer and raw338-byte record arithmetic retained.',
       'F1495 scratch reservation8→16 for host epilogue pops; original packed scratch offsets remain unchanged.',
       'Factory and arithmetic callback pointers widened to host64-bit only; historical descriptor pointers rebound to low-address captured resources.',
       'F144 is an explicit typed event boundary. Its matched reply may patch the raw bank/module window and change the count/loop limit; F924 resumes and re-reads original globals.',
       'memcpy copies original338bytes; observer counters preserve source-visible state.'],
      'scope':'Whole original F928 descending slot allocation/reuse plus F924 and F925 release, with real F1533/F1538/F1495/F1341 factory. Explicit module-event replies, no full F144 engine, F942 debris, Main, APK or Android performance claim.'}
    a.proof_dir.mkdir(parents=True,exist_ok=True)
    (a.proof_dir/'source-procedures.asm').write_text(captured)
    (a.proof_dir/'instruction-proof.json').write_text(json.dumps(info,indent=2)+'\n')
    (a.proof_dir/'dos-disassembly.txt').write_text(''.join('F'+n+'\n'+x for n,x in dis.items()))

def verify(proof):
    m=json.loads((proof/'instruction-proof.json').read_text());s=(proof/'source-procedures.asm').read_text()
    if m['source_executable_sha256']!=EXE_SHA or m['source_assembly_sha256']!=ASM_SHA or not m['full_original_instruction_equality'] or sha(s.encode())!=m['source_procedures_sha256'] or sha(F.DATA.read_bytes())!=m['resources_sha256'] or set(m['procedures'])!=set(map(str,NUMBERS)):raise ValueError('Unreviewed captured slots profile')
    with tempfile.TemporaryDirectory(prefix='slots-dos-')as d:
        for n in NUMBERS:
            r=m['procedures'][str(n)];raw=bytes.fromhex(r['hex']);p=Path(d)/('F%d.bin'%n);p.write_bytes(raw)
            actual=N.C.J.instructions(subprocess.check_output(['objdump','-D','-b','binary','-m','i386','-Mintel','--no-show-raw-insn','--adjust-vma='+hex(r['virtual_address']),str(p)],text=True))
            compiled=N.C.J.instructions(N.C.compile32(N.G.block(s,n),m['bindings'],'FUNC_%06d'%n,r['virtual_address']))
            if not r['all_instructions_equal'] or sha(raw)!=r['sha256'] or N.canonical(actual)!=N.canonical(compiled) or len(actual)!=r['instruction_count'] or sha('\n'.join(N.canonical(actual)).encode())!=r['normalized_instruction_sha256']:raise ValueError('Whole archived DOS procedure differs F%d'%n)
    return m,s

def assembly(source):
    selected=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',source)+'\nFUNC_999999:\nret\n'
    lines,_=N.Q.procedures(selected,NUMBERS);text='\n'.join(lines)
    marker='FUNC_001495:\npush rbp\nmov rbp,rsp\nadd rsp,-8'
    if text.count(marker)!=1:raise ValueError('Factory scratch ABI changed')
    text=text.replace(marker,marker.replace('rsp,-8','rsp,-16'))
    text=text.replace('FUNC_001538:\n','FUNC_001538:\npushfq\ninc DWORD PTR [lookup_calls]\npopfq\n',1)
    return '.intel_syntax noprefix\n.code64\n.section .text\n.global _start\n'+text+'\n'+wrapper()

def bank(row):
    seed=row['bank_before'];raw=bytearray.fromhex(seed['header_hex'])+bytearray.fromhex(seed['template_hex'])*115
    if len(raw)!=BANK:raise ValueError('Seed bank domain differs')
    for key,value in seed['overrides'].items():
        at=116+int(key)*338;raw[at:at+338]=bytes.fromhex(value)
    return bytes(raw)

def packet(row):
    resource=json.loads(F.DATA.read_text())['models'][str(row['model_index_u32'])]
    cells=[row['operation_u32'],row['model_index_u32'],row['flags_u8'],row['source_slot_s32'],row['body_slot_u32'],row['reason_u8'],row['recyclable_count_before_u32'],row['module_highest_before_s32'],row['clock']['tick_u32'],row['clock']['day_u32'],len(row['event_replies'])]+[0]*5
    out=struct.pack('<16I',*[v&0xffffffff for v in cells])+bank(row)+bytes.fromhex(row['source_body_hex'])+bytes.fromhex(row['module_window_before_hex'])+bytes.fromhex(resource['descriptor_hex'])+bytes.fromhex(resource['physical_spec_hex']).ljust(24,b'\0')+struct.pack('<3I',resource['collision_first_byte_u8'],resource['collision_present'],bool(resource['physical_spec_hex']))
    for reply in row['event_replies']:
        patches=reply['bank_patches'];flags=reply['module_patches']
        block=struct.pack('<6I',reply['event_index_u32'],reply['recyclable_count_after_u32'],reply['module_highest_after_s32']&0xffffffff,len(patches),len(flags),0)
        for p in patches:block+=struct.pack('<2I',p['offset_u32'],len(bytes.fromhex(p['hex'])))+bytes.fromhex(p['hex']).ljust(16,b'\0')
        block+=bytes((8-len(patches))*24)
        for p in flags:block+=struct.pack('<2I',p['offset_u32'],len(bytes.fromhex(p['hex'])))+bytes.fromhex(p['hex']).ljust(8,b'\0')
        block+=bytes((8-len(flags))*16)
        assert len(block)==SCRIPT;out+=block
    out+=bytes((MAX-len(row['event_replies']))*SCRIPT)
    assert len(out)==INPUT
    return out

def decode(raw,row):
    h=struct.unpack_from('<16I',raw)
    if h[0]!=0x928924aa or h[1]!=len(raw) or h[6] or h[5]!=len(row['event_replies']) or len(raw)!=FIXED+h[5]*TRACE or raw[FIXED-80:FIXED]!=b'\xa5'*80:raise ValueError('Native slots guards/observations differ '+row['name'])
    state=raw[64:64+BANK];src=raw[64+BANK:64+BANK+338];tab=raw[64+BANK+338:64+BANK+338+TABLE]
    resource=json.loads(F.DATA.read_text())['models'][str(row['model_index_u32'])]
    if src.hex()!=row['source_body_hex'] or raw[64+BANK+338+TABLE:FIXED-80]!=bytes.fromhex(resource['descriptor_hex'])+bytes.fromhex(resource['physical_spec_hex']).ljust(24,b'\0'):raise ValueError('Native source/resources mutated')
    events=[]
    for i in range(h[5]):
        p=FIXED+i*TRACE;v=struct.unpack_from('<10I',raw,p);before=raw[p+40:p+40+BANK];window=raw[p+40+BANK:p+TRACE]
        if v[1]!=11 or v[2] or v[8] or v[9]:raise ValueError('F144 boundary payload changed')
        events.append({'event_index_u32':v[0],'event_code_u32':v[1],'payload_zero_u32':v[2],'body_offset_u32':v[3],'slot_u8':v[4],'reason_u8':v[5],'recyclable_count_before_u32':v[6],'module_highest_before_s32':(v[7]&0x7fffffff)-(v[7]&0x80000000),'bank_before_sha256':sha(before),'module_window_before_hex':window.hex()})
    return {'selected_slot_u32':h[2],'recyclable_count_after_u32':h[3],'module_highest_after_s32':(h[4]&0x7fffffff)-(h[4]&0x80000000),'return_body_offset_u32':h[9],'factory_copy_calls_u32':h[7],'factory_lookup_calls_u32':h[8],'bank_after_sha256':sha(state),'bank_header_after_hex':state[:116].hex(),'selected_body_after_hex':state[116+h[2]*338:116+(h[2]+1)*338].hex() if 0<h[2]<=114 else '', 'external_source_body_after_hex':src.hex(),'source_pointer_body_after_hex':(src if row['source_slot_s32']<0 else state[116+row['source_slot_s32']*338:116+(row['source_slot_s32']+1)*338]).hex(),'module_window_after_hex':tab.hex(),'events':events}

def cases():
    rng=random.Random(0x928924);rows=[]
    def add(name,op=0,model=38,free=1,source_slot=-1,flags=1,count=0,highest=-1,replies=None,header=None,overrides=None,window=None):
        template=rng.randbytes(338);h=bytearray(header if header is not None else bytes([1])*115+b'\x9d');over=dict(overrides or {})
        if op:body=bytearray.fromhex(over.get(str(free),template.hex()));body[0x86]=free;over[str(free)]=body.hex()
        rows.append({'name':name,'operation_u32':op,'model_index_u32':model,'flags_u8':flags,'source_slot_s32':source_slot,'body_slot_u32':free,'reason_u8':rng.randrange(256),'recyclable_count_before_u32':count,'module_highest_before_s32':highest,'clock':{'tick_u32':rng.choice([0,1,0xffffffff,0x80000000]),'day_u32':rng.choice([0,1,0xffffffff,0x121cf7])},'bank_before':{'header_hex':h.hex(),'template_hex':template.hex(),'overrides':over},'source_body_hex':rng.randbytes(338).hex(),'module_window_before_hex':(window or bytes(TABLE)).hex(),'event_replies':replies or []})
    for index in range(1,115):
        h=bytearray([1]*116);h[index]=0;h[0]=0;h[115]=0xde
        add('descending-free-slot-%03d'%index,model=index%149,flags=(index*37)&255,count=[0,1,0xffffffff,0x80000000][index%4],header=h)
    for index in range(1,115):
        h=bytearray([1]*116);h[index]=0x20|((index*37)&255);h[0]=0;h[115]=0xa7
        add('descending-reuse-slot-%03d'%index,model=(index+35)%149,flags=(index*53)&255,count=[0,1,0xffffffff,0x80000000][index%4],header=h)
    for model in range(149):
        h=bytearray([0x20]*115+[0xcd]);h[1]=0;h[37]=0;h[114]=0
        add('real-factory-model-%03d'%model,model=model,source_slot=[-1,0,1,37,114][model%5],flags=model,count=model,header=h)
    for flags in range(256):
        h=bytearray([1]*116);h[42]=0;h[114]=0x20
        add('all-new-flags-%03d'%flags,model=38,flags=flags,count=0xffffffff,header=h)
    for flag in range(256):
        h=bytearray([1]*116);h[37]=flag
        add('release-all-old-flags-%03d'%flag,op=1+(flag%2),free=37,count=[0,1,0xffffffff,0x80000000][flag%4],header=h)
    for physical,target,flag in [(0,114,1),(114,0,0x20),(37,1,0x20),(1,37,1)]:
        h=bytearray([1]*116);h[target]=flag
        add('release-pointer-slot%d-index%d'%(physical,target),op=1,free=physical,header=h,count=0)
        b=bytearray.fromhex(rows[-1]['bank_before']['overrides'][str(physical)]);b[0x86]=target;rows[-1]['bank_before']['overrides'][str(physical)]=b.hex()
    for source in [-1,0,1,37,114]:
        for model in [0,38]:
            h=bytearray([1]*116);h[37]=0
            add('source-alias-%d-model%d'%(source,model),source_slot=source,model=model,header=h)
    for zero in [False,True]:
        h=bytearray([1]*116);h[0]=0 if zero else 0x20
        add('exhausted-slotzero-excluded-%s'%zero,header=h,count=0xffffffff)
    def reply(index,count=123,highest=20,bp=None,mp=None):return {'event_index_u32':index,'recyclable_count_after_u32':count,'module_highest_after_s32':highest,'bank_patches':bp or [],'module_patches':mp or []}
    for high in [-1,0,1,19,20]:
        for op in [1,2]:
            w=bytearray(rng.randbytes(TABLE));
            for i in range(21):w[i*8]=4
            reps=[reply(i,count=0xffffffff-i,highest=high)for i in range(high+1)]
            add('inclusive-events-%d-op%d'%(high,op),op=op,free=114,count=55,highest=high,replies=reps,window=w)
    # Original F924 must re-read D8621 and future module flags after callbacks;
    # its saved slot comes from the original body even if a reply changes it.
    w=bytearray(TABLE);w[0]=4;w[8]=0;w[16]=4;w[160]=4
    p=[{'offset_u32':116+37*338+0x86,'hex':'72'},{'offset_u32':37,'hex':'ff'},{'offset_u32':116+114*338+0x88,'hex':'ab'}]
    add('event-grow-limit-activate-and-body-index-mutate',op=1,free=37,count=5,highest=0,window=w,replies=[reply(0,0xffffffff,20,p,[{'offset_u32':8,'hex':'04'}]),reply(1,2,20),reply(2,3,20),reply(20,4,20)])
    add('event-shrink-limit-stops-next-iteration',op=1,free=37,count=0,highest=20,window=bytes([4])*TABLE,replies=[reply(0,0x80000000,-1)])
    add('event-deactivate-future-flags',op=2,free=37,count=12,highest=2,window=bytes([4])*TABLE,replies=[reply(0,13,2,mp=[{'offset_u32':8,'hex':'00'},{'offset_u32':16,'hex':'00'}])])
    for i in range(32):
        h=bytearray(rng.choice([1,0x20,0x80,0xff])for _ in range(116));h[rng.randrange(1,115)]=0
        add('random-caller-template-%02d'%i,model=rng.randrange(149),source_slot=rng.choice([-1,0,1,37,114]),flags=rng.randrange(256),count=rng.randrange(1<<32),header=h)
    return rows

def generate(a):
    m,s=verify(a.proof_dir);native=assembly(s);rows=cases()
    with tempfile.TemporaryDirectory(prefix='object-slots-native-')as d:
        p=Path(d);(p/'native.s').write_text(native);subprocess.run(['as','--64','-o',str(p/'native.o'),str(p/'native.s')],check=True);subprocess.run(['ld','-o',str(p/'native'),str(p/'native.o')],check=True)
        def run(items):
            done=subprocess.run([str(p/'native')],input=b''.join(packet(r)for r in items),capture_output=True,check=True,timeout=60)
            if done.stderr:raise ValueError('Native stderr differs')
            outputs=[];at=0
            for row in items:
                length=struct.unpack_from('<I',done.stdout,at+4)[0];raw=done.stdout[at:at+length];decode(raw,row);outputs.append(raw);at+=length
            if at!=len(done.stdout):raise ValueError('Native output span differs')
            return outputs
        # Feed actual bank/counter outputs into later original operations;
        # Python only transports bytes and selects subsequent caller arguments.
        previous=bytes([0]*115+[0xd9])+bytes.fromhex(rows[0]['bank_before']['template_hex'])*115
        prior_count=0xffffffff;last_selected=114
        for step in range(24):
            row=json.loads(json.dumps(rows[0]));op=1 if step%3==1 else 0
            row.update(name='consecutive-native-%02d'%step,operation_u32=op,model_index_u32=[38,0,117,24][step%4],body_slot_u32=last_selected,source_slot_s32=[-1,0,last_selected][step%3],flags_u8=32 if step%3==0 else 1,recyclable_count_before_u32=prior_count)
            template=previous[116:454]
            row['bank_before']={'header_hex':previous[:116].hex(),'template_hex':template.hex(),'overrides':{str(i):previous[116+i*338:116+(i+1)*338].hex()for i in range(115)if previous[116+i*338:116+(i+1)*338]!=template}}
            raw=run([row])[0];rows.append(row);previous=raw[64:64+BANK];h=struct.unpack_from('<16I',raw);prior_count=h[3]
            if h[2]:last_selected=h[2]
        outputs=run(rows)
        for _ in range(2):
            if run(rows)!=outputs:raise ValueError('Native fresh process differs')
        if run(list(reversed(rows)))!=list(reversed(outputs)):raise ValueError('Native order leakage')
        for row,raw in zip(rows,outputs):row['expected']=decode(raw,row)
    paths=['tools/rebuild_source_object_slots_native.py','tools/rebuild_source_object_factory_native.py','tools/rebuild_source_natural_contact_native.py','recovered-history/ground_harness/tools/native_reference.py','data/ffe_object_factory.json']
    doc={'schema':'starfrontier-source-object-slots-native-v1','profile':PROFILE,'case_count':len(rows),'source_executable_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'instruction_proof_sha256':sha((a.proof_dir/'instruction-proof.json').read_bytes()),'source_procedures_sha256':sha(s.encode()),'host_adapted_assembly_sha256':sha(native.encode()),'fresh_process_runs':3,'reverse_repeat_cases':len(rows),'consecutive_original_steps':24,'all_full_bank_resource_and_source_canaries_unchanged':True,'all_new_flags_byte_values':256,'all_release_flags_byte_values':256,'all_real_models':149,'expected_arithmetic_calculated_in_python':False,'source_dependencies_sha256':{p:sha((PROJECT/p).read_bytes())for p in paths},'scope':m['scope'],'cases':rows}
    a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(doc,indent=2)+'\n');(a.proof_dir/'slots-native.s').write_text(native)
    print(json.dumps({'case_count':len(rows),'fixture_sha256':sha(a.output.read_bytes()),'full_procedures':len(NUMBERS),'F144_observations':sum(len(r['expected']['events'])for r in rows)}))

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=FIXTURE);p.add_argument('--proof-dir',type=Path,default=PROOF);p.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'));p.add_argument('--asm',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'));p.add_argument('--data',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffedat.asm'));p.add_argument('--refresh-original-proof',action='store_true');a=p.parse_args()
    if a.refresh_original_proof:reprove(a)
    generate(a)

def wrapper():
    return WRAPPER.replace('@INPUT@',str(INPUT)).replace('@SOURCE@',str(SOURCE_AT)).replace('@TABLE@',str(TABLE_AT)).replace('@DESC@',str(DESC_AT)).replace('@PHYS@',str(PHYS_AT)).replace('@RESOURCE@',str(RESOURCE_AT)).replace('@SCRIPTS@',str(SCRIPTS_AT)).replace('@SCRIPT@',str(SCRIPT)).replace('@TRACE@',str(TRACE)).replace('@FIXED@',str(FIXED)).replace('@BANK@',str(BANK))

WRAPPER=r'''
_memcpy:
 push rbp
 mov rbp,rsp
 push rsi
 push rdi
 inc DWORD PTR [copy_calls]
 mov edi,DWORD PTR [rbp+16]
 mov esi,DWORD PTR [rbp+24]
 mov ecx,DWORD PTR [rbp+32]
 mov eax,edi
 cld
 rep movsb
 pop rdi
 pop rsi
 pop rbp
 ret
FUNC_000144:
 push rbp
 mov rbp,rsp
 push rbx
 push rsi
 push rdi
 mov eax,DWORD PTR [event_count]
 cmp eax,DWORD PTR [input+40]
 jae event_error
 imul ebx,eax,@TRACE@
 add ebx,OFFSET FLAT:output+@FIXED@
 imul eax,eax,@SCRIPT@
 add eax,OFFSET FLAT:input+@SCRIPTS@
 mov DWORD PTR [reply_ptr],eax
 mov ecx,DWORD PTR [rbp+16]
 cmp ecx,DWORD PTR [eax]
 jne event_error
 mov DWORD PTR [ebx],ecx
 mov ecx,DWORD PTR [rbp+24]
 mov DWORD PTR [ebx+4],ecx
 mov edx,DWORD PTR [rbp+32]
 mov ecx,DWORD PTR [edx]
 mov DWORD PTR [ebx+8],ecx
 mov ecx,DWORD PTR [edx+4]
 sub ecx,OFFSET FLAT:bank
 mov DWORD PTR [ebx+12],ecx
 movzx ecx,BYTE PTR [edx+8]
 mov DWORD PTR [ebx+16],ecx
 movzx ecx,BYTE PTR [edx+9]
 mov DWORD PTR [ebx+20],ecx
 mov ecx,DWORD PTR [DATA_008834]
 mov DWORD PTR [ebx+24],ecx
 mov ecx,DWORD PTR [DATA_008621]
 mov DWORD PTR [ebx+28],ecx
 lea edi,[ebx+40]
 mov esi,OFFSET FLAT:bank
 mov ecx,@BANK@
 rep movsb
 mov esi,OFFSET FLAT:DATA_008623
 mov ecx,168
 rep movsb
 mov ebx,DWORD PTR [reply_ptr]
 mov eax,DWORD PTR [ebx+4]
 mov DWORD PTR [DATA_008834],eax
 mov eax,DWORD PTR [ebx+8]
 mov DWORD PTR [DATA_008621],eax
 mov edx,DWORD PTR [ebx+12]
 lea esi,[ebx+24]
bank_patch_loop:
 test edx,edx
 jz module_patches
 mov edi,DWORD PTR [esi]
 add edi,OFFSET FLAT:bank
 mov ecx,DWORD PTR [esi+4]
 push rsi
 add esi,8
 rep movsb
 pop rsi
 add esi,24
 dec edx
 jmp bank_patch_loop
module_patches:
 mov edx,DWORD PTR [ebx+16]
 lea esi,[ebx+216]
module_patch_loop:
 test edx,edx
 jz event_done
 mov edi,DWORD PTR [esi]
 add edi,OFFSET FLAT:DATA_008623
 mov ecx,DWORD PTR [esi+4]
 push rsi
 add esi,8
 rep movsb
 pop rsi
 add esi,16
 dec edx
 jmp module_patch_loop
event_error:
 mov DWORD PTR [native_error],1
 mov DWORD PTR [DATA_008621],-1
event_done:
 inc DWORD PTR [event_count]
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
 add esi,r8d
 mov edx,@INPUT@
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,@INPUT@
 jne read_more
 cld
 mov edi,OFFSET FLAT:guard_begin
 mov ecx,guard_end-guard_begin
 mov al,0xa5
 rep stosb
 mov edi,OFFSET FLAT:output
 mov ecx,@FIXED@+21*@TRACE@
 xor eax,eax
 rep stosb
 mov esi,OFFSET FLAT:input+64
 mov edi,OFFSET FLAT:bank
 mov ecx,@BANK@
 rep movsb
 mov edi,OFFSET FLAT:source
 mov ecx,338
 rep movsb
 mov edi,OFFSET FLAT:DATA_008623
 mov ecx,168
 rep movsb
 mov edi,OFFSET FLAT:descriptor
 mov ecx,68
 rep movsb
 mov edi,OFFSET FLAT:physical
 mov ecx,24
 rep movsb
 mov eax,DWORD PTR [input+24]
 mov DWORD PTR [DATA_008834],eax
 mov eax,DWORD PTR [input+28]
 mov DWORD PTR [DATA_008621],eax
 mov eax,DWORD PTR [input+32]
 mov DWORD PTR [DATA_008804],eax
 mov eax,DWORD PTR [input+36]
 mov DWORD PTR [DATA_008807],eax
 mov eax,DWORD PTR [input+@RESOURCE@]
 mov BYTE PTR [collision],al
 mov DWORD PTR [descriptor+0x34],0
 cmp DWORD PTR [input+@RESOURCE@+4],0
 je collision_ready
 mov DWORD PTR [descriptor+0x34],OFFSET FLAT:collision
collision_ready:
 mov DWORD PTR [descriptor+0x38],0
 cmp DWORD PTR [input+@RESOURCE@+8],0
 je physical_ready
 mov DWORD PTR [descriptor+0x38],OFFSET FLAT:physical
physical_ready:
 mov edi,OFFSET FLAT:DATA_004681
 mov ecx,149
 mov eax,OFFSET FLAT:descriptor
 rep stosd
 mov DWORD PTR [native_error],0
 mov DWORD PTR [copy_calls],0
 mov DWORD PTR [lookup_calls],0
 mov DWORD PTR [event_count],0
 mov DWORD PTR [selected],0
 mov DWORD PTR [return_offset],0xffffffff
 cmp DWORD PTR [input],0
 jne free_operation
 mov eax,DWORD PTR [input+12]
 cmp eax,-1
 je external_source
 imul eax,eax,338
 add eax,OFFSET FLAT:bank+116
 jmp source_ready
external_source:
 mov eax,OFFSET FLAT:source
source_ready:
 push OFFSET FLAT:selected
 mov ecx,DWORD PTR [input+4]
 push rcx
 mov ecx,DWORD PTR [input+8]
 push rcx
 push rax
 push OFFSET FLAT:bank
 call FUNC_000928
 add rsp,40
 test eax,eax
 jz execute_done
 sub eax,OFFSET FLAT:bank
 mov DWORD PTR [return_offset],eax
 jmp execute_done
free_operation:
 mov eax,DWORD PTR [input+16]
 imul eax,eax,338
 add eax,OFFSET FLAT:bank+116
 cmp DWORD PTR [input],2
 je free_zero
 mov ecx,DWORD PTR [input+20]
 push rcx
 push rax
 call FUNC_000924
 add rsp,16
 jmp execute_done
free_zero:
 push rax
 call FUNC_000925
 add rsp,8
execute_done:
 mov eax,DWORD PTR [input+@DESC@+0x34]
 mov DWORD PTR [descriptor+0x34],eax
 mov eax,DWORD PTR [input+@DESC@+0x38]
 mov DWORD PTR [descriptor+0x38],eax
 mov DWORD PTR [output],0x928924aa
 mov eax,DWORD PTR [event_count]
 imul eax,eax,@TRACE@
 add eax,@FIXED@
 mov DWORD PTR [output+4],eax
 mov eax,DWORD PTR [selected]
 mov DWORD PTR [output+8],eax
 mov eax,DWORD PTR [DATA_008834]
 mov DWORD PTR [output+12],eax
 mov eax,DWORD PTR [DATA_008621]
 mov DWORD PTR [output+16],eax
 mov eax,DWORD PTR [event_count]
 mov DWORD PTR [output+20],eax
 mov eax,DWORD PTR [native_error]
 mov DWORD PTR [output+24],eax
 mov eax,DWORD PTR [copy_calls]
 mov DWORD PTR [output+28],eax
 mov eax,DWORD PTR [lookup_calls]
 mov DWORD PTR [output+32],eax
 mov eax,DWORD PTR [return_offset]
 mov DWORD PTR [output+36],eax
 mov edi,OFFSET FLAT:output+64
 mov esi,OFFSET FLAT:bank
 mov ecx,@BANK@
 rep movsb
 mov esi,OFFSET FLAT:source
 mov ecx,338
 rep movsb
 mov esi,OFFSET FLAT:DATA_008623
 mov ecx,168
 rep movsb
 mov esi,OFFSET FLAT:descriptor
 mov ecx,68
 rep movsb
 mov esi,OFFSET FLAT:physical
 mov ecx,24
 rep movsb
 mov esi,OFFSET FLAT:bank_before
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:bank_after
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:source_before
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:source_after
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:table_before
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:table_after
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:desc_before
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:desc_after
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:physical_before
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:physical_after
 mov ecx,8
 rep movsb
 mov esi,OFFSET FLAT:output
 mov edx,DWORD PTR [output+4]
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
 mov edi,99
 jmp leave
finished:
 xor edi,edi
leave:
 mov eax,60
 syscall
.section .data
DATA_007755: .quad FUNC_001533
DATA_007734: .quad FUNC_001495
DATA_007758: .long bank
DATA_007210: .long 0,4,10,25,45,80,150,250,400,600,6,12,24,36,0
DATA_008834: .long 0
DATA_008621: .long 0
DATA_008804: .long 0
DATA_008807: .long 0
.section .bss
.balign 16
input: .zero @INPUT@
output: .zero @FIXED@+21*@TRACE@
guard_begin:
bank_before: .zero 8
bank: .zero @BANK@
bank_after: .zero 8
source_before: .zero 8
source: .zero 338
source_after: .zero 8
table_before: .zero 8
DATA_008623: .zero 168
table_after: .zero 8
desc_before: .zero 8
descriptor: .zero 68
desc_after: .zero 8
physical_before: .zero 8
physical: .zero 24
physical_after: .zero 8
guard_end:
collision: .zero 1
copy_calls: .zero 4
lookup_calls: .zero 4
event_count: .zero 4
native_error: .zero 4
selected: .zero 4
return_offset: .zero 4
reply_ptr: .zero 4
DATA_004681: .zero 596
stack: .zero 1048576
stack_end:
.section .note.GNU-stack,"",@progbits
'''
if __name__=='__main__':main()
