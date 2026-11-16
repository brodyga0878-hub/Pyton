extends RefCounted
# Explicit bounded handoff between two non-rotating, moving source origins.
# The original ephemeris supplies the translation and its sampled derivative;
# this is not the unported F570/F606 reference-frame/object-bank dispatcher.
const Orbit=preload("res://scripts/native_orbit_trial.gd")
const Trial=preload("res://scripts/native_landing_trial.gd")
const World=preload("res://scripts/planetary_system.gd")
const Flight=preload("res://scripts/flight_model.gd")
const Surface=preload("res://scripts/surface_model.gd")
const Station=preload("res://scripts/source_station_session.gd")
const Geometry=preload("res://scripts/source_station_geometry.gd")
const Ephemeris=preload("res://scripts/source_orbit.gd")
const Clock=preload("res://scripts/source_clock.gd")
const Units=preload("res://scripts/source_units.gd")
const Physics=preload("res://scripts/source_physics_bridge.gd")
const POLICY:="bounded-source-station-origin-handoff-v1"
const VELOCITY_POLICY:="source-ephemeris-origin-derivative-one-second-v1"
const MAX_DISTANCE_M:=100000.0
const MAX_LOCAL_M:=1000000000.0
const MAX_INT:=9223372036854775807
const MIN_INT:=-9223372036854775807-1
const RELATIVE_CACHE_LIMIT:=256
static var _relative_cache:Dictionary={}
static var _relative_cache_order:Array[String]=[]
static var _relative_cache_mutex:=Mutex.new()

static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"policy":POLICY,"clock_advanced":false,"fuel_advanced":false,"hp_applied":false,"position_snapped":false}
static func _record(object:Dictionary)->PackedByteArray:
	var text:Variant=object.get("runtime_record_hex")
	return str(text).hex_decode() if text is String and Orbit._hex(text,68) else PackedByteArray()
static func _world_valid(world:RefCounted)->bool:
	return world!=null and world.get_script()==World and world.layout_mode==World.FULL_LAYOUT and not str(world.source_digest).is_empty() and world.by_id.has(str(world.focus_id)) and world.transfer_remaining==0 and world.pending_id.is_empty() and world.pending_site_id.is_empty() and _record(world.by_id[str(world.focus_id)]).size()==68
static func _site(world:RefCounted,id:String)->Dictionary:
	var site:Dictionary=world.get_site(id)
	var raw:=_record(site)
	if site.is_empty() or str(site.get("parent",""))!=str(world.focus_id) or int(site.get("type_code",-1)) not in [32,33,34] or int(site.get("model_index",-1)) not in Geometry.MODELS or raw.size()!=68:return {}
	if int(raw.decode_u16(10))!=int(site.type_code) or int(raw.decode_u16(12))!=int(site.model_index):return {}
	return site
static func _relative(record:PackedByteArray,clock:Dictionary)->PackedInt64Array:
	if record.size()!=68:return PackedInt64Array()
	# Cache only the pure source-record/clock result, never a World or a mutable
	# returned buffer. No hit/miss or eviction detail enters a sealed receipt.
	var key:="%s:%d:%d"%[record.hex_encode(),int(clock.day_u32),int(clock.tick_u32)]
	_relative_cache_mutex.lock()
	if _relative_cache.has(key):
		var cached:PackedInt64Array=_relative_cache[key].duplicate()
		_relative_cache_mutex.unlock()
		return cached
	_relative_cache_mutex.unlock()
	var value:Dictionary=Ephemeris.evaluate_from_epoch(record,int(clock.tick_u32),int(clock.day_u32),Clock.EPOCH_TICK_U32,Clock.EPOCH_DAY_U32)
	var point:PackedInt64Array=value.get("position_raw",PackedInt64Array())
	if point.size()!=3:return PackedInt64Array()
	_relative_cache_mutex.lock()
	if not _relative_cache.has(key):
		while _relative_cache_order.size()>=RELATIVE_CACHE_LIMIT:
			_relative_cache.erase(_relative_cache_order.pop_front())
		_relative_cache[key]=point.duplicate();_relative_cache_order.append(key)
	_relative_cache_mutex.unlock()
	return point.duplicate()
static func _raw_origin(world:RefCounted,clock:Dictionary)->PackedInt64Array:
	# Reproduce World's source-origin law without touching its live cache/spin.
	var chain:Array[PackedByteArray]=[];var seen:Dictionary={};var cursor:=str(world.focus_id)
	for _depth in range(64):
		if cursor.is_empty():break
		if seen.has(cursor) or not world.by_id.has(cursor):return PackedInt64Array()
		seen[cursor]=true
		var object:Dictionary=world.by_id[cursor];var record:=_record(object)
		if record.size()!=68:return PackedInt64Array()
		chain.push_front(record);cursor=str(object.get("parent",""))
	if not cursor.is_empty():return PackedInt64Array()
	var origin:=PackedInt64Array([0,0,0])
	for record:PackedByteArray in chain:
		var point:=_relative(record,clock)
		if point.size()!=3:return PackedInt64Array()
		origin=Ephemeris.add_positions(origin,point)
	if not str(world.site_id).is_empty():
		var site:=_site(world,str(world.site_id))
		if site.is_empty():return PackedInt64Array()
		var relative:=_relative(_record(site),clock)
		if relative.size()!=3:return PackedInt64Array()
		origin=Ephemeris.add_positions(origin,relative)
		return Ephemeris.add_positions(origin,Physics.relative_from_metres(-World.ORBITAL_DOCK_LOCAL))
	var radius:float=float(world.by_id[str(world.focus_id)].radius_km)*1000.0
	if not is_finite(radius) or radius<=0:return PackedInt64Array()
	return Ephemeris.add_positions(origin,Physics.relative_from_metres(-World.ARRIVAL_DIRECTION.normalized()*maxf(radius*4.0,3000000.0)))
static func _difference(first:PackedInt64Array,second:PackedInt64Array)->PackedInt64Array:
	if first.size()!=3 or second.size()!=3:return PackedInt64Array()
	var result:=PackedInt64Array()
	for axis in range(3):
		var a:int=first[axis];var b:int=second[axis]
		if (b>0 and a<MIN_INT+b) or (b<0 and a>MAX_INT+b):return PackedInt64Array()
		result.append(a-b)
	return result
static func _raw_hex(values:PackedInt64Array)->String:
	var bytes:=PackedByteArray();bytes.resize(values.size()*8)
	for axis in range(values.size()):bytes.encode_s64(axis*8,values[axis])
	return bytes.hex_encode()
static func _delta(from_world:RefCounted,to_world:RefCounted,clock:Dictionary)->Dictionary:
	var first:=_raw_origin(from_world,clock);var second:=_raw_origin(to_world,clock);var raw:=_difference(first,second)
	if raw.size()!=3:return _reject("station_origin_difference_unavailable_or_overflow")
	var metres:=PackedFloat64Array()
	for value:int in raw:
		var converted:=Units.metres(float(value))
		if not is_finite(converted) or absf(converted)>MAX_LOCAL_M:return _reject("station_origin_difference_outside_supported_range")
		metres.append(converted)
	return {"ok":true,"metres":metres,"raw":raw,"from_raw_hex":_raw_hex(first),"to_raw_hex":_raw_hex(second),"delta_raw_hex":_raw_hex(raw)}

static func offset(from_world:RefCounted,to_world:RefCounted,days:float)->Dictionary:
	if not _world_valid(from_world) or not _world_valid(to_world) or int(from_world.system_id)!=int(to_world.system_id) or str(from_world.source_digest)!=str(to_world.source_digest) or str(from_world.focus_id)!=str(to_world.focus_id) or _record(from_world.by_id[str(from_world.focus_id)])!=_record(to_world.by_id[str(to_world.focus_id)]):return _reject("incompatible_source_station_frames")
	var now:=Clock.from_elapsed_days(days)
	if now.is_empty():return _reject("invalid_station_frame_clock")
	var half_day:=0.5/86400.0
	var low:=maxf(0.0,days-half_day);var high:=minf(Clock.MAX_ELAPSED_DAYS,days+half_day)
	if low==days:high=minf(Clock.MAX_ELAPSED_DAYS,days+1.0/86400.0)
	if high==days:low=maxf(0.0,days-1.0/86400.0)
	var before:=Clock.from_elapsed_days(low);var after:=Clock.from_elapsed_days(high)
	if before.is_empty() or after.is_empty():return _reject("station_velocity_sample_unavailable")
	var ticks:int=(int(after.day_u32)-int(before.day_u32))*Clock.TICKS_PER_DAY+int(after.tick_u32)-int(before.tick_u32)
	var seconds:=float(ticks)*86400.0/float(Clock.TICKS_PER_DAY)
	if not is_finite(seconds) or seconds<=0 or seconds>1.1:return _reject("invalid_station_velocity_sample_spacing")
	var current:=_delta(from_world,to_world,now);var previous:=_delta(from_world,to_world,before);var next:=_delta(from_world,to_world,after)
	if not current.get("ok",false):return current
	if not previous.get("ok",false):return previous
	if not next.get("ok",false):return next
	var raw_change:=_difference(next.raw,previous.raw)
	if raw_change.size()!=3:return _reject("station_velocity_difference_overflow")
	var velocity:=PackedFloat64Array()
	for axis in range(3):
		var speed:float=Units.metres(float(raw_change[axis]))/seconds
		if not is_finite(speed) or absf(speed)>MAX_LOCAL_M:return _reject("station_origin_velocity_outside_supported_range")
		velocity.append(speed)
	var receipt:=Orbit._json({"policy":POLICY,"velocity_policy":VELOCITY_POLICY,"system_id":int(from_world.system_id),"body_id":str(from_world.focus_id),"source_digest":str(from_world.source_digest),"source_record_hex":_record(from_world.by_id[str(from_world.focus_id)]).hex_encode(),"from_site_id":str(from_world.site_id),"to_site_id":str(to_world.site_id),"source_days_f64_hex":Orbit._float(days),"from_origin_raw_s64_hex":current.from_raw_hex,"to_origin_raw_s64_hex":current.to_raw_hex,"origin_difference_raw_s64_hex":current.delta_raw_hex,"position_delta_f64_hex":Orbit.NativeSurface._native_floats(Array(current.metres),8),"velocity_delta_f64_hex":Orbit.NativeSurface._native_floats(Array(velocity),8),"sample_days_before_f64_hex":Orbit._float(low),"sample_days_after_f64_hex":Orbit._float(high),"sample_clock_before":{"day_u32":int(before.day_u32),"tick_u32":int(before.tick_u32)},"sample_clock_after":{"day_u32":int(after.day_u32),"tick_u32":int(after.tick_u32)},"sample_seconds_f64_hex":Orbit._float(seconds),"sample_origin_difference_before_raw_s64_hex":previous.delta_raw_hex,"sample_origin_difference_after_raw_s64_hex":next.delta_raw_hex,"axes_rotated":false,"omega_cross_radius_added":false,"full_original_object_bank":false})
	return {"ok":true,"policy":POLICY,"position_delta_f64":current.metres.duplicate(),"velocity_delta_f64":velocity,"receipt":receipt}

static func map_between(from_world:RefCounted,to_world:RefCounted,position_f64:PackedFloat64Array,velocity:Vector3,days:float)->Dictionary:
	if position_f64.size()!=3 or not velocity.is_finite():return _reject("invalid_station_mapping_pose")
	for value:float in position_f64:
		if not is_finite(value) or absf(value)>MAX_LOCAL_M:return _reject("invalid_station_mapping_position")
	var shift:=offset(from_world,to_world,days)
	if not shift.get("ok",false):return shift
	var position:=PackedFloat64Array();var speed:=PackedFloat64Array()
	for axis in range(3):
		var point:float=position_f64[axis]+float(shift.position_delta_f64[axis]);var moved:float=float(velocity[axis])+float(shift.velocity_delta_f64[axis])
		if not is_finite(point) or absf(point)>MAX_LOCAL_M or not is_finite(moved) or absf(moved)>MAX_LOCAL_M:return _reject("mapped_station_pose_outside_supported_range")
		position.append(point);speed.append(moved)
	return {"ok":true,"policy":POLICY,"position_f64":position,"velocity_f64":speed,"position_delta_f64":shift.position_delta_f64,"velocity_delta_f64":shift.velocity_delta_f64,"receipt":shift.receipt.duplicate(true)}

static func prepare(orbit:RefCounted,ship:RefCounted,nav:RefCounted,gear:RefCounted,world:RefCounted,site_id:String)->Dictionary:
	if orbit==null or orbit.get_script()!=Orbit or not orbit.is_active() or not orbit._matches(ship,nav,world,gear) or not Orbit._valid(ship,nav,world):return _reject("invalid_bound_native_station_owners")
	var site:=_site(world,site_id)
	if site.is_empty():return _reject("unsupported_or_nonlocal_orbital_station")
	var cs:=Trial._fork_ship(ship);var cn:RefCounted=nav.fork_runtime();var cg:=Orbit._fork_gear(gear);var cw:=Orbit._fork_world(world)
	if cs==null or cn==null or cg==null or cw==null:return _reject("station_frame_fork_failed")
	cw.site_id=site_id;cw.selected_id=str(site.parent);cw.pending_id="";cw.pending_site_id="";cw.transfer_remaining=0
	var mapped:=map_between(world,cw,orbit._position_f64,ship.velocity,nav.elapsed_days)
	if not mapped.get("ok",false):return mapped
	var square:=0.0
	for axis in range(3):square+=pow(float(mapped.position_f64[axis])-float(Flight.STATION[axis]),2)
	var distance:=sqrt(square)
	if not is_finite(distance) or distance>MAX_DISTANCE_M:return _reject("station_is_not_within_100km_manual_approach")
	# Admission probes run on a private body-frame World, with canonical body
	# velocity. A station-relative speed must never create false atmosphere heat.
	var guard_world:=Orbit._fork_world(world);var inactive:=Surface.new();inactive.body_id=str(world.focus_id)
	var clearance:=Orbit._guard(guard_world,cs,nav.elapsed_days)
	if not clearance.get("ok",false):return _reject("station_handoff_requires_safe_body_clearance")
	var atmosphere:Dictionary=Orbit.Atmosphere.new().sample(guard_world,cs,inactive,nav.elapsed_days,bool(cg.state().get("f1014_raw_gear_flag",false)))
	if not atmosphere.get("ok",false) or bool(atmosphere.get("apply_f1014",true)):return _reject("station_handoff_requires_outside_source_atmosphere")
	cs.position=Vector3(mapped.position_f64[0],mapped.position_f64[1],mapped.position_f64[2]);cs.velocity=Vector3(mapped.velocity_f64[0],mapped.velocity_f64[1],mapped.velocity_f64[2])
	cs.surface_mode=false;cs.station_available=false;cs.clear_source_station()
	if not Trial._finite_ship(cs) or not Orbit.NativeSurface._native_pose_valid(Orbit._pose(cs)):return _reject("invalid_station_handoff_pose")
	var context:=Station.configure_flight(cs,cw,cn)
	cs.source_motion_profile=ship.source_motion_profile
	if not context.get("ok",false) or not context.get("active",false) or not cn.bind_thermal_ship(cs) or not cn.apply_fuel_availability(cs) or not cn.validate_source_ship(cs):return _reject("station_context_or_source_owner_rejected")
	var receipt:=Orbit._json({"schema":"starfrontier-native-station-frame-handoff-v1","policy":POLICY,"velocity_policy":VELOCITY_POLICY,"system_id":int(cw.system_id),"body_id":str(cw.focus_id),"site_id":site_id,"source_digest":str(cw.source_digest),"source_record_hex":_record(cw.by_id[str(cw.focus_id)]).hex_encode(),"station_record_hex":_record(site).hex_encode(),"source_pose_f32_hex":Orbit._pose(ship),"station_pose_f32_hex":Orbit._pose(cs),"ideal_position_f64_hex":Orbit.NativeSurface._native_floats(Array(mapped.position_f64),8),"ideal_velocity_f64_hex":Orbit.NativeSurface._native_floats(Array(mapped.velocity_f64),8),"source_days_f64_hex":Orbit._float(nav.elapsed_days),"mapping":mapped.receipt,"station_context":context,"legacy_orbit_guard":clearance.sample,"source_atmosphere":{"apply_f1014":false,"contract":str(atmosphere.get("source_contract",""))},"distance_to_station_m":distance,"thrust_profile_enabled":bool(ship.source_motion_profile),"clock_advanced":false,"fuel_advanced":false,"hp_applied":false,"position_snapped":false,"full_original_object_bank":false,"ongoing_station_law":"existing-station-following-mobile-flight-not-inertial-trajectory-equivalence"})
	return {"ok":true,"reason":"native_station_frame_prepared","policy":POLICY,"candidate_ship":cs,"candidate_nav":cn,"candidate_gear":cg,"candidate_world":cw,"candidate_surface":inactive,"candidate_position_f64":mapped.position_f64.duplicate(),"candidate_velocity_f64":mapped.velocity_f64.duplicate(),"receipt":receipt,"save_after":true}
