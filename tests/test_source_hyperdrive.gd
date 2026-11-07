extends SceneTree
# Original native procedures provide byte/register/global oracles. The higher
# level quote tests additionally exercise immutable resource/profile boundaries.
const Core=preload("res://scripts/source_hyperdrive.gd")
const FIXTURE:="res://tests/fixtures/source_hyperdrive_native.json"
var checks:=0
var failures:=0
var domains:Dictionary={}
var domain_failures:Dictionary={}
var evidence:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=40:push_error(message)
func words_equal(actual:Array,expected:Array)->bool:
	if actual.size()!=expected.size():return false
	for index in range(actual.size()):
		if (int(actual[index])&0xffffffff)!=(int(expected[index])&0xffffffff):return false
	return true
func compare_globals(actual:Dictionary,expected:Dictionary,label:String)->void:
	for key:String in expected:
		check(actual.has(key) and (int(actual.get(key,0))&0xffffffff)==(int(expected[key])&0xffffffff),label+" original global "+key+" actual="+str(actual.get(key))+" expected="+str(expected[key]))
func native_cases()->void:
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture is Dictionary and fixture.get("schema")==1 and fixture.get("source_sha256")==Core.SOURCE_SHA,"Native fixture uses uploaded DOS source provenance")
	if not fixture is Dictionary:return
	check(fixture.get("fresh_process_runs")==3 and fixture.get("reverse_repeat_count")==fixture.get("case_count") and fixture.get("canaries_unchanged",false),"Original native routines repeat with independent processes, reverse order and guarded buffers")
	for at in range(fixture.cases.size()):
		var sample:Dictionary=fixture.cases[at];var operation:=str(sample.operation);var label:="native%d %s"%[at,operation];var previous_failures:=failures
		domains[operation]=int(domains.get(operation,0))+1
		var expected:Dictionary=sample.expected
		if operation=="F1521":
			check(Core.multiply_q31(int(sample.operands_s32[0]),int(sample.operands_s32[1]))==int(expected.return_s32),label+" exact signed64 product/Q31 high word")
		elif operation=="F902":
			var result:=Core.ranges_for_spec(str(sample.spec_hex).hex_decode())
			check(result.ok,label+" spec accepted")
			check(words_equal(result.ranges_s32,expected.ranges_s32),label+" all8 original standard drive ranges")
		elif operation in ["F833","F833_F903"]:
			var distance:=Core.distance_raw_from_q16(sample.from_q16,sample.to_q16)
			check(distance.ok,label+" source positions accepted")
			check(int(distance.distance_raw)==int(expected.distance_raw_s32),label+" source F833 distance actual="+str(distance.distance_raw)+" expected="+str(expected.distance_raw_s32))
			if operation=="F833_F903":compare_evaluation(sample,expected,label,int(distance.distance_raw))
		else:compare_evaluation(sample,expected,label,int(sample.distance_raw_s32))
		if failures>previous_failures:domain_failures[operation]=int(domain_failures.get(operation,0))+failures-previous_failures
	for at in range(fixture.unsafe_cases.size()):
		var sample:Dictionary=fixture.unsafe_cases[at];var object:=str(sample.object_hex).hex_decode();var globals:Dictionary=sample.globals.duplicate(true);globals["output_seed_u32"]=sample.output_seed_u32.duplicate()
		var before:=var_to_bytes([object,globals]);var rejected:=Core.evaluate(object,str(sample.spec_hex).hex_decode(),int(sample.distance_raw_s32),globals,int(sample.mutate_flag))
		check(sample.expected_native_signal==8 and not rejected.ok and rejected.reason==sample.expected_error,"Actual native SIGFPE input rejects explicitly rather than fabricating a successful register result "+str(at))
		check(rejected.object==object and var_to_bytes(rejected.globals)==var_to_bytes(globals) and var_to_bytes([object,globals])==before,"Native fault-domain rejection leaves all raw caller bytes and globals intact "+str(at))
	var every_case:bool=domains.size()==fixture.operation_counts.size()
	for key:String in domains:every_case=every_case and int(domains[key])==int(fixture.operation_counts.get(key,-1))
	check(every_case,"Every original native safe operation is consumed exactly once")
	evidence.append({"native_cases":fixture.get("case_count",fixture.cases.size()),"native_fault_cases":fixture.unsafe_cases.size(),"operations":domains,"domain_failures":domain_failures,"native_output_sha256":fixture.get("native_ordered_output_sha256",""),"fresh_process_runs":fixture.get("fresh_process_runs",0),"canaries_unchanged":fixture.get("canaries_unchanged",false)})
func compare_evaluation(sample:Dictionary,expected:Dictionary,label:String,distance:int)->void:
	var object:=str(sample.object_hex).hex_decode();var spec:=str(sample.spec_hex).hex_decode();var globals:Dictionary=sample.globals.duplicate(true)
	globals["output_seed_u32"]=sample.get("output_seed_u32",[0,0,0,0,0]).duplicate()
	var object_before:=object.duplicate();var spec_before:=spec.duplicate();var globals_before:=var_to_bytes(globals)
	var mode:=int(sample.get("mutate_flag",1))
	if sample.operation=="F899":mode=1
	elif sample.operation=="F901":mode=2
	if sample.operation=="F900":distance=0;mode=1
	var actual:=Core.evaluate(object,spec,distance,globals,mode)
	check(actual.ok,label+" source-defined input accepted "+str(actual.get("error","")))
	if not actual.ok:return
	check(int(actual.source_return_s32)==int(expected.return_s32),label+" original return register")
	var fields:Array=["name_code_u32","max_range_s32"] if sample.operation=="F900" else ["name_code_u32","fuel_needed_s32","current_range_s32","time_raw_u32","max_range_s32"]
	for key:String in fields:
		check((int(actual[key])&0xffffffff)==(int(expected[key])&0xffffffff),label+" original output "+key+" actual="+str(actual[key])+" expected="+str(expected[key]))
	check(actual.object.hex_encode()==expected.object_hex,label+" exact338post-object bytes")
	compare_globals(actual.globals,expected.globals,label)
	check(object==object_before and spec==spec_before and var_to_bytes(globals)==globals_before,label+" source call returns isolated mutations")
func runtime_contracts()->void:
	var resource:=Core.resource();check(not resource.is_empty(),"DOS drive/spec resource loads")
	if resource.is_empty():return
	var model:=38;var source_spec:=Core.ship_spec(model)
	check(source_spec.size()>=10 and Core._s16(int(source_spec.decode_u16(6)))==100,"Actual CobraMkIII model38 carries original100t static mass;80t is its capacity, not mass")
	if source_spec.size()<10:return
	var profile:={"model_index":model,"source_drive_index":2,"player":true,"status_u16":0,"cargo_u32":20,"waste_u16":0}
	var before:=var_to_bytes(profile);var preview:=Core.quote(profile,300,4,0)
	check(preview.ok and preview.can_jump and preview.max_range_raw==300 and preview.required_fuel==1,"Original100t/class1 reaches3ly using1hydrogen")
	check(preview.duration_raw_u32==458745 and preview.duration_days==458745.0/65536.0,"Maximum-range duration retains source Q16 seven-day boundary")
	check(preview.hydrogen_after==4 and preview.cargo_after==20 and var_to_bytes(profile)==before,"Preview never consumes source inventory or mutates its profile")
	var committed:=Core.quote(profile,300,4,0,true)
	check(committed.ok and committed.can_jump and committed.hydrogen_after==3 and committed.cargo_after==19,"Consumption debits hydrogen and raw cargo together")
	check(committed.status_after==0 and preview.status_after==256,"Player flag1preview and flag2consumption preserve original ready-bit side effects as returned copies")
	var over:=Core.quote(profile,301,65535,0,true)
	check(over.ok and not over.can_jump and over.reason=="out_of_range" and over.hydrogen_after==65535 and over.cargo_after==20,"One raw distance unit beyond original range rejects without consuming fuel")
	var empty:=Core.quote(profile,1,0,0,true)
	check(empty.ok and not empty.can_jump and empty.reason=="insufficient_fuel" and empty.hydrogen_after==0,"Empty correct fuel inventory prevents a source jump")
	var zero:=Core.quote(profile,0,4,0)
	check(zero.ok and not zero.can_jump and zero.reason=="zero_distance" and zero.max_range_raw==300 and zero.current_range_raw==0,"F900-style zero distance preserves maximum range but no current-range estimate")
	var wrong_mass:=profile.duplicate(true);wrong_mass["mass_tonnes"]=999999;wrong_mass.cargo_u32=65535
	check(Core.quote(wrong_mass,1,4,0).max_range_raw==300,"Current cargo and unproven mass overrides cannot replace source static ship mass")
	var military:=profile.duplicate(true);military.source_drive_index=10;military.waste_u16=65535
	var mil:=Core.quote(military,300,0,4,true)
	check(mil.ok and mil.can_jump and mil.military_after==3 and mil.waste_after==0 and mil.cargo_after==20,"Military consumption creates source u16 radioactive waste and keeps cargo unchanged")
	var npc:=profile.duplicate(true);npc.player=false;npc.npc_fuel=2
	var npc_result:=Core.quote(npc,300,0,0,true)
	check(npc_result.ok and npc_result.can_jump and npc_result.npc_fuel_after==1 and npc_result.hydrogen_after==0,"NPC fuel uses object byte119 independently of player inventories")
	for drive in [0,1]:
		var missing:=profile.duplicate(true);missing.source_drive_index=drive
		var denied:=Core.quote(missing,1,65535,65535,true)
		check(denied.ok and not denied.can_jump and denied.reason=="no_drive","Original zero-power drive slot cannot initiate a nonzero jump")
	check(not Core.quote(profile,-1,4,0).ok and not Core.quote(profile,1,65536,0).ok,"Safe quote rejects negative distance and out-of-u16 player inventory")
	check(Core.distance_raw_from_q16([0,0,0],[65536,0,0]).distance_raw==802,"Actual F833 sector distance is802raw; no800raw Euclidean replacement")
	var object:=PackedByteArray();object.resize(338);object[0xd0]=2;var spec:=Core.ship_spec(model)
	var globals:={"player_object_index_u32":0,"status_u16":65535,"cargo_s32":10,"hydrogen_u16":4,"military_u16":0,"waste_u16":0}
	var inputs:=var_to_bytes([object,spec,globals]);var zero_mass:=spec.duplicate();zero_mass.encode_u16(6,0)
	var fault:=Core.evaluate(object,zero_mass,1,globals,2)
	check(not fault.ok and fault.reason=="source_divide_by_zero" and fault.object==object and var_to_bytes(fault.globals)==var_to_bytes(globals),"Original mass-zero SIGFPE domain rejects atomically rather than fabricating an F903 return")
	object[0xd0]=255;var invalid_drive:=Core.evaluate(object,spec,1,globals,2)
	check(not invalid_drive.ok and invalid_drive.reason=="invalid_drive_index" and invalid_drive.object==object,"Signednegative drive index rejects before reading outside DATA7187")
	object[0xd0]=0;var invalid_time:=Core.evaluate(object,spec,-1,globals,2)
	check(not invalid_time.ok and invalid_time.reason=="source_divide_by_zero","Zero-range/negative-distance source time division is explicitly guarded")
	object[0xd0]=2
	check(var_to_bytes([object,spec,globals])==inputs,"Invalid arithmetic/index domains leave every caller byte intact")
	check(not Core.evaluate(PackedByteArray(),spec,1,globals).ok and not Core.evaluate(object,PackedByteArray(),1,globals).ok,"Raw input buffers are bounded before any offset read")
	var bad_global:=globals.duplicate(true);bad_global.hydrogen_u16=-1
	check(not Core.evaluate(object,spec,1,bad_global,2).ok,"Malformed raw global widths reject atomically")
	evidence.append({"model_index":model,"mass_tonnes":100,"drive_index":2,"max_range_raw":preview.max_range_raw,"time_raw_u32":preview.time_raw_u32,"source_table_sha256":Core.TABLE_SHA})
func run()->void:
	native_cases();runtime_contracts()
	var path:="res://validation/hyperdrive-2026-11-07/source-hyperdrive-core.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"scope":"Original F899..F903/F1521 and F833 distance arithmetic, immutable raw evaluator and safe source-spec quote. Does not implement complete hyperspace entry/arrival, misjumps, interception, drive failures or service prices.","evidence":evidence,"sources":{"core_sha256":FileAccess.get_file_as_string("res://scripts/source_hyperdrive.gd").sha256_text(),"test_sha256":FileAccess.get_file_as_string("res://tests/test_source_hyperdrive.gd").sha256_text(),"fixture_sha256":FileAccess.get_file_as_string(FIXTURE).sha256_text(),"resource_sha256":FileAccess.get_file_as_string(Core.DATA_PATH).sha256_text()}},"\t"))
	print("Source hyperdrive: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
