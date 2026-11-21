extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Patrol := preload("res://scripts/patrol_encounter.gd")
const Pulse := preload("res://scripts/combat_pulse.gd")
const Escape := preload("res://scripts/escape_pod.gd")
const Session := preload("res://scripts/session_io.gd")
const OPEN_SPACE := Vector3(2400, 8100, 8000)

var _checks := 0
var _failures: Array[String] = []


class SurvivalGame extends "res://scripts/main.gd":
	func _save(_keep_backup: bool = false) -> void:
		pass


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_energy_pulse()
	_test_escape_rescue()
	_test_rescue_without_local_port()
	await _test_cockpit_emergency_controls()
	for failure: String in _failures:
		printerr(failure)
	print("Energy pulse and escape recovery: %d checks, %d failures" % [_checks, _failures.size()])
	quit(int(not _failures.is_empty()))


func _test_energy_pulse() -> void:
	var flight := Flight.new()
	flight.credits = 500
	_expect(flight.service_action("combat_energy_pulse") and flight.credits == 500 - Pulse.COST
		and not flight.service_action("combat_energy_pulse") and not flight.launch_energy_pulse(),
		"A real port sells one charge and the docked pilot cannot activate it")
	if not _expect(flight.patrol_action() and Fixture.depart(flight) and flight.patrol_action()
		and _until(flight, func() -> bool: return flight.patrol.phase == Patrol.ENGAGED, 50.0),
		"Approach a real current hostile through its existing patrol mission"):
		return
	var hostile := flight.patrol.contacts(flight)[0]
	flight.position = hostile.position + Vector3.BACK * (Pulse.RADIUS + 12.0)
	_expect(not flight.launch_energy_pulse() and flight.energy_pulse_status().count == 1,
		"An out-of-range target or neutral craft cannot consume the stored pulse")
	flight.position = hostile.position + Vector3.BACK * 90.0
	var origin := flight.position
	var neutral := _neutral_hulls(flight)
	var hull := flight.patrol.enemy_hull
	_expect(flight.combat_lock_id().is_empty() and flight.energy_pulse_status().ready,
		"Area activation needs a nearby hostile, without needing a laser or missile lock")
	if not _expect(flight.launch_energy_pulse() and flight.status_event == "combat_energy_pulse"
		and flight.patrol.enemy_hull == hull - Pulse.DAMAGE and _neutral_hulls(flight) == neutral,
		"The pulse damages the real raider but does not hit friendly contacts"):
		return
	_expect(not flight.launch_energy_pulse() and flight.energy_pulse_status().count == 0
		and flight.energy_pulse_status().active and flight.energy_pulse_status().position == origin,
		"The same one-use cell cannot be debited or fired a second time")
	var cold := _cold_load(flight)
	if _expect(cold != null and cold.energy_pulse_status().active and cold.energy_pulse_status().count == 0
		and cold.patrol.enemy_hull == hull - Pulse.DAMAGE, "Cold reload preserves the visual pulse and does not repeat the hit"):
		var malformed := cold.snapshot()
		malformed.combat.energy_pulse.count = 1
		_expect(not cold.restore(malformed), "A wave cannot be persisted beside a magically replenished charge")
		_expect(_until(cold, func() -> bool: return not cold.energy_pulse_status().active, 1.0)
			and cold.patrol.enemy_hull == hull - Pulse.DAMAGE, "The visual pulse expires without applying more damage")


func _test_escape_rescue() -> void:
	var flight := Flight.new()
	flight.credits = 900
	_expect(flight.market_trade("ore", "buy", 2) and flight.service_action("combat_ecm") and flight.contract_action(),
		"The destroyed ship had real purchased gear, cargo and a running contract")
	Fixture.launch(flight)
	flight.position = OPEN_SPACE
	flight.velocity = Vector3.ZERO
	flight.ship.hull = 12.0
	var ship := flight.ship
	var source := flight.position + Vector3(0.0, 0.0, 130.0)
	flight.combat.incoming_shot(source, flight.position, flight.system_id, flight.orbit_time)
	if not _expect(flight.combat.incoming_shot(source, flight.position, flight.system_id, flight.orbit_time)
		and _until(flight, func() -> bool: return flight.escape_status().active, 6.0), "Actual lethal missile impact creates the separate pod"):
		return
	var escape := flight.escape_status()
	_expect(flight.ship == ship and flight.ship.hull == 0.0 and flight.status_event == "ship_destroyed"
		and escape.wreck_visible and Vector3(escape.wreck_position).distance_to(flight.position) >= 15.0
		and flight.mining.ore_hold == 0 and flight.contract_stage == 0,
		"The old ship is truly ruined, the pod starts away from the wreck, and cargo and freight contract are lost")
	_expect(not flight.plan_jump(Catalog.VELAR_SYSTEM) and not flight.launch_energy_pulse() and not flight.eject_escape_pod()
		and not flight.station_services_available(), "A pod cannot act as an intact airframe or eject again")
	var cold := _cold_load(flight)
	if not _expect(cold != null and cold.ship.hull == 0.0 and cold.escape_status().can_signal
		and cold.escape_status().wreck_position == escape.wreck_position, "A real JSON cold load returns to the waiting capsule"):
		return
	var snapshot := cold.snapshot()
	var no_capsule := snapshot.duplicate(true)
	no_capsule.escape.clear()
	_expect(not cold.restore(no_capsule) and cold.snapshot() == snapshot, "Reject a zero-hull ordinary flight atomically")
	var holding := cold.position
	cold.update(0.5, Vector2.ONE, 1.0, true, true, Vector3.ONE)
	_expect(holding.distance_to(cold.position) > 0.0 and cold.throttle == 0.0 and cold.escape_status().can_signal,
		"The capsule drifts separately without accepting old ship steering or boost")
	_expect(cold.request_rescue() and cold.escape_status().waiting and cold.escape_status().remaining == Escape.PICKUP_DELAY
		and not cold.request_rescue(), "One distress call starts a finite rescue pickup")
	var destination: int = cold.escape_status().destination
	var balance := cold.credits
	if not _expect(cold.toggle_time_pause(), "The waiting capsule can pause"):
		return
	var waiting := _cold_load(cold)
	if not _expect(waiting != null and waiting.escape_status().waiting and waiting.time_paused,
		"Cold reload preserves the pending rescue and pause"):
		return
	waiting.update(Escape.PICKUP_DELAY * 2.0, Vector2.ZERO, 0.0, false, false)
	_expect(waiting.escape_status().remaining == Escape.PICKUP_DELAY and waiting.credits == balance,
		"Paused waiting does not advance the rescue clock or charge twice")
	waiting.toggle_time_pause()
	_expect(_until(waiting, func() -> bool: return not waiting.escape_status().active, Escape.PICKUP_DELAY + Fixture.STEP)
		and waiting.status_event == "rescue_complete" and waiting.docked == destination
		and waiting.ship.hull == waiting.ship.MAX_HULL and not waiting.combat.ecm_fitted
		and waiting.credits <= balance - Escape.RESCUE_FEE and waiting.mining.ore_hold == 0,
		"The tug docks a replacement ship, charges once, and does not restore lost cargo or modules")
	var returned := _cold_load(waiting)
	_expect(returned != null and not returned.escape_status().active and returned.docked == destination
		and returned.credits == waiting.credits, "Recovery can be saved as an ordinary docked flight")


func _test_rescue_without_local_port() -> void:
	var flight := Flight.new()
	Fixture.launch(flight)
	var remote := Catalog.SYSTEM_COUNT - 1
	var chart := flight.cartography.snapshot()
	chart.systems = [{"system": remote, "epoch": 0.0}]
	if not _expect(flight.cartography.restore(chart, 0.0), "Prepare a remote charted system with no local berth"):
		return
	flight.system_id = remote
	flight.target = Catalog.star_for(remote)
	flight.position = OPEN_SPACE
	flight.ship.hull = Escape.EJECT_HULL_LIMIT
	_expect(flight.eject_escape_pod() and flight.request_rescue() and flight.escape_status().destination == 0,
		"A manually abandoned critical ship in an uninhabited system can request the home rescue tug")
	_expect(_until(flight, func() -> bool: return not flight.escape_status().active, Escape.PICKUP_DELAY + Fixture.STEP)
		and flight.system_id == Catalog.HOME_SYSTEM and flight.docked == 0 and flight.credits == 0,
		"Remote recovery works without taking the player's credit balance below zero")


func _test_cockpit_emergency_controls() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := SurvivalGame.new()
	game.show_voyage_menu_on_launch = true
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game._flight_active = true
	game._voyages.close()
	game._hud.set_input_enabled(true)
	var flight := game.flight
	flight.credits = 1200
	if _expect(flight.service_action("combat_energy_pulse") and flight.service_action("combat_launcher")
		and flight.service_action("combat_missile_dart") and flight.service_action("combat_decoy")
		and flight.patrol_action() and Fixture.depart(flight) and flight.patrol_action()
		and _until(flight, func() -> bool: return flight.patrol.phase == Patrol.ENGAGED, 50.0),
		"Prepare every fitted ordnance control in a live cockpit"):
		flight.position = flight.patrol.contacts(flight)[0].position + Vector3.BACK * 90.0
		game._update_display(0.0)
		await process_frame
		var pulse: Button = game._hud._actions["energy_pulse"]
		_expect(pulse.is_visible_in_tree() and not pulse.disabled
			and viewport.get_visible_rect().encloses(pulse.get_global_rect()),
			"The fitted pulse touch target stays accessible with the rack and decoys shown")
		_tap_control(viewport, pulse)
		_expect(flight.energy_pulse_status().active and game._view._pulse_wave.is_visible_in_tree()
			and game._view._pulse_wave.position.is_equal_approx(flight.energy_pulse_status().position),
			"A live cockpit touch launches the visible wave at its simulation position")
		flight.ship.hull = Escape.EJECT_HULL_LIMIT
		game._update_display(0.0)
		await process_frame
		_tap_control(viewport, game._hud._actions["rescue_eject"])
		var status := flight.escape_status()
		_expect(status.active and game._view._escape_capsule.visible and game._view._escape_wreck.visible
			and game._view._escape_capsule.position.is_equal_approx(flight.position)
			and game._view._escape_wreck.position.is_equal_approx(status.wreck_position)
			and not game._view._ship.visible and not game._hud._steer.visible,
			"Touch ejection shows the distinct pod and wreck, with old ship steering hidden")
		await process_frame
		_tap_control(viewport, game._hud._actions["rescue_signal"])
		_expect(flight.escape_status().waiting and game._hud._rescue_panel.visible
			and not flight.escape_status().destination_name.is_empty()
			and flight.escape_status().destination_name in game._hud._rescue_caption.text,
			"The rescue touch sends a request and exposes an actual destination in the countdown")
	viewport.queue_free()
	await process_frame


func _tap_control(viewport: SubViewport, button: Button) -> void:
	var point := button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 4
		touch.position = point
		touch.pressed = pressed
		viewport.push_input(touch, true)


func _neutral_hulls(flight: Flight) -> Dictionary:
	var result := {}
	for row: Dictionary in flight.traffic_contacts():
		if row.role in ["trader", "patrol"]:
			result[row.id] = row.hull
	return result


func _until(flight: Flight, reached: Callable, seconds: float) -> bool:
	for _frame in range(ceili(seconds / Fixture.STEP)):
		if reached.call():
			return true
		flight.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
	return reached.call()


func _cold_load(flight: Flight) -> Flight:
	var path := "user://survival-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var replacement := Flight.new()
	var accepted := Session.save_state(flight.snapshot(), path) == OK \
		and Session.load_valid_state(path, replacement.restore) == Session.LoadResult.PRIMARY
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return replacement if accepted else null


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
