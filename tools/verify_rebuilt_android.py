#!/usr/bin/env python3
"""Verify the rebuilt ARM64 APK; technical success is not full FFE readiness."""
from __future__ import annotations
import argparse,hashlib,json,re,struct,subprocess,zipfile
from pathlib import Path

FORBIDDEN_PERMISSIONS=['INTERNET','RECORD_AUDIO','READ_EXTERNAL_STORAGE','WRITE_EXTERNAL_STORAGE','MANAGE_EXTERNAL_STORAGE']
SOURCE_IMAGE_SHA256='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
SOURCE_ASSEMBLY_SHA256='d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a'
SOURCE_ASSEMBLY_COMMIT='7e540341d4e09aa3c92877b87d49e7f2c143ad8d'
MATERIAL_KINDS=('painted_alloy','brushed_metal','concrete','asphalt','rock','ice','rubber','glass')
MATERIAL_CHANNELS=('albedo','normal','orm')
SURFACE_PROFILES=('cobra','eagle','shuttle')
CITY_ROLES=('facade','road','pad','roof')
WORLD_SURFACE_KINDS=('earth','rock','desert','ice')
FULL_SOURCE_MODULES=(
    'source_galaxy','source_system_definition','source_system_metadata',
    'source_system_builder','source_body_classifier_full','source_planet_names',
    'source_settlement_builder','source_world_catalogue','source_body_factory',
    'handcrafted_runtime_builder','stellar_body_factory','planetary_classifier',
    'body_initializer','body_rotation','ffe_math','source_clock','source_units','ground_coordinates',
    'source_orbit','source_gravity','source_physics_bridge','source_ship_control_profile',
    'source_ground_surface','source_terrain_query','source_terrain_point','source_terrain_math',
    'source_surface_terrain','source_global_body_mesh','source_ground_pads',
    'source_surface_render_packet','source_surface_render_state','source_surface_contact_patch','surface_visual',
    'source_model_vm','source_model_vertices','source_model_mesh','source_polygon',
    'source_station_geometry','source_station_session','source_station_visual',
    'source_underground_port','source_underground_controller','source_enclosed_city_visual',
    'source_city_profile','source_city_runtime','source_city_view','source_model_visual',
    'galaxy','navigation','planetary_system','flight_model','surface_model',
    'spherical_terrain','celestial_renderer','near_surface_view','surface_orbit_link',
    'segment_triangle','segment_box','main',
)
FULL_SOURCE_TABLES=(
    'ffe_data_provenance','ffe_galaxy','ffe_ground_collision','ffe_ground_coordinates',
    'ffe_ground_pads','ffe_handcrafted_records','ffe_math','ffe_planet_names',
    'ffe_runtime_model_descriptors','ffe_settlement_rules','ffe_ship_registry',
    'ffe_special_station_models','ffe_stellar_factory','ffe_system_metadata',
    'ffe_system_names','ffe_terrain_query','ffe_underground_models','ffe_world_models','ffe_worlds',
)
FULL_SOURCE_SHADERS=('source_terrain_packet.gdshader','source_terrain_packet_transition.gdshader')
CLASSIC_CONSOLE_ACTIONS=('system','routes','auto','brake','dock','view','menu','status','equipment','control','surface','pause')
CLASSIC_CONSOLE_MODULES=('flight_console','touch_action_button','flight_instruments','main')
SOURCE_MINING_KERNEL_MODULE='source_mining_machine'
NAVIGATION_MODULES=(
    'galactic_map_model','galactic_map_view','system_map_model','system_map_view',
    'flight_time_controller','flight_time_controls','roll_control',
    'rotating_dock_dynamics','source_motion_pipeline','source_motion_bridge','source_frame_kinematics',
)
NAVIGATION_TABLES=('ffe_galactic_map',)
MAP_VISUAL_PROFILE='navy-star-chart-v1'
MAP_VISUAL_BASELINE_SOURCE_COMMIT='e4e8e7edccdb4422124f249365dfb8c99d135bb5'
MAP_VISUAL_PROTECTED_SOURCE_SHA256={
    'scripts/galactic_map_model.gd':'bb2f52814aae33d1d7fa000931e369f8c4d1cb0de1364939f9b363e496399b02',
    'scripts/galaxy.gd':'6cb023e203a633deebe774bc0c87fb71021d44d679e130bae6ba5aa36b3c94f4',
    'scripts/source_galaxy.gd':'5c258d5192e0797c76eab2e7a2653a3dd83954063d4fba58ed5bf0fa2f76d767',
    'scripts/navigation.gd':'aee7aeffccd200290c435cabf708c0e4ec5dc852fbae30f85b2bedce1c2a6b80',
    'scripts/system_map_model.gd':'ac7ae75188b9b8a47fefbd233d85dc90d4c64996e64d98dcc46705394f732e4a',
    'scripts/system_map_view.gd':'0d438facab582699c852ee19107ea113c69fa56971978ca998930554c55f6a2d',
    'scripts/main.gd':'61dd63e92cc7b2bebdb86859ccc5a8e5653f5376fbf0616d168f4c1ab4652d30',
    'scripts/flight_model.gd':'8da5454be81142412ba8bcfb4df0154ae43d906a73fc1f04f5650ec1d57b3391',
    'scripts/flight_time_controller.gd':'bebb04d4a40793bbaad2574044ab763ffe4609aaf9f8b615eeace704dd2ff728',
    'scripts/source_motion_pipeline.gd':'478b18ed852da1549eb573e2b8d168e3b817deb684c31c50e085d30a6d98bb84',
    'scripts/source_motion_bridge.gd':'7f5a805ca0a9675262ce511e28e4306df12b2b3cb5992dbb76d6e42f97f0bb9a',
    'scripts/source_frame_kinematics.gd':'aac70ddc3237a9b97910020db6a2ac400659ab02457730e113de9c828b530689',
    'scripts/rotating_dock_dynamics.gd':'68eb63c19831a2828fa62a1c10126de099d7d4905859f905c4b93e37124206a4',
    'scripts/source_station_session.gd':'80807b1c4b0aefb42f6907ef7480e2792295017f681caa5608894290d8d85b8f',
    'scripts/planetary_system.gd':'f243ebb2699bce714386e87ca32bfdb35709a2c9c45178cac9fa6cb8874abc62',
    'scripts/surface_model.gd':'a8e2825fd2daae3a9e66783cd0c77dd87e12d249187281147984e652677e2ab5',
    'data/ffe_galactic_map.json':'8fe5f5c5445a282422d5f9845b8d237a759c12c54538a3af8d8c260beb2b72b9',
    'data/ships.json':'944974a355019507fefe53f79dffc19d24e838fe650d34a52fbc00c692b8571a',
}
MAP_VISUAL_PROTECTED_FUNCTION_SHA256={
    '_prepare':'513d42bf46abe1015c5d5985a5995189b1f5a523019ddfd68619389edc664624',
    '_confirm_jump':'daceaa30c79ebe789ac6cd2a4d0b34108b04bfb5f8c56293874cc0d858b727ec',
    'select_system':'8c6d79b4187f0bfc0dd456056d602e3b5dbf46276b5dcd7b7c743c3dddfcda9a',
    '_pan':'1b26c414e3f6962f5d3b4d278a40cdddcd7944461c705b52756238b8da04c465',
    '_input':'bef7d1e275130c45c8b4e45484395a27dff25fd9f99b8054a74eea4337d9c32d',
    '_search':'6e7af10f8ed67621683a20533c93989ac92232c6547f6ac10afcd729ee418fd7',
    '_goto_sector':'cbb9c084c4456c285ef6b571516f50d80d78f3af18a778b9f95d893658e327d4',
}
# v38 permits only the explicit Main projection and FULL star-coverage fixes.
CELESTIAL_VISUAL_BASELINE_SOURCE_COMMIT='c5d61229d579dc738aca6f5b45c570e5444fa836'
CELESTIAL_VISUAL_GALACTIC_VIEW_SHA256='3b0d0fc97429ae3e37bf041ecaa0b67c6625bc0fbeda4a2a78fbe0ce04266137'
CELESTIAL_VISUAL_PROTECTED_MAIN_FUNCTION_SHA256={
    '_new_models':'84ee3ddf0488623c93a925f9e80c76d28f4b7369245264dc686c0a99b364d5d9',
    '_time_context':'fe9c64abab18fcfef20cc38e32749e8f484cbe2f54cdf7c6dfd06ed316b3f23a',
    '_advance_controls':'040b53157b656043a248f22bcac26a8e33ddb056338cdc26f4fcc1ef58e54b7d',
    '_tick':'d75bff3c9ad15639e0a9c10b14c3241d10e0dc3029c31b39ca46ce8ca5db148f',
    '_source_motion_step':'c476095f2e40347e7e45b1680dcb74c9adcd85931d8914a4959460a9410631cd',
    '_apply_system':'ba5483228b2c6182a77cea0a6c60095e7c533f1dda83e3a837c53139834c3fdb',
    '_set_speed':'70f2369529290729e7cce96f51b7e6925614f0694cacebd0056523608ea34ec9',
    '_brake':'65dcd9782fee7cf46f030449926b6b637261f77e29024b3b765638878dfb58c1',
    '_toggle_auto':'c66d6117ba49db06dcff00c94c59e04cb7c18bbd3ea91442eafe54f9e086616d',
    '_takeoff_action':'9d9648da5d8568bd962c3cde905bbd3865daa99f2fab14ba4ef1608b77ba310b',
    '_dock_action':'bb95a86e818161c86714e17c200c16fef97354b5d62c555997b15799dc9e1865',
    '_surface_action':'a19f55eb2bd983bdb3845cd7db9164b4bd18807877bae4c69e7096ef5ab3c5f3',
    '_enter_surface':'832d1576ee6c4f123d36a84c48bb0d0c882ef9bedffbaec506eb6647ff4716cf',
    '_finish_ascent':'596a7336a3b0f5d95fc223a8e721572db7f35065ebaf23ead1fbf1fdd729d742',
    '_cycle_view':'6e67437213491fd93075a37b9cc87b0dffe6409d2cffe810754c6b9dbbe516ad',
    '_show_system':'18a541bfc14a32692b1dfd0cfe662e687c399e106525bd3dae00f923990234c9',
    '_choose_body':'c3dab65a5e88c31f842188d34607279731672271b8d300b5c37a7c6929fdb18b',
    '_choose_site':'5dd971636babc4a708158c8438ad0b426794763328a26634c40c8757b05eab39',
    '_show_routes':'9adaa3907d6d826d80c39368430558b37e04490d22fefc64da4fe1a0bf61359f',
    '_install_map':'9b03be6d3d7a12352218d827adacbeeef0450e44f727dafba01c01c1a8a80608',
    '_close_map':'e4ce4c508c25955794749a6b86587bdbcaba275289eafed266781e485bb4aae8',
    '_start_jump':'e86f67215d31be57a5daa5f6e68774d7a65ecf245f7e5e3589a9daa5830db8f9',
    '_confirm_new_game':'26d20395cda493fa057b8f850c16903e90b91c2be8fb4e24612b2790278197cc',
    '_payload':'3dea677d678c8ba4859e4046060a4bd429ceff43b65ac1f1896cec705beec3f2',
    '_decode_state':'a4e3a90b798c8dc82b7886dfe823e724ce1eb3e9addd8b25c83881b61062facd',
    '_commit_state':'f9f2d2a08f0290ddc57c1027820ad364c618b6272c3716bd124373e4a4b9cde1',
    '_save_game':'dd756e0363e7368927145ccf6c45505e4f74ed472d5f6c815729a343eac6a649',
    '_load_game':'df251a26d6b7d236fd349a99ef61a7e3f9174dda3f50f6a3ffd7fc2fb66db8ab',
}
CELESTIAL_VISUAL_PROTECTED_RENDERER_FUNCTION_SHA256={
    '_full_context':'584b482a5cc29aaaae51fc9514afd8020ab11a6495f2164622fdc2f3a3a77028',
    '_exit_tree':'cd0257352c17bb107192713a0b986ee4e0502f9befab0e0bb6743e2401f1830d',
    '_process':'89a90ebb4ecbe58f17a0a311cf5ab63c836fa91b72437a8ba09ac0e58499941c',
    '_start_source_job':'423300d697e2d0d53fc5a6a7a596a9c2dae6df0eae460a1c5ab39f6df3db35f8',
    '_request_source_focus':'8593aea50eaa65f2af005be26d81eb11fe1810c28e6747f94114254fdf8260f4',
    '_install_source_mesh':'76854b8e821569cc039b3150a4fc7771995c4735a552702ee19184ac3d138ace',
    'source_mesh_state':'35635ae9f87c0ac584420dd0cbdcb4f4dd5c661a8d9ae5a1c449d626cab41a5f',
    'source_light':'5e933b0625767d801983a1d51792d33a5b9505fca09b8b4ec81c5b6fd6ed71aa',
    'source_cap_state':'ccbe85c137c870a895b379f9ae71409cadb0914815d1cbdb58f7cb343bc83126',
    'set_source_ground_patch':'4d2db181f729685a264b7440d0ba207229e445ae82ea365bb03a2ef6d058813b',
    '_source_cap':'728e0f1ecb94fa9352684e0b47927ad00557082705bc43b9aafa47d0e9c2fb1f',
    'set_quality':'81d329a0373e5ba177abf2ab7149141fc20d3baf3dbf393a5281fb73c773adff',
    '_bind_body_material':'591c6b4f8106981ee4ecfe0c173a1fd9bf101a1df42b1901ea8bc35dce237ffa',
    'configure':'e5ac7ff9943c1c375528c44957c40190e790507896ed9c9222ac923f52123dea',
    'update_view':'de2acb54093ccfa7d3e1d44f68d3eb1033a4129ce6e92b43d214fd412b800206',
    'suppress_focus_surface':'f75e533078f78f997d20e1d893e350df51505e438d96f157dd705c61fba3f105',
}
CELESTIAL_VISUAL_LEGACY_TRANSITION_SHA256='9a400b1d1e7e163f3ada764f441bbd70f313da04793293dc379c8fd26d864697'
CELESTIAL_VISUAL_RUNTIME_MODULES=('main','celestial_renderer')
SYSTEM_INFORMATION_BASELINE_SOURCE_COMMIT='606775527498662697ae9eedba152898adabfe40'
SYSTEM_INFORMATION_MODULES=('source_information_text','source_system_information','system_information_view')
SYSTEM_INFORMATION_TABLES=('ffe_system_information','system_information_ru')
SYSTEM_INFORMATION_CELESTIAL_SHA256='c084f772a420a8b625488ce176e87532833c4677e26da2a669939a437c01448e'
SYSTEM_INFORMATION_RESOURCE_SHA256={
    'ffe_system_information':'77b37c26d7925e27f227c683c2c78a74f636fc28bf3b55f71f916ab6bcfc09c6',
    'system_information_ru':'b78c2edcd1889b6aee01b45ef9b591705b159622fca918b803552a3e42057a7f',
}
SYSTEM_INFORMATION_MAIN_HELPER_SHA256={'_information_source_counts': '1e50a9c7f8bd846e12b720789ed95ebb57b24fff8d978ce71d480962a8520b8f', '_prepare_information_context': '1b2c529ccd3c7ab736851939114a56582ea24cfbade55446a0dbd5b6c37bad74', '_show_information': '4e0b3d599fd4ded671a997693c81f1533d88421fce685ec5781e0cbee64c2977', '_pump_information': 'a0ea44aca075882067ccdb66806cab1c34783502bbcdd566c826b79c4575f62c', '_finish_information_preparation': 'cefce6e006ad70a083501817b981caf7434c744edee365fc2324c55e1683d3a7', '_discard_information_parent': 'c11a5a15264b0e8d66c304bf3e234c4088b1755dbd4b47e6ea17e248aba09389', '_close_information': '5b06ec3d36bb706ad315797e6b40046be80964877f90f04c2beee0948fa7a868'}
SYSTEM_INFORMATION_BASELINE_MAIN_FUNCTION_SHA256={'_safe_area': '6d5e38a60d624a39a9d2316f19d36d9a70d165ed774d98758770591a9572fd8f', '_update_flight_projection': '64f5a6530eeebe1e58488f0f54b106e15f889bf2e311f9384c48eb3ab1e1f9e3', '_build_ui': '3436befa9d94776e9569d8d712ecdef667a51c36b2fbd8de1baee9e921b44d6a', '_process': '630d45fb00b80dd356b3343e078fbf0e559edda05cc466856e167b60664a0707', '_exit_tree': 'd568fc0f044944e6755ae645ef01a926c118bfc82c7c98c3c5afe92e4cb1c242', '_show_status': 'ddee14eda7ad252602270d6eb4f0802b7528f07a6280bf55830e2fa9dc7bd1f2'}
SYSTEM_INFORMATION_MAP_VIEW_SHA256={'scripts/system_map_view.gd': 'b1c03291928cb9dea19ca7a27e6055e192d2066e6fc46e3a21370100963eb103', 'scripts/galactic_map_view.gd': '2b725d1ecfda0f66e2d56872dd20c737dc73f904eee1a4fe490a2d93bbd9a33f'}
HYPERDRIVE_BASELINE_SOURCE_COMMIT='860951235548fc58c859d7337b9a6909fd78ca62'
HYPERDRIVE_MODULES=('source_hyperdrive', 'source_hyperdrive_session', 'hyperdrive_services_view')
HYPERDRIVE_RESOURCE_SHA256='17fe376bf480aa34fe8278193c558a8a30d198fa06354caf3c9692de34b1cf47'
HYPERDRIVE_NATIVE_SHA256='5f5034fb0b2b2b73d1b82b73217b7ee0a4483b483f8f9921e1f640d2dbb91eae'
HYPERDRIVE_AUDITED_SOURCE_SHA256={'scripts/source_hyperdrive.gd': 'b79cd38051e44d52fcd4f2beb173b2699096e7d9aea9a0288aba205e453a8874', 'scripts/navigation.gd': '3bc3d50e1c008b0f9f37f587e804729450ced47baf19330a27550d6343dccc1c', 'scripts/source_hyperdrive_session.gd': '0a505bd31bbffc703c9c06144b2f58167aa1da525de8ed013de5af4b58d2e59a', 'scripts/hyperdrive_services_view.gd': '755fad2ba1d52366a64954621f3406c4483bff299ead44a0d7151f502acac468', 'scripts/main.gd': '25dad04995505b2c119cc45470ff531c657dd80eb6963408a427bae641823049', 'scripts/galactic_map_model.gd': '597a5bd049e3dea2698bfbc255a0d57e7c98b70fabedfe09d56bb60ccd3a11a5', 'scripts/galactic_map_view.gd': '9a2a6fa97d9ab4f6ce572a5e10bb390d5036ccf6d30e3bc31e087a61440b7876'}
HYPERDRIVE_INFORMATION_SOURCE_SHA256={'scripts/source_information_text.gd': '3d3e3af3b32fe77c28f00eb269e0b286ec16763e0c79730f51767a9c62409648', 'scripts/source_system_information.gd': '503be92125c8f4dd461a97bf891fbe27a48a8a0da57630aa0c9db11dada3647c', 'scripts/system_information_view.gd': 'f2dfa6ae205713ee52b5d39d7cb755ca902cb9583f3353496a772767f2814708'}
HYPERDRIVE_PHYSICAL_MAIN_FUNCTION_SHA256={'_new_models': '84ee3ddf0488623c93a925f9e80c76d28f4b7369245264dc686c0a99b364d5d9', '_time_context': 'fe9c64abab18fcfef20cc38e32749e8f484cbe2f54cdf7c6dfd06ed316b3f23a', '_advance_controls': '040b53157b656043a248f22bcac26a8e33ddb056338cdc26f4fcc1ef58e54b7d', '_tick': 'd75bff3c9ad15639e0a9c10b14c3241d10e0dc3029c31b39ca46ce8ca5db148f', '_source_motion_step': 'c476095f2e40347e7e45b1680dcb74c9adcd85931d8914a4959460a9410631cd', '_apply_system': '47920c0adf4566e249ff2a7107ea85ae46923de53f94d788ad61307063acddc0', '_set_speed': '70f2369529290729e7cce96f51b7e6925614f0694cacebd0056523608ea34ec9', '_brake': '65dcd9782fee7cf46f030449926b6b637261f77e29024b3b765638878dfb58c1', '_toggle_auto': 'c66d6117ba49db06dcff00c94c59e04cb7c18bbd3ea91442eafe54f9e086616d', '_takeoff_action': '9d9648da5d8568bd962c3cde905bbd3865daa99f2fab14ba4ef1608b77ba310b', '_dock_action': 'bb95a86e818161c86714e17c200c16fef97354b5d62c555997b15799dc9e1865', '_surface_action': 'a19f55eb2bd983bdb3845cd7db9164b4bd18807877bae4c69e7096ef5ab3c5f3', '_enter_surface': '832d1576ee6c4f123d36a84c48bb0d0c882ef9bedffbaec506eb6647ff4716cf', '_finish_ascent': '596a7336a3b0f5d95fc223a8e721572db7f35065ebaf23ead1fbf1fdd729d742', '_choose_body': 'c3dab65a5e88c31f842188d34607279731672271b8d300b5c37a7c6929fdb18b', '_choose_site': '5dd971636babc4a708158c8438ad0b426794763328a26634c40c8757b05eab39', '_safe_area': '6d5e38a60d624a39a9d2316f19d36d9a70d165ed774d98758770591a9572fd8f', '_update_flight_projection': '64f5a6530eeebe1e58488f0f54b106e15f889bf2e311f9384c48eb3ab1e1f9e3', '_commit_state': 'f9f2d2a08f0290ddc57c1027820ad364c618b6272c3716bd124373e4a4b9cde1'}
FUEL_BASELINE_SOURCE_COMMIT='c3872931413d5641c3b437aa2669ed444e5f8075'
FUEL_MODULES=('source_jet_fuel', 'source_fuel_scoop', 'source_fuel_contact', 'source_fuel_flight_bridge')
FUEL_RESOURCE_SHA256='4d35dfd7047e7c3878ab92e25dcd9fde67697d7a93d46e53e57d0e1c7b71f14f'
FUEL_AUDITED_SOURCE_SHA256={'scripts/source_hyperdrive.gd': 'b79cd38051e44d52fcd4f2beb173b2699096e7d9aea9a0288aba205e453a8874', 'scripts/navigation.gd': '26e25aabedbf93831bd2f875b663a075053b0e479a67376b014a3aae79525a03', 'scripts/source_hyperdrive_session.gd': '6604df5a7573e1abdc3aae5b22e10c38c1d0cfcef4a38dbb03e54459bbe9aaf4', 'scripts/hyperdrive_services_view.gd': 'b0bcc31c52f8d46f94b29585ce2993535d45ef045a39617e8c90d15a2967cc97', 'scripts/main.gd': 'a09c5fe5b38011aaa455c78bc85902d27723f32cb4c82a5522882d7821068abf', 'scripts/galactic_map_model.gd': '597a5bd049e3dea2698bfbc255a0d57e7c98b70fabedfe09d56bb60ccd3a11a5', 'scripts/galactic_map_view.gd': '9a2a6fa97d9ab4f6ce572a5e10bb390d5036ccf6d30e3bc31e087a61440b7876', 'scripts/source_jet_fuel.gd': 'ef043cd3d7fe4ef06a08d1f6592bf97b5d1e6d81c5f2efe9ea067d514f207cc1', 'scripts/source_fuel_scoop.gd': 'de1e96fd3013de48557b340b9ca4e4d174c4d39aaebb8b2eee96250db53af296', 'scripts/source_fuel_contact.gd': '0f8d5defba15db89d02c5253c988a2a5680d7a16058296b91d262017d5a49903', 'scripts/source_fuel_flight_bridge.gd': '70921d3cb8b7d211f07f1211309f809dab1e0be9094ccf015e658558d6a04b52', 'scripts/flight_model.gd': '4bec7bd8448f7eb4f59436bcc45f09183736a274f5759124dbfa02dd5557264b', 'scripts/surface_model.gd': '28fcc37fb4adc1291129fdd90fb685828992e5657eaeb891eff986c9d5f3d894', 'scripts/source_motion_bridge.gd': 'f6ce8bd052ed586b560fb7935cbf4a039e264ab67a53e7afb32f14889c62c402'}
FUEL_CONTACT_DEPENDENCY_SHA256={'scripts/source_terrain_point.gd': 'caebe9f918763d6781a4885ae05e9d27aec84e584b9b45bb02cc71dc75000037', 'scripts/source_terrain_query.gd': 'fc9bf87c182113fffa10bbad9aab150eb99ed95b089dcaac20806e5505b15731', 'scripts/source_ground_surface.gd': 'e9db09fbd9c9e8a70bfba771b79627bbba6313d86b3efe781fba7b93a29e7ee7', 'scripts/ground_coordinates.gd': '54dedcc157dea6c84c4f8ad6ff0859159d81719cafbbaa23c626cd94e1cdf7b6', 'scripts/source_units.gd': '42f7db81e27c5d8ef12bf7e80192e0ebc96b815cbd71b0263047d14fbdc03b24', 'scripts/source_gravity.gd': '058db4e5cbebd07e7420274ca07b24ccaec620f46c440081d1d6855326dc3872', 'scripts/body_rotation.gd': 'b5d4e63331728681d1f34c73fe83cdd57120e29b352e09090da4ff147b22ed34', 'scripts/source_clock.gd': 'b2d206a9e2e6db21635fe37d6f61ba75d2fb9f56d92f8851a77c9b11fc4dbe09', 'scripts/source_terrain_math.gd': 'de4b98dfae36b680b3d378750624b0b8d84fb520e4883d78800f1cb4572e4eff', 'scripts/ffe_math.gd': 'd3cb103361e4039fd2b0942d84af042d69c9e19b8a856c7d830b82827827f228', 'scripts/source_physics_bridge.gd': 'c7b8550217fbce3925da741afeb3c7d58c841d91ab247c4994ecc1c45ac72262', 'scripts/source_ship_control_profile.gd': 'de2d0aed1943af69160f16b4b4892fea37afbc97c707a7b0870bba9b1805562e', 'data/ffe_ground_collision.json': '2dbf44a94422907b1bb29b34df1d795cef819cecf267b1591f3d82ea6326d018', 'data/ffe_terrain_query.json': '8d764c2cd2a682ddfa8e0b8978b8f12616333ef361d0ed820dcb5b03b3f1977a', 'data/ffe_math.json': '4166407ada817e8abfbd6e501ad12bac1a75977ee4d0c66fe727adb3aea8cce5', 'data/ffe_ship_registry.json': '07ccae9d6674bef40a7a5d2311a216b083ebdf010d5d47b187f7520de3b5d61a'}
FUEL_UNCHANGED_MAIN_FUNCTION_SHA256={'_new_models': '84ee3ddf0488623c93a925f9e80c76d28f4b7369245264dc686c0a99b364d5d9', '_time_context': 'fe9c64abab18fcfef20cc38e32749e8f484cbe2f54cdf7c6dfd06ed316b3f23a', '_advance_controls': '040b53157b656043a248f22bcac26a8e33ddb056338cdc26f4fcc1ef58e54b7d', '_source_motion_step': 'c476095f2e40347e7e45b1680dcb74c9adcd85931d8914a4959460a9410631cd', '_apply_system': '47920c0adf4566e249ff2a7107ea85ae46923de53f94d788ad61307063acddc0', '_set_speed': '70f2369529290729e7cce96f51b7e6925614f0694cacebd0056523608ea34ec9', '_brake': '65dcd9782fee7cf46f030449926b6b637261f77e29024b3b765638878dfb58c1', '_toggle_auto': 'c66d6117ba49db06dcff00c94c59e04cb7c18bbd3ea91442eafe54f9e086616d', '_takeoff_action': '9d9648da5d8568bd962c3cde905bbd3865daa99f2fab14ba4ef1608b77ba310b', '_dock_action': 'bb95a86e818161c86714e17c200c16fef97354b5d62c555997b15799dc9e1865', '_surface_action': 'a19f55eb2bd983bdb3845cd7db9164b4bd18807877bae4c69e7096ef5ab3c5f3', '_enter_surface': '832d1576ee6c4f123d36a84c48bb0d0c882ef9bedffbaec506eb6647ff4716cf', '_choose_body': 'c3dab65a5e88c31f842188d34607279731672271b8d300b5c37a7c6929fdb18b', '_choose_site': '5dd971636babc4a708158c8438ad0b426794763328a26634c40c8757b05eab39', '_safe_area': '6d5e38a60d624a39a9d2316f19d36d9a70d165ed774d98758770591a9572fd8f', '_update_flight_projection': '64f5a6530eeebe1e58488f0f54b106e15f889bf2e311f9384c48eb3ab1e1f9e3'}
FUEL_NATIVE_REFERENCE={'source_jet_fuel_native': {'sha256': 'ba1fa8be78c6c142fa037f0fb499e2aa2f2782077ad0b8f1da6a1dffa30051c8', 'case_count': 3182}, 'source_fuel_scoop_native': {'sha256': '40d2a6528bc7607a442311aeea69c2fcc7ac9859ccfe4cc64a88ddf123f6b15f', 'case_count': 729}, 'source_fuel_contact_native': {'sha256': 'a68264130ed7a13b17a689b58e23e2f0d6921d4c33b9bfb4d20219709d7cf3d6', 'case_count': 330}}
DEVELOPMENT_ASSET_PREFIXES=(
    'assets/tests/','assets/tools/','assets/docs/','assets/recovered-history/',
    'assets/recovery/','assets/validation/','assets/deliverables/',
    'assets/localization/','assets/build/',
)

def run(*command):
    return subprocess.check_output([str(v) for v in command],text=True,stderr=subprocess.STDOUT)

# Code42 is a distinct integration scope; prior code41 remains frozen above.
ATMOSPHERE_BASELINE_SOURCE_COMMIT='450e862ac3c146994371d8fa427efbc65b9fc677'
ATMOSPHERE_MODULES=('source_atmospheric_dynamics','source_atmosphere_contact')
ATMOSPHERE_RESOURCE_SHA256='b65e25e187ac4abe7e24325a78de3fe70c140395711127ee0076f9905222bcce'
ATMOSPHERE_AUDITED_SOURCE_SHA256={'scripts/source_hyperdrive.gd': 'b79cd38051e44d52fcd4f2beb173b2699096e7d9aea9a0288aba205e453a8874', 'scripts/navigation.gd': '2745b49c42b69a23679740f21bf31efdcab319d7eedff6de090aac854bd3f225', 'scripts/source_hyperdrive_session.gd': '0a0428071f8cfc188f80930474c804261626be6952d41a55b8399eb6b70c7bc8', 'scripts/hyperdrive_services_view.gd': '70d828f819faeb8c8e31d12e1101ef82ce5d306f9cf329b2902600f82b5fe3f7', 'scripts/main.gd': '62e77b1f2d64fcdd5e1604876f883965cae635df3906b895226549cab41b4f2b', 'scripts/galactic_map_model.gd': '597a5bd049e3dea2698bfbc255a0d57e7c98b70fabedfe09d56bb60ccd3a11a5', 'scripts/galactic_map_view.gd': '9a2a6fa97d9ab4f6ce572a5e10bb390d5036ccf6d30e3bc31e087a61440b7876', 'scripts/source_jet_fuel.gd': 'ef043cd3d7fe4ef06a08d1f6592bf97b5d1e6d81c5f2efe9ea067d514f207cc1', 'scripts/source_fuel_scoop.gd': 'de1e96fd3013de48557b340b9ca4e4d174c4d39aaebb8b2eee96250db53af296', 'scripts/source_fuel_contact.gd': '0f8d5defba15db89d02c5253c988a2a5680d7a16058296b91d262017d5a49903', 'scripts/source_fuel_flight_bridge.gd': '70921d3cb8b7d211f07f1211309f809dab1e0be9094ccf015e658558d6a04b52', 'scripts/flight_model.gd': '4bec7bd8448f7eb4f59436bcc45f09183736a274f5759124dbfa02dd5557264b', 'scripts/surface_model.gd': '28fcc37fb4adc1291129fdd90fb685828992e5657eaeb891eff986c9d5f3d894', 'scripts/source_motion_bridge.gd': '4fd81d7226e1c63f5c280e6ade6692b829bc5568937429a8ecac397949a003a5', 'scripts/source_atmospheric_dynamics.gd': 'a9ccce9fa27a2354205f3b1c88a9108320f567742d44d84082635339bc9af4a9', 'scripts/source_atmosphere_contact.gd': '5b048597421267adf2604617be09079dbd3d256c26572506e57ce3de7c3a87a9', 'scripts/flight_time_controller.gd': 'd171bb7354e57ae6349ac04775d6f640a932c0f061cba879bb044724f3d06d91'}
ATMOSPHERE_NATIVE_REFERENCE={'source_atmospheric_native': {'sha256': '04cff4bc5d43c7eabda2ed4361a0ee8c0221cc1c432c8ea2dd33daad0d3b9025', 'case_count': 1447}, 'source_atmosphere_speed_native': {'sha256': 'cbffa800bfbfa805f12480dbefe30888ed2f9d37cb8a3f07469fa0ae11dca57f', 'case_count': 239}}
ATMOSPHERE_DOS_PROCEDURES={'34': {'dos_file_offset': 13048, 'byte_count': 31, 'sha256': 'fbafd34f244fc54703ebc14e55a04731088dfd1a8462e87d99f4020b4ee63187', 'independently_normalized_instruction_count': 12}, '35': {'dos_file_offset': 13080, 'byte_count': 15, 'sha256': '96974c654576f4f30e03da8d77af820eb9b6b2e0ce0c037ab98b817e3c7e5866', 'independently_normalized_instruction_count': 6}, '953': {'dos_file_offset': 191868, 'byte_count': 436, 'sha256': 'aa8ec30bafd1e80ed164f34e8b384a2ff9e46d8eaf9a17239ee9065d84874469', 'independently_normalized_instruction_count': 131}, '1014': {'dos_file_offset': 202896, 'byte_count': 321, 'sha256': 'dcdc0bc325086ddaff36264342e39a703e41543d7e0badd4f067c3a5ce595095', 'independently_normalized_instruction_count': 94}, '1016': {'dos_file_offset': 203244, 'byte_count': 27, 'sha256': 'd11d23496ba03a43ce954ab8e0906dcb2f53cecfd8b2425911e2ccfc517137c5', 'independently_normalized_instruction_count': 10}, '1017': {'dos_file_offset': 203272, 'byte_count': 10, 'sha256': '2d8a6cf3a78899319464c62419cb1f5f1b36331ff4359fc1b1081d1ccbbea30a', 'independently_normalized_instruction_count': 6}, '1521': {'dos_file_offset': 279160, 'byte_count': 17, 'sha256': 'f62a5f949cbf8da772c3cc32ae59b607e0f35cda6c3c4e1ddf848ba3b5a1b445', 'independently_normalized_instruction_count': 9}, '1530': {'dos_file_offset': 279740, 'byte_count': 63, 'sha256': '35fb8bff8c10fc5628238eb1cfe0078393caf7fa1a4cdb6a6d28374e6edf0535', 'independently_normalized_instruction_count': 18}}

# Code43 adds a separate gear sibling; old code42 remains frozen above.
LANDING_GEAR_BASELINE_SOURCE_COMMIT='0ad404f25db0b54d42796457555c8e4dc7f2ad6d'
LANDING_GEAR_MODULES=('source_landing_gear','source_landing_gear_session')
LANDING_GEAR_RESOURCE_SHA256='f06d7184046407dea3ee45fb3c6dedeb6bfaf21fe1a6136a388a87fa97ed1f00'
LANDING_GEAR_UNCHANGED_SOURCE_SHA256={'scripts/source_hyperdrive.gd': 'b79cd38051e44d52fcd4f2beb173b2699096e7d9aea9a0288aba205e453a8874', 'scripts/navigation.gd': '2745b49c42b69a23679740f21bf31efdcab319d7eedff6de090aac854bd3f225', 'scripts/source_hyperdrive_session.gd': '0a0428071f8cfc188f80930474c804261626be6952d41a55b8399eb6b70c7bc8', 'scripts/hyperdrive_services_view.gd': '70d828f819faeb8c8e31d12e1101ef82ce5d306f9cf329b2902600f82b5fe3f7', 'scripts/galactic_map_model.gd': '597a5bd049e3dea2698bfbc255a0d57e7c98b70fabedfe09d56bb60ccd3a11a5', 'scripts/galactic_map_view.gd': '9a2a6fa97d9ab4f6ce572a5e10bb390d5036ccf6d30e3bc31e087a61440b7876', 'scripts/source_jet_fuel.gd': 'ef043cd3d7fe4ef06a08d1f6592bf97b5d1e6d81c5f2efe9ea067d514f207cc1', 'scripts/source_fuel_scoop.gd': 'de1e96fd3013de48557b340b9ca4e4d174c4d39aaebb8b2eee96250db53af296', 'scripts/source_fuel_contact.gd': '0f8d5defba15db89d02c5253c988a2a5680d7a16058296b91d262017d5a49903', 'scripts/source_fuel_flight_bridge.gd': '70921d3cb8b7d211f07f1211309f809dab1e0be9094ccf015e658558d6a04b52', 'scripts/flight_model.gd': '4bec7bd8448f7eb4f59436bcc45f09183736a274f5759124dbfa02dd5557264b', 'scripts/source_motion_bridge.gd': '4fd81d7226e1c63f5c280e6ade6692b829bc5568937429a8ecac397949a003a5', 'scripts/source_atmospheric_dynamics.gd': 'a9ccce9fa27a2354205f3b1c88a9108320f567742d44d84082635339bc9af4a9', 'scripts/flight_time_controller.gd': 'd171bb7354e57ae6349ac04775d6f640a932c0f061cba879bb044724f3d06d91'}
LANDING_GEAR_AUDITED_SOURCE_SHA256={'scripts/source_hyperdrive.gd': 'b79cd38051e44d52fcd4f2beb173b2699096e7d9aea9a0288aba205e453a8874', 'scripts/navigation.gd': '2745b49c42b69a23679740f21bf31efdcab319d7eedff6de090aac854bd3f225', 'scripts/source_hyperdrive_session.gd': '0a0428071f8cfc188f80930474c804261626be6952d41a55b8399eb6b70c7bc8', 'scripts/hyperdrive_services_view.gd': '70d828f819faeb8c8e31d12e1101ef82ce5d306f9cf329b2902600f82b5fe3f7', 'scripts/galactic_map_model.gd': '597a5bd049e3dea2698bfbc255a0d57e7c98b70fabedfe09d56bb60ccd3a11a5', 'scripts/galactic_map_view.gd': '9a2a6fa97d9ab4f6ce572a5e10bb390d5036ccf6d30e3bc31e087a61440b7876', 'scripts/source_jet_fuel.gd': 'ef043cd3d7fe4ef06a08d1f6592bf97b5d1e6d81c5f2efe9ea067d514f207cc1', 'scripts/source_fuel_scoop.gd': 'de1e96fd3013de48557b340b9ca4e4d174c4d39aaebb8b2eee96250db53af296', 'scripts/source_fuel_contact.gd': '0f8d5defba15db89d02c5253c988a2a5680d7a16058296b91d262017d5a49903', 'scripts/source_fuel_flight_bridge.gd': '70921d3cb8b7d211f07f1211309f809dab1e0be9094ccf015e658558d6a04b52', 'scripts/flight_model.gd': '4bec7bd8448f7eb4f59436bcc45f09183736a274f5759124dbfa02dd5557264b', 'scripts/source_motion_bridge.gd': '4fd81d7226e1c63f5c280e6ade6692b829bc5568937429a8ecac397949a003a5', 'scripts/source_atmospheric_dynamics.gd': 'a9ccce9fa27a2354205f3b1c88a9108320f567742d44d84082635339bc9af4a9', 'scripts/flight_time_controller.gd': 'd171bb7354e57ae6349ac04775d6f640a932c0f061cba879bb044724f3d06d91', 'scripts/main.gd': 'f0b46207ef64b6c95b495ad01d47b11263d560774f7e49c1bca4ec5d0d942db6', 'scripts/surface_model.gd': '6b03d8625bdddd4f552aea4640010a62ab7f2f51c8b087d75d66d07f61f1ae8f', 'scripts/source_atmosphere_contact.gd': '046dcfbb3ad3f2c937f023aa5268e239b9c668e9a943ce6a51502ad7b35392be', 'scripts/flight_console.gd': '0a9fe99fd5e4f2cfb276e476a8a12c141cbb9b74a92cd246c4dcfa9cc4180c54', 'scripts/ship_visual.gd': '5c175408f1687ecb440296e62051884a79503a4903965d16bd8dbba66934dd88', 'scripts/source_landing_gear.gd': '0a65184b0e02f6a578e9d4bc12124a87585241e25598020b351494059af05b6a', 'scripts/source_landing_gear_session.gd': 'ba8b63cbf89f30441f0bdfe01ed51af3a7e0e4679451264826039dd7b65887a0'}
LANDING_GEAR_UNCHANGED_SURFACE_FUNCTION_SHA256={'height_at': 'b4334a9bcd40d059ab4e69326963118334ca87d80cfee80f94424056591885e5', '_grounded_height': '728f9b6b466644452c0813868ba1fad567b4860a1960b99fe65ebbfcc6056132', 'clearance': '32ff5539b2bd849931ed72fc4855f42975dda12749996378d79abf01c4b378c8', 'take_off': '3e21f47dc06320aefe0c4dbf4b107d94c389246a48829fe7bf4219d73dfbecaa', 'restore': '7e16930659abbe68b434a2757fe1dc4e17698e6114dfc64df26db05665b70caa', 'snapshot': 'd7be5cf06115a101bc396e0c0c7a50a748937368498dd5b2acb1547906e41863', 'create_entry_snapshot': '3d669383e97c0d052b7767f9c8cd6f5a7f51b3b9780e96179838ce9dc87a8c16', 'prepare_entry': 'cbb9d056a9f04abb38e49b5a0aac3ece7cf63cda8d94376dce8a3ab47c7ebdb7', 'begin_ascent': 'c4f8f5270ba355b824a0e99ae6d8eaed9eae4105bf0146ab52372e42b20d034e'}
LANDING_GEAR_DOS_ANCHORS={'1008': {'dos_file_offset': 202128, 'byte_count': 305, 'sha256': '6d0a8a82a36809b64f58568ad7ef7c29e2b767f8091e06d47536e04adab41e97', 'independently_normalized_instruction_count': 72}, '1056_4410': {'dos_file_offset': 213146, 'byte_count': 116, 'sha256': '4262147506224b00e3d94d2febdfed3f690773655f90439d724e8f393ba61107', 'independently_normalized_instruction_count': 32}}
LANDING_GEAR_SUPPORTING_ANCHORS={'1009_call_order': {'dos_file_offset': 202524, 'byte_count': 26, 'sha256': 'e8595087e9d8024083bd4a947051337dcedbb9bf0fbf0548c6015f4560713f9b', 'independently_normalized_instruction_count': 8}, '575_landing_predicate': {'dos_file_offset': 100049, 'byte_count': 27, 'sha256': '99d87ce24619fcba14d99c78cd37b0a24a41fc2b334d591f0e7bc53383d08c7b', 'independently_normalized_instruction_count': 6}}
LANDING_GEAR_NATIVE_REFERENCE_SHA256='3690144d57048c2be03fa5e70ffd193a57edef38e0602126c17b857834439a16'

# Code44 adds only the bounded player continuation and explicit phone bridge.
SURFACE_CONTACT_BASELINE_SOURCE_COMMIT='faa22eaee504b324b096d64c059d9daf670eca9c'
SURFACE_CONTACT_MODULES=('source_surface_contact','source_surface_contact_bridge')
SURFACE_CONTACT_RESOURCE_SHA256='960931e58ac1fe73428956b87f8567e29ea554c84793e33e1e86852f060050e6'
SURFACE_CONTACT_NATIVE_REFERENCE_SHA256='a4c23ec94860641f18bb3632189346f3a264834904532bd24bed0e980e3ebeef'
SURFACE_CONTACT_RUNTIME_DESCRIPTOR_SHA256='cf9c673c2bba22f0c865e77e3a7ceed5497053cdb444b80f31d7439176446818'
SURFACE_CONTACT_UNCHANGED_SOURCE_SHA256={'scripts/source_hyperdrive.gd': 'b79cd38051e44d52fcd4f2beb173b2699096e7d9aea9a0288aba205e453a8874', 'scripts/hyperdrive_services_view.gd': '70d828f819faeb8c8e31d12e1101ef82ce5d306f9cf329b2902600f82b5fe3f7', 'scripts/galactic_map_model.gd': '597a5bd049e3dea2698bfbc255a0d57e7c98b70fabedfe09d56bb60ccd3a11a5', 'scripts/galactic_map_view.gd': '9a2a6fa97d9ab4f6ce572a5e10bb390d5036ccf6d30e3bc31e087a61440b7876', 'scripts/source_jet_fuel.gd': 'ef043cd3d7fe4ef06a08d1f6592bf97b5d1e6d81c5f2efe9ea067d514f207cc1', 'scripts/source_fuel_scoop.gd': 'de1e96fd3013de48557b340b9ca4e4d174c4d39aaebb8b2eee96250db53af296', 'scripts/source_fuel_contact.gd': '0f8d5defba15db89d02c5253c988a2a5680d7a16058296b91d262017d5a49903', 'scripts/source_fuel_flight_bridge.gd': '70921d3cb8b7d211f07f1211309f809dab1e0be9094ccf015e658558d6a04b52', 'scripts/flight_model.gd': '4bec7bd8448f7eb4f59436bcc45f09183736a274f5759124dbfa02dd5557264b', 'scripts/source_motion_bridge.gd': '4fd81d7226e1c63f5c280e6ade6692b829bc5568937429a8ecac397949a003a5', 'scripts/source_atmospheric_dynamics.gd': 'a9ccce9fa27a2354205f3b1c88a9108320f567742d44d84082635339bc9af4a9', 'scripts/flight_time_controller.gd': 'd171bb7354e57ae6349ac04775d6f640a932c0f061cba879bb044724f3d06d91', 'scripts/source_atmosphere_contact.gd': '046dcfbb3ad3f2c937f023aa5268e239b9c668e9a943ce6a51502ad7b35392be', 'scripts/flight_console.gd': '0a9fe99fd5e4f2cfb276e476a8a12c141cbb9b74a92cd246c4dcfa9cc4180c54', 'scripts/ship_visual.gd': '5c175408f1687ecb440296e62051884a79503a4903965d16bd8dbba66934dd88', 'scripts/source_landing_gear.gd': '0a65184b0e02f6a578e9d4bc12124a87585241e25598020b351494059af05b6a', 'scripts/source_landing_gear_session.gd': 'ba8b63cbf89f30441f0bdfe01ed51af3a7e0e4679451264826039dd7b65887a0'}
SURFACE_CONTACT_AUDITED_SOURCE_SHA256={'scripts/source_hyperdrive.gd': 'b79cd38051e44d52fcd4f2beb173b2699096e7d9aea9a0288aba205e453a8874', 'scripts/hyperdrive_services_view.gd': '70d828f819faeb8c8e31d12e1101ef82ce5d306f9cf329b2902600f82b5fe3f7', 'scripts/galactic_map_model.gd': '597a5bd049e3dea2698bfbc255a0d57e7c98b70fabedfe09d56bb60ccd3a11a5', 'scripts/galactic_map_view.gd': '9a2a6fa97d9ab4f6ce572a5e10bb390d5036ccf6d30e3bc31e087a61440b7876', 'scripts/source_jet_fuel.gd': 'ef043cd3d7fe4ef06a08d1f6592bf97b5d1e6d81c5f2efe9ea067d514f207cc1', 'scripts/source_fuel_scoop.gd': 'de1e96fd3013de48557b340b9ca4e4d174c4d39aaebb8b2eee96250db53af296', 'scripts/source_fuel_contact.gd': '0f8d5defba15db89d02c5253c988a2a5680d7a16058296b91d262017d5a49903', 'scripts/source_fuel_flight_bridge.gd': '70921d3cb8b7d211f07f1211309f809dab1e0be9094ccf015e658558d6a04b52', 'scripts/flight_model.gd': '4bec7bd8448f7eb4f59436bcc45f09183736a274f5759124dbfa02dd5557264b', 'scripts/source_motion_bridge.gd': '4fd81d7226e1c63f5c280e6ade6692b829bc5568937429a8ecac397949a003a5', 'scripts/source_atmospheric_dynamics.gd': 'a9ccce9fa27a2354205f3b1c88a9108320f567742d44d84082635339bc9af4a9', 'scripts/flight_time_controller.gd': 'd171bb7354e57ae6349ac04775d6f640a932c0f061cba879bb044724f3d06d91', 'scripts/source_atmosphere_contact.gd': '046dcfbb3ad3f2c937f023aa5268e239b9c668e9a943ce6a51502ad7b35392be', 'scripts/flight_console.gd': '0a9fe99fd5e4f2cfb276e476a8a12c141cbb9b74a92cd246c4dcfa9cc4180c54', 'scripts/ship_visual.gd': '5c175408f1687ecb440296e62051884a79503a4903965d16bd8dbba66934dd88', 'scripts/source_landing_gear.gd': '0a65184b0e02f6a578e9d4bc12124a87585241e25598020b351494059af05b6a', 'scripts/source_landing_gear_session.gd': 'ba8b63cbf89f30441f0bdfe01ed51af3a7e0e4679451264826039dd7b65887a0', 'scripts/main.gd': 'ad3cde5417c04c042f729cd3a391d7a996f048990e26c8cf7cf66d2b8637d09f', 'scripts/navigation.gd': '5f689fce7b1f899c4a39e95add22dd59a8b9ba2909ccfec2d7bf18a74698f3c6', 'scripts/source_hyperdrive_session.gd': '931427fe16367c8a7d32fdfbb554e14ef64987a477fa8e275a75122aa1505c14', 'scripts/surface_model.gd': '449155f904b72e6c97e430b90b78d1859c6d6a27017f297620552e5094eb32ff', 'scripts/source_surface_contact.gd': 'fcfb6077f0bcabf7b6ffce98c3a3dbb23251a850175be4ef241b299fdf8d117d', 'scripts/source_surface_contact_bridge.gd': 'f83bbecc35c60bfaf79cf2314d067f997b966258665a41a93f082534ba7dfdd9'}
SURFACE_CONTACT_PROVIDER_DEPENDENCY_SHA256={'scripts/source_surface_render_state.gd': '91eca62418b0f3bf48d10cf1af9286688e9cd8b0ab6a214c77df9070396465f4', 'scripts/source_surface_render_packet.gd': '1371064fbbd00010567c2a7ae8552254540a22f3e382bba4cfd16f68fa99273e', 'scripts/source_surface_contact_patch.gd': 'a0c2dfe0442cdb33498ccd9e92cf5bb0c3b23f0fef06de71358bcfe668e15d0a', 'scripts/source_surface_terrain.gd': '5c2939f5dae7adfa08e7591980612d6e53fd6fcdcf321850d00d388982024a17', 'scripts/source_city_runtime.gd': 'a0a5bcbfc37adda1d46ff968c88eac752ccddbe268556520dbf2c83c7b1f12ba', 'scripts/source_underground_controller.gd': '08128b223be3d28db23523fe1080c6aa29c69f07f62bcba9bd71e29188dfb1b8', 'scripts/source_underground_port.gd': 'a23791197ec0cebf635367f68b4a26483f374d96c7ad4c037afef51386ebc596', 'scripts/source_model_mesh.gd': '6642ce62a1a8046c71a57fb08325304c8d12c3bc61b90921d458ef84ad21472e', 'scripts/source_city_profile.gd': 'b5015f8252aa611cc9a2c93158495a3d12d6bad66affbd5635d501cbaa96d8b4', 'scripts/segment_triangle.gd': 'c1f000e1481ba9654ab9cf27db7b30e6eaeef46a35d533a01dffb2d86bece346', 'scripts/source_ground_pads.gd': '2de5cec29b7e69be5d3f4f6652386bd7a5ff80ac84ce1367feb07fcf5fc24cbb', 'scripts/source_model_vm.gd': '2ee0a4743bb497de34310e0fef9823d3558e13d36fd38e8d235788bb74b3f3f2', 'scripts/source_model_vertices.gd': 'bfd236cbee940167f882a85a461911aad672fd7c292b6f58619e87cf6ecc7e33', 'scripts/source_polygon.gd': '9e83a719b5a13a22fcba53417cb3c4006d310804eda3e69aba543a9551c07a43', 'scripts/source_station_geometry.gd': '5785d288a3a0582dc4f06db53fad4b6d52446d3d476adc894fa9b7624cf69b94', 'data/ffe_ground_pads.json': '4d582c012349360d7fbee5bd0cf8285b904c491161d5553d5c7bc705ee2ef4ba', 'data/ffe_ground_coordinates.json': 'e94e9ec86761aa1d775498a2959af201f3c6497506da481c9d49ca7f27766abf'}
SURFACE_CONTACT_UNCHANGED_STATE_FUNCTION_SHA256={'scripts/source_hyperdrive_session.gd': {'_valid_fuel': 'd934d420a156117f2b901fcddbdb8f122eec0e6b46b44b40e07dc706baeaeb11', '_valid_thermal': 'c67fbe48b898db1cc91a0dac81b74b3cd395fe045ce8241a68da220df5902ea3', 'hyperdrive_snapshot': 'd705cd2afe6173961d21f21fa2cd4225c1a63263ec868be1b71c60b29baae4aa', 'snapshot': '3c94d3d679ac5eedff346eef1983497f5b47e0e1b090405c4286a92f7e6f2f66', 'restore': '97eeb8599e7c03000aafa13d7f9532bb911204fed587bc7e511148f805011668', '_apply_damage_call': 'df3f22ba220d68d985927d8eb63750bb6171fadcde7030d270f1eba72ae9e7ed', '_fixed_thermal_seconds': 'cde9f6f300b41ef2d7a931b0be10ef8ff8be5bd731420348287e3abddf30447c', '_thermal_context': 'f1c69fad30ab4bbbe2edd7b48367c843522e93612574df616cf460531a1335da', '_thermal_step_inplace': '82f2b8542ba34c493f644bfe0c38888c8d2ed84f619e0300c5c0f2990790e47a'}, 'scripts/navigation.gd': {'_pending_for': 'cb9483134294c729d223106050e769f70f5de95985c450a55651a5fb81aef5fa', '_restore_source': 'aaa41a0c1f9e691aec525de14bc7207103a92844fd15e2e9774157122a8b3936', '_commit_fuel_result': '5e6768913db17047e16b3c3c1b593abf071f080c3c914aee2ccdc5008402b3df', 'snapshot': '603ad05749dbcb33760a625008c19d83c3ab2ff3d30ec2492e5517249d3c25dd'}}
SURFACE_CONTACT_DOS_ANCHORS={'575_postclassification': {'dos_file_offset': 99829, 'byte_count': 1657, 'sha256': '56d9e671bd0b831b6364ab1927351594d33b02967342ce401261388e65807785', 'disassembled_instruction_count': 518}, '575_full_static_only': {'dos_file_offset': 99488, 'byte_count': 2005, 'sha256': '33e2895597b23f2e12a3fc6f8c09a08c73042eb26f3529a2b1d911d12b77b015', 'disassembled_instruction_count': 635}, '578_excluded_variant': {'dos_file_offset': 102328, 'byte_count': 416, 'sha256': 'c5234844446da9de83bff6aa3ebe81bb64ec510a02d8b4a4b6503461c1c91f83', 'disassembled_instruction_count': 114}}
SURFACE_CONTACT_INSTRUCTION_PROOFS={'571': {'executable_offset': 99040, 'byte_length': 75, 'sha256': 'd6f72bd663b601a5c0292f2b3e52cd5025762d68c77f4fccaf3fb7334abfdda6', 'instruction_count': 28}, '1333': {'executable_offset': 259606, 'byte_length': 25, 'sha256': '8946c4ccd895806bb39d3d393c582970d2e34c8ba60c06257447eb10186e5468', 'instruction_count': 11}, '1335': {'executable_offset': 259656, 'byte_length': 25, 'sha256': '630251ee2b7c42186d7b3e5a7dad2245d537527943aa08e08cfe6879016c0514', 'instruction_count': 11}, '1503': {'executable_offset': 276874, 'byte_length': 60, 'sha256': 'd0afd5b854572fc1f0c76c0e0baf449afecd09a825f1962dd0d1183c8612e36d', 'instruction_count': 26}, '1504': {'executable_offset': 276934, 'byte_length': 105, 'sha256': '3086b86ae6eed52dcb62404ed6eecc861949b851139ae9cd621ba08e88414e09', 'instruction_count': 45}, '1501': {'executable_offset': 276671, 'byte_length': 64, 'sha256': '422940485e22b08f5173b3b64ada177be0a09e4ba2dc8599b8b36ecdee8cff04', 'instruction_count': 31}, '1502': {'executable_offset': 276735, 'byte_length': 139, 'sha256': '06d92dfc59b6eca45c8c8c4d203e1deb6a270101894bdea28ca83b692dc60d19', 'instruction_count': 61}, '1519': {'executable_offset': 278938, 'byte_length': 136, 'sha256': '4cf67a734da229a0a8cb12b509f70668250b4b0f3836a19146b53b0272e78ea3', 'instruction_count': 59}, '1466': {'executable_offset': 269559, 'byte_length': 272, 'sha256': 'd8afc05d10b13f7872438dd3a1e13e11ccc15dd0b55881fa120ef8781055cf10', 'instruction_count': 103}, '1520': {'executable_offset': 279074, 'byte_length': 86, 'sha256': '97176815c1009869daef82477468f18dd21c7dccac64b5a3714d84295f281976', 'instruction_count': 37}, '1521': {'executable_offset': 279160, 'byte_length': 17, 'sha256': 'f62a5f949cbf8da772c3cc32ae59b607e0f35cda6c3c4e1ddf848ba3b5a1b445', 'instruction_count': 9}, '1522': {'executable_offset': 279177, 'byte_length': 12, 'sha256': 'e6001a066c6ed54cff7bf995d82867c4b0809fa6752fdfb96247378823c29291', 'instruction_count': 7}, '1523': {'executable_offset': 279189, 'byte_length': 33, 'sha256': 'e393035168c327e2d7c04e94b55828696681e5f6eabbab45e27c103d00f712af', 'instruction_count': 16}, '1538': {'executable_offset': 281168, 'byte_length': 15, 'sha256': '7f8a8207c382290494a4d7fabdc00b15b17b0c51b7e9185cd4a3ae9f4cfb1226', 'instruction_count': 6}, '1552': {'executable_offset': 282920, 'byte_length': 157, 'sha256': '7977b9c88ca60678c48bd16343b74af7de283391e7ac94a49c27aa269eb4ee2d', 'instruction_count': 69}, '1656': {'executable_offset': 305076, 'byte_length': 74, 'sha256': '8bdce1d3d508b9cbf7d5fcbbf261407789d7bbf8fd917a4225db88c6d5aa2949', 'instruction_count': 29}, '1658': {'executable_offset': 305360, 'byte_length': 44, 'sha256': '6bdbafa74820fd4a83d1e5dfdb85032acacc6fd0e1636b481ac3f18af1ad065f', 'instruction_count': 23}, '1657': {'executable_offset': 305152, 'byte_length': 207, 'sha256': '86d7da85e49ea3ddca538301d8ff1595065c0fb8e2a52ad7dd1b35b68bcbd6ff', 'instruction_count': 84}, '1660': {'executable_offset': 305752, 'byte_length': 177, 'sha256': 'e23941156e2eb6f1c53020a82a29d6537e6be0b7a6af446323409fb93e3be0cc', 'instruction_count': 74}, '575_postclassification': {'executable_offset': 99829, 'byte_length': 1657, 'sha256': '56d9e671bd0b831b6364ab1927351594d33b02967342ce401261388e65807785', 'instruction_count': 518}, 'abs': {'executable_offset': 421944, 'byte_length': 22, 'sha256': '46c8a9d0c4e7b862f57c083615031c907a391a2166724a009057ab580d4c0795', 'instruction_count': 12}}

SPHERICAL_CONTACT_BASELINE_SOURCE_COMMIT='86a4a5e2a44c73d610d8a35f7fda7e393343991e'
SPHERICAL_CONTACT_MODULES=('source_spherical_contact','source_spherical_contact_pipeline','source_spherical_contact_probe')
SPHERICAL_CONTACT_RESOURCE_SHA256='e0fe32fe24ec2a0bb036aca3ee2afd1cb890bee1a976ffe58ffbee68ce42a07f'
SPHERICAL_CONTACT_NATIVE_REFERENCE_SHA256='37a9c51bf5d1b9dbb74343e3863d7672cca009985bfd89a557f22993fb9059c4'
SPHERICAL_CONTACT_PIPELINE_REFERENCE_SHA256='4334c5f9583d50938ba8cbd8a57cc1a977c0f84a2f6a28482c284699fa3dc0ac'
NATURAL_CONTACT_BASELINE_SOURCE_COMMIT='e3b9369230085ef7c15ab974d8e8de84eda1a991'
NATURAL_CONTACT_MODULES=('source_natural_contact','source_natural_contact_pipeline','source_natural_contact_probe')
NATURAL_CONTACT_RESOURCE_SHA256='0074a49df9f22879a4eefbef6dda183cbb517243792dd8d086cb782c2da5603e'
NATURAL_CONTACT_GROUND_RESOURCE_SHA256='2dbf44a94422907b1bb29b34df1d795cef819cecf267b1591f3d82ea6326d018'
SPHERICAL_CONTACT_AUDITED_SOURCE_SHA256={**SURFACE_CONTACT_AUDITED_SOURCE_SHA256,
    'scripts/main.gd':'4d219628aac3fda5f217da57f26f6c65d5144950899c5aa031a8f736b35722aa',
    'scripts/source_spherical_contact.gd':'d5b484d6e5c6c6802c896fbb12df9cf13a6a7a79c8b9292dae9b31df3b772a77',
    'scripts/source_spherical_contact_pipeline.gd':'60361ad6f22a13fc31d8b03f28e924391a4b7d9510b9618a8993da7b8249186b',
    'scripts/source_spherical_contact_probe.gd':'dc320da753e778e6ebd69c01ea60a15c37df6cceceaf0fe93289c0fe95846883'}
NATURAL_CONTACT_AUDITED_SOURCE_SHA256={**SPHERICAL_CONTACT_AUDITED_SOURCE_SHA256,
    'scripts/main.gd':'91e21ef682be19fe07ce4ac970829bb01f767b6e9eab551d8f248706f0f43a82',
    'scripts/source_natural_contact.gd':'e6cb189d34dc4d434b10f9fc2ef43bf8b96433845c01673f79b4d9592446658f',
    'scripts/source_natural_contact_pipeline.gd':'8d981b53f301dd375f22faae89a439673a3f94a98278cbb2161075a85ae125be',
    'scripts/source_natural_contact_probe.gd':'ee163acac97707333e5b8234987dd82a071791b36a92c3c518ad32fc1ee6977c'}
NATURAL_CONTACT_NATIVE_REFERENCE_SHA256='d4ce0cf3ebfe0fd3bb1f263d047fa3a17ffc5201b8040389fdbddcc21a50e166'
NATURAL_CONTACT_NATIVE_CASE_COUNT=993
NATURAL_CONTACT_PRIMARY_PROOFS={
    '576':(101496,466,'2b8ae8b0a52f16b8fb101879618218e83dd9852ccecb97090c7cb3f611439227',159),
    '579':(102744,215,'f535e8001ef4989a30b2189a20157425ce67970d55959a6b06bae7a64902c218',87),
    '581':(103404,1542,'a5559afa26a9783d6df67b558cd84d69e35158844c1a00cc81a75bcb0be766f0',533),
    '582':(104948,653,'a216b90c8dcac7e7601fcf57ea6c2afbc2d9a02111a051d1da4da1293901b4b4',243),
}
CONTACT_ALIGNMENT_BASELINE_SOURCE_COMMIT='2637168f2371937758504a54b9e17c11d279c82e'
CONTACT_ALIGNMENT_BASELINE_FIXTURE_SHA256='36c864a535d12398d5fa9427fbdafcf24f0638c94a3d1ea8cb5328368c848b16'
CONTACT_ALIGNMENT_MODULES=('source_terrain_contact_field','source_contact_surface_terrain','source_natural_surface_bridge','source_contact_alignment_probe')
CONTACT_ALIGNMENT_PROVIDER_SOURCE_SHA256={'scripts/source_surface_render_packet.gd': '1371064fbbd00010567c2a7ae8552254540a22f3e382bba4cfd16f68fa99273e', 'scripts/source_surface_render_state.gd': '91eca62418b0f3bf48d10cf1af9286688e9cd8b0ab6a214c77df9070396465f4', 'scripts/source_surface_contact_patch.gd': 'a0c2dfe0442cdb33498ccd9e92cf5bb0c3b23f0fef06de71358bcfe668e15d0a', 'scripts/source_global_body_mesh.gd': 'c0101d6e2b442e5dd0e469f0c8d07272f038e9a6bb1e4016ddec1815949974d6', 'scripts/surface_visual.gd': 'b94c8f3eac101e7fc95ad4633236c9db877f6d5e39b7cd1fe414f577bc45227e', 'scripts/celestial_renderer.gd': 'c084f772a420a8b625488ce176e87532833c4677e26da2a669939a437c01448e'}
CONTACT_ALIGNMENT_AUDITED_SOURCE_SHA256={'scripts/source_hyperdrive.gd': 'b79cd38051e44d52fcd4f2beb173b2699096e7d9aea9a0288aba205e453a8874', 'scripts/hyperdrive_services_view.gd': '70d828f819faeb8c8e31d12e1101ef82ce5d306f9cf329b2902600f82b5fe3f7', 'scripts/galactic_map_model.gd': '597a5bd049e3dea2698bfbc255a0d57e7c98b70fabedfe09d56bb60ccd3a11a5', 'scripts/galactic_map_view.gd': '9a2a6fa97d9ab4f6ce572a5e10bb390d5036ccf6d30e3bc31e087a61440b7876', 'scripts/source_jet_fuel.gd': 'ef043cd3d7fe4ef06a08d1f6592bf97b5d1e6d81c5f2efe9ea067d514f207cc1', 'scripts/source_fuel_scoop.gd': 'de1e96fd3013de48557b340b9ca4e4d174c4d39aaebb8b2eee96250db53af296', 'scripts/source_fuel_contact.gd': '0f8d5defba15db89d02c5253c988a2a5680d7a16058296b91d262017d5a49903', 'scripts/source_fuel_flight_bridge.gd': '70921d3cb8b7d211f07f1211309f809dab1e0be9094ccf015e658558d6a04b52', 'scripts/flight_model.gd': '4bec7bd8448f7eb4f59436bcc45f09183736a274f5759124dbfa02dd5557264b', 'scripts/source_motion_bridge.gd': '4fd81d7226e1c63f5c280e6ade6692b829bc5568937429a8ecac397949a003a5', 'scripts/source_atmospheric_dynamics.gd': 'a9ccce9fa27a2354205f3b1c88a9108320f567742d44d84082635339bc9af4a9', 'scripts/flight_time_controller.gd': 'd171bb7354e57ae6349ac04775d6f640a932c0f061cba879bb044724f3d06d91', 'scripts/source_atmosphere_contact.gd': '046dcfbb3ad3f2c937f023aa5268e239b9c668e9a943ce6a51502ad7b35392be', 'scripts/flight_console.gd': '0a9fe99fd5e4f2cfb276e476a8a12c141cbb9b74a92cd246c4dcfa9cc4180c54', 'scripts/ship_visual.gd': '5c175408f1687ecb440296e62051884a79503a4903965d16bd8dbba66934dd88', 'scripts/source_landing_gear.gd': '0a65184b0e02f6a578e9d4bc12124a87585241e25598020b351494059af05b6a', 'scripts/source_landing_gear_session.gd': 'ba8b63cbf89f30441f0bdfe01ed51af3a7e0e4679451264826039dd7b65887a0', 'scripts/main.gd': '7713e18fc3b98603a4e772e9079a5b048b087ad0d6bdeb914f583730f8d7f457', 'scripts/navigation.gd': '5f689fce7b1f899c4a39e95add22dd59a8b9ba2909ccfec2d7bf18a74698f3c6', 'scripts/source_hyperdrive_session.gd': '931427fe16367c8a7d32fdfbb554e14ef64987a477fa8e275a75122aa1505c14', 'scripts/surface_model.gd': 'd96a20c9be21f4113975cd522e360963cb0b29a1ac75e27ed43b8b8d95edb445', 'scripts/source_surface_contact.gd': 'fcfb6077f0bcabf7b6ffce98c3a3dbb23251a850175be4ef241b299fdf8d117d', 'scripts/source_surface_contact_bridge.gd': 'f83bbecc35c60bfaf79cf2314d067f997b966258665a41a93f082534ba7dfdd9', 'scripts/source_spherical_contact.gd': 'd5b484d6e5c6c6802c896fbb12df9cf13a6a7a79c8b9292dae9b31df3b772a77', 'scripts/source_spherical_contact_pipeline.gd': '60361ad6f22a13fc31d8b03f28e924391a4b7d9510b9618a8993da7b8249186b', 'scripts/source_spherical_contact_probe.gd': 'dc320da753e778e6ebd69c01ea60a15c37df6cceceaf0fe93289c0fe95846883', 'scripts/source_natural_contact.gd': 'e6cb189d34dc4d434b10f9fc2ef43bf8b96433845c01673f79b4d9592446658f', 'scripts/source_natural_contact_pipeline.gd': '8d981b53f301dd375f22faae89a439673a3f94a98278cbb2161075a85ae125be', 'scripts/source_natural_contact_probe.gd': 'ee163acac97707333e5b8234987dd82a071791b36a92c3c518ad32fc1ee6977c', 'scripts/source_surface_render_packet.gd': 'e04552b706b8c4b89f53280e9e96afa73ede777e8719cf0b4c6587479b1b84f5', 'scripts/source_surface_render_state.gd': '0f71658a283e2e6afa6eeea4e496b447565469242cfa7222e12618caa9b58b4a', 'scripts/source_surface_contact_patch.gd': '7a34e21fab9db0d379f4866d3193cb0f32723e714ca4bebfd03cabec36a40744', 'scripts/source_global_body_mesh.gd': 'dc7bdced64514126be8c92d4907fef4e92d245a073881832c64093ff37ae6721', 'scripts/surface_visual.gd': 'f5bdaf925ac522fdf08edd4141ecbd5bc46418e978a3792b253866935bde4432', 'scripts/celestial_renderer.gd': '8930c20b150de0019f55ca8aa2c4dd84ba9bde03d164fd7cd5bc8572505de492', 'scripts/surface_orbit_link.gd': '52d8bbfd7de127dea1c9a46394877f8e06ae988db4d035b262c9319d28b4a40a', 'scripts/source_terrain_contact_field.gd': 'e6de88193bd96912587f0b653b96e058357a4d157017c8f82ce86f7be42e9bf3', 'scripts/source_contact_alignment_probe.gd': '7347ff488e5525aded65f36c17235f433c53942a5ac93a10b3c5cf1143c98dd8', 'scripts/source_contact_surface_terrain.gd': '50faef7f781117f1e3b8d6fe4c96146d3af3dc0074bf42283a882c9093c9abac', 'scripts/source_natural_surface_bridge.gd': 'a67cb675c93f052bd00a2268e0629ae729c6c975f0419d105f6c60b90c2d7686'}
CONTACT_ALIGNMENT_FIELD_REFERENCE_SHA256='6cb84a1f6dff615a504c9cac7935f339291831b62a658971110a03c1cb7b6db6'
CONTACT_ALIGNMENT_RENDER_TEST_SHA256='34098086bb055ea91688e2253936511efa7a00e118797233d3296e3fe5c5cd3c'
CONTACT_ALIGNMENT_V4_PATCH_CHECKSUM='6110d64354fc6e79f258e75c6d08a3fb376bb7fdc2ca3adb44b13ce0ff4638cf'
CONTACT_ALIGNMENT_V4_GLOBAL_KEY='d9b811fa801e29bbe96ea7742fdca368181a5d6a174a978cc102e068ee33ed14'
CONTACT_ALIGNMENT_PROTECTED_KERNEL_DATA_SHA256={**FUEL_CONTACT_DEPENDENCY_SHA256,
    'scripts/source_surface_terrain.gd':SURFACE_CONTACT_PROVIDER_DEPENDENCY_SHA256['scripts/source_surface_terrain.gd'],'scripts/game_diagnostics.gd':'ec43f79d0971680225f0555ac9d7f6e60f41806257bae7e9c1bff8a4f73c0fc3'}
SPHERICAL_CONTACT_INSTRUCTION_PROOFS={'577': {'executable_offset': 101964, 'byte_length': 363, 'sha256': 'f2bb5974c51d801bf5c219f697cf16716250a296f744e54fed61a6c26131e790', 'instruction_count': 128}, '1333': {'executable_offset': 259606, 'byte_length': 25, 'sha256': '8946c4ccd895806bb39d3d393c582970d2e34c8ba60c06257447eb10186e5468', 'instruction_count': 11}, '1341': {'executable_offset': 259928, 'byte_length': 127, 'sha256': 'ce1f10cd3645a7e74e65b774758ad6160e67cc67d19b0ad4cbfa77dbcc454ef3', 'instruction_count': 57}, '1502': {'executable_offset': 276735, 'byte_length': 139, 'sha256': '06d92dfc59b6eca45c8c8c4d203e1deb6a270101894bdea28ca83b692dc60d19', 'instruction_count': 61}, '1522': {'executable_offset': 279177, 'byte_length': 12, 'sha256': 'e6001a066c6ed54cff7bf995d82867c4b0809fa6752fdfb96247378823c29291', 'instruction_count': 7}, '1656': {'executable_offset': 305076, 'byte_length': 74, 'sha256': '8bdce1d3d508b9cbf7d5fcbbf261407789d7bbf8fd917a4225db88c6d5aa2949', 'instruction_count': 29}, '1660': {'executable_offset': 305752, 'byte_length': 177, 'sha256': 'e23941156e2eb6f1c53020a82a29d6537e6be0b7a6af446323409fb93e3be0cc', 'instruction_count': 74}}
SPHERICAL_CONTACT_PIPELINE_INSTRUCTION_PROOFS={'571': {'executable_offset': 99040, 'byte_length': 75, 'sha256': 'd6f72bd663b601a5c0292f2b3e52cd5025762d68c77f4fccaf3fb7334abfdda6', 'instruction_count': 28}, '1333': {'executable_offset': 259606, 'byte_length': 25, 'sha256': '8946c4ccd895806bb39d3d393c582970d2e34c8ba60c06257447eb10186e5468', 'instruction_count': 11}, '1335': {'executable_offset': 259656, 'byte_length': 25, 'sha256': '630251ee2b7c42186d7b3e5a7dad2245d537527943aa08e08cfe6879016c0514', 'instruction_count': 11}, '1503': {'executable_offset': 276874, 'byte_length': 60, 'sha256': 'd0afd5b854572fc1f0c76c0e0baf449afecd09a825f1962dd0d1183c8612e36d', 'instruction_count': 26}, '1504': {'executable_offset': 276934, 'byte_length': 105, 'sha256': '3086b86ae6eed52dcb62404ed6eecc861949b851139ae9cd621ba08e88414e09', 'instruction_count': 45}, '1501': {'executable_offset': 276671, 'byte_length': 64, 'sha256': '422940485e22b08f5173b3b64ada177be0a09e4ba2dc8599b8b36ecdee8cff04', 'instruction_count': 31}, '1502': {'executable_offset': 276735, 'byte_length': 139, 'sha256': '06d92dfc59b6eca45c8c8c4d203e1deb6a270101894bdea28ca83b692dc60d19', 'instruction_count': 61}, '1519': {'executable_offset': 278938, 'byte_length': 136, 'sha256': '4cf67a734da229a0a8cb12b509f70668250b4b0f3836a19146b53b0272e78ea3', 'instruction_count': 59}, '1466': {'executable_offset': 269559, 'byte_length': 272, 'sha256': 'd8afc05d10b13f7872438dd3a1e13e11ccc15dd0b55881fa120ef8781055cf10', 'instruction_count': 103}, '1520': {'executable_offset': 279074, 'byte_length': 86, 'sha256': '97176815c1009869daef82477468f18dd21c7dccac64b5a3714d84295f281976', 'instruction_count': 37}, '1521': {'executable_offset': 279160, 'byte_length': 17, 'sha256': 'f62a5f949cbf8da772c3cc32ae59b607e0f35cda6c3c4e1ddf848ba3b5a1b445', 'instruction_count': 9}, '1522': {'executable_offset': 279177, 'byte_length': 12, 'sha256': 'e6001a066c6ed54cff7bf995d82867c4b0809fa6752fdfb96247378823c29291', 'instruction_count': 7}, '1523': {'executable_offset': 279189, 'byte_length': 33, 'sha256': 'e393035168c327e2d7c04e94b55828696681e5f6eabbab45e27c103d00f712af', 'instruction_count': 16}, '1538': {'executable_offset': 281168, 'byte_length': 15, 'sha256': '7f8a8207c382290494a4d7fabdc00b15b17b0c51b7e9185cd4a3ae9f4cfb1226', 'instruction_count': 6}, '1552': {'executable_offset': 282920, 'byte_length': 157, 'sha256': '7977b9c88ca60678c48bd16343b74af7de283391e7ac94a49c27aa269eb4ee2d', 'instruction_count': 69}, '1656': {'executable_offset': 305076, 'byte_length': 74, 'sha256': '8bdce1d3d508b9cbf7d5fcbbf261407789d7bbf8fd917a4225db88c6d5aa2949', 'instruction_count': 29}, '1658': {'executable_offset': 305360, 'byte_length': 44, 'sha256': '6bdbafa74820fd4a83d1e5dfdb85032acacc6fd0e1636b481ac3f18af1ad065f', 'instruction_count': 23}, '1657': {'executable_offset': 305152, 'byte_length': 207, 'sha256': '86d7da85e49ea3ddca538301d8ff1595065c0fb8e2a52ad7dd1b35b68bcbd6ff', 'instruction_count': 84}, '1660': {'executable_offset': 305752, 'byte_length': 177, 'sha256': 'e23941156e2eb6f1c53020a82a29d6537e6be0b7a6af446323409fb93e3be0cc', 'instruction_count': 74}, 'abs': {'executable_offset': 421944, 'byte_length': 22, 'sha256': '46c8a9d0c4e7b862f57c083615031c907a391a2166724a009057ab580d4c0795', 'instruction_count': 12}, '1332': {'executable_offset': 259552, 'byte_length': 54, 'sha256': '0e214c91774522f45b3c50a19f59f2807fb95454fc24eead2749bdc795ccc03c', 'instruction_count': 20}, '1341': {'executable_offset': 259928, 'byte_length': 127, 'sha256': 'ce1f10cd3645a7e74e65b774758ad6160e67cc67d19b0ad4cbfa77dbcc454ef3', 'instruction_count': 57}, '1664': {'executable_offset': 306204, 'byte_length': 65, 'sha256': '701108e268a44d562f19fe0c65162217e901584fb775656302d5c4c27c9b9e08', 'instruction_count': 27}, '575': {'executable_offset': 99488, 'byte_length': 2005, 'sha256': '33e2895597b23f2e12a3fc6f8c09a08c73042eb26f3529a2b1d911d12b77b015', 'instruction_count': 635}, '577': {'executable_offset': 101964, 'byte_length': 363, 'sha256': 'f2bb5974c51d801bf5c219f697cf16716250a296f744e54fed61a6c26131e790', 'instruction_count': 128}}

def preset_values(path):
    text=path.read_text()
    def quoted(key):
        found=re.search(r'^'+re.escape(key)+r'="([^"]+)"\s*$',text,re.M)
        if not found:raise ValueError('Export preset missing '+key)
        return found[1]
    found=re.search(r'^version/code=(\d+)\s*$',text,re.M)
    if not found:raise ValueError('Export preset missing version/code')
    return {'package':quoted('package/unique_name'),'version':quoted('version/name'),'version_code':int(found[1])}

def source_function(text,name):
    found=re.search(r'^(?:static\s+)?func\s+'+re.escape(name)+r'\([^\n]*\)[^\n]*:',text,re.M)
    assert found,'Missing source function '+name
    following=re.search(r'^(?:static\s+)?func\s+',text[found.end():],re.M)
    return text[found.start():found.end()+following.start() if following else len(text)]

def verify_full_startup(main,world):
    """Pin v34 startup and the explicit legacy entry point, not just a token."""
    ready=source_function(main,'_ready')
    helper=source_function(main,'_new_models')
    new_game=source_function(main,'_confirm_new_game')
    assert re.search(r'_new_models\(\s*World\.PORT_LAYOUT\s+if\s+automated\s+else\s+World\.FULL_LAYOUT\s*\)',ready),'Normal v34 startup must select FULL while automated capture preserves PORT'
    assert re.search(r'func\s+_new_models\(\s*layout\s*:\s*String\s*=\s*World\.PORT_LAYOUT\s*\)',helper),'Legacy helper/graphics preview must retain explicit PORT default'
    assert re.search(r'if\s+layout\s*==\s*World\.FULL_LAYOUT\s+and\s+not\s+nav\.configure_native\(\)',helper),'Full startup must initialize the native navigation catalogue'
    assert re.search(r'world\.configure\(\s*nav\.current\(\)\s*,\s*layout\s*\)',helper),'World must receive the explicitly selected layout'
    assert re.search(r'_new_models\(\s*World\.FULL_LAYOUT\s*\)',new_game),'User New Game action must select FULL'
    expected={'SOURCE_LAYOUT':'handcrafted_analytic_rebuild_v1','NATIVE_LAYOUT':'handcrafted_jjffe_orbits_v2','PORT_LAYOUT':'handcrafted_jjffe_ports_v3','FULL_LAYOUT':'source_jjffe_systems_v4','SOLAR_LAYOUT':'reconstructed_solar_v1','EMPTY_LAYOUT':'source_unavailable_rebuild_v1'}
    for name,value in expected.items():
        assert re.search(r'^const\s+'+name+r'\s*:=\s*"'+re.escape(value)+r'"\s*$',world,re.M),'Changed explicit world layout '+name
    restore=source_function(world,'restore');snapshot=source_function(world,'snapshot')
    for version in [1,2,3,4]:
        assert 'starfrontier-rebuild-world-v'+str(version) in restore,'World restore lost saved schema v'+str(version)
        assert 'starfrontier-rebuild-world-v'+str(version) in snapshot,'World snapshot lost saved schema v'+str(version)
    assert 'requested_layout' in restore and 'PORT_LAYOUT if port_save' in restore and 'NATIVE_LAYOUT if native_save' in restore,'Legacy restore must retain the requested saved layout'
    return {'normal_startup_layout':expected['FULL_LAYOUT'],'user_new_game_layout':expected['FULL_LAYOUT'],'automated_and_helper_layout':expected['PORT_LAYOUT'],'legacy_saved_layouts_retained':[expected[key] for key in ['SOURCE_LAYOUT','NATIVE_LAYOUT','PORT_LAYOUT','SOLAR_LAYOUT','EMPTY_LAYOUT']]}

def verify_material_assets(archive,project):
    """Follow exported texture imports to actual runtime data, without extraction.

    These checks establish packaging and source consistency, not visual quality.
    Lossless maps share the imported CTEX across desktop and Android; if an
    imported feature variant is selected, compare that exact referenced file.
    """
    names=set(archive.namelist())
    assert not any('texture_contact_sheet' in name for name in names),'Documentation contact sheet included in runtime APK'
    manifest_path=project/'assets/materials/manifest.json'
    manifest=json.loads(manifest_path.read_text())
    packed_manifest='assets/assets/materials/manifest.json'
    assert packed_manifest in names,'Missing runtime material metadata'
    assert archive.read(packed_manifest)==manifest_path.read_bytes(),'Runtime material metadata differs from source'
    assert manifest['resolution']==512 and set(manifest['materials'])==set(MATERIAL_KINDS),'Unexpected authored material manifest'
    runtime='assets/scripts/material_library.gdc'
    assert runtime in names and len(archive.read(runtime))>64,'Missing material library runtime'
    result={'runtime_sha256':hashlib.sha256(archive.read(runtime)).hexdigest(),'maps':{}}
    for kind in MATERIAL_KINDS:
        for channel in MATERIAL_CHANNELS:
            relative='assets/materials/'+kind+'/'+channel+'.png'
            source=project/relative
            png=source.read_bytes()
            source_hash=hashlib.sha256(png).hexdigest()
            assert manifest['materials'][kind]['files'][channel]['sha256']==source_hash,'Material source differs from authored manifest '+relative
            assert png[:8]==b'\x89PNG\r\n\x1a\n' and png[12:16]==b'IHDR','Invalid source material PNG '+relative
            assert struct.unpack_from('>II',png,16)==(512,512),'Unexpected material map dimensions '+relative
            local_import=Path(str(source)+'.import').read_text()
            assert re.search(r'^mipmaps/generate=true\s*$',local_import,re.M),'Missing material mipmap import '+relative
            if channel=='normal':
                assert re.search(r'^compress/normal_map=1\s*$',local_import,re.M),'Material normal import not forced '+relative
                assert re.search(r'^process/normal_map_invert_y=false\s*$',local_import,re.M),'Unexpected material normal Y inversion '+relative
            imported='assets/'+relative+'.import'
            assert imported in names,'Missing exported material import '+relative
            remap=archive.read(imported).decode('utf-8').rstrip('\0')
            assert 'importer="texture"' in remap and 'type="CompressedTexture2D"' in remap,'Invalid material import '+relative
            found=re.search(r'^path="(res://\.godot/imported/[^"\r\n]+\.ctex)"\s*$',remap,re.M)
            assert found and '..' not in found[1].split('/'),'Missing material runtime remap '+relative
            resource=found[1].removeprefix('res://')
            packed_path='assets/'+resource
            assert packed_path in names,'Missing material CTEX '+relative
            packed=archive.read(packed_path)
            assert len(packed)>52 and packed[:4]==b'GST2','Invalid material CTEX '+relative
            assert struct.unpack_from('<II',packed,8)==(512,512),'Wrong packed material dimensions '+relative
            local=project/resource
            assert local.is_file() and packed==local.read_bytes(),'Material CTEX differs from imported source '+relative
            result['maps'][kind+'/'+channel]={'source_png_sha256':source_hash,'runtime_resource':resource,'runtime_bytes':len(packed),'runtime_sha256':hashlib.sha256(packed).hexdigest(),'width':512,'height':512,'mipmap_import_enabled':True}
    result['map_count']=len(result['maps'])
    assert result['map_count']==24
    return result

def verify_surface_map(archive,names,project,relative,entry,resolution):
    """Check one dedicated source map and its exact exported runtime texture."""
    source=project/relative
    png=source.read_bytes()
    source_hash=hashlib.sha256(png).hexdigest()
    assert entry['sha256']==source_hash and entry['bytes']==len(png),'Surface source differs from authored manifest '+relative
    assert png[:8]==b'\x89PNG\r\n\x1a\n' and png[12:16]==b'IHDR','Invalid source surface PNG '+relative
    assert struct.unpack_from('>II',png,16)==(resolution,resolution),'Unexpected surface map dimensions '+relative
    local_import=Path(str(source)+'.import').read_text()
    assert re.search(r'^mipmaps/generate=true\s*$',local_import,re.M),'Missing surface mipmap import '+relative
    assert re.search(r'^compress/mode=0\s*$',local_import,re.M),'Surface map is not imported losslessly '+relative
    if relative.endswith('/normal.png'):
        assert re.search(r'^compress/normal_map=1\s*$',local_import,re.M),'Surface normal import not forced '+relative
        assert re.search(r'^process/normal_map_invert_y=false\s*$',local_import,re.M),'Unexpected surface normal Y inversion '+relative
    imported='assets/'+relative+'.import'
    assert imported in names,'Missing exported surface import '+relative
    remap=archive.read(imported).decode('utf-8').rstrip('\0')
    assert 'importer="texture"' in remap and 'type="CompressedTexture2D"' in remap,'Invalid surface texture import '+relative
    found=re.search(r'^path="(res://\.godot/imported/[^"\r\n]+\.ctex)"\s*$',remap,re.M)
    assert found and '..' not in found[1].split('/'),'Missing surface runtime remap '+relative
    resource=found[1].removeprefix('res://')
    packed_path='assets/'+resource
    assert packed_path in names,'Missing surface CTEX '+relative
    packed=archive.read(packed_path)
    assert len(packed)>52 and packed[:4]==b'GST2','Invalid surface CTEX '+relative
    assert struct.unpack_from('<II',packed,8)==(resolution,resolution),'Wrong packed surface dimensions '+relative
    local=project/resource
    assert local.is_file() and packed==local.read_bytes(),'Surface CTEX differs from imported source '+relative
    return {'source_png_sha256':source_hash,'source_png_bytes':len(png),'runtime_resource':resource,'runtime_bytes':len(packed),'runtime_sha256':hashlib.sha256(packed).hexdigest(),'width':resolution,'height':resolution,'mipmap_import_enabled':True}

def verify_surface_details(archive,project):
    """Verify bespoke ship/station assets, not visual fidelity or phone speed."""
    names=set(archive.namelist())
    assert not any('contact_sheet' in name for name in names),'Documentation surface contact sheet included in runtime APK'
    runtime='assets/scripts/surface_detail_library.gdc'
    assert runtime in names and len(archive.read(runtime))>64,'Missing dedicated surface library runtime'
    result={'runtime_sha256':hashlib.sha256(archive.read(runtime)).hexdigest(),'manifests':{},'maps':{}}
    manifests={}
    for family in ['ships','station']:
        relative='assets/surface_details/'+family+'/manifest.json'
        raw=(project/relative).read_bytes()
        exported='assets/'+relative
        assert exported in names and archive.read(exported)==raw,'Runtime surface metadata differs from source '+family
        metadata=json.loads(raw)
        assert metadata['resolution']==1024,'Unexpected surface texture resolution '+family
        assert metadata['orm_channels']=={'r':'ambient_occlusion','g':'roughness','b':'metallic'},'Unexpected surface ORM channel convention '+family
        manifests[family]=metadata
        result['manifests'][family]={'source_sha256':hashlib.sha256(raw).hexdigest(),'runtime_path':exported}
    ships=manifests['ships']
    assert set(ships['profiles'])==set(SURFACE_PROFILES),'Unexpected dedicated ship profile set'
    assert ships['projection']['canonical_bounds_m']==[-21,21] and ships['projection']['wrap'] is False,'Unexpected canonical hull projection metadata'
    expected_shapes={'cobra':(1.0,1.0),'eagle':(0.90,1.20),'shuttle':(0.82,0.96)}
    for profile in SURFACE_PROFILES:
        entry=ships['profiles'][profile]
        assert (entry['shape_x'],entry['shape_z'])==expected_shapes[profile],'Surface atlas shape differs from existing ship '+profile
        assert set(entry['files'])==set(MATERIAL_CHANNELS),'Incomplete dedicated ship map set '+profile
        for channel in MATERIAL_CHANNELS:
            relative='assets/surface_details/ships/'+profile+'/'+channel+'.png'
            result['maps']['ships/'+profile+'/'+channel]=verify_surface_map(archive,names,project,relative,entry['files'][channel],1024)
    station=manifests['station']
    assert set(station['files'])==set(MATERIAL_CHANNELS),'Incomplete dedicated station map set'
    for channel in MATERIAL_CHANNELS:
        relative='assets/surface_details/station/'+channel+'.png'
        result['maps']['station/'+channel]=verify_surface_map(archive,names,project,relative,station['files'][channel],1024)
    result['map_count']=len(result['maps'])
    assert result['map_count']==12
    return result

def verify_city_surfaces(archive,project):
    """Verify the four-role city atlas and the exact runtime material adapter."""
    names=set(archive.namelist())
    relative='assets/city_surfaces/manifest.json'
    raw=(project/relative).read_bytes()
    exported='assets/'+relative
    assert exported in names and archive.read(exported)==raw,'Runtime city surface metadata differs from source'
    manifest=json.loads(raw)
    assert (manifest['resolution'],manifest['tile_size'],manifest['content_size'],manifest['gutter'],manifest['max_safe_lod'])==(2048,1024,992,16,4),'Unexpected city atlas layout'
    assert manifest['orm_channels']=={'r':'ambient_occlusion','g':'roughness','b':'metallic'},'Unexpected city ORM channel convention'
    assert set(manifest['roles'])==set(CITY_ROLES),'Unexpected city role set'
    assert set(manifest['files'])==set(MATERIAL_CHANNELS),'Incomplete city atlas map set'
    for index,role in enumerate(CITY_ROLES):
        entry=manifest['roles'][role]
        assert entry['index']==index and entry['origin_px']==[(index%2)*1024,(index//2)*1024],'Unexpected city tile placement '+role
        assert 0<entry['mean_linear_luminance']<=1,'Invalid city albedo normalization '+role
        assert 0<=entry['mean_roughness']<=1 and 0<=entry['mean_metallic']<=1,'Invalid city material response '+role
    result={'manifest_sha256':hashlib.sha256(raw).hexdigest(),'runtime_manifest':exported,'runtime_assets_sha256':{},'maps':{}}
    for name in ['city_surface_library.gdc','city_material_roles.gdc','source_model_visual.gdc','source_city_view.gdc','source_model.gdshader']:
        path='assets/scripts/'+name
        assert path in names and len(archive.read(path))>64,'Missing city material runtime '+name
        packed=archive.read(path)
        if name.endswith('.gdshader'):
            assert packed==(project/'scripts'/name).read_bytes(),'City shader differs from current source '+name
        result['runtime_assets_sha256'][name]=hashlib.sha256(packed).hexdigest()
    for channel in MATERIAL_CHANNELS:
        relative='assets/city_surfaces/'+channel+'.png'
        result['maps'][channel]=verify_surface_map(archive,names,project,relative,manifest['files'][channel],2048)
    result['map_count']=len(result['maps'])
    assert result['map_count']==3
    return result

def verify_world_surfaces(archive,project):
    """Check dedicated terrain/planet resources, not geography or phone speed."""
    names=set(archive.namelist())
    relative='assets/world_surfaces/manifest.json'
    raw=(project/relative).read_bytes()
    exported='assets/'+relative
    assert exported in names and archive.read(exported)==raw,'Runtime world surface metadata differs from source'
    manifest=json.loads(raw)
    assert manifest['resolution']==1024,'Unexpected world surface resolution'
    assert manifest['orm_channels']=={'r':'ambient_occlusion','g':'roughness','b':'metallic'},'Unexpected world surface ORM channels'
    assert set(manifest['materials'])==set(WORLD_SURFACE_KINDS),'Unexpected world surface kind set'
    result={'manifest_sha256':hashlib.sha256(raw).hexdigest(),'runtime_manifest':exported,'runtime_assets_sha256':{},'maps':{}}
    for name in ['world_surface_library.gdc','surface_visual.gdc','celestial_renderer.gdc','terrain.gdshader','terrain_transition.gdshader','planet.gdshader']:
        path='assets/scripts/'+name
        assert path in names and len(archive.read(path))>64,'Missing world surface runtime '+name
        packed=archive.read(path)
        if name.endswith('.gdshader'):
            assert packed==(project/'scripts'/name).read_bytes(),'World surface shader differs from current source '+name
        result['runtime_assets_sha256'][name]=hashlib.sha256(packed).hexdigest()
    for kind in WORLD_SURFACE_KINDS:
        entry=manifest['materials'][kind]
        assert 0<entry['mean_linear_luminance']<=1,'Invalid world surface normalization '+kind
        assert 0<=entry['mean_roughness']<=1 and 0<=entry['mean_metallic']<=1,'Invalid world surface response '+kind
        assert set(entry['files'])==set(MATERIAL_CHANNELS),'Incomplete world surface map set '+kind
        for channel in MATERIAL_CHANNELS:
            relative='assets/world_surfaces/'+kind+'/'+channel+'.png'
            result['maps'][kind+'/'+channel]=verify_surface_map(archive,names,project,relative,entry['files'][channel],1024)
    result['map_count']=len(result['maps'])
    assert result['map_count']==12
    return result

def verify_source_world_runtime(archive,project):
    """Verify native-Godot source-world modules and their exact source tables.

    This establishes package consistency, not a complete procedural galaxy,
    source ephemeris integration or physical Android execution.
    """
    names=set(archive.namelist())
    result={'scripts_sha256':{},'data':{},'clock_constants':{}}
    scripts=['source_body_factory.gdc','handcrafted_runtime_builder.gdc',
             'source_clock.gdc','stellar_body_factory.gdc','planetary_classifier.gdc',
             'body_initializer.gdc','ffe_math.gdc','planetary_system.gdc',
             'flight_console.gdc','main.gdc']
    for name in scripts:
        path='assets/scripts/'+name
        assert path in names,'Missing source-world runtime '+name
        packed=archive.read(path)
        assert len(packed)>64 and packed[:4]==b'GDSC','Invalid compiled source-world module '+name
        result['scripts_sha256'][name]=hashlib.sha256(packed).hexdigest()
    for name in ['ffe_handcrafted_records','ffe_stellar_factory','ffe_math']:
        relative='data/'+name+'.json'
        raw=(project/relative).read_bytes()
        exported='assets/'+relative
        assert exported in names and archive.read(exported)==raw,'Runtime source-world data differs from source '+name
        metadata=json.loads(raw)
        assert metadata.get('source_sha256')==SOURCE_IMAGE_SHA256,'Unexpected source-world executable provenance '+name
        result['data'][name]={'runtime_path':exported,'bytes':len(raw),
                              'source_json_sha256':hashlib.sha256(raw).hexdigest(),
                              'source_executable_sha256':metadata['source_sha256']}
    clock=(project/'scripts/source_clock.gd').read_text()
    for name,value in [('EPOCH_DAY_U32',0x121cf7),('EPOCH_TICK_U32',0x80000000),
                       ('TICKS_PER_DAY',0x100000000),('TICKS_PER_DISPLAY_SECOND',0xc22e)]:
        matched=re.search(r'^const\s+'+name+r'\s*:=\s*(0x[0-9a-fA-F]+|\d+)\s*$',clock,re.M)
        assert matched and int(matched[1],0)==value,'Unexpected source-clock constant '+name
        result['clock_constants'][name]=value
    return result

def verify_source_orbit_runtime(archive,project,version_code=32):
    """Check orbital packaging and local native-fixture provenance.

    The fixture is a development reference, never an Android runtime asset.
    This check does not execute its native oracle or establish original
    radius, mass, gravity, spin, full procedural generation or phone behavior.
    """
    names=set(archive.namelist())
    result={'scripts':{},'data':{}}
    scripts=['source_orbit','planetary_system','main','source_clock','source_units',
             'ground_coordinates','ffe_math','handcrafted_runtime_builder']
    source_text={}
    for name in scripts:
        relative='scripts/'+name+'.gd'
        raw=(project/relative).read_bytes()
        source_text[name]=raw.decode('utf-8')
        exported='assets/scripts/'+name+'.gdc'
        assert exported in names,'Missing source-orbit runtime '+name
        packed=archive.read(exported)
        assert len(packed)>64 and packed[:4]==b'GDSC','Invalid compiled source-orbit module '+name
        result['scripts'][name]={'runtime_path':exported,'runtime_bytes':len(packed),
                                 'runtime_sha256':hashlib.sha256(packed).hexdigest(),
                                 'local_source_sha256':hashlib.sha256(raw).hexdigest()}
    metadata={}
    for name in ['ffe_worlds','ffe_handcrafted_records','ffe_ground_coordinates','ffe_math','world_names_ru']:
        relative='data/'+name+'.json'
        raw=(project/relative).read_bytes()
        exported='assets/'+relative
        assert exported in names and archive.read(exported)==raw,'Runtime source-orbit data differs from source '+name
        entry=json.loads(raw)
        assert isinstance(entry,dict),'Invalid source-orbit data '+name
        if name!='world_names_ru':
            assert entry.get('source_sha256')==SOURCE_IMAGE_SHA256,'Unexpected source-orbit executable provenance '+name
        metadata[name]=entry
        result['data'][name]={'runtime_path':exported,'bytes':len(raw),
                              'source_json_sha256':hashlib.sha256(raw).hexdigest()}
        if name!='world_names_ru':result['data'][name]['source_executable_sha256']=entry['source_sha256']

    def string_constant(text,name):
        matched=re.search(r'^const\s+'+re.escape(name)+r'\s*:=\s*"([^"\r\n]+)"\s*$',text,re.M)
        assert matched,'Missing source-orbit string constant '+name
        return matched[1]

    def u32_constant(text,name):
        matched=re.search(r'^const\s+'+re.escape(name)+r'\s*:=\s*(0x[0-9a-fA-F]+|\d+)\s*$',text,re.M)
        assert matched,'Missing source-orbit clock constant '+name
        value=int(matched[1],0)
        assert 0<=value<=0xffffffff,'Invalid source-orbit clock constant '+name
        return value

    variant=string_constant(source_text['source_orbit'],'SOURCE_VARIANT')
    contract=string_constant(source_text['planetary_system'],'NATIVE_CONTRACT')
    epoch_tick=u32_constant(source_text['source_orbit'],'SOURCE_EPOCH_TICK')
    epoch_day=u32_constant(source_text['source_orbit'],'SOURCE_EPOCH_DAY')
    assert epoch_tick==u32_constant(source_text['source_clock'],'EPOCH_TICK_U32'),'Orbital epoch tick differs from source clock'
    assert epoch_day==u32_constant(source_text['source_clock'],'EPOCH_DAY_U32'),'Orbital epoch day differs from source clock'
    assert re.search(r'SourceOrbit\.evaluate_from_epoch\(\s*record\s*,\s*clock\.tick_u32\s*,\s*clock\.day_u32\s*,\s*SourceClock\.EPOCH_TICK_U32\s*,\s*SourceClock\.EPOCH_DAY_U32\s*\)',source_text['planetary_system']),'World does not evaluate native orbits from the fixed source-clock epoch'
    layout_names=['NATIVE_LAYOUT','SOURCE_LAYOUT','SOLAR_LAYOUT','EMPTY_LAYOUT']
    if version_code>=33:layout_names.append('PORT_LAYOUT')
    if version_code>=34:layout_names.append('FULL_LAYOUT')
    layouts={name:string_constant(source_text['planetary_system'],name) for name in layout_names}
    assert len(set(layouts.values()))==len(layout_names),'Source-orbit and legacy layouts must remain distinct'
    assert layouts['SOURCE_LAYOUT']=='handcrafted_analytic_rebuild_v1','Legacy handcrafted layout changed'
    assert layouts['SOLAR_LAYOUT']=='reconstructed_solar_v1','Legacy solar layout changed'
    assert layouts['EMPTY_LAYOUT']=='source_unavailable_rebuild_v1','Legacy unavailable-world layout changed'
    requested='FULL_LAYOUT' if version_code>=34 else ('PORT_LAYOUT' if version_code>=33 else 'NATIVE_LAYOUT')
    if version_code>=34:
        result['startup_contract']=verify_full_startup(source_text['main'],source_text['planetary_system'])
    else:
        assert re.search(r'world\.configure\(\s*nav\.current\(\)\s*,\s*World\.'+requested+r'\s*\)',source_text['main']),'New game does not request the expected native orbital layout'
    adapter=re.search(r'"radius_mass_gravity_spin"\s*:\s*"([^"\r\n]+)"',source_text['planetary_system'])
    assert adapter and adapter[1]=='analytic_si_rebuild_v1','Missing explicit retained local physics adapter'
    assert re.search(r'"complete_original_physics"\s*:\s*false',source_text['planetary_system']),'Orbital backend must identify incomplete original physics'
    units=re.search(r'^const\s+METRES_PER_RAW\s*:=\s*16785(?:\.0)?\s*/\s*16777216(?:\.0)?\s*$',source_text['source_units'],re.M)
    assert units,'Unexpected source geometry-to-metres calibration'

    fixture_relative='tests/fixtures/source_orbit_native.json'
    fixture_raw=(project/fixture_relative).read_bytes()
    fixture=json.loads(fixture_raw)
    assert fixture.get('schema')==1,'Unexpected native orbital fixture schema'
    assert fixture.get('source_variant')==variant,'Native orbital fixture differs from runtime SOURCE_VARIANT'
    assert fixture.get('source_sha256')==SOURCE_IMAGE_SHA256,'Unexpected native orbital executable provenance'
    assert fixture.get('source_assembly_sha256')==SOURCE_ASSEMBLY_SHA256,'Unexpected native orbital assembly provenance'
    assert fixture.get('source_commit')==SOURCE_ASSEMBLY_COMMIT,'Unexpected native orbital source revision'
    assert fixture.get('ordinary_epoch_tick_u32')==epoch_tick and fixture.get('ordinary_epoch_day_u32')==epoch_day,'Native orbital fixture differs from runtime epoch anchor'
    initializer=fixture.get('dos_f880_rate_and_initialization_slice')
    update=fixture.get('pinned_f866_ordinary_orbital_slice')
    assert isinstance(initializer,dict) and isinstance(update,dict),'Missing native initializer/update slice provenance'
    for value,key in [(initializer,'executable_block_sha256'),(initializer,'pinned_executed_slice_sha256'),
                      (initializer,'pinned_full_f880_sha256'),(initializer,'host_entry_sha256'),
                      (update,'pinned_executed_orbital_slice_sha256'),(update,'pinned_full_f866_sha256'),
                      (update,'host_entry_sha256')]:
        assert isinstance(value.get(key),str) and re.fullmatch(r'[0-9a-f]{64}',value[key]),'Invalid native initializer/update provenance '+key
    assert type(initializer.get('executable_offset')) is int and initializer['executable_offset']>=0,'Invalid F880 executable slice offset'
    assert type(initializer.get('byte_length')) is int and initializer['byte_length']>0,'Invalid F880 executable slice length'
    assert isinstance(initializer.get('entry_signature'),str) and re.fullmatch(r'(?:[0-9a-f]{2})+',initializer['entry_signature']),'Invalid F880 executable entry signature'
    for value,key in [(initializer,'phase_call_word_order'),(update,'scope'),(update,'position_dispatch')]:
        assert isinstance(value.get(key),str) and value[key].strip(),'Missing native initializer/update policy '+key
    packed_relative='tests/fixtures/handcrafted_runtime_native.json'
    packed_raw=(project/packed_relative).read_bytes()
    assert fixture.get('packed_record_fixture')==packed_relative,'Unexpected native orbital input fixture'
    assert fixture.get('packed_record_fixture_sha256')==hashlib.sha256(packed_raw).hexdigest(),'Native orbital input fixture differs from local packed records'
    required_procedures={'1333','1338','1341','1483','1494','1496','1506','1507','1508','1509','1510','1521','1661','1914'}
    for key in ['source_procedure_hashes','pinned_procedure_hashes']:
        hashes=fixture.get(key,{})
        assert isinstance(hashes,dict) and required_procedures<=hashes.keys(),'Incomplete native orbital procedure provenance '+key
        assert all(isinstance(value,str) and re.fullmatch(r'[0-9a-f]{64}',value) for value in hashes.values()),'Invalid native orbital procedure digest '+key
    for count_key,cases_key in [('case_count','cases'),('vector_add_case_count','vector_add_cases'),('epoch_update_case_count','epoch_update_cases')]:
        count=fixture.get(count_key)
        assert type(count) is int and count>0 and isinstance(fixture.get(cases_key),list) and count==len(fixture[cases_key]),'Incomplete native orbital fixture '+cases_key
    assert fixture.get('reverse_repeat_count')==fixture['case_count'],'Incomplete native orbital reverse repeat check'
    assert fixture.get('vector_add_reverse_repeat_count')==fixture['vector_add_case_count'],'Incomplete parent-vector reverse repeat check'
    assert fixture.get('epoch_update_reverse_repeat_count')==fixture['epoch_update_case_count']*2,'Incomplete single/stepped orbital epoch reverse repeat check'
    assert fixture.get('epoch_single_step_matches_stepped') is True,'Native orbital updates depend on intermediate epoch steps'
    for row in fixture['epoch_update_cases']:
        assert isinstance(row,dict) and row.get('epoch_tick_u32')==epoch_tick and row.get('epoch_day_u32')==epoch_day,'Native orbital epoch case uses a different anchor'
    for key in ['fresh_process_runs','vector_add_fresh_process_runs','epoch_update_fresh_process_runs']:
        assert type(fixture.get(key)) is int and fixture[key]>=2,'Missing native orbital fresh-process comparison '+key
    assert fixture.get('object_canaries_unchanged') is True and fixture.get('non_target_object_bytes_unchanged') is True,'Native orbital object-boundary checks failed'
    sine=metadata['ffe_ground_coordinates'].get('sin_quarter_q31')
    assert isinstance(sine,list) and len(sine)==16384 and all(type(value) is int and 0<=value<=0x7fffffff for value in sine),'Invalid source-orbit Sin32 table'
    sine_sha256=hashlib.sha256(struct.pack('<16384i',*sine)).hexdigest()
    assert sine_sha256==metadata['ffe_ground_coordinates'].get('sine_table_sha256')==fixture.get('sine_sha256'),'Native orbital fixture uses a different Sin32 table'
    for key in ['native_ordered_output_sha256','native_vector_add_output_sha256','native_epoch_update_output_sha256','adapted_assembly_sha256']:
        assert isinstance(fixture.get(key),str) and re.fullmatch(r'[0-9a-f]{64}',fixture[key]),'Missing native orbital output provenance '+key
    result.update({'source_variant':variant,'native_contract':contract,'layouts':layouts,
                   'new_game_requested_layout':layouts[requested],
                   'epoch_anchor':{'tick_u32':epoch_tick,'day_u32':epoch_day,
                                   'source_clock_constants_agree':True,
                                   'world_calls_evaluate_from_epoch':True},
                   'retained_local_physics_adapter':adapter[1],
                   'metres_per_raw':16785/16777216,
                   'active_scope':'Fixed-epoch native F880 initialization followed by ordinary F866 orbital updates, source clock and parent translations; retained analytic SI radius/mass/gravity/spin and legacy saved layouts.',
                   'complete_original_physics':False,
                   'compiled_source_correspondence_rebuilt_by_verifier':False,
                   'native_fixture':{'local_path':fixture_relative,'bytes':len(fixture_raw),
                                     'sha256':hashlib.sha256(fixture_raw).hexdigest(),
                                     'provenance_checked':True,'oracle_executed_by_apk_verifier':False,
                                     **{key:fixture[key] for key in ['revision','source_variant','source_sha256','source_assembly_sha256','source_commit','scope','source_procedure_hashes','pinned_procedure_hashes','dos_f880_rate_and_initialization_slice','pinned_f866_ordinary_orbital_slice','packed_record_fixture','packed_record_fixture_sha256','case_count','vector_add_case_count','epoch_update_case_count','fresh_process_runs','vector_add_fresh_process_runs','epoch_update_fresh_process_runs','epoch_update_reverse_repeat_count','epoch_single_step_matches_stepped','ordinary_epoch_tick_u32','ordinary_epoch_day_u32','native_ordered_output_sha256','native_vector_add_output_sha256','native_epoch_update_output_sha256','adapted_assembly_sha256','sine_sha256']}}})
    return result

def verify_source_physics_ports_runtime(archive,project,version_code=33):
    """Check v3 port-frame packaging and bounded raw-physics provenance.

    Local fixtures establish which controls were used by development tests.
    This verifier neither runs the oracle nor treats packaged raw F603/F1511
    primitives as the live SI gravity, surface or original docking backend.
    """
    names=set(archive.namelist())
    result={'scripts':{}}
    source={}
    for name in ['source_gravity','source_orbit','planetary_system','flight_model',
                 'surface_model','surface_orbit_link','main','source_units','source_clock']:
        relative='scripts/'+name+'.gd'
        raw=(project/relative).read_bytes();source[name]=raw.decode('utf-8')
        exported='assets/scripts/'+name+'.gdc'
        assert exported in names,'Missing source-physics/port runtime '+name
        packed=archive.read(exported)
        assert len(packed)>64 and packed[:4]==b'GDSC','Invalid compiled source-physics/port module '+name
        result['scripts'][name]={'runtime_path':exported,'runtime_bytes':len(packed),
                                 'runtime_sha256':hashlib.sha256(packed).hexdigest(),
                                 'local_source_sha256':hashlib.sha256(raw).hexdigest()}

    def string_constant(text,name):
        matched=re.search(r'^const\s+'+re.escape(name)+r'\s*:=\s*"([^"\r\n]+)"\s*$',text,re.M)
        assert matched,'Missing source-physics/port string constant '+name
        return matched[1]

    def integer_constant(text,name):
        matched=re.search(r'^const\s+'+re.escape(name)+r'\s*:=\s*(0x[0-9a-fA-F]+|\d+)\s*$',text,re.M)
        assert matched,'Missing source-physics/port integer constant '+name
        return int(matched[1],0)

    def vector_constant(text,name):
        number=r'([-+]?\d+(?:\.\d+)?)'
        matched=re.search(r'^const\s+'+re.escape(name)+r'\s*:=\s*Vector3\(\s*'+number+r'\s*,\s*'+number+r'\s*,\s*'+number+r'\s*\)\s*$',text,re.M)
        assert matched,'Missing source-physics/port vector constant '+name
        return [float(value) for value in matched.groups()]

    def digest(value,label):
        assert isinstance(value,str) and re.fullmatch(r'[0-9a-f]{64}',value),'Invalid native source-physics digest '+label
        return value

    world=source['planetary_system']
    variant=string_constant(source['source_gravity'],'SOURCE_VARIANT')
    port_layout=string_constant(world,'PORT_LAYOUT')
    contract=string_constant(world,'PORT_CONTRACT')
    assert port_layout=='handcrafted_jjffe_ports_v3','Unexpected port layout version'
    if version_code>=34:
        result['startup_contract']=verify_full_startup(source['main'],world)
    else:
        assert re.search(r'world\.configure\(\s*nav\.current\(\)\s*,\s*World\.PORT_LAYOUT\s*\)',source['main']),'New flight does not select the port-following layout'
    dock=vector_constant(world,'ORBITAL_DOCK_LOCAL')
    assert dock==vector_constant(source['flight_model'],'STATION')==[0.0,0.0,-2500.0],'Port frame target differs from the flight docking target'
    assert re.search(r'SourceGravity\.coefficient\(\s*raw\s*\)',world) and 'source_a4_packed' in world,'Prepared native source coefficient is missing from v3 bodies'
    assert not re.search(r'SourceGravity\.(?:update|integrate)\s*\(',world+source['main']),'Raw source-gravity kernel unexpectedly became live flight physics'
    for key in ['live_gravity','live_surface_radius']:
        assert re.search(r'"'+key+r'"\s*:\s*"analytic_si_rebuild_v1"',world),'Missing retained SI adapter declaration '+key
    for key in ['descriptor_bounds_are_surface_radius','source_time_policy_integrated','complete_original_physics','complete_original_docking']:
        assert re.search(r'"'+key+r'"\s*:\s*false',world),'Unexpected source-physics/port completion claim '+key
    assert 'descriptor_outer_sphere_not_surface_radius' in world,'Source descriptor bounds must remain distinct from surface radii'
    assert 'non-rotating station-following origin' in world,'Missing explicit non-rotating port frame contract'
    assert re.search(r'SourceClock\.EPOCH_TICK_U32\s*,\s*SourceClock\.EPOCH_DAY_U32',world),'Port positions lost the fixed source-clock epoch'
    epoch={'tick_u32':integer_constant(source['source_clock'],'EPOCH_TICK_U32'),
           'day_u32':integer_constant(source['source_clock'],'EPOCH_DAY_U32')}
    assert epoch=={'tick_u32':0x80000000,'day_u32':0x121cf7},'Unexpected source-physics/port clock anchor'
    assert integer_constant(source['source_clock'],'TICKS_PER_DAY')==0x100000000,'Unexpected nominal day clock'
    assert integer_constant(source['source_clock'],'TICKS_PER_DISPLAY_SECOND')==0xc22e,'Unexpected source display-clock divisor'
    assert re.search(r'^const\s+METRES_PER_RAW\s*:=\s*16785(?:\.0)?\s*/\s*16777216(?:\.0)?\s*$',source['source_units'],re.M),'Unexpected source-physics geometry calibration'

    relative='tests/fixtures/source_gravity_native.json'
    fixture_raw=(project/relative).read_bytes();fixture=json.loads(fixture_raw)
    assert fixture.get('schema')==1,'Unexpected native source-gravity fixture schema'
    assert fixture.get('source_variant')==variant,'Native gravity fixture differs from runtime SOURCE_VARIANT'
    assert fixture.get('source_sha256')==SOURCE_IMAGE_SHA256,'Unexpected native gravity executable provenance'
    assert fixture.get('source_assembly_sha256')==SOURCE_ASSEMBLY_SHA256,'Unexpected native gravity source provenance'
    assert fixture.get('source_commit')==SOURCE_ASSEMBLY_COMMIT,'Unexpected native gravity source revision'
    size=integer_constant(source['source_gravity'],'OBJECT_BYTES')
    assert fixture.get('object_bytes')==fixture.get('object_bank_stride_bytes')==size==338,'Unexpected native gravity object size'
    assert fixture.get('object_bank_header_bytes')==116,'Unexpected native gravity object-bank header'
    assert fixture.get('object_state_offsets')=={'position_signed64_xyz':0x3e,'parent_index_u8':0x56,'velocity_signed32_xyz':0x8c,'gravity_coefficient_packed':0xa4,'velocity_fraction_u16_xyz':0xec},'Native gravity state layout differs from the source contract'
    procedures={'603','1333','1338','1466','1482','1483','1496','1502','1511','1512','1521','1532','1656','1657','1658','1660','1661'}
    for key in ['source_procedure_hashes','pinned_procedure_hashes']:
        hashes=fixture.get(key)
        assert isinstance(hashes,dict) and procedures<=hashes.keys(),'Incomplete native gravity procedure provenance '+key
        for number,value in hashes.items():digest(value,key+'/'+number)
    coefficient=fixture.get('F880_coefficient_slice')
    assert isinstance(coefficient,dict) and isinstance(coefficient.get('scope'),str) and coefficient['scope'].strip(),'Missing native F880 coefficient slice provenance'
    for key in ['pinned_full_f880_sha256','pinned_executed_slice_sha256','host_entry_sha256']:digest(coefficient.get(key),'F880/'+key)
    inputs=fixture.get('input_fixtures_sha256')
    expected_inputs=['tests/fixtures/handcrafted_runtime_native.json','tests/fixtures/source_orbit_native.json']
    assert isinstance(inputs,dict) and set(inputs)==set(expected_inputs),'Unexpected source-gravity native inputs'
    for name in expected_inputs:
        assert digest(inputs[name],name)==hashlib.sha256((project/name).read_bytes()).hexdigest(),'Native source-gravity input fixture changed '+name
    orbital=json.loads((project/expected_inputs[1]).read_bytes())
    assert coefficient['pinned_full_f880_sha256']==orbital['dos_f880_rate_and_initialization_slice']['pinned_full_f880_sha256'],'Gravity and orbit controls use different F880 source'
    for count_key,cases_key,repeat_key in [('case_count','cases','reverse_repeat_count'),('mass_case_count','mass_cases','mass_reverse_repeat_count'),('integration_case_count','integration_cases','integration_reverse_repeat_count')]:
        count=fixture.get(count_key)
        assert type(count) is int and count>0 and isinstance(fixture.get(cases_key),list) and len(fixture[cases_key])==count,'Incomplete native source-gravity cases '+cases_key
        assert fixture.get(repeat_key)==count,'Incomplete native source-gravity reverse repeat '+repeat_key
    assert type(fixture.get('fresh_process_runs')) is int and fixture['fresh_process_runs']>=2,'Missing native source-gravity fresh-process reproduction'
    for key in ['object_canaries_unchanged','parent_bank_unchanged_except_mass_initializer','non_target_object_bytes_unchanged']:
        assert fixture.get(key) is True,'Native source-gravity boundary check failed '+key
    for key in ['native_gravity_output_sha256','native_mass_output_sha256','native_integration_output_sha256','adapted_assembly_sha256']:digest(fixture.get(key),key)
    assert isinstance(fixture.get('scope'),str) and fixture['scope'].strip(),'Missing native source-gravity scope'
    result.update({'source_variant':variant,'port_layout':port_layout,'port_contract':contract,
                   'reported_layout_scope':'retained-v3-layout' if version_code>=34 else 'default-v3-layout',
                   'dock_local_m':dock,'flight_dock_target_equal':True,'source_epoch':epoch,
                   'active_scope':'Native orbital station centres in a non-rotating station-following frame; prepared F880 a4 fields and separately available raw F603/F1511/F1512 primitives.',
                   'live_gravity':'analytic_si_rebuild_v1','live_surface_radius':'analytic_si_rebuild_v1',
                   'source_time_accumulator_integrated':False,'original_station_spin_integrated':False,
                   'original_dock_geometry_services_integrated':False,'complete_original_physics':False,
                   'complete_original_docking':False,'compiled_source_correspondence_rebuilt_by_verifier':False,
                   'native_fixture':{'local_path':relative,'bytes':len(fixture_raw),
                                     'sha256':hashlib.sha256(fixture_raw).hexdigest(),
                                     'provenance_checked':True,'oracle_executed_by_apk_verifier':False,
                                     **{key:fixture[key] for key in ['revision','source_variant','source_sha256','source_assembly_sha256','source_commit','scope','object_bytes','object_bank_stride_bytes','object_bank_header_bytes','object_state_offsets','source_procedure_hashes','pinned_procedure_hashes','F880_coefficient_slice','case_count','mass_case_count','integration_case_count','fresh_process_runs','reverse_repeat_count','mass_reverse_repeat_count','integration_reverse_repeat_count','native_gravity_output_sha256','native_mass_output_sha256','native_integration_output_sha256','adapted_assembly_sha256','input_fixtures_sha256']}}})
    return result

def verify_source_full_runtime(archive,project,version_code=34):
    """Check v34 runtime/data packaging and declared caller policies.

    Compiled bytes are checked as GDSC and hashed; they are not decompiled or
    proven equivalent to local scripts by this checker. Native/Godot behavior
    and physical-device validation remain separate from APK package evidence.
    """
    names=set(archive.namelist())
    for name in names:
        assert not name.startswith(DEVELOPMENT_ASSET_PREFIXES),'Development material included in full runtime APK '+name
        assert not (name.startswith('assets/') and 'fixtures' in name.lower().split('/')),'Native development fixture included in APK '+name
        assert not (name.startswith('assets/') and name.lower().endswith(('.py','.asm','.exe','.o','.elf','.apk'))),'Host/development binary included in APK '+name
    result={'scripts':{},'shaders':{},'data':{},'source_executable_sha256':SOURCE_IMAGE_SHA256}
    text={}
    for name in FULL_SOURCE_MODULES:
        raw=(project/'scripts'/f'{name}.gd').read_bytes();text[name]=raw.decode('utf-8')
        exported=f'assets/scripts/{name}.gdc'
        assert exported in names,'Missing full source runtime module '+name
        packed=archive.read(exported)
        assert len(packed)>64 and packed[:4]==b'GDSC','Invalid compiled full source runtime module '+name
        result['scripts'][name]={'runtime_path':exported,'runtime_bytes':len(packed),'runtime_sha256':hashlib.sha256(packed).hexdigest(),'local_source_sha256':hashlib.sha256(raw).hexdigest()}
    for name in FULL_SOURCE_SHADERS:
        raw=(project/'scripts'/name).read_bytes();exported='assets/scripts/'+name
        assert exported in names,'Missing source streaming terrain shader '+name
        assert len(raw)>64 and archive.read(exported)==raw,'Source streaming terrain shader differs from local source '+name
        assert re.search(rb'^shader_type\s+spatial\s*;',raw,re.M),'Invalid source streaming spatial shader '+name
        result['shaders'][name]={'runtime_path':exported,'runtime_bytes':len(raw),'runtime_sha256':hashlib.sha256(raw).hexdigest()}
    result['startup_contract']=verify_full_startup(text['main'],text['planetary_system'])
    required_tables=FULL_SOURCE_TABLES+(NAVIGATION_TABLES if version_code>=36 else ())+(('ffe_fuel',) if version_code>=41 else ())+(('ffe_atmosphere',) if version_code>=42 else ())+(('ffe_landing_gear',) if version_code>=43 else ())+(('ffe_surface_contact',) if version_code>=44 else ())+(('ffe_spherical_contact',) if version_code>=45 else ())+(('ffe_natural_contact',) if version_code>=46 else ())
    present_tables=set(path.stem for path in (project/'data').glob('ffe_*.json'))
    # Older contracts still inspect their exact base tables when tested from a
    # newer checkout. Only explicitly known later-version tables may coexist;
    # current v36 must include and verify its additional original map resource.
    allowed_tables=FULL_SOURCE_TABLES+NAVIGATION_TABLES+('ffe_system_information','ffe_hyperdrive')+(('ffe_fuel',) if version_code>=41 else ())+(('ffe_atmosphere',) if version_code>=42 else ())+(('ffe_landing_gear',) if version_code>=43 else ())+(('ffe_surface_contact',) if version_code>=44 else ())+(('ffe_spherical_contact',) if version_code>=45 else ())+(('ffe_natural_contact',) if version_code>=46 else ())
    assert set(required_tables)<=present_tables<=set(allowed_tables),'Full packaging verifier list omits a source table or names a missing table'
    tables={}
    for name in required_tables+('ships','world_names_ru'):
        raw=(project/'data'/f'{name}.json').read_bytes();exported=f'assets/data/{name}.json'
        assert exported in names and archive.read(exported)==raw,'Full runtime JSON differs from local source '+name
        metadata=json.loads(raw);assert isinstance(metadata,dict),'Invalid full runtime JSON '+name
        if name.startswith('ffe_'):
            image=metadata.get('original_executable_sha256') if name=='ffe_data_provenance' else metadata.get('source_sha256')
            assert image==SOURCE_IMAGE_SHA256,'Wrong original executable provenance '+name
            if 'source_assembly_sha256' in metadata:assert metadata['source_assembly_sha256']==SOURCE_ASSEMBLY_SHA256,'Wrong pinned assembly provenance '+name
            if 'source_commit' in metadata:assert metadata['source_commit']==SOURCE_ASSEMBLY_COMMIT,'Wrong pinned source revision '+name
        tables[name]=metadata
        result['data'][name]={'runtime_path':exported,'bytes':len(raw),'source_json_sha256':hashlib.sha256(raw).hexdigest()}
    ground=tables['ffe_ground_collision']
    assert ground.get('parent_models')==list(range(117,134)),'Full runtime lost a natural model terrain resource'
    assert ground['models']['117'].get('non_spherical_source_model') is True,'Source model117 must retain its non-spherical role'
    for model in ground['models'].values():
        for data_key,digest_key in [('descriptor_hex','descriptor_sha256'),('vertices_hex','vertices_sha256'),('collision_bytes_hex','collision_bytes_sha256'),('collision_preceding_hex','collision_preceding_sha256')]:
            assert hashlib.sha256(bytes.fromhex(model[data_key])).hexdigest()==model[digest_key],'Invalid ground resource component digest '+data_key
    special=tables['ffe_special_station_models']
    assert special.get('roots')==[69] and set(special.get('models',{}))=={'69','225'},'Missing actual special orbital port69 closure'
    assert tables['ffe_underground_models'].get('roots')==[96] and '96' in tables['ffe_underground_models'].get('models',{}),'Missing actual underground port96 closure'
    orbital_models=[69]+list(range(72,81))
    descriptors=tables['ffe_runtime_model_descriptors']
    assert descriptors.get('model_count')==149 and set(descriptors.get('models',{}))==set(map(str,range(149))),'Incomplete original runtime descriptor resource'
    for model in orbital_models:
        resource=special if model==69 else tables['ffe_world_models']
        assert str(model) in resource['models'],'Missing actual orbital station model '+str(model)
        record=resource['models'][str(model)]
        assert hashlib.sha256(bytes.fromhex(record['mesh_hex'])).hexdigest()==record['mesh_sha256'],'Wrong original orbital model program digest '+str(model)
        assert record['descriptor_sha256']==descriptors['models'][str(model)]['descriptor_sha256'],'Station geometry descriptor differs from source world catalogue '+str(model)
    models=re.search(r'^const\s+MODELS\s*:=\s*\[([\d,\s]+)\]\s*$',text['source_station_geometry'],re.M)
    assert models and [int(value) for value in models[1].split(',') if value.strip()]==orbital_models,'Full runtime station backend omits an actual source orbital root'
    assert 'ffe_special_station_models.json' in text['source_model_vm'],'Special orbital model resource is not reachable by runtime lookup'
    assert 'source-root69-faces110-through160-v1' in text['source_station_geometry'] and 'source-root79-faces602-through734-v1' in text['source_station_geometry'],'Special integrated source dock bays lost their explicit original-face policies'
    assert 'explicit-zero-eight-root-locals-v1' in text['source_station_geometry'],'Missing explicit static source model parameter policy'
    assert re.search(r'^const\s+REFERENCE_STEP_TICKS\s*:=\s*49710\s*$',text['source_physics_bridge'],re.M),'Sampled F603 reference step changed'
    assert re.search(r'^const\s+CONTRACT\s*:=\s*"sampled-f603-nominal-day-si-v1"\s*$',text['source_physics_bridge'],re.M),'Sampled SI bridge contract changed'
    assert 'single_current_focus_parent_f603_v1' in text['planetary_system'],'Live gravity parent-selection policy is missing'
    gravity=source_function(text['planetary_system'],'_full_gravity_at')
    assert 'by_id[focus_id]' in gravity and 'PhysicsBridge.sample_prepared' in gravity and not re.search(r'for\s+body\s*:',gravity),'Full gravity must sample its one current focus parent'
    assert 'sphere-source-ground-v4' in text['source_surface_terrain'] and 'source_exterior_probe_125pct_axes_v1' in text['source_surface_terrain'],'Shared source terrain and explicit model117 caller policy are missing'
    assert 'continuous_q31_source_probe_grid_v1' in text['source_surface_terrain'],'Shared source render/collision sampling policy changed'
    assert 'source_surface_terrain.gd' in text['source_global_body_mesh'] and 'source-height-global-lod-v1' in text['source_global_body_mesh'],'Celestial global LOD is not bound to shared source surface heights'
    for name in ['source_surface_render_packet.gd','source_surface_render_state.gd',*FULL_SOURCE_SHADERS]:
        assert 'res://scripts/'+name in text['surface_visual'],'Source terrain streaming helper is disconnected from SurfaceVisual '+name
    assert 'sphere-source-ground-v4' in text['source_surface_render_packet'] and 'source-surface-render-state-v1' in text['source_surface_render_state'],'Streaming publication must retain its explicit source terrain/frame contract'
    assert 'source_surface_contact_patch.gd' in text['surface_model'] and 'source-surface-contact-triangle-v1' in text['source_surface_contact_patch'],'Saved source contact triangle validator is disconnected from Surface'
    assert 'source_motion_profile=full' in text['source_station_session'] and 'if source_motion_profile:' in source_function(text['flight_model'],'acceleration'),'Source ship controls must be selected by world version'
    assert 'SourceControlProfile.acceleration(ship_id)' in source_function(text['flight_model'],'acceleration'),'Source control profile is disconnected from Flight'
    cobra=next((row for row in tables['ffe_ship_registry']['ships'] if row['index']==38),None)
    assert cobra is not None,'Original Cobra38 specification is missing'
    spec=bytes.fromhex(cobra['spec_hex']);spec_sha=hashlib.sha256(spec).hexdigest()
    assert len(spec)==24 and spec_sha=='b0f77d55db624b023accc8542f6b990d95515ab3e4c23bdd4e1d6e30c4cf2656' and spec_sha in text['source_ship_control_profile'],'Source control profile differs from actual original Cobra38 specification'
    decode=source_function(text['main'],'_decode_state')
    assert decode.index('candidate_world.restore(')<decode.index('StationSession.restore_flight(')<decode.index('candidate_surface.restore('),'Full save load order must remain World then Flight then Surface'
    tick=source_function(text['main'],'_tick')
    assert tick.index('StationSession.refresh(')<tick.index('ship.step(') and 'surface.set_source_time(nav.elapsed_days)' in tick,'Frame update must precede orbital Flight and source surface step'
    result.update({'compiled_module_count':len(FULL_SOURCE_MODULES),'streaming_shader_count':len(FULL_SOURCE_SHADERS),'raw_json_count':len(result['data']),'natural_model_indices':ground['parent_models'],'orbital_station_model_indices':orbital_models,'source_control_specification_sha256':spec_sha,'world_layout':'source_jjffe_systems_v4','live_gravity':'sampled-f603-nominal-day-si-v1','gravity_parent_policy':'single_current_focus_parent_f603_v1','live_terrain':'sphere-source-ground-v4','surface_streaming_packet':'source-surface-render-packet-v1','surface_streaming_state':'source-surface-render-state-v1','station_session':'selected-source-station-session-v1','native_development_fixtures_packaged':False,'compiled_source_correspondence_rebuilt_by_verifier':False,'original_per_frame_dynamics':False,'complete_original_physics':False,'physical_device_tested':False})
    if version_code>=36:
        result.update({'live_gravity':'source-fixed-parent-raw-f603-with-sampled-si-fallback-v1',
                       'retained_sampled_force_bridge':'sampled-f603-nominal-day-si-v1',
                       'raw_source_motion_scope':'Optional new-FULL-session Cobra motion around one fixed natural focus; ports, surfaces, vertical assist and other profiles retain the existing path.'})
    return result

def verify_classic_console_runtime(archive,project):
    """Check v35 console resources and declared live command connections.

    This checks packaging plus the local API contract. Independent Main/touch
    tests establish behavior; it does not decompile GDSC or claim every FFE
    instrument, mobile hit target or hardware scenario has been reproduced.
    """
    names=set(archive.namelist())
    result={'scripts':{},'compiled_source_correspondence_rebuilt_by_verifier':False}
    for name in CLASSIC_CONSOLE_MODULES:
        raw=(project/'scripts'/f'{name}.gd').read_bytes()
        exported=f'assets/scripts/{name}.gdc'
        assert exported in names,'Missing classic console runtime module '+name
        packed=archive.read(exported)
        assert len(packed)>64 and packed[:4]==b'GDSC','Invalid compiled classic console runtime module '+name
        result['scripts'][name]={'runtime_path':exported,'runtime_bytes':len(packed),'runtime_sha256':hashlib.sha256(packed).hexdigest(),'local_source_sha256':hashlib.sha256(raw).hexdigest()}
    console=(project/'scripts/flight_console.gd').read_text()
    main=(project/'scripts/main.gd').read_text()
    height=re.search(r'^const\s+HEIGHT\s*:=\s*(\d+(?:\.\d+)?)\s*$',console,re.M)
    assert height and float(height[1])==240,'Classic console logical height must be240'
    actions=[]
    for label in ['ACTIONS','EXTRA_ACTIONS']:
        declaration=re.search(r'^const\s+'+label+r'\s*:=\s*\[([^\]]+)\]',console,re.M)
        assert declaration,'Missing classic console command list '+label
        actions.extend(re.findall(r'"([^"\r\n]+)"',declaration[1]))
    assert len(actions)==len(set(actions)) and set(actions)==set(CLASSIC_CONSOLE_ACTIONS),'Classic console command set differs from the live12-action contract'
    for action in CLASSIC_CONSOLE_ACTIONS:
        assert re.search(r'^signal\s+'+action+r'_requested\b',console,re.M),'Missing classic console command signal '+action
        assert re.search(r'flight_console\.'+action+r'_requested\.connect\s*\(',main),'Classic console command is not connected to Main '+action
    result.update({'console_height_logical_px':240,'live_command_count':len(actions),'live_commands':actions,'compiled_module_count':len(CLASSIC_CONSOLE_MODULES),'complete_original_interface':False,'original_per_frame_dynamics':False,'physical_device_tested':False})
    return result

def verify_mining_kernel_runtime(archive,project):
    """Check the standalone MB4 record kernel without claiming gameplay."""
    name=SOURCE_MINING_KERNEL_MODULE
    raw=(project/'scripts'/f'{name}.gd').read_bytes();text=raw.decode('utf-8')
    exported=f'assets/scripts/{name}.gdc'
    assert exported in set(archive.namelist()),'Missing standalone MB4 record kernel'
    packed=archive.read(exported)
    assert len(packed)>64 and packed[:4]==b'GDSC','Invalid compiled standalone MB4 record kernel'
    weekly=json.loads((project/'tests/fixtures/source_mining_weekly_native.json').read_text())
    loading=json.loads((project/'tests/fixtures/source_mining_load_native.json').read_text())
    for fixture in [weekly,loading]:
        assert fixture['source_commit']==SOURCE_ASSEMBLY_COMMIT and fixture['source_assembly_sha256']==SOURCE_ASSEMBLY_SHA256,'Wrong standalone MB4 native fixture provenance'
        assert len(fixture['cases'])==fixture['case_count'] and fixture['fresh_process_runs']==3 and fixture['record_guards_unchanged'] is True,'Incomplete standalone MB4 native fixture'
    expected={'SOURCE_ASM_SHA256':SOURCE_ASSEMBLY_SHA256,'F243_SHA256':weekly['f243_sha256'],'F247_SHA256':loading['source_function_sha256']['247'],'F252_SHA256':loading['source_function_sha256']['252']}
    for constant,digest in expected.items():
        assert re.search(r'^const\s+'+constant+r'\s*:=\s*"'+re.escape(digest)+r'"\s*$',text,re.M),'Standalone MB4 provenance constant differs '+constant
    mapping=re.search(r'^const\s+COMMODITY_BY_PROSPECT\s*:=\s*\[([\d,\s]+)\]\s*$',text,re.M)
    assert mapping and [int(value) for value in mapping[1].split(',') if value.strip()]==loading['commodity_map'],'Standalone MB4 commodity map differs from original native fixture'
    return {'runtime_path':exported,'runtime_bytes':len(packed),'runtime_sha256':hashlib.sha256(packed).hexdigest(),'local_source_sha256':hashlib.sha256(raw).hexdigest(),'native_fixture_provenance_checked':True,'native_weekly_case_count':weekly['case_count'],'native_load_case_count':loading['case_count'],'oracle_executed_by_apk_verifier':False,'integrated_gameplay':False,'physical_deployment_implemented':False,'weekly_world_scheduler_integrated':False,'star_fuel_scoop_integrated':False,'physical_device_tested':False}

def verify_navigation_runtime(archive,project):
    """Check v36 navigation/time/motion packaging and real Main consumers.

    Hashes and local API checks do not decompile GDSC or rerun native oracles.
    Native/reference, UI and Main behavior are established by separate suites.
    """
    names=set(archive.namelist());text={}
    result={'scripts':{},'data':{},'native_reference_metadata':{},
            'compiled_source_correspondence_rebuilt_by_verifier':False,
            'oracle_executed_by_apk_verifier':False,'physical_device_tested':False}
    for name in NAVIGATION_MODULES:
        raw=(project/'scripts'/f'{name}.gd').read_bytes();text[name]=raw.decode('utf-8')
        exported=f'assets/scripts/{name}.gdc'
        assert exported in names,'Missing navigation runtime module '+name
        packed=archive.read(exported)
        assert len(packed)>64 and packed[:4]==b'GDSC','Invalid compiled navigation runtime module '+name
        result['scripts'][name]={'runtime_path':exported,'runtime_bytes':len(packed),
                                 'runtime_sha256':hashlib.sha256(packed).hexdigest(),
                                 'local_source_sha256':hashlib.sha256(raw).hexdigest()}
    raw=(project/'data/ffe_galactic_map.json').read_bytes();exported='assets/data/ffe_galactic_map.json'
    assert exported in names and archive.read(exported)==raw,'Navigation map JSON differs from local source'
    data=json.loads(raw)
    assert data.get('schema')==1 and data.get('source_sha256')==SOURCE_IMAGE_SHA256,'Wrong navigation map executable provenance'
    assert data.get('source_assembly_sha256')==SOURCE_ASSEMBLY_SHA256 and data.get('source_commit')==SOURCE_ASSEMBLY_COMMIT,'Wrong navigation map assembly provenance'
    assert data.get('display_sector_offset_raw')==[5912,5412] and data.get('source_overview_pixels')==[320,158],'Changed original map coordinates or overview dimensions'
    indices=data.get('overview_palette_indices');palette=data.get('overview_palette_rgb6')
    assert isinstance(indices,list) and len(indices)==64 and all(type(i) is int and 0<=i<16 for i in indices),'Invalid original map density palette'
    assert isinstance(palette,list) and len(palette)==16 and all(isinstance(row,list) and len(row)==3 and all(type(c) is int and 0<=c<64 for c in row) for row in palette),'Invalid original map RGB6 palette'
    assert data.get('overview_density_ignores_handcrafted_count_override') is True,'Overview must retain its distinct F853 caller mode'
    blocks={(b['first_label'],b['bytes']):b['sha256'] for b in data.get('source_blocks',[]) if b.get('matches_source_bytes') is True}
    assert blocks=={(6821,256):'6078def153120d68cdd56738615176d192afa1ac27ccdc7dae30c8d9e132ddd6',
                    (7769,384):'79fc5dd2e848ba8c8edad4955f3a863153a95a215a492b0e9a8b4e3ff5fbdab2',
                    (6812,240):'ad0feb1b7b071299819d6ed08dd95eea22ad865e60b74d471b42b74906512297'},'Original map source blocks changed'
    result['data']['ffe_galactic_map']={'runtime_path':exported,'bytes':len(raw),'source_json_sha256':hashlib.sha256(raw).hexdigest(),'source_landmark_count':len(data.get('landmarks',[]))}
    for name in ['main','flight_model','source_station_session']:
        text[name]=(project/'scripts'/f'{name}.gd').read_text()
    main=text['main']
    for alias,module in [('GalacticMap','galactic_map_view'),('SystemMap','system_map_view'),('TimeController','flight_time_controller'),('TimeControls','flight_time_controls'),('RollControl','roll_control'),('MotionBridge','source_motion_bridge')]:
        assert re.search(r'const\s+'+alias+r'\s*=\s*preload\("res://scripts/'+module+r'\.gd"\)',main),'Navigation Main preload missing '+module
    for view,model in [('galactic_map_view','galactic_map_model'),('system_map_view','system_map_model')]:
        assert 'res://scripts/'+model+'.gd' in text[view],'Navigation view lost its data model '+view
    galactic=source_function(main,'_show_routes');system=source_function(main,'_show_system')
    assert 'GalacticMap.new()' in galactic and 'view.configure_state(' in galactic and 'view.system_selected.connect(' in galactic and 'view.jump_requested.connect(' in galactic and '_start_jump(id)' in galactic,'Graphical galactic map is not connected to Main navigation'
    assert 'SystemMap.new()' in system and 'view.configure(' in system and 'world.snapshot()' in system and 'view.body_selected.connect(' in system and 'view.site_selected.connect(' in system and 'view.travel_requested.connect(' in system and '_choose_body(body_id)' in system and '_choose_site(site_id)' in system,'Graphical system map is not connected to Main selections/travel'
    assert 'is_instance_valid(active_map)' in source_function(main,'_blocked'),'Map must block flight input'
    assert '_release_inputs()' in source_function(main,'_install_map') and 'flight_time.interrupt(' in source_function(main,'_install_map'),'Map opening must release flight input and interrupt accelerated time'
    advance=source_function(main,'_advance_controls')
    for marker in ['flight_time.plan_frame(','flight_time.can_continue(','flight_time.finish_frame(','_tick(step,']:
        assert marker in advance,'Bounded time controller is not connected to Main '+marker
    assert re.search(r'^const\s+MAX_IMPLEMENTED_RATE\s*:=\s*100\s*$',text['flight_time_controller'],re.M),'Unsupported time rates must remain disabled'
    assert re.search(r'^const\s+MAX_SUBSTEPS\s*:=\s*32\s*$',text['flight_time_controller'],re.M) and re.search(r'^const\s+MAX_STEP_SECONDS\s*:=\s*0\.1\s*$',text['flight_time_controller'],re.M),'Bounded time substep policy changed'
    assert 'time_controls.rate_requested.connect(_request_time_rate)' in main and 'flight_time.rate_options(' in source_function(main,'_request_time_rate'),'Time buttons are not connected to the real scheduler'
    assert main.count('RollControl.new()')>=2 and 'roll1.axis_changed.connect(' in main and 'roll2.axis_changed.connect(' in main and 'roll_right_strength-roll_left_strength' in advance,'Analog phone roll is not connected to Main flight input'
    assert 'res://scripts/rotating_dock_dynamics.gd' in text['flight_model'] and 'RotatingDock.sweep(' in text['flight_model'] and 'RotatingDock.surface_velocity(' in text['flight_model'],'Rotating station contact is not consumed by Flight'
    assert 'ship.configure_source_station(geometry,basis,step_seconds)' in text['source_station_session'],'Station coordinator must supply the sampled rotation interval'
    tick=source_function(main,'_tick');motion_step=source_function(main,'_source_motion_step')
    assert '_source_motion_step(dt,steering,roll,lift)' in tick and 'ship.step(' in tick,'Main lost the scoped raw-motion branch or compatible fallback'
    assert re.search(r'if\s+not\s+source_motion_enabled\b',motion_step),'Source motion must respect the saved session enable gate'
    assert re.search(r'source_motion_enabled\s*=\s*layout\s*==\s*World\.FULL_LAYOUT',source_function(main,'_new_models')),'Only new FULL sessions may select the raw-motion path by default'
    assert 'MotionBridge.eligible(' in motion_step and 'source_motion.step(' in motion_step and 'settings.orbital_gravity' in motion_step,'Source motion bridge is not connected with its explicit guards'
    eligibility=source_function(text['source_motion_bridge'],'eligible')
    for marker in ['"cobra"','surface_active','"station_available"','"site_id"','"star"','"barycenter"']:
        assert marker in eligibility,'Source motion bridge lost an explicit scope guard '+marker
    assert 'res://scripts/source_motion_pipeline.gd' in text['source_motion_bridge'],'Source motion bridge lost its raw kernel'
    sequence=source_function(text['source_motion_pipeline'],'manual_step')
    for marker in ['Gravity.update(','desired_acceleration(','set_thrust(','velocity_step(','Gravity.integrate(']:
        assert marker in sequence,'Raw source motion composition lost '+marker
    payload=source_function(main,'_payload');decode=source_function(main,'_decode_state')
    assert 'if source_motion_enabled:' in payload and 'result.motion_session=' in payload,'Optional raw-motion session is not saved'
    assert 'candidate_motion_enabled:=false' in decode and 'if data.has("motion_session"):' in decode and 'candidate_motion.restore(' in decode,'Old saves must keep the previous path unless an explicit raw-motion session is present'
    assert 'candidate_motion.is_active()' in decode and 'candidate_nav.elapsed_days=candidate_motion.elapsed_days()' in decode,'Validated active raw motion must restore its exact saved clock'
    assert re.search(r'func\s+elapsed_days\(\)\s*->\s*float\s*:',text['source_motion_bridge']),'Source motion bridge is missing its validated exact-clock API'
    fixtures=[('source_motion_native','source_motion_pipeline','profile','body_and_bank_canaries_unchanged','reverse_case_count'),
              ('source_frame_native','source_frame_kinematics','profile','canaries_and_matrix_unchanged','reverse_case_count'),
              ('source_time_controls_native','flight_time_controller',None,'guards_unchanged','reverse_repeat_cases'),
              ('source_galactic_map_native','galactic_map_model',None,'canaries_unchanged','reverse_repeat_count')]
    for name,module,profile_key,guard,reverse in fixtures:
        path=project/'tests/fixtures'/f'{name}.json';fixture_raw=path.read_bytes();fixture=json.loads(fixture_raw)
        assert fixture.get('source_assembly_sha256')==SOURCE_ASSEMBLY_SHA256 and fixture.get('source_commit')==SOURCE_ASSEMBLY_COMMIT,'Wrong navigation native reference provenance '+name
        if 'source_executable_sha256' in fixture:assert fixture['source_executable_sha256']==SOURCE_IMAGE_SHA256,'Wrong source image in navigation reference '+name
        if 'source_sha256' in fixture:assert fixture['source_sha256']==SOURCE_IMAGE_SHA256,'Wrong source image in navigation reference '+name
        assert type(fixture.get('case_count')) is int and fixture['case_count']>0 and len(fixture.get('cases',[]))==fixture['case_count'] and fixture.get(guard) is True and fixture.get(reverse)==fixture['case_count'],'Incomplete navigation native reference '+name
        fresh=fixture.get('fresh_process_runs_per_scale') if name=='source_galactic_map_native' else fixture.get('fresh_process_runs')
        assert fresh==3,'Navigation native reference requires three fresh processes '+name
        if profile_key:
            profile=re.search(r'^const\s+PROFILE\s*:=\s*"([^"]+)"\s*$',text[module],re.M)
            assert profile and fixture[profile_key]==profile[1],'Navigation native profile differs from runtime '+module
        if name=='source_galactic_map_native':assert fixture.get('runtime_resource_sha256')==hashlib.sha256(raw).hexdigest(),'Map resource differs from native-used bytes'
        result['native_reference_metadata'][name]={'local_path':str(path.relative_to(project)),'sha256':hashlib.sha256(fixture_raw).hexdigest(),'case_count':fixture['case_count'],'fresh_process_runs':fresh,'provenance_checked':True,'oracle_executed_by_apk_verifier':False}
    result.update({'compiled_module_count':len(NAVIGATION_MODULES),'raw_json_count':1,
                   'galactic_map_connected':True,'system_map_connected':True,'original_map_overview_data_verified':True,
                   'galactic_map_renderer_policy':'modern-touch-projection-with-original-density-palette-landmarks-and-sector-data',
                   'complete_original_map_renderer':False,'complete_original_map_instruments':False,
                   'galactic_search_scope':'bounded local window plus original named-system catalogue, not exhaustive global name enumeration',
                   'implemented_time_rates':[1,10,100],'disabled_time_rates':[1000,10000],'maximum_substeps':32,'maximum_substep_seconds':0.1,
                   'original_time_scheduler_complete':False,'analog_phone_roll_connected':True,
                   'rotating_station_contact':'sampled-pose-modern-conservative-sweep-with-omega-cross-radius',
                   'complete_original_f582_collision':False,'raw_source_motion_connected':True,
                   'raw_source_motion_scope':'Optional new FULL sessions; Cobra around a fixed natural focus; ports/surfaces/vertical assist and other profiles use existing fallback.',
                   'old_saves_without_motion_session_use_previous_path':True,
                   'active_raw_session_restores_validated_ieee64_clock':True,
                   'source_frame_primitives_standalone':True,'automatic_source_for_parent_selection':False,
                   'original_hyperdrive_f903_complete':False,'complete_original_player_pipeline':False,'complete_original_physics':False})
    return result

def _verify_map_visual_contract(archive,project,protected_source_sha256,baseline_source_commit):
    """Check map presentation inputs explicitly selected by the version wrapper.

    Protected input hashes come from the exact v36 source checkpoint, not from
    the new view. They establish selected local source/data preservation;
    compiled GDSC is checked and hashed, not decompiled or equated to source.
    """
    path='assets/scripts/galactic_map_view.gdc'
    assert path in set(archive.namelist()),'Missing modern map visual runtime'
    packed=archive.read(path)
    assert len(packed)>64 and packed[:4]==b'GDSC','Invalid compiled modern map visual runtime'
    raw=(project/'scripts/galactic_map_view.gd').read_bytes();text=raw.decode('utf-8')
    assert re.search(r'^const\s+PRESENTATION_PROFILE\s*:=\s*"'+re.escape(MAP_VISUAL_PROFILE)+r'"\s*$',text,re.M),'Modern map presentation profile missing or changed'
    assert re.search(r'set_meta\(\s*"presentation_profile"\s*,\s*PRESENTATION_PROFILE\s*\)',source_function(text,'_ready')),'Modern map presentation profile is not consumed by the view'
    protected={}
    for relative,expected in protected_source_sha256.items():
        actual=hashlib.sha256((project/relative).read_bytes()).hexdigest()
        assert actual==expected,'Visual-only map update changed protected source/data '+relative
        protected[relative]=actual
    functions={}
    for name,expected in MAP_VISUAL_PROTECTED_FUNCTION_SHA256.items():
        actual=hashlib.sha256(source_function(text,name).encode()).hexdigest()
        assert actual==expected,'Visual-only map update changed protected input/worker function '+name
        functions[name]=actual
    return {'presentation_profile':MAP_VISUAL_PROFILE,'runtime_path':path,'runtime_bytes':len(packed),
            'runtime_sha256':hashlib.sha256(packed).hexdigest(),'local_source_sha256':hashlib.sha256(raw).hexdigest(),
            'baseline_source_commit':baseline_source_commit,
            'protected_source_data_sha256':protected,'protected_view_function_sha256':functions,
            'protected_source_data_count':len(protected),'protected_view_function_count':len(functions),
            'additional_runtime_modules':0,'additional_shaders':0,'additional_textures':0,
            'original_map_data_preserved':True,'display_color_transfer_is_presentation':True,
            'complete_original_renderer':False,'compiled_source_correspondence_rebuilt_by_verifier':False,
            'behavior_proved_by_this_package_check':False,'physical_device_tested':False}

def verify_map_visual_runtime(archive,project):
    # Historical v37 contract stays strict, including the complete previous Main.
    return _verify_map_visual_contract(archive,project,MAP_VISUAL_PROTECTED_SOURCE_SHA256,MAP_VISUAL_BASELINE_SOURCE_COMMIT)

def verify_celestial_visibility_runtime(archive,project):
    """v38 allows Main projection and FULL star coverage, with protected inputs.

    These checks pin selected source functions and require actual consumers;
    exported GDSC is hashed, never claimed equivalent to local source.
    Functional visibility and eclipse tests are separate acceptance evidence.
    """
    protected={path:value for path,value in MAP_VISUAL_PROTECTED_SOURCE_SHA256.items() if path!='scripts/main.gd'}
    map_assets=_verify_map_visual_contract(archive,project,protected,CELESTIAL_VISUAL_BASELINE_SOURCE_COMMIT)
    view_hash=hashlib.sha256((project/'scripts/galactic_map_view.gd').read_bytes()).hexdigest()
    assert view_hash==CELESTIAL_VISUAL_GALACTIC_VIEW_SHA256,'Celestial presentation fix changed the galactic map view'
    runtime={}
    for name in CELESTIAL_VISUAL_RUNTIME_MODULES:
        path='assets/scripts/'+name+'.gdc'
        assert path in set(archive.namelist()),'Missing celestial visibility runtime '+name
        packed=archive.read(path)
        assert len(packed)>64 and packed[:4]==b'GDSC','Invalid compiled celestial visibility runtime '+name
        runtime[name]={'path':path,'bytes':len(packed),'sha256':hashlib.sha256(packed).hexdigest(),
                       'local_source_sha256':hashlib.sha256((project/'scripts'/str(name+'.gd')).read_bytes()).hexdigest()}
    main=(project/'scripts/main.gd').read_text();renderer=(project/'scripts/celestial_renderer.gd').read_text()
    main_functions={}
    for name,expected in CELESTIAL_VISUAL_PROTECTED_MAIN_FUNCTION_SHA256.items():
        text=source_function(main,name)
        # This one existing initialization method gains only a presentation call.
        if name=='_apply_system':
            suffix=';_sync_scene();_update_flight_projection()'
            assert text.count('_update_flight_projection()')==1 and re.search(re.escape(suffix)+r'\n\s*\Z',text),'System initialization may only append one projection call after scene synchronization'
            text=text.replace(';_update_flight_projection()','',1)
        actual=hashlib.sha256(text.encode()).hexdigest()
        assert actual==expected,'Celestial presentation fix changed protected Main function '+name
        main_functions[name]=actual
    renderer_functions={}
    for name,expected in CELESTIAL_VISUAL_PROTECTED_RENDERER_FUNCTION_SHA256.items():
        actual=hashlib.sha256(source_function(renderer,name).encode()).hexdigest()
        assert actual==expected,'Celestial presentation fix changed protected renderer function '+name
        renderer_functions[name]=actual
    transition=source_function(renderer,'set_surface_transition')
    assert '\tif last_high_focus' in transition,'Legacy celestial transition missing'
    legacy_hash=hashlib.sha256(transition.split('\tif last_high_focus',1)[1].encode()).hexdigest()
    assert legacy_hash==CELESTIAL_VISUAL_LEGACY_TRANSITION_SHA256,'Celestial presentation fix changed the legacy transition'
    full_transition=transition.split('\tif last_high_focus',1)[0]
    assert 'str(body.get("kind",""))=="star" and type_code>=17 and type_code<=30' in full_transition,'FULL celestial transition lacks actual luminous-star classification'
    assert '1.0 if not enabled or id==context.focus_id or luminous else surface_space_blend' in full_transition,'Luminous star coverage is not connected to the FULL transition'
    assert 'set_shader_parameter("view_coverage",coverage)' in full_transition,'FULL star coverage is not consumed by the mesh material'
    projection=source_function(main,'_update_flight_projection')
    for token in ['flight_console.get_global_rect()','flight_view_rect.get_center()','camera.set_frustum(',
                  'camera.near','camera.far','camera.fov','camera.keep_aspect','_flight_projection_signature']:
        assert token in projection,'Flight projection lacks real console/camera consumer '+token
    assert not re.search(r'\b(?:ship|world|nav|surface|source_motion)\s*[.\[]',projection),'Flight projection must not access simulation state'
    assert not re.search(r'camera\.(?:position|quaternion|rotation|basis|transform)\b',projection),'Flight projection must preserve physical camera pose'
    for name in ['_safe_area','_apply_system','_process']:
        assert '_update_flight_projection()' in source_function(main,name),'Flight projection is not connected to '+name
    ui=source_function(main,'_build_ui')
    assert 'Vector4(0,0,0,-FlightConsole.HEIGHT)' in ui and '-20-console_height*0.5' in ui,'Flight reticle and cross must use the unobscured flight area'
    return {'baseline_source_commit':CELESTIAL_VISUAL_BASELINE_SOURCE_COMMIT,
            'presentation_runtime_modules':runtime,'presentation_runtime_module_count':len(runtime),
            'galactic_map_visual_assets':map_assets,'unchanged_galactic_map_view_sha256':view_hash,
            'protected_source_data_count':len(protected),'protected_main_function_sha256':main_functions,
            'protected_main_function_count':len(main_functions),'main_apply_system_normalization':'Exactly one appended ;_update_flight_projection() immediately after the final _sync_scene() is excluded from the prior function hash.',
            'protected_renderer_function_sha256':renderer_functions,'protected_renderer_function_count':len(renderer_functions),
            'legacy_transition_sha256':legacy_hash,'actual_console_camera_projection_consumers':True,
            'full_star_coverage_material_consumer_checked':True,
            'physical_camera_pose_unchanged_by_projection':True,'additional_runtime_modules':0,'additional_shaders':0,'additional_textures':0,
            'compiled_source_correspondence_rebuilt_by_verifier':False,'visibility_or_eclipse_proved_by_this_package_check':False,
            'physical_device_tested':False,'astronomically_calibrated_star_radii':False,'complete_original_renderer':False}

def _verify_system_information_payload(archive,project):
    """Unchanged code39 source/RU/compiled controls, reused by later modules."""
    modules={}
    for name in SYSTEM_INFORMATION_MODULES:
        path='assets/scripts/'+name+'.gdc'
        assert path in set(archive.namelist()),'Missing system information runtime '+name
        packed=archive.read(path)
        assert len(packed)>64 and packed[:4]==b'GDSC','Invalid compiled system information runtime '+name
        modules[name]={'runtime_sha256':hashlib.sha256(packed).hexdigest(),
                       'local_source_sha256':hashlib.sha256((project/'scripts'/f'{name}.gd').read_bytes()).hexdigest()}
    tables={}
    for name in SYSTEM_INFORMATION_TABLES:
        path='assets/data/'+name+'.json'
        assert path in set(archive.namelist()),'Missing system information resource '+name
        raw=archive.read(path)
        assert raw==(project/'data'/f'{name}.json').read_bytes(),'System information resource differs from source '+name
        tables[name]={'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
    source=json.loads(archive.read('assets/data/ffe_system_information.json'))
    language=json.loads(archive.read('assets/data/system_information_ru.json'))
    for data in [source,language]:
        assert data.get('schema')==1 and data.get('source_sha256')==SOURCE_IMAGE_SHA256,'Wrong system information source provenance'
        assert data.get('source_assembly_sha256')==SOURCE_ASSEMBLY_SHA256,'Wrong system information assembly provenance'
    assert len(source.get('strings',{}))==358 and len(source.get('ff_code_to_label',{}))==349,'Incomplete original information text graph'
    assert set(source['strings'])==set(language.get('strings',{})),'Russian information string coverage differs from original'
    for key,entry in source['strings'].items():
        raw=bytes.fromhex(entry['hex'])
        assert raw and raw[-1]==0 and raw.find(b'\0')==len(raw)-1,'Information string crosses its original C boundary '+key
        assert language['strings'][key].get('source_hex')==entry['hex'],'Russian template refers to different original bytes '+key
        tokens=[];at=0
        while at<len(raw)-1:
            byte=raw[at]
            if byte in (255,254):
                assert at+2<len(raw)-1,'Truncated information FF/FE operand '+key
                tokens.append('{%s%02X%02X}'%('FF' if byte==255 else 'FE',raw[at+1],raw[at+2]));at+=3
            elif byte==253:
                assert at+1<len(raw)-1,'Truncated information FD operand '+key
                tokens.append('{FD%02X}'%raw[at+1]);at+=2
            else:
                if byte==13:tokens.append('\r')
                elif byte<32:tokens.append('{CTRL%02X}'%byte)
                at+=1
        translated=language['strings'][key].get('text')
        assert isinstance(translated,str) and '\0' not in translated,'Invalid Russian information template '+key
        assert re.findall(r'\{(?:FF[0-9A-F]{4}|FD[0-9A-F]{2}|FE[0-9A-F]{4}|CTRL[0-9A-F]{2})\}|\r',translated)==tokens,'Russian information variable/layout tokens differ '+key
        assert re.findall(r'%[si]',translated)==[item.decode() for item in re.findall(rb'%[si]',raw[:-1])],'Russian information formatting arguments differ '+key
    long_strings=[bytes.fromhex(source['strings'][str(index)]['hex']) for index in range(7139,7183)]
    blank=sum(not raw[:-1].strip() for raw in long_strings)
    assert blank==19 and len(long_strings)-blank==25,'Incorrect first-NUL long-description boundary'
    assert source.get('metadata_stride_bytes')==54 and source.get('negative_rows')==8,'Incorrect DOS information policy stride'
    assert source.get('dos_record_rows')==338 and source.get('dos_sentinel_offset')==18198,'Incorrect DOS information policy domain'
    assert len(bytes.fromhex(source['dos_metadata_hex']))==18268,'Incorrect DOS information policy bytes'
    assert language.get('language')=='ru' and language.get('coverage',{}).get('complete_game_localization') is False,'Russian information scope is not explicit'
    for name,expected in SYSTEM_INFORMATION_RESOURCE_SHA256.items():
        assert tables[name]['sha256']==expected,'System information resource differs from reviewed original/translation '+name
    return {'modules':modules,'tables':tables}

def verify_system_information_runtime(archive,project):
    """Require actual information consumers/data while preserving flight logic.

    This verifies package/source inputs and narrowly allowed UI hooks; original
    instruction controls, translation review, Main behavior and GPU are separate.
    """
    protected={path:value for path,value in MAP_VISUAL_PROTECTED_SOURCE_SHA256.items()
               if path not in ('scripts/main.gd','scripts/system_map_view.gd')}
    map_assets=_verify_map_visual_contract(archive,project,protected,SYSTEM_INFORMATION_BASELINE_SOURCE_COMMIT)
    information=_verify_system_information_payload(archive,project)
    modules,tables=information['modules'],information['tables']
    main=(project/'scripts/main.gd').read_text()
    additions={
        '_show_system':'\tview.information_requested.connect(func(id:String):\n\t\tif active_map==view:_show_information(world.system_id,id)\n\t)\n',
        '_show_routes':'\tview.information_requested.connect(func(id:int):\n\t\tif active_map==view:_show_information(id)\n\t)\n',
        '_close_map':'\tif active_map_kind=="information":\n\t\tif save_progress:_close_information();return\n\t\t_finish_information_preparation();_discard_information_parent()\n',
    }
    hashes={}
    for name,expected in CELESTIAL_VISUAL_PROTECTED_MAIN_FUNCTION_SHA256.items():
        text=source_function(main,name)
        if name in additions:
            assert text.count(additions[name])==1,'Information requires exactly one declared Main hook '+name
            text=text.replace(additions[name],'',1)
        if name=='_apply_system':
            suffix=';_sync_scene();_update_flight_projection()'
            assert text.count('_update_flight_projection()')==1 and re.search(re.escape(suffix)+r'\n\s*\Z',text),'Information must preserve the Mercury projection consumer'
            text=text.replace(';_update_flight_projection()','',1)
        actual=hashlib.sha256(text.encode()).hexdigest()
        assert actual==expected,'Information update changed protected Main function '+name
        hashes[name]=actual
    for name,expected in SYSTEM_INFORMATION_MAIN_HELPER_SHA256.items():
        assert hashlib.sha256(source_function(main,name).encode()).hexdigest()==expected,'Information update changed audited read-only Main helper '+name
    allowed={
        '_process':'\t_pump_information()\n',
        '_exit_tree':'\t_finish_information_preparation()\n\tif is_instance_valid(information_parent) and information_parent.has_method("finish_preparation"):information_parent.finish_preparation()\n',
        '_show_status':'\t_menu_action("Сведения о системе",func():_show_information())\n',
    }
    for name,expected in SYSTEM_INFORMATION_BASELINE_MAIN_FUNCTION_SHA256.items():
        text=source_function(main,name)
        if name in allowed:
            assert text.count(allowed[name])==1,'Information requires exactly one declared presentation consumer '+name
            text=text.replace(allowed[name],'',1)
        assert hashlib.sha256(text.encode()).hexdigest()==expected,'Information update changed protected projection/lifecycle function '+name
    celestial=hashlib.sha256((project/'scripts/celestial_renderer.gd').read_bytes()).hexdigest()
    assert celestial==SYSTEM_INFORMATION_CELESTIAL_SHA256,'Information update changed the Mercury stellar-visibility fix'
    for view in ['system_map_view','galactic_map_view']:
        text=(project/'scripts'/f'{view}.gd').read_text()
        assert 'signal information_requested(' in text and 'information_requested.emit(' in text,'Missing live information action '+view
    for relative,expected in SYSTEM_INFORMATION_MAP_VIEW_SHA256.items():
        assert hashlib.sha256((project/relative).read_bytes()).hexdigest()==expected,'Information update changed audited map view '+relative
    opening=source_function(main,'_show_information')
    assert 'information_parent=active_map' in opening and 'duplicate(true)' in opening,'Information must retain parent UI and copy records'
    assert '_save_game' not in opening and 'begin_jump' not in opening and 'begin_transfer' not in opening,'Information opening must remain read-only'
    assert '_pump_information()' in source_function(main,'_process'),'Information worker is not consumed by Main'
    assert '_finish_information_preparation()' in source_function(main,'_exit_tree'),'Information worker lacks cleanup'
    assert '_close_information' in source_function(main,'_close_map'),'Information lacks parent-map return'
    for name,expected in SYSTEM_INFORMATION_RESOURCE_SHA256.items():
        assert tables[name]['sha256']==expected,'System information resource differs from reviewed original/translation '+name
    return {'baseline_source_commit':SYSTEM_INFORMATION_BASELINE_SOURCE_COMMIT,
            'compiled_modules':modules,'compiled_module_count':len(modules),'resources':tables,
            'source_strings':358,'ff_lookups':349,'long_descriptions':44,'long_nonblank_descriptions':25,
            'long_blank_descriptions':19,'dos_metadata_rows':338,'source_variant':'uploaded_DOS_information_policy',
            'protected_main_functions':hashes,'protected_main_function_count':len(hashes),
            'galactic_map_visual_assets':map_assets,'unchanged_celestial_renderer_sha256':celestial,
            'additional_runtime_modules':3,'additional_shaders':0,'additional_textures':0,
            'raw_original_and_ru_resources_checked':True,'read_only_Main_consumers_checked':True,
            'original_instruction_oracle_executed_by_this_check':False,
            'complete_original_information_pages':False,'complete_original_text_interpreter':False,
            'complete_game_localization':False,'physical_device_tested':False}


def _verify_hyperdrive_payload(archive,project):
    """Retained code40 byte/native metadata controls shared with later fuel."""
    names=set(archive.namelist());modules={}
    for name in HYPERDRIVE_MODULES:
        path='assets/scripts/'+name+'.gdc'
        assert path in names,'Missing hyperdrive runtime module '+name
        packed=archive.read(path)
        assert len(packed)>64 and packed[:4]==b'GDSC','Invalid compiled hyperdrive runtime '+name
        modules[name]={'runtime_sha256':hashlib.sha256(packed).hexdigest(),
                       'local_source_sha256':hashlib.sha256((project/'scripts'/f'{name}.gd').read_bytes()).hexdigest()}
    path='assets/data/ffe_hyperdrive.json'
    assert path in names,'Missing hyperdrive resource'
    raw=archive.read(path)
    assert raw==(project/'data/ffe_hyperdrive.json').read_bytes(),'Hyperdrive resource differs from source'
    data=json.loads(raw)
    assert data.get('schema')==1 and data.get('source_sha256')==SOURCE_IMAGE_SHA256,'Wrong hyperdrive source provenance'
    assert data.get('source',{}).get('ffe_asm_sha256')==SOURCE_ASSEMBLY_SHA256 and data.get('source',{}).get('jjffe_commit')==SOURCE_ASSEMBLY_COMMIT,'Wrong hyperdrive assembly provenance'
    drive_raw=bytes.fromhex(data.get('drive_table_hex',''))
    assert data.get('drive_count')==15 and data.get('drive_stride_bytes')==16 and len(drive_raw)==240,'Incorrect original hyperdrive table domain'
    assert hashlib.sha256(drive_raw).hexdigest()=='82659f368ab7b4298735b16b4f76276207a19d1b529526c4452c2c78569fe654','Changed original hyperdrive table bytes'
    assert sorted(map(int,data.get('ship_specs',{})))==list(range(15,72)),'Incomplete original hyperdrive ship specifications'
    for key,spec in data['ship_specs'].items():
        packed=bytes.fromhex(spec['spec_hex'])
        assert len(packed)==24 and hashlib.sha256(packed).hexdigest()==spec['spec_sha256'],'Changed original hyperdrive ship spec '+key
        assert struct.unpack_from('<hh',packed,6)==(spec['hull_mass_tonnes_s16'],spec['internal_capacity_tonnes_s16']),'Incorrect signed original hyperdrive ship spec '+key
    for ship,expected in {'cobra':(38,3,4,6,True),'eagle':(24,2,1,6,False),'shuttle':(15,1,0,0,False)}.items():
        profile=data.get('new_session_profiles',{}).get(ship,{})
        assert tuple(profile.get(key) for key in ['source_model_index','source_drive_index','hydrogen','fixed_equipment_space_t','original_starter'])==expected,'Changed audited new-session hyperdrive profile '+ship
        assert profile.get('military')==profile.get('waste')==0,'Incorrect initial hyperdrive cargo '+ship
    assert hashlib.sha256(raw).hexdigest()==HYPERDRIVE_RESOURCE_SHA256,'Hyperdrive resource differs from reviewed DOS extraction'
    fixture_path=project/'tests/fixtures/source_hyperdrive_native.json'
    fixture_raw=fixture_path.read_bytes();fixture=json.loads(fixture_raw)
    assert hashlib.sha256(fixture_raw).hexdigest()==HYPERDRIVE_NATIVE_SHA256,'Changed independent hyperdrive native reference'
    assert fixture.get('source_sha256')==SOURCE_IMAGE_SHA256 and fixture.get('source_assembly_sha256')==SOURCE_ASSEMBLY_SHA256 and fixture.get('source_commit')==SOURCE_ASSEMBLY_COMMIT,'Wrong hyperdrive native provenance'
    assert fixture.get('drive_table_hex')==data['drive_table_hex'] and fixture.get('drive_count')==15,'Hyperdrive native table differs from runtime'
    for key,spec in data['ship_specs'].items():
        assert fixture.get('ship_specs',{}).get(key,{}).get('spec_hex')==spec['spec_hex'],'Hyperdrive native spec differs from runtime '+key
    assert fixture.get('case_count')==len(fixture.get('cases',[]))==5453 and fixture.get('unsafe_case_count')==len(fixture.get('unsafe_cases',[]))==11,'Incomplete independent hyperdrive cases'
    assert fixture.get('fresh_process_runs')==3 and fixture.get('reverse_repeat_count')==5453 and all(fixture.get(key) is True for key in ['canaries_unchanged','nonfuel_object_bytes_unchanged','specifications_unchanged']),'Incomplete independent hyperdrive reproduction/boundaries'
    return {'modules':modules,'raw':raw,'data':data,'fixture':fixture}

def verify_hyperdrive_runtime(archive,project):
    """Code40 package inputs and audited consumers, without executing GDSC.

    Exact source pins follow the reviewed integration checkpoint. Native kernel,
    live Main and UI behavior are tested separately; package evidence does not
    imply F908/arrival, original economy, or complete original physics parity.
    """
    payload=_verify_hyperdrive_payload(archive,project)
    modules,raw,data=payload['modules'],payload['raw'],payload['data']
    # Preserve all code39 original/RU boundaries and variable controls. The
    # three information scripts are frozen as well, rather than skipped.
    information=_verify_system_information_payload(archive,project)
    for relative,expected in HYPERDRIVE_INFORMATION_SOURCE_SHA256.items():
        assert hashlib.sha256((project/relative).read_bytes()).hexdigest()==expected,'Hyperdrive update changed information runtime '+relative
    protected={path:value for path,value in MAP_VISUAL_PROTECTED_SOURCE_SHA256.items()
               if path not in ('scripts/main.gd','scripts/system_map_view.gd','scripts/navigation.gd','scripts/galactic_map_model.gd')}
    for relative,expected in protected.items():
        assert hashlib.sha256((project/relative).read_bytes()).hexdigest()==expected,'Hyperdrive update changed protected flight/source data '+relative
    celestial=hashlib.sha256((project/'scripts/celestial_renderer.gd').read_bytes()).hexdigest()
    assert celestial==SYSTEM_INFORMATION_CELESTIAL_SHA256,'Hyperdrive update changed the Mercury stellar-visibility fix'
    assert hashlib.sha256((project/'scripts/system_map_view.gd').read_bytes()).hexdigest()==SYSTEM_INFORMATION_MAP_VIEW_SHA256['scripts/system_map_view.gd'],'Hyperdrive update changed system-map information/travel view'
    main=(project/'scripts/main.gd').read_text()
    for name,expected in HYPERDRIVE_PHYSICAL_MAIN_FUNCTION_SHA256.items():
        assert hashlib.sha256(source_function(main,name).encode()).hexdigest()==expected,'Hyperdrive update changed protected physical Main function '+name
    source={name:(project/'scripts'/f'{name}.gd').read_text() for name in (*HYPERDRIVE_MODULES,'navigation','galactic_map_model','galactic_map_view')}
    ready=source_function(main,'_ready');enable=source_function(main,'_enable_source_hyperdrive')
    assert re.search(r'if not automated:\s*\n\s*_enable_source_hyperdrive\(\)\s*\n\s*_load_game\(\)',ready),'Fresh normal startup must configure source hyperdrive before optional save restore'
    assert 'world.layout_mode!=World.FULL_LAYOUT' in enable and 'nav.configure_source(ship.ship_id,nav.current_id)' in enable and 'nav.sync_source_ship(ship)' in enable,'Missing explicit FULL source-hyperdrive startup gate'
    assert '_enable_source_hyperdrive()' in source_function(main,'_confirm_new_game'),'New Game omits source hyperdrive'
    routes=source_function(main,'_show_routes')
    assert 'nav.map_profile(ship)' in routes and 'map_state.source_hyperdrive_profile=' in routes,'Galactic map lost its source hyperdrive profile'
    assert 'SourceNavigation.source_map_quote(' in source_function(source['galactic_map_model'],'jump_state'),'Galactic map lost source fuel/duration quote consumer'
    assert 'model.jump_state()' in source_function(source['galactic_map_view'],'_confirm_jump'),'Map jump must use the displayed quote availability'
    assert 'nav.begin_jump(ship)' in source_function(main,'_start_jump'),'Main lost Navigation jump consumer'
    navigation=source['navigation']
    assert '"starfrontier-rebuild-navigation-v3"' in source_function(navigation,'snapshot') and '_hyperdrive.snapshot()' in source_function(navigation,'snapshot'),'Source inventory lacks versioned Navigation snapshot'
    assert '_restore_source(data)' in source_function(navigation,'restore') and 'starfrontier-rebuild-navigation-v1' in source_function(navigation,'restore') and 'starfrontier-rebuild-navigation-v2' in source_function(navigation,'restore'),'Source restore must retain explicit legacy branches'
    assert 'session.restore(data.source_hyperdrive)' in source_function(navigation,'_restore_source') and '_same_pending(expected,data.pending_source_quote)' in source_function(navigation,'_restore_source'),'Source restore lacks validated inventory/pending quote'
    assert 'pending_source_quote={}' in source_function(navigation,'cancel_jump') and '.commit(' not in source_function(navigation,'cancel_jump'),'Jump cancel must clear pending quote without fuel consumption'
    step=source_function(navigation,'_step_source')
    assert 'candidate.commit(' in step and 'duration_raw_u32)/65536.0' in step and '_same_pending(' in step,'Jump completion lost source quote/atomic fuel/duration consumer'
    assert 'candidate_nav.validate_source_ship(candidate_ship)' in source_function(main,'_decode_state'),'Save restore lost Flight/inventory validation'
    assert 'nav.sync_source_ship(ship)' in source_function(main,'_payload'),'Save snapshot lost Flight/cargo bridge'
    assert 'hyperdrive_services_view.command.connect(_hyperdrive_service_command)' in source_function(main,'_embed_hyperdrive_services') and 'nav.service(action,id,quantity,ship)' in source_function(main,'_hyperdrive_service_command'),'Workshop UI lacks live Navigation command consumer'
    assert 'command.emit(action,id,quantity)' in source_function(source['hyperdrive_services_view'],'_action') and '_editable()' in source_function(source['hyperdrive_services_view'],'_action'),'Workshop commands lack actual copied-state/docked UI gate'
    session=source['source_hyperdrive_session']
    assert 'Kernel.quote(' in source_function(session,'quote') and 'drive_mass(drive_index)' in source_function(session,'occupied'),'Session lost original quote/installed-mass capacity consumer'
    assert 'source_digest' in source_function(session,'restore') and 'candidate.valid()' in source_function(session,'restore'),'Inventory save lacks validated resource-bound atomic restore'
    for relative,expected in HYPERDRIVE_AUDITED_SOURCE_SHA256.items():
        assert hashlib.sha256((project/relative).read_bytes()).hexdigest()==expected,'Hyperdrive update differs from audited integration source '+relative
    return {'baseline_source_commit':HYPERDRIVE_BASELINE_SOURCE_COMMIT,'compiled_modules':modules,'compiled_module_count':3,
            'raw_resource_sha256':hashlib.sha256(raw).hexdigest(),'raw_json_count':1,'drive_count':15,'ship_specification_count':57,
            'new_session_profile_models':{'cobra':38,'eagle':24,'shuttle':15},'original_starting_loadout_subset':['cobra'],
            'explicit_fitting_adapters':['eagle','shuttle'],'protected_flight_source_data_count':len(protected),
            'protected_physical_Main_functions':len(HYPERDRIVE_PHYSICAL_MAIN_FUNCTION_SHA256),
            'unchanged_information_runtime_count':3,'unchanged_information_resource_count':2,'system_information_resources':information['tables'],
            'audited_local_source_sha256':HYPERDRIVE_AUDITED_SOURCE_SHA256,
            'source_f903_live_quote_consumers_checked':True,'source_f833_distance_consumer_checked':True,
            'legacy_v1_v2_saved_navigation_retained':True,'source_v3_inventory_and_pending_restore_checked':True,
            'native_reference':{'sha256':HYPERDRIVE_NATIVE_SHA256,'case_count':5453,'unsafe_case_count':11,'fresh_process_runs':3,'oracle_executed_by_apk_verifier':False},
            'pricing_policy':'basic-source-workshop-pricing-adapter-v1','original_outfitting_economy':False,
            'original_f908_arrival_pipeline':False,'original_misjump_pipeline':False,'jetfuel_or_star_scoop_integrated_by_this_block':False,
            'all57_ships_playable':False,'complete_original_hyperdrive_gameplay':False,'complete_original_physics':False,
            'compiled_source_correspondence_rebuilt_by_verifier':False,'physical_device_tested':False}


def _verify_fuel_payload(archive,project):
    """Retained code41 original data/module/native metadata controls."""
    hyper=_verify_hyperdrive_payload(archive,project)
    information=_verify_system_information_payload(archive,project)
    names=set(archive.namelist());modules={}
    for name in FUEL_MODULES:
        path='assets/scripts/'+name+'.gdc'
        assert path in names,'Missing fuel runtime module '+name
        raw=archive.read(path)
        assert len(raw)>64 and raw[:4]==b'GDSC','Invalid compiled fuel runtime '+name
        modules[name]={'runtime_sha256':hashlib.sha256(raw).hexdigest(),
                       'local_source_sha256':hashlib.sha256((project/'scripts'/f'{name}.gd').read_bytes()).hexdigest()}
    path='assets/data/ffe_fuel.json'
    assert path in names,'Missing fuel resource'
    raw=archive.read(path)
    assert raw==(project/'data/ffe_fuel.json').read_bytes(),'Fuel resource differs from local source'
    data=json.loads(raw)
    assert data.get('schema')==1 and data.get('source_sha256')==SOURCE_IMAGE_SHA256,'Wrong fuel executable provenance'
    assert data.get('source_assembly_sha256')==SOURCE_ASSEMBLY_SHA256 and data.get('source_commit')==SOURCE_ASSEMBLY_COMMIT,'Wrong fuel assembly provenance'
    assert data.get('immutable_hyperdrive_resource_sha256')==HYPERDRIVE_RESOURCE_SHA256,'Fuel update changed immutable hyperdrive digest'
    for label,expected in {'5111':'094f80502f208b354b4e91d1dff6777d0d893d47c05c31fba8177d3e5b214a57','6266':'6fd21579d4bf35590dee289b2a1cbe12f1bc4e0d10a9ee71d56efea80cac21cb'}.items():
        table=bytes.fromhex(data.get('tables_hex',{}).get(label,''))
        assert len(table)==60 and hashlib.sha256(table).hexdigest()==expected,'Changed original fuel table '+label
    variant=data.get('source_variants',{}).get('F929',{})
    assert variant.get('DOS_automatic_restore') is False and variant.get('DOS_exhaustion_cleared_offsets')==[188,192,196],'Fuel policy lost the canonical DOS three-axis variant'
    assert sorted(map(int,data.get('models',{})))==list(range(134,149)),'Incomplete original gas/star contact models'
    for key,row in data['models'].items():
        descriptor=bytes.fromhex(row['descriptor_hex']);vertices=bytes.fromhex(row['vertices_hex']);payload=bytes.fromhex(row['collision_payload_hex'])
        assert len(descriptor)==68 and len(vertices)==24 and len(payload)==8,'Incorrect original contact component bounds '+key
        for field in ['descriptor','vertices','collision_payload']:
            assert hashlib.sha256(bytes.fromhex(row[field+'_hex'])).hexdigest()==row[field+'_sha256'],'Changed original fuel contact component '+key+'/'+field
        assert row['mesh_zoom']==sum(struct.unpack_from('<II',descriptor,20)),'Changed original fuel contact scale '+key
        assert struct.unpack_from('<H',payload,4)[0]=={134:3,135:6,136:5}.get(int(key),9),'Changed original stellar terrain style '+key
    for key,expected in {'refueller':(14,1,2),'scoop':(29,6,0x100000),'atmospheric_shielding':(15,1,0x40000000)}.items():
        item=data.get('equipment',{}).get(key,{})
        assert tuple(item.get(k)for k in ['equipment_index','mass_tonnes_u32','equipment_mask_u32'])==expected,'Changed original fuel equipment '+key
    assert data['equipment']['scoop'].get('required_spec_word_offset')==4 and data['equipment']['scoop'].get('required_spec_mask_u16')==256,'Fuel scoop lost its original hull eligibility'
    assert hashlib.sha256(raw).hexdigest()==FUEL_RESOURCE_SHA256,'Fuel resource differs from frozen DOS extraction'
    references={}
    for name,expected in FUEL_NATIVE_REFERENCE.items():
        fixture_raw=(project/'tests/fixtures'/f'{name}.json').read_bytes();fixture=json.loads(fixture_raw)
        assert hashlib.sha256(fixture_raw).hexdigest()==expected['sha256'],'Changed fuel native reference '+name
        assert fixture.get('schema')==1 and fixture.get('source_assembly_sha256',fixture.get('asm_sha256'))==SOURCE_ASSEMBLY_SHA256,'Wrong fuel native assembly provenance '+name
        assert fixture.get('case_count')==len(fixture.get('cases',[]))==expected['case_count'] and fixture.get('fresh_process_runs')==3 and fixture.get('canaries_unchanged') is True,'Incomplete fuel native reproduction '+name
        references[name]={'sha256':expected['sha256'],'case_count':expected['case_count'],'fresh_process_runs':3,'oracle_executed_by_apk_verifier':False}
        if name=='source_jet_fuel_native':
            assert fixture.get('source_sha256')==SOURCE_IMAGE_SHA256 and fixture.get('source_variant')=='dos-firstenc-f929-f938-f289-v1','Wrong canonical DOS jet native provenance'
            for label in ['5111','6266']:assert fixture['tables'][label]['hex']==data['tables_hex'][label],'Jet native table differs from runtime '+label
            for label in ['289','929','938']:
                proof=fixture['dos_instruction_proof'][label];original=data['dos_code_blocks'][label]
                assert proof['sha256']==original['sha256'] and proof['executable_offset']==original['dos_file_offset'] and proof['byte_length']==original['byte_count'] and proof['all_instructions_equal_after_only_branch_destination_normalization'] is True,'Jet native instructions differ from uploaded DOS '+label
            counterfactual=fixture.get('jjffe_counterfactual',{})
            assert counterfactual.get('not_canonical_dos') is True and counterfactual.get('difference_count',0)>0,'Missing explicit DOS/JJFFE jet divergence proof'
        elif name=='source_fuel_scoop_native':
            assert fixture.get('source_contract')=='jjffe-f1033-after-f569-fuel-scoop-v1' and fixture.get('reverse_order_unchanged') is True,'Wrong scoop native contract/reproduction'
        else:
            assert fixture.get('source_sha256')==SOURCE_IMAGE_SHA256 and fixture.get('models')==list(range(134,149)) and fixture.get('reverse_repeat_count')==expected['case_count'] and fixture.get('parent_bank_unchanged') is True,'Incomplete original gas/star contact reference'
    return {'hyper':hyper,'information':information,'modules':modules,'raw':raw,'data':data,'references':references}

def verify_fuel_runtime(archive,project):
    """Code41 fuel input/consumer gate, separate from instruction/GPU tests."""
    payload=_verify_fuel_payload(archive,project)
    hyper,information,modules,raw,data,references=(payload[key]for key in ['hyper','information','modules','raw','data','references'])
    protected={path:value for path,value in MAP_VISUAL_PROTECTED_SOURCE_SHA256.items()
               if path not in ('scripts/main.gd','scripts/system_map_view.gd','scripts/navigation.gd','scripts/galactic_map_model.gd',
                               'scripts/flight_model.gd','scripts/surface_model.gd','scripts/source_motion_bridge.gd')}
    for relative,expected in {**protected,**HYPERDRIVE_INFORMATION_SOURCE_SHA256,**FUEL_CONTACT_DEPENDENCY_SHA256}.items():
        assert hashlib.sha256((project/relative).read_bytes()).hexdigest()==expected,'Fuel update changed protected source/data '+relative
    assert hashlib.sha256((project/'scripts/celestial_renderer.gd').read_bytes()).hexdigest()==SYSTEM_INFORMATION_CELESTIAL_SHA256,'Fuel update changed Mercury stellar visibility'
    assert hashlib.sha256((project/'scripts/system_map_view.gd').read_bytes()).hexdigest()==SYSTEM_INFORMATION_MAP_VIEW_SHA256['scripts/system_map_view.gd'],'Fuel update changed system-map travel/information'
    main=(project/'scripts/main.gd').read_text()
    for name,expected in FUEL_UNCHANGED_MAIN_FUNCTION_SHA256.items():
        assert hashlib.sha256(source_function(main,name).encode()).hexdigest()==expected,'Fuel update changed undeclared physical Main function '+name
    source={name:(project/'scripts'/f'{name}.gd').read_text() for name in (*FUEL_MODULES,*HYPERDRIVE_MODULES,'navigation','flight_model','surface_model','source_motion_bridge','galactic_map_model')}
    jet=source['source_jet_fuel'];session=source['source_hyperdrive_session'];navigation=source['navigation']
    assert 'uploaded-dos-f929-three-positive-limits-no-automatic-restore' in jet,'Live jet kernel uses the wrong F929 variant'
    assert 'tables_hex' in source_function(jet,'_load') and '5111' in source_function(jet,'jet_capacity_raw'),'Manual refill lost its original tank-capacity consumer'
    assert 'state.thrust_u16=state.cached_thrust_u16.duplicate()' in source_function(jet,'manual_refuel'),'Manual refill lost its original thrust-limit restoration'
    tick=source_function(main,'_tick')
    assert '_apply_source_fuel_state()' in tick and '_step_source_fuel(dt,fuel_commands)' in tick,'Main fuel debit is not consumed by the live physics step'
    debit=source_function(main,'_step_source_fuel')
    assert 'fuel_contact.sample(world,ship,nav.elapsed_days)' in debit and 'FuelContact.new()' in main and 'nav.advance_fuel_seconds(seconds,context,ship)' in debit,'Live fuel step lost original contact/session consumers'
    assert 'destruction_requested' in debit and 'ship.hull=0' in debit,'Stellar thermal destruction is not consumed by Main'
    runtime_command=source_function(main,'_fuel_runtime_command')
    assert 'nav.manual_jet_refuel(ship)' in runtime_command and 'nav.set_refueller_enabled(enabled,ship)' in runtime_command,'Manual refill/refueller controls lack Main consumers'
    assert 'runtime_command.connect(_fuel_runtime_command)' in source_function(main,'_embed_hyperdrive_services'),'Fuel UI commands are not connected to Main'
    assert 'runtime_command.emit(' in source['hyperdrive_services_view'],'Fuel workshop lost its actual runtime signal'
    assert 'apply_fuel_availability' in source_function(main,'_decode_state') and '_apply_source_fuel_state()' in source_function(main,'_commit_state'),'Restored fuel flags must derive Flight propulsion state'
    assert 'nav.apply_fuel_availability(ship)' in source_function(main,'_apply_source_fuel_state'),'Source fuel state is not consumed by Flight'
    assert 'propulsion_available' in source_function(source['flight_model'],'acceleration') and 'source_thrust_limits_u16' in source['source_motion_bridge'],'Fuel exhaustion lost its phone/raw propulsion consumers'
    assert 'propulsion_available' in source['surface_model'],'Surface propulsion must respect empty jet fuel'
    assert '"propulsion_available"' not in source_function(source['flight_model'],'snapshot'),'Derived propulsion flags must not become trusted Flight save fields'
    assert 'fuel_system' in source_function(session,'snapshot') and '_valid_fuel()' in source_function(session,'valid'),'Fuel inventory lacks validated snapshot state'
    assert '_fuel_digest()' in source_function(session,'_valid_fuel') and '_fraction(' in source_function(session,'_valid_fuel'),'Fuel restore lacks resource/clock-fraction validation'
    assert 'Jet.manual_refuel(' in source_function(session,'manual_jet_refuel') and 'Jet.jet_capacity_raw(' in source_function(session,'manual_jet_refuel'),'Manual refill lost original F289/capacity calculation'
    fuel_step=source_function(session,'_step_fuel')
    assert 'Jet.fuel_step(' in fuel_step and 'Scoop.evaluate(' in fuel_step,'Session lost its jet debit or scoop source kernel'
    assert 'PLAYER_UPDATE_TICKS' in source_function(session,'advance_fuel_ticks') and 'ticks_fraction_f64_hex' in source_function(session,'advance_fuel_seconds'),'Jet maintenance lost its explicit calendar-second/fraction schedule'
    assert 'starter_shielding_credit()' in source_function(session,'occupied'),'Eagle baseline shielding cannot be double-counted as new equipment'
    assert 'candidate.fuel_system.jet_raw_u32=0' in source_function(session,'service'),'Drive removal lost its F410 jet-empty side effect'
    assert 'source_map_quote(' in source_function(source['galactic_map_model'],'jump_state'),'Map lost the retained source hyperdrive quote'
    assert 'session.hyperdrive_snapshot()' in source_function(navigation,'_pending_for'),'Pending hyperdrive quote must exclude unrelated jet clock ticks'
    assert 'legacy_pending' in source_function(navigation,'_restore_source') and 'fuel_extension_upgraded' in source_function(navigation,'_restore_source'),'Previous v3 pending/fuel initialization path is missing'
    for relative,expected in FUEL_AUDITED_SOURCE_SHA256.items():
        assert hashlib.sha256((project/relative).read_bytes()).hexdigest()==expected,'Fuel update differs from audited integration source '+relative
    return {'baseline_source_commit':FUEL_BASELINE_SOURCE_COMMIT,'compiled_modules':modules,'compiled_module_count':4,
        'raw_resource_sha256':hashlib.sha256(raw).hexdigest(),'raw_json_count':1,'contact_model_count':15,'fuel_equipment_records':len(data['equipment']),
        'audited_local_source_sha256':FUEL_AUDITED_SOURCE_SHA256,'protected_old_source_data_count':len(protected),
        'protected_contact_dependency_count':len(FUEL_CONTACT_DEPENDENCY_SHA256),'unchanged_Main_function_count':len(FUEL_UNCHANGED_MAIN_FUNCTION_SHA256),
        'unchanged_hyperdrive_resource_sha256':HYPERDRIVE_RESOURCE_SHA256,'retained_hyperdrive_compiled_module_count':len(hyper['modules']),
        'unchanged_information_resources':information['tables'],'unchanged_information_runtime_count':3,
        'native_references':references,'canonical_jet_variant':'uploaded-DOS-three-positive-limits-no-automatic-restore',
        'manual_refill':'F289 cargo-to-jet, not direct station tank filling','source_scoop_kernel':'F1033 after supplied contact',
        'gas_star_contact':'F574/F581/F1876 with exact source models and read-only model84 probe; current SI/world frame adapter',
        'cadence_policy':'nominal-day SI clock, F152 integer49710 calendar-second updates, explicit caller cooldown decrement',
        'phone_powered_impulse_to_f938_commands_is_adapter':True,'full_F938_shield_damage_loop_integrated':False,
        'full_F569_player_collision_integrated':False,'full_F1014_atmospheric_heat_integrated':False,
        'original_F908_arrival_pipeline':False,'original_outfitting_economy':False,'complete_original_time_scheduler':False,
        'complete_original_physics':False,'compiled_source_correspondence_rebuilt_by_verifier':False,'physical_device_tested':False}



def _verify_atmosphere_payload(archive,project):
    """Retained code42 immutable data/modules/native metadata, no source upgrade."""
    retained=_verify_fuel_payload(archive,project)
    names=set(archive.namelist());modules={}
    for name in ATMOSPHERE_MODULES:
        path='assets/scripts/'+name+'.gdc'
        assert path in names,'Missing atmospheric runtime module '+name
        compiled=archive.read(path)
        assert len(compiled)>64 and compiled[:4]==b'GDSC','Invalid compiled atmospheric runtime '+name
        modules[name]={'runtime_sha256':hashlib.sha256(compiled).hexdigest(),
                      'local_source_sha256':hashlib.sha256((project/'scripts'/f'{name}.gd').read_bytes()).hexdigest()}
    integration_modules={}
    for relative in ATMOSPHERE_AUDITED_SOURCE_SHA256:
        name=Path(relative).stem;path='assets/scripts/'+name+'.gdc'
        assert path in names,'Missing atmospheric integration runtime '+name
        compiled=archive.read(path)
        assert len(compiled)>64 and compiled[:4]==b'GDSC','Invalid compiled atmospheric integration runtime '+name
        integration_modules[name]=hashlib.sha256(compiled).hexdigest()
    path='assets/data/ffe_atmosphere.json'
    assert path in names,'Missing atmosphere resource'
    raw=archive.read(path)
    assert raw==(project/'data/ffe_atmosphere.json').read_bytes(),'Atmosphere resource differs from local source'
    data=json.loads(raw)
    assert data.get('schema')==1 and data.get('profile')=='dos-firstenc-atmosphere-damage-anchors-v1','Wrong atmosphere extraction profile'
    assert data.get('source_sha256')==SOURCE_IMAGE_SHA256 and data.get('source_assembly_sha256')==SOURCE_ASSEMBLY_SHA256 and data.get('source_commit')==SOURCE_ASSEMBLY_COMMIT,'Wrong atmosphere source provenance'
    assert data.get('immutable_resources')=={'ffe_hyperdrive_sha256':HYPERDRIVE_RESOURCE_SHA256,'ffe_fuel_sha256':FUEL_RESOURCE_SHA256},'Atmosphere extension changed retained resource digests'
    assert set(data.get('procedures',{}))==set(ATMOSPHERE_DOS_PROCEDURES),'Incomplete atmosphere DOS anchors'
    for label,expected in ATMOSPHERE_DOS_PROCEDURES.items():
        row=data['procedures'][label];original=bytes.fromhex(row.get('hex',''))
        assert all(row.get(key)==value for key,value in expected.items()),'Changed atmosphere DOS anchor '+label
        assert len(original)==expected['byte_count'] and hashlib.sha256(original).hexdigest()==expected['sha256'],'Changed atmosphere DOS bytes '+label
        assert row.get('pinned_jjffe_instructions_match_dos')==(label!='1014'),'Lost explicit atmospheric DOS/JJFFE distinction '+label
    variants=data.get('source_variants',{});dos=variants.get('F1014_DOS',{});jjffe=variants.get('F1014_pinned_JJFFE',{})
    assert dos.get('heat_per_invocation') is True and dos.get('heat_shifts')==[5,11] and dos.get('uses_gear_adjustment') is True and dos.get('incremental_F953_damage') is True and dos.get('heat_step_multiplication') is False and dos.get('drag_cap_u32')==0xfffff,'Atmosphere lost canonical DOS heat/drag policy'
    assert jjffe.get('heat_shifts')==[19,22] and jjffe.get('heat_step_multiplication') is True and jjffe.get('drag_cap_signed_s32')==0xffff,'Atmosphere lost explicit JJFFE counterfactual'
    policies=data.get('caller_policies',{})
    assert policies.get('phone_invocation_rate_hz')==60 and policies.get('phone_rate_is_original') is False and policies.get('canonical_original_player_call_rate_inferred') is False,'Phone thermal cadence must remain an explicit adapter'
    assert 'fuel_system.heat_s32' in policies.get('existing_heat_state','') and data.get('field_layout',{}).get('game',{}).get('heat_s32')==0x1ec,'Atmosphere must share the original single heat state'
    assert data.get('constants',{}).get('drag_max_master_ticks_u32')==0xfffff and data['constants'].get('hull_raw_per_mass_tonne')==4,'Wrong atmospheric unsigned drag cap or raw HP scale'
    for id,index,mass,hull in [('cobra',38,100,400),('eagle',24,28,112),('shuttle',15,8,32)]:
        row=data.get('ship_profiles',{}).get(id,{})
        assert (row.get('source_model_index'),row.get('hull_mass_tonnes_s16'),row.get('maximum_hull_raw_u16'))==(index,mass,hull),'Changed source atmospheric hull profile '+id
        spec=bytes.fromhex(row.get('spec_hex',''))
        assert len(spec)==24 and spec.hex()==retained['hyper']['data']['ship_specs'][str(index)]['spec_hex'] and hashlib.sha256(spec).hexdigest()==row.get('spec_sha256'),'Atmospheric hull differs from original specification '+id
    assert hashlib.sha256(raw).hexdigest()==ATMOSPHERE_RESOURCE_SHA256,'Atmosphere resource differs from frozen DOS extraction'
    references={}
    for name,expected in ATMOSPHERE_NATIVE_REFERENCE.items():
        fixture_raw=(project/'tests/fixtures'/f'{name}.json').read_bytes();fixture=json.loads(fixture_raw)
        assert hashlib.sha256(fixture_raw).hexdigest()==expected['sha256'],'Changed atmospheric native reference '+name
        assert fixture.get('case_count')==len(fixture.get('cases',[]))==expected['case_count'],'Incomplete atmospheric native cases '+name
        if name=='source_atmospheric_native':
            assert fixture.get('schema_version')==1 and fixture.get('executable_sha256')==SOURCE_IMAGE_SHA256 and fixture.get('pinned_asm_sha256')==SOURCE_ASSEMBLY_SHA256 and fixture.get('source_commit')==SOURCE_ASSEMBLY_COMMIT,'Wrong atmospheric DOS native provenance'
            checks=fixture.get('execution_checks',{})
            assert checks.get('fresh_identical_processes')==3 and checks.get('reverse_case_order_identical') is True and checks.get('object_globals_output_canaries') is True and checks.get('unrelated_object_bytes_unchanged') is True and checks.get('expected_arithmetic_computed_by_python') is False,'Incomplete atmospheric native reproduction'
            assert set(fixture.get('byte_instruction_proofs',{}))==set(ATMOSPHERE_DOS_PROCEDURES),'Incomplete atmospheric instruction proof'
            for label,original in ATMOSPHERE_DOS_PROCEDURES.items():
                proof=fixture['byte_instruction_proofs'][label]
                assert (proof.get('executable_offset'),proof.get('byte_length'),proof.get('sha256'),proof.get('instruction_count'))==(original['dos_file_offset'],original['byte_count'],original['sha256'],original['independently_normalized_instruction_count']) and proof.get('all_instructions_equal_after_only_branch_destination_normalization') is True,'Atmospheric native instructions differ from DOS '+label
            variant='uploaded-DOS-F1014-F953-F1530-with-observed-external-callbacks'
        else:
            assert fixture.get('schema')==1 and fixture.get('asm_sha256')==SOURCE_ASSEMBLY_SHA256 and fixture.get('source_contract')=='pinned-jjffe-f1099-f1475-f1466-speed-v1' and fixture.get('whole_DOS_binary_equivalence') is False,'Speed fixture must retain its pinned-JJFFE-only evidence scope'
            assert fixture.get('fresh_process_runs')==3 and fixture.get('reverse_repeat_count')==expected['case_count'],'Incomplete speed native reproduction'
            variant='pinned-JJFFE-speed-fragment-host-ABI-not-whole-DOS-equivalence'
        references[name]={'sha256':expected['sha256'],'case_count':expected['case_count'],'source_variant':variant,'oracle_executed_by_apk_verifier':False}
    return {'retained':retained,'modules':modules,'integration_modules':integration_modules,'raw':raw,'data':data,'references':references}

def verify_atmosphere_runtime(archive,project):
    """Code42 package/source wiring evidence; does not execute/decompile GDSC."""
    payload=_verify_atmosphere_payload(archive,project)
    retained,modules,integration_modules,raw,data,references=(payload[key]for key in ['retained','modules','integration_modules','raw','data','references'])
    protected={path:value for path,value in MAP_VISUAL_PROTECTED_SOURCE_SHA256.items()
               if path not in ('scripts/main.gd','scripts/system_map_view.gd','scripts/navigation.gd','scripts/galactic_map_model.gd',
                               'scripts/flight_model.gd','scripts/surface_model.gd','scripts/source_motion_bridge.gd','scripts/flight_time_controller.gd')}
    for relative,expected in {**protected,**HYPERDRIVE_INFORMATION_SOURCE_SHA256,**FUEL_CONTACT_DEPENDENCY_SHA256}.items():
        assert hashlib.sha256((project/relative).read_bytes()).hexdigest()==expected,'Atmosphere update changed protected source/data '+relative
    assert hashlib.sha256((project/'scripts/celestial_renderer.gd').read_bytes()).hexdigest()==SYSTEM_INFORMATION_CELESTIAL_SHA256,'Atmosphere update changed Mercury stellar visibility'
    assert hashlib.sha256((project/'scripts/system_map_view.gd').read_bytes()).hexdigest()==SYSTEM_INFORMATION_MAP_VIEW_SHA256['scripts/system_map_view.gd'],'Atmosphere update changed system-map travel/information'
    main=(project/'scripts/main.gd').read_text()
    unchanged={name:value for name,value in FUEL_UNCHANGED_MAIN_FUNCTION_SHA256.items()if name not in ('_new_models','_time_context')}
    for name,expected in unchanged.items():
        assert hashlib.sha256(source_function(main,name).encode()).hexdigest()==expected,'Atmosphere update changed undeclared physical Main function '+name
    source={name:(project/'scripts'/f'{name}.gd').read_text() for name in (*ATMOSPHERE_MODULES,*FUEL_MODULES,*HYPERDRIVE_MODULES,'navigation','source_motion_bridge','flight_time_controller','galactic_map_model')}
    session=source['source_hyperdrive_session'];navigation=source['navigation'];bridge=source['source_motion_bridge'];contact=source['source_atmosphere_contact'];core=source['source_atmospheric_dynamics']
    tick=source_function(main,'_tick');step=source_function(main,'_step_source_fuel')
    assert '_step_source_fuel(dt,fuel_commands)' in tick and tick.index('_step_source_fuel(dt,fuel_commands)')<tick.index('if save_after_fuel:_save_game()'),'Atmospheric/fuel state must advance before arrival autosave'
    assert 'AtmosphereContact.new()' in main and 'atmosphere_contact.sample(world,ship,surface,nav.elapsed_days)' in step and 'context["thermal"]=' in step and 'nav.advance_fuel_seconds(seconds,context,ship)' in step,'Live thermal step lost actual contact/combined session consumers'
    assert 'source_motion.apply_velocity_words(after,ship)' in step and 'ship.velocity+=Basis(context.velocity_to_phone_basis)*delta' in step,'Atmospheric drag has no raw/SI velocity consumer'
    assert '_source_ship_destroyed(' in step and 'destruction_requested' in step and 'ship.hull=0' in source_function(main,'_source_ship_destroyed'),'Atmospheric destruction has no Main consumer'
    assert 'nav.bind_thermal_ship(ship)' in source_function(main,'_apply_source_fuel_state') and 'candidate_nav.bind_thermal_ship(candidate_ship)' in source_function(main,'_decode_state'),'Restored thermal HP must bind strictly without repair'
    assert 'source_motion.velocity_words()' in step and 'AtmosphereContact.raw_speed_words(context.velocity_s32)' in step,'Active raw motion speed must consume source velocity words'
    assert 'source_fuel_contact.gd' in contact and 'source_ground_surface.gd' in contact and 'source_terrain_point.gd' in contact and '_natural.height_raw(' in source_function(contact,'query_raw') and 'query_raw(' in source_function(contact,'sample'),'Atmosphere contact lost original solid/gas geometry consumers'
    assert 'altitude_s32' in source_function(contact,'sample') and '0x7fffffff' in source_function(session,'_thermal_context'),'Unknown source altitude must not become below-ground heat'
    thermal=source_function(session,'_thermal_step_inplace');context=source_function(session,'_thermal_context')
    assert '"heat_s32":int(fuel_system.heat_s32)' in context and 'fuel_system.heat_s32=int(atmosphere.state.heat_s32)' in thermal and 'Thermal.atmosphere(' in thermal,'Thermal integration disconnected the single source heat state'
    match=re.search(r'^const THERMAL_KEYS:=([^\n]+)',session,re.M)
    assert match and 'heat_s32' not in match.group(1),'Thermal save must not introduce a duplicate heat state'
    assert 'Thermal.damage(' in source_function(session,'_apply_damage_call') and '_apply_damage_call(callback)' in thermal,'Atmospheric F953 requests are not consumed by raw HP arithmetic'
    fixed=source_function(session,'_fixed_thermal_seconds')
    assert 'const THERMAL_HZ:=60' in session and 'dt*THERMAL_HZ+_fraction(thermal_system.phase_f64_hex)' in fixed and 'candidate.advance_fuel_ticks(ticks,fuel_context)' in fixed and 'candidate._thermal_step_inplace(thermal_context)' in fixed,'Combined fuel/thermal fixed-host schedule is disconnected'
    assert '_fixed_thermal_seconds(dt,context,true)' in source_function(session,'advance_fuel_seconds'),'Ordinary source fuel step bypasses thermal schedule'
    valid=source_function(session,'_valid_thermal')
    assert 'thermal_system.source_digest!=_thermal_digest()' in valid and '_fraction(thermal_system.phase_f64_hex)' in valid and '_fraction(thermal_system.tick_fraction_anchor_f64_hex)' in valid,'Thermal restore lacks resource/fraction validation'
    assert 'rng_seed_a_u32' in valid and 'rng_seed_b_u32' in valid and 'thermal_system.hull_u16' in valid and 'full_hull_raw()*anchor/100.0' in valid,'Thermal restore lacks raw HP/RNG validation'
    assert 'candidate._valid_thermal()' in source_function(session,'restore') and 'result.thermal_system=thermal_system.duplicate(true)' in source_function(session,'snapshot'),'Thermal state lacks validated round-trip persistence'
    assert 'not thermal_system.is_empty():return thermal_hull_matches(percent)' in source_function(session,'bind_thermal_hull'),'Ordinary restore binding may silently repair raw HP'
    assert 'ship.hull=candidate.thermal_hull_percent()' in source_function(navigation,'_commit_fuel_result'),'F953 raw hull changes are not consumed by Flight'
    assert 'thermal_system.rng_seed_a_u32=int(result.rng_state.seed_a_u32)' in source_function(session,'_apply_damage_call'),'Thermal RNG continuation is not persisted'
    velocity=source_function(bridge,'apply_velocity_words')
    assert velocity.count('body.encode_s32(')==1 and 'body.encode_s32(0x8c+axis*4,int(words[axis]))' in velocity and 'encode_u16' not in velocity and 'encode_s64' not in velocity,'Atmospheric raw drag must preserve Q16 velocity fractions and position'
    hazard=source_function(main,'_time_context');limit=source_function(source['flight_time_controller'],'safety_limit')
    assert 'result.atmospheric_hazard=' in hazard and 'nav.thermal_state(ship)' in hazard and 'atmospheric_hazard' in limit and '"rate":1' in limit,'Atmospheric time acceleration safety is disconnected'
    assert 'nav.thermal_state(ship)' in step and '_announce(fuel_notice.strip_edges())' in step and '_render_thermal()' in source_function(source['hyperdrive_services_view'],'_render'),'Thermal state has no actual flight-notice/workshop consumers'
    # Retain original source fuel/hyperdrive wiring as well as the new thermal branch.
    assert 'Jet.fuel_step(' in source_function(session,'_step_fuel') and 'Scoop.evaluate(' in source_function(session,'_step_fuel'),'Atmospheric extension disconnected retained jet/scoop kernels'
    assert 'candidate.fuel_system.jet_raw_u32=0' in source_function(session,'service'),'Drive removal lost its F410 empty-tank side effect'
    assert 'session.hyperdrive_snapshot()' in source_function(navigation,'_pending_for') and 'source_map_quote(' in source_function(source['galactic_map_model'],'jump_state'),'Atmospheric extension disconnected source hyperdrive quotes'
    for relative,expected in ATMOSPHERE_AUDITED_SOURCE_SHA256.items():
        assert hashlib.sha256((project/relative).read_bytes()).hexdigest()==expected,'Atmosphere update differs from audited integration source '+relative
    return {'baseline_source_commit':ATMOSPHERE_BASELINE_SOURCE_COMMIT,'compiled_modules':modules,'compiled_module_count':2,
        'raw_resource_sha256':hashlib.sha256(raw).hexdigest(),'raw_json_count':1,'original_procedure_count':8,
        'integration_compiled_modules':integration_modules,'integration_compiled_module_count':len(integration_modules),
        'original_procedure_bytes':sum(row['byte_count']for row in ATMOSPHERE_DOS_PROCEDURES.values()),
        'audited_local_source_sha256':ATMOSPHERE_AUDITED_SOURCE_SHA256,'protected_old_source_data_count':len(protected),
        'protected_contact_dependency_count':len(FUEL_CONTACT_DEPENDENCY_SHA256),'unchanged_Main_function_count':len(unchanged),
        'retained_fuel_compiled_module_count':len(retained['modules']),'unchanged_fuel_resource_sha256':FUEL_RESOURCE_SHA256,
        'retained_fuel_native_references':retained['references'],'unchanged_hyperdrive_resource_sha256':HYPERDRIVE_RESOURCE_SHA256,
        'retained_hyperdrive_compiled_module_count':len(retained['hyper']['modules']),
        'unchanged_information_resources':retained['information']['tables'],'unchanged_information_runtime_count':3,
        'native_references':references,'canonical_atmosphere_variant':'uploaded-DOS-F1014-per-invocation-gear-shield-heat-unsigned-drag-cap-0xFFFFF',
        'shared_single_heat_state':True,'raw_HP_and_local_thermal_RNG_persisted':True,'actual_contact_and_drag_consumers_checked':True,
        'phone_invocation_rate_hz':60,'phone_rate_is_original':False,'full_original_reference_frame_pipeline':False,
        'full_original_global_event_rng_stream':False,'full_original_equipment_damage_dispatcher':False,
        'full_original_destruction_dispatcher':False,'full_F569_player_collision_integrated':False,
        'original_F908_arrival_pipeline':False,'original_outfitting_economy':False,'complete_original_time_scheduler':False,
        'complete_original_physics':False,'compiled_source_correspondence_rebuilt_by_verifier':False,'physical_device_tested':False}


def _verify_landing_gear_payload(archive,project):
    """Retained code43 immutable gear/older data, modules and native metadata."""
    atmosphere=_verify_atmosphere_payload(archive,project)
    names=set(archive.namelist());modules={};integration_modules={}
    for relative in LANDING_GEAR_AUDITED_SOURCE_SHA256:
        name=Path(relative).stem;path='assets/scripts/'+name+'.gdc'
        assert path in names,'Missing landing-gear integration runtime '+name
        compiled=archive.read(path)
        assert len(compiled)>64 and compiled[:4]==b'GDSC','Invalid compiled landing-gear integration runtime '+name
        integration_modules[name]=hashlib.sha256(compiled).hexdigest()
        if name in LANDING_GEAR_MODULES:modules[name]={'runtime_sha256':integration_modules[name],'local_source_sha256':hashlib.sha256((project/relative).read_bytes()).hexdigest()}
    path='assets/data/ffe_landing_gear.json'
    assert path in names,'Missing landing-gear resource'
    raw=archive.read(path)
    assert raw==(project/'data/ffe_landing_gear.json').read_bytes(),'Landing-gear resource differs from local source'
    data=json.loads(raw)
    assert data.get('schema')==1 and data.get('profile')=='dos-firstenc-f1008-f1056-landing-gear-anchors-v1','Wrong landing-gear extraction profile'
    assert data.get('source_sha256')==SOURCE_IMAGE_SHA256 and data.get('source_assembly_sha256')==SOURCE_ASSEMBLY_SHA256 and data.get('source_commit')==SOURCE_ASSEMBLY_COMMIT,'Wrong landing-gear source provenance'
    assert data.get('immutable_resources')=={'ffe_hyperdrive_sha256':HYPERDRIVE_RESOURCE_SHA256,'ffe_fuel_sha256':FUEL_RESOURCE_SHA256,'ffe_atmosphere_sha256':ATMOSPHERE_RESOURCE_SHA256},'Landing-gear extension changed retained resource digests'
    for section,expected_rows in [('procedures',LANDING_GEAR_DOS_ANCHORS),('supporting_slices',LANDING_GEAR_SUPPORTING_ANCHORS)]:
        assert set(data.get(section,{}))==set(expected_rows),'Incomplete landing-gear '+section
        for label,expected in expected_rows.items():
            row=data[section][label];original=bytes.fromhex(row.get('hex',''))
            assert all(row.get(key)==value for key,value in expected.items()),'Changed landing-gear DOS anchor '+label
            assert len(original)==expected['byte_count'] and hashlib.sha256(original).hexdigest()==expected['sha256'],'Changed landing-gear DOS bytes '+label
    constants=data.get('constants',{})
    assert tuple(constants.get(key)for key in ['request_retract_game_e9_mask_u8','position_fully_retracted_u16','position_fully_deployed_u16'])==(2,0,65535),'Landing-gear request/position polarity reversed'
    assert tuple(constants.get(key)for key in ['automatic_flight_state_u8','auto_retract_phase_maximum_u8','toggle_blocked_autopilot_phase_u8'])==(2,30,36),'Landing-gear automatic/toggle phases conflated'
    assert tuple(constants.get(key)for key in ['deployment_warning_speed_raw_s32','deployment_warning_message_u16','warning_selector_s32'])==(100000,0x98ce,-1),'Landing-gear original warning altered'
    assert constants.get('console_button_indices_u8')==[0x38,0x46] and constants.get('toggle_success_sound_u8')==0x0c and constants.get('toggle_final_sound_u8')==0x14,'Landing-gear original callbacks altered'
    fields=data.get('field_layout',{})
    assert fields.get('object',{}).get('unrelated_timer_u16')==0xe8 and fields.get('game',{}).get('flight_state_u8')==0xe8 and fields['object'].get('gear_position_u16')==0x9e,'Landing-gear object timer/flight state/position fields conflated'
    policy=data.get('caller_policies',{});variants=data.get('source_variants',{})
    assert policy.get('phone_invocation_rate_hz')==60 and policy.get('phone_rate_is_original') is False and policy.get('canonical_original_player_call_rate_inferred') is False,'Gear phone cadence must remain an explicit adapter'
    assert variants.get('covered_DOS_and_pinned_JJFFE_instructions_equal') is True and variants.get('whole_F1056_DOS_equivalence_proved') is False,'Gear branch must not claim full F1056 equivalence'
    assert hashlib.sha256(raw).hexdigest()==LANDING_GEAR_RESOURCE_SHA256,'Landing-gear resource differs from frozen DOS extraction'
    fixture_raw=(project/'tests/fixtures/source_landing_gear_native.json').read_bytes();fixture=json.loads(fixture_raw)
    assert hashlib.sha256(fixture_raw).hexdigest()==LANDING_GEAR_NATIVE_REFERENCE_SHA256,'Changed landing-gear native reference'
    assert fixture.get('schema_version')==1 and fixture.get('executable_sha256')==SOURCE_IMAGE_SHA256 and fixture.get('pinned_asm_sha256')==SOURCE_ASSEMBLY_SHA256 and fixture.get('source_commit')==SOURCE_ASSEMBLY_COMMIT,'Wrong gear DOS native provenance'
    assert fixture.get('case_count')==len(fixture.get('cases',[]))==2812,'Incomplete gear native cases'
    checks=fixture.get('execution_checks',{})
    assert checks.get('fresh_identical_processes')==3 and checks.get('reverse_case_order_identical') is True and checks.get('object_globals_output_canaries') is True and checks.get('unrelated_bytes_unchanged') is True and checks.get('expected_transitions_computed_by_python') is False,'Incomplete gear native reproduction'
    for label,native_key in [('1008','F1008'),('1056_4410','F1056_JUMP_004410')]:
        expected=LANDING_GEAR_DOS_ANCHORS[label];proof=fixture.get('byte_instruction_proofs',{}).get(native_key,{})
        assert (proof.get('executable_offset'),proof.get('byte_length'),proof.get('sha256'),proof.get('instruction_count'))==(expected['dos_file_offset'],expected['byte_count'],expected['sha256'],expected['independently_normalized_instruction_count']) and proof.get('all_instructions_equal_after_branch_destination_normalization') is True,'Gear native instructions differ from DOS '+label
    warning=fixture.get('warning_resource',{})
    assert warning.get('ff_code_u16')==0x98ce and warning.get('sha256')=='3bd5c30b6cb91dfa97d7e93cc471885f0ccc88ec50605c8c9cb8435429dd9644' and hashlib.sha256(bytes.fromhex(warning.get('hex',''))).hexdigest()==warning['sha256'],'Gear warning lost its original text provenance'
    return {'atmosphere':atmosphere,'modules':modules,'integration_modules':integration_modules,'raw':raw,'data':data,'fixture':fixture}

def verify_landing_gear_runtime(archive,project):
    """Code43 package/source wiring, separate from native/GPU/device evidence."""
    payload=_verify_landing_gear_payload(archive,project)
    atmosphere,modules,integration_modules,raw,data,fixture=(payload[key]for key in ['atmosphere','modules','integration_modules','raw','data','fixture'])
    protected={path:value for path,value in MAP_VISUAL_PROTECTED_SOURCE_SHA256.items()
               if path not in ('scripts/main.gd','scripts/system_map_view.gd','scripts/navigation.gd','scripts/galactic_map_model.gd',
                               'scripts/flight_model.gd','scripts/surface_model.gd','scripts/source_motion_bridge.gd','scripts/flight_time_controller.gd')}
    for relative,expected in {**protected,**HYPERDRIVE_INFORMATION_SOURCE_SHA256,**FUEL_CONTACT_DEPENDENCY_SHA256,**LANDING_GEAR_UNCHANGED_SOURCE_SHA256}.items():
        assert hashlib.sha256((project/relative).read_bytes()).hexdigest()==expected,'Landing-gear update changed protected source/data '+relative
    assert hashlib.sha256((project/'scripts/celestial_renderer.gd').read_bytes()).hexdigest()==SYSTEM_INFORMATION_CELESTIAL_SHA256,'Landing-gear update changed Mercury stellar visibility'
    assert hashlib.sha256((project/'scripts/system_map_view.gd').read_bytes()).hexdigest()==SYSTEM_INFORMATION_MAP_VIEW_SHA256['scripts/system_map_view.gd'],'Landing-gear update changed system-map travel/information'
    source={Path(name).stem:(project/name).read_text()for name in LANDING_GEAR_AUDITED_SOURCE_SHA256}
    main=source['main'];session=source['source_landing_gear_session'];surface=source['surface_model'];console=source['flight_console'];visual=source['ship_visual']
    unchanged={name:value for name,value in FUEL_UNCHANGED_MAIN_FUNCTION_SHA256.items()if name not in ('_new_models','_time_context','_apply_system','_toggle_auto','_dock_action')}
    for name,expected in unchanged.items():
        assert hashlib.sha256(source_function(main,name).encode()).hexdigest()==expected,'Landing-gear update changed undeclared physical Main function '+name
    for name,expected in LANDING_GEAR_UNCHANGED_SURFACE_FUNCTION_SHA256.items():
        assert hashlib.sha256(source_function(surface,name).encode()).hexdigest()==expected,'Landing-gear update changed undeclared physical Surface function '+name
    contact=source['source_atmosphere_contact']
    contact=contact.replace('# Historical argument/key gear_down is the raw E9 bit2 (SET=retract).\n# Physical extension belongs to the separately bound landing-gear session.\n','',1).replace('historical_raw_game_e9_bit2_default_clear_not_physical_down','explicit_caller_input_default_retracted',1)
    assert hashlib.sha256(contact.encode()).hexdigest()==ATMOSPHERE_AUDITED_SOURCE_SHA256['scripts/source_atmosphere_contact.gd'],'Gear contact description correction changed atmospheric geometry/math'
    tick=source_function(main,'_tick');thermal=source_function(main,'_step_source_fuel')
    assert '_step_landing_gear(dt)' in tick and tick.index('_step_landing_gear(dt)')<tick.index('_step_source_fuel(dt,fuel_commands)'),'Main must advance source gear before thermal fuel processing'
    assert '_step_source_fuel(dt,fuel_commands)' in tick and tick.index('_step_source_fuel(dt,fuel_commands)')<tick.index('if save_after_fuel:_save_game()'),'Gear/fuel must advance before arrival autosave'
    assert 'landing_gear=LandingGearSession.new()' in source_function(main,'_new_models') and 'landing_gear.configure(ship.docked or surface.landed)' in source_function(main,'_new_models'),'Fresh source games lack independent gear initialization'
    assert 'World.FULL_LAYOUT' in source_function(main,'_gear_enabled'),'Legacy worlds must not silently acquire source gear behavior'
    assert 'landing_gear.advance_seconds(seconds,_gear_context())' in source_function(main,'_step_landing_gear'),'Live gear animation lacks the source session consumer'
    assert 'flight_console.gear_requested.connect(_toggle_landing_gear)' in source_function(main,'_build_ui') and 'landing_gear.command_toggle(_gear_context())' in source_function(main,'_toggle_landing_gear'),'Console gear command lacks a Main/source toggle consumer'
    assert 'paused' in source_function(main,'_toggle_landing_gear') and 'context.get("paused",false)' in source_function(session,'command_toggle') and 'context.get("paused",false)' in source_function(session,'_advance_seconds'),'Paused gear input/animation must preserve state'
    assert 'atmosphere_contact.sample(world,ship,surface,nav.elapsed_days,bool(_gear_state().get("f1014_raw_gear_flag",false)))' in thermal and '"gear_down":bool(context.gear_down)' in thermal,'F1014 must consume the raw retract request bit, not physical deployed state'
    assert 'nav.advance_fuel_seconds(seconds,context,ship)' in thermal and 'source_motion.apply_velocity_words(after,ship)' in thermal and 'ship.velocity+=Basis(context.velocity_to_phone_basis)*delta' in thermal,'Gear extension disconnected retained thermal/fuel/raw/SI consumers'
    assert 'candidate_nav.bind_thermal_ship(candidate_ship)' in source_function(main,'_decode_state') and 'nav.bind_thermal_ship(ship)' in source_function(main,'_apply_source_fuel_state'),'Gear restore must retain strict raw thermal HP binding'
    persist=source_function(main,'_payload');decode=source_function(main,'_decode_state')
    assert 'result.gear_session=landing_gear.snapshot()' in persist and 'candidate_gear.restore(data.gear_session)' in decode and 'candidate_gear.configure(candidate_surface.landed or candidate_ship.docked)' in decode,'Independent gear state lacks strict restore and explicit previous-save initialization'
    assert 'candidate_surface.landed and (' in decode and 'restored_gear.get("deployed",false)' in decode and 'restored_gear.get("requested_down",false)' in decode and 'landing_gear=data.get("landing_gear")' in source_function(main,'_commit_state'),'Landed restore must validate and install physical gear position'
    assert 'data.source_digest!=_digest()' in source_function(session,'_valid') and '_phase(data.phase_f64_hex)' in source_function(session,'_valid') and 'frame_tick_remainder_raw' in source_function(session,'_valid'),'Gear restore lacks resource/fraction/remainder validation'
    assert 'const HZ:=60' in session and 'const TICK_DENOMINATOR:=86400*HZ' in session and 'Kernel.step(candidate._kernel_state(context),ticks)' in source_function(session,'_advance_seconds'),'Gear fixed-host rational ticks are disconnected'
    assert 'Kernel.toggle(_kernel_state(context))' in source_function(session,'command_toggle'),'Gear command bypasses original bounded F1056 branch'
    keys=re.search(r'^const KEYS:=([^\n]+)',session,re.M)
    assert keys and all(token not in keys.group(1)for token in ['heat_s32','jet_raw_u32','hydrogen','hull_u16']),'Independent gear save must not duplicate fuel/heat/cargo/raw HP'
    state=source_function(session,'state')
    assert 'position==Kernel.DEPLOYED_POSITION' in state and '"f1014_raw_gear_flag":retract' in state and '"landing_ready":deployed' in state,'Gear telemetry conflates physical position and raw request'
    apply=source_function(main,'_apply_landing_gear_state')
    assert 'surface.set_landing_gear_state(' in apply and 'current.get("deployed",true)' in apply and 'player.set_gear_fraction(' in apply and 'player.clear_gear_fraction_override()' in apply,'Gear position lacks actual surface/visual/legacy consumers'
    assert 'landing_gear_managed and not landing_gear_ready' in source_function(surface,'_gear_blocks_touchdown') and '_gear_blocks_touchdown()' in source_function(surface,'touch_down') and '_gear_blocks_touchdown()' in source_function(surface,'_clip_source_city'),'Actual touchdown paths ignore incomplete physical gear'
    assert surface.count('_hold_for_landing_gear(ship)')>=3 and 'landed and not _gear_blocks_touchdown()' in surface,'Terrain/city/underground contact lost gear readiness gating'
    assert 'landing_gear_managed' not in source_function(surface,'snapshot') and 'landing_gear_ready' not in source_function(surface,'snapshot'),'Derived surface gear readiness must not become a trusted duplicate save field'
    assert 'gear_requested.emit()' in source_function(console,'_action') and '_configure_gear()' in source_function(console,'configure_state') and 'buttons.gear.disabled=paused' in source_function(console,'_update_action_availability'),'Actual console gear button/disabled-state consumers are missing'
    assert '_source_gear_driven=true' in source_function(visual,'set_gear_fraction') and 'if not _source_gear_driven:' in source_function(visual,'_process'),'Visual gear must consume physical source fraction without a second animation clock'
    for relative,expected in LANDING_GEAR_AUDITED_SOURCE_SHA256.items():
        assert hashlib.sha256((project/relative).read_bytes()).hexdigest()==expected,'Landing-gear update differs from audited integration source '+relative
    return {'baseline_source_commit':LANDING_GEAR_BASELINE_SOURCE_COMMIT,'compiled_modules':modules,'compiled_module_count':2,
        'integration_compiled_modules':integration_modules,'integration_compiled_module_count':len(integration_modules),
        'raw_resource_sha256':hashlib.sha256(raw).hexdigest(),'raw_json_count':1,'original_primary_anchors':2,'original_primary_anchor_bytes':421,'original_primary_instruction_count':104,
        'supporting_anchor_slices':2,'supporting_anchor_bytes':53,'supporting_instruction_count':14,
        'audited_local_source_sha256':LANDING_GEAR_AUDITED_SOURCE_SHA256,'unchanged_code42_source_count':len(LANDING_GEAR_UNCHANGED_SOURCE_SHA256),
        'protected_old_source_data_count':len(protected),'protected_contact_dependency_count':len(FUEL_CONTACT_DEPENDENCY_SHA256),
        'unchanged_Main_function_count':len(unchanged),'unchanged_Surface_function_count':len(LANDING_GEAR_UNCHANGED_SURFACE_FUNCTION_SHA256),
        'unchanged_atmosphere_resource_sha256':ATMOSPHERE_RESOURCE_SHA256,'retained_atmosphere_compiled_module_count':len(atmosphere['modules']),
        'retained_atmosphere_native_references':atmosphere['references'],'unchanged_fuel_resource_sha256':FUEL_RESOURCE_SHA256,
        'retained_fuel_compiled_module_count':len(atmosphere['retained']['modules']),'retained_fuel_native_references':atmosphere['retained']['references'],
        'unchanged_hyperdrive_resource_sha256':HYPERDRIVE_RESOURCE_SHA256,'retained_hyperdrive_compiled_module_count':len(atmosphere['retained']['hyper']['modules']),
        'unchanged_information_resources':atmosphere['retained']['information']['tables'],'unchanged_information_runtime_count':3,
        'native_reference':{'sha256':LANDING_GEAR_NATIVE_REFERENCE_SHA256,'case_count':2812,'source_variant':'uploaded-DOS-complete-F1008-and-selected-F1056-gear-branch','oracle_executed_by_apk_verifier':False},
        'separate_gear_sibling_persisted':True,'actual_console_visual_touchdown_thermal_consumers_checked':True,
        'phone_invocation_rate_hz':60,'phone_rate_is_original':False,'whole_original_F1056_dispatcher':False,
        'full_original_player_scheduler':False,'full_original_autopilot_phase_mapping':False,'full_F575_contact_response':False,
        'full_original_GUI_audio_callbacks':False,'micrometeorite_damage_integrated_by_this_block':False,
        'complete_original_physics':False,'compiled_source_correspondence_rebuilt_by_verifier':False,'physical_device_tested':False}


def verify_surface_contact_runtime(archive,project):
    """Code44 strict source/asset controls, not full classifier or GDSC proof."""
    return _verify_surface_contact_runtime(archive,project)


def _verify_surface_contact_runtime(archive,project,normalized_main=None):
    """Retain every code44 check; code45 supplies only exact AD3-normalized Main."""
    gear=_verify_landing_gear_payload(archive,project);atmosphere=gear['atmosphere'];fuel=atmosphere['retained']
    names=set(archive.namelist());modules={};integration_modules={}
    for relative in SURFACE_CONTACT_AUDITED_SOURCE_SHA256:
        name=Path(relative).stem;path='assets/scripts/'+name+'.gdc'
        assert path in names,'Missing surface-contact integration runtime '+name
        compiled=archive.read(path)
        assert len(compiled)>64 and compiled[:4]==b'GDSC','Invalid compiled surface-contact integration runtime '+name
        integration_modules[name]=hashlib.sha256(compiled).hexdigest()
        if name in SURFACE_CONTACT_MODULES:modules[name]={'runtime_sha256':integration_modules[name],'local_source_sha256':hashlib.sha256((project/relative).read_bytes()).hexdigest()}
    path='assets/data/ffe_surface_contact.json'
    assert path in names,'Missing surface-contact provenance resource'
    raw=archive.read(path)
    assert raw==(project/'data/ffe_surface_contact.json').read_bytes(),'Surface-contact resource differs from local source'
    data=json.loads(raw)
    assert data.get('schema')==1 and data.get('profile')=='dos-firstenc-f575-postclassification-anchors-v1','Wrong surface-contact extraction profile'
    assert data.get('source_sha256')==SOURCE_IMAGE_SHA256 and data.get('source_assembly_sha256')==SOURCE_ASSEMBLY_SHA256 and data.get('source_commit')==SOURCE_ASSEMBLY_COMMIT and data.get('source_data_sha256')=='34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850','Wrong surface-contact source provenance'
    assert data.get('immutable_resources')=={'ffe_hyperdrive_sha256':HYPERDRIVE_RESOURCE_SHA256,'ffe_fuel_sha256':FUEL_RESOURCE_SHA256,'ffe_atmosphere_sha256':ATMOSPHERE_RESOURCE_SHA256,'ffe_landing_gear_sha256':LANDING_GEAR_RESOURCE_SHA256,'ffe_runtime_model_descriptors_sha256':SURFACE_CONTACT_RUNTIME_DESCRIPTOR_SHA256},'Contact extension changed retained resource digests'
    assert set(data.get('procedures',{}))==set(SURFACE_CONTACT_DOS_ANCHORS),'Incomplete bounded/static/excluded contact anchors'
    for label,expected in SURFACE_CONTACT_DOS_ANCHORS.items():
        row=data['procedures'][label];original=bytes.fromhex(row.get('hex',''))
        assert all(row.get(key)==value for key,value in expected.items()),'Changed contact DOS anchor '+label
        assert len(original)==expected['byte_count'] and hashlib.sha256(original).hexdigest()==expected['sha256'],'Changed contact DOS bytes '+label
        assert row.get('runtime_entry')==(label=='575_postclassification'),'Static/excluded contact anchor cannot be called runtime '+label
    assert data.get('helper_proof_complete') is True and set(data.get('instruction_proofs',{}))==set(SURFACE_CONTACT_INSTRUCTION_PROOFS),'Contact helper proof domain is incomplete'
    for label,expected in SURFACE_CONTACT_INSTRUCTION_PROOFS.items():
        row=data['instruction_proofs'][label];original=bytes.fromhex(row.get('hex',''))
        assert all(row.get(key)==value for key,value in expected.items()),'Changed contact instruction proof '+label
        assert len(original)==expected['byte_length'] and hashlib.sha256(original).hexdigest()==expected['sha256'],'Changed contact helper bytes '+label
        if label!='abs':assert row.get('all_instructions_equal_after_branch_destination_normalization') is True,'Unproved contact source/DOS helper '+label
    constants=data.get('constants',{})
    assert tuple(constants.get(k)for k in ['landing_speed_l1_limit_raw_s32','landing_gear_required_u16','landing_orientation_dot_minimum_q31_s32','impact_damage_divisor_s32'])==(600,65535,0x78000000,1800),'Contact original landing/damage thresholds changed'
    variants=data.get('source_variants',{});policy=data.get('caller_policies',{})
    assert variants.get('full_F575_anchor_is_runtime_entry') is False and variants.get('F577_included_in_runtime') is False and variants.get('F578_included_in_runtime') is False,'Bounded contact must not claim full/excluded classifiers'
    assert (variants.get('F577_DOS_other_radius_object_offset'),variants.get('F577_pinned_JJFFE_other_radius_object_offset'))==(0x138,0x140),'Lost explicit DOS/JJFFE sphere-classifier difference'
    assert policy.get('source_classifier_integrated') is False and policy.get('source_frame_pipeline_integrated') is False and policy.get('whole_original_physics') is False,'Phone contact provider must remain an explicit adapter'
    assert 'radial source normal' in data.get('canonical_contracts',{}).get('natural_normal','') and 'no second HP or contact RNG state' in policy.get('HP_RNG_scope',''),'Contact source normal or shared HP policy changed'
    descriptor_path='assets/data/ffe_runtime_model_descriptors.json'
    assert descriptor_path in names,'Missing original runtime descriptor table'
    descriptor_raw=archive.read(descriptor_path)
    assert descriptor_raw==(project/'data/ffe_runtime_model_descriptors.json').read_bytes() and hashlib.sha256(descriptor_raw).hexdigest()==SURFACE_CONTACT_RUNTIME_DESCRIPTOR_SHA256,'Contact runtime descriptors differ from immutable original table'
    descriptors=json.loads(descriptor_raw)
    assert descriptors.get('model_count')==149 and descriptors.get('source_sha256')==SOURCE_IMAGE_SHA256,'Wrong contact descriptor-table provenance'
    assert set(data.get('ship_models',{}))=={'15','24','38'},'Incomplete three-ship contact provenance'
    for key,row in data['ship_models'].items():
        original=descriptors['models'][key];spec=fuel['hyper']['data']['ship_specs'][key]
        desc=bytes.fromhex(row.get('descriptor_hex',''));raw_spec=bytes.fromhex(row.get('spec_hex',''))
        assert len(desc)==68 and row['descriptor_hex']==original['descriptor_hex'] and hashlib.sha256(desc).hexdigest()==original['descriptor_sha256'],'Contact ship descriptor differs from original '+key
        assert len(raw_spec)==24 and row['spec_hex']==spec['spec_hex'] and hashlib.sha256(raw_spec).hexdigest()==spec['spec_sha256'] and struct.unpack_from('<I',desc,0x38)[0]==spec['original_spec_pointer_u32'],'Contact ship specification differs from original '+key
        assert row.get('model_scale_raw')==sum(struct.unpack_from('<II',desc,0x14))-8,'Contact ship bounds lost F1495 exponent bias '+key
    assert hashlib.sha256(raw).hexdigest()==SURFACE_CONTACT_RESOURCE_SHA256,'Contact resource differs from frozen DOS extraction'
    protected={path:value for path,value in MAP_VISUAL_PROTECTED_SOURCE_SHA256.items()
               if path not in ('scripts/main.gd','scripts/system_map_view.gd','scripts/navigation.gd','scripts/galactic_map_model.gd',
                               'scripts/flight_model.gd','scripts/surface_model.gd','scripts/source_motion_bridge.gd','scripts/flight_time_controller.gd')}
    for relative,expected in {**protected,**HYPERDRIVE_INFORMATION_SOURCE_SHA256,**FUEL_CONTACT_DEPENDENCY_SHA256,**SURFACE_CONTACT_UNCHANGED_SOURCE_SHA256,**SURFACE_CONTACT_PROVIDER_DEPENDENCY_SHA256}.items():
        assert hashlib.sha256((project/relative).read_bytes()).hexdigest()==expected,'Surface-contact update changed protected source/data '+relative
    assert hashlib.sha256((project/'scripts/celestial_renderer.gd').read_bytes()).hexdigest()==SYSTEM_INFORMATION_CELESTIAL_SHA256,'Surface-contact update changed Mercury stellar visibility'
    assert hashlib.sha256((project/'scripts/system_map_view.gd').read_bytes()).hexdigest()==SYSTEM_INFORMATION_MAP_VIEW_SHA256['scripts/system_map_view.gd'],'Surface-contact update changed system-map travel/information'
    providers={}
    for relative in SURFACE_CONTACT_PROVIDER_DEPENDENCY_SHA256:
        if not relative.endswith('.gd'):continue
        name=Path(relative).stem;path='assets/scripts/'+name+'.gdc'
        assert path in names,'Missing published contact provider runtime '+name
        content=archive.read(path)
        assert len(content)>64 and content[:4]==b'GDSC','Invalid compiled published contact provider '+name
        providers[name]=hashlib.sha256(content).hexdigest()
    source={Path(relative).stem:(project/relative).read_text()for relative in SURFACE_CONTACT_AUDITED_SOURCE_SHA256}
    if normalized_main is not None:source['main']=normalized_main
    main=source['main'];surface=source['surface_model'];bridge=source['source_surface_contact_bridge'];core=source['source_surface_contact'];session=source['source_hyperdrive_session'];nav=source['navigation']
    unchanged={name:value for name,value in FUEL_UNCHANGED_MAIN_FUNCTION_SHA256.items()if name not in ('_new_models','_time_context','_apply_system','_toggle_auto','_dock_action')}
    main_normalization={'_advance_controls':('\tif not surface.pending_source_contact().is_empty():\n\t\t_tick(0.0,Vector2.ZERO,0.0)\n\t\treturn\n',''),'_set_speed':('if instruments.paused or not surface.pending_source_contact().is_empty():return','if instruments.paused:return')}
    for name,expected in unchanged.items():
        body=source_function(main,name)
        if name in main_normalization:
            addition,replacement=main_normalization[name]
            assert body.count(addition)==1,'Missing approved pending-contact Main guard '+name
            body=body.replace(addition,replacement,1)
        assert hashlib.sha256(body.encode()).hexdigest()==expected,'Contact changed undeclared physical Main function '+name
    for name,expected in LANDING_GEAR_UNCHANGED_SURFACE_FUNCTION_SHA256.items():assert hashlib.sha256(source_function(surface,name).encode()).hexdigest()==expected,'Contact changed undeclared physical Surface function '+name
    for relative,methods in SURFACE_CONTACT_UNCHANGED_STATE_FUNCTION_SHA256.items():
        text=(project/relative).read_text()
        for name,expected in methods.items():assert hashlib.sha256(source_function(text,name).encode()).hexdigest()==expected,'Contact changed persisted fuel/thermal/quote function '+relative+'/'+name
    tick=source_function(main,'_tick');apply=source_function(main,'_apply_pending_source_contact')
    finish_interval=source_function(main,'_finish_flight_interval')
    assert '_apply_pending_source_contact()' in tick and '_finish_flight_interval(' in tick and tick.index('_apply_pending_source_contact()')<tick.index('_finish_flight_interval('),'Main contact must resolve before fuel/thermal and arrival save'
    assert '_step_source_fuel(dt,fuel_commands)' in finish_interval and 'if save_after_fuel:_save_game()' in finish_interval and finish_interval.index('_step_source_fuel(dt,fuel_commands)')<finish_interval.index('if save_after_fuel:_save_game()'),'Contact interval must debit source fuel before arrival autosave'
    assert 'fuel_commands=FuelFlightBridge.commands(ship,dt)' in tick and tick.index('fuel_commands=FuelFlightBridge.commands(ship,dt)')<tick.rindex('_apply_pending_source_contact()'),'Contact must capture fired nozzles before native pose rotation'
    assert '_source_contact_interval=' in tick and '_finish_flight_interval(float(interval.seconds),interval.commands,save_after)' in tick and '_source_contact_interval.clear()' in tick,'Failed contact must retain and complete its existing interval exactly once'
    assert 'SurfaceContactBridge.resolve(surface,ship,int(_gear_state().get("position_u16",0)),event)' in apply,'Live contact must consume bridge and physical gear word'
    assert 'resolution.position.is_finite()' in apply and 'resolution.velocity.is_finite()' in apply and 'resolution.attitude.is_finite()' in apply and apply.index('resolution.attitude.is_finite()')<apply.index('nav.apply_contact_damage('),'Complete candidate pose must validate before HP mutation'
    assert 'nav.sync_thermal_ship(ship)' in apply and 'nav.apply_contact_damage(resolution.get("damage_calls",[]),ship)' in apply and 'surface.finish_source_contact(ship,resolution,parked,hpdetail)' in apply,'Contact requests are disconnected from shared HP and pose consumers'
    assert apply.index('nav.apply_contact_damage(')<apply.index('surface.finish_source_contact('),'Shared contact HP must commit before the validated pose'
    assert '_source_ship_destroyed(' in apply and 'destruction_requested' in apply and '_record_event("source_surface_contact",source_contact_last)' in apply,'Contact destruction/diagnostic consumers are missing'
    assert 'surface.set_source_contact_enabled(' in source_function(main,'_apply_landing_gear_state') and 'World.FULL_LAYOUT' in source_function(main,'_apply_landing_gear_state') and 'nav.is_source_hyperdrive()' in source_function(main,'_apply_landing_gear_state'),'Source contact must remain explicit for full source sessions'
    assert 'not surface.pending_source_contact().is_empty():return {}' in source_function(main,'_payload') and 'not surface.pending_source_contact().is_empty():return false' in source_function(main,'_save_game'),'Unresolved contact must not be persisted as a half-applied impact'
    queue=source_function(surface,'_queue_source_contact');finish=source_function(surface,'finish_source_contact')
    assert 'not _pending_source_contact.is_empty():return false' in queue and '_pending_source_contact.clear()' in finish,'One physical event must not queue/apply duplicate contact requests'
    assert 'uses_source_contact()' in source_function(surface,'touch_down') and '_queue_source_contact(ship,"manual"' in source_function(surface,'touch_down') and '_queue_source_contact(ship,"city_floor"' in source_function(surface,'_clip_source_city') and '_queue_source_contact(ship,"terrain"' in source_function(surface,'step'),'Manual/terrain/city floors lack the common source contact path'
    assert 'not uses_source_contact() and altitude(ship)<=0' in source_function(surface,'step'),'Source contacts still fall through the old independent SI impact penalty'
    assert not re.search(r'ship\.hull\s*=',finish) and 'ship.position=Vector3(resolution.position)' in finish and 'ship.attitude=Quaternion(resolution.attitude)' in finish,'Pose commit must not apply a second percent-based impact law'
    contact=source_function(session,'apply_contact_damage');nav_contact=source_function(nav,'apply_contact_damage')
    assert 'candidate._apply_damage_call(call)' in contact and '_copy(candidate)' in contact and 'rng_state_after' in contact,'Contact damage must reuse the existing authoritative F953 HP/RNG owner'
    assert 'calls.is_empty():return result' in contact and 'candidate.apply_contact_damage(calls)' in nav_contact and '_commit_fuel_result(candidate,result,ship)' in nav_contact,'Contact damage caller lost transactional empty/batch semantics'
    assert 'Core.resolve_player(body,parent,context)' in source_function(bridge,'resolve') and 'body.encode_u16(0x9e,physical_gear_u16)' in source_function(bridge,'resolve'),'Bridge bypasses bounded source continuation or physical gear state'
    assert 'res://data/ffe_runtime_model_descriptors.json' in source_function(bridge,'_load_tables') and 'res://data/ffe_hyperdrive.json' in source_function(bridge,'_load_tables') and 'FileAccess.get_sha256(row[1])!=row[2]' in source_function(bridge,'_load_tables'),'Bridge runtime model/spec tables lack exact immutable consumers'
    assert 'state.height_at(globe,' in source_function(bridge,'sample') and 'Frame._inverse_rows(basis)' in source_function(bridge,'to_local_vector') and 'to_bodyfixed_point(basis,' in source_function(bridge,'sample'),'Published provider/frame conversion consumers are missing'
    assert 'var up:=radius+float(value.y)' in source_function(bridge,'to_bodyfixed_point') and 'PackedFloat64Array' in source_function(bridge,'to_bodyfixed_point'),'Planet-scale contact positions must preserve small local height before Float32 conversion'
    assert '"mesh_normal_is_native_contact_normal":false' in bridge and '"collision_kind_u8":1' in source_function(bridge,'resolve') and '_radial_normal(relative)' in source_function(core,'resolve_player'),'Phone geometry must not replace the original kind1 radial response normal'
    assert 'int(globals.player_object_index_u32)!=int(body[0x86])' in source_function(core,'_valid'),'Bounded player continuation must not silently become a full NPC/classifier implementation'
    for relative,expected in SURFACE_CONTACT_AUDITED_SOURCE_SHA256.items():
        content=normalized_main.encode() if relative=='scripts/main.gd' and normalized_main is not None else (project/relative).read_bytes()
        assert hashlib.sha256(content).hexdigest()==expected,'Contact differs from audited integration source '+relative
    fixture_raw=(project/'tests/fixtures/source_surface_contact_native.json').read_bytes();fixture=json.loads(fixture_raw)
    assert hashlib.sha256(fixture_raw).hexdigest()==SURFACE_CONTACT_NATIVE_REFERENCE_SHA256,'Changed surface-contact native reference'
    assert fixture.get('schema_version')==1 and fixture.get('executable_sha256')==SOURCE_IMAGE_SHA256 and fixture.get('pinned_asm_sha256')==SOURCE_ASSEMBLY_SHA256 and fixture.get('source_commit')==SOURCE_ASSEMBLY_COMMIT,'Wrong contact native source provenance'
    assert fixture.get('case_count')==len(fixture.get('cases',[]))==858,'Incomplete contact native cases'
    checks=fixture.get('execution_checks',{})
    assert checks.get('fresh_identical_processes')==3 and checks.get('reverse_case_order_identical') is True and checks.get('object_parent_relative_descriptor_spec_output_canaries') is True and checks.get('unrelated_body_bytes_unchanged') is True and checks.get('parent_and_descriptors_and_specs_unchanged') is True and checks.get('expected_transitions_computed_by_python') is False,'Incomplete contact native reproduction'
    assert set(fixture.get('byte_instruction_proofs',{}))==set(SURFACE_CONTACT_INSTRUCTION_PROOFS),'Incomplete native contact instruction proof'
    for label,expected in SURFACE_CONTACT_INSTRUCTION_PROOFS.items():
        row=fixture['byte_instruction_proofs'][label]
        assert all(row.get(key)==value for key,value in expected.items()),'Native contact instructions differ from DOS '+label
        if label!='abs':assert row.get('all_instructions_equal_after_branch_destination_normalization') is True,'Unproved native contact instruction equivalence '+label
    assert set(fixture.get('models',{}))=={'15','24','38','81','96','117','118','121','130','134','140'},'Changed native contact model domain'
    for key,row in fixture['models'].items():assert row.get('descriptor_hex')==descriptors['models'][key]['descriptor_hex'],'Native contact model differs from runtime original '+key
    return {'baseline_source_commit':SURFACE_CONTACT_BASELINE_SOURCE_COMMIT,'compiled_modules':modules,'compiled_module_count':2,'integration_compiled_modules':integration_modules,'integration_compiled_module_count':len(integration_modules),
        'raw_resource_sha256':hashlib.sha256(raw).hexdigest(),'raw_json_count':1,'new_json_is_provenance_only':True,'new_json_runtime_lookup_required':False,
        'runtime_primary_anchor_bytes':1657,'runtime_primary_instruction_count':518,'full_F575_static_anchor_bytes':2005,'full_F575_static_instruction_count':635,
        'instruction_proof_record_count':21,'instruction_proof_bytes_including_primary':3402,'instruction_proof_instructions_including_primary':1259,'exact_current_ship_models':3,
        'audited_local_source_sha256':SURFACE_CONTACT_AUDITED_SOURCE_SHA256,'unchanged_code43_source_count':len(SURFACE_CONTACT_UNCHANGED_SOURCE_SHA256),'protected_old_source_data_count':len(protected),'protected_contact_dependency_count':len(FUEL_CONTACT_DEPENDENCY_SHA256),
        'published_provider_dependency_count':len(SURFACE_CONTACT_PROVIDER_DEPENDENCY_SHA256),'published_provider_compiled_modules':providers,'unchanged_Main_function_count':len(unchanged)-len(main_normalization),'normalized_Main_function_count':len(main_normalization),'protected_Main_function_count':len(unchanged),'unchanged_Surface_function_count':len(LANDING_GEAR_UNCHANGED_SURFACE_FUNCTION_SHA256),'unchanged_saved_state_function_count':sum(map(len,SURFACE_CONTACT_UNCHANGED_STATE_FUNCTION_SHA256.values())),
        'unchanged_landing_gear_resource_sha256':LANDING_GEAR_RESOURCE_SHA256,'retained_landing_gear_compiled_module_count':len(gear['modules']),'unchanged_atmosphere_resource_sha256':ATMOSPHERE_RESOURCE_SHA256,'retained_atmosphere_compiled_module_count':len(atmosphere['modules']),'retained_atmosphere_native_references':atmosphere['references'],
        'unchanged_fuel_resource_sha256':FUEL_RESOURCE_SHA256,'retained_fuel_compiled_module_count':len(fuel['modules']),'retained_fuel_native_references':fuel['references'],'unchanged_hyperdrive_resource_sha256':HYPERDRIVE_RESOURCE_SHA256,'retained_hyperdrive_compiled_module_count':len(fuel['hyper']['modules']),'unchanged_information_resources':fuel['information']['tables'],'unchanged_information_runtime_count':3,
        'native_reference':{'sha256':SURFACE_CONTACT_NATIVE_REFERENCE_SHA256,'case_count':858,'source_variant':'uploaded-DOS-bounded-F575-postclassification-player-continuation','oracle_executed_by_apk_verifier':False},
        'shared_F953_HP_RNG_consumer_checked':True,'actual_contact_pose_and_save_consumers_checked':True,'authored_clearance_to_native_origin_is_adapter':True,
        'whole_F575_runtime':False,'full_F569_F570_F576_F577_F578_classifier':False,'full_original_reference_frame_pipeline':False,'full_original_destruction_equipment_dispatcher':False,'complete_original_physics':False,'compiled_source_correspondence_rebuilt_by_verifier':False,'physical_device_tested':False}


def _normalize_spherical_main(main):
    # Exactly one preload and one diagnostic-only addition; every remaining
    # byte must equal the portable code44 Main, including physical/save paths.
    preload='const SphericalContactProbe=preload("res://scripts/source_spherical_contact_probe.gd")\n'
    old_return='\tvar sample:={"ship_id"'
    diagnostic='\tsample["source_spherical_probe"]=SphericalContactProbe.sample(world,ship,surface,nav.elapsed_days) if nav.is_source_hyperdrive() else {"ok":true,"reason":"legacy_navigation","envelope_only":true,"response_applied":false}\n\treturn sample\n\n'
    assert main.count(preload)==1 and main.count(old_return)==1 and main.count(diagnostic)==1,'Missing exact spherical diagnostic-only Main additions'
    function=source_function(main,'_flight_diagnostic_sample')
    assert old_return in function and diagnostic in function,'Spherical probe must only run in diagnostic sampling'
    normalized=main.replace(preload,'',1).replace(old_return,'\treturn {"ship_id"',1).replace(diagnostic,'',1)
    assert hashlib.sha256(normalized.encode()).hexdigest()==SURFACE_CONTACT_AUDITED_SOURCE_SHA256['scripts/main.gd'],'Spherical update changed physical/save/Main outside exact diagnostic normalization'
    return normalized


def verify_spherical_contact_runtime(archive,project):
    """Code45 source/asset controls; no oracle execution, GDSC decompilation or device claim."""
    return _verify_spherical_contact_runtime(archive,project)


def _verify_spherical_contact_runtime(archive,project,normalized_main=None):
    # Private retained audit view. The public code45 entry still checks the
    # actual Main exactly; code46 first proves its complete Main normalization.
    names=set(archive.namelist());compiled={}
    for relative,expected in SPHERICAL_CONTACT_AUDITED_SOURCE_SHA256.items():
        name=Path(relative).stem;path='assets/scripts/'+name+'.gdc'
        assert path in names,'Missing spherical-contact integration runtime '+name
        content=archive.read(path)
        assert len(content)>64 and content[:4]==b'GDSC','Invalid compiled spherical-contact integration runtime '+name
        compiled[name]=hashlib.sha256(content).hexdigest()
    main=normalized_main if normalized_main is not None else (project/'scripts/main.gd').read_text()
    normalized=_normalize_spherical_main(main)
    for relative,expected in SPHERICAL_CONTACT_AUDITED_SOURCE_SHA256.items():
        raw=main.encode() if relative=='scripts/main.gd' else (project/relative).read_bytes()
        assert hashlib.sha256(raw).hexdigest()==expected,'Spherical contact differs from audited integration source '+relative
    # This retained report describes the virtual AD3 Main audit view only.
    # The actual Main and its exact normalization are separately pinned above.
    retained=_verify_surface_contact_runtime(archive,project,normalized)
    path='assets/data/ffe_spherical_contact.json'
    assert path in names,'Missing spherical-contact routing resource'
    raw=archive.read(path)
    assert raw==(project/'data/ffe_spherical_contact.json').read_bytes(),'Spherical-contact resource differs from local source'
    data=json.loads(raw)
    assert data.get('schema')==1 and data.get('profile')=='dos-firstenc-f577-spherical-contact-routing-v1','Wrong spherical-contact extraction profile'
    assert data.get('source_sha256')==SOURCE_IMAGE_SHA256 and data.get('source_assembly_sha256')==SOURCE_ASSEMBLY_SHA256 and data.get('source_commit')==SOURCE_ASSEMBLY_COMMIT and data.get('source_data_sha256')=='34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850','Wrong spherical-contact source provenance'
    immutable={'ffe_hyperdrive_sha256':HYPERDRIVE_RESOURCE_SHA256,'ffe_fuel_sha256':FUEL_RESOURCE_SHA256,'ffe_atmosphere_sha256':ATMOSPHERE_RESOURCE_SHA256,'ffe_landing_gear_sha256':LANDING_GEAR_RESOURCE_SHA256,'ffe_surface_contact_sha256':SURFACE_CONTACT_RESOURCE_SHA256,'ffe_runtime_model_descriptors_sha256':SURFACE_CONTACT_RUNTIME_DESCRIPTOR_SHA256}
    assert data.get('immutable_resources')==immutable,'Spherical extension changed retained resource digests'
    assert data.get('helper_proof_complete') is True and set(data.get('instruction_proofs',{}))==set(SPHERICAL_CONTACT_INSTRUCTION_PROOFS),'Incomplete spherical instruction proof domain'
    for label,expected in SPHERICAL_CONTACT_INSTRUCTION_PROOFS.items():
        row=data['instruction_proofs'][label];original=bytes.fromhex(row.get('hex',''))
        assert all(row.get(key)==value for key,value in expected.items()),'Changed spherical DOS instruction proof '+label
        assert len(original)==expected['byte_length'] and hashlib.sha256(original).hexdigest()==expected['sha256'] and row.get('all_instructions_equal_after_branch_destination_normalization') is True,'Changed spherical DOS bytes '+label
    variants=data.get('source_variants',{})
    assert (variants.get('nonpositive_shift_DOS_parent_radius_offset'),variants.get('nonpositive_shift_JJFFE_parent_radius_offset'))==(0x138,0x140) and variants.get('other_instructions_equal') is True,'Spherical DOS/JJFFE radius operand distinction changed'
    dos=bytes.fromhex(data['instruction_proofs']['577']['hex'])
    assert dos[0x18eb2-0x18e4c:0x18eb8-0x18e4c]==bytes.fromhex('038638010000'),'Canonical F577 must retain DOS parent+138'
    api=data.get('raw_api',{})
    assert api.get('global_writes_only')==['collision_flags_u8','altitude_s64'] and all(key in api.get('does_not_write',[])for key in ('body','parent','collision_kind','previous_altitude','HP','RNG','clock')),'Spherical helper must remain bounded and read-only'
    policy=data.get('caller_policies',{})
    assert all(policy.get(key) is False for key in ('physical_response_changed_by_probe','source_world_bank_dispatch_integrated','full_F569_F570_F576_F578_pipeline_integrated','HP_RNG_clock_mutated_by_probe','full_original_physics')),'Diagnostic envelope must not claim live collision/world physics'
    rows=data.get('model_collision_routing',{});descriptors=json.loads((project/'data/ffe_runtime_model_descriptors.json').read_text())['models']
    assert set(rows)=={str(i)for i in range(149)},'Incomplete149-model spherical routing domain'
    zero=[];eligible=[];hierarchical=[]
    for index in range(149):
        row=rows[str(index)];original=descriptors[str(index)];descriptor=bytes.fromhex(original['descriptor_hex'])
        pointer=struct.unpack_from('<I',descriptor,0x34)[0];prefix=bytes.fromhex(row.get('collision_prefix_hex',''))
        assert row.get('model_index')==index and row.get('descriptor_file_offset')==original['descriptor_executable_offset'] and row.get('descriptor_sha256')==original['descriptor_sha256'] and row.get('collision_pointer_u32')==pointer,'Spherical routing descriptor mismatch '+str(index)
        assert len(prefix)==(8 if pointer else 0) and hashlib.sha256(prefix).hexdigest()==row.get('collision_prefix_sha256'),'Spherical routing prefix mismatch '+str(index)
        first=prefix[0]if pointer else 0
        assert row.get('collision_first_byte_u8')==first and (row.get('collision_file_offset')==pointer-0x416400 if pointer else row.get('collision_file_offset') is None),'Spherical collision pointer/first byte mismatch '+str(index)
        flags=((struct.unpack_from('<I',descriptor,0x24)[0]>>4)&7)|(128 if first else 0)
        assert row.get('descriptor_derived_object_flags_14c_u8')==flags,'Spherical routing derived flags mismatch '+str(index)
        if first==0:zero.append(index)
        if index==0:
            assert row.get('model_zero_skips_F1533_descriptor_initialization') is True and row.get('initial_object_flags_14c_u8') is None and row.get('initial_sphere_path_eligible') is None,'Model0 skips F1533; initialized flags/eligibility must remain unknown'
        else:
            assert row.get('model_zero_skips_F1533_descriptor_initialization') is False and row.get('initial_object_flags_14c_u8')==flags and row.get('initial_sphere_path_eligible') is ((flags&128)==0),'Spherical initialized routing mismatch '+str(index)
            (eligible if flags&128==0 else hierarchical).append(index)
    expected_zero=list(range(14))+[101,102,104,105,109]
    assert zero==expected_zero and data.get('descriptor_stream_zero_models')==zero and eligible==list(range(1,14))+[101,102,104,105,109] and data.get('initial_simple_sphere_models')==eligible and data.get('initialization_skipped_models')==[0] and data.get('initial_hierarchical_models')==hierarchical,'Spherical19zero/18initialized/130hierarchical routing counts changed'
    assert all(rows[str(i)]['initial_sphere_path_eligible'] is False for i in range(117,149)),'Natural collision streams require F576 and cannot become F577 terrain'
    assert hashlib.sha256(raw).hexdigest()==SPHERICAL_CONTACT_RESOURCE_SHA256,'Spherical routing resource differs from frozen DOS extraction'
    source={Path(relative).stem:(project/relative).read_text()for relative in SPHERICAL_CONTACT_AUDITED_SOURCE_SHA256}
    source['main']=main
    probe=source['source_spherical_contact_probe'];pipeline=source['source_spherical_contact_pipeline'];core=source['source_spherical_contact']
    assert 'res://data/ffe_spherical_contact.json' in probe and 'FileAccess.get_sha256(DATA_PATH)!=DATA_SHA' in source_function(probe,'_load_routing') and SPHERICAL_CONTACT_RESOURCE_SHA256 in probe and 'model_collision_routing' in source_function(probe,'_load_routing'),'Read-only probe lacks immutable routing resource consumer'
    assert 'Sphere.classify(player,parent,context)' in source_function(probe,'sample') and '"response_applied":false' in source_function(probe,'_base') and '"envelope_only":true' in source_function(probe,'_base'),'Probe must remain envelope-only without response'
    assert 'world.bodies.duplicate(true)' in source_function(probe,'_scratch_world') and 'scratch._full_origin_raw(days)' in source_function(probe,'_space_point') and 'Bridge.to_bodyfixed_point(' in source_function(probe,'sample'),'Probe frame/ephemeris sampling must stay read-only and explicit'
    assert 'parent[0x14c]&0x80' in source_function(pipeline,'resolve_player') and 'hierarchical_collision_stream_requires_f576' in pipeline and 'other_pair_response_requires_f578' in pipeline and 'Response.resolve_player(body,parent,response_context)' in pipeline,'Bounded raw route lost unsupported-path guards or prior terminal helper'
    assert 'body.decode_u32(0x140)+parent.decode_u32(0x138)' in source_function(core,'classify') and '0 if inside else -1' in source_function(core,'classify'),'F577 raw DOS radius/return semantics changed'
    references={}
    for name,expected_sha,count in [('source_spherical_contact_native',SPHERICAL_CONTACT_NATIVE_REFERENCE_SHA256,1141),('source_spherical_contact_pipeline_native',SPHERICAL_CONTACT_PIPELINE_REFERENCE_SHA256,213)]:
        fixture_raw=(project/'tests/fixtures'/f'{name}.json').read_bytes();fixture=json.loads(fixture_raw)
        assert hashlib.sha256(fixture_raw).hexdigest()==expected_sha,'Changed spherical native reference '+name
        assert fixture.get('schema_version')==1 and fixture.get('executable_sha256')==SOURCE_IMAGE_SHA256 and fixture.get('pinned_asm_sha256')==SOURCE_ASSEMBLY_SHA256 and fixture.get('source_commit')==SOURCE_ASSEMBLY_COMMIT and fixture.get('case_count')==len(fixture.get('cases',[]))==count,'Wrong spherical native source/case domain '+name
        checks=fixture.get('execution_checks',{})
        assert checks.get('fresh_identical_processes')==3 and checks.get('reverse_case_order_identical') is True,'Incomplete spherical native reproduction '+name
        expected_proofs=SPHERICAL_CONTACT_INSTRUCTION_PROOFS if count==1141 else SPHERICAL_CONTACT_PIPELINE_INSTRUCTION_PROOFS
        assert set(fixture.get('byte_instruction_proofs',{}))==set(expected_proofs),'Incomplete spherical native instruction domain '+name
        for label,expected in expected_proofs.items():
            assert all(fixture['byte_instruction_proofs'][label].get(key)==value for key,value in expected.items()),'Changed spherical native instruction proof '+name+'/'+label
        if count==1141:
            assert checks.get('object_parent_relative_absolute_output_canaries') is True and checks.get('all_input_buffers_unchanged') is True and checks.get('expected_transitions_computed_by_python') is False,'Incomplete pure F577 native isolation'
            assert fixture.get('known_jjffe_variant')==variants.get('known_jjffe_variant'),'Native F577 source variant differs'
        else:
            assert fixture.get('supported_case_count')==207 and fixture.get('unsupported_guard_case_count')==6 and fixture.get('canonical_classifier_fixture_sha256')==SPHERICAL_CONTACT_NATIVE_REFERENCE_SHA256,'Coupled native cases must separate207supported from6host guards'
            assert all(fixture.get(key) is False for key in ('complete_original_F575_behavior','F576_F578_engine_executed','full_F569_scanner')),'Coupled native reference cannot claim full scanner/pair/terrain engine'
            assert checks.get('raw338_parent_descriptor_spec_output_canaries') is True and checks.get('unrelated_body_bytes_unchanged') is True and checks.get('parent_descriptors_specs_unchanged') is True and checks.get('expected_source_transitions_computed_by_python') is False,'Incomplete coupled native isolation'
        references[name]={'sha256':expected_sha,'case_count':count,'supported_case_count':count if count==1141 else 207,'host_guard_case_count':0 if count==1141 else 6,'oracle_executed_by_apk_verifier':False}
    return {'baseline_source_commit':SPHERICAL_CONTACT_BASELINE_SOURCE_COMMIT,'compiled_modules':{k:compiled[k]for k in SPHERICAL_CONTACT_MODULES},'compiled_module_count':3,'integration_compiled_modules':compiled,'integration_compiled_module_count':len(compiled),'audited_local_source_sha256':SPHERICAL_CONTACT_AUDITED_SOURCE_SHA256,
        'raw_resource_sha256':SPHERICAL_CONTACT_RESOURCE_SHA256,'raw_json_count':1,'new_json_is_runtime_routing_resource':True,'new_json_runtime_lookup_required':True,'descriptor_model_count':149,'descriptor_zero_stream_count':19,'initial_simple_sphere_count':18,'initialization_skipped_model_count':1,'initial_hierarchical_count':130,
        'primary_anchor_bytes':363,'primary_instruction_count':128,'instruction_proof_record_count':7,'instruction_proof_bytes':917,'instruction_proof_instructions':367,'native_references':references,
        'unchanged_code44_source_count':22,'whole_Main_normalization_sha256':SURFACE_CONTACT_AUDITED_SOURCE_SHA256['scripts/main.gd'],'Main_normalization_policy':'Exactly one probe preload and diagnostic sample rewrite removed; all other bytes equal code44 AD3. Retained strict44 report audits this virtual normalized Main; actual45 Main is separately pinned.','actual_Main_sha256':SPHERICAL_CONTACT_AUDITED_SOURCE_SHA256['scripts/main.gd'],'retained_surface_contact_assets':retained,
        'actual_Main_probe_readonly':True,'physical_response_changed_by_probe':False,'complete_original_F575':False,'F576_F578_engine_integrated':False,'full_original_world_object_bank':False,'complete_original_physics':False,'compiled_source_correspondence_rebuilt_by_verifier':False,'physical_device_tested':False}

def _load_contact_alignment_baseline(project):
    """Read immutable host source history, never replace exported assets."""
    raw=(project/'tests/fixtures/alignment_v46_sources.json').read_bytes()
    assert hashlib.sha256(raw).hexdigest()==CONTACT_ALIGNMENT_BASELINE_FIXTURE_SHA256,'Changed portable code46 alignment source baseline'
    data=json.loads(raw)
    expected={**NATURAL_CONTACT_AUDITED_SOURCE_SHA256,**CONTACT_ALIGNMENT_PROVIDER_SOURCE_SHA256,
              'scripts/surface_orbit_link.gd':'c1cffc1ea9ba6efc4ea88e3adcf0e6e84ec2a42ff830df6f3d8e23097ca1767c'}
    assert data.get('schema')==1 and data.get('source_commit')==CONTACT_ALIGNMENT_BASELINE_SOURCE_COMMIT and data.get('audited_runtime_source_sha256')==NATURAL_CONTACT_AUDITED_SOURCE_SHA256 and data.get('provider_source_sha256')==CONTACT_ALIGNMENT_PROVIDER_SOURCE_SHA256 and set(data.get('files',{}))==set(expected),'Wrong portable code46 alignment baseline domain'
    for path,digest in expected.items():
        entry=data['files'][path]
        assert entry.get('sha256')==digest and hashlib.sha256(entry.get('source','').encode()).hexdigest()==digest,'Changed portable code46 alignment source '+path
    return data


class _AlignmentSourceAuditPath:
    """A read-only host source-history view; archive entries are never wrapped."""
    def __init__(self,project,overrides,relative=Path('.')):
        self.project=project;self.overrides=overrides;self.relative=relative
    def __truediv__(self,relative):
        return _AlignmentSourceAuditPath(self.project,self.overrides,self.relative/relative)
    def read_bytes(self):
        key=self.relative.as_posix()
        return self.overrides[key].encode() if key in self.overrides else (self.project/self.relative).read_bytes()
    def read_text(self,encoding='utf-8'):
        return self.read_bytes().decode(encoding)


def _verify_contact_field_native_reference(project):
    raw=(project/'tests/fixtures/source_contact_field_native.json').read_bytes();data=json.loads(raw)
    assert hashlib.sha256(raw).hexdigest()==CONTACT_ALIGNMENT_FIELD_REFERENCE_SHA256,'Changed independent signed-field native reference'
    assert data.get('schema')==1 and data.get('revision')=='source-contact-field-native-v1' and data.get('source_sha256')==SOURCE_IMAGE_SHA256 and data.get('source_assembly_sha256')==SOURCE_ASSEMBLY_SHA256 and data.get('source_commit')==SOURCE_ASSEMBLY_COMMIT,'Wrong signed-field native provenance'
    assert data.get('source_canonical_fixture_sha256')==NATURAL_CONTACT_NATIVE_REFERENCE_SHA256 and data.get('source_units_module_sha256')==FUEL_CONTACT_DEPENDENCY_SHA256['scripts/source_units.gd'],'Signed-field native proof must retain canonical F576 and exact source units'
    anchors=data.get('anchors',[]);geometry=data.get('geometry_cases',[]);classifier=data.get('classifier_cases',[])
    assert data.get('anchor_count')==len(anchors)==51 and data.get('model_count')==17 and {row['model_index']for row in anchors}==set(range(117,134)),'Incomplete signed-field17-model51-anchor domain'
    assert data.get('geometry_case_count')==len(geometry)==153 and data.get('classifier_case_count')==len(classifier)==306 and data.get('case_count')==459 and data.get('player_models')==[24,38,15],'Signed-field geometry/classifier cases cannot be conflated'
    assert data.get('fresh_process_runs_per_bank')==3 and data.get('geometry_reverse_repeat_count')==153 and data.get('classifier_reverse_repeat_count')==306 and data.get('original_body_parent_buffers_and_canaries_unchanged') is True and data.get('python_expected_query_arithmetic') is False,'Incomplete independent signed-field native execution checks'
    excluded=['model117_axis_x','model117_axis_z']
    assert data.get('geometry_exclusion_anchor_ids')==excluded,'Model117 geometry-only coarse-bound exclusions changed'
    assert sum(row['certified_status']=='exact_zero'for row in anchors)==39 and sum(row['certified_status']=='adjacent_sign_boundary'for row in anchors)==12,'Signed-field zero/adjacent-boundary domains changed'
    assert {row['role']for row in geometry}=={'final','inside','outside'} and {row['role']for row in classifier}=={'final','native_inner_clearance'},'Incomplete signed-field native witness roles'
    altered=[]
    for row in geometry:
        if row['geometry_parent_object_hex']!=row['original_parent_object_hex']:altered.append(row['anchor_id'])
    assert len(altered)==6 and set(altered)==set(excluded),'Expanded model117 bounds may occur only in six geometry-only witnesses'
    descriptors=json.loads((project/'data/ffe_runtime_model_descriptors.json').read_bytes())['models']
    ships=json.loads((project/'data/ffe_natural_contact.json').read_bytes())['ship_models']
    assert {row['player_model']for row in classifier}=={15,24,38},'Signed-field classifier must use all three actual positive-radius player shapes'
    for row in classifier:
        parent=bytes.fromhex(row['parent_object_hex']);player=bytes.fromhex(row['player_object_hex']);descriptor=bytes.fromhex(descriptors[str(row['parent_model'])]['descriptor_hex']);ship=ships[str(row['player_model'])]
        assert len(parent)==338 and len(player)==338,'Signed-field native raw objects must preserve338-byte layout'
        exponent=sum(struct.unpack_from('<II',descriptor,0x14))-8
        bounds=[struct.unpack_from('<h',descriptor,at)[0]for at in (0x2c,0x30)]
        bounds=[value<<exponent if exponent>=0 else value>>(-exponent)for value in bounds]
        assert [struct.unpack_from('<q',parent,at)[0]for at in (0x138,0x140)]==bounds,'Canonical signed-field F576 classifier may not inherit expanded geometry bounds'
        assert struct.unpack_from('<q',player,0x138)[0]==ship['f1533_radii']['outer_s64'] and struct.unpack_from('<q',player,0x140)[0]==ship['f1533_radii']['inner_s64']>0,'Signed-field classifier may not use a zero-radius proxy'
    return {'sha256':CONTACT_ALIGNMENT_FIELD_REFERENCE_SHA256,'case_count':459,'geometry_case_count':153,'canonical_positive_player_classifier_case_count':306,'anchor_count':51,'model_count':17,'exact_zero_count':39,'adjacent_integer_boundary_count':12,'geometry_only_coarse_bound_exclusions':excluded,'canonical_F576_bounds_expanded':False,'oracle_executed_by_apk_verifier':False,'root_algorithm_is_original_FFE':False,'global_root_uniqueness_proved':False,'interpolated_triangle_certification_proved':False}


def _verify_contact_alignment_v4_evidence(project):
    path='validation/alignment-2026-11-13/source-contact-surface-render.json'
    raw=(project/path).read_bytes();data=json.loads(raw)
    assert data.get('schema')==1 and data.get('failures')==0 and data.get('checks',0)>=40,'Missing successful current v4/v5 renderer regression evidence'
    expected=set(CONTACT_ALIGNMENT_PROVIDER_SOURCE_SHA256)|{'scripts/source_terrain_contact_field.gd','scripts/source_contact_surface_terrain.gd','tests/test_source_contact_surface_render.gd'}
    assert set(data.get('sources',{}))==expected,'Incomplete renderer regression source bindings'
    assert data['sources']['tests/test_source_contact_surface_render.gd']==CONTACT_ALIGNMENT_RENDER_TEST_SHA256,'Changed renderer regression test source contract'
    for relative,digest in data['sources'].items():
        assert hashlib.sha256((project/relative).read_bytes()).hexdigest()==digest,'Stale renderer regression evidence source '+relative
    rows={row.get('case'):row for row in data.get('evidence',[])}
    old=rows.get('immutable_v4_compatibility',{})
    assert old.get('old_source_commit')=='abae633776275a88bf0706893a030e7497ae6ef0' and old.get('patch_checksum')==CONTACT_ALIGNMENT_V4_PATCH_CHECKSUM and old.get('global_key')==CONTACT_ALIGNMENT_V4_GLOBAL_KEY,'Current renderer changed independently measured old v4 checksum/cache defaults'
    patch=rows.get('actual_source_v5_saved_triangle',{});worker=rows.get('actual_source_v5_worker_packet',{})
    assert patch.get('interpolated_triangle_is_native_arbitrary_point_zero') is False and patch.get('full_global_v5_mesh_build_executed') is False and worker.get('arbitrary_point_native_equivalence_claim') is False and worker.get('GPU_executed') is False,'Renderer evidence cannot claim arbitrary-point/native/global/GPU equivalence'
    assert worker.get('terrain_revision')=='sphere-source-contact-v5' and worker.get('vertices',0)>0 and worker.get('source_query_count',0)>0,'Missing actual bounded v5 source-root worker packet evidence'
    return {'report':path,'report_sha256':hashlib.sha256(raw).hexdigest(),'checks':data['checks'],'failures':0,'source_hashes_match_actual_checkout':True,'v4_patch_checksum':CONTACT_ALIGNMENT_V4_PATCH_CHECKSUM,'v4_global_cache_key':CONTACT_ALIGNMENT_V4_GLOBAL_KEY,'v4_reference_source_commit':'abae633776275a88bf0706893a030e7497ae6ef0','renderer_tests_reexecuted_by_apk_verifier':False,'arbitrary_point_triangle_native_equivalence_proved':False}


def _verify_contact_alignment_preserved_functions(project,baseline):
    # The Main physical loop, save payload and source contact application do
    # not gain a new response path. The compatibility layer and preview bugfix
    # are independently pinned as actual code47 files, outside this subset.
    protected={
        'scripts/main.gd':['_tick','_source_contact_enabled','_source_contact_failed','_apply_pending_source_contact','_payload','_decode_state'],
        'scripts/surface_orbit_link.gd':['preferred_terrain_revision'],
        'scripts/source_surface_contact_patch.gd':['checksum_for'],
        'scripts/surface_visual.gd':['_bind_ground_material'],
        'scripts/celestial_renderer.gd':['source_light','_bind_body_material'],
    }
    checked={}
    for relative,functions in protected.items():
        current=(project/relative).read_text();previous=baseline['files'][relative]['source']
        for function in functions:
            old=source_function(previous,function);new=source_function(current,function)
            assert new==old,'Contact alignment changed protected physical/default/material function '+relative+'/'+function
            checked[relative+'/'+function]=hashlib.sha256(new.encode()).hexdigest()
    return checked


def _normalize_natural_main(main):
    preload='const NaturalContactProbe=preload("res://scripts/source_natural_contact_probe.gd")\n'
    diagnostic='\tsample["source_natural_probe"]=NaturalContactProbe.sample(world,ship,surface,nav.elapsed_days) if nav.is_source_hyperdrive() else {"ok":true,"reason":"legacy_navigation","diagnostic_only":true,"response_applied":false}\n'
    assert main.count(preload)==1 and main.count(diagnostic)==1,'Missing exact natural diagnostic-only Main additions'
    assert diagnostic in source_function(main,'_flight_diagnostic_sample'),'Natural probe must only run in diagnostic sampling'
    normalized=main.replace(preload,'',1).replace(diagnostic,'',1)
    assert hashlib.sha256(normalized.encode()).hexdigest()==SPHERICAL_CONTACT_AUDITED_SOURCE_SHA256['scripts/main.gd'],'Natural update changed physical/save/Main outside exact diagnostic normalization'
    return normalized


def _verify_natural_contact_resource(archive,project):
    names=set(archive.namelist());path='assets/data/ffe_natural_contact.json'
    assert path in names,'Missing natural-contact metadata resource'
    raw=archive.read(path)
    assert raw==(project/'data/ffe_natural_contact.json').read_bytes(),'Natural-contact resource differs from local source'
    data=json.loads(raw)
    assert data.get('schema')==1 and data.get('profile')=='dos-firstenc-natural-contact-v1','Wrong natural-contact extraction profile'
    assert data.get('source_sha256')==SOURCE_IMAGE_SHA256 and data.get('source_assembly_sha256')==SOURCE_ASSEMBLY_SHA256 and data.get('source_commit')==SOURCE_ASSEMBLY_COMMIT and data.get('source_data_sha256')=='34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850','Wrong natural-contact source provenance'
    immutable={'ffe_runtime_model_descriptors':SURFACE_CONTACT_RUNTIME_DESCRIPTOR_SHA256,'ffe_hyperdrive':HYPERDRIVE_RESOURCE_SHA256,'ffe_fuel':FUEL_RESOURCE_SHA256,'ffe_ground_collision':NATURAL_CONTACT_GROUND_RESOURCE_SHA256}
    assert data.get('immutable_resources')=={name+'_sha256':digest for name,digest in immutable.items()},'Natural extension changed retained resource digests'
    previous={}
    for name,digest in immutable.items():
        local=(project/'data'/f'{name}.json').read_bytes();exported='assets/data/'+name+'.json'
        assert exported in names and archive.read(exported)==local and hashlib.sha256(local).hexdigest()==digest,'Natural retained resource changed '+name
        previous[name]=json.loads(local)
    descriptors=previous['ffe_runtime_model_descriptors']['models'];specs=previous['ffe_hyperdrive']['ship_specs']
    ships=data.get('ship_models',{})
    assert set(ships)=={'15','24','38'},'Incomplete three-ship natural player domain'
    expected_children={'24':(0x8a2a8,'0000',[]),'38':(0x8d894,'00007805903379059033',[(13200,1401),(13200,1400)]),'15':(0x88dea,'0000840c803e',[(16000,3204)])}
    expected_radii={'24':(0,10400,5200),'38':(1,36000,9600),'15':(-2,4800,1920)}
    for key,row in ships.items():
        descriptor=bytes.fromhex(row.get('descriptor_hex',''));old=descriptors[key];spec=specs[key]
        assert len(descriptor)==68 and descriptor.hex()==old['descriptor_hex'] and row.get('descriptor_sha256')==old['descriptor_sha256'] and row.get('descriptor_file_offset')==old['descriptor_executable_offset'],'Natural ship descriptor mismatch '+key
        physical=bytes.fromhex(row.get('physical_spec_hex',''))
        assert len(physical)==24 and physical.hex()==spec['spec_hex'] and row.get('physical_spec_sha256')==spec['spec_sha256'] and hashlib.sha256(physical).hexdigest()==spec['spec_sha256'] and row.get('physical_spec_pointer_u32')==struct.unpack_from('<I',descriptor,0x38)[0] and row.get('physical_spec_file_offset')==spec['spec_file_offset'],'Natural ship physical specification mismatch '+key
        radius=row.get('f1533_radii',{})
        assert (radius.get('exponent_s32'),radius.get('outer_s64'),radius.get('inner_s64'))==expected_radii[key],'Natural ship positive F1533 radii mismatch '+key
        prefix=bytes.fromhex(row.get('collision_prefix_hex',''));pointer=struct.unpack_from('<I',descriptor,0x34)[0]
        assert row.get('collision_pointer_u32')==pointer and row.get('collision_file_offset')==pointer-0x416400 and len(prefix)==8 and hashlib.sha256(prefix).hexdigest()==row.get('collision_prefix_sha256'),'Natural ship original collision pointer/prefix mismatch '+key
        children=row.get('preceding_children',{});child_raw=bytes.fromhex(children.get('hex',''));at,expected_hex,pairs=expected_children[key]
        assert child_raw.hex()==expected_hex and children.get('file_offset')==at and children.get('byte_length')==len(child_raw) and at+len(child_raw)==row['collision_file_offset'] and children.get('terminator_file_offset')==at and children.get('terminator_s16')==0 and child_raw[:2]==b'\0\0' and hashlib.sha256(child_raw).hexdigest()==children.get('sha256'),'Natural player backwards child bytes mismatch '+key
        records=children.get('records',[])
        assert len(records)==len(pairs),'Natural player actual child count mismatch '+key
        for index,(offset,encoded) in enumerate(pairs):
            entry=records[index];word_at=len(child_raw)-2-index*4
            assert (struct.unpack_from('<h',child_raw,word_at)[0],struct.unpack_from('<h',child_raw,word_at-2)[0])==(offset,encoded),'Natural player child traversal mismatch '+key
            expected={'radius_s16':offset,'displacement_s16':offset,'axis_radius_encoded_s16':encoded,'axis_index':(encoded&6)//2,'axis_negative':bool(encoded&1),'radius_word_u16':encoded&0xfff8,'displacement_file_offset':at+word_at,'axis_radius_file_offset':at+word_at-2}
            assert entry==expected,'Natural player child axis/radius/offset mismatch '+key
    parents=data.get('natural_parent_programs',{})
    assert set(parents)=={str(i)for i in range(117,149)},'Incomplete32-natural parent resource domain'
    for key,row in parents.items():
        ground=int(key)<=133;name='ffe_ground_collision' if ground else 'ffe_fuel';original=previous[name]['models'][key]
        stream=bytes.fromhex(original['collision_bytes_hex' if ground else 'collision_stream_hex']);vertices=bytes.fromhex(original['vertices_hex']);descriptor=bytes.fromhex(descriptors[key]['descriptor_hex'])
        program=row.get('program',{});col=int(original['collision_offset' if ground else 'collision_stream_offset'],16)
        assert row.get('resource')==name and row.get('model_path')=='models.'+key and row.get('descriptor_sha256')==original['descriptor_sha256'] and row.get('vertices_sha256')==original['vertices_sha256'] and row.get('descriptor_file_offset')==descriptors[key]['descriptor_executable_offset'] and row.get('vertices_file_offset')==int(original['vertices_offset'],16),'Natural retained parent descriptor/vertices index mismatch '+key
        assert len(vertices)==24 and hashlib.sha256(vertices).hexdigest()==row['vertices_sha256'] and row.get('descriptor_zoom_s32')==struct.unpack_from('<I',descriptor,0x14)[0]+struct.unpack_from('<I',descriptor,0x18)[0] and row.get('non_spherical_source_model') is (key=='117'),'Natural source vertex/zoom/nonspherical provenance mismatch '+key
        assert stream[:3] in (bytes.fromhex('1082ff'),bytes.fromhex('1083ff')) and stream[-5:]==bytes.fromhex('5080000000') and program.get('byte_length')==len(stream) and program.get('sha256')==hashlib.sha256(stream).hexdigest() and program.get('collision_file_offset')==col,'Natural retained complete terrain program mismatch '+key
        end=9;features=[]
        while end+2<=len(stream) and struct.unpack_from('<H',stream,end)[0]:features.append(col+end);end+=16
        assert end+7==len(stream) and program.get('feature_count')==len(features) and program.get('feature_offsets')==features and program.get('feature_terminator_file_offset')==col+end and program.get('tail_file_offset')==col+end+2 and program.get('tail_hex')=='5080000000','Natural feature list/terminator/tail provenance mismatch '+key
        assert (program.get('opcode_u8'),program.get('primitive_flags_u8'),program.get('primitive_selector_u8'))==tuple(stream[:3]) and program.get('terrain_payload_file_offset')==col+3 and program.get('terrain_payload_byte_length')==end-1 and program.get('terrain_style_raw')==stream[7],'Natural opcode/payload provenance mismatch '+key
    assert data.get('field_layout',{}).get('object_bytes')==338 and data.get('field_layout',{}).get('descriptor_bytes')==68 and data.get('field_layout',{}).get('physical_spec_bytes')==24,'Natural original object/descriptor/spec sizes changed'
    assert hashlib.sha256(raw).hexdigest()==NATURAL_CONTACT_RESOURCE_SHA256,'Natural metadata differs from frozen DOS extraction'
    return data


def verify_natural_contact_runtime(archive,project):
    """Code46 data/source/asset controls, separate from native/Godot/device tests."""
    names=set(archive.namelist());compiled={}
    for relative in NATURAL_CONTACT_AUDITED_SOURCE_SHA256:
        name=Path(relative).stem;path='assets/scripts/'+name+'.gdc'
        assert path in names,'Missing natural-contact integration runtime '+name
        raw=archive.read(path)
        assert len(raw)>64 and raw[:4]==b'GDSC','Invalid compiled natural-contact integration runtime '+name
        compiled[name]=hashlib.sha256(raw).hexdigest()
    main=(project/'scripts/main.gd').read_text();normalized=_normalize_natural_main(main)
    for relative,digest in NATURAL_CONTACT_AUDITED_SOURCE_SHA256.items():
        assert hashlib.sha256((project/relative).read_bytes()).hexdigest()==digest,'Natural contact differs from audited integration source '+relative
    retained=_verify_spherical_contact_runtime(archive,project,normalized)
    data=_verify_natural_contact_resource(archive,project)
    core=(project/'scripts/source_natural_contact.gd').read_text();pipeline=(project/'scripts/source_natural_contact_pipeline.gd').read_text();probe=(project/'scripts/source_natural_contact_probe.gd').read_text()
    assert NATURAL_CONTACT_RESOURCE_SHA256 in core and 'FileAccess.get_sha256(DATA_PATH)!=DATA_SHA' in source_function(core,'ship_model') and 'preceding_children' in source_function(core,'ship_model'),'Natural core lacks immutable original child metadata consumer'
    assert 'Ground.model_resources(index)' in source_function(core,'parent_model') and 'Fuel.model(index)' in source_function(core,'parent_model'),'Natural core must reuse retained32-natural source resources'
    assert 'Natural.new().classify_natural_player(' in source_function(probe,'sample') and 'FileAccess.get_sha256(DATA_PATH)!=DATA_SHA' in source_function(probe,'sample') and NATURAL_CONTACT_RESOURCE_SHA256 in probe,'Natural read-only probe lacks immutable source classifier consumer'
    base=source_function(probe,'_base')
    assert all(token in base for token in ('"diagnostic_only":true','"response_applied":false','"source_object_bank_present":false','"live_collision_classifier_changed":false','"original_F575_dispatch_executed":false','"terrain_provider_queried":false','"mesh_source_height_alignment_proved":false')),'Natural phone probe must remain diagnostic-only without mesh-alignment/live-physics claims'
    assert 'source_natural_contact_pipeline' not in probe and 'Response.resolve_player(body,parent,' in source_function(pipeline,'_dispatch_classification') and '_classifier.classify_natural_player(' in source_function(pipeline,'resolve_natural_player'),'Standalone natural F575 composition must stay separate from phone diagnostics'
    fixture_raw=(project/'tests/fixtures/source_natural_contact_native.json').read_bytes();fixture=json.loads(fixture_raw)
    assert hashlib.sha256(fixture_raw).hexdigest()==NATURAL_CONTACT_NATIVE_REFERENCE_SHA256,'Changed natural native reference'
    assert fixture.get('schema')==1 and fixture.get('source_sha256')==SOURCE_IMAGE_SHA256 and fixture.get('source_assembly_sha256')==SOURCE_ASSEMBLY_SHA256 and fixture.get('source_commit')==SOURCE_ASSEMBLY_COMMIT and fixture.get('source_data_assembly_sha256')==data['source_data_sha256'],'Wrong natural native source provenance'
    cases=fixture.get('cases',[])
    assert fixture.get('case_count')==len(cases)==NATURAL_CONTACT_NATIVE_CASE_COUNT,'Wrong natural native case count'
    assert fixture.get('fresh_process_runs')==3 and fixture.get('reverse_repeat_count')==len(cases) and fixture.get('output_canaries_unchanged') is True and fixture.get('caller_buffers_unchanged') is True and fixture.get('native_expected_arithmetic_in_python') is False,'Incomplete independent natural native execution checks'
    assert fixture.get('dos_jjffe_behavior_differences')==[],'Unreviewed natural DOS/JJFFE behavior difference'
    proofs=fixture.get('byte_instruction_proofs',{})
    assert set(NATURAL_CONTACT_PRIMARY_PROOFS)<=set(proofs),'Incomplete natural primary instruction proof domain'
    for key,expected in NATURAL_CONTACT_PRIMARY_PROOFS.items():
        row=proofs[key]
        assert (row.get('executable_offset'),row.get('byte_length'),row.get('sha256'),row.get('instruction_count'))==expected and row.get('all_instructions_equal') is True,'Changed natural primary instruction proof '+key
    for key,row in proofs.items():
        assert row.get('all_instructions_equal') is True and row.get('virtual_address')==row.get('executable_offset',-1)+0x40f200 and row.get('byte_length',0)>0 and row.get('instruction_count',0)>0,'Incomplete natural static helper proof '+key
    assert {int(row['parent_model'])for row in cases}==set(range(117,149)) and {int(row['player_model'])for row in cases}=={15,24,38},'Incomplete natural native parent/player domain'
    resources=fixture.get('original_model_resources',{})
    assert set(resources)=={str(n)for n in [15,24,38,*range(117,149)]},'Incomplete natural native original resource domain'
    for key,row in data['ship_models'].items():
        original=resources[key]
        assert original.get('descriptor_hex')==row['descriptor_hex'] and original.get('preceding_children_hex')==row['preceding_children']['hex'] and original.get('physical_spec_hex','')[:48]==row['physical_spec_hex'],'Native natural player resource differs from frozen metadata '+key
    traps=fixture.get('host_trap_codes',{})
    assert 'FUNC_000580' in traps.values() and 'FUNC_000583' in traps.values(),'Natural general/nested/plane VM must remain explicit native traps'
    interceptions=fixture.get('unsupported_vm_interceptions',[])
    assert fixture.get('unsupported_vm_interception_count')==len(interceptions)==2 and {row.get('intercepted_original_callee')for row in interceptions}=={'FUNC_000580','FUNC_000583'},'Natural native unsupported VM interceptions must remain separate from supported cases'
    assert all(row.get('separate_from_supported_natural_cases') is True and row.get('completed_output_records')==0 and row.get('expected_native_exit_status') in (100,101)for row in interceptions),'Unreviewed natural native VM abort interception'
    reference={'sha256':NATURAL_CONTACT_NATIVE_REFERENCE_SHA256,'case_count':len(cases),'supported_case_count':len(cases),'separate_unsupported_VM_abort_interception_count':2,'static_instruction_proof_count':len(proofs),'static_instruction_proof_bytes':sum(row['byte_length']for row in proofs.values()),'static_instruction_proof_instructions':sum(row['instruction_count']for row in proofs.values()),'executed_primary_procedures':['576','579','581','582'],'general_nested_and_plane_VM_executed':False,'oracle_executed_by_apk_verifier':False}
    return {'baseline_source_commit':NATURAL_CONTACT_BASELINE_SOURCE_COMMIT,'compiled_modules':{name:compiled[name]for name in NATURAL_CONTACT_MODULES},'compiled_module_count':3,'integration_compiled_modules':compiled,'integration_compiled_module_count':len(compiled),'audited_local_source_sha256':NATURAL_CONTACT_AUDITED_SOURCE_SHA256,
        'raw_resource_sha256':NATURAL_CONTACT_RESOURCE_SHA256,'raw_json_count':1,'new_json_runtime_lookup_required':True,'ship_model_count':3,'natural_parent_model_count':32,'source_player_child_counts':{key:len(row['preceding_children']['records'])for key,row in data['ship_models'].items()},'unchanged_code45_source_count':25,
        'whole_Main_normalization_sha256':SPHERICAL_CONTACT_AUDITED_SOURCE_SHA256['scripts/main.gd'],'actual_Main_sha256':NATURAL_CONTACT_AUDITED_SOURCE_SHA256['scripts/main.gd'],'Main_normalization_policy':'Exactly one new probe preload and diagnostic line removed; every remaining byte equals code45. Retained strict45 report audits that virtual Main, while actual46 Main is separately pinned.','retained_spherical_contact_assets':retained,'native_reference':reference,
        'actual_Main_probe_readonly':True,'physical_response_changed_by_probe':False,'source_field_is_phone_AGL':False,'mesh_source_height_alignment_proved':False,'independent_native_natural_F575_pipeline_executed':False,'full_F569_F570_engine':False,'general_F580_F583_VM':False,'full_original_world_object_bank':False,'complete_original_physics':False,'compiled_source_correspondence_rebuilt_by_verifier':False,'physical_device_tested':False}


def verify_contact_alignment_runtime(archive,project):
    """Code47 actual assets/pins plus explicitly separated historical source audit."""
    names=set(archive.namelist());compiled={}
    for relative in CONTACT_ALIGNMENT_AUDITED_SOURCE_SHA256:
        name=Path(relative).stem;path='assets/scripts/'+name+'.gdc'
        assert path in names,'Missing contact-alignment integration runtime '+name
        raw=archive.read(path)
        assert len(raw)>64 and raw[:4]==b'GDSC','Invalid compiled contact-alignment integration runtime '+name
        compiled[name]=hashlib.sha256(raw).hexdigest()
    for relative,digest in CONTACT_ALIGNMENT_AUDITED_SOURCE_SHA256.items():
        assert hashlib.sha256((project/relative).read_bytes()).hexdigest()==digest,'Contact alignment differs from audited integration source '+relative
    kernels={}
    for relative,digest in CONTACT_ALIGNMENT_PROTECTED_KERNEL_DATA_SHA256.items():
        raw=(project/relative).read_bytes()
        assert hashlib.sha256(raw).hexdigest()==digest,'Contact alignment changed protected original kernel/data '+relative
        if relative.startswith('data/'):
            assert 'assets/'+relative in names and archive.read('assets/'+relative)==raw,'Contact alignment exported protected data differs '+relative
        else:
            path='assets/scripts/'+Path(relative).stem+'.gdc'
            assert path in names,'Missing contact-alignment original kernel runtime '+relative
            exported=archive.read(path)
            assert len(exported)>64 and exported[:4]==b'GDSC','Invalid compiled contact-alignment original kernel '+relative
            kernels[Path(relative).stem]=hashlib.sha256(exported).hexdigest()
    baseline=_load_contact_alignment_baseline(project)
    preserved=_verify_contact_alignment_preserved_functions(project,baseline)
    native=_verify_contact_field_native_reference(project)
    renderer=_verify_contact_alignment_v4_evidence(project)
    source={name:(project/'scripts'/f'{name}.gd').read_text()for name in (*CONTACT_ALIGNMENT_MODULES,'main','surface_model','surface_orbit_link','celestial_renderer')}
    main=source['main'];probe=source['source_contact_alignment_probe'];bridge=source['source_natural_surface_bridge'];terrain=source['source_contact_surface_terrain']
    assert 'ContactAlignmentProbe.sample(surface,ship)' in source_function(main,'_show_surface_alignment') and 'source_alignment_last' in source_function(main,'_flight_diagnostic_sample'),'Explicit surface comparison menu/report consumer is disconnected'
    assert 'source_natural_surface_bridge.gd' not in main and 'source_alignment_last' not in source_function(main,'_payload'),'Surface comparison must not add Main natural response or game-save state'
    assert '"diagnostic_only":true' in source_function(probe,'_base') and '"response_applied":false' in source_function(probe,'_base') and '"interpolated_points_certified":false' in source_function(probe,'_base') and '"explicit_user_command_only":true' in source_function(probe,'_base'),'Surface comparison must stay explicit and read-only without interpolation certification'
    assert 'guard==measured' in source_function(bridge,'eligibility') and '"whole_triangle_certified":false' in source_function(bridge,'eligibility') and '"live_response_enabled":false' in source_function(bridge,'eligibility'),'Natural surface candidate requires a freshly recomputed local guard, not a whole-triangle/live grant'
    geometry=source_function(bridge,'_geometry')
    assert 'if residual==0:' in geometry and 'boundary.position_raw==raw' in geometry and 'boundary.source_bounds.terrain_query_eligible==true' in geometry,'Visible point must equal an exact source zero or exact admitted integer boundary, not a tolerance'
    assert '"sampled_nodes_certified_against_signed_F581"' in terrain and '"interpolated_points_certified_against_F581"' in terrain and 'BaseTerrain.SAMPLE_POLICY' in terrain,'Signed-field terrain must preserve v4 seed provenance and separate nodes from interpolation'
    assert '_source_terrain_revision:=SourceGlobalMesh.Terrain.REVISION_NAME' in source['celestial_renderer'],'Ordinary celestial geometry must keep its v4 default'
    # Existing gates remain strict against actual47. This view restores only
    # nine permitted host source-history entries; it passes the SAME archive
    # object and never substitutes, synthesizes or rewrites compiled assets.
    changed=[*CONTACT_ALIGNMENT_PROVIDER_SOURCE_SHA256,'scripts/main.gd','scripts/surface_model.gd','scripts/surface_orbit_link.gd']
    overrides={relative:baseline['files'][relative]['source']for relative in changed}
    retained=verify_natural_contact_runtime(archive,_AlignmentSourceAuditPath(project,overrides))
    audit={'source_override_count':len(overrides),'source_override_paths':changed,'compiled_assets_substituted':False,'audit_is_actual_unchanged_code46_runtime':False,'description':'Host code46 source-history/data checks only, after separate actual47 source pins and current v4 checksum/default regressions. All compiled hashes below are read from the actual code47 archive; no old compiled assets are substituted.','assets':retained}
    return {'baseline_source_commit':CONTACT_ALIGNMENT_BASELINE_SOURCE_COMMIT,'baseline_fixture_sha256':CONTACT_ALIGNMENT_BASELINE_FIXTURE_SHA256,'baseline_fixture_source_count':36,'compiled_modules':{name:compiled[name]for name in CONTACT_ALIGNMENT_MODULES},'compiled_module_count':4,'integration_compiled_modules':compiled,'integration_compiled_module_count':len(compiled),'audited_local_source_sha256':CONTACT_ALIGNMENT_AUDITED_SOURCE_SHA256,'protected_original_kernel_compiled_modules':kernels,
        'raw_json_count':0,'new_runtime_JSON_added':False,'unchanged_code46_runtime_source_count':27,'actual_runtime_is_unchanged_code46':False,'preserved_physical_default_material_functions':preserved,'preserved_physical_default_material_function_count':len(preserved),'native_field_reference':native,'v4_renderer_regression':renderer,'retained_code46_source_audit':audit,
        'v4_is_default_physical_terrain':True,'v5_geometry_is_explicit_opt_in':True,'Main_new_natural_response_branch':False,'new_alignment_data_persisted_in_game_save':False,'geometry_guard_is_local_point_only':True,'whole_interpolated_triangle_certified':False,'independent_native_F575_coupled_pipeline_executed':False,'full_original_world_bank':False,'complete_original_physics':False,'compiled_source_correspondence_rebuilt_by_verifier':False,'physical_device_tested':False}


def verify(apk,build_tools,presets,smoke=False,allow_debuggable=False):
    expected=preset_values(presets)
    signature=run(build_tools/'apksigner','verify','--verbose','--print-certs',apk)
    assert 'CN=StarFrontier Rebuild TEST' in signature,'Unexpected signing identity for the TEST rebuild channel'
    run(build_tools/'zipalign','-c','-P','16','4',apk)
    badging=run(build_tools/'aapt','dump','badging',apk)
    permissions=run(build_tools/'aapt','dump','permissions',apk)
    assert "name='"+expected['package']+"'" in badging,'Wrong Android package'
    assert "versionCode='"+str(expected['version_code'])+"'" in badging,'Wrong Android version code'
    assert "versionName='"+expected['version']+"'" in badging,'Wrong Android version'
    assert "sdkVersion:'24'" in badging,'Unexpected minimum Android SDK'
    target=int(re.search(r"targetSdkVersion:'(\d+)'",badging)[1])
    assert target>=35,'Android target SDK is too old for this rebuild'
    debuggable='application-debuggable' in badging
    assert allow_debuggable or not debuggable,'Debuggable APK is not a candidate'
    for permission in FORBIDDEN_PERMISSIONS:
        assert 'android.permission.'+permission not in permissions,'Unexpected permission '+permission
    certificate=re.search(r'Signer #1 certificate SHA-256 digest: (\w+)',signature)[1]
    libraries={};native_assets={};graphics_assets={};diagnostic_assets={};material_assets={};surface_detail_assets={};flight_ui_assets={};city_surface_assets={};world_surface_assets={};source_world_assets={};source_orbit_assets={};source_physics_ports_assets={};source_full_assets={};classic_console_assets={};mining_kernel_assets={};navigation_assets={};map_visual_assets={};celestial_visibility_assets={};system_information_assets={};hyperdrive_assets={};fuel_assets={};atmosphere_assets={};landing_gear_assets={};surface_contact_assets={};spherical_contact_assets={};natural_contact_assets={};contact_alignment_assets={}
    with zipfile.ZipFile(apk) as archive:
        assert archive.testzip() is None,'APK ZIP CRC failure'
        names=archive.namelist()
        assert sorted({n.split('/')[1] for n in names if n.startswith('lib/')})==['arm64-v8a'],'APK is not ARM64-only'
        assert not any(n.lower().endswith(('.exe','.asm','.keystore','.jks','.argosmodel')) for n in names),'Non-runtime/secret file in APK'
        assert not any(n.startswith(DEVELOPMENT_ASSET_PREFIXES) for n in names),'Development history included in APK'
        if not smoke:
            for name in ['ffe_worlds','ffe_world_models','ffe_ship_registry','ffe_ground_coordinates','ffe_ground_pads']:
                path='assets/data/'+name+'.json'
                assert path in names,'Missing native data asset '+name
                native_assets[name]=json.loads(archive.read(path))
            assert len(native_assets['ffe_worlds']['systems'])==11
            assert {int(s['index']) for s in native_assets['ffe_ship_registry']['ships']}==set(range(15,72))
            assert len(native_assets['ffe_ground_coordinates']['sin_quarter_q31'])==16384
            world_models=native_assets['ffe_world_models']
            assert world_models['source_sha256']==SOURCE_IMAGE_SHA256
            assert all(str(i) in world_models['models'] for i in range(81,91))
            if expected['version_code']>=23:
                required_graphics=['ship_visual.gdc','ship_hull.gdshader','ship_exhaust.gdshader','ship_halo.gdshader','station_visual.gdc','station_solar.gdshader','space_environment.gdc','asteroid_surface.gdshader','space_sky.gdshader','flight_theme.gdc','flight_reticle.gdc']
                for name in required_graphics:
                    path='assets/scripts/'+name
                    assert path in names,'Missing graphics runtime asset '+name
                    packed=archive.read(path)
                    assert len(packed)>64,'Empty graphics runtime asset '+name
                    if name.endswith('.gdshader'):
                        assert packed==(presets.parent/'scripts'/name).read_bytes(),'Graphics shader differs from current source '+name
                    graphics_assets[name]=hashlib.sha256(packed).hexdigest()
            if expected['version_code']>=24:
                build_info=(presets.parent/'scripts/build_info.gd').read_text()
                version=re.search(r'^const VERSION\s*:=\s*"([^"]+)"\s*$',build_info,re.M)
                code=re.search(r'^const VERSION_CODE\s*:=\s*(\d+)\s*$',build_info,re.M)
                assert version and version[1]==expected['version'],'Diagnostic runtime version differs from APK version'
                assert code and int(code[1])==expected['version_code'],'Diagnostic runtime code differs from APK code'
                for name in ['build_info.gdc','game_diagnostics.gdc','diagnostics_logger.gdc','report_export.gdc']:
                    path='assets/scripts/'+name
                    assert path in names and len(archive.read(path))>64,'Missing diagnostics runtime asset '+name
                    diagnostic_assets[name]=hashlib.sha256(archive.read(path)).hexdigest()
            if expected['version_code']>=25:
                material_assets=verify_material_assets(archive,presets.parent)
            if expected['version_code']>=26:
                surface_detail_assets=verify_surface_details(archive,presets.parent)
            if expected['version_code']>=27:
                for name in ['flight_console.gdc','touch_action_button.gdc','main.gdc','surface_model.gdc']:
                    path='assets/scripts/'+name
                    assert path in names and len(archive.read(path))>64,'Missing flight control runtime '+name
                    flight_ui_assets[name]=hashlib.sha256(archive.read(path)).hexdigest()
            if expected['version_code']>=28:
                for name in ['dock_services_view.gdc','training_dock_services.gdc','navigation.gdc']:
                    path='assets/scripts/'+name
                    assert path in names and len(archive.read(path))>64,'Missing dock service runtime '+name
                    flight_ui_assets[name]=hashlib.sha256(archive.read(path)).hexdigest()
            if expected['version_code']>=29:
                city_surface_assets=verify_city_surfaces(archive,presets.parent)
                assert material_assets['map_count']+surface_detail_assets['map_count']+city_surface_assets['map_count']==39,'Incomplete runtime material map collection'
            if expected['version_code']>=30:
                world_surface_assets=verify_world_surfaces(archive,presets.parent)
                assert material_assets['map_count']+surface_detail_assets['map_count']+city_surface_assets['map_count']+world_surface_assets['map_count']==51,'Incomplete terrain/planet runtime material collection'
            if expected['version_code']>=31:
                source_world_assets=verify_source_world_runtime(archive,presets.parent)
            if expected['version_code']>=32:
                source_orbit_assets=verify_source_orbit_runtime(archive,presets.parent,expected['version_code'])
            if expected['version_code']>=33:
                source_physics_ports_assets=verify_source_physics_ports_runtime(archive,presets.parent,expected['version_code'])
            if expected['version_code']>=34:
                source_full_assets=verify_source_full_runtime(archive,presets.parent,expected['version_code'])
            if expected['version_code']>=35:
                classic_console_assets=verify_classic_console_runtime(archive,presets.parent)
                mining_kernel_assets=verify_mining_kernel_runtime(archive,presets.parent)
            if expected['version_code']>=36:
                navigation_assets=verify_navigation_runtime(archive,presets.parent)
            if expected['version_code']==37:
                map_visual_assets=verify_map_visual_runtime(archive,presets.parent)
            if expected['version_code']==38:
                celestial_visibility_assets=verify_celestial_visibility_runtime(archive,presets.parent)
                map_visual_assets=celestial_visibility_assets['galactic_map_visual_assets']
            if expected['version_code']==39:
                system_information_assets=verify_system_information_runtime(archive,presets.parent)
                map_visual_assets=system_information_assets['galactic_map_visual_assets']
            if expected['version_code']==40:
                hyperdrive_assets=verify_hyperdrive_runtime(archive,presets.parent)
                system_information_assets={'resources':hyperdrive_assets['system_information_resources'],'unchanged_runtime_modules':3,'raw_original_and_ru_resources_checked':True}
            if expected['version_code']==41:
                fuel_assets=verify_fuel_runtime(archive,presets.parent)
                hyperdrive_assets={'raw_resource_sha256':fuel_assets['unchanged_hyperdrive_resource_sha256'],'compiled_module_count':fuel_assets['retained_hyperdrive_compiled_module_count'],'retained_by_strict_fuel_gate':True,'source_f903_live_quote_consumers_checked':True}
                system_information_assets={'resources':fuel_assets['unchanged_information_resources'],'unchanged_runtime_modules':3,'raw_original_and_ru_resources_checked':True}
            if expected['version_code']==42:
                atmosphere_assets=verify_atmosphere_runtime(archive,presets.parent)
                fuel_assets={'raw_resource_sha256':atmosphere_assets['unchanged_fuel_resource_sha256'],'compiled_module_count':atmosphere_assets['retained_fuel_compiled_module_count'],'retained_by_strict_atmosphere_gate':True,'native_references':atmosphere_assets['retained_fuel_native_references']}
                hyperdrive_assets={'raw_resource_sha256':atmosphere_assets['unchanged_hyperdrive_resource_sha256'],'compiled_module_count':atmosphere_assets['retained_hyperdrive_compiled_module_count'],'retained_by_strict_atmosphere_gate':True,'source_f903_live_quote_consumers_checked':True}
                system_information_assets={'resources':atmosphere_assets['unchanged_information_resources'],'unchanged_runtime_modules':3,'raw_original_and_ru_resources_checked':True}
            if expected['version_code']==43:
                landing_gear_assets=verify_landing_gear_runtime(archive,presets.parent)
                atmosphere_assets={'raw_resource_sha256':landing_gear_assets['unchanged_atmosphere_resource_sha256'],'compiled_module_count':landing_gear_assets['retained_atmosphere_compiled_module_count'],'retained_by_strict_landing_gear_gate':True,'native_references':landing_gear_assets['retained_atmosphere_native_references']}
                fuel_assets={'raw_resource_sha256':landing_gear_assets['unchanged_fuel_resource_sha256'],'compiled_module_count':landing_gear_assets['retained_fuel_compiled_module_count'],'retained_by_strict_landing_gear_gate':True,'native_references':landing_gear_assets['retained_fuel_native_references']}
                hyperdrive_assets={'raw_resource_sha256':landing_gear_assets['unchanged_hyperdrive_resource_sha256'],'compiled_module_count':landing_gear_assets['retained_hyperdrive_compiled_module_count'],'retained_by_strict_landing_gear_gate':True,'source_f903_live_quote_consumers_checked':True}
                system_information_assets={'resources':landing_gear_assets['unchanged_information_resources'],'unchanged_runtime_modules':3,'raw_original_and_ru_resources_checked':True}
            if expected['version_code']==44:
                surface_contact_assets=verify_surface_contact_runtime(archive,presets.parent)
            if expected['version_code']==45:
                spherical_contact_assets=verify_spherical_contact_runtime(archive,presets.parent)
                surface_contact_assets=spherical_contact_assets['retained_surface_contact_assets']
            if expected['version_code']==46:
                natural_contact_assets=verify_natural_contact_runtime(archive,presets.parent)
                spherical_contact_assets=natural_contact_assets['retained_spherical_contact_assets']
                surface_contact_assets=spherical_contact_assets['retained_surface_contact_assets']
            if expected['version_code']>=47:
                contact_alignment_assets=verify_contact_alignment_runtime(archive,presets.parent)
                natural_contact_assets={**contact_alignment_assets['retained_code46_source_audit']['assets'],'host_source_history_audit_only':True,'actual_runtime_is_unchanged_code46':False}
                spherical_contact_assets={**natural_contact_assets['retained_spherical_contact_assets'],'host_source_history_audit_only':True}
                surface_contact_assets={**spherical_contact_assets['retained_surface_contact_assets'],'host_source_history_audit_only':True}
            if expected['version_code']>=44:
                landing_gear_assets={'raw_resource_sha256':surface_contact_assets['unchanged_landing_gear_resource_sha256'],'compiled_module_count':surface_contact_assets['retained_landing_gear_compiled_module_count'],'retained_by_strict_surface_contact_gate':True}
                atmosphere_assets={'raw_resource_sha256':surface_contact_assets['unchanged_atmosphere_resource_sha256'],'compiled_module_count':surface_contact_assets['retained_atmosphere_compiled_module_count'],'retained_by_strict_surface_contact_gate':True,'native_references':surface_contact_assets['retained_atmosphere_native_references']}
                fuel_assets={'raw_resource_sha256':surface_contact_assets['unchanged_fuel_resource_sha256'],'compiled_module_count':surface_contact_assets['retained_fuel_compiled_module_count'],'retained_by_strict_surface_contact_gate':True,'native_references':surface_contact_assets['retained_fuel_native_references']}
                hyperdrive_assets={'raw_resource_sha256':surface_contact_assets['unchanged_hyperdrive_resource_sha256'],'compiled_module_count':surface_contact_assets['retained_hyperdrive_compiled_module_count'],'retained_by_strict_surface_contact_gate':True,'source_f903_live_quote_consumers_checked':True}
                system_information_assets={'resources':surface_contact_assets['unchanged_information_resources'],'unchanged_runtime_modules':3,'raw_original_and_ru_resources_checked':True}
        for name in names:
            if not name.startswith('lib/') or not name.endswith('.so'):continue
            data=archive.read(name)
            assert data[:5]==b'\x7fELF\x02','Native library must be ELF64'
            assert struct.unpack_from('<H',data,18)[0]==183,'Native library must be AArch64'
            start=struct.unpack_from('<Q',data,32)[0]
            size,count=struct.unpack_from('<HH',data,54)
            aligns=[]
            for index in range(count):
                header=struct.unpack_from('<IIQQQQQQ',data,start+index*size)
                if header[0]==1:
                    assert header[7]>=16384,'ELF LOAD alignment is below16K'
                    assert header[2]%header[7]==header[3]%header[7],'Invalid ELF LOAD offset alignment'
                    aligns.append(header[7])
            assert aligns
            libraries[name]=aligns
    assert libraries,'APK has no native ARM64 library'
    return {**expected,'apk':apk.name,'bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'abi':'arm64-v8a','min_sdk':24,'target_sdk':target,'signature_verified':True,'certificate_sha256':certificate,'test_key_only':True,'zipalign_16k':True,'elf_load_alignment':libraries,'forbidden_permissions_absent':True,'debuggable':debuggable,'native_data_checked':not smoke,'native_data_assets':sorted(native_assets),'graphics_runtime_assets_sha256':graphics_assets,'diagnostics_runtime_assets_sha256':diagnostic_assets,'material_assets':material_assets,'surface_detail_assets':surface_detail_assets,'city_surface_assets':city_surface_assets,'world_surface_assets':world_surface_assets,'source_world_runtime_assets':source_world_assets,'source_orbit_runtime_assets':source_orbit_assets,'source_physics_ports_runtime_assets':source_physics_ports_assets,'source_full_runtime_assets':source_full_assets,'classic_console_runtime_assets':classic_console_assets,'source_mining_kernel_assets':mining_kernel_assets,'navigation_runtime_assets':navigation_assets,'galactic_map_visual_assets':map_visual_assets,'celestial_visibility_assets':celestial_visibility_assets,'system_information_assets':system_information_assets,'hyperdrive_assets':hyperdrive_assets,'fuel_assets':fuel_assets,'atmosphere_assets':atmosphere_assets,'landing_gear_assets':landing_gear_assets,'surface_contact_assets':surface_contact_assets,'spherical_contact_assets':spherical_contact_assets,'natural_contact_assets':natural_contact_assets,'contact_alignment_assets':contact_alignment_assets,'runtime_material_map_count':sum(v.get('map_count',0) for v in [material_assets,surface_detail_assets,city_surface_assets,world_surface_assets]),'flight_ui_runtime_assets_sha256':flight_ui_assets,'toolchain_smoke_only':smoke,'physical_device_tested':False,'full_original_port_complete':False,'production_signing_key_configured':False,'publication_ready':False}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('apk',type=Path);p.add_argument('report',type=Path)
    p.add_argument('--build-tools',type=Path,default=Path('/workspace/toolchains/android-sdk/build-tools/36.0.0'))
    p.add_argument('--presets',type=Path,default=Path(__file__).resolve().parents[1]/'export_presets.cfg')
    p.add_argument('--smoke',action='store_true',help='Only for the separate minimal toolchain test project')
    p.add_argument('--allow-debuggable',action='store_true')
    a=p.parse_args();result=verify(a.apk,a.build_tools,a.presets,a.smoke,a.allow_debuggable)
    a.report.parent.mkdir(parents=True,exist_ok=True);a.report.write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
    print(json.dumps(result,indent=2,ensure_ascii=False))

if __name__=='__main__':main()
