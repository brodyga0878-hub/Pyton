extends SceneTree
const Factory=preload("res://scripts/source_object_factory.gd")
const FIXTURE:="res://tests/fixtures/source_object_factory_native.json"
const FIXTURE_SHA:="0c04db1aec7ad72125599848125eab9dde1c9d32a87b0b2e732de576403ede92"
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<20:push_error(message)
func digest(value:Variant)->String:return var_to_bytes(value).hex_encode().sha256_text()
func run()->void:
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent original factory control bank remains pinned")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.schema=="starfrontier-source-object-factory-native-v1" and fixture.case_count==650 and fixture.cases.size()==650,"Whole raw factory bank includes all650 original cases")
	check(fixture.real_model_count==149 and fixture.fresh_process_runs==3 and fixture.reverse_repeat_cases==650 and fixture.consecutive_original_steps==32 and fixture.all_type87_byte_values_preserved==256 and fixture.all_body_source_resource_canaries_unchanged and not fixture.expected_arithmetic_calculated_in_python,"Independent whole-instruction executions cover actual resources, source sequences and immutable boundaries")
	var types:Dictionary={};var real_models:Dictionary={};var previous:Dictionary={}
	for row:Dictionary in fixture.cases:
		var body:=str(row.before_body_hex).hex_decode();var source:=str(row.source_body_hex).hex_decode();var frozen:=digest([body,source,row.resources,row.clock])
		var result:=Factory.initialize_context(body,source,row.model_index_u32,row.clock,row.resources,row.copy_source)
		check(result.ok,"Raw original factory result exists: "+str(row.name))
		if not result.ok:continue
		check(result.body_after.hex_encode()==row.expected_body_hex,"All338 destination bytes match actual DOS instructions: "+str(row.name))
		check(result.copy_performed==(int(row.copy_calls)==1) and result.descriptor_initialized==(int(row.lookup_calls)==1),"Observed native copy/descriptor branches are retained: "+str(row.name))
		check(digest([body,source,row.resources,row.clock])==frozen and source.hex_encode()==row.expected_source_body_hex,"Caller body, source, logical references and clocks remain private: "+str(row.name))
		check(not result.object_allocated and not result.full_original_player_factory and not result.pose_seeded_from_SI and not result.type87_assigned and not result.source_clock_advanced,"Raw initialization does not claim source allocation, invented type/pose or a consumed interval")
		var selected:PackedByteArray=source if row.copy_source else body
		check(int(result.body_after[0x87])==int(selected[0x87]) and result.body_after.slice(0,0x24)==selected.slice(0,0x24) and result.body_after.slice(0xec,0xf2)==selected.slice(0xec,0xf2) and result.body_after.slice(0xb0,0xb6)==selected.slice(0xb0,0xb6),"Type, Q31 attitude, Q16 velocity and signed16 angular residues are never synthesized")
		if str(row.name).begins_with("real-model"):
			real_models[int(row.model_index_u32)]=true
			var from_registry:=Factory.initialize_raw(body,source,row.model_index_u32,row.clock,row.copy_source)
			check(from_registry.ok and from_registry.body_after==result.body_after,"Pinned original model resource produces the identical full raw object")
		if str(row.name).begins_with("all-type87"):
			types[int(result.body_after[0x87])]=true
		if str(row.name).begins_with("consecutive-native"):
			var saved:Dictionary=JSON.parse_string(JSON.stringify({"body_hex":row.before_body_hex,"source_hex":row.source_body_hex,"clock":row.clock,"model":row.model_index_u32,"copy":row.copy_source}))
			var cold:=Factory.initialize_raw(str(saved.body_hex).hex_decode(),str(saved.source_hex).hex_decode(),saved.model,saved.clock,saved.copy)
			check(cold.ok and cold.body_after.hex_encode()==row.expected_body_hex,"Dependent source initialization survives an exact raw JSON boundary")
			if not previous.is_empty():check(previous.expected_body_hex==row.before_body_hex,"Next source initialization starts at the previous actual native338-byte output")
			previous=row
	check(real_models.size()==149 and types.size()==256,"Every actual descriptor and every possible caller-owned type87 byte is covered")
	var zero:Dictionary=fixture.cases[1];var dest:=str(zero.before_body_hex).hex_decode();var src:=str(zero.source_body_hex).hex_decode()
	var zero_result:=Factory.initialize_context(dest,src,0,zero.clock,{},true)
	check(zero_result.ok and zero_result.body_after.hex_encode()==zero.expected_body_hex,"Model0 copy does not read descriptor/specification references")
	var in_place:=Factory.initialize_context(dest,src,0,zero.clock,{},false)
	check(in_place.ok and in_place.body_after==dest,"Model0 in-place leaves the exact caller object unchanged")
	var row:Dictionary=fixture.cases[77];dest=str(row.before_body_hex).hex_decode();src=str(row.source_body_hex).hex_decode()
	var resource:=Factory.source_model(38);var expected_resource:=digest(resource);resource.descriptor_hex="00".repeat(68);resource.drive_mass_table_u32[0]=1234
	check(digest(Factory.source_model(38))==expected_resource,"Returned resource maps cannot mutate the pinned model registry")
	var base_result:=Factory.initialize_raw(dest,src,38,row.clock,true);var actual:PackedByteArray=base_result.body_after;actual[0]=actual[0]^255
	check(Factory.initialize_raw(dest,src,38,row.clock,true).body_after.hex_encode()==row.expected_body_hex,"Returned output bytes cannot alter an independent factory call")
	var original:=digest([dest,src,row.clock,row.resources])
	for invalid:Variant in [null,true,1,[],{},PackedByteArray(),PackedByteArray([1,2]),"raw"]:
		check(not Factory.initialize_raw(invalid,src,38,row.clock).ok and not Factory.initialize_raw(dest,invalid,38,row.clock).ok and digest([dest,src,row.clock,row.resources])==original,"Malformed raw records reject without modifying caller owners")
	for invalid:Variant in [-1,true,1.5,149,0xffffffff,NAN,INF,"38"]:
		check(Factory.source_model(invalid).is_empty() and not Factory.initialize_raw(dest,src,invalid,row.clock).ok and digest([dest,src,row.clock,row.resources])==original,"Unsupported model identity is rejected before a table lookup")
	for invalid:Variant in [null,true,[],{},1,{"tick_u32":0},{"tick_u32":0,"day_u32":0,"extra":0},{"tick_u32":true,"day_u32":0},{"tick_u32":-1,"day_u32":0},{"tick_u32":0x100000000,"day_u32":0},{"tick_u32":0,"day_u32":NAN}]:
		check(not Factory.initialize_raw(dest,src,38,invalid).ok and digest([dest,src,row.clock,row.resources])==original,"Malformed exact raw clock rejects atomically")
	for invalid:Variant in [null,1,0,1.5,"true"]:check(not Factory.initialize_raw(dest,src,38,row.clock,invalid).ok,"Copy identity is an explicit typed caller policy")
	var bad_resources:Array=[null,true,[],{},Factory.source_model(38)]
	bad_resources[-1].extra=0
	for key:String in ["descriptor_hex","collision_present","collision_first_byte_u8","physical_spec_hex","drive_mass_table_u32"]:
		var bad:=Factory.source_model(38)
		match key:
			"descriptor_hex":bad.descriptor_hex="g".repeat(136)
			"collision_present":bad.collision_present=not bad.collision_present
			"collision_first_byte_u8":bad.collision_first_byte_u8=256
			"physical_spec_hex":bad.physical_spec_hex="00"
			"drive_mass_table_u32":bad.drive_mass_table_u32=[0]
		bad_resources.append(bad)
	var unsupported:=Factory.source_model(38);var spec:=str(unsupported.physical_spec_hex).hex_decode();spec.encode_u16(20,0x80ff);unsupported.physical_spec_hex=spec.hex_encode();bad_resources.append(unsupported)
	for invalid:Variant in bad_resources:
		check(not Factory.initialize_context(dest,src,38,row.clock,invalid,true).ok and digest([dest,src,row.clock,row.resources])==original,"Unbound pointers, malformed descriptors/specifications and out-of-table default drives reject without native dereference")
	var sources:Dictionary={}
	for path:String in ["scripts/source_object_factory.gd","scripts/source_orbit.gd","data/ffe_object_factory.json","tests/test_source_object_factory.gd","tests/fixtures/source_object_factory_native.json","tools/rebuild_source_object_factory_native.py","validation/player-dispatch-2026-11-17/factory-native-proof/instruction-proof.json","validation/player-dispatch-2026-11-17/factory-native-proof/source-procedures.s"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"))
	var file:=FileAccess.open("res://build/current-test-reports/source-object-factory.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"sources":sources,"native_cases":650,"real_source_models":149,"consecutive_original_steps":32,"type87_values_preserved":256,"profile":Factory.PROFILE,"scope":"Whole original DOS F1533/F1538/F1495/F1341 with explicit raw caller templates and pinned149 model contexts. All338-byte expected states come from independent native original arithmetic. Copy/in-place/model0/null-resource/physical-spec/default-drive domains, caller ownership and raw JSON boundary verified. No allocation, player creation, type87 assignment, SI/quaternion seeding or actual Main integration."},"\t"));file.close()
	print("SOURCE OBJECT FACTORY TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
