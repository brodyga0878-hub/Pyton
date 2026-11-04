extends SceneTree
# Diagnostic material render, not a gameplay screenshot. The main scene, saved
# flight and device settings are never loaded or changed by this standalone tool.
const OUTPUT:="res://build/planet-materials"
const KINDS:=["earth","rock","desert","gas","ice_gas","ice","star"]
const SUN:=Vector3(0.4,0.4,0.7)
var scene:Node3D
var materials:Array[ShaderMaterial]=[]
var atmospheres:Array[MeshInstance3D]=[]
var ring_materials:Array[ShaderMaterial]=[]
var captures:Array=[]

func _initialize()->void:call_deferred("run")
func frame()->void:
	await process_frame
	await RenderingServer.frame_post_draw

func make_scene()->bool:
	var planet_shader:Shader=load("res://scripts/planet.gdshader")
	var atmosphere_shader:Shader=load("res://scripts/atmosphere.gdshader")
	var ring_shader:Shader=load("res://scripts/rings.gdshader")
	if planet_shader==null or atmosphere_shader==null or ring_shader==null:return false
	scene=Node3D.new();root.add_child(scene)
	var env:=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("020712");scene.add_child(env)
	var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(0,0,6);camera.fov=44;camera.make_current()
	for kind in range(KINDS.size()):
		var sphere:=SphereMesh.new();sphere.radius=0.63;sphere.height=1.26;sphere.radial_segments=96;sphere.rings=64
		var mesh:=MeshInstance3D.new();mesh.mesh=sphere;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.position=Vector3((kind%4-1.5)*1.45,(0.5-floor(float(kind)/4))*1.55,0)
		var material:=ShaderMaterial.new();material.shader=planet_shader
		material.set_shader_parameter("body_kind",kind);material.set_shader_parameter("sun_direction_world",SUN.normalized())
		material.set_shader_parameter("seed_offset",float(kind)*0.3);material.set_shader_parameter("inhabited",kind==0)
		mesh.material_override=material;materials.append(material);scene.add_child(mesh)
		if kind in [0,3,4]:
			var air:=MeshInstance3D.new();air.mesh=sphere;air.position=mesh.position;air.scale=Vector3.ONE*1.014
			air.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var am:=ShaderMaterial.new();am.shader=atmosphere_shader;am.set_shader_parameter("sun_direction_world",SUN.normalized())
			air.material_override=am;atmospheres.append(air);scene.add_child(air)
		if kind==3:
			# Match the live renderer's unit Torus/radial shader coordinates before
			# applying the shared planetary scale, rather than baking small radii.
			var ring:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=1.25;torus.outer_radius=2.25
			torus.rings=96;torus.ring_segments=12;ring.mesh=torus;ring.position=mesh.position
			ring.scale=Vector3(0.63,0.63*0.025,0.63);ring.rotation.x=0.42;ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var rm:=ShaderMaterial.new();rm.shader=ring_shader;rm.set_shader_parameter("sun_direction_local",Basis(Vector3.RIGHT,-0.42)*SUN.normalized())
			ring.material_override=rm;ring_materials.append(rm);scene.add_child(ring)
	return true

func photograph(quality:int)->bool:
	for material in materials:material.set_shader_parameter("detail_level",quality)
	for atmosphere in atmospheres:atmosphere.visible=quality>0
	for material in ring_materials:material.set_shader_parameter("detail_level",quality)
	for warmup in range(5):await frame()
	var filename:="planet-materials-quality%d.png"%quality
	var captured:=root.get_texture().get_image()
	if captured==null or captured.is_empty() or captured.get_size()!=root.size:
		push_error("Planet material viewport did not return a complete image");return false
	if captured.save_png(OUTPUT+"/"+filename)!=OK:
		push_error("Cannot write planet material capture");return false
	captures.append({"file":filename,"quality":quality,"body_kinds":KINDS,"atmosphere_instances":atmospheres.size() if quality>0 else 0,"ring_instances":ring_materials.size(),"inhabited_body_kinds":["earth"]})
	return true

func finish(code:int)->void:
	if is_instance_valid(scene):scene.queue_free();await process_frame
	quit(code)

func run()->void:
	if DisplayServer.get_name()=="headless":push_error("Planet material capture requires a real rendered viewport");await finish(1);return
	if DirAccess.make_dir_recursive_absolute(OUTPUT)!=OK:push_error("Cannot create planet material output directory");await finish(1);return
	root.size=Vector2i(1050,700)
	if not make_scene():push_error("Cannot load planet material shaders");await finish(1);return
	for quality in [0,2]:
		if not await photograph(quality):await finish(1);return
	var report:={"kind":"diagnostic_material_probe","gameplay_screenshot":false,"image_source":"direct Godot viewport; no compositing","engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"display_server":DisplayServer.get_name(),"viewport_size":[root.size.x,root.size.y],"sun_direction":[SUN.normalized().x,SUN.normalized().y,SUN.normalized().z],"shader_time":"Real shader TIME, decorative clouds only; images are not asserted byte-identical across runs","user_progress_read":false,"user_progress_written":false,"physical_android_device_tested":false,"captures":captures}
	var file:=FileAccess.open(OUTPUT+"/capture-manifest.json",FileAccess.WRITE)
	if file==null:push_error("Cannot write planet material manifest");await finish(1);return
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PLANET MATERIAL CAPTURES PASS: 7 branches at quality0/2, atmospheres/rings, actual %s viewport, no user progress access"%report.renderer)
	await finish(0)
