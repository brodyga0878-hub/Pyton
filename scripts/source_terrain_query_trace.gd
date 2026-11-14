extends "res://scripts/source_terrain_query.gd"
# Observes the selected F1876 leaf and its original integer plane fractions.
# Every arithmetic result comes from an unchanged superclass call. Captured
# geometry is not by itself a certificate for a floating render triangle.
const CONTRACT:="source-f1876-readonly-winning-triangle-trace-v1"
const MAX_TRACE_QUERIES:=64
var _trace_rows:Array=[]
var _trace_query_count:=0
var _trace_truncated:=false
var _trace_current:Dictionary={}
var _trace_fractions:Array=[]
var _trace_intersection_active:=false
var _trace_leaf_depth:=0

func reset_trace()->void:
	# Like the base query kernel, an instance belongs to one caller/thread.
	# Use a separate kernel for a concurrent worker, never share live state.
	_trace_rows.clear();_trace_query_count=0;_trace_truncated=false
	_trace_current={};_trace_fractions=[];_trace_intersection_active=false;_trace_leaf_depth=0

func read_trace()->Array:
	return _trace_rows.duplicate(true)

func trace_state()->Dictionary:
	return {"source_contract":CONTRACT,"query_count":_trace_query_count,"recorded_query_count":_trace_rows.size(),"max_trace_queries":MAX_TRACE_QUERIES,"trace_truncated":_trace_truncated,"source_query_arithmetic_changed":false,"geometry_provider_or_collision_response":false}

func _plane_fraction(numerator:int,denominator:int)->int:
	# Observing the actual superclass call also preserves its denominator-zero
	# behavior and invalid_query flag. No alternate fraction formula runs here.
	var result:=super._plane_fraction(numerator,denominator)
	if _trace_intersection_active:
		_trace_fractions.append({"numerator_s32":numerator,"denominator_s32":denominator,"fraction_s32":result})
	return result

func _prepare_triangle(vertices:Array,node:Variant)->void:
	super._prepare_triangle(vertices,node)
	_trace_leaf_depth=0

func _schedule_features(vertices:Array,node:Variant,depth:int)->void:
	super._schedule_features(vertices,node,depth)
	# The immutable caller increments its subdivision level once after every
	# schedule/edge/selection iteration. Observe that level without copying it.
	_trace_leaf_depth=depth+1

func _intersection(vertices:Array)->int:
	if _trace_current.is_empty():return super._intersection(vertices)
	var positions:Array=[];var normals:Array=[]
	var ids:=PackedInt64Array();var depths:=PackedInt64Array();var heights:=PackedInt64Array();var lands:=PackedInt64Array()
	var bits:=0
	for vertex:Dictionary in vertices:
		positions.append(vertex.p.duplicate());normals.append(vertex.n.duplicate())
		ids.append(int(vertex.id));depths.append(int(vertex.depth));heights.append(int(vertex.height));lands.append(int(vertex.land))
		for value:int in vertex.p:bits|=_abs32(value)
	var shift:=maxi(0,_msb(bits)-13);var shifted:Array=[]
	for point:PackedInt64Array in positions:
		var value:=PackedInt64Array()
		for coordinate:int in point:value.append(coordinate>>shift)
		shifted.append(value)
	_trace_fractions=[];_trace_intersection_active=true
	var result:=super._intersection(vertices)
	_trace_intersection_active=false
	var leaf:={"positions_raw":positions,"normals_raw":normals,"vertex_ids_s32":ids,"vertex_ids_are_native_pointers":false,"depths_s32":depths,"heights_s32":heights,"lands_s32":lands,"leaf_depth_s32":_trace_leaf_depth,"sar_shift_s32":shift,"sar_positions_raw":shifted,"plane_fraction_calls":_trace_fractions.duplicate(true),"recorded_intersection_raw":result}
	if not _trace_current.is_empty():
		_trace_current.intersections.append(leaf)
		_trace_current["winning_triangle"]=leaf.duplicate(true)
	return result

func query_raw(seed:int,style:int,matrix_raw:PackedInt64Array,center_raw:PackedInt64Array,query_limit_raw:int,graphics_level_raw:=1,features:=PackedByteArray())->Dictionary:
	var retain:=_trace_rows.size()<MAX_TRACE_QUERIES
	if retain:
		_trace_current={"query_index":_trace_query_count,"source_uid_u32":seed&0xffffffff,"style_s32":style,"graphics_level_s32":graphics_level_raw,"query_limit_s32":_s32(query_limit_raw),"query_matrix_raw":matrix_raw.duplicate(),"query_center_raw":center_raw.duplicate(),"features_hex":features.hex_encode(),"query_ok":false,"result":{},"winning_triangle":{},"intersections":[]}
	else:_trace_current={};_trace_truncated=true
	_trace_query_count+=1
	var result:=super.query_raw(seed,style,matrix_raw,center_raw,query_limit_raw,graphics_level_raw,features)
	if retain:
		_trace_current.query_ok=not result.is_empty();_trace_current.result=result.duplicate(true)
		_trace_rows.append(_trace_current.duplicate(true))
	_trace_current={};_trace_fractions=[];_trace_intersection_active=false;_trace_leaf_depth=0
	return result
