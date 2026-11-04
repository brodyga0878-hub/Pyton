extends RefCounted
# Verified original integer primitives, not the complete FFE terrain generator.
# F1824 hashes a uint32, F1846 supplies signed midpoint displacement. Source
# subdivision, terrain configuration and height queries remain separate work.
const Ground=preload("res://scripts/ground_coordinates.gd")
const MASK:=0xffffffff

static func rotate_left32(value:int,count:int)->int:
	var low:=value&MASK
	var shift:=count&31
	if shift==0:return low
	return ((low<<shift)|(low>>(32-shift)))&MASK

static func hash32(value:int)->int:
	# Both additions overflow at 32 bits. SHR reads unsigned words; the return
	# keeps the signed EAX interpretation needed by following SAR instructions.
	var low:=value&MASK
	var mixed:=(rotate_left32(low,5)+low)&MASK
	return Ground.signed32(low+rotate_left32(mixed,16))

static func mul_q31(first:int,second:int)->int:
	return Ground.multiply_q31(first,second)

static func jitter(first:int,second:int,depth:int)->int:
	var mixed:=hash32((first&MASK)^(second&MASK))
	if Ground.signed32(depth)<=1:return mixed>>4
	var difference:=Ground.signed32(first-second)
	# NEG INT32_MIN wraps to itself, rather than becoming a positive int64.
	if difference<0:difference=Ground.signed32(-difference)
	return mul_q31(mixed,difference)>>1
