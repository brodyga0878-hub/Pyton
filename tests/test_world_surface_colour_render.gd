extends SceneTree
# Measured material fixture, never presented as a gameplay screenshot. Terrain
# lighting is removed in a shader clone to isolate colour-space normalization.
const Materials=preload("res://scripts/world_surface_library.gd")
const KINDS:=["earth","rock","desert","ice"]
var checks:=0
var failures:=0
var scene:Node3D
var visual:MeshInstance3D
var camera:Camera3D
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
	var sum:=0.0;var squares:=0.0;var count:=0;var bright:=0
	for y in range(8,picture.get_height()-8,2):
		for x in range(8,picture.get_width()-8,2):
			var pixel:=picture.get_pixel(x,y)
			var value:float=(pixel.r+pixel.g+pixel.b)/3.0
			if value<=0.012:continue
			sum+=value;squares+=value*value;count+=1
			if value>=0.98:bright+=1
	var mean:=sum/maxf(count,1)
	return {"mean":mean,"std":sqrt(maxf(0.0,squares/maxf(count,1)-mean*mean)),"count":count,"clipped":bright}
func map_constant(colour:Color)->ImageTexture:
	var picture:=Image.create(1,1,false,Image.FORMAT_RGB8);picture.fill(colour)
	return ImageTexture.create_from_image(picture)
func neutral(material:ShaderMaterial)->void:
	material.set_shader_parameter("material_albedo",map_constant(Color(128.0/255.0,128.0/255.0,128.0/255.0)))
	material.set_shader_parameter("material_normal",map_constant(Color(128.0/255.0,128.0/255.0,1)))
	material.set_shader_parameter("material_orm",map_constant(Color(1,0.85,0)))
	var encoded:=Color(128.0/255.0,128.0/255.0,128.0/255.0)
	material.set_shader_parameter("material_gain",1.0/encoded.srgb_to_linear().r)
func ground_mesh(span:float)->ArrayMesh:
	var half:=span*0.5
	var vertices:=PackedVector3Array([Vector3(-half,0,-half),Vector3(half,0,-half),Vector3(half,0,half),Vector3(-half,0,-half),Vector3(half,0,half),Vector3(-half,0,half)])
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices
	var normals:=PackedVector3Array();var colours:=PackedColorArray()
	for _vertex in vertices:normals.append(Vector3.UP);colours.append(Color(0.25,0.25,0.25,1))
	arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colours
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
func ground_case(kind:String,transition:bool)->Dictionary:
	var scale:=0.03125 if kind=="ice" else 0.0625
	visual.mesh=ground_mesh(1.0/scale)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.0/scale
	camera.position=Vector3(0,100,0);camera.look_at(Vector3.ZERO,Vector3.FORWARD)
	var shader:=Shader.new()
	var path:="res://scripts/terrain_transition.gdshader" if transition else "res://scripts/terrain.gdshader"
	var code:=FileAccess.get_file_as_string(path)
	var render:=RegEx.new();render.compile("render_mode[^;]+;")
	shader.code=render.sub(code,"render_mode unshaded, fog_disabled, cull_disabled;",false)
	var material:=ShaderMaterial.new();material.shader=shader;visual.material_override=material
	material.set_shader_parameter("surface_kind",KINDS.find(kind));material.set_shader_parameter("detail_level",1)
	material.set_shader_parameter("material_scale",scale);neutral(material)
	var base:Dictionary=await stats()
	check(Materials.bind_shader(material,kind,scale),"Dedicated ground maps bind "+kind)
	var detail:Dictionary=await stats()
	check(int(detail.count)>40000 and float(detail.mean)>0.02,"Ground fixture has complete finite coverage "+kind)
	check(absf(float(base.mean)-float(detail.mean))<float(base.mean)*0.14,"Ground normalization keeps neutral tint in linear light "+kind)
	check(int(detail.clipped)==0,"Ground material avoids saturated-white clipping "+kind)
	return {"kind":kind,"transition":transition,"neutral":base,"textured":detail}
func planet_case(kind:String)->Dictionary:
	var sphere:=SphereMesh.new();sphere.radius=1;sphere.height=2;sphere.radial_segments=96;sphere.rings=64;visual.mesh=sphere
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=44;camera.position=Vector3(0,0,3.5);camera.look_at(Vector3.ZERO,Vector3.UP)
	var shader:=Shader.new();shader.code=FileAccess.get_file_as_string("res://scripts/planet.gdshader").replace("TIME","0.0")
	var material:=ShaderMaterial.new();material.shader=shader;visual.material_override=material
	material.set_shader_parameter("body_kind",{"earth":0,"rock":1,"desert":2,"ice":5}[kind])
	material.set_shader_parameter("sun_direction_world",Vector3(0.3,0.3,1).normalized());material.set_shader_parameter("detail_level",1)
	material.set_shader_parameter("material_scale",48.0);neutral(material)
	var base:Dictionary=await stats()
	check(Materials.bind_shader(material,kind,48.0),"Dedicated orbital maps bind "+kind)
	var detail:Dictionary=await stats()
	check(int(detail.count)>10000 and float(detail.mean)>0.02,"Orbital fixture has finite visible coverage "+kind)
	check(absf(float(base.mean)-float(detail.mean))<float(base.mean)*0.14,"Orbital normalization preserves procedural palette "+kind)
	return {"kind":kind,"planet":true,"neutral":base,"textured":detail}
func run()->void:
	if DisplayServer.get_name()=="headless":push_error("World colour regression requires a real renderer");quit(1);return
	root.size=Vector2i(512,512);scene=Node3D.new();root.add_child(scene)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color.BLACK;environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;scene.add_child(environment)
	visual=MeshInstance3D.new();scene.add_child(visual);camera=Camera3D.new();camera.far=200;scene.add_child(camera);camera.make_current()
	for kind in KINDS:
		var regular:Dictionary=await ground_case(kind,false);records.append(regular)
		var transition:Dictionary=await ground_case(kind,true);records.append(transition)
		check(absf(float(regular.textured.mean)-float(transition.textured.mean))<0.001,"Ground and transition agree at complete coverage "+kind)
		records.append(await planet_case(kind))
	DirAccess.make_dir_recursive_absolute("res://build/world-colour-render")
	var report:={"checks":checks,"failures":failures,"controlled_material_fixture":true,"terrain_lighting_removed_for_colour_measurement":true,"planet_shader_time_fixture":0,"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"phone_test":false,"measurements":records}
	var file:=FileAccess.open("res://build/world-colour-render/result.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("WORLD SURFACE COLOUR RENDER TESTS: %d checks, %d failures; controlled material fixture, not gameplay screenshots"%[checks,failures])
	scene.queue_free();await process_frame;quit(1 if failures else 0)
