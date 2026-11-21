extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Civilian := preload("res://scripts/civilian_traffic.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Frame := preload("res://scripts/flight_frame.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Patrol := preload("res://scripts/patrol_encounter.gd")
const Session := preload("res://scripts/session_io.gd")
const STEP := Fixture.STEP
const ACTIVE_SAVE := "user://ambient-active.json"
const VICTORY_SAVE := "user://ambient-victory.json"

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_deterministic_routes()
	_test_early_relief()
	_test_cockpit_encounter()
	_test_sector_arrivals()
	_test_mission_precedence()
	print("Autonomous traffic integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_deterministic_routes() -> void:
	var flight := Flight.new()
	var traffic := Civilian.new()
	var first := traffic.contacts(flight)
	_expect(first.size() == 2 and _by_role(first, "trader").hull == 100.0 and _by_role(first, "patrol").hull == 100.0
		and _by_role(first, "raider").is_empty() and flight.patrol.phase == Patrol.IDLE
		and not traffic.fire_status(flight).ok, "Ordinary traffic exists without a mission or friendly fire")
	_set_epoch(flight, 27.0)
	var approach := traffic.contacts(flight)
	_expect(_by_role(approach, "trader").phase == "approach" and _by_role(approach, "raider").phase == "approach"
		and _by_role(approach, "patrol").id == _by_role(first, "patrol").id
		and _by_role(approach, "trader").position.distance_to(_by_role(first, "trader").position) > 70.0,
		"The same patrol and transport travel a route while another ship begins an autonomous approach")
	_set_epoch(flight, 42.03)
	var attacked := traffic.contacts(flight)
	var beams := traffic.beams(flight)
	_expect(_by_role(attacked, "trader").phase == "retreat" and _by_role(attacked, "trader").hull == 93.0
		and _by_role(attacked, "raider").phase == "attack" and beams.size() == 1 and beams[0].hostile
		and beams[0].from.is_equal_approx(_by_role(attacked, "raider").position),
		"An autonomous raider physically attacks the transport, which takes damage and retreats")
	_set_epoch(flight, 50.03)
	var intercepted := traffic.contacts(flight)
	var patrol_beams := traffic.beams(flight)
	_expect(_by_role(intercepted, "trader").hull == 86.0 and _by_role(intercepted, "patrol").phase == "intercept"
		and _by_role(intercepted, "raider").hull == 90.0 and patrol_beams.size() == 1 and not patrol_beams[0].hostile,
		"The autonomous escort intercepts the hostile and applies its own beam damage")
	_set_epoch(flight, 61.0)
	var retreating := traffic.contacts(flight)
	_expect(_by_role(retreating, "raider").phase == "retreat" and _by_role(retreating, "raider").hull == 70.0
		and _by_role(retreating, "trader").phase == "relief" and not traffic.status(flight).danger,
		"A damaged raider leaves while the transport resumes its route")
	_set_epoch(flight, 78.0)
	var ended := traffic.contacts(flight)
	_expect(_by_role(ended, "raider").is_empty() and _by_role(ended, "trader").hull == 86.0
		and _by_role(ended, "trader").phase == "transit",
		"After the outbound route, the successful transport keeps its actual damage and hostile leaves")


func _test_early_relief() -> void:
	var flight := Flight.new()
	var traffic := Civilian.new()
	if not _expect(Fixture.depart(flight), "Undock normally before approaching autonomous traffic"):
		return
	_set_epoch(flight, 40.5)
	var enemy := _by_role(traffic.contacts(flight), "raider")
	if not _expect(not enemy.is_empty(), "An ambient hostile is present in its own attack phase"):
		return
	flight.position = enemy.position + Vector3.UP * 105.0
	flight.velocity = Vector3.ZERO
	_aim(flight, enemy.position)
	if not _expect(traffic.status(flight).danger and traffic.step(flight, STEP).event == "ambient_engaged",
		"The nearby raid also reacts to a player outside any contract"):
		return
	var untouched := Civilian.new()
	for elapsed: float in [40.5, 41.1, 41.7, 42.3]:
		_set_epoch(flight, elapsed)
		var hostile := traffic.status(flight)
		_aim(flight, hostile.position)
		if not _expect(traffic.fire(flight).event == "ambient_fire", "A real ray hits the intended ambient hostile"):
			return
	var final_epoch := 42.9
	_set_epoch(flight, final_epoch)
	var last := traffic.status(flight)
	_aim(flight, last.position)
	var before := _by_role(traffic.contacts(flight), "trader")
	if not _expect(traffic.fire(flight).event == "ambient_victory" and not traffic.status(flight).hostile
		and not traffic.fire_status(flight).ok and _by_role(traffic.contacts(flight), "raider").is_empty(),
		"Defeat removes one hostile and cannot target friendly traffic next"):
		return
	var after := _by_role(traffic.contacts(flight), "trader")
	_expect(after.id == before.id and after.position.is_equal_approx(before.position)
		and after.velocity.is_equal_approx(before.velocity) and after.phase == "relief",
		"The surviving transport changes its plan without teleporting or changing identity")
	var encoded := traffic.snapshot()
	var cold := Civilian.new()
	if not _expect(cold.restore(JSON.parse_string(JSON.stringify(encoded)), flight.orbit_time)
		and not cold.status(flight).hostile and cold.contacts(flight) == traffic.contacts(flight),
		"A cold model does not resurrect the defeated ship"):
		return
	_set_epoch(flight, 48.0)
	var freed := _by_role(cold.contacts(flight), "trader")
	var ordinary := _by_role(untouched.contacts(flight), "trader")
	_expect(freed.hull == 93.0 and ordinary.hull == 86.0 and freed.position.distance_to(ordinary.position) > 1.0
		and freed.phase == "relief" and ordinary.phase == "retreat",
		"Early rescue saves the transport from the later shot and changes its subsequent flight path")
	_set_epoch(flight, 172.0)
	var next := cold.status(flight)
	_expect(next.hostile and next.hull == 100.0,
		"The following autonomous event starts a fresh ship cycle instead of reviving an earlier encounter")


func _test_cockpit_encounter() -> void:
	var scout := Flight.new()
	_set_epoch(scout, 44.0)
	var destination: Vector3 = Civilian.new().status(scout).position + Vector3.UP * 100.0
	var pilot := Flight.new()
	if not _expect(Fixture.depart(pilot) and pilot.set_reference_frame(Frame.SYSTEM),
		"An unassigned pilot leaves through the normal home station and uses system-relative manual navigation"):
		return
	_aim(pilot, pilot.position + Vector3.UP)
	pilot.change_throttle(0.23)
	_set_epoch(pilot, pilot.orbit_time + 6.0)
	pilot.change_throttle(0.19)
	for _frame in range(ceili(25.0 / STEP)):
		_aim(pilot, destination)
		if pilot.position.distance_to(destination) < 32.0:
			pilot.change_throttle(-1.0)
			break
		_tick(pilot)
	_set_epoch(pilot, 40.30)
	if not _expect(pilot.patrol.phase == Patrol.IDLE and not pilot.convoy_status().active
		and pilot.ambient_status().danger and pilot.ambient_status().fire_visible and pilot.status_event == "ambient_engaged"
		and not pilot.time_status().allowed, "Fly entirely under manual controls into a local fight without accepting any contract"):
		return
	if not _expect(_until(pilot, func() -> bool: return pilot.ship.hull < 100.0, 4.5)
		and pilot.ship.hull == 94.0 and pilot.status_event == "ambient_enemy_hit"
		and pilot.combat_beams().any(func(beam: Dictionary) -> bool: return beam.hostile and beam.to.distance_to(pilot.position) < 0.02),
		"A real autonomous hostile engages the unassigned player and damages the actual hull"):
		return
	var first := pilot.ambient_status()
	var innocent := _ambient_contact(pilot, "trader")
	_aim(pilot, first.position)
	if not _expect(pilot.fire_status().ok and pilot.fire_action() and pilot.status_event == "ambient_fire"
		and pilot.ambient_status().hull == first.hull - 24.0 and not pilot.fire_action(),
		"The normal player weapon damages only the ambient raider and enforces cooldown"):
		return
	_expect(_ambient_contact(pilot, "trader").hull == innocent.hull,
		"Player intervention never harms the NPC's transport hull")
	if not _expect(pilot.toggle_time_pause() and Session.save_state(pilot.snapshot(), ACTIVE_SAVE) == OK,
		"Save an actual nearby battle after the first player hit"):
		return
	pilot = _load(ACTIVE_SAVE)
	if pilot == null:
		return
	var saved := pilot.snapshot()
	_tick(pilot)
	if not _expect(pilot.snapshot() == saved and pilot.clock_status().paused and pilot.ambient_status().id == first.id
		and pilot.ambient_status().hull == first.hull - 24.0 and pilot.ship.hull == 94.0
		and pilot.toggle_time_pause(), "A cold battle preserves ships, damage, raid identity and timing while paused"):
		return
	var value := pilot.snapshot()
	var foreign := value.duplicate(true)
	foreign.ambient.raider_damage[str(Catalog.SYSTEM_COUNT)] = value.ambient.raider_damage[str(pilot.system_id)].duplicate()
	_expect(not Flight.new().restore(foreign), "Reject combat history that refers to a nonexistent sector")
	for _frame in range(ceili(5.0 / STEP)):
		var target := pilot.ambient_status()
		if not target.hostile:
			break
		_aim(pilot, target.position)
		if pilot.fire_status().ok:
			pilot.fire_action()
		if pilot.ambient_status().hostile:
			_tick(pilot)
	var freed := _ambient_contact(pilot, "trader")
	if not _expect(not pilot.ambient_status().hostile and pilot.status_event == "ambient_victory"
		and pilot.credits == 0 and pilot.patrol.phase == Patrol.IDLE
		and freed.id == innocent.id and freed.phase == "relief" and freed.hull == 93.0,
		"Ordinary player fire can end the attack before the second scheduled hit without paying a mission reward"):
		return
	_aim(pilot, freed.position)
	_expect(not pilot.fire_status().ok and not pilot.fire_action() and _ambient_contact(pilot, "trader").hull == 93.0,
		"A released transport cannot become the next weapon target")
	if not _expect(Session.save_state(pilot.snapshot(), VICTORY_SAVE) == OK, "Save a completed autonomous victory"):
		return
	pilot = _load(VICTORY_SAVE)
	if pilot == null:
		return
	_set_epoch(pilot, 48.0)
	_expect(not pilot.ambient_status().hostile and _ambient_contact(pilot, "trader").phase == "relief"
		and _ambient_contact(pilot, "trader").hull == 93.0 and pilot.credits == 0,
		"Reloading combat victory does not resurrect the hostile or replay the prevented attack")


func _test_sector_arrivals() -> void:
	var traveler := Flight.new()
	var local_trader := _ambient_contact(traveler, "trader")
	_set_epoch(traveler, 18.0)
	if not _expect(not local_trader.is_empty() and Fixture.depart(traveler) and _jump(traveler, Catalog.VELAR_SYSTEM),
		"Make an actual paid jump from Home into a different sector without any encounter assignment"):
		return
	var merchant := _ambient_contact(traveler, "trader")
	var escort := _ambient_contact(traveler, "patrol")
	if not _expect(not merchant.is_empty() and merchant.id != local_trader.id and escort.phase == "intercept"
		and merchant.phase == "retreat" and merchant.hull == 86.0 and traveler.ambient_status().hull <= 90.0,
		"Velar's own underway battle has progressed before the player ever visited"):
		return
	var still_local := traveler.orbit_time
	if not _expect(_jump(traveler, Catalog.HOME_SYSTEM) and traveler.orbit_time > still_local
		and traveler.patrol.phase == Patrol.IDLE, "Travel back to Home through a second normal paid jump"):
		return
	var returned := _ambient_contact(traveler, "trader")
	_expect(returned.id == local_trader.id and returned.phase == "transit" and returned.hull == 86.0
		and returned.position.distance_to(local_trader.position) > 70.0 and not traveler.ambient_status().hostile,
		"The original transport and escort have continued their home flight while both jumps took place")


func _test_mission_precedence() -> void:
	var flight := Flight.new()
	_set_epoch(flight, 24.0)
	if not _expect(flight.patrol_action() and Fixture.depart(flight) and flight.patrol_action()
		and _until(flight, func() -> bool: return flight.patrol.phase == Patrol.ENGAGED, 50.0),
		"Take an ordinary explicit patrol and physically reach its mission raider"):
		return
	var ambient := flight.ambient_status()
	if not _expect(ambient.hostile and ambient.id != _mission_contact(flight).get("id"),
		"The same local sector has two separate hostile contacts, only one from the mission"):
		return
	var mission_hull := flight.patrol.enemy_hull
	var ship_location := flight.position
	var ship_velocity := flight.velocity
	flight.position = ambient.position + Vector3.UP * 105.0
	_aim(flight, ambient.position)
	_expect(flight.ambient.fire_status(flight).ok and not flight.fire_action()
		and flight.ambient_status().hull == ambient.hull and flight.patrol.enemy_hull == mission_hull,
		"An otherwise shootable ambient target cannot steal a shot reserved for an active mission")
	flight.position = ship_location
	flight.velocity = ship_velocity
	var mission := _mission_contact(flight)
	if not _expect(not mission.is_empty(), "The explicit patrol has its own distinct contact identity"):
		return
	_aim(flight, mission.position)
	_expect(flight.fire_action() and flight.patrol.enemy_hull == mission_hull - 24.0
		and flight.ambient_status().hull == ambient.hull,
		"Normal firing hits the explicit encounter while leaving the unrelated nearby raid unchanged")


func _jump(flight: Flight, destination: int) -> bool:
	if not flight.plan_jump(destination):
		return false
	_aim(flight, flight.position + Vector3.BACK)
	flight.change_throttle(0.18)
	if not _until(flight, func() -> bool: return flight.jump_status(destination).ok, 15.0) or not flight.start_jump():
		return false
	return _until(flight, func() -> bool: return flight.system_id == destination, 5.0)


func _load(path: String) -> Flight:
	var flight := Flight.new()
	return flight if _expect(flight.restore(Session.load_state(path)), "Cold load the real checkpoint from %s" % path) else null


func _ambient_contact(flight: Flight, role: String) -> Dictionary:
	for contact: Dictionary in flight.traffic_contacts():
		if contact.get("ambient", false) and contact.role == role:
			return contact
	return {}


func _mission_contact(flight: Flight) -> Dictionary:
	for contact: Dictionary in flight.traffic_contacts():
		if contact.role == "raider" and not contact.get("ambient", false):
			return contact
	return {}


func _until(flight: Flight, reached: Callable, seconds: float) -> bool:
	for _frame in range(ceili(seconds / STEP)):
		if reached.call():
			return true
		_tick(flight)
	return reached.call()


func _tick(flight: Flight) -> void:
	flight.update(STEP, Vector2.ZERO, 0.0, false, false)


func _set_epoch(flight: Flight, epoch: float) -> void:
	flight.update(epoch - flight.orbit_time, Vector2.ZERO, 0.0, false, false)


func _aim(flight: Flight, point: Vector3) -> void:
	var facing := flight.position.direction_to(point)
	flight.yaw = atan2(-facing.x, -facing.z)
	flight.pitch = clampf(asin(facing.y), -Flight.MAX_PITCH, Flight.MAX_PITCH)


func _by_role(contacts: Array[Dictionary], role: String) -> Dictionary:
	for contact: Dictionary in contacts:
		if contact.role == role:
			return contact
	return {}


func _expect(value: bool, description: String) -> bool:
	_checks += 1
	if not value:
		_failures.append("FAIL: " + description)
	return value
