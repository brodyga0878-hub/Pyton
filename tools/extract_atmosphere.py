#!/usr/bin/env python3
"""Extract DOS atmospheric/damage/RNG anchors without changing old resources.

The uploaded F1014 is authoritative. JJFFE's frame-rate heat/drag fixes are a
different policy. A modern60Hz caller is documented as an adapter, never as an
inferred original rate. Heat continues to use the existing game+1EC state.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import struct

from extract_system_information import ASM_SHA, COMMIT, DATA_SHA, EXE_SHA, sha
from rebuild_ground_surface_native import block

PROJECT=Path(__file__).resolve().parents[1]
HYPER_SHA='17fe376bf480aa34fe8278193c558a8a30d198fa06354caf3c9692de34b1cf47'
FUEL_SHA='4d35dfd7047e7c3878ab92e25dcd9fde67697d7a93d46e53e57d0e1c7b71f14f'
PROCEDURES={
    34:(0x32f8,31,'fbafd34f244fc54703ebc14e55a04731088dfd1a8462e87d99f4020b4ee63187',12),
    35:(0x3318,15,'96974c654576f4f30e03da8d77af820eb9b6b2e0ce0c037ab98b817e3c7e5866',6),
    953:(0x2ed7c,436,'aa8ec30bafd1e80ed164f34e8b384a2ff9e46d8eaf9a17239ee9065d84874469',131),
    1014:(0x31890,321,'dcdc0bc325086ddaff36264342e39a703e41543d7e0badd4f067c3a5ce595095',94),
    1016:(0x319ec,27,'d11d23496ba03a43ce954ab8e0906dcb2f53cecfd8b2425911e2ccfc517137c5',10),
    1017:(0x31a08,10,'2d8a6cf3a78899319464c62419cb1f5f1b36331ff4359fc1b1081d1ccbbea30a',6),
    1521:(0x44278,17,'f62a5f949cbf8da772c3cc32ae59b607e0f35cda6c3c4e1ddf848ba3b5a1b445',9),
    1530:(0x444bc,63,'35fb8bff8c10fc5628238eb1cfe0078393caf7fa1a4cdb6a6d28374e6edf0535',18),
}


def extract(executable:bytes,asm_bytes:bytes,data_bytes:bytes,hyper_bytes:bytes,fuel_bytes:bytes)->dict:
    if (sha(executable),sha(asm_bytes),sha(data_bytes))!=(EXE_SHA,ASM_SHA,DATA_SHA):
        raise ValueError('Pinned DOS/JJFFE source SHA256 mismatch')
    if sha(hyper_bytes)!=HYPER_SHA or sha(fuel_bytes)!=FUEL_SHA:
        raise ValueError('Immutable previous hyperdrive/fuel resource differs')
    source=asm_bytes.decode();hyper=json.loads(hyper_bytes);fuel=json.loads(fuel_bytes)
    procedures={}
    for number,(at,count,expected,instructions) in PROCEDURES.items():
        raw=executable[at:at+count]
        if sha(raw)!=expected or raw[-1]!=0xc3:raise ValueError('DOS procedure anchor mismatch F'+str(number))
        pinned=block(source,number)
        procedures[str(number)]={'source_label':'FUNC_%06d'%number,
            'source_line':source.count('\n',0,source.index(pinned))+1,
            'pinned_jjffe_procedure_sha256':sha(pinned.encode()),
            'dos_file_offset':at,'dos_virtual_address':at+0x40f200,'byte_count':count,
            'hex':raw.hex(),'sha256':sha(raw),'independently_normalized_instruction_count':instructions,
            'pinned_jjffe_instructions_match_dos':number!=1014,
            'instruction_proof_policy':'Only branch destination addresses normalized; F1014 canonical reconstruction comes directly from DOS, not modified JJFFE'}
    profiles={}
    for key in ['cobra','eagle','shuttle']:
        old=hyper['new_session_profiles'][key];model=old['source_model_index'];spec=hyper['ship_specs'][str(model)]
        raw=bytes.fromhex(spec['spec_hex']);mass=struct.unpack_from('<h',raw,6)[0]
        profiles[key]={'source_model_index':model,'spec_hex':raw.hex(),'spec_sha256':sha(raw),
            'hull_mass_tonnes_s16':mass,'maximum_hull_raw_u16':(mass<<2)&65535,
            'initial_equipment_bits_u32':fuel['starter_profiles'][key]['initial_equipment_bits_u32'],
            'original_starter':bool(old['original_starter']),
            'scope':'Source hull specification and explicit existing starter adapter, not a reconstructed full original inventory or shared world object bank'}
    return {'schema':1,'profile':'dos-firstenc-atmosphere-damage-anchors-v1',
        'source_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'source_data_sha256':DATA_SHA,'source_commit':COMMIT,
        'immutable_resources':{'ffe_hyperdrive_sha256':HYPER_SHA,'ffe_fuel_sha256':FUEL_SHA},
        'procedures':procedures,'ship_profiles':profiles,
        'equipment':{'atmospheric_shielding':fuel['equipment']['atmospheric_shielding'],
                     'shield_generator':fuel['equipment']['shield_generator']},
        'field_layout':{
            'object':{'model_index_u32':0x82,'object_index_u8':0x86,'kind_u8':0x87,'volume_s8':0x88,
                'velocity_s32_xyz':[0x8c,0x90,0x94],'equipment_u32':0xc8,'shielding_byte':0xcb,
                'shield_current_u16':0xe0,'shield_maximum_u16':0xe2,'hull_u16':0xe4,
                'player_selector_u8':0x118,'damage_timer_u8':0x14e,'damage_flags_u8':0x151},
            'game':{'wind_flags_u8':0x74,'speed_s32':0xd8,'altitude_s32':0xdc,'gear_flags_u8':0xe9,
                'heat_s32':0x1ec,'wind_enabled_u8':0x3f62,'wind_armed_u8':0x3f5c}},
        'constants':{'altitude_limit_raw_s32':20000000,'minimum_drag_speed_raw_s32':3000,
            'drag_max_master_ticks_u32':0xfffff,'drag_shift':11,'shielded_heat_shift':11,'unshielded_heat_shift':5,
            'gear_up_shift_reduction':1,'gear_down_game_e9_mask_u8':2,'shielding_object_cb_mask_u8':0x40,
            'shielding_equipment_mask_u32':0x40000000,'fatal_heat_signed_limit':65535,
            'incremental_damage_shift':8,'hull_raw_per_mass_tonne':4,'damage_flash_timer_raw_u8':10,
            'shield_hit_flag_mask_u8':1,'damage_register':12,'object_register':13,'attacker_register':14,
            'wind_parent_shield_threshold_s16':0x116,'wind_flag_mask_u8':0x40,
            'rng_xor_u32':0x1234567f,'rng_first_rotate_left':25,'rng_second_rotate_left':13,'rng_output_mask_u32':65535},
        'canonical_contracts':{
            'heat':'F1014 increments existing game+1EC once per invocation; no step multiplication and no second temperature state',
            'fatal_heat':'Signed32 wrapped candidate>65535 calls F953(-1,0) without storing candidate; other invocation effects continue',
            'incremental_damage':'Stored nonfatal heat increment SAR8>0 calls F953(amount,0)',
            'drag':'Unsigned min(master_ticks,0xFFFFF)<<11; velocity -= F1521(velocity,factor), preserving32-bit wrap',
            'altitude':'F1033 HUD-normalized game+DC; unknown raw-1 is converted to0x7FFFFFFF before F1014',
            'near_surface':'Complete F1016 only conditionally calls F1017; complete DOS F1017 has no gameplay state effect',
            'damage':'F953 consumes shield word then hull word; F952 equipment damage and F942 destruction remain distinct callbacks',
            'rng':'F1530 pure transition of two caller-supplied u32 seeds; source shared global sequence is not inferred'},
        'caller_policies':{
            'canonical_original_player_call_rate_inferred':False,
            'phone_invocation_rate_hz':60,'phone_rate_is_original':False,
            'phone_rate_scope':'Explicit fixed-step reconstruction adapter; not proof that original DOS runs F1014 at60Hz',
            'existing_heat_state':'fuel_system.heat_s32 corresponds to game+0x1EC; preserve it across mode/restore transitions',
            'thermal_rng_scope':'Caller-owned local deterministic thermal stream; not original AI/event shared RNG',
            'event_filter_scope':'Default identity treatment of F34/F35 damage registers does not implement the full source event/module dispatcher',
            'HP_scope':'Raw F953 shield/hull words and explicit Flight percentage bridge; no invented original HP rate'},
        'source_variants':{
            'F1014_DOS':{'heat_per_invocation':True,'heat_shifts':[5,11],'uses_gear_adjustment':True,
                'incremental_F953_damage':True,'drag_cap_u32':0xfffff,'heat_step_multiplication':False},
            'F1014_pinned_JJFFE':{'heat_per_invocation':False,'heat_shifts':[19,22],'uses_gear_adjustment':False,
                'heat_step_multiplication':True,'heat_increment_cap':4096,'incremental_F953_damage':False,
                'heat_bit8000_notification':True,'drag_cap_signed_s32':65535},
            'unchanged_helpers':'F34/F35/F953/F1016/F1017/F1521/F1530 independently match uploaded DOS instructions after branch-target normalization only'},
        'scope':'Source bytes/provenance and explicit caller policies only. Extraction executes no original instructions, proves no complete F569/collision/atmosphere/event/RNG integration, and does not modify previous resources.'}


def main()->None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe'))
    parser.add_argument('--hyperdrive',type=Path,default=PROJECT/'data/ffe_hyperdrive.json')
    parser.add_argument('--fuel',type=Path,default=PROJECT/'data/ffe_fuel.json')
    parser.add_argument('--output',type=Path,default=PROJECT/'data/ffe_atmosphere.json')
    args=parser.parse_args();result=extract(args.exe.read_bytes(),(args.source/'ffe.asm').read_bytes(),
        (args.source/'ffedat.asm').read_bytes(),args.hyperdrive.read_bytes(),args.fuel.read_bytes())
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'path':str(args.output),'sha256':sha(args.output.read_bytes()),'procedures':len(result['procedures'])}))


if __name__=='__main__':main()
