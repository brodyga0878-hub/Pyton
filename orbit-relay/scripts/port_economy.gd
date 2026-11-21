extends RefCounted
## Local tariffs, inventories and offered freight routes.

const Catalog := preload("res://scripts/sector_catalog.gd")
const HYDROGEN := "hydrogen"
const PRE_HYDROGEN_GOODS := ["ore", "crystal", "ice", "circuits", "medical"]
const LEGACY_GOODS := ["ore", "crystal", "ice", "circuits", "medical", HYDROGEN]
const GOODS := [
	"ore", "crystal", "ice", "circuits", "medical", HYDROGEN,
	"grain", "protein", "rations", "cultures", "textiles", "sterile_kits",
	"alloys", "ceramics", "polymers", "power_cells", "machinery", "robotics",
	"optics", "computers", "instruments", "ecology", "luxuries", "spices",
	"filters", "fertilizer", "coolant", "weapon_parts", "biosamples", "reactor_fuel",
	"scrap", "reactor_waste", "sludge",
]
const GROUPS := ["Основные", "Снабжение", "Промышленность", "Технологии", "Спецгрузы", "Утилизация"]
const GROUP_SIZE := 6
const MAX_HIDDEN_STOCK := 16
const SUPPLY_INTERVAL := 300.0
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
	Catalog.GROUND_PAD: {"ore": 29, "crystal": 46, "ice": 23, "circuits": 57, "medical": 66, HYDROGEN: 19},
	Catalog.GROUND_HANGAR: {"ore": 39, "crystal": 49, "ice": 32, "circuits": 39, "medical": 57, HYDROGEN: 24},
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
	Catalog.GROUND_PAD: {"circuits": 50, "medical": 56, HYDROGEN: 15},
	Catalog.GROUND_HANGAR: {"circuits": 34, "medical": 49, HYDROGEN: 19},
}

const REPAIR_PRICES := {
	0: 2, 1: 3, 3: 2, 10: 3, 11: 2, Catalog.FRINGE_ARRIVAL_PORT: 3, Catalog.FRINGE_SECOND_PORT: 2,
	Catalog.HEATHER_PORT: 4, Catalog.LIMIT_PORT: 4,
	Catalog.GROUND_PAD: 3, Catalog.GROUND_HANGAR: 2,
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
	"87": {"ore": 62, "crystal": 16, "ice": 39, "circuits": 12, "medical": 18, HYDROGEN: 45},
	"88": {"ore": 19, "crystal": 22, "ice": 12, "circuits": 46, "medical": 26, HYDROGEN: 30},
}

const SPECIALTIES := {
	"mining": "Добыча и обогащение",
	"food": "Пищевое производство",
	"industry": "Производство оборудования",
	"research": "Исследования и медицина",
	"transit": "Перевалка и снабжение",
	"recycling": "Переработка и утилизация",
}
# Port functions coexist inside a settled system.
const PORT_SPECIALTIES := {
	0: "industry", 1: "food", 3: "mining", 10: "research", 11: "transit",
	Catalog.FRINGE_ARRIVAL_PORT: "transit", Catalog.FRINGE_SECOND_PORT: "recycling",
	Catalog.HEATHER_PORT: "food", Catalog.LIMIT_PORT: "mining",
	Catalog.GROUND_PAD: "food", Catalog.GROUND_HANGAR: "industry",
}
const NEW_GOODS := {
	"grain": {"name": "Зерно", "price": 24, "source": "food", "buyer": "transit", "use": "Пищевое сырьё для снабжения экипажей."},
	"protein": {"name": "Белковые смеси", "price": 33, "source": "food", "buyer": "research", "use": "Основа медицинских и пищевых смесей."},
	"rations": {"name": "Рационы", "price": 38, "source": "food", "buyer": "mining", "use": "Запасы для дальних добывающих смен."},
	"cultures": {"name": "Биокультуры", "price": 54, "source": "research", "buyer": "food", "use": "Закваски для тепличных и пищевых линий."},
	"textiles": {"name": "Техноткань", "price": 33, "source": "industry", "buyer": "transit", "use": "Ремонт скафандров и грузовых оболочек."},
	"sterile_kits": {"name": "Стерильные наборы", "price": 53, "source": "research", "buyer": "transit", "use": "Оснащение перевалочных медпунктов."},
	"alloys": {"name": "Сплавы", "price": 47, "source": "mining", "buyer": "industry", "use": "Сырьё для несущих деталей и обшивки."},
	"ceramics": {"name": "Керамика", "price": 41, "source": "mining", "buyer": "industry", "use": "Изоляторы и жаропрочные облицовки."},
	"polymers": {"name": "Полимеры", "price": 35, "source": "recycling", "buyer": "industry", "use": "Уплотнители, трубки и сменная тара."},
	"power_cells": {"name": "Энергоячейки", "price": 66, "source": "industry", "buyer": "transit", "use": "Питание маяков и грузовых механизмов."},
	"machinery": {"name": "Станки", "price": 83, "source": "industry", "buyer": "recycling", "use": "Оснастка для сортировки и переработки."},
	"robotics": {"name": "Роботехника", "price": 106, "source": "industry", "buyer": "mining", "use": "Удалённая работа в шахтах и карьерах."},
	"optics": {"name": "Оптика", "price": 68, "source": "research", "buyer": "industry", "use": "Линзы сканеров и производственных датчиков."},
	"computers": {"name": "Вычислители", "price": 90, "source": "industry", "buyer": "research", "use": "Вычислительные блоки лабораторий."},
	"instruments": {"name": "Приборы", "price": 79, "source": "research", "buyer": "mining", "use": "Полевые измерения и разведка залежей."},
	"ecology": {"name": "Агромодули", "price": 74, "source": "industry", "buyer": "food", "use": "Контроль питания культур на фермах."},
	"luxuries": {"name": "Изделия мастеров", "price": 102, "source": "transit", "buyer": "research", "use": "Редкие изделия для рынков больших поселений."},
	"spices": {"name": "Пряности", "price": 59, "source": "food", "buyer": "transit", "use": "Дорогие добавки к дорожным рационам."},
	"filters": {"name": "Фильтры", "price": 39, "source": "industry", "buyer": "recycling", "use": "Очистка воздуха и производственных стоков."},
	"fertilizer": {"name": "Удобрения", "price": 26, "source": "recycling", "buyer": "food", "use": "Питание тепличных посадок."},
	"coolant": {"name": "Охладители", "price": 52, "source": "mining", "buyer": "industry", "use": "Рабочие жидкости станков и теплообменников."},
	"weapon_parts": {"name": "Оружейные узлы", "price": 116, "source": "industry", "buyer": "transit", "use": "Комплектующие оборонных систем."},
	"biosamples": {"name": "Биообразцы", "price": 101, "source": "research", "buyer": "food", "use": "Образцы для контролируемого карантина."},
	"reactor_fuel": {"name": "Реакторное топливо", "price": 133, "source": "mining", "buyer": "research", "use": "Силовые установки портов."},
	"scrap": {"name": "Металлолом", "price": 15, "source": "industry", "buyer": "recycling", "use": "Вторичное сырьё для перерабатывающих линий."},
	"reactor_waste": {"name": "Реакторные отходы", "price": -24, "source": "research", "buyer": "recycling", "use": "Оплачиваемый вывоз и платная утилизация."},
	"sludge": {"name": "Загрязнённый шлам", "price": -16, "source": "industry", "buyer": "recycling", "use": "Отходы фильтрации, требующие приёмки."},
}
const ALLOWANCES := {
	"medical": [-1, 4],
	"weapon_parts": [3, 0],
	"biosamples": [0, 3],
	"reactor_fuel": [2, 0],
}
const CONTACTS := {
	3: {"name": "Перевалочный диспетчер", "goods": ["weapon_parts", "biosamples"]},
	10: {"name": "Поставщик лабораторий", "goods": ["medical", "biosamples", "reactor_fuel"]},
	11: {"name": "Агент складского ряда", "goods": ["medical", "weapon_parts", "reactor_fuel"]},
	Catalog.FRINGE_SECOND_PORT: {"name": "Приёмщик старого дока", "goods": ["weapon_parts", "biosamples", "reactor_fuel"]},
	Catalog.HEATHER_PORT: {"name": "Представитель каравана", "goods": ["medical", "biosamples", "reactor_fuel"]},
	Catalog.LIMIT_PORT: {"name": "Дальний снабженец", "goods": ["medical", "weapon_parts", "reactor_fuel"]},
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
	"slope_samples": {
		"id": "slope_samples", "origin": Catalog.GROUND_PAD, "stops": [11, 10], "reward": 690,
		"title": "Сверка проб Лазури", "cargo": "Контрольные кассеты",
	},
	"lazur_workshop": {
		"id": "lazur_workshop", "origin": Catalog.GROUND_HANGAR, "stops": [Catalog.GROUND_PAD, 10], "reward": 650,
		"title": "Посылка из мастерской", "cargo": "Сменные клапаны",
	},
}

var _stocks := _initial_stock()
var _hidden_stocks := _initial_hidden_stock()


static func good_name(good: String) -> String:
	match good:
		"circuits": return "Микросхемы"
		"medical": return "Медикаменты"
		HYDROGEN: return "Водород"
		_: return str(NEW_GOODS[good].name) if NEW_GOODS.has(good) else Catalog.resource_name(good)


static func good_use(good: String) -> String:
	return str(NEW_GOODS[good].use) if NEW_GOODS.has(good) else ""


static func goods_for_group(group: int) -> Array:
	return GOODS.slice(group * GROUP_SIZE, (group + 1) * GROUP_SIZE)


static func allowance(authority: int, good: String) -> int:
	return int(ALLOWANCES[good][authority]) if authority in [0, 1] and ALLOWANCES.has(good) else -1


static func profile(port: int, owner: int, settlements: int, pressure: int, contested: bool) -> Dictionary:
	if not PORT_SPECIALTIES.has(port):
		return {}
	var place := str(PORT_SPECIALTIES[port])
	var developed := Catalog.system_of_site(port) < Catalog.CORE_SYSTEM_COUNT
	var hazard := (0 if developed else 2) + (3 + pressure / 20 if contested else 0)
	return {"specialty": place, "label": SPECIALTIES[place], "owner": owner,
		"settlements": settlements, "risk": int(hazard)}


static func supply_flow(good: String, local: Dictionary) -> int:
	if not NEW_GOODS.has(good) or local.is_empty():
		return 0
	var item: Dictionary = NEW_GOODS[good]
	var producer: bool = local.specialty == item.source
	var buyer: bool = local.specialty == item.buyer
	var production := 2 + int(local.settlements) if producer else 0
	var demand := 2 + (int(local.settlements) + 1) / 2 if buyer else 0
	if producer and int(local.risk) >= 4:
		production = maxi(1, production - 2)
	return production - demand


static func contact(port: int, owner: int) -> Dictionary:
	if not CONTACTS.has(port):
		return {}
	var available: Array[String] = []
	for good: String in CONTACTS[port].goods:
		if allowance(owner, good) >= 0:
			available.append(good)
	return {} if available.is_empty() else {"name": CONTACTS[port].name, "goods": available}


static func price(port: int, good: String, side: String, local: Dictionary = {}) -> int:
	if not BUY_PRICES.has(port) or side not in ["buy", "sell"]:
		return 0
	if good in LEGACY_GOODS:
		if side == "buy":
			return BUY_PRICES[port].get(good, 0)
		return Catalog.price(port, good) if good in Catalog.RESOURCES else SUPPLY_SELL_PRICES[port].get(good, 0)
	if not NEW_GOODS.has(good):
		return 0
	if local.is_empty():
		local = _default_profile(port)
	var item: Dictionary = NEW_GOODS[good]
	var tagged := int(item.price)
	var spread := maxi(3, roundi(absi(tagged) * 0.07))
	var flow := supply_flow(good, local)
	var fair := tagged - signi(flow) * (maxi(5, absi(tagged) / 5) + absi(flow))
	if int(local.owner) == 1 and (allowance(1, good) >= 0 or item.source == "research"):
		fair += spread
	if tagged < 0:
		fair += mini(int(local.risk), 6) * signi(flow) * -1
		return mini(-spread - 1, fair) + (spread if side == "buy" else -spread)
	fair += int(local.risk) * (2 if flow < 0 else 1)
	return maxi(spread + 1, fair) + (spread if side == "buy" else -spread)


static func repair_price(port: int) -> int:
	return REPAIR_PRICES.get(port, 0)


static func courier_at(port: int) -> Dictionary:
	for route: Dictionary in COURIERS.values():
		if route.origin == port:
			return route.duplicate(true)
	return {}


static func courier(id: String) -> Dictionary:
	return COURIERS[id].duplicate(true) if COURIERS.has(id) else {}


func stock(port: int, good: String, hidden := false) -> int:
	var inventory: Dictionary = (_hidden_stocks if hidden else _stocks).get(str(port), {})
	return inventory.get(good, 0)


func trade_value(port: int, good: String, side: String, quantity: int, local: Dictionary = {}, hidden := false) -> int:
	var capacity := MAX_HIDDEN_STOCK if hidden else MAX_STOCK
	if quantity <= 0 or quantity > capacity:
		return 0
	var base := price(port, good, side, local)
	if hidden:
		if local.is_empty() or not contact(port, int(local.owner)).get("goods", []).has(good):
			return 0
		var risk := int(local.risk)
		base = ceili(base * (1.45 if side == "buy" else 1.27)) + (12 if side == "buy" else 2) + risk * 3
	if base == 0:
		return 0
	var normal_stock := _hidden_initial(port, good) if hidden else _initial_count(port, good)
	var supply := stock(port, good, hidden)
	var total := 0
	for index in range(quantity):
		# Reversing a transaction quotes both sides at the same inventory levels.
		var slot := supply - index if side == "buy" else supply + index + 1
		var shortage := normal_stock - clampi(slot, 0, capacity)
		var step_size := 2.0 if hidden else STOCK_PER_PRICE_STEP
		var steps := mini(floori(absi(shortage) / step_size), MAX_STOCK_PRICE_CHANGE)
		var quote := base + signi(shortage) * steps
		total += maxi(1, quote) if base > 0 else mini(-1, quote)
	return total


func change_stock(port: int, good: String, amount: int, hidden := false) -> bool:
	var inventory: Dictionary = (_hidden_stocks if hidden else _stocks).get(str(port), {})
	if not inventory.has(good):
		return false
	var current: int = inventory[good]
	if amount < -current:
		return false
	var capacity := MAX_HIDDEN_STOCK if hidden else MAX_STOCK
	inventory[good] = current + mini(amount, capacity - current)
	return true


func advance(previous_epoch: float, next_epoch: float, sim: RefCounted) -> void:
	var intervals := floori(next_epoch / SUPPLY_INTERVAL) - floori(previous_epoch / SUPPLY_INTERVAL)
	if intervals <= 0:
		return
	for key: String in _stocks:
		var port := int(key)
		if not sim.station_operational(port):
			continue
		var local: Dictionary = sim.market_profile(port)
		var inventory: Dictionary = _stocks[key]
		for good: String in NEW_GOODS:
			inventory[good] = clampi(int(inventory[good]) + intervals * supply_flow(good, local), 0, MAX_STOCK)


func snapshot() -> Dictionary:
	return _stocks.duplicate(true)


func hidden_snapshot() -> Dictionary:
	return _hidden_stocks.duplicate(true)


func restore(value: Variant, legacy := false, pre_expansion := false, pre_hydrogen := false,
		pre_ground_ports := false, pre_assortment := false, hidden: Variant = null) -> bool:
	var cutoff := Catalog.DESTINATION_COUNT
	if legacy:
		cutoff = Catalog.PRE_TRAFFIC_DESTINATION_COUNT
	elif pre_expansion:
		cutoff = Catalog.PRE_EXPANSION_DESTINATION_COUNT
	elif pre_ground_ports:
		cutoff = Catalog.PRE_GROUND_DESTINATION_COUNT
	if not value is Dictionary:
		return false
	var restored := _initial_stock()
	var fields := GOODS
	if pre_hydrogen:
		fields = PRE_HYDROGEN_GOODS
	elif pre_assortment:
		fields = LEGACY_GOODS
	var required_ports := 0
	for port: String in restored:
		if int(port) >= cutoff:
			continue
		required_ports += 1
		var inventory: Variant = value.get(port)
		if not _restore_inventory(inventory, fields, restored[port], MAX_STOCK):
			return false
	if value.size() != required_ports:
		return false
	var contacts := _initial_hidden_stock()
	if not pre_assortment:
		if not hidden is Dictionary or hidden.size() != contacts.size():
			return false
		for port: String in contacts:
			if not _restore_inventory(hidden.get(port), CONTACTS[int(port)].goods, contacts[port], MAX_HIDDEN_STOCK):
				return false
	_stocks = restored
	_hidden_stocks = contacts
	return true


static func _restore_inventory(raw: Variant, fields: Array, destination: Dictionary, capacity: int) -> bool:
	if not raw is Dictionary or raw.size() != fields.size():
		return false
	for good: String in fields:
		var count: Variant = raw.get(good)
		if not (count is int or count is float) or not is_finite(float(count)):
			return false
		if count < 0 or count > capacity or count != floorf(count):
			return false
		destination[good] = int(count)
	return true


static func _initial_stock() -> Dictionary:
	var inventories := INITIAL_STOCKS.duplicate(true)
	for port: String in inventories:
		for good: String in NEW_GOODS:
			inventories[port][good] = _initial_count(int(port), good)
	return inventories


static func _initial_count(port: int, good: String) -> int:
	if not NEW_GOODS.has(good):
		return int(INITIAL_STOCKS[str(port)].get(good, 0))
	var local := _default_profile(port)
	var supply := supply_flow(good, local)
	return 24 + supply * 3 + ((port * 11 + GOODS.find(good) * 7) % 9)


static func _default_profile(port: int) -> Dictionary:
	var system := Catalog.system_of_site(port)
	return profile(port, 1 if system == Catalog.VELAR_SYSTEM else 0, Catalog.ports_for(system).size(), 0, false)


static func _initial_hidden_stock() -> Dictionary:
	var inventories := {}
	for port: int in CONTACTS:
		var stock := {}
		for good: String in CONTACTS[port].goods:
			stock[good] = _hidden_initial(port, good)
		inventories[str(port)] = stock
	return inventories


static func _hidden_initial(port: int, good: String) -> int:
	return 4 + (port * 3 + GOODS.find(good) * 7) % 8
