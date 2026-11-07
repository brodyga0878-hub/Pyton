extends "res://tests/test_source_thermal_main.gd"
# Actual Main rendered frames. Explicit observer/old-save fixtures use the
# production source geometry, renderer, equipment touch and thermal pipeline.
const BuildInfo=preload("res://scripts/build_info.gd")
const OUTPUT:="res://validation/thermal-2026-11-07/screenshots"
var captures:Array=[]
var capture_errors:Array=[]
var input_hashes:Dictionary={}
var fixture_label:=""
func check(ok:bool,message:String)->void:
	super.check(ok,message)
	if not ok:capture_errors.append(message)
func frame()->void:
	game._process(0.0);await process_frame;await RenderingServer.frame_post_draw
func fresh(source:=true)->void:
	super.fresh(source)
	# Independent screenshot cases must not retain the previous case's live
	# announcement. New flight steps still publish their actual thermal warning.
	game._announce("")
func resize(width:int,height:int)->void:
	root.size=Vector2i(width,height);await frame();game._safe_area();await frame()
func settle_scene()->void:
	game.ship.last_notice="";game._apply_system();game._process(0.2);game._refresh_hud()
	for index in range(4):await frame()
func reveal_thermal()->void:
	var view:Control=game.hyperdrive_services_view;var scroll:ScrollContainer=game.menu_rows.get_parent()
	check(view.labels.has("thermal_heat") and view.labels.has("thermal_hull") and view.labels.has("thermal_shielding"),"Actual equipment view exposes the dedicated heat, hull and atmospheric-protection labels")
	if not view.labels.has("thermal_heat"):return
	scroll.ensure_control_visible(view.labels.thermal_heat);await frame()
	var card:Control=view.labels.thermal_heat.get_parent();var whole_card_fits:bool=card.size.y<=scroll.size.y-8.0
	var target:String="thermal_source_heat" if whole_card_fits else ("thermal_guidance" if view.labels.has("thermal_guidance") else "thermal_damage")
	if view.labels.has(target):scroll.ensure_control_visible(view.labels[target]);await frame()
	var keys:Array=["thermal_heat","thermal_status","thermal_hull","thermal_shielding","thermal_damage","thermal_guidance"]
	if whole_card_fits:keys.append_array(["thermal_shield","thermal_atmosphere","thermal_drag","thermal_upgrade","thermal_source_heat"])
	for key:String in keys:
		if view.labels.has(key):check(scroll.get_global_rect().encloses(view.labels[key].get_global_rect()),"Thermal status/advice remains visible in the actual scroll viewport: "+key)
func photograph(filename:String,screen:="equipment")->void:
	for index in range(3):await frame()
	check(game.automated and not game.saving_enabled,"Thermal capture never loads or writes ordinary player progress")
	var bounds:Rect2=root.get_visible_rect()
	var metadata:={"file":filename,"screen":screen,"actual_scene":"scenes/main.tscn","viewport":[root.size.x,root.size.y],"fixture_setup":fixture_label,"current_system_id":game.nav.current_id,"elapsed_days":game.nav.elapsed_days,"source_fuel":fuel(),"source_thermal":thermal(),"phone_hull_percent":game.ship.hull,"ship_velocity_mps":str(game.ship.velocity),"source_motion_active":game.source_motion.is_active(),"surface_active":game.surface.active,"renderer":{"focus_id":game.world.focus_id,"site_id":game.world.site_id,"source_station_visible":game.source_station.visible,"adapter_station_visible":game.station.visible,"camera_position":str(game.camera.position),"camera_attitude":str(game.camera.quaternion),"notice":game.menu_feedback.text},"composited":false,"physical_phone_capture":false,"performance_benchmark":false,"player_progress_read_or_written":false}
	if screen=="equipment":
		check(game.menu.visible and is_instance_valid(game.hyperdrive_services_view),"Actual Main equipment modal is visible")
		check(bounds.encloses(game.menu.get_global_rect()),"Actual thermal equipment modal fits the viewport")
		var view:Control=game.hyperdrive_services_view;metadata["labels"]={};metadata["buttons"]=[]
		for key:String in view.labels:metadata.labels[key]=view.labels[key].text
		for button:Button in view.action_buttons:
			var rect:=button.get_global_rect();check(rect.position.x>=bounds.position.x and rect.end.x<=bounds.end.x+1,"Thermal equipment touch action fits horizontally: "+button.name)
			metadata.buttons.append({"name":button.name,"text":button.text,"disabled":button.disabled,"rect":str(rect)})
	else:check(not game.menu.visible and game.active_map==null,"Actual classic flight console remains visible")
	check(root.get_texture().get_image().save_png(OUTPUT.path_join(filename))==OK,"Actual thermal framebuffer saved as PNG")
	captures.append(metadata)
func finish()->void:
	for path:String in input_hashes:check(FileAccess.get_sha256("res://"+path)==input_hashes[path],"Capture leaves source input unchanged: "+path)
	check(captures.size()==8,"Eight actual Main thermal frames were captured")
	var file:=FileAccess.open(OUTPUT.path_join("capture-manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"version":BuildInfo.VERSION,"completed_utc":Time.get_datetime_string_from_system(true),"source_sha256":input_hashes,"checks":checks,"failures":capture_errors,"frames":captures,"scope":"Actual desktop Main thermal/HP/shielding/natural-contact/old-save interface. Source-ground observer placement, workshop bay placement and old-save shape are explicit fixtures. Original DOS kernels run under the named fixed60Hz phone adapter; no physical Android, FPS benchmark, manual atmospheric approach or complete damage/event VM proof."},"\t"));file.close()
	game.queue_free();await process_frame
	print("SOURCE THERMAL CAPTURE: %d frames, %d checks, %d failures"%[captures.size(),checks,failures]);quit(1 if failures else 0)
func run()->void:
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires rendered display and private capture mode");quit(1);return
	for path:String in ["scripts/main.gd","scripts/flight_model.gd","scripts/navigation.gd","scripts/source_hyperdrive_session.gd","scripts/source_motion_bridge.gd","scripts/source_atmospheric_dynamics.gd","scripts/source_atmosphere_contact.gd","scripts/hyperdrive_services_view.gd","scripts/build_info.gd","data/ffe_fuel.json","data/ffe_atmosphere.json","tests/test_source_hyperdrive_main.gd","tests/test_source_fuel_main.gd","tests/test_source_thermal_main.gd","tools/capture_source_thermal.gd"]:input_hashes[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(OUTPUT);root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main script failed to load");game.free();quit(1);return
	game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	fresh();game.settings.orbital_gravity=false;stage_natural();ticks(18,1.0/60.0);await settle_scene()
	check(game.ship.hull<100 and int(fuel().heat_s32)>0,"Actual unshielded source Earth flight produced visible damage and heat")
	fixture_label="Explicit source Earth sampled ground +5000m, tangent900m/s, gravity disabled to isolate atmosphere; eighteen actual Main flight steps under the named fixed60Hz caller adapter. No manual approach claim."
	await photograph("01-source-earth-unshielded-flight.png","flight")
	game._show_equipment();await frame();await reveal_thermal();await photograph("02-unshielded-thermal-and-hull.png")
	await resize(720,720);await reveal_thermal();await photograph("03-unshielded-thermal-narrow.png")
	await resize(1440,720);game._close_menu();fresh();game.settings.orbital_gravity=false;await install_atmospheric_shielding();game._announce("");stage_natural();ticks(18,1.0/60.0);await settle_scene()
	fixture_label="Atmospheric shielding fitted by an actual equipment touch in an original source bay, then source Earth observer +5000m at900m/s for the same eighteen Main steps. Workshop supply/pricing remain the declared adapter."
	game._show_equipment();await frame();await reveal_thermal();await photograph("04-fitted-atmospheric-shielding.png")
	game._close_menu();fresh();game.settings.orbital_gravity=false;var mercury:=stage_natural("mercury");ticks(6,1.0/60.0);await settle_scene();check(not mercury.contact.apply_f1014 and not thermal().last_atmosphere_active,"Actual airless source Mercury remains outside F1014")
	fixture_label="Explicit source Mercury native ground +5000m observer at900m/s. The real natural field has no atmosphere; this frame does not introduce fictional heating or drag."
	game._show_equipment();await frame();await reveal_thermal();await photograph("05-airless-mercury-thermal-status.png")
	game._close_menu();fresh();game.settings.orbital_gravity=false;var solar:=stage_star();ticks(6,1.0/60.0);await settle_scene()
	check(solar.altitude_s32==0x7fffffff and not thermal().last_atmosphere_active,"Actual Sun unknown height is normalized before F1014")
	fixture_label="Explicit Sun focus-frame placement at0.95 native outer bound and tangent900m/s. Source natural query returns raw height−1, normalized toINTMAX before F1014; F1033 stellar heat is a separate source effect."
	game._show_equipment();await frame();await reveal_thermal();await photograph("06-sun-unknown-height-gate.png")
	game._close_menu();fresh();game.settings.orbital_gravity=false;stage_natural("earth",5000,0);await game._enter_surface();check(game.surface.active and game.surface.source_surface(),"Actual source descent prepared the surface frame")
	if game.surface.active:
		game.ship.assisted=false;game.ship.target_speed=0;game.ship.velocity=Vector3(900,0,0);game.ship.last_notice="";game._tick(1.0/60.0,Vector2.ZERO,0)
	await settle_scene();fixture_label="Main's actual source-surface descent setup, followed by an explicit900m/s tangent-velocity fixture. Source terrain and its bodyfixed/tangent drag mapping remain active; no manual descent claim."
	await photograph("07-source-earth-surface-thermal-flight.png","flight")
	fresh();var old:Dictionary=copied(payload());old.navigation.source_hyperdrive.erase("thermal_system");old.flight.hull=37.625;check(load_fixture(old,"Prior0.16 source save with37.625percent hull"),"Actual Main loads the previous fuel-only save shape")
	check(game.ship.hull==37.625,"Legacy partial hull remains exact after first thermal binding")
	await settle_scene();fixture_label="Actual whole-game decoder loaded an explicit previous0.16 fuel-only source save with37.625percent hull; the new raw HP anchor preserves that exact percentage without healing or repeated damage."
	game._show_equipment();await frame();await reveal_thermal();await photograph("08-legacy-partial-hull-anchor.png")
	await finish()
