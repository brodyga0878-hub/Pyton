extends SceneTree
# The observer is compared with the unchanged kernel and with independently
# executed original native transitions. No floating plane is an oracle.
const Natural=preload("res://scripts/source_natural_contact.gd")
const Point=preload("res://scripts/source_terrain_point.gd")
const Query=preload("res://scripts/source_terrain_query.gd")
const Trace=preload("res://scripts/source_terrain_query_trace.gd")
const ORIGINAL_FIXTURE:="res://tests/fixtures/source_natural_contact_native.json"
const ROOT_FIXTURE:="res://tests/fixtures/source_contact_field_native.json"
const FOOTPRINT_FIXTURE:="res://tests/fixtures/source_footprint_native.json"
const REPORT:="res://validation/footprint-2026-11-14/source-terrain-query-trace.json"
var checks:=0
var failures:=0
var evidence:Array=[]
var baseline_cases:=0
var baseline_queries:=0
var root_queries:=0
var native_leaf_cases:=0
var native_leaves:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=30:push_error(label)
func same(actual:Variant,expected:Variant)->bool:
	if actual is Dictionary and expected is Dictionary:
		if actual.size()!=expected.size():return false
		for key:Variant in actual:
			if not expected.has(key) or not same(actual[key],expected[key]):return false
		return true
	if (actual is Array or actual is PackedInt64Array) and (expected is Array or expected is PackedInt64Array):
		if actual.size()!=expected.size():return false
		for index in range(actual.size()):
			if not same(actual[index],expected[index]):return false
		return true
	if (actual is int or actual is float) and (expected is int or expected is float):return int(actual)==int(expected)
	return actual==expected
func exact_vector(hex_value:String)->PackedInt64Array:
	var raw:=hex_value.hex_decode()
	return PackedInt64Array([raw.decode_s64(0),raw.decode_s64(8),raw.decode_s64(16)]) if raw.size()==24 else PackedInt64Array()
func read_fixture(path:String)->Dictionary:
	var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	check(value is Dictionary,"Required independently executed fixture exists: "+path)
	return value if value is Dictionary else {}

func inspect_query(row:Dictionary,classified:Dictionary,label:String)->void:
	check(row.get("query_ok")==true and row.get("result") is Dictionary,"Observer retains a valid original query result: "+label)
	check(row.get("intersections") is Array and row.intersections.size()==1,"Original selected-face traversal records exactly one leaf: "+label)
	if not row.get("winning_triangle") is Dictionary or row.winning_triangle.is_empty():check(false,"Original winning triangle is present: "+label);return
	var leaf:Dictionary=row.winning_triangle
	check(leaf.positions_raw.size()==3 and leaf.normals_raw.size()==3 and leaf.depths_s32.size()==3 and leaf.vertex_ids_s32.size()==3,"Observed leaf retains three independent vertices and source attributes: "+label)
	check(leaf.plane_fraction_calls.size()==2 and leaf.vertex_ids_are_native_pointers==false,"Both original integer fraction calls are observed without mislabelling host cache IDs as native pointers: "+label)
	check(int(leaf.recorded_intersection_raw)==int(row.result.recorded_intersection_raw),"Observed leaf result equals the original returned intersection: "+label)
	check(same(row.query_matrix_raw,classified.query_matrix_raw) and same(row.query_center_raw,classified.query_center_raw),"Observer retains the exact integer F581 query frame: "+label)
	check(int(row.query_limit_s32)==int(classified.query_limit_raw) and int(row.result.query_result_raw)==int(classified.query_result_raw),"Observer retains the exact query limit and original result: "+label)

func complete_existing_native_controls()->void:
	var fixture:=read_fixture(ORIGINAL_FIXTURE)
	if fixture.is_empty():return
	check(fixture.get("source_sha256")==Natural.SOURCE_SHA and fixture.get("case_count")==993,"Preserved canonical993-case original native classifier fixture")
	var original:=Natural.new();var observed:=Natural.new();var trace:=Trace.new();observed._query=trace
	for sample:Dictionary in fixture.cases:
		var label:=str(sample.name);var player:=str(sample.player_object_hex).hex_decode();var parent:=str(sample.parent_object_hex).hex_decode();var relative:=exact_vector(str(sample.relative_before_hex));var context:Dictionary=sample.context.duplicate(true)
		var before:=var_to_bytes([player,parent,relative,context]);trace.reset_trace()
		var expected:=original.classify_natural_player(player,parent,relative,context);var actual:=observed.classify_natural_player(player,parent,relative,context)
		baseline_cases+=1
		check(same(actual,expected),"Installing the observer preserves the complete unchanged classifier result: "+label)
		check(actual.get("ok",false) and int(actual.f576_return_s32)==int(sample.expected.f576_return_s32) and same(actual.globals_after,sample.expected.globals),"Observed classification retains the independently executed native return and all globals: "+label)
		check(actual.body_after==str(sample.expected.player_hex).hex_decode() and actual.parent_after==str(sample.expected.parent_hex).hex_decode() and actual.relative_position_s64==exact_vector(str(sample.expected.relative_after_hex)),"Observed classification retains all native raw buffers: "+label)
		check(var_to_bytes([player,parent,relative,context])==before,"Observation never changes caller buffers or globals: "+label)
		var rows:=trace.read_trace();baseline_queries+=rows.size()
		check(rows.size()==int(sample.expected.terrain_query_calls) and rows.size()==actual.query_trace.size() and not trace.trace_state().trace_truncated,"One bounded observer record corresponds to each original F1876 call: "+label)
		for index in range(mini(rows.size(),actual.query_trace.size())):
			inspect_query(rows[index],actual.query_trace[index],label+" query"+str(index))
	check(baseline_cases==993 and baseline_queries==501,"Every original native classifier case and all501 visited terrain queries are consumed once")
	evidence.append({"case":"complete_original_classifier_observation","native_fixture_cases":baseline_cases,"observed_query_count":baseline_queries,"full_classifier_results_equal_unmodified_kernel":true,"expected_native_transitions_reexecuted_by_this_test":false})

func signed_root_query_controls()->void:
	var fixture:=read_fixture(ROOT_FIXTURE)
	if fixture.is_empty():return
	var point:=Point.new();var trace:=Trace.new();var ordinary:=Query.new()
	for sample:Dictionary in fixture.geometry_cases:
		var label:=str(sample.id);var observer:=PackedInt64Array()
		for value:Variant in sample.expected.observer_model_local_raw:observer.append(int(value))
		var frame:=point.frame_raw(int(sample.model_index),observer,int(sample.expected.vector_scale_s32));check(not frame.is_empty(),"Independently native-proved signed-root query supplies its original F581 frame: "+label)
		if frame.is_empty():continue
		var record:=str(sample.source_record_hex).hex_decode();trace.reset_trace()
		var before:=var_to_bytes([frame.query_matrix_raw,frame.query_center_raw,frame.features])
		var expected:=ordinary.query_raw(record.decode_u32(4),int(frame.query_style_raw),frame.query_matrix_raw,frame.query_center_raw,int(frame.query_limit_raw),1,frame.features)
		var actual:=trace.query_raw(record.decode_u32(4),int(frame.query_style_raw),frame.query_matrix_raw,frame.query_center_raw,int(frame.query_limit_raw),1,frame.features)
		root_queries+=1
		check(same(actual,expected) and int(actual.query_result_raw)==int(sample.expected.query_result_s32),"Tracing preserves unchanged and independently native-proved near-root query results: "+label)
		check(var_to_bytes([frame.query_matrix_raw,frame.query_center_raw,frame.features])==before,"Near-root query tracing preserves all input arrays and features: "+label)
		var rows:=trace.read_trace();check(rows.size()==1,"Exactly one near-root query record is returned: "+label)
		if rows.size()!=1:continue
		var known:=frame.duplicate(true);known["query_result_raw"]=int(sample.expected.query_result_s32)
		inspect_query(rows[0],known,label)
	check(root_queries==153,"All153 independently native-proved geometry cases retain original source arithmetic")
	evidence.append({"case":"independent_near_root_queries","geometry_cases":root_queries,"winning_float_plane_is_native_intersection":false,"source_SAR13_and_Q15_approximation_retained":true})

func native_winning_leaf_controls()->void:
	# The compact original-MOV observer fixture is added by the independent
	# native executor. Missing evidence must fail, not become a skipped pass.
	var fixture:=read_fixture(FOOTPRINT_FIXTURE)
	if fixture.is_empty():return
	check(fixture.get("source_sha256")==Natural.SOURCE_SHA and fixture.get("native_fresh_process_runs_per_bank")==3,"New winning-triangle controls identify the uploaded executable and three fresh processes per bank")
	check(fixture.actor_cases.size()==int(fixture.actor_case_count) and fixture.ground_cases.size()==int(fixture.visible_ground_case_count) and int(fixture.actor_reverse_repeat_count)==fixture.actor_cases.size() and int(fixture.ground_reverse_repeat_count)==fixture.ground_cases.size(),"All compact actor/direct-query controls repeat identically in reverse order")
	var observed:=Natural.new();var original:=Natural.new();var trace:=Trace.new();observed._query=trace
	for sample:Dictionary in fixture.actor_cases:
		var label:=str(sample.id);var player:=str(sample.player_object_hex).hex_decode();var parent:=str(sample.parent_object_hex).hex_decode();var relative:=exact_vector(str(sample.relative_before_hex));var context:Dictionary=sample.context.duplicate(true)
		trace.reset_trace();var before:=var_to_bytes([player,parent,relative,context]);var actual:=observed.classify_natural_player(player,parent,relative,context);var expected:Dictionary=sample.expected.canonical
		check(actual.get("ok",false) and int(actual.f576_return_s32)==int(expected.f576_return_s32) and same(actual.globals_after,expected.globals),"New native observed actor classification retains exact source return/globals: "+label)
		check(actual.body_after==str(expected.player_hex).hex_decode() and actual.parent_after==str(expected.parent_hex).hex_decode() and actual.relative_position_s64==exact_vector(str(expected.relative_after_hex)) and var_to_bytes([player,parent,relative,context])==before,"New winning-leaf observation leaves all original actor/caller records unchanged: "+label)
		compare_native_leaves(trace.read_trace(),sample.expected.volume_trace,actual.query_trace,label)
		native_leaf_cases+=1
	for sample:Dictionary in fixture.ground_cases:
		var label:=str(sample.id);var player:=str(sample.player_object_hex).hex_decode();var parent:=str(sample.parent_object_hex).hex_decode();var relative:=exact_vector(str(sample.relative_before_hex));var context:Dictionary=sample.context.duplicate(true)
		var state:=Natural._globals(context.initial_globals);var old_state:=state.duplicate(true);var model:=Natural.parent_model(parent.decode_u32(0x82));var before:=var_to_bytes([player,parent,relative,context]);trace.reset_trace()
		var actual:=observed._classify_record(player,parent,relative,0,model,state,int(context.get("graphics_level",1)));var ordinary:=original._classify_record(player,parent,relative,0,model,old_state,int(context.get("graphics_level",1)))
		check(not actual.is_empty() and same(actual,ordinary) and same(state,old_state),"Direct visible-point trace preserves the unchanged F579 result and globals: "+label)
		check(not actual.is_empty() and int(actual.return_s32)==int(sample.expected.canonical.f576_return_s32) and same(state,sample.expected.canonical.globals),"Direct threshold-zero query agrees with independently executed original F579: "+label)
		check(var_to_bytes([player,parent,relative,context])==before,"Direct visible-point observation leaves all caller records unchanged: "+label)
		var known:Array=[]
		if not actual.is_empty() and int(actual.trace.terrain_query_calls)>0:known.append(actual.trace)
		compare_native_leaves(trace.read_trace(),sample.expected.volume_trace,known,label)
		native_leaf_cases+=1
	check(native_leaf_cases==int(fixture.case_count) and native_leaves>0,"Every compact native control and every actually visited winning triangle is consumed")
	evidence.append({"case":"new_independent_native_winning_leaves","native_cases":native_leaf_cases,"native_leaf_count":native_leaves,"actor_controls":fixture.actor_cases.size(),"direct_ground_controls":fixture.ground_cases.size(),"source_vertex_positions_depths_SAR_and_intercept_compared":true,"unvisited_children_certified":false,"plane_fractions_have_separate_native_observation":false})

func compare_native_leaves(rows:Array,visits:Array,query_frames:Array,label:String)->void:
	var at:=0
	for visit:Dictionary in visits:
		if not visit.query.executed:
			check(not visit.winning_triangle.captured,"Native coarse branch has no fabricated winning triangle: "+label)
			continue
		check(visit.winning_triangle.captured and at<rows.size() and at<query_frames.size(),"Executed native F1876 has one corresponding observed leaf: "+label)
		if at>=rows.size() or at>=query_frames.size():continue
		var row:Dictionary=rows[at];var leaf:Dictionary=row.winning_triangle;var expected:Dictionary=visit.winning_triangle
		inspect_query(row,query_frames[at],label+" query"+str(at))
		check(same(leaf.positions_raw,expected.positions_raw),"All nine winning vertex position words equal native MOV-only observations: "+label)
		check(same(leaf.depths_s32,expected.depths_s32) and int(leaf.leaf_depth_s32)==int(expected.leaf_depth_s32),"Winning vertex depths and actual subdivision level equal native observations: "+label)
		check(int(leaf.sar_shift_s32)==int(expected.sar_shift_s32) and int(leaf.recorded_intersection_raw)==int(expected.recorded_intersection_raw),"Winning intersection SAR shift and signed result equal original native observations: "+label)
		check(int(row.result.query_result_raw)==int(visit.query.result_s32) and int(row.query_limit_s32)==int(visit.query.limit_s32),"Original native query return and active query limit are retained: "+label)
		at+=1;native_leaves+=1
	check(at==rows.size() and at==query_frames.size(),"Only actually executed original queries publish leaf records: "+label)

func private_copies_reset_and_cap()->void:
	var trace:=Trace.new();var ordinary:=Query.new();var matrix:=PackedInt64Array([1000000,0,0,0,1000000,0,0,0,1000000]);var center:=PackedInt64Array([0,0,2000000]);var features:=PackedByteArray([0,0])
	var expected:=ordinary.query_raw(13,0,matrix,center,2000000000,1,features)
	var actual:=trace.query_raw(13,0,matrix,center,2000000000,1,features)
	check(same(actual,expected) and trace.read_trace().size()==1,"Standalone direct query preserves the original complete result")
	var original:=var_to_bytes(trace.read_trace());var copied:=trace.read_trace()
	if copied.size()==1 and not copied[0].winning_triangle.is_empty():
		copied[0].query_matrix_raw[0]=0;copied[0].winning_triangle.positions_raw[0][0]=123;copied[0].winning_triangle.plane_fraction_calls[0].fraction_s32=987
	check(var_to_bytes(trace.read_trace())==original,"Caller mutations cannot alter private trace matrices, vertices or fraction records")
	var base_state:=var_to_bytes([trace.depth_control,trace.vertex_count,trace.vertex_serial,trace.invalid_query]);trace.reset_trace()
	check(trace.read_trace().is_empty() and trace.trace_state().query_count==0 and not trace.trace_state().trace_truncated and var_to_bytes([trace.depth_control,trace.vertex_count,trace.vertex_serial,trace.invalid_query])==base_state,"Reset clears only the observer journal and leaves the original kernel state untouched")
	for index in range(Trace.MAX_TRACE_QUERIES+1):
		actual=trace.query_raw(13,0,matrix,center,2000000000,1,features)
		check(same(actual,expected),"Bounded observation cannot change arithmetic when its record limit is reached")
	var state:=trace.trace_state()
	check(trace.read_trace().size()==Trace.MAX_TRACE_QUERIES and state.query_count==Trace.MAX_TRACE_QUERIES+1 and state.trace_truncated,"Observer journal has an explicit bounded size and reports truncation")
	trace.reset_trace();actual=trace.query_raw(13,0,PackedInt64Array([1]),center,2000000000,1,features)
	check(actual.is_empty() and trace.read_trace().size()==1 and not trace.read_trace()[0].query_ok and trace.read_trace()[0].winning_triangle.is_empty(),"Rejected original query returns no fabricated winning triangle")
	evidence.append({"case":"private_bounded_observer_journal","max_query_records":Trace.MAX_TRACE_QUERIES,"cap_changes_source_query_results":false,"reset_changes_base_kernel_state":false,"traces_are_private_copies":true})

func run()->void:
	complete_existing_native_controls();signed_root_query_controls();native_winning_leaf_controls();private_copies_reset_and_cap()
	var sources:Dictionary={}
	for path:String in ["scripts/source_terrain_query.gd","scripts/source_terrain_query_trace.gd","scripts/source_natural_contact.gd","scripts/source_terrain_point.gd","tests/test_source_terrain_query_trace.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	var report:={"schema":1,"source_contract":Trace.CONTRACT,"checks":checks,"failures":failures,"existing_native_classifier_cases":baseline_cases,"existing_native_query_count":baseline_queries,"existing_native_geometry_cases":root_queries,"new_native_leaf_cases":native_leaf_cases,"new_native_leaf_count":native_leaves,"sources":sources,"fixtures":{"original_classifier_sha256":FileAccess.get_sha256(ORIGINAL_FIXTURE),"signed_root_sha256":FileAccess.get_sha256(ROOT_FIXTURE),"winning_leaf_sha256":FileAccess.get_sha256(FOOTPRINT_FIXTURE) if FileAccess.file_exists(FOOTPRINT_FIXTURE) else ""},"evidence":evidence,"scope":"Private bounded observer of the actual F1876 selected leaf, original signed vertices and original super-call plane fractions. Existing native controls are reused, not new native executions. No source-field/float-plane equivalence, local provider certificate, geometry publication, HP, time, source object bank, live response or physical Android claim."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("SOURCE TERRAIN QUERY TRACE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
