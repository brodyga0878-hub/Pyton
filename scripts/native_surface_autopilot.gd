extends RefCounted
# Bounded phone guidance over the existing native-contact interval. This is
# not the complete original FFE autopilot/VM: only Flight's existing controls
# are chosen here. F576/F575 alone decides collision and accepted parking.
const Trial=preload("res://scripts/native_landing_trial.gd")
const Surface=preload("res://scripts/native_surface_model.gd")
const Session=preload("res://scripts/source_natural_contact_session.gd")
const Gear=preload("res://scripts/source_landing_gear_session.gd")
const SCHEMA:="starfrontier-native-surface-autopilot-v1"
const POLICY:="bounded-native-contact-phone-guidance-v1"
const KEYS:=["schema","version","policy","mode","phase","active","steps","elapsed_f64_hex","reason","binding","snapshot_sha256"]
const BINDING_KEYS:=["system_id","body_id","ship_id","source_record_hex","source_generation","raw_body_sha256","raw_parent_sha256","provider_identity","days_f64_hex","phone_pose_f32_hex"]
const LANDING_PHASES:=["gear","align","descent"]
const MAX_DESCENT_MPS:=4.0
const MIN_DESCENT_MPS:=0.35
const MAX_LEVEL_ERROR_RAD:=0.17453292519943295 # Ten degrees, below F575's actual acceptance cone.
var _saved:Dictionary={}

static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"guidance_policy":POLICY}
static func _whole(value:Variant,low:int,high:int)->bool:return (value is int or value is float) and is_finite(float(value)) and value==floorf(float(value)) and value>=low and value<=high
static func _digest(bytes:PackedByteArray)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()
static func _float_hex(value:float)->String:
	var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value);return bytes.hex_encode()
static func _float(value:Variant)->float:
	if not Session._hex(value,8):return NAN
	return str(value).hex_decode().decode_double(0)
static func _json(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
static func _valid_scene(ship:RefCounted,nav:RefCounted,surface:RefCounted,allow_destroyed:bool=false)->bool:
	if ship==null or nav==null or surface==null or surface.get_script()!=Surface:return false
	if not surface.is_native_landing_trial() or not ship.surface_mode or ship.docked or not is_finite(ship.hull) or ship.hull<0 or ship.hull>100 or (ship.hull==0 and not allow_destroyed) or not nav.is_source_hyperdrive() or nav.remaining>0:return false
	if surface.native_session.is_pending() or not surface._native_stage.is_empty() or surface.landing or surface.ready_for_orbit or ship.autopilot:return false
	if not ship.position.is_finite() or not ship.velocity.is_finite() or not ship.attitude.is_finite() or absf(ship.attitude.length_squared()-1.0)>0.0001 or not is_finite(nav.elapsed_days) or nav.elapsed_days!=surface._source_days:return false
	return int(surface.native_world().system_id)==int(nav.current_id) and surface.native_world().focus_id==surface.body_id
static func _binding(ship:RefCounted,nav:RefCounted,surface:RefCounted)->Dictionary:
	return _json({"system_id":int(nav.current_id),"body_id":str(surface.body_id),"ship_id":str(ship.ship_id),"source_record_hex":surface._native_source_record.hex_encode(),"source_generation":surface.native_session.generation(),"raw_body_sha256":_digest(surface.native_session.raw_body()),"raw_parent_sha256":_digest(surface.native_session.raw_parent()),"provider_identity":surface.native_provider.snapshot_identity(),"days_f64_hex":_float_hex(nav.elapsed_days),"phone_pose_f32_hex":Surface._native_pose(ship.position,ship.velocity,ship.attitude)})
static func _sealed(data:Dictionary)->Dictionary:
	var result:Dictionary=_json(data);result.erase("snapshot_sha256");result.snapshot_sha256=Session._hash(result);return result

func configure_land(ship:RefCounted,nav:RefCounted,surface:RefCounted)->bool:
	if not _saved.is_empty() or not _valid_scene(ship,nav,surface) or surface.landed:return false
	var height:Dictionary=surface.height_sample(ship.position.x,ship.position.z)
	if height.is_empty() or not is_finite(float(height.get("height",NAN))):return false
	if not _propulsion_ok(ship,surface):return false
	_saved=_sealed({"schema":SCHEMA,"version":1,"policy":POLICY,"mode":"landing","phase":"gear","active":true,"steps":0,"elapsed_f64_hex":_float_hex(0),"reason":"landing_requested","binding":_binding(ship,nav,surface)})
	return true

func is_active()->bool:return bool(_saved.get("active",false))
func phase()->String:return str(_saved.get("phase","idle"))
func mode()->String:return str(_saved.get("mode",""))
func cancel(reason:String="manual_control")->void:
	if _saved.is_empty():return
	_saved.active=false;_saved.phase="cancelled";_saved.reason=reason.left(160);_saved=_sealed(_saved)
func snapshot()->Dictionary:return _saved.duplicate(true) if is_active() else {}
func fork_runtime()->RefCounted:
	var copy:RefCounted=get_script().new();copy._saved=_saved.duplicate(true);return copy

func restore(data:Dictionary,ship:RefCounted,nav:RefCounted,surface:RefCounted)->bool:
	if not _saved.is_empty() or not _valid_scene(ship,nav,surface) or surface.landed or not Session._keys(data,KEYS):return false
	if data.schema!=SCHEMA or not _whole(data.version,1,1) or data.policy!=POLICY or data.mode!="landing" or not data.active is bool or data.active!=true or data.phase not in LANDING_PHASES:return false
	if not _whole(data.steps,0,1000000000) or not data.reason is String or data.reason.length()>160 or not data.binding is Dictionary or not Session._keys(data.binding,BINDING_KEYS):return false
	var elapsed:=_float(data.elapsed_f64_hex)
	if not is_finite(elapsed) or elapsed<0 or elapsed>1e9 or (int(data.steps)==0 and elapsed!=0):return false
	var candidate:Dictionary=_json(data);var checksum:Variant=candidate.snapshot_sha256;candidate.erase("snapshot_sha256")
	if not Session._hex(checksum,32) or Session._hash(candidate)!=checksum or _json(data.binding)!=_binding(ship,nav,surface):return false
	_saved=_json(data);return true

static func _propulsion_ok(ship:RefCounted,surface:RefCounted)->bool:
	if not ship.propulsion_available or not surface.gravity_vector.is_finite():return false
	var available:float=ship.available_acceleration(Vector3.UP)
	return is_finite(available) and available>surface.gravity_vector.length()+0.25

static func _level_controls(ship:RefCounted,seconds:float)->Dictionary:
	var basis:=Basis(ship.attitude);var up:Vector3=basis.y.normalized();var dot:=clampf(up.dot(Vector3.UP),-1,1)
	var angle:=acos(dot);var error:=up.cross(Vector3.UP)
	if error.length_squared()>0.000000000001:error=basis.transposed()*(error.normalized()*angle)
	elif dot<0:error=Vector3(PI,0,0)
	else:error=Vector3.ZERO
	var rate:float=float(ship.profile().turn_rate)
	# Limit by this actual interval so a large step cannot overshoot upright.
	var gain:=minf(2.0,1.0/seconds)
	return {"steering":Vector2(0,clampf(-error.x*gain/rate,-1,1)),"roll":clampf(-error.z*gain*1.2/rate,-1,1),"angle_rad":angle}

func prepare(ship:RefCounted,nav:RefCounted,gear:RefCounted,surface:RefCounted,seconds:float)->Dictionary:
	if not is_active() or mode()!="landing":return _reject("guidance_inactive")
	if not is_finite(seconds) or seconds<=0 or seconds>1.0:return _reject("invalid_guidance_interval")
	if not _valid_scene(ship,nav,surface) or surface.landed or _binding(ship,nav,surface)!=_saved.binding:return _reject("stale_guidance_binding")
	if gear==null or gear.get_script()!=Gear or gear.snapshot().is_empty():return _reject("invalid_guidance_gear")
	if not _propulsion_ok(ship,surface):return _reject("insufficient_vertical_propulsion")
	var height:Dictionary=surface.height_sample(ship.position.x,ship.position.z)
	if height.is_empty():return _reject("guidance_outside_observed_leaf")
	var altitude:float=ship.position.y-float(height.height)-surface.clearance(ship)
	if not is_finite(altitude):return _reject("nonfinite_guidance_altitude")
	var controls:=_level_controls(ship,seconds);var state:Dictionary=gear.state()
	var deployed:bool=bool(state.get("deployed",false)) and bool(state.get("requested_down",false))
	var phase_name:="descent" if deployed and float(controls.angle_rad)<=MAX_LEVEL_ERROR_RAD else ("gear" if not deployed else "align")
	var available:float=maxf(0.25,ship.acceleration()-surface.gravity_vector.length())
	var desired_velocity:=-clampf(sqrt(2.0*available*maxf(altitude,0))*0.5,MIN_DESCENT_MPS,MAX_DESCENT_MPS) if phase_name=="descent" else 0.0
	return {"ok":true,"reason":"landing_guidance_prepared","guidance_policy":POLICY,"phase":phase_name,"steering":controls.steering,"roll":controls.roll,"lift":desired_velocity/60.0,"target_speed":0.0,"assisted":true,"gear_down":true,"desired_vertical_mps":desired_velocity,"observed_render_altitude_m":altitude,"original_contact_decides_landing":true,"pose_written":false}

func observe(ship:RefCounted,nav:RefCounted,surface:RefCounted,accepted:Dictionary,seconds:float,planned_phase:String)->bool:
	if not is_active() or not accepted.get("ok",false) or accepted.get("candidate_ship")!=ship or accepted.get("candidate_nav")!=nav or accepted.get("candidate_surface")!=surface or not _valid_scene(ship,nav,surface,bool(accepted.get("destruction_requested",false))):return false
	if not is_finite(seconds) or seconds<=0 or seconds>1.0 or planned_phase not in LANDING_PHASES:return false
	var candidate:Dictionary=_saved.duplicate(true);candidate.steps=int(candidate.steps)+1;candidate.elapsed_f64_hex=_float_hex(_float(candidate.elapsed_f64_hex)+seconds);candidate.binding=_binding(ship,nav,surface)
	if surface.landed:
		if surface.native_session.phase()!="parked" or not accepted.get("stage") is Dictionary or not accepted.stage.get("landing_accepted",false):return false
		candidate.active=false;candidate.phase="completed";candidate.reason="original_park_accepted"
	elif bool(accepted.get("destruction_requested",false)):
		candidate.active=false;candidate.phase="cancelled";candidate.reason="ship_destroyed"
	else:candidate.phase=planned_phase;candidate.reason="landing_interval_accepted"
	_saved=_sealed(candidate);return true

func advance(ship:RefCounted,nav:RefCounted,gear:RefCounted,surface:RefCounted,seconds:float)->Dictionary:
	var plan:=prepare(ship,nav,gear,surface,seconds)
	if not plan.get("ok",false):return plan
	var candidate_ship:RefCounted=Trial._fork_ship(ship);var candidate_gear:=Gear.new()
	if candidate_ship==null or not candidate_gear.restore(gear.snapshot()):return _reject("guidance_owner_fork_failed")
	# The existing controller still runs with the real manual Flight input law.
	# Guidance edits control intent only on private candidates, never a pose.
	candidate_ship.assisted=true;candidate_ship.target_speed=0;candidate_ship.autopilot=false
	var request:Dictionary=candidate_gear.command_request(true,Trial._gear_context(candidate_ship,surface))
	if not request.get("ok",false) or not request.get("accepted",false):return _reject("guidance_gear_request_rejected")
	var accepted:=Trial.prepare(candidate_ship,nav,candidate_gear,surface,seconds,plan.steering,float(plan.roll),float(plan.lift))
	if not accepted.get("ok",false):return accepted
	var candidate_pilot:RefCounted=fork_runtime()
	if not candidate_pilot.observe(accepted.candidate_ship,accepted.candidate_nav,accepted.candidate_surface,accepted,seconds,str(plan.phase)):return _reject("guidance_observation_rejected")
	accepted.candidate_pilot=candidate_pilot;accepted.guidance=plan.duplicate(true);accepted.guidance_policy=POLICY
	return accepted
