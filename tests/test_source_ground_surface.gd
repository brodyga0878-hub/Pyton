extends SceneTree
const Query=preload("res://scripts/source_terrain_query.gd")
const Point=preload("res://scripts/source_terrain_point.gd")
const Surface=preload("res://scripts/source_ground_surface.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=12:push_error(message)
func _init()->void:call_deferred("run")
func run()->void:
	ground_surface_controls()
	standalone_height_controls()
	invalid_controls()
	var kernel:=Query.new()
	var point_query:=Point.new()
	var empty:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/terrain_query_reference.json"))
	check(empty.cases.size()==336,"Independent native raw fixture has 336 cases")
	for index in range(empty.cases.size()):
		var row:Dictionary=empty.cases[index]
		var actual:Dictionary=kernel.query_raw(int(row.seed),int(row.style),Query._vector(row.matrix_raw),Query._vector(row.center_raw),int(row.query_limit_raw),int(row.graphics_level_raw),PackedByteArray())
		check(not actual.is_empty(),"Raw query executes %d"%index)
		for key in row.result:
			check(actual.get(key)==int(row.result[key]),"Raw native case %d field %s: expected %s got %s"%[index,key,str(row.result[key]),str(actual.get(key))])
	for fixture_name in ["terrain_game_query_reference.json","rebuild_terrain_all_models_reference.json"]:
		var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+fixture_name))
		check(fixture.cases.size()==(510 if fixture_name.begins_with("rebuild_") else 120),"Independent native F581 fixture count")
		for index in range(fixture.cases.size()):
			var row:Dictionary=fixture.cases[index]
			var expected:Dictionary=row.result
			var observer:=Query._vector(row.observer_model_local_raw)
			var before:=observer.duplicate()
			var actual:Dictionary=point_query.query_point_raw(int(row.model_index),int(row.seed),observer,int(row.vector_scale))
			check(not actual.is_empty(),"F581 point executes model %d case %d"%[row.model_index,index])
			check(observer==before,"Observer input remains unchanged")
			check(actual.get("query_matrix_raw")==Query._vector(expected.query_matrix_raw),"Native matrix model %d case %d"%[row.model_index,index])
			check(actual.get("query_center_raw")==Query._vector(expected.query_center_raw),"Native center model %d case %d"%[row.model_index,index])
			for key in ["query_style_raw","query_limit_raw","collision_status","recorded_intersection_raw","pending_query_flag","terrain_query_calls","altitude_raw_i64"]:
				check(actual.get(key)==int(expected[key]),"F581 native model %d case %d field %s: expected %s got %s"%[row.model_index,index,key,str(expected[key]),str(actual.get(key))])
	print("SOURCE GROUND SURFACE TESTS: %d checks, %d failures; native F879/F574 placement and336raw/630F581 caller controls"%[checks,failures])
	quit(1 if failures else 0)

func int64_vector(values:Variant)->PackedInt64Array:
	var result:=PackedInt64Array()
	for value in values:result.append(int(value))
	return result

func ground_surface_controls()->void:
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_ground_surface_native.json"))
	check(fixture is Dictionary,"Independent full ground surface fixture exists")
	if not fixture is Dictionary:return
	check(fixture.source_variant==Surface.SOURCE_VARIANT,"Explicit pinned ground-position algorithm variant")
	check(fixture.source_sha256=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72","Native source fixture pins uploaded executable")
	check(fixture.get("source_assembly_sha256")=="d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a" and fixture.get("source_commit")=="7e540341d4e09aa3c92877b87d49e7f2c143ad8d","Native fixture pins reviewed source revision")
	check(int(fixture.case_count)==fixture.cases.size() and int(fixture.query_case_count)==fixture.query_cases.size(),"Native placement/query banks complete")
	check(fixture.get("fresh_process_runs",0)>=3 and int(fixture.reverse_repeat_count)==fixture.cases.size() and int(fixture.query_reverse_repeat_count)==fixture.query_cases.size(),"Fresh native processes and reverse orders agree")
	for key in ["observation_matches_untouched_objects","parent_bank_unchanged","object_canaries_unchanged"]:check(fixture.get(key)==true,"Original source memory/instrumentation proof "+key)
	check(FileAccess.get_sha256("res://"+str(fixture.ground_resource.path))==str(fixture.ground_resource.sha256),"Runtime ground resources match independent original extraction")
	for path in fixture.input_fixtures_sha256:check(FileAccess.get_sha256("res://"+str(path))==str(fixture.input_fixtures_sha256[path]),"Native source input dependency pinned "+str(path))
	var comparison:Dictionary=fixture.dos_f879_instruction_comparison
	check(int(comparison.normalized_instruction_count)==227 and comparison.all_other_instructions_equal and comparison.differences.size()==1,"Full DOS/JJFFE F879 instruction comparison has one explicit change")
	check(comparison.differences[0].pinned_jjffe=="sar eax,0x3" and comparison.differences[0].uploaded_dos=="sar eax,0x4","Ground height margin variant is explicit")
	var resources:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/ffe_ground_collision.json"))
	check(resources.parent_models.size()==17 and resources.port_models.size()==11 and resources.handcrafted_parent_models.size()==6,"Original descriptors cover all natural models and reviewed city domain")
	var surface:=Surface.new()
	for row:Dictionary in fixture.cases:
		var name:=str(row.source_context)+"/"+str(row.local_index)+"/"+str(row.angle_case)
		var raw_port:=str(row.port_object_input_hex).hex_decode();var raw_parent:=str(row.parent_object_input_hex).hex_decode()
		var port_init:=Surface.initialize_model(raw_port,int(row.port_model));var parent_init:=Surface.initialize_model(raw_parent,int(row.parent_model))
		check(not port_init.is_empty() and not parent_init.is_empty(),"Source model initialization "+name)
		if port_init.is_empty() or parent_init.is_empty():continue
		check(port_init.object==str(row.expected.initialized_port_hex).hex_decode(),"Exact full F1533 initialized port "+name)
		check(parent_init.object==str(row.expected.initialized_parent_hex).hex_decode(),"Exact full F1533 initialized parent "+name)
		var result:=surface.place_point_raw(port_init.object,parent_init.object,int(row.phase_u16),int(row.inclination_u16),int(row.get("graphics_level",1)),row.get("initial_globals",{}))
		check(not result.is_empty(),"Two source height queries execute "+name)
		if result.is_empty():continue
		check(result.position_raw==int64_vector(row.expected.position_raw),"Exact source F879 final signed64 coordinates "+name)
		var basis:=Surface.matrix_q31(int(row.phase_u16),int(row.inclination_u16));var direction:=PackedInt64Array([basis[3],basis[4],basis[5]])
		var sampled:=surface.sample_record_radial(str(row.parent_record_hex).hex_decode(),direction,int(row.get("graphics_level",1)))
		check(not sampled.is_empty() and sampled.position_raw==int64_vector(row.expected.position_raw),"Explicit radial probe agrees at native F1674 control direction "+name)
		var full:=surface.place_raw(port_init.object,parent_init.object,int(row.phase_u16),int(row.inclination_u16),int(row.get("graphics_level",1)),row.get("initial_globals",{}))
		check(not full.is_empty(),"Full source ground-port mutation executes "+name)
		if not full.is_empty():
			check(full.port==str(row.expected.port_hex).hex_decode(),"Exact complete F879 final338byte port "+name)
			check(full.parent==str(row.expected.parent_hex).hex_decode(),"Full F879 leaves actual parent unchanged "+name)
			check(full.height_calls==int(row.expected.height_calls) and full.terrain_query_calls==int(row.expected.terrain_query_calls),"Two actual source height/terrain calls "+name)
		if int(row.angle_case)==0 and str(row.origin).begins_with("original handcrafted"):
			var records:=surface.place_records(str(row.port_record_hex).hex_decode(),str(row.parent_record_hex).hex_decode(),int(row.local_index),int(row.get("graphics_level",1)))
			check(not records.is_empty() and records.port==str(row.expected.port_hex).hex_decode(),"Source-record geometry bootstrap matches actual F1533/F879 "+name)
		for index in range(2):
			var actual:Dictionary=result.passes[index];var expected:Dictionary=row.expected.passes[index]
			check(actual.trace.point_raw==int64_vector(expected.point_raw),"Source incoming F574 point "+name+"/"+str(index))
			check(int(actual.height_s32)==int(expected.height_s32),"Source F574 height "+name+"/"+str(index))
			for key in ["altitude_low_u32","altitude_high_s32","previous_altitude_low_u32","previous_altitude_high_s32","collision_kind_u8","collision_flags_u8","volume_flags_u8","collider_index_u8","collision_active_u8","collision_enabled_u8","primitive_flags_u8"]:check(int(actual.globals[key])==int(expected[key]),"Source F574 global "+key+"/"+name+"/"+str(index))

func standalone_height_controls()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_ground_surface_native.json"))
	var surface:=Surface.new()
	check(fixture.get("query_cases",[]).size()>0,"Independent standalone complete F574 queries exist")
	for index in range(fixture.get("query_cases",[]).size()):
		var row:Dictionary=fixture.query_cases[index];var expected:Dictionary=row.expected
		var port_init:=Surface.initialize_model(str(row.port_object_input_hex).hex_decode(),int(row.port_model))
		var parent_init:=Surface.initialize_model(str(row.parent_object_input_hex).hex_decode(),int(row.parent_model))
		check(not port_init.is_empty() and not parent_init.is_empty(),"F574 source descriptor setup "+str(index))
		if port_init.is_empty() or parent_init.is_empty():continue
		check(port_init.object==str(expected.initialized_port_hex).hex_decode() and parent_init.object==str(expected.initialized_parent_hex).hex_decode(),"F574 exact initialized objects "+str(index))
		var point:=int64_vector(row.point_input_raw);var before:=point.duplicate()
		var result:=surface.height_raw(port_init.object,parent_init.object,point,int(row.graphics_level),row.initial_globals)
		check(not result.is_empty(),"Standalone native F574 executes "+str(index))
		if result.is_empty():continue
		check(result.probe==str(expected.port_hex).hex_decode() and result.parent==str(expected.parent_hex).hex_decode(),"F574 exact complete objects "+str(index))
		check(result.point_after_raw==int64_vector(expected.point_after_raw),"F574 exact in-place point VecAbs output "+str(index))
		check(point==before,"Pure F574 input vector remains unchanged "+str(index))
		check(result.height_s32==int(expected.passes[0].height_s32),"Standalone F574 exact returned height "+str(index))
		check(result.globals.terrain_query_calls==int(expected.terrain_query_calls),"Standalone F574 actual terrain call count "+str(index))
		for key in ["altitude_low_u32","altitude_high_s32","previous_altitude_low_u32","previous_altitude_high_s32","collision_kind_u8","collision_flags_u8","volume_flags_u8","collider_index_u8","collision_active_u8","collision_enabled_u8","primitive_flags_u8"]:
			check(int(result.globals[key])==int(expected.passes[0][key]),"Standalone F574 original global "+key+"/"+str(index))

func invalid_controls()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_ground_surface_native.json"))
	var row:Dictionary=fixture.cases[0];var surface:=Surface.new()
	var port:PackedByteArray=str(row.expected.initialized_port_hex).hex_decode();var parent:PackedByteArray=str(row.expected.initialized_parent_hex).hex_decode()
	var point:=int64_vector(row.expected.passes[0].point_raw)
	var original_port:=port.duplicate();var original_parent:=parent.duplicate();var original_point:=point.duplicate()
	check(Surface.initialize_model(port.slice(0,337),84).is_empty(),"Short source object rejected")
	check(Surface.initialize_model(port,999).is_empty(),"Unreviewed model descriptor rejected")
	check(Surface.initialize_model(port,84,-1,0).is_empty(),"Invalid initialization clock rejected")
	check(surface.place_raw(port,parent,-1,0).is_empty() and surface.place_raw(port,parent,0,65536).is_empty(),"Out-of-domain source angle rejected")
	check(surface.sample_radial_raw(port,parent,PackedInt64Array([0,0,0])).is_empty(),"Zero continuous radial probe rejected")
	check(surface.sample_radial_raw(port,parent,PackedInt64Array([0x80000000,0,0])).is_empty(),"Out-of-range Q31 probe rejected")
	check(surface.height_raw(port,parent,PackedInt64Array([1,2])).is_empty(),"Malformed source vector rejected")
	check(surface.height_raw(port,parent,point,-1).is_empty() and surface.height_raw(port,parent,point,16).is_empty(),"Unreviewed graphics level rejected")
	for globals in [{"unknown":0},{"altitude_low_u32":-1},{"altitude_high_s32":0x80000000},{"collision_kind_u8":256},{"altitude_low_u32":NAN},{"previous_altitude_low_u32":"invalid"}]:check(surface.height_raw(port,parent,point,1,globals).is_empty(),"Invalid original context rejected atomically")
	var inside:=PackedInt64Array([0,0,0])
	check(surface.height_raw(port,parent,inside).is_empty(),"Interactive inner/contact response explicitly outside height domain")
	check(port==original_port and parent==original_parent and point==original_point,"Every rejected query leaves object/vector inputs unchanged")
	var shared:=Surface.model_resources(int(row.parent_model));var old:=int(shared.outer_radius_raw);shared.outer_radius_raw=-1
	check(int(Surface.model_resources(int(row.parent_model)).outer_radius_raw)==old,"Public descriptor copy cannot corrupt shared source resource")
