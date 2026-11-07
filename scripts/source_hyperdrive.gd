extends RefCounted
# Original F899..F903/F1521 integer core. The raw evaluator returns copies of
# every mutated byte/global; no caller state, Navigation or Flight is edited.
const DATA_PATH:="res://data/ffe_hyperdrive.json"
const SOURCE_SHA:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const TABLE_SHA:="82659f368ab7b4298735b16b4f76276207a19d1b529526c4452c2c78569fe654"
const CONTRACT:="dos-firstenc-f899-f903-hyperdrive-v1"
const MASK:=0xffffffff
const OBJECT_BYTES:=338
const DISTANCE_RAW_PER_LY:=100.0
const TIME_RAW_PER_DAY:=65536.0
static var _data:Dictionary={}
static var _drives:=PackedByteArray()
static var _mutex:=Mutex.new()

static func _number(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
static func _hex(value:Variant)->bool:
	if not value is String or value.length()%2!=0:return false
	for character:String in value:
		if not character in "0123456789abcdefABCDEF":return false
	return true
static func _s32(value:int)->int:
	value&=MASK;return value-0x100000000 if value>=0x80000000 else value
static func _s16(value:int)->int:
	value&=65535;return value-65536 if value>=32768 else value
static func _s8(value:int)->int:
	value&=255;return value-256 if value>=128 else value
@warning_ignore("integer_division")
static func _div(numerator:int,denominator:int)->int:return numerator/denominator
static func _load()->bool:
	_mutex.lock()
	if not _data.is_empty():_mutex.unlock();return true
	var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
	if not value is Dictionary or value.get("schema")!=1 or value.get("source_sha256")!=SOURCE_SHA or not _hex(value.get("drive_table_hex")) or not value.get("ship_specs") is Dictionary:
		_mutex.unlock();return false
	var raw:=str(value.drive_table_hex).hex_decode()
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw)
	if raw.size()!=240 or hash.finish().hex_encode()!=TABLE_SHA:_mutex.unlock();return false
	_data=value;_drives=raw;_mutex.unlock();return true
static func resource()->Dictionary:return _data.duplicate(true) if _load() else {}
static func ship_spec(model_index:int)->PackedByteArray:
	if model_index<0 or model_index>65535 or not _load():return PackedByteArray()
	var entry:Variant=_data.ship_specs.get(str(model_index))
	if not entry is Dictionary or not _hex(entry.get("spec_hex")):return PackedByteArray()
	var raw:=str(entry.spec_hex).hex_decode()
	return raw if raw.size()>=10 else PackedByteArray()
static func drive(index:int)->Dictionary:
	if index<0 or index>=15 or not _load():return {}
	var at:=index*16
	return {"source_drive_index":index,"power_u32":int(_drives.decode_u32(at)),"correction_u32":int(_drives.decode_u32(at+4)),"capacity_threshold_u32":int(_drives.decode_u32(at+8)),"name_code_u32":int(_drives.decode_u32(at+12)),"raw_hex":_drives.slice(at,at+16).hex_encode()}

static func multiply_q31(first:int,second:int)->int:
	# F1521 IMUL signed64 followed SHL EAX/RCL EDX, returning the high word.
	return _s32((_s32(first)*_s32(second))>>31)

static func _globals(input:Dictionary)->Dictionary:
	var result:={"player_object_index_u32":input.get("player_object_index_u32",input.get("player_index_u32",0)),"status_u16":input.get("status_u16",0),"cargo_s32":input.get("cargo_s32",input.get("cargo_u32",0)),"hydrogen_u16":input.get("hydrogen_u16",0),"military_u16":input.get("military_u16",0),"waste_u16":input.get("waste_u16",0)}
	for key:String in result:
		var high:=MASK if key in ["player_object_index_u32","cargo_s32"] else 65535
		var low:=-2147483648 if key=="cargo_s32" else 0
		if not _number(result[key],low,high):return {}
		result[key]=_s32(int(result[key])) if key=="cargo_s32" else int(result[key])
	return result
static func _reject(reason:String,object:PackedByteArray,globals:Dictionary)->Dictionary:
	return {"ok":false,"can_jump":false,"reason":reason,"error":reason,"object":object.duplicate(),"globals":globals.duplicate(true),"source_contract":CONTRACT,"source_sha256":SOURCE_SHA}
static func _result(object:PackedByteArray,globals:Dictionary,outputs:Array,returned:int,distance:int,reason:String)->Dictionary:
	return {"ok":true,"can_jump":returned>=0,"reason":reason,"error":"","source_return_s32":_s32(returned),"return_s32":_s32(returned),"distance_raw_s32":distance,"name_code_u32":int(outputs[0])&MASK,"fuel_needed_s32":_s32(int(outputs[1])),"current_range_s32":_s32(int(outputs[2])),"time_raw_u32":int(outputs[3])&MASK,"max_range_s32":_s32(int(outputs[4])),"outputs_u32":[int(outputs[0])&MASK,int(outputs[1])&MASK,int(outputs[2])&MASK,int(outputs[3])&MASK,int(outputs[4])&MASK],"object":object,"globals":globals,"source_contract":CONTRACT,"source_sha256":SOURCE_SHA}

static func evaluate(object_bytes:PackedByteArray,spec_bytes:PackedByteArray,distance_raw:int,globals:Dictionary={},mode:int=1)->Dictionary:
	if object_bytes.size()!=OBJECT_BYTES or spec_bytes.size()<10:return _reject("invalid_raw_buffers",object_bytes,globals)
	if not _number(distance_raw,-2147483648,MASK) or not _number(mode,-2147483648,MASK):return _reject("invalid_integer_domain",object_bytes,globals)
	var state:=_globals(globals)
	if state.is_empty():return _reject("invalid_globals",object_bytes,globals)
	var seeds:Variant=globals.get("output_seed_u32",[0,0,0,0,0])
	if not seeds is Array or seeds.size()!=5:return _reject("invalid_output_seeds",object_bytes,globals)
	var outputs:Array=[]
	for seed:Variant in seeds:
		if not _number(seed,0,MASK):return _reject("invalid_output_seeds",object_bytes,globals)
		outputs.append(int(seed))
	var index:=_s8(int(object_bytes[0xd0]));var mass:=_s16(int(spec_bytes.decode_u16(6)))
	if index<0 or index>=15:return _reject("invalid_drive_index",object_bytes,globals)
	if mass==0:return _reject("source_divide_by_zero",object_bytes,globals)
	if not _load():return _reject("resource_unavailable",object_bytes,globals)
	var entry:=drive(index);var distance:=_s32(distance_raw)
	var maximum:=_div(_s32(int(entry.power_u32)),mass)
	outputs[0]=int(entry.name_code_u32);outputs[1]=mass&MASK;outputs[4]=maximum&MASK
	var player:=int(object_bytes[0x86])==int(state.player_object_index_u32)
	var object:=object_bytes.duplicate()
	if maximum<distance or distance==0:
		outputs[2]=0;outputs[1]=MASK
		if player and distance!=0:state.status_u16=int(state.status_u16)&0xfeff
		return _result(object,state,outputs,-1,distance,"zero_distance" if distance==0 else ("no_drive" if int(entry.power_u32)==0 else "out_of_range"))
	# The original discards IMUL's high word before CDQ/IDIV. This overflow is
	# observable and intentionally is not replaced by a real-number formula.
	var needed:=_s32(_div(_s32(distance*mass),30001)+1)
	var correction:=_s32(int(entry.correction_u32)<<15)
	needed=_s32(needed-multiply_q31(needed,correction));needed=maxi(1,needed);outputs[1]=needed&MASK
	if (maximum&MASK)==0:return _reject("source_divide_by_zero",object_bytes,globals)
	var duration:=(_div(((distance&MASK)<<16)-1&MASK,maximum&MASK)*7)&MASK
	outputs[3]=duration
	var available:=int(object[0x119]) if not player else int(state.military_u16 if index>=10 else state.hydrogen_u16)
	outputs[2]=available
	if needed>available:
		outputs[2]=0
		if player:state.status_u16=int(state.status_u16)&0xfeff
		return _result(object,state,outputs,-1,distance,"insufficient_fuel")
	if player:state.status_u16=int(state.status_u16)|0x100
	if mode==2:
		available=_s32(available-needed)
		if not player:object[0x119]=(int(object[0x119])-needed)&255
		elif index>=10:
			state.military_u16=(int(state.military_u16)-needed)&65535
			state.waste_u16=(int(state.waste_u16)+needed)&65535
			state.status_u16=int(state.status_u16)&0xfeff
		else:
			state.hydrogen_u16=(int(state.hydrogen_u16)-needed)&65535
			state.cargo_s32=_s32(int(state.cargo_s32)-needed)
			state.status_u16=int(state.status_u16)&0xfeff
	var effective_mass:=maxi(1,_s32(mass-multiply_q31(mass,correction)))
	var current:=_s32(_div(30001,effective_mass)*available)
	outputs[2]=(maximum if maximum<current else current)&MASK
	return _result(object,state,outputs,distance,distance,"ready")

static func ranges_for_spec(spec:PackedByteArray)->Dictionary:
	if spec.size()<10 or not _load():return {"ok":false,"error":"invalid_spec_or_resource","ranges_s32":[]}
	var mass:=_s16(int(spec.decode_u16(6)));var capacity:=_s16(int(spec.decode_u16(8)));var ranges:Array=[]
	if mass==0:mass=1 # F902 only; F903 must retain its source fault boundary.
	for index in range(2,10):
		var entry:=drive(index);var range_raw:=0
		if capacity>_s32(int(entry.capacity_threshold_u32)):
			range_raw=_div(_s32(int(entry.power_u32)),mass)
			if range_raw<300:range_raw=0
		ranges.append(range_raw)
	return {"ok":true,"error":"","ranges_s32":ranges,"drive_indices":[2,3,4,5,6,7,8,9],"source_procedure":"F902"}

static func distance_raw_from_q16(from_q16:Array,to_q16:Array)->Dictionary:
	if from_q16.size()!=3 or to_q16.size()!=3:return {"ok":false,"error":"invalid_position","distance_raw":0}
	var components:Array=[]
	for axis in range(3):
		if not _number(from_q16[axis],-2147483648,MASK) or not _number(to_q16[axis],-2147483648,MASK):return {"ok":false,"error":"invalid_position","distance_raw":0}
		components.append(absi(_s32(int(to_q16[axis])-int(from_q16[axis]))>>8))
	var shift:=14
	# F833 checks each axis in sequence, shifting ALL components each time.
	while true:
		for axis in range(3):
			if int(components[axis])>32767:
				for index in range(3):components[index]=int(components[index])>>1
				shift-=1
		if int(components[0])<=32767 and int(components[1])<=32767 and int(components[2])<=32767:break
	var sum:=_s32(int(components[0])*int(components[0])+int(components[1])*int(components[1])+int(components[2])*int(components[2]))
	# Negative FILD sum -> sqrt NaN -> original F2095 FISTP integer-indefinite
	# qword, whose low32 is zero. Preserve this source boundary explicitly.
	var root:=0 if sum<0 else int(sqrt(float(sum)))
	var distance:=_s32(root*0xc8b4)>>(shift&31)
	return {"ok":true,"error":"","distance_raw":distance,"distance_ly":float(distance)/DISTANCE_RAW_PER_LY,"source_procedure":"F833/F2095","source_squared_sum_s32":sum,"source_shift":shift,"source_nan_boundary":sum<0}

static func quote(profile:Dictionary,distance_raw:int,hydrogen:int,military:int,consume:bool=false)->Dictionary:
	var rejected:={"ok":false,"can_jump":false,"reason":"invalid_profile","error":"invalid_profile","source_contract":CONTRACT}
	if not _number(profile.get("model_index"),0,65535) or not _number(profile.get("source_drive_index"),0,14) or not profile.get("player",true) is bool:return rejected
	if not _number(distance_raw,0,2147483647):rejected.reason="invalid_distance";rejected.error=rejected.reason;return rejected
	if not _number(hydrogen,0,65535) or not _number(military,0,65535) or not _number(profile.get("npc_fuel",0),0,255):return rejected
	var spec:=ship_spec(int(profile.model_index))
	if spec.is_empty():rejected.reason="resource_unavailable";rejected.error=rejected.reason;return rejected
	if _s16(int(spec.decode_u16(6)))<=0:return rejected
	var object:=PackedByteArray();object.resize(OBJECT_BYTES);object.encode_u32(0x82,int(profile.model_index));object[0xd0]=int(profile.source_drive_index);object[0x86]=1 if profile.get("player",true) else 2;object[0x119]=int(profile.get("npc_fuel",0))
	var globals:={"player_object_index_u32":1,"status_u16":profile.get("status_u16",0),"cargo_u32":profile.get("cargo_u32",0),"hydrogen_u16":hydrogen,"military_u16":military,"waste_u16":profile.get("waste_u16",0)}
	var result:=evaluate(object,spec,distance_raw,globals,2 if consume else 1)
	if not result.ok:return result
	result["required_fuel"]=int(result.fuel_needed_s32)
	result["max_range_raw"]=int(result.max_range_s32);result["current_range_raw"]=int(result.current_range_s32)
	result["duration_raw_u32"]=int(result.time_raw_u32);result["duration_days"]=float(result.time_raw_u32)/TIME_RAW_PER_DAY
	result["hydrogen_after"]=int(result.globals.hydrogen_u16);result["military_after"]=int(result.globals.military_u16);result["waste_after"]=int(result.globals.waste_u16);result["cargo_after"]=int(result.globals.cargo_s32)&MASK;result["status_after"]=int(result.globals.status_u16);result["npc_fuel_after"]=int(result.object[0x119])
	result["source_drive_index"]=int(profile.source_drive_index);result["model_index"]=int(profile.model_index);result["static_mass_s16"]=_s16(int(spec.decode_u16(6)));result["fuel_kind"]="military" if int(profile.source_drive_index)>=10 else "hydrogen"
	result["consume"]=consume;return result
