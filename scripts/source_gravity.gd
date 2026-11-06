extends RefCounted
# Pinned source F603 velocity kick and F1511/F1512 drift. Raw source units.
# This module does not select reference frames or provide an SI flight backend.
const Math=preload("res://scripts/ffe_math.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
const Orbit=preload("res://scripts/source_orbit.gd")
const SOURCE_VARIANT:="jjffe-7e54034-gravity"
const OBJECT_BYTES:=338
const MASK:=0xffffffff

static func _s32(value:int)->int:return Ground.signed32(value)
static func _s16(value:int)->int:return Math.s16(value)
static func _u32(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=MASK and float(value)==floorf(float(value))
static func _i32(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=(-0x80000000) and value<=0x7fffffff and float(value)==floorf(float(value))
static func _words(value:int)->PackedInt64Array:return PackedInt64Array([value&MASK,(value>>32)&MASK])
static func _packed(mantissa:int,exponent:int)->int:return ((exponent&65535)<<16)|(mantissa&65535)

static func _normalize(value:int)->Dictionary:
	# Original F1496 has no exit for mantissa0x8000. Reject that input before
	# entering its word-shift loop; physical positive distances do not use it.
	var mantissa:=value&65535;var exponent:=(value>>16)&65535
	if mantissa==0x8000:return {}
	while mantissa!=0 and (mantissa&0x4000)==0:
		mantissa=(mantissa<<1)&65535;exponent=(exponent-1)&65535
	return {"packed":_packed(mantissa,exponent)}

static func _msb(value:int)->int:
	# F1656 and the bit-search tail of F1657 return0 for both0 and1.
	var word:=value&MASK;var bit:=0
	while word>1:word>>=1;bit+=1
	return bit

static func _vec64_msb(position:PackedInt64Array)->int:
	# F1657 examines sign-extension words, then the absolute high OR low
	# DWORDs. Its negations intentionally do not propagate a low-word carry.
	var high:=PackedInt64Array()
	for coordinate in position:high.append((coordinate>>32)&MASK)
	var large:=false
	for word in high:
		if word!=0 and word!=MASK:large=true
	var combined:=0
	for axis in range(3):
		var part:=high[axis] if large else (position[axis]&MASK)
		if _s32(high[axis])<0:part=(-part)&MASK
		combined|=part
	return (32 if large else 0)+_msb(combined)

static func _truncate(position:PackedInt64Array)->Dictionary:
	var shift:=maxi(0,_vec64_msb(position)-13)
	var small:=PackedInt64Array()
	for coordinate in position:
		var words:=Orbit.shift_words(_words(coordinate),-shift)
		small.append(_s32(words[0]))
	return {"vector":small,"shift":shift}

static func _sqrt_q31(value:int)->int:
	# Actual F1502 bit loop. This is not the LUT-backed F1467 and is not
	# interchangeable with integer_sqrt() or a floating square root.
	var number:=value&MASK;var stage:=0;var probe:=0x80000000
	while probe>number:stage+=1;probe>>=2
	var result:=0;var accepted:=0
	while stage<=15:
		var candidate:=((result>>((stage-1)&31))+accepted+(0x80000000>>((stage*2)&31)))&MASK
		if candidate<=number:
			accepted=candidate;result=(result+(0x80000000>>(stage&31)))&MASK
		stage+=1
	while stage<=31:
		var candidate:=((result>>((stage-1)&31))+accepted)&MASK
		if candidate<=number:
			accepted=candidate;result=(result+(0x80000000>>(stage&31)))&MASK
		stage+=1
	return result

static func _length32(vector:PackedInt64Array)->int:
	# F1466 protects its norm against falling below any absolute component.
	var absolute:=PackedInt64Array();var combined:=0
	for coordinate in vector:
		var value:=((-coordinate) if coordinate<0 else coordinate)&MASK
		absolute.append(value);combined|=value
	var shift:=30-_msb(combined);var squared:=0
	for value in absolute:
		var scaled:=_s32((value<<(shift&31))&MASK)
		squared=_s32(squared+(Ground.multiply_q31(scaled,scaled)>>2))
	var result:=_sqrt_q31(squared)
	result=result>>((shift-1)&31) if shift>0 else (result*2)&MASK
	for coordinate in absolute:result=maxi(result,coordinate)
	return result

static func coefficient(record:PackedByteArray)->Dictionary:
	if record.size()!=68:return {}
	var normalized:=_normalize(Math.multiply(int(record.decode_u32(0)),0xffd54082))
	if normalized.is_empty():return {}
	return {"a4_u32":int(normalized.packed),"source_variant":SOURCE_VARIANT}

static func _result(body:PackedByteArray,scratch:PackedInt64Array,trace:Dictionary)->Dictionary:
	var velocity:=PackedInt64Array();var fraction:=PackedInt64Array()
	for axis in range(3):
		velocity.append(_s32(body.decode_u32(0x8c+axis*4)))
		fraction.append(int(body.decode_u16(0xec+axis*2)))
	return {"body":body,"velocity_s32":velocity,"fraction_u16":fraction,"scratch_s32":scratch,"trace":trace,"source_variant":SOURCE_VARIANT}

static func update(body:PackedByteArray,parent:PackedByteArray,step_s32:Variant,initial_scratch_s32:Variant=null)->Dictionary:
	if body.size()!=OBJECT_BYTES or parent.size()!=OBJECT_BYTES or not _i32(step_s32):return {}
	var scratch:=PackedInt64Array([0,0,0])
	if initial_scratch_s32!=null:
		if not (initial_scratch_s32 is Array or initial_scratch_s32 is PackedInt64Array) or initial_scratch_s32.size()!=3:return {}
		for value in initial_scratch_s32:
			if not _i32(value):return {}
		for axis in range(3):scratch[axis]=int(initial_scratch_s32[axis])
	var candidate:=body.duplicate();var trace:={"reason":"no_parent","scratch_written":false,"velocity_written":false}
	if body[0x56]==0:return _result(candidate,scratch,trace)
	trace.reason="zero_parent_mass"
	if parent.decode_u16(0xa4)==0:return _result(candidate,scratch,trace)
	var position:=PackedInt64Array()
	for axis in range(3):position.append(body.decode_s64(0x3e+axis*8))
	var truncated:=_truncate(position)
	scratch=truncated.vector.duplicate();trace.scratch_written=true;trace["truncate_shift"]=truncated.shift
	var norm:=_length32(scratch);trace["norm_u32"]=norm
	var distance:=_normalize(_packed(norm,int(truncated.shift)))
	if distance.is_empty():return {}
	trace["distance_packed"]=distance.packed;trace.reason="zero_distance"
	if (int(distance.packed)&65535)==0:return _result(candidate,scratch,trace)
	var squared:=Math.multiply(int(distance.packed),int(distance.packed))
	trace["square_packed"]=squared
	# The source copies the SQUARE exponent here, deliberately omitting the
	# third distance exponent: its coordinate vector was already truncated.
	var cube:=_normalize(_packed((_s16(int(distance.packed))*_s16(squared))>>15,squared>>16))
	if cube.is_empty():return {}
	trace["cube_like_packed"]=int(cube.packed)
	var factor:=Math.divide(int(parent.decode_u32(0xa4)),int(cube.packed))
	var exponent:=_s16(factor>>16);var step:=int(step_s32)
	while step>32767 or step<(-32767):step>>=1;exponent=_s16(exponent+1)
	var impulse:=_s32(-(_s32(_s16(factor)*step)>>15))
	trace["factor_s32"]=impulse
	var delta:=PackedInt64Array()
	for coordinate in scratch:delta.append(_s32(impulse*coordinate))
	trace["factor_packed"]=factor;trace["step_mantissa"]=step;trace["delta_exponent"]=exponent;trace.reason="fractional_underflow"
	if exponent<=(-32):return _result(candidate,scratch,trace)
	if exponent<=0:
		if exponent<0:
			for axis in range(3):delta[axis]>>=(-exponent)&31
		for axis in range(3):
			var combined:=_s32(int(candidate.decode_u16(0xec+axis*2))+delta[axis])
			candidate.encode_u16(0xec+axis*2,combined&65535)
			candidate.encode_u32(0x8c+axis*4,(_s32(candidate.decode_u32(0x8c+axis*4))+(combined>>16))&MASK)
		trace.reason="fractional_velocity"
	else:
		exponent=_s16(exponent-16)
		if exponent<0:
			for axis in range(3):delta[axis]>>=(-exponent)&31
		for axis in range(3):candidate.encode_u32(0x8c+axis*4,(_s32(candidate.decode_u32(0x8c+axis*4))+delta[axis])&MASK)
		trace.reason="integer_velocity"
	trace.velocity_written=true
	return _result(candidate,scratch,trace)

static func _manual_left(words:PackedInt64Array,amount:int)->PackedInt64Array:
	# F1511 uses two SHL/SHR instructions without a >=32 branch; preserve its
	# x86-masked counts even for synthetic full-width timestep controls.
	return PackedInt64Array([(words[0]<<(amount&31))&MASK,((words[1]<<(amount&31))|(words[0]>>((32-amount)&31)))&MASK])

static func integrate(body:PackedByteArray,step_words:Variant)->Dictionary:
	if body.size()!=OBJECT_BYTES or not (step_words is Array or step_words is PackedInt64Array) or step_words.size()!=2:return {}
	for word in step_words:
		if not _u32(word):return {}
	var low:=int(step_words[0]);var high:=int(step_words[1]);var negative:=_s32(high)<0
	if negative:
		low=(-low)&MASK;high=((~high)+(1 if low==0 else 0))&MASK
	low=((low>>7)|(high<<25))&MASK;high>>=7
	var shift:=0
	if high!=0:
		shift=_msb(high)+1;low=((low>>(shift&31))|(high<<((32-shift)&31)))&MASK
	var extra:=maxi(0,_msb(low)-14);shift+=extra;low>>=extra&31
	var displacement:=PackedInt64Array();var position:=PackedInt64Array()
	for axis in range(3):
		var value:=_s32(body.decode_u32(0x8c+axis*4))*low
		var words:=_words(value>>2)
		if shift!=0:words=_manual_left(words,shift)
		if negative:
			words[0]=(-words[0])&MASK;words[1]=((~words[1])+(1 if words[0]==0 else 0))&MASK
		displacement.append(Orbit.signed64(words));position.append(body.decode_s64(0x3e+axis*8))
	var advanced:=Orbit.add_positions(position,displacement);var candidate:=body.duplicate();var pairs:Array=[]
	for axis in range(3):candidate.encode_s64(0x3e+axis*8,advanced[axis]);pairs.append(_words(advanced[axis]))
	return {"body":candidate,"position_words":pairs,"position_raw":advanced,"source_variant":SOURCE_VARIANT}
