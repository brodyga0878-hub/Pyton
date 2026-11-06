#!/usr/bin/env python3
"""Independent source F603 samples and exact rational nominal-day SI controls.

Raw kicks and F880 coefficients come from real extracted instructions. Python
Fraction applies the explicit unit policy to those integer outputs; it never
reconstructs F603 or obtains expectations from the new GDScript bridge.
"""
from __future__ import annotations
import argparse, hashlib, json, math, random, struct, subprocess, tempfile
from fractions import Fraction
from pathlib import Path
import rebuild_source_gravity_native as native
from rebuild_ground_surface_native import Image

PROJECT=Path(__file__).resolve().parents[1]
CONTRACT='sampled-f603-nominal-day-si-v1'
TPS=Fraction(1<<32,86400)
METRES_PER_RAW=Fraction(16785,1<<24)
VELOCITY_UNIT=METRES_PER_RAW*TPS/512
REFERENCE=49710

def sha(raw):return hashlib.sha256(raw).hexdigest()

def blank_body(position=(0,0,0)):
    raw=bytearray(338);raw[0x56]=1;struct.pack_into('<3q',raw,0x3e,*position)
    return bytes(raw)

def blank_parent(a4=0):
    raw=bytearray(338);struct.pack_into('<I',raw,0xa4,a4);return bytes(raw)

def mass_controls():
    source=json.loads((PROJECT/'tests/fixtures/handcrafted_runtime_native.json').read_text())
    rows=[];seen=set()
    for case in source['cases']:
        if not (case['name'].endswith('/ zero destination') or case['name']=='Unmapped Riedquat diagnostic / zero'):continue
        for index,record in enumerate(case['expected']['records_hex']):
            if record in seen:continue
            seen.add(record)
            rows.append({'name':case['name']+' / record%d'%index,'source_context':case['name'],'record_hex':record,'body_hex':blank_body().hex(),'parent_hex':blank_parent().hex()})
    return rows

def rows_from_records(masses,exe):
    rows=[];image=Image(exe)
    def add(record,a4,position,name,step=REFERENCE,origin='source descriptor sphere used only as a coordinate input'):
        rows.append({'name':name,'origin':origin,'record_hex':record,'a4_native_u32':a4,'relative_raw':[str(x) for x in position],
                     'step_s32':step,'reference_step_ticks':step,'body_hex':blank_body(position).hex(),'parent_hex':blank_parent(a4).hex()})
    for item in masses:
        record=bytes.fromhex(item['record_hex']);a4=item['expected_a4_u32'];model=struct.unpack_from('<H',record,12)[0]
        if model>=150:raise ValueError('Unreviewed original model index')
        at=image.pointer(0xba8fc+model*4,68);fields=struct.unpack_from('<17I',exe,at)
        exponent=fields[5]+fields[6]-8
        mantissa=struct.unpack_from('<h',exe,at+0x2c)[0]
        radius=mantissa*(1<<exponent) if exponent>=0 else mantissa>>-exponent
        radius=max(1,abs(radius))
        for multiple in [1,2,10]:
            r=radius*multiple
            if r>=(1<<63):raise ValueError('Input radius outside signed64')
            for axis in range(3):
                for sign in [1,-1]:
                    point=[0,0,0];point[axis]=r*sign
                    add(item['record_hex'],a4,point,item['name']+' / radius%d axis%d sign%d'%(multiple,axis,sign))
        for direction in [(3,4,0),(-3,4,0),(1,-2,2),(-1,-2,-2)]:
            length=math.sqrt(sum(v*v for v in direction));point=[round(radius*v/length) for v in direction]
            add(item['record_hex'],a4,point,item['name']+' / oblique'+str(direction))
        add(item['record_hex'],a4,(0,0,0),item['name']+' / zero-distance guard',origin='explicit zero-distance source guard')
    by_record={row['record_hex']:row['expected_a4_u32'] for row in masses}
    surface=json.loads((PROJECT/'tests/fixtures/source_ground_surface_native.json').read_text())
    for case in surface['cases']:
        if case['system_id'] is None or case['angle_case']!=0 or case['graphics_level']!=1:continue
        record=case['parent_record_hex'];a4=by_record[record];point=[int(x) for x in case['expected']['position_raw']]
        for sign in [1,-1]:
            add(record,a4,[x*sign for x in point],case['source_context']+' / native F879 port%d sign%d'%(case['local_index'],sign),origin='actual independently native F879 surface position and its reflected input')
    earth=next(row for row in masses if row['source_context']=='Sol / zero destination' and bytes.fromhex(row['record_hex'])[38:43]==b'Earth')
    for power in range(13,49):
        for offset in [-1,0,1]:
            r=(1<<power)+offset
            for sign in [1,-1]:add(earth['record_hex'],earth['expected_a4_u32'],(r*sign,0,0),'Earth normalization power%d offset%d sign%d'%(power,offset,sign),origin='exact input around a source integer normalization boundary')
    reference_point=(round(Fraction(6371000,1)/METRES_PER_RAW),0,0)
    for step in [1,127,128,512,32767,32768,49700,49710,50000,0x7fffffff]:
        add(earth['record_hex'],earth['expected_a4_u32'],reference_point,'Earth explicit sampling dt%d'%step,step=step,origin='input-only legacy radius and alternate reference ticks; bridge sampling policy comparison')
    return rows

def conversions(rows):
    for row in rows:
        expected=row['expected'];q=[v*65536+f for v,f in zip(expected['velocity_s32'],expected['fraction_u16'])]
        duration=Fraction(row['reference_step_ticks'],1)/TPS
        velocity=[Fraction(value,65536)*VELOCITY_UNIT for value in q]
        acceleration=[value/duration for value in velocity]
        expected.update(delta_velocity_q16=[str(value) for value in q],delta_velocity_mps=[float(value) for value in velocity],
                        acceleration_mps2=[float(value) for value in acceleration],
                        acceleration_exact_rational=[[str(value.numerator),str(value.denominator)] for value in acceleration],
                        reference_duration_seconds=float(duration),gravity_mps2=math.sqrt(sum(float(value)**2 for value in acceleration)))

def integration_controls():
    result=[]
    for ticks in [128,512,49710,1<<32]:
        for velocity in [(1,0,0),(0,-1,0),(3,-4,12)]:
            body=bytearray(blank_body());struct.pack_into('<3i',body,0x8c,*velocity)
            result.append({'name':'unit policy drift ticks%d velocity%s'%(ticks,velocity),'body_hex':body.hex(),'parent_hex':blank_parent().hex(),'step_words':[ticks&0xffffffff,ticks>>32]})
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe/ffe.asm'))
    parser.add_argument('--executable',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    args=parser.parse_args()
    raw_source=args.source.read_bytes();exe=args.executable.read_bytes()
    if sha(raw_source)!=native.ASM_SHA or sha(exe)!=native.EXE_SHA:raise ValueError('Unsupported pinned source')
    if exe[0x67038:0x67038+len(native.ABS_DOS)]!=native.ABS_DOS:raise ValueError('Original CRT abs differs')
    source=raw_source.decode().replace('\r\n','\n');assembly,hashes=native.assembly(source)
    masses=mass_controls();drifts=integration_controls()
    with tempfile.TemporaryDirectory(prefix='ffe-physics-bridge-') as directory:
        work=Path(directory);(work/'control.s').write_text(assembly)
        dos=native.verify_dos_f603(source,args.executable,work)
        subprocess.run(['as','--64',str(work/'control.s'),'-o',str(work/'control.o')],check=True)
        subprocess.run(['ld','-m','elf_x86_64',str(work/'control.o'),'-o',str(work/'control')],check=True)
        coefficient_digest,_=native.execute(work/'control',1,masses)
        rows=rows_from_records(masses,exe);kick_digest,_=native.execute(work/'control',0,rows)
        drift_digest,_=native.execute(work/'control',2,drifts)
    conversions(rows)
    fixture={'schema':1,'revision':'source-physics-bridge-native-v1','contract':CONTRACT,'source_variant':native.VARIANT,
             'source_sha256':native.EXE_SHA,'source_assembly_sha256':native.ASM_SHA,'source_commit':native.COMMIT,
             'scope':'Exact native F880 coefficients and zero-velocity/fraction F603 kicks. SI expectations are exact rational application of an explicit nominal-day unit policy, not a reconstruction of the force law or the original per-frame integrator.',
             'source_procedure_hashes':hashes,'dos_f603_instruction_comparison':dos,
             'reference_step_ticks':REFERENCE,'ticks_per_second_rational':[str(TPS.numerator),str(TPS.denominator)],
             'metres_per_raw_rational':[str(METRES_PER_RAW.numerator),str(METRES_PER_RAW.denominator)],
             'velocity_unit_mps_rational':[str(VELOCITY_UNIT.numerator),str(VELOCITY_UNIT.denominator)],
             'reference_duration_seconds':float(Fraction(REFERENCE,1)/TPS),
             'coefficient_case_count':len(masses),'case_count':len(rows),'drift_case_count':len(drifts),
             'fresh_process_runs':3,'reverse_repeat_count':len(rows),'coefficient_reverse_repeat_count':len(masses),'drift_reverse_repeat_count':len(drifts),
             'zero_sample_initial_velocity_and_fraction':True,'object_canaries_unchanged':True,'parent_bank_unchanged_except_coefficient':True,
             'native_coefficient_output_sha256':coefficient_digest,'native_kick_output_sha256':kick_digest,'native_drift_output_sha256':drift_digest,
             'adapted_assembly_sha256':sha(assembly.encode()),'normalization_quirks_preserved':True,'original_per_frame_dynamics':False,
             'input_fixtures_sha256':{name:sha((PROJECT/name).read_bytes()) for name in ['tests/fixtures/handcrafted_runtime_native.json','tests/fixtures/source_ground_surface_native.json']},
             'coefficient_cases':masses,'cases':rows,'drift_cases':drifts}
    path=PROJECT/'tests/fixtures/source_physics_bridge_native.json';path.write_text(json.dumps(fixture,separators=(',',':'))+'\n')
    print(json.dumps({'fixture':str(path),'coefficients':len(masses),'samples':len(rows),'drifts':len(drifts),'sha256':sha(path.read_bytes())},indent=2))

if __name__=='__main__':main()
