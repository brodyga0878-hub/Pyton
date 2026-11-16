"""Code52 rejection controls; explicit GDSC mocks do not prove an APK/device."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import test_native_autopilot_packaging as retained

verifier=retained.verifier
PROJECT=Path(__file__).resolve().parents[1]


class MockNativeReturnArchive(retained.MockNativeAutopilotArchive):
    def __init__(self):
        super().__init__()
        for name in verifier.NATIVE_RETURN_MODULES:
            self.entries['assets/scripts/'+name+'.gdc']=b'GDSC'+('explicit-code52-unit-mock-'+name).encode()*5


class NativeReturnPortableBaseline(unittest.TestCase):
    @staticmethod
    def source_view(overrides):return verifier._AlignmentSourceAuditPath(PROJECT,overrides)

    def test_portable51_expands_without_repository_or_commands(self):
        relatives=(verifier.NATIVE_RETURN_BASELINE_FIXTURE_PATH,'tests/fixtures/native_autopilot_v50_sources.json','tests/fixtures/native_landing_v49_sources.json','tests/fixtures/contact_frame_v48_sources.json','tests/fixtures/footprint_v47_sources.json')
        with tempfile.TemporaryDirectory() as directory:
            project=Path(directory)
            for relative in relatives:
                target=project/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((PROJECT/relative).read_bytes())
            self.assertFalse((project/'.git').exists())
            with mock.patch.object(verifier,'run',side_effect=AssertionError('Commands forbidden')),mock.patch.object(verifier.subprocess,'check_output',side_effect=AssertionError('Git forbidden')):
                expanded=verifier._load_native_return_baseline(project)
            self.assertEqual(len(expanded['files']),54)
            self.assertEqual({path:row['sha256']for path,row in expanded['files'].items()},verifier.NATIVE_AUTOPILOT_AUDITED_SOURCE_SHA256)
            self.assertEqual(len(expanded['source_overrides']),3)
            self.assertEqual({path:row['sha256']for path,row in expanded['metadata_source_files'].items()},verifier.NATIVE_RETURN_BASELINE_METADATA_SHA256)
            self.assertEqual(expanded['source_commit'],'347f0b44c700ba4c8aeede3fd3c1cdc8ad2d4ef9')

    def test_rehashed_fabricated51_history_is_rejected(self):
        relative=verifier.NATIVE_RETURN_BASELINE_FIXTURE_PATH;data=json.loads((PROJECT/relative).read_text())
        row=data['source_overrides']['scripts/main.gd'];row['source']+='\n# fabricated history\n';row['sha256']=hashlib.sha256(row['source'].encode()).hexdigest()
        data['audited_runtime_source_sha256']['scripts/main.gd']=row['sha256']
        with self.assertRaisesRegex(AssertionError,'Changed portable code51 native-return source delta'):
            verifier._load_native_return_baseline(self.source_view({relative:json.dumps(data)}))

    def test_every_previous_portable_link_remains_pinned(self):
        for relative in ('tests/fixtures/native_autopilot_v50_sources.json','tests/fixtures/native_landing_v49_sources.json','tests/fixtures/contact_frame_v48_sources.json','tests/fixtures/footprint_v47_sources.json'):
            with self.subTest(relative=relative),self.assertRaises(AssertionError):
                verifier._load_native_return_baseline(self.source_view({relative:(PROJECT/relative).read_text()+' '}))

    def test_code51_metadata_and_runtime_freeze_links_are_exact(self):
        baseline=verifier._load_native_return_baseline(PROJECT)
        self.assertEqual(baseline['runtime_freeze'],{'path':verifier.NATIVE_RETURN_RUNTIME_BASELINE_PATH,'sha256':verifier.NATIVE_RETURN_RUNTIME_BASELINE_SHA256,'runtime_input_count':467})
        for relative,row in baseline['metadata_source_files'].items():
            self.assertEqual(hashlib.sha256(row['source'].encode()).hexdigest(),verifier.NATIVE_RETURN_BASELINE_METADATA_SHA256[relative])
        raw=(PROJECT/verifier.NATIVE_RETURN_RUNTIME_BASELINE_PATH).read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(),verifier.NATIVE_RETURN_RUNTIME_BASELINE_SHA256)
        self.assertEqual(len(json.loads(raw)['files_sha256']),467)


class NativeReturnMotionContract(unittest.TestCase):
    @staticmethod
    def source_view(overrides):return verifier._AlignmentSourceAuditPath(PROJECT,overrides)

    def test_actual_return_motion_contract_is_bounded(self):
        scope=verifier._verify_native_return_motion_scope(PROJECT)
        for name in ('continuous_reverse_coordinate_handoff','private_candidate_publication','actual_installed_atmospheric_shield_checked','return_descent_cold_mode_validated'):
            self.assertTrue(scope[name],name)
        for name in ('full_original_F597_autopilot_proved','full_original_F570_F606_object_bank_proved','whole_planet_terrain_proved','circular_orbit_insertion_proved','physical_device_tested'):
            self.assertFalse(scope[name],name)

    def test_inverse_cannot_discard_f64_position_residual(self):
        relative='scripts/native_orbit_return.gd';source=(PROJECT/relative).read_text();old='orbit._position_f64[axis]-float(center[axis])'
        self.assertIn(old,source)
        with self.assertRaises((AssertionError,ValueError)):
            verifier._verify_native_return_motion_scope(self.source_view({relative:source.replace(old,'float(ship.position[axis])-float(center[axis])')}))

    def test_inverse_cannot_zero_speed_or_mutate_live_pose(self):
        relative='scripts/native_orbit_return.gd';source=(PROJECT/relative).read_text();old=verifier.source_function(source,'prepare_return')
        for statement in ('cs.velocity=Vector3.ZERO','ship.position=Vector3.ZERO','cs.hull=100','cn.elapsed_days=0'):
            with self.subTest(statement=statement):
                changed=source.replace(old,old.replace('\n','\n\t'+statement+'\n',1),1)
                with self.assertRaises(AssertionError):verifier._verify_native_return_motion_scope(self.source_view({relative:changed}))

    def test_inverse_cannot_restart_trial_or_call_legacy_protection(self):
        relative='scripts/native_orbit_return.gd';source=(PROJECT/relative).read_text();old=verifier.source_function(source,'prepare_return')
        for statement in ('source.enter(ship,world)','world.protect_surface(cs,nav.elapsed_days)','cn.advance_fuel_seconds(1,{},cs)'):
            with self.subTest(statement=statement):
                changed=source.replace(old,old.replace('\n','\n\t'+statement+'\n',1),1)
                with self.assertRaises(AssertionError):verifier._verify_native_return_motion_scope(self.source_view({relative:changed}))

    def test_airborne_rebind_cannot_skip_real_classifier_or_allow_response(self):
        relative='scripts/native_surface_model.gd';source=(PROJECT/relative).read_text()
        for old,new in (('proposed.native_session.prepare(','ignored_session.prepare('),('prepared.contact_detected or prepared.response_applied or prepared.landing_accepted','false'),('proposed.native_session.commit(','ignored_session.commit(')):
            with self.subTest(consumer=old):
                self.assertIn(old,source)
                with self.assertRaises((AssertionError,ValueError)):
                    verifier._verify_native_return_motion_scope(self.source_view({relative:source.replace(old,new)}))

    def test_airborne_rebind_cannot_move_the_reached_pose(self):
        relative='scripts/native_surface_model.gd';source=(PROJECT/relative).read_text();old=verifier.source_function(source,'rebind_airborne')
        changed=source.replace(old,old.replace('\n','\n\tship.position=Vector3.ZERO\n',1),1)
        with self.assertRaisesRegex(AssertionError,'must not change the already-reached physical pose'):
            verifier._verify_native_return_motion_scope(self.source_view({relative:changed}))

    def test_return_controls_and_actual_shield_check_cannot_disconnect(self):
        relative='scripts/main.gd';source=(PROJECT/relative).read_text()
        for old,new in (('NativeReturn.prepare_return(','IgnoredReturn.prepare_return('),('pilot.configure_descent(prepared.candidate_ship','pilot.ignore_descent(prepared.candidate_ship'),('candidate_nav.fuel_state(candidate_ship)','candidate_nav.unverified_fuel_state(candidate_ship)')):
            with self.subTest(consumer=old):
                self.assertIn(old,source)
                with self.assertRaises((AssertionError,ValueError)):
                    verifier._verify_native_return_motion_scope(self.source_view({relative:source.replace(old,new)}))

    def test_return_descent_cold_phase_and_real_gear_consumers_cannot_disconnect(self):
        relative='scripts/native_surface_autopilot.gd';source=(PROJECT/relative).read_text()
        for old,new in (('data.phase not in _phases(str(data.mode))','false'),('mode()=="return_landing" and altitude>RETURN_GEAR_HEIGHT_M','false'),('"gear_down":false','"gear_down":true')):
            with self.subTest(consumer=old):
                self.assertIn(old,source)
                with self.assertRaises((AssertionError,ValueError)):
                    verifier._verify_native_return_motion_scope(self.source_view({relative:source.replace(old,new)}))

    def test_return_guidance_cannot_write_physical_pose(self):
        relative='scripts/native_surface_autopilot.gd';source=(PROJECT/relative).read_text();old=verifier.source_function(source,'configure_descent')
        changed=source.replace(old,old.replace('\n','\n\tship.position=Vector3.ZERO\n',1),1)
        with self.assertRaisesRegex(AssertionError,'Guidance must emit controls'):
            verifier._verify_native_return_motion_scope(self.source_view({relative:changed}))


class NativeDockGuidanceContract(unittest.TestCase):
    @staticmethod
    def source_view(overrides):return verifier._AlignmentSourceAuditPath(PROJECT,overrides)

    def test_actual_dock_feedback_contract_is_readonly_and_bounded(self):
        scope=verifier._verify_native_dock_guidance_scope(PROJECT)
        for name in ('readonly_dock_guidance','actual_dock_authority_unchanged','actual_rotating_frame_telemetry_used','clearance_uses_existing_station_owner','existing_dock_autopilot_unchanged'):
            self.assertTrue(scope[name],name)
        self.assertFalse(scope['native_trial_dock_connection_supported'])
        self.assertFalse(scope['new_automatic_dock_entry_implemented'])

    def test_status_cannot_fake_authority_or_replace_rotating_speed(self):
        relative='scripts/dock_approach_guidance.gd';source=(PROJECT/relative).read_text()
        for old,new in (('result.ready=ship.can_dock()','result.ready=true'),('telemetry.relative_linear_velocity_mps.length()','ship.velocity.length()'),('ship.source_docking_telemetry()','{}')):
            with self.subTest(consumer=old):
                self.assertIn(old,source)
                with self.assertRaises((AssertionError,ValueError)):
                    verifier._verify_native_dock_guidance_scope(self.source_view({relative:source.replace(old,new)}))

    def test_status_cannot_move_ship_or_open_actual_geometry(self):
        relative='scripts/dock_approach_guidance.gd';source=(PROJECT/relative).read_text();old=verifier.source_function(source,'status')
        for statement in ('ship.position=Vector3.ZERO','ship.docked=true','ship.dock()','geometry.door_u16=0','ship._source_station.door_u16=0'):
            with self.subTest(statement=statement):
                changed=source.replace(old,old.replace('\n','\n\t'+statement+'\n',1),1)
                with self.assertRaisesRegex(AssertionError,'Dock feedback must remain read-only'):
                    verifier._verify_native_dock_guidance_scope(self.source_view({relative:changed}))

    def test_clearance_cannot_bypass_existing_station_request(self):
        relative='scripts/main.gd';source=(PROJECT/relative).read_text();old=verifier.source_function(source,'_request_dock_clearance')
        changed=source.replace(old,old.replace('world.request_station_open(nav.elapsed_days)','true'),1)
        with self.assertRaisesRegex(AssertionError,'Clearance request must use the existing station owner'):
            verifier._verify_native_dock_guidance_scope(self.source_view({relative:changed}))
        changed=source.replace(old,old.replace('\n','\n\tship._source_station.door_u16=0\n',1),1)
        with self.assertRaisesRegex(AssertionError,'must not write physical station or ship state directly'):
            verifier._verify_native_dock_guidance_scope(self.source_view({relative:changed}))

    def test_actual_dock_capture_cannot_be_replaced_with_a_manual_flag(self):
        relative='scripts/main.gd';source=(PROJECT/relative).read_text();old=verifier.source_function(source,'_dock_action')
        changed=source.replace(old,old.replace('elif ship.dock():','elif true:'),1)
        with self.assertRaises(AssertionError):verifier._verify_native_dock_guidance_scope(self.source_view({relative:changed}))
        changed=source.replace(old,old.replace('\n','\n\tship.docked=true\n',1),1)
        with self.assertRaisesRegex(AssertionError,'Dock button must leave capture'):
            verifier._verify_native_dock_guidance_scope(self.source_view({relative:changed}))

    def test_dock_window_cannot_hide_real_metrics_or_disconnect_actions(self):
        relative='scripts/main.gd';source=(PROJECT/relative).read_text();old=verifier.source_function(source,'_show_docking_guidance')
        for token in ('state.relative_speed_mps','state.local_position_m','_request_dock_clearance)','_toggle_auto()','if state.ready:_menu_action('):
            with self.subTest(consumer=token):
                self.assertIn(token,old)
                changed=source.replace(old,old.replace(token,'ignored_metric_or_action'),1)
                with self.assertRaises((AssertionError,ValueError)):
                    verifier._verify_native_dock_guidance_scope(self.source_view({relative:changed}))


class NativeReturnPackaging(unittest.TestCase):
    def setUp(self):self.archive=MockNativeReturnArchive()

    @staticmethod
    def source_view(overrides):return verifier._AlignmentSourceAuditPath(PROJECT,overrides)

    def test_actual52_scope_and_same_actual_archive_history(self):
        result=verifier.verify_native_return_runtime(self.archive,PROJECT)
        self.assertEqual((result['version'],result['version_code']),('0.27.0-native-return-alpha1',52))
        self.assertEqual((result['compiled_module_count'],result['integration_compiled_module_count']),(2,56))
        self.assertEqual((result['baseline_runtime_source_count'],result['baseline_stored_runtime_source_delta_count']),(54,3))
        self.assertEqual(result['unchanged_code51_runtime_source_count'],51)
        for name in ('baseline_requires_Git','actual_runtime_is_unchanged_code51','compiled_source_correspondence_rebuilt_by_verifier','physical_device_tested','full_original_port_complete'):
            self.assertFalse(result[name],name)
        historical=result['retained_code51_source_audit']
        self.assertEqual(set(historical['source_override_paths']),{'scripts/main.gd','scripts/native_surface_autopilot.gd','scripts/native_surface_model.gd','scripts/build_info.gd','export_presets.cfg'})
        self.assertFalse(historical['compiled_assets_substituted'])
        self.assertFalse(historical['audit_is_actual_unchanged_code51_runtime'])
        scope=result['return_and_dock_scope']
        for name in ('explicit_separate_native_trial','continuous_reverse_coordinate_handoff','private_candidate_publication','original_contact_decides_landing','readonly_dock_guidance','actual_dock_authority_unchanged','default_physical_terrain_is_v4'):
            self.assertTrue(scope[name],name)
        for name in ('full_original_F597_autopilot_proved','full_original_F570_F606_object_bank_proved','whole_planet_terrain_proved','circular_orbit_insertion_proved','physical_device_tested','full_original_port_complete'):
            self.assertFalse(scope[name],name)

    def test_all56_actual_compiled_modules_are_required(self):
        for relative in verifier.NATIVE_RETURN_AUDITED_SOURCE_SHA256:
            with self.subTest(relative=relative):
                archive=MockNativeReturnArchive();del archive.entries['assets/scripts/'+Path(relative).stem+'.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing native-return integration runtime'):
                    verifier.verify_native_return_runtime(archive,PROJECT)

    def test_new_compiled_headers_and_truncation_reject(self):
        for name in verifier.NATIVE_RETURN_MODULES:
            for raw in (b'BAD!'+b'x'*100,b'GDSC'+b'x'*60):
                with self.subTest(name=name,size=len(raw)):
                    archive=MockNativeReturnArchive();archive.entries['assets/scripts/'+name+'.gdc']=raw
                    with self.assertRaisesRegex(AssertionError,'Invalid compiled native-return integration runtime'):
                        verifier.verify_native_return_runtime(archive,PROJECT)

    def test_all56_local_runtime_source_pins_are_strict(self):
        for relative in verifier.NATIVE_RETURN_AUDITED_SOURCE_SHA256:
            with self.subTest(relative=relative):
                project=self.source_view({relative:(PROJECT/relative).read_text()+'\n# unaudited source change\n'})
                with self.assertRaisesRegex(AssertionError,'Native return differs from audited integration source'):
                    verifier.verify_native_return_runtime(self.archive,project)

    def test_same_actual_compiled_bytes_survive_every_historical_gate(self):
        digests={}
        for name in ('main','native_surface_autopilot','native_surface_model','native_orbit_trial','navigation','source_hyperdrive_session'):
            raw=b'GDSC'+('only-actual-exported52-'+name).encode()*6
            self.archive.entries['assets/scripts/'+name+'.gdc']=raw;digests[name]=hashlib.sha256(raw).hexdigest()
        result=verifier.verify_native_return_runtime(self.archive,PROJECT)
        history=result['retained_code51_source_audit']['assets']
        for name,digest in digests.items():
            self.assertEqual(result['integration_compiled_modules'][name],digest)
            self.assertEqual(history['integration_compiled_modules'][name],digest)
        for name in ('main','navigation','source_hyperdrive_session'):
            current=history
            for key in ('retained_code50_source_audit','retained_code49_source_audit','retained_code48_source_audit','retained_code47_source_audit','retained_code46_source_audit'):
                current=current[key]['assets'];self.assertEqual(current['integration_compiled_modules'][name],digests[name])

    def test_old51_public_gate_still_rejects_actual52_source(self):
        with self.assertRaisesRegex(AssertionError,'Native autopilot differs from audited integration source'):
            verifier.verify_native_autopilot_runtime(self.archive,PROJECT)

    def test_original_orbit_and_all_other51_core_sources_are_byte_exact(self):
        protected={path:digest for path,digest in verifier.NATIVE_AUTOPILOT_AUDITED_SOURCE_SHA256.items()if path not in verifier.NATIVE_RETURN_CHANGED_RUNTIME_SOURCES}
        self.assertEqual(len(protected),51)
        for relative,digest in protected.items():
            with self.subTest(relative=relative):
                self.assertEqual(verifier.NATIVE_RETURN_AUDITED_SOURCE_SHA256[relative],digest)
                self.assertEqual(hashlib.sha256((PROJECT/relative).read_bytes()).hexdigest(),digest)
        for relative in ('scripts/native_orbit_trial.gd','scripts/native_landing_trial.gd','scripts/flight_model.gd','scripts/navigation.gd','scripts/source_natural_contact_session.gd'):
            self.assertIn(relative,protected)

    def test_all_undeclared467_runtime_inputs_remain_exact(self):
        runtime=verifier._verify_native_return_runtime_baseline(PROJECT)
        self.assertEqual((runtime['previous_runtime_file_count'],runtime['unchanged_runtime_file_count'],runtime['changed_runtime_file_count']),(467,462,5))
        self.assertEqual(set(runtime['changed_runtime_source_sha256']),{*verifier.NATIVE_RETURN_CHANGED_RUNTIME_SOURCES,'scripts/build_info.gd','export_presets.cfg'})
        self.assertFalse(runtime['runtime_assets_copied_for_validation'])
        for path in ('scripts/planetary_system.gd','scripts/source_orbit_surface_guard.gd','data/ffe_worlds.json'):
            with self.subTest(protected_outside_core56=path),self.assertRaisesRegex(AssertionError,'changed protected code51 runtime input'):
                verifier._verify_native_return_runtime_baseline(self.source_view({path:(PROJECT/path).read_text()+'\n# unaudited old dependency\n'}))
        path=verifier.NATIVE_RETURN_RUNTIME_BASELINE_PATH
        with self.assertRaisesRegex(AssertionError,'Changed immutable code51 runtime freeze'):
            verifier._verify_native_return_runtime_baseline(self.source_view({path:(PROJECT/path).read_text()+' '}))

    def test_protected_Main_contact_and_fuel_methods_cannot_change(self):
        baseline=verifier._load_native_return_baseline(PROJECT)
        for name in ('_apply_pending_source_contact','_source_contact_enabled','_finish_flight_interval'):
            with self.subTest(name=name):
                relative='scripts/main.gd';source=(PROJECT/relative).read_text();old=verifier.source_function(source,name)
                changed=source.replace(old,old.replace('\n','\n\t# protected method changed\n',1),1)
                with self.assertRaisesRegex(AssertionError,'Native return changed protected function'):
                    verifier._verify_native_return_preserved_functions(self.source_view({relative:changed}),baseline)

    def test_unlisted_methods_are_not_silently_accepted(self):
        baseline=verifier._load_native_return_baseline(PROJECT)
        for relative in sorted(verifier.NATIVE_RETURN_CHANGED_RUNTIME_SOURCES):
            with self.subTest(relative=relative):
                source=(PROJECT/relative).read_text()+'\nfunc unaudited_return_entry()->void:pass\n'
                with self.assertRaisesRegex(AssertionError,'Native return changed declared function inventory'):
                    verifier._verify_native_return_preserved_functions(self.source_view({relative:source}),baseline)

    def test_original_runtime_data_remains_exact_in_actual_archive(self):
        for name in ('ffe_natural_contact','ffe_surface_contact','ffe_terrain_query'):
            with self.subTest(name=name):
                archive=MockNativeReturnArchive();archive.entries['assets/data/'+name+'.json']=(PROJECT/'data'/f'{name}.json').read_bytes()+b' '
                with self.assertRaises(AssertionError):verifier.verify_native_return_runtime(archive,PROJECT)

    def test_current52_metadata_and_preset_are_consistent(self):
        result=verifier._verify_native_return_metadata(PROJECT)
        self.assertEqual((result['version'],result['version_code']),(verifier.NATIVE_RETURN_VERSION,52))
        self.assertTrue(result['ui_and_preset_match'])
        for relative,old,new in (('scripts/build_info.gd','VERSION_CODE:=52','VERSION_CODE:=51'),('export_presets.cfg','version/code=52','version/code=51')):
            with self.subTest(relative=relative):
                source=(PROJECT/relative).read_text();self.assertIn(old,source)
                with self.assertRaisesRegex(AssertionError,'differs from code52'):
                    verifier._verify_native_return_metadata(self.source_view({relative:source.replace(old,new)}))
        info=(PROJECT/'scripts/build_info.gd').read_text()
        for desired,wrong in (('const VERSION_CODE:=52','const VERSION_CODE:=51'),('const VERSION:="0.27.0-native-return-alpha1"','const VERSION:="wrong-build"')):
            with self.subTest(commented_expected_constant=desired):
                self.assertIn(desired,info)
                changed=info.replace(desired,wrong)+'\n# '+desired+'\n'
                with self.assertRaisesRegex(AssertionError,'UI/diagnostic version differs from code52'):
                    verifier._verify_native_return_metadata(self.source_view({'scripts/build_info.gd':changed}))


if __name__=='__main__':unittest.main()
