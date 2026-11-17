extends SceneTree
const Dispatch=preload("res://scripts/source_frame_dispatch.gd")
const FIXTURE:="res://tests/fixtures/source_frame_dispatch_native.json"
const FIXTURE_SHA:="1c6a82c85c1ef45f230684ba653d856a64cdf89d93e199e3cce42ab99cf7499d"
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<24:push_error(message)
func same(first:Variant,second:Variant)->bool:
	# JSON fixture numbers are Float64 while the source kernel returns integer
	# words. Compare the exact admitted words without imposing Variant identity.
	if first is Dictionary and second is Dictionary:
		if first.size()!=second.size():return false
		for key:Variant in first:
			if not second.has(key) or not same(first[key],second[key]):return false
		return true
	if first is Array and second is Array:
		if first.size()!=second.size():return false
		for index in range(first.size()):
			if not same(first[index],second[index]):return false
		return true
	if (first is int or first is float) and (second is int or second is float):return first==second
	return first==second
func objects(row:Dictionary,key:String="objects_by_index")->Dictionary:
	var result:Dictionary={}
	for index:Variant in row[key]:result[int(index)]=str(row[key][index]).hex_decode()
	return result
func invoke(row:Dictionary)->Dictionary:
	return Dispatch.dispatch(str(row.player_hex).hex_decode(),objects(row),str(row.flags_hex).hex_decode(),row.globals,row.frame_ticks_u32,row.source_frame_byte,row.trace,row.enabled)
func run()->void:
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"The native whole-caller bank is pinned")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.get("schema")=="starfrontier-source-frame-dispatch-native-v1" and fixture.get("profile")==Dispatch.PROFILE and fixture.cases.size()>0,"Whole original F568/F569/F570 controls use the declared DOS profile")
	check(fixture.source_executable_sha256==Dispatch.SOURCE_EXE_SHA256 and int(fixture.case_count)==fixture.cases.size() and int(fixture.fresh_process_runs)==3 and int(fixture.reverse_repeat_cases)==fixture.cases.size() and fixture.all_owner_canaries_unchanged and not fixture.expected_arithmetic_computed_in_Python,"Original instruction controls are byte-pinned, fresh/reverse/canary checked and not calculated in the port")
	var callbacks:=0;var rotations:=0;var cache_cases:=0;var cache_records:=0;var enabled_modes:Dictionary={}
	var trace_row:Dictionary={}
	for row:Dictionary in fixture.cases:
		var frozen:=var_to_bytes(row)
		var result:=invoke(row)
		check(result.get("ok",false),"Native caller admits "+str(row.name))
		if not result.get("ok",false):continue
		check(result.body.hex_encode()==row.expected.player_hex,"Entire338-byte player equals actual source caller "+str(row.name))
		check(result.objects_by_index.size()==row.expected.objects_by_index.size(),"Indexed caller output retains every supplied object "+str(row.name))
		for index:Variant in row.expected.objects_by_index:
			check(result.objects_by_index.has(int(index)) and result.objects_by_index[int(index)].hex_encode()==row.expected.objects_by_index[index],"Whole object/cache bytes equal source output "+str(row.name)+"/"+str(index))
		check(result.flags.hex_encode()==row.flags_hex,"F570 preserves caller's bank flags "+str(row.name))
		check(same(result.globals_after,row.expected.globals),"All contact globals including preserved history equal source caller "+str(row.name))
		check(same(result.outputs,row.expected.outputs),"ReturnAL and all five source output arguments match "+str(row.name))
		check(result.trace_consumed==row.trace.size(),"Only the observed source classifier calls are consumed "+str(row.name))
		check(not result.F575_body_executed and not result.full_collision_classifier and not result.live_owners_changed and not result.clock_advanced and not result.complete_original_flight_pipeline,"Caller and observed classifier scopes stay explicit")
		check(var_to_bytes(row)==frozen,"Source dispatch never rewrites a fixture or callback witness")
		callbacks+=row.trace.size();enabled_modes[bool(row.enabled)]=true
		if str(row.player_hex).hex_decode()[0x57]!=result.body[0x57]:rotations+=1
		var original_objects:=objects(row)
		var cache_changed:=false
		for index:Variant in original_objects:
			if original_objects[index].slice(0x25,0x3e)!=result.objects_by_index[index].slice(0x25,0x3e):cache_changed=true;cache_records+=1
		if cache_changed:cache_cases+=1
		if trace_row.is_empty() and not row.trace.is_empty():trace_row=row
	check(callbacks>0 and rotations>0 and cache_cases>0 and enabled_modes.size()==2,"Native controls exercise classifier calls, real frame rotations, cache effects and both source wrappers")
	check(callbacks==int(fixture.observed_F575_callbacks) and rotations==int(fixture.actual_frame_conversion_cases) and cache_cases==int(fixture.candidate_cache_byte_change_cases) and cache_records==int(fixture.candidate_cache_byte_record_changes),"Observed call/rotation/cache-window counts match native metadata without counting response edits as cache writes")
	check(not trace_row.is_empty(),"At least one native callback observation is available for rejection tests")
	if trace_row.is_empty():quit(1);return
	var player:=str(trace_row.player_hex).hex_decode();var bank:=objects(trace_row);var flags:=str(trace_row.flags_hex).hex_decode();var history:Dictionary=trace_row.globals.duplicate(true);var trace:Array=trace_row.trace.duplicate(true)
	var input_before:=var_to_bytes([player,bank,flags,history,trace])
	var baseline:=invoke(trace_row)
	for bad:Variant in [null,true,[],{},"raw",PackedByteArray()]:
		check(not Dispatch.dispatch(bad,bank,flags,history,trace_row.frame_ticks_u32,trace_row.source_frame_byte,trace,trace_row.enabled).ok,"Invalid player container rejects")
		check(not Dispatch.dispatch(player,bad,flags,history,trace_row.frame_ticks_u32,trace_row.source_frame_byte,trace,trace_row.enabled).ok,"Invalid raw bank container rejects")
		check(not Dispatch.dispatch(player,bank,bad,history,trace_row.frame_ticks_u32,trace_row.source_frame_byte,trace,trace_row.enabled).ok,"Invalid bank flags reject")
		check(not Dispatch.dispatch(player,bank,flags,bad,trace_row.frame_ticks_u32,trace_row.source_frame_byte,trace,trace_row.enabled).ok,"Invalid contact globals reject")
		check(not Dispatch.dispatch(player,bank,flags,history,trace_row.frame_ticks_u32,trace_row.source_frame_byte,bad,trace_row.enabled).ok,"Invalid observation container rejects")
	for bad:Variant in [-1,true,0x100000000,NAN,INF,0.5,"1"]:
		check(not Dispatch.dispatch(player,bank,flags,history,bad,trace_row.source_frame_byte,trace,trace_row.enabled).ok,"Invalid raw frame ticks reject without truncation")
	for bad:Variant in [-1,true,256,NAN,INF,0.5,"1"]:
		check(not Dispatch.dispatch(player,bank,flags,history,trace_row.frame_ticks_u32,bad,trace,trace_row.enabled).ok,"Invalid source frame stamp rejects")
	for bad:Variant in [null,1,0,"true",[],{}]:check(not Dispatch.dispatch(player,bank,flags,history,trace_row.frame_ticks_u32,trace_row.source_frame_byte,trace,bad).ok,"Wrapper flag must be explicitly boolean")
	check(not Dispatch.dispatch(player,bank,flags,history,trace_row.frame_ticks_u32,trace_row.source_frame_byte,trace,trace_row.enabled,"jjffe-fixed").ok,"A different instruction profile cannot silently replace DOS")
	var malformed_history:=history.duplicate(true);malformed_history.erase("altitude_high_s32")
	check(not Dispatch.dispatch(player,bank,flags,malformed_history,trace_row.frame_ticks_u32,trace_row.source_frame_byte,trace,trace_row.enabled).ok,"Missing preserved altitude HIGH is not silently zeroed")
	malformed_history=history.duplicate(true);malformed_history.extra=0
	check(not Dispatch.dispatch(player,bank,flags,malformed_history,trace_row.frame_ticks_u32,trace_row.source_frame_byte,trace,trace_row.enabled).ok,"Unknown global field rejects")
	for key:String in Dispatch.GLOBAL_KEYS:
		malformed_history=history.duplicate(true);malformed_history[key]=true
		check(not Dispatch.dispatch(player,bank,flags,malformed_history,trace_row.frame_ticks_u32,trace_row.source_frame_byte,trace,trace_row.enabled).ok,"Boolean raw word rejects: "+key)
	var corrupt:=trace.duplicate(true);corrupt[0].subject_before_hex="00".repeat(338)
	check(not Dispatch.dispatch(player,bank,flags,history,trace_row.frame_ticks_u32,trace_row.source_frame_byte,corrupt,trace_row.enabled).ok,"Classifier witness cannot replace its full subject input")
	corrupt=trace.duplicate(true);corrupt[0].relative_before_hex="ff".repeat(24)
	check(not Dispatch.dispatch(player,bank,flags,history,trace_row.frame_ticks_u32,trace_row.source_frame_byte,corrupt,trace_row.enabled).ok,"Classifier witness must match the actual source relative vector")
	corrupt=trace.duplicate(true);corrupt[0].globals_before.altitude_high_s32=int(corrupt[0].globals_before.altitude_high_s32)^1
	check(not Dispatch.dispatch(player,bank,flags,history,trace_row.frame_ticks_u32,trace_row.source_frame_byte,corrupt,trace_row.enabled).ok,"A witness cannot substitute previous caller globals")
	for offset:int in [0x56,0x57,0x86]:
		corrupt=trace.duplicate(true);var raw:=str(corrupt[0].subject_after_hex).hex_decode();raw[offset]=raw[offset]^1;corrupt[0].subject_after_hex=raw.hex_encode()
		check(not Dispatch.dispatch(player,bank,flags,history,trace_row.frame_ticks_u32,trace_row.source_frame_byte,corrupt,trace_row.enabled).ok,"Observed F575 response cannot own identity/frame field %x"%offset)
	corrupt=trace.duplicate(true);corrupt.append(trace[0].duplicate(true))
	check(not Dispatch.dispatch(player,bank,flags,history,trace_row.frame_ticks_u32,trace_row.source_frame_byte,corrupt,trace_row.enabled).ok,"Unused classifier observations are not silently accepted")
	check(not Dispatch.dispatch(player,bank,flags,history,trace_row.frame_ticks_u32,trace_row.source_frame_byte,[],trace_row.enabled).ok,"Missing classifier observations reject before publication")
	var corrupt_player:=player.duplicate();corrupt_player[0x86]=0
	check(not Dispatch.dispatch(corrupt_player,bank,flags,history,trace_row.frame_ticks_u32,trace_row.source_frame_byte,trace,trace_row.enabled).ok,"Invalid own object index rejects")
	corrupt_player=player.duplicate();corrupt_player[0x56]=corrupt_player[0x86]
	check(not Dispatch.dispatch(corrupt_player,bank,flags,history,trace_row.frame_ticks_u32,trace_row.source_frame_byte,trace,trace_row.enabled).ok,"Cyclic hierarchy rejects before F1677 recursion")
	var wrong_flags:=flags.duplicate();var absent:=0
	for index in range(1,115):
		if index!=int(player[0x86]) and not bank.has(index):absent=index;break
	if absent:
		wrong_flags[absent]=wrong_flags[absent]|4
		check(not Dispatch.dispatch(player,bank,wrong_flags,history,trace_row.frame_ticks_u32,trace_row.source_frame_byte,trace,trace_row.enabled).ok,"An admitted collision slot needs a real matching raw record")
	check(var_to_bytes([player,bank,flags,history,trace])==input_before,"Every rejected candidate leaves all live input owners untouched")
	baseline.body[0]=baseline.body[0]^255
	for index:Variant in baseline.objects_by_index:baseline.objects_by_index[index][0]=baseline.objects_by_index[index][0]^255
	check(var_to_bytes([player,bank,flags,history,trace])==input_before,"Returned records and caches are independent copies")
	var source_pins:Dictionary={}
	for path:String in ["scripts/source_frame_dispatch.gd","scripts/source_reference_bank.gd","scripts/source_frame_kinematics.gd","scripts/ground_coordinates.gd","scripts/source_gravity.gd","scripts/source_motion_pipeline.gd","scripts/source_orbit.gd","tests/test_source_frame_dispatch.gd","tests/fixtures/source_frame_dispatch_native.json","tools/rebuild_source_frame_dispatch_native.py","validation/player-dispatch-2026-11-17/frame-native-proof/instruction-proof.json","validation/player-dispatch-2026-11-17/frame-native-proof/source-procedures.asm","validation/player-dispatch-2026-11-17/frame-native-proof/frame-dispatch-observed-kernel.s"]:source_pins[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/current-test-reports"))
	var file:=FileAccess.open("res://build/current-test-reports/source-frame-dispatch.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"checks":checks,"failures":failures,"sources":source_pins,"native_cases":fixture.cases.size(),"observed_classifier_calls":callbacks,"actual_rotation_cases":rotations,"actual_cache_write_cases":cache_cases,"actual_cache_byte_record_changes":cache_records,"scope":"Whole original DOS F568/F569/F570 caller control with actual independently controlled F572/F573 and F1677 cache arithmetic. Each F575 request is matched against full raw input/globals and literal observed afterstate; F575 classifier/response VM is not executed. Cache metrics compare only actual +25..+3D bytes, excluding scripted contact response edits. No original allocation/cadence/player dispatcher/Main/Android/full-clone claim."},"\t"));file.close()
	print("SOURCE FRAME DISPATCH TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
