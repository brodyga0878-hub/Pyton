extends SceneTree

const Main := preload("res://main.tscn")
const Flight := preload("res://scripts/flight_sim.gd")
const Career := preload("res://scripts/pilot_career.gd")
const Catalog := preload("res://scripts/sector_catalog.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const HOME := Catalog.HOME_SYSTEM
const PORT := 0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_combat_ranks()
	await _test_reconnaissance()
	_test_interception()
	_test_order_failure()
	print("Military orders and bounty integration: %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_combat_ranks() -> void:
	var record := Career.new()
	var thresholds := [0, 1, 3, 7, 15, 30, 60, 110, 180, 300]
	var names := {}
	for rank in range(thresholds.size()):
		var state := record.snapshot()
		state.combat = thresholds[rank]
		var next: int = thresholds[rank + 1] if rank + 1 < thresholds.size() else -1
		_expect(record.restore(state, 0.0) and record.status().combat_rank == rank
			and record.status().combat_next == next and not names.has(record.status().combat_title),
			"Combat threshold %d maps to one distinct rank and the correct next milestone" % thresholds[rank])
		names[record.status().combat_title] = true
	var differentiated := Career.new()
	var ordinary := differentiated.note_ambient_victory(HOME, 0, 0, 1000)
	var marked := differentiated.note_ambient_victory(HOME, 1, 0, 1000)
	_expect(ordinary.paid == 0 and marked.paid > 0 and differentiated.status().combat_points == 3
		and differentiated.note_convoy_result(0, 1, "intercept", true)
		and differentiated.status().combat_points == 6 and differentiated.status().bounty_awards == 1,
		"Ordinary encounters, wanted raiders, and convoy interceptions produce separate weighted credits")


func _test_reconnaissance() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var game := Main.instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var pilot := _senior_pilot(4)
	game.flight = pilot
	game._update_display(0.0)
	await process_frame
	_expect(pilot.contract_action() and pilot.contract_stage == 1, "Keep a civil transport contract independently active")
	_tap(viewport, game._hud._actions["journal"], "Open the actual career Journal from the flight HUD")
	await process_frame
	var journal: CanvasLayer = game._journal
	_tap(viewport, journal._career_tab, "Open the faction career page")
	await process_frame
	_tap(viewport, journal._career_buttons["intercept"], "View the senior order before qualifying")
	_expect(journal._career_action.disabled and "Нужен ранг" in journal._dispatch_hint.text,
		"Interception is explicitly gated by a higher independent service rank")
	_tap(viewport, journal._career_buttons["recon"], "Select the available reconnaissance order")
	await process_frame
	_tap(viewport, journal._career_action, "Accept a separate military order through its normal touch action")
	var order := pilot.career_status().order as Dictionary
	if not _expect(order.active and order.kind == "recon" and not order.proved and pilot.contract_stage == 1
		and not pilot.career_dispatch_action("dispatch"), "Taking a military order preserves the civil contract and blocks simultaneous service orders"):
		viewport.queue_free()
		return
	var site := int(order.site)
	_tap(viewport, journal._follow_buttons["career"], "Use the order to route to its actual reconnaissance body")
	_expect(pilot.planned_target == site and Fixture.launch(pilot), "The Journal plots the designated reconnaissance body")
	var center := pilot.target_position(site)
	pilot.position = center + Vector3.BACK * (float(Catalog.site(site).radius) + 200.0)
	pilot.velocity = pilot.target_velocity(site)
	_aim(pilot, center)
	_expect(not pilot.career_dispatch_action("recon"), "A spot outside the observation envelope cannot record proof")
	pilot.position -= Vector3.BACK * 100.0
	_aim(pilot, center)
	pilot.velocity += Vector3.RIGHT * 72.0
	_expect(not pilot.career_dispatch_action("recon"), "Passing the target at high relative speed cannot record proof")
	pilot.velocity = pilot.target_velocity(site)
	_expect(pilot.career_status().order_can_probe and pilot.career_dispatch_action("recon") and pilot.career_status().order.proved,
		"Good range, speed and heading complete the real reconnaissance proof once")
	var stored := pilot.snapshot()
	var cold := Flight.new()
	if _expect(cold.restore(_json(stored)) and cold.career_status().order.proved,
		"The evidence, deadline and commissioning port survive cold load"):
		var balance := cold.credits
		_expect(not cold.career_dispatch_action("recon") and _return_to_port(cold)
			and cold.career_dispatch_action("recon") and cold.credits == balance + int(order.reward)
			and cold.career_status().factions[0].service_rank == 3 and cold.career_status().factions[1].service_points == 0
			and not cold.career_status().order.active and cold.contract_stage == 1,
			"Report proof at the issuing port to earn a single promotion while the civilian work remains active")
	viewport.queue_free()
	await process_frame


func _test_interception() -> void:
	var pilot := _senior_pilot(6)
	if not _expect(pilot.career_dispatch_action("intercept"), "Senior service and trust qualify for the sector defence order"):
		return
	pilot.update(174.0, Vector2.ZERO, 0.0, false, false)
	if not _expect(Fixture.launch(pilot), "Depart to exercise a normally scheduled raid on the local route"):
		return
	var contact := pilot.ambient_status()
	var wanted := pilot.career_status().wanted as Dictionary
	if not _expect(contact.hostile and int(wanted.get("reward", 0)) > 0 and wanted.id == contact.id,
		"The currently marked live raider has its own posted bounty"):
		return
	var contact_row := pilot.traffic_contacts().filter(func(item: Dictionary) -> bool: return item.id == contact.id)
	_expect(contact_row.size() == 1 and int(contact_row[0].get("bounty", 0)) == int(wanted.reward)
		and "в розыске" in str(contact_row[0].name), "The combat contact is visibly marked before victory")
	pilot.position = contact.position + Vector3.BACK * 105.0
	pilot.velocity = Vector3.ZERO
	for _step in range(420):
		if not pilot.ambient_status().hostile:
			break
		_aim(pilot, pilot.ambient_status().position)
		if pilot.fire_status().ok:
			pilot.fire_action()
		if pilot.ambient_status().hostile:
			pilot.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
	var status := pilot.career_status()
	if not _expect(not pilot.ambient_status().hostile and status.order.proved and status.bounty_awards == 1
		and status.bounty_credits == wanted.reward and pilot.credits == wanted.reward and status.combat_points == 2,
		"A marked laser victory pays the bounty immediately and only marks military proof for later reporting"):
		return
	var checkpoint := pilot.snapshot()
	var cold := Flight.new()
	_expect(cold.restore(_json(checkpoint)), "Restore the actual completed victory and the separate active military report")
	var replay := {"event": "ambient_victory", "message": "", "system": HOME, "cycle": int(contact.cycle)}
	cold._apply_ambient_result(replay)
	_expect(cold.credits == wanted.reward and cold.career_status().combat_points == status.combat_points
		and cold.career_status().bounty_awards == 1, "Duplicate victory delivery after restoration cannot add rating or credits")
	var reward := int(status.order.reward)
	_expect(_return_to_port(cold) and cold.career_dispatch_action("intercept") and cold.credits == int(wanted.reward) + reward
		and cold.career_status().bounty_awards == 1 and not cold.career_status().order.active,
		"The military report pays its own contract without a second bounty")
	var old := checkpoint.duplicate(true)
	old.schema = 49
	Fixture.remove_extended_career_from_legacy(old)
	Fixture.remove_ordnance_from_legacy(old)
	var migrated := Flight.new()
	if _expect(migrated.restore(_json(old)) and migrated.credits == checkpoint.credits and migrated.career_status().bounty_awards == 0,
		"Old career state retains existing rating and credits without retroactive bounty payments"):
		migrated.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
		_expect(migrated.credits == checkpoint.credits and not migrated.ambient_status().hostile,
			"The completed encounter remains defeated beyond the first migrated tick")


func _test_order_failure() -> void:
	var pilot := _senior_pilot(6)
	if not _expect(pilot.career_dispatch_action("intercept"), "Prepare an expiring real service order"):
		return
	var deadline := float(pilot.career_status().order.deadline)
	pilot.update(deadline - pilot.orbit_time, Vector2.ZERO, 0.0, false, false)
	var status := pilot.career_status()
	_expect(not status.order.active and status.factions[0].service_points == 4 and status.factions[0].service_rank == 2
		and status.factions[0].trust == 4 and status.factions[1].service_points == 0 and pilot.credits == 0,
		"A missed operation demotes only the issuing faction at the real deadline")
	pilot = _senior_pilot(6)
	_expect(pilot.career_dispatch_action("recon"), "Prepare an order during an active military commission")
	for _violation in range(5):
		pilot.career.note_customs_violation(0)
	pilot.update(Fixture.STEP, Vector2.ZERO, 0.0, false, false)
	status = pilot.career_status()
	_expect(not status.order.active and status.factions[0].service_rank == 0 and status.factions[0].service_points == 6
		and not status.offer.allowed and not status.order_offers.recon.allowed and status.factions[1].trust == 0,
		"Loss of trust removes the active commission and preserves the historical service record")


func _senior_pilot(points: int) -> Flight:
	var pilot := Flight.new()
	for _record in range(points):
		assert(pilot.career.note_patrol_accept(0, PORT, true))
		assert(pilot.career.note_patrol_report(PORT))
	return pilot


func _return_to_port(pilot: Flight) -> bool:
	if not pilot.select_target(PORT):
		return false
	pilot.set_autopilot(true)
	for _step in range(145 * 20):
		if pilot.docked == PORT:
			return true
		pilot.update(0.05, Vector2.ZERO, 0.0, false, false)
	return false


func _aim(pilot: Flight, point: Vector3) -> void:
	var direction := pilot.position.direction_to(point)
	pilot.yaw = atan2(-direction.x, -direction.z)
	pilot.pitch = clampf(asin(direction.y), -Flight.MAX_PITCH, Flight.MAX_PITCH)
	pilot.roll = 0.0


func _tap(viewport: SubViewport, button: Button, description: String) -> void:
	if not _expect(button.is_visible_in_tree() and not button.disabled, description):
		return
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 8
		event.pressed = pressed
		event.position = button.get_global_rect().get_center()
		viewport.push_input(event, true)


func _json(state: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(state))


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
