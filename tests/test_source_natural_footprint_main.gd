extends "res://tests/test_source_contact_alignment_main.gd"
# Actual Main action, paused observation, ephemeral state and offline ZIP.
# Original instruction/triangle parity is covered by the independent fixtures.
const Footprint=preload("res://scripts/source_natural_footprint_probe.gd")
const FootprintNatural=preload("res://scripts/source_natural_contact.gd")
const FOOTPRINT_ACTION:="Проверить контакт всего корабля"
const FOOTPRINT_KEY:="last_surface_footprint"
const FOOTPRINT_REPORT:="res://build/current-test-reports/source-natural-footprint-main.json"
var footprint_evidence:Array=[]
var footprint_archive:=""

func footprint_contract(value:Dictionary)->void:
	check(value.get("ok",false) and value.get("diagnostic_only")==true and value.get("response_applied")==false and value.get("live_response_enabled")==false,"A completed ship-volume observation never applies a physical response")
	check(value.get("source_geometry_identity_verified")==false and game.diagnostics._json_safe(value),"The bounded observation is strict JSON and does not certify the rendered mesh as original geometry")
	if not value.get("ok",false):return
	check(int(value.get("visited_volume_count",0))==value.get("volumes",[]).size() and int(value.get("total_volume_count",0))>=int(value.get("visited_volume_count",0)),"The diagnostic labels the actual visited prefix separately from all ship volumes")
	check(str(value.get("context_binding_sha256","")).length()==64 and value.get("query_context") is Dictionary,"The observation identifies its exact source and phone-frame operands")
	var selected:=int(value.get("selected_child_index",-1))
	check((int(value.get("f576_return_s32",-1))<0 and selected==-1) or (int(value.get("f576_return_s32",-1))>=0 and selected>=0),"First-hit label is absent when the original walk found no contact")
	check(not value.has("body_after") and not value.has("parent_after"),"No response object buffers are published as live state")

func actual_footprint_action()->void:
	if not await stage_gear_surface(40):return
	game._show_menu();var button:=alignment_action(FOOTPRINT_ACTION)
	check(button!=null,"The real commander menu exposes the complete-ship contact check")
	if button==null:return
	var scroll:ScrollContainer=game.menu_rows.get_parent();scroll.ensure_control_visible(button);await frame()
	var before:=alignment_live_state();var cache:Dictionary=game.surface.globe.cache_stats();var provider:RefCounted=game.surface.source_render_state
	await tap(button,321)
	var value:Dictionary=game.source_footprint_last.duplicate(true);footprint_contract(value)
	check(game.menu.visible and game.menu_title.text=="КОНТАКТ КОРАБЛЯ","A phone tap opens the actual Russian contact-check page")
	check(alignment_live_state()==before and game.surface.source_render_state==provider and game.surface.globe.cache_stats()==cache,"Checking every volume preserves flight, HP/RNG, fuel, clock, gear, terrain cache and provider ownership")
	check(alignment_labels().contains("Проверено объёмов корабля:") and alignment_action("Отчёт об ошибке / логи")!=null,"The production page displays the visited count and offers the real ZIP report")
	var expected:=Footprint.sample(game.surface,game.ship,int(gear().position_u16),{"initial_globals":FootprintNatural._globals({}),"history_policy":"isolated-diagnostic-initial-state"})
	expected["observed_elapsed_days"]=game.nav.elapsed_days
	check(value==expected,"Main retains exactly the independent probe result and observed game time")
	for index in range(3):game._advance_controls(1.0);game._process(0)
	check(alignment_live_state()==before and game.source_footprint_last==value,"An open observation page pauses flight without changing its measured state")
	game.busy=true;game._show_surface_footprint();game.busy=false
	check(game.source_footprint_last==value,"A busy command cannot overwrite the completed observation")
	footprint_evidence.append({"case":"actual_default_v4_touch_and_state_isolation","measurement":value,"cache_unchanged":true})

func footprint_lifetime()->void:
	var observation:Dictionary=game.source_footprint_last.duplicate(true);game._close_menu()
	var save:Dictionary=copied(payload());var hp:=thermal();var gear_before:=gear()
	check(not save.has(FOOTPRINT_KEY) and not save.has("source_footprint_last"),"The diagnostic does not extend the persisted flight/save schema")
	check(load_fixture(save,"Existing v4 source save after full-ship observation"),"The ordinary decoder restores the previous save policy")
	check(game.source_footprint_last.is_empty() and thermal()==hp and gear()==gear_before,"Cold restore clears transient observations and preserves exact HP and gear")
	game._show_surface_footprint();observation=game.source_footprint_last.duplicate(true);game._close_menu()
	var original_gear:RefCounted=game.landing_gear;var before:=alignment_live_state()
	game._begin_graphics_demo()
	check(not game.graphics_return.is_empty() and game.source_footprint_last.is_empty(),"Graphics preview has separate transient diagnostic state")
	game.source_footprint_last={"explicit_preview_fixture":true};game._end_graphics_demo()
	check(game.landing_gear==original_gear and game.source_footprint_last==observation and alignment_live_state()==before,"Returning from graphics preview restores the original observation and entire flight session")
	game._close_menu();stage_natural("mercury",5000,0);before=alignment_live_state();game._show_menu()
	check(not game.surface.active and alignment_action(FOOTPRINT_ACTION)==null,"A surface contact action is absent during space flight")
	game._show_surface_footprint()
	check(game.source_footprint_last==observation and alignment_live_state()==before,"An out-of-scope command retains the previous observation with its original binding")
	footprint_evidence.append({"case":"cold_restore_preview_and_out_of_scope_lifetime","last_observation":observation})

func actual_footprint_report()->void:
	if not await stage_gear_surface(40):return
	# Both explicit observations coexist; the periodic logger must retain
	# earlier spherical/natural facts within its existing 8000-character cap.
	game.automated=false;game._show_surface_alignment();game._show_surface_footprint();game.automated=true
	var observation:Dictionary=game.source_footprint_last.duplicate(true);footprint_contract(observation)
	game._close_menu();game._process(0);game._refresh_hud();game._refresh_hud()
	var before:=alignment_live_state();game.automated=false;game.diagnostic_timer=0;game._process(2.01);game.automated=true
	check(game.last_flight_sample.get(FOOTPRINT_KEY)==observation and alignment_live_state()==before,"The periodic in-memory sample retains the full observation without advancing simulation")
	game.report_draft="Проверка контакта основного корпуса и дополнительных объёмов. Полёт не изменяется."
	game._show_bug_report();await game._create_bug_report(false)
	check(game.current_report.get("ok",false) and not game.busy,"The real production report action creates a full-ship diagnostic ZIP")
	if not game.current_report.get("ok",false):return
	footprint_archive=str(game.current_report.path);var files:=read_alignment_archive(footprint_archive)
	if files.has("report.json"):
		var report:Dictionary=JSON.parse_string(files["report.json"].get_string_from_utf8())
		check(report.context.flight.get(FOOTPRINT_KEY)==copied(observation) and report.context.last_flight_sample.get(FOOTPRINT_KEY)==copied(observation),"Both actual report contexts retain every exact volume/triangle field without depth or array truncation")
		check(not report.included_save and not files.has("game-save.json"),"The default report excludes ordinary saved progress")
	if files.has("events/current-events.jsonl"):
		var observed:=false;var periodic:=false;var truncated:=false;var maximum_line:=0
		for line:String in files["events/current-events.jsonl"].get_string_from_utf8().split("\n",false):
			maximum_line=maxi(maximum_line,line.length());var entry:Variant=JSON.parse_string(line)
			if not entry is Dictionary:continue
			if entry.get("kind")=="entry_truncated":truncated=true
			if entry.get("event")=="source_ship_footprint" and entry.get("details")==copied(game._source_footprint_summary(observation)):observed=true
			if entry.get("event")=="flight_sample":
				var details:Dictionary=entry.get("details",{});var reference:Dictionary=details.get(FOOTPRINT_KEY,{})
				var alignment:Dictionary=details.get("last_surface_alignment",{})
				periodic=reference.get("compact_periodic_record")==true and reference.get("report_sha256")==JSON.stringify(observation).sha256_text() and alignment.get("context_binding_sha256")==game.source_alignment_last.context_binding_sha256 and alignment.get("delta_m")==copied(game.source_alignment_last.delta_m) and details.get("source_natural_probe")==copied(game.last_flight_sample.get("source_natural_probe")) and details.get("source_spherical_probe")==copied(game.last_flight_sample.get("source_spherical_probe"))
		check(observed and periodic and not truncated and maximum_line<=7900,"Actual log retains bound references alongside earlier probes with room below the8000-character cap")
		footprint_evidence.append({"case":"actual_collector_zip_and_bounded_logs","measurement":observation,"maximum_log_line_characters":maximum_line,"archive_filename":game.current_report.filename})
	check(alignment_live_state()==before,"Building the real report leaves ship, source history, HP/RNG, fuel and clock unchanged")

func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires private capture mode");quit(1);return
	root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main failed to load");game.free();quit(1);return
	game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame();initialize_alignment_diagnostics()
	check(game.automated and not game.saving_enabled,"Full-ship Main tests use private diagnostics and never read/write player progress")
	await actual_footprint_action();footprint_lifetime();await actual_footprint_report()
	var sources:Dictionary={}
	for path:String in ["scripts/main.gd","scripts/source_natural_footprint_probe.gd","scripts/source_terrain_query_trace.gd","scripts/source_natural_contact.gd","scripts/source_natural_contact_pipeline.gd","scripts/source_natural_surface_bridge.gd","scripts/source_surface_contact_bridge.gd","scripts/game_diagnostics.gd","scripts/diagnostics_logger.gd","tests/test_source_natural_footprint_main.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOOTPRINT_REPORT.get_base_dir()));var file:=FileAccess.open(FOOTPRINT_REPORT,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"sources":sources,"evidence":footprint_evidence,"scope":"Actual Main full-ship explicit diagnostic: touch action, copied source F576 operands, ordered visited volumes and isolated history; simulation/cache/HP/RNG/fuel/clock preservation; cold/preview/out-of-scope lifetime; complete offline ZIP fields and bounded log reference. Existing default v4 live physics unchanged. No physical Android or full original collision pipeline proof."},"\t"));file.close()
	game.queue_free();await frame();print("Source natural footprint Main: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
