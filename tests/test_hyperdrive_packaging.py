"""Code40 package rejection controls using an explicit non-APK archive.

No signatures, GPU, native instruction execution or GDSC-to-source equivalence
is claimed here. Those are separate release checks.
"""
import importlib.util
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

PROJECT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('hyperdrive_android_verifier',PROJECT/'tools/verify_rebuilt_android.py')
verifier=importlib.util.module_from_spec(spec);spec.loader.exec_module(verifier)
HISTORICAL_SOURCE_SHA256={**verifier.HYPERDRIVE_AUDITED_SOURCE_SHA256,
                         **{name:verifier.MAP_VISUAL_PROTECTED_SOURCE_SHA256[name] for name in
                            ['scripts/flight_model.gd','scripts/surface_model.gd','scripts/source_motion_bridge.gd']}}


class MockHyperdriveArchive:
    def __init__(self):
        self.entries={f'assets/scripts/{name}.gdc':b'GDSC'+b'unit-mock-not-a-real-export'*5
                      for name in (*verifier.HYPERDRIVE_MODULES,*verifier.SYSTEM_INFORMATION_MODULES)}
        self.entries.update({f'assets/data/{name}.json':(PROJECT/'data'/f'{name}.json').read_bytes()
                             for name in ('ffe_hyperdrive',*verifier.SYSTEM_INFORMATION_TABLES)})
    def namelist(self):return list(self.entries)
    def read(self,name):return self.entries[name]


class HyperdrivePackaging(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        directory=tempfile.TemporaryDirectory(prefix='hyperdrive-packaging-v40-')
        cls.addClassCleanup(directory.cleanup)
        cls.project=Path(directory.name)
        for relative in cls.project_files():
            path=cls.project/relative;path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes((PROJECT/relative).read_bytes())
        baseline=json.loads((PROJECT/'tests/fixtures/fuel_v40_sources.json').read_text())
        if baseline['source_commit']!='c3872931413d5641c3b437aa2669ed444e5f8075' or set(baseline['files'])!=set(HISTORICAL_SOURCE_SHA256):
            raise AssertionError('Historical code40 source fixture changed')
        for name,expected in HISTORICAL_SOURCE_SHA256.items():
            entry=baseline['files'][name];raw=entry['source'].encode()
            if entry['sha256']!=expected or hashlib.sha256(raw).hexdigest()!=expected:
                raise AssertionError('Historical code40 source differs: '+name)
            (cls.project/name).write_bytes(raw)
        thermal=json.loads((PROJECT/'tests/fixtures/thermal_v41_sources.json').read_text())
        for name in ['scripts/planetary_system.gd','scripts/flight_time_controller.gd']:
            entry=thermal['files'][name];raw=entry['source'].encode()
            if hashlib.sha256(raw).hexdigest()!=entry['sha256'] or entry['sha256']!=verifier.MAP_VISUAL_PROTECTED_SOURCE_SHA256[name]:
                raise AssertionError('Historical World/time source differs')
            (cls.project/name).write_bytes(raw)

        # Future renderer opt-ins must not redefine these historical contracts.
        alignment=verifier._load_contact_alignment_baseline(PROJECT)
        for relative in verifier.CONTACT_ALIGNMENT_PROVIDER_SOURCE_SHA256:
            target=cls.project/relative
            if target.exists():target.write_text(alignment['files'][relative]['source'])

    def setUp(self):self.archive=MockHyperdriveArchive()

    @staticmethod
    def project_files():
        files=set(verifier.MAP_VISUAL_PROTECTED_SOURCE_SHA256)
        files.update(verifier.HYPERDRIVE_AUDITED_SOURCE_SHA256)
        files.update(verifier.HYPERDRIVE_INFORMATION_SOURCE_SHA256)
        files.update(['scripts/celestial_renderer.gd','data/ffe_hyperdrive.json','tests/fixtures/source_hyperdrive_native.json'])
        files.update(f'data/{name}.json' for name in verifier.SYSTEM_INFORMATION_TABLES)
        return files

    def project_copy(self,directory):
        project=Path(directory)
        for relative in self.project_files():
            path=project/relative;path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes((self.project/relative).read_bytes())
        return project

    def mutate_resource(self,project,name,callback):
        path=project/'data'/f'{name}.json';data=json.loads(path.read_text());callback(data)
        raw=json.dumps(data,ensure_ascii=False).encode();path.write_bytes(raw)
        self.archive.entries[f'assets/data/{name}.json']=raw

    def mutate_function(self,project,module,name,old,new):
        path=project/'scripts'/f'{module}.gd';raw=path.read_text();function=verifier.source_function(raw,name)
        self.assertIn(old,function);changed=function.replace(old,new,1)
        path.write_text(raw.replace(function,changed,1))

    def test_historical_code40_scope_is_explicit_and_bounded(self):
        result=verifier.verify_hyperdrive_runtime(self.archive,self.project)
        self.assertEqual(result['baseline_source_commit'],'860951235548fc58c859d7337b9a6909fd78ca62')
        self.assertEqual((result['compiled_module_count'],result['drive_count'],result['ship_specification_count']),(3,15,57))
        self.assertEqual(result['protected_flight_source_data_count'],14)
        self.assertEqual(result['new_session_profile_models'],{'cobra':38,'eagle':24,'shuttle':15})
        self.assertEqual(result['explicit_fitting_adapters'],['eagle','shuttle'])
        self.assertEqual(result['native_reference']['case_count'],5453)
        self.assertEqual(result['native_reference']['unsafe_case_count'],11)
        for key in ['original_outfitting_economy','original_f908_arrival_pipeline','original_misjump_pipeline',
                    'jetfuel_or_star_scoop_integrated_by_this_block','all57_ships_playable',
                    'complete_original_hyperdrive_gameplay','complete_original_physics',
                    'compiled_source_correspondence_rebuilt_by_verifier','physical_device_tested']:
            self.assertFalse(result[key],key)
        self.assertFalse(result['native_reference']['oracle_executed_by_apk_verifier'])

    def test_historical_code40_fixture_is_exactly_pinned(self):
        path=PROJECT/'tests/fixtures/fuel_v40_sources.json'
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),'323e3446b726ad211f0e02cec76a88e826e9ef2fa3bdacbd547ca180cd46ec44')
        for name,expected in HISTORICAL_SOURCE_SHA256.items():
            self.assertEqual(hashlib.sha256((self.project/name).read_bytes()).hexdigest(),expected)

    def test_each_new_compiled_module_is_required(self):
        for name in verifier.HYPERDRIVE_MODULES:
            with self.subTest(name=name):
                archive=MockHyperdriveArchive();del archive.entries[f'assets/scripts/{name}.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing hyperdrive runtime module'):
                    verifier.verify_hyperdrive_runtime(archive,self.project)

    def test_invalid_compiled_core_is_rejected(self):
        self.archive.entries['assets/scripts/source_hyperdrive.gdc']=b'BAD!'+b'x'*100
        with self.assertRaisesRegex(AssertionError,'Invalid compiled hyperdrive runtime'):
            verifier.verify_hyperdrive_runtime(self.archive,self.project)

    def test_missing_or_wrong_exported_resource_is_rejected(self):
        del self.archive.entries['assets/data/ffe_hyperdrive.json']
        with self.assertRaisesRegex(AssertionError,'Missing hyperdrive resource'):
            verifier.verify_hyperdrive_runtime(self.archive,self.project)
        self.archive=MockHyperdriveArchive();self.archive.entries['assets/data/ffe_hyperdrive.json']+=b' '
        with self.assertRaisesRegex(AssertionError,'Hyperdrive resource differs from source'):
            verifier.verify_hyperdrive_runtime(self.archive,self.project)

    def test_wrong_original_provenance_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_resource(project,'ffe_hyperdrive',lambda data:data.update(source_sha256='0'*64))
            with self.assertRaisesRegex(AssertionError,'Wrong hyperdrive source provenance'):
                verifier.verify_hyperdrive_runtime(self.archive,project)

    def test_changed_original_drive_bytes_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_resource(project,'ffe_hyperdrive',lambda data:data.update(drive_table_hex='ff'+data['drive_table_hex'][2:]))
            with self.assertRaisesRegex(AssertionError,'Changed original hyperdrive table bytes'):
                verifier.verify_hyperdrive_runtime(self.archive,project)

    def test_changed_new_session_fuel_or_eagle_claim_is_rejected(self):
        for key,value in [('hydrogen',12),('original_starter',True)]:
            with self.subTest(key=key),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory)
                self.mutate_resource(project,'ffe_hyperdrive',lambda data:data['new_session_profiles']['eagle'].update({key:value}))
                with self.assertRaisesRegex(AssertionError,'Changed audited new-session hyperdrive profile eagle'):
                    verifier.verify_hyperdrive_runtime(self.archive,project)

    def test_reviewed_information_resources_remain_required(self):
        for name in verifier.SYSTEM_INFORMATION_TABLES:
            with self.subTest(name=name):
                archive=MockHyperdriveArchive();del archive.entries[f'assets/data/{name}.json']
                with self.assertRaisesRegex(AssertionError,'Missing system information resource'):
                    verifier.verify_hyperdrive_runtime(archive,self.project)

    def test_information_control_tokens_are_still_checked(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_resource(project,'system_information_ru',lambda data:data['strings']['7010'].update(text='Без исходных переменных'))
            with self.assertRaisesRegex(AssertionError,'variable/layout tokens differ'):
                verifier.verify_hyperdrive_runtime(self.archive,project)

    def test_information_runtime_cannot_be_mutated(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'scripts/source_information_text.gd';path.write_bytes(path.read_bytes()+b'\n')
            with self.assertRaisesRegex(AssertionError,'changed information runtime'):
                verifier.verify_hyperdrive_runtime(self.archive,project)

    def test_original_physical_sources_and_mercury_fix_remain_frozen(self):
        for relative,reason in [('scripts/flight_model.gd','protected flight/source data'),('scripts/celestial_renderer.gd','Mercury stellar-visibility fix')]:
            with self.subTest(relative=relative),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/relative;path.write_bytes(path.read_bytes()+b'\n')
                with self.assertRaisesRegex(AssertionError,reason):verifier.verify_hyperdrive_runtime(self.archive,project)

    def test_ui_tick_injection_cannot_move_ship(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_function(project,'main','_tick','\n','\n\tship.position=Vector3.ZERO\n')
            with self.assertRaisesRegex(AssertionError,'protected physical Main function _tick'):
                verifier.verify_hyperdrive_runtime(self.archive,project)

    def test_new_game_must_enable_source_hyperdrive(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_function(project,'main','_confirm_new_game','_enable_source_hyperdrive()','_load_game()')
            with self.assertRaisesRegex(AssertionError,'New Game omits source hyperdrive'):
                verifier.verify_hyperdrive_runtime(self.archive,project)

    def test_map_quote_cannot_revert_to_old_fuel_formula(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_function(project,'galactic_map_model','jump_state','SourceNavigation.source_map_quote(','SourceNavigation.old_fuel_quote(')
            with self.assertRaisesRegex(AssertionError,'lost source fuel/duration quote consumer'):
                verifier.verify_hyperdrive_runtime(self.archive,project)

    def test_cancel_cannot_consume_reserved_fuel(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_function(project,'navigation','cancel_jump','\n','\n\t_hyperdrive.commit(100,pending_source_quote)\n')
            with self.assertRaisesRegex(AssertionError,'cancel must clear pending quote without fuel consumption'):
                verifier.verify_hyperdrive_runtime(self.archive,project)

    def test_save_tamper_validation_cannot_be_skipped(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_function(project,'navigation','_restore_source','_same_pending(expected,data.pending_source_quote)','true')
            with self.assertRaisesRegex(AssertionError,'restore lacks validated inventory/pending quote'):
                verifier.verify_hyperdrive_runtime(self.archive,project)

    def test_core_fuel_mutation_cannot_pass_audited_source_pin(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_function(project,'source_hyperdrive_session','commit','candidate.hydrogen=int(consumed.hydrogen_after)','candidate.hydrogen=65535')
            with self.assertRaisesRegex(AssertionError,'differs from audited integration source scripts/source_hyperdrive_session.gd'):
                verifier.verify_hyperdrive_runtime(self.archive,project)

    def test_pending_completion_must_use_source_duration(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_function(project,'navigation','_step_source','duration_raw_u32)/65536.0','duration_raw_u32)/100.0')
            with self.assertRaisesRegex(AssertionError,'lost source quote/atomic fuel/duration consumer'):
                verifier.verify_hyperdrive_runtime(self.archive,project)

    def test_changed_native_reference_is_rejected_without_rerunning_it(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'tests/fixtures/source_hyperdrive_native.json'
            data=json.loads(path.read_text());data['source_sha256']='0'*64;path.write_text(json.dumps(data))
            with self.assertRaisesRegex(AssertionError,'Changed independent hyperdrive native reference'):
                verifier.verify_hyperdrive_runtime(self.archive,project)


if __name__=='__main__':unittest.main()
