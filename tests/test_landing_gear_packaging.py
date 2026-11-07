"""Strict code43 rejection controls; explicit mock bytes, not an exported APK."""
import importlib.util
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

PROJECT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('landing_gear_android_verifier',PROJECT/'tools/verify_rebuilt_android.py')
verifier=importlib.util.module_from_spec(spec);spec.loader.exec_module(verifier)


class MockLandingGearArchive:
    def __init__(self):
        names={Path(name).stem for name in verifier.LANDING_GEAR_AUDITED_SOURCE_SHA256}
        names.update(verifier.SYSTEM_INFORMATION_MODULES)
        self.entries={f'assets/scripts/{name}.gdc':b'GDSC'+b'explicit-unit-mock-not-an-APK'*5 for name in names}
        self.entries.update({f'assets/data/{name}.json':(PROJECT/'data'/f'{name}.json').read_bytes()
                             for name in ('ffe_landing_gear','ffe_atmosphere','ffe_fuel','ffe_hyperdrive',*verifier.SYSTEM_INFORMATION_TABLES)})
    def namelist(self):return list(self.entries)
    def read(self,name):return self.entries[name]


class LandingGearPackaging(unittest.TestCase):
    def setUp(self):self.archive=MockLandingGearArchive()

    @staticmethod
    def project_files():
        files=set(verifier.MAP_VISUAL_PROTECTED_SOURCE_SHA256)
        files.update(verifier.LANDING_GEAR_AUDITED_SOURCE_SHA256)
        files.update(verifier.FUEL_CONTACT_DEPENDENCY_SHA256)
        files.update(verifier.HYPERDRIVE_INFORMATION_SOURCE_SHA256)
        files.update(['scripts/celestial_renderer.gd','scripts/system_map_view.gd',
                      'data/ffe_landing_gear.json','data/ffe_atmosphere.json','data/ffe_fuel.json','data/ffe_hyperdrive.json',
                      'tests/fixtures/source_hyperdrive_native.json','tests/fixtures/source_landing_gear_native.json'])
        files.update(f'data/{name}.json'for name in verifier.SYSTEM_INFORMATION_TABLES)
        files.update(f'tests/fixtures/{name}.json'for name in (*verifier.FUEL_NATIVE_REFERENCE,*verifier.ATMOSPHERE_NATIVE_REFERENCE))
        return files

    def project_copy(self,directory):
        project=Path(directory)
        for relative in self.project_files():
            path=project/relative;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes((PROJECT/relative).read_bytes())
        return project

    def mutate_resource(self,project,callback):
        path=project/'data/ffe_landing_gear.json';data=json.loads(path.read_text());callback(data)
        raw=json.dumps(data,ensure_ascii=False).encode();path.write_bytes(raw);self.archive.entries['assets/data/ffe_landing_gear.json']=raw

    def mutate_function(self,project,module,name,old,new):
        path=project/'scripts'/f'{module}.gd';raw=path.read_text();function=verifier.source_function(raw,name)
        self.assertIn(old,function);path.write_text(raw.replace(function,function.replace(old,new,1),1))

    def test_frozen_scope_retains_old_data_and_honest_partial_boundaries(self):
        result=verifier.verify_landing_gear_runtime(self.archive,PROJECT)
        self.assertEqual(result['baseline_source_commit'],'0ad404f25db0b54d42796457555c8e4dc7f2ad6d')
        self.assertEqual((result['compiled_module_count'],result['integration_compiled_module_count'],result['raw_json_count']),(2,21,1))
        self.assertEqual((result['original_primary_anchors'],result['original_primary_anchor_bytes'],result['original_primary_instruction_count']),(2,421,104))
        self.assertEqual((result['supporting_anchor_slices'],result['supporting_anchor_bytes'],result['supporting_instruction_count']),(2,53,14))
        self.assertEqual((result['protected_old_source_data_count'],result['protected_contact_dependency_count'],result['unchanged_code42_source_count']),(10,16,14))
        self.assertEqual((result['unchanged_Main_function_count'],result['unchanged_Surface_function_count']),(11,9))
        self.assertEqual(len(result['audited_local_source_sha256']),21)
        self.assertEqual(result['native_reference']['case_count'],2812)
        self.assertFalse(result['native_reference']['oracle_executed_by_apk_verifier'])
        for key in ['phone_rate_is_original','whole_original_F1056_dispatcher','full_original_player_scheduler',
                    'full_original_autopilot_phase_mapping','full_F575_contact_response','full_original_GUI_audio_callbacks',
                    'micrometeorite_damage_integrated_by_this_block','complete_original_physics',
                    'compiled_source_correspondence_rebuilt_by_verifier','physical_device_tested']:
            self.assertFalse(result[key],key)
        self.assertEqual(result['unchanged_atmosphere_resource_sha256'],verifier.ATMOSPHERE_RESOURCE_SHA256)

    def test_each_integration_module_is_required(self):
        for relative in verifier.LANDING_GEAR_AUDITED_SOURCE_SHA256:
            name=Path(relative).stem
            with self.subTest(name=name):
                archive=MockLandingGearArchive();del archive.entries[f'assets/scripts/{name}.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing (atmospheric|landing-gear|fuel|hyperdrive)'):
                    verifier.verify_landing_gear_runtime(archive,PROJECT)

    def test_each_integration_module_header_and_length_is_checked(self):
        for relative in verifier.LANDING_GEAR_AUDITED_SOURCE_SHA256:
            name=Path(relative).stem
            for content in [b'BAD!'+b'x'*100,b'GDSC'+b'x'*60]:
                with self.subTest(name=name,bytes=len(content)):
                    archive=MockLandingGearArchive();archive.entries[f'assets/scripts/{name}.gdc']=content
                    with self.assertRaisesRegex(AssertionError,'Invalid compiled'):
                        verifier.verify_landing_gear_runtime(archive,PROJECT)

    def test_retained_information_modules_still_required(self):
        for name in verifier.SYSTEM_INFORMATION_MODULES:
            with self.subTest(name=name):
                archive=MockLandingGearArchive();del archive.entries[f'assets/scripts/{name}.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing system information runtime'):
                    verifier.verify_landing_gear_runtime(archive,PROJECT)

    def test_missing_or_different_exported_gear_resource_rejects(self):
        del self.archive.entries['assets/data/ffe_landing_gear.json']
        with self.assertRaisesRegex(AssertionError,'Missing landing-gear resource'):
            verifier.verify_landing_gear_runtime(self.archive,PROJECT)
        self.archive=MockLandingGearArchive();self.archive.entries['assets/data/ffe_landing_gear.json']+=b' '
        with self.assertRaisesRegex(AssertionError,'Landing-gear resource differs from local source'):
            verifier.verify_landing_gear_runtime(self.archive,PROJECT)

    def test_old_fuel_atmosphere_hyperdrive_and_information_payloads_stay_checked(self):
        for name in ('ffe_atmosphere','ffe_fuel','ffe_hyperdrive',*verifier.SYSTEM_INFORMATION_TABLES):
            with self.subTest(name=name):
                archive=MockLandingGearArchive();archive.entries[f'assets/data/{name}.json']+=b' '
                with self.assertRaises(AssertionError):verifier.verify_landing_gear_runtime(archive,PROJECT)

    def test_matching_export_cannot_use_wrong_original_provenance(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,lambda d:d.update(source_sha256='0'*64))
            with self.assertRaisesRegex(AssertionError,'Wrong landing-gear source provenance'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_original_instruction_bytes_cannot_use_self_reported_hash(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            def corrupt(data):
                row=data['procedures']['1008'];row['hex']='00'+row['hex'][2:];row['sha256']=hashlib.sha256(bytes.fromhex(row['hex'])).hexdigest()
            self.mutate_resource(project,corrupt)
            with self.assertRaisesRegex(AssertionError,'Changed landing-gear DOS anchor 1008'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_polarity_cannot_be_flipped_to_requested_down_equals_set_bit(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,lambda d:d['constants'].update(position_fully_deployed_u16=0))
            with self.assertRaisesRegex(AssertionError,'request/position polarity reversed'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_auto_phase_thirty_and_blocked_phase_thirty_six_are_distinct(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,lambda d:d['constants'].update(auto_retract_phase_maximum_u8=36))
            with self.assertRaisesRegex(AssertionError,'automatic/toggle phases conflated'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_original_signed_warning_threshold_cannot_be_replaced(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,lambda d:d['constants'].update(deployment_warning_speed_raw_s32=9000))
            with self.assertRaisesRegex(AssertionError,'original warning altered'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_sixty_hz_and_selected_branch_cannot_claim_full_original_dispatcher(self):
        for part,key,value,message in [('caller_policies','phone_rate_is_original',True,'explicit adapter'),
                                       ('source_variants','whole_F1056_DOS_equivalence_proved',True,'full F1056 equivalence')]:
            with self.subTest(key=key),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);self.mutate_resource(project,lambda d:d[part].update({key:value}))
                with self.assertRaisesRegex(AssertionError,message):verifier.verify_landing_gear_runtime(self.archive,project)

    def test_object_timer_and_game_flight_state_cannot_be_conflated(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,lambda d:d['field_layout']['object'].update(unrelated_timer_u16=0xe9))
            with self.assertRaisesRegex(AssertionError,'timer/flight state/position fields conflated'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_native_reference_is_frozen_without_reexecuting_oracle(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'tests/fixtures/source_landing_gear_native.json';data=json.loads(path.read_text());data['case_count']=1;path.write_text(json.dumps(data))
            with self.assertRaisesRegex(AssertionError,'Changed landing-gear native reference'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_every_retained_atmospheric_native_reference_still_rejects_mutation(self):
        for name in verifier.ATMOSPHERE_NATIVE_REFERENCE:
            with self.subTest(name=name),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/'tests/fixtures'/f'{name}.json';path.write_bytes(path.read_bytes()+b' ')
                with self.assertRaisesRegex(AssertionError,'Changed atmospheric native reference '+name):
                    verifier.verify_landing_gear_runtime(self.archive,project)

    def test_thermal_consumer_must_use_raw_retract_bit_not_deployed_boolean(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'main','_step_source_fuel','get("f1014_raw_gear_flag",false)','get("deployed",false)')
            with self.assertRaisesRegex(AssertionError,'raw retract request bit, not physical deployed state'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_selected_original_toggle_must_not_instantly_teleport_physical_gear(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'source_landing_gear','toggle','state.control_flags_u8=','state.position_u16=65535\n\tstate.control_flags_u8=')
            with self.assertRaisesRegex(AssertionError,'audited integration source scripts/source_landing_gear.gd'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_gear_resource_digest_restore_validation_cannot_be_skipped(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'source_landing_gear_session','_valid','data.source_digest!=_digest()','false')
            with self.assertRaisesRegex(AssertionError,'resource/fraction/remainder validation'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_gear_fraction_restore_validation_cannot_be_skipped(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'source_landing_gear_session','_valid','_phase(data.phase_f64_hex)','0.0')
            with self.assertRaisesRegex(AssertionError,'resource/fraction/remainder validation'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_gear_save_cannot_duplicate_thermal_state(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'scripts/source_landing_gear_session.gd';text=path.read_text().replace('const KEYS:=[','const KEYS:=["heat_s32",',1);path.write_text(text)
            with self.assertRaisesRegex(AssertionError,'duplicate fuel/heat/cargo/raw HP'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_command_cannot_bypass_original_bounded_toggle_branch(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'source_landing_gear_session','command_toggle','Kernel.toggle(_kernel_state(context))','Kernel.fake_toggle(_kernel_state(context))')
            with self.assertRaisesRegex(AssertionError,'bypasses original bounded F1056 branch'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_live_animation_cannot_disconnect_from_main_tick(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'main','_tick','_step_landing_gear(dt)','_skip_landing_gear(dt)')
            with self.assertRaisesRegex(AssertionError,'advance source gear before thermal fuel'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_console_gear_signal_cannot_be_disconnected(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'main','_build_ui','flight_console.gear_requested.connect(_toggle_landing_gear)','flight_console.gear_requested.connect(_toggle_auto)')
            with self.assertRaisesRegex(AssertionError,'Console gear command lacks'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_physical_surface_readiness_cannot_be_replaced_with_true(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'main','_apply_landing_gear_state','current.get("deployed",true)','true')
            with self.assertRaisesRegex(AssertionError,'actual surface/visual/legacy consumers'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_soft_touchdown_cannot_ignore_incomplete_physical_gear(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'surface_model','touch_down','_gear_blocks_touchdown()','false')
            with self.assertRaisesRegex(AssertionError,'touchdown paths ignore incomplete physical gear'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_underground_contact_cannot_lose_gear_readiness(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'surface_model','step','landed and not _gear_blocks_touchdown()','landed')
            with self.assertRaisesRegex(AssertionError,'underground contact lost gear readiness'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_source_visual_must_not_add_a_second_wall_clock_animation(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'ship_visual','_process','if not _source_gear_driven:','if true:')
            with self.assertRaisesRegex(AssertionError,'without a second animation clock'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_strict_restore_cannot_replace_saved_gear_with_fresh_defaults(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'main','_decode_state','candidate_gear.restore(data.gear_session)','candidate_gear.configure(candidate_surface.landed or candidate_ship.docked)')
            with self.assertRaisesRegex(AssertionError,'strict restore and explicit previous-save initialization'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_landed_restore_cannot_skip_physical_gear_validation(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'main','_decode_state','if candidate_surface.landed and (','if false and (')
            with self.assertRaisesRegex(AssertionError,'Landed restore must validate'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_hyperdrive_state_cannot_be_mutated_behind_independent_sibling(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'scripts/source_hyperdrive_session.gd';path.write_bytes(path.read_bytes()+b'\n# undeclared fuel/state change\n')
            with self.assertRaisesRegex(AssertionError,'protected source/data scripts/source_hyperdrive_session.gd'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_world_orbits_cannot_change_behind_gear_block(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'scripts/planetary_system.gd';path.write_bytes(path.read_bytes()+b'\n# undeclared orbital change\n')
            with self.assertRaisesRegex(AssertionError,'protected source/data scripts/planetary_system.gd'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_original_ascent_takeoff_function_remains_exact(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'surface_model','take_off','\n','\n\tship.hull=100\n')
            with self.assertRaisesRegex(AssertionError,'undeclared physical Surface function take_off'):
                verifier.verify_landing_gear_runtime(self.archive,project)

    def test_contact_comment_correction_cannot_conceal_geometry_math_change(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'source_atmosphere_contact','sample','result.altitude_s32=','result.altitude_s32=1+')
            with self.assertRaisesRegex(AssertionError,'description correction changed atmospheric geometry/math'):
                verifier.verify_landing_gear_runtime(self.archive,project)


if __name__=='__main__':unittest.main()
