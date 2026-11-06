#!/usr/bin/env python3
"""Execute actual pinned F1533/F879/F574 terrain placement on host x86_64.

No height callback is substituted. The reachable natural-parent terrain path
uses original F575/F576/F579/F582/F581/F1876 and original model resources.
Other source collision/render branches abort if reached and are listed in the
fixture. This tool is a host instruction oracle, never an Android emulator.
"""
from __future__ import annotations
import argparse, hashlib, importlib.util, json, random, re, struct, subprocess, sys, tempfile
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
EXE_SHA='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
COMMIT='7e540341d4e09aa3c92877b87d49e7f2c143ad8d'
VARIANT='jjffe-7e54034-ground-surface'
SIN_SIGNATURE=bytes.fromhex('000000003f2403007e480600be6c0900fd900c003db50f007cd91200bbfd1500')
ABS_DOS=bytes.fromhex('558bec8b450885c07d068bd0f7daeb028bd08bc25dc3')
OBJECT=338
BANK=116+256*OBJECT
INPUT=16+2*OBJECT
TRACE_STRIDE=72
GLOBAL_FIELDS=[('collision_flags_u8',8696,1),('volume_flags_u8',8697,1),('collider_index_u8',8698,1),('collision_active_u8',8699,1),('collision_enabled_u8',8700,1),('primitive_flags_u8',8701,1),('altitude_low_u32',8703,4),('altitude_high_s32',8704,4),('previous_altitude_low_u32',8705,4),('previous_altitude_high_s32',8706,4),('collision_kind_u8',8707,1)]
OUTPUT=4*OBJECT+TRACE_STRIDE*2+64+256
EXTRA=[571,574,575,576,578,579,581,582,879,1332,1333,1334,1338,1341,1466,1495,1501,1502,1503,1504,1519,1520,1522,1523,1532,1533,1538,1552,1657,1658,1660,1662,1664,1669,1670,1674,1914]

def sha(raw):return hashlib.sha256(raw).hexdigest()

class Image:
    def __init__(self,raw):
        self.raw=raw
        pe=struct.unpack_from('<I',raw,60)[0]
        self.base=struct.unpack_from('<I',raw,pe+52)[0]
        count=struct.unpack_from('<H',raw,pe+6)[0]
        start=pe+24+struct.unpack_from('<H',raw,pe+20)[0]
        self.sections=[struct.unpack_from('<4I',raw,start+i*40+8) for i in range(count)]
    def offset(self,address,length):
        for _,va,size,at in self.sections:
            delta=address-self.base-va
            if 0<=delta and delta+length<=size and at+delta+length<=len(self.raw):return at+delta
        raise ValueError('Unmapped original pointer '+hex(address))
    def pointer(self,at,length):return self.offset(struct.unpack_from('<I',self.raw,at)[0],length)

def block(source,number):
    start=re.search(r'^FUNC_%06d(?:_[A-Za-z0-9_]+)?:'%number,source,re.M)
    if not start:raise ValueError('Missing source procedure '+str(number))
    end=re.search(r'^(?:FUNC_\d+(?:_[A-Za-z0-9_]+)?|_[A-Za-z0-9_]+):',source[start.end():],re.M)
    return source[start.start():start.end()+end.start() if end else len(source)]

def dos_f879_comparison(source,executable,work):
    """Check source/DOS instruction bodies, permitting only documented SAR3/4."""
    raw=executable.read_bytes();signature=bytes.fromhex('558bec83c4c85356578b7d088b451450')
    at=raw.find(signature)
    if at<0 or raw.find(signature,at+1)>=0:raise ValueError('Ambiguous DOS F879 entry')
    end=raw.find(bytes.fromhex('558bec83c4f05356578b7d0c33c0'),at+len(signature))
    if end-at!=580:raise ValueError('Unexpected DOS F879 length')
    original=subprocess.check_output(['objdump','-D','-b','binary','-m','i386','-M','intel','--start-address='+hex(at),'--stop-address='+hex(end),str(executable)],text=True)
    def instructions(text):
        rows=[]
        for line in text.splitlines():
            found=re.match(r'\s*([0-9a-f]+):\t(?:[0-9a-f]{2} ?)+\s*\t([^\n]+)',line)
            if found:rows.append((int(found[1],16),re.sub(r'\s+',' ',found[2].split(' <')[0]).strip().replace('DWORD PTR ds:','ds:')))
        return rows
    dos=instructions(original)
    padding=0
    while dos and dos[-1][1]=='nop':dos.pop();padding+=1
    source_calls=re.findall(r'\bcall(?: near)?\s+(\[DATA_\d+\]|FUNC_\d+(?:_[A-Za-z0-9_]+)?)',block(source,879))
    dos_calls=[text for _,text in dos if text.startswith('call ')]
    if len(source_calls)!=len(dos_calls):raise ValueError('Source/DOS F879 call count differs')
    bindings={}
    for name,line in zip(source_calls,dos_calls):
        name=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',name.strip('[]'))
        address=int(line.split('0x')[-1],16)
        if name in bindings and bindings[name]!=address:raise ValueError('Source/DOS F879 callee consistency failed')
        bindings[name]=address
    lines=[]
    for line in block(source,879).splitlines():
        line=line.split(';')[0].strip()
        if not line:continue
        line=re.sub(r'\b(?:near|short)\s+','',line)
        line=re.sub(r'\b(byte|word|dword)\s*\[',lambda m:m[1].upper()+' PTR [',line)
        line=re.sub(r'\b(?:byte|word|dword)\s+(?=[+\-0-9])','',line)
        line=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',line)
        lines.append(line)
    asm='.intel_syntax noprefix\n.code32\n.section .text\n.global FUNC_000879\n'+'\n'.join('.set '+k+','+hex(v) for k,v in bindings.items())+'\n'+'\n'.join(lines)+'\n'
    (work/'surface32.s').write_text(asm)
    subprocess.run(['as','--32',str(work/'surface32.s'),'-o',str(work/'surface32.o')],check=True)
    subprocess.run(['ld','-m','elf_i386','-Ttext='+hex(at),'-e','FUNC_000879',str(work/'surface32.o'),'-o',str(work/'surface32')],check=True)
    ours=instructions(subprocess.check_output(['objdump','-d','-M','intel',str(work/'surface32')],text=True))
    def normalized(rows):
        targets={address:i for i,(address,_) in enumerate(rows)};result=[]
        for _,text in rows:
            branch=re.match(r'(j[a-z]+) (?:0x)?([0-9a-f]+)$',text)
            if branch:text=branch[1]+' instruction_'+str(targets[int(branch[2],16)])
            text=re.sub(r'^(call) 0x',r'\1 ',text)
            result.append(text)
        return result
    first=normalized(ours);second=normalized(dos)
    if len(first)!=len(second):raise ValueError('Source/DOS F879 instruction counts differ')
    differences=[{'instruction':i,'pinned_jjffe':a,'uploaded_dos':b} for i,(a,b) in enumerate(zip(first,second)) if a!=b]
    if len(differences)!=1 or differences[0]['pinned_jjffe']!='sar eax,0x3' or differences[0]['uploaded_dos']!='sar eax,0x4':raise ValueError('Unexpected source/DOS F879 instruction difference '+str(differences))
    return {'executable_offset':at,'byte_length':end-at,'trailing_alignment_nops':padding,'executable_block_sha256':sha(raw[at:end]),'normalized_instruction_count':len(first),'differences':differences,'all_other_instructions_equal':True,'callee_and_global_bindings':bindings,'pinned_normalized_sha256':sha(('\n'.join(first)+'\n').encode()),'dos_normalized_sha256':sha(('\n'.join(second)+'\n').encode())}

def resources(executable):
    image=Image(executable)
    worlds=json.loads((PROJECT/'data/ffe_worlds.json').read_text())
    port_models=set();parent_models=set()
    for system in worlds['systems']:
        by={int(row['local_index']):row for row in system['objects']}
        for row in system['objects']:
            if int(row['type_code'])==35:
                port_models.add(int(row['model_index']));parent_models.add(int(by[int(row['parent_index'])]['model_index']))
    used_port_models=sorted(port_models);used_parent_models=sorted(parent_models)
    # Include every preserved open-city model plus the actual underground
    # type96, while controls below retain only the21 real source ports.
    port_models.update(range(81,91))
    if len(parent_models)!=6 or len(port_models)!=11:raise ValueError('Unexpected supported handcrafted ground model domain')
    parent_models.update(range(117,134))
    model_ids=sorted(port_models|parent_models)
    result={};lines=['.section .data']
    for mid in model_ids:
        at=image.pointer(0xba8fc+mid*4,68)
        raw=executable[at:at+68];fields=struct.unpack('<17I',raw)
        col=image.offset(fields[13],6)
        vertices_at=image.offset(fields[1],24)
        if fields[14]!=0:raise ValueError('Unreviewed model physical specification '+str(mid))
        prefix=executable[col:col+3]
        before=executable[col-16:col]
        if before[-2:]!=bytes(2):raise ValueError('Unsupported source child collision list '+str(mid))
        natural=mid in parent_models
        if natural:
            if prefix not in [bytes.fromhex('1082ff'),bytes.fromhex('1083ff')]:raise ValueError('Unexpected natural collision stream')
            end=col+9
            while struct.unpack_from('<H',executable,end)[0]:
                end+=16
                if end>col+4096:raise ValueError('Unbounded natural features')
            tail=executable[end+2:end+7]
            if tail!=bytes.fromhex('5080000000'):raise ValueError('Unreviewed natural collision tail '+str(mid))
            collision=executable[col:end+7]
        else:
            # The reviewed F879 domain reads the true first collision byte
            # and the preceding zero child-list marker for the port. Other
            # city collision response commands are not this height oracle.
            collision=executable[col:col+64]
        vertex_count=4 if natural else max(4,((fields[0]>>8)&0xff))
        vertices=executable[vertices_at:vertices_at+24]
        row={'model_index':mid,'role':'natural_parent' if natural else 'ground_port',
             'descriptor_offset':hex(at),'descriptor_hex':raw.hex(),'descriptor_sha256':sha(raw),
             'scale':fields[5],'scale2':fields[6],'model_scale_raw':fields[5]+fields[6]-8,
             'outer_radius_raw':fields[11],'inner_radius_raw':fields[12],
             'flags_raw':fields[9],'physical_spec_pointer_raw':fields[14],
             'non_spherical_source_model':mid==117,
             'vertices_offset':hex(vertices_at),'vertices_hex':vertices.hex(),'vertices_sha256':sha(vertices),
             'vertices_scope':'first four source vertex records used by natural terrain basis; port vertex geometry is separate',
             'collision_offset':hex(col),'collision_prefix_hex':prefix.hex(),
             'collision_preceding_hex':before.hex(),'collision_preceding_sha256':sha(before),
             'collision_bytes_hex':collision.hex(),'collision_bytes_sha256':sha(collision),
             'collision_resource_scope':'complete natural terrain stream/features and original5080000000tail' if natural else 'bounded first64 bytes; F879 reads prefix and zero preceding child marker only',
             'pointer_relocations':{'descriptor+0x04':'vertices_hex','descriptor+0x34':'collision_bytes_hex'},
             'other_descriptor_pointers_kept_as_original_data_not_dereferenced':True}
        result[str(mid)]=row
        lines += [f'vertices_{mid}:','.byte '+','.join(map(str,vertices)),f'collision_before_{mid}:','.byte '+','.join(map(str,before)),f'collision_{mid}:','.byte '+','.join(map(str,collision)),f'descriptor_{mid}:']
        for index,value in enumerate(fields):
            replacement=f'vertices_{mid}' if index==1 else (f'collision_{mid}' if index==13 else str(value))
            lines.append('.long '+replacement)
    lines.append('DATA_004681:')
    for mid in range(150):lines.append('.long '+(f'descriptor_{mid}' if str(mid) in result else '0'))
    report={'schema':1,'source_sha256':EXE_SHA,'revision':'ffe-ground-collision-resources-v1',
            'scope':'Exact original descriptors, natural terrain stream/features and source vertices for all17 natural models; ground-port first collision prefix, zero child marker and bounded64-byte window. Model117 is non-spherical. No full city collision-response stream claim.',
            'parent_models':sorted(parent_models),'handcrafted_parent_models':used_parent_models,'port_models':sorted(port_models),'handcrafted_port_models':used_port_models,'models':result}
    return report,lines

def controls():
    fixture=json.loads((PROJECT/'tests/fixtures/handcrafted_runtime_native.json').read_text())
    rows=[]
    for case in fixture['cases']:
        if not case['name'].endswith('/ zero destination') or 'system_id' not in case:continue
        records=[bytes.fromhex(x) for x in case['expected']['records_hex']]
        for index,record in enumerate(records):
            if struct.unpack_from('<H',record,10)[0]!=35:continue
            parent_index=struct.unpack_from('<H',record,8)[0]
            parent=records[parent_index-1]
            base={'origin':'original handcrafted ground port after native F878','source_context':case['name'],
                  'system_id':case['system_id'],'local_index':index+1,'parent_index':parent_index,
                  'global_index':case['source_global_indices'][index],
                  'port_record_hex':record.hex(),'parent_record_hex':parent.hex(),
                  'port_model':struct.unpack_from('<H',record,12)[0],
                  'parent_model':struct.unpack_from('<H',parent,12)[0]}
            phase=struct.unpack_from('<H',record,18)[0];inclination=struct.unpack_from('<H',record,34)[0]
            for variation,(p,i) in enumerate([(phase,inclination),(0,0),(0x4000,0),(0x8000,0),(0xc000,0),(0,0x4000),(0,0xc000)]):
                row={**base,'angle_case':variation,'phase_u16':p,'inclination_u16':i,'graphics_level':1,'initial_globals':{name:0 for name,_,_ in GLOBAL_FIELDS}}
                port=bytearray(OBJECT);parent_object=bytearray(OBJECT)
                port[0x56]=parent_index;port[0x57]=1;port[0x86]=index+1
                parent_object[0x86]=parent_index
                struct.pack_into('<I',parent_object,0xa0,struct.unpack_from('<I',parent,4)[0])
                for axis in range(3):struct.pack_into('<I',parent_object,axis*16,0x7fffffff)
                row['port_object_input_hex']=port.hex();row['parent_object_input_hex']=parent_object.hex()
                rows.append(row)
    if len(rows)!=147:raise ValueError('Expected21groundports ×7angles, got '+str(len(rows)))
    known_models={row['parent_model'] for row in rows}
    for model in range(117,134):
        if model in known_models:continue
        for seed_index,seed in enumerate([1,0x12345678]):
            parent_record=bytearray(68);struct.pack_into('<I',parent_record,4,seed);struct.pack_into('<H',parent_record,12,model)
            for variation,(phase,inclination) in enumerate([(0x2345,0x1234),(0,0),(0x4000,0),(0x8000,0),(0xc000,0),(0,0x4000),(0,0xc000)]):
                port=bytearray(OBJECT);parent=bytearray(OBJECT)
                port[0x56]=1;port[0x57]=1;port[0x86]=2;parent[0x86]=1
                struct.pack_into('<I',parent,0xa0,seed)
                for axis in range(3):struct.pack_into('<I',parent,axis*16,0x7fffffff)
                rows.append({'origin':'original natural model with explicitly synthetic parent UID/object and source model84 probe',
                             'source_context':'model%d / seed%d'%(model,seed),'system_id':None,'local_index':2,'parent_index':1,
                             'global_index':-model*2-seed_index,'port_record_hex':bytes(68).hex(),'parent_record_hex':parent_record.hex(),
                             'port_model':84,'parent_model':model,'angle_case':variation,'phase_u16':phase,'inclination_u16':inclination,
                             'graphics_level':1,'initial_globals':{name:0 for name,_,_ in GLOBAL_FIELDS},
                             'port_object_input_hex':port.hex(),'parent_object_input_hex':parent.hex()})
    extra=[]
    for row in rows:
        if row['angle_case']==0:
            for level in [4,12]:extra.append({**row,'graphics_level':level})
    rows+=extra
    return rows

def packet(row):
    mode=0x80000000 if row.get('mode')=='height_query' else 0
    return struct.pack('<4I',row['port_model']|mode,row['parent_model']|(int(row.get('graphics_level',1))<<16),row['phase_u16'],row['inclination_u16'])+bytes.fromhex(row['port_object_input_hex'])+bytes.fromhex(row['parent_object_input_hex'])

def query_controls(placements):
    result=[];first_parent={}
    for row in placements:first_parent.setdefault(row['parent_model'],row['global_index'])
    far_done=set()
    for row in placements:
        if row['angle_case']==0:passes=[0,1]
        elif row['global_index']==first_parent[row['parent_model']]:passes=[0]
        else:continue
        for step in passes:
            point=row['expected']['passes'][step]['point_raw']
            query={'mode':'height_query','origin':'raw F574 probe using actual source model84 descriptor and independently native placement point',
                   'source_context':row['source_context'],'system_id':row['system_id'],'source_port_index':row['local_index'],
                   'parent_index':row['parent_index'],'port_model':84,'parent_model':row['parent_model'],
                   'parent_record_hex':row['parent_record_hex'],'phase_u16':0,'inclination_u16':0,
                   'graphics_level':row['graphics_level'],'initial_globals':dict(row['initial_globals']),
                   'point_input_raw':point,'source_angle_case':row['angle_case'],'source_height_pass':step,
                   'parent_object_input_hex':row['parent_object_input_hex']}
            port=bytearray.fromhex(row['port_object_input_hex'])
            struct.pack_into('<3q',port,0x3e,*(int(x) for x in point));query['port_object_input_hex']=port.hex()
            result.append(query)
        if row['parent_model'] not in far_done and row['angle_case']==1:
            far_done.add(row['parent_model']);query=dict(result[-1])
            point=[str(int(x)*4) for x in query['point_input_raw']]
            port=bytearray.fromhex(query['port_object_input_hex']);struct.pack_into('<3q',port,0x3e,*(int(x) for x in point))
            query.update(point_input_raw=point,port_object_input_hex=port.hex(),origin='raw F574 source broad-phase rejection at four times native outer-point vector')
            result.append(query)
    return result

def decode(rows,output,query=False):
    ordered_count=len(rows)*2
    for index,row in enumerate(rows):
        raw=output[index*OUTPUT:(index+1)*OUTPUT]
        if raw!=output[(ordered_count-1-index)*OUTPUT:(ordered_count-index)*OUTPUT]:raise ValueError('Source control order dependence')
        row['expected']={'initialized_port_hex':raw[:OBJECT].hex(),'initialized_parent_hex':raw[OBJECT:2*OBJECT].hex(),'port_hex':raw[2*OBJECT:3*OBJECT].hex(),'parent_hex':raw[3*OBJECT:4*OBJECT].hex(),'passes':[]}
        for step in range(1 if query else 2):
            values=struct.unpack_from('<3q12i',raw,4*OBJECT+step*TRACE_STRIDE)
            state={name:(value&0xffffffff if name.endswith('_u32') else value) for (name,_,_),value in zip(GLOBAL_FIELDS,values[4:])}
            row['expected']['passes'].append({'point_raw':[str(x) for x in values[:3]],'height_s32':values[3],**state})
        calls,queries=struct.unpack_from('<2I',raw,4*OBJECT+TRACE_STRIDE*2)
        if calls!=(1 if query else 2):raise ValueError('Unexpected source height-call count')
        row['expected']['height_calls']=calls;row['expected']['terrain_query_calls']=queries
        row['expected']['position_raw']=[str(x) for x in struct.unpack_from('<3q',raw,2*OBJECT+0x3e)]
        if query:row['expected']['point_after_raw']=[str(x) for x in struct.unpack_from('<3q',raw,4*OBJECT+TRACE_STRIDE*2+8)]
        if raw[-256:]!=bytes([0xa5])*256:raise ValueError('Source port/bank object canary changed')
        if row['expected']['initialized_parent_hex']!=row['expected']['parent_hex']:raise ValueError('Source query changed parent')
    return rows

def assembly(source,data,executable,sine,model_lines):
    sys.path.insert(0,str(PROJECT/'recovered-history/ground_harness/tools'))
    import build_terrain_query_reference as q
    old_numbers=q.NUMBERS;old_frames=q.WIDENED_FRAMES
    try:
        q.NUMBERS=sorted(set(old_numbers+EXTRA));q.WIDENED_FRAMES=old_frames+[582,1495,1669]
        hashes=q.function_hashes(source);text,terrain_resources=q.adapt_assembly(source,data,executable)
    finally:q.NUMBERS=old_numbers;q.WIDENED_FRAMES=old_frames
    start=text.index('_start:');end=text.index('.section .bss',start)
    text=text[:start]+WRAPPER.replace('@INPUT@',str(INPUT)).replace('@OUTPUT@',str(OUTPUT)).replace('@OBJECT@',str(OBJECT)).replace('@BANK@',str(BANK))+'\n'+text[end:]
    begin=text.index('FUNC_000879:');end=text.index('FUNC_001332:',begin)
    original=text[begin:end]
    observed=original.replace('FUNC_000879:','FUNC_998879:')
    observed=re.sub(r'JUMP_(\d+)',r'GROUND_OBS_\1',observed)
    text=text[:begin]+original.replace('call FUNC_000574','call OriginalF574')+observed+text[end:]
    text=text.replace('FUNC_001876:','FUNC_001876:\npushfq\ninc DWORD PTR [query_count_full]\npopfq')
    # Observe F574 arguments/results without changing any original instruction.
    text=text.replace('FUNC_000574:','OriginalF574:')
    trace=TRACE_F574
    capture=[]
    for index,(_,number,size) in enumerate(GLOBAL_FIELDS):
        capture.append(('movzx eax,BYTE PTR ' if size==1 else 'mov eax,DWORD PTR ')+('[DATA_%06d]'%number))
        capture.append('mov DWORD PTR [rbx+%d],eax'%(28+index*4))
    trace=trace.replace('@CAPTURE_GLOBALS@','\n'.join(capture))
    clear=['clear_height_globals:','push rax','xor eax,eax']
    for _,number,size in GLOBAL_FIELDS:clear.append(('mov BYTE PTR ' if size==1 else 'mov DWORD PTR ')+('[DATA_%06d],'%number)+('al' if size==1 else 'eax'))
    clear+=['pop rax','ret']
    text+='\n.section .text\n'+trace+'\n'+'\n'.join(clear)+'\n'
    drive=q.byte_block(q.data_block(data,7210))
    if executable.find(drive)<0:raise ValueError('Original hyperdrive resource differs')
    text+='\n.section .data\nDATA_007754: .long FUNC_001532\nDATA_007756: .long FUNC_001538\nDATA_007734: .long FUNC_001495\nDATA_007738: .long FUNC_001502\nDATA_007737: .long FUNC_001522\nDATA_007719: .long FUNC_001520\nDATA_007210: .byte '+','.join(map(str,drive))+'\nDATA_007975: .incbin "sine.bin"\n'+'\n'.join(model_lines)+'\n'
    for number in [7635,7636]:
        raw=q.byte_block(q.data_block(data,number))
        if raw!=bytes(4):raise ValueError('Original signed64 zero constant differs')
        text+='DATA_%06d: .byte '%number+','.join(map(str,raw))+'\n'
    text+='DATA_008804: .long 0\nDATA_008807: .long 0\n'
    text+='''\n.section .bss
.balign 16
input_full: .zero 692
output_full: .zero 1816
port_guard_before: .zero 64
port: .zero 338
port_guard_after: .zero 64
bank_guard_before: .zero 64
bank: .zero 86644
bank_guard_after: .zero 64
initial_port: .zero 338
initial_parent: .zero 338
untouched_port: .zero 338
untouched_parent: .zero 338
bank_before: .zero 86644
query_point: .zero 24
untouched_point: .zero 24
query_height: .zero 4
untouched_height: .zero 4
query_count_full: .zero 4
height_calls: .zero 4
height_trace: .zero 144
'''
    return text,hashes,terrain_resources,q

WRAPPER=r'''_start:
 mov esp,OFFSET FLAT:stack_end
 cld
next_full_case:
 xor r8d,r8d
read_full:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:input_full
 add rsi,r8
 mov edx,@INPUT@
 sub edx,r8d
 syscall
 test eax,eax
 jle finish_full
 add r8d,eax
 cmp r8d,@INPUT@
 jne read_full
 mov edi,OFFSET FLAT:bank
 xor eax,eax
 mov ecx,@BANK@
 rep stosb
 mov edi,OFFSET FLAT:port_guard_before
 mov eax,0xa5a5a5a5
 mov ecx,16
 rep stosd
 mov edi,OFFSET FLAT:port_guard_after
 mov ecx,16
 rep stosd
 mov edi,OFFSET FLAT:bank_guard_before
 mov ecx,16
 rep stosd
 mov edi,OFFSET FLAT:bank_guard_after
 mov ecx,16
 rep stosd
 mov esi,OFFSET FLAT:input_full+16
 mov edi,OFFSET FLAT:port
 mov ecx,@OBJECT@
 rep movsb
 movzx eax,BYTE PTR [port+0x56]
 imul eax,@OBJECT@
 add eax,OFFSET FLAT:bank+116
 mov ebx,eax
 mov esi,OFFSET FLAT:input_full+354
 mov edi,ebx
 mov ecx,@OBJECT@
 rep movsb
 mov eax,DWORD PTR [input_full+4]
 and eax,0xffff
 push rax
 push rbx
 push rbx
 call FUNC_001533
 add rsp,24
 mov eax,DWORD PTR [input_full]
 and eax,0xffff
 push rax
 push OFFSET FLAT:port
 push OFFSET FLAT:port
 call FUNC_001533
 add rsp,24
 mov esi,OFFSET FLAT:port
 mov edi,OFFSET FLAT:initial_port
 mov ecx,@OBJECT@
 rep movsb
 mov esi,ebx
 mov edi,OFFSET FLAT:initial_parent
 mov ecx,@OBJECT@
 rep movsb
 mov esi,OFFSET FLAT:bank
 mov edi,OFFSET FLAT:bank_before
 mov ecx,@BANK@
 rep movsb
 mov eax,DWORD PTR [input_full+4]
 shr eax,16
 mov DWORD PTR [DATA_008812],eax
 mov DWORD PTR [height_calls],0
 mov DWORD PTR [query_count_full],0
 mov edi,OFFSET FLAT:height_trace
 xor eax,eax
 mov ecx,36
 rep stosd
 call clear_height_globals
 test DWORD PTR [input_full],0x80000000
 jnz original_height_query
 push OFFSET FLAT:bank
 mov eax,DWORD PTR [input_full+12]
 push rax
 mov eax,DWORD PTR [input_full+8]
 push rax
 push OFFSET FLAT:port
 call FUNC_000879
 add rsp,32
 jmp original_complete
original_height_query:
 mov esi,OFFSET FLAT:port+0x3e
 mov edi,OFFSET FLAT:query_point
 mov ecx,6
 rep movsd
 push rbx
 push OFFSET FLAT:port
 push OFFSET FLAT:query_point
 push OFFSET FLAT:query_height
 call OriginalF574
 add rsp,32
 mov eax,DWORD PTR [query_height]
 mov DWORD PTR [untouched_height],eax
 mov esi,OFFSET FLAT:query_point
 mov edi,OFFSET FLAT:untouched_point
 mov ecx,6
 rep movsd
original_complete:
 mov esi,OFFSET FLAT:port
 mov edi,OFFSET FLAT:untouched_port
 mov ecx,@OBJECT@
 rep movsb
 mov esi,ebx
 mov edi,OFFSET FLAT:untouched_parent
 mov ecx,@OBJECT@
 rep movsb
 mov esi,OFFSET FLAT:bank
 mov edi,OFFSET FLAT:bank_before
 mov ecx,@BANK@
 repe cmpsb
 jne invalid_bank
 mov esi,OFFSET FLAT:initial_port
 mov edi,OFFSET FLAT:port
 mov ecx,@OBJECT@
 rep movsb
 mov esi,OFFSET FLAT:initial_parent
 mov edi,ebx
 mov ecx,@OBJECT@
 rep movsb
 mov DWORD PTR [query_count_full],0
 call clear_height_globals
 test DWORD PTR [input_full],0x80000000
 jnz observed_height_query
 push OFFSET FLAT:bank
 mov eax,DWORD PTR [input_full+12]
 push rax
 mov eax,DWORD PTR [input_full+8]
 push rax
 push OFFSET FLAT:port
 call FUNC_998879
 add rsp,32
 jmp observation_complete
observed_height_query:
 mov esi,OFFSET FLAT:port+0x3e
 mov edi,OFFSET FLAT:query_point
 mov ecx,6
 rep movsd
 push rbx
 push OFFSET FLAT:port
 push OFFSET FLAT:query_point
 push OFFSET FLAT:query_height
 call FUNC_000574
 add rsp,32
 mov eax,DWORD PTR [query_height]
 cmp eax,DWORD PTR [untouched_height]
 jne invalid_observation
 mov esi,OFFSET FLAT:query_point
 mov edi,OFFSET FLAT:untouched_point
 mov ecx,6
 repe cmpsd
 jne invalid_observation
observation_complete:
 mov esi,OFFSET FLAT:port
 mov edi,OFFSET FLAT:untouched_port
 mov ecx,@OBJECT@
 repe cmpsb
 jne invalid_observation
 mov esi,ebx
 mov edi,OFFSET FLAT:untouched_parent
 mov ecx,@OBJECT@
 repe cmpsb
 jne invalid_observation
 mov esi,OFFSET FLAT:bank
 mov edi,OFFSET FLAT:bank_before
 mov ecx,@BANK@
 repe cmpsb
 jne invalid_bank
 mov esi,OFFSET FLAT:initial_port
 mov edi,OFFSET FLAT:output_full
 mov ecx,@OBJECT@
 rep movsb
 mov esi,OFFSET FLAT:initial_parent
 mov ecx,@OBJECT@
 rep movsb
 mov esi,OFFSET FLAT:port
 mov ecx,@OBJECT@
 rep movsb
 mov esi,ebx
 mov ecx,@OBJECT@
 rep movsb
 mov esi,OFFSET FLAT:height_trace
 mov ecx,144
 rep movsb
 mov eax,DWORD PTR [height_calls]
 mov DWORD PTR [rdi],eax
 mov eax,DWORD PTR [query_count_full]
 mov DWORD PTR [rdi+4],eax
 test DWORD PTR [input_full],0x80000000
 jz no_query_point_output
 push rdi
 add edi,8
 mov esi,OFFSET FLAT:query_point
 mov ecx,6
 rep movsd
 pop rdi
no_query_point_output:
 add edi,64
 mov esi,OFFSET FLAT:port_guard_before
 mov ecx,64
 rep movsb
 mov esi,OFFSET FLAT:port_guard_after
 mov ecx,64
 rep movsb
 mov esi,OFFSET FLAT:bank_guard_before
 mov ecx,64
 rep movsb
 mov esi,OFFSET FLAT:bank_guard_after
 mov ecx,64
 rep movsb
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output_full
 mov edx,@OUTPUT@
 syscall
 jmp next_full_case
invalid_bank:
 mov eax,60
 mov edi,94
 syscall
invalid_observation:
 mov eax,60
 mov edi,95
 syscall
finish_full:
 mov eax,60
 xor edi,edi
 syscall
'''

TRACE_F574=r'''FUNC_000574:
 push rbp
 mov rbp,rsp
 push rbx
 push rsi
 push rdi
 mov ebx,DWORD PTR [height_calls]
 imul ebx,72
 add ebx,OFFSET FLAT:height_trace
 mov esi,DWORD PTR [rbp+24]
 mov edi,ebx
 mov ecx,6
 rep movsd
 push QWORD PTR [rbp+40]
 push QWORD PTR [rbp+32]
 push QWORD PTR [rbp+24]
 push QWORD PTR [rbp+16]
 call OriginalF574
 add rsp,32
 pushfq
 push rax
 push rcx
 push rdx
 mov eax,DWORD PTR [rbp+16]
 mov eax,DWORD PTR [eax]
 mov DWORD PTR [rbx+24],eax
@CAPTURE_GLOBALS@
 inc DWORD PTR [height_calls]
 pop rdx
 pop rcx
 pop rax
 popfq
 pop rdi
 pop rsi
 pop rbx
 pop rbp
 ret
'''

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--work',type=Path)
    args=parser.parse_args()
    raw_source=args.source.read_bytes();source=raw_source.decode().replace('\r\n','\n');data=args.source.with_name('ffedat.asm').read_text();executable=args.executable.read_bytes()
    if sha(raw_source)!=ASM_SHA or sha(executable)!=EXE_SHA:raise ValueError('Unsupported pinned source/executable')
    model_data,model_lines=resources(executable);rows=controls()
    at=executable.find(SIN_SIGNATURE)
    if at<0 or executable.find(SIN_SIGNATURE,at+1)>=0:raise ValueError('Ambiguous original sine table')
    sine=executable[at:at+65536]
    temporary=tempfile.TemporaryDirectory(prefix='ffe-ground-surface-') if args.work is None else None
    work=Path(temporary.name) if temporary else args.work;work.mkdir(parents=True,exist_ok=True);(work/'sine.bin').write_bytes(sine)
    text,hashes,terrain_resources,q=assembly(source,data,executable,work/'sine.bin',model_lines)
    (work/'surface.s').write_text(text)
    subprocess.run(['as','--64',str(work/'surface.s'),'-o',str(work/'surface.o')],check=True,cwd=work)
    undefined=subprocess.check_output(['nm','-u',str(work/'surface.o')],text=True)
    adapter,adapter_metadata=q.unresolved_adapter(undefined,data)
    # Proven DOS abs instruction semantics, with the host argument ABI only.
    if executable[0x67038:0x67038+len(ABS_DOS)]!=ABS_DOS:raise ValueError('Original CRT abs bytes differ')
    adapter=adapter.replace('_abs:\nmov eax,60\nmov edi,97\nsyscall','''_abs:
push rbp
mov rbp,rsp
mov eax,DWORD PTR [rbp+16]
test eax,eax
jge source_abs_positive
mov edx,eax
neg edx
jmp source_abs_return
source_abs_positive:
mov edx,eax
source_abs_return:
mov eax,edx
pop rbp
ret''')
    trap_codes={}
    def trap_code(match):
        code=100+len(trap_codes);trap_codes[code]=match[1]
        return match[1]+':\nmov eax,60\nmov edi,'+str(code)+'\nsyscall'
    adapter=re.sub(r'((?:FUNC_\d+|_[A-Za-z0-9_]+)):\nmov eax,60\nmov edi,97\nsyscall',trap_code,adapter)
    (work/'excluded.s').write_text(adapter);subprocess.run(['as','--64',str(work/'excluded.s'),'-o',str(work/'excluded.o')],check=True)
    subprocess.run(['ld','-m','elf_x86_64',str(work/'surface.o'),str(work/'excluded.o'),'-o',str(work/'surface')],check=True)
    def execute(cases):
        ordered=cases+list(reversed(cases));payload=b''.join(map(packet,ordered));outputs=[]
        for trial in range(3):
            result=subprocess.run([str(work/'surface')],input=payload,capture_output=True,timeout=120)
            if result.returncode!=0:raise RuntimeError('Original control failed status%d(%s) after%drecords; work%s'%(result.returncode,trap_codes.get(result.returncode,'native fault'),len(result.stdout)//OUTPUT,work))
            if len(result.stdout)!=len(ordered)*OUTPUT:raise ValueError('Incomplete native output')
            outputs.append(result.stdout)
        if outputs[0]!=outputs[1] or outputs[0]!=outputs[2]:raise ValueError('Fresh process source outputs differ')
        return outputs[0]
    output=execute(rows);decode(rows,output)
    query_rows=query_controls(rows);query_output=execute(query_rows);decode(query_rows,query_output,True)
    dos_comparison=dos_f879_comparison(source,args.executable,work)
    adapter_metadata['unreached_function_traps'].remove('_abs')
    resource_bytes=(json.dumps(model_data,separators=(',',':'))+'\n').encode()
    report={'schema':1,'revision':'source-ground-surface-native-v1','source_variant':VARIANT,'source_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'source_data_assembly_sha256':sha(args.source.with_name('ffedat.asm').read_bytes()),'source_commit':COMMIT,'source_procedure_hashes':hashes,'pinned_procedure_hashes':{n:sha(block(source,int(n)).encode()) for n in hashes},'dos_f879_instruction_comparison':dos_comparison,'scope':'Actual F1533 bounds/flags initialization and F879 two-pass placement through actual F574/F575/F576/F579/F582/F581/F1876, plus standalone F574 queries with an original model84 zero-inner-bound probe. Nonplayer zero-velocity source objects, all17 natural models and original terrain/contact normalization branches; damage/render branches abort. Model117 is non-spherical and its syntheticcontact cases do not imply a spherical provider. No synthetic height callback or universal SI surface-radius claim.','case_count':len(rows),'handcrafted_placement_case_count':sum(r['system_id'] is not None for r in rows),'synthetic_model_placement_case_count':sum(r['system_id'] is None for r in rows),'query_case_count':len(query_rows),'fresh_process_runs':3,'reverse_repeat_count':len(rows),'query_reverse_repeat_count':len(query_rows),'original_resources':terrain_resources,'host_adapter':adapter_metadata,'host_adaptations':{'two_pop_local_frames_widened_to_16_bytes':[582,1495,1669],'original_terrain_worker_two_pop_frames':q.WIDENED_FRAMES,'source_clock_globals_explicit32bit_zero':True,'source_objects_and_bank_low_address':True,'observed_clone_preserves_original_registers_and_flags':True},'observation_matches_untouched_objects':True,'parent_bank_unchanged':True,'dos_abs_entry':{'offset':0x67038,'bytes_hex':ABS_DOS.hex(),'sha256':sha(ABS_DOS)},'adapted_assembly_sha256':sha(text.encode()),'native_ordered_output_sha256':sha(output),'native_query_output_sha256':sha(query_output),'sine_sha256':sha(sine),'object_canaries_unchanged':True,'ground_resource':{'path':'data/ffe_ground_collision.json','sha256':sha(resource_bytes)},'input_fixtures_sha256':{name:sha((PROJECT/name).read_bytes()) for name in ['tests/fixtures/handcrafted_runtime_native.json','data/ffe_worlds.json']},'cases':rows,'query_cases':query_rows}
    (PROJECT/'data/ffe_ground_collision.json').write_bytes(resource_bytes)
    (PROJECT/'tests/fixtures/source_ground_surface_native.json').write_text(json.dumps(report,separators=(',',':'))+'\n')
    print('SOURCE GROUND SURFACE NATIVE:',len(rows),'placements,',len(query_rows),'F574queries; 3fresh,reverse,untouchedobservation; work',work)

if __name__=='__main__':main()
