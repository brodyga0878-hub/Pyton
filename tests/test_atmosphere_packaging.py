"""Strict code42 rejection paths using explicit mock bytes, never an APK/oracle."""
import importlib.util
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

PROJECT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('atmosphere_android_verifier',PROJECT/'tools/verify_rebuilt_android.py')
verifier=importlib.util.module_from_spec(spec);spec.loader.exec_module(verifier)


class MockAtmosphereArchive:
    def __init__(self):
        names={Path(name).stem for name in verifier.ATMOSPHERE_AUDITED_SOURCE_SHA256}
        names.update(verifier.SYSTEM_INFORMATION_MODULES)
        self.entries={f'assets/scripts/{name}.gdc':b'GDSC'+b'explicit-unit-mock-not-an-APK'*5 for name in names}
        self.entries.update({f'assets/data/{name}.json':(PROJECT/'data'/f'{name}.json').read_bytes()
                             for name in ('ffe_atmosphere','ffe_fuel','ffe_hyperdrive',*verifier.SYSTEM_INFORMATION_TABLES)})
    def namelist(self):return list(self.entries)
    def read(self,name):return self.entries[name]


class AtmospherePackaging(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        directory=tempfile.TemporaryDirectory(prefix='landing-gear-packaging-v42-')
        cls.addClassCleanup(directory.cleanup);cls.project=Path(directory.name)
        for relative in cls.project_files():
            target=cls.project/relative;target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes((PROJECT/relative).read_bytes())
        path=PROJECT/'tests/fixtures/landing_gear_v42_sources.json'
        if hashlib.sha256(path.read_bytes()).hexdigest()!='df26c2952f08c837f074d4d9ccf44731e84a61e7f9258d84f34126ddc5ffb894':
            raise AssertionError('Historical code42 landing-gear baseline fixture changed')
        baseline=json.loads(path.read_text());expected=verifier.ATMOSPHERE_AUDITED_SOURCE_SHA256
        if baseline['source_commit']!='0ad404f25db0b54d42796457555c8e4dc7f2ad6d' or set(baseline['files'])!=set(expected):
            raise AssertionError('Historical code42 source fixture domain changed')
        for name,digest in expected.items():
            entry=baseline['files'][name];raw=entry['source'].encode()
            if entry['sha256']!=digest or hashlib.sha256(raw).hexdigest()!=digest:
                raise AssertionError('Historical code42 source differs '+name)
            (cls.project/name).write_bytes(raw)

        # Future renderer opt-ins must not redefine these historical contracts.
        alignment=verifier._load_contact_alignment_baseline(PROJECT)
        for relative in verifier.CONTACT_ALIGNMENT_PROVIDER_SOURCE_SHA256:
            target=cls.project/relative
            if target.exists():target.write_text(alignment['files'][relative]['source'])

    def setUp(self):self.archive=MockAtmosphereArchive()

    @staticmethod
    def project_files():
        files=set(verifier.MAP_VISUAL_PROTECTED_SOURCE_SHA256)
        files.update(verifier.ATMOSPHERE_AUDITED_SOURCE_SHA256)
        files.update(verifier.FUEL_CONTACT_DEPENDENCY_SHA256)
        files.update(verifier.HYPERDRIVE_INFORMATION_SOURCE_SHA256)
        files.update(['scripts/celestial_renderer.gd','scripts/system_map_view.gd',
                      'data/ffe_atmosphere.json','data/ffe_fuel.json','data/ffe_hyperdrive.json',
                      'tests/fixtures/source_hyperdrive_native.json'])
        files.update(f'data/{name}.json'for name in verifier.SYSTEM_INFORMATION_TABLES)
        files.update(f'tests/fixtures/{name}.json'for name in (*verifier.FUEL_NATIVE_REFERENCE,*verifier.ATMOSPHERE_NATIVE_REFERENCE))
        return files

    def project_copy(self,directory):
        project=Path(directory)
        for relative in self.project_files():
            path=project/relative;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes((self.project/relative).read_bytes())
        return project

    def mutate_resource(self,project,name,callback):
        path=project/'data'/f'{name}.json';data=json.loads(path.read_text());callback(data)
        raw=json.dumps(data,ensure_ascii=False).encode();path.write_bytes(raw);self.archive.entries[f'assets/data/{name}.json']=raw

    def mutate_function(self,project,module,name,old,new):
        path=project/'scripts'/f'{module}.gd';raw=path.read_text();function=verifier.source_function(raw,name)
        self.assertIn(old,function);path.write_text(raw.replace(function,function.replace(old,new,1),1))

    def test_frozen_scope_and_honest_evidence_boundaries(self):
        result=verifier.verify_atmosphere_runtime(self.archive,self.project)
        self.assertEqual(result['baseline_source_commit'],'450e862ac3c146994371d8fa427efbc65b9fc677')
        self.assertEqual((result['compiled_module_count'],result['integration_compiled_module_count'],result['raw_json_count']),(2,17,1))
        self.assertEqual((result['original_procedure_count'],result['original_procedure_bytes']),(8,920))
        self.assertEqual((result['protected_old_source_data_count'],result['protected_contact_dependency_count'],result['unchanged_Main_function_count']),(10,16,14))
        self.assertEqual(len(result['audited_local_source_sha256']),17)
        self.assertEqual(result['unchanged_fuel_resource_sha256'],verifier.FUEL_RESOURCE_SHA256)
        self.assertEqual(result['unchanged_hyperdrive_resource_sha256'],verifier.HYPERDRIVE_RESOURCE_SHA256)
        self.assertEqual({k:v['case_count']for k,v in result['native_references'].items()},
                         {'source_atmospheric_native':1447,'source_atmosphere_speed_native':239})
        self.assertEqual(result['phone_invocation_rate_hz'],60)
        for key in ['phone_rate_is_original','full_original_reference_frame_pipeline','full_original_global_event_rng_stream',
                    'full_original_equipment_damage_dispatcher','full_original_destruction_dispatcher',
                    'full_F569_player_collision_integrated','original_F908_arrival_pipeline','original_outfitting_economy',
                    'complete_original_time_scheduler','complete_original_physics',
                    'compiled_source_correspondence_rebuilt_by_verifier','physical_device_tested']:
            self.assertFalse(result[key],key)
        self.assertTrue(all(not row['oracle_executed_by_apk_verifier']for row in result['native_references'].values()))

    def test_every_compiled_integration_module_is_required(self):
        for relative in verifier.ATMOSPHERE_AUDITED_SOURCE_SHA256:
            name=Path(relative).stem
            with self.subTest(name=name):
                archive=MockAtmosphereArchive();del archive.entries[f'assets/scripts/{name}.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing (atmospheric|fuel|hyperdrive)'):
                    verifier.verify_atmosphere_runtime(archive,self.project)

    def test_every_integration_module_header_and_length_is_checked(self):
        for relative in verifier.ATMOSPHERE_AUDITED_SOURCE_SHA256:
            name=Path(relative).stem
            for content in [b'BAD!'+b'x'*100,b'GDSC'+b'x'*60]:
                with self.subTest(name=name,bytes=len(content)):
                    archive=MockAtmosphereArchive();archive.entries[f'assets/scripts/{name}.gdc']=content
                    with self.assertRaisesRegex(AssertionError,'Invalid compiled'):
                        verifier.verify_atmosphere_runtime(archive,self.project)

    def test_all_retained_information_modules_remain_required(self):
        for name in verifier.SYSTEM_INFORMATION_MODULES:
            with self.subTest(name=name):
                archive=MockAtmosphereArchive();del archive.entries[f'assets/scripts/{name}.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing system information runtime'):
                    verifier.verify_atmosphere_runtime(archive,self.project)

    def test_missing_or_different_exported_atmosphere_resource_rejects(self):
        del self.archive.entries['assets/data/ffe_atmosphere.json']
        with self.assertRaisesRegex(AssertionError,'Missing atmosphere resource'):
            verifier.verify_atmosphere_runtime(self.archive,self.project)
        self.archive=MockAtmosphereArchive();self.archive.entries['assets/data/ffe_atmosphere.json']+=b' '
        with self.assertRaisesRegex(AssertionError,'Atmosphere resource differs from local source'):
            verifier.verify_atmosphere_runtime(self.archive,self.project)

    def test_retained_fuel_hyperdrive_information_payloads_stay_checked(self):
        for name in ('ffe_fuel','ffe_hyperdrive',*verifier.SYSTEM_INFORMATION_TABLES):
            with self.subTest(name=name):
                archive=MockAtmosphereArchive();archive.entries[f'assets/data/{name}.json']+=b' '
                with self.assertRaises(AssertionError):verifier.verify_atmosphere_runtime(archive,self.project)

    def test_wrong_executable_provenance_rejects_even_with_matching_export(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,'ffe_atmosphere',lambda d:d.update(source_sha256='0'*64))
            with self.assertRaisesRegex(AssertionError,'Wrong atmosphere source provenance'):
                verifier.verify_atmosphere_runtime(self.archive,project)

    def test_each_original_procedure_anchor_is_pinned(self):
        for label in verifier.ATMOSPHERE_DOS_PROCEDURES:
            with self.subTest(label=label),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);self.mutate_resource(project,'ffe_atmosphere',lambda d:d['procedures'][label].update(dos_file_offset=0))
                with self.assertRaisesRegex(AssertionError,'Changed atmosphere DOS anchor '+label):
                    verifier.verify_atmosphere_runtime(self.archive,project)

    def test_original_dos_bytes_cannot_use_a_self_reported_hash(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            def corrupt(d):
                row=d['procedures']['1014'];row['hex']='00'+row['hex'][2:];row['sha256']=hashlib.sha256(bytes.fromhex(row['hex'])).hexdigest()
            self.mutate_resource(project,'ffe_atmosphere',corrupt)
            with self.assertRaisesRegex(AssertionError,'Changed atmosphere DOS anchor 1014'):
                verifier.verify_atmosphere_runtime(self.archive,project)

    def test_modified_jjffe_heat_cannot_be_marked_original_dos(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,'ffe_atmosphere',lambda d:d['procedures']['1014'].update(pinned_jjffe_instructions_match_dos=True))
            with self.assertRaisesRegex(AssertionError,'DOS/JJFFE distinction 1014'):
                verifier.verify_atmosphere_runtime(self.archive,project)

    def test_dos_heat_cannot_be_replaced_with_step_scaled_jjffe_formula(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,'ffe_atmosphere',lambda d:d['source_variants']['F1014_DOS'].update(heat_step_multiplication=True))
            with self.assertRaisesRegex(AssertionError,'canonical DOS heat/drag policy'):
                verifier.verify_atmosphere_runtime(self.archive,project)

    def test_sixty_hz_cannot_be_claimed_as_original_player_scheduler(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,'ffe_atmosphere',lambda d:d['caller_policies'].update(phone_rate_is_original=True))
            with self.assertRaisesRegex(AssertionError,'cadence must remain an explicit adapter'):
                verifier.verify_atmosphere_runtime(self.archive,project)

    def test_one_heat_state_cannot_be_relocated_in_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,'ffe_atmosphere',lambda d:d['field_layout']['game'].update(heat_s32=0x1f0))
            with self.assertRaisesRegex(AssertionError,'single heat state'):
                verifier.verify_atmosphere_runtime(self.archive,project)

    def test_actual_source_hull_hp_cannot_be_substituted(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,'ffe_atmosphere',lambda d:d['ship_profiles']['eagle'].update(maximum_hull_raw_u16=400))
            with self.assertRaisesRegex(AssertionError,'Changed source atmospheric hull profile eagle'):
                verifier.verify_atmosphere_runtime(self.archive,project)

    def test_shared_solver_cannot_change_behind_new_contact_module(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'scripts/source_terrain_query.gd';path.write_bytes(path.read_bytes()+b'\n# altered shared solver\n')
            with self.assertRaisesRegex(AssertionError,'protected source/data scripts/source_terrain_query.gd'):
                verifier.verify_atmosphere_runtime(self.archive,project)

    def test_live_actual_contact_cannot_be_replaced_by_sphere_guess(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'main','_step_source_fuel','atmosphere_contact.sample(','atmosphere_contact.fake_sphere_sample(')
            with self.assertRaisesRegex(AssertionError,'actual contact/combined session consumers'):
                verifier.verify_atmosphere_runtime(self.archive,project)

    def test_raw_and_surface_drag_cannot_be_disconnected(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'main','_step_source_fuel','source_motion.apply_velocity_words(after,ship)','source_motion.skip_velocity_words(after,ship)')
            with self.assertRaisesRegex(AssertionError,'drag has no raw/SI velocity consumer'):
                verifier.verify_atmosphere_runtime(self.archive,project)

    def test_raw_drag_cannot_reset_velocity_fractions(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'source_motion_bridge','apply_velocity_words','var body:=_motion.raw_body()','var body:=_motion.raw_body();body.encode_u16(0x98,0)')
            with self.assertRaisesRegex(AssertionError,'preserve Q16 velocity fractions'):
                verifier.verify_atmosphere_runtime(self.archive,project)

    def test_arrival_save_cannot_run_before_thermal_debit(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'main','_tick','_step_source_fuel(dt,fuel_commands)','_skip_source_fuel(dt,fuel_commands)')
            with self.assertRaisesRegex(AssertionError,'advance before arrival autosave'):
                verifier.verify_atmosphere_runtime(self.archive,project)

    def test_strict_restore_must_bind_raw_hp_without_live_repair(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'main','_decode_state','candidate_nav.bind_thermal_ship(candidate_ship)','candidate_nav.sync_thermal_ship(candidate_ship)')
            with self.assertRaisesRegex(AssertionError,'bind strictly without repair'):
                verifier.verify_atmosphere_runtime(self.archive,project)

    def test_fuel_heat_cannot_be_duplicated_in_thermal_save(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'scripts/source_hyperdrive_session.gd';text=path.read_text();text=text.replace('const THERMAL_KEYS:=[','const THERMAL_KEYS:=["heat_s32",',1);path.write_text(text)
            with self.assertRaisesRegex(AssertionError,'duplicate heat state'):
                verifier.verify_atmosphere_runtime(self.archive,project)

    def test_saved_thermal_phase_and_digest_validation_cannot_be_skipped(self):
        for old,new in [('thermal_system.source_digest!=_thermal_digest()','false'),('_fraction(thermal_system.phase_f64_hex)','0.0')]:
            with self.subTest(old=old),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);self.mutate_function(project,'source_hyperdrive_session','_valid_thermal',old,new)
                with self.assertRaisesRegex(AssertionError,'resource/fraction validation'):
                    verifier.verify_atmosphere_runtime(self.archive,project)

    def test_saved_hp_anchor_and_rng_validation_cannot_be_skipped(self):
        for old,new in [('"rng_seed_a_u32","rng_seed_b_u32"','"rng_seed_a_ignored","rng_seed_b_u32"'),('full_hull_raw()*anchor/100.0','full_hull_raw()')]:
            with self.subTest(old=old),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);self.mutate_function(project,'source_hyperdrive_session','_valid_thermal',old,new)
                with self.assertRaisesRegex(AssertionError,'raw HP/RNG validation'):
                    verifier.verify_atmosphere_runtime(self.archive,project)

    def test_atmospheric_time_acceleration_safety_cannot_be_disconnected(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'main','_time_context','result.atmospheric_hazard=','result.atmospheric_hazard_ignored=')
            with self.assertRaisesRegex(AssertionError,'time acceleration safety is disconnected'):
                verifier.verify_atmosphere_runtime(self.archive,project)

    def test_original_orbit_selection_remains_exact(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'main','_choose_body','\n','\n\tship.position=Vector3.ZERO\n')
            with self.assertRaisesRegex(AssertionError,'undeclared physical Main function _choose_body'):
                verifier.verify_atmosphere_runtime(self.archive,project)

    def test_each_new_native_reference_is_frozen_without_reexecuting_oracle(self):
        for name in verifier.ATMOSPHERE_NATIVE_REFERENCE:
            with self.subTest(name=name),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/'tests/fixtures'/f'{name}.json';data=json.loads(path.read_text());data['case_count']=1;path.write_text(json.dumps(data))
                with self.assertRaisesRegex(AssertionError,'Changed atmospheric native reference '+name):
                    verifier.verify_atmosphere_runtime(self.archive,project)

    def test_retained_fuel_native_references_still_reject_mutation(self):
        for name in verifier.FUEL_NATIVE_REFERENCE:
            with self.subTest(name=name),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/'tests/fixtures'/f'{name}.json';path.write_bytes(path.read_bytes()+b' ')
                with self.assertRaisesRegex(AssertionError,'Changed fuel native reference '+name):
                    verifier.verify_atmosphere_runtime(self.archive,project)


if __name__=='__main__':unittest.main()
