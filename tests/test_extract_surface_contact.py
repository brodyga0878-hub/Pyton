"""Exact bounded-contact byte/provenance controls, not a native or phone run."""
import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest

PROJECT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(PROJECT/'tools'))
import extract_surface_contact as extractor
from rebuild_ground_surface_native import block
EXE=Path('/workspace/ffe-original/FIRSTENC.EXE')
SOURCE=Path('/workspace/ffe-upstream/jjffe')
FIXTURE=PROJECT/'tests/fixtures/source_surface_contact_native.json'


class SurfaceContactExtraction(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data=json.loads((PROJECT/'data/ffe_surface_contact.json').read_text())
        cls.native=json.loads(FIXTURE.read_text())

    def inputs(self):
        return [EXE.read_bytes(),(SOURCE/'ffe.asm').read_bytes(),(SOURCE/'ffedat.asm').read_bytes(),
                {name:(PROJECT/'data'/f'{name}.json').read_bytes()for name in extractor.IMMUTABLE_RESOURCES}]

    def test_pinned_sources_and_five_previous_resources_are_exact(self):
        self.assertEqual(self.data['schema'],1)
        self.assertEqual(self.data['profile'],'dos-firstenc-f575-postclassification-anchors-v1')
        self.assertEqual((self.data['source_sha256'],self.data['source_assembly_sha256'],self.data['source_data_sha256'],self.data['source_commit']),
                         (extractor.EXE_SHA,extractor.ASM_SHA,extractor.DATA_SHA,extractor.COMMIT))
        for name,digest in extractor.IMMUTABLE_RESOURCES.items():
            self.assertEqual(self.data['immutable_resources'][name+'_sha256'],digest)
            self.assertEqual(hashlib.sha256((PROJECT/'data'/f'{name}.json').read_bytes()).hexdigest(),digest)

    def test_bounded_entry_is_separate_from_full_static_function_and_excluded_f578(self):
        self.assertEqual(set(self.data['procedures']),set(extractor.ANCHORS))
        for name,(at,count,digest,instructions) in extractor.ANCHORS.items():
            row=self.data['procedures'][name];raw=bytes.fromhex(row['hex'])
            self.assertEqual((row['dos_file_offset'],len(raw),row['sha256'],row['disassembled_instruction_count']),
                             (at,count,digest,instructions))
            self.assertEqual(hashlib.sha256(raw).hexdigest(),digest)
        self.assertTrue(self.data['procedures']['575_postclassification']['runtime_entry'])
        self.assertFalse(self.data['procedures']['575_full_static_only']['runtime_entry'])
        self.assertFalse(self.data['procedures']['578_excluded_variant']['runtime_entry'])
        primary=self.data['procedures']['575_postclassification']
        self.assertEqual((primary['dos_file_offset'],primary['byte_count'],primary['disassembled_instruction_count']),(0x185f5,1657,518))
        self.assertIn('not executed',primary['scope'])

    def test_all_twenty_one_instruction_records_are_native_proof_bound_and_byte_pinned(self):
        self.assertTrue(self.data['helper_proof_complete'])
        expected={*map(str,extractor.HELPERS),'575_postclassification','abs'}
        self.assertEqual(set(self.data['instruction_proofs']),expected)
        self.assertEqual(set(self.native['byte_instruction_proofs']),expected)
        for name,row in self.data['instruction_proofs'].items():
            native=self.native['byte_instruction_proofs'][name]
            for key,value in native.items():self.assertEqual(row[key],value,(name,key))
            raw=bytes.fromhex(row['hex'])
            self.assertEqual((len(raw),hashlib.sha256(raw).hexdigest()),(row['byte_length'],row['sha256']))
            self.assertEqual(row['virtual_address'],row['executable_offset']+0x40f200)
            if name!='abs':self.assertTrue(row['all_instructions_equal_after_branch_destination_normalization'])
        self.assertEqual(sum(row['byte_length']for row in self.data['instruction_proofs'].values()),3402)
        self.assertEqual(sum(row['instruction_count']for row in self.data['instruction_proofs'].values()),1259)

    def test_three_current_ship_models_match_existing_original_descriptor_and_spec_tables(self):
        descriptors=json.loads((PROJECT/'data/ffe_runtime_model_descriptors.json').read_text())
        hyper=json.loads((PROJECT/'data/ffe_hyperdrive.json').read_text())
        self.assertEqual(set(self.data['ship_models']),{'15','24','38'})
        for key,row in self.data['ship_models'].items():
            old=descriptors['models'][key];spec=hyper['ship_specs'][key]
            descriptor=bytes.fromhex(row['descriptor_hex']);raw_spec=bytes.fromhex(row['spec_hex'])
            self.assertEqual((len(descriptor),len(raw_spec)),(68,24))
            self.assertEqual(row['descriptor_hex'],old['descriptor_hex']);self.assertEqual(row['spec_hex'],spec['spec_hex'])
            self.assertEqual(row['descriptor_sha256'],old['descriptor_sha256']);self.assertEqual(row['spec_sha256'],spec['spec_sha256'])
            self.assertEqual(row['descriptor_file_offset'],old['descriptor_executable_offset'])
            self.assertEqual(struct.unpack_from('<I',descriptor,0x38)[0],row['original_spec_pointer_u32'])
            self.assertEqual(row['original_spec_pointer_u32'],row['spec_file_offset']+0x416400)
            self.assertEqual(struct.unpack_from('<h',raw_spec,6)[0],{'15':8,'24':28,'38':100}[key])

    def test_original_radius_exponent_uses_f1495_bias_not_visual_mesh_dimensions(self):
        expected={'15':(-2,19200,7680),'24':(0,10400,5200),'38':(1,18000,4800)}
        for key,values in expected.items():
            row=self.data['ship_models'][key];raw=bytes.fromhex(row['descriptor_hex'])
            self.assertEqual(tuple(row[k]for k in ['model_scale_raw','outer_radius_s16','inner_radius_s16']),values)
            self.assertEqual(row['model_scale_raw'],struct.unpack_from('<I',raw,0x14)[0]+struct.unpack_from('<I',raw,0x18)[0]-8)
        self.assertIn('no visual mesh radius',self.data['canonical_contracts']['bounds'])

    def test_landing_predicate_retains_l1_q31_and_physical_word(self):
        constants=self.data['constants']
        self.assertEqual((constants['landing_speed_l1_limit_raw_s32'],constants['landing_gear_required_u16'],constants['landing_orientation_dot_minimum_q31_s32']),
                         (600,65535,0x78000000))
        raw=bytes.fromhex(self.data['procedures']['575_postclassification']['hex'])
        self.assertIn(bytes.fromhex('817df0580200007f296681bb9e000000ffff751e3d000000787c17'),raw)
        self.assertIn('distinct from the request flag',self.data['canonical_contracts']['landing'])

    def test_raw_context_fields_do_not_replace_64bit_geometry_with_lossy_float_positions(self):
        fields=self.data['field_layout']['object']
        self.assertEqual(fields['orientation_q31_dword_offsets'],list(range(0,0x24,4)))
        self.assertEqual(fields['position_s64_xyz'],[0x3e,0x46,0x4e])
        self.assertEqual(fields['velocity_s32_xyz'],[0x8c,0x90,0x94])
        self.assertEqual((fields['gear_position_u16'],fields['outer_bound_s64'],fields['inner_bound_s64']),(0x9e,0x138,0x140))
        self.assertIn('DATA label numbers',self.data['global_field_policy'])

    def test_natural_radial_normal_and_phone_triangle_provider_have_distinct_scope(self):
        policy=self.data['caller_policies'];self.assertFalse(policy['source_classifier_integrated']);self.assertFalse(policy['source_frame_pipeline_integrated'])
        self.assertIn('radial source normal',self.data['canonical_contracts']['natural_normal'])
        self.assertIn('not substituted',self.data['canonical_contracts']['natural_normal'])
        self.assertIn('Phone CCD/height provider',policy['published_geometry_scope'])
        self.assertIn('explicit adapter',policy['published_geometry_scope'])
        self.assertIn('L1 speed is basis-sensitive',policy['source_frame_scope'])
        self.assertIn('caller policy',policy['response_schedule_scope'])
        self.assertFalse(policy['whole_original_physics'])

    def test_contact_damage_has_one_existing_hp_rng_owner_and_explicit_callbacks(self):
        self.assertEqual((self.data['constants']['hull_raw_per_mass_tonne'],self.data['constants']['impact_damage_divisor_s32']),(4,1800))
        self.assertIn('existing saved HP/RNG owner',self.data['canonical_contracts']['response'])
        self.assertIn('no second HP or contact RNG state',self.data['caller_policies']['HP_RNG_scope'])
        self.assertIn('F942 destruction/F952 equipment',self.data['caller_policies']['callback_scope'])

    def test_jjffe_pair_response_rewrite_is_not_mislabeled_canonical_dos_runtime(self):
        variants=self.data['source_variants'];self.assertFalse(variants['F578_included_in_runtime']);self.assertFalse(variants['F577_included_in_runtime']);self.assertFalse(variants['full_F575_anchor_is_runtime_entry'])
        self.assertEqual((variants['F577_DOS_other_radius_object_offset'],variants['F577_pinned_JJFFE_other_radius_object_offset']),(0x138,0x140))
        self.assertIn('signed wrapped means',variants['F578_DOS'])
        self.assertIn('Missile retardation rewrite',variants['F578_pinned_JJFFE'])
        self.assertIn('excluded',variants['F578_pinned_JJFFE'])

    @unittest.skipUnless(EXE.is_file() and (SOURCE/'ffe.asm').is_file(),'Pinned DOS/source files unavailable')
    def test_actual_source_bytes_reextraction_and_lf_helper_hashes_are_exact(self):
        args=self.inputs();proof=self.native['byte_instruction_proofs']
        self.assertEqual(extractor.extract(*args,proof),self.data)
        for row in self.data['instruction_proofs'].values():
            at=row['executable_offset'];self.assertEqual(args[0][at:at+row['byte_length']].hex(),row['hex'])
        source=args[1].decode().replace('\r\n','\n')
        for key,digest in self.data['helper_source_procedure_sha256'].items():
            self.assertEqual(hashlib.sha256(block(source,int(key)).encode()).hexdigest(),digest)

    @unittest.skipUnless(EXE.is_file() and (SOURCE/'ffe.asm').is_file(),'Pinned DOS/source files unavailable')
    def test_unproved_or_tampered_inputs_cannot_silently_claim_final_provenance(self):
        args=self.inputs();prototype=extractor.extract(*args)
        self.assertFalse(prototype['helper_proof_complete']);self.assertEqual(prototype['instruction_proofs'],{})
        proof=self.native['byte_instruction_proofs'].copy();proof.pop('1521')
        with self.assertRaisesRegex(ValueError,'helper proof domain'):extractor.extract(*args,proof)
        for name in extractor.IMMUTABLE_RESOURCES:
            changed=args[3].copy();changed[name]+=b' '
            with self.assertRaisesRegex(ValueError,'Immutable previous'):extractor.extract(*args[:3],changed,self.native['byte_instruction_proofs'])


if __name__=='__main__':unittest.main()
