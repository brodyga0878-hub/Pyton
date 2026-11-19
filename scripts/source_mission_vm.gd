extends RefCounted
# New composition over the frozen 0.31 kernels. Every statement invocation has
# an explicit private scratch seed; cursors and retired projections are local.
const Runtime=preload("res://scripts/source_mission_runtime.gd")
const Expr=preload("res://scripts/source_mission_expression.gd")
const Store=preload("res://scripts/source_mission_store.gd")
const Statements=preload("res://scripts/source_mission_statements.gd")
const Spawn=preload("res://scripts/source_mission_spawn.gd")
const Events=preload("res://scripts/source_events.gd")
const Safe=preload("res://scripts/source_mission_services.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const PROFILE:="dos-firstenc-composed-mission-vm-v1"
const MASK:=0xffffffff
const EXTRA_KEYS:=["text_buffer","text_cursor_u32","vectors"]
const WORLD_KEYS:=["kind","args","task_slot_s32","ip_before_u32","ip_after_u32","before","after","return_u32","input_hex","output_hex","input_defined_hex","output_defined_hex"]
const VECTOR_SHA:="a59194e05117f7bd46e82b9ca92c5bbf0ebe3952e6cddfbdebbe102332c56ae2"
const MAX_CALLS:=256
static func _hash(raw:PackedByteArray)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw);return hash.finish().hex_encode()
static func _keys(value:Variant,keys:Array)->bool:return Expr._keys(value,keys)
static func _whole(value:Variant,low:int,high:int)->bool:return Frame._whole(value,low,high)
static func _view(value:Dictionary,keys:Array)->Dictionary:return Runtime._view(value,keys)
static func _context(value:Variant)->bool:
	if not Safe._plain(value) or not _keys(value,Runtime.KEYS+EXTRA_KEYS) or not Runtime._context(_view(value,Runtime.KEYS)):return false
	return value.text_buffer is PackedByteArray and value.text_buffer.size()>=1 and value.text_buffer.size()<=65536 and _whole(value.text_cursor_u32,0,value.text_buffer.size()) and value.vectors is PackedByteArray and value.vectors.size()==324 and _hash(value.vectors)==VECTOR_SHA
static func _copy_context(value:Variant)->Dictionary:
	if not _context(value):return {}
	var result:=Runtime._copy_context(_view(value,Runtime.KEYS))
	for key:String in EXTRA_KEYS:result[key]=value[key].duplicate() if value[key] is PackedByteArray else int(value[key])
	return result
static func decode_context(value:Variant)->Dictionary:
	if not Safe._plain(value) or not _keys(value,Runtime.KEYS+EXTRA_KEYS):return {}
	var result:=Runtime.decode_context(_view(value,Runtime.KEYS))
	if result.is_empty():return {}
	for key:String in ["text_buffer","vectors"]:
		var raw:Variant=value[key]
		if raw is PackedByteArray:result[key]=raw.duplicate()
		elif raw is String and raw.length()%2==0 and raw.length()<=131072 and Frame._hex(raw,raw.length()/2):result[key]=str(raw).hex_decode()
		else:return {}
	result["text_cursor_u32"]=value.text_cursor_u32
	return _copy_context(result)
static func _mask(value:Variant,count:int)->bool:
	if not Frame._hex(value,count):return false
	for byte:int in str(value).hex_decode():
		if byte not in [0,1]:return false
	return true
static func _scratch(value:Variant)->bool:
	return _keys(value,["seed_hex","defined_hex"]) and Frame._hex(value.seed_hex,156) and _mask(value.defined_hex,156)
static func _command(value:Variant)->bool:
	if not Safe._plain(value) or not _keys(value,Runtime.COMMAND_KEYS+["statement_frames"]) or not value.statement_frames is Array or value.statement_frames.size()>MAX_CALLS:return false
	for scratch:Variant in value.statement_frames:
		if not _scratch(scratch):return false
	var prior:Dictionary=value.duplicate();prior.erase("statement_frames")
	if value.kind in ["statements","spawn"]:
		return value.operation==("F41" if value.kind=="statements" else "F40") and Expr._words(value.args,0 if value.kind=="statements" else 9) and _whole(value.task_slot_s32,0 if value.kind=="statements" else -1,149) and _whole(value.ip_u32,0,MASK)
	return Runtime._command(prior)
static func _world_rows(value:Variant)->Variant:
	if not Safe._plain(value) or not value is Array or value.size()>MAX_CALLS:return null
	var result:Array=[]
	for raw:Variant in value:
		if not raw is Dictionary:return null
		var keys:=WORLD_KEYS.duplicate()
		if raw.has("registry_actions"):keys.append("registry_actions")
		if not _keys(raw,keys) or not raw.kind is String or raw.kind=="F41" or not raw.args is Array or raw.args.size()>12 or not Expr._words(raw.args,raw.args.size()) or not _whole(raw.task_slot_s32,-1,149) or not _whole(raw.ip_before_u32,0,MASK) or not _whole(raw.ip_after_u32,0,MASK) or not _whole(raw.return_u32,0,MASK) or not raw.input_hex is String or not raw.output_hex is String or raw.input_hex.length()%2!=0 or raw.output_hex.length()%2!=0 or raw.input_hex.length()>131072 or raw.output_hex.length()>131072 or not Frame._hex(raw.input_hex,raw.input_hex.length()/2) or not Frame._hex(raw.output_hex,raw.output_hex.length()/2) or not _mask(raw.input_defined_hex,raw.input_hex.length()/2) or not _mask(raw.output_defined_hex,raw.output_hex.length()/2) or (raw.has("registry_actions") and not Events._actions(raw.registry_actions)):return null
		var row:Dictionary=raw.duplicate(true);row.before=decode_context(raw.before);row.after=decode_context(raw.after)
		if row.before.is_empty() or row.after.is_empty():return null
		for key:String in ["task_slot_s32","ip_before_u32","ip_after_u32","return_u32"]:row[key]=int(row[key])
		for index in range(row.args.size()):row.args[index]=int(row.args[index])
		result.append(row)
	return result
static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false,"full_original_port_complete":false}
static func execute(context:Variant,command:Variant,observations:Variant=[])->Dictionary:
	if not _context(context) or not _command(command):return _reject("invalid_mission_vm_command")
	var rows:Variant=_world_rows(observations)
	if rows==null:return _reject("invalid_mission_vm_world_observation")
	var runner:=Session.new();runner.core=Runtime._copy_context(_view(context,Runtime.KEYS));runner.text_buffer=context.text_buffer.duplicate();runner.text_cursor=int(context.text_cursor_u32);runner.vectors=context.vectors.duplicate();runner.observations=rows;runner.seeds=command.statement_frames.duplicate(true)
	var result:=runner.invoke(command.kind,command.operation,command.args,int(command.task_slot_s32),int(command.ip_u32))
	if not result.get("ok",false):result["profile"]=PROFILE;return result
	if runner.used!=rows.size():return _reject("unused_mission_vm_world_observations")
	if runner.seed_used!=runner.seeds.size():return _reject("unused_statement_frame_seeds")
	return {"ok":true,"profile":PROFILE,"context_after":runner.owner(),"kernel_result":result.kernel_result,"cursor_after_u32":int(result.cursor_after_u32),"return_u32":int(result.return_u32),"return_defined":bool(result.return_defined),"source_order":result.source_order,"dependency_calls":runner.calls.duplicate(true),"world_observations_used":runner.used,"statement_frames_used":runner.seed_used,"statement_frames_after":runner.frames_after.duplicate(true),"retired_projection_never_reinserted":true,"live_owners_changed":false,"Main_integrated":false,"full_original_port_complete":false}

# The source only dereferences task+20 for selector6. A private transport buffer
# can finish a callback continuation after free, but every actual read is gated.
class VMExpression extends Expr.MissionExpression:
	var variable_live:=true
	var global_live:=true
	func expression(level:int=0)->int:
		if stopped.is_empty() and int(context.ip_u32)<context.program.size():
			var opcode:int=context.program[int(context.ip_u32)]
			if opcode==6 and not variable_live:return fail("dangling_selected_task_variable_read")
			if opcode==5 and not global_live:return fail("invalid_selected_module_global_read")
		return super.expression(level)
	func boundary(kind:String,args:Array)->Dictionary:
		if not stopped.is_empty():return {}
		order.append(kind);var pending:Dictionary={"kind":kind,"args":args.duplicate(),"before":host()._copy_context(context),"input_hex":""}
		if used>=observations.size():fail("boundary_required");stopped["pending"]=pending;return {}
		var row:Dictionary=observations[used];var checked:=row.duplicate(true)
		for key:String in ["variable_live_after","global_live_after"]:checked.erase(key)
		# Validate the frozen callback ABI independently of the new projection's
		# changing selected allocation/global base; only the program is readonly.
		checked.after.task_variables=checked.before.task_variables.duplicate();checked.after.module_global_offset_u32=checked.before.module_global_offset_u32
		if not host()._observation(checked) or row.kind!=kind or row.args!=args or not host()._same_context(row.before,context) or not host()._context(row.after) or row.before.program!=row.after.program or row.before.ip_u32!=row.after.ip_u32:fail("unmatched_vm_expression_observation");return {}
		context=host()._copy_context(row.after);variable_live=bool(row.variable_live_after);global_live=bool(row.global_live_after);requests.append(row.duplicate(true));used+=1
		return {"ok":true,"return_u32":int(row.return_u32),"output":str(row.output_hex).hex_decode()}

class VMStore extends Store.Store:
	var variable_live:=true
	var global_live:=true
	func run(value:int)->Dictionary:
		if int(context.ip_u32)<context.program.size():
			var opcode:int=context.program[int(context.ip_u32)]
			if opcode==6 and not variable_live:fail("dangling_selected_task_variable_write");return stopped
			if opcode==5 and not global_live:fail("invalid_selected_module_global_write");return stopped
		return super.run(value)
	func boundary(kind:String,args:Array)->Dictionary:
		if not stopped.is_empty():return {}
		order.append(kind);var pending:Dictionary={"kind":kind,"args":args.duplicate(),"before":host()._copy_context(context),"input_hex":""}
		if used>=observations.size():fail("boundary_required");stopped["pending"]=pending;return {}
		var row:Dictionary=observations[used];var checked:=row.duplicate(true)
		for key:String in ["variable_live_after","global_live_after"]:checked.erase(key)
		for key:String in ["task_variables","module_global_offset_u32","descriptor_ref_u32"]:checked.after[key]=checked.before[key].duplicate() if checked.before[key] is PackedByteArray else checked.before[key]
		if not host()._observation(checked) or row.kind!=kind or row.args!=args or row.before!=context or not host()._context(row.after) or row.before.program!=row.after.program:fail("unmatched_vm_store_observation");return {}
		context=host()._copy_context(row.after);variable_live=bool(row.variable_live_after);global_live=bool(row.global_live_after);requests.append(row.duplicate(true));used+=1
		return {"ok":true,"return_u32":int(row.return_u32)}

class Session extends Runtime.Session:
	var text_buffer:PackedByteArray
	var text_cursor:=0
	var vectors:PackedByteArray
	var seeds:Array=[]
	var seed_used:=0
	var frames_after:Array=[]
	var active_frame:Dictionary={}
	func vmhost()->GDScript:return load("res://scripts/source_mission_vm.gd")
	func owner()->Dictionary:
		var result:=Runtime._copy_context(core);result["text_buffer"]=text_buffer.duplicate();result["text_cursor_u32"]=text_cursor;result["vectors"]=vectors.duplicate();return result
	func set_owner(value:Dictionary)->void:
		core=Runtime._copy_context(Runtime._view(value,Runtime.KEYS));text_buffer=value.text_buffer.duplicate();text_cursor=int(value.text_cursor_u32);vectors=value.vectors.duplicate()
	func selected(slot:int,frame:Dictionary)->Dictionary:
		if slot<0 or slot>=150:return {}
		var descriptor:int=core.arena.decode_u32(slot*36+28);var at:=descriptor-int(core.program_base_u32);var identifier:=str(core.arena.decode_u32(slot*36+32));var live:bool=core.task_variables.has(identifier)
		var global_offset:=MASK;var global_live:=false
		if at>=0 and at+24<=core.program.size():
			var reference:int=core.program.decode_u32(at+20)
			if reference>=0x60bde0 and reference<=0x60bde0+36 and (reference-0x60bde0)%4==0:global_offset=reference-0x60bde0;global_live=true
		var variables:PackedByteArray=core.task_variables[identifier].duplicate() if live else frame.get("retired_variables",core.scratch_words.slice(0,8)).duplicate()
		if live:frame["retired_variables"]=variables.duplicate()
		frame["variable_live"]=live;frame["global_live"]=global_live;frame["variable_id"]=identifier
		if not frame.has("initial_variable_live"):frame["initial_variable_live"]=live;frame["initial_global_live"]=global_live
		return {"descriptor":descriptor,"variables":variables,"global_offset":global_offset}
	func frame_view(kind:String,slot:int,ip:int,frame:Dictionary)->Dictionary:
		if kind=="spawn":return Runtime._view(core,Spawn.CONTEXT_KEYS)
		if kind=="statements":
			if slot<0 or slot>=150 or ip<0 or ip>core.program.size():return {}
			return {"root":core.root.duplicate(),"root_tail":core.root_tail.duplicate(),"bank":core.bank.duplicate(),"program":core.program.duplicate(),"program_base_u32":int(core.program_base_u32),"ip_u32":ip,"task_record":core.arena.slice(slot*36,slot*36+36),"task_slot_u32":slot,"vectors":vectors.duplicate(),"text_buffer":text_buffer.duplicate(),"text_cursor_u32":text_cursor}
		if kind not in ["expression","store"]:return super.frame_view(kind,slot,ip,frame)
		if ip<0 or ip>core.program.size():return {}
		var selection:=selected(slot,frame)
		if selection.is_empty():return {}
		var result:=Runtime._view(core,Runtime.EXPR_SHARED);result["task_variables"]=selection.variables;result["ip_u32"]=ip;result["module_global_offset_u32"]=selection.global_offset
		if kind=="store":
			result["task_slot_u32"]=slot;result["descriptor_ref_u32"]=int(selection.descriptor) if int(selection.descriptor)!=0 else int(core.program_base_u32)
			if frame.market_key!="" and core.market_records.has(frame.market_key):result["market_buffer"]=core.market_records[frame.market_key].duplicate()
			else:
				var ignored:=PackedByteArray();ignored.resize(308);result["market_buffer"]=ignored
		return result
	func merge(kind:String,view:Dictionary,slot:int,frame:Dictionary)->bool:
		if kind=="statements":
			for key:String in ["root","root_tail","bank"]:core[key]=view[key].duplicate()
			for index in range(36):core.arena[slot*36+index]=view.task_record[index]
			text_buffer=view.text_buffer.duplicate();text_cursor=int(view.text_cursor_u32)
		elif kind=="spawn":
			for key:String in Spawn.CONTEXT_KEYS:core[key]=view[key].duplicate()
		elif kind in ["expression","store"]:
			for key:String in Runtime.EXPR_SHARED:core[key]=view[key].duplicate() if view[key] is PackedByteArray else view[key]
			var identifier:=str(core.arena.decode_u32(slot*36+32))
			if bool(frame.get("variable_live",false)) and core.task_variables.has(identifier):core.task_variables[identifier]=view.task_variables.duplicate()
			if kind=="store" and frame.market_key!="":core.market_records[frame.market_key]=view.market_buffer.duplicate()
		else:return super.merge(kind,view,slot,frame)
		return Runtime._context(core)
	func kernel(kind:String,initial:Dictionary,operation:String,args:Array,trace:Array)->Dictionary:
		if kind=="statements":return Statements.execute(initial,trace,active_frame.scratch)
		if kind=="spawn":return Spawn.execute(initial,operation,args,trace)
		if kind=="expression":
			if not Expr._operation(operation,args) or not Expr._context(initial):return failed("invalid_vm_expression_projection")
			var runner:=VMExpression.new();runner.context=Expr._copy_context(initial);runner.observations=trace.duplicate(true);runner.variable_live=bool(active_frame.initial_variable_live);runner.global_live=bool(active_frame.initial_global_live);return runner.run(operation,args)
		if kind=="store":
			if operation!="F37" or not Expr._words(args,1) or not Store._context(initial):return failed("invalid_vm_store_projection")
			var runner:=VMStore.new();runner.context=Store._copy_context(initial);runner.observations=trace.duplicate(true);runner.variable_live=bool(active_frame.initial_variable_live);runner.global_live=bool(active_frame.initial_global_live);return runner.run(int(args[0]))
		return super.kernel(kind,initial,operation,args,trace)
	func invoke_body(kind:String,operation:String,args:Array,slot:int,ip:int)->Dictionary:
		if kind=="model":return model(operation,args,ip)
		var frame:Dictionary={"market_key":""}
		if kind=="statements":
			if seed_used>=seeds.size():return failed("statement_frame_seed_required")
			frame["scratch"]=seeds[seed_used].duplicate(true);frame["ordinal"]=seed_used;seed_used+=1
		var initial:=frame_view(kind,slot,ip,frame)
		if initial.is_empty():return failed("mission_frame_projection_outside_profile")
		var trace:Array=[];var children:Array=[];var cursor:=ip
		for attempt in range(MAX_CALLS+1):
			steps+=1
			if steps>Runtime.MAX_STEPS:return failed("mission_runtime_composition_profile_limit")
			active_frame=frame
			var result:=kernel(kind,initial,operation,args,trace)
			if result.get("ok",false):
				if not merge(kind,result.context_after,slot,frame):return failed("invalid_composed_mission_result")
				if kind in ["expression","store","guards","statements"]:cursor=int(result.context_after.ip_u32)
				elif kind=="tasks":cursor=int(result.context_after.caller_ip_u32)
				if kind=="events" and operation in ["F44","F45","F50","F56"]:registry_journal.append({"operation":"F50" if operation=="F56" else operation,"args":[] if operation=="F56" else args.duplicate()})
				var expanded:Array=[]
				for index in range(result.source_order.size()):
					expanded.append(result.source_order[index])
					for child:Dictionary in children:
						if int(child.at)==index:
							var order:Array=child.order;expanded.append_array(order.slice(1) if not order.is_empty() and order[0]==result.source_order[index] else order)
				var returned:=int(result.get("return_u32",0));var defined:=bool(result.get("return_defined",false))
				if kind=="events" and operation=="F51":returned=int(result.allocated_slot_s32)&MASK;defined=true
				if kind=="statements":frames_after.append({"ordinal_u32":int(frame.ordinal),"task_slot_u32":slot,"scratch_after_hex":result.scratch_after_hex,"scratch_defined_hex":result.scratch_defined_hex})
				return {"ok":true,"kernel_result":result,"cursor_after_u32":cursor,"return_u32":returned,"return_defined":defined,"source_order":expanded}
			if not result.get("pending") is Dictionary:return failed(kind+"_"+str(result.get("reason","rejected")))
			var pending:Dictionary=result.pending
			if not merge(kind,pending.before,slot,frame):return failed("invalid_pending_mission_projection")
			if kind in ["expression","store","guards","statements"]:cursor=int(pending.before.ip_u32)
			var journal_start:=registry_journal.size();var closed:=close(kind,pending,slot,cursor,frame)
			if not closed.get("ok",false):return closed
			var after_cursor:=int(closed.get("cursor_after_u32",cursor));var after_ip:=after_cursor if kind in ["expression","store","guards","statements"] else ip
			if kind=="tasks" and pending.cursor_kind=="caller":after_ip=after_cursor
			elif kind=="tasks":after_ip=int(pending.before.caller_ip_u32)
			var projected:=frame_view(kind,slot,after_ip,frame)
			if projected.is_empty():return failed("dangling_outer_projection_outside_vm_profile")
			var row:Dictionary={"kind":pending.kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":projected,"return_u32":int(closed.get("return_u32",0))}
			if kind in ["expression","store","spawn","statements"]:row["input_hex"]=str(closed.get("input_hex",""));row["output_hex"]=str(closed.get("output_hex",""))
			if kind in ["expression","store"]:row["variable_live_after"]=bool(frame.variable_live);row["global_live_after"]=bool(frame.global_live)
			if kind=="statements":row["input_defined_hex"]=str(closed.get("input_defined_hex",""));row["output_defined_hex"]=str(closed.get("output_defined_hex",""))
			if kind=="tasks":row["cursor_kind"]=pending.cursor_kind;row["cursor_before_u32"]=int(pending.cursor_before_u32);row["cursor_after_u32"]=MASK if pending.cursor_kind=="none" else after_cursor
			if kind=="events":row["registry_actions"]=registry_journal.slice(journal_start)
			trace.append(row);children.append({"at":result.source_order.size()-1,"order":closed.get("source_order",[]).duplicate()})
		return failed("mission_runtime_composition_profile_limit")
	func close(parent:String,pending:Dictionary,slot:int,ip:int,frame:Dictionary)->Dictionary:
		frame.erase("packet")
		var name:String=pending.kind;var args:Array=pending.args
		if parent=="statements":
			if name=="F31":return nested("expression","F31",[],slot,ip)
			if name=="F37":return nested("store","F37",[int(args[1])],slot,ip)
			if name=="F52":return nested("tasks","F52",[slot,int(args[1]),int(args[2])],slot,ip)
			if name=="F38":return nested("tasks","F38",args,slot,ip)
			if name=="F48":return nested("events","F48",args,slot,ip)
			if name in ["F39","F40"]:
				var closed:=nested("spawn",name,args,slot,ip)
				if closed.get("ok",false) and name=="F39":closed["return_u32"]=0;closed["return_defined"]=false
				return closed
			frame["packet"]=pending
			return world(name,args,slot,ip,parent,frame)
		if name=="F41":
			if parent=="tasks":return nested("statements","F41",[],int(args[0]),int(pending.cursor_before_u32))
			if parent=="events":
				var local_ip:=int(args[1])-int(core.program_base_u32)
				if local_ip<0 or local_ip>core.program.size():return failed("event_cleanup_cursor_outside_program")
				return nested("statements","F41",[],int(args[0]),local_ip)
			return failed("unrecognized_statement_call_site")
		return super.close(parent,pending,slot,ip,frame)
	func world(name:String,args:Array,slot:int,ip:int,parent:String,frame:Dictionary)->Dictionary:
		if name=="F41":return failed("statement_world_boundary_forbidden")
		var packet:Dictionary=frame.get("packet",{});var input_hex:=str(packet.get("input_hex",""));var input_defined:=str(packet.get("input_defined_hex",""))
		var pending:Dictionary={"kind":name,"args":args.duplicate(),"task_slot_s32":slot,"ip_before_u32":ip,"before":owner(),"input_hex":input_hex,"input_defined_hex":input_defined,"output_byte_count_u32":int(packet.get("output_byte_count_u32",0))}
		if used>=observations.size():return failed("world_boundary_required",pending)
		var row:Dictionary=observations[used]
		if row.kind!=name or row.args!=args or int(row.task_slot_s32)!=slot or int(row.ip_before_u32)!=ip or row.before!=owner() or row.input_hex!=input_hex or row.input_defined_hex!=input_defined:return failed("unmatched_mission_vm_world_observation",pending)
		if int(row.ip_after_u32)!=ip:return failed("world_provider_changed_private_invocation_cursor")
		# The frozen expression evaluator predates byte-definedness transport.
		# Admit only fully observed output buffers there; private statement
		# windows retain their more precise per-byte unknown provenance.
		if parent=="expression" and row.output_defined_hex!="01".repeat(row.output_hex.length()/2):return failed("expression_output_bytes_outside_defined_transport_profile")
		if parent=="statements":
			var count:=int(packet.get("output_byte_count_u32",0));var actual:int=row.output_hex.length()/2
			if actual not in [0,count]:return failed("statement_world_output_extent_mismatch")
		for key:String in ["program","program_base_u32","metadata","definitions","vectors"]:
			if row.before[key]!=row.after[key]:return failed("world_provider_changed_readonly_mission_resource")
		if row.before.text_buffer.size()!=row.after.text_buffer.size() or not Runtime._heap_transition(Runtime._view(row.before,Runtime.KEYS),Runtime._view(row.after,Runtime.KEYS)):return failed("world_provider_changed_owner_allocation_profile")
		var tree:=Runtime._view(core,Events.CONTEXT_KEYS);var world_order:Array=[name]
		for action:Dictionary in row.get("registry_actions",[]):
			var replay:=Runtime.RuntimeEvents.new();replay.context=tree;replay.observations=[];var outcome:=replay.run(action.operation,action.args)
			if not outcome.get("ok",false):return failed("world_registry_action_rejected")
			tree=outcome.context_after;world_order.append_array(outcome.source_order)
		for key:String in ["tree_root_u32","nodes","next_node_id_u32"]:
			if tree[key]!=row.after[key]:return failed("world_registry_result_does_not_match_original_actions")
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
		set_owner(row.after);used+=1;registry_journal.append_array(row.get("registry_actions",[]).duplicate(true))
		return {"ok":true,"return_u32":int(row.return_u32),"return_defined":true,"cursor_after_u32":ip,"input_hex":row.input_hex,"output_hex":row.output_hex,"input_defined_hex":row.input_defined_hex,"output_defined_hex":row.output_defined_hex,"source_order":world_order}
