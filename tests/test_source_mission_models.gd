extends SceneTree
const Models=preload("res://scripts/source_mission_models.gd")
const Factory=preload("res://scripts/source_object_factory.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_model_replace_native.json"
const REPORT:="res://build/current-test-reports/source-mission-models.json"
const FIXTURE_SHA:="c6245738954bc22825b1d6650a75582bf02b34efc050225d3e48e7dd7b92a79f"
var checks:=0
var failures:=0
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	var catalog:=Models.load_original()
	check(not catalog.is_empty() and Models.validate_catalog(catalog),"Pinned original catalog validates")
	if catalog.is_empty():finish({});return
	check(catalog.model_count==466 and catalog.nonnull_model_count==465 and catalog.null_model_indices_u32.size()==1 and int(catalog.null_model_indices_u32[0])==149,"Actual independently bound table contains466slots andoneNULL")
	check(catalog.model_table_original_va_u32==0x4d0cfc and catalog.adjacent_string_table_original_va_u32==0x4d1444,"Two independent source operands bind the catalog extent")
	check(catalog.captured_span_count==1016 and catalog.captured_bytes==36025,"All exact source replacement spans retained")
	for index in range(466):
		var result:=Models.lookup(index)
		check(result.get("ok",false) and result.pointer_return_defined,"F1538 lookup admitted: %d"%index)
		if index==149:
			check(result.pointer_is_null and result.resource.is_empty() and Models.source_model(index).is_empty(),"Original model149 preserves NULL independently of valid model0")
		else:
			var source:=Models.source_model(index)
			check(not result.pointer_is_null and Models.validate_model(source),"Full actual model resource available: %d"%index)
			check(source.descriptor_hex==catalog.models[str(index)].descriptor_hex and source.physical_spec_hex==catalog.models[str(index)].physical_spec_hex,"Loader retains exact descriptor and optional physical bytes: %d"%index)
			check(source.drive_mass_table_u32==Models.DRIVE_MASSES,"Every admitted model uses the exact shared15word drive resource: %d"%index)
			if index<149:check(Clock._hash(source)==Clock._hash(Factory.source_model(index)),"Existing factory input projection stays exact: %d"%index)
	var original:=Models.source_model(38);var changed:=Models.source_model(38);changed.descriptor_hex="00".repeat(68);changed.drive_mass_table_u32[0]=99
	check(Models.source_model(38)==original,"Returned model projections cannot mutate cached catalog ownership")
	var wrong:=catalog.duplicate(true);wrong.models["38"].descriptor_hex="00".repeat(68)
	check(not Models.validate_catalog(wrong),"A forged descriptor cannot retain the catalog tag")
	wrong=catalog.duplicate(true);wrong.model_count=467
	check(not Models.validate_catalog(wrong),"An invented catalog extent is rejected")
	var cycle:Dictionary={"schema":"starfrontier-original-mission-model-resources-v1"};cycle["cycle"]=cycle
	check(not Models.validate_catalog(cycle),"Cyclic forged catalogs reject before canonical hashing");cycle.clear()
	for invalid:Variant in [-1,149,466,0xffffffff,1.5,true,null,{},[]]:
		var body:=PackedByteArray();body.resize(338)
		check(not Models.replace(body,invalid).get("ok",false),"Invalid replacement target rejects safely: "+str(invalid))
	for invalid:Variant in [-1,466,0xffffffff,1.5,true,null,{},[]]:check(not Models.lookup(invalid).get("ok",false),"Invalid lookup index rejects safely")
	var body:=PackedByteArray();body.resize(338);body.fill(0xa5)
	for invalid:Variant in [null,[],{},"",PackedByteArray()]:check(not Models.replace(invalid,38).get("ok",false),"Malformed raw body rejects before writes")
	for field:String in Models.RESOURCE_KEYS:
		var bad:Dictionary=original.duplicate(true);bad.erase(field)
		check(not Models.replace(body,38,bad).get("ok",false),"Missing resource field rejects: "+field)
	var bad:=original.duplicate(true);bad.drive_mass_table_u32[14]=1
	check(not Models.replace(body,38,bad).get("ok",false),"Unproved drive-table substitution rejects")
	bad=original.duplicate(true);var physical:PackedByteArray=str(bad.physical_spec_hex).hex_decode();physical.encode_u16(20,0xffff);bad.physical_spec_hex=physical.hex_encode()
	check(not Models.replace(body,38,bad).get("ok",false),"Negative default drive outside the original15words rejects")
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture is Dictionary and FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Native fixture is the reviewed exact corpus")
	if not fixture is Dictionary:finish({});return
	check(fixture.case_count==566 and fixture.cases.size()==566 and fixture.original_model_count==465,"All actual non-null models and boundary controls are present")
	check(fixture.fresh_process_runs==3 and fixture.reverse_repeat_cases==566 and fixture.dependent_original_replacements==32,"Fresh/reverse/dependent source controls are explicit")
	check(fixture.native_fault_domains_separate.size()==1 and fixture.native_fault_domains_separate[0].actual_native_signal=="SIGSEGV","Actual model149NULL dereference is measured separately from normal results")
	check(not fixture.native_fault_domains_separate[0].normal_case_count_includes_fault and not fixture.native_fault_domains_separate[0].after_body_claimed,"A source fault never contributes a fabricated after-state or normal control")
	for row:Dictionary in fixture.cases:
		var input:PackedByteArray=str(row.before_body_hex).hex_decode();var before:=input.duplicate();var resource:Dictionary=row.resource.duplicate(true);var resource_hash:=Clock._hash(resource)
		if row.operation=="F36":
			var result:=Models.replace(input,row.model_index_u32,resource)
			check(result.get("ok",false),"Original F36 case completes: "+row.name)
			if not result.get("ok",false):continue
			check(result.body_after==str(row.expected_body_hex).hex_decode(),"Every338bodybyte matches independently executed original: "+row.name)
			check(result.void_return_register_ignored and not result.return_defined and not result.F1533_substituted,"F36 never fabricates a scalar return or invokes the factory: "+row.name)
			check(not result.object_allocated and not result.source_clock_advanced and not result.Main_integrated,"Replacement scope remains isolated: "+row.name)
			check(input==before and Clock._hash(resource)==resource_hash,"Input body and readonly resource witness stay untouched: "+row.name)
		else:
			var result:=Models.lookup(row.model_index_u32)
			check(result.get("ok",false) and result.pointer_is_null==not bool(row.pointer_is_nonnull),"F1538 normalized pointer result matches original: "+row.name)
			check(row.expected_body_hex==row.before_body_hex,"Lookup-only native path leaves body untouched")
	finish(fixture)
func finish(fixture:Dictionary)->void:
	var sources:Dictionary={}
	for path:String in ["scripts/source_mission_models.gd","scripts/source_object_factory.gd","scripts/source_orbit.gd","scripts/source_frame_dispatch.gd","scripts/source_clock_pipeline.gd","tests/test_source_mission_models.gd","tests/fixtures/source_model_replace_native.json","tools/rebuild_source_model_replace_native.py","tools/extract_source_mission_models.py","data/ffe_mission_models.json","validation/mission-tasks-2026-11-19/model-native-proof/instruction-proof.json","validation/mission-tasks-2026-11-19/model-native-proof/source-procedures.asm","validation/mission-tasks-2026-11-19/model-native-proof/model-replace-native.s","validation/mission-tasks-2026-11-19/model-resources/original-spans.json"]:sources[path]=FileAccess.get_sha256("res://"+path)
	for path:String in fixture.get("source_dependencies_sha256",{}):
		sources[path]=FileAccess.get_sha256("res://"+path)
		check(sources[path]==fixture.source_dependencies_sha256[path],"Native dependency remains current: "+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"profile":Models.PROFILE,"checks":checks,"failures":failures,"native_cases":fixture.get("case_count",0),"source_model_slots":466,"actual_nonnull_models":465,"sources":sources,"Main_integrated":false},"\t")+"\n");file.close()
	print("MISSION MODEL TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
