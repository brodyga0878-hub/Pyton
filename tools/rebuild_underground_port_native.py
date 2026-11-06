#!/usr/bin/env python3
"""Execute actual F650/F1674 and F880/F741 decision slices for enclosed model96.

Reuses the preserved original-instruction ground-pad harness; the player UI
callbacks remain non-return traps. F741's complete waypoint-selection slice is
tested, not F742's navigation controller. Original EXE tables are verified first.
"""
from __future__ import annotations
import argparse,hashlib,json,random,re,struct,subprocess,sys,tempfile,types
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
EXPECTED='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
ASM_SHA='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
sys.path.insert(0,str(PROJECT/'recovered-history/ground_harness/tools'))
# Only these constants are imported by the preserved pad harness. Its older
# command-line galaxy/settlement extraction dependencies are absent here; no
# native procedure, allocation output or geometry callback is substituted.
constants=types.ModuleType('build_ground_reference')
constants.SIN_SIGNATURE=bytes.fromhex('000000003f2403007e480600be6c0900fd900c003db50f007cd91200bbfd1500')
sys.modules['build_ground_reference']=constants
guard=types.ModuleType('extract_galaxy');guard.EXPECTED=EXPECTED
sys.modules['extract_galaxy']=guard
import build_ground_pads_reference as pads
from native_reference import procedures
OUTPUT_BYTES=104

def assembly(source,tables,sine):
    original_count=pads.count_snippet
    f880=source[source.index('FUNC_000880:'):]
    begin=f880.index('\t\tmov ax,[ebx+0xc]\n\t\tcmp ax,byte +0x51')
    end=f880.index('\tJUMP_003669:',begin)
    flags=f880[begin:end]
    pads.count_snippet=lambda text:flags+original_count(text)
    try:asm=pads.build_assembly(source,tables,sine)
    finally:pads.count_snippet=original_count
    f741=source[source.index('FUNC_000741:'):source.index('FUNC_000742:')]
    begin=f741.index('\t\ttest byte [esi+0x14c],0x10')
    end=f741.index('\t\tpush ebx\n\t\tcall FUNC_000742',begin)
    waypoint=f741[begin:end]
    selected='FUNC_999996:\n push ebp\n mov ebp,esp\n add esp,byte -0xc\n push ebx\n push esi\n mov ebx,[ebp+0x8]\n mov esi,[ebp+0xc]\n'+waypoint+' pop esi\n pop ebx\n mov esp,ebp\n pop ebp\n ret\nFUNC_999997:\nret\n'
    selected=re.sub(r'(FUNC_\d+)_[A-Za-z0-9_]+',r'\1',selected)
    lines,_=procedures(selected,[999996])
    asm=asm.replace('_start:\n','\n'.join(lines)+'\n_start:\n',1)
    marker=' mov eax,1\n mov edi,1\n mov esi,OFFSET FLAT:output\n mov edx,88\n syscall'
    added=''' push OFFSET FLAT:object
 push OFFSET FLAT:record
 call FUNC_999996
 add rsp,16
 movsx eax,WORD PTR [record+0x102]
 mov DWORD PTR [output+88],eax
 movsx eax,WORD PTR [record+0x104]
 mov DWORD PTR [output+92],eax
 movsx eax,WORD PTR [record+0x106]
 mov DWORD PTR [output+96],eax
 mov eax,DWORD PTR [object+0x14c]
 mov DWORD PTR [output+100],eax
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,104
 syscall'''
    if asm.count(marker)!=1:raise ValueError('Unexpected preserved original pad wrapper')
    return asm.replace(marker,added).replace('output: .zero 88','output: .zero 104').replace('record: .zero 64','record: .zero 512')

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    ap.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    ap.add_argument('--output',type=Path,default=PROJECT/'tests/fixtures/source_underground_native.json')
    args=ap.parse_args();raw=args.source.read_bytes();original=args.executable.read_bytes()
    if hashlib.sha256(raw).hexdigest()!=ASM_SHA or hashlib.sha256(original).hexdigest()!=EXPECTED:raise ValueError('Unreviewed original instruction/image revision')
    source=raw.decode().replace('\r\n','\n');data_source=args.source.with_name('ffedat.asm').read_text()
    tables=pads.extract_tables(data_source,original)['tables'];offset=original.find(pads.SIN_SIGNATURE)
    if offset<0 or original.find(pads.SIN_SIGNATURE,offset+1)>=0:raise ValueError('Missing/ambiguous source sine table')
    sine=list(struct.unpack('<16384i',original[offset:offset+65536]))
    angles=[(0,0),(16384,0),(32768,0),(49152,0),(0,16384),(0,49152),(65535,1),(1,65535),(16383,16385),(32769,49151),(26563,1585),(33966,3247)]
    contexts=[{'ground_phase_u16':a,'ground_inclination_u16':b,'explicit_matrix_q31':None} for a,b in angles]
    rng=random.Random(96650741)
    contexts +=[{'ground_phase_u16':0,'ground_inclination_u16':0,'explicit_matrix_q31':[rng.randrange(-2147483648,2147483648) for _ in range(9)]} for _ in range(12)]
    cases=[]
    for context in contexts:
        configurations=[('all_free',7,[0]*8,-2),('all_occupied',7,[23]*8,-2),('no_slot',7,[0]*8,-1),('signed_min',-128,[128]*8,-2),('signed_existing',-1,[255]*8,-2),('unsigned_not_signed',255,[255]*8,-2),('zero_existing',0,[0]*8,-2)]
        for i in range(6):
            occupancy=[23]*8;occupancy[i]=0;configurations.append(('specific_free_'+str(i),7,occupancy,-2))
            occupancy=[23]*8;occupancy[i]=7;configurations.append(('existing_'+str(i),7,occupancy,-2))
        configurations.append(('higher_free_before_existing',7,[7,0,0,0,0,0,0,0],-2))
        for name,identifier,occupancy,last in configurations:cases.append({**context,'name':name,'npc_id_i32':identifier,'occupancy_before_u8':occupancy,'last_slot_override_i32':last})
    payloads=[]
    for case in cases:
        matrix=case['explicit_matrix_q31'] or [0]*9
        words=[96,case['npc_id_i32'],case['last_slot_override_i32'],int(case['explicit_matrix_q31'] is None),case['ground_phase_u16'],case['ground_inclination_u16'],*matrix]
        payloads.append(struct.pack('<15I',*(v&0xffffffff for v in words))+bytes(case['occupancy_before_u8'])+struct.pack('<I',0x30))
    text=assembly(source,tables,sine)
    with tempfile.TemporaryDirectory(prefix='ffe-enclosed-native-') as tmp:
        path=Path(tmp);(path/'source.s').write_text(text)
        subprocess.run(['as','--64',str(path/'source.s'),'-o',str(path/'source.o')],check=True)
        subprocess.run(['ld','-m','elf_x86_64',str(path/'source.o'),'-o',str(path/'source')],check=True)
        def run(rows):
            out=subprocess.run([str(path/'source')],input=b''.join(rows),stdout=subprocess.PIPE,check=True,timeout=20).stdout
            if len(out)!=len(rows)*OUTPUT_BYTES:raise ValueError('Incomplete actual instruction output')
            return [out[i:i+OUTPUT_BYTES] for i in range(0,len(out),OUTPUT_BYTES)]
        rows=run(payloads)
        if run(payloads)!=rows or run(payloads)!=rows or run(payloads[::-1])!=rows[::-1]:raise ValueError('State contamination across source native cases')
    for case,row in zip(cases,rows):
        ret,status,slot=struct.unpack_from('<3i',row)
        matrix=list(struct.unpack_from('<9i',row,36));initial,last=struct.unpack_from('<2i',row,80)
        waypoint=list(struct.unpack_from('<3i',row,88));flags=struct.unpack_from('<I',row,100)[0]
        target=list(struct.unpack_from('<3q',row,12));after=list(row[72:80])
        if initial!=5 or flags!=0x30:raise ValueError('Model96 unexpectedly initialized open geometric pads')
        if case['explicit_matrix_q31'] is None and matrix!=pads.matrix_for_angles(case['ground_phase_u16'],case['ground_inclination_u16'],sine):raise ValueError('Original F1674 matrix differs')
        expected_waypoint=[pads.signed(pads.mul(6000,matrix[3+i]),16) for i in range(3)]
        if waypoint!=expected_waypoint:raise ValueError('Original F741 ground waypoint differs')
        selected=-1;expected_after=case['occupancy_before_u8'].copy();allocated=0
        for i in range(last,-1,-1):
            if pads.signed(expected_after[i],8)==case['npc_id_i32']:selected=i;break
            if expected_after[i]==0:selected=i;expected_after[i]=case['npc_id_i32']&255;allocated=-1;break
        if after!=expected_after or ret!=(0 if selected>=0 else -1):raise ValueError('Actual F650 allocation differs from independent signed-byte scalar trace')
        if selected>=0 and (slot!=selected or status!=allocated or target!=[0,0,-1]):raise ValueError('Actual F650 enclosed target differs')
        if selected<0 and (slot!=pads.PAD_SENTINEL or status!=pads.STATUS_SENTINEL or target!=pads.POINT_SENTINELS):raise ValueError('Actual failed F650 changed target outputs')
        case['matrix_q31']=matrix
        case['expected']={'return_i32':ret,'allocation_status_i32':status,'selected_slot_i32':slot,'target_vec64_raw':target,'occupancy_after_u8':after,'initialized_last_slot_i32':initial,'actual_last_slot_i32':last,'approach_raw':[v<<10 for v in waypoint],'flags_u32':flags}
    result={'schema_version':1,'source_executable_sha256':EXPECTED,'source_assembly_sha256':ASM_SHA,'source_commit':'7e540341d4e09aa3c92877b87d49e7f2c143ad8d','generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'native_assembly_sha256':hashlib.sha256(text.encode()).hexdigest(),'case_count':len(cases),'fresh_process_runs':3,'reverse_repeat_count':len(cases),'scope':'Complete original F650 NPC/non-openpad branch plus F1674/F1669/F1521/F1914; actual F880 flags/count and F741 waypoint-selection slices. No F742 autopilot or F575 contact-provider emulation.','cases':cases}
    args.output.write_text(json.dumps(result,separators=(',',':'))+'\n')
    print('Original enclosed hangar F650/F741:',len(cases),'native cases,3fresh processes andreverse order verified')

if __name__=='__main__':main()
