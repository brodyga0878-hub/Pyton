extends "res://tests/test_native_return_main.gd"
# Actual production Main framebuffers. Native flight is flown through real
# commands/intervals. The later station-modal placement is a separate labelled
# fixture after exact return to the ordinary flight, not a station-frame port.
const CaptureBuild=preload("res://scripts/build_info.gd")
const OUTPUT:="res://validation/native-return-2026-11-16/screenshots"
const REPORT_NAME:="sample-native-return-include-save-report.zip"
const CAPTURE_SECONDS:=0.1
class CaptureSettings extends MemorySettings:
	func load_file()->bool:quality=2;return false
var captures:Array=[]
var capture_errors:Array=[]
var input_hashes:Dictionary={}
var archive_evidence:Dictionary={}
var flown_phases:Array=[]
var dock_fixture_evidence:Dictionary={}

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

func finite_scene(dock:bool=false)->bool:
	if not game.ship.position.is_finite() or not game.ship.velocity.is_finite() or not game.ship.attitude.is_finite() or not game.camera.position.is_finite() or not game.camera.quaternion.is_finite() or not game.source_contact_error.is_empty():return false
	if dock:return not game.surface.active and game.ship.has_source_station() and game.ship.station_available and not game._native_trial_active()
	if capture_orbit_active():return not capture_orbit_snapshot().is_empty() and not game.surface.active and not game.ship.surface_mode
	if not game._native_surface_active():return false
	var hit:Dictionary=game.surface.height_sample(game.ship.position.x,game.ship.position.z)
	return not hit.is_empty() and is_finite(float(hit.get("height",NAN))) and is_finite(float(game.surface.altitude(game.ship)))

func camera_precision_bound(expected:Vector3)->float:
	# Unchanged production camera interpolates Float32 world positions. Record
	# one vector ULP when large orbital coordinates cannot converge further.
	var squared:=0.0
	for component:float in [expected.x,expected.y,expected.z]:
		var raw:=PackedByteArray();raw.resize(4);raw.encode_float(0,component)
		var exponent:=(raw.decode_u32(0)>>23)&255
		var width:=pow(2.0,exponent-150.0) if exponent>0 else pow(2.0,-149.0)
		squared+=width*width
	return maxf(0.5,sqrt(squared))

func photograph(filename:String,phase:String,scope:String,dock:bool=false)->bool:
	game._safe_area();game._refresh_hud();game._update_flight_controls()
	for index in range(12):await frame()
	check(finite_scene(dock),"An actual finite production flight is shown: "+phase)
	if not finite_scene(dock):return false
	var expected:Dictionary=game.instruments.camera_pose(game.ship.position,game.ship.attitude,game.ship.external_view,float(game.ship.profile().visual_span_m))
	var camera_error:float=game.camera.position.distance_to(expected.position);var camera_bound:=camera_precision_bound(expected.position)
	check(camera_error<=camera_bound,"The unchanged production camera follows the actual ship within its recorded Float32 bound: "+phase)
	var before:=capture_state();var bounds:=root.get_visible_rect()
	check(game.automated and not game.saving_enabled,"Captures use private automated owners without ordinary player save writes")
	if not dock:
		check(not game.native_trial_return.is_empty() and game._native_surface_active(),"Native captures retain the separate trial and its original ordinary return point")
		check(not game.menu.visible and game.flight_console.visible and bounds.encloses(game.flight_console.get_global_rect()),"The full retained original-style lower console fits the framebuffer: "+phase)
		check(game.player.visible and game.camera.is_position_in_frustum(game.player.global_position),"The real external ship remains visible in its actual production camera: "+phase)
		check(game.native_ground_view.visible and not game.ground_view.visible and not game.city_view.visible,"Native captures show the actual emitted source terrain")
	else:
		check(game.menu.visible and bounds.encloses(game.menu.get_global_rect()),"The actual docking-guidance window fits the small framebuffer")
		check(not game.ship.docked and not game.ship.can_dock(),"The separate source-station fixture remains outside the real bay capture volume")
	var screenshot:=root.get_texture().get_image()
	check(screenshot!=null and screenshot.get_width()==root.size.x and screenshot.get_height()==root.size.y,"The root framebuffer has the requested capture dimensions")
	if screenshot==null:return false
	check(screenshot.save_png(OUTPUT.path_join(filename))==OK,"The actual framebuffer is saved: "+filename)
	check(capture_state()==before,"Photographing advances no physics, guidance, source history, HP, fuel, gear or clock")
	captures.append({"file":filename,"sha256":FileAccess.get_sha256(OUTPUT.path_join(filename)),"phase":phase,"screen":"dock_guidance" if dock else "flight","scope":scope,"viewport":[root.size.x,root.size.y],"scene":"scenes/main.tscn","native_state":game._native_trial_diagnostic(),"guidance":pilot_state(),"source_contact":game.source_contact_last.duplicate(true),"native_surface_visual":game.native_ground_view.stats() if game._native_surface_active() else {},"ship_position_m":[game.ship.position.x,game.ship.position.y,game.ship.position.z],"ship_velocity_mps":[game.ship.velocity.x,game.ship.velocity.y,game.ship.velocity.z],"camera_position_m":[game.camera.position.x,game.camera.position.y,game.camera.position.z],"camera_attitude_xyzw":[game.camera.quaternion.x,game.camera.quaternion.y,game.camera.quaternion.z,game.camera.quaternion.w],"camera_expected_position_m":[expected.position.x,expected.position.y,expected.position.z],"camera_residual_m":camera_error,"camera_float32_bound_m":camera_bound,"hull_percent":game.ship.hull,"atmospheric_shielding_installed":bool(game.nav.fuel_state(game.ship).get("atmospheric_shielding_installed",false)),"menu_title":game.menu_title.text if game.menu.visible else "","composited":false,"physical_android_capture":false,"performance_benchmark":false,"whole_native_mesh_claim":false,"circular_orbit_claim":false,"continuous_station_handoff_claim":false})
	return true

func record_phase(name:String,intervals:int,before_days:float,before_fuel:Dictionary,completed:bool)->void:
	flown_phases.append({"phase":name,"accepted_command_intervals":intervals,"seconds_per_interval":CAPTURE_SECONDS,"days_before_f64_hex":capture_clock_hex(before_days),"days_after_f64_hex":capture_clock_hex(game.nav.elapsed_days),"completed":completed,"hull_percent":game.ship.hull,"fuel_before":before_fuel,"fuel_after":fuel(),"source_contact_error":game.source_contact_error})

func fly_outbound()->bool:
	var before_days:float=game.nav.elapsed_days;var before_fuel:=fuel();var intervals:=0
	check(game._begin_native_orbital_departure(),"Actual production departure requests the genuine source20km powered climb")
	for index in range(9000):
		if capture_orbit_active() or not pilot_active():break
		game._tick(CAPTURE_SECONDS,Vector2.ZERO,0);intervals=index+1
		if index%32==31:await frame()
		if not game.source_contact_error.is_empty() or game.ship.hull<=0:break
	var complete:bool=capture_orbit_active() and game.source_contact_error.is_empty()
	check(complete and game.nav.elapsed_days>before_days and fuel()!=before_fuel and game.ship.hull==100,"The actual powered outward flight reaches the guarded space frame with real time/fuel and healthy hull")
	ordinary_unchanged("Captured genuine outbound flight")
	record_phase("protected_20km_outbound",intervals,before_days,before_fuel,complete)
	return complete

func fly_descent(to_height:float,max_intervals:int,expect_park:bool=false)->bool:
	var before_days:float=game.nav.elapsed_days;var before_fuel:=fuel();var intervals:=0
	for index in range(max_intervals):
		if not pilot_active() or game.surface.landed or game.surface.altitude(game.ship)<=to_height:break
		game._tick(CAPTURE_SECONDS,Vector2.ZERO,0);intervals=index+1
		if index%32==31:await frame()
		if not game.source_contact_error.is_empty() or game.ship.hull<=0:break
	var complete:bool=game.surface.landed and not pilot_active() and game.surface.native_session.phase()=="parked" if expect_park else pilot_active() and game.surface.altitude(game.ship)<=to_height
	check(complete and game.source_contact_error.is_empty(),"Actual Main completes the requested physical return-descent segment")
	check(game.nav.elapsed_days>before_days and fuel()!=before_fuel and game.ship.hull==100,"Accepted descent advances actual time/fuel and retains the real protected hull")
	ordinary_unchanged("Captured native descent")
	record_phase("accepted_source_park" if expect_park else "high_return_descent",intervals,before_days,before_fuel,complete)
	return complete

func capture_clock_hex(value:float)->String:
	var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value);return bytes.hex_encode()

func actual_include_save_report()->bool:
	game.diagnostics.directory=trial_directory+"/capture-diagnostics";game.diagnostics.reports_directory=trial_directory+"/capture-reports";game.diagnostics.engine_logs_directory=trial_directory+"/capture-engine"
	check(game.diagnostics.initialize(CaptureBuild.VERSION),"Production diagnostics initializes private capture directories")
	var before:=capture_state();var saved:Dictionary=copied(payload())
	check(saved.has("native_autopilot_session") and saved.native_autopilot_session.mode=="return_landing" and not saved.has("native_orbit_session"),"The actual whole-game payload contains active returned descent and its native history")
	game.report_include_save=true;game.report_draft="Возвращение из космоса и управляемое снижение: полный снимок исходной поверхности, истории контакта, автоматики, шасси, корпуса, топлива и времени."
	game._show_bug_report();await game._create_bug_report(false)
	check(game.current_report.get("ok",false),"The production report command creates an include-save return-descent ZIP")
	if not game.current_report.get("ok",false):return false
	var reader:=ZIPReader.new();var path:=str(game.current_report.path)
	check(reader.open(path)==OK,"The actual returned-flight diagnostic ZIP opens")
	if not reader.file_exists("report.json") or not reader.file_exists("game-save.json") or not reader.file_exists("manifest.json"):reader.close();check(false,"The actual report ZIP contains report, full save and checksum manifest");return false
	var report:Dictionary=JSON.parse_string(reader.read_file("report.json").get_string_from_utf8());var raw:=reader.read_file("game-save.json").get_string_from_utf8();var saved_zip:Dictionary=JSON.parse_string(raw);var manifest:Dictionary=JSON.parse_string(reader.read_file("manifest.json").get_string_from_utf8())
	check(report.included_save and saved_zip==saved and saved_zip.native_autopilot_session.mode=="return_landing" and not raw.contains("[depth limit]") and not raw.contains("[unsupported value]"),"The actual ZIP preserves complete returned guidance/raw history without context truncation")
	check(not game._decode_state(saved_zip).is_empty(),"The production cold factory validates the exact return-descent save extracted from its ZIP")
	for entry:Dictionary in manifest.files:
		var data:=reader.read_file(str(entry.name));var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(data)
		check(data.size()==int(entry.bytes) and digest.finish().hex_encode()==str(entry.sha256),"Actual ZIP entry matches its production checksum: "+str(entry.name))
	reader.close();var bytes:=FileAccess.get_file_as_bytes(path);var copy_path:=OUTPUT.get_base_dir().path_join(REPORT_NAME);var file:=FileAccess.open(copy_path,FileAccess.WRITE)
	if file==null:check(false,"Retained return-descent report copy opens");return false
	file.store_buffer(bytes);file.close();check(FileAccess.get_file_as_bytes(copy_path)==bytes,"Retained report is byte-for-byte the actual production ZIP")
	archive_evidence={"file":copy_path.trim_prefix("res://"),"sha256":FileAccess.get_sha256(copy_path),"bytes":bytes.size(),"included_save":true,"full_native_surface_session":true,"full_return_descent_guidance":true,"whole_game_cold_decoder_accepted":true,"manifest_files":manifest.files,"production_filename":game.current_report.filename,"flown_altitude_m":game.surface.altitude(game.ship)}
	check(capture_state()==before,"Production reporting and cold validation leave the actual flight unchanged")
	game._close_menu();return true

func stage_dock_modal()->bool:
	# This is an explicit independent fixture in the existing real station
	# frame after restoring the ordinary flight, never a transfer from trial.
	leave_auto_fixture("Captured full return descent")
	fresh();var port:Dictionary={}
	for row:Dictionary in game.world.settlements:
		if int(row.type_code) in [32,33,34]:port=row;break
	check(not port.is_empty(),"The separate ordinary fixture has an actual original orbital station")
	if port.is_empty():return false
	game.world.focus_id=str(port.parent);game.world.selected_id=str(port.parent);game.world.site_id=str(port.id)
	game._apply_system();var basis:Basis=game.world.source_station_basis(game.nav.elapsed_days)
	game.ship.position=game.ship.STATION+basis*Vector3(0,0,80);game.ship.velocity=Vector3.ZERO;game.ship.target_speed=0;game.ship.attitude=basis.get_rotation_quaternion().normalized();game.ship.assisted=true;game.ship.autopilot=false
	game._apply_system();game._close_menu();game._refresh_hud()
	check(game.has_method("_show_docking_guidance") and game.ship.has_source_station() and not game.ship.can_dock(),"The genuine existing dock rejects the labelled80m fixture outside its interior capture volume")
	if not game.has_method("_show_docking_guidance"):return false
	var before:=capture_state();game._show_docking_guidance();await frame()
	check(game.menu.visible and capture_state()==before,"Opening the production guidance page is read-only for the ordinary station fixture")
	dock_fixture_evidence={"explicit_independent_station_fixture":true,"after_exact_trial_exit":true,"station_id":str(port.id),"source_model_index":int(port.model_index),"local_position_m":[0,0,80],"position_is_fixture_not_flown":true,"can_dock":game.ship.can_dock(),"continuous_trial_to_station_transfer_claim":false,"kernel_predicates_unchanged":true}
	return game.menu.visible

func finish_capture()->void:
	for path:String in input_hashes:check(FileAccess.get_sha256("res://"+path)==input_hashes[path],"Capture input remained frozen: "+path)
	check(captures.size()==4 and not archive_evidence.is_empty() and not dock_fixture_evidence.is_empty(),"Four genuine production frames and the real return-descent include-save ZIP are retained")
	var file:=FileAccess.open(OUTPUT.path_join("capture-manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"version":CaptureBuild.VERSION,"checks":checks,"failures":capture_errors,"completed_utc":Time.get_datetime_string_from_system(true),"source_sha256":input_hashes,"frames":captures,"archive":archive_evidence,"flown_phases":flown_phases,"equipment_service":orbital_equipment_evidence.duplicate(true),"atmospheric_shielding_from_real_service":true,"independent_dock_fixture":dock_fixture_evidence,"renderer":RenderingServer.get_current_rendering_method(),"display_server":DisplayServer.get_name(),"scope":"Actual production Main framebuffers: continuous inverse20km native-surface return; genuinely flown high descent; original F575 accepted park; production station-guidance modal in a separate explicitly placed80m source-station fixture after exact trial exit. Native flight uses real0.1s intervals and rendered checkpoints; shield is bought through actual equipment service. Real include-save diagnosticZIP fully cold-decodes returned descent. No camera/light/pose changes during flown native phases, no compositing, circularorbit, fullsourceautopilot, stationframecontinuity, universalterrain, physicalAndroid or FPS claim."},"\t"));file.close()
	game.queue_free();await process_frame;print("Native return captures: %d frames, %d checks, %d failures"%[captures.size(),checks,failures]);quit(1 if failures else 0)

func run()->void:
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires rendered display and private capture mode");quit(1);return
	for directory:String in ["res://scripts","res://scenes","res://data","res://assets","res://tests"]:hash_sources(directory)
	for path:String in ["project.godot","tools/capture_native_return.gd"]:input_hashes[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(OUTPUT);root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main failed to load");game.free();quit(1);return
	game.settings=CaptureSettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	check(game.automated and not game.saving_enabled,"The process starts without ordinary player progress")
	if not await orbital_park_fixture():await finish_capture();return
	game._close_menu()
	for index in range(3):
		if game.ship.external_view:break
		game._cycle_view()
	check(game.ship.external_view,"The actual retained view command selects the unchanged production chase camera")
	if not await fly_outbound():await finish_capture();return
	var days:float=game.nav.elapsed_days;var before_fuel:=fuel();var before_hp:=thermal();var before_gear:Dictionary=game.landing_gear.snapshot()
	check(game._begin_native_surface_return() and game._native_surface_active(),"The production command returns the actual flown space pose to its source chart")
	check(game.nav.elapsed_days==days and fuel()==before_fuel and thermal()==before_hp and game.landing_gear.snapshot()==before_gear,"The inverse frame boundary consumes no extra time/fuel/HP/gear interval")
	await photograph("01-native-surface-return-1440x720.png","surface_return","Actual Main inverse frame transfer at the genuinely flown20km departure pose. Current Float64 position, velocity and exact source time were preserved; no new50m entry or physical interval ran.")
	check(game._begin_native_return_landing() and pilot_active(),"The production Auto command arms actual high return descent without relocation")
	if await fly_descent(16000.0,1600):
		await photograph("02-native-return-descent-1440x720.png","high_descent","Actual protected native return descent with real control inputs, source fuel/time and stowed gear. The production camera and emitted native terrain are unchanged.")
		await actual_include_save_report()
		if await fly_descent(-1000000.0,6500,true):
			root.size=Vector2i(960,432)
			await photograph("03-native-return-park-960x432.png","accepted_park","The full genuinely flown twenty-kilometre return descent has reached an actual original F575 park with physically deployed gear; no ground-position snap was introduced by the guidance.")
			if await stage_dock_modal():await photograph("04-source-dock-guidance-960x432.png","dock_guidance","Actual Main docking guidance explains the genuine source-station capture requirements. The displayed80m position is an independent labelled fixture after exact ordinary-flight restoration, not a continuous native-trial-to-station transfer.",true)
	await finish_capture()
