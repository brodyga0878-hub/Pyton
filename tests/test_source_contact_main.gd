extends "res://tests/test_source_gear_main.gd"
# Actual Main/Surface/provider orchestration. Source terminal arithmetic has an
# independent native oracle; positions and old-save HP anchors here are fixtures.
const ContactFrame=preload("res://scripts/source_surface_contact_bridge.gd")
const CityContacts=preload("res://scripts/source_city_runtime.gd")
const CONTACT_REPORT:="res://build/current-test-reports/source-contact-main.json"
var contact_evidence:Array=[]
class ObservedSurface extends "res://scripts/surface_model.gd":
	const ObservedFuel=preload("res://scripts/source_fuel_flight_bridge.gd")
	var fail_next_contact:=false
	var precontact_commands:Array=[]
	func _queue_source_contact(ship:RefCounted,kind:String,hit:Dictionary={})->bool:
		var accepted:=super._queue_source_contact(ship,kind,hit)
		if accepted and fail_next_contact:
			fail_next_contact=false;_pending_source_contact.kind="explicit-malformed-provider-fixture"
		return accepted
	func step(dt:float,ship:RefCounted,steering:Vector2,roll:float,lift:=0.0)->void:
		super.step(dt,ship,steering,roll,lift)
		precontact_commands=ObservedFuel.commands(ship,dt)

func last_contact()->Dictionary:return game.source_contact_last.duplicate(true)
func resolution()->Dictionary:return last_contact().get("resolution",{}).duplicate(true)
func hp_detail()->Dictionary:return last_contact().get("hpdetail",{}).duplicate(true)
func contact_facts()->Dictionary:
	return {"last":last_contact(),"hull_percent":game.ship.hull,"raw_hull_u16":thermal().hull_u16,"raw_shield_u16":thermal().shield_u16,"position_m":str(game.ship.position),"velocity_mps":str(game.ship.velocity),"attitude":str(game.ship.attitude),"surface_landed":game.surface.landed,"agl_m":game.surface.altitude(game.ship),"gear":gear()}
func contact_pose(height:float,velocity:Vector3,attitude:=Quaternion.IDENTITY)->void:
	game.surface.landed=false;game.surface.landing=false;game.surface.taking_off=false;game.surface.cancel_vertical()
	game.ship.position=Vector3(0,game.surface.height_at(0,0)+game.surface.clearance(game.ship)+height,0)
	game.ship.velocity=velocity;game.ship.attitude=attitude;game.ship.target_speed=0;game.ship.assisted=false;game.ship.autopilot=false
func set_contact_hull_fixture(percent:float)->bool:
	# The actual old thermal-extension binding preserves fractional visible HP;
	# no alternate contact HP state or test-only damage callback is introduced.
	var value:Dictionary=copied(payload());value.navigation.source_hyperdrive.erase("thermal_system");value.flight.hull=percent
	return load_fixture(value,"Explicit previous-save hull anchor %.6f percent"%percent)
func has_contact()->bool:
	var present:bool=not resolution().is_empty()
	check(present,"Actual Main consumes a real source-surface contact candidate")
	return present
func source_damage_once(before_percent:float,before_raw:int,minimum_amount:=100)->void:
	if not has_contact():return
	var native:=resolution();var detail:=hp_detail()
	check(not native.landing_accepted and (int(native.return_flags_u8)&0x80)!=0,"Unsafe physical contact retains the original F575 unsafe flag")
	check(native.damage_calls.size()==1 and int(native.damage_calls[0].amount_s32)==minimum_amount and int(native.damage_calls[0].attacker_u32)==0,"Original player contact emits its source mass-based minimum F953 request exactly once")
	check(int(detail.applied_calls)==1 and int(detail.raw_hull_before)==before_raw and int(detail.raw_hull_after)==before_raw-minimum_amount,"Main applies one original raw damage request to the existing HP owner")
	check(game.ship.hull==before_percent-float(minimum_amount)*100.0/int(thermal().full_hull_u16),"Phone hull projects the authoritative source raw damage once without a second impact law")
	var before:=state();var hp:=thermal();var pose:Vector3=game.ship.position;var velocity:Vector3=game.ship.velocity
	check(game._apply_pending_source_contact(),"Applying an already-consumed contact queue is an accepted no-effect")
	check(state()==before and thermal()==hp and game.ship.position==pose and game.ship.velocity==velocity,"An already-consumed geometric hit cannot replay HP, RNG or pose correction")

func healthy_source_landing_above_old_six()->void:
	if not await stage_gear_surface(2.0):return
	check(game._source_contact_enabled(),"Actual full source surface enables the bounded original contact continuation")
	complete_gear(true);contact_pose(-0.01,Vector3(0,-0.5,-10))
	var hull:float=game.ship.hull;var raw:int=thermal().hull_u16;game._tick(0.001,Vector2.ZERO,0)
	if not has_contact():return
	var native:=resolution();var detail:=hp_detail()
	check(int(last_contact().body_model_index)==int(game.world.by_id[game.surface.body_id].model_index) and int(last_contact().ship_model_index)==38,"Main diagnostics identify the real source body and Cobra model instead of an inferred visual radius")
	check(native.landing_accepted and (int(native.return_flags_u8)&0x40)!=0 and (int(native.return_flags_u8)&0x80)==0,"Aligned fully deployed contact uses the original accepted-landing flags")
	check(int(native.l1_speed_s32)>61 and int(native.l1_speed_s32)<=600,"Actual source L1 landing predicate accepts this speed above the previous phone6m/s limit")
	check(native.damage_calls.is_empty() and int(detail.applied_calls)==0 and game.ship.hull==hull and int(thermal().hull_u16)==raw,"Healthy accepted contact never invents an impact damage request")
	check(game.surface.landed and game.ship.velocity==Vector3.ZERO and bool(last_contact().parked),"Main parks the accepted source contact with zero relative velocity")
	var placed:=ContactFrame.sample(game.surface,game.ship)
	check(placed.ok and placed.mesh_normal_is_native_contact_normal==false,"Published terrain supplies the contact event while source kind1 retains its native radial-normal policy")
	var save:Dictionary=copied(payload());check(load_fixture(save,"Accepted source-contact parked state"),"Actual whole-game decoder restores a healthy source landing")
	check(game.surface.landed and game.ship.hull==hull and int(thermal().hull_u16)==raw,"Cold restore neither reapplies contact damage nor loses the parked state")
	check(game._takeoff_action(),"Actual takeoff remains available after native accepted contact")
	for index in range(12):game._tick(1.0/60.0,Vector2.ZERO,0,1)
	check(not game.surface.landed and game.ship.velocity.y>0 and game.ship.hull==hull,"The real phone lift leaves a healthy source landing without HP loss or a control lockout")
	contact_evidence.append({"case":"actual_source_accepted_above_old_phone_speed","contact":native,"hull_percent":hull,"manual_landing_claim":false})

func retracted_and_bad_inclination()->void:
	for cause:String in ["gear_retracted","bad_inclination"]:
		if not await stage_gear_surface(2.0):return
		complete_gear(cause=="bad_inclination")
		var tilt:=Quaternion(Vector3.FORWARD,PI*0.5) if cause=="bad_inclination" else Quaternion.IDENTITY
		contact_pose(-0.01,Vector3(0,-0.5,0),tilt)
		var hull:float=game.ship.hull;var raw:int=thermal().hull_u16;game._tick(0.001,Vector2.ZERO,0)
		source_damage_once(hull,raw)
		if not has_contact():continue
		var immediate:=contact_facts()
		check(not game.surface.landed and game.ship.velocity.y>=0 and absf(game.surface.altitude(game.ship))<=game.surface.CONTACT_QUANTIZATION_METRES,"Original unsafe contact rebounds at the native millimetre contact plane without an invented gear-up hover")
		if cause=="bad_inclination":check(int(resolution().alignment_q31)<0x78000000,"The inclined fixture fails the actual original up/normal alignment threshold")
		var height:float=game.surface.altitude(game.ship);var after_hull:float=game.ship.hull
		for index in range(8):game._tick(1.0/60.0,Vector2.ZERO,0,1)
		check(game.ship.hull==after_hull and game.surface.altitude(game.ship)>height and game.ship.velocity.y>0,"Actual lift immediately escapes the source rebound without repeating its damage")
		var unsafe_facts:=contact_facts()
		if cause=="gear_retracted":
			complete_gear(true);contact_pose(-0.01,Vector3(0,-0.5,0));game._tick(0.001,Vector2.ZERO,0)
			check(game.surface.landed and game.ship.hull==after_hull and resolution().damage_calls.is_empty(),"A new fully deployed aligned recovery contact preserves the HP left by the source rebound")
			check(game._takeoff_action(),"The actual takeoff command remains usable after recovery from a damaging source contact")
			for index in range(8):game._tick(1.0/60.0,Vector2.ZERO,0,1)
			check(not game.surface.landed and game.ship.velocity.y>0 and game.ship.hull==after_hull,"Phone lift leaves the recovery landing without control lockout or replayed damage")
		contact_evidence.append({"case":"actual_source_unsafe_"+cause,"immediate":immediate,"facts":unsafe_facts,"recovered_hull_percent":game.ship.hull,"expected_raw_minimum_damage":100,"removed_phone_hold_claim":false,"second_contact_placement_fixture":cause=="gear_retracted"})

func high_speed_and_fractional_cold()->void:
	if not await stage_gear_surface(2.0):return
	complete_gear(true);contact_pose(-0.01,Vector3(0,-80,0));var hull:float=game.ship.hull;var raw:int=thermal().hull_u16
	game._tick(0.001,Vector2.ZERO,0)
	if has_contact():
		check(not resolution().landing_accepted and int(resolution().l1_speed_s32)>600,"Deployed gear cannot bypass the original raw L1 speed limit")
		var calls:Array=resolution().damage_calls;var amount:int=int(calls[0].amount_s32) if calls.size()==1 else -1
		check(calls.size()==1 and amount>=100,"A hard source impact supplies its own bounded F953 damage amount")
		if game.ship.hull>0:check(game.ship.hull==hull-float(amount)*100.0/int(thermal().full_hull_u16) and int(thermal().hull_u16)==raw-amount,"High-speed impact projects its exact native raw HP loss without a phone speed multiplier")
		contact_evidence.append({"case":"actual_source_hard_speed","facts":contact_facts()})
	if not await stage_gear_surface(2.0):return
	check(set_contact_hull_fixture(37.625),"A fractional old-save HP anchor prepares the native contact continuation")
	complete_gear(false);contact_pose(-0.01,Vector3(0,-0.5,0));raw=thermal().hull_u16;game._tick(0.001,Vector2.ZERO,0)
	source_damage_once(37.625,raw)
	check(game.ship.hull==12.625,"Source minimum100raw loss retains the exact old37.625percent anchor")
	var cold:Dictionary=copied(payload());var hp:=thermal();var percent:float=game.ship.hull;var position:Vector3=game.ship.position;var velocity:Vector3=game.ship.velocity;var attitude:Quaternion=game.ship.attitude
	check(load_fixture(cold,"Fractional HP after original source rebound"),"Actual cold decoder accepts the post-contact source pose and raw HP")
	check(thermal()==hp and game.ship.hull==percent,"Cold restore preserves the exact shared contact HP anchor and local RNG")
	check(game.ship.position.is_equal_approx(position) and game.ship.velocity.is_equal_approx(velocity) and game.ship.attitude.is_equal_approx(attitude),"Cold restore retains the corrected phone pose within its existing serialization precision")
	check(game.surface.pending_source_contact().is_empty(),"A completed contact is not re-created as a pending hit by cold restore")
	game._apply_pending_source_contact();check(thermal()==hp and game.ship.hull==percent,"Cold continuation cannot replay the preceding source damage")
	contact_evidence.append({"case":"actual_source_fractional_rebound_cold_restore","hull_percent":percent,"raw_hull_u16":hp.hull_u16,"anchor_percent_f64_hex":hp.hull_anchor_percent_f64_hex})

func fatal_source_contact()->void:
	if not await stage_gear_surface(2.0):return
	check(set_contact_hull_fixture(20.125),"Explicit low-HP previous-save fixture prepares a fatal actual floor contact")
	complete_gear(false);contact_pose(-0.01,Vector3(0,-0.5,0))
	var hydrogen:int=inventory().hydrogen;var tank:int=fuel().jet_raw_u32;var recording:=RecordingStore.new();game.saves=recording;game.saving_enabled=true
	game._tick(0.001,Vector2.ZERO,0)
	check(game.ship.hull==0 and thermal().destroyed and not game.surface.landed,"Original raw contact damage destroys the low-HP ship without marking a successful landing")
	check(game.nav.remaining==0 and game.nav.pending_source_quote.is_empty() and inventory().hydrogen==hydrogen and int(fuel().jet_raw_u32)==tank,"Fatal Main cleanup has no pending charge and cannot spend cargo hydrogen or reaction fuel")
	check(not recording.last_payload.is_empty() and recording.last_payload.flight.hull==0,"Main emits a coherent whole-game post-contact death save")
	if not recording.last_payload.is_empty():
		var restored:Dictionary=game._decode_state(copied(recording.last_payload));check(not restored.is_empty(),"Actual strict whole-game decoder accepts the recorded source-contact death")
		if not restored.is_empty():game._commit_state(restored);game._apply_system();check(game.ship.hull==0 and thermal().destroyed,"Cold restoration cannot resurrect a native contact fatality")
	game.saving_enabled=false
	contact_evidence.append({"case":"actual_source_contact_fatality","hull_percent":game.ship.hull,"hydrogen":inventory().hydrogen,"reaction_tank_raw":fuel().jet_raw_u32,"pending_surface_jump_fabricated":false})

func pending_contact_save_boundary()->void:
	if not await stage_gear_surface(2.0):return
	complete_gear(true);contact_pose(-0.01,Vector3(0,-0.5,0))
	var hp:=thermal();var nav_before:=var_to_bytes(game.nav.snapshot())
	check(game.surface.touch_down(game.ship) and not game.surface.pending_source_contact().is_empty(),"Actual manual contact command queues the source candidate before committing HP and pose")
	var original:Dictionary=game.surface.pending_source_contact();var external:Dictionary=game.surface.pending_source_contact();external.kind="invalid";external.candidate_position=Vector3.INF
	check(game.surface.pending_source_contact()==original,"Mutating a returned candidate copy cannot change the live pending source contact")
	var recording:=RecordingStore.new();game.saves=recording;game.saving_enabled=true
	check(game._payload().is_empty() and not game._save_game() and recording.last_payload.is_empty(),"Main refuses to serialize an unresolved physical contact instead of saving its pre-damage intermediate state")
	check(thermal()==hp and var_to_bytes(game.nav.snapshot())==nav_before,"Blocking an intermediate save cannot alter authoritative HP, RNG or navigation")
	check(game._apply_pending_source_contact() and game.surface.pending_source_contact().is_empty() and game.surface.landed,"Actual Main atomically consumes and parks the accepted pending source contact")
	check(game._save_game() and not recording.last_payload.is_empty(),"Whole-game saving becomes available after the contact commit")
	if not recording.last_payload.is_empty():check(not game._decode_state(copied(recording.last_payload)).is_empty(),"Post-contact whole-game save is accepted by the actual strict decoder")
	game.saving_enabled=false
	contact_evidence.append({"case":"actual_pending_contact_atomic_save_boundary","unresolved_contact_saved":false,"source_HP_unchanged_on_blocked_save":true})

func actual_city_floor_single_hit()->void:
	fresh();game.settings.orbital_gravity=false
	var site:Dictionary={}
	for candidate:Dictionary in game.world.settlements:
		if int(candidate.get("model_index",-1))==84 and int(candidate.get("type_code",-1))==35:site=candidate;break
	check(not site.is_empty(),"Actual Sol supplies the original city84 floor fixture")
	if site.is_empty():return
	game._choose_site(str(site.id))
	for index in range(7):game._tick(0.5,Vector2.ZERO,0)
	var deadline:=Time.get_ticks_msec()+30000
	while game.busy and Time.get_ticks_msec()<deadline:await frame()
	game._process(0)
	check(game.surface.active and game.surface.source_city() and not game.surface.city_data.is_empty(),"Actual Main city transfer prepares the original compiled floor triangles")
	if not game.surface.active or game.surface.city_data.is_empty():return
	complete_gear(false);var selected:=false;var collision:Dictionary={}
	var pad:Vector3=game.surface.pad_position()
	for point:Vector2 in [Vector2(pad.x,pad.z),Vector2.ZERO,Vector2(40,40),Vector2(-40,-40),Vector2(80,-80)]:
		game.ship.position=Vector3(point.x,game.surface.height_at(point.x,point.y)+game.surface.clearance(game.ship)-0.02,point.y)
		collision=CityContacts.sweep(game.surface.city_data,game.surface.globe,game.ship.position,game.ship.position+Vector3.DOWN*0.1,game.surface.collision_radii(game.ship))
		if not collision.is_empty() and collision.normal.dot(Vector3.UP)>0.9:
			var ground:float=game.surface.height_at(collision.position.x,collision.position.z)
			if absf(float(collision.position.y)-game.surface.collision_radii(game.ship).y-ground)<=0.25:selected=true;break
	check(selected,"Explicit city fixture intersects an actual published upward-facing floor triangle")
	if not selected:return
	game.surface.landed=false;game.surface.landing=false;game.surface.taking_off=false;game.surface.cancel_vertical();game.ship.velocity=Vector3(0,-0.5,0);game.ship.attitude=Quaternion.IDENTITY;coast()
	var hull:float=game.ship.hull;var raw:int=thermal().hull_u16;game._tick(0.001,Vector2.ZERO,0)
	source_damage_once(hull,raw)
	check(hp_detail().applied_calls==1,"Overlapping city-floor and terrain candidates cannot apply the same F953 hit twice")
	contact_evidence.append({"case":"actual_city84_floor_no_duplicate_terrain_hit","site_id":site.id,"triangle_index":collision.get("triangle_index",-1),"facts":contact_facts()})

func pause_and_stale_contact_input()->void:
	if not await stage_gear_surface(2.0):return
	complete_gear(false);contact_pose(1.0,Vector3(0,-0.5,0));game._refresh_hud();game._update_flight_controls();await frame()
	var before:=state();game._toggle_pause();game._tick(5,Vector2.ONE,1,1);game._process(0)
	check(state()==before and game.surface.pending_source_contact().is_empty(),"Actual pause cannot create contact, move the ship or damage its existing raw HP")
	game._dock_action();game._toggle_auto();game._takeoff_action();check(state()==before,"Paused landing, pilot and takeoff commands cannot force a source contact")
	game._toggle_pause();game._refresh_hud();game._update_flight_controls();await frame()
	var button:Button=game.flight_console.buttons.gear;var event:=InputEventScreenTouch.new();event.index=261;event.position=button.get_global_rect().get_center();event.pressed=true
	root.push_input(event,true);await frame();check(button.pointer_id==261,"Actual gear input owns a pointer before the source-contact focus boundary")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);event.pressed=false;root.push_input(event,true);await frame();game._advance_controls(5)
	check(state()==before and button.pointer_id==-1,"A stale gear release after focus loss cannot alter the upcoming contact request or damage state")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	contact_evidence.append({"case":"actual_contact_pause_and_stale_pointer","stale_command_replayed":false})

func failed_pending_freeze_and_retry()->void:
	if not await stage_gear_surface(2.0):return
	complete_gear(true);contact_pose(-0.01,Vector3(0,-0.5,0));check(game.surface.touch_down(game.ship),"Actual floor command prepares the failed-candidate boundary fixture")
	var original:Dictionary=game.surface.pending_source_contact();var nav_before:=var_to_bytes(game.nav.snapshot());var gear_before:Dictionary=game.landing_gear.snapshot();var flight_before:=var_to_bytes(game.ship.snapshot());var hp:=thermal()
	var state_before:RefCounted=game.surface.source_render_state;var worker_before:Thread=game.ground_view._source_worker
	var finished_before:int=game.ground_view.source_stream_stats().jobs_finished
	for corruption:Dictionary in [{"kind":"explicit-malformed-provider-fixture"},{"body_id":"explicit-stale-body-fixture"},{"frame_index":game.surface.frame_index+1}]:
		game.surface._pending_source_contact=original.duplicate(true)
		for key:String in corruption:game.surface._pending_source_contact[key]=corruption[key]
		for index in range(3):game._tick(0.5,Vector2.ONE,1,1);game._process(0)
		check(var_to_bytes(game.nav.snapshot())==nav_before and game.landing_gear.snapshot()==gear_before and thermal()==hp and var_to_bytes(game.ship.snapshot())==flight_before,"Failed/stale pending retries freeze gear, calendar, fuel, HP/RNG and physical pose before new simulation time")
		check(not game.source_contact_error.is_empty() and (game.notice.text.contains("отчёт") or game.notice.text.contains("сохранени")),"Failed contact exposes recoverable report/reload guidance")
		game._brake();game._toggle_landing_gear();game._dock_action();game._takeoff_action();game._toggle_auto()
		check(var_to_bytes(game.nav.snapshot())==nav_before and game.landing_gear.snapshot()==gear_before and var_to_bytes(game.ship.snapshot())==flight_before,"Physical commands cannot bypass the unresolved-contact boundary")
	check(game.surface.source_render_state==state_before and game.ground_view._source_worker==worker_before and int(game.ground_view.source_stream_stats().jobs_finished)==finished_before,"Display processing leaves source collision geometry and its pending worker unconsumed while contact is unresolved")
	game._refresh_hud();game._update_flight_controls();await frame()
	check(game.flight_console.buttons.menu.input_allowed and not game.flight_console.buttons.gear.input_allowed,"The actual pending-contact console retains its menu pointer while blocking physical gear input")
	var menu_button:Button=game.flight_console.buttons.menu;var menu_touch:=InputEventScreenTouch.new();menu_touch.index=263;menu_touch.position=menu_button.get_global_rect().get_center();menu_touch.pressed=true
	root.push_input(menu_touch,true);await frame()
	check(menu_button.pointer_id==263,"The real recovery menu owns its held phone pointer while contact is unresolved")
	for index in range(2):game._process(0);game._tick(0.5,Vector2.ZERO,0);await frame()
	check(menu_button.pointer_id==263,"A menu press survives display updates and repeated failure processing before its release")
	menu_touch.pressed=false;root.push_input(menu_touch,true);await frame()
	check(game.menu.visible and game.menu_title.text=="КОМАНДИР","Actual onscreen menu touch opens recovery controls while the source contact remains unresolved")
	var actions:Array=[]
	for node in game.menu_rows.get_children():
		if node is Button:actions.append(node.text)
	check(actions.has("Загрузить последнее сохранение") and actions.has("Отчёт об ошибке / логи"),"The real pending-contact menu exposes last-save recovery and diagnostic-report actions")
	var surface_before:RefCounted=game.surface;game._begin_graphics_demo()
	check(game.graphics_return.is_empty() and game.surface==surface_before and not game.surface.pending_source_contact().is_empty(),"Graphics preview cannot bypass the unresolved source contact or replace it with an invalid empty backup")
	check(var_to_bytes(game.nav.snapshot())==nav_before and game.landing_gear.snapshot()==gear_before and thermal()==hp,"Opening recovery/report controls cannot advance or damage the unresolved game state")
	game._close_menu()
	game._show_backup();check(game.backup_edit!=null and game.backup_edit.text.is_empty(),"Unresolved contact cannot be encoded as an invalid replacement backup; the import field stays available")
	game._close_menu();game.surface._pending_source_contact=original.duplicate(true);game._tick(5,Vector2.ONE,1,1)
	check(game.surface.pending_source_contact().is_empty() and game.source_contact_error.is_empty() and game.surface.landed,"A repaired actual candidate resolves on retry without another physical interval")
	check(var_to_bytes(game.nav.snapshot())==nav_before and saved_gear()==gear_before and thermal()==hp,"Completing a manual pending candidate does not invent retry time, gear movement or fuel/HP updates")
	var days:float=game.nav.elapsed_days;game._tick(0.01,Vector2.ZERO,0)
	check(game.nav.elapsed_days>days,"Normal simulation resumes after the pending source contact has committed")
	contact_evidence.append({"case":"failed_stale_contact_retry_boundary","fixture":"Explicit private candidate kind/body/frame corruptions; real provider geometry and source terminal response retained","invalid_backup_created":false,"retry_dt_applied":false})

func powered_contact_interval_once()->void:
	if not await stage_gear_surface(2.0):return
	complete_gear(true);check(set_fuel_fixture({"jet_update_remainder_raw":49709}),"Explicit original F152 boundary prepares one powered-contact debit")
	var observed:=ObservedSurface.new();observed.set_source_time(game.nav.elapsed_days)
	check(observed.restore(copied(game.surface.snapshot()),game.ship,game.world),"Instrumented Surface restores the actual original source frame and provider state")
	game.surface=observed;game._apply_system();observed.fail_next_contact=true
	contact_pose(-0.01,Vector3(5,-2,0),Quaternion(Vector3.FORWARD,PI*0.5));game.ship.target_speed=game.ship.MAX_SPEED
	var tank:int=fuel().jet_raw_u32;var days:float=game.nav.elapsed_days;var dt:=1.0/60.0
	game._tick(dt,Vector2.ZERO,0)
	var commands:Array=observed.precontact_commands.duplicate();var interval:Dictionary=game._source_contact_interval.duplicate(true)
	check(not observed.pending_source_contact().is_empty() and not interval.is_empty() and interval.commands==commands and float(interval.seconds)==dt,"Actual Main retains the powered interval's commands before native contact changes the ship basis")
	check(commands!=[0,0,0] and fuel().jet_raw_u32==tank,"Real powered impulse is present while the failed contact defers its fuel completion")
	var failed_days:float=game.nav.elapsed_days;var gear_before:Dictionary=game.landing_gear.snapshot()
	check(absf(failed_days-days-dt/86400.0)<1e-11,"The original failed physical interval advances its calendar exactly once")
	observed._pending_source_contact.kind="terrain";game._tick(0.5,Vector2.ONE,1,1)
	var expected:=Jet.consumption(100,commands,1);var post:Array=ObservedSurface.ObservedFuel.commands(game.ship,dt)
	check(not interval.is_empty() and game._source_contact_interval.is_empty() and observed.pending_source_contact().is_empty(),"Retry commits the stored physical interval and clears it exactly once")
	check(commands!=post,"The powered fixture actually changes its nozzle projection across the native response basis")
	check(int(fuel().jet_raw_u32)==tank-int(expected.amount_u32),"Actual source F938 debit uses pre-impact force words once at the original F152 boundary")
	check(game.nav.elapsed_days==failed_days and saved_gear()==gear_before,"Retry completion ignores the new caller dt and cannot advance calendar or gear twice")
	var fuel_after:=fuel();game._tick(0,Vector2.ZERO,0)
	check(fuel()==fuel_after and game.nav.elapsed_days==failed_days,"A subsequent zero-time frame cannot replay the deferred source debit")
	contact_evidence.append({"case":"powered_native_contact_deferred_interval","instrumentation":"Actual Surface.super.step with command recording and a one-shot malformed classification kind; no physics or geometry replacement","source_commands_before":commands,"source_commands_after":post,"original_dt_seconds":dt,"ignored_retry_dt_seconds":0.5,"expected_raw_debit":expected.amount_u32,"actual_raw_debit":tank-int(fuel_after.jet_raw_u32)})

func native_rank_one_main()->void:
	if not await stage_gear_surface(2.0):return
	complete_gear(false)
	# Explicit north-pole frame and tangential post-classification fixture. The
	# source field, original raw continuation and Main HP/pose commit stay real.
	game.surface.globe.latitude=PI/2;game.surface.globe.longitude=0;game.surface.source_render_state=null
	contact_pose(-0.025,Vector3(-100*Physics.VELOCITY_UNIT_MPS,0,0));var attitude:Quaternion=game.ship.attitude;var velocity:Vector3=game.ship.velocity
	check(game.surface._queue_source_contact(game.ship,"terrain"),"Actual source pole field queues the explicit tangential terminal-contact fixture")
	check(game._apply_pending_source_contact(),"Actual Main commits the native rank-one response instead of dropping its damage and pose deltas")
	var facts:Dictionary=last_contact().get("facts",{})
	check(game.ship.hull==75 and hp_detail().applied_calls==1 and not game.surface.landed,"Native rank-one orientation does not suppress its real100raw F953 request")
	check(absf(float(facts.get("native_orientation_determinant",1)))<0.0001 and facts.get("orientation_projection_policy")=="native-rank-deficient-preserve-phone-quaternion-v1","Main diagnostics retain the native singular result and name the explicit phone projection policy")
	check(game.ship.attitude==attitude and game.ship.velocity!=velocity and game.surface.pending_source_contact().is_empty(),"Phone Quaternion remains valid while the other original native deltas are applied exactly once")
	contact_evidence.append({"case":"actual_Main_native_rank_one_projection","fixture":"Explicit real source terrain north-pole frame and tangential post-classification queue; no complete classifier/manual travel claim","facts":contact_facts()})

func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires private capture mode");quit(1);return
	root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main script failed to load");game.free();quit(1);return
	game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	check(game.automated and not game.saving_enabled,"Contact regression never reads or writes ordinary player progress")
	await healthy_source_landing_above_old_six();await retracted_and_bad_inclination();await high_speed_and_fractional_cold();await actual_city_floor_single_hit();await pending_contact_save_boundary();await failed_pending_freeze_and_retry();await powered_contact_interval_once();await native_rank_one_main();await pause_and_stale_contact_input();await fatal_source_contact()
	var sources:Dictionary={}
	for path:String in ["scripts/main.gd","scripts/surface_model.gd","scripts/navigation.gd","scripts/source_hyperdrive_session.gd","scripts/source_surface_contact.gd","scripts/source_surface_contact_bridge.gd","tests/test_source_contact_main.gd","data/ffe_surface_contact.json"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CONTACT_REPORT.get_base_dir()));var file:=FileAccess.open(CONTACT_REPORT,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"evidence":contact_evidence,"sources":sources,"scope":"Actual Main bounded original F575/F953 integration around an explicit source-surface published-geometry event adapter. Gear/alignment/raw-speed boundaries, native mass-based damage, fractional HP/RNG/cold continuation, one-hit consumption, city-floor duplicate prevention, pause/focus and post-contact death save. Explicit observer/legacy-HP fixtures; no fabricated surface jump, manual landing, physical Android, complete classifier or performance claim."},"\t"));file.close()
	game.queue_free();await frame();print("Source contact Main: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
