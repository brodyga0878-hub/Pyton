extends RefCounted
# Whole original task lifecycle. Source task/resource references are logical
# tokens; local/callee cursors are invocation-local and distinct from caller IP.
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const PROFILE:="dos-firstenc-mission-task-v1"
const MASK:=0xffffffff
const CONTEXT_KEYS:=["arena","program","program_base_u32","module_refs","caller_ip_u32"]
const MAX_OBSERVATIONS:=256
const MAX_STEPS:=1024
static func _whole(value:Variant,low:int,high:int)->bool:return Frame._whole(value,low,high)
static func _keys(value:Variant,keys:Array)->bool:
	if not value is Dictionary or value.size()!=keys.size():return false
	for key:Variant in value:
		if not (key is String or key is StringName) or str(key) not in keys:return false
	return true
static func _module_key(value:Variant)->bool:return value is String and value.length()<=3 and value.is_valid_int() and str(int(value))==value and _whole(int(value),0,255)
static func _context(value:Variant)->bool:
	if not _keys(value,CONTEXT_KEYS) or not value.arena is PackedByteArray or value.arena.size()!=5400 or not value.program is PackedByteArray or value.program.is_empty() or value.program.size()>65536 or not _whole(value.program_base_u32,1,MASK) or int(value.program_base_u32)+value.program.size()>0x100000000 or not value.module_refs is Dictionary or value.module_refs.size()>256:return false
	if not _whole(value.caller_ip_u32,0,MASK) or (int(value.caller_ip_u32)!=MASK and int(value.caller_ip_u32)>value.program.size()):return false
	for key:Variant in value.module_refs:
		if not _module_key(key) or not _whole(value.module_refs[key],0,MASK):return false
	return true
static func _copy_context(value:Dictionary)->Dictionary:
	if not _context(value):return {}
	var result:Dictionary={"arena":value.arena.duplicate(),"program":value.program.duplicate(),"program_base_u32":int(value.program_base_u32),"module_refs":{},"caller_ip_u32":int(value.caller_ip_u32)}
	for key:String in value.module_refs:result.module_refs[key]=int(value.module_refs[key])
	return result
static func decode_context(value:Variant)->Dictionary:
	if not _keys(value,CONTEXT_KEYS) or not _whole(value.program_base_u32,1,MASK) or not _whole(value.caller_ip_u32,0,MASK) or not value.module_refs is Dictionary or value.module_refs.size()>256:return {}
	var result:Dictionary={"program_base_u32":int(value.program_base_u32),"caller_ip_u32":int(value.caller_ip_u32),"module_refs":{}}
	for key:Variant in value.module_refs:
		if not _module_key(key) or not _whole(value.module_refs[key],0,MASK):return {}
		result.module_refs[key]=int(value.module_refs[key])
	for field:String in ["arena","program"]:
		var raw:Variant=value[field];var maximum:=5400 if field=="arena" else 65536
		if raw is PackedByteArray:
			if raw.size()>maximum:return {}
			result[field]=raw.duplicate()
		elif raw is String and raw.length()<=maximum*2 and raw.length()%2==0 and Frame._hex(raw,raw.length()/2):result[field]=str(raw).hex_decode()
		else:return {}
	return _copy_context(result) if _context(result) else {}
static func _same_context(first:Variant,second:Dictionary)->bool:
	if not _context(first):return false
	for key:String in CONTEXT_KEYS:
		if first[key]!=second[key]:return false
	return true
static func _args(value:Variant,count:int)->bool:
	if not value is Array or value.size()!=count:return false
	for word:Variant in value:
		if not _whole(word,0,MASK):return false
	return true
static func _operation(operation:Variant,args:Variant)->bool:
	if not operation is String or operation not in ["F38","F47","F52","F53"] or not args is Array:return false
	if operation=="F38":return _args(args,1)
	if operation=="F47":return _args(args,2) and int(args[0])<150 and int(args[1])<=16383
	if operation=="F53":return _args(args,1) and int(args[0])<150
	return args.size()==3 and _whole(args[0],-1,149) and _whole(args[1],0,255) and _whole(args[2],0,MASK)
static func _observation(value:Variant)->bool:
	if not _keys(value,["kind","args","before","after","return_u32","cursor_kind","cursor_before_u32","cursor_after_u32"]) or not value.kind is String or value.kind not in ["F31","F37","F41","F51","F33"] or not _context(value.before) or not _context(value.after) or not _whole(value.return_u32,0,MASK) or not value.cursor_kind is String or not _whole(value.cursor_before_u32,0,MASK) or not _whole(value.cursor_after_u32,0,MASK):return false
	if not _args(value.args,1 if value.kind in ["F31","F41"] else 2):return false
	if value.kind in ["F31","F37","F41","F33"] and int(value.args[0])>=150:return false
	if value.kind=="F51" and (int(value.args[0])>255 or (int(value.return_u32)!=MASK and int(value.return_u32)>=150)):return false
	if value.kind=="F33" and int(value.args[1]) not in [44,45]:return false
	if value.kind not in ["F31","F51"] and int(value.return_u32)!=0:return false
	for field:String in ["program","program_base_u32","module_refs"]:
		if value.before[field]!=value.after[field]:return false
	if value.kind in ["F51","F33"]:
		if value.cursor_kind!="none" or int(value.cursor_before_u32)!=MASK or int(value.cursor_after_u32)!=MASK:return false
	else:
		if (value.kind=="F31" and value.cursor_kind not in ["caller","local"]) or (value.kind=="F37" and value.cursor_kind!="callee") or (value.kind=="F41" and value.cursor_kind!="local"):return false
		if int(value.cursor_before_u32)>value.before.program.size() or int(value.cursor_after_u32)>value.after.program.size():return false
	if value.cursor_kind=="caller":return int(value.before.caller_ip_u32)==int(value.cursor_before_u32) and int(value.after.caller_ip_u32)==int(value.cursor_after_u32)
	return int(value.before.caller_ip_u32)==int(value.after.caller_ip_u32)
static func decode_observations(value:Variant)->Variant:
	if not value is Array or value.size()>MAX_OBSERVATIONS:return null
	var result:Array=[]
	for raw:Variant in value:
		if not _keys(raw,["kind","args","before","after","return_u32","cursor_kind","cursor_before_u32","cursor_after_u32"]) or not raw.kind is String or not raw.cursor_kind is String or not _args(raw.args,1 if raw.kind in ["F31","F41"] else 2) or not _whole(raw.return_u32,0,MASK) or not _whole(raw.cursor_before_u32,0,MASK) or not _whole(raw.cursor_after_u32,0,MASK):return null
		var row:Dictionary={"kind":raw.kind,"args":raw.args.duplicate(),"before":decode_context(raw.before),"after":decode_context(raw.after),"return_u32":int(raw.return_u32),"cursor_kind":raw.cursor_kind,"cursor_before_u32":int(raw.cursor_before_u32),"cursor_after_u32":int(raw.cursor_after_u32)}
		if not _observation(row):return null
		result.append(row)
	return result
static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false,"full_F41_executed":false}
static func execute(context:Variant,operation:Variant,args:Variant=[],observations:Variant=[])->Dictionary:
	if not _context(context) or not _operation(operation,args) or not observations is Array or observations.size()>MAX_OBSERVATIONS:return _reject("invalid_mission_task_command")
	for row:Variant in observations:
		if not _observation(row):return _reject("invalid_mission_task_observations")
	var runner:=Task.new();runner.context=_copy_context(context);runner.observations=observations.duplicate(true)
	return runner.run(operation,args)

class Task:
	var context:Dictionary
	var observations:Array
	var used:=0
	var steps:=0
	var order:Array=[]
	var requests:Array=[]
	var stopped:Dictionary={}
	func host()->GDScript:return load("res://scripts/source_mission_task.gd")
	func fail(reason:String)->bool:
		if stopped.is_empty():stopped=host()._reject(reason);stopped["source_order"]=order.duplicate();stopped["observations_used"]=used
		return false
	func step()->bool:
		steps+=1
		return true if steps<=host().MAX_STEPS else fail("task_lifecycle_profile_limit")
	func offset_for(reference:int,count:int)->int:
		var offset:=reference-int(context.program_base_u32)
		if offset<0 or count<0 or offset+count>context.program.size():fail("task_resource_span_outside_program");return -1
		return offset
	func read_word(reference:int,relative:int=0)->int:
		var at:=offset_for(reference+relative,4)
		return context.program.decode_u32(at) if at>=0 else 0
	func cursor(reference:int)->int:return offset_for(reference,0)
	func boundary(kind:String,args:Array,cursor_kind:String="none",before_cursor:int=0xffffffff)->Dictionary:
		order.append(kind)
		var pending:Dictionary={"kind":kind,"args":args.duplicate(),"before":host()._copy_context(context),"cursor_kind":cursor_kind,"cursor_before_u32":before_cursor}
		if used>=observations.size():fail("boundary_required");stopped["pending"]=pending;return {}
		var row:Variant=observations[used]
		if not host()._observation(row) or row.kind!=kind or row.cursor_kind!=cursor_kind or int(row.cursor_before_u32)!=before_cursor or not host()._same_context(row.before,context):fail("unmatched_mission_task_observation");return {}
		for index in range(args.size()):
			if int(row.args[index])!=int(args[index]):fail("unmatched_mission_task_arguments");return {}
		context=host()._copy_context(row.after);requests.append(row.duplicate(true));used+=1
		return {"ok":true,"return_u32":int(row.return_u32),"cursor_after_u32":int(row.cursor_after_u32)}
	func unregister(slot:int)->bool:
		return not boundary("F33",[slot,45]).is_empty()
	func cancel(handle:int)->bool:
		var slot:=handle&65535
		if slot>=150:return fail("task_handle_slot_outside_arena")
		var at:=slot*36
		if context.arena.decode_u32(at+4)!=handle:return true
		if context.arena.decode_u32(at+8)!=0:
			if not unregister(slot):return false
			context.arena.encode_u32(at+8,0);context.arena.encode_u32(at+12,0xffffffff)
		var cleanup:=read_word(context.arena.decode_u32(at+28),12)
		if not stopped.is_empty():return false
		if (cleanup&0x80000000)==0:context.arena.encode_u32(at,5)
		else:
			context.arena.encode_u16(at+6,(context.arena.decode_u16(at+6)+1)&65535);context.arena.encode_u32(at,6)
		return true
	func callback(slot:int,clause:int)->bool:
		var at:=slot*36
		if context.arena.decode_u32(at)!=1:return true
		var expression:=read_word(context.arena.decode_u32(at+8),8+clause*4)
		if not stopped.is_empty():return false
		var ip:=cursor(expression)
		if ip<0:return false
		var condition:=boundary("F31",[slot],"local",ip)
		if condition.is_empty():return false
		if int(condition.return_u32)==0:return true
		context.arena.encode_u32(at,2)
		if boundary("F41",[slot],"local",int(condition.cursor_after_u32)).is_empty():return false
		if context.arena.decode_u32(at)==2:context.arena.encode_u32(at,1)
		return true
	func create(args:Array)->int:
		var caller_slot:=int(args[0]);var module_index:=int(args[1]);var allocated:=boundary("F51",[module_index,int(args[2])])
		if allocated.is_empty():return 0
		var slot:=int(allocated.return_u32)
		if slot==0xffffffff:fail("task_allocation_null_fault");return 0
		if not context.module_refs.has(str(module_index)):fail("missing_mission_module_descriptor");return 0
		var descriptor:=int(context.module_refs[str(module_index)]);var target:=read_word(descriptor)
		if not stopped.is_empty():return 0
		var index:=0
		while true:
			if not step():return 0
			var argc:=read_word(descriptor,8)
			if not stopped.is_empty():return 0
			if index>=int(host().Frame.Ground.signed32(argc)):break
			if int(context.caller_ip_u32)==0xffffffff:fail("null_caller_expression_cursor_fault");return 0
			if caller_slot<0:fail("unsupported_null_caller_task");return 0
			var argument:=boundary("F31",[caller_slot],"caller",int(context.caller_ip_u32))
			if argument.is_empty():return 0
			var target_ip:=cursor(target)
			if target_ip<0:return 0
			var stored:=boundary("F37",[slot,int(argument.return_u32)],"callee",target_ip)
			if stored.is_empty():return 0
			target=int(context.program_base_u32)+int(stored.cursor_after_u32);index+=1
		var block:=read_word(int(context.module_refs[str(module_index)]),28)
		if not stopped.is_empty():return 0
		context.arena.encode_u32(slot*36+16,block);context.arena.encode_u32(slot*36+20,0)
		return context.arena.decode_u32(slot*36+4)
	func initialize(slot:int)->bool:
		var at:=slot*36;context.arena.encode_u32(at,3)
		if context.arena.decode_u32(at+8)!=0:
			if not unregister(slot):return false
			context.arena.encode_u32(at+8,0);context.arena.encode_u32(at+12,0xffffffff)
		var initializer:=read_word(context.arena.decode_u32(at+16))
		if not stopped.is_empty():return false
		var ip:=cursor(initializer)
		if ip<0:return false
		if boundary("F41",[slot],"local",ip).is_empty():return false
		if context.arena.decode_u32(at)!=3:return true
		var index:=0
		while true:
			if not step():return false
			var block:int=context.arena.decode_u32(at+16);var count:=read_word(block,4)
			if not stopped.is_empty():return false
			if index>=int(host().Frame.Ground.signed32(count)):break
			var expression:=read_word(block,8+index*4)
			if not stopped.is_empty():return false
			ip=cursor(expression)
			if ip<0:return false
			var condition:=boundary("F31",[slot],"local",ip)
			if condition.is_empty():return false
			if int(condition.return_u32)!=0:
				if boundary("F41",[slot],"local",int(condition.cursor_after_u32)).is_empty():return false
				if context.arena.decode_u32(at)!=3:return true
				index=0
			index+=1
		context.arena.encode_u32(at+8,context.arena.decode_u32(at+16));context.arena.encode_u32(at+12,context.arena.decode_u32(at+20))
		if boundary("F33",[slot,44]).is_empty():return false
		context.arena.encode_u32(at,1);return true
	func run(operation:String,args:Array)->Dictionary:
		order.append(operation);var value:=0;var completed:=true
		match operation:
			"F38":completed=cancel(int(args[0]))
			"F47":completed=callback(int(args[0]),int(args[1]))
			"F52":value=create(args);completed=stopped.is_empty()
			"F53":completed=initialize(int(args[0]))
		if not completed or not stopped.is_empty():return stopped
		if used!=observations.size():fail("unused_mission_task_observations");return stopped
		return {"ok":true,"profile":host().PROFILE,"context_after":host()._copy_context(context),"source_order":order.duplicate(),"requests":requests.duplicate(true),"observations_used":used,"return_defined":operation=="F52","return_u32":value,"return_s32":int(value) if value<0x80000000 else int(value)-0x100000000,"void_return_register_ignored":operation!="F52","live_owners_changed":false,"Main_integrated":false,"full_F41_executed":false}
