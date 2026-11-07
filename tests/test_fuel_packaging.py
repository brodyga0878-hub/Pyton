"""Strict code41 package negative controls with an explicit mock, not an APK."""
import importlib.util
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

PROJECT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('fuel_android_verifier',PROJECT/'tools/verify_rebuilt_android.py')
verifier=importlib.util.module_from_spec(spec);spec.loader.exec_module(verifier)


class MockFuelArchive:
    def __init__(self):
        self.entries={f'assets/scripts/{name}.gdc':b'GDSC'+b'explicit-unit-mock-not-an-APK'*5
                      for name in (*verifier.FUEL_MODULES,*verifier.HYPERDRIVE_MODULES,*verifier.SYSTEM_INFORMATION_MODULES)}
        self.entries.update({f'assets/data/{name}.json':(PROJECT/'data'/f'{name}.json').read_bytes()
                             for name in ('ffe_fuel','ffe_hyperdrive',*verifier.SYSTEM_INFORMATION_TABLES)})
    def namelist(self):return list(self.entries)
    def read(self,name):return self.entries[name]


class FuelPackaging(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        directory=tempfile.TemporaryDirectory(prefix='fuel-packaging-v41-')
        cls.addClassCleanup(directory.cleanup);cls.project=Path(directory.name)
        for relative in cls.project_files():
            target=cls.project/relative;target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes((PROJECT/relative).read_bytes())
        path=PROJECT/'tests/fixtures/thermal_v41_sources.json'
        if hashlib.sha256(path.read_bytes()).hexdigest()!='4fd5e42c88d9a11c911ac01ca04f41dc5fe1a42624fa99c7774cb145e7382790':
            raise AssertionError('Historical code41 thermal baseline fixture changed')
        baseline=json.loads(path.read_text())
        expected={**verifier.FUEL_AUDITED_SOURCE_SHA256,
                  **{name:verifier.MAP_VISUAL_PROTECTED_SOURCE_SHA256[name] for name in
                     ['scripts/planetary_system.gd','scripts/flight_time_controller.gd']}}
        if baseline['source_commit']!='450e862ac3c146994371d8fa427efbc65b9fc677' or set(baseline['files'])!=set(expected):
            raise AssertionError('Historical code41 source fixture domain changed')
        for name,digest in expected.items():
            entry=baseline['files'][name];raw=entry['source'].encode()
            if entry['sha256']!=digest or hashlib.sha256(raw).hexdigest()!=digest:
                raise AssertionError('Historical code41 source differs '+name)
            (cls.project/name).write_bytes(raw)

    def setUp(self):self.archive=MockFuelArchive()

    @staticmethod
    def project_files():
        files=set(verifier.MAP_VISUAL_PROTECTED_SOURCE_SHA256)
        files.update(verifier.FUEL_AUDITED_SOURCE_SHA256)
        files.update(verifier.FUEL_CONTACT_DEPENDENCY_SHA256)
        files.update(verifier.HYPERDRIVE_INFORMATION_SOURCE_SHA256)
        files.update(['scripts/celestial_renderer.gd','scripts/galactic_map_view.gd',
                      'data/ffe_fuel.json','data/ffe_hyperdrive.json','tests/fixtures/source_hyperdrive_native.json'])
        files.update(f'data/{name}.json' for name in verifier.SYSTEM_INFORMATION_TABLES)
        files.update(f'tests/fixtures/{name}.json'for name in verifier.FUEL_NATIVE_REFERENCE)
        return files

    def project_copy(self,directory):
        project=Path(directory)
        for relative in self.project_files():
            target=project/relative;target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes((self.project/relative).read_bytes())
        return project

    def mutate_resource(self,project,name,callback):
        path=project/'data'/f'{name}.json';data=json.loads(path.read_text());callback(data)
        raw=json.dumps(data,ensure_ascii=False).encode();path.write_bytes(raw)
        self.archive.entries[f'assets/data/{name}.json']=raw

    def mutate_function(self,project,module,name,old,new):
        path=project/'scripts'/f'{module}.gd';raw=path.read_text();function=verifier.source_function(raw,name)
        self.assertIn(old,function);changed=function.replace(old,new,1)
        path.write_text(raw.replace(function,changed,1))

    def test_historical_frozen_code41_scope_and_declared_limits(self):
        result=verifier.verify_fuel_runtime(self.archive,self.project)
        self.assertEqual(result['baseline_source_commit'],'c3872931413d5641c3b437aa2669ed444e5f8075')
        self.assertEqual((result['compiled_module_count'],result['contact_model_count'],result['raw_json_count']),(4,15,1))
        self.assertEqual(result['protected_old_source_data_count'],11)
        self.assertEqual(result['protected_contact_dependency_count'],16)
        self.assertEqual(result['unchanged_Main_function_count'],16)
        self.assertEqual(result['unchanged_hyperdrive_resource_sha256'],verifier.HYPERDRIVE_RESOURCE_SHA256)
        self.assertEqual(len(result['audited_local_source_sha256']),14)
        self.assertEqual({k:v['case_count']for k,v in result['native_references'].items()},
                         {'source_jet_fuel_native':3182,'source_fuel_scoop_native':729,'source_fuel_contact_native':330})
        for key in ['full_F938_shield_damage_loop_integrated','full_F569_player_collision_integrated',
                    'full_F1014_atmospheric_heat_integrated','original_F908_arrival_pipeline','original_outfitting_economy',
                    'complete_original_time_scheduler','complete_original_physics',
                    'compiled_source_correspondence_rebuilt_by_verifier','physical_device_tested']:
            self.assertFalse(result[key],key)
        self.assertTrue(all(not value['oracle_executed_by_apk_verifier']for value in result['native_references'].values()))

    def test_each_new_compiled_module_is_required(self):
        for name in verifier.FUEL_MODULES:
            with self.subTest(name=name):
                archive=MockFuelArchive();del archive.entries[f'assets/scripts/{name}.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing fuel runtime module'):
                    verifier.verify_fuel_runtime(archive,self.project)

    def test_each_new_compiled_module_header_is_checked(self):
        for name in verifier.FUEL_MODULES:
            with self.subTest(name=name):
                archive=MockFuelArchive();archive.entries[f'assets/scripts/{name}.gdc']=b'BAD!'+b'x'*100
                with self.assertRaisesRegex(AssertionError,'Invalid compiled fuel runtime'):
                    verifier.verify_fuel_runtime(archive,self.project)

    def test_old_hyperdrive_and_information_modules_are_still_required(self):
        for name in (*verifier.HYPERDRIVE_MODULES,*verifier.SYSTEM_INFORMATION_MODULES):
            with self.subTest(name=name):
                archive=MockFuelArchive();del archive.entries[f'assets/scripts/{name}.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing (hyperdrive|system information) runtime'):
                    verifier.verify_fuel_runtime(archive,self.project)

    def test_missing_or_different_exported_fuel_resource_is_rejected(self):
        del self.archive.entries['assets/data/ffe_fuel.json']
        with self.assertRaisesRegex(AssertionError,'Missing fuel resource'):
            verifier.verify_fuel_runtime(self.archive,self.project)
        self.archive=MockFuelArchive();self.archive.entries['assets/data/ffe_fuel.json']+=b' '
        with self.assertRaisesRegex(AssertionError,'Fuel resource differs from local source'):
            verifier.verify_fuel_runtime(self.archive,self.project)

    def test_wrong_original_provenance_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_resource(project,'ffe_fuel',lambda data:data.update(source_sha256='0'*64))
            with self.assertRaisesRegex(AssertionError,'Wrong fuel executable provenance'):
                verifier.verify_fuel_runtime(self.archive,project)

    def test_wrong_original_tank_capacity_cannot_pass_with_matching_export(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_resource(project,'ffe_fuel',lambda data:data['tables_hex'].update({'5111':'ff'+data['tables_hex']['5111'][2:]}))
            with self.assertRaisesRegex(AssertionError,'Changed original fuel table 5111'):
                verifier.verify_fuel_runtime(self.archive,project)

    def test_jjffe_six_axis_restoration_cannot_be_called_canonical_dos(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_resource(project,'ffe_fuel',lambda data:data['source_variants']['F929'].update(DOS_automatic_restore=True))
            with self.assertRaisesRegex(AssertionError,'canonical DOS three-axis variant'):
                verifier.verify_fuel_runtime(self.archive,project)

    def test_missing_original_stellar_model_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_resource(project,'ffe_fuel',lambda data:data['models'].pop('137'))
            with self.assertRaisesRegex(AssertionError,'Incomplete original gas/star contact models'):
                verifier.verify_fuel_runtime(self.archive,project)

    def test_changed_stellar_geometry_cannot_use_self_reported_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_resource(project,'ffe_fuel',lambda data:data['models']['137'].update(vertices_hex='ff'+data['models']['137']['vertices_hex'][2:]))
            with self.assertRaisesRegex(AssertionError,'Changed original fuel contact component 137/vertices'):
                verifier.verify_fuel_runtime(self.archive,project)

    def test_fuel_scoop_cannot_skip_original_hull_eligibility(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_resource(project,'ffe_fuel',lambda data:data['equipment']['scoop'].update(required_spec_mask_u16=0))
            with self.assertRaisesRegex(AssertionError,'lost its original hull eligibility'):
                verifier.verify_fuel_runtime(self.archive,project)

    def test_old_hyperdrive_digest_cannot_be_changed_for_fuel_extension(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_resource(project,'ffe_hyperdrive',lambda data:data.update(extra_fuel_metadata='forbidden old-data edit'))
            with self.assertRaisesRegex(AssertionError,'Hyperdrive resource differs from reviewed DOS extraction'):
                verifier.verify_fuel_runtime(self.archive,project)

    def test_information_variable_tokens_remain_checked(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_resource(project,'system_information_ru',lambda data:data['strings']['7010'].update(text='Без исходных переменных'))
            with self.assertRaisesRegex(AssertionError,'variable/layout tokens differ'):
                verifier.verify_fuel_runtime(self.archive,project)

    def test_shared_contact_solver_cannot_mutate_behind_pinned_caller(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'scripts/source_terrain_query.gd'
            path.write_bytes(path.read_bytes()+b'\n# mutation of shared solver\n')
            with self.assertRaisesRegex(AssertionError,'protected source/data scripts/source_terrain_query.gd'):
                verifier.verify_fuel_runtime(self.archive,project)

    def test_live_fuel_tick_cannot_be_disconnected(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_function(project,'main','_tick','_step_source_fuel(dt,fuel_commands)','_skip_source_fuel(dt,fuel_commands)')
            with self.assertRaisesRegex(AssertionError,'fuel debit is not consumed by the live physics step'):
                verifier.verify_fuel_runtime(self.archive,project)

    def test_actual_contact_query_cannot_be_replaced_by_a_sphere_guess(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_function(project,'main','_step_source_fuel','fuel_contact.sample(','fuel_contact.fake_sphere_sample(')
            with self.assertRaisesRegex(AssertionError,'lost original contact/session consumers'):
                verifier.verify_fuel_runtime(self.archive,project)

    def test_restored_jet_state_must_derive_flight_limits(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_function(project,'main','_decode_state','candidate_nav.apply_fuel_availability(candidate_ship)','candidate_nav.skip_fuel_availability(candidate_ship)')
            with self.assertRaisesRegex(AssertionError,'Restored fuel flags must derive Flight propulsion state'):
                verifier.verify_fuel_runtime(self.archive,project)

    def test_kernel_cannot_silently_restore_six_limits_on_ordinary_debit(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_function(project,'source_jet_fuel','consume','\n','\n\tinput["thrust_u16"]=input["cached_thrust_u16"].duplicate()\n')
            with self.assertRaisesRegex(AssertionError,'audited integration source scripts/source_jet_fuel.gd'):
                verifier.verify_fuel_runtime(self.archive,project)

    def test_saved_fraction_validation_cannot_be_removed(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_function(project,'source_hyperdrive_session','_valid_fuel','_fraction(fuel_system.ticks_fraction_f64_hex)','0.0')
            with self.assertRaisesRegex(AssertionError,'lacks resource/clock-fraction validation'):
                verifier.verify_fuel_runtime(self.archive,project)

    def test_source_drive_removal_cannot_keep_jet_fuel(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_function(project,'source_hyperdrive_session','service','candidate.fuel_system.jet_raw_u32=0','candidate.fuel_system.jet_raw_u32=536870912')
            with self.assertRaisesRegex(AssertionError,'Drive removal lost its F410 jet-empty side effect'):
                verifier.verify_fuel_runtime(self.archive,project)

    def test_original_main_orbit_selection_must_not_change(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_function(project,'main','_choose_body','\n','\n\tship.position=Vector3.ZERO\n')
            with self.assertRaisesRegex(AssertionError,'undeclared physical Main function _choose_body'):
                verifier.verify_fuel_runtime(self.archive,project)

    def test_each_native_reference_is_pinned_without_reexecuting_oracle(self):
        for name in verifier.FUEL_NATIVE_REFERENCE:
            with self.subTest(name=name),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/'tests/fixtures'/f'{name}.json'
                data=json.loads(path.read_text());data['case_count']=1;path.write_text(json.dumps(data))
                with self.assertRaisesRegex(AssertionError,'Changed fuel native reference '+name):
                    verifier.verify_fuel_runtime(self.archive,project)


if __name__=='__main__':unittest.main()
