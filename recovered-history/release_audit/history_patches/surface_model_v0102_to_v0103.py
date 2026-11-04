from pathlib import Path
p=Path('/workspace/recovery/from-agent-history/release_audit/scripts/surface_model.gd')
s=p.read_text().replace('const SphereTerrain=', 'const OrbitLink=preload("res://scripts/surface_orbit_link.gd")\nvar orbit_link:Dictionary={}\nconst SphereTerrain=',1)
s=s.replace('\tglobe=null;frame_index=0\n\tif spherical:', '\torbit_link={}\n\tglobe=null;frame_index=0\n\tif spherical:',1)
s=s.replace('func leave(ship: RefCounted) -> bool:', 'func leave(ship: RefCounted,system:RefCounted=null,days:=0.0) -> bool:',1)
s=s.replace('\tship.position=orbit_position;ship.attitude=orbit_attitude','''\tif globe and system:
\t\torbit_link=OrbitLink.make(self,ship,system,days)
\t\tvar ll:Array=geographic_position(ship)
\t\tvar world_basis:Basis=Basis(Vector3.UP,OrbitLink.spin(system.by_id[body_id],days))*globe.basis_at(ll[0],ll[1])
\t\tship.attitude=(world_basis.get_rotation_quaternion()*ship.attitude).normalized()
\t\tship.position=Vector3(orbit_link.position[0],orbit_link.position[1],orbit_link.position[2])
\telse:
\t\tship.position=orbit_position;ship.attitude=orbit_attitude''',1)
s=s.replace('\treturn state\n\nfunc restore', '\tif not active and not orbit_link.is_empty():state.version=5;state.orbit_link=orbit_link.duplicate(true)\n\treturn state\n\nfunc restore',1)
s=s.replace('\tif data.get("version",0)==4:return _restore_globe', '''\tif data.get("version",0)==5:
\t\tif data.get("active")!=false or data.get("landed")!=false or not OrbitLink.valid(data.get("orbit_link"),system):return false
\t\tif not system.site_id.is_empty() or ship.docked:return false
\t\tvar old:=data.duplicate(true);old.version=3;old.erase("orbit_link")
\t\tvar candidate:RefCounted=get_script().new()
\t\tif not candidate.restore(old,ship,system):return false
\t\tif not restore(old,ship,system):return false
\t\torbit_link=data.orbit_link.duplicate(true)
\t\treturn true
\tif data.get("version",0)==4:return _restore_globe''',1)
s=s.replace('\tglobe=null;frame_index=0\n\tsite_name=', '\torbit_link={}\n\tglobe=null;frame_index=0\n\tsite_name=',1)
s=s.replace('\tglobe=candidate.globe;seed_value=', '\torbit_link={}\n\tglobe=candidate.globe;seed_value=',1)
s+='''
func enter_from_orbit(ship:RefCounted,system:RefCounted,days:float)->bool:
\tif not OrbitLink.matches(orbit_link,system):return enter(ship,system,true)
\tmessage=entry_error(ship,system)
\tif not message.is_empty():return false
\tvar ll:Array=OrbitLink.coordinates(orbit_link,ship,system,days)
\tif ll.is_empty():message="Невозможно определить точку входа над планетой.";return false
\tvar anchor:String=orbit_link.site_id
\tvar previous_site:String=system.site_id
\tsystem.site_id=anchor
\tif not enter(ship,system,true):system.site_id=previous_site;return false
\tglobe.latitude=ll[0];globe.longitude=ll[1];frame_index+=1
\tship.position=Vector3(0,height_at(0,0)+clearance(ship)+1500,0)
\tship.velocity=Vector3.ZERO;ship.target_speed=0;ship.attitude=Quaternion(Vector3.RIGHT,-0.35)
\tmessage="Вход над текущей точкой планеты. До исходной площадки %.1f км."%(pad_distance(ship)/1000.0)
\treturn true
'''
# The later review fixes from the same history.
s=s.replace('\t\tif not system.site_id.is_empty() or ship.docked:return false\n','',1)
s=s.replace('if data.get("active")!=false or data.get("landed")!=false or not OrbitLink.valid(data.get("orbit_link"),system):return false','if not data.get("active") is bool or not data.get("landed") is bool or data.active or data.landed or data.get("body_id")!=system.focus_id or not OrbitLink.valid(data.get("orbit_link"),system):return false',1)
p.write_text(s)
version=p.parents[1]/'versions'/'v0.10.3-history-patches'/'scripts';version.mkdir(parents=True,exist_ok=True);(version/'surface_model.gd').write_text(s)
