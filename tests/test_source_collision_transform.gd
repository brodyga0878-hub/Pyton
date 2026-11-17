extends SceneTree
const Transform=preload("res://scripts/source_collision_transform.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const FIXTURE:="res://tests/fixtures/source_collision_transform_native.json"
const FIXTURE_SHA:="34801772f5c68a0d776d43295fc40ff8f987e442cb18153c91237c5b4138d0cd"
const REPORT:="res://build/current-test-reports/source-collision-transform.json"
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,description:String)->void:
 checks+=1
 if not value:
  failures+=1
  if failures<22:push_error(description)
func context(row:Dictionary)->Dictionary:
 return {"point_xyz_s32":row.point_xyz_s32.duplicate(),"normals":str(row.normals_hex).hex_decode(),"vertices":str(row.vertices_hex).hex_decode(),"mesh_zoom_s32":row.mesh_zoom_s32,"vector_scale_s32":row.vector_scale_s32,"vertex_origin_u32":row.vertex_origin_u32}
func resource(row:Dictionary)->Dictionary:
 return {"descriptor":str(row.descriptor_hex).hex_decode(),"normals":str(row.normals_hex).hex_decode(),"vertices":str(row.vertices_hex).hex_decode(),"collision_program":str(row.collision_program_hex).hex_decode(),"normal_origin_u32":row.normal_origin_u32,"vertex_origin_u32":row.vertex_origin_u32}
func integers(value:Array)->Array:return [int(value[0]),int(value[1]),int(value[2])]
func run()->void:
 check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Complete native F580 fixture is pinned")
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
 check(fixture.profile==Transform.PROFILE and fixture.case_count==416 and fixture.cases.size()==416,"All416 native source controls present")
 check(fixture.proof.fresh_process_runs==3 and fixture.proof.reverse_repeat_cases==416 and fixture.proof.consecutive_native_steps==32 and not fixture.proof.expected_arithmetic_calculated_in_Python,"Fresh/reverse/dependent native controls are independent")
 for path:String in fixture.proof.source_dependencies_sha256:check(FileAccess.get_sha256("res://"+path)==fixture.proof.source_dependencies_sha256[path],"Pinned native reproduction input "+path)
 var count:=0;var negative:=0;var prior:Dictionary={};var prior_resource:Dictionary={}
 for row:Dictionary in fixture.cases:
  var before:=context(row.context_before);var model:=resource(row.model_resource);var frozen:=var_to_bytes([before,model])
  var result:=Transform.prepare_nested(before,model,row.vertex_u8,row.orientation_u8,row.threshold_s32)
  check(result.get("ok",false),"Actual nested source transform "+str(row.name))
  if not result.get("ok",false):continue
  var expected:Dictionary=row.expected
  check(result.context_after.point_xyz_s32==integers(expected.point_xyz_s32),"All3 native signed transformed coordinates match "+str(row.name))
  check(int(result.context_after.mesh_zoom_s32)==int(expected.mesh_zoom_s32) and int(result.context_after.vector_scale_s32)==int(expected.vector_scale_s32),"Exact model zoom/wrapped sum and inherited vector scale "+str(row.name))
  var resumed:=Transform.resume_nested(row.recursive_return_u32,row.recursive_primitive_u8)
  check(resumed.ok and int(resumed.return_s32)==int(expected.return_s32) and int(resumed.primitive_u8)==int(expected.primitive_u8),"Actual F580 sign-extends F582 AL and preserves output primitive "+str(row.name))
  check(int(result.threshold_s32)==int(expected.threshold_s32),"F580 retains original threshold "+str(row.name))
  check(result.context_after.normals==str(expected.new_normals_after_hex).hex_decode() and result.context_after.vertices==str(expected.new_vertices_after_hex).hex_decode() and result.program==str(expected.program_after_hex).hex_decode(),"Native recursive call selects exact new model resources "+str(row.name))
  check(int(result.context_after.normal_origin_u32)==int(model.normal_origin_u32) and int(result.context_after.vertex_origin_u32)==int(model.vertex_origin_u32),"Logical pointer origins preserved "+str(row.name))
  check(result.request.kind=="F582" and result.request.context==result.context_after and int(result.request.threshold_s32)==int(expected.threshold_s32) and result.source_order==["F580","F1538"] and not result.recursive_F582_executed,"Recursive request is explicit and arithmetic preparation does not execute F582")
  check(var_to_bytes([before,model])==frozen,"Caller raw context/model resources unchanged "+str(row.name))
  if row.has("sequence_index"):
   if int(row.sequence_index)>0:
    check(integers(before.point_xyz_s32)==prior.point_xyz_s32 and int(before.mesh_zoom_s32)==int(prior.mesh_zoom_s32) and int(before.vector_scale_s32)==int(prior.vector_scale_s32),"Consecutive native outputs become next transform input")
    check(before.vertices.slice(0,192)==prior.vertices and int(before.vertex_origin_u32)==int(prior_resource.vertex_origin_u32),"Consecutive model vertex pointer remains native")
   prior=result.context_after.duplicate(true);prior_resource=model.duplicate(true)
  if int(row.vertex_u8)>=128:negative+=1
  if count%32==0:
   result.context_after.point_xyz_s32[0]=int(result.context_after.point_xyz_s32[0])^1
   result.context_after.vertices[0]=int(result.context_after.vertices[0])^1
   result.request.context.normals[0]=int(result.request.context.normals[0])^1
   check(var_to_bytes([before,model])==frozen,"Output mutation cannot alter caller data")
  count+=1
 var first:Dictionary=fixture.cases[0];var base:=context(first.context_before);var model:=resource(first.model_resource);var frozen:=var_to_bytes([base,model])
 for bad:Variant in [null,true,0,"context",[],{},PackedByteArray()]:
  check(not Transform.prepare_nested(bad,model,0,0,0).ok,"Malformed context rejects")
  check(not Transform.prepare_nested(base,bad,0,0,0).ok,"Malformed model rejects")
 for key:String in Transform.CONTEXT_KEYS:
  var altered:=base.duplicate(true);altered.erase(key);check(not Transform.prepare_nested(altered,model,0,0,0).ok,"Missing context property rejects "+key)
 for key:String in Transform.RESOURCE_KEYS:
  var altered:=model.duplicate(true);altered.erase(key);check(not Transform.prepare_nested(base,altered,0,0,0).ok,"Missing model property rejects "+key)
 for bad:Variant in [-1,256,NAN,INF,true,0.5,"0",null]:
  check(not Transform.prepare_nested(base,model,bad,0,0).ok,"Invalid source vertex byte rejects")
  check(not Transform.prepare_nested(base,model,0,bad,0).ok,"Invalid axis byte rejects")
 for bad:Variant in [-0x80000001,0x80000000,NAN,INF,true,0.5,"0",null]:check(not Transform.prepare_nested(base,model,0,0,bad).ok,"Invalid threshold rejects")
 for bad:Variant in [-1,0x100000000,NAN,INF,true,0.5,"0",null]:check(not Transform.resume_nested(bad,0).ok,"Malformed recursive return word rejects")
 for bad:Variant in [-1,256,NAN,INF,true,0.5,"0",null]:check(not Transform.resume_nested(0,bad).ok,"Malformed recursive primitive byte rejects")
 for axes in range(256):
  if (axes&7)>5:check(not Transform.prepare_nested(base,model,0,axes,0).ok,"Original uninitialized axis permutations reject atomically")
 for code:int in [64,126,127,128,129,190,191]:check(not Transform.prepare_nested(base,model,code,0,0).ok,"Packed signed vertex offset beyond explicit resource rejects")
 var no_origin:=base.duplicate(true);no_origin.erase("vertex_origin_u32")
 check(Transform.prepare_nested(no_origin,model,0,0,0).ok,"Legacy zero vertex origin remains supported")
 check(not Transform.prepare_nested(no_origin,model,254,0,0).ok,"Negative vertex requires retained prefix, never fabricated")
 check(var_to_bytes([base,model])==frozen,"All malformed and unsupported calls preserve inputs")
 var sources:Dictionary={}
 for path:String in ["scripts/source_collision_transform.gd","tests/test_source_collision_transform.gd","tests/fixtures/source_collision_transform_native.json","tools/rebuild_source_collision_transform_native.py","validation/collision-programs-2026-11-17/transform-native-proof/instruction-proof.json","validation/collision-programs-2026-11-17/transform-native-proof/source-procedures.asm"]:sources[path]=FileAccess.get_sha256("res://"+path)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
 var file:=FileAccess.open(REPORT,FileAccess.WRITE)
 if file:file.store_string(JSON.stringify({"profile":Transform.PROFILE,"checks":checks,"failures":failures,"native_cases":count,"signed_negative_vertex_cases":negative,"consecutive_native_steps":32,"sources":sources,"recursive_F582_executed":false,"Main_integrated":false},"\t"));file.close()
 print("SOURCE COLLISION TRANSFORM TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
