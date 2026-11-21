extends SceneTree

const Flight := preload("res://scripts/flight_sim.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const CargoPods := preload("res://scripts/cargo_pods.gd")
const Session := preload("res://scripts/session_io.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const SAVE_PATH := "user://cargo-pods-test.json"
const OPEN_SPACE := Vector3(2400.0, 8100.0, 8000.0)

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_test_round_trip_and_recovery()
	_test_jump_and_expiration()
	_test_legacy_and_corrupt_saves()
	print("Cargo pods integration: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _test_round_trip_and_recovery() -> void:
	var flight := Flight.new()
	_expect(flight.mining.insert_cargo("circuits", 2) and not flight.jettison_cargo("circuits")
		and flight.mining.cargo_amount("circuits") == 2 and flight.local_cargo_pods().is_empty(),
		"A docked ship cannot eject or lose any cargo")
	if not _expect(Fixture.launch(flight), "Begin a free flight"):
		return
	flight.position = OPEN_SPACE
	flight.velocity = Vector3(16, 7, 4)
	_expect(flight.mining.insert_cargo("ice", 1) and flight.jettison_cargo("circuits") and flight.jettison_cargo("ice"),
		"Eject two occupied slots containing different goods")
	var initial := flight.local_cargo_pods()
	if not _expect(initial.size() == 2 and int(initial[0].id) < int(initial[1].id)
		and initial[0].good == "circuits" and initial[1].good == "ice"
		and flight.mining.cargo_amount("circuits") == 1 and flight.mining.cargo_amount("ice") == 0,
		"The exact goods move from the hold into two independently identified containers"):
		return
	var first: int = initial[0].id
	var second: int = initial[1].id
	var original_target := flight.target
	_expect(flight.target_cargo_pod() and flight.cargo_pod_status().id == first and flight.cargo_pod_status().tracking
		and flight.target_cargo_pod() and flight.cargo_pod_status().id == second
		and flight.target == original_target and not flight.autopilot,
		"Repeated targeting cycles local containers without replacing the ship's navigation course or starting autopilot")
	flight.change_target()
	_expect(not flight.cargo_pod_status().tracking and flight.target != original_target and flight.local_cargo_pods().size() == 2,
		"Cycling to a destination clears the container marker while preserving both containers")
	_expect(not flight.collect_cargo_pod(first) and flight.status_event == "cargo_pod_collect_denied",
		"Recovery requires an installed fragment collector")
	flight.ship.fragment_collector = true
	flight.update(0.5, Vector2.ZERO, 0.0, false, false)
	var displaced := flight.cargo_pod_status(first)
	var origin: Vector3 = initial[0].position
	var drift: Vector3 = initial[0].velocity
	_expect(displaced.position.is_equal_approx(origin + drift * 0.5) and displaced.velocity.is_equal_approx(drift),
		"An ejected container drifts along its own trajectory using the simulation clock")
	_expect(flight.target_cargo_pod(first) and flight.cargo_pod_status(first).tracking,
		"Select a precise container ID for a checkpoint during free flight")
	var checkpoint := flight.snapshot()
	var reopened := Flight.new()
	if not _expect(Session.save_state(checkpoint, SAVE_PATH) == OK and reopened.restore(Session.load_state(SAVE_PATH))
		and reopened.snapshot().cargo_pods == checkpoint.cargo_pods and reopened.cargo_pod_status().tracking,
		"Cold JSON reload preserves the two container trajectories and the selected ID"):
		return
	var pod := reopened.cargo_pod_status(first)
	reopened.position = pod.position + Vector3(0, 0, Flight.FRAGMENT_COLLECT_RANGE + 5.0)
	reopened.velocity = pod.velocity
	_expect(not reopened.cargo_pod_status(first).collectible and not reopened.collect_cargo_pod(first),
		"A valid selected ID cannot be collected outside pickup range")
	reopened.position = pod.position + Vector3(0, 0, 10)
	reopened.velocity = pod.velocity + Vector3(Flight.FRAGMENT_COLLECT_SPEED + 1.0, 0, 0)
	_expect(not reopened.collect_cargo_pod(first) and reopened.local_cargo_pods().size() == 2,
		"Excess relative speed blocks collection without removing the pod")
	reopened.velocity = pod.velocity
	var fill := reopened.mining.free_capacity()
	_expect(reopened.mining.insert_cargo("ore", fill) and not reopened.collect_cargo_pod(first)
		and reopened.local_cargo_pods().size() == 2 and reopened.mining.remove_cargo("ore", fill),
		"A full shared hold refuses the transfer and preserves both container entries")
	_expect(reopened.collect_cargo_pod(first) and reopened.mining.cargo_amount("circuits") == 2
		and not reopened.collect_cargo_pod(first) and not reopened.cargo_pod_status(first).active
		and reopened.local_cargo_pods().size() == 1 and reopened.mining.cargo_amount("ice") == 0,
		"A repeated request for the same ID cannot duplicate its good or accidentally pick the other one")
	_expect(reopened.collect_cargo_pod(second) and reopened.mining.cargo_amount("ice") == 1
		and reopened.local_cargo_pods().is_empty() and not reopened.cargo_pod_status().tracking,
		"The existing collector can recover further containers using the same flight flow")
	var finalized := Flight.new()
	_expect(Session.save_state(reopened.snapshot(), SAVE_PATH) == OK and finalized.restore(Session.load_state(SAVE_PATH))
		and finalized.local_cargo_pods().is_empty() and finalized.mining.cargo_amount("circuits") == 2
		and finalized.mining.cargo_amount("ice") == 1,
		"A second cold reload cannot recreate recovered goods in space")


func _test_jump_and_expiration() -> void:
	var flight := _free_flight()
	flight.mining.insert_cargo("ore", CargoPods.CAPACITY + 1)
	var issued := 0
	for _index in range(CargoPods.CAPACITY):
		issued += int(flight.jettison_cargo("ore"))
	_expect(issued == CargoPods.CAPACITY and not flight.jettison_cargo("ore")
		and flight.mining.cargo_amount("ore") == 1 and flight.local_cargo_pods().size() == CargoPods.CAPACITY,
		"The active container cap refuses additional ejects without losing another unit")
	var tracked: int = flight.cargo_pod_status().id
	if not _expect(flight.target_cargo_pod(tracked) and flight.plan_jump(Catalog.VELAR_SYSTEM) and flight.start_jump(),
		"Charge a real jump from the system containing loose pods"):
		return
	for _step in range(32):
		if flight.jump_seconds_left <= 0.0:
			break
		flight.update(0.25, Vector2.ZERO, 0.0, false, false)
	_expect(flight.system_id == Catalog.VELAR_SYSTEM and flight.local_cargo_pods().is_empty()
		and not flight.collect_cargo_pod(tracked) and flight.snapshot().cargo_pods.items.size() == CargoPods.CAPACITY
		and flight.snapshot().cargo_pods.tracked == -1,
		"Arrival hides the prior system's pods and clears tracking while retaining their state")
	var resumed := Flight.new()
	if not _expect(resumed.restore(flight.snapshot()), "A save in a different system still validates every prior container"):
		return
	resumed._advance_background_clock(CargoPods.LIFETIME)
	resumed.position = OPEN_SPACE
	_expect(resumed.snapshot().cargo_pods.items.is_empty() and resumed.jettison_cargo("ore")
		and int(resumed.cargo_pod_status().id) > tracked and resumed.local_cargo_pods().size() == 1,
		"Expired pods release capacity without recycling an old action ID")


func _test_legacy_and_corrupt_saves() -> void:
	var flight := _free_flight()
	var legacy := flight.snapshot()
	legacy.schema = 47
	Fixture.remove_expanded_market_from_legacy(legacy)
	legacy.erase("cargo_pods")
	legacy.mining.reserves.resize(Catalog.PRE_RICH_SYSTEMS_DESTINATION_COUNT)
	_expect(flight.restore(legacy) and flight.local_cargo_pods().is_empty() and flight.snapshot().schema == Flight.SAVE_SCHEMA,
		"A schema 47 flight migrates with an empty container ledger")
	flight.mining.insert_cargo("ore", 1)
	if not _expect(flight.jettison_cargo("ore") and flight.target_cargo_pod(), "Create a single tracked ledger for corruption checks"):
		return
	var intact := flight.snapshot()
	var invalid_cases: Array[Dictionary] = []
	var bad := intact.duplicate(true)
	bad.erase("cargo_pods")
	invalid_cases.append(bad)
	bad = intact.duplicate(true)
	bad.cargo_pods.items.append(bad.cargo_pods.items.front().duplicate(true))
	invalid_cases.append(bad)
	bad = intact.duplicate(true)
	bad.cargo_pods.items[0].good = "unknown"
	invalid_cases.append(bad)
	bad = intact.duplicate(true)
	bad.cargo_pods.items[0].created = float(bad.orbit_time) + 1.0
	invalid_cases.append(bad)
	bad = intact.duplicate(true)
	bad.cargo_pods.items[0].velocity = [1000.0, 0.0, 0.0]
	invalid_cases.append(bad)
	bad = intact.duplicate(true)
	bad.cargo_pods.items[0].system = Catalog.VELAR_SYSTEM
	invalid_cases.append(bad)
	bad = intact.duplicate(true)
	bad.cargo_pods.items[0].system = Catalog.SYSTEM_COUNT - 1
	invalid_cases.append(bad)
	for invalid in invalid_cases:
		_expect(not flight.restore(invalid) and flight.snapshot() == intact,
			"Invalid container snapshots are rejected before mutating a live flight")


func _free_flight() -> Flight:
	var flight := Flight.new()
	Fixture.launch(flight)
	flight.position = OPEN_SPACE
	flight.velocity = Vector3.ZERO
	return flight


func _expect(value: bool, description: String) -> bool:
	_checks += 1
	if not value:
		_failures += 1
		printerr(description)
	return value
