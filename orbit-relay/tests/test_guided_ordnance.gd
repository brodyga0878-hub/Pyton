extends SceneTree

const Combat := preload("res://scripts/combat_systems.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const FlightView := preload("res://scripts/flight_view.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Ordnance := preload("res://scripts/combat_ordnance.gd")
const Patrol := preload("res://scripts/patrol_encounter.gd")
const Session := preload("res://scripts/session_io.gd")
const OPEN_SPACE := Vector3(2400, 8100, 8000)
const STEP := Fixture.STEP

var _checks := 0
var _failures: Array[String] = []
var _view := FlightView.new()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	viewport.add_child(_view)
	_test_player_rack()
	_test_hostile_guidance()
	_test_countermeasures()
	_test_legacy()
	viewport.queue_free()
	await process_frame
	for failure: String in _failures:
		printerr(failure)
	print("Guided ordnance: %d checks, %d failures" % [_checks, _failures.size()])
	quit(int(not _failures.is_empty()))


func _test_player_rack() -> void:
	var flight := Flight.new()
	flight.credits = 1000
	_expect(not flight.service_action("combat_missile_dart") and flight.credits == 1000,
		"A missile purchase requires an installed rack and a denied purchase charges nothing")
	if not _expect(flight.service_action("combat_launcher") and not flight.service_action("combat_launcher"),
		"A berth can install exactly one four-slot rack"):
		return
	for kind in ["dart", "dart", "lance", "lance"]:
		_expect(flight.service_action("combat_missile_" + kind), "Buy one missile into a discrete slot")
	var credit_total := 1000 - Ordnance.LAUNCHER_COST - 2 * (int(Ordnance.PROFILES.dart.cost) + int(Ordnance.PROFILES.lance.cost))
	_expect(flight.credits == credit_total and not flight.service_action("combat_missile_dart"),
		"All four occupied rails cap the order and every purchase debits its own price once")
	_expect(flight.select_missile("lance") and flight.combat_equipment_status().missile_slot == 2
		and flight.select_missile_slot(1) and not flight.select_missile_slot(4),
		"Select either type and the second rail of the same installed type")
	var persisted := _cold_load(flight)
	if not _expect(persisted != null and persisted.combat_equipment_status().missile_slots == ["dart", "dart", "lance", "lance"]
		and persisted.combat_equipment_status().missile_slot == 1, "JSON reload retains all rails and the exact chosen index"):
		return
	flight = persisted
	if not _expect(flight.patrol_action() and Fixture.depart(flight) and flight.patrol_action()
		and _until(flight, func() -> bool: return flight.patrol.phase == Patrol.ENGAGED, 50.0),
		"Engage the existing moving patrol raider through the actual mission and approach"):
		return
	var target := flight.patrol.contacts(flight)[0]
	var id: String = target.id
	var aim := flight.position.direction_to(target.position)
	flight.yaw = atan2(-aim.x, -aim.z) + 0.25
	flight.pitch = clampf(asin(aim.y), -Flight.MAX_PITCH, Flight.MAX_PITCH)
	_expect(not flight.launch_missile(id) and flight.combat_equipment_status().missile_ammo.dart == 2,
		"Knowing a hostile's ID without a genuine lock cannot launch or spend ammo")
	var hull := flight.patrol.enemy_hull
	var rail_origin := flight.position + flight.forward() * 5.0 - flight.attitude().x * 1.3
	if not _expect(flight.select_combat_contact(id) and not flight.launch_missile("unlocked-contact")
		and flight.launch_missile(id), "Only the explicit current hostile lock can be launched upon"):
		return
	var launched: Dictionary = flight.missile_status().projectile
	_expect(launched.slot == 1 and launched.target == id and Vector3(launched.position).is_equal_approx(rail_origin)
		and flight.combat_equipment_status().missile_slots == ["dart", "", "lance", "lance"]
		and flight.patrol.enemy_hull == hull and not flight.launch_missile(id),
		"Launch spends the chosen second rail, has its physical origin, and deals no instant damage")
	_view.sync(flight, 0.0)
	_expect(_view._player_missile.is_visible_in_tree() and _view._player_missile.global_position.is_equal_approx(launched.position)
		and not _view._player_decoy.visible, "The rendered player missile appears at the actual rail position")
	flight.update(0.10, Vector2.ZERO, 0.0, false, false)
	var flight_path: Dictionary = flight.missile_status().projectile
	if not _expect(not flight_path.is_empty() and Vector3(flight_path.velocity).angle_to(launched.velocity) > 0.02
		and Vector3(flight_path.velocity).angle_to(launched.velocity) <= float(Ordnance.PROFILES.dart.turn) * 0.10 + 0.001,
		"An off-axis moving target requires finite guidance before impact"):
		return
	_view.sync(flight, 0.10)
	_expect(_view._player_missile.global_position.is_equal_approx(flight_path.position)
		and (-_view._player_missile.global_basis.z).is_equal_approx(Vector3(flight_path.velocity).normalized()),
		"The visible model moves and turns with the guided flight step")
	_expect(flight.select_combat_contact("") and flight.toggle_time_pause(), "A launched missile keeps its original lock while the pilot clears the current selection")
	var cold := _cold_load(flight)
	if not _expect(cold != null and cold.combat_lock_id().is_empty() and cold.missile_status().projectile.target == id
		and cold.time_paused, "The in-flight missile retains the original target while cold-loading a paused checkpoint"):
		return
	_view.sync(cold, 0.0)
	_expect(_view._player_missile.is_visible_in_tree()
		and _view._player_missile.global_position.is_equal_approx(cold.missile_status().projectile.position),
		"An active missile is visible at its persisted position after load")
	var before := cold.snapshot()
	cold.update(15.0, Vector2.ZERO, 0.0, false, false)
	_expect(cold.snapshot() == before and not cold.launch_missile(id), "Pause freezes the projectile and blocks more launches")
	var fabricated := before.duplicate(true)
	fabricated.combat.ordnance.missile.slot = 0
	_expect(not cold.restore(fabricated) and cold.snapshot() == before, "Reject an active missile allegedly fired from a rail still carrying ammunition")
	_expect(cold.toggle_time_pause() and _until(cold, func() -> bool: return cold.patrol.enemy_hull < hull, 6.0)
		and cold.patrol.enemy_hull == hull - Ordnance.PROFILES.dart.damage
		and cold.missile_status().projectile.is_empty() and cold.combat_equipment_status().missile_ammo.dart == 1,
		"The in-flight missile hits the original moving actor exactly once and keeps the other rail")
	_view.sync(cold, 0.0)
	_expect(not _view._player_missile.visible, "The player missile model disappears after the actual impact")


func _test_hostile_guidance() -> void:
	var flight := _open_flight()
	if not _expect(_incoming(flight, 150.0, false), "Two actual enemy salvo events launch an incoming projectile"):
		return
	var before := flight.combat.projectile_status()
	flight.position += Vector3(40.0, 0.0, 0.0)
	flight.update(0.10, Vector2.ZERO, 0.0, false, false)
	var after := flight.combat.projectile_status()
	var angle := Vector3(after.velocity).angle_to(before.velocity)
	_expect(angle > 0.02 and angle <= Ordnance.HOSTILE_TURN * 0.10 + 0.001
		and is_equal_approx(Vector3(after.velocity).length(), Combat.PROJECTILE_SPEED),
		"Hostile missile turns toward the displaced ship at a finite rate without changing speed")
	var hull := flight.ship.hull
	_expect(_until(flight, func() -> bool: return flight.ship.hull < hull, 6.0)
		and flight.ship.hull == hull - Flight.MISSILE_DAMAGE and flight.combat.projectile_status().is_empty(),
		"A physical proximity hit applies damage once after the evasion displacement")


func _test_countermeasures() -> void:
	var basic := Combat.new()
	var source := Vector3(170.0, 0.0, 0.0)
	_expect(basic.buy("combat_ecm_advanced", 200) == 0 and basic.buy("combat_ecm", 200) == Combat.ECM_COST
		and not basic.incoming_shot(source, Vector3.ZERO, 0, 3.0, true)
		and basic.incoming_shot(source, Vector3.ZERO, 0, 4.0, true), "The enhanced module requires the basic one and a real hardened missile can be active")
	_expect(not basic.use_ecm(Vector3(50.0, 0.0, 0.0), 4.0) and not basic.projectile_status().is_empty(),
		"A hardened missile resists basic ECM even inside its ordinary radius")
	_expect(basic.buy("combat_ecm_advanced", 200) == Combat.ECM_ADVANCED_COST and basic.use_ecm(Vector3.ZERO, 4.0)
		and basic.projectile_status().is_empty() and basic.snapshot().ecm_ready_at == 4.0 + Combat.ECM_ADVANCED_COOLDOWN,
		"Enhanced ECM intercepts the protected missile at greater range and uses its own cooldown")
	var flight := Flight.new()
	flight.credits = 100
	_expect(flight.service_action("combat_decoy") and flight.service_action("combat_decoy"), "Purchase expendable decoys separately from ECM")
	Fixture.launch(flight)
	flight.position = OPEN_SPACE
	flight.velocity = Vector3.ZERO
	if not _expect(_incoming(flight, 145.0, true) and flight.launch_decoy()
		and flight.decoy_status().count == 1 and flight.decoy_status().active and not flight.launch_decoy()
		and not flight.combat.projectile_status().is_empty(), "A launched decoy spends one charge and leaves the physical missile in flight"):
		return
	var launch: Dictionary = flight.decoy_status()
	_view.sync(flight, 0.0)
	_expect(_view._player_decoy.is_visible_in_tree() and _view._player_decoy.global_position.is_equal_approx(launch.position),
		"The decoy model appears separately at the simulated deployment position")
	flight.update(0.10, Vector2.ZERO, 0.0, false, false)
	_view.sync(flight, 0.10)
	var moving: Dictionary = flight.decoy_status()
	_expect(moving.active and _view._player_decoy.global_position.is_equal_approx(moving.position)
		and not _view._player_decoy.global_position.is_equal_approx(launch.position),
		"The visible decoy follows the live countermeasure movement")
	var saved := _cold_load(flight)
	if not _expect(saved != null and saved.decoy_status().active and saved.decoy_status().count == 1
		and saved.combat.projectile_status().hardened, "The moving decoy and protected missile survive a JSON checkpoint"):
		return
	_view.sync(saved, 0.0)
	_expect(_view._player_decoy.is_visible_in_tree() and _view._player_decoy.global_position.is_equal_approx(saved.decoy_status().position),
		"Loading an active countermeasure draws at its restored position")
	var berthed := _cold_load(Flight.new())
	if _expect(berthed != null, "Load a separate checkpoint without active ordnance"):
		_view.sync(berthed, 0.0)
		_expect(not _view._player_decoy.visible and not _view._player_missile.visible,
			"The previous ordnance props are hidden when the loaded voyage has none")
	var hull := saved.ship.hull
	_expect(_until(saved, func() -> bool: return saved.status_event == "combat_decoy_hit", 4.0)
		and saved.ship.hull == hull and not saved.decoy_status().active and not saved.combat_status().projectile,
		"The physical decoy draws and intercepts a missile that basic ECM could not stop")
	_view.sync(saved, 0.0)
	_expect(not _view._player_decoy.visible, "Interception also removes the decoy from the flight scene")
	_expect(saved.launch_decoy() and _until(saved, func() -> bool: return not saved.decoy_status().active,
		Ordnance.DECOY_LIFETIME + STEP) and not saved.launch_decoy() and saved.decoy_status().count == 0,
		"An unused decoy expires at the finite lifetime without recreating its spent item")
	_view.sync(saved, 0.0)
	_expect(not _view._player_decoy.visible, "A spent decoy is hidden after its finite lifetime")


func _test_legacy() -> void:
	var old := Combat.new()
	old.buy("combat_ecm", Combat.ECM_COST)
	old.incoming_shot(Vector3(0, 0, 175), Vector3.ZERO, 0, 3.0)
	old.incoming_shot(Vector3(0, 0, 175), Vector3.ZERO, 0, 4.0)
	var saved := {"combat": old.snapshot()}
	Fixture.remove_ordnance_from_legacy(saved)
	var restored := Combat.new()
	_expect(restored.restore(saved.combat, 4.0, 0, true) and restored.ecm_fitted and not restored.ecm_advanced
		and not restored.projectile_status().hardened and not restored.ordnance.fitted and restored.ordnance.decoys == 0,
		"Old combat state retains the basic ECM and live standard missile, with no added equipment")


func _incoming(flight: Flight, distance: float, hardened: bool) -> bool:
	var source := flight.position + Vector3.BACK * distance
	flight.combat.incoming_shot(source, flight.position, flight.system_id, flight.orbit_time, hardened)
	return flight.combat.incoming_shot(source, flight.position, flight.system_id, flight.orbit_time, hardened)


func _open_flight() -> Flight:
	var flight := Flight.new()
	Fixture.launch(flight)
	flight.position = OPEN_SPACE
	flight.velocity = Vector3.ZERO
	return flight


func _cold_load(flight: Flight) -> Flight:
	var path := "user://ordnance-checkpoint-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var restored := Flight.new()
	var success := Session.save_state(flight.snapshot(), path) == OK \
		and Session.load_valid_state(path, restored.restore) == Session.LoadResult.PRIMARY
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return restored if success else null


func _until(flight: Flight, reached: Callable, seconds: float) -> bool:
	for _index in range(ceili(seconds / STEP)):
		if reached.call():
			return true
		flight.update(STEP, Vector2.ZERO, 0.0, false, false)
	return reached.call()


func _expect(value: bool, description: String) -> bool:
	_checks += 1
	if not value:
		_failures.append(description)
	return value
