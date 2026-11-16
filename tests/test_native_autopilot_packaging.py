"""Code51 source/asset rejection controls; mock GDSC never proves an APK/device."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import test_native_landing_packaging as retained

verifier=retained.verifier
# Keep the code51 assertions against exact portable source history as code52 evolves.
# This wraps host source reads only; every archive byte remains the caller's actual byte.
_code51_baseline=verifier._load_native_return_baseline(retained.PROJECT)
PROJECT=verifier._AlignmentSourceAuditPath(retained.PROJECT,{
    path:row['source']for path,row in {**_code51_baseline['files'],**_code51_baseline['metadata_source_files']}.items()
})


class MockNativeAutopilotArchive(retained.MockNativeLandingArchive):
    def __init__(self):
        super().__init__()
        for name in verifier.NATIVE_AUTOPILOT_MODULES:
            self.entries['assets/scripts/'+name+'.gdc']=b'GDSC'+('explicit-code51-unit-mock-'+name).encode()*5


class NativeAutopilotPackaging(unittest.TestCase):
    def setUp(self):self.archive=MockNativeAutopilotArchive()

    @staticmethod
    def source_view(overrides):return verifier._AlignmentSourceAuditPath(PROJECT,overrides)

    def test_actual51_scope_and_same_actual_archive_history(self):
        result=verifier.verify_native_autopilot_runtime(self.archive,PROJECT)
        self.assertEqual((result['version'],result['version_code']),('0.26.0-native-autopilot-alpha1',51))
        self.assertEqual((result['compiled_module_count'],result['integration_compiled_module_count']),(2,54))
        self.assertEqual((result['baseline_runtime_source_count'],result['baseline_stored_runtime_source_delta_count']),(52,9))
        self.assertEqual(result['unchanged_code50_runtime_source_count'],51)
        self.assertFalse(result['baseline_requires_Git'])
        self.assertFalse(result['actual_runtime_is_unchanged_code50'])
        self.assertFalse(result['compiled_source_correspondence_rebuilt_by_verifier'])
        self.assertFalse(result['physical_device_tested'])
        self.assertFalse(result['full_original_port_complete'])
        scope=result['automatic_trial_scope']
        for name in ('explicit_separate_surface_and_orbit_trial','legacy_code50_manual_native_save_supported','control_only_host_autoland','powered_host_departure_without_pose_snap','original_contact_and_park_decide_landing','atomic_guidance_and_orbit_intervals','exact_guidance_and_orbit_cold_bindings','continuous_affine_coordinate_handoff','default_physical_terrain_is_v4'):
            self.assertTrue(scope[name],name)
        for name in ('whole_mesh_identity_claimed','full_original_autopilot_F597_proved','full_original_launch_scheduler_proved','full_original_F570_F606_object_bank_proved','circular_orbit_insertion_proved','physical_device_tested','full_original_port_complete'):
            self.assertFalse(scope[name],name)
        historical=result['retained_code50_source_audit']
        self.assertEqual(historical['source_override_paths'],['scripts/main.gd'])
        self.assertFalse(historical['compiled_assets_substituted'])
        self.assertFalse(historical['audit_is_actual_unchanged_code50_runtime'])

    def test_all54_actual_compiled_modules_are_required(self):
        for relative in verifier.NATIVE_AUTOPILOT_AUDITED_SOURCE_SHA256:
            with self.subTest(relative=relative):
                archive=MockNativeAutopilotArchive();del archive.entries['assets/scripts/'+Path(relative).stem+'.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing native-autopilot integration runtime'):
                    verifier.verify_native_autopilot_runtime(archive,PROJECT)

    def test_new_compiled_headers_and_truncation_reject(self):
        for name in verifier.NATIVE_AUTOPILOT_MODULES:
            for raw in (b'BAD!'+b'x'*100,b'GDSC'+b'x'*60):
                with self.subTest(name=name,size=len(raw)):
                    archive=MockNativeAutopilotArchive();archive.entries['assets/scripts/'+name+'.gdc']=raw
                    with self.assertRaisesRegex(AssertionError,'Invalid compiled native-autopilot integration runtime'):
                        verifier.verify_native_autopilot_runtime(archive,PROJECT)

    def test_all54_local_runtime_source_pins_are_strict(self):
        for relative in verifier.NATIVE_AUTOPILOT_AUDITED_SOURCE_SHA256:
            with self.subTest(relative=relative):
                project=self.source_view({relative:(PROJECT/relative).read_text()+'\n# unaudited source change\n'})
                with self.assertRaisesRegex(AssertionError,'Native autopilot differs from audited integration source'):
                    verifier.verify_native_autopilot_runtime(self.archive,project)

    def test_same_actual_compiled_bytes_survive_every_historical_gate(self):
        digests={}
        for name in ('main','navigation','source_hyperdrive_session'):
            raw=b'GDSC'+('only-actual-exported51-'+name).encode()*6
            self.archive.entries['assets/scripts/'+name+'.gdc']=raw;digests[name]=hashlib.sha256(raw).hexdigest()
        result=verifier.verify_native_autopilot_runtime(self.archive,PROJECT)
        for name,digest in digests.items():
            self.assertEqual(result['integration_compiled_modules'][name],digest)
            history=result['retained_code50_source_audit']['assets']
            self.assertEqual(history['integration_compiled_modules'][name],digest)
            for key in ('retained_code49_source_audit','retained_code48_source_audit','retained_code47_source_audit','retained_code46_source_audit'):
                history=history[key]['assets'];self.assertEqual(history['integration_compiled_modules'][name],digest)

    def test_old50_public_gate_still_rejects_actual51_source(self):
        with self.assertRaisesRegex(AssertionError,'Native landing differs from audited integration source'):
            verifier.verify_native_landing_runtime(self.archive,PROJECT)

    def test_portable50_expands_without_repository_commands(self):
        relatives=('tests/fixtures/native_autopilot_v50_sources.json','tests/fixtures/native_landing_v49_sources.json','tests/fixtures/contact_frame_v48_sources.json','tests/fixtures/footprint_v47_sources.json')
        with tempfile.TemporaryDirectory() as directory:
            project=Path(directory)
            for relative in relatives:
                target=project/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((PROJECT/relative).read_bytes())
            self.assertFalse((project/'.git').exists())
            with mock.patch.object(verifier,'run',side_effect=AssertionError('Commands forbidden')),mock.patch.object(verifier.subprocess,'check_output',side_effect=AssertionError('Git forbidden')):
                expanded=verifier._load_native_autopilot_baseline(project)
            self.assertEqual(len(expanded['files']),52)
            self.assertEqual({path:row['sha256']for path,row in expanded['files'].items()},verifier.NATIVE_LANDING_AUDITED_SOURCE_SHA256)
            self.assertEqual(len(expanded['source_overrides']),9)
            self.assertEqual({path:row['sha256']for path,row in expanded['metadata_source_files'].items()},verifier.NATIVE_AUTOPILOT_BASELINE_METADATA_SHA256)
            self.assertEqual(expanded['source_commit'],'2f07e52497211436c94f98e5a41d17dab6784835')

    def test_rehashed_fabricated50_history_is_rejected(self):
        relative='tests/fixtures/native_autopilot_v50_sources.json';data=json.loads((PROJECT/relative).read_text())
        row=data['source_overrides']['scripts/main.gd'];row['source']+='\n# fabricated history\n';row['sha256']=hashlib.sha256(row['source'].encode()).hexdigest()
        data['audited_runtime_source_sha256']['scripts/main.gd']=row['sha256']
        with self.assertRaisesRegex(AssertionError,'Changed portable code50 native-autopilot source delta'):
            verifier._load_native_autopilot_baseline(self.source_view({relative:json.dumps(data)}))

    def test_every_old_portable_link_remains_pinned(self):
        for relative in ('tests/fixtures/native_landing_v49_sources.json','tests/fixtures/contact_frame_v48_sources.json','tests/fixtures/footprint_v47_sources.json'):
            with self.subTest(relative=relative),self.assertRaises(AssertionError):
                verifier._load_native_autopilot_baseline(self.source_view({relative:(PROJECT/relative).read_text()+' '}))

    def test_all51_retained_nonMain_kernel_sources_are_byte_exact(self):
        old=verifier.NATIVE_LANDING_AUDITED_SOURCE_SHA256;new=verifier.NATIVE_AUTOPILOT_AUDITED_SOURCE_SHA256
        protected={path:digest for path,digest in old.items()if path!='scripts/main.gd'}
        self.assertEqual(len(protected),51)
        for path,digest in protected.items():
            with self.subTest(path=path):
                self.assertEqual(new[path],digest)
                self.assertEqual(hashlib.sha256((PROJECT/path).read_bytes()).hexdigest(),digest)
        for path in ('scripts/flight_model.gd','scripts/surface_model.gd','scripts/navigation.gd','scripts/source_hyperdrive_session.gd','scripts/source_natural_contact_session.gd','scripts/source_native_surface_provider.gd','scripts/native_landing_trial.gd'):
            self.assertIn(path,protected)

        runtime=verifier._verify_native_autopilot_runtime_baseline(PROJECT)
        self.assertEqual((runtime['previous_runtime_file_count'],runtime['unchanged_runtime_file_count'],runtime['changed_runtime_file_count']),(463,460,3))
        self.assertEqual(set(runtime['changed_runtime_source_sha256']),{'scripts/main.gd','scripts/build_info.gd','export_presets.cfg'})
        self.assertFalse(runtime['runtime_assets_copied_for_validation'])
        for path in ('scripts/planetary_system.gd','scripts/source_orbit_surface_guard.gd','data/ffe_worlds.json'):
            with self.subTest(protected_outside_core54=path),self.assertRaisesRegex(AssertionError,'changed protected code50 runtime input'):
                verifier._verify_native_autopilot_runtime_baseline(self.source_view({path:(PROJECT/path).read_text()+'\n# unaudited old dependency\n'}))
        path=verifier.NATIVE_AUTOPILOT_RUNTIME_BASELINE_PATH
        with self.assertRaisesRegex(AssertionError,'Changed immutable code50 runtime freeze'):
            verifier._verify_native_autopilot_runtime_baseline(self.source_view({path:(PROJECT/path).read_text()+' '}))


    def test_protected_ordinary_Main_contact_and_fuel_methods_cannot_change(self):
        baseline=verifier._load_native_autopilot_baseline(PROJECT)
        for name in ('_apply_pending_source_contact','_source_contact_enabled','_finish_flight_interval'):
            with self.subTest(name=name):
                relative='scripts/main.gd';source=(PROJECT/relative).read_text();old=verifier.source_function(source,name)
                changed=source.replace(old,old.replace('\n','\n\t# protected method changed\n',1),1)
                with self.assertRaisesRegex(AssertionError,'Native autopilot changed protected Main function'):
                    verifier._verify_native_autopilot_preserved_functions(self.source_view({relative:changed}),baseline)

    def test_unlisted_Main_methods_are_not_silently_accepted(self):
        relative='scripts/main.gd';source=(PROJECT/relative).read_text()+'\nfunc unaudited_auto_entry()->void:pass\n'
        with self.assertRaisesRegex(AssertionError,'Native autopilot changed declared Main function inventory'):
            verifier._verify_native_autopilot_preserved_functions(self.source_view({relative:source}),verifier._load_native_autopilot_baseline(PROJECT))

    def test_guidance_cannot_write_the_physical_pose_directly(self):
        relative='scripts/native_surface_autopilot.gd';source=(PROJECT/relative).read_text()
        old=verifier.source_function(source,'configure_land');changed=source.replace(old,old.replace('\n','\n\tship.position=Vector3.ZERO\n',1),1)
        with self.assertRaisesRegex(AssertionError,'Guidance must emit controls'):
            verifier._verify_native_autopilot_scope(self.source_view({relative:changed}))

    def test_actual_contact_and_guidance_observation_consumers_cannot_disconnect(self):
        controls=(('Trial.prepare(','DisconnectedTrial.prepare('),('candidate_pilot.observe(','candidate_pilot.ignore_observation('),('surface.native_session.phase()!="parked"','false'))
        for old,new in controls:
            with self.subTest(consumer=old):
                relative='scripts/native_surface_autopilot.gd';source=(PROJECT/relative).read_text();self.assertIn(old,source)
                with self.assertRaises((AssertionError,ValueError)):
                    verifier._verify_native_autopilot_scope(self.source_view({relative:source.replace(old,new)}))

    def test_handoff_cannot_bypass_affine_pose_or_guard_or_cold_lineage(self):
        controls=(('Phone.to_bodyfixed_point(','unverified_point('),('_guard(candidate_world,candidate_ship,nav.elapsed_days)','{"ok":true}'),('_replay_lineage(data.lineage)','{}'),('candidate._position_f64=position','candidate._position_f64=PackedFloat64Array()'),('_hex(data.position_f64_hex,24)','_hex(data.position_f64_hex,12)'),('"fuel_advanced":false','"fuel_advanced":true'))
        for old,new in controls:
            with self.subTest(consumer=old):
                relative='scripts/native_orbit_trial.gd';source=(PROJECT/relative).read_text();self.assertIn(old,source)
                with self.assertRaises((AssertionError,ValueError)):
                    verifier._verify_native_autopilot_scope(self.source_view({relative:source.replace(old,new)}))

    def test_handoff_cannot_zero_actual_velocity_or_call_legacy_protect(self):
        relative='scripts/native_orbit_trial.gd';source=(PROJECT/relative).read_text();old=verifier.source_function(source,'prepare_handoff')
        for statement in ('candidate_ship.velocity=Vector3.ZERO','candidate_world.protect_surface(candidate_ship,nav.elapsed_days)'):
            with self.subTest(statement=statement):
                changed=source.replace(old,old.replace('\n','\n\t'+statement+'\n',1),1)
                with self.assertRaisesRegex(AssertionError,'Handoff must not relocate'):
                    verifier._verify_native_autopilot_scope(self.source_view({relative:changed}))

    def test_both_native_trial_phases_cannot_be_routed_to_the_ordinary_save(self):
        relative='scripts/main.gd';source=(PROJECT/relative).read_text();old=verifier.source_function(source,'_save_game');changed=source.replace(old,old.replace('_native_trial_active()','_native_surface_active()'),1)
        with self.assertRaisesRegex(AssertionError,'Every native trial phase'):
            verifier._verify_native_autopilot_scope(self.source_view({relative:changed}))

    def test_original_runtime_data_remains_exact_in_actual_archive(self):
        for name in ('ffe_natural_contact','ffe_surface_contact','ffe_terrain_query'):
            with self.subTest(name=name):
                archive=MockNativeAutopilotArchive();archive.entries['assets/data/'+name+'.json']=(PROJECT/'data'/f'{name}.json').read_bytes()+b' '
                with self.assertRaises(AssertionError):verifier.verify_native_autopilot_runtime(archive,PROJECT)

    def test_current51_metadata_and_preset_are_consistent(self):
        result=verifier._verify_native_autopilot_metadata(PROJECT)
        self.assertEqual((result['version'],result['version_code']),(verifier.NATIVE_AUTOPILOT_VERSION,51))
        self.assertTrue(result['ui_and_preset_match'])
        for relative,old,new in (('scripts/build_info.gd','VERSION_CODE:=51','VERSION_CODE:=50'),('export_presets.cfg','version/code=51','version/code=50')):
            with self.subTest(relative=relative):
                source=(PROJECT/relative).read_text();self.assertIn(old,source)
                with self.assertRaisesRegex(AssertionError,'differs from code51'):
                    verifier._verify_native_autopilot_metadata(self.source_view({relative:source.replace(old,new)}))


        info=(PROJECT/'scripts/build_info.gd').read_text()
        for desired,wrong in (('const VERSION_CODE:=51','const VERSION_CODE:=50'),('const VERSION:="0.26.0-native-autopilot-alpha1"','const VERSION:="wrong-build"')):
            with self.subTest(commented_expected_constant=desired):
                self.assertIn(desired,info)
                changed=info.replace(desired,wrong)+'\n# '+desired+'\n'
                with self.assertRaisesRegex(AssertionError,'UI/diagnostic version differs from code51'):
                    verifier._verify_native_autopilot_metadata(self.source_view({'scripts/build_info.gd':changed}))


if __name__=='__main__':unittest.main()
