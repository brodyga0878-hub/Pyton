extends RefCounted
# Raw DOS reference-frame transactions. F604/F605/F595 and F606/F590 use
# explicit source object records and cache bytes; no SI state is reconstructed.
# This is not the F570 caller, F585 controller, allocation manager or a complete
# moving-body flight/time pipeline. The JJFFE velocity fix is a different ABI.
const Ground=preload("res://scripts/ground_coordinates.gd")
const Gravity=preload("res://scripts/source_gravity.gd")
const Frame=preload("res://scripts/source_frame_kinematics.gd")
const Orbit=preload("res://scripts/source_orbit.gd")
const OBJECT_BYTES:=338
const MAX_INDEX:=114
const FLAGS_BYTES:=115
const MASK:=0xffffffff
const VARIANT:="dos-firstenc"
const PROFILE:="dos-firstenc-reference-bank-v1"
const SCHEMA:="starfrontier-source-reference-bank-v1"
const MAX_GENERATION:=100000000
const SNAPSHOT_KEYS:=["schema","version","profile","variant","player_hex","objects","flags_hex","clock","generation","snapshot_sha256"]
var _player:=PackedByteArray()
var _objects:Dictionary={}
var _flags:=PackedByteArray()
var _clock:Dictionary={}
var _generation:=0

static func _whole(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=low and value<=high and float(value)==floorf(float(value))
static func _hex(value:Variant,size:int)->bool:
	if not value is String or value.length()!=size*2:return false
	for character:String in value:
		if not character in "0123456789abcdef":return false
	return true
static func _keys(value:Variant,keys:Array)->bool:
	if not value is Dictionary or value.size()!=keys.size():return false
	for key:Variant in value:
		if not key is String or key not in keys:return false
	return true
static func _valid_clock(value:Variant)->bool:
	return _keys(value,["tick_u32","day_u32"]) and _whole(value.tick_u32,0,MASK) and _whole(value.day_u32,0,MASK)
static func _copy_objects(objects:Dictionary)->Dictionary:
	var result:Dictionary={}
	for index:Variant in objects:result[index]=objects[index].duplicate()
	return result
static func _clock_copy(clock:Dictionary)->Dictionary:
	return {"tick_u32":int(clock.tick_u32),"day_u32":int(clock.day_u32)}
static func _position(body:PackedByteArray,offset:int=0x3e)->PackedInt64Array:
	return PackedInt64Array([body.decode_s64(offset),body.decode_s64(offset+8),body.decode_s64(offset+16)])
static func _write_position(body:PackedByteArray,value:PackedInt64Array,offset:int=0x3e)->void:
	for axis in range(3):body.encode_s64(offset+axis*8,value[axis])
static func _add_position(first:PackedInt64Array,second:PackedInt64Array,subtract:=false)->PackedInt64Array:
	var result:=PackedInt64Array()
	for axis in range(3):
		var a:=Orbit._words(first[axis]);var b:=Orbit._words(second[axis]);var low:int;var high:int
		if subtract:
			low=(a[0]-b[0])&MASK;high=(a[1]-b[1]-(1 if a[0]<b[0] else 0))&MASK
		else:
			var summed:int=a[0]+b[0];low=summed&MASK;high=(a[1]+b[1]+(summed>>32))&MASK
		result.append(Orbit.signed64(PackedInt64Array([low,high])))
	return result
static func _event()->Dictionary:return {"event_u32":11,"param_u32":0}
static func _scope()->Dictionary:
	return {"variant":VARIANT,"profile":PROFILE,"clock_advanced":false,"fuel_advanced":false,"hp_applied":false,"si_roundtrip":false,"full_f570_caller":false,"full_f585_controller":false,"full_object_allocation_manager":false,"complete_original_flight_pipeline":false,"jjffe_velocity_fix_selected":false}

static func parent_velocity_dos(parent:PackedByteArray)->Dictionary:
	if parent.size()!=OBJECT_BYTES:return {}
	var velocity:=PackedInt64Array([0,0,0]);var branch:="orbital_original_zero"
	if int(parent[0x87])!=1:
		branch="direct_velocity_words"
		for axis in range(3):velocity[axis]=parent.decode_s32(0x8c+axis*4)
	elif (int(parent[0x14c])&0x20)!=0:branch="flag_0x20_zero"
	# Original DOS F595 samples a private F1533/F866 copy but subtracts the
	# unchanged original EBX positions. Its observable orbital velocity is zero.
	# The copied orbital computation is not represented as a full F866 port.
	var result:=_scope();result.velocity_s32=velocity;result.branch=branch
	result.full_f866_executed=false;result.parent_unchanged=true
	if branch=="orbital_original_zero":
		var tick:int=parent.decode_u32(0xa8);var advanced:int=tick+0x82c00
		result.future_copy_clock={"tick_u32":advanced&MASK,"day_u32":(int(parent.decode_u32(0xac))+(advanced>>32))&MASK}
	return result
static func parent_velocity(parent:PackedByteArray,variant:String=VARIANT)->Dictionary:
	return parent_velocity_dos(parent) if variant==VARIANT else {}
static func _translate(body:PackedByteArray,parent:PackedByteArray,enter:bool,target_index:int)->Dictionary:
	if body.size()!=OBJECT_BYTES or parent.size()!=OBJECT_BYTES:return {}
	var evaluated:=parent_velocity_dos(parent)
	if evaluated.is_empty():return {}
	var result_body:=body.duplicate()
	result_body[0x56]=target_index if enter else int(parent[0x56])
	_write_position(result_body,_add_position(_position(body),_position(parent),enter))
	for axis in range(3):
		var value:int=body.decode_s32(0x8c+axis*4)
		value+=(-1 if enter else 1)*int(evaluated.velocity_s32[axis])
		result_body.encode_s32(0x8c+axis*4,Ground.signed32(value))
	var result:=_scope();result.body=result_body;result.events=[_event()]
	result.parent_velocity_s32=evaluated.velocity_s32.duplicate();result.parent_velocity_branch=evaluated.branch
	result.procedure="F605" if enter else "F604";result.bank_unchanged=true
	return result
static func translate_enter(body:PackedByteArray,parent:PackedByteArray,target_index:Variant)->Dictionary:
	if not _whole(target_index,1,MAX_INDEX):return {}
	return _translate(body,parent,true,int(target_index))
static func translate_leave(body:PackedByteArray,parent:PackedByteArray)->Dictionary:
	return _translate(body,parent,false,0)
static func transition(body:PackedByteArray,parent:PackedByteArray,enter:Variant,variant:String=VARIANT,target_index:Variant=1)->Dictionary:
	if not enter is bool or variant!=VARIANT:return {}
	return translate_enter(body,parent,target_index) if enter else translate_leave(body,parent)

static func _valid_state(player:PackedByteArray,objects:Dictionary,flags:PackedByteArray,clock:Dictionary,variant:String)->bool:
	if variant!=VARIANT or player.size()!=OBJECT_BYTES or flags.size()!=FLAGS_BYTES or not _valid_clock(clock) or objects.size()>MAX_INDEX-1:return false
	var own:=int(player[0x86])
	if own<1 or own>MAX_INDEX or objects.has(own) or (int(flags[own])&0x10)!=0:return false
	for key:Variant in objects:
		if not key is int or key<1 or key>MAX_INDEX or not objects[key] is PackedByteArray or objects[key].size()!=OBJECT_BYTES or int(objects[key][0x86])!=key:return false
	for index in range(1,MAX_INDEX+1):
		if (int(flags[index])&0x10)!=0 and not objects.has(index):return false
	var all:=objects.duplicate();all[own]=player
	for key:Variant in all:
		var seen:Dictionary={};var cursor:int=int(key)
		while cursor!=0:
			if seen.has(cursor) or not all.has(cursor):return false
			seen[cursor]=true;cursor=int(all[cursor][0x56])
	return true
func configure(player:PackedByteArray,objects:Dictionary,flags:PackedByteArray,clock:Dictionary,variant:String=VARIANT)->bool:
	if not _valid_state(player,objects,flags,clock,variant):return false
	_player=player.duplicate();_objects=_copy_objects(objects);_flags=flags.duplicate();_clock=_clock_copy(clock);_generation=0;return true
func is_active()->bool:return _player.size()==OBJECT_BYTES
func raw_player()->PackedByteArray:return _player.duplicate()
func raw_object(index:int)->PackedByteArray:
	return _objects[index].duplicate() if _objects.has(index) else PackedByteArray()
func raw_objects()->Dictionary:return _copy_objects(_objects)
func bank_flags()->PackedByteArray:return _flags.duplicate()
func raw_clock()->Dictionary:return _clock.duplicate(true)
func generation()->int:return _generation
func object_indices()->Array:
	var result:Array=_objects.keys();result.sort();return result
func _fork()->RefCounted:
	var result=get_script().new()
	result._player=_player.duplicate();result._objects=_copy_objects(_objects);result._flags=_flags.duplicate();result._clock=_clock_copy(_clock);result._generation=_generation
	return result
func _get_record(index:int)->PackedByteArray:
	return _player if index==int(_player[0x86]) else _objects[index]
func _set_record(index:int,body:PackedByteArray)->void:
	if index==int(_player[0x86]):_player=body
	else:_objects[index]=body
func _global(index:int,frame_byte:int)->PackedInt64Array:
	var body:=_get_record(index);var parent_index:=int(body[0x56])
	if parent_index!=0 and int(body[0x25])==frame_byte:return _position(body,0x26)
	var result:=_position(body)
	if parent_index!=0:
		var parent_global:=_global(parent_index,frame_byte)
		if int(body[0x57])!=0:
			var matrix:=PackedInt64Array();var parent:=_get_record(parent_index)
			for component in range(9):matrix.append(parent.decode_s32(component*4))
			var rotated:=Frame.rotate(body,matrix,false,frame_byte)
			if rotated.is_empty():return PackedInt64Array()
			result=_position(rotated.body)
		result=_add_position(parent_global,result)
	_write_position(body,result,0x26);body[0x25]=frame_byte;_set_record(index,body)
	return result
func _distance_shift(target:int,frame_byte:int)->int:
	var own:=int(_player[0x86]);var player_global:=_global(own,frame_byte)
	if player_global.size()!=3:return -1
	var target_body:=_get_record(target);var relative:PackedInt64Array
	if int(target_body[0x56])==int(_player[0x56]) and int(target_body[0x57])==int(_player[0x57]):
		relative=_add_position(_position(target_body),_position(_player),true)
	elif int(_player[0x56])==int(target_body[0x86]):
		relative=_add_position(PackedInt64Array([0,0,0]),_position(_player),true)
	else:
		var target_global:=_global(target,frame_byte)
		if target_global.size()!=3:return -1
		relative=_add_position(target_global,_position(_player,0x26),true)
	return maxi(0,Gravity._vec64_msb(relative)-13)
static func _score(shift:int,mass:int,left:int,added:int=0)->int:
	return Ground.signed32(Ground.signed32(Ground.signed32(shift-mass)<<left)+added)
func _select(frame_byte:int)->Dictionary:
	var events:Array=[];var trace:Array=[]
	if int(_player[0x57])!=0:return {"ok":true,"events":events,"trace":trace,"transition":"rotating_frame_unchanged"}
	var selected:=int(_player[0x56]);var grandparent:=0;var score:=0x32
	if selected!=0:
		var parent:=_get_record(selected);var shift:=_distance_shift(selected,frame_byte)
		if shift<0:return {"ok":false}
		score=_score(shift,int(parent.decode_s16(0xda)),2,0x20);grandparent=int(parent[0x56])
		trace.append({"index":selected,"relation":"current_parent","distance_shift_s32":shift,"score_s32":score})
		if grandparent!=0:
			shift=_distance_shift(grandparent,frame_byte)
			if shift<0:return {"ok":false}
			var ancestor:=_get_record(grandparent);var ancestor_score:=_score(shift,int(ancestor.decode_s16(0xda)),0,0x28)
			trace.append({"index":grandparent,"relation":"grandparent","distance_shift_s32":shift,"score_s32":ancestor_score})
			if ancestor_score<=score:
				var left:=translate_leave(_player,_get_record(selected));_player=left.body
				return {"ok":true,"events":left.events,"trace":trace,"transition":"leave_parent"}
	for index in range(MAX_INDEX,0,-1):
		if (int(_flags[index])&0x10)==0:continue
		var other:=_get_record(index);var relation:="";var candidate_score:=0
		if int(other[0x56])==int(_player[0x56]):relation="sibling"
		elif int(other[0x56])==grandparent:relation="parent_sibling"
		else:continue
		var shift:=_distance_shift(index,frame_byte)
		if shift<0:return {"ok":false}
		candidate_score=_score(shift,int(other.decode_s16(0xda)),4) if relation=="sibling" else _score(shift,int(other.decode_s16(0xda)),2,0x20)
		trace.append({"index":index,"relation":relation,"distance_shift_s32":shift,"score_s32":candidate_score})
		if candidate_score>=score:continue
		if relation=="sibling":selected=index;score=candidate_score
		else:
			var left:=translate_leave(_player,_get_record(int(_player[0x56])));_player=left.body
			return {"ok":true,"events":left.events,"trace":trace,"transition":"leave_parent"}
	if int(_player[0x56])!=selected:
		var entered:=translate_enter(_player,_get_record(selected),selected);_player=entered.body;events=entered.events
		return {"ok":true,"events":events,"trace":trace,"transition":"enter_parent"}
	return {"ok":true,"events":events,"trace":trace,"transition":"parent_unchanged"}
func _prepared(candidate:RefCounted,events:Array,procedure:String,trace:Array=[])->Dictionary:
	if candidate==null or not _valid_state(candidate._player,candidate._objects,candidate._flags,candidate._clock,VARIANT):return {"ok":false,"reason":"invalid_reference_candidate"}
	if _generation>=MAX_GENERATION:return {"ok":false,"reason":"reference_generation_limit"}
	candidate._generation=_generation+1
	var receipt:=_scope();receipt.procedure=procedure;receipt.events=events.duplicate(true);receipt.trace=trace.duplicate(true)
	receipt.parent_before_u8=int(_player[0x56]);receipt.parent_after_u8=int(candidate._player[0x56]);receipt.clock=_clock_copy(_clock)
	receipt.generation_before=_generation;receipt.generation_after=candidate._generation
	receipt.bank_cache_writes_allowed=procedure=="F606";receipt.automatic_parent_selection=procedure=="F606"
	return {"ok":true,"reason":"source_reference_transaction_prepared","candidate":candidate,"candidate_bank":candidate,"body":candidate.raw_player(),"objects_by_index":candidate.raw_objects(),"flags":candidate.bank_flags(),"events":events.duplicate(true),"receipt":receipt}
func prepare_transition(action:String,target_index:Variant=0)->Dictionary:
	if not is_active() or action not in ["enter_parent","leave_parent"]:return {"ok":false,"reason":"invalid_reference_transition"}
	var candidate:=_fork();var translated:Dictionary
	if action=="enter_parent":
		if not _whole(target_index,1,MAX_INDEX) or not _objects.has(int(target_index)) or int(_objects[int(target_index)][0x56])!=int(_player[0x56]):return {"ok":false,"reason":"target_is_not_a_child_of_current_frame"}
		translated=translate_enter(candidate._player,candidate._objects[int(target_index)],int(target_index))
	else:
		var parent:=int(_player[0x56])
		if parent==0 or not _objects.has(parent):return {"ok":false,"reason":"root_frame_has_no_parent"}
		translated=translate_leave(candidate._player,candidate._objects[parent])
	if translated.is_empty():return {"ok":false,"reason":"reference_translation_rejected"}
	candidate._player=translated.body
	return _prepared(candidate,translated.events,translated.procedure)
func prepare_select(source_frame_byte:Variant)->Dictionary:
	if not is_active() or not _whole(source_frame_byte,0,255):return {"ok":false,"reason":"invalid_source_frame_byte"}
	var candidate:=_fork();var selected:Dictionary=candidate._select(int(source_frame_byte))
	if not selected.get("ok",false):return {"ok":false,"reason":"source_parent_selection_rejected"}
	return _prepared(candidate,selected.events,"F606",selected.trace)
func prepare_rebind(player:PackedByteArray,new_clock:Dictionary)->Dictionary:
	# An outer verified raw-motion/clock transaction may supply its exact
	# records. This is an ownership operation, not an implementation of F570.
	# Source cache stamps remain raw; the caller owns DATA_008811 on selection.
	if not is_active() or player.size()!=OBJECT_BYTES or int(player[0x86])!=int(_player[0x86]) or int(player[0x56])!=int(_player[0x56]) or int(player[0x57])!=int(_player[0x57]) or not _valid_clock(new_clock):return {"ok":false,"reason":"invalid_raw_reference_rebind"}
	var candidate:=_fork();candidate._player=player.duplicate();candidate._clock=_clock_copy(new_clock)
	var result:=_prepared(candidate,[],"caller-owned-raw-state-rebind-not-native-F570")
	if result.get("ok",false):
		result.receipt.clock_before=_clock_copy(_clock);result.receipt.clock_after=_clock_copy(new_clock)
		result.receipt.clock_advanced=_clock!=candidate._clock
		result.receipt.source_clock_interval_executed_here=false
		result.receipt.celestial_f866_advanced=false
		result.receipt.cache_policy="preserve-source-cache-bytes-caller-owns-next-source-frame-byte"
	return result
static func select_parent(body:PackedByteArray,objects:Dictionary,flags:PackedByteArray,source_frame_byte:Variant)->Dictionary:
	var state:=new()
	if not state.configure(body,objects,flags,{"tick_u32":0,"day_u32":0}):return {}
	var result:=state.prepare_select(source_frame_byte)
	return result if result.get("ok",false) else {}
func snapshot()->Dictionary:
	if not is_active():return {}
	var objects:Array=[]
	for index:int in object_indices():objects.append({"index":index,"object_hex":_objects[index].hex_encode()})
	return {"schema":SCHEMA,"version":1,"profile":PROFILE,"variant":VARIANT,"player_hex":_player.hex_encode(),"objects":objects,"flags_hex":_flags.hex_encode(),"clock":_clock_copy(_clock),"generation":_generation,"snapshot_sha256":_state_digest()}
func _state_digest()->String:
	var raw:PackedByteArray=(SCHEMA+"|1|"+PROFILE+"|"+VARIANT).to_utf8_buffer()
	var numbers:=PackedByteArray();numbers.resize(18)
	numbers.encode_u32(0,int(_clock.tick_u32));numbers.encode_u32(4,int(_clock.day_u32));numbers.encode_s64(8,_generation);numbers.encode_u16(16,_objects.size())
	raw.append_array(numbers);raw.append_array(_player);raw.append_array(_flags)
	for index:int in object_indices():raw.append(index);raw.append_array(_objects[index])
	var hasher:=HashingContext.new();hasher.start(HashingContext.HASH_SHA256);hasher.update(raw)
	return hasher.finish().hex_encode()
func restore(data:Variant)->bool:
	if not _keys(data,SNAPSHOT_KEYS) or data.schema!=SCHEMA or not _whole(data.version,1,1) or data.profile!=PROFILE or data.variant!=VARIANT or not _hex(data.player_hex,OBJECT_BYTES) or not _hex(data.flags_hex,FLAGS_BYTES) or not _hex(data.snapshot_sha256,32) or not data.objects is Array or data.objects.size()>MAX_INDEX-1 or not _valid_clock(data.clock) or not _whole(data.generation,0,MAX_GENERATION):return false
	var objects:Dictionary={};var previous:=0
	for row:Variant in data.objects:
		if not _keys(row,["index","object_hex"]) or not _whole(row.index,1,MAX_INDEX) or int(row.index)<=previous or not _hex(row.object_hex,OBJECT_BYTES):return false
		previous=int(row.index);objects[previous]=str(row.object_hex).hex_decode()
	var player:=str(data.player_hex).hex_decode();var flags:=str(data.flags_hex).hex_decode()
	if not _valid_state(player,objects,flags,data.clock,VARIANT):return false
	var candidate=get_script().new();candidate._player=player;candidate._objects=objects;candidate._flags=flags;candidate._clock=_clock_copy(data.clock);candidate._generation=int(data.generation)
	if candidate._state_digest()!=data.snapshot_sha256:return false
	_player=player;_objects=objects;_flags=flags;_clock=_clock_copy(data.clock);_generation=int(data.generation);return true
