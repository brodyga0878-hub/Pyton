extends "res://tests/test_source_thermal_main.gd"
# Actual Main commands, source terrain and whole-game decoder. Placements and
# old-save shapes below are labelled fixtures, never claims of manual flight.
const GEAR_REPORT:="res://validation/contact-2026-11-08/gear-main-regression.json"
var gear_evidence:Array=[]

func gear()->Dictionary:return game._gear_state().duplicate(true)
func saved_gear()->Dictionary:return payload().get("gear_session",{}).duplicate(true)
func command_gear(down:bool)->void:
	game._request_landing_gear(down)
	check(gear().requested_down==down,"Actual Main selects the requested gear direction without instantly moving the mechanism")
func complete_gear(down:bool)->void:
	command_gear(down)
	check(game._step_landing_gear(3.0),"Actual Main advances the gear scheduler for an explicit three-second fixture")
	check(int(gear().position_u16)==(65535 if down else 0),"Actual source mechanism reaches its requested physical endpoint")

func stage_gear_surface(height:=2.0)->bool:
	fresh();game.settings.orbital_gravity=false;stage_natural("earth",5000,0)
	await game._enter_surface()
	check(game.surface.active and game.surface.source_surface(),"Actual Main enters the original source Earth terrain for gear contact")
	if not game.surface.active:return false
	game.surface.landed=false;game.surface.landing=false;game.surface.taking_off=false;game.surface.cancel_vertical()
	game.ship.position=Vector3(0,game.surface.height_at(0,0)+game.surface.clearance(game.ship)+height,0)
	game.ship.velocity=Vector3.ZERO;game.ship.attitude=Quaternion.IDENTITY;game.ship.assisted=false;game.ship.target_speed=0
	game._apply_system();game._refresh_hud();game._update_flight_controls()
	return true

func old_save_default_and_atomic()->void:
	var landed_good:Dictionary={}
	fresh();check(gear().get("available",true),"Full source layout enables managed landing gear")
	var airborne:Dictionary=copied(payload());airborne.erase("gear_session")
	check(load_fixture(airborne,"Prior airborne save without managed gear"),"Actual Main upgrades a missing old gear extension")
	check(int(gear().position_u16)==0 and not gear().requested_down,"Old airborne state explicitly initializes retracted gear")
	fresh();check(dock_fixture(),"Old docked default fixture occupies a real source station bay")
	var docked:Dictionary=copied(payload());docked.erase("gear_session")
	check(load_fixture(docked,"Prior docked save without managed gear"),"Actual Main upgrades an old docked gear state")
	check(int(gear().position_u16)==65535 and gear().requested_down,"Old docked state initializes fully deployed gear")
	var docked_gear:=saved_gear();game._toggle_landing_gear()
	check(saved_gear()==docked_gear and not gear().can_toggle,"Original parked player phase blocks gear toggling in an actual orbital dock")
	await launch();game._toggle_landing_gear()
	check(not gear().requested_down,"Leaving the actual dock makes manual gear retraction available again")
	if await stage_gear_surface(1.0):
		complete_gear(true);game.ship.position.y=game.surface.height_at(0,0)+game.surface.clearance(game.ship)-0.001
		check(game.surface.touch_down(game.ship) and game._apply_pending_source_contact() and game.surface.landed,"Actual source floor accepts and commits the fully deployed native contact fixture")
		var landed:Dictionary=copied(payload());landed.erase("gear_session")
		check(load_fixture(landed,"Prior landed source save without managed gear"),"Actual Main upgrades an old landed gear state")
		check(int(gear().position_u16)==65535 and gear().requested_down and game.surface.landed,"Old landed source save remains parked with fully deployed gear")
		landed_good=copied(payload())
	fresh();var good:Dictionary=copied(payload());var before:=state();var objects:=identities();var gear_object:RefCounted=game.landing_gear
	var variants:Array=[];var bad:Dictionary=good.duplicate(true);bad.gear_session={};variants.append(bad)
	bad=good.duplicate(true);bad.gear_session["unknown_field"]=1;variants.append(bad)
	bad=good.duplicate(true);bad.gear_session=null;variants.append(bad)
	bad=good.duplicate(true);bad.gear_session=[];variants.append(bad)
	if not landed_good.is_empty():
		bad=landed_good.duplicate(true);bad.gear_session.control_flags_u8=int(bad.gear_session.control_flags_u8)|2;variants.append(bad)
		bad=landed_good.duplicate(true);bad.gear_session.position_u16=65534;variants.append(bad)
	for index in range(variants.size()):
		check(game._decode_state(variants[index]).is_empty(),"Present malformed gear extension is rejected rather than treated as an old missing save "+str(index))
		check(state()==before and identities()==objects and game.landing_gear==gear_object,"Rejected gear restore preserves every live model and gear identity "+str(index))
	gear_evidence.append({"case":"old_missing_extension_and_present_malformed","airborne_default_u16":0,"landed_or_docked_default_u16":65535,"malformed_variants":variants.size()})

func partial_cold_continuation()->void:
	fresh();command_gear(true);game._step_landing_gear(0.0073)
	for index in range(17):game._step_landing_gear(1.0/120.0)
	check(int(gear().position_u16)>0 and int(gear().position_u16)<65535,"Production gear scheduler creates a genuinely partial physical state")
	var save:Dictionary=copied(payload());var partial:=gear();var raw:=saved_gear()
	for index in range(43):game._step_landing_gear(1.0/120.0)
	var expected:=saved_gear();var expected_state:=gear()
	check(load_fixture(save,"Partial physical gear and fractional host-clock continuation"),"Actual decoder accepts a partially extended mechanism")
	check(gear()==partial and saved_gear()==raw,"Cold restore retains exact physical position and both host fractions")
	for index in range(43):game._step_landing_gear(1.0/120.0)
	check(saved_gear()==expected and gear()==expected_state,"Cold continuation applies the remaining source updates exactly once")
	gear_evidence.append({"case":"partial_cold_continuation","partial":partial,"continued":expected_state,"partial_save":raw})

func pointer_pause_and_background()->void:
	fresh();game._refresh_hud();game._update_flight_controls();await frame()
	check(game.flight_console.buttons.has("gear"),"Actual retained classic console contains the managed-gear touch command")
	if not game.flight_console.buttons.has("gear"):return
	var button:Button=game.flight_console.buttons.gear
	var up:=gear();await tap(button,231)
	check(gear().requested_down and int(gear().position_u16)==int(up.position_u16),"Actual console tap requests extension without a display-frame animation shortcut")
	game._step_landing_gear(0.125);game._refresh_hud();var before:=state()
	game._toggle_pause();game._advance_controls(5);game._tick(5,Vector2.ONE,1,1)
	check(state()==before and game.flight_console.buttons.gear.disabled,"Pause freezes the actual gear mechanism and disables physical gear input")
	game._toggle_landing_gear();check(state()==before,"Direct gear command cannot bypass the actual pause guard")
	game._toggle_pause();game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);game._advance_controls(5)
	check(state()==before,"Background time does not create catch-up debt in the gear scheduler")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);game._refresh_hud();game._update_flight_controls();await frame()
	button=game.flight_console.buttons.gear
	var event:=InputEventScreenTouch.new();event.index=232;event.position=button.get_global_rect().get_center();event.pressed=true
	root.push_input(event,true);await frame();check(button.pointer_id==232,"Gear button owns its real independent phone pointer")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);event.pressed=false;root.push_input(event,true);await frame()
	check(state()==before and button.pointer_id==-1,"A held gear pointer released after focus loss cannot send a stale toggle")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);game._refresh_hud();game._update_flight_controls();await frame()
	await tap(button,233);check(not gear().requested_down,"A fresh post-resume pointer can request retraction")
	gear_evidence.append({"case":"actual_classic_console_pointer_pause_focus","stale_pointer_replayed":false})

func raw_thermal_bit_and_visual()->void:
	fresh();check(gear().f1014_raw_gear_flag and not gear().requested_down,"Retracted gear exposes the original set E9 bit to F1014")
	command_gear(true)
	check(not gear().f1014_raw_gear_flag and int(gear().position_u16)==0,"F1014 follows the requested raw bit even before physical extension begins")
	game._step_landing_gear(1.0);game._process(0);var middle:=gear()
	check(int(middle.position_u16)>0 and int(middle.position_u16)<65535,"Thermal/visual fixture has a real partial source word")
	check(is_equal_approx(game.player._gear_amount,float(middle.extension_fraction)) and game.player._source_gear_driven,"Actual external ship struts follow the exact source fraction")
	var fraction:float=game.player._gear_amount;game.player._process(10)
	check(game.player._gear_amount==fraction,"Drawing a source-controlled ship cannot advance its gear while simulation is frozen")
	game._step_landing_gear(2.0);check(int(gear().position_u16)==65535 and not gear().f1014_raw_gear_flag,"Fully deployed gear keeps the clear original E9 request bit")
	command_gear(false)
	check(gear().f1014_raw_gear_flag and int(gear().position_u16)==65535,"Retraction request reaches F1014 before the physical word has moved")
	gear_evidence.append({"case":"thermal_raw_bit_not_deployed_flag","partial":middle,"visual_fraction":fraction})

func actual_thermal_request_bit()->void:
	var outcomes:Array=[]
	for request_down:bool in [false,true]:
		fresh();game.settings.orbital_gravity=false;var placed:=stage_natural("earth",5000,900)
		command_gear(request_down)
		check(int(gear().position_u16)==0,"Thermal raw-bit boundary retains identical fully retracted physical geometry")
		var speed:int=placed.contact.speed_s32;var expected_heat:int=speed>>(4 if request_down else 5)
		game._step_source_fuel(1.0/60.0,[0,0,0])
		check(int(fuel().heat_s32)==expected_heat,"Actual Main passes the original requested E9 bit into the first F1014 heat invocation")
		outcomes.append({"requested_down":request_down,"physical_position_u16":gear().position_u16,"raw_gear_flag":gear().f1014_raw_gear_flag,"source_speed_s32":speed,"expected_heat_s32":expected_heat,"actual_heat_s32":fuel().heat_s32})
	check(int(outcomes[1].actual_heat_s32)>int(outcomes[0].actual_heat_s32),"Actual Main thermal behavior follows the raw request bit rather than physical gear deployment")
	gear_evidence.append({"case":"actual_Main_F1014_requested_raw_bit","actual_source_Earth_contact":true,"outcomes":outcomes})

func ground_hold_lift_and_autoland()->void:
	if not await stage_gear_surface(-0.01):return
	complete_gear(false);game.ship.velocity=Vector3(0,-0.5,0)
	game._tick(1.0/60.0,Vector2.ZERO,0)
	check(not game.surface.landed and absf(game.surface.altitude(game.ship))<=game.surface.CONTACT_QUANTIZATION_METRES and game.ship.hull==75,"Gear-up contact now consumes the original100raw damage and rebound rather than the previous artificial clearance hold")
	var hull:float=game.ship.hull
	check(not game.surface.touch_down(game.ship),"Manual soft-landing shortcut rejects retracted gear")
	var hold_height:float=game.surface.altitude(game.ship)
	for index in range(12):game._tick(1.0/60.0,Vector2.ZERO,0,1)
	check(not game.surface.landed and game.surface.altitude(game.ship)>hold_height and game.ship.velocity.y>0 and game.ship.hull==hull,"Actual phone lift escapes the damaging source rebound without a parked-state lockout or repeated loss")
	game.ship.position=Vector3(0,game.surface.height_at(0,0)+game.surface.clearance(game.ship)+0.5,0)
	game.ship.velocity=Vector3.ZERO;game.ship.target_speed=0;game.surface.landed=false;game.surface.landing=false
	game._toggle_auto();check(game.surface.landing,"Actual classic automatic command starts a gear-managed surface landing")
	for index in range(15):game._tick(1.0/60.0,Vector2.ZERO,0)
	check(gear().requested_down and int(gear().position_u16)<65535 and not game.surface.landed,"Automatic descent requests extension and waits for the physical endpoint")
	var waiting_position:int=gear().position_u16;game._dock_action()
	check(game.surface.landing and gear().requested_down and int(gear().position_u16)==waiting_position,"Repeated actual landing command keeps the pending gear-wait approach instead of cancelling it")
	for index in range(240):
		game._tick(1.0/60.0,Vector2.ZERO,0)
		if game.surface.landed:break
	check(game.surface.landed and int(gear().position_u16)==65535 and game.ship.hull==hull,"Actual Main completes the soft landing only after complete extension")
	game._refresh_hud();game._update_flight_controls();var parked:=gear();game._toggle_landing_gear()
	check(gear()==parked,"Original landed-phase gate blocks manual retraction on a healthy parked ship")
	check(game._takeoff_action(),"Actual takeoff command remains available after the gear-managed landing")
	for index in range(12):game._tick(1.0/60.0,Vector2.ZERO,0,1)
	check(not game.surface.landed and game.ship.velocity.y>0 and game.ship.hull==hull,"Recovered landing still leaves the actual source floor through the phone lift path")
	gear_evidence.append({"case":"actual_source_floor_gear_native_rebound_and_recovery","initial_native_agl_m":hold_height,"final_agl_m":game.surface.altitude(game.ship),"hull_percent":game.ship.hull,"response_policy":"dos-firstenc-f575-postclassification-player-contact-v1","geometry_provider_is_phone_adapter":true,"full_original_F575_collision_claim":false})

func retract_request_before_first_frame()->void:
	if not await stage_gear_surface(0.0):return
	complete_gear(true);command_gear(false)
	check(int(gear().position_u16)==65535 and not gear().requested_down,"Immediate retraction fixture retains the deployed physical endpoint until its first source update")
	check(not game.surface.touch_down(game.ship) and not game.surface.landed,"Additional phone landing-readiness guard blocks a new soft landing once retraction has been requested")
	command_gear(true)
	check(game.surface.touch_down(game.ship) and game._apply_pending_source_contact() and game.surface.landed,"Restoring the deployment request permits and commits contact at the still-complete physical endpoint")
	gear_evidence.append({"case":"request_guard_before_first_source_frame","physical_word_u16":65535,"policy":"phone landing requires full physical extension plus deployment request; additional host policy, not the whole original F575 response"})

func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires private capture mode");quit(1);return
	root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main script failed to load");game.free();quit(1);return
	game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	check(game.automated and not game.saving_enabled,"Gear regression never reads or writes ordinary player progress")
	await old_save_default_and_atomic();partial_cold_continuation();await pointer_pause_and_background();raw_thermal_bit_and_visual();actual_thermal_request_bit();await retract_request_before_first_frame();await ground_hold_lift_and_autoland()
	var sources:Dictionary={}
	for path:String in ["scripts/main.gd","scripts/surface_model.gd","scripts/flight_console.gd","scripts/ship_visual.gd","scripts/source_landing_gear.gd","scripts/source_landing_gear_session.gd","scripts/source_surface_contact.gd","scripts/source_surface_contact_bridge.gd","tests/test_source_gear_main.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GEAR_REPORT.get_base_dir()))
	var file:=FileAccess.open(GEAR_REPORT,FileAccess.WRITE);file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"evidence":gear_evidence,"sources":sources,"scope":"Retained managed-gear regression on current0.19 Main: classic-console touch/pause/focus, original bounded F575 rebound and existing F953 HP, automatic recovery, source-fraction visuals and old/partial/invalid saves. Original0.18 evidence is unchanged; current reports write only under contact. Explicit observer placement; no manual landing, physical Android, complete original collision classifier or performance benchmark claim."},"\t"));file.close()
	game.queue_free();await frame();print("Source gear Main: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
