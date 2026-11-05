extends SceneTree
# Actual Main screenshots of the source-calendar bridge. No progress access.
const Clock=preload("res://scripts/source_clock.gd")
const OUTPUT:="res://build/source-clock-screenshots"
var game:Node3D
var records:Array=[]
func _initialize()->void:call_deferred("run")
func frame()->void:
	await process_frame
	await RenderingServer.frame_post_draw
func photograph(name:String,eye:Vector3,target:Vector3)->bool:
	game.active=true;game._process(0.0);game._sync_scene();game._refresh_hud()
	game.camera.position=eye;game.camera.look_at(game.to_global(target),Vector3.UP);game.camera.fov=58
	game.notice_timer=0;game.notice.hide()
	for i in range(4):await frame()
	if root.get_texture().get_image().save_png(OUTPUT+"/"+name+".png")!=OK:return false
	var clock:=Clock.from_elapsed_days(game.nav.elapsed_days)
	if game.flight_console.labels.clock.text!=clock.label_ru:return false
	records.append({"file":name+".png","scene":"actual scenes/main.tscn","source_clock":clock,"console_label":game.flight_console.labels.clock.text,"source_runtime":game.world.source_runtime_state,"layout":game.world.layout_mode,"elapsed_days":game.nav.elapsed_days,"quality":game.settings.quality,"phone_capture":false,"gameplay_progress_read":false,"gameplay_progress_written":false,"physical_orbit_backend":"unchanged analytic_si_rebuild_v1","fixture":"Fixed review camera and explicit elapsed-days snapshot; no image compositing."})
	return true
func run()->void:
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Source-clock captures require rendered --rebuild-capture");quit(1);return
	root.size=Vector2i(1920,1080);DirAccess.make_dir_recursive_absolute(OUTPUT)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	game.settings.quality=2;game._apply_settings();game.ship.external_view=true;game.nav.elapsed_days=0.0;game._apply_system()
	if not await photograph("01-original-3250-clock",game.ship.position+Vector3(-26,17,30),game.ship.position):game.queue_free();await process_frame;quit(1);return
	game.world.focus_id="earth";game.world.selected_id="earth";game.world.site_id="site10";game._apply_system();await game._enter_surface();game.surface.begin_landing(game.ship)
	for step in range(24000):
		game.surface.step(0.05,game.ship,Vector2.ZERO,0)
		if game.surface.landed:break
	if not game.surface.landed:push_error("Source city landing failed");game.queue_free();await process_frame;quit(1);return
	game.nav.elapsed_days=1.5;game.ship.external_view=true;var pad:Vector3=game.surface.pad_position()
	if not await photograph("02-calendar-and-original-city",pad+Vector3(60,45,70),pad+Vector3(0,8,0)):game.queue_free();await process_frame;quit(1);return
	var file:=FileAccess.open(OUTPUT+"/capture-manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"\t"));file.close()
	print("SOURCE CLOCK CAPTURES PASS: %d actual Main frames; native calendar bridge, no phone or full ephemeris claim"%records.size())
	game.queue_free();await process_frame;quit()
