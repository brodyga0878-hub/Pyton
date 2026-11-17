extends SceneTree
const Program=preload("res://scripts/source_collision_program.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_collision_program_native.json"
const FIXTURE_SHA:="33524f360435c560222473f16664cccec04a04292d0b4d64daa7a7ec68695b64"
const REPORT:="res://build/current-test-reports/source-collision-program.json"
var checks:=0
var failures:=0
var native_cases:=0
var pending_cases:=0
var native_pins:Dictionary={}
var consecutive_steps:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<30:push_error(message)
func digest(value:Dictionary)->String:return Clock._hash(value)
func base()->Dictionary:
	var body:=PackedByteArray();body.resize(338)
	var globals:Dictionary={}
	for key:String in Frame.GLOBAL_KEYS:globals[key]=0
	var context:Dictionary={"point_xyz_s32":[0,0,0],"normals":PackedByteArray([0,0,1,0,0,0,0,0,1,0,0,0]),"vertices":PackedByteArray([0,0,0,0,0,0]),"mesh_zoom_s32":0,"vector_scale_s32":0,"normal_origin_u32":6,"vertex_origin_u32":0}
	return {"body":body,"context":context,"globals":globals}
func invoke(state:Dictionary,program:Variant,observations:Variant=[],resources:Variant={},primitive:Variant=0)->Dictionary:
	return Program.execute(state.body,program,state.context,0,state.globals,observations,resources,primitive)
func basic()->void:
	var state:=base();var frozen:=var_to_bytes(state)
	var features:=PackedByteArray();features.resize(34);features.encode_s16(0,-1);features.encode_s16(16,23)
	var skipped:=Program.skip_terrain_features(features)
	check(skipped.ok and skipped.next_offset_u32==34 and skipped.source_order==["F1822"],"Actual terrain feature layout uses signed words every16 bytes until its two-byte zero terminator")
	check(Program.skip_terrain_features(PackedByteArray([0,0])).next_offset_u32==2,"An empty feature list advances exactly its signed16 terminator")
	check(not Program.skip_terrain_features(PackedByteArray([1,0,0,0])).ok,"Feature skipping cannot mistake an interior zero byte for the next record")
	for primitive in [0,1,127,128,255]:
		var result:=invoke(state,PackedByteArray([0]),[],{},primitive)
		check(result.ok and result.return_s8==1 and result.primitive_u8==0 and result.primitive_written,"Zero program overwrites caller primitive seed and returns AL1")
		check(result.ok and result.stream_cursor_u32==1 and result.source_order==["F582"],"Empty program consumes exactly the initial terminator")
	var empty_exclusion:=invoke(state,PackedByteArray([0x40,0xa5,0,0]))
	check(empty_exclusion.ok and empty_exclusion.return_s8==-1 and empty_exclusion.primitive_u8==0x40 and int(empty_exclusion.globals_after.volume_flags_u8)==0x25,"Empty exclusion writes primitive and masked volume before negative return")
	var empty_volume:=invoke(state,PackedByteArray([0xc0,0x85,0,0]))
	check(empty_volume.ok and empty_volume.return_s8==0 and empty_volume.primitive_u8==0xc0 and empty_volume.globals_after.volume_flags_u8==0x85,"Empty inclusive record with high volume bit accepts immediately")
	var needs_suffix:=invoke(state,PackedByteArray([0xd0,0x7f,0,0]))
	check(not needs_suffix.ok,"ClassC0 may consume the structural program terminator as a plane-list byte; absent adjacent bytes are never invented")
	var with_suffix:=invoke(state,PackedByteArray([0xd0,0x7f,0,0,0]))
	check(with_suffix.ok and with_suffix.return_s8==1 and with_suffix.stream_cursor_u32==5,"Explicit adjacent source bytes permit the original ClassC0 fallthrough")
	var descriptor:=PackedByteArray();descriptor.resize(68)
	var resource:Dictionary={"descriptor":descriptor,"vertices":state.context.vertices.duplicate(),"normals":state.context.normals.duplicate(),"collision_program":PackedByteArray([0x40,0x81,0,0]),"normal_origin_u32":6,"vertex_origin_u32":0}
	var nested:=invoke(state,PackedByteArray([0x80,0x82,0,1,0,0,0]),[],{1:resource})
	check(nested.ok and nested.return_s8==-1 and nested.primitive_u8==0x80 and nested.globals_after.volume_flags_u8==3 and nested.globals_after.primitive_flags_u8==0x40,"Nested negative program combines child primitive and parent volume in the original order")
	check(nested.ok and nested.source_order==["F582","F580","F1538","F582"],"Nested geometry executes the real coordinate transform before recursive F582")
	resource.collision_program=PackedByteArray([0xc0,0x81,0,0])
	nested=invoke(state,PackedByteArray([0x80,0x82,0,1,0,0,0]),[],{1:resource})
	check(nested.ok and nested.return_s8==0 and nested.primitive_u8==0x80 and nested.globals_after.volume_flags_u8==0x83 and nested.globals_after.primitive_flags_u8==0xc0,"Nested accepted volume retains source primitive accumulation and high-bit early return")
	resource.collision_program=PackedByteArray([0x80,0,0,1,0,0,0])
	check(not invoke(state,PackedByteArray([0x80,0,0,1,0,0,0]),[],{1:resource}).ok,"Recursive model cycles stop at an explicit depth bound")
	state.body.encode_u16(0x9c,1)
	var conditional:=invoke(state,PackedByteArray([0x60,0x85,0,0,2,0,0]))
	check(conditional.ok and conditional.return_s8==1 and conditional.primitive_u8==0 and conditional.globals_after.volume_flags_u8==0,"Equipment condition skips its exact plane list without effects")
	var inverted:=invoke(state,PackedByteArray([0x60,0x85,0,0x80,0,0]))
	check(inverted.ok and inverted.return_s8==-1 and inverted.primitive_u8==0x60,"Equipment condition inversion admits the same empty exclusion")
	state.body.encode_u16(0x9c,0)
	var terrain_skip:=invoke(state,PackedByteArray([0x20,0x80,0,0x80,255,1,2,3,4,5,6,0,0,0]))
	check(terrain_skip.ok and terrain_skip.return_s8==1 and terrain_skip.stream_cursor_u32==14 and terrain_skip.source_order==["F582","F1822"],"Skipped terrain advances six header bytes and original signed16 feature terminator")
	var terrain_program:=PackedByteArray([0x10,0x82,255,1,2,3,4,5,6,0,0,0])
	var pending:=invoke(state,terrain_program)
	check(not pending.ok and pending.get("pending") is Dictionary and pending.pending.kind=="F581" and pending.pending.args==[3,0],"Terrain is an explicit pending boundary with exact payload pointer")
	if pending.get("pending") is Dictionary:
		var row:Dictionary={"kind":"F581","args":pending.pending.args.duplicate(),"before":pending.pending.before.duplicate(true),"after":pending.pending.before.duplicate(true),"return_s32":0,"next_offset_u32":11}
		row.after.globals.altitude_low_u32=17
		var complete:=invoke(state,terrain_program,[row])
		check(complete.ok and complete.return_s8==0 and complete.primitive_u8==0x10 and complete.globals_after.altitude_low_u32==17 and complete.globals_after.volume_flags_u8==0x82,"Matched terrain hit resumes original F582 with full globals")
		var cold:Dictionary=JSON.parse_string(JSON.stringify(row))
		for side:String in ["before","after"]:
			cold[side].body=state.body.duplicate();cold[side].program=terrain_program.duplicate();cold[side].context=state.context.duplicate(true)
		var resumed:=invoke(state,terrain_program,[cold])
		check(resumed.ok and digest(resumed.globals_after)==digest(complete.globals_after),"JSON numeric terrain continuation restores exact raw source globals")
		for key:String in ["body","program"]:
			var bad:=row.duplicate(true);bad.before[key][0]=int(bad.before[key][0])^1
			check(not invoke(state,terrain_program,[bad]).ok,"Mismatched terrain before bytes reject: "+key)
		var bad:=row.duplicate(true);bad.after.context.mesh_zoom_s32=1
		check(not invoke(state,terrain_program,[bad]).ok,"Terrain cannot change unpassed geometry context")
		bad=row.duplicate(true);bad.next_offset_u32=terrain_program.size()+1
		check(not invoke(state,terrain_program,[bad]).ok,"Terrain next pointer cannot escape its program buffer")
		check(not invoke(state,terrain_program,[row,row]).ok,"Extra terrain observations are not silently consumed")
	var expected:=state.duplicate(true);expected.body.encode_u16(0x9c,0)
	check(var_to_bytes(state)==var_to_bytes(expected),"All runtime calls preserve explicitly supplied raw owners")
	check(frozen==var_to_bytes(state),"Restoring the explicit equipment input reproduces the original owner bytes")
func malformed()->void:
	var state:=base();var p:=PackedByteArray([0]);var frozen:=var_to_bytes(state)
	for bad:Variant in [null,true,0,"bytes",{},[],PackedByteArray()]:
		check(not Program.execute(bad,p,state.context,0,state.globals).ok,"Malformed raw subject rejects")
		check(not Program.execute(state.body,bad,state.context,0,state.globals).ok,"Malformed or empty collision program rejects")
	for bad:Variant in [null,true,0,"context",[],{}]:
		check(not Program.execute(state.body,p,bad,0,state.globals).ok,"Malformed geometry context rejects")
		check(not Program.execute(state.body,p,state.context,0,bad).ok,"Malformed source globals reject")
	for key:String in Program.CONTEXT_KEYS:
		var context:Dictionary=state.context.duplicate(true);context.erase(key)
		check(not Program.execute(state.body,p,context,0,state.globals).ok,"Missing geometry input rejects: "+key)
	for key:String in ["mesh_zoom_s32","vector_scale_s32"]:
		for bad:Variant in [-0x80000001,0x80000000,NAN,INF,true,0.5,"0"]:
			var context:Dictionary=state.context.duplicate(true);context[key]=bad
			check(not Program.execute(state.body,p,context,0,state.globals).ok,"Malformed signed geometry word rejects: "+key)
	for bad:Variant in [-0x80000001,0x80000000,NAN,INF,true,0.5,"0"]:check(not Program.execute(state.body,p,state.context,bad,state.globals).ok,"Malformed threshold rejects")
	for bad:Variant in [null,true,0,"obs",{},[{}]]:check(not invoke(state,p,bad).ok,"Malformed or unused observation data rejects")
	for bad:Variant in [null,true,0,"models",[]]:check(not invoke(state,p,[],bad).ok,"Malformed model catalog rejects")
	for bad:Variant in [-1,256,NAN,INF,true,0.5,"0"]:check(not invoke(state,p,[],{},bad).ok,"Malformed primitive seed rejects")
	for bytes:PackedByteArray in [PackedByteArray([0x10]),PackedByteArray([0x60,0x80]),PackedByteArray([0x80,0,0]),PackedByteArray([0x40,0,2]),PackedByteArray([0x20,0,0,0x80,255,0,0,0,0,0,0])]:
		check(not invoke(state,bytes).ok,"Truncated records and unterminated lists fail closed")
	check(not invoke(state,PackedByteArray([0x20,0,255,0,0,0])).ok,"Out-of-record equipment reads are unavailable")
	check(not invoke(state,PackedByteArray([0x80,0,0,1,0,0,0])).ok,"Missing nested model never becomes an empty no-hit result")
	check(var_to_bytes(state)==frozen,"Every malformed call leaves caller state unchanged")
func native_bank()->void:
	check(FileAccess.file_exists(FIXTURE),"Independent original F582 instruction fixture is required")
	if not FileAccess.file_exists(FIXTURE):return
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent F582 fixture is pinned")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.schema=="starfrontier-source-collision-program-native-v1" and fixture.profile==Program.PROFILE and int(fixture.case_count)==fixture.cases.size() and fixture.cases.size()==448,"Independent whole-program native corpus and DOS profile are complete")
	check(fixture.fresh_process_runs==3 and int(fixture.reverse_repeat_cases)==fixture.cases.size() and not fixture.expected_arithmetic_calculated_in_Python and fixture.all_readonly_buffers_unchanged,"Native expected arithmetic uses original instructions in three fresh processes and reverse order")
	check(fixture.source_executable_sha256=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72" and fixture.source_assembly_sha256=="d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a","Native programs bind the original DOS executable and assembly")
	check(FileAccess.get_sha256("res://validation/collision-programs-2026-11-17/program-native-proof/instruction-proof.json")==fixture.instruction_proof_sha256,"Whole original F582/F1822/F583/F580 instruction proof is pinned")
	check(FileAccess.get_sha256("res://validation/collision-programs-2026-11-17/program-native-proof/program-native.s")==fixture.host_assembly_sha256,"Documented native host ABI assembly is pinned")
	native_pins=fixture.source_dependencies_sha256.duplicate(true)
	for path:String in native_pins:check(FileAccess.get_sha256("res://"+path)==native_pins[path],"Native reproduction dependency is pinned: "+path)
	var exercised:Dictionary={};var last_traced:Dictionary={};var previous:Dictionary={}
	for row:Dictionary in fixture.cases:
		var state:Dictionary={"body":str(row.body_before_hex).hex_decode(),"context":decode_context(row.context),"globals":row.globals_before.duplicate(true)}
		var resources:=decode_resources(row.resources);var program:=str(row.program_hex).hex_decode();var observations:Array=[]
		for observation:Dictionary in row.expected.observations:observations.append(decode_observation(observation))
		var before:=var_to_bytes([state,program,observations,resources])
		var result:=Program.execute(state.body,program,state.context,row.threshold_s32,state.globals,observations,resources,row.primitive_u8_before);native_cases+=1
		check(result.get("ok",false),"Whole original F582 executes: "+str(row.name)+" "+str(result.get("reason")))
		if not result.get("ok",false):continue
		check(result.return_s8==int(row.expected.return_s8) and result.primitive_u8==int(row.expected.primitive_u8) and result.primitive_written,"Actual return AL and caller primitive byte match native: "+str(row.name))
		check(result.stream_cursor_u32==int(row.expected.stream_cursor_u32),"Instrumented original ESI cursor before epilogue matches: "+str(row.name))
		check(result.body_after==str(row.expected.body_after_hex).hex_decode(),"All338 subject bytes match original F582: "+str(row.name))
		check(digest(result.globals_after)==digest(row.expected.globals_after),"All12 collision globals match original F582: "+str(row.name))
		check(result.source_order==row.expected.source_order,"Router, real plane/transform recursion and terrain boundary order match native: "+str(row.name)+" "+str(result.source_order)+" / "+str(row.expected.source_order))
		check(result.observations_used==observations.size() and result.requests==observations,"Original terrain boundaries are consumed exactly once: "+str(row.name))
		check(not result.live_owners_changed and not result.F581_body_executed and result.F582_body_executed and not result.full_collision_programs_executed,"Program and unresolved terrain execution scope stays explicit")
		check(var_to_bytes([state,program,observations,resources])==before,"Every raw owner remains unchanged by native parity call: "+str(row.name))
		if row.has("native_continuation_index"):
			check(int(row.native_continuation_index)==consecutive_steps,"Native continuation indices preserve the actual source sequence")
			if not previous.is_empty():
				check(state.body==previous.body_after and digest(state.globals)==digest(previous.globals_after) and int(row.primitive_u8_before)==int(previous.primitive_u8),"A dependent native call receives exactly the previous body, primitive and all source globals")
			previous=result;consecutive_steps+=1
		for name:String in result.source_order:exercised[name]=true
		if observations.size()>0:last_traced=row
	for name:String in ["F582","F583","F580","F1538","F581","F1822"]:check(exercised.has(name),"Independent native corpus exercises original branch: "+name)
	check(consecutive_steps==32 and int(fixture.consecutive_native_steps)==32,"All32 actual dependent native continuations are checked")
	if not last_traced.is_empty():
		var row:=last_traced;var state:Dictionary={"body":str(row.body_before_hex).hex_decode(),"context":decode_context(row.context),"globals":row.globals_before.duplicate(true)};var resources:=decode_resources(row.resources);var program:=str(row.program_hex).hex_decode();var observations:Array=[]
		for observation:Dictionary in row.expected.observations:observations.append(decode_observation(observation))
		for index in range(observations.size()):
			var pending:=Program.execute(state.body,program,state.context,row.threshold_s32,state.globals,observations.slice(0,index),resources,row.primitive_u8_before)
			check(not pending.ok and pending.get("pending") is Dictionary and pending.pending.kind==observations[index].kind,"Every strict native terrain prefix pauses before its next original callback");pending_cases+=1
func decode_context(row:Dictionary)->Dictionary:
	return {"point_xyz_s32":[int(row.point_xyz_s32[0]),int(row.point_xyz_s32[1]),int(row.point_xyz_s32[2])],"normals":str(row.normals_hex).hex_decode(),"vertices":str(row.vertices_hex).hex_decode(),"mesh_zoom_s32":int(row.mesh_zoom_s32),"vector_scale_s32":int(row.vector_scale_s32),"normal_origin_u32":int(row.get("normal_origin_u32",0)),"vertex_origin_u32":int(row.get("vertex_origin_u32",0))}
func decode_resources(rows:Dictionary)->Dictionary:
	var result:Dictionary={}
	for key:String in rows:
		var row:Dictionary=rows[key]
		result[int(key)]={"descriptor":str(row.descriptor_hex).hex_decode(),"normals":str(row.normals_hex).hex_decode(),"vertices":str(row.vertices_hex).hex_decode(),"collision_program":str(row.collision_program_hex).hex_decode(),"normal_origin_u32":int(row.get("normal_origin_u32",0)),"vertex_origin_u32":int(row.get("vertex_origin_u32",0))}
	return result
func decode_observation(row:Dictionary)->Dictionary:
	var result:Dictionary={"kind":str(row.kind),"args":[int(row.args[0]),int(row.args[1])],"return_s32":int(row.return_s32),"next_offset_u32":int(row.next_offset_u32)}
	for side:String in ["before","after"]:
		var context:Dictionary=row[side]
		result[side]={"body":str(context.body_hex).hex_decode(),"program":str(context.program_hex).hex_decode(),"context":decode_context(context.context),"globals":context.globals.duplicate(true)}
	return result
func run()->void:
	basic();malformed();native_bank()
	var sources:Dictionary={}
	for path:String in ["scripts/source_collision_program.gd","scripts/source_collision_planes.gd","scripts/source_collision_transform.gd","tests/test_source_collision_program.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	for path:String in native_pins:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"profile":Program.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"consecutive_native_steps":consecutive_steps,"pending_cases":pending_cases,"sources":sources,"full_F581_terrain_executed":false,"Main_integrated":false},"\t"));file.close()
	print("SOURCE COLLISION PROGRAM TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
