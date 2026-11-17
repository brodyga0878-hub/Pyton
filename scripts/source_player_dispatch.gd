extends RefCounted
# Original DOS player control-preparation and drift callbacks. F1041 does not
# kick or drift: its order is angular half-step twice, gravity, spin copying,
# reference-frame request, then thrust selection. Full F1019/F570 scheduling,
# F606 execution, audio and the outer player/event owner remain separate.
const Angular=preload("res://scripts/source_angular_motion.gd")
const Motion=preload("res://scripts/source_motion_pipeline.gd")
const Gravity=preload("res://scripts/source_gravity.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
const PROFILE:="dos-firstenc-player-control-dispatch-v1"
const SOURCE_EXE_SHA256:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const OBJECT_BYTES:=338
const MASK:=0xffffffff
const GLOBAL_KEYS:=["frame_ticks_u32","spin_elapsed_s32","player_mode_u8","flight_flags_u8","set_speed_s32","damping_flags_u8","reference_velocity_s32","forward_key_u8","reverse_key_u8","spin_xyz_s32","player_index_u32","player_roll_s16","drift_ticks_low_u32","drift_ticks_high_u32"]
const OPERATIONS:=["prepare_f1041","manual_f1043","drift_f1044","drift_f1045"]

static func _whole(value:Variant,minimum:int,maximum:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=minimum and float(value)<=maximum and float(value)==floorf(float(value))
static func _vector(value:Variant)->bool:
	if not (value is Array or value is PackedInt64Array) or value.size()!=3:return false
	for cell:Variant in value:
		if not _whole(cell,-0x80000000,0x7fffffff):return false
	return true
static func _globals(value:Variant)->bool:
	if not value is Dictionary or value.size()!=GLOBAL_KEYS.size():return false
	for key:String in GLOBAL_KEYS:
		if not value.has(key):return false
	for key:String in ["frame_ticks_u32","player_index_u32","drift_ticks_low_u32","drift_ticks_high_u32"]:
		if not _whole(value[key],0,MASK):return false
	for key:String in ["spin_elapsed_s32","set_speed_s32"]:
		if not _whole(value[key],-0x80000000,0x7fffffff):return false
	for key:String in ["player_mode_u8","flight_flags_u8","damping_flags_u8","forward_key_u8","reverse_key_u8"]:
		if not _whole(value[key],0,255):return false
	return _whole(value.player_roll_s16,-32768,32767) and _vector(value.reference_velocity_s32) and _vector(value.spin_xyz_s32)
static func _copy_globals(value:Dictionary)->Dictionary:
	var result:Dictionary={}
	for key:String in GLOBAL_KEYS:
		if key in ["reference_velocity_s32","spin_xyz_s32"]:
			result[key]=[int(value[key][0]),int(value[key][1]),int(value[key][2])]
		else:result[key]=int(value[key])
	return result
static func _body(value:Variant)->bool:return value is PackedByteArray and value.size()==OBJECT_BYTES
static func _s32(value:int)->int:return Ground.signed32(value)
static func _s8(value:int)->int:return value-256 if value>=128 else value
static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"raw_owners_mutated":false,"full_original_player_pipeline":false,"full_F606_executed":false,"audio_effects_applied":false}
static func _result(body:PackedByteArray,state:Dictionary,requests:Array,order:Array)->Dictionary:
	return {"ok":true,"profile":PROFILE,"body_after":body,"globals_after":state,"requests":requests,"source_order":order,"frame_selection_requested":false,"frame_boundary_body":PackedByteArray(),"response_applied":false,"raw_owners_mutated":false,"full_original_player_pipeline":false,"full_F606_executed":false,"audio_effects_applied":false,"quaternion_reconstruction_used":false}

static func manual_f1043(body:Variant,globals:Variant)->Dictionary:
	if not _body(body) or not _globals(globals):return _reject("invalid_manual_context")
	var candidate:PackedByteArray=body.duplicate();var state:=_copy_globals(globals)
	var command:=PackedInt64Array([0,0,0]);var requests:Array=[]
	if (int(state.damping_flags_u8)&2)!=0:
		var delta:=PackedInt64Array()
		for axis in range(3):delta.append(_s32(candidate.decode_s32(0x8c+axis*4)-int(state.reference_velocity_s32[axis])))
		var side:=0;var up:=0
		for axis in range(3):
			side=_s32(side+Ground.multiply_q31(candidate.decode_s32(axis*4),delta[axis]))
			up=_s32(up+Ground.multiply_q31(candidate.decode_s32(0xc+axis*4),delta[axis]))
		if side>0x100 or side< -0x100:command[0]=_s32(_s32(-side)<<2)
		if up>0x100 or up< -0x100:command[1]=_s32(_s32(-up)<<2)
	# Actual DOS keys are active-low. The first key jumps directly to F599;
	# reverse is considered only when forward was not pressed. JJFFE's later
	# 6DOF overrides and removed jumps are not part of this variant.
	if int(state.forward_key_u8)==0:command[2]=0x7fff
	elif int(state.reverse_key_u8)==0:command[2]=-0x7fff
	else:requests.append({"kind":"F1910","args":[3,1,300]})
	var thrust:=Motion.set_thrust(candidate,command)
	if thrust.is_empty():return _reject("manual_thrust_rejected")
	var result:=_result(thrust.body,state,requests,["F1043","F599"])
	result.command_s32=thrust.command_s32.duplicate();return result

static func prefix_f1041(body:Variant,parent:Variant,globals:Variant)->Dictionary:
	if not _body(body) or not _body(parent) or not _globals(globals):return _reject("invalid_control_context")
	var candidate:PackedByteArray=body.duplicate();var state:=_copy_globals(globals)
	var half_ticks:=(int(state.frame_ticks_u32)&MASK)>>1
	var angular_globals:={"player_index_u32":int(state.player_index_u32),"player_roll_s16":int(state.player_roll_s16)}
	for repeat_index in range(2):
		var angular:=Angular.step_raw(candidate,half_ticks,false,half_ticks,angular_globals)
		if not angular.get("ok",false):return _reject("angular_half_step_rejected")
		candidate=angular.body_after;angular_globals=angular.globals_after
	state.player_roll_s16=int(angular_globals.player_roll_s16)
	# F603 shares DATA8708..8710 with F609. It overwrites those words with
	# its truncated radial vector whenever the parent/mass path is entered;
	# the no-parent/zero-mass paths retain their previous contents.
	var gravity:=Gravity.update(candidate,parent,_s32(int(state.frame_ticks_u32)),PackedInt64Array(state.spin_xyz_s32))
	if gravity.is_empty():return _reject("source_gravity_rejected")
	candidate=gravity.body
	state.spin_xyz_s32=Array(gravity.scratch_s32)
	var order:Array=["F1041","F585","F585","F603"]
	if int(state.spin_elapsed_s32)<=0x2625a00:
		var spinning:=Angular.spin_command_raw(candidate,PackedInt64Array(state.spin_xyz_s32))
		if not spinning.get("ok",false):return _reject("source_spin_rejected")
		candidate=spinning.body_after
		candidate.encode_u16(0xb2,candidate.decode_u16(0x112));order.append("F609")
	candidate[0x14d]=(int(candidate[0x14d])-1)&255
	var needs_frame:=_s8(int(candidate[0x14d]))<0
	var requests:Array=[]
	if needs_frame:
		requests.append({"kind":"F606","body_hex_at_call":candidate.hex_encode()});order.append("F606")
	var result:=_result(candidate,state,requests,order)
	result.frame_selection_requested=needs_frame
	result.frame_boundary_body=candidate.duplicate() if needs_frame else PackedByteArray()
	return result

static func _frame_response_valid(before:PackedByteArray,response:Variant)->bool:
	if not _body(response):return false
	# The observer response is an explicitly supplied F606 boundary result.
	# Its provenance belongs to the outer frame owner, not this arithmetic
	# callback. Even there it cannot alter unrelated player bytes.
	for offset in range(OBJECT_BYTES):
		var mutable:bool=(offset>=0x25 and offset<0x57) or (offset>=0x8c and offset<0x98)
		if not mutable and before[offset]!=response[offset]:return false
	return true
static func prepare_f1041(body:Variant,parent:Variant,globals:Variant,frame_response:Variant=null)->Dictionary:
	var prefix:=prefix_f1041(body,parent,globals)
	if not prefix.get("ok",false):return prefix
	var candidate:PackedByteArray=prefix.body_after.duplicate();var state:Dictionary=prefix.globals_after
	if prefix.frame_selection_requested:
		if frame_response!=null:
			if not _frame_response_valid(candidate,frame_response):return _reject("invalid_F606_boundary_response")
			candidate=frame_response.duplicate()
		candidate[0x14d]=13
	elif frame_response!=null:return _reject("unexpected_F606_boundary_response")
	var order:Array=prefix.source_order.duplicate();var requests:Array=prefix.requests.duplicate(true)
	var thrust:Dictionary
	if int(state.player_mode_u8)==0x24:
		thrust=Motion.set_thrust(candidate,PackedInt64Array([0,0xcc6,0]));order.append("F599")
	elif (int(state.flight_flags_u8)&1)!=0:
		var manual:=manual_f1043(candidate,state)
		if not manual.get("ok",false):return manual
		thrust={"body":manual.body_after,"command_s32":manual.command_s32}
		requests.append_array(manual.requests);order.append_array(manual.source_order)
	else:
		var desired:=Motion.desired_acceleration(candidate,int(state.set_speed_s32))
		if desired.is_empty():return _reject("speedhold_rejected")
		thrust=Motion.set_thrust(desired.body,desired.command_s32);order.append_array(["F607","F599"])
	if thrust.is_empty():return _reject("control_thrust_rejected")
	var result:=_result(thrust.body,state,requests,order)
	result.frame_selection_requested=prefix.frame_selection_requested
	result.frame_boundary_body=prefix.frame_boundary_body.duplicate()
	result.command_s32=thrust.command_s32.duplicate()
	result.response_applied=frame_response!=null
	return result

static func drift_raw(body:Variant,globals:Variant,through_f1044:bool=false)->Dictionary:
	if not _body(body) or not _globals(globals):return _reject("invalid_drift_context")
	var state:=_copy_globals(globals)
	var advanced:=Gravity.integrate(body,PackedInt64Array([int(state.drift_ticks_low_u32),int(state.drift_ticks_high_u32)]))
	if advanced.is_empty():return _reject("source_drift_rejected")
	return _result(advanced.body,state,[],["F1044","F1045","F1512"] if through_f1044 else ["F1045","F1512"])
static func execute(operation:Variant,body:Variant,parent:Variant,globals:Variant,frame_response:Variant=null)->Dictionary:
	if not operation is String or operation not in OPERATIONS:return _reject("unknown_player_callback")
	match operation:
		"prepare_f1041":return prepare_f1041(body,parent,globals,frame_response)
		"manual_f1043":
			if frame_response!=null:return _reject("unexpected_F606_boundary_response")
			return manual_f1043(body,globals)
		"drift_f1044","drift_f1045":
			if frame_response!=null:return _reject("unexpected_F606_boundary_response")
			return drift_raw(body,globals,operation=="drift_f1044")
	return _reject("unknown_player_callback")
