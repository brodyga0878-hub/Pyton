extends RefCounted
# Whole DOS F32/F33 guard walk and F34/F35 event-register access.
# Source resource/task addresses are logical original-DOS tokens, never host pointers.
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
const PROFILE:="dos-firstenc-mission-guards-v1"
const CONTEXT_KEYS:=["event_registers","program","program_base_u32","ip_u32","task_record","task_slot_u32","metadata"]
const METADATA_SHA:="fa9ea4bbb6b062b426e0c56299b0aa1a646341a7355bb51aa5cad574cc8670b0"
const TASK_BASE:=0x60bf50
const F47_WORD:=0x413ff4
const MAX_DEPTH:=128
const MAX_STEPS:=8192
const MAX_OBSERVATIONS:=256
const MASK:=0xffffffff
static func _context(value:Variant)->bool:
	if not Frame._keys(value,CONTEXT_KEYS) or not Frame._whole(value.program_base_u32,1,MASK) or not Frame._whole(value.ip_u32,0,65536) or not Frame._whole(value.task_slot_u32,0,149):return false
	if not value.event_registers is PackedByteArray or value.event_registers.size()!=284 or not value.task_record is PackedByteArray or value.task_record.size()!=36 or not value.metadata is PackedByteArray or value.metadata.size()!=1088 or not value.program is PackedByteArray or value.program.is_empty() or value.program.size()>65536 or int(value.ip_u32)>value.program.size() or int(value.program_base_u32)+value.program.size()>0x100000000:return false
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(value.metadata)
	return hash.finish().hex_encode()==METADATA_SHA
static func _copy_context(value:Dictionary)->Dictionary:
	var result:Dictionary=value.duplicate(true)
	for field:String in ["program_base_u32","ip_u32","task_slot_u32"]:result[field]=int(result[field])
	return result
static func _same_context(first:Variant,second:Dictionary)->bool:
	if not _context(first):return false
	for key:String in CONTEXT_KEYS:
		if first[key]!=second[key]:return false
	return true
static func decode_context(value:Variant)->Dictionary:
	if not Frame._keys(value,CONTEXT_KEYS):return {}
	var result:Dictionary={}
	for field:String in ["program_base_u32","ip_u32","task_slot_u32"]:
		if not Frame._whole(value[field],0,MASK):return {}
		result[field]=int(value[field])
	for field:String in ["event_registers","task_record","metadata","program"]:
		var raw:Variant=value[field];var maximum:=65536 if field=="program" else 284 if field=="event_registers" else 36 if field=="task_record" else 1088
		if raw is PackedByteArray:
			if raw.size()>maximum:return {}
			result[field]=raw.duplicate()
		elif raw is String and raw.length()<=maximum*2 and raw.length()%2==0 and Frame._hex(raw,raw.length()/2):result[field]=str(raw).hex_decode()
		else:return {}
	return _copy_context(result) if _context(result) else {}
static func _args(value:Variant,count:int)->bool:
	if not value is Array or value.size()!=count:return false
	for word:Variant in value:
		if not Frame._whole(word,0,MASK):return false
	return true
static func _observation(value:Variant)->bool:
	if not Frame._keys(value,["kind","args","before","after","return_u32"]) or not value.kind is String or value.kind not in ["F31","F44","F45","F48"] or not _context(value.before) or not _context(value.after) or not Frame._whole(value.return_u32,0,MASK):return false
	if not _args(value.args,1 if value.kind=="F31" else 3 if value.kind=="F48" else 6):return false
	for field:String in ["program","program_base_u32","metadata","task_slot_u32"]:
		if value.before[field]!=value.after[field]:return false
	return true
static func decode_observations(value:Variant)->Variant:
	if not value is Array or value.size()>MAX_OBSERVATIONS:return null
	var result:Array=[]
	for row:Variant in value:
		if not Frame._keys(row,["kind","args","before","after","return_u32"]) or not row.kind is String or row.kind not in ["F31","F44","F45","F48"] or not _args(row.args,1 if row.kind=="F31" else 3 if row.kind=="F48" else 6) or not Frame._whole(row.return_u32,0,MASK):return null
		var decoded:Dictionary={"kind":row.kind,"args":row.args.duplicate(),"before":decode_context(row.before),"after":decode_context(row.after),"return_u32":int(row.return_u32)}
		if not _observation(decoded):return null
		result.append(decoded)
	return result
static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false,"full_mission_VM_executed":false}
static func execute(context:Variant,operation:Variant,args:Variant=[],observations:Variant=[])->Dictionary:
	if not _context(context) or not operation is String or operation not in ["F32","F33","F34","F35"] or not args is Array or not observations is Array or observations.size()>MAX_OBSERVATIONS:return _reject("invalid_mission_guard_command")
	for row:Variant in observations:
		if not _observation(row):return _reject("invalid_mission_guard_observations")
	if operation in ["F32","F33"]:
		if args.size()!=(2 if operation=="F32" else 1) or not args[0] is String or args[0] not in ["F44","F45"] or (operation=="F32" and not Frame._whole(args[1],0,MASK)):return _reject("invalid_guard_registration_command")
	elif not _args(args,2 if operation=="F34" else 1) or int(args[0])>=71:return _reject("invalid_event_register_command")
	var runner:=Guard.new();runner.context=_copy_context(context);runner.observations=observations.duplicate(true)
	return runner.run(operation,args)

class Guard:
	var context:Dictionary
	var observations:Array
	var used:=0
	var steps:=0
	var order:Array=[]
	var requests:Array=[]
	var stopped:Dictionary={}
	func fail(reason:String)->bool:
		var Host:GDScript=load("res://scripts/source_mission_guards.gd")
		stopped=Host._reject(reason);stopped["source_order"]=order.duplicate();stopped["observations_used"]=used;return false
	func span(offset:int,count:int)->bool:
		if offset<0 or count<0 or offset+count>context.program.size():return fail("program_span_outside_resource")
		return true
	func offset_for(reference:int,count:int)->int:
		var offset:=reference-int(context.program_base_u32)
		if not span(offset,count):return -1
		return offset
	func word()->int:
		if not span(int(context.ip_u32),4):return 0
		order.append("F20");var value:int=context.program.decode_u32(int(context.ip_u32));context.ip_u32=int(context.ip_u32)+4;return value
	func boundary(kind:String,args:Array)->Dictionary:
		var Host:GDScript=load("res://scripts/source_mission_guards.gd");order.append(kind)
		var pending:Dictionary={"kind":kind,"args":args.duplicate(),"before":Host._copy_context(context)}
		if used>=observations.size():fail("boundary_required");stopped["pending"]=pending;return {}
		var row:Variant=observations[used]
		if not Host._observation(row) or row.kind!=kind or not Host._args(row.args,args.size()):fail("invalid_guard_observation");return {}
		for index in range(args.size()):
			if int(row.args[index])!=int(args[index]):fail("unmatched_guard_observation_args");return {}
		if not Host._same_context(row.before,pending.before):fail("unmatched_guard_observation_before");return {}
		context=Host._copy_context(row.after);requests.append(row.duplicate(true));used+=1
		return {"ok":true,"return_u32":int(row.return_u32)}
	func walk(registration:String,clause:int,depth:int=0)->bool:
		var Host:GDScript=load("res://scripts/source_mission_guards.gd")
		steps+=1
		if depth>=Host.MAX_DEPTH or steps>Host.MAX_STEPS:return fail("guard_walk_profile_limit")
		order.append("F32")
		if not span(int(context.ip_u32),1):return false
		var token:int=context.program[int(context.ip_u32)];context.ip_u32=int(context.ip_u32)+1
		if token>=68:return fail("metadata_selector_outside_table")
		var at:=token*16;var event:int=Ground.signed32(context.metadata.decode_u32(at+4))
		if event>0:
			var saved_ip:int=context.ip_u32;var key_a:=0;var key_b:=0
			match int(context.metadata.decode_u32(at+8)):
				0:key_a=0
				1:key_a=context.task_record.decode_u32(28)
				2:key_a=Host.TASK_BASE+int(context.task_slot_u32)*36
				3:
					var result:=boundary("F31",[int(context.task_slot_u32)])
					if result.is_empty():return false
					key_a=int(result.return_u32)
				_:return fail("undefined_guard_key_a_mode")
			match int(context.metadata.decode_u32(at+12)):
				0:key_b=0
				1:
					key_b=word()
					if not stopped.is_empty():return false
				2:
					var result:=boundary("F31",[int(context.task_slot_u32)])
					if result.is_empty():return false
					key_b=int(result.return_u32)
				_:return fail("undefined_guard_key_b_mode")
			var called:=boundary(registration,[event&MASK,key_a&MASK,key_b&MASK,Host.F47_WORD,Host.TASK_BASE+int(context.task_slot_u32)*36,clause&MASK])
			if called.is_empty():return false
			context.ip_u32=saved_ip
		var operands:int=Ground.signed32(context.metadata.decode_u32(at))
		if operands>0:
			for index in range(operands):
				if not walk(registration,clause,depth+1):return false
		else:
			if not span(int(context.ip_u32),4):return false
			context.ip_u32=int(context.ip_u32)+4
		return true
	func run(operation:String,args:Array)->Dictionary:
		var Host:GDScript=load("res://scripts/source_mission_guards.gd");var value:=0;var entry_ip:int=context.ip_u32
		if operation=="F32":
			if not walk(str(args[0]),int(args[1])):return stopped
		elif operation=="F33":
			order.append("F33");var index:=0
			while true:
				var block:=offset_for(context.task_record.decode_u32(8),8)
				if block<0:return stopped
				var count:int=Ground.signed32(context.program.decode_u32(block+4))
				if index>=count:break
				if index>=MAX_STEPS or not span(block+8+index*4,4):fail("guard_block_profile_limit");return stopped
				context.ip_u32=offset_for(context.program.decode_u32(block+8+index*4),1)
				if int(context.ip_u32)<0:return stopped
				if not walk(str(args[0]),index):return stopped
				index+=1
			# F33 owns a local cursor for each clause; no caller IP is an argument.
			context.ip_u32=entry_ip
		else:
			order.append(operation)
			if operation=="F34":
				context.event_registers.encode_u32(int(args[0])*4,int(args[1]))
				if boundary("F48",[2,0,int(args[0])]).is_empty():return stopped
			else:value=context.event_registers.decode_u32(int(args[0])*4)
		if used!=observations.size():fail("unused_guard_observations");return stopped
		return {"ok":true,"profile":Host.PROFILE,"context_after":Host._copy_context(context),"source_order":order.duplicate(),"requests":requests.duplicate(true),"observations_used":used,"return_defined":operation=="F35","return_u32":value,"return_s32":Ground.signed32(value),"void_return_register_ignored":operation!="F35","live_owners_changed":false,"Main_integrated":false,"full_mission_VM_executed":false}
