extends SceneTree

const Catalog := preload("res://scripts/sector_catalog.gd")
const Economy := preload("res://scripts/port_economy.gd")
const Expedition := preload("res://scripts/expedition.gd")
const FactionFronts := preload("res://scripts/faction_fronts.gd")
const Fixture := preload("res://tests/flight_fixture.gd")
const Flight := preload("res://scripts/flight_sim.gd")
const Session := preload("res://scripts/session_io.gd")
const HEATHER := Catalog.HEATHER_SYSTEM
const PORT := Catalog.HEATHER_PORT
const STEP := 1.0 / 30.0

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var flight := _before_declaration()
	if flight != null:
		_test_overdue_front_from_old_save(flight)
		var escort := Flight.new()
		if _expect(escort.restore(flight.snapshot()), "Copy the prewar world for the physical escort scenario"):
			_test_escort_across_boundaries(escort)
		_test_phase_and_production(flight)
	print("Frontier calendar: %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _before_declaration() -> Flight:
	var flight := Flight.new()
	# Start from a legitimate commissioning checkpoint. The first declaration
	# precedes the 600 s supply tick by 0.5 s so one HUD update can cross both.
	_tick(flight, 239.5)
	var state := flight.snapshot()
	state.credits = 5000
	state.expedition.projects[0] = {"phase": Expedition.COMPLETE, "sponsor_port": 0, "sponsor": 0,
		"scan_index": Expedition.SURVEY_TOTAL, "build_index": Expedition.BUILD_TOTAL}
	if not _expect(flight.factions.commission(HEATHER, 0, flight.orbit_time)
			and flight.freight.activate_frontier(HEATHER, flight.orbit_time),
		"The commissioned checkpoint activates exactly one civil freight route"):
		return null
	state.factions = flight.factions.snapshot()
	state.freight = flight.freight.snapshot()
	if not _expect(flight.restore(state) and flight.service_action("tank") and flight.service_action("jump_refuel"),
		"The starter pilot equips and fuels for the physical return to the frontier"):
		return null
	_tick(flight, FactionFronts.FOUNDING_GRACE - 0.5)
	_expect(flight.orbit_time == 599.0 and flight.market_profile(PORT).risk == 2
		and flight.customs_status(HEATHER).authority == 0, "Before the deadline trade follows the founding authority")
	return flight


func _test_overdue_front_from_old_save(flight: Flight) -> void:
	var old := Flight.new()
	if not _expect(old.restore(flight.snapshot()), "Copy the old calendar with its founding deadline"):
		return
	# Older large docked updates could leave a frontier behind the saved clock.
	old._advance_background_clock(10000.0)
	var saved_epoch := old.orbit_time
	var saved := old.snapshot()
	saved.schema = 54
	saved.erase("story_finale")
	var resumed := Flight.new()
	if not _expect(resumed.restore(saved), "Restore a structurally valid old voyage with an overdue frontier"):
		return
	_tick(resumed, 1.0)
	var frontier := resumed.factions.system_state(HEATHER)
	_expect(frontier.stage == "war" and frontier.campaign == 1 and frontier.round == 0
		and frontier.next_at == saved_epoch + FactionFronts.ROUND_SECONDS,
		"An overdue founding event starts its round at the saved clock without replaying missed campaigns")


func _test_phase_and_production(flight: Flight) -> void:
	var saved := "user://frontier-before-declaration.json"
	var split := Flight.new()
	if not _expect(Session.save_state(flight.snapshot(), saved) == OK and split.restore(Session.load_state(saved)),
		"Cold-load the commissioned world before the market and military deadlines"):
		return
	var stock := flight.market.stock(PORT, "grain")
	var peaceful_production := Economy.supply_flow("grain", flight.market_profile(PORT))
	_tick(flight, 2.0)
	_tick(split, 0.75)
	_tick(split, 1.25)
	var wartime_production := Economy.supply_flow("grain", flight.market_profile(PORT))
	_expect(flight.factions.system_state(HEATHER).stage == "war" and wartime_production < peaceful_production
		and flight.market.stock(PORT, "grain") == stock + wartime_production
		and flight.market.snapshot() == split.market.snapshot(),
		"The later production tick uses the declared conflict in both update partitions")
	_expect(flight.freight.snapshot() == split.freight.snapshot() and flight.factions.snapshot() == split.factions.snapshot(),
		"Changing frame partition preserves civic schedules and war convoy orders")
	for _round in range(30):
		if split.factions.owner(HEATHER) == 1:
			break
		_tick(split, 25.0)
	var interval := split.orbit_time - flight.orbit_time
	if not _expect(interval > 0.0 and split.factions.owner(HEATHER) == 1,
		"The military phase reaches conquest while the player stays docked in another system"):
		return
	_tick(flight, interval)
	if not _expect(flight.factions.snapshot() == split.factions.snapshot() and flight.market.snapshot() == split.market.snapshot()
		and flight.freight.snapshot() == split.freight.snapshot(),
		"One long docked update resolves all military boundaries at the same epochs as smaller updates"):
		return
	var frontier_epochs: Array = flight.freight.snapshot().frontier_epochs
	if not _expect(_jump_to_heather(flight) and _dock_at_heather(flight),
		"Physically leave the core, jump and dock at the captured station"):
		return
	var customs := flight.customs_status()
	_expect(customs.authority == 1 and customs.medical_allowance == 4 and customs.available
		and flight.market_quote("weapon_parts", "buy", 1).allowance == 0,
		"The reopened port enforces the new faction's actual market and customs rules")
	_expect(flight.freight.frontier_active(HEATHER) and flight.freight.snapshot().frontier_epochs == frontier_epochs,
		"The civilian route retains its original activation date through capture and travel")
	var quote := flight.market_quote("medical", "buy", 1)
	var balance := flight.credits
	_expect(quote.ok and flight.market_trade("medical", "buy", 1) and flight.credits == balance - int(quote.cost),
		"Buy legal freight under the live authority")
	var arrived := "user://frontier-under-new-authority.json"
	var resumed := Flight.new()
	_expect(Session.save_state(flight.snapshot(), arrived) == OK and resumed.restore(Session.load_state(arrived))
		and resumed.docked == PORT and resumed.customs_status().authority == 1
		and resumed.factions.snapshot() == flight.factions.snapshot()
		and resumed.market.snapshot() == flight.market.snapshot() and resumed.freight.snapshot() == flight.freight.snapshot(),
		"Reload after the transfer without resetting territory, stock or route deadlines")


func _test_escort_across_boundaries(flight: Flight) -> void:
	_tick(flight, 0.75)
	var offer := {}
	for candidate: Dictionary in flight.convoy_offers():
		if candidate.kind == "escort" and int(candidate.system) == HEATHER:
			offer = candidate
			break
	if not _expect(not offer.is_empty() and flight.convoy_action(HEATHER, offer.id) and _jump_to_heather(flight)
			and flight.convoy_action(), "Accept the allied order and follow the convoy after a real jump"):
		return
	for _frame in range(ceili(55.0 / STEP)):
		if flight.convoy_status().phase == "escorted":
			break
		_tick(flight, STEP)
	if not _expect(flight.convoy_status().phase == "escorted" and _dock_at_heather(flight)
			and flight.orbit_time < float(offer.deadline) and flight.convoy_status().phase == "escorted",
		"Fly formation, then dock while the protected convoy is still en route"):
		return
	var saved := "user://frontier-escort-before-delivery.json"
	var resumed := Flight.new()
	if not _expect(Session.save_state(flight.snapshot(), saved) == OK and resumed.restore(Session.load_state(saved)),
		"Cold-load the protected convoy at the real frontier port"):
		return
	var balance := resumed.credits
	var round_end := float(resumed.factions.system_state(HEATHER).next_at)
	_tick(resumed, round_end - resumed.orbit_time + 0.5)
	_expect(resumed.factions.system_state(HEATHER).round == 1 and resumed.convoy_status().phase == "succeeded"
			and resumed.factions.convoy(HEATHER, offer.id).is_empty() and resumed.credits == balance + int(offer.reward),
		"A single docked update pays the arrival before the next turn replaces the delivered convoy")
	_tick(resumed, 1.0)
	_expect(resumed.convoy_status().phase == "succeeded" and resumed.credits == balance + int(offer.reward),
		"Further ticks cannot pay the concluded escort again")
	var capped := Flight.new()
	if _expect(capped.restore(Session.load_state(saved)), "Restore a second copy of the same escort"):
		capped.credits = 999999995
		_tick(capped, round_end - capped.orbit_time + 0.5)
		var confirmed := Flight.new()
		_expect(capped.credits == 1000000000 and capped.convoy_status().phase == "succeeded"
			and confirmed.restore(capped.snapshot()), "Automatic escort payout near the account ceiling keeps a valid completed voyage")


func _jump_to_heather(flight: Flight) -> bool:
	if not flight.plan_jump(HEATHER) or not Fixture.depart(flight):
		return false
	flight.change_throttle(0.18)
	for _frame in range(ceili(30.0 / STEP)):
		if flight.jump_status(HEATHER).ok:
			break
		_tick(flight, STEP)
	if not flight.start_jump():
		return false
	for _frame in range(ceili(4.0 / STEP)):
		if flight.system_id == HEATHER:
			return true
		_tick(flight, STEP)
	return false


func _dock_at_heather(flight: Flight) -> bool:
	if not flight.select_target(PORT):
		return false
	flight.set_autopilot(true)
	if not flight.autopilot:
		return false
	for _frame in range(ceili(180.0 / STEP)):
		if flight.docked == PORT:
			return true
		_tick(flight, STEP)
	return false


func _tick(flight: Flight, delta: float) -> void:
	flight.update(delta, Vector2.ZERO, 0.0, false, false)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
	return condition
