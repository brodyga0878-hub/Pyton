extends SceneTree
const Query=preload("res://scripts/terrain_query.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=10:push_error(message)
func _init()->void:call_deferred("run")
func run_case(kernel:RefCounted,case:Dictionary,features:PackedByteArray,expected:Dictionary,label:String)->Dictionary:
	var result:Dictionary=kernel.query_raw(int(case.seed),int(case.style),Query._vector(case.matrix_raw),Query._vector(case.center_raw),int(case.query_limit_raw),int(case.graphics_level_raw),features)
	check(not result.is_empty(),"Raw query executes "+label)
	if result.is_empty():return result
	for key in expected:
		check(result.get(key)==int(expected[key]),"Native %s %s: expected %s, got %s"%[label,key,str(expected[key]),str(result.get(key))])
	return result
func run()->void:
	var empty:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/terrain_query_reference.json"))
	var models:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/terrain_model_query_reference.json"))
	var caller:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/terrain_game_query_reference.json"))
	check(empty.schema==1 and empty.cases.size()==336,"All independent empty-feature controls are present")
	check(models.schema==1 and models.cases.size()==608,"All independent actual-model controls are present")
	var kernel:=Query.new()
	var input_before:=JSON.stringify(empty.cases)
	for index in range(empty.cases.size()):
		var row:Dictionary=empty.cases[index]
		run_case(kernel,row,PackedByteArray(),row.result,"empty case %d"%index)
	check(JSON.stringify(empty.cases)==input_before,"Raw queries leave the supplied input case data unchanged")
	var changed:=0
	for index in range(models.cases.size()):
		var row:Dictionary=models.cases[index]
		var features:PackedByteArray=str(models.models[str(int(row.model_index))].feature_stream_hex).hex_decode()
		var before:=features.duplicate()
		var populated:=run_case(kernel,row,features,row.result,"model case %d"%index)
		check(features==before,"Model feature bytes are read-only case %d"%index)
		var blank:=run_case(kernel,row,PackedByteArray(),row.empty_feature_control,"paired empty case %d"%index)
		if not populated.is_empty() and not blank.is_empty() and populated.query_result_raw!=blank.query_result_raw:changed+=1
	check(changed==87,"Original real feature streams change 87 control heights")
	check(caller.cases.size()==120,"Independent original F581 game-caller queries are present")
	for index in range(caller.cases.size()):
		var row:Dictionary=caller.cases[index]
		var call:Dictionary=row.result
		var input:Dictionary={"seed":int(row.seed),"style":int(call.query_style_raw),"matrix_raw":call.query_matrix_raw,"center_raw":call.query_center_raw,"query_limit_raw":int(call.query_limit_raw),"graphics_level_raw":1}
		var features:PackedByteArray=str(caller.models[str(int(row.model_index))].collision_payload_hex).hex_decode().slice(6)
		var expected:Dictionary={"query_result_raw":int(call.altitude_raw_i64)>>int(row.vector_scale),"recorded_intersection_raw":int(call.recorded_intersection_raw),"pending_query_flag":int(call.pending_query_flag)}
		run_case(kernel,input,features,expected,"original F581 caller %d"%index)
	# Repeat earlier queries after other models to catch leaked patch schedules,
	# shared edges and seed state without comparing a function against itself.
	for index in [0,1,27,303,607]:
		var row:Dictionary=models.cases[index]
		var features:PackedByteArray=str(models.models[str(int(row.model_index))].feature_stream_hex).hex_decode()
		run_case(kernel,row,features,row.result,"interleaved repeat %d"%index)
	check(kernel.query_raw(0,14,PackedInt64Array([1,0,0,0,1,0,0,0,1]),PackedInt64Array([0,0,2]),4).is_empty(),"Unsupported raw style is rejected")
	check(kernel.query_raw(0,0,PackedInt64Array([1,2]),PackedInt64Array([0,0,2]),4).is_empty(),"Incomplete matrix is rejected")
	print("TERRAIN QUERY TESTS: %d checks, %d failures; 336 empty, 608 model, 608 paired and 120 F581 native queries, %d feature effects"%[checks,failures,changed])
	quit(1 if failures else 0)
