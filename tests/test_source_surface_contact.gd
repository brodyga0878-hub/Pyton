extends SceneTree
# Expected complete338-byte states come from independently executed original
# DOS instructions. Exact64-bit hex fields avoid JSON's binary64 conversion.
const Core=preload("res://scripts/source_surface_contact.gd")
const FIXTURE:="res://tests/fixtures/source_surface_contact_native.json"
const REPORT:="res://validation/contact-2026-11-08/source-surface-contact-core.json"
var checks:=0
var failures:=0
var domains:Dictionary={}
var domain_failures:Dictionary={}
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
func machine_globals(value:Dictionary)->Dictionary:
	var result:Dictionary=value.duplicate(true)
	result.previous_altitude_s64=str(result.previous_altitude_s64_hex).hex_decode().decode_s64(0)
	result.erase("previous_altitude_s64_hex")
	return result
func machine_context(value:Dictionary)->Dictionary:
	var relative_bytes:=str(value.relative_position_s64_hex).hex_decode()
	return {"globals":machine_globals(value.globals),"relative_position_s64":PackedInt64Array([relative_bytes.decode_s64(0),relative_bytes.decode_s64(8),relative_bytes.decode_s64(16)]),"distance_squared_s32":int(value.distance_squared_s32),"body_descriptor":str(value.body_descriptor_hex).hex_decode(),"parent_descriptor":str(value.parent_descriptor_hex).hex_decode(),"body_spec":str(value.body_spec_hex).hex_decode()}
func bytes_diagnostic(actual:PackedByteArray,expected:PackedByteArray)->String:
	var changed:Array=[]
	for offset in range(mini(actual.size(),expected.size())):
		if actual[offset]!=expected[offset]:
			changed.append("%03x:%02x/%02x"%[offset,actual[offset],expected[offset]])
			if changed.size()>=12:break
	return ",".join(changed)
func raw_callbacks(value:Array)->Array:
	var result:Array=[]
	for callback:Dictionary in value:
		if callback.function=="F953":result.append([953,int(callback.amount_s32)&0xffffffff,int(callback.attacker_u32),0])
	return result
func native_cases()->void:
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture is Dictionary and fixture.get("schema_version")==1 and fixture.get("executable_sha256")==Core.SOURCE_SHA,"Surface contact reference identifies uploaded DOS executable")
	if not fixture is Dictionary:return
	var proof:Dictionary=fixture.byte_instruction_proofs
	check(proof.size()==21 and proof.has("575_postclassification") and proof.has("abs"),"Bounded continuation and its complete19-helper+abs instruction proof are present")
	for name:String in proof:check(proof[name].all_instructions_equal_after_branch_destination_normalization,"Original DOS instruction match "+name)
	check(proof["575_postclassification"].byte_length==1657 and proof["575_postclassification"].instruction_count==518,"Runtime scope is the518-instruction bounded continuation, rather than all635 F575 instructions")
	var execution:Dictionary=fixture.execution_checks
	check(execution.fresh_identical_processes==3 and execution.reverse_case_order_identical and execution.object_parent_relative_descriptor_spec_output_canaries and execution.unrelated_body_bytes_unchanged and execution.parent_and_descriptors_and_specs_unchanged and not execution.expected_transitions_computed_by_python,"Three fresh native processes, reversed order and protected buffers agree without Python transition calculations")
	var cases_by_id:Dictionary={};var outputs_by_id:Dictionary={}
	for sample:Dictionary in fixture.cases:
		var label:=str(sample.id)+" "+str(sample.domain);var old_failures:=failures;var domain:=str(sample.domain)
		cases_by_id[str(sample.id)]=sample;domains[domain]=int(domains.get(domain,0))+1
		var body:=str(sample.body_hex).hex_decode();var parent:=str(sample.parent_hex).hex_decode();var context:=machine_context(sample.context)
		if baseline_body.is_empty():baseline_body=body.duplicate();baseline_parent=parent.duplicate();baseline_context=context.duplicate(true)
		var sample_before:=var_to_bytes(sample);var original_parent:=parent.duplicate();var original_relative:PackedInt64Array=context.relative_position_s64.duplicate()
		var damage_calls:Array=[];var callbacks:Array=[];var result:Dictionary={}
		for iteration in range(int(sample.repeat_count)):
			var before:=var_to_bytes([body,parent,context]);result=Core.resolve_player(body,parent,context)
			check(result.ok,label+" accepts native operand domain")
			check(var_to_bytes([body,parent,context])==before,label+" leaves all source buffers and globals immutable")
			if not result.ok:break
			body=result.body_after;context.globals=result.globals_after;damage_calls.append_array(result.damage_calls);callbacks.append_array(result.callbacks)
		var expected_body:=str(sample.expected.body_hex).hex_decode();var expected_globals:=machine_globals(sample.expected.globals)
		check(body==expected_body,label+" exact complete338-byte body "+bytes_diagnostic(body,expected_body))
		check(parent==original_parent and result.get("parent_after",PackedByteArray())==str(sample.expected.parent_hex).hex_decode(),label+" parent is the exact unmodified native buffer")
		check(equal_words(context.globals,expected_globals),label+" exact source flags, collision pointer identity and signed64 prior altitude actual="+str(context.globals)+" expected="+str(expected_globals))
		check(equal_words(result.get("normal_q31",[]),sample.expected.normal_q31),label+" exact original normal")
		check(int(result.get("l1_speed_s32",0))==int(sample.expected.initial_velocity_l1_s32),label+" signed wrapping L1 speed")
		check(int(result.get("alignment_q31",0))==int(sample.expected.alignment_dot_s32),label+" signed wrapping up-normal dot product")
		check(result.get("landing_accepted",false)==sample.expected.landing_accepted,label+" landing decision is freshly observed, not inferred from a preexisting flag")
		check(int(result.get("return_flags_u8",0))==int(sample.expected.return_flags_u8),label+" exact returned collision byte")
		check(equal_words(damage_calls,sample.expected.damage_calls) and equal_words(raw_callbacks(callbacks),sample.expected.callbacks_raw_u32),label+" exact F953 amount, attacker and invocation order")
		check(context.relative_position_s64==original_relative and var_to_bytes(sample)==sample_before,label+" immutable classification vector and external fixture")
		outputs_by_id[str(sample.id)]={"body":body,"result":result,"damage_calls":damage_calls}
		if failures>old_failures:domain_failures[domain]=int(domain_failures.get(domain,0))+failures-old_failures
	for control:Dictionary in fixture.independent_literal_controls:
		check(control.passed and equal_words(control.observed,control.literal_expected) and outputs_by_id.has(str(control.case_id)),"Independent native literal canary "+str(control.name))
	var total:=0
	for count:Variant in domains.values():total+=int(count)
	check(total==858 and total==int(fixture.case_count) and total==fixture.cases.size(),"Every native case is consumed once, including both source branches and repeated continuation calls")
	check(fixture.independent_literal_controls.size()==9,"All nine independent source semantic canaries remain present")
	evidence.append({"native_cases":total,"domains":domains.duplicate(true),"domain_failures":domain_failures.duplicate(true),"literal_controls":fixture.independent_literal_controls,"byte_instruction_proofs":proof,"execution_checks":execution,"scope":fixture.scope,"exact64_policy":"Decode little-endian raw64 hex; JSON decimal64 values are human previews only."})
func reject_case(body:PackedByteArray,parent:PackedByteArray,context:Dictionary,label:String)->void:
	var before:=var_to_bytes([body,parent,context]);var result:=Core.resolve_player(body,parent,context)
	check(not result.ok and result.body_after==body and result.parent_after==parent and result.damage_calls.is_empty() and result.callbacks.is_empty() and result.globals_after.is_empty(),label+" rejects atomically before any external request")
	check(var_to_bytes([body,parent,context])==before,label+" preserves caller inputs")
func boundary_contracts()->void:
	if baseline_body.is_empty():return
	for size_value:int in [0,337,339]:
		var body:=baseline_body.duplicate();body.resize(size_value);reject_case(body,baseline_parent,baseline_context,"Invalid body size"+str(size_value))
		var parent:=baseline_parent.duplicate();parent.resize(size_value);reject_case(baseline_body,parent,baseline_context,"Invalid parent size"+str(size_value))
	for key:String in ["body_descriptor","parent_descriptor","body_spec","globals","relative_position_s64","distance_squared_s32"]:
		var context:=baseline_context.duplicate(true);context.erase(key);reject_case(baseline_body,baseline_parent,context,"Missing context "+key)
	for key:String in Core.GLOBAL_KEYS:
		var context:=baseline_context.duplicate(true);context.globals.erase(key);reject_case(baseline_body,baseline_parent,context,"Missing global "+key)
	for key:String in ["body_descriptor","parent_descriptor","body_spec"]:
		var context:=baseline_context.duplicate(true);context[key]=PackedByteArray([0]);reject_case(baseline_body,baseline_parent,context,"Truncated raw resource "+key)
	for pair:Array in [["collision_flags_u8",-1],["collider_index_u8",256],["collision_active_u8",0.5],["collision_enabled_u8",true],["collision_kind_u8",NAN],["player_object_index_u32",4294967296],["previous_altitude_s64",1.0],["collider_parent_selected",1]]:
		var context:=baseline_context.duplicate(true);context.globals[pair[0]]=pair[1];reject_case(baseline_body,baseline_parent,context,"Malformed global "+str(pair))
	for relative:Variant in [[],[1,2],[1,2,3,4],[1,2,3.0],"123"]:
		var context:=baseline_context.duplicate(true);context.relative_position_s64=relative;reject_case(baseline_body,baseline_parent,context,"Malformed classified raw64 vector "+str(relative))
	for distance:Variant in [-2147483649,2147483648,0.5,INF,"0"]:
		var context:=baseline_context.duplicate(true);context.distance_squared_s32=distance;reject_case(baseline_body,baseline_parent,context,"Malformed signed32 squared-distance operand "+str(distance))
	var nonplayer:=baseline_body.duplicate();nonplayer[0x86]=(nonplayer[0x86]+1)&255;reject_case(nonplayer,baseline_parent,baseline_context,"NPC branch is outside player-only contract")
	var parent:=baseline_parent.duplicate();parent.encode_u32(0x82,baseline_body.decode_u32(0x82));reject_case(baseline_body,parent,baseline_context,"Conflicting descriptors cannot resolve to one source model index")
	var context:=baseline_context.duplicate(true);context.globals["metadata"]={"values":[1]};var result:=Core.resolve_player(baseline_body,baseline_parent,context);result.globals_after.metadata.values[0]=2
	check(context.globals.metadata.values==[1],"Returned globals are deeply isolated from caller metadata")
	check(result.source_contract==Core.CONTRACT and result.scope.contains("no collision provider"),"Runtime reports its bounded source scope explicitly")
	evidence.append({"case":"raw_api_guards","npc_rejected":true,"no_geometry_classification_claim":true,"no_executed_F953_claim":true,"no_F578_claim":true,"raw_kind_semantics":"kind1 natural branch; every otheru8 source branch can be arithmetic-tested, without live provider eligibility."})
func run()->void:
	native_cases();boundary_contracts()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	var sources:={"core_sha256":FileAccess.get_sha256("res://scripts/source_surface_contact.gd"),"test_sha256":FileAccess.get_sha256("res://tests/test_source_surface_contact.gd"),"fixture_sha256":FileAccess.get_sha256(FIXTURE),"native_generator_sha256":FileAccess.get_sha256("res://tools/rebuild_source_surface_contact_native.py"),"math_helpers":{"source_ground_surface":FileAccess.get_sha256("res://scripts/source_ground_surface.gd"),"ground_coordinates":FileAccess.get_sha256("res://scripts/ground_coordinates.gd"),"source_terrain_point":FileAccess.get_sha256("res://scripts/source_terrain_point.gd"),"source_gravity":FileAccess.get_sha256("res://scripts/source_gravity.gd")}}
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"domains":domains,"domain_failures":domain_failures,"sources":sources,"evidence":evidence,"scope":"Uploaded DOS F575 bounded postclassification player continuation. Exact338-byte pose/velocity correction, raw landing decision, flags and observed F953 requests versus independently executed instruction-matched controls. No geometry/classification, F569/F576/F577/F578, HP mutation or full collision-engine claim."},"\t"));file.close()
	print("Source surface contact: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
