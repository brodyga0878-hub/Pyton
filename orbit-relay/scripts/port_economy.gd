extends RefCounted
## Local tariffs, inventories and offered freight routes.

const Catalog := preload("res://scripts/sector_catalog.gd")
const GOODS := ["ore", "crystal", "ice", "circuits", "medical"]
const MAX_STOCK := 96

const BUY_PRICES := {
	0: {"ore": 23, "crystal": 43, "ice": 17, "circuits": 34, "medical": 68},
	1: {"ore": 25, "crystal": 34, "ice": 32, "circuits": 49, "medical": 54},
	3: {"ore": 34, "crystal": 57, "ice": 26, "circuits": 58, "medical": 74},
	10: {"ore": 32, "crystal": 52, "ice": 21, "circuits": 43, "medical": 42},
	11: {"ore": 38, "crystal": 40, "ice": 37, "circuits": 65, "medical": 77},
}

const SUPPLY_SELL_PRICES := {
	0: {"circuits": 29, "medical": 57},
	1: {"circuits": 43, "medical": 48},
	3: {"circuits": 52, "medical": 67},
	10: {"circuits": 38, "medical": 36},
	11: {"circuits": 55, "medical": 68},
}

const REPAIR_PRICES := {0: 2, 1: 3, 3: 2, 10: 3, 11: 2}

const INITIAL_STOCKS := {
	"0": {"ore": 45, "crystal": 12, "ice": 56, "circuits": 48, "medical": 13},
	"1": {"ore": 31, "crystal": 38, "ice": 9, "circuits": 15, "medical": 38},
	"3": {"ore": 14, "crystal": 8, "ice": 24, "circuits": 11, "medical": 7},
	"10": {"ore": 18, "crystal": 11, "ice": 47, "circuits": 26, "medical": 55},
	"11": {"ore": 8, "crystal": 32, "ice": 7, "circuits": 8, "medical": 9},
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
}

var _stocks := INITIAL_STOCKS.duplicate(true)


static func good_name(good: String) -> String:
	match good:
		"circuits": return "Микросхемы"
		"medical": return "Медикаменты"
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


func restore(value: Variant) -> bool:
	if not value is Dictionary or value.size() != INITIAL_STOCKS.size():
		return false
	var restored := {}
	for port: String in INITIAL_STOCKS:
		var inventory: Variant = value.get(port)
		if not inventory is Dictionary or inventory.size() != GOODS.size():
			return false
		var counts := {}
		for good: String in GOODS:
			var count: Variant = inventory.get(good)
			if not (count is int or count is float) or not is_finite(float(count)):
				return false
			if count < 0 or count > MAX_STOCK or count != floorf(count):
				return false
			counts[good] = int(count)
		restored[port] = counts
	_stocks = restored
	return true
