extends RefCounted
# Whole DOS F1046 plus F1033/F1034 after a matched F569 observation. The
# source root owns clocks E0/E4 and flags C6. Particle allocation/RNG, sound,
# UI/messages and destruction are ordered requests, never invented effects.
const Scoop=preload("res://scripts/source_fuel_scoop.gd")
const Gravity=preload("res://scripts/source_gravity.gd")
const PROFILE:="dos-firstenc-player-motion-contact-v1"
const SOURCE_EXE_SHA256:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
const ROOT_BYTES:=0x4000
const OBJECT_BYTES:=338
const MASK:=0xffffffff
const GLOBAL_KEYS:=["effect_gate_s32","sound_mode_s8","step_u32"]
const OPERATIONS:=["effects_f1046","contact_f1033","decay_f1034"]
const CONTACT_PROFILE:="dos-firstenc-f569-explicit-observation-v1"
const CONTACT_KEYS:=["caller_profile","body_before_hex","body_after_hex","flags_u8","altitude_raw_s32","collider_ref_u32","collider_index_u8","material_u8","collider_body_hex"]
static func _whole(value:Variant,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=low and float(value)<=high
static func _keys(value:Variant,keys:Array)->bool:
	if not value is Dictionary or value.size()!=keys.size():return false
	for key:Variant in keys:
		if not value.has(key):return false
	return true
static func _hex(value:Variant,count:int)->bool:
	if not value is String or value.length()!=count*2:return false
	for code:int in value.to_ascii_buffer():
		if not (code>=48 and code<=57 or code>=97 and code<=102):return false
	return true
static func _globals(value:Variant)->bool:
	return _keys(value,GLOBAL_KEYS) and _whole(value.effect_gate_s32,-0x80000000,0x7fffffff) and _whole(value.sound_mode_s8,-128,127) and _whole(value.step_u32,0,MASK)
static func _context(root:Variant,body:Variant,globals:Variant)->bool:
	return root is PackedByteArray and root.size()==ROOT_BYTES and body is PackedByteArray and body.size()==OBJECT_BYTES and _globals(globals) and _whole(body[0x86],1,114) and root.decode_u32(0xc8)==int(body[0x86]) and root.decode_u32(0xcc)<=114
static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"raw_owners_mutated":false,"F569_geometry_executed":false,"F939_body_executed":false,"external_effects_applied":false,"complete_original_flight_pipeline":false}
static func _result(root:PackedByteArray,body:PackedByteArray,globals:Dictionary,requests:Array,order:Array,returned:int=0,outputs:Dictionary={})->Dictionary:
	var state:Dictionary={}
	for key:String in GLOBAL_KEYS:state[key]=int(globals[key])
	return {"ok":true,"profile":PROFILE,"root_after":root,"body_after":body,"globals_after":state,"requests":requests,"source_order":order,"return_s32":returned,"outputs":outputs,"raw_owners_mutated":false,"F569_geometry_executed":false,"F939_body_executed":false,"external_effects_applied":false,"complete_original_flight_pipeline":false}
static func effects_f1046(body:Variant,root:Variant,globals:Variant,boundary:Variant={})->Dictionary:
	if not _context(root,body,globals) or not boundary is Dictionary:return _reject("invalid_effects_context")
	var needs_trail:bool=int(body[0x14e])!=0
	if needs_trail:
		if not _keys(boundary,["trail_policy"]) or boundary.trail_policy!="observe_only":return _reject("missing_explicit_F939_observer")
	elif not boundary.is_empty():return _reject("unexpected_F939_observer")
	var candidate:PackedByteArray=body.duplicate();var game:PackedByteArray=root.duplicate();var requests:Array=[];var order:Array=["F1046"]
	if needs_trail:
		requests.append({"kind":"F939","body_hex_at_call":candidate.hex_encode(),"position_hex_at_call":candidate.slice(0x3e,0x56).hex_encode(),"flags_u32":0});order.append("F939")
	# DATA8868 is LOW and8869 HIGH. These are rootE0/E4 aliases, not
	# independently initialized clocks. F1046 always enters F1045 here.
	var drift:=Gravity.integrate(candidate,PackedInt64Array([int(game.decode_u32(0xe0)),int(game.decode_u32(0xe4))]))
	if drift.is_empty():return _reject("source_drift_rejected")
	candidate=drift.body;order.append_array(["F1045","F1512","F1511"])
	if int(game[0x3f5e])!=0 and int(globals.effect_gate_s32)<0:
		var maximum:=maxi(absi(candidate.decode_s16(0xb6)),maxi(absi(candidate.decode_s16(0xb8)),absi(candidate.decode_s16(0xba))))
		var level:=maximum-0x221
		if level>=0:
			requests.append({"kind":"F1910","args":[3,level,0x1ae-level],"body_hex_at_call":candidate.hex_encode()});order.append("F1910")
			game.encode_u16(0xc6,int(game.decode_u16(0xc6))|0x80)
	return _result(game,candidate,globals,requests,order)
static func _contact(body:PackedByteArray,value:Variant)->bool:
	if not _keys(value,CONTACT_KEYS) or value.caller_profile!=CONTACT_PROFILE or not _hex(value.body_before_hex,OBJECT_BYTES) or value.body_before_hex!=body.hex_encode() or not _hex(value.body_after_hex,OBJECT_BYTES) or not _hex(value.collider_body_hex,OBJECT_BYTES):return false
	if not _whole(value.flags_u8,0,255) or not _whole(value.altitude_raw_s32,-0x80000000,0x7fffffff) or not _whole(value.collider_ref_u32,0,114) or not _whole(value.collider_index_u8,0,255) or not _whole(value.material_u8,0,255):return false
	var response:PackedByteArray=str(value.body_after_hex).hex_decode()
	for offset:int in [0x56,0x57,0x86]:
		if response[offset]!=body[offset]:return false
	if (int(value.flags_u8)&1)!=0:
		var collider:PackedByteArray=str(value.collider_body_hex).hex_decode()
		if int(value.collider_ref_u32)==0 or int(collider[0x86])!=int(value.collider_ref_u32):return false
	return true
static func contact_f1033(body:Variant,root:Variant,globals:Variant,boundary:Variant)->Dictionary:
	if not _context(root,body,globals) or not _contact(body,boundary):return _reject("invalid_or_unmatched_F569_observation")
	var candidate:PackedByteArray=str(boundary.body_after_hex).hex_decode();var collider:PackedByteArray=str(boundary.collider_body_hex).hex_decode()
	var contact:={"flags_u8":int(boundary.flags_u8),"altitude_raw_s32":int(boundary.altitude_raw_s32),"parent_model_u32":int(collider.decode_u32(0x82))}
	var scoop:=Scoop.evaluate_buffers(root.slice(0,Scoop.GAME_BYTES),candidate,contact,int(globals.step_u32),int(globals.sound_mode_s8))
	if not scoop.get("ok",false):return _reject("proven_F1033_kernel_rejected")
	var game:PackedByteArray=root.duplicate()
	for offset in range(Scoop.GAME_BYTES):game[offset]=scoop.game[offset]
	var requests:Array=[{"kind":"F569","body_hex_at_call":body.hex_encode(),"response":boundary.duplicate(true)}]
	var order:Array=["F1033","F569"]
	var events:Dictionary=scoop.events
	if int(events.refresh)!=0:requests.append({"kind":"F1116"});order.append("F1116")
	if (int(boundary.flags_u8)&1)==0:order.append("F1034")
	if int(events.notify)!=0:
		# Uploaded DOS initializes only these two message words here. JJFFE
		# added a third stack initialization; that instruction is excluded.
		requests.append({"kind":"F349","message_code_u32":int(events.message_code),"message_amount_u32":int(events.message_amount)})
		requests.append({"kind":"F148","args":[int(events.notify_first),int(events.notify_second)]})
		requests.append({"kind":"F1906","args":[0x11]});order.append_array(["F349","F148","F1906"])
	if int(events.destroy)!=0:requests.append({"kind":"F953","args":[-1,0],"body_hex_at_call":candidate.hex_encode()});order.append("F953")
	var outputs:={"flags_u8":int(boundary.flags_u8),"altitude_s32":int(boundary.altitude_raw_s32),"collider_ref_u32":int(boundary.collider_ref_u32),"collider_index_u8":int(boundary.collider_index_u8),"material_u8":int(boundary.material_u8)}
	return _result(game,scoop.object,globals,requests,order,int(scoop.return_s32),outputs)
static func decay_f1034(body:Variant,root:Variant,globals:Variant,boundary:Variant={})->Dictionary:
	if not _context(root,body,globals) or not boundary is Dictionary or not boundary.is_empty():return _reject("invalid_decay_context")
	# Reuse the independently DOS-checked F1034 arithmetic already shared
	# by the scoop module. Its unrelated F1033 HUD writes are not committed.
	var decay:=Scoop.evaluate_buffers(root.slice(0,Scoop.GAME_BYTES),body,{"flags_u8":0,"altitude_raw_s32":0,"parent_model_u32":0},int(globals.step_u32),int(globals.sound_mode_s8))
	if not decay.get("ok",false):return _reject("proven_F1034_kernel_rejected")
	var game:PackedByteArray=root.duplicate()
	for offset:int in [0x14c,0x146,0x14a,0x13c]:game.encode_u16(offset,int(decay.game.decode_u16(offset)))
	return _result(game,body.duplicate(),globals,[],["F1034"])
static func execute(operation:Variant,body:Variant,root:Variant,globals:Variant,boundary:Variant={})->Dictionary:
	if not operation is String or operation not in OPERATIONS:return _reject("unknown_motion_contact_operation")
	match operation:
		"effects_f1046":return effects_f1046(body,root,globals,boundary)
		"contact_f1033":return contact_f1033(body,root,globals,boundary)
		"decay_f1034":return decay_f1034(body,root,globals,boundary)
	return _reject("unknown_motion_contact_operation")
