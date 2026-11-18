extends RefCounted
# A single cold owner for the complete raw bank, Root and event/module words.
# Targets are physical slots inside the bank, not separately saved body copies.
const Effects=preload("res://scripts/source_damage_effects.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const Scan=preload("res://scripts/source_contact_scan.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const PROFILE:="dos-firstenc-owned-bank-damage-effects-state-v1"
const SCHEMA:="starfrontier-source-damage-effects-state-v1"
const MAX_GENERATION:=100000000
const PAYLOAD_KEYS:=["target_slot_u32","damage_s32","attacker_u32","observations","equipment_observations","destruction_observations"]
var _core:Dictionary={}
var _generation:=0
var _revision:=0
var _witness:Dictionary={}
static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false}
static func _valid_core(value:Variant)->bool:
	return value is Dictionary and Clock._keys(value,["context"]) and not Effects.decode_context(value.context).is_empty()
static func _payload(value:Variant)->bool:
	return value is Dictionary and Clock._keys(value,PAYLOAD_KEYS) and Frame._whole(value.target_slot_u32,0,114) and Frame._whole(value.damage_s32,-0x80000000,0x7fffffff) and Frame._whole(value.attacker_u32,0,0xffffffff) and value.observations is Array and value.observations.size()<=64 and Effects._packets(value.equipment_observations) and Effects._packets(value.destruction_observations)
static func _pack(context:Dictionary)->Dictionary:
	return {"context":Scan.json_value(context)}
static func _run(core:Dictionary,payload:Dictionary)->Dictionary:
	var result:=Effects.execute(Effects.decode_context(core.context),payload.target_slot_u32,payload.damage_s32,payload.attacker_u32,payload.observations,payload.equipment_observations,payload.destruction_observations)
	if not result.get("ok",false):return result
	var next:=_pack(result.context_after)
	if not _valid_core(next):return _reject("invalid_owned_effects_result")
	var receipt:Dictionary={"profile":PROFILE,"target_slot_u32":int(payload.target_slot_u32),"return_u32":int(result.return_u32),"return_s32":int(result.return_s32),"source_order":result.source_order.duplicate(),"equipment_calls_u32":int(result.equipment_calls_u32),"destruction_calls_u32":int(result.destruction_calls_u32),"raw_state_after_sha256":Clock._hash(next),"callback_requests_sha256":Clock._hash({"requests":Scan.json_value(result.requests)}),"Main_integrated":false}
	return {"ok":true,"core":next,"receipt":receipt}
func is_active()->bool:return not _core.is_empty()
func generation()->int:return _generation
func raw_core()->Dictionary:return _core.duplicate(true)
func raw_context()->Dictionary:return Effects.decode_context(_core.context) if is_active() else {}
func configure(context:Variant)->bool:
	if not Effects._context(context):return false
	var core:=_pack(Effects._copy_context(context))
	if not _valid_core(core):return false
	_core=core;_generation=0;_witness={};_revision+=1;return true
func prepare_damage(target_slot_u32:Variant,damage_s32:Variant,attacker_u32:Variant,observations:Variant=[],equipment_observations:Variant=[],destruction_observations:Variant=[])->Dictionary:
	var payload:Dictionary={"target_slot_u32":target_slot_u32,"damage_s32":damage_s32,"attacker_u32":attacker_u32,"observations":observations,"equipment_observations":equipment_observations,"destruction_observations":destruction_observations}
	if not is_active() or _generation>=MAX_GENERATION or not _payload(payload):return _reject("invalid_owned_effects_command")
	payload=Scan.json_value(payload)
	var result:=_run(_core,payload)
	if not result.get("ok",false):return result
	var candidate=get_script().new();candidate._core=result.core.duplicate(true);candidate._generation=_generation+1
	candidate._witness={"before_generation":_generation,"before_core":_core.duplicate(true),"payload":payload.duplicate(true)}
	result.receipt["generation_after"]=candidate._generation
	return {"ok":true,"profile":PROFILE,"candidate_state":candidate,"owner_instance_id":get_instance_id(),"owner_revision":_revision,"before_generation":_generation,"before_core_sha256":Clock._hash(_core),"receipt":result.receipt}
func commit(prepared:Variant)->bool:
	if not is_active() or not prepared is Dictionary or prepared.get("ok")!=true or prepared.get("profile")!=PROFILE or not prepared.get("candidate_state") is RefCounted or not prepared.get("receipt") is Dictionary or not prepared.get("owner_instance_id") is int or not prepared.get("owner_revision") is int or not prepared.get("before_generation") is int or prepared.get("owner_instance_id")!=get_instance_id() or prepared.get("owner_revision")!=_revision or prepared.get("before_generation")!=_generation or prepared.get("before_core_sha256")!=Clock._hash(_core):return false
	var candidate:RefCounted=prepared.candidate_state
	if candidate==self or candidate.get_script()!=get_script():return false
	var verified=get_script().new()
	if not verified.restore(candidate.snapshot()) or verified._generation!=_generation+1 or Clock._hash(verified._witness.before_core)!=Clock._hash(_core):return false
	var p:Dictionary=verified._witness.payload
	var expected:=prepare_damage(p.target_slot_u32,p.damage_s32,p.attacker_u32,p.observations,p.equipment_observations,p.destruction_observations)
	if not expected.get("ok",false) or Clock._hash(prepared.receipt)!=Clock._hash(expected.receipt):return false
	_core=verified._core.duplicate(true);_generation=verified._generation;_witness=verified._witness.duplicate(true);_revision+=1;return true
func snapshot()->Dictionary:
	if not is_active():return {}
	var result:Dictionary={"schema":SCHEMA,"version":1,"profile":PROFILE,"generation":_generation,"core":_core.duplicate(true),"last_witness":_witness.duplicate(true)}
	result["snapshot_sha256"]=Clock._hash(result);return result
func restore(value:Variant)->bool:
	if not value is Dictionary or not Clock._keys(value,["schema","version","profile","generation","core","last_witness","snapshot_sha256"]) or value.schema!=SCHEMA or not Frame._whole(value.version,1,1) or value.profile!=PROFILE or not Frame._whole(value.generation,0,MAX_GENERATION) or not _valid_core(value.core) or not value.last_witness is Dictionary:return false
	var witness:Dictionary=value.last_witness
	if int(value.generation)==0:
		if not witness.is_empty():return false
	else:
		if not Clock._keys(witness,["before_generation","before_core","payload"]) or not Frame._whole(witness.before_generation,0,MAX_GENERATION-1) or int(witness.before_generation)!=int(value.generation)-1 or not _valid_core(witness.before_core) or not _payload(witness.payload):return false
		var replay:=_run(witness.before_core,witness.payload)
		if not replay.get("ok",false) or Clock._hash(replay.core)!=Clock._hash(value.core):return false
	var signed:Dictionary=value.duplicate(true);signed.erase("snapshot_sha256")
	if value.snapshot_sha256!=Clock._hash(signed):return false
	_core=value.core.duplicate(true);_generation=int(value.generation);_witness=witness.duplicate(true);_revision+=1;return true
