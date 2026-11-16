extends "res://tests/test_native_landing_trial_main.gd"
# Production Main integration. Guidance uses the existing powered flight and
# source contact owners; the initial50m Earth location is an explicit fixture.
const AUTO_MAIN_REPORT:="res://build/current-test-reports/native-autopilot-main.json"
var auto_main_evidence:Array=[]
var auto_fixture_index:=0
var normal_owners:Array=[]
var normal_state:=PackedByteArray()
var normal_save_generation:=0
var normal_save_payload:Dictionary={}

func current_pilot()->RefCounted:return game.get("native_autopilot")
func pilot_active()->bool:
	var pilot:=current_pilot()
	return pilot!=null and pilot.is_active()
func pilot_state()->Dictionary:
	var pilot:=current_pilot()
	return pilot.snapshot() if pilot!=null else {}
func auto_state()->PackedByteArray:return var_to_bytes([trial_state(),pilot_state()])
func flight_facts()->Dictionary:
	# Unrelated Navigation visited-list JSON integer types are not physics.
	return copied({"flight":game.ship.snapshot(),"surface":game.surface.snapshot(),"gear":game.landing_gear.snapshot(),"source_owner":game.nav.snapshot().source_hyperdrive,"elapsed_days":game.nav.elapsed_days,"autopilot":pilot_state()})
func auto_fixture()->bool:
	auto_fixture_index+=1
	trial_directory="user://native-autopilot-main-%d-%d"%[OS.get_process_id(),auto_fixture_index]
	if not await trial_fresh():return false
	normal_owners=trial_owners();normal_state=trial_state()
	check(game._start_native_landing_trial(),"Actual Main creates a separate native Earth trial for automatic guidance")
	if not game._native_surface_active():return false
	game._close_menu()
	normal_save_generation=ordinary_store.sequence;normal_save_payload=ordinary_store.last_payload.duplicate(true)
	check(not pilot_active(),"A fresh native trial starts with automatic guidance inactive")
	return true
func ordinary_unchanged(label:String)->void:
	check(ordinary_store.sequence==normal_save_generation and ordinary_store.last_payload==normal_save_payload,label+": ordinary save is unchanged")
func leave_auto_fixture(label:String)->void:
	check(game._exit_native_landing_trial(),label+": actual Main returns to the ordinary flight")
	check(trial_owners()==normal_owners and trial_state()==normal_state,label+": every original model and its exact state is restored")
	ordinary_unchanged(label)
	check(not pilot_active(),label+": trial guidance cannot leak into the ordinary flight")

func automatic_landing_and_single_interval()->void:
	if not await auto_fixture():return
	check(int(gear().position_u16)==0 and not gear().requested_down,"Autoland begins with the real source mechanism fully retracted")
	var position:Vector3=game.ship.position;var velocity:Vector3=game.ship.velocity;var before_days:float=game.nav.elapsed_days;var before_fuel:=fuel();var before_hp:=thermal()
	game._refresh_hud();game._update_flight_controls();await frame()
	check(game.flight_console.buttons.has("auto") and not game.flight_console.buttons.auto.disabled,"The retained lower console exposes an enabled real Auto touch command")
	await tap(game.flight_console.buttons.auto,911)
	check(pilot_active(),"The actual classic-console Auto command starts native landing guidance")
	check(game.ship.position==position and game.ship.velocity==velocity and game.nav.elapsed_days==before_days and fuel()==before_fuel and thermal()==before_hp,"Starting guidance does not move the ship or spend HP/fuel/time")
	if not pilot_active():leave_auto_fixture("Rejected guidance start");return
	var before:=auto_state();var owners:=trial_owners();var pilot:RefCounted=current_pilot()
	var predicted:Dictionary=pilot.advance(game.ship,game.nav,game.landing_gear,game.surface,0.1)
	check(predicted.get("ok",false),"One production guidance preparation runs the actual native transaction on private owners")
	check(auto_state()==before and trial_owners()==owners and current_pilot()==pilot,"Pure guidance preparation changes neither Main nor any live owner")
	if not predicted.get("ok",false):leave_auto_fixture("Rejected guidance preparation");return
	game._tick(0.1,Vector2.ZERO,0)
	check(game.source_contact_error.is_empty() and game.nav.elapsed_days==predicted.candidate_nav.elapsed_days and game.nav.elapsed_days==before_days+0.1/86400.0,"One actual guided Main tick advances the celestial clock exactly once")
	check(game.nav.snapshot().source_hyperdrive==predicted.candidate_nav.snapshot().source_hyperdrive and game.ship.snapshot()==predicted.candidate_ship.snapshot(),"Main publishes the exact prepared raw HP/RNG/fuel and physical flight result without a second interval")
	check(game.surface.snapshot()==predicted.candidate_surface.snapshot() and game.landing_gear.snapshot()==predicted.candidate_gear.snapshot(),"Source history, geometry and gear are published from that same accepted interval")
	var start_y:float=position.y;var accepted_tick:=-1;var all_steps_safe:=true
	for index in range(1800):
		var days:float=game.nav.elapsed_days
		game._tick(0.1,Vector2.ZERO,0)
		if not game.source_contact_error.is_empty() or game.ship.hull!=100 or game.nav.elapsed_days!=days+0.1/86400.0:all_steps_safe=false;break
		if game.surface.landed:accepted_tick=index+2;break
		if not pilot_active():break
	check(all_steps_safe and accepted_tick>0 and game.surface.landed,"Actual automatic descent reaches an accepted source landing with every interval clocked once")
	check(game.ship.position.y<start_y and game.ship.hull==100 and int(thermal().hull_u16)==400,"Flown automatic descent preserves healthy raw source hull")
	check(game.surface.native_session.phase()=="parked" and gear().deployed and gear().requested_down,"Autoland completes only on original parked contact with physically deployed gear")
	check(not pilot_active(),"Native guidance completes after the original park is actually committed")
	ordinary_unchanged("Automatic native landing")
	var raw:PackedByteArray=game.surface.native_session.raw_body();var generation:int=game.surface.native_session.generation();var parked_pose:Vector3=game.ship.position
	for index in range(4):game._tick(0.1,Vector2.ZERO,0)
	check(game.surface.native_session.raw_body()==raw and game.surface.native_session.generation()==generation and game.ship.position==parked_pose and game.ship.hull==100,"Post-autoland parked ticks retain exact raw pose/history and cannot replay damage")
	auto_main_evidence.append({"case":"actual_Auto_source_landing","intervals":accepted_tick,"gear_u16":gear().position_u16,"raw_hull":thermal().hull_u16,"source_generation":generation,"render_agl":game.surface.altitude(game.ship),"single_interval_prediction_matched":true})
	leave_auto_fixture("Automatic native landing")

func cold_guidance_continuation_and_legacy()->void:
	if not await auto_fixture():return
	var legacy:Dictionary=copied(payload())
	legacy.erase("native_autopilot_session")
	check(not game._decode_state(legacy).is_empty(),"The new whole-game factory still accepts a code50 native save without guidance")
	game._toggle_auto()
	if not pilot_active():check(false,"Cold guidance fixture starts the real Auto command");leave_auto_fixture("Cold fixture rejected");return
	for index in range(8):game._tick(0.1,Vector2.ZERO,0)
	check(pilot_active() and not game.surface.landed,"Cold fixture is an actual partially flown automatic descent")
	var saved:Dictionary=copied(payload())
	check(saved.has("native_autopilot_session") and not saved.native_autopilot_session.is_empty(),"An active guidance owner is included in the actual whole-game payload")
	if not saved.has("native_autopilot_session"):leave_auto_fixture("Missing guidance save");return
	var saved_facts:=flight_facts();var saved_pilot:Dictionary=saved.native_autopilot_session.duplicate(true)
	check(game._native_save_game(),"Actual Main writes active guidance into the separate native SaveStore")
	for index in range(20):game._tick(0.1,Vector2.ZERO,0)
	var continued:=flight_facts();var later:Dictionary=copied(payload())
	check(game._load_native_landing_trial(),"Actual Main restores active guidance through the real native whole-game factory")
	check(pilot_active() and flight_facts()==saved_facts,"Cold load retains exact guidance, raw body/history, physical gear, source HP/fuel/RNG and clock")
	for index in range(20):game._tick(0.1,Vector2.ZERO,0)
	check(flight_facts()==continued,"Cold automatic continuation reproduces the next twenty actual intervals exactly")
	var protected:=auto_state();var owners:=trial_owners();var bad:Dictionary=later.duplicate(true)
	bad.native_autopilot_session=saved_pilot
	check(game._decode_state(bad).is_empty(),"A separately valid older guidance snapshot cannot attach to a later source pose/history")
	for value:Variant in [{},null,[],{"unknown_field":true}]:
		bad=saved.duplicate(true);bad.native_autopilot_session=value
		check(game._decode_state(bad).is_empty(),"Present malformed guidance cannot silently become a legacy missing extension")
	bad=ordinary_store.last_payload.duplicate(true);bad.native_autopilot_session=saved_pilot
	check(game._decode_state(bad).is_empty(),"An ordinary flight cannot import a native-surface guidance owner")
	check(auto_state()==protected and trial_owners()==owners,"Every rejected guidance restore preserves the live physical owners and guidance state")
	var restored:Dictionary=game._decode_state(legacy)
	if not restored.is_empty():game._commit_state(restored);game._apply_system()
	check(not restored.is_empty() and game._native_surface_active() and not pilot_active(),"Loading a valid old native save explicitly resumes manual flight")
	auto_main_evidence.append({"case":"actual_cold_guidance_continuation","initial_intervals":8,"compared_intervals":20,"whole_game_factory_rejects_stale_guidance":true})
	leave_auto_fixture("Cold native guidance")

func pause_cancel_and_failed_interval()->void:
	if not await auto_fixture():return
	game._toggle_auto();check(pilot_active(),"Cancellation fixture starts actual guidance")
	if not pilot_active():leave_auto_fixture("Cancellation fixture rejected");return
	var protected:=auto_state();game._toggle_pause();game._advance_controls(5.0);game._tick(0.1,Vector2.ZERO,0)
	check(pilot_active() and auto_state()==protected,"Pause preserves active guidance and freezes all physical/fuel/time owners")
	game._toggle_pause();protected=auto_state();game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);game._advance_controls(5.0)
	check(pilot_active() and auto_state()==protected,"Background frames do not advance guidance or accumulate flight time")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	var before:=trial_state();game._toggle_auto()
	check(not pilot_active() and trial_state()==before,"The second Auto command cancels guidance without a physical impulse or time step")
	game._toggle_auto();game._tick(0.1,Vector2(0.2,0),0)
	check(not pilot_active() and game.source_contact_error.is_empty(),"A genuine manual steering interval cancels native automatic guidance")
	game._toggle_auto();check(pilot_active(),"Guidance may be requested again after manual flight")
	game._brake();check(not pilot_active(),"The actual Brake command cancels guidance")
	game._toggle_auto();game._set_speed(7)
	check(not pilot_active() and game.ship.target_speed==7,"A manual throttle command cancels guidance and retains the requested speed")
	game.ship.target_speed=0;game._toggle_auto()
	check(pilot_active(),"Rollback fixture restarts actual guidance")
	if pilot_active():
		# This is an explicit invalid-chart fixture. The guidance and physics
		# prepare must reject it together, retaining every live owner.
		game.ship.position.x=1e9;protected=auto_state();var owners:=trial_owners();var pilot:=current_pilot()
		game._tick(0.1,Vector2.ZERO,0)
		check(not game.source_contact_error.is_empty() and auto_state()==protected and trial_owners()==owners and current_pilot()==pilot,"A rejected real native step cannot partially commit the automatic owner, HP/fuel/time or physical models")
	auto_main_evidence.append({"case":"pause_cancel_and_failed_interval","manual_actions":["Auto","steering","Brake","throttle"],"failed_step_atomic":true})
	leave_auto_fixture("Cancelled/rejected native guidance")

func automatic_report_zip()->void:
	if not await auto_fixture():return
	game._toggle_auto();game._tick(0.1,Vector2.ZERO,0)
	check(pilot_active(),"Diagnostic fixture contains a genuinely active native pilot")
	if not pilot_active():leave_auto_fixture("Diagnostic fixture rejected");return
	game.diagnostics.directory=trial_directory+"/diagnostics";game.diagnostics.reports_directory=trial_directory+"/reports";game.diagnostics.engine_logs_directory=trial_directory+"/empty-logs"
	check(game.diagnostics.initialize("native-autopilot-main-validation"),"Production diagnostics initializes private automatic-flight logs")
	var before:=auto_state();var complete:Dictionary=copied(payload())
	game.report_include_save=true;game.report_draft="Автопосадка: состояние управления, точная исходная геометрия и воспроизводимый текущий полёт."
	game._show_bug_report();await game._create_bug_report(false)
	check(game.current_report.get("ok",false),"Actual report command builds a ZIP containing active native guidance")
	if game.current_report.get("ok",false):
		var zip:=ZIPReader.new();check(zip.open(str(game.current_report.path))==OK,"The real automatic-flight report ZIP opens")
		check(zip.file_exists("game-save.json"),"The optional whole-game source save is present in the actual report")
		if zip.file_exists("game-save.json"):
			var saved:Dictionary=JSON.parse_string(zip.read_file("game-save.json").get_string_from_utf8())
			check(saved==complete and saved.native_autopilot_session==complete.native_autopilot_session,"Report transport preserves the whole active guidance snapshot and its bound source state")
			check(not game._decode_state(saved).is_empty(),"The production cold decoder validates guidance directly from its real diagnostic ZIP")
		zip.close()
	check(auto_state()==before,"Creating the automatic-flight ZIP changes no live guidance or physical owner")
	auto_main_evidence.append({"case":"actual_active_guidance_include_save_ZIP","archive":str(game.current_report.get("filename","")),"full_guidance_transported":true})
	leave_auto_fixture("Automatic-flight diagnostic")

func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires private capture mode");quit(1);return
	root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main failed to load");game.free();quit(1);return
	game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	check(game.automated and not game.saving_enabled,"Actual automatic-flight Main tests use private capture mode")
	await automatic_landing_and_single_interval();await cold_guidance_continuation_and_legacy();await pause_cancel_and_failed_interval();await automatic_report_zip()
	var sources:Dictionary={}
	for path:String in ["scripts/main.gd","scripts/native_surface_autopilot.gd","scripts/native_landing_trial.gd","scripts/native_surface_model.gd","scripts/source_natural_contact_session.gd","scripts/source_native_surface_provider.gd","scripts/source_landing_gear_session.gd","tests/test_native_autopilot_main.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(AUTO_MAIN_REPORT.get_base_dir()));var report:=FileAccess.open(AUTO_MAIN_REPORT,FileAccess.WRITE)
	if report:report.store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":auto_main_evidence,"sources":sources,"scope":"Actual Main automatic native landing guidance, source contact, exact candidate publication, old-save compatibility, cold continuation/cancellation, isolated normal return and real report ZIP. Host guidance is not the complete original autopilot; no physical Android/FPS claim."},"\t"))
	game.queue_free();await frame();print("Native autopilot Main: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
