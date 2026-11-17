extends RefCounted
# Original DOS F584/F585/F609/F611 angular commands and matrix rotation.
# Raw338-byte state stays authoritative; no quaternion round-trip is used.
const Ground=preload("res://scripts/source_ground_surface.gd")
const PROFILE:="dos-firstenc-angular-motion-v1"
const SOURCE_EXE_SHA256:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const OBJECT_BYTES:=338
const MASK:=0xffffffff
const STEPS:=[2555,1297,651,326,163,82,41,20]
const DECREMENTS:=[18,3,3,3,5,2,1,1]

static func _s32(value:int)->int:return (value&0x7fffffff)-(value&0x80000000)
static func _s16(value:int)->int:return (value&0x7fff)-(value&0x8000)
static func _whole(value:Variant,minimum:int,maximum:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=minimum and float(value)<=maximum and float(value)==floorf(float(value))
static func _body(value:Variant)->bool:return value is PackedByteArray and value.size()==OBJECT_BYTES
static func _globals(value:Variant)->bool:
	return value is Dictionary and value.size()==2 and _whole(value.get("player_index_u32"),0,MASK) and _whole(value.get("player_roll_s16"),-32768,32767)
static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"source_profile":PROFILE,"raw_owner_mutated":false}
static func _quantize(value:int)->Dictionary:
	for index in range(7):
		if value>=STEPS[index]:return {"amount_s32":STEPS[index],"shift_s32":index+2}
	return {"amount_s32":20,"shift_s32":9}

static func quantize_raw(value:Variant)->Dictionary:
	if not _whole(value,-0x80000000,0x7fffffff):return _reject("invalid_signed_angle")
	var result:=_quantize(int(value));result["ok"]=true;result["source_profile"]=PROFILE
	return result

static func _matrix(body:PackedByteArray)->PackedInt64Array:
	var values:=PackedInt64Array()
	for index in range(9):values.append(body.decode_s32(index*4))
	return values
static func _write_matrix(body:PackedByteArray,values:PackedInt64Array)->void:
	for index in range(9):body.encode_u32(index*4,values[index]&MASK)
static func _normalize(body:PackedByteArray)->void:_write_matrix(body,Ground._orthonormalize(_matrix(body)))

static func _pair(body:PackedByteArray,first:int,second:int,positive:bool,shift:int)->bool:
	# F611 attenuates both rows before applying its paired small-angle shear.
	if shift<=5:
		var attenuation:=(shift*2+1)&31
		for axis in range(3):
			for start in [first,second]:
				var value:=body.decode_s32(start+axis*4)
				body.encode_u32(start+axis*4,_s32(value-(value>>attenuation))&MASK)
	var updated_second:=PackedInt64Array();var old_second_shift:=PackedInt64Array()
	for axis in range(3):
		var a:=body.decode_s32(first+axis*4);var b:=body.decode_s32(second+axis*4)
		updated_second.append(_s32(b+(a>>shift)) if positive else _s32(b-(a>>shift)))
		old_second_shift.append(b>>shift)
	for axis in range(3):body.encode_u32(second+axis*4,updated_second[axis]&MASK)
	for axis in range(3):
		var value:=body.decode_s32(first+axis*4)
		body.encode_u32(first+axis*4,(_s32(value-old_second_shift[axis]) if positive else _s32(value+old_second_shift[axis]))&MASK)
	body[0x24]=(int(body[0x24])-DECREMENTS[shift-2])&0xff
	if body[0x24]>=128:
		_normalize(body);body[0x24]=60;return true
	return false

static func step_raw(body:Variant,budget:Variant,accumulate:Variant,elapsed_ticks:Variant,globals:Variant)->Dictionary:
	if not _body(body):return _reject("invalid_raw_body")
	if not _whole(budget,-0x80000000,0x7fffffff) or not _whole(elapsed_ticks,-0x80000000,0x7fffffff) or not accumulate is bool or not _globals(globals):return _reject("invalid_angular_context")
	var result:PackedByteArray=body.duplicate();var state:Dictionary=globals.duplicate(true)
	var limit:=int(budget);var model:=result.decode_u32(0x82)
	if model>=0x35:limit>>=1
	if model>=0x3b:limit>>=1
	if accumulate:
		var ticks:=mini(int(elapsed_ticks),0x7fff)
		for axis in range(3):
			var product:=_s32(result.decode_s16(0x110+axis*2)*ticks)
			result.encode_u16(0xb0+axis*2,(_s16(result.decode_s16(0xb0+axis*2)+(product>>16)))&0xffff)
	limit=mini(limit,0x7fff)
	var applied:Array=[];var normalized:=0
	var first_rows:=[24,12,0];var second_rows:=[12,0,24]
	for axis in range(3):
		var residual:=result.decode_s16(0xb0+axis*2);var positive:=residual>=0
		var amount:=mini(limit,absi(residual))
		if amount<15:continue
		var quantized:=_quantize(amount);var consumed:=int(quantized.amount_s32)
		result.encode_u16(0xb0+axis*2,(_s16(residual-consumed if positive else residual+consumed))&0xffff)
		var renormalized:=_pair(result,first_rows[axis],second_rows[axis],positive,int(quantized.shift_s32))
		if renormalized:normalized+=1
		if axis==2 and int(result[0x86])==int(state.player_index_u32):state.player_roll_s16=_s16(int(state.player_roll_s16)-consumed if positive else int(state.player_roll_s16)+consumed)
		applied.append({"axis":axis,"positive":positive,"consumed_s16":consumed,"shift_s32":quantized.shift_s32,"matrix_normalized":renormalized})
	return {"ok":true,"source_profile":PROFILE,"body_after":result,"globals_after":state,"applied":applied,"normalization_count":normalized,"effective_budget_s32":limit,"residues_s16":[result.decode_s16(0xb0),result.decode_s16(0xb2),result.decode_s16(0xb4)],"raw_owner_mutated":false,"quaternion_reconstruction_used":false}

static func rotate_pair_raw(body:Variant,first:Variant,second:Variant,positive:Variant,shift:Variant)->Dictionary:
	if not _body(body) or not _whole(first,0,24) or not int(first) in [0,12,24] or not _whole(second,0,24) or not int(second) in [0,12,24] or first==second or not positive is bool or not _whole(shift,2,9):return _reject("unsupported_raw_rotation_pair")
	var result:PackedByteArray=body.duplicate();var normalized:=_pair(result,int(first),int(second),positive,int(shift))
	return {"ok":true,"source_profile":PROFILE,"body_after":result,"matrix_normalized":normalized,"raw_owner_mutated":false}

static func spin_command_raw(body:Variant,spin:Variant)->Dictionary:
	if not _body(body) or not spin is PackedInt64Array or spin.size()!=3:return _reject("invalid_raw_spin")
	for value in spin:
		if value< -0x80000000 or value>0x7fffffff:return _reject("invalid_raw_spin")
	var result:PackedByteArray=body.duplicate();var product:=0
	for axis in range(3):product=_s32(product+_s32((result.decode_s32(axis*4)>>16)*spin[axis]))
	result.encode_u16(0x112,_s16(-(product>>18))&0xffff)
	return {"ok":true,"source_profile":PROFILE,"body_after":result,"raw_owner_mutated":false}

static func orthonormalize_raw(body:Variant)->Dictionary:
	if not _body(body):return _reject("invalid_raw_body")
	var result:PackedByteArray=body.duplicate();_normalize(result)
	return {"ok":true,"source_profile":PROFILE,"body_after":result,"raw_owner_mutated":false}
