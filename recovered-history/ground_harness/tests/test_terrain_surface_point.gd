extends SceneTree
const Point=preload("res://scripts/terrain_surface_point.gd")
const Query=preload("res://scripts/terrain_query.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=10:push_error(message)
func _init()->void:call_deferred("run")
func run()->void:
	var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/terrain_game_query_reference.json"))
	check(reference.schema==1 and reference.cases.size()==120,"All independent original F581 caller cases are present")
	var model:=Point.new()
	var source_before:=JSON.stringify(reference.cases)
	for index in range(reference.cases.size()):
		var row:Dictionary=reference.cases[index]
		var point:PackedInt64Array=Query._vector(row.observer_model_local_raw)
		var before:=point.duplicate()
		var result:Dictionary=model.query_point_raw(int(row.model_index),int(row.seed),point,int(row.vector_scale))
		check(not result.is_empty(),"Model-local point query executes case %d"%index)
		if result.is_empty():continue
		check(point==before,"Model-local observer is read-only case %d"%index)
		check(result.query_matrix_raw==Query._vector(row.result.query_matrix_raw),"Original F581 derives the same matrix case %d"%index)
		check(result.query_center_raw==Query._vector(row.result.query_center_raw),"Original F581 derives the same center case %d"%index)
		for key in ["query_style_raw","query_limit_raw","collision_status","recorded_intersection_raw","pending_query_flag","terrain_query_calls","altitude_raw_i64"]:
			check(result[key]==int(row.result[key]),"Native F581 %s case %d: expected %s, got %s"%[key,index,str(row.result[key]),str(result[key])])
		check(result.altitude_written and result.contact_altitude_raw_i64==result.altitude_raw_i64,"All native controls produce written non-collision altitude case %d"%index)
	check(JSON.stringify(reference.cases)==source_before,"Point queries do not alter supplied control data")
	for index in [119,0,67,35]:
		var row:Dictionary=reference.cases[index]
		var result:Dictionary=model.query_point_raw(int(row.model_index),int(row.seed),Query._vector(row.observer_model_local_raw),int(row.vector_scale))
		check(result.get("altitude_raw_i64")==int(row.result.altitude_raw_i64),"Interleaved source model/UID queries preserve native altitude")
	check(model.query_point_raw(-1,0,PackedInt64Array([0,0,1]),10).is_empty(),"Unsupported source model fails explicitly")
	check(model.query_point_raw(129,0,PackedInt64Array([1,2]),12).is_empty(),"Incomplete raw observer fails explicitly")
	var first:Dictionary=reference.cases[0]
	var width_case:Dictionary=model.query_point_raw(int(first.model_index),int(first.seed),Query._vector(first.observer_model_local_raw),int(first.vector_scale),1,0xffffffff)
	check(width_case.get("collision_status")==-1,"Threshold uses the original signed 32-bit input width")
	check(model.frame_raw(129,PackedInt64Array([0,0,0]),12).is_empty(),"Center point outside the original terrain branch is rejected")
	print("TERRAIN SURFACE POINT TESTS: %d checks, %d failures; 120 original F581 matrix/center/altitude cases"%[checks,failures])
	quit(1 if failures else 0)
