extends RefCounted
# Project one owner into expression, guard and event kernels. A task record and
# its variable bytes occur once in the persisted arena/heap, never twice.
const Expr=preload("res://scripts/source_mission_expression.gd")
const Guards=preload("res://scripts/source_mission_guards.gd")
const Events=preload("res://scripts/source_events.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const PROFILE:="dos-firstenc-mission-services-v1"
const KEYS:=["root","root_tail","bank","event_registers","module_globals","program","ip_u32","module_global_offset_u32","temporary_event_index_s32","scratch_words","arena","tree_root_u32","nodes","next_node_id_u32","task_variables","next_variable_id_u32","definitions","task_slot_u32","program_base_u32","metadata"]
const EXPRESSION_SHARED:=["root","root_tail","bank","event_registers","module_globals","program","ip_u32","module_global_offset_u32","temporary_event_index_s32"]
const MAX_CALLS:=256
const MAX_PAYLOAD_NODES:=262144
const MAX_PAYLOAD_BYTES:=134217728
const ORIGINAL_PROGRAM_BASE:=0x4801c4
const ORIGINAL_PROGRAM_BYTES:=57560
const ORIGINAL_PROGRAM_SHA:="1f06f63f9ddf72abdc9d5c4482b88a8730f468642de7cae09361875daa52ffad"
static func _plain_bounded(value:Variant,depth:int,budget:Array)->bool:
	budget[0]-=1
	if depth>32 or budget[0]<0 or budget[1]<0:return false
	if value==null or value is bool or value is int:return true
	if value is float:return is_finite(value)
	if value is String or value is StringName:
		budget[1]-=str(value).length()*4;return str(value).length()<=262144 and budget[1]>=0
	if value is PackedByteArray:
		budget[1]-=value.size();return value.size()<=65536 and budget[1]>=0
	if value is Array:
		if value.size()>4096:return false
		for item:Variant in value:
			if not _plain_bounded(item,depth+1,budget):return false
		return true
	if value is Dictionary:
		if value.size()>4096:return false
		for key:Variant in value:
			if not (key is String or key is StringName) or not _plain_bounded(key,depth+1,budget) or not _plain_bounded(value[key],depth+1,budget):return false
		return true
	return false
static func _plain(value:Variant)->bool:return _plain_bounded(value,0,[MAX_PAYLOAD_NODES,MAX_PAYLOAD_BYTES])
static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false,"full_mission_VM_executed":false}
static func _copy_context(value:Dictionary)->Dictionary:return value.duplicate(true)
static func _view(value:Dictionary,keys:Array)->Dictionary:
	var result:Dictionary={}
	for key:String in keys:result[key]=value[key].duplicate(true) if value[key] is Dictionary or value[key] is Array else (value[key].duplicate() if value[key] is PackedByteArray else value[key])
	return result
static func _variable_id(value:Dictionary)->int:
	return value.arena.decode_u32(int(value.task_slot_u32)*36+32)
static func _descriptor(value:Dictionary)->int:return value.arena.decode_u32(int(value.task_slot_u32)*36+28)
static func _uses_original_image(value:Dictionary)->bool:return int(value.program_base_u32)==ORIGINAL_PROGRAM_BASE and value.program.size()==ORIGINAL_PROGRAM_BYTES
static func _original_projection(value:Dictionary)->bool:
	# Short synthetic programs are explicit witnesses. A complete DOS image must
	# bind its real module table, descriptors and variable/global projections.
	if not _uses_original_image(value):return true
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(value.program)
	if hash.finish().hex_encode()!=ORIGINAL_PROGRAM_SHA or value.definitions.size()!=105:return false
	for module_index in range(105):
		var key:=str(module_index)
		if not value.definitions.has(key):return false
		var definition:Dictionary=value.definitions[key]
		var reference:int=value.program.decode_u32(57140+module_index*4);var at:=reference-ORIGINAL_PROGRAM_BASE
		if int(definition.descriptor_ref_u32)!=reference or int(definition.variable_words_u32)!=value.program.decode_u32(at+16):return false
		var cleanup:int=value.program.decode_s32(at+12);var instruction:=0
		if cleanup>=0:
			var block:int=value.program.decode_u32(at+28+cleanup*4)-ORIGINAL_PROGRAM_BASE
			instruction=value.program.decode_u32(block)
		if int(definition.cleanup_instruction_u32)!=instruction:return false
	var task:=int(value.task_slot_u32)*36;var module_index:int=value.arena.decode_u32(task+24)
	if module_index>104:return false
	var reference:int=value.program.decode_u32(57140+module_index*4)
	if _descriptor(value)!=reference:return false
	var at:=reference-ORIGINAL_PROGRAM_BASE;var global_reference:int=value.program.decode_u32(at+20)
	var expected_global:=0xffffffff if global_reference==0 else global_reference-0x60bde0
	if int(value.module_global_offset_u32)!=expected_global or value.task_variables[str(_variable_id(value))].size()!=value.program.decode_u32(at+16)*4:return false
	return true
static func expression_view(value:Dictionary)->Dictionary:
	var result:=_view(value,EXPRESSION_SHARED);var key:=str(_variable_id(value))
	if not value.task_variables.has(key):return {}
	result["task_variables"]=value.task_variables[key].duplicate();return result
static func guard_view(value:Dictionary)->Dictionary:
	var result:=_view(value,["event_registers","program","program_base_u32","ip_u32","task_slot_u32","metadata"])
	var at:=int(value.task_slot_u32)*36;result["task_record"]=value.arena.slice(at,at+36);return result
static func _context(value:Variant)->bool:
	if not Events._keys(value,KEYS) or not _plain(value) or not Frame._whole(value.task_slot_u32,0,149) or not Events._context(_view(value,Events.CONTEXT_KEYS)):return false
	var projected:=expression_view(value)
	if projected.is_empty() or not Expr._context(projected) or not Guards._context(guard_view(value)):return false
	# A source cleanup-less module cannot enter F54's state5 cleanup path.
	for index in range(150):
		var at:=index*36
		if value.arena.decode_u32(at)==5:
			var module_key:=str(value.arena.decode_u32(at+24))
			if not value.definitions.has(module_key) or int(value.definitions[module_key].cleanup_instruction_u32)==0:return false
	return _original_projection(value)
static func decode_context(value:Variant)->Dictionary:
	if not Events._keys(value,KEYS) or not _plain(value):return {}
	var result:Dictionary=value.duplicate(true);var event:=Events.decode_context(_view(result,Events.CONTEXT_KEYS))
	if event.is_empty():return {}
	for key:String in event:result[key]=event[key]
	for key:String in ["root_tail","module_globals","program","metadata"]:
		var raw:Variant=result[key]
		if raw is String and raw.length()%2==0 and Frame._hex(raw,raw.length()/2):result[key]=str(raw).hex_decode()
	return _copy_context(result) if _context(result) else {}
static func bind_views(expression:Variant,events:Variant,guards:Variant)->Dictionary:
	if not Expr._context(expression) or not Events._context(events) or not Guards._context(guards):return _reject("invalid_mission_owner_views")
	var result:=_view(expression,EXPRESSION_SHARED)
	for key:String in Events.CONTEXT_KEYS:
		if result.has(key) and result[key]!=events[key]:return _reject("shared_mission_owner_mismatch")
		result[key]=events[key].duplicate(true) if events[key] is Dictionary or events[key] is Array else (events[key].duplicate() if events[key] is PackedByteArray else events[key])
	for key:String in ["task_slot_u32","program_base_u32","metadata"]:result[key]=guards[key].duplicate() if guards[key] is PackedByteArray else guards[key]
	if not _context(result) or not Expr._same_context(expression_view(result),expression) or not Guards._same_context(guard_view(result),guards):return _reject("inconsistent_mission_owner_views")
	return {"ok":true,"context":result,"original_resource_projection_verified":_uses_original_image(result),"Main_integrated":false}
static func _merge_expression(base:Dictionary,view:Dictionary)->Dictionary:
	var result:=_copy_context(base)
	for key:String in EXPRESSION_SHARED:result[key]=view[key].duplicate() if view[key] is PackedByteArray else view[key]
	result.task_variables[str(_variable_id(base))]=view.task_variables.duplicate();return result
static func _merge_guard(base:Dictionary,view:Dictionary)->Dictionary:
	var result:=_copy_context(base)
	for key:String in ["event_registers","program","program_base_u32","ip_u32","task_slot_u32","metadata"]:result[key]=view[key].duplicate() if view[key] is PackedByteArray else view[key]
	var at:=int(result.task_slot_u32)*36
	for index in range(36):result.arena[at+index]=view.task_record[index]
	return result
static func _merge_events(base:Dictionary,view:Dictionary)->Dictionary:
	var result:=_copy_context(base)
	for key:String in Events.CONTEXT_KEYS:result[key]=view[key].duplicate(true) if view[key] is Dictionary or view[key] is Array else (view[key].duplicate() if view[key] is PackedByteArray else view[key])
	return result
static func _packets(value:Variant)->bool:
	if not value is Array or value.size()>MAX_CALLS:return false
	for packet:Variant in value:
		if not Events._keys(packet,["call_index_u32","observations"]) or not Frame._whole(packet.call_index_u32,0,MAX_CALLS-1) or not packet.observations is Array:return false
	return true
static func _failed(stage:String,result:Dictionary)->Dictionary:
	var failed:=_reject(stage+"_"+str(result.get("reason","rejected")));failed["service_stage"]=stage
	if result.get("pending") is Dictionary:failed["pending"]=result.pending.duplicate(true)
	return failed
static func _dependency_failed(stage:String,result:Dictionary,index:int,caller:Dictionary)->Dictionary:
	var failed:=_failed(stage,result);failed["dependency_call_index_u32"]=index;failed["caller_pending"]=caller.duplicate(true);return failed
static func execute(context:Variant,command:Variant,observations:Variant=[],dependency_packets:Variant=[])->Dictionary:
	if not _context(context) or not Events._keys(command,["kind","operation","args"]) or command.kind not in ["expression","guards"] or not observations is Array or observations.size()>256 or not _packets(dependency_packets) or not _plain(command) or not _plain(observations) or not _plain(dependency_packets):return _reject("invalid_mission_services_command")
	var kind:String=command.kind;var state:=_copy_context(context);var trace:Array=[];var calls:Array=[];var used:=0;var packet_used:=0
	var selected_id:=_variable_id(state)
	var selected_descriptor:=_descriptor(state)
	var decoded:Variant=Expr.decode_observations(observations)
	if decoded==null:return _reject("invalid_mission_service_observations")
	var initial:=expression_view(state) if kind=="expression" else guard_view(state)
	var result:Dictionary={}
	for attempt in range(MAX_CALLS+1):
		result=Expr.execute(initial,command.operation,command.args,trace) if kind=="expression" else Guards.execute(initial,command.operation,command.args,trace)
		if result.get("ok",false):
			if used!=decoded.size() or packet_used!=dependency_packets.size():return _reject("unused_mission_service_observations")
			state=_merge_expression(state,result.context_after) if kind=="expression" else _merge_guard(state,result.context_after)
			break
		if not result.get("pending") is Dictionary:return _failed(kind,result)
		var pending:Dictionary=result.pending
		state=_merge_expression(state,pending.before) if kind=="expression" else _merge_guard(state,pending.before)
		var row:Dictionary={}
		if (kind=="guards" and pending.kind in ["F31","F44","F45","F48"]) or (kind=="expression" and pending.kind=="F48"):
			var replies:Array=[]
			if packet_used<dependency_packets.size() and int(dependency_packets[packet_used].call_index_u32)==calls.size():
				replies=dependency_packets[packet_used].observations;packet_used+=1
			var invoked:Dictionary
			if pending.kind=="F31":
				var expression_replies:Variant=Expr.decode_observations(replies)
				if expression_replies==null:return _reject("invalid_nested_expression_observations")
				invoked=Expr.execute(expression_view(state),"F31",[],expression_replies)
				if not invoked.get("ok",false):return _dependency_failed("expression",invoked,calls.size(),pending)
				state=_merge_expression(state,invoked.context_after)
			else:
				var event_replies:Variant=Events.decode_observations(replies)
				if event_replies==null:return _reject("invalid_nested_registry_observations")
				invoked=Events.execute(_view(state,Events.CONTEXT_KEYS),pending.kind,pending.args,event_replies)
				if not invoked.get("ok",false):return _dependency_failed("events",invoked,calls.size(),pending)
				state=_merge_events(state,invoked.context_after)
			if not _context(state) or _variable_id(state)!=selected_id or _descriptor(state)!=selected_descriptor:return _reject("mission_selection_changed_outside_service_profile")
			calls.append({"kind":pending.kind,"result":invoked.duplicate(true)})
			row={"kind":pending.kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":expression_view(state) if kind=="expression" else guard_view(state),"return_u32":int(invoked.get("return_u32",0)) if pending.kind=="F31" else 0}
			if kind=="expression":row["input_hex"]="";row["output_hex"]=""
		else:
			if used>=decoded.size():return _failed(kind,result)
			row=decoded[used].duplicate(true);used+=1
			if row.kind=="F48":return _reject("observed_F48_cannot_replace_actual_registry")
		trace.append(row)
	if not result.get("ok",false):return _reject("mission_service_profile_limit")
	if not _context(state) or _variable_id(state)!=selected_id or _descriptor(state)!=selected_descriptor:return _reject("invalid_mission_service_result")
	return {"ok":true,"profile":PROFILE,"context_after":state,"service_kind":kind,"source_order":result.source_order.duplicate(),"kernel_result":result,"dependency_calls":calls,"original_resource_projection_verified":_uses_original_image(state),"live_owners_changed":false,"Main_integrated":false,"full_mission_VM_executed":false}
