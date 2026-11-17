extends RefCounted
# One raw owner for the independently verified frame, angular and clock
# kernels. Commands remain explicit: their arbitrary composition is not the
# original F570/F1019/F1041 dispatcher or a universal player-flight step.
const Bank=preload("res://scripts/source_reference_bank.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const Angular=preload("res://scripts/source_angular_motion.gd")
const SCHEMA:="starfrontier-source-flight-state-v1"
const PROFILE:="dos-firstenc-explicit-raw-flight-owner-v1"
const CORE_KEYS:=["reference_bank","clock_pipeline","angular_globals"]
const SAVE_KEYS:=["schema","version","profile","generation","core","last_witness","snapshot_sha256"]
const MAX_GENERATION:=100000000
var _bank:RefCounted
var _clock:RefCounted
var _angular:Dictionary={}
var _generation:=0
var _last_witness:Dictionary={}
var _revision:=0

static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"event_effects_applied":false,"full_original_player_dispatcher":false}
static func _sha(raw:PackedByteArray)->String:
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(raw);return digest.finish().hex_encode()
static func _core_objects(core:Variant)->Dictionary:
	if not core is Dictionary or not Clock._keys(core,CORE_KEYS) or not Angular._globals(core.angular_globals):return {}
	var bank:=Bank.new();var clock:=Clock.new()
	if not bank.restore(core.reference_bank) or not clock.restore(core.clock_pipeline):return {}
	var raw_clock:Dictionary=clock.raw_state();var bank_clock:Dictionary=bank.raw_clock()
	if int(raw_clock.clock_low_u32)!=int(bank_clock.tick_u32) or int(raw_clock.clock_day_u32)!=int(bank_clock.day_u32) or int(core.angular_globals.player_index_u32)!=int(bank.raw_player()[0x86]):return {}
	return {"bank":bank,"clock":clock,"angular":{"player_index_u32":int(core.angular_globals.player_index_u32),"player_roll_s16":int(core.angular_globals.player_roll_s16)}}
static func _valid_payload(operation:String,payload:Variant)->bool:
	if not payload is Dictionary:return false
	match operation:
		"clock":return Clock._keys(payload,["accelerated_ticks_u32","system_ticks_u32"]) and Clock._whole(payload.accelerated_ticks_u32) and Clock._whole(payload.system_ticks_u32)
		"angular":return Clock._keys(payload,["budget_s32","accumulate","elapsed_ticks_s32"]) and Angular._whole(payload.budget_s32,-0x80000000,0x7fffffff) and payload.accumulate is bool and Angular._whole(payload.elapsed_ticks_s32,-0x80000000,0x7fffffff)
		"frame":return Clock._keys(payload,["action","target_index","source_frame_byte"]) and payload.action is String and payload.action in ["select","enter_parent","leave_parent"] and Clock._whole(payload.target_index,114) and Clock._whole(payload.source_frame_byte,255)
	return false
static func _valid_receipt(value:Variant)->bool:
	if not value is Dictionary or not Clock._keys(value,["operation","generation_after","events","raw_player_before_sha256","event_effects_applied","si_roundtrip","F1418_executed","full_original_player_dispatcher","source_frame_cache_policy","celestial_F866_advanced"]):return false
	if not value.operation is String or value.operation not in ["clock","angular","frame"] or not Clock._whole(value.generation_after,MAX_GENERATION) or not Bank._hex(value.raw_player_before_sha256,32) or value.source_frame_cache_policy!="raw-stamps-preserved-caller-owns-DATA008811" or not value.events is Array or value.events.size()>3:return false
	for key:String in ["event_effects_applied","si_roundtrip","F1418_executed","full_original_player_dispatcher","celestial_F866_advanced"]:
		if not value[key] is bool or value[key]:return false
	for event:Variant in value.events:
		if not event is Dictionary or not Clock._whole(event.get("event_u32")):return false
		if int(event.event_u32)==11:
			if not Clock._keys(event,["event_u32","param_u32"]) or not Clock._whole(event.param_u32,0):return false
		elif not Clock._valid_events([event]):return false
	return true
func is_active()->bool:return _bank!=null and _clock!=null and _bank.is_active() and _clock.is_active()
func generation()->int:return _generation
func raw_player()->PackedByteArray:return _bank.raw_player() if is_active() else PackedByteArray()
func raw_objects()->Dictionary:return _bank.raw_objects() if is_active() else {}
func raw_clock()->Dictionary:return _clock.raw_state() if is_active() else {}
func angular_globals()->Dictionary:return _angular.duplicate(true)
func _core()->Dictionary:
	return {"reference_bank":_bank.snapshot(),"clock_pipeline":_clock.snapshot(),"angular_globals":_angular.duplicate(true)} if is_active() else {}
func configure(reference_bank:Variant,clock_pipeline:Variant,angular_globals_value:Variant)->bool:
	var objects:=_core_objects({"reference_bank":reference_bank,"clock_pipeline":clock_pipeline,"angular_globals":angular_globals_value})
	if objects.is_empty():return false
	_bank=objects.bank;_clock=objects.clock;_angular=objects.angular;_generation=0;_last_witness={};_revision+=1;return true
func _prepare(operation:String,payload:Variant)->Dictionary:
	if not is_active() or _generation>=MAX_GENERATION or not _valid_payload(operation,payload):return _reject("invalid_raw_flight_command")
	var before_core:=_core();var cloned:=_core_objects(before_core)
	if cloned.is_empty():return _reject("raw_flight_owner_inconsistent")
	var candidate_bank:RefCounted=cloned.bank
	var candidate_clock:RefCounted=cloned.clock
	var candidate_angular:Dictionary=cloned.angular
	var prepared:Dictionary={};var events:Array=[]
	match operation:
		"clock":
			var admitted:Dictionary=candidate_clock.prepare(payload.accelerated_ticks_u32,payload.system_ticks_u32)
			if not admitted.get("ok",false):return _reject("raw_clock_admission_rejected")
			candidate_clock=admitted.candidate_clock
			var time:Dictionary=candidate_clock.raw_state()
			prepared=candidate_bank.prepare_rebind(candidate_bank.raw_player(),{"tick_u32":int(time.clock_low_u32),"day_u32":int(time.clock_day_u32)})
			events=admitted.events.duplicate(true)
		"angular":
			var turned:=Angular.step_raw(candidate_bank.raw_player(),payload.budget_s32,payload.accumulate,payload.elapsed_ticks_s32,candidate_angular)
			if not turned.get("ok",false):return _reject("raw_angular_step_rejected")
			candidate_angular=turned.globals_after.duplicate(true)
			prepared=candidate_bank.prepare_rebind(turned.body_after,candidate_bank.raw_clock())
		"frame":
			prepared=candidate_bank.prepare_select(payload.source_frame_byte) if payload.action=="select" else candidate_bank.prepare_transition(payload.action,payload.target_index)
			if prepared.get("ok",false):events=prepared.events.duplicate(true)
	if not prepared.get("ok",false):return _reject("raw_reference_transaction_rejected")
	candidate_bank=prepared.candidate_bank
	var candidate=get_script().new()
	candidate._bank=candidate_bank;candidate._clock=candidate_clock;candidate._angular=candidate_angular.duplicate(true);candidate._generation=_generation+1
	candidate._last_witness={"before_generation":_generation,"before_core":before_core,"operation":operation,"payload":payload.duplicate(true)}
	return {"ok":true,"profile":PROFILE,"candidate_state":candidate,"owner_instance_id":get_instance_id(),"owner_revision":_revision,"before_generation":_generation,"before_core_sha256":Clock._hash(before_core),"receipt":{"operation":operation,"generation_after":candidate._generation,"events":events.duplicate(true),"raw_player_before_sha256":_sha(_bank.raw_player()),"event_effects_applied":false,"si_roundtrip":false,"F1418_executed":false,"full_original_player_dispatcher":false,"source_frame_cache_policy":"raw-stamps-preserved-caller-owns-DATA008811","celestial_F866_advanced":false}}
func prepare_clock(accelerated_ticks:Variant,system_ticks:Variant)->Dictionary:
	return _prepare("clock",{"accelerated_ticks_u32":accelerated_ticks,"system_ticks_u32":system_ticks})
func prepare_angular(budget:Variant,accumulate:Variant,elapsed_ticks:Variant)->Dictionary:
	return _prepare("angular",{"budget_s32":budget,"accumulate":accumulate,"elapsed_ticks_s32":elapsed_ticks})
func prepare_frame(action:Variant,target_index:Variant=0,source_frame_byte:Variant=1)->Dictionary:
	return _prepare("frame",{"action":action,"target_index":target_index,"source_frame_byte":source_frame_byte})
func commit(prepared:Variant)->bool:
	if not prepared is Dictionary or prepared.get("ok")!=true or prepared.get("profile")!=PROFILE or not prepared.get("candidate_state") is RefCounted or not is_active():return false
	if not prepared.get("owner_instance_id") is int or prepared.owner_instance_id!=get_instance_id() or not prepared.get("owner_revision") is int or prepared.owner_revision!=_revision or not Clock._whole(prepared.get("before_generation"),MAX_GENERATION) or int(prepared.before_generation)!=_generation or prepared.get("before_core_sha256")!=Clock._hash(_core()):return false
	var candidate:RefCounted=prepared.candidate_state
	if candidate==self or candidate.get_script()!=get_script():return false
	var verified=get_script().new()
	if not verified.restore(candidate.snapshot()) or verified._generation!=_generation+1 or Clock._hash(verified._last_witness.before_core)!=Clock._hash(_core()):return false
	if not _valid_receipt(prepared.get("receipt")):return false
	var expected:=_prepare(verified._last_witness.operation,verified._last_witness.payload)
	if not expected.get("ok",false) or Clock._hash(prepared.receipt)!=Clock._hash(expected.receipt):return false
	_bank=verified._bank;_clock=verified._clock;_angular=verified._angular.duplicate(true);_generation=verified._generation;_last_witness=verified._last_witness.duplicate(true);_revision+=1;return true
func snapshot()->Dictionary:
	if not is_active():return {}
	var result:Dictionary={"schema":SCHEMA,"version":1,"profile":PROFILE,"generation":_generation,"core":_core(),"last_witness":_last_witness.duplicate(true)}
	result.snapshot_sha256=Clock._hash(result);return result
func restore(data:Variant)->bool:
	if not data is Dictionary or not Clock._keys(data,SAVE_KEYS) or data.get("schema")!=SCHEMA or not Clock._whole(data.get("version"),1) or int(data.version)!=1 or data.get("profile")!=PROFILE or not Clock._whole(data.get("generation"),MAX_GENERATION) or not data.get("last_witness") is Dictionary:return false
	var objects:=_core_objects(data.get("core"))
	if objects.is_empty():return false
	var witness:Dictionary=data.last_witness
	if int(data.generation)==0:
		if not witness.is_empty():return false
	else:
		if not Clock._keys(witness,["before_generation","before_core","operation","payload"]) or not Clock._whole(witness.get("before_generation"),MAX_GENERATION-1) or int(witness.before_generation)!=int(data.generation)-1 or not witness.operation is String or not _valid_payload(witness.operation,witness.payload):return false
		var before:=_core_objects(witness.before_core)
		if before.is_empty():return false
		var replay=get_script().new();replay._bank=before.bank;replay._clock=before.clock;replay._angular=before.angular;replay._generation=int(witness.before_generation)
		var next:Dictionary=replay._prepare(witness.operation,witness.payload)
		if not next.get("ok",false) or Clock._hash(next.candidate_state._core())!=Clock._hash(data.core):return false
	var unsigned:Dictionary=data.duplicate(true);unsigned.erase("snapshot_sha256")
	if not data.snapshot_sha256 is String or data.snapshot_sha256!=Clock._hash(unsigned):return false
	_bank=objects.bank;_clock=objects.clock;_angular=objects.angular;_generation=int(data.generation);_last_witness=witness.duplicate(true);_revision+=1;return true
