extends SceneTree
# Original native F581 executes the final points and both signed witnesses.
# No expected altitude or classifier transition is computed by this test.
const Field=preload("res://scripts/source_terrain_contact_field.gd")
const Natural=preload("res://scripts/source_natural_contact.gd")
const Units=preload("res://scripts/source_units.gd")
const FIXTURE:="res://tests/fixtures/source_contact_field_native.json"
const REPORT:="res://build/current-test-reports/source-terrain-contact-field.json"
var checks:=0
var failures:=0
var query_counts:Dictionary={}
var statuses:Dictionary={}
var models:Dictionary={}
var field:=Field.new()
var results:Dictionary={}
var baseline_record:=PackedByteArray()
var baseline_direction:=PackedInt64Array()
class UnavailableField extends Field:
	func _sample_at(_direction:PackedInt64Array,_radius:int,_data:Dictionary,_cache:Dictionary,_trace:Array)->Dictionary:return {}
class NoCrossingField extends Field:
	func _sample_at(direction:PackedInt64Array,radius:int,_data:Dictionary,cache:Dictionary,trace:Array)->Dictionary:
		if cache.has(str(radius)):return cache[str(radius)]
		if trace.size()>=MAX_FIELD_QUERIES:return {}
		var sample:={"ray_radius_raw":radius,"position_raw":ray_point(direction,radius),"residual_raw_s64":1}
		cache[str(radius)]=sample;trace.append(sample);return sample
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=35:push_error(label)
func exact_vector(value:String)->PackedInt64Array:
	var bytes:=value.hex_decode()
	return PackedInt64Array([bytes.decode_s64(0),bytes.decode_s64(8),bytes.decode_s64(16)]) if bytes.size()==24 else PackedInt64Array()
func exact_scalar(value:String)->int:return value.hex_decode().decode_s64(0)
func equal_words(actual:Variant,expected:Variant)->bool:
	if actual is Dictionary and expected is Dictionary:
		if actual.size()!=expected.size():return false
		for key:Variant in actual:
			if not expected.has(key) or not equal_words(actual[key],expected[key]):return false
		return true
	if (actual is Array or actual is PackedInt64Array) and (expected is Array or expected is PackedInt64Array):
		if actual.size()!=expected.size():return false
		for index in range(actual.size()):
			if not equal_words(actual[index],expected[index]):return false
		return true
	if (actual is int or actual is float) and (expected is int or expected is float):return int(actual)==int(expected)
	return actual==expected
func tally(target:Dictionary,key:Variant)->void:target[str(key)]=int(target.get(str(key),0))+1
func native_geometry(fixture:Dictionary)->void:
	var geometry:Dictionary={}
	for row:Dictionary in fixture.geometry_cases:
		geometry[str(row.id)]=row
		var data:=Field._source_models(str(row.source_record_hex).hex_decode());var direction:=PackedInt64Array(row.radial_q31);var radius:=int(row.ray_radius_raw);var trace:Array=[]
		var point:=Field.ray_point(direction,radius)
		check(point==exact_vector(str(row.point_hex)),str(row.id)+" exact overflow-safe Q31×64 ray point agrees with independent native-input selection")
		var actual:Dictionary=field._sample_at(direction,radius,data,{},trace);var expected:Dictionary=row.expected
		check(not actual.is_empty() and trace.size()==1,str(row.id)+" one defined signed source query")
		if actual.is_empty():continue
		check(actual.position_raw==point and int(actual.residual_raw_s64)==exact_scalar(str(expected.residual_s64_hex)),str(row.id)+" exact original-native signed64 residual")
		for pair:Array in [["query_result_s32","query_result_s32"],["vector_scale_s32","vector_scale_s32"],["recorded_intersection_raw","recorded_intersection_raw"],["pending_query_flag","pending_query_flag"],["depth_control_raw","depth_control_raw"],["vertex_pool_count","vertex_pool_count"]]:check(int(actual[pair[0]])==int(expected[pair[1]]),str(row.id)+" native "+str(pair[0]))
		check(int(expected.terrain_query_calls)==1 and int(expected.native_f581_status_s32)==(0 if exact_scalar(str(expected.residual_s64_hex))<0 else -1),str(row.id)+" original strict terrain zero boundary")
	for anchor:Dictionary in fixture.anchors:
		var record:=str(anchor.source_record_hex).hex_decode();var direction:=PackedInt64Array(anchor.radial_q31);var original:=var_to_bytes([record,direction]);var result:=field.sample_radial(record,direction)
		if baseline_record.is_empty():baseline_record=record.duplicate();baseline_direction=direction.duplicate()
		check(result.ok and result.certified,str(anchor.id)+" certifies a measured signed source outcome")
		check(var_to_bytes([record,direction])==original,str(anchor.id)+" immutable source record and ray")
		if not result.ok:continue
		results[str(anchor.id)]=result;tally(query_counts,result.query_count);tally(statuses,result.status);tally(models,int(anchor.model_index))
		check(result.position_raw==exact_vector(str(anchor.final_point_hex)) and int(result.ray_radius_raw)==int(anchor.final_ray_radius_raw),str(anchor.id)+" deterministic point independently executed by the original classifier")
		check(str(result.status)==str(anchor.certified_status) and int(result.query_count)==int(anchor.field_query_count),str(anchor.id)+" bounded reproducible solver outcome")
		check(int(result.query_count)>=1 and int(result.query_count)<=Field.MAX_FIELD_QUERIES and result.query_trace.size()==int(result.query_count),str(anchor.id)+" hard query budget and complete trace")
		check(result.source_policy.seed_source_variant=="jjffe-7e54034-ground-surface" and "SAR3" in str(result.source_policy.seed_policy) and "SAR4" in str(result.source_policy.seed_policy),str(anchor.id)+" old seed provenance distinguishes pinned JJFFE from original DOS")
		check(result.seed.point_hex==anchor.seed.point_hex and result.seed.height_calls==2,str(anchor.id)+" original reviewed two-query seed remains unchanged")
		var final:Dictionary=geometry[str(anchor.id)+"/final"];var inside:Dictionary=geometry[str(anchor.id)+"/inside"];var outside:Dictionary=geometry[str(anchor.id)+"/outside"]
		check(int(result.residual_raw_s64)==exact_scalar(str(final.expected.residual_s64_hex)),str(anchor.id)+" claimed root residual independently executes in original native F581")
		check(exact_scalar(str(inside.expected.residual_s64_hex))<0 and exact_scalar(str(outside.expected.residual_s64_hex))>0 and int(inside.ray_radius_raw)<int(outside.ray_radius_raw),str(anchor.id)+" native negative inner and positive outer witnesses")
		check(int(inside.ray_radius_raw)<=int(result.ray_radius_raw) and int(result.ray_radius_raw)<=int(outside.ray_radius_raw),str(anchor.id)+" selected boundary lies within original-native signed witnesses")
		if result.status=="exact_zero":check(int(result.residual_raw_s64)==0,str(anchor.id)+" exact-zero status never rounds a nonzero residual")
		else:
			check(int(result.bracket.width_raw)==1 and int(result.bracket.inside.residual_raw_s64)<0 and int(result.bracket.outside.residual_raw_s64)>0,str(anchor.id)+" adjacent integer ray boundary retains its actual signed residual")
			check(result.bracket.inside.point_hex==inside.point_hex and result.bracket.outside.point_hex==outside.point_hex,str(anchor.id)+" both returned adjacent endpoints independently executed")
		check(float(result.residual_m)==Units.metres(float(result.residual_raw_s64)) and float(result.source_policy.metres_per_raw)==Units.METRES_PER_RAW,str(anchor.id)+" exact calibrated source units, not0.001")
		check(equal_words(result.source_bounds,anchor.source_bounds),str(anchor.id)+" original bound eligibility remains explicit")
	for model in range(117,134):check(models.has(str(model)) and int(models[str(model)])==3,"All three independent anchors of natural model "+str(model))
	check(statuses.has("exact_zero") and statuses.has("adjacent_sign_boundary"),"Both exact zeros and integer discontinuity boundaries are native witnessed")
	check(results.model117_axis_x.source_bounds.branch=="inside_inner" and results.model117_axis_z.source_bounds.branch=="outside_outer" and not results.model117_axis_x.source_bounds.terrain_query_eligible and not results.model117_axis_z.source_bounds.terrain_query_eligible,"Anisotropic117 geometry roots do not bypass either original source bound")
func native_classifiers(fixture:Dictionary)->void:
	var core:=Natural.new()
	for row:Dictionary in fixture.classifier_cases:
		var body:=str(row.player_object_hex).hex_decode();var parent:=str(row.parent_object_hex).hex_decode();var relative:=exact_vector(str(row.relative_before_hex));var context:Dictionary=row.context.duplicate(true);var before:=var_to_bytes([body,parent,relative,context])
		var result:=core.classify_natural_player(body,parent,relative,context);var expected:Dictionary=row.expected
		check(result.ok,str(row.id)+" original bounded positive-player classification is defined")
		check(var_to_bytes([body,parent,relative,context])==before,str(row.id)+" readonly field/classification never mutates ship or caller globals")
		if not result.ok:continue
		check(int(result.f576_return_s32)==int(expected.f576_return_s32) and equal_words(result.globals_after,expected.globals),str(row.id)+" actual original F576 with real positive radius and all child volumes")
		check(result.body_after==str(expected.player_hex).hex_decode() and result.parent_after==str(expected.parent_hex).hex_decode() and result.relative_position_s64==exact_vector(str(expected.relative_after_hex)),str(row.id)+" full guarded raw output records")
		check(int(result.terrain_query_calls)==int(expected.terrain_query_calls) and result.iterations.size()==int(expected.f579_calls),str(row.id)+" native query/volume counts")
func reject(record:PackedByteArray,direction:PackedInt64Array,graphics:int,label:String,provider:RefCounted=field)->void:
	var before:=var_to_bytes([record,direction]);var result:Dictionary=provider.sample_radial(record,direction,graphics)
	check(not result.ok and not result.certified and result.position_raw.is_empty() and result.bracket.is_empty(),label+" fails closed without a fabricated root")
	check(var_to_bytes([record,direction])==before and int(result.query_count)<=Field.MAX_FIELD_QUERIES,label+" immutable inputs and bounded work")
func contracts()->void:
	if baseline_record.is_empty():return
	for size_value:int in [0,67,69]:
		var changed:=baseline_record.duplicate();changed.resize(size_value);reject(changed,baseline_direction,1,"Invalid record size "+str(size_value))
	for model:int in [0,15,116,134,148,65535]:
		var changed:=baseline_record.duplicate();changed.encode_u16(12,model);reject(changed,baseline_direction,1,"Unsupported natural record "+str(model))
	for direction:PackedInt64Array in [PackedInt64Array(),PackedInt64Array([0,0,0]),PackedInt64Array([1,0,0]),PackedInt64Array([Field.Q31,Field.Q31,0]),PackedInt64Array([2147483648,0,0]),PackedInt64Array([0,0,0,Field.Q31])]:reject(baseline_record,direction,1,"Invalid Q31 ray "+str(direction))
	for graphics:int in [-1,0,2,15]:reject(baseline_record,baseline_direction,graphics,"Unsupported graphics level "+str(graphics))
	reject(baseline_record,baseline_direction,1,"Unavailable signed geometry dependency",UnavailableField.new())
	reject(baseline_record,baseline_direction,1,"No outward signed crossing",NoCrossingField.new())
	check(Field.ray_point(PackedInt64Array([Field.Q31,0,0]),1099511627793)==PackedInt64Array([1099511627280,0,0]),"Positive64 ray multiplication uses all bits beyond a direct signed64 product")
	check(Field.ray_point(PackedInt64Array([-Field.Q31,0,0]),1099511627793)==PackedInt64Array([-1099511627281,0,0]),"Negative64 ray multiplication keeps arithmetic floor")
	check(Field.ray_point(PackedInt64Array([-2147483648,0,0]),1099511627793)==PackedInt64Array([-1099511627793,0,0]),"Minimum signed Q31 is exact negative unity")
func run()->void:
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)) if FileAccess.file_exists(FIXTURE) else null
	check(fixture is Dictionary and fixture.get("source_sha256")==Field.SOURCE_SHA,"Independent original-native field fixture identifies uploaded DOS")
	if fixture is Dictionary:
		check(fixture.anchor_count==51 and fixture.geometry_case_count==153 and fixture.classifier_case_count==306 and fixture.case_count==459,"Independent17×3 anchor bank and all three positive-player banks are complete")
		check(fixture.fresh_process_runs_per_bank==3 and fixture.geometry_reverse_repeat_count==153 and fixture.classifier_reverse_repeat_count==306 and fixture.original_body_parent_buffers_and_canaries_unchanged and fixture.python_expected_query_arithmetic==false,"Three fresh native processes per bank, reverse ordering, canaries and machine-computed expectations")
		native_geometry(fixture);native_classifiers(fixture);contracts()
	var report:={"schema":1,"test":"source_terrain_contact_field","checks":checks,"failures":failures,"source_contract":Field.CONTRACT,"height_policy":Field.HEIGHT_POLICY,"native_case_count":459 if fixture is Dictionary else 0,"anchor_count":results.size(),"query_counts":query_counts,"statuses":statuses,"models":models,"field_source_sha256":FileAccess.get_sha256("res://scripts/source_terrain_contact_field.gd"),"test_source_sha256":FileAccess.get_sha256("res://tests/test_source_terrain_contact_field.gd"),"fixture_sha256":FileAccess.get_sha256(FIXTURE),"scope":"New signed F581 geometry caller only. Old JJFFE SAR3 two-query seed and all old kernels unchanged. Exact zeros or adjacent outward sign boundaries; no fabricated zero, no global uniqueness claim, original117 gate exclusions explicit. Per-node certificates do not certify interpolated meshes or imply live F575/HP/clock integration."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(report,"\t")+"\n")
	print("Source terrain contact field: "+str(checks)+" checks, "+str(failures)+" failures");quit(1 if failures>0 else 0)
