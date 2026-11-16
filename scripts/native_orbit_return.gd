extends RefCounted
# Bounded inverse of the native trial's affine outward transfer. It reuses
# the same observed source chart and raw history, not a new 50m trial entry.
const Orbit=preload("res://scripts/native_orbit_trial.gd")
const NativeSurface=preload("res://scripts/native_surface_model.gd")
const Trial=preload("res://scripts/native_landing_trial.gd")
const Phone=preload("res://scripts/source_surface_contact_bridge.gd")
const World=preload("res://scripts/planetary_system.gd")
const Flight=preload("res://scripts/flight_model.gd")
const POLICY:="native-trial-inverse-affine-airborne-return-v1"
const MIN_RETURN_AGL_M:=1000.0
const MAX_RETURN_AGL_M:=30000.0

static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"policy":POLICY,"position_snapped":false,"clock_advanced":false,"fuel_advanced":false,"hp_applied":false}

static func _outbound_surface(orbit:RefCounted,nav:RefCounted)->RefCounted:
	var data:Dictionary=orbit._lineage
	if not data.get("ship") is Dictionary or not data.get("surface") is Dictionary or not data.get("world") is Dictionary:return null
	var source_ship:=Flight.new();var source_world:=World.new();var surface:=NativeSurface.new()
	source_world.configure(nav.current(),World.FULL_LAYOUT)
	if not source_ship.restore(data.ship) or not source_world.restore(data.world) or not surface.restore(data.surface,source_ship,source_world):return null
	return surface

static func prepare_return(orbit:RefCounted,ship:RefCounted,nav:RefCounted,gear:RefCounted,world:RefCounted)->Dictionary:
	if orbit==null or orbit.get_script()!=Orbit or not orbit.is_active() or not orbit._matches(ship,nav,world,gear) or not Orbit._valid(ship,nav,world):return _reject("invalid_bound_orbit_return_owners")
	var source:=_outbound_surface(orbit,nav)
	if source==null or source.landed or source.native_session.phase()!="free":return _reject("outbound_native_lineage_unavailable")
	if str(source.body_id)!=str(world.focus_id) or int(source.native_world().system_id)!=int(world.system_id):return _reject("return_source_identity_changed")
	var cs:=Trial._fork_ship(ship);var cn:RefCounted=nav.fork_runtime();var cg:=Orbit._fork_gear(gear);var cw:=Orbit._fork_world(world)
	if cs==null or cn==null or cg==null or cw==null:return _reject("return_owner_fork_failed")
	var body:Dictionary=cw.by_id[str(cw.focus_id)]
	var rotation:=Orbit.Gas._basis_readonly(cw,body,cn.elapsed_days)
	if rotation.is_empty():return _reject("return_rotation_unavailable")
	var center:Vector3=cw.local_meters(str(cw.focus_id),cn.elapsed_days)
	if not center.is_finite():return _reject("return_center_unavailable")
	var chart:Basis=source.globe.basis_at(source.globe.latitude,source.globe.longitude)
	var relative:=PackedFloat64Array()
	for axis in range(3):relative.append(orbit._position_f64[axis]-float(center[axis]))
	# Both inverse products are scalar-double operations, including the final
	# radius subtraction. Transpose/F32 intermediate vectors lose the residual.
	var bodyfixed:=Phone.to_local_vector(Basis(rotation.basis),relative)
	if bodyfixed.size()!=3:return _reject("return_bodyfixed_projection_unavailable")
	var local:=Phone.to_local_vector(chart,bodyfixed)
	var body_velocity:=Phone.to_local_vector(Basis(rotation.basis),PackedFloat64Array([ship.velocity.x,ship.velocity.y,ship.velocity.z]))
	var velocity:=Phone.to_local_vector(chart,body_velocity)
	if local.size()!=3 or velocity.size()!=3:return _reject("return_chart_projection_unavailable")
	local[1]-=float(source.globe.radius)
	cs.position=Vector3(local[0],local[1],local[2]);cs.velocity=Vector3(velocity[0],velocity[1],velocity[2])
	cs.attitude=(chart.inverse()*Basis(rotation.basis).inverse()*Basis(ship.attitude)).get_rotation_quaternion().normalized()
	cs.surface_mode=true;cs.station_available=false;cs.source_motion_profile=ship.source_motion_profile;cs.clear_source_station()
	if not Trial._finite_ship(cs) or not NativeSurface._native_pose_valid(Orbit._pose(cs)):return _reject("return_pose_outside_supported_range")
	var height:Dictionary=source.height_sample(cs.position.x,cs.position.z)
	if height.is_empty():return _reject("return_outside_observed_native_leaf")
	var agl:float=cs.position.y-float(height.height)-source.clearance(cs)
	if not is_finite(agl) or agl<MIN_RETURN_AGL_M or agl>MAX_RETURN_AGL_M:return _reject("return_height_outside_bounded_airborne_region")
	var speed:=Orbit.Gas.raw_speed(cs.velocity)
	if not speed.get("ok",false):return _reject("return_gear_speed_unavailable")
	var state:Dictionary=cg.state({"flight_state_u8":0,"autopilot_phase_u8":0,"speed_s32":int(speed.speed_s32),"paused":false})
	if not state.get("initialized",false) or not state.has("position_u16"):return _reject("return_gear_unavailable")
	var witness:={"schema":"starfrontier-native-airborne-return-boundary-v1","policy":POLICY,"seconds_f64_hex":Orbit._float(0),"days_before_f64_hex":Orbit._float(nav.elapsed_days),"days_after_f64_hex":Orbit._float(nav.elapsed_days),"outbound_lineage_sha256":Orbit._hash(orbit._lineage),"space_generation":int(orbit._generation),"space_position_f64_hex":NativeSurface._native_floats(Array(orbit._position_f64),8),"space_pose_f32_hex":Orbit._pose(ship),"phone_pose_f32_hex":Orbit._pose(cs),"gear_position_u16":int(state.position_u16)}
	var surface:RefCounted=source.fork_runtime(cs)
	var rebound:Dictionary=surface.rebind_airborne(cs,cw,cn.elapsed_days,int(state.position_u16),witness)
	if not rebound.get("ok",false):return _reject(str(rebound.get("reason","return_native_rebind_failed")))
	if not cn.bind_thermal_ship(cs) or not cn.validate_source_ship(cs):return _reject("return_hp_fuel_owner_mismatch")
	var rounding:Array=[]
	for axis in range(3):rounding.append(absf(local[axis]-float(cs.position[axis])))
	var receipt:Dictionary=Orbit._json({"schema":"starfrontier-native-orbit-return-v1","policy":POLICY,"velocity_policy":Orbit.VELOCITY_POLICY,"system_id":int(cw.system_id),"body_id":str(cw.focus_id),"source_record_hex":str(body.runtime_record_hex),"space_generation":int(orbit._generation),"outbound_lineage_sha256":Orbit._hash(orbit._lineage),"space_position_f64_hex":NativeSurface._native_floats(Array(orbit._position_f64),8),"space_pose_f32_hex":Orbit._pose(ship),"phone_pose_f32_hex":Orbit._pose(cs),"phone_position_ideal_f64_hex":NativeSurface._native_floats(Array(local),8),"phone_velocity_ideal_f64_hex":NativeSurface._native_floats(Array(velocity),8),"phone_position_rounding_error_f64_hex":NativeSurface._native_floats(rounding,8),"days_f64_hex":Orbit._float(cn.elapsed_days),"native_display_agl_m":agl,"airborne_rebind":rebound,"clock_advanced":false,"fuel_advanced":false,"hp_applied":false,"position_snapped":false,"omega_cross_radius_added":false,"full_original_object_bank":false})
	return {"ok":true,"reason":"native_orbit_return_prepared","policy":POLICY,"candidate_ship":cs,"candidate_nav":cn,"candidate_gear":cg,"candidate_world":cw,"candidate_surface":surface,"candidate_orbit":null,"receipt":receipt,"save_after":true}
