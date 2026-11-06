extends SceneTree
const Vertices=preload("res://scripts/source_model_vertices.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<20:push_error(label)
func _initialize()->void:
	var text:=FileAccess.get_file_as_string("res://tests/fixtures/model_vertices_reference.json");var fixture:Dictionary=JSON.parse_string(text)
	check(text.sha256_text()=="220df30098cada7cf77ff2d6c6ab9d1aeb790665bfd87c5794ba5dc5be5f1a22","Independent actual F1470/F1478 fixture is pinned")
	check(fixture.source_sha256=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72" and fixture.source_assembly_sha256=="d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a","Original EXE and original source instruction provenance")
	check(fixture.fresh_process_runs==3 and fixture.reverse_repeat_count==108 and fixture.guard_canaries_unchanged,"Native fresh/reverse runs and buffer guards passed")
	check(fixture.models.size()==9 and fixture.contexts.size()==12 and fixture.cases.size()==108,"All9 original leaf streams and12 explicit snapshots covered")
	var points:=0;var kinds:Dictionary={}
	for row:Dictionary in fixture.cases:
		var model:Dictionary=fixture.models[str(int(row.model_index))];var bytes:=str(model.vertices_hex).hex_decode()
		var context:Dictionary=fixture.contexts[int(row.context_index)].duplicate(true);context.scale_shift_raw=int(model.scale_shift_raw)
		var before:=var_to_bytes(context);var kernel:=Vertices.new()
		check(kernel.configure(bytes,context),"Native leaf input accepted")
		for i in range(0,bytes.size(),6):kinds[int(bytes[i])]=true
		var result:=kernel.all_points()
		check(result.get("ok",false),"Complete actual native vertex sequence completes")
		if not result.get("ok",false):continue
		check(result.vertices_local_raw.size()==row.vertices_local_raw.size(),"Every native vertex including unused mirror points is returned")
		for i in range(row.vertices_local_raw.size()):
			points+=1
			for axis in range(3):check(int(result.vertices_local_raw[i][axis])==int(row.vertices_local_raw[i][axis]),"Exact signed32 original native vertex coordinate")
		for i in range(2):check(int(result.final_random_state_u32[i])==int(row.final_random_state_u32[i]),"Leaf evaluation preserves actual source global RNG snapshot")
		check(before==var_to_bytes(context),"Original supplied frame snapshot is immutable")
	check(points==1392 and kinds.size()==3 and kinds.has(1) and kinds.has(5) and kinds.has(19),"Actual static/mirror/negation/interpolated leaf vertex coverage")
	print("SOURCE MODEL VERTICES NATIVE TESTS: %d checks, %d failures, %d points"%[checks,failures,points]);quit(1 if failures else 0)
