extends RefCounted
# Explicit phone-input/SI adapter around independently controlled raw source
# motion. Eligible only in a fixed natural-parent arrival frame. Surface, port,
# collision, automatic FOR changes and unsupported input use the existing path.
const Motion=preload("res://scripts/source_motion_pipeline.gd")
const Gravity=preload("res://scripts/source_gravity.gd")
const Profile=preload("res://scripts/source_ship_control_profile.gd")
const Units=preload("res://scripts/source_units.gd")
const SCHEMA:="starfrontier-source-motion-bridge-v1"
const CONTRACT:="source-fixed-natural-parent-phone-motion-v1"
const AXIS_POLICY:="identity-world-axes-proper-local-yaw-pi-q31-v1"
const CLOCK_POLICY:="nominal-day-si-tick-fraction-v1"
const MAX_STEP_SECONDS:=0.1
const MAX_LOCAL_METRES:=1.0e11
const SNAPSHOT_KEYS:=["schema","version","contract","axis_policy","clock_policy","system_id","parent_id","parent_record_sha256","source_spec_sha256","anchor_local_m","anchor_raw_hex","parent_local_m","ticks_fraction_f64_hex","elapsed_days_f64_hex","motion"]
var _motion:=Motion.new()
var _active:=false
var _system_id:=0
var _parent_id:=""
var _parent_digest:=""
var _anchor_local:Array=[]
var _anchor_raw:=PackedInt64Array()
var _parent_local:Array=[]
var _ticks_fraction:=0.0
var _days:=0.0

static func _finite(value:Variant)->bool:return (typeof(value)==TYPE_INT or typeof(value)==TYPE_FLOAT) and is_finite(float(value))
static func _array3(value:Variant)->bool:
	if not value is Array or value.size()!=3:return false
	for component in value:
		if not _finite(component) or absf(float(component))>MAX_LOCAL_METRES:return false
	return true
static func _hex(value:Variant,length:int)->bool:
	if not value is String or value.length()!=length:return false
	for character:String in value:
		if not character in "0123456789abcdef":return false
	return true
static func eligible(world:RefCounted,ship:RefCounted,surface_active:=false)->bool:
	if world==null or ship==null or surface_active or str(world.get("layout_mode"))!="source_jjffe_systems_v4":return false
	if str(ship.get("ship_id"))!="cobra" or bool(ship.get("docked")) or bool(ship.get("surface_mode")) or bool(ship.get("combat_active")) or bool(ship.get("station_available")) or bool(ship.get("autopilot")):return false
	if not _finite(ship.get("hull")) or float(ship.get("hull"))<=0:return false
	if not str(world.get("site_id")).is_empty() or float(world.get("transfer_remaining"))>0:return false
	var bodies:Variant=world.get("by_id");var focus:=str(world.get("focus_id"))
	if not bodies is Dictionary or not bodies.has(focus):return false
	var parent:Dictionary=bodies[focus]
	return str(parent.get("kind","")) not in ["star","barycenter"] and _hex(parent.get("runtime_record_hex"),136)
static func _record(world:RefCounted)->PackedByteArray:
	return str(world.by_id[str(world.focus_id)].get("runtime_record_hex","")).hex_decode()
static func _parent_body(record:PackedByteArray)->PackedByteArray:
	var coefficient:=Gravity.coefficient(record)
	if coefficient.is_empty():return PackedByteArray()
	var result:=PackedByteArray();result.resize(Motion.OBJECT_BYTES);result.fill(0);result.encode_u32(0xa4,int(coefficient.a4_u32));return result
static func _orientation(attitude:Quaternion)->PackedInt64Array:
	var basis:=Basis(attitude.normalized())
	# Native +X is left, +Y up, +Z forward. The authored phone ship has
	# forward -Basis.z, so use a proper LOCAL yaw(pi), never global reflection.
	var axes:=[-basis.x,basis.y,-basis.z];var values:=PackedInt64Array()
	for axis:Vector3 in axes:
		for component in [axis.x,axis.y,axis.z]:values.append(clampi(roundi(float(component)*2147483647.0),-2147483647,2147483647))
	return values
static func _template()->PackedByteArray:
	var profile:=Profile.describe("cobra")
	if profile.is_empty():return PackedByteArray()
	var body:=PackedByteArray();body.resize(Motion.OBJECT_BYTES);body.fill(0)
	body[0x56]=1;body.encode_u16(0x82,38);body.encode_u16(0xe4,int(profile.source_mass_tonnes)*4)
	for i in range(6):body.encode_u16(0xbc+i*2,int(profile.source_axis_thrust_s16[i])&65535)
	return body
static func _raw_position(body:PackedByteArray)->PackedInt64Array:
	return PackedInt64Array([body.decode_s64(0x3e),body.decode_s64(0x46),body.decode_s64(0x4e)])
static func _write_orientation(body:PackedByteArray,attitude:Quaternion)->void:
	var values:=_orientation(attitude)
	for i in range(9):body.encode_s32(i*4,values[i])
static func _raw_from_metres(value:float)->int:return roundi(value/Units.METRES_PER_RAW)
static func _float_hex(value:float)->String:
	var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value);return bytes.hex_encode()
static func _velocity_error(expected:Vector3,actual:Vector3)->float:
	return maxf(0.000004,maxf(expected.length(),actual.length())*0.0000003)

func is_active()->bool:return _active
# Valid only for an active session. After strict restore this exact saved
# nominal-day value may replace a rounded decimal Navigation JSON candidate.
func elapsed_days()->float:return _days if _active else NAN
func reset()->void:
	_motion=Motion.new();_active=false;_anchor_local=[];_anchor_raw=PackedInt64Array();_parent_local=[];_ticks_fraction=0
func configure(world:RefCounted,ship:RefCounted,days:Variant)->bool:
	if not eligible(world,ship) or not _finite(days) or float(days)<0 or not ship.position.is_finite() or not ship.velocity.is_finite() or not ship.attitude.is_finite() or ship.attitude.length_squared()<0.0001:return false
	var center:Vector3=world.local_meters(str(world.focus_id),float(days))
	if not center.is_finite() or ship.position.length()>MAX_LOCAL_METRES or ship.velocity.length()>100000000.0:return false
	var body:=_template();var record:=_record(world);var parent:=_parent_body(record)
	if body.is_empty() or parent.is_empty():return false
	for axis in range(3):
		# Subtract in double precision at the conversion boundary, not through
		# another Float32 Vector3. Persistent raw position stays authoritative.
		var relative:=float(ship.position[axis])-float(center[axis])
		if absf(relative)>MAX_LOCAL_METRES:return false
		body.encode_s64(0x3e+axis*8,_raw_from_metres(relative))
		var raw_velocity:=float(ship.velocity[axis])/Motion.VELOCITY_UNIT_MPS
		var integer:=floori(raw_velocity);var fraction:=roundi((raw_velocity-float(integer))*65536.0)
		if fraction==65536:integer+=1;fraction=0
		if integer<(-0x80000000) or integer>0x7fffffff:return false
		body.encode_s32(0x8c+axis*4,integer);body.encode_u16(0xec+axis*2,fraction)
	_write_orientation(body,ship.attitude)
	var candidate:=Motion.new()
	if not candidate.configure(body,parent):return false
	_motion=candidate;_system_id=int(world.system_id);_parent_id=str(world.focus_id);_parent_digest=str(world.by_id[_parent_id].runtime_record_hex).sha256_text()
	_anchor_local=[float(ship.position.x),float(ship.position.y),float(ship.position.z)];_anchor_raw=_raw_position(body)
	_parent_local=[float(center.x),float(center.y),float(center.z)];_ticks_fraction=0;_days=float(days);_active=true;return true

func _position(body:PackedByteArray)->Vector3:
	var raw:=_raw_position(body);var values:Array=[]
	for axis in range(3):values.append(float(_anchor_local[axis])+float(raw[axis]-_anchor_raw[axis])*Units.METRES_PER_RAW)
	return Vector3(float(values[0]),float(values[1]),float(values[2]))
func _velocity(body:PackedByteArray)->Vector3:
	var si:=Motion.decode_si(body)
	return Vector3(float(si.velocity_mps[0]),float(si.velocity_mps[1]),float(si.velocity_mps[2]))
func _matches(world:RefCounted,ship:RefCounted,days:float)->bool:
	if not _active or not eligible(world,ship) or int(world.system_id)!=_system_id or str(world.focus_id)!=_parent_id:return false
	if str(world.by_id[_parent_id].runtime_record_hex).sha256_text()!=_parent_digest:return false
	var center:Vector3=world.local_meters(_parent_id,days)
	for axis in range(3):
		if absf(float(center[axis])-float(_parent_local[axis]))>0.01:return false
	var body:=_motion.raw_body();var position:=_position(body);var velocity:=_velocity(body)
	return position.is_finite() and velocity.is_finite() and position.distance_to(ship.position)<=maxf(0.002,maxf(position.length(),ship.position.length())*0.0000003) and velocity.distance_to(ship.velocity)<=_velocity_error(velocity,ship.velocity)

func synchronized(world:RefCounted,ship:RefCounted,days:Variant)->bool:
	# For a quiescent save/origin boundary, not before a simulation step whose
	# clock and phone attitude have intentionally advanced. Parent-relative
	# velocity is meaningful here only for the eligible natural-focus frame.
	if not _finite(days) or float(days)<0 or not _matches(world,ship,float(days)):return false
	if absf(_days-float(days))>maxf(1.0e-9,absf(float(days))*0.000000000000002):return false
	if not ship.attitude.is_finite() or ship.attitude.length_squared()<0.0001:return false
	var orientation:=_orientation(ship.attitude);var body:=_motion.raw_body()
	for index in range(9):
		if absi(int(body.decode_s32(index*4))-orientation[index])>2048:return false
	return true

func step(dt:Variant,ship:RefCounted,world:RefCounted,days:Variant,lift:Variant=0.0)->Dictionary:
	if not _finite(dt) or float(dt)<=0 or float(dt)>MAX_STEP_SECONDS or not _finite(days) or float(days)<0 or not _finite(lift):return {"ok":false,"handled":false,"reason":"invalid_time_or_input"}
	if ship==null or not _finite(ship.get("target_speed")) or absf(float(ship.target_speed)/Motion.VELOCITY_UNIT_MPS)>2147483647.0:return {"ok":false,"handled":false,"reason":"invalid_target_speed"}
	if not ship.attitude.is_finite() or ship.attitude.length_squared()<0.0001:return {"ok":false,"handled":false,"reason":"invalid_attitude"}
	if not eligible(world,ship) or absf(float(lift))>0.000001:
		reset();return {"ok":true,"handled":false,"reason":"outside_fixed_parent_scope_or_vertical_assist"}
	if not _active:
		if not configure(world,ship,float(days)):return {"ok":false,"handled":false,"reason":"configuration_failed"}
	elif not _matches(world,ship,float(days)):
		reset();return {"ok":true,"handled":false,"reason":"external_state_change_requires_reanchor"}
	var body:=_motion.raw_body();_write_orientation(body,ship.attitude)
	var saved_state:=_motion.snapshot()
	if not _motion.configure(body,str(saved_state.parent_hex).hex_decode()):return {"ok":false,"handled":false,"reason":"orientation_update_failed"}
	var accumulated:=float(dt)*Motion.NOMINAL_TICKS_PER_SECOND+_ticks_fraction
	var ticks:=floori(accumulated);var remainder:=accumulated-float(ticks)
	if ticks<0 or ticks>0x7fffffff:return {"ok":false,"handled":false,"reason":"source_tick_range"}
	var target:=roundi(float(ship.target_speed)/Motion.VELOCITY_UNIT_MPS)
	var command:=PackedInt64Array([0,0,0])
	if not ship.assisted:
		# Explicit analog phone-input adapter, not the original key dispatcher:
		# full lever maps to the real native forward/retro limit, no engine bonus.
		var throttle:=clampf(float(ship.target_speed)/float(ship.MAX_SPEED),-1.0,1.0)
		var limit:=int(body.decode_s16(0xc4 if throttle>=0 else 0xc6))
		command[2]=roundi(absf(throttle)*float(limit))
	var result:=_motion.advance(ticks,target,command,not bool(ship.assisted),0)
	if result.is_empty():
		_motion.restore(saved_state);return {"ok":false,"handled":false,"reason":"source_step_failed"}
	var position:=_position(result.body);var velocity:=_velocity(result.body)
	if not position.is_finite() or not velocity.is_finite() or position.length()>MAX_LOCAL_METRES:
		_motion.restore(saved_state);return {"ok":false,"handled":false,"reason":"source_state_out_of_display_range"}
	ship.position=position;ship.velocity=velocity;_ticks_fraction=remainder;_days=float(days)
	return {"ok":true,"handled":true,"reason":"source_fixed_parent_step","profile":CONTRACT,"ticks":ticks,"ticks_fraction":_ticks_fraction,"source_order":result.source_order,"original_complete_player_pipeline":false}

func snapshot()->Dictionary:
	if not _active:return {}
	var raw:=PackedByteArray();raw.resize(24)
	for axis in range(3):raw.encode_s64(axis*8,_anchor_raw[axis])
	return {"schema":SCHEMA,"version":1,"contract":CONTRACT,"axis_policy":AXIS_POLICY,"clock_policy":CLOCK_POLICY,"system_id":_system_id,"parent_id":_parent_id,"parent_record_sha256":_parent_digest,"source_spec_sha256":Profile.SPEC_SHA,"anchor_local_m":_anchor_local.duplicate(),"anchor_raw_hex":raw.hex_encode(),"parent_local_m":_parent_local.duplicate(),"ticks_fraction_f64_hex":_float_hex(_ticks_fraction),"elapsed_days_f64_hex":_float_hex(_days),"motion":_motion.snapshot()}
func restore(data:Variant,world:RefCounted,ship:RefCounted,days:Variant)->bool:
	if not data is Dictionary or data.size()!=SNAPSHOT_KEYS.size() or not eligible(world,ship) or not _finite(days):return false
	for key in SNAPSHOT_KEYS:
		if not data.has(key):return false
	if data.schema!=SCHEMA or not Motion._whole(data.version,1,1) or data.contract!=CONTRACT or data.axis_policy!=AXIS_POLICY or data.clock_policy!=CLOCK_POLICY or data.source_spec_sha256!=Profile.SPEC_SHA:return false
	if not Motion._whole(data.system_id,0,0xffffffff) or int(data.system_id)!=int(world.system_id) or not data.parent_id is String or data.parent_id!=str(world.focus_id):return false
	if data.parent_record_sha256!=str(world.by_id[str(world.focus_id)].runtime_record_hex).sha256_text():return false
	if not _array3(data.anchor_local_m) or not _array3(data.parent_local_m) or not _hex(data.anchor_raw_hex,48) or not _hex(data.ticks_fraction_f64_hex,16) or not _hex(data.elapsed_days_f64_hex,16):return false
	var tick_fraction:=str(data.ticks_fraction_f64_hex).hex_decode().decode_double(0);var saved_days:=str(data.elapsed_days_f64_hex).hex_decode().decode_double(0)
	if not is_finite(tick_fraction) or tick_fraction<0 or tick_fraction>=1 or not is_finite(saved_days) or saved_days<0 or absf(saved_days-float(days))>maxf(1.0e-9,absf(float(days))*0.000000000000002):return false
	var motion:=Motion.new()
	if not motion.restore(data.motion):return false
	var body:=motion.raw_body();var template:=_template();var mutable:=PackedByteArray();mutable.resize(Motion.OBJECT_BYTES);mutable.fill(0)
	for span in [[0,36],[0x3e,24],[0x8c,12],[0xb6,6],[0xec,6],[0xf2,12]]:
		for index in range(int(span[0]),int(span[0])+int(span[1])):mutable[index]=1
	for index in range(Motion.OBJECT_BYTES):
		if mutable[index]==0 and body[index]!=template[index]:return false
	if str(data.motion.parent_hex).hex_decode()!=_parent_body(_record(world)):return false
	var orientation:=_orientation(ship.attitude)
	for index in range(9):
		if absi(int(body.decode_s32(index*4))-orientation[index])>2048:return false
	var raw:=str(data.anchor_raw_hex).hex_decode();var anchor:=PackedInt64Array()
	for axis in range(3):
		anchor.append(raw.decode_s64(axis*8))
		if absf(float(anchor[axis]))>1.0e15 or absf(float(body.decode_s64(0x3e+axis*8)))>1.0e15:return false
		if anchor[axis]!=_raw_from_metres(float(data.anchor_local_m[axis])-float(data.parent_local_m[axis])):return false
	var candidate=get_script().new();candidate._motion=motion;candidate._active=true;candidate._system_id=int(data.system_id);candidate._parent_id=str(data.parent_id);candidate._parent_digest=str(data.parent_record_sha256)
	candidate._anchor_local=data.anchor_local_m.duplicate();candidate._anchor_raw=anchor;candidate._parent_local=data.parent_local_m.duplicate();candidate._ticks_fraction=tick_fraction;candidate._days=saved_days
	if not candidate.synchronized(world,ship,float(days)):return false
	_motion=motion;_active=true;_system_id=candidate._system_id;_parent_id=candidate._parent_id;_parent_digest=candidate._parent_digest;_anchor_local=candidate._anchor_local;_anchor_raw=anchor;_parent_local=candidate._parent_local;_ticks_fraction=candidate._ticks_fraction;_days=candidate._days
	return true
