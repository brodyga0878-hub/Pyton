extends SceneTree
const Surface=preload("res://scripts/surface_model.gd")
const World=preload("res://scripts/planetary_system.gd")
const Nav=preload("res://scripts/navigation.gd")
const Ship=preload("res://scripts/flight_model.gd")
const Visual=preload("res://scripts/surface_visual.gd")
const Renderer=preload("res://scripts/celestial_renderer.gd")
const Presentation=preload("res://scripts/world_presentation.gd")
var checks:=0
var failures:=0
func check(ok:bool,text:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func _init()->void:call_deferred("run")
func run()->void:
	var world:=World.new();var nav:=Nav.new();world.configure(nav.current());world.site_id="site10"
	var ship:=Ship.new();var surface:=Surface.new();surface.enter(ship,world)
	var original:=JSON.stringify(surface.snapshot())
	var visual:=Visual.new();root.add_child(visual);visual.configure(surface)
	var terrain:MeshInstance3D=visual.get_child(0)
	var arrays:=terrain.mesh.surface_get_arrays(0)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var triangles:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for index in [0,96,4704,4705,9408]:
		var point:Vector3=vertices[index]
		check(absf(surface.height_at(point.x,point.z)-point.y)<0.001,"Detailed material keeps collision vertices")
	var env:=Environment.new();var presentation:=Presentation.new()
	var renderer:=Renderer.new();root.add_child(renderer);renderer.configure(world)
	for quality in [0,1,2,0,2]:
		visual.set_quality(quality);visual.configure(surface);renderer.set_quality(quality)
		presentation.apply(env,surface,quality)
		check(visual.get_child(0)==terrain,"Quality changes reuse terrain")
		check(terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==vertices and terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]==triangles,"Graphics profile preserves collision mesh")
		check(JSON.stringify(surface.snapshot())==original,"Presentation does not change save state")
		check(env.background_mode==Environment.BG_SKY and env.fog_enabled==(quality>0),"Earth sky and quality-dependent haze")
		check(int(terrain.material_override.get_shader_parameter("detail_level"))==quality,"Terrain quality updates immediately")
		for i in range(surface.buildings().size()):
			var block:MeshInstance3D=visual.get_node("CityBlock%d"%i)
			check(block.mesh.size==surface.buildings()[i].size and block.position==surface.buildings()[i].get_center(),"Window material keeps solid building envelope")
		check(renderer.visuals.earth.air.visible==(quality>0),"Economy profile suppresses transparent atmosphere shell")
		check(not renderer.visuals.moon.has("air"),"Airless moon has no atmosphere shell")
	for body in world.bodies:
		if body.kind=="desert":check(not renderer.visuals[body.id].has("air"),"Desert classification does not invent an atmosphere")
	surface.active=false;presentation.apply(env,surface,2)
	check(env.background_mode==Environment.BG_COLOR and env.sky==null and not env.fog_enabled,"Orbital return clears sky and fog")
	surface.active=true;surface.kind="rock";presentation.apply(env,surface,2)
	check(env.background_mode==Environment.BG_COLOR and not env.fog_enabled,"Airless landing has no blue sky or haze")
	visual.queue_free();renderer.queue_free();await process_frame
	print("WORLD PRESENTATION TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
