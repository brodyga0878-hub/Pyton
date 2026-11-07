extends "res://tests/test_source_gear_main.gd"
# Eight real Main framebuffers. Inspection-camera and observer placements are
# explicit fixtures; source words, classic console and meshes stay production.
const GearBuildInfo=preload("res://scripts/build_info.gd")
const GEAR_OUTPUT:="res://validation/contact-2026-11-08/gear-screenshots"
var gear_captures:Array=[]
var gear_capture_errors:Array=[]
var gear_input_hashes:Dictionary={}
var gear_fixture_label:=""
var inspection_camera:=false

func check(ok:bool,message:String)->void:
	super.check(ok,message)
	if not ok:gear_capture_errors.append(message)
func frame()->void:
	game._process(0);await process_frame;await RenderingServer.frame_post_draw
func resize_gear(width:int,height:int)->void:
	root.size=Vector2i(width,height);await frame();game._safe_area();game._refresh_hud();await frame()
func settle_gear()->void:
	game.ship.last_notice="";game._refresh_hud();game._update_flight_controls();game._process(0)
	for index in range(4):await frame()
func inspect_struts()->void:
	# An explicit static inspection observer below and beside the actual ship,
	# not a new gameplay camera or composited render of a replacement model.
	inspection_camera=true;game.ship.external_view=true;game.last_view="";game._process(0)
	var span:float=game.ship.profile().visual_span_m
	game.camera.position=game.ship.position+Basis(game.ship.attitude)*Vector3(span*0.90,-span*0.20,span*1.25)
	game.camera.look_at(game.ship.position+Basis(game.ship.attitude)*Vector3(0,-span*0.05,0),Vector3.UP)
func photograph_gear(filename:String)->void:
	await settle_gear()
	check(game.automated and not game.saving_enabled,"Gear capture never reads or writes ordinary player progress")
	check(not game.menu.visible and game.active_map==null,"Actual classic console remains visible in the captured Main scene")
	var bounds:Rect2=root.get_visible_rect();var button:Button=game.flight_console.buttons.get("gear")
	check(is_instance_valid(button),"Production managed-gear console button is present")
	var button_rect:=Rect2()
	if is_instance_valid(button):
		button_rect=button.get_global_rect();check(bounds.encloses(button_rect),"Actual gear touch target fits the viewport")
		check(button.size.x>=64 and button.size.y>=64,"Actual gear touch target keeps its supported minimum size")
		for key:String in game.flight_console.buttons:
			if key!="gear":check(not button_rect.intersects(game.flight_console.buttons[key].get_global_rect()),"Managed gear does not overlap retained classic action "+key)
		for key:String in game.flight_console.scanner_buttons:check(not button_rect.intersects(game.flight_console.scanner_buttons[key].get_global_rect()),"Managed gear does not overlap scanner touch "+key)
	var record:={"file":filename,"actual_scene":"scenes/main.tscn","viewport":[root.size.x,root.size.y],"fixture_setup":gear_fixture_label,"gear":gear(),"gear_save":saved_gear(),"gear_button_text":button.text if is_instance_valid(button) else "missing","gear_button_rect":str(button_rect),"gear_button_disabled":button.disabled if is_instance_valid(button) else true,"source_surface":game.surface.source_surface(),"surface_landed":game.surface.landed,"surface_altitude_m":game.surface.altitude(game.ship),"hull_percent":game.ship.hull,"external_ship_visible":game.player.visible,"actual_struts_visible":game.player.landing_gear.visible,"actual_strut_scale_y":game.player.landing_gear.scale.y,"actual_source_fraction":game.player._gear_amount,"camera_inspection_fixture":inspection_camera,"camera_position":str(game.camera.position),"camera_attitude":str(game.camera.quaternion),"notice":game.notice.text,"composited":false,"physical_phone_capture":false,"performance_benchmark":false,"manual_landing_claim":false,"player_progress_read_or_written":false}
	check(root.get_texture().get_image().save_png(GEAR_OUTPUT.path_join(filename))==OK,"Actual Main framebuffer saved as PNG")
	gear_captures.append(record)

func finish_gear_capture()->void:
	for path:String in gear_input_hashes:check(FileAccess.get_sha256("res://"+path)==gear_input_hashes[path],"Gear capture leaves its input unchanged: "+path)
	check(gear_captures.size()==8,"Eight meaningful actual Main gear frames are retained")
	var file:=FileAccess.open(GEAR_OUTPUT.path_join("capture-manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"version":GearBuildInfo.VERSION,"completed_utc":Time.get_datetime_string_from_system(true),"source_sha256":gear_input_hashes,"checks":checks,"failures":gear_capture_errors,"frames":gear_captures,"scope":"Retained gear capture tool adapted to current0.19 Main/console and real ship meshes. Original0.18 images/manifests are unchanged; optional reruns write only to the new contact folder. Earth observer placements and three lower-side inspection camera poses are explicit fixtures. Gear motion, bounded original rebound/damage and automatic recovery use production methods; no compositing, physical Android, manual landing, complete original F575 collision classifier or performance benchmark proof."},"\t"));file.close()
	game.queue_free();await process_frame
	print("SOURCE GEAR CAPTURE: %d frames, %d checks, %d failures"%[gear_captures.size(),checks,failures]);quit(1 if failures else 0)

func run()->void:
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires rendered display and private capture mode");quit(1);return
	for path:String in ["scripts/main.gd","scripts/surface_model.gd","scripts/flight_console.gd","scripts/ship_visual.gd","scripts/source_landing_gear.gd","scripts/source_landing_gear_session.gd","scripts/source_atmospheric_dynamics.gd","scripts/build_info.gd","tests/test_source_gear_main.gd","tools/capture_source_gear.gd","data/ffe_landing_gear.json","scripts/source_atmosphere_contact.gd","tests/test_source_thermal_main.gd","tests/test_source_fuel_main.gd","tests/test_source_hyperdrive_main.gd"]:gear_input_hashes[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(GEAR_OUTPUT);root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main script failed to load");game.free();quit(1);return
	game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	if not await stage_gear_surface(40.0):await finish_gear_capture();return
	# The observer fixture has replaced the completed descent setup. Clear its
	# old banner before recording independent gear states at the new altitude.
	game._announce("")
	inspection_camera=false;game.ship.external_view=false;game.last_view="";game._process(0)
	gear_fixture_label="Actual source Earth surface with an explicit observer40m above sampled ground; production classic cockpit console, physical gear initially retracted. No manual descent claim."
	await photograph_gear("01-classic-console-gear-retracted.png")
	command_gear(true);game._step_landing_gear(1.0)
	gear_fixture_label="Same actual Earth observer. Main requested deployment and advanced one source-clock second; the mechanism remains physically partial."
	await photograph_gear("02-classic-console-gear-deploying.png")
	game._step_landing_gear(2.0);await resize_gear(720,720)
	gear_fixture_label="Same source Earth observer with physically deployed gear. Supported narrow720px classic console retains every existing action and a separate gear touch target."
	await photograph_gear("03-classic-console-gear-deployed-narrow.png")
	await resize_gear(1440,720);complete_gear(false);inspect_struts()
	gear_fixture_label="Explicit lower-side inspection camera of the actual Main ship mesh at40m AGL. Production source gear fully retracted; no replacement mesh or added gameplay camera."
	await photograph_gear("04-actual-external-struts-retracted.png")
	command_gear(true);game._step_landing_gear(1.0);inspect_struts()
	gear_fixture_label="Same explicit lower-side actual-Main inspection camera. One production source-clock second of deployment sets the actual strut mesh scale from the physical source fraction."
	await photograph_gear("05-actual-external-struts-deploying.png")
	game._step_landing_gear(2.0);inspect_struts()
	gear_fixture_label="Same explicit lower-side actual-Main inspection camera. Production physical gear reaches65535 and the real strut mesh is fully extended."
	await photograph_gear("06-actual-external-struts-deployed.png")
	if not await stage_gear_surface(-0.01):await finish_gear_capture();return
	inspection_camera=false;complete_gear(false);game.ship.velocity=Vector3(0,-0.5,0);game.ship.external_view=false;game.last_view="";game._tick(1.0/60.0,Vector2.ZERO,0)
	check(not game.surface.landed and absf(game.surface.altitude(game.ship))<=game.surface.CONTACT_QUANTIZATION_METRES and game.ship.hull==75,"Current production gear-up contact applies original raw damage and a recoverable rebound at the native millimetre plane")
	gear_fixture_label="Explicit low-speed source-ground contact with retracted gear under current0.19. Original bounded F575 requests100raw damage and rebounds; existing F953 leaves75percent hull. Lift remains available; original0.18 screenshots are unchanged."
	await photograph_gear("07-gear-up-source-ground-rebound.png")
	game._toggle_auto()
	for index in range(300):
		game._tick(1.0/60.0,Vector2.ZERO,0)
		if game.surface.landed:break
	check(game.surface.landed and int(gear().position_u16)==65535 and game.ship.hull==75,"Production automatic recovery completes after physical gear deployment without restoring prior contact HP")
	game.ship.external_view=true;game.last_view="";game._process(0)
	gear_fixture_label="Current production automatic landing after the explicit original gear-up rebound: request extension, wait for its physical endpoint, then complete a healthy source contact at the existing75percent HP. Existing takeoff controls remain available."
	await photograph_gear("08-full-gear-recovered-source-landing.png")
	await finish_gear_capture()
