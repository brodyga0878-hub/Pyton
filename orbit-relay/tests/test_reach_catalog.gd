extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Procedural := preload("res://scripts/procedural_systems.gd")
const Orbit := preload("res://scripts/orbit_ephemeris.gd")
const Ground := preload("res://scripts/ground_port.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Dossier := preload("res://scripts/system_dossier.gd")
const Rig := preload("res://scripts/mining_rig.gd")
const Session := preload("res://scripts/session_io.gd")
const Fixture := preload("res://tests/flight_fixture.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_test_relay_geometry()
	_test_dossiers()
	_test_comet_voyage()
	_test_legacy_schema()
	print("Outer reach integration: %d checks, %d failures" % [_checks, _failures])
	quit(int(_failures > 0))


func _test_relay_geometry() -> void:
	var system_count := 0
	var stars := 0
	var moons := 0
	var giants := 0
	var comets := 0
	var epoch := 381.5
	var capacity := Flight.new().ship.jump_capacity()
	for arm in range(Procedural.ARM_ROOTS.size()):
		var predecessor := Catalog.PRE_ATLAS_SYSTEM_COUNT + ((arm + 1) * Procedural.ARM_GROUP_COUNT - 1) * Procedural.ARM_GROUP_SIZE
		for group in range(Procedural.REACH_GROUP_COUNT):
			var relay := Catalog.PRE_REACH_SYSTEM_COUNT + (arm * Procedural.REACH_GROUP_COUNT + group) * Procedural.ARM_GROUP_SIZE
			_expect(relay in Catalog.generated_systems_near(predecessor, Catalog.GENERATED_SCAN_RANGE)
				and Catalog.jump_cost(predecessor, relay) <= capacity, "Relay %d has a discoverable ordinary jump from its predecessor" % relay)
			predecessor = relay
			for index in range(Procedural.ARM_GROUP_SIZE):
				var system := relay + index
				system_count += 1
				_expect(system == relay or (system in Catalog.generated_systems_near(relay, Catalog.GENERATED_SCAN_RANGE)
					and Catalog.jump_cost(relay, system) <= capacity), "System %d is reachable from its relay" % system)
				var suns := Catalog.stars_for(system)
				stars += suns.size()
				if suns.size() == 2:
					var primary: int = suns.front()
					var secondary: int = suns.back()
					var left := Orbit.body_gravity_parameter(primary)
					var right := Orbit.body_gravity_parameter(secondary)
					var first: Vector3 = Orbit.sample(primary, epoch).position
					var second: Vector3 = Orbit.sample(secondary, epoch).position
					var center := (first * left + second * right) / (left + right)
					_expect(center.distance_to(Catalog.system(system).barycenter) < 0.001
						and first.distance_to(Catalog.site(primary).center) > 0.1
						and Orbit.period(primary) == Orbit.period(secondary), "Binary %d actually shares a moving barycentric orbit" % system)
				for body: int in Catalog.targets_for(system):
					var body_type: String = Catalog.site(body).kind
					if body_type == "moon":
						moons += 1
						var parent := Orbit.orbit_parent(body)
						_expect(parent >= 0 and Catalog.system_of_site(parent) == system
							and Catalog.site(parent).kind == "planet" and Orbit.period(body) > 0.0,
							"Lunar target %d moves around its own planet" % body)
					elif body_type == "gas":
						giants += 1
						_expect(body == Catalog.gas_giant_for(system) and not Catalog.is_mine_site(body),
							"Gas giant %d has a genuine scoopable body and no surface landing" % body)
					elif body_type == "comet":
						comets += 1
						var extrema := Orbit.extrema(body)
						_expect(extrema.x > 0.0 and extrema.y > extrema.x * 2.0 and Catalog.is_mine_site(body),
							"Comet %d is a solid target on a strongly elongated orbit" % body)
	_expect(system_count == 512 and stars == 524 and moons == 36 and giants == 16 and comets == 24,
		"The extension has precisely 512 systems, 524 stars, 36 moons, 16 giants and 24 comets")


func _test_dossiers() -> void:
	var flight := Flight.new()
	var home := Dossier.read(flight, Catalog.HOME_SYSTEM)
	var velar := Dossier.read(flight, Catalog.VELAR_SYSTEM)
	var heather := Dossier.read(flight, Catalog.HEATHER_SYSTEM)
	_expect(home.archive.size() == 3 and home.population_range.x > 0 and home.regime != velar.regime
		and not heather.known and not heather.has("archive"), "Named histories and distinct civic structures only show for known systems")
	var ground_body := Ground.body(Catalog.GROUND_PAD)
	_expect(flight.body_dossier(ground_body).data.is_empty(), "Body properties require an observation")
	_expect(flight.cartography.record(ground_body, flight.orbit_time), "Record the atmosphere-bearing ground port host")
	var data: Dictionary = flight.body_dossier(ground_body).data
	_expect(float(data.mass_kg) > 0.0 and float(data.temperature_k) > 0.0
		and data.associated_ports == [Catalog.GROUND_PAD, Catalog.GROUND_HANGAR],
		"Observed system body associates its two operational ground ports and its actual model mass and temperature")
	flight.update(60.0, Vector2.ZERO, 0.0, false, false)
	_expect(flight.body_dossier(ground_body).data.temperature_k == data.temperature_k,
		"Displayed temperature refers to the persisted measurement epoch")


func _test_comet_voyage() -> void:
	var flight := Flight.new()
	var prior_tip := Catalog.PRE_REACH_SYSTEM_COUNT - Procedural.ARM_GROUP_SIZE
	var first_new := Catalog.SYSTEM_COUNT - Procedural.REACH_GROUP_COUNT * Procedural.ARM_GROUP_SIZE
	var comet_system := first_new + Procedural.ARM_GROUP_SIZE + 3
	var comet: int = Catalog.mines_for(comet_system).back()
	if not _expect(Fixture.launch(flight) and flight.cartography.restore({"systems": [{"system": prior_tip, "epoch": 0.0}], "scans": []}, 0.0),
		"Begin in flight at the old atlas tip with the new reach still unknown"):
		return
	flight.jump_target = prior_tip
	flight._finish_jump_arrival(flight.ship.flight_mass(flight.mining.ore_hold), -1)
	_expect(not flight.system_known(first_new) and not flight.plan_jump(first_new) and flight.body_dossier(comet).name.is_empty(),
		"A new relay and remote body are unavailable before discovery")
	if not _expect(_travel(flight, first_new) and _travel(flight, first_new + Procedural.ARM_GROUP_SIZE) and _travel(flight, comet_system),
		"Radio-survey and physically jump three consecutive outer legs from the old atlas into a new comet system: %s" % flight.status_message):
		return
	# Start the local approach co-moving at a safe distance. Landing and extraction use normal controls.
	flight.position = flight.target_position(comet) + Vector3.BACK * (float(Catalog.site(comet).radius) + 95.0)
	flight.velocity = flight.target_velocity(comet)
	var reserve := flight.mining.reserve_at(comet)
	if not _expect(flight.select_target(comet) and flight.survey_action(comet), "Survey the comet on a safe final approach"):
		return
	flight.set_autopilot(true)
	if not _expect(_advance(flight, func() -> bool: return flight.landed_site == comet, 140.0)
		and flight.ship.hull > 99.0 and flight.mine_action(), "Autoland on a moving comet and detach the actual surface rig: %s" % flight.status_message):
		return
	if not _expect(_advance(flight, func() -> bool: return flight.mining.phase == Rig.READY, 30.0) and flight.mine_action()
		and _advance(flight, func() -> bool: return flight.mining.phase == Rig.STOWED, 8.0), "Extract and recover a batch of comet ice"):
		return
	var path := "user://reach-comet-%d.json" % OS.get_process_id()
	var restored := Flight.new()
	_expect(Session.save_state(flight.snapshot(), path) == OK
		and Session.load_valid_state(path, restored.restore) == Session.LoadResult.PRIMARY
		and restored.landed_site == comet and restored.system_known(first_new) and restored.body_dossier(comet).known
		and restored.mining.reserve_at(comet) == reserve - Rig.BATCH and restored.mining.cargo_amount("ice") == Rig.BATCH
		and restored.dock_action() and not restored.landed,
		"Ordinary JSON restart preserves discovery, ice and depleted reserves and allows takeoff")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_legacy_schema() -> void:
	var old := Flight.new().snapshot()
	old.schema = 50
	Fixture.remove_schema_51_from_legacy(old)
	old.patrol.erase("tactics")
	var previous_last := Catalog.PRE_REACH_SYSTEM_COUNT - 1
	old.cartography.systems = [{"system": previous_last, "epoch": 0.0}]
	var new_system := Catalog.PRE_REACH_SYSTEM_COUNT
	var first_planet: int = Catalog.mines_for(new_system)[0]
	var restored := Flight.new()
	_expect(restored.restore(JSON.parse_string(JSON.stringify(old))) and restored.system_known(previous_last)
		and not restored.system_known(new_system) and restored.mining.reserve_at(first_planet) == int(Catalog.site(first_planet).reserve),
		"Schema 50 JSON preserves historic discoveries and initializes undisturbed new resource bodies")
	old.cartography.systems.append({"system": new_system, "epoch": 0.0})
	_expect(not restored.restore(old), "Old-schema JSON cannot invent discoveries beyond its historical boundary")


func _travel(flight: Flight, destination: int) -> bool:
	flight.scan_galaxy()
	if not flight.plan_jump(destination):
		return false
	# The long return route normally uses stellar skimming. Supply fuel to focus these short proof hops on navigation.
	flight.ship.jump_fuel = flight.ship.jump_capacity()
	var star := Catalog.star_for(flight.system_id)
	var outgoing := (flight.position - flight.target_position(star)).normalized()
	flight.yaw = atan2(-outgoing.x, -outgoing.z)
	flight.pitch = asin(outgoing.y)
	flight.change_throttle(0.18)
	return _advance(flight, func() -> bool: return flight.jump_status(destination).ok, 25.0) and flight.start_jump() \
		and _advance(flight, func() -> bool: return flight.system_id == destination, 4.0)


func _advance(flight: Flight, reached: Callable, seconds: float) -> bool:
	for _index in range(ceili(seconds / Fixture.STEP)):
		if reached.call():
			return true
		flight.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
	return reached.call()


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures += 1
		printerr(description)
	return condition
