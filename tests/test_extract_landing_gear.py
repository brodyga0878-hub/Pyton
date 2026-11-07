"""Exact gear/source provenance tests; no native arithmetic or APK execution."""
import hashlib
import json
from pathlib import Path
import sys
import unittest

PROJECT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(PROJECT/'tools'))
import extract_landing_gear as extractor
EXE=Path('/workspace/ffe-original/FIRSTENC.EXE')
SOURCE=Path('/workspace/ffe-upstream/jjffe')


class LandingGearExtraction(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.data=json.loads((PROJECT/'data/ffe_landing_gear.json').read_text())

    def test_pinned_original_sources_and_three_immutable_resources(self):
        self.assertEqual(self.data['schema'],1)
        self.assertEqual(self.data['profile'],'dos-firstenc-f1008-f1056-landing-gear-anchors-v1')
        self.assertEqual((self.data['source_sha256'],self.data['source_assembly_sha256'],self.data['source_data_sha256'],self.data['source_commit']),
                         (extractor.EXE_SHA,extractor.ASM_SHA,extractor.DATA_SHA,extractor.COMMIT))
        for name,digest in extractor.IMMUTABLE_RESOURCES.items():
            self.assertEqual(self.data['immutable_resources'][name+'_sha256'],digest)
            self.assertEqual(hashlib.sha256((PROJECT/'data'/f'{name}.json').read_bytes()).hexdigest(),digest)

    def test_two_primary_anchors_keep_exact_bounds_bytes_and_scope(self):
        self.assertEqual(set(self.data['procedures']),{'1008','1056_4410'})
        total=0
        for key,(at,count,digest,instructions) in extractor.PROCEDURES.items():
            row=self.data['procedures'][key];raw=bytes.fromhex(row['hex'])
            self.assertEqual((row['dos_file_offset'],len(raw),row['sha256'],row['independently_normalized_instruction_count']),
                             (at,count,digest,instructions))
            self.assertEqual(hashlib.sha256(raw).hexdigest(),digest);total+=count
            self.assertTrue(row['pinned_jjffe_instructions_match_dos'])
        self.assertEqual(total,421)
        self.assertEqual(bytes.fromhex(self.data['procedures']['1008']['hex'])[-1],0xc3)
        self.assertIn('not the full input dispatcher',self.data['procedures']['1056_4410']['coverage'])
        variants=self.data['source_variants']
        self.assertTrue(variants['covered_DOS_and_pinned_JJFFE_instructions_equal'])
        self.assertFalse(variants['whole_F1056_DOS_equivalence_proved'])

    def test_same_offset_e8_does_not_conflate_object_timer_and_flight_state(self):
        fields=self.data['field_layout'];self.assertEqual(fields['object']['gear_position_u16'],0x9e)
        self.assertEqual(fields['object']['unrelated_timer_u16'],0xe8)
        self.assertEqual(fields['game']['flight_state_u8'],0xe8)
        self.assertEqual((fields['game']['warning_flags_u16'],fields['game']['control_flags_u8'],fields['game']['speed_s32']),
                         (0xc6,0xe9,0xd8))
        self.assertIn('not the game+E8',self.data['canonical_contracts']['object_timer'])

    def test_request_bit_and_position_polarity_are_explicit(self):
        constants=self.data['constants'];contracts=self.data['canonical_contracts']
        self.assertEqual((constants['request_retract_game_e9_mask_u8'],constants['position_fully_retracted_u16'],constants['position_fully_deployed_u16']),
                         (2,0,65535))
        self.assertEqual(constants['motion_ticks_shift_right'],1)
        self.assertIn('SET requests retraction',contracts['request_polarity'])
        self.assertIn('CLEAR requests deployment',contracts['request_polarity'])
        self.assertIn('request is distinct',contracts['request_polarity'])
        self.assertIn('raw game+E9 bit2',contracts['thermal_polarity'])
        self.assertIn('not physical deployment',contracts['thermal_polarity'])
        raw=bytes.fromhex(self.data['procedures']['1008']['hex'])
        self.assertIn(bytes.fromhex('f686e90000000274260fb7939e000000'),raw)

    def test_automatic_phase_boundary_and_manual_block_are_not_interchanged(self):
        constants=self.data['constants'];contracts=self.data['canonical_contracts']
        self.assertEqual((constants['automatic_flight_state_u8'],constants['auto_retract_phase_maximum_u8'],constants['toggle_blocked_autopilot_phase_u8']),
                         (2,0x1e,0x24))
        self.assertIn('refreshes on every invocation',contracts['automatic_phase'])
        self.assertIn('only if previously set',contracts['automatic_phase'])
        self.assertIn('Only object+FF==0x24 blocks',contracts['manual_toggle'])
        self.assertIn(bytes.fromhex('80b8ff000000247458'),bytes.fromhex(self.data['procedures']['1056_4410']['hex']))

    def test_high_speed_emits_one_warning_without_blocking_motion(self):
        constants=self.data['constants'];contract=self.data['canonical_contracts']['speed_warning']
        self.assertEqual((constants['deployment_warning_speed_raw_s32'],constants['deployment_warning_message_u16'],constants['warning_selector_s32']),
                         (100000,0x98ce,-1))
        self.assertEqual(constants['warning_game_c6_mask_u16'],2)
        self.assertIn('signed raw speed>=100000',contract)
        self.assertIn('does not block',contract)
        self.assertIn(bytes.fromhex('81bed8000000a08601007c20'),bytes.fromhex(self.data['procedures']['1008']['hex']))

    def test_console_and_sound_callbacks_do_not_claim_full_ui_execution(self):
        constants=self.data['constants'];callbacks=self.data['callbacks']
        self.assertEqual(constants['console_button_indices_u8'],[0x38,0x46])
        self.assertEqual((constants['console_retracted_request_image_u8'],constants['console_deployed_request_image_u8']),(0,1))
        self.assertEqual((constants['toggle_success_sound_u8'],constants['toggle_final_sound_u8']),(0x0c,0x14))
        self.assertEqual({key:value['dos_virtual_address']for key,value in callbacks.items()},
                         {'FUNC_001116':0x445aac,'FUNC_001097':0x444518,'FUNC_000262':0x41d308,'FUNC_001906':0x46fe7a})
        self.assertIn('every path plays0x14',self.data['canonical_contracts']['manual_toggle'])
        self.assertIn('Observed',callbacks['FUNC_000262']['scope'])

    def test_supporting_caller_and_landing_predicates_are_bounded_slices(self):
        slices=self.data['supporting_slices'];self.assertEqual(set(slices),set(extractor.SUPPORTING_SLICES))
        for key,(at,count,digest,instructions) in extractor.SUPPORTING_SLICES.items():
            row=slices[key];raw=bytes.fromhex(row['hex'])
            self.assertEqual((row['dos_file_offset'],len(raw),row['sha256'],row['independently_normalized_instruction_count']),
                             (at,count,digest,instructions))
            self.assertEqual(hashlib.sha256(raw).hexdigest(),digest)
        self.assertIn('not full collision',slices['575_landing_predicate']['scope'])
        self.assertIn('not prove the whole F1009',slices['1009_call_order']['scope'])
        self.assertIn(bytes.fromhex('6681bb9e000000ffff'),bytes.fromhex(slices['575_landing_predicate']['hex']))

    def test_fixed_sixty_host_rate_is_adapter_not_source_scheduler(self):
        policy=self.data['caller_policies'];self.assertEqual(policy['phone_invocation_rate_hz'],60)
        self.assertFalse(policy['phone_rate_is_original']);self.assertFalse(policy['canonical_original_player_call_rate_inferred'])
        self.assertIn('persisted phase/rational master ticks',policy['phone_rate_scope'])
        self.assertIn('no complete F998',policy['initialization_scope'])
        self.assertIn('must be named as an adapter',policy['automatic_phase_scope'])
        self.assertIn('separate versioned landing-gear sibling',policy['persistence_scope'])

    @unittest.skipUnless(EXE.is_file() and (SOURCE/'ffe.asm').is_file(),'Pinned DOS and source files unavailable')
    def test_actual_dos_offsets_and_reextraction_are_exact(self):
        args=[EXE.read_bytes(),(SOURCE/'ffe.asm').read_bytes(),(SOURCE/'ffedat.asm').read_bytes(),
              {name:(PROJECT/'data'/f'{name}.json').read_bytes()for name in extractor.IMMUTABLE_RESOURCES}]
        self.assertEqual(hashlib.sha256(args[0]).hexdigest(),extractor.EXE_SHA)
        for row in [*self.data['procedures'].values(),*self.data['supporting_slices'].values()]:
            at=row['dos_file_offset'];self.assertEqual(args[0][at:at+row['byte_count']].hex(),row['hex'])
            self.assertEqual(row['dos_virtual_address'],at+0x40f200)
        self.assertEqual(extractor.extract(*args),self.data)
        for name in extractor.IMMUTABLE_RESOURCES:
            changed=args[3].copy();changed[name]+=b' '
            with self.assertRaisesRegex(ValueError,'Immutable previous'):
                extractor.extract(*args[:3],changed)


if __name__=='__main__':unittest.main()
