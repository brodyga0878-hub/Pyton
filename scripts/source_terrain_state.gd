extends RefCounted
# D8812 is Root+10. Only D9283/D9284 are separately owned cold query words.
# A flat F581 exit does not read graphics or reset these two words.
const Context=preload("res://scripts/source_player_context.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const PROFILE:="dos-firstenc-terrain-root-state-v1"
const GRAPHICS_OFFSET:=0x10
const AUX_KEYS:=["recorded_intersection_raw_s32","pending_query_flag_u32"]
const STATE_KEYS:=["graphics_level_u32","recorded_intersection_raw_s32","pending_query_flag_u32"]
static func _keys(value:Variant,keys:Array)->bool:
	if not value is Dictionary or value.size()!=keys.size():return false
	for key:String in keys:
		if not value.has(key):return false
	return true
static func valid_aux(value:Variant)->bool:
	return _keys(value,AUX_KEYS) and Frame._whole(value.recorded_intersection_raw_s32,-0x80000000,0x7fffffff) and Frame._whole(value.pending_query_flag_u32,0,0xffffffff)
static func valid(value:Variant)->bool:
	if not _keys(value,STATE_KEYS) or not Frame._whole(value.graphics_level_u32,0,0xffffffff):return false
	return valid_aux({"recorded_intersection_raw_s32":value.recorded_intersection_raw_s32,"pending_query_flag_u32":value.pending_query_flag_u32})
static func auxiliary(value:Variant)->Dictionary:
	if not valid(value):return {}
	return {"recorded_intersection_raw_s32":int(value.recorded_intersection_raw_s32),"pending_query_flag_u32":int(value.pending_query_flag_u32)}
static func from_root(root:Variant,aux:Variant)->Dictionary:
	if not Context._root(root) or not valid_aux(aux):return {}
	return {"graphics_level_u32":int(root.decode_u32(GRAPHICS_OFFSET)),"recorded_intersection_raw_s32":int(aux.recorded_intersection_raw_s32),"pending_query_flag_u32":int(aux.pending_query_flag_u32)}
static func matches_root(root:Variant,state:Variant)->bool:
	return Context._root(root) and valid(state) and int(root.decode_u32(GRAPHICS_OFFSET))==int(state.graphics_level_u32)
