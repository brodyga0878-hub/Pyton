extends SceneTree
# Same actual Main scene/camera poses for each revision; no image compositing.
# --capture-output=/absolute/path and --capture-label=... support comparison.
var game:Node3D
var records:Array=[]
var output:="res://build/surface-detail-screenshots"
var revision:="current"
func _initialize()->void:call_deferred("capture")
func frame()->void:
	await process_frame
	await RenderingServer.frame_post_draw
func photograph(name:String,eye:Vector3,target:Vector3,fov:=58.0)->bool:
	game.active=true;game._process(0.0);game._sync_scene();game._refresh_hud()
	game.camera.position=eye;game.camera.look_at(game.to_global(target),Vector3.UP);game.camera.fov=fov
	game.ui.visible=false;game.notice_timer=0;game.notice.hide()
	for i in range(4):await frame()
	var path:=output+"/"+name+".png"
	if root.get_texture().get_image().save_png(path)!=OK:push_error("Cannot save "+path);return false
	records.append({"file":name+".png","revision":revision,"source":"actual scenes/main.tscn","renderer":"gl_compatibility","quality":game.settings.quality,"ship_profile":game.ship.profile().id,"ship_span_m":game.player._span,"elapsed_days":game.nav.elapsed_days,"graphics_demo":not game.graphics_return.is_empty(),"asteroid_count":game.space_environment.asteroid_count,"camera_position":[eye.x,eye.y,eye.z],"camera_target":[target.x,target.y,target.z],"camera_fov":fov,"phone_capture":false})
	return true
func capture()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless":push_error("Needs --rebuild-capture and real renderer");quit(1);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-output="):output=arg.trim_prefix("--capture-output=")
		elif arg.begins_with("--capture-label="):revision=arg.trim_prefix("--capture-label=")
	DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1920,1080)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false)
	await frame();game.settings.quality=2;game._apply_settings();game.ship.external_view=true
	# Same recorded simulated date in both revisions; game defaults stay intact.
	game.nav.elapsed_days=225.0
	game.ship.position=Vector3(0,45,-1550)
	var index:=0
	for id in ["cobra","eagle","shuttle"]:
		game.ship.ship_id=id;game._apply_system()
		var span:float=game.player._span
		if not await photograph("%02d-%s-hull"%[index+1,id],game.ship.position+Vector3(-0.45,0.40,0.55)*span,game.ship.position+Vector3(0,0,-0.07)*span):quit(1);return
		if not await photograph("%02d-%s-plating"%[index+2,id],game.ship.position+Vector3(0,0.82,0.23)*span,game.ship.position+Vector3(0,0,-0.04)*span,52):quit(1);return
		index+=2
	if not await photograph("07-station-overview",game.ship.STATION+Vector3(220,170,330),game.ship.STATION+Vector3(0,0,-110)):quit(1);return
	if not await photograph("08-station-closeup",game.ship.STATION+Vector3(225,70,-25),game.ship.STATION+Vector3(150,0,-150),52):quit(1);return
	var file:=FileAccess.open(output+"/capture-manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"\t"));file.close()
	print("SURFACE DETAIL GAME CAPTURES PASS: %d actual game poses, revision=%s, no save IO or added scenery"%[records.size(),revision])
	game.queue_free();await process_frame;quit()
