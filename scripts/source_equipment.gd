extends RefCounted
# Original F952/F943..951/F933 over one raw Root and target record. Message
# rendering and non-null module bodies remain typed matched continuations.
const Damage=preload("res://scripts/source_damage.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
const Rng=preload("res://scripts/source_global_rng.gd")
const PROFILE:="dos-firstenc-equipment-f952-v1"
const CONTEXT_KEYS:=["root","flags","event_registers","module_entries","module_count_s32","model_descriptors","physical_specs"]
const BYTE_COUNTS:={"root":16384,"flags":115,"event_registers":284,"module_entries":168}
const OPERATIONS:=["F933","F943","F944","F945","F946","F947","F948","F949","F950","F951","F952"]
const DRIVE_MASSES:=[0,4,10,25,45,80,150,250,400,600,6,12,24,36,0]
const EQUIPMENT_NAMES:=[0x9888,0x9888,0x9889,0x988c,0x9892,0x988d,0x988b,0x989c,0x988f,0x98a7,0x989e,0x989f,0x9899,0x9893,0x9884,0x989d,0x9887,0x9883,0x98b2,0x98b0,0x98b1,0x9885,0x9886,0x9880,0x98b3,0x987f,0x9898,0x9881,0x9882,0x98b4]
const HANDLER_MODULES:=[2,3,4,7,11,12,14,15,17,18,19,20]
const MAX_OBSERVATIONS:=96
const MASK:=0xffffffff
static func _whole(value:Variant,low:int,high:int)->bool:return Frame._whole(value,low,high)
static func _keys(value:Variant,keys:Array)->bool:return Damage._keys(value,keys)
static func _body(value:Variant)->bool:return value is PackedByteArray and value.size()==338
static func _context(value:Variant)->bool:
	if not _keys(value,CONTEXT_KEYS) or not value.physical_specs is Dictionary or value.physical_specs.size()>149:return false
	var base:Dictionary=value.duplicate();base.erase("physical_specs")
	if not Damage._context(base):return false
	for key:Variant in value.physical_specs:
		if not Damage._model_key(key) or not value.physical_specs[key] is PackedByteArray or value.physical_specs[key].size()!=24:return false
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
static func _immutable(first:Dictionary,second:Dictionary)->bool:return first.model_descriptors==second.model_descriptors and first.physical_specs==second.physical_specs
static func _observation(value:Variant)->bool:
	if not (_keys(value,["kind","args","before","after","return_u32"]) or _keys(value,["kind","args","before","after","return_u32","payload_after_u32"])) or not value.kind is String or value.kind not in ["F349","F144_handler"] or not value.args is Array or not _snapshot(value.before) or not _snapshot(value.after) or not _whole(value.return_u32,0,MASK):return false
	if value.args.size()!=(3 if value.kind=="F349" else 4):return false
	for cell:Variant in value.args:
		if not _whole(cell,-0x80000000,MASK):return false
	if value.has("payload_after_u32"):
		if value.kind!="F144_handler" or int(value.args[1])!=2 or not value.payload_after_u32 is Array or value.payload_after_u32.size()!=2:return false
		for cell:Variant in value.payload_after_u32:
			if not _whole(cell,0,MASK):return false
	return _immutable(value.before.context,value.after.context)
static func decode_context(value:Variant)->Dictionary:
	if not _keys(value,CONTEXT_KEYS) or not value.model_descriptors is Dictionary or not value.physical_specs is Dictionary:return {}
	var result:Dictionary=value.duplicate(true)
	for key:String in BYTE_COUNTS:
		if result[key] is String and Frame._hex(result[key],int(BYTE_COUNTS[key])):result[key]=str(result[key]).hex_decode()
	for field:String in ["model_descriptors","physical_specs"]:
		var count:=68 if field=="model_descriptors" else 24
		for key:Variant in result[field]:
			if result[field][key] is String and Frame._hex(result[field][key],count):result[field][key]=str(result[field][key]).hex_decode()
	return _copy_context(result) if _context(result) else {}
static func decode_observations(value:Variant)->Variant:
	if not value is Array or value.size()>MAX_OBSERVATIONS:return null
	var result:Array=value.duplicate(true)
	for row:Variant in result:
		if not (_keys(row,["kind","args","before","after","return_u32"]) or _keys(row,["kind","args","before","after","return_u32","payload_after_u32"])):return null
		for side:String in ["before","after"]:
			if not _keys(row[side],["body","context"]):return null
			if row[side].body is String and Frame._hex(row[side].body,338):row[side].body=str(row[side].body).hex_decode()
			row[side].context=decode_context(row[side].context)
			if not _snapshot(row[side]):return null
		if not _observation(row):return null
	return result
static func _operation(value:Variant,args:Variant)->bool:
	if not value is String or value not in OPERATIONS or not args is Array:return false
	if value=="F944":return args.size()==2 and _whole(args[0],0,MASK) and _whole(args[1],0,MASK)
	if value in ["F946","F951"]:return args.size()==1 and _whole(args[0],-0x80000000,0x7fffffff)
	return args.is_empty()
static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false,"full_world_effects_executed":false}
static func execute(body:Variant,context:Variant,observations:Variant=[],operation:Variant="F952",args:Variant=[])->Dictionary:
	if not _body(body) or not _context(context) or not _operation(operation,args) or not observations is Array or observations.size()>MAX_OBSERVATIONS:return _reject("invalid_equipment_context")
	var runner:=Equipment.new();runner.body=body.duplicate();runner.context=_copy_context(context);runner.observations=observations.duplicate(true)
	var result:Dictionary=runner.run(str(operation),args)
	return result

class Equipment:
	var body:PackedByteArray
	var context:Dictionary
	var observations:Array
	var used:=0
	var order:Array=[]
	var requests:Array=[]
	var stopped:Dictionary={}
	var rng_calls:=0
	var model_calls:=0
	var broadcast_calls:=0
	var dispatcher_calls:=0
	var message_calls:=0
	func host()->GDScript:return load("res://scripts/source_equipment.gd")
	func fail(reason:String)->bool:
		stopped=host()._reject(reason);stopped["source_order"]=order.duplicate();stopped["observations_used"]=used;return false
	func snapshot()->Dictionary:return {"body":body.duplicate(),"context":context.duplicate(true)}
	func boundary(kind:String,args:Array)->Dictionary:
		order.append(kind);var pending:Dictionary={"kind":kind,"args":args.duplicate(),"before":snapshot()}
		if used>=observations.size():fail("boundary_required");stopped["pending"]=pending;return {}
		var row:Variant=observations[used]
		if not host()._observation(row) or row.kind!=kind or not Damage._same_args(row.args,args) or not host()._same_snapshot(row.before,pending.before):fail("unmatched_equipment_observation");return {}
		body=row.after.body.duplicate();context=host()._copy_context(row.after.context);used+=1;requests.append(row.duplicate(true))
		var reply:Dictionary={"ok":true,"return_u32":int(row.return_u32)}
		if row.has("payload_after_u32"):reply["payload_after_u32"]=[int(row.payload_after_u32[0]),int(row.payload_after_u32[1])]
		return reply
	func random(operation:String,bound:Variant=null)->int:
		order.append(operation);rng_calls+=1;var result:=Rng.execute(context.root,operation,bound)
		if not result.get("ok",false):fail("shared_rng_rejected");return 0
		context.root=result.root_after;return int(result.return_u32)
	func broadcast()->bool:
		order.append("F148");broadcast_calls+=1;var payload:Array=[23,0]
		for module in range(21):
			if (int(context.module_entries[module*8])&2)==0:continue
			order.append("F144");dispatcher_calls+=1
			if module not in HANDLER_MODULES:continue
			var reply:=boundary("F144_handler",[module,2,int(payload[0]),int(payload[1])])
			if reply.is_empty():return false
			if reply.has("payload_after_u32"):payload=reply.payload_after_u32.duplicate()
		return true
	func f933()->int:
		order.append("F933");var word:=body.decode_u32(0xc8);var eligible:=((word<<16)|(word>>16))&MASK
		if eligible==0:return 0
		for attempt in range(29):
			var selected:=random("F922",29)
			if (eligible&(1<<(selected&31)))==0:continue
			var mask:=1<<((selected^16)&31)
			body.encode_u32(0xcc,(body.decode_u32(0xcc)|mask)&MASK);body.encode_u32(0xc8,body.decode_u32(0xc8)&(~mask&MASK))
			return int(EQUIPMENT_NAMES[selected])
		return 0
	func f943()->int:
		order.append("F943")
		if int(body[0x118])==255 and not broadcast():return 0
		return 1
	func f944(message:int,argument:int)->int:
		order.append("F944")
		if int(body[0x118])==255:
			message_calls+=1
			if boundary("F349",[message&MASK,argument&MASK,MASK]).is_empty() or not broadcast():return 0
		return f943()
	func f945()->int:
		order.append("F945");var name:=f933()
		return f944(0x98c9,name) if name!=0 else f943()
	func f946(amount:int)->int:
		order.append("F946")
		context.root.encode_u16(0x170,(context.root.decode_u16(0x170)+amount)&65535)
		context.root.encode_u32(0x120,(context.root.decode_u32(0x120)+amount)&MASK)
		var value:int=(context.root.decode_u32(0x118)+amount)&MASK;context.root.encode_u32(0x118,value);return value
	func drive_mass(index:int)->int:
		if index<0 or index>=DRIVE_MASSES.size():fail("unsupported_equipment_drive_index");return 0
		return int(DRIVE_MASSES[index])
	func f947()->int:
		order.append("F947");var drive:=Ground.signed32(int(body[0xd0])<<24)>>24
		body[0xd0]=0;body.encode_u32(0x11e,0)
		if int(body[0x118])==255:
			var mass:=drive_mass(drive)
			if not stopped.is_empty():return 0
			f946(mass)
		return f944(0x98ca,0)
	func f948()->int:
		order.append("F948");var drive:=Ground.signed32(int(body[0xd0])<<24)>>24
		if drive!=0:
			body[0xd0]=1
			if int(body[0x118])==255:
				var mass:=drive_mass(drive)
				if not stopped.is_empty():return 0
				f946(Ground.signed32(mass-4))
		return f944(0x98ca,0)
	func f949()->int:
		order.append("F949");var mount:=random("F922",6)
		if mount<=5:body.encode_u16(0xbc+mount*2,0)
		if int(body[0x118])==255:context.root.encode_u32(0x214+mount*4,0)
		return f944(0x98cb,(mount+0x99ae)&MASK)
	func f950()->int:
		order.append("F950");var selection:=random("F1530")
		if selection>=0x5555:return f945()
		if selection<0x888:return f947()
		if selection<0x1c71:return f948()
		return f949()
	func f951(index:int)->int:
		order.append("F951");var cursor:=index
		if cursor<context.root.decode_s32(0x120):
			for cargo in range(37,-1,-1):
				var at:=0x17e-(37-cargo)*2;cursor=Ground.signed32(cursor-context.root.decode_u16(at))
				if cursor<0:
					context.root.encode_u16(at,(context.root.decode_u16(at)-1)&65535)
					context.root.encode_u16(0x170,(context.root.decode_u16(0x170)+1)&65535)
					return f944(0x98c8,cargo+0x8e00)
		return f943()
	func f952()->int:
		order.append("F952")
		if int(body[0x118])==255:
			order.append("F1538");model_calls+=1;var model:=body.decode_u32(0x82);var key:=str(model)
			if model>=149 or not context.model_descriptors.has(key) or not context.physical_specs.has(key) or context.model_descriptors[key].decode_u32(0x38)==0:fail("equipment_physical_spec_unavailable");return 0
			var capacity:int=context.physical_specs[key].decode_s16(8);var selected:=random("F922",capacity&MASK)
			if selected<context.root.decode_s32(0x118):return f951(selected)
		return f950()
	func run(operation:String,args:Array)->Dictionary:
		var value:=0
		match operation:
			"F933":value=f933()
			"F943":value=f943()
			"F944":value=f944(int(args[0]),int(args[1]))
			"F945":value=f945()
			"F946":value=f946(int(args[0]))
			"F947":value=f947()
			"F948":value=f948()
			"F949":value=f949()
			"F950":value=f950()
			"F951":value=f951(int(args[0]))
			"F952":value=f952()
		if not stopped.is_empty():return stopped
		if used!=observations.size():fail("unused_equipment_observations");return stopped
		return {"ok":true,"profile":PROFILE,"body_after":body.duplicate(),"context_after":host()._copy_context(context),"return_u32":value&MASK,"return_s32":Ground.signed32(value),"source_order":order.duplicate(),"requests":requests.duplicate(true),"observations_used":used,"rng_calls_u32":rng_calls,"model_calls_u32":model_calls,"broadcast_calls_u32":broadcast_calls,"dispatcher_calls_u32":dispatcher_calls,"message_calls_u32":message_calls,"F952_body_executed":operation=="F952","live_owners_changed":false,"Main_integrated":false,"full_world_effects_executed":false}
