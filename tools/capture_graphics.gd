extends SceneTree
# Actual game scene renders. Camera poses and simulated date are recorded;
# no generated artwork, compositing or edits to saved user progress.
var game:Node3D
var records:Array=[]
const OUTPUT:="res://build/graphics-screenshots"
func _initialize()->void:call_deferred("capture")
func frame()->void:
	await process_frame
	await RenderingServer.frame_post_draw
func photograph(name:String,offset:Vector3,look_offset:Vector3,show_ui:bool,fov:float=74)->bool:
	game.ship.external_view=true;game.ship.velocity=Vector3(0,0,-180);game.ship.target_speed=180
	game.player.set_thrust(0.7);game.player._process(0.2)
	game.active=true;game._process(0.1);game._sync_scene()
	game.camera.fov=fov
	game.camera.position=game.ship.position+Basis(game.ship.attitude)*offset
	game.camera.look_at(game.to_global(game.ship.position+Basis(game.ship.attitude)*look_offset),Vector3.UP)
	game._sync_scene();game._refresh_hud();game.ui.visible=show_ui;game.notice_timer=0;game.notice.hide()
	if not game.player.visible or not game.camera.is_position_in_frustum(game.player.global_position):
		push_error("Ship missing from actual capture frustum: "+name);return false
	for i in range(4):await frame()
	var path:=OUTPUT+"/"+name+".png"
	if root.get_texture().get_image().save_png(path)!=OK:push_error("Capture write failed: "+path);return false
	records.append({"file":name+".png","renderer":"gl_compatibility","source":"actual scenes/main.tscn","hud":show_ui,"elapsed_days":game.nav.elapsed_days,"ship_position":[game.ship.position.x,game.ship.position.y,game.ship.position.z],"camera_offset":[offset.x,offset.y,offset.z]})
	return true
func capture()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Needs --rebuild-capture");quit(1);return
	if DisplayServer.get_name()=="headless":push_error("Screenshot requires actual GPU rendering");quit(1);return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for name in ["01-cobra-orbit","02-flight-hud","03-station-approach","04-cobra-detail"]:
		if FileAccess.file_exists(OUTPUT+"/"+name+".png"):DirAccess.remove_absolute(OUTPUT+"/"+name+".png")
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false)
	await frame()
	game._begin_graphics_demo();game.ship.position=Vector3.ZERO;game._apply_system()
	if not await photograph("01-cobra-orbit",Vector3(-15,18,35),Vector3(0,0,-3),false,60):quit(1);return
	game.ship.position=Vector3(0,25,-1100);game._apply_system()
	if not await photograph("02-flight-hud",Vector3(0,14.28,69.3),Vector3(0,4,-30),true):quit(1);return
	game.ship.position=Vector3(0,45,-1550);game._apply_system()
	if not await photograph("03-station-approach",Vector3(35,24,35),Vector3(-4,0,-8),false,64):quit(1);return
	if not await photograph("04-cobra-detail",Vector3(-19,17,23),Vector3(0,0,-3),false,54):quit(1);return
	var file:=FileAccess.open(OUTPUT+"/capture-manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"\t"));file.close()
	print("GRAPHICS GAME CAPTURES PASS: %d actual rendered game poses, no user save access"%records.size())
	game.queue_free();await process_frame;quit()
