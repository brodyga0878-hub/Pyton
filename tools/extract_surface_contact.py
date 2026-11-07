#!/usr/bin/env python3
"""Read-only DOS F575 bounded-contact anchors and exact existing ship records.

This resource is metadata, not the original classifier or a second HP store.
Optional independently generated instruction proofs are incorporated before
release freezing; without them the resource is explicitly a prototype.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import struct

from extract_system_information import ASM_SHA, COMMIT, DATA_SHA, EXE_SHA, sha
from rebuild_ground_surface_native import block

PROJECT=Path(__file__).resolve().parents[1]
IMMUTABLE_RESOURCES={
    'ffe_hyperdrive':'17fe376bf480aa34fe8278193c558a8a30d198fa06354caf3c9692de34b1cf47',
    'ffe_fuel':'4d35dfd7047e7c3878ab92e25dcd9fde67697d7a93d46e53e57d0e1c7b71f14f',
    'ffe_atmosphere':'b65e25e187ac4abe7e24325a78de3fe70c140395711127ee0076f9905222bcce',
    'ffe_landing_gear':'f06d7184046407dea3ee45fb3c6dedeb6bfaf21fe1a6136a388a87fa97ed1f00',
    'ffe_runtime_model_descriptors':'cf9c673c2bba22f0c865e77e3a7ceed5497053cdb444b80f31d7439176446818',
}
ANCHORS={
    '575_postclassification':(0x185f5,1657,'56d9e671bd0b831b6364ab1927351594d33b02967342ce401261388e65807785',518),
    '575_full_static_only':(0x184a0,2005,'33e2895597b23f2e12a3fc6f8c09a08c73042eb26f3529a2b1d911d12b77b015',635),
    '578_excluded_variant':(0x18fb8,416,'c5234844446da9de83bff6aa3ebe81bb64ec510a02d8b4a4b6503461c1c91f83',114),
}
HELPERS=[571,1333,1335,1466,1501,1502,1503,1504,1519,1520,1521,1522,1523,1538,1552,1656,1657,1658,1660]
SHIP_INDICES=[15,24,38]


def anchor(executable:bytes,at:int,count:int,expected:str,instructions:int)->dict:
    raw=executable[at:at+count]
    if len(raw)!=count or sha(raw)!=expected:raise ValueError('DOS contact anchor differs at'+hex(at))
    if executable.find(raw)!=at or executable.find(raw,at+1)>=0:raise ValueError('Nonunique DOS contact anchor')
    return {'dos_file_offset':at,'dos_virtual_address':at+0x40f200,'byte_count':count,
        'hex':raw.hex(),'sha256':sha(raw),'disassembled_instruction_count':instructions}


def extract(executable:bytes,asm_bytes:bytes,data_bytes:bytes,previous_resources:dict[str,bytes],proofs:dict|None=None)->dict:
    if (sha(executable),sha(asm_bytes),sha(data_bytes))!=(EXE_SHA,ASM_SHA,DATA_SHA):
        raise ValueError('Pinned DOS/JJFFE source SHA256 mismatch')
    if set(previous_resources)!=set(IMMUTABLE_RESOURCES) or any(sha(previous_resources[key])!=expected for key,expected in IMMUTABLE_RESOURCES.items()):
        raise ValueError('Immutable previous resource differs')
    source=asm_bytes.decode().replace('\r\n','\n')
    procedures={key:anchor(executable,*args)for key,args in ANCHORS.items()}
    procedures['575_postclassification'].update(source_label='FUNC_000575/JUMP_002410..before JUMP_002432',
        runtime_entry=True,scope='Bounded post-classification continuation only; original epilogue is captured by the host wrapper, original geometry/classifier entry is not executed.')
    procedures['575_full_static_only'].update(source_label='FUNC_000575',runtime_entry=False,
        scope='Whole original DOS byte/disassembly anchor for provenance; not whole-function native execution or gameplay integration.')
    procedures['578_excluded_variant'].update(source_label='FUNC_000578',runtime_entry=False,
        scope='Explicitly excluded pair/solid response; pinned JJFFE rewrites this DOS procedure.')
    hyper=json.loads(previous_resources['ffe_hyperdrive']);descriptors=json.loads(previous_resources['ffe_runtime_model_descriptors'])
    if descriptors.get('source_sha256')!=EXE_SHA or descriptors.get('model_count')!=149:raise ValueError('Wrong original descriptor resource')
    ships={}
    for index in SHIP_INDICES:
        old=hyper['ship_specs'][str(index)];existing=descriptors['models'][str(index)]
        at=int(old['descriptor_file_offset']);raw=executable[at:at+68]
        spec_at=int(old['spec_file_offset']);spec=executable[spec_at:spec_at+24]
        pointer=struct.unpack_from('<I',raw,0x38)[0]
        if len(raw)!=68 or raw.hex()!=existing['descriptor_hex'] or sha(raw)!=existing['descriptor_sha256'] or existing['descriptor_executable_offset']!=at:raise ValueError('Existing ship descriptor differs '+str(index))
        if len(spec)!=24 or spec.hex()!=old['spec_hex'] or sha(spec)!=old['spec_sha256'] or pointer!=old['original_spec_pointer_u32'] or pointer!=spec_at+0x416400:raise ValueError('Existing ship specification differs '+str(index))
        scale=struct.unpack_from('<I',raw,0x14)[0]+struct.unpack_from('<I',raw,0x18)[0]-8
        outer=struct.unpack_from('<h',raw,0x2c)[0];inner=struct.unpack_from('<h',raw,0x30)[0]
        ships[str(index)]={'model_index':index,'descriptor_hex':raw.hex(),'descriptor_file_offset':at,'descriptor_sha256':sha(raw),
            'spec_hex':spec.hex(),'spec_file_offset':spec_at,'spec_sha256':sha(spec),'original_spec_pointer_u32':pointer,
            'model_scale_raw':scale,'outer_radius_s16':outer,'inner_radius_s16':inner,
            'source_refs':'Existing immutable149-descriptor table and57-specification table; these are the3 current adapted ships, not57 playable ships.'}
    instruction_proofs={}
    if proofs is not None:
        expected={*map(str,HELPERS),'575_postclassification','abs'}
        if set(proofs)!=expected:raise ValueError('Incomplete bounded-contact helper proof domain')
        for label,row in proofs.items():
            at=row['executable_offset'];count=row['byte_length'];raw=executable[at:at+count]
            if len(raw)!=count or sha(raw)!=row['sha256'] or row['virtual_address']!=at+0x40f200:raise ValueError('Contact instruction proof differs from DOS '+label)
            if label!='abs' and row.get('all_instructions_equal_after_branch_destination_normalization') is not True:raise ValueError('Unproved source/DOS contact instructions '+label)
            instruction_proofs[label]={**row,'hex':raw.hex()}
        primary=instruction_proofs['575_postclassification'];expected_primary=procedures['575_postclassification']
        if (primary['executable_offset'],primary['byte_length'],primary['sha256'],primary['instruction_count'])!=(expected_primary['dos_file_offset'],expected_primary['byte_count'],expected_primary['sha256'],518):raise ValueError('Contact proof selected a different entry')
    return {'schema':1,'profile':'dos-firstenc-f575-postclassification-anchors-v1',
        'source_sha256':EXE_SHA,'source_assembly_sha256':ASM_SHA,'source_data_sha256':DATA_SHA,'source_commit':COMMIT,
        'immutable_resources':{name+'_sha256':expected for name,expected in IMMUTABLE_RESOURCES.items()},
        'procedures':procedures,'helper_proof_complete':bool(instruction_proofs),'instruction_proofs':instruction_proofs,
        'helper_source_procedure_sha256':{str(n):sha(block(source,n).encode())for n in HELPERS},
        'source_newlines_normalized_for_fragment_hashes':True,'ship_models':ships,
        'global_field_policy':'field_layout.globals values name original DATA label numbers, not object/game byte offsets.',
        'field_layout':{'object':{'orientation_q31_dword_offsets':list(range(0,0x24,4)),'parent_index_u8':0x56,
            'position_s64_xyz':[0x3e,0x46,0x4e],'model_index_u32':0x82,'object_index_u8':0x86,'kind_u8':0x87,
            'velocity_s32_xyz':[0x8c,0x90,0x94],'gear_position_u16':0x9e,'outer_bound_s64':0x138,'inner_bound_s64':0x140},
            'globals':{'collision_flags_u8':8696,'collider_index_u8':8698,'collision_active_u8':8699,'collision_enabled_u8':8700,
                'collider_pointer':8702,'previous_altitude_low_u32':8705,'previous_altitude_high_s32':8706,'collision_kind_u8':8707,'player_index_u32':8857}},
        'constants':{'landing_speed_l1_limit_raw_s32':600,'landing_gear_required_u16':65535,'landing_orientation_dot_minimum_q31_s32':0x78000000,
            'contact_flag_u8':2,'landing_flag_u8':0x40,'unsafe_contact_flag_u8':0x80,'natural_contact_kind_u8':1,
            'source_object_record_bytes':338,'ship_descriptor_bytes':68,'ship_specification_bytes':24,
            'hull_raw_per_mass_tonne':4,'impact_damage_divisor_s32':1800},
        'canonical_contracts':{'classification':'Caller supplies classification/contact globals and valid raw context; runtime entry begins after original F575 classification.',
            'natural_normal':'Kind1 continuation computes the radial source normal from parent-relative raw position; a published triangle gradient is not substituted as original source math.',
            'landing':'Original Q31/L1/fully-deployed-word predicate; physicalgear position is distinct from the request flag.',
            'response':'Exact bounded position/basis/velocity continuation returns F953 amount/attacker requests. Original F953 arithmetic is reused through the existing saved HP/RNG owner.',
            'bounds':'Ship outer/inner bounds derive from original descriptor mantissa and F1533→F1495 exponent: scale14+scale18−8; no visual mesh radius is inferred.',
            'scope':'Post-classification arithmetic is distinct from full F569/F570/F574/F575/F576/F577/F578 and the complete object-bank/frame/event pipelines.'},
        'caller_policies':{'source_classifier_integrated':False,'source_frame_pipeline_integrated':False,
            'published_geometry_scope':'Phone CCD/height provider uses published terrain/city triangles; its event classification is an explicit adapter to the bounded original continuation.',
            'source_frame_scope':'Position, orientation and velocity must enter one consistent source frame; L1 speed is basis-sensitive. No implicit complete F570 frame selection.',
            'response_schedule_scope':'Phone contact event scheduling/repeated-hit suppression is caller policy, not an inferred original timer frequency.',
            'HP_RNG_scope':'Reuse existing persisted F953 raw HP/shield/local RNG owner; no second HP or contact RNG state.',
            'callback_scope':'F953 requests are consumed by existing DOS damage arithmetic; F942 destruction/F952 equipment/full event dispatcher remain explicit external scope.',
            'whole_original_physics':False},
        'source_variants':{'canonical_entry':'Uploaded DOS bounded F575 JUMP_002410 continuation; pinned-source helper equivalence recorded separately when proof_complete.',
            'full_F575_anchor_is_runtime_entry':False,'F577_included_in_runtime':False,'F578_included_in_runtime':False,
            'F577_DOS_other_radius_object_offset':0x138,'F577_pinned_JJFFE_other_radius_object_offset':0x140,
            'F577_scope':'Pinned JJFFE explicitly changes the other-object sphere radius; full original sphere classifier is excluded from this runtime.',
            'F578_DOS':'Pair velocity uses signed wrapped means and original raw hull-word damage order.',
            'F578_pinned_JJFFE':'Explicit Missile retardation rewrite uses descriptor masses, collision direction and a different impulse/damage formula; excluded from this runtime.'},
        'scope':'Read-only metadata/bytes/provenance. Extractor executes no original instructions. Prototype until helper_proof_complete=true; no full classifier/world/frame/collision/destruction/equipment parity claim.'}


def main()->None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe'))
    parser.add_argument('--resources',type=Path,default=PROJECT/'data')
    parser.add_argument('--proof',type=Path)
    parser.add_argument('--output',type=Path,default=PROJECT/'data/ffe_surface_contact.json')
    args=parser.parse_args();proof=None
    if args.proof is not None:proof=json.loads(args.proof.read_text())['byte_instruction_proofs']
    result=extract(args.exe.read_bytes(),(args.source/'ffe.asm').read_bytes(),(args.source/'ffedat.asm').read_bytes(),
        {name:(args.resources/f'{name}.json').read_bytes()for name in IMMUTABLE_RESOURCES},proof)
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'path':str(args.output),'sha256':sha(args.output.read_bytes()),'ship_models':len(result['ship_models']),'helper_proof_complete':result['helper_proof_complete']}))


if __name__=='__main__':main()
