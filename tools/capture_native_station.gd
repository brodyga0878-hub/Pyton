extends "res://tests/test_native_station_main.gd"
# Actual Main framebuffers. The source20km outbound is genuinely flown. The
# later placement outside the real station approach waypoint is an explicit
# starting fixture; the many-megametre planetary transit is not claimed.
const CaptureBuild=preload("res://scripts/build_info.gd")
const OUTPUT:="res://validation/native-station-2026-11-16/screenshots"
const REPORT_NAME:="sample-native-station-include-save-report.zip"
const CAPTURE_SECONDS:=0.1
const RUNTIME_FREEZE:="res://validation/native-station-2026-11-16/runtime-freeze.json"
const CAPTURE_RUNTIME_PINS:="res://build/native-station-capture-runtime-pins.json"
class CaptureSettings extends MemorySettings:
	func load_file()->bool:quality=2;return false
var captures:Array=[]
var capture_errors:Array=[]
var input_hashes:Dictionary={}
var archive_evidence:Dictionary={}
var flown_phases:Array=[]
var fixture_evidence:Dictionary={}
var service_evidence:Dictionary={}
var station_candidates:Array=[]
var outward_boundary:Dictionary={}
var reverse_boundary:Dictionary={}
var runtime_pin_input:=""
var runtime_pin_inventory_sha256:=""
var runtime_pin_is_final_proof:=false

func check(ok:bool,label:String)->void:
	super.check(ok,label)
	if not ok:capture_errors.append(label)

func frame()->void:
	if is_instance_valid(game):game._process(1.0/60.0)
	await process_frame;await RenderingServer.frame_post_draw

func hash_test_sources(directory:String)->void:
	for name:String in DirAccess.get_files_at(directory):
		if name.ends_with(".pyc") or name.ends_with(".pyo"):continue
		var path:=directory.path_join(name);input_hashes[path.trim_prefix("res://")]=FileAccess.get_sha256(path)
	for name:String in DirAccess.get_directories_at(directory):
		if not name.begins_with(".") and name!="__pycache__":hash_test_sources(directory.path_join(name))

func hash_capture_inputs()->bool:
	runtime_pin_is_final_proof=FileAccess.file_exists(RUNTIME_FREEZE)
	runtime_pin_input=RUNTIME_FREEZE if runtime_pin_is_final_proof else CAPTURE_RUNTIME_PINS
	if not FileAccess.file_exists(runtime_pin_input):check(false,"Capture requires the explicit frozen runtime input map");return false
	runtime_pin_inventory_sha256=FileAccess.get_sha256(runtime_pin_input)
	var freeze:Variant=JSON.parse_string(FileAccess.get_file_as_string(runtime_pin_input))
	if not freeze is Dictionary or not freeze.get("files_sha256") is Dictionary:check(false,"Capture requires the typed frozen runtime inventory");return false
	check(freeze.files_sha256.size()==475 and int(freeze.get("version_code",-1))==53,"All475 actual code53 runtime inputs are pinned before capture")
	for path:String in freeze.files_sha256:
		var digest:=FileAccess.get_sha256("res://"+path)
		check(digest==str(freeze.files_sha256[path]),"Capture uses the final frozen runtime input: "+path)
		input_hashes[path]=digest
	hash_test_sources("res://tests")
	for path:String in ["tools/capture_native_station.gd","tools/capture_native_station.gd.uid"]:input_hashes[path]=FileAccess.get_sha256("res://"+path)
	return capture_errors.is_empty()

func capture_state()->PackedByteArray:
	var station:RefCounted=station_session();var orbital:RefCounted=game.get("native_orbit_trial")
	return var_to_bytes([game.ship.snapshot(),game.nav.snapshot(),game.world.snapshot(),game.surface.snapshot(),game.landing_gear.snapshot(),pilot_state(),station.snapshot(game.ship,game.nav,game.world,game.landing_gear) if station!=null and station.is_active() else {},orbital.snapshot(game.ship,game.nav,game.world,game.landing_gear) if orbital!=null and orbital.is_active() else {},game.source_motion.snapshot()])

func finite_scene()->bool:
	return game.ship.position.is_finite() and game.ship.velocity.is_finite() and game.ship.attitude.is_finite() and game.camera.position.is_finite() and game.camera.quaternion.is_finite() and game.source_contact_error.is_empty() and game._native_trial_active() and not payload().is_empty()

func camera_precision_bound(expected:Vector3)->float:
	var squared:=0.0
	for component:float in [expected.x,expected.y,expected.z]:
		var raw:=PackedByteArray();raw.resize(4);raw.encode_float(0,component)
		var exponent:=(raw.decode_u32(0)>>23)&255
		var width:=pow(2.0,exponent-150.0) if exponent>0 else pow(2.0,-149.0)
		squared+=width*width
	return maxf(0.5,sqrt(squared))

func photograph(filename:String,phase:String,scope:String,screen:String="flight")->bool:
	var immutable:=capture_state()
	game._safe_area();game._refresh_hud();game._update_flight_controls()
	for index in range(12):await frame()
	check(capture_state()==immutable,"Rendering and HUD refresh leave all actual physical owners unchanged: "+phase)
	check(finite_scene(),"The displayed production trial is finite and cold-save eligible: "+phase)
	if not finite_scene():return false
	var expected:Dictionary=game.instruments.camera_pose(game.ship.position,game.ship.attitude,game.ship.external_view,float(game.ship.profile().visual_span_m))
	var camera_error:float=game.camera.position.distance_to(expected.position);var camera_bound:=camera_precision_bound(expected.position)
	check(camera_error<=camera_bound,"The unchanged production camera follows the actual ship within its Float32 bound: "+phase)
	var bounds:=root.get_visible_rect()
	check(game.automated and not game.saving_enabled and not game.native_trial_return.is_empty(),"The capture owns a separate trial and preserves ordinary player progress")
	if screen=="flight":
		check(not game.menu.visible and game.flight_console.visible and bounds.encloses(game.flight_console.get_global_rect()),"The retained original-style lower console fits the actual framebuffer: "+phase)
		check(game.ship.external_view and game.player.visible and game.camera.is_position_in_frustum(game.player.global_position),"The real ship is visible through its actual production chase camera: "+phase)
	else:
		check(game.menu.visible and bounds.encloses(game.menu.get_global_rect()),"The actual production menu fits the requested phone framebuffer: "+phase)
	var screenshot:=root.get_texture().get_image()
	check(screenshot!=null and screenshot.get_width()==root.size.x and screenshot.get_height()==root.size.y,"The actual root framebuffer has the requested dimensions")
	if screenshot==null:return false
	check(screenshot.save_png(OUTPUT.path_join(filename))==OK,"The actual framebuffer is saved: "+filename)
	check(capture_state()==immutable,"Photographing spends no physical interval, fuel, HP, gear or source clock")
	captures.append({"file":filename,"sha256":FileAccess.get_sha256(OUTPUT.path_join(filename)),"phase":phase,"screen":screen,"scope":scope,"viewport":[root.size.x,root.size.y],"scene":"scenes/main.tscn","native_state":game._native_trial_diagnostic(),"station_flight":station_facts() if station_active() else {},"source_contact":game.source_contact_last.duplicate(true),"ship_position_m":[game.ship.position.x,game.ship.position.y,game.ship.position.z],"ship_velocity_mps":[game.ship.velocity.x,game.ship.velocity.y,game.ship.velocity.z],"camera_position_m":[game.camera.position.x,game.camera.position.y,game.camera.position.z],"camera_attitude_xyzw":[game.camera.quaternion.x,game.camera.quaternion.y,game.camera.quaternion.z,game.camera.quaternion.w],"camera_expected_position_m":[expected.position.x,expected.position.y,expected.position.z],"camera_residual_m":camera_error,"camera_float32_bound_m":camera_bound,"hull_percent":game.ship.hull,"atmospheric_shielding_installed":bool(fuel().atmospheric_shielding_installed),"menu_title":game.menu_title.text if game.menu.visible else "","composited":false,"physical_android_capture":false,"performance_benchmark":false,"planet_to_station_transit_flown":false,"circular_orbit_claim":false,"full_original_frame_bank_claim":false})
	return true

func clock_hex(value:float)->String:return NativeSurfaceModel._native_floats([value],8)

func record_phase(name:String,intervals:int,before_days:float,before_fuel:Dictionary,completed:bool)->void:
	flown_phases.append({"phase":name,"accepted_command_intervals":intervals,"seconds_per_interval":CAPTURE_SECONDS,"days_before_f64_hex":clock_hex(before_days),"days_after_f64_hex":clock_hex(game.nav.elapsed_days),"completed":completed,"hull_percent":game.ship.hull,"fuel_before":before_fuel,"fuel_after":fuel(),"source_contact_error":game.source_contact_error})

func fly_outbound()->bool:
	var before_days:float=game.nav.elapsed_days;var before_fuel:=fuel();var intervals:=0;var clock_once:=true
	check(game._begin_native_orbital_departure(),"The production departure requests a genuine source20km powered climb")
	for index in range(9000):
		if game._native_orbit_active() or not pilot_active():break
		var day:float=game.nav.elapsed_days;game._tick(CAPTURE_SECONDS,Vector2.ZERO,0);intervals=index+1
		clock_once=clock_once and game.nav.elapsed_days==day+CAPTURE_SECONDS/86400.0
		if index%32==31:await frame()
		if not game.source_contact_error.is_empty() or game.ship.hull<=0:break
	var complete:bool=game._native_orbit_active() and game.source_contact_error.is_empty()
	check(complete and clock_once and game.nav.elapsed_days>before_days and fuel()!=before_fuel and game.ship.hull==100,"The actual powered outbound reaches its guarded space phase with one real clock/fuel interval per step")
	ordinary_unchanged("Captured genuine source outbound")
	record_phase("protected_20km_outbound",intervals,before_days,before_fuel,complete)
	return complete

func collect_candidates()->void:
	var frame_module:Script=load("res://scripts/native_station_frame.gd");var orbit_module:Script=load("res://scripts/native_orbit_trial.gd")
	for site:Dictionary in game.world.settlements:
		if str(site.parent)!=str(game.world.focus_id) or int(site.type_code) not in [32,33,34]:continue
		var target_world:RefCounted=orbit_module._fork_world(game.world);target_world.site_id=str(site.id)
		var shift:Dictionary=frame_module.offset(game.world,target_world,game.nav.elapsed_days)
		if not shift.get("ok",false):continue
		var distance_sq:=0.0
		for axis in range(3):distance_sq+=pow(game.native_orbit_trial._position_f64[axis]+shift.position_delta_f64[axis]-float(game.ship.STATION[axis]),2)
		station_candidates.append({"site_id":str(site.id),"name_ru":str(site.name),"parent_id":str(site.parent),"record_hex":str(site.runtime_record_hex),"distance_m":sqrt(distance_sq),"source_model_index":int(site.model_index)})

func capture_station_steps(count:int,expect_dock:bool=false)->bool:
	var before_days:float=game.nav.elapsed_days;var before_fuel:=fuel();var intervals:=0;var clock_once:=true;var measured_spin:=false
	for index in range(count):
		if not station_active() or game.ship.docked and expect_dock or not game.source_contact_error.is_empty():break
		var day:float=game.nav.elapsed_days;game._tick(CAPTURE_SECONDS,Vector2.ZERO,0);intervals=index+1
		clock_once=clock_once and game.nav.elapsed_days==day+CAPTURE_SECONDS/86400.0
		measured_spin=measured_spin or game.ship._source_angular_velocity.length()>0.000001
		if index%32==31:await frame()
		if game.ship.hull!=100:break
	var complete:bool=station_active() and game.source_contact_error.is_empty() and game.ship.hull==100 and (game.ship.docked if expect_dock else intervals==count)
	check(complete and clock_once and measured_spin,"Actual source station intervals retain real measured spin, healthy hull and exact single clock: "+str(expect_dock))
	check(game.nav.elapsed_days>before_days and fuel()!=before_fuel,"The flown station segment consumes the actual source time and propulsion")
	ordinary_unchanged("Captured source station flight")
	record_phase("healthy_source_dock" if expect_dock else "active_source_station_approach",intervals,before_days,before_fuel,complete)
	return complete

func actual_include_save_report()->bool:
	game.diagnostics.directory=trial_directory+"/capture-diagnostics";game.diagnostics.reports_directory=trial_directory+"/capture-reports";game.diagnostics.engine_logs_directory=trial_directory+"/capture-engine"
	check(game.diagnostics.initialize(CaptureBuild.VERSION),"Actual production diagnostics initializes private capture directories")
	var before:=capture_state();var saved:Dictionary=copied(payload())
	check(saved.has("native_station_session") and not saved.has("native_orbit_session") and not saved.has("motion_session"),"The production payload contains the complete single source-station trial owner")
	game.report_include_save=true;game.report_draft="Полёт у исходной станции: полный снимок активного захода, вращения и двери, точной позы, шасси, корпуса, топлива и времени. Дальний перелёт от планеты не выполнялся: начальная постановка у исходной точки захода — явная фикстура."
	game._show_bug_report();await game._create_bug_report(false)
	check(game.current_report.get("ok",false),"The actual report command creates a full station-trial include-save ZIP")
	if not game.current_report.get("ok",false):return false
	var reader:=ZIPReader.new();var path:=str(game.current_report.path)
	check(reader.open(path)==OK,"The actual station-trial ZIP opens")
	if not reader.file_exists("report.json") or not reader.file_exists("game-save.json") or not reader.file_exists("manifest.json"):reader.close();check(false,"Actual ZIP contains report, complete save and checksum manifest");return false
	var report:Dictionary=JSON.parse_string(reader.read_file("report.json").get_string_from_utf8());var raw:=reader.read_file("game-save.json").get_string_from_utf8();var saved_zip:Dictionary=JSON.parse_string(raw);var manifest:Dictionary=JSON.parse_string(reader.read_file("manifest.json").get_string_from_utf8())
	check(report.included_save and saved_zip==saved and saved_zip.native_station_session.motion.autopilot and not raw.contains("[depth limit]") and not raw.contains("[unsupported value]"),"Production ZIP retains the exact complete active source station save with no truncation")
	check(not game._decode_state(saved_zip).is_empty(),"The production cold factory accepts the exact save extracted from the actual ZIP")
	for entry:Dictionary in manifest.files:
		var data:=reader.read_file(str(entry.name));var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(data)
		check(data.size()==int(entry.bytes) and digest.finish().hex_encode()==str(entry.sha256),"Every actual report member matches its production checksum: "+str(entry.name))
	reader.close();var bytes:=FileAccess.get_file_as_bytes(path);var copy_path:=OUTPUT.get_base_dir().path_join(REPORT_NAME);var file:=FileAccess.open(copy_path,FileAccess.WRITE)
	if file==null:check(false,"Retained source station report copy opens");return false
	file.store_buffer(bytes);file.close();check(FileAccess.get_file_as_bytes(copy_path)==bytes,"Retained report is byte-for-byte the actual production ZIP")
	archive_evidence={"file":copy_path.trim_prefix("res://"),"sha256":FileAccess.get_sha256(copy_path),"bytes":bytes.size(),"included_save":true,"full_native_station_session":true,"full_source_angular_history":true,"active_station_autopilot":true,"whole_game_cold_decoder_accepted":true,"manifest_files":manifest.files,"production_filename":game.current_report.filename}
	check(capture_state()==before,"Production reporting and cold validation leave all physical trial owners unchanged")
	game._close_menu();return true

func actual_paid_services()->bool:
	game._show_services(false);await frame()
	check(game.menu.visible and game.hyperdrive_services_view!=null and game.ship.docked,"The legitimately docked trial exposes actual production station services")
	if not game.ship.docked or game.hyperdrive_services_view==null:return false
	var before_days:float=game.nav.elapsed_days;var before_hp:=thermal();var credits:int=game.ship.credits;var hydrogen:int=int(game.nav.snapshot().source_hyperdrive.hydrogen)
	var button:Button=game.hyperdrive_services_view.buttons.get("refuel:hydrogen",null)
	check(button!=null and not button.disabled,"The actual station quotes a real available hydrogen purchase")
	if button==null or button.disabled:return false
	var scroll:ScrollContainer=game.menu_rows.get_parent();scroll.ensure_control_visible(button);await frame();await tap(button,992)
	check(int(game.nav.snapshot().source_hyperdrive.hydrogen)==hydrogen+1 and game.ship.credits<credits,"A routed real service touch adds one tonne of hydrogen and charges station credits")
	var after_refuel_credits:int=game.ship.credits;button=game.hyperdrive_services_view.buttons.get("remove_fuel_equipment:atmospheric_shielding",null)
	check(button!=null and not button.disabled,"The actual source equipment page offers removal of the purchased atmospheric protection")
	if button==null or button.disabled:return false
	scroll.ensure_control_visible(button);await frame();await tap(button,993)
	check(not bool(fuel().atmospheric_shielding_installed) and game.ship.credits>after_refuel_credits,"Actual source equipment removal applies its real quoted refund")
	var reinstall_credits:int=game.ship.credits;button=game.hyperdrive_services_view.buttons.get("install_fuel_equipment:atmospheric_shielding",null)
	check(button!=null and not button.disabled,"The real source equipment page quotes reinstalling atmospheric protection")
	if button==null or button.disabled:return false
	scroll.ensure_control_visible(button);await frame();await tap(button,994)
	check(bool(fuel().atmospheric_shielding_installed) and game.ship.credits==reinstall_credits-100,"The actual routed reinstall spends100credits and restores real source protection")
	check(game.nav.elapsed_days==before_days and thermal()==before_hp and game.ship.docked and station_active(),"Real paid services preserve the physical dock, clock and raw HP/RNG without a flight interval")
	service_evidence={"actual_routed_UI_transactions":true,"hydrogen_before":hydrogen,"hydrogen_after":int(game.nav.snapshot().source_hyperdrive.hydrogen),"credits_before":credits,"credits_after_refuel":after_refuel_credits,"credits_before_reinstall":reinstall_credits,"credits_after":game.ship.credits,"shield_reinstall_cost":100,"atmospheric_shielding_installed":bool(fuel().atmospheric_shielding_installed),"clock_advanced":false,"hull_or_heat_patched":false}
	scroll.scroll_vertical=0;await frame();return true

func actual_departure_and_reverse()->bool:
	game._close_menu();var days:float=game.nav.elapsed_days;var before_fuel:=fuel();var before_hp:=thermal();var before_pose:Vector3=game.ship.position
	game._dock_action()
	check(game.ship.position==before_pose and game.nav.elapsed_days==days and fuel()==before_fuel and thermal()==before_hp,"The real source launch request spends no physical interval or external relocation")
	var clock_once:=true;var intervals:=0
	for index in range(400):
		var day:float=game.nav.elapsed_days;game._tick(CAPTURE_SECONDS,Vector2.ZERO,0);intervals=index+1
		clock_once=clock_once and game.nav.elapsed_days==day+CAPTURE_SECONDS/86400.0
		if index%32==31:await frame()
		if not game.source_contact_error.is_empty() or game.ship.hull!=100:break
	var local:Vector3=game.ship._source_basis.transposed()*(game.ship.position-game.ship.STATION)
	var departed:bool=station_active() and not game.ship.docked and local.z>250 and game.ship.hull==100 and game.source_contact_error.is_empty()
	check(departed and clock_once,"Actual source departure flies out of the rotating station with healthy hull and exact time")
	record_phase("physical_source_departure",intervals,days,before_fuel,departed)
	if not departed:return false
	days=game.nav.elapsed_days;before_fuel=fuel();before_hp=thermal();var before_gear:Dictionary=game.landing_gear.snapshot()
	var prepared:Dictionary=station_session().prepare_reverse(game.ship,game.nav,game.landing_gear,game.world)
	check(prepared.get("ok",false),"The departed ship prepares a same-time return to the original body frame")
	if not prepared.get("ok",false):return false
	check(game._begin_native_station_reverse() and game._native_orbit_active() and not station_active(),"Actual Main publishes the reverse source-frame boundary after real departure")
	check(game.ship.position==prepared.candidate_ship.position and game.ship.velocity==prepared.candidate_ship.velocity and game.ship.attitude==prepared.candidate_ship.attitude,"Reverse Main pose equals the actual current-origin/velocity transform")
	check(game.nav.elapsed_days==days and fuel()==before_fuel and thermal()==before_hp and game.landing_gear.snapshot()==before_gear,"Reverse frame mapping adds no HP/RNG, fuel, gear or clock interval")
	check(not payload().is_empty() and not game._decode_state(copied(payload())).is_empty(),"The reverse body-frame trial remains cold-loadable with its original native lineage")
	reverse_boundary=prepared.receipt.duplicate(true);reverse_boundary.physical_departure_axis_m=local.z
	ordinary_unchanged("Captured connected station departure and reverse")
	return true

func finish_capture()->void:
	for path:String in input_hashes:check(FileAccess.get_sha256("res://"+path)==input_hashes[path],"Capture input remained byte-exact: "+path)
	check(captures.size()==4 and not archive_evidence.is_empty() and not fixture_evidence.is_empty() and not service_evidence.is_empty() and not reverse_boundary.is_empty(),"Four genuine connected station frames, real services, source boundaries and full report ZIP are retained")
	var file:=FileAccess.open(OUTPUT.path_join("capture-manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"version":CaptureBuild.VERSION,"checks":checks,"failures":capture_errors,"completed_utc":Time.get_datetime_string_from_system(true),"source_sha256":input_hashes,"runtime_pin_input":runtime_pin_input.trim_prefix("res://"),"runtime_pin_inventory_sha256":runtime_pin_inventory_sha256,"runtime_pin_is_final_suite_proof":runtime_pin_is_final_proof,"runtime_pinned_files":475,"frames":captures,"archive":archive_evidence,"flown_phases":flown_phases,"equipment_service":orbital_equipment_evidence.duplicate(true),"atmospheric_shielding_from_real_service":true,"station_candidates":station_candidates,"near_station_fixture":fixture_evidence,"paid_services":service_evidence,"handoff":outward_boundary,"reverse":reverse_boundary,"renderer":RenderingServer.get_current_rendering_method(),"display_server":DisplayServer.get_name(),"scope":"Actual production Main framebuffers: genuinely flown source20km outbound with real distant-Earth-station selection; explicitly labelled source approach-waypoint fixture followed by continuous nearstation frame mapping; actual original rotating approach/door/CCD/dock; routed paid source services; real departure and reverse body-frame mapping. Every flown capture interval is0.1s with rendered checkpoints. The many-megametre planet-to-station transit is not flown. Full include-save ZIP retains the actual source station owner/angular history and cold-decodes. No compositing, camera/light/physics overrides, full F570/F606/F597, circular orbit, physical Android or FPS proof."},"\t"));file.close()
	game.queue_free();await process_frame;print("Native station captures: %d frames, %d checks, %d failures"%[captures.size(),checks,failures]);quit(1 if failures else 0)

func run()->void:
	if DisplayServer.get_name()=="headless" or not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires rendered display and private capture mode");quit(1);return
	if not hash_capture_inputs():quit(1);return
	DirAccess.make_dir_recursive_absolute(OUTPUT);root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main failed to load");game.free();quit(1);return
	game.settings=CaptureSettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	check(game.automated and not game.saving_enabled,"Capture starts with private automated owners and no ordinary player save writes")
	if not await orbital_park_fixture():await finish_capture();return
	game._close_menu()
	for index in range(3):
		if game.ship.external_view:break
		game._cycle_view()
	check(game.ship.external_view,"The retained real view command selects the unchanged production chase camera")
	if not await fly_outbound():await finish_capture();return
	collect_candidates();check(station_candidates.size()==3,"The actual source Earth has three original orbital station records")
	var before:=capture_state();var port:=current_earth_station()
	check(not port.is_empty() and not game._begin_native_station_approach(str(port.id)) and capture_state()==before,"The genuine source20km flight rejects its physically distant station without relocation")
	game._show_native_station_selection()
	await photograph("01-earth-station-selection-1440x720.png","station_selection","Actual Main after genuine source20km ascent lists the original Earth stations and their real many-megametre distances. No station transit or near placement has yet occurred.","station_selection")
	game._close_menu()
	if not labelled_near_station_fixture(true):await finish_capture();return
	check(game._begin_native_station_approach(str(station_fixture_port.id)) and station_active(),"The explicit original-approach-waypoint fixture enters actual connected source station flight")
	if not station_active():await finish_capture();return
	var local:Vector3=game.ship._source_basis.transposed()*(game.ship.position-game.ship.STATION)
	fixture_evidence={"explicit_near_station_fixture":true,"placement_is_fixture_not_flown":true,"planet_to_station_journey_flown":false,"outbound_original_lineage_retained":true,"site_id":str(station_fixture_port.id),"parent_id":str(station_fixture_port.parent),"source_model_index":int(station_fixture_port.model_index),"source_approach_waypoint_m":[game.ship._source_station.approach_waypoint.x,game.ship._source_station.approach_waypoint.y,game.ship._source_station.approach_waypoint.z],"actual_station_local_position_m":[local.x,local.y,local.z],"distance_to_station_m":game.ship.position.distance_to(game.ship.STATION),"closed_door_is_explicit_fixture":true,"no_game_pose_patch_after_station_handoff":true}
	outward_boundary=game.source_contact_last.get("receipt",{}).duplicate(true)
	check(game._native_station_command("auto") and game.ship.autopilot,"The actual source Auto command requests opening and starts the existing station guidance")
	if not await capture_station_steps(8):await finish_capture();return
	await photograph("02-native-station-approach-1440x720.png","station_approach","Actual Main source station phase after a continuous same-time frame transfer from the explicit original-approach-waypoint fixture. The real existing Auto has begun its rotating approach and door scheduling; the long planetary transit is not claimed.")
	if not await actual_include_save_report():await finish_capture();return
	if not await capture_station_steps(9000,true):await finish_capture();return
	root.size=Vector2i(960,432)
	if not await actual_paid_services():await finish_capture();return
	await photograph("03-native-station-services-960x432.png","station_services","Actual healthy source dock reached by original rotating Auto/door/CCD, followed by real routed paid hydrogen and equipment transactions in the same saved native trial.","station_services")
	if not await actual_departure_and_reverse():await finish_capture();return
	await photograph("04-native-station-reverse-960x432.png","body_frame_return","Actual source departure has flown out of the station, then the current physical pose and velocity were transformed back to the retained body frame without another interval. The ship is still near the station's real orbit; this is not a planetary return flight.")
	leave_auto_fixture("Captured connected source station cycle")
	check(not station_active() and not game._native_trial_active(),"Exact ordinary progress restoration clears every station/orbit trial owner")
	await finish_capture()
