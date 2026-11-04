extends SceneTree
# Focused integration checks for the new controller. No user save files are written.
# Run with: godot --headless --path . --script res://tests/test_rebuilt_app_transitions.gd -- --rebuild-capture
const SaveStore=preload("res://scripts/save_store.gd")
var game:Node3D
var checks:=0
var failures:=0
var replaced_during_entry:=false

func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<20:push_error(message)
func json_copy(value:Dictionary)->Dictionary:return JSON.parse_string(JSON.stringify(value))
func reset_models()->void:
	game._new_models();game._close_menu();game._apply_system()
func button_count()->int:
	var count:=0
	for item in game.menu_rows.get_children():
		if item is Button:count+=1
	return count

func save_candidates()->void:
	reset_models()
	var valid:Dictionary=json_copy(game._payload())
	var before:=JSON.stringify(game._payload())
	var store:=SaveStore.new()
	var envelope:=store.decode(store.encode(valid,4))
	check(not envelope.is_empty() and envelope.generation==4,"New save envelope preserves its explicit generation")
	check(not game._decode_state(envelope.payload).is_empty(),"Fresh real controller state passes the whole candidate decoder")
	var broken_envelope:Dictionary=JSON.parse_string(store.encode(valid,4))
	broken_envelope.body+=" "
	check(store.decode(JSON.stringify(broken_envelope)).is_empty(),"Envelope rejects edited bytes before candidate construction")
	for missing in ["flight","navigation","planetary","surface"]:
		var bad:=valid.duplicate(true);bad.erase(missing)
		check(game._decode_state(bad).is_empty(),"Incomplete app payload is rejected: "+missing)
	var bad:=valid.duplicate(true);bad.schema="previous-game-format"
	check(game._decode_state(bad).is_empty(),"Different whole-game format is not claimed compatible")
	bad=valid.duplicate(true);bad.flight.hull="undamaged"
	check(game._decode_state(bad).is_empty(),"Invalid flight candidate cannot load through a valid envelope")
	bad=valid.duplicate(true);bad.planetary.source_digest="other-source"
	check(game._decode_state(bad).is_empty(),"World provenance mismatch is rejected")
	bad=valid.duplicate(true);bad.planetary.focus_id="mars";bad.planetary.selected_id="mars";bad.flight.docked=true
	check(game._decode_state(bad).is_empty(),"Docked ship requires a real dock context, not any selected planet")
	check(JSON.stringify(game._payload())==before,"All failed candidate decodes leave active controller models untouched")
	game.ship.position=game.ship.STATION;game.ship.velocity=Vector3.ZERO
	check(game.ship.dock(),"Control fixture uses an actual valid dock action")
	check(not game._decode_state(json_copy(game._payload())).is_empty(),"Actual docked state loads in the default training dock context")
	var docked:Dictionary=json_copy(game._payload())
	bad=docked.duplicate(true);bad.flight.position=[0,0,0]
	check(game._decode_state(bad).is_empty(),"A docked flag cannot move the ship far from its actual dock")
	bad=docked.duplicate(true);bad.flight.velocity=[1,0,0]
	check(game._decode_state(bad).is_empty(),"A docked snapshot cannot retain flight velocity")
	bad=docked.duplicate(true);bad.flight.target_speed=1
	check(game._decode_state(bad).is_empty(),"A docked snapshot cannot keep a live throttle target")

func jump_and_transfer_controls()->void:
	reset_models()
	var stars:Array=game.nav.galaxy.all();var first:=int(stars[1].id);var second:=int(stars[2].id)
	var initial_fuel:int=game.nav.fuel
	game._start_jump(first)
	check(game.nav.remaining>0 and game.nav.pending_id==first,"Route action starts the requested hypercharge")
	var pending:Dictionary=json_copy(game._payload())
	check(not game._decode_state(pending).is_empty(),"A valid pending hyperjump survives whole-game candidate loading")
	game._start_jump(second)
	check(game.nav.pending_id==first and game.nav.remaining>0,"Different route cannot silently replace an active hypercharge")
	game._start_jump(first)
	check(game.nav.remaining==0 and game.nav.pending_id==-1 and game.nav.fuel==initial_fuel,"Repeating the same route cancels without burning fuel")
	var bad:=pending.duplicate(true)
	bad.flight.docked=true;bad.flight.position=[0,0,-2500]
	check(game._decode_state(bad).is_empty(),"A docked ship cannot load a pending hyperjump")
	bad=pending.duplicate(true);bad.planetary.selected_id="mars";bad.planetary.pending_id="mars";bad.planetary.transfer_remaining=1.0
	check(game._decode_state(bad).is_empty(),"Two mutually exclusive travel countdowns cannot load together")
	game._choose_body("mars")
	check(game.world.transfer_remaining>0 and game.world.pending_id=="mars","Body selection starts a planetary transfer")
	var transit:Dictionary=json_copy(game._payload())
	check(not game._decode_state(transit).is_empty(),"Valid pending planetary transfer loads without advancing it")
	game._choose_body("venus")
	check(game.world.pending_id=="mars","Different body does not overwrite the current planetary destination")
	game._choose_body("mars")
	check(game.world.transfer_remaining==0 and game.world.pending_id.is_empty(),"Repeating the selected body cancels its transfer")
	bad=transit.duplicate(true);bad.flight.docked=true;bad.flight.position=[0,0,-2500]
	check(game._decode_state(bad).is_empty(),"A docked ship cannot load a pending planetary transfer")
	game._choose_site("site10")
	check(game.world.transfer_remaining>0 and game.world.pending_site_id=="site10","Actual New Moscow action keeps its source site identity")
	game._choose_site("site10")
	check(game.world.transfer_remaining==0 and game.world.pending_site_id.is_empty(),"Repeating the source city cancels its pending transfer")
	game._start_jump(first);game._brake()
	check(game.nav.remaining==0 and game.nav.fuel==initial_fuel,"Brake cancels hypercharge without changing fuel")
	game._choose_body("mars");game._brake()
	check(game.world.transfer_remaining==0 and game.ship.target_speed==0,"Brake also cancels planetary transfer and requests a stop")
	game.busy=true
	game._start_jump(first);game._choose_body("mars");game._choose_site("site10")
	check(game.nav.remaining==0 and game.world.transfer_remaining==0,"Busy preparation rejects route, body and source-site actions")
	game.busy=false
	var resumed:Dictionary=game._decode_state(pending)
	game._commit_state(resumed);game._apply_system();game._tick(3.0,Vector2.ZERO,0)
	check(game.nav.current_id==first and game.world.system_id==first and not game.surface.active,"Resumed hypercharge arrives with navigation and source world in the same system")
	check(game.nav.fuel==initial_fuel-2 and game.nav.remaining==0,"Resumed hypercharge consumes its committed fuel exactly once")
	check(not game._decode_state(json_copy(game._payload())).is_empty(),"Arrived source-world state is immediately loadable")
	game._tick(0.1,Vector2.ZERO,0)
	check(game.nav.fuel==initial_fuel-2,"The next application tick cannot charge arrival fuel again")
	resumed=game._decode_state(transit)
	game._commit_state(resumed);game._apply_system();game._tick(3.0,Vector2.ZERO,0)
	check(game.world.focus_id=="mars" and game.world.transfer_remaining==0 and not game.ship.station_available,"Resumed planetary transfer arrives without a phantom dock")
	check(not game._decode_state(json_copy(game._payload())).is_empty(),"Arrived planetary-transfer state also remains loadable")

func charge_entry_guard()->void:
	reset_models()
	var first:=int(game.nav.galaxy.all()[1].id)
	game._start_jump(first)
	await game._enter_surface()
	check(not game.surface.active and not game.busy and game.nav.remaining>0,"Surface entry cannot invalidate an active hypercharge")
	check(not game._decode_state(json_copy(game._payload())).is_empty(),"Refused surface entry leaves a loadable whole-game snapshot")
	game._brake();game._choose_body("mars")
	await game._enter_surface()
	check(not game.surface.active and game.world.transfer_remaining>0,"Surface entry also preserves a pending planetary transfer")
	game._brake()
	game.surface.active=true;game.surface.flight_phase="ascent"
	game._toggle_auto()
	check(game.surface.flight_phase.is_empty() and not game.surface.landing,"Auto button cancels vertical guidance instead of starting landing")
	game.surface.flight_phase="descent";game._toggle_auto()
	check(game.surface.flight_phase.is_empty(),"Auto button cancels descent guidance too")
	reset_models()

func source_services_gating()->void:
	reset_models()
	var orbital:Dictionary={}
	for site in game.world.settlements:
		if int(site.type_code)<35:orbital=site;break
	check(not orbital.is_empty(),"Source catalogue contains an actual orbital port for service gating")
	if orbital.is_empty():return
	game.world.focus_id=str(orbital.parent);game.world.selected_id=str(orbital.parent);game.world.site_id=str(orbital.id)
	game.ship.position=game.ship.STATION;game.ship.docked=true;game._apply_system()
	check(game.ship.original_port and game.ship.station_available,"Source orbital context is distinct from the adapted training dock")
	game._show_services()
	check(button_count()==0,"Source port menu exposes no training trade, refuel or ship-exchange actions")
	var credits:int=game.ship.credits
	check(not game.ship.deliver() and game.ship.credits==credits,"Source port cannot award the adapted delivery reward")
	reset_models();game.ship.position=game.ship.STATION;game.ship.docked=true;game._apply_system();game._show_services()
	check(not game.ship.original_port and button_count()>=5,"Training dock explicitly retains its adapted services")
	game._close_menu()

func replace_models_during_entry()->void:
	check(game.busy,"Source-city preparation yielded with its busy guard active")
	game._new_models();game.ship.credits=4321;game._apply_system();replaced_during_entry=true

func async_entry_context()->void:
	reset_models();game.world.site_id="site10";game._apply_system()
	call_deferred("replace_models_during_entry")
	await game._enter_surface()
	check(replaced_during_entry and not game.busy and game.worker==null,"Prepared worker is joined after models were replaced")
	check(not game.surface.active and game.ship.credits==4321 and game.world.site_id.is_empty(),"Stale city preparation cannot activate a surface in a new flight")
	check(not game._decode_state(json_copy(game._payload())).is_empty(),"Replacement flight stays loadable after stale asynchronous entry")

func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():
		push_error("Use -- --rebuild-capture so this integration test never loads or writes user progress");quit(1);return
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	check(game.automated and not game.saving_enabled,"Actual application starts with user persistence disabled for this test")
	save_candidates();jump_and_transfer_controls();await charge_entry_guard();source_services_gating();await async_entry_context()
	game.queue_free();await process_frame
	print("REBUILT APP TRANSITIONS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
