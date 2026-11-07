extends "res://tests/test_source_hyperdrive_main.gd"
# Reuse the private actual-Main fixture helpers; the inherited hyperdrive test
# run is replaced below. Source contact/loadout fixtures are explicitly labelled.
const Jet=preload("res://scripts/source_jet_fuel.gd")
const Contact=preload("res://scripts/source_fuel_contact.gd")
class RecordingStore extends Store:
	var last_payload:Dictionary={}
	func write(value:Dictionary)->bool:last_payload=value.duplicate(true);sequence+=1;return true
func inventory()->Dictionary:return game.nav.snapshot().get("source_hyperdrive",{}).duplicate(true)
func fuel()->Dictionary:return inventory().fuel_system.duplicate(true)
func load_fixture(value:Dictionary,label:String)->bool:
	var restored:Dictionary=game._decode_state(copied(value));check(not restored.is_empty(),label+" is accepted by the actual whole-game decoder")
	if restored.is_empty():return false
	game._commit_state(restored);game._apply_system();return true
func set_fuel_fixture(fields:Dictionary)->bool:
	var value:=payload().duplicate(true)
	for key:String in fields:value.navigation.source_hyperdrive.fuel_system[key]=fields[key]
	return load_fixture(value,"Explicit jet/cadence boundary fixture")
func coast()->void:game.ship.assisted=false;game.ship.target_speed=0
func ticks(count:int,dt:=1.0/60.0)->void:
	for index in range(count):game._tick(dt,Vector2.ZERO,0)
func cadence_and_continuation()->void:
	fresh();var initial:=fuel();check(not initial.scoop_installed and not initial.refueller_installed,"Fresh source hardware has neither scoop nor automatic refueller")
	game.ship.assisted=false;game.ship.target_speed=game.ship.MAX_SPEED
	ticks(59);check(fuel().jet_raw_u32==initial.jet_raw_u32,"Fifty-nine powered frames do not debit the once-per-source-second F938 tank")
	game._tick(1.0/60.0,Vector2.ZERO,0)
	check(game.source_motion.is_active() and game.last_motion_result.commands_s16==[0,0,10900],"Real source flight supplies actual B6/B8/BA force words to fuel consumption")
	check(fuel().jet_raw_u32==int(initial.jet_raw_u32)-2128,"The60th frame debits one original100t×10900 force quantum, not60 frame debits")
	var saved:Dictionary=copied(payload());var old_motion:=var_to_bytes(game.source_motion.snapshot());var old_fuel:Dictionary=fuel()
	check(load_fixture(saved,"Powered fractional motion/fuel save"),"Powered save restores")
	check(var_to_bytes(game.source_motion.snapshot())==old_motion and JSON.stringify(copied(fuel()))==JSON.stringify(copied(old_fuel)),"Whole-game restore retains exact motion fraction and fuel cadence fraction")
	ticks(60);check(fuel().jet_raw_u32==int(initial.jet_raw_u32)-4256,"Restored source fuel crosses the next49710 boundary once")
	coast();var prior:int=fuel().jet_raw_u32;var moving:Vector3=game.ship.velocity;ticks(61)
	check(fuel().jet_raw_u32==prior and game.ship.velocity.length()>0 and moving.length()>0,"Inertial coast and natural gravity do not burn reaction fuel or hard-stop velocity")
	evidence.append({"case":"actual_force_cadence","first_second_debit":2128,"frame_count":60,"source_force_words":[0,0,10900]})
func exhaustion_and_manual_touch()->void:
	fresh();game.ship.assisted=false;game.ship.target_speed=game.ship.MAX_SPEED;game.ship.velocity=Vector3(30,0,0)
	set_fuel_fixture({"jet_raw_u32":1,"jet_update_remainder_raw":49709});game._tick(1.0/60.0,Vector2.ZERO,0)
	check(fuel().jet_raw_u32==0 and fuel().disabled_axes_mask_u8==0x15,"Actual Main exhaustion applies the uploaded DOS three-positive-axis mask")
	check(game.ship.velocity.length()>1 and not game.ship.forward_propulsion_available(),"Exhaustion preserves inertia while disabling direct positive thrust")
	var empty:Dictionary=copied(payload());check(load_fixture(empty,"Empty-tank dynamic-nozzle save"),"Empty source save restores")
	check(fuel().disabled_axes_mask_u8==0x15 and game.ship.source_thrust_limits_u16[4]==0,"Restored availability is derived from source fuel state before raw motion validation")
	var before_motion:Dictionary=game.source_motion.snapshot();var hydrogen:int=inventory().hydrogen
	game._show_equipment();await frame();var button:Button=game.hyperdrive_services_view.buttons.manual_jet_refuel
	var scroll:ScrollContainer=game.menu_rows.get_parent();scroll.ensure_control_visible(button);await frame();await tap(button)
	check(fuel().jet_raw_u32==Jet.RAW_PER_TONNE and inventory().hydrogen==hydrogen-1 and fuel().disabled_axes_mask_u8==0,"Actual manual-refuel touch transfers one cargo tonne and restores all six F289 limits")
	check(game.ship.forward_propulsion_available(),"Manual refill immediately restores usable forward thrust")
	var after_motion:Dictionary=game.source_motion.snapshot()
	check(not before_motion.is_empty() and not after_motion.is_empty() and before_motion.ticks_fraction_f64_hex==after_motion.ticks_fraction_f64_hex and before_motion.anchor_raw_hex==after_motion.anchor_raw_hex,"Manual refill preserves active raw-motion anchoring and sub-tick fraction")
	var before_raw:=str(before_motion.motion.body_hex).hex_decode();var after_raw:=str(after_motion.motion.body_hex).hex_decode()
	for offset in range(before_raw.size()):
		if offset>=0xbc and offset<0xc8:continue
		check(before_raw[offset]==after_raw[offset],"Manual refill leaves every non-nozzle source body byte intact "+str(offset))
	game._close_menu()
func fit_hardware()->void:
	check(dock_fixture(),"Hardware fixture docks at an actual original source bay")
	game._show_equipment();await frame()
	for id:String in ["scoop","refueller"]:
		var button:Button=game.hyperdrive_services_view.buttons["install_fuel_equipment:"+id];var scroll:ScrollContainer=game.menu_rows.get_parent();scroll.ensure_control_visible(button);await frame();await tap(button)
		check(fuel()[id+"_installed"],"Actual dock fitting touch installs source hardware: "+id)
	var button:Button=game.hyperdrive_services_view.buttons.set_refueller_enabled;var scroll:ScrollContainer=game.menu_rows.get_parent();scroll.ensure_control_visible(button);await frame();await tap(button)
	check(not fuel().refueller_enabled,"Actual runtime toggle disables the fitted refueller")
	button=game.hyperdrive_services_view.buttons.set_refueller_enabled;scroll.ensure_control_visible(button);await frame();await tap(button)
	check(fuel().refueller_enabled,"Actual runtime toggle enables the fitted refueller")
	await launch();coast()
func auto_refill_and_mount_guard()->void:
	fresh();await fit_hardware();game.world.configure(game.nav.current(),World.FULL_LAYOUT);game.ship.position=Vector3.ZERO;game.ship.velocity=Vector3.ZERO;game._apply_system()
	set_fuel_fixture({"jet_raw_u32":1,"jet_update_remainder_raw":49709});game.ship.assisted=false;game.ship.target_speed=game.ship.MAX_SPEED;var hydrogen:int=inventory().hydrogen
	game._tick(1.0/60.0,Vector2.ZERO,0)
	check(fuel().jet_raw_u32==Jet.RAW_PER_TONNE and inventory().hydrogen==hydrogen-1,"Fitted and enabled source auto-refueller transfers one tonne during actual powered flight")
	check(fuel().disabled_axes_mask_u8==0 and game.ship.forward_propulsion_available(),"Automatic refill before source depletion preserves live directional limits")
	fresh(false);game.ship.ship_id="shuttle";game.ship.goods.clear();check(game._enable_source_hyperdrive(),"Explicit bare Shuttle fixture starts with its real source specification")
	game._apply_system();dock_fixture();var before:=state();game._hyperdrive_service_command("install_fuel_equipment","scoop",1)
	check(state()==before and not fuel().scoop_installed,"Actual Main fitting cannot invent a source scoop mounting on an unsupported ship")
func place_contact(body_id:String,speed:=900.0)->Dictionary:
	var body:Dictionary=game.world.by_id[body_id];var meta:=Contact.metadata(int(body.model_index));var centre:Vector3=game.world.local_meters(body_id,game.nav.elapsed_days)
	game.ship.position=centre+Vector3(float(meta.outer_bound_m)*0.95,0,0);game.ship.velocity=Vector3(0,speed,0);coast();game.source_motion.reset()
	return game.fuel_contact.sample(game.world,game.ship,game.nav.elapsed_days)
func scoop_real_contact()->void:
	fresh();await fit_hardware();var prepared:Dictionary=copied(payload());var contact:=place_contact("star")
	check(contact.ok and contact.body_id=="star" and contact.contact.flags_u8==3 and contact.speed_s32>=9000,"Actual source Sun geometry supplies a non-solid eligible contact at900m/s")
	var hydrogen:int=inventory().hydrogen;var tank:int=fuel().jet_raw_u32;game._tick(1.0/60.0,Vector2.ZERO,0)
	check(inventory().hydrogen==hydrogen+1 and fuel().jet_raw_u32==tank,"Actual Main Sun scoop puts hydrogen in cargo without filling the reaction tank")
	check(fuel().last_scoop_reason=="scooped" and fuel().cooldown_u32==149130 and game.ship.hull>0,"Real source scoop sets its original reset timer and keeps a safe0.95outer fixture alive")
	game._tick(1.0/60.0,Vector2.ZERO,0);check(inventory().hydrogen==hydrogen+1,"Cooldown prevents a second immediate source contact collection")
	load_fixture(prepared,"Source fitting baseline");place_contact("star",800);game._tick(1.0/60.0,Vector2.ZERO,0)
	check(fuel().last_scoop_reason=="too_slow" and inventory().hydrogen==hydrogen,"Actual speed below the source9000 threshold does not scoop")
	load_fixture(prepared,"Source fitting baseline");var no_scoop:=payload().duplicate(true);no_scoop.navigation.source_hyperdrive.fuel_system.scoop_installed=false;load_fixture(no_scoop,"Explicit hardware-absent fixture");place_contact("star");game._tick(1.0/60.0,Vector2.ZERO,0)
	check(fuel().last_scoop_reason=="no_scoop" and inventory().hydrogen==hydrogen,"Actual stellar contact cannot collect hydrogen without source scoop hardware")
	load_fixture(prepared,"Source fitting baseline");var full:=payload().duplicate(true);var free:int=game.nav.service_state(game.ship).free_t;full.navigation.source_hyperdrive.hydrogen+=free;full.navigation.fuel+=free;load_fixture(full,"Explicit exactly-full source hold fixture");place_contact("star");var full_h:int=inventory().hydrogen;game._tick(1.0/60.0,Vector2.ZERO,0)
	check(fuel().last_scoop_reason=="cargo_full" and inventory().hydrogen==full_h,"Actual full source hold cannot gain an extra scooped tonne")
	load_fixture(prepared,"Source fitting baseline");var gas_contact:=place_contact("jupiter");var gas_h:int=inventory().hydrogen;game._tick(1.0/60.0,Vector2.ZERO,0)
	check(gas_contact.ok and gas_contact.body_id=="jupiter" and (int(gas_contact.contact.flags_u8)&1)!=0,"Actual source Jupiter geometry supplies its own gas contact rather than borrowing stellar eligibility")
	if int(gas_contact.contact.altitude_raw_s32)<=30000000 and (int(gas_contact.contact.flags_u8)&0x80)==0:
		check(inventory().hydrogen==gas_h+1,"Actual eligible Jupiter atmosphere transfers one hydrogen tonne")
	else:check(inventory().hydrogen==gas_h,"Actual noneligible gas altitude/core contact cannot invent a collection")
	evidence.append({"case":"actual_gas_contact","fixture_position":"Jupiter centre +0.95 native outer bound, tangent900m/s","contact":gas_contact.contact,"reason_after":fuel().last_scoop_reason,"hydrogen_delta":int(inventory().hydrogen)-gas_h})
	evidence.append({"case":"actual_Sun_contact","fixture_position":"source Sun centre +0.95 native outer bound, tangent900m/s","contact":contact.contact,"geometry_branch":contact.geometry.branch,"speed_raw":contact.speed_s32,"manual_approach_or_market_supply_claim":false})
func legacy_v40_pending()->void:
	fresh();game._start_jump(ALPHA);game._tick(0.4,Vector2.ZERO,0);var old:Dictionary=copied(payload())
	old.navigation.source_hyperdrive.erase("fuel_system");old.navigation.source_hyperdrive.erase("thermal_system");var pending:Dictionary=old.navigation.pending_source_quote;pending.schema="source-hyperdrive-pending-v1";pending.erase("fuel_hardware_before_sha256")
	var restored:Dictionary=game._decode_state(old);check(not restored.is_empty(),"Actual Main accepts an old0.15.0 source session without fuel extension and its original pending-v1 quote")
	if restored.is_empty():return
	game._commit_state(restored);game._apply_system();check(game.nav.fuel_extension_upgraded and fuel().jet_raw_u32==0x40000000 and game.nav.remaining>0,"Old source session receives its explicit starter extension without discarding pending charge")
	check(game.nav.pending_source_quote.schema=="source-hyperdrive-pending-v2" and inventory().hydrogen==old.navigation.source_hyperdrive.hydrogen,"Compatible pending quote is upgraded without a fuel debit")
	ticks(27,0.1);check(game.nav.current_id==ALPHA and inventory().hydrogen==int(old.navigation.source_hyperdrive.hydrogen)-int(old.navigation.pending_fuel),"Upgraded old pending jump completes once with its original hyperfuel cost")
func pause_save_and_arrival()->void:
	fresh();game.ship.assisted=false;game.ship.target_speed=game.ship.MAX_SPEED;game._tick(0.1,Vector2.ZERO,0);var before:=state();game._toggle_pause();game._advance_controls(5.0)
	check(state()==before,"Console pause cannot progress reaction fuel, scoop cooldown or heat")
	game._toggle_pause();game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);game._advance_controls(5.0);check(state()==before,"Background time cannot catch up the source fuel scheduler")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	set_fuel_fixture({"jet_raw_u32":0x10000000});game._show_equipment();await frame();var button:Button=game.hyperdrive_services_view.buttons.manual_jet_refuel;var scroll:ScrollContainer=game.menu_rows.get_parent();scroll.ensure_control_visible(button);await frame()
	var event:=InputEventScreenTouch.new();event.index=181;event.position=button.get_global_rect().get_center();event.pressed=true;var old:=state();root.push_input(event,true);await frame();game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);event.pressed=false;root.push_input(event,true);await frame()
	check(state()==old,"Manual-refuel touch held across focus loss cannot consume cargo")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);var failing:=FailingStore.new();game.saves=failing;game.saving_enabled=true;game._fuel_runtime_command("manual_jet_refuel",false)
	check(game.notice.text.contains("Fixture save failure"),"Accepted manual refuel retains the actual save-error feedback")
	game.saving_enabled=false;game._close_menu();fresh();var recorder:=RecordingStore.new();game.saves=recorder;game.saving_enabled=true;game._start_jump(ALPHA);ticks(30,0.1)
	check(game.nav.current_id==ALPHA and not recorder.last_payload.is_empty(),"Actual source arrival emits a whole-game save")
	if not recorder.last_payload.is_empty():check(recorder.last_payload.navigation.source_hyperdrive.fuel_system==payload().navigation.source_hyperdrive.fuel_system,"Arrival save captures the post-frame fuel cadence and availability exactly")
	game.saving_enabled=false
func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires private capture mode");quit(1);return
	root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate();game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	await cadence_and_continuation();await exhaustion_and_manual_touch();await scoop_real_contact();await auto_refill_and_mount_guard();legacy_v40_pending();await pause_save_and_arrival()
	game.queue_free();await frame();var path:="res://validation/thermal-2026-11-07/fuel-main-regression.json";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()));var file:=FileAccess.open(path,FileAccess.WRITE)
	var sources:Dictionary={}
	for name:String in ["scripts/main.gd","scripts/flight_model.gd","scripts/navigation.gd","scripts/source_hyperdrive_session.gd","scripts/source_motion_bridge.gd","scripts/hyperdrive_services_view.gd","scripts/source_fuel_flight_bridge.gd","tests/test_source_fuel_main.gd","data/ffe_fuel.json"]:sources[name]=FileAccess.get_sha256("res://"+name)
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"evidence":evidence,"sources":sources,"scope":"Actual Main source force/cadence, dynamic DOS nozzle availability/manual touch, raw continuation, source-Sun geometry scoop boundary fixtures, oldv40/pending compatibility, pause/background and private save boundaries; no physical phone, manual stellar approach or original-market proof."},"\t"))
	print("Source fuel Main: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
