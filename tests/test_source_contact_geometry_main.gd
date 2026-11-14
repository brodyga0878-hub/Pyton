extends "res://tests/test_source_natural_footprint_main.gd"
const GeometryProbe=preload("res://scripts/source_contact_geometry_probe.gd")
const GeometryView=preload("res://scripts/native_contact_geometry_view.gd")
const GEOMETRY_ACTION:="Исходная геометрия контакта"
const GEOMETRY_KEY:="last_contact_geometry"
const GEOMETRY_MAIN_REPORT:="res://build/current-test-reports/source-contact-geometry-main.json"
var geometry_main_evidence:Array=[]
var geometry_archive:=""
func geometry_view()->Control:
	for node:Node in game.menu_rows.get_children():
		if node.get_script()==GeometryView:return node
	return null
func geometry_contract(value:Dictionary)->void:
	check(value.get("ok",false) and value.get("diagnostic_only")==true and value.get("response_applied")==false and value.get("live_response_enabled")==false,"The actual geometry page stores a completed copied observation without live response")
	check(value.get("ordinary_surface_replaced")==false and value.get("whole_mesh_certified")==false and value.get("original_F575_dispatch_executed")==false,"The inspector does not certify or replace ordinary terrain and cannot apply F575")
	check(game.diagnostics._json_safe(value) and str(value.get("context_binding_sha256","")).length()==64,"Geometry observations retain finite JSON and exact source/phone binding")
	if not value.get("ok",false):return
	check(int(value.geometry_packet_count)>0 and int(value.visited_volume_count)==value.volumes.size() and value.source_query_count_matches,"Actual default v4 source flight yields the bound native query prefix and projected leaf packets")
	for row:Dictionary in value.volumes:
		if row.geometry_ok:check(row.certificate.ok and row.certificate.original_integer_intersection_replayed and row.certificate.render_projection_verified and not row.certificate.source_geometry_identity_verified,"Actual native leaf certificates retain their declared projection scope")

func actual_geometry_menu()->void:
	if not await stage_gear_surface(40):return
	game._show_menu();var action:=alignment_action(GEOMETRY_ACTION)
	check(action!=null,"The real commander menu exposes native contact geometry inspection")
	if action==null:return
	var scroll:ScrollContainer=game.menu_rows.get_parent();await frame();scroll.ensure_control_visible(action);await frame()
	check(scroll.get_global_rect().encloses(action.get_global_rect()),"The geometry action has a completed visible scroll layout before a real tap")
	var before:=alignment_live_state();var cache:Dictionary=game.surface.globe.cache_stats();var provider:RefCounted=game.surface.source_render_state
	var camera_state:=var_to_bytes([game.camera.position,game.camera.quaternion,game.camera.fov,game.camera.get_world_3d()])
	await tap(action,361)
	var observation:Dictionary=game.source_geometry_last.duplicate(true);geometry_contract(observation)
	check(game.menu.visible and game.menu_title.text=="ИСХОДНАЯ ГЕОМЕТРИЯ КОНТАКТА","A phone tap opens the real Russian geometry page")
	check(alignment_live_state()==before and game.surface.source_render_state==provider and game.surface.globe.cache_stats()==cache,"The actual geometry page preserves HP/RNG, fuel, clock, pose, gear, live terrain/cache and provider ownership")
	var view:=geometry_view();check(view!=null,"The production page embeds the isolated native-leaf viewer")
	if view!=null:
		check(view.plot.size.y>=200,"The actual landscape menu gives source geometry a readable inspection area")
		check(view.triangle_count==int(observation.geometry_packet_count) and view.viewport.world_3d!=game.camera.get_world_3d(),"Actual packet count renders in a separate World3D from flight")
		var yaw:float=view.view_state().yaw;scroll.ensure_control_visible(view.buttons.right);await frame();await tap(view.buttons.right,362)
		check(float(view.view_state().yaw)!=yaw and game.source_geometry_last==observation,"A real rotation button changes only the copied viewer state")
		check(var_to_bytes([game.camera.position,game.camera.quaternion,game.camera.fov,game.camera.get_world_3d()])==camera_state and alignment_live_state()==before,"Rotating source geometry leaves the real flight camera and simulation exact")
	for index in range(3):game._advance_controls(1.0);game._process(0)
	check(alignment_live_state()==before and game.source_geometry_last==observation,"The open inspection page pauses flight while the independent preview stays usable")
	var expected:=GeometryProbe.sample(game.surface,game.ship,int(gear().position_u16),{"initial_globals":FootprintNatural._globals({}),"history_policy":"isolated-diagnostic-initial-state"});expected["observed_elapsed_days"]=game.nav.elapsed_days
	check(observation==expected,"Main stores exactly the independently rebuilt geometry observation and game time")
	game.busy=true;game._show_contact_geometry();game.busy=false
	check(game.source_geometry_last==observation,"A busy command cannot relabel or replace the observed geometry")
	check(alignment_action("Отчёт об ошибке / логи")!=null and alignment_action("Вернуться в меню")!=null,"The actual geometry page retains offline report and commander-menu routes")
	geometry_main_evidence.append({"case":"actual_default_surface_touch_and_isolated_3d_view","observation":observation,"source_cache_unchanged":true,"flight_camera_unchanged":true})

func geometry_lifetime()->void:
	game._close_menu();await frame();var save:Dictionary=copied(payload());var hp:=thermal();var mechanism:=gear()
	check(not save.has(GEOMETRY_KEY) and not save.has("source_geometry_last"),"Native geometry observations add no persisted flight schema")
	check(load_fixture(save,"Existing v4 source save after geometry inspection"),"Ordinary cold restore accepts the old surface policy")
	check(game.source_geometry_last.is_empty() and thermal()==hp and gear()==mechanism,"Cold restore clears ephemeral geometry while preserving exact HP and gear")
	game._show_contact_geometry();var observation:Dictionary=game.source_geometry_last.duplicate(true);game._close_menu();await frame();var before:=alignment_live_state();var owner:RefCounted=game.landing_gear
	game._begin_graphics_demo();check(not game.graphics_return.is_empty() and game.source_geometry_last.is_empty(),"Graphics preview owns a separate ephemeral geometry observation")
	game.source_geometry_last={"explicit_preview_fixture":true};game._end_graphics_demo()
	check(game.source_geometry_last==observation and game.landing_gear==owner and alignment_live_state()==before,"Graphics preview return restores original geometry observation and all flight owners")
	game._close_menu();stage_natural("mercury",5000,0);before=alignment_live_state();game._show_menu()
	check(not game.surface.active and alignment_action(GEOMETRY_ACTION)==null,"Surface geometry inspection is absent during space flight")
	game._show_contact_geometry();check(game.source_geometry_last==observation and alignment_live_state()==before,"An ineligible command retains the prior observation with its original context")
	geometry_main_evidence.append({"case":"cold_preview_and_out_of_scope_lifetime","original_binding":observation.context_binding_sha256,"observation_persisted":false})

func actual_geometry_report()->void:
	if not await stage_gear_surface(40):return
	game.automated=false;game._show_surface_alignment();game._show_surface_footprint();game._show_contact_geometry();game.automated=true
	var observation:Dictionary=game.source_geometry_last.duplicate(true);geometry_contract(observation)
	game._close_menu();await frame();game._refresh_hud();game._refresh_hud();var before:=alignment_live_state()
	game.automated=false;game.diagnostic_timer=0;game._process(2.01);game.automated=true
	check(game.last_flight_sample.get(GEOMETRY_KEY)==observation and alignment_live_state()==before,"Periodic in-memory sampling retains the complete geometry observation without advancing flight")
	game.report_draft="Проверка исходной геометрии контакта и целочисленных округлений. Просмотр не меняет полёт."
	game._show_bug_report();await game._create_bug_report(false)
	check(game.current_report.get("ok",false) and not game.busy,"The real production collector creates the geometry report ZIP")
	if not game.current_report.get("ok",false):return
	geometry_archive=str(game.current_report.path);var files:=read_alignment_archive(geometry_archive)
	if files.has("report.json"):
		var report:Dictionary=JSON.parse_string(files["report.json"].get_string_from_utf8())
		check(report.context.flight.get(GEOMETRY_KEY)==copied(observation) and report.context.last_flight_sample.get(GEOMETRY_KEY)==copied(observation),"Actual report retains every frame/raw leaf/quantization/packet field in current and periodic contexts")
		check(report.context.flight.last_surface_alignment==copied(game.source_alignment_last) and report.context.flight.last_surface_footprint==copied(game.source_footprint_last),"New geometry reports retain both previous full observations")
		check(not report.included_save and not files.has("game-save.json"),"The default geometry report excludes saved player progress")
	if files.has("events/current-events.jsonl"):
		var measured:=false;var periodic:=false;var truncated:=false;var maximum_line:=0
		for line:String in files["events/current-events.jsonl"].get_string_from_utf8().split("\n",false):
			maximum_line=maxi(maximum_line,line.length());var entry:Variant=JSON.parse_string(line)
			if not entry is Dictionary:continue
			if entry.get("kind")=="entry_truncated":truncated=true
			if entry.get("event")=="source_contact_geometry" and entry.get("details")==copied(game._source_geometry_summary(observation)):measured=true
			if entry.get("event")=="flight_sample":
				var details:Dictionary=entry.get("details",{});var refs:Dictionary=details.get("diagnostic_observation_refs",{})
				periodic=refs.get("contact_geometry_sha256")==JSON.stringify(observation).sha256_text() and refs.get("last_surface_alignment_sha256")==JSON.stringify(game.source_alignment_last).sha256_text() and refs.get("last_surface_footprint_sha256")==JSON.stringify(game.source_footprint_last).sha256_text() and details.get("source_natural_probe")==copied(game.last_flight_sample.source_natural_probe) and details.get("source_spherical_probe")==copied(game.last_flight_sample.source_spherical_probe)
		check(measured and periodic and not truncated and maximum_line<=7900,"Actual periodic log retains three exact digest references and previous probes within the unchanged line cap")
		geometry_main_evidence.append({"case":"actual_full_geometry_zip_and_bounded_log","observation":observation,"maximum_log_line_characters":maximum_line,"archive_filename":game.current_report.filename})
	check(alignment_live_state()==before,"Collecting native geometry cannot change ship, source motion, HP/RNG, fuel, gear or clock")

func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires private capture mode");quit(1);return
	root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main failed to load");game.free();quit(1);return
	game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame();initialize_alignment_diagnostics()
	check(game.automated and not game.saving_enabled,"Geometry Main tests use private diagnostics and never read/write player progress")
	await actual_geometry_menu();await geometry_lifetime();await actual_geometry_report()
	var sources:Dictionary={}
	for path:String in ["scripts/main.gd","scripts/source_contact_geometry_probe.gd","scripts/source_native_contact_geometry.gd","scripts/source_terrain_query_frame.gd","scripts/native_contact_geometry_view.gd","scripts/source_natural_contact.gd","scripts/source_natural_footprint_probe.gd","scripts/source_surface_contact_bridge.gd","scripts/game_diagnostics.gd","scripts/diagnostics_logger.gd","tests/test_source_contact_geometry_main.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GEOMETRY_MAIN_REPORT.get_base_dir()));var file:=FileAccess.open(GEOMETRY_MAIN_REPORT,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"sources":sources,"evidence":geometry_main_evidence,"scope":"Actual Russian Main geometry action and isolated3Dviewer, source/native leaf packets and bounded projection certificates, paused state/cache/camera ownership, old cold/preview lifetime, full offline ZIP and three bounded digest references. Existing default v4 live terrain/response unchanged; no full visible mesh parity, source bank, physical Android or FPS claim."},"\t"));file.close()
	game.queue_free();await frame();print("Source contact geometry Main: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
