#!/usr/bin/env python3
"""Extract verified DOS landing-gear instruction anchors and caller policies.

F1008 is a complete procedure; F1056 coverage is only JUMP_004410 through the
terminal JUMP_004431 exit. The wider keyboard/autopilot/collision engines are
not reconstructed here. Previous JSON resources remain byte-for-byte frozen.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re

from extract_system_information import ASM_SHA, COMMIT, DATA_SHA, EXE_SHA, sha
from rebuild_ground_surface_native import block

PROJECT=Path(__file__).resolve().parents[1]
IMMUTABLE_RESOURCES={
    'ffe_hyperdrive':'17fe376bf480aa34fe8278193c558a8a30d198fa06354caf3c9692de34b1cf47',
    'ffe_fuel':'4d35dfd7047e7c3878ab92e25dcd9fde67697d7a93d46e53e57d0e1c7b71f14f',
    'ffe_atmosphere':'b65e25e187ac4abe7e24325a78de3fe70c140395711127ee0076f9905222bcce',
}
PROCEDURES={
    '1008':(0x31590,305,'6d0a8a82a36809b64f58568ad7ef7c29e2b767f8091e06d47536e04adab41e97',72),
    '1056_4410':(0x3409a,116,'4262147506224b00e3d94d2febdfed3f690773655f90439d724e8f393ba61107',32),
}
SUPPORTING_SLICES={
    '1009_call_order':(0x3171c,26,'e8595087e9d8024083bd4a947051337dcedbb9bf0fbf0548c6015f4560713f9b',8),
    '575_landing_predicate':(0x186d1,27,'99d87ce24619fcba14d99c78cd37b0a24a41fc2b334d591f0e7bc53383d08c7b',6),
}


def gear_toggle_fragment(source:str)->str:
    start=re.search(r'^[ \t]*JUMP_004410:',source,re.M)
    if not start:raise ValueError('Missing original F1056 gear branch')
    end=re.search(r'^[ \t]*JUMP_004414:',source[start.end():],re.M)
    if not end:raise ValueError('Missing original F1056 gear branch')
    return source[start.start():start.end()+end.start()]


def _anchor(executable:bytes,at:int,count:int,expected:str,instructions:int)->dict:
    raw=executable[at:at+count]
    if len(raw)!=count or sha(raw)!=expected:raise ValueError('DOS landing-gear instruction anchor differs at'+hex(at))
    if executable.find(raw)!=at or executable.find(raw,at+1)>=0:raise ValueError('Nonunique DOS landing-gear anchor')
    return {'dos_file_offset':at,'dos_virtual_address':at+0x40f200,'byte_count':count,
        'hex':raw.hex(),'sha256':sha(raw),'independently_normalized_instruction_count':instructions}


def extract(executable:bytes,asm_bytes:bytes,data_bytes:bytes,previous_resources:dict[str,bytes])->dict:
    if (sha(executable),sha(asm_bytes),sha(data_bytes))!=(EXE_SHA,ASM_SHA,DATA_SHA):
        raise ValueError('Pinned DOS/JJFFE source SHA256 mismatch')
    if set(previous_resources)!=set(IMMUTABLE_RESOURCES) or any(sha(previous_resources[key])!=expected for key,expected in IMMUTABLE_RESOURCES.items()):
        raise ValueError('Immutable previous resource differs')
    source=asm_bytes.decode().replace('\r\n','\n')
    fragments={'1008':block(source,1008),'1056_4410':gear_toggle_fragment(source)}
    procedures={}
    for key,args in PROCEDURES.items():
        row=_anchor(executable,*args);fragment=fragments[key]
        row.update(source_label='FUNC_001008' if key=='1008' else 'FUNC_001056/JUMP_004410..JUMP_004413',
            source_line=source.count('\n',0,source.index(fragment))+1,
            pinned_jjffe_fragment_sha256=sha(fragment.encode()),
            pinned_jjffe_instructions_match_dos=True,
            coverage='complete procedure' if key=='1008' else 'gear toggle branch including its terminal jump to the F1056 epilogue; not the full input dispatcher',
            instruction_proof_policy='Instruction/operand comparison normalizes branch destination addresses only; external calls remain identified by DOS address')
        if key=='1008' and bytes.fromhex(row['hex'])[-1]!=0xc3:raise ValueError('Incomplete original F1008')
        procedures[key]=row
    supporting={key:_anchor(executable,*args)for key,args in SUPPORTING_SLICES.items()}
    supporting['1009_call_order'].update(source_label='FUNC_001009',source_line=source.count('\n',0,source.index(block(source,1009)))+1,
        scope='Only PUSH/call F1008/POP then indirect active-state dispatch. Does not prove the whole F1009/frame scheduler.')
    supporting['575_landing_predicate'].update(source_label='FUNC_000575/JUMP_002412',source_line=source.count('\n',0,source.index('cmp dword [ebp-0x10],0x258'))+1,
        scope='Only six predicate instructions: aggregate speed<=0x258, gear word==0xFFFF, orientation dot>=0x78000000; not full collision response or manual docking.')
    return {'schema':1,'profile':'dos-firstenc-f1008-f1056-landing-gear-anchors-v1',
        'source_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'source_data_sha256':DATA_SHA,'source_commit':COMMIT,
        'immutable_resources':{name+'_sha256':expected for name,expected in IMMUTABLE_RESOURCES.items()},
        'source_newlines_normalized_for_fragment_hashes':True,'procedures':procedures,'supporting_slices':supporting,
        'field_layout':{'object':{'gear_position_u16':0x9e,'unrelated_timer_u16':0xe8,'autopilot_phase_u8':0xff},
            'game':{'warning_flags_u16':0xc6,'player_object_pointer_u32':0xc8,'speed_s32':0xd8,'flight_state_u8':0xe8,'control_flags_u8':0xe9},
            'globals':{'DATA_008804_game_virtual_address':0x64213c,'DATA_009155_master_ticks_u32_virtual_address':0x652c0c}},
        'constants':{'request_retract_game_e9_mask_u8':2,'warning_game_c6_mask_u16':2,'position_fully_retracted_u16':0,
            'position_fully_deployed_u16':65535,'motion_ticks_shift_right':1,'automatic_flight_state_u8':2,
            'auto_retract_phase_maximum_u8':0x1e,'toggle_blocked_autopilot_phase_u8':0x24,
            'deployment_warning_speed_raw_s32':100000,'deployment_warning_message_u16':0x98ce,'warning_selector_s32':-1,
            'console_button_indices_u8':[0x38,0x46],'console_retracted_request_image_u8':0,'console_deployed_request_image_u8':1,
            'toggle_success_sound_u8':0x0c,'toggle_final_sound_u8':0x14,
            'supporting_landing_maximum_speed_aggregate_s32':0x258,'supporting_landing_minimum_orientation_dot_s32':0x78000000},
        'callbacks':{'FUNC_001116':{'dos_virtual_address':0x445aac,'scope':'Observed control/console refresh request, not the entire original UI engine'},
            'FUNC_001097':{'dos_virtual_address':0x444518,'arguments':['message_u16','selector_s32'],'scope':'Observed warning presentation request'},
            'FUNC_000262':{'dos_virtual_address':0x41d308,'arguments':['console_button_index','image_index'],'scope':'Observed original console icon update request'},
            'FUNC_001906':{'dos_virtual_address':0x46fe7a,'arguments':['sound_sample_index'],'scope':'Observed sound callback, not original audio execution'}},
        'canonical_contracts':{
            'request_polarity':'game+E9 bit2 SET requests retraction to object+9E=0; CLEAR requests deployment to0xFFFF. A request is distinct from actual word position.',
            'motion':'F1008 uses unsigned master_ticks>>1, saturating at the requested endpoint. Tick0/1 can leave position unchanged while other source effects still occur.',
            'object_timer':'First independently decrement object+E8 u16 by supplied master ticks, saturating at0; ticks>65535 clear it. This is not the game+E8 flight state.',
            'automatic_phase':'For game+E8==2, clear warning bit; object+FF<=0x1E sets retract and refreshes on every invocation; phase>0x1E clears retract and refreshes only if previously set.',
            'speed_warning':'Deploy request outside automatic flight state warns once at signed raw speed>=100000 and latches warning bit2. It does not block gear motion.',
            'manual_toggle':'Only object+FF==0x24 blocks this branch. Otherwise XOR request bit2, clear warning latch, set both console icons, refresh, play0x0C; every path plays0x14.',
            'landing_position':'Original six-instruction F575 predicate requires exact gear position0xFFFF as one condition; a request alone is insufficient and this is not full collision parity.',
            'source_order':'Verified F1009 slice calls F1008 before indirect active-state dispatch; the modern caller rate is a separate policy.',
            'thermal_polarity':'Existing source_atmospheric_dynamics.gear_down bool represents raw game+E9 bit2 despite its historical name: pass retract_request_bit, not physical deployment. No previous JSON is rewritten.'},
        'caller_policies':{'canonical_original_player_call_rate_inferred':False,'phone_invocation_rate_hz':60,'phone_rate_is_original':False,
            'phone_rate_scope':'Explicit named fixed60 phone adapter with persisted phase/rational master ticks; not proof of original DOS60Hz.',
            'initialization_scope':'Explicit context-derived phone snapshot adapter; no complete F998 starter gear state inferred.',
            'automatic_phase_scope':'Phone landing/docking phase mapping must be named as an adapter; the original entire autopilot/state machine is not implied.',
            'persistence_scope':'A separate versioned landing-gear sibling owns request bit, position, warning/timer and scheduling state; previous thermal/fuel/hyperdrive resources stay immutable.',
            'callback_scope':'Icon/warning/refresh/sound callbacks are observed requests; full original GUI/audio/event dispatcher is outside extraction.'},
        'source_variants':{'covered_DOS_and_pinned_JJFFE_instructions_equal':True,
            'covered_scope':['complete F1008','F1056 JUMP_004410..JUMP_004413 including exit jump'],
            'whole_F1056_DOS_equivalence_proved':False,'whole_F1056_scope':'Pinned JJFFE changes other keyboard input paths; no whole-dispatcher equivalence is asserted.',
            'legacy_thermal_boolean_polarity_correction':'New metadata explicitly documents retract-bit polarity; old atmosphere JSON and old API spelling are immutable.'},
        'scope':'Read-only byte/source provenance and caller policies. No original instructions executed by extractor, no new raw gear tables, no complete player scheduler/autopilot/F575/GUI/audio integration proof.'}


def main()->None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe'))
    parser.add_argument('--resources',type=Path,default=PROJECT/'data')
    parser.add_argument('--output',type=Path,default=PROJECT/'data/ffe_landing_gear.json')
    args=parser.parse_args();result=extract(args.exe.read_bytes(),(args.source/'ffe.asm').read_bytes(),
        (args.source/'ffedat.asm').read_bytes(),{name:(args.resources/f'{name}.json').read_bytes()for name in IMMUTABLE_RESOURCES})
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'path':str(args.output),'sha256':sha(args.output.read_bytes()),'procedures':len(result['procedures'])}))


if __name__=='__main__':main()
