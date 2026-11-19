#!/usr/bin/env python3
"""Verify the versioned ARM64 mission statement checkpoint without rewriting old release proofs."""
from __future__ import annotations
import argparse,hashlib,importlib.util,json,os,re,struct,subprocess,tempfile,zipfile
from pathlib import Path
VERSION='0.32.0-statements-alpha1';CODE=57
CERT='16f47f20a2d2aca3de1fe893ddfa01e90acf2d6b98b32ca772bb914c9ee21e25'
def require(value,reason):
    if not value:raise ValueError(reason)
def sha(raw):return hashlib.sha256(raw).hexdigest()
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('apk',type=Path);p.add_argument('report',type=Path);p.add_argument('--project',type=Path,required=True);p.add_argument('--source-commit',required=True);p.add_argument('--runtime-freeze',type=Path,required=True);p.add_argument('--source-verification',type=Path,required=True);p.add_argument('--toolchain',type=Path,default=Path('/workspace/toolchains'));a=p.parse_args()
    project=a.project.resolve();apk=a.apk.resolve();freeze_raw=a.runtime_freeze.read_bytes();freeze=json.loads(freeze_raw);pair=json.loads(a.source_verification.read_text())
    require(re.fullmatch('[0-9a-f]{40}',a.source_commit)and pair.get('ok')is True and pair.get('source_commit')==a.source_commit,'Verified source-pair identity required')
    require(pair.get('runtime_freeze_sha256')==sha(freeze_raw),'Source-pair runtime freeze differs')
    runtime=freeze['files_sha256']
    for n,h in runtime.items():require(sha((project/n).read_bytes())==h,'Source runtime changed before APK verification: '+n)
    spec=importlib.util.spec_from_file_location('retained_android_assets',project/'tools/verify_rebuilt_android.py');old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
    expected=old.preset_values(project/'export_presets.cfg');require(expected['version']==VERSION and expected['version_code']==CODE,'New Android preset version required')
    info=(project/'scripts/build_info.gd').read_text();require(re.search(r'^const VERSION\s*:=\s*"'+re.escape(VERSION)+r'"\s*$',info,re.M)and re.search(r'^const VERSION_CODE\s*:=\s*57\s*$',info,re.M),'Diagnostic/menu build version differs')
    env=dict(os.environ,JAVA_HOME=str(a.toolchain/'jdk17'));env['PATH']=str(a.toolchain/'jdk17/bin')+os.pathsep+env.get('PATH','');bt=a.toolchain/'android-sdk/build-tools/36.0.0'
    def run(name,*args):return subprocess.check_output([str(bt/name),*map(str,args)],env=env,stderr=subprocess.STDOUT,text=True)
    signing=run('apksigner','verify','--verbose','--print-certs',apk);require('CN=StarFrontier Rebuild TEST'in signing,'Unexpected signing identity')
    cert=re.search(r'Signer #1 certificate SHA-256 digest: (\w+)',signing);require(cert and cert[1]==CERT,'APK cannot update the existing test installation')
    run('zipalign','-c','-P','16','4',apk)
    badging=run('aapt','dump','badging',apk);permissions=run('aapt','dump','permissions',apk)
    for token in ["name='org.starfrontier.rebuild'","versionCode='57'","versionName='"+VERSION+"'","sdkVersion:'24'"]:require(token in badging,'APK manifest differs: '+token)
    target=int(re.search(r"targetSdkVersion:'(\d+)'",badging)[1]);require(target>=35 and'application-debuggable'not in badging,'APK target/debug policy differs')
    for name in old.FORBIDDEN_PERMISSIONS:require('android.permission.'+name not in permissions,'Unexpected permission '+name)
    compiled={};data_assets={};libraries={}
    with zipfile.ZipFile(apk)as archive:
        require(archive.testzip()is None,'APK ZIP CRC failed');names=set(archive.namelist())
        require(sorted({n.split('/')[1]for n in names if n.startswith('lib/')})==['arm64-v8a'],'APK must be ARM64 only')
        require(not any(n.startswith(old.DEVELOPMENT_ASSET_PREFIXES)for n in names),'Development files leaked into APK')
        require(not any(n.lower().endswith(('.exe','.asm','.keystore','.jks'))for n in names),'Nonruntime/signing file leaked into APK')
        for n,h in runtime.items():
            if n.startswith('scripts/')and n.endswith('.gd'):
                packed='assets/'+n[:-3]+'.gdc';require(packed in names and len(archive.read(packed))>64 and archive.read(packed).startswith(b'GDSC'),'Compiled script missing or invalid: '+n);compiled[n]=sha(archive.read(packed))
            elif n.startswith('data/')and n.endswith('.json'):
                packed='assets/'+n;require(packed in names and sha(archive.read(packed))==h,'Exported data differs: '+n);data_assets[n]=h
        materials={name:fn(archive,project)for name,fn in [('materials',old.verify_material_assets),('surface_details',old.verify_surface_details),('city',old.verify_city_surfaces),('world',old.verify_world_surfaces)]}
        for n in sorted(names):
            if not n.startswith('lib/')or not n.endswith('.so'):continue
            raw=archive.read(n);require(raw[:5]==b'\x7fELF\x02'and struct.unpack_from('<H',raw,18)[0]==183,'Native library must be AArch64 ELF64');start=struct.unpack_from('<Q',raw,32)[0];size,count=struct.unpack_from('<HH',raw,54);aligns=[]
            for i in range(count):
                row=struct.unpack_from('<IIQQQQQQ',raw,start+i*size)
                if row[0]==1:require(row[7]>=16384 and row[2]%row[7]==row[3]%row[7],'Invalid native LOAD alignment');aligns.append(row[7])
            require(aligns,'Native LOAD segments missing');libraries[n]=aligns
        build=project/'build';build.mkdir(exist_ok=True);(build/'.gdignore').touch()
        with tempfile.TemporaryDirectory(prefix='apk-version-proof-',dir=build)as directory:
            private=Path(directory);script_path=private/'actual_build_info.gdc';script_path.write_bytes(archive.read('assets/scripts/build_info.gdc'));probe_path=private/'constants.json'
            probe_env=dict(env,XDG_DATA_HOME=str(private/'data'),XDG_CONFIG_HOME=str(private/'config'),XDG_CACHE_HOME=str(private/'cache'))
            probe=subprocess.run(['godot','--headless','--path',str(project),'--script','res://tools/probe_events_android_version.gd','--',str(script_path),str(probe_path)],env=probe_env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=60)
            require(probe.returncode==0 and probe_path.is_file()and not re.search(r'SCRIPT ERROR:|^\s*ERROR:|ObjectDB instances leaked|resources still in use at exit',probe.stdout,re.M),'Engine could not inspect exported BuildInfo bytecode')
            embedded=json.loads(probe_path.read_text());require(embedded=={'version':VERSION,'version_code':CODE,'channel':'rebuild-alpha-test','actual_exported_bytecode_loaded':True},'Actual compiled diagnostic/menu version differs from the APK manifest')
    require(libraries,'No native ARM64 library')
    result={'schema':'starfrontier-mission-statements-android-verification-v1','status':'verified','package':'org.starfrontier.rebuild','version':VERSION,'version_code':CODE,'apk':apk.name,'bytes':apk.stat().st_size,'sha256':sha(apk.read_bytes()),'abi':'arm64-v8a','min_sdk':24,'target_sdk':target,'signature_verified':True,'certificate_sha256':CERT,'test_key_only':True,'zipalign_16k':True,'elf_load_alignment':libraries,'forbidden_permissions_absent':True,'debuggable':False,'source_commit':a.source_commit,'runtime_freeze_sha256':sha(freeze_raw),'runtime_inputs_verified':len(runtime),'runtime_inputs_match_frozen_source':True,'source_pair_verified':True,'compiled_modules':compiled,'data_assets_sha256':data_assets,'retained_material_assets':materials,'new_kernels_connected_to_Main':False,'physical_device_tested':False,'full_original_port_complete':False,'scope':'Versioned test-signed APK built from the verified frozen source pair. Actual manifest/signature/ARM64/alignment/data/material checks passed. Mission statement/spawn/VM kernels remain separately verified; this is not full mission VM or new Main orchestration.'}
    # Compile a separate Android resource pack ourselves from the pinned project.
    # ZIP timestamps/signatures are irrelevant; every script byte must match.
    build=project/'build'
    with tempfile.TemporaryDirectory(prefix='apk-source-recompile-',dir=build)as directory:
        private=Path(directory);pack=private/'expected.pck';paths=private/'scripts.json';hashes=private/'hashes.json';paths.write_text(json.dumps(sorted(compiled)))
        export_env=dict(env,XDG_DATA_HOME=str(a.toolchain/'godot-data'),XDG_CONFIG_HOME=str(a.toolchain/'godot-config'),XDG_CACHE_HOME=str(a.toolchain/'cache'),ANDROID_USER_HOME=str(a.toolchain/'android-user'))
        export_command=['godot','--headless','--path',str(project),'--export-pack','Android',str(pack)]
        rebuilt=subprocess.run(export_command,env=export_env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=300)
        require(rebuilt.returncode==0 and pack.is_file()and not re.search(r'SCRIPT ERROR:|^\s*ERROR:|ObjectDB instances leaked|resources still in use at exit',rebuilt.stdout,re.M),'Independent Android pack compilation failed')
        probe_env=dict(env,XDG_DATA_HOME=str(private/'data'),XDG_CONFIG_HOME=str(private/'config'),XDG_CACHE_HOME=str(private/'cache'))
        observed=subprocess.run(['godot','--headless','--path',str(project),'--script','res://tools/probe_events_android_pack.gd','--',str(pack),str(paths),str(hashes)],env=probe_env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=60)
        require(observed.returncode==0 and hashes.is_file()and not re.search(r'SCRIPT ERROR:|^\s*ERROR:|ObjectDB instances leaked|resources still in use at exit',observed.stdout,re.M),'Could not inspect independently compiled Android pack')
        require(json.loads(hashes.read_text())==compiled,'Actual APK bytecode differs from independently compiled frozen source')
        recompilation={'compiled_script_count':len(compiled),'all_compiled_script_bytes_match':True,'resource_pack_sha256':sha(pack.read_bytes()),'export_log_sha256':sha(rebuilt.stdout.encode()),'command':export_command[:-1]+['<private>/expected.pck'],'actual_engine_pack_mounted':True}
    for n,h in runtime.items():require(sha((project/n).read_bytes())==h,'Frozen runtime source changed during independent compilation: '+n)
    result['embedded_build_info']=embedded;result['all_script_bytecode_headers_valid']=True;result['compiled_source_correspondence_rebuilt_by_verifier']=True;result['independent_android_recompilation']=recompilation
    a.report.parent.mkdir(parents=True,exist_ok=True);a.report.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:result[k]for k in ['status','version','version_code','bytes','sha256','runtime_inputs_verified']},indent=2))
if __name__=='__main__':main()
