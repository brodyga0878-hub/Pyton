extends SceneTree
const Compiler=preload("res://scripts/source_model_mesh.gd")
const Visual=preload("res://scripts/source_model_visual.gd")
var world:Node3D
var model_id:=89
func _init()->void:call_deferred("run")
func run()->void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--model="):model_id=int(argument.trim_prefix("--model="))
	var start:=Time.get_ticks_usec()
	var compiled:=Compiler.new().compile(model_id,{"source_seed":0xbdd3aa2e})
	if not compiled.ok:push_error(str(compiled));quit(1);return
	world=Node3D.new();root.add_child(world)
	var visual:=Visual.new();world.add_child(visual)
	if not visual.configure(compiled):push_error("No source geometry");quit(1);return
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-28,0);light.light_energy=1.1;world.add_child(light)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("071321")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("a6b9ca");environment.environment.ambient_light_energy=0.5;world.add_child(environment)
	var camera:=Camera3D.new();camera.fov=55;camera.far=1000000
	var center:Vector3=visual.local_bounds.get_center();var extent:float=maxf(1,visual.local_bounds.size.length())
	camera.near=maxf(0.5,extent*0.002);camera.far=extent*8.0
	camera.position=center+Vector3(0.62,0.7,1.05)*extent;camera.look_at_from_position(camera.position,center,Vector3.UP);world.add_child(camera)
	print("SOURCE MODEL PREVIEW: model %d, %d source triangles, %d source instances, bounds %s metres, preparation %.1f ms"%[model_id,visual.triangle_count,compiled.instance_count,visual.local_bounds.size,(Time.get_ticks_usec()-start)/1000.0])
	for frame in range(4):await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/source-model-%d.png"%model_id)
	visual.free();world.free();quit()
