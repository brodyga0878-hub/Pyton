extends "res://tests/test_source_spherical_contact.gd"
# Independent full-F575 native controls exercise this bounded composed route.
# The original raw mutation is returned on copied buffers; live terrain and
# unsupported F576/F578 branches are never supplied a fabricated response.
const Pipeline=preload("res://scripts/source_spherical_contact_pipeline.gd")
const CHAIN_FIXTURE:="res://tests/fixtures/source_spherical_contact_pipeline_native.json"
const CHAIN_REPORT:="res://build/current-test-reports/source-spherical-pipeline.json"
var chain_domains:Dictionary={}
var chain_branches:Dictionary={}
var chain_evidence:Array=[]
var chain_body:PackedByteArray
var chain_parent:PackedByteArray
var chain_context:Dictionary

func chain_globals(value:Dictionary)->Dictionary:
	var result:Dictionary=value.duplicate(true)
	for key:String in ["previous_altitude_s64","altitude_s64"]:
		result[key]=str(result[key+"_hex"]).hex_decode().decode_s64(0)
		result.erase(key+"_hex")
	return result

func chain_input(value:Dictionary)->Dictionary:
	return {"relative_position_s64":exact_vector(str(value.relative_position_s64_hex)),"globals":chain_globals(value.globals),"body_descriptor":str(value.body_descriptor_hex).hex_decode(),"parent_descriptor":str(value.parent_descriptor_hex).hex_decode(),"body_spec":str(value.body_spec_hex).hex_decode()}

func observed_damage_callbacks(callbacks:Array)->Array:
	var result:Array=[]
	for callback:Dictionary in callbacks:
		if callback.function=="F953":result.append([953,int(callback.amount_s32)&0xffffffff,int(callback.attacker_u32),0])
	return result

func native_chain()->void:
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(CHAIN_FIXTURE))
	check(fixture is Dictionary and fixture.get("executable_sha256")==Core.SOURCE_SHA,"Coupled sphere reference identifies the uploaded DOS executable")
	if not fixture is Dictionary:return
	var execution:Dictionary=fixture.execution_checks
	check(execution.fresh_identical_processes==3 and execution.reverse_case_order_identical and execution.raw338_parent_descriptor_spec_output_canaries and execution.unrelated_body_bytes_unchanged and execution.parent_descriptors_specs_unchanged and not execution.expected_source_transitions_computed_by_python,"Three independent native processes, reversed order and guarded object/resource buffers agree")
	var proofs:Dictionary=fixture.byte_instruction_proofs
	check(proofs.size()==25 and proofs.has("575") and proofs.has("577") and proofs["575"].byte_length==2005 and proofs["575"].instruction_count==635 and proofs["577"].byte_length==363 and proofs["577"].instruction_count==128,"Full original F575 and F577 bytes anchor the bounded supported execution paths")
	for name:String in proofs:check(proofs[name].all_instructions_equal_after_branch_destination_normalization,"Instruction-matched coupled native scope "+name)
	var supported:=0;var guarded:=0
	for sample:Dictionary in fixture.cases:
		var expected:Dictionary=sample.expected
		var body:=str(sample.body_hex).hex_decode();var parent:=str(sample.parent_hex).hex_decode();var context:=chain_input(sample.context)
		var label:=str(sample.id)
		var result:Dictionary={};var calls:Array=[];var callbacks:Array=[];var classifier_calls:=0
		for iteration in range(int(sample.repeat_count)):
			var original:=var_to_bytes([body,parent,context])
			result=Pipeline.resolve_player(body,parent,context)
			check(var_to_bytes([body,parent,context])==original,label+" no caller buffer or source-state mutation")
			if not result.ok:break
			classifier_calls+=1 if result.classification_applied else 0
			calls.append_array(result.damage_calls);callbacks.append_array(result.callbacks)
			body=result.body_after;context.globals=result.globals_after
			context.relative_position_s64=result.absolute_position_s64
		check(result.ok==expected.get("ok",true),label+" supported or explicitly unsupported raw route")
		if not result.ok:
			guarded+=1
			check(result.body_after==body and result.parent_after==parent and equal_words(result.globals_after,context.globals) and result.damage_calls.is_empty() and result.callbacks.is_empty(),label+" unsupported provider/pair is rolled back atomically")
			check(result.error==str(expected.error),label+" unsupported domain is named rather than treated as harmless geometry")
			continue
		supported+=1
		if chain_body.is_empty():chain_body=str(sample.body_hex).hex_decode();chain_parent=parent.duplicate();chain_context=chain_input(sample.context)
		check(result.body_after==str(expected.body_hex).hex_decode(),label+" full338-byte native player result")
		check(result.parent_after==str(expected.parent_hex).hex_decode() and result.parent_after==parent,label+" unchanged native parent")
		check(equal_words(result.globals_after,chain_globals(expected.globals)),label+" exact native kind, flags, collider identity and both64-bit altitude fields")
		check(result.absolute_position_s64==exact_vector(str(expected.relative_after_hex)),label+" F1664 wrapped absolute vector is returned from the original caller path")
		check(int(result.return_flags_u8)==int(expected.return_flags_u8),label+" only the defined source AL return byte is compared")
		check(result.branch==str(expected.branch) and result.response_applied==bool(expected.response_applied) and result.classification_applied==bool(expected.classification_applied),label+" original coarse/classifier/parent-response routing")
		check(classifier_calls==int(expected.F577_calls),label+" original aggregate F577 invocation count")
		check(result.landing_accepted==bool(expected.landing_accepted),label+" accepted landing is observed only after terminal response")
		check(equal_words(calls,expected.damage_calls) and equal_words(observed_damage_callbacks(callbacks),expected.callbacks_raw_u32),label+" exact source F953 request sequence without applying HP twice")
		var domain:=str(sample.get("domain",sample.get("input_domain","unknown")))
		chain_domains[domain]=int(chain_domains.get(domain,0))+1
		chain_branches[result.branch]=int(chain_branches.get(result.branch,0))+1
	check(chain_branches.has("coarse_rejected") and chain_branches.has("sphere_external_or_equal") and chain_branches.has("simple_parent_player_response"),"Native controls cover all three supported caller paths")
	check(supported==207 and guarded==6 and supported+guarded==int(fixture.case_count),"207 supported original source paths stay separate from six intercepted native paths with host rollback policy")
	check(int(fixture.supported_case_count)==supported and int(fixture.unsupported_guard_case_count)==guarded and not fixture.complete_original_F575_behavior and not fixture.F576_F578_engine_executed and not fixture.full_F569_scanner,"Native metadata excludes unsupported response engines and the full object scanner")
	check(fixture.independent_literal_controls.size()==9,"Nine independent literal controls anchor the coupled source behavior")
	for control:Dictionary in fixture.independent_literal_controls:check(control.passed and equal_words(control.observed,control.literal_expected),"Independent coupled literal canary "+str(control.name))
	chain_evidence.append({"native_case_count":fixture.case_count,"supported_native_cases":supported,"intercepted_native_paths_with_host_rollback_guards":guarded,"domains":chain_domains.duplicate(true),"branches":chain_branches.duplicate(true),"execution_checks":fixture.get("execution_checks",{}),"byte_instruction_proofs":fixture.get("byte_instruction_proofs",{}),"scope":fixture.get("scope",""),"exact64_policy":"Decode little-endian raw64 hex; JSON decimal previews never provide machine values.","adapter_rollback_is_native_response":false})

func reject_chain(body:PackedByteArray,parent:PackedByteArray,context:Dictionary,label:String)->void:
	var before:=var_to_bytes([body,parent,context]);var result:=Pipeline.resolve_player(body,parent,context)
	check(not result.ok and result.body_after==body and result.parent_after==parent and result.damage_calls.is_empty() and result.callbacks.is_empty(),label+" rejects without partial effects")
	check(var_to_bytes([body,parent,context])==before,label+" preserves caller inputs")

func pipeline_guards()->void:
	if chain_body.is_empty():return
	for size_value:int in [0,337,339]:
		var body:=chain_body.duplicate();body.resize(size_value);reject_chain(body,chain_parent,chain_context,"Malformed player size"+str(size_value))
		var parent:=chain_parent.duplicate();parent.resize(size_value);reject_chain(chain_body,parent,chain_context,"Malformed parent size"+str(size_value))
	for key:String in ["body_descriptor","parent_descriptor","body_spec","relative_position_s64","globals"]:
		var context:=chain_context.duplicate(true);context.erase(key);reject_chain(chain_body,chain_parent,context,"Missing context "+key)
	for key:String in Pipeline.Response.GLOBAL_KEYS+["altitude_s64"]:
		var context:=chain_context.duplicate(true);context.globals.erase(key);reject_chain(chain_body,chain_parent,context,"Missing raw global "+key)
	for value:Variant in [0.5,"0",true,INF]:
		var context:=chain_context.duplicate(true);context.globals.altitude_s64=value;reject_chain(chain_body,chain_parent,context,"Noninteger exact altitude "+str(value))
	var context:=chain_context.duplicate(true);context.globals["metadata"]={"values":[1]}
	var result:=Pipeline.resolve_player(chain_body,chain_parent,context)
	check(result.ok and result.source_contract==Pipeline.CONTRACT and not result.full_f569 and not result.full_f575 and not result.object_bank_traversed,"Composed raw API declares its bounded source scope")
	result.globals_after.metadata.values[0]=2
	check(context.globals.metadata.values==[1],"Returned route metadata is deeply isolated")

func run()->void:
	native_chain();pipeline_guards()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CHAIN_REPORT.get_base_dir()))
	var file:=FileAccess.open(CHAIN_REPORT,FileAccess.WRITE)
	var sources:={}
	for path:String in ["scripts/source_spherical_contact_pipeline.gd","scripts/source_spherical_contact.gd","scripts/source_surface_contact.gd","tests/test_source_spherical_contact_pipeline.gd","tests/fixtures/source_spherical_contact_pipeline_native.json","tools/rebuild_source_spherical_contact_native.py"]:sources[path]=FileAccess.get_sha256("res://"+path)
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"evidence":chain_evidence,"sources":sources,"scope":"Bounded raw player/simple-parent F575 caller: original coarse test, full F577 and unchanged terminal response. Unsupported F576/F578 is an explicit atomic host guard. No live World bank/frame dispatch or HP application."},"\t"));file.close()
	print("Source spherical pipeline: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
