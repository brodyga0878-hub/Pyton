extends SceneTree
const Mode=preload("res://scripts/source_player_mode.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_player_mode_native.json"
const FIXTURE_SHA:="5f13bed8a6664f64636200b098d8485e95fad9c97c2855baab517ab8a8ebad7e"
const REPORT:="res://build/current-test-reports/source-player-mode.json"
var checks:=0
var failures:=0
var native_cases:=0
var response_cases:=0
var pending_boundaries:=0
var consecutive_steps:=0
var operations:Dictionary={}
var proof_dependencies:Dictionary={}
var callback_counts:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<28:push_error(message)
func digest(value:Dictionary)->String:return Clock._hash(value)
func raw_sha(value:PackedByteArray)->String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(value);return context.finish().hex_encode()
func sparse(value:Dictionary)->PackedByteArray:
	var result:=PackedByteArray();result.resize(Mode.ROOT_WINDOW_BYTES);result.fill(int(value.fill_u8))
	for patch:Array in value.patches:result[int(patch[0])]=int(patch[1])
	return result
func differences(first:PackedByteArray,second:PackedByteArray)->String:
	var cells:Array=[]
	for index in range(mini(first.size(),second.size())):
		if first[index]!=second[index]:cells.append("%x:%x/%x"%[index,first[index],second[index]])
	return str(cells.slice(0,12))
func reject_contexts()->void:
	var body:=PackedByteArray();body.resize(Mode.OBJECT_BYTES)
	var root:=PackedByteArray();root.resize(Mode.ROOT_WINDOW_BYTES)
	var external:Dictionary={"frame_ticks_u32":7,"action_a_u32":0,"action_b_u32":0}
	var clock:Dictionary={"tick_u32":3,"day_u32":1}
	var frozen:=var_to_bytes([body,root,external,clock])
	for bad:Variant in [null,true,0,"mode",[],{},PackedByteArray()]:
		check(not Mode.execute("control_f1009",bad,root,external,clock).ok,"Malformed player body rejects")
		check(not Mode.execute("control_f1009",body,bad,external,clock).ok,"Malformed raw root rejects")
	for bad:Variant in [null,true,0,"mode",[],{}]:
		check(not Mode.execute("control_f1009",body,root,bad,clock).ok,"Malformed external globals reject")
		check(not Mode.execute("control_f1009",body,root,external,bad).ok,"Malformed calendar words reject")
	for key:String in Mode.EXTERNAL_KEYS:
		var malformed:=external.duplicate(true);malformed.erase(key)
		check(not Mode.execute("control_f1009",body,root,malformed,clock).ok,"Missing external word rejects: "+key)
		for bad:Variant in [-1,0x100000000,NAN,INF,true,0.5,"0"]:
			malformed=external.duplicate(true);malformed[key]=bad
			check(not Mode.execute("control_f1009",body,root,malformed,clock).ok,"Invalid raw external word rejects: "+key)
	for key:String in ["tick_u32","day_u32"]:
		var malformed:=clock.duplicate(true);malformed.erase(key)
		check(not Mode.execute("control_f1009",body,root,external,malformed).ok,"Missing clock word rejects: "+key)
		for bad:Variant in [-1,0x100000000,NAN,INF,true,0.5,"0"]:
			malformed=clock.duplicate(true);malformed[key]=bad
			check(not Mode.execute("control_f1009",body,root,external,malformed).ok,"Invalid calendar word rejects: "+key)
	var malformed:=external.duplicate(true);malformed.phase_u8=0
	check(not Mode.execute("control_f1009",body,root,malformed,clock).ok,"Phase alias cannot be supplied as a second external owner")
	malformed=clock.duplicate(true);malformed.extra=0
	check(not Mode.execute("control_f1009",body,root,external,malformed).ok,"Unknown clock word rejects")
	for op:Variant in [null,true,0,"F1009","manual",""]:
		check(not Mode.execute(op,body,root,external,clock).ok,"Unknown operation rejects")
	for phase:int in [58,59,127,128,129,254,255]:
		var unsafe:=root.duplicate();unsafe[0xe8]=phase
		check(Mode.mode_for(phase).is_empty(),"Signed or null table selector is not clamped: %d"%phase)
		for op:String in ["control_f1009","post_f1010"]:
			check(not Mode.execute(op,body,unsafe,external,clock).ok,"Unsafe indirect call rejects atomically: "+op)
		check(Mode.execute("housekeeping_f1008",body,unsafe,external,clock).ok,"Standalone housekeeping preserves an opaque phase without calling it")
	for bad:Variant in [-1,256,NAN,INF,true,0.5,"0",null]:check(Mode.mode_for(bad).is_empty(),"Invalid phase lookup rejects")
	for phase in range(58):
		var row:=Mode.mode_for(phase);var again:=Mode.mode_for(phase)
		check(not row.is_empty() and int(row.phase_u8)==(phase&0xfe),"All actual even and odd phase selectors retain their pair")
		row.control_function_id=0
		check(Mode.mode_for(phase)==again,"Returned mode row cannot mutate the pinned table")
	for bad:Variant in [null,true,0,"trace",{},[{}],[],[{}, {}, {}, {}, {}]]:
		if bad is Array and bad.is_empty():continue
		check(not Mode.execute("control_f1009",body,root,external,clock,bad).ok,"Malformed observation trace rejects")
	for bad:Variant in [null,0,1,"true",[],{}]:check(not Mode.execute("control_f1009",body,root,external,clock,[],bad).ok,"Pending policy must be an explicit boolean")
	var no_callback:=Mode.execute("housekeeping_f1008",body,root,external,clock,[],true)
	check(no_callback.ok,"A complete housekeeping step with no external callback needs no observation")
	var pending:=Mode.execute("control_f1009",body,root,external,clock,[],true)
	check(not pending.ok and pending.get("pending",false) and pending.request.kind=="control_phase" and pending.trace_consumed==0,"Strict empty trace pauses before executing the selected handler")
	var output:=Mode.execute("control_f1009",body,root,external,clock)
	check(output.ok,"Independent valid mode context is admitted")
	if output.ok:
		output.body_after[0]=255;output.root_after[0]=255;output.externals_after.frame_ticks_u32=0;output.requests[0].args_u32.append(99)
	check(var_to_bytes([body,root,external,clock])==frozen,"Every reject and output edit leaves caller-owned context unchanged")
func trace_rejections(row:Dictionary)->void:
	var body:=str(row.body_before_hex).hex_decode();var root:=sparse(row.root_before)
	var frozen:=var_to_bytes([body,root,row.externals_before,row.clock,row.trace])
	var trace:Array=row.trace.duplicate(true)
	for key:String in ["body_before_hex","root_before_hex"]:
		trace=row.trace.duplicate(true)
		var bytes:=str(trace[0][key]).hex_decode();bytes[0]=int(bytes[0])^1;trace[0][key]=bytes.hex_encode()
		check(not Mode.execute(row.operation,body,root,row.externals_before,row.clock,trace).ok,"Mismatched observed before bytes cannot continue: "+key)
	trace=row.trace.duplicate(true);trace[0].externals_before.frame_ticks_u32=(int(trace[0].externals_before.frame_ticks_u32)+1)&0xffffffff
	check(not Mode.execute(row.operation,body,root,row.externals_before,row.clock,trace).ok,"Mismatched before external words cannot continue")
	trace=row.trace.duplicate(true);trace[0].request.function_id_u32=0
	check(not Mode.execute(row.operation,body,root,row.externals_before,row.clock,trace).ok,"Another callback cannot consume the observed response")
	for key:String in Mode.TRACE_KEYS:
		trace=row.trace.duplicate(true);trace[0].erase(key)
		check(not Mode.execute(row.operation,body,root,row.externals_before,row.clock,trace).ok,"Incomplete observed row rejects: "+key)
	for key:String in ["body_before_hex","root_before_hex","body_after_hex","root_after_hex"]:
		trace=row.trace.duplicate(true);trace[0][key]="00"
		check(not Mode.execute(row.operation,body,root,row.externals_before,row.clock,trace).ok,"Truncated observed raw window rejects: "+key)
	trace=row.trace.duplicate(true);trace[0].extra=0
	check(not Mode.execute(row.operation,body,root,row.externals_before,row.clock,trace).ok,"Unknown observation field rejects")
	trace=row.trace.duplicate(true);trace.append(trace[-1].duplicate(true))
	check(not Mode.execute(row.operation,body,root,row.externals_before,row.clock,trace).ok,"Unused observed callback cannot be silently accepted")
	if row.trace.size()>1:
		trace=row.trace.duplicate(true);trace.pop_back()
		check(not Mode.execute(row.operation,body,root,row.externals_before,row.clock,trace).ok,"Missing required observed callback rejects")
	check(var_to_bytes([body,root,row.externals_before,row.clock,row.trace])==frozen,"Rejected observations do not mutate original callback state or trace")
func run()->void:
	reject_contexts()
	if not FileAccess.file_exists(FIXTURE):
		check(false,"Native fixture is required; original instructions are never replaced by Python expected math")
	else:
		check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent original DOS mode fixture is pinned")
		var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
		check(fixture.get("schema")=="starfrontier-source-player-mode-native-v1" and fixture.profile==Mode.PROFILE and int(fixture.case_count)==568 and fixture.cases.size()==568 and fixture.proof is Dictionary,"All568 independently executed original mode cases and proof metadata are present")
		check(fixture.proof.source_executable_sha256==Mode.SOURCE_EXE_SHA256 and fixture.proof.source_assembly_sha256=="d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a" and fixture.proof.source_data_sha256=="34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850","DOS executable, assembly and logical58entry source table identities remain pinned")
		check(fixture.proof.fresh_process_runs==3 and fixture.proof.reverse_repeat_cases==568 and fixture.proof.all_body_root_external_canaries_unchanged and not fixture.proof.expected_arithmetic_calculated_in_python,"Original instructions run in three clean processes, reversed case order and guarded body/root/global memory")
		check(fixture.callback_response_cases==40 and fixture.consecutive_native_steps==32 and int(fixture.case_counts_by_operation.housekeeping_f1008)==264 and int(fixture.case_counts_by_operation.control_f1009)==164 and int(fixture.case_counts_by_operation.post_f1010)==140,"Fixture keeps directed callback mutations,32 dependent steps and all three whole procedure banks")
		proof_dependencies=fixture.proof.source_dependencies_sha256.duplicate(true)
		for path:String in proof_dependencies:check(FileAccess.get_sha256("res://"+path)==proof_dependencies[path],"Native reproduction dependency is pinned: "+path)
		var observed_row:Dictionary={}
		var phase_coverage:Dictionary={"control_f1009":{},"post_f1010":{}}
		var sequence_body:=PackedByteArray();var sequence_root:=PackedByteArray();var sequence_external:Dictionary={}
		for row:Dictionary in fixture.cases:
			var label:=str(row.name);var body:=str(row.body_before_hex).hex_decode();var root:=sparse(row.root_before)
			var trace:Array=row.get("trace",[]);var original:=var_to_bytes([body,root,row.externals_before,row.clock,trace])
			if trace.is_empty() and phase_coverage.has(row.operation):phase_coverage[row.operation][int(root[0xe8])]=true
			var result:=Mode.execute(row.operation,body,root,row.externals_before,row.clock,trace)
			operations[str(row.operation)]=true;native_cases+=1
			check(result.get("ok",false),"Original mode procedure executes: "+label)
			if not result.get("ok",false):continue
			var expected:Dictionary=row.expected;var expected_body:=str(expected.body_after_hex).hex_decode();var expected_root:=sparse(expected.root_after)
			check(result.body_after==expected_body,"Entire338-byte body matches actual DOS instructions: "+label+" "+differences(result.body_after,expected_body))
			check(result.root_after==expected_root,"Entire16384-byte raw root window matches actual DOS instructions: "+label+" "+differences(result.root_after,expected_root))
			check(raw_sha(result.root_after)==expected.root_after_sha256,"Native after-root fingerprint matches: "+label)
			check(digest(result.externals_after)==digest(expected.externals_after),"All non-aliased external globals match original: "+label)
			check(digest({"requests":result.requests})==digest({"requests":expected.requests}),"Typed callback arguments and exact source order match: "+label)
			var selected:int=0
			for request:Dictionary in expected.requests:
				callback_counts[request.kind]=int(callback_counts.get(request.kind,0))+1
				if request.kind in ["control_phase","post_phase"]:selected=int(request.function_id_u32)
			check(result.selected_function_id_u32==selected,"Actual signed-byte paired table selection matches: "+label)
			check(result.trace_consumed==trace.size(),"Every supplied native boundary is consumed exactly once: "+label)
			check(not result.live_owners_changed and not result.callback_bodies_executed and not result.full_player_cycle and result.root_window_bytes==16384,"Observed callback and raw window scope stays explicit: "+label)
			check(var_to_bytes([body,root,row.externals_before,row.clock,trace])==original,"Original body/root/external/clock/trace remain caller-owned: "+label)
			if not trace.is_empty():
				response_cases+=1
				if observed_row.is_empty() or trace.size()>observed_row.trace.size():observed_row=row
				for index in range(trace.size()):
					var pending:=Mode.execute(row.operation,body,root,row.externals_before,row.clock,trace.slice(0,index),true)
					var boundary:Dictionary=trace[index];pending_boundaries+=1
					check(not pending.ok and pending.get("pending",false),"Strict native prefix pauses at the next real original callback: "+label)
					if pending.get("pending",false):
						check(digest(pending.request)==digest(boundary.request),"Pending descriptor matches native function, arguments and body identity: "+label)
						check(pending.body_before==str(boundary.body_before_hex).hex_decode() and pending.root_before==str(boundary.root_before_hex).hex_decode(),"Pending338Bbody/16384Broot are the exact native callback boundary: "+label)
						check(digest(pending.externals_before)==digest(boundary.externals_before) and pending.trace_consumed==index,"Pending non-aliased globals and consumed prefix match native: "+label)
						check(not pending.live_owners_changed and not pending.callback_bodies_executed and not pending.full_player_cycle,"Pausing has no implicit callback effects: "+label)
				var resumed:=Mode.execute(row.operation,body,root,row.externals_before,row.clock,trace,true)
				check(resumed.ok and resumed.body_after==expected_body and resumed.root_after==expected_root and digest(resumed.externals_after)==digest(expected.externals_after),"Complete native observations resume the strict operation exactly: "+label)
				check(var_to_bytes([body,root,row.externals_before,row.clock,trace])==original,"Strict prefix replay leaves all initial native owners and observations unchanged: "+label)
			if label.begins_with("consecutive-native/"):
				var step:int=int(label.get_slice("/",1))
				if step==0:sequence_body=body.duplicate();sequence_root=root.duplicate();sequence_external=row.externals_before.duplicate(true)
				check(step==consecutive_steps and sequence_body==body and sequence_root==root and digest(sequence_external)==digest(row.externals_before),"Consecutive original step begins from the prior runtime's full raw output: "+label)
				var continued:=Mode.execute(row.operation,sequence_body,sequence_root,sequence_external,row.clock,trace)
				check(continued.ok and continued.body_after==expected_body and continued.root_after==expected_root and digest(continued.externals_after)==digest(expected.externals_after),"Repeated clock borrow, flags and shield residues match consecutive native instructions: "+label)
				if continued.ok:sequence_body=continued.body_after;sequence_root=continued.root_after;sequence_external=continued.externals_after
				consecutive_steps+=1
		check(operations.size()==3 and response_cases>0,"Original instruction bank exercises all three procedures and callback continuations")
		check(phase_coverage.control_f1009.size()==58 and phase_coverage.post_f1010.size()==58,"Every one of58 signed-byte even/odd selectors is executed natively in both table columns")
		check(response_cases==40 and consecutive_steps==32 and pending_boundaries==102,"All40 callback-mutation cases,102 strict native boundaries and32 consecutive steps run")
		check(digest(callback_counts)==digest({"control_phase":164,"post_phase":140,"F1116":155,"F1062":79,"F1064":72,"F1097":34}),"Native callbacks include every notification, both preactions and each selected column")
		if not observed_row.is_empty():trace_rejections(observed_row)
	var sources:Dictionary={}
	for path:String in proof_dependencies:sources[path]=FileAccess.get_sha256("res://"+path)
	for path:String in ["scripts/source_player_mode.gd","scripts/source_clock_pipeline.gd","scripts/source_reference_bank.gd","tests/test_source_player_mode.gd","data/ffe_player_modes.json","tests/fixtures/source_player_mode_native.json","tools/rebuild_source_player_mode_native.py","validation/player-cycle-2026-11-17/mode-native-proof/instruction-proof.json"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"schema":1,"profile":Mode.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"observed_callback_cases":response_cases,"pending_callback_boundaries":pending_boundaries,"consecutive_native_steps":consecutive_steps,"callback_counts":callback_counts,"sources":sources,"live_Main_replaced":false,"full_player_cycle":false,"callback_bodies_executed":false,"physical_device_tested":false,"scope":"Whole DOS F1008/F1009/F1010, exact 29 paired mode entries and odd-phase selectors, one raw16KiB root window, three non-aliased globals. Callback bodies remain explicit matched before/after observation boundaries, with strict pending prefixes for composition; this is not full handler or live Main/Android proof."},"\t"));file.close()
	print("SOURCE PLAYER MODE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
