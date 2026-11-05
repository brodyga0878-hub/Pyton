extends SceneTree
# Full integer results come from independently executed pinned source functions.
const Orbit=preload("res://scripts/source_orbit.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=20:push_error(message)
func same_words(actual:Variant,expected:Variant)->bool:
	if actual.size()!=expected.size():return false
	for index in range(actual.size()):
		if (actual[index] is Array or actual[index] is PackedInt64Array):
			if not same_words(actual[index],expected[index]):return false
		elif int(actual[index])!=int(expected[index]):return false
	return true
func run()->void:
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_orbit_native.json"))
	check(fixture is Dictionary,"Native source-orbit fixture exists")
	if not fixture is Dictionary:quit(1);return
	check(fixture.revision=="source-orbit-native-jjffe-q31-v1" and fixture.source_variant==Orbit.SOURCE_VARIANT,"Position backend explicitly identifies the pinned JJFFE variant")
	check(fixture.source_sha256=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72" and fixture.source_commit=="7e540341d4e09aa3c92877b87d49e7f2c143ad8d","Native controls pin executable and reviewed source")
	check(int(fixture.fresh_process_runs)==3 and int(fixture.reverse_repeat_count)==fixture.cases.size() and fixture.object_canaries_unchanged and fixture.non_target_object_bytes_unchanged,"Native controls repeated freshly and in reverse with untouched object memory")
	check(int(fixture.case_count)==fixture.cases.size() and int(fixture.source_record_context_count)>0,"Fixture includes independently finalized real-world records")
	var source_rows:=0;var synthetic:=0;var zero_periods:=0
	for index in range(fixture.cases.size()):
		var row:Dictionary=fixture.cases[index];var expected:Dictionary=row.expected
		var record:PackedByteArray=str(row.record_hex).hex_decode();var immutable:=record.duplicate()
		var result:=Orbit.initialize(record,row.tick_u32,row.day_u32)
		check(not result.is_empty(),"Native context accepted %d"%index)
		if result.is_empty():continue
		check(record==immutable,"Source record remains byte-identical %d"%index)
		check(int(result.rate_u32)==int(expected.rate_u32),"Original F880/F1494 rate matches %d"%index)
		check(same_words(result.phase_words,expected.phase_words),"Both original F880 phase words match, including initializer clock ordering %d"%index)
		check(same_words(result.position_words,expected.position_words),"All six original position words match %d"%index)
		check(same_words(result.increment_words,expected.increment_words),"Original interpolation increments match %d"%index)
		var signed_match:=true
		for axis in range(3):signed_match=signed_match and str(result.position_raw[axis])==str(expected.position_raw[axis])
		check(signed_match,"Signed64 positions retain exact native bits without JSON float conversion %d"%index)
		var delta:=Orbit.phase_delta(row.direct_rate_u32,row.old_tick_u32,row.old_day_u32,row.new_tick_u32,row.new_day_u32)
		check(same_words(delta,expected.phase_delta_words),"Native timestamp subtraction, multiplication and wrapping phase match %d"%index)
		var before:=var_to_bytes(result)
		var advanced:=Orbit.interpolate(result.position_words,result.increment_words,result.orbit_packed,row.interpolation_delta_u32)
		check(not advanced.is_empty() and same_words(advanced.position_words,expected.interpolated_position_words),"Both source F1508 fractional stages match %d"%index)
		check(var_to_bytes(result)==before,"Incremental evaluation leaves prior caller state untouched %d"%index)
		check(result.source_variant==fixture.source_variant,"Every result keeps explicit source variant %d"%index)
		if row.origin=="native F878 packed source record":source_rows+=1
		else:synthetic+=1
		if (record.decode_u32(20)&65535)==0:zero_periods+=1
	check(source_rows==int(fixture.source_record_context_count) and synthetic>=640 and zero_periods>0,"Real records, unusual register values and source zero-period roots are exercised")
	check(fixture.has("vector_add_cases") and int(fixture.vector_add_case_count)==fixture.vector_add_cases.size() and int(fixture.vector_add_fresh_process_runs)==3 and int(fixture.vector_add_reverse_repeat_count)==fixture.vector_add_cases.size(),"Parent vector controls execute original F1661 independently and repeat freshly/in reverse")
	for index in range(fixture.vector_add_cases.size()):
		var row:Dictionary=fixture.vector_add_cases[index]
		var parent:=PackedInt64Array();var relative:=PackedInt64Array()
		for axis in range(3):
			parent.append(Orbit.signed64(row.parent_words[axis]))
			relative.append(Orbit.signed64(row.relative_words[axis]))
		var parent_before:=parent.duplicate();var relative_before:=relative.duplicate()
		var absolute:=Orbit.add_positions(parent,relative)
		var actual_words:Array=[];var raw_match:=absolute.size()==3
		for axis in range(absolute.size()):
			actual_words.append([absolute[axis]&0xffffffff,(absolute[axis]>>32)&0xffffffff])
			raw_match=raw_match and str(absolute[axis])==str(row.expected_raw[axis])
		check(same_words(actual_words,row.expected_words) and raw_match,"Native F1661 parent sum retains all signed64 and carry bits %d"%index)
		check(parent==parent_before and relative==relative_before,"Parent addition leaves both caller vectors untouched %d"%index)
	check(Orbit.add_positions(PackedInt64Array([0,0]),PackedInt64Array([0,0,0])).is_empty() and Orbit.add_positions(PackedInt64Array([0,0,0]),PackedInt64Array()).is_empty(),"Parent addition rejects wrong vector lengths")
	check(fixture.has("epoch_update_cases") and int(fixture.epoch_update_case_count)==fixture.epoch_update_cases.size() and int(fixture.epoch_update_fresh_process_runs)==3 and int(fixture.epoch_update_reverse_repeat_count)==fixture.epoch_update_cases.size()*2 and fixture.epoch_single_step_matches_stepped,"Native epoch lifecycle executes actual F880/F866 slices freshly, in reverse and with an intermediate update")
	if fixture.has("epoch_update_cases"):
		for index in range(fixture.epoch_update_cases.size()):
			var row:Dictionary=fixture.epoch_update_cases[index];var expected:Dictionary=row.expected
			var record:PackedByteArray=str(row.record_hex).hex_decode();var unchanged:=record.duplicate()
			var initial:=Orbit.initialize(record,row.epoch_tick_u32,row.epoch_day_u32)
			var before:=var_to_bytes(initial)
			var result:=Orbit.advance(initial,row.tick_u32,row.day_u32)
			var absolute:=Orbit.evaluate_from_epoch(record,row.tick_u32,row.day_u32,row.epoch_tick_u32,row.epoch_day_u32)
			var intermediate:=Orbit.advance(initial,row.intermediate_tick_u32,row.intermediate_day_u32)
			var stepped:=Orbit.advance(intermediate,row.tick_u32,row.day_u32)
			check(not result.is_empty() and not absolute.is_empty(),"Source F880/F866 lifecycle accepts native context %d"%index)
			if result.is_empty() or absolute.is_empty():continue
			check(same_words(initial.phase_words,expected.initial_phase_words),"Actual F880 game-epoch phase matches before any ordinary update %d"%index)
			check(int(result.rate_u32)==int(expected.rate_u32) and same_words(result.phase_words,expected.phase_words),"F880 anchor plus ordinary F866 clock delta matches native phase %d"%index)
			check(same_words(result.position_words,expected.position_words) and same_words(result.increment_words,expected.increment_words),"F866 ordinary orbital recompute matches native full position/interpolation state %d"%index)
			var raw_match:=true
			for axis in range(3):raw_match=raw_match and str(result.position_raw[axis])==str(expected.position_raw[axis])
			check(raw_match,"Updated signed64 coordinates retain native bits %d"%index)
			check(same_words(absolute.phase_words,result.phase_words) and same_words(absolute.position_words,result.position_words),"Fixed epoch bridge matches source lifecycle without reinitializing at now %d"%index)
			check(not stepped.is_empty() and same_words(stepped.phase_words,expected.phase_words) and same_words(stepped.position_words,expected.position_words) and same_words(stepped.increment_words,expected.increment_words),"Intermediate frame partition matches independently verified native stepped lifecycle %d"%index)
			check(var_to_bytes(initial)==before and record==unchanged,"Advancing the orbit leaves prior state and record untouched %d"%index)
			check(int(result.clock_tick_u32)==int(row.tick_u32) and int(result.clock_day_u32)==int(row.day_u32) and int(result.anchor_tick_u32)==int(row.epoch_tick_u32) and int(result.anchor_day_u32)==int(row.epoch_day_u32),"Native clock words and fixed initializer anchor remain explicit %d"%index)
	var epoch_record:PackedByteArray=str(fixture.cases[10].record_hex).hex_decode()
	var source_epoch:=Orbit.evaluate_from_epoch(epoch_record,Orbit.SOURCE_EPOCH_TICK,Orbit.SOURCE_EPOCH_DAY)
	var source_initial:=Orbit.initialize(epoch_record,Orbit.SOURCE_EPOCH_TICK,Orbit.SOURCE_EPOCH_DAY)
	check(same_words(source_epoch.phase_words,source_initial.phase_words) and same_words(source_epoch.position_words,source_initial.position_words),"Game epoch bridge starts at the literal F880 initializer phase")
	var zero_epoch:=Orbit.initialize(epoch_record,0,0)
	var zero_advanced:=Orbit.advance(zero_epoch,Orbit.SOURCE_EPOCH_TICK,Orbit.SOURCE_EPOCH_DAY)
	var compatible:=Orbit.evaluate(epoch_record,Orbit.SOURCE_EPOCH_TICK,Orbit.SOURCE_EPOCH_DAY)
	check(same_words(zero_advanced.phase_words,compatible.phase_words),"evaluate remains the explicitly documented zero-epoch bridge")
	check(Orbit.advance({},0,0).is_empty() and Orbit.advance(source_initial,-1,0).is_empty(),"Malformed state and invalid update clock are rejected")
	var valid:PackedByteArray=str(fixture.cases[0].record_hex).hex_decode()
	for clock in [-1,4294967296,0.5,NAN,INF,"zero",true,null]:
		check(Orbit.evaluate(valid,clock,0).is_empty() and Orbit.evaluate(valid,0,clock).is_empty(),"Invalid clock words are rejected before computation")
	var ground:=valid.duplicate();ground.encode_u16(10,35)
	check(Orbit.evaluate(ground,0,0).is_empty(),"Ground-port positioning uses a different source path")
	var hanging:=valid.duplicate();hanging.encode_u16(20,0x8000)
	check(Orbit.evaluate(hanging,0,0).is_empty(),"Native F1496 nonterminating mantissa is rejected safely")
	hanging.encode_u16(20,0xffff)
	check(Orbit.evaluate(hanging,0,0).is_empty(),"Negative physical periods are outside the validated domain")
	check(Orbit.evaluate(PackedByteArray(),0,0).is_empty(),"Wrong record length is rejected")
	check(same_words(Orbit.phase_delta(1,0xffffffff,0,0,1),[8,0]),"One-tick carry between clock words is exact")
	check(same_words(Orbit.phase_delta(1,0,1,0xffffffff,0),[0xfffffff8,0xffffffff]),"Reverse one-tick phase retains modulo64 bits")
	check(same_words(Orbit.shift_words([0x01234567,0x89abcdef],64),[0,0x01234567]),"F1341 shifts beyond63 retain original masked word behavior")
	check(same_words(Orbit.shift_words([0x01234567,0x89abcdef],-64),[0x89abcdef,0xffffffff]),"F1341 negative shifts beyond63 sign-extend the original high word")
	print("SOURCE ORBIT TESTS: %d checks, %d failures; exact pinned JJFFE position/phase, not full DOS/SI physics"%[checks,failures])
	quit(1 if failures else 0)
