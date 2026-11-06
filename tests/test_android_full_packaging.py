"""Verifier unit controls using an explicit mock archive, not an APK build.

Actual APK signatures, ARM64 libraries, GDSC export and source correspondence
are checked separately against the real exported APK. Mock GDSC here tests the
packaging checker's rejection paths only.
"""
from __future__ import annotations
import importlib.util
from pathlib import Path
import tempfile
import unittest

PROJECT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('android_verifier',PROJECT/'tools/verify_rebuilt_android.py')
verifier=importlib.util.module_from_spec(spec);spec.loader.exec_module(verifier)

class MockArchive:
    def __init__(self):
        self.entries={f'assets/scripts/{name}.gdc':b'GDSC'+b'unit-mock-not-an-exported-module'*4 for name in verifier.FULL_SOURCE_MODULES}
        self.entries.update({f'assets/scripts/{name}.gdc':b'GDSC'+b'unit-mock-not-an-exported-module'*4 for name in verifier.CLASSIC_CONSOLE_MODULES})
        self.entries[f'assets/scripts/{verifier.SOURCE_MINING_KERNEL_MODULE}.gdc']=b'GDSC'+b'unit-mock-not-an-exported-module'*4
        for name in verifier.FULL_SOURCE_TABLES+('ships','world_names_ru'):
            self.entries[f'assets/data/{name}.json']=(PROJECT/'data'/f'{name}.json').read_bytes()
        for name in verifier.FULL_SOURCE_SHADERS:
            self.entries['assets/scripts/'+name]=(PROJECT/'scripts'/name).read_bytes()
    def namelist(self):return list(self.entries)
    def read(self,name):return self.entries[name]

class FullPackagingChecks(unittest.TestCase):
    def setUp(self):
        self.archive=MockArchive()
        self.main=(PROJECT/'scripts/main.gd').read_text()
        self.world=(PROJECT/'scripts/planetary_system.gd').read_text()

    def test_actual_local_startup_and_legacy_contract(self):
        result=verifier.verify_full_startup(self.main,self.world)
        self.assertEqual(result['normal_startup_layout'],'source_jjffe_systems_v4')
        self.assertEqual(result['automated_and_helper_layout'],'handcrafted_jjffe_ports_v3')
        self.assertEqual(len(result['legacy_saved_layouts_retained']),5)

    def test_normal_startup_cannot_remain_legacy(self):
        wrong=self.main.replace('World.PORT_LAYOUT if automated else World.FULL_LAYOUT','World.PORT_LAYOUT if automated else World.PORT_LAYOUT')
        with self.assertRaisesRegex(AssertionError,'Normal v34 startup'):
            verifier.verify_full_startup(wrong,self.world)

    def test_legacy_helper_cannot_silently_upgrade(self):
        wrong=self.main.replace('_new_models(layout:String=World.PORT_LAYOUT)','_new_models(layout:String=World.FULL_LAYOUT)')
        with self.assertRaisesRegex(AssertionError,'Legacy helper'):
            verifier.verify_full_startup(wrong,self.world)

    def test_full_startup_requires_native_navigation(self):
        wrong=self.main.replace('nav.configure_native()','nav.configure_disabled()')
        with self.assertRaisesRegex(AssertionError,'native navigation'):
            verifier.verify_full_startup(wrong,self.world)

    def test_new_game_cannot_use_preview_layout(self):
        new_game=verifier.source_function(self.main,'_confirm_new_game')
        wrong=self.main.replace(new_game,new_game.replace('_new_models(World.FULL_LAYOUT)','_new_models(World.PORT_LAYOUT)'))
        with self.assertRaisesRegex(AssertionError,'New Game'):
            verifier.verify_full_startup(wrong,self.world)

    def test_legacy_saved_schema_cannot_disappear(self):
        wrong=self.world.replace('starfrontier-rebuild-world-v3','starfrontier-rebuild-world-v9')
        with self.assertRaisesRegex(AssertionError,'saved schema v3'):
            verifier.verify_full_startup(self.main,wrong)

    def test_full_packaging_summary_is_explicitly_bounded(self):
        result=verifier.verify_source_full_runtime(self.archive,PROJECT)
        self.assertEqual(result['compiled_module_count'],len(verifier.FULL_SOURCE_MODULES))
        self.assertEqual(result['raw_json_count'],len(verifier.FULL_SOURCE_TABLES)+2)
        self.assertEqual(result['streaming_shader_count'],2)
        self.assertEqual(result['orbital_station_model_indices'],[69]+list(range(72,81)))
        self.assertEqual(result['natural_model_indices'],list(range(117,134)))
        self.assertFalse(result['compiled_source_correspondence_rebuilt_by_verifier'])
        self.assertFalse(result['original_per_frame_dynamics'])
        self.assertFalse(result['physical_device_tested'])

    def test_retained_orbit_native_provenance_still_runs_for_v34(self):
        for code in [34,35]:
            with self.subTest(version_code=code):
                result=verifier.verify_source_orbit_runtime(self.archive,PROJECT,code)
                self.assertEqual(result['new_game_requested_layout'],'source_jjffe_systems_v4')
                self.assertTrue(result['native_fixture']['provenance_checked'])
                self.assertFalse(result['native_fixture']['oracle_executed_by_apk_verifier'])
                self.assertEqual(result['retained_local_physics_adapter'],'analytic_si_rebuild_v1')

    def test_retained_v3_raw_physics_checks_are_not_relaxed(self):
        for code in [34,35]:
            with self.subTest(version_code=code):
                result=verifier.verify_source_physics_ports_runtime(self.archive,PROJECT,code)
                self.assertEqual(result['reported_layout_scope'],'retained-v3-layout')
                self.assertEqual(result['live_gravity'],'analytic_si_rebuild_v1')
                self.assertTrue(result['native_fixture']['provenance_checked'])
                self.assertFalse(result['complete_original_physics'])

    def test_missing_new_kernel_rejects(self):
        for name in ['source_station_session','source_surface_render_packet','source_surface_render_state','source_surface_contact_patch']:
            with self.subTest(module=name):
                archive=MockArchive();del archive.entries[f'assets/scripts/{name}.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing full source runtime module '+name):
                    verifier.verify_source_full_runtime(archive,PROJECT)

    def test_invalid_new_compiled_header_rejects(self):
        self.archive.entries['assets/scripts/source_physics_bridge.gdc']=b'wrong-header'+b'x'*100
        with self.assertRaisesRegex(AssertionError,'Invalid compiled full source runtime module'):
            verifier.verify_source_full_runtime(self.archive,PROJECT)

    def test_missing_streaming_shader_rejects(self):
        del self.archive.entries['assets/scripts/source_terrain_packet.gdshader']
        with self.assertRaisesRegex(AssertionError,'Missing source streaming terrain shader'):
            verifier.verify_source_full_runtime(self.archive,PROJECT)

    def test_changed_streaming_shader_rejects(self):
        self.archive.entries['assets/scripts/source_terrain_packet_transition.gdshader']+=b' '
        with self.assertRaisesRegex(AssertionError,'streaming terrain shader differs'):
            verifier.verify_source_full_runtime(self.archive,PROJECT)

    def test_missing_special_source_resource_rejects(self):
        del self.archive.entries['assets/data/ffe_special_station_models.json']
        with self.assertRaisesRegex(AssertionError,'Full runtime JSON differs'):
            verifier.verify_source_full_runtime(self.archive,PROJECT)

    def test_changed_raw_source_table_rejects(self):
        self.archive.entries['assets/data/ffe_ground_collision.json']+=b' '
        with self.assertRaisesRegex(AssertionError,'Full runtime JSON differs'):
            verifier.verify_source_full_runtime(self.archive,PROJECT)

    def test_native_fixtures_never_enter_apk(self):
        self.archive.entries['assets/data/fixtures/native.json']=b'{}'
        with self.assertRaisesRegex(AssertionError,'development fixture included'):
            verifier.verify_source_full_runtime(self.archive,PROJECT)

    def test_tools_never_enter_apk(self):
        self.archive.entries['assets/tools/native.py']=b'pass'
        with self.assertRaisesRegex(AssertionError,'Development material included'):
            verifier.verify_source_full_runtime(self.archive,PROJECT)

    def test_host_binary_never_enters_apk(self):
        self.archive.entries['assets/native-oracle.elf']=b'ELF'
        with self.assertRaisesRegex(AssertionError,'Host/development binary included'):
            verifier.verify_source_full_runtime(self.archive,PROJECT)

    def test_classic_console_packaging_is_explicitly_bounded(self):
        result=verifier.verify_classic_console_runtime(self.archive,PROJECT)
        self.assertEqual(result['console_height_logical_px'],240)
        self.assertEqual(result['live_command_count'],12)
        self.assertEqual(set(result['live_commands']),set(verifier.CLASSIC_CONSOLE_ACTIONS))
        self.assertFalse(result['complete_original_interface'])
        self.assertFalse(result['compiled_source_correspondence_rebuilt_by_verifier'])
        self.assertFalse(result['physical_device_tested'])

    def test_missing_classic_console_compiled_module_rejects(self):
        for name in verifier.CLASSIC_CONSOLE_MODULES:
            with self.subTest(module=name):
                archive=MockArchive();del archive.entries[f'assets/scripts/{name}.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing classic console runtime module '+name):
                    verifier.verify_classic_console_runtime(archive,PROJECT)

    def test_invalid_classic_console_compiled_header_rejects(self):
        self.archive.entries['assets/scripts/flight_console.gdc']=b'not-GDSC'+b'x'*100
        with self.assertRaisesRegex(AssertionError,'Invalid compiled classic console runtime module flight_console'):
            verifier.verify_classic_console_runtime(self.archive,PROJECT)

    def test_classic_console_command_without_main_consumer_rejects(self):
        with tempfile.TemporaryDirectory() as directory:
            project=Path(directory);(project/'scripts').mkdir()
            for name in verifier.CLASSIC_CONSOLE_MODULES:
                raw=(PROJECT/'scripts'/f'{name}.gd').read_text()
                if name=='main':raw=raw.replace('flight_console.pause_requested.connect','flight_console.unconnected_pause_requested.connect')
                (project/'scripts'/f'{name}.gd').write_text(raw)
            with self.assertRaisesRegex(AssertionError,'Classic console command is not connected to Main pause'):
                verifier.verify_classic_console_runtime(self.archive,project)

    def test_standalone_mining_kernel_packaging_does_not_claim_gameplay(self):
        result=verifier.verify_mining_kernel_runtime(self.archive,PROJECT)
        self.assertTrue(result['native_fixture_provenance_checked'])
        self.assertEqual(result['native_weekly_case_count'],2816)
        self.assertEqual(result['native_load_case_count'],990)
        self.assertFalse(result['oracle_executed_by_apk_verifier'])
        self.assertFalse(result['integrated_gameplay'])
        self.assertFalse(result['physical_deployment_implemented'])
        self.assertFalse(result['weekly_world_scheduler_integrated'])
        self.assertFalse(result['star_fuel_scoop_integrated'])

    def test_standalone_mining_kernel_missing_module_rejects(self):
        del self.archive.entries[f'assets/scripts/{verifier.SOURCE_MINING_KERNEL_MODULE}.gdc']
        with self.assertRaisesRegex(AssertionError,'Missing standalone MB4 record kernel'):
            verifier.verify_mining_kernel_runtime(self.archive,PROJECT)

if __name__=='__main__':unittest.main()
