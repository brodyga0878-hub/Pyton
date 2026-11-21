extends SceneTree

const Fixture = preload("res://tests/flight_fixture.gd")

const Flight := preload("res://scripts/flight_sim.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Expedition := preload("res://scripts/expedition.gd")
const FactionFronts := preload("res://scripts/faction_fronts.gd")
const SessionIO := preload("res://scripts/session_io.gd")
const OrbitRelay := preload("res://main.tscn")

const HOME := Catalog.HOME_SYSTEM
const FRINGE := Catalog.FRINGE_SYSTEM
const HEATHER := Catalog.HEATHER_SYSTEM
const LIMIT := Catalog.LIMIT_SYSTEM
const SPONSOR_PORT := Catalog.FRINGE_ARRIVAL_PORT
const STEP := 1.0 / 30.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_previous_save()
	var commissioned := _test_heather_project()
	if commissioned != null:
		_test_limit_project(commissioned)
		_test_wars(commissioned)
	await _test_board()
	print("Frontier integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_previous_save() -> void:
	# The schema-9 fixture has all seven original markets and twenty deposit slots.
	var legacy := {
		"schema": 9, "system_id": 1, "jump_target": 0, "docked": 10, "landed_site": -1,
		"target": 11, "planned_target": -1, "landing_direction": [0.0, 0.0, 0.0],
		"position": [0.0, 0.0, -152.0], "velocity": [0.0, 0.0, 0.0], "yaw": 0.0, "pitch": 0.0,
		"roll": 0.0, "elapsed": 0.0, "orbit_time": 0.0, "throttle": 0.0,
		"credits": 836, "deliveries": 4, "contract_stage": 1, "contract_origin": 3,
		"contract_destination": 10, "contract_route_id": "outer_relay", "contract_leg": 1,
		"ship": {"fuel": 70.0, "tank_upgraded": true, "eco_upgraded": true, "hull": 82.5, "cargo_upgraded": true},
		"mining": {"site_id": 2, "phase": 0, "phase_seconds": 0.0, "pending_ore": 0,
			"cargo": {"ore": 5, "crystal": 0, "ice": 0, "circuits": 10, "medical": 9},
			"reserves": [0, 0, 113, 0, 96, 180, 156, 132, 216, 0, 0, 0, 192, 144, 0, 240, 0, 0, 180, 0]},
		"market": {
			"0": {"ore": 45, "crystal": 12, "ice": 56, "circuits": 38, "medical": 13},
			"1": {"ore": 31, "crystal": 38, "ice": 9, "circuits": 15, "medical": 38},
			"3": {"ore": 14, "crystal": 8, "ice": 24, "circuits": 11, "medical": 7},
			"10": {"ore": 18, "crystal": 11, "ice": 47, "circuits": 26, "medical": 46},
			"11": {"ore": 8, "crystal": 32, "ice": 7, "circuits": 8, "medical": 9},
			"16": {"ore": 20, "crystal": 12, "ice": 16, "circuits": 14, "medical": 11},
			"17": {"ore": 17, "crystal": 42, "ice": 36, "circuits": 43, "medical": 25},
		},
		"patrol": {"phase": 0, "origin": -1, "enemy_hull": 100.0, "encounter_time": 0.0, "completed": 0},
	}
	var flight := Flight.new()
	if not _expect(flight.restore(_round_trip(legacy)), "A valid pre-expedition flight migrates"):
		return
	var latest := flight.snapshot()
	_expect(flight.credits == 836 and flight.ship.hull == 82.5 and flight.ship.fuel == 70.0
		and flight.ship.jump_fuel == 70.0 and flight.mining.cargo_amount("hydrogen") == 0
		and flight.contract_route_id == "outer_relay" and flight.contract_leg == 1
		and flight.mining.cargo_amount("circuits") == 10 and flight.mining.reserve_at(18) == 180
		and flight.market.stock(16, "ore") == 20, "Migration preserves the courier, purchases, deposits and ship")
	_expect(latest.schema == Flight.SAVE_SCHEMA and latest.market.size() == 11
		and latest.mining.reserves.size() == Catalog.DESTINATION_COUNT
		and flight.mining.reserve_at(Catalog.HEATHER_PLANET) == int(Catalog.site(Catalog.HEATHER_PLANET).reserve),
		"Migration initializes the new markets and deposits")
	_expect(flight.system_known(0) and flight.system_known(1) and flight.system_known(2)
		and not flight.system_known(HEATHER) and not flight.system_known(LIMIT)
		and not flight.station_operational(Catalog.HEATHER_PORT), "Migration retains the known systems and starts new quests locked")
	var invalid := legacy.duplicate(true)
	invalid.jump_target = HEATHER
	_expect(not flight.restore(invalid) and flight.snapshot() == latest,
		"A legacy snapshot cannot supply a jump plan into a new locked system")
	invalid = legacy.duplicate(true)
	invalid.market["20"] = latest.market["20"]
	_expect(not flight.restore(invalid) and flight.snapshot() == latest,
		"A legacy snapshot must contain just the original economies")


func _test_heather_project() -> Flight:
	var flight := _at_port(Flight.new(), SPONSOR_PORT)
	flight.credits = 2000
	var port := Catalog.HEATHER_PORT
	var sites: Array = Catalog.system(HEATHER).survey_sites
	_expect(not flight.plan_jump(HEATHER) and not flight.plan_jump(LIMIT) and not flight.jump_status(HEATHER).ok,
		"Neither undiscovered system can be selected or jumped to")
	if not _expect(flight.project_action() and flight.jump_target == HEATHER and flight.system_known(HEATHER)
		and not flight.system_known(LIMIT) and flight.frontier_status().sponsor_port == SPONSOR_PORT,
		"The faction order opens the first expedition exclusively and records its sponsoring port"):
		return null
	_expect(not flight.station_operational(port) and flight.factions.owner(HEATHER) == -1,
		"The revealed system remains neutral until its station is complete")
	if not _expect(_jump_to(flight, HEATHER) and flight.target == sites[0],
		"A real jump arrives at the first survey gate and debits its fuel fare"):
		return null
	_expect(port not in flight.local_ports() and port not in flight.local_targets()
		and not flight.select_target(port) and flight.traffic_contacts().is_empty(),
		"The construction site has a distinct waypoint with no station targeting, docking or traffic services yet")
	flight.velocity = flight.target_velocity(sites[0]) + Vector3.UP * (Expedition.SERVICE_SPEED + 2.0)
	flight.position = flight.target_gate(sites[0])
	_expect(not flight.frontier_status().can_act and not flight.expedition.act(flight).ok
		and flight.frontier_status().scan_index == 0, "A fast flyby cannot record an observation")
	flight.position += Vector3.BACK * 105.0
	_expect(not flight.frontier_status().can_act and flight.frontier_status().can_follow,
		"An out-of-range scan instead offers to guide the ship")
	if not _expect(_guide_to_project(flight) and flight.project_action() and flight.frontier_status().scan_index == 1,
		"Course assistance brakes into the first scan and the survey advances once (%s)" % flight.status_message):
		return null
	_expect(flight.frontier_status().site == sites[1] and not flight.frontier_status().can_act,
		"The second observation requires following the next survey target")
	if not _expect(_guide_to_project(flight) and flight.project_action()
		and flight.frontier_status().phase == Expedition.REPORT and flight.jump_target == FRINGE,
		"Guidance reaches the second orbit and completing the scan sets a course back to the sponsor (%s)" % flight.status_message):
		return null
	var wrong_port := _at_port(flight, Catalog.FRINGE_SECOND_PORT)
	var report_credits := flight.credits
	_expect(not wrong_port.frontier_status().can_act and wrong_port.project_action()
		and wrong_port.planned_target == SPONSOR_PORT and wrong_port.credits == report_credits
		and wrong_port.frontier_status().phase == Expedition.REPORT,
		"Another station in the same faction can set a course to the sponsor but cannot accept the report")
	_expect(not flight.frontier_status().can_act and flight.project_action() and flight.jump_target == FRINGE
		and flight.credits == report_credits, "The expedition board only plans a return jump while abroad")
	if not _expect(_jump_to(flight, FRINGE) and _dock_at(flight, SPONSOR_PORT),
		"The report can be brought home by jumping and docking (%s)" % flight.status_message):
		return null
	var start := flight.credits
	var report := flight.frontier_status()
	if not _expect(flight.project_action() and flight.frontier_status().phase == Expedition.BUILD
		and flight.credits == start + report.survey_reward and flight.jump_target == HEATHER,
		"Reporting pays the agreed reward and opens construction freight"):
		return null
	flight.project_action()
	_expect(flight.credits == start + report.survey_reward and flight.frontier_status().build_index == 0,
		"The same report does not pay twice")
	if not _expect(_buy(flight, {"ore": 10, "circuits": 2, "crystal": 3}) and _jump_to(flight, HEATHER)
		and _guide_to_project(flight), "Freight bought from the sponsoring dock can reach the construction waypoint (%s)" % flight.status_message):
		return null
	var missing := Flight.new()
	if not _expect(missing.restore(_round_trip(flight.snapshot())) and missing.mining.remove_cargo("circuits", 1),
		"Clone a loaded flight to check an incomplete delivery"):
		return null
	var unchanged := missing.snapshot()
	_expect(missing.frontier_status().ready and missing.frontier_status().missing == {"circuits": 1}
		and not missing.project_action() and missing.snapshot() == unchanged,
		"Missing one required material rejects the whole shipment without consuming cargo")
	if not _expect(flight.project_action() and flight.frontier_status().build_index == 1 and flight.mining.cargo_amount("ore") == 4
		and flight.mining.cargo_amount("circuits") == 0 and flight.mining.cargo_amount("crystal") == 3
		and not flight.station_operational(port) and not flight.system_known(LIMIT),
		"The first shipment removes only the required goods and leaves the station under construction"):
		return null
	var partial := _round_trip(flight.snapshot())
	var reloaded := Flight.new()
	if not _expect(reloaded.restore(partial) and reloaded.frontier_status().build_index == 1
		and reloaded.frontier_status().needs == {"ore": 4, "crystal": 3}
		and reloaded.factions.owner(HEATHER) == -1, "A cold restore resumes the second shipment without advancing ownership"):
		return null
	_check_invalid_dock(reloaded, port)
	start = reloaded.credits
	var build_reward: int = reloaded.frontier_status().build_reward
	if not _expect(reloaded.project_action() and reloaded.station_operational(port) and reloaded.factions.owner(HEATHER) == 0
		and reloaded.credits == start + build_reward and not reloaded.system_known(LIMIT)
		and reloaded.mining.cargo_amount("ore") == 0 and reloaded.mining.cargo_amount("crystal") == 0,
		"The second shipment pays once and transfers the completed station and system to the expedition sponsor"):
		return null
	_expect(port in reloaded.local_ports() and port in reloaded.local_targets() and not reloaded.traffic_contacts().is_empty(),
		"The newly commissioned port enters navigation and generates autonomous traffic")
	if not _expect(_dock_at(reloaded, port) and reloaded.market_trade("ore", "buy", 1)
		and reloaded.service_action("refuel") and reloaded.service_action("jump_refuel"),
		"The finished station can actually dock, sell goods and supply both reserves (%s)" % reloaded.status_message):
		return null
	_expect(reloaded.offer_destination() >= 0 and reloaded.contract_action() and reloaded.jump_target != HEATHER,
		"The completed frontier dock offers outbound freight alongside its market")
	return reloaded


func _check_invalid_dock(flight: Flight, port: int) -> void:
	var partial := flight.snapshot()
	var invalid := partial.duplicate(true)
	invalid.docked = port
	invalid.target = port
	invalid.position = _coordinates(flight.docking_position(port))
	_expect(not flight.restore(invalid) and flight.snapshot() == partial,
		"A save cannot bypass the queue by claiming a berth at an unfinished station")


func _test_limit_project(commissioned: Flight) -> void:
	var flight := _at_port(commissioned, 10)
	var departure := Catalog.VELAR_SYSTEM
	var site: int = Catalog.LIMIT_PORT
	if not _expect(flight.project_action() and flight.system_known(LIMIT) and flight.frontier_status().sponsor == 1
		and flight.frontier_status().sponsor_port == 10 and flight.jump_target == LIMIT,
		"The next region is revealed upon accepting a new expedition with a different sponsor"):
		return
	_expect(flight.factions.owner(LIMIT) == -1 and not flight.station_operational(site),
		"Discovering another system leaves its territory neutral")
	if not _expect(_jump_to(flight, LIMIT) and _guide_to_project(flight) and flight.project_action()
		and _guide_to_project(flight) and flight.project_action() and flight.frontier_status().phase == Expedition.REPORT,
		"The second expedition surveys both sites, including its asteroid (%s)" % flight.status_message):
		return
	if not _expect(_jump_to(flight, departure) and _dock_at(flight, 10) and flight.project_action()
		and _buy(flight, {"ore": 8, "medical": 3, "crystal": 4, "circuits": 3})
		and flight.service_action("refuel") and flight.service_action("jump_refuel"),
		"The Velar sponsor can process the report, sell materials and fuel the second expedition (%s)" % flight.status_message):
		return
	if not _expect(_jump_to(flight, LIMIT) and _guide_to_project(flight) and flight.project_action() and flight.project_action()
		and flight.station_operational(site) and flight.factions.owner(LIMIT) == 1 and flight.frontier_status().series_done,
		"Two deliveries commission the second station for its own faction and finish the expedition chain (%s)" % flight.status_message):
		return
	var state := flight.snapshot()
	_expect(not flight.project_action() and flight.snapshot() == state,
		"Completing the expedition series cannot grant duplicate rewards or reveal another system")


func _test_wars(commissioned: Flight) -> void:
	var remote := _at_port(commissioned, 0)
	var start := remote.factions.system_state(HEATHER)
	var owner: int = start.owner
	if not _expect(start.stage == "peace" and start.next_at > remote.orbit_time and remote.factions.owner(LIMIT) == -1,
		"Recently commissioned stations have a grace period and neutral systems do not go to war"):
		return
	if not _expect(remote.cycle_time_scale() and remote.cycle_time_scale() and remote.time_scale == 16,
		"Time acceleration is available while docked far from the frontier"):
		return
	var safe := (float(start.next_at) - remote.orbit_time - 2.0) / remote.time_scale
	_tick(remote, safe)
	_expect(remote.factions.system_state(HEATHER).stage == "peace" and remote.factions.owner(HEATHER) == owner,
		"The autonomous conflict respects the founding deadline under time acceleration")
	_tick(remote, 0.25)
	var conflict := remote.factions.system_state(HEATHER)
	if not _expect(conflict.stage == "war" and conflict.challenger == 1 - owner and conflict.round == 0
		and remote.factions.owner(HEATHER) == owner,
		"Crossing the founding deadline starts a war without prematurely transferring the sector"):
		return
	var resumed := Flight.new()
	var saved := _round_trip(remote.snapshot())
	if not _expect(resumed.restore(saved) and _round_trip(resumed.factions.snapshot()) == saved.factions,
		"Saving during the fighting preserves its phase, challenger, strength and next phase deadline"):
		return
	_test_convoys(remote, conflict, saved)
	var captured := false
	var repelled := false
	var delivered := false
	var intercepted := false
	for _frame in range(500):
		var previous_owner := remote.factions.owner(HEATHER)
		_tick(remote, 1.0)
		captured = captured or (remote.status_event == "war_captured" and remote.factions.owner(HEATHER) == 1 - previous_owner)
		repelled = repelled or remote.status_event == "war_repulsed"
		delivered = delivered or remote.status_event == "war_convoy_delivered"
		intercepted = intercepted or remote.status_event == "war_convoy_intercepted"
		if captured and repelled and delivered and intercepted:
			break
	_expect(captured and repelled and remote.docked == 0 and remote.system_id == HOME,
		"Autonomous campaigns advance while the player is elsewhere and can end in both conquest and repulse")
	_expect(delivered and intercepted, "Remote simulation produces both deliveries and interceptions")
	_expect(remote.factions.owner(0) == 0 and remote.factions.owner(1) == 1 and remote.factions.owner(2) == 0
		and remote.factions.owner(LIMIT) == -1 and remote.station_operational(Catalog.HEATHER_PORT)
		and remote.factions.news().size() <= FactionFronts.MAX_NEWS,
		"Campaigns keep core and neutral systems intact, leave the station operational and bound war reports")
	var current := remote.snapshot()
	var invalid := current.duplicate(true)
	invalid.factions.frontiers[0].pressure = 101
	_expect(not remote.restore(invalid) and remote.snapshot() == current,
		"Invalid saved war strength cannot partially mutate the active flight")
	saved = _round_trip(current)
	_expect(resumed.restore(saved) and _round_trip(resumed.factions.snapshot()) == saved.factions,
		"Cold restoring after multiple campaigns preserves territory, schedules and war reports")


func _test_convoys(remote: Flight, conflict: Dictionary, saved: Dictionary) -> void:
	var convoys := remote.factions.active_convoys(HEATHER)
	if not _expect(convoys.size() == 2 and convoys[0].faction != convoys[1].faction
		and convoys[0].due_at != convoys[1].due_at and conflict.next_event_at < conflict.next_at
		and remote.factions.active_convoys(HOME).is_empty(),
		"At the opening of a frontier battle, both factions send supplies with separate deadlines"):
		return
	var local := _at_port(remote, Catalog.HEATHER_PORT)
	var sooner: Dictionary = convoys[0] if convoys[0].due_at < convoys[1].due_at else convoys[1]
	var later: Dictionary = convoys[1] if sooner.id == convoys[0].id else convoys[0]
	var visible := _convoy_traffic(local)
	_expect(visible.size() == convoys.size() and visible.has(sooner.id) and visible.has(later.id)
		and visible[sooner.id].position.is_finite() and visible[later.id].velocity.is_finite(),
		"Scheduled reinforcements appear in local flight traffic as physical convoy contacts")
	_tick(remote, (float(sooner.due_at) - remote.orbit_time - 0.5) / remote.time_scale)
	_expect(remote.factions.active_convoys(HEATHER).size() == 2 and remote.factions.owner(HEATHER) == conflict.owner,
		"Both cargo ships stay active until the earlier arrival deadline")
	_tick(remote, 1.0 / remote.time_scale)
	var pending := remote.factions.active_convoys(HEATHER)
	_expect(pending.size() == 1 and pending[0].id == later.id
		and remote.status_event in ["war_convoy_delivered", "war_convoy_intercepted"]
		and remote.factions.system_state(HEATHER).round == conflict.round,
		"At the first arrival deadline only the earlier convoy resolves while the combat round remains in progress")
	local = _at_port(remote, Catalog.HEATHER_PORT)
	var remaining := _convoy_traffic(local)
	_expect(remaining.size() == 1 and remaining.has(later.id) and visible.has(later.id)
		and remaining[later.id].position.distance_to(visible[later.id].position) > 20.0,
		"The remaining convoy travels along its local route while the resolved convoy leaves the contacts")
	var resolved := _round_trip(remote.snapshot())
	var resumed := Flight.new()
	_expect(resumed.restore(resolved) and _round_trip(resumed.factions.snapshot()) == resolved.factions,
		"Saving between two arrivals holds both the completed outcome and the convoy still en route")
	var invalid := resolved.duplicate(true)
	invalid.factions.frontiers[0].convoys[0].due_at = 0
	_expect(not resumed.restore(invalid) and _round_trip(resumed.factions.snapshot()) == resolved.factions,
		"A convoy due before its launch is rejected without discarding the active campaign")
	_tick(remote, (float(later.due_at) - remote.orbit_time + 0.5) / remote.time_scale)
	var aftermath := remote.factions.system_state(HEATHER)
	var logistics := 0
	for convoy: Dictionary in aftermath.convoys:
		if convoy.stage == "delivered":
			logistics += 2 * int(convoy.units) * (1 if convoy.faction == conflict.challenger else -1)
	_expect(remote.factions.active_convoys(HEATHER).is_empty(), "The second convoy resolves at its own later deadline")
	_tick(remote, (float(conflict.next_at) - remote.orbit_time + 0.5) / remote.time_scale)
	_expect(remote.status_event == "war_round" and remote.factions.system_state(HEATHER).round == conflict.round + 1
		and ("%+d п. п." % logistics) in remote.status_message,
		"The combat round incorporates the net supplies that physically arrived")
	var legacy := saved.duplicate(true)
	legacy.schema = 10
	Fixture.remove_ground_ports_from_legacy(legacy)
	legacy.ship.erase("mining_laser")
	legacy.ship.erase("fragment_collector")
	legacy.ship.erase("hydrogen_scoop")
	legacy.ship.erase("fuel_pump")
	legacy.ship.erase("pump_mode")
	legacy.ship.erase("range_drive")
	legacy.ship.erase("drive_kind")
	legacy.ship.erase("autopilot_fitted")
	legacy.ship.erase("hull_id")
	legacy.ship.erase("jump_fuel")
	legacy.mining.cargo.erase("hydrogen")
	legacy.mining.reserves.resize(Catalog.PRE_GAS_DESTINATION_COUNT)
	for stocks: Dictionary in legacy.market.values():
		stocks.erase("hydrogen")
	legacy.ship.erase("heat_shield")
	legacy.erase("star_heat")
	for record: Dictionary in legacy.factions.frontiers:
		record.erase("convoys")
		record.erase("legacy_round")
	if not _expect(resumed.restore(legacy) and resumed.star_heat == 0.0
		and resumed.factions.active_convoys(HEATHER).is_empty() and resumed.factions.owner(HEATHER) == conflict.owner
		and is_equal_approx(resumed.factions.system_state(HEATHER).next_at, conflict.next_at),
		"An older in-progress war migrates without duplicating supplies or moving its round deadline"):
		return
	_tick(resumed, float(conflict.next_at) - resumed.orbit_time + 0.5)
	_expect(resumed.factions.system_state(HEATHER).round == conflict.round + 1
		and resumed.factions.active_convoys(HEATHER).size() == 2,
		"The migrated campaign dispatches supplies automatically when its next round begins")


func _convoy_traffic(flight: Flight) -> Dictionary:
	var contacts := {}
	for contact: Dictionary in flight.traffic_contacts():
		if contact.role == "convoy":
			contacts[contact.id] = contact
	return contacts


func _test_board() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := OrbitRelay.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.flight = Flight.new()
	game._update_display(0.0)
	await process_frame
	_tap(viewport, game._hud._actions["galaxy"], "The galaxy map opens by touching the flight HUD")
	await process_frame
	_expect(game._galaxy.is_open() and not game._galaxy._system_buttons.has(HEATHER)
		and not game._galaxy._system_buttons.has(LIMIT),
		"The map shows no orbit controls for undiscovered systems")
	_tap(viewport, game._galaxy._close_button, "Close the galaxy map")
	await process_frame
	_tap(viewport, game._hud._actions["frontier"], "Open the expansion board through a real touch")
	await process_frame
	if _expect(game._frontier.is_open() and not game._hud._input_enabled,
		"The expansion board is shown and pauses ordinary HUD actions"):
		_tap(viewport, game._frontier._project_button, "Accept a faction expedition by touch")
		await process_frame
		_expect(game.flight.frontier_status().phase == Expedition.SURVEY and game.flight.jump_target == HEATHER
			and game.flight.docked == 0, "Board acceptance plans but does not launch a jump")
		var saved := SessionIO.load_state()
		_expect(saved.get("expedition") == _round_trip(game.flight.snapshot()).expedition,
			"Accepting the expedition through the real UI persists its discovery")
		_tap(viewport, game._frontier._close_button, "Close the expansion board")
		await process_frame
		_tap(viewport, game._hud._actions["galaxy"], "Reopen the updated galaxy map")
		await process_frame
		_expect(game._galaxy._system_buttons.has(HEATHER) and not game._galaxy._system_buttons.has(LIMIT),
			"The map now exposes just the newly revealed frontier")
	viewport.queue_free()
	await process_frame


func _at_port(flight: Flight, port: int) -> Flight:
	var state := flight.snapshot()
	var other := Flight.new()
	other.orbit_time = flight.orbit_time
	var contact := other.docking_position(port)
	var system := Catalog.system_of_site(port)
	state.merge({"system_id": system, "docked": port, "target": port, "landing_direction": [0.0, 0.0, 0.0],
		"landed_site": -1, "jump_target": -1, "planned_target": -1, "position": _coordinates(contact),
		"velocity": [0.0, 0.0, 0.0], "throttle": 0.0}, true)
	state.dock_access = Flight.DockAccess.new().snapshot()
	_expect(other.restore(state), "Prepare a ship docked at port %d with the same progress" % port)
	return other


func _jump_to(flight: Flight, system: int) -> bool:
	if (flight.docked >= 0 and not Fixture.launch(flight)) or not flight.plan_jump(system):
		return false
	var fare := Catalog.jump_cost(flight.system_id, system)
	flight.change_throttle(0.18)
	for _frame in range(roundi(30.0 / STEP)):
		if flight.jump_status(system).ok:
			break
		_tick(flight)
	var before := flight.ship.jump_fuel
	if not flight.start_jump():
		return false
	for _frame in range(roundi(3.0 / STEP)):
		if flight.jump_seconds_left <= 0.0:
			break
		_tick(flight)
	return flight.system_id == system and is_equal_approx(flight.ship.jump_fuel, before - fare)


func _guide_to_project(flight: Flight) -> bool:
	if not flight.frontier_status().ready and not flight.project_action():
		return false
	for _frame in range(roundi(140.0 / STEP)):
		if flight.frontier_status().ready:
			return true
		_tick(flight)
	return false


func _dock_at(flight: Flight, port: int) -> bool:
	if not flight.select_target(port):
		return false
	flight.set_autopilot(true)
	for _frame in range(roundi(120.0 / STEP)):
		if not flight.autopilot:
			break
		_tick(flight)
	return flight.docked == port


func _buy(flight: Flight, cargo: Dictionary) -> bool:
	for good: String in cargo:
		if not flight.market_trade(good, "buy", cargo[good]):
			return false
	return true


func _tick(flight: Flight, delta: float = STEP) -> void:
	flight.update(delta, Vector2.ZERO, 0.0, false, false)


func _tap(viewport: SubViewport, button: Button, label: String) -> void:
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, label):
		return
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 7
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		viewport.push_input(event, true)


func _coordinates(position: Vector3) -> Array:
	return [position.x, position.y, position.z]


func _round_trip(state: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(state))


func _expect(value: bool, description: String) -> bool:
	_checks += 1
	if not value:
		_failures.append(description)
	return value
