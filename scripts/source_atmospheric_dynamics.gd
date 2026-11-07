extends RefCounted
# Uploaded FIRSTENC.EXE F1014/F1016/F1017 integer transitions. The original
# F1014 heat increment is per invocation; choosing a modern caller frequency
# is a separate, explicitly named policy. No JJFFE heat/drag fixes are used.
# Calls into damage, sound, object lookup and event modules are observations;
# this pure module never mutates another gameplay model or executes a GUI.
const SOURCE_SHA:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const CONTRACT:="dos-firstenc-f1014-atmosphere-v1"
const DAMAGE_CONTRACT:="dos-firstenc-f953-shield-hull-callbacks-v1"
const MASK:=0xffffffff
const ALTITUDE_LIMIT:=20000000
const DRAG_MIN_SPEED:=3000
const DRAG_MAX_TICKS:=0xfffff
const ATMOSPHERE_KEYS:=["altitude_s32","speed_s32","heat_s32","velocity_s32","shielding","gear_down","wind_enabled","wind_armed","parent_shield_s16","wind_flags_u8"]
const DAMAGE_KEYS:=["object_index_u8","kind_u8","volume_s8","player_selector_u8","shield_u16","hull_u16","damage_timer_u8","damage_flags_u8"]

static func _whole(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
static func _s32(value:int)->int:
	value&=MASK;return value-0x100000000 if value>=0x80000000 else value
static func multiply_q31(first:int,second:int)->int:
	# F1521 signed IMUL and SHL/RCL return the high word of product*2.
	return _s32((_s32(first)*_s32(second))>>31)
static func _reject(state:Dictionary,reason:String,contract:=CONTRACT)->Dictionary:
	return {"ok":false,"changed":false,"state":state.duplicate(true),"reason":reason,"damage_calls":[],"callbacks":[],"source_contract":contract,"source_sha256":SOURCE_SHA}
static func valid_atmosphere(state:Dictionary)->bool:
	for key:String in ATMOSPHERE_KEYS:
		if not state.has(key):return false
	for key:String in ["altitude_s32","speed_s32","heat_s32"]:
		if not _whole(state[key],-2147483648,2147483647):return false
	for key:String in ["shielding","gear_down","wind_enabled","wind_armed"]:
		if not state[key] is bool:return false
	if not _whole(state.parent_shield_s16,-32768,32767) or not _whole(state.wind_flags_u8,0,255):return false
	if not state.velocity_s32 is Array or state.velocity_s32.size()!=3:return false
	for value:Variant in state.velocity_s32:
		if not _whole(value,-2147483648,2147483647):return false
	return true

static func atmosphere(input:Dictionary,step_ticks_u32:Variant)->Dictionary:
	if not valid_atmosphere(input):return _reject(input,"invalid_state")
	if not _whole(step_ticks_u32,0,MASK):return _reject(input,"invalid_master_ticks")
	var state:=input.duplicate(true);var damage_calls:Array=[];var callbacks:Array=[]
	var result:={"ok":true,"changed":false,"state":state,"reason":"above_atmosphere","damage_calls":damage_calls,"callbacks":callbacks,"heat_increment_s32":0,"drag_factor_s32":0,"overheat_requested":false,"source_contract":CONTRACT,"source_sha256":SOURCE_SHA,"source_heat_cadence":"one increment per original player-state invocation; not F152 whole seconds"}
	# +DC is F1033's HUD-normalized altitude, not the untouched F569 result.
	# An unknown raw height -1 becomes 0x7FFFFFFF before this procedure.
	if int(state.altitude_s32)>ALTITUDE_LIMIT:return result
	result.reason="atmosphere"
	var shift:=(11 if state.shielding else 5)-(0 if state.gear_down else 1)
	var increment:int=int(state.speed_s32)>>shift
	result.heat_increment_s32=increment
	if _s32(int(state.heat_s32)+increment)>65535:
		damage_calls.append({"amount_s32":-1,"attacker_u32":0})
		callbacks.append({"function":"F953","amount_s32":-1,"attacker_u32":0})
		result.overheat_requested=true
		# DOS deliberately does not store the overflowing/fatal candidate heat.
	else:
		state.heat_s32=_s32(int(state.heat_s32)+increment)
		var damage:int=increment>>8
		if damage>0:
			damage_calls.append({"amount_s32":damage,"attacker_u32":0})
			callbacks.append({"function":"F953","amount_s32":damage,"attacker_u32":0})
	if state.wind_enabled and state.wind_armed:
		callbacks.append({"function":"F1532"})
		if int(state.parent_shield_s16)<0x116:
			state.wind_flags_u8=int(state.wind_flags_u8)|0x40
			callbacks.append({"function":"F1906","sample":14})
	if int(state.speed_s32)<DRAG_MIN_SPEED:
		callbacks.append({"function":"F1017"})
	else:
		var factor:=mini(int(step_ticks_u32),DRAG_MAX_TICKS)<<11
		result.drag_factor_s32=factor
		for axis in range(3):
			state.velocity_s32[axis]=_s32(int(state.velocity_s32[axis])-multiply_q31(int(state.velocity_s32[axis]),factor))
		# F1016 checks this same +DC alias; its F1017 target is an actual DOS
		# no-op. Preserve the observed calls without inventing lift or damage.
		callbacks.append({"function":"F1016"});callbacks.append({"function":"F1017"})
	result.changed=state!=input
	return result

static func near_surface(input:Dictionary)->Dictionary:
	# Complete DOS F1016: its only conditional effect is calling F1017.
	if not _whole(input.get("altitude_s32"),-2147483648,2147483647):return _reject(input,"invalid_altitude")
	return {"ok":true,"changed":false,"state":input.duplicate(true),"callbacks":[{"function":"F1017"}] if int(input.altitude_s32)<=ALTITUDE_LIMIT else [],"source_procedure":"F1016","source_sha256":SOURCE_SHA}

static func surface_stub(input:Dictionary)->Dictionary:
	# Complete DOS F1017 allocates and immediately discards its stack frame.
	# No lift, gear damage, heating or material response can be inferred here.
	return {"ok":true,"changed":false,"state":input.duplicate(true),"callbacks":[],"source_procedure":"F1017","source_sha256":SOURCE_SHA}

static func rng(input:Dictionary)->Dictionary:
	# F1530's shared source generator, exposed as a pure transition. A caller
	# which uses a local sequence must name that policy; this is not the yet
	# unported AI/event engine's global stream.
	if not _whole(input.get("seed_a_u32"),0,MASK) or not _whole(input.get("seed_b_u32"),0,MASK):return {"ok":false,"state":input.duplicate(true),"reason":"invalid_rng_state"}
	var state:=input.duplicate(true);var previous:int=int(state.seed_a_u32)
	var mixed:int=int(state.seed_b_u32)^0x1234567f
	var rotated:int=((mixed<<25)|(mixed>>7))&MASK
	state.seed_a_u32=(previous+rotated)&MASK
	state.seed_b_u32=((previous<<13)|(previous>>19))&MASK
	return {"ok":true,"state":state,"value_u16":int(state.seed_a_u32)&65535,"source_procedure":"F1530","source_sha256":SOURCE_SHA}

static func valid_damage(state:Dictionary)->bool:
	for key:String in DAMAGE_KEYS:
		if not state.has(key):return false
	for key:String in ["object_index_u8","kind_u8","player_selector_u8","damage_timer_u8","damage_flags_u8"]:
		if not _whole(state[key],0,255):return false
	if not _whole(state.volume_s8,-128,127):return false
	for key:String in ["shield_u16","hull_u16"]:
		if not _whole(state[key],0,65535):return false
	return true

static func _damage_context(context:Dictionary)->bool:
	for key:String in ["object_flags_u8"]:
		if not _whole(context.get(key,0),0,255):return false
	if not context.get("has_spec",true) is bool:return false
	if not context.get("module_flags_u8",[]) is Array or context.get("module_flags_u8",[]).size()>4096:return false
	for flag:Variant in context.get("module_flags_u8",[]):
		if not _whole(flag,0,255):return false
	for key:String in ["filtered_damage_s32","destruction_return_s32","equipment_return_s32"]:
		if context.has(key) and not _whole(context[key],-2147483648,2147483647):return false
	if context.has("rng_u32") and not _whole(context.rng_u32,0,MASK):return false
	if context.has("rng_state") and not context.rng_state is Dictionary:return false
	if context.has("rng_state") and not rng(context.rng_state).ok:return false
	return true

static func damage(input:Dictionary,amount_s32:Variant,attacker_u32:Variant=0,context:Dictionary={})->Dictionary:
	if not valid_damage(input):return _reject(input,"invalid_state",DAMAGE_CONTRACT)
	if not _whole(amount_s32,-2147483648,2147483647) or not _whole(attacker_u32,0,MASK) or not _damage_context(context):return _reject(input,"invalid_damage_context",DAMAGE_CONTRACT)
	var normalized:int=2147483647 if int(amount_s32)<0 else int(amount_s32)
	var filtered:int=int(context.get("filtered_damage_s32",normalized))
	var state:=input.duplicate(true);var callbacks:Array=[]
	var result:={"ok":true,"changed":false,"state":state,"reason":"sound_only","callbacks":callbacks,"destruction_requested":false,"equipment_damage_requested":false,"rng_consumed":false,"rng_state":context.get("rng_state",{}).duplicate(true),"return_s32":1,"normalized_damage_s32":normalized,"filtered_damage_s32":filtered,"source_contract":DAMAGE_CONTRACT,"source_sha256":SOURCE_SHA,"event_filter_policy":"explicit-filter-result" if context.has("filtered_damage_s32") else "identity-event-filter-adapter","callback_policy":"F942/F952/module effects requested, not executed"}
	callbacks.append({"function":"F34","register":13,"value_u32":int(state.object_index_u8)})
	callbacks.append({"function":"F34","register":14,"value_u32":int(attacker_u32)})
	callbacks.append({"function":"F34","register":12,"value_u32":normalized})
	callbacks.append({"function":"F35","register":12,"return_s32":filtered})
	var modules:Array=context.get("module_flags_u8",[])
	for index in range(modules.size()):
		if int(modules[index])&4:callbacks.append({"function":"F144","module_index":index,"event":11,"code":1,"object_index_u8":int(state.object_index_u8)})
	var eligible:bool=int(state.kind_u8)==3
	if int(state.kind_u8)==11 and (int(context.get("object_flags_u8",0))&0x10)==0:
		callbacks.append({"function":"F1538"});eligible=bool(context.get("has_spec",true))
	if not eligible:
		callbacks.append({"function":"F1907","sample":29,"volume_s8":int(state.volume_s8)})
		return result
	result.reason="shield"
	if filtered<=int(state.shield_u16):
		state.shield_u16=(int(state.shield_u16)-(filtered&65535))&65535
		callbacks.append({"function":"F1907","sample":28,"volume_s8":int(state.volume_s8)})
		state.damage_flags_u8=int(state.damage_flags_u8)|1
	else:
		var remainder:int=_s32(filtered-int(state.shield_u16))
		state.shield_u16=0
		if remainder>=int(state.hull_u16):
			result.reason="destroy";result.destruction_requested=true
			callbacks.append({"function":"F942","attacker_u32":int(attacker_u32)})
			result.return_s32=int(context.get("destruction_return_s32",0))
			result.changed=state!=input;return result
		state.hull_u16=(int(state.hull_u16)-(remainder&65535))&65535
		state.damage_timer_u8=10
		callbacks.append({"function":"F1907","sample":29,"volume_s8":int(state.volume_s8)})
		result.reason="hull"
		var quarter:int=int(state.hull_u16)>>2
		var equipment:bool=remainder>=quarter
		if not equipment:
			var random_value:int=0
			if context.has("rng_u32"):
				random_value=int(context.rng_u32);result["rng_policy"]="explicit-F1530-callback-result"
			elif context.has("rng_state"):
				var next:=rng(context.rng_state);random_value=int(next.value_u16);result.rng_state=next.state;result["rng_policy"]="source-F1530-pure-state"
			else:return _reject(input,"missing_rng_state",DAMAGE_CONTRACT)
			result.rng_consumed=true;callbacks.append({"function":"F1530","return_u32":random_value})
			# IDIV is reached only with positive quarter>remainder>0 here.
			@warning_ignore("integer_division")
			var threshold:int=_s32(remainder<<15)/quarter
			equipment=random_value<threshold
		if equipment:
			result.reason="equipment_request";result.equipment_damage_requested=true
			callbacks.append({"function":"F952"});result.return_s32=int(context.get("equipment_return_s32",0))
			result.changed=state!=input;return result
	if int(state.player_selector_u8)==255:callbacks.append({"function":"F148","action":23,"value":0})
	result.changed=state!=input
	return result
