from pathlib import Path
p=Path('/workspace/recovery/from-agent-history/release_audit/scripts/surface_model.gd')
s=p.read_text().replace('const SegmentBox=', '''const SphereTerrain=preload("res://scripts/spherical_terrain.gd")
const REBASE_DISTANCE:=512.0
var globe:RefCounted
var frame_index:=0
var frame_rotation:=Quaternion.IDENTITY
var rebase_from:=Vector3.ZERO
var rebase_to:=Vector3.ZERO
const SegmentBox=''',1)
s=s.replace('\tvar phase:=float(seed_value&1023)*0.013','\tif globe:return globe.raw_height(x,z)\n\tvar phase:=float(seed_value&1023)*0.013',1)
s=s.replace('func enter(ship: RefCounted, system: RefCounted) -> bool:','func enter(ship: RefCounted, system: RefCounted, spherical:=false) -> bool:',1)
s=s.replace('\tgravity=G*float(body.mass_solar)*SOLAR_MASS/pow(float(body.radius_km)*1000,2)\n\torbit_position=', '''\tglobe=null;frame_index=0
\tif spherical:
\t\tglobe=SphereTerrain.new();globe.configure(system,body_id,system.site_id)
\tgravity=G*float(body.mass_solar)*SOLAR_MASS/pow(float(body.radius_km)*1000,2)
\torbit_position=''',1)
s=s.replace('\t\tvar horizontal:=Vector3(-ship.position.x,0,-ship.position.z)\n\t\tvar height:=maxf(0,ship.position.y-clearance(ship))', '''\t\tvar pad:=pad_position()
\t\tvar horizontal:=Vector3(pad.x-ship.position.x,0,pad.z-ship.position.z)
\t\tvar height:=maxf(0,ship.position.y-pad.y-clearance(ship))''',1)
s=s.replace('else clampf((200-ship.position.y)*0.1,-20,20)','else clampf((height_at(ship.position.x,ship.position.z)+200-ship.position.y)*0.1,-20,20)',1)
s=s.replace('\tif radial.length()>LIMIT:','\tif not globe and radial.length()>LIMIT:',1)
s=s.replace('\tif ship.position.y>4000:\n\t\tship.position.y=4000;ship.velocity.y=minf(ship.velocity.y,0);ship.target_speed=0','''\tvar ceiling:=height_at(ship.position.x,ship.position.z)+clearance(ship)+4000.0 if globe else 4000.0
\tif ship.position.y>ceiling:
\t\tship.position.y=ceiling;ship.velocity.y=minf(ship.velocity.y,0);ship.target_speed=0''',1)
s=s.replace('\nfunc touch_down(', '\n\tif globe and radial.length()>REBASE_DISTANCE:recenter(ship)\n\nfunc touch_down(',1)
s=s.replace('\treturn {"version":3,"active":active,', '\tvar state:Dictionary={"version":3,"active":active,',1)
s=s.replace('\nfunc restore(data:', '''
\tif active and globe:
\t\tstate.version=4;state.layout="globe_v1";state.terrain_revision=SphereTerrain.REVISION
\t\tstate.latitude=globe.latitude;state.longitude=globe.longitude
\treturn state

func restore(data:''',1)
s=s.replace('\tif (data.get("version",0)!=1', '\tif data.get("version",0)==4:return _restore_globe(data,ship,system)\n\tif (data.get("version",0)!=1',1)
s=s.replace('\tsite_name=""\n\tactive=data.active;', '\tglobe=null;frame_index=0\n\tsite_name=""\n\tactive=data.active;',1)
s=s.replace('\tfor i in range(10):\n\t\tvar height:=', '\tvar pad:=pad_position()\n\tif globe and Vector2(pad.x,pad.z).length()>GRID_WIDTH:return result\n\tfor i in range(10):\n\t\tvar height:=',1)
s=s.replace('var z:=float((i%5)*130-260)\n\t\tresult.append', 'var z:=float((i%5)*130-260)\n\t\tx+=pad.x;z+=pad.z\n\t\tresult.append',1)
s+='''
func terrain_key()->String:
\treturn str(seed_value)+":"+kind+":"+site_name+(":globe:"+str(frame_index) if globe else ":local")
func pad_position()->Vector3:
\tif not globe:return Vector3.ZERO
\tvar p:Vector2=globe.project(globe.pad_latitude,globe.pad_longitude)
\t# Far-side ports are navigation targets, not rendered through the planet.
\treturn Vector3(p.x,height_at(p.x,p.y),p.y)
func geographic_position(ship:RefCounted)->Array:
\treturn globe.coordinates(ship.position.x,ship.position.z) if globe else []
func pad_distance(ship:RefCounted)->float:
\tif not globe:return Vector2(ship.position.x,ship.position.z).length()
\tvar ll:=geographic_position(ship)
\tvar saved_lat:float=globe.latitude;var saved_lon:float=globe.longitude
\tglobe.latitude=ll[0];globe.longitude=ll[1]
\tvar result:float=globe.distance_to(globe.pad_latitude,globe.pad_longitude)
\tglobe.latitude=saved_lat;globe.longitude=saved_lon
\treturn result
func recenter(ship:RefCounted)->void:
\tif not globe:return
\tvar altitude_now:=altitude(ship)
\tvar ll: Array=geographic_position(ship)
\tvar old_basis:Basis=globe.basis_at(globe.latitude,globe.longitude)
\tvar next_basis:Basis=globe.basis_at(ll[0],ll[1])
\tframe_rotation=(next_basis.transposed()*old_basis).get_rotation_quaternion().normalized()
\trebase_from=ship.position
\tglobe.latitude=ll[0];globe.longitude=ll[1];frame_index+=1
\tship.position=Vector3(0,height_at(0,0)+clearance(ship)+altitude_now,0)
\tship.velocity=frame_rotation*ship.velocity
\tship.attitude=(frame_rotation*ship.attitude).normalized()
\trebase_to=ship.position
func _restore_globe(data:Dictionary,ship:RefCounted,system:RefCounted)->bool:
\tif data.get("layout")!="globe_v1" or data.get("terrain_revision")!=SphereTerrain.REVISION:return false
\tif data.get("active")!=true or not data.get("landed") is bool or data.get("body_id")!=system.focus_id:return false
\tif ship.docked or str(system.by_id[system.focus_id].kind) in ["gas","ice_gas","star","barycenter"]:return false
\tfor key in ["latitude","longitude"]:
\t\tif not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])):return false
\tif absf(float(data.latitude))>PI*0.5 or float(data.longitude)< -PI or float(data.longitude)>PI:return false
\tfor key in ["orbit_position","orbit_attitude"]:
\t\tif not data.get(key) is Array or data[key].size()!=(4 if key=="orbit_attitude" else 3):return false
\t\tfor value in data[key]:
\t\t\tif not (value is float or value is int) or not is_finite(float(value)) or absf(float(value))>1e9:return false
\tvar rotation:=Quaternion(data.orbit_attitude[0],data.orbit_attitude[1],data.orbit_attitude[2],data.orbit_attitude[3])
\tif rotation.length_squared()<0.01 or not ship.position.is_finite() or not ship.velocity.is_finite():return false
\tif Vector2(ship.position.x,ship.position.z).length()>REBASE_DISTANCE+20:return false
\tvar candidate:RefCounted=get_script().new()
\tcandidate.globe=SphereTerrain.new();candidate.globe.configure(system,system.focus_id,system.site_id)
\tcandidate.globe.latitude=float(data.latitude);candidate.globe.longitude=float(data.longitude)
\tcandidate.seed_value=system.system_id^system.focus_id.hash()
\tvar site:Dictionary=system.current_site()
\tif not site.is_empty() and int(site.type_code)==35:
\t\tcandidate.site_name=str(site.name);candidate.seed_value^=system.site_id.hash()
\tvar height:float=candidate.altitude(ship)
\tif height< -1 or height>4001 or candidate.overlaps_building(ship):return false
\tif data.landed and (absf(height)>1 or ship.velocity.length()>0.1):return false
\tglobe=candidate.globe;seed_value=candidate.seed_value;site_name=candidate.site_name
\tframe_index=0;active=true;landed=data.landed;landing=false;taking_off=false;body_id=system.focus_id
\tkind=str(system.by_id[body_id].kind)
\tgravity=G*float(system.by_id[body_id].mass_solar)*SOLAR_MASS/pow(float(system.by_id[body_id].radius_km)*1000,2)
\torbit_position=Vector3(data.orbit_position[0],data.orbit_position[1],data.orbit_position[2]);orbit_attitude=rotation.normalized()
\tship.surface_mode=true
\treturn true
'''
# Subsequent fixes preserved verbatim from the same historical tool inputs.
s=s.replace('str(frame_index) if globe', 'str(globe.get_instance_id())+":"+str(frame_index) if globe')
s=s.replace('return Vector3(p.x,height_at(p.x,p.y),p.y)','return Vector3(p.x,height_at(p.x,p.y) if p.length()<GRID_WIDTH*1.5 else height_at(0,0),p.y)')
s=s.replace('if data.get("active")!=true or not data.get("landed") is bool', 'if not data.get("active") is bool or not data.active or not data.get("landed") is bool')
s=s.replace('\tship.attitude=Quaternion(Vector3.RIGHT,-0.35)\n\tmessage=', '\tship.attitude=Quaternion(Vector3.RIGHT,-0.35)\n\tif globe:recenter(ship)\n\tmessage=',1)
s=s.replace('var cell:=GRID_WIDTH/GRID_CELLS','var cell:=GRID_WIDTH/grid_cells()',1).replace('\tif (data.get("version",0)!=1','\tif data.has("terrain_revision") or data.has("layout"):return false\n\tif (data.get("version",0)!=1',1)
s=s.replace('\nfunc terrain_key()', '\nfunc grid_cells()->int:return 64 if globe else GRID_CELLS\n\nfunc terrain_key()',1)
s=s.replace('\t\tship.velocity=ship.velocity.move_toward(desired,reserve*dt)', '''\t\tif globe and horizontal.length()>80 and altitude(ship)<100:
\t\t\t# Clear nearby hills before accelerating horizontally after a wilderness takeoff.
\t\t\tdesired=Vector3.UP*minf(20,sqrt(maxf(0,180-altitude(ship))*reserve))
\t\tship.velocity=ship.velocity.move_toward(desired,reserve*dt)''',1)
s=s.replace('if landing and altitude(ship)<=0.6 and ship.velocity.length()<=6:', 'if landing and altitude(ship)<=0.6 and ship.velocity.length()<=6 and (not globe or pad_distance(ship)<80):',1)
p.write_text(s)
version=p.parents[1]/'versions'/'v0.10.2-history-patches'/'scripts';version.mkdir(parents=True,exist_ok=True);(version/'surface_model.gd').write_text(s)
