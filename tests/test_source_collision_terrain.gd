extends SceneTree
const Terrain=preload("res://scripts/source_collision_terrain.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_collision_terrain_native.json"
const FIXTURE_SHA:="2a165478fdc66eb99dd51f9fc55ad59eb97ee0ee2348d0f410e798b82027d799"
const REPORT:="res://build/current-test-reports/source-collision-terrain.json"
var checks:=0
var failures:=0
var native_cases:=0
var resource_records:=0
var queries:=0
var cold_queries:=0
var branches:Dictionary={}
var queried_styles:Dictionary={}
var queried_records:Dictionary={}
var queried_graphics:Dictionary={}
var dependency_pins:Dictionary={}
var query_rejects_checked:=false
var native_controls_complete:=false
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<26:push_error(message)
func globals()->Dictionary:
	var state:Dictionary={}
	for key:String in Frame.GLOBAL_KEYS:state[key]=0
	state.altitude_low_u32=0x89abcdef;state.altitude_high_s32=-27;state.previous_altitude_low_u32=23;state.previous_altitude_high_s32=-18
	return state
func terrain_state()->Dictionary:return {"graphics_level_u32":1,"recorded_intersection_raw_s32":12345,"pending_query_flag_u32":0x76543210}
func base_context()->Dictionary:return {"point_xyz_s32":[0,0,0],"normals":PackedByteArray(),"vertices":PackedByteArray([0,0,0,0,0,0]),"mesh_zoom_s32":0,"vector_scale_s32":0}
func decode_context(value:Dictionary)->Dictionary:
	return {"point_xyz_s32":value.point_xyz_s32.duplicate(),"normals":str(value.normals_hex).hex_decode(),"vertices":str(value.vertices_hex).hex_decode(),"mesh_zoom_s32":value.mesh_zoom_s32,"vector_scale_s32":value.vector_scale_s32,"normal_origin_u32":value.get("normal_origin_u32",0),"vertex_origin_u32":value.get("vertex_origin_u32",0)}
func result_digest(result:Dictionary)->String:
	return Clock._hash({"hit_s32":result.hit_s32,"next_offset_u32":result.next_offset_u32,"globals_after":result.globals_after,"terrain_state_after":result.terrain_state_after,"query_count_u32":result.query_count_u32})
func standalone()->void:
	var body:=PackedByteArray();body.resize(338)
	var program:=PackedByteArray([0,0,0,0,255,255,0,0])
	var context:=base_context();var state:=globals();var aux:=terrain_state()
	var frozen:=var_to_bytes([body,program,context,state,aux])
	var outside:=Terrain.execute(body,program,0,context,0,state,aux)
	check(outside.ok and outside.branch=="outside_outer" and outside.hit_s32==-1 and outside.next_offset_u32==8,"Exact outer equality takes the original flat outside path")
	check(outside.globals_after.collision_kind_u8==0 and outside.globals_after.altitude_low_u32==state.altitude_low_u32 and outside.globals_after.previous_altitude_high_s32==state.previous_altitude_high_s32,"Flat outside updates only source collision kind among altitude owners")
	check(outside.query_count_u32==0 and outside.terrain_state_after==aux and outside.source_order==["F581","F1822"],"Flat gates do not collect terrain, change graphics or reset query globals")
	var inside:=Terrain.execute(body,program,0,context,1,state,aux)
	check(inside.ok and inside.branch=="inside_inner" and inside.hit_s32==0 and inside.globals_after.collision_kind_u8==1,"Exact inner branch retains source signed comparisons")
	check(inside.globals_after.altitude_low_u32==state.altitude_low_u32 and inside.terrain_state_after==aux,"Flat inside retains prior altitude/query history; F575 owns the later response")
	var opaque_graphics:=aux.duplicate(true);opaque_graphics.graphics_level_u32=0xffffffff
	var opaque:=Terrain.execute(body,program,0,context,0,state,opaque_graphics)
	check(opaque.ok and opaque.terrain_state_after==opaque_graphics and opaque.query_count_u32==0,"Flat F581 preserves a full32-bit graphics word without reading it as a query level")
	var generic_body:=body.duplicate();generic_body.encode_u32(0x82,0xffffffff)
	check(Terrain.execute(generic_body,program,0,context,0,state,aux).ok,"Standalone F581 uses supplied raw geometry independently of authored model ID bounds")
	var shifted:=program.duplicate();shifted.insert(0,99)
	var offset:=Terrain.execute(body,shifted,1,context,0,state,aux)
	check(offset.ok and offset.next_offset_u32==9,"Caller program offset is retained independently of the payload bytes")
	check(var_to_bytes([body,program,context,state,aux])==frozen,"Pure terrain checks preserve every raw caller owner")
	outside.body_after[0]=1;outside.program_after[0]=1;outside.context_after.point_xyz_s32[0]=1;outside.globals_after.collision_kind_u8=99;outside.terrain_state_after.graphics_level_u32=7
	check(var_to_bytes([body,program,context,state,aux])==frozen,"Successful raw results cannot alias supplied body/program/context/global owners")
	var packed_context:=context.duplicate(true);packed_context.normals=PackedByteArray([13,14,15])
	var packed_before:=var_to_bytes(packed_context);var packed_result:=Terrain.execute(body,program,0,packed_context,0,state,aux)
	packed_result.context_after.normals[0]=42;packed_result.context_after.vertices[0]=42
	check(var_to_bytes(packed_context)==packed_before,"Returned nested packed geometry bytes cannot alias caller-owned buffers")
	for bad:Variant in [null,true,0,"raw",[],{},PackedByteArray()]:
		check(not Terrain.execute(bad,program,0,context,0,state,aux).ok,"Malformed collider record rejects")
		check(not Terrain.execute(body,bad,0,context,0,state,aux).ok,"Malformed raw collision program rejects")
	for bad:Variant in [null,true,0,"raw",[],{}]:
		check(not Terrain.execute(body,program,0,bad,0,state,aux).ok,"Malformed model-local context rejects")
		check(not Terrain.execute(body,program,0,context,0,bad,aux).ok,"Malformed collision globals reject")
		check(not Terrain.execute(body,program,0,context,0,state,bad).ok,"Malformed terrain state rejects")
	for key:String in Terrain.TERRAIN_KEYS:
		var broken:=aux.duplicate(true);broken.erase(key)
		check(not Terrain.execute(body,program,0,context,0,state,broken).ok,"Missing terrain word rejects: "+key)
	for bad:Variant in [null,true,NAN,INF,0.5,-1,0x100000000,"1"]:
		var broken:=aux.duplicate(true);broken.graphics_level_u32=bad
		check(not Terrain.execute(body,program,0,context,0,state,broken).ok,"Unrepresentable graphics delivery rejects")
	for key:String in ["recorded_intersection_raw_s32","pending_query_flag_u32"]:
		for bad:Variant in [null,true,NAN,INF,0.5,-0x80000001,0x100000000,"1"]:
			var broken:=aux.duplicate(true);broken[key]=bad
			check(not Terrain.execute(body,program,0,context,0,state,broken).ok,"Unrepresentable query word rejects: "+key)
	for bad:Variant in [null,true,NAN,INF,0.5,-1,9,0x100000000,"0"]:check(not Terrain.execute(body,program,bad,context,0,state,aux).ok,"Invalid caller payload offset rejects")
	for bad:Variant in [null,true,NAN,INF,0.5,-0x80000001,0x80000000,"0"]:check(not Terrain.execute(body,program,0,context,bad,state,aux).ok,"Invalid signed threshold rejects")
	for cut in range(8):check(not Terrain.execute(body,program.slice(0,cut),0,context,0,state,aux).ok,"Truncated terrain basis or terminator is not filled with invented zeros")
	var unterminated:=program.duplicate();unterminated[6]=1
	check(not Terrain.execute(body,unterminated,0,context,0,state,aux).ok,"F1822 requires a real16-byte feature sequence ending in a zero word")
	var broken_context:=context.duplicate(true);broken_context.vertices.resize(5)
	check(not Terrain.execute(body,program,0,broken_context,0,state,aux).ok,"Packed vertex reads stay within explicitly supplied bytes")
	broken_context=context.duplicate(true);broken_context.extra=1
	check(not Terrain.execute(body,program,0,broken_context,0,state,aux).ok,"Unknown model-local ownership fields reject")
	for key:String in ["mesh_zoom_s32","vector_scale_s32"]:
		for bad:Variant in [null,true,NAN,INF,0.5,-0x80000001,0x80000000,"0"]:
			broken_context=context.duplicate(true);broken_context[key]=bad
			check(not Terrain.execute(body,program,0,broken_context,0,state,aux).ok,"Unrepresentable source context scalar rejects: "+key)
	for key:String in ["normal_origin_u32","vertex_origin_u32"]:
		for bad:Variant in [null,true,NAN,INF,0.5,-1,0x100000000,"0"]:
			broken_context=context.duplicate(true);broken_context[key]=bad
			check(not Terrain.execute(body,program,0,broken_context,0,state,aux).ok,"Unrepresentable source buffer origin rejects: "+key)
	for bad:Variant in [null,true,[],[0,0],[0,0,0,0],[0,0,0.5],[0,0,NAN],[0,0,INF],[0,0,-0x80000001],[0,0,0x80000000],[0,0,"0"]]:
		broken_context=context.duplicate(true);broken_context.point_xyz_s32=bad
		check(not Terrain.execute(body,program,0,broken_context,0,state,aux).ok,"Invalid raw observer rejects without coercing source coordinates")
	for key:String in ["normals","vertices"]:
		broken_context=context.duplicate(true);broken_context[key]=[]
		check(not Terrain.execute(body,program,0,broken_context,0,state,aux).ok,"Raw geometry buffers require their actual packed byte type")
	var broken_aux:=aux.duplicate(true);broken_aux.extra=1
	check(not Terrain.execute(body,program,0,context,0,state,broken_aux).ok,"Unknown terrain ownership fields reject")
	check(var_to_bytes([body,program,context,state,aux])==frozen,"All invalid raw deliveries leave the original owners untouched")
func query_rejections(row:Dictionary)->void:
	var body:=str(row.body_before_hex).hex_decode();var program:=str(row.program_hex).hex_decode();var context:=decode_context(row.context)
	var state:Dictionary=row.globals_before.duplicate(true);var aux:Dictionary=row.terrain_state_before.duplicate(true)
	var before:=var_to_bytes([body,program,context,state,aux])
	for graphics in [16,0x7fffffff,0x80000000,0xffffffff]:
		var unsupported:=aux.duplicate(true);unsupported.graphics_level_u32=graphics
		var got:=Terrain.execute(body,program,row.offset_u32,context,row.threshold_s32,state,unsupported)
		check(not got.ok and got.reason=="unsupported_terrain_query_graphics" and not got.has("globals_after") and not got.F1876_body_executed,"A real query with unsupported graphics rejects atomically; flat gates still accept the full raw word")
	var unsupported_program:=program.duplicate();unsupported_program.encode_u16(int(row.offset_u32)+4,14)
	var bad_style:=Terrain.execute(body,unsupported_program,row.offset_u32,context,row.threshold_s32,state,aux)
	check(not bad_style.ok and bad_style.reason=="unsupported_terrain_style" and not bad_style.has("globals_after"),"Query style outside original fourteen-entry table rejects atomically")
	var broken_features:=program.slice(0,int(row.offset_u32)+6)
	broken_features.append_array(PackedByteArray([8,0,255,255,0,0,0,0,0,0,0,0,0,0,0,0,0,0]))
	var bad_features:=Terrain.execute(body,broken_features,row.offset_u32,context,row.threshold_s32,state,aux)
	check(not bad_features.ok and bad_features.reason=="source_terrain_query_rejected" and not bad_features.has("globals_after"),"Unsupported actual F1876 feature data rejects without an invented height or partial state")
	check(var_to_bytes([body,program,context,state,aux])==before,"Every rejected actual query preserves raw caller-owned inputs")
func catalog_coverage()->void:
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/ffe_collision_programs.json"))
	var body:=PackedByteArray();body.resize(338)
	for key:String in catalog.models:
		var row:Dictionary=catalog.models[key];var descriptor:=str(row.descriptor_hex).hex_decode()
		var context:Dictionary={"point_xyz_s32":[0,0,0],"normals":str(row.normals_hex).hex_decode(),"vertices":str(row.vertices_hex).hex_decode(),"mesh_zoom_s32":descriptor.decode_s32(0x14)+descriptor.decode_s32(0x18),"vector_scale_s32":descriptor.decode_s32(0x14)+descriptor.decode_s32(0x18),"normal_origin_u32":int(row.normals_origin_u32),"vertex_origin_u32":int(row.vertices_origin_u32)}
		for record:Dictionary in row.program_records:
			if record.kind!="terrain":continue
			var program:=str(row.collision_program_hex).hex_decode();var at:=int(record.terrain_features_offset)-6;var aux:=terrain_state();var state:=globals()
			var before:=var_to_bytes([body,program,context,state,aux])
			var got:=Terrain.execute(body,program,at,context,0,state,aux);resource_records+=1
			check(got.ok and got.next_offset_u32==int(record.next_offset),"Actual terrain basis/feature span matches structural original bytes: "+key)
			check(got.ok and got.query_count_u32==0 and got.terrain_state_after==aux,"Explicit zero body bounds test each actual terrain record without inventing a query: "+key)
			check(var_to_bytes([body,program,context,state,aux])==before,"Every original record read preserves supplied resource bytes: "+key)
	check(resource_records==37,"All37 authored terrain records are covered independently of collider model IDs")
func native_controls()->void:
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent whole F581 fixture is pinned")
	if not FileAccess.file_exists(FIXTURE):return
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(int(fixture.case_count)==fixture.cases.size() and fixture.cases.size()>0,"Independent actual DOS terrain controls are present")
	check(int(fixture.fresh_process_runs)==3 and int(fixture.reverse_repeat_cases)==int(fixture.base_case_count) and int(fixture.consecutive_native_steps)==32,"Native controls include three fresh processes, reverse-order repeats and consecutive query state")
	check(fixture.expected_arithmetic_calculated_in_python==false and fixture.all_readonly_buffers_unchanged==true,"Expected arithmetic is executed by original source bodies with complete read-only buffer canaries")
	dependency_pins=fixture.get("source_dependencies_sha256",{}).duplicate(true)
	for path:String in dependency_pins:check(FileAccess.get_sha256("res://"+path)==dependency_pins[path],"Native reproduction dependency is pinned: "+path)
	for row:Dictionary in fixture.cases:
		var body:=str(row.body_before_hex).hex_decode();var program:=str(row.program_hex).hex_decode();var context:=decode_context(row.context)
		var before:=var_to_bytes([body,program,context,row.globals_before,row.terrain_state_before])
		var result:=Terrain.execute(body,program,row.offset_u32,context,row.threshold_s32,row.globals_before,row.terrain_state_before);native_cases+=1
		check(result.ok,"Actual F581 source invocation executes: "+str(row.name))
		if not result.ok:continue
		var expected:Dictionary=row.expected
		for key:String in ["hit_s32","next_offset_u32","query_count_u32"]:check(int(result[key])==int(expected[key]),"Native F581 result word "+key+": "+str(row.name))
		check(Frame._same_globals(result.globals_after,expected.globals_after),"All12 collision globals equal original native output: "+str(row.name))
		check(Clock._hash(result.terrain_state_after)==Clock._hash(expected.terrain_state_after),"Persistent query words equal original output: "+str(row.name))
		check(result.source_order==expected.source_order,"Terrain versus F1822 source call order equals original trace: "+str(row.name))
		check(result.body_after==body and result.program_after==program and result.context_after==context,"Whole body/program/context remain raw and read-only: "+str(row.name))
		check(str(expected.body_after_hex)==body.hex_encode() and str(expected.program_after_hex)==program.hex_encode() and decode_context(expected.context_after)==context,"Native controls independently prove body/program/context read-only: "+str(row.name))
		check(var_to_bytes([body,program,context,row.globals_before,row.terrain_state_before])==before,"Whole native case keeps every caller-owned input unchanged: "+str(row.name))
		if int(result.query_count_u32)!=0:
			var args:Dictionary=expected.query_args
			queried_styles[int(args.style_u32)]=true;queried_records["%d/%d"%[int(row.model_index_u32),int(row.record_offset_u32)]]=true;queried_graphics[int(row.terrain_state_before.graphics_level_u32)]=true
			for key:String in ["seed_u32","style_u32","query_limit_s32"]:check(int(result.query_args[key])==int(args[key]),"Native F1876 query scalar "+key+": "+str(row.name))
			check(Clock._hash({"matrix":result.query_args.query_matrix_s32,"center":result.query_args.query_center_s32})==Clock._hash({"matrix":args.matrix_s32,"center":args.center_s32}),"All twelve source matrix/center words equal actual original F581 transform: "+str(row.name))
			check(int(args.features_offset_u32)==int(row.offset_u32)+6 and str(result.query_args.features_hex)==program.slice(int(args.features_offset_u32),int(expected.next_offset_u32)).hex_encode(),"Real F1876 feature pointer and stream match caller program bytes: "+str(row.name))
			check(int(result.query_metrics.depth_control_raw)==int(expected.query_scratch_after.depth_control_s32) and int(result.query_metrics.vertex_pool_count_after_return)==int(expected.query_scratch_after.vertex_pool_count_u32),"Actual query depth/pool scratch equals original output without becoming persistent terrain state: "+str(row.name))
			if not query_rejects_checked:query_rejections(row);query_rejects_checked=true
		branches[result.branch]=true;queries+=int(result.query_count_u32)
		var cold:Dictionary=JSON.parse_string(JSON.stringify(row));var again:=Terrain.execute(str(cold.body_before_hex).hex_decode(),str(cold.program_hex).hex_decode(),cold.offset_u32,decode_context(cold.context),cold.threshold_s32,cold.globals_before,cold.terrain_state_before)
		check(again.ok and result_digest(again)==result_digest(result),"Cold JSON numeric/raw deliveries continue the same source result: "+str(row.name))
		if result.query_count_u32!=0:cold_queries+=1
	check(branches.has("outside_outer") and branches.has("inside_inner") and branches.has("terrain_query") and queries>0,"Native controls exercise both flat gates and genuine terrain queries")
	check(queried_styles.size()==14,"All fourteen original style descriptors reach actual F1876 queries")
	check(queried_records.size()==37,"All37 original terrain payload/feature streams reach F1876 with explicit raw bounds where required")
	check(queried_graphics.has(0) and queried_graphics.has(15),"Actual queries cover both supported graphics profile endpoints")
	check(native_cases==int(fixture.case_count),"Every native control finished and contributes to the report")
	native_controls_complete=true
func run()->void:
	standalone();catalog_coverage();native_controls()
	check(native_controls_complete and query_rejects_checked,"The complete native parity loop and actual query rejection controls return normally")
	var sources:Dictionary={}
	for path:String in dependency_pins:sources[path]=FileAccess.get_sha256("res://"+path)
	for path:String in ["scripts/source_collision_terrain.gd","tests/test_source_collision_terrain.gd",FIXTURE.trim_prefix("res://"),"scripts/source_terrain_query.gd","scripts/source_terrain_point.gd","scripts/source_frame_dispatch.gd","data/ffe_collision_programs.json"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"schema":1,"profile":Terrain.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"authored_terrain_records":resource_records,"actual_queries":queries,"cold_queries":cold_queries,"queried_style_count":queried_styles.size(),"queried_record_count":queried_records.size(),"queried_graphics_levels":queried_graphics.keys(),"sources":sources,"Main_integrated":false,"physical_device_tested":false},"\t"));file.close()
	print("SOURCE COLLISION TERRAIN TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
