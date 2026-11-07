extends RefCounted
# One coordinator for selected source orbital-port context. World owns spin,
# door and persistence; Flight owns collision/approach. No geometry enters saves.
const Flight=preload("res://scripts/flight_model.gd")
const Geometry=preload("res://scripts/source_station_geometry.gd")
const FULL_LAYOUT:="source_jjffe_systems_v4"
const CONTRACT:="selected-source-station-session-v1"

static func _number(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value))

static func _whole(value:Variant,maximum:int)->bool:
	return _number(value) and float(value)>=0 and float(value)<=maximum and float(value)==floorf(float(value))

static func _record(value:Variant)->PackedByteArray:
	if not value is String or value.length()!=136 or not value.is_valid_hex_number(false):return PackedByteArray()
	return value.hex_decode()

static func _existing_geometry(ship:RefCounted,world:RefCounted,raw:PackedByteArray,days:float)->Dictionary:
	# The immutable model/UID/door identity determines the compiled solids.
	# Reuse Flight's already validated pack; avoid copying thousands of triangles
	# every frame just to update the nine-value spin basis.
	if not world.has_method("source_station_state"):return {}
	var state:Variant=world.source_station_state(days)
	var existing:Variant=ship.get("_source_station")
	if not state is Dictionary or state.get("site_id")!=world.get("site_id") or not _whole(state.get("door_u16"),65535) or not existing is Dictionary or existing.is_empty():return {}
	if existing.get("model_index")!=int(raw.decode_u16(12)) or existing.get("source_seed")!=int(raw.decode_u32(4)) or existing.get("door_u16")!=int(state.door_u16):return {}
	return existing

static func _clear(ship:RefCounted,nav:RefCounted,full:bool)->void:
	if ship!=null and ship.has_method("clear_source_station"):
		ship.clear_source_station()
		if full:ship.station_available=false;ship.autopilot=false
	if nav!=null and nav.has_method("set_source_port_available"):nav.set_source_port_available(false)

static func _result(ok:bool,active:bool,handled:bool,status:String)->Dictionary:
	return {"ok":ok,"active":active,"handled":handled,"status":status,"contract":CONTRACT}

static func configure_flight(ship:RefCounted,world:RefCounted,nav:RefCounted,step_seconds:=0.0)->Dictionary:
	var full:bool=world!=null and world.get("layout_mode")==FULL_LAYOUT
	if ship==null or world==null or nav==null or not ship.has_method("clear_source_station") or not ship.has_method("configure_source_station") or not nav.has_method("set_source_port_available"):
		_clear(ship,nav,full);return _result(false,false,full,"invalid_models")
	if ship.get("source_motion_profile") is bool:ship.source_motion_profile=full
	if not full:
		_clear(ship,nav,false);return _result(true,false,false,"legacy_layout")
	# A full source world may never retain the adapted invisible station sphere.
	if not nav.has_method("is_native") or not nav.is_native() or nav.get("current_id")!=world.get("system_id") or not _number(nav.get("elapsed_days")) or float(nav.elapsed_days)<0:
		_clear(ship,nav,true);return _result(false,false,true,"invalid_navigation")
	for method in ["current_site","is_orbital_site","source_station_geometry","source_station_basis"]:
		if not world.has_method(method):
			_clear(ship,nav,true);return _result(false,false,true,"missing_world_api")
	var site:Variant=world.current_site()
	if not site is Dictionary:
		_clear(ship,nav,true);return _result(false,false,true,"invalid_site")
	ship.original_port=not site.is_empty()
	if not world.is_orbital_site():
		_clear(ship,nav,true);return _result(true,false,true,"no_orbital_site")
	if not world.get("site_id") is String or world.site_id.is_empty() or site.get("id")!=world.site_id or not _whole(site.get("type_code"),65535) or not _whole(site.get("model_index"),65535):
		_clear(ship,nav,true);return _result(false,false,true,"invalid_site")
	if int(site.type_code) not in [32,33,34] or int(site.model_index) not in Geometry.MODELS:
		_clear(ship,nav,true);return _result(false,false,true,"invalid_site")
	var raw:=_record(site.get("runtime_record_hex"))
	if raw.size()!=68 or int(raw.decode_u16(10))!=int(site.type_code) or int(raw.decode_u16(12))!=int(site.model_index):
		_clear(ship,nav,true);return _result(false,false,true,"invalid_site_record")
	var geometry:Variant=_existing_geometry(ship,world,raw,float(nav.elapsed_days))
	if geometry.is_empty():geometry=world.source_station_geometry(float(nav.elapsed_days))
	var basis:Variant=world.source_station_basis(float(nav.elapsed_days))
	if not geometry is Dictionary or not basis is Basis or geometry.is_empty() or not _whole(geometry.get("model_index"),65535) or not _whole(geometry.get("source_seed"),0xffffffff):
		_clear(ship,nav,true);return _result(false,false,true,"invalid_source_geometry")
	if int(geometry.model_index)!=int(raw.decode_u16(12)) or int(geometry.source_seed)!=int(raw.decode_u32(4)) or not ship.configure_source_station(geometry,basis,step_seconds):
		_clear(ship,nav,true);return _result(false,false,true,"invalid_source_geometry")
	ship.station_available=true;nav.set_source_port_available(true)
	var result:=_result(true,true,true,"configured")
	result["site_id"]=str(site.id);result["model_index"]=int(geometry.model_index);result["source_seed"]=int(geometry.source_seed)
	result["door_u16"]=int(geometry.door_u16);result["descriptor_sha256"]=str(geometry.descriptor_sha256)
	return result

static func refresh(ship:RefCounted,world:RefCounted,nav:RefCounted,dt:Variant)->Dictionary:
	var full:bool=world!=null and world.get("layout_mode")==FULL_LAYOUT
	if not full:return configure_flight(ship,world,nav)
	if nav==null or not _number(dt) or float(dt)<0 or not _number(nav.get("elapsed_days")) or not world.has_method("advance_station"):
		_clear(ship,nav,true);return _result(false,false,true,"invalid_step")
	if not world.advance_station(float(dt),float(nav.elapsed_days)):
		_clear(ship,nav,true);return _result(false,false,true,"station_step_failed")
	return configure_flight(ship,world,nav,float(dt))

static func restore_flight(world:RefCounted,nav:RefCounted,data:Dictionary)->Dictionary:
	# The supplied World and Navigation are already restored isolated candidates.
	# Allocate Flight here so rejection never mutates an existing live ship.
	var candidate:=Flight.new()
	var context:=configure_flight(candidate,world,nav)
	if not context.ok:return {}
	var source_save:bool=data.get("version")==5
	if source_save!=bool(context.active):return {}
	# Dock capture allows a slow approach; a committed dock save is already at
	# rest in the centre. Check before configure can follow/snap a docked pose.
	if source_save and data.get("docked")==true:
		for field in ["position","velocity"]:
			if not data.get(field) is Array or data[field].size()!=3:return {}
			for value in data[field]:
				if not _number(value):return {}
		if not _number(data.get("target_speed")):return {}
		var saved_position:=Vector3(data.position[0],data.position[1],data.position[2])
		var saved_velocity:=Vector3(data.velocity[0],data.velocity[1],data.velocity[2])
		if saved_position.distance_to(Flight.STATION)>0.01 or saved_velocity.length()>0.001 or absf(float(data.target_speed))>0.001:return {}
	if not candidate.restore(data):return {}
	# Flight.restore intentionally clears runtime availability flags. Re-derive
	# them from the same validated world instead of trusting saved booleans.
	context=configure_flight(candidate,world,nav)
	if not context.ok:return {}
	return {"ok":true,"ship":candidate,"context":context}

static func diagnostics(ship:RefCounted,world:RefCounted,nav:RefCounted)->Dictionary:
	var result:={"contract":CONTRACT,"layout":str(world.get("layout_mode")) if world!=null else "","active":ship!=null and ship.has_method("has_source_station") and ship.has_source_station(),"site_id":str(world.get("site_id")) if world!=null else ""}
	if ship!=null and ship.has_method("source_station_state"):result["flight_context"]=ship.source_station_state().duplicate(true)
	if world!=null and nav!=null and world.get("layout_mode")==FULL_LAYOUT and _number(nav.get("elapsed_days")) and world.has_method("source_station_state"):
		var state:Variant=world.source_station_state(float(nav.elapsed_days))
		if state is Dictionary:result["world_context"]=state.duplicate(true)
	return result
