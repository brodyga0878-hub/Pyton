extends RefCounted
# Explicit raw-player control owner. This is not Main or the whole world loop.
# F1009 chooses the actual mode; supported F1019/F1021 phases replay matched
# boundaries and invoke real raw input/contact kernels at their original sites.
# Unimplemented callbacks require supplied observations and are never guessed.
const Context=preload("res://scripts/source_player_context.gd")
const Mode=preload("res://scripts/source_player_mode.gd")
const RawInput=preload("res://scripts/source_player_input.gd")
const Phase=preload("res://scripts/source_player_phase.gd")
const Motion=preload("res://scripts/source_player_motion.gd")
const Player=preload("res://scripts/source_player_dispatch.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const Bank=preload("res://scripts/source_reference_bank.gd")
const SCHEMA:="starfrontier-source-player-cycle-state-v1"
const PROFILE:="dos-firstenc-explicit-player-control-owner-v1"
const MAX_GENERATION:=100000000
const EXTERNAL_KEYS:=["frame_ticks_u32","system_frame_ticks_u32","speed_multiplier_u32","forward_key_u8","reverse_key_u8","throttle_key_u8","aux_key1_u8","aux_key2_u8","mouse_buttons_u8","input_gate_s8","spin_xyz_s32","transfer_state_u32","saved_flight_flags_u32","effect_gate_s32","action_a_u32","action_b_u32"]
const PHASE_KEYS:=["frame_ticks_u32","forward_key_u8","reverse_key_u8","spin_xyz_s32","transfer_state_u32","saved_flight_flags_u32","effect_gate_s32"]
var _core:Dictionary={}
var _generation:=0
var _revision:=0
var _witness:Dictionary={}

static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"full_world_scheduler":false,"Main_integrated":false}
static func _pick(value:Dictionary,keys:Array)->Dictionary:
	var result:Dictionary={}
	for key:String in keys:result[key]=value[key]
	return result.duplicate(true)
static func _external(value:Variant)->bool:
	if not value is Dictionary or not Clock._keys(value,EXTERNAL_KEYS):return false
	if not RawInput._globals(_pick(value,RawInput.GLOBAL_KEYS)) or not Player._vector(value.spin_xyz_s32):return false
	for key:String in ["frame_ticks_u32","transfer_state_u32","saved_flight_flags_u32","action_a_u32","action_b_u32"]:
		if not Clock._whole(value[key]):return false
	return Player._whole(value.effect_gate_s32,-0x80000000,0x7fffffff)
static func _valid_core(value:Variant)->bool:
	if not value is Dictionary or not Clock._keys(value,["body_hex","parent_hex","root_hex","external","clock"]) or not Bank._hex(value.body_hex,338) or not Bank._hex(value.parent_hex,338) or not Bank._hex(value.root_hex,Context.ROOT_BYTES) or not _external(value.external) or not Mode._clock(value.clock):return false
	var body:PackedByteArray=str(value.body_hex).hex_decode();var root:PackedByteArray=str(value.root_hex).hex_decode()
	# C8/CC are stable logical object references, never saved host pointers.
	return int(body[0x86])>=1 and int(body[0x86])<=114 and int(root.decode_u32(0xc0))==int(body[0x86]) and int(root.decode_u32(0xc8))==int(body[0x86]) and int(root.decode_u32(0xcc))<=114
static func _json_value(value:Variant)->Variant:
	# Normalise packed arrays before the JSON cold-save boundary.
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
static func _phase_observation(value:Variant)->Dictionary:
	if not value is Dictionary:return {}
	var row:Dictionary=value.duplicate(true)
	for side:String in ["before","after"]:
		if not row.get(side) is Dictionary:return {}
		for key:String in ["body","root"]:
			if not Bank._hex(row[side].get(key),338 if key=="body" else Context.ROOT_BYTES):return {}
			row[side][key]=str(row[side][key]).hex_decode()
	if row.has("collider_body"):
		if not Bank._hex(row.collider_body,338):return {}
		row.collider_body=str(row.collider_body).hex_decode()
	return row
static func _motion_globals(external:Dictionary)->Dictionary:
	return {"effect_gate_s32":external.effect_gate_s32,"sound_mode_s8":external.input_gate_s8,"step_u32":external.frame_ticks_u32}
static func phase_boundary_sha256(before:Dictionary)->String:
	# Portable byte token, independent of a JSON writer's numeric spelling.
	if not before.get("body") is PackedByteArray or before.body.size()!=338 or not Context._root(before.get("root")) or not Phase._external(before.get("external")):return ""
	var raw:PackedByteArray=before.body.duplicate();raw.append_array(before.root)
	var state:Dictionary=before.external
	var cells:Array=[state.frame_ticks_u32,state.forward_key_u8,state.reverse_key_u8,state.spin_xyz_s32[0],state.spin_xyz_s32[1],state.spin_xyz_s32[2],state.transfer_state_u32,state.saved_flight_flags_u32,state.effect_gate_s32]
	var words:=PackedByteArray();words.resize(36)
	for index in range(9):words.encode_u32(index*4,int(cells[index])&0xffffffff)
	raw.append_array(words)
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(raw);return digest.finish().hex_encode()
static func _adopt(core:Dictionary,result:Dictionary,external_field:String,keys:Array)->Dictionary:
	var candidate:Dictionary=core.duplicate(true)
	candidate.body_hex=result.body_after.hex_encode();candidate.root_hex=result.root_after.hex_encode()
	if not external_field.is_empty():
		for key:String in keys:candidate.external[key]=result[external_field][key]
	return candidate
static func _run_phase(core:Dictionary,operation:String,payload:Dictionary)->Dictionary:
	var supplied:Array=payload.phase_observations;var samples:Array=payload.gui_samples;var contacts:Array=payload.contacts
	var trace:Array=[];var cursor:=0;var gui_cursor:=0;var contact_cursor:=0;var extra_requests:Array=[]
	var initial_body:PackedByteArray=str(core.body_hex).hex_decode();var root:PackedByteArray=str(core.root_hex).hex_decode();var parent:PackedByteArray=str(core.parent_hex).hex_decode()
	var external:=_pick(core.external,PHASE_KEYS)
	for attempt in range(65):
		var result:=Phase.execute(operation,initial_body,parent,root,external,trace)
		if result.get("ok",false):
			if cursor!=supplied.size() or gui_cursor!=samples.size() or contact_cursor!=contacts.size():return _reject("unconsumed_player_phase_inputs")
			return {"ok":true,"core":_adopt(core,result,"external_after",PHASE_KEYS),"source_order":result.source_order,"requests":extra_requests,"phase_result":_json_value(result)}
		if not result.get("pending") is Dictionary:return _reject("phase_"+str(result.get("reason","rejected")))
		var pending:Dictionary=result.pending;var kind:String=pending.kind;var row:Dictionary
		var at_boundary:Dictionary=core.external.duplicate(true)
		for key:String in PHASE_KEYS:at_boundary[key]=pending.before.external[key]
		if kind in ["F1037","F1039"]:
			if gui_cursor>=samples.size():return _reject("missing_owned_GUI_sample")
			var sample:Variant=samples[gui_cursor]
			if not sample is Dictionary or not Clock._keys(sample,["kind","before_sha256","gui_u32"]) or sample.kind!=kind or sample.before_sha256!=phase_boundary_sha256(pending.before) or not Clock._whole(sample.gui_u32):return _reject("unmatched_owned_GUI_sample")
			var input_result:=RawInput.execute("throttle_f1037" if kind=="F1037" else "view_f1039",pending.before.body,pending.before.root,_pick(at_boundary,RawInput.GLOBAL_KEYS),int(sample.gui_u32))
			if not input_result.get("ok",false):return _reject("owned_input_rejected")
			row=pending.duplicate(true);row.after={"body":input_result.body_after,"root":input_result.root_after,"external":pending.before.external.duplicate(true)};row.return_u32=0
			extra_requests.append_array(input_result.requests);gui_cursor+=1
		elif kind=="F1033":
			if contact_cursor>=contacts.size():return _reject("missing_owned_contact_observation")
			var contact:Variant=contacts[contact_cursor]
			var motion_result:=Motion.execute("contact_f1033",pending.before.body,pending.before.root,_motion_globals(at_boundary),contact)
			if not motion_result.get("ok",false):return _reject("owned_contact_rejected")
			row=pending.duplicate(true);row.after={"body":motion_result.body_after,"root":motion_result.root_after,"external":pending.before.external.duplicate(true)};row.return_u32=int(motion_result.return_s32)&255
			row.collider_body=str(contact.collider_body_hex).hex_decode();row.collider_index=int(contact.collider_ref_u32)
			extra_requests.append_array(motion_result.requests);contact_cursor+=1
		else:
			if cursor>=supplied.size():return _reject("missing_owned_"+kind+"_observation")
			row=_phase_observation(supplied[cursor]);cursor+=1
			if row.is_empty():return _reject("invalid_owned_phase_observation")
		trace.append(row)
	return _reject("player_phase_boundary_limit")
static func _run_control(core:Dictionary,payload:Dictionary)->Dictionary:
	var trace:Array=[];var cursor:=0;var composed:Dictionary={};var selected:=0
	for attempt in range(6):
		var result:=Mode.execute("control_f1009",str(core.body_hex).hex_decode(),str(core.root_hex).hex_decode(),_pick(core.external,Mode.EXTERNAL_KEYS),core.clock,trace,true)
		if result.get("ok",false):
			if cursor!=payload.mode_observations.size() or composed.is_empty():return _reject("unconsumed_mode_observations_or_missing_phase")
			var after:=_adopt(core,result,"externals_after",Mode.EXTERNAL_KEYS)
			# Merge fields changed inside the actual phase into the same owner.
			for key:String in PHASE_KEYS:
				if key not in Mode.EXTERNAL_KEYS:after.external[key]=composed.core.external[key]
			return {"ok":true,"core":after,"source_order":result.source_order,"phase_source_order":composed.source_order,"selected_function_id_u32":selected,"requests":result.requests,"phase_requests":composed.requests}
		if result.get("pending")!=true:return _reject("mode_"+str(result.get("reason","rejected")))
		var pending:Dictionary=result;var request:Dictionary=pending.request;var row:Dictionary
		if request.kind=="control_phase":
			selected=int(request.function_id_u32)
			var phase_core:Dictionary=core.duplicate(true);phase_core.body_hex=pending.body_before.hex_encode();phase_core.root_hex=pending.root_before.hex_encode()
			for key:String in Mode.EXTERNAL_KEYS:phase_core.external[key]=pending.externals_before[key]
			if selected in [1019,1021]:composed=_run_phase(phase_core,"phase_f%d"%selected,payload)
			elif selected==1044:
				if not payload.phase_observations.is_empty() or not payload.gui_samples.is_empty() or not payload.contacts.is_empty():return _reject("unexpected_drift_phase_inputs")
				var drift:=Player.drift_raw(str(phase_core.body_hex).hex_decode(),Context.player_globals(str(phase_core.root_hex).hex_decode(),phase_core.external),true)
				if not drift.get("ok",false):return _reject("owned_F1044_rejected")
				phase_core.body_hex=drift.body_after.hex_encode();composed={"ok":true,"core":phase_core,"source_order":drift.source_order,"requests":[]}
			else:return _reject("unsupported_owned_control_phase_F%d"%selected)
			if not composed.get("ok",false):return composed
			row={"request":request,"body_before_hex":pending.body_before.hex_encode(),"root_before_hex":pending.root_before.hex_encode(),"externals_before":pending.externals_before,"body_after_hex":composed.core.body_hex,"root_after_hex":composed.core.root_hex,"externals_after":_pick(composed.core.external,Mode.EXTERNAL_KEYS)}
		else:
			if cursor>=payload.mode_observations.size():return _reject("missing_owned_mode_observation")
			row=payload.mode_observations[cursor];cursor+=1
		trace.append(row)
	return _reject("player_mode_boundary_limit")
static func _valid_payload(operation:Variant,payload:Variant)->bool:
	if not operation is String or not payload is Dictionary:return false
	if operation=="control" or operation=="phase":
		var keys:Array=["mode_observations","phase_observations","gui_samples","contacts"]
		if operation=="phase":keys.append("operation")
		if not Clock._keys(payload,keys):return false
		for key:String in ["mode_observations","phase_observations","gui_samples","contacts"]:
			if not payload[key] is Array or payload[key].size()>64:return false
		return operation=="control" or (payload.operation in ["phase_f1019","phase_f1021"] and payload.mode_observations.is_empty())
	if operation=="input":return Clock._keys(payload,["operation","gui_u32","speed_s32"]) and payload.operation in RawInput.OPERATIONS and Clock._whole(payload.gui_u32) and Player._whole(payload.speed_s32,-0x80000000,0x7fffffff)
	if operation=="motion":return Clock._keys(payload,["operation","boundary"]) and payload.operation in Motion.OPERATIONS and payload.boundary is Dictionary
	if operation=="delivery":return Clock._keys(payload,["clock","external"]) and Mode._clock(payload.clock) and _external(payload.external)
	return false
static func _run(core:Dictionary,operation:String,payload:Dictionary)->Dictionary:
	if not _valid_core(core) or not _valid_payload(operation,payload):return _reject("invalid_owned_player_command")
	if operation=="control":return _run_control(core,payload)
	if operation=="phase":return _run_phase(core,str(payload.operation),payload)
	if operation=="delivery":
		# The outer counter/input owner supplies measured words. Collection,
		# F1418 and world time admission are not invented by this control owner.
		var delivered:Dictionary=core.duplicate(true);delivered.clock=payload.clock.duplicate(true);delivered.external=payload.external.duplicate(true)
		return {"ok":true,"core":delivered,"source_order":[],"requests":[],"counter_collection_executed":false}
	var result:Dictionary
	if operation=="input":result=RawInput.execute(payload.operation,str(core.body_hex).hex_decode(),str(core.root_hex).hex_decode(),_pick(core.external,RawInput.GLOBAL_KEYS),payload.gui_u32,payload.speed_s32)
	else:result=Motion.execute(payload.operation,str(core.body_hex).hex_decode(),str(core.root_hex).hex_decode(),_motion_globals(core.external),payload.boundary)
	if not result.get("ok",false):return _reject("owned_kernel_rejected")
	var receipt:Dictionary={"ok":true,"core":_adopt(core,result,"globals_after",RawInput.GLOBAL_KEYS if operation=="input" else []),"source_order":result.source_order,"requests":result.requests}
	if operation=="input":receipt.value_u32=result.value_u32
	else:receipt.return_s32=result.return_s32;receipt.outputs=result.outputs.duplicate(true)
	return receipt
func configure(body:Variant,parent:Variant,root:Variant,external:Variant,clock:Variant)->bool:
	if not body is PackedByteArray or not parent is PackedByteArray or not root is PackedByteArray:return false
	var core:Dictionary={"body_hex":body.hex_encode(),"parent_hex":parent.hex_encode(),"root_hex":root.hex_encode(),"external":_json_value(external),"clock":clock}
	if not _valid_core(core):return false
	_core=core.duplicate(true);_generation=0;_witness={};_revision+=1;return true
func is_active()->bool:return not _core.is_empty()
func raw_core()->Dictionary:return _core.duplicate(true)
func generation()->int:return _generation
func prepare(operation:Variant,payload:Variant)->Dictionary:
	if not is_active() or _generation>=MAX_GENERATION or not _valid_payload(operation,payload):return _reject("invalid_owned_player_command")
	var canonical:Dictionary=_json_value(payload);var result:=_run(_core,str(operation),canonical)
	if not result.get("ok",false) or not _valid_core(result.get("core")):return result if not result.get("ok",false) else _reject("invalid_owned_player_result")
	var candidate=get_script().new();candidate._core=result.core.duplicate(true);candidate._generation=_generation+1
	candidate._witness={"before_generation":_generation,"before_core":_core.duplicate(true),"operation":operation,"payload":canonical.duplicate(true)}
	var receipt:Dictionary=result.duplicate(true);receipt.erase("core");receipt.generation_after=candidate._generation;receipt.profile=PROFILE
	return {"ok":true,"profile":PROFILE,"candidate_state":candidate,"owner_instance_id":get_instance_id(),"owner_revision":_revision,"before_generation":_generation,"before_core_sha256":Clock._hash(_core),"receipt":receipt}
func commit(prepared:Variant)->bool:
	if not prepared is Dictionary or prepared.get("ok")!=true or prepared.get("profile")!=PROFILE or not prepared.get("candidate_state") is RefCounted or not prepared.get("receipt") is Dictionary or prepared.get("owner_instance_id")!=get_instance_id() or prepared.get("owner_revision")!=_revision or prepared.get("before_generation")!=_generation or prepared.get("before_core_sha256")!=Clock._hash(_core):return false
	var candidate:RefCounted=prepared.candidate_state
	if candidate==self or candidate.get_script()!=get_script():return false
	var verified=get_script().new()
	if not verified.restore(candidate.snapshot()) or verified._generation!=_generation+1 or Clock._hash(verified._witness.before_core)!=Clock._hash(_core):return false
	var replay:=prepare(verified._witness.operation,verified._witness.payload)
	if not replay.get("ok",false) or Clock._hash(prepared.get("receipt",{}))!=Clock._hash(replay.receipt):return false
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
		if not Clock._keys(witness,["before_generation","before_core","operation","payload"]) or not Clock._whole(witness.before_generation,MAX_GENERATION-1) or int(witness.before_generation)!=int(data.generation)-1 or not _valid_core(witness.before_core) or not _valid_payload(witness.operation,witness.payload):return false
		var replay:=_run(witness.before_core,witness.operation,witness.payload)
		if not replay.get("ok",false) or Clock._hash(replay.core)!=Clock._hash(data.core):return false
	var unsigned:Dictionary=data.duplicate(true);unsigned.erase("snapshot_sha256")
	if data.snapshot_sha256!=Clock._hash(unsigned):return false
	_core=data.core.duplicate(true);_generation=int(data.generation);_witness=witness.duplicate(true);_revision+=1;return true
