extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Orbit := preload("res://scripts/orbit_ephemeris.gd")
const Atmosphere := preload("res://scripts/atmosphere.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Session := preload("res://scripts/session_io.gd")
const Startup := preload("res://voyage_start.tscn")
const Fixture := preload("res://tests/flight_fixture.gd")
const SOL := Catalog.SOLAR_SYSTEM

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog()
	await _test_solar_entry()
	_test_land_and_lift()
	_test_real_jump()
	print("Solar voyage: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(int(not _failures.is_empty()))


func _test_catalog() -> void:
	var targets := Catalog.targets_for(SOL)
	var names := targets.map(func(id: int) -> String: return Catalog.site(id).name)
	_expect(SOL == 513933476 and Catalog.STREAMED_SITE_LIMIT == 1541800553
		and Catalog.is_extended_system(SOL - 1) and not Catalog.is_extended_system(SOL)
		and Catalog.system_of_site(Catalog.STREAMED_SITE_LIMIT - 1) == SOL - 1,
		"Solar addresses start immediately after the published procedural galaxy")
	var required := [
		"Солнце", "Меркурий", "Венера", "Земля", "Луна", "Марс", "Юпитер", "Сатурн", "Уран", "Нептун",
		"Церера", "Плутон", "Хаумеа", "Макемаке", "Эрида"]
	if not _expect(Catalog.ports_for(SOL).is_empty() and targets.size() >= 40
		and required.all(func(body: String) -> bool: return body in names),
		"The real Solar system exposes the Sun, all planets and the recognized dwarf planets"):
		return
	_expect(targets.all(func(id: int) -> bool: return Catalog.system_of_site(id) == SOL)
		and Catalog.gas_giants_for(SOL).size() == 4 and Catalog.site(Catalog.SOLAR_EARTH).name == "Земля",
		"Solar body IDs resolve locally, with four distinct giants")
	var moon := int(targets[names.find("Луна")])
	_expect(Orbit.orbit_parent(moon) == Catalog.SOLAR_EARTH
		and absf(Orbit.period(moon) / 86400.0 - 27.322) < 0.02
		and absf(Orbit.period(Catalog.SOLAR_EARTH) / 86400.0 - 365.256) < 0.02,
		"The Moon orbits Earth and the two periods match the astronomical data")
	_expect(Catalog.astronomical_system_ids().size() == 4381
		and SOL in Catalog.astronomical_sector_system_ids(Catalog.sector_coordinates(SOL))
		and Catalog.system_position3(SOL).distance_to(Catalog.GALACTIC_CENTER_LY) == 26700.0,
		"The measured catalogue and physical Galactic centre share the Sol reference frame")


func _test_solar_entry() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1544, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := Startup.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	var button: Button = game._voyages._actions["new_solar"]
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 3
		touch.position = button.get_global_rect().get_center()
		touch.pressed = pressed
		viewport.push_input(touch, true)
	await process_frame
	var pilot: Flight = game.flight
	var earth := Catalog.SOLAR_EARTH
	var separation := pilot.position.distance_to(pilot.target_position(earth))
	_expect(game._flight_active and not game._voyages.is_open() and pilot.system_id == SOL
		and pilot.target == earth and pilot.docked < 0 and pilot.system_known(SOL)
		and is_equal_approx(separation, float(Catalog.site(earth).radius) + 290.0),
		"The real start button creates a playable voyage above Earth")
	var cold := Flight.new()
	_expect(cold.restore(Session.load_single_state(Session.SAVE_PATH)) and cold.system_id == SOL
		and cold.target == earth and cold.system_known(SOL), "The normal save retains astronomy system and target IDs")
	var venus := int(Catalog.targets_for(SOL)[2])
	var sample := Orbit.sample(venus, pilot.orbit_time)
	var edge: Vector3 = sample.position + Vector3.UP * (float(Catalog.site(venus).radius) + 1.0)
	var air := Atmosphere.sample(pilot, edge, Vector3.ZERO)
	_expect(air.site == venus and air.inside and air.density > 0.0,
		"The atmosphere model follows another planet rather than staying on the Earth or Jupiter")
	viewport.queue_free()
	await process_frame


func _test_land_and_lift() -> void:
	var pilot := Flight.new()
	pilot.start_solar_voyage()
	for site: int in [Catalog.SOLAR_EARTH, Catalog.STREAMED_SITE_LIMIT + 1]:
		if not _expect(pilot.select_target(site), "Select %s for an ordinary approach" % Catalog.site(site).name):
			return
		pilot.set_autopilot(true)
		if not _expect(_advance(pilot, func() -> bool: return not pilot.autopilot, 170.0)
			and pilot.landed_site == site and pilot.dock_action() and not pilot.landed and pilot.ship.hull == 100.0,
			"Land and lift off %s without hull damage" % Catalog.site(site).name):
			return


func _test_real_jump() -> void:
	var pilot := Flight.new()
	pilot.start_solar_voyage()
	var proxima := -1
	for candidate: int in Catalog.generated_systems_near(SOL, Catalog.GENERATED_SCAN_RANGE, true):
		if Catalog.is_astronomical_system(candidate) and "Проксима" in str(Catalog.system(candidate).name):
			proxima = candidate
			break
	if not _expect(proxima >= 0 and absf(Catalog.jump_distance(SOL, proxima) - 4.22666) < 0.01
		and not pilot.system_known(proxima), "Proxima Centauri has its observed distance in the normal jump catalogue"):
		return
	if not _expect(pilot.scan_galaxy() and pilot.system_known(proxima) and pilot.route_preview(proxima).available
		and pilot.route_preview(proxima).path.all(Catalog.is_astronomical_system)
		and pilot.plan_jump(proxima), "Radio discovery can be plotted to a measured nearby star"):
		return
	var outward := (pilot.position - pilot.target_position(Catalog.SOLAR_EARTH)).normalized()
	pilot.yaw = atan2(-outward.x, -outward.z)
	pilot.change_throttle(0.18)
	if not _expect(_advance(pilot, func() -> bool: return pilot.jump_status(proxima).ok, 35.0)
		and pilot.start_jump() and _advance(pilot, func() -> bool: return pilot.system_id == proxima, 6.0),
		"A normal jump enters the real star site"):
		return
	var cold := Flight.new()
	_expect(pilot.local_targets() == [Catalog.star_for(proxima)] and cold.restore(pilot.snapshot())
		and cold.system_id == proxima and cold.route_preview(SOL).available,
		"The measured star needs no invented local objects and permits a return route to Sol")


func _advance(pilot: Flight, reached: Callable, seconds: float) -> bool:
	for _frame in range(ceili(seconds / Fixture.STEP)):
		if reached.call():
			return true
		pilot.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
	return reached.call()


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
