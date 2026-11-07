extends "res://tests/test_source_contact_main.gd"
# Actual Main diagnostic sampling only. F577's sphere envelope is not terrain
# classification, a landing verdict, or a new source-object collision bank.
const SphereProbe=preload("res://scripts/source_spherical_contact_probe.gd")
const SphereBuild=preload("res://scripts/build_info.gd")
const SPHERE_REPORT:="res://validation/spherical-2026-11-08/source-spherical-main.json"
const SPHERE_KEY:="source_spherical_probe"
var spherical_evidence:Array=[]
var spherical_private:="user://spherical-main-"+str(OS.get_process_id())
var spherical_archive:=""

func live_spherical_state()->PackedByteArray:
	# Read models directly: unresolved existing contact intentionally excludes
	# its intermediate pose from Main._payload(), even during a report.
	return var_to_bytes([game.ship.snapshot(),game.nav.snapshot(),game.world.snapshot(),game.surface.snapshot(),game.landing_gear.snapshot(),game.source_motion.snapshot(),game.world.body_spin_by_id,game.world.native_evaluation_count,game.world._native_cache_tick,game.world._native_cache_day,game.world._native_positions_raw,game.world._native_relative_raw])
func spherical_sample()->Dictionary:
	var sample:Dictionary=game._flight_diagnostic_sample()
	check(sample.get(SPHERE_KEY) is Dictionary,"Actual Main flight diagnostics include the new spherical-envelope facts")
	return sample.get(SPHERE_KEY,{}).duplicate(true)
func spherical_contract(value:Dictionary)->void:
	check(value.get("envelope_only")==true and value.get("response_applied")==false,"Spherical diagnostics explicitly remain read-only envelope observations")
	check(value.get("full_F569",false)==false and value.get("source_object_bank_present",false)==false,"Diagnostic sampling cannot claim a complete original classifier or an existing source object bank")
	check(game.diagnostics._json_safe(value),"Compact probe facts contain only strict JSON-safe values, not live objects or raw body buffers")
func assert_probe_readonly(label:String,days_offset:=0.0)->Dictionary:
	var before:=live_spherical_state();var objects:=identities();var cache:Dictionary=game.surface.globe.cache_stats() if game.surface.active and game.surface.globe!=null else {}
	var value:Dictionary=SphereProbe.sample(game.world,game.ship,game.surface,game.nav.elapsed_days+days_offset)
	if not cache.is_empty():check(game.surface.globe.cache_stats()==cache,"Spherical envelope sampling never queries or changes the real source terrain cache: "+label)
	check(live_spherical_state()==before and identities()==objects,"Read-only spherical probe preserves all live model/HP/RNG/fuel/clock/frame state: "+label)
	spherical_contract(value)
	return value

func routing_and_compact_raw_facts()->void:
	var count:=0
	for index in range(149):
		var row:Dictionary=SphereProbe.model_routing(index)
		if not row.is_empty() and int(row.get("model_index",-1))==index:count+=1
	check(count==149 and SphereProbe.model_routing(-1).is_empty() and SphereProbe.model_routing(149).is_empty(),"Diagnostic routing covers exactly the149 original descriptor indices without inventing model149")
	for index in range(117,149):
		var row:Dictionary=SphereProbe.model_routing(index)
		check(not row.is_empty() and row.get("initial_sphere_path_eligible")==false and (int(row.get("initial_object_flags_14c_u8",0))&128)!=0,"Actual natural collision stream remains on its original F576 path: model"+str(index))
	fresh();stage_natural("earth",5000,0);var value:=spherical_sample()
	check(str(value.get("relative_position_s64_hex","")).length()==48 and str(value.get("absolute_position_s64_hex","")).length()==48 and str(value.get("altitude_s64_hex","")).length()==16,"Compact diagnostic operands retain exact little-endian signed64 hex alongside human previews")
	check(not value.has("body_after") and not value.has("parent_after") and not value.has("damage_calls"),"Read-only Main diagnostics expose no mutable raw body records or fabricated damage requests")
	check(value.get("terrain_provider_queried")==false and value.get("terrain_collision_kind_changed")==false and value.get("flags2_means_landing_hit")==false,"Sphere flags and bounds cannot be misreported as a terrain hit or a gameplay classifier change")
	spherical_evidence.append({"case":"complete_original_routing_and_compact_raw_operands","model_count":count,"natural_stream_model_count":32,"probe":value})

func actual_natural_space_and_surface()->void:
	for body_id:String in ["earth","mercury"]:
		fresh();game.settings.orbital_gravity=false;var placed:=stage_natural(body_id,5000,0)
		check(not placed.is_empty(),"Actual source body configures the spherical diagnostic fixture "+body_id)
		var before:=live_spherical_state();var value:=spherical_sample();spherical_contract(value)
		check(value.get("ok",false) and int(value.get("parent_model_index",-1))==int(game.world.by_id[body_id].model_index),"Actual orbital diagnostic identifies the selected original parent model "+body_id)
		check(value.get("original_sphere_dispatch_eligible")==false,"Natural collision-stream model is not mislabelled as the original F577 dispatcher path "+body_id)
		check(live_spherical_state()==before,"Calling the actual Main diagnostic entry point cannot mutate orbital state "+body_id)
		for offset:float in [0.0,0.125,17.25]:assert_probe_readonly(body_id+" orbital, days offset "+str(offset),offset)
		var orbital:=value.duplicate(true)
		await game._enter_surface()
		check(game.surface.active and game.surface.source_surface(),"Actual Main enters the unchanged source surface "+body_id)
		if not game.surface.active:continue
		value=assert_probe_readonly(body_id+" active source surface");var context:=spherical_sample()
		check(value==context and value.get("original_sphere_dispatch_eligible")==false,"Main and the pure probe agree on the active natural-surface envelope without changing its classifier "+body_id)
		spherical_evidence.append({"case":"actual_"+body_id+"_orbital_and_surface","orbital":orbital,"surface":context,"new_physical_response":false,"observer_placement_fixture":true})

func inside_outside_are_not_contact_hits()->void:
	fresh();game.settings.orbital_gravity=false;stage_natural("earth",5000,0)
	var descriptor:=ContactFrame.model_descriptor(int(game.world.by_id.earth.model_index));var bounds:=ContactFrame.descriptor_radii(descriptor)
	check(bounds.get("ok",false),"Actual original Earth descriptor supplies the envelope observer scale")
	if not bounds.get("ok",false):return
	var radius:float=float(bounds.outer_raw)*ContactFrame.Units.METRES_PER_RAW;var centre:Vector3=game.world.local_meters("earth",game.nav.elapsed_days);var rows:Array=[]
	for multiplier:float in [0.25,4.0]:
		# Explicit diagnostic observer placements; the physics tick is not used
		# to fly a player through a solid planet or manufacture a landing.
		game.ship.position=centre+Vector3.RIGHT*(radius*multiplier);game.ship.velocity=Vector3.ZERO;game.source_motion.reset()
		var before:=live_spherical_state();var value:=spherical_sample();spherical_contract(value)
		check(value.get("ok",false),"Actual Main samples the explicit sphere-envelope observer position")
		check(value.get("inside_sphere")==bool(multiplier<1.0) and int(value.get("return_s32",1))==(0 if multiplier<1.0 else -1),"F577 inside/outside return polarity is retained independently of terrain collision")
		check(value.get("original_sphere_dispatch_eligible")==false and live_spherical_state()==before and game.ship.hull==100,"Inside a natural model's envelope is diagnostic only and never applies F575/F953 damage")
		check(not game.surface.active and not game.ship.docked and game.source_contact_last.is_empty(),"Envelope observations cannot silently land, dock or create an existing source contact result")
		rows.append({"radius_multiplier":multiplier,"probe":value})
	spherical_evidence.append({"case":"actual_Earth_envelope_observers","rows":rows,"radius_m_is_original_descriptor_bound":true,"terrain_or_landing_predicate_claim":false})

func fractional_cold_and_legacy()->void:
	fresh();game.settings.orbital_gravity=false;stage_natural("earth",5000,0)
	check(set_contact_hull_fixture(37.625),"An explicit old-save anchor prepares the fractional HP diagnostic fixture")
	var value:=spherical_sample();var hp:=thermal();var saved:Dictionary=copied(payload())
	check(not saved.has(SPHERE_KEY) and not saved.navigation.source_hyperdrive.has(SPHERE_KEY),"New diagnostic facts do not become a second persisted flight or HP state")
	check(load_fixture(saved,"Unchanged whole-game save with spherical diagnostic sampling"),"Existing full source save schema cold-restores without a probe-state migration")
	check(game.ship.hull==37.625 and thermal()==hp and spherical_sample()==value,"Cold restoration preserves exact fractional HP/RNG and recomputes identical current envelope facts")
	fresh(false);var before:=live_spherical_state();value=spherical_sample();spherical_contract(value)
	check(not game.nav.is_source_hyperdrive() and live_spherical_state()==before,"Legacy source-world diagnostics cannot silently opt into the native hardware/session profile")
	check(not value.get("reason","").is_empty() and value.get("response_applied")==false,"Legacy diagnostics explicitly explain their disabled spherical-probe scope")
	spherical_evidence.append({"case":"fractional_cold_and_legacy_readonly","fractional_hull_percent":37.625,"legacy_probe":value,"new_save_extension":false})

func docked_pause_and_held_menu()->void:
	fresh();check(dock_fixture(),"Actual original orbital bay prepares the docked diagnostic scope")
	var before:=live_spherical_state();var value:=spherical_sample();spherical_contract(value)
	check(live_spherical_state()==before and game.ship.docked,"Docked spherical diagnostics cannot apply impulse, damage or launch a ship")
	game._toggle_pause();before=live_spherical_state()
	for index in range(4):spherical_sample();game._advance_controls(1.0);game._process(0)
	check(live_spherical_state()==before and game.instruments.paused,"Repeated diagnostic samples and paused frames retain the actual docked clock, gear and HP")
	game._toggle_pause()
	if not await stage_gear_surface(2):return
	complete_gear(true);contact_pose(-0.01,Vector3(0,-0.5,0))
	check(game.surface.touch_down(game.ship),"Existing source contact queues the explicit pending diagnostic boundary")
	game._toggle_pause();game._refresh_hud();game._update_flight_controls();await frame();before=live_spherical_state()
	value=spherical_sample();spherical_contract(value)
	var button:Button=game.flight_console.buttons.menu;var event:=InputEventScreenTouch.new();event.index=281;event.position=button.get_global_rect().get_center();event.pressed=true
	root.push_input(event,true);await frame()
	for index in range(2):game._process(0);game._tick(0.5,Vector2.ZERO,0);spherical_sample();await frame()
	check(button.pointer_id==281 and live_spherical_state()==before,"A real held recovery-menu pointer survives paused pending frames and read-only probe sampling")
	event.pressed=false;root.push_input(event,true);await frame()
	check(game.menu.visible and game.menu_title.text=="КОМАНДИР","Actual phone menu remains available while the existing contact is pending")
	game._close_menu();game._toggle_pause();game._tick(0,Vector2.ZERO,0)
	check(game.surface.landed and game.ship.hull==100 and game.surface.pending_source_contact().is_empty(),"Existing accepted F575 landing still commits once; the spherical diagnostic introduced no extra response")
	spherical_evidence.append({"case":"actual_docked_pause_pending_menu","docked_probe":value,"old_contact_pipeline_changed":false})

func report_action(text:String)->Button:
	for node in game.menu_rows.get_children():
		if node is Button and node.text==text:return node
	return null
func read_probe_archive(path:String)->Dictionary:
	var reader:=ZIPReader.new();check(reader.open(path)==OK,"Actual diagnostic collector produces a readable spherical-probe ZIP")
	var files:Dictionary={}
	for name:String in reader.get_files():files[name]=reader.read_file(name)
	reader.close();check(files.has("report.json") and files.has("manifest.json"),"The new diagnostic ZIP retains its report and member manifest")
	if files.has("manifest.json"):
		var manifest:Dictionary=JSON.parse_string(files["manifest.json"].get_string_from_utf8())
		for row:Dictionary in manifest.files:
			var bytes:PackedByteArray=files.get(row.name,PackedByteArray());var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
			check(bytes.size()==int(row.bytes) and hash.finish().hex_encode()==str(row.sha256),"Collected spherical ZIP member matches the actual manifest bytes and SHA: "+str(row.name))
	return files
func initialize_probe_diagnostics()->void:
	game.diagnostics.directory=spherical_private+"/diagnostics";game.diagnostics.reports_directory=spherical_private+"/reports";game.diagnostics.engine_logs_directory=spherical_private+"/engine"
	check(game.diagnostics.initialize(SphereBuild.VERSION),"Actual diagnostics initialize only in private spherical-test directories")
func actual_logger_and_report_zip()->void:
	fresh();game.settings.orbital_gravity=false;stage_natural("mercury",5000,0);game._process(0)
	var before:=live_spherical_state();var probe:=spherical_sample()
	# The production two-second logger is disabled in capture mode. Enable
	# only its runtime branch after private initialization; automatic process
	# and physics remain disabled and ordinary progress saving stays false.
	game.automated=false;game.diagnostic_timer=0;game._process(2.01);game.automated=true
	check(live_spherical_state()==before and game.last_flight_sample.get(SPHERE_KEY)==probe,"Actual periodic Main logger records the same read-only envelope facts without advancing simulation")
	game.report_draft="Проверка отчёта: положение у Меркурия, исходные данные и журналы.\nНовая диагностика не меняет полёт или повреждения."
	game._show_bug_report();check(report_action("Собрать ZIP и сохранить…")!=null,"Actual report page exposes its production collection action")
	await game._create_bug_report(false)
	check(game.current_report.get("ok",false) and not game.busy,"Actual Main collects a complete private diagnostic ZIP")
	if not game.current_report.get("ok",false):return
	spherical_archive=str(game.current_report.path);var files:=read_probe_archive(spherical_archive)
	if files.has("report.json"):
		var report:Dictionary=JSON.parse_string(files["report.json"].get_string_from_utf8())
		check(report.context.flight.get(SPHERE_KEY)==copied(probe) and report.context.last_flight_sample.get(SPHERE_KEY)==copied(probe),"Actual ZIP contains the new current and periodically recorded spherical diagnostic fields")
		check(not report.included_save and not files.has("game-save.json"),"Default spherical diagnostic report excludes saved player progress")
	if files.has("events/current-events.jsonl"):
		var found:=false
		for line:String in files["events/current-events.jsonl"].get_string_from_utf8().split("\n",false):
			var entry:Variant=JSON.parse_string(line)
			if entry is Dictionary and entry.get("event")=="flight_sample" and entry.get("details",{}).get(SPHERE_KEY)==copied(probe):found=true
		check(found,"Actual periodic flight_sample event preserves the compact probe facts in the collected log")
	check(live_spherical_state()==before,"Collecting the real report cannot change the observed flight, native HP/RNG, fuel or celestial spin")
	spherical_evidence.append({"case":"actual_periodic_logger_and_diagnostic_zip","probe":probe,"archive_filename":game.current_report.filename,"included_save":false,"new_collision_response_claim":false})

func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires private capture mode");quit(1);return
	root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main script failed to load");game.free();quit(1);return
	game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame();initialize_probe_diagnostics()
	check(game.automated and not game.saving_enabled,"Spherical Main regression never loads or writes ordinary player progress")
	routing_and_compact_raw_facts();await actual_natural_space_and_surface();inside_outside_are_not_contact_hits();fractional_cold_and_legacy();await docked_pause_and_held_menu();await actual_logger_and_report_zip()
	var sources:Dictionary={}
	for path:String in ["scripts/main.gd","scripts/source_spherical_contact.gd","scripts/source_spherical_contact_probe.gd","scripts/source_surface_contact.gd","scripts/source_surface_contact_bridge.gd","scripts/game_diagnostics.gd","tests/test_source_spherical_main.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SPHERE_REPORT.get_base_dir()));var file:=FileAccess.open(SPHERE_REPORT,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"evidence":spherical_evidence,"sources":sources,"scope":"Actual Main read-only DOS F577 envelope diagnostics, original natural-model routing, orbit/surface/docked/legacy contexts, exact existing HP/RNG/fuel/time/frame preservation, cold restore, held pause/menu interaction and production periodic-log/ZIP collection. Inside/outside observers are explicit fixtures; natural F576 terrain, existing F575/F953 response, collider-bank scanning and gameplay collision behavior are not extended by this diagnostic module."},"\t"));file.close()
	game.queue_free();await frame();print("Source spherical Main: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
