extends SceneTree
# Raw outputs originate in native F880/F603, unit expectations in exact Fraction.
const Bridge=preload("res://scripts/source_physics_bridge.gd")
const Gravity=preload("res://scripts/source_gravity.gd")
const Units=preload("res://scripts/source_units.gd")
const Clock=preload("res://scripts/source_clock.gd")
const FIXTURE:="res://tests/fixtures/source_physics_bridge_native.json"
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
func near(first:float,second:float,relative:=3e-14,absolute:=1e-18)->bool:
	return absf(first-second)<=maxf(absolute,maxf(absf(first),absf(second))*relative)
func triple_near(first:Variant,second:Variant,relative:=3e-14,absolute:=1e-18)->bool:
	if first.size()!=3 or second.size()!=3:return false
	for axis in range(3):
		if not near(float(first[axis]),float(second[axis]),relative,absolute):return false
	return true

func metadata(fixture:Dictionary)->void:
	check(fixture.get("schema")==1 and fixture.get("contract")==Bridge.CONTRACT,"Explicit sampled bridge contract")
	check(fixture.get("source_variant")==Gravity.SOURCE_VARIANT,"Native force variant remains explicit")
	check(fixture.get("source_sha256")=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72","Native bridge controls pin uploaded source EXE")
	check(fixture.get("source_assembly_sha256")=="d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a","Native bridge controls pin source assembly")
	check(fixture.reference_step_ticks==Bridge.REFERENCE_STEP_TICKS and Bridge.REFERENCE_STEP_TICKS==49710,"Reference49710ticks is not silently replaced by50000 or1second")
	check(Clock.TICKS_PER_DAY==0x100000000 and near(Bridge.TICKS_PER_SECOND,4294967296.0/86400.0),"Bridge uses the already-versioned nominal navigation day")
	check(near(Bridge.VELOCITY_UNIT_MPS,373.0/3840.0) and near(Bridge.VELOCITY_UNIT_MPS,Units.METRES_PER_RAW*Bridge.TICKS_PER_SECOND/512.0),"Exact rational nominal velocity unit agrees with source length and F1511scale")
	check(near(float(fixture.reference_duration_seconds),0.9999945759773254),"Reference interval is the explicit fractional nominal second")
	for pair in [["case_count","cases"],["coefficient_case_count","coefficient_cases"],["drift_case_count","drift_cases"]]:check(int(fixture.get(pair[0],0))==fixture.get(pair[1],[]).size() and fixture.get(pair[1],[]).size()>0,"Complete bridge native cases "+str(pair[1]))
	check(fixture.fresh_process_runs==3 and fixture.reverse_repeat_count==fixture.case_count and fixture.coefficient_reverse_repeat_count==fixture.coefficient_case_count and fixture.drift_reverse_repeat_count==fixture.drift_case_count,"Fresh native processes and reverse order reproduce")
	for key in ["object_canaries_unchanged","parent_bank_unchanged_except_coefficient","zero_sample_initial_velocity_and_fraction","normalization_quirks_preserved"]:check(fixture.get(key)==true,"Independent source boundary "+key)
	check(fixture.get("original_per_frame_dynamics")==false,"Sampled controller does not claim an original per-frame integrator")
	for path in fixture.input_fixtures_sha256:check(FileAccess.get_sha256("res://"+path)==str(fixture.input_fixtures_sha256[path]),"Native bridge input fixture remains pinned "+path)
	check(fixture.dos_f603_instruction_comparison.normalized_instruction_count==180 and fixture.dos_f603_instruction_comparison.pinned_f603_matches_uploaded_dos_instructions,"Complete F603 source instruction body matches uploaded DOS")

func samples(rows:Array)->void:
	var records:Dictionary={};var reasons:Dictionary={};var positive_ticks:Dictionary={}
	var positive_boundary:Dictionary={};var negative_boundary:Dictionary={}
	for row:Dictionary in rows:
		var record:=str(row.record_hex).hex_decode();var before:=record.duplicate();var point:=ints(row.relative_raw);var point_before:=point.duplicate()
		var result:=Bridge.sample_acceleration(record,point,int(row.reference_step_ticks))
		check(not result.is_empty(),"Sample source record "+str(row.name))
		if result.is_empty():continue
		check(result.source_body.hex_encode()==str(row.expected.body_hex),"Zero-state F603 full338byte result exact "+str(row.name))
		check(result.a4_u32==int(row.a4_native_u32) and result.velocity_s32==ints(row.expected.velocity_s32) and result.fraction_u16==ints(row.expected.fraction_u16),"Native F880 and velocity/fraction words exact "+str(row.name))
		check(result.delta_velocity_q16==ints(row.expected.delta_velocity_q16),"Signed48 velocity composition preserves negative fractional carry "+str(row.name))
		check(triple_near(result.delta_velocity_mps,row.expected.delta_velocity_mps) and triple_near(result.acceleration_mps2,row.expected.acceleration_mps2),"SI unit conversion agrees with independent exact rational output "+str(row.name))
		check(near(result.reference_duration_seconds,float(row.expected.reference_duration_seconds)) and near(result.gravity_mps2,float(row.expected.gravity_mps2)),"Duration and scalar surface gravity share the same sampled force "+str(row.name))
		var vector:Vector3=result.acceleration
		check(vector.is_finite() and near(vector.x,float(row.expected.acceleration_mps2[0]),2e-6,1e-20) and near(vector.y,float(row.expected.acceleration_mps2[1]),2e-6,1e-20) and near(vector.z,float(row.expected.acceleration_mps2[2]),2e-6,1e-20),"Finite Vector3 conversion occurs only after scalar double force calculation "+str(row.name))
		check(result.contract==Bridge.CONTRACT and result.original_per_frame_dynamics==false and result.normalization_quirks_preserved,"Every sample exposes controller and source boundaries")
		check(record==before and point==point_before,"Bridge never changes caller record or position "+str(row.name))
		var prepared:=Bridge.sample_prepared(int(row.a4_native_u32),point,int(row.reference_step_ticks))
		check(not prepared.is_empty() and prepared.source_body==result.source_body and prepared.acceleration_mps2==result.acceleration_mps2,"Prepared-coefficient API is the same original force kernel")
		if str(row.origin).begins_with("actual independently native F879"):
			var surface:=Bridge.surface_gravity(record,point,int(row.reference_step_ticks))
			check(not surface.is_empty() and surface.gravity_mps2==result.gravity_mps2 and surface.acceleration_mps2==result.acceleration_mps2,"Queried source surface and world use one force sample")
		result.relative_raw[0]=result.relative_raw[0]^1;result.source_body[0]=result.source_body[0]^1
		check(record==before and point==point_before,"Returned arrays cannot mutate a future sample or caller state")
		records[str(row.record_hex)]=true;reasons[str(result.source_trace.reason)]=true;positive_ticks[int(row.reference_step_ticks)]=true
		if row.name=="Earth normalization power32 offset0 sign1":positive_boundary=prepared
		elif row.name=="Earth normalization power32 offset0 sign-1":negative_boundary=prepared
	check(records.size()>=133,"Every distinct source F878 record domain is sampled, including zero-mass controls")
	check(reasons.has("zero_parent_mass") and reasons.has("zero_distance") and reasons.has("fractional_velocity") and reasons.has("integer_velocity"),"Sampler retains source guard and update branches")
	check(positive_ticks.has(49700) and positive_ticks.has(49710) and positive_ticks.has(50000),"Different timer policies remain distinct explicit sample arguments")
	check(not positive_boundary.is_empty() and not negative_boundary.is_empty() and positive_boundary.acceleration_mps2!=negative_boundary.acceleration_mps2,"Native signed64 normalization asymmetry is preserved")
	if not positive_boundary.is_empty() and not negative_boundary.is_empty():check(positive_boundary.gravity_mps2>0 and negative_boundary.gravity_mps2==0,"The exact source negative2^32 guard is not smoothed into a Newtonian law")

func drifts(rows:Array)->void:
	for row:Dictionary in rows:
		var body:=str(row.body_hex).hex_decode();var before:=body.duplicate();var result:=Gravity.integrate(body,ints(row.step_words))
		check(not result.is_empty() and result.body.hex_encode()==str(row.expected_body_hex),"Separate F1511/F1512 native motion proof "+str(row.name))
		check(result.position_raw==ints(row.expected_position_raw) and body==before,"Native drift remains exact and does not mutate caller")
		if row.step_words==[512.0,0.0] or row.step_words==[512,0]:
			for axis in range(3):check(result.position_raw[axis]==body.decode_s32(0x8c+axis*4),"At512ticks the source unit drift exactly calibrates velocity "+str(axis))
		if row.name=="unit policy drift ticks49710 velocity(1, 0, 0)":check(result.position_raw[0]==97,"Source per-step time quantization remains visible; sampled acceleration does not replace the raw integrator")

func invalid_inputs()->void:
	var record:=PackedByteArray();record.resize(68);record.fill(0);var original:=record.duplicate();var point:=PackedInt64Array([1,2,3]);var before:=point.duplicate()
	for bad in [null,true,"49710",0,-1,0.5,NAN,INF,-INF,2147483648]:check(Bridge.sample_acceleration(record,point,bad).is_empty() and Bridge.sample_prepared(0,point,bad).is_empty(),"Bad reference interval rejects atomically "+str(bad))
	for bad in [null,true,{},[],[0],[0,0],[0,0,0,0],[0,0,0.5],[0,0,NAN],[0,0,true],["0",0,0],Vector3.ZERO]:check(Bridge.sample_acceleration(record,bad).is_empty(),"Bad raw coordinate rejects atomically")
	for bad in [-1,4294967296,1.0,true,null,"0"]:check(Bridge.sample_prepared(bad,point).is_empty(),"Bad packed coefficient rejects")
	for size in [0,67,69]:
		var invalid:=PackedByteArray();invalid.resize(size)
		check(Bridge.sample_acceleration(invalid,point).is_empty(),"Bad record size rejects")
	for bad in [true,null,"1",NAN,INF,-INF,1e40,-1e40]:check(Bridge.raw_metres(bad).is_empty(),"Nonfinite or overflowing metre conversion rejects")
	for bad in [true,null,{},[],[1,2],[1,2,3,4],[1,2,NAN],[1,2,true],Vector3(INF,0,0)]:check(Bridge.relative_from_metres(bad).is_empty(),"Bad metre vector rejects")
	check(Bridge.relative_from_metres([0.0,Units.METRES_PER_RAW,-Units.METRES_PER_RAW])==PackedInt64Array([0,1,-1]),"Finite scalar metre conversion rounds to original integer geometry")
	check(Bridge.relative_from_metres(Vector3.ZERO)==PackedInt64Array([0,0,0]),"Finite Vector3 zero conversion accepted")
	check(record==original and point==before,"All invalid calls preserve original inputs")

func run()->void:
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not fixture is Dictionary:push_error("Missing independent source physics bridge fixture");quit(1);return
	metadata(fixture);samples(fixture.cases);drifts(fixture.drift_cases);invalid_inputs()
	print("SOURCE PHYSICS BRIDGE TESTS: %d checks, %d failures; native F603 samples and explicit nominal-day SI controller, not original per-frame dynamics"%[checks,failures])
	quit(1 if failures else 0)
