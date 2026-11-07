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
DEVELOPMENT_ASSET_PREFIXES=(
    'assets/tests/','assets/tools/','assets/docs/','assets/recovered-history/',
    'assets/recovery/','assets/validation/','assets/deliverables/',
    'assets/localization/','assets/build/',
)

def run(*command):
    return subprocess.check_output([str(v) for v in command],text=True,stderr=subprocess.STDOUT)

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
    required_tables=FULL_SOURCE_TABLES+(NAVIGATION_TABLES if version_code>=36 else ())
    present_tables=set(path.stem for path in (project/'data').glob('ffe_*.json'))
    # Older contracts still inspect their exact base tables when tested from a
    # newer checkout. Only explicitly known later-version tables may coexist;
    # current v36 must include and verify its additional original map resource.
    assert set(required_tables)<=present_tables<=set(FULL_SOURCE_TABLES+NAVIGATION_TABLES+('ffe_system_information',)),'Full packaging verifier list omits a source table or names a missing table'
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

def verify_system_information_runtime(archive,project):
    """Require actual information consumers/data while preserving flight logic.

    This verifies package/source inputs and narrowly allowed UI hooks; original
    instruction controls, translation review, Main behavior and GPU are separate.
    """
    protected={path:value for path,value in MAP_VISUAL_PROTECTED_SOURCE_SHA256.items()
               if path not in ('scripts/main.gd','scripts/system_map_view.gd')}
    map_assets=_verify_map_visual_contract(archive,project,protected,SYSTEM_INFORMATION_BASELINE_SOURCE_COMMIT)
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
    libraries={};native_assets={};graphics_assets={};diagnostic_assets={};material_assets={};surface_detail_assets={};flight_ui_assets={};city_surface_assets={};world_surface_assets={};source_world_assets={};source_orbit_assets={};source_physics_ports_assets={};source_full_assets={};classic_console_assets={};mining_kernel_assets={};navigation_assets={};map_visual_assets={};celestial_visibility_assets={};system_information_assets={}
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
            if expected['version_code']>=39:
                system_information_assets=verify_system_information_runtime(archive,presets.parent)
                map_visual_assets=system_information_assets['galactic_map_visual_assets']
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
    return {**expected,'apk':apk.name,'bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'abi':'arm64-v8a','min_sdk':24,'target_sdk':target,'signature_verified':True,'certificate_sha256':certificate,'test_key_only':True,'zipalign_16k':True,'elf_load_alignment':libraries,'forbidden_permissions_absent':True,'debuggable':debuggable,'native_data_checked':not smoke,'native_data_assets':sorted(native_assets),'graphics_runtime_assets_sha256':graphics_assets,'diagnostics_runtime_assets_sha256':diagnostic_assets,'material_assets':material_assets,'surface_detail_assets':surface_detail_assets,'city_surface_assets':city_surface_assets,'world_surface_assets':world_surface_assets,'source_world_runtime_assets':source_world_assets,'source_orbit_runtime_assets':source_orbit_assets,'source_physics_ports_runtime_assets':source_physics_ports_assets,'source_full_runtime_assets':source_full_assets,'classic_console_runtime_assets':classic_console_assets,'source_mining_kernel_assets':mining_kernel_assets,'navigation_runtime_assets':navigation_assets,'galactic_map_visual_assets':map_visual_assets,'celestial_visibility_assets':celestial_visibility_assets,'system_information_assets':system_information_assets,'runtime_material_map_count':sum(v.get('map_count',0) for v in [material_assets,surface_detail_assets,city_surface_assets,world_surface_assets]),'flight_ui_runtime_assets_sha256':flight_ui_assets,'toolchain_smoke_only':smoke,'physical_device_tested':False,'full_original_port_complete':False,'production_signing_key_configured':False,'publication_ready':False}

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
