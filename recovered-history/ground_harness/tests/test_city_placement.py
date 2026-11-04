"""Original two-pass placement, resource provenance and native reproduction."""
import hashlib
import json
import platform
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).parents[1]
EXE = Path('/workspace/scratch/ffe-analysis/files/FIRSTENC/FIRSTENC.EXE')
SOURCE = Path('/workspace/ffe-upstream/jjffe/ffe.asm')
NATIVE = (EXE.exists() and SOURCE.exists() and SOURCE.with_name('ffedat.asm').exists()
          and sys.platform == 'linux' and platform.machine() == 'x86_64'
          and all(shutil.which(tool) for tool in ['as', 'ld', 'nm']))


class OriginalCityPlacementTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = json.loads((ROOT/'tests/fixtures/city_placement_reference.json').read_text())

    def test_real_constructor_pairs_and_full_original_query_chain(self):
        fixture = self.fixture
        self.assertEqual(fixture['case_count'], 373)
        self.assertEqual(fixture['variant_count'], 2)
        self.assertEqual({row['parent_model_index'] for row in fixture['cases']}, set(range(118, 134)))
        self.assertEqual({row['city_model_index'] for row in fixture['cases']}, set(range(81, 91)) | {96})
        records = json.loads((ROOT/'data/ffe_handcrafted_records.json').read_text())['records']
        actual = [row for row in fixture['cases'] if row['origin'] == 'original_handcrafted_city']
        self.assertEqual(len(actual), 21)
        for row in actual:
            self.assertEqual(records[str(row['city_record_slot'])]['record_hex'], row['city_record_hex'])
            self.assertEqual(records[str(row['parent_record_slot'])]['record_hex'], row['parent_record_hex'])
            raw = bytes.fromhex(row['parent_record_hex'])
            self.assertEqual(struct.unpack_from('<H', raw, 12)[0], row['parent_model_index'])
            self.assertEqual(struct.unpack_from('<I', raw, 4)[0], row['parent_uid_u32'])
        for variant in fixture['variants'].values():
            self.assertTrue({'574', '575', '576', '579', '581', '582', '879', '1495', '1532', '1533', '1538', '1674', '1876'}
                            <= variant['source_procedure_hashes'].keys())
            self.assertTrue({'FUNC_000953', 'FUNC_000578'} <= set(variant['host_adapter']['unreached_function_traps']))
            self.assertFalse({'FUNC_000574', 'FUNC_000581', 'FUNC_001876'} & set(variant['host_adapter']['unreached_function_traps']))

    def test_both_passes_finish_with_positive_written_altitude_without_physics(self):
        self.assertTrue(self.fixture['fresh_process_reproduction_verified'])
        self.assertTrue(self.fixture['same_process_reverse_reproduction_verified'])
        for variant in self.fixture['variants'].values():
            self.assertEqual(len(variant['results']), 373)
            for result in variant['results']:
                self.assertEqual(result['clearance_calls'], 2)
                self.assertEqual(result['terrain_query_calls'], 2)
                self.assertEqual(result['matrix_repair_calls'], 0)
                for index, pass_ in enumerate(result['passes']):
                    self.assertEqual(pass_['query_calls_before'], index)
                    self.assertEqual(pass_['query_calls_after'], index + 1)
                    self.assertGreater(pass_['clearance_i32'], 0)
                    self.assertEqual(pass_['clearance_i32'], pass_['altitude_raw_i64'])
                    self.assertEqual(pass_['pending_query_flag'], 0)
                    self.assertEqual(pass_['collision_mode_raw'], 255)
                    self.assertGreater(pass_['intersection_raw'], 0)
                    self.assertLess(pass_['intersection_raw'], pass_['query_limit_raw'])
                    self.assertEqual(pass_['matrix_before_q31'], result['matrix_q31'])
                    self.assertEqual(pass_['matrix_after_q31'], result['matrix_q31'])
        a = self.fixture['variants']['jjffe_sar3']['results']
        b = self.fixture['variants']['archive_local_sar4']['results']
        for first, second in zip(a, b):
            self.assertEqual(first['passes'][0], second['passes'][0])
        self.assertTrue(any(first['position_vec64_raw'] != second['position_vec64_raw'] for first, second in zip(a, b)))

    @unittest.skipUnless(EXE.exists(), 'Uploaded FIRSTENC.EXE required')
    def test_original_descriptor_collision_and_variant_instruction_bytes(self):
        executable = EXE.read_bytes()
        self.assertEqual(hashlib.sha256(executable).hexdigest(), self.fixture['source_sha256'])
        at = int(self.fixture['archive_local_sar4_verified_exe_offset'], 16)
        self.assertEqual(executable[at:at + 3], bytes.fromhex('c1f804'))
        for model in self.fixture['variants']['jjffe_sar3']['resources']['models'].values():
            descriptor = bytes.fromhex(model['descriptor_hex'])
            start = int(model['descriptor_offset'], 16)
            self.assertEqual(executable[start:start + 68], descriptor)
            self.assertEqual(hashlib.sha256(descriptor).hexdigest(), model['descriptor_sha256'])
            stream = bytes.fromhex(model['collision_prefix_and_stream_hex'])
            start = int(model['collision_stream_offset'], 16) - 2
            self.assertEqual(executable[start:start + len(stream)], stream)

    @unittest.skipUnless(NATIVE, 'Original source/EXE and native x86_64 tools required')
    def test_full_native_placement_reproduction(self):
        with tempfile.TemporaryDirectory(prefix='test-city-placement-') as directory:
            output = Path(directory)
            subprocess.run([sys.executable, str(ROOT/'tools/build_city_placement_reference.py'), str(SOURCE), str(EXE),
                            '--project', str(output)], check=True, capture_output=True, timeout=45)
            self.assertEqual(json.loads((output/'tests/fixtures/city_placement_reference.json').read_text()), self.fixture)


if __name__ == '__main__':
    unittest.main()
