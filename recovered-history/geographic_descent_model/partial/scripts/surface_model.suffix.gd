func grid_cells()->int:return 64 if globe else GRID_CELLS

func terrain_key()->String:
	return str(seed_value)+":"+kind+":"+site_name+(":globe:"+str(globe.get_instance_id())+":"+str(frame_index)+(":high" if extended_flight else "") if globe else ":local")
func pad_position()->Vector3:
	if not globe:return Vector3.ZERO
	var p:Vector2=globe.project(globe.pad_latitude,globe.pad_longitude)
	# Far-side ports are navigation targets, not rendered through the planet.
	return Vector3(p.x,height_at(p.x,p.y) if p.length()<GRID_WIDTH*1.5 else height_at(0,0),p.y)
func geographic_position(ship:RefCounted)->Array:
	return globe.coordinates(ship.position.x,ship.position.z) if globe else []
func pad_distance(ship:RefCounted)->float:
	if not globe:return Vector2(ship.position.x,ship.position.z).length()
	var ll:=geographic_position(ship)
	var saved_lat:float=globe.latitude;var saved_lon:float=globe.longitude
	globe.latitude=ll[0];globe.longitude=ll[1]
	var result:float=globe.distance_to(globe.pad_latitude,globe.pad_longitude)
	globe.latitude=saved_lat;globe.longitude=saved_lon
	return result
func recenter(ship:RefCounted)->void:
	if not globe:return
	var altitude_now:=altitude(ship)
	var ll: Array=geographic_position(ship)
	var old_basis:Basis=globe.basis_at(globe.latitude,globe.longitude)
	var next_basis:Basis=globe.basis_at(ll[0],ll[1])
	frame_rotation=(next_basis.transposed()*old_basis).get_rotation_quaternion().normalized()
	rebase_from=ship.position
	globe.latitude=ll[0];globe.longitude=ll[1];frame_index+=1
	ship.position=Vector3(0,height_at(0,0)+clearance(ship)+altitude_now,0)
	ship.velocity=frame_rotation*ship.velocity
	ship.attitude=(frame_rotation*ship.attitude).normalized()
	rebase_to=ship.position
func _restore_globe(data:Dictionary,ship:RefCounted,system:RefCounted,maximum_height:=4001.0)->bool:
	if data.get("layout")!="globe_v1" or data.get("terrain_revision")!=SphereTerrain.REVISION:return false
	if not data.get("active") is bool or not data.active or not data.get("landed") is bool or data.get("body_id")!=system.focus_id:return false
	if ship.docked or str(system.by_id[system.focus_id].kind) in ["gas","ice_gas","star","barycenter"]:return false
	for key in ["latitude","longitude"]:
		if not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])):return false
	if absf(float(data.latitude))>PI*0.5 or float(data.longitude)< -PI or float(data.longitude)>PI:return false
	for key in ["orbit_position","orbit_attitude"]:
		if not data.get(key) is Array or data[key].size()!=(4 if key=="orbit_attitude" else 3):return false
		for value in data[key]:
			if not (value is float or value is int) or not is_finite(float(value)) or absf(float(value))>1e9:return false
	var rotation:=Quaternion(data.orbit_attitude[0],data.orbit_attitude[1],data.orbit_attitude[2],data.orbit_attitude[3])
	if rotation.length_squared()<0.01 or not ship.position.is_finite() or not ship.velocity.is_finite():return false
	if Vector2(ship.position.x,ship.position.z).length()>REBASE_DISTANCE+20:return false
	var candidate:RefCounted=get_script().new()
	candidate.globe=SphereTerrain.new();candidate.globe.configure(system,system.focus_id,system.site_id)
	candidate.globe.latitude=float(data.latitude);candidate.globe.longitude=float(data.longitude)
	candidate.seed_value=system.system_id^system.focus_id.hash()
	var site:Dictionary=system.current_site()
	if not site.is_empty() and int(site.type_code)==35:
		candidate.site_name=str(site.name);candidate.seed_value^=system.site_id.hash()
	var height:float=candidate.altitude(ship)
	if height< -1 or height>maximum_height or candidate.overlaps_building(ship):return false
	if data.landed and (absf(height)>1 or ship.velocity.length()>0.1):return false
	orbit_link={}
	extended_flight=false;flight_phase="";ready_for_orbit=false
	globe=candidate.globe;seed_value=candidate.seed_value;site_name=candidate.site_name
	frame_index=0;active=true;landed=data.landed;landing=false;taking_off=false;body_id=system.focus_id
	kind=str(system.by_id[body_id].kind)
	gravity=G*float(system.by_id[body_id].mass_solar)*SOLAR_MASS/pow(float(system.by_id[body_id].radius_km)*1000,2)
	orbit_position=Vector3(data.orbit_position[0],data.orbit_position[1],data.orbit_position[2]);orbit_attitude=rotation.normalized()
	ship.surface_mode=true
	return true

func enter_from_orbit(ship:RefCounted,system:RefCounted,days:float)->bool:
	if not OrbitLink.matches(orbit_link,system):return enter(ship,system,true)
	message=entry_error(ship,system)
	if not message.is_empty():return false
	var ll:Array=OrbitLink.coordinates(orbit_link,ship,system,days)
	if ll.is_empty():message="Невозможно определить точку входа над планетой.";return false
	var anchor:String=orbit_link.site_id
	var previous_site:String=system.site_id
	system.site_id=anchor
	if not enter(ship,system,true):system.site_id=previous_site;return false
	globe.latitude=ll[0];globe.longitude=ll[1];frame_index+=1
	ship.position=Vector3(0,height_at(0,0)+clearance(ship)+1500,0)
	ship.velocity=Vector3.ZERO;ship.target_speed=0;ship.attitude=Quaternion(Vector3.RIGHT,-0.35)
	message="Вход над текущей точкой планеты. До исходной площадки %.1f км."%(pad_distance(ship)/1000.0)
	return true

func cancel_vertical()->void:
	if not flight_phase.is_empty():message="Вертикальный автополёт отменён. Торможение доступно отдельной кнопкой."
	flight_phase="";ready_for_orbit=false
func begin_ascent(ship:RefCounted)->bool:
	if not active or not globe or landed or ship.hull<=0 or altitude(ship)<500 or ship.velocity.length()>20:
		message="Для автоподъёма: высота от 500 м, скорость до 20 м/с."
		return false
	extended_flight=true;flight_phase="ascent";ready_for_orbit=false;landing=false;taking_off=false
	ship.assisted=true;ship.target_speed=0;ship.autopilot=false
	message="Автоподъём к 20 км. «Тормозить» или ручное управление отменяют подъём."
	return true
func begin_descent(ship:RefCounted,system:RefCounted,days:float)->bool:
	if not is_finite(days):message="Невозможно определить время входа.";return false
	message=entry_error(ship,system)
	if not message.is_empty():return false
	var linked:=OrbitLink.matches(orbit_link,system)
	var height:float=ship.position.distance_to(system.local_meters(system.focus_id,days))-float(system.by_id[system.focus_id].radius_km)*1000.0
	# Distant, previously unlinked district visits retain the existing fast approach.
	# Nearby first arrivals use the same physical geographic descent as return flights.
	if not linked and height>MAX_DESCENT_HEIGHT:return enter(ship,system,true)
	if height>MAX_DESCENT_HEIGHT or height<MIN_DESCENT_HEIGHT:
		message="Для автоспуска подойдите на высоту от 1,8 до 60 км над планетой."
		return false
	var ll:Array=OrbitLink.coordinates(orbit_link,ship,system,days)
	if ll.is_empty():message="Невозможно определить точку входа над планетой.";return false
	var anchor:String=OrbitLink.anchor(orbit_link,system)
	var velocity:Vector3=ship.velocity
	var attitude:Quaternion=ship.attitude
	var previous_site:String=system.site_id
	system.site_id=anchor
	if not enter(ship,system,true):system.site_id=previous_site;return false
	globe.latitude=ll[0];globe.longitude=ll[1];frame_index+=1
	var world_basis:Basis=Basis(Vector3.UP,OrbitLink.spin(system.by_id[body_id],days))*globe.basis_at(ll[0],ll[1])
	ship.position=Vector3(0,height,0)
	ship.velocity=world_basis.inverse()*velocity
	ship.attitude=(world_basis.inverse()*Basis(attitude)).get_rotation_quaternion().normalized()
	extended_flight=true;flight_phase="descent"
	message="Управляемый спуск к высоте 1500 м. «Тормозить» отменяет спуск."
	return true
func resume_descent(ship:RefCounted)->bool:
	if not active or not globe or landed or ship.hull<=0:return false
	extended_flight=true;flight_phase="descent";ready_for_orbit=false;landing=false;taking_off=false
	ship.assisted=true;ship.target_speed=0;ship.autopilot=false
	message="Управляемое снижение к 1500 м."
	return true
func _step_vertical(dt:float,ship:RefCounted)->void:
	var height:=altitude(ship)
	var target:=1500.0
	if flight_phase=="ascent":
		var ll:Array=geographic_position(ship)
		target=OrbitLink.ALTITUDE-globe.elevation(ll[0],ll[1])-clearance(ship)
	var error:=target-height
	var reserve:=maxf(0.1,ship.acceleration()-gravity)
	var speed:=minf(300.0,sqrt(2.0*reserve*absf(error))*0.65)
	ship.velocity=ship.velocity.move_toward(Vector3.UP*signf(error)*speed,reserve*dt)
	ship.attitude=ship.attitude.slerp(Quaternion(Vector3.RIGHT,0.15 if flight_phase=="ascent" else -0.35),minf(1,dt)).normalized()
	ship.position+=ship.velocity*dt
	if absf(error)<0.6 and ship.velocity.length()<2:
		ship.position.y=height_at(ship.position.x,ship.position.z)+clearance(ship)+target
		ship.velocity=Vector3.ZERO
		if flight_phase=="ascent":ready_for_orbit=true
		else:
			flight_phase="";message="Спуск завершён. Можно лететь вручную или включить автопосадку."
