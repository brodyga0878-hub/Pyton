extends RefCounted
# Actual DOS F1103/F1102/F1101 and F61. The watched byte lives at4EED84,
# outside Root; Root+EF is a different field and must not be substituted.
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
const PROFILE:="dos-firstenc-player-module-events-v1"
const CONTEXT_KEYS:=["root","bank","event_registers","temporary_event_index_s32","watched_index_u8"]
const BUFFER_BYTES:={"root":16384,"bank":38986,"event_registers":284}
const PAYLOAD_KEYS:=["code_u32","body_slot_u32","index_u8"]
const CALLBACK_ARITY:={"F262":2,"F991":0,"F1097":2,"F1116":0,"F48":3,"F1104":1}
const MAX_OBSERVATIONS:=16
const MASK:=0xffffffff
static func _context(value:Variant)->bool:
	if not Frame._keys(value,CONTEXT_KEYS) or not Frame._whole(value.temporary_event_index_s32,-0x80000000,0x7fffffff) or not Frame._whole(value.watched_index_u8,0,255):return false
	for key:String in BUFFER_BYTES:
		if not value[key] is PackedByteArray or value[key].size()!=int(BUFFER_BYTES[key]):return false
	return true
static func _copy_context(value:Dictionary)->Dictionary:
	var result:Dictionary=value.duplicate(true);result.temporary_event_index_s32=int(value.temporary_event_index_s32);result.watched_index_u8=int(value.watched_index_u8);return result
static func _same_context(first:Variant,second:Dictionary)->bool:
	if not _context(first):return false
	for key:String in CONTEXT_KEYS:
		if first[key]!=second[key]:return false
	return true
static func _payload(value:Variant)->bool:
	return Frame._keys(value,PAYLOAD_KEYS) and Frame._whole(value.code_u32,0,MASK) and Frame._whole(value.body_slot_u32,0,114) and Frame._whole(value.index_u8,0,255)
static func _same_args(value:Variant,args:Array)->bool:
	if not value is Array or value.size()!=args.size():return false
	for index in range(args.size()):
		if not Frame._whole(value[index],-0x80000000,MASK) or (int(value[index])&MASK)!=(int(args[index])&MASK):return false
	return true
static func _observation(value:Variant)->bool:
	if not Frame._keys(value,["kind","args","before","after","return_u32"]) or not value.kind is String or not CALLBACK_ARITY.has(value.kind) or not value.args is Array or value.args.size()!=int(CALLBACK_ARITY[value.kind]) or not _context(value.before) or not _context(value.after) or not Frame._whole(value.return_u32,0,MASK):return false
	for arg:Variant in value.args:
		if not Frame._whole(arg,-0x80000000,MASK):return false
	return true
static func decode_context(value:Variant)->Dictionary:
	if not Frame._keys(value,CONTEXT_KEYS):return {}
	var result:Dictionary=value.duplicate(true)
	for key:String in BUFFER_BYTES:
		if result[key] is String and Frame._hex(result[key],int(BUFFER_BYTES[key])):result[key]=str(result[key]).hex_decode()
	return _copy_context(result) if _context(result) else {}
static func decode_observations(value:Variant)->Variant:
	if not value is Array or value.size()>MAX_OBSERVATIONS:return null
	var result:Array=value.duplicate(true)
	for row:Variant in result:
		if not Frame._keys(row,["kind","args","before","after","return_u32"]):return null
		for side:String in ["before","after"]:row[side]=decode_context(row[side])
		if not _observation(row):return null
	return result
static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false,"full_gameover_executed":false,"full_event_VM_executed":false}
static func execute(context:Variant,payload:Variant,observations:Variant=[],operation:Variant="F1103")->Dictionary:
	if not _context(context) or not _payload(payload) or not operation is String or operation not in ["F1103","F1102","F61"] or not observations is Array or observations.size()>MAX_OBSERVATIONS:return _reject("invalid_player_event_context")
	var runner:=Player.new();runner.context=_copy_context(context);runner.payload=payload.duplicate(true);runner.observations=observations.duplicate(true)
	return runner.run(operation)
static func _s8(value:int)->int:return (value&127)-(value&128)

class Player:
	var context:Dictionary
	var payload:Dictionary
	var observations:Array
	var used:=0
	var order:Array=[]
	var requests:Array=[]
	var stopped:Dictionary={}
	func fail(reason:String)->bool:
		var Host:GDScript=load("res://scripts/source_player_events.gd")
		stopped=Host._reject(reason);stopped["source_order"]=order.duplicate();stopped["observations_used"]=used;return false
	func boundary(kind:String,args:Array)->Dictionary:
		var Host:GDScript=load("res://scripts/source_player_events.gd");order.append(kind)
		var pending:Dictionary={"kind":kind,"args":args.duplicate(),"before":Host._copy_context(context)}
		if used>=observations.size():fail("boundary_required");stopped["pending"]=pending;return {}
		var row:Variant=observations[used]
		if not Host._observation(row) or row.kind!=kind or not Host._same_args(row.args,args) or not Host._same_context(row.before,pending.before):fail("unmatched_player_event_observation");return {}
		context=Host._copy_context(row.after);requests.append(row.duplicate(true));used+=1;return {"ok":true,"return_u32":int(row.return_u32)}
	func finish(value:int,defined:bool=true)->Dictionary:
		var Host:GDScript=load("res://scripts/source_player_events.gd")
		if used!=observations.size():fail("unused_player_event_observations");return stopped
		return {"ok":true,"profile":Host.PROFILE,"context_after":Host._copy_context(context),"return_u32":value&0xffffffff,"return_s32":Host.Ground.signed32(value),"return_defined":defined,"handler_return_consumed_by_F144":false,"source_order":order.duplicate(),"requests":requests.duplicate(true),"observations_used":used,"live_owners_changed":false,"Main_integrated":false,"full_gameover_executed":false,"full_event_VM_executed":false}
	func cleanup(index:int)->bool:
		var Host:GDScript=load("res://scripts/source_player_events.gd");order.append("F1101")
		if index==Host._s8(int(context.root[0xec])) or index==Host._s8(int(context.root[0xed])):
			if boundary("F1097",[0x98c2,0xffffffff]).is_empty():return false
		if index==Host._s8(int(context.root[0xec])):
			context.root[0xec]=0
			if (index&0xffffffff)!=context.root.decode_u32(0xc0) and int(context.root[0xe8])==2:
				context.root[0xe8]=0
				if boundary("F1116",[]).is_empty() or boundary("F48",[1,0,14]).is_empty():return false
		if index==Host._s8(int(context.root[0xed])):context.root[0xed]=0
		return true
	func run(operation:String)->Dictionary:
		var Host:GDScript=load("res://scripts/source_player_events.gd");var raw_index:=int(payload.index_u8);var index:int=Host._s8(raw_index)
		if operation=="F61":
			order.append("F61")
			# The skip branch leaves an unconsumed opaque payload pointer inEAX.
			# Portable state reports it as undefined, never as a fabricated pointer.
			if int(payload.code_u32)!=0:return finish(0,false)
			context.temporary_event_index_s32=index
			if boundary("F48",[22,0,index]).is_empty():return stopped
			context.temporary_event_index_s32=0;return finish(0)
		if operation=="F1103":order.append("F1103")
		order.append("F1102")
		if int(payload.code_u32)!=0:
			if (index&0xffffffff)==context.root.decode_u32(0xc0):context.root.encode_u32(0x10e,30)
			return finish(index)
		if raw_index==int(context.root[0x112]):context.root[0x112]=0
		if raw_index==int(context.watched_index_u8):
			context.watched_index_u8=0
			if int(context.root[0xea])==5:context.root[0xea]=0
			if boundary("F262",[20,0]).is_empty():return stopped
			var after:=boundary("F991",[])
			return finish(int(after.return_u32)) if not after.is_empty() else stopped
		if not cleanup(index):return stopped
		var after:=boundary("F1104",[index])
		return finish(int(after.return_u32)) if not after.is_empty() else stopped
