extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Ground := preload("res://scripts/ground_port.gd")
const Orbit := preload("res://scripts/orbit_ephemeris.gd")
const Session := preload("res://scripts/session_io.gd")
const Terrain := preload("res://scripts/surface_terrain.gd")

const BODY := Catalog.GROUND_BODY
const PAD := Catalog.GROUND_PAD
const HANGAR := Catalog.GROUND_HANGAR
const ORBITAL := 10
const STEP := Fixture.STEP
const DEPARTURE_SAVE := "user://ground-hangar-departure.json"

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog()
	var ship := _reach_velar()
	if ship != null:
		_test_closed_shutter(ship)
		_test_manual_pad(ship)
		_test_round_trip(ship)
	print("Ground port integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_catalog() -> void:
	_expect(Catalog.PRE_GROUND_DESTINATION_COUNT == 87 and PAD == 87 and HANGAR == 88
		and Catalog.PRE_EXPANDED_DESTINATION_COUNT == 89 and Catalog.system(Catalog.VELAR_SYSTEM).arrival_port == ORBITAL
		and Catalog.ports_for(Catalog.VELAR_SYSTEM) == [10, 11, PAD, HANGAR],
		"New surface destinations append to the catalog without redirecting the existing orbital arrival")
	_expect(Catalog.site(PAD).name == "Откос" and Catalog.site(HANGAR).name == "Шлюз Лазури"
		and Catalog.is_port(PAD) and Catalog.is_port(HANGAR) and Catalog.is_mine_site(BODY)
		and Ground.body(PAD) == BODY and Ground.body(HANGAR) == BODY
		and not Ground.is_hangar(PAD) and Ground.is_hangar(HANGAR),
		"The two serviced ground ports differ from the retained free-landing moon")
	for port: int in [PAD, HANGAR]:
		var first := Orbit.sample(port, 0.0)
		var after := Orbit.sample(port, 14.0)
		var body := Orbit.sample(BODY, 14.0)
		var local: Vector3 = after.position - body.position
		var normal := Ground.basis(port, 14.0).z
		var velocity: Vector3 = body.velocity + Terrain.spin_velocity(BODY, local)
		_expect(Orbit.orbit_parent(port) == BODY and first.position.distance_to(Catalog.site(port).center) < 0.001
			and after.position.distance_to(first.position) > 0.05 and local.is_equal_approx(Ground.anchor_offset(port, 14.0))
			and normal.dot(local.normalized()) > 0.90 and after.velocity.is_equal_approx(velocity),
			"Surface port %d follows its host moon's moving position and terrain normal" % port)
	_expect(not Ground.local_hull(PAD, Vector3(6.0, 0.0, 2.0))
		and Ground.local_hull(HANGAR, Vector3(6.0, 0.0, 2.0))
		and not Ground.local_hull(HANGAR, Vector3(2.0, 0.0, 2.0)),
		"The open deck leaves the sky open while the enclosed berth has a narrow central aperture")
	_expect(Ground.hull_entry(PAD, Vector3(6.0, 0.0, 9.0), Vector3(6.0, 0.0, 2.0)) < 0.0
		and is_equal_approx(Ground.hull_entry(HANGAR, Vector3(6.0, 0.0, 9.0), Vector3(6.0, 0.0, 2.0)), 3.0 / 7.0)
		and is_equal_approx(Ground.hull_entry(HANGAR, Vector3(0.0, 0.0, 10.0), Vector3(0.0, 0.0, -3.0)), 11.6 / 13.0),
		"Ballistic prediction distinguishes the sky, the roof and the floor beyond the open corridor")
	var ship := Flight.new()
	var saved := ship.snapshot()
	_expect(saved.market.size() == 11 and saved.mining.reserves.size() == Catalog.DESTINATION_COUNT
		and ship.mining.reserve_at(BODY) == 192 and ship.mining.reserve_at(PAD) == 0 and ship.mining.reserve_at(HANGAR) == 0,
		"Ground markets get their own stocks while the existing moon remains the mining deposit")


func _reach_velar() -> Flight:
	var ship := Flight.new()
	if not _expect(ship.contract_action() and _autopilot_from_stop(ship, 1)
		and _until(ship, func() -> bool: return ship.docked == 1, 100.0)
		and ship.contract_action() and ship.deliveries == 1 and ship.credits == 240,
		"A real home courier flight earns market funds"):
		return null
	if not _expect(Fixture.depart(ship) and ship.plan_jump(Catalog.VELAR_SYSTEM),
		"Physically depart the home station and plan the old system"):
		return null
	ship.change_throttle(0.18)
	if not _expect(_until(ship, func() -> bool: return ship.jump_status(Catalog.VELAR_SYSTEM).ok, 14.0)
		and ship.start_jump() and _until(ship, func() -> bool: return ship.system_id == Catalog.VELAR_SYSTEM, 4.0)
		and ship.select_target(ORBITAL), "Fly a real paid jump into Velar with the orbital port still selected"):
		return null
	ship.set_autopilot(true)
	if not _expect(_until(ship, func() -> bool: return ship.docked == ORBITAL, 125.0),
		"Reach the original orbital berth using regular traffic clearance"):
		return null
	return ship


func _test_closed_shutter(docked: Flight) -> void:
	var ship := _copy(docked)
	if ship == null or not _expect(Fixture.depart(ship) and ship.select_target(HANGAR),
		"Enter normal airborne navigation to the destination hangar"):
		return
	var approach := _place_on_axis(ship, HANGAR, Ground.HANGAR_TOP + 0.04)
	ship.velocity -= approach * 12.0
	var hull := ship.ship.hull
	_tick(ship)
	var altitude := (ship.position - ship.docking_position(HANGAR)).dot(ship.station_axis(HANGAR))
	_expect(ship.docked < 0 and altitude >= Ground.HANGAR_TOP - 0.04 and ship.ship.hull == hull
		and not ship.dock_access_status(HANGAR).ready,
		"A physical inward sweep cannot pass a shut hatch")
	_place_on_axis(ship, HANGAR, 12.0)
	if not _expect(ship.dock_clearance_action() and ship.dock_access_status(HANGAR).phase == "queued",
		"The hangar takes a real traffic request and queues before moving its door"):
		return
	var opening_seen := false
	for _frame in range(ceili(13.0 / STEP)):
		var permit := ship.dock_access_status(HANGAR)
		if permit.ready:
			break
		opening_seen = opening_seen or (permit.phase == "opening" and permit.open_fraction > 0.0 and permit.open_fraction < 1.0)
		_tick(ship)
	if not _expect(opening_seen and ship.dock_access_status(HANGAR).ready,
		"Only a fully opened hangar becomes traversable"):
		return
	approach = _place_on_axis(ship, HANGAR, Ground.HANGAR_TOP + 0.04)
	ship.velocity -= approach * 12.0
	_tick(ship)
	altitude = (ship.position - ship.docking_position(HANGAR)).dot(ship.station_axis(HANGAR))
	_expect(altitude < Ground.HANGAR_TOP - 0.06 and ship.docked < 0
		and ship.ship.hull == hull, "The exact physical sweep crosses a fully authorized shutter without damage")
	_place_on_axis(ship, HANGAR, 2.5)
	ship.gear_deployed = true
	ship.gear_extension = 1.0
	_expect(ship.docking_guidance().ok and ship.dock_action() and ship.docked == HANGAR,
		"An aligned, authorized slow manual approach can capture the enclosed berth")


func _test_manual_pad(docked: Flight) -> void:
	var ship := _copy(docked)
	if ship == null or not _expect(Fixture.depart(ship) and ship.select_target(PAD),
		"Prepare a manual approach to the open terrace"):
		return
	_place_on_axis(ship, PAD, 2.5)
	var status := ship.docking_guidance()
	_expect(status.ground and not status.ground_hangar and not status.sync_available
		and not status.ok and status.awaiting_gear and not ship.gear_deployed
		and not ship.dock_action() and ship.gear_deployed and ship.docked < 0,
		"The normal manual docking action requests gear without teleporting onto the pad")
	if not _expect(_until(ship, func() -> bool: return ship.gear_extension >= 1.0, 4.0), "The actual gear animation reaches locked"):
		return
	_place_on_axis(ship, PAD, 2.5)
	_expect(ship.docking_guidance().ok and not ship.dock_clearance_action() and ship.dock_action()
		and ship.docked == PAD and ship.gear_extension == 1.0 and not ship.landed,
		"Manual open-pad capture requires landing gear and uses the serviced dock with no wait")
	_expect(not ship.gear_action() and ship.station_services_available(), "A surface-docked ship keeps its gear locked and opens services")


func _test_round_trip(ship: Flight) -> void:
	if not _expect(_autopilot_from_stop(ship, PAD), "Plan a route from orbital dock to the open terrace"):
		return
	if not _expect(_land_under_autopilot(ship, PAD, false), "Autopilot reaches the open site with gear and no shutter request"):
		return
	_expect(ship.docked == PAD and ship.landed_site == -1 and ship.gear_deployed and ship.gear_extension == 1.0
		and ship.station_services_available() and not ship.mine_action(), "Serviced open pad stays distinct from an off-port mining landing")
	var stock := ship.market.stock(PAD, "ice")
	var balance := ship.credits
	var quote := ship.market_quote("ice", "buy", 2)
	_expect(quote.ok and quote.cost > 0 and ship.market_trade("ice", "buy", 2)
		and ship.market.stock(PAD, "ice") == stock - 2 and ship.mining.cargo_amount("ice") == 2
		and ship.credits == balance - quote.cost, "Physical open-pad docking enables local stock trades and charges the exact quote")
	var fuel := ship.ship.fuel
	var fare := ship.service_offer("refuel")
	_expect(fuel < ship.ship.capacity() and fare.allowed and ship.service_action("refuel")
		and ship.ship.fuel > fuel, "The open surface port offers working fuel service")
	if not _expect(ship.select_target(HANGAR) and ship.dock_action() and ship.docked < 0 and ship.target == HANGAR,
		"Open-pad takeoff immediately releases the ship along its armed route"):
		return
	var outward := ship.station_axis(PAD)
	var relative := ship.velocity - ship.surface_velocity(PAD, ship.position)
	_expect(relative.dot(outward) > 5.0 and relative.slide(outward).length() < 0.08
		and not ship.station_services_available() and not ship.market_trade("ice", "buy", 1),
		"Takeoff follows the terrain normal with moving surface drift and disables station services")
	ship.set_autopilot(true)
	if not _expect(_land_under_autopilot(ship, HANGAR, true), "Fly between surface ports by the real gear, request, moving aperture and capture path"):
		return
	_expect(ship.docked == HANGAR and ship.gear_extension == 1.0 and ship.station_services_available()
		and ship.mining.cargo_amount("ice") == 2 and ship.market_quote("ice", "sell", 1).ok,
		"The enclosed ground berth recognizes the intact cargo and enables its independent services")
	_test_hangar_departure(ship)


func _test_hangar_departure(ship: Flight) -> void:
	if not _expect(ship.select_target(ORBITAL) and ship.dock_action() and ship.docked == HANGAR
		and ship.departure_status().active and not ship.station_services_available(),
		"A hangar requires a departure booking and closes station services immediately"):
		return
	_expect(not ship.service_action("refuel") and not ship.market_trade("ice", "sell", 1),
		"Outbound clearance cannot consume funds or cargo after the roster is locked")
	if not _expect(_until(ship, func() -> bool:
		return ship.departure_status().phase == "transit" and ship.departure_status().progress >= 0.45, 15.0),
		"Pass halfway through the actual active hangar departure"):
		return
	var snapshot := ship.snapshot()
	var departure := ship.departure_status()
	var position := ship.position
	var velocity := ship.velocity
	if not _expect(ship.dock_access_status(HANGAR).ready and ship.docked == HANGAR
		and snapshot.planned_target == ORBITAL and Session.save_state(snapshot, DEPARTURE_SAVE) == OK,
		"Save the live flight before it passes completely out of the shutter"):
		return
	var restored := Flight.new()
	if not _expect(restored.restore(Session.load_state(DEPARTURE_SAVE)) and restored.docked == HANGAR
		and restored.planned_target == ORBITAL and restored.departure_status().phase == "transit"
		and is_equal_approx(restored.departure_status().progress, departure.progress)
		and restored.position.is_equal_approx(position) and restored.velocity.is_equal_approx(velocity)
		and restored.gear_extension == ship.gear_extension and not restored.dock_action(),
		"Cold restore retains exact mid-exit trajectory, gear state, booked door and noncancellable crossing"):
		return
	var malformed := snapshot.duplicate(true)
	malformed.dock_access.port = PAD
	_expect(not Flight.new().restore(malformed), "Crossing a hangar cannot be restored with a permit for the open pad")
	if not _expect(Fixture.await_departure(restored) and restored.docked < 0 and restored.target == ORBITAL
		and restored.velocity.is_equal_approx(restored.surface_velocity(HANGAR, restored.position) + restored.station_axis(HANGAR) * 6.0)
		and restored.ship.hull == ship.ship.hull,
		"Continue the exact cold departure through the open hangar with no hull damage"):
		return
	restored.set_autopilot(true)
	_expect(_until(restored, func() -> bool: return restored.docked == ORBITAL, 120.0)
		and restored.gear_extension == 0.0 and restored.mining.cargo_amount("ice") == 2,
		"The released ship physically returns to the rotating orbital port and stows its landing gear")


func _land_under_autopilot(ship: Flight, port: int, hangar: bool) -> bool:
	var deploying := false
	var queued := false
	var opening := false
	var open := false
	for _frame in range(ceili(140.0 / STEP)):
		if ship.docked >= 0:
			break
		deploying = deploying or (ship.gear_deployed and ship.gear_extension < 1.0)
		var permit := ship.dock_access_status(port)
		queued = queued or permit.phase == "queued"
		opening = opening or permit.phase == "opening"
		open = open or permit.phase == "open"
		_tick(ship)
	return ship.docked == port and deploying and (queued and opening and open if hangar else not queued and not opening)


func _autopilot_from_stop(ship: Flight, port: int) -> bool:
	if not ship.select_target(port) or not Fixture.depart(ship):
		return false
	ship.set_autopilot(true)
	return ship.target == port and ship.autopilot


func _place_on_axis(ship: Flight, port: int, altitude: float) -> Vector3:
	var axis := ship.station_axis(port)
	ship.position = ship.docking_position(port) + axis * altitude
	ship.velocity = ship.surface_velocity(port, ship.position)
	ship.yaw = atan2(axis.x, axis.z)
	ship.pitch = clampf(asin(-axis.y), -Flight.MAX_PITCH, Flight.MAX_PITCH)
	ship.roll = ship.station_angle(port)
	return axis


func _copy(source: Flight) -> Flight:
	var ship := Flight.new()
	return ship if _expect(ship.restore(source.snapshot()), "Load an independent copy of the known good orbital berth") else null


func _until(ship: Flight, reached: Callable, timeout_seconds: float) -> bool:
	for _frame in range(ceili(timeout_seconds / STEP)):
		if reached.call():
			return true
		_tick(ship)
	return reached.call()


func _tick(ship: Flight) -> void:
	ship.update(STEP, Vector2.ZERO, 0.0, false, false)


func _expect(value: bool, description: String) -> bool:
	_checks += 1
	if not value:
		_failures.append("FAIL: " + description)
	return value
