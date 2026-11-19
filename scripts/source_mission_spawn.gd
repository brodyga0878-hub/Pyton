extends RefCounted
# Whole uploaded-DOS F39/F40 caller with exact bank lookup, phase arithmetic
# and orientation. Allocation and the DOS position worker remain typed calls.
# F1507 is deliberately not replaced with the later JJFFE orbital algorithm.
const Safe=preload("res://scripts/source_mission_services.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Expr=preload("res://scripts/source_mission_expression.gd")
const Orbit=preload("res://scripts/source_orbit.gd")
const Rotation=preload("res://scripts/body_rotation.gd")
const PROFILE:="dos-firstenc-mission-spawn-v1"
const MASK:=0xffffffff
const CONTEXT_KEYS:=["root","root_tail","bank"]
const BYTE_COUNTS:={"root":16384,"root_tail":6160,"bank":38986}
const OBSERVATION_KEYS:=["kind","args","before","after","return_u32","input_hex","output_hex"]
const MAX_OBSERVATIONS:=2
static func _whole(value:Variant,low:int,high:int)->bool:return Frame._whole(value,low,high)
static func _keys(value:Variant,keys:Array)->bool:return Expr._keys(value,keys)
static func _reference(value:Variant,allow_null:bool=true)->bool:
	return _whole(value,0,MASK) and ((allow_null and int(value)==0) or (int(value)>=116 and int(value)<=116+114*338 and (int(value)-116)%338==0))
static func _context(value:Variant)->bool:
	if not Safe._plain(value) or not _keys(value,CONTEXT_KEYS):return false
	for key:String in BYTE_COUNTS:
		if not value[key] is PackedByteArray or value[key].size()!=int(BYTE_COUNTS[key]):return false
	return value.root_tail.decode_u32(0x180c)==1 and _reference(value.root.decode_u32(0xc8)) and _reference(value.root.decode_u32(0xcc))
static func _copy_context(value:Dictionary)->Dictionary:
	if not _context(value):return {}
	return {"root":value.root.duplicate(),"root_tail":value.root_tail.duplicate(),"bank":value.bank.duplicate()}
static func decode_context(value:Variant)->Dictionary:
	if not Safe._plain(value) or not _keys(value,CONTEXT_KEYS):return {}
	var result:Dictionary={}
	for key:String in BYTE_COUNTS:
		var raw:Variant=value[key]
		if raw is PackedByteArray and raw.size()==int(BYTE_COUNTS[key]):result[key]=raw.duplicate()
		elif Frame._hex(raw,int(BYTE_COUNTS[key])):result[key]=str(raw).hex_decode()
		else:return {}
	return _copy_context(result)
static func _same_context(first:Variant,second:Dictionary)->bool:
	return _context(first) and first.root==second.root and first.root_tail==second.root_tail and first.bank==second.bank
static func _observation(value:Variant)->bool:
	if not Safe._plain(value) or not _keys(value,OBSERVATION_KEYS) or not value.kind is String or value.kind not in ["F927","F1507"] or not Expr._words(value.args,4) or not _context(value.before) or not _context(value.after) or not _whole(value.return_u32,0,MASK) or value.input_hex!="" or not value.output_hex is String:return false
	if value.kind=="F927":
		return int(value.args[0])==1 and _reference(value.args[1],false) and int(value.args[2])==29 and _reference(value.return_u32) and (value.output_hex=="" or Frame._hex(value.output_hex,4))
	return _reference(value.args[0],false) and int(value.return_u32)==0 and value.output_hex==""
static func decode_observations(value:Variant)->Variant:
	if not Safe._plain(value) or not value is Array or value.size()>MAX_OBSERVATIONS:return null
	var result:Array=[]
	for raw:Variant in value:
		if not _keys(raw,OBSERVATION_KEYS) or not raw.kind is String or not Expr._words(raw.args,4) or not _whole(raw.return_u32,0,MASK) or raw.input_hex!="" or not raw.output_hex is String:return null
		var row:Dictionary={"kind":raw.kind,"args":[],"before":decode_context(raw.before),"after":decode_context(raw.after),"return_u32":int(raw.return_u32),"input_hex":"","output_hex":raw.output_hex}
		for word:Variant in raw.args:row.args.append(int(word))
		if not _observation(row):return null
		result.append(row)
	return result
static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false,"full_F1507_executed":false,"full_F927_executed":false}
static func execute(context:Variant,operation:Variant,args:Variant=[],observations:Variant=[])->Dictionary:
	if not Safe._plain(args) or not Safe._plain(observations) or not _context(context) or not operation is String or operation not in ["F39","F40"] or not Expr._words(args,1 if operation=="F39" else 9) or not observations is Array or observations.size()>MAX_OBSERVATIONS:return _reject("invalid_mission_spawn_command")
	if operation=="F40" and int(args[1])>114:return _reject("mission_spawn_parent_slot_outside_bank")
	for row:Variant in observations:
		if not _observation(row):return _reject("invalid_mission_spawn_observation")
	var runner:=Spawn.new();runner.context=_copy_context(context);runner.observations=observations.duplicate(true)
	return runner.run(operation,args)
class Spawn:
	var context:Dictionary
	var observations:Array=[]
	var used:=0
	var order:Array=[]
	var requests:Array=[]
	var stopped:Dictionary={}
	func host()->GDScript:return load("res://scripts/source_mission_spawn.gd")
	func fail(reason:String)->bool:
		if stopped.is_empty():stopped=host()._reject(reason);stopped["source_order"]=order.duplicate();stopped["observations_used"]=used
		return false
	func boundary(kind:String,args:Array)->Dictionary:
		order.append(kind);var pending:Dictionary={"kind":kind,"args":args.duplicate(),"before":host()._copy_context(context),"input_hex":""}
		if used>=observations.size():fail("boundary_required");stopped["pending"]=pending;return {}
		var row:Dictionary=observations[used]
		if row.kind!=kind or not host()._same_context(row.before,context) or row.args.size()!=args.size():fail("unmatched_mission_spawn_observation");return {}
		for index in range(args.size()):
			if int(row.args[index])!=int(args[index]):fail("unmatched_mission_spawn_arguments");return {}
		context=host()._copy_context(row.after);requests.append(row.duplicate(true));used+=1
		return {"return_u32":int(row.return_u32)}
	func run(operation:String,args:Array)->Dictionary:
		order.append(operation);var returned:=int(args[0])
		if operation=="F40":
			order.append("F1532");var source_ref:=116+int(args[1])*338
			var allocated:=boundary("F927",[1,source_ref,29,int(args[0])])
			if allocated.is_empty():return stopped
			returned=int(allocated.return_u32)
			if returned!=0:
				# The source holds this body pointer across every later callback.
				var at:=returned
				context.bank.encode_u32(at+0xa0,int(args[2]));context.bank[at+0x56]=int(args[1])&255;context.bank.encode_u16(at+0xda,0xfffc)
				context.bank.encode_u32(at+0xa8,context.root.decode_u32(0));context.bank.encode_u32(at+0xac,context.root.decode_u32(4));context.bank.encode_u32(at+0xc2,int(args[5]))
				order.append_array(["F1510","F1509","F1338"])
				# F40 pushes day before tick: F1510 receives NEW high=tick,
				# low=day. The exact DOS primitive is independent of Q31 F1507.
				var phase:=Orbit.phase_delta(int(args[5]),0,0,context.root.decode_u32(4),context.root.decode_u32(0))
				context.bank.encode_u32(at+0xba,phase[0]);context.bank.encode_u32(at+0xbe,phase[1])
				context.bank.encode_u32(at+0xbe,(context.bank.decode_u32(at+0xbe)+((int(args[4])<<16)&MASK))&MASK)
				context.bank.encode_u32(at+0xa4,0);context.bank.encode_u16(at+0xc6,int(args[6])&65535);context.bank[at+0x87]=1;context.bank.encode_u32(at+0xb0,int(args[3]))
				if boundary("F1507",[at,int(args[3]),Rotation.signed16(int(args[6]))&MASK,context.bank.decode_u32(at+0xbe)]).is_empty():return stopped
				context.bank.encode_u16(at+0xcc,int(args[8])&65535);context.bank[at+0xc8]=int(args[7])&255
				var first: int=(context.bank.decode_u32(at+0xa8)<<(int(args[7])&31))&MASK
				var second:int=context.bank.decode_s16(at+0xcc)
				order.append_array(["F1675","F1914","F1914","F1914","F1914","F1521","F1521","F1521","F1521"])
				var matrix:=Rotation.matrix_yzt(first,second)
				for index in range(9):context.bank.encode_s32(at+index*4,matrix[index])
		if used!=observations.size():fail("unused_mission_spawn_observations");return stopped
		if not host()._context(context):fail("invalid_mission_spawn_result");return stopped
		return {"ok":true,"profile":host().PROFILE,"context_after":host()._copy_context(context),"return_u32":returned,"return_defined":true,"scalar_return_defined":operation=="F39","pointer_return_defined":operation=="F40","pointer_result_kind":"logical_bank_offset" if operation=="F40" else "","source_order":order.duplicate(),"requests":requests.duplicate(true),"observations_used":used,"F1510_body_executed":operation=="F40" and returned!=0,"F1675_body_executed":operation=="F40" and returned!=0,"full_F1507_executed":false,"full_F927_executed":false,"live_owners_changed":false,"Main_integrated":false}
