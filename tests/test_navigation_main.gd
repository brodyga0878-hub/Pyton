extends SceneTree
# Player-facing integration: actual Main, touch controls, isolated maps and
# strict raw continuation. No disk saves or simulated Android/device claims.
const World=preload("res://scripts/planetary_system.gd")
const Settings=preload("res://scripts/device_settings.gd")
class MemorySettings extends Settings:
	func load_file()->bool:quality=0;return false
var game:Node3D
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func copied(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func snapshot()->String:return JSON.stringify(game._payload())
func reset_full()->void:
	game._close_menu();game.settings_panel.hide();game.active=true;game.busy=false
	game._new_models(World.FULL_LAYOUT);game._apply_system();game._refresh_hud();game._update_flight_controls()
func touch(point:Vector2,pointer:int,pressed:bool)->void:
	var event:=InputEventScreenTouch.new();event.index=pointer;event.position=point;event.pressed=pressed
	Input.parse_input_event(event);await process_frame
func tap(button:Button,pointer:=71)->void:
	await touch(button.get_global_rect().get_center(),pointer,true)
	await touch(button.get_global_rect().get_center(),pointer,false)
func settle_map(view:Control)->void:
	var frames:=0
	while view.loading() and frames<10000:await process_frame;frames+=1
	check(not view.loading(),"Galaxy worker completes within the bounded test window")
	await process_frame
func reject(payload:Dictionary,label:String)->void:
	var before:=snapshot();var identities:Array=[game.ship,game.world,game.nav,game.surface,game.source_motion]
	check(game._decode_state(payload).is_empty(),"Decoder rejects "+label)
	check(snapshot()==before and identities==[game.ship,game.world,game.nav,game.surface,game.source_motion],"Rejected "+label+" preserves the entire live session")

func maps()->void:
	reset_full();var before:=snapshot();var elapsed:float=game.nav.elapsed_days
	await tap(game.flight_console.buttons.routes)
	var view:Control=game.active_map
	check(view!=null and game.active_map_kind=="galaxy" and game._blocked(),"Actual console opens the graphical native galaxy as a modal screen")
	if view==null:return
	await settle_map(view)
	game._advance_controls(1.0);game._process(0.02)
	check(game.nav.elapsed_days==elapsed and snapshot()==before,"Open galaxy freezes actual ship, source clock and gameplay publication")
	check(view.select_system(111449880),"Actual map selects original Alpha Centauri")
	check(game.nav.selected_id==111449880 and game.nav.remaining==0,"Star selection changes destination without starting a jump")
	check(not view.buttons.jump.disabled,"Reachable selected star enables explicit jump confirmation")
	await tap(view.buttons.jump,72)
	check(game.active_map==null and game.nav.pending_id==111449880 and game.nav.remaining>0,"Real map jump touch closes the map and starts the actual charge")
	var decoded:Dictionary=game._decode_state(copied(game._payload()))
	check(not decoded.is_empty() and decoded.source_motion_enabled,"Pending jump preserves the opt-in source-motion session")
	var charge_start:float=game.nav.elapsed_days
	game._tick(0.1,Vector2.ZERO,0)
	check(absf((game.nav.elapsed_days-charge_start)*86400-0.1)<0.00001,"New source session advances celestial time during jump charge")
	for step in range(31):game._tick(0.1,Vector2.ZERO,0)
	check(game.nav.current_id==111449880 and game.world.system_id==111449880,"Confirmed graphical route constructs the real destination world")
	check(not game._decode_state(copied(game._payload())).is_empty(),"Arrival after source charge remains strictly restorable")
	reset_full();elapsed=game.nav.elapsed_days
	await tap(game.flight_console.buttons.system,73)
	var system_view:Control=game.active_map
	check(system_view!=null and game.active_map_kind=="system","Actual console opens the full hierarchical system map")
	if system_view==null:return
	var world_before:=var_to_bytes(game.world.snapshot());var point:Array=system_view.model.position_au("moon")
	check(system_view.set_preview_offset(12.5),"System forecast accepts a separate preview date")
	check(system_view.model.position_au("moon")!=point,"Forecast actually moves the source Moon rather than a decorative icon")
	game._advance_controls(2);game._process(0.02)
	check(game.nav.elapsed_days==elapsed and var_to_bytes(game.world.snapshot())==world_before,"Forecast and modal render leave every live source world field unchanged")
	system_view._select("moon")
	check(game.world.selected_id=="moon" and game.world.focus_id=="earth" and game.world.transfer_remaining==0,"Selecting a body sets the target without teleporting the ship")
	await tap(system_view.buttons.travel,74)
	check(game.active_map==null and game.world.pending_id=="moon" and game.world.transfer_remaining>0,"Explicit system-map travel uses the existing declared transfer adapter")
	var transfer_start:float=game.nav.elapsed_days
	game._tick(0.1,Vector2.ZERO,0)
	check(absf((game.nav.elapsed_days-transfer_start)*86400-0.1)<0.00001,"New source session advances celestial time during transfer charge")
	reset_full();game._show_system();system_view=game.active_map
	var orbital:Dictionary={}
	for item:Dictionary in game.world.settlements:
		if int(item.type_code) in [32,33,34]:orbital=item;break
	check(not orbital.is_empty(),"Sol exposes a real orbital port for moving-target integration")
	if not orbital.is_empty():
		system_view._select(str(orbital.id))
		check(game.target_site_id==str(orbital.id),"Map port selection retains the actual port identifier")
		var expected:Vector3=game.world.site_local_meters(str(orbital.id),game.nav.elapsed_days)
		check(game._navigation_target().position==expected,"Flight target points at the selected moving port")
		decoded=game._decode_state(copied(game._payload()))
		check(not decoded.is_empty() and decoded.target_site_id==str(orbital.id),"Port selection survives strict isolated save decoding")
		var bad:Dictionary=copied(game._payload());bad.target_session.system_id=1;reject(bad,"target belonging to another system")
		system_view._select("moon")
		check(game.target_site_id.is_empty(),"Selecting a body clears the previous port target")
	game._close_map(false);await process_frame

func source_continuation()->void:
	reset_full();game.ship.velocity=Vector3(0.00123,-0.00234,0.00345);game.ship.assisted=false
	game._tick(0.0073,Vector2.ZERO,0)
	check(game.source_motion_enabled and game.source_motion.is_active() and game.last_motion_result.get("handled",false),"Actual Main advances eligible Cobra translation through original integer/fractional motion")
	var saved:Dictionary=copied(game._payload());var state:Dictionary=game.source_motion.snapshot()
	check(not saved.motion_session.state.is_empty(),"Actual payload retains raw body bytes and fractional source ticks")
	var decoded:Dictionary=game._decode_state(saved)
	check(not decoded.is_empty() and decoded.source_motion.snapshot()==state,"JSON Main restore retains every raw and IEEE64 fractional word exactly")
	if decoded.is_empty():return
	game._tick(0.0091,Vector2(0.2,-0.1),0.07)
	var expected_position:Vector3=game.ship.position;var expected_velocity:Vector3=game.ship.velocity;var expected:Dictionary=game.source_motion.snapshot()
	game._commit_state(decoded);game._apply_system();game._tick(0.0091,Vector2(0.2,-0.1),0.07)
	check(game.ship.position==expected_position and game.ship.velocity==expected_velocity and game.source_motion.snapshot()==expected,"Actual Main resumes the identical next raw flight step after save/reload")
	var bad:Dictionary=copied(game._payload());bad.motion_session.version=true;reject(bad,"boolean motion version")
	bad=copied(game._payload());bad.motion_session.state.parent_id="mars";reject(bad,"raw body bound to a different parent")
	bad=copied(game._payload());bad.motion_session.state.ticks_fraction_f64_hex="000000000000f03f";reject(bad,"out-of-range raw fractional tick")
	var legacy:Dictionary=copied(game._payload());legacy.erase("motion_session")
	decoded=game._decode_state(legacy)
	check(not decoded.is_empty() and not decoded.source_motion_enabled,"Published save without opt-in retains its original SI flight behavior")
	game._commit_state(decoded);game._apply_system();game._start_jump(111449880)
	var legacy_days:float=game.nav.elapsed_days;game._tick(0.1,Vector2.ZERO,0)
	check(game.nav.elapsed_days==legacy_days,"Legacy save retains its published jump charge timing")
	reset_full();game._tick(0.0073,Vector2.ZERO,0)
	game.ship.position+=Vector3(10,0,0)
	check(game._payload().motion_session.state.is_empty() and not game.source_motion.is_active(),"External collision/position change cannot serialize stale raw coordinates")
	game._tick(0.0073,Vector2.ZERO,0);var original_bridge:RefCounted=game.source_motion;state=original_bridge.snapshot()
	game.instruments.paused=true;game._begin_graphics_demo()
	check(not game.instruments.paused and not game.source_motion_enabled,"Optional graphics preview starts its own independent flight")
	game._end_graphics_demo()
	check(game.instruments.paused and game.source_motion==original_bridge and game.source_motion.snapshot()==state,"Returning from preview preserves paused flight and every source fractional word")

func touch_roll_and_time()->void:
	reset_full();await process_frame
	var roll:Control=game.holds[3];var stick:Control=game.stick
	var roll_point:=roll.get_global_rect().position+Vector2(roll.size.x*0.25,roll.size.y*0.5)
	await touch(roll_point,81,true);await touch(stick.get_global_rect().get_center(),82,true)
	check(roll.pointer_id==81 and stick.pointer_id==82 and absf(game.roll_right_strength-0.25)<0.02,"Actual independent phone fingers hold fine roll and steering together")
	var attitude:Quaternion=game.ship.attitude;game._advance_controls(0.05)
	check(game.ship.attitude!=attitude and game.ship.hull==100,"Fine phone roll genuinely rotates the live ship without a camera-only trick")
	await tap(game.flight_console.buttons.pause,83)
	check(game.instruments.paused and roll.pointer_id==-1 and stick.pointer_id==-1 and game.roll_right_strength==0,"Third-finger pause clears roll and stick ownership")
	await tap(game.flight_console.buttons.pause,84)
	await touch(roll_point,81,false);await touch(stick.get_global_rect().get_center(),82,false)
	game._refresh_hud()
	check(game.time_controls.buttons[1000].disabled and game.time_controls.buttons[10000].disabled,"Unimplemented original high acceleration buttons are visibly disabled")
	check(int(game.flight_time.safety_limit(game._time_context()).rate)==100,"Natural arrival has enough measured clearance for bounded ×100")
	await tap(game.time_controls.buttons[100],85)
	check(game.flight_time.requested_rate==100,"Actual phone time button requests supported ×100")
	var days:float=game.nav.elapsed_days
	for frame in range(60):game._advance_controls(1.0/60.0)
	check(absf((game.nav.elapsed_days-days)*86400-100)<0.001,"One second of actual scheduled frames advances exactly100 celestial seconds")
	await touch(roll_point,86,true);days=game.nav.elapsed_days;game._advance_controls(1.0/60.0)
	check(game.flight_time.requested_rate==1 and (game.nav.elapsed_days-days)*86400<0.02,"Fresh manual roll immediately returns to ×1 without accelerated input debt")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(roll.pointer_id==-1 and game.roll_right_strength==0 and game.flight_time.requested_rate==1,"Backgrounding releases fine roll and resets acceleration")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);await touch(roll_point,86,false)
	game._request_time_rate(100);game._show_routes();var view:Control=game.active_map
	check(game.flight_time.requested_rate==1 and not roll.input_allowed,"Opening a map clears acceleration and disables held flight controls")
	await settle_map(view);game._close_map(false)
	game.ship.hull=0;days=game.nav.elapsed_days;game._advance_controls(0.1)
	check(game.nav.elapsed_days==days,"Destroyed ship cannot advance unexecuted simulation time")

func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires safe capture mode");quit(1);return
	root.size=Vector2i(1440,720)
	game=load("res://scenes/main.tscn").instantiate();game.settings=MemorySettings.new();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);await process_frame
	check(game.automated and not game.saving_enabled,"Integration leaves actual user progress untouched")
	await maps();source_continuation();await touch_roll_and_time()
	game.queue_free();await process_frame
	print("NAVIGATION MAIN TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
