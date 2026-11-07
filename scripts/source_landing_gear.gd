extends RefCounted
# Uploaded FIRSTENC.EXE F1008 and the bounded F1056/JUMP_004410 dispatch
# branch. The caller has already selected the original undercarriage action;
# this module does not implement the rest of F1056 or execute GUI/sound code.
# Source game+E9 bit2 means RETRACT, not "gear down". Physical position+9E
# is0 when retracted and0xFFFF when deployed (the original F575 contact gate).
const SOURCE_SHA:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const CONTRACT:="dos-firstenc-f1008-f1056-gear-branch-v1"
const MASK:=0xffffffff
const RETRACT_FLAG:=0x02
const WARNING_FLAG:=0x02
const DEPLOYED_POSITION:=0xffff
const BLOCKED_TOGGLE_PHASE:=0x24
const AUTO_FLIGHT_STATE:=2
const AUTO_RETRACT_LAST_PHASE:=0x1e
const WARNING_SPEED_RAW:=100000
const WARNING_MESSAGE:=0x98ce
const STATE_KEYS:=["position_u16","object_timer_u16","autopilot_phase_u8","flight_state_u8","control_flags_u8","warning_flags_u16","speed_s32"]

static func _whole(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
static func valid_state(state:Dictionary)->bool:
	for key:String in STATE_KEYS:
		if not state.has(key):return false
	for key:String in ["position_u16","object_timer_u16","warning_flags_u16"]:
		if not _whole(state[key],0,65535):return false
	for key:String in ["autopilot_phase_u8","flight_state_u8","control_flags_u8"]:
		if not _whole(state[key],0,255):return false
	return _whole(state.speed_s32,-2147483648,2147483647)
static func _reject(state:Dictionary,reason:String)->Dictionary:
	return {"ok":false,"accepted":false,"changed":false,"state":state.duplicate(true),"reason":reason,"callbacks":[],"source_contract":CONTRACT,"source_sha256":SOURCE_SHA}
static func _result(original:Dictionary,state:Dictionary,reason:String,callbacks:Array,accepted:=true)->Dictionary:
	var down:bool=(int(state.control_flags_u8)&RETRACT_FLAG)==0
	var deployed:bool=int(state.position_u16)==DEPLOYED_POSITION
	var retracted:bool=int(state.position_u16)==0
	return {"ok":true,"accepted":accepted,"changed":state!=original,"state":state,"reason":reason,"callbacks":callbacks,"requested_down":down,"deployed":deployed,"retracted":retracted,"moving":not deployed if down else not retracted,"source_contract":CONTRACT,"source_sha256":SOURCE_SHA,"source_tick_units":"DATA9155 unsigned master ticks per F1008 player-state invocation, not F152 whole display seconds"}

static func toggle(input:Dictionary)->Dictionary:
	if not valid_state(input):return _reject(input,"invalid_state")
	var state:=input.duplicate(true);var callbacks:Array=[]
	if int(state.autopilot_phase_u8)==BLOCKED_TOGGLE_PHASE:
		callbacks.append({"function":"F1906","sample":0x14})
		return _result(input,state,"blocked_source_phase",callbacks,false)
	state.control_flags_u8=int(state.control_flags_u8)^RETRACT_FLAG
	state.warning_flags_u16=int(state.warning_flags_u16)&0xfffd
	var image:=0 if (int(state.control_flags_u8)&RETRACT_FLAG)!=0 else 1
	callbacks.append({"function":"F262","button":0x38,"image":image})
	callbacks.append({"function":"F262","button":0x46,"image":image})
	callbacks.append({"function":"F1116"})
	callbacks.append({"function":"F1906","sample":0x0c})
	callbacks.append({"function":"F1906","sample":0x14})
	# No source flight state, autopilot phase or physical position is changed
	# by this selected branch. F1008 advances/overrides the request afterwards.
	return _result(input,state,"toggled",callbacks)

static func step(input:Dictionary,step_ticks_u32:Variant)->Dictionary:
	if not valid_state(input):return _reject(input,"invalid_state")
	if not _whole(step_ticks_u32,0,MASK):return _reject(input,"invalid_master_ticks")
	var state:=input.duplicate(true);var callbacks:Array=[];var ticks:int=int(step_ticks_u32)
	# F1008 begins by updating an independent object+E8 timer. Its purpose is
	# outside this selected host module; it must not become a gear-motion delay.
	if int(state.object_timer_u16)!=0:
		state.object_timer_u16=0 if ticks>65535 or ticks>int(state.object_timer_u16) else int(state.object_timer_u16)-ticks
	if int(state.flight_state_u8)==AUTO_FLIGHT_STATE:
		state.warning_flags_u16=int(state.warning_flags_u16)&0xfffd
		if int(state.autopilot_phase_u8)>AUTO_RETRACT_LAST_PHASE:
			if (int(state.control_flags_u8)&RETRACT_FLAG)!=0:callbacks.append({"function":"F1116"})
			state.control_flags_u8=int(state.control_flags_u8)&0xfd
		else:
			state.control_flags_u8=int(state.control_flags_u8)|RETRACT_FLAG
			# The original OR followed by TEST emits this refresh on EVERY
			# low-phase automatic invocation, including zero elapsed ticks.
			callbacks.append({"function":"F1116"})
	var motion_ticks:int=ticks>>1
	if (int(state.control_flags_u8)&RETRACT_FLAG)!=0:
		state.position_u16=maxi(0,int(state.position_u16)-motion_ticks)
	else:
		if int(state.flight_state_u8)!=AUTO_FLIGHT_STATE and int(state.speed_s32)>=WARNING_SPEED_RAW:
			if (int(state.warning_flags_u16)&WARNING_FLAG)==0:callbacks.append({"function":"F1097","message":WARNING_MESSAGE,"priority_s32":-1})
			state.warning_flags_u16=int(state.warning_flags_u16)|WARNING_FLAG
		state.position_u16=mini(DEPLOYED_POSITION,int(state.position_u16)+motion_ticks)
	return _result(input,state,"advanced",callbacks)
