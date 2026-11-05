extends SceneTree
# Actual controller cycle plus the existing v6 ascent/restore contract.
const Surface=preload("res://scripts/surface_model.gd")
const Ship=preload("res://scripts/flight_model.gd")
const World=preload("res://scripts/planetary_system.gd")
const Nav=preload("res://scripts/navigation.gd")
const CityRuntime=preload("res://scripts/source_city_runtime.gd")
var game:Node3D
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func json_copy(value:Dictionary)->Dictionary:return JSON.parse_string(JSON.stringify(value))
func contexts(site:String="",id:String="cobra")->Dictionary:
	var nav:=Nav.new();var world:=World.new();world.configure(nav.current());world.focus_id="earth";world.selected_id="earth";world.site_id=site
	var ship:=Ship.new();ship.ship_id=id
	if id=="shuttle":ship.equipment.append("engine");ship.goods.medicines=0
	var surface:=Surface.new();check(surface.enter(ship,world,true),"Eligible spherical departure fixture enters its actual surface")
	ship.position=Vector3(300,surface.height_at(300,200)+surface.clearance(ship)+0.5,200);ship.velocity=Vector3.ZERO
	check(surface.touch_down(ship),"Fixture lands healthy away from the selected pad")
	return {"nav":nav,"world":world,"ship":ship,"surface":surface}
func api_available(surface:RefCounted)->bool:
	var available:=surface.has_method("begin_departure")
	check(available,"Spherical departure has an explicit model API")
	return available
func state_pair(surface:RefCounted,ship:RefCounted)->String:
	# Binary values retain NaN in deliberate invalid-input cases without asking
	# JSON to invent an equivalent null or emit a diagnostic warning.
	return var_to_bytes({"surface":surface.snapshot(),"ship":ship.snapshot(),"phase":surface.flight_phase,"extended":surface.extended_flight,"taking_off":surface.taking_off,"ready":surface.ready_for_orbit,"surface_mode":ship.surface_mode,"autopilot":ship.autopilot,"combat":ship.combat_active}).hex_encode()
func restored_copy(ctx:Dictionary)->Dictionary:
	var ship:=Ship.new();var surface:=Surface.new()
	var ship_ok:=ship.restore(json_copy(ctx.ship.snapshot()))
	var surface_ok:=surface.restore(json_copy(ctx.surface.snapshot()),ship,ctx.world)
	check(ship_ok and surface_ok,"Existing ship and v6 surface decoder accept an automatic departure snapshot")
	return {"ship":ship,"surface":surface,"world":ctx.world,"nav":ctx.nav,"ok":ship_ok and surface_ok}
func to_ready(surface:RefCounted,ship:RefCounted)->void:
	for i in range(10000):
		surface.step(0.05,ship,Vector2.ZERO,0)
		if surface.ready_for_orbit or ship.hull<=0 or surface.flight_phase.is_empty():break
func model_departures()->void:
	for site in ["","site10"]:
		for id in ["cobra","eagle","shuttle"]:
			var ctx:=contexts(site,id);var surface:RefCounted=ctx.surface;var ship:RefCounted=ctx.ship
			if not api_available(surface):continue
			var immutable_world:=JSON.stringify(ctx.world.snapshot());var cargo:Dictionary=ship.goods.duplicate(true);var credits:int=ship.credits
			check(surface.pad_distance(ship)>80 and ship.hull==100,"Direct departure starts from a genuine healthy off-pad landing: "+site+id)
			check(surface.call("begin_departure",ship),"Ground departure accepts the eligible "+site+id)
			check(not surface.landed and surface.flight_phase=="ascent" and surface.extended_flight and not surface.taking_off,"Ground departure enters the existing airborne ascent phase without a new schema")
			check(surface.snapshot().version==6 and ship.assisted and ship.target_speed==0 and ship.velocity.length()<=20,"Immediate lift-off already has a valid resumable v6 ascent representation")
			var immediate:=restored_copy(ctx)
			if immediate.ok:
				check(absf(immediate.surface.altitude(immediate.ship)-surface.altitude(ship))<0.001 and immediate.surface.flight_phase=="ascent","Immediate post-command reload preserves the current location and route")
			for tick in range(100):surface.step(0.05,ship,Vector2.ZERO,0)
			check(not surface.landed and surface.altitude(ship)>1 and ship.hull==100,"Controlled ascent separates from the actual terrain without floor contact damage")
			var resumed:=restored_copy(ctx)
			if resumed.ok:
				to_ready(resumed.surface,resumed.ship)
				check(resumed.surface.ready_for_orbit and resumed.ship.hull==100 and resumed.ship.velocity.length()<2,"Midflight saved departure resumes to a stopped orbit handoff")
			to_ready(surface,ship)
			check(surface.ready_for_orbit and not surface.landed and ship.hull==100 and ship.velocity.length()<2,"Original and resumed departure both reach a safe handoff: "+site+id)
			check(ship.goods==cargo and ship.credits==credits and JSON.stringify(ctx.world.snapshot())==immutable_world,"Automatic departure cannot alter cargo, money or source-world selection")
			check(surface.leave(ship,ctx.world,ctx.nav.elapsed_days),"Completed automatic ascent uses the normal geographic orbit handoff")
			var radius:float=float(ctx.world.by_id.earth.radius_km)*1000.0
			var altitude:float=ship.position.distance_to(ctx.world.local_meters("earth",ctx.nav.elapsed_days))-radius
			check(not surface.active and not ship.surface_mode and absf(altitude-20000.0)<8.0,"Departure places the ship at the existing 20-km radial orbit reference")
			check(surface.snapshot().version==5 and ctx.world.site_id==site,"Leaving the ground retains its source anchor and the existing v5 orbit-link schema")
func cancelled_departures()->void:
	for method in ["cancel","steer","lift"]:
		var ctx:=contexts();var surface:RefCounted=ctx.surface;var ship:RefCounted=ctx.ship
		if not api_available(surface):continue
		check(surface.call("begin_departure",ship),"Cancellation fixture starts a departure")
		for i in range(50):surface.step(0.05,ship,Vector2.ZERO,0)
		var point:Vector3=ship.position
		if method=="cancel":surface.cancel_vertical()
		elif method=="steer":surface.step(0.05,ship,Vector2(0.3,0),0)
		else:surface.step(0.05,ship,Vector2.ZERO,0,1)
		check(surface.flight_phase.is_empty() and not surface.ready_for_orbit and surface.active and not surface.landed,"User "+method+" cancels the route without forcing a landing or orbit jump")
		check(ship.position.distance_to(point)<10 and ship.hull==100,"Cancellation preserves continuous healthy motion near the current location")
func rejected_departures()->void:
	for reason in ["inactive","local","destroyed","docked","combat","fast","thrust","position","velocity","hull","attitude","target_speed"]:
		var ctx:=contexts();var surface:RefCounted=ctx.surface;var ship:RefCounted=ctx.ship
		if not api_available(surface):continue
		match reason:
			"inactive":surface.active=false
			"local":surface.globe=null
			"destroyed":ship.hull=0
			"docked":ship.docked=true
			"combat":ship.combat_active=true
			"fast":surface.landed=false;ship.velocity=Vector3(21,0,0)
			"thrust":surface.gravity=ship.acceleration()
			"position":ship.position=Vector3(NAN,0,0)
			"velocity":ship.velocity=Vector3(NAN,0,0)
			"hull":ship.hull=NAN
			"attitude":ship.attitude=Quaternion(0,0,0,0)
			"target_speed":ship.target_speed=NAN
		var before:=state_pair(surface,ship)
		check(not surface.call("begin_departure",ship),"Unsafe departure context rejects "+reason)
		check(state_pair(surface,ship)==before,"Rejected "+reason+" departure cannot partially move the ship or alter route state")
		check(not surface.message.is_empty(),"Rejected "+reason+" departure explains the reason")
func explicit_takeoff_unchanged()->void:
	var ctx:=contexts();var surface:RefCounted=ctx.surface;var ship:RefCounted=ctx.ship
	check(surface.take_off(ship),"The existing separate takeoff command remains available")
	for i in range(240):surface.step(0.05,ship,Vector2.ZERO,0)
	check(surface.active and not surface.landed and not surface.taking_off and surface.flight_phase.is_empty(),"Separate takeoff stays near the ground and never silently starts orbital ascent")
	check(surface.altitude(ship)>=34.5 and surface.altitude(ship)<100 and ship.hull==100,"Separate takeoff preserves its established low-altitude lift and deceleration")
func roof_obstruction()->void:
	# Independently found ground point under a real source model84 roof. The
	# capsule is initially clear, but a purely vertical departure meets its roof.
	var ctx:=contexts("site10");var surface:RefCounted=ctx.surface;var ship:RefCounted=ctx.ship
	if not api_available(surface):return
	surface.landed=false;ship.position=Vector3(-2219.012,0,1140.938)
	ship.position.y=surface.height_at(ship.position.x,ship.position.z)+surface.clearance(ship)+0.5;ship.velocity=Vector3.ZERO
	check(surface.touch_down(ship),"Real covered-ground fixture can land below the source city roof")
	surface.recenter(ship)
	check(surface.landed and Vector2(ship.position.x,ship.position.z).length()<1 and not surface.overlaps_building(ship),"Covered ground uses a legitimate recentered free capsule, not an initial penetration")
	var start:Vector3=ship.position+Vector3.UP*0.3
	var roof:Dictionary=CityRuntime.sweep(surface.city_data,surface.globe,start,start+Vector3.UP*1000,surface.collision_radii(ship))
	check(not roof.is_empty() and roof.normal.y< -0.5,"An independent existing CCD query finds the real roof above the grounded ship")
	var before:=state_pair(surface,ship)
	check(not surface.call("begin_departure",ship),"An automatic departure refuses the obstructed vertical route before climbing into a roof")
	check(state_pair(surface,ship)==before and ship.hull==100 and surface.landed,"Obstruction refusal preserves position, grounded state, hull and route atomically")
func airborne_surface_action()->void:
	# Reuse the actual loaded district; a safe stopped flight at100m is a valid
	# state after a short takeoff, without requiring another expensive city load.
	game.surface.landed=false;game.surface.landing=false;game.surface.taking_off=false
	game.ship.position.y=game.surface.height_at(game.ship.position.x,game.ship.position.z)+game.surface.clearance(game.ship)+100.0
	game.ship.velocity=Vector3.ZERO;game.ship.target_speed=0
	check(absf(game.surface.altitude(game.ship)-100.0)<0.01 and game.surface.flight_phase.is_empty(),"Actual upper-surface action fixture is stopped in flight below the former500m threshold")
	game._refresh_hud();game._process(0.0)
	check(game.surface_button.text=="На орбиту","Upper surface button advertises the orbital action while already airborne")
	game.surface_button.pressed.emit()
	check(game.surface.flight_phase=="ascent" and game.surface.extended_flight and not game.surface.landed,"Upper На орбиту action begins the existing route directly from100m")
	var before:=JSON.stringify(game._payload());var identities:Array=[game.ship,game.surface,game.world,game.nav]
	game.surface_button.pressed.emit()
	check(JSON.stringify(game._payload())==before and [game.ship,game.surface,game.world,game.nav]==identities,"Pressing upper orbital action again preserves the running ascent and all four game models")
	var point:Vector3=game.ship.position;game._brake()
	check(game.surface.flight_phase.is_empty() and not game.surface.ready_for_orbit and game.surface.active and not game.surface.landed and game.ship.position==point,"Brake cancels this low-altitude orbital action without jumping, landing or moving the ship")
	game.ship.position.y=game.surface.height_at(game.ship.position.x,game.ship.position.z)+game.surface.clearance(game.ship)+0.5
	game.ship.velocity=Vector3.ZERO
	check(game.surface.touch_down(game.ship),"The same actual district remains usable for the following grounded departure cycle")
func controller_cycle()->void:
	var scene:PackedScene=load("res://scenes/main.tscn")
	if scene==null:check(false,"Actual Main scene is available to the controller test");return
	game=scene.instantiate()
	if game.get_script()==null:
		check(false,"Actual Main script compiled successfully before testing its cycle")
		game.free();return
	root.add_child(game);game.set_process(false);game.set_physics_process(false)
	check(game.automated and not game.saving_enabled,"Controller test never loads or writes user progress")
	game.world.focus_id="earth";game.world.selected_id="earth";game.world.site_id="site10";game._apply_system()
	await game._enter_surface()
	game.ship.position=Vector3(300,game.surface.height_at(300,200)+game.surface.clearance(game.ship)+0.5,200);game.ship.velocity=Vector3.ZERO
	check(game.surface.touch_down(game.ship),"Actual source city allows healthy manual off-pad touchdown")
	check(game.surface.pad_distance(game.ship)>80 and game.ship.hull==100,"Actual controller starts from an undamaged off-pad landing")
	airborne_surface_action()
	game._refresh_hud();game._process(0.0)
	var generation:int=game.saves.sequence;var cargo:Dictionary=game.ship.goods.duplicate(true);var credits:int=game.ship.credits
	game.auto_button.pressed.emit()
	check(game.surface.flight_phase=="ascent" and not game.surface.landed,"Actual classic Auto command starts departure directly from the ground")
	if game.surface.flight_phase=="ascent":
		check(game.auto_button.text=="Отмена","The lower panel exposes cancellation while departure is active")
		var immediate:Dictionary=game._decode_state(json_copy(game._payload()))
		check(not immediate.is_empty(),"Actual complete game decoder accepts immediate departure progress")
		for tick in range(100):game._tick(0.05,Vector2.ZERO,0)
		var resumed:Dictionary=game._decode_state(json_copy(game._payload()))
		check(not resumed.is_empty() and resumed.surface.flight_phase=="ascent","Actual complete game decoder retains an airborne saved route")
		if not resumed.is_empty():game._commit_state(resumed);game._apply_system()
		for tick in range(10000):
			game._tick(0.05,Vector2.ZERO,0)
			if not game.surface.active:break
		check(not game.surface.active and game.ship.hull==100 and not game.ship.surface_mode,"Actual Main completes ascent and invokes its geographic orbit handoff")
		check(game.world.site_id=="site10" and not game.ship.station_available and game.ship.original_port,"Departure preserves the original ground-port context instead of injecting a training station")
		var balance:int=game.ship.credits
		check(not game.ship.deliver() and not game.ship.buy() and game.ship.credits==balance,"Source-port context cannot receive adapted training services")
		check(not game._decode_state(json_copy(game._payload())).is_empty(),"Completed orbit handoff remains a valid full save")
		check(game.world.select(game.world.default_id) and game.world.begin_transfer(game.ship,game.nav,""),"User can explicitly choose the existing training-dock approach after returning to orbit")
		for tick in range(100):
			game._tick(0.05,Vector2.ZERO,0)
			if game.world.transfer_remaining==0:break
		check(game.world.site_id.is_empty() and game.ship.station_available and not game.ship.original_port,"Explicit transfer alone selects the adapted training station")
		game._toggle_auto()
		for tick in range(4000):
			game._tick(0.05,Vector2.ZERO,0)
			if game.ship.docked:break
		check(game.ship.docked and game.ship.hull==100 and game.ship.velocity==Vector3.ZERO,"Ground-to-orbit cycle ends with autonomous healthy docking")
		check(game.ship.goods==cargo and game.ship.credits==credits,"Departure and docking do not trade or alter progress rewards automatically")
		check(not game._decode_state(json_copy(game._payload())).is_empty(),"The docked end state retains valid full save semantics")
		check(not game.saving_enabled and game.saves.sequence==generation,"Full automated controller cycle never writes persistent game progress")
	game.queue_free();await process_frame
func run()->void:
	if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires --rebuild-capture");quit(1);return
	model_departures();cancelled_departures();rejected_departures();explicit_takeoff_unchanged();roof_obstruction()
	await controller_cycle()
	print("DEPARTURE CYCLE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
