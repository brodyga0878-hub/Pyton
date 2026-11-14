extends RefCounted
# Bounded, explicit F569/F570-primary-prefix caller state around the immutable
# F576/F575 pipeline. HP/RNG, movement, clocks, fuel, geometry admission and the
# host's clone-and-swap transaction remain outside this session.
const Natural=preload("res://scripts/source_natural_contact.gd")
const Pipeline=preload("res://scripts/source_natural_contact_pipeline.gd")
const Trace=preload("res://scripts/source_terrain_query_trace.gd")
const Ground=preload("res://scripts/source_ground_surface.gd")
const Response=preload("res://scripts/source_surface_contact.gd")
const Park=preload("res://scripts/source_natural_park.gd")
const SCHEMA:="starfrontier-source-natural-contact-session-v1"
const CONTRACT:="source-explicit-primary-parent-natural-contact-session-v1"
const CALLER_POLICY:="isolated-f569-enabled-f570-primary-parent-prefix-v1"
const COORDINATE_POLICY:="matching-primary-bodyfixed-parent-v1"
const HISTORY_POLICY:="explicit-initial-globals-preserved-v1"
const PARK_POLICY:="explicit-host-natural-park-v1"
const THERMAL_VELOCITY_POLICY:="explicit-host-bodyfixed-thermal-word-delta-v1"
const SNAPSHOT_KEYS:=["schema","version","contract","source_sha256","natural_resource_sha256","binding","body_hex","parent_hex","globals","generation","last_sequence","last_token","last_commit_receipt","phase","game_root_hex","park_witness"]
var _body:=PackedByteArray()
var _parent:=PackedByteArray()
var _globals:Dictionary={}
var _binding:Dictionary={}
var _generation:=0
var _last_sequence:=0
var _last_token:=""
var _last_receipt:Dictionary={}
var _phase:="free"
var _park_witness:Dictionary={}
var _last_transition:Dictionary={}
var _last_accepted:=false
var _pending:Dictionary={}
var _game_root:=PackedByteArray()
var _park_context:Dictionary={}
var _park_callbacks:Array=[]

static func _keys(value:Dictionary,keys:Array)->bool:
	if value.size()!=keys.size():return false
	for key:Variant in keys:
		if not value.has(key):return false
	return true
static func _hex(value:Variant,count:int)->bool:
	if not value is String or value.length()!=count*2:return false
	for character:String in value:
		if character not in "0123456789abcdef":return false
	return true
static func _plain(value:Variant,depth:int=0)->bool:
	if depth>8:return false
	if value is Dictionary:
		if value.size()>128:return false
		for key:Variant in value:
			if not key is String or key.length()>128 or not _plain(value[key],depth+1):return false
		return true
	if value is Array:
		if value.size()>256:return false
		for cell:Variant in value:
			if not _plain(cell,depth+1):return false
		return true
	if value is String:return value.length()<=16384
	return value==null or value is bool or ((value is int or value is float) and is_finite(float(value)) and absf(float(value))<=9007199254740991.0)
static func _json(value:Dictionary)->Dictionary:return JSON.parse_string(JSON.stringify(value))
static func _hash(value:Dictionary)->String:return JSON.stringify(_json(value),"",true).sha256_text()
static func _relative(body:PackedByteArray)->PackedInt64Array:
	return PackedInt64Array([body.decode_s64(0x3e),body.decode_s64(0x46),body.decode_s64(0x4e)]) if body.size()==338 else PackedInt64Array()
static func _vector(value:PackedInt64Array)->String:return Natural._vector_hex(value)
static func _decode_vector(value:String)->PackedInt64Array:
	var bytes:=value.hex_decode();return PackedInt64Array([bytes.decode_s64(0),bytes.decode_s64(8),bytes.decode_s64(16)])
static func _history(value:Dictionary)->Dictionary:
	if not _keys(value,Natural.GLOBAL_KEYS) or not _plain(value):return {}
	return Natural._globals(value)
static func caller_globals(history:Dictionary)->Dictionary:
	# Exact F569-enabled/F570 primary-parent prefix assignments. In particular
	# neither altitude HIGH nor previous LOW/HIGH nor active8699 is zeroed.
	var result:=_history(history)
	if result.is_empty():return {}
	for key:String in ["collision_flags_u8","volume_flags_u8","collider_index_u8","primitive_flags_u8","collision_kind_u8"]:result[key]=0
	result.altitude_low_u32=0xffffffff;result.collision_enabled_u8=255
	result.collider_parent_selected=true
	return result
static func _binding_valid(value:Dictionary,parent:PackedByteArray)->bool:
	if not _keys(value,["system_id","parent_id","source_record_hex","coordinate_policy","history_policy"]) or not _plain(value):return false
	if not Natural._whole(value.system_id,0,0xffffffff) or not value.parent_id is String or value.parent_id.is_empty() or value.parent_id.length()>128 or value.coordinate_policy!=COORDINATE_POLICY or value.history_policy!=HISTORY_POLICY or not _hex(value.source_record_hex,68):return false
	var record:=str(value.source_record_hex).hex_decode()
	return parent.size()==338 and record.decode_u16(12)==parent.decode_u32(0x82) and record.decode_u32(4)==parent.decode_u32(0xa0)
static func _operands_valid(body:PackedByteArray,parent:PackedByteArray,relative:PackedInt64Array)->bool:
	if body.size()!=338 or parent.size()!=338 or relative.size()!=3 or relative!=_relative(body):return false
	if body[0x86]==0 or parent[0x86]==0 or body[0x86]==parent[0x86] or body[0x57]==0 or body[0x56]!=parent[0x86]:return false
	var ship:=Natural.ship_model(body.decode_u32(0x82));var model:=int(parent.decode_u32(0x82))
	if ship.is_empty() or model<117 or model>133 or Natural.parent_model(model).is_empty():return false
	var spec:=str(ship.get("physical_spec_hex","")).hex_decode()
	if spec.size()!=24 or Natural._sha(spec)!=str(ship.get("physical_spec_sha256","")):return false
	if body[0x14c]!=int(ship.initial_object_flags_14c_u8) or body.decode_s64(0x138)!=int(ship.f1533_radii.outer_s64) or body.decode_s64(0x140)!=int(ship.f1533_radii.inner_s64):return false
	var initialized:=Ground.initialize_model(parent,model)
	if initialized.is_empty():return false
	var canonical:PackedByteArray=initialized.object
	if parent[0x14c]!=canonical[0x14c] or parent.decode_s64(0x138)!=canonical.decode_s64(0x138) or parent.decode_s64(0x140)!=canonical.decode_s64(0x140):return false
	# This is the declared isolated bodyfixed chart, not an ignored arbitrary
	# parent orientation or an executed F570 reference-frame conversion.
	for index in range(9):
		if parent.decode_s32(index*4)!=(0x7fffffff if index in [0,4,8] else 0):return false
	return true
static func _same_identity(first:PackedByteArray,second:PackedByteArray)->bool:
	for offset:int in [0x56,0x57,0x86,0x14c]:
		if first[offset]!=second[offset]:return false
	return first.slice(0x82,0x86)==second.slice(0x82,0x86) and first.slice(0x138,0x148)==second.slice(0x138,0x148)
static func _isolated_root_valid(root:PackedByteArray,parent:PackedByteArray,parked:bool=false)->bool:
	if root.size()!=Park.ROOT_BYTES or parent.size()!=338:return false
	var zero:=PackedByteArray();zero.resize(Park.ROOT_BYTES)
	if not parked and root==zero:return true
	zero[0xc5]=parent[0x86];zero.encode_u32(0xcc,int(parent[0x86]));zero[0xe8]=0x32;zero[0xf8]=255
	return root==zero
static func _fail(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"error":reason,"damage_calls":[],"callbacks":[],"response_applied":false,"contact_detected":false,"landing_accepted":false,"hp_applied":false,"clock_advanced":false,"fuel_advanced":false,"full_F569":false,"full_F570":false,"full_F575_header":false,"source_object_bank_present":false}
func is_active()->bool:return _body.size()==338
func is_pending()->bool:return not _pending.is_empty()
func phase()->String:return _phase
func generation()->int:return _generation
func raw_body()->PackedByteArray:return _body.duplicate()
func raw_parent()->PackedByteArray:return _parent.duplicate()
func globals()->Dictionary:return _globals.duplicate(true)
func binding()->Dictionary:return _binding.duplicate(true)
func fork_runtime()->RefCounted:
	# Host transaction candidates copy even the private pending proposal; cold
	# snapshots deliberately omit it. No classifier, query or command executes.
	var copy:RefCounted=get_script().new()
	for key:String in ["_body","_parent","_globals","_binding","_generation","_last_sequence","_last_token","_last_receipt","_phase","_park_witness","_last_transition","_last_accepted","_pending","_game_root","_park_context","_park_callbacks"]:
		var value:Variant=get(key)
		if value is Dictionary or value is Array:value=value.duplicate(true)
		elif value is PackedByteArray:value=value.duplicate()
		copy.set(key,value)
	return copy
func configure(body:PackedByteArray,parent:PackedByteArray,initial_globals:Dictionary,source_binding:Dictionary)->bool:
	var history:=_history(initial_globals)
	if history.is_empty() or not _operands_valid(body,parent,_relative(body)) or not _binding_valid(source_binding,parent):return false
	_body=body.duplicate();_parent=parent.duplicate();_globals=history;_binding=_json(source_binding);_generation=0;_last_sequence=0;_last_token="";_last_receipt={};_phase="free";_park_witness={};_last_transition={};_last_accepted=false;_pending={}
	_game_root=PackedByteArray();_game_root.resize(Park.ROOT_BYTES);_park_context={};_park_callbacks=[]
	return true
static func _request_valid(request:Dictionary,sequence:int)->bool:
	return _keys(request,["sequence","graphics_level","caller_policy","interval_receipt"]) and _plain(request,3) and Natural._whole(request.sequence,1,0xffffffff) and int(request.sequence)==sequence and Natural._whole(request.graphics_level,1,1) and request.caller_policy==CALLER_POLICY and request.interval_receipt is Dictionary
static func _header_enters(body:PackedByteArray,parent:PackedByteArray,relative:PackedInt64Array)->bool:
	# Original F575 before JUMP2404: wrapped64 ABS+sum, arithmetic shift1,
	# subtract body outer, then parent outer. Both branches compare SIGNED
	# high words only (not an unsigned radius or a floating distance test).
	var absolute:=PackedInt64Array()
	for value:int in relative:absolute.append(Response._sub64(0,value) if value<0 else value)
	var distance:=Ground._shift64(Response._add64(Response._add64(absolute[0],absolute[1]),absolute[2]),-1)
	distance=Response._sub64(distance,body.decode_s64(0x138))
	if (distance>>32)<0:return true
	distance=Response._sub64(distance,parent.decode_s64(0x138))
	return (distance>>32)<0
static func _raw_transition(body:PackedByteArray,parent:PackedByteArray,relative:PackedInt64Array,initial:Dictionary)->Dictionary:
	if not _header_enters(body,parent,relative):
		return {"ok":true,"body_after":body.duplicate(),"parent_after":parent.duplicate(),"relative_position_s64":relative.duplicate(),"globals_after":initial.duplicate(true),"f576_return_s32":null,"return_flags_u8":0,"dispatch":"original_f575_header_early_return","response_applied":false,"contact_detected":false,"landing_accepted":false,"damage_calls":[],"callbacks":[],"classification":{},"response":{},"trace_rows":[],"f576_called":false}
	var pipeline:=Pipeline.new();var collector:=Trace.new();collector.reset_trace();pipeline._classifier._query=collector
	var result:=pipeline.resolve_natural_player(body,parent,relative,{"graphics_level":1,"initial_globals":initial,"player_object_index_u32":int(body[0x86])})
	if not result.get("ok",false):return result
	var traces:=collector.read_trace();var state:=collector.trace_state()
	if bool(state.trace_truncated) or traces.size()!=int(result.classification.terrain_query_calls) or traces.size()!=int(state.query_count):return _fail("incomplete_actual_source_query_trace")
	result["trace_rows"]=traces;result["f576_called"]=true
	return result
func prepare(candidate:PackedByteArray,parent:PackedByteArray,original_relative:PackedInt64Array,request:Dictionary)->Dictionary:
	if not is_active():return _fail("uninitialized_contact_session")
	if _phase!="free":return _fail("parked_session_requires_explicit_host_release")
	if _generation==0xffffffff or _last_sequence==0xffffffff or not _request_valid(request,_last_sequence+1):return _fail("invalid_or_stale_contact_request")
	if not _operands_valid(candidate,parent,original_relative) or not _same_identity(candidate,_body) or parent!=_parent:return _fail("invalid_or_changed_primary_parent_operands")
	var transition:={"body_before_hex":candidate.hex_encode(),"parent_hex":parent.hex_encode(),"original_relative_s64_hex":_vector(original_relative),"globals_before":_globals.duplicate(true),"request":_json(request),"binding":_binding.duplicate(true),"generation":_generation}
	var request_hash:=_hash(transition)
	if not _pending.is_empty():
		return _pending.duplicate(true) if _pending.request_sha256==request_hash else _fail("different_request_while_contact_pending")
	var initial:=caller_globals(_globals);var kernel:=_raw_transition(candidate,parent,original_relative,initial)
	if not kernel.get("ok",false):return _fail(str(kernel.get("error","source_pipeline_rejected")))
	var traces:Array=kernel.trace_rows
	transition["caller_globals"]=initial;transition["body_after_hex"]=kernel.body_after.hex_encode();transition["globals_after"]=kernel.globals_after.duplicate(true)
	var command_hash:=_hash({"damage_calls":kernel.damage_calls,"callbacks":kernel.callbacks})
	var receipt:={"token":request_hash,"generation":_generation,"sequence":_last_sequence+1,"interval_receipt_sha256":_hash(request.interval_receipt),"commands_sha256":command_hash,"transition_sha256":_hash(transition)}
	_pending={"ok":true,"reason":"source_transition_prepared","token":request_hash,"request_sha256":request_hash,"generation":_generation,"sequence":_last_sequence+1,"source_contract":CONTRACT,"caller_policy":CALLER_POLICY,"body_before_hex":transition.body_before_hex,"body_after_hex":transition.body_after_hex,"parent_hex":transition.parent_hex,"original_relative_s64_hex":transition.original_relative_s64_hex,"globals_before":_globals.duplicate(true),"caller_globals":initial,"globals_after":kernel.globals_after.duplicate(true),"classification":kernel.classification.duplicate(true),"trace_rows":traces.duplicate(true),"kernel":kernel.duplicate(true),"contact_detected":bool(kernel.contact_detected),"response_applied":bool(kernel.response_applied),"landing_accepted":bool(kernel.landing_accepted),"damage_calls":kernel.damage_calls.duplicate(true),"callbacks":kernel.callbacks.duplicate(true),"interval_receipt":request.interval_receipt.duplicate(true),"commit_receipt":receipt,"transition":transition,"hp_applied":false,"clock_advanced":false,"fuel_advanced":false,"full_F569":false,"full_F570":false,"full_F575_header":false,"source_object_bank_present":false}
	_pending["f575_header_entered"]=bool(kernel.f576_called);_pending["f576_called"]=bool(kernel.f576_called);_pending["full_F575_header"]=true
	return _pending.duplicate(true)
func commit(token:String,outer_candidate_receipt:Dictionary)->Dictionary:
	# The receipt acknowledges host validation; it does not prove that an
	# external HP/fuel/clock mutation occurred. The host must clone and swap.
	if _pending.is_empty():
		if not _last_token.is_empty() and token==_last_token and _plain(outer_candidate_receipt) and _json(outer_candidate_receipt)==_json(_last_receipt):return {"ok":true,"reason":"already_committed","already_committed":true,"generation":_generation,"damage_calls":[],"callbacks":[],"response_applied":false}
		return _fail("no_matching_prepared_contact")
	if token!=str(_pending.token) or not _plain(outer_candidate_receipt) or _json(outer_candidate_receipt)!=_json(_pending.commit_receipt):return _fail("mismatched_outer_candidate_receipt")
	_body=str(_pending.body_after_hex).hex_decode();_globals=_pending.globals_after.duplicate(true);_generation+=1;_last_sequence=int(_pending.sequence);_last_token=token;_last_receipt=_json(_pending.commit_receipt);_last_transition=_pending.transition.duplicate(true);_last_accepted=bool(_pending.landing_accepted) and bool(_pending.response_applied) and _pending.damage_calls.is_empty();_park_witness={};_pending={}
	return {"ok":true,"reason":"source_transition_committed","already_committed":false,"generation":_generation,"damage_calls":[],"callbacks":[],"response_applied":false,"hp_applied":false,"clock_advanced":false,"fuel_advanced":false}
func discard(token:String)->bool:
	if _pending.is_empty() or token!=str(_pending.token):return false
	_pending={};return true
func apply_host_velocity_word_delta(delta:PackedInt64Array,policy:String=THERMAL_VELOCITY_POLICY)->bool:
	# F1014 changes integer velocity words. Its owner/frame adapter supplies
	# that actual word delta; low Q16 words are never re-derived from SI floats.
	if not is_active() or _phase!="free" or not _pending.is_empty() or policy!=THERMAL_VELOCITY_POLICY or delta.size()!=3:return false
	var candidate:=_body.duplicate();var changed:=false
	for axis in range(3):
		if delta[axis]<-4294967295 or delta[axis]>4294967295:return false
		var value:=int(_body.decode_s32(0x8c+axis*4))+int(delta[axis])
		if value<-2147483648 or value>2147483647:return false
		candidate.encode_s32(0x8c+axis*4,value);changed=changed or delta[axis]!=0
	if changed:
		_body=candidate;_last_transition={};_last_accepted=false
	return true
static func _replay_witness(witness:Dictionary,body:PackedByteArray,parent:PackedByteArray,history:Dictionary,source_binding:Dictionary)->bool:
	if not _keys(witness,["body_before_hex","parent_hex","original_relative_s64_hex","globals_before","request","binding","generation","caller_globals","body_after_hex","globals_after"]) or not _plain(witness):return false
	for key:String in ["binding","globals_before","globals_after","caller_globals","request"]:
		if not witness[key] is Dictionary:return false
	if not _hex(witness.body_before_hex,338) or not _hex(witness.parent_hex,338) or not _hex(witness.original_relative_s64_hex,24) or not _hex(witness.body_after_hex,338) or witness.parent_hex!=parent.hex_encode() or witness.body_after_hex!=body.hex_encode() or _json(witness.binding)!=_json(source_binding) or not witness.globals_before is Dictionary or not witness.globals_after is Dictionary or not witness.caller_globals is Dictionary:return false
	var before:=str(witness.body_before_hex).hex_decode();var relative:=_decode_vector(witness.original_relative_s64_hex);var prior:=_history(witness.globals_before)
	if prior.is_empty() or _history(witness.globals_after)!=history or caller_globals(prior)!=_history(witness.caller_globals) or not _operands_valid(before,parent,relative) or not _same_identity(before,body):return false
	if not Natural._whole(witness.request.get("sequence"),1,0xffffffff) or not _request_valid(witness.request,int(witness.request.sequence)) or not Natural._whole(witness.generation,0,0xffffffff):return false
	var result:=_raw_transition(before,parent,relative,caller_globals(prior))
	return result.get("ok",false) and bool(result.landing_accepted) and bool(result.response_applied) and result.damage_calls.is_empty() and result.body_after==body and result.globals_after==history
func mark_parked(policy:String=PARK_POLICY)->bool:
	# Only privately committed source output can enter park. Runtime does not
	# classify a second time; cold restoration verifies the witness by replay.
	if not is_active() or not _pending.is_empty() or _phase!="free" or policy!=PARK_POLICY or _last_transition.is_empty() or not _last_accepted:return false
	var context:={"collision_flags_u8":int(_globals.collision_flags_u8),"body_pointer_u32":int(_body[0x86]),"parent_pointer_u32":int(_parent[0x86]),"parent_index_u8":int(_parent[0x86]),"source_flags_8860_u8":0,"control_8918_s32":0,"reference_policy":"isolated-parent-reference-word-v1"}
	var result:=Park.accept(_body,_parent,_game_root,context)
	if not result.ok:return false
	_park_witness={"contact":_last_transition.duplicate(true),"game_root_before_hex":_game_root.hex_encode(),"game_root_after_hex":result.game_root_after.hex_encode(),"park_context":context,"body_after_park_hex":result.body_after.hex_encode(),"callbacks":result.callbacks.duplicate(true)}
	_body=result.body_after.duplicate();_game_root=result.game_root_after.duplicate();_park_context=context.duplicate(true);_park_context.control_8918_s32=0;_park_callbacks=result.callbacks.duplicate(true);_phase="parked";return true
func park_state()->Dictionary:
	return {"phase":_phase,"game_root_hex":_game_root.hex_encode(),"source_state_u8":int(_game_root[0xe8]) if _game_root.size()==Park.ROOT_BYTES else -1,"reference_policy":"isolated-parent-reference-word-v1","source_object_bank_present":false,"park_contract":Park.CONTRACT,"callbacks":_park_callbacks.duplicate(true),"callbacks_executed":false,"full_F1021":false,"source_launch_executed":false}
func parked_tick()->Dictionary:
	if _phase!="parked" or not _pending.is_empty():return _fail("outside_source_park_phase")
	return Park.parked_tick(_body,_parent,_game_root,_park_context)
func release_park(policy:String=PARK_POLICY)->Dictionary:
	if not is_active() or not _pending.is_empty() or _phase!="parked" or policy!=PARK_POLICY:return _fail("invalid_explicit_host_park_release")
	_phase="free";_park_witness={};_last_transition={};_last_accepted=false;_park_context={};_park_callbacks=[]
	return {"ok":true,"reason":"explicit_host_park_released_without_pose_or_history_change","body_hex":_body.hex_encode(),"globals":_globals.duplicate(true),"source_launch_scheduler_executed":false,"damage_calls":[],"callbacks":[]}
func snapshot()->Dictionary:
	if not is_active() or not _pending.is_empty():return {}
	return _json({"schema":SCHEMA,"version":1,"contract":CONTRACT,"source_sha256":Natural.SOURCE_SHA,"natural_resource_sha256":Natural.DATA_SHA,"binding":_binding.duplicate(true),"body_hex":_body.hex_encode(),"parent_hex":_parent.hex_encode(),"globals":_globals.duplicate(true),"generation":_generation,"last_sequence":_last_sequence,"last_token":_last_token,"last_commit_receipt":_last_receipt.duplicate(true),"phase":_phase,"game_root_hex":_game_root.hex_encode(),"park_witness":_park_witness.duplicate(true)})
func restore(saved:Dictionary)->bool:
	if not _keys(saved,SNAPSHOT_KEYS) or not _plain(saved) or saved.schema!=SCHEMA or not Natural._whole(saved.version,1,1) or saved.contract!=CONTRACT or saved.source_sha256!=Natural.SOURCE_SHA or saved.natural_resource_sha256!=Natural.DATA_SHA or not _hex(saved.body_hex,338) or not _hex(saved.parent_hex,338) or not saved.globals is Dictionary or not saved.binding is Dictionary or not saved.park_witness is Dictionary or saved.phase not in ["free","parked"]:return false
	if not Natural._whole(saved.generation,0,0xffffffff) or not Natural._whole(saved.last_sequence,0,0xffffffff) or int(saved.generation)!=int(saved.last_sequence) or (int(saved.generation)==0 and saved.last_token!="") or (int(saved.generation)>0 and not _hex(saved.last_token,32)):return false
	if not _hex(saved.game_root_hex,Park.ROOT_BYTES):return false
	if not saved.last_commit_receipt is Dictionary:return false
	var receipt:Dictionary=saved.last_commit_receipt
	if int(saved.generation)==0:
		if not receipt.is_empty():return false
	else:
		if not _keys(receipt,["token","generation","sequence","interval_receipt_sha256","commands_sha256","transition_sha256"]) or receipt.token!=saved.last_token or not Natural._whole(receipt.generation,0,0xffffffff) or int(receipt.generation)+1!=int(saved.generation) or not Natural._whole(receipt.sequence,1,0xffffffff) or int(receipt.sequence)!=int(saved.last_sequence):return false
		for key:String in ["interval_receipt_sha256","commands_sha256","transition_sha256"]:
			if not _hex(receipt[key],32):return false
	var body:=str(saved.body_hex).hex_decode();var parent:=str(saved.parent_hex).hex_decode();var history:=_history(saved.globals)
	if history.is_empty() or not _operands_valid(body,parent,_relative(body)) or not _binding_valid(saved.binding,parent):return false
	if not _isolated_root_valid(str(saved.game_root_hex).hex_decode(),parent,saved.phase=="parked"):return false
	if saved.phase=="parked":
		var park:Dictionary=saved.park_witness
		if not _keys(park,["contact","game_root_before_hex","game_root_after_hex","park_context","body_after_park_hex","callbacks"]) or not park.contact is Dictionary or not park.park_context is Dictionary or not park.callbacks is Array or not _hex(park.game_root_before_hex,Park.ROOT_BYTES) or not _hex(park.game_root_after_hex,Park.ROOT_BYTES) or not _hex(park.body_after_park_hex,338):return false
		var witness:Dictionary=park.contact
		if not _hex(witness.get("body_after_hex"),338):return false
		var before_park:=str(witness.body_after_hex).hex_decode()
		if not _replay_witness(witness,before_park,parent,history,saved.binding) or park.park_context.get("collision_flags_u8")!=history.collision_flags_u8 or park.park_context.get("reference_policy")!="isolated-parent-reference-word-v1" or park.park_context.get("source_flags_8860_u8")!=0 or park.park_context.get("control_8918_s32")!=0 or not _isolated_root_valid(str(park.game_root_before_hex).hex_decode(),parent):return false
		var reset:=Park.accept(before_park,parent,str(park.game_root_before_hex).hex_decode(),park.park_context)
		if not reset.ok or reset.body_after!=body or park.body_after_park_hex!=body.hex_encode() or reset.game_root_after.hex_encode()!=saved.game_root_hex or park.game_root_after_hex!=saved.game_root_hex or _json({"callbacks":reset.callbacks})!=_json({"callbacks":park.callbacks}):return false
		if int(witness.generation)+1!=int(saved.generation) or int(witness.request.sequence)!=int(saved.last_sequence):return false
		var token_input:=witness.duplicate(true)
		for key:String in ["caller_globals","body_after_hex","globals_after"]:token_input.erase(key)
		if _hash(token_input)!=saved.last_token or _hash(witness)!=receipt.transition_sha256 or _hash(witness.request.interval_receipt)!=receipt.interval_receipt_sha256:return false
	elif not saved.park_witness.is_empty():return false
	_body=body;_parent=parent;_globals=history;_binding=_json(saved.binding);_generation=int(saved.generation);_last_sequence=int(saved.last_sequence);_last_token=str(saved.last_token);_last_receipt=_json(receipt);_phase=str(saved.phase);_park_witness=_json(saved.park_witness);_last_transition=_park_witness.contact.duplicate(true) if _phase=="parked" else {};_last_accepted=_phase=="parked";_pending={};_game_root=str(saved.game_root_hex).hex_decode();_park_context=_park_witness.park_context.duplicate(true) if _phase=="parked" else {};_park_callbacks=_park_witness.callbacks.duplicate(true) if _phase=="parked" else []
	if not _park_context.is_empty():_park_context.control_8918_s32=0
	return true
