"""Strict code44 asset/source rejection controls with explicit mock GDSC bytes."""
import importlib.util
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

PROJECT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('surface_contact_android_verifier',PROJECT/'tools/verify_rebuilt_android.py')
verifier=importlib.util.module_from_spec(spec);spec.loader.exec_module(verifier)


class MockSurfaceContactArchive:
    def __init__(self):
        names={Path(name).stem for name in verifier.SURFACE_CONTACT_AUDITED_SOURCE_SHA256}
        names.update(Path(name).stem for name in verifier.SURFACE_CONTACT_PROVIDER_DEPENDENCY_SHA256 if name.endswith('.gd'))
        names.update(verifier.SYSTEM_INFORMATION_MODULES)
        self.entries={f'assets/scripts/{name}.gdc':b'GDSC'+b'explicit-unit-mock-not-an-APK'*5 for name in names}
        self.entries.update({f'assets/data/{name}.json':(PROJECT/'data'/f'{name}.json').read_bytes()
                             for name in ('ffe_surface_contact','ffe_runtime_model_descriptors','ffe_landing_gear','ffe_atmosphere','ffe_fuel','ffe_hyperdrive',*verifier.SYSTEM_INFORMATION_TABLES)})
    def namelist(self):return list(self.entries)
    def read(self,name):return self.entries[name]


class SurfaceContactPackaging(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        directory=tempfile.TemporaryDirectory(prefix='spherical-packaging-v44-')
        cls.addClassCleanup(directory.cleanup);cls.project=Path(directory.name)
        for relative in cls.project_files():
            target=cls.project/relative;target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes((PROJECT/relative).read_bytes())
        path=PROJECT/'tests/fixtures/spherical_v44_sources.json'
        if hashlib.sha256(path.read_bytes()).hexdigest()!='8b6eebc4d6ea1faf37f86f3fdb0389da8fd1a238925044370232bca86e923d57':
            raise AssertionError('Historical code44 spherical baseline fixture changed')
        baseline=json.loads(path.read_text());expected=verifier.SURFACE_CONTACT_AUDITED_SOURCE_SHA256
        if baseline['source_commit']!='86a4a5e2a44c73d610d8a35f7fda7e393343991e' or set(baseline['files'])!=set(expected):
            raise AssertionError('Historical code44 source fixture domain changed')
        for name,digest in expected.items():
            entry=baseline['files'][name];raw=entry['source'].encode()
            if entry['sha256']!=digest or hashlib.sha256(raw).hexdigest()!=digest:
                raise AssertionError('Historical code44 source differs '+name)
            (cls.project/name).write_bytes(raw)

    def setUp(self):self.archive=MockSurfaceContactArchive()

    @staticmethod
    def project_files():
        files=set(verifier.MAP_VISUAL_PROTECTED_SOURCE_SHA256)
        for values in [verifier.SURFACE_CONTACT_AUDITED_SOURCE_SHA256,verifier.FUEL_CONTACT_DEPENDENCY_SHA256,
                       verifier.HYPERDRIVE_INFORMATION_SOURCE_SHA256,verifier.SURFACE_CONTACT_PROVIDER_DEPENDENCY_SHA256]:files.update(values)
        files.update(['scripts/celestial_renderer.gd','scripts/system_map_view.gd','data/ffe_surface_contact.json',
                      'data/ffe_runtime_model_descriptors.json','data/ffe_landing_gear.json','data/ffe_atmosphere.json','data/ffe_fuel.json',
                      'data/ffe_hyperdrive.json','tests/fixtures/source_hyperdrive_native.json','tests/fixtures/source_landing_gear_native.json','tests/fixtures/source_surface_contact_native.json'])
        files.update(f'data/{name}.json'for name in verifier.SYSTEM_INFORMATION_TABLES)
        files.update(f'tests/fixtures/{name}.json'for name in (*verifier.FUEL_NATIVE_REFERENCE,*verifier.ATMOSPHERE_NATIVE_REFERENCE))
        return files

    def project_copy(self,directory):
        project=Path(directory)
        for relative in self.project_files():
            path=project/relative;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes((self.project/relative).read_bytes())
        return project

    def mutate_resource(self,project,callback):
        path=project/'data/ffe_surface_contact.json';data=json.loads(path.read_text());callback(data)
        raw=json.dumps(data,ensure_ascii=False).encode();path.write_bytes(raw);self.archive.entries['assets/data/ffe_surface_contact.json']=raw

    def mutate_function(self,project,module,name,old,new):
        path=project/'scripts'/f'{module}.gd';raw=path.read_text();function=verifier.source_function(raw,name)
        self.assertIn(old,function);path.write_text(raw.replace(function,function.replace(old,new,1),1))

    def test_frozen_scope_and_retained_evidence_boundaries(self):
        result=verifier.verify_surface_contact_runtime(self.archive,self.project)
        self.assertEqual(result['baseline_source_commit'],'faa22eaee504b324b096d64c059d9daf670eca9c')
        self.assertEqual((result['compiled_module_count'],result['integration_compiled_module_count'],result['raw_json_count']),(2,23,1))
        self.assertEqual((result['runtime_primary_anchor_bytes'],result['runtime_primary_instruction_count']),(1657,518))
        self.assertEqual((result['instruction_proof_record_count'],result['instruction_proof_bytes_including_primary'],result['instruction_proof_instructions_including_primary']),(21,3402,1259))
        self.assertEqual((result['unchanged_code43_source_count'],result['protected_old_source_data_count'],result['protected_contact_dependency_count']),(17,10,16))
        self.assertEqual((result['unchanged_Main_function_count'],result['normalized_Main_function_count'],result['protected_Main_function_count'],result['unchanged_Surface_function_count'],result['unchanged_saved_state_function_count']),(9,2,11,9,13))
        self.assertEqual(result['published_provider_dependency_count'],17)
        self.assertEqual(result['native_reference']['case_count'],858)
        self.assertTrue(result['new_json_is_provenance_only']);self.assertFalse(result['new_json_runtime_lookup_required'])
        self.assertFalse(result['native_reference']['oracle_executed_by_apk_verifier'])
        for key in ['whole_F575_runtime','full_F569_F570_F576_F577_F578_classifier','full_original_reference_frame_pipeline',
                    'full_original_destruction_equipment_dispatcher','complete_original_physics',
                    'compiled_source_correspondence_rebuilt_by_verifier','physical_device_tested']:
            self.assertFalse(result[key],key)

    def test_each_integration_module_is_required(self):
        for relative in verifier.SURFACE_CONTACT_AUDITED_SOURCE_SHA256:
            name=Path(relative).stem
            with self.subTest(name=name):
                archive=MockSurfaceContactArchive();del archive.entries[f'assets/scripts/{name}.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing (atmospheric|landing-gear|surface-contact|fuel|hyperdrive)'):
                    verifier.verify_surface_contact_runtime(archive,self.project)

    def test_each_new_module_header_and_length_is_checked(self):
        for name in verifier.SURFACE_CONTACT_MODULES:
            for content in [b'BAD!'+b'x'*100,b'GDSC'+b'x'*60]:
                with self.subTest(name=name,bytes=len(content)):
                    archive=MockSurfaceContactArchive();archive.entries[f'assets/scripts/{name}.gdc']=content
                    with self.assertRaisesRegex(AssertionError,'Invalid compiled surface-contact'):
                        verifier.verify_surface_contact_runtime(archive,self.project)

    def test_each_published_geometry_provider_is_required(self):
        for relative in verifier.SURFACE_CONTACT_PROVIDER_DEPENDENCY_SHA256:
            if not relative.endswith('.gd'):continue
            name=Path(relative).stem
            with self.subTest(name=name):
                archive=MockSurfaceContactArchive();del archive.entries[f'assets/scripts/{name}.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing published contact provider'):
                    verifier.verify_surface_contact_runtime(archive,self.project)

    def test_missing_or_different_exported_provenance_json_rejects(self):
        del self.archive.entries['assets/data/ffe_surface_contact.json']
        with self.assertRaisesRegex(AssertionError,'Missing surface-contact provenance resource'):
            verifier.verify_surface_contact_runtime(self.archive,self.project)
        self.archive=MockSurfaceContactArchive();self.archive.entries['assets/data/ffe_surface_contact.json']+=b' '
        with self.assertRaisesRegex(AssertionError,'Surface-contact resource differs from local source'):
            verifier.verify_surface_contact_runtime(self.archive,self.project)

    def test_all_retained_resources_remain_checked(self):
        for name in ('ffe_landing_gear','ffe_atmosphere','ffe_fuel','ffe_hyperdrive',*verifier.SYSTEM_INFORMATION_TABLES):
            with self.subTest(name=name):
                archive=MockSurfaceContactArchive();archive.entries[f'assets/data/{name}.json']+=b' '
                with self.assertRaises(AssertionError):verifier.verify_surface_contact_runtime(archive,self.project)

    def test_original_runtime_descriptor_table_cannot_be_substituted(self):
        self.archive.entries['assets/data/ffe_runtime_model_descriptors.json']+=b' '
        with self.assertRaisesRegex(AssertionError,'Contact runtime descriptors differ'):
            verifier.verify_surface_contact_runtime(self.archive,self.project)

    def test_wrong_executable_provenance_cannot_pass_matching_export(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,lambda d:d.update(source_sha256='0'*64))
            with self.assertRaisesRegex(AssertionError,'Wrong surface-contact source provenance'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_bounded_entry_cannot_claim_whole_f575_or_excluded_pair_response(self):
        for label in ['575_full_static_only','578_excluded_variant']:
            with self.subTest(label=label),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);self.mutate_resource(project,lambda d:d['procedures'][label].update(runtime_entry=True))
                with self.assertRaisesRegex(AssertionError,'Static/excluded contact anchor cannot be called runtime'):
                    verifier.verify_surface_contact_runtime(self.archive,project)

    def test_instruction_proof_bytes_cannot_use_a_self_reported_hash(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            def corrupt(data):
                row=data['instruction_proofs']['1521'];row['hex']='00'+row['hex'][2:];row['sha256']=hashlib.sha256(bytes.fromhex(row['hex'])).hexdigest()
            self.mutate_resource(project,corrupt)
            with self.assertRaisesRegex(AssertionError,'Changed contact instruction proof 1521'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_incomplete_or_prototype_helper_domain_cannot_be_released(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,lambda d:d.update(helper_proof_complete=False))
            with self.assertRaisesRegex(AssertionError,'helper proof domain is incomplete'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_original_landing_speed_gear_alignment_thresholds_are_pinned(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,lambda d:d['constants'].update(landing_speed_l1_limit_raw_s32=6000))
            with self.assertRaisesRegex(AssertionError,'original landing/damage thresholds changed'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_jjffe_sphere_fix_and_pair_rewrite_cannot_be_claimed_live(self):
        for key in ['F577_included_in_runtime','F578_included_in_runtime']:
            with self.subTest(key=key),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);self.mutate_resource(project,lambda d:d['source_variants'].update({key:True}))
                with self.assertRaisesRegex(AssertionError,'must not claim full/excluded classifiers'):
                    verifier.verify_surface_contact_runtime(self.archive,project)

    def test_phone_provider_cannot_claim_original_classification_and_frames(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,lambda d:d['caller_policies'].update(source_classifier_integrated=True))
            with self.assertRaisesRegex(AssertionError,'provider must remain an explicit adapter'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_original_ship_descriptor_and_specification_cannot_use_visual_fallback(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,lambda d:d['ship_models']['38'].update(descriptor_hex='00'*68))
            with self.assertRaisesRegex(AssertionError,'ship descriptor differs from original 38'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_old_provider_source_cannot_change_behind_pinned_bridge(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'scripts/source_surface_render_state.gd';path.write_bytes(path.read_bytes()+b'\n# altered physical triangles\n')
            with self.assertRaisesRegex(AssertionError,'protected source/data scripts/source_surface_render_state.gd'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_shared_original_math_cannot_change_behind_new_kernel(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'scripts/source_ground_surface.gd';path.write_bytes(path.read_bytes()+b'\n# altered original normalization\n')
            with self.assertRaisesRegex(AssertionError,'protected source/data scripts/source_ground_surface.gd'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_main_contact_resolution_must_consume_physical_gear_word(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'main','_apply_pending_source_contact','get("position_u16",0)','get("requested_down",false)')
            with self.assertRaisesRegex(AssertionError,'bridge and physical gear word'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_candidate_pose_must_validate_before_hp_mutation(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'main','_apply_pending_source_contact','resolution.attitude.is_finite()','true')
            with self.assertRaisesRegex(AssertionError,'candidate pose must validate'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_source_damage_requests_cannot_be_replaced_with_empty_list(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'main','_apply_pending_source_contact','nav.apply_contact_damage(resolution.get("damage_calls",[]),ship)','nav.apply_contact_damage([],ship)')
            with self.assertRaisesRegex(AssertionError,'shared HP and pose consumers'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_pose_commit_must_not_apply_a_second_percent_penalty(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'surface_model','finish_source_contact','\n','\n\tship.hull=maxf(0,ship.hull-10)\n')
            with self.assertRaisesRegex(AssertionError,'second percent-based impact law'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_contact_f953_calls_must_use_existing_saved_hp_rng(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'source_hyperdrive_session','apply_contact_damage','candidate._apply_damage_call(call)','candidate._apply_damage_call({"amount_s32":0,"attacker_u32":0})')
            with self.assertRaisesRegex(AssertionError,'existing authoritative F953 HP/RNG owner'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_saved_thermal_fraction_and_inventory_validation_stay_exact(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'source_hyperdrive_session','_valid_thermal','_fraction(thermal_system.phase_f64_hex)','0.0')
            with self.assertRaisesRegex(AssertionError,'persisted fuel/thermal/quote function'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_unresolved_contact_cannot_be_saved_before_pose_and_hp_finish(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'main','_payload','not surface.pending_source_contact().is_empty():return {}','false:return {}')
            with self.assertRaisesRegex(AssertionError,'half-applied impact'):
                verifier.verify_surface_contact_runtime(self.archive,project)

        # The same unresolved-contact flow must retain its recovery menu.
        # This is another rejection control inside the existing35-case suite.
        for method,before,after in [
            ('_update_flight_controls','if button!=flight_console.buttons.menu:button.input_allowed=false','if true:button.input_allowed=false'),
            ('_source_contact_failed','\t\t_release_inputs()','\t_release_inputs()'),
            ('_begin_graphics_demo','\tif not surface.pending_source_contact().is_empty():_paused_command();return\n','')]:
            with self.subTest(recovery_menu=method),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory)
                self.mutate_function(project,'main',method,before,after)
                with self.assertRaisesRegex(AssertionError,'audited integration source scripts/main.gd'):
                    verifier.verify_surface_contact_runtime(self.archive,project)

    def test_contact_event_must_be_cleared_after_exactly_one_pose_application(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'surface_model','finish_source_contact','_pending_source_contact.clear()','pass')
            with self.assertRaisesRegex(AssertionError,'duplicate contact requests'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_preimpact_nozzle_capture_cannot_follow_native_pose_rotation(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'main','_tick','fuel_commands=FuelFlightBridge.commands(ship,dt)','fuel_commands=[0,0,0]')
            with self.assertRaisesRegex(AssertionError,'capture fired nozzles before native pose rotation'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_failed_contact_retry_must_complete_its_saved_interval_commands(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'main','_tick','_finish_flight_interval(float(interval.seconds),interval.commands,save_after)','_finish_flight_interval(0.0,[0,0,0],save_after)')
            with self.assertRaisesRegex(AssertionError,'existing interval exactly once'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_arrival_save_must_follow_thermal_fuel_debit(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'main','_finish_flight_interval','_step_source_fuel(dt,fuel_commands)','pass')
            with self.assertRaisesRegex(AssertionError,'debit source fuel before arrival autosave'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_published_city_floor_cannot_bypass_the_common_response(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'surface_model','_clip_source_city','_queue_source_contact(ship,"city_floor",hit)','_queue_source_contact(ship,"manual",hit)')
            with self.assertRaisesRegex(AssertionError,'common source contact path'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_bridge_cannot_replace_bounded_kernel_with_a_phone_impact_formula(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'source_surface_contact_bridge','resolve','Core.resolve_player(body,parent,context)','{}')
            with self.assertRaisesRegex(AssertionError,'bypasses bounded source continuation'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_native_planet_height_must_not_be_rounded_to_float32_before_mapping(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'source_surface_contact_bridge','to_bodyfixed_point','var up:=radius+float(value.y)','var up:=float(Vector3(0,radius+value.y,0).y)')
            with self.assertRaisesRegex(AssertionError,'preserve small local height'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_actual_bounded_native_fixture_cannot_be_replaced_with_self_reported_case_count(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'tests/fixtures/source_surface_contact_native.json';d=json.loads(path.read_text());d['case_count']=1;path.write_text(json.dumps(d))
            with self.assertRaisesRegex(AssertionError,'Changed surface-contact native reference'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_retained_native_fuel_atmosphere_gear_controls_remain_required(self):
        for name in [*verifier.FUEL_NATIVE_REFERENCE,*verifier.ATMOSPHERE_NATIVE_REFERENCE,'source_landing_gear_native']:
            with self.subTest(name=name),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/'tests/fixtures'/f'{name}.json';path.write_bytes(path.read_bytes()+b' ')
                with self.assertRaisesRegex(AssertionError,'Changed (fuel|atmospheric|landing-gear) native reference'):
                    verifier.verify_surface_contact_runtime(self.archive,project)

    def test_pending_contact_speed_guard_cannot_hide_other_physical_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'main','_set_speed','\n','\n\tship.hull=100\n')
            with self.assertRaisesRegex(AssertionError,'undeclared physical Main function _set_speed'):
                verifier.verify_surface_contact_runtime(self.archive,project)

    def test_world_motion_must_not_change_behind_contact_block(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'scripts/planetary_system.gd';path.write_bytes(path.read_bytes()+b'\n# undeclared orbital change\n')
            with self.assertRaisesRegex(AssertionError,'protected source/data scripts/planetary_system.gd'):
                verifier.verify_surface_contact_runtime(self.archive,project)


if __name__=='__main__':unittest.main()
