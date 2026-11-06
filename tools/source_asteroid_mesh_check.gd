extends SceneTree
# Offline spike: actual source asset + independent native vertices. No game IO.
const VM=preload("res://scripts/source_model_vm.gd")
const Vertices=preload("res://scripts/source_model_vertices.gd")
const MeshCompiler=preload("res://scripts/source_model_mesh.gd")
const Units=preload("res://scripts/source_units.gd")
const FIXTURE:="res://tests/fixtures/source_asteroid_mesh_spike.json"
const OUTPUT:="res://build/source-asteroid112-mesh-spike.json"
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)
func hit(direction:Vector3,triangles:Array)->Dictionary:
	var best:=INF
	var normal:=Vector3.ZERO
	var best_index:=-1
	for index in range(triangles.size()):
		var row:Dictionary=triangles[index]
		var vertices:Array=row.vertices
		var a:=Vector3(vertices[0][0],vertices[0][1],vertices[0][2])
		var b:=Vector3(vertices[1][0],vertices[1][1],vertices[1][2])
		var c:=Vector3(vertices[2][0],vertices[2][1],vertices[2][2])
		var edge1:=b-a
		var edge2:=c-a
		var p:=direction.cross(edge2)
		var determinant:=edge1.dot(p)
		if absf(determinant)<0.00001:continue
		var inverse:=1.0/determinant
		var tvec:=-a
		var u:=tvec.dot(p)*inverse
		if u< -0.000001 or u>1.000001:continue
		var q:=tvec.cross(edge1)
		var v:=direction.dot(q)*inverse
		if v< -0.000001 or u+v>1.000001:continue
		var distance:=edge2.dot(q)*inverse
		if distance>0 and distance<best:
			best=distance;normal=edge1.cross(edge2).normalized();best_index=index
	if best_index<0:return {"ok":false}
	if normal.dot(direction)<0:normal=-normal
	return {"ok":true,"radius_raw":best,"radius_m":Units.metres(best),"triangle_index":best_index,"normal":[normal.x,normal.y,normal.z]}
func run()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.get("revision")=="source-asteroid112-offline-spike-v1","Reviewed offline fixture")
	var models:Dictionary=fixture.assets.models
	# This is a standalone process; the runtime resource loader is unmodified.
	VM.assets=models
	for row:Dictionary in fixture.cases:
		var evaluator:=Vertices.new()
		var context:Dictionary=row.context.duplicate(true)
		context.scale_shift_raw=12
		check(evaluator.configure(str(models["112"].vertex_hex).hex_decode(),context),"Source vertex evaluator accepts exact model112 stream")
		var actual:=evaluator.all_points()
		check(actual.ok,"Source112 vertex evaluation succeeds")
		for index in range(row.vertices_local_raw.size()):
			var equal:=true
			for axis in range(3):equal=equal and int(actual.vertices_local_raw[index][axis])==int(row.vertices_local_raw[index][axis])
			check(equal,"Source112 vertices match independent native output")
		check(int(actual.final_random_state_u32[0])==int(row.final_random_state_u32[0]) and int(actual.final_random_state_u32[1])==int(row.final_random_state_u32[1]),"Static source112 consumes no invented randomness")
	var compiled:=MeshCompiler.new().compile(112)
	check(compiled.ok,"Existing model VM compiles exact source112 program")
	if not compiled.ok:quit(1);return
	check(compiled.triangle_count>0,"Source112 has real solid triangles")
	check(compiled.instance_count==1,"Source112 has no substituted submodels")
	var rays:Array=[]
	for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK,Vector3(1,1,1).normalized(),Vector3(-1,1,-1).normalized()]:
		var result:=hit(direction,compiled.triangles_raw)
		check(result.ok,"Source112 actual rendered mesh intersects tested body ray")
		if result.ok:
			result.direction=[direction.x,direction.y,direction.z]
			rays.append(result)
	DirAccess.make_dir_recursive_absolute("res://build")
	var file:=FileAccess.open(OUTPUT,FileAccess.WRITE)
	file.store_string(JSON.stringify({"profile":"offline-source112-native-vertex-and-mesh-spike-v1","checks":checks,"failures":failures,"native_vertex_points":200,"model_index":112,"triangle_count":compiled.triangle_count,"source_events":compiled.source_events.size(),"bounds_raw":compiled.bounds_raw,"radial_mesh_intersections":rays,"original_collider_executed":false,"runtime_landability_enabled":false},"\t"));file.close()
	print("SOURCE ASTEROID112 SPIKE: %d checks, %d failures; %d rendered triangles; original collider and live landing not implemented"%[checks,failures,compiled.triangle_count])
	quit(1 if failures else 0)
