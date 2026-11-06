extends SceneTree
# Actual Main and actual console. No compositing, gameplay loading or saving.
const World=preload("res://scripts/planetary_system.gd")
const OUTPUT:="res://build/classic-console-screenshots"
var game:Node3D
var records:Array=[]
func _initialize()->void:call_deferred("run")
func frame()->void:await process_frame;await RenderingServer.frame_post_draw
func photograph(filename:String)->bool:
	game._process(0);game._refresh_hud();game.notice_timer=0;game.notice.hide();game.player._process(0)
	for index in range(4):await frame()
	if root.get_texture().get_image().save_png(OUTPUT+"/"+filename)!=OK:return false
	records.append({"file":filename,"actual_scene":"scenes/main.tscn","console_height":game.flight_console.HEIGHT,"view":game.instruments.view_key(game.ship.external_view),"simulation_paused":game.instruments.paused,"layout":game.world.layout_mode,"station_model":int(game.world.current_site().get("model_index",-1)),"menu_visible":game.menu.visible,"viewport":[root.size.x,root.size.y],"physical_phone_capture":false,"composited":false,"gameplay_progress_read":false,"gameplay_progress_written":false})
	return true
func finish(code:int)->void:
	game.queue_free();await frame();quit(code)
func run()->void:
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Needs actual rendered capture mode");quit(1);return
	root.size=Vector2i(1440,720);DirAccess.make_dir_recursive_absolute(OUTPUT)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	if not game.automated or game.saving_enabled:push_error("Unsafe capture state");await finish(1);return
	game._new_models(World.FULL_LAYOUT)
	var port:Dictionary={}
	for site:Dictionary in game.world.settlements:
		if int(site.model_index)==80:port=site;break
	if port.is_empty():push_error("Original source80 missing");await finish(1);return
	game.world.focus_id=str(port.parent);game.world.selected_id=str(port.parent);game.world.site_id=str(port.id);game._apply_system()
	var basis:Basis=game.world.source_station_basis(game.nav.elapsed_days)
	game.ship.position=game.ship.STATION+basis*Vector3(0,0,600);game.ship.attitude=basis.get_rotation_quaternion();game.ship.external_view=true
	game.ship.velocity=game.ship.forward()*35;game.ship.target_speed=35;game._apply_system()
	for index in range(2000):
		game._process(0)
		if game.celestial.source_mesh_state().get("status")=="ready":break
		await frame()
	if not await photograph("01-classic-console-external.png"):await finish(1);return
	game._cycle_view();game._cycle_view()
	if not await photograph("02-classic-console-rear.png"):await finish(1);return
	game._toggle_pause()
	if not await photograph("03-classic-console-pause.png"):await finish(1);return
	game._show_equipment()
	if not await photograph("04-real-cargo-and-equipment.png"):await finish(1);return
	game._close_menu();game._toggle_pause();game.ship.external_view=true;game.last_view=""
	root.size=Vector2i(2316,1080);await frame();game._safe_area()
	if not await photograph("05-classic-console-wide-landscape.png"):await finish(1);return
	var file:=FileAccess.open(OUTPUT+"/capture-manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"\t"));file.close()
	print("CLASSIC CONSOLE CAPTURES PASS: %d actual Main frames; desktop rendering, no phone-performance claim"%records.size());await finish(0)
