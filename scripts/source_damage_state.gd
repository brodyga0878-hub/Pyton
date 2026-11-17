extends RefCounted
# One owned F953 target/context: raw Root contains the sole RNG words. Event
# registers, module entries and flags retain exact bytes across cold replay.
# Matched world/module callbacks remain explicit, not invented side effects.
const Damage=preload("res://scripts/source_damage.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const PROFILE:="dos-firstenc-owned-damage-state-v1"
const SCHEMA:="starfrontier-source-damage-state-v1"
const MAX_GENERATION:=100000000
const BUFFER_BYTES:={"root":16384,"flags":115,"event_registers":284,"module_entries":168}
var _core:Dictionary={}
var _generation:=0
var _revision:=0
var _witness:Dictionary={}

static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false,"full_world_effects_executed":false}
static func _json_value(value:Variant)->Variant:
	if value is PackedByteArray:return value.hex_encode()
	if value is Dictionary:
		var result:Dictionary={}
		for key:Variant in value:result[key]=_json_value(value[key])
		return result
	if value is Array or value is PackedInt64Array:
		var result:Array=[]
		for cell:Variant in value:result.append(_json_value(cell))
		return result
	return value
static func _bytes(value:Variant,count:int)->Variant:
	if value is PackedByteArray:return value.duplicate() if value.size()==count else null
	return str(value).hex_decode() if Frame._hex(value,count) else null
static func _decode_context(value:Variant)->Dictionary:
	if not value is Dictionary or not Clock._keys(value,["root","flags","event_registers","module_entries","module_count_s32","model_descriptors"]):return {}
	var result:Dictionary={}
	for key:String in BUFFER_BYTES:
		var decoded:Variant=_bytes(value[key],int(BUFFER_BYTES[key]))
		if decoded==null:return {}
		result[key]=decoded
	if not Frame._whole(value.module_count_s32,-0x80000000,21) or not value.model_descriptors is Dictionary or value.model_descriptors.size()>149:return {}
	result["module_count_s32"]=int(value.module_count_s32)
	var models:Dictionary={}
	for key:Variant in value.model_descriptors:
		if not key is String or not key.is_valid_int() or str(int(key))!=key or not Frame._whole(int(key),0,0xffffffff):return {}
		var descriptor:Variant=_bytes(value.model_descriptors[key],68)
		if descriptor==null:return {}
		models[key]=descriptor
	result["model_descriptors"]=models
	return Damage._copy_context(result) if Damage._context(result) else {}
static func _decode_observations(value:Variant)->Variant:
	return Damage.decode_observations(value)
static func _valid_core(value:Variant)->bool:
	return value is Dictionary and Clock._keys(value,["body_hex","context"]) and Frame._hex(value.body_hex,338) and not _decode_context(value.context).is_empty()
static func _payload(value:Variant)->bool:
	return value is Dictionary and Clock._keys(value,["damage_s32","attacker_u32","observations"]) and Frame._whole(value.damage_s32,-0x80000000,0x7fffffff) and Frame._whole(value.attacker_u32,0,0xffffffff) and _decode_observations(value.observations)!=null
static func _pack(body:PackedByteArray,context:Dictionary)->Dictionary:
	return {"body_hex":body.hex_encode(),"context":_json_value(context)}
static func _run(core:Dictionary,payload:Dictionary)->Dictionary:
	var result:=Damage.execute(str(core.body_hex).hex_decode(),int(payload.damage_s32),int(payload.attacker_u32),_decode_context(core.context),_decode_observations(payload.observations))
	if not result.get("ok",false):return result
	var next:=_pack(result.body_after,result.context_after)
	if not _valid_core(next):return _reject("invalid_owned_damage_result")
	var receipt:Dictionary={"profile":PROFILE,"return_s32":int(result.return_s32),"return_u32":int(result.return_u32),"source_order":result.source_order.duplicate(),"callback_requests":_json_value(result.requests),"raw_state_after_sha256":Clock._hash(next),"Main_integrated":false,"full_world_effects_executed":false}
	return {"ok":true,"core":next,"receipt":receipt}
func is_active()->bool:return not _core.is_empty()
func generation()->int:return _generation
func raw_core()->Dictionary:return _core.duplicate(true)
func raw_body()->PackedByteArray:return str(_core.body_hex).hex_decode() if is_active() else PackedByteArray()
func raw_context()->Dictionary:return _decode_context(_core.context) if is_active() else {}
func configure(body:Variant,context:Variant)->bool:
	if not body is PackedByteArray or body.size()!=338 or not Damage._context(context):return false
	var core:=_pack(body,Damage._copy_context(context))
	if not _valid_core(core):return false
	_core=core;_generation=0;_witness={};_revision+=1;return true
func prepare_damage(damage_s32:Variant,attacker_u32:Variant,observations:Variant=[])->Dictionary:
	var payload:Dictionary={"damage_s32":damage_s32,"attacker_u32":attacker_u32,"observations":observations}
	if not is_active() or _generation>=MAX_GENERATION or not _payload(payload):return _reject("invalid_owned_damage_command")
	payload=_json_value(payload)
	var result:=_run(_core,payload)
	if not result.get("ok",false):return result
	var candidate=get_script().new();candidate._core=result.core.duplicate(true);candidate._generation=_generation+1
	candidate._witness={"before_generation":_generation,"before_core":_core.duplicate(true),"payload":payload.duplicate(true)}
	result.receipt["generation_after"]=candidate._generation
	return {"ok":true,"profile":PROFILE,"candidate_state":candidate,"owner_instance_id":get_instance_id(),"owner_revision":_revision,"before_generation":_generation,"before_core_sha256":Clock._hash(_core),"receipt":result.receipt}
func commit(prepared:Variant)->bool:
	if not is_active() or not prepared is Dictionary or prepared.get("ok")!=true or prepared.get("profile")!=PROFILE or not prepared.get("candidate_state") is RefCounted or not prepared.get("receipt") is Dictionary or not prepared.get("owner_instance_id") is int or not prepared.get("owner_revision") is int or not prepared.get("before_generation") is int or prepared.owner_instance_id!=get_instance_id() or prepared.owner_revision!=_revision or prepared.before_generation!=_generation or prepared.get("before_core_sha256")!=Clock._hash(_core):return false
	var candidate:RefCounted=prepared.candidate_state
	if candidate==self or candidate.get_script()!=get_script():return false
	var verified=get_script().new()
	if not verified.restore(candidate.snapshot()) or verified._generation!=_generation+1 or Clock._hash(verified._witness.before_core)!=Clock._hash(_core):return false
	var payload:Dictionary=verified._witness.payload
	var expected:=prepare_damage(payload.damage_s32,payload.attacker_u32,payload.observations)
	if not expected.get("ok",false) or Clock._hash(prepared.receipt)!=Clock._hash(expected.receipt):return false
	_core=verified._core.duplicate(true);_generation=verified._generation;_witness=verified._witness.duplicate(true);_revision+=1;return true
func snapshot()->Dictionary:
	if not is_active():return {}
	var result:Dictionary={"schema":SCHEMA,"version":1,"profile":PROFILE,"generation":_generation,"core":_core.duplicate(true),"last_witness":_witness.duplicate(true)}
	result["snapshot_sha256"]=Clock._hash(result);return result
func restore(data:Variant)->bool:
	if not data is Dictionary or not Clock._keys(data,["schema","version","profile","generation","core","last_witness","snapshot_sha256"]) or data.schema!=SCHEMA or not Clock._whole(data.version,1) or int(data.version)!=1 or data.profile!=PROFILE or not Clock._whole(data.generation,MAX_GENERATION) or not _valid_core(data.core) or not data.last_witness is Dictionary:return false
	var witness:Dictionary=data.last_witness
	if int(data.generation)==0:
		if not witness.is_empty():return false
	else:
		if not Clock._keys(witness,["before_generation","before_core","payload"]) or not Clock._whole(witness.before_generation,MAX_GENERATION-1) or int(witness.before_generation)!=int(data.generation)-1 or not _valid_core(witness.before_core) or not _payload(witness.payload):return false
		var replay:=_run(witness.before_core,witness.payload)
		if not replay.get("ok",false) or Clock._hash(replay.core)!=Clock._hash(data.core):return false
	var unsigned:Dictionary=data.duplicate(true);unsigned.erase("snapshot_sha256")
	if data.snapshot_sha256!=Clock._hash(unsigned):return false
	_core=data.core.duplicate(true);_generation=int(data.generation);_witness=witness.duplicate(true);_revision+=1;return true
