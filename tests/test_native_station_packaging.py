"""Code53 rejection controls; explicit GDSC mocks do not prove an APK/device."""
import hashlib
import json
from pathlib import Path
import re
import tempfile
import unittest
from unittest import mock

import test_native_return_packaging as retained

verifier=retained.verifier
PROJECT=Path(__file__).resolve().parents[1]


class MockNativeStationArchive(retained.MockNativeReturnArchive):
    def __init__(self):
        super().__init__()
        for name in verifier.NATIVE_STATION_MODULES:
            self.entries['assets/scripts/'+name+'.gdc']=b'GDSC'+('explicit-code53-unit-mock-'+name).encode()*5


class NativeStationPortableBaseline(unittest.TestCase):
    @staticmethod
    def source_view(overrides):return verifier._AlignmentSourceAuditPath(PROJECT,overrides)

    def test_portable52_expands_without_repository_or_commands(self):
        relatives=(verifier.NATIVE_STATION_BASELINE_FIXTURE_PATH,verifier.NATIVE_RETURN_BASELINE_FIXTURE_PATH,'tests/fixtures/native_autopilot_v50_sources.json','tests/fixtures/native_landing_v49_sources.json','tests/fixtures/contact_frame_v48_sources.json','tests/fixtures/footprint_v47_sources.json')
        with tempfile.TemporaryDirectory() as directory:
            project=Path(directory)
            for relative in relatives:
                target=project/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((PROJECT/relative).read_bytes())
            self.assertFalse((project/'.git').exists())
            with mock.patch.object(verifier,'run',side_effect=AssertionError('Commands forbidden')),mock.patch.object(verifier.subprocess,'check_output',side_effect=AssertionError('Git forbidden')),mock.patch.object(verifier.subprocess,'run',side_effect=AssertionError('Subprocess forbidden')),mock.patch.object(verifier.subprocess,'Popen',side_effect=AssertionError('Process forbidden')):
                expanded=verifier._load_native_station_baseline(project)
            self.assertEqual(len(expanded['files']),56)
            self.assertEqual({path:row['sha256']for path,row in expanded['files'].items()},verifier.NATIVE_RETURN_AUDITED_SOURCE_SHA256)
            self.assertEqual(len(expanded['source_overrides']),5)
            self.assertEqual({path:row['sha256']for path,row in expanded['metadata_source_files'].items()},verifier.NATIVE_STATION_BASELINE_METADATA_SHA256)
            self.assertEqual(len(expanded['evidence_source_files']),1)
            self.assertEqual(expanded['source_commit'],'837ad517d098b4a82aaff75a48dca89c4a157d06')

    def test_rehashed_fabricated52_history_is_rejected(self):
        relative=verifier.NATIVE_STATION_BASELINE_FIXTURE_PATH;data=json.loads((PROJECT/relative).read_text())
        row=data['source_overrides']['scripts/main.gd'];row['source']+='\n# fabricated history\n';row['sha256']=hashlib.sha256(row['source'].encode()).hexdigest()
        data['audited_runtime_source_sha256']['scripts/main.gd']=row['sha256']
        with self.assertRaisesRegex(AssertionError,'Changed portable code52 native-station source delta'):
            verifier._load_native_station_baseline(self.source_view({relative:json.dumps(data)}))

    def test_every_previous_portable_link_remains_pinned(self):
        for relative in (verifier.NATIVE_RETURN_BASELINE_FIXTURE_PATH,'tests/fixtures/native_autopilot_v50_sources.json','tests/fixtures/native_landing_v49_sources.json','tests/fixtures/contact_frame_v48_sources.json','tests/fixtures/footprint_v47_sources.json'):
            with self.subTest(relative=relative),self.assertRaises(AssertionError):
                verifier._load_native_station_baseline(self.source_view({relative:(PROJECT/relative).read_text()+' '}))

    def test_code52_metadata_and_runtime_freeze_links_are_exact(self):
        baseline=verifier._load_native_station_baseline(PROJECT)
        self.assertEqual(baseline['runtime_freeze'],{'path':verifier.NATIVE_STATION_RUNTIME_BASELINE_PATH,'sha256':verifier.NATIVE_STATION_RUNTIME_BASELINE_SHA256,'runtime_input_count':471})
        for relative,row in baseline['metadata_source_files'].items():
            self.assertEqual(hashlib.sha256(row['source'].encode()).hexdigest(),verifier.NATIVE_STATION_BASELINE_METADATA_SHA256[relative])
        raw=(PROJECT/verifier.NATIVE_STATION_RUNTIME_BASELINE_PATH).read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(),verifier.NATIVE_STATION_RUNTIME_BASELINE_SHA256)
        self.assertEqual(len(json.loads(raw)['files_sha256']),471)


class NativeStationPackaging(unittest.TestCase):
    def setUp(self):self.archive=MockNativeStationArchive()

    @staticmethod
    def source_view(overrides):return verifier._AlignmentSourceAuditPath(PROJECT,overrides)

    def test_actual53_scope_and_same_actual_archive_history(self):
        result=verifier.verify_native_station_runtime(self.archive,PROJECT)
        self.assertEqual((result['version'],result['version_code']),('0.28.0-native-station-alpha1',53))
        self.assertEqual((result['compiled_module_count'],result['integration_compiled_module_count']),(2,58))
        self.assertEqual((result['baseline_runtime_source_count'],result['baseline_stored_runtime_source_delta_count']),(56,5))
        self.assertEqual(result['unchanged_code52_runtime_source_count'],55)
        for name in ('baseline_requires_Git','actual_runtime_is_unchanged_code52','compiled_source_correspondence_rebuilt_by_verifier','physical_device_tested','full_original_port_complete'):
            self.assertFalse(result[name],name)
        history=result['retained_code52_source_audit']
        self.assertEqual(set(history['source_override_paths']),{'scripts/main.gd','scripts/build_info.gd','export_presets.cfg'})
        self.assertFalse(history['compiled_assets_substituted'])
        self.assertFalse(history['audit_is_actual_unchanged_code52_runtime'])

    def test_unsealed_source_pins_cannot_learn_live_bytes(self):
        changed=dict(verifier.NATIVE_STATION_AUDITED_SOURCE_SHA256);changed['scripts/main.gd']='PENDING_IMPLEMENTATION_FREEZE'
        with self.assertRaisesRegex(AssertionError,'Unsealed code53 native-station source pins'):
            verifier._verify_native_station_source_pins(changed)

    def test_all58_actual_compiled_modules_are_required(self):
        for relative in verifier.NATIVE_STATION_AUDITED_SOURCE_SHA256:
            with self.subTest(relative=relative):
                archive=MockNativeStationArchive();del archive.entries['assets/scripts/'+Path(relative).stem+'.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing native-station integration runtime'):
                    verifier.verify_native_station_runtime(archive,PROJECT)

    def test_new_compiled_headers_and_truncation_reject(self):
        for name in verifier.NATIVE_STATION_MODULES:
            for raw in (b'BAD!'+b'x'*100,b'GDSC'+b'x'*60):
                with self.subTest(name=name,size=len(raw)):
                    archive=MockNativeStationArchive();archive.entries['assets/scripts/'+name+'.gdc']=raw
                    with self.assertRaisesRegex(AssertionError,'Invalid compiled native-station integration runtime'):
                        verifier.verify_native_station_runtime(archive,PROJECT)

    def test_all58_local_runtime_source_pins_are_strict(self):
        for relative in verifier.NATIVE_STATION_AUDITED_SOURCE_SHA256:
            with self.subTest(relative=relative):
                project=self.source_view({relative:(PROJECT/relative).read_text()+'\n# unaudited source change\n'})
                with self.assertRaisesRegex(AssertionError,'Native station differs from audited integration source'):
                    verifier.verify_native_station_runtime(self.archive,project)

    def test_same_actual_compiled_bytes_survive_every_historical_gate(self):
        digests={}
        for name in ('main','native_station_frame','native_station_trial','native_orbit_return','dock_approach_guidance','native_orbit_trial','navigation','source_hyperdrive_session'):
            raw=b'GDSC'+('only-actual-exported53-'+name).encode()*6
            self.archive.entries['assets/scripts/'+name+'.gdc']=raw;digests[name]=hashlib.sha256(raw).hexdigest()
        result=verifier.verify_native_station_runtime(self.archive,PROJECT)
        for name,digest in digests.items():self.assertEqual(result['integration_compiled_modules'][name],digest)
        history=result['retained_code52_source_audit']['assets']
        for name in ('main','native_orbit_return','dock_approach_guidance','native_orbit_trial','navigation','source_hyperdrive_session'):
            self.assertEqual(history['integration_compiled_modules'][name],digests[name])
        for name in ('main','navigation','source_hyperdrive_session'):
            current=history
            for key in ('retained_code51_source_audit','retained_code50_source_audit','retained_code49_source_audit','retained_code48_source_audit','retained_code47_source_audit','retained_code46_source_audit'):
                current=current[key]['assets'];self.assertEqual(current['integration_compiled_modules'][name],digests[name])

    def test_old52_public_gate_still_rejects_actual53_source(self):
        with self.assertRaisesRegex(AssertionError,'Native return differs from audited integration source'):
            verifier.verify_native_return_runtime(self.archive,PROJECT)

    def test_all55_previous_nonMain_core_sources_are_byte_exact(self):
        protected={path:digest for path,digest in verifier.NATIVE_RETURN_AUDITED_SOURCE_SHA256.items()if path!='scripts/main.gd'}
        self.assertEqual(len(protected),55)
        for relative,digest in protected.items():
            with self.subTest(relative=relative):
                self.assertEqual(verifier.NATIVE_STATION_AUDITED_SOURCE_SHA256[relative],digest)
                self.assertEqual(hashlib.sha256((PROJECT/relative).read_bytes()).hexdigest(),digest)
        for relative in ('scripts/native_orbit_trial.gd','scripts/native_orbit_return.gd','scripts/native_surface_model.gd','scripts/flight_model.gd','scripts/navigation.gd'):
            self.assertIn(relative,protected)

    def test_all_undeclared471_runtime_inputs_remain_exact(self):
        result=verifier._verify_native_station_runtime_baseline(PROJECT)
        self.assertEqual((result['previous_runtime_file_count'],result['unchanged_runtime_file_count'],result['changed_runtime_file_count']),(471,468,3))
        self.assertEqual(set(result['changed_runtime_source_sha256']),{'scripts/main.gd','scripts/build_info.gd','export_presets.cfg'})
        self.assertFalse(result['runtime_assets_copied_for_validation'])
        for relative in ('scripts/planetary_system.gd','scripts/source_station_session.gd','scripts/source_orbit_surface_guard.gd','data/ffe_worlds.json'):
            with self.subTest(protected_outside_core58=relative),self.assertRaisesRegex(AssertionError,'changed protected code52 runtime input'):
                verifier._verify_native_station_runtime_baseline(self.source_view({relative:(PROJECT/relative).read_text()+'\n# unaudited previous dependency\n'}))
        relative=verifier.NATIVE_STATION_RUNTIME_BASELINE_PATH
        with self.assertRaisesRegex(AssertionError,'Changed immutable code52 runtime freeze'):
            verifier._verify_native_station_runtime_baseline(self.source_view({relative:(PROJECT/relative).read_text()+' '}))

    def test_protected_Main_methods_cannot_change(self):
        baseline=verifier._load_native_station_baseline(PROJECT)
        names=set(re.findall(r'^(?:static\s+)?func\s+([A-Za-z0-9_]+)\(',baseline['files']['scripts/main.gd']['source'],re.M))
        protected=sorted(names-verifier.NATIVE_STATION_ALLOWED_CHANGED_MAIN_FUNCTIONS)
        self.assertGreater(len(protected),100)
        for name in protected[:3]:
            with self.subTest(name=name):
                relative='scripts/main.gd';source=(PROJECT/relative).read_text();old=verifier.source_function(source,name)
                changed=source.replace(old,old.replace('\n','\n\t# protected method changed\n',1),1)
                with self.assertRaisesRegex(AssertionError,'Native station changed protected Main function'):
                    verifier._verify_native_station_preserved_functions(self.source_view({relative:changed}),baseline)

    def test_unlisted_Main_methods_are_not_silently_accepted(self):
        baseline=verifier._load_native_station_baseline(PROJECT)
        source=(PROJECT/'scripts/main.gd').read_text()+'\nfunc unaudited_station_entry()->void:pass\n'
        with self.assertRaisesRegex(AssertionError,'Native station changed declared Main function inventory'):
            verifier._verify_native_station_preserved_functions(self.source_view({'scripts/main.gd':source}),baseline)

    def test_original_runtime_data_remains_exact_in_actual_archive(self):
        for name in ('ffe_natural_contact','ffe_surface_contact','ffe_terrain_query'):
            with self.subTest(name=name):
                archive=MockNativeStationArchive();archive.entries['assets/data/'+name+'.json']=(PROJECT/'data'/f'{name}.json').read_bytes()+b' '
                with self.assertRaises(AssertionError):verifier.verify_native_station_runtime(archive,PROJECT)

    def test_current53_metadata_and_preset_are_consistent(self):
        result=verifier._verify_native_station_metadata(PROJECT)
        self.assertEqual((result['version'],result['version_code']),(verifier.NATIVE_STATION_VERSION,53))
        self.assertTrue(result['ui_and_preset_match'])
        for relative,old,new in (('scripts/build_info.gd','VERSION_CODE:=53','VERSION_CODE:=52'),('export_presets.cfg','version/code=53','version/code=52')):
            with self.subTest(relative=relative):
                source=(PROJECT/relative).read_text();self.assertIn(old,source)
                with self.assertRaisesRegex(AssertionError,'differs from code53'):
                    verifier._verify_native_station_metadata(self.source_view({relative:source.replace(old,new)}))
        info=(PROJECT/'scripts/build_info.gd').read_text()
        for desired,wrong in (('const VERSION_CODE:=53','const VERSION_CODE:=52'),('const VERSION:="0.28.0-native-station-alpha1"','const VERSION:="wrong-build"')):
            with self.subTest(commented_expected_constant=desired):
                self.assertIn(desired,info)
                with self.assertRaisesRegex(AssertionError,'UI/diagnostic version differs from code53'):
                    verifier._verify_native_station_metadata(self.source_view({'scripts/build_info.gd':info.replace(desired,wrong)+'\n# '+desired+'\n'}))


class NativeStationContracts(unittest.TestCase):
    @staticmethod
    def view(overrides):return verifier._AlignmentSourceAuditPath(PROJECT,overrides)

    def reject(self,relative,old,new,gate):
        source=(PROJECT/relative).read_text();self.assertIn(old,source)
        with self.assertRaises((AssertionError,ValueError)):
            gate(self.view({relative:source.replace(old,new,1)}))

    def inserted(self,relative,function,statement,gate):
        source=(PROJECT/relative).read_text();old=verifier.source_function(source,function)
        changed=source.replace(old,old.replace('\n','\n\t'+statement+'\n',1),1)
        with self.assertRaises((AssertionError,ValueError)):gate(self.view({relative:changed}))

    def test_actual_frame_contract_declares_bounded_sampled_velocity(self):
        result=verifier._verify_native_station_frame_scope(PROJECT)
        for name in ('source_ephemeris_origin_difference_before_float','source_clock_sampled_origin_velocity','float64_position_carry_used','private_source_clearance_and_atmosphere_checked','boundary_preserves_actual_pose_clock_hp_fuel'):
            self.assertTrue(result[name],name)
        self.assertEqual(result['same_parent_station_handoff_limit_m'],100000)
        self.assertEqual(result['velocity_policy'],'source-ephemeris-origin-derivative-one-second-v1')
        self.assertFalse(result['full_original_F570_F606_object_bank_proved'])
        self.assertFalse(result['physical_device_tested'])

    def test_origin_subtraction_cannot_use_float_absolute_positions(self):
        relative='scripts/native_station_frame.gd'
        self.reject(relative,'_difference(first,second)','ignored_float_absolute_difference(first,second)',verifier._verify_native_station_frame_scope)
        self.reject(relative,'(b>0 and a<MIN_INT+b) or (b<0 and a>MAX_INT+b)','false',verifier._verify_native_station_frame_scope)
        for old,new in [('record.hex_encode(),int(clock.day_u32),int(clock.tick_u32)','record.hex_encode(),0,0'),('_relative_cache[key].duplicate()','_relative_cache[key]'),('_relative_cache[key]=point.duplicate()','_relative_cache[key]=point')]:
            with self.subTest(memo_guard=old):self.reject(relative,old,new,verifier._verify_native_station_frame_scope)

    def test_velocity_difference_cannot_discard_raw_delta_or_source_clock_spacing(self):
        relative='scripts/native_station_frame.gd'
        self.reject(relative,'_difference(next.raw,previous.raw)','ignored_float_delta(next.raw,previous.raw)',verifier._verify_native_station_frame_scope)
        self.reject(relative,'float(ticks)*86400.0/float(Clock.TICKS_PER_DAY)','1.0',verifier._verify_native_station_frame_scope)

    def test_handoff_cannot_replace_actual_float64_orbit_position(self):
        self.reject('scripts/native_station_frame.gd','map_between(world,cw,orbit._position_f64,ship.velocity,nav.elapsed_days)','map_between(world,cw,PackedFloat64Array([ship.position.x,ship.position.y,ship.position.z]),ship.velocity,nav.elapsed_days)',verifier._verify_native_station_frame_scope)

    def test_handoff_cannot_drop_same_parent_distance_atmosphere_or_clearance(self):
        relative='scripts/native_station_frame.gd'
        for old,new in [('str(site.get("parent",""))!=str(world.focus_id)','false'),('distance>MAX_DISTANCE_M','false'),('bool(atmosphere.get("apply_f1014",true))','false'),('Orbit._guard(guard_world,cs,nav.elapsed_days)','ignored_guard(guard_world,cs,nav.elapsed_days)')]:
            with self.subTest(guard=old):self.reject(relative,old,new,verifier._verify_native_station_frame_scope)

    def test_frame_boundary_cannot_move_live_owners_fabricate_hull_or_step_time(self):
        for statement in ('ship.position=Vector3.ZERO','nav.elapsed_days=0','cs.hull=100','cs.attitude=Quaternion.IDENTITY','cn.advance_fuel_seconds(1,{},cs)','cs.step(1,Vector2.ZERO)'):
            with self.subTest(statement=statement):self.inserted('scripts/native_station_frame.gd','prepare',statement,verifier._verify_native_station_frame_scope)

    def test_actual_trial_contract_keeps_real_physics_service_and_cold_owner(self):
        result=verifier._verify_native_station_trial_scope(PROJECT)
        for name in ('atomic_existing_station_motion_and_source_fuel','authoritative_dock_launch_commands_retained','actual_paid_service_owner_retained','station_float64_position_carry_preserved','canonical_body_hazard_observer_used','strict_typed_station_snapshot','cold_source_spin_and_angular_history_replayed','reverse_preserves_current_motion_and_original_orbit_lineage'):
            self.assertTrue(result[name],name)
        self.assertFalse(result['full_original_F597_autopilot_proved'])
        self.assertFalse(result['full_original_port_complete'])

    def test_trial_cannot_disconnect_real_spin_motion_or_collision_hp(self):
        relative='scripts/native_station_trial.gd'
        for old,new in [('Station.refresh(cs,cw,cn,seconds)','ignored_refresh(cs,cw,cn,seconds)'),('cs.step(seconds,steering,roll,gravity,lift)','cs.ignored_step(seconds,steering,roll,gravity,lift)'),('cn.sync_thermal_ship(cs)','cn.ignored_sync(cs)')]:
            with self.subTest(consumer=old):self.reject(relative,old,new,verifier._verify_native_station_trial_scope)

    def test_trial_cannot_replay_motion_or_fuel_interval(self):
        for statement in ('cs.step(seconds,steering,roll,gravity,lift)','cn.advance_fuel_seconds(seconds,{},cs)'):
            with self.subTest(statement=statement):self.inserted('scripts/native_station_trial.gd','prepare',statement,verifier._verify_native_station_trial_scope)

    def test_trial_cannot_use_station_relative_pose_for_body_hazard_observer(self):
        relative='scripts/native_station_trial.gd'
        self.reject(relative,'Frame.map_between(world,bodyworld,position,ship.velocity,nav.elapsed_days)','ignored_station_relative_body_probe()',verifier._verify_native_station_trial_scope)
        self.reject(relative,'Atmosphere.new().sample(bodyworld,probe,','Atmosphere.new().sample(world,ship,',verifier._verify_native_station_trial_scope)

    def test_dock_commands_cannot_fake_physical_capture_or_free_opening(self):
        relative='scripts/native_station_trial.gd'
        for old,new in [('cw.request_station_open(cn.elapsed_days)','true'),('cs.dock()','true'),('cs.launch()','ignored_launch()')]:
            with self.subTest(authority=old):self.reject(relative,old,new,verifier._verify_native_station_trial_scope)
        self.inserted(relative,'prepare_command','cs.position=Flight.STATION',verifier._verify_native_station_trial_scope)

    def test_services_cannot_bypass_paid_owner_pose_clock_or_ship_identity(self):
        relative='scripts/native_station_trial.gd'
        for old,new in [('cn.service(action,id,quantity,cs)','true'),('cs.ship_id!=ship.ship_id','false'),('Orbit._pose(cs)!=_pose_hex','false'),('_hexfloat(cn.elapsed_days)!=_days_hex','false')]:
            with self.subTest(service_guard=old):self.reject(relative,old,new,verifier._verify_native_station_trial_scope)
        for statement in ('cs.credits=999999','cs.hull=100','cn.advance_fuel_seconds(1,{},cs)'):
            with self.subTest(statement=statement):self.inserted(relative,'prepare_service',statement,verifier._verify_native_station_trial_scope)

    def test_cold_motion_cannot_drop_source_spin_or_angular_history(self):
        relative='scripts/native_station_trial.gd'
        for old,new in [('oldworld.advance_station(seconds,nav.elapsed_days)','true'),('Dynamics.sample(expected_previous,expected_basis,seconds)','{}'),('_vec(omega)!=_vec(expected_omega)','false'),('_vec(shipomega)!=_vec(expected_shipomega)','false'),('motion.motion_pending!=expected_pending','false')]:
            with self.subTest(cold_guard=old):self.reject(relative,old,new,verifier._verify_native_station_trial_scope)

    def test_reverse_cannot_reset_current_position_or_original_lineage(self):
        relative='scripts/native_station_trial.gd'
        self.reject(relative,'Frame.map_between(world,bodyworld,_position_f64,cs.velocity,cn.elapsed_days)','ignored_outbound_pose_restore()',verifier._verify_native_station_trial_scope)
        self.reject(relative,'orbit._lineage=original.orbit._lineage.duplicate(true)','orbit._lineage={}',verifier._verify_native_station_trial_scope)
        self.inserted(relative,'prepare_reverse','ship.position=Flight.STATION',verifier._verify_native_station_trial_scope)

    def test_actual_Main_controls_and_save_isolation_are_connected(self):
        result=verifier._verify_native_station_Main_scope(PROJECT)
        for name in ('actual_station_controls_connected','actual_paid_service_controls_connected','Main_preserves_station_spin_on_render_refresh','station_payload_and_strict_decoder_connected','ordinary_progress_and_trial_saves_isolated','station_trial_connection_supported'):
            self.assertTrue(result[name],name)
        self.assertFalse(result['new_original_autopilot_claimed'])

    def test_Main_cannot_drop_typed_station_session_or_cold_conflict_guard(self):
        relative='scripts/main.gd'
        for old,new in [('result.native_station_session=station_state','result.ignored_station_session=station_state'),('candidate_station.restore(data.native_station_session,candidate_ship,candidate_nav,candidate_world,candidate_gear)','true'),('candidate_orbit!=null or data.has("motion_session") or not data.native_station_session is Dictionary','false')]:
            with self.subTest(cold_consumer=old):self.reject(relative,old,new,verifier._verify_native_station_Main_scope)

    def test_Main_exact_clock_must_precede_station_factory(self):
        self.reject('scripts/main.gd','candidate_nav.elapsed_days=exact_day','candidate_nav.elapsed_days=0',verifier._verify_native_station_Main_scope)

    def test_Main_render_refresh_cannot_reset_measured_station_spin(self):
        relative='scripts/main.gd';source=(PROJECT/relative).read_text();old='ship.station_available=true;ship.source_motion_profile=native_station_trial.thrust_profile_enabled()'
        self.assertIn(old,source)
        self.reject(relative,old,'StationSession.configure_flight(ship,world,nav);'+old,verifier._verify_native_station_Main_scope)
        for old,new in [('native_station_render_world=NativeOrbit._fork_world(world)','native_station_render_world=world'),('ship._source_station if _native_station_active()','world.source_station_geometry(nav.elapsed_days) if _native_station_active()'),('ship._source_basis if _native_station_active()','world.source_station_basis(nav.elapsed_days) if _native_station_active()')]:
            with self.subTest(render_guard=old):self.reject(relative,old,new,verifier._verify_native_station_Main_scope)

    def test_Main_input_and_paid_service_cannot_disconnect_transactions(self):
        relative='scripts/main.gd'
        for old,new in [('native_station_trial.prepare_command(ship,nav,landing_gear,world,action)','ignored_command(action)'),('native_station_trial.prepare_service(ship,nav,landing_gear,world,action,id,quantity)','ignored_service(action)'),('_native_station_command("launch" if ship.docked else "dock")','ignored_dock_action()'),('_native_station_command("request_open")','ignored_open_action()')]:
            with self.subTest(actual_consumer=old):self.reject(relative,old,new,verifier._verify_native_station_Main_scope)

    def test_Main_cannot_run_a_second_station_physics_interval(self):
        for statement in ('ship.step(dt,steering,roll)','nav.advance_fuel_seconds(dt,{},ship)','_finish_flight_interval(dt)'):
            with self.subTest(statement=statement):self.inserted('scripts/main.gd','_tick_native_station',statement,verifier._verify_native_station_Main_scope)

    def test_ordinary_factory_cannot_accept_a_native_station_save(self):
        relative='scripts/main.gd';source=(PROJECT/relative).read_text();old=verifier.source_function(source,'_decode_primary_state')
        self.assertIn(' or data.has("native_station_session")',old)
        changed=source.replace(old,old.replace(' or data.has("native_station_session")',''),1)
        with self.assertRaises(AssertionError):verifier._verify_native_station_Main_scope(self.view({relative:changed}))


if __name__=='__main__':unittest.main()
