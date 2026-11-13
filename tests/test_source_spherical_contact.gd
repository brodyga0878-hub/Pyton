extends SceneTree
# Complete original DOS native states are the expected values. No copy of the
# classifier formula is used to construct an expected transition in this test.
const Core=preload("res://scripts/source_spherical_contact.gd")
const FIXTURE:="res://tests/fixtures/source_spherical_contact_native.json"
const REPORT:="res://build/current-test-reports/source-spherical-contact-core.json"
var checks:=0
var failures:=0
var domains:Dictionary={}
var domain_failures:Dictionary={}
var shifts:Dictionary={}
var returns:Dictionary={}
var evidence:Array=[]
var baseline_body:PackedByteArray
var baseline_parent:PackedByteArray
var baseline_context:Dictionary
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=40:push_error(message)
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
func exact_vector(hex_value:String)->PackedInt64Array:
	var raw:=hex_value.hex_decode()
	return PackedInt64Array([raw.decode_s64(0),raw.decode_s64(8),raw.decode_s64(16)])
func machine_globals(value:Dictionary)->Dictionary:
	var result:Dictionary=value.duplicate(true)
	result.altitude_s64=str(result.altitude_s64_hex).hex_decode().decode_s64(0)
	result.erase("altitude_s64_hex")
	return result
func machine_context(value:Dictionary)->Dictionary:
	return {"relative_position_s64":exact_vector(str(value.relative_position_s64_hex)),"absolute_position_s64":exact_vector(str(value.absolute_position_s64_hex)),"globals":machine_globals(value.globals)}
func native_cases()->void:
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture is Dictionary and fixture.get("schema_version")==1 and fixture.get("executable_sha256")==Core.SOURCE_SHA,"Spherical classifier reference identifies uploaded DOS executable")
	if not fixture is Dictionary:return
	var proof:Dictionary=fixture.byte_instruction_proofs
	check(proof.has("577") and proof.size()==7,"Native fixture includes complete F577 and all six integer helper instruction proofs")
	for name:String in proof:check(proof[name].all_instructions_equal_after_branch_destination_normalization,"Exact original DOS instructions "+name)
	check(proof["577"].byte_length==363,"Full classifier byte scope is363 DOS bytes")
	var execution:Dictionary=fixture.execution_checks
	check(execution.fresh_identical_processes==3 and execution.reverse_case_order_identical and execution.object_parent_relative_absolute_output_canaries and execution.all_input_buffers_unchanged and not execution.expected_transitions_computed_by_python,"Three native processes, reverse order and guarded readonly buffers agree without Python transition calculations")
	var cases_by_id:Dictionary={}
	for sample:Dictionary in fixture.cases:
		var domain:=str(sample.get("domain",sample.get("input_domain","")));var label:=str(sample.id)+" "+domain;var old_failures:=failures
		cases_by_id[str(sample.id)]=sample;domains[domain]=int(domains.get(domain,0))+1
		var body:=str(sample.body_hex).hex_decode();var parent:=str(sample.parent_hex).hex_decode();var context:=machine_context(sample.context)
		if baseline_body.is_empty():baseline_body=body.duplicate();baseline_parent=parent.duplicate();baseline_context=context.duplicate(true)
		var sample_before:=var_to_bytes(sample);var original:=var_to_bytes([body,parent,context]);var result:=Core.classify(body,parent,context)
		check(result.ok,label+" accepts native raw operand domain")
		if not result.ok:continue
		check(var_to_bytes([body,parent,context])==original,label+" leaves both bodies, raw vectors and globals immutable")
		check(result.body_after==str(sample.expected.body_hex).hex_decode() and result.body_after==body,label+" exact readonly338-byte body")
		check(result.parent_after==str(sample.expected.parent_hex).hex_decode() and result.parent_after==parent,label+" exact readonly338-byte parent")
		check(result.relative_position_s64==exact_vector(str(sample.expected.relative_position_s64_hex)) and result.absolute_position_s64==exact_vector(str(sample.expected.absolute_position_s64_hex)),label+" exact unchanged source input vectors")
		check(result.scaled_position_s64==exact_vector(str(sample.expected.scaled_position_s64_hex)),label+" exact by-value local words including preserved high DWORDs on the low-shift path")
		for key:String in ["return_s32","distance_squared_s32","shift_s32","radius_s32","radius_squared_s32"]:check(int(result[key])==int(sample.expected[key]),label+" native "+key+" actual="+str(result[key])+" expected="+str(sample.expected[key]))
		check(result.inside_sphere==sample.expected.inside_sphere and result.inside_sphere==(int(result.return_s32)==0),label+" geometric inside means source return0; equality/outside means−1")
		check(equal_words(result.globals_after,machine_globals(sample.expected.globals)),label+" exact source flags and signed64 altitude")
		check(result.global_writes.is_empty() if result.inside_sphere else result.global_writes.keys().size()==2 and result.global_writes.collision_flags_u8==result.globals_after.collision_flags_u8 and result.global_writes.altitude_s64==result.globals_after.altitude_s64,label+" only the outside branch publishes the two actual source global writes")
		check(var_to_bytes(sample)==sample_before,label+" independent native fixture remains immutable")
		shifts[str(int(result.shift_s32))]=int(shifts.get(str(int(result.shift_s32)),0))+1
		returns[str(int(result.return_s32))]=int(returns.get(str(int(result.return_s32)),0))+1
		if failures>old_failures:domain_failures[domain]=int(domain_failures.get(domain,0))+failures-old_failures
	var counterfactual:Dictionary=fixture.jjffe_counterfactual_case
	for control:Dictionary in fixture.independent_literal_controls:check(control.passed and equal_words(control.observed,control.literal_expected) and (cases_by_id.has(str(control.case_id)) or str(control.case_id)==str(counterfactual.id)),"Independent literal native canary "+str(control.name))
	var variant:Dictionary=fixture.known_jjffe_variant
	check(variant.difference_count==1 and variant.all_other_instructions_equal,"Exactly one original operand distinguishes complete F577 from the pinned JJFFE procedure")
	check(counterfactual.body_hex==fixture.cases[0].body_hex and counterfactual.parent_hex==fixture.cases[0].parent_hex and equal_words(counterfactual.context,fixture.cases[0].context) and int(counterfactual.expected.return_s32)==-1 and int(fixture.cases[0].expected.return_s32)==0,"Identical raw input independently executes DOS inside and patched JJFFE outside; the counterfactual is not counted as a DOS case")
	var total:=0
	for count:Variant in domains.values():total+=int(count)
	check(total==int(fixture.case_count) and total==fixture.cases.size() and total>100,"All native classifier cases are consumed once")
	for value:int in [-29,0,1,31,32,34]:check(shifts.has(str(value)),"Critical source shift covered "+str(value))
	check(returns.has("0") and returns.has("-1"),"Both raw classifier returns are independently exercised")
	evidence.append({"native_cases":total,"domains":domains.duplicate(true),"domain_failures":domain_failures.duplicate(true),"shifts":shifts.duplicate(true),"returns":returns.duplicate(true),"literal_controls":fixture.independent_literal_controls,"known_jjffe_variant":variant,"separate_jjffe_counterfactual_cases":1,"byte_instruction_proofs":proof,"execution_checks":execution,"scope":fixture.scope,"exact64_policy":"Decode little-endian hex; decimal64 JSON previews never supply machine inputs."})
func reject_case(body:PackedByteArray,parent:PackedByteArray,context:Dictionary,label:String)->void:
	var original:=var_to_bytes([body,parent,context]);var result:=Core.classify(body,parent,context)
	check(not result.ok and result.body_after==body and result.parent_after==parent and result.globals_after.is_empty() and result.global_writes.is_empty(),label+" rejects before any raw output/global mutation")
	check(var_to_bytes([body,parent,context])==original,label+" preserves caller inputs")
func boundary_contracts()->void:
	if baseline_body.is_empty():return
	for size_value:int in [0,337,339]:
		var body:=baseline_body.duplicate();body.resize(size_value);reject_case(body,baseline_parent,baseline_context,"Invalid body size "+str(size_value))
		var parent:=baseline_parent.duplicate();parent.resize(size_value);reject_case(baseline_body,parent,baseline_context,"Invalid parent size "+str(size_value))
	for key:String in ["relative_position_s64","absolute_position_s64","globals"]:
		var context:=baseline_context.duplicate(true);context.erase(key);reject_case(baseline_body,baseline_parent,context,"Missing context "+key)
	for key:String in Core.GLOBAL_KEYS:
		var context:=baseline_context.duplicate(true);context.globals.erase(key);reject_case(baseline_body,baseline_parent,context,"Missing source global "+key)
	for key:String in ["relative_position_s64","absolute_position_s64"]:
		for invalid:Variant in [null,[],[1,2],[1,2,3,4],[1,2,3.0],PackedFloat64Array([1,2,3]),"123",[1,2,true]]:
			var context:=baseline_context.duplicate(true);context[key]=invalid;reject_case(baseline_body,baseline_parent,context,"Invalid raw64 vector "+key+" "+str(invalid))
	for invalid:Variant in [-1,256,0.5,INF,NAN,"0",true]:
		var context:=baseline_context.duplicate(true);context.globals.collision_flags_u8=invalid;reject_case(baseline_body,baseline_parent,context,"Invalid source flag byte "+str(invalid))
	for invalid:Variant in [0.0,INF,"0",true]:
		var context:=baseline_context.duplicate(true);context.globals.altitude_s64=invalid;reject_case(baseline_body,baseline_parent,context,"Invalid exact signed64 altitude "+str(invalid))
	var context:=baseline_context.duplicate(true);context.globals.collision_kind_u8=0x5a;context.globals.previous_altitude_s64=-9223372036854775807;context.globals["metadata"]={"values":[1]}
	var original:=var_to_bytes(context);var result:=Core.classify(baseline_body,baseline_parent,context)
	check(result.ok and result.globals_after.collision_kind_u8==0x5a and result.globals_after.previous_altitude_s64==-9223372036854775807,"F577 never assigns a caller collision kind or F581 previous-altitude field")
	result.globals_after.metadata.values[0]=2
	check(var_to_bytes(context)==original,"Returned optional global metadata is deeply isolated")
	var independent:=baseline_context.duplicate(true);independent.absolute_position_s64=PackedInt64Array([0,0,0])
	check(Core.classify(baseline_body,baseline_parent,independent).ok,"Separate absolute vector is an explicit source helper operand; caller consistency is not silently fabricated")
	check(result.source_contract==Core.CONTRACT and result.scope.contains("no collider scan"),"Runtime scope is exactly one source classifier helper")
	evidence.append({"case":"pure_raw_api_guards","signed64_hex_inputs":true,"bodies_mutated":false,"automatic_kind_assignment":false,"automatic_previous_altitude_assignment":false,"collider_bank_or_F578_claim":false})
func run()->void:
	native_cases();boundary_contracts()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	var sources:={"core_sha256":FileAccess.get_sha256("res://scripts/source_spherical_contact.gd"),"test_sha256":FileAccess.get_sha256("res://tests/test_source_spherical_contact.gd"),"fixture_sha256":FileAccess.get_sha256(FIXTURE),"native_generator_sha256":FileAccess.get_sha256("res://tools/rebuild_source_spherical_contact_native.py"),"reused_helpers":{"source_surface_contact":FileAccess.get_sha256("res://scripts/source_surface_contact.gd"),"source_ground_surface":FileAccess.get_sha256("res://scripts/source_ground_surface.gd"),"ground_coordinates":FileAccess.get_sha256("res://scripts/ground_coordinates.gd"),"source_terrain_point":FileAccess.get_sha256("res://scripts/source_terrain_point.gd"),"source_gravity":FileAccess.get_sha256("res://scripts/source_gravity.gd"),"source_orbit":FileAccess.get_sha256("res://scripts/source_orbit.gd")}}
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"domains":domains,"domain_failures":domain_failures,"sources":sources,"evidence":evidence,"scope":"Complete uploaded DOS F577 helper versus independently executed original instructions. Original DOS parent outer-radius operand retained, including its difference from JJFFE. No collider banks, F575 caller decision/response, F578, terrain classification or HP mutation."},"\t"));file.close()
	print("Source spherical contact: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
