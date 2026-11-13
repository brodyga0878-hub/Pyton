extends "res://tests/test_source_contact_alignment_main.gd"
# Production desktop framebuffers only. V5 is an explicit bounded geometry
# preview; no native physical landing policy is enabled by these fixtures.
const ALIGNMENT_OUTPUT:="res://validation/alignment-2026-11-13/screenshots"
var alignment_captures:Array=[]
var alignment_capture_errors:Array=[]
var alignment_input_hashes:Dictionary={}
var alignment_fixture_label:=""
var alignment_captured_report:Dictionary={}

func check(ok:bool,message:String)->void:
	super.check(ok,message)
	if not ok:alignment_capture_errors.append(message)
func frame()->void:
	game._process(0);await process_frame;await RenderingServer.frame_post_draw
func settle_alignment()->void:
	game.ship.last_notice="";game._refresh_hud();game._update_flight_controls();game._process(0)
	for index in range(4):await frame()
func alignment_camera(external:bool)->void:
	game.ship.external_view=external;game.last_view="";game._process(0)
func dismiss_alignment_fixture_notice()->void:
	game.notice.text="";game.notice_timer=0;game.notice.hide()
func photograph_alignment(filename:String,screen:="flight")->void:
	await settle_alignment()
	check(game.automated and not game.saving_enabled,"Alignment capture never reads or writes ordinary player progress")
	var before:=alignment_live_state();var sample:Dictionary=game._flight_diagnostic_sample()
	check(alignment_live_state()==before,"Recording actual framebuffer facts cannot change measured flight")
	var native_session:bool=game.nav.is_source_hyperdrive()
	var native_inventory:Dictionary=inventory() if native_session else {}
	var native_fuel:Dictionary=native_inventory.get("fuel_system",{})
	var native_thermal:Dictionary=native_inventory.get("thermal_system",{})
	var bounds:Rect2=root.get_visible_rect();var record:={"file":filename,"actual_scene":"scenes/main.tscn","viewport":[root.size.x,root.size.y],"screen":screen,"fixture_setup":alignment_fixture_label,"terrain_revision":str(game.surface.globe.revision) if game.surface.globe!=null else "","surface_active":game.surface.active,"surface_landed":game.surface.landed,"last_surface_alignment":game.source_alignment_last.duplicate(true),"source_natural_probe":sample.get("source_natural_probe",{}),"hull_percent":game.ship.hull,"raw_hull_u16":native_thermal.get("hull_u16") if native_session else null,"cargo_hydrogen":native_inventory.get("hydrogen") if native_session else null,"reaction_tank_raw":native_fuel.get("jet_raw_u32") if native_session else null,"native_session":native_session,"gear":gear(),"ship_position_m":str(game.ship.position),"ship_velocity_mps":str(game.ship.velocity),"camera_position":str(game.camera.position),"camera_attitude":str(game.camera.quaternion),"camera_policy":"retained production cockpit/external camera","notice":game.notice.text,"native_live_collision_enabled":false,"composited":false,"physical_phone_capture":false,"performance_benchmark":false,"manual_flight_claim":false,"player_progress_read_or_written":false}
	if screen=="flight":
		check(not game.menu.visible and game.active_map==null,"Retained classic flight console is visible in the actual frame")
		var gear_available:bool=game._gear_enabled()
		var button:Button=game.flight_console.buttons.get("gear" if gear_available else "menu")
		check(is_instance_valid(button) and bounds.encloses(button.get_global_rect()),"Existing gear control stays within the native flight frame" if gear_available else "Retained classic Menu control stays within the legacy graphics-preview frame")
		record["native_gear_control_available"]=gear_available
	else:
		check(game.menu.visible and bounds.encloses(game.menu.get_global_rect()),"Actual comparison/commander/report modal fits the framebuffer")
		record["menu_title"]=game.menu_title.text;record["menu_text"]=alignment_labels()
	if screen=="comparison":
		alignment_contract(game.source_alignment_last)
		check(game.menu_title.text=="ПРОВЕРКА ПОВЕРХНОСТИ","Actual production comparison page is shown")
	if screen=="report":record["verified_archive"]=alignment_captured_report.duplicate(true)
	check(root.get_texture().get_image().save_png(ALIGNMENT_OUTPUT.path_join(filename))==OK,"Actual Main framebuffer saves as an alignment PNG")
	alignment_captures.append(record)
func finish_alignment_capture()->void:
	for path:String in alignment_input_hashes:check(FileAccess.get_sha256("res://"+path)==alignment_input_hashes[path],"Alignment capture leaves its input unchanged: "+path)
	check(alignment_captures.size()==8,"Eight actual production-view/comparison/report frames are retained")
	var file:=FileAccess.open(ALIGNMENT_OUTPUT.path_join("capture-manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"version":AlignmentBuild.VERSION,"completed_utc":Time.get_datetime_string_from_system(true),"source_sha256":alignment_input_hashes,"checks":checks,"failures":alignment_capture_errors,"frames":alignment_captures,"scope":"Actual desktop Main framebuffers: retained default v4 surface, new explicit readonly comparison page and actual diagnostic ZIP, paused menu, existing graphics preview with restored original gear, and explicit canonical local v5 root-backed geometry preview. V4 remains the ordinary entry/default; no native live F576 switch, full globalv5 build, interpolated-point root certificate, physical Android, manual flight, performance benchmark or compositing."},"\t"));file.close()
	game.queue_free();await process_frame;print("SOURCE CONTACT ALIGNMENT CAPTURE: %d frames, %d checks, %d failures"%[alignment_captures.size(),checks,failures]);quit(1 if failures else 0)

func run()->void:
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires rendered display and private capture mode");quit(1);return
	for path:String in ["scripts/main.gd","scripts/surface_model.gd","scripts/surface_orbit_link.gd","scripts/source_contact_alignment_probe.gd","scripts/source_contact_surface_terrain.gd","scripts/source_terrain_contact_field.gd","scripts/source_natural_surface_bridge.gd","scripts/source_surface_terrain.gd","scripts/source_surface_render_packet.gd","scripts/source_surface_render_state.gd","scripts/source_surface_contact_patch.gd","scripts/surface_visual.gd","scripts/celestial_renderer.gd","scripts/source_landing_gear_session.gd","scripts/game_diagnostics.gd","scripts/diagnostics_logger.gd","scripts/build_info.gd","tests/test_source_contact_alignment_main.gd","tools/capture_source_contact_alignment.gd"]:alignment_input_hashes[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ALIGNMENT_OUTPUT);root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main script failed to load");game.free();quit(1);return
	game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame();initialize_alignment_diagnostics()
	if not await stage_gear_surface(40):await finish_alignment_capture();return
	dismiss_alignment_fixture_notice();alignment_camera(true)
	alignment_fixture_label="Actual default v4 Earth source surface with an explicit40m observer. The prepared-entry transient banner is dismissed; source F576 is diagnostic only and the existing live contact provider is retained. No manual approach claim."
	await photograph_alignment("01-existing-v4-source-surface.png")
	game._show_surface_alignment()
	alignment_fixture_label="Actual new commander-menu comparison page. Both values are measured at this observer's radial direction above one static reference radius; the page pauses flight and writes only the bound last comparison and log event."
	await photograph_alignment("02-actual-v4-height-comparison.png","comparison")
	game._show_menu();game._toggle_pause()
	alignment_fixture_label="Actual paused commander menu after the readonly comparison. The new surface-height action remains reachable; no ship, native HP, fuel, source clock or terrain-cache change is caused by the measurement."
	await photograph_alignment("03-paused-commander-surface-action.png","menu")
	game._close_menu();game._toggle_pause();command_gear(true);check(game._step_landing_gear(0.75),"Actual partial gear prepares the graphics-preview return fixture")
	var original_gear:RefCounted=game.landing_gear;var original_state:=gear();var original_comparison:Dictionary=game.source_alignment_last.duplicate(true)
	game._begin_graphics_demo();alignment_camera(true);dismiss_alignment_fixture_notice()
	alignment_fixture_label="Existing production graphics-flight preview, separate from the original surface session. Its geometry is retained product behavior; this frame does not depict v5 physics or a native terrain-contact change."
	await photograph_alignment("04-existing-graphics-preview.png")
	game._end_graphics_demo();alignment_camera(true);dismiss_alignment_fixture_notice()
	check(game.landing_gear==original_gear and gear()==original_state and game.source_alignment_last==original_comparison,"Production graphics return restores original partial gear owner and last measured context")
	alignment_fixture_label="Actual return from the existing graphics preview to the original v4 surface. The same original gear object, its partial physical position and the prior bound comparison are restored."
	await photograph_alignment("05-returned-original-surface-and-gear.png")
	if not await explicit_v5_surface_fixture(4000.0,64):await finish_alignment_capture();return
	dismiss_alignment_fixture_notice();alignment_camera(true)
	alignment_fixture_label="Explicit test-only v5 Earth source-root geometry preview using a real canonical4000m64-cell local worker packet in the production renderer. Original source records are retained; interpolated triangle points are not certified roots. No physics tick or default-policy switch is performed."
	await photograph_alignment("06-explicit-v5-bounded-surface-preview.png")
	game._show_surface_alignment()
	alignment_fixture_label="Actual comparison page for the explicit canonical local v5 preview. A small or large residual is reported as measured; no height, kind1, observer position or source bounds are adjusted to produce an artificial agreement."
	await photograph_alignment("07-actual-v5-height-comparison.png","comparison")
	game._close_menu();await actual_alignment_logger_and_report()
	check(not alignment_archive.is_empty() and game.current_report.get("ok",false),"Actual production collector retains the bound comparison in a real report archive")
	if not alignment_archive.is_empty():
		var bytes:=FileAccess.get_file_as_bytes(alignment_archive);var output:=ALIGNMENT_OUTPUT.get_base_dir().path_join("sample-diagnostic-report.zip");var copy:=FileAccess.open(output,FileAccess.WRITE)
		copy.store_buffer(bytes);copy.close();check(FileAccess.get_file_as_bytes(output)==bytes,"The actual collector ZIP is retained byte-for-byte as a review artifact")
		alignment_captured_report={"artifact":"sample-diagnostic-report.zip","bytes":bytes.size(),"sha256":FileAccess.get_sha256(output),"current_and_last_measurement_verified":true,"periodic_and_explicit_events_verified":true,"included_save":false}
	var scroll:ScrollContainer=game.menu_rows.get_parent()
	if is_instance_valid(game.report_feedback):scroll.ensure_control_visible(game.report_feedback);await frame()
	alignment_fixture_label="Actual production report page after collecting a real private ZIP. report.json contains last_surface_alignment in current and periodic contexts; the log contains comparison and flight_sample events. No player save, external file picker or sharing action is performed."
	await photograph_alignment("08-actual-comparison-diagnostic-zip-ready.png","report")
	await finish_alignment_capture()
