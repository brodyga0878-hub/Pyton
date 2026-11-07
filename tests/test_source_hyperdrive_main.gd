extends SceneTree
# Actual Main commands and whole-game save decoder. All disk writes below are
# private test fixtures; this process never loads ordinary player progress.
const World=preload("res://scripts/planetary_system.gd")
const Settings=preload("res://scripts/device_settings.gd")
const Store=preload("res://scripts/save_store.gd")
const Core=preload("res://scripts/source_hyperdrive.gd")
const ALPHA:=0x06a49718
class MemorySettings extends Settings:
	func load_file()->bool:quality=0;return false
class FailingStore extends Store:
	func write(_payload:Dictionary)->bool:last_error="Fixture save failure";return false
class InvalidBackupStore extends Store:
	func encode(_payload:Dictionary,_generation:int)->String:return "{}"
var game:Node3D
var checks:=0
var failures:=0
var evidence:Array=[]
var private_directory:="user://hyperdrive-main-"+str(OS.get_process_id())
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func frame()->void:await process_frame;await process_frame
func payload()->Dictionary:return game._payload()
func copied(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func state()->PackedByteArray:return var_to_bytes(payload())
func identities()->Array:return [game.ship,game.nav,game.world,game.surface,game.source_motion]
func inventory()->Dictionary:
	# This suite compares the hyperdrive inventory. The independently advancing
	# jet/thermal clock has its own complete pause/continuation tests.
	var result:Dictionary=game.nav.snapshot().get("source_hyperdrive",{}).duplicate(true)
	result.erase("fuel_system");result.erase("thermal_system");return result
func tap(button:Button,pointer:=111)->void:
	var event:=InputEventScreenTouch.new();event.index=pointer;event.position=button.get_global_rect().get_center();event.pressed=true
	root.push_input(event,true);await frame();event.pressed=false;root.push_input(event,true);await frame()
func fresh(source:=true)->void:
	game._close_menu();game.saving_enabled=false;game._new_models(World.FULL_LAYOUT)
	if source:check(game._enable_source_hyperdrive(),"Actual fresh-session hook enables the original hyperdrive")
	game._apply_system();game._safe_area();game._refresh_hud()
func dock_fixture()->bool:
	# Explicit fixture placement in a real source bay, followed by the actual
	# docking command. This does not claim a manual flight or trade took place.
	var port:Dictionary={}
	for row:Dictionary in game.world.settlements:
		if int(row.type_code) in [32,33,34]:port=row;break
	if port.is_empty():check(false,"Actual selected system supplies an orbital dock fixture");return false
	game.world.focus_id=str(port.parent);game.world.selected_id=str(port.parent);game.world.site_id=str(port.id)
	game._apply_system();game.ship.position=game.ship.STATION;game.ship.velocity=Vector3.ZERO;game.ship.target_speed=0;game.ship.attitude=game.world.source_station_basis(game.nav.elapsed_days).get_rotation_quaternion().normalized()
	game._dock_action()
	check(game.ship.docked and game.ship.has_source_station() and game.nav.has_station(),"Actual Main docks into an original orbital-station bay")
	return game.ship.docked
func launch()->void:
	game._close_menu();game._dock_action()
	for index in range(3):
		if not game.ship.docked:break
		game._tick(0.1,Vector2.ZERO,0)
	check(not game.ship.docked,"Actual source hatch/launch command returns the docked ship to flight")
	game.ship.velocity=Vector3.ZERO;game.ship.target_speed=0;game.ship.assisted=false
func source_map_and_cancel()->void:
	fresh();check(game.nav.is_source_hyperdrive() and inventory().drive_index==3 and inventory().hydrogen==4,"New Main session uses original Cobra38/class2/H4 profile")
	game.ship.velocity=Vector3(0.00123,-0.00234,0.00345);game.ship.assisted=false;game._tick(0.0073,Vector2.ZERO,0)
	check(game.source_motion.is_active(),"Actual source flight begins with live fractional native motion")
	game._show_routes();await frame();var map:Control=game.active_map;var started:=Time.get_ticks_msec()
	while map.loading() and Time.get_ticks_msec()-started<30000:await frame()
	check(not map.loading() and map.select_system(ALPHA),"Actual galaxy map selects source Alpha Centauri")
	var before:=state();var old:=identities();var quote:Dictionary=game.nav.quote_for(ALPHA,game.ship);var mapquote:Dictionary=map.model.jump_state()
	var metric:=Core.distance_raw_from_q16(game.nav.current().position_q16,game.nav.galaxy.get_system(ALPHA).position_q16)
	check(quote.ok and quote.can_jump and mapquote.reachable,"Actual Main route has a reachable original hyperdrive quote")
	check(int(quote.distance_raw)==int(metric.distance_raw) and absf(map.model.distance_ly(map.model.selected)-float(metric.distance_raw)/100.0)<0.000001,"Map distance uses real F833 rounding, not Euclidean ly conversion")
	check(int(mapquote.fuel_required)==int(quote.required_fuel) and int(mapquote.duration_raw_u32)==int(quote.duration_raw_u32),"Map cost and time equal the actual Navigation source quote")
	check(state()==before and identities()==old and game.nav.remaining==0,"Reading source route quotes preserves all live payload bytes and model identities")
	var inv:=inventory();await tap(map.buttons.jump)
	check(game.nav.remaining>0 and game.nav.pending_id==ALPHA,"Actual map jump button starts the Main source charging path")
	check(inventory()==inv,"Charge initiation reserves a quote without consuming inventory")
	game._tick(0.4,Vector2.ZERO,0);game._brake()
	check(game.nav.remaining==0 and game.nav.pending_id==-1 and game.nav.pending_source_quote.is_empty() and inventory()==inv,"Actual Main brake cancels charge with zero fuel consumption")
	evidence.append({"case":"source_map_cancel","distance_raw":quote.distance_raw,"required_fuel":quote.required_fuel,"duration_raw_u32":quote.duration_raw_u32})
func pending_save_and_arrival()->void:
	fresh();game.nav.select(ALPHA);var quote:Dictionary=game.nav.quote_for(ALPHA,game.ship);var inv:=inventory();var start_days:float=game.nav.elapsed_days
	game._start_jump(ALPHA)
	for index in range(11):game._tick(0.1,Vector2.ZERO,0)
	var paused_charge:float=game.nav.remaining;var paused_days:float=game.nav.elapsed_days
	game._show_equipment();game._advance_controls(5.0)
	check(game.nav.remaining==paused_charge and game.nav.elapsed_days==paused_days and inventory()==inv,"Equipment modal pauses a pending source charge without spending fuel or travel time")
	game._close_menu();game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);game._advance_controls(5.0)
	check(game.nav.remaining==paused_charge and game.nav.elapsed_days==paused_days,"Focus loss pauses pending source time with no catch-up debt")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	var pending:=payload();check(pending.navigation.version==3 and pending.navigation.remaining>0 and pending.navigation.has("pending_source_quote"),"Actual charging Main payload records a versioned source pending quote")
	check(inventory()==inv and absf(game.nav.elapsed_days-start_days-1.1/86400.0)<1e-12,"Pre-save charging adds ordinary seconds only and consumes no fuel")
	var encoded:String=game.saves.encode(pending,7);var envelope:Dictionary=game.saves.decode(encoded);var decoded:Dictionary=game._decode_state(envelope.payload)
	check(not decoded.is_empty(),"Whole-game save envelope and Main decoder accept a real partly charged source session")
	if decoded.is_empty():return
	var remaining:float=game.nav.remaining;game._commit_state(decoded);game._apply_system()
	check(absf(game.nav.remaining-remaining)<1e-12 and game.nav.pending_id==ALPHA and inventory().hydrogen==inv.hydrogen,"Main restore retains remaining charge and unconsumed inventory")
	var ticks:=0
	while game.nav.remaining>0 and ticks<60:game._tick(0.1,Vector2.ZERO,0);ticks+=1
	check(game.nav.current_id==ALPHA and game.world.system_id==ALPHA and game.nav.pending_id==-1 and game.nav.remaining==0,"Restored charging arrives once through actual Main and replaces the source world")
	check(inventory().hydrogen==int(inv.hydrogen)-int(quote.required_fuel),"Arrival consumes precisely the saved source quote once")
	var expected_days:=start_days+(1.1+ticks*0.1)/86400.0+float(quote.duration_raw_u32)/65536.0
	check(absf(game.nav.elapsed_days-expected_days)<1e-11,"Arrival adds original Q16 travel duration once plus actual charging seconds")
	var arrived:=inventory();var arrival_days:float=game.nav.elapsed_days
	game._tick(0.1,Vector2.ZERO,0)
	check(inventory()==arrived and absf(game.nav.elapsed_days-arrival_days-0.1/86400.0)<1e-11,"The next Main tick cannot replay fuel consumption or the travel duration")
	var final:Dictionary=game._decode_state(copied(payload()))
	check(not final.is_empty() and final.nav.current_id==ALPHA,"Arrived source session survives the complete Main decoder")
	evidence.append({"case":"pending_save_arrival","remaining_at_save":remaining,"arrival_ticks_after_restore":ticks,"expected_elapsed_days":expected_days,"actual_elapsed_days":game.nav.elapsed_days,"hydrogen_after":inventory().hydrogen})
func military_fixture()->void:
	fresh();check(dock_fixture(),"Military fixture starts in a real source dock")
	var candidate:Dictionary=copied(payload());candidate.navigation.source_hyperdrive.drive_index=11;candidate.navigation.source_hyperdrive.military=4;candidate.navigation.fuel=4
	var prepared:Dictionary=game._decode_state(candidate);check(not prepared.is_empty(),"Explicit military equipment fixture is a valid whole-game source state")
	if prepared.is_empty():return
	game._commit_state(prepared);game._apply_system();game._show_equipment();await frame()
	check(game.hyperdrive_services_view!=null and game.hyperdrive_services_view._state.military==4,"Actual equipment screen shows fixture military inventory without claiming a market transaction")
	var inv:=inventory();await launch();var quote:Dictionary=game.nav.quote_for(ALPHA,game.ship);check(quote.can_jump,"Military class2 fixture can reach source Alpha Centauri")
	game._start_jump(ALPHA)
	for index in range(31):game._tick(0.1,Vector2.ZERO,0)
	check(game.nav.current_id==ALPHA and inventory().hydrogen==inv.hydrogen and inventory().military==int(inv.military)-int(quote.required_fuel),"Actual Main military jump consumes only military fuel")
	check(inventory().radioactives==int(inv.radioactives)+int(quote.required_fuel),"Actual military arrival creates precisely the original radioactive waste")
	var before:=state();game._hyperdrive_service_command("refuel","military",1)
	check(state()==before,"A stale dock service command in flight cannot buy fuel or change credits")
	evidence.append({"case":"military_fixture_not_trade","fixture_drive_index":11,"fuel_before":inv.military,"military_after":inventory().military,"waste_after":inventory().radioactives})
func services_focus_and_save_failure()->void:
	fresh();dock_fixture();game._show_equipment();await frame()
	var view:Control=game.hyperdrive_services_view;var button:Button=view.buttons["refuel:hydrogen"];var scroll:ScrollContainer=game.menu_rows.get_parent();scroll.ensure_control_visible(button);await frame()
	check(not button.disabled,"Actual docked source workshop offers one hydrogen tonne")
	var before:=state();var event:=InputEventScreenTouch.new();event.index=131;event.position=button.get_global_rect().get_center();event.pressed=true
	root.push_input(event,true);await frame();game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);event.pressed=false;root.push_input(event,true);await frame()
	check(state()==before,"Buy touch held across focus loss cannot spend fuel credits or edit cargo")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);event.pressed=true;root.push_input(event,true);await frame();game._close_menu();event.pressed=false;root.push_input(event,true);await frame()
	check(state()==before,"Buy touch released after closing its workshop cannot execute a stale service")
	game._show_equipment();await frame();var failing:=FailingStore.new();failing.directory=private_directory.path_join("failing-slot");game.saves=failing;game.saving_enabled=true
	var inv:=inventory();var credits:int=game.ship.credits;game._hyperdrive_service_command("refuel","hydrogen",1)
	check(inventory().hydrogen==int(inv.hydrogen)+1 and game.ship.credits<credits,"Accepted workshop operation remains coherent in memory when its private save fails")
	check(game.notice.text.contains("не удалось сохранить"),"Actual Main preserves the unsaved-operation message after service feedback")
	game.saving_enabled=false;game._close_menu();await frame()
func invalid_v3_atomic()->void:
	fresh();game._start_jump(ALPHA);game._tick(0.4,Vector2.ZERO,0)
	var good:Dictionary=copied(payload());var before:=state();var old:=identities();var variants:Array=[]
	var bad:Dictionary=good.duplicate(true);bad.navigation.source_hyperdrive.source_digest="invalid";variants.append(bad)
	bad=good.duplicate(true);bad.navigation.source_hyperdrive.drive_index=15;variants.append(bad)
	bad=good.duplicate(true);bad.navigation.source_hyperdrive.adapted_cargo_t+=1;variants.append(bad)
	bad=good.duplicate(true);bad.navigation.pending_source_quote.required_fuel+=1;variants.append(bad)
	bad=good.duplicate(true);bad.navigation.pending_source_quote.duration_raw_u32+=1;variants.append(bad)
	bad=good.duplicate(true);bad.navigation.source_hyperdrive["extra"]=1;variants.append(bad)
	for at in range(variants.size()):
		check(game._decode_state(variants[at]).is_empty(),"Whole-game decoder rejects invalid source session/pending branch "+str(at))
		check(state()==before and identities()==old,"Rejected v3 branch leaves the whole live game atomic "+str(at))
func legacy_migration_and_backup()->void:
	fresh(false);check(not game.nav.is_source_hyperdrive() and game.nav.snapshot().version==2,"Old full-world v2 navigation remains the original published adapter")
	check(dock_fixture(),"Legacy migration fixture docks at an actual original port")
	game.nav.elapsed_days=125.25;game.nav.select(ALPHA);game._apply_system();var old_payload:Dictionary=copied(payload())
	var old_ship:RefCounted=game.ship;var old_world:RefCounted=game.world;var old_surface:RefCounted=game.surface
	var store:=Store.new();store.directory=private_directory;game.saves=store;game.saving_enabled=true
	check(store.write(old_payload),"Private v2 slot is persisted before migration")
	game._show_hyperdrive_migration();await frame();check(not game.nav.is_source_hyperdrive(),"Opening the migration review never silently upgrades the old session")
	game._apply_hyperdrive_migration();await frame()
	check(game.nav.is_source_hyperdrive() and game.nav.current_id==old_payload.navigation.current_id and game.nav.selected_id==ALPHA and game.nav.elapsed_days==125.25,"Explicit Main migration preserves system, target and exact clock")
	check(game.ship==old_ship and game.world==old_world and game.surface==old_surface and copied(game.ship.snapshot())==old_payload.flight,"Explicit migration preserves ship identity, goods, credits and physical pose")
	check(inventory().hydrogen==old_payload.navigation.fuel,"Explicit migration converts old fuel units to hydrogen tonnes one to one")
	var backup:String=game._latest_hyperdrive_backup();check(not backup.is_empty() and FileAccess.file_exists(backup),"Main creates a separate durable pre-migration backup")
	var code:=FileAccess.get_file_as_string(backup);var entry:=store.decode(code)
	check(not entry.is_empty() and entry.payload.navigation.version==2 and not game._decode_state(entry.payload).is_empty(),"Durable backup remains a complete valid old-v2 game")
	check(game._save_game() and game._save_game(),"Both rolling save slots can now hold v3")
	check(FileAccess.get_file_as_string(backup)==code and store.decode(code).payload.navigation.version==2,"Two new v3 slot writes cannot destroy the old-v2 migration backup")
	game._show_previous_hyperdrive_backup();await frame()
	check(game.backup_edit!=null and game.backup_edit.text==code,"Actual backup screen exposes the old-v2 code after migration")
	game._close_menu();game.saving_enabled=false
	fresh(false);dock_fixture();var baseline:=state();var models:=identities();var blocked:=InvalidBackupStore.new();blocked.directory=private_directory.path_join("invalid-backup");game.saves=blocked;game.saving_enabled=true
	game._apply_hyperdrive_migration()
	check(not game.nav.is_source_hyperdrive() and state()==baseline and identities()==models,"Failed mandatory backup aborts migration without replacing or editing any live game model")
	check(game.notice.text.contains("отменён"),"Backup failure visibly reports that migration was cancelled")
	game.saving_enabled=false;evidence.append({"case":"legacy_explicit_migration","backup_private_path":backup,"backup_navigation_version":2,"old_backup_survives_both_v3_slots":true})
func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires private capture mode");quit(1);return
	root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate();game.settings=MemorySettings.new();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);await frame();check(game.automated and not game.saving_enabled,"Actual Main test never loads ordinary player progress")
	await source_map_and_cancel();await pending_save_and_arrival();await military_fixture();await services_focus_and_save_failure();invalid_v3_atomic();await legacy_migration_and_backup()
	game.queue_free();await frame()
	var path:="res://validation/contact-2026-11-08/hyperdrive-main-regression.json";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()));var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual Main source jump, map quote, pending whole-game continuation, military fixture, explicit legacy migration/durable private backup and invalid-v3 atomicity; no physical-phone or FPS proof.","sources":{"main_sha256":FileAccess.get_sha256("res://scripts/main.gd"),"navigation_sha256":FileAccess.get_sha256("res://scripts/navigation.gd"),"session_sha256":FileAccess.get_sha256("res://scripts/source_hyperdrive_session.gd"),"test_sha256":FileAccess.get_sha256("res://tests/test_source_hyperdrive_main.gd")}},"\t"))
	print("Source hyperdrive Main: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
