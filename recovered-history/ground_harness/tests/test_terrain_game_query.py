"""Independent original collision-caller matrices and terrain altitudes."""
import json,platform,shutil,subprocess,sys,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).parents[1]
EXE=Path('/workspace/scratch/ffe-analysis/files/FIRSTENC/FIRSTENC.EXE')
SOURCE=Path('/workspace/ffe-upstream/jjffe/ffe.asm')
NATIVE=EXE.exists() and SOURCE.exists() and SOURCE.with_name('ffedat.asm').exists() and sys.platform=='linux' and platform.machine()=='x86_64' and all(shutil.which(tool) for tool in ['as','ld','nm'])
class TerrainGameQueryTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.fixture=json.loads((ROOT/'tests/fixtures/terrain_game_query_reference.json').read_text())
 def test_original_collision_caller_and_model_coverage(self):
  f=self.fixture;self.assertEqual(f['case_count'],120)
  self.assertEqual(set(f['models']),{'119','125','129','133'})
  self.assertEqual({row['seed'] for row in f['cases']},{1,0x12345678,0x0abc1234})
  self.assertEqual({row['direction_probe_index'] for row in f['cases']},set(range(10)))
  self.assertTrue({'581','1341','1466','1502','1523','1669','1876'}<=f['source_procedure_hashes'].keys())
  self.assertTrue(f['real_model_feature_lists'])
  for model in f['models'].values():
   payload=bytes.fromhex(model['collision_payload_hex'])
   self.assertEqual(payload[:4],bytes([6,2,4,0]))
   self.assertEqual(payload[-2:],b'\0\0')
   self.assertEqual(len(bytes.fromhex(model['vertices_hex'])),24)
   self.assertEqual(model['mesh_zoom']-model['vector_scale'],14)
 def test_captured_query_is_complete_and_preserves_original_altitude_scale(self):
  f=self.fixture;self.assertEqual(f['same_process_interleaved_repeat_checks'],120)
  self.assertTrue(f['fresh_process_reproduction_verified'])
  for row in f['cases']:
   result=row['result'];self.assertEqual(result['terrain_query_calls'],1)
   self.assertEqual(result['pending_query_flag'],0)
   self.assertEqual(len(result['query_matrix_raw']),9)
   self.assertEqual(result['query_center_raw'][:2],[0,0])
   self.assertEqual(result['query_style_raw'],f['models'][str(row['model_index'])]['terrain_style_raw'])
   self.assertEqual(result['query_limit_raw'],2000000000>>row['vector_scale'])
   if result['collision_status']==-1:
    self.assertEqual(result['altitude_raw_i64'],result['recorded_intersection_raw']<<row['vector_scale'])
   else:
    self.assertEqual(result['collision_status'],0);self.assertEqual(result['altitude_raw_i64'],0)
  # This value is the source constructor's explicit Earth UID, not the artistic
  # system/body hash used by the current approximate terrain renderer.
  source_records=json.loads((ROOT/'data/ffe_handcrafted_records.json').read_text())['records']
  earth=next(row for row in source_records.values() if row['name_en']=='Earth')
  self.assertEqual(earth['seed_u32'],f['earth_explicit_source_uid_probe'])
 @unittest.skipUnless(NATIVE,'Original source/EXE and native x86_64 tools required')
 def test_native_game_query_reproduction(self):
  with tempfile.TemporaryDirectory() as directory:
   destination=Path(directory)
   subprocess.run([sys.executable,str(ROOT/'tools/build_terrain_game_query_reference.py'),str(SOURCE),str(EXE),'--project',str(destination)],check=True,capture_output=True,timeout=45)
   self.assertEqual(json.loads((destination/'tests/fixtures/terrain_game_query_reference.json').read_text()),self.fixture)
if __name__=='__main__':unittest.main()
