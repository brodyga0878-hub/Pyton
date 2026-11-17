extends RefCounted
# Whole DOS F1533 object/model initialization over explicit raw caller records.
# This is not allocation, player creation, an SI pose seed or a frame scheduler.
const Orbit=preload("res://scripts/source_orbit.gd")
const PROFILE:="dos-firstenc-raw-object-factory-v1"
const SOURCE_EXE_SHA256:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const RESOURCE_PATH:="res://data/ffe_object_factory.json"
const RESOURCE_SHA256:="c2a39b98f17721b55eac7fc5d3015e39b279fb05a002401fd3120218721894a2"
const OBJECT_BYTES:=338
const MODEL_COUNT:=149
const MASK:=0xffffffff
static var _models:Dictionary={}
static var _mutex:=Mutex.new()
static func _whole(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=low and value<=high and float(value)==floorf(float(value))
static func _keys(value:Variant,keys:Array)->bool:
	if not value is Dictionary or value.size()!=keys.size():return false
	for key:Variant in value:
		if not key is String or key not in keys:return false
	return true
static func _hex(value:Variant,count:int)->bool:
	if not value is String or value.length()!=count*2:return false
	for character:String in value:
		if character not in "0123456789abcdef":return false
	return true
static func _s16(value:int)->int:return (value&0x7fff)-(value&0x8000)
static func _s8(value:int)->int:return (value&0x7f)-(value&0x80)
static func _clock(value:Variant)->bool:
	return _keys(value,["tick_u32","day_u32"]) and _whole(value.tick_u32,0,MASK) and _whole(value.day_u32,0,MASK)
static func _resources(value:Variant)->bool:
	if not _keys(value,["descriptor_hex","collision_present","collision_first_byte_u8","physical_spec_hex","drive_mass_table_u32"]) or not _hex(value.descriptor_hex,68) or not value.collision_present is bool or not _whole(value.collision_first_byte_u8,0,255) or not value.physical_spec_hex is String or not value.drive_mass_table_u32 is Array or value.drive_mass_table_u32.size()!=15:return false
	var descriptor:String=value.descriptor_hex;var raw:=descriptor.hex_decode()
	if (raw.decode_u32(0x34)!=0)!=value.collision_present or (not value.collision_present and int(value.collision_first_byte_u8)!=0):return false
	if raw.decode_u32(0x38)!=0:
		if not _hex(value.physical_spec_hex,24):return false
		var spec:=str(value.physical_spec_hex).hex_decode()
		if spec.decode_s16(0x14)<0 and (_s8(spec[0x14])<0 or _s8(spec[0x14])>=15):return false
	elif value.physical_spec_hex!="":return false
	for word:Variant in value.drive_mass_table_u32:
		if not _whole(word,0,MASK):return false
	return true
static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"raw_owners_changed":false,"object_allocated":false,"source_clock_advanced":false,"full_original_player_factory":false}
static func source_model(index:Variant)->Dictionary:
	if not _whole(index,0,MODEL_COUNT-1):return {}
	_mutex.lock()
	if _models.is_empty():
		if not FileAccess.file_exists(RESOURCE_PATH) or FileAccess.get_sha256(RESOURCE_PATH)!=RESOURCE_SHA256:_mutex.unlock();return {}
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(RESOURCE_PATH))
		if not parsed is Dictionary or parsed.get("schema")!="starfrontier-source-object-factory-resources-v1" or parsed.get("profile")!=PROFILE or parsed.get("source_executable_sha256")!=SOURCE_EXE_SHA256 or int(parsed.get("model_count",-1))!=MODEL_COUNT or not parsed.get("models") is Dictionary or parsed.models.size()!=MODEL_COUNT:_mutex.unlock();return {}
		for key:Variant in parsed.models:
			if not _resources(parsed.models[key]):_mutex.unlock();return {}
		_models=parsed.models.duplicate(true)
	var result:Dictionary=_models.get(str(int(index)),{}).duplicate(true)
	_mutex.unlock();return result
static func initialize_context(destination:Variant,source:Variant,model_index:Variant,clock:Variant,resources:Variant,copy_source:Variant=true)->Dictionary:
	if not destination is PackedByteArray or destination.size()!=OBJECT_BYTES or not source is PackedByteArray or source.size()!=OBJECT_BYTES or not _whole(model_index,0,MODEL_COUNT-1) or not _clock(clock) or not copy_source is bool:return _reject("invalid_raw_factory_inputs")
	var model:=int(model_index)
	if model!=0 and not _resources(resources):return _reject("invalid_or_unsupported_factory_resources")
	var candidate:PackedByteArray=source.duplicate() if copy_source else destination.duplicate()
	if copy_source:candidate[0x86]=int(destination[0x86]) if model!=0 else 0
	if model!=0:
		var descriptor:=str(resources.descriptor_hex).hex_decode()
		candidate.encode_u32(0xa8,int(clock.tick_u32));candidate.encode_u32(0xac,int(clock.day_u32));candidate.encode_u32(0x82,model)
		var exponent:=_s16(int(descriptor.decode_u16(0x14))+int(descriptor.decode_u16(0x18))+7)-15
		for pair:Array in [[0x138,0x2c],[0x140,0x30]]:
			var shifted:=Orbit.shift_words(Orbit._words(descriptor.decode_s16(int(pair[1]))),exponent)
			if shifted.size()!=2:return _reject("factory_bound_shift_rejected")
			candidate.encode_s64(int(pair[0]),Orbit.signed64(shifted))
		candidate[0x151]=0;candidate[0x25]=0;candidate[0x124]=0
		var flags:=(int(descriptor[0x24])>>4)&7
		if resources.collision_present and int(resources.collision_first_byte_u8)!=0:flags|=0x80
		candidate[0x14c]=flags;candidate[0x88]=255
		if str(resources.physical_spec_hex)!="":
			var spec:=str(resources.physical_spec_hex).hex_decode()
			var reverse:int=spec.decode_u16(2);var opposite:=(-reverse)&65535
			candidate.encode_u16(0xc4,spec.decode_u16(0))
			for offset:int in [0xc6,0xc2,0xbe]:candidate.encode_u16(offset,reverse)
			for offset:int in [0xc0,0xbc]:candidate.encode_u16(offset,opposite)
			var upper:=_s16(opposite)
			candidate[0x101]=2 if upper>=0x1329 else (1 if upper>=0xaa5 else 0)
			candidate[0xd1]=spec[4];candidate.encode_u16(0xe4,(int(spec.decode_u16(6))<<2)&65535)
			var capacity:int=spec.decode_s16(8)
			if spec.decode_s16(0x14)<0:
				var drive:=_s8(spec[0x14]);candidate[0xd0]=drive&255
				capacity=(capacity-int(resources.drive_mass_table_u32[drive]))&MASK
			candidate.encode_u16(0x116,capacity&65535);candidate.encode_u16(0xe0,0);candidate.encode_u16(0xe2,0)
	return {"ok":true,"profile":PROFILE,"body_after":candidate,"copy_performed":copy_source,"descriptor_initialized":model!=0,"physical_spec_initialized":model!=0 and str(resources.physical_spec_hex)!="","raw_owners_changed":false,"object_allocated":false,"source_clock_advanced":false,"full_original_player_factory":false,"pose_seeded_from_SI":false,"type87_assigned":false,"input_pointer_policy":"explicit-logical-copy-identity-no-Godot-host-pointer-dereference"}
static func initialize_raw(destination:Variant,source:Variant,model_index:Variant,clock:Variant,copy_source:Variant=true)->Dictionary:
	var resource:=source_model(model_index)
	if resource.is_empty():return _reject("source_model_resource_unavailable")
	return initialize_context(destination,source,model_index,clock,resource,copy_source)
static func initialize_in_place(body:Variant,model_index:Variant,clock:Variant)->Dictionary:
	return initialize_raw(body,body,model_index,clock,false)
