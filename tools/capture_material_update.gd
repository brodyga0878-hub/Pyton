extends SceneTree
# Real game scene, ordinary-flight objects only; no demo or generated artwork.
# Fixed camera poses aid review of materials. Does not access user progress.
const OUTPUT:="res://build/material-screenshots"
var game:Node3D
var records:Array=[]
func _initialize()->void:call_deferred("capture")
func frame()->void:
	await process_frame
	await RenderingServer.frame_post_draw
func photograph(name:String,eye:Vector3,target:Vector3,show_ui:=false,terrain_coverage:=1.0)->bool:
	game.active=true;game._process(0.0);game._sync_scene();game._refresh_hud()
	if game.surface.active:game.ground_view.set_view_coverage(terrain_coverage)
	game.camera.position=eye;game.camera.look_at(game.to_global(target),Vector3.UP)
	game.camera.fov=58;game.ui.visible=show_ui;game.notice_timer=0;game.notice.hide()
	for i in range(4):await frame()
	var path:=OUTPUT+"/"+name+".png"
	if root.get_texture().get_image().save_png(path)!=OK:push_error("Cannot save "+path);return false
	records.append({"file":name+".png","source":"actual scenes/main.tscn","renderer":"gl_compatibility","quality":game.settings.quality,"graphics_demo":not game.graphics_return.is_empty(),"decorative_asteroids_visible":game.space_environment.visible,"camera_position":[eye.x,eye.y,eye.z],"camera_target":[target.x,target.y,target.z],"hud":show_ui,"terrain_coverage":terrain_coverage,"phone_capture":false})
	return true
func capture()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless":
		push_error("Needs --rebuild-capture and real rendering");quit(1);return
	DirAccess.make_dir_recursive_absolute(OUTPUT);root.size=Vector2i(1920,1080)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false)
	await frame()
	game.settings.quality=2;game._apply_settings();game.ship.external_view=true
	game.ship.position=Vector3(0,45,-1550);game._apply_system()
	if not await photograph("01-ship-materials",game.ship.position+Vector3(-19,17,23),game.ship.position+Vector3(0,0,-3)):quit(1);return
	if not await photograph("02-station-materials",game.ship.STATION+Vector3(220,170,330),game.ship.STATION+Vector3(0,0,-110)):quit(1);return
	game.world.focus_id="earth";game.world.selected_id="earth";game.world.site_id="site10";game._apply_system()
	await game._enter_surface()
	game.surface.begin_landing(game.ship)
	for step in range(24000):
		game.surface.step(0.05,game.ship,Vector2.ZERO,0)
		if game.surface.landed:break
	if not game.surface.landed:push_error("Actual source city landing failed");quit(1);return
	game.ship.external_view=true;game._sync_scene()
	var pad:Vector3=game.surface.pad_position()
	if not await photograph("03-city-materials",pad+Vector3(150,110,175),pad+Vector3(0,8,0)):quit(1);return
	if not await photograph("04-pad-and-ship",pad+Vector3(-27,23,35),game.ship.position+Vector3(0,0,-3)):quit(1);return
	# Frame an existing lit roof at its real placement; do not add a showcase mesh.
	var city:Node3D=game.city_view.current_visual()
	if city!=null and city.has_node("SourceLit"):
		var faces:MeshInstance3D=city.get_node("SourceLit")
		var arrays:Array=faces.mesh.surface_get_arrays(0)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var best:=INF;var roof:=Vector3.ZERO
		for index in range(0,vertices.size(),3):
			var a:Vector3=game.to_local(faces.to_global(vertices[index]))
			var b:Vector3=game.to_local(faces.to_global(vertices[index+1]))
			var c:Vector3=game.to_local(faces.to_global(vertices[index+2]))
			var cross:Vector3=(b-a).cross(c-a);var centre:Vector3=(a+b+c)/3.0
			if absf(cross.normalized().y)<0.85 or cross.length()<200 or centre.y<pad.y+15:continue
			var score:float=centre.distance_squared_to(pad)
			if score<best:best=score;roof=centre
		if is_finite(best):
			if not await photograph("05-source-city-roof",roof+Vector3(65,55,90),roof):quit(1);return
	var ground:Vector3=pad+Vector3(550,0,550)
	ground.y=game.surface.height_at(ground.x,ground.z)
	if not await photograph("06-ground-materials",ground+Vector3(0,12,16),ground):quit(1);return
	if not await photograph("07-ground-transition",ground+Vector3(0,12,16),ground,false,0.8):quit(1);return
	var file:=FileAccess.open(OUTPUT+"/capture-manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"\t"));file.close()
	print("MATERIAL UPDATE CAPTURES PASS: %d actual ordinary-flight/city frames, no demo scenery"%records.size())
	game.queue_free();await process_frame;quit()
