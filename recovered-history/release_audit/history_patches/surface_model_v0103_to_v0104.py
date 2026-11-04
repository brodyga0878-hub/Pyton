from pathlib import Path
p=Path('/workspace/recovery/from-agent-history/release_audit/scripts/surface_model.gd')
s=p.read_text().replace('var globe:RefCounted','''const MAX_FLIGHT_HEIGHT:=24000.0
var extended_flight:=false
var flight_phase:=""
var ready_for_orbit:=false
var globe:RefCounted''',1)
s=s.replace('\torbit_link={}\n\tglobe=null;frame_index=0','\torbit_link={}\n\textended_flight=false;flight_phase="";ready_for_orbit=false\n\tglobe=null;frame_index=0',1)
s=s.replace('\ttaking_off=false\n\tlanding=not landing', '\tcancel_vertical()\n\ttaking_off=false\n\tlanding=not landing',1)
s=s.replace('\tvar previous:Vector3=ship.position\n', '''\tvar previous:Vector3=ship.position
\tif not flight_phase.is_empty() and (steering.length()>0.05 or absf(roll)>0.05 or absf(lift)>0.1):cancel_vertical()
''',1)
s=s.replace('\tif taking_off:\n', '''\tif not flight_phase.is_empty():
\t\t_step_vertical(dt,ship)
\telif taking_off:
''',1)
s=s.replace('+clearance(ship)+4000.0 if globe else 4000.0','+clearance(ship)+(MAX_FLIGHT_HEIGHT if extended_flight else 4000.0) if globe else 4000.0',1)
s=s.replace('\tactive=false;landing=false;taking_off=false\n', '\tactive=false;landing=false;taking_off=false;flight_phase="";ready_for_orbit=false\n',1)
s=s.replace('\tif not active and not orbit_link.is_empty():', '\tif active and extended_flight:state.version=6;state.flight_phase=flight_phase\n\tif not active and not orbit_link.is_empty():',1)
s=s.replace('\tif data.get("version",0)==5:', '''\tif data.get("version",0)==6:
\t\tif not data.get("flight_phase") is String or data.flight_phase not in ["","ascent","descent"]:return false
\t\tif data.get("landed")==true and not data.flight_phase.is_empty():return false
\t\tif not _restore_globe(data,ship,system,MAX_FLIGHT_HEIGHT+1):return false
\t\textended_flight=true;flight_phase=data.flight_phase
\t\treturn true
\tif data.get("version",0)==5:''',1)
s=s.replace('\torbit_link={}\n\tglobe=null;frame_index=0\n\tsite_name=', '\torbit_link={}\n\textended_flight=false;flight_phase="";ready_for_orbit=false\n\tglobe=null;frame_index=0\n\tsite_name=',1)
s=s.replace('func _restore_globe(data:Dictionary,ship:RefCounted,system:RefCounted)->bool:', 'func _restore_globe(data:Dictionary,ship:RefCounted,system:RefCounted,maximum_height:=4001.0)->bool:',1).replace('if height< -1 or height>4001 or candidate.overlaps_building(ship):','if height< -1 or height>maximum_height or candidate.overlaps_building(ship):',1)
s=s.replace('\torbit_link={}\n\tglobe=candidate.globe;', '\torbit_link={}\n\textended_flight=false;flight_phase="";ready_for_orbit=false\n\tglobe=candidate.globe;',1)
s=s.replace('str(frame_index) if globe else ":local")','str(frame_index)+(":high" if extended_flight else "") if globe else ":local")',1)
s+='''
func cancel_vertical()->void:
\tif not flight_phase.is_empty():message="Вертикальный автополёт отменён. Торможение доступно отдельной кнопкой."
\tflight_phase="";ready_for_orbit=false
func begin_ascent(ship:RefCounted)->bool:
\tif not active or not globe or landed or ship.hull<=0 or altitude(ship)<500 or ship.velocity.length()>20:
\t\tmessage="Для автоподъёма: высота от 500 м, скорость до 20 м/с."
\t\treturn false
\textended_flight=true;flight_phase="ascent";ready_for_orbit=false;landing=false;taking_off=false
\tship.assisted=true;ship.target_speed=0;ship.autopilot=false
\tmessage="Автоподъём к 20 км. «Тормозить» или ручное управление отменяют подъём."
\treturn true
func begin_descent(ship:RefCounted,system:RefCounted,days:float)->bool:
\tif not OrbitLink.matches(orbit_link,system):return enter(ship,system,true)
\tvar height:float=ship.position.distance_to(system.local_meters(system.focus_id,days))-float(system.by_id[system.focus_id].radius_km)*1000.0
\tif height>MAX_FLIGHT_HEIGHT-200 or height<1800:
\t\tmessage="Для автоспуска подойдите на высоту от 1,8 до 23,8 км над планетой."
\t\treturn false
\tif not enter_from_orbit(ship,system,days):return false
\textended_flight=true;flight_phase="descent"
\tship.position.y=height
\tmessage="Управляемый спуск к высоте 1500 м. «Тормозить» отменяет спуск."
\treturn true
func resume_descent(ship:RefCounted)->bool:
\tif not active or not globe or landed or ship.hull<=0:return false
\textended_flight=true;flight_phase="descent";ready_for_orbit=false;landing=false;taking_off=false
\tship.assisted=true;ship.target_speed=0;ship.autopilot=false
\tmessage="Управляемое снижение к 1500 м."
\treturn true
func _step_vertical(dt:float,ship:RefCounted)->void:
\tvar height:=altitude(ship)
\tvar target:=1500.0
\tif flight_phase=="ascent":
\t\tvar ll:Array=geographic_position(ship)
\t\ttarget=OrbitLink.ALTITUDE-globe.elevation(ll[0],ll[1])-clearance(ship)
\tvar error:=target-height
\tvar reserve:=maxf(0.1,ship.acceleration()-gravity)
\tvar speed:=minf(300.0,sqrt(2.0*reserve*absf(error))*0.65)
\tship.velocity=ship.velocity.move_toward(Vector3.UP*signf(error)*speed,reserve*dt)
\tship.attitude=ship.attitude.slerp(Quaternion(Vector3.RIGHT,0.15 if flight_phase=="ascent" else -0.35),minf(1,dt)).normalized()
\tship.position+=ship.velocity*dt
\tif absf(error)<0.6 and ship.velocity.length()<2:
\t\tship.position.y=height_at(ship.position.x,ship.position.z)+clearance(ship)+target
\t\tship.velocity=Vector3.ZERO
\t\tif flight_phase=="ascent":ready_for_orbit=true
\t\telse:
\t\t\tflight_phase="";message="Спуск завершён. Можно лететь вручную или включить автопосадку."
'''
# Later exact validation fixes from the original tool inputs.
s=s.replace('if data.get("version",0)==4:return _restore_globe(data,ship,system)','''if data.get("version",0)==4:
\t\tif data.has("flight_phase"):return false
\t\treturn _restore_globe(data,ship,system)''',1)
s=s.replace('if data.get("landed")==true and not data.flight_phase.is_empty():return false','''if data.get("landed")==true and not data.flight_phase.is_empty():return false
\t\tif not data.flight_phase.is_empty() and (ship.velocity.length()>301 or not ship.assisted or absf(ship.target_speed)>0.01):return false''',1)
p.write_text(s)
version=p.parents[1]/'versions'/'v0.10.4-history-patches'/'scripts';version.mkdir(parents=True,exist_ok=True);(version/'surface_model.gd').write_text(s)
