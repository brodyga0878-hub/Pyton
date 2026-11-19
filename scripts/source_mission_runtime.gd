extends RefCounted
# One persistent owner set, with invocation-local caller/callee cursors. F41 and
# the remaining world services are explicit, frame-bound observations. No world
# statement interpreter or Main integration is claimed by this bounded profile.
const Expr=preload("res://scripts/source_mission_expression.gd")
const Store=preload("res://scripts/source_mission_store.gd")
const Guards=preload("res://scripts/source_mission_guards.gd")
const Tasks=preload("res://scripts/source_mission_task.gd")
const Events=preload("res://scripts/source_events.gd")
const Models=preload("res://scripts/source_mission_models.gd")
const Safe=preload("res://scripts/source_mission_services.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const PROFILE:="dos-firstenc-composed-mission-runtime-v1"
const MASK:=0xffffffff
const KEYS:=["root","root_tail","bank","event_registers","module_globals","program","program_base_u32","metadata","temporary_event_index_s32","scratch_words","arena","tree_root_u32","nodes","next_node_id_u32","task_variables","next_variable_id_u32","definitions","market_records"]
const COMMAND_KEYS:=["kind","operation","args","task_slot_s32","ip_u32"]
const WORLD_KEYS:=["kind","args","task_slot_s32","ip_before_u32","ip_after_u32","before","after","return_u32","input_hex","output_hex"]
const BYTE_COUNTS:={"root":16384,"root_tail":6160,"bank":38986,"event_registers":284,"module_globals":40,"metadata":1088,"scratch_words":32,"arena":5400}
const EXPR_SHARED:=["root","root_tail","bank","event_registers","module_globals","program","temporary_event_index_s32"]
const MAX_CALLS:=256
const MAX_DEPTH:=32
const MAX_STEPS:=2048
static func _whole(value:Variant,low:int,high:int)->bool:return Frame._whole(value,low,high)
static func _view(value:Dictionary,keys:Array)->Dictionary:
	var result:Dictionary={}
	for key:String in keys:result[key]=value[key]
	return result.duplicate(true)
static func _id_key(value:Variant)->bool:return value is String and value.is_valid_int() and str(int(value))==value and _whole(int(value),0,MASK)
static func _context(value:Variant)->bool:
	if not Safe._plain(value) or not Events._keys(value,KEYS):return false
	for key:String in BYTE_COUNTS:
		if not value[key] is PackedByteArray or value[key].size()!=int(BYTE_COUNTS[key]):return false
	if not value.program is PackedByteArray or value.program.is_empty() or value.program.size()>65536 or not _whole(value.program_base_u32,1,MASK) or int(value.program_base_u32)+value.program.size()>0x100000000 or not value.market_records is Dictionary or value.market_records.size()>256:return false
	for key:Variant in value.market_records:
		if not _id_key(key) or not value.market_records[key] is PackedByteArray or value.market_records[key].size()!=308:return false
	if not Events._context(_view(value,Events.CONTEXT_KEYS)) or value.root_tail.decode_u32(0x180c)!=1 or not Expr._body_reference(value.root.decode_u32(0xc8)) or not Expr._body_reference(value.root.decode_u32(0xcc)):return false
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(value.metadata)
	if hash.finish().hex_encode()!=Guards.METADATA_SHA:return false
	# The complete archived image must bind all real descriptors and definitions.
	if int(value.program_base_u32)==Safe.ORIGINAL_PROGRAM_BASE and value.program.size()==Safe.ORIGINAL_PROGRAM_BYTES:
		hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(value.program)
		if hash.finish().hex_encode()!=Safe.ORIGINAL_PROGRAM_SHA or value.definitions.size()!=105:return false
		for module_index in range(105):
			var key:=str(module_index)
			if not value.definitions.has(key):return false
			var definition:Dictionary=value.definitions[key];var reference:int=value.program.decode_u32(57140+module_index*4);var at:=reference-Safe.ORIGINAL_PROGRAM_BASE
			if at<0 or at+32>value.program.size() or int(definition.descriptor_ref_u32)!=reference or int(definition.variable_words_u32)!=value.program.decode_u32(at+16):return false
			var cleanup:int=value.program.decode_s32(at+12);var instruction:=0
			if cleanup>=0:
				if at+28+cleanup*4+4>value.program.size():return false
				var block:int=value.program.decode_u32(at+28+cleanup*4)-Safe.ORIGINAL_PROGRAM_BASE
				if block<0 or block+4>value.program.size():return false
				instruction=value.program.decode_u32(block)
			if int(definition.cleanup_instruction_u32)!=instruction:return false
	return true
static func _copy_context(value:Dictionary)->Dictionary:
	if not _context(value):return {}
	var result:Dictionary=value.duplicate(true);var event:=Events._copy_context(_view(result,Events.CONTEXT_KEYS))
	for key:String in event:result[key]=event[key]
	result.program_base_u32=int(result.program_base_u32)
	return result
static func decode_context(value:Variant)->Dictionary:
	if not Safe._plain(value) or not Events._keys(value,KEYS):return {}
	var result:Dictionary=value.duplicate(true)
	for key:String in BYTE_COUNTS:
		if result[key] is String and Frame._hex(result[key],int(BYTE_COUNTS[key])):result[key]=str(result[key]).hex_decode()
	if result.program is String and result.program.length()%2==0 and result.program.length()<=131072 and Frame._hex(result.program,result.program.length()/2):result.program=str(result.program).hex_decode()
	if not result.task_variables is Dictionary or not result.market_records is Dictionary:return {}
	for field:String in ["task_variables","market_records"]:
		for key:Variant in result[field]:
			var raw:Variant=result[field][key]
			if raw is String and raw.length()%2==0 and raw.length()<=2048 and Frame._hex(raw,raw.length()/2):result[field][key]=str(raw).hex_decode()
	return _copy_context(result)
static func _heap_transition(before:Dictionary,after:Dictionary)->bool:
	if before.definitions!=after.definitions or int(after.next_variable_id_u32)<int(before.next_variable_id_u32):return false
	for key:String in before.task_variables:
		if after.task_variables.has(key) and before.task_variables[key].size()!=after.task_variables[key].size():return false
	for key:String in after.task_variables:
		if not before.task_variables.has(key) and int(key)<int(before.next_variable_id_u32):return false
	return true
static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false,"full_mission_VM_executed":false}
static func _command(value:Variant)->bool:
	return Events._keys(value,COMMAND_KEYS) and value.kind in ["expression","store","guards","tasks","events","model"] and value.operation is String and value.args is Array and _whole(value.task_slot_s32,-1,149) and _whole(value.ip_u32,0,MASK)
static func execute(core:Variant,command:Variant,observations:Variant=[])->Dictionary:
	if not Safe._plain(command) or not Safe._plain(observations) or not _context(core) or not _command(command) or not observations is Array or observations.size()>MAX_CALLS:return _reject("invalid_mission_runtime_command")
	var decoded:Array=[]
	for raw:Variant in observations:
		if not raw is Dictionary:return _reject("invalid_mission_runtime_world_observation")
		var keys:=WORLD_KEYS.duplicate()
		if raw.has("registry_actions"):keys.append("registry_actions")
		if not Events._keys(raw,keys) or not raw.kind is String or not raw.args is Array or raw.args.size()>6 or not Expr._words(raw.args,raw.args.size()) or not _whole(raw.task_slot_s32,-1,149) or not _whole(raw.ip_before_u32,0,MASK) or not _whole(raw.ip_after_u32,0,MASK) or not _whole(raw.return_u32,0,MASK) or not raw.input_hex is String or not raw.output_hex is String or (raw.has("registry_actions") and not Events._actions(raw.registry_actions)):return _reject("invalid_mission_runtime_world_observation")
		var row:Dictionary=raw.duplicate(true);row.before=decode_context(raw.before);row.after=decode_context(raw.after)
		for key:String in ["task_slot_s32","ip_before_u32","ip_after_u32","return_u32"]:row[key]=int(row[key])
		for index in range(row.args.size()):row.args[index]=int(row.args[index])
		if row.has("registry_actions"):
			for action:Dictionary in row.registry_actions:
				for index in range(action.args.size()):action.args[index]=int(action.args[index])
		if row.before.is_empty() or row.after.is_empty():return _reject("invalid_mission_runtime_world_context")
		decoded.append(row)
	var runner:=Session.new();runner.core=_copy_context(core);runner.observations=decoded
	var result:=runner.invoke(command.kind,command.operation,command.args,int(command.task_slot_s32),int(command.ip_u32))
	if not result.get("ok",false):return result
	if runner.used!=decoded.size():return _reject("unused_mission_runtime_world_observations")
	return {"ok":true,"profile":PROFILE,"context_after":_copy_context(runner.core),"kernel_result":result.kernel_result,"cursor_after_u32":int(result.cursor_after_u32),"return_u32":int(result.return_u32),"return_defined":bool(result.return_defined),"source_order":result.source_order,"dependency_calls":runner.calls.duplicate(true),"world_observations_used":runner.used,"callback_ownership_profile":"monotonic_logical_heap_and_actual_registry_journal","dangling_outer_projection_rejected":true,"live_owners_changed":false,"Main_integrated":false,"full_mission_VM_executed":false}

# Only callback ownership differs from the frozen Events runner. All event tree,
# allocator, dispatch, scheduling and cleanup bodies are inherited unchanged.
class RuntimeEvents extends Events.Events:
	func boundary(kind:String,args:Array)->bool:
		order.append(kind);var pending:Dictionary={"kind":kind,"args":args.duplicate(),"before":host()._copy_context(context)}
		if used>=observations.size():fail("boundary_required");stopped["pending"]=pending;return false
		var row:Variant=observations[used]
		if not host()._observation(row) or row.kind!=kind or not same_args(row.args,args) or not host()._same_context(row.before,pending.before):return fail("unmatched_source_events_observation")
		var after:Dictionary=host()._copy_context(row.after)
		if not load("res://scripts/source_mission_runtime.gd")._heap_transition(context,after):return fail("callback_changed_heap_outside_monotonic_profile")
		for key:String in host().BYTE_COUNTS:context[key]=after[key].duplicate()
		context.temporary_event_index_s32=int(after.temporary_event_index_s32);context.task_variables=after.task_variables.duplicate(true);context.next_variable_id_u32=int(after.next_variable_id_u32)
		var replay_order_start:=order.size()
		for action:Dictionary in row.get("registry_actions",[]):
			if action.operation=="F44":
				if not insert(action.args):return false
			elif action.operation=="F45":remove(action.args)
			else:clear_tree()
			if not stopped.is_empty():return false
		# The journal replays ownership effects; the composed child already owns
		# the actual call order, so transport replay must not count it twice.
		order.resize(replay_order_start)
		if context.tree_root_u32!=after.tree_root_u32 or context.nodes!=after.nodes or context.next_node_id_u32!=after.next_node_id_u32:return fail("callback_registry_result_does_not_match_original_actions")
		requests.append(row.duplicate(true));used+=1;return true

class Session:
	var core:Dictionary
	var observations:Array=[]
	var used:=0
	var depth:=0
	var steps:=0
	var calls:Array=[]
	var registry_journal:Array=[]
	func host()->GDScript:return load("res://scripts/source_mission_runtime.gd")
	func failed(reason:String,pending:Dictionary={})->Dictionary:
		var result:Dictionary=host()._reject(reason)
		if not pending.is_empty():result["pending"]=pending.duplicate(true)
		return result
	func frame_view(kind:String,slot:int,ip:int,frame:Dictionary)->Dictionary:
		if kind=="events":return host()._view(core,Events.CONTEXT_KEYS)
		if kind=="tasks":
			var refs:Dictionary={}
			for key:String in core.definitions:refs[key]=int(core.definitions[key].descriptor_ref_u32)
			return {"arena":core.arena.duplicate(),"program":core.program.duplicate(),"program_base_u32":int(core.program_base_u32),"module_refs":refs,"caller_ip_u32":ip}
		if slot<0 or slot>=150 or ip<0 or ip>core.program.size():return {}
		if kind=="guards":return {"event_registers":core.event_registers.duplicate(),"program":core.program.duplicate(),"program_base_u32":int(core.program_base_u32),"ip_u32":ip,"task_record":core.arena.slice(slot*36,slot*36+36),"task_slot_u32":slot,"metadata":core.metadata.duplicate()}
		var descriptor:int=core.arena.decode_u32(slot*36+28);var at:=descriptor-int(core.program_base_u32);var variable_id:int=core.arena.decode_u32(slot*36+32)
		if at<0 or at+24>core.program.size() or not core.task_variables.has(str(variable_id)):return {}
		var global_ref:int=core.program.decode_u32(at+20);var global_offset:=MASK if global_ref==0 else global_ref-0x60bde0
		var result:Dictionary=host()._view(core,EXPR_SHARED);result["task_variables"]=core.task_variables[str(variable_id)].duplicate();result["ip_u32"]=ip;result["module_global_offset_u32"]=global_offset
		if not Expr._context(result):return {}
		if int(core.program_base_u32)==Safe.ORIGINAL_PROGRAM_BASE and core.program.size()==Safe.ORIGINAL_PROGRAM_BYTES:
			var module_index:int=core.arena.decode_u32(slot*36+24)
			if module_index>104 or descriptor!=core.program.decode_u32(57140+module_index*4) or core.task_variables[str(variable_id)].size()!=core.program.decode_u32(at+16)*4:return {}
		if kind=="store":
			result["task_slot_u32"]=slot;result["descriptor_ref_u32"]=descriptor
			if frame.market_key!="" and core.market_records.has(frame.market_key):result["market_buffer"]=core.market_records[frame.market_key].duplicate()
			else:
				var unused:=PackedByteArray();unused.resize(308);result["market_buffer"]=unused
		return result
	func merge(kind:String,view:Dictionary,slot:int,frame:Dictionary)->bool:
		if kind=="events":
			for key:String in Events.CONTEXT_KEYS:core[key]=view[key].duplicate(true) if view[key] is Dictionary else (view[key].duplicate() if view[key] is PackedByteArray else view[key])
		elif kind=="tasks":core.arena=view.arena.duplicate()
		elif kind=="guards":
			core.event_registers=view.event_registers.duplicate()
			for index in range(36):core.arena[slot*36+index]=view.task_record[index]
		else:
			var identifier:=str(core.arena.decode_u32(slot*36+32))
			if not core.task_variables.has(identifier):return false
			for key:String in EXPR_SHARED:core[key]=view[key].duplicate() if view[key] is PackedByteArray else view[key]
			core.task_variables[identifier]=view.task_variables.duplicate()
			if kind=="store" and frame.market_key!="":core.market_records[frame.market_key]=view.market_buffer.duplicate()
		return host()._context(core)
	func kernel(kind:String,initial:Dictionary,operation:String,args:Array,trace:Array)->Dictionary:
		match kind:
			"expression":return Expr.execute(initial,operation,args,trace)
			"store":
				if operation!="F37" or not Expr._words(args,1):return failed("invalid_store_runtime_operation")
				return Store.execute(initial,args[0],trace)
			"guards":return Guards.execute(initial,operation,args,trace)
			"tasks":return Tasks.execute(initial,operation,args,trace)
			"events":
				if not Events._operation(operation,args):return failed("invalid_events_runtime_operation")
				var runner:=RuntimeEvents.new();runner.context=Events._copy_context(initial);runner.observations=trace.duplicate(true);return runner.run(operation,args)
		return failed("invalid_mission_runtime_kind")
	func model(operation:String,args:Array,ip:int)->Dictionary:
		if operation!="F36" or not Expr._words(args,2) or int(args[0])>114:return failed("invalid_model_runtime_operation")
		var at:=116+int(args[0])*338;var replaced:=Models.replace(core.bank.slice(at,at+338),int(args[1]))
		if not replaced.get("ok",false):return failed("model_"+str(replaced.get("reason","rejected")))
		for index in range(338):core.bank[at+index]=replaced.body_after[index]
		return {"ok":true,"kernel_result":replaced,"cursor_after_u32":ip,"return_u32":0,"return_defined":false,"source_order":replaced.source_order.duplicate()}
	func invoke(kind:String,operation:String,args:Array,slot:int,ip:int)->Dictionary:
		steps+=1;depth+=1
		if depth>MAX_DEPTH or steps>MAX_STEPS or calls.size()>MAX_CALLS:depth-=1;return failed("mission_runtime_composition_profile_limit")
		var result:=invoke_body(kind,operation,args,slot,ip);depth-=1;return result
	func invoke_body(kind:String,operation:String,args:Array,slot:int,ip:int)->Dictionary:
		if kind=="model":return model(operation,args,ip)
		var frame:Dictionary={"market_key":""};var initial:=frame_view(kind,slot,ip,frame)
		if initial.is_empty():return failed("mission_frame_projection_outside_profile")
		var trace:Array=[];var children:Array=[];var cursor:=ip
		for attempt in range(MAX_CALLS+1):
			steps+=1
			if steps>MAX_STEPS:return failed("mission_runtime_composition_profile_limit")
			var result:=kernel(kind,initial,operation,args,trace)
			if result.get("ok",false):
				if not merge(kind,result.context_after,slot,frame):return failed("invalid_composed_mission_result")
				if kind in ["expression","store","guards"]:cursor=int(result.context_after.ip_u32)
				elif kind=="tasks":cursor=int(result.context_after.caller_ip_u32)
				if kind=="events" and operation in ["F44","F45","F50","F56"]:registry_journal.append({"operation":"F50" if operation=="F56" else operation,"args":[] if operation=="F56" else args.duplicate()})
				var expanded:Array=[]
				for index in range(result.source_order.size()):
					expanded.append(result.source_order[index])
					for child:Dictionary in children:
						if int(child.at)==index:
							var order:Array=child.order
							expanded.append_array(order.slice(1) if not order.is_empty() and order[0]==result.source_order[index] else order)
				var returned:=int(result.get("return_u32",0));var defined:=bool(result.get("return_defined",false))
				if kind=="events" and operation=="F51":returned=int(result.allocated_slot_s32)&MASK;defined=true
				return {"ok":true,"kernel_result":result,"cursor_after_u32":cursor,"return_u32":returned,"return_defined":defined,"source_order":expanded}
			if not result.get("pending") is Dictionary:return failed(kind+"_"+str(result.get("reason","rejected")))
			var pending:Dictionary=result.pending
			if not merge(kind,pending.before,slot,frame):return failed("invalid_pending_mission_projection")
			if kind in ["expression","store","guards"]:cursor=int(pending.before.ip_u32)
			var journal_start:=registry_journal.size();var closed:=close(kind,pending,slot,cursor,frame)
			if not closed.get("ok",false):return closed
			var after_cursor:=int(closed.get("cursor_after_u32",cursor));var after_ip:=after_cursor if kind in ["expression","store","guards"] else ip
			if kind=="tasks" and pending.cursor_kind=="caller":after_ip=after_cursor
			elif kind=="tasks":after_ip=int(pending.before.caller_ip_u32)
			var projected:=frame_view(kind,slot,after_ip,frame)
			if projected.is_empty():return failed("dangling_outer_projection_outside_composition_profile")
			var row:Dictionary={"kind":pending.kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":projected,"return_u32":int(closed.get("return_u32",0))}
			if kind in ["expression","store"]:row["input_hex"]=str(closed.get("input_hex",""));row["output_hex"]=str(closed.get("output_hex",""))
			if kind=="tasks":row["cursor_kind"]=pending.cursor_kind;row["cursor_before_u32"]=int(pending.cursor_before_u32);row["cursor_after_u32"]=MASK if pending.cursor_kind=="none" else after_cursor
			if kind=="events":row["registry_actions"]=registry_journal.slice(journal_start)
			trace.append(row)
			children.append({"at":result.source_order.size()-1,"order":closed.get("source_order",[]).duplicate()})
		return failed("mission_runtime_composition_profile_limit")
	func nested(kind:String,operation:String,args:Array,slot:int,ip:int)->Dictionary:
		var index:=calls.size();calls.append({"kind":kind,"operation":operation,"args":args.duplicate(),"task_slot_s32":slot,"ip_u32":ip})
		var result:=invoke(kind,operation,args,slot,ip)
		if result.get("ok",false):calls[index]["return_u32"]=int(result.return_u32);calls[index]["return_defined"]=bool(result.return_defined);calls[index]["cursor_after_u32"]=int(result.cursor_after_u32)
		return result
	func close(parent:String,pending:Dictionary,slot:int,ip:int,frame:Dictionary)->Dictionary:
		var name:String=pending.kind;var args:Array=pending.args
		if parent in ["expression","store","guards"]:
			if name=="F31":return nested("expression","F31",[],slot,ip)
			if name=="F22":return nested("expression","F22",args,slot,ip)
			if name=="F34":return nested("guards","F34",args,slot,ip)
			if name=="F36":return nested("model","F36",args,slot,ip)
			if name in ["F44","F45","F48"]:return nested("events",name,args,slot,ip)
		elif parent=="tasks":
			var target:=int(args[0]);var call_ip:=int(pending.cursor_before_u32)
			if name=="F31":return nested("expression","F31",[],target,call_ip)
			if name=="F37":return nested("store","F37",[int(args[1])],target,call_ip)
			if name=="F33":return nested("guards","F33",["F44" if int(args[1])==44 else "F45"],target,0)
			if name=="F51":return nested("events","F51",args,slot,MASK)
			if name=="F41":return world(name,args,target,call_ip,parent,frame)
		elif parent=="events":
			if name=="event_callback" and int(args[0])==Guards.F47_WORD:
				var token:=int(args[1])-Guards.TASK_BASE
				if token<0 or token%36!=0 or token/36>=150:return failed("event_callback_task_reference_outside_arena")
				return nested("tasks","F47",[token/36,int(args[2])],token/36,MASK)
			if name=="F53":return nested("tasks","F53",[int(args[0])],int(args[0]),MASK)
			if name=="F52":return nested("tasks","F52",[-1,0,0],-1,MASK)
			if name=="F41":
				var local_ip:=int(args[1])-int(core.program_base_u32)
				if local_ip<0 or local_ip>core.program.size():return failed("event_cleanup_cursor_outside_program")
				return world(name,[int(args[0])],int(args[0]),local_ip,parent,frame)
		return world(name,args,slot,ip,parent,frame)
	func world(name:String,args:Array,slot:int,ip:int,parent:String,frame:Dictionary)->Dictionary:
		var pending:Dictionary={"kind":name,"args":args.duplicate(),"task_slot_s32":slot,"ip_before_u32":ip,"before":host()._copy_context(core),"input_hex":""}
		if used>=observations.size():return failed("world_boundary_required",pending)
		var row:Dictionary=observations[used]
		if row.kind!=name or row.args!=args or int(row.task_slot_s32)!=slot or int(row.ip_before_u32)!=ip or row.before!=core or row.input_hex!="":return failed("unmatched_mission_runtime_world_observation",pending)
		if name!="F41" and int(row.ip_after_u32)!=ip:return failed("world_provider_changed_invocation_cursor")
		if name=="F41" and (int(row.return_u32)!=0 or int(row.ip_after_u32)>core.program.size() or row.output_hex!=""):return failed("invalid_F41_statement_continuation")
		if name=="event_callback" and (int(row.return_u32)!=0 or row.output_hex!=""):return failed("invalid_external_event_callback")
		for key:String in ["program","program_base_u32","metadata","definitions"]:
			if row.before[key]!=row.after[key]:return failed("world_provider_changed_readonly_mission_resource")
		if not host()._heap_transition(row.before,row.after):return failed("world_provider_changed_heap_outside_monotonic_profile")
		var tree:Dictionary=host()._view(core,Events.CONTEXT_KEYS);var world_order:Array=[name]
		for action:Dictionary in row.get("registry_actions",[]):
			var replay:=RuntimeEvents.new();replay.context=tree;replay.observations=[];var outcome:=replay.run(action.operation,action.args)
			if not outcome.get("ok",false):return failed("world_registry_action_rejected")
			tree=outcome.context_after;world_order.append_array(outcome.source_order)
		for key:String in ["tree_root_u32","nodes","next_node_id_u32"]:
			if tree[key]!=row.after[key]:return failed("world_registry_result_does_not_match_original_actions")
		# F649 is the sole source binding for a mutable market owner. A zero
		# transport buffer before a successful lookup is never persisted as data.
		if name=="F649" and parent=="store":
			if int(row.return_u32) not in [0,1] or row.output_hex!="":return failed("invalid_store_market_observation")
			var requested:=str(int(args[0]))
			for key:String in row.before.market_records:
				if not row.after.market_records.has(key) or row.before.market_records[key]!=row.after.market_records[key]:return failed("market_lookup_changed_existing_owner")
			for key:String in row.after.market_records:
				if not row.before.market_records.has(key) and (key!=requested or int(row.return_u32)!=1):return failed("market_lookup_bound_unrequested_owner")
			if int(row.return_u32)==1:
				if not row.after.market_records.has(requested):return failed("unbound_source_market_record")
				frame.market_key=requested
			else:frame.market_key=""
		elif name=="F649" and parent=="expression" and int(row.return_u32)==1:
			if not Frame._hex(row.output_hex,308):return failed("invalid_expression_market_snapshot")
			var key:=str(int(args[0]))
			if row.after.market_records!=row.before.market_records or (row.after.market_records.has(key) and row.after.market_records[key]!=row.output_hex.hex_decode()):return failed("expression_market_snapshot_owner_mismatch")
		elif row.after.market_records!=row.before.market_records:return failed("world_provider_changed_unrequested_market_owner")
		core=host()._copy_context(row.after);used+=1
		registry_journal.append_array(row.get("registry_actions",[]).duplicate(true))
		return {"ok":true,"return_u32":int(row.return_u32),"return_defined":true,"cursor_after_u32":int(row.ip_after_u32),"input_hex":row.input_hex,"output_hex":row.output_hex,"source_order":world_order}
