import hashlib
import json
import platform
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).parents[1]
EXE = Path('/workspace/scratch/ffe-analysis/files/FIRSTENC/FIRSTENC.EXE')
SOURCE = Path('/workspace/ffe-upstream/jjffe/ffe.asm')
NATIVE = (EXE.exists() and SOURCE.exists() and SOURCE.with_name('ffedat.asm').exists() and
          sys.platform == 'linux' and platform.machine() == 'x86_64' and
          all(shutil.which(command) for command in ['as', 'ld', 'nm']))


class AdditionalTerrainQueryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = json.loads((ROOT/'tests/fixtures/terrain_additional_query_reference.json').read_text())
        cls.resources = json.loads((ROOT/'data/ffe_terrain_query.json').read_text())

    def test_source_models_and_actual_caller_queries_cover_remaining_catalogue(self):
        fixture = self.fixture
        expected = set(range(117, 134))-{119, 125, 129, 133}
        self.assertEqual({int(number) for number in fixture['models']}, expected)
        self.assertEqual(len(fixture['cases']), 390)
        self.assertEqual(fixture['same_process_interleaved_repeat_checks'], 390)
        self.assertEqual({case['model_index'] for case in fixture['cases']}, expected)
        for number, model in fixture['models'].items():
            source = self.resources['models'][number]
            self.assertEqual(model['vertices_hex'], source['vertices_hex'])
            self.assertEqual(model['collision_payload_hex'], source['collision_payload_hex'])
            self.assertEqual(model['collision_stream_prefix_hex'], source['collision_stream_prefix_hex'])
            self.assertEqual(model['static_axis_vertices_raw'], source['axis_vertices_raw'])
            for key in ['descriptor_sha256', 'vertices_sha256', 'collision_payload_sha256', 'mesh_zoom', 'terrain_style_raw']:
                self.assertEqual(model[key], source[key])
        # The unequal source axes are retained as raw controls, not admitted to
        # the spherical provider by borrowing one component as a universal radius.
        self.assertFalse(self.resources['models']['117']['spherical_provider_eligible'])
        self.assertEqual(fixture['models']['117']['static_axis_vertices_raw'], [14, 23, 71])
        for case in fixture['cases']:
            result = case['result']
            self.assertEqual(result['terrain_query_calls'], 1)
            self.assertEqual(result['pending_query_flag'], 0)
            self.assertEqual(result['query_style_raw'], fixture['models'][str(case['model_index'])]['terrain_style_raw'])
            self.assertEqual(len(result['query_matrix_raw']), 9)
            self.assertEqual(len(result['query_center_raw']), 3)
        if EXE.exists():
            executable = EXE.read_bytes()
            self.assertEqual(hashlib.sha256(executable).hexdigest(), fixture['source_sha256'])
            for model in fixture['models'].values():
                for field, offset_field in [('vertices_hex', 'vertices_offset'), ('collision_payload_hex', 'collision_payload_offset')]:
                    raw = bytes.fromhex(model[field])
                    offset = int(model[offset_field], 16)
                    self.assertEqual(executable[offset:offset+len(raw)], raw)

    @unittest.skipUnless(NATIVE, 'Original source/EXE and native x86_64 tools required')
    def test_native_additional_reference_reproduction(self):
        with tempfile.TemporaryDirectory(prefix='test-terrain-additional-') as directory:
            output = Path(directory)
            subprocess.run([sys.executable, str(ROOT/'tools/build_terrain_additional_query_reference.py'),
                            str(SOURCE), str(EXE), '--project', str(output)],
                           check=True, capture_output=True, timeout=45)
            generated = json.loads((output/'tests/fixtures/terrain_additional_query_reference.json').read_text())
            self.assertEqual(generated, self.fixture)


if __name__ == '__main__':
    unittest.main()
