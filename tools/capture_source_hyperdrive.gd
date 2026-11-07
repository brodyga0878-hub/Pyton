extends SceneTree
# Actual Main framebuffer capture. Explicit fixture placement/loadout is
# recorded below; no compositing, normal player progress or device/FPS claim.
const World=preload("res://scripts/planetary_system.gd")
const Settings=preload("res://scripts/device_settings.gd")
const BuildInfo=preload("res://scripts/build_info.gd")
const ALPHA:=0x06a49718
const OUTPUT:="res://validation/hyperdrive-2026-11-07/screenshots"
class MemorySettings extends Settings:
	func load_file()->bool:quality=0;return false
var game:Node3D
var checks:=0
var failures:Array=[]
var captures:Array=[]
var sources:Dictionary={}
var fixture:=""
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func frame()->void:game._process(0.0);await process_frame;await RenderingServer.frame_post_draw
func copied(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func session()->Dictionary:return game.nav.snapshot().get("source_hyperdrive",{}).duplicate(true)
func tap(button:Button,pointer:=151)->void:
	var event:=InputEventScreenTouch.new();event.index=pointer;event.position=button.get_global_rect().get_center();event.pressed=true
	root.push_input(event,true);await frame();event.pressed=false;root.push_input(event,true);await frame()
func resize(width:int,height:int)->void:
	root.size=Vector2i(width,height);await frame();game._safe_area();await frame()
func fresh(source:=true)->void:
	game._close_menu();game._new_models(World.FULL_LAYOUT)
	if source:check(game._enable_source_hyperdrive(),"Actual fresh source hyperdrive hook succeeds")
	game._apply_system();game._safe_area();game._refresh_hud();fixture="fresh original Cobra38/class2/H4 source session" if source else "fresh legacy native-v2 adapter session for migration review"
func dock_fixture()->bool:
	var port:Dictionary={}
	for row:Dictionary in game.world.settlements:
		if int(row.type_code) in [32,33,34]:port=row;break
	if port.is_empty():check(false,"Actual system supplies an orbital dock for the fixture");return false
	game.world.focus_id=str(port.parent);game.world.selected_id=str(port.parent);game.world.site_id=str(port.id);game._apply_system()
	game.ship.position=game.ship.STATION;game.ship.velocity=Vector3.ZERO;game.ship.target_speed=0;game.ship.attitude=game.world.source_station_basis(game.nav.elapsed_days).get_rotation_quaternion().normalized()
	game._dock_action();check(game.ship.docked and game.ship.has_source_station(),"Actual Main docks the explicitly positioned fixture at a real source port")
	fixture+="; explicitly positioned in actual source bay "+str(port.id)+" then actual Main dock command (no manual-flight/trade claim)"
	return game.ship.docked
func launch()->void:
	game._close_menu();game._dock_action()
	for index in range(3):
		if not game.ship.docked:break
		game._tick(0.1,Vector2.ZERO,0)
	check(not game.ship.docked,"Actual Main launches through the source dock")
	game.ship.velocity=Vector3.ZERO;game.ship.target_speed=0;game.ship.assisted=false
func photograph(filename:String,screen:String)->void:
	for index in range(3):await frame()
	check(game.automated and not game.saving_enabled,"Capture never loads or writes ordinary player progress")
	var bounds:Rect2=root.get_visible_rect();var metadata:={"file":filename,"actual_scene":"scenes/main.tscn","screen":screen,"viewport":[root.size.x,root.size.y],"fixture_setup":fixture,"current_system_id":game.nav.current_id,"selected_system_id":game.nav.selected_id,"elapsed_days":game.nav.elapsed_days,"source_session":session(),"docked":game.ship.docked,"composited":false,"physical_phone_capture":false,"performance_benchmark":false,"player_progress_read_or_written":false}
	if screen in ["equipment","migration"]:
		check(game.menu.visible and bounds.encloses(game.menu.get_global_rect()),"Actual embedded menu fits the logical viewport")
		metadata["menu_rect"]=str(game.menu.get_global_rect());metadata["menu_title"]=game.menu_title.text
		if screen=="equipment":
			var view:Control=game.hyperdrive_services_view;check(is_instance_valid(view),"Actual source equipment view is embedded in Main")
			metadata["service_state"]=view._state.duplicate(true);metadata["labels"]={};metadata["button_rects"]=[]
			for key:String in view.labels:metadata.labels[key]=view.labels[key].text
			for button:Button in view.action_buttons:
				var rect:=button.get_global_rect();check(rect.position.x>=bounds.position.x and rect.end.x<=bounds.end.x+1,"Equipment action stays within the viewport horizontally: "+button.name)
				metadata.button_rects.append({"name":button.name,"text":button.text,"rect":str(rect),"disabled":button.disabled})
	elif screen=="galaxy":
		check(game.active_map_kind=="galaxy" and game.active_map.model.selected_id==ALPHA,"Actual native map displays the selected Alpha Centauri route")
		metadata["route_quote"]=game.active_map.model.jump_state();metadata["nav_quote"]=game.nav.quote_for(ALPHA,game.ship)
		check(int(metadata.route_quote.fuel_required)==int(metadata.nav_quote.required_fuel) and int(metadata.route_quote.duration_raw_u32)==int(metadata.nav_quote.duration_raw_u32),"Rendered route cost/time match actual source Navigation quote")
	else:check(not game.menu.visible and game.active_map==null,"Actual classic flight console is visible after closing the screen")
	check(root.get_texture().get_image().save_png(OUTPUT.path_join(filename))==OK,"Actual Main framebuffer PNG is saved")
	captures.append(metadata)
func finish()->void:
	for path:String in sources:check(FileAccess.get_sha256("res://"+path)==sources[path],"Capture leaves source input unchanged: "+path)
	var file:=FileAccess.open(OUTPUT.path_join("capture-manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"version":BuildInfo.VERSION,"completed_utc":Time.get_datetime_string_from_system(true),"source_sha256":sources,"checks":checks,"failures":failures,"frames":captures,"scope":"Actual desktop-rendered Main source hyperdrive equipment/routes/military fixture/waste and legacy migration review; no phone, manual-docking or market-supply proof."},"\t"));file.close()
	game.queue_free();await process_frame
	print("SOURCE HYPERDRIVE CAPTURE: %d frames, %d checks, %d failures"%[captures.size(),checks,failures.size()]);quit(0 if failures.is_empty() else 1)
func run()->void:
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Use a rendered display and private capture mode");quit(1);return
	for path:String in ["scripts/main.gd","scripts/navigation.gd","scripts/source_hyperdrive.gd","scripts/source_hyperdrive_session.gd","scripts/hyperdrive_services_view.gd","scripts/galactic_map_model.gd","scripts/galactic_map_view.gd","scripts/build_info.gd","data/ffe_hyperdrive.json","tools/capture_source_hyperdrive.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	root.size=Vector2i(1440,720);DirAccess.make_dir_recursive_absolute(OUTPUT);game=load("res://scenes/main.tscn").instantiate();game.settings=MemorySettings.new();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);await frame()
	fresh();dock_fixture();game._show_equipment();await photograph("01-source-equipment-sol.png","equipment")
	await resize(720,720);await photograph("02-source-equipment-narrow.png","equipment")
	await resize(1440,720);var candidate:Dictionary=copied(game._payload());candidate.navigation.source_hyperdrive.drive_index=11;candidate.navigation.source_hyperdrive.military=4;candidate.navigation.fuel=4
	var military:Dictionary=game._decode_state(candidate);check(not military.is_empty(),"Explicit military fixture validates through the whole-game source decoder")
	if military.is_empty():await finish();return
	game._commit_state(military);game._apply_system();fixture+="; explicit validated class2 military drive11/M4 equipment fixture, no purchase claim"
	game._show_equipment();await photograph("03-military-equipment-sol.png","equipment")
	await launch();game._show_routes();await frame();var map:Control=game.active_map;var started:=Time.get_ticks_msec()
	while map.loading() and Time.get_ticks_msec()-started<30000:await frame()
	check(not map.loading() and map.select_system(ALPHA),"Actual source map selects a reachable Alpha Centauri route")
	await photograph("04-alpha-source-route.png","galaxy");await tap(map.buttons.jump)
	check(game.nav.remaining>0 and game.nav.pending_id==ALPHA,"Actual rendered map button starts source charge")
	await photograph("05-source-charge-classic-console.png","flight")
	for index in range(31):game._tick(0.1,Vector2.ZERO,0)
	check(game.nav.current_id==ALPHA and int(session().radioactives)>0,"Actual source military jump reaches Alpha Centauri and creates waste")
	dock_fixture();game._show_equipment();await photograph("06-military-waste-after-arrival.png","equipment")
	fresh(false);dock_fixture();game._show_hyperdrive_migration();await photograph("07-legacy-migration-review.png","migration")
	game._close_menu();await photograph("08-return-classic-flight.png","flight")
	await finish()
