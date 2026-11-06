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
    'source_surface_render_packet','source_surface_render_state','surface_visual',
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
    found=re.search(r'^(?:static\s+)?func\s+'+re.escape(name)+r'\([^\n]*\)[^\n]*:\s*\n',text,re.M)
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

def verify_source_full_runtime(archive,project):
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
    assert set(path.stem for path in (project/'data').glob('ffe_*.json'))==set(FULL_SOURCE_TABLES),'Full packaging verifier list omits a source table or names a missing table'
    tables={}
    for name in FULL_SOURCE_TABLES+('ships','world_names_ru'):
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
    return result

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
    libraries={};native_assets={};graphics_assets={};diagnostic_assets={};material_assets={};surface_detail_assets={};flight_ui_assets={};city_surface_assets={};world_surface_assets={};source_world_assets={};source_orbit_assets={};source_physics_ports_assets={};source_full_assets={}
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
                source_full_assets=verify_source_full_runtime(archive,presets.parent)
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
    return {**expected,'apk':apk.name,'bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'abi':'arm64-v8a','min_sdk':24,'target_sdk':target,'signature_verified':True,'certificate_sha256':certificate,'test_key_only':True,'zipalign_16k':True,'elf_load_alignment':libraries,'forbidden_permissions_absent':True,'debuggable':debuggable,'native_data_checked':not smoke,'native_data_assets':sorted(native_assets),'graphics_runtime_assets_sha256':graphics_assets,'diagnostics_runtime_assets_sha256':diagnostic_assets,'material_assets':material_assets,'surface_detail_assets':surface_detail_assets,'city_surface_assets':city_surface_assets,'world_surface_assets':world_surface_assets,'source_world_runtime_assets':source_world_assets,'source_orbit_runtime_assets':source_orbit_assets,'source_physics_ports_runtime_assets':source_physics_ports_assets,'source_full_runtime_assets':source_full_assets,'runtime_material_map_count':sum(v.get('map_count',0) for v in [material_assets,surface_detail_assets,city_surface_assets,world_surface_assets]),'flight_ui_runtime_assets_sha256':flight_ui_assets,'toolchain_smoke_only':smoke,'physical_device_tested':False,'full_original_port_complete':False,'production_signing_key_configured':False,'publication_ready':False}

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
