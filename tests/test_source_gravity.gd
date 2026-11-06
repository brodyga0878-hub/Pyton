extends SceneTree
# Expectations are native instruction outputs, not formulas from this module.
const Gravity=preload("res://scripts/source_gravity.gd")
const FIXTURE:="res://tests/fixtures/source_gravity_native.json"
var checks:=0
var failures:=0

func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<25:push_error(message)
func ints(values:Variant)->PackedInt64Array:
	var result:=PackedInt64Array()
	for value in values:result.append(int(value))
	return result
func pairs_equal(actual:Array,expected:Array)->bool:
	if actual.size()!=expected.size():return false
	for axis in range(actual.size()):
		if ints(actual[axis])!=ints(expected[axis]):return false
	return true

func metadata(fixture:Dictionary)->void:
	check(fixture.get("schema")==1 and fixture.get("source_variant")==Gravity.SOURCE_VARIANT,"Native gravity schema and explicit source variant")
	check(fixture.get("source_sha256")=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72","Native controls pin uploaded DOS image")
	check(fixture.get("source_assembly_sha256")=="d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a" and fixture.get("source_commit")=="7e540341d4e09aa3c92877b87d49e7f2c143ad8d","Native controls pin reviewed JJFFE source")
	check(fixture.get("object_bytes")==Gravity.OBJECT_BYTES and fixture.get("object_bank_stride_bytes")==338 and fixture.get("object_bank_header_bytes")==116,"Native body layout and actual F1532 lookup stride")
	for entry in [["case_count","cases"],["mass_case_count","mass_cases"],["integration_case_count","integration_cases"]]:
		check(int(fixture.get(entry[0],0))==fixture.get(entry[1],[]).size() and int(fixture.get(entry[0],0))>100,"Complete native controls "+entry[1])
	check(fixture.get("fresh_process_runs",0)>=3 and fixture.get("reverse_repeat_count")==fixture.get("case_count") and fixture.get("mass_reverse_repeat_count")==fixture.get("mass_case_count") and fixture.get("integration_reverse_repeat_count")==fixture.get("integration_case_count"),"Fresh-process/reverse native runs agree")
	for key in ["object_canaries_unchanged","parent_bank_unchanged_except_mass_initializer","non_target_object_bytes_unchanged"]:check(fixture.get(key)==true,"Native memory boundary proof "+key)
	var observer:Dictionary=fixture.get("native_observation",{})
	check(observer.get("registers_and_flags_preserved")==true and observer.get("observed_matches_untouched_complete_outputs")==true,"Separately observed F603 preserves original full native output")
	var dos:Dictionary=fixture.get("dos_f603_instruction_comparison",{})
	check(dos.get("pinned_f603_matches_uploaded_dos_instructions")==true and dos.get("normalized_instruction_count")==180,"Complete pinned F603 instructions match uploaded DOS body")

func coefficient_controls(rows:Array)->void:
	for row:Dictionary in rows:
		var record:=str(row.record_hex).hex_decode();var before:=record.duplicate()
		var actual:=Gravity.coefficient(record)
		check(not actual.is_empty(),"F880 coefficient supported "+str(row.name))
		if actual.is_empty():continue
		check(int(actual.a4_u32)==int(row.expected_a4_u32),"F880 packed a4 exact "+str(row.name))
		check(record==before,"F880 coefficient leaves source record unchanged "+str(row.name))

func gravity_controls(rows:Array)->void:
	var reasons:Dictionary={};var changed:=0
	for row:Dictionary in rows:
		var body:=str(row.body_hex).hex_decode();var parent:=str(row.parent_hex).hex_decode()
		var before:=body.duplicate();var parent_before:=parent.duplicate();var scratch:=ints(row.initial_scratch_s32);var scratch_before:=scratch.duplicate()
		var actual:=Gravity.update(body,parent,row.step_s32,scratch)
		check(not actual.is_empty(),"F603 source context supported "+str(row.name))
		if actual.is_empty():continue
		check(actual.body.hex_encode()==str(row.expected.body_hex),"F603 all338 object bytes exact "+str(row.name)+" trace="+str(actual.trace))
		check(actual.velocity_s32==ints(row.expected.velocity_s32),"F603 complete signed32 velocity exact "+str(row.name))
		check(actual.fraction_u16==ints(row.expected.fraction_u16),"F603 three fractional words exact "+str(row.name))
		check(actual.scratch_s32==ints(row.expected.scratch_s32),"F603 debug vector and no-op sentinel exact "+str(row.name))
		for pair in [["truncate_shift","truncate_shift"],["norm_u32","norm_u32"],["distance_packed","radius_packed"],["square_packed","square_packed"],["cube_like_packed","cube_like_packed"],["factor_packed","ratio_packed"],["step_mantissa","normalized_step_s32"],["factor_s32","factor_s32"],["delta_exponent","final_exponent_s16"]]:
			if actual.trace.has(pair[0]):check(row.native_trace.has(pair[1]) and int(actual.trace[pair[0]])==int(row.native_trace[pair[1]]),"F603 original intermediate "+str(pair[1])+" "+str(row.name))
		var expected_path:=1 if actual.trace.reason=="fractional_velocity" else (2 if actual.trace.reason=="integer_velocity" else 0xffffffff)
		check(expected_path==int(row.native_trace.update_path),"F603 original branch marker "+str(row.name))
		check(body==before and parent==parent_before and parent.hex_encode()==str(row.expected.parent_hex) and scratch==scratch_before,"F603 leaves caller body, parent and scratch unchanged "+str(row.name))
		reasons[str(actual.trace.reason)]=true
		if actual.body!=body:changed+=1
		actual.body[0]=actual.body[0]^255
		check(body==before,"Returned F603 body is an independent copy "+str(row.name))
	check(changed>100,"Independent F603 controls exercise real velocity/fraction changes")
	for reason in ["no_parent","zero_parent_mass","zero_distance","fractional_underflow","fractional_velocity","integer_velocity"]:check(reasons.has(reason),"F603 native grid exercises "+reason)

func integration_controls(rows:Array)->void:
	for row:Dictionary in rows:
		var body:=str(row.body_hex).hex_decode();var before:=body.duplicate();var step:=ints(row.step_words);var step_before:=step.duplicate()
		var actual:=Gravity.integrate(body,step)
		check(not actual.is_empty(),"F1512 timestep supported "+str(row.name))
		if actual.is_empty():continue
		check(actual.body.hex_encode()==str(row.expected_body_hex),"F1512 all338 object bytes exact "+str(row.name))
		check(pairs_equal(actual.position_words,row.expected_position_words),"F1512 six coordinate words exact "+str(row.name))
		check(pairs_equal(actual.position_words,row.direct_f1511_position_words),"Direct F1511 and F1512 native outputs agree "+str(row.name))
		check(actual.position_raw==ints(row.expected_position_raw),"F1512 signed64 coordinates retain all bits "+str(row.name))
		check(body==before and step==step_before,"F1512 preserves caller object and timestep "+str(row.name))
		actual.body[0]=actual.body[0]^255
		check(body==before,"Returned F1512 object is an independent copy "+str(row.name))

func invalid_inputs()->void:
	var body:=PackedByteArray();body.resize(338);body.fill(91);var parent:=body.duplicate();var before:=body.duplicate()
	for step in [null,true,"1",0.5,NAN,INF,-INF,2147483648,-2147483649]:
		check(Gravity.update(body,parent,step).is_empty(),"F603 invalid signed32 timestep rejected "+str(step))
	for size in [0,67,337,339]:
		var invalid:=PackedByteArray();invalid.resize(size)
		check(Gravity.update(invalid,parent,1).is_empty() and Gravity.update(body,invalid,1).is_empty(),"F603 invalid object size rejected "+str(size))
		check(Gravity.integrate(invalid,[1,0]).is_empty(),"F1512 invalid object size rejected "+str(size))
	for scratch in [true,{},[],[0],[0,0],[0,0,0,0],[0,0,0.5],[0,0,NAN],[0,0,2147483648]]:check(Gravity.update(body,parent,1,scratch).is_empty(),"F603 malformed scratch rejected")
	for step in [null,true,{},[],[0],[0,0,0],[-1,0],[0,4294967296],[0,NAN],[0,true],["0",0],[0.5,0]]:check(Gravity.integrate(body,step).is_empty(),"F1512 invalid word pair rejected")
	for size in [0,67,69]:
		var record:=PackedByteArray();record.resize(size)
		check(Gravity.coefficient(record).is_empty(),"F880 invalid record size rejected "+str(size))
	check(body==before and parent==before,"Every rejected call preserves input objects")

func run()->void:
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not fixture is Dictionary:push_error("Missing independent native gravity fixture");quit(1);return
	metadata(fixture);coefficient_controls(fixture.mass_cases);gravity_controls(fixture.cases);integration_controls(fixture.integration_cases);invalid_inputs()
	print("SOURCE GRAVITY TESTS: %d checks, %d failures; native F603/F880-a4/F1511/F1512, raw units only"%[checks,failures])
	quit(1 if failures else 0)
