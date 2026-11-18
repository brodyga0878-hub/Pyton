extends RefCounted
# Whole F953 resumed with real equipment and full-bank destruction kernels.
# Root is owned once; all flags and object records live in the one raw bank.
const Damage=preload("res://scripts/source_damage.gd")
const Equipment=preload("res://scripts/source_equipment.gd")
const Destruction=preload("res://scripts/source_destruction.gd")
const Factory=preload("res://scripts/source_object_factory.gd")
const EffectFactory=preload("res://scripts/source_effect_factory.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const PROFILE:="dos-firstenc-owned-bank-damage-effects-v1"
const KEYS:=["root","bank","event_registers","module_entries","module_count_s32","model_resources"]
const BUFFER_BYTES:={"root":16384,"bank":38986,"event_registers":284,"module_entries":168}
const HEADER_BYTES:=116
const BODY_BYTES:=338
const MAX_BOUNDARIES:=64
const DRIVE_MASSES:=[0,4,10,25,45,80,150,250,400,600,6,12,24,36,0]

static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false,"full_event_VM_executed":false}
static func _drive_masses(value:Variant)->bool:
	if not value is Array or value.size()!=15:return false
	for index in range(15):
		if not Frame._whole(value[index],int(DRIVE_MASSES[index]),int(DRIVE_MASSES[index])):return false
	return true
static func _context(value:Variant)->bool:
	if not Damage._keys(value,KEYS) or not Frame._whole(value.module_count_s32,-0x80000000,20) or not value.model_resources is Dictionary or value.model_resources.size()>151:return false
	for key:String in BUFFER_BYTES:
		if not value[key] is PackedByteArray or value[key].size()!=int(BUFFER_BYTES[key]):return false
	for key:Variant in value.model_resources:
		if not key is String or not key.is_valid_int() or str(int(key))!=key or (not Frame._whole(int(key),0,148) and int(key) not in [153,155]) or not Factory._resources(value.model_resources[key]) or not _drive_masses(value.model_resources[key].drive_mass_table_u32):return false
	return true
static func _copy_context(value:Dictionary)->Dictionary:
	var result:Dictionary=value.duplicate(true);result.module_count_s32=int(value.module_count_s32);return result
static func decode_context(value:Variant)->Dictionary:
	if not Damage._keys(value,KEYS):return {}
	var result:Dictionary=value.duplicate(true)
	for key:String in BUFFER_BYTES:
		if result[key] is String and Frame._hex(result[key],int(BUFFER_BYTES[key])):result[key]=str(result[key]).hex_decode()
	return _copy_context(result) if _context(result) else {}
static func source_resources()->Dictionary:
	var result:Dictionary={}
	for index in range(149):
		var resource:=Factory.source_model(index)
		if resource.is_empty():return {}
		result[str(index)]=resource
	for index in [153,155]:
		var resource:=EffectFactory.source_model(index)
		if resource.is_empty():return {}
		result[str(index)]=resource
	return result
static func body_at(bank:PackedByteArray,slot:int)->PackedByteArray:
	return bank.slice(HEADER_BYTES+slot*BODY_BYTES,HEADER_BYTES+(slot+1)*BODY_BYTES)
static func _write(bank:PackedByteArray,offset:int,raw:PackedByteArray)->void:
	for index in range(raw.size()):bank[offset+index]=raw[index]
static func _damage_context(value:Dictionary)->Dictionary:
	var models:Dictionary={}
	for key:String in value.model_resources:
		if int(key)<149:models[key]=str(value.model_resources[key].descriptor_hex).hex_decode()
	return {"root":value.root.duplicate(),"flags":value.bank.slice(0,115),"event_registers":value.event_registers.duplicate(),"module_entries":value.module_entries.duplicate(),"module_count_s32":int(value.module_count_s32),"model_descriptors":models}
static func _equipment_context(value:Dictionary)->Dictionary:
	var result:=_damage_context(value);var specs:Dictionary={}
	for key:String in value.model_resources:
		if int(key)<149 and str(value.model_resources[key].physical_spec_hex)!="":specs[key]=str(value.model_resources[key].physical_spec_hex).hex_decode()
	result["physical_specs"]=specs
	return result
static func _destruction_context(value:Dictionary)->Dictionary:
	return {"root":value.root.duplicate(),"bank":value.bank.duplicate(),"module_entries":value.module_entries.duplicate(),"module_count_s32":int(value.module_count_s32),"model_resources":value.model_resources.duplicate(true)}
static func _from_damage(base:Dictionary,slot:int,snapshot:Dictionary)->Dictionary:
	var result:=_copy_context(base)
	result.root=snapshot.context.root.duplicate();result.event_registers=snapshot.context.event_registers.duplicate();result.module_entries=snapshot.context.module_entries.duplicate();result.module_count_s32=int(snapshot.context.module_count_s32)
	_write(result.bank,0,snapshot.context.flags);_write(result.bank,HEADER_BYTES+slot*BODY_BYTES,snapshot.body)
	return result
static func _packets(value:Variant)->bool:
	if not value is Array or value.size()>MAX_BOUNDARIES:return false
	for row:Variant in value:
		if not Damage._keys(row,["call_index_u32","observations"]) or not Frame._whole(row.call_index_u32,0,MAX_BOUNDARIES-1) or not row.observations is Array:return false
	return true
static func _expanded_order(order:Array,calls:Array)->Array:
	var result:Array=[];var cursor:=0
	for item:Variant in order:
		if item in ["F952","F942"] and cursor<calls.size():result.append_array(calls[cursor].calculation.source_order);cursor+=1
		else:result.append(item)
	return result
static func execute(context:Variant,target_slot:Variant,damage_s32:Variant,attacker_u32:Variant,observations:Variant=[],equipment_observations:Variant=[],destruction_observations:Variant=[])->Dictionary:
	if not _context(context) or not Frame._whole(target_slot,0,114) or not Frame._whole(damage_s32,-0x80000000,0x7fffffff) or not Frame._whole(attacker_u32,0,0xffffffff) or not observations is Array or observations.size()>MAX_BOUNDARIES or not _packets(equipment_observations) or not _packets(destruction_observations):return _reject("invalid_damage_effects_context")
	var decoded:Variant=Damage.decode_observations(observations)
	if decoded==null:return _reject("invalid_damage_effects_observations")
	var initial:=_copy_context(context);var state:=_copy_context(context);var slot:=int(target_slot)
	var trace:Array=[];var calls:Array=[];var used:=0;var equipment_used:=0;var destruction_used:=0;var equipment_calls:=0;var destruction_calls:=0
	for attempt in range(MAX_BOUNDARIES+1):
		var result:=Damage.execute(body_at(initial.bank,slot),damage_s32,attacker_u32,_damage_context(initial),trace)
		if result.get("ok",false):
			if used!=decoded.size() or equipment_used!=equipment_observations.size() or destruction_used!=destruction_observations.size():return _reject("unused_damage_effects_observations")
			state=_from_damage(state,slot,{"body":result.body_after,"context":result.context_after})
			if not _context(state):return _reject("invalid_damage_effects_result")
			return {"ok":true,"profile":PROFILE,"context_after":state,"body_after":body_at(state.bank,slot),"return_u32":int(result.return_u32),"return_s32":int(result.return_s32),"source_order":_expanded_order(result.source_order,calls),"requests":result.requests.duplicate(true),"effect_calls":calls,"equipment_calls_u32":equipment_calls,"destruction_calls_u32":destruction_calls,"F953_body_executed":true,"F952_body_executed":equipment_calls>0,"F942_body_executed":destruction_calls>0,"live_owners_changed":false,"Main_integrated":false,"full_event_VM_executed":false}
		if not result.get("pending") is Dictionary:return _reject("damage_"+str(result.get("reason","rejected")))
		var pending:Dictionary=result.pending;var row:Dictionary
		state=_from_damage(state,slot,pending.before)
		if not _context(state):return _reject("unsupported_damage_effects_intermediate_state")
		if pending.kind in ["F952","F942"]:
			var equipment:bool=pending.kind=="F952";var packets:Array=equipment_observations if equipment else destruction_observations
			var packet_cursor:=equipment_used if equipment else destruction_used;var call_index:=equipment_calls if equipment else destruction_calls;var replies:Array=[]
			if packet_cursor<packets.size() and int(packets[packet_cursor].call_index_u32)==call_index:
				replies=packets[packet_cursor].observations.duplicate(true)
				if equipment:equipment_used+=1
				else:destruction_used+=1
			var calculated:Dictionary
			if equipment:
				var observed:Variant=Equipment.decode_observations(replies)
				if observed==null:return _reject("invalid_equipment_effects_observations")
				calculated=Equipment.execute(body_at(state.bank,slot),_equipment_context(state),observed)
			else:
				var observed:Variant=Destruction.decode_observations(replies)
				if observed==null:return _reject("invalid_destruction_effects_observations")
				calculated=Destruction.execute(_destruction_context(state),slot,attacker_u32,observed)
			if not calculated.get("ok",false):
				var failed:=_reject("effect_"+str(calculated.get("reason","rejected")));failed["effect_stage"]="equipment" if equipment else "destruction";failed["effect_call_index_u32"]=call_index;failed["caller_pending"]=pending.duplicate(true)
				if calculated.get("pending") is Dictionary:failed["pending"]=calculated.pending.duplicate(true)
				return failed
			if equipment:
				state=_from_damage(state,slot,{"body":calculated.body_after,"context":calculated.context_after});equipment_calls+=1
			else:
				for key:String in ["root","bank","module_entries","module_count_s32"]:state[key]=calculated.context_after[key].duplicate() if calculated.context_after[key] is PackedByteArray else int(calculated.context_after[key])
				destruction_calls+=1
			if not _context(state):return _reject("invalid_effect_kernel_result")
			row={"kind":pending.kind,"args":pending.args.duplicate(),"before":pending.before.duplicate(true),"after":{"body":body_at(state.bank,slot),"context":_damage_context(state)},"return_u32":int(calculated.return_u32)}
			calls.append({"kind":pending.kind,"calculation":calculated.duplicate(true)})
		else:
			if used>=decoded.size():
				var failed:=_reject("boundary_required");failed["effect_stage"]="damage";failed["pending"]=pending.duplicate(true);return failed
			row=decoded[used].duplicate(true);used+=1
			if row.kind in ["F952","F942"]:return _reject("observed_reply_cannot_replace_actual_effects")
		trace.append(row)
	return _reject("damage_effects_boundary_limit")
