extends "res://tests/test_source_contact_geometry_main.gd"
# Actual production Main and its independent SubViewport. No compositing.
const OUTPUT:="res://validation/contact-frame-2026-11-14/screenshots"
var captures:Array=[]
var capture_failures:Array=[]
var input_hashes:Dictionary={}
func check(ok:bool,message:String)->void:
	super.check(ok,message)
	if not ok:capture_failures.append(message)
func frame()->void:
	game._process(0);await process_frame;await RenderingServer.frame_post_draw
func photograph(filename:String,screen:String,scope:String)->void:
	for index in range(5):await frame()
	var before:=alignment_live_state();var view:=geometry_view();var state:Dictionary=view.view_state() if view!=null else {}
	check(game.automated and not game.saving_enabled,"Actual geometry framebuffer capture uses private progress state")
	if screen=="flight":check(not game.menu.visible,"The retained production flight console is shown")
	else:check(game.menu.visible and root.get_visible_rect().encloses(game.menu.get_global_rect()),"The production modal fits the framebuffer")
	if screen=="geometry":check(view!=null and view.triangle_count>0 and view.viewport.world_3d!=game.camera.get_world_3d(),"The real independent native-leaf viewport renders actual bound packets")
	check(root.get_texture().get_image().save_png(OUTPUT.path_join(filename))==OK,"Actual Main framebuffer saves: "+filename)
	check(alignment_live_state()==before,"Photographing source geometry does not advance physical flight")
	captures.append({"file":filename,"screen":screen,"scope":scope,"scene":"scenes/main.tscn","viewport":[root.size.x,root.size.y],"title":game.menu_title.text if game.menu.visible else "","menu_text":alignment_labels() if game.menu.visible else "","view_state":state,"terrain_revision":game.surface.globe.revision,"ship_position_m":str(game.ship.position),"main_camera_position":str(game.camera.position),"main_camera_attitude":str(game.camera.quaternion),"observation":game.source_geometry_last.duplicate(true),"physical_phone_capture":false,"performance_benchmark":false,"ordinary_surface_replaced":false,"live_native_collision_enabled":false,"composited":false})
func run()->void:
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires rendered display and private capture mode");quit(1);return
	for path:String in ["scripts/main.gd","scripts/source_contact_geometry_probe.gd","scripts/source_terrain_query_frame.gd","scripts/source_native_contact_geometry.gd","scripts/native_contact_geometry_view.gd","scripts/source_terrain_query_trace.gd","scripts/source_natural_footprint_probe.gd","scripts/source_natural_contact.gd","scripts/source_surface_contact_bridge.gd","scripts/game_diagnostics.gd","scripts/diagnostics_logger.gd","scripts/build_info.gd","tests/test_source_contact_geometry_main.gd","tools/capture_source_contact_geometry.gd"]:input_hashes[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(OUTPUT);root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main failed to load");game.free();quit(1);return
	game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame();initialize_alignment_diagnostics()
	if await stage_gear_surface(40):
		game.ship.external_view=true;game.last_view="";game.notice.text="";game.notice_timer=0;game.notice.hide();game._refresh_hud();game._update_flight_controls()
		await photograph("01-retained-v4-flight-console.png","flight","Actual retained default v4 source surface and classic flight console. Observer40m placement is a fixture; no new gameplay terrain or manual flight claim.")
		game._show_contact_geometry();geometry_contract(game.source_geometry_last);await frame()
		var view:=geometry_view();var scroll:ScrollContainer=game.menu_rows.get_parent()
		if view!=null:scroll.ensure_control_visible(view);await frame()
		await photograph("02-actual-native-contact-geometry.png","geometry","Actual new Russian geometry page and isolated production World3D preview. The visible triangles come from fresh original F1876 leaf packets with Q31/SAR/IEEE projection witnesses. Independent preview only; ordinary flight terrain and physical camera unchanged.")
		if view!=null:
			var before:=alignment_live_state();var snapshot:Dictionary=game.source_geometry_last.duplicate(true);var yaw:float=view.view_state().yaw
			await tap(view.buttons.right,381);await tap(view.buttons.right,382)
			check(float(view.view_state().yaw)!=yaw and game.source_geometry_last==snapshot and alignment_live_state()==before,"Actual phone rotation changes only the isolated inspector camera")
		await photograph("03-rotated-native-contact-geometry.png","geometry","Same actual sealed source geometry packets after two real inspector rotation-button taps. No source recomputation, texture substitution, flight-camera edit or physics tick is used to produce this frame.")
		await actual_geometry_report()
		if not geometry_archive.is_empty():
			var bytes:=FileAccess.get_file_as_bytes(geometry_archive);var file:=FileAccess.open(OUTPUT.get_base_dir().path_join("sample-diagnostic-report.zip"),FileAccess.WRITE);file.store_buffer(bytes);file.close()
			check(FileAccess.get_file_as_bytes(OUTPUT.get_base_dir().path_join("sample-diagnostic-report.zip"))==bytes,"The retained geometry ZIP is byte-for-byte the real production collector archive")
			scroll=game.menu_rows.get_parent()
			if is_instance_valid(game.report_feedback):scroll.ensure_control_visible(game.report_feedback);await frame()
			await photograph("04-actual-native-geometry-report-ready.png","report","Actual offline report page after full frame/native leaf/quantization collection and compact periodic references. Default collection excludes saved player progress; no external sharing or file picker is exercised.")
	for path:String in input_hashes:check(FileAccess.get_sha256("res://"+path)==input_hashes[path],"Capture source unchanged: "+path)
	check(captures.size()==4,"Four actual production flight/geometry/rotation/report frames are retained")
	var manifest:=FileAccess.open(OUTPUT.path_join("capture-manifest.json"),FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"schema":1,"version":AlignmentBuild.VERSION,"checks":checks,"failures":capture_failures,"source_sha256":input_hashes,"frames":captures,"scope":"Actual desktop Main framebuffers and independent native-contact geometry SubViewport, including real rotation input and actual collector ZIP. Default v4 terrain/live response preserved. No physical Android, FPS, manual flight, full visible mesh equivalence or compositing claim."},"\t"));manifest.close()
	game.queue_free();await process_frame;print("Source contact geometry capture: %d frames, %d checks, %d failures"%[captures.size(),checks,failures]);quit(1 if failures else 0)
