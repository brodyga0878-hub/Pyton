extends "res://tests/test_source_fuel_main.gd"
# Actual Main integration. Natural contact points, old-save shapes and raw
# boundary states below are explicit fixtures, never fabricated flight claims.
const Atmosphere=preload("res://scripts/source_atmospheric_dynamics.gd")
const AtmosphereContact=preload("res://scripts/source_atmosphere_contact.gd")
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const Surface=preload("res://scripts/surface_model.gd")
const Physics=preload("res://scripts/source_physics_bridge.gd")
const REPORT:="res://validation/contact-2026-11-08/thermal-main-regression.json"
var atmosphere_contact:=AtmosphereContact.new()

func thermal()->Dictionary:return inventory().get("thermal_system",{}).duplicate(true)
func f64_hex(value:float)->String:
	var raw:=PackedByteArray();raw.resize(8);raw.encode_double(0,value);return raw.hex_encode()
func set_thermal_fixture(fields:Dictionary)->bool:
	var value:Dictionary=copied(payload())
	for key:String in fields:value.navigation.source_hyperdrive.thermal_system[key]=fields[key]
	return load_fixture(value,"Explicit thermal boundary fixture")
func stage_natural(body_id:String="earth",height:=5000.0,speed:=900.0)->Dictionary:
	# Prepare the actual source field, then place an explicitly labelled test
	# observer above its sampled ground. No contact flags/height are injected.
	game._close_menu();game.world.focus_id=body_id;game.world.selected_id=body_id;game.world.site_id=""
	game.surface=Surface.new();game.near.clear();game.source_motion.reset()
	game.ship.docked=false;game.ship.surface_mode=false;game.ship.station_available=false;game.ship.autopilot=false;game.ship.last_notice="";coast()
	var terrain:=Terrain.new();terrain.configure(game.world,body_id,"")
	check(terrain.configured_ok,"Actual source terrain configures natural fixture "+body_id)
	if not terrain.configured_ok:return {}
	var elevation:float=terrain.elevation(terrain.latitude,terrain.longitude);var tangent:Basis=terrain.basis_at(terrain.latitude,terrain.longitude)
	var orientation:Dictionary=AtmosphereContact.Gas._basis_readonly(game.world,game.world.by_id[body_id],game.nav.elapsed_days)
	check(not orientation.is_empty(),"Actual source body orientation configures natural fixture "+body_id)
	if orientation.is_empty():return {}
	var basis:Basis=orientation.basis
	game.ship.position=game.world.local_meters(body_id,game.nav.elapsed_days)+basis*tangent*Vector3(0,float(terrain.radius)+elevation+height,0)
	game.ship.velocity=basis*tangent*Vector3(speed,0,0)
	game.ship.attitude=Basis.looking_at(basis*tangent*Vector3.RIGHT,basis*tangent*Vector3.UP).get_rotation_quaternion().normalized()
	game._apply_system();game._refresh_hud()
	var contact:Dictionary=atmosphere_contact.sample(game.world,game.ship,game.surface,game.nav.elapsed_days)
	check(contact.get("ok",false) and contact.get("body_id","")==body_id,"Actual Main observer queries the selected natural body "+body_id)
	return {"terrain":terrain,"contact":contact,"height_above_sampled_ground_m":height,"elevation_m":elevation,"basis":basis*tangent}
func stage_star(speed:=900.0)->Dictionary:
	game._close_menu();game.world.focus_id="star";game.world.selected_id="star";game.world.site_id="";game.surface=Surface.new();game.near.clear();game.source_motion.reset()
	game.ship.docked=false;game.ship.surface_mode=false;game.ship.station_available=false;game.ship.last_notice="";coast()
	var metadata:=AtmosphereContact.metadata(int(game.world.by_id.star.model_index));var centre:Vector3=game.world.local_meters("star",game.nav.elapsed_days)
	game.ship.position=centre+Vector3(float(metadata.outer_bound_m)*0.95,0,0);game.ship.velocity=Vector3(0,speed,0)
	game.ship.attitude=Basis.looking_at((centre-game.ship.position).normalized(),Vector3.UP).get_rotation_quaternion().normalized();game._apply_system()
	return atmosphere_contact.sample(game.world,game.ship,game.surface,game.nav.elapsed_days)
func thermal_hooks(count:int,dt:float)->void:
	# Exercise Main's real post-physics hook while deliberately holding physical
	# integration fixed. This isolates the60Hz schedule from ballistic dt policy.
	for index in range(count):game._step_source_fuel(dt,[0,0,0])
func thermal_facts()->Dictionary:
	var value:=thermal()
	return {"heat_s32":fuel().heat_s32,"hull_u16":value.hull_u16,"shield_u16":value.shield_u16,"rng_seed_a_u32":value.rng_seed_a_u32,"rng_seed_b_u32":value.rng_seed_b_u32,"jet_update_remainder_raw":fuel().jet_update_remainder_raw,"jet_raw_u32":fuel().jet_raw_u32,"cooldown_u32":fuel().cooldown_u32,"hull_percent":game.ship.hull,"velocity_words":game.source_motion.velocity_words()}
func install_atmospheric_shielding()->void:
	check(dock_fixture(),"Shielding fitting fixture docks in an actual source bay")
	game._show_equipment();await frame();var button:Button=game.hyperdrive_services_view.buttons["install_fuel_equipment:atmospheric_shielding"]
	var scroll:ScrollContainer=game.menu_rows.get_parent();scroll.ensure_control_visible(button);await frame();await tap(button)
	check(fuel().atmospheric_shielding_installed,"Actual fitting touch installs atmospheric shielding")
	await launch();coast()

func live_heat_drag_and_shielding()->void:
	fresh();game.settings.orbital_gravity=false;var placed:=stage_natural();check(placed.contact.apply_f1014 and placed.contact.within_altitude_gate,"Real Earth atmosphere activates the original thermal branch")
	var start_speed:float=game.ship.velocity.length();var start_hull:float=game.ship.hull;var raw_hull:int=thermal().hull_u16
	ticks(30,1.0/60.0)
	var exposed:Dictionary=thermal_facts()
	check(int(fuel().heat_s32)>0 and game.ship.hull<start_hull and int(thermal().hull_u16)<raw_hull,"Actual unshielded flight accumulates heat and applies real F953 hull loss")
	check(game.ship.velocity.length()<start_speed and thermal().last_drag_active,"Actual Main applies source drag to the live ship velocity")
	check(is_equal_approx(start_hull-game.ship.hull,float(raw_hull-int(thermal().hull_u16))*100.0/int(thermal().full_hull_u16)),"Phone hull loss follows the authoritative raw HP delta once")
	fresh();game.settings.orbital_gravity=false;await install_atmospheric_shielding();stage_natural();var protected_hull:float=game.ship.hull;ticks(30,1.0/60.0)
	check(int(fuel().heat_s32)<int(exposed.heat_s32) and game.ship.hull==protected_hull,"Actual fitted shielding reduces source heat and prevents this fixture's small incremental hull damage")
	check(thermal().last_drag_active,"Shielding does not erase original atmospheric drag")
	evidence.append({"case":"actual_earth_heat_and_drag","fixture":"source Earth native sampled ground +5000m, tangent900m/s, gravity disabled to isolate atmosphere","unshielded":exposed,"shielded":thermal_facts(),"manual_approach_claim":false})

func old_hull_anchor_and_collision()->void:
	fresh();var old:Dictionary=copied(payload());old.navigation.source_hyperdrive.erase("thermal_system");old.flight.hull=37.625
	check(load_fixture(old,"Prior0.16 source save with partial37.625percent hull"),"Actual Main decoder accepts the prior fuel-only source session")
	check(game.ship.hull==37.625 and thermal().initialization_policy=="previous-v3-hull-anchor-v1","First thermal binding preserves the exact legacy hull percentage")
	check(thermal().hull_anchor_percent_f64_hex==f64_hex(37.625),"Legacy partial hull is anchored as exact IEEE64 rather than rounded raw HP")
	game.settings.orbital_gravity=false;stage_natural();var before_raw:int=thermal().hull_u16;ticks(6,1.0/60.0)
	var expected:float=37.625-float(before_raw-int(thermal().hull_u16))*100.0/int(thermal().full_hull_u16)
	check(game.ship.hull==expected and game.ship.hull<37.625,"Later thermal raw loss projects from the exact old percentage without healing")
	var saved:Dictionary=copied(payload());var percent:float=game.ship.hull;var raw:Dictionary=thermal()
	check(load_fixture(saved,"Partially damaged thermal continuation"),"Actual whole-game thermal continuation restores")
	check(game.ship.hull==percent and thermal()==raw,"Whole-game restore neither rounds the old anchor nor reapplies its previous damage")
	var stable:float=game.ship.hull;game._payload();game._payload();check(game.ship.hull==stable,"Repeated save projection does not double-apply source damage")
	# Now use the real current source orbit-clearance collision adapter. Its
	# independently applied10percent damage must become a new exact HP anchor.
	fresh();game.settings.orbital_gravity=false;stage_natural("earth",500,0);game._tick(0.001,Vector2.ZERO,0)
	check(game.ship.hull==90 and not game.source_motion.is_active(),"Actual source-ground clearance collision applies its existing10percent loss and resets stale motion")
	check(thermal().hull_anchor_percent_f64_hex==f64_hex(90) and game.ship.hull==90,"External collision damage reanchors thermal HP exactly once")
	var after_collision:Dictionary=copied(payload());check(load_fixture(after_collision,"Post-external-collision save"),"Post-collision whole-game state restores")
	check(game.ship.hull==90,"Cold restore cannot restore health lost to the external collision adapter")

func schedules_and_cold_restore()->void:
	var baseline:Dictionary={}
	for fps in [30,60,120]:
		fresh();stage_natural();check(game.source_motion.configure(game.world,game.ship,game.nav.elapsed_days),"Raw source body anchors the fixed-contact scheduling fixture")
		thermal_hooks(fps/2,1.0/fps)
		var current:=thermal_facts()
		if baseline.is_empty():baseline=current
		else:check(current==baseline,"Actual Main thermal hook gives identical raw heat/HP/RNG/drag/fuel after half a second at%d caller frames"%fps)
	fresh();stage_natural();game.source_motion.configure(game.world,game.ship,game.nav.elapsed_days);thermal_hooks(1,0.5)
	check(thermal_facts()==baseline,"One batched Main hook delivers the same fixed60Hz atmosphere transitions")
	fresh();stage_natural();game.source_motion.configure(game.world,game.ship,game.nav.elapsed_days);thermal_hooks(1,0.0073);thermal_hooks(17,1.0/120.0)
	var cold:Dictionary=copied(payload());thermal_hooks(43,1.0/120.0);var expected_fuel:=fuel();var expected_thermal:=thermal();var expected_motion:Dictionary=game.source_motion.snapshot();var expected_velocity:Vector3=game.ship.velocity
	check(load_fixture(cold,"Fractional thermal-phase whole-game save"),"Fractional thermal host phase restores through the actual decoder")
	thermal_hooks(43,1.0/120.0)
	check(fuel()==expected_fuel and thermal()==expected_thermal and game.source_motion.snapshot()==expected_motion and game.ship.velocity==expected_velocity,"Cold continuation retains fractional thermal phase, source tick fraction, RNG and raw drag exactly")
	evidence.append({"case":"fixed_contact_main_hook_caller_partition","caller_fps":[30,60,120],"duration_seconds":0.5,"facts":baseline,"scope":"Main post-physics thermal hook with actual native contact and anchored source velocity; physical integration held fixed deliberately, no whole-flight FPS or device benchmark claim."})

func raw_motion_delta_only()->void:
	fresh();game.settings.orbital_gravity=true;stage_natural();game._tick(0.0073,Vector2.ZERO,0)
	check(game.source_motion.is_active(),"Actual Main source flight preserves a fractional raw-motion body before thermal drag")
	var before:Dictionary=game.source_motion.snapshot();var raw_before:=str(before.motion.body_hex).hex_decode();var words:Array=game.source_motion.velocity_words()
	game._step_source_fuel(1.0/60.0,[0,0,0]);var after:Dictionary=game.source_motion.snapshot();var raw_after:=str(after.motion.body_hex).hex_decode()
	check(not after.is_empty() and game.source_motion.velocity_words()!=words,"Actual Main atmospheric coupling updates active source velocity words")
	for index in range(raw_before.size()):
		if index>=0x8c and index<0x98:continue
		check(raw_before[index]==raw_after[index],"Main drag preserves every non-integer-velocity body byte including Q16 residues "+str(index))
	var metadata:=before.duplicate(true);metadata.erase("motion");var after_metadata:=after.duplicate(true);after_metadata.erase("motion")
	check(metadata==after_metadata and game.source_motion.synchronized(game.world,game.ship,game.nav.elapsed_days),"Main drag preserves the raw anchor, attitude, days and fractional ticks at a save boundary")
	var saved:Dictionary=copied(payload());check(load_fixture(saved,"Post-drag fractional raw-motion save"),"Actual Main strict decoder accepts the post-drag source body")
	check(game.source_motion.snapshot()==after,"Cold restore preserves the exact post-drag raw snapshot")

func no_air_and_unknown_star()->void:
	fresh();game.settings.orbital_gravity=false;var mercury:=stage_natural("mercury");check(not mercury.contact.apply_f1014,"Actual airless Mercury contact does not activate F1014")
	var mercury_velocity:Vector3=game.ship.velocity;ticks(6,1.0/60.0)
	check(int(fuel().heat_s32)==0 and not thermal().last_atmosphere_active and not thermal().last_drag_active and game.ship.velocity==mercury_velocity,"Airless Mercury does not gain fictional heating or drag")
	fresh();game.settings.orbital_gravity=false;var star:=stage_star()
	check(star.ok and star.contact.altitude_raw_s32==-1 and star.altitude_s32==0x7fffffff,"Actual source Sun unknown height is normalized before the thermal branch")
	var velocity:Vector3=game.ship.velocity;ticks(6,1.0/60.0)
	check(not thermal().last_atmosphere_active and not thermal().last_drag_active and game.ship.velocity==velocity,"Unknown stellar height cannot falsely trigger F1014 heat or drag")
	evidence.append({"case":"natural_contact_boundaries","mercury":mercury.contact.contact,"Sun_raw_altitude":star.contact.altitude_raw_s32,"Sun_normalized_altitude":star.altitude_s32,"Sun_F1033_heat_may_still_apply":true})

func actual_surface_contact()->void:
	fresh();game.settings.orbital_gravity=false;stage_natural("earth",5000,0);await game._enter_surface()
	check(game.surface.active and game.surface.source_surface(),"Actual Main descent prepares and enters the source surface")
	if not game.surface.active:return
	game.ship.assisted=false;game.ship.target_speed=0;game.ship.velocity=Vector3(900,0,0);game.ship.last_notice=""
	var sample:Dictionary=atmosphere_contact.sample(game.world,game.ship,game.surface,game.nav.elapsed_days)
	check(sample.ok and sample.apply_f1014 and sample.within_altitude_gate and sample.velocity_frame=="bodyfixed_from_current_source_surface_tangent","Actual active surface uses its source field and tangent-to-body thermal frame")
	var hull:float=game.ship.hull;game._tick(1.0/60.0,Vector2.ZERO,0)
	check(int(fuel().heat_s32)>0 and game.ship.hull<hull,"Actual surface flight participates in the same heat/damage pipeline")
	evidence.append({"case":"actual_main_surface","contact":sample.contact,"velocity_frame":sample.velocity_frame,"surface_revision":game.surface.globe.revision,"manual_descent_claim":false})

func pause_touch_death_and_save()->void:
	fresh();stage_natural();game._tick(0.0073,Vector2.ZERO,0);var old:=state();game._toggle_pause();game._advance_controls(5)
	check(state()==old,"Console pause freezes heat, damage, local RNG and both thermal/fuel fractions")
	game._toggle_pause();game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);game._advance_controls(5);check(state()==old,"Background time creates no thermal catch-up");game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	for screen:String in ["equipment","system","galaxy","settings"]:
		match screen:
			"equipment":game._show_equipment()
			"system":game._show_system()
			"galaxy":game._show_routes()
			"settings":game.settings_panel.show()
		var frozen:=state();game._advance_controls(5);game._process(0)
		check(state()==frozen,"Actual modal "+screen+" freezes the thermal pipeline")
		game._close_menu();game._close_map(false);game.settings_panel.hide()
	set_fuel_fixture({"jet_raw_u32":0x10000000});game._show_equipment();await frame();var button:Button=game.hyperdrive_services_view.buttons.manual_jet_refuel;var scroll:ScrollContainer=game.menu_rows.get_parent();scroll.ensure_control_visible(button);await frame()
	var touch:=InputEventScreenTouch.new();touch.index=191;touch.position=button.get_global_rect().get_center();touch.pressed=true;var frozen:=state();root.push_input(touch,true);await frame();game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);touch.pressed=false;root.push_input(touch,true);await frame()
	check(state()==frozen,"Fuel touch held across focus loss cannot change inventory or thermal state")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);game._close_menu();fresh();stage_natural("earth",5000,10);set_fuel_fixture({"heat_s32":65534});game._start_jump(ALPHA)
	check(game.nav.remaining>0,"Actual source hyperdrive enters its charge before the overheat fixture")
	var hydrogen:int=inventory().hydrogen;var record:=RecordingStore.new();game.saves=record;game.saving_enabled=true;game._tick(1.0/60.0,Vector2.ZERO,0)
	check(game.ship.hull==0 and thermal().destroyed and game.nav.remaining==0 and game.nav.pending_source_quote.is_empty(),"Actual thermal destruction cancels the pending source charge")
	check(inventory().hydrogen==hydrogen,"Destruction before arrival does not spend pending hyperfuel")
	check(not record.last_payload.is_empty() and record.last_payload.navigation.source_hyperdrive.thermal_system==thermal() and record.last_payload.flight.hull==0,"Destruction save captures the post-thermal hull and cancellation state")
	if not record.last_payload.is_empty():check(not game._decode_state(copied(record.last_payload)).is_empty(),"Post-destruction whole-game save remains strictly restorable")
	game.saving_enabled=false;fresh();record=RecordingStore.new();game.saves=record;game.saving_enabled=true;game._start_jump(ALPHA);ticks(30,0.1)
	check(game.nav.current_id==ALPHA and not record.last_payload.is_empty(),"Actual source arrival still emits its whole-game save")
	if not record.last_payload.is_empty():check(record.last_payload.navigation.source_hyperdrive.thermal_system==thermal() and record.last_payload.navigation.source_hyperdrive.fuel_system==fuel(),"Arrival save includes both post-frame thermal and fuel clocks")
	game.saving_enabled=false

func malformed_thermal_restore_atomic()->void:
	fresh();game._tick(0.0073,Vector2.ZERO,0)
	var good:Dictionary=copied(payload());var live:=state();var models:=identities();var variants:Array=[]
	var bad:=good.duplicate(true);bad.navigation.source_hyperdrive.thermal_system={};variants.append(bad)
	bad=good.duplicate(true);bad.navigation.source_hyperdrive.thermal_system["unknown"]=0;variants.append(bad)
	bad=good.duplicate(true);bad.navigation.source_hyperdrive.thermal_system.phase_f64_hex=f64_hex(1.0);variants.append(bad)
	bad=good.duplicate(true);bad.navigation.source_hyperdrive.thermal_system.rng_seed_a_u32=0x100000000;variants.append(bad)
	bad=good.duplicate(true);bad.navigation.source_hyperdrive.thermal_system.hull_u16+=1;variants.append(bad)
	bad=good.duplicate(true);bad.flight.hull=37.625;variants.append(bad)
	bad=good.duplicate(true);bad.navigation.source_hyperdrive.thermal_system.source_digest="invalid";variants.append(bad)
	for index in range(variants.size()):
		check(game._decode_state(variants[index]).is_empty(),"Actual whole-game decoder rejects malformed or mismatched thermal state "+str(index))
		check(state()==live and identities()==models,"Rejected thermal restore preserves all live model identities and state "+str(index))

func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires private capture mode");quit(1);return
	root.size=Vector2i(1440,720);game=load("res://scenes/main.tscn").instantiate()
	if game.get_script()==null:push_error("Actual Main script failed to load");game.free();quit(1);return
	game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);await frame()
	fresh();check(game.nav.has_method("thermal_state") and not thermal().is_empty(),"Actual Main enables and binds the new source thermal extension")
	if not thermal().is_empty():
		await live_heat_drag_and_shielding();old_hull_anchor_and_collision();schedules_and_cold_restore();raw_motion_delta_only();no_air_and_unknown_star();await actual_surface_contact();await pause_touch_death_and_save();malformed_thermal_restore_atomic()
	game.queue_free();await frame();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE);var sources:Dictionary={}
	for path:String in ["scripts/main.gd","scripts/navigation.gd","scripts/source_hyperdrive_session.gd","scripts/source_motion_bridge.gd","scripts/flight_model.gd","scripts/source_atmospheric_dynamics.gd","scripts/source_atmosphere_contact.gd","scripts/hyperdrive_services_view.gd","data/ffe_atmosphere.json","tests/test_source_hyperdrive_main.gd","tests/test_source_fuel_main.gd","tests/test_source_thermal_main.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"evidence":evidence,"sources":sources,"scope":"Actual Main Earth flight/surface heat, raw drag and HP integration; exact legacy percentage anchors, source-body continuation, fixed thermal-hook caller partition, natural airless/unknown-height boundaries, modal/background/input and post-environment save ordering. Explicit terrain/charge/raw boundary fixtures; no physical Android, manual atmospheric approach, complete F942/F952/event VM or whole-flight FPS equivalence proof."},"\t"));file.close()
	print("Source thermal Main: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
