"""Code50 source/asset rejection controls. GDSC mocks are never an APK/device."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import test_contact_frame_packaging as retained

verifier=retained.verifier
PROJECT=retained.PROJECT


class MockNativeLandingArchive(retained.MockContactFrameArchive):
    def __init__(self):
        super().__init__()
        for name in verifier.NATIVE_LANDING_MODULES:
            self.entries['assets/scripts/'+name+'.gdc']=b'GDSC'+('explicit-code50-unit-mock-'+name).encode()*5


class NativeLandingPackaging(unittest.TestCase):
    def setUp(self):self.archive=MockNativeLandingArchive()

    @staticmethod
    def source_view(overrides):return verifier._AlignmentSourceAuditPath(PROJECT,overrides)

    def test_actual50_scope_and_same_actual_archive_history(self):
        result=verifier.verify_native_landing_runtime(self.archive,PROJECT)
        self.assertEqual((result['version'],result['version_code']),('0.25.0-native-landing-alpha1',50))
        self.assertEqual((result['compiled_module_count'],result['integration_compiled_module_count']),(6,52))
        self.assertEqual(result['unchanged_code49_runtime_source_count'],43)
        self.assertEqual((result['baseline_runtime_source_count'],result['baseline_stored_runtime_source_delta_count']),(46,5))
        self.assertFalse(result['baseline_requires_Git'])
        self.assertTrue(result['live_native_contact_enabled_only_in_explicit_trial'])
        self.assertTrue(result['default_physical_terrain_is_v4'])
        self.assertFalse(result['full_original_port_complete'])
        self.assertFalse(result['physical_device_tested'])
        self.assertFalse(result['compiled_source_correspondence_rebuilt_by_verifier'])
        functions=result['protected_functions']
        self.assertEqual([len(functions['preserved'][path])for path in ('scripts/main.gd','scripts/navigation.gd','scripts/source_hyperdrive_session.gd')],[103,56,73])
        self.assertEqual(len(functions['modified']['scripts/main.gd']),27)
        self.assertEqual(len(functions['added']['scripts/main.gd']),10)
        self.assertEqual(set(functions['added']['scripts/navigation.gd']),{'fork_runtime'})
        self.assertEqual(set(functions['added']['scripts/source_hyperdrive_session.gd']),{'fork_runtime'})
        audit=result['retained_code49_source_audit']
        self.assertEqual(audit['source_override_paths'],['scripts/main.gd','scripts/navigation.gd','scripts/source_hyperdrive_session.gd'])
        self.assertFalse(audit['compiled_assets_substituted'])
        self.assertFalse(audit['audit_is_actual_unchanged_code49_runtime'])
        scope=result['manual_trial_scope']
        self.assertEqual(scope['bounded_models'],list(range(118,134)))
        for key in ('city_underground_supported','autoland_or_orbit_connected','full_source_launch_executed','whole_mesh_identity_claimed','physical_device_tested'):
            self.assertFalse(scope[key],key)

    def test_all52_actual_compiled_modules_are_required(self):
        for relative in verifier.NATIVE_LANDING_AUDITED_SOURCE_SHA256:
            with self.subTest(relative=relative):
                archive=MockNativeLandingArchive();del archive.entries['assets/scripts/'+Path(relative).stem+'.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing native-landing integration runtime'):
                    verifier.verify_native_landing_runtime(archive,PROJECT)

    def test_all_new_compiled_headers_and_truncation_reject(self):
        for name in verifier.NATIVE_LANDING_MODULES:
            for raw in (b'BAD!'+b'x'*100,b'GDSC'+b'x'*60):
                with self.subTest(name=name,size=len(raw)):
                    archive=MockNativeLandingArchive();archive.entries['assets/scripts/'+name+'.gdc']=raw
                    with self.assertRaisesRegex(AssertionError,'Invalid compiled native-landing integration runtime'):
                        verifier.verify_native_landing_runtime(archive,PROJECT)

    def test_all52_local_runtime_source_pins_are_strict(self):
        for relative in verifier.NATIVE_LANDING_AUDITED_SOURCE_SHA256:
            with self.subTest(relative=relative):
                project=self.source_view({relative:(PROJECT/relative).read_text()+'\n# unaudited source change\n'})
                with self.assertRaisesRegex(AssertionError,'Native landing differs from audited integration source'):
                    verifier.verify_native_landing_runtime(self.archive,project)

    def test_same_actual_main_nav_and_hp_session_bytes_used_by_all_old_gates(self):
        digests={}
        for name in ('main','navigation','source_hyperdrive_session'):
            raw=b'GDSC'+('only-actual-exported50-'+name).encode()*6
            self.archive.entries['assets/scripts/'+name+'.gdc']=raw;digests[name]=hashlib.sha256(raw).hexdigest()
        result=verifier.verify_native_landing_runtime(self.archive,PROJECT)
        for name,digest in digests.items():
            self.assertEqual(result['integration_compiled_modules'][name],digest)
            history=result['retained_code49_source_audit']['assets']
            self.assertEqual(history['integration_compiled_modules'][name],digest)
            for key in ('retained_code48_source_audit','retained_code47_source_audit','retained_code46_source_audit'):
                history=history[key]['assets'];self.assertEqual(history['integration_compiled_modules'][name],digest)

    def test_old49_public_gate_still_rejects_actual50_source(self):
        with self.assertRaisesRegex(AssertionError,'Contact frame differs from audited integration source'):
            verifier.verify_contact_frame_runtime(self.archive,PROJECT)

    def test_portable49_expands_without_repository_commands(self):
        relatives=('tests/fixtures/native_landing_v49_sources.json','tests/fixtures/contact_frame_v48_sources.json','tests/fixtures/footprint_v47_sources.json')
        with tempfile.TemporaryDirectory() as directory:
            project=Path(directory)
            for relative in relatives:
                target=project/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((PROJECT/relative).read_bytes())
            self.assertFalse((project/'.git').exists())
            with mock.patch.object(verifier,'run',side_effect=AssertionError('Commands forbidden')),mock.patch.object(verifier.subprocess,'check_output',side_effect=AssertionError('Git forbidden')):
                expanded=verifier._load_native_landing_baseline(project)
            self.assertEqual(len(expanded['files']),46)
            self.assertEqual({path:row['sha256']for path,row in expanded['files'].items()},verifier.CONTACT_FRAME_AUDITED_SOURCE_SHA256)
            self.assertEqual(len(expanded['source_overrides']),5)

    def test_rehashed_fabricated49_history_is_rejected(self):
        relative='tests/fixtures/native_landing_v49_sources.json';data=json.loads((PROJECT/relative).read_text())
        row=data['source_overrides']['scripts/main.gd'];row['source']+='\n# fabricated history\n';row['sha256']=hashlib.sha256(row['source'].encode()).hexdigest()
        data['audited_runtime_source_sha256']['scripts/main.gd']=row['sha256']
        with self.assertRaisesRegex(AssertionError,'Changed portable code49 native-landing source delta'):
            verifier._load_native_landing_baseline(self.source_view({relative:json.dumps(data)}))

    def test_every_old_portable_link_is_still_pinned(self):
        for relative in ('tests/fixtures/contact_frame_v48_sources.json','tests/fixtures/footprint_v47_sources.json'):
            with self.subTest(relative=relative),self.assertRaises(AssertionError):
                verifier._load_native_landing_baseline(self.source_view({relative:(PROJECT/relative).read_text()+' '}))

    def test_protected_ordinary_main_nav_and_hp_methods_cannot_change(self):
        baseline=verifier._load_native_landing_baseline(PROJECT)
        for relative,name in (('scripts/main.gd','_payload'),('scripts/main.gd','_apply_pending_source_contact'),('scripts/main.gd','_finish_flight_interval'),('scripts/navigation.gd','apply_contact_damage'),('scripts/source_hyperdrive_session.gd','advance_fuel_seconds')):
            with self.subTest(relative=relative,name=name):
                source=(PROJECT/relative).read_text();old=verifier.source_function(source,name)
                changed=source.replace(old,old.replace('\n','\n\t# protected method changed\n',1),1)
                with self.assertRaisesRegex(AssertionError,'Native landing changed protected function'):
                    verifier._verify_native_landing_preserved_functions(self.source_view({relative:changed}),baseline)

    def test_unlisted_new_main_method_is_not_silently_accepted(self):
        relative='scripts/main.gd';source=(PROJECT/relative).read_text()+'\nfunc unaudited_native_entry()->void:pass\n'
        with self.assertRaisesRegex(AssertionError,'Native landing changed declared function inventory'):
            verifier._verify_native_landing_preserved_functions(self.source_view({relative:source}),verifier._load_native_landing_baseline(PROJECT))

    def test_disconnected_manual_contact_park_and_atomic_host_consumers_reject(self):
        controls=(
            ('scripts/native_surface_model.gd','native_session.prepare(','disconnected_session.prepare('),
            ('scripts/native_surface_model.gd','native_session.parked_tick()','{}'),
            ('scripts/native_surface_model.gd','native_session.mark_parked()','true'),
            ('scripts/native_surface_model.gd','NativeGravityFrame._basis_readonly(','mutable_world_rotation('),
            ('scripts/native_landing_trial.gd','candidate_surface.finish_native_step(','disconnected_finish('),
            ('scripts/main.gd','native_saves.directory="user://native_contact_trial"','native_saves.directory="user://saves"'),
        )
        for relative,old,new in controls:
            with self.subTest(relative=relative,consumer=old):
                source=(PROJECT/relative).read_text();self.assertIn(old,source)
                with self.assertRaises((AssertionError,ValueError)):
                    verifier._verify_native_landing_scope(self.source_view({relative:source.replace(old,new)}))

    def test_new_native_lifecycle_and_original_instruction_proof_are_pinned(self):
        result=verifier._verify_native_landing_native_reference(PROJECT)
        self.assertEqual((result['case_count'],result['actor_case_count'],result['parked_cold_tick_case_count']),(402,247,76))
        self.assertEqual((result['procedure_count'],result['instruction_count'],result['instruction_bytes']),(19,1409,4202))
        self.assertTrue(result['accepted_F1021_fragment_F1042_F1030_proved'])
        for key in ('full_F1021_proved','full_F1047_launch_proved','original_save_format_proved','oracle_executed_by_apk_verifier','physical_device_tested'):
            self.assertFalse(result[key],key)
        for relative in ('tests/fixtures/source_contact_lifecycle_native.json','validation/contact-lifecycle-2026-11-15/native-proof/instruction-proofs.json'):
            with self.subTest(relative=relative),self.assertRaises(AssertionError):
                verifier._verify_native_landing_native_reference(self.source_view({relative:(PROJECT/relative).read_text()+' '}))

    def test_original_runtime_data_stays_byte_exact_in_actual_archive(self):
        for name in ('ffe_natural_contact','ffe_surface_contact','ffe_terrain_query'):
            with self.subTest(name=name):
                archive=MockNativeLandingArchive();archive.entries['assets/data/'+name+'.json']=(PROJECT/'data'/f'{name}.json').read_bytes()+b' '
                with self.assertRaises(AssertionError):verifier.verify_native_landing_runtime(archive,PROJECT)

    def test_current50_diagnostics_and_android_version_match(self):
        info=(PROJECT/'scripts/build_info.gd').read_text();preset=verifier.preset_values(PROJECT/'export_presets.cfg')
        self.assertIn('const VERSION_CODE:=50',info);self.assertIn('const VERSION:="0.25.0-native-landing-alpha1"',info)
        self.assertEqual((preset['version_code'],preset['version']),(50,verifier.NATIVE_LANDING_VERSION))


if __name__=='__main__':unittest.main()
