"""Verifier unit controls using an explicit mock archive, not an APK build.

Actual APK signatures, ARM64 libraries, GDSC export and source correspondence
are checked separately against the real exported APK. Mock GDSC here tests the
packaging checker's rejection paths only.
"""
from __future__ import annotations
import importlib.util
import hashlib
from pathlib import Path
import json
import shutil
import tempfile
import unittest
import atexit

PROJECT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('android_verifier',PROJECT/'tools/verify_rebuilt_android.py')
verifier=importlib.util.module_from_spec(spec);spec.loader.exec_module(verifier)

# These are historical v34..39 controls. Later live Main/Nav/map consumers
# must not silently redefine what the old verifier accepted. Preserve the
# exact audited v39 source overlay while sharing unchanged project inputs.
_LIVE_PROJECT=PROJECT
_HISTORICAL_DIRECTORY=tempfile.TemporaryDirectory(prefix='packaging-v39-')
atexit.register(_HISTORICAL_DIRECTORY.cleanup)
PROJECT=Path(_HISTORICAL_DIRECTORY.name)
for _directory in ('scripts','data','tests'):
    (PROJECT/_directory).mkdir()
    for _path in (_LIVE_PROJECT/_directory).iterdir():
        (PROJECT/_directory/_path.name).symlink_to(_path,target_is_directory=_path.is_dir())
_baseline=json.loads((_LIVE_PROJECT/'tests/fixtures/hyperdrive_v39_sources.json').read_text())
assert _baseline['source_commit']=='860951235548fc58c859d7337b9a6909fd78ca62'
_baseline_sha256={
    'scripts/main.gd':'c83a666e1de2c6ce23b29247ad3c8fab007a0f325ecf2288523bfc8abad3a9de',
    'scripts/navigation.gd':verifier.MAP_VISUAL_PROTECTED_SOURCE_SHA256['scripts/navigation.gd'],
    'scripts/galactic_map_model.gd':verifier.MAP_VISUAL_PROTECTED_SOURCE_SHA256['scripts/galactic_map_model.gd'],
    'scripts/galactic_map_view.gd':verifier.SYSTEM_INFORMATION_MAP_VIEW_SHA256['scripts/galactic_map_view.gd'],
}
assert set(_baseline['files'])==set(_baseline_sha256)
for _relative,_entry in _baseline['files'].items():
    assert hashlib.sha256(_entry['source'].encode()).hexdigest()==_entry['sha256']==_baseline_sha256[_relative]
    _target=PROJECT/_relative
    _target.unlink();_target.write_text(_entry['source'])

class MockArchive:
    def __init__(self):
        self.entries={f'assets/scripts/{name}.gdc':b'GDSC'+b'unit-mock-not-an-exported-module'*4 for name in verifier.FULL_SOURCE_MODULES}
        self.entries.update({f'assets/scripts/{name}.gdc':b'GDSC'+b'unit-mock-not-an-exported-module'*4 for name in verifier.CLASSIC_CONSOLE_MODULES})
        self.entries.update({f'assets/scripts/{name}.gdc':b'GDSC'+b'unit-mock-not-an-exported-module'*4 for name in verifier.NAVIGATION_MODULES})
        self.entries.update({f'assets/scripts/{name}.gdc':b'GDSC'+b'unit-mock-not-an-exported-module'*4 for name in verifier.CELESTIAL_VISUAL_RUNTIME_MODULES})
        self.entries[f'assets/scripts/{verifier.SOURCE_MINING_KERNEL_MODULE}.gdc']=b'GDSC'+b'unit-mock-not-an-exported-module'*4
        for name in verifier.FULL_SOURCE_TABLES+verifier.NAVIGATION_TABLES+('ships','world_names_ru'):
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
        historical=tempfile.TemporaryDirectory();self.addCleanup(historical.cleanup)
        self.celestial_baseline=Path(historical.name)
        self.celestial_visual_project(self.celestial_baseline)

    def test_actual_local_startup_and_legacy_contract(self):
        result=verifier.verify_full_startup(self.main,self.world)
        self.assertEqual(result['normal_startup_layout'],'source_jjffe_systems_v4')
        self.assertEqual(result['automated_and_helper_layout'],'handcrafted_jjffe_ports_v3')
        self.assertEqual(len(result['legacy_saved_layouts_retained']),5)

    def test_source_function_extracts_inline_and_multiline_without_next_function(self):
        example='func one()->bool:return true\nfunc two()->void:\n\tpass\nfunc three()->void:pass\n'
        self.assertEqual(verifier.source_function(example,'one'),'func one()->bool:return true\n')
        self.assertEqual(verifier.source_function(example,'two'),'func two()->void:\n\tpass\n')

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
        for code in [34,35,36,37,38]:
            with self.subTest(version_code=code):
                result=verifier.verify_source_orbit_runtime(self.archive,PROJECT,code)
                self.assertEqual(result['new_game_requested_layout'],'source_jjffe_systems_v4')
                self.assertTrue(result['native_fixture']['provenance_checked'])
                self.assertFalse(result['native_fixture']['oracle_executed_by_apk_verifier'])
                self.assertEqual(result['retained_local_physics_adapter'],'analytic_si_rebuild_v1')

    def test_retained_v3_raw_physics_checks_are_not_relaxed(self):
        for code in [34,35,36,37,38]:
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

    def navigation_project(self,directory,replacements=None):
        """Only local verifier inputs are copied; the archive stays an explicit mock."""
        project=Path(directory)
        for name in (*verifier.NAVIGATION_MODULES,'main','flight_model','source_station_session'):
            target=project/'scripts'/f'{name}.gd';target.parent.mkdir(parents=True,exist_ok=True)
            raw=(PROJECT/'scripts'/f'{name}.gd').read_text()
            for old,new in (replacements or {}).get(name,[]):
                self.assertIn(old,raw,'Mutation must affect the intended real contract')
                raw=raw.replace(old,new)
            target.write_text(raw)
        target=project/'data/ffe_galactic_map.json';target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(PROJECT/'data/ffe_galactic_map.json',target)
        for name in ['source_motion_native','source_frame_native','source_time_controls_native','source_galactic_map_native']:
            target=project/'tests/fixtures'/f'{name}.json';target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(PROJECT/'tests/fixtures'/f'{name}.json',target)
        return project

    def test_navigation_summary_declares_actual_scope_and_limits(self):
        result=verifier.verify_navigation_runtime(self.archive,PROJECT)
        self.assertEqual(result['compiled_module_count'],11)
        self.assertEqual(result['raw_json_count'],1)
        self.assertTrue(result['galactic_map_connected'])
        self.assertTrue(result['system_map_connected'])
        self.assertTrue(result['analog_phone_roll_connected'])
        self.assertTrue(result['raw_source_motion_connected'])
        self.assertTrue(result['old_saves_without_motion_session_use_previous_path'])
        self.assertTrue(result['active_raw_session_restores_validated_ieee64_clock'])
        self.assertEqual(result['implemented_time_rates'],[1,10,100])
        self.assertEqual(result['disabled_time_rates'],[1000,10000])
        self.assertEqual(result['maximum_substeps'],32)
        self.assertEqual(result['maximum_substep_seconds'],0.1)
        for flag in ['complete_original_map_renderer','complete_original_map_instruments','original_time_scheduler_complete','complete_original_f582_collision','automatic_source_for_parent_selection','original_hyperdrive_f903_complete','complete_original_player_pipeline','complete_original_physics','physical_device_tested','compiled_source_correspondence_rebuilt_by_verifier','oracle_executed_by_apk_verifier']:
            self.assertFalse(result[flag],flag)
        expected={'source_motion_native':1236,'source_frame_native':720,'source_time_controls_native':1736,'source_galactic_map_native':4536}
        self.assertEqual({k:v['case_count'] for k,v in result['native_reference_metadata'].items()},expected)

    def test_v36_source_tables_are_required_without_changing_old_contract(self):
        previous=verifier.verify_source_full_runtime(self.archive,PROJECT,35)
        current=verifier.verify_source_full_runtime(self.archive,PROJECT,36)
        self.assertEqual(previous['raw_json_count'],21)
        self.assertNotIn('ffe_galactic_map',previous['data'])
        self.assertEqual(current['raw_json_count'],22)
        self.assertIn('ffe_galactic_map',current['data'])
        self.assertEqual(previous['live_gravity'],'sampled-f603-nominal-day-si-v1')
        self.assertEqual(current['live_gravity'],'source-fixed-parent-raw-f603-with-sampled-si-fallback-v1')
        self.assertFalse(current['original_per_frame_dynamics'])
        del self.archive.entries['assets/data/ffe_galactic_map.json']
        with self.assertRaisesRegex(AssertionError,'Full runtime JSON differs.*ffe_galactic_map'):
            verifier.verify_source_full_runtime(self.archive,PROJECT,36)

    def test_missing_each_navigation_runtime_module_rejects(self):
        for name in verifier.NAVIGATION_MODULES:
            with self.subTest(module=name):
                archive=MockArchive();del archive.entries[f'assets/scripts/{name}.gdc']
                with self.assertRaisesRegex(AssertionError,'Missing navigation runtime module '+name):
                    verifier.verify_navigation_runtime(archive,PROJECT)

    def test_invalid_navigation_compiled_header_rejects(self):
        for name in ['galactic_map_view','source_motion_bridge','source_frame_kinematics']:
            with self.subTest(module=name):
                archive=MockArchive();archive.entries[f'assets/scripts/{name}.gdc']=b'not-GDSC'+b'x'*100
                with self.assertRaisesRegex(AssertionError,'Invalid compiled navigation runtime module '+name):
                    verifier.verify_navigation_runtime(archive,PROJECT)

    def test_navigation_map_json_missing_or_changed_rejects(self):
        path='assets/data/ffe_galactic_map.json'
        for mutation in ['missing','changed']:
            with self.subTest(mutation=mutation):
                archive=MockArchive()
                if mutation=='missing':del archive.entries[path]
                else:archive.entries[path]+=b'\n'
                with self.assertRaisesRegex(AssertionError,'Navigation map JSON differs'):
                    verifier.verify_navigation_runtime(archive,PROJECT)

    def test_galactic_map_without_jump_consumer_rejects(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.navigation_project(directory,{'main':[('view.jump_requested.connect','view.unconnected_jump_requested.connect')]})
            with self.assertRaisesRegex(AssertionError,'Graphical galactic map is not connected'):
                verifier.verify_navigation_runtime(self.archive,project)

    def test_system_map_without_travel_consumer_rejects(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.navigation_project(directory,{'main':[('view.travel_requested.connect','view.unconnected_travel_requested.connect')]})
            with self.assertRaisesRegex(AssertionError,'Graphical system map is not connected'):
                verifier.verify_navigation_runtime(self.archive,project)

    def test_time_scheduler_without_step_acknowledgement_rejects(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.navigation_project(directory,{'main':[('flight_time.finish_frame(','flight_time.skip_acknowledgement(')]})
            with self.assertRaisesRegex(AssertionError,'Bounded time controller is not connected'):
                verifier.verify_navigation_runtime(self.archive,project)

    def test_unproven_high_time_rates_reject(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.navigation_project(directory,{'flight_time_controller':[('MAX_IMPLEMENTED_RATE:=100','MAX_IMPLEMENTED_RATE:=10000')]})
            with self.assertRaisesRegex(AssertionError,'Unsupported time rates must remain disabled'):
                verifier.verify_navigation_runtime(self.archive,project)

    def test_source_motion_scope_cannot_silently_include_ports(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.navigation_project(directory,{'source_motion_bridge':[('"station_available"','"ignored_station_available"')]})
            with self.assertRaisesRegex(AssertionError,'Source motion bridge lost an explicit scope guard'):
                verifier.verify_navigation_runtime(self.archive,project)

    def test_old_saves_cannot_silently_enable_raw_motion(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.navigation_project(directory,{'main':[('candidate_motion_enabled:=false','candidate_motion_enabled:=true')]})
            with self.assertRaisesRegex(AssertionError,'Old saves must keep the previous path'):
                verifier.verify_navigation_runtime(self.archive,project)

    def test_active_motion_cannot_restore_only_rounded_json_clock(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.navigation_project(directory,{'main':[('candidate_nav.elapsed_days=candidate_motion.elapsed_days()','candidate_nav.elapsed_days=candidate_nav.elapsed_days')]})
            with self.assertRaisesRegex(AssertionError,'Validated active raw motion must restore its exact saved clock'):
                verifier.verify_navigation_runtime(self.archive,project)

    def test_source_motion_kernel_without_main_consumer_rejects(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.navigation_project(directory,{'main':[('source_motion.step(','source_motion.unconsumed_step(')]})
            with self.assertRaisesRegex(AssertionError,'Source motion bridge is not connected'):
                verifier.verify_navigation_runtime(self.archive,project)

    def test_source_motion_requires_saved_session_enable_gate(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.navigation_project(directory,{'main':[('not source_motion_enabled or ','')]})
            with self.assertRaisesRegex(AssertionError,'Source motion must respect the saved session enable gate'):
                verifier.verify_navigation_runtime(self.archive,project)

    def test_legacy_new_game_cannot_enable_raw_motion_by_default(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.navigation_project(directory,{'main':[('source_motion_enabled=layout==World.FULL_LAYOUT','source_motion_enabled=true')]})
            with self.assertRaisesRegex(AssertionError,'Only new FULL sessions'):
                verifier.verify_navigation_runtime(self.archive,project)

    def test_wrong_motion_native_provenance_rejects(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.navigation_project(directory)
            path=project/'tests/fixtures/source_motion_native.json';fixture=json.loads(path.read_text());fixture['source_assembly_sha256']='0'*64;path.write_text(json.dumps(fixture))
            with self.assertRaisesRegex(AssertionError,'Wrong navigation native reference provenance'):
                verifier.verify_navigation_runtime(self.archive,project)

    def map_visual_project(self,directory,replacements=None,historical_main=True):
        project=Path(directory)
        for relative in (*verifier.MAP_VISUAL_PROTECTED_SOURCE_SHA256,'scripts/galactic_map_view.gd'):
            target=project/relative;target.parent.mkdir(parents=True,exist_ok=True)
            raw=(PROJECT/relative).read_text()
            historical=json.loads((PROJECT/'tests/fixtures/celestial_visual_v38_sources.json').read_text())
            if relative in historical['files']:
                entry=historical['files'][relative]
                self.assertEqual(hashlib.sha256(entry['source'].encode()).hexdigest(),entry['sha256'])
                raw=entry['source']
            if historical_main and relative=='scripts/main.gd':
                baseline=json.loads((PROJECT/'tests/fixtures/map_visual_v37_main_source.json').read_text())
                self.assertEqual(hashlib.sha256(baseline['source'].encode()).hexdigest(),verifier.MAP_VISUAL_PROTECTED_SOURCE_SHA256[relative])
                self.assertEqual(baseline['source_commit'],verifier.CELESTIAL_VISUAL_BASELINE_SOURCE_COMMIT)
                raw=baseline['source']
            for old,new in (replacements or {}).get(relative,[]):
                self.assertIn(old,raw,'Mutation must affect the intended protected input')
                raw=raw.replace(old,new)
            target.write_text(raw)
        return project

    def test_modern_map_visual_scope_is_explicitly_presentation_only(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.map_visual_project(directory)
            result=verifier.verify_map_visual_runtime(self.archive,project)
        self.assertEqual(result['presentation_profile'],'navy-star-chart-v1')
        self.assertEqual(result['baseline_source_commit'],'e4e8e7edccdb4422124f249365dfb8c99d135bb5')
        self.assertEqual(result['protected_source_data_count'],18)
        self.assertEqual(result['protected_view_function_count'],7)
        self.assertEqual(result['additional_runtime_modules'],0)
        self.assertEqual(result['additional_shaders'],0)
        self.assertEqual(result['additional_textures'],0)
        self.assertTrue(result['original_map_data_preserved'])
        self.assertTrue(result['display_color_transfer_is_presentation'])
        self.assertFalse(result['complete_original_renderer'])
        self.assertFalse(result['compiled_source_correspondence_rebuilt_by_verifier'])
        self.assertFalse(result['behavior_proved_by_this_package_check'])
        self.assertFalse(result['physical_device_tested'])

    def test_modern_map_missing_or_invalid_compiled_view_rejects(self):
        path='assets/scripts/galactic_map_view.gdc'
        for mutation in ['missing','invalid_header']:
            with self.subTest(mutation=mutation):
                archive=MockArchive()
                if mutation=='missing':del archive.entries[path]
                else:archive.entries[path]=b'not-GDSC'+b'x'*100
                with self.assertRaisesRegex(AssertionError,'(?:Missing|Invalid compiled) modern map visual runtime'):
                    verifier.verify_map_visual_runtime(archive,PROJECT)

    def test_modern_map_requires_presentation_profile(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.map_visual_project(directory,{'scripts/galactic_map_view.gd':[('PRESENTATION_PROFILE','UNDECLARED_PRESENTATION_PROFILE')]})
            with self.assertRaisesRegex(AssertionError,'Modern map presentation profile missing'):
                verifier.verify_map_visual_runtime(self.archive,project)

    def test_modern_map_requires_actual_presentation_consumer(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.map_visual_project(directory,{'scripts/galactic_map_view.gd':[('"presentation_profile"','"unconnected_presentation_profile"')]})
            with self.assertRaisesRegex(AssertionError,'Modern map presentation profile is not consumed'):
                verifier.verify_map_visual_runtime(self.archive,project)

    def test_visual_map_update_cannot_change_protected_gameplay_or_data(self):
        for relative in ['scripts/main.gd','scripts/galactic_map_model.gd','scripts/system_map_view.gd','scripts/source_motion_bridge.gd','data/ffe_galactic_map.json']:
            with self.subTest(relative=relative),tempfile.TemporaryDirectory() as directory:
                project=self.map_visual_project(directory)
                path=project/relative;path.write_bytes(path.read_bytes()+b'\n')
                with self.assertRaisesRegex(AssertionError,'Visual-only map update changed protected source/data'):
                    verifier.verify_map_visual_runtime(self.archive,project)

    def test_visual_map_update_retains_worker_explicit_jump_and_input_deduplication(self):
        changes=[('candidate.load_sector_window(center)','candidate.load_sector_window(Vector2.ZERO)'),
                 ('jump_requested.emit(int(model.selected_id))','system_selected.emit(int(model.selected_id))'),
                 ('event.device==-1','event.device==999')]
        for old,new in changes:
            with self.subTest(mutation=old),tempfile.TemporaryDirectory() as directory:
                project=self.map_visual_project(directory,{'scripts/galactic_map_view.gd':[(old,new)]})
                with self.assertRaisesRegex(AssertionError,'Visual-only map update changed protected input/worker function'):
                    verifier.verify_map_visual_runtime(self.archive,project)

    def celestial_visual_project(self,directory,replacements=None):
        project=self.map_visual_project(directory,replacements,historical_main=False)
        path=project/'scripts/celestial_renderer.gd'
        raw=(PROJECT/'scripts/celestial_renderer.gd').read_text()
        for old,new in (replacements or {}).get('scripts/celestial_renderer.gd',[]):
            self.assertIn(old,raw,'Mutation must affect the intended celestial source')
            raw=raw.replace(old,new)
        path.write_text(raw)
        return project

    def test_celestial_visual_scope_keeps_gameplay_and_source_units_explicit(self):
        result=verifier.verify_celestial_visibility_runtime(self.archive,self.celestial_baseline)
        self.assertEqual(result['baseline_source_commit'],'c5d61229d579dc738aca6f5b45c570e5444fa836')
        self.assertEqual(result['presentation_runtime_module_count'],2)
        self.assertEqual(result['protected_source_data_count'],17)
        self.assertEqual(result['protected_main_function_count'],28)
        self.assertEqual(result['protected_renderer_function_count'],16)
        self.assertTrue(result['actual_console_camera_projection_consumers'])
        self.assertTrue(result['full_star_coverage_material_consumer_checked'])
        self.assertEqual(result['additional_runtime_modules'],0)
        self.assertFalse(result['compiled_source_correspondence_rebuilt_by_verifier'])
        self.assertFalse(result['visibility_or_eclipse_proved_by_this_package_check'])
        self.assertFalse(result['astronomically_calibrated_star_radii'])
        self.assertFalse(result['physical_device_tested'])

    def test_historical_v37_contract_does_not_accept_v38_Main_changes(self):
        with self.assertRaisesRegex(AssertionError,'Visual-only map update changed protected source/data scripts/main.gd'):
            verifier.verify_map_visual_runtime(self.archive,self.celestial_baseline)

    def test_celestial_presentation_requires_both_compiled_consumers(self):
        for name in verifier.CELESTIAL_VISUAL_RUNTIME_MODULES:
            for mutation in ['missing','invalid']:
                with self.subTest(module=name,mutation=mutation):
                    archive=MockArchive();path='assets/scripts/'+name+'.gdc'
                    if mutation=='missing':del archive.entries[path]
                    else:archive.entries[path]=b'invalid'+b'x'*100
                    with self.assertRaisesRegex(AssertionError,'(?:Missing|Invalid compiled) celestial visibility runtime'):
                        verifier.verify_celestial_visibility_runtime(archive,self.celestial_baseline)

    def test_celestial_update_cannot_change_simulation_save_or_transfer_functions(self):
        for name in ['_tick','_payload','_decode_state','_time_context','_source_motion_step','_choose_body','_choose_site','_apply_system']:
            with self.subTest(function=name),tempfile.TemporaryDirectory() as directory:
                original=verifier.source_function(self.main,name)
                project=self.celestial_visual_project(directory,{'scripts/main.gd':[(original,original+'# Unapproved gameplay change\n')]})
                error='System initialization may only append one projection call' if name=='_apply_system' else 'Celestial presentation fix changed protected Main function '+name
                with self.assertRaisesRegex(AssertionError,error):
                    verifier.verify_celestial_visibility_runtime(self.archive,project)

    def test_celestial_update_cannot_change_original_lighting_or_geometry(self):
        original=(PROJECT/'scripts/celestial_renderer.gd').read_text()
        for name in ['source_light','update_view','configure','_source_cap']:
            with self.subTest(function=name),tempfile.TemporaryDirectory() as directory:
                function=verifier.source_function(original,name)
                project=self.celestial_visual_project(directory,{'scripts/celestial_renderer.gd':[(function,function+'# Unapproved lighting or geometry change\n')]})
                with self.assertRaisesRegex(AssertionError,'Celestial presentation fix changed protected renderer function '+name):
                    verifier.verify_celestial_visibility_runtime(self.archive,project)

    def test_celestial_update_cannot_duplicate_system_projection_call(self):
        with tempfile.TemporaryDirectory() as directory:
            function=verifier.source_function(self.main,'_apply_system')
            wrong=function.replace(';_update_flight_projection()',';_update_flight_projection();_update_flight_projection()')
            project=self.celestial_visual_project(directory,{'scripts/main.gd':[(function,wrong)]})
            with self.assertRaisesRegex(AssertionError,'System initialization may only append one projection call'):
                verifier.verify_celestial_visibility_runtime(self.archive,project)

    def test_celestial_update_cannot_change_legacy_crossfade(self):
        with tempfile.TemporaryDirectory() as directory:
            old='var is_focus:bool=id==context.focus_id'
            project=self.celestial_visual_project(directory,{'scripts/celestial_renderer.gd':[(old,'var is_focus:bool=true')]})
            with self.assertRaisesRegex(AssertionError,'Celestial presentation fix changed the legacy transition'):
                verifier.verify_celestial_visibility_runtime(self.archive,project)

    def test_celestial_update_keeps_real_projection_consumers(self):
        changes=[('_safe_area','\t_update_flight_projection()','\tpass'),
                 ('_update_flight_projection','camera.set_frustum(','camera.unconsumed_frustum(')]
        for name,old,new in changes:
            with self.subTest(function=name),tempfile.TemporaryDirectory() as directory:
                function=verifier.source_function(self.main,name)
                self.assertIn(old,function)
                project=self.celestial_visual_project(directory,{'scripts/main.gd':[(function,function.replace(old,new))]})
                with self.assertRaisesRegex(AssertionError,'Flight projection (?:lacks|is not connected)'):
                    verifier.verify_celestial_visibility_runtime(self.archive,project)

    def test_projection_cannot_access_simulation_state_or_move_camera_pose(self):
        for extra in ['\tnav.elapsed_days=1\n','\tcamera.position=Vector3.ZERO\n']:
            with self.subTest(statement=extra),tempfile.TemporaryDirectory() as directory:
                function=verifier.source_function(self.main,'_update_flight_projection')
                project=self.celestial_visual_project(directory,{'scripts/main.gd':[(function,function+extra)]})
                with self.assertRaisesRegex(AssertionError,'Flight projection must (?:not access simulation state|preserve physical camera pose)'):
                    verifier.verify_celestial_visibility_runtime(self.archive,project)

    def test_stars_cannot_be_disconnected_from_FULL_coverage_fix(self):
        with tempfile.TemporaryDirectory() as directory:
            old='id==context.focus_id or luminous else surface_space_blend'
            project=self.celestial_visual_project(directory,{'scripts/celestial_renderer.gd':[(old,'id==context.focus_id else surface_space_blend')]})
            with self.assertRaisesRegex(AssertionError,'Luminous star coverage is not connected'):
                verifier.verify_celestial_visibility_runtime(self.archive,project)

    def test_celestial_update_keeps_complete_previous_galactic_view(self):
        with tempfile.TemporaryDirectory() as directory:
            project=self.celestial_visual_project(directory)
            path=project/'scripts/galactic_map_view.gd';path.write_bytes(path.read_bytes()+b'\n')
            with self.assertRaisesRegex(AssertionError,'Celestial presentation fix changed the galactic map view'):
                verifier.verify_celestial_visibility_runtime(self.archive,project)

if __name__=='__main__':unittest.main()
