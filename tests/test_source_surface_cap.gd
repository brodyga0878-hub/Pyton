extends SceneTree
# Real source117 overdraw regression plus a default-off legacy shader contract.
const World=preload("res://scripts/planetary_system.gd")
const GalaxyData=preload("res://scripts/galaxy.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const GlobalMesh=preload("res://scripts/source_global_body_mesh.gd")
const Renderer=preload("res://scripts/celestial_renderer.gd")
const PlanetShader=preload("res://scripts/planet.gdshader")
var checks:=0
var failures:=0
var measured:Dictionary={}
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")

func source_case(world:RefCounted,id:String,lat:float,lon:float)->Dictionary:
	world.focus_id=id
	var input:=GlobalMesh.snapshot(world,id);var result:=GlobalMesh.build(input)
	check(result.get("ok",false),"Actual source global mesh builds for cap control "+id)
	if not result.get("ok",false):return {}
	var terrain:=Terrain.new();terrain.configure(world,id,"",Terrain.REVISION_NAME);terrain.latitude=lat;terrain.longitude=lon
	var elevation:=terrain.elevation(lat,lon);var radial:=Vector3(cos(lat)*cos(lon),sin(lat),-cos(lat)*sin(lon))
	var renderer:=Renderer.new();root.add_child(renderer);renderer._source_cache[GlobalMesh.key(input)]=result;renderer.configure(world)
	renderer.set_source_ground_patch(terrain);renderer.set_surface_transition(true,0)
	var body_basis:Basis=world.body_rotation_basis(id,0.0);var centre:Vector3=world.local_meters(id,0.0)
	var observer:Vector3=centre+body_basis*radial*(terrain.radius+elevation+20000)
	renderer.update_view(0.0,observer)
	var cap:=renderer.source_cap_state(id)
	var outer:=minf(terrain.maximum_patch_extent(),minf(512000.0,terrain.radius*0.7))
	check(cap.enabled and cap.direction.distance_to(radial)<0.000001,"Actual body-fixed patch anchor enables native cap "+id)
	check(absf(float(cap.rendered_outer_m)-outer)<0.000001 and float(cap.radius_m)<outer,"Cap follows actual source maximum extent, including117minimum axis")
	check(float(cap.maximum_body_radius_m)*sin(acos(float(cap.cosine)))<=outer*0.900001,"Whole cap stays inside rendered orthographic near-ground footprint")
	for index in range(16):check(Renderer.source_cap_hidden(radial,cap,(index+0.5)/16.0),"Low-AGL actual cap leaves no opaque global fragment over exact source ground")
	var angle:=acos(float(cap.cosine));var axis:=radial.cross(Vector3.UP).normalized()
	if axis.length_squared()<0.5:axis=Vector3.RIGHT
	var far_direction:=Basis(axis,minf(angle*2.0,PI))*radial
	for index in range(16):check(not Renderer.source_cap_hidden(far_direction,cap,(index+0.5)/16.0),"Source cap preserves every outside-cap far-horizon fragment")
	renderer.set_surface_transition(true,0.5);renderer.update_view(0,observer);cap=renderer.source_cap_state(id)
	var hidden:=0
	for index in range(16):
		if Renderer.source_cap_hidden(radial,cap,(index+0.5)/16.0):hidden+=1
	check(hidden==8,"Global source cap returns with exactly complementary half screen coverage")
	renderer.set_surface_transition(true,1);renderer.update_view(0,observer);cap=renderer.source_cap_state(id)
	check(not Renderer.source_cap_hidden(radial,cap,0.01),"Space endpoint restores global source view without a persistent hole")
	# Main's high-surface scene transform uses local terrain camera coordinates.
	var frame:=Transform3D(body_basis*terrain.basis_at(lat,lon),centre+body_basis*radial*terrain.radius)
	renderer.transform=frame.affine_inverse();renderer.set_surface_transition(true,0);renderer.update_view(0,renderer.transform*observer)
	cap=renderer.source_cap_state(id)
	check(cap.direction.distance_to(radial)<0.000001 and cap.direction_world.distance_to((renderer.global_basis*body_basis*radial).normalized())<0.000001,"Native cap remains in same body patch through actual high-surface frame")
	for body:Dictionary in world.bodies:
		if body.id==id or body.kind=="barycenter":continue
		var relative:Vector3=world.local_meters(str(body.id),0.0)-observer;var distance:=maxf(relative.length(),1)
		var expected:=observer+relative/distance*3000000.0
		check(renderer.visuals[str(body.id)].anchor.position.distance_to(expected)<16.0,"FULL camera is converted from local surface frame before far-body placement")
		break
	renderer.set_source_ground_patch(null);renderer.update_view(0,renderer.transform*observer)
	check(not renderer.source_cap_state(id).enabled,"Without actual near-ground context no global cap is invented")
	renderer.queue_free()
	return {"result":result,"terrain":terrain,"radial":radial,"elevation":elevation,"cap":cap}

func numeric_controls()->void:
	check(PlanetShader.code.contains("uniform bool source_surface_cap_enabled = false;"),"Cap is explicit opt-in with shader default off")
	var world:=World.new();world.configure(GalaxyData.new().get_system(GalaxyData.SOL_ID),World.FULL_LAYOUT)
	var source117:=""
	for body:Dictionary in world.bodies:
		if int(body.model_index)==117:source117=str(body.id);break
	check(not source117.is_empty(),"Independent actual Sol runtime supplies nonspherical source117 body")
	if source117.is_empty():return
	measured=source_case(world,source117,-PI/8,PI/2)
	if not measured.is_empty():
		var vertex:Vector3=measured.result.arrays[Mesh.ARRAY_VERTEX][12*65+48]
		var above:=vertex.length()*float(measured.result.radius_m)-(float(measured.terrain.radius)+float(measured.elevation))
		check(above>10000 and above<12000,"Actual117regression retains independently measured~10.9km coarse overshoot to prove cap addresses real defect")
		measured.overshoot_m=above
	var earth:=source_case(world,"earth",0.27,-0.44)
	check(not earth.is_empty(),"Actual source Earth uses same safe cap policy")
	await process_frame

func gpu_controls()->void:
	if DisplayServer.get_name()=="headless" or measured.is_empty():return
	var scene:=Node3D.new();root.add_child(scene);var world_env:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color.BLACK;world_env.environment=env;scene.add_child(world_env)
	var planet:=MeshInstance3D.new();var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,measured.result.arrays);planet.mesh=mesh
	var material:=ShaderMaterial.new();material.shader=PlanetShader;material.set_shader_parameter("body_kind",1);material.set_shader_parameter("detail_level",0);material.set_shader_parameter("sun_direction_world",measured.radial);planet.material_override=material;scene.add_child(planet)
	var radius:=float(measured.result.radius_m);var ground_radius:=(float(measured.terrain.radius)+float(measured.elevation))/radius
	var ground:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2.ONE*(12000.0/radius);ground.mesh=quad
	var red:=StandardMaterial3D.new();red.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;red.albedo_color=Color(0.9,0.03,0.01);red.cull_mode=BaseMaterial3D.CULL_DISABLED;ground.material_override=red
	ground.position=Vector3(measured.radial)*ground_radius;ground.basis=Basis.looking_at(-Vector3(measured.radial),Vector3.UP);scene.add_child(ground)
	var camera:=Camera3D.new();camera.fov=45;camera.near=0.0001;camera.far=5;camera.position=Vector3(measured.radial)*(ground_radius+20000.0/radius);scene.add_child(camera);camera.look_at(ground.position,Vector3.UP);camera.make_current()
	root.size=Vector2i(512,512)
	for frame in range(4):await process_frame;await RenderingServer.frame_post_draw
	var before:=root.get_texture().get_image();var pixel_before:=before.get_pixel(256,256)
	material.set_shader_parameter("source_surface_cap_enabled",true);material.set_shader_parameter("source_surface_cap_direction_world",measured.radial);material.set_shader_parameter("source_surface_cap_cosine",float(measured.cap.cosine));material.set_shader_parameter("source_surface_cap_coverage",0.0)
	for frame in range(4):await process_frame;await RenderingServer.frame_post_draw
	var after:=root.get_texture().get_image();var pixel_after:=after.get_pixel(256,256)
	check(pixel_before.r<0.7 or pixel_before.g>0.1,"Actual117coarse source globe occludes red exact-ground control without native cap")
	check(pixel_after.r>0.7 and pixel_after.g<0.12 and pixel_after.b<0.12,"Actual GLES cap exposes exact source ground through previously opaque117LOD")
	print("CAP GLES PIXELS before=",pixel_before," after=",pixel_after," measured_overshoot_m=",measured.overshoot_m)
	scene.queue_free();await process_frame

func run()->void:
	await numeric_controls();await gpu_controls()
	print("SOURCE SURFACE CAP TESTS: ",checks," checks, ",failures," failures; native117/Earth, global horizon, default-off legacy shader")
	quit(1 if failures else 0)
