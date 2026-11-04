#!/usr/bin/env python3
"""Install the pinned official toolchain used by the native Android rebuild.

New reconstruction tooling, not a recovered historical file. Downloads keep
normal TLS/proxy configuration. Every archive is verified before extraction.
No Android emulator, system image or production signing key is installed.
"""
from __future__ import annotations
import argparse,concurrent.futures,hashlib,json,os,shutil,stat,subprocess,tarfile,tempfile,urllib.request,zipfile
from pathlib import Path,PurePosixPath

PACKAGES=[
 {'name':'godot-templates','url':'https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz','algorithm':'sha512','hash':'da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68','source':'Official Godot4.6.3 SHA512-SUMS.txt'},
 {'name':'jdk17','url':'https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.16%2B8/OpenJDK17U-jdk_x64_linux_hotspot_17.0.16_8.tar.gz','algorithm':'sha256','hash':'166774efcf0f722f2ee18eba0039de2d685b350ee14d7b69e6f83437dafd2af1','source':'Official Temurin release .sha256.txt'},
 {'name':'build-tools','url':'https://dl.google.com/android/repository/build-tools_r36_linux.zip','algorithm':'sha1','hash':'b0b6376977657e8ad9b969bacf4093601da2c6fb','source':'Official Android repository2-1.xml complete/checksum'},
 {'name':'platform35','url':'https://dl.google.com/android/repository/platform-35_r02.zip','algorithm':'sha1','hash':'0bb560a90a7a2cbd0dd8348224d518b638fe7949','source':'Official Android repository2-1.xml complete/checksum'},
 {'name':'platform-tools','url':'https://dl.google.com/android/repository/platform-tools_r37.0.2-linux.zip','algorithm':'sha1','hash':'736a08af10515674e40d8b754fe87390d698da2b','source':'Official Android repository2-1.xml complete/checksum'},
]

def digest(path:Path,algorithm:str)->str:
 h=hashlib.new(algorithm)
 with path.open('rb') as stream:
  for block in iter(lambda:stream.read(1024*1024),b''):h.update(block)
 return h.hexdigest()

def download(package:dict,directory:Path)->tuple[dict,Path]:
 path=directory/package['url'].rsplit('/',1)[-1]
 if path.is_file() and digest(path,package['algorithm'])==package['hash']:
  print('Verified cached '+package['name'],flush=True);return package,path
 temporary=path.with_name(path.name+'.partial')
 print('Downloading '+package['name'],flush=True)
 with urllib.request.urlopen(package['url'],timeout=60) as response,temporary.open('wb') as target:
  shutil.copyfileobj(response,target,1024*1024)
 if digest(temporary,package['algorithm'])!=package['hash']:raise RuntimeError('Checksum mismatch: '+package['name'])
 temporary.replace(path)
 print('Verified '+package['name']+' '+str(path.stat().st_size)+' bytes',flush=True)
 return package,path

def extract_sdk(archive:Path,destination:Path,package:dict)->None:
 marker=destination/'.rebuild-package.json'
 if marker.is_file() and json.loads(marker.read_text()).get('hash')==package['hash']:return
 if destination.exists():raise RuntimeError('Refusing to overwrite an unverified SDK directory: '+str(destination))
 destination.parent.mkdir(parents=True,exist_ok=True)
 stage=Path(tempfile.mkdtemp(prefix='sdk-extract-',dir=destination.parent))
 try:
  with zipfile.ZipFile(archive) as source:
   members=source.infolist();tops={PurePosixPath(x.filename).parts[0] for x in members if x.filename}
   if len(tops)!=1:raise RuntimeError('Unexpected SDK archive layout')
   for info in members:
    parts=PurePosixPath(info.filename).parts
    if not parts or PurePosixPath(info.filename).is_absolute() or '..' in parts:raise RuntimeError('Unsafe SDK archive entry')
    rel=Path(*parts[1:])
    if not rel.parts:continue
    path=stage/rel
    if info.is_dir():path.mkdir(parents=True,exist_ok=True);continue
    if stat.S_ISLNK(info.external_attr>>16):raise RuntimeError('Unexpected SDK symlink')
    path.parent.mkdir(parents=True,exist_ok=True)
    with source.open(info) as reader,path.open('wb') as writer:shutil.copyfileobj(reader,writer)
    path.chmod(((info.external_attr>>16)&0o777) or 0o644)
  (stage/'.rebuild-package.json').write_text(json.dumps(package,indent=2)+'\n')
  stage.replace(destination)
 except BaseException:
  shutil.rmtree(stage);raise

def install(root:Path,archives:dict)->dict:
 jdk=root/'jdk17';jdk_marker=jdk/'.rebuild-package.json';package,archive=archives['jdk17']
 if not(jdk_marker.is_file() and json.loads(jdk_marker.read_text()).get('hash')==package['hash']):
  if jdk.exists():raise RuntimeError('Refusing to overwrite an unverified JDK directory')
  stage=Path(tempfile.mkdtemp(prefix='jdk-extract-',dir=root))
  try:
   with tarfile.open(archive) as source:source.extractall(stage,filter='data')
   candidates=list(stage.iterdir())
   if len(candidates)!=1:raise RuntimeError('Unexpected JDK archive layout')
   candidates[0].replace(jdk)
   jdk_marker.write_text(json.dumps(package,indent=2)+'\n')
  finally:shutil.rmtree(stage)
 sdk=root/'android-sdk'
 for name,path in [('build-tools',sdk/'build-tools'/'36.0.0'),('platform35',sdk/'platforms'/'android-35'),('platform-tools',sdk/'platform-tools')]:
  package,archive=archives[name];extract_sdk(archive,path,package)
 templates=root/'godot-data'/'godot'/'export_templates'/'4.6.3.stable';templates.mkdir(parents=True,exist_ok=True)
 package,archive=archives['godot-templates']
 with zipfile.ZipFile(archive) as source:
  for filename in ['android_debug.apk','android_release.apk','version.txt']:
   member='templates/'+filename
   with source.open(member) as reader,(templates/filename).open('wb') as writer:shutil.copyfileobj(reader,writer)
 (templates/'.rebuild-package.json').write_text(json.dumps(package,indent=2)+'\n')
 keys=root/'keys';keys.mkdir(exist_ok=True);keys.chmod(0o700)
 key=keys/'starfrontier-rebuild-test.keystore'
 if not key.exists():
  subprocess.run([str(jdk/'bin'/'keytool'),'-genkeypair','-keystore',str(key),'-storepass','android','-keypass','android','-alias','starfrontier-rebuild-test','-keyalg','RSA','-keysize','3072','-validity','10000','-dname','CN=StarFrontier Rebuild TEST,O=Local development,C=XX'],check=True)
  key.chmod(0o600)
 config=root/'godot-config'/'godot';config.mkdir(parents=True,exist_ok=True)
 (config/'editor_settings-4.6.tres').write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\nexport/android/android_sdk_path = '+json.dumps(str(sdk))+'\nexport/android/java_sdk_path = '+json.dumps(str(jdk))+'\nexport/android/debug_keystore = '+json.dumps(str(key))+'\nexport/android/debug_keystore_user = "starfrontier-rebuild-test"\nexport/android/debug_keystore_pass = "android"\n')
 for path in ['godot-data','godot-config','cache','android-user']:(root/path).mkdir(exist_ok=True)
 result={'godot':'4.6.3.stable','java_home':str(jdk),'android_sdk':str(sdk),'build_tools':str(sdk/'build-tools'/'36.0.0'),'templates':str(templates),'test_keystore':str(key),'test_alias':'starfrontier-rebuild-test','test_key_only':True,'production_signing':False,'emulator_installed':False,'archives':[{**p,'bytes':a.stat().st_size,'local_sha256':digest(a,'sha256')} for p,a in archives.values()]}
 (root/'android-rebuild-toolchain.json').write_text(json.dumps(result,indent=2)+'\n')
 return result

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,default=Path('/workspace/toolchains'));a=p.parse_args()
 root=a.root.resolve();root.mkdir(parents=True,exist_ok=True);downloads=root/'downloads';downloads.mkdir(exist_ok=True)
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:archives={p['name']:(p,path) for p,path in pool.map(lambda p:download(p,downloads),PACKAGES)}
 result=install(root,archives)
 subprocess.run([str(root/'jdk17'/'bin'/'java'),'-version'],check=True)
 subprocess.run([str(root/'jdk17'/'bin'/'javac'),'-version'],check=True)
 subprocess.run([str(root/'android-sdk'/'platform-tools'/'adb'),'version'],check=True)
 print(json.dumps({k:v for k,v in result.items() if k!='archives'},indent=2))

if __name__=='__main__':main()
