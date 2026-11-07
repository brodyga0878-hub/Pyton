extends "res://tests/test_source_spherical_main.gd"
# Existing production views plus the actual diagnostic ZIP. These frames do
# not depict a new collision response or a replacement terrain classifier.
const SPHERE_OUTPUT:="res://validation/spherical-2026-11-08/screenshots"
var sphere_captures:Array=[]
var sphere_capture_errors:Array=[]
var sphere_input_hashes:Dictionary={}
var sphere_fixture_label:=""
var captured_report_proof:Dictionary={}

func check(ok:bool,message:String)->void:
	super.check(ok,message)
	if not ok:sphere_capture_errors.append(message)
func frame()->void:
	game._process(0);await process_frame;await RenderingServer.frame_post_draw
func settle_spherical()->void:
	game.ship.last_notice="";game._refresh_hud();game._update_flight_controls();game._process(0)
	for index in range(4):await frame()
func spherical_camera(external:bool)->void:
	game.ship.external_view=external;game.last_view="";game._process(0)
func spherical_space_observer(body_id:String)->void:
	var body:Dictionary=game.world.by_id[body_id]
	var centre:Vector3=game.world.local_meters(body_id,game.nav.elapsed_days)
	var envelope:=maxf(float(body.radius_km)*1000.0,float(body.get("source_outer_bound_m",0.0)))
	var radial:Vector3=game.world.local_meters("star",game.nav.elapsed_days)-centre
	if radial.length_squared()==0:radial=Vector3.RIGHT
	radial=radial.normalized()
	game.ship.position=centre+radial*envelope*1.35
	game.ship.velocity=Vector3.ZERO;game.ship.target_speed=0;game.ship.assisted=false;game.source_motion.reset()
	var forward:Vector3=(centre-game.ship.position).normalized()
	var up:=Vector3.RIGHT if absf(forward.dot(Vector3.UP))>0.98 else Vector3.UP
	game.ship.attitude=Basis.looking_at(forward,up).get_rotation_quaternion().normalized()
	spherical_camera(false)
	check(game.ship.position.distance_to(centre)>envelope,"Explicit capture observer is outside both the authored planet and original source envelope")
	check((-game.camera.global_basis.z).dot(forward)>0.999,"Retained production cockpit camera faces the actual planet centre")
func photograph_spherical(filename:String,screen:="flight")->void:
	await settle_spherical()
	check(game.automated and not game.saving_enabled,"Spherical diagnostic capture never reads or writes ordinary player progress")
	var before:=live_spherical_state();var probe:=spherical_sample();spherical_contract(probe)
	check(live_spherical_state()==before,"Recording screenshot metadata cannot change the actual observed flight")
	var bounds:Rect2=root.get_visible_rect();var record:={"file":filename,"actual_scene":"scenes/main.tscn","viewport":[root.size.x,root.size.y],"screen":screen,"fixture_setup":sphere_fixture_label,"source_spherical_probe":probe,"source_contact":last_contact(),"surface_active":game.surface.active,"surface_landed":game.surface.landed,"hull_percent":game.ship.hull,"raw_hull_u16":thermal().hull_u16,"cargo_hydrogen":inventory().hydrogen,"reaction_tank_raw":fuel().jet_raw_u32,"ship_position_m":str(game.ship.position),"ship_velocity_mps":str(game.ship.velocity),"camera_position":str(game.camera.position),"camera_attitude":str(game.camera.quaternion),"camera_policy":"retained production cockpit/external camera","notice":game.notice.text,"new_collision_response":false,"composited":false,"physical_phone_capture":false,"performance_benchmark":false,"manual_flight_claim":false,"player_progress_read_or_written":false}
	match screen:
		"map":check(game.active_map!=null and bounds.encloses(game.active_map.get_global_rect()),"Actual unchanged system map fits the framebuffer")
		"status","report":check(game.menu.visible and bounds.encloses(game.menu.get_global_rect()),"Actual production status/report modal fits the framebuffer")
		_:
			check(not game.menu.visible and game.active_map==null,"Retained classic flight console is visible")
			var button:Button=game.flight_console.buttons.get("gear")
			check(is_instance_valid(button) and bounds.encloses(button.get_global_rect()),"Existing independent gear control remains available in the flight console")
	if screen=="report":record["verified_archive"]=captured_report_proof.duplicate(true)
	check(root.get_texture().get_image().save_png(SPHERE_OUTPUT.path_join(filename))==OK,"Actual Main framebuffer saved as a spherical-diagnostic PNG")
	sphere_captures.append(record)
func finish_spherical_capture()->void:
	for path:String in sphere_input_hashes:check(FileAccess.get_sha256("res://"+path)==sphere_input_hashes[path],"Spherical capture leaves its input unchanged: "+path)
	check(sphere_captures.size()==8,"Eight actual production-view/report frames are retained")
	var file:=FileAccess.open(SPHERE_OUTPUT.path_join("capture-manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"version":SphereBuild.VERSION,"completed_utc":Time.get_datetime_string_from_system(true),"source_sha256":sphere_input_hashes,"checks":checks,"failures":sphere_capture_errors,"frames":sphere_captures,"scope":"Actual desktop Main views and real diagnostic-report ZIP containing read-only DOS F577 envelope facts. Existing source terrain, F575/F953 landing/takeoff, map and docking views are retained production behavior, not newly implemented F577 collisions. Explicit observer placements; no compositing, physical Android, manual approach, complete original classifier/object bank or performance benchmark proof."},"\t"));file.close()
	game.queue_free();await process_frame;print("SOURCE SPHERICAL CAPTURE: %d frames, %d checks, %d failures"%[sphere_captures.size(),checks,failures]);quit(1 if failures else 0)

func run()->void:
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires rendered display and private capture mode");quit(1);return
	for path:String in ["scripts/main.gd","scripts/source_spherical_contact.gd","scripts/source_spherical_contact_probe.gd","scripts/source_surface_contact.gd","scripts/source_surface_contact_bridge.gd","scripts/game_diagnostics.gd","scripts/diagnostics_logger.gd","scripts/build_info.gd","data/ffe_spherical_contact.json","tests/test_source_spherical_main.gd","tools/capture_source_spherical.gd"]:sphere_input_hashes[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(SPHERE_OUTPUT);root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main script failed to load");game.free();quit(1);return
	game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame();initialize_probe_diagnostics()
	fresh();game.settings.orbital_gravity=false;stage_natural("earth",5000,0);spherical_space_observer("earth")
	sphere_fixture_label="Explicit space observer at1.35 times the larger of Earth's authored radius and original outer envelope, from the actual body centre on its Sun-facing side. Ship attitude points the retained production cockpit camera toward Earth; no physics or renderer changes. New envelope facts are diagnostic only."
	await photograph_spherical("01-existing-earth-flight-readonly-probe.png")
	game._show_system();await frame()
	sphere_fixture_label="Existing production Sol system map for the same explicit Earth observer. The diagnostic probe does not move the ship, select a new physics parent or change original map behavior."
	await photograph_spherical("02-existing-system-map-readonly-probe.png","map");game._close_map(false)
	fresh();game.settings.orbital_gravity=false;stage_natural("mercury",5000,0);spherical_space_observer("mercury")
	sphere_fixture_label="Explicit space observer at1.35 times the larger of Mercury's authored radius and original outer envelope, from the actual body centre on its Sun-facing side. Ship attitude points the retained production cockpit camera toward Mercury; existing planet/Sun rendering is retained and F577 metadata creates no collision response."
	await photograph_spherical("03-existing-mercury-flight-readonly-probe.png")
	if not await stage_gear_surface(40):await finish_spherical_capture();return
	game.notice.text="";game.notice_timer=0;game.notice.hide();spherical_camera(true)
	sphere_fixture_label="Actual Main source Earth surface with an explicit40m observer. The canceled-entry transient descent banner is dismissed for this prepared observer. The probe composes the authored ship centre through the existing tangent frame without querying the terrain provider or changing its response."
	await photograph_spherical("04-existing-source-surface-observer.png")
	complete_gear(true);contact_pose(-0.01,Vector3(0,-0.5,0));game._tick(0.001,Vector2.ZERO,0);spherical_camera(false)
	check(game.surface.landed and game.ship.hull==100,"Existing0.19 source contact still lands safely without a new spherical-probe damage path")
	sphere_fixture_label="Explicit aligned Earth floor fixture with fully deployed gear. The existing bounded F575/F953 path completes the healthy landing; new F577 sampling remains envelope_only and response_applied=false."
	await photograph_spherical("05-unchanged-healthy-source-landing.png")
	check(game._takeoff_action(),"Existing takeoff command remains usable with read-only spherical diagnostics")
	for index in range(12):game._tick(1.0/60.0,Vector2.ZERO,0,1)
	spherical_camera(true);check(not game.surface.landed and game.ship.velocity.y>0 and game.ship.hull==100,"Existing source takeoff/lift is unchanged")
	sphere_fixture_label="Actual production takeoff and lift after the explicit healthy landing. The new diagnostic envelope neither parks the ship nor changes native HP, thrust or the existing flight controls."
	await photograph_spherical("06-unchanged-source-takeoff.png")
	fresh();check(dock_fixture(),"Actual original orbital bay prepares the retained docked status view")
	game._show_status();await frame()
	sphere_fixture_label="Explicit placement in an actual original orbital bay followed by the production docking command. Existing onboard-computer status remains read-only; probe facts refer to an envelope rather than a new docking collider."
	await photograph_spherical("07-existing-docked-onboard-status.png","status")
	game._close_menu();await actual_logger_and_report_zip()
	check(not spherical_archive.is_empty() and game.current_report.get("ok",false),"Actual Main report archive contains the new spherical facts")
	if not spherical_archive.is_empty():
		var bytes:=FileAccess.get_file_as_bytes(spherical_archive);var output:=SPHERE_OUTPUT.get_base_dir().path_join("sample-diagnostic-report.zip");var copied:=FileAccess.open(output,FileAccess.WRITE)
		copied.store_buffer(bytes);copied.close();check(FileAccess.get_file_as_bytes(output)==bytes,"The real collector ZIP is retained byte-for-byte as a standalone review artifact")
		captured_report_proof={"artifact":"sample-diagnostic-report.zip","bytes":bytes.size(),"sha256":FileAccess.get_sha256(output),"current_and_last_probe_verified":true,"periodic_event_verified":true,"included_save":false}
	var scroll:ScrollContainer=game.menu_rows.get_parent()
	if is_instance_valid(game.report_feedback):scroll.ensure_control_visible(game.report_feedback);await frame()
	sphere_fixture_label="Actual production diagnostic page after creating a real private ZIP. report.json and the periodic flight_sample log contain the new compact spherical-envelope field; no player save is included and no file-picker or external sharing is performed."
	await photograph_spherical("08-actual-diagnostic-zip-ready.png","report")
	await finish_spherical_capture()
