extends SceneTree
# New native orientation controls. This does not validate omitted F866 orbital
# or animation effects, the original clock epoch, or the live world adapter.
const Rotation=preload("res://scripts/body_rotation.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=12:push_error(message)
func ints(values:Array)->PackedInt64Array:
	var result:=PackedInt64Array()
	for value in values:result.append(int(value))
	return result
func _init()->void:call_deferred("run")
func run()->void:
	var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/rebuild_body_rotation_native.json"))
	check(reference.schema==1 and reference.revision=="rebuild-body-rotation-native-slice-v1","Distinct new fixture has an explicit orientation-only revision")
	check(reference.source_executable_sha256=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72" and reference.source_commit=="7e540341d4e09aa3c92877b87d49e7f2c143ad8d","Native inputs have pinned original binary and reviewed source provenance")
	check(reference.sine_bytes_verified_against_source and reference.fresh_process_reproduction_verified and int(reference.reversed_interleaving_checks)==reference.cases.size(),"Actual source table and independent/reversed native executions were checked")
	check(reference.cases.size()==1542,"All newly generated native cases are present, without claiming the lost1400-case fixture")
	var encoded_bytes:Dictionary={};var updates:=0;var unchanged:=0;var station_updates:=0;var overrides:=0
	for index in range(reference.cases.size()):
		var row:Dictionary=reference.cases[index]
		var raw:=int(row.rotation_raw);encoded_bytes[raw&255]=true
		var initial:=Rotation.initialize(raw,int(row.tilt_i16),int(row.old_tick_u32))
		check(initial==ints(row.initial_matrix_q31),"Native F880/F1675 initial matrix case%d"%index)
		check(Rotation.initial_arguments(raw,int(row.tilt_i16),int(row.old_tick_u32))==Vector2i(int(row.initial_args_i32[0]),int(row.initial_args_i32[1])),"Native signed-byte/word/shift arguments case%d"%index)
		var previous:PackedInt64Array=initial
		if row.previous_matrix_override!=null:
			previous=ints(row.previous_matrix_override);overrides+=1
		var untouched:=previous.duplicate()
		var result:Dictionary=Rotation.advance(previous,raw,int(row.tilt_i16),int(row.flags_u8),int(row.old_tick_u32),int(row.new_tick_u32),int(row.old_day_u32),int(row.new_day_u32))
		check(previous==untouched,"Pure update preserves caller matrix case%d"%index)
		check(result.matrix==ints(row.updated_matrix_q31),"Native F866 selected spin/F1675 matrix case%d"%index)
		check(int(result.matrix_update_calls)==int(row.matrix_update_calls) and result.updated==bool(int(row.matrix_update_calls)),"Native bucket decision and actual matrix call count case%d"%index)
		check(int(result.stored_tick_u32)==int(row.stored_tick_u32) and int(result.stored_day_u32)==int(row.stored_day_u32),"Native timestamp stores on every selected branch case%d"%index)
		if row.updated_args_i32==null:
			check(result.arguments==null,"No invented matrix arguments on frozen branch case%d"%index)
			unchanged+=1
		else:
			check(result.arguments==Vector2i(int(row.updated_args_i32[0]),int(row.updated_args_i32[1])),"Actual native station/body argument ordering case%d"%index)
			updates+=1
			if int(row.flags_u8)&0x10:station_updates+=1
	check(encoded_bytes.size()==256 and updates==int(reference.matrix_updates) and updates>0 and unchanged>0 and station_updates>0 and overrides>0,"Coverage includes every encoded rotation byte, frozen bodies, station swaps and arbitrary previous matrices")
	print("REBUILT BODY ROTATION TESTS: %d checks, %d failures; %d native orientation-slice cases"%[checks,failures,reference.cases.size()])
	quit(1 if failures else 0)
