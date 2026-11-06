extends SceneTree
const Profile=preload("res://scripts/source_ship_control_profile.gd")
const Bridge=preload("res://scripts/source_physics_bridge.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func close(first:float,second:float)->bool:return absf(first-second)<1e-10
func _initialize()->void:
	var text:=FileAccess.get_file_as_string("res://tests/fixtures/source_cobra_control_native.json");var fixture:Dictionary=JSON.parse_string(text)
	check(text.sha256_text()=="80edd5969bbc728bce27a3cd676f06641adf75f89155cb8afced844baa2d02da","Actual source F601 native fixture is pinned")
	check(fixture.source_sha256==Profile.EXE_SHA and fixture.spec_sha256==Profile.SPEC_SHA,"Independent original EXE/specification provenance")
	check(fixture.fresh_process_runs==3 and fixture.reverse_repeat_count==18 and fixture.object_canaries_unchanged and fixture.nonvelocity_object_bytes_unchanged,"Native repeat ordering and original object write boundaries")
	check(fixture.source_f601_sha256=="4c15df920a586c72aa5cec09637db70cad61231c6d4c1da653278e3c668c0ab2","The actual reviewed original F601 instructions executed")
	var description:=Profile.describe("cobra")
	check(not description.is_empty() and description.profile==Profile.PROFILE,"Only named conservative Cobra38 profile is available")
	check(description.source_spec_hex==fixture.spec_hex and description.source_model_index==38,"Profile uses the exact original Cobra specification")
	check(description.source_mass_tonnes==100 and description.source_internal_capacity_tonnes==80,"Original source specification is retained as metadata without replacing adapted cargo")
	check(description.equipment_multiplier==1.0 and not description.original_controller,"No invented thrust booster or full controller claim")
	check(description.physics_bridge_contract==Bridge.CONTRACT and close(description.ticks_per_second,float(fixture.nominal_ticks_per_second)),"Thrust and gravity use the same explicit nominal-day bridge")
	check(close(description.velocity_unit_mps,float(fixture.velocity_unit_mps)) and description.reference_step_ticks==fixture.reference_step_ticks,"Original geometry velocity calibration and selected fixed reference step")
	var reference_count:=0;var expected_bound:=INF
	for row:Dictionary in fixture.cases:
		var initial:=str(row.initial_body_hex).hex_decode();var expected:=str(row.expected.body_hex).hex_decode()
		check(initial.size()==338 and expected.size()==338,"Every independent expected original object is complete")
		if int(row.step_ticks)==8:
			for q in row.expected.velocity_q16:check(int(q)==0,"Original tiny-step truncation is explicit, not fitted as a universal continuous controller")
		if int(row.step_ticks)!=Profile.REFERENCE_TICKS:continue
		var actual:Dictionary=description.source_axis_samples[reference_count];reference_count+=1
		var axis:=int(row.axis_index);var native_value:=float(row.expected.acceleration_mps2[axis]);expected_bound=minf(expected_bound,absf(native_value))
		check(actual.raw_thrust_s16==int(row.raw_thrust_s16),"Actual F1533 signed axis word selection")
		check(actual.velocity_s32==int(row.expected.velocity_s32[axis]) and actual.fraction_u16==int(row.expected.fraction_u16[axis]),"Exact original F601 integer velocity and fractional carry")
		check(actual.velocity_q16==int(row.expected.velocity_q16[axis]),"Exact native combined signed velocity sample")
		check(close(actual.acceleration_mps2,native_value),"Native nominal source axis acceleration")
	check(reference_count==6 and close(Profile.acceleration("cobra"),expected_bound),"Isotropic phone acceleration is bounded by all six original directions")
	check(close(expected_bound,70.25156725799762) and close(description.source_axis_samples[4].acceleration_mps2,200.7187635942789),"Independent native vertical and main numeric anchors")
	check(23.0<Profile.acceleration("cobra")*0.8,"Original23m/s2 port terrain is within the declared starter Cobra safety reserve")
	for id in ["","eagle","shuttle","Cobra","cobra38"]:check(Profile.acceleration(id)==0.0 and Profile.describe(id).is_empty(),"Other ship/loadout profiles remain outside this helper "+id)
	var snapshot:=var_to_bytes(description);var altered:=Profile.describe("cobra");altered.source_axis_samples[0].acceleration_mps2=0;altered.acceleration_mps2=0
	check(snapshot==var_to_bytes(Profile.describe("cobra")),"Caller cannot mutate the cached source profile or its nested samples")
	print("SOURCE COBRA CONTROL PROFILE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
