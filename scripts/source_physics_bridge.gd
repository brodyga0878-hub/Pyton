extends RefCounted
# Explicit sampled source force for the nominal-day SI controller. This keeps
# F603's truncation/asymmetry; it is not the original per-frame integrator.
const Gravity=preload("res://scripts/source_gravity.gd")
const Units=preload("res://scripts/source_units.gd")
const Clock=preload("res://scripts/source_clock.gd")
const CONTRACT:="sampled-f603-nominal-day-si-v1"
const REFERENCE_STEP_TICKS:=49710
const TICKS_PER_SECOND:=4294967296.0/86400.0
const VELOCITY_UNIT_MPS:=16785.0/172800.0
const FRACTION_SCALE:=65536.0

static func _step(value:Variant)->bool:
	return value is int and value>=1 and value<=0x7fffffff

static func _position(value:Variant)->bool:
	if not (value is PackedInt64Array or value is Array) or value.size()!=3:return false
	for coordinate in value:
		if not coordinate is int:return false
	return true

static func _coefficient(value:Variant)->bool:
	return value is int and value>=0 and value<=0xffffffff

static func sample_acceleration(parent_record:PackedByteArray,relative_raw:Variant,reference_step_ticks:Variant=REFERENCE_STEP_TICKS)->Dictionary:
	if parent_record.size()!=68 or not _position(relative_raw) or not _step(reference_step_ticks):return {}
	var coefficient:=Gravity.coefficient(parent_record)
	if coefficient.is_empty():return {}
	return sample_prepared(int(coefficient.a4_u32),relative_raw,reference_step_ticks)

static func sample_prepared(a4_u32:Variant,relative_raw:Variant,reference_step_ticks:Variant=REFERENCE_STEP_TICKS)->Dictionary:
	if not _coefficient(a4_u32) or not _position(relative_raw) or not _step(reference_step_ticks):return {}
	# Each sample starts at rest. Both integer velocity and its fraction words
	# are zero; no hidden impulse history is accumulated by this controller.
	var body:=PackedByteArray();body.resize(Gravity.OBJECT_BYTES);body.fill(0)
	var parent:=body.duplicate();body[0x56]=1
	parent.encode_u32(0xa4,int(a4_u32))
	for axis in range(3):body.encode_s64(0x3e+axis*8,int(relative_raw[axis]))
	var kick:=Gravity.update(body,parent,int(reference_step_ticks))
	if kick.is_empty():return {}
	var duration:=float(reference_step_ticks)/TICKS_PER_SECOND
	var velocity_q16:=PackedInt64Array();var delta_velocity:Array=[];var acceleration_values:Array=[]
	for axis in range(3):
		var combined:=int(kick.velocity_s32[axis])*65536+int(kick.fraction_u16[axis])
		velocity_q16.append(combined)
		var delta:=float(combined)*(VELOCITY_UNIT_MPS/FRACTION_SCALE)
		delta_velocity.append(delta);acceleration_values.append(delta/duration)
	var gravity:=sqrt(float(acceleration_values[0])*float(acceleration_values[0])+float(acceleration_values[1])*float(acceleration_values[1])+float(acceleration_values[2])*float(acceleration_values[2]))
	var vector:=Vector3(float(acceleration_values[0]),float(acceleration_values[1]),float(acceleration_values[2]))
	if not is_finite(gravity) or not vector.is_finite():return {}
	return {"contract":CONTRACT,"source_variant":Gravity.SOURCE_VARIANT,"a4_u32":int(a4_u32),"relative_raw":PackedInt64Array(relative_raw),"reference_step_ticks":int(reference_step_ticks),"reference_duration_seconds":duration,"ticks_per_second":TICKS_PER_SECOND,"velocity_unit_mps":VELOCITY_UNIT_MPS,"velocity_s32":kick.velocity_s32.duplicate(),"fraction_u16":kick.fraction_u16.duplicate(),"delta_velocity_q16":velocity_q16,"delta_velocity_mps":delta_velocity,"acceleration_mps2":acceleration_values,"acceleration":vector,"gravity_mps2":gravity,"source_body":kick.body.duplicate(),"source_trace":kick.trace.duplicate(true),"original_per_frame_dynamics":false,"normalization_quirks_preserved":true}

static func surface_gravity(parent_record:PackedByteArray,surface_position_raw:Variant,reference_step_ticks:Variant=REFERENCE_STEP_TICKS)->Dictionary:
	# The same raw sample supplies the scalar used for surface thrust checks.
	# Its direction remains available to the world; no independent GM law is fit.
	return sample_acceleration(parent_record,surface_position_raw,reference_step_ticks)

static func raw_metres(metres:Variant)->Dictionary:
	# GDScript float cannot exactly represent the top signed64 endpoint.
	# Reject at +/-2^63 before the conversion instead of overflowing an int.
	if not (metres is float or metres is int) or not is_finite(float(metres)):return {}
	var value:=float(metres)/Units.METRES_PER_RAW
	if not is_finite(value) or value<=-9223372036854775808.0 or value>=9223372036854775808.0:return {}
	return {"raw":int(round(value))}

static func relative_from_metres(vector:Variant)->PackedInt64Array:
	if not (vector is Vector3 or vector is Array or vector is PackedFloat64Array):return PackedInt64Array()
	if not vector is Vector3 and vector.size()!=3:return PackedInt64Array()
	var result:=PackedInt64Array()
	for axis in range(3):
		var converted:=raw_metres(vector[axis])
		if converted.is_empty():return PackedInt64Array()
		result.append(int(converted.raw))
	return result
