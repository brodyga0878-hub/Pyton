#!/usr/bin/env python3
"""Extract uploaded DOS F577 and descriptor-derived initial collision routing.

F577 is a bounded integer helper, not the F575 dispatcher. Its nonzero return
means outside/equality of the tested envelope; source flags2 is not a hit
verdict. The new routing map records the original F1533 initialization policy
without changing the immutable149-descriptor resource or claiming a live bank.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import struct

from extract_system_information import ASM_SHA, COMMIT, DATA_SHA, EXE_SHA, sha
from rebuild_ground_surface_native import Image, block

PROJECT=Path(__file__).resolve().parents[1]
IMMUTABLE_RESOURCES={
    'ffe_hyperdrive':'17fe376bf480aa34fe8278193c558a8a30d198fa06354caf3c9692de34b1cf47',
    'ffe_fuel':'4d35dfd7047e7c3878ab92e25dcd9fde67697d7a93d46e53e57d0e1c7b71f14f',
    'ffe_atmosphere':'b65e25e187ac4abe7e24325a78de3fe70c140395711127ee0076f9905222bcce',
    'ffe_landing_gear':'f06d7184046407dea3ee45fb3c6dedeb6bfaf21fe1a6136a388a87fa97ed1f00',
    'ffe_surface_contact':'960931e58ac1fe73428956b87f8567e29ea554c84793e33e1e86852f060050e6',
    'ffe_runtime_model_descriptors':'cf9c673c2bba22f0c865e77e3a7ceed5497053cdb444b80f31d7439176446818',
}
PRIMARY=(0x18e4c,363,'f2bb5974c51d801bf5c219f697cf16716250a296f744e54fed61a6c26131e790',128)
HELPERS=[1333,1341,1502,1522,1656,1660]
ZERO_STREAM_MODELS=[*range(14),101,102,104,105,109]
ELIGIBLE_MODELS=[*range(1,14),101,102,104,105,109]


def _proof_records(executable:bytes,proofs:dict)->dict:
    if set(proofs)!={*map(str,HELPERS),'577'}:raise ValueError('Incomplete F577 instruction proof domain')
    result={}
    for label,row in proofs.items():
        at=row['executable_offset'];count=row['byte_length'];raw=executable[at:at+count]
        if len(raw)!=count or sha(raw)!=row['sha256'] or row['virtual_address']!=at+0x40f200 or row.get('all_instructions_equal_after_branch_destination_normalization') is not True:
            raise ValueError('F577 helper proof differs from uploaded DOS '+label)
        result[label]={**row,'hex':raw.hex()}
    primary=result['577']
    if (primary['executable_offset'],primary['byte_length'],primary['sha256'],primary['instruction_count'])!=PRIMARY:
        raise ValueError('Unreviewed F577 procedure boundary')
    return result


def routing(executable:bytes,descriptors:dict)->dict:
    image=Image(executable);result={}
    if descriptors.get('source_sha256')!=EXE_SHA or descriptors.get('model_count')!=149 or set(descriptors.get('models',{}))!={str(n)for n in range(149)}:
        raise ValueError('Incomplete original runtime descriptor table')
    for model in range(149):
        old=descriptors['models'][str(model)];at=old['descriptor_executable_offset'];descriptor=executable[at:at+68]
        if len(descriptor)!=68 or descriptor.hex()!=old['descriptor_hex'] or sha(descriptor)!=old['descriptor_sha256']:
            raise ValueError('Original routing descriptor differs '+str(model))
        pointer=struct.unpack_from('<I',descriptor,0x34)[0]
        offset=image.offset(pointer,8) if pointer else None
        prefix=executable[offset:offset+8] if offset is not None else b''
        first=prefix[0] if prefix else 0
        initial_flags=((struct.unpack_from('<I',descriptor,0x24)[0]>>4)&7)|(0x80 if first else 0)
        result[str(model)]={'model_index':model,'descriptor_file_offset':at,'descriptor_sha256':sha(descriptor),
            'collision_pointer_u32':pointer,'collision_file_offset':offset,'collision_prefix_hex':prefix.hex(),
            'collision_prefix_sha256':sha(prefix),'collision_first_byte_u8':first,
            'model_zero_skips_F1533_descriptor_initialization':model==0,
            'descriptor_derived_object_flags_14c_u8':initial_flags,
            'initial_object_flags_14c_u8':None if model==0 else initial_flags,
            'initial_sphere_path_eligible':None if model==0 else (initial_flags&0x80)==0}
    if [n for n in range(149)if result[str(n)]['collision_first_byte_u8']==0]!=ZERO_STREAM_MODELS:
        raise ValueError('Unreviewed original zero-stream descriptor domain')
    if [n for n in range(149)if result[str(n)]['initial_sphere_path_eligible']]!=ELIGIBLE_MODELS:
        raise ValueError('Unreviewed F1533/F575 initial routing domain')
    return result


def extract(executable:bytes,asm_bytes:bytes,data_bytes:bytes,previous_resources:dict[str,bytes],native:dict)->dict:
    if (sha(executable),sha(asm_bytes),sha(data_bytes))!=(EXE_SHA,ASM_SHA,DATA_SHA):raise ValueError('Pinned DOS/JJFFE source SHA256 mismatch')
    if set(previous_resources)!=set(IMMUTABLE_RESOURCES) or any(sha(previous_resources[key])!=expected for key,expected in IMMUTABLE_RESOURCES.items()):
        raise ValueError('Immutable previous resource differs')
    if native.get('executable_sha256')!=EXE_SHA or native.get('pinned_asm_sha256')!=ASM_SHA or native.get('source_commit')!=COMMIT:
        raise ValueError('Wrong F577 native proof provenance')
    source=asm_bytes.decode().replace('\r\n','\n');proofs=_proof_records(executable,native['byte_instruction_proofs'])
    variant=native.get('known_jjffe_variant',{})
    expected_difference={'instruction':38,'dos':'add eax,dwordptr[esi+0x138]','pinned_jjffe':'add eax,dwordptr[esi+0x140]'}
    if variant.get('difference_count')!=1 or variant.get('differences')!=[expected_difference] or variant.get('all_other_instructions_equal') is not True:
        raise ValueError('Unreviewed F577 DOS/JJFFE source difference')
    rowmap=routing(executable,json.loads(previous_resources['ffe_runtime_model_descriptors']))
    return {'schema':1,'profile':'dos-firstenc-f577-spherical-contact-routing-v1','source_sha256':EXE_SHA,
        'source_assembly_sha256':ASM_SHA,'source_data_sha256':DATA_SHA,'source_commit':COMMIT,
        'immutable_resources':{name+'_sha256':expected for name,expected in IMMUTABLE_RESOURCES.items()},
        'instruction_proofs':proofs,'helper_proof_complete':True,
        'source_newlines_normalized_for_fragment_hashes':True,
        'pinned_source_procedure_sha256':{str(n):sha(block(source,n).encode())for n in [577,*HELPERS]},
        'model_collision_routing':rowmap,'descriptor_stream_zero_models':ZERO_STREAM_MODELS,
        'initial_simple_sphere_models':ELIGIBLE_MODELS,'initialization_skipped_models':[0],
        'initial_hierarchical_models':[n for n in range(1,149)if n not in ELIGIBLE_MODELS],
        'routing_contract':{'source_procedures':['F1533 descriptor initialization','F575 parent+14C branch before F576/F577'],
            'low_flag_formula':'(descriptor+0x24 DWORD >>4)&7',
            'program_flag_formula':'OR0x80 only if descriptor+0x34 pointer is nonzero and its first byte is nonzero',
            'sphere_selector':'For nonzero models,18initialized parent+0x14C masks are nonnegative.19descriptors have zero streams including model0, but F1533 skips descriptor initialization for model0 and its actual flags are unknown. All natural117..148 are hierarchical.',
            'model_zero_policy':'F1533 test model-index; JZ bypasses descriptor initialization at0. Descriptor-derived mask is only provenance, never an initialized model0 object or bank eligibility.',
            'null_pointer_policy':'F1533 skips the first-byte dereference for a null collision pointer; prefix is empty and stored firstbyte0 records that branch.',
            'prefix_scope':'At most8raw source bytes at the original pointer; not a complete collision program or decoded hierarchy.',
            'initialization_only':True,'live_original_object_bank_available':False},
        'field_layout':{'object_bytes':338,'outer_bound_s64':0x138,'outer_high_u32':0x13c,'inner_low_s32':0x140,
            'initial_collision_flags_u8':0x14c,'descriptor_flags_dword':0x24,'descriptor_collision_pointer_u32':0x34,
            'globals_DATA_labels':{'collision_flags_u8':8696,'altitude_low_u32':8703,'altitude_high_s32':8704}},
        'raw_api':{'inputs':['body338readonly','parent338readonly','relative_position_s64:Array3byvalue','absolute_position_s64:Array3readonly','globals.collision_flags_u8','globals.altitude_s64'],
            'outputs':['return_s32','inside_sphere','distance_squared_s32','globals_after','global_writes'],
            'global_writes_only':['collision_flags_u8','altitude_s64'],'does_not_write':['body','parent','caller_relative_vector','caller_absolute_vector','collision_kind','previous_altitude','HP','RNG','clock']},
        'canonical_contracts':{'return':'Return0 means the original unsigned scaled radius²>distance² inside branch; return−1 means outside or equality, not a collision-hit verdict.',
            'comparison':'F1522 signed32 square high words; source modulo32 distance sum; compare radius² and distance² as unsigned DWORDs.',
            'small_coordinates':'For nonpositive shift, source uses body+0x140 low INNER and parent+0x138 low OUTER, then shifts radius and only relative LOW DWORDs with x86 count masking.',
            'large_coordinates':'For positive shift, source F1660 shifts the signed64 relative vector and F1333/F1341 sum/shift the two OUTER64 radii.',
            'outside_effects':'Only the nonzero branch writes flags|2 and unsigned-root-derived altitude; flags|1 compares parent INNER/OUTER low DWORDs only.',
            'inside_effects':'Return0 still writes output distance² but leaves incoming source globals unchanged.',
            'absolute_buffer':'The original caller supplies a separate F1664 absolute buffer; arbitrary operand controls do not prove a geometric hit.',
            'integer_serialization':'Exact little-endian hex carries serialized64-bit machine values; decimal JSON previews must not become lossy float machine inputs.'},
        'source_variants':{'canonical':'Uploaded DOS F577, complete363-byte128-instruction procedure.',
            'known_jjffe_variant':variant,'nonpositive_shift_DOS_parent_radius_offset':0x138,'nonpositive_shift_JJFFE_parent_radius_offset':0x140,
            'other_instructions_equal':True,'canonical_source_patch':'Only restore the documented short-shift ADD parent+0x138 from DOS; retain every other pinned source instruction.'},
        'caller_policies':{'actual_Main_use':'Read-only source descriptor envelope sampling with actual ship radii and routing eligibility; results are diagnostics only.',
            'natural_parent_scope':'Natural117..148 have collision streams and require original F576 dispatch. A standalone F577 envelope query must not replace terrain collision.',
            'routing_scope':'Recorded nonzero-model masks describe F1533 initialization; model0 flags/eligibility are unknown. No full live original object-bank state.',
            'bounded_raw_pipeline_scope':'A separate raw simple-parent F575→F577→prior terminal helper has an independently verified coupled fixture. Its packaging proof stays outside this routing resource and does not imply a live dispatcher or physical Main change.',
            'physical_response_changed_by_probe':False,'source_world_bank_dispatch_integrated':False,'full_F569_F570_F576_F578_pipeline_integrated':False,
            'HP_RNG_clock_mutated_by_probe':False,'full_original_physics':False},
        'scope':'Extractor executes no original instructions. Complete DOS F577 arithmetic and initial descriptor routing are distinct from physical collision dispatch, terrain hierarchy, damage and reference-frame/world-bank integration.'}


def main()->None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe',type=Path,default=Path('/workspace/ffe-original/FIRSTENC.EXE'))
    parser.add_argument('--source',type=Path,default=Path('/workspace/ffe-upstream/jjffe'))
    parser.add_argument('--resources',type=Path,default=PROJECT/'data')
    parser.add_argument('--proof',type=Path,default=PROJECT/'tests/fixtures/source_spherical_contact_native.json')
    parser.add_argument('--output',type=Path,default=PROJECT/'data/ffe_spherical_contact.json')
    args=parser.parse_args();result=extract(args.exe.read_bytes(),(args.source/'ffe.asm').read_bytes(),(args.source/'ffedat.asm').read_bytes(),
        {name:(args.resources/f'{name}.json').read_bytes()for name in IMMUTABLE_RESOURCES},json.loads(args.proof.read_text()))
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'path':str(args.output),'sha256':sha(args.output.read_bytes()),'routing_models':len(result['model_collision_routing']),'instruction_records':len(result['instruction_proofs'])}))


if __name__=='__main__':main()
