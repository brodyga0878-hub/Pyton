extends RefCounted
# Raw frame/angular/clock owner with original player preparation and drift
# callbacks. A requested F606 executes at its real boundary before thrust.
# Explicit callbacks do not replace the full F1019/world/player scheduler.
const Bank=preload("res://scripts/source_reference_bank.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const Angular=preload("res://scripts/source_angular_motion.gd")
const Player=preload("res://scripts/source_player_dispatch.gd")
const SCHEMA:="starfrontier-source-flight-state-v1"
const PROFILE:="dos-firstenc-explicit-raw-flight-owner-v1"
const CORE_KEYS:=["reference_bank","clock_pipeline","angular_globals"]
const SAVE_KEYS:=["schema","version","profile","generation","core","last_witness","snapshot_sha256"]
const MAX_GENERATION:=100000000
var _bank:RefCounted
var _clock:RefCounted
var _angular:Dictionary={}
var _player_globals:Dictionary={}
var _generation:=0
var _last_witness:Dictionary={}
var _revision:=0

static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"event_effects_applied":false,"full_original_player_dispatcher":false}
static func _sha(raw:PackedByteArray)->String:
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(raw);return digest.finish().hex_encode()
static func _core_objects(core:Variant)->Dictionary:
	if not core is Dictionary:return {}
	var keys:Array=CORE_KEYS.duplicate()
	if core.has("player_dispatch_globals"):keys.append("player_dispatch_globals")
	if not Clock._keys(core,keys) or not Angular._globals(core.angular_globals):return {}
	var bank:=Bank.new();var clock:=Clock.new()
	if not bank.restore(core.reference_bank) or not clock.restore(core.clock_pipeline):return {}
	var raw_clock:Dictionary=clock.raw_state();var bank_clock:Dictionary=bank.raw_clock()
	if int(raw_clock.clock_low_u32)!=int(bank_clock.tick_u32) or int(raw_clock.clock_day_u32)!=int(bank_clock.day_u32) or int(core.angular_globals.player_index_u32)!=int(bank.raw_player()[0x86]):return {}
	var player_globals:Dictionary={}
	if core.has("player_dispatch_globals"):
		if not Player._globals(core.player_dispatch_globals) or int(core.player_dispatch_globals.player_index_u32)!=int(core.angular_globals.player_index_u32) or int(core.player_dispatch_globals.player_roll_s16)!=int(core.angular_globals.player_roll_s16) or int(core.player_dispatch_globals.frame_ticks_u32)!=int(raw_clock.frame_ticks_u32):return {}
		player_globals=Player._copy_globals(core.player_dispatch_globals)
	return {"bank":bank,"clock":clock,"angular":{"player_index_u32":int(core.angular_globals.player_index_u32),"player_roll_s16":int(core.angular_globals.player_roll_s16)},"player_globals":player_globals}
static func _valid_payload(operation:String,payload:Variant)->bool:
	if not payload is Dictionary:return false
	match operation:
		"clock":return Clock._keys(payload,["accelerated_ticks_u32","system_ticks_u32"]) and Clock._whole(payload.accelerated_ticks_u32) and Clock._whole(payload.system_ticks_u32)
		"angular":return Clock._keys(payload,["budget_s32","accumulate","elapsed_ticks_s32"]) and Angular._whole(payload.budget_s32,-0x80000000,0x7fffffff) and payload.accumulate is bool and Angular._whole(payload.elapsed_ticks_s32,-0x80000000,0x7fffffff)
		"frame":return Clock._keys(payload,["action","target_index","source_frame_byte"]) and payload.action is String and payload.action in ["select","enter_parent","leave_parent"] and Clock._whole(payload.target_index,114) and Clock._whole(payload.source_frame_byte,255)
		"player":return Clock._keys(payload,["operation","globals","source_frame_byte"]) and payload.operation is String and payload.operation in Player.OPERATIONS and Player._globals(payload.globals) and Clock._whole(payload.source_frame_byte,255)
	return false
static func _valid_requests(value:Variant)->bool:
	if not value is Array or value.size()>2:return false
	for row:Variant in value:
		if not row is Dictionary or not row.get("kind") is String:return false
		if row.kind=="F606":
			if not Clock._keys(row,["kind","body_hex_at_call"]) or not Bank._hex(row.body_hex_at_call,Bank.OBJECT_BYTES):return false
		elif row.kind=="F1910":
			if not Clock._keys(row,["kind","args"]) or not row.args is Array or row.args.size()!=3:return false
			for index in range(3):
				if not Clock._whole(row.args[index]) or int(row.args[index])!=[3,1,300][index]:return false
		else:return false
	return true
static func _valid_receipt(value:Variant)->bool:
	if not value is Dictionary:return false
	var keys:Array=["operation","generation_after","events","raw_player_before_sha256","event_effects_applied","si_roundtrip","F1418_executed","full_original_player_dispatcher","source_frame_cache_policy","celestial_F866_advanced"]
	if value.get("operation")=="player":keys.append_array(["player_callback","F606_executed","source_order","callback_requests_sha256","player_globals_after_sha256"])
	if not Clock._keys(value,keys):return false
	if not value.operation is String or value.operation not in ["clock","angular","frame","player"] or not Clock._whole(value.generation_after,MAX_GENERATION) or not Bank._hex(value.raw_player_before_sha256,32) or value.source_frame_cache_policy!="raw-stamps-preserved-caller-owns-DATA008811" or not value.events is Array or value.events.size()>3:return false
	if value.operation=="player":
		if not value.player_callback is String or value.player_callback not in Player.OPERATIONS or not value.F606_executed is bool or not Bank._hex(value.callback_requests_sha256,32) or not Bank._hex(value.player_globals_after_sha256,32) or not value.source_order is Array or value.source_order.size()>16:return false
		for name:Variant in value.source_order:
			if not name is String or name not in ["F1041","F585","F603","F609","F606","F1043","F607","F599","F1044","F1045","F1512"]:return false
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
func player_globals()->Dictionary:return _player_globals.duplicate(true)
func _core()->Dictionary:
	if not is_active():return {}
	var result:Dictionary={"reference_bank":_bank.snapshot(),"clock_pipeline":_clock.snapshot(),"angular_globals":_angular.duplicate(true)}
	if not _player_globals.is_empty():result.player_dispatch_globals=_player_globals.duplicate(true)
	return result
func configure(reference_bank:Variant,clock_pipeline:Variant,angular_globals_value:Variant,player_globals_value:Variant=null)->bool:
	var core:Dictionary={"reference_bank":reference_bank,"clock_pipeline":clock_pipeline,"angular_globals":angular_globals_value}
	if player_globals_value!=null:core.player_dispatch_globals=player_globals_value
	var objects:=_core_objects(core)
	if objects.is_empty():return false
	_bank=objects.bank;_clock=objects.clock;_angular=objects.angular;_player_globals=objects.player_globals;_generation=0;_last_witness={};_revision+=1;return true
func _prepare(operation:String,payload:Variant)->Dictionary:
	if not is_active() or _generation>=MAX_GENERATION or not _valid_payload(operation,payload):return _reject("invalid_raw_flight_command")
	var before_core:=_core();var cloned:=_core_objects(before_core)
	if cloned.is_empty():return _reject("raw_flight_owner_inconsistent")
	var candidate_bank:RefCounted=cloned.bank
	var candidate_clock:RefCounted=cloned.clock
	var candidate_angular:Dictionary=cloned.angular
	var candidate_player_globals:Dictionary=cloned.player_globals
	var prepared:Dictionary={};var events:Array=[];var player_result:Dictionary={};var frame_executed:=false
	match operation:
		"clock":
			var admitted:Dictionary=candidate_clock.prepare(payload.accelerated_ticks_u32,payload.system_ticks_u32)
			if not admitted.get("ok",false):return _reject("raw_clock_admission_rejected")
			candidate_clock=admitted.candidate_clock
			var time:Dictionary=candidate_clock.raw_state()
			if not candidate_player_globals.is_empty():candidate_player_globals.frame_ticks_u32=int(time.frame_ticks_u32)
			prepared=candidate_bank.prepare_rebind(candidate_bank.raw_player(),{"tick_u32":int(time.clock_low_u32),"day_u32":int(time.clock_day_u32)})
			events=admitted.events.duplicate(true)
		"angular":
			var turned:=Angular.step_raw(candidate_bank.raw_player(),payload.budget_s32,payload.accumulate,payload.elapsed_ticks_s32,candidate_angular)
			if not turned.get("ok",false):return _reject("raw_angular_step_rejected")
			candidate_angular=turned.globals_after.duplicate(true)
			if not candidate_player_globals.is_empty():candidate_player_globals.player_roll_s16=int(candidate_angular.player_roll_s16)
			prepared=candidate_bank.prepare_rebind(turned.body_after,candidate_bank.raw_clock())
		"frame":
			prepared=candidate_bank.prepare_select(payload.source_frame_byte) if payload.action=="select" else candidate_bank.prepare_transition(payload.action,payload.target_index)
			if prepared.get("ok",false):events=prepared.events.duplicate(true)
		"player":
			var control:Dictionary=payload.globals
			if int(control.player_index_u32)!=int(_angular.player_index_u32) or int(control.player_roll_s16)!=int(_angular.player_roll_s16) or int(control.frame_ticks_u32)!=int(candidate_clock.raw_state().frame_ticks_u32):return _reject("player_callback_owner_mismatch")
			var original_body:PackedByteArray=candidate_bank.raw_player()
			var parent:PackedByteArray=original_body
			var frame_response:Variant=null
			if payload.operation=="prepare_f1041":
				if int(control.frame_ticks_u32)!=int(candidate_clock.raw_state().frame_ticks_u32):return _reject("player_callback_raw_interval_mismatch")
				# F603 returns before reading a parent when body+56 is zero.
				# The typed placeholder is unused; no physical parent is created.
				if int(original_body[0x56])!=0:
					parent=candidate_bank.raw_object(int(original_body[0x56]))
					if parent.size()!=Bank.OBJECT_BYTES:return _reject("player_callback_parent_record_unavailable")
				var prefix:=Player.prefix_f1041(original_body,parent,control)
				if not prefix.get("ok",false):return _reject("player_prefix_rejected")
				if prefix.frame_selection_requested:
					var at_boundary:Dictionary=candidate_bank.prepare_rebind(prefix.body_after,candidate_bank.raw_clock())
					if not at_boundary.get("ok",false):return _reject("player_frame_boundary_rebind_rejected")
					var selected:Dictionary=at_boundary.candidate_bank.prepare_select(payload.source_frame_byte)
					if not selected.get("ok",false):return _reject("player_F606_rejected")
					candidate_bank=selected.candidate_bank;frame_response=candidate_bank.raw_player();events=selected.events.duplicate(true);frame_executed=true
			player_result=Player.execute(payload.operation,original_body,parent,control,frame_response)
			if not player_result.get("ok",false):return _reject("player_callback_rejected")
			candidate_angular={"player_index_u32":int(player_result.globals_after.player_index_u32),"player_roll_s16":int(player_result.globals_after.player_roll_s16)}
			candidate_player_globals=Player._copy_globals(player_result.globals_after)
			prepared=candidate_bank.prepare_rebind(player_result.body_after,candidate_bank.raw_clock())
	if not prepared.get("ok",false):return _reject("raw_reference_transaction_rejected")
	candidate_bank=prepared.candidate_bank
	var candidate=get_script().new()
	candidate._bank=candidate_bank;candidate._clock=candidate_clock;candidate._angular=candidate_angular.duplicate(true);candidate._player_globals=candidate_player_globals.duplicate(true);candidate._generation=_generation+1
	candidate._last_witness={"before_generation":_generation,"before_core":before_core,"operation":operation,"payload":payload.duplicate(true)}
	var receipt:Dictionary={"operation":operation,"generation_after":candidate._generation,"events":events.duplicate(true),"raw_player_before_sha256":_sha(_bank.raw_player()),"event_effects_applied":false,"si_roundtrip":false,"F1418_executed":false,"full_original_player_dispatcher":false,"source_frame_cache_policy":"raw-stamps-preserved-caller-owns-DATA008811","celestial_F866_advanced":false}
	var result:Dictionary={"ok":true,"profile":PROFILE,"candidate_state":candidate,"owner_instance_id":get_instance_id(),"owner_revision":_revision,"before_generation":_generation,"before_core_sha256":Clock._hash(before_core),"receipt":receipt}
	if operation=="player":
		receipt.player_callback=payload.operation;receipt.F606_executed=frame_executed;receipt.source_order=player_result.source_order.duplicate();receipt.callback_requests_sha256=Clock._hash({"requests":player_result.requests});receipt.player_globals_after_sha256=Clock._hash(candidate_player_globals)
		result.callback_requests=player_result.requests.duplicate(true)
		result.player_globals_after=candidate_player_globals.duplicate(true)
	return result
func prepare_clock(accelerated_ticks:Variant,system_ticks:Variant)->Dictionary:
	return _prepare("clock",{"accelerated_ticks_u32":accelerated_ticks,"system_ticks_u32":system_ticks})
func prepare_angular(budget:Variant,accumulate:Variant,elapsed_ticks:Variant)->Dictionary:
	return _prepare("angular",{"budget_s32":budget,"accumulate":accumulate,"elapsed_ticks_s32":elapsed_ticks})
func prepare_frame(action:Variant,target_index:Variant=0,source_frame_byte:Variant=1)->Dictionary:
	return _prepare("frame",{"action":action,"target_index":target_index,"source_frame_byte":source_frame_byte})
func prepare_player(operation:Variant,globals:Variant,source_frame_byte:Variant=1)->Dictionary:
	return _prepare("player",{"operation":operation,"globals":globals,"source_frame_byte":source_frame_byte})
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
	if verified._last_witness.operation=="player" and (not _valid_requests(prepared.get("callback_requests")) or Clock._hash({"requests":prepared.callback_requests})!=Clock._hash({"requests":expected.callback_requests})):return false
	if verified._last_witness.operation=="player" and (not Player._globals(prepared.get("player_globals_after")) or Clock._hash(prepared.player_globals_after)!=Clock._hash(expected.player_globals_after)):return false
	_bank=verified._bank;_clock=verified._clock;_angular=verified._angular.duplicate(true);_player_globals=verified._player_globals.duplicate(true);_generation=verified._generation;_last_witness=verified._last_witness.duplicate(true);_revision+=1;return true
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
		var replay=get_script().new();replay._bank=before.bank;replay._clock=before.clock;replay._angular=before.angular;replay._player_globals=before.player_globals;replay._generation=int(witness.before_generation)
		var next:Dictionary=replay._prepare(witness.operation,witness.payload)
		if not next.get("ok",false) or Clock._hash(next.candidate_state._core())!=Clock._hash(data.core):return false
	var unsigned:Dictionary=data.duplicate(true);unsigned.erase("snapshot_sha256")
	if not data.snapshot_sha256 is String or data.snapshot_sha256!=Clock._hash(unsigned):return false
	_bank=objects.bank;_clock=objects.clock;_angular=objects.angular;_player_globals=objects.player_globals;_generation=int(data.generation);_last_witness=witness.duplicate(true);_revision+=1;return true
