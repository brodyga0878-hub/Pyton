extends RefCounted
# Whole original DOS F581 in model-local raw coordinates. The caller supplies
# the F582 context and the exact graphics/terrain words; no SI pose is inferred.
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Point=preload("res://scripts/source_terrain_point.gd")
const Query=preload("res://scripts/source_terrain_query.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
const PROFILE:="dos-firstenc-whole-f581-terrain-v1"
const TERRAIN_KEYS:=["graphics_level_u32","recorded_intersection_raw_s32","pending_query_flag_u32"]
const CONTEXT_KEYS:=["point_xyz_s32","normals","vertices","mesh_zoom_s32","vector_scale_s32"]
const ORIGIN_KEYS:=["normal_origin_u32","vertex_origin_u32"]
const MASK:=0xffffffff

static func _s32(value:int)->int:return Ground.signed32(value)
static func _whole(value:Variant,low:int,high:int)->bool:return Frame._whole(value,low,high)
static func _keys(value:Variant,required:Array,optional:Array=[])->bool:
	if not value is Dictionary:return false
	for key:String in required:
		if not value.has(key):return false
	for key:Variant in value:
		if not (key is String or key is StringName) or str(key) not in required+optional:return false
	return true
static func _terrain_state(value:Variant)->bool:
	return _keys(value,TERRAIN_KEYS) and _whole(value.graphics_level_u32,0,MASK) and _whole(value.recorded_intersection_raw_s32,-0x80000000,0x7fffffff) and _whole(value.pending_query_flag_u32,0,MASK)
static func _copy_terrain(value:Dictionary)->Dictionary:
	return {"graphics_level_u32":int(value.graphics_level_u32),"recorded_intersection_raw_s32":int(value.recorded_intersection_raw_s32),"pending_query_flag_u32":int(value.pending_query_flag_u32)}
static func _context(value:Variant)->bool:
	if not _keys(value,CONTEXT_KEYS,ORIGIN_KEYS) or not (value.point_xyz_s32 is Array or value.point_xyz_s32 is PackedInt64Array) or value.point_xyz_s32.size()!=3 or not value.normals is PackedByteArray or not value.vertices is PackedByteArray:return false
	for cell:Variant in value.point_xyz_s32:
		if not _whole(cell,-0x80000000,0x7fffffff):return false
	for key:String in ["mesh_zoom_s32","vector_scale_s32"]:
		if not _whole(value[key],-0x80000000,0x7fffffff):return false
	for key:String in ORIGIN_KEYS:
		if value.has(key) and not _whole(value[key],0,value.normals.size() if key=="normal_origin_u32" else value.vertices.size()):return false
	return true
static func _reject(reason:String)->Dictionary:
	return {"ok":false,"reason":reason,"profile":PROFILE,"live_owners_changed":false,"Main_integrated":false,"F581_body_executed":false,"F1876_body_executed":false}
static func _shift64(value:int,count:int)->int:
	# F1341 tests NEG(count) as signed32. INT_MIN takes the two-word path
	# after its negation wraps; it cannot be handled by an unbounded shift.
	var low:int=value&MASK;var high:int=(value>>32)&MASK
	if count<0:
		var amount:=_s32(-count)
		if amount<32:
			low=((low>>(amount&31))|(high<<((_s32(32-amount))&31)))&MASK
			high=(_s32(high)>>(amount&31))&MASK
		else:
			low=(_s32(high)>>((_s32(amount-32))&31))&MASK;high=(_s32(high)>>31)&MASK
	elif count>0:
		if count<32:
			high=((high<<(count&31))|(low>>((_s32(32-count))&31)))&MASK;low=(low<<(count&31))&MASK
		else:high=(low<<((_s32(count-32))&31))&MASK;low=0
	return (_s32(high)<<32)|low
static func _features_end(program:PackedByteArray,at:int)->int:
	while at+2<=program.size():
		if program.decode_s16(at)==0:return at+2
		at+=16
	return -1
static func _vertex(vertices:PackedByteArray,origin:int,code:int,shift:int)->PackedInt64Array:
	var at:=origin+(code>>1)*6
	if at<0 or at+6>vertices.size():return PackedInt64Array()
	var x:=int(vertices[at+2]);x=x-256 if x>=128 else x
	if (code&1)!=0:x=-x
	var result:=PackedInt64Array([x,0,0])
	for axis in range(1,3):
		var value:=int(vertices[at+2+axis]);result[axis]=value-256 if value>=128 else value
	for axis in range(3):result[axis]=_s32(result[axis]<<(shift&31)) if shift>=0 else result[axis]>>((-shift)&31)
	return result
static func _prepare_frame(vertices:Array,observer:PackedInt64Array)->Dictionary:
	var origin:PackedInt64Array=vertices[0];var center:=Query._subtract(origin,observer)
	var distance:=Point.source_length(center)
	var matrix:=PackedInt64Array([0x7fffffff,0,0,0,0x7fffffff,0,0,0,0x7fffffff])
	if center[0]!=0:
		var length:=Point.source_length(PackedInt64Array([center[0],center[1],0]))
		var first:=Point._normalized_component(center[0],length);var second:=Point._normalized_component(center[1],length)
		matrix=PackedInt64Array([second,first,0,_s32(-first),second,0,0,0,0x7fffffff]);center[1]=length
	if center[1]!=0:
		var length:=Point.source_length(PackedInt64Array([0,center[1],center[2]]))
		var first:=Point._normalized_component(center[1],length);var second:=Point._normalized_component(center[2],length)
		for row in range(2):
			matrix[row*3+2]=Ground.multiply_q31(matrix[row*3+1],first);matrix[row*3+1]=Ground.multiply_q31(matrix[row*3+1],second)
		matrix[7]=_s32(-first);matrix[8]=second
	var transformed:=PackedInt64Array()
	for corner in range(1,4):transformed.append_array(Point._transform(Query._subtract(vertices[corner],origin),matrix))
	return {"distance_s32":distance,"query_matrix_s32":transformed,"query_center_s32":PackedInt64Array([0,0,distance])}
static func execute(body:Variant,program:Variant,offset_u32:Variant,context:Variant,threshold_s32:Variant,globals:Variant,terrain_state:Variant)->Dictionary:
	if not body is PackedByteArray or body.size()!=338 or not program is PackedByteArray or not _whole(offset_u32,0,program.size()) or not _context(context) or not _whole(threshold_s32,-0x80000000,0x7fffffff) or not Frame._globals(globals) or not _terrain_state(terrain_state):return _reject("invalid_terrain_context")
	var offset:=int(offset_u32)
	if offset+8>program.size():return _reject("truncated_terrain_payload")
	var next_offset:=_features_end(program,offset+6)
	if next_offset<0:return _reject("unterminated_terrain_feature_records")
	var vertices:Array=[];var shift:=_s32(int(context.mesh_zoom_s32)-int(context.vector_scale_s32))
	for corner in range(4):
		var vertex:=_vertex(context.vertices,int(context.get("vertex_origin_u32",0)),int(program[offset+corner]),shift)
		if vertex.size()!=3:return _reject("terrain_vertex_outside_buffer")
		vertices.append(vertex)
	var observer:=PackedInt64Array([int(context.point_xyz_s32[0]),int(context.point_xyz_s32[1]),int(context.point_xyz_s32[2])])
	var center:=Query._subtract(vertices[0],observer);var distance:=Point.source_length(center)
	var scale:=int(context.vector_scale_s32)
	var outer:=_s32(_shift64(body.decode_s64(0x138),_s32(-scale)))
	var inner:=_s32(_shift64(body.decode_s64(0x140),_s32(-scale)))
	var state:=Frame._copy_globals(globals);var terrain:=_copy_terrain(terrain_state)
	state.collision_kind_u8=255
	var branch:="";var hit:=-1;var query_count:=0;var query_result:Dictionary={};var query_args:Dictionary={}
	var order:Array=["F581"]
	if _s32(distance-outer)>=int(threshold_s32):
		branch="outside_outer";state.collision_kind_u8=0;order.append("F1822")
	elif _s32(distance-inner)<=int(threshold_s32):
		branch="inside_inner";state.collision_kind_u8=1;hit=0;order.append("F1822")
	else:
		var style:=int(program.decode_u16(offset+4))
		if style>=14:return _reject("unsupported_terrain_style")
		if int(terrain.graphics_level_u32)>15:return _reject("unsupported_terrain_query_graphics")
		var frame:=_prepare_frame(vertices,observer);var limit:=2000000000>>(scale&31)
		var features:PackedByteArray=program.slice(offset+6,next_offset)
		var kernel:=Query.new()
		query_result=kernel.query_raw(body.decode_u32(0xa0),style,frame.query_matrix_s32,frame.query_center_s32,limit,int(terrain.graphics_level_u32),features)
		if query_result.is_empty():return _reject("source_terrain_query_rejected")
		branch="terrain_query";query_count=1;order.append("F1876")
		query_args={"seed_u32":body.decode_u32(0xa0),"style_u32":style,"query_matrix_s32":Array(frame.query_matrix_s32),"query_center_s32":Array(frame.query_center_s32),"query_limit_s32":limit,"graphics_level_u32":int(terrain.graphics_level_u32),"features_hex":features.hex_encode()}
		var height:=int(query_result.query_result_raw)
		terrain.recorded_intersection_raw_s32=int(query_result.recorded_intersection_raw);terrain.pending_query_flag_u32=int(query_result.pending_query_flag)&MASK
		hit=0 if (int(threshold_s32)>>16)>height else -1
		if height<limit:
			var altitude:=_shift64(height,scale)
			state.altitude_low_u32=altitude&MASK;state.altitude_high_s32=_s32(altitude>>32)
		state.previous_altitude_low_u32=int(state.altitude_low_u32);state.previous_altitude_high_s32=int(state.altitude_high_s32)
		if hit==0:state.altitude_low_u32=0;state.altitude_high_s32=0;state.collision_kind_u8=1
	return {"ok":true,"profile":PROFILE,"hit_s32":hit,"next_offset_u32":next_offset,"body_after":body.duplicate(),"program_after":program.duplicate(),"context_after":context.duplicate(true),"globals_after":state,"terrain_state_after":terrain,"branch":branch,"distance_s32":distance,"outer_s32":outer,"inner_s32":inner,"query_count_u32":query_count,"query_args":query_args,"query_metrics":query_result.duplicate(true),"source_order":order,"source_order_scope":"F581-direct-terrain-or-skip-calls","live_owners_changed":false,"F581_body_executed":true,"F1876_body_executed":query_count!=0,"Main_integrated":false}
