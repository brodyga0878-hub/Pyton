extends SceneTree
const Destruction=preload("res://scripts/source_destruction.gd")
const Factory=preload("res://scripts/source_effect_factory.gd")
const FIXTURE:="res://tests/fixtures/source_destruction_native.json"
const FIXTURE_SHA:="988b08fd107de2564f0cb2c30cf81c5a22b8c2b2cb324211740004f74661ca48"
const PROOF:="res://validation/equipment-effects-2026-11-18/destruction-native-proof/"
const REPORT:="res://build/current-test-reports/source-destruction.json"
var checks:=0
var failures:=0
var pool:Dictionary={}
var cache:Dictionary={}
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<20:push_error(message)
func bytes(reference:String)->PackedByteArray:
	if cache.has(reference):return cache[reference].duplicate()
	var entry:Dictionary=pool[reference];var result:=Marshalls.base64_to_raw(entry.zlib_base64).decompress(int(entry.byte_count),FileAccess.COMPRESSION_DEFLATE)
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(result)
	check(result.size()==int(entry.byte_count) and h.finish().hex_encode()==reference,"Native owner buffer exact length and SHA")
	cache[reference]=result.duplicate();return result
func context(value:Dictionary)->Dictionary:
	var out:=value.duplicate(true)
	for key:String in ["root","bank","module_entries"]:out[key]=bytes(str(out[key]))
	return out
func observations(value:Array)->Array:
	var out:Array=value.duplicate(true)
	for row:Dictionary in out:row.before=context(row.before);row.after=context(row.after)
	return out
func json_value(value:Variant)->Variant:
	if value is PackedByteArray:return value.hex_encode()
	if value is Dictionary:
		var out:Dictionary={}
		for key:Variant in value:out[key]=json_value(value[key])
		return out
	if value is Array:
		var out:Array=[]
		for v:Variant in value:out.append(json_value(v))
		return out
	return value
func _initialize()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));pool=fixture.buffers
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent native fixture byte identity pinned")
	check(int(fixture.case_count)==fixture.cases.size() and fixture.cases.size()>=100,"Independent whole native destruction controls present")
	check(int(fixture.fresh_process_runs)==3 and int(fixture.reverse_repeat_cases)==fixture.cases.size() and not fixture.expected_arithmetic_calculated_in_python,"Original source calculations and independent process repeats")
	check(str(fixture.cargo_table_hex)==PackedByteArray(Destruction.CARGO_ITEMS).hex_encode(),"Original captured cargo32table exact")
	check(int(fixture.whole_original_procedures)==16 and int(fixture.whole_original_instructions)==872 and int(fixture.consecutive_native_steps)==12,"Complete original instruction closure and dependent owner steps")
	check(fixture.all_owner_boundary_canaries_unchanged and fixture.all_readonly_input_resource_bytes_unchanged,"Native owner guards and readonly resources preserved")
	for pair:Array in [["instruction-proof.json","instruction_proof_sha256"],["source-procedures.asm","source_procedures_sha256"],["destruction-native.s","host_assembly_sha256"],["destruction-support.c","host_support_sha256"]]:check(FileAccess.get_sha256(PROOF+pair[0])==str(fixture[pair[1]]),"Captured source/host proof pinned: "+str(pair[0]))
	for path:String in fixture.source_dependencies_sha256:check(FileAccess.get_sha256("res://"+path)==fixture.source_dependencies_sha256[path],"Native source dependency "+path)
	var total_cargo:=0;var allocations:=0;var matrices:=0;var releases:=0;var position_edges:=0;var active_cargo:=0
	for row:Dictionary in fixture.cases:
		var before:=context(row.context_before);var replies:=observations(row.observations);var frozen:=var_to_bytes([before,replies])
		var result:=Destruction.execute(before,row.body_slot_u32,row.attacker_u32,replies)
		check(result.ok,"Whole source F942 accepted native case: "+str(row.name))
		if not result.ok:
			if failures<20:print(result)
			continue
		var expected:=context(row.expected.context_after)
		check(Destruction._same_context(result.context_after,expected),"All native Root/bank/module/counters equal: "+str(row.name))
		check(int(result.return_u32)==int(row.expected.return_u32),"Source zero F942 return: "+str(row.name))
		check(result.source_order==row.expected.source_order,"Original nested call order: "+str(row.name))
		check(var_to_bytes([before,replies])==frozen,"Input owners unchanged: "+str(row.name))
		check(int(result.observations_used)==replies.size() and result.requests.size()==replies.size(),"All exact external replies consumed: "+str(row.name))
		check(result.source_order.count("F1530")+result.source_order.count("F922")==int(result.rng_calls_u32),"Shared Root RNG calls exact")
		total_cargo+=int(result.cargo_calls_u32);matrices+=1 if result.F1675_body_executed else 0;releases+=1 if result.F924_body_executed else 0
		allocations+=result.source_order.count("F1514")
		if row.has("position_boundary_words"):
			position_edges+=1;check(result.source_order.count("F1514")>0,"Actual source displacement executes on directed low-word carry/signed64 edge")
		for i in range(1,115):
			if int(result.context_after.bank[i])!=0 and result.context_after.bank.decode_u32(116+i*338+0x82)==153:active_cargo+=1
		if not replies.is_empty():
			var pending:=Destruction.execute(before,row.body_slot_u32,row.attacker_u32,[])
			check(not pending.ok and pending.get("pending") is Dictionary and pending.pending.kind==replies[0].kind,"Missing provider returns exact pending without implicit success")
		if row==fixture.cases[0]:
			var cold_ctx:=Destruction.decode_context(JSON.parse_string(JSON.stringify(json_value(before))));var cold_replies:Variant=Destruction.decode_observations(JSON.parse_string(JSON.stringify(json_value(replies))))
			check(not cold_ctx.is_empty() and cold_replies is Array and Destruction.execute(cold_ctx,row.body_slot_u32,row.attacker_u32,cold_replies).ok,"Lossless cold contexts and typed callback observations replay")
	check(total_cargo>0 and matrices>0 and releases==fixture.cases.size(),"Actual cargo, matrix, allocation and release paths covered")
	check(allocations==int(fixture.actual_cargo_allocations) and allocations>0 and active_cargo>0,"Original F926 creates actual active cargo153 records, not merely attempts")
	check(total_cargo==int(fixture.actual_F926_attempts) and matrices==int(fixture.actual_explosion_matrices) and position_edges==6,"Measured native branch/call coverage retained")
	var raw:=context(fixture.cases[0].context_before);var original:=var_to_bytes(raw)
	for bad:Variant in [null,true,0,[],{},PackedByteArray()]:check(not Destruction.execute(bad,0,0).ok,"Invalid context rejects")
	for bad:Variant in [-1,115,true,0.5,NAN,INF,"0",null]:check(not Destruction.execute(raw,bad,0).ok,"Invalid physical body slot rejects")
	for bad:Variant in [-1,0x100000000,true,0.5,NAN,INF,"0",null]:check(not Destruction.execute(raw,0,bad).ok,"Invalid attacker word rejects")
	for key:String in Destruction.KEYS:
		var invalid:=raw.duplicate(true);invalid.erase(key);check(not Destruction.execute(invalid,0,0).ok,"Missing owner rejects: "+key)
	var invalid:=raw.duplicate(true);invalid.model_resources["149"]=Factory.source_model(153);check(not Destruction.execute(invalid,0,0).ok,"Uncaptured actual NULL149 resource rejects")
	invalid=raw.duplicate(true);invalid.model_resources["153"].drive_mass_table_u32[1]=5;check(not Destruction.execute(invalid,0,0).ok,"A second incompatible global drive table rejects")
	check(var_to_bytes(raw)==original,"Rejected controls preserve caller owners")
	var sources:Dictionary={}
	for path:String in ["scripts/source_destruction.gd","scripts/source_effect_factory.gd","scripts/source_object_factory.gd","scripts/source_global_rng.gd","scripts/body_rotation.gd","scripts/ground_coordinates.gd","scripts/source_damage.gd","tests/test_source_destruction.gd","tests/fixtures/source_destruction_native.json"]:sources[path]=FileAccess.get_sha256("res://"+path)
	for path:String in fixture.source_dependencies_sha256:sources[path]=FileAccess.get_sha256("res://"+path)
	for name:String in ["instruction-proof.json","source-procedures.asm","destruction-native.s","destruction-support.c"]:sources[PROOF.trim_prefix("res://")+name]=FileAccess.get_sha256(PROOF+name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"profile":Destruction.PROFILE,"checks":checks,"failures":failures,"native_cases":fixture.cases.size(),"actual_cargo_attempts":total_cargo,"actual_cargo_allocations":allocations,"actual_matrices":matrices,"sources":sources,"Main_integrated":false,"full_UI_or_module_handler_engine":false},"\t"));file.close()
	print("SOURCE DESTRUCTION TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
