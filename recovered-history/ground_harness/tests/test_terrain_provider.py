"""Original source controls for the fixed-probe, explicitly adapted terrain policy."""
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
          and all(shutil.which(command) for command in ['as', 'ld', 'nm']))


class FixedTerrainProviderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = json.loads((ROOT/'tests/fixtures/terrain_provider_reference.json').read_text())
        cls.resources = json.loads((ROOT/'data/ffe_terrain_query.json').read_text())

    def test_fixed_policy_retains_source_models_and_actual_uid_provenance(self):
        fixture = self.fixture
        self.assertEqual(set(fixture['models']), {str(number) for number in range(118, 134)})
        self.assertEqual(fixture['case_count'], 1040)
        self.assertEqual(fixture['same_process_interleaved_repeat_checks'], 1040)
        self.assertTrue(fixture['fresh_process_reproduction_verified'])
        self.assertEqual(fixture['policy']['graphics_level_raw'], 12)
        actual = []
        for number, row in fixture['uid_representatives'].items():
            model = self.resources['models'][number]
            self.assertTrue(model['axes_uniform'])
            self.assertEqual(model['uniform_base_radius_raw'] << 14,
                             fixture['models'][number]['terrain_radius_parameter_raw'])
            if row['kind'] == 'explicit_synthetic_seed':
                self.assertEqual(number, '118')
                continue
            actual.append(number)
            raw = bytes.fromhex(row['record_hex'])
            self.assertEqual(struct.unpack_from('<H', raw, 12)[0], int(number))
            self.assertEqual(struct.unpack_from('<I', raw, 4)[0], row['seed'])
            source = json.loads((ROOT/row['path']).read_text())
            if row['kind'] == 'original_F875_record':
                self.assertEqual(source['records'][str(row['slot'])]['record_hex'], row['record_hex'])
            else:
                self.assertEqual(source['cases'][row['case_index']]['result']['records'][row['record_index']],
                                 row['record_hex'])
        self.assertEqual(len(actual), 15)
        self.assertFalse(self.resources['models']['117']['spherical_provider_eligible'])

    def test_policy_queries_complete_without_caller_limit_clamping(self):
        policies = [row for row in self.fixture['cases'] if row['control_kind'] == 'fixed_provider_policy']
        self.assertEqual(len(policies), 960)
        for case in policies:
            result = case['result']
            self.assertEqual(case['graphics_level_raw'], 12)
            self.assertEqual(case['observer_radius_multiplier'], 1.25)
            self.assertEqual(result['terrain_query_calls'], 1)
            self.assertEqual(result['pending_query_flag'], 0)
            self.assertEqual(result['last_original_subdivision_level_raw'], 9)
            self.assertTrue(result['altitude_written'])
            self.assertGreater(result['recorded_intersection_raw'], 0)
            self.assertLess(result['recorded_intersection_raw'], result['query_limit_raw'])
            self.assertEqual(result['altitude_raw_i64'],
                             result['recorded_intersection_raw'] << case['vector_scale'])
            self.assertEqual(result['source_surface_radius_raw'],
                             result['query_center_raw'][2]-result['recorded_intersection_raw'])
            self.assertEqual(result['surface_radius_ratio'],
                             result['source_surface_radius_raw']/case['base_radius_raw'])
            self.assertGreater(result['surface_radius_ratio'], 0)
        for interval in self.fixture['sampled_model_ranges'].values():
            self.assertEqual(interval['query_limit_clamp_count'], 0)

    def test_source_distance_and_detail_dependence_remains_explicit(self):
        sensitivities = [row for row in self.fixture['cases']
                         if row['control_kind'] == 'observer_detail_sensitivity']
        self.assertEqual(len(sensitivities), 80)
        pairs = {}
        for row in sensitivities:
            key = row['model_index'], row['direction_probe_index'], row['observer_radius_multiplier']
            pairs.setdefault(key, {})[row['graphics_level_raw']] = row['result']['source_surface_radius_raw']
        self.assertTrue(any(value[1] != value[12] for value in pairs.values()))
        earth = [row for row in sensitivities if row['model_index'] == 129
                 and row['direction_probe_index'] == 26 and row['graphics_level_raw'] == 1]
        self.assertGreater(len({row['result']['source_surface_radius_raw'] for row in earth}), 1)

    @unittest.skipUnless(NATIVE, 'Original source/EXE and native x86_64 tools required')
    def test_native_provider_reference_reproduction(self):
        with tempfile.TemporaryDirectory(prefix='test-terrain-provider-') as directory:
            output = Path(directory)
            subprocess.run([sys.executable, str(ROOT/'tools/build_terrain_provider_reference.py'),
                            str(SOURCE), str(EXE), '--project', str(output)],
                           check=True, capture_output=True, timeout=45)
            generated = json.loads((output/'tests/fixtures/terrain_provider_reference.json').read_text())
            self.assertEqual(generated, self.fixture)


if __name__ == '__main__':
    unittest.main()
