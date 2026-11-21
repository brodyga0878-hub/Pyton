extends RefCounted
## Scheduled freight moves stock between operational ports without creating inventory.

const Catalog = preload("res://scripts/sector_catalog.gd")
const Economy = preload("res://scripts/port_economy.gd")
const TRADER_NAMES := ["Торговец «Вектор»", "Торговец «Каскад»"]
const FIRST_DEPARTURES := [28.0, 62.0]
const LOCAL_ROUTE_COUNT := 6
const FRONTIER_SYSTEMS := [Catalog.HEATHER_SYSTEM, Catalog.LIMIT_SYSTEM]
const FRONTIER_NAMES := ["Шаттл «Перешеек»", "Шаттл «Меридиан»"]
const FRONTIER_DEPARTURE := 28.0
const TRANSIT_SECONDS := 50.0
const LAYOVER_SECONDS := 16.0
const LEG_SECONDS := TRANSIT_SECONDS + LAYOVER_SECONDS
const LOCAL_TRANSIT_SECONDS := 12.0
const TRACE_RESIDUAL_SECONDS := 26.0
const CAPACITY := 8
const STOCK_FLOOR := 6
const MAX_EPOCH := 3155760000.0
const ROUTES := [
	{"ports": [0, 1], "goods": ["circuits", "crystal"]},
	{"ports": [1, 3], "goods": ["medical", "ice"]},
	{"ports": [10, 11], "goods": ["ice", "crystal"]},
	{"ports": [10, 11], "goods": ["medical", "ore"]},
	{"ports": [Catalog.FRINGE_ARRIVAL_PORT, Catalog.FRINGE_SECOND_PORT], "goods": ["ore", "circuits"]},
	{"ports": [Catalog.FRINGE_SECOND_PORT, Catalog.FRINGE_ARRIVAL_PORT], "goods": ["crystal", "ice"]},
	{"ports": [Catalog.FRINGE_SECOND_PORT, Catalog.HEATHER_PORT], "goods": ["medical", "ice"]},
	{"ports": [Catalog.HEATHER_PORT, Catalog.LIMIT_PORT], "goods": ["circuits", "crystal"]},
]
const SHIP_FIELDS := ["id", "step", "good", "amount", "last_good", "last_delivered"]

var _seed_epoch := 0.0
var _frontier_epochs: Array[float] = [-1.0, -1.0]
var _ships: Array[Dictionary] = []
var _next_ship := -1
var _next_epoch := INF


func _init() -> void:
	reset()


func reset(epoch := 0.0) -> void:
	if not _valid_epoch(epoch):
		return
	_seed_epoch = epoch
	_frontier_epochs.fill(-1.0)
	_ships.clear()
	for index in range(ROUTES.size()):
		_ships.append(_empty_ship(index))
	_refresh_schedule()


func activate_frontier(system: int, epoch: float) -> bool:
	var slot := FRONTIER_SYSTEMS.find(system)
	if slot < 0 or not _valid_epoch(epoch) or epoch < _seed_epoch or _frontier_epochs[slot] >= 0.0:
		return false
	if slot > 0 and (_frontier_epochs[slot - 1] < 0.0 or epoch < _frontier_epochs[slot - 1]):
		return false
	_frontier_epochs[slot] = epoch
	_refresh_schedule()
	return true


func frontier_active(system: int) -> bool:
	var slot := FRONTIER_SYSTEMS.find(system)
	return slot >= 0 and _frontier_epochs[slot] >= 0.0


func advance(market: RefCounted, previous_epoch: float, next_epoch: float) -> void:
	if next_epoch <= previous_epoch or next_epoch < _next_epoch or not _valid_epoch(previous_epoch) or not _valid_epoch(next_epoch):
		return
	var roundtrip_slack := _clock_tolerance(previous_epoch)
	if previous_epoch - _next_epoch > roundtrip_slack:
		# Skip genuine clock gaps but execute a pending event at a rounded save boundary.
		_skip_without_trade(previous_epoch - roundtrip_slack)
	var long_advance := next_epoch - previous_epoch >= LEG_SECONDS * 4.0
	while _next_epoch <= next_epoch:
		if long_advance and not _can_trade(market):
			# No leg can change stock or cargo until the player trades again.
			_skip_without_trade(next_epoch)
			return
		_trade_event(_next_ship, market)
		_refresh_schedule()


func services(system: int, epoch: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if system < 0 or system >= Catalog.SYSTEM_COUNT or not _valid_epoch(epoch):
		return result
	if system < Catalog.CORE_SYSTEM_COUNT:
		for slot in range(TRADER_NAMES.size()):
			result.append(_service(system, slot, epoch))
	for index in range(LOCAL_ROUTE_COUNT, _ships.size()):
		if not _active(index) or epoch < _route_seed(index):
			continue
		var service := _service_for(index, epoch)
		if service.system == system:
			result.append(service)
	return result


func hyperspace_windows(system: int, epoch: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(LOCAL_ROUTE_COUNT, _ships.size()):
		var ship := _ships[index]
		var step := int(ship.step)
		if not _active(index) or step <= 0:
			continue
		var in_transit := step % 2 == 1
		var departure_step := step - (1 if in_transit else 2)
		var depart_at := _event_time(index, departure_step, _route_seed(index)) + LOCAL_TRANSIT_SECONDS
		var arrive_at := depart_at + TRANSIT_SECONDS - 2.0 * LOCAL_TRANSIT_SECONDS
		var remaining := arrive_at + TRACE_RESIDUAL_SECONDS - epoch
		if epoch < depart_at or remaining <= 0.0:
			continue
		var leg := _leg_index(departure_step)
		var direction := leg % 2
		var origin := int(ROUTES[index].ports[direction])
		var destination := int(ROUTES[index].ports[1 - direction])
		var origin_system := Catalog.system_of_site(origin)
		var destination_system := Catalog.system_of_site(destination)
		if system not in [origin_system, destination_system]:
			continue
		var departure := system == origin_system
		var kind := "departure" if departure else ("incoming" if epoch < arrive_at else "residual")
		var cargo := int(ship.amount) + (0 if in_transit else int(ship.last_delivered))
		result.append({"id": "%s-echo-%d-%d" % [ship.id, leg, system], "name": FRONTIER_NAMES[index - LOCAL_ROUTE_COUNT],
			"kind": kind, "origin": origin_system, "destination": destination_system,
			"slot": TRADER_NAMES.size() + index - LOCAL_ROUTE_COUNT, "port": origin if departure else destination,
			"cargo": cargo, "eta": maxf(0.0, arrive_at - epoch) if kind != "residual" else -1.0,
			"remaining": remaining})
	return result


func status_for(port: int, epoch: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _valid_epoch(epoch):
		return result
	for index in range(_ships.size()):
		if _active(index) and epoch >= _route_seed(index) and port in ROUTES[index].ports:
			result.append(_service_for(index, epoch))
	return result


func snapshot() -> Dictionary:
	return {"seed_epoch": _seed_epoch, "ships": _ships.duplicate(true), "frontier_epochs": _frontier_epochs.duplicate()}


func restore(raw: Variant, epoch: float, legacy_frontier := false) -> bool:
	if not _valid_epoch(epoch) or not raw is Dictionary or raw.size() != (2 if legacy_frontier else 3):
		return false
	var seed: Variant = raw.get("seed_epoch")
	var records: Variant = raw.get("ships")
	var count := LOCAL_ROUTE_COUNT if legacy_frontier else ROUTES.size()
	if not _valid_epoch(seed) or seed > epoch or not records is Array or records.size() != count:
		return false
	var frontier_epochs: Array[float] = [-1.0, -1.0]
	if not legacy_frontier:
		var raw_epochs: Variant = raw.get("frontier_epochs")
		if not raw_epochs is Array or raw_epochs.size() != FRONTIER_SYSTEMS.size():
			return false
		for slot in range(raw_epochs.size()):
			var activation: Variant = raw_epochs[slot]
			if activation == -1.0:
				continue
			if not _valid_epoch(activation) or activation < seed or activation > epoch:
				return false
			if slot > 0 and (frontier_epochs[slot - 1] < 0.0 or activation < frontier_epochs[slot - 1]):
				return false
			frontier_epochs[slot] = float(activation)
	var restored: Array[Dictionary] = []
	for index in range(records.size()):
		var record: Variant = records[index]
		var route_seed := float(seed) if index < LOCAL_ROUTE_COUNT else frontier_epochs[index - LOCAL_ROUTE_COUNT]
		var step := _restored_step(index, epoch, route_seed, record)
		if step < 0:
			return false
		if not _valid_ship(index, step, record):
			return false
		restored.append({
			"id": _id(index), "step": step, "good": str(record.good), "amount": int(record.amount),
			"last_good": str(record.last_good), "last_delivered": int(record.last_delivered),
		})
	for index in range(restored.size(), ROUTES.size()):
		restored.append(_empty_ship(index))
	_seed_epoch = float(seed)
	_frontier_epochs = frontier_epochs
	_ships = restored
	_refresh_schedule()
	return true


func _service(system: int, slot: int, epoch: float) -> Dictionary:
	return _service_for(system * TRADER_NAMES.size() + slot, epoch)


func _service_for(index: int, epoch: float) -> Dictionary:
	var ship := _ships[index]
	var step: int = ship.step
	var route: Dictionary = ROUTES[index]
	var leg := _leg_index(step)
	var direction := leg % 2
	var origin: int = route.ports[direction]
	var destination: int = route.ports[1 - direction]
	var in_transit := step % 2 == 1
	var remaining := maxf(0.0, _event_time(index, step, _route_seed(index)) - epoch)
	var seconds := clampf(TRANSIT_SECONDS - remaining, 0.0, TRANSIT_SECONDS) if in_transit else 0.0
	var elapsed := seconds / TRANSIT_SECONDS
	var interstellar := index >= LOCAL_ROUTE_COUNT
	var slot := TRADER_NAMES.size() + index - LOCAL_ROUTE_COUNT if interstellar else index % TRADER_NAMES.size()
	var name: String = FRONTIER_NAMES[index - LOCAL_ROUTE_COUNT] if interstellar else TRADER_NAMES[slot]
	var service := {
		"id": ship.id, "name": name, "system": Catalog.system_of_site(origin), "slot": slot,
		"origin": origin, "destination": destination, "in_transit": in_transit,
		"progress": smoothstep(0.0, 1.0, elapsed),
		"speed_fraction": 6.0 * elapsed * (1.0 - elapsed) / TRANSIT_SECONDS,
		"departure_eta": 0.0 if in_transit else remaining,
		"arrival_eta": remaining if in_transit else remaining + TRANSIT_SECONDS,
		"good": ship.good if ship.amount > 0 else route.goods[direction], "amount": ship.amount,
		"last_port": origin if leg > 0 else -1, "last_good": ship.last_good, "last_delivered": ship.last_delivered,
		"interstellar": interstellar, "visual_phase": "transit" if in_transit else "waiting",
		"local_port": -1 if in_transit else origin, "local_progress": 0.0, "local_speed_fraction": 0.0,
	}
	if interstellar:
		_place_shuttle(service, seconds)
	return service


static func _place_shuttle(service: Dictionary, seconds: float) -> void:
	if not service.in_transit:
		return
	var arriving := seconds >= TRANSIT_SECONDS - LOCAL_TRANSIT_SECONDS
	if seconds >= LOCAL_TRANSIT_SECONDS and not arriving:
		service.visual_phase = "hyperspace"
		service.system = -1
		return
	var local_time := seconds - (TRANSIT_SECONDS - LOCAL_TRANSIT_SECONDS) if arriving else seconds
	var progress := clampf(local_time / LOCAL_TRANSIT_SECONDS, 0.0, 1.0)
	var eased := smoothstep(0.0, 1.0, progress)
	var speed := 6.0 * progress * (1.0 - progress) / LOCAL_TRANSIT_SECONDS
	service.visual_phase = "arrival" if arriving else "departure"
	service.local_port = service.destination if arriving else service.origin
	service.system = Catalog.system_of_site(service.local_port)
	service.local_progress = 1.0 - eased if arriving else eased
	service.local_speed_fraction = -speed if arriving else speed


func _trade_event(index: int, market: RefCounted) -> void:
	var ship := _ships[index]
	var route: Dictionary = ROUTES[index]
	var step: int = ship.step
	var direction := _leg_index(step) % 2
	var origin: int = route.ports[direction]
	var destination: int = route.ports[1 - direction]
	if step % 2 == 0:
		if ship.amount == 0:
			var good: String = route.goods[direction]
			var amount := _pickup_size(market, origin, destination, good)
			if amount > 0 and market.change_stock(origin, good, -amount):
				ship.good = good
				ship.amount = amount
	else:
		ship.last_good = ship.good
		ship.last_delivered = 0
		if ship.amount > 0:
			var unload := mini(int(ship.amount), _free_space(market, destination, ship.good))
			if unload > 0 and market.change_stock(destination, ship.good, unload):
				ship.amount -= unload
				ship.last_delivered = unload
				if ship.amount == 0:
					ship.good = ""
	ship.step = step + 1


func _can_trade(market: RefCounted) -> bool:
	for index in range(_ships.size()):
		if not _active(index):
			continue
		var ship := _ships[index]
		var route: Dictionary = ROUTES[index]
		for direction in range(2):
			var origin: int = route.ports[direction]
			var destination: int = route.ports[1 - direction]
			if ship.amount > 0:
				if _free_space(market, destination, ship.good) > 0:
					return true
			elif _pickup_size(market, origin, destination, route.goods[direction]) > 0:
				return true
	return false


func _skip_without_trade(epoch: float) -> void:
	for index in range(_ships.size()):
		if not _active(index):
			continue
		var ship := _ships[index]
		var step := _steps_through(index, epoch, _route_seed(index))
		if step <= int(ship.step):
			continue
		if _leg_index(step) > _leg_index(ship.step):
			ship.last_good = ship.good
			ship.last_delivered = 0
		ship.step = step
	_refresh_schedule()


func _refresh_schedule() -> void:
	_next_ship = -1
	_next_epoch = INF
	for index in range(_ships.size()):
		if not _active(index):
			continue
		var due := _event_time(index, int(_ships[index].step), _route_seed(index))
		if due < _next_epoch:
			_next_epoch = due
			_next_ship = index


func _active(index: int) -> bool:
	return index < LOCAL_ROUTE_COUNT or _frontier_epochs[index - LOCAL_ROUTE_COUNT] >= 0.0


func _route_seed(index: int) -> float:
	return _seed_epoch if index < LOCAL_ROUTE_COUNT else _frontier_epochs[index - LOCAL_ROUTE_COUNT]


static func _steps_through(index: int, epoch: float, seed: float) -> int:
	var first := _event_time(index, 0, seed)
	if epoch < first:
		return 0
	var departure_step := floori((epoch - first) / LEG_SECONDS) * 2
	# Verify the estimated boundary against the same timestamp used by advance().
	if _event_time(index, departure_step, seed) > epoch:
		departure_step -= 2
	elif _event_time(index, departure_step + 2, seed) <= epoch:
		departure_step += 2
	return departure_step + (2 if _event_time(index, departure_step + 1, seed) <= epoch else 1)


static func _event_time(index: int, step: int, seed: float) -> float:
	var first := FRONTIER_DEPARTURE if index >= LOCAL_ROUTE_COUNT else float(FIRST_DEPARTURES[index % TRADER_NAMES.size()])
	return seed + first + _leg_index(step) * LEG_SECONDS + (TRANSIT_SECONDS if step % 2 == 1 else 0.0)


static func _restored_step(index: int, epoch: float, seed: float, record: Variant) -> int:
	var saved: Variant = record.get("step") if record is Dictionary else null
	if not (saved is int or saved is float):
		return -1
	var expected := _steps_through(index, epoch, seed) if seed >= 0.0 else 0
	if saved == expected:
		return expected
	if seed < 0.0 or saved < 0 or (saved != expected - 1 and saved != expected + 1):
		return -1
	var boundary := _event_time(index, mini(int(saved), expected), seed)
	# The stock update follows the event that actually ran, even if JSON rounded the clock.
	return int(saved) if absf(epoch - boundary) <= _clock_tolerance(epoch) else -1


static func _clock_tolerance(epoch: float) -> float:
	return maxf(1e-10, absf(epoch) * 2e-14)


static func _leg_index(step: int) -> int:
	return step >> 1


static func _id(index: int) -> String:
	if index >= LOCAL_ROUTE_COUNT:
		return "freighter-frontier-%d" % FRONTIER_SYSTEMS[index - LOCAL_ROUTE_COUNT]
	return "trader-%d-%d" % [floori(float(index) / TRADER_NAMES.size()), index % TRADER_NAMES.size()]


static func _empty_ship(index: int) -> Dictionary:
	return {"id": _id(index), "step": 0, "good": "", "amount": 0, "last_good": "", "last_delivered": 0}


static func _pickup_size(market: RefCounted, origin: int, destination: int, good: String) -> int:
	var available := maxi(0, int(market.stock(origin, good)) - STOCK_FLOOR)
	return mini(CAPACITY, mini(available, _free_space(market, destination, good)))


static func _free_space(market: RefCounted, port: int, good: String) -> int:
	return maxi(0, Economy.MAX_STOCK - int(market.stock(port, good)))


static func _valid_epoch(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0.0 and value <= MAX_EPOCH


static func _valid_count(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= CAPACITY and value == floorf(float(value))


static func _valid_ship(index: int, step: int, raw: Variant) -> bool:
	if not raw is Dictionary or raw.size() != SHIP_FIELDS.size() or raw.get("id") != _id(index):
		return false
	if not (raw.get("step") is int or raw.get("step") is float) or raw.step != step:
		return false
	if not _valid_count(raw.get("amount")) or not _valid_count(raw.get("last_delivered")):
		return false
	if not raw.get("good") is String or not raw.get("last_good") is String:
		return false
	var goods: Array = ROUTES[index].goods
	if (raw.amount == 0) != raw.good.is_empty() or (not raw.good.is_empty() and raw.good not in goods):
		return false
	if (raw.last_good.is_empty() and raw.last_delivered > 0) or (not raw.last_good.is_empty() and raw.last_good not in goods):
		return false
	if (step == 0 and raw.amount != 0) or (step < 2 and not raw.last_good.is_empty()):
		return false
	if raw.amount == 0:
		return raw.last_good.is_empty() or raw.last_delivered > 0
	var retained: bool = raw.good == raw.last_good and raw.amount + raw.last_delivered <= CAPACITY
	var must_retain: bool = step % 2 == 0 or (raw.last_delivered == 0 and not raw.last_good.is_empty())
	if must_retain:
		return retained
	return raw.good == goods[_leg_index(step) % 2] or retained
