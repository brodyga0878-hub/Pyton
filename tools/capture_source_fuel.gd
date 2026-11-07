extends "res://tests/test_source_fuel_main.gd"
# Genuine rendered Main frames using the same private fixture helpers as the
# integration suite. The inherited test run is replaced, not executed here.
const BuildInfo=preload("res://scripts/build_info.gd")
const OUTPUT:="res://validation/jet-fuel-2026-11-07/screenshots"
var captures:Array=[]
var capture_errors:Array=[]
var input_hashes:Dictionary={}
var fixture_label:=""
func check(ok:bool,message:String)->void:
	super.check(ok,message)
	if not ok:capture_errors.append(message)
func frame()->void:
	game._process(0.0);await process_frame;await RenderingServer.frame_post_draw
func resize(width:int,height:int)->void:
	root.size=Vector2i(width,height);await frame();game._safe_area();await frame()
func reveal_tank()->void:
	var view:Control=game.hyperdrive_services_view;var scroll:ScrollContainer=game.menu_rows.get_parent()
	scroll.ensure_control_visible(view.labels.jetfuel);await frame();scroll.ensure_control_visible(view.buttons.manual_jet_refuel);await frame()
func reveal_scoop()->void:
	var view:Control=game.hyperdrive_services_view;var scroll:ScrollContainer=game.menu_rows.get_parent()
	scroll.ensure_control_visible(view.labels.scoop);await frame();scroll.ensure_control_visible(view.labels.scoop_status);await frame()
func stage_sun_contact()->Dictionary:
	# Fitting leaves the presentation anchored to its orbital bay. Relocate this
	# explicitly labelled capture fixture into the Sun's real local frame before
	# sampling contact, then let Main refresh its genuine renderer while unblocked.
	game.world.focus_id="star";game.world.selected_id="star";game.world.site_id=""
	game.ship.last_notice=""
	var contact:=place_contact("star")
	var direction:Vector3=game.world.local_meters("star",game.nav.elapsed_days)-game.ship.position
	game.ship.attitude=Basis.looking_at(direction.normalized(),Vector3.UP).get_rotation_quaternion().normalized()
	game._apply_system();game._process(0.2)
	for index in range(4):await frame()
	check(game.world.focus_id=="star" and game.world.site_id.is_empty() and not game.source_station.visible and not game.station.visible,"Solar fixture publishes the current Sun frame without its former station")
	return contact
func photograph(filename:String,screen:="equipment")->void:
	for index in range(3):await frame()
	check(game.automated and not game.saving_enabled,"Capture neither loads nor writes normal player progress")
	var bounds:Rect2=root.get_visible_rect();var metadata:={"file":filename,"screen":screen,"actual_scene":"scenes/main.tscn","viewport":[root.size.x,root.size.y],"fixture_setup":fixture_label,"current_system_id":game.nav.current_id,"elapsed_days":game.nav.elapsed_days,"source_hyperdrive":inventory(),"source_fuel":game.nav.fuel_state(game.ship),"docked":game.ship.docked,"renderer":{"focus_id":game.world.focus_id,"site_id":game.world.site_id,"source_station_visible":game.source_station.visible,"adapter_station_visible":game.station.visible,"camera_position":str(game.camera.position),"camera_attitude":str(game.camera.quaternion),"notice":game.menu_feedback.text},"composited":false,"physical_phone_capture":false,"performance_benchmark":false,"player_progress_read_or_written":false}
	if screen=="equipment":
		check(game.menu.visible and is_instance_valid(game.hyperdrive_services_view),"Actual Main equipment screen is visible")
		check(bounds.encloses(game.menu.get_global_rect()),"Actual Main equipment menu fits the viewport")
		var view:Control=game.hyperdrive_services_view;metadata["labels"]={};metadata["buttons"]=[];metadata["menu_rect"]=str(game.menu.get_global_rect())
		for key:String in view.labels:metadata.labels[key]=view.labels[key].text
		for button:Button in view.action_buttons:
			var rect:=button.get_global_rect();check(rect.position.x>=bounds.position.x and rect.end.x<=bounds.end.x+1,"Actual fuel action fits horizontally: "+button.name)
			metadata.buttons.append({"name":button.name,"text":button.text,"disabled":button.disabled,"rect":str(rect)})
	else:check(not game.menu.visible and game.active_map==null,"Actual classic flight console is visible")
	check(root.get_texture().get_image().save_png(OUTPUT.path_join(filename))==OK,"Actual Main framebuffer saved as PNG")
	captures.append(metadata)
func finish()->void:
	for path:String in input_hashes:check(FileAccess.get_sha256("res://"+path)==input_hashes[path],"Capture leaves source input unchanged: "+path)
	var file:=FileAccess.open(OUTPUT.path_join("capture-manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"version":BuildInfo.VERSION,"completed_utc":Time.get_datetime_string_from_system(true),"source_sha256":input_hashes,"checks":checks,"failures":capture_errors,"frames":captures,"scope":"Actual desktop Main source reaction-tank/manual-refuel/refueller/Sun-contact/legacy-upgrade frames. Bay placement and atmosphere approach are explicit fixtures; no manual approach, original-market supply, physical Android or FPS proof."},"\t"));file.close()
	game.queue_free();await process_frame
	print("SOURCE FUEL CAPTURE: %d frames, %d checks, %d failures"%[captures.size(),checks,failures]);quit(1 if failures else 0)
func run()->void:
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires rendered display and private capture mode");quit(1);return
	for path:String in ["scripts/main.gd","scripts/flight_model.gd","scripts/navigation.gd","scripts/source_hyperdrive_session.gd","scripts/source_motion_bridge.gd","scripts/source_fuel_flight_bridge.gd","scripts/source_jet_fuel.gd","scripts/source_fuel_scoop.gd","scripts/source_fuel_contact.gd","scripts/hyperdrive_services_view.gd","scripts/build_info.gd","data/ffe_fuel.json","tests/test_source_hyperdrive_main.gd","tests/test_source_fuel_main.gd","tools/capture_source_fuel.gd"]:input_hashes[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(OUTPUT);root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate();game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	fresh();dock_fixture();game._show_equipment();await frame();await reveal_tank();fixture_label="Fresh source Cobra38, default reaction tank and no scoop/refueller; explicit placement in an actual source bay followed by Main docking."
	await photograph("01-default-source-reaction-tank.png")
	await resize(720,720);await reveal_tank();await photograph("02-reaction-tank-narrow.png")
	await resize(1440,720);game._close_menu();fresh();await fit_hardware();game._show_equipment();await frame();var scroll:ScrollContainer=game.menu_rows.get_parent();scroll.ensure_control_visible(game.hyperdrive_services_view.labels.refueller);await frame()
	fixture_label="Actual source-bay fitting touches installed scoop and automatic refueller, then actual source-hatch launch; prices remain the explicit workshop adapter."
	await photograph("03-fitted-refueller-in-flight.png")
	game._close_menu();fresh();set_fuel_fixture({"jet_raw_u32":1,"jet_update_remainder_raw":49709});game.ship.assisted=false;game.ship.target_speed=game.ship.MAX_SPEED;game.ship.velocity=Vector3(30,0,0);game._tick(0.01,Vector2.ZERO,0)
	game._show_equipment();await frame();await reveal_tank();fixture_label="Explicit one-raw-unit reaction-tank boundary with49709 accumulated master ticks; actual powered Main step exhausted it and applied original DOS0x15 directional mask."
	await photograph("04-empty-tank-manual-refuel.png")
	await tap(game.hyperdrive_services_view.buttons.manual_jet_refuel);await reveal_tank();fixture_label+=" Actual manual-refuel touch transferred one cargo tonne and restored all six source limits."
	await photograph("05-manual-refill-restored-limits.png")
	game._close_menu();fresh();await fit_hardware();var contact:Dictionary=await stage_sun_contact();check(contact.ok and contact.contact.flags_u8==3,"Actual source Sun atmosphere fixture remains outside its solid core")
	game._tick(0.01,Vector2.ZERO,0);check(fuel().last_scoop_reason=="scooped","Actual Main source Sun collection succeeds")
	game._apply_system();game._process(0.2);for index in range(4):await frame()
	check(game.menu_feedback.text.begins_with("Топливозаборник собрал водород"),"Solar capture retains the actual collection notice instead of a stale launch notice")
	game._show_equipment();await frame();await reveal_scoop();fixture_label="Explicit placement at source Sun centre +0.95 native outer bound and tangent900m/s in the Sun focus frame; Main refreshed the current renderer before the equipment modal. Actual source terrain query flags3 and Main scoop added hydrogen to cargo, not the reaction tank."
	await photograph("06-source-sun-hydrogen-collection.png")
	game._close_menu();fresh();var old:Dictionary=copied(payload());old.navigation.source_hyperdrive.erase("fuel_system");check(load_fixture(old,"Old0.15.0 source save without reaction-fuel extension"),"Actual Main upgrades the prior source save")
	game._show_equipment();await resize(720,720);await reveal_tank();fixture_label="Actual whole-game decoder loaded the prior twelve-field source-session shape; the explicit source-profile reaction-fuel extension preserves existing cargo and hyperfuel."
	await photograph("07-legacy-source-fuel-upgrade-narrow.png")
	game._close_menu();await resize(1440,720);fixture_label="Closed the actual equipment screen and returned to the preserved classic flight console."
	await photograph("08-return-classic-flight.png","flight")
	await finish()
