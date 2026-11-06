extends RefCounted
# Source body-frame port positions: F874 -> F1674 row 1 -> F879/F880.
# Parent spin, orbital motion and the original terrain remain separate work.
static var sine_quarter:Array=[]
static var _sine_mutex:=Mutex.new()

static func signed32(value:int)->int:
	var low:=value&0xffffffff
	return low-0x100000000 if low>=0x80000000 else low

static func constructor_angles(first:int,second:int)->Vector2i:
	# F874 uses unsigned 32-bit division after shifting, including negative args.
	var phase:int=((first<<16)&0xffffffff)/36000
	var inclination:int=((second<<16)&0xffffffff)/36000
	return Vector2i((-phase-0x4000)&65535,inclination&65535)

static func fields(phase:int,inclination:int,representation:String)->Dictionary:
	return {"ground_phase_u16":phase&65535,"ground_inclination_u16":inclination&65535,"ground_coordinate_source":representation}

static func from_constructor(first:int,second:int)->Dictionary:
	var angles:=constructor_angles(first,second)
	return fields(angles.x,angles.y,"ffe_f874_arguments")

static func from_record(phase:int,inclination:int)->Dictionary:
	return fields(phase,inclination,"ffe_packed_record")

static func sin_q31(angle:int)->int:
	_sine_mutex.lock()
	if sine_quarter.is_empty():
		sine_quarter=JSON.parse_string(FileAccess.get_file_as_string("res://data/ffe_ground_coordinates.json")).sin_quarter_q31
	var index:=angle&0x3fff
	var quadrant:=(angle>>14)&3
	# Original Sin32 mirrors at 16383, not the ideal quarter-turn endpoint.
	if quadrant&1:index=0x3fff-index
	var value:=int(sine_quarter[index])
	_sine_mutex.unlock()
	return -value if quadrant>=2 else value

static func multiply_q31(first:int,second:int)->int:
	return signed32((signed32(first)*signed32(second))>>31)

static func native_radial(phase:int,inclination:int)->PackedInt64Array:
	var sine_phase:=sin_q31(phase)
	var cosine_phase:=sin_q31(phase+0x4000)
	var sine_inclination:=sin_q31(inclination)
	var cosine_inclination:=sin_q31(inclination+0x4000)
	return PackedInt64Array([multiply_q31(cosine_inclination,cosine_phase),sine_inclination,signed32(-multiply_q31(cosine_inclination,sine_phase))])

static func coordinates(site:Dictionary)->Array:
	if int(site.get("type_code",-1))!=35:return []
	if not site.has("ground_phase_u16") or not site.has("ground_inclination_u16"):return []
	var radial:=native_radial(int(site.ground_phase_u16),int(site.ground_inclination_u16))
	var x:=float(radial[0]);var y:=float(radial[1]);var z:=float(radial[2])
	return [atan2(y,sqrt(x*x+z*z)),atan2(-z,x)]
