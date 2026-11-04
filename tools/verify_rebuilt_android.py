#!/usr/bin/env python3
"""Verify the rebuilt ARM64 APK; technical success is not full FFE readiness."""
from __future__ import annotations
import argparse,hashlib,json,re,struct,subprocess,zipfile
from pathlib import Path

FORBIDDEN_PERMISSIONS=['INTERNET','RECORD_AUDIO','READ_EXTERNAL_STORAGE','WRITE_EXTERNAL_STORAGE','MANAGE_EXTERNAL_STORAGE']
SOURCE_IMAGE_SHA256='d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72'

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
    libraries={};native_assets={};graphics_assets={}
    with zipfile.ZipFile(apk) as archive:
        assert archive.testzip() is None,'APK ZIP CRC failure'
        names=archive.namelist()
        assert sorted({n.split('/')[1] for n in names if n.startswith('lib/')})==['arm64-v8a'],'APK is not ARM64-only'
        assert not any(n.lower().endswith(('.exe','.asm','.keystore','.jks','.argosmodel')) for n in names),'Non-runtime/secret file in APK'
        forbidden=['assets/tests/','assets/tools/','assets/docs/','assets/recovered-history/','assets/recovery/','assets/validation/','assets/deliverables/','assets/localization/']
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
    return {**expected,'apk':apk.name,'bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'abi':'arm64-v8a','min_sdk':24,'target_sdk':target,'signature_verified':True,'certificate_sha256':certificate,'test_key_only':True,'zipalign_16k':True,'elf_load_alignment':libraries,'forbidden_permissions_absent':True,'debuggable':debuggable,'native_data_checked':not smoke,'native_data_assets':sorted(native_assets),'graphics_runtime_assets_sha256':graphics_assets,'toolchain_smoke_only':smoke,'physical_device_tested':False,'full_original_port_complete':False,'production_signing_key_configured':False,'publication_ready':False}

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
