extends SceneTree
# Real Compatibility renderer regression, separate from headless logic suites.
# No gameplay captures: a controlled quad measures colour normalization directly.
const CityShader=preload("res://scripts/source_model.gdshader")
const Materials=preload("res://scripts/city_surface_library.gd")
var checks:=0
var failures:=0
var records:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func frame()->void:
	await process_frame
	await RenderingServer.frame_post_draw
func stats()->Dictionary:
	for i in range(3):await frame()
	var picture:=root.get_texture().get_image()
	var sum:=0.0;var squares:=0.0;var count:=0
	for y in range(8,picture.get_height()-8):
		for x in range(8,picture.get_width()-8):
			var pixel:=picture.get_pixel(x,y)
			var value:float=(pixel.r+pixel.g+pixel.b)/3.0
			sum+=value;squares+=value*value;count+=1
	var mean:=sum/float(count)
	return {"mean":mean,"std":sqrt(maxf(0.0,squares/float(count)-mean*mean))}
func run()->void:
	if DisplayServer.get_name()=="headless":push_error("Colour regression needs actual gl_compatibility rendering");quit(1);return
	root.size=Vector2i(512,512)
	var scene:=Node3D.new();root.add_child(scene)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color.BLACK
	environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	scene.add_child(environment)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=16;camera.position=Vector3(0,0,10);scene.add_child(camera);camera.make_current()
	var visual:=MeshInstance3D.new();scene.add_child(visual)
	var material:=ShaderMaterial.new();material.shader=CityShader
	check(Materials.bind_shader(material),"Real atlas binds for the colour regression")
	visual.material_override=material
	for role in range(4):
		var vertices:=PackedVector3Array([Vector3(-8,-8,0),Vector3(8,-8,0),Vector3(8,8,0),Vector3(-8,-8,0),Vector3(8,8,0),Vector3(-8,8,0)])
		var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices
		var normals:=PackedVector3Array();var colours:=PackedColorArray();var uv2:=PackedVector2Array()
		for vertex in vertices:normals.append(Vector3.BACK);colours.append(Color(0.25,0.25,0.25,1));uv2.append(Vector2(0,role))
		arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colours;arrays[Mesh.ARRAY_TEX_UV2]=uv2
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);visual.mesh=mesh
		material.set_shader_parameter("detail_level",0);var neutral:Dictionary=await stats()
		material.set_shader_parameter("detail_level",1);var detailed:Dictionary=await stats()
		material.set_shader_parameter("detail_level",2);var high:Dictionary=await stats()
		check(absf(float(detailed.mean)-float(neutral.mean))<float(neutral.mean)*0.12,"Role%d preserves neutral source brightness within12%% after linear normalization"%role)
		check(float(detailed.std)>0.006,"Role%d retains measurable texture variation instead of clipping flat"%role)
		check(absf(float(detailed.mean)-float(high.mean))<0.002 and absf(float(detailed.std)-float(high.std))<0.002,"Unlit role%d changes no lighting when high quality enables lit normals"%role)
		records.append({"role":role,"neutral":neutral,"textured":detailed,"high":high})
	var report:={"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"phone_test":false,"controlled_fixture":true,"measurements":records,"checks":checks,"failures":failures}
	DirAccess.make_dir_recursive_absolute("res://build/city-colour-render")
	var file:=FileAccess.open("res://build/city-colour-render/result.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CITY COLOUR RENDER TESTS: %d checks, %d failures; controlled actual renderer, not gameplay screenshots"%[checks,failures])
	scene.queue_free();await process_frame;quit(1 if failures else 0)
