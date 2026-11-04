extends RefCounted
# Original F883..F887 classification on paths that finish without invoking
# unavailable F891/F892 settlement or F893 recursive naming helpers.
# The result is an atomic source-record candidate, not a complete planet factory.
const RandomSource=preload("res://scripts/stellar_body_factory.gd")
const MASK:=0xffffffff
const CALLBACKS:=[883,884,885,886,887]

static func _u32(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=MASK and value==floorf(value)
static func _signed32(value:int)->int:
	var word:=value&MASK
	return word-0x100000000 if word>=0x80000000 else word
static func _blocked(helper:int)->Dictionary:
	return {"ok":false,"reason":"requires_unimplemented_source_helper","helper_id":helper}
static func _set_class(body:PackedByteArray,model:int,type_code:int)->void:
	body.encode_u16(0x0c,model);body.encode_u16(0x0a,type_code)
static func _add_temperature(body:PackedByteArray,amount:int)->int:
	var value:=(int(body.decode_u16(0x24))+amount)&65535
	body.encode_u16(0x24,value);return value

func classify(record:PackedByteArray,callback:Variant,mass:Variant,population_raw:Variant,system_id:Variant,seed_a:Variant,seed_b:Variant)->Dictionary:
	if record.size()!=68 or not _u32(callback) or not int(callback) in CALLBACKS:return {}
	for value in [mass,population_raw,system_id,seed_a,seed_b]:
		if not _u32(value):return {}
	var body:=record.duplicate()
	var seeds:=PackedInt64Array([int(seed_a),int(seed_b)])
	var population:=_signed32(int(population_raw))
	var function_id:=int(callback)
	var temperature:=int(body.decode_u16(0x24))
	if function_id==883:
		if temperature>0x139:
			_set_class(body,0x7b,0xc)
			_add_temperature(body,int(mass)>>1)
		elif temperature<=0xd7:
			if temperature>=0xaa:
				_add_temperature(body,0x19)
				if population<0xc8:
					_set_class(body,0x7b,0x6)
					if int(system_id) in [0x1aa89738,0x02ae1718,0x0eb6973d]:
						body.encode_u16(0xc,0x85)
						var uid:=int(body.decode_u32(4))
						if (int(system_id)==0x02ae1718 and uid==0x5b5ff290) or (int(system_id)==0x0eb6973d and uid==0x70740190):return _blocked(892)
				else:return _blocked(893)
			elif temperature>=0x42 and temperature<=0x7b:
				_add_temperature(body,0x16);_set_class(body,0x7c,0x7)
			else:function_id=884
		else:
			temperature=_add_temperature(body,0x23)
			seeds=RandomSource.rng_step(seeds[0],seeds[1])
			# CMP/JNA is unsigned: a negative subtraction wraps to unsigned32.
			if ((seeds[0]&255)>>2)>((temperature-0xfa)&MASK):
				if population<0x78:_set_class(body,0x80,0x8)
				else:return _blocked(893)
			elif population>=4:return _blocked(893)
	if function_id==884:
		temperature=_add_temperature(body,0x14)
		if population>=0x96 and temperature>=0x102 and temperature<=0x139:return _blocked(893)
		_set_class(body,0x79,0x4)
		if temperature<=0x212:
			var reaches_names:=(population>=0xc8 and temperature>=0xa0) or (temperature>=0xb4 and population>6) or (population>=0xfa and temperature>0x87)
			if reaches_names:return _blocked(893)
	elif function_id==885:
		if temperature>=0x96 and temperature<=0x1f4 and (population>=0xc8 or (temperature>=0xc8 and population>8)):return _blocked(893)
	elif function_id==886:
		if temperature>=0xdc and population>0x32:return _blocked(893)
	elif function_id==887:
		body.encode_u16(0,0);body.encode_u16(2,0x38)
		if temperature>=0xdc and population>0x32:return _blocked(893)
	return {"ok":true,"record":body,"seed_a":seeds[0],"seed_b":seeds[1],"callback":int(callback)}
