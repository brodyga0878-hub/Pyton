extends "res://tests/test_source_contact_main.gd"
# Real Main framebuffers with explicit low-altitude, speed, attitude and HP
# fixtures. Production geometry, native contact response and HP owner are used.
const ContactBuildInfo=preload("res://scripts/build_info.gd")
const CONTACT_OUTPUT:="res://validation/contact-2026-11-08/screenshots"
var contact_captures:Array=[]
var contact_capture_errors:Array=[]
var contact_input_hashes:Dictionary={}
var contact_fixture_label:=""

func check(ok:bool,message:String)->void:
	super.check(ok,message)
	if not ok:contact_capture_errors.append(message)
func frame()->void:
	game._process(0);await process_frame;await RenderingServer.frame_post_draw
func settle_contact()->void:
	game.ship.last_notice="";game._refresh_hud();game._update_flight_controls();game._process(0)
	for index in range(4):await frame()
func contact_camera(external:bool)->void:
	game.ship.external_view=external;game.last_view="";game._process(0)
func reveal_contact_hull()->void:
	game._show_equipment();await frame()
	var view:Control=game.hyperdrive_services_view;var scroll:ScrollContainer=game.menu_rows.get_parent()
	check(view.labels.has("thermal_hull") and view.labels.has("thermal_heat"),"Actual equipment view exposes the existing shared raw-HP status")
	if not view.labels.has("thermal_hull"):return
	scroll.ensure_control_visible(view.labels.thermal_heat);await frame()
	if view.labels.has("thermal_damage"):scroll.ensure_control_visible(view.labels.thermal_damage);await frame()
	check(scroll.get_global_rect().encloses(view.labels.thermal_hull.get_global_rect()),"Source contact HP remains visible inside the actual equipment viewport")
func photograph_contact(filename:String,screen:="flight")->void:
	await settle_contact()
	check(game.automated and not game.saving_enabled,"Contact capture never reads or writes ordinary player progress")
	var bounds:Rect2=root.get_visible_rect();var record:={"file":filename,"actual_scene":"scenes/main.tscn","viewport":[root.size.x,root.size.y],"screen":screen,"fixture_setup":contact_fixture_label,"contact":contact_facts(),"raw_thermal":thermal(),"cargo_hydrogen":inventory().hydrogen,"reaction_tank_raw":fuel().jet_raw_u32,"camera_position":str(game.camera.position),"camera_attitude":str(game.camera.quaternion),"camera_policy":"retained production cockpit/external camera","notice":game.notice.text,"composited":false,"physical_phone_capture":false,"performance_benchmark":false,"manual_landing_claim":false,"player_progress_read_or_written":false}
	if screen=="flight":
		check(not game.menu.visible and game.active_map==null,"Retained classic flight console is visible in the actual contact frame")
		var gear_button:Button=game.flight_console.buttons.get("gear")
		check(is_instance_valid(gear_button) and bounds.encloses(gear_button.get_global_rect()),"Actual retained console keeps its independent gear control within the viewport")
	else:
		check(game.menu.visible and bounds.encloses(game.menu.get_global_rect()),"Actual equipment modal fits the contact screenshot viewport")
		record["labels"]={}
		for key:String in game.hyperdrive_services_view.labels:record.labels[key]=game.hyperdrive_services_view.labels[key].text
	check(root.get_texture().get_image().save_png(CONTACT_OUTPUT.path_join(filename))==OK,"Actual contact Main framebuffer saved as PNG")
	contact_captures.append(record)
func finish_contact_capture()->void:
	for path:String in contact_input_hashes:check(FileAccess.get_sha256("res://"+path)==contact_input_hashes[path],"Contact capture leaves its production input unchanged: "+path)
	check(contact_captures.size()==8,"Eight actual Main source-contact frames are retained")
	var file:=FileAccess.open(CONTACT_OUTPUT.path_join("capture-manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"version":ContactBuildInfo.VERSION,"completed_utc":Time.get_datetime_string_from_system(true),"source_sha256":contact_input_hashes,"checks":checks,"failures":contact_capture_errors,"frames":contact_captures,"scope":"Actual desktop Main framebuffers with the retained classic console, production source terrain/city geometry and bounded original F575→existing F953 raw-HP owner. Explicit low-altitude/speed/attitude/legacy-HP fixtures; no compositing, new inspection camera, physical Android, manual flight, complete classifier/frame/event parity or performance benchmark proof."},"\t"));file.close()
	game.queue_free();await process_frame;print("SOURCE CONTACT CAPTURE: %d frames, %d checks, %d failures"%[contact_captures.size(),checks,failures]);quit(1 if failures else 0)

func run()->void:
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires rendered display and private capture mode");quit(1);return
	for path:String in ["scripts/main.gd","scripts/surface_model.gd","scripts/navigation.gd","scripts/source_hyperdrive_session.gd","scripts/source_surface_contact.gd","scripts/source_surface_contact_bridge.gd","scripts/flight_console.gd","scripts/ship_visual.gd","scripts/build_info.gd","data/ffe_surface_contact.json","tests/test_source_contact_main.gd","tools/capture_source_contact.gd"]:contact_input_hashes[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(CONTACT_OUTPUT);root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main script failed to load");game.free();quit(1);return
	game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	if not await stage_gear_surface(2):await finish_contact_capture();return
	complete_gear(true);contact_pose(-0.01,Vector3(0,-0.5,-10));game._tick(0.001,Vector2.ZERO,0);contact_camera(false)
	check(game.surface.landed and game.ship.hull==100,"Actual source contact accepts the aligned fully deployed above6m/s fixture without HP loss")
	contact_fixture_label="Explicit actual Earth source-ground contact with fully deployed gear, aligned hull and10m/s tangent velocity. Original raw L1 predicate accepts this case above the removed phone6m/s limit; no manual approach claim."
	await photograph_contact("01-native-soft-landing-classic-console.png")
	if not await stage_gear_surface(2):await finish_contact_capture();return
	complete_gear(false);contact_pose(-0.01,Vector3(0,-0.5,0));game._tick(0.001,Vector2.ZERO,0);contact_camera(false)
	check(not game.surface.landed and game.ship.hull==75,"Actual gear-up contact produces source rebound and one100raw/25percent minimum hull loss")
	contact_fixture_label="Explicit low-speed actual Earth floor contact with retracted gear. Original bounded F575 requests100raw damage for the real Cobra mass and rebounds; the removed0.18hover/100percent result is not retained."
	await photograph_contact("02-native-gear-up-rebound-and-hull.png")
	if not await stage_gear_surface(2):await finish_contact_capture();return
	complete_gear(true);contact_pose(-0.01,Vector3(0,-0.5,0),Quaternion(Vector3.FORWARD,PI*0.5));game._tick(0.001,Vector2.ZERO,0);contact_camera(true)
	check(not game.surface.landed and int(resolution().alignment_q31)<0x78000000,"Actual inclined contact fails the native alignment predicate despite deployed gear")
	contact_fixture_label="Explicit sideways-hull Earth floor fixture with fully deployed gear. Original Q31 alignment fails; the production external camera shows the actual native response pose and resulting raw HP."
	await photograph_contact("03-native-inclined-contact-external.png")
	if not await stage_gear_surface(2):await finish_contact_capture();return
	complete_gear(true);contact_pose(-0.01,Vector3(0,-80,0));game._tick(0.001,Vector2.ZERO,0);contact_camera(true)
	check(not resolution().landing_accepted and int(resolution().l1_speed_s32)>600,"Actual hard-impact fixture exceeds the source L1 speed boundary")
	contact_fixture_label="Explicit80m/s descending Earth floor fixture with deployed gear. Original bounce/L1-loss and ship-spec arithmetic supplies F953 damage; the phone impact multiplier has been removed for this source path."
	await photograph_contact("04-native-hard-impact-external.png")
	if not await stage_gear_surface(2):await finish_contact_capture();return
	check(set_contact_hull_fixture(37.625),"Fractional contact capture prepares its explicit legacy HP anchor")
	complete_gear(false);contact_pose(-0.01,Vector3(0,-0.5,0));game._tick(0.001,Vector2.ZERO,0)
	var cold:Dictionary=copied(payload());check(load_fixture(cold,"Explicit post-native-contact fractional HP continuation"),"Actual decoder cold-restores the fractional rebound fixture")
	check(game.ship.hull==12.625,"Cold restoration preserves exact12.625percent HP after source100raw loss")
	await reveal_contact_hull()
	contact_fixture_label="Actual whole-game cold restore after a source rebound from an explicit37.625percent old-save anchor. Native100raw loss leaves exactly12.625percent; equipment reads the existing shared HP state."
	await photograph_contact("05-fractional-contact-hp-cold-restore.png","equipment")
	game._close_menu();await actual_city_floor_single_hit();contact_camera(true)
	check(not last_contact().is_empty() and hp_detail().applied_calls==1,"Actual source city floor applies one native hit across its overlapping terrain provider")
	contact_fixture_label="Actual Main transfer to original city84 and an explicitly selected real compiled upward-facing floor triangle. One production contact consumes one F953 request; the same-step terrain overlap cannot double the hit."
	await photograph_contact("06-original-city-floor-single-impact.png")
	if not await stage_gear_surface(2):await finish_contact_capture();return
	complete_gear(false);contact_pose(-0.01,Vector3(0,-0.5,0));game._tick(0.001,Vector2.ZERO,0)
	for index in range(8):game._tick(1.0/60.0,Vector2.ZERO,0,1)
	complete_gear(true);contact_pose(-0.01,Vector3(0,-0.5,0));game._tick(0.001,Vector2.ZERO,0)
	check(game.surface.landed and game.ship.hull==75,"After a source rebound, full extension permits a healthy recovery landing at its existing75percent HP")
	check(game._takeoff_action(),"Actual takeoff remains available after the source-contact recovery")
	for index in range(8):game._tick(1.0/60.0,Vector2.ZERO,0,1)
	contact_camera(true);check(not game.surface.landed and game.ship.velocity.y>0 and game.ship.hull==75,"Actual phone lift escapes after recovery without repeating contact damage")
	contact_fixture_label="Explicit gear-up source impact followed by actual lift, full production gear extension, a new low-speed source recovery contact and the real takeoff/lift path. Corrected placement for the second contact is an explicit fixture."
	await photograph_contact("07-recovered-source-landing-and-takeoff.png")
	await fatal_source_contact();game._close_menu();contact_camera(false)
	check(game.ship.hull==0 and thermal().destroyed,"Actual native contact death survives its whole-game cold restore")
	contact_fixture_label="Explicit20.125percent old-save HP anchor meets an actual low-speed gear-up Earth floor contact. Original raw damage destroys the ship; Main records and cold-restores the fatal state without spending jump fuel or fabricating a surface charge."
	await photograph_contact("08-source-contact-fatality-restored.png")
	await finish_contact_capture()
