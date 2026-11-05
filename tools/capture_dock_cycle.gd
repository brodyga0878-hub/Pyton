extends SceneTree
# Real controller and service transactions; user progress is disabled in capture mode.
const OUTPUT:="res://build/dock-cycle-screenshots"
var game:Node3D
var records:Array=[]
func _initialize()->void:call_deferred("capture")
func frame()->void:
	await process_frame
	await RenderingServer.frame_post_draw
func photograph(name:String)->bool:
	game.active=true;game._process(0.1);game._refresh_hud();game.notice_timer=0;game.notice.hide();game.player._process(0.3)
	for i in range(3):await frame()
	if root.get_texture().get_image().save_png(OUTPUT+"/"+name+".png")!=OK:push_error("Capture failed");return false
	records.append({"file":name+".png","source":"actual scenes/main.tscn","phone_capture":false,"surface":game.surface.active,"landed":game.surface.landed,"flight_phase":game.surface.flight_phase,"hull":game.ship.hull,"credits":game.ship.credits,"fuel":game.nav.fuel,"docked":game.ship.docked,"site_id":game.world.site_id,"menu_visible":game.menu.visible})
	return true
func capture()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless":push_error("Requires capture mode and real renderer");quit(1);return
	DirAccess.make_dir_recursive_absolute(OUTPUT);root.size=Vector2i(1440,720)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	await frame();game.active=true;game.nav.elapsed_days=225.0;game.ship.external_view=true
	game.world.focus_id="earth";game.world.selected_id="earth";game.world.site_id="site10";game._apply_system();await game._enter_surface()
	if not game.surface.active:push_error("Source city entry failed");quit(1);return
	game.ship.position=Vector3(300,game.surface.height_at(300,200)+game.surface.clearance(game.ship)+0.5,200);game.ship.velocity=Vector3.ZERO
	if not game.surface.touch_down(game.ship):push_error("Off-pad touchdown failed");quit(1);return
	game._apply_system()
	if not await photograph("01-ground-departure-command"):quit(1);return
	game.auto_button.pressed.emit()
	for i in range(200):game._tick(0.05,Vector2.ZERO,0)
	if game.surface.flight_phase!="ascent":push_error("Automatic departure failed");quit(1);return
	if not await photograph("02-automatic-ascent"):quit(1);return
	for i in range(12000):
		game._tick(0.05,Vector2.ZERO,0)
		if not game.surface.active:break
	if game.surface.active:push_error("Orbit handoff failed");quit(1);return
	# Explicit selection is required to approach the existing training dock.
	game._choose_body(game.world.default_id)
	for i in range(100):game._tick(0.05,Vector2.ZERO,0)
	game._toggle_auto()
	for i in range(4000):
		game._tick(0.05,Vector2.ZERO,0)
		if game.ship.docked:break
	if not game.ship.docked:push_error("Docking failed");quit(1);return
	# A valid damaged/fuel-deficient review fixture makes repair quotes visible.
	game.ship.hull=64.5;game.nav.fuel=7;game._refresh_hud();game.auto_button.pressed.emit()
	if not is_instance_valid(game.dock_services_view):push_error("Services shortcut failed");quit(1);return
	if not await photograph("03-dock-repair-and-refuel"):quit(1);return
	game.dock_services_view.buttons.repair.pressed.emit();game.dock_services_view.buttons.refuel.pressed.emit()
	if game.ship.hull!=100 or game.nav.fuel!=12 or game.ship.credits!=879:push_error("Service transactions failed");quit(1);return
	if not await photograph("04-serviced-ship"):quit(1);return
	var scroll:ScrollContainer=game.menu_rows.get_parent();scroll.ensure_control_visible(game.dock_services_view.buttons["buy:electronics"])
	if not await photograph("05-commodity-market"):quit(1);return
	scroll.ensure_control_visible(game.dock_services_view.buttons["trade_ship:shuttle"])
	if not await photograph("06-ship-exchange-quotes"):quit(1);return
	var file:=FileAccess.open(OUTPUT+"/capture-manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"service_review_fixture_hull":64.5,"service_review_fixture_fuel":7,"renderer":"Mesa llvmpipe/OpenGL Compatibility","user_progress_io":false,"frames":records},"\t"));file.close()
	print("DOCK CYCLE CAPTURES PASS: %d real frames, ground departure/orbit/explicit transfer/autodock/services"%records.size())
	game.queue_free();await process_frame;quit()
