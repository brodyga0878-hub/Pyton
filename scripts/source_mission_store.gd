extends RefCounted
# Whole DOS F37 assignment caller. Its external services are exact observations;
# Root composition closes the existing expression, register, event and model bodies.
const Expr=preload("res://scripts/source_mission_expression.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const PROFILE:="dos-firstenc-mission-store-v1"
const MASK:=0xffffffff
const TASK_BASE:=0x60bf50
const CONTEXT_KEYS:=["root","root_tail","bank","event_registers","module_globals","task_variables","program","ip_u32","module_global_offset_u32","temporary_event_index_s32","task_slot_u32","descriptor_ref_u32","market_buffer"]
const PROVIDERS:={"F31":1,"F22":2,"F34":2,"F36":2,"F48":3,"F390":2,"F391":2,"F392":2,"F441":3,"F649":1}
const VOID_PROVIDERS:=["F22","F34","F36","F48","F441"]
const SELECTOR_MAP:=[0,0,0,17,16,15,14,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,13,0,0,12,11,10,9,0,0,8,7,0,0,0,0,0,0,6,0,0,0,0,0,0,0,5,0,0,0,0,4,3,0,0,2,1]
const MAX_OBSERVATIONS:=256
const MAX_LOOP_STEPS:=4096
static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false,"full_mission_VM_executed":false}
static func _expression_view(value:Dictionary)->Dictionary:
	var result:Dictionary={}
	for key:String in Expr.CONTEXT_KEYS:result[key]=value[key]
	return result
static func _context(value:Variant)->bool:
	if not Expr._keys(value,CONTEXT_KEYS) or not Frame._whole(value.task_slot_u32,0,149) or not Frame._whole(value.descriptor_ref_u32,1,MASK) or not value.market_buffer is PackedByteArray or value.market_buffer.size()!=308:return false
	return Expr._context(_expression_view(value))
static func _copy_context(value:Variant)->Dictionary:
	if not _context(value):return {}
	var result:=Expr._copy_context(_expression_view(value))
	result["task_slot_u32"]=int(value.task_slot_u32);result["descriptor_ref_u32"]=int(value.descriptor_ref_u32);result["market_buffer"]=value.market_buffer.duplicate();return result
static func _same_context(first:Variant,second:Dictionary)->bool:
	if not _context(first):return false
	for key:String in CONTEXT_KEYS:
		if first[key]!=second[key]:return false
	return true
static func decode_context(value:Variant)->Dictionary:
	if not Expr._keys(value,CONTEXT_KEYS) or not Frame._whole(value.task_slot_u32,0,149) or not Frame._whole(value.descriptor_ref_u32,1,MASK):return {}
	var result:=Expr.decode_context(_expression_view(value))
	if result.is_empty():return {}
	var raw:Variant=value.market_buffer
	if raw is PackedByteArray and raw.size()==308:result["market_buffer"]=raw.duplicate()
	elif Frame._hex(raw,308):result["market_buffer"]=str(raw).hex_decode()
	else:return {}
	result["task_slot_u32"]=int(value.task_slot_u32);result["descriptor_ref_u32"]=int(value.descriptor_ref_u32)
	return _copy_context(result)
static func _observation(value:Variant)->bool:
	if not Expr._keys(value,["kind","args","before","after","return_u32","input_hex","output_hex"]) or not value.kind is String or not PROVIDERS.has(value.kind) or not Expr._words(value.args,int(PROVIDERS[value.kind])) or not Frame._whole(value.return_u32,0,MASK) or value.input_hex!="" or value.output_hex!="" or not _context(value.before) or not _context(value.after):return false
	for key:String in ["program","module_global_offset_u32","task_slot_u32","descriptor_ref_u32"]:
		if value.before[key]!=value.after[key]:return false
	if value.kind!="F31" and int(value.before.ip_u32)!=int(value.after.ip_u32):return false
	if value.before.task_variables.size()!=value.after.task_variables.size():return false
	if value.kind in VOID_PROVIDERS and int(value.return_u32)!=0:return false
	return value.kind!="F649" or int(value.return_u32) in [0,1]
static func decode_observations(value:Variant)->Variant:
	if not value is Array or value.size()>MAX_OBSERVATIONS:return null
	var result:Array=[]
	for row:Variant in value:
		if not Expr._keys(row,["kind","args","before","after","return_u32","input_hex","output_hex"]) or not row.kind is String or not PROVIDERS.has(row.kind) or not Expr._words(row.args,int(PROVIDERS[row.kind])) or not Frame._whole(row.return_u32,0,MASK) or row.input_hex!="" or row.output_hex!="":return null
		var copy:Dictionary={"kind":row.kind,"args":[],"before":decode_context(row.before),"after":decode_context(row.after),"return_u32":int(row.return_u32),"input_hex":"","output_hex":""}
		for word:Variant in row.args:copy.args.append(int(word))
		if not _observation(copy):return null
		result.append(copy)
	return result
static func execute(context:Variant,value_u32:Variant,observations:Variant=[])->Dictionary:
	if not _context(context) or not Frame._whole(value_u32,0,MASK) or not observations is Array or observations.size()>MAX_OBSERVATIONS:return _reject("invalid_mission_store_context")
	for row:Variant in observations:
		if not _observation(row):return _reject("invalid_mission_store_observation")
	var runner:=Store.new();runner.context=_copy_context(context);runner.observations=observations.duplicate(true);return runner.run(int(value_u32))

class Store:
	var context:Dictionary
	var observations:Array
	var used:=0
	var order:Array=[]
	var requests:Array=[]
	var stopped:Dictionary={}
	var loop_steps:=0
	func host()->GDScript:return load("res://scripts/source_mission_store.gd")
	func fail(reason:String)->bool:
		if stopped.is_empty():stopped=host()._reject(reason);stopped["source_order"]=order.duplicate();stopped["observations_used"]=used
		return false
	func span(buffer:PackedByteArray,offset:int,width:int)->bool:
		return true if offset>=0 and width>=0 and offset+width<=buffer.size() else fail("mission_store_memory_out_of_bounds")
	func word()->int:
		if not span(context.program,int(context.ip_u32),4):return 0
		order.append("F20");var value:int=context.program.decode_u32(int(context.ip_u32));context.ip_u32=int(context.ip_u32)+4;return value
	func boundary(kind:String,args:Array)->Dictionary:
		if not stopped.is_empty():return {}
		order.append(kind);var pending:Dictionary={"kind":kind,"args":args.duplicate(),"before":host()._copy_context(context),"input_hex":""}
		if used>=observations.size():fail("boundary_required");stopped["pending"]=pending;return {}
		var row:Variant=observations[used]
		if not host()._observation(row) or row.kind!=kind or not host()._same_context(row.before,context) or row.args.size()!=args.size():fail("unmatched_mission_store_observation");return {}
		for index in range(args.size()):
			if int(row.args[index])!=int(args[index]):fail("unmatched_mission_store_arguments");return {}
		context=host()._copy_context(row.after);requests.append(row.duplicate(true));used+=1;return {"ok":true,"return_u32":int(row.return_u32)}
	func expression()->int:
		var result:=boundary("F31",[int(context.task_slot_u32)]);return int(result.return_u32) if result.get("ok",false) else 0
	func event(kind:int,key_a:int,key_b:int)->void:boundary("F48",[kind&0xffffffff,key_a&0xffffffff,key_b&0xffffffff])
	func body_offset(slot:int)->int:
		order.append("F1532")
		if slot<0 or slot>114:fail("mission_store_body_index_out_of_bounds");return -1
		return 116+slot*338
	func equip(slot:int,item:int,value:int)->void:
		var current:=boundary("F392",[slot,item])
		if current.is_empty():return
		var delta:int=Expr._s32(value-int(current.return_u32))
		while delta!=0:
			loop_steps+=1
			if loop_steps>MAX_LOOP_STEPS:fail("mission_store_equipment_loop_profile_limit");return
			var result:=boundary("F390" if delta>0 else "F391",[slot,item])
			if result.is_empty() or int(result.return_u32)!=0:return
			delta+=-1 if delta>0 else 1
	func cargo(body:int,item:int,value:int)->void:
		if body!=context.root.decode_u32(0xc8) or item>=38:return
		if item<0:fail("mission_store_cargo_index_out_of_bounds");return
		var at:=0x134+item*2;var old:int=context.root.decode_u16(at);var delta:int=Expr._s32(value-old)
		if delta>0:
			var used_word:int=context.root.decode_u32(0x120);var total:int=Expr._s32(used_word+delta)
			if total>context.root.decode_s32(0x118):delta=Expr._s32(context.root.decode_u32(0x118)-used_word)
		elif Expr._s32(value)<0:delta=-old
		context.root.encode_u32(0x120,(context.root.decode_u32(0x120)+delta)&0xffffffff)
		context.root.encode_u16(at,(context.root.decode_u16(at)+delta)&65535)
	func finish()->Dictionary:
		if not stopped.is_empty():return stopped
		if used!=observations.size():fail("unused_mission_store_observations");return stopped
		return {"ok":true,"profile":PROFILE,"context_after":host()._copy_context(context),"return_u32":0,"return_defined":false,"scalar_return_defined":false,"void_return_register_ignored":true,"source_order":order.duplicate(),"requests":requests.duplicate(true),"observations_used":used,"equipment_loop_steps_u32":loop_steps,"live_owners_changed":false,"Main_integrated":false,"full_mission_VM_executed":false}
	func run(value:int)->Dictionary:
		order.append("F37")
		if not span(context.program,int(context.ip_u32),1):return stopped
		var selector:int=context.program[int(context.ip_u32)];context.ip_u32=int(context.ip_u32)+1
		var branch:int=SELECTOR_MAP[selector] if selector<=66 else 0
		match branch:
			17,16:
				var index:=word()
				if stopped.is_empty():boundary("F22" if branch==17 else "F34",[index,value])
			15,14:
				var index:=word()
				if not stopped.is_empty():return stopped
				if branch==15:
					if int(context.module_global_offset_u32)==0xffffffff:fail("unbound_mission_store_globals");return stopped
					var at:=int(context.module_global_offset_u32)+index*4
					if not span(context.module_globals,at,4):return stopped
					context.module_globals.encode_u32(at,value);event(3,int(context.descriptor_ref_u32),index)
				else:
					var at:=index*4
					if not span(context.task_variables,at,4):return stopped
					context.task_variables.encode_u32(at,value);event(4,TASK_BASE+int(context.task_slot_u32)*36,index)
			13,11,6:
				var index:int=Expr._s32(expression())
				if not stopped.is_empty():return stopped
				if index>=0 and index<6:
					if branch==13:context.root_tail.encode_u32(0x10e0+index*4,value);event(21,0,index)
					elif branch==11:context.root_tail.encode_u32(0x10f8+index*4,value);event(10,0,index)
					else:context.root.encode_u32(0x184+index*4,value);event(17,0,index)
			10:
				var slot:=expression()
				if not stopped.is_empty():return stopped
				var at:=body_offset(slot)
				if at<0:return stopped
				boundary("F441",[slot,value,context.bank.decode_u32(at+0xa0)])
			9:
				var slot:=expression()
				if not stopped.is_empty():return stopped
				var body:=body_offset(slot)
				if body<0:return stopped
				var item:int=Expr._s32(expression())
				if not stopped.is_empty():return stopped
				if item<1000:equip(slot,(item-100)&0xffffffff,value)
				else:cargo(body,item-1000,value)
			5,4,3,2:
				var slot:=expression()
				if not stopped.is_empty():return stopped
				var at:=body_offset(slot)
				if at<0:return stopped
				if branch==5:context.bank.encode_u32(at+0xa0,value)
				elif branch==4:boundary("F36",[slot,value])
				elif branch==3:
					# Actual DOS has no later JJFFE F1538/physical-null guard here.
					context.bank[at+0xff]=value&255;event(23,0,slot)
				else:context.bank[at+0xfe]=value&255
			1:
				var system:=expression()
				if not stopped.is_empty():return stopped
				var index:int=Expr._s32(expression()-1000)
				if not stopped.is_empty():return stopped
				var result:=boundary("F649",[system])
				if not result.is_empty() and int(result.return_u32)!=0 and index>=0 and index<38:
					context.market_buffer.encode_u32(index*8+4,value);event(24,system,index+1000)
		return finish()
