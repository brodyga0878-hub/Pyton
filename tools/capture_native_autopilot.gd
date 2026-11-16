extends "res://tests/test_native_orbit_main.gd"
# Production Main commands and framebuffers. The initial equipped Earth park
# is an explicit fixture; all three subsequent automatic phases are flown.
const CaptureBuild=preload("res://scripts/build_info.gd")
const OUTPUT:="res://validation/native-autopilot-2026-11-16/screenshots"
const REPORT_NAME:="sample-native-autopilot-include-save-report.zip"
const CAPTURE_SECONDS:=0.1
class CaptureSettings extends MemorySettings:
	func load_file()->bool:quality=2;return false
var captures:Array=[]
var capture_errors:Array=[]
var input_hashes:Dictionary={}
var archive_evidence:Dictionary={}
var flown_phases:Array=[]

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

func capture_orbit()->RefCounted:return game.get("native_orbit_trial")
func capture_orbit_active()->bool:
	var orbit:=capture_orbit()
	return orbit!=null and orbit.is_active()
func capture_orbit_snapshot()->Dictionary:
	var orbit:=capture_orbit()
	return orbit.snapshot(game.ship,game.nav,game.world,game.landing_gear) if orbit!=null and orbit.is_active() else {}
func capture_state()->PackedByteArray:
	return var_to_bytes([game.ship.snapshot(),game.nav.snapshot(),game.world.snapshot(),game.surface.snapshot(),game.landing_gear.snapshot(),pilot_state(),capture_orbit_snapshot(),game.source_motion.snapshot()])

func finite_scene()->bool:
	if not game.ship.position.is_finite() or not game.ship.velocity.is_finite() or not game.ship.attitude.is_finite() or not game.camera.position.is_finite() or not game.camera.quaternion.is_finite() or not game.source_contact_error.is_empty():return false
	if capture_orbit_active():return not capture_orbit_snapshot().is_empty() and not game.surface.active and not game.ship.surface_mode
	if not game._native_surface_active():return false
	var hit:Dictionary=game.surface.height_sample(game.ship.position.x,game.ship.position.z)
	return not hit.is_empty() and is_finite(float(hit.get("height",NAN))) and is_finite(float(game.surface.altitude(game.ship)))

func camera_precision_bound(expected:Vector3)->float:
	if not capture_orbit_active():return 0.5
	# The unchanged production camera interpolates Float32 world positions.
	# At multi-million metre coordinates a half-step can round back to the
	# current value one ULP away. More render frames cannot remove that cell.
	var squared:=0.0
	for component:float in [expected.x,expected.y,expected.z]:
		var raw:=PackedByteArray();raw.resize(4);raw.encode_float(0,component)
		var exponent:=(raw.decode_u32(0)>>23)&255
		var width:=pow(2.0,exponent-150.0) if exponent>0 else pow(2.0,-149.0)
		squared+=width*width
	return maxf(0.5,sqrt(squared))

func photograph(filename:String,phase:String,scope:String)->bool:
	game._safe_area();game._refresh_hud();game._update_flight_controls()
	for index in range(12):await frame()
	check(finite_scene(),"A finite accepted native automatic flight is shown: "+phase)
	if not finite_scene():return false
	var expected:Dictionary=game.instruments.camera_pose(game.ship.position,game.ship.attitude,game.ship.external_view,float(game.ship.profile().visual_span_m))
	var camera_error:float=game.camera.position.distance_to(expected.position);var camera_bound:=camera_precision_bound(expected.position)
	check(camera_error<=camera_bound,"The production chase camera follows the actual flown pose within its recorded Float32 bound: "+phase)
	var before:=capture_state();var bounds:=root.get_visible_rect();var space:=capture_orbit_active()
	check(game.automated and not game.saving_enabled and not game.native_trial_return.is_empty(),"Automatic captures keep private trial owners and an ordinary-flight return point")
	if phase!="report":
		check(not game.menu.visible and game.flight_console.visible and bounds.encloses(game.flight_console.get_global_rect()),"The full retained original-style lower console fits the framebuffer: "+phase)
		check(game.player.visible and game.camera.is_position_in_frustum(game.player.global_position),"The real external ship remains visible in the actual production camera: "+phase)
		if not space:check(game.native_ground_view.visible and not game.ground_view.visible and not game.city_view.visible,"Surface captures show only the actual emitted native terrain")
		else:check(not game.native_ground_view.visible and not game.ground_view.visible and game.celestial.visible,"The actual handoff uses the production space scene")
	else:check(game.menu.visible and bounds.encloses(game.menu.get_global_rect()),"The real report modal fits the small framebuffer")
	var screenshot:=root.get_texture().get_image()
	check(screenshot!=null and screenshot.get_width()==root.size.x and screenshot.get_height()==root.size.y,"The root framebuffer has the requested capture dimensions")
	if screenshot==null:return false
	check(screenshot.save_png(OUTPUT.path_join(filename))==OK,"The actual framebuffer is saved: "+filename)
	check(capture_state()==before,"Photographing advances no physics, guidance, source history, HP, fuel, gear or clock")
	var orbit:=capture_orbit();var ground:Dictionary=game.native_ground_view.stats() if game._native_surface_active() else {}
	captures.append({"file":filename,"sha256":FileAccess.get_sha256(OUTPUT.path_join(filename)),"phase":phase,"screen":"report" if phase=="report" else "flight","scope":scope,"viewport":[root.size.x,root.size.y],"scene":"scenes/main.tscn","native_state":game._native_trial_diagnostic(),"native_orbit":orbit.diagnostics() if space else {},"guidance":pilot_state(),"source_contact":game.source_contact_last.duplicate(true),"native_surface_visual":ground,"ship_position_m":[game.ship.position.x,game.ship.position.y,game.ship.position.z],"ship_velocity_mps":[game.ship.velocity.x,game.ship.velocity.y,game.ship.velocity.z],"camera_position_m":[game.camera.position.x,game.camera.position.y,game.camera.position.z],"camera_attitude_xyzw":[game.camera.quaternion.x,game.camera.quaternion.y,game.camera.quaternion.z,game.camera.quaternion.w],"camera_expected_position_m":[expected.position.x,expected.position.y,expected.position.z],"camera_residual_m":camera_error,"camera_float32_bound_m":camera_bound,"hull_percent":game.ship.hull,"atmospheric_shielding_installed":bool(game.nav.fuel_state(game.ship).get("atmospheric_shielding_installed",false)),"menu_title":game.menu_title.text if game.menu.visible else "","composited":false,"physical_android_capture":false,"performance_benchmark":false,"whole_native_mesh_claim":false,"circular_orbit_claim":false})
	return true

func fly_surface_guidance(phase:String,max_intervals:int,to_space:bool=false)->bool:
	var before_days:float=game.nav.elapsed_days;var before_fuel:=fuel();var intervals:=0
	for index in range(max_intervals):
		if (capture_orbit_active() if to_space else not pilot_active()):break
		game._tick(CAPTURE_SECONDS,Vector2.ZERO,0);intervals=index+1
		if index%32==31:await frame()
		if not game.source_contact_error.is_empty() or game.ship.hull<=0:break
	var completed:bool=capture_orbit_active() if to_space else not pilot_active() and game._native_surface_active() and not game.surface.landed
	check(completed and game.source_contact_error.is_empty(),"Actual Main completes powered automatic phase: "+phase)
	check(game.nav.elapsed_days>before_days and fuel()!=before_fuel,"Actual accepted phase consumes real clock and source fuel: "+phase)
	check(game.ship.hull==100,"The real protected automatic flight retains healthy source hull: "+phase)
	ordinary_unchanged("Captured "+phase)
	flown_phases.append({"phase":phase,"accepted_command_intervals":intervals,"seconds_per_interval":CAPTURE_SECONDS,"days_before_f64_hex":capture_clock_hex(before_days),"days_after_f64_hex":capture_clock_hex(game.nav.elapsed_days),"completed":completed,"hull_percent":game.ship.hull,"fuel_before":before_fuel,"fuel_after":fuel(),"source_contact_error":game.source_contact_error})
	return completed and game.source_contact_error.is_empty()

func capture_clock_hex(value:float)->String:
	var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value);return bytes.hex_encode()

func actual_include_save_report()->bool:
	game.diagnostics.directory=trial_directory+"/capture-diagnostics";game.diagnostics.reports_directory=trial_directory+"/capture-reports";game.diagnostics.engine_logs_directory=trial_directory+"/capture-engine"
	check(game.diagnostics.initialize(CaptureBuild.VERSION),"Production diagnostics initializes private capture directories")
	var before:=capture_state();var saved:Dictionary=copied(payload())
	check(saved.has("native_orbit_session") and not saved.native_orbit_session.is_empty(),"The real whole-game payload contains the active separate space-trial session")
	game.report_include_save=true;game.report_draft="Автопосадка, автоматический взлёт и непрерывный переход в космический режим: текущие управление, исходная история, шасси, топливо и полный снимок отдельного полёта."
	game._show_bug_report();await game._create_bug_report(false)
	check(game.current_report.get("ok",false),"The production report command creates an include-save ZIP")
	if not game.current_report.get("ok",false):return false
	var reader:=ZIPReader.new();var path:=str(game.current_report.path)
	check(reader.open(path)==OK,"The actual automatic-flight diagnostic ZIP opens")
	if not reader.file_exists("report.json") or not reader.file_exists("game-save.json") or not reader.file_exists("manifest.json"):reader.close();check(false,"The actual report ZIP contains report, full save and checksum manifest");return false
	var report:Dictionary=JSON.parse_string(reader.read_file("report.json").get_string_from_utf8());var raw:=reader.read_file("game-save.json").get_string_from_utf8();var saved_zip:Dictionary=JSON.parse_string(raw);var manifest:Dictionary=JSON.parse_string(reader.read_file("manifest.json").get_string_from_utf8())
	check(report.included_save and saved_zip==saved and saved_zip.native_orbit_session==saved.native_orbit_session and not raw.contains("[depth limit]") and not raw.contains("[unsupported value]"),"The actual ZIP preserves the complete active space session without context truncation")
	check(not game._decode_state(saved_zip).is_empty(),"The production cold factory validates the exact space-trial save extracted from its ZIP")
	for entry:Dictionary in manifest.files:
		var data:=reader.read_file(str(entry.name));var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(data)
		check(data.size()==int(entry.bytes) and digest.finish().hex_encode()==str(entry.sha256),"Actual ZIP entry matches its production checksum: "+str(entry.name))
	reader.close();var bytes:=FileAccess.get_file_as_bytes(path);var copy_path:=OUTPUT.get_base_dir().path_join(REPORT_NAME);var file:=FileAccess.open(copy_path,FileAccess.WRITE)
	if file==null:check(false,"Retained automatic-flight report copy opens");return false
	file.store_buffer(bytes);file.close();check(FileAccess.get_file_as_bytes(copy_path)==bytes,"Retained report is byte-for-byte the actual production ZIP")
	archive_evidence={"file":copy_path.trim_prefix("res://"),"sha256":FileAccess.get_sha256(copy_path),"bytes":bytes.size(),"included_save":true,"full_native_orbit_session":true,"whole_game_cold_decoder_accepted":true,"manifest_files":manifest.files,"production_filename":game.current_report.filename}
	check(capture_state()==before,"Production reporting and cold validation leave the actual captured flight unchanged")
	var scroll:ScrollContainer=game.menu_rows.get_parent()
	if is_instance_valid(game.report_feedback):scroll.ensure_control_visible(game.report_feedback)
	return true

func run()->void:
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires rendered display and private capture mode");quit(1);return
	for directory:String in ["res://scripts","res://scenes","res://data","res://assets","res://tests"]:hash_sources(directory)
	for path:String in ["project.godot","tools/capture_native_autopilot.gd"]:input_hashes[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(OUTPUT);root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main failed to load");game.free();quit(1);return
	game.settings=CaptureSettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	check(game.automated and not game.saving_enabled,"The process starts without ordinary player progress")
	if not await orbital_park_fixture():game.queue_free();await process_frame;quit(1);return
	game._close_menu()
	for index in range(3):
		if game.ship.external_view:break
		game._cycle_view()
	check(game.ship.external_view,"The actual retained view command selects the production chase camera")
	check(game.surface.landed and not pilot_active() and game.ship.hull==100,"The first frame follows actual automatic descent and original accepted parking")
	await photograph("01-native-autoland-1440x720.png","autoland","Actual Main automatic descent from the explicit initial Earth fixture has reached a genuine accepted source park. Real atmospheric shielding was bought through the ordinary service before entry; no HP, heat or contact state was patched.")
	check(game._begin_departure_action() and pilot_active(),"The production departure action starts automatic powered local ascent")
	if await fly_surface_guidance("local_1000m_ascent",3500):
		check(absf(game.surface.altitude(game.ship)-1000.0)<=1.0 and game.ship.velocity.length()<1.5,"The actual local ascent settles at one kilometre using real powered intervals")
		await photograph("02-native-auto-ascent-1440x720.png","local_ascent","Actual Main automatic launch and thrust-controlled ascent have settled at the local1000m target. Physical gear was retracted during flown safe clearance; no target-height relocation occurred.")
		check(game._begin_native_orbital_departure(),"The separate production orbital-departure command starts the next powered climb")
		if await fly_surface_guidance("space_handoff_after_20000m",7200,true):
			root.size=Vector2i(960,432)
			await photograph("03-native-space-handoff-960x432.png","space_handoff","Actual Main powered climb reached the guarded handoff and changed coordinate frames while retaining the flown position, rotated velocity, orientation and exact clock. This is a separate space-trial phase, not circular-orbit insertion or full original F570/F606.")
			if await actual_include_save_report():await photograph("04-native-autopilot-include-save-report-960x432.png","report","The actual production offline report page contains a real include-save ZIP with the complete current native space-trial session and accepted lineage. The real cold decoder accepted the extracted save; no external sending or file picker was exercised.")
	for path:String in input_hashes:check(FileAccess.get_sha256("res://"+path)==input_hashes[path],"Capture input remained frozen: "+path)
	check(captures.size()==4 and not archive_evidence.is_empty(),"Four genuine automatic-flight frames and the real include-save ZIP are retained")
	var file:=FileAccess.open(OUTPUT.path_join("capture-manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"version":CaptureBuild.VERSION,"checks":checks,"failures":capture_errors,"completed_utc":Time.get_datetime_string_from_system(true),"source_sha256":input_hashes,"frames":captures,"archive":archive_evidence,"flown_phases":flown_phases,"equipment_service":orbital_equipment_evidence.duplicate(true),"atmospheric_shielding_from_real_service":true,"renderer":RenderingServer.get_current_rendering_method(),"display_server":DisplayServer.get_name(),"scope":"Actual production Main framebuffers: genuine source autoland; local automatic1000m ascent; powered guarded20km space-frame handoff; real full-space-trial include-save ZIP. Initial Earth placement and real equipment service are explicit fixtures. Simulation uses actual Main commands and intervals with rendered checkpoints. Full retained bottom console fits1440x720 and960x432; camera follows actual ship. No compositing, circular-orbit/full-source-autopilot/object-bank/universalterrain, physical Android or FPS proof."},"\t"));file.close()
	game.queue_free();await process_frame;print("Native autopilot captures: %d frames, %d checks, %d failures"%[captures.size(),checks,failures]);quit(1 if failures else 0)
