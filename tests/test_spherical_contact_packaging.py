"""Strict code45 controls using explicit mock GDSC, not an exported APK/device."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import test_surface_contact_packaging as retained

verifier=retained.verifier;PROJECT=retained.PROJECT


class MockSphericalArchive(retained.MockSurfaceContactArchive):
    def __init__(self):
        super().__init__()
        for name in verifier.SPHERICAL_CONTACT_MODULES:
            self.entries[f'assets/scripts/{name}.gdc']=b'GDSC'+b'explicit-unit-mock-not-an-APK'*5
        self.entries['assets/data/ffe_spherical_contact.json']=(PROJECT/'data/ffe_spherical_contact.json').read_bytes()


class SphericalContactPackaging(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        directory=tempfile.TemporaryDirectory(prefix='natural-packaging-v45-')
        cls.addClassCleanup(directory.cleanup);cls.project=Path(directory.name)
        for relative in cls.project_files():
            target=cls.project/relative;target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes((PROJECT/relative).read_bytes())
        path=PROJECT/'tests/fixtures/natural_v45_sources.json'
        if hashlib.sha256(path.read_bytes()).hexdigest()!='f9511cf774d7a54826a77a71d0ac5a88ae68369e0ed63d6eb8f2717b9a66a60d':
            raise AssertionError('Historical code45 natural baseline fixture changed')
        baseline=json.loads(path.read_text());expected=verifier.SPHERICAL_CONTACT_AUDITED_SOURCE_SHA256
        if baseline['source_commit']!='e3b9369230085ef7c15ab974d8e8de84eda1a991' or set(baseline['files'])!=set(expected):
            raise AssertionError('Historical code45 source fixture domain changed')
        for name,digest in expected.items():
            raw=baseline['files'][name].encode()
            if hashlib.sha256(raw).hexdigest()!=digest:raise AssertionError('Historical code45 source differs '+name)
            (cls.project/name).write_bytes(raw)
    def setUp(self):self.archive=MockSphericalArchive()

    @staticmethod
    def project_files():
        files=retained.SurfaceContactPackaging.project_files()
        files.update(verifier.SPHERICAL_CONTACT_AUDITED_SOURCE_SHA256)
        files.update(['data/ffe_spherical_contact.json','tests/fixtures/source_spherical_contact_native.json',
                      'tests/fixtures/source_spherical_contact_pipeline_native.json'])
        return files

    def project_copy(self,directory):
        project=Path(directory)
        for relative in self.project_files():
            path=project/relative;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes((self.project/relative).read_bytes())
        return project

    def mutate_resource(self,project,callback):
        path=project/'data/ffe_spherical_contact.json';data=json.loads(path.read_text());callback(data)
        raw=json.dumps(data,ensure_ascii=False).encode();path.write_bytes(raw);self.archive.entries['assets/data/ffe_spherical_contact.json']=raw

    def mutate_function(self,project,module,name,old,new):
        path=project/'scripts'/f'{module}.gd';raw=path.read_text();function=verifier.source_function(raw,name)
        self.assertIn(old,function);path.write_text(raw.replace(function,function.replace(old,new,1),1))

    def test_frozen_runtime_scope_and_distinct_native_domains(self):
        result=verifier.verify_spherical_contact_runtime(self.archive,self.project)
        self.assertEqual(result['baseline_source_commit'],'86a4a5e2a44c73d610d8a35f7fda7e393343991e')
        self.assertEqual((result['compiled_module_count'],result['integration_compiled_module_count'],result['raw_json_count']),(3,26,1))
        self.assertEqual((result['primary_anchor_bytes'],result['primary_instruction_count']),(363,128))
        self.assertEqual((result['instruction_proof_record_count'],result['instruction_proof_bytes'],result['instruction_proof_instructions']),(7,917,367))
        self.assertEqual((result['descriptor_model_count'],result['descriptor_zero_stream_count'],result['initial_simple_sphere_count'],result['initialization_skipped_model_count'],result['initial_hierarchical_count']),(149,19,18,1,130))
        self.assertEqual(result['unchanged_code44_source_count'],22)
        a=result['native_references']['source_spherical_contact_native'];b=result['native_references']['source_spherical_contact_pipeline_native']
        self.assertEqual((a['case_count'],a['supported_case_count'],a['host_guard_case_count']),(1141,1141,0))
        self.assertEqual((b['case_count'],b['supported_case_count'],b['host_guard_case_count']),(213,207,6))
        self.assertTrue(result['new_json_is_runtime_routing_resource']);self.assertTrue(result['new_json_runtime_lookup_required'])
        for key in ('physical_response_changed_by_probe','complete_original_F575','F576_F578_engine_integrated','full_original_world_object_bank','complete_original_physics','compiled_source_correspondence_rebuilt_by_verifier','physical_device_tested'):
            self.assertFalse(result[key],key)
        self.assertFalse(a['oracle_executed_by_apk_verifier']);self.assertFalse(b['oracle_executed_by_apk_verifier'])
        old=result['retained_surface_contact_assets']
        self.assertEqual(old['native_reference']['case_count'],858);self.assertTrue(old['new_json_is_provenance_only'])
        self.assertNotEqual(result['actual_Main_sha256'],result['whole_Main_normalization_sha256'])
        self.assertIn('virtual normalized Main',result['Main_normalization_policy'])

    def test_each_of26_compiled_integration_modules_required(self):
        for relative in verifier.SPHERICAL_CONTACT_AUDITED_SOURCE_SHA256:
            with self.subTest(relative=relative):
                archive=MockSphericalArchive();del archive.entries['assets/scripts/'+Path(relative).stem+'.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing spherical-contact integration runtime'):
                    verifier.verify_spherical_contact_runtime(archive,self.project)

    def test_each_new_compiled_header_and64byte_truncation_rejects(self):
        for name in verifier.SPHERICAL_CONTACT_MODULES:
            for content in (b'BAD!'+b'x'*100,b'GDSC'+b'x'*60):
                with self.subTest(name=name,bytes=len(content)):
                    archive=MockSphericalArchive();archive.entries['assets/scripts/'+name+'.gdc']=content
                    with self.assertRaisesRegex(AssertionError,'Invalid compiled spherical-contact integration runtime'):
                        verifier.verify_spherical_contact_runtime(archive,self.project)

    def test_retained_information_compiled_modules_required(self):
        for name in verifier.SYSTEM_INFORMATION_MODULES:
            with self.subTest(name=name):
                archive=MockSphericalArchive();del archive.entries['assets/scripts/'+name+'.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing system information runtime'):
                    verifier.verify_spherical_contact_runtime(archive,self.project)

    def test_published_physical_provider_compiled_module_remains_required(self):
        del self.archive.entries['assets/scripts/source_surface_render_state.gdc']
        with self.assertRaisesRegex(AssertionError,'Missing published contact provider'):
            verifier.verify_spherical_contact_runtime(self.archive,self.project)

    def test_missing_new_routing_resource_rejects(self):
        del self.archive.entries['assets/data/ffe_spherical_contact.json']
        with self.assertRaisesRegex(AssertionError,'Missing spherical-contact routing resource'):
            verifier.verify_spherical_contact_runtime(self.archive,self.project)

    def test_export_cannot_differ_from_local_routing_resource(self):
        self.archive.entries['assets/data/ffe_spherical_contact.json']+=b' '
        with self.assertRaisesRegex(AssertionError,'Spherical-contact resource differs from local source'):
            verifier.verify_spherical_contact_runtime(self.archive,self.project)

    def test_all_six_old_raw_resources_and_information_resources_stay_checked(self):
        for name in ('ffe_surface_contact','ffe_runtime_model_descriptors','ffe_landing_gear','ffe_atmosphere','ffe_fuel','ffe_hyperdrive',*verifier.SYSTEM_INFORMATION_TABLES):
            with self.subTest(name=name):
                archive=MockSphericalArchive();archive.entries[f'assets/data/{name}.json']+=b' '
                with self.assertRaises(AssertionError):verifier.verify_spherical_contact_runtime(archive,self.project)

    def test_wrong_original_executable_provenance_rejects_matching_export(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,lambda d:d.update(source_sha256='0'*64))
            with self.assertRaisesRegex(AssertionError,'Wrong spherical-contact source provenance'):
                verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_old_resource_digest_contract_cannot_change(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,lambda d:d['immutable_resources'].update(ffe_fuel_sha256='0'*64))
            with self.assertRaisesRegex(AssertionError,'changed retained resource digests'):
                verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_incomplete_helper_proof_domain_rejects(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,lambda d:d['instruction_proofs'].pop('1341'))
            with self.assertRaisesRegex(AssertionError,'Incomplete spherical instruction proof domain'):
                verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_self_reported_hash_cannot_replace_original_instruction_anchor(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            def corrupt(data):
                row=data['instruction_proofs']['577'];row['hex']='00'+row['hex'][2:];row['sha256']=hashlib.sha256(bytes.fromhex(row['hex'])).hexdigest()
            self.mutate_resource(project,corrupt)
            with self.assertRaisesRegex(AssertionError,'Changed spherical DOS instruction proof 577'):
                verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_jjffe_parent_inner_operand_cannot_replace_uploaded_dos_outer(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory)
            self.mutate_resource(project,lambda d:d['source_variants'].update(nonpositive_shift_DOS_parent_radius_offset=0x140))
            with self.assertRaisesRegex(AssertionError,'DOS/JJFFE radius operand distinction changed'):
                verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_helper_cannot_claim_writing_collision_kind_hp_or_clock(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,lambda d:d['raw_api'].update(global_writes_only=['collision_flags_u8','altitude_s64','collision_kind']))
            with self.assertRaisesRegex(AssertionError,'must remain bounded and read-only'):
                verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_diagnostic_probe_cannot_claim_physical_response_or_whole_world(self):
        for key in ('physical_response_changed_by_probe','source_world_bank_dispatch_integrated','full_original_physics'):
            with self.subTest(key=key),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);self.mutate_resource(project,lambda d:d['caller_policies'].update({key:True}))
                with self.assertRaisesRegex(AssertionError,'must not claim live collision/world physics'):
                    verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_all149_routing_models_required(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,lambda d:d['model_collision_routing'].pop('148'))
            with self.assertRaisesRegex(AssertionError,'Incomplete149-model spherical routing domain'):
                verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_routing_descriptor_pointer_cannot_be_fabricated(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,lambda d:d['model_collision_routing']['117'].update(collision_pointer_u32=0))
            with self.assertRaisesRegex(AssertionError,'Spherical routing descriptor mismatch 117'):
                verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_collision_prefix_first_byte_checked_independently(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,lambda d:d['model_collision_routing']['117'].update(collision_first_byte_u8=0))
            with self.assertRaisesRegex(AssertionError,'Spherical collision pointer/first byte mismatch 117'):
                verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_model_zero_descriptor_is_not_an_initialized_object(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,lambda d:d['model_collision_routing']['0'].update(initial_object_flags_14c_u8=0,initial_sphere_path_eligible=True))
            with self.assertRaisesRegex(AssertionError,'Model0 skips F1533'):
                verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_natural_models_cannot_be_reclassified_as_simple_spheres(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,lambda d:d['model_collision_routing']['117'].update(initial_sphere_path_eligible=True))
            with self.assertRaisesRegex(AssertionError,'Spherical initialized routing mismatch 117'):
                verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_19_descriptor_streams_cannot_be_claimed19_initialized_objects(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,lambda d:d['initial_simple_sphere_models'].insert(0,0))
            with self.assertRaisesRegex(AssertionError,'19zero/18initialized/130hierarchical'):
                verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_unreviewed_routing_resource_metadata_change_rejects(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_resource(project,lambda d:d.update(scope=d['scope']+' altered'))
            with self.assertRaisesRegex(AssertionError,'differs from frozen DOS extraction'):
                verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_source_core_pipeline_and_probe_all_require_exact_reviewed_bytes(self):
        for name in verifier.SPHERICAL_CONTACT_MODULES:
            with self.subTest(name=name),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/'scripts'/f'{name}.gd';path.write_bytes(path.read_bytes()+b'\n# unreviewed change\n')
                with self.assertRaisesRegex(AssertionError,'Spherical contact differs from audited integration source'):
                    verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_main_probe_cannot_run_as_a_physical_tick_mutation(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);self.mutate_function(project,'main','_tick','\n','\n\tship.hull=100\n')
            with self.assertRaisesRegex(AssertionError,'changed physical/save/Main outside exact diagnostic normalization'):
                verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_main_diagnostic_probe_consumer_cannot_be_removed_or_duplicated(self):
        for value in ('', 'const SphericalContactProbe=preload("res://scripts/source_spherical_contact_probe.gd")\n'*2):
            with self.subTest(value=value),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/'scripts/main.gd';raw=path.read_text();raw=raw.replace('const SphericalContactProbe=preload("res://scripts/source_spherical_contact_probe.gd")\n',value,1);path.write_text(raw)
                with self.assertRaisesRegex(AssertionError,'Missing exact spherical diagnostic-only Main additions'):
                    verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_pending_contact_menu_and_save_recovery_cannot_change(self):
        for name,before,after in [('_payload','not surface.pending_source_contact().is_empty():return {}','false:return {}'),('_update_flight_controls','if button!=flight_console.buttons.menu:button.input_allowed=false','if true:button.input_allowed=false')]:
            with self.subTest(name=name),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);self.mutate_function(project,'main',name,before,after)
                with self.assertRaisesRegex(AssertionError,'changed physical/save/Main outside exact diagnostic normalization'):
                    verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_old_surface_bridge_nav_and_shared_hp_owner_remain_immutable(self):
        for name in ('surface_model','source_surface_contact_bridge','navigation','source_hyperdrive_session'):
            with self.subTest(name=name),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/'scripts'/f'{name}.gd';path.write_bytes(path.read_bytes()+b'\n# altered state owner\n')
                with self.assertRaisesRegex(AssertionError,'Spherical contact differs from audited integration source'):
                    verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_pure1141_native_reference_cannot_be_changed(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'tests/fixtures/source_spherical_contact_native.json';path.write_bytes(path.read_bytes()+b' ')
            with self.assertRaisesRegex(AssertionError,'Changed spherical native reference source_spherical_contact_native'):
                verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_coupled207_supported_and6_host_guards_cannot_be_conflated(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'tests/fixtures/source_spherical_contact_pipeline_native.json';data=json.loads(path.read_text());data['supported_case_count']=213;data['unsupported_guard_case_count']=0;path.write_text(json.dumps(data))
            with self.assertRaisesRegex(AssertionError,'Changed spherical native reference source_spherical_contact_pipeline_native'):
                verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_old858_response_native_controls_still_pinned(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.project_copy(directory);path=project/'tests/fixtures/source_surface_contact_native.json';path.write_bytes(path.read_bytes()+b' ')
            with self.assertRaisesRegex(AssertionError,'Changed surface-contact native reference'):
                verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_old_fuel_atmosphere_gear_and_hyper_native_controls_retained(self):
        for name in (*verifier.FUEL_NATIVE_REFERENCE,*verifier.ATMOSPHERE_NATIVE_REFERENCE,'source_landing_gear_native','source_hyperdrive_native'):
            with self.subTest(name=name),tempfile.TemporaryDirectory() as directory:
                project=self.project_copy(directory);path=project/'tests/fixtures'/f'{name}.json';path.write_bytes(path.read_bytes()+b' ')
                with self.assertRaises(AssertionError):verifier.verify_spherical_contact_runtime(self.archive,project)

    def test_old44_public_gate_remains_strict_against_actual45_main(self):
        with self.assertRaisesRegex(AssertionError,'Contact differs from audited integration source scripts/main.gd'):
            verifier.verify_surface_contact_runtime(self.archive,self.project)


if __name__=='__main__':unittest.main()
