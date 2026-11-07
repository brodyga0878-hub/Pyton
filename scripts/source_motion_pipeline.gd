extends RefCounted
# Original fixed-frame linear-motion core. Full F585/F606/reference-frame
# selection, collisions, atmosphere, fuel and global player event scheduling
# remain outside this module; no claim of a complete FFE flight integrator.
const Gravity=preload("res://scripts/source_gravity.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
const Units=preload("res://scripts/source_units.gd")
const PROFILE:="source-fixed-frame-linear-motion-v1"
const SCHEMA:="starfrontier-source-motion-state-v1"
const OBJECT_BYTES:=338
const MASK:=0xffffffff
const VELOCITY_UNIT_MPS:=16785.0/172800.0
const NOMINAL_TICKS_PER_SECOND:=4294967296.0/86400.0
var _body:=PackedByteArray()
var _parent:=PackedByteArray()

static func _s32(value:int)->int:return Ground.signed32(value)
static func _whole(value:Variant,low:int,high:int)->bool:
	return (typeof(value)==TYPE_INT or typeof(value)==TYPE_FLOAT) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=low and value<=high
static func _vector(value:Variant)->bool:
	if not (value is Array or value is PackedInt64Array) or value.size()!=3:return false
	for component in value:
		if not _whole(component,-0x80000000,0x7fffffff):return false
	return true
static func _mul_q31(a:int,b:int)->int:return _s32((_s32(a)*_s32(b))>>31)
static func _ratio(a:int,b:int)->int:
	var first:=a&MASK;var second:=b&MASK
	if (first>>1)>=second:return -1
	return _s32((first<<31)/second)
static func _f1515(first:int,second:int)->int:
	var a:=first&MASK;var b:=_s32(second)
	var low:=(_s32((a&65535)*b)&MASK)>>16
	return _s32(low+_s32((a>>16)*b))
static func _f1516(first:int,second:int)->int:
	var b:=_s32(second)
	if b<0:return _s32(-_s32(_f1515(first,_s32(-b))<<1))
	return _s32(_f1515(first,b)<<1)
static func _read_vector(body:PackedByteArray,offset:int)->PackedInt64Array:
	return PackedInt64Array([body.decode_s32(offset),body.decode_s32(offset+4),body.decode_s32(offset+8)])

static func set_thrust(body:PackedByteArray,command:Variant,mode:String="limited")->Dictionary:
	if body.size()!=OBJECT_BYTES or not _vector(command) or mode not in ["limited","maximum","direction"]:return {}
	var candidate:=body.duplicate();var result:=PackedInt64Array([int(command[0]),int(command[1]),int(command[2])])
	var factor:=0x7fffffff
	if mode=="maximum":
		result[0]=32767 if int(command[0])>=0 else -32767
		result[1]=32767 if int(command[1])>=0 else -32767
		result[2]=_s32(int(command[2])<<3)
	for axis in range(3):
		var upper:=int(body.decode_s16(0xbc+axis*4));var lower:=int(body.decode_s16(0xbe+axis*4))
		if mode=="direction":
			# F600 overwrites the ratio for each constrained axis in source order.
			# Do not replace this with an invented minimum/common-scale policy.
			if upper<int(command[axis]):factor=_ratio(upper,int(command[axis]))
			if lower>int(command[axis]):factor=_ratio(_s32(-lower),_s32(-int(command[axis])))
		elif mode=="limited":
			if upper<int(command[axis]):result[axis]=upper
			if lower>int(command[axis]):result[axis]=lower
		else:
			if upper<result[axis]:result[axis]=upper
			if lower>result[axis]:result[axis]=lower
	if mode=="direction":
		for axis in range(3):result[axis]=_mul_q31(factor,int(command[axis]))
	for axis in range(3):candidate.encode_u16(0xb6+axis*2,int(result[axis])&65535)
	return {"body":candidate,"command_s32":result,"profile":PROFILE}

static func desired_acceleration(body:PackedByteArray,set_speed:Variant)->Dictionary:
	if body.size()!=OBJECT_BYTES or not _whole(set_speed,-0x80000000,0x7fffffff):return {}
	var candidate:=body.duplicate();var speed:=int(set_speed)
	var quotient:=int(absi(speed)/100);quotient=-quotient if speed<0 else quotient
	speed=_s32(speed+quotient)
	var delta:=PackedInt64Array();var local:=PackedInt64Array()
	for axis in range(3):
		var component:=int(body.decode_s32(0x18+axis*4))>>16
		var target:=_f1516(_s32(-speed),component) if speed<0 else _f1516(speed,component)
		if speed<0:target=_s32(-target)
		delta.append(_s32(target-int(body.decode_s32(0x8c+axis*4))))
		candidate.encode_s32(0xf2+axis*4,delta[axis])
	for axis in range(3):
		var sum:=0
		for world_axis in range(3):sum=_s32(sum+_mul_q31(int(delta[world_axis]),int(body.decode_s32(axis*12+world_axis*4))))
		local.append(_s32(sum<<2))
	return {"body":candidate,"command_s32":local,"remaining_velocity_s32":delta,"profile":PROFILE}

static func velocity_step(body:PackedByteArray,ticks:Variant,capped:=true)->Dictionary:
	if body.size()!=OBJECT_BYTES or not _whole(ticks,0,MASK):return {}
	# These entries differ before the common multiply: F601 uses SHR and
	# starts the large-step exponent at16; F602 uses SAR and starts at15.
	var candidate:=body.duplicate();var factor:=(int(ticks)>>3) if capped else (_s32(int(ticks))>>3);var shift:=-1
	if factor>32767:
		shift=16 if capped else 15
		while factor>32767:factor>>=1;shift-=1
	var impulse:=PackedInt64Array([0,0,0])
	for local_axis in range(3):
		var thrust:=int(body.decode_s16(0xb6+local_axis*2))
		if thrust==0:continue
		for axis in range(3):
			var basis_high:=int(body.decode_s32(local_axis*12+axis*4))>>16
			var term:=_s32((_s32(basis_high*factor)>>15)*thrust)
			impulse[axis]=_s32(impulse[axis]+term)
	for axis in range(3):
		impulse[axis]=_s32(impulse[axis]<<1)
		var increment:int
		if shift<0:
			var combined:=_s32(int(body.decode_u16(0xec+axis*2))+impulse[axis])
			candidate.encode_u16(0xec+axis*2,combined&65535);increment=combined>>16
		else:increment=int(impulse[axis])>>(shift&31)
		if capped and (shift>=0 or factor>=0x4014):
			var residual:=int(body.decode_s32(0xf2+axis*4))
			if residual>=0:increment=maxi(0,mini(increment,residual))
			else:increment=mini(0,maxi(increment,residual))
		candidate.encode_s32(0x8c+axis*4,_s32(int(body.decode_s32(0x8c+axis*4))+increment))
	return {"body":candidate,"velocity_s32":_read_vector(candidate,0x8c),"fraction_u16":PackedInt64Array([candidate.decode_u16(0xec),candidate.decode_u16(0xee),candidate.decode_u16(0xf0)]),"impulse_s32":impulse,"time_factor":factor,"time_shift":shift,"profile":PROFILE}

static func manual_step(body:PackedByteArray,parent:PackedByteArray,ticks:Variant,set_speed:Variant,command:Variant=[0,0,0],engines_off:=false,day_words:Variant=0)->Dictionary:
	if body.size()!=OBJECT_BYTES or parent.size()!=OBJECT_BYTES or not _whole(ticks,0,0x7fffffff) or not _whole(day_words,0,MASK) or not _whole(set_speed,-0x80000000,0x7fffffff) or not _vector(command):return {}
	var gravity:=Gravity.update(body,parent,int(ticks))
	if gravity.is_empty():return {}
	var candidate:PackedByteArray=gravity.body
	var desired:=set_thrust(candidate,command) if engines_off else desired_acceleration(candidate,int(set_speed))
	if desired.is_empty():return {}
	if not engines_off:desired=set_thrust(desired.body,desired.command_s32)
	var kicked:=velocity_step(desired.body,int(ticks),not engines_off)
	if kicked.is_empty():return {}
	var drift:=Gravity.integrate(kicked.body,PackedInt64Array([int(ticks),int(day_words)]))
	if drift.is_empty():return {}
	return {"body":drift.body,"profile":PROFILE,"source_order":["F603","F599" if engines_off else "F607/F599","F602" if engines_off else "F601","F1512"],"gravity_trace":gravity.trace,"command_s32":desired.command_s32,"velocity_s32":kicked.velocity_s32,"fraction_u16":kicked.fraction_u16,"position_raw":drift.position_raw,"fixed_parent_and_attitude":true,"complete_original_player_pipeline":false}

static func decode_si(body:PackedByteArray)->Dictionary:
	if body.size()!=OBJECT_BYTES:return {}
	var position:Array=[];var velocity:Array=[]
	for axis in range(3):
		position.append(float(body.decode_s64(0x3e+axis*8))*Units.METRES_PER_RAW)
		velocity.append((float(body.decode_s32(0x8c+axis*4))+float(body.decode_u16(0xec+axis*2))/65536.0)*VELOCITY_UNIT_MPS)
	return {"position_metres":position,"velocity_mps":velocity,"axes":"unaltered_source_world_axes","profile":PROFILE,"ticks_per_second":NOMINAL_TICKS_PER_SECOND}

func configure(body:PackedByteArray,parent:PackedByteArray)->bool:
	if body.size()!=OBJECT_BYTES or parent.size()!=OBJECT_BYTES:return false
	_body=body.duplicate();_parent=parent.duplicate();return true
func raw_body()->PackedByteArray:return _body.duplicate()
func advance(ticks:Variant,set_speed:Variant,command:Variant=[0,0,0],engines_off:=false,day_words:Variant=0)->Dictionary:
	var result:=manual_step(_body,_parent,ticks,set_speed,command,engines_off,day_words)
	if result.is_empty():return {}
	_body=result.body.duplicate();return result
func snapshot()->Dictionary:
	if _body.size()!=OBJECT_BYTES:return {}
	return {"schema":SCHEMA,"version":1,"profile":PROFILE,"body_hex":_body.hex_encode(),"parent_hex":_parent.hex_encode()}
func restore(data:Variant)->bool:
	if not data is Dictionary or data.size()!=5 or data.get("schema")!=SCHEMA or not _whole(data.get("version"),1,1) or data.get("profile")!=PROFILE:return false
	for key in ["body_hex","parent_hex"]:
		if not data.get(key) is String or data[key].length()!=OBJECT_BYTES*2:return false
		for character:String in data[key]:
			if not character in "0123456789abcdef":return false
	return configure(str(data.body_hex).hex_decode(),str(data.parent_hex).hex_decode())
