extends "res://tests/test_source_natural_footprint_main.gd"
# Production framebuffers and the actual offline report. No compositing.
const OUTPUT:="res://validation/footprint-2026-11-14/screenshots"
var captures:Array=[]
var capture_failures:Array=[]
var input_hashes:Dictionary={}
func check(ok:bool,message:String)->void:
	super.check(ok,message)
	if not ok:capture_failures.append(message)
func frame()->void:
	game._process(0);await process_frame;await RenderingServer.frame_post_draw
func photograph(filename:String,screen:String,scope:String)->void:
	for index in range(4):await frame()
	var before:=alignment_live_state();var bounds:=root.get_visible_rect()
	check(game.automated and not game.saving_enabled,"Production framebuffer capture uses private state")
	if screen=="flight":check(not game.menu.visible and bounds.encloses(game.flight_console.buttons.menu.get_global_rect()),"The retained classic console remains accessible")
	else:check(game.menu.visible and bounds.encloses(game.menu.get_global_rect()),"The production contact/report modal fits the phone-shaped framebuffer")
	check(root.get_texture().get_image().save_png(OUTPUT.path_join(filename))==OK,"Actual Main framebuffer saves: "+filename)
	check(alignment_live_state()==before,"Photographing the production UI does not advance flight")
	captures.append({"file":filename,"screen":screen,"scope":scope,"scene":"scenes/main.tscn","viewport":[root.size.x,root.size.y],"title":game.menu_title.text if game.menu.visible else "","menu_text":alignment_labels() if game.menu.visible else "","terrain_revision":game.surface.globe.revision,"ship_position_m":str(game.ship.position),"ship_attitude":str(game.ship.attitude),"observation":game.source_footprint_last.duplicate(true),"physical_phone_capture":false,"performance_benchmark":false,"composited":false,"native_live_collision_enabled":false})
func run()->void:
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires rendered display and private capture mode");quit(1);return
	for path:String in ["scripts/main.gd","scripts/source_natural_footprint_probe.gd","scripts/source_terrain_query_trace.gd","scripts/source_natural_contact.gd","scripts/source_natural_contact_pipeline.gd","scripts/source_natural_surface_bridge.gd","scripts/source_surface_contact_bridge.gd","scripts/game_diagnostics.gd","scripts/diagnostics_logger.gd","scripts/build_info.gd","tests/test_source_natural_footprint_main.gd","tools/capture_source_natural_footprint.gd"]:input_hashes[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(OUTPUT);root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main failed to load");game.free();quit(1);return
	game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame();initialize_alignment_diagnostics()
	if await stage_gear_surface(40):
		game.ship.external_view=true;game.last_view="";game.notice.text="";game.notice_timer=0;game.notice.hide();game._refresh_hud();game._update_flight_controls()
		await photograph("01-retained-flight-console.png","flight","Actual default v4 Earth source surface and retained original-style console, observer staged40m above authored clearance. No manual-flight or new collision-physics claim.")
		game._show_surface_footprint();footprint_contract(game.source_footprint_last)
		await photograph("02-actual-full-ship-contact-check.png","observation","Actual explicit Russian full-ship observation page; source F576 visits the original ordered volume prefix on copied records. Isolated initial globals are labelled; visible geometry identity is not certified and no response is applied.")
		await actual_footprint_report()
		if not footprint_archive.is_empty():
			var bytes:=FileAccess.get_file_as_bytes(footprint_archive);var output:=OUTPUT.get_base_dir().path_join("sample-diagnostic-report.zip");var file:=FileAccess.open(output,FileAccess.WRITE);file.store_buffer(bytes);file.close()
			check(FileAccess.get_file_as_bytes(output)==bytes,"Retained sample archive is byte-for-byte the real collector result")
			var scroll:ScrollContainer=game.menu_rows.get_parent()
			if is_instance_valid(game.report_feedback):scroll.ensure_control_visible(game.report_feedback);await frame()
			await photograph("03-actual-contact-report-zip-ready.png","report","Actual production report page after collecting the complete ship-volume observation and original triangle integer trace into a private ZIP. No player save or external share/file picker is used.")
	for path:String in input_hashes:check(FileAccess.get_sha256("res://"+path)==input_hashes[path],"Capture leaves its source unchanged: "+path)
	check(captures.size()==3,"Three actual production flight/contact/report frames are retained")
	var manifest:=FileAccess.open(OUTPUT.path_join("capture-manifest.json"),FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"schema":1,"version":AlignmentBuild.VERSION,"checks":checks,"failures":capture_failures,"source_sha256":input_hashes,"frames":captures,"scope":"Actual desktop production Main framebuffers, copied diagnostic observations and real offline collector ZIP. Default v4 live physics and original-style console retained. No physical Android, FPS, manual approach, full mesh parity or compositing claim."},"\t"));manifest.close()
	game.queue_free();await process_frame;print("Source footprint capture: %d frames, %d checks, %d failures"%[captures.size(),checks,failures]);quit(1 if failures else 0)
