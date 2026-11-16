extends "res://tests/test_native_orbit_main.gd"
# Task1 production Main: a genuinely flown native20km ascent returns through
# the inverse frame boundary, without initialize_from's explicit50m placement.
const RETURN_MAIN_REPORT:="res://build/current-test-reports/native-return-main.json"
const ReturnPhone=preload("res://scripts/source_surface_contact_bridge.gd")
const ReturnSpin=preload("res://scripts/source_fuel_contact.gd")
var native_return_evidence:Array=[]
var native_return_space_template:Dictionary={}

func return_space_fixture()->bool:
	if native_return_space_template.is_empty():
		if not await orbital_park_fixture():return false
		var flown:=await fly_native_orbital_departure()
		if flown.is_empty():leave_auto_fixture("Rejected return outbound fixture");return false
		native_return_space_template=copied(payload())
		native_return_evidence.append({"case":"actual_protected_outbound_fixture","flight":flown,"initial_placement_is_labelled_fixture":true,"post_trial_pose_patched":false})
		return true
	if not await orbital_entry_fixture():return false
	var restored:Dictionary=game._decode_state(native_return_space_template.duplicate(true))
	check(not restored.is_empty(),"The production whole-game factory accepts the genuinely flown return-space fixture")
	if restored.is_empty():leave_auto_fixture("Rejected saved return fixture");return false
	game._commit_state(restored);game._apply_system();game._close_menu()
	return game._native_orbit_active()

func _forward_world(surface:RefCounted,ship:RefCounted,world:RefCounted,days:float)->PackedFloat64Array:
	var chart:Basis=surface.globe.basis_at(surface.globe.latitude,surface.globe.longitude)
	var fixed:=ReturnPhone.to_bodyfixed_point(chart,float(surface.globe.radius),ship.position)
	var rotation:Dictionary=ReturnSpin._basis_readonly(world,world.by_id[str(world.focus_id)],days)
	if fixed.size()!=3 or rotation.is_empty():return PackedFloat64Array()
	var matrix:Basis=rotation.basis;var center:Vector3=world.local_meters(str(world.focus_id),days);var result:=PackedFloat64Array()
	for axis in range(3):result.append(float(center[axis])+float(matrix.x[axis])*fixed[0]+float(matrix.y[axis])*fixed[1]+float(matrix.z[axis])*fixed[2])
	return result

func return_facts()->Dictionary:
	return copied({"flight":game.ship.snapshot(),"surface":game.surface.snapshot(),"gear":game.landing_gear.snapshot(),"source_owner":game.nav.snapshot().source_hyperdrive,"elapsed_days":game.nav.elapsed_days})

func actual_inverse_handoff_and_console()->void:
	if not await return_space_fixture():return
	var module:Script=load("res://scripts/native_orbit_return.gd")
	if module==null or not game.has_method("_begin_native_surface_return"):check(false,"The return module and production Main command are installed");leave_auto_fixture("Missing return implementation");return
	game._process(1.0/60.0);game._refresh_hud();game._update_flight_controls()
	var before:=orbit_state();var owners:=orbit_owners();var old_clock:float=game.nav.elapsed_days;var old_fuel:=fuel();var old_hp:=thermal();var old_gear:Dictionary=game.landing_gear.snapshot();var old_orbit:RefCounted=game.native_orbit_trial
	var position_before:PackedFloat64Array=old_orbit._position_f64.duplicate();var prior_world:RefCounted=game.world
	var world_before:=var_to_bytes([prior_world.snapshot(),prior_world.native_evaluation_count,prior_world._native_cache_day,prior_world._native_cache_tick])
	var prepared:Dictionary=module.prepare_return(old_orbit,game.ship,game.nav,game.landing_gear,game.world)
	check(prepared.get("ok",false),"The genuine outbound pose prepares an inverse surface boundary")
	check(orbit_state()==before and orbit_owners()==owners and game.native_orbit_trial==old_orbit,"Preparing the inverse boundary preserves every live orbital owner and exact state")
	check(var_to_bytes([prior_world.snapshot(),prior_world.native_evaluation_count,prior_world._native_cache_day,prior_world._native_cache_tick])==world_before,"Preparing the inverse frame cannot mutate the old World spin or geometry cache")
	if not prepared.get("ok",false):leave_auto_fixture("Rejected actual return");return
	game._toggle_pause()
	var frozen:=orbit_state();check(not game._begin_native_surface_return() and orbit_state()==frozen and orbit_owners()==owners,"A paused return command cannot publish a surface frame or consume time")
	game._toggle_pause();game._refresh_hud();game._update_flight_controls();await frame()
	check(game.flight_console.buttons.has("surface") and not game.flight_console.buttons.surface.disabled,"The retained bottom console exposes the real return-to-surface action")
	await tap(game.flight_console.buttons.surface,951)
	check(game._native_surface_active() and not game._native_orbit_active() and game._native_trial_active(),"Actual console return changes to native surface while retaining the separate trial")
	if not game._native_surface_active():leave_auto_fixture("Console return rejected");return
	check(game.ship.position==prepared.candidate_ship.position and game.ship.velocity==prepared.candidate_ship.velocity and game.ship.attitude==prepared.candidate_ship.attitude,"Main publishes exactly the prepared inverse position, velocity and attitude")
	check(game.nav.elapsed_days==old_clock and fuel()==old_fuel and thermal()==old_hp and game.landing_gear.snapshot()==old_gear,"Return frame conversion spends no extra fuel, gear interval, HP/RNG or celestial time")
	check(not game.surface.landed and game.surface.native_session.phase()=="free" and game.ship.surface_mode and not game.ship.docked and not game.ship.station_available,"Return produces an airborne original-contact surface without fabricated parking or station access")
	check(not pilot_active() and game.native_orbital_departure_requested==false,"Task1 return does not silently arm a descending or outbound autopilot")
	var forwarded:=_forward_world(game.surface,game.ship,game.world,game.nav.elapsed_days);var error:=0.0
	if forwarded.size()==3:
		for axis in range(3):error+=pow(forwarded[axis]-position_before[axis],2)
		error=sqrt(error)
	check(forwarded.size()==3 and error<0.1,"Independent forward projection returns to the carried Float64 orbital position within local Float32 rounding")
	check(game.surface.altitude(game.ship)>19000 and game.surface.altitude(game.ship)<21000,"Inverse return preserves the real twenty-kilometre altitude instead of placing at the entry50m fixture")
	check(not payload().is_empty() and game._decode_primary_state(copied(payload())).is_empty(),"The inverse surface is serializable and remains excluded from ordinary progress saves")
	ordinary_unchanged("Inverse native return")
	native_return_evidence.append({"case":"actual_console_inverse_boundary","position_roundtrip_error_m":error,"surface_altitude_m":game.surface.altitude(game.ship),"clock_fuel_hp_gear_preserved":true,"outbound_f64_position":[position_before[0],position_before[1],position_before[2]],"original_owners_unmutated":true})
	leave_auto_fixture("Actual inverse return")

func return_cold_and_repeated_boundary()->void:
	if not await return_space_fixture():return
	check(game._begin_native_surface_return() and game._native_surface_active(),"A genuine saved space trial returns by the production menu command")
	if not game._native_surface_active():leave_auto_fixture("Cold return rejected");return
	var saved:=return_facts();var complete:Dictionary=copied(payload());var source_generation:int=game.surface.native_session.generation()
	check(not complete.is_empty() and not complete.has("native_orbit_session") and game._native_save_game(),"The separate SaveStore writes the valid reverse-transition native witness without stale orbital ownership")
	for index in range(3):game._tick(0.1,Vector2.ZERO,0)
	var continued:=return_facts()
	check(game._load_native_landing_trial() and game._native_surface_active() and return_facts()==saved,"Actual cold loading reproduces exact returned pose, native raw history, provider, HP/fuel/RNG, gear and time")
	for index in range(3):game._tick(0.1,Vector2.ZERO,0)
	check(return_facts()==continued and game.source_contact_error.is_empty(),"The next three returned native intervals equal warm continuation exactly")
	# Select the genuine zero-time return snapshot again for a second boundary.
	check(game.native_saves.write(complete) and game._load_native_landing_trial(),"The exact accepted reverse snapshot is selected as an explicit repeat-boundary control")
	var old_clock:float=game.nav.elapsed_days;var old_fuel:=fuel();var old_hp:=thermal();var local_position:Vector3=game.ship.position;var local_velocity:Vector3=game.ship.velocity
	check(game._begin_native_orbital_departure() and game._native_orbit_active(),"The genuinely returned high surface can depart by another checked zero-time coordinate boundary")
	check(game._begin_native_surface_return() and game._native_surface_active(),"A second return rebuilds a fresh valid native witness rather than reusing the first transition")
	if game._native_surface_active():
		check(game.surface.native_session.generation()>source_generation and not payload().is_empty() and not game._decode_state(copied(payload())).is_empty(),"Repeated frame changes advance verified source lineage and remain cold-restorable")
		check(game.nav.elapsed_days==old_clock and fuel()==old_fuel and thermal()==old_hp,"Repeated coordinate conversions cannot replay HP, fuel or time")
		check(game.ship.position.distance_to(local_position)<0.1 and game.ship.velocity.distance_to(local_velocity)<0.01,"Repeated inverse boundaries preserve local physical pose within declared rounding")
	native_return_evidence.append({"case":"actual_return_cold_and_repeated_boundaries","cold_compared_intervals":3,"native_generation_before_repeat":source_generation,"repeated_frame_changes_do_not_advance_clock":true})
	leave_auto_fixture("Cold and repeated inverse return")

func return_rejection_and_rollback()->void:
	if not await return_space_fixture():return
	var module:Script=load("res://scripts/native_orbit_return.gd")
	# Explicit invalid owner fixture: this is not a flown trajectory or a valid
	# saved space owner. The mismatch must reject before any state publication.
	game.ship.position.x+=1024.0
	var before:=orbit_state();var owners:=orbit_owners();var original:RefCounted=game.native_orbit_trial
	var rejected:Dictionary=module.prepare_return(original,game.ship,game.nav,game.landing_gear,game.world)
	check(not rejected.get("ok",false) and orbit_state()==before and orbit_owners()==owners,"A stale orbital pose cannot prepare a reverse handoff or partly mutate any owner")
	check(not game._begin_native_surface_return() and game._native_orbit_active() and not game.surface.active and game.native_orbit_trial==original,"Actual Main rejects invalid return while retaining the active orbital session")
	check(orbit_state()==before and orbit_owners()==owners,"A rejected Main return spends no pose/HP/RNG/fuel/time/gear and swaps no owner")
	ordinary_unchanged("Rejected inverse return")
	native_return_evidence.append({"case":"explicit_stale_orbit_pose_rejected_atomically","input_is_labelled_invalid_fixture":true,"ordinary_progress_unchanged":true})
	leave_auto_fixture("Rejected inverse return")

func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires private capture mode");quit(1);return
	root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main failed to load");game.free();quit(1);return
	game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	check(game.automated and not game.saving_enabled,"Actual inverse-return Main tests use private capture mode without player saves")
	await actual_inverse_handoff_and_console();await return_cold_and_repeated_boundary();await return_rejection_and_rollback()
	var sources:Dictionary={}
	for path:String in ["scripts/main.gd","scripts/native_orbit_return.gd","scripts/native_orbit_trial.gd","scripts/native_surface_autopilot.gd","scripts/native_landing_trial.gd","scripts/native_surface_model.gd","scripts/source_natural_contact_session.gd","scripts/source_native_surface_provider.gd","scripts/source_landing_gear_session.gd","tests/test_native_return_main.gd","tests/test_native_orbit_main.gd","tests/test_native_ascent_main.gd","tests/test_native_autopilot_main.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RETURN_MAIN_REPORT.get_base_dir()));var report:=FileAccess.open(RETURN_MAIN_REPORT,FileAccess.WRITE)
	if report:report.store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":native_return_evidence,"sources":sources,"scope":"Task1 actual Main protected flown20km source ascent followed by inverse Float64 space-to-native-surface boundary, retained bottom-console action, zero extra HP/fuel/gear/time, pure preparation, pause/stale-owner rollback, exact cold continuation, repeated boundary and full six-owner ordinary-flight restoration. No new source oracle, full objectbank, circularorbit, universal terrain, Android or FPS claim."},"\t"))
	game.queue_free();await frame();print("Native return Main: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
