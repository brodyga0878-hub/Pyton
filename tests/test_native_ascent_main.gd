extends "res://tests/test_native_autopilot_main.gd"
# Task2: a real powered ascent to a local target, before the separate orbit
# frame handoff. The parked reuse fixture is captured from actual autoland.
const ASCENT_MAIN_REPORT:="res://build/current-test-reports/native-ascent-main.json"
const ASCENT_TARGET_METRES:=1000.0
var ascent_main_evidence:Array=[]
var accepted_park_template:Dictionary={}

func ascent_fixture()->bool:
	if not await auto_fixture():return false
	if accepted_park_template.is_empty():
		game._toggle_auto()
		for index in range(1800):
			game._tick(0.1,Vector2.ZERO,0)
			if game.surface.landed or not game.source_contact_error.is_empty() or not pilot_active():break
		check(game.surface.landed and game.surface.native_session.phase()=="parked" and game.ship.hull==100,"Ascent setup first flies the actual automatic descent into a genuine source park")
		if not game.surface.landed:return false
		accepted_park_template=copied(payload())
	else:
		var decoded:Dictionary=game._decode_state(accepted_park_template.duplicate(true))
		check(not decoded.is_empty(),"A saved genuinely flown parked pose restores through the real whole-game factory")
		if decoded.is_empty():return false
		game._commit_state(decoded);game._apply_system();game._close_menu()
	check(game.surface.landed and game.surface.native_session.phase()=="parked" and gear().deployed and not pilot_active(),"Every ascent case begins in a validated source park with physically deployed gear")
	return true

func actual_powered_ascent()->void:
	if not await ascent_fixture():return
	var parked_pose:Vector3=game.ship.position;var parked_raw:PackedByteArray=game.surface.native_session.raw_body();var before_days:float=game.nav.elapsed_days;var before_fuel:=fuel();var before_hp:=thermal()
	game._refresh_hud();game._update_flight_controls();await frame()
	check(not game.flight_console.buttons.auto.disabled,"A parked native ship exposes the real lower-console automatic departure command")
	await tap(game.flight_console.buttons.auto,931)
	check(pilot_active() and current_pilot().mode()=="ascent","Actual parked Auto touch starts powered ascent guidance")
	check(game.surface.landed and game.ship.position==parked_pose and game.ship.velocity==Vector3.ZERO and game.surface.native_session.raw_body()==parked_raw,"Requesting automatic departure cannot move, rotate or release the accepted source park")
	check(game.nav.elapsed_days==before_days and fuel()==before_fuel and thermal()==before_hp and gear().deployed,"Departure request spends no time/fuel/HP and leaves physical gear down")
	if not pilot_active():leave_auto_fixture("Rejected ascent request");return
	var before:=auto_state();var owners:=trial_owners();var pilot:RefCounted=current_pilot();var predicted:Dictionary=pilot.advance(game.ship,game.nav,game.landing_gear,game.surface,0.1)
	check(predicted.get("ok",false) and auto_state()==before and trial_owners()==owners and current_pilot()==pilot,"The first powered ascent prepares on private owners without releasing the live park")
	if not predicted.get("ok",false):leave_auto_fixture("Rejected powered preparation");return
	game._tick(0.1,Vector2.ZERO,0)
	check(not game.surface.landed and game.surface.native_session.phase()=="free" and game.ship.velocity.y>0 and game.ship.position.y>parked_pose.y,"The first actual powered interval releases parking and creates physical upward motion")
	check(game.ship.snapshot()==predicted.candidate_ship.snapshot() and game.surface.snapshot()==predicted.candidate_surface.snapshot() and game.nav.snapshot().source_hyperdrive==predicted.candidate_nav.snapshot().source_hyperdrive and game.nav.elapsed_days==before_days+0.1/86400.0,"Main publishes exactly one prepared launch interval, including source state, fuel/RNG/HP and clock")
	check(gear().deployed and gear().requested_down,"The initial powered launch does not retract gear while still close to the ground")
	var intervals:=1;var first_retraction_height:=-1.0;var all_intervals_safe:=true;var previous_pose:Vector3=game.ship.position;var largest_step:=0.0
	for index in range(3500):
		if not pilot_active():break
		var days:float=game.nav.elapsed_days;var previous_height:float=game.surface.altitude(game.ship)
		game._tick(0.1,Vector2.ZERO,0);intervals+=1
		if not game.source_contact_error.is_empty() or game.ship.hull!=100 or game.nav.elapsed_days!=days+0.1/86400.0:all_intervals_safe=false;break
		largest_step=maxf(largest_step,game.ship.position.distance_to(previous_pose));previous_pose=game.ship.position
		if first_retraction_height<0 and not gear().requested_down:
			first_retraction_height=previous_height
	var final_height:float=game.surface.altitude(game.ship)
	check(all_intervals_safe and not pilot_active() and game.surface.active and not game.surface.landed,"Powered native ascent completes inside the existing source surface without fake parking or orbit transfer")
	check(absf(final_height-ASCENT_TARGET_METRES)<=1.0 and game.ship.velocity.length()<1.5,"Actual powered ascent settles at the one-kilometre target using control inputs")
	check(first_retraction_height>=30.0 and not gear().requested_down and int(gear().position_u16)==0,"Physical gear retracts only after the flown safe-clearance threshold")
	check(game.ship.hull==100 and int(thermal().hull_u16)==400 and fuel()!=before_fuel,"Full ascent preserves real source hull while consuming actual propulsion fuel")
	check(largest_step<20.0,"Accepted ascent movement remains a sequence of bounded powered intervals rather than a target-height relocation")
	ordinary_unchanged("Full powered native ascent")
	ascent_main_evidence.append({"case":"actual_console_powered_ascent","intervals":intervals,"target_height_m":ASCENT_TARGET_METRES,"final_render_altitude_m":final_height,"final_velocity_mps":[game.ship.velocity.x,game.ship.velocity.y,game.ship.velocity.z],"first_gear_retraction_height_m":first_retraction_height,"largest_accepted_position_step_m":largest_step,"raw_hull":thermal().hull_u16,"source_phase":game.surface.native_session.phase()})
	leave_auto_fixture("Full powered native ascent")

func parked_request_and_airborne_cold()->void:
	if not await ascent_fixture():return
	check(game._begin_departure_action() and pilot_active() and current_pilot().mode()=="ascent","Actual menu departure action prepares a saved automatic-launch intent")
	if not pilot_active():leave_auto_fixture("Rejected cold launch intent");return
	var parked_pose:Vector3=game.ship.position;var requested:=flight_facts();var request_payload:Dictionary=copied(payload())
	check(game.surface.landed and request_payload.has("native_autopilot_session") and game._native_save_game(),"An active departure intent can be saved while the exact source park is still held")
	game._tick(0.1,Vector2.ZERO,0)
	check(not game.surface.landed and game.ship.velocity.y>0,"Warm saved intent launches through real propulsion")
	var warm_launch:=flight_facts()
	# Auto-save on park release is deliberately superseded with the earlier
	# genuine parked request. This is a labelled cold-recovery fixture.
	check(game.native_saves.write(request_payload),"The exact validated parked request is selected for a cold recovery control")
	check(game._load_native_landing_trial() and game.surface.landed and game.ship.position==parked_pose and flight_facts()==requested,"Production cold loading retains the active request without releasing or moving its source park")
	game._tick(0.1,Vector2.ZERO,0)
	check(flight_facts()==warm_launch,"The first cold launch reproduces the warm powered interval exactly")
	for index in range(28):game._tick(0.1,Vector2.ZERO,0)
	check(pilot_active() and not game.surface.landed,"Airborne cold fixture is a genuinely continuing ascent")
	var airborne:=flight_facts();var airborne_payload:Dictionary=copied(payload())
	check(game._native_save_game(),"Actual Main saves the partly flown ascent and its source/gear state")
	for index in range(20):game._tick(0.1,Vector2.ZERO,0)
	var continued:=flight_facts();var later:Dictionary=copied(payload())
	check(game._load_native_landing_trial() and flight_facts()==airborne,"Actual cold factory restores the exact airborne ascent state")
	for index in range(20):game._tick(0.1,Vector2.ZERO,0)
	check(flight_facts()==continued,"Cold airborne guidance reproduces the next twenty source/HP/fuel/time/gear intervals exactly")
	var protected:=auto_state();var owners:=trial_owners();var stale:=later.duplicate(true);stale.native_autopilot_session=airborne_payload.native_autopilot_session
	check(game._decode_state(stale).is_empty() and auto_state()==protected and trial_owners()==owners,"A separately valid older ascent pilot cannot bind to a later physical/source history")
	ascent_main_evidence.append({"case":"parked_intent_and_airborne_cold_ascent","parked_request_restored":true,"first_powered_interval_exact":true,"airborne_pre_save_intervals":29,"cold_compared_intervals":20})
	leave_auto_fixture("Cold powered ascent")

func manual_cancel_and_empty_fuel()->void:
	if not await ascent_fixture():return
	check(game._begin_departure_action() and pilot_active(),"Cancellation fixture starts a genuine automatic departure request")
	if not pilot_active():leave_auto_fixture("Rejected cancellation request");return
	game._tick(0.1,Vector2.ZERO,0);check(not game.surface.landed,"Cancellation fixture first physically leaves the source park")
	game._brake();check(not pilot_active(),"The actual Brake command cancels automatic ascent")
	check(game._begin_departure_action() and pilot_active(),"Ascent can be requested again during valid airborne flight")
	var before_days:float=game.nav.elapsed_days;game._tick(0.1,Vector2(0.2,0),0)
	check(not pilot_active() and game.source_contact_error.is_empty() and game.nav.elapsed_days==before_days+0.1/86400.0,"Manual steering cancels ascent while its one manual interval continues normally")
	leave_auto_fixture("Cancelled powered ascent")
	if not await ascent_fixture():return
	var dry:Dictionary=copied(payload());dry.navigation.source_hyperdrive.fuel_system.jet_raw_u32=0;dry.navigation.source_hyperdrive.fuel_system.disabled_axes_mask_u8=0x15;dry.navigation.source_hyperdrive.fuel_system.status_u16=1
	var decoded:Dictionary=game._decode_state(dry)
	check(not decoded.is_empty(),"The actual whole-game decoder accepts an exhausted source owner at a valid source park")
	if decoded.is_empty():leave_auto_fixture("Rejected dry fixture");return
	game._commit_state(decoded);game._apply_system();game._close_menu()
	var protected:=auto_state();var owners:=trial_owners();var raw:PackedByteArray=game.surface.native_session.raw_body()
	check(not game._begin_departure_action() and not pilot_active(),"A real empty positive-nozzle tank cannot arm automatic ascent")
	game._toggle_auto()
	check(not pilot_active() and game.surface.landed and game.surface.native_session.raw_body()==raw and auto_state()==protected and trial_owners()==owners,"Repeated real Auto commands cannot invent upward thrust, release park, or consume fuel/time in an exhausted source state")
	check(not game._takeoff_action() and auto_state()==protected,"The manual takeoff command also respects the same unavailable source thrust")
	ascent_main_evidence.append({"case":"ascent_manual_cancel_and_source_empty_fuel","empty_source_mask_u8":fuel().disabled_axes_mask_u8,"park_retained":true,"ordinary_flight_isolated":true})
	leave_auto_fixture("Exhausted native park")

func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires private capture mode");quit(1);return
	root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main failed to load");game.free();quit(1);return
	game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	check(game.automated and not game.saving_enabled,"Actual ascent Main tests use isolated private capture mode")
	await actual_powered_ascent();await parked_request_and_airborne_cold();await manual_cancel_and_empty_fuel()
	var sources:Dictionary={}
	for path:String in ["scripts/main.gd","scripts/native_surface_autopilot.gd","scripts/native_landing_trial.gd","scripts/native_surface_model.gd","scripts/source_natural_contact_session.gd","scripts/source_native_surface_provider.gd","scripts/source_landing_gear_session.gd","tests/test_native_ascent_main.gd","tests/test_native_autopilot_main.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ASCENT_MAIN_REPORT.get_base_dir()));var report:=FileAccess.open(ASCENT_MAIN_REPORT,FileAccess.WRITE)
	if report:report.store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":ascent_main_evidence,"sources":sources,"scope":"Task2 production Main automatic powered ascent from actual/cold source park to local1000m target, gear clearance, exact cold launch/airborne continuation, manual cancellation, empty source fuel and ordinary-flight isolation. Task3 orbit-frame handoff is not exercised; no full original autopilot/Android/FPS claim."},"\t"))
	game.queue_free();await frame();print("Native ascent Main: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
