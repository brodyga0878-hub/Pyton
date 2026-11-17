extends SceneTree
const Core=preload("res://scripts/source_collision_planes.gd")
const FIXTURE:="res://tests/fixtures/source_collision_planes_native.json"
const FIXTURE_SHA:="d7de6044356b3554f2fcce60c7dffc2a3cff349283dd37b9b0145d11d98d7e95"
const REPORT:="res://build/current-test-reports/source-collision-planes.json"
var checks:=0
var failures:=0
var native_cases:=0
var values:Dictionary={}
var codes:Dictionary={}
var shift_counts:Dictionary={}
var equality_cases:=0
var mirror_combinations:Dictionary={}
var dependencies:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<24:push_error(message)
func fixture_context(raw:Dictionary)->Dictionary:
	return {"point_xyz_s32":raw.point_xyz_s32.duplicate(),"normals":str(raw.normals_hex).hex_decode(),"vertices":str(raw.vertices_hex).hex_decode(),"mesh_zoom_s32":raw.mesh_zoom_s32,"vector_scale_s32":raw.vector_scale_s32,"normal_origin_u32":raw.normal_origin_u32,"vertex_origin_u32":raw.vertex_origin_u32}
func base_context()->Dictionary:
	return {"point_xyz_s32":[0,0,0],"normals":PackedByteArray([0,0,1,0,0,0]),"vertices":PackedByteArray([0,0,0,0,0,0]),"mesh_zoom_s32":0,"vector_scale_s32":0}
func reject_tests()->void:
	var context:=base_context();var frozen:=var_to_bytes(context)
	for bad:Variant in [null,true,0,"raw",[],{},PackedByteArray()]:check(not Core.execute(bad,2,0).ok,"Malformed packed-plane context rejects")
	for key:String in Core.REQUIRED_KEYS:
		var copied:=context.duplicate(true);copied.erase(key)
		check(not Core.execute(copied,2,0).ok,"Missing raw context owner rejects: "+key)
	for key:String in ["mesh_zoom_s32","vector_scale_s32"]:
		for bad:Variant in [null,true,"0",NAN,INF,0.5,-0x80000001,0x80000000]:
			var copied:=context.duplicate(true);copied[key]=bad
			check(not Core.execute(copied,2,0).ok,"Invalid signed source scale rejects: "+key)
	for key:String in Core.OPTIONAL_KEYS:
		for bad:Variant in [null,true,"0",NAN,INF,0.5,-1,0x100000000]:
			var copied:=context.duplicate(true);copied[key]=bad
			check(not Core.execute(copied,2,0).ok,"Invalid logical raw-buffer origin rejects: "+key)
	for bad:Variant in [null,true,"0",NAN,INF,0.5,-1,256]:check(not Core.execute(context,bad,0).ok,"Invalid plane code rejects")
	for bad:Variant in [null,true,"0",NAN,INF,0.5,-0x80000001,0x80000000]:check(not Core.execute(context,2,bad).ok,"Invalid threshold rejects")
	for bad:Variant in [null,true,[],[0,0],[0,0,true],[0,0,0.5],[0,0,0x80000000]]:
		var copied:=context.duplicate(true);copied.point_xyz_s32=bad
		check(not Core.execute(copied,2,0).ok,"Invalid raw signed point rejects")
	for key:String in ["normals","vertices"]:
		for bad:Variant in [null,[],"000000000000",PackedByteArray(),PackedByteArray([0,0,0,0,0])]:
			var copied:=context.duplicate(true);copied[key]=bad
			check(not Core.execute(copied,2,0).ok,"Missing/truncated packed record rejects: "+key)
	var copied:=context.duplicate(true);copied.extra=0
	check(not Core.execute(copied,2,0).ok,"Unknown context owner rejects")
	check(Core.execute(context,2,0).ok,"Omitted optional origins mean actual pointer at buffer start")
	check(not Core.execute(context,0,0).ok and not Core.execute(context,1,0).ok,"No invented prefix for plane0/1 records before pointer")
	copied=context.duplicate(true);copied["normal_origin_u32"]=6
	check(Core.execute(copied,0,0).ok and Core.execute(copied,1,0).ok,"An explicit captured prefix makes preceding plane0/1 records available")
	copied=context.duplicate(true);copied.normals[0]=254
	check(not Core.execute(copied,2,0).ok,"Out-of-range referenced vertex fails before any geometry result")
	check(var_to_bytes(context)==frozen,"Malformed/prefix checks do not alter caller-owned raw buffers")
func run()->void:
	reject_tests()
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent complete DOS plane fixture is pinned")
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not fixture is Dictionary or not fixture.get("cases") is Array:
		check(false,"Actual native packed-plane controls required")
	else:
		check(fixture.profile==Core.PROFILE and fixture.source_executable_sha256==Core.SOURCE_EXE_SHA256 and int(fixture.case_count)==640 and fixture.cases.size()==640,"All640 original native controls present")
		check(fixture.fresh_process_runs==3 and fixture.reverse_repeat_cases==640 and fixture.all_raw_buffer_and_context_canaries_unchanged and not fixture.expected_arithmetic_calculated_in_python,"Fresh/reverse native executions preserve all raw buffers/context")
		dependencies=fixture.source_dependencies_sha256.duplicate(true)
		for path:String in dependencies:check(FileAccess.get_sha256("res://"+path)==dependencies[path],"Portable native dependency is pinned: "+path)
		for row:Dictionary in fixture.cases:
			var context:=fixture_context(row.context);var before:=var_to_bytes(context);var expected:Dictionary=row.expected
			var result:=Core.execute(context,row.plane_u8,row.threshold_s32);native_cases+=1
			check(result.get("ok",false),"Packed original plane executes: "+str(row.name))
			if not result.get("ok",false):continue
			for key:String in ["value_s32","truncate_shift_u32","distance_s32","threshold_after_s32"]:check(int(result[key])==int(expected[key]),"Original native plane arithmetic: "+key+" "+str(row.name))
			for key:String in ["normal_q8_s32","delta_s32"]:check(PackedInt64Array(result[key])==PackedInt64Array(expected[key]),"Actual native packed decoding/intermediate vector: "+key+" "+str(row.name))
			check(result.source_order==expected.source_order,"Whole F583/abs/FindMSB call order matches native")
			check(var_to_bytes(context)==before,"Plane evaluation preserves complete caller point/scales/raw buffers")
			check(not result.live_owners_changed and not result.full_collision_program_VM,"Plane predicate does not claim outer VM or live world effects")
			var cold:Dictionary=JSON.parse_string(JSON.stringify(row.context));var continued:=Core.execute(fixture_context(cold),float(row.plane_u8),float(row.threshold_s32))
			check(continued.get("ok",false) and int(continued.get("value_s32",-1))==int(expected.value_s32),"Portable JSON numeric source inputs retain the original predicate")
			var normal_at:=int(context.normal_origin_u32)+(int(row.plane_u8)>>1)*6-6
			mirror_combinations[(int(row.plane_u8)&1)*2+(int(context.normals[normal_at])&1)]=true
			codes[int(row.plane_u8)]=true;values[int(result.value_s32)]=true;shift_counts[int(result.truncate_shift_u32)]=true
			if int(expected.distance_s32)==int(expected.threshold_after_s32):equality_cases+=1
			result.normal_q8_s32[0]=123;result.delta_s32[0]=456
			check(var_to_bytes(context)==before,"Returned intermediate arrays never alias caller state")
		check(codes.size()==256 and mirror_combinations.size()==4 and values.size()==2 and equality_cases>0 and shift_counts.has(0) and shift_counts.has(18),"Native coverage includes every byte code, both outcomes, equality and large-vector truncation")
	var sources:Dictionary={}
	for path:String in dependencies:sources[path]=FileAccess.get_sha256("res://"+path)
	for path:String in ["scripts/source_collision_planes.gd","tests/test_source_collision_planes.gd","tests/fixtures/source_collision_planes_native.json","validation/collision-programs-2026-11-17/planes-native-proof/instruction-proof.json","validation/collision-programs-2026-11-17/planes-native-proof/source-procedures.asm"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var report:=FileAccess.open(REPORT,FileAccess.WRITE)
	if report:report.store_string(JSON.stringify({"schema":1,"profile":Core.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"plane_byte_codes":codes.size(),"equality_cases":equality_cases,"mirror_combinations":mirror_combinations.size(),"sources":sources,"full_collision_program_VM":false,"Main_integrated":false,"physical_device_tested":false},"\t"));report.close()
	print("SOURCE COLLISION PLANES TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
