extends "res://tests/test_source_contact_main.gd"
# Actual Main menu, report and old/new surface factories. Explicit v5 preview
# operands never opt ordinary gameplay into a new natural-contact response.
const AlignmentProbe=preload("res://scripts/source_contact_alignment_probe.gd")
const AlignmentBuild=preload("res://scripts/build_info.gd")
const AlignmentTerrain=preload("res://scripts/source_contact_surface_terrain.gd")
const AlignmentPacket=preload("res://scripts/source_surface_render_packet.gd")
const AlignmentState=preload("res://scripts/source_surface_render_state.gd")
const AlignmentLink=preload("res://scripts/surface_orbit_link.gd")
const ALIGNMENT_REPORT:="res://validation/alignment-2026-11-13/source-contact-alignment-main.json"
const ALIGNMENT_ACTION:="Проверить высоту поверхности"
const ALIGNMENT_KEY:="last_surface_alignment"
var alignment_evidence:Array=[]
var alignment_private:="user://alignment-main-"+str(OS.get_process_id())
var alignment_archive:=""

func alignment_live_state()->PackedByteArray:
	# Deliberately avoid Surface.snapshot(): saved-triangle capture is a separate
	# operation and is allowed to obtain ordinary provider samples.
	return var_to_bytes([game.ship.snapshot(),game.nav.snapshot(),game.world.snapshot(),game.landing_gear.snapshot(),game.source_motion.snapshot(),game.world.body_spin_by_id,game.world.native_evaluation_count,game.world._native_cache_tick,game.world._native_cache_day,game.world._native_positions_raw,game.world._native_relative_raw,game.surface.active,game.surface.landed,game.surface.landing,game.surface.taking_off,game.surface.flight_phase,game.surface.frame_index,game.surface.pending_source_contact()])
func alignment_action(text:String)->Button:
	for node in game.menu_rows.get_children():
		if node is Button and node.text==text:return node
	return null
func alignment_labels()->String:
	var parts:=PackedStringArray()
	for node in game.menu_rows.get_children():
		if node is Label:parts.append(node.text)
	return "\n".join(parts)
func initialize_alignment_diagnostics()->void:
	game.diagnostics.directory=alignment_private+"/diagnostics";game.diagnostics.reports_directory=alignment_private+"/reports";game.diagnostics.engine_logs_directory=alignment_private+"/engine"
	check(game.diagnostics.initialize(AlignmentBuild.VERSION),"Actual alignment diagnostics initialize only in private test directories")
func alignment_contract(value:Dictionary)->void:
	check(value.get("ok",false) and value.get("diagnostic_only")==true and value.get("response_applied")==false and value.get("live_collision_classifier_changed")==false,"The comparison is a completed read-only observation, not a new live contact policy")
	check(value.get("interpolated_points_certified")==false and game.diagnostics._json_safe(value),"Comparison facts retain finite strict JSON and make no arbitrary-triangle certification claim")
	if not value.get("ok",false):return
	check(is_finite(float(value.visible_height_m)) and is_finite(float(value.source_root_height_m)) and absf(float(value.delta_m)-(float(value.source_root_height_m)-float(value.visible_height_m)))<0.000001,"Both compared heights and their signed difference use one finite radial elevation reference")
	check(str(value.get("context_binding_sha256","")).length()==64 and value.get("query_context") is Dictionary,"The measurement contains its complete stable context binding")
	if not value.get("query_context") is Dictionary:return
	var context:Dictionary=value.query_context
	check(context.get("body_id")==game.surface.body_id and context.get("terrain_revision")==game.surface.globe.revision and context.get("frame_index")==game.surface.frame_index,"Measurement context identifies the actual current body, sampler revision and tangent frame")
	check(context.get("ship_position_local_m")==[game.ship.position.x,game.ship.position.y,game.ship.position.z] and str(context.get("source_record_sha256","")).length()==64,"Measurement is bound to the exact current observer and original source record")
	check(not value.has("body_after") and not value.has("damage_calls") and not value.has("landing_accepted"),"Comparison diagnostics expose no raw response buffers, damage request or landing verdict")

func actual_alignment_menu()->void:
	if not await stage_gear_surface(40):return
	check(game.surface.globe.revision==Terrain.REVISION_NAME and AlignmentLink.preferred_terrain_revision(game.world)==Terrain.REVISION_NAME,"Ordinary Main surface entry and preferred orbit link remain the existing v4 policy")
	game._show_menu();var button:=alignment_action(ALIGNMENT_ACTION)
	check(button!=null,"Actual commander menu exposes the surface-height comparison action")
	if button==null:return
	var scroll:ScrollContainer=game.menu_rows.get_parent();scroll.ensure_control_visible(button);await frame()
	var before:=alignment_live_state();var cache:Dictionary=game.surface.globe.cache_stats();var provider:RefCounted=game.surface.source_render_state;var owner:RefCounted=game.surface.globe
	await tap(button,291)
	var value:Dictionary=game.source_alignment_last.duplicate(true);alignment_contract(value)
	check(game.menu.visible and game.menu_title.text=="ПРОВЕРКА ПОВЕРХНОСТИ","Actual touch opens the production comparison page")
	check(alignment_live_state()==before and game.surface.globe==owner and game.surface.source_render_state==provider,"Opening the page preserves flight, HP/RNG, fuel, clock and physical provider identities")
	check(game.surface.globe.cache_stats()==cache,"The actual comparison page does not warm or alter the live terrain cache")
	var text:=alignment_labels()
	check(text.contains("Высота текущей поверхности:") and text.contains("Уточнённая высота:") and text.contains("Расхождение высот:"),"Production page displays all three measured values in Russian")
	check(alignment_action("Отчёт об ошибке / логи")!=null and alignment_action("Вернуться в меню")!=null,"Comparison page retains the real report and commander-menu actions")
	var expected:=AlignmentProbe.sample(game.surface,game.ship);expected["observed_elapsed_days"]=game.nav.elapsed_days
	check(value==expected,"Main stores exactly the pure current comparison plus its observed game time")
	for index in range(3):game._advance_controls(1.0);game._process(0)
	check(alignment_live_state()==before and game.source_alignment_last==value,"The open comparison page pauses simulation and cannot advance measured flight state")
	var sample:Dictionary=game._flight_diagnostic_sample()
	check(sample.get(ALIGNMENT_KEY)==value,"Actual flight diagnostics label the observation as the last surface comparison")
	game.busy=true;game._show_surface_alignment();game.busy=false
	check(game.source_alignment_last==value,"A busy command cannot overwrite the completed comparison")
	alignment_evidence.append({"case":"actual_v4_comparison_menu","measurement":value,"live_cache_unchanged":game.surface.globe.cache_stats()==cache,"default_surface_revision":Terrain.REVISION_NAME})

func last_measurement_and_cold_save()->void:
	var measurement:Dictionary=game.source_alignment_last.duplicate(true)
	game._close_menu();var saved:Dictionary=copied(payload());var hp:=thermal();var gear_before:=gear()
	check(saved.surface.terrain_revision==Terrain.REVISION_NAME and not saved.has(ALIGNMENT_KEY) and not saved.has("source_alignment_last"),"Existing v4 save schema does not acquire a persisted diagnostic state")
	check(load_fixture(saved,"Existing v4 source save after read-only comparison"),"Actual whole-game decoder cold-restores the old source policy")
	check(game.surface.globe.revision==Terrain.REVISION_NAME and thermal()==hp and gear()==gear_before and game.source_alignment_last.is_empty(),"Cold restore preserves old geometry, exact HP/gear and clears ephemeral measurements")
	game._show_surface_alignment();measurement=game.source_alignment_last.duplicate(true);var original_body:String=game.surface.body_id
	game._close_menu();stage_natural("mercury",5000,0);var before:=alignment_live_state();game._show_menu()
	check(not game.surface.active and alignment_action(ALIGNMENT_ACTION)==null,"Surface comparison action is absent outside an active source surface")
	game._show_surface_alignment()
	check(alignment_live_state()==before and game.source_alignment_last==measurement,"An ineligible space command cannot re-label or overwrite the prior measurement")
	var sample:Dictionary=game._flight_diagnostic_sample()
	check(sample.get(ALIGNMENT_KEY)==measurement and sample[ALIGNMENT_KEY].query_context.body_id==original_body and game.world.focus_id=="mercury","After a focus change the retained last measurement still identifies its original body rather than the current target")
	alignment_evidence.append({"case":"last_measurement_context_and_v4_cold_restore","original_body":original_body,"current_body":game.world.focus_id,"last_measurement":measurement,"diagnostic_state_persisted_in_save":false})

func graphics_demo_restores_gear_and_measurement()->void:
	if not await stage_gear_surface(40):return
	command_gear(true);check(game._step_landing_gear(0.75),"Actual gear scheduler prepares a partially extended mechanism before graphics preview")
	game._show_surface_alignment();var measurement:Dictionary=game.source_alignment_last.duplicate(true);game._close_menu()
	var old_gear:RefCounted=game.landing_gear;var gear_before:=gear();var objects:=identities();var before:=state();var hp:=thermal()
	game._begin_graphics_demo()
	check(not game.graphics_return.is_empty() and game.landing_gear!=old_gear and game.source_alignment_last.is_empty(),"Graphics preview owns a separate gear mechanism and ephemeral comparison state")
	game._request_landing_gear(false);game._step_landing_gear(1.0);game.source_alignment_last={"explicit_demo_fixture":true}
	game._end_graphics_demo()
	check(game.graphics_return.is_empty() and identities()==objects and game.landing_gear==old_gear,"Returning from preview restores all original model identities including the gear owner")
	check(gear()==gear_before and game.source_alignment_last==measurement and thermal()==hp and state()==before,"Graphics preview cannot lose the partially deployed gear, prior comparison, exact HP/fuel/clock or saved flight")
	alignment_evidence.append({"case":"graphics_preview_restores_original_gear_and_last_measurement","physical_gear_position_u16":gear_before.position_u16,"gear_identity_restored":game.landing_gear==old_gear,"measurement_context":measurement.get("context_binding_sha256","")})

func explicit_v5_surface_fixture(width:=128.0,cells:=4)->bool:
	if not await stage_gear_surface(40):return false
	var previous:RefCounted=game.surface.globe
	var globe:RefCounted=Surface.make_globe(game.world,game.surface.body_id,"",AlignmentTerrain.CONTACT_REVISION)
	check(globe!=null and globe.revision==AlignmentTerrain.CONTACT_REVISION,"Explicit v5 factory selects a distinct source-root sampler without changing ordinary entry")
	if globe==null:return false
	globe.latitude=previous.latitude;globe.longitude=previous.longitude
	var packet:Dictionary=AlignmentPacket.prepare(globe,{"kind":game.surface.kind if game.surface.kind in AlignmentPacket.KINDS else "rock","core_width":width,"core_cells":cells,"include_rings":false})
	var provider:=AlignmentState.new()
	check(packet.get("ok",false) and provider.configure(packet),"Explicit v5 preview uses an actual bounded worker packet and physical render state")
	if not packet.get("ok",false) or not provider.configured_ok:return false
	game.surface.globe=globe;game.surface.source_render_state=provider;game.surface.source_render_packet=packet;game.surface.source_render_worker_state=globe.capture_worker_state()
	game.surface._source_render_ship=game.ship;game.surface._source_system=game.world
	game.ship.position=Vector3(8,game.surface.height_at(8,8)+game.surface.clearance(game.ship)+40,8);game.ship.velocity=Vector3.ZERO;game.ship.attitude=Quaternion.IDENTITY
	game.surface.render_position=game.ship.position;game.surface.render_velocity=game.ship.velocity;game.surface._render_frame_shift=Vector3.ZERO
	game._apply_system();game._refresh_hud();game._update_flight_controls()
	check(game.surface.source_surface() and game.surface.globe.revision==AlignmentTerrain.CONTACT_REVISION,"Actual production Surface recognizes the explicitly prepared v5 preview")
	return true

func explicit_v5_factory_restore_and_lod()->void:
	if not await explicit_v5_surface_fixture(4000.0,64):return
	game._show_surface_alignment();var measured:Dictionary=game.source_alignment_last.duplicate(true);alignment_contract(measured);game._close_menu()
	var saved:Dictionary=copied(payload());var hp:=thermal();var position:Vector3=game.ship.position;var velocity:Vector3=game.ship.velocity;var attitude:Quaternion=game.ship.attitude
	check(saved.surface.terrain_revision==AlignmentTerrain.CONTACT_REVISION and saved.surface.has("terrain_contact"),"Explicit v5 whole-game save stamps its distinct revision and independently verifiable contact triangle")
	var restored:Dictionary=game._decode_state(saved)
	check(not restored.is_empty(),"Actual Main cold decoder accepts the explicit v5 factory and source-backed saved triangle")
	if restored.is_empty():return
	check(restored.surface.source_render_state!=null and restored.surface.source_render_state.get("validation_samples")==3,"The cold v5 decoder independently validates all three original saved source vertices")
	# Give this explicit preview its canonical4000/64 local core before
	# production display setup; no full v5 global field is built.
	var cold_packet:Dictionary=AlignmentPacket.prepare(restored.surface.globe,{"kind":"rock","core_width":4000.0,"core_cells":64,"include_rings":false})
	check(cold_packet.get("ok",false),"The restored preview receives an actual canonical4000/64 v5 render packet")
	if not cold_packet.get("ok",false):return
	restored.surface.source_render_packet=cold_packet;restored.surface.source_render_worker_state=restored.surface.globe.capture_worker_state()
	game._commit_state(restored);game._apply_system()
	check(game.surface.globe.revision==AlignmentTerrain.CONTACT_REVISION and game.surface.source_render_state!=null and thermal()==hp and game.source_alignment_last.is_empty(),"V5 cold restore retains the chosen geometry and exact shared HP without persisting old diagnostic facts")
	check(game.ship.position==position and game.ship.velocity==velocity and game.ship.attitude.is_equal_approx(attitude),"Explicit v5 cold restore preserves the observer pose without a gameplay-contact correction")
	var packet:Dictionary=AlignmentPacket.prepare(game.surface.globe,{"kind":"rock","core_width":256.0,"core_cells":2,"include_rings":false});var next:=AlignmentState.new()
	check(packet.get("ok",false) and next.configure(packet),"A second actual v5 LOD supplies a valid replacement render state")
	if packet.get("ok",false) and next.configured_ok:
		var before:=alignment_live_state();position=game.ship.position;velocity=game.ship.velocity;attitude=game.ship.attitude
		game.surface.publish_source_render_state(next)
		check(game.surface.source_render_state==next and game.ship.position==position and game.ship.velocity==velocity and game.ship.attitude==attitude,"Publishing v5 LOD changes geometry while keeping every observer pose component exact")
		check(alignment_live_state()==before and game.surface.consume_render_frame_shift()==Vector3.ZERO,"V5 publication emits no synthetic observer displacement, damage, fuel, clock or frame shift")
	check(AlignmentLink.preferred_terrain_revision(game.world)==Terrain.REVISION_NAME,"Explicit v5 restore and LOD cannot switch the ordinary preferred surface policy")
	alignment_evidence.append({"case":"explicit_v5_factory_cold_save_and_lod","measurement":measured,"terrain_revision":game.surface.globe.revision,"default_revision":AlignmentLink.preferred_terrain_revision(game.world),"native_live_response_enabled":false,"arbitrary_point_mesh_root_certified":false})

func read_alignment_archive(path:String)->Dictionary:
	var reader:=ZIPReader.new();check(reader.open(path)==OK,"Actual comparison report collector produces a readable ZIP")
	var files:Dictionary={}
	for name:String in reader.get_files():files[name]=reader.read_file(name)
	reader.close();check(files.has("report.json") and files.has("manifest.json"),"Actual report retains its report JSON and member manifest")
	if files.has("manifest.json"):
		var manifest:Dictionary=JSON.parse_string(files["manifest.json"].get_string_from_utf8())
		for row:Dictionary in manifest.files:
			var bytes:PackedByteArray=files.get(row.name,PackedByteArray());var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
			check(bytes.size()==int(row.bytes) and hash.finish().hex_encode()==str(row.sha256),"Collected comparison ZIP member matches its actual size and SHA: "+str(row.name))
	return files
func actual_alignment_logger_and_report()->void:
	if not game.surface.active or not game.surface.source_surface():
		if not await stage_gear_surface(40):return
	game.automated=false;game._show_surface_alignment();game.automated=true
	var measurement:Dictionary=game.source_alignment_last.duplicate(true);game._close_menu();game._process(0)
	# Ordinary HUD reads may increment live cache-hit counters. Warm those
	# existing views before checking that logging creates no new source nodes.
	game._refresh_hud();game._refresh_hud()
	var before:=alignment_live_state();var cache:Dictionary=game.surface.globe.cache_stats()
	game.automated=false;game.diagnostic_timer=0;game._process(2.01);game.automated=true
	check(game.last_flight_sample.get(ALIGNMENT_KEY)==measurement and alignment_live_state()==before,"Actual periodic Main logger retains the bound last comparison without advancing flight")
	game.report_draft="Проверка высоты поверхности: сравнение текущего рельефа с уточнённым расчётом.\nПросмотр не меняет полёт, корпус или топливо."
	game._show_bug_report();await game._create_bug_report(false)
	check(game.current_report.get("ok",false) and not game.busy,"Actual production report action collects the current comparison and logs")
	if not game.current_report.get("ok",false):return
	alignment_archive=str(game.current_report.path);var files:=read_alignment_archive(alignment_archive)
	if files.has("report.json"):
		var report:Dictionary=JSON.parse_string(files["report.json"].get_string_from_utf8())
		check(report.context.flight.get(ALIGNMENT_KEY)==copied(measurement) and report.context.last_flight_sample.get(ALIGNMENT_KEY)==copied(measurement),"Real report JSON includes both current diagnostic context and periodically recorded last comparison")
		check(not report.included_save and not files.has("game-save.json"),"Default comparison report excludes saved player progress")
	if files.has("events/current-events.jsonl"):
		var compared:=false;var periodic:=false;var truncated:=false
		for line:String in files["events/current-events.jsonl"].get_string_from_utf8().split("\n",false):
			var entry:Variant=JSON.parse_string(line)
			if not entry is Dictionary:continue
			if entry.get("kind")=="entry_truncated":truncated=true
			if entry.get("event")=="source_contact_alignment" and entry.get("details")==copied(measurement):compared=true
			if entry.get("event")=="flight_sample":
				var logged:Dictionary=entry.get("details",{});var compact:Dictionary=logged.get(ALIGNMENT_KEY,{})
				var bound:Dictionary=compact.get("query_context",{});var expected:Dictionary=measurement.query_context
				periodic=compact.get("compact_periodic_record")==true and compact.get("context_binding_sha256")==measurement.context_binding_sha256 and compact.get("delta_m")==copied(measurement.delta_m) and bound.get("parent_uid_u32")==expected.parent_uid_u32 and bound.get("body_id")==expected.body_id and bound.get("frame_index")==expected.frame_index and compact.get("observed_elapsed_days")==measurement.observed_elapsed_days and compact.get("diagnostic_only")==true and compact.get("response_applied")==false and logged.get("source_natural_probe")==copied(game.last_flight_sample.get("source_natural_probe")) and logged.get("source_spherical_probe")==copied(game.last_flight_sample.get("source_spherical_probe"))
		check(compared and periodic and not truncated,"Real log retains the full explicit comparison and a context-bound compact periodic record without losing existing natural/spherical diagnostics or truncating the line")
	var after_cache:Dictionary=game.surface.globe.cache_stats()
	check(alignment_live_state()==before and after_cache.get("source_samples")==cache.get("source_samples") and after_cache.get("entries")==cache.get("entries"),"Periodic sampling and real ZIP collection preserve flight and create no new source terrain nodes")
	alignment_evidence.append({"case":"actual_comparison_periodic_log_and_report_zip","measurement":measurement,"archive_filename":game.current_report.filename,"included_save":false,"live_response_enabled":false,"cache_before":cache,"cache_after":after_cache,"ordinary_HUD_cache_hit_counters_may_advance":true})

func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires private capture mode");quit(1);return
	root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main script failed to load");game.free();quit(1);return
	game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame();initialize_alignment_diagnostics()
	check(game.automated and not game.saving_enabled,"Alignment Main tests never read or write ordinary player progress")
	await actual_alignment_menu();last_measurement_and_cold_save();await graphics_demo_restores_gear_and_measurement();await explicit_v5_factory_restore_and_lod();await actual_alignment_logger_and_report()
	var sources:Dictionary={}
	for path:String in ["scripts/main.gd","scripts/surface_model.gd","scripts/surface_orbit_link.gd","scripts/source_contact_alignment_probe.gd","scripts/source_contact_surface_terrain.gd","scripts/source_terrain_contact_field.gd","scripts/source_surface_render_packet.gd","scripts/source_surface_render_state.gd","scripts/source_surface_contact_patch.gd","scripts/source_surface_terrain.gd","scripts/game_diagnostics.gd","scripts/diagnostics_logger.gd","scripts/build_info.gd","tests/test_source_contact_alignment_main.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ALIGNMENT_REPORT.get_base_dir()));var file:=FileAccess.open(ALIGNMENT_REPORT,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"evidence":alignment_evidence,"sources":sources,"scope":"Actual Main Russian comparison action and pause, source-record/context-bound last measurement, exact live HP/RNG/fuel/clock/cache isolation, periodic log and production ZIP, old v4 cold save, graphics-preview gear-owner preservation, explicit v5 factory/cold saved triangle/LOD observer invariance. V4 remains default; no live F576 switch, arbitrary-point mesh certification, physical Android or full source object-bank parity."},"\t"));file.close()
	game.queue_free();await frame();print("Source contact alignment Main: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
