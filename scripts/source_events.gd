extends RefCounted
# Original event-registration and dispatch kernels. Heap/task references are
# normalized logical tokens; no host address is a persistent owner.
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
const PROFILE:="dos-firstenc-events-tree-v1"
const KEY_ORDER:=[0,1,2,4,5,3]
const MASK:=0xffffffff
const CONTEXT_KEYS:=["root","bank","event_registers","scratch_words","arena","temporary_event_index_s32","tree_root_u32","nodes","next_node_id_u32","task_variables","next_variable_id_u32","definitions"]
const BYTE_COUNTS:={"root":16384,"bank":38986,"event_registers":284,"scratch_words":32,"arena":5400}
const NODE_KEYS:=["left_u32","right_u32","key_u32","generation_u32"]
const DEFINITION_KEYS:=["descriptor_ref_u32","cleanup_instruction_u32","variable_words_u32"]
const OPERATIONS:=["F42","F43","F44","F45","F46","F48","F50","F51","F54","F55","F56"]
const MAX_ALLOCATIONS:=512
const MAX_OBSERVATIONS:=256
const MAX_SCHEDULER_STEPS:=1024
static func _whole(value:Variant,low:int,high:int)->bool:return Frame._whole(value,low,high)
static func _keys(value:Variant,keys:Array)->bool:
	if not value is Dictionary or value.size()!=keys.size():return false
	for key:Variant in value:
		if not (key is String or key is StringName) or str(key) not in keys:return false
	return true
static func _words(value:Variant,count:int)->bool:
	if not value is Array or value.size()!=count:return false
	for word:Variant in value:
		if not _whole(word,0,MASK):return false
	return true
static func _compare(first:Array,second:Array,order:Array)->int:
	for index:int in order:
		if int(first[index])!=int(second[index]):return Ground.signed32(int(first[index])-int(second[index]))
	return 0
static func compare_f42(first:Variant,second:Variant)->Dictionary:
	if not _words(first,6) or not _words(second,6):return {"ok":false,"reason":"invalid_F42_keys","profile":PROFILE}
	var value:=_compare(first,second,KEY_ORDER)
	return {"ok":true,"return_s32":value,"return_u32":value&MASK,"source_order":["F42"],"profile":PROFILE,"live_owners_changed":false}
static func compare_f43(first:Variant,second:Variant)->Dictionary:
	if not _words(first,3) or not _words(second,3):return {"ok":false,"reason":"invalid_F43_keys","profile":PROFILE}
	var value:=_compare(first,second,[0,1,2])
	return {"ok":true,"return_s32":value,"return_u32":value&MASK,"source_order":["F43"],"profile":PROFILE,"live_owners_changed":false}
static func _id_key(value:Variant,maximum:int=MAX_ALLOCATIONS,allow_zero:bool=false)->bool:
	return value is String and value.is_valid_int() and str(int(value))==value and _whole(int(value),0 if allow_zero else 1,maximum)
static func _context(value:Variant)->bool:
	if not _keys(value,CONTEXT_KEYS) or not _whole(value.temporary_event_index_s32,-0x80000000,0x7fffffff) or not _whole(value.tree_root_u32,0,MAX_ALLOCATIONS) or not _whole(value.next_node_id_u32,1,MAX_ALLOCATIONS+1) or not _whole(value.next_variable_id_u32,1,MAX_ALLOCATIONS+1) or not value.nodes is Dictionary or value.nodes.size()>MAX_ALLOCATIONS or not value.task_variables is Dictionary or value.task_variables.size()>MAX_ALLOCATIONS or not value.definitions is Dictionary or value.definitions.size()>256:return false
	for key:String in BYTE_COUNTS:
		if not value[key] is PackedByteArray or value[key].size()!=int(BYTE_COUNTS[key]):return false
	for key:Variant in value.nodes:
		var node:Variant=value.nodes[key]
		if not _id_key(key) or int(key)>=int(value.next_node_id_u32) or not _keys(node,NODE_KEYS) or not _whole(node.left_u32,0,MAX_ALLOCATIONS) or not _whole(node.right_u32,0,MAX_ALLOCATIONS) or not _words(node.key_u32,6) or not _whole(node.generation_u32,1,1):return false
	var seen:Dictionary={};var pending:Array=[int(value.tree_root_u32)]
	while not pending.is_empty():
		var handle:int=pending.pop_back()
		if handle==0:continue
		var key:=str(handle)
		if seen.has(key) or not value.nodes.has(key):return false
		seen[key]=true;pending.append(int(value.nodes[key].left_u32));pending.append(int(value.nodes[key].right_u32))
	if seen.size()!=value.nodes.size():return false
	for key:Variant in value.task_variables:
		if not _id_key(key) or int(key)>=int(value.next_variable_id_u32) or not value.task_variables[key] is PackedByteArray or value.task_variables[key].size()<8 or value.task_variables[key].size()>1024 or value.task_variables[key].size()%4!=0:return false
	for key:Variant in value.definitions:
		var definition:Variant=value.definitions[key]
		if not _id_key(key,255,true) or not _keys(definition,DEFINITION_KEYS) or not _whole(definition.descriptor_ref_u32,0,MASK) or not _whole(definition.cleanup_instruction_u32,0,MASK) or not _whole(definition.variable_words_u32,2,256):return false
	return true
static func _copy_context(value:Dictionary)->Dictionary:
	var result:Dictionary=value.duplicate(true)
	for key:String in ["temporary_event_index_s32","tree_root_u32","next_node_id_u32","next_variable_id_u32"]:result[key]=int(value[key])
	for key:String in result.nodes:
		var node:Dictionary=result.nodes[key]
		for field:String in ["left_u32","right_u32","generation_u32"]:node[field]=int(node[field])
		for index in range(6):node.key_u32[index]=int(node.key_u32[index])
	for key:String in result.definitions:
		for field:String in DEFINITION_KEYS:result.definitions[key][field]=int(result.definitions[key][field])
	return result
static func _same_context(first:Variant,second:Dictionary)->bool:
	if not _context(first):return false
	for key:String in CONTEXT_KEYS:
		if first[key]!=second[key]:return false
	return true
static func decode_context(value:Variant)->Dictionary:
	if not _keys(value,CONTEXT_KEYS) or not value.task_variables is Dictionary:return {}
	var result:Dictionary=value.duplicate(true)
	for key:String in BYTE_COUNTS:
		if result[key] is String and Frame._hex(result[key],int(BYTE_COUNTS[key])):result[key]=str(result[key]).hex_decode()
	for key:Variant in result.task_variables:
		var raw:Variant=result.task_variables[key]
		if raw is String and raw.length()%8==0 and raw.length()>=16 and raw.length()<=2048 and Frame._hex(raw,raw.length()/2):result.task_variables[key]=str(raw).hex_decode()
	return _copy_context(result) if _context(result) else {}
static func _operation(operation:Variant,args:Variant)->bool:
	if not operation is String or operation not in OPERATIONS or not args is Array:return false
	if operation in ["F42","F43"]:return args.size()==2 and _words(args[0],6) and _words(args[1],6)
	if operation in ["F44","F45"]:return _words(args,6)
	if operation in ["F46","F48"]:return _words(args,3)
	if operation=="F51":return args.size()==2 and _whole(args[0],0,255) and _whole(args[1],0,MASK)
	return args.is_empty()
static func _actions(value:Variant)->bool:
	if not value is Array or value.size()>64:return false
	for action:Variant in value:
		if not _keys(action,["operation","args"]) or action.operation not in ["F44","F45","F50"] or not _operation(action.operation,action.args):return false
	return true
static func _observation(value:Variant)->bool:
	if not value is Dictionary:return false
	var keys:Array=["kind","args","before","after"]
	if value.has("return_u32"):keys.append("return_u32")
	if value.has("registry_actions"):keys.append("registry_actions")
	if not _keys(value,keys) or not value.kind is String or value.kind not in ["event_callback","F53","F41","F52"] or not value.args is Array or not _context(value.before) or not _context(value.after):return false
	var count:=3 if value.kind=="event_callback" else 4 if value.kind=="F52" else 2
	if not _words(value.args,count) or (value.has("return_u32") and not _whole(value.return_u32,0,MASK)) or (value.has("registry_actions") and not _actions(value.registry_actions)):return false
	return true
static func decode_observations(value:Variant)->Variant:
	if not value is Array or value.size()>MAX_OBSERVATIONS:return null
	var result:Array=value.duplicate(true)
	for row:Variant in result:
		if not row is Dictionary or not row.has("before") or not row.has("after"):return null
		row.before=decode_context(row.before);row.after=decode_context(row.after)
		if not _observation(row):return null
	return result
static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false,"full_F41_VM_executed":false}
static func execute(context:Variant,operation:Variant,args:Variant=[],observations:Variant=[])->Dictionary:
	if not _context(context) or not _operation(operation,args) or not observations is Array or observations.size()>MAX_OBSERVATIONS:return _reject("invalid_source_events_context")
	var runner:=Events.new();runner.context=_copy_context(context);runner.observations=observations.duplicate(true)
	return runner.run(str(operation),args)

class Events:
	var context:Dictionary
	var observations:Array
	var used:=0
	var order:Array=[]
	var requests:Array=[]
	var stopped:Dictionary={}
	var captured:Array=[]
	var allocated_slot:=-1
	var allocated_handle:=0
	func host()->GDScript:return load("res://scripts/source_events.gd")
	func fail(reason:String)->bool:
		stopped=host()._reject(reason);stopped["source_order"]=order.duplicate();stopped["observations_used"]=used;return false
	func same_args(first:Variant,second:Array)->bool:
		if not first is Array or first.size()!=second.size():return false
		for index in range(second.size()):
			if not host()._whole(first[index],0,MASK) or int(first[index])!=int(second[index]):return false
		return true
	func boundary(kind:String,args:Array)->bool:
		order.append(kind);var pending:Dictionary={"kind":kind,"args":args.duplicate(),"before":host()._copy_context(context)}
		if used>=observations.size():fail("boundary_required");stopped["pending"]=pending;return false
		var row:Variant=observations[used]
		if not host()._observation(row) or row.kind!=kind or not same_args(row.args,args) or not host()._same_context(row.before,pending.before):return fail("unmatched_source_events_observation")
		var after:Dictionary=host()._copy_context(row.after)
		if after.definitions!=context.definitions or after.next_variable_id_u32!=context.next_variable_id_u32 or after.task_variables.size()!=context.task_variables.size():return fail("callback_changed_readonly_definitions_or_variable_owners")
		for key:String in context.task_variables:
			if not after.task_variables.has(key) or after.task_variables[key].size()!=context.task_variables[key].size():return fail("callback_changed_variable_owner_identity")
		for key:String in BYTE_COUNTS:context[key]=after[key].duplicate()
		context.temporary_event_index_s32=int(after.temporary_event_index_s32);context.task_variables=after.task_variables.duplicate(true)
		for action:Dictionary in row.get("registry_actions",[]):
			if action.operation=="F44":
				if not insert(action.args):return false
			elif action.operation=="F45":remove(action.args)
			else:clear_tree()
			if not stopped.is_empty():return false
		if context.tree_root_u32!=after.tree_root_u32 or context.nodes!=after.nodes or context.next_node_id_u32!=after.next_node_id_u32:return fail("callback_registry_result_does_not_match_original_actions")
		requests.append(row.duplicate(true));used+=1;return true
	func get_link(owner:int,side:int)->int:
		return int(context.tree_root_u32) if owner==0 else int(context.nodes[str(owner)].left_u32 if side==0 else context.nodes[str(owner)].right_u32)
	func set_link(owner:int,side:int,value:int)->void:
		if owner==0:context.tree_root_u32=value
		elif side==0:context.nodes[str(owner)].left_u32=value
		else:context.nodes[str(owner)].right_u32=value
	func compare6(first:Array,second:Array)->int:
		order.append("F42");return host()._compare(first,second,KEY_ORDER)
	func compare3(first:Array,second:Array)->int:
		order.append("F43");return host()._compare(first,second,[0,1,2])
	func insert(key:Array)->bool:
		order.append("F44")
		var identifier:int=int(context.next_node_id_u32)
		if identifier>MAX_ALLOCATIONS:return fail("bounded_event_tree_allocator_exhausted")
		context.next_node_id_u32=identifier+1
		var owner:=0;var side:=0;var current:=get_link(owner,side)
		while current!=0:
			var compared:=compare6(key,context.nodes[str(current)].key_u32)
			owner=current;side=0 if compared<0 else 1;current=get_link(owner,side)
		var words:Array=[]
		for word:Variant in key:words.append(int(word))
		context.nodes[str(identifier)]={"left_u32":0,"right_u32":0,"key_u32":words,"generation_u32":1};set_link(owner,side,identifier);return true
	func remove(key:Array)->void:
		order.append("F45");var owner:=0;var side:=0;var current:=get_link(owner,side)
		while current!=0:
			var compared:=compare6(key,context.nodes[str(current)].key_u32)
			if compared==0:break
			owner=current;side=0 if compared<0 else 1;current=get_link(owner,side)
		if current==0:return
		var left:int=int(context.nodes[str(current)].left_u32);var right:int=int(context.nodes[str(current)].right_u32)
		if right==0:set_link(owner,side,left)
		elif left==0:set_link(owner,side,right)
		else:
			var predecessor_owner:=current;var predecessor_side:=0;var predecessor:=left
			while int(context.nodes[str(predecessor)].right_u32)!=0:
				predecessor_owner=predecessor;predecessor_side=1;predecessor=int(context.nodes[str(predecessor)].right_u32)
			set_link(predecessor_owner,predecessor_side,int(context.nodes[str(predecessor)].left_u32))
			context.nodes[str(predecessor)].left_u32=int(context.nodes[str(current)].left_u32);context.nodes[str(predecessor)].right_u32=right;set_link(owner,side,predecessor)
		context.nodes.erase(str(current))
	func snapshot_tree(current:int,key:Array,output:Array)->void:
		order.append("F46")
		if current==0:return
		var node:Dictionary=context.nodes[str(current)]
		snapshot_tree(int(node.left_u32),key,output)
		if compare3(node.key_u32,key)==0:output.append([int(node.key_u32[3]),int(node.key_u32[4]),int(node.key_u32[5])])
		snapshot_tree(int(node.right_u32),key,output)
	func free_tree(current:int)->void:
		order.append("F49")
		if current==0:return
		var node:Dictionary=context.nodes[str(current)];free_tree(int(node.left_u32));free_tree(int(node.right_u32));context.nodes.erase(str(current))
	func clear_tree()->void:
		order.append("F50");free_tree(int(context.tree_root_u32));context.tree_root_u32=0
	func dispatch(key:Array)->bool:
		order.append("F48");var current:int=int(context.tree_root_u32)
		while current!=0:
			var compared:=compare3(key,context.nodes[str(current)].key_u32)
			if compared==0:break
			current=int(context.nodes[str(current)].left_u32 if compared<0 else context.nodes[str(current)].right_u32)
		if current==0:return true
		var snapshot:Array=[];snapshot_tree(current,key,snapshot);captured=snapshot.duplicate(true)
		for callback:Array in snapshot:
			if int(callback[0])==0:return fail("unsupported_null_event_callback")
			if not boundary("event_callback",callback):return false
		return schedule()
	func allocate_task(module:int,argument:int)->bool:
		order.append("F51");allocated_slot=-1;allocated_handle=0
		var slot:=-1
		for index in range(150):
			if context.arena.decode_u32(index*36)==0:slot=index;break
		if slot<0:return true
		var key:=str(module)
		if not context.definitions.has(key):return fail("event_task_definition_unavailable")
		var identifier:int=int(context.next_variable_id_u32)
		if identifier>MAX_ALLOCATIONS:return fail("bounded_task_variable_allocator_exhausted")
		var definition:Dictionary=context.definitions[key];var at:=slot*36;var generation:int=(context.arena.decode_u16(at+6)+1)&65535
		context.arena.encode_u32(at,4);context.arena.encode_u16(at+4,slot);context.arena.encode_u16(at+6,generation);context.arena.encode_u32(at+8,0);context.arena.encode_u32(at+12,MASK);context.arena.encode_u32(at+16,0);context.arena.encode_u32(at+20,MASK);context.arena.encode_u32(at+24,module);context.arena.encode_u32(at+28,int(definition.descriptor_ref_u32));context.arena.encode_u32(at+32,identifier)
		var variables:=PackedByteArray();variables.resize(int(definition.variable_words_u32)*4);variables.fill(0xa5);allocated_handle=int(context.arena.decode_u32(at+4));variables.encode_u32(0,allocated_handle);variables.encode_u32(4,argument&MASK)
		context.task_variables[str(identifier)]=variables;context.next_variable_id_u32=identifier+1;allocated_slot=slot;return true
	func free_variables(identifier:int)->bool:
		if identifier==0:return true
		if not context.task_variables.has(str(identifier)):return fail("unowned_or_freed_task_variable_reference")
		context.task_variables.erase(str(identifier));return true
	func schedule()->bool:
		order.append("F54")
		for step in range(MAX_SCHEDULER_STEPS):
			var maximum:=0;var selected:=-1
			for slot in range(150):
				var value:int=context.arena.decode_s32(slot*36)
				if value>maximum:maximum=value;selected=slot
			if maximum<=3:return true
			if maximum>6:return fail("unsupported_nonterminating_source_task_priority")
			var at:=selected*36
			if maximum==4:
				if not boundary("F53",[selected,int(context.arena.decode_u32(at+4))]):return false
			elif maximum==5:
				context.arena.encode_u32(at,6);var key:=str(context.arena.decode_u32(at+24))
				if not context.definitions.has(key):return fail("event_cleanup_definition_unavailable")
				if not boundary("F41",[selected,int(context.definitions[key].cleanup_instruction_u32)]):return false
			else:
				if not free_variables(int(context.arena.decode_u32(at+32))):return false
				context.arena.encode_u32(at,0)
		return fail("bounded_source_task_scheduler_limit")
	func initialize()->bool:
		order.append("F55")
		for index in range(8):context.scratch_words.encode_u32(index*4,0)
		return boundary("F52",[0,0,0,0]) and schedule()
	func clear_all()->bool:
		order.append("F56")
		for slot in range(150):
			var at:=slot*36
			if context.arena.decode_s32(at)<=0:continue
			if not free_variables(int(context.arena.decode_u32(at+32))):return false
			context.arena.encode_u32(at,0)
		clear_tree();return true
	func run(operation:String,args:Array)->Dictionary:
		var returned:=0;var defined:=false
		match operation:
			"F42":returned=compare6(args[0],args[1]);defined=true
			"F43":returned=compare3(args[0],args[1]);defined=true
			"F44":insert(args)
			"F45":remove(args)
			"F46":snapshot_tree(int(context.tree_root_u32),args,captured)
			"F48":dispatch(args)
			"F50":clear_tree()
			"F51":allocate_task(int(args[0]),int(args[1]))
			"F54":schedule()
			"F55":initialize()
			"F56":clear_all()
		if not stopped.is_empty():return stopped
		if used!=observations.size():fail("unused_source_events_observations");return stopped
		if not host()._context(context):fail("invalid_source_events_result");return stopped
		var result:Dictionary={"ok":true,"profile":PROFILE,"context_after":host()._copy_context(context),"source_order":order.duplicate(),"requests":requests.duplicate(true),"observations_used":used,"captured_callbacks":captured.duplicate(true),"return_defined":defined,"scalar_return_defined":defined,"pointer_return_defined":operation=="F51","live_owners_changed":false,"Main_integrated":false,"full_F41_VM_executed":false}
		if defined:result["return_s32"]=returned;result["return_u32"]=returned&MASK
		if operation=="F51":result["allocated_slot_s32"]=allocated_slot;result["allocated_handle_u32"]=allocated_handle;result["pointer_result_kind"]="logical_task_slot";result["allocation_succeeded"]=allocated_slot>=0
		return result
