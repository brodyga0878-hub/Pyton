extends RefCounted
# Owned raw collision bank and optional external terrain query words. No SI
# round-trip, live Main allocation or world destruction is implied.
const Scan=preload("res://scripts/source_contact_scan.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Context=preload("res://scripts/source_player_context.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const TerrainState=preload("res://scripts/source_terrain_state.gd")
const PROFILE:="dos-firstenc-owned-contact-bank-v1"
const SCHEMA:="starfrontier-source-contact-bank-v1"
const MAX_GENERATION:=100000000
const CORE_KEYS:=["body_hex","objects_hex","flags_hex","root_hex","globals","frame_ticks_u32","source_frame_byte"]
var _core:Dictionary={}
var _generation:=0
var _revision:=0
var _witness:Dictionary={}

static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false,"full_collision_program_VM":false}
static func _objects(value:Variant)->Variant:
	if not value is Dictionary or value.size()>113:return null
	var result:Dictionary={}
	for key:Variant in value:
		if not key is String or not key.is_valid_int() or str(int(key))!=key or int(key)<1 or int(key)>114 or not Frame._hex(value[key],338):return null
		result[int(key)]=str(value[key]).hex_decode()
	return result
static func _valid_core(value:Variant)->bool:
	if not value is Dictionary:return false
	var keys:Array=CORE_KEYS.duplicate()
	if value.has("terrain_aux"):keys.append("terrain_aux")
	if not Clock._keys(value,keys) or not Frame._hex(value.body_hex,338) or not Frame._hex(value.flags_hex,115) or not Frame._hex(value.root_hex,Context.ROOT_BYTES) or not Frame._globals(value.globals) or not Frame._whole(value.frame_ticks_u32,0,0xffffffff) or not Frame._whole(value.source_frame_byte,0,255):return false
	if value.has("terrain_aux") and not TerrainState.valid_aux(value.terrain_aux):return false
	var objects:Variant=_objects(value.objects_hex)
	return objects is Dictionary and str(value.root_hex).hex_decode().decode_u32(0xc0)<=114 and Frame._raw_bank(str(value.body_hex).hex_decode(),objects,str(value.flags_hex).hex_decode())
static func _payload(value:Variant)->bool:
	if not value is Dictionary:return false
	var keys:Array=["enabled","classifier_observations"]
	if value.has("use_geometry"):keys.append("use_geometry")
	if value.has("use_terrain"):keys.append("use_terrain")
	return Clock._keys(value,keys) and value.enabled is bool and (not value.has("use_geometry") or value.use_geometry is bool) and (not value.has("use_terrain") or value.use_terrain is bool) and (not value.get("use_terrain",false) or value.get("use_geometry",false)) and value.classifier_observations is Array and value.classifier_observations.size()<=Scan.LIMIT
static func _pack(body:PackedByteArray,objects:Dictionary,flags:PackedByteArray,root:PackedByteArray,globals:Dictionary,ticks:int,source_frame:int,terrain_aux:Variant=null)->Dictionary:
	var encoded:Dictionary={}
	for index:int in objects:encoded[str(index)]=objects[index].hex_encode()
	var result:Dictionary={"body_hex":body.hex_encode(),"objects_hex":encoded,"flags_hex":flags.hex_encode(),"root_hex":root.hex_encode(),"globals":globals.duplicate(true),"frame_ticks_u32":ticks,"source_frame_byte":source_frame}
	if terrain_aux!=null:result["terrain_aux"]=terrain_aux.duplicate(true)
	return result
static func _run(core:Dictionary,payload:Dictionary)->Dictionary:
	var terrain:Variant=null
	if payload.get("use_terrain",false):
		if not core.has("terrain_aux"):return _reject("missing_owned_terrain_auxiliary_words")
		terrain=TerrainState.from_root(str(core.root_hex).hex_decode(),core.terrain_aux)
		if terrain.is_empty():return _reject("invalid_owned_terrain_state")
	var result:=Scan.dispatch(str(core.body_hex).hex_decode(),_objects(core.objects_hex),str(core.flags_hex).hex_decode(),str(core.root_hex).hex_decode(),core.globals,core.frame_ticks_u32,core.source_frame_byte,payload.classifier_observations,payload.enabled,payload.get("use_geometry",false),terrain)
	if not result.get("ok",false):return result
	var aux:Variant=core.get("terrain_aux",null)
	if terrain!=null:aux=TerrainState.auxiliary(result.terrain_state_after)
	var next:=_pack(result.body,result.objects_by_index,result.flags,result.root_after,result.globals_after,int(core.frame_ticks_u32),int(core.source_frame_byte),aux)
	if not _valid_core(next):return _reject("invalid_raw_contact_result")
	var boundary:=Scan.contact_boundary(str(core.body_hex).hex_decode(),result)
	var receipt:Dictionary={"profile":PROFILE,"outputs":result.outputs.duplicate(true),"classifier_calls":Scan.json_value(result.classifier_calls),"raw_bank_after_sha256":Clock._hash(next),"frame_caller":result.caller_procedure,"contact_boundary_available":not boundary.is_empty(),"full_collision_program_VM":false,"Main_integrated":false,"damage_engine_executed":false}
	if payload.get("use_geometry",false):receipt["actual_geometry_route"]=true
	if terrain!=null:receipt["actual_terrain_route"]=true;receipt["terrain_aux_after"]=aux.duplicate(true)
	return {"ok":true,"core":next,"receipt":receipt,"contact_boundary":boundary}
func is_active()->bool:return not _core.is_empty()
func generation()->int:return _generation
func raw_core()->Dictionary:return _core.duplicate(true)
func configure(body:Variant,objects:Variant,flags:Variant,root:Variant,globals:Variant,frame_ticks_u32:Variant,source_frame_byte:Variant,terrain_aux:Variant=null)->bool:
	if not Frame._raw_bank(body,objects,flags) or not Context._root(root) or not Frame._globals(globals) or not Frame._whole(frame_ticks_u32,0,0xffffffff) or not Frame._whole(source_frame_byte,0,255):return false
	if terrain_aux!=null and not TerrainState.valid_aux(terrain_aux):return false
	var core:=_pack(body,objects,flags,root,globals,int(frame_ticks_u32),int(source_frame_byte),terrain_aux)
	if not _valid_core(core):return false
	_core=core;_generation=0;_witness={};_revision+=1;return true
func prepare(classifier_observations:Variant=[],enabled:Variant=true,use_geometry:Variant=false,use_terrain:Variant=false)->Dictionary:
	var payload:Dictionary={"enabled":enabled,"classifier_observations":classifier_observations}
	if not use_geometry is bool:return _reject("invalid_geometry_route_policy")
	if use_geometry:payload["use_geometry"]=true
	if not use_terrain is bool or (use_terrain and not use_geometry):return _reject("invalid_terrain_route_policy")
	if use_terrain:payload["use_terrain"]=true
	if not is_active() or _generation>=MAX_GENERATION or not _payload(payload):return _reject("invalid_owned_contact_scan_command")
	payload=Scan.json_value(payload)
	var result:=_run(_core,payload)
	if not result.get("ok",false):return result
	var candidate=get_script().new();candidate._core=result.core.duplicate(true);candidate._generation=_generation+1
	candidate._witness={"before_generation":_generation,"before_core":_core.duplicate(true),"payload":payload.duplicate(true)}
	result.receipt.generation_after=candidate._generation
	return {"ok":true,"profile":PROFILE,"candidate_state":candidate,"owner_instance_id":get_instance_id(),"owner_revision":_revision,"before_generation":_generation,"before_core_sha256":Clock._hash(_core),"receipt":result.receipt,"contact_boundary":result.contact_boundary}
func commit(prepared:Variant)->bool:
	if not is_active() or not prepared is Dictionary or prepared.get("ok")!=true or prepared.get("profile")!=PROFILE or not prepared.get("candidate_state") is RefCounted or not prepared.get("receipt") is Dictionary or not prepared.get("contact_boundary") is Dictionary or prepared.get("owner_instance_id")!=get_instance_id() or prepared.get("owner_revision")!=_revision or prepared.get("before_generation")!=_generation or prepared.get("before_core_sha256")!=Clock._hash(_core):return false
	var candidate:RefCounted=prepared.candidate_state
	if candidate==self or candidate.get_script()!=get_script():return false
	var verified=get_script().new()
	if not verified.restore(candidate.snapshot()) or verified._generation!=_generation+1 or Clock._hash(verified._witness.before_core)!=Clock._hash(_core):return false
	var expected:=prepare(verified._witness.payload.classifier_observations,verified._witness.payload.enabled,verified._witness.payload.get("use_geometry",false),verified._witness.payload.get("use_terrain",false))
	if not expected.get("ok",false) or Clock._hash(prepared.receipt)!=Clock._hash(expected.receipt) or Clock._hash(prepared.contact_boundary)!=Clock._hash(expected.contact_boundary):return false
	_core=verified._core.duplicate(true);_generation=verified._generation;_witness=verified._witness.duplicate(true);_revision+=1;return true
func snapshot()->Dictionary:
	if not is_active():return {}
	var result:Dictionary={"schema":SCHEMA,"version":1,"profile":PROFILE,"generation":_generation,"core":_core.duplicate(true),"last_witness":_witness.duplicate(true)}
	result.snapshot_sha256=Clock._hash(result);return result
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
