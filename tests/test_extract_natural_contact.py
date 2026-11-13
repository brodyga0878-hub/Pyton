"""Original player shapes/natural program provenance and malformed-stream controls."""
import copy
import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
import extract_natural_contact as extractor
from rebuild_ground_surface_native import Image

EXE = Path('/workspace/ffe-original/FIRSTENC.EXE')
SOURCE = Path('/workspace/ffe-upstream/jjffe')
BASELINE_SHA = 'f9511cf774d7a54826a77a71d0ac5a88ae68369e0ed63d6eb8f2717b9a66a60d'


class NaturalContactExtraction(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads((PROJECT / 'data/ffe_natural_contact.json').read_text())

    def inputs(self):
        return [EXE.read_bytes(), (SOURCE / 'ffe.asm').read_bytes(),
                (SOURCE / 'ffedat.asm').read_bytes(),
                {name: (PROJECT / 'data' / (name + '.json')).read_bytes()
                 for name in extractor.IMMUTABLE_RESOURCES}]

    def test_four_previous_resources_remain_byte_exact(self):
        self.assertEqual(self.data['schema'], 1)
        self.assertEqual(self.data['profile'], 'dos-firstenc-natural-contact-v1')
        self.assertEqual((self.data['source_sha256'], self.data['source_assembly_sha256'],
                          self.data['source_data_sha256'], self.data['source_commit']),
                         (extractor.EXE_SHA, extractor.ASM_SHA, extractor.DATA_SHA, extractor.COMMIT))
        for name, digest in extractor.IMMUTABLE_RESOURCES.items():
            self.assertEqual(self.data['immutable_resources'][name + '_sha256'], digest)
            self.assertEqual(hashlib.sha256((PROJECT / 'data' / (name + '.json')).read_bytes()).hexdigest(), digest)

    def test_code45_portable_baseline_contains_all26_exact_audited_sources(self):
        path = PROJECT / 'tests/fixtures/natural_v45_sources.json'
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), BASELINE_SHA)
        baseline = json.loads(path.read_text())
        self.assertEqual(baseline['source_commit'], 'e3b9369230085ef7c15ab974d8e8de84eda1a991')
        self.assertEqual(len(baseline['files']), 26)
        # The legacy gate owns these code45 pins; the fixture remains portable
        # even after runtime consumers change for a newer version.
        import verify_rebuilt_android as gate
        self.assertEqual(set(baseline['files']), set(gate.SPHERICAL_CONTACT_AUDITED_SOURCE_SHA256))
        for name, digest in gate.SPHERICAL_CONTACT_AUDITED_SOURCE_SHA256.items():
            self.assertEqual(hashlib.sha256(baseline['files'][name].encode()).hexdigest(), digest, name)

    def test_three_ship_descriptors_and_specs_match_existing_149model_and_hyperdrive_tables(self):
        descriptors = json.loads((PROJECT / 'data/ffe_runtime_model_descriptors.json').read_text())['models']
        specs = json.loads((PROJECT / 'data/ffe_hyperdrive.json').read_text())['ship_specs']
        self.assertEqual(set(self.data['ship_models']), {'24', '38', '15'})
        for key, row in self.data['ship_models'].items():
            descriptor = bytes.fromhex(row['descriptor_hex'])
            spec = bytes.fromhex(row['physical_spec_hex'])
            self.assertEqual(len(descriptor), 68)
            self.assertEqual(len(spec), 24)
            self.assertEqual(row['descriptor_hex'], descriptors[key]['descriptor_hex'])
            self.assertEqual(row['descriptor_sha256'], descriptors[key]['descriptor_sha256'])
            self.assertEqual(row['physical_spec_hex'], specs[key]['spec_hex'])
            self.assertEqual(row['physical_spec_sha256'], specs[key]['spec_sha256'])
            self.assertEqual(row['physical_spec_pointer_u32'], struct.unpack_from('<I', descriptor, 0x38)[0])
            self.assertEqual(row['physical_spec_file_offset'], specs[key]['spec_file_offset'])

    def test_actual_positive_ship_radii_use_signed_descriptor_bounds_and_f1495_scale(self):
        expected = {'24': (0, 10400, 5200), '38': (1, 36000, 9600), '15': (-2, 4800, 1920)}
        for key, values in expected.items():
            row = self.data['ship_models'][key]
            radii = row['f1533_radii']
            self.assertEqual((radii['exponent_s32'], radii['outer_s64'], radii['inner_s64']), values)
            descriptor = bytes.fromhex(row['descriptor_hex'])
            self.assertEqual(radii['exponent_s32'], struct.unpack_from('<I', descriptor, 0x14)[0] + struct.unpack_from('<I', descriptor, 0x18)[0] - 8)

    def test_preceding_child_bytes_include_real_terminator_and_traversal_order(self):
        cases = {'24': ('0000', []),
                 '38': ('00007805903379059033', [(13200, 1401), (13200, 1400)]),
                 '15': ('0000840c803e', [(16000, 3204)])}
        for key, (hex_bytes, pairs) in cases.items():
            child = self.data['ship_models'][key]['preceding_children']
            raw = bytes.fromhex(child['hex'])
            self.assertEqual(raw.hex(), hex_bytes)
            self.assertEqual(child['sha256'], hashlib.sha256(raw).hexdigest())
            self.assertEqual(child['byte_length'], 2 + 4 * len(pairs))
            self.assertEqual(child['terminator_file_offset'], child['file_offset'])
            self.assertEqual([(r['radius_s16'], r['axis_radius_encoded_s16']) for r in child['records']], pairs)
            decoded = extractor.decode_children(raw, len(raw))
            self.assertEqual([(r['radius_s16'], r['axis_radius_encoded_s16']) for r in decoded['records']], pairs)

    def test_child_axes_signs_and_displacements_are_separate_from_child_radius(self):
        cobra = self.data['ship_models']['38']['preceding_children']['records']
        shuttle = self.data['ship_models']['15']['preceding_children']['records']
        self.assertEqual([(r['displacement_s16'], r['axis_index'], r['axis_negative'], r['radius_word_u16']) for r in cobra],
                         [(13200, 0, True, 1400), (13200, 0, False, 1400)])
        self.assertEqual([(r['displacement_s16'], r['axis_index'], r['axis_negative'], r['radius_word_u16']) for r in shuttle],
                         [(16000, 2, False, 3200)])
        self.assertEqual(self.data['ship_models']['24']['preceding_children']['records'], [])

    def test_decoder_rejects_truncated_missing_terminator_and_oversized_child_lists(self):
        for raw, pointer in [(b'', 0), (b'\x01', 1), (b'\x78\x05\x90\x33', 4)]:
            with self.assertRaisesRegex(ValueError, 'Truncated'):
                extractor.decode_children(raw, pointer)
        with self.assertRaisesRegex(ValueError, 'oversized'):
            extractor.decode_children(bytes.fromhex('00007805903379059033'), 10, max_records=1)

    def test_decoder_preserves_negative_signed_displacement_and_encoded_word(self):
        raw = struct.pack('<Hhh', 0, -8, -123)
        row = extractor.decode_children(raw, len(raw))['records'][0]
        self.assertEqual(row['radius_s16'], -123)
        self.assertEqual(row['axis_radius_encoded_s16'], -8)
        self.assertEqual((row['axis_index'], row['radius_word_u16']), (0, 65528))

    def test_axis6_is_explicitly_unsupported_instead_of_inventing_a_matrix_row(self):
        with self.assertRaisesRegex(ValueError, 'axis6'):
            extractor.decode_children(struct.pack('<Hhh', 0, 6, 1), 6)

    def test_all32_natural_programs_reference_immutable_complete_source_bytes(self):
        self.assertEqual(set(self.data['natural_parent_programs']), {str(n) for n in range(117, 149)})
        ground = json.loads((PROJECT / 'data/ffe_ground_collision.json').read_text())['models']
        fuel = json.loads((PROJECT / 'data/ffe_fuel.json').read_text())['models']
        for key, row in self.data['natural_parent_programs'].items():
            is_ground = int(key) <= 133
            source = (ground if is_ground else fuel)[key]
            raw = bytes.fromhex(source['collision_bytes_hex' if is_ground else 'collision_stream_hex'])
            program = row['program']
            self.assertEqual(row['resource'], 'ffe_ground_collision' if is_ground else 'ffe_fuel')
            self.assertEqual(row['model_path'], 'models.' + key)
            self.assertEqual(row['descriptor_sha256'], source['descriptor_sha256'])
            self.assertEqual(row['vertices_sha256'], source['vertices_sha256'])
            self.assertEqual(program['byte_length'], len(raw))
            self.assertEqual(program['sha256'], hashlib.sha256(raw).hexdigest())
            self.assertNotIn('descriptor_hex', row)
            self.assertNotIn('vertices_hex', row)
            self.assertNotIn('collision_stream_hex', row)

    def test_natural_program_decoder_retains_feature_records_and_actual_return_tail(self):
        ground = json.loads((PROJECT / 'data/ffe_ground_collision.json').read_text())['models']
        seen_features = False
        for model in range(117, 134):
            raw = bytes.fromhex(ground[str(model)]['collision_bytes_hex'])
            row = extractor.decode_natural_program(raw, 0)
            self.assertEqual(raw[:3], bytes([row['opcode_u8'], row['primitive_flags_u8'], row['primitive_selector_u8']]))
            self.assertEqual(row['opcode_u8'], 0x10)
            self.assertEqual(row['primitive_selector_u8'], 255)
            self.assertEqual(row['terrain_payload_byte_length'], 8 + 16 * row['feature_count'])
            self.assertEqual(raw[row['feature_terminator_file_offset']:row['tail_file_offset']], b'\0\0')
            self.assertEqual(raw[row['tail_file_offset']:].hex(), '5080000000')
            seen_features |= row['feature_count'] > 0
        self.assertTrue(seen_features)

    def test_natural_decoder_rejects_opcode_tail_and_feature_truncation(self):
        raw = bytes.fromhex('1082ff06020400020000005080000000')
        for offset, value in [(0, 0x11), (1, 0x80), (2, 0xfe), (len(raw) - 1, 1)]:
            changed = bytearray(raw)
            changed[offset] = value
            with self.assertRaises(ValueError):
                extractor.decode_natural_program(bytes(changed), 0)
        for length in [2, 8, 10, len(raw) - 1]:
            with self.assertRaises(ValueError):
                extractor.decode_natural_program(raw[:length], 0)
        changed = bytearray(raw)
        changed[9] = 1
        with self.assertRaisesRegex(ValueError, 'Truncated'):
            extractor.decode_natural_program(bytes(changed), 0)

    def test_model117_retains_nonspherical_provenance_without_a_generic_caller_claim(self):
        rows = self.data['natural_parent_programs']
        self.assertEqual([int(k) for k, r in rows.items() if r['non_spherical_source_model']], [117])
        self.assertIn('nonspherical', self.data['child_stream_contract']['model117'])
        self.assertIn('separate evidence', self.data['child_stream_contract']['model117'])
        self.assertIn('no full F576..F583/DOS-JJFFE equivalence', self.data['proof_scope'])

    @unittest.skipUnless(EXE.is_file(), 'Uploaded DOS image unavailable')
    def test_every_new_ship_byte_and_parent_index_matches_actual_mapped_dos_pointer(self):
        exe = EXE.read_bytes()
        image = Image(exe)
        self.assertEqual(hashlib.sha256(exe).hexdigest(), extractor.EXE_SHA)
        for row in self.data['ship_models'].values():
            at = row['descriptor_file_offset']
            self.assertEqual(exe[at:at + 68].hex(), row['descriptor_hex'])
            self.assertEqual(image.offset(row['collision_pointer_u32'], 8), row['collision_file_offset'])
            self.assertEqual(row['collision_pointer_u32'] - 0x416400, row['collision_file_offset'])
            child = row['preceding_children']
            self.assertEqual(child['file_offset'] + child['byte_length'], row['collision_file_offset'])
            self.assertEqual(exe[child['file_offset']:row['collision_file_offset']].hex(), child['hex'])
            at = image.offset(row['physical_spec_pointer_u32'], 24)
            self.assertEqual(exe[at:at + 24].hex(), row['physical_spec_hex'])
        for row in self.data['natural_parent_programs'].values():
            p = row['program']
            at = p['collision_file_offset']
            self.assertEqual(hashlib.sha256(exe[at:at + p['byte_length']]).hexdigest(), p['sha256'])

    @unittest.skipUnless(EXE.is_file() and (SOURCE / 'ffe.asm').is_file(), 'Pinned DOS and source unavailable')
    def test_reextraction_is_byte_exact_and_any_changed_previous_resource_rejects(self):
        args = self.inputs()
        self.assertEqual(extractor.extract(*args), self.data)
        for name in extractor.IMMUTABLE_RESOURCES:
            changed = args[3].copy()
            changed[name] += b' '
            with self.assertRaisesRegex(ValueError, 'Immutable previous'):
                extractor.extract(*args[:3], changed)

    @unittest.skipUnless(EXE.is_file() and (SOURCE / 'ffe.asm').is_file(), 'Pinned DOS and source unavailable')
    def test_changed_executable_assembly_or_data_cannot_enter_resource(self):
        args = self.inputs()
        for index in range(3):
            changed = list(args)
            changed[index] += b' '
            with self.assertRaisesRegex(ValueError, 'Pinned DOS/JJFFE'):
                extractor.extract(*changed)

    @unittest.skipUnless(EXE.is_file(), 'Uploaded DOS image unavailable')
    def test_mutated_descriptor_spec_and_unreviewed_child_bytes_reject(self):
        exe = EXE.read_bytes()
        desc = json.loads((PROJECT / 'data/ffe_runtime_model_descriptors.json').read_text())
        hyper = json.loads((PROJECT / 'data/ffe_hyperdrive.json').read_text())
        changed = copy.deepcopy(desc)
        changed['models']['24']['descriptor_hex'] = '00' * 68
        with self.assertRaisesRegex(ValueError, 'descriptor differs'):
            extractor.ship_rows(exe, changed, hyper)
        changed = copy.deepcopy(hyper)
        changed['ship_specs']['24']['spec_hex'] = '00' * 24
        with self.assertRaisesRegex(ValueError, 'physical specification differs'):
            extractor.ship_rows(exe, desc, changed)
        changed_exe = bytearray(exe)
        changed_exe[0x8d89c] += 1
        with self.assertRaisesRegex(ValueError, 'child list'):
            extractor.ship_rows(bytes(changed_exe), desc, hyper)


if __name__ == '__main__':
    unittest.main()
