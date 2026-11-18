extends RefCounted
# Whole F942 with actual model155 allocation, source RNG/matrix and F924.
# Cargo/debris F926/F927 and position arithmetic execute. Messages, module
# handler bodies and F1344 name expansion remain typed external boundaries.
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Damage=preload("res://scripts/source_damage.gd")
const Rng=preload("res://scripts/source_global_rng.gd")
const Factory=preload("res://scripts/source_effect_factory.gd")
const Rotation=preload("res://scripts/body_rotation.gd")
const PROFILE:="dos-firstenc-whole-f942-destruction-v1"
const BANK_BYTES:=38986
const KEYS:=["root","bank","module_entries","module_count_s32","model_resources"]
const MAX_OBSERVATIONS:=64
const MASK:=0xffffffff
const CARGO_ITEMS:=[0,30,30,30,4,5,30,7,8,9,10,4,9,30,14,15,16,17,18,30,29,21,22,23,24,25,26,27,28,29,30,31]
const DRIVE_MASSES:=[0,4,10,25,45,80,150,250,400,600,6,12,24,36,0]
static func _keys(v:Variant,k:Array)->bool:return Frame._keys(v,k)
static func _whole(v:Variant,a:int,b:int)->bool:return Frame._whole(v,a,b)
static func _s32(v:int)->int:return (v&0x7fffffff)-(v&0x80000000)
static func _context(v:Variant)->bool:
	if not _keys(v,KEYS) or not v.root is PackedByteArray or v.root.size()!=16384 or not v.bank is PackedByteArray or v.bank.size()!=BANK_BYTES or not v.module_entries is PackedByteArray or v.module_entries.size()!=168 or not _whole(v.module_count_s32,-0x80000000,20) or not v.model_resources is Dictionary or v.model_resources.size()>151:return false
	for key:Variant in v.model_resources:
		if not key is String or not key.is_valid_int() or str(int(key))!=key or not Factory.supported_model(int(key)) or not Factory.Factory._resources(v.model_resources[key]):return false
		for i in range(15):
			if int(v.model_resources[key].drive_mass_table_u32[i])!=int(DRIVE_MASSES[i]):return false
	return true
static func _copy_context(v:Dictionary)->Dictionary:
	var out:=v.duplicate(true);out.module_count_s32=int(v.module_count_s32);return out
static func _same_context(a:Variant,b:Dictionary)->bool:
	if not _context(a):return false
	for key:String in KEYS:
		if a[key]!=b[key]:return false
	return true
static func _reject(reason:String)->Dictionary:return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false,"full_world_destruction":false}
static func decode_context(v:Variant)->Dictionary:
	if not _keys(v,KEYS):return {}
	var out:Dictionary=v.duplicate(true)
	for key:String in ["root","bank","module_entries"]:
		var size:int={"root":16384,"bank":BANK_BYTES,"module_entries":168}[key]
		if Frame._hex(out[key],size):out[key]=str(out[key]).hex_decode()
	return _copy_context(out) if _context(out) else {}
static func decode_observations(v:Variant)->Variant:
	if not v is Array or v.size()>MAX_OBSERVATIONS:return null
	var out:Array=v.duplicate(true)
	for row:Variant in out:
		if not _keys(row,["kind","args","before","after","return_u32"]):return null
		row.before=decode_context(row.before);row.after=decode_context(row.after)
		if row.before.is_empty() or row.after.is_empty():return null
	return out
static func execute(context:Variant,body_slot_u32:Variant,attacker_u32:Variant,observations:Variant=[])->Dictionary:
	if not _context(context) or not _whole(body_slot_u32,0,114) or not _whole(attacker_u32,0,MASK) or not observations is Array or observations.size()>MAX_OBSERVATIONS:return _reject("invalid_destruction_context")
	var run:=Destruction.new();run.context=_copy_context(context);run.slot=int(body_slot_u32);run.attacker=int(attacker_u32);run.observations=observations.duplicate(true)
	return run.run()
class Destruction:
	var context:Dictionary
	var slot:int
	var attacker:int
	var observations:Array
	var used:=0
	var order:Array=[]
	var requests:Array=[]
	var stopped:Dictionary={}
	var explosion_slot:=0
	var rng_calls:=0
	var cargo_calls:=0
	func host()->GDScript:return load("res://scripts/source_destruction.gd")
	func fail(reason:String)->bool:
		stopped=host()._reject(reason);stopped["source_order"]=order.duplicate();stopped["observations_used"]=used;return false
	func at(index:int)->int:return 116+index*338
	func body(index:int)->PackedByteArray:return context.bank.slice(at(index),at(index)+338)
	func set_body(index:int,value:PackedByteArray)->void:
		for i in range(338):context.bank[at(index)+i]=value[i]
	func boundary(kind:String,args:Array)->bool:
		order.append(kind)
		var pending:Dictionary={"kind":kind,"args":args.duplicate(),"before":context.duplicate(true)}
		if used>=observations.size():fail("boundary_required");stopped["pending"]=pending;return false
		var row:Variant=observations[used]
		if not host()._keys(row,["kind","args","before","after","return_u32"]) or row.kind!=kind or not row.args is Array or row.args.size()!=args.size() or not host()._same_context(row.before,context) or not host()._context(row.after) or not host()._whole(row.return_u32,0,0xffffffff):return fail("unmatched_destruction_observation")
		for i in range(args.size()):
			if not host()._whole(row.args[i],-0x80000000,0xffffffff) or (int(row.args[i])&0xffffffff)!=(int(args[i])&0xffffffff):return fail("unmatched_destruction_arguments")
		if row.after.model_resources!=context.model_resources:return fail("readonly_destruction_resources_changed")
		context=host()._copy_context(row.after);requests.append(row.duplicate(true));used+=1;return true
	func model(index:int)->Dictionary:
		order.append("F1538")
		if not context.model_resources.has(str(index)):fail("missing_destruction_model");return {}
		return context.model_resources[str(index)]
	func random(operation:String,bound:Variant=null)->int:
		order.append(operation);rng_calls+=1
		var result:=Rng.execute(context.root,operation,bound)
		if not result.ok:fail("invalid_destruction_rng");return -1
		context.root=result.root_after;return int(result.return_u32)
	func allocate(model_index:int=155,new_flags:int=9,reserved_min:int=1)->int:
		order.append("F928" if reserved_min==1 else "F927")
		var selected:=0;var count:int=context.root.decode_u32(0x70)
		for index in range(114,0,-1):
			if context.bank[index]==0:selected=index;break
		if selected<reserved_min:
			selected=0
			for index in range(114,0,-1):
				if (int(context.bank[index])&0x20)!=0:
					if index<reserved_min:return 0
					selected=index;count=(count-1)&0xffffffff;break
		if selected==0:return 0
		context.bank[selected]=new_flags
		if (new_flags&0x20)!=0:count=(count+1)&0xffffffff
		context.root.encode_u32(0x70,count)
		order.append("F1533");var resources:=model(model_index)
		if resources.is_empty():return -1
		var initialized:=Factory.initialize_context(body(selected),body(slot),model_index,{"tick_u32":context.root.decode_u32(0),"day_u32":context.root.decode_u32(4)},resources,selected!=slot)
		if not initialized.ok:fail("explosion_factory_rejected");return -1
		var value:PackedByteArray=initialized.body_after;value[0x86]=selected;set_body(selected,value);return selected
	func cargo(item:int)->bool:
		order.append("F926");cargo_calls+=1
		var selected:=allocate(153,15,20)
		if selected<0:return false
		if selected==0:return true
		var value:=body(selected);value.encode_u16(0x9e,(item+0x7200)&65535);set_body(selected,value)
		if not boundary("F1344",[at(selected)+0x124,item]):return false
		value=body(selected);value[0x118]=250;value[0x87]=11;value[0xff]=21;value[0x14e]=6;set_body(selected,value)
		random("F1530");var first:int=context.root.decode_s32(0x24)>>22
		random("F1530");var second:int=context.root.decode_s32(0x24)>>22;var third:int=context.root.decode_s32(0x28)>>22
		value=body(selected);var delta:Array=[first,second,third]
		for i in range(3):value.encode_s32(0x8c+i*4,host()._s32(value.decode_s32(0x8c+i*4)+int(delta[i])))
		order.append("F1514")
		for i in range(3):
			var offset:int=0x3e+i*8;var old:int=value.decode_u32(offset);var low:int=(old+int(delta[i]))&0xffffffff
			value.encode_u32(offset,low);value.encode_s32(offset+4,host()._s32(value.decode_s32(offset+4)+(int(delta[i])>>31)+(1 if old>low else 0)))
		set_body(selected,value);return true
	func release()->bool:
		order.append("F924");var reference:int=context.bank[at(slot)+0x86]
		if reference>114:return fail("release_index_outside_bank")
		if (int(context.bank[reference])&0x20)!=0:context.root.encode_u32(0x70,(context.root.decode_u32(0x70)-1)&0xffffffff)
		else:
			var index:=0
			while index<=int(context.module_count_s32):
				if (int(context.module_entries[index*8])&4)!=0:
					order.append("F144")
					if index in Damage.HANDLER_MODULES[11] and not boundary("F144_handler",[index,11,0,at(slot),reference,attacker&255]):return false
				index+=1
		context.bank[reference]=0;return true
	func run()->Dictionary:
		order.append("F942")
		if attacker!=0 and attacker==int(context.root.decode_u32(0xc0)):
			var value:=body(slot)
			if int(value[0x118])==251 and value.decode_u32(0x11a)!=0:
				var player:int=context.root.decode_u32(0xc8)
				if player<1 or player>114:fail("unbound_player_pointer_for_bounty");return stopped
				if (int(context.bank[at(player)+0xca])&0x40)!=0:
					if not boundary("F349",[0x8635,1,value.decode_u32(0x11a),0xffffffff]):return stopped
					value=body(slot);context.root.encode_u32(0x114,(context.root.decode_u32(0x114)+value.decode_u32(0x11a)*10)&0xffffffff)
			value=body(slot);var resource:=model(value.decode_u32(0x82))
			if resource.is_empty():return stopped
			if not str(resource.physical_spec_hex).is_empty():
				var previous:int=context.root.decode_s32(0x19c);resource=model(body(slot).decode_u32(0x82))
				if resource.is_empty():return stopped
				var points:int=str(resource.physical_spec_hex).hex_decode().decode_s16(0x16)
				var next:int=host()._s32(context.root.decode_s32(0x19c)+points);context.root.encode_s32(0x19c,next)
				if (next>>16)!=(previous>>16) and not boundary("F349",[0x98cf,0,0,0xffffffff]):return stopped
		if not boundary("F1907",[5,host()._s32(int(body(slot)[0x88])<<24)>>24]):return stopped
		explosion_slot=allocate()
		if explosion_slot<0:return stopped
		if explosion_slot!=0:
			var explosion:=body(explosion_slot);explosion[0x87]=11;explosion[0xff]=28;explosion.encode_u32(0xa4,0xffffffff);explosion.encode_u16(0x9e,65535);set_body(explosion_slot,explosion)
			var first:=random("F1530");var second:=random("F1530");order.append("F1675")
			var matrix:=Rotation.matrix_yzt(first,second);explosion=body(explosion_slot)
			for i in range(9):explosion.encode_s32(i*4,matrix[i])
			set_body(explosion_slot,explosion)
			var source:=body(slot);var resource:=model(source.decode_u32(0x82))
			if resource.is_empty():return stopped
			if not str(resource.physical_spec_hex).is_empty():
				resource=model(body(slot).decode_u32(0x82))
				if resource.is_empty():return stopped
				var mass:int=str(resource.physical_spec_hex).hex_decode().decode_s16(6)
				explosion=body(explosion_slot);explosion.encode_u32(0x7e,(explosion.decode_u32(0x7e)-1)&0xffffffff);set_body(explosion_slot,explosion)
				if mass>=10:
					if not boundary("F1907",[31,host()._s32(int(body(slot)[0x88])<<24)>>24]):return stopped
					explosion=body(explosion_slot);explosion.encode_u32(0x7e,(explosion.decode_u32(0x7e)+1)&0xffffffff);set_body(explosion_slot,explosion)
					if mass>=400:
						var own:=model(body(slot).decode_u32(0x82));var other:=model(body(explosion_slot).decode_u32(0x82))
						if own.is_empty() or other.is_empty():return stopped
						var a:=str(own.descriptor_hex).hex_decode();var b:=str(other.descriptor_hex).hex_decode()
						explosion=body(explosion_slot);explosion.encode_s32(0x7e,host()._s32(a.decode_s32(0x14)+a.decode_s32(0x18)-b.decode_s32(0x14)-b.decode_s32(0x18)+4));set_body(explosion_slot,explosion)
			var source_model:int=body(slot).decode_u32(0x82)
			if source_model>=15 and source_model<=63:
				var pieces:=random("F922",6)-2
				while pieces>0:
					if not cargo(0x8e0f):return stopped
					pieces-=1
				var maximum:int=mini(int(body(slot).decode_u16(0x116))>>1,4)
				if maximum>0:
					var cargo_count:=random("F922",maximum)-2
					while cargo_count>=0:
						var item:=0x8e00+int(CARGO_ITEMS[random("F1530")&31])
						if not cargo(item):return stopped
						cargo_count-=1
		if not release():return stopped
		if used!=observations.size():fail("unused_destruction_observations");return stopped
		return {"ok":true,"profile":host().PROFILE,"context_after":context.duplicate(true),"return_u32":0,"return_s32":0,"explosion_slot_u32":explosion_slot,"source_order":order.duplicate(),"requests":requests.duplicate(true),"observations_used":used,"rng_calls_u32":rng_calls,"cargo_calls_u32":cargo_calls,"F942_body_executed":true,"F928_body_executed":true,"F924_body_executed":true,"F1675_body_executed":explosion_slot!=0,"F926_body_executed":cargo_calls!=0,"live_owners_changed":false,"Main_integrated":false,"full_world_destruction":false}
