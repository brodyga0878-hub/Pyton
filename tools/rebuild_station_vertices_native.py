#!/usr/bin/env python3
"""Execute pinned F1470/F1478 for all ten original orbital roots.

The original triangle programs remain the existing source-model compiler; this
independent oracle checks original root vertex arithmetic, including kinds
11/19 and explicit caller-local/door snapshots. No GDScript output is imported.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import rebuild_model_vertices_native as vertex
from rebuild_ground_surface_native import Image

MODELS=[69]+list(range(72,81))
OUTPUT=1600

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--output',type=Path,default=vertex.PROJECT/'tests/fixtures/source_station_vertices_native.json')
    parser.add_argument('--work',type=Path)
    args=parser.parse_args();raw=args.exe.read_bytes();source_raw=args.source.read_bytes()
    if vertex.sha(raw)!=vertex.EXE_SHA or vertex.sha(source_raw)!=vertex.ASM_SHA:raise ValueError('Unexpected pinned input')
    image=Image(raw);models={}
    for index in MODELS:
        at=image.pointer(0xba8fc+index*4,68);descriptor=raw[at:at+68];fields=struct.unpack('<17I',descriptor);count=fields[2]
        if count%2 or count>128:raise ValueError('Unexpected source vertex count')
        vat=image.offset(fields[1],count*3);stream=raw[vat:vat+count*3]
        if not set(stream[::6])<={1,5,11,19}:raise ValueError('Unreviewed vertex instruction family')
        models[index]={'descriptor_offset':at,'descriptor_hex':descriptor.hex(),'descriptor_sha256':vertex.sha(descriptor),'vertices_offset':vat,'vertices_hex':stream.hex(),'vertices_sha256':vertex.sha(stream),'vertex_count':count,'scale_shift_raw':fields[5]+fields[6]}
    contexts=[]
    for existing in vertex.contexts():
        door=existing['frame_parameters'][2]
        for policy in ['explicit-zero-eight-root-locals-v1','explicit-door-in-bay-locals1-and2-v1']:
            ctx={k:list(v) for k,v in existing.items()};ctx['entity_variables_u16'][1]=door
            ctx['frame_parameters']=[0]*8
            if policy.endswith('locals1-and2-v1'):ctx['frame_parameters'][1]=door;ctx['frame_parameters'][2]=door
            ctx['caller_policy']=policy;ctx['door_u16']=door;contexts.append(ctx)
    old=vertex.OUTPUT
    try:
        vertex.OUTPUT=OUTPUT;text,hashes=vertex.assembly(source_raw.decode())
    finally:vertex.OUTPUT=old
    for old_offset,new_offset in [(768,1536),(772,1540),(776,1544),(784,1552),(792,1560)]:text=text.replace('output+'+str(old_offset),'output+'+str(new_offset))
    order=[(index,ci) for index in MODELS for ci in range(len(contexts))]
    packets=[vertex.packet(models[index],contexts[ci]) for index,ci in order]
    with tempfile.TemporaryDirectory(prefix='ffe-station-vertices-') as directory:
        work=args.work or Path(directory);work.mkdir(parents=True,exist_ok=True);(work/'native.s').write_text(text)
        subprocess.run(['as','--64',str(work/'native.s'),'-o',str(work/'native.o')],check=True)
        subprocess.run(['ld',str(work/'native.o'),'-o',str(work/'native')],check=True)
        outputs=[]
        for _ in range(3):
            run=subprocess.run([str(work/'native')],input=b''.join(packets),capture_output=True)
            if run.returncode:raise RuntimeError('Native vertex failure%d after%d cases; next%s work%s'%(run.returncode,len(run.stdout)//OUTPUT,order[len(run.stdout)//OUTPUT],work))
            outputs.append(run.stdout)
        if len(set(outputs))!=1 or len(outputs[0])!=len(order)*OUTPUT:raise ValueError('Unstable native vertex output')
        reverse=subprocess.run([str(work/'native')],input=b''.join(packets[::-1]),capture_output=True,check=True).stdout
        if reverse!=b''.join(outputs[0][i*OUTPUT:(i+1)*OUTPUT] for i in reversed(range(len(order)))):raise ValueError('Order-dependent native vertex state')
    cases=[]
    for i,(index,ci) in enumerate(order):
        output=outputs[0][i*OUTPUT:(i+1)*OUTPUT];count=models[index]['vertex_count']
        if struct.unpack_from('<2Q',output,1544)!=(vertex.GUARD,vertex.GUARD) or struct.unpack_from('<I',output,1560)[0]!=count:raise ValueError('Native vertex guard failed')
        cases.append({'model_index':index,'context_index':ci,'vertices_local_raw':[list(struct.unpack_from('<3i',output,j*12)) for j in range(count)],'final_random_state_u32':list(struct.unpack_from('<2I',output,1536))})
    report={'schema':1,'revision':'source-station-vertices-native-v1','source_sha256':vertex.EXE_SHA,'source_assembly_sha256':vertex.ASM_SHA,'source_procedure_hashes':hashes,'adapted_assembly_sha256':vertex.sha(text.encode()),'input_packets_sha256':vertex.sha(b''.join(packets)),'native_ordered_output_sha256':vertex.sha(outputs[0]),'fresh_process_runs':3,'reverse_repeat_count':len(order),'guard_canaries_unchanged':True,'models':{str(k):v for k,v in models.items()},'contexts':contexts,'cases':cases,'case_count':len(cases),'scope':'Actual original unprojected F1470/F1478 instructions for all10 orbital roots69/72..80. Explicit Q31 matrices, zero root locals, and distinct source door/entity/local snapshots; vertex kinds1/5/11/19. Source model-program branches/triangles and child-model caller frames are compiled separately and are not claimed native-executed by this oracle.','host_adaptations':{'low_address_x86_64_abi':True,'jump_table_pointers':'original32bit entries to low host labels','projection_argument':0,'projected_only_unreachable_branches_exit_code':93,'vertex_output_capacity':128}}
    args.output.write_text(json.dumps(report,separators=(',',':'))+'\n')
    print('SOURCE STATION VERTICES NATIVE:',len(cases),'cases;',sum(len(x['vertices_local_raw']) for x in cases),'points; fixture',vertex.sha(args.output.read_bytes()))

if __name__=='__main__':main()
