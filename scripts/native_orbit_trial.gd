extends RefCounted
# A bounded continuation of the separate native landing trial. This is a
# coordinate handoff and manual space flight, not circular-orbit insertion or
# the unported original F570/F606 object bank/reference-frame dispatcher.
const Trial=preload("res://scripts/native_landing_trial.gd")
const NativeSurface=preload("res://scripts/native_surface_model.gd")
const Surface=preload("res://scripts/surface_model.gd")
const World=preload("res://scripts/planetary_system.gd")
const Flight=preload("res://scripts/flight_model.gd")
const Navigation=preload("res://scripts/navigation.gd")
const Gear=preload("res://scripts/source_landing_gear_session.gd")
const Phone=preload("res://scripts/source_surface_contact_bridge.gd")
const Session=preload("res://scripts/source_natural_contact_session.gd")
const Gas=preload("res://scripts/source_fuel_contact.gd")
const Atmosphere=preload("res://scripts/source_atmosphere_contact.gd")
const Fuel=preload("res://scripts/source_fuel_flight_bridge.gd")
const Guard=preload("res://scripts/source_orbit_surface_guard.gd")
const SCHEMA:="starfrontier-native-orbit-trial-v1"
const POLICY:="native-trial-affine-handoff-and-atomic-manual-space-v1"
const VELOCITY_POLICY:="rotate-bodyfixed-phone-velocity-no-added-omega-cross-radius-v1"
const MIN_HANDOFF_AGL_M:=19000.0
const MIN_GUARD_CLEARANCE_M:=2000.0
const MAX_SECONDS:=0.1
const KEYS:=["schema","version","policy","velocity_policy","lineage","lineage_sha256","receipt","thrust_profile_enabled","generation","pose_f32_hex","position_f64_hex","elapsed_days_f64_hex","legacy_pose_anchor","legacy_days_anchor","owners","snapshot_sha256"]
var last_error:=""
var _lineage:Dictionary={}
var _receipt:Dictionary={}
var _generation:=0
var _pose_hex:=""
var _position_f64:=PackedFloat64Array()
var _days_hex:=""
var _owners:Dictionary={}

func is_active()->bool:return not _lineage.is_empty() and not _receipt.is_empty() and not _owners.is_empty()
func thrust_profile_enabled()->bool:return bool(_receipt.get("thrust_profile_enabled",false))
func diagnostics()->Dictionary:
	return {"active":is_active(),"phase":"orbital_flight" if is_active() else "inactive","policy":POLICY,"velocity_policy":VELOCITY_POLICY,"generation":_generation,"system_id":_owners.get("system_id",-1),"body_id":_owners.get("body_id",""),"lineage_sha256":_hash(_lineage) if is_active() else "","last_error":last_error,"circular_orbit_inserted":false,"full_original_object_bank":false}

static func _reject(reason:String,extra:float=0.0)->Dictionary:
	return {"ok":false,"reason":reason,"policy":POLICY,"required_extra_climb_m":extra,"position_snapped":false,"clock_advanced":false,"fuel_advanced":false,"hp_applied":false}
static func _plain(value:Variant,depth:int=0)->bool:
	if depth>28:return false
	if value is Dictionary:
		if value.size()>1024:return false
		for key:Variant in value:
			if not key is String or not _plain(value[key],depth+1):return false
		return true
	if value is Array:
		if value.size()>4096:return false
		for child:Variant in value:
			if not _plain(child,depth+1):return false
		return true
	return value==null or value is bool or (value is String and value.length()<131072) or ((value is int or value is float) and is_finite(float(value)) and absf(float(value))<=9007199254740991.0)
static func _json(value:Dictionary)->Dictionary:return Session._json(value)
static func _hash(value:Dictionary)->String:return Session._hash(value)
static func _hex(value:Variant,bytes:int)->bool:
	if not value is String or value.length()!=bytes*2:return false
	for index in range(value.length()):
		var c:int=value.unicode_at(index)
		if not ((c>=48 and c<=57) or (c>=97 and c<=102)):return false
	return true
static func _float(value:float)->String:return NativeSurface._native_floats([value],8)
static func _decimal(value:float)->Variant:return JSON.parse_string(JSON.stringify(value))
static func _pose(ship:RefCounted)->String:return NativeSurface._native_pose(ship.position,ship.velocity,ship.attitude)
static func _legacy_pose(ship:RefCounted)->Dictionary:return NativeSurface._native_legacy_pose(ship)
static func _basis_values(basis:Basis)->Array:
	return [basis.x.x,basis.x.y,basis.x.z,basis.y.x,basis.y.y,basis.y.z,basis.z.x,basis.z.y,basis.z.z]
static func _multiply(basis:Basis,values:PackedFloat64Array)->PackedFloat64Array:
	var result:=PackedFloat64Array()
	for axis in range(3):result.append(float(basis.x[axis])*values[0]+float(basis.y[axis])*values[1]+float(basis.z[axis])*values[2])
	return result
static func _fork_world(world:RefCounted)->RefCounted:
	if world==null or world.get_script()!=World:return null
	var copied:=World.new()
	for property:Dictionary in world.get_property_list():
		if (int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE)==0:continue
		var key:=str(property.name)
		copied.set(key,Guard.new() if key=="_full_surface_guard" else Trial._copy_value(world.get(key)))
	return copied
static func _fork_gear(gear:RefCounted)->RefCounted:
	if gear==null or gear.get_script()!=Gear:return null
	var copy:=Gear.new()
	return copy if copy.restore(gear.snapshot()) else null
static func _valid(ship:RefCounted,nav:RefCounted,world:RefCounted,allow_destroyed:bool=false)->bool:
	return ship!=null and nav!=null and world!=null and ship.get_script()==Flight and nav.get_script()==Navigation and world.get_script()==World and world.layout_mode==World.FULL_LAYOUT and nav.is_source_hyperdrive() and nav.remaining==0 and world.transfer_remaining==0 and int(nav.current_id)==int(world.system_id) and world.by_id.has(str(world.focus_id)) and not ship.docked and not ship.combat_active and not ship.autopilot and Trial._finite_ship(ship) and (allow_destroyed or ship.hull>0) and is_finite(nav.elapsed_days) and nav.elapsed_days>=0 and nav.elapsed_days<=1e9
static func _guard_record(sampled:Dictionary)->Dictionary:
	var result:Dictionary={}
	for key:String in ["ok","coarse_only","outside_envelope","body_id","minimum_altitude_m","altitude_m","elevation_m","distance_m","terrain_radius_m","contract","terrain_revision"]:
		if sampled.has(key):result[key]=sampled[key]
	return _json(result)
static func _guard(world:RefCounted,ship:RefCounted,days:float)->Dictionary:
	var sampled:Dictionary=world._full_surface_guard.probe(world,ship,days)
	if sampled.is_empty() or not sampled.get("ok",false):return _reject("orbit_clearance_unavailable")
	var clearance:=float(sampled.get("minimum_altitude_m",NAN)) if sampled.get("coarse_only",false) else float(sampled.get("altitude_m",NAN))
	if not is_finite(clearance):return _reject("nonfinite_orbit_clearance")
	if clearance<MIN_GUARD_CLEARANCE_M:return _reject("legacy_orbit_guard_requires_further_powered_climb",MIN_GUARD_CLEARANCE_M-clearance+1.0)
	return {"ok":true,"sample":_guard_record(sampled),"clearance_m":clearance}
static func _owner_binding(ship:RefCounted,nav:RefCounted,world:RefCounted,gear:RefCounted)->Dictionary:
	return _json({"ship_sha256":_hash(ship.snapshot()),"navigation_sha256":_hash(nav.snapshot()),"world_sha256":_hash(world.snapshot()),"gear_sha256":_hash(gear.snapshot()),"system_id":int(world.system_id),"body_id":str(world.focus_id),"source_record_hex":str(world.by_id[str(world.focus_id)].runtime_record_hex)})
func _bind(ship:RefCounted,nav:RefCounted,world:RefCounted,gear:RefCounted)->void:
	_pose_hex=_pose(ship);_days_hex=_float(nav.elapsed_days);_owners=_owner_binding(ship,nav,world,gear)
func _matches(ship:RefCounted,nav:RefCounted,world:RefCounted,gear:RefCounted)->bool:
	return not _lineage.is_empty() and _position_f64.size()==3 and ship!=null and Vector3(_position_f64[0],_position_f64[1],_position_f64[2])==ship.position and gear!=null and gear.get_script()==Gear and not gear.snapshot().is_empty() and _valid(ship,nav,world,true) and nav.validate_source_ship(ship) and not ship.surface_mode and not ship.station_available and ship.source_motion_profile==thrust_profile_enabled() and world.site_id.is_empty() and world.pending_id.is_empty() and world.pending_site_id.is_empty() and _pose(ship)==_pose_hex and _float(nav.elapsed_days)==_days_hex and int(world.system_id)==int(_owners.get("system_id",-1)) and str(world.focus_id)==str(_owners.get("body_id","")) and str(world.by_id[str(world.focus_id)].runtime_record_hex)==str(_owners.get("source_record_hex","")) and str(world.source_digest)==str(_receipt.get("source_digest",""))

static func prepare_handoff(ship:RefCounted,nav:RefCounted,gear:RefCounted,surface:RefCounted)->Dictionary:
	if surface==null or surface.get_script()!=NativeSurface or not surface.is_native_landing_trial() or surface.landed or surface.native_session.phase()!="free" or surface.native_session.is_pending():return _reject("handoff_requires_free_native_surface")
	var world:RefCounted=surface.native_world()
	if not _valid(ship,nav,world) or not ship.surface_mode or surface._source_render_ship!=ship or not nav.validate_source_ship(ship) or _float(surface._source_days)!=_float(nav.elapsed_days):return _reject("invalid_native_handoff_owners")
	var agl:float=surface.altitude(ship)
	if not is_finite(agl) or agl<MIN_HANDOFF_AGL_M:return _reject("native_ascent_not_high_enough",maxf(0.0,MIN_HANDOFF_AGL_M-agl) if is_finite(agl) else 0.0)
	var candidate_ship:=Trial._fork_ship(ship);var candidate_nav:RefCounted=nav.fork_runtime();var candidate_gear:=_fork_gear(gear);var candidate_world:=_fork_world(world)
	if candidate_ship==null or candidate_nav==null or candidate_gear==null or candidate_world==null:return _reject("handoff_fork_failed")
	candidate_world.site_id="";candidate_world.pending_id="";candidate_world.pending_site_id="";candidate_world.transfer_remaining=0.0
	var body:Dictionary=candidate_world.by_id[str(candidate_world.focus_id)]
	var rotation:=Gas._basis_readonly(candidate_world,body,nav.elapsed_days)
	if rotation.is_empty():return _reject("handoff_rotation_unavailable")
	var chart:Basis=surface.globe.basis_at(surface.globe.latitude,surface.globe.longitude);var inertial:Basis=rotation.basis
	var local:=Phone.to_bodyfixed_point(chart,float(surface.globe.radius),ship.position)
	var local_velocity:=Phone.to_bodyfixed_vector(chart,ship.velocity)
	if local.size()!=3 or local_velocity.size()!=3:return _reject("handoff_chart_unavailable")
	var relative:=_multiply(inertial,local);var velocity:=_multiply(inertial,local_velocity)
	var center:Vector3=candidate_world.local_meters(str(candidate_world.focus_id),nav.elapsed_days);var ideal:=PackedFloat64Array()
	for axis in range(3):ideal.append(float(center[axis])+relative[axis])
	candidate_ship.position=Vector3(ideal[0],ideal[1],ideal[2]);candidate_ship.velocity=Vector3(velocity[0],velocity[1],velocity[2])
	candidate_ship.attitude=(inertial*chart*Basis(ship.attitude)).get_rotation_quaternion().normalized()
	candidate_ship.surface_mode=false;candidate_ship.station_available=false;candidate_ship.source_motion_profile=ship.source_motion_profile;candidate_ship.clear_source_station()
	if not _valid(candidate_ship,candidate_nav,candidate_world) or not NativeSurface._native_pose_valid(_pose(candidate_ship)):return _reject("handoff_pose_outside_supported_range")
	var clearance:=_guard(candidate_world,candidate_ship,nav.elapsed_days)
	if not clearance.ok:return clearance
	var rounding:Array=[]
	for axis in range(3):rounding.append(absf(ideal[axis]-float(candidate_ship.position[axis])))
	var receipt:=_json({"schema":"starfrontier-native-orbit-handoff-v1","policy":POLICY,"velocity_policy":VELOCITY_POLICY,"system_id":int(world.system_id),"body_id":str(world.focus_id),"source_record_hex":str(body.runtime_record_hex),"source_phone_pose_f32_hex":_pose(ship),"space_pose_f32_hex":_pose(candidate_ship),"source_days_f64_hex":_float(nav.elapsed_days),"chart_basis_f32_hex":NativeSurface._native_floats(_basis_values(chart),4),"rotation_basis_f32_hex":NativeSurface._native_floats(_basis_values(inertial),4),"center_f32_hex":NativeSurface._native_floats([center.x,center.y,center.z],4),"ideal_position_f64_hex":NativeSurface._native_floats(Array(ideal),8),"ideal_velocity_f64_hex":NativeSurface._native_floats(Array(velocity),8),"position_rounding_error_m":rounding,"position_rounding_error_f64_hex":NativeSurface._native_floats(rounding,8),"native_display_agl_m":agl,"legacy_orbit_guard":clearance.sample,"source_generation":surface.native_session.generation(),"clock_advanced":false,"fuel_advanced":false,"hp_applied":false,"position_snapped":false,"omega_cross_radius_added":false,"circular_orbit_inserted":false,"full_original_object_bank":false})
	var orbit:=new()
	receipt["source_digest"]=str(world.source_digest);receipt["thrust_profile_enabled"]=bool(ship.source_motion_profile)
	orbit._lineage=_json({"ship":ship.snapshot(),"navigation":nav.snapshot(),"gear":gear.snapshot(),"world":world.snapshot(),"surface":surface.snapshot(),"thrust_profile_enabled":bool(ship.source_motion_profile)})
	orbit._receipt=receipt;orbit._position_f64=ideal.duplicate();orbit._bind(candidate_ship,candidate_nav,candidate_world,candidate_gear)
	var inactive:=Surface.new();inactive.body_id=str(world.focus_id)
	return {"ok":true,"reason":"native_orbit_handoff_prepared","policy":POLICY,"candidate_ship":candidate_ship,"candidate_nav":candidate_nav,"candidate_gear":candidate_gear,"candidate_world":candidate_world,"candidate_surface":inactive,"candidate_orbit":orbit,"receipt":receipt.duplicate(true),"required_extra_climb_m":0.0,"save_after":true}

func snapshot(ship:RefCounted,nav:RefCounted,world:RefCounted,gear:RefCounted)->Dictionary:
	if not _matches(ship,nav,world,gear):return {}
	var result:=_json({"schema":SCHEMA,"version":1,"policy":POLICY,"velocity_policy":VELOCITY_POLICY,"lineage":_lineage,"lineage_sha256":_hash(_lineage),"receipt":_receipt,"thrust_profile_enabled":thrust_profile_enabled(),"generation":_generation,"pose_f32_hex":_pose_hex,"position_f64_hex":NativeSurface._native_floats(Array(_position_f64),8),"elapsed_days_f64_hex":_days_hex,"legacy_pose_anchor":_legacy_pose(ship),"legacy_days_anchor":_decimal(nav.elapsed_days),"owners":_owner_binding(ship,nav,world,gear)})
	result.snapshot_sha256=_hash(result);return result
static func _replay_lineage(data:Dictionary)->Dictionary:
	if not Session._keys(data,["ship","navigation","gear","world","surface","thrust_profile_enabled"]) or not data.thrust_profile_enabled is bool:return {}
	for key:String in ["ship","navigation","gear","world","surface"]:
		if not data[key] is Dictionary:return {}
	var nav:=Navigation.new()
	if not nav.restore(data.navigation):return {}
	var world:=World.new();world.configure(nav.current(),World.FULL_LAYOUT)
	if not world.restore(data.world):return {}
	var ship:=Flight.new();var gear:=Gear.new();var surface:=NativeSurface.new()
	if not ship.restore(data.ship) or not gear.restore(data.gear) or not nav.validate_source_ship(ship) or not nav.bind_thermal_ship(ship):return {}
	if not surface.restore(data.surface,ship,world) or _decimal(surface._source_days)!=nav.elapsed_days:return {}
	nav.elapsed_days=surface._source_days;ship.source_motion_profile=data.thrust_profile_enabled
	return prepare_handoff(ship,nav,gear,surface)
func restore(data:Dictionary,ship:RefCounted,nav:RefCounted,world:RefCounted,gear:RefCounted)->bool:
	if not _lineage.is_empty() or not _plain(data) or not Session._keys(data,KEYS) or data.schema!=SCHEMA or data.version!=1 or data.policy!=POLICY or data.velocity_policy!=VELOCITY_POLICY:last_error="cold_guard_01";return false
	if not _hex(data.snapshot_sha256,32) or not data.lineage is Dictionary or not data.receipt is Dictionary or not data.owners is Dictionary or not data.legacy_pose_anchor is Dictionary or not data.thrust_profile_enabled is bool:last_error="cold_guard_02";return false
	var sealed:=data.duplicate(true);sealed.erase("snapshot_sha256")
	if _hash(sealed)!=data.snapshot_sha256 or not _hex(data.lineage_sha256,32) or _hash(data.lineage)!=data.lineage_sha256 or not NativeSurface._native_pose_valid(data.pose_f32_hex) or not _hex(data.position_f64_hex,24) or not _hex(data.elapsed_days_f64_hex,8) or not Gear._whole(data.generation,0,100000000):last_error="cold_guard_03";return false
	if gear==null or gear.get_script()!=Gear or gear.snapshot().is_empty() or not _valid(ship,nav,world,true) or ship.surface_mode or not world.site_id.is_empty() or not world.pending_id.is_empty() or not world.pending_site_id.is_empty():last_error="cold_guard_04";return false
	var replay:=_replay_lineage(data.lineage)
	if not replay.get("ok",false) or replay.receipt!=data.receipt or data.thrust_profile_enabled!=replay.candidate_orbit.thrust_profile_enabled():last_error="cold_guard_05";return false
	var days:float=str(data.elapsed_days_f64_hex).hex_decode().decode_double(0)
	if not is_finite(days) or days<float(replay.candidate_nav.elapsed_days) or days>1e9 or _decimal(days)!=data.legacy_days_anchor or data.legacy_days_anchor!=nav.elapsed_days:last_error="cold_guard_06";return false
	if data.generation>0 and days<=float(replay.candidate_nav.elapsed_days):last_error="cold_guard_07";return false
	var pose:=NativeSurface._native_decode_pose(data.pose_f32_hex)
	var position:=PackedFloat64Array(NativeSurface._native_numbers(data.position_f64_hex,8))
	for value:float in position:
		if not is_finite(value) or absf(value)>1e9:last_error="cold_position_f64_invalid";return false
	if Vector3(position[0],position[1],position[2])!=pose.position:last_error="cold_position_f64_projection_mismatch";return false
	var copy:=Trial._fork_ship(ship);var copied_nav:RefCounted=nav.fork_runtime()
	copy.position=pose.position;copy.velocity=pose.velocity;copy.attitude=pose.attitude;copied_nav.elapsed_days=days
	if _legacy_pose(copy)!=data.legacy_pose_anchor or _owner_binding(copy,copied_nav,world,gear)!=data.owners:last_error="cold_guard_08";return false
	# The caller's decimal restore may normalize a unit quaternion. It may not
	# move position or velocity; exact F32 quaternion bits remain authoritative.
	if ship.position!=pose.position or ship.velocity!=pose.velocity or absf(ship.attitude.dot(pose.attitude))<0.999999:last_error="cold_guard_09";return false
	if data.generation==0 and (data.pose_f32_hex!=replay.receipt.space_pose_f32_hex or data.position_f64_hex!=replay.receipt.ideal_position_f64_hex or data.elapsed_days_f64_hex!=replay.receipt.source_days_f64_hex):last_error="cold_guard_10";return false
	if data.owners.system_id!=replay.receipt.system_id or data.owners.body_id!=replay.receipt.body_id or data.owners.source_record_hex!=replay.receipt.source_record_hex:last_error="cold_guard_11";return false
	# No engine, contact response, fuel or clock interval runs during restore.
	_lineage=data.lineage.duplicate(true);_receipt=data.receipt.duplicate(true);_generation=int(data.generation);_pose_hex=str(data.pose_f32_hex);_position_f64=position;_days_hex=str(data.elapsed_days_f64_hex);_owners=data.owners.duplicate(true)
	ship.position=pose.position;ship.velocity=pose.velocity;ship.attitude=pose.attitude;ship.source_motion_profile=data.thrust_profile_enabled;nav.elapsed_days=days
	return true
func prepare(ship:RefCounted,nav:RefCounted,gear:RefCounted,world:RefCounted,seconds:float,steering:Vector2=Vector2.ZERO,roll:float=0.0,lift:float=0.0)->Dictionary:
	if not _matches(ship,nav,world,gear) or not _valid(ship,nav,world) or not is_finite(seconds) or seconds<=0 or seconds>MAX_SECONDS or not steering.is_finite() or not is_finite(roll) or not is_finite(lift):return _reject("invalid_orbit_interval_or_owners")
	var cs:=Trial._fork_ship(ship);var cn:RefCounted=nav.fork_runtime();var cg:=_fork_gear(gear);var cw:=_fork_world(world);var inactive:=Surface.new();inactive.body_id=str(world.focus_id)
	if cs==null or cn==null or cg==null or cw==null or not cn.bind_thermal_ship(cs) or not cn.apply_fuel_availability(cs):return _reject("orbit_interval_fork_failed")
	var speed:=Gas.raw_speed(cs.velocity)
	if not speed.get("ok",false):return _reject("invalid_orbit_gear_speed")
	var gear_context:={"flight_state_u8":0,"autopilot_phase_u8":0,"speed_s32":int(speed.speed_s32),"paused":false}
	var advanced:Dictionary=cg.advance_seconds(seconds,gear_context)
	if not advanced.get("ok",false):return _reject("orbit_gear_interval_rejected")
	var before_day:float=cn.elapsed_days;cn.elapsed_days=before_day+seconds/86400.0
	if not is_finite(cn.elapsed_days) or cn.elapsed_days<before_day or cn.elapsed_days>1e9:return _reject("orbit_clock_rejected")
	var gravity:Vector3=cw.gravity_at(cs.position,cn.elapsed_days)
	if not gravity.is_finite():return _reject("orbit_gravity_unavailable")
	cs.step(seconds,steering,roll,gravity,lift)
	if not Trial._finite_ship(cs):return _reject("orbit_motion_invalid")
	# Flight computes the real filtered impulse/velocity, but its Float32
	# position cannot retain centimetre-scale displacement at this frame's
	# tens-of-megametres coordinates. Carry the SAME semi-implicit displacement
	# in double precision; retain the residual across ticks and cold restores.
	var position:=_position_f64.duplicate()
	for axis in range(3):
		position[axis]+=float(cs.velocity[axis])*seconds
		if not is_finite(position[axis]) or absf(position[axis])>1e9:return _reject("orbit_position_accumulator_invalid")
	cs.position=Vector3(position[0],position[1],position[2])
	var commands:=Fuel.commands(cs,seconds);var state:Dictionary=cg.state(gear_context)
	var sampler:=Atmosphere.new();var context:Dictionary=sampler.sample(cw,cs,inactive,cn.elapsed_days,bool(state.get("f1014_raw_gear_flag",false)))
	if not context.get("ok",false):return _reject("orbit_atmosphere_rejected")
	context.commands_s16=commands.duplicate(true)
	context.thermal={"apply_f1014":bool(context.apply_f1014),"altitude_s32":int(context.altitude_s32),"speed_s32":int(context.speed_s32),"velocity_s32":context.velocity_s32.duplicate(),"shielding":bool(cn.fuel_state(cs).get("atmospheric_shielding_installed",false)),"gear_down":bool(context.gear_down),"wind_enabled":false,"wind_armed":false,"parent_shield_s16":0,"wind_flags_u8":0}
	var fuel:Dictionary=cn.advance_fuel_seconds(seconds,context,cs)
	if not fuel.get("ok",false):return _reject("orbit_fuel_thermal_rejected")
	var thermal:Dictionary=fuel.get("thermal",{})
	if thermal.get("velocity_changed",false):
		var before:Array=thermal.velocity_before_s32;var after:Array=thermal.velocity_after_s32
		cs.velocity+=Basis(context.velocity_to_phone_basis)*(Vector3(int(after[0])-int(before[0]),int(after[1])-int(before[1]),int(after[2])-int(before[2]))*float(context.velocity_unit_mps))
	if not cn.apply_fuel_availability(cs) or not cn.validate_source_ship(cs) or not Trial._finite_ship(cs):return _reject("orbit_post_interval_owner_mismatch")
	var clearance:=_guard(cw,cs,cn.elapsed_days)
	if not clearance.ok:return clearance
	var candidate:=new();candidate._lineage=_lineage.duplicate(true);candidate._receipt=_receipt.duplicate(true);candidate._position_f64=position;candidate._generation=_generation+1;candidate._bind(cs,cn,cw,cg)
	var receipt:={"schema":"starfrontier-native-manual-space-interval-v1","policy":POLICY,"seconds_f64_hex":_float(seconds),"days_before_f64_hex":_float(before_day),"days_after_f64_hex":_float(cn.elapsed_days),"generation":candidate._generation,"gear_position_u16":int(state.position_u16),"commands_s16":commands.duplicate(),"legacy_orbit_guard":clearance.sample}
	return {"ok":true,"reason":"native_orbit_interval_prepared","policy":POLICY,"candidate_ship":cs,"candidate_nav":cn,"candidate_gear":cg,"candidate_world":cw,"candidate_surface":inactive,"candidate_orbit":candidate,"interval_receipt":receipt,"fuel":fuel,"gear":advanced,"destruction_requested":bool(fuel.get("destruction_requested",false)) or cs.hull<=0,"save_after":false}
