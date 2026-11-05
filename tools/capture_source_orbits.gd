extends SceneTree
# Actual Main frames; capture mode disables loading/writing user progress.
const Clock=preload("res://scripts/source_clock.gd")
const World=preload("res://scripts/planetary_system.gd")
const OUTPUT:="res://build/source-orbit-screenshots"
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
	records.append({"file":name+".png","scene":"actual scenes/main.tscn","source_clock":clock,"console_label":game.flight_console.labels.clock.text,"source_runtime":game.world.source_runtime_state.duplicate(true),"source_orbit":game.world.orbit_backend_state.duplicate(true),"earth_position_au":game.world.position_au("earth",game.nav.elapsed_days),"moon_position_au":game.world.position_au("moon",game.nav.elapsed_days),"layout":game.world.layout_mode,"elapsed_days":game.nav.elapsed_days,"quality":game.settings.quality,"phone_capture":false,"gameplay_progress_read":false,"gameplay_progress_written":false,"fixture":"Fixed review camera. Existing51material maps; no new graphics or compositing. SI radius/mass/gravity/spin remain adapters."})
	return true
func finish(code:int)->void:
	game.queue_free();await process_frame;quit(code)
func run()->void:
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Source-orbit captures require rendered --rebuild-capture");quit(1);return
	root.size=Vector2i(1920,1080);DirAccess.make_dir_recursive_absolute(OUTPUT)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	if game.world.layout_mode!=World.NATIVE_LAYOUT:push_error("Actual new game did not select v2 orbits");await finish(1);return
	game.settings.quality=2;game._apply_settings();game.ship.external_view=true;game.nav.elapsed_days=0.0;game._apply_system()
	if not await photograph("01-jjffe-orbits-3250",game.ship.position+Vector3(-26,17,30),game.ship.position):await finish(1);return
	game.nav.elapsed_days=30.0
	if not await photograph("02-jjffe-orbits-day30",game.ship.position+Vector3(-26,17,30),game.ship.position):await finish(1);return
	game.world.focus_id="earth";game.world.selected_id="earth";game.world.site_id="site10";game._apply_system();await game._enter_surface();game.surface.begin_landing(game.ship)
	for step in range(24000):
		game.surface.step(0.05,game.ship,Vector2.ZERO,0)
		if game.surface.landed:break
	if not game.surface.landed:push_error("Native-layout source city landing failed");await finish(1);return
	game.ship.external_view=true;var pad:Vector3=game.surface.pad_position()
	if not await photograph("03-v2-original-city",pad+Vector3(60,45,70),pad+Vector3(0,8,0)):await finish(1);return
	game._new_models();game.world.configure(game.nav.current(),World.SOURCE_LAYOUT)
	var previous:Dictionary=JSON.parse_string(JSON.stringify(game._payload()))
	var restored:Dictionary=game._decode_state(previous)
	if restored.is_empty():push_error("Legacy v1 complete save rejected");await finish(1);return
	game._commit_state(restored);game._apply_system();game.ship.external_view=true
	if game.world.layout_mode!=World.SOURCE_LAYOUT or not await photograph("04-restored-v1-layout",game.ship.position+Vector3(-26,17,30),game.ship.position):await finish(1);return
	var file:=FileAccess.open(OUTPUT+"/capture-manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"\t"));file.close()
	print("SOURCE ORBIT CAPTURES PASS: %d actual Main frames; nativev2 and restoredv1, no phone/full physics claim"%records.size())
	await finish(0)
