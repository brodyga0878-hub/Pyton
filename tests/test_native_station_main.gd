extends "res://tests/test_native_return_main.gd"
# A real source50m -> park ->20km outbound supplies the retained lineage.
# The subsequent near-station placement is an EXPLICIT TEST FIXTURE. The
# many-megametre Earth-to-station journey is not claimed to have been flown.
const STATION_MAIN_REPORT:="res://build/current-test-reports/native-station-main.json"
var station_main_evidence:Array=[]
var station_fixture_port:Dictionary={}

func station_session()->RefCounted:return game.get("native_station_trial")
func station_active()->bool:
	var session:RefCounted=station_session()
	return session!=null and session.is_active()
func station_owners()->Array:return [game.ship,game.nav,game.world,game.surface,game.landing_gear,station_session()]
func station_facts()->Dictionary:
	var session:RefCounted=station_session()
	return copied({"flight":game.ship.snapshot(),"source_owner":game.nav.snapshot().source_hyperdrive,"world":game.world.snapshot(),"surface":game.surface.snapshot(),"gear":game.landing_gear.snapshot(),"days_f64_hex":NativeSurfaceModel._native_floats([game.nav.elapsed_days],8),"autopilot":game.ship.autopilot,"station":session.snapshot(game.ship,game.nav,game.world,game.landing_gear) if session!=null else {}})
func station_state()->PackedByteArray:return var_to_bytes(station_facts())
func current_earth_station()->Dictionary:
	for port:Dictionary in game.world.settlements:
		if int(port.type_code) in [32,33,34] and str(port.parent)==str(game.world.focus_id):return port.duplicate(true)
	return {}

func labelled_near_station_fixture(closed:bool=true)->bool:
	var frame_module:Script=load("res://scripts/native_station_frame.gd")
	var orbit_module:Script=load("res://scripts/native_orbit_trial.gd")
	if frame_module==null or orbit_module==null or not game._native_orbit_active():return false
	# One genuinely accepted interval establishes generation>0 before this
	# labelled fixture. Generation0 is reserved for the exact real outbound.
	game._tick(0.1,Vector2.ZERO,0)
	check(game.source_contact_error.is_empty() and game.native_orbit_trial._generation>0,"Near-station fixture retains a genuinely accepted nonzero orbital generation")
	station_fixture_port=current_earth_station()
	check(not station_fixture_port.is_empty(),"The actual retained parent body has a real source orbital station")
	if station_fixture_port.is_empty():return false
	var station_world:RefCounted=orbit_module._fork_world(game.world)
	station_world.site_id=str(station_fixture_port.id);station_world.pending_id="";station_world.pending_site_id="";station_world.transfer_remaining=0.0
	var basis:Basis=station_world.source_station_basis(game.nav.elapsed_days)
	if closed:
		# The closed door is part of the explicit fixture, not a flown command.
		var spin:Dictionary=station_world.station_state_by_site[str(station_fixture_port.id)].duplicate(true)
		spin.door_u16=65535;spin.status_u8=0
		game.world.station_state_by_site[str(station_fixture_port.id)]=spin
		station_world.station_state_by_site[str(station_fixture_port.id)]=spin.duplicate(true)
	var geometry:Dictionary=station_world.source_station_geometry(game.nav.elapsed_days)
	check(not geometry.is_empty() and geometry.get("approach_waypoint") is Vector3,"The explicit fixture uses the actual compiled source station approach waypoint")
	if geometry.is_empty() or not geometry.get("approach_waypoint") is Vector3:return false
	var waypoint:Vector3=geometry.approach_waypoint
	var station_local:Vector3=waypoint+Vector3(0,0,100)
	var station_position:Vector3=game.ship.STATION+basis*station_local
	var mapped:Dictionary=frame_module.map_between(station_world,game.world,PackedFloat64Array([station_position.x,station_position.y,station_position.z]),Vector3.ZERO,game.nav.elapsed_days)
	check(mapped.get("ok",false),"The labelled source outer-waypoint fixture maps to the retained body frame using actual source origins and velocities")
	if not mapped.get("ok",false):return false
	var point:PackedFloat64Array=mapped.position_f64;var velocity:PackedFloat64Array=mapped.velocity_f64
	game.ship.position=Vector3(point[0],point[1],point[2]);game.ship.velocity=Vector3(velocity[0],velocity[1],velocity[2]);game.ship.attitude=basis.get_rotation_quaternion().normalized()
	game.ship.assisted=true;game.ship.target_speed=0;game.ship.autopilot=false
	game.native_orbit_trial._position_f64=point.duplicate();game.native_orbit_trial._bind(game.ship,game.nav,game.world,game.landing_gear)
	check(not payload().is_empty() and not game._decode_state(copied(payload())).is_empty(),"The explicit near-station fixture remains an honestly labelled cold-valid advanced orbital owner")
	station_main_evidence.append({"case":"explicit_near_station_setup","site_id":str(station_fixture_port.id),"source_parent":str(station_fixture_port.parent),"placement_is_fixture_not_flown":true,"planet_to_station_journey_flown":false,"station_local_axis_m":station_local.z,"actual_source_waypoint_m":[waypoint.x,waypoint.y,waypoint.z],"fixture_outside_source_waypoint_m":100.0,"closed_door_is_fixture":closed,"outbound_original_lineage_retained":true})
	return true

func fly_station_steps(count:int)->bool:
	for index in range(count):
		var before:float=game.nav.elapsed_days
		game._tick(0.1,Vector2.ZERO,0)
		if not station_active() or not game.source_contact_error.is_empty() or game.ship.hull!=100 or game.nav.elapsed_days!=before+0.1/86400.0:return false
	return true

func actual_station_handoff_dock_service_reverse()->void:
	if not await return_space_fixture():return
	var station_module:Script=load("res://scripts/native_station_trial.gd")
	var frame_module:Script=load("res://scripts/native_station_frame.gd")
	if station_module==null or frame_module==null or not game.has_method("_begin_native_station_approach"):
		check(false,"Station Main commands and bounded source frame/trial modules are installed");leave_auto_fixture("Missing station implementation");return
	var port:Dictionary=current_earth_station();check(not port.is_empty(),"The genuine Earth20km flight has actual orbital station candidates")
	if port.is_empty():leave_auto_fixture("No Earth station");return
	var before:=orbit_state();var owners:=orbit_owners()
	check(not game._begin_native_station_approach(str(port.id)),"A genuine twenty-kilometre ascent cannot masquerade as a completed many-megametre station trip")
	check(orbit_state()==before and orbit_owners()==owners and game._native_orbit_active() and not station_active(),"The real far-station command rejects atomically without moving pose, fuel, HP, gear or time")
	ordinary_unchanged("Rejected far station")
	if not labelled_near_station_fixture():leave_auto_fixture("Rejected labelled near-station setup");return
	before=orbit_state();owners=orbit_owners()
	var old_world:RefCounted=game.world;var cache_before:=var_to_bytes([old_world.snapshot(),old_world.native_evaluation_count,old_world._native_cache_tick,old_world._native_cache_day])
	var prepared:Dictionary=station_module.prepare_handoff(game.native_orbit_trial,game.ship,game.nav,game.landing_gear,game.world,str(station_fixture_port.id))
	check(prepared.get("ok",false),"A valid same-parent near-station orbital owner prepares the continuous source frame boundary")
	check(orbit_state()==before and orbit_owners()==owners and var_to_bytes([old_world.snapshot(),old_world.native_evaluation_count,old_world._native_cache_tick,old_world._native_cache_day])==cache_before,"Preparing station handoff changes neither physical owners nor the old World's source caches/spin")
	if not prepared.get("ok",false):leave_auto_fixture("Rejected station preparation");return
	var days:float=game.nav.elapsed_days;var previous_fuel:=fuel();var previous_hp:=thermal();var previous_gear:Dictionary=game.landing_gear.snapshot()
	game._toggle_pause();var paused:=orbit_state()
	check(not game._begin_native_station_approach(str(station_fixture_port.id)) and orbit_state()==paused and orbit_owners()==owners,"Paused station handoff cannot consume an interval or replace any owner")
	game._toggle_pause()
	check(game._begin_native_station_approach(str(station_fixture_port.id)) and station_active() and not game._native_orbit_active() and game._native_trial_active(),"The actual Main command enters a separate typed station phase in the same native trial")
	if not station_active():leave_auto_fixture("Rejected actual station handoff");return
	check(game.ship.position==prepared.candidate_ship.position and game.ship.velocity==prepared.candidate_ship.velocity and game.ship.attitude==prepared.candidate_ship.attitude,"Main publishes exactly the prepared station-frame pose and corrected relative velocity")
	check(game.nav.elapsed_days==days and fuel()==previous_fuel and thermal()==previous_hp and game.landing_gear.snapshot()==previous_gear,"The accepted station boundary spends no extra time, raw HP/RNG, fuel or physical gear step")
	check(game.ship.has_source_station() and game.ship.station_available and not game.ship.docked and game.world.site_id==str(station_fixture_port.id),"Actual source geometry and port availability belong to the validated chosen station without fabricated docking")
	var saved:Dictionary=copied(payload())
	check(saved.has("native_station_session") and not saved.has("native_orbit_session") and not saved.has("motion_session") and not saved.has("native_autopilot_session"),"The real whole-game payload carries exactly one station-trial owner")
	check(game._decode_primary_state(saved).is_empty() and not game._decode_native_trial_state(saved).is_empty(),"Station trials remain excluded from ordinary saves and accepted by the separate native decoder")
	var dock_before:=station_state();game._show_docking_guidance();await frame()
	check(game.menu.visible and game.menu_title.text=="ПОДХОД К ДОКУ" and station_state()==dock_before,"The real source docking window is available inside the station trial and is read-only")
	game._advance_controls(3.0);check(station_state()==dock_before,"The station modal pauses motion, source clock and door scheduling")
	game._close_menu();game._toggle_pause();var paused_station:=station_state();var station_refs:=station_owners()
	check(not game._request_dock_clearance() and station_state()==paused_station and station_owners()==station_refs,"Paused station opening requests cannot change the door, clock, raw fuel or owners")
	game._toggle_pause();var request_pose:Vector3=game.ship.position;days=game.nav.elapsed_days;previous_fuel=fuel();previous_hp=thermal()
	check(game._request_dock_clearance(),"Actual Main routes a station-trial opening request through its private command transaction")
	check(game.ship.position==request_pose and game.nav.elapsed_days==days and fuel()==previous_fuel and thermal()==previous_hp,"Opening intent does not instantly move the ship or spend flight time/HP/fuel")
	game._refresh_hud();game._update_flight_controls();await frame()
	check(game.flight_console.buttons.has("auto") and not game.flight_console.buttons.auto.disabled,"The retained lower console exposes actual station-trial Auto")
	await tap(game.flight_console.buttons.auto,981)
	check(station_active() and game.ship.autopilot and not game.ship.docked,"A routed lower-console Auto touch starts the existing physical station approach")
	check(fly_station_steps(8),"Station guidance advances eight actual private source spin/door/fuel intervals")
	if not station_active() or not game.source_contact_error.is_empty():leave_auto_fixture("Failed station intervals");return
	var door_word:int=int(game.world.station_state_by_site[game.world.site_id].door_u16)
	var cold_start:=station_facts();saved=copied(payload())
	check(door_word>0 and door_word<65535,"The cold station fixture captures an actually moving source door rather than a forced open endpoint")
	check(game._native_save_game() and game.ship.autopilot,"The actual separate SaveStore writes active source station guidance and its measured rotating history")
	check(fly_station_steps(6),"Warm source approach continues through six real intervals")
	var continued:=station_facts()
	check(game._load_native_landing_trial() and station_active() and game.ship.autopilot and station_facts()==cold_start,"Cold Main restore retains exact active approach, source door/spin history, pose, gear, HP/fuel/RNG and clock")
	check(fly_station_steps(6) and station_facts()==continued,"The next six actual cold station intervals equal warm continuation exactly")
	var refresh_before:=station_state();game._apply_system();game._sync_scene();game._refresh_hud()
	check(station_state()==refresh_before,"Normal scene and HUD refreshes do not reinitialize measured station angular history or active guidance")
	var intervals:=14;var measured_spin:=false;var clock_once:=true;var approach_progress:Array=[];var last_phase:=""
	# The fixture begins100m beyond the actual source outer waypoint. It first
	# reaches that waypoint and then flies the complete approach into the bay.
	# The finite bound prevents a hung controller without skipping either leg.
	for index in range(9000):
		if game.ship.docked or not station_active() or not game.source_contact_error.is_empty():break
		days=game.nav.elapsed_days;game._tick(0.1,Vector2.ZERO,0);intervals+=1
		clock_once=clock_once and game.nav.elapsed_days==days+0.1/86400.0
		measured_spin=measured_spin or game.ship._source_angular_velocity.length()>0.000001
		var phase_name:=str(game.ship._source_pilot_phase)
		if phase_name!=last_phase or intervals%1000==0 or game.ship.docked:
			var local:Vector3=game.ship._source_basis.transposed()*(game.ship.position-game.ship.STATION)
			var progress:={"intervals":intervals,"phase":phase_name,"local_position_m":[local.x,local.y,local.z],"speed_mps":game.ship.velocity.length(),"hull":game.ship.hull,"door_u16":int(game.world.station_state_by_site[game.world.site_id].door_u16),"clock_f64_hex":NativeSurfaceModel._native_floats([game.nav.elapsed_days],8)}
			approach_progress.append(progress);print("STATION_MAIN_PROGRESS "+JSON.stringify(progress));last_phase=phase_name
		if game.ship.hull!=100:break
	check(clock_once and measured_spin and station_active() and game.ship.docked and game.ship.hull==100 and game.source_contact_error.is_empty(),"Actual station-trial Auto flies through the original rotating aperture into a healthy accepted dock with one clock advance per interval")
	if not game.ship.docked:
		station_main_evidence.append({"case":"actual_station_approach_rejected_or_incomplete","intervals":intervals,"phase":str(game.ship._source_pilot_phase),"hull":game.ship.hull,"error":str(game.source_contact_error),"position":str(game.ship.position),"velocity":str(game.ship.velocity),"physical_docking_ready":game.ship.can_dock()})
		leave_auto_fixture("Station approach did not dock");return
	check(game.ship.position==game.ship.STATION and game.ship.velocity==Vector3.ZERO,"The actual existing source capture, rather than the frame boundary, establishes the parked dock pose")
	check(game._native_save_game(),"The accepted source dock is saved in the separate native slot")
	var docked_facts:=station_facts();check(game._load_native_landing_trial() and station_active() and game.ship.docked and station_facts()==docked_facts,"The actual docked station state cold-restores without losing its source geometry, rates or trial ownership")
	var docked_before:=station_state();station_refs=station_owners()
	check(not game._begin_native_station_reverse() and station_state()==docked_before and station_owners()==station_refs,"A docked ship must physically depart before it can leave the station coordinate context")
	game._show_services(false);await frame()
	check(game.menu.visible and game.hyperdrive_services_view!=null,"A legitimately docked station trial exposes the real source services UI")
	var button:Button=game.hyperdrive_services_view.buttons.get("refuel:hydrogen",null)
	check(button!=null and not button.disabled,"The captured station quotes an available real hydrogen purchase")
	var before_hydrogen:int=int(game.nav.snapshot().source_hyperdrive.hydrogen);var credits:int=game.ship.credits;var save_sequence:int=game.native_saves.sequence
	if button!=null and not button.disabled:
		var scroll:ScrollContainer=game.menu_rows.get_parent();scroll.ensure_control_visible(button);await frame();await tap(button,982)
	check(int(game.nav.snapshot().source_hyperdrive.hydrogen)==before_hydrogen+1 and game.ship.credits<credits,"A real routed service purchase adds one tonne of hydrogen and charges station credits")
	check(station_active() and game.ship.docked and game.native_saves.sequence>save_sequence,"Accepted station service persists to the native slot while ordinary saving is disabled")
	button=game.hyperdrive_services_view.buttons.get("remove_fuel_equipment:atmospheric_shielding",null)
	check(button!=null and not button.disabled,"The actual equipment view permits removing the previously purchased shield at a legitimate orbital dock")
	credits=game.ship.credits
	if button!=null and not button.disabled:
		var scroll:ScrollContainer=game.menu_rows.get_parent();scroll.ensure_control_visible(button);await frame();await tap(button,983)
	check(not bool(fuel().atmospheric_shielding_installed) and game.ship.credits>credits,"Actual source equipment removal changes the real shielding flag and pays the quoted refund")
	button=game.hyperdrive_services_view.buttons.get("install_fuel_equipment:atmospheric_shielding",null)
	check(button!=null and not button.disabled,"The station quotes reinstalling actual atmospheric protection")
	credits=game.ship.credits
	if button!=null and not button.disabled:
		var scroll:ScrollContainer=game.menu_rows.get_parent();scroll.ensure_control_visible(button);await frame();await tap(button,984)
	check(bool(fuel().atmospheric_shielding_installed) and game.ship.credits==credits-100,"The real routed reinstall action charges100credits and restores source equipment without modifying hull or time")
	var serviced:=station_facts();check(game._native_save_game() and game._load_native_landing_trial() and station_facts()==serviced,"Cold station saving preserves legitimately changed equipment, cargo, credits and the source fuel owner")
	game._close_menu();var departure_pose:Vector3=game.ship.position;days=game.nav.elapsed_days;previous_fuel=fuel();previous_hp=thermal()
	game._dock_action()
	check(game.ship.position==departure_pose and game.nav.elapsed_days==days and fuel()==previous_fuel and thermal()==previous_hp,"The actual source launch request does not relocate outside the hangar or consume a second interval")
	for index in range(400):
		game._tick(0.1,Vector2.ZERO,0)
		if not game.source_contact_error.is_empty() or game.ship.hull!=100:break
	var source_axis:Vector3=game.world.source_station_basis(game.nav.elapsed_days).transposed()*(game.ship.position-game.ship.STATION)
	check(station_active() and not game.ship.docked and game.ship.hull==100 and source_axis.z>250 and game.source_contact_error.is_empty(),"Real post-service source departure flies safely out of the rotating station")
	var station_world_before:RefCounted=game.world;var station_position:PackedFloat64Array=station_session()._position_f64.duplicate();var station_velocity:Vector3=game.ship.velocity
	var reverse:Dictionary=station_session().prepare_reverse(game.ship,game.nav,game.landing_gear,game.world)
	check(reverse.get("ok",false),"The actual departed station state prepares a same-time reverse frame boundary")
	if not reverse.get("ok",false):leave_auto_fixture("Station reverse preparation rejected");return
	var expected:Dictionary=frame_module.map_between(station_world_before,reverse.candidate_world,station_position,station_velocity,game.nav.elapsed_days)
	var expected_position:PackedFloat64Array=expected.position_f64;var expected_velocity:PackedFloat64Array=expected.velocity_f64
	days=game.nav.elapsed_days;previous_fuel=fuel();previous_hp=thermal();previous_gear=game.landing_gear.snapshot()
	check(game._begin_native_station_reverse() and game._native_orbit_active() and not station_active() and game._native_trial_active(),"Actual Main reverses to the original body-frame orbital trial after a legitimate departure")
	check(game.ship.position==Vector3(expected_position[0],expected_position[1],expected_position[2]) and game.ship.velocity==Vector3(expected_velocity[0],expected_velocity[1],expected_velocity[2]),"Reverse handoff publishes the same current source-origin translation and physical velocity correction")
	check(game.nav.elapsed_days==days and fuel()==previous_fuel and thermal()==previous_hp and game.landing_gear.snapshot()==previous_gear,"The reverse frame boundary spends no additional HP/RNG, fuel, gear or clock interval")
	check(game.world.site_id.is_empty() and not game.ship.station_available and not game.ship.has_source_station() and not payload().is_empty() and not game._decode_state(copied(payload())).is_empty(),"The original body-frame owner resumes with no stale station context and remains strictly cold-loadable")
	ordinary_unchanged("Connected station dock/services/departure/reverse")
	station_main_evidence.append({"case":"actual_Main_connected_near_station_cycle","site_id":str(station_fixture_port.id),"original_parent":str(station_fixture_port.parent),"near_station_placement_is_explicit_fixture":true,"planet_to_station_journey_flown":false,"source_approach_intervals":intervals,"seconds_per_interval":0.1,"approach_progress":approach_progress,"mid_door_word_u16":door_word,"cold_compared_intervals":6,"original_station_spin_observed":measured_spin,"real_hydrogen_purchase":true,"real_equipment_remove_reinstall":true,"departure_axis_m":source_axis.z,"reverse_zero_time":true,"healthy_hull":game.ship.hull})
	leave_auto_fixture("Connected station native cycle")
	check(not station_active(),"Returning to ordinary progress clears station-trial ownership")

func station_save_rejections_and_failed_interval()->void:
	if not await return_space_fixture():return
	if not labelled_near_station_fixture(false):leave_auto_fixture("Rejected station rejection fixture");return
	check(game._begin_native_station_approach(str(station_fixture_port.id)) and station_active(),"The station rejection case uses a second valid typed same-parent handoff")
	if not station_active():leave_auto_fixture("Rejected station rejection handoff");return
	var valid:Dictionary=copied(payload());var before:=station_state();var owners:=station_owners()
	for invalid:Variant in [null,[],{},"invalid"]:
		var bad:=valid.duplicate(true);bad.native_station_session=invalid
		check(game._decode_state(bad).is_empty(),"Present malformed station ownership cannot silently decode as an ordinary or legacy flight")
	var mixed:=valid.duplicate(true);mixed.native_orbit_session=native_return_space_template.native_orbit_session.duplicate(true)
	check(game._decode_state(mixed).is_empty(),"A station save cannot contain a simultaneous separately valid body-orbit owner")
	mixed=valid.duplicate(true);mixed.motion_session={"version":1,"profile":game.source_motion.CONTRACT,"enabled":false,"state":{}}
	check(game._decode_state(mixed).is_empty(),"The native station owner cannot also accept an ordinary motion session")
	check(game._decode_native_trial_state(copied(ordinary_store.last_payload)).is_empty() and game._decode_primary_state(valid).is_empty(),"Station and ordinary SaveStores enforce their actual typed mode boundary")
	check(station_state()==before and station_owners()==owners,"All rejected station cold candidates leave the live game exactly unchanged")
	check(fly_station_steps(1),"A valid station interval advances the stale-snapshot control")
	var later:Dictionary=copied(payload());later.native_station_session=valid.native_station_session.duplicate(true)
	check(game._decode_state(later).is_empty(),"An older station snapshot cannot attach to a later physical pose, clock or source spin")
	# Explicit invalid external pose, not a physical trajectory or accepted save.
	game.ship.position.x+=1024.0;before=station_state();owners=station_owners();var sequence:int=game.native_saves.sequence
	game._tick(0.1,Vector2.ZERO,0)
	check(not game.source_contact_error.is_empty() and station_state()==before and station_owners()==owners,"An invalid bound station interval rejects without partly advancing physical owners, raw source state or time")
	check(not game._native_save_game() and game.native_saves.sequence==sequence,"A stale station pose cannot replace a valid native save")
	ordinary_unchanged("Station invalid save and interval")
	station_main_evidence.append({"case":"actual_station_typed_restore_and_stale_interval_guards","malformed_present_extensions_rejected":true,"mixed_owners_rejected":true,"stale_physical_pose_is_explicit_invalid_fixture":true,"all_ordinary_progress_unchanged":true})
	leave_auto_fixture("Rejected station candidates")

func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires private capture mode");quit(1);return
	root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main failed to load");game.free();quit(1);return
	game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	check(game.automated and not game.saving_enabled,"Actual station Main tests use isolated capture mode without player saves")
	await actual_station_handoff_dock_service_reverse();await station_save_rejections_and_failed_interval()
	var sources:Dictionary={}
	for path:String in ["scripts/main.gd","scripts/native_station_trial.gd","scripts/native_station_frame.gd","scripts/native_orbit_trial.gd","scripts/native_surface_model.gd","scripts/planetary_system.gd","scripts/source_station_session.gd","scripts/source_station_geometry.gd","scripts/rotating_dock_dynamics.gd","scripts/flight_model.gd","scripts/navigation.gd","scripts/hyperdrive_services_view.gd","tests/test_native_station_main.gd","tests/test_native_return_main.gd","tests/test_native_orbit_main.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STATION_MAIN_REPORT.get_base_dir()));var file:=FileAccess.open(STATION_MAIN_REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":station_main_evidence,"sources":sources,"scope":"Actual Main native station phase: genuine source autoland/20km outbound and honest far-station rejection; explicitly labelled near-station placement retains that real lineage, then continuous boundary, source rotating autopilot/door/CCD, cold active and parked continuation, routed paid source services, physical departure, inverse body-frame return, malformed/mixed/stale rejection and exact six-owner ordinary-flight restoration. The many-megametre transit is not flown; no full F570/F606/F597, new original oracle, physical Android or FPS claim."},"\t"));file.close()
	game.queue_free();await frame();print("Native station Main: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
