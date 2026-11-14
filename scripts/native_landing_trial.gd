extends RefCounted
# Explicit manual native-contact trial. All interval owners are private copies
# until the host swaps the four returned references together. No save, sound,
# scene, original World, or diagnostic global is changed during preparation.
const Flight=preload("res://scripts/flight_model.gd")
const FuelFlight=preload("res://scripts/source_fuel_flight_bridge.gd")
const Atmosphere=preload("res://scripts/source_atmosphere_contact.gd")
const FuelContact=preload("res://scripts/source_fuel_contact.gd")
const POLICY:="atomic-manual-native-contact-interval-v1"
const MAX_SECONDS:=4.0

static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"policy":POLICY}

static func _copy_value(value:Variant)->Variant:
	if value is Dictionary or value is Array:return value.duplicate(true)
	if value is PackedByteArray or value is PackedInt32Array or value is PackedInt64Array or value is PackedFloat32Array or value is PackedFloat64Array or value is PackedStringArray or value is PackedVector2Array or value is PackedVector3Array or value is PackedColorArray:return value.duplicate()
	return value

static func _fork_ship(ship:RefCounted)->RefCounted:
	if ship==null or ship.get_script()!=Flight:return null
	var result:=Flight.new()
	# This is an internal runtime fork, not the untrusted save-file boundary.
	# Catalogues are immutable lookups; every mutable script container is copied.
	for property:Dictionary in ship.get_property_list():
		if (int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE)!=0:
			result.set(str(property.name),_copy_value(ship.get(str(property.name))))
	return result

static func _gear_context(ship:RefCounted,surface:RefCounted)->Dictionary:
	var speed:=FuelContact.raw_speed(ship.velocity)
	if not speed.get("ok",false):return {}
	# This is the existing manual phone gear adapter. It does not claim that
	# the host phase is the original parked-state byte 0x32.
	return {"flight_state_u8":0,"autopilot_phase_u8":0x24 if surface.landed else 0,"speed_s32":int(speed.speed_s32),"paused":false}

static func _fuel_context(ship:RefCounted,nav:RefCounted,surface:RefCounted,gear_state:Dictionary,commands:Array)->Dictionary:
	var sampler:=Atmosphere.new()
	# F574's independent model84 atmospheric probe is read-only. F576 is run
	# exactly once by stage_manual and its actual trace also makes the mesh.
	var context:Dictionary=sampler.sample(surface.native_world(),ship,surface,nav.elapsed_days,bool(gear_state.get("f1014_raw_gear_flag",false)))
	if not context.get("ok",false):return context
	context.commands_s16=commands.duplicate(true)
	context.thermal={"apply_f1014":bool(context.apply_f1014),"altitude_s32":int(context.altitude_s32),"speed_s32":int(context.speed_s32),"velocity_s32":context.velocity_s32.duplicate(),"shielding":bool(nav.fuel_state(ship).get("atmospheric_shielding_installed",false)),"gear_down":bool(context.gear_down),"wind_enabled":false,"wind_armed":false,"parent_shield_s16":0,"wind_flags_u8":0}
	return context

static func _finite_ship(ship:RefCounted)->bool:
	return ship.position.is_finite() and ship.velocity.is_finite() and ship.attitude.is_finite() and ship.attitude.length_squared()>0.0001 and is_finite(ship.hull) and ship.hull>=0 and ship.hull<=100 and is_finite(ship.target_speed)

static func prepare(ship:RefCounted,nav:RefCounted,gear:RefCounted,surface:RefCounted,seconds:float,steering:Vector2=Vector2.ZERO,roll:float=0.0,lift:float=0.0)->Dictionary:
	if ship==null or nav==null or gear==null or surface==null:return _reject("missing_interval_owner")
	if not is_finite(seconds) or seconds<=0 or seconds>MAX_SECONDS or not steering.is_finite() or not is_finite(roll) or not is_finite(lift):return _reject("invalid_interval_or_controls")
	if not surface.has_method("stage_manual") or not surface.has_method("fork_runtime") or not surface.has_method("native_world") or not surface.has_method("acknowledge_post_interval"):return _reject("not_native_trial_surface")
	if not surface.active or not ship.surface_mode or ship.docked or ship.hull<=0 or ship.autopilot or surface.landing or surface.ready_for_orbit:return _reject("unsupported_trial_phase")
	if not _finite_ship(ship) or not nav.is_source_hyperdrive() or nav.remaining>0 or not is_finite(nav.elapsed_days) or nav.elapsed_days<0:return _reject("invalid_live_interval")
	var candidate_ship:=_fork_ship(ship)
	var candidate_nav:RefCounted=nav.fork_runtime()
	var candidate_gear:RefCounted=gear.get_script().new()
	if candidate_ship==null or candidate_nav==null or not candidate_gear.restore(gear.snapshot()):return _reject("interval_fork_failed")
	var candidate_surface:RefCounted=surface.fork_runtime(candidate_ship)
	if candidate_surface==null:return _reject("surface_fork_failed")
	if not candidate_nav.bind_thermal_ship(candidate_ship) or not candidate_nav.apply_fuel_availability(candidate_ship):return _reject("source_hp_or_thrust_binding_failed")
	var gear_context:=_gear_context(candidate_ship,candidate_surface)
	if gear_context.is_empty():return _reject("invalid_gear_velocity")
	var gear_result:Dictionary=candidate_gear.advance_seconds(seconds,gear_context)
	if not gear_result.get("ok",false):return _reject("gear_interval_rejected")
	var gear_state:Dictionary=candidate_gear.state(gear_context)
	var before_days:float=candidate_nav.elapsed_days
	candidate_nav.elapsed_days=before_days+seconds/86400.0
	if not is_finite(candidate_nav.elapsed_days) or candidate_nav.elapsed_days<before_days or candidate_nav.elapsed_days>1e9:return _reject("clock_interval_rejected")
	candidate_surface.set_source_time(candidate_nav.elapsed_days)
	var interval_receipt:={"schema":"starfrontier-native-manual-interval-v1","seconds_f64_hex":_float_hex(seconds),"days_before_f64_hex":_float_hex(before_days),"days_after_f64_hex":_float_hex(candidate_nav.elapsed_days),"gear_position_u16":int(gear_state.get("position_u16",0)),"policy":POLICY}
	var stage:Dictionary=candidate_surface.stage_manual(candidate_ship,seconds,steering,roll,lift,int(gear_state.get("position_u16",0)),interval_receipt)
	if not stage.get("ok",false):return _reject("native_stage:"+str(stage.get("reason","rejected")))
	var commands:Variant=stage.get("fuel_commands")
	if not commands is Array or commands.size()!=3:return _reject("invalid_preimpact_fuel_commands")
	var damage_calls:Variant=stage.get("damage_calls")
	if not damage_calls is Array:return _reject("invalid_native_damage_commands")
	var damage:Dictionary=candidate_nav.apply_contact_damage(damage_calls,candidate_ship)
	if not damage.get("ok",false):return _reject("native_hp_rejected")
	var parked:bool=(bool(stage.get("parked_idle",false)) or bool(stage.get("landing_accepted",false))) and candidate_ship.hull>0
	var hpdetail:Dictionary=damage.get("contact_damage",{})
	if not candidate_surface.finish_native_step(candidate_ship,stage,parked,hpdetail):return _reject("native_commit_rejected")
	var fuel_result:Dictionary={"ok":true,"reason":"source_caller_stopped_after_contact_destruction","thermal":{},"destruction_requested":false}
	var destroyed:bool=bool(damage.get("destruction_requested",false)) or candidate_ship.hull<=0
	if not destroyed:
		var context:=_fuel_context(candidate_ship,candidate_nav,candidate_surface,gear_state,commands)
		if not context.get("ok",false):return _reject("atmosphere_context:"+str(context.get("reason","rejected")))
		fuel_result=candidate_nav.advance_fuel_seconds(seconds,context,candidate_ship)
		if not fuel_result.get("ok",false):return _reject("fuel_thermal_interval:"+str(fuel_result.get("reason","rejected")))
		var thermal:Dictionary=fuel_result.get("thermal",{})
		if thermal.get("velocity_changed",false):
			var before:Array=thermal.velocity_before_s32;var after:Array=thermal.velocity_after_s32
			var delta:=Vector3(int(after[0])-int(before[0]),int(after[1])-int(before[1]),int(after[2])-int(before[2]))*float(context.velocity_unit_mps)
			candidate_ship.velocity+=Basis(context.velocity_to_phone_basis)*delta
		destroyed=bool(fuel_result.get("destruction_requested",false)) or candidate_ship.hull<=0
	if not candidate_surface.acknowledge_post_interval(candidate_ship):return _reject("post_interval_native_anchor_rejected")
	if not candidate_nav.apply_fuel_availability(candidate_ship) or not candidate_nav.validate_source_ship(candidate_ship) or not _finite_ship(candidate_ship):return _reject("post_interval_owner_mismatch")
	return {"ok":true,"reason":"native_manual_interval_accepted","policy":POLICY,"candidate_ship":candidate_ship,"candidate_nav":candidate_nav,"candidate_gear":candidate_gear,"candidate_surface":candidate_surface,"interval_receipt":interval_receipt,"stage":stage,"damage":damage,"fuel":fuel_result,"gear":gear_result,"destruction_requested":destroyed,"save_after":bool(candidate_surface.landed)!=bool(surface.landed)}

static func _float_hex(value:float)->String:
	var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value);return bytes.hex_encode()
