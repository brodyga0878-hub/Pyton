extends SceneTree
const Effect=preload("res://scripts/source_effect_factory.gd")
const Factory=preload("res://scripts/source_object_factory.gd")
const FIXTURE:="res://tests/fixtures/source_effect_factory_native.json"
const FIXTURE_SHA:="1369d7a33befecd244c3d3cb1b3becd89dcfeea881e90e325971481ccb2c13c1"
const REPORT:="res://build/current-test-reports/source-effect-factory.json"
const PROOF:="res://validation/equipment-effects-2026-11-18/factory-native-proof/"
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<20:push_error(message)
func digest(value:Variant)->String:return var_to_bytes(value).hex_encode().sha256_text()
func native_controls(fixture:Dictionary)->void:
	check(fixture.schema=="starfrontier-effect-factory-native-v1" and fixture.profile==Effect.PROFILE and int(fixture.case_count)==fixture.cases.size() and int(fixture.case_count)==616,"Independent original effect factory corpus and profile remain pinned")
	check(Effect._indices(fixture.selected_real_model_indices,[153,155]) and Effect._indices(fixture.null_model_indices,[149]),"Selected original models do not invent a full model inventory or accept null149")
	check(int(fixture.fresh_process_runs)==3 and int(fixture.reverse_repeat_cases)==616 and int(fixture.consecutive_original_steps)==24 and int(fixture.all_type87_values_per_selected_model)==256 and fixture.all_readonly_inputs_and_canaries_unchanged and not fixture.expected_arithmetic_calculated_in_python,"Source controls include actual fresh processes, reverse order, dependent calls and byte-domain type controls")
	check(FileAccess.get_sha256(PROOF+"instruction-proof.json")==fixture.instruction_proof_sha256 and FileAccess.get_sha256(PROOF+"source-procedures.asm")==fixture.source_procedures_sha256 and FileAccess.get_sha256(PROOF+"factory-native.s")==fixture.host_adapted_assembly_sha256,"Original instruction capture and documented host adapter match native fixture")
	for path:String in fixture.source_dependencies_sha256:check(FileAccess.get_sha256("res://"+path)==fixture.source_dependencies_sha256[path],"Native source dependency pinned: "+path)
	var kinds:Dictionary={153:{},155:{}};var carried:=0;var previous:=str(fixture.cases[0].expected_body_hex)
	for row:Dictionary in fixture.cases:
		var body:=str(row.before_body_hex).hex_decode();var source:=str(row.source_body_hex).hex_decode();var frozen:=digest([body,source,row.resources,row.clock])
		var actual:=Effect.initialize_context(body,source,row.model_index_u32,row.clock,row.resources,row.copy_source)
		check(actual.ok,"Actual F1533 effect result exists: "+str(row.name))
		if not actual.ok:continue
		check(actual.body_after.hex_encode()==row.expected_body_hex,"Every destination byte equals true original model-token execution: "+str(row.name))
		check(actual.copy_performed==(int(row.copy_calls)==1) and actual.descriptor_initialized==(int(row.lookup_calls)==1),"Actual original copy and lookup branches match: "+str(row.name))
		check(digest([body,source,row.resources,row.clock])==frozen and source.hex_encode()==row.expected_source_body_hex,"Input templates, immutable resources and clocks remain unchanged: "+str(row.name))
		check(not actual.object_allocated and not actual.source_clock_advanced and not actual.full_explosion_or_debris_engine and not actual.full_special_model_inventory and not actual.pose_seeded_from_SI and not actual.type87_assigned,"Factory does not claim allocation, rendering, invented pose or type")
		var selected:PackedByteArray=source if row.copy_source else body
		check(actual.body_after[0x87]==selected[0x87] and actual.body_after.slice(0,0x24)==selected.slice(0,0x24) and actual.body_after.slice(0xec,0xf2)==selected.slice(0xec,0xf2),"Actual template attitude, angular words and type are preserved")
		if int(row.model_index_u32) in [153,155]:
			check(actual.body_after.decode_u32(0x82)==int(row.model_index_u32) and actual.additional_resource_adapter_used,"Additional model keeps its true source index after descriptor-parametric initialization")
			if str(row.name).contains("-type87-"):kinds[int(row.model_index_u32)][int(selected[0x87])]=true
		if row.has("input_provenance"):
			check(str(row.before_body_hex)==previous and str(row.source_body_hex)==previous,"Dependent input carries the previous entire original output")
			previous=str(row.expected_body_hex);carried+=1
	check(kinds[153].size()==256 and kinds[155].size()==256 and carried==24,"Both actual special models retain all type bytes and all dependent source calls")
func resources_and_bounds()->void:
	for model in range(149):check(Effect.source_model(model)==Factory.source_model(model),"Existing factory catalog remains byte exact for model"+str(model))
	for model in [153,155]:
		var resource:=Effect.source_model(model)
		check(Factory._resources(resource),"Captured additional model has complete original factory resources")
		var before:=digest(resource);var copy:=Effect.source_model(model);copy.descriptor_hex="changed";copy.drive_mass_table_u32[0]=9
		check(digest(Effect.source_model(model))==before,"Returned resource edits cannot mutate the cached original catalog")
	var cargo:=Effect.source_model(153);var explosion:=Effect.source_model(155)
	check(cargo.collision_present and int(cargo.collision_first_byte_u8)==16 and str(cargo.physical_spec_hex).length()==48,"Original cargo model has actual collision and physical records")
	check(explosion.collision_present and int(explosion.collision_first_byte_u8)==0 and explosion.physical_spec_hex=="","Original explosion model has an empty collision program and no physical spec")
	var body:=PackedByteArray();body.resize(338);body[0x86]=114;body[0x87]=3
	var source:=body.duplicate();source[0x87]=11;var clock:={"tick_u32":0xffffffff,"day_u32":0x121cf7};var frozen:=digest([body,source,clock])
	for model in [149,150,151,152,154,156,177,0xffffffff,-1,0x100000000,true,null,NAN,INF,0.5,"153"]:
		check(Effect.source_model(model).is_empty() and not Effect.initialize_context(body,source,model,clock,cargo).ok,"Uncaptured, null or malformed model index rejects atomically")
	for bad:Variant in [null,true,0,"body",[],{},PackedByteArray()]:check(not Effect.initialize_raw(bad,source,153,clock).ok,"Malformed destination rejects")
	for bad:Variant in [null,true,0,"source",[],{},PackedByteArray()]:check(not Effect.initialize_raw(body,bad,155,clock).ok,"Malformed source rejects")
	for bad:Variant in [null,true,0,[],{},PackedByteArray()]:check(not Effect.initialize_context(body,source,153,clock,bad).ok,"Malformed explicit resource rejects")
	for bad:Variant in [{"tick_u32":-1,"day_u32":0},{"tick_u32":0,"day_u32":0x100000000},{"tick_u32":0,"day_u32":0,"duplicate":0},true,null]:check(not Effect.initialize_raw(body,source,153,bad).ok,"Clock state requires exactly two source words")
	for bad:Variant in [null,0,1,"true",[]]:check(not Effect.initialize_raw(body,source,153,clock,bad).ok,"Logical copy identity is a boolean")
	check(digest([body,source,clock])==frozen,"All rejects preserve the caller input records")
	var copied:=Effect.initialize_raw(body,source,155,clock,true);var inplace:=Effect.initialize_in_place(body,155,clock)
	check(copied.ok and inplace.ok and copied.body_after[0x87]==11 and inplace.body_after[0x87]==3,"Raw and in-place entry preserve the actual source identity policy")
	if copied.ok:
		copied.body_after[0]=99;check(digest([body,source,clock])==frozen,"Returned output cannot mutate caller records")
func run()->void:
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent original effect fixture is immutable")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	native_controls(fixture);resources_and_bounds()
	var sources:Dictionary={}
	for path:String in ["scripts/source_effect_factory.gd","scripts/source_object_factory.gd","scripts/source_orbit.gd","tests/test_source_effect_factory.gd","tests/fixtures/source_effect_factory_native.json","data/ffe_effect_factory.json","data/ffe_object_factory.json","tools/rebuild_source_effect_factory_native.py","validation/equipment-effects-2026-11-18/factory-native-proof/instruction-proof.json","validation/equipment-effects-2026-11-18/factory-native-proof/resource-spans.json","validation/equipment-effects-2026-11-18/factory-native-proof/source-procedures.asm","validation/equipment-effects-2026-11-18/factory-native-proof/factory-native.s"]:sources[path]=FileAccess.get_sha256("res://"+path)
	for path:String in fixture.source_dependencies_sha256:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"profile":Effect.PROFILE,"checks":checks,"failures":failures,"native_cases":int(fixture.case_count),"sources":sources,"full_special_model_inventory":false,"Main_integrated":false,"physical_device_tested":false},"\t"));file.close()
	print("SOURCE EFFECT FACTORY TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
