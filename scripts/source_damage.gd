extends RefCounted
# Whole DOS F953/F34/F35/F144/F148 orchestration. Module handlers, sound,
# equipment and fatal effects are matched explicit callback boundaries.
# The bounded owners contain 71 event words and 21 module entries. Actual
# model reads use catalog indices 0..148; unused model words stay opaque. Callback
# replies own the declared raw buffers and optional F148 packet words only;
# immutable model descriptors and other world globals are outside that reply.
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
const Rng=preload("res://scripts/source_global_rng.gd")
const PROFILE:="dos-firstenc-whole-f953-damage-v1"
const CONTEXT_KEYS:=["root","flags","event_registers","module_entries","module_count_s32","model_descriptors"]
const BYTE_COUNTS:={"root":0x4000,"flags":115,"event_registers":284,"module_entries":168}
const BODY_BYTES:=338
const MODULE_CAPACITY:=21
const EVENT_CAPACITY:=71
const HANDLER_MODULES:={2:[2,3,4,7,11,12,14,15,17,18,19,20],11:[3,11,17,20]}
const CALLBACK_ARITY:={"F48":3,"F144_handler":4,"F1907":2,"F942":2,"F952":1}
const MAX_OBSERVATIONS:=64
const MASK:=0xffffffff
static func _whole(value:Variant,low:int,high:int)->bool:return Frame._whole(value,low,high)
static func _keys(value:Variant,keys:Array)->bool:
	if not value is Dictionary or value.size()!=keys.size():return false
	for key:Variant in value:
		if not (key is String or key is StringName) or str(key) not in keys:return false
	return true
static func _body(value:Variant)->bool:return value is PackedByteArray and value.size()==BODY_BYTES
static func _model_key(value:Variant)->bool:
	return value is String and value.is_valid_int() and str(int(value))==value and _whole(int(value),0,MASK)
static func _context(value:Variant)->bool:
	if not _keys(value,CONTEXT_KEYS) or not _whole(value.module_count_s32,-0x80000000,MODULE_CAPACITY) or not value.model_descriptors is Dictionary or value.model_descriptors.size()>149:return false
	for key:String in BYTE_COUNTS:
		if not value[key] is PackedByteArray or value[key].size()!=int(BYTE_COUNTS[key]):return false
	for key:Variant in value.model_descriptors:
		if not _model_key(key) or not value.model_descriptors[key] is PackedByteArray or value.model_descriptors[key].size()!=68:return false
	return true
static func _copy_context(value:Dictionary)->Dictionary:
	var result:=value.duplicate(true);result.module_count_s32=int(value.module_count_s32);return result
static func _same_context(first:Variant,second:Dictionary)->bool:
	if not _context(first):return false
	for key:String in CONTEXT_KEYS:
		if first[key]!=second[key]:return false
	return true
static func _snapshot(value:Variant)->bool:return _keys(value,["body","context"]) and _body(value.body) and _context(value.context)
static func _same_snapshot(first:Variant,second:Dictionary)->bool:return _snapshot(first) and first.body==second.body and _same_context(first.context,second.context)
static func _same_args(value:Variant,expected:Array)->bool:
	if not value is Array or value.size()!=expected.size():return false
	for index in range(expected.size()):
		if not _whole(value[index],-0x80000000,MASK) or (int(value[index])&MASK)!=(int(expected[index])&MASK):return false
	return true
static func _observation(value:Variant)->bool:
	if not (_keys(value,["kind","args","before","after","return_u32"]) or _keys(value,["kind","args","before","after","return_u32","payload_after_u32"])) or not value.kind is String or not CALLBACK_ARITY.has(value.kind) or not value.args is Array or value.args.size()!=int(CALLBACK_ARITY[value.kind]) or not _snapshot(value.before) or not _snapshot(value.after) or not _whole(value.return_u32,0,MASK):return false
	for cell:Variant in value.args:
		if not _whole(cell,-0x80000000,MASK):return false
	if value.has("payload_after_u32"):
		if value.kind!="F144_handler" or int(value.args[1])!=2 or not value.payload_after_u32 is Array or value.payload_after_u32.size()!=2:return false
		for cell:Variant in value.payload_after_u32:
			if not _whole(cell,0,MASK):return false
	return value.before.context.model_descriptors==value.after.context.model_descriptors
static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false,"F953_body_executed":false,"full_world_damage":false}
static func decode_context(value:Variant)->Dictionary:
	if not _keys(value,CONTEXT_KEYS) or not value.model_descriptors is Dictionary:return {}
	var result:Dictionary=value.duplicate(true)
	for key:String in BYTE_COUNTS:
		if result[key] is String and Frame._hex(result[key],int(BYTE_COUNTS[key])):result[key]=str(result[key]).hex_decode()
	for key:Variant in result.model_descriptors:
		if result.model_descriptors[key] is String and Frame._hex(result.model_descriptors[key],68):result.model_descriptors[key]=str(result.model_descriptors[key]).hex_decode()
	return _copy_context(result) if _context(result) else {}
static func decode_observations(value:Variant)->Variant:
	if not value is Array or value.size()>MAX_OBSERVATIONS:return null
	var result:Array=value.duplicate(true)
	for row:Variant in result:
		if not (_keys(row,["kind","args","before","after","return_u32"]) or _keys(row,["kind","args","before","after","return_u32","payload_after_u32"])):return null
		for side:String in ["before","after"]:
			if not _keys(row[side],["body","context"]):return null
			if row[side].body is String and Frame._hex(row[side].body,BODY_BYTES):row[side].body=str(row[side].body).hex_decode()
			row[side].context=decode_context(row[side].context)
			if not _snapshot(row[side]):return null
		if not _observation(row):return null
	return result
static func execute(body:Variant,damage_s32:Variant,attacker_u32:Variant,context:Variant,observations:Variant=[])->Dictionary:
	if not _body(body) or not _whole(damage_s32,-0x80000000,0x7fffffff) or not _whole(attacker_u32,0,MASK) or not _context(context) or not observations is Array or observations.size()>MAX_OBSERVATIONS:return _reject("invalid_damage_context")
	var runner:=Damage.new();runner.body=body.duplicate();runner.context=_copy_context(context);runner.observations=observations.duplicate(true);runner.attacker=int(attacker_u32)
	return runner.run(int(damage_s32))

class Damage:
	var body:PackedByteArray
	var context:Dictionary
	var observations:Array
	var attacker:int
	var used:=0
	var order:Array=[]
	var requests:Array=[]
	var stopped:Dictionary={}
	var rng_calls:=0
	var model_calls:=0
	var broadcast_calls:=0
	var dispatcher_calls:=0
	var broadcast_payload:Array=[]
	func snapshot()->Dictionary:return {"body":body.duplicate(),"context":context.duplicate(true)}
	func fail(reason:String)->bool:
		var Host:GDScript=load("res://scripts/source_damage.gd")
		stopped=Host._reject(reason);stopped.observations_used=used;stopped.source_order=order.duplicate();return false
	func boundary(kind:String,args:Array)->Dictionary:
		var Host:GDScript=load("res://scripts/source_damage.gd")
		order.append(kind)
		var pending:Dictionary={"kind":kind,"args":args.duplicate(),"before":snapshot()}
		if used>=observations.size():fail("boundary_required");stopped.pending=pending;return {}
		var row:Variant=observations[used]
		if not Host._observation(row) or row.kind!=kind or not Host._same_args(row.args,args) or not Host._same_snapshot(row.before,pending.before):fail("unmatched_damage_observation");return {}
		if row.after.context.model_descriptors!=context.model_descriptors:fail("readonly_damage_models_changed");return {}
		body=row.after.body.duplicate();context=Host._copy_context(row.after.context);requests.append(row.duplicate(true));used+=1
		var reply:Dictionary={"ok":true,"return_u32":int(row.return_u32)}
		if row.has("payload_after_u32"):reply.payload_after_u32=[int(row.payload_after_u32[0]),int(row.payload_after_u32[1])]
		return reply
	func write_event(index:int,value:int)->bool:
		order.append("F34");context.event_registers.encode_u32(index*4,value&0xffffffff)
		return not boundary("F48",[2,0,index]).is_empty()
	func module_call(module:int,event:int,first:int,second:int)->bool:
		order.append("F144");dispatcher_calls+=1
		if module not in HANDLER_MODULES[event]:return true
		var reply:=boundary("F144_handler",[module,event,first,second])
		if reply.is_empty():return false
		if event==2 and reply.has("payload_after_u32"):broadcast_payload=reply.payload_after_u32.duplicate()
		return true
	func broadcast()->bool:
		order.append("F148");broadcast_calls+=1;broadcast_payload=[23,0]
		for module in range(21):
			if (int(context.module_entries[module*8])&2)!=0 and not module_call(module,2,int(broadcast_payload[0]),int(broadcast_payload[1])):return false
		return true
	func result(value:int)->Dictionary:
		var Host:GDScript=load("res://scripts/source_damage.gd")
		if used!=observations.size():fail("unused_damage_observations");return stopped
		return {"ok":true,"profile":Host.PROFILE,"body_after":body.duplicate(),"context_after":Host._copy_context(context),"return_u32":value&Host.MASK,"return_s32":Ground.signed32(value),"source_order":order.duplicate(),"requests":requests.duplicate(true),"observations_used":used,"rng_calls_u32":rng_calls,"model_calls_u32":model_calls,"broadcast_calls_u32":broadcast_calls,"dispatcher_calls_u32":dispatcher_calls,"F953_body_executed":true,"F34_body_executed":true,"F35_body_executed":true,"F144_body_executed":dispatcher_calls!=0,"F148_body_executed":broadcast_calls!=0,"F1530_body_executed":rng_calls!=0,"F942_body_executed":false,"F952_body_executed":false,"full_world_damage":false,"live_owners_changed":false,"Main_integrated":false}
	func finish_nonfatal()->Dictionary:
		if int(body[0x118])==255 and not broadcast():return stopped
		return result(1)
	func run(damage:int)->Dictionary:
		order.append("F953")
		var remaining:=0x7fffffff if damage<0 else damage
		if not write_event(13,int(body[0x86])) or not write_event(14,attacker) or not write_event(12,remaining):return stopped
		order.append("F35");remaining=context.event_registers.decode_s32(12*4)
		var module:=0
		while module<int(context.module_count_s32):
			if (int(context.module_entries[module*8])&4)!=0 and not module_call(module,11,1,int(body[0x86])):return stopped
			module+=1
		var eligible:=int(body[0x87])==3
		if int(body[0x87])==11:
			var index:=int(body[0x86])
			if index>=context.flags.size():fail("damage_flag_reference_outside_supplied_bank");return stopped
			if (int(context.flags[index])&16)==0:
				order.append("F1538");model_calls+=1
				var key:=str(body.decode_u32(0x82))
				if body.decode_u32(0x82)>=149:fail("unsupported_damage_model_index");return stopped
				if not context.model_descriptors.has(key):fail("damage_model_descriptor_unavailable");return stopped
				eligible=context.model_descriptors[key].decode_u32(0x38)!=0
		if not eligible:
			if boundary("F1907",[29,Ground.signed32(int(body[0x88])<<24)>>24]).is_empty():return stopped
			return result(1)
		var shield:=body.decode_u16(0xe0)
		if remaining<=shield:
			body.encode_u16(0xe0,(shield-remaining)&65535)
			if boundary("F1907",[28,Ground.signed32(int(body[0x88])<<24)>>24]).is_empty():return stopped
			body[0x151]=int(body[0x151])|1
			return finish_nonfatal()
		remaining=Ground.signed32(remaining-shield);body.encode_u16(0xe0,0)
		if remaining>=body.decode_u16(0xe4):
			var fatal:=boundary("F942",[int(body[0x86]),attacker])
			return stopped if fatal.is_empty() else result(Ground.signed32(int(fatal.return_u32)))
		body.encode_u16(0xe4,(body.decode_u16(0xe4)-remaining)&65535);body[0x14e]=10
		if boundary("F1907",[29,Ground.signed32(int(body[0x88])<<24)>>24]).is_empty():return stopped
		var quarter:=body.decode_u16(0xe4)>>2
		var equipment:=remaining>=quarter
		if not equipment:
			order.append("F1530");rng_calls+=1
			var random:=Rng.execute(context.root,"F1530");context.root=random.root_after
			var numerator:=Ground.signed32(remaining<<15)
			# This branch has 0<remaining<quarter<=16383 in ordinary source
			# states. A filtered negative amount takes the earlier shield path.
			var threshold:int=absi(numerator)/quarter
			if numerator<0:threshold=-threshold
			equipment=int(random.return_u32)<(threshold&0xffffffff)
		if equipment:
			var damage_equipment:=boundary("F952",[int(body[0x86])])
			return stopped if damage_equipment.is_empty() else result(Ground.signed32(int(damage_equipment.return_u32)))
		return finish_nonfatal()
