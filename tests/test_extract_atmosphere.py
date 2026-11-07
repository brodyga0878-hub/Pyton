"""Exact DOS thermal byte provenance; not a native arithmetic or phone test."""
import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest

PROJECT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(PROJECT/'tools'))
import extract_atmosphere as extractor
EXE=Path('/workspace/ffe-original/FIRSTENC.EXE')
SOURCE=Path('/workspace/ffe-upstream/jjffe')


class AtmosphereExtraction(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.data=json.loads((PROJECT/'data/ffe_atmosphere.json').read_text())

    def test_source_and_previous_resource_provenance_are_exact(self):
        self.assertEqual(self.data['schema'],1)
        self.assertEqual(self.data['source_sha256'],extractor.EXE_SHA)
        self.assertEqual(self.data['source_assembly_sha256'],extractor.ASM_SHA)
        self.assertEqual(self.data['source_data_sha256'],extractor.DATA_SHA)
        for name,expected in [('ffe_hyperdrive',extractor.HYPER_SHA),('ffe_fuel',extractor.FUEL_SHA)]:
            self.assertEqual(hashlib.sha256((PROJECT/'data'/f'{name}.json').read_bytes()).hexdigest(),expected)
            self.assertEqual(self.data['immutable_resources'][name+'_sha256'],expected)

    def test_eight_original_procedure_bounds_and_digests(self):
        self.assertEqual(set(self.data['procedures']),set(map(str,extractor.PROCEDURES)))
        for number,(at,count,digest,instructions) in extractor.PROCEDURES.items():
            row=self.data['procedures'][str(number)];raw=bytes.fromhex(row['hex'])
            self.assertEqual((row['dos_file_offset'],len(raw),row['sha256'],row['independently_normalized_instruction_count']),
                             (at,count,digest,instructions))
            self.assertEqual(hashlib.sha256(raw).hexdigest(),digest)
            self.assertEqual(raw[-1],0xc3)
        f=self.data['procedures']['1014']
        self.assertEqual((f['dos_file_offset'],f['byte_count']),(0x31890,321))
        self.assertFalse(f['pinned_jjffe_instructions_match_dos'])
        self.assertTrue(all(v['pinned_jjffe_instructions_match_dos']for k,v in self.data['procedures'].items()if k!='1014'))

    def test_dos_heat_gear_damage_and_drag_do_not_silently_use_jjffe_fixes(self):
        dos=self.data['source_variants']['F1014_DOS'];jjffe=self.data['source_variants']['F1014_pinned_JJFFE']
        self.assertEqual(dos['heat_shifts'],[5,11]);self.assertEqual(jjffe['heat_shifts'],[19,22])
        self.assertTrue(dos['uses_gear_adjustment']);self.assertFalse(jjffe['uses_gear_adjustment'])
        self.assertTrue(dos['incremental_F953_damage']);self.assertFalse(jjffe['incremental_F953_damage'])
        self.assertFalse(dos['heat_step_multiplication']);self.assertTrue(jjffe['heat_step_multiplication'])
        self.assertEqual((dos['drag_cap_u32'],jjffe['drag_cap_signed_s32']),(0xfffff,0xffff))
        raw=bytes.fromhex(self.data['procedures']['1014']['hex'])
        self.assertIn(bytes.fromhex('f686e9000000020f94c283e2012bc2'),raw)
        self.assertIn(bytes.fromhex('8bd0c1fa0885d27e0c'),raw)
        self.assertIn(bytes.fromhex('813d0c2c6500ffff0f00'),raw)

    def test_single_existing_heat_state_and_explicit_non_original_phone_rate(self):
        self.assertEqual(self.data['field_layout']['game']['heat_s32'],0x1ec)
        policy=self.data['caller_policies']
        self.assertFalse(policy['canonical_original_player_call_rate_inferred'])
        self.assertFalse(policy['phone_rate_is_original'])
        self.assertEqual(policy['phone_invocation_rate_hz'],60)
        self.assertIn('fuel_system.heat_s32',policy['existing_heat_state'])
        self.assertIn('not original',policy['thermal_rng_scope'])
        self.assertIn('does not implement',policy['event_filter_scope'])

    def test_hull_profiles_keep_raw_specs_and_shielding_baseline(self):
        expected={'cobra':(38,100,400,0x40000),'eagle':(24,28,112,0x40240000),'shuttle':(15,8,32,0)}
        for key,values in expected.items():
            row=self.data['ship_profiles'][key];raw=bytes.fromhex(row['spec_hex'])
            self.assertEqual(tuple(row[k]for k in ['source_model_index','hull_mass_tonnes_s16','maximum_hull_raw_u16','initial_equipment_bits_u32']),values)
            self.assertEqual(struct.unpack_from('<h',raw,6)[0],values[1])
            self.assertEqual(hashlib.sha256(raw).hexdigest(),row['spec_sha256'])
        self.assertEqual(self.data['equipment']['atmospheric_shielding']['mass_tonnes_u32'],1)
        self.assertEqual(self.data['equipment']['atmospheric_shielding']['equipment_mask_u32'],0x40000000)

    def test_damage_and_rng_metadata_keep_original_field_units(self):
        fields=self.data['field_layout']['object'];constants=self.data['constants']
        self.assertEqual((fields['shield_current_u16'],fields['hull_u16'],fields['damage_timer_u8'],fields['damage_flags_u8']),
                         (0xe0,0xe4,0x14e,0x151))
        self.assertEqual(constants['damage_flash_timer_raw_u8'],10)
        self.assertEqual(constants['rng_xor_u32'],0x1234567f)
        self.assertEqual((constants['rng_first_rotate_left'],constants['rng_second_rotate_left']),(25,13))
        self.assertIn('no gameplay state effect',self.data['canonical_contracts']['near_surface'])

    @unittest.skipUnless(EXE.is_file(),'Uploaded original DOS executable not present')
    def test_every_published_instruction_byte_is_at_the_real_dos_offset(self):
        exe=EXE.read_bytes();self.assertEqual(hashlib.sha256(exe).hexdigest(),extractor.EXE_SHA)
        for row in self.data['procedures'].values():
            at=row['dos_file_offset'];count=row['byte_count']
            self.assertEqual(exe[at:at+count].hex(),row['hex'])
            self.assertEqual(row['dos_virtual_address'],at+0x40f200)

    @unittest.skipUnless(EXE.is_file() and (SOURCE/'ffe.asm').is_file(),'Pinned original sources unavailable')
    def test_reextraction_is_reproducible_and_old_resource_changes_reject(self):
        args=[EXE.read_bytes(),(SOURCE/'ffe.asm').read_bytes(),(SOURCE/'ffedat.asm').read_bytes(),
              (PROJECT/'data/ffe_hyperdrive.json').read_bytes(),(PROJECT/'data/ffe_fuel.json').read_bytes()]
        self.assertEqual(extractor.extract(*args),self.data)
        with self.assertRaisesRegex(ValueError,'Immutable previous'):
            extractor.extract(*args[:4],args[4]+b' ')


if __name__=='__main__':unittest.main()
