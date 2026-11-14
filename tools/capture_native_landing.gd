extends "res://tests/test_native_landing_trial_main.gd"
# Real Main framebuffers and production commands. Initial Earth placement is
# an explicit fixture; descent and powered departure execute the actual loop.
const CaptureBuild=preload("res://scripts/build_info.gd")
const OUTPUT:="res://validation/contact-lifecycle-2026-11-15/screenshots"
class CaptureSettings extends MemorySettings:
	func load_file()->bool:quality=2;return false
var captures:Array=[]
var capture_errors:Array=[]
var input_hashes:Dictionary={}
var archive_evidence:Dictionary={}
var contact_intervals:=0
var powered_intervals:=0
func check(ok:bool,label:String)->void:
	super.check(ok,label)
	if not ok:capture_errors.append(label)
func frame()->void:
	if is_instance_valid(game):game._process(1.0/60.0)
	await process_frame;await RenderingServer.frame_post_draw
func hash_sources(directory:String)->void:
	for name:String in DirAccess.get_files_at(directory):
		if name.get_extension() not in ["gd","gdshader","tscn","tres","json","png","ttf"]:continue
		var path:=directory.path_join(name);input_hashes[path.trim_prefix("res://")]=FileAccess.get_sha256(path)
	for name:String in DirAccess.get_directories_at(directory):
		if not name.begins_with("."):hash_sources(directory.path_join(name))
func finite_trial()->bool:
	if not game._native_surface_active() or not game.ship.position.is_finite() or not game.ship.velocity.is_finite() or not game.ship.attitude.is_finite() or not game.camera.position.is_finite() or not game.camera.quaternion.is_finite():return false
	var ground:Dictionary=game.surface.height_sample(game.ship.position.x,game.ship.position.z)
	return not ground.is_empty() and is_finite(float(ground.get("height",NAN))) and is_finite(float(game.surface.altitude(game.ship))) and game.source_contact_error.is_empty()
func photograph(filename:String,screen:String,scope:String)->bool:
	game._safe_area();game._refresh_hud();game._update_flight_controls()
	for index in range(5):await frame()
	check(finite_trial(),"Capture uses a finite actual native pose/ground without a rejected interval")
	if not finite_trial():return false
	var expected:Dictionary=game.instruments.camera_pose(game.ship.position,game.ship.attitude,game.ship.external_view,float(game.ship.profile().visual_span_m))
	check(game.camera.position.distance_to(expected.position)<0.5,"Production chase camera follows the actual flown pose after rendering frames")
	if screen=="flight":check(game.player.visible and game.camera.is_position_in_frustum(game.player.global_position),"Actual external ship remains visible in the production camera frustum")
	var before:=trial_state();var bounds:=root.get_visible_rect();var payload:Dictionary=game.surface.native_provider.render_payload();var visual:Dictionary=game.native_ground_view.stats()
	check(game.automated and not game.saving_enabled,"Native photographs use a separate private trial and never player progress")
	check(bool(visual.get("configured",false)) and bool(visual.get("all_emitted_leaves_filled",false)),"Actual Main world renders all sealed native leaves as opaque terrain")
	if screen=="flight":
		check(not game.menu.visible and game.flight_console.visible and bounds.encloses(game.flight_console.get_global_rect()),"The complete retained original-style bottom console fits the actual framebuffer")
		check(not game.ground_view.visible and not game.city_view.visible and game.native_ground_view.visible,"The ordinary terrain is hidden while the actual native leaf terrain is visible")
	else:check(game.menu.visible and bounds.encloses(game.menu.get_global_rect()),"Actual production report modal fits the small phone-shaped framebuffer")
	var image:=root.get_texture().get_image()
	check(image!=null and image.get_width()==root.size.x and image.get_height()==root.size.y,"Actual root viewport has the requested capture dimensions")
	if image==null:return false
	check(image.save_png(OUTPUT.path_join(filename))==OK,"Actual Main screenshot saved: "+filename)
	check(trial_state()==before,"Photographing changes no source body/history, physics, HP, fuel, gear or clock")
	captures.append({"file":filename,"sha256":FileAccess.get_sha256(OUTPUT.path_join(filename)),"screen":screen,"scope":scope,"viewport":[root.size.x,root.size.y],"scene":"scenes/main.tscn","native_state":game._native_trial_diagnostic(),"source_contact":game.source_contact_last.duplicate(true),"render_phase":payload.get("render_phase",""),"provider_identity":game.surface.native_provider.snapshot_identity(),"emitted_triangles":payload.get("triangles",[]).size(),"visual":visual,"ship_position_m":[game.ship.position.x,game.ship.position.y,game.ship.position.z],"ship_velocity_mps":[game.ship.velocity.x,game.ship.velocity.y,game.ship.velocity.z],"camera_position_m":[game.camera.position.x,game.camera.position.y,game.camera.position.z],"camera_attitude_xyzw":[game.camera.quaternion.x,game.camera.quaternion.y,game.camera.quaternion.z,game.camera.quaternion.w],"menu_title":game.menu_title.text if game.menu.visible else "","composited":false,"physical_android_capture":false,"performance_benchmark":false,"whole_native_mesh_claim":false})
	return true
func actual_include_save_report()->bool:
	game.diagnostics.directory=trial_directory+"/capture-diagnostics";game.diagnostics.reports_directory=trial_directory+"/capture-reports";game.diagnostics.engine_logs_directory=trial_directory+"/capture-engine"
	check(game.diagnostics.initialize(CaptureBuild.VERSION),"Production collector initializes a private capture directory")
	var before:=trial_state();var saved:Dictionary=copied(payload())
	game.report_include_save=true;game.report_draft="Исходная ручная посадка и взлёт: целочисленная геометрия корабля, все фактические пробники, состояние управления и полный снимок отдельного испытания."
	game._show_bug_report();await game._create_bug_report(false)
	check(game.current_report.get("ok",false),"Actual production report command creates the include-save ZIP")
	if not game.current_report.get("ok",false):return false
	var reader:=ZIPReader.new();var path:=str(game.current_report.path)
	check(reader.open(path)==OK,"Actual native diagnostic ZIP opens")
	if not reader.file_exists("report.json") or not reader.file_exists("game-save.json") or not reader.file_exists("manifest.json"):reader.close();check(false,"Actual ZIP includes report, complete save and checksum manifest");return false
	var report:Dictionary=JSON.parse_string(reader.read_file("report.json").get_string_from_utf8());var contents:=reader.read_file("game-save.json").get_string_from_utf8();var transported:Dictionary=JSON.parse_string(contents);var manifest:Dictionary=JSON.parse_string(reader.read_file("manifest.json").get_string_from_utf8())
	check(report.included_save and transported==saved and not contents.contains("[depth limit]") and not contents.contains("[unsupported value]"),"The real ZIP includes every raw native body/history and exact geometry witness")
	check(not game._decode_state(transported).is_empty(),"The production whole-game factory validates the exact native save extracted from its diagnostic ZIP")
	for entry:Dictionary in manifest.files:
		var data:=reader.read_file(str(entry.name));var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(data)
		check(data.size()==int(entry.bytes) and digest.finish().hex_encode()==str(entry.sha256),"Actual ZIP entry matches its production checksum manifest: "+str(entry.name))
	reader.close();var bytes:=FileAccess.get_file_as_bytes(path);var copy_path:=OUTPUT.get_base_dir().path_join("sample-native-landing-include-save-report.zip");var file:=FileAccess.open(copy_path,FileAccess.WRITE)
	if file==null:check(false,"Retained report copy opens");return false
	file.store_buffer(bytes);file.close();check(FileAccess.get_file_as_bytes(copy_path)==bytes,"Retained include-save report is byte-for-byte the production ZIP")
	archive_evidence={"file":copy_path.trim_prefix("res://"),"sha256":FileAccess.get_sha256(copy_path),"bytes":bytes.size(),"included_save":true,"whole_game_cold_decoder_accepted":true,"manifest_files":manifest.files,"production_filename":game.current_report.filename}
	check(trial_state()==before,"The actual report and cold validation leave the photographed native flight unchanged")
	var scroll:ScrollContainer=game.menu_rows.get_parent()
	if is_instance_valid(game.report_feedback):scroll.ensure_control_visible(game.report_feedback)
	return true
func run()->void:
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires rendered display and private capture mode");quit(1);return
	for directory:String in ["res://scripts","res://scenes","res://data","res://assets","res://tests"]:hash_sources(directory)
	for path:String in ["project.godot","tools/capture_native_landing.gd"]:input_hashes[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(OUTPUT);root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main failed to load");game.free();quit(1);return
	game.settings=CaptureSettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	check(game.automated and not game.saving_enabled,"Capture process starts without ordinary player progress")
	if not await trial_fresh():game.queue_free();await process_frame;quit(1);return
	check(game._start_native_landing_trial(),"Actual Main enters isolated native Earth landing outside cities")
	if not game._native_surface_active():game.queue_free();await process_frame;quit(1);return
	game._request_landing_gear(true);check(game._step_landing_gear(3.0),"Actual source gear reaches its physical endpoint before descent")
	game._close_menu();game.ship.assisted=false
	for index in range(3):
		if game.ship.external_view:break
		game._cycle_view()
	check(game.ship.external_view,"Actual retained view command selects the production chase camera")
	await photograph("01-native-entry-1440x720.png","flight","Actual production native trial starts50m above a signed original Earth root. Earth placement and gear extension are explicit setup fixtures; no orbit approach or universal terrain is claimed.")
	var start_y:float=game.ship.position.y
	for index in range(140):
		game._tick(0.1,Vector2.ZERO,0);contact_intervals=index+1
		await frame()
		if game.surface.landed or not game.source_contact_error.is_empty():break
	check(game.surface.landed and game.ship.position.y<start_y and game.ship.hull==100,"Actual manual gravity descent reaches original accepted healthy contact")
	await photograph("02-native-manual-landing-1440x720.png","flight","Actual Main gravity-only descent and original integer F576/F575 contact accepted the parked ship. Terrain contains only the actual sealed observed leaf triangles; Float32/native scalar height equivalence is not asserted.")
	var parked:Vector3=game.ship.position;check(game._takeoff_action() and game.ship.position==parked,"Actual takeoff command queues departure without a coordinate jump")
	for index in range(12):
		game._tick(0.1,Vector2.ZERO,0,1);powered_intervals=index+1
		await frame()
		if not game.source_contact_error.is_empty() or (not game.surface.landed and game.ship.position.y>parked.y+1.0):break
	check(not game.surface.landed and game.ship.position.y>parked.y and game.ship.velocity.y>0 and game.ship.hull==100,"Actual upward-thrust intervals release parking and create powered ascent")
	root.size=Vector2i(960,432);await photograph("03-native-powered-takeoff-960x432.png","flight","Actual queued takeoff followed by held upward thrust through the production native controller. The full retained lower console is shown at960x432; no automated departure or physical-phone performance claim.")
	if await actual_include_save_report():await photograph("04-native-include-save-report-960x432.png","report","Actual production offline report page with a real include-save ZIP. The retained archive contains exact native state and geometry and passes the actual cold decoder; no external sending or file picker is used.")
	for path:String in input_hashes:check(FileAccess.get_sha256("res://"+path)==input_hashes[path],"Capture input stayed frozen: "+path)
	check(captures.size()==4 and not archive_evidence.is_empty(),"Exactly four production frames and one actual include-save archive retained")
	var file:=FileAccess.open(OUTPUT.path_join("capture-manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"version":CaptureBuild.VERSION,"checks":checks,"failures":capture_errors,"completed_utc":Time.get_datetime_string_from_system(true),"source_sha256":input_hashes,"frames":captures,"archive":archive_evidence,"manual_descent_intervals":contact_intervals,"powered_takeoff_intervals":powered_intervals,"interval_seconds":0.1,"renderer":RenderingServer.get_current_rendering_method(),"display_server":DisplayServer.get_name(),"scope":"Actual production Main camera/framebuffers: explicit outside-city Earth trial entry, manually commanded gravity descent, original integer accepted contact, queued takeoff and actual powered ascent, complete retained bottom console at1440x720 and960x432, actual include-save offline ZIP. Shader/materials are production quality2. Only bounded observed source leaves are rendered; no compositing, universal mesh/native Float32-height equality, full sourcebank/autopilot, physical Android or FPS proof. All progress/diagnostics/save writes use private capture owners/directories."},"\t"));file.close()
	game.queue_free();await process_frame;print("Native landing captures: %d frames, %d checks, %d failures"%[captures.size(),checks,failures]);quit(1 if failures else 0)
