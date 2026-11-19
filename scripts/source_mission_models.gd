extends RefCounted
# Original F36 replacement, distinct from F1533 object creation/copying.
# Catalog references are original resource identities, never host pointers.
const Orbit=preload("res://scripts/source_orbit.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const PROFILE:="dos-firstenc-model-replacement-v1"
const RESOURCE:="res://data/ffe_mission_models.json"
const RESOURCE_SHA:="0e90113470f40071336631e5777550835c330d32ff9a9968f8e1200e07200a1a"
const CANONICAL_RESOURCE_SHA:="b6248eb3138ce105c41c29bd95757ec8b1d763544591eee4c023307d4de30f35"
const MODEL_COUNT:=466
const BODY_BYTES:=338
const DRIVE_MASSES:=[0,4,10,25,45,80,150,250,400,600,6,12,24,36,0]
const RESOURCE_KEYS:=["descriptor_hex","collision_present","collision_first_byte_u8","physical_spec_hex","drive_mass_table_u32"]
static var _catalog:Dictionary={}
static var _mutex:=Mutex.new()
static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"profile":PROFILE,"raw_owners_changed":false,"object_allocated":false,"source_clock_advanced":false,"Main_integrated":false}
static func _s16(value:int)->int:return (value&0x7fff)-(value&0x8000)
static func _s8(value:int)->int:return (value&0x7f)-(value&0x80)
static func _plain(value:Variant,depth:int,budget:Array)->bool:
	budget[0]-=1
	if depth>24 or budget[0]<0:return false
	if value is Dictionary:
		if value.size()>4096:return false
		for key:Variant in value:
			if not key is String or not _plain(value[key],depth+1,budget):return false
		return true
	if value is Array:
		if value.size()>4096:return false
		for item:Variant in value:
			if not _plain(item,depth+1,budget):return false
		return true
	if value is String:return value.length()<=300000
	return value==null or value is bool or value is int or (value is float and is_finite(value))
static func validate_catalog(value:Variant)->bool:
	return value is Dictionary and value.get("schema")=="starfrontier-original-mission-model-resources-v1" and _plain(value,0,[65536]) and Clock._hash(value)==CANONICAL_RESOURCE_SHA
static func load_original()->Dictionary:
	if FileAccess.get_sha256(RESOURCE)!=RESOURCE_SHA:return {}
	var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(RESOURCE))
	return value.duplicate(true) if validate_catalog(value) else {}
static func validate_model(value:Variant)->bool:
	if not Frame._keys(value,RESOURCE_KEYS) or not Frame._hex(value.descriptor_hex,68) or not value.collision_present is bool or not Frame._whole(value.collision_first_byte_u8,0,255) or not value.physical_spec_hex is String or not value.drive_mass_table_u32 is Array or value.drive_mass_table_u32.size()!=15:return false
	var descriptor:PackedByteArray=str(value.descriptor_hex).hex_decode()
	if (descriptor.decode_u32(52)!=0)!=value.collision_present or (not value.collision_present and int(value.collision_first_byte_u8)!=0):return false
	if descriptor.decode_u32(56)!=0:
		if not Frame._hex(value.physical_spec_hex,24):return false
		var physical:PackedByteArray=str(value.physical_spec_hex).hex_decode()
		if physical.decode_s16(20)<0 and (_s8(physical[20])<0 or _s8(physical[20])>=15):return false
	elif value.physical_spec_hex!="":return false
	for index in range(15):
		if not Frame._whole(value.drive_mass_table_u32[index],0,0xffffffff) or int(value.drive_mass_table_u32[index])!=DRIVE_MASSES[index]:return false
	return true
static func source_model(index:Variant)->Dictionary:
	if not Frame._whole(index,0,MODEL_COUNT-1) or int(index)==149:return {}
	_mutex.lock()
	if _catalog.is_empty():_catalog=load_original()
	if _catalog.is_empty():_mutex.unlock();return {}
	var row:Dictionary=_catalog.models.get(str(int(index)),{})
	var result:Dictionary={}
	if not row.is_empty():
		for key:String in ["descriptor_hex","collision_present","collision_first_byte_u8","physical_spec_hex"]:result[key]=row[key]
		result["drive_mass_table_u32"]=DRIVE_MASSES.duplicate()
	_mutex.unlock();return result if validate_model(result) else {}
static func lookup(index:Variant)->Dictionary:
	if not Frame._whole(index,0,MODEL_COUNT-1):return _reject("model_table_index_outside_source_profile")
	if int(index)==149:return {"ok":true,"profile":PROFILE,"model_index_u32":149,"pointer_return_defined":true,"pointer_is_null":true,"resource":{},"Main_integrated":false}
	var resource:=source_model(index)
	if resource.is_empty():return _reject("model_resource_unavailable")
	return {"ok":true,"profile":PROFILE,"model_index_u32":int(index),"pointer_return_defined":true,"pointer_is_null":false,"resource":resource,"Main_integrated":false}
static func replace(body:Variant,model_index:Variant,resources:Variant=null)->Dictionary:
	if not body is PackedByteArray or body.size()!=BODY_BYTES or not Frame._whole(model_index,0,MODEL_COUNT-1):return _reject("invalid_model_replacement_input")
	if int(model_index)==149:return _reject("null_original_model_pointer")
	var resource:Variant=source_model(model_index) if resources==null else resources
	if not validate_model(resource):return _reject("invalid_model_replacement_resource")
	var candidate:PackedByteArray=body.duplicate();var descriptor:PackedByteArray=str(resource.descriptor_hex).hex_decode()
	candidate.encode_u32(0x82,int(model_index))
	var exponent:=_s16(int(descriptor.decode_u16(0x14))+int(descriptor.decode_u16(0x18))+7)-15
	for pair:Array in [[0x138,0x2c],[0x140,0x30]]:
		var shifted:=Orbit.shift_words(Orbit._words(descriptor.decode_s16(int(pair[1]))),exponent)
		if shifted.size()!=2:return _reject("model_replacement_shift_outside_profile")
		candidate.encode_s64(int(pair[0]),Orbit.signed64(shifted))
	var flags:=(int(descriptor[0x24])>>4)&7
	if resource.collision_present and int(resource.collision_first_byte_u8)!=0:flags|=0x80
	candidate[0x14c]=flags
	if str(resource.physical_spec_hex)!="":
		var physical:PackedByteArray=str(resource.physical_spec_hex).hex_decode()
		var reverse:int=physical.decode_u16(2);var opposite:=(-reverse)&65535
		candidate.encode_u16(0xc4,physical.decode_u16(0))
		for offset in [0xc6,0xc2,0xbe]:candidate.encode_u16(offset,reverse)
		for offset in [0xc0,0xbc]:candidate.encode_u16(offset,opposite)
		var signed_reverse:=_s16(opposite)
		candidate[0x101]=2 if signed_reverse>=0x1329 else (1 if signed_reverse>=0xaa5 else 0)
		candidate[0xd1]=physical[4];candidate.encode_u16(0xe4,(int(physical.decode_u16(6))<<2)&65535)
		var capacity:int=physical.decode_s16(8)
		if physical.decode_s16(20)<0:
			var drive:=_s8(physical[20]);candidate[0xd0]=drive&255;capacity-=DRIVE_MASSES[drive]
		candidate.encode_u16(0x116,capacity&65535)
	return {"ok":true,"profile":PROFILE,"body_after":candidate,"source_order":["F36","F1538","F1495","F1341","F1495","F1341"],"physical_spec_present":str(resource.physical_spec_hex)!="","F36_body_executed":true,"F1533_substituted":false,"void_return_register_ignored":true,"return_defined":false,"raw_owners_changed":false,"object_allocated":false,"source_clock_advanced":false,"Main_integrated":false}
