extends RefCounted
## Local tariffs, inventories and offered freight routes.

const Catalog := preload("res://scripts/sector_catalog.gd")
const HYDROGEN := "hydrogen"
const PRE_HYDROGEN_GOODS := ["ore", "crystal", "ice", "circuits", "medical"]
const GOODS := ["ore", "crystal", "ice", "circuits", "medical", HYDROGEN]
const MAX_STOCK := 96
const STOCK_PER_PRICE_STEP := 6.0
const MAX_STOCK_PRICE_CHANGE := 8

const BUY_PRICES := {
	0: {"ore": 23, "crystal": 43, "ice": 17, "circuits": 34, "medical": 68, HYDROGEN: 18},
	1: {"ore": 25, "crystal": 34, "ice": 32, "circuits": 49, "medical": 54, HYDROGEN: 25},
	3: {"ore": 34, "crystal": 57, "ice": 26, "circuits": 58, "medical": 74, HYDROGEN: 13},
	10: {"ore": 32, "crystal": 52, "ice": 21, "circuits": 43, "medical": 42, HYDROGEN: 20},
	11: {"ore": 38, "crystal": 40, "ice": 37, "circuits": 65, "medical": 77, HYDROGEN: 27},
	Catalog.FRINGE_ARRIVAL_PORT: {"ore": 30, "crystal": 54, "ice": 33, "circuits": 56, "medical": 72, HYDROGEN: 21},
	Catalog.FRINGE_SECOND_PORT: {"ore": 41, "crystal": 40, "ice": 24, "circuits": 37, "medical": 61, HYDROGEN: 15},
	Catalog.HEATHER_PORT: {"ore": 45, "crystal": 56, "ice": 21, "circuits": 64, "medical": 78, HYDROGEN: 30},
	Catalog.LIMIT_PORT: {"ore": 42, "crystal": 39, "ice": 48, "circuits": 73, "medical": 86, HYDROGEN: 37},
}

const SUPPLY_SELL_PRICES := {
	0: {"circuits": 29, "medical": 57, HYDROGEN: 14},
	1: {"circuits": 43, "medical": 48, HYDROGEN: 20},
	3: {"circuits": 52, "medical": 67, HYDROGEN: 9},
	10: {"circuits": 38, "medical": 36, HYDROGEN: 16},
	11: {"circuits": 55, "medical": 68, HYDROGEN: 22},
	Catalog.FRINGE_ARRIVAL_PORT: {"circuits": 50, "medical": 65, HYDROGEN: 17},
	Catalog.FRINGE_SECOND_PORT: {"circuits": 32, "medical": 52, HYDROGEN: 11},
	Catalog.HEATHER_PORT: {"circuits": 56, "medical": 68, HYDROGEN: 25},
	Catalog.LIMIT_PORT: {"circuits": 63, "medical": 75, HYDROGEN: 31},
}

const REPAIR_PRICES := {
	0: 2, 1: 3, 3: 2, 10: 3, 11: 2, Catalog.FRINGE_ARRIVAL_PORT: 3, Catalog.FRINGE_SECOND_PORT: 2,
	Catalog.HEATHER_PORT: 4, Catalog.LIMIT_PORT: 4,
}

const INITIAL_STOCKS := {
	"0": {"ore": 45, "crystal": 12, "ice": 56, "circuits": 48, "medical": 13, HYDROGEN: 32},
	"1": {"ore": 31, "crystal": 38, "ice": 9, "circuits": 15, "medical": 38, HYDROGEN: 18},
	"3": {"ore": 14, "crystal": 8, "ice": 24, "circuits": 11, "medical": 7, HYDROGEN: 44},
	"10": {"ore": 18, "crystal": 11, "ice": 47, "circuits": 26, "medical": 55, HYDROGEN: 30},
	"11": {"ore": 8, "crystal": 32, "ice": 7, "circuits": 8, "medical": 9, HYDROGEN: 14},
	"16": {"ore": 37, "crystal": 12, "ice": 16, "circuits": 14, "medical": 11, HYDROGEN: 26},
	"17": {"ore": 17, "crystal": 42, "ice": 36, "circuits": 43, "medical": 25, HYDROGEN: 40},
	"20": {"ore": 23, "crystal": 19, "ice": 58, "circuits": 14, "medical": 10, HYDROGEN: 16},
	"24": {"ore": 21, "crystal": 54, "ice": 13, "circuits": 12, "medical": 8, HYDROGEN: 12},
}

const COURIERS := {
	"relay_calibration": {
		"id": "relay_calibration", "origin": 0, "stops": [1, 3], "reward": 570,
		"title": "Калибровка маяков", "cargo": "Калибровочные маяки",
	},
	"instrument_return": {
		"id": "instrument_return", "origin": 1, "stops": [3, 0], "reward": 660,
		"title": "Возврат приборов", "cargo": "Эталонные фотометры",
	},
	"outer_relay": {
		"id": "outer_relay", "origin": 3, "stops": [0, 10, 11], "reward": 1080,
		"title": "Связь с Веларом", "cargo": "Модули телеметрии",
	},
	"geology_archive": {
		"id": "geology_archive", "origin": 10, "stops": [11, 0, 1], "reward": 1050,
		"title": "Геологический архив", "cargo": "Контейнеры с образцами",
	},
	"clinical_supply": {
		"id": "clinical_supply", "origin": 11, "stops": [10, 3], "reward": 790,
		"title": "Снабжение медпункта", "cargo": "Портативные анализаторы",
	},
	"fringe_shuttle": {
		"id": "fringe_shuttle", "origin": Catalog.FRINGE_ARRIVAL_PORT,
		"stops": [Catalog.FRINGE_SECOND_PORT, Catalog.FRINGE_ARRIVAL_PORT], "reward": 620,
		"title": "Сверка сигналов", "cargo": "Регистраторы радиосигналов",
	},
	"fringe_beacons": {
		"id": "fringe_beacons", "origin": Catalog.FRINGE_SECOND_PORT,
		"stops": [Catalog.FRINGE_ARRIVAL_PORT, 10, 11], "reward": 1100,
		"title": "Маяки Кромки", "cargo": "Маячные компенсаторы",
	},
	"heather_cores": {
		"id": "heather_cores", "origin": Catalog.HEATHER_PORT,
		"stops": [Catalog.FRINGE_ARRIVAL_PORT, Catalog.FRINGE_SECOND_PORT], "reward": 1050,
		"title": "Керны Вереска", "cargo": "Кассеты с кернами",
	},
	"limit_telemetry": {
		"id": "limit_telemetry", "origin": Catalog.LIMIT_PORT,
		"stops": [Catalog.FRINGE_SECOND_PORT, 10, 11], "reward": 1440,
		"title": "Архив Предела", "cargo": "Записи дальнего наблюдения",
	},
}

var _stocks := INITIAL_STOCKS.duplicate(true)


static func good_name(good: String) -> String:
	match good:
		"circuits": return "Микросхемы"
		"medical": return "Медикаменты"
		HYDROGEN: return "Водород"
		_: return Catalog.resource_name(good)


static func price(port: int, good: String, side: String) -> int:
	if not BUY_PRICES.has(port):
		return 0
	match side:
		"buy": return BUY_PRICES[port].get(good, 0)
		"sell":
			if good in Catalog.RESOURCES:
				return Catalog.price(port, good)
			return SUPPLY_SELL_PRICES[port].get(good, 0)
		_: return 0


static func repair_price(port: int) -> int:
	return REPAIR_PRICES.get(port, 0)


static func courier_at(port: int) -> Dictionary:
	for route: Dictionary in COURIERS.values():
		if route.origin == port:
			return route.duplicate(true)
	return {}


static func courier(id: String) -> Dictionary:
	return COURIERS[id].duplicate(true) if COURIERS.has(id) else {}


func stock(port: int, good: String) -> int:
	var inventory: Dictionary = _stocks.get(str(port), {})
	return inventory.get(good, 0)


func trade_value(port: int, good: String, side: String, quantity: int) -> int:
	var base := price(port, good, side)
	if base <= 0 or quantity <= 0 or quantity > MAX_STOCK:
		return 0
	var normal_stock := int(INITIAL_STOCKS[str(port)][good])
	var supply := stock(port, good)
	var total := 0
	for index in range(quantity):
		# The same stock levels apply when reversing a buy and sell. The
		# local bid/ask spread therefore applies to every unit of a bulk order.
		var slot := supply - index if side == "buy" else supply + index + 1
		var shortage := normal_stock - clampi(slot, 0, MAX_STOCK)
		var steps := mini(floori(absi(shortage) / STOCK_PER_PRICE_STEP), MAX_STOCK_PRICE_CHANGE)
		total += maxi(1, base + signi(shortage) * steps)
	return total


func change_stock(port: int, good: String, amount: int) -> bool:
	var inventory: Dictionary = _stocks.get(str(port), {})
	if not inventory.has(good):
		return false
	var current: int = inventory[good]
	if amount < -current:
		return false
	inventory[good] = current + mini(amount, MAX_STOCK - current)
	return true


func snapshot() -> Dictionary:
	return _stocks.duplicate(true)


func restore(value: Variant, legacy := false, pre_expansion := false, pre_hydrogen := false) -> bool:
	var cutoff := Catalog.DESTINATION_COUNT
	if legacy:
		cutoff = Catalog.PRE_TRAFFIC_DESTINATION_COUNT
	elif pre_expansion:
		cutoff = Catalog.PRE_EXPANSION_DESTINATION_COUNT
	if not value is Dictionary:
		return false
	var restored := INITIAL_STOCKS.duplicate(true)
	var fields := PRE_HYDROGEN_GOODS if pre_hydrogen else GOODS
	var required_ports := 0
	for port: String in INITIAL_STOCKS:
		if int(port) >= cutoff:
			continue
		required_ports += 1
		var inventory: Variant = value.get(port)
		if not inventory is Dictionary or inventory.size() != fields.size():
			return false
		var counts: Dictionary = restored[port]
		for good: String in fields:
			var count: Variant = inventory.get(good)
			if not (count is int or count is float) or not is_finite(float(count)):
				return false
			if count < 0 or count > MAX_STOCK or count != floorf(count):
				return false
			counts[good] = int(count)
	if value.size() != required_ports:
		return false
	_stocks = restored
	return true
