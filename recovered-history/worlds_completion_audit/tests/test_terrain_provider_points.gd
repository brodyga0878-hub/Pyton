extends SceneTree
# Native controls for every extracted model and the explicit fixed-probe policy.
# This verifies source model-local integer math; it is not an Android benchmark.
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

func compare_case(model:RefCounted,row:Dictionary,index:int)->void:
	var observer:=Query._vector(row.observer_model_local_raw)
	var before:=observer.duplicate()
	var result:Dictionary=model.query_point_raw(int(row.model_index),int(row.seed),observer,int(row.vector_scale),int(row.get("graphics_level_raw",1)))
	check(not result.is_empty(),"Original terrain point completes case %d"%index)
	if result.is_empty():return
	check(observer==before,"Source observer remains read-only case %d"%index)
	check(result.query_matrix_raw==Query._vector(row.result.query_matrix_raw),"Native model frame case %d"%index)
	check(result.query_center_raw==Query._vector(row.result.query_center_raw),"Native source distance case %d"%index)
	for key in ["query_style_raw","query_limit_raw","collision_status","recorded_intersection_raw","pending_query_flag","terrain_query_calls"]:
		check(result[key]==int(row.result[key]),"Original point %s case %d: expected %s, got %s"%[key,index,str(row.result[key]),str(result[key])])
	var written:bool=row.result.get("altitude_written",true)
	check(result.altitude_written==written,"Original caller altitude write contract case %d"%index)
	if written:
		check(result.altitude_raw_i64==int(row.result.altitude_raw_i64),"Original source int64 altitude case %d"%index)
	else:
		check(result.altitude_raw_i64==null,"Unwritten source altitude is explicit case %d"%index)
	if row.has("base_radius_raw"):
		var surface_radius:int=int(result.query_center_raw[2])-int(result.recorded_intersection_raw)
		check(surface_radius==int(row.result.source_surface_radius_raw),"Original unitless source shape case %d"%index)
		if row.control_kind=="fixed_provider_policy":
			check(result.pending_query_flag==0 and result.recorded_intersection_raw>0 and result.recorded_intersection_raw<result.query_limit_raw,"Fixed probe outside terrain, complete and unclamped case %d"%index)

func run()->void:
	var additional:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/terrain_additional_query_reference.json"))
	var provider:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/terrain_provider_reference.json"))
	check(additional.cases.size()==390,"Additional thirteen-model source corpus is complete")
	check(provider.cases.size()==1040,"Fixed-policy and observer/detail source corpus is complete")
	var model:=Point.new()
	var models:Dictionary={}
	var original:=JSON.stringify([additional.cases,provider.cases])
	var started:=Time.get_ticks_usec()
	var index:=0
	for reference in [additional,provider]:
		for row in reference.cases:
			models[int(row.model_index)]=true
			compare_case(model,row,index)
			index+=1
	var elapsed:=Time.get_ticks_usec()-started
	check(models.size()==17,"All original terrain source models 117..133 are exercised")
	check(JSON.stringify([additional.cases,provider.cases])==original,"Queries leave control resources unchanged")
	for offset in [0,389,27,1023,959,1039]:
		var reference:Dictionary=additional if offset==389 else provider
		compare_case(model,reference.cases[offset],index)
		index+=1
	compare_case(Point.new(),provider.cases[959],index)
	print("TERRAIN PROVIDER POINT TESTS: %d checks, %d failures; 1430 native source cases, all 17 models; host query loop %.3f s (%.1f us/case), not phone performance"%[checks,failures,float(elapsed)/1000000.0,float(elapsed)/1430.0])
	quit(1 if failures else 0)
