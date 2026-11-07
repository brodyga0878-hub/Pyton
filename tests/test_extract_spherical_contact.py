"""Uploaded-DOS F577/routing provenance controls; no native/APK execution."""
import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest

PROJECT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(PROJECT/'tools'))
import extract_spherical_contact as extractor
from rebuild_ground_surface_native import Image
EXE=Path('/workspace/ffe-original/FIRSTENC.EXE')
SOURCE=Path('/workspace/ffe-upstream/jjffe')
FIXTURE=PROJECT/'tests/fixtures/source_spherical_contact_native.json'


class SphericalContactExtraction(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data=json.loads((PROJECT/'data/ffe_spherical_contact.json').read_text())
        cls.native=json.loads(FIXTURE.read_text())

    def inputs(self):
        return [EXE.read_bytes(),(SOURCE/'ffe.asm').read_bytes(),(SOURCE/'ffedat.asm').read_bytes(),
                {name:(PROJECT/'data'/f'{name}.json').read_bytes()for name in extractor.IMMUTABLE_RESOURCES},self.native]

    def test_original_sources_and_all_six_previous_resources_are_exact(self):
        self.assertEqual(self.data['schema'],1)
        self.assertEqual(self.data['profile'],'dos-firstenc-f577-spherical-contact-routing-v1')
        self.assertEqual((self.data['source_sha256'],self.data['source_assembly_sha256'],self.data['source_data_sha256'],self.data['source_commit']),
                         (extractor.EXE_SHA,extractor.ASM_SHA,extractor.DATA_SHA,extractor.COMMIT))
        for name,digest in extractor.IMMUTABLE_RESOURCES.items():
            self.assertEqual(self.data['immutable_resources'][name+'_sha256'],digest)
            self.assertEqual(hashlib.sha256((PROJECT/'data'/f'{name}.json').read_bytes()).hexdigest(),digest)

    def test_complete_f577_and_six_helpers_keep_exact_original_byte_bounds(self):
        records=self.data['instruction_proofs'];self.assertTrue(self.data['helper_proof_complete'])
        self.assertEqual(set(records),{'577',*map(str,extractor.HELPERS)})
        self.assertEqual((records['577']['executable_offset'],records['577']['byte_length'],records['577']['sha256'],records['577']['instruction_count']),extractor.PRIMARY)
        self.assertEqual(sum(row['byte_length']for row in records.values()),917)
        self.assertEqual(sum(row['instruction_count']for row in records.values()),367)
        for key,row in records.items():
            raw=bytes.fromhex(row['hex']);self.assertEqual((len(raw),hashlib.sha256(raw).hexdigest()),(row['byte_length'],row['sha256']))
            self.assertTrue(row['all_instructions_equal_after_branch_destination_normalization'])
            for field,value in self.native['byte_instruction_proofs'][key].items():self.assertEqual(row[field],value)

    def test_single_jjffe_operand_change_is_not_silently_adopted(self):
        variant=self.data['source_variants'];self.assertTrue(variant['other_instructions_equal'])
        self.assertEqual((variant['nonpositive_shift_DOS_parent_radius_offset'],variant['nonpositive_shift_JJFFE_parent_radius_offset']),(0x138,0x140))
        self.assertEqual(variant['known_jjffe_variant']['difference_count'],1)
        raw=bytes.fromhex(self.data['instruction_proofs']['577']['hex'])
        self.assertEqual(raw[0x18eb2-0x18e4c:0x18eb8-0x18e4c],bytes.fromhex('038638010000'))

    def test_raw_return_and_unsigned_boundary_are_not_a_collision_hit_verdict(self):
        contract=self.data['canonical_contracts'];self.assertIn('Return0',contract['return']);self.assertIn('return−1',contract['return'])
        self.assertIn('outside or equality',contract['return']);self.assertIn('not a collision-hit verdict',contract['return'])
        self.assertIn('unsigned DWORDs',contract['comparison'])
        self.assertIn('leaves incoming source globals unchanged',contract['inside_effects'])
        raw=bytes.fromhex(self.data['instruction_proofs']['577']['hex'])
        self.assertIn(bytes.fromhex('3b07760433c0eb57'),raw)

    def test_small_and_large_coordinate_radius_paths_remain_distinct(self):
        contract=self.data['canonical_contracts']
        self.assertIn('body+0x140 low INNER',contract['small_coordinates'])
        self.assertIn('parent+0x138 low OUTER',contract['small_coordinates'])
        self.assertIn('relative LOW DWORDs',contract['small_coordinates'])
        self.assertIn('two OUTER64 radii',contract['large_coordinates'])
        self.assertIn('low DWORDs only',contract['outside_effects'])

    def test_helper_does_not_claim_kind_previous_hp_rng_or_body_mutation(self):
        api=self.data['raw_api'];self.assertEqual(api['global_writes_only'],['collision_flags_u8','altitude_s64'])
        for key in ['body','parent','caller_relative_vector','caller_absolute_vector','collision_kind','previous_altitude','HP','RNG','clock']:
            self.assertIn(key,api['does_not_write'])
        self.assertEqual(self.data['field_layout']['object_bytes'],338)
        self.assertIn('F1664 absolute buffer',self.data['canonical_contracts']['absolute_buffer'])
        self.assertIn('little-endian hex',self.data['canonical_contracts']['integer_serialization'])

    def test_all149_initial_route_rows_are_bound_to_existing_descriptors(self):
        descriptors=json.loads((PROJECT/'data/ffe_runtime_model_descriptors.json').read_text())['models']
        rows=self.data['model_collision_routing'];self.assertEqual(set(rows),{str(n)for n in range(149)})
        for key,row in rows.items():
            desc=bytes.fromhex(descriptors[key]['descriptor_hex']);pointer=struct.unpack_from('<I',desc,0x34)[0]
            self.assertEqual(row['descriptor_sha256'],descriptors[key]['descriptor_sha256'])
            self.assertEqual(row['descriptor_file_offset'],descriptors[key]['descriptor_executable_offset'])
            self.assertEqual(row['collision_pointer_u32'],pointer)
            prefix=bytes.fromhex(row['collision_prefix_hex']);self.assertEqual(len(prefix),8 if pointer else 0)
            self.assertEqual(row['collision_prefix_sha256'],hashlib.sha256(prefix).hexdigest())
            self.assertEqual(row['collision_first_byte_u8'],prefix[0] if prefix else 0)
            flags=((struct.unpack_from('<I',desc,0x24)[0]>>4)&7)|(0x80 if row['collision_first_byte_u8'] else 0)
            self.assertEqual(row['descriptor_derived_object_flags_14c_u8'],flags)
            if key=='0':
                self.assertTrue(row['model_zero_skips_F1533_descriptor_initialization'])
                self.assertIsNone(row['initial_object_flags_14c_u8']);self.assertIsNone(row['initial_sphere_path_eligible'])
            else:
                self.assertFalse(row['model_zero_skips_F1533_descriptor_initialization'])
                self.assertEqual(row['initial_object_flags_14c_u8'],flags)
                self.assertEqual(row['initial_sphere_path_eligible'],(flags&0x80)==0)

    def test_model_zero_skip_and18_initialized_simple_models_do_not_mislabel_natural_hierarchy(self):
        eligible=[int(key)for key,row in self.data['model_collision_routing'].items()if row['initial_sphere_path_eligible']]
        self.assertEqual(eligible,[*range(1,14),101,102,104,105,109])
        self.assertEqual(self.data['descriptor_stream_zero_models'],[*range(14),101,102,104,105,109])
        self.assertEqual(self.data['initialization_skipped_models'],[0])
        self.assertEqual(eligible,self.data['initial_simple_sphere_models'])
        self.assertEqual(len(self.data['initial_hierarchical_models']),130)
        for model in range(117,149):self.assertFalse(self.data['model_collision_routing'][str(model)]['initial_sphere_path_eligible'])
        self.assertTrue(self.data['routing_contract']['initialization_only']);self.assertFalse(self.data['routing_contract']['live_original_object_bank_available'])

    def test_runtime_probe_is_read_only_and_does_not_replace_terrain_or_damage(self):
        policy=self.data['caller_policies']
        self.assertIn('diagnostics only',policy['actual_Main_use'])
        self.assertIn('must not replace terrain collision',policy['natural_parent_scope'])
        for key in ['physical_response_changed_by_probe','source_world_bank_dispatch_integrated','full_F569_F570_F576_F578_pipeline_integrated','HP_RNG_clock_mutated_by_probe','full_original_physics']:
            self.assertFalse(policy[key],key)

    @unittest.skipUnless(EXE.is_file(),'Uploaded DOS image unavailable')
    def test_every_code_and_routing_prefix_is_at_its_actual_dos_offset(self):
        exe=EXE.read_bytes();self.assertEqual(hashlib.sha256(exe).hexdigest(),extractor.EXE_SHA);image=Image(exe)
        for row in self.data['instruction_proofs'].values():
            at=row['executable_offset'];self.assertEqual(exe[at:at+row['byte_length']].hex(),row['hex'])
        for row in self.data['model_collision_routing'].values():
            if row['collision_pointer_u32']:
                at=image.offset(row['collision_pointer_u32'],8);self.assertEqual(row['collision_file_offset'],at)
                self.assertEqual(exe[at:at+8].hex(),row['collision_prefix_hex'])
            else:self.assertIsNone(row['collision_file_offset'])

    @unittest.skipUnless(EXE.is_file() and (SOURCE/'ffe.asm').is_file(),'Pinned DOS and source unavailable')
    def test_reextraction_is_exact_and_previous_resource_changes_reject(self):
        args=self.inputs();self.assertEqual(extractor.extract(*args),self.data)
        for name in extractor.IMMUTABLE_RESOURCES:
            changed=args[3].copy();changed[name]+=b' '
            with self.assertRaisesRegex(ValueError,'Immutable previous'):extractor.extract(*args[:3],changed,args[4])

    @unittest.skipUnless(EXE.is_file() and (SOURCE/'ffe.asm').is_file(),'Pinned DOS and source unavailable')
    def test_unproved_or_changed_instruction_variants_cannot_enter_resource(self):
        args=self.inputs();changed=json.loads(json.dumps(args[4]));changed['byte_instruction_proofs'].pop('1341')
        with self.assertRaisesRegex(ValueError,'instruction proof domain'):extractor.extract(*args[:4],changed)
        changed=json.loads(json.dumps(args[4]));changed['known_jjffe_variant']['difference_count']=0
        with self.assertRaisesRegex(ValueError,'DOS/JJFFE source difference'):extractor.extract(*args[:4],changed)


if __name__=='__main__':unittest.main()
