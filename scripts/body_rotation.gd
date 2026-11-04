extends RefCounted
# Pure F880 initialization / F866 spin branch, using the original Q31 matrix.
# The original clock epoch, parent transforms, orbital updates and animation
# effects are deliberately outside this primitive; it is not the live clock.
const Ground=preload("res://scripts/ground_coordinates.gd")
const U32_MASK:=0xffffffff

static func signed8(value:int)->int:
	var byte:=value&255
	return byte-256 if byte>=128 else byte

static func signed16(value:int)->int:
	var word:=value&65535
	return word-65536 if word>=32768 else word

static func matrix_yzt(first:int,second:int)->PackedInt64Array:
	# F1675 row-major storage, with every multiply/negation rounded as i32.
	var sine_first:=Ground.sin_q31(first)
	var cosine_first:=Ground.sin_q31(first+0x4000)
	var sine_second:=Ground.sin_q31(second)
	var cosine_second:=Ground.sin_q31(second+0x4000)
	return PackedInt64Array([
		Ground.multiply_q31(cosine_second,cosine_first),
		sine_first,
		Ground.signed32(-Ground.multiply_q31(cosine_first,sine_second)),
		Ground.signed32(-Ground.multiply_q31(cosine_second,sine_first)),
		cosine_first,
		Ground.multiply_q31(sine_second,sine_first),
		sine_second,
		0,
		cosine_second,
	])

static func initial_arguments(rotation_raw:int,tilt_u16:int,ticks_u32:int)->Vector2i:
	# x86 SHR masks the count to five bits, including signed-byte edge cases.
	var shift:=(17-signed8(rotation_raw))&31
	return Vector2i(signed16(tilt_u16),(ticks_u32&U32_MASK)>>shift)

static func initialize(rotation_raw:int,tilt_u16:int,ticks_u32:int)->PackedInt64Array:
	var arguments:=initial_arguments(rotation_raw,tilt_u16,ticks_u32)
	return matrix_yzt(arguments.x,arguments.y)

static func advance(previous_matrix:PackedInt64Array,rotation_raw:int,tilt_u16:int,flags_u8:int,old_tick_u32:int,new_tick_u32:int,_old_day_u32:int,new_day_u32:int)->Dictionary:
	var flags:=flags_u8&255
	var ground:bool=bool(flags&0x20)
	var station:bool=bool(flags&0x10)
	var result:Dictionary={
		"matrix":previous_matrix.duplicate(),
		"updated":false,
		"stored_tick_u32":new_tick_u32&U32_MASK,
		"stored_day_u32":new_day_u32&U32_MASK,
		"matrix_update_calls":0,
		"arguments":null,
		"animation_requested":ground or station,
		"orbital_phase_requested":not ground,
	}
	# F866 stores the timestamps before either early-return condition.
	if ground or (rotation_raw&255)==0:return result
	var previous_tick:=old_tick_u32&U32_MASK
	var current_tick:=new_tick_u32&U32_MASK
	var shift:=signed8(rotation_raw)-1
	if shift>=0:
		previous_tick=(previous_tick<<(shift&31))&U32_MASK
		current_tick=(current_tick<<(shift&31))&U32_MASK
	if previous_tick>>20==current_tick>>20:return result
	var phase:=current_tick>>16
	var tilt:=signed16(tilt_u16)
	var arguments:=Vector2i(phase,tilt) if station else Vector2i(tilt,phase)
	result.matrix=matrix_yzt(arguments.x,arguments.y)
	result.updated=true
	result.matrix_update_calls=1
	result.arguments=arguments
	return result
