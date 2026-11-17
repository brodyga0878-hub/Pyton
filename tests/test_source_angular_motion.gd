extends SceneTree
const Angular=preload("res://scripts/source_angular_motion.gd")
const FIXTURE:="res://tests/fixtures/source_angular_native.json"
const REPORT:="res://build/current-test-reports/source-angular-motion.json"
var checks:=0
var failures:=0
var evidence:Array=[]

func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)

func _initialize()->void:call_deferred("_run")

func _run()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.profile==Angular.PROFILE and fixture.source_executable_sha256==Angular.SOURCE_EXE_SHA256,"Native angular fixture uses the exact uploaded DOS source")
	check(not fixture.expected_arithmetic_calculated_in_python and fixture.fresh_process_runs==3 and fixture.reverse_repeat_cases==fixture.case_count and fixture.all_body_canaries_unchanged,"Expected angular bytes come from fresh/reversed original instruction executions with intact canaries")
	check(fixture.consecutive_original_steps==64,"Fixture includes consecutive original residual/matrix state rather than re-quantized phone poses")
	var operation_counts:Dictionary={};var previous_native:Dictionary={};var normalization_count:=0;var changing_residue_count:=0
	var pair_coverage:Dictionary={}
	for row:Dictionary in fixture.cases:
		var raw:PackedByteArray=str(row.body_before_hex).hex_decode();var before:=raw.duplicate();var context:Dictionary=row.globals_before.duplicate(true)
		var operation:=int(row.operation);var result:Dictionary={};operation_counts[str(operation)]=int(operation_counts.get(str(operation),0))+1
		match operation:
			0:
				result=Angular.step_raw(raw,row.budget_s32,row.accumulate,row.elapsed_ticks_s32,context)
			1:
				result=Angular.quantize_raw(row.budget_s32)
			2:
				result=Angular.rotate_pair_raw(raw,row.first_offset,row.second_offset,row.positive,row.shift_s32)
				pair_coverage["%s/%s/%s/%s"%[int(row.first_offset),int(row.second_offset),row.positive,int(row.shift_s32)]]=true
			3:
				result=Angular.spin_command_raw(raw,PackedInt64Array(row.spin_xyz_s32))
			4:
				result=Angular.orthonormalize_raw(raw)
		check(result.get("ok",false),"Original angular operation accepted: "+str(row.name))
		if not result.get("ok",false):continue
		if operation==1:
			check(result.amount_s32==int(row.quantized_amount_s32) and result.shift_s32==int(row.quantized_shift_s32),"FullF584 threshold/negative-domain parity: "+str(row.name))
		else:
			check(result.body_after.hex_encode()==str(row.body_after_hex),"Every raw body byte matches actual original instructions: "+str(row.name))
		if operation==0:
			check(int(result.globals_after.player_index_u32)==int(row.globals_after.player_index_u32) and int(result.globals_after.player_roll_s16)==int(row.globals_after.player_roll_s16),"Player roll wrapping and nonplayer isolation match original: "+str(row.name))
			normalization_count+=int(result.normalization_count)
			if before.decode_u16(0xb0)!=result.body_after.decode_u16(0xb0) or before.decode_u16(0xb2)!=result.body_after.decode_u16(0xb2) or before.decode_u16(0xb4)!=result.body_after.decode_u16(0xb4):changing_residue_count+=1
		check(raw==before and context==row.globals_before,"Angular prepare never changes caller-owned raw body or global state")
		if row.has("sequence_step"):
			var step:=int(row.sequence_step)
			if step>0:check(str(row.body_before_hex)==str(previous_native.body_after_hex) and row.globals_before==previous_native.globals_after,"Native consecutive trajectory continues exact previous raw state without quaternion reconstruction")
			previous_native=row
	check(operation_counts.keys().size()==fixture.case_counts_by_operation.keys().size(),"Every declared original angular operation is covered")
	for operation:String in operation_counts:check(int(operation_counts[operation])==int(fixture.case_counts_by_operation[operation]),"Every original angular case executes exactly once for operation "+operation)
	check(pair_coverage.size()==96,"F611 covers every directed pair, sign and source shift2..9")
	check(normalization_count>0 and changing_residue_count>0,"Actual fullF1520 branches and residual accumulation are exercised")
	var valid:PackedByteArray=str(fixture.cases[0].body_before_hex).hex_decode();var globals:Dictionary={"player_index_u32":0,"player_roll_s16":0};var source_before:=valid.duplicate()
	for invalid:Variant in [null,{},PackedByteArray(),"00"]:check(not Angular.step_raw(invalid,1,true,1,globals).ok,"Reject malformed raw angular owners")
	for invalid:Variant in [NAN,INF,-0x80000001,0x80000000,1.5,"1",null]:
		check(not Angular.step_raw(valid,invalid,true,1,globals).ok and not Angular.step_raw(valid,1,true,invalid,globals).ok,"Reject malformed or out-of-range source angular intervals")
	for invalid:Variant in [null,{},[0,0],{"player_index_u32":0},{"player_index_u32":-1,"player_roll_s16":0},{"player_index_u32":0,"player_roll_s16":32768}]:check(not Angular.step_raw(valid,1,true,1,invalid).ok,"Reject incomplete or unbounded angular global context")
	check(not Angular.step_raw(valid,1,1,1,globals).ok,"Accumulation admission is an explicit boolean")
	check(not Angular.rotate_pair_raw(valid,0,0,true,2).ok and not Angular.rotate_pair_raw(valid,0,12,true,1).ok and not Angular.rotate_pair_raw(valid,0,12,true,10).ok,"Unobserved or aliased F611 pair contexts are explicitly rejected")
	check(not Angular.spin_command_raw(valid,PackedInt64Array([0,0])).ok and not Angular.spin_command_raw(valid,PackedInt64Array([0,0,0x80000000])).ok,"F609 rejects malformed raw spin globals")
	check(valid==source_before,"All rejected angular operations preserve caller bytes")
	var cold:PackedByteArray=previous_native.body_after_hex.hex_decode();var encoded:=cold.hex_encode();var restored:=encoded.hex_decode()
	var a:=Angular.step_raw(cold,1000,true,1000,previous_native.globals_after);var b:=Angular.step_raw(restored,1000,true,1000,JSON.parse_string(JSON.stringify(previous_native.globals_after)))
	check(a.ok and b.ok and a.body_after==b.body_after and a.globals_after==b.globals_after,"Raw angular hex cold boundary preserves all residuals, matrix countdown and next actual interval")
	evidence.append({"case":"original_angular_operations","native_cases":fixture.case_count,"operation_counts":operation_counts,"directed_pair_shift_sign_contexts":pair_coverage.size(),"normalizations_exercised":normalization_count,"residue_changes":changing_residue_count,"consecutive_native_steps":64,"host_abi_adaptations":fixture.host_adaptations,"source_pipeline_caller_order_claimed":false})
	var sources:Dictionary={}
	for path:String in ["scripts/source_angular_motion.gd","scripts/source_ground_surface.gd","tests/test_source_angular_motion.gd","tests/fixtures/source_angular_native.json","tools/rebuild_source_angular_native.py","validation/reference-bank-2026-11-17/angular-native-proof/instruction-proof.json","validation/reference-bank-2026-11-17/angular-native-proof/source-procedures.s"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"checks":checks,"failures":failures,"sources":sources,"evidence":evidence,"scope":"Standalone whole originalF584/F585/F609/F611 angular raw-state operations, realF1520 normalization, signed16 residues/commands and32bit wrap arithmetic versus641 nativeDOS-checked instruction cases. Source scheduling/F1019/F1041 order, full object/frame bank and live Main/Android integration remain separate."},"\t"));file.close()
	print("Source angular motion: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
