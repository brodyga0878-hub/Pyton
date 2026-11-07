extends RefCounted
# Uploaded DOS F575, bounded JUMP_002410..JUMP_002432 continuation for the
# player only. Classification, source frame selection and collision geometry
# are required caller inputs; no F569/F570/F576/F577/F578 provider is implied.
# F953 is observed, not executed. Its authoritative HP/RNG owner consumes the
# returned damage requests after this independent raw-body transition.
const Ground=preload("res://scripts/source_ground_surface.gd")
const Math=preload("res://scripts/ground_coordinates.gd")
const Point=preload("res://scripts/source_terrain_point.gd")
const Gravity=preload("res://scripts/source_gravity.gd")
const SOURCE_SHA:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const CONTRACT:="dos-firstenc-f575-postclassification-player-contact-v1"
const OBJECT_BYTES:=338
const DESCRIPTOR_BYTES:=68
const SPEC_BYTES:=24
const MASK:=0xffffffff
const GLOBAL_KEYS:=["collision_flags_u8","collider_index_u8","collision_active_u8","collision_enabled_u8","previous_altitude_s64","collision_kind_u8","player_object_index_u32"]

static func _whole(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
static func _s32(value:int)->int:return Math.signed32(value)
static func _mul(first:int,second:int)->int:return Math.multiply_q31(first,second)
static func _div(numerator:int,denominator:int)->int:
	@warning_ignore("integer_division")
	var quotient:int=absi(numerator)/absi(denominator)
	return -quotient if (numerator<0)!=(denominator<0) else quotient
static func _s64(low:int,high:int)->int:return (_s32(high)<<32)|(low&MASK)
static func _add64(first:int,second:int)->int:
	var low:=(first&MASK)+(second&MASK)
	return _s64(low,_s32((first>>32)+(second>>32)+(low>>32)))
static func _sub64(first:int,second:int)->int:
	var low:=(first&MASK)-(second&MASK)
	return _s64(low,_s32((first>>32)-(second>>32)-(1 if low<0 else 0)))
static func _matrix(body:PackedByteArray)->PackedInt64Array:return Ground._matrix(body)
static func _write_matrix(body:PackedByteArray,matrix:PackedInt64Array)->void:
	for index in range(9):body.encode_s32(index*4,int(matrix[index]))
static func _velocity(body:PackedByteArray)->PackedInt64Array:
	return PackedInt64Array([body.decode_s32(0x8c),body.decode_s32(0x90),body.decode_s32(0x94)])
static func _l1(vector:PackedInt64Array)->int:
	var result:=0
	for component:int in vector:result=_s32(result+_s32(absi(component)))
	return result
static func _dot(first:PackedInt64Array,second:PackedInt64Array)->int:
	var result:=0
	for axis in range(3):result=_s32(result+_mul(first[axis],second[axis]))
	return result
static func _normalize_to(vector:PackedInt64Array,target:int,squared:int)->PackedInt64Array:
	# Complete F1504: signed source squares wrap before the unsigned F1502
	# root; F1501's restoring loop retains original zero-divisor behavior.
	var root:=int(Point.source_square_root(_s32(squared*2)))&MASK;var result:=PackedInt64Array()
	for component:int in vector:result.append(_mul(Ground._divide_q31_signed(component,root),target))
	return result
static func _radial_normal(relative:PackedInt64Array)->PackedInt64Array:
	var shift:=maxi(0,Gravity._vec64_msb(relative)-28);var vector:=PackedInt64Array()
	for component:int in relative:vector.append(_s32(Ground._shift64(component,-shift)&MASK))
	return Ground._normalize_1503(vector)
static func _align_up(matrix:PackedInt64Array,normal:PackedInt64Array)->PackedInt64Array:
	var result:=matrix.duplicate()
	for axis in range(3):result[axis+3]=normal[axis]
	return Ground._swap_matrix_rows(Ground._orthonormalize(Ground._swap_matrix_rows(result)))
static func _reject(body:PackedByteArray,parent:PackedByteArray,reason:String)->Dictionary:
	return {"ok":false,"error":reason,"body_after":body.duplicate(),"parent_after":parent.duplicate(),"globals_after":{},"landing_accepted":false,"normal_q31":[],"damage_calls":[],"callbacks":[],"source_contract":CONTRACT,"source_sha256":SOURCE_SHA}
static func _valid(body:PackedByteArray,parent:PackedByteArray,context:Dictionary)->bool:
	if body.size()!=OBJECT_BYTES or parent.size()!=OBJECT_BYTES:return false
	for key:String in ["body_descriptor","parent_descriptor","body_spec"]:
		if not context.get(key) is PackedByteArray:return false
	if context.body_descriptor.size()!=DESCRIPTOR_BYTES or context.parent_descriptor.size()!=DESCRIPTOR_BYTES or context.body_spec.size()!=SPEC_BYTES:return false
	if not context.get("globals") is Dictionary:return false
	var globals:Dictionary=context.globals
	for key:String in GLOBAL_KEYS:
		if not globals.has(key):return false
	for key:String in ["collision_flags_u8","collider_index_u8","collision_active_u8","collision_enabled_u8","collision_kind_u8"]:
		if not _whole(globals[key],0,255):return false
	# The continuation compares kind with1; every other byte enters its second
	# arithmetic branch. Accepting those operand controls does not classify a hit.
	if not globals.previous_altitude_s64 is int:return false
	if not _whole(globals.player_object_index_u32,0,MASK) or int(globals.player_object_index_u32)!=int(body[0x86]):return false
	if globals.has("collider_parent_selected") and not globals.collider_parent_selected is bool:return false
	var relative:Variant=context.get("relative_position_s64")
	if not (relative is Array or relative is PackedInt64Array) or relative.size()!=3:return false
	for component:Variant in relative:
		if not component is int:return false
	if not _whole(context.get("distance_squared_s32"),-2147483648,2147483647):return false
	# F1538 resolves one descriptor per original model index. Conflicting
	# descriptors for an identical model would not describe a source lookup.
	if body.decode_u32(0x82)==parent.decode_u32(0x82) and context.body_descriptor!=context.parent_descriptor:return false
	return true

static func resolve_player(body:PackedByteArray,parent:PackedByteArray,context:Dictionary)->Dictionary:
	if not _valid(body,parent,context):return _reject(body,parent,"invalid_or_unsupported_player_context")
	var candidate:=body.duplicate();var globals:Dictionary=context.globals.duplicate(true)
	if not globals.has("collider_parent_selected"):globals.collider_parent_selected=false
	var relative:=PackedInt64Array(context.relative_position_s64);var kind:int=int(globals.collision_kind_u8)
	var descriptor:PackedByteArray=context.body_descriptor;var parent_descriptor:PackedByteArray=context.parent_descriptor
	var old_velocity:=_velocity(body);var old_l1:=_l1(old_velocity);var old_matrix:=_matrix(body)
	var normal:=_radial_normal(relative) if kind==1 else Ground._normalize_vector(PackedInt64Array([_s32(relative[0]),_s32(relative[1]),_s32(relative[2])]))
	var alignment:=_dot(PackedInt64Array([old_matrix[3],old_matrix[4],old_matrix[5]]),normal)
	var accepted:bool=old_l1<=0x258 and body.decode_u16(0x9e)==65535 and alignment>=0x78000000
	globals.collision_flags_u8=int(globals.collision_flags_u8)|2
	if accepted:
		globals.collision_flags_u8=(int(globals.collision_flags_u8)|0x40)&0x7f;globals.collision_active_u8=0
	else:globals.collision_active_u8=int(globals.collision_enabled_u8)
	# Both source F1538 descriptor lookups occur before position correction.
	var callbacks:Array=[{"function":"F1538","model_index_u32":int(body.decode_u32(0x82))},{"function":"F1538","model_index_u32":int(parent.decode_u32(0x82))}]
	if kind==1:
		var correction:=_s32(_sub64(body.decode_s64(0x140),int(globals.previous_altitude_s64)))
		for axis in range(3):candidate.encode_s64(0x3e+axis*8,_add64(body.decode_s64(0x3e+axis*8),_mul(correction,normal[axis])))
	else:
		var target:=_s32(int(parent_descriptor.decode_s32(0x2c))<<16)
		var parent_scale:=_s32(int(parent_descriptor.decode_s32(0x14))+int(parent_descriptor.decode_s32(0x18)))
		var body_scale:=_s32(int(descriptor.decode_s32(0x14))+int(descriptor.decode_s32(0x18)))
		var difference:=_s32(parent_scale-body_scale)
		var body_radius:=_s32(int(descriptor.decode_s32(0x30))<<16)
		if difference!=0:body_radius>>=difference&31
		target=_s32(target+body_radius)
		var squared:=int(context.distance_squared_s32)
		if target<0:target=(target&MASK)>>1;squared=_s32(squared+1)
		var projected:=_normalize_to(PackedInt64Array([_s32(relative[0]),_s32(relative[1]),_s32(relative[2])]),target,squared)
		var high_shift:=_s32(56-parent_scale);var low_shift:=_s32(32-high_shift)
		for axis in range(3):candidate.encode_s64(0x3e+axis*8,_s64(_s32(projected[axis]<<(low_shift&31)),projected[axis]>>(high_shift&31)))
	var damage_calls:Array=[];var velocity:=old_velocity.duplicate()
	if int(globals.collision_active_u8)!=0:
		globals.collision_flags_u8=int(globals.collision_flags_u8)|0x80
		_write_matrix(candidate,_align_up(old_matrix,normal))
		var normal_velocity:=_dot(normal,old_velocity);var projection:=PackedInt64Array()
		for axis in range(3):
			var projected:=_mul(normal[axis],normal_velocity)
			velocity[axis]=_s32(_div(_s32(old_velocity[axis]*2),3)-_div(_s32(projected*10),12))
			candidate.encode_s32(0x8c+axis*4,velocity[axis]);projection.append(velocity[axis])
		var forward:=PackedInt64Array([old_matrix[6],old_matrix[7],old_matrix[8]])
		if _dot(velocity,forward)<0:
			for axis in range(3):projection[axis]=_s32(-projection[axis])
		var lost_l1:=_s32(old_l1-_l1(velocity));var full_hull:=_s32(int(context.body_spec.decode_s16(6))<<2)
		var damage:=maxi(_div(_s32(full_hull*lost_l1),0x708),_div(full_hull,4))
		callbacks.append({"function":"F1538","model_index_u32":int(body.decode_u32(0x82))})
		damage_calls.append({"amount_s32":damage,"attacker_u32":0});callbacks.append({"function":"F953","amount_s32":damage,"attacker_u32":0})
		if projection==PackedInt64Array([0,0,0]):projection=forward
		var final_forward:=Ground._normalize_1503(projection);var final_matrix:=old_matrix.duplicate()
		for axis in range(3):final_matrix[6+axis]=final_forward[axis]
		_write_matrix(candidate,Ground._orthonormalize(final_matrix))
	else:
		_write_matrix(candidate,_align_up(old_matrix,normal))
		for axis in range(3):candidate.encode_s32(0x8c+axis*4,0);velocity[axis]=0
	# The original comparison deliberately considers only the low radius words.
	if parent.decode_u32(0x140)!=parent.decode_u32(0x138):globals.collision_flags_u8=int(globals.collision_flags_u8)|1
	if int(globals.collider_index_u8)==0:globals.collider_index_u8=int(parent[0x86]);globals.collider_parent_selected=true
	return {"ok":true,"error":"","body_after":candidate,"parent_after":parent.duplicate(),"globals_after":globals,"landing_accepted":accepted,"normal_q31":Array(normal),"l1_speed_s32":old_l1,"alignment_q31":alignment,"damage_calls":damage_calls,"callbacks":callbacks,"return_flags_u8":int(globals.collision_flags_u8),"source_contract":CONTRACT,"source_sha256":SOURCE_SHA,"scope":"postclassification player continuation only; no collision provider, F578 or executed F953 effects"}
