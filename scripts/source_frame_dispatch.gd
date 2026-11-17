extends RefCounted
# Original DOS F568/F569 -> F570 caller. The source classifier F575 is an
# explicit, matched observation boundary; optional flag receipts preserve
# callback timing without introducing a second flags-bank owner.
const Bank=preload("res://scripts/source_reference_bank.gd")
const Frame=preload("res://scripts/source_frame_kinematics.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
const PROFILE:="dos-firstenc-f569-f570-trace-v1"
const SOURCE_EXE_SHA256:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const OBJECT_BYTES:=338
const FLAGS_BYTES:=115
const MAX_INDEX:=114
const MASK:=0xffffffff
const GLOBAL_KEYS:=["collision_flags_u8","volume_flags_u8","collider_index_u8","collision_active_u8","collision_enabled_u8","primitive_flags_u8","altitude_low_u32","altitude_high_s32","previous_altitude_low_u32","previous_altitude_high_s32","collision_kind_u8","collider_ref_u32"]
# collider_ref_u32 is a logical source-bank index (0 means null), never an
# Android/host process address. A stale inactive slot may remain observable.
const TRACE_KEYS:=["subject_before_hex","collider_index_u8","collider_before_hex","relative_before_hex","globals_before","subject_after_hex","collider_after_hex","globals_after","return_u8"]

static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"F575_body_executed":false,"full_collision_classifier":false,"complete_original_flight_pipeline":false}
static func _whole(value:Variant,low:int,high:int)->bool:return Bank._whole(value,low,high)
static func _keys(value:Variant,expected:Array)->bool:return Bank._keys(value,expected)
static func _hex(value:Variant,count:int)->bool:return Bank._hex(value,count)
static func _globals(value:Variant)->bool:
	if not _keys(value,GLOBAL_KEYS):return false
	for key:String in GLOBAL_KEYS:
		var low:=0;var high:=255
		if key.ends_with("_s32"):low=-0x80000000;high=0x7fffffff
		elif key=="collider_ref_u32":high=MAX_INDEX
		elif key.ends_with("_u32"):high=MASK
		if not _whole(value[key],low,high):return false
	return true
static func _copy_globals(value:Dictionary)->Dictionary:
	var result:Dictionary={}
	for key:String in GLOBAL_KEYS:result[key]=int(value[key])
	return result
static func _same_globals(first:Dictionary,second:Dictionary)->bool:
	for key:String in GLOBAL_KEYS:
		if int(first[key])!=int(second[key]):return false
	return true
static func _raw_bank(player:Variant,objects:Variant,flags:Variant)->bool:
	if not player is PackedByteArray or player.size()!=OBJECT_BYTES or not objects is Dictionary or objects.size()>MAX_INDEX-1 or not flags is PackedByteArray or flags.size()!=FLAGS_BYTES:return false
	var own:=int(player[0x86])
	if own<1 or own>MAX_INDEX or objects.has(own):return false
	for key:Variant in objects:
		if not key is int or key<1 or key>MAX_INDEX or not objects[key] is PackedByteArray or objects[key].size()!=OBJECT_BYTES or int(objects[key][0x86])!=key:return false
	for index in range(1,MAX_INDEX+1):
		if (int(flags[index])&4)!=0 and index!=own and not objects.has(index):return false
	var all:Dictionary=objects.duplicate();all[own]=player
	for key:Variant in all:
		var seen:Dictionary={};var cursor:int=int(key)
		while cursor!=0:
			if seen.has(cursor) or not all.has(cursor):return false
			seen[cursor]=true;cursor=int(all[cursor][0x56])
	return true
static func _valid_trace(trace:Variant,allow_flag_writes:bool=false)->bool:
	if not trace is Array or trace.size()>115:return false
	for row:Variant in trace:
		var keys:Array=TRACE_KEYS.duplicate()
		if row is Dictionary and (row.has("flags_before_hex") or row.has("flags_after_hex")):
			if not allow_flag_writes or not _hex(row.get("flags_before_hex"),FLAGS_BYTES) or not _hex(row.get("flags_after_hex"),FLAGS_BYTES):return false
			keys.append_array(["flags_before_hex","flags_after_hex"])
		if not _keys(row,keys) or not _hex(row.subject_before_hex,OBJECT_BYTES) or not _hex(row.collider_before_hex,OBJECT_BYTES) or not _hex(row.relative_before_hex,24) or not _hex(row.subject_after_hex,OBJECT_BYTES) or not _hex(row.collider_after_hex,OBJECT_BYTES) or not _globals(row.globals_before) or not _globals(row.globals_after) or not _whole(row.collider_index_u8,1,MAX_INDEX) or not _whole(row.return_u8,0,255):return false
		var subject_before:=str(row.subject_before_hex).hex_decode();var subject_after:=str(row.subject_after_hex).hex_decode()
		var collider_before:=str(row.collider_before_hex).hex_decode();var collider_after:=str(row.collider_after_hex).hex_decode()
		# An observed classifier response does not own identity/frame selection.
		for offset:int in [0x56,0x57,0x86]:
			if subject_before[offset]!=subject_after[offset] or collider_before[offset]!=collider_after[offset]:return false
	return true
static func _vector_hex(value:PackedInt64Array)->String:
	var bytes:=PackedByteArray();bytes.resize(24)
	for axis in range(3):bytes.encode_s64(axis*8,value[axis])
	return bytes.hex_encode()
static func _matrix(body:PackedByteArray)->PackedInt64Array:
	var values:=PackedInt64Array()
	for index in range(9):values.append(body.decode_s32(index*4))
	return values
static func _call(bank:RefCounted,history:Dictionary,relative:PackedInt64Array,collider_index:int,trace:Array,index:int,allow_pending:bool=false,allow_flag_writes:bool=false)->Dictionary:
	if index>=trace.size():
		var missing:=_reject("missing_F575_observation")
		if allow_pending:
			missing.pending={"kind":"F575","subject":bank.raw_player(),"collider_index_u8":collider_index,"collider":bank._get_record(collider_index).duplicate(),"relative":_vector_hex(relative).hex_decode(),"globals":_copy_globals(history)}
			if allow_flag_writes:missing.pending["bank_flags_before"]=bank.bank_flags()
			missing.trace_consumed=index
		return missing
	var row:Dictionary=trace[index]
	var collider:PackedByteArray=bank._get_record(collider_index)
	if row.subject_before_hex!=bank._player.hex_encode() or int(row.collider_index_u8)!=collider_index or row.collider_before_hex!=collider.hex_encode() or row.relative_before_hex!=_vector_hex(relative) or not _same_globals(row.globals_before,history):return _reject("F575_observation_request_mismatch")
	if row.has("flags_before_hex") and row.flags_before_hex!=bank._flags.hex_encode():return _reject("F575_observation_flag_request_mismatch")
	bank._player=str(row.subject_after_hex).hex_decode()
	bank._set_record(collider_index,str(row.collider_after_hex).hex_decode())
	if row.has("flags_after_hex"):bank._flags=str(row.flags_after_hex).hex_decode()
	if not _raw_bank(bank._player,bank._objects,bank._flags):return _reject("F575_observation_broke_raw_bank")
	return {"ok":true,"globals_after":_copy_globals(row.globals_after),"return_u8":int(row.return_u8)}

static func dispatch(player:Variant,objects_by_index:Variant,flags:Variant,initial_globals:Variant,frame_ticks_u32:Variant,source_frame_byte:Variant,trace:Variant,enabled:Variant=true,profile:String=PROFILE,allow_pending:Variant=false,allow_flag_writes:Variant=false)->Dictionary:
	if profile!=PROFILE or not _raw_bank(player,objects_by_index,flags) or not _globals(initial_globals) or not _whole(frame_ticks_u32,0,MASK) or not _whole(source_frame_byte,0,255) or not allow_flag_writes is bool or not _valid_trace(trace,allow_flag_writes) or not enabled is bool or not allow_pending is bool:return _reject("invalid_frame_dispatch_inputs")
	# The private bank supplies the already independently controlled F1677 path.
	# Its public configure() has a separate F606 natural-candidate constraint;
	# F570 collision-list flags use bit4 and have their own admission above.
	var bank:=Bank.new();bank._player=player.duplicate();bank._objects=Bank._copy_objects(objects_by_index);bank._flags=flags.duplicate();bank._clock={"tick_u32":0,"day_u32":0}
	var history:=_copy_globals(initial_globals)
	history.collision_enabled_u8=255 if enabled else 0
	for key:String in ["collision_flags_u8","volume_flags_u8","collider_index_u8","primitive_flags_u8","collision_kind_u8"]:history[key]=0
	history.altitude_low_u32=MASK
	var consumed:=0
	var parent_index:=int(bank._player[0x56])
	if parent_index!=0:
		history.collider_ref_u32=parent_index
		var response:=_call(bank,history,Bank._position(bank._player),parent_index,trace,consumed,allow_pending,allow_flag_writes)
		if not response.get("ok",false):return response
		consumed+=1;history=response.globals_after
		var cooldown:int=bank._player.decode_s32(0x148)
		if cooldown!=0:
			var ticks:=Ground.signed32(int(frame_ticks_u32));var half:=ticks>>1
			if half<0:half+=ticks&1
			bank._player.encode_s32(0x148,0 if half>cooldown else Ground.signed32(cooldown-half))
		else:
			var rotating:bool=int(bank._player[0x57])!=0
			var enter:bool=(int(response.return_u8)&2)!=0
			if rotating!=enter:
				var transformed:=Frame.rotate(bank._player,_matrix(bank._get_record(parent_index)),enter,int(source_frame_byte))
				if transformed.is_empty():return _reject("source_frame_rotation_rejected")
				bank._player=transformed.body;bank._player.encode_u32(0x148,127)
	var scan_parent:=int(bank._player[0x56])
	var parent_flags:int=int(history.collision_flags_u8)
	var own:=int(bank._player[0x86])
	for index in range(MAX_INDEX,0,-1):
		if (int(bank._flags[index])&4)==0 or index==own:continue
		var candidate:PackedByteArray=bank._get_record(index)
		if int(candidate[0x8b])!=0 or int(candidate[0x56])!=scan_parent:continue
		if candidate.decode_u32(0x82)==0x99 and bank._player.decode_u32(0x82)!=0x99:continue
		var relative:PackedInt64Array
		if int(bank._player[0x57])!=int(candidate[0x57]):
			var subject_global:PackedInt64Array=bank._global(own,int(source_frame_byte))
			var candidate_global:PackedInt64Array=bank._global(index,int(source_frame_byte))
			if subject_global.size()!=3 or candidate_global.size()!=3:return _reject("source_global_frame_unavailable")
			relative=Bank._add_position(subject_global,candidate_global,true)
		else:relative=Bank._add_position(Bank._position(bank._player),Bank._position(candidate),true)
		var response:=_call(bank,history,relative,index,trace,consumed,allow_pending,allow_flag_writes)
		if not response.get("ok",false):return response
		consumed+=1;history=response.globals_after
	if consumed!=trace.size():return _reject("unused_F575_observations")
	history.collision_flags_u8=int(history.collision_flags_u8)|parent_flags
	var low:=Ground.signed32(int(history.altitude_low_u32))
	var outputs:Dictionary={"flags_u8":int(history.collision_flags_u8),"collider_index_u8":int(history.collider_index_u8),"collider_ref_u32":int(history.collider_ref_u32),"altitude_s32":-1 if int(history.altitude_high_s32)!=0 or low<0 else low,"material_u8":int(history.primitive_flags_u8)&31,"return_u8":int(history.collision_flags_u8)}
	return {"ok":true,"profile":PROFILE,"body":bank.raw_player(),"objects_by_index":bank.raw_objects(),"flags":bank.bank_flags(),"globals_after":history,"outputs":outputs,"trace_consumed":consumed,"caller_procedure":"F569" if enabled else "F568","F570_executed":true,"F575_body_executed":false,"classifier_observations_applied":consumed,"live_owners_changed":false,"full_collision_classifier":false,"clock_advanced":false,"complete_original_flight_pipeline":false}
