extends RefCounted
# F1533 is parametric in the selected descriptor after the nonzero gate.
# The additional cargo153/explosion155 records reuse the reviewed initializer;
# actual DOS F1533 controls verify every output byte with the true model token.
const Factory=preload("res://scripts/source_object_factory.gd")
const PROFILE:="dos-firstenc-effect-factory-v1"
const RESOURCE_PATH:="res://data/ffe_effect_factory.json"
const RESOURCE_SHA256:="28afd09d2d3107c75d20e15fa9c431f46cddfee3a399de9a29d7310a7f782db3"
const EXTRA_MODEL_IDS:=[153,155]
static var _models:Dictionary={}
static var _mutex:=Mutex.new()

static func _indices(value:Variant,expected:Array)->bool:
	if not value is Array or value.size()!=expected.size():return false
	for i in range(expected.size()):
		if not Factory._whole(value[i],0,0xffffffff) or int(value[i])!=int(expected[i]):return false
	return true
static func supported_model(index:Variant)->bool:
	return Factory._whole(index,0,148) or (Factory._whole(index,0,0xffffffff) and int(index) in EXTRA_MODEL_IDS)
static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"raw_owners_changed":false,"object_allocated":false,"source_clock_advanced":false,"full_special_model_inventory":false,"full_explosion_or_debris_engine":false}
static func source_model(index:Variant)->Dictionary:
	if not supported_model(index):return {}
	if int(index)<=148:return Factory.source_model(index)
	_mutex.lock()
	if _models.is_empty():
		if not FileAccess.file_exists(RESOURCE_PATH) or FileAccess.get_sha256(RESOURCE_PATH)!=RESOURCE_SHA256:_mutex.unlock();return {}
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(RESOURCE_PATH))
		if not parsed is Dictionary or parsed.get("schema")!="starfrontier-effect-factory-resources-v1" or parsed.get("profile")!=PROFILE or parsed.get("source_executable_sha256")!=Factory.SOURCE_EXE_SHA256 or not _indices(parsed.get("selected_model_indices"),EXTRA_MODEL_IDS) or not _indices(parsed.get("null_model_indices"),[149]) or not parsed.get("models") is Dictionary or parsed.models.size()!=2:_mutex.unlock();return {}
		for key:String in ["153","155"]:
			if not parsed.models.has(key) or not Factory._resources(parsed.models[key]):_mutex.unlock();return {}
		_models=parsed.models.duplicate(true)
	var result:Dictionary=_models.get(str(int(index)),{}).duplicate(true)
	_mutex.unlock();return result
static func initialize_context(destination:Variant,source:Variant,model_index:Variant,clock:Variant,resources:Variant,copy_source:Variant=true)->Dictionary:
	if not supported_model(model_index):return _reject("effect_factory_model_not_captured_or_null")
	var actual:=int(model_index);var token:=actual if actual<=148 else 1
	var result:=Factory.initialize_context(destination,source,token,clock,resources,copy_source)
	if not result.get("ok",false):return _reject("factory_"+str(result.get("reason","rejected")))
	# Original model token ESI is tested, stored at+82 and used for F1538.
	# ESI then becomes the descriptor pointer; no later operation reads the token.
	if actual!=token:result.body_after.encode_u32(0x82,actual)
	result.profile=PROFILE;result["source_model_index_u32"]=actual;result["additional_resource_adapter_used"]=actual!=token;result["full_special_model_inventory"]=false;result["full_explosion_or_debris_engine"]=false
	return result
static func initialize_raw(destination:Variant,source:Variant,model_index:Variant,clock:Variant,copy_source:Variant=true)->Dictionary:
	var resource:=source_model(model_index)
	if resource.is_empty():return _reject("effect_factory_resource_unavailable")
	return initialize_context(destination,source,model_index,clock,resource,copy_source)
static func initialize_in_place(body:Variant,model_index:Variant,clock:Variant)->Dictionary:
	return initialize_raw(body,body,model_index,clock,false)
