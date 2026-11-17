extends SceneTree
const Dispatch=preload("res://scripts/source_player_dispatch.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_player_dispatch_native.json"
const FIXTURE_SHA:="2033e37070b53e2eaa90452ddf7cbb0f7484ce0453f5aba4a5dea00c5f446c8e"
const REPORT:="res://build/current-test-reports/source-player-dispatch.json"
var checks:=0
var failures:=0
var native_cases:=0
var response_cases:=0
var selection_cases:=0
var audio_cases:=0
var sequence_cases:=0
var operations:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<28:push_error(message)
func digest(value:Dictionary)->String:return Clock._hash(value)
func differences(first:PackedByteArray,second:PackedByteArray)->String:
	var cells:Array=[]
	for index in range(mini(first.size(),second.size())):
		if first[index]!=second[index]:cells.append("%x:%x/%x"%[index,first[index],second[index]])
	return str(cells.slice(0,12))
func execute_row(row:Dictionary)->Dictionary:
	var response:Variant=null
	if not str(row.get("frame_response_body_hex","")).is_empty():response=str(row.frame_response_body_hex).hex_decode()
	return Dispatch.execute(str(row.operation),str(row.body_before_hex).hex_decode(),str(row.parent_hex).hex_decode(),row.globals_before,response)
func run()->void:
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent original player callback fixture is pinned")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.get("schema")=="starfrontier-source-player-dispatch-native-v1" and fixture.get("profile")==Dispatch.PROFILE and fixture.cases.size()==640 and fixture.case_count==640,"All640 original DOS control and drift callback controls are present")
	check(fixture.source_executable_sha256==Dispatch.SOURCE_EXE_SHA256 and fixture.source_assembly_sha256=="d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a","Original uploaded EXE and reviewed assembly identities remain explicit")
	check(fixture.fresh_process_runs==3 and fixture.reverse_repeat_cases==640 and fixture.all_body_parent_bank_canaries_unchanged and not fixture.expected_arithmetic_calculated_in_python,"Three fresh native processes, reversed cases and raw ownership guards are verified separately")
	check(fixture.consecutive_native_steps==64 and fixture.frame_response_cases==55,"Fixture includes dependent original callbacks and actual frame-boundary continuations")
	var with_frame:Dictionary={};var without_frame:Dictionary={};var direct_manual:Dictionary={};var drift_case:Dictionary={}
	var sequence_body:=PackedByteArray();var sequence_globals:Dictionary={}
	for row:Dictionary in fixture.cases:
		var label:=str(row.name);var body:=str(row.body_before_hex).hex_decode();var parent:=str(row.parent_hex).hex_decode()
		var original:=var_to_bytes([body,parent,row.globals_before])
		var result:=execute_row(row)
		operations[str(row.operation)]=true;native_cases+=1
		check(result.get("ok",false),"Original callback executes: "+label)
		if not result.get("ok",false):continue
		var expected:Dictionary=row.expected
		var expected_body:=str(expected.body_after_hex).hex_decode()
		check(result.body_after==expected_body,"Entire338-byte body matches original callback: "+label+" "+differences(result.body_after,expected_body))
		check(digest(result.globals_after)==digest(expected.globals_after),"All raw player globals match: "+label)
		check(digest({"requests":result.requests})==digest({"requests":expected.requests}),"Original external-call boundaries retain order and arguments: "+label)
		check(result.source_order==expected.source_order,"Actual source procedure-entry order matches: "+label)
		check(result.frame_selection_requested==expected.frame_selection_requested and result.frame_boundary_body==str(expected.frame_boundary_body_hex).hex_decode(),"Exact F606 boundary pose and request condition match: "+label)
		check(result.response_applied==expected.response_applied,"Explicit external frame response admission matches: "+label)
		check(not result.raw_owners_mutated and not result.full_original_player_pipeline and not result.full_F606_executed and not result.audio_effects_applied and not result.quaternion_reconstruction_used,"Dispatcher keeps raw/callback boundaries explicit: "+label)
		check(var_to_bytes([body,parent,row.globals_before])==original,"Callback leaves every caller-owned byte and global unchanged: "+label)
		if result.frame_selection_requested:
			selection_cases+=1
			if with_frame.is_empty():with_frame=row
			var prefix:=Dispatch.prefix_f1041(body,parent,row.globals_before)
			check(prefix.ok and prefix.frame_selection_requested and prefix.body_after==result.frame_boundary_body,"Pure prefix exposes the original continuation boundary: "+label)
		elif row.operation=="prepare_f1041" and without_frame.is_empty():without_frame=row
		if result.response_applied:response_cases+=1
		for request:Dictionary in result.requests:
			if request.kind=="F1910":audio_cases+=1
		if row.operation=="manual_f1043" and direct_manual.is_empty():direct_manual=row
		if row.operation in ["drift_f1044","drift_f1045"]:
			if drift_case.is_empty():drift_case=row
			check(result.body_after.slice(0,0x3e)==body.slice(0,0x3e) and result.body_after.slice(0x56)==body.slice(0x56),"Original drift changes onlyposition338Bfields: "+label)
		var cold_input:Dictionary=JSON.parse_string(JSON.stringify(row))
		var cold_result:=execute_row(cold_input)
		check(cold_result.ok and cold_result.body_after==result.body_after and digest(cold_result.globals_after)==digest(result.globals_after) and digest({"requests":cold_result.requests})==digest({"requests":result.requests}),"Cold JSON raw input continues the exact callback: "+label)
		if row.has("sequence_step"):
			if int(row.sequence_step)==0:sequence_body=body.duplicate();sequence_globals=row.globals_before.duplicate(true)
			check(int(row.sequence_step)==sequence_cases and sequence_body==body and digest(sequence_globals)==digest(row.globals_before),"Consecutive original callback begins from prior actual output: "+label)
			var response:Variant=null if str(row.frame_response_body_hex).is_empty() else str(row.frame_response_body_hex).hex_decode()
			var continued:=Dispatch.execute(row.operation,sequence_body,parent,sequence_globals,response)
			check(continued.ok and continued.body_after==expected_body and digest(continued.globals_after)==digest(expected.globals_after),"Actual repeated callbacks preserve raw residues and scratch globals: "+label)
			if continued.ok:sequence_body=continued.body_after;sequence_globals=continued.globals_after
			sequence_cases+=1
	check(operations.size()==4 and selection_cases>0 and response_cases>0 and audio_cases>0,"Native bank exercises four callbacks, real frame-request conditions, injected continuation and audio-request branches")
	check(sequence_cases==64,"All64 consecutive source callback outputs were fed into the following actual runtime call")
	check(not with_frame.is_empty() and not without_frame.is_empty() and not direct_manual.is_empty() and not drift_case.is_empty(),"Native bank supplies all required negative-test contexts")
	if not direct_manual.is_empty():
		var row:=direct_manual;var body:=str(row.body_before_hex).hex_decode();var parent:=str(row.parent_hex).hex_decode();var state:Dictionary=row.globals_before.duplicate(true)
		var frozen:=var_to_bytes([body,parent,state])
		for bad:Variant in [null,true,{},[],1,"body",PackedByteArray()]:
			check(not Dispatch.execute("manual_f1043",bad,parent,state).ok and var_to_bytes([body,parent,state])==frozen,"Malformed raw body rejects without mutation")
		for bad:Variant in [null,true,[],{},1,"globals"]:check(not Dispatch.execute("manual_f1043",body,parent,bad).ok,"Malformed player globals reject")
		for key:String in Dispatch.GLOBAL_KEYS:
			var malformed:=state.duplicate(true);malformed.erase(key)
			check(not Dispatch.execute("manual_f1043",body,parent,malformed).ok,"Missing source global cannot be silently initialized: "+key)
		for bad:Variant in [-1,0x100000000,NAN,INF,true,0.5,"0"]:
			var malformed:=state.duplicate(true);malformed.frame_ticks_u32=bad
			check(not Dispatch.execute("manual_f1043",body,parent,malformed).ok,"Invalid raw unsigned tick field rejects")
		for bad:Variant in [-0x80000001,0x80000000,NAN,INF,true,0.5,"0"]:
			var malformed:=state.duplicate(true);malformed.set_speed_s32=bad
			check(not Dispatch.execute("manual_f1043",body,parent,malformed).ok,"Invalid signed source speed rejects")
		var malformed:=state.duplicate(true);malformed.extra=0
		check(not Dispatch.execute("manual_f1043",body,parent,malformed).ok,"Unknown source global rejects")
		malformed=state.duplicate(true);malformed.spin_xyz_s32=[0,true,0]
		check(not Dispatch.execute("prepare_f1041",body,parent,malformed).ok,"Boolean spin components are not raw signed words")
		malformed=state.duplicate(true);malformed.reference_velocity_s32=[0,0]
		check(not Dispatch.execute("manual_f1043",body,parent,malformed).ok,"Truncated reference velocity rejects")
		for op:Variant in [null,true,0,"F597","manual",""]:check(not Dispatch.execute(op,body,parent,state).ok,"Unknown callback does not invent a generic flight step")
		var result:=Dispatch.execute("manual_f1043",body,parent,state)
		result.body_after[0]=int(result.body_after[0])^255;result.globals_after.reference_velocity_s32[0]=0
		check(var_to_bytes([body,parent,state])==frozen,"Returned output cannot alias caller-owned raw state")
	if not with_frame.is_empty():
		var row:=with_frame;var body:=str(row.body_before_hex).hex_decode();var parent:=str(row.parent_hex).hex_decode();var state:Dictionary=row.globals_before
		var prefix:=Dispatch.prefix_f1041(body,parent,state)
		var response:PackedByteArray=prefix.frame_boundary_body.duplicate()
		var replaced:=Dispatch.execute("prepare_f1041",body,parent,state,response)
		check(replaced.ok and replaced.response_applied,"An explicit identical no-op response resumes only the requested F606 boundary")
		for offset:int in [0,0x24,0x57,0x86,0xb0,0xbc,0xec,0x110,0x14d]:
			var invalid:=response.duplicate();invalid[offset]=int(invalid[offset])^1
			check(not Dispatch.execute("prepare_f1041",body,parent,state,invalid).ok,"Frame response cannot alter unrelated body byte%x"%offset)
		for invalid:Variant in [true,{},[],"raw",PackedByteArray()]:check(not Dispatch.execute("prepare_f1041",body,parent,state,invalid).ok,"Malformed frame-boundary response rejects")
	if not without_frame.is_empty():
		var row:=without_frame
		check(not Dispatch.execute("prepare_f1041",str(row.body_before_hex).hex_decode(),str(row.parent_hex).hex_decode(),row.globals_before,str(row.body_before_hex).hex_decode()).ok,"A response cannot be injected when source F1041 did not call F606")
	if not drift_case.is_empty():
		var row:=drift_case
		check(not Dispatch.execute(str(row.operation),str(row.body_before_hex).hex_decode(),str(row.parent_hex).hex_decode(),row.globals_before,str(row.body_before_hex).hex_decode()).ok,"Drift callback does not admit a reference-selection response")
	var sources:Dictionary={}
	for path:String in ["scripts/source_player_dispatch.gd","scripts/source_angular_motion.gd","scripts/source_motion_pipeline.gd","scripts/source_gravity.gd","scripts/source_ground_surface.gd","scripts/ground_coordinates.gd","tests/test_source_player_dispatch.gd","tests/fixtures/source_player_dispatch_native.json","tools/rebuild_source_player_dispatch_native.py","validation/player-dispatch-2026-11-17/player-native-proof/instruction-proof.json","validation/player-dispatch-2026-11-17/player-native-proof/source-procedures.s"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"schema":1,"profile":Dispatch.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"frame_request_cases":selection_cases,"frame_response_cases":response_cases,"audio_request_cases":audio_cases,"consecutive_actual_callbacks":sequence_cases,"sources":sources,"full_original_player_pipeline":false,"full_F606_executed":false,"live_Main_motion_replaced":false,"physical_device_tested":false,"scope":"Whole DOS F1041 control preparation, restored DOS F1043 active-low forward/reverse and damping, separate F1044/F1045 drift callbacks. Real original angular/gravity/thrust/drift kernels; F606 and audio remain explicit observed boundaries. Full338B outputs, exact procedure order and post-frame-response thrust continuation match independent native instructions. This is not universal F1019/F570 player scheduling, event effects, live Main or Android proof."},"\t"));file.close()
	print("SOURCE PLAYER DISPATCH TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
