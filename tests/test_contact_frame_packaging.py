"""Code49 rejection controls with explicit mock GDSC, never an APK/device."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import test_contact_footprint_packaging as retained

verifier=retained.verifier
PROJECT=retained.PROJECT


class MockContactFrameArchive(retained.MockFootprintArchive):
    def __init__(self):
        super().__init__()
        for name in verifier.CONTACT_FRAME_MODULES:
            self.entries['assets/scripts/'+name+'.gdc']=b'GDSC'+('actual49-unit-mock-'+name).encode()*5


class ContactFramePackaging(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        directory=tempfile.TemporaryDirectory(prefix='native-landing-packaging-v49-')
        cls.addClassCleanup(directory.cleanup);cls.project=Path(directory.name)
        for relative in cls.project_files():
            target=cls.project/relative;target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes((PROJECT/relative).read_bytes())
        baseline=verifier._load_native_landing_baseline(PROJECT)
        for relative,entry in {**baseline['files'],**baseline['metadata_source_files']}.items():
            target=cls.project/relative;target.parent.mkdir(parents=True,exist_ok=True)
            target.write_text(entry['source'])
    def setUp(self):self.archive=MockContactFrameArchive()

    @staticmethod
    def project_files():
        files=retained.ContactFootprintPackaging.project_files()
        files.update(verifier.CONTACT_FRAME_AUDITED_SOURCE_SHA256)
        files.update(['tests/fixtures/contact_frame_v48_sources.json','tests/fixtures/native_landing_v49_sources.json','tests/fixtures/source_contact_frame_native.json','validation/contact-frame-2026-11-14/native-proof/caller-instruction-proofs.json'])
        return files

    def project_copy(self,directory):
        project=Path(directory)
        for relative in self.project_files():
            target=project/relative;target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes((self.project/relative).read_bytes())
        return project

    def test_actual49_scope_preserves_live_physics_and_actual_archive_bytes(self):
        result=verifier.verify_contact_frame_runtime(self.archive,self.project)
        self.assertEqual(result['baseline_source_commit'],'4dc8e42f864aad3515d2d9a4f1959d41645fffa2')
        self.assertEqual((result['compiled_module_count'],result['integration_compiled_module_count']),(4,46))
        self.assertEqual(result['baseline_runtime_source_count'],42)
        self.assertEqual(result['baseline_stored_runtime_source_delta_count'],3)
        self.assertEqual(result['baseline_metadata_source_count'],2)
        self.assertEqual(result['unchanged_code48_runtime_source_count'],41)
        self.assertEqual(result['preserved_Main_function_count'],121)
        self.assertIn('_sync_scene',result['preserved_Main_functions'])
        self.assertIn('_tick',result['preserved_Main_functions'])
        self.assertIn('_payload',result['preserved_Main_functions'])
        old=result['retained_code48_source_audit']
        self.assertEqual(old['source_override_count'],1)
        self.assertEqual(old['source_override_paths'],['scripts/main.gd'])
        self.assertFalse(old['compiled_assets_substituted'])
        self.assertFalse(old['audit_is_actual_unchanged_code48_runtime'])
        self.assertTrue(result['default_physical_terrain_is_v4'])
        native=result['native_frame_reference']
        self.assertEqual((native['case_count'],native['frame_case_count'],native['caller_case_count']),(242,230,12))
        self.assertEqual(native['caller_instruction_procedure_count'],11)
        self.assertEqual(native['caller_native_adapted_procedure_count'],5)
        self.assertEqual(native['caller_static_only_procedure_count'],6)
        self.assertFalse(native['source_F575_response_executed'])
        self.assertFalse(native['world_frame_conversion_executed'])
        self.assertFalse(native['oracle_executed_by_apk_verifier'])
        self.assertTrue(native['native_negative_D_transform_observed'])
        self.assertGreater(native['q31_nonodd_origin_difference_case_count'],0)
        for key in ('actual_runtime_is_unchanged_code48','baseline_requires_Git','new_runtime_JSON_added',
                    'live_response_enabled','whole_mesh_certified','complete_original_physics',
                    'physical_device_tested','compiled_source_correspondence_rebuilt_by_verifier'):
            self.assertFalse(result[key],key)

    def test_all46_actual_compiled_modules_are_required(self):
        for relative in verifier.CONTACT_FRAME_AUDITED_SOURCE_SHA256:
            with self.subTest(relative=relative):
                archive=MockContactFrameArchive();del archive.entries['assets/scripts/'+Path(relative).stem+'.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing contact-frame integration runtime'):
                    verifier.verify_contact_frame_runtime(archive,self.project)

    def test_new_compiled_headers_and_truncation_reject(self):
        for name in verifier.CONTACT_FRAME_MODULES:
            for raw in (b'BAD!'+b'x'*100,b'GDSC'+b'x'*60):
                with self.subTest(name=name,size=len(raw)):
                    archive=MockContactFrameArchive();archive.entries['assets/scripts/'+name+'.gdc']=raw
                    with self.assertRaisesRegex(AssertionError,'Invalid compiled contact-frame integration runtime'):
                        verifier.verify_contact_frame_runtime(archive,self.project)

    def test_all46_audited_runtime_sources_are_frozen(self):
        for relative in verifier.CONTACT_FRAME_AUDITED_SOURCE_SHA256:
            with self.subTest(relative=relative),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/relative
                path.write_bytes(path.read_bytes()+b'\n# unaudited\n')
                with self.assertRaisesRegex(AssertionError,'Contact frame differs from audited integration source'):
                    verifier.verify_contact_frame_runtime(self.archive,project)

    def test_same_actual_compiled_main_used_in_all_historical_source_audits(self):
        path='assets/scripts/main.gdc';raw=b'GDSC'+b'the-only-exported49-main-byte-array'*7
        self.archive.entries[path]=raw
        result=verifier.verify_contact_frame_runtime(self.archive,self.project);digest=hashlib.sha256(raw).hexdigest()
        self.assertEqual(result['integration_compiled_modules']['main'],digest)
        old48=result['retained_code48_source_audit']['assets']
        self.assertEqual(old48['integration_compiled_modules']['main'],digest)
        old47=old48['retained_code47_source_audit']['assets']
        self.assertEqual(old47['integration_compiled_modules']['main'],digest)
        old46=old47['retained_code46_source_audit']['assets']
        self.assertEqual(old46['integration_compiled_modules']['main'],digest)
        self.assertFalse(result['retained_code48_source_audit']['compiled_assets_substituted'])

    def test_strict48_public_gate_rejects_actual49_source(self):
        with self.assertRaisesRegex(AssertionError,'Contact footprint differs from audited integration source'):
            verifier.verify_contact_footprint_runtime(self.archive,self.project)

    def test_portable_delta_has_exact3_runtime_sources_and_expands42_pinned_hashes(self):
        path=self.project/'tests/fixtures/contact_frame_v48_sources.json';raw=json.loads(path.read_text())
        self.assertNotIn('files',raw)
        self.assertEqual(set(raw['source_overrides']),{'scripts/main.gd','scripts/source_terrain_query_trace.gd','scripts/source_natural_footprint_probe.gd'})
        self.assertEqual(set(raw['metadata_source_files']),{'scripts/build_info.gd','export_presets.cfg'})
        expanded=verifier._load_contact_frame_baseline(self.project)
        self.assertEqual(len(expanded['files']),42)
        self.assertEqual({p:e['sha256']for p,e in expanded['files'].items()},verifier.CONTACT_FOOTPRINT_AUDITED_SOURCE_SHA256)
        self.assertEqual(expanded['base_fixture']['sha256'],verifier.CONTACT_FOOTPRINT_BASELINE_FIXTURE_SHA256)
        self.assertEqual(len(expanded['evidence_source_files']),1)

    def test_delta_expands_in_fresh_directory_without_any_git_or_command_access(self):
        with tempfile.TemporaryDirectory() as directory:
            project=Path(directory)
            for relative in ('tests/fixtures/contact_frame_v48_sources.json','tests/fixtures/footprint_v47_sources.json'):
                target=project/relative;target.parent.mkdir(parents=True,exist_ok=True)
                target.write_bytes((self.project/relative).read_bytes())
            self.assertFalse((project/'.git').exists())
            with mock.patch.object(verifier,'run',side_effect=AssertionError('Commands forbidden while expanding source history')),mock.patch.object(verifier.subprocess,'check_output',side_effect=AssertionError('Git forbidden')):
                expanded=verifier._load_contact_frame_baseline(project)
            self.assertEqual(len(expanded['files']),42)

    def test_delta_cannot_rehash_fabricated_main_history(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'tests/fixtures/contact_frame_v48_sources.json'
            data=json.loads(path.read_text());row=data['source_overrides']['scripts/main.gd']
            row['source']+='\n# fabricated\n';row['sha256']=hashlib.sha256(row['source'].encode()).hexdigest()
            data['audited_runtime_source_sha256']['scripts/main.gd']=row['sha256'];path.write_text(json.dumps(data,ensure_ascii=False))
            with self.assertRaisesRegex(AssertionError,'Changed portable code48 contact-frame source delta'):
                verifier._load_contact_frame_baseline(project)

    def test_linked_immutable47_base_cannot_change(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'tests/fixtures/footprint_v47_sources.json'
            path.write_bytes(path.read_bytes()+b' ')
            with self.assertRaisesRegex(AssertionError,'Changed portable code47 footprint source baseline'):
                verifier._load_contact_frame_baseline(project)

    def test_original_geometry_query_response_and_old_footprint_sources_remain_exact(self):
        for relative in ('scripts/source_terrain_query.gd','scripts/source_terrain_point.gd','scripts/source_terrain_math.gd',
                         'scripts/source_natural_contact.gd','scripts/source_natural_contact_pipeline.gd',
                         'scripts/source_surface_contact.gd','scripts/source_surface_contact_bridge.gd',
                         'scripts/source_natural_footprint_probe.gd','scripts/source_terrain_query_trace.gd'):
            with self.subTest(relative=relative),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/relative
                path.write_bytes(path.read_bytes()+b'\n# original changed\n')
                with self.assertRaises(AssertionError):verifier.verify_contact_frame_runtime(self.archive,project)

    def test_actual_sync_physics_save_and_contact_functions_match48_before_history_audit(self):
        baseline=verifier._load_contact_frame_baseline(self.project)
        for name in ('_sync_scene','_tick','_payload','_decode_state','_source_contact_enabled','_apply_pending_source_contact'):
            with self.subTest(name=name),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/'scripts/main.gd';raw=path.read_text()
                previous=verifier.source_function(raw,name)
                path.write_text(raw.replace(previous,previous.replace('\n','\n\t# changed protected physical method\n',1),1))
                with self.assertRaisesRegex(AssertionError,'Contact frame changed protected Main function'):
                    verifier._verify_contact_frame_preserved_functions(project,baseline)

    def test_original_native_references_remain_exact(self):
        for name in ('source_natural_contact_native','source_surface_contact_native','source_contact_field_native','source_footprint_native'):
            with self.subTest(name=name),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/'tests/fixtures'/f'{name}.json'
                path.write_bytes(path.read_bytes()+b' ')
                with self.assertRaises(AssertionError):verifier.verify_contact_frame_runtime(self.archive,project)

    def test_original_runtime_json_stays_exported_byteexact(self):
        for name in ('ffe_natural_contact','ffe_spherical_contact','ffe_ground_collision','ffe_surface_contact','ffe_terrain_query'):
            with self.subTest(name=name):
                archive=MockContactFrameArchive();path='assets/data/'+name+'.json'
                archive.entries[path]=(self.project/'data'/f'{name}.json').read_bytes()+b' '
                with self.assertRaises(AssertionError):verifier.verify_contact_frame_runtime(archive,self.project)

    def test_new_native_frame_and_caller_instruction_proof_cannot_change(self):
        for relative in ('tests/fixtures/source_contact_frame_native.json','validation/contact-frame-2026-11-14/native-proof/caller-instruction-proofs.json'):
            with self.subTest(relative=relative),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/relative
                path.write_bytes(path.read_bytes()+b' ')
                with self.assertRaises(AssertionError):verifier._verify_contact_frame_native_reference(project)

    def test_current49_runtime_and_android_metadata_have_one_consistent_version(self):
        info=(self.project/'scripts/build_info.gd').read_text();preset=verifier.preset_values(self.project/'export_presets.cfg')
        self.assertIn('const VERSION_CODE:=49',info)
        self.assertIn('const VERSION:="0.24.0-contact-frame-alpha1"',info)
        self.assertEqual((preset['version_code'],preset['version']),(49,'0.24.0-contact-frame-alpha1'))


if __name__=='__main__':unittest.main()
