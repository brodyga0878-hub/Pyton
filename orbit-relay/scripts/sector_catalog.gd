extends RefCounted
## Stable site IDs are used by navigation, visuals and saved flights.

const ProceduralSystems = preload("res://scripts/procedural_systems.gd")
const SECTOR_SIZE := ProceduralSystems.SECTOR_SIZE
const GENERATED_SCAN_RANGE := 10.5
const GENERATED_SYSTEM_COUNT := ProceduralSystems.SINGLE_SYSTEM_COUNT + 1
const SITE_COUNT := 9
const STAR_ID := SITE_COUNT
const TARGET_COUNT := SITE_COUNT + 1
const HOME_SYSTEM := 0
const VELAR_SYSTEM := 1
const PRE_TRAFFIC_SYSTEM_COUNT := 2
const FRINGE_SYSTEM := PRE_TRAFFIC_SYSTEM_COUNT
const CORE_SYSTEM_COUNT := PRE_TRAFFIC_SYSTEM_COUNT + 1
const HEATHER_SYSTEM := CORE_SYSTEM_COUNT
const LIMIT_SYSTEM := HEATHER_SYSTEM + 1
const AUTHORED_SYSTEM_COUNT := LIMIT_SYSTEM + 1
const PRE_BINARY_SYSTEM_COUNT := AUTHORED_SYSTEM_COUNT + ProceduralSystems.SINGLE_SYSTEM_COUNT
const BINARY_SYSTEM := PRE_BINARY_SYSTEM_COUNT
const SYSTEM_COUNT := AUTHORED_SYSTEM_COUNT + GENERATED_SYSTEM_COUNT
const PRE_SURFACE_DESTINATION_COUNT := 15
const PRE_TRAFFIC_DESTINATION_COUNT := PRE_SURFACE_DESTINATION_COUNT + 1
const PRE_EXPANSION_DESTINATION_COUNT := PRE_TRAFFIC_DESTINATION_COUNT + 4
const PRE_GAS_DESTINATION_COUNT := PRE_EXPANSION_DESTINATION_COUNT + 8
const GAS_GIANT_ID := PRE_GAS_DESTINATION_COUNT
const AUTHORED_DESTINATION_COUNT := GAS_GIANT_ID + 1
const PRE_BINARY_DESTINATION_COUNT := AUTHORED_DESTINATION_COUNT + ProceduralSystems.SINGLE_SYSTEM_COUNT * ProceduralSystems.TARGETS_PER_SYSTEM
const BINARY_PRIMARY := PRE_BINARY_DESTINATION_COUNT
const BINARY_SECONDARY := BINARY_PRIMARY + 1
const BINARY_PLANET := BINARY_SECONDARY + 1
const BINARY_MOON := BINARY_PLANET + 1
const DESTINATION_COUNT := BINARY_MOON + 1
const VELAR_STAR_ID := 14
const TERRACE_ID := PRE_SURFACE_DESTINATION_COUNT
const FRINGE_ARRIVAL_PORT := PRE_TRAFFIC_DESTINATION_COUNT
const FRINGE_SECOND_PORT := FRINGE_ARRIVAL_PORT + 1
const FRINGE_ASTEROID_ID := FRINGE_SECOND_PORT + 1
const FRINGE_STAR_ID := FRINGE_ASTEROID_ID + 1
const HEATHER_PORT := PRE_EXPANSION_DESTINATION_COUNT
const HEATHER_PLANET := HEATHER_PORT + 1
const HEATHER_MOON := HEATHER_PORT + 2
const HEATHER_STAR := HEATHER_PORT + 3
const LIMIT_PORT := HEATHER_PORT + 4
const LIMIT_PLANET := LIMIT_PORT + 1
const LIMIT_ASTEROID := LIMIT_PORT + 2
const LIMIT_STAR := LIMIT_PORT + 3
const JUMP_FUEL := 26
const JUMP_COSTS := [
	[0, JUMP_FUEL, 36, 48, 66],
	[JUMP_FUEL, 0, 19, 25, 42],
	[36, 19, 0, 19, 36],
	[48, 25, 19, 0, 18],
	[66, 42, 36, 18, 0],
]
const STAR_CLEARANCE := 250.0
const SCOOP_INNER := 268.0
const SCOOP_OUTER := 382.0
const SCOOP_SPEED := 38.0
const PORT_IDS := [0, 1, 3]
const MINING_IDS := [2, 4, 5, 6, 7, 8]
const SYSTEMS := [
	{
		"name": "Гелион", "position": Vector2.ZERO, "accent": Color("#ffc778"),
		"description": "Три порта, шесть месторождений, жёлтая звезда и газовый гигант «Янтарь».",
		"arrival_port": 0, "targets": [0, 1, 2, 3, 4, 5, 6, 7, 8, STAR_ID, GAS_GIANT_ID], "ports": PORT_IDS,
		"mines": MINING_IDS, "star": STAR_ID, "gas_giant": GAS_GIANT_ID, "stellar_heat": 1.0,
	},
	{
		"name": "Велар", "position": Vector2(3.6, -2.2), "accent": Color("#9dcaff"),
		"description": "Голубая звезда, два порта, ледяная луна, залежи кристаллов и скальная планета «Терраса».",
		"arrival_port": 10, "targets": [10, 11, 12, 13, VELAR_STAR_ID, TERRACE_ID], "ports": [10, 11],
		"mines": [12, 13, TERRACE_ID], "star": VELAR_STAR_ID, "stellar_heat": 1.16,
	},
	{
		"name": "Кромка", "position": Vector2(5.7, 0.15), "accent": Color("#ffc2a4"),
		"description": "Два перевалочных порта и астероид «Рубец» с месторождением кристаллов.",
		"arrival_port": FRINGE_ARRIVAL_PORT,
		"targets": [FRINGE_ARRIVAL_PORT, FRINGE_SECOND_PORT, FRINGE_ASTEROID_ID, FRINGE_STAR_ID],
		"ports": [FRINGE_ARRIVAL_PORT, FRINGE_SECOND_PORT],
		"mines": [FRINGE_ASTEROID_ID], "star": FRINGE_STAR_ID, "stellar_heat": 0.89,
	},
	{
		"name": "Вереск", "position": Vector2(7.7, -2.5), "accent": Color("#b9e4af"),
		"description": "Каменистый Ковыль и ледяная луна Ломь. На орбите предусмотрено место для форпоста.",
		"arrival_port": HEATHER_PORT, "construction_port": HEATHER_PORT, "frontier": true,
		"survey_sites": [HEATHER_PLANET, HEATHER_MOON],
		"targets": [HEATHER_PORT, HEATHER_PLANET, HEATHER_MOON, HEATHER_STAR], "ports": [HEATHER_PORT],
		"mines": [HEATHER_PLANET, HEATHER_MOON], "star": HEATHER_STAR, "stellar_heat": 0.95,
	},
	{
		"name": "Предел", "position": Vector2(10.1, -4.0), "accent": Color("#ddbfff"),
		"description": "Скальная Северина и кристаллическая Стежка. Дальний узел рассчитан на межзвёздные рейсы.",
		"arrival_port": LIMIT_PORT, "construction_port": LIMIT_PORT, "frontier": true,
		"survey_sites": [LIMIT_PLANET, LIMIT_ASTEROID],
		"targets": [LIMIT_PORT, LIMIT_PLANET, LIMIT_ASTEROID, LIMIT_STAR], "ports": [LIMIT_PORT],
		"mines": [LIMIT_PLANET, LIMIT_ASTEROID], "star": LIMIT_STAR, "stellar_heat": 1.12,
	},
]
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
	{"name": "Створ", "kind": "port", "center": Vector3(0, 0, -160), "radius": 32.0, "pad_offset": 8.0, "gate_offset": 70.0, "spin": -0.23, "angle": 0.74, "accent": Color("#76bcff")},
	{"name": "Гранитный причал", "kind": "port", "center": Vector3(-540, 110, -1080), "radius": 32.0, "pad_offset": 8.0, "gate_offset": 70.0, "spin": 0.29, "angle": 1.85, "accent": Color("#f2ab8d")},
	{"name": "Лазурь", "kind": "moon", "center": Vector3(620, -95, -880), "radius": 98.0, "pad_offset": 98.0, "gate_offset": 174.0, "seed": 163, "surface_color": Color("#658bad"), "accent": Color("#83dfff"), "resource": "ice", "reserve": 192, "drill_seconds": 11.0},
	{"name": "Просека", "kind": "asteroid", "center": Vector3(-260, -165, -590), "radius": 60.0, "pad_offset": 60.0, "gate_offset": 132.0, "seed": 181, "surface_color": Color("#475c5d"), "accent": Color("#98eab5"), "resource": "crystal", "reserve": 144, "drill_seconds": 13.0},
	{"name": "Велар", "kind": "star", "center": Vector3(1800, 280, -1600), "radius": 220.0, "pad_offset": 310.0, "gate_offset": 470.0, "accent": Color("#9dcaff")},
	{"name": "Терраса", "kind": "planet", "center": Vector3(1580, -340, -1180), "radius": 170.0, "pad_offset": 170.0, "gate_offset": 280.0, "seed": 223, "surface_color": Color("#936a55"), "accent": Color("#f3bf85"), "resource": "ore", "reserve": 240, "drill_seconds": 15.0},
	{"name": "Рубеж", "kind": "port", "center": Vector3(0, 0, -160), "radius": 32.0, "pad_offset": 8.0, "gate_offset": 70.0, "spin": 0.26, "angle": 0.50, "accent": Color("#f4a987")},
	{"name": "Свод", "kind": "port", "center": Vector3(-950, 130, -1240), "radius": 32.0, "pad_offset": 8.0, "gate_offset": 70.0, "spin": -0.32, "angle": 1.48, "accent": Color("#8fded1")},
	{"name": "Рубец", "kind": "asteroid", "center": Vector3(740, -210, -1170), "radius": 72.0, "pad_offset": 72.0, "gate_offset": 149.0, "seed": 269, "surface_color": Color("#74677c"), "accent": Color("#ffc5f0"), "resource": "crystal", "reserve": 180, "drill_seconds": 12.0},
	{"name": "Кромка", "kind": "star", "center": Vector3(1720, 310, -1600), "radius": 220.0, "pad_offset": 310.0, "gate_offset": 470.0, "accent": Color("#ffc2a4")},
	{"name": "Форпост Вереска", "kind": "port", "center": Vector3(0, 0, -160), "radius": 32.0, "pad_offset": 8.0, "gate_offset": 70.0, "spin": 0.24, "angle": 2.12, "accent": Color("#addda1")},
	{"name": "Ковыль", "kind": "planet", "center": Vector3(950, -225, -985), "radius": 146.0, "pad_offset": 146.0, "gate_offset": 254.0, "seed": 419, "surface_color": Color("#837658"), "accent": Color("#dcc386"), "resource": "ore", "reserve": 276, "drill_seconds": 14.0},
	{"name": "Ломь", "kind": "moon", "center": Vector3(1580, 90, -1670), "radius": 78.0, "pad_offset": 78.0, "gate_offset": 153.0, "seed": 427, "surface_color": Color("#739b9f"), "accent": Color("#a0e8d9"), "resource": "ice", "reserve": 168, "drill_seconds": 9.0},
	{"name": "Вереск", "kind": "star", "center": Vector3(2350, 160, -1650), "radius": 220.0, "pad_offset": 310.0, "gate_offset": 470.0, "accent": Color("#b9e4af")},
	{"name": "Дальний узел", "kind": "port", "center": Vector3(0, 0, -160), "radius": 32.0, "pad_offset": 8.0, "gate_offset": 70.0, "spin": -0.19, "angle": 1.1, "accent": Color("#d5bbf3")},
	{"name": "Северина", "kind": "planet", "center": Vector3(860, -250, -1050), "radius": 143.0, "pad_offset": 143.0, "gate_offset": 257.0, "seed": 503, "surface_color": Color("#766b8f"), "accent": Color("#cbc2f5"), "resource": "ore", "reserve": 252, "drill_seconds": 13.0},
	{"name": "Стежка", "kind": "asteroid", "center": Vector3(1490, 110, -1800), "radius": 67.0, "pad_offset": 67.0, "gate_offset": 143.0, "seed": 509, "surface_color": Color("#71697e"), "accent": Color("#e5b9fa"), "resource": "crystal", "reserve": 216, "drill_seconds": 15.0},
	{"name": "Предел", "kind": "star", "center": Vector3(2320, 265, -1775), "radius": 220.0, "pad_offset": 310.0, "gate_offset": 470.0, "accent": Color("#ddbfff")},
	{"name": "Янтарь", "kind": "gas", "center": Vector3(-2380, -680, -3970), "radius": 460.0, "pad_offset": 505.0, "gate_offset": 650.0, "accent": Color("#efb082")},
]
const PORT_PRICES := {
	0: {"ore": 20, "crystal": 38, "ice": 14},
	1: {"ore": 20, "crystal": 30, "ice": 27},
	3: {"ore": 29, "crystal": 50, "ice": 22},
	10: {"ore": 27, "crystal": 46, "ice": 17},
	11: {"ore": 33, "crystal": 35, "ice": 32},
	FRINGE_ARRIVAL_PORT: {"ore": 25, "crystal": 48, "ice": 25},
	FRINGE_SECOND_PORT: {"ore": 35, "crystal": 36, "ice": 19},
	HEATHER_PORT: {"ore": 38, "crystal": 49, "ice": 16},
	LIMIT_PORT: {"ore": 35, "crystal": 32, "ice": 41},
}
const FUEL_PRICES := {
	0: 2, 1: 3, 3: 1, 10: 2, 11: 3, FRINGE_ARRIVAL_PORT: 2, FRINGE_SECOND_PORT: 1,
	HEATHER_PORT: 3, LIMIT_PORT: 4,
}
const ROUTES := {
	0: {1: ["Регуляторы охлаждения", 240], 3: ["Катушки связи", 340]},
	1: {0: ["Калибровочные датчики", 180], 3: ["Оптические блоки", 280]},
	3: {0: ["Контейнеры с фильтрами", 320], 1: ["Сенсоры давления", 260]},
	10: {11: ["Теплообменники", 270]},
	11: {10: ["Защитные экраны", 230]},
	FRINGE_ARRIVAL_PORT: {FRINGE_SECOND_PORT: ["Ретрансляторы", 290]},
	FRINGE_SECOND_PORT: {FRINGE_ARRIVAL_PORT: ["Запасные гироскопы", 260]},
	HEATHER_PORT: {FRINGE_ARRIVAL_PORT: ["Геологические пробы", 540]},
	LIMIT_PORT: {FRINGE_SECOND_PORT: ["Сводка дальнего наблюдения", 680]},
}

static var _generated := ProceduralSystems.build(AUTHORED_DESTINATION_COUNT)


static func site(id: int) -> Dictionary:
	if id < 0 or id >= DESTINATION_COUNT:
		return {}
	if id < AUTHORED_DESTINATION_COUNT:
		return SITES[id]
	return _generated.sites[id - AUTHORED_DESTINATION_COUNT]


static func system(id: int) -> Dictionary:
	if id < 0 or id >= SYSTEM_COUNT:
		return {}
	if id < AUTHORED_SYSTEM_COUNT:
		return SYSTEMS[id]
	return _generated.systems[id - AUTHORED_SYSTEM_COUNT]


static func is_generated_system(id: int) -> bool:
	return id >= AUTHORED_SYSTEM_COUNT and id < SYSTEM_COUNT


static func system_position3(id: int) -> Vector3:
	var entry := system(id)
	if is_generated_system(id):
		return entry.position_3d
	var position: Vector2 = entry.get("position", Vector2.ZERO)
	return Vector3(position.x, position.y, 0.0)


static func sector_coordinates(id: int) -> Vector2i:
	var position := system_position3(id)
	return Vector2i(floori(position.x / SECTOR_SIZE), floori(position.y / SECTOR_SIZE))


static func system_of_site(id: int) -> int:
	if id < 0 or id >= DESTINATION_COUNT:
		return -1
	if id >= PRE_BINARY_DESTINATION_COUNT:
		return BINARY_SYSTEM
	if id >= AUTHORED_DESTINATION_COUNT:
		@warning_ignore("integer_division")
		return AUTHORED_SYSTEM_COUNT + (id - AUTHORED_DESTINATION_COUNT) / ProceduralSystems.TARGETS_PER_SYSTEM
	if id == GAS_GIANT_ID:
		return HOME_SYSTEM
	if id >= LIMIT_PORT:
		return LIMIT_SYSTEM
	if id >= PRE_EXPANSION_DESTINATION_COUNT:
		return HEATHER_SYSTEM
	if id >= PRE_TRAFFIC_DESTINATION_COUNT:
		return FRINGE_SYSTEM
	return HOME_SYSTEM if id < TARGET_COUNT else VELAR_SYSTEM


static func targets_for(system_id: int) -> Array:
	return system(system_id).get("targets", [])


static func ports_for(system_id: int) -> Array:
	return system(system_id).get("ports", [])


static func mines_for(system_id: int) -> Array:
	return system(system_id).get("mines", [])


static func star_for(system_id: int) -> int:
	return system(system_id).get("star", -1)


static func stars_for(system_id: int) -> Array:
	var entry := system(system_id)
	return entry.get("stars", [entry.star]) if not entry.is_empty() else []


static func is_star(site_id: int) -> bool:
	return site(site_id).get("kind", "") == "star"


static func stellar_clearance(site_id: int) -> float:
	return site(site_id).get("star_clearance", STAR_CLEARANCE)


static func gas_giant_for(system_id: int) -> int:
	return system(system_id).get("gas_giant", -1)


static func stellar_heat(system_id: int) -> float:
	return system(system_id).get("stellar_heat", 1.0)


static func jump_cost(origin: int, destination: int) -> int:
	if origin == destination or origin < 0 or origin >= SYSTEM_COUNT or destination < 0 or destination >= SYSTEM_COUNT:
		return 0
	if origin < AUTHORED_SYSTEM_COUNT and destination < AUTHORED_SYSTEM_COUNT:
		return JUMP_COSTS[origin][destination]
	return ceili(jump_distance(origin, destination) * 7.0 + 5.0)


static func jump_distance(origin: int, destination: int) -> float:
	if origin == destination or origin < 0 or origin >= SYSTEM_COUNT or destination < 0 or destination >= SYSTEM_COUNT:
		return 0.0
	if is_generated_system(origin) or is_generated_system(destination):
		return system_position3(origin).distance_to(system_position3(destination))
	var departure: Vector2 = system(origin).position
	return departure.distance_to(system(destination).position)


static func is_port(id: int) -> bool:
	return id in ports_for(system_of_site(id))


static func is_mine_site(id: int) -> bool:
	return id in mines_for(system_of_site(id))


static func is_gas_giant(id: int) -> bool:
	return site(id).get("kind", "") == "gas"


static func kind_name(kind: String) -> String:
	match kind:
		"port": return "Порт"
		"asteroid": return "Астероид"
		"moon": return "Луна"
		"planet": return "Планета"
		"gas": return "Газовый гигант"
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


static func first_contract_destination(origin: int) -> int:
	if not ROUTES.has(origin):
		return -1
	return ROUTES[origin].keys()[0]
