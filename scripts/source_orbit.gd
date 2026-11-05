extends RefCounted
# Exact pinned JJFFE orbital primitives, not an SI/gravity/system backend.
# Phase values and vectors retain original word/register truncation.
const Math=preload("res://scripts/ffe_math.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
const MASK:=0xffffffff
const SOURCE_VARIANT:="jjffe-7e54034-q31-orbit"
const SOURCE_EPOCH_TICK:=0x80000000
const SOURCE_EPOCH_DAY:=0x121cf7

static func _u32(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=MASK and float(value)==floorf(float(value))

static func _pair(value:Variant)->bool:
	return (value is Array or value is PackedInt64Array) and value.size()==2 and _u32(value[0]) and _u32(value[1])

static func _s16(value:int)->int:return Math.s16(value)
static func _s32(value:int)->int:return Ground.signed32(value)
static func _words(value:int)->PackedInt64Array:return PackedInt64Array([value&MASK,(value>>32)&MASK])
static func signed64(words:Variant)->int:
	return (_s32(int(words[1]))<<32)|(int(words[0])&MASK)

static func _mul32(first:int,second:int)->PackedInt64Array:
	# Unsigned MUL without relying on a product above signed64's range.
	var a:=first&MASK;var b:=second&MASK
	var low:=(a&65535)*(b&65535)
	var middle:=(a>>16)*(b&65535)+(a&65535)*(b>>16)
	var carried:=low+((middle&65535)<<16)
	return PackedInt64Array([carried&MASK,((a>>16)*(b>>16)+(middle>>16)+(carried>>32))&MASK])

static func _add(first:Variant,second:Variant)->PackedInt64Array:
	var low:=int(first[0])+int(second[0])
	return PackedInt64Array([low&MASK,(int(first[1])+int(second[1])+(low>>32))&MASK])

static func add_positions(parent:PackedInt64Array,relative:PackedInt64Array)->PackedInt64Array:
	# F1661/F1677 ordinary parent chain: add raw vectors, modulo64 per axis.
	# Rotation for source ground ports is deliberately a separate operation.
	if parent.size()!=3 or relative.size()!=3:return PackedInt64Array()
	var result:=PackedInt64Array()
	for axis in range(3):result.append(signed64(_add(_words(parent[axis]),_words(relative[axis]))))
	return result

static func _multiply64(words:Variant,multiplier:int)->PackedInt64Array:
	var low:=_mul32(int(words[0]),multiplier)
	var high:=_mul32(int(words[1]),multiplier)
	return PackedInt64Array([low[0],(low[1]+high[0])&MASK])

static func shift_words(words:Variant,shift:Variant)->PackedInt64Array:
	if not _pair(words) or not (shift is int) or shift<(-0x80000000) or shift>0x7fffffff:return PackedInt64Array()
	var low:=int(words[0]);var high:=int(words[1]);var amount:=int(shift)
	if amount==0:return PackedInt64Array([low,high])
	if amount<0:
		# NEG is i32, including INT_MIN, before the signed comparison to32.
		amount=_s32(-amount)
		if amount<32:
			return PackedInt64Array([((low>>(amount&31))|((high<<((32-amount)&31))&MASK))&MASK,(_s32(high)>>(amount&31))&MASK])
		return PackedInt64Array([(_s32(high)>>((amount-32)&31))&MASK,MASK if _s32(high)<0 else 0])
	if amount<32:
		return PackedInt64Array([(low<<amount)&MASK,((high<<amount)|(low>>(32-amount)))&MASK])
	return PackedInt64Array([0,(low<<((amount-32)&31))&MASK])

static func normalize_packed(value:Variant)->Dictionary:
	if not _u32(value):return {}
	var mantissa:=int(value)&65535;var exponent:=(int(value)>>16)&65535
	if mantissa==0x8000:return {} # F1496 would loop after its16-bit shift becomes0.
	if mantissa!=0:
		while (mantissa&0x4000)==0:
			mantissa=(mantissa<<1)&65535;exponent=(exponent-1)&65535
	return {"packed":(exponent<<16)|mantissa}

static func packed_to_u32(value:Variant)->Dictionary:
	if not _u32(value):return {}
	var exponent:=_s16(int(value)>>16);var mantissa:=_s16(int(value))
	var result:=MASK
	if exponent<=15:result=(mantissa&MASK)>>((15-exponent)&31)
	elif exponent<=32:result=(mantissa<<((exponent-15)&31))&MASK
	return {"value":result}

static func rate(period:Variant)->Dictionary:
	if not _u32(period) or (int(period)&0x8000)!=0:return {}
	var normalized:=normalize_packed(period)
	if normalized.is_empty():return {}
	var packed:=Math.shift(Math.divide(0xffee5460,int(normalized.packed)),64)
	return {"rate_u32":int(packed_to_u32(packed).value),"normalized_period":int(normalized.packed),"rate_packed":packed}

static func phase_delta(rate_u32:Variant,old_tick:Variant,old_day:Variant,new_tick:Variant,new_day:Variant)->PackedInt64Array:
	for value in [rate_u32,old_tick,old_day,new_tick,new_day]:
		if not _u32(value):return PackedInt64Array()
	var low:=int(new_tick)-int(old_tick)
	var high:=(int(new_day)-int(old_day)-(1 if low<0 else 0))&MASK
	return shift_words(_multiply64(PackedInt64Array([low&MASK,high]),int(rate_u32)),3)

static func radial(inclination:int,phase:int)->PackedInt64Array:
	var sine:=Ground.sin_q31(phase)
	return PackedInt64Array([_s32(-Ground.multiply_q31(Ground.sin_q31(inclination+0x4000),sine)),Ground.multiply_q31(Ground.sin_q31(inclination),sine),Ground.sin_q31(phase+0x4000)])

static func interpolate(position_words:Array,increment_words:Variant,orbit_packed:Variant,delta:Variant)->Dictionary:
	if position_words.size()!=3 or not (increment_words is Array or increment_words is PackedInt64Array) or increment_words.size()!=3 or not _u32(orbit_packed) or not _u32(delta):return {}
	for words in position_words:
		if not _pair(words):return {}
	for value in increment_words:
		if not _u32(value):return {}
	var result:Array=[]
	var mantissa:=_s16(int(orbit_packed));var exponent:=_s16(int(orbit_packed)>>16)
	for axis in range(3):
		var increment:=_s32(int(increment_words[axis]))
		var first:=_s32(mantissa*(int(delta)>>16))
		var second:=_s32(mantissa*(int(delta)&65535))
		var high_part:=shift_words(_words(increment*first),exponent-50)
		var low_part:=shift_words(_words(increment*second),exponent-66)
		result.append(_add(_add(position_words[axis],high_part),low_part))
	return {"position_words":result,"position_raw":PackedInt64Array([signed64(result[0]),signed64(result[1]),signed64(result[2])])}

static func position(orbit_packed:Variant,inclination:Variant,phase_hi:Variant)->Dictionary:
	if not _u32(orbit_packed) or not _u32(phase_hi) or not (inclination is int or inclination is float) or not is_finite(float(inclination)) or float(inclination)!=floorf(float(inclination)) or inclination<(-32768) or inclination>65535:return {}
	var angle:=(_s32(int(phase_hi))>>16)&(-16)
	var first:=radial(_s16(int(inclination)),angle)
	var second:=radial(_s16(int(inclination)),_s32(angle+16))
	var increments:=PackedInt64Array();var base:Array=[]
	for axis in range(3):
		increments.append((second[axis]-first[axis])&MASK)
		base.append(shift_words(_words(_s16(int(orbit_packed))*first[axis]),_s16(int(orbit_packed)>>16)-46))
	var result:=interpolate(base,increments,int(orbit_packed),int(phase_hi)&0xfffff)
	result.increment_words=increments;result.base_position_words=base;result.coarse_angle=angle
	return result

static func initialize(record:PackedByteArray,tick_u32:Variant,day_u32:Variant)->Dictionary:
	# Literal F880 initializer. Its F1510 argument order swaps the two NEW
	# clock words; a8/ac still store the ordinary tick/day pair. F866 updates
	# use the ordinary ordering. Reinitializing at every frame is not F866.
	if record.size()!=68 or record.decode_u16(10)==35 or not _u32(tick_u32) or not _u32(day_u32):return {}
	var timing:=rate(int(record.decode_u32(20)))
	if timing.is_empty():return {}
	var phase:=phase_delta(int(timing.rate_u32),0,0,day_u32,tick_u32)
	phase[1]=(phase[1]+(int(record.decode_u16(18))<<16))&MASK
	var result:=position(int(record.decode_u32(14)),int(record.decode_u16(34)),phase[1])
	result.rate_u32=timing.rate_u32;result.phase_words=phase;result.source_variant=SOURCE_VARIANT
	result.orbit_packed=int(record.decode_u32(14));result.inclination_s16=_s16(int(record.decode_u16(34)))
	result.clock_tick_u32=int(tick_u32);result.clock_day_u32=int(day_u32)
	result.anchor_tick_u32=int(tick_u32);result.anchor_day_u32=int(day_u32)
	result.clock_policy="f880-initializer"
	return result

static func advance(state:Dictionary,tick_u32:Variant,day_u32:Variant)->Dictionary:
	# Only ordinary-orbit F866 phase/position. Object flags, surface spin,
	# orientation, ports, allocation and all other physics are outside scope.
	if not _u32(tick_u32) or not _u32(day_u32):return {}
	for key in ["source_variant","clock_tick_u32","clock_day_u32","rate_u32","phase_words","orbit_packed","inclination_s16","position_words","position_raw","increment_words"]:
		if not state.has(key):return {}
	if state.source_variant!=SOURCE_VARIANT or not _pair(state.phase_words):return {}
	for value in [state.clock_tick_u32,state.clock_day_u32,state.rate_u32,state.orbit_packed]:
		if not _u32(value):return {}
	if not state.position_words is Array or state.position_words.size()!=3 or not state.position_raw is PackedInt64Array or state.position_raw.size()!=3 or not (state.increment_words is PackedInt64Array or state.increment_words is Array) or state.increment_words.size()!=3:return {}
	for axis in range(3):
		if not _pair(state.position_words[axis]) or not _u32(state.increment_words[axis]) or signed64(state.position_words[axis])!=state.position_raw[axis]:return {}
	var phase:=_add(state.phase_words,phase_delta(state.rate_u32,state.clock_tick_u32,state.clock_day_u32,tick_u32,day_u32))
	var current:=position(state.orbit_packed,state.inclination_s16,phase[1])
	if current.is_empty():return {}
	var result:=state.duplicate(true)
	# Pinned JJFFE's drift fix always selects F1507 on a changed high word.
	# When the word is unchanged the source leaves the position untouched.
	if phase[1]!=int(state.phase_words[1]):
		for key in current:result[key]=current[key]
	result.phase_words=phase;result.clock_tick_u32=int(tick_u32);result.clock_day_u32=int(day_u32)
	result.clock_policy="f880-anchor-plus-f866"
	return result

static func evaluate_from_epoch(record:PackedByteArray,tick_u32:Variant,day_u32:Variant,epoch_tick_u32:Variant=SOURCE_EPOCH_TICK,epoch_day_u32:Variant=SOURCE_EPOCH_DAY)->Dictionary:
	# Reconstruct a persistent source orbit without making system entry time
	# or render frame partition change the initializer's phase offset.
	var initial:=initialize(record,epoch_tick_u32,epoch_day_u32)
	if initial.is_empty():return {}
	return advance(initial,tick_u32,day_u32)

static func evaluate(record:PackedByteArray,tick_u32:Variant,day_u32:Variant)->Dictionary:
	# Compatibility helper: explicitly fixed zero epoch, not F880-at-now.
	return evaluate_from_epoch(record,tick_u32,day_u32,0,0)
