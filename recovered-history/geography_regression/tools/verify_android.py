#!/usr/bin/env python3
"""Verify a review APK; passing technical checks does not mean full FFE is ported."""
import argparse,hashlib,json,re,struct,subprocess,zipfile
from pathlib import Path

def run(*command):return subprocess.check_output([str(v) for v in command],text=True,stderr=subprocess.STDOUT)
def verify(apk,build_tools,previous=None):
 signature=run(build_tools/'apksigner','verify','--verbose','--print-certs',apk)
 run(build_tools/'zipalign','-c','-P','16','4',apk)
 badging=run(build_tools/'aapt','dump','badging',apk)
 permissions=run(build_tools/'aapt','dump','permissions',apk)
 assert "name='org.starfrontier.flightprototype'" in badging
 assert "versionCode='21'" in badging and "versionName='0.10.8-alpha1'" in badging and "sdkVersion:'24'" in badging
 for permission in ['INTERNET','RECORD_AUDIO','READ_EXTERNAL_STORAGE','WRITE_EXTERNAL_STORAGE']:
  assert 'android.permission.'+permission not in permissions
 certificate=re.search(r'Signer #1 certificate SHA-256 digest: (\w+)',signature).group(1)
 same_key=None
 if previous:
  old=run(build_tools/'apksigner','verify','--print-certs',previous)
  same_key=certificate==re.search(r'Signer #1 certificate SHA-256 digest: (\w+)',old).group(1);assert same_key
 libraries={}
 with zipfile.ZipFile(apk) as archive:
  names=archive.namelist()
  assert sorted({n.split('/')[1] for n in names if n.startswith('lib/')})==['arm64-v8a']
  assert not any(n.lower().endswith(('.exe','.asm','.keystore','.argosmodel')) for n in names)
  assert not any(n.startswith(('assets/tests/','assets/tools/','assets/docs/','assets/localization/')) for n in names)
  for filename in ['ffe_name_rules','ffe_settlement_rules','ffe_system_profiles','ffe_formation','ffe_body_geometry','ffe_ground_coordinates']:
   assert 'assets/data/'+filename+'.json' in names
  assert len(json.loads(archive.read('assets/data/ffe_ground_coordinates.json'))['sin_quarter_q31'])==16384
  assert any(n.startswith('assets/scripts/ground_coordinates') for n in names)
  assert len(json.loads(archive.read('assets/data/ffe_body_geometry.json'))['models'])==31
  assert any(n.startswith('assets/scripts/procedural_worlds') for n in names)
  for shader in ['terrain','terrain_transition','rings','landing_pad','building','atmosphere','planet']:
   assert 'assets/scripts/'+shader+'.gdshader' in names
  assert any(n.startswith('assets/scripts/world_presentation') for n in names)
  assert any(n.startswith('assets/scripts/spherical_terrain') for n in names)
  assert any(n.startswith('assets/scripts/surface_orbit_link') for n in names)
  assert any(n.startswith('assets/scripts/near_surface_view') for n in names)
  assert not any(n.endswith('/model.bin') or 'ctranslate2' in n for n in names)
  assert len(json.loads(archive.read('assets/data/journals_ru.json'))['entries'])==657
  registry=json.loads(archive.read('assets/data/ffe_ship_registry.json'))
  assert {int(s['index']) for s in registry['ships']}==set(range(15,72))
  assert len(registry['selection_pools'])==19
  worlds=json.loads(archive.read('assets/data/ffe_worlds.json'))
  assert len(worlds['systems'])==11 and sum(len(s['objects']) for s in worlds['systems'])==130
  assert len(json.loads(archive.read('assets/data/ffe_math.json'))['sqrt_table'])==2048
  for name in names:
   if not name.startswith('lib/') or not name.endswith('.so'):continue
   data=archive.read(name);assert data[:5]==b'\x7fELF\x02'
   start=struct.unpack_from('<Q',data,32)[0];size,count=struct.unpack_from('<HH',data,54);aligns=[]
   for i in range(count):
    header=struct.unpack_from('<IIQQQQQQ',data,start+i*size)
    if header[0]==1:aligns.append(header[7])
   assert aligns and min(aligns)>=16384;libraries[name]=aligns
 return {'apk':apk.name,'bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'package':'org.starfrontier.flightprototype','version':'0.10.8-alpha1','version_code':21,'min_sdk':24,'abi':'arm64-v8a','signature_verified':True,'same_key_as_previous':same_key,'zipalign_16k':True,'elf_load_alignment':libraries,'no_network_or_storage_permission':True,'debuggable':"application-debuggable" in badging,'physical_device_tested':False,'production_ready':False}
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('apk',type=Path);p.add_argument('report',type=Path);p.add_argument('--build-tools',type=Path,required=True);p.add_argument('--previous',type=Path)
 a=p.parse_args();result=verify(a.apk,a.build_tools,a.previous);a.report.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
