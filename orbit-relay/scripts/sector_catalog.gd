extends RefCounted
## Stable site IDs are used by navigation, visuals and saved flights.

const SITE_COUNT := 9
const STAR_ID := SITE_COUNT
const TARGET_COUNT := SITE_COUNT + 1
const STAR_CLEARANCE := 250.0
const SCOOP_INNER := 268.0
const SCOOP_OUTER := 382.0
const SCOOP_SPEED := 38.0
const PORT_IDS := [0, 1, 3]
const MINING_IDS := [2, 4, 5, 6, 7, 8]
const RESOURCES := ["ore", "crystal", "ice"]
const SITES := [
	{"name": "Маяк-7", "kind": "port", "center": Vector3(0, 0, -160), "radius": 32.0, "pad_offset": 8.0, "gate_offset": 70.0, "spin": 0.19, "angle": 0.0, "accent": Color("#5df6c9")},
	{"name": "Тихий порт", "kind": "port", "center": Vector3(330, 65, -870), "radius": 32.0, "pad_offset": 8.0, "gate_offset": 70.0, "spin": -0.27, "angle": 0.55, "accent": Color("#ffb66f")},
	{"name": "Осколок", "kind": "asteroid", "center": Vector3(-215, -70, -415), "radius": 43.0, "pad_offset": 43.0, "gate_offset": 105.0, "seed": 29, "surface_color": Color("#796456"), "accent": Color("#fac974"), "resource": "ore", "reserve": 120, "drill_seconds": 9.0},
	{"name": "Перевал", "kind": "port", "center": Vector3(-550, 90, -1590), "radius": 32.0, "pad_offset": 8.0, "gate_offset": 70.0, "spin": 0.34, "angle": 1.1, "accent": Color("#aab9ff")},
	{"name": "Грань", "kind": "asteroid", "center": Vector3(625, 42, -410), "radius": 54.0, "pad_offset": 54.0, "gate_offset": 116.0, "seed": 45, "surface_color": Color("#6d646d"), "accent": Color("#d5adff"), "resource": "crystal", "reserve": 96, "drill_seconds": 12.0},
	{"name": "Ржавый камень", "kind": "asteroid", "center": Vector3(-830, 35, -740), "radius": 48.0, "pad_offset": 48.0, "gate_offset": 110.0, "seed": 71, "surface_color": Color("#9b624a"), "accent": Color("#ffb389"), "resource": "ore", "reserve": 180, "drill_seconds": 7.0},
	{"name": "Иней", "kind": "moon", "center": Vector3(-990, -105, -1160), "radius": 86.0, "pad_offset": 86.0, "gate_offset": 163.0, "seed": 97, "surface_color": Color("#829bb4"), "accent": Color("#9fe8ff"), "resource": "ice", "reserve": 156, "drill_seconds": 8.0},
	{"name": "Сланец", "kind": "moon", "center": Vector3(1090, -125, -1470), "radius": 105.0, "pad_offset": 105.0, "gate_offset": 182.0, "seed": 113, "surface_color": Color("#586488"), "accent": Color("#d5adff"), "resource": "crystal", "reserve": 132, "drill_seconds": 14.0},
	{"name": "Дымка", "kind": "comet", "center": Vector3(450, 170, -2090), "radius": 68.0, "pad_offset": 68.0, "gate_offset": 142.0, "seed": 137, "surface_color": Color("#517e7e"), "accent": Color("#9fe8ff"), "resource": "ice", "reserve": 216, "drill_seconds": 10.0},
	{"name": "Гелион", "kind": "star", "center": Vector3(2000, 380, -1850), "radius": 220.0, "pad_offset": 310.0, "gate_offset": 470.0, "accent": Color("#ffc778")},
]
const PORT_PRICES := {
	0: {"ore": 20, "crystal": 38, "ice": 14},
	1: {"ore": 20, "crystal": 30, "ice": 27},
	3: {"ore": 29, "crystal": 50, "ice": 22},
}
const FUEL_PRICES := {0: 2, 1: 3, 3: 1}
const ROUTES := {
	0: {1: ["Регуляторы охлаждения", 240], 3: ["Катушки связи", 340]},
	1: {0: ["Калибровочные датчики", 180], 3: ["Оптические блоки", 280]},
	3: {0: ["Контейнеры с фильтрами", 320], 1: ["Сенсоры давления", 260]},
}


static func site(id: int) -> Dictionary:
	return SITES[id] if id >= 0 and id < TARGET_COUNT else {}


static func is_port(id: int) -> bool:
	return id in PORT_IDS


static func kind_name(kind: String) -> String:
	match kind:
		"port": return "Порт"
		"asteroid": return "Астероид"
		"moon": return "Луна"
		"comet": return "Комета"
		"star": return "Звезда"
		_: return ""


static func resource_name(resource: String) -> String:
	match resource:
		"ore": return "Руда"
		"crystal": return "Кристаллы"
		"ice": return "Лёд"
		_: return ""


static func price(port_id: int, resource: String) -> int:
	return PORT_PRICES[port_id].get(resource, 0) if is_port(port_id) else 0

static func refuel_price(port_id: int) -> int:
	return FUEL_PRICES.get(port_id, 0)


static func contract(origin: int, destination: int) -> Array:
	return ROUTES[origin].get(destination, []) if is_port(origin) else []
