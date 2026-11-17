extends SceneTree
const InputSource=preload("res://scripts/source_player_input.gd")
const FIXTURE:="res://tests/fixtures/source_player_input_native.json"
const FIXTURE_SHA:="6644b8eaec991b79a28c6b26e3be8f1e8b2303a21f9fdb5d21019b6e8b6cfeb8"
const REPORT:="res://build/current-test-reports/source-player-input.json"
var checks:=0
var failures:=0
var native_cases:=0
var sequence_cases:=0
var gui_cases:=0
var f931_cases:=0
var operations:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<24:push_error(message)
func digest(value:Variant)->String:return JSON.stringify(JSON.parse_string(JSON.stringify(value)),"",true).sha256_text()
func patch(bytes:PackedByteArray,segments:Array)->void:
	for segment:Dictionary in segments:
		var raw:=str(segment.hex).hex_decode()
		for index in range(raw.size()):bytes[int(segment.offset)+index]=raw[index]
func root_for(row:Dictionary)->PackedByteArray:
	var root:=PackedByteArray();root.resize(InputSource.ROOT_BYTES);root.fill(int(row.root_fill_u8));patch(root,row.root_before_segments);return root
func byte_hash(bytes:PackedByteArray)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()
func differences(first:PackedByteArray,second:PackedByteArray)->String:
	var cells:Array=[]
	for index in range(mini(first.size(),second.size())):
		if first[index]!=second[index]:cells.append("%x:%x/%x"%[index,first[index],second[index]])
	return str(cells.slice(0,8))
func execute_row(row:Dictionary,body:Variant=null,root:Variant=null,globals:Variant=null)->Dictionary:
	return InputSource.execute(str(row.operation),str(row.body_before_hex).hex_decode() if body==null else body,root_for(row) if root==null else root,row.globals_before if globals==null else globals,int(row.gui_accumulator_u32),int(row.speed_input_s32))
func run()->void:
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent full original DOS input fixture is pinned")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.schema=="starfrontier-source-player-input-native-v1" and fixture.profile==InputSource.PROFILE and fixture.case_count==774 and fixture.cases.size()==774,"All774 whole original procedure cases are present")
	check(fixture.source_executable_sha256==InputSource.SOURCE_EXE_SHA256 and fixture.source_assembly_sha256=="d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a","Original uploaded EXE and reviewed source identities are explicit")
	check(fixture.fresh_process_runs==3 and fixture.reverse_repeat_cases==774 and fixture.consecutive_native_steps==64 and fixture.all_full_root_body_and_canary_checks_passed and fixture.root_aliases_share_one_backing_store and not fixture.expected_arithmetic_calculated_in_python,"Fresh and reversed native runs verify full raw root ownership and original expected arithmetic")
	var sequence_body:=PackedByteArray();var sequence_root:=PackedByteArray();var sequence_globals:Dictionary={};var first:Dictionary={}
	for row:Dictionary in fixture.cases:
		var label:=str(row.name);var body:=str(row.body_before_hex).hex_decode();var root:=root_for(row);var original:=var_to_bytes([body,root,row.globals_before])
		var expected:Dictionary=row.expected;var expected_body:=str(expected.body_after_hex).hex_decode();var expected_root:=root.duplicate();patch(expected_root,expected.root_after_changes)
		var result:=execute_row(row,body,root);operations[str(row.operation)]=true;native_cases+=1
		if first.is_empty():first=row
		check(result.ok,"Original input procedure executes: "+label)
		if not result.ok:continue
		check(result.body_after==expected_body,"Full338-byte body matches original instructions: "+label+" "+differences(result.body_after,expected_body))
		check(result.root_after==expected_root and byte_hash(result.root_after)==expected.root_after_sha256,"Full16KiB root matches original and retains all untouched bytes: "+label+" "+differences(result.root_after,expected_root))
		check(digest(result.globals_after)==digest(expected.globals_after),"All external nonroot source globals match: "+label)
		check(digest(result.requests)==digest(expected.requests),"GUI raw response and F931 mode/body requests match: "+label)
		check(result.source_order==expected.source_order and int(result.value_u32)==int(expected.value_u32),"Actual original procedure order and F1121 raw result match: "+label)
		check(not result.live_owners_changed and not result.GUI_input_collected and not result.F931_effects_executed and not result.JJFFE_key_path_selected and not result.full_player_cycle,"Original input scope remains explicit: "+label)
		check(var_to_bytes([body,root,row.globals_before])==original,"All caller-owned body/root/globals remain unchanged: "+label)
		var cold:Dictionary=JSON.parse_string(JSON.stringify(row));var again:=execute_row(cold)
		check(again.ok and again.body_after==result.body_after and again.root_after==result.root_after and digest(again.requests)==digest(result.requests),"Cold JSON context preserves original raw input continuation: "+label)
		for request:Dictionary in result.requests:
			if request.kind=="F1445":gui_cases+=1
			elif request.kind=="F931":f931_cases+=1
		if row.has("sequence_step"):
			if int(row.sequence_step)==0:sequence_body=body.duplicate();sequence_root=root.duplicate();sequence_globals=row.globals_before.duplicate(true)
			check(int(row.sequence_step)==sequence_cases and body==sequence_body and root==sequence_root and digest(row.globals_before)==digest(sequence_globals),"Consecutive input begins at previous actual native output: "+label)
			var continued:=execute_row(row,sequence_body,sequence_root,sequence_globals)
			check(continued.ok and continued.body_after==expected_body and continued.root_after==expected_root,"Consecutive actual runtime retains throttle and raw word residues: "+label)
			if continued.ok:sequence_body=continued.body_after;sequence_root=continued.root_after;sequence_globals=continued.globals_after
			sequence_cases+=1
	check(operations.size()==5 and gui_cases>0 and f931_cases>0 and sequence_cases==64,"All five procedures, callback boundaries and64 actual consecutive inputs are exercised")
	if not first.is_empty():
		var body:=str(first.body_before_hex).hex_decode();var root:=root_for(first);var globals:Dictionary=first.globals_before;var frozen:=var_to_bytes([body,root,globals])
		for bad:Variant in [null,true,{},[],1,"body",PackedByteArray()]:check(not InputSource.execute("throttle_f1037",bad,root,globals).ok,"Malformed body rejects")
		for bad:Variant in [null,true,{},[],1,"root",PackedByteArray()]:check(not InputSource.execute("throttle_f1037",body,bad,globals).ok,"Malformed raw root rejects")
		for bad:Variant in [null,true,[],1,"globals"]:check(not InputSource.execute("throttle_f1037",body,root,bad).ok,"Malformed external globals reject")
		for key:String in InputSource.GLOBAL_KEYS:
			var invalid:=globals.duplicate(true);invalid.erase(key);check(not InputSource.execute("throttle_f1037",body,root,invalid).ok,"Missing original external global rejects: "+key)
		for bad:Variant in [NAN,INF,true,0.5,"0",-1,0x100000000]:
			var invalid:=globals.duplicate(true);invalid.system_frame_ticks_u32=bad;check(not InputSource.execute("throttle_f1037",body,root,invalid).ok,"Invalid unsigned system ticks reject")
		for bad:Variant in [NAN,INF,true,0.5,"0",-129,128]:
			var invalid:=globals.duplicate(true);invalid.input_gate_s8=bad;check(not InputSource.execute("throttle_f1037",body,root,invalid).ok,"Invalid signed input gate rejects")
		for bad:Variant in [NAN,INF,true,0.5,"0",-1,256]:
			var invalid:=globals.duplicate(true);invalid.forward_key_u8=bad;check(not InputSource.execute("throttle_f1037",body,root,invalid).ok,"Invalid original key byte rejects")
		for bad:Variant in [NAN,INF,true,0.5,"0",-1,0x100000000]:check(not InputSource.execute("throttle_f1037",body,root,globals,bad).ok,"Invalid raw GUI accumulator response rejects")
		for bad:Variant in [NAN,INF,true,0.5,"0",-0x80000001,0x80000000]:check(not InputSource.execute("speed_increment_f1121",body,root,globals,0,bad).ok,"Invalid signed F1121 speed input rejects")
		var invalid:=globals.duplicate(true);invalid.view_mode_u8=2;check(not InputSource.execute("view_f1039",body,root,invalid).ok,"A duplicate root alias cannot be supplied as an external global")
		for bad:Variant in [null,true,0,"input","","F1038"]:check(not InputSource.execute(bad,body,root,globals).ok,"Unknown procedure rejects")
		check(var_to_bytes([body,root,globals])==frozen,"Malformed inputs preserve all caller-owned raw data")
		var result:=execute_row(first,body,root,globals);result.body_after[0]=int(result.body_after[0])^255;result.root_after[0]=int(result.root_after[0])^255;result.globals_after.input_gate_s8=4
		check(var_to_bytes([body,root,globals])==frozen,"Returned body/root/globals never alias caller-owned inputs")
	var sources:Dictionary={}
	for path:String in ["scripts/source_player_input.gd","tests/test_source_player_input.gd","tools/rebuild_source_player_input_native.py","tests/fixtures/source_player_input_native.json","validation/player-cycle-2026-11-17/input-native-proof/instruction-proof.json","validation/player-cycle-2026-11-17/input-native-proof/source-procedures.s"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"schema":1,"profile":InputSource.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"GUI_observer_cases":gui_cases,"F931_request_cases":f931_cases,"consecutive_actual_inputs":sequence_cases,"sources":sources,"live_Main_changed":false,"Android_input_proven":false,"full_player_cycle":false,"F931_effects_executed":false,"scope":fixture.scope},"\t"));file.close()
	print("SOURCE PLAYER INPUT TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
