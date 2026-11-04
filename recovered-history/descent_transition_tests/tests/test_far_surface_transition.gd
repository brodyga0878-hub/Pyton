extends SceneTree
const NearView=preload("res://scripts/near_surface_view.gd")
const Surface=preload("res://scripts/surface_model.gd")
const World=preload("res://scripts/planetary_system.gd")
const Nav=preload("res://scripts/navigation.gd")
const Ship=preload("res://scripts/flight_model.gd")
const Visual=preload("res://scripts/surface_visual.gd")
const Renderer=preload("res://scripts/celestial_renderer.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _init()->void:call_deferred("run")
func run()->void:
	check(is_zero_approx(NearView.far_blend(0)) and is_zero_approx(NearView.far_blend(NearView.FADE_START)),"Near endpoint has no distant image contribution")
	check(is_equal_approx(NearView.far_blend(NearView.FADE_END),1.0) and is_equal_approx(NearView.far_blend(100000),1.0),"Far endpoint has full distant contribution")
	var previous:=-1.0
	for height in range(20000,64001,500):
		var blend:float=NearView.far_blend(float(height))
		check(blend>=0 and blend<=1 and blend>=previous,"Outward transition is bounded and monotonic")
		previous=blend
	previous=2.0
	for height in range(64000,19999,-500):
		var blend:float=NearView.far_blend(float(height))
		check(blend<=previous,"Inward transition traverses the same band monotonically")
		previous=blend
	check(NearView.far_blend(NearView.FADE_START+1.0)<0.00001,"Near boundary has a smooth start")
	check(1.0-NearView.far_blend(NearView.FADE_END-1.0)<0.00001,"Far boundary has a smooth finish")
	var nav:=Nav.new();var world:=World.new();world.configure(nav.current());world.site_id="site10"
	var ship:=Ship.new();var surface:=Surface.new();surface.enter(ship,world,true);surface.extended_flight=true
	ship.position.y=surface.height_at(0,0)+surface.clearance(ship)+20000;ship.velocity=Vector3.ZERO
	check(surface.leave(ship,world,10),"Prepared surface can create a geographic orbital link")
	world.site_id=""
	var source_before:=JSON.stringify(surface.snapshot());var world_before:=JSON.stringify(world.snapshot())
	var view:=NearView.new();var visual:=Visual.new();var renderer:=Renderer.new();root.add_child(visual);root.add_child(renderer);renderer.configure(world)
	var center:Vector3=world.local_meters(world.focus_id,10);var radius:float=world.by_id[world.focus_id].radius_km*1000
	var first_mesh:Node;var first_key:="";var last_blend:=-1.0
	for altitude in [20000.0,23800.0,26000.0,32000.0,40000.0,50000.0,59984.0]:
		# A fixed polar direction avoids tangent motion and isolates the altitude transition.
		ship.position=center+Vector3.UP*(radius+altitude)
		var ship_before:=JSON.stringify(ship.snapshot())
		check(view.update(surface,ship,world,10) and view.active,"Linked preview stays active throughout distant transition band")
		check(view.space_blend>=last_blend and view.space_blend>=0 and view.space_blend<=1,"Preview reports continuous far contribution")
		last_blend=view.space_blend
		visual.configure(view.drawing)
		if first_mesh==null:first_mesh=visual.get_child(0);first_key=view.drawing.terrain_key()
		check(visual.get_child(0)==first_mesh and view.drawing.terrain_key()==first_key,"Altitude blend reuses existing terrain geometry")
		var arrays_before:Array=visual.get_child(0).mesh.surface_get_arrays(0)
		visual.set_view_coverage(1.0-view.space_blend)
		check(visual.get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==arrays_before[Mesh.ARRAY_VERTEX],"Coverage updates never displace collision vertices")
		var layers:=0
		for node in visual.get_children():
			if node.get_meta("terrain_layer",false):
				layers+=1
				check(is_equal_approx(float(node.material_override.get_shader_parameter("view_coverage")),1.0-view.space_blend),"Every terrain LOD receives consistent near coverage")
				check(node.material_override.shader==(Visual.TerrainShader if visual.view_coverage>=1.0 else Visual.TransitionShader),"Partial coverage uses smooth overlay; full coverage restores opaque terrain")
		check(layers>=4,"Distant terrain rings participate in transition")
		for quality in [0,2]:
			visual.set_quality(quality)
			for node in visual.get_children():
				if node.get_meta("terrain_layer",false):check(int(node.material_override.get_shader_parameter("detail_level"))==quality,"Quality changes update active terrain transition material")
		renderer.set_surface_transition(true,view.space_blend);renderer.update_view(10,ship.position)
		var focus:Dictionary=renderer.visuals[world.focus_id]
		check(focus.anchor.visible and is_equal_approx(float(focus.mesh.material_override.get_shader_parameter("view_coverage")),1.0),"Full focus sphere remains as baseline wherever terrain has no fragment")
		check(focus.mesh.material_override.get_shader_parameter("coverage_invert")==false,"Baseline sphere never uses complementary hole masking")
		check(focus.anchor.position.distance_to(center)<0.1,"Blending sphere uses physical planet centre")
		var expected_radius:=radius-350.0*(1.0-view.space_blend)
		check(absf(focus.anchor.scale.x-expected_radius)<1.0,"Underlying sphere is inset beneath terrain while near contribution remains")
		check(focus.mesh.mesh.radial_segments>=256 and focus.mesh.mesh.rings>=128,"Near baseline sphere has high-resolution silhouette")
		check(is_equal_approx(float(focus.air.material_override.get_shader_parameter("view_coverage")),view.space_blend),"Atmosphere emerges with distant contribution")
		check(is_equal_approx(float(renderer.visuals.moon.mesh.material_override.get_shader_parameter("view_coverage")),view.space_blend),"Other celestial bodies emerge progressively")
		check(renderer.visuals.moon.anchor.position.distance_to(ship.position)>2900000,"Other bodies stay beyond the physical planet horizon")
		check(renderer.visuals.saturn.has("rings") and is_equal_approx(float(renderer.visuals.saturn.rings.material_override.get_shader_parameter("view_coverage")),view.space_blend),"Rings emerge with their parent planet instead of popping at band start")
		check(JSON.stringify(surface.snapshot())==source_before and JSON.stringify(world.snapshot())==world_before and JSON.stringify(ship.snapshot())==ship_before,"Transition presentation does not mutate saved game state")
	# At full far contribution the physical and compressed spheres have the same angular size.
	ship.position=center+Vector3.UP*(radius+60000.0)
	renderer.set_surface_transition(true,1.0);renderer.update_view(10,ship.position)
	var focus:Dictionary=renderer.visuals[world.focus_id]
	var actual_ratio:float=focus.anchor.scale.x/focus.anchor.position.distance_to(ship.position)
	renderer.set_surface_transition(false,1.0);renderer.update_view(10,ship.position)
	var compressed_ratio:float=focus.anchor.scale.x/focus.anchor.position.distance_to(ship.position)
	check(absf(actual_ratio-compressed_ratio)<0.00005,"Switching baseline back to compressed space retains its angular projection")
	check(is_equal_approx(float(focus.mesh.material_override.get_shader_parameter("view_coverage")),1.0) and is_equal_approx(float(focus.air.material_override.get_shader_parameter("view_coverage")),1.0),"Normal space resets focus material coverage")
	check(is_equal_approx(float(renderer.visuals.moon.mesh.material_override.get_shader_parameter("view_coverage")),1.0),"Normal space restores other bodies")
	check(is_equal_approx(float(renderer.visuals.saturn.rings.material_override.get_shader_parameter("view_coverage")),1.0),"Normal space restores ring coverage")
	world.focus_id="moon";renderer.set_surface_transition(false,1.0)
	check(renderer.visuals.earth.mesh.mesh.radial_segments==64 and renderer.visuals.earth.mesh.mesh.rings==32,"Changing focus releases high-resolution mesh of previous focus")
	renderer.set_surface_transition(true,0.5)
	check(renderer.visuals.moon.mesh.mesh.radial_segments==256,"New focus alone can request high-resolution silhouette")
	world.focus_id="earth";renderer.set_surface_transition(false,1.0)
	check(renderer.visuals.moon.mesh.mesh.radial_segments==64,"Repeated focus changes do not accumulate high-resolution inactive spheres")
	ship.position=center+Vector3.UP*(radius+61000.0)
	check(not view.update(surface,ship,world,10) and not view.active and view.drawing==null,"Preview clears only beyond far endpoint")
	ship.position=center+Vector3.UP*(radius+40000.0)
	check(view.update(surface,ship,world,10) and view.space_blend>0 and view.space_blend<1,"Inward flight reconstructs partially blended preview")
	visual.configure(view.drawing)
	for coverage in [0.0,0.49,0.5,1.0,-1.0,2.0]:
		visual.set_view_coverage(coverage)
		check(visual.view_coverage>=0 and visual.view_coverage<=1,"Coverage API clamps inputs")
		for node in visual.get_children():
			if node.get_meta("terrain_layer",false):
				check(node.material_override.shader==(Visual.TerrainShader if visual.view_coverage>=1.0 else Visual.TransitionShader),"Coverage cycling restores correct opaque or blended shader")
			else:check(node.visible==(visual.view_coverage>=0.5),"Non-terrain district decorations follow transition visibility")
	ship.docked=true
	check(not view.update(surface,ship,world,10),"Docking still invalidates distant preview")
	ship.docked=false
	var old_focus:String=world.focus_id;world.focus_id="moon"
	check(not view.update(surface,ship,world,10),"Body change still invalidates geographic preview")
	world.focus_id=old_focus
	check(JSON.stringify(surface.snapshot())==source_before and JSON.stringify(world.snapshot())==world_before,"Preview lifecycle leaves saved geographic context unchanged")
	visual.queue_free();renderer.queue_free();await process_frame
	print("FAR SURFACE TRANSITION TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
