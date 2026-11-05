extends SceneTree
# Actual Main UI and motion; capture mode leaves user progress untouched.
const OUTPUT:="res://build/flight-console-screenshots"
var game:Node3D
var records:Array=[]
func _initialize()->void:call_deferred("capture")
func frame()->void:
	await process_frame
	await RenderingServer.frame_post_draw
func photograph(name:String)->bool:
	game.active=true;game._process(0.1);game._refresh_hud();game.notice_timer=0;game.notice.hide()
	game.player._process(0.3)
	for i in range(3):await frame()
	var path:=OUTPUT+"/"+name+".png"
	if root.get_texture().get_image().save_png(path)!=OK:push_error("Cannot save "+path);return false
	records.append({"file":name+".png","source":"actual scenes/main.tscn","console_height":game.flight_console.HEIGHT,"renderer":"OpenGL Compatibility/Mesa llvmpipe","phone_capture":false,"surface":game.surface.active,"landed":game.surface.landed,"taking_off":game.surface.taking_off,"hull":game.ship.hull,"altitude_m":game.surface.altitude(game.ship) if game.surface.active else 0.0,"docked":game.ship.docked,"menu_visible":game.menu.visible})
	return true
func capture()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless":push_error("Needs --rebuild-capture and actual rendering");quit(1);return
	DirAccess.make_dir_recursive_absolute(OUTPUT);root.size=Vector2i(1440,720)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	await frame();game.active=true;game.nav.elapsed_days=225.0;game.ship.external_view=true;game._apply_system()
	if not await photograph("01-classic-space-console"):quit(1);return
	game._toggle_auto()
	for step in range(4000):
		game._tick(0.05,Vector2.ZERO,0)
		if game.ship.docked:break
	if not game.ship.docked:push_error("Autodock failed");quit(1);return
	game._show_services()
	if not await photograph("02-dock-services"):quit(1);return
	game._close_menu();game.ship.launch();game.ship.velocity=Vector3.ZERO;game.ship.target_speed=0
	game.world.focus_id="earth";game.world.selected_id="earth";game.world.site_id="";game._apply_system()
	await game._enter_surface()
	if not game.surface.active:push_error("Earth surface entry failed");quit(1);return
	game.ship.position=Vector3(300,game.surface.height_at(300,200)+game.surface.clearance(game.ship)+0.5,200);game.ship.velocity=Vector3.ZERO
	if not game.surface.touch_down(game.ship):push_error("Off-pad touchdown failed");quit(1);return
	game.ship.external_view=true;game._apply_system()
	if not await photograph("03-offpad-landed-console"):quit(1);return
	game.dock_button.pressed.emit()
	for step in range(240):game._tick(0.05,Vector2.ZERO,0)
	if game.surface.landed or game.surface.altitude(game.ship)<34.5:push_error("Off-pad takeoff failed");quit(1);return
	if not await photograph("04-offpad-takeoff-console"):quit(1);return
	game._show_bug_report()
	if not await photograph("05-report-page"):quit(1);return
	var file:=FileAccess.open(OUTPUT+"/capture-manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"\t"));file.close()
	print("FLIGHT CONSOLE CAPTURES PASS: %d actual states including autonomous dock, off-pad landing/takeoff and report UI"%records.size())
	game.queue_free();await process_frame;quit()
