extends SceneTree
# Whole DOS F1046/F1033/F1034 bodies feed these controls. F569 geometry and
# F939/audio/UI/destruction effects remain explicit source-call boundaries.
const Motion=preload("res://scripts/source_player_motion.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_player_motion_native.json"
const FIXTURE_SHA:="622178b60d3108936c868ea9ae36e95c1a72db34bb17c257e2d5fde814bf36cb"
const REPORT:="res://build/current-test-reports/source-player-motion.json"
var checks:=0
var failures:=0
var native_cases:=0
var trail_cases:=0
var sound_cases:=0
var contact_cases:=0
var sequence_cases:=0
var sequence_groups:=0
var callback_cases:Dictionary={}
var operations:Dictionary={}
var _fixture:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<28:push_error(label)
func digest(value:Dictionary)->String:return Clock._hash(value)
func copied(value:Dictionary)->Dictionary:return JSON.parse_string(JSON.stringify(value))
func raw_sha(bytes:PackedByteArray)->String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes);return context.finish().hex_encode()
func raw_root(row:Dictionary,after:bool=false)->PackedByteArray:
	var root:=PackedByteArray();root.resize(0x4000);root.fill(int(row.root_tail_fill_u8))
	var encoded:String=str(row.expected.root_prefix_after_hex) if after else str(row.root_prefix_before_hex)
	var prefix:=encoded.hex_decode()
	for index in range(prefix.size()):root[index]=prefix[index]
	root[0x3f5e]=int(row.effects_enabled_root_u8)
	return root
func invoke(operation:Variant,root:Variant,body:Variant,globals:Variant,boundary:Variant={})->Dictionary:
	return Motion.execute(operation,body,root,globals,boundary)
func execute_row(row:Dictionary)->Dictionary:
	return invoke(row.operation,raw_root(row),str(row.body_before_hex).hex_decode(),row.globals_before,row.boundary)
func first_row(operation:String)->Dictionary:
	for row:Dictionary in _fixture.cases:
		if row.operation==operation:return row
	return {}
func raw_tests()->void:
	var sequence_root:=PackedByteArray();var sequence_body:=PackedByteArray();var sequence_globals:Dictionary={}
	for row:Dictionary in _fixture.cases:
		var label:=str(row.name);var root:=raw_root(row);var body:=str(row.body_before_hex).hex_decode()
		var original:=var_to_bytes([root,body,row.globals_before,row.boundary]);var result:=invoke(row.operation,root,body,row.globals_before,row.boundary)
		operations[row.operation]=true;native_cases+=1
		check(result.get("ok",false),"Original motion/contact tail executes: "+label)
		if not result.get("ok",false):continue
		var expected:Dictionary=row.expected
		check(result.root_after==raw_root(row,true),"Every16KB source-root byte matches original native output: "+label)
		check(raw_sha(result.root_after)==expected.root_after_sha256,"Whole-root native checksum includes every preserved tail byte: "+label)
		check(result.body_after.hex_encode()==expected.body_after_hex,"Every338B caller-body byte matches original native output: "+label)
		check(digest(result.globals_after)==digest(expected.globals_after),"All source globals match native output: "+label)
		check(digest({"requests":result.requests})==digest({"requests":expected.requests}),"Original callbacks retain exact source order, arguments and boundary pose: "+label)
		check(result.source_order==expected.source_order,"Actual procedure-entry order matches native source: "+label)
		check(result.return_s32==expected.return_s32,"Original signed return matches native source: "+label)
		check(digest(result.outputs)==digest(expected.outputs),"F569 caller output references and material match actual observation: "+label)
		check(not result.raw_owners_mutated and not result.complete_original_flight_pipeline and not result.F569_geometry_executed and not result.F939_body_executed and not result.external_effects_applied,"Runtime preserves the bounded source-callback provenance: "+label)
		check(var_to_bytes([root,body,row.globals_before,row.boundary])==original,"All caller-owned state and boundary metadata remain unchanged: "+label)
		var cold:=execute_row(copied(row))
		check(cold.ok and cold.root_after==result.root_after and cold.body_after==result.body_after and digest(cold.globals_after)==digest(result.globals_after) and digest({"requests":cold.requests})==digest({"requests":result.requests}),"Cold JSON observations replay the same source procedure: "+label)
		for request:Dictionary in result.requests:
			callback_cases[str(request.kind)]=int(callback_cases.get(str(request.kind),0))+1
			if request.kind=="F939":trail_cases+=1
			if request.kind=="F1910":sound_cases+=1
		if row.operation=="contact_f1033":contact_cases+=1
		if row.has("sequence_step"):
			if int(row.sequence_step)==0:
				sequence_root=root.duplicate();sequence_body=body.duplicate();sequence_globals=row.globals_before.duplicate(true);sequence_groups+=1
			check(sequence_root==root and sequence_body==body and digest(sequence_globals)==digest(row.globals_before),"Consecutive source step begins from previous actual runtime output: "+label)
			var continued:=invoke(row.operation,sequence_root,sequence_body,sequence_globals,row.boundary)
			check(continued.ok and continued.root_after==raw_root(row,true) and continued.body_after.hex_encode()==expected.body_after_hex and digest(continued.globals_after)==digest(expected.globals_after),"Prior runtime state continues the exact original native procedure: "+label)
			if continued.ok:sequence_root=continued.root_after;sequence_body=continued.body_after;sequence_globals=continued.globals_after
			sequence_cases+=1
	check(operations.size()==3 and trail_cases>0 and sound_cases>0 and contact_cases>0,"Native corpus covers three source operations and both trail/noise boundaries")
	for callback:String in ["F569","F939","F1910","F1116","F349","F148","F1906","F953"]:check(int(callback_cases.get(callback,0))>0,"Source bank reaches observed callback "+callback)
	check(sequence_cases==48 and sequence_groups==3,"All48 original native consecutive callbacks continue actual runtime output in three operation groups")
func reject_common()->void:
	var row:=first_row("effects_f1046");check(not row.is_empty(),"Native effects context exists")
	if row.is_empty():return
	var root:=raw_root(row);var body:=str(row.body_before_hex).hex_decode();var globals:Dictionary=row.globals_before.duplicate(true);var boundary:Dictionary=row.boundary.duplicate(true)
	var frozen:=var_to_bytes([root,body,globals,boundary])
	for bad:Variant in [null,true,{},[],1,"root",PackedByteArray()]:
		check(not invoke("effects_f1046",bad,body,globals,boundary).ok and var_to_bytes([root,body,globals,boundary])==frozen,"Malformed raw root rejects without changing any owner")
	for bad:Variant in [null,true,{},[],1,"body",PackedByteArray()]:check(not invoke("effects_f1046",root,bad,globals,boundary).ok,"Malformed raw body rejects")
	for wrong_size:int in [0x3fff,0x4001]:
		var wrong:=root.duplicate();wrong.resize(wrong_size)
		check(not invoke("effects_f1046",wrong,body,globals,boundary).ok,"Raw root length must be exactly the source window")
	for wrong_size:int in [337,339]:
		var wrong:=body.duplicate();wrong.resize(wrong_size)
		check(not invoke("effects_f1046",root,wrong,globals,boundary).ok,"Raw body length must be exactly the source record")
	for bad:Variant in [null,true,[],{},1,"globals"]:check(not invoke("effects_f1046",root,body,bad,boundary).ok,"Malformed source-global set rejects")
	for key:String in ["effect_gate_s32","sound_mode_s8","step_u32"]:
		var missing:=globals.duplicate(true);missing.erase(key)
		check(not invoke("effects_f1046",root,body,missing,boundary).ok,"Missing global is never silently initialized: "+key)
	var extra:=globals.duplicate(true);extra.extra=0
	check(not invoke("effects_f1046",root,body,extra,boundary).ok,"Unknown global rejects")
	for key:String in ["effect_gate_s32","sound_mode_s8","step_u32"]:
		for value:Variant in [true,0.5,NAN,INF,"0",null]:
			var invalid:=globals.duplicate(true);invalid[key]=value
			check(not invoke("effects_f1046",root,body,invalid,boundary).ok,"Noninteger raw global rejects: "+key)
	for entry:Array in [["effect_gate_s32",-0x80000001],["effect_gate_s32",0x80000000],["sound_mode_s8",-129],["sound_mode_s8",128],["step_u32",-1],["step_u32",0x100000000]]:
		var invalid:=globals.duplicate(true);invalid[entry[0]]=entry[1]
		check(not invoke("effects_f1046",root,body,invalid,boundary).ok,"Out-of-range source global rejects: "+str(entry[0]))
	for bad:Variant in [null,true,0,"F1046","motion",""]:check(not invoke(bad,root,body,globals,boundary).ok,"Unknown operation does not become a generic source tick")
	for bad:Variant in [null,true,[],0,"observe"]:check(not invoke("effects_f1046",root,body,globals,bad).ok,"Malformed callback boundary rejects")
	for offset:int in [0xc8,0xcc]:
		var invalid:=root.duplicate();invalid.encode_u32(offset,115)
		check(not invoke("effects_f1046",invalid,body,globals,boundary).ok,"Source root logical bank references reject an out-of-bank index")
	for identity:int in [0,115,255]:
		var invalid_body:=body.duplicate();invalid_body[0x86]=identity
		var invalid_root:=root.duplicate();invalid_root.encode_u32(0xc8,identity)
		check(not invoke("effects_f1046",invalid_root,invalid_body,globals,boundary).ok,"Player body identity must resolve a live source bank slot")
	var invalid:=root.duplicate();invalid.encode_u32(0xc8,0)
	check(not invoke("effects_f1046",invalid,body,globals,boundary).ok,"Source root must resolve the supplied player identity")
	invalid=root.duplicate();invalid.encode_u32(0xc8,1 if int(body[0x86])!=1 else 2)
	check(not invoke("effects_f1046",invalid,body,globals,boundary).ok,"Source root player reference cannot disagree with body identity")
	var returned:=invoke("effects_f1046",root,body,globals,boundary)
	check(returned.ok,"Valid native context is available for result alias protection")
	if returned.ok:
		returned.root_after[0]=int(returned.root_after[0])^255;returned.body_after[0]=int(returned.body_after[0])^255;returned.globals_after.step_u32=0
		if not returned.requests.is_empty():returned.requests[0].extra=1
		check(var_to_bytes([root,body,globals,boundary])==frozen,"Returned raw bytes, globals and requests cannot alias caller inputs")
func reject_effects()->void:
	var trail_seen:=false;var no_trail_seen:=false
	for row:Dictionary in _fixture.cases:
		if row.operation!="effects_f1046":continue
		var root:=raw_root(row);var body:=str(row.body_before_hex).hex_decode()
		if int(body[0x14e])!=0:
			if trail_seen:continue
			trail_seen=true
			check(not invoke(row.operation,root,body,row.globals_before,{}).ok,"A requested F939 allocation/RNG boundary cannot be silently ignored")
			for malformed:Dictionary in [{"trail_policy":"execute"},{"trail_policy":"observe_only","extra":0}]:check(not invoke(row.operation,root,body,row.globals_before,malformed).ok,"Unknown trail effects or request metadata reject")
		else:
			if no_trail_seen:continue
			no_trail_seen=true
			check(not invoke(row.operation,root,body,row.globals_before,{"trail_policy":"observe_only"}).ok,"Trail observations cannot be injected when source did not call F939")
		if trail_seen and no_trail_seen:break
	check(trail_seen and no_trail_seen,"Native source bank covers both F939 admission conditions")
func reject_contact()->void:
	var row:=first_row("contact_f1033");check(not row.is_empty(),"Native F1033 contact context exists")
	if row.is_empty():return
	var root:=raw_root(row);var body:=str(row.body_before_hex).hex_decode();var globals:Dictionary=row.globals_before;var boundary:Dictionary=row.boundary
	var frozen:=var_to_bytes([root,body,globals,boundary])
	check(not invoke(row.operation,root,body,globals,{}).ok,"Contact continuation requires an explicit actual F569 observation")
	for key:String in boundary:
		var missing:=boundary.duplicate(true);missing.erase(key)
		check(not invoke(row.operation,root,body,globals,missing).ok,"Incomplete source contact observation rejects: "+key)
	var changed:=boundary.duplicate(true);changed.extra=0
	check(not invoke(row.operation,root,body,globals,changed).ok,"Unknown contact observation metadata rejects")
	for entry:Array in [["caller_profile","jjffe"],["body_before_hex",""],["body_after_hex",""],["collider_body_hex",""],["flags_u8",256],["flags_u8",-1],["altitude_raw_s32",0x80000000],["altitude_raw_s32",-0x80000001],["collider_ref_u32",115],["collider_ref_u32",-1],["collider_index_u8",256],["material_u8",256]]:
		changed=boundary.duplicate(true);changed[entry[0]]=entry[1]
		check(not invoke(row.operation,root,body,globals,changed).ok,"Invalid raw F569 observation field rejects: "+str(entry[0]))
	for key:String in ["flags_u8","altitude_raw_s32","collider_ref_u32","collider_index_u8","material_u8"]:
		for value:Variant in [true,0.25,NAN,INF,"0"]:
			changed=boundary.duplicate(true);changed[key]=value
			check(not invoke(row.operation,root,body,globals,changed).ok,"Noninteger F569 output rejects: "+key)
	for offset:int in [0x56,0x57,0x86]:
		changed=boundary.duplicate(true);var after:=str(changed.body_after_hex).hex_decode();after[offset]=int(after[offset])^1;changed.body_after_hex=after.hex_encode()
		check(not invoke(row.operation,root,body,globals,changed).ok,"Observed classifier cannot replace body identity metadata at%x"%offset)
	changed=boundary.duplicate(true);var other:=body.duplicate();other[0]=int(other[0])^1;changed.body_before_hex=other.hex_encode()
	check(not invoke(row.operation,root,body,globals,changed).ok,"Contact observation is bound to the exact original caller body")
	changed=boundary.duplicate(true);changed.flags_u8=int(changed.flags_u8)|1;changed.collider_ref_u32=0
	check(not invoke(row.operation,root,body,globals,changed).ok,"Atmospheric contact cannot dereference a null collider")
	changed=boundary.duplicate(true);changed.flags_u8=int(changed.flags_u8)|1;changed.collider_ref_u32=1
	var collider:=str(changed.collider_body_hex).hex_decode();collider[0x86]=2;changed.collider_body_hex=collider.hex_encode()
	check(not invoke(row.operation,root,body,globals,changed).ok,"Collider bytes must resolve the observed logical bank reference")
	check(var_to_bytes([root,body,globals,boundary])==frozen,"All rejected observations leave original root/body/globals/metadata unchanged")
func reject_decay()->void:
	var row:=first_row("decay_f1034");check(not row.is_empty(),"Native F1034 decay context exists")
	if row.is_empty():return
	check(not invoke(row.operation,raw_root(row),str(row.body_before_hex).hex_decode(),row.globals_before,{"trail_policy":"observe_only"}).ok,"Cargo decay cannot consume an unrelated callback boundary")
func run()->void:
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent original player motion fixture is pinned")
	_fixture=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(_fixture.get("schema")=="starfrontier-source-player-motion-native-v1" and _fixture.get("profile")==Motion.PROFILE and _fixture.case_count==_fixture.cases.size() and _fixture.case_count==600,"Native corpus contains every published original motion/contact case")
	check(_fixture.source_executable_sha256==Motion.SOURCE_EXE_SHA256 and _fixture.source_assembly_sha256=="d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a","Uploaded executable and reviewed source identities remain explicit")
	check(_fixture.fresh_process_runs==3 and _fixture.reverse_repeat_cases==_fixture.case_count and _fixture.all_root_body_collider_canaries_unchanged and _fixture.consecutive_native_steps==48 and not _fixture.expected_arithmetic_calculated_in_python,"Fresh native processes and reversed inputs independently calculate expected source output")
	raw_tests();reject_common();reject_effects();reject_contact();reject_decay()
	var sources:Dictionary={}
	for path:String in ["scripts/source_player_motion.gd","scripts/source_fuel_scoop.gd","scripts/source_gravity.gd","tests/test_source_player_motion.gd","tests/fixtures/source_player_motion_native.json","tools/rebuild_source_player_motion_native.py","validation/player-cycle-2026-11-17/motion-native-proof/instruction-proof.json","validation/player-cycle-2026-11-17/motion-native-proof/source-procedures.s"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"schema":1,"profile":Motion.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"operations":operations.keys(),"trail_request_cases":trail_cases,"noise_request_cases":sound_cases,"contact_cases":contact_cases,"consecutive_actual_callbacks":sequence_cases,"callback_cases":callback_cases,"sources":sources,"full_collision_classifier":false,"live_Main_motion_replaced":false,"physical_device_tested":false,"scope":"Whole original DOS F1046 drift/FX caller, F1033 after explicit source F569 observation and F1034 cargo decay. Full16KB root and338B body are compared against independent native source instructions. F939 RNG/allocation, audio/UI/destruction and F569 classification are explicit boundaries, not full effects execution."},"\t"));file.close()
	print("SOURCE PLAYER MOTION TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
