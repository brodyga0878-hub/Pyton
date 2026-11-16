extends "res://tests/test_native_return_main.gd"
# Task2 actual Main: return at the genuinely flown outbound pose, then fly
# the entire powered descent into original F576/F575 parking. Cold/report
# controls are taken from that real trajectory, never a lowered fixture.
const RETURN_DESCENT_MAIN_REPORT:="res://build/current-test-reports/native-return-descent-main.json"
var return_descent_evidence:Array=[]
var flown_descent_template:Dictionary={}

func descent_facts()->Dictionary:return copied({"physical":return_facts(),"pilot":pilot_state()})

func inspect_cold_descent_and_report()->void:
	check(pilot_active() and current_pilot().mode()=="return_landing" and game.surface.altitude(game.ship)>1000,"Cold/report control comes from a genuinely partly flown high return descent")
	flown_descent_template=copied(payload())
	var saved:=descent_facts();check(game._native_save_game(),"The actual separate SaveStore records active long return descent and its source witness")
	for index in range(6):game._tick(0.5,Vector2.ZERO,0)
	var continued:=descent_facts()
	check(game._load_native_landing_trial() and descent_facts()==saved and pilot_active(),"Actual cold loading preserves the complete returned high descent, source HP/fuel/RNG, gear, pose and clock")
	for index in range(6):game._tick(0.5,Vector2.ZERO,0)
	check(descent_facts()==continued and game.source_contact_error.is_empty(),"The next six real cold descent intervals equal warm continuation exactly")
	game.diagnostics.directory=trial_directory+"/diagnostics";game.diagnostics.reports_directory=trial_directory+"/reports";game.diagnostics.engine_logs_directory=trial_directory+"/empty-logs"
	check(game.diagnostics.initialize("native-return-descent-main-validation"),"Production return-descent diagnostics initializes in private test directories")
	var before:=descent_facts();var complete:Dictionary=copied(payload())
	game.report_include_save=true;game.report_draft="Возвращение из космоса: настоящее снижение после обратного перехода, исходная история контакта и состояние автоматики."
	game._show_bug_report();await game._create_bug_report(false)
	check(game.current_report.get("ok",false),"The real report action builds an include-save ZIP during active return descent")
	if game.current_report.get("ok",false):
		var zip:=ZIPReader.new();check(zip.open(str(game.current_report.path))==OK,"The actual return-descent report ZIP opens")
		check(zip.file_exists("game-save.json"),"The optional full returned descent save is included in the actual archive")
		if zip.file_exists("game-save.json"):
			var contents:=zip.read_file("game-save.json").get_string_from_utf8();var archived:Dictionary=JSON.parse_string(contents)
			check(archived==complete and archived.native_autopilot_session.mode=="return_landing" and not archived.has("native_orbit_session"),"The report preserves exact active return guidance and native surface lineage without stale orbital ownership")
			check(not contents.contains("[depth limit]") and not contents.contains("[unsupported value]") and not game._decode_state(archived).is_empty(),"The real factory cold-validates complete raw/provider and returned guidance directly from the report ZIP")
		zip.close()
	check(descent_facts()==before,"Collecting the actual return report changes no physical, HP/fuel/RNG/gear/time or guidance owner")
	game._close_menu()
	return_descent_evidence.append({"case":"actual_return_descent_cold_and_include_save_ZIP","cold_compared_intervals":6,"archive":str(game.current_report.get("path","")),"mid_descent_altitude_m":game.surface.altitude(game.ship),"whole_game_factory_accepts_report":true})

func actual_full_return_descent()->void:
	if not await return_space_fixture():return
	var module:Script=load("res://scripts/native_orbit_return.gd")
	if not game.has_method("_begin_native_return_landing"):check(false,"Production Main exposes the task2 return-and-land command");leave_auto_fixture("Missing return descent");return
	var request_days:float=game.nav.elapsed_days;var request_fuel:=fuel();var request_hp:=thermal();var request_gear:Dictionary=game.landing_gear.snapshot()
	var returned:Dictionary=module.prepare_return(game.native_orbit_trial,game.ship,game.nav,game.landing_gear,game.world)
	check(returned.get("ok",false),"Full descent starts at a genuinely flown valid inverse boundary")
	game._refresh_hud();game._update_flight_controls();await frame()
	check(game.flight_console.buttons.has("auto") and not game.flight_console.buttons.auto.disabled,"The retained lower console enables actual return-and-land guidance from space")
	await tap(game.flight_console.buttons.auto,971)
	check(game._native_surface_active() and not game._native_orbit_active() and pilot_active() and current_pilot().mode()=="return_landing","Actual space Auto performs a checked return and arms high-descent guidance")
	if not pilot_active() or not game._native_surface_active():leave_auto_fixture("Return descent request rejected");return
	check(game.ship.position==returned.candidate_ship.position and game.ship.velocity==returned.candidate_ship.velocity and game.ship.attitude==returned.candidate_ship.attitude,"Starting return guidance retains exactly the physical inverse-boundary pose")
	check(game.nav.elapsed_days==request_days and fuel()==request_fuel and thermal()==request_hp and game.landing_gear.snapshot()==request_gear,"The combined return-and-land request spends no extra fuel/HP/RNG/gear/time and performs no descent interval")
	var start_altitude:float=game.surface.altitude(game.ship);var before:=auto_state();var owners:=trial_owners();var original_pilot:RefCounted=current_pilot()
	var predicted:Dictionary=original_pilot.advance(game.ship,game.nav,game.landing_gear,game.surface,0.5)
	check(predicted.get("ok",false) and auto_state()==before and trial_owners()==owners and current_pilot()==original_pilot,"The first long-descent step prepares on private owners without touching the live inverse state")
	if not predicted.get("ok",false):leave_auto_fixture("Return descent preparation rejected");return
	game._tick(0.5,Vector2.ZERO,0)
	check(game.ship.snapshot()==predicted.candidate_ship.snapshot() and game.surface.snapshot()==predicted.candidate_surface.snapshot() and game.nav.snapshot().source_hyperdrive==predicted.candidate_nav.snapshot().source_hyperdrive and game.nav.elapsed_days==request_days+0.5/86400.0,"Main publishes exactly one prepared descent/HP/fuel/time interval")
	check(not gear().requested_down and int(gear().position_u16)==0,"High return descent begins with actual gear retracted")
	var intervals:=1;var first_deployment_height:=-1.0;var fastest_down:=0.0;var largest_step:=0.0;var previous_position:Vector3=game.ship.position;var safe:=true;var high_gear_stowed:=true;var saw_cold:=false
	for index in range(5000):
		if not pilot_active() or game.surface.landed:break
		var altitude:float=game.surface.altitude(game.ship);var days:float=game.nav.elapsed_days
		game._tick(0.5,Vector2.ZERO,0);intervals+=1
		if not game.source_contact_error.is_empty() or game.ship.hull!=100 or game.nav.elapsed_days!=days+0.5/86400.0:safe=false;break
		largest_step=maxf(largest_step,game.ship.position.distance_to(previous_position));previous_position=game.ship.position;fastest_down=maxf(fastest_down,-game.ship.velocity.y)
		if altitude>600 and gear().requested_down:high_gear_stowed=false
		if first_deployment_height<0 and gear().requested_down:first_deployment_height=altitude
		if not saw_cold and intervals>=100:
			saw_cold=true;await inspect_cold_descent_and_report();previous_position=game.ship.position
	check(safe and game.surface.landed and not pilot_active(),"The complete genuinely flown twenty-kilometre return descent reaches accepted original parking without an interval failure")
	check(game.surface.native_session.phase()=="parked" and gear().requested_down and gear().deployed,"Completion requires real F576/F575 parked contact and physically deployed gear")
	check(game.ship.hull==100 and int(thermal().hull_u16)==400 and fuel()!=request_fuel,"The fitted return descent retains genuine source hull while spending actual propulsion fuel")
	check(high_gear_stowed and first_deployment_height>=0 and first_deployment_height<=300.5,"Gear stays retracted high above the ground and first receives a real deployment command only at the near-surface threshold")
	check(fastest_down>20 and fastest_down<=61 and largest_step<40,"Long descent uses a bounded higher-speed phase with real interval movement and braking rather than relocating to the ground")
	check(start_altitude>19000 and game.ship.position.y<returned.candidate_ship.position.y-19000 and game.nav.elapsed_days>request_days,"The accepted landing follows an actual timed twenty-kilometre trajectory from the inverse pose")
	check(saw_cold and not flown_descent_template.is_empty(),"The complete physical trajectory includes tested cold recovery and diagnostic collection")
	ordinary_unchanged("Full flown return descent")
	return_descent_evidence.append({"case":"actual_console_return_and_full_native_descent","initial_altitude_m":start_altitude,"native_intervals_excluding_cold_controls":intervals,"interval_seconds":0.5,"first_gear_deployment_height_m":first_deployment_height,"maximum_downward_speed_mps":fastest_down,"largest_accepted_step_m":largest_step,"raw_hull":thermal().hull_u16,"parked_source_generation":game.surface.native_session.generation(),"original_contact_decided_completion":true})
	leave_auto_fixture("Full flown return descent")

func restore_flown_descent()->bool:
	if flown_descent_template.is_empty():check(false,"Control cases require an actually flown high return descent");return false
	if not await orbital_entry_fixture():return false
	var loaded:Dictionary=game._decode_state(flown_descent_template.duplicate(true))
	check(not loaded.is_empty(),"The production decoder accepts the actually flown high-return control snapshot")
	if loaded.is_empty():leave_auto_fixture("Rejected high-return control");return false
	game._commit_state(loaded);game._apply_system();game._close_menu()
	return pilot_active() and current_pilot().mode()=="return_landing"

func return_pause_cancel_and_empty_fuel()->void:
	if not await restore_flown_descent():return
	var before:=auto_state();var owners:=trial_owners();game._toggle_pause();game._advance_controls(2);game._tick(0.5,Vector2.ZERO,0)
	check(pilot_active() and auto_state()==before and trial_owners()==owners,"Pause freezes active high-return guidance and every physical/source owner")
	game._toggle_pause();var days:float=game.nav.elapsed_days;var source_fuel:=fuel();var source_hp:=thermal();var position:Vector3=game.ship.position
	game._brake()
	check(not pilot_active() and game.ship.position==position and game.nav.elapsed_days==days and fuel()==source_fuel and thermal()==source_hp,"Actual Brake cancels high return without spending a physical interval or snapping position")
	check(game._begin_native_return_landing() and pilot_active(),"A valid returned native surface can resume long-descent guidance after manual cancellation")
	game._tick(0.5,Vector2(0.2,0),0)
	check(not pilot_active() and game.source_contact_error.is_empty() and game.nav.elapsed_days==days+0.5/86400.0,"Actual manual steering cancels return guidance and continues one ordinary native interval")
	return_descent_evidence.append({"case":"actual_return_pause_and_manual_cancel","manual_commands":["Brake","steering"],"physical_interval_after_manual_input":true})
	leave_auto_fixture("Paused/cancelled return descent")
	if not await restore_flown_descent():return
	var dry:Dictionary=copied(payload());dry.erase("native_autopilot_session");dry.navigation.source_hyperdrive.fuel_system.jet_raw_u32=0;dry.navigation.source_hyperdrive.fuel_system.disabled_axes_mask_u8=0x15;dry.navigation.source_hyperdrive.fuel_system.status_u16=1
	var loaded:Dictionary=game._decode_state(dry)
	check(not loaded.is_empty(),"The actual decoder admits an explicitly exhausted source fuel owner at a valid returned airborne pose")
	if loaded.is_empty():leave_auto_fixture("Rejected exhausted return fixture");return
	game._commit_state(loaded);game._apply_system();game._close_menu();before=auto_state();owners=trial_owners()
	check(not game._begin_native_return_landing() and not pilot_active() and auto_state()==before and trial_owners()==owners,"A real exhausted upward-thrust tank cannot arm return guidance or partially change its physical/source owners")
	ordinary_unchanged("Exhausted return guidance")
	return_descent_evidence.append({"case":"explicit_source_empty_return_fuel_rejected","fixture_changes_source_fuel_only":true,"physical_pose_unmoved":true,"source_disabled_axes_u8":fuel().disabled_axes_mask_u8})
	leave_auto_fixture("Exhausted return descent")

func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires private capture mode");quit(1);return
	root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main failed to load");game.free();quit(1);return
	game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	check(game.automated and not game.saving_enabled,"Actual return-descent Main tests use isolated capture mode without player saves")
	await actual_full_return_descent();await return_pause_cancel_and_empty_fuel()
	var sources:Dictionary={}
	for path:String in ["scripts/main.gd","scripts/native_orbit_return.gd","scripts/native_orbit_trial.gd","scripts/native_surface_autopilot.gd","scripts/native_landing_trial.gd","scripts/native_surface_model.gd","scripts/source_natural_contact_session.gd","scripts/source_native_surface_provider.gd","scripts/source_landing_gear_session.gd","tests/test_native_return_descent_main.gd","tests/test_native_return_main.gd","tests/test_native_orbit_main.gd","tests/test_native_ascent_main.gd","tests/test_native_autopilot_main.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RETURN_DESCENT_MAIN_REPORT.get_base_dir()));var report:=FileAccess.open(RETURN_DESCENT_MAIN_REPORT,FileAccess.WRITE)
	if report:report.store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":return_descent_evidence,"sources":sources,"scope":"Task2 actual Main protected flown20km outbound, real console inverse return and full powered high descent into original F576/F575 park, genuine gear schedule, no frame-boundary HP/fuel/time step, exact mid-descent cold continuation, actual include-save ZIP, pause/manual cancellation/empty source-fuel rejection and exact six-owner ordinary-flight restoration. Fixtures explicitly labelled; no full original autopilot, stationframe continuity, universal terrain, Android or FPS claim."},"\t"))
	game.queue_free();await frame();print("Native return descent Main: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
