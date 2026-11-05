#!/usr/bin/env python3
"""Verify the rebuilt ARM64 APK; technical success is not full FFE readiness."""
from __future__ import annotations
import argparse,hashlib,json,re,struct,subprocess,zipfile
from pathlib import Path

FORBIDDEN_PERMISSIONS=['INTERNET','RECORD_AUDIO','READ_EXTERNAL_STORAGE','WRITE_EXTERNAL_STORAGE','MANAGE_EXTERNAL_STORAGE']
SOURCE_IMAGE_SHA256='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'
MATERIAL_KINDS=('painted_alloy','brushed_metal','concrete','asphalt','rock','ice','rubber','glass')
MATERIAL_CHANNELS=('albedo','normal','orm')
SURFACE_PROFILES=('cobra','eagle','shuttle')

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
    libraries={};native_assets={};graphics_assets={};diagnostic_assets={};material_assets={};surface_detail_assets={};flight_ui_assets={}
    with zipfile.ZipFile(apk) as archive:
        assert archive.testzip() is None,'APK ZIP CRC failure'
        names=archive.namelist()
        assert sorted({n.split('/')[1] for n in names if n.startswith('lib/')})==['arm64-v8a'],'APK is not ARM64-only'
        assert not any(n.lower().endswith(('.exe','.asm','.keystore','.jks','.argosmodel')) for n in names),'Non-runtime/secret file in APK'
        forbidden=['assets/tests/','assets/tools/','assets/docs/','assets/recovered-history/','assets/recovery/','assets/validation/','assets/deliverables/','assets/localization/','assets/build/']
        assert not any(n.startswith(tuple(forbidden)) for n in names),'Development history included in APK'
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
    return {**expected,'apk':apk.name,'bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'abi':'arm64-v8a','min_sdk':24,'target_sdk':target,'signature_verified':True,'certificate_sha256':certificate,'test_key_only':True,'zipalign_16k':True,'elf_load_alignment':libraries,'forbidden_permissions_absent':True,'debuggable':debuggable,'native_data_checked':not smoke,'native_data_assets':sorted(native_assets),'graphics_runtime_assets_sha256':graphics_assets,'diagnostics_runtime_assets_sha256':diagnostic_assets,'material_assets':material_assets,'surface_detail_assets':surface_detail_assets,'flight_ui_runtime_assets_sha256':flight_ui_assets,'toolchain_smoke_only':smoke,'physical_device_tested':False,'full_original_port_complete':False,'production_signing_key_configured':False,'publication_ready':False}

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
