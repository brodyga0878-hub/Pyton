extends RefCounted
## Scheduled local freight moves stock between ports without creating inventory.

const Catalog = preload("res://scripts/sector_catalog.gd")
const Economy = preload("res://scripts/port_economy.gd")
const TRADER_NAMES := ["Торговец «Вектор»", "Торговец «Каскад»"]
const FIRST_DEPARTURES := [28.0, 62.0]
const TRANSIT_SECONDS := 50.0
const LAYOVER_SECONDS := 16.0
const LEG_SECONDS := TRANSIT_SECONDS + LAYOVER_SECONDS
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
]
const SHIP_FIELDS := ["id", "step", "good", "amount", "last_good", "last_delivered"]

var _seed_epoch := 0.0
var _ships: Array[Dictionary] = []
var _next_ship := -1
var _next_epoch := INF


func _init() -> void:
	reset()


func reset(epoch := 0.0) -> void:
	if not _valid_epoch(epoch):
		return
	_seed_epoch = epoch
	_ships.clear()
	for index in range(ROUTES.size()):
		_ships.append({"id": _id(index), "step": 0, "good": "", "amount": 0, "last_good": "", "last_delivered": 0})
	_refresh_schedule()


func advance(market: RefCounted, previous_epoch: float, next_epoch: float) -> void:
	if next_epoch <= previous_epoch or next_epoch < _next_epoch or not _valid_epoch(previous_epoch) or not _valid_epoch(next_epoch):
		return
	if previous_epoch >= _next_epoch:
		# An externally advanced clock should not retrospectively mutate inventories.
		_skip_without_trade(previous_epoch)
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
	if system < 0 or system >= Catalog.CORE_SYSTEM_COUNT or not _valid_epoch(epoch):
		return result
	for slot in range(TRADER_NAMES.size()):
		result.append(_service(system, slot, epoch))
	return result


func status_for(port: int, epoch: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for service: Dictionary in services(Catalog.system_of_site(port), epoch):
		if service.origin == port or service.destination == port:
			result.append(service)
	return result


func snapshot() -> Dictionary:
	return {"seed_epoch": _seed_epoch, "ships": _ships.duplicate(true)}


func restore(raw: Variant, epoch: float) -> bool:
	if not _valid_epoch(epoch) or not raw is Dictionary or raw.size() != 2:
		return false
	var seed: Variant = raw.get("seed_epoch")
	var records: Variant = raw.get("ships")
	if not _valid_epoch(seed) or seed > epoch or not records is Array or records.size() != ROUTES.size():
		return false
	var restored: Array[Dictionary] = []
	for index in range(records.size()):
		var record: Variant = records[index]
		var step := _steps_through(index, epoch, float(seed))
		if not _valid_ship(index, step, record):
			return false
		restored.append({
			"id": _id(index), "step": step, "good": str(record.good), "amount": int(record.amount),
			"last_good": str(record.last_good), "last_delivered": int(record.last_delivered),
		})
	_seed_epoch = float(seed)
	_ships = restored
	_refresh_schedule()
	return true


func _service(system: int, slot: int, epoch: float) -> Dictionary:
	var index := system * TRADER_NAMES.size() + slot
	var ship := _ships[index]
	var step: int = ship.step
	var route: Dictionary = ROUTES[index]
	var leg := _leg_index(step)
	var direction := leg % 2
	var origin: int = route.ports[direction]
	var destination: int = route.ports[1 - direction]
	var in_transit := step % 2 == 1
	var remaining := maxf(0.0, _event_time(index, step, _seed_epoch) - epoch)
	var elapsed := clampf(1.0 - remaining / TRANSIT_SECONDS, 0.0, 1.0) if in_transit else 0.0
	return {
		"id": ship.id, "name": TRADER_NAMES[slot], "system": system, "slot": slot,
		"origin": origin, "destination": destination, "in_transit": in_transit,
		"progress": smoothstep(0.0, 1.0, elapsed),
		"speed_fraction": 6.0 * elapsed * (1.0 - elapsed) / TRANSIT_SECONDS,
		"departure_eta": 0.0 if in_transit else remaining,
		"arrival_eta": remaining if in_transit else remaining + TRANSIT_SECONDS,
		"good": ship.good if ship.amount > 0 else route.goods[direction], "amount": ship.amount,
		"last_port": origin if leg > 0 else -1, "last_good": ship.last_good, "last_delivered": ship.last_delivered,
	}


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
		var ship := _ships[index]
		var step := _steps_through(index, epoch, _seed_epoch)
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
		var due := _event_time(index, int(_ships[index].step), _seed_epoch)
		if due < _next_epoch:
			_next_epoch = due
			_next_ship = index


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
	return seed + float(FIRST_DEPARTURES[index % TRADER_NAMES.size()]) + _leg_index(step) * LEG_SECONDS + (TRANSIT_SECONDS if step % 2 == 1 else 0.0)


static func _leg_index(step: int) -> int:
	return step >> 1


static func _id(index: int) -> String:
	return "trader-%d-%d" % [floori(float(index) / TRADER_NAMES.size()), index % TRADER_NAMES.size()]


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
