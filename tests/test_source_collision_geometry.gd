extends SceneTree
const Geometry=preload("res://scripts/source_collision_geometry.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const Program=preload("res://scripts/source_collision_program.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_collision_geometry_native.json"
const FIXTURE_SHA:="bdedb3892cbb6234a3418280b25a9ca5ed4c6be47a09851ac9671162628aaf03"
const REPORT:="res://build/current-test-reports/source-collision-geometry.json"
var checks:=0
var failures:=0
var native_cases:=0
var native_calls:=0
var terrain_cold:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<25:push_error(message)
func resources(row:Dictionary)->Dictionary:
	var result:Dictionary={}
	for key:String in row.resources:
		var r:Dictionary=row.resources[key]
		result[int(key)]={"model_index_u32":int(key),"descriptor":str(r.descriptor_hex).hex_decode(),"vertices":str(r.vertices_hex).hex_decode(),"normals":str(r.normals_hex).hex_decode(),"collision_program":str(r.collision_program_hex).hex_decode(),"normal_origin_u32":0,"vertex_origin_u32":0,"children_records":r.children_records.duplicate(true)}
	return result
func observed(row:Dictionary,models:Dictionary)->Array:
	var result:Array=[];var body:=str(row.body_hex).hex_decode();var parent:=str(row.collider_hex).hex_decode()
	var model:Dictionary=models[int(parent.decode_u32(0x82))]
	for i in range(row.expected.calls.size()):
		var c:Dictionary=row.expected.calls[i]
		var context:Dictionary={"point_xyz_s32":[int(c.point_xyz_s32[0]),int(c.point_xyz_s32[1]),int(c.point_xyz_s32[2])],"normals":model.normals.duplicate(),"vertices":model.vertices.duplicate(),"mesh_zoom_s32":int(c.mesh_zoom_s32),"vector_scale_s32":int(c.vector_scale_s32),"normal_origin_u32":0,"vertex_origin_u32":0}
		result.append({"before":{"geometry_context":context,"threshold_s32":int(c.threshold_s32),"globals":Frame._copy_globals(c.globals_before),"body":parent.duplicate(),"program":model.collision_program.duplicate(),"iteration_u32":i},"return_s32":int(c.return_s32),"primitive_u8":int(c.primitive_u8),"globals_after":Frame._copy_globals(c.globals_after)})
	return result
func json_raw(value:Variant)->Variant:
	if value is PackedByteArray:return value.hex_encode()
	if value is Dictionary:
		var d:Dictionary={}
		for key:Variant in value:d[key]=json_raw(value[key])
		return d
	if value is Array:
		var a:Array=[]
		for item:Variant in value:a.append(json_raw(item))
		return a
	return value
func malformed(row:Dictionary)->void:
	var body:=str(row.body_hex).hex_decode();var parent:=str(row.collider_hex).hex_decode();var relative:=str(row.relative_hex).hex_decode();var models:=resources(row);var trace:=observed(row,models)
	var frozen:=var_to_bytes([body,parent,relative,row.globals_before,models,trace])
	for bad:Variant in [null,true,0,"raw",[],{},PackedByteArray()]:
		check(not Geometry.execute_observed(bad,parent,relative,row.globals_before,trace,models).ok,"Bad subject rejects")
		check(not Geometry.execute_observed(body,bad,relative,row.globals_before,trace,models).ok,"Bad collider rejects")
		check(not Geometry.execute_observed(body,parent,bad,row.globals_before,trace,models).ok,"Bad relative rejects")
	for bad:Variant in [null,true,0,"raw",[],{}]:check(not Geometry.execute_observed(body,parent,relative,bad,trace,models).ok,"Bad globals reject")
	var wrong:=trace.duplicate(true);wrong[0].before.threshold_s32=int(wrong[0].before.threshold_s32)^1
	check(not Geometry.execute_observed(body,parent,relative,row.globals_before,wrong,models).ok,"Wrong prepared raw threshold rejects")
	wrong=trace.duplicate(true);wrong.append(wrong[-1].duplicate(true))
	check(not Geometry.execute_observed(body,parent,relative,row.globals_before,wrong,models).ok,"Unused observed continuation rejects")
	wrong=trace.duplicate(true);wrong[0].before.geometry_context.point_xyz_s32[0]=int(wrong[0].before.geometry_context.point_xyz_s32[0])^1
	check(not Geometry.execute_observed(body,parent,relative,row.globals_before,wrong,models).ok,"Wrong actual prepared point rejects")
	wrong=trace.duplicate(true);wrong[0].before.body[0]=int(wrong[0].before.body[0])^1
	check(not Geometry.execute_observed(body,parent,relative,row.globals_before,wrong,models).ok,"World program must receive actual collider record")
	var pending:=Geometry.execute_observed(body,parent,relative,row.globals_before,[],models)
	check(not pending.ok and pending.get("pending") is Dictionary and pending.pending.kind=="F582","Observed seam pauses before unavailable program result")
	check(var_to_bytes([body,parent,relative,row.globals_before,models,trace])==frozen,"Rejected inputs and observations preserve every raw owner")
func terrain_json()->void:
	var model:Dictionary={"model_index_u32":1,"descriptor":PackedByteArray(),"vertices":PackedByteArray(),"normals":PackedByteArray(),"collision_program":PackedByteArray([0x10,0x82,255,0,0,0,0,0,0,0,0,0]),"children_records":[]}
	model.descriptor.resize(68);model.descriptor.encode_s32(0x14,23)
	var body:=PackedByteArray();body.resize(338);body[0x86]=114;body.encode_u32(0x82,0)
	var parent:=body.duplicate();parent[0x86]=37;parent.encode_u32(0x82,1)
	var relative:=PackedByteArray();relative.resize(24);var globals:Dictionary={}
	for key:String in Frame.GLOBAL_KEYS:globals[key]=0
	var models:Dictionary={0:model.duplicate(true),1:model.duplicate(true)}
	var first:=Geometry.execute(body,parent,relative,globals,[],models)
	check(not first.ok and first.get("pending") is Dictionary and first.pending.kind=="F581" and first.get("iteration_u32")==0,"Actual program reaches typed terrain boundary through F576/F579")
	if not first.get("pending") is Dictionary:return
	var request:Dictionary=first.pending
	var row:Dictionary={"kind":request.kind,"args":request.args.duplicate(),"depth_u32":request.depth_u32,"before":request.before.duplicate(true),"after":request.before.duplicate(true),"return_s32":0,"next_offset_u32":12}
	var packets:Array=[{"iteration_u32":0,"observations":[row]}]
	var hot:=Geometry.execute(body,parent,relative,globals,packets,models)
	var cold:Variant=JSON.parse_string(JSON.stringify(json_raw(packets)))
	var restored:=Geometry.execute(body,parent,relative,globals,cold,models)
	check(hot.ok and restored.ok,"Exact F581 continuation accepts full JSON byte transport")
	if hot.ok and restored.ok:
		check(hot.return_s32==restored.return_s32 and hot.globals_after==restored.globals_after and hot.body_after==body and hot.collider_after==parent and hot.relative_after==relative,"Cold terrain continuation preserves exact owners and result")
		terrain_cold+=1
	var malformed:Variant=cold.duplicate(true);malformed[0].observations[0].before.program="nothex"
	check(not Geometry.execute(body,parent,relative,globals,malformed,models).ok,"Malformed program transport rejects without guessing bytes")
	malformed=cold.duplicate(true);malformed[0].observations[0].before.context.normals="f"
	check(not Geometry.execute(body,parent,relative,globals,malformed,models).ok,"Odd-length raw context transport rejects")
func run()->void:
	check(FileAccess.get_sha256(Geometry.DATA_PATH)==Geometry.RESOURCE_SHA,"Complete source resource identity pinned")
	check(Geometry.catalog().size()==178,"All149 primary and29 nested resources available")
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Native observed geometry fixture pinned")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.case_count==288 and fixture.cases.size()==288 and fixture.consecutive_native_steps==32 and fixture.fresh_process_runs==3 and not fixture.expected_arithmetic_calculated_in_python,"All whole original procedure controls retained")
	for path:String in fixture.source_dependencies_sha256:check(FileAccess.get_sha256("res://"+path)==fixture.source_dependencies_sha256[path],"Native dependency pinned: "+path)
	for row:Dictionary in fixture.cases:
		var models:=resources(row);var trace:=observed(row,models);var body:=str(row.body_hex).hex_decode();var parent:=str(row.collider_hex).hex_decode();var relative:=str(row.relative_hex).hex_decode()
		var frozen:=var_to_bytes([body,parent,relative,row.globals_before,trace,models])
		var got:=Geometry.execute_observed(body,parent,relative,row.globals_before,trace,models)
		check(got.ok,"Whole F576/F579 observed execution "+str(row.name))
		if not got.ok:continue
		check(got.body_after.hex_encode()==row.expected.body_after_hex and got.collider_after.hex_encode()==row.expected.collider_after_hex and got.relative_after.hex_encode()==row.expected.relative_after_hex,"Native complete immutable raw records/vector "+str(row.name))
		check(got.return_s32==int(row.expected.return_s32) and Frame._same_globals(got.globals_after,row.expected.globals_after),"Native final return and all12 globals "+str(row.name))
		check(got.calls.size()==row.expected.calls.size(),"Native actual F579 program call count "+str(row.name))
		for i in range(got.calls.size()):
			check(got.calls[i].relative_after.hex_encode()==row.expected.calls[i].relative_after_hex,"Native F1658 source local-vector mutation "+str(row.name))
			check(got.calls[i].return_s32==int(row.expected.calls[i].return_s32),"Native source signed AL call result "+str(row.name))
		check(var_to_bytes([body,parent,relative,row.globals_before,trace,models])==frozen,"Every successful raw owner remains isolated "+str(row.name))
		native_cases+=1;native_calls+=got.calls.size()
	malformed(fixture.cases[0]);terrain_json()
	var sources:Dictionary={}
	for path:String in ["scripts/source_collision_geometry.gd","scripts/source_collision_program.gd","tests/test_source_collision_geometry.gd","tests/fixtures/source_collision_geometry_native.json","tools/rebuild_source_collision_geometry_native.py",Geometry.DATA_PATH.trim_prefix("res://"),"validation/collision-programs-2026-11-17/geometry-native-proof/instruction-proof.json","validation/collision-programs-2026-11-17/geometry-native-proof/source-procedures.asm"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"profile":Geometry.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"native_F579_calls":native_calls,"cold_terrain_continuations":terrain_cold,"sources":sources,"Main_integrated":false,"native_F582_body_executed":false,"scope":"Whole DOS F576/F579 arithmetic and child order against original instruction oracle with explicit F582 observations; public runtime invokes actual collision VM, including typed F581 continuation and exact cold byte transport. General terrain engine remains external."},"\t"));file.close()
	print("SOURCE COLLISION GEOMETRY TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
