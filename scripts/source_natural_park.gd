extends RefCounted
# Only original F1021 JUMP4228's accepted natural branch, its F1042 reset and
# state32's F1030 RET. Caller supplies explicit source pointer WORD bindings;
# this module does not allocate an object bank or execute sound/UI/launch.
const Natural=preload("res://scripts/source_natural_contact.gd")
const CONTRACT:="dos-firstenc-f1021-natural-accepted-f1042-f1030-park-v1"
const ROOT_BYTES:=256
const CONTEXT_KEYS:=["collision_flags_u8","body_pointer_u32","parent_pointer_u32","parent_index_u8","source_flags_8860_u8","control_8918_s32","reference_policy"]
static func _reject(body:PackedByteArray,root:PackedByteArray,reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"body_after":body.duplicate(),"game_root_after":root.duplicate(),"callbacks":[],"source_contract":CONTRACT,"source_sha256":Natural.SOURCE_SHA,"source_launch_executed":false}
static func _valid(body:PackedByteArray,parent:PackedByteArray,root:PackedByteArray,context:Dictionary)->bool:
	if body.size()!=338 or parent.size()!=338 or root.size()!=ROOT_BYTES or context.size()!=CONTEXT_KEYS.size():return false
	for key:String in CONTEXT_KEYS:
		if not context.has(key):return false
	for key:String in ["collision_flags_u8","source_flags_8860_u8"]:
		if not Natural._whole(context[key],0,255):return false
	# DATA8860 is the actual DATA8804 game-root byte C6, not a second flag.
	if int(context.source_flags_8860_u8)!=int(root[0xc6]):return false
	for key:String in ["body_pointer_u32","parent_pointer_u32"]:
		if not Natural._whole(context[key],1,0xffffffff):return false
	if context.body_pointer_u32==context.parent_pointer_u32 or not Natural._whole(context.control_8918_s32,-2147483648,2147483647) or not Natural._whole(context.parent_index_u8,1,255) or int(context.parent_index_u8)!=int(parent[0x86]):return false
	if context.reference_policy not in ["isolated-parent-reference-word-v1","native-captured-pointer-word-v1"]:return false
	if context.reference_policy=="isolated-parent-reference-word-v1" and (int(context.body_pointer_u32)!=int(body[0x86]) or int(context.parent_pointer_u32)!=int(parent[0x86])):return false
	return body[0x86]!=0 and parent[0x86]!=0 and body[0x86]!=parent[0x86]
static func accept(body:PackedByteArray,parent:PackedByteArray,root:PackedByteArray,context:Dictionary)->Dictionary:
	if not _valid(body,parent,root,context):return _reject(body,root,"invalid_explicit_source_park_operands")
	var flags:=int(context.collision_flags_u8)
	if root[0xe8]==0x2c or (flags&0x20)!=0 or (flags&0x40)==0:return _reject(body,root,"outside_original_accepted_natural_park_branch")
	var after:=body.duplicate();var game:=root.duplicate();var callbacks:Array=[]
	game.encode_u32(0xcc,int(context.parent_pointer_u32));game[0xc5]=parent[0x86]
	for offset:int in [0x8c,0x90,0x94]:after.encode_s32(offset,0)
	for offset:int in [0xb0,0xb2,0xb6,0xb8,0xba]:after.encode_u16(offset,0)
	if int(context.source_flags_8860_u8)&0x80:callbacks.append({"function":"F1910","arguments_u32":[3,1,300,int(context.body_pointer_u32)]})
	game[0xf8]=255;game[0xe8]=0x32
	callbacks.append({"function":"F48","arguments_u32":[1,0,13]});callbacks.append({"function":"F48","arguments_u32":[1,0,14]})
	return {"ok":true,"reason":"original_accepted_natural_park","body_after":after,"game_root_after":game,"control_8918_after_s32":0,"callbacks":callbacks,"source_contract":CONTRACT,"source_sha256":Natural.SOURCE_SHA,"source_state_u8":0x32,"fractional_velocity_words_preserved":true,"pointer_words_are_caller_supplied":true,"source_object_bank_present":false,"full_F1021":false,"source_launch_executed":false}
static func parked_tick(body:PackedByteArray,parent:PackedByteArray,root:PackedByteArray,context:Dictionary)->Dictionary:
	if not _valid(body,parent,root,context) or root[0xe8]!=0x32 or root.decode_u32(0xcc)!=int(context.parent_pointer_u32) or root[0xc5]!=parent[0x86]:return _reject(body,root,"outside_bound_source_state32")
	return {"ok":true,"reason":"original_F1030_ret","body_after":body.duplicate(),"game_root_after":root.duplicate(),"control_8918_after_s32":int(context.control_8918_s32),"callbacks":[],"source_contract":CONTRACT,"source_sha256":Natural.SOURCE_SHA,"source_state_u8":0x32,"source_object_bank_present":false,"full_F1021":false,"source_launch_executed":false}
