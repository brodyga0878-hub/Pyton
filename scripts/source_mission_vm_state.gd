extends RefCounted
# Replay-verified statement VM owner. Source cursor/return data belongs to the call
# receipt; the persistent core has one copy of each mutable world/arena owner.
const Runtime=preload("res://scripts/source_mission_vm.gd")
const Safe=preload("res://scripts/source_mission_services.gd")
const Scan=preload("res://scripts/source_contact_scan.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const PROFILE:="dos-firstenc-owned-mission-vm-v1"
const SCHEMA:="starfrontier-source-mission-vm-v1"
const MAX_GENERATION:=100000000
var _core:Dictionary={}
var _generation:=0
var _revision:=0
var _witness:Dictionary={}
static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false}
static func _valid_core(value:Variant)->bool:return value is Dictionary and Clock._keys(value,["context"]) and not Runtime.decode_context(value.context).is_empty()
static func _payload(value:Variant)->bool:
	return value is Dictionary and Clock._keys(value,["command","observations"]) and value.command is Dictionary and value.observations is Array and value.observations.size()<=256 and Safe._plain(value)
static func _pack(value:Dictionary)->Dictionary:return {"context":Scan.json_value(value)}
static func _run(core:Dictionary,payload:Dictionary)->Dictionary:
	var result:=Runtime.execute(Runtime.decode_context(core.context),payload.command,payload.observations)
	if not result.get("ok",false):return result
	var next:=_pack(result.context_after)
	if not _valid_core(next):return _reject("invalid_owned_service_result")
	var receipt:Dictionary={"profile":PROFILE,"service_kind":str(payload.command.kind),"operation":str(payload.command.operation),"cursor_after_u32":int(result.cursor_after_u32),"return_u32":int(result.return_u32),"return_defined":bool(result.return_defined),"source_order":result.source_order.duplicate(),"raw_state_after_sha256":Clock._hash(next),"kernel_result_sha256":Clock._hash(Scan.json_value(result.kernel_result)),"nested_dependency_calls_u32":result.dependency_calls.size(),"Main_integrated":false,"statement_frames_used":int(result.statement_frames_used),"statement_frames_after_sha256":Clock._hash({"frames":result.statement_frames_after})}
	return {"ok":true,"core":next,"receipt":receipt}
func is_active()->bool:return not _core.is_empty()
func generation()->int:return _generation
func raw_core()->Dictionary:return _core.duplicate(true)
func raw_context()->Dictionary:return Runtime.decode_context(_core.context) if is_active() else {}
func configure(context:Variant)->bool:
	if not Runtime._context(context):return false
	var core:=_pack(Runtime._copy_context(context))
	if not _valid_core(core):return false
	_core=core;_generation=0;_witness={};_revision+=1;return true
func prepare(command:Variant,observations:Variant=[])->Dictionary:
	var payload:Dictionary={"command":command,"observations":observations}
	if not is_active() or _generation>=MAX_GENERATION or not _payload(payload):return _reject("invalid_owned_service_command")
	payload=Scan.json_value(payload)
	if not _payload(payload):return _reject("owned_mission_serialization_profile_limit")
	var result:=_run(_core,payload)
	if not result.get("ok",false):return result
	var candidate=get_script().new();candidate._core=result.core.duplicate(true);candidate._generation=_generation+1
	candidate._witness={"before_generation":_generation,"before_core":_core.duplicate(true),"payload":payload.duplicate(true)}
	if candidate.snapshot().is_empty():return _reject("owned_mission_snapshot_profile_limit")
	result.receipt["generation_after"]=candidate._generation
	return {"ok":true,"profile":PROFILE,"candidate_state":candidate,"owner_instance_id":get_instance_id(),"owner_revision":_revision,"before_generation":_generation,"before_core_sha256":Clock._hash(_core),"receipt":result.receipt}
func commit(prepared:Variant)->bool:
	if not is_active() or not prepared is Dictionary or prepared.get("ok")!=true or prepared.get("profile")!=PROFILE or not prepared.get("candidate_state") is RefCounted or not prepared.get("receipt") is Dictionary or not Safe._plain(prepared.receipt) or not prepared.get("owner_instance_id") is int or not prepared.get("owner_revision") is int or not prepared.get("before_generation") is int or prepared.owner_instance_id!=get_instance_id() or prepared.owner_revision!=_revision or prepared.before_generation!=_generation or prepared.get("before_core_sha256")!=Clock._hash(_core):return false
	var candidate:RefCounted=prepared.candidate_state
	if candidate==self or candidate.get_script()!=get_script():return false
	var verified=get_script().new()
	if not verified.restore(candidate.snapshot()) or verified._generation!=_generation+1 or Clock._hash(verified._witness.before_core)!=Clock._hash(_core):return false
	var payload:Dictionary=verified._witness.payload;var expected:=prepare(payload.command,payload.observations)
	if not expected.get("ok",false) or Clock._hash(prepared.receipt)!=Clock._hash(expected.receipt):return false
	_core=verified._core.duplicate(true);_generation=verified._generation;_witness=verified._witness.duplicate(true);_revision+=1;return true
func snapshot()->Dictionary:
	if not is_active() or not _valid_core(_core) or not Safe._plain(_witness):return {}
	var shape:Dictionary={"schema":SCHEMA,"version":1,"profile":PROFILE,"generation":_generation,"core":_core,"last_witness":_witness,"snapshot_sha256":"0".repeat(64)}
	if not Safe._plain(shape):return {}
	var value:Dictionary={"schema":SCHEMA,"version":1,"profile":PROFILE,"generation":_generation,"core":_core.duplicate(true),"last_witness":_witness.duplicate(true)}
	value["snapshot_sha256"]=Clock._hash(value);return value
func restore(value:Variant)->bool:
	if not value is Dictionary or not Safe._plain(value) or not Clock._keys(value,["schema","version","profile","generation","core","last_witness","snapshot_sha256"]) or value.schema!=SCHEMA or not Frame._whole(value.version,1,1) or value.profile!=PROFILE or not Frame._whole(value.generation,0,MAX_GENERATION) or not _valid_core(value.core) or not value.last_witness is Dictionary:return false
	var witness:Dictionary=value.last_witness
	if int(value.generation)==0:
		if not witness.is_empty():return false
	else:
		if not Clock._keys(witness,["before_generation","before_core","payload"]) or not Frame._whole(witness.before_generation,0,MAX_GENERATION-1) or int(witness.before_generation)!=int(value.generation)-1 or not _valid_core(witness.before_core) or not _payload(witness.payload):return false
		var replay:=_run(witness.before_core,witness.payload)
		if not replay.get("ok",false) or Clock._hash(replay.core)!=Clock._hash(value.core):return false
	var unsigned:Dictionary=value.duplicate(true);unsigned.erase("snapshot_sha256")
	if value.snapshot_sha256!=Clock._hash(unsigned):return false
	_core=value.core.duplicate(true);_generation=int(value.generation);_witness=witness.duplicate(true);_revision+=1;return true
