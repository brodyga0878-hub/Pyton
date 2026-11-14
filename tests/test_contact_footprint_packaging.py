"""Code48 package rejection controls; explicit mock GDSC is never an APK."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import test_contact_alignment_packaging as retained

verifier=retained.verifier
PROJECT=retained.PROJECT


class MockFootprintArchive(retained.MockAlignmentArchive):
    def __init__(self):
        super().__init__()
        for name in verifier.CONTACT_FOOTPRINT_MODULES:
            self.entries['assets/scripts/'+name+'.gdc']=b'GDSC'+('actual48-unit-mock-'+name).encode()*5


class ContactFootprintPackaging(unittest.TestCase):
    def setUp(self):self.archive=MockFootprintArchive()

    @staticmethod
    def project_files():
        files=retained.ContactAlignmentPackaging.project_files()
        files.update(verifier.CONTACT_FOOTPRINT_AUDITED_SOURCE_SHA256)
        files.update(['tests/fixtures/footprint_v47_sources.json','tests/fixtures/source_footprint_native.json','scripts/build_info.gd','export_presets.cfg'])
        return files

    def project_copy(self,directory):
        project=Path(directory)
        for relative in self.project_files():
            target=project/relative;target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes((PROJECT/relative).read_bytes())
        return project

    def test_actual48_scope_keeps_default_physics_and_all_actual_archive_hashes(self):
        result=verifier.verify_contact_footprint_runtime(self.archive,PROJECT)
        self.assertEqual(result['baseline_source_commit'],'39397785dde976ca46e59e0c3fa240703898057c')
        self.assertEqual((result['compiled_module_count'],result['integration_compiled_module_count']),(2,42))
        self.assertEqual(result['baseline_fixture_source_count'],40)
        self.assertEqual(result['unchanged_code47_runtime_source_count'],39)
        self.assertEqual(result['preserved_Main_function_count'],119)
        self.assertIn('_tick',result['preserved_Main_functions'])
        self.assertIn('_payload',result['preserved_Main_functions'])
        old=result['retained_code47_source_audit']
        self.assertEqual(old['source_override_count'],2)
        self.assertEqual(old['runtime_source_override_count'],1)
        self.assertEqual(old['evidence_helper_source_override_count'],1)
        self.assertEqual(old['source_override_paths'],['scripts/main.gd','tests/test_source_contact_surface_render.gd'])
        self.assertFalse(old['compiled_assets_substituted'])
        self.assertFalse(old['audit_is_actual_unchanged_code47_runtime'])
        self.assertTrue(result['default_physical_terrain_is_v4'])
        self.assertTrue(result['explicit_user_command_only'])
        native=result['native_footprint_reference']
        self.assertEqual((native['case_count'],native['actor_case_count'],native['visible_ground_case_count']),(158,65,93))
        self.assertFalse(native['oracle_executed_by_apk_verifier'])
        self.assertFalse(native['floating_mesh_identity_proved'])
        self.assertEqual(native['fresh_selected_player_volume_pairs'],[[15,0],[15,1],[24,0],[38,0],[38,1],[38,2]])
        for key in ('actual_runtime_is_unchanged_code47','new_runtime_JSON_added',
                    'live_response_enabled','fullmesh_geometry_certified',
                    'complete_original_physics','physical_device_tested',
                    'compiled_source_correspondence_rebuilt_by_verifier'):
            self.assertFalse(result[key],key)

    def test_all42_actual_compiled_sources_required(self):
        for relative in verifier.CONTACT_FOOTPRINT_AUDITED_SOURCE_SHA256:
            with self.subTest(relative=relative):
                archive=MockFootprintArchive();del archive.entries['assets/scripts/'+Path(relative).stem+'.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing contact-footprint integration runtime'):
                    verifier.verify_contact_footprint_runtime(archive,PROJECT)

    def test_new_compiled_headers_and_truncation_reject(self):
        for name in verifier.CONTACT_FOOTPRINT_MODULES:
            for raw in (b'BAD!'+b'x'*100,b'GDSC'+b'x'*60):
                with self.subTest(name=name,size=len(raw)):
                    archive=MockFootprintArchive();archive.entries['assets/scripts/'+name+'.gdc']=raw
                    with self.assertRaisesRegex(AssertionError,'Invalid compiled contact-footprint integration runtime'):
                        verifier.verify_contact_footprint_runtime(archive,PROJECT)

    def test_same_actual_compiled_main_used_by_nested_history_audits(self):
        path='assets/scripts/main.gdc';raw=b'GDSC'+b'only-the-actual48-main-exported'*7
        self.archive.entries[path]=raw
        result=verifier.verify_contact_footprint_runtime(self.archive,PROJECT)
        digest=hashlib.sha256(raw).hexdigest()
        self.assertEqual(result['integration_compiled_modules']['main'],digest)
        old47=result['retained_code47_source_audit']['assets']
        self.assertEqual(old47['integration_compiled_modules']['main'],digest)
        old46=old47['retained_code46_source_audit']['assets']
        self.assertEqual(old46['integration_compiled_modules']['main'],digest)
        self.assertFalse(result['retained_code47_source_audit']['compiled_assets_substituted'])

    def test_old47_public_gate_remains_strict_against_actual48(self):
        with self.assertRaisesRegex(AssertionError,'Contact alignment differs from audited integration source'):
            verifier.verify_contact_alignment_runtime(self.archive,PROJECT)

    def test_baseline_is_exact_portable40source_code47_history(self):
        baseline=verifier._load_contact_footprint_baseline(PROJECT)
        self.assertEqual(baseline['version_code'],47)
        self.assertEqual(baseline['audited_runtime_source_sha256'],verifier.CONTACT_ALIGNMENT_AUDITED_SOURCE_SHA256)
        self.assertEqual(len(baseline['files']),40)
        self.assertNotIn('scripts/source_terrain_query_trace.gd',baseline['files'])

    def test_baseline_cannot_rehash_fabricated_history(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'tests/fixtures/footprint_v47_sources.json'
            data=json.loads(path.read_text());row=data['files']['scripts/main.gd']
            row['source']+='\n# fabricated\n';row['sha256']=hashlib.sha256(row['source'].encode()).hexdigest()
            path.write_text(json.dumps(data,ensure_ascii=False))
            with self.assertRaisesRegex(AssertionError,'Changed portable code47 footprint source baseline'):
                verifier.verify_contact_footprint_runtime(self.archive,project)

    def test_every_actual48_audited_source_is_frozen(self):
        for relative in verifier.CONTACT_FOOTPRINT_AUDITED_SOURCE_SHA256:
            with self.subTest(relative=relative),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/relative
                path.write_bytes(path.read_bytes()+b'\n# unaudited\n')
                with self.assertRaisesRegex(AssertionError,'Contact footprint differs from audited integration source'):
                    verifier.verify_contact_footprint_runtime(self.archive,project)

    def test_actual_physics_and_save_functions_compared_to47_before_source_history_audit(self):
        baseline=verifier._load_contact_footprint_baseline(PROJECT)
        for name in ('_tick','_payload','_decode_state','_source_contact_enabled','_apply_pending_source_contact'):
            with self.subTest(name=name),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/'scripts/main.gd';raw=path.read_text()
                original=verifier.source_function(raw,name)
                path.write_text(raw.replace(original,original.replace('\n','\n\t# changed physical function\n',1),1))
                with self.assertRaisesRegex(AssertionError,'Contact footprint changed protected Main function'):
                    verifier._verify_contact_footprint_preserved_functions(project,baseline)

    def test_new_footprint_does_not_unfreeze_original_terrain_math_or_response(self):
        for relative in ('scripts/source_terrain_query.gd','scripts/source_terrain_point.gd',
                         'scripts/source_terrain_math.gd','scripts/source_units.gd',
                         'scripts/source_natural_contact.gd','scripts/source_natural_contact_pipeline.gd',
                         'scripts/source_surface_contact.gd','scripts/source_surface_contact_bridge.gd'):
            with self.subTest(relative=relative),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/relative
                path.write_bytes(path.read_bytes()+b'\n# altered original\n')
                with self.assertRaises(AssertionError):verifier.verify_contact_footprint_runtime(self.archive,project)

    def test_original_native_proofs_remain_exact(self):
        for name in ('source_natural_contact_native','source_surface_contact_native','source_contact_field_native'):
            with self.subTest(name=name),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/'tests/fixtures'/f'{name}.json'
                path.write_bytes(path.read_bytes()+b' ')
                with self.assertRaises(AssertionError):verifier.verify_contact_footprint_runtime(self.archive,project)

    def test_original_runtime_resources_remain_exported_byteexact(self):
        for name in ('ffe_natural_contact','ffe_spherical_contact','ffe_ground_collision','ffe_surface_contact','ffe_terrain_query'):
            with self.subTest(name=name):
                archive=MockFootprintArchive();path='assets/data/'+name+'.json'
                archive.entries[path]=(PROJECT/'data'/f'{name}.json').read_bytes()+b' '
                with self.assertRaises(AssertionError):verifier.verify_contact_footprint_runtime(archive,PROJECT)

    def test_new_native_footprint_reference_cannot_change(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'tests/fixtures/source_footprint_native.json'
            path.write_bytes(path.read_bytes()+b' ')
            with self.assertRaisesRegex(AssertionError,'Changed independent ordered-footprint native reference'):
                verifier.verify_contact_footprint_runtime(self.archive,project)

    def test_runtime_and_android_metadata_are48_with_consistent_name(self):
        info=(PROJECT/'scripts/build_info.gd').read_text();preset=verifier.preset_values(PROJECT/'export_presets.cfg')
        self.assertIn('const VERSION_CODE:=48',info)
        self.assertIn('const VERSION:="0.23.0-footprint-alpha1"',info)
        self.assertEqual((preset['version_code'],preset['version']),(48,'0.23.0-footprint-alpha1'))


if __name__=='__main__':unittest.main()
