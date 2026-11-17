extends RefCounted
# One raw GameRoot window owns aliased control words. The legacy F1041 API
# calls Root+DC spin_elapsed_s32; it is the original HUD/altitude control word,
# not a newly accumulated time. Only roll and external scratch are writable
# by that restricted arithmetic callback. Other owners use the full raw root.
const Player=preload("res://scripts/source_player_dispatch.gd")
const ROOT_BYTES:=0x4000
const PROFILE:="dos-firstenc-player-root-context-v1"
const EXTERNAL_KEYS:=["frame_ticks_u32","forward_key_u8","reverse_key_u8","spin_xyz_s32"]

static func _root(value:Variant)->bool:
	return value is PackedByteArray and value.size()==ROOT_BYTES
static func player_globals(root:Variant,external:Variant)->Dictionary:
	if not _root(root) or not external is Dictionary:return {}
	for key:String in EXTERNAL_KEYS:
		if not external.has(key):return {}
	var result:Dictionary={
		"frame_ticks_u32":external.frame_ticks_u32,
		"spin_elapsed_s32":root.decode_s32(0xdc),
		"player_mode_u8":int(root[0xe8]),"flight_flags_u8":int(root[0xe9]),
		"set_speed_s32":root.decode_s32(0x1b8),"damping_flags_u8":int(root[0x3fb6]),
		"reference_velocity_s32":[root.decode_s32(0x88),root.decode_s32(0x8c),root.decode_s32(0x90)],
		"forward_key_u8":external.forward_key_u8,"reverse_key_u8":external.reverse_key_u8,
		"spin_xyz_s32":external.spin_xyz_s32,
		"player_index_u32":root.decode_u32(0xc0),"player_roll_s16":root.decode_s16(0x210),
		"drift_ticks_low_u32":root.decode_u32(0xe0),"drift_ticks_high_u32":root.decode_u32(0xe4)}
	return Player._copy_globals(result) if Player._globals(result) else {}

static func apply_player_globals(root:Variant,external:Variant,after:Variant)->Dictionary:
	var before:=player_globals(root,external)
	if before.is_empty() or not Player._globals(after):return {"ok":false,"reason":"invalid_player_root_context"}
	for key:String in Player.GLOBAL_KEYS:
		if key in ["player_roll_s16","spin_xyz_s32"]:continue
		if before[key]!=after[key]:return {"ok":false,"reason":"readonly_player_alias_changed"}
	var candidate:PackedByteArray=root.duplicate();candidate.encode_s16(0x210,int(after.player_roll_s16))
	var state:Dictionary=external.duplicate(true);state.spin_xyz_s32=Array(after.spin_xyz_s32).duplicate()
	return {"ok":true,"profile":PROFILE,"root_after":candidate,"external_after":state}
