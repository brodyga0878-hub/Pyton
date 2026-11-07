#!/usr/bin/env python3
"""Extract original DOS fuel/equipment/stellar-contact data without old-data edits.

F929 is deliberately variant-labelled: uploaded DOS does not restore all six
thrust limits on ordinary consumption, and exhaustion clears three limits.
JJFFE adds six-limit restoration/clearing. Table labels are not object bounds.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import struct

from extract_system_information import (ASM_SHA, COMMIT, DATA_SHA, EXE_SHA,
    cstring, db_bytes, sha, source_blocks, unique_offset)
from rebuild_ground_surface_native import Image, block

PROJECT=Path(__file__).resolve().parents[1]
HYPER_SHA='17fe376bf480aa34fe8278193c558a8a30d198fa06354caf3c9692de34b1cf47'
PROFILE='dos-firstenc-jetfuel-equipment-contact-v1'
CODE_BLOCKS={
    289:(0xf97c,345,'d83870c75de8cbf419e29dc914e0b7fe162478d6a49c03802a5617e7ca7c8ad3'),
    929:(0x2d988,265,'5cf107ea67615fff219284668c08d4774a4d6333ee025786ccdc6a760f8ae65e'),
    938:(0x2e23c,490,'ac4975750edefd5b501469a1f37a9a04297035efb4e9cd77e70f8508f8c756c2'),
    1033:(0x32560,461,'69ea2c057be92133c929ec44be09607a3567b3dd4011d89803322a3fd45e865c'),
}
EQUIPMENT_IDS={'refueller':14,'atmospheric_shielding':15,'laser_cooling_booster':18,
    'scanner':20,'autopilot':24,'shield_generator':27,'scoop':29,
    'cargo_scoop_conversion':30,'tractor_beam_cargo_scoop':35,
    'energy_booster':36,'hull_auto_repair':40}


def extract_drive_service_proof(executable:bytes,asm_bytes:bytes)->dict:
    """Separate evidence for F408/F410; never changes the frozen fuel JSON."""
    if sha(executable)!=EXE_SHA or sha(asm_bytes)!=ASM_SHA:
        raise ValueError('Pinned DOS/JJFFE source SHA256 mismatch')
    functions={}
    for number,at,count,effects in [
        (408,0x140b8,77,{'object_write_offsets':[0xd0],'jet_write':False,
                         'thrust_limit_writes':False,'initial_fuel_granted':False}),
        (410,0x14148,77,{'object_write_offsets':[0xd0,0x11e],'jet_write':True,
                         'jet_value_on_success':0,'thrust_limit_writes':False,
                         'requires_removable_spec_drive':True,'requires_matching_equipment_drive':True}),
    ]:
        raw=executable[at:at+count]
        if raw[:3]!=bytes.fromhex('558bec') or raw[-1]!=0xc3:
            raise ValueError('Unexpected drive-service instruction bounds')
        functions[str(number)]={'dos_file_offset':at,'dos_virtual_address':at+0x40f200,
            'byte_count':count,'hex':raw.hex(),'sha256':sha(raw),
            'jjffe_procedure_sha256':sha(block(asm_bytes.decode(),number).encode()),
            'statically_reviewed_effects':effects}
    removal=bytes.fromhex(functions['410']['hex'])
    installation=bytes.fromhex(functions['408']['hex'])
    encoded='c683d00000000033c089831e010000'
    at=unique_offset(executable,bytes.fromhex(encoded),'F410 clear-drive-and-jet')
    if at!=0x14179 or bytes.fromhex(encoded) not in removal or struct.pack('<I',0x11e) in installation:
        raise ValueError('Drive-service fuel side effects differ')
    return {'schema':1,'source_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,
        'source_commit':COMMIT,'functions':functions,
        'clear_drive_and_jet_anchor':{'dos_file_offset':at,'hex':encoded},
        'proof_kind':'Pinned original full function bytes and read-only DOS/ASM disassembly review; no instruction oracle executed',
        'full_jjffe_machine_code_equality_claimed':False,'native_oracle_executed':False,
        'frozen_fuel_resource_unchanged_sha256':'4d35dfd7047e7c3878ab92e25dcd9fde67697d7a93d46e53e57d0e1c7b71f14f',
        'scope':'F410 success clears removable drive and jet tank, without modifying six thrust-limit fields; F408 installs the selected drive but does not grant jet fuel. Prices and full outfitting transactions are separate.'}


def extract(executable:bytes,asm_bytes:bytes,data_bytes:bytes,hyper_bytes:bytes)->dict:
    if (sha(executable),sha(asm_bytes),sha(data_bytes))!=(EXE_SHA,ASM_SHA,DATA_SHA):
        raise ValueError('Pinned DOS/JJFFE source SHA256 mismatch')
    if sha(hyper_bytes)!=HYPER_SHA:
        raise ValueError('Immutable code40 hyperdrive resource differs')
    hyper=json.loads(hyper_bytes);blocks=source_blocks(data_bytes.decode())
    tables={};tables_hex={}
    for number,count in [(5111,60),(6266,60),(7208,40),(7209,44)]:
        raw=db_bytes(blocks[number]);at=unique_offset(executable,raw,str(number))
        if len(raw)!=count:raise ValueError('Unexpected fuel-table bounds '+str(number))
        tables_hex[str(number)]=raw.hex()
        tables[str(number)]={'source_label':number,'source_line':blocks[number].line,
            'dos_file_offset':at,'original_pointer_u32':at+0x416400,
            'byte_count':len(raw),'hex':raw.hex(),'sha256':sha(raw),'dos_matches_jjffe_data':True}
    equipment_table=hyper['tables']['equipment_records']
    at=equipment_table['dos_file_offset'];equipment_raw=executable[at:at+1452]
    if equipment_raw.hex()!=equipment_table['hex']:
        raise ValueError('Original equipment records differ from independently verified code40 table')
    tables['5289']={**equipment_table,'source_label':5289}
    # F383/F386 names an equipment record with FF9875+index. All66 text
    # pointers and their first-NUL bounds form the contiguous DATA5771..5836.
    names_raw=b''.join(db_bytes(blocks[label]) for label in range(5771,5837))
    names_at=unique_offset(executable,names_raw,'equipment names')
    names={};cursor=names_at
    for index in range(66):
        label=5771+index;raw=cstring(db_bytes(blocks[label]))
        if raw!=db_bytes(blocks[label]):raise ValueError('Equipment name crosses label '+str(label))
        names[index]={'source_label':label,'source_line':blocks[label].line,
                      'dos_file_offset':cursor,'hex':raw.hex(),'name_en':raw[:-1].decode('ascii')}
        cursor+=len(raw)
    equipment={}
    for key,index in EQUIPMENT_IDS.items():
        raw=equipment_raw[index*22:(index+1)*22]
        purchase,sale,mass,flags=struct.unpack_from('<4I',raw)
        kind,selector=raw[16],raw[18]
        item={'equipment_index':index,'name_ff_code':0x9875+index,
              **names[index],'record_hex':raw.hex(),'record_sha256':sha(raw),
              'record_file_offset':at+index*22,'purchase_price_raw_u32':purchase,
              'sale_price_raw_u32':sale,'mass_tonnes_u32':mass,'flags_u32':flags,
              'type_u8':kind,'source_selector_u8':selector,
              'availability_bytes_hex':raw[19:22].hex(),
              'equipment_mask_u32':1<<((selector^16)&31) if kind==0 else 0,
              'storage':'PhysObj+0xc8 equipmentDWORD' if kind==0 else 'PhysObj+0xe2 shield-capacity WORD',
              'single_install':kind==0,'required_spec_word_offset':None,
              'required_spec_mask_u16':0,'required_equipment_mask_u32':0}
        if key=='scoop':item.update(required_spec_word_offset=4,required_spec_mask_u16=0x100)
        if key=='cargo_scoop_conversion':item['required_equipment_mask_u32']=0x100000
        if key=='shield_generator':item.update(shield_capacity_increment_raw=64,single_install=False)
        equipment[key]=item
    code_blocks={}
    for number,(at,count,expected) in CODE_BLOCKS.items():
        raw=executable[at:at+count]
        if sha(raw)!=expected or not raw.startswith(bytes.fromhex('558bec')) or raw[-1]!=0xc3:
            raise ValueError('DOS procedure anchor mismatch F'+str(number))
        source=block(asm_bytes.decode(),number)
        code_blocks[str(number)]={'dos_file_offset':at,'dos_virtual_address':at+0x40f200,
             'byte_count':count,'sha256':sha(raw),'hex':raw.hex(),
             'jjffe_procedure_sha256':sha(source.encode()),
             'whole_jjffe_machine_code_equality_claimed':False}
    # These are individual, source-labelled instruction anchors, independent
    # of the compiler's source Pos comments or its choice of XOR encoding.
    anchors={}
    for key,at,encoded in [
        ('F394_scoop_hull_eligibility',0x13dc9,'0fbf4004f6c401'),
        ('F413_shield_capacity',0x14232,'668380e200000040'),
        ('F289_capacity_threshold',0xf9a8,'81eb999999013bf37222'),
        ('F929_DOS_consume_no_restore',0x2d99b,'8b8b1e0100008bd03bca760b29931e010000e9d9000000'),
        ('F929_DOS_clear_three_limits',0x2da70,'66c783bc000000000066c783c0000000000066c783c40000000000'),
        ('F1033_scoop_eligibility',0x3263d,'f687ca00000010747c817dfc80c3c9017f1a81bed800000028230000'),
    ]:
        raw=bytes.fromhex(encoded)
        if executable[at:at+len(raw)]!=raw:raise ValueError('DOS instruction anchor mismatch '+key)
        anchors[key]={'dos_file_offset':at,'hex':encoded,'byte_count':len(raw),'sha256':sha(raw)}

    image=Image(executable);models={}
    for index in range(134,149):
        descriptor_at=image.pointer(0xba8fc+index*4,68)
        descriptor=executable[descriptor_at:descriptor_at+68]
        words=struct.unpack('<17I',descriptor)
        vertices_at=image.offset(words[1],24);vertices=executable[vertices_at:vertices_at+24]
        stream_at=image.offset(words[13],16);stream=executable[stream_at:stream_at+16]
        if stream[:3]!=bytes.fromhex('1083ff') or stream[11:]!=bytes.fromhex('5080000000'):
            raise ValueError('Unexpected stellar terrain stream '+str(index))
        payload=stream[3:11];style=struct.unpack_from('<H',payload,4)[0]
        expected_style={134:3,135:6,136:5}.get(index,9)
        if style!=expected_style or payload[:4]!=bytes.fromhex('06020400') or payload[6:]!=bytes(2):
            raise ValueError('Unexpected stellar terrain payload '+str(index))
        models[str(index)]={'model_index':index,'descriptor_table_file_offset':0xba8fc+index*4,
            'descriptor_offset':hex(descriptor_at),'descriptor_hex':descriptor.hex(),'descriptor_sha256':sha(descriptor),
            'vertices_offset':hex(vertices_at),'vertices_hex':vertices.hex(),'vertices_sha256':sha(vertices),
            'collision_stream_offset':hex(stream_at),'collision_prefix_hex':stream[:3].hex(),
            'collision_stream_hex':stream.hex(),'collision_stream_sha256':sha(stream),
            'collision_payload_offset':hex(stream_at+3),'collision_payload_hex':payload.hex(),
            'collision_payload_sha256':sha(payload),'terrain_style_raw':style,
            'mesh_zoom':words[5]+words[6],'scale_u32':words[5],'scale2_u32':words[6],
            'outer_radius_bound_raw_u32':words[11],'inner_radius_bound_raw_u32':words[12],
            'flags_raw_u32':words[9],'physical_spec_pointer_raw_u32':words[14],
            'vector_scale_policy':'caller-supplied original frame/scale; no inferred SI radius',
            'bounds_policy':'broad-phase bounds only; contact must evaluate original F581/F1876 geometry'}
    starters={}
    for key in ['cobra','eagle','shuttle']:
        old=hyper['new_session_profiles'][key];model=old['source_model_index']
        spec=bytes.fromhex(hyper['ship_specs'][str(model)]['spec_hex'])
        main,reverse=struct.unpack_from('<hh',spec)
        # F1533 object+BC/BE/C0/C2/C4/C6 and F996/F424 cached8935..8940.
        axes=[-reverse,reverse,-reverse,reverse,main,reverse]
        initial=old['source_jetfuel_raw_u32']
        bits=old.get('source_equipment_bits_u32',0)
        starters[key]={'source_model_index':model,'initial_jet_raw_u32':0 if initial is None else initial,
            'initial_equipment_bits_u32':bits,'source_axis_order':['left','right','up','down','forward','retro'],
            'cached_thrust_limits_s16':axes,'source_spec_hex':spec.hex(),
            'original_starter':bool(old['original_starter']),
            'initial_jet_policy':'explicit bare adapter, zero; no original model15 F998 start exists' if key=='shuttle' else
                ('F998 selector3 original loadout subset' if key=='cobra' else 'explicit model24 adapter borrowing model23 F998 selector1 fuel/equipment'),
            'has_refueller':bool(bits&2),'has_scoop':bool(bits&0x100000),
            'scoop_hull_eligible':bool(struct.unpack_from('<H',spec,4)[0]&0x100)}
    return {'schema':1,'profile':PROFILE,'source_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,
        'source_data_sha256':DATA_SHA,'source_commit':COMMIT,'immutable_hyperdrive_resource_sha256':HYPER_SHA,
        'tables_hex':tables_hex,'tables':tables,'equipment':equipment,'starter_profiles':starters,
        'models':models,'dos_code_blocks':code_blocks,'dos_instruction_anchors':anchors,
        'constants':{'one_tonne_jet_raw_u32':0x20000000,'manual_refill_margin_raw_u32':0x1999999,
            'hydrogen_commodity_index':19,'military_commodity_index':20,'radioactives_commodity_index':29,
            'scoop_model_min':134,'scoop_model_max':148,'scoop_altitude_max_raw_s32':30000000,
            'scoop_min_speed_raw_s32':9000,'scoop_delay_raw_u32':0x2468a,
            'stellar_warning_altitude_raw_s32':12000000,'shield_generator_increment_raw_u16':64},
        'source_variants':{
            'F929':{'uploaded_DOS':'On cost<fuel subtract only; on exhaustion clear BC/C0/C4 only; auto-refill does not restore cached limits',
                    'pinned_JJFFE':'Adds cached six-axis restoration on ordinary consumption; exhaustion clears all6axis limits',
                    'DOS_automatic_restore':False,'DOS_exhaustion_cleared_offsets':[0xbc,0xc0,0xc4]},
            'F289':'DOS manual refill restores all6 cached thrust limits; tank capacity DATA5111, threshold capacity-0x1999999; unsigned boundaries/clamp remain original',
            'F938':'Shield recharge, hull repair, cooling, throttle-sum jet consumption; dependent F929 variant must be explicit',
            'F1033':'Original contact results/flags and conditional scoop/stellar heat; timer compare uses current step, not absolute clock',
            'F1014':'Pinned JJFFE changes atmospheric heating/gear code versus DOS; no whole-DOS-equivalence claim',
            'equipment':'DOS DATA5289 bytes used; four JJFFE availability-byte differences retained in table provenance'},
        'scope':'Raw source data, provenance and explicit NEW fuel-session starter adapters. No full player/world/atmosphere/heat/collision integration is proved by extraction; no old resource/save is silently migrated.'}


def main()->None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe'))
    parser.add_argument('--hyperdrive',type=Path,default=PROJECT/'data/ffe_hyperdrive.json')
    parser.add_argument('--output',type=Path,default=PROJECT/'data/ffe_fuel.json')
    args=parser.parse_args()
    result=extract(args.exe.read_bytes(),(args.source/'ffe.asm').read_bytes(),
                   (args.source/'ffedat.asm').read_bytes(),args.hyperdrive.read_bytes())
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'path':str(args.output),'sha256':sha(args.output.read_bytes()),
                      'equipment_count':len(result['equipment']),'contact_models':len(result['models'])}))


if __name__=='__main__':main()
