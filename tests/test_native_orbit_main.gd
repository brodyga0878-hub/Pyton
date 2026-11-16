extends "res://tests/test_native_ascent_main.gd"
# Task3 actual Main flow. Atmospheric protection is bought through the real
# existing bay UI before a labelled native50m entry, never patched into HP.
const ORBIT_MAIN_REPORT:="res://build/current-test-reports/native-orbit-main.json"
var orbit_main_evidence:Array=[]
var orbital_equipment_evidence:Dictionary={}
var protected_ordinary_template:Dictionary={}
var orbital_park_template:Dictionary={}
var actual_orbit_template:Dictionary={}

func orbital_entry_fixture()->bool:
	auto_fixture_index+=1;trial_directory="user://native-orbit-main-%d-%d"%[OS.get_process_id(),auto_fixture_index]
	fresh();game.settings.orbital_gravity=false
	if protected_ordinary_template.is_empty():
		var credits_before:int=game.ship.credits;var fitted_before:bool=bool(fuel().atmospheric_shielding_installed)
		await install_atmospheric_shielding()
		check(not fitted_before and fuel().atmospheric_shielding_installed and game.ship.credits<credits_before,"Orbital fixture buys real atmospheric shielding through the existing bay equipment button")
		orbital_equipment_evidence={"actual_bay_UI_purchase":true,"credits_before":credits_before,"credits_after":game.ship.credits,"credits_spent":credits_before-game.ship.credits,"atmospheric_shielding_installed":bool(fuel().atmospheric_shielding_installed),"hull_or_heat_patched":false}
		stage_natural("earth",5000,0);await game._enter_surface()
		check(game.surface.active and game.surface.source_surface(),"The fitted ship enters actual source Earth terrain before the explicit trial")
		if not game.surface.active:return false
		game.surface.globe.latitude=0;game.surface.globe.longitude=0;game.surface.landed=false;game.surface.landing=false;game.surface.taking_off=false;game.surface.cancel_vertical()
		game.ship.position=Vector3(0,game.surface.height_at(0,0)+game.surface.clearance(game.ship)+40,0);game.ship.velocity=Vector3.ZERO;game.ship.attitude=Quaternion.IDENTITY;game.ship.target_speed=0;game.ship.assisted=false
		# This placement is a fixture rather than a flown ordinary approach.
		# Synchronize its render/clearance anchor, then let the real v4 worker
		# publish its contact patch BEFORE saving the ordinary return baseline.
		game.surface.render_position=game.ship.position;game.surface.render_velocity=game.ship.velocity;game.surface._source_render_clearance=game.surface.altitude(game.ship)
		game._apply_system();var publication_started:=Time.get_ticks_msec()
		while not game.surface.snapshot().has("terrain_contact") and Time.get_ticks_msec()-publication_started<30000:
			game._sync_scene();await frame()
		check(game.surface.snapshot().has("terrain_contact"),"The labelled ordinary40m placement settles its actual v4 render/contact publication before the return baseline")
		game.surface.consume_render_frame_shift();protected_ordinary_template=copied(payload())
	else:
		var loaded:Dictionary=game._decode_state(protected_ordinary_template.duplicate(true))
		check(not loaded.is_empty(),"A genuinely fitted pre-trial source save restores through the whole-game factory")
		if loaded.is_empty():return false
		game._commit_state(loaded);game._apply_system()
	ordinary_store=RecordingStore.new();ordinary_store.directory=trial_directory+"/ordinary";game.saves=ordinary_store;game.native_saves.directory=trial_directory+"/native";game.native_saves.sequence=0;game.saving_enabled=true
	normal_owners=trial_owners();normal_state=trial_state()
	check(game._start_native_landing_trial(),"Actual Main starts a protected native trial while preserving the fitted ordinary flight")
	if not game._native_surface_active():return false
	game._close_menu();normal_save_generation=ordinary_store.sequence;normal_save_payload=ordinary_store.last_payload.duplicate(true)
	check(fuel().atmospheric_shielding_installed and not pilot_active(),"The isolated native trial retains purchased source protection without automatic guidance")
	return true

func orbital_park_fixture()->bool:
	if not await orbital_entry_fixture():return false
	if orbital_park_template.is_empty():
		game._toggle_auto()
		for index in range(1800):
			game._tick(0.1,Vector2.ZERO,0)
			if game.surface.landed or not game.source_contact_error.is_empty() or not pilot_active():break
		check(game.surface.landed and game.surface.native_session.phase()=="parked" and game.ship.hull==100,"The protected orbital fixture first flies the actual original-contact autoland")
		if not game.surface.landed:return false
		orbital_park_template=copied(payload())
	else:
		var loaded:Dictionary=game._decode_state(orbital_park_template.duplicate(true))
		check(not loaded.is_empty(),"The genuinely flown protected source park restores without fabricated contact flags")
		if loaded.is_empty():return false
		game._commit_state(loaded);game._apply_system();game._close_menu()
	return game.surface.landed and game.surface.native_session.phase()=="parked"

func orbit_facts()->Dictionary:
	var value:Dictionary=copied(payload())
	if value.is_empty():return {}
	return {"flight":value.flight,"source_owner":value.navigation.source_hyperdrive,"elapsed_days":game.nav.elapsed_days,"gear":value.gear_session,"surface":value.surface,"orbit":value.get("native_orbit_session",{})}
func orbit_state()->PackedByteArray:return var_to_bytes([trial_state(),orbit_facts(),game.get("native_orbital_departure_requested")])
func orbit_owners()->Array:return [game.ship,game.nav,game.world,game.surface,game.landing_gear,game.get("native_orbit_trial")]
func f64_values(encoded:String)->PackedFloat64Array:
	var raw:=encoded.hex_decode();var values:=PackedFloat64Array()
	for index in range(raw.size()/8):values.append(raw.decode_double(index*8))
	return values

func fly_native_orbital_departure(seconds:float=0.5)->Dictionary:
	if not game._native_surface_active():check(false,"Orbital departure helper requires an actual native surface flight");return {}
	var module:Script=load("res://scripts/native_orbit_trial.gd")
	var request_pose:Vector3=game.ship.position;var request_velocity:Vector3=game.ship.velocity;var request_days:float=game.nav.elapsed_days;var request_fuel:=fuel();var request_hp:=thermal()
	check(game._begin_native_orbital_departure(),"The actual separate In-space command requests a twenty-kilometre native ascent")
	check(pilot_active() and current_pilot().mode()=="ascent" and game.get("native_orbital_departure_requested")==true,"Orbital departure arms the real ascent controller and its explicit pending-handoff flag")
	check(game.ship.position==request_pose and game.ship.velocity==request_velocity and game.nav.elapsed_days==request_days and fuel()==request_fuel and thermal()==request_hp,"Requesting the orbital phase does not move the ship or spend an interval")
	if not pilot_active():return {}
	var intervals:=0;var boundary_expected:Dictionary={};var source_expected:Dictionary={};var prior_world:RefCounted;var prior_world_state:=PackedByteArray();var final_height:=-1.0;var safe:=true
	for index in range(5000):
		if not game._native_surface_active():break
		var altitude:float=game.surface.altitude(game.ship)
		# A lookahead is a private preparation, not an extra live interval.
		# Only inspect the few final braking steps rather than replaying flight.
		if altitude>19995.0 and pilot_active():
			var predicted:Dictionary=current_pilot().advance(game.ship,game.nav,game.landing_gear,game.surface,seconds)
			if predicted.get("ok",false) and not predicted.candidate_pilot.is_active() and predicted.candidate_pilot.phase()=="completed":
				source_expected=predicted;boundary_expected=module.prepare_handoff(predicted.candidate_ship,predicted.candidate_nav,predicted.candidate_gear,predicted.candidate_surface)
				prior_world=game.world;prior_world_state=var_to_bytes([game.world.snapshot(),game.world.native_evaluation_count,game.world._native_cache_day,game.world._native_cache_tick]);final_height=predicted.candidate_surface.altitude(predicted.candidate_ship)
		var days:float=game.nav.elapsed_days
		game._tick(seconds,Vector2.ZERO,0);intervals=index+1
		if not game.source_contact_error.is_empty() or game.ship.hull<=0 or game.nav.elapsed_days!=days+seconds/86400.0:safe=false;break
		if game._native_orbit_active():break
	check(safe and game._native_orbit_active() and game._native_trial_active() and not game.surface.active,"The actual powered ascent reaches a continuous space-frame handoff while remaining in the isolated trial")
	if not game._native_orbit_active():return {}
	check(not boundary_expected.is_empty() and boundary_expected.get("ok",false) and not source_expected.is_empty(),"The boundary is independently prepared from the actual final powered source interval")
	if boundary_expected.is_empty() or not boundary_expected.get("ok",false) or source_expected.is_empty():return {}
	check(game.nav.elapsed_days==source_expected.candidate_nav.elapsed_days and game.nav.snapshot().source_hyperdrive==source_expected.candidate_nav.snapshot().source_hyperdrive and game.landing_gear.snapshot()==source_expected.candidate_gear.snapshot(),"Coordinate handoff adds no HP/RNG/fuel/gear/time interval after the accepted powered ascent")
	check(game.ship.position==boundary_expected.candidate_ship.position and game.ship.velocity==boundary_expected.candidate_ship.velocity and game.ship.attitude==boundary_expected.candidate_ship.attitude,"Actual Main publishes the exact prepared affine position, velocity and attitude")
	check(var_to_bytes([prior_world.snapshot(),prior_world.native_evaluation_count,prior_world._native_cache_day,prior_world._native_cache_tick])==prior_world_state,"Preparing and publishing the new space frame does not mutate the old native World owner")
	check(not game.ship.surface_mode and not game.ship.docked and not game.ship.station_available and not game.ship.has_source_station() and not pilot_active() and game.get("native_orbital_departure_requested")==false,"The isolated space phase clears surface guidance without acquiring an unearned station or docking context")
	var receipt:Dictionary=boundary_expected.receipt;var ideal:=f64_values(str(receipt.ideal_position_f64_hex));var velocity:=f64_values(str(receipt.ideal_velocity_f64_hex))
	check(ideal.size()==3 and velocity.size()==3 and game.ship.position==Vector3(ideal[0],ideal[1],ideal[2]) and game.ship.velocity==Vector3(velocity[0],velocity[1],velocity[2]),"The frame boundary rounds the declared ideal affine pose to the actual Float32 ship coordinates")
	check(not receipt.clock_advanced and not receipt.fuel_advanced and not receipt.hp_applied and not receipt.position_snapped and not receipt.circular_orbit_inserted and not receipt.omega_cross_radius_added,"Boundary receipt explicitly preserves continuity and the limited velocity/orbit policy")
	ordinary_unchanged("Native-to-space handoff")
	return {"native_intervals":intervals,"interval_seconds":seconds,"native_boundary_altitude_m":final_height,"receipt":receipt.duplicate(true),"raw_hull":thermal().hull_u16,"boundary_preserved_owner_intervals":true}

func full_sequence_and_first_space_frame()->void:
	if not await orbital_park_fixture():return
	var completed:=await fly_native_orbital_departure()
	if completed.is_empty():leave_auto_fixture("Rejected full orbital sequence");return
	# Exercise the real presentation path before preparing the next interval;
	# merely loading the SceneTree would miss mutable World spin-cache effects.
	game._process(1.0/60.0);game._refresh_hud();game._update_flight_controls()
	check(not payload().is_empty() and game._native_orbit_active(),"A real Main render/control refresh leaves the new space owner usable and serializable")
	var module:RefCounted=game.native_orbit_trial;var before:=orbit_state();var owners:=orbit_owners();var days:float=game.nav.elapsed_days
	var predicted:Dictionary=module.prepare(game.ship,game.nav,game.landing_gear,game.world,0.1,Vector2.ZERO,0.0,0.1)
	check(predicted.get("ok",false) and orbit_state()==before and orbit_owners()==owners,"The first actual space interval prepares without changing any live orbital owner")
	if predicted.get("ok",false):
		game._tick(0.1,Vector2.ZERO,0,0.1)
		check(game.nav.elapsed_days==days+0.1/86400.0 and game.ship.snapshot()==predicted.candidate_ship.snapshot() and game.nav.snapshot().source_hyperdrive==predicted.candidate_nav.snapshot().source_hyperdrive and game.landing_gear.snapshot()==predicted.candidate_gear.snapshot(),"The first actual space tick publishes exactly one physical/HP/fuel/gear/time transaction")
	var scheduled_days:float=game.nav.elapsed_days;var generation:int=int(game.native_orbit_trial.diagnostics().generation)
	game._advance_controls(0.3)
	check(absf(game.nav.elapsed_days-scheduled_days-0.3/86400.0)<1e-14 and int(game.native_orbit_trial.diagnostics().generation)==generation+3,"The frame scheduler runs all three space substeps despite expected Ship and World owner replacements")
	check(game.flight_time._plan.is_empty() and game.flight_time.pending_real_seconds==0,"Accepted orbital frames leave no half-open plan or accumulated real-time debt")
	check(game.ship.hull==100 and not payload().is_empty(),"Legitimate atmospheric shielding preserves the fitted source hull through the full flown sequence")
	var low_start:Vector3=game.ship.position;var low_days:float=game.nav.elapsed_days;var low_saved:Dictionary=copied(payload());var low_position:=f64_values(str(low_saved.native_orbit_session.position_f64_hex))
	game._set_speed(1.0)
	var low_motion_safe:=true
	for index in range(360):
		game._tick(1.0/60.0,Vector2.ZERO,0)
		if not game.source_contact_error.is_empty():low_motion_safe=false;break
		if index%60==59:game._process(1.0/60.0)
	var low_after:Dictionary=copied(payload());var carried:=f64_values(str(low_after.get("native_orbit_session",{}).get("position_f64_hex","")));var accumulated_distance:=0.0
	if carried.size()==3 and low_position.size()==3:
		for axis in range(3):accumulated_distance+=pow(carried[axis]-low_position[axis],2)
		accumulated_distance=sqrt(accumulated_distance)
	check(low_motion_safe and carried.size()==3 and accumulated_distance>0.5 and game.ship.position!=low_start,"Actual Main retains sub-Float32 motion at one metre per second through360 real60Hz space intervals")
	check(absf(game.nav.elapsed_days-low_days-6.0/86400.0)<1e-14 and game.ship.velocity.length()<5.0,"Small-speed movement accumulates real time and distance without inventing a larger velocity")
	game._set_speed(0.0)
	actual_orbit_template=copied(payload())
	completed.case="actual_Main_autoland_powered20km_affine_handoff_and_space";completed.equipment_service=orbital_equipment_evidence.duplicate(true);completed.first_space_interval_once=true;completed.actual_small_speed_intervals=360;completed.actual_small_speed_f64_distance_m=accumulated_distance
	orbit_main_evidence.append(completed)
	leave_auto_fixture("Full isolated native/space sequence")

func orbit_fixture()->bool:
	if actual_orbit_template.is_empty():check(false,"A genuinely flown space template must exist before cold-space controls");return false
	if not await orbital_entry_fixture():return false
	var loaded:Dictionary=game._decode_state(actual_orbit_template.duplicate(true))
	check(not loaded.is_empty(),"A genuinely flown orbital save is accepted by the real whole-game factory")
	if loaded.is_empty():return false
	game._commit_state(loaded);game._apply_system();game._close_menu()
	check(game._native_orbit_active() and game._native_trial_active() and not game.surface.active,"Cold orbital state resumes as isolated space flight rather than ordinary progress")
	return game._native_orbit_active()

func cold_orbit_and_transaction_guards()->void:
	if not await orbit_fixture():return
	game._process(1.0/60.0)
	var saved:=orbit_facts();var value:Dictionary=copied(payload())
	check(not saved.is_empty() and value.has("native_orbit_session") and not value.has("native_autopilot_session") and game._native_save_game(),"Actual native SaveStore writes the complete exact space owner without a stale surface pilot")
	for index in range(2):game._tick(0.1,Vector2(0.05,0),0.02,0.05)
	var expected:=orbit_facts()
	check(game._load_native_landing_trial() and game._native_orbit_active() and orbit_facts()==saved,"Actual native cold loading preserves exact space pose, quaternion, day, HP/fuel/RNG, World and gear")
	for index in range(2):game._tick(0.1,Vector2(0.05,0),0.02,0.05)
	check(orbit_facts()==expected,"The next two real orbital physics intervals match warm continuation exactly")
	var protected:=orbit_state();var owners:=orbit_owners();var malformed:=value.duplicate(true);malformed.native_orbit_session={}
	check(game._decode_state(malformed).is_empty(),"A present empty orbital extension cannot silently become an ordinary flight")
	malformed=value.duplicate(true);malformed.native_orbit_session=null
	check(game._decode_state(malformed).is_empty(),"A present non-object orbital extension is rejected")
	malformed=ordinary_store.last_payload.duplicate(true);malformed.native_orbit_session=value.native_orbit_session
	check(game._decode_state(malformed).is_empty(),"A valid orbital receipt cannot attach to a separately valid unrelated normal surface")
	check(game._decode_primary_state(value).is_empty() and orbit_state()==protected and orbit_owners()==owners,"Orbital saves stay out of the normal store and failed decode changes no live owner")
	var prepared:Dictionary=game.native_orbit_trial.prepare(game.ship,game.nav,game.landing_gear,game.world,1.0)
	check(not prepared.get("ok",false) and orbit_state()==protected and orbit_owners()==owners,"An out-of-budget space candidate rejects without advancing World, fuel, clock, gear or pose")
	orbit_main_evidence.append({"case":"actual_space_cold_and_guards","exact_compared_intervals":2,"normal_store_rejects_orbit":true,"out_of_budget_interval_atomic":true})
	leave_auto_fixture("Cold isolated space continuation")

func orbital_intent_and_premature_guard()->void:
	if not await orbital_park_fixture():return
	var module:Script=load("res://scripts/native_orbit_trial.gd")
	var protected:=auto_state();var owners:=trial_owners();var world_before:=var_to_bytes([game.world.snapshot(),game.world.native_evaluation_count,game.world._native_cache_day,game.world._native_cache_tick])
	var early:Dictionary=module.prepare_handoff(game.ship,game.nav,game.landing_gear,game.surface)
	check(not early.get("ok",false) and auto_state()==protected and trial_owners()==owners and var_to_bytes([game.world.snapshot(),game.world.native_evaluation_count,game.world._native_cache_day,game.world._native_cache_tick])==world_before,"An actual premature handoff rejects without releasing park or mutating the World")
	check(game._begin_native_orbital_departure() and game.get("native_orbital_departure_requested")==true,"A new genuine source-park request records orbital intent")
	for index in range(10):game._tick(0.5,Vector2.ZERO,0)
	check(game._native_surface_active() and pilot_active() and game.get("native_orbital_departure_requested")==true,"Partly flown orbital departure retains its intent before the handoff")
	var value:Dictionary=copied(payload());var saved:=flight_facts()
	check(value.get("native_orbital_departure_requested")==true and value.has("native_autopilot_session") and game._native_save_game(),"The whole-game payload saves orbital intent together with its exact active ascent owner")
	for index in range(4):game._tick(0.5,Vector2.ZERO,0)
	var continued:=flight_facts()
	check(game._load_native_landing_trial() and game.get("native_orbital_departure_requested")==true and flight_facts()==saved,"Cold source-ascent loading retains the pending orbital handoff flag")
	for index in range(4):game._tick(0.5,Vector2.ZERO,0)
	check(flight_facts()==continued and game.get("native_orbital_departure_requested")==true,"Cold pending departure reproduces its next four actual powered intervals")
	game._brake()
	check(not pilot_active() and game.get("native_orbital_departure_requested")==false,"Manual cancellation clears pending orbital intent before it can trigger a later handoff")
	var malformed:=value.duplicate(true);malformed.erase("native_autopilot_session")
	check(game._decode_state(malformed).is_empty(),"An orbital request cannot restore without its bound active ascent pilot")
	orbit_main_evidence.append({"case":"pending_orbital_intent_cold_and_early_guard","pre_save_intervals":10,"exact_compared_intervals":4,"premature_handoff_atomic":true})
	leave_auto_fixture("Pending orbital departure")
	if not await auto_fixture():return
	check(not fuel().atmospheric_shielding_installed,"The preflight rejection control uses the actual unprotected starter loadout")
	protected=auto_state();owners=trial_owners()
	check(not game._begin_native_orbital_departure() and not pilot_active() and game.get("native_orbital_departure_requested")==false and auto_state()==protected and trial_owners()==owners,"Atmospheric orbital departure rejects an unprotected source ship without inventing shielding or damaging/moving it")
	orbit_main_evidence.append({"case":"actual_unshielded_atmospheric_departure_rejected","equipment_autofitted":false})
	leave_auto_fixture("Unprotected orbital request")

func actual_orbit_report()->void:
	if not await orbit_fixture():return
	game.diagnostics.directory=trial_directory+"/diagnostics";game.diagnostics.reports_directory=trial_directory+"/reports";game.diagnostics.engine_logs_directory=trial_directory+"/empty-logs"
	check(game.diagnostics.initialize("native-orbit-main-validation"),"Actual space diagnostic collector initializes in private test directories")
	var before:=orbit_state();var complete:Dictionary=copied(payload())
	game.report_include_save=true;game.report_draft="После автопосадки, взлёта и перехода в космическую систему координат: точная поза, время и исходное состояние корабля."
	game._show_bug_report();await game._create_bug_report(false)
	check(game.current_report.get("ok",false),"Actual report button creates a ZIP containing the new space phase")
	if game.current_report.get("ok",false):
		var zip:=ZIPReader.new();check(zip.open(str(game.current_report.path))==OK,"The actual orbital report ZIP opens")
		check(zip.file_exists("game-save.json"),"The optional complete orbital save is present in the real report")
		if zip.file_exists("game-save.json"):
			var saved:Dictionary=JSON.parse_string(zip.read_file("game-save.json").get_string_from_utf8())
			check(saved==complete and saved.native_orbit_session==complete.native_orbit_session,"The real archive preserves all exact space state, native lineage and handoff receipt")
			check(not game._decode_state(saved).is_empty(),"The production whole-game factory accepts the orbital save directly from its report ZIP")
		zip.close()
	check(orbit_state()==before,"Producing a report advances no physical or source/space owner")
	orbit_main_evidence.append({"case":"actual_space_include_save_ZIP","archive":str(game.current_report.get("filename","")),"full_space_lineage_transported":true})
	leave_auto_fixture("Space diagnostic report")

func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires private capture mode");quit(1);return
	root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main failed to load");game.free();quit(1);return
	game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	check(game.automated and not game.saving_enabled,"Actual orbital Main tests start in isolated capture mode")
	await full_sequence_and_first_space_frame();await cold_orbit_and_transaction_guards();await orbital_intent_and_premature_guard();await actual_orbit_report()
	var sources:Dictionary={}
	for path:String in ["scripts/main.gd","scripts/native_surface_autopilot.gd","scripts/native_orbit_trial.gd","scripts/native_landing_trial.gd","scripts/native_surface_model.gd","scripts/source_natural_contact_session.gd","scripts/source_native_surface_provider.gd","scripts/source_landing_gear_session.gd","scripts/source_orbit_surface_guard.gd","tests/test_native_orbit_main.gd","tests/test_native_ascent_main.gd","tests/test_native_autopilot_main.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ORBIT_MAIN_REPORT.get_base_dir()));var report:=FileAccess.open(ORBIT_MAIN_REPORT,FileAccess.WRITE)
	if report:report.store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":orbit_main_evidence,"sources":sources,"scope":"Task3 actual Main protected autoland, real powered20km ascent, continuous affine space handoff, exactly one subsequent space/fuel/time interval, real render/control refresh, scheduler, cold space/ascent intent, early/typed guards, real ZIP and original-flight isolation. Atmospheric protection bought through actual source bay UI; no circular-orbit insertion/full original dispatcher/Android/FPS claim."},"\t"))
	game.queue_free();await frame();print("Native orbit Main: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
