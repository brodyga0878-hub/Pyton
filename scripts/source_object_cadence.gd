extends RefCounted
# Original DOS F149/F144 callback cadence. Callback bodies remain explicit
# observed boundaries; this module does not run an arbitrary game handler.
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const Bank=preload("res://scripts/source_reference_bank.gd")
const PROFILE:="dos-firstenc-object-cadence-v1"
const EXE_SHA256:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const ORIGINAL_EVENT5_TYPES:=[1,3,5,7,11,17]
const MAX_MUTATIONS:=16

static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"callback_effects_executed":false,"full_world_scheduler":false}
static func _clock(value:Variant)->bool:
	return value is Dictionary and Clock._keys(value,["clock_low_u32","clock_day_u32"]) and Clock._whole(value.clock_low_u32) and Clock._whole(value.clock_day_u32)
static func _objects(value:Variant)->bool:
	if not value is Dictionary or value.size()>Bank.MAX_INDEX:return false
	for index:Variant in value:
		if not index is int or index<1 or index>Bank.MAX_INDEX or not value[index] is PackedByteArray or value[index].size()!=Bank.OBJECT_BYTES:return false
	return true
static func _types(value:Variant)->bool:
	if not value is Array or value.size()>21:return false
	var seen:Dictionary={}
	for cell:Variant in value:
		if not Clock._whole(cell,20) or seen.has(int(cell)):return false
		seen[int(cell)]=true
	return true
static func _mutations(value:Variant,objects:Dictionary)->bool:
	if not value is Array or value.size()>MAX_MUTATIONS:return false
	for row:Variant in value:
		if not row is Dictionary or not Clock._keys(row,["trigger_index_u8","target_index_u8","offset_u16","value_u8"]):return false
		if not Clock._whole(row.trigger_index_u8,Bank.MAX_INDEX) or int(row.trigger_index_u8)<1 or not Clock._whole(row.target_index_u8,Bank.MAX_INDEX) or not objects.has(int(row.target_index_u8)) or not Clock._whole(row.offset_u16,Bank.OBJECT_BYTES-1) or not Clock._whole(row.value_u8,255):return false
	return true
static func _attempt(index:int,kind:int,clock:Dictionary)->Dictionary:
	return {"object_index_u8":index,"type_u8":kind,"event_u32":5,"clock_low_u32":int(clock.clock_low_u32),"clock_day_u32":int(clock.clock_day_u32)}
static func _dispatch(index:int,kind:int,clock:Dictionary,objects:Dictionary,types:Array,mutations:Array,attempts:Array,callbacks:Array)->int:
	# An invalid selector would read outside the original21-entry table. Reject
	# before publishing any candidate; dormant invalid bytes are left untouched.
	if kind<0 or kind>20:return -1
	var call:=_attempt(index,kind,clock)
	attempts.append(call.duplicate(true))
	if not kind in types:return 0
	callbacks.append(call.duplicate(true))
	var applied:=0
	for row:Dictionary in mutations:
		if int(row.trigger_index_u8)!=index:continue
		var target:PackedByteArray=objects[int(row.target_index_u8)]
		target[int(row.offset_u16)]=int(row.value_u8);objects[int(row.target_index_u8)]=target;applied+=1
	return applied

static func advance_raw(operation:Variant,clock:Variant,objects_by_index:Variant,flags:Variant,callback_types:Variant=null,mutations:Variant=[],dispatch_object_index:Variant=0,dispatch_type:Variant=0)->Dictionary:
	if not operation is String or operation not in ["cadence","dispatch"] or not _clock(clock) or not _objects(objects_by_index) or not flags is PackedByteArray or flags.size()!=Bank.FLAGS_BYTES:return _reject("invalid_raw_cadence_context")
	if callback_types!=null and not callback_types is Array:return _reject("invalid_callback_table_container")
	var types:Array=ORIGINAL_EVENT5_TYPES.duplicate() if callback_types==null else callback_types
	if not _types(types) or not _mutations(mutations,objects_by_index):return _reject("invalid_observed_callback_table_or_effects")
	var canonical_types:Array=[]
	for kind:Variant in types:canonical_types.append(int(kind))
	types=canonical_types
	if operation=="dispatch" and (not Clock._whole(dispatch_object_index,Bank.MAX_INDEX) or int(dispatch_object_index)<1 or not objects_by_index.has(int(dispatch_object_index)) or not Clock._whole(dispatch_type,20)):return _reject("invalid_direct_F144_context")
	var objects:=Bank._copy_objects(objects_by_index)
	var attempts:Array=[];var callbacks:Array=[];var applied:=0
	if operation=="dispatch":
		applied=_dispatch(int(dispatch_object_index),int(dispatch_type),clock,objects,types,mutations,attempts,callbacks)
	else:
		for index in range(Bank.MAX_INDEX,0,-1):
			if (int(flags[index])&1)==0:continue
			if not objects.has(index):return _reject("eligible_object_record_missing")
			var body:PackedByteArray=objects[index]
			var before:=int(body[0x8b]);body[0x8b]=(before-1)&255
			if before!=0:
				objects[index]=body;continue
			body[0x8b]=int(body[0x8a])
			objects[index]=body
			var count:=_dispatch(index,int(body[0x87]),clock,objects,types,mutations,attempts,callbacks)
			if count<0:return _reject("pending_callback_selector_outside_original_table")
			applied+=count
	return {"ok":true,"profile":PROFILE,"objects_by_index":objects,"flags":flags.duplicate(),"dispatch_attempts":attempts,"callbacks":callbacks,"mutations_applied":applied,"owner_global_bound_to_bank":operation=="cadence","callback_table_policy":"pinned-DOS-event5-presence" if callback_types==null else "explicit-event5-table-witness","callback_effect_policy":"declared-indexed-byte-witnesses-only","live_owners_changed":false,"callback_effects_executed":false,"full_world_scheduler":false,"JJFFE_laser_fix_executed":false}
