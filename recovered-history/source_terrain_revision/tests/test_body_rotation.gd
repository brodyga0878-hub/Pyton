extends SceneTree
const Rotation=preload("res://scripts/body_rotation.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=10:push_error(message)
func _init()->void:call_deferred("run")
func integers(values:Array)->PackedInt64Array:
	var result:=PackedInt64Array()
	for value in values:result.append(int(value))
	return result
func run()->void:
	var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/body_rotation_reference.json"))
	check(reference.schema==1 and reference.cases.size()==1400,"Reference contains all 1400 native cases")
	var updates:=0;var station_updates:=0;var frozen_raw:=0;var frozen_ground:=0
	var bytes_seen:Dictionary={}
	for index in range(reference.cases.size()):
		var row:Dictionary=reference.cases[index]
		var raw:=int(row.rotation_raw);bytes_seen[raw]=true
		var initial:PackedInt64Array=Rotation.initialize(raw,int(row.tilt_i16),int(row.old_tick_u32))
		var expected_initial:=integers(row.initial_matrix_q31)
		# The F880 snippet initializes at the old tick before the F866 advance.
		check(initial==expected_initial,"Initial matrix matches original F880/F1675 case %d"%index)
		var initial_arguments:Vector2i=Rotation.initial_arguments(raw,int(row.tilt_i16),int(row.old_tick_u32))
		check(initial_arguments==Vector2i(int(row.initial_args_i32[0]),int(row.initial_args_i32[1])),"Initializer uses exact signed-byte shift case %d"%index)
		var before:=initial.duplicate()
		var result:Dictionary=Rotation.advance(initial,raw,int(row.tilt_i16),int(row.flags_u8),int(row.old_tick_u32),int(row.new_tick_u32),int(row.old_day_u32),int(row.new_day_u32))
		check(initial==before,"Spin update does not mutate its input case %d"%index)
		check(result.matrix==integers(row.updated_matrix_q31),"Updated matrix matches original F866/F1675 case %d"%index)
		check(result.matrix_update_calls==int(row.matrix_update_calls) and result.updated==bool(int(row.matrix_update_calls)),"Original bucket update decision case %d"%index)
		check(result.stored_tick_u32==int(row.stored_tick_u32) and result.stored_day_u32==int(row.stored_day_u32),"Every branch stores both timestamps case %d"%index)
		check(int(result.animation_requested)==int(row.animation_stub_calls) and int(result.orbital_phase_requested)==int(row.zero_phase_stub_calls),"Animation/orbit branch eligibility case %d"%index)
		if row.updated_args_i32==null:
			check(result.arguments==null,"No matrix arguments for unchanged branch case %d"%index)
		else:
			check(result.arguments==Vector2i(int(row.updated_args_i32[0]),int(row.updated_args_i32[1])),"Station branch swaps original matrix arguments case %d"%index)
			updates+=1
			if int(row.flags_u8)&0x10:station_updates+=1
		if raw==0:frozen_raw+=1
		if int(row.flags_u8)&0x20:frozen_ground+=1
	check(bytes_seen.size()==256,"All 256 encoded rotation bytes were exercised")
	check(updates==682 and station_updates>0 and frozen_raw>0 and frozen_ground>0,"Reference covers update, station, raw-zero and ground branches")
	# Boundary widths are part of the source ABI, not floating-angle approximations.
	for raw in [0,1,17,31,32,33,127,128,255]:
		check(Rotation.initialize(raw,65535,0xffffffff)==Rotation.initialize(raw+256,-1,-1),"Initializer masks raw byte, tilt word and unsigned tick widths")
	var sentinel:=PackedInt64Array([11,22,33,44,55,66,77,88,99])
	var unchanged:Dictionary=Rotation.advance(sentinel,0,0,0,-1,0x100000003,0,0x100000004)
	check(unchanged.matrix==sentinel and unchanged.stored_tick_u32==3 and unchanged.stored_day_u32==4,"Frozen body preserves arbitrary prior matrix and wraps stored timestamps")
	unchanged.matrix[0]=-1
	check(sentinel[0]==11,"Returned unchanged matrix has independent storage")
	print("BODY ROTATION TESTS: %d checks, %d failures; %d native cases, %d updates"%[checks,failures,reference.cases.size(),updates])
	quit(1 if failures else 0)
