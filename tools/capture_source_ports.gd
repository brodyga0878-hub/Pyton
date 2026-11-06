extends SceneTree
# Actual Main rendered frames. Capture mode disables player progress access.
const World=preload("res://scripts/planetary_system.gd")
const OUTPUT:="res://build/source-port-screenshots"
var game:Node3D
var frames:Array=[]
func _initialize()->void:call_deferred("run")
func frame()->void:
	await process_frame
	await RenderingServer.frame_post_draw
func photograph(name:String)->bool:
	game.active=true;game._process(0.0);game._sync_scene();game._refresh_hud()
	var center:Vector3=game.world.local_meters(game.world.focus_id,game.nav.elapsed_days)
	var visual_center:Vector3=game.ship.STATION+Vector3(0,0,-250)
	var toward:Vector3=(center-visual_center).normalized()
	var side:Vector3=toward.cross(Vector3.UP).normalized()
	if side.length_squared()<0.5:side=Vector3.RIGHT
	game.camera.position=visual_center-toward*1250.0+side*300.0+Vector3.UP*220.0
	game.camera.look_at(game.to_global(visual_center),Vector3.UP);game.camera.fov=58.0
	game.celestial.update_view(game.nav.elapsed_days,game.camera.position)
	game.notice_timer=0;game.notice.hide()
	for i in range(4):await frame()
	if root.get_texture().get_image().save_png(OUTPUT+"/"+name+".png")!=OK:return false
	frames.append({"file":name+".png","scene":"actual scenes/main.tscn","layout":game.world.layout_mode,"site_id":game.world.site_id,"site_name":game.world.current_site().get("name",""),"elapsed_days":game.nav.elapsed_days,"source_site_position_au":game.world.site_position_au(game.world.site_id,game.nav.elapsed_days),"local_station":[game.station.position.x,game.station.position.y,game.station.position.z],"local_parent":[center.x,center.y,center.z],"ship_docked":game.ship.docked,"source_ports":game.world.port_backend_state.duplicate(true),"source_physics":game.world.source_physics_state.duplicate(true),"quality":game.settings.quality,"fixture":"Fixed review camera looking toward the real parent from an adapted station. Original port centre, existing51maps, generic station geometry/orientation. No compositing.","phone_capture":false,"gameplay_progress_read":false,"gameplay_progress_written":false})
	return true
func finish(code:int)->void:
	game.queue_free();await process_frame;quit(code)
func transfer(id:String)->bool:
	game.ship.docked=false;game.ship.position=Vector3.ZERO;game.ship.velocity=Vector3.ZERO;game.ship.target_speed=0.0
	game._choose_site(id)
	if game.world.pending_site_id!=id:return false
	game._tick(3.01,Vector2.ZERO,0.0)
	return game.world.site_id==id and game.world.layout_mode==World.PORT_LAYOUT
func run()->void:
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Source-port captures require rendered --rebuild-capture");quit(1);return
	root.size=Vector2i(1920,1080);DirAccess.make_dir_recursive_absolute(OUTPUT)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	if not game.automated or game.saving_enabled or game.world.layout_mode!=World.PORT_LAYOUT:push_error("Unsafe or wrong capture startup");await finish(1);return
	game.settings.quality=2;game._apply_settings();game.ship.external_view=true
	if not transfer("site13") or not await photograph("01-abraham-lincoln-earth"):push_error("Original Earth port capture failed");await finish(1);return
	if not transfer("site40") or not await photograph("02-titan-city-original-orbit"):push_error("Original Titan port capture failed");await finish(1);return
	game._toggle_auto()
	for i in range(10000):
		game._tick(0.05,Vector2.ZERO,0.0)
		if game.ship.docked:break
	if not game.ship.docked or not await photograph("03-native-centre-auto-dock"):push_error("Source-port auto dock failed");await finish(1);return
	var saved:Dictionary=JSON.parse_string(JSON.stringify(game._payload()))
	var loaded:Dictionary=game._decode_state(saved)
	if loaded.is_empty():push_error("Docked v3 full save rejected");await finish(1);return
	game._commit_state(loaded);game._apply_system()
	game._dock_action()
	if game.ship.docked or not await photograph("04-restored-native-port-launch"):push_error("Restored port launch failed");await finish(1);return
	var out:=FileAccess.open(OUTPUT+"/capture-manifest.json",FileAccess.WRITE);out.store_string(JSON.stringify(frames,"\t"));out.close()
	print("SOURCE PORT CAPTURES PASS: %d actual Main frames; native centres, adapted station, auto dock/save/launch; no phone/fullphysics claim"%frames.size())
	await finish(0)
