extends RefCounted
# Bounded continuation in the existing station-following mobile flight frame.
# The same-time boundary is continuous; this is not the full F570/F606 bank.
const Frame=preload("res://scripts/native_station_frame.gd")
const Orbit=preload("res://scripts/native_orbit_trial.gd")
const Trial=preload("res://scripts/native_landing_trial.gd")
const NativeSurface=preload("res://scripts/native_surface_model.gd")
const Surface=preload("res://scripts/surface_model.gd")
const World=preload("res://scripts/planetary_system.gd")
const Flight=preload("res://scripts/flight_model.gd")
const Navigation=preload("res://scripts/navigation.gd")
const Gear=preload("res://scripts/source_landing_gear_session.gd")
const Station=preload("res://scripts/source_station_session.gd")
const Geometry=preload("res://scripts/source_station_geometry.gd")
const Dynamics=preload("res://scripts/rotating_dock_dynamics.gd")
const SourceClock=preload("res://scripts/source_clock.gd")
const Atmosphere=preload("res://scripts/source_atmosphere_contact.gd")
const Fuel=preload("res://scripts/source_fuel_flight_bridge.gd")
const SCHEMA:="starfrontier-native-station-trial-v1"
const POLICY:="bounded-native-station-following-atomic-flight-v1"
const MAX_SECONDS:=0.1
const KEYS:=["schema","version","policy","origin","origin_sha256","entry_receipt","generation","pose_f32_hex","position_f64_hex","elapsed_days_f64_hex","legacy_pose_anchor","legacy_days_anchor","motion","motion_history","motion_override","owners","snapshot_sha256"]
const MOTION_KEYS:=["autopilot","pilot_phase","basis_f32_hex","previous_basis_f32_hex","step_f64_hex","angular_f32_hex","ship_angular_f32_hex","sample_valid","motion_pending","last_collision"]
var _origin:Dictionary={}
var _entry:Dictionary={}
var _history:Dictionary={}
var _motion_override:="none"
var _generation:=0
var _position_f64:=PackedFloat64Array()
var _pose_hex:=""
var _days_hex:=""
var _owners:Dictionary={}
var last_error:=""

class BodyProbe extends RefCounted:
	# Only the immutable scalar inputs consumed by the three read-only probes.
	# This owns no station geometry and can never modify a physical Flight.
	var position:=Vector3.ZERO
	var velocity:=Vector3.ZERO
	var hull:=100.0
	var docked:=false
	var surface_mode:=false

static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"policy":POLICY,"clock_advanced":false,"fuel_advanced":false,"hp_applied":false,"position_snapped":false}
static func _hexfloat(value:float)->String:return Orbit._float(value)
static func _decode_float(value:Variant)->float:return str(value).hex_decode().decode_double(0) if Orbit._hex(value,8) else NAN
static func _vec(value:Vector3)->String:return NativeSurface._native_floats([value.x,value.y,value.z],4)
static func _read_vec(value:Variant)->Vector3:
	if not Orbit._hex(value,12):return Vector3(NAN,NAN,NAN)
	var v:Array=NativeSurface._native_numbers(str(value),4);return Vector3(v[0],v[1],v[2])
static func _basis_hex(value:Basis)->String:return NativeSurface._native_floats(Orbit._basis_values(value),4)
static func _read_basis(value:Variant)->Basis:
	if not Orbit._hex(value,36):return Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
	var v:Array=NativeSurface._native_numbers(str(value),4);return Basis(Vector3(v[0],v[1],v[2]),Vector3(v[3],v[4],v[5]),Vector3(v[6],v[7],v[8]))
static func _qhex(value:Quaternion)->String:return NativeSurface._native_floats([value.x,value.y,value.z,value.w],4)
static func _read_q(value:Variant)->Quaternion:
	if not Orbit._hex(value,16):return Quaternion(0,0,0,0)
	var v:Array=NativeSurface._native_numbers(str(value),4);return Quaternion(v[0],v[1],v[2],v[3])
static func _keys(data:Dictionary,keys:Array)->bool:return Orbit.Session._keys(data,keys)
static func _legacy_vectors_match(ship:RefCounted,anchor:Dictionary)->bool:
	if not _keys(anchor,["position","velocity","attitude"]):return false
	for key:String in ["position","velocity","attitude"]:
		if not anchor[key] is Array or anchor[key].size()!=(4 if key=="attitude" else 3):return false
		for value:Variant in anchor[key]:
			if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value))>1e9:return false
	return ship.position==Vector3(anchor.position[0],anchor.position[1],anchor.position[2]) and ship.velocity==Vector3(anchor.velocity[0],anchor.velocity[1],anchor.velocity[2])
static func _collision_snapshot(ship:RefCounted)->Dictionary:
	var data:Dictionary=ship._source_last_collision.duplicate(true);var vectors:Dictionary={}
	for key:String in ["station_surface_velocity_mps","contact_point_m","relative_contact_velocity_mps"]:
		if data.get(key) is Vector3:vectors[key]=_vec(data[key]);data.erase(key)
	return {"data":Orbit._json(data),"vector_f32_hex":vectors}
static func _collision_restore(value:Variant)->Dictionary:
	if not value is Dictionary or not _keys(value,["data","vector_f32_hex"]) or not value.data is Dictionary or not value.vector_f32_hex is Dictionary or not Orbit._plain(value.data):return {"ok":false}
	var result:Dictionary=value.data.duplicate(true)
	for key:Variant in value.vector_f32_hex:
		if key not in ["station_surface_velocity_mps","contact_point_m","relative_contact_velocity_mps"] or not Orbit._hex(value.vector_f32_hex[key],12):return {"ok":false}
		var v:=_read_vec(value.vector_f32_hex[key]);if not v.is_finite():return {"ok":false}
		result[key]=v
	return {"ok":true,"data":result}
static func _motion(ship:RefCounted)->Dictionary:
	return {"autopilot":ship.autopilot,"pilot_phase":ship._source_pilot_phase,"basis_f32_hex":_basis_hex(ship._source_basis),"previous_basis_f32_hex":_basis_hex(ship._source_previous_basis),"step_f64_hex":_hexfloat(ship._source_step_seconds),"angular_f32_hex":_vec(ship._source_angular_velocity),"ship_angular_f32_hex":_vec(ship._source_ship_angular_velocity),"sample_valid":ship._source_rate_sample_valid,"motion_pending":ship._source_motion_pending,"last_collision":_collision_snapshot(ship)}
func is_active()->bool:return not _origin.is_empty() and not _entry.is_empty() and not _owners.is_empty()
func thrust_profile_enabled()->bool:return bool(_entry.get("thrust_profile_enabled",false))
func diagnostics()->Dictionary:
	return {"active":is_active(),"phase":"station_flight" if is_active() else "inactive","policy":POLICY,"generation":_generation,"system_id":_entry.get("system_id",-1),"body_id":_entry.get("body_id",""),"site_id":_entry.get("site_id",""),"bounded_near_station":true,"full_original_object_bank":false,"last_error":last_error}
func _valid(ship:RefCounted,nav:RefCounted,world:RefCounted,allow_destroyed:bool=false)->bool:
	if ship==null or nav==null or world==null or ship.get_script()!=Flight or nav.get_script()!=Navigation or world.get_script()!=World:return false
	if not Trial._finite_ship(ship) or (not allow_destroyed and ship.hull<=0) or ship.surface_mode or ship.combat_active or not ship.station_available or not ship.has_source_station():return false
	if world.layout_mode!=World.FULL_LAYOUT or not world.is_orbital_site() or nav.current_id!=world.system_id or not nav.is_source_hyperdrive() or nav.remaining!=0 or world.transfer_remaining!=0 or not world.pending_id.is_empty() or not world.pending_site_id.is_empty():return false
	var site:Dictionary=world.current_site()
	return is_finite(nav.elapsed_days) and nav.elapsed_days>=0 and nav.elapsed_days<=1e9 and nav.validate_source_ship(ship) and world.system_id==_entry.get("system_id") and world.focus_id==_entry.get("body_id") and world.site_id==_entry.get("site_id") and str(world.source_digest)==str(_entry.get("source_digest")) and str(site.get("runtime_record_hex"))==str(_entry.get("station_record_hex")) and str(world.by_id[world.focus_id].runtime_record_hex)==str(_entry.get("source_record_hex")) and str(ship.ship_id)==str(_origin.get("ship",{}).get("ship_id")) and ship.source_motion_profile==thrust_profile_enabled()
func runtime_matches(ship:RefCounted,nav:RefCounted,world:RefCounted,gear:RefCounted)->bool:
	if not is_active() or not _valid(ship,nav,world,true) or gear==null or gear.get_script()!=Gear or gear.snapshot().is_empty() or _position_f64.size()!=3:return false
	if Vector3(_position_f64[0],_position_f64[1],_position_f64[2])!=ship.position or Orbit._pose(ship)!=_pose_hex or _hexfloat(nav.elapsed_days)!=_days_hex:return false
	if not world.station_state_by_site.has(world.site_id):return false
	var spin:Dictionary=world.station_state_by_site[world.site_id].spin;var clock:=SourceClock.from_elapsed_days(nav.elapsed_days)
	return not clock.is_empty() and spin.tick_u32==clock.tick_u32 and spin.day_u32==clock.day_u32 and _basis_hex(ship._source_basis)==_basis_hex(Geometry.orientation_basis(spin))
func _bind(ship:RefCounted,nav:RefCounted,world:RefCounted,gear:RefCounted)->void:
	_pose_hex=Orbit._pose(ship);_days_hex=_hexfloat(nav.elapsed_days);_owners=Orbit._owner_binding(ship,nav,world,gear)
func rebind_runtime(ship:RefCounted,nav:RefCounted,world:RefCounted,gear:RefCounted)->bool:
	if not runtime_matches(ship,nav,world,gear):return false
	_bind(ship,nav,world,gear);return true
func _copy()->RefCounted:
	var copy:=new();copy._origin=_origin.duplicate(true);copy._entry=_entry.duplicate(true);copy._history=_history.duplicate(true);copy._motion_override=_motion_override;copy._generation=_generation;copy._position_f64=_position_f64.duplicate();copy._pose_hex=_pose_hex;copy._days_hex=_days_hex;copy._owners=_owners.duplicate(true);return copy
static func _restore_origin(origin:Dictionary)->Dictionary:
	if not _keys(origin,["ship","navigation","gear","world","orbit","site_id"]) or not origin.site_id is String:return {}
	for key:String in ["ship","navigation","gear","world","orbit"]:
		if not origin[key] is Dictionary:return {}
	var nav:=Navigation.new();if not nav.restore(origin.navigation):return {}
	var world:=World.new();world.configure(nav.current(),World.FULL_LAYOUT);if not world.restore(origin.world):return {}
	var loaded:=Station.restore_flight(world,nav,origin.ship);if loaded.is_empty():return {}
	var ship:RefCounted=loaded.ship;var gear:=Gear.new();var orbit:=Orbit.new()
	if not nav.bind_thermal_ship(ship) or not gear.restore(origin.gear) or not orbit.restore(origin.orbit,ship,nav,world,gear):return {}
	return {"ship":ship,"nav":nav,"gear":gear,"world":world,"orbit":orbit}
static func prepare_handoff(orbit:RefCounted,ship:RefCounted,nav:RefCounted,gear:RefCounted,world:RefCounted,site_id:String)->Dictionary:
	var prepared:Dictionary=Frame.prepare(orbit,ship,nav,gear,world,site_id)
	if not prepared.get("ok",false):return prepared
	var orbital:Dictionary=orbit.snapshot(ship,nav,world,gear);if orbital.is_empty():return _reject("station_origin_snapshot_unavailable")
	var candidate:=new();candidate._origin=Orbit._json({"ship":ship.snapshot(),"navigation":nav.snapshot(),"gear":gear.snapshot(),"world":world.snapshot(),"orbit":orbital,"site_id":site_id});candidate._entry=prepared.receipt.duplicate(true);candidate._position_f64=prepared.candidate_position_f64.duplicate();candidate._bind(prepared.candidate_ship,prepared.candidate_nav,prepared.candidate_world,prepared.candidate_gear)
	prepared.candidate_station=candidate;prepared.candidate_orbit=null;prepared.save_after=true;return prepared
func _fork(ship:RefCounted,nav:RefCounted,gear:RefCounted,world:RefCounted)->Dictionary:
	var cs:=Trial._fork_ship(ship);var cn:RefCounted=nav.fork_runtime();var cg:=Orbit._fork_gear(gear);var cw:=Orbit._fork_world(world)
	if cs==null or cn==null or cg==null or cw==null:return {}
	var inactive:=Surface.new();inactive.body_id=str(world.focus_id)
	return {"candidate_ship":cs,"candidate_nav":cn,"candidate_gear":cg,"candidate_world":cw,"candidate_surface":inactive}
func _body_world(nav:RefCounted,current_world:RefCounted=null)->RefCounted:
	if current_world!=null:
		var body:RefCounted=Orbit._fork_world(current_world)
		if body==null:return null
		body.site_id="";body.pending_id="";body.pending_site_id="";body.transfer_remaining=0.0
		return body
	var result:=World.new();result.configure(nav.current(),World.FULL_LAYOUT)
	return result if result.restore(_origin.world) else null
func _environment(ship:RefCounted,nav:RefCounted,world:RefCounted,gear:RefCounted,position:PackedFloat64Array)->Dictionary:
	var bodyworld:RefCounted=_body_world(nav,world);if bodyworld==null:return _reject("station_body_frame_unavailable")
	var mapped:Dictionary=Frame.map_between(world,bodyworld,position,ship.velocity,nav.elapsed_days)
	if not mapped.get("ok",false):return mapped
	var probe:=BodyProbe.new();probe.position=Vector3(mapped.position_f64[0],mapped.position_f64[1],mapped.position_f64[2]);probe.velocity=Vector3(mapped.velocity_f64[0],mapped.velocity_f64[1],mapped.velocity_f64[2]);probe.hull=ship.hull
	var state:Dictionary=gear.state();var inactive:=Surface.new();var context:Dictionary=Atmosphere.new().sample(bodyworld,probe,inactive,nav.elapsed_days,bool(state.get("f1014_raw_gear_flag",false)))
	if not context.get("ok",false) or bool(context.get("apply_f1014",false)) or (int(context.get("contact",{}).get("flags_u8",0))&0x80)!=0:return _reject("station_trial_body_hazard_requires_body_frame")
	var guarded:Dictionary=Orbit._guard(bodyworld,probe,nav.elapsed_days);if not guarded.get("ok",false):return guarded
	return {"ok":true,"context":context,"guard":guarded.sample}
func _accept(prepared:Dictionary,candidate:RefCounted,receipt:Dictionary,save_after:bool=true)->Dictionary:
	candidate._bind(prepared.candidate_ship,prepared.candidate_nav,prepared.candidate_world,prepared.candidate_gear)
	prepared.ok=true;prepared.reason="native_station_transaction_prepared";prepared.policy=POLICY;prepared.candidate_station=candidate;prepared.candidate_orbit=null;prepared.receipt=receipt;prepared.save_after=save_after;return prepared
func prepare(ship:RefCounted,nav:RefCounted,gear:RefCounted,world:RefCounted,seconds:float,steering:Vector2=Vector2.ZERO,roll:float=0.0,lift:float=0.0)->Dictionary:
	if not runtime_matches(ship,nav,world,gear) or not _valid(ship,nav,world) or not is_finite(seconds) or seconds<=0 or seconds>MAX_SECONDS or not steering.is_finite() or not is_finite(roll) or not is_finite(lift):return _reject("invalid_station_interval_or_owners")
	var prepared:=_fork(ship,nav,gear,world);if prepared.is_empty():return _reject("station_interval_fork_failed")
	var cs:RefCounted=prepared.candidate_ship;var cn:RefCounted=prepared.candidate_nav;var cg:RefCounted=prepared.candidate_gear;var cw:RefCounted=prepared.candidate_world
	if not cn.bind_thermal_ship(cs) or not cn.apply_fuel_availability(cs):return _reject("station_source_binding_failed")
	var before_environment:=_environment(cs,cn,cw,cg,_position_f64);if not before_environment.get("ok",false):return before_environment
	var speed:=Orbit.Gas.raw_speed(cs.velocity);if not speed.get("ok",false):return _reject("station_gear_velocity_invalid")
	var gear_result:Dictionary=cg.advance_seconds(seconds,{"flight_state_u8":0,"autopilot_phase_u8":0x24 if cs.docked else 0,"speed_s32":int(speed.speed_s32),"paused":false})
	if not gear_result.get("ok",false):return _reject("station_gear_interval_rejected")
	var before_day:float=cn.elapsed_days;var prior_world:Dictionary=cw.snapshot();var was_docked:bool=cs.docked
	cn.elapsed_days=before_day+seconds/86400.0
	if not is_finite(cn.elapsed_days) or cn.elapsed_days<before_day or cn.elapsed_days>1e9:return _reject("station_clock_rejected")
	var refreshed:Dictionary=Station.refresh(cs,cw,cn,seconds);if not refreshed.get("ok",false) or not refreshed.get("active",false):return _reject("station_source_context_rejected")
	cs.source_motion_profile=thrust_profile_enabled()
	var launched:=false
	if cs.docked and cw.station_launch_ready():cs.launch();launched=not cs.docked;cw.finish_station_launch(launched)
	if steering.length()>0.04 or absf(roll)>0.05 or absf(lift)>0.1:cs.autopilot=false
	var before_attitude:Quaternion=cs.attitude;var before_position:Vector3=cs.position;var before_step_docked:bool=cs.docked
	var gravity:Vector3=cw.gravity_at(cs.position,cn.elapsed_days);if not gravity.is_finite():return _reject("station_gravity_unavailable")
	cs.last_notice="";cs.step(seconds,steering,roll,gravity,lift)
	if not Trial._finite_ship(cs):return _reject("station_motion_invalid")
	var physical_anchor:bool=launched or before_step_docked or cs.docked or cs.position!=before_position+cs.velocity*seconds
	var position:=PackedFloat64Array([cs.position.x,cs.position.y,cs.position.z]) if physical_anchor else _position_f64.duplicate()
	if not physical_anchor:
		for axis in range(3):position[axis]+=float(cs.velocity[axis])*seconds
	cs.position=Vector3(position[0],position[1],position[2])
	for value:float in position:
		if not is_finite(value) or absf(value)>1e9:return _reject("station_position_accumulator_invalid")
	var commands:=Fuel.commands(cs,seconds)
	if not cn.sync_thermal_ship(cs):return _reject("station_collision_hp_sync_rejected")
	var environment:=_environment(cs,cn,cw,cg,position);if not environment.get("ok",false):return environment
	var fuel_result:Dictionary={"ok":true,"reason":"station_collision_destroyed","thermal":{},"destruction_requested":false}
	if cs.hull>0:
		var context:Dictionary=environment.context;context.commands_s16=commands.duplicate(true)
		context.thermal={"apply_f1014":false,"altitude_s32":int(context.altitude_s32),"speed_s32":int(context.speed_s32),"velocity_s32":context.velocity_s32.duplicate(),"shielding":bool(cn.fuel_state(cs).get("atmospheric_shielding_installed",false)),"gear_down":bool(context.gear_down),"wind_enabled":false,"wind_armed":false,"parent_shield_s16":0,"wind_flags_u8":0}
		fuel_result=cn.advance_fuel_seconds(seconds,context,cs)
		if not fuel_result.get("ok",false):return _reject("station_fuel_interval_rejected")
		var thermal:Dictionary=fuel_result.get("thermal",{})
		if thermal.get("velocity_changed",false):
			var before:Array=thermal.velocity_before_s32;var after:Array=thermal.velocity_after_s32;cs.velocity+=Basis(context.velocity_to_phone_basis)*(Vector3(int(after[0])-int(before[0]),int(after[1])-int(before[1]),int(after[2])-int(before[2]))*float(context.velocity_unit_mps))
	if not cn.apply_fuel_availability(cs) or not cn.validate_source_ship(cs) or not Trial._finite_ship(cs):return _reject("station_post_interval_owner_mismatch")
	var candidate:RefCounted=_copy();candidate._generation+=1;candidate._position_f64=position;candidate._motion_override="none"
	candidate._history=Orbit._json({"world_before":prior_world,"days_before_f64_hex":_hexfloat(before_day),"seconds_f64_hex":_hexfloat(seconds),"step_before_attitude_f32_hex":_qhex(before_attitude),"step_before_docked":before_step_docked})
	var receipt:={"schema":"starfrontier-native-station-interval-v1","policy":POLICY,"seconds_f64_hex":_hexfloat(seconds),"days_before_f64_hex":_hexfloat(before_day),"days_after_f64_hex":_hexfloat(cn.elapsed_days),"physical_anchor_applied":physical_anchor,"docked_before":was_docked,"docked_after":cs.docked,"launch_completed":launched,"legacy_orbit_guard":environment.guard,"fuel":fuel_result.get("reason","")}
	prepared.destruction_requested=cs.hull<=0 or bool(fuel_result.get("destruction_requested",false));prepared.fuel=fuel_result;prepared.gear=gear_result
	return _accept(prepared,candidate,receipt,was_docked!=cs.docked or launched)
func prepare_command(ship:RefCounted,nav:RefCounted,gear:RefCounted,world:RefCounted,action:String)->Dictionary:
	if not runtime_matches(ship,nav,world,gear) or not _valid(ship,nav,world) or action not in ["auto","request_open","dock","launch","brake"]:return _reject("invalid_station_command_or_owners")
	var prepared:=_fork(ship,nav,gear,world);if prepared.is_empty():return _reject("station_command_fork_failed")
	var cs:RefCounted=prepared.candidate_ship;var cn:RefCounted=prepared.candidate_nav;var cw:RefCounted=prepared.candidate_world;var candidate:RefCounted=_copy()
	match action:
		"brake":
			cs.brake();cw.cancel_station_launch()
		"auto":
			if cs.docked:return _reject("station_autopilot_requires_free_ship")
			cs.autopilot=not cs.autopilot
			if cs.autopilot and not cw.request_station_open(cn.elapsed_days):return _reject("station_open_request_rejected")
		"request_open":
			if cs.docked or not cw.request_station_open(cn.elapsed_days):return _reject("station_open_request_rejected")
		"dock":
			if cs.docked or not cs.dock():return _reject("station_docking_not_ready")
			candidate._motion_override="dock"
		"launch":
			if not cs.docked or not cs.forward_propulsion_available() or not cw.request_station_open(cn.elapsed_days,true):return _reject("station_launch_not_ready")
			cs.launch();cw.finish_station_launch(not cs.docked)
			if not cs.docked:candidate._motion_override="launch"
	candidate._generation+=1;candidate._position_f64=PackedFloat64Array([cs.position.x,cs.position.y,cs.position.z]) if action in ["dock","launch"] else _position_f64.duplicate()
	return _accept(prepared,candidate,{"schema":"starfrontier-native-station-command-v1","action":action,"clock_advanced":false,"fuel_advanced":false,"hp_applied":false,"docked":cs.docked,"launch_pending":cw.station_launch_pending()})
func prepare_service(ship:RefCounted,nav:RefCounted,gear:RefCounted,world:RefCounted,action:String,id:String="",quantity:int=0)->Dictionary:
	if not runtime_matches(ship,nav,world,gear) or not _valid(ship,nav,world):return _reject("invalid_station_service_owners")
	var prepared:=_fork(ship,nav,gear,world);if prepared.is_empty():return _reject("station_service_fork_failed")
	var cs:RefCounted=prepared.candidate_ship;var cn:RefCounted=prepared.candidate_nav;var accepted:=false
	if action=="manual_jet_refuel":accepted=cn.manual_jet_refuel(cs)
	elif action=="set_refueller_enabled":accepted=cn.set_refueller_enabled(quantity!=0,cs)
	else:accepted=cn.service(action,id,quantity,cs)
	if not accepted:return {"ok":false,"reason":"station_service_rejected","policy":POLICY,"message":cn.message}
	if cs.ship_id!=ship.ship_id or Orbit._pose(cs)!=_pose_hex or _hexfloat(cn.elapsed_days)!=_days_hex or not cn.apply_fuel_availability(cs) or not cn.validate_source_ship(cs):return _reject("station_service_changed_physical_identity")
	var candidate:RefCounted=_copy();candidate._generation+=1
	prepared.message=cn.message
	return _accept(prepared,candidate,{"schema":"starfrontier-native-station-service-v1","action":action,"id":id,"quantity":quantity,"clock_advanced":false,"physical_fuel_interval_advanced":false,"fuel_advanced":false,"contact_damage_applied":false,"service_applied":true,"hull_before":ship.hull,"hull_after":cs.hull,"credits_before":ship.credits,"credits_after":cs.credits,"service_message":cn.message})
func prepare_reverse(ship:RefCounted,nav:RefCounted,gear:RefCounted,world:RefCounted)->Dictionary:
	if not runtime_matches(ship,nav,world,gear) or not _valid(ship,nav,world) or ship.docked or ship.autopilot:return _reject("station_reverse_requires_free_manual_ship")
	var original_day:=_decode_float(_origin.orbit.receipt.source_days_f64_hex)
	if not is_finite(original_day) or nav.elapsed_days<=original_day:return _reject("station_reverse_requires_advanced_orbital_clock")
	var prepared:=_fork(ship,nav,gear,world);if prepared.is_empty():return _reject("station_reverse_fork_failed")
	var cs:RefCounted=prepared.candidate_ship;var cn:RefCounted=prepared.candidate_nav;var cg:RefCounted=prepared.candidate_gear;var bodyworld:RefCounted=_body_world(cn,world)
	if bodyworld==null:return _reject("station_reverse_body_frame_unavailable")
	var mapped:Dictionary=Frame.map_between(world,bodyworld,_position_f64,cs.velocity,cn.elapsed_days);if not mapped.get("ok",false):return mapped
	cs.position=Vector3(mapped.position_f64[0],mapped.position_f64[1],mapped.position_f64[2]);cs.velocity=Vector3(mapped.velocity_f64[0],mapped.velocity_f64[1],mapped.velocity_f64[2]);cs.clear_source_station();cs.station_available=false;cn.set_source_port_available(false)
	var original:=_restore_origin(_origin);if original.is_empty():return _reject("station_reverse_original_lineage_unavailable")
	var orbit:=Orbit.new();orbit._lineage=original.orbit._lineage.duplicate(true);orbit._receipt=original.orbit._receipt.duplicate(true);orbit._position_f64=mapped.position_f64.duplicate();orbit._generation=original.orbit._generation+_generation+1
	cs.source_motion_profile=orbit.thrust_profile_enabled();var guarded:Dictionary=Orbit._guard(bodyworld,cs,cn.elapsed_days)
	if not guarded.get("ok",false) or not cn.validate_source_ship(cs) or orbit._generation>100000000:return _reject("station_reverse_guard_rejected")
	orbit._bind(cs,cn,bodyworld,cg);if not orbit._matches(cs,cn,bodyworld,cg):return _reject("station_reverse_binding_rejected")
	prepared.candidate_world=bodyworld;prepared.candidate_orbit=orbit;prepared.candidate_station=null;prepared.ok=true;prepared.reason="native_station_body_frame_prepared";prepared.policy=POLICY;prepared.save_after=true;prepared.receipt={"schema":"starfrontier-native-station-reverse-v1","policy":POLICY,"mapping":mapped.receipt,"clock_advanced":false,"fuel_advanced":false,"hp_applied":false,"position_snapped":false};return prepared
func snapshot(ship:RefCounted,nav:RefCounted,world:RefCounted,gear:RefCounted)->Dictionary:
	if not runtime_matches(ship,nav,world,gear):return {}
	var result:=Orbit._json({"schema":SCHEMA,"version":1,"policy":POLICY,"origin":_origin,"origin_sha256":Orbit._hash(_origin),"entry_receipt":_entry,"generation":_generation,"pose_f32_hex":_pose_hex,"position_f64_hex":NativeSurface._native_floats(Array(_position_f64),8),"elapsed_days_f64_hex":_days_hex,"legacy_pose_anchor":Orbit._legacy_pose(ship),"legacy_days_anchor":Orbit._decimal(nav.elapsed_days),"motion":_motion(ship),"motion_history":_history,"motion_override":_motion_override,"owners":Orbit._owner_binding(ship,nav,world,gear)})
	result.snapshot_sha256=Orbit._hash(result);return result
func _restore_motion(data:Dictionary,ship:RefCounted,nav:RefCounted,world:RefCounted,initial_world:RefCounted)->bool:
	var motion:Dictionary=data.motion
	if not _keys(motion,MOTION_KEYS) or not motion.autopilot is bool or not motion.sample_valid is bool or not motion.motion_pending is bool or motion.pilot_phase not in ["","staging","align","enter"] or not motion.last_collision is Dictionary:return false
	var basis:=_read_basis(motion.basis_f32_hex);var previous:=_read_basis(motion.previous_basis_f32_hex);var omega:=_read_vec(motion.angular_f32_hex);var shipomega:=_read_vec(motion.ship_angular_f32_hex);var dt:=_decode_float(motion.step_f64_hex)
	if not Dynamics.rigid(basis) or not Dynamics.rigid(previous) or not omega.is_finite() or not shipomega.is_finite() or not is_finite(dt) or dt<0 or dt>MAX_SECONDS:return false
	if not world.station_state_by_site.has(world.site_id):return false
	var current:Dictionary=world.station_state_by_site[world.site_id];var expected_basis:=Geometry.orientation_basis(current.spin);var expected_previous:=expected_basis;var expected_omega:=Vector3.ZERO;var expected_shipomega:=Vector3.ZERO;var expected_pending:=false
	if not data.motion_history.is_empty():
		var h:Dictionary=data.motion_history
		if not _keys(h,["world_before","days_before_f64_hex","seconds_f64_hex","step_before_attitude_f32_hex","step_before_docked"]) or not h.world_before is Dictionary or not h.step_before_docked is bool:return false
		var beforeday:=_decode_float(h.days_before_f64_hex);var seconds:=_decode_float(h.seconds_f64_hex);var attitude:=_read_q(h.step_before_attitude_f32_hex)
		if not is_finite(beforeday) or not is_finite(seconds) or seconds<=0 or seconds>MAX_SECONDS or _hexfloat(beforeday+seconds/86400.0)!=_hexfloat(nav.elapsed_days) or _hexfloat(dt)!=_hexfloat(seconds) or not attitude.is_finite() or absf(attitude.length_squared()-1.0)>0.0001:return false
		var oldworld:=World.new();oldworld.configure(nav.current(),World.FULL_LAYOUT)
		if not oldworld.restore(h.world_before) or oldworld.site_id!=world.site_id or oldworld.focus_id!=world.focus_id or oldworld.source_digest!=world.source_digest:return false
		var prior:Dictionary=oldworld.source_station_state(beforeday);if prior.is_empty():return false
		expected_previous=Geometry.orientation_basis(prior.spin)
		if not oldworld.advance_station(seconds,nav.elapsed_days):return false
		var advanced:Dictionary=oldworld.source_station_state(nav.elapsed_days)
		if advanced.spin!=current.spin or int(advanced.door_u16)!=int(current.door_u16):return false
		expected_omega=Dynamics.sample(expected_previous,expected_basis,seconds).get("angular_velocity_world_rad_s",Vector3.ZERO)
		expected_shipomega=expected_omega if ship.docked else Dynamics.angular_displacement(attitude,ship.attitude)/seconds
		expected_pending=bool(h.step_before_docked) and ship.docked
	else:
		if dt!=0 or motion.sample_valid or _hexfloat(nav.elapsed_days)!=str(_entry.source_days_f64_hex) or initial_world==null or not initial_world.station_state_by_site.has(world.site_id):return false
		var initial:Dictionary=initial_world.station_state_by_site[world.site_id]
		if current.spin!=initial.spin or int(current.door_u16)!=int(initial.door_u16):return false
	if data.motion_override=="dock":
		if not ship.docked:return false
		expected_shipomega=expected_omega;expected_pending=false
	elif data.motion_override=="launch":
		if ship.docked:return false
		expected_shipomega=Vector3.ZERO;expected_pending=false
	if _basis_hex(basis)!=_basis_hex(expected_basis) or _basis_hex(previous)!=_basis_hex(expected_previous) or _vec(omega)!=_vec(expected_omega) or _vec(shipomega)!=_vec(expected_shipomega) or motion.sample_valid!=(dt>0) or motion.motion_pending!=expected_pending:return false
	var collision:=_collision_restore(motion.last_collision);if not collision.get("ok",false):return false
	ship.autopilot=motion.autopilot;ship._source_pilot_phase=str(motion.pilot_phase);ship._source_basis=basis;ship._source_previous_basis=previous;ship._source_step_seconds=dt;ship._source_angular_velocity=omega;ship._source_ship_angular_velocity=shipomega;ship._source_rate_sample_valid=motion.sample_valid;ship._source_motion_pending=motion.motion_pending;ship._source_last_collision=collision.data;return true
func restore(data:Dictionary,ship:RefCounted,nav:RefCounted,world:RefCounted,gear:RefCounted)->bool:
	if is_active() or not _keys(data,KEYS) or not Orbit._plain(data) or data.schema!=SCHEMA or data.version!=1 or data.policy!=POLICY:last_error="station_restore_header";return false
	for key:String in ["origin","entry_receipt","legacy_pose_anchor","motion","motion_history","owners"]:
		if not data[key] is Dictionary:last_error="station_restore_dictionary_shape";return false
	if data.motion_override not in ["none","dock","launch"] or not Gear._whole(data.generation,0,100000000) or not Orbit._hex(data.origin_sha256,32) or Orbit._hash(data.origin)!=data.origin_sha256 or not NativeSurface._native_pose_valid(data.pose_f32_hex) or not Orbit._hex(data.position_f64_hex,24) or not Orbit._hex(data.elapsed_days_f64_hex,8):last_error="station_restore_metadata_domain";return false
	var sealed:=data.duplicate(true);sealed.erase("snapshot_sha256");if not Orbit._hex(data.snapshot_sha256,32) or Orbit._hash(sealed)!=data.snapshot_sha256:last_error="station_restore_checksum";return false
	var original:=_restore_origin(data.origin);if original.is_empty():last_error="invalid_station_origin";return false
	var replay:Dictionary=Frame.prepare(original.orbit,original.ship,original.nav,original.gear,original.world,str(data.origin.site_id))
	if not replay.get("ok",false) or Orbit._hash(replay.receipt)!=Orbit._hash(data.entry_receipt):last_error="invalid_station_entry_replay";return false
	var pose:=NativeSurface._native_decode_pose(data.pose_f32_hex);var days:=_decode_float(data.elapsed_days_f64_hex);var position:=PackedFloat64Array(NativeSurface._native_numbers(data.position_f64_hex,8))
	if not is_finite(days) or days<0 or days>1e9 or Orbit._decimal(days)!=data.legacy_days_anchor or not is_finite(float(data.legacy_days_anchor)) or (nav.elapsed_days!=data.legacy_days_anchor and _hexfloat(nav.elapsed_days)!=data.elapsed_days_f64_hex):last_error="station_restore_clock_anchor";return false
	for value:float in position:
		if not is_finite(value) or absf(value)>1e9:last_error="station_restore_position_domain";return false
	if Vector3(position[0],position[1],position[2])!=pose.position or not _legacy_vectors_match(ship,data.legacy_pose_anchor) or absf(ship.attitude.dot(pose.attitude))<0.999999:last_error="station_restore_pose_anchor";return false
	var copy:=Trial._fork_ship(ship);var copied_nav:RefCounted=nav.fork_runtime();copy.position=pose.position;copy.velocity=pose.velocity;copy.attitude=pose.attitude;copied_nav.elapsed_days=days
	_origin=data.origin.duplicate(true);_entry=data.entry_receipt.duplicate(true);_history=data.motion_history.duplicate(true);_motion_override=str(data.motion_override);_generation=int(data.generation);_position_f64=position;_pose_hex=str(data.pose_f32_hex);_days_hex=str(data.elapsed_days_f64_hex);_owners=data.owners.duplicate(true)
	copy.source_motion_profile=thrust_profile_enabled()
	if not _valid(copy,copied_nav,world,true) or Orbit._legacy_pose(copy)!=data.legacy_pose_anchor or Orbit._owner_binding(copy,copied_nav,world,gear)!=data.owners or not _restore_motion(data,copy,copied_nav,world,replay.candidate_world):_origin={};_entry={};last_error="invalid_station_current_binding";return false
	if _generation==0 and (data.pose_f32_hex!=replay.receipt.station_pose_f32_hex or data.position_f64_hex!=replay.receipt.ideal_position_f64_hex or data.elapsed_days_f64_hex!=replay.receipt.source_days_f64_hex):_origin={};_entry={};return false
	ship.position=pose.position;ship.velocity=pose.velocity;ship.attitude=pose.attitude;ship.source_motion_profile=thrust_profile_enabled();nav.elapsed_days=days
	if not _restore_motion(data,ship,nav,world,replay.candidate_world):_origin={};_entry={};return false
	return runtime_matches(ship,nav,world,gear)
