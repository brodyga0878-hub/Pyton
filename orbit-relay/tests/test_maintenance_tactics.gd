extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Combat := preload("res://scripts/combat_systems.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Maintenance := preload("res://scripts/ship_maintenance.gd")
const Patrol := preload("res://scripts/patrol_encounter.gd")
const OPEN_SPACE := Vector3(2400, 8100, 8000)

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_module_repair()
	_test_drive_maintenance()
	_test_npc_tactics()
	_test_missile_defence()
	_test_ambient_reacquisition()
	for message: String in _failures:
		printerr(message)
	print("Maintenance and patrol tactics: %d checks, %d failures" % [_checks, _failures.size()])
	quit(int(not _failures.is_empty()))


func _test_module_repair() -> void:
	var flight := Flight.new()
	flight.credits = 700
	_expect(flight.service_action("combat_auto_repair") and flight.service_action("combat_launcher")
		and flight.service_action("combat_missile_dart") and flight.maintenance_status().auto_fitted,
		"Purchase the repair unit, launcher, and one usable missile through normal services")
	Fixture.launch(flight)
	flight.position = OPEN_SPACE
	flight.velocity = Vector3.ZERO
	var source := flight.position + Vector3.BACK * 85.0
	flight.combat.incoming_shot(source, flight.position, flight.system_id, flight.orbit_time)
	if not _expect(flight.combat.incoming_shot(source, flight.position, flight.system_id, flight.orbit_time)
		and _until(flight, func() -> bool: return flight.combat.damaged == Combat.LAUNCHER_MODULE, 4.0),
		"A real missile impact can disable the new launcher while leaving its loaded slot intact"):
		return
	_expect(flight.missile_status().reason.contains("повреждена") and flight.maintenance_status().auto_wait > 0.0
		and flight.maintenance_status().wear > 0.0, "Damage blocks launch and starts a persistent repair wait and drive wear")
	var cold := Flight.new()
	if not _expect(cold.restore(_round_trip(flight)) and cold.combat.damaged == Combat.LAUNCHER_MODULE,
		"The disabled equipment and active maintenance timer survive serialization"):
		return
	var hull := cold.ship.hull
	_expect(_until(cold, func() -> bool: return cold.combat.damaged.is_empty(), Maintenance.REPAIR_DELAY + Fixture.STEP)
		and cold.combat_equipment_status().missile_ammo.dart == 1 and cold.ship.hull == hull,
		"The fitted module restores operation after waiting without healing hull or replenishing ammo")


func _test_drive_maintenance() -> void:
	var flight := Flight.new()
	var previous_jumps := floori((Maintenance.WEAR_LIMIT - Maintenance.JUMP_WEAR) / Maintenance.JUMP_WEAR)
	for _index in range(previous_jumps):
		flight._maintenance.record_jump(flight.orbit_time, false)
	var worn: float = flight.maintenance_status().wear
	_expect(worn == Maintenance.WEAR_LIMIT - Maintenance.JUMP_WEAR and flight.maintenance_status().drive_cooldown == 0,
		"Earlier completed trips leave a worn, working drive")
	Fixture.launch(flight)
	flight.position = OPEN_SPACE
	flight.velocity = Vector3.ZERO
	if not _expect(flight.plan_jump(Catalog.VELAR_SYSTEM) and flight.start_jump()
		and _until(flight, func() -> bool: return flight.system_id == Catalog.VELAR_SYSTEM, 8.0),
		"A normal paid journey finishes at the real destination"):
		return
	var cold := Flight.new()
	_expect(flight.maintenance_status().wear == Maintenance.WEAR_LIMIT and flight.maintenance_status().drive_cooldown > 0.0
		and flight.jump_status(Catalog.HOME_SYSTEM).reason.contains("восстанавливается")
		and cold.restore(_round_trip(flight)), "Full accumulated wear blocks another jump temporarily and persists on reload")
	if cold.system_id == Catalog.VELAR_SYSTEM:
		_expect(_until(cold, func() -> bool: return cold.maintenance_status().drive_cooldown <= 0.0, Maintenance.DRIVE_COOLDOWN + Fixture.STEP)
			and cold.maintenance_status().wear == Maintenance.WEAR_LIMIT, "A remote pilot can wait out the temporary fault without a port")
	var berthed := Flight.new()
	berthed.credits = 400
	berthed._maintenance.record_jump(0.0, true)
	var fee := int(berthed.service_offer("combat_maintenance").cost)
	_expect(berthed.service_action("combat_maintenance") and berthed.maintenance_status().wear == 0.0
		and berthed.credits == 400 - fee and not berthed.service_action("combat_maintenance"),
		"A paid berth overhaul clears the wear exactly once")


func _test_npc_tactics() -> void:
	var pursuer := _local_patrol(int(Catalog.system(Catalog.VELAR_SYSTEM).arrival_port))
	var skirmisher := _local_patrol(Catalog.FRINGE_ARRIVAL_PORT)
	if not _expect(pursuer != null and skirmisher != null, "Engage patrol contacts in two different authored systems"):
		return
	var first := pursuer.patrol.contacts(pursuer)[0]
	var second := skirmisher.patrol.contacts(skirmisher)[0]
	_expect(first.variant == Patrol.PURSUER and first.tactic == "pursuit" and first.hardened_missiles
		and second.variant == Patrol.SKIRMISHER and second.tactic == "strafe" and not second.hardened_missiles
		and first.weapon != second.weapon, "Profiles differ in actual manoeuvre, emitter and missile protection")
	var cold := Flight.new()
	_expect(cold.restore(_round_trip(pursuer)) and cold.patrol.snapshot().tactics == pursuer.patrol.snapshot().tactics
		and cold.patrol.contacts(cold)[0].position.is_equal_approx(first.position), "Restore the same moving tactical position and velocity")
	var old := pursuer.patrol.snapshot()
	old.erase("tactics")
	var legacy := Patrol.new()
	_expect(legacy.restore(old, true) and legacy.contacts(pursuer)[0].variant == Patrol.CLASSIC,
		"An already active legacy encounter keeps its classic profile")
	pursuer.patrol.missile_hit(pursuer, first.id, 64.0)
	var earlier_distance: float = pursuer.position.distance_to(pursuer.patrol.contacts(pursuer)[0].position)
	for _frame in range(120):
		pursuer.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
	var avoiding := pursuer.patrol.contacts(pursuer)[0]
	_expect(avoiding.tactic == "evade" and pursuer.position.distance_to(avoiding.position) > earlier_distance,
		"The damaged pursuer moves away in evasion instead of continuing its pursuit route")


func _test_missile_defence() -> void:
	for port: int in [int(Catalog.system(Catalog.VELAR_SYSTEM).arrival_port), Catalog.FRINGE_ARRIVAL_PORT]:
		var pilot := _local_patrol(port, true)
		if not _expect(pilot != null, "Reach each advanced profile after buying ammunition at the port"):
			continue
		var target := pilot.patrol.contacts(pilot)[0]
		var control := Flight.new()
		if not _expect(control.restore(_round_trip(pilot)) and pilot.select_combat_contact(target.id),
			"The baseline and missile-run share the same active opponent before launch"):
			continue
		_aim(pilot, target.position)
		if not _expect(pilot.launch_missile(target.id) and pilot.patrol_status().missile_defence,
			"A live incoming projectile enters the opponent's reaction envelope"):
			continue
		var ordnance := pilot.combat.ordnance
		_expect(ordnance.threatening_missile(pilot.orbit_time, pilot.system_id, "other", target.position, 205.0).is_empty()
			and ordnance.threatening_missile(pilot.orbit_time, pilot.system_id + 1, target.id, target.position, 205.0).is_empty()
			and ordnance.threatening_missile(pilot.orbit_time, pilot.system_id, target.id,
				Vector3(ordnance.missile.position) - Vector3(ordnance.missile.velocity).normalized() * 10.0, 205.0).is_empty(),
			"An unrelated, remote, or already passed projectile cannot trigger the defence")
		pilot.patrol.restore_combat_clock({"shot": 0.0, "attack": 0.0})
		control.patrol.restore_combat_clock({"shot": 0.0, "attack": 0.0})
		_tick(pilot)
		_tick(control)
		var evasive := pilot.patrol.contacts(pilot)[0]
		var ordinary := control.patrol.contacts(control)[0]
		_expect(evasive.tactic == "evade" and evasive.missile_defence
			and evasive.position.distance_to(ordinary.position) > 0.1
			and evasive.velocity.distance_to(ordinary.velocity) > 5.0
			and Vector3(evasive.forward).is_equal_approx(pilot.patrol._tactical_velocity.normalized())
			and pilot.ship.hull == 100.0 and control.ship.hull < 100.0,
			"The reacting opponent turns into its altered trajectory and defers a due shot")
		var cold := Flight.new()
		if not _expect(cold.restore(_round_trip(pilot)) and cold.patrol_status().missile_defence
			and cold.patrol.combat_clock() == pilot.patrol.combat_clock(),
			"A cold load retains the guided threat and the pending reacquisition delay"):
			continue
		_tick(pilot)
		_tick(cold)
		_expect(cold.patrol.contacts(cold)[0].position.is_equal_approx(pilot.patrol.contacts(pilot)[0].position)
			and cold.combat.ordnance.snapshot() == pilot.combat.ordnance.snapshot(),
			"The saved evasive path and projectile both continue deterministically")
		_expect(_until(cold, func() -> bool: return cold.combat.ordnance.missile.is_empty(), 6.0)
			and _until(cold, func() -> bool: return cold.ship.hull < 100.0, 3.1)
			and not cold.patrol_status().missile_defence,
			"The opponent resumes pressure after the projectile resolves")
		_test_reaction_range(port, target.variant == Patrol.SKIRMISHER)


func _test_reaction_range(port: int, reacts_early: bool) -> void:
	var pilot := _local_patrol(port, true)
	if not _expect(pilot != null, "Begin a second run to measure the profile's reaction distance"):
		return
	var target := pilot.patrol.contacts(pilot)[0]
	pilot.position = target.position + Vector3.BACK * 180.0
	_aim(pilot, target.position)
	_expect(pilot.select_combat_contact(target.id) and pilot.launch_missile(target.id)
		and pilot.patrol_status().missile_defence == reacts_early,
		"The lighter skirmisher reacts to a distant missile before the larger pursuer would")


func _test_ambient_reacquisition() -> void:
	var pilot := Flight.new()
	if not _expect(_fit_test_missile(pilot) and Fixture.launch(pilot), "Undock with ammunition for a local unscripted fight"):
		return
	pilot.update(40.3 - pilot.orbit_time, Vector2.ZERO, 0.0, false, false)
	var target := pilot.ambient_status()
	pilot.position = target.position + Vector3.BACK * 100.0
	pilot.velocity = Vector3.ZERO
	_tick(pilot)
	target = pilot.ambient_status()
	_aim(pilot, target.position)
	if not _expect(target.danger and pilot.select_combat_contact(target.id) and pilot.launch_missile(target.id)
		and pilot.ambient_status().missile_defence, "A scheduled raider recognizes the projectile aimed at its current raid"):
		return
	var due := pilot.ambient.snapshot()
	due.next_attack = pilot.orbit_time + Fixture.STEP * 0.5
	if not _expect(pilot.ambient.restore(due, pilot.orbit_time), "Reach the boundary of a due counterfire shot"):
		return
	_tick(pilot)
	_expect(pilot.ship.hull == 100.0 and pilot.ambient.snapshot().next_attack > pilot.orbit_time + 0.8,
		"The ambient raider postpones counterfire while the missile is closing")
	var cold := Flight.new()
	if not _expect(cold.restore(_round_trip(pilot)) and cold.ambient_status().missile_defence
		and cold.ambient.snapshot().next_attack == pilot.ambient.snapshot().next_attack,
		"The ambient defence delay can resume from existing save fields"):
		return
	_expect(_until(cold, func() -> bool: return cold.combat.ordnance.missile.is_empty(), 6.0)
		and _until(cold, func() -> bool: return cold.ship.hull < 100.0, 3.1),
		"An undestroyed raider resumes counterfire after the projectile resolves")


func _local_patrol(port: int, with_missile := false) -> Flight:
	var flight := Flight.new()
	flight.system_id = Catalog.system_of_site(port)
	flight.target = port
	flight.docked = port
	if with_missile and not _fit_test_missile(flight):
		return null
	if not flight.patrol_action() or not Fixture.launch(flight):
		return null
	flight.position = flight.patrol.signal_position(flight) + Vector3.BACK * 108.0
	flight.velocity = Vector3.ZERO
	for _frame in range(35):
		flight.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
	return flight if flight.patrol.phase == Patrol.ENGAGED else null


func _fit_test_missile(flight: Flight) -> bool:
	flight.credits = 1000
	return flight.service_action("combat_launcher") and flight.service_action("combat_missile_dart")


func _aim(flight: Flight, point: Vector3) -> void:
	var direction := flight.position.direction_to(point)
	flight.yaw = atan2(-direction.x, -direction.z)
	flight.pitch = asin(direction.y)


func _tick(flight: Flight) -> void:
	flight.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)


func _round_trip(flight: Flight) -> Dictionary:
	return JSON.parse_string(JSON.stringify(flight.snapshot(), "", true, true))


func _until(flight: Flight, condition: Callable, seconds: float) -> bool:
	for _frame in range(ceili(seconds / Fixture.STEP)):
		if condition.call():
			return true
		flight.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
	return condition.call()


func _expect(value: bool, description: String) -> bool:
	_checks += 1
	if not value:
		_failures.append(description)
	return value
