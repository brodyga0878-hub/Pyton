extends RefCounted
## Deterministic catalog for uncharted systems. Sector and slot order define save IDs.

const SECTOR_SIZE := 8.0
const SYSTEMS_PER_SECTOR := 3
const TARGETS_PER_SYSTEM := 3
const SECTORS := [
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, 1),
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 0),
]
const SECTOR_COUNT := len(SECTORS)
const NAMES := [
	"Тальвена", "Ирсавель", "Морикса", "Вестрида", "Ольвенир", "Астрэва",
	"Ниварис", "Сельтура", "Каэлин", "Дорвейн", "Ярсела", "Энтурин",
	"Ровайна", "Остриэль", "Тавернис", "Умберас", "Меллория", "Зарвелион",
]
const SLOT_OFFSETS := [Vector2.ZERO, Vector2(-2.0, 1.5), Vector2(1.7, -1.7)]
const STELLAR_COLORS := [Color("#ffc195"), Color("#ffe3a8"), Color("#b4d7ff")]
const SURFACE_COLORS := [Color("#906d5f"), Color("#776e8a"), Color("#69919d")]
const MINERAL_COLORS := [Color("#f8b981"), Color("#d9b4f4"), Color("#ade6f0")]
const RESOURCES := ["ore", "crystal", "ice"]


static func build(first_target: int) -> Dictionary:
	var systems: Array[Dictionary] = []
	var sites: Array[Dictionary] = []
	for sector: Vector2i in SECTORS:
		for slot in range(SYSTEMS_PER_SECTOR):
			var seed := ((sector.x + 17) * 73856093 ^ (sector.y + 17) * 19349663 ^ (slot + 1) * 83492791) & 0x7fffffff
			var name: String = NAMES[systems.size()]
			var star_id := first_target + sites.size()
			var planet_id := star_id + 1
			var asteroid_id := star_id + 2
			var position := _system_position(sector, slot, seed)
			var star_color: Color = STELLAR_COLORS[floori(_sample(seed, 3) * STELLAR_COLORS.size())]
			var star_center := Vector3(
				lerpf(1660.0, 1960.0, _sample(seed, 4)), lerpf(150.0, 310.0, _sample(seed, 5)),
				lerpf(-1910.0, -1580.0, _sample(seed, 6)))
			var system := {
				"name": name, "position": Vector2(position.x, position.y), "position_3d": position,
				"sector": sector, "seed": seed, "accent": star_color,
				"description": "Необитаемая система. Каменистая планета и астероид доступны для исследования.",
				"arrival_port": -1, "arrival_target": star_id, "star": star_id,
				"targets": [star_id, planet_id, asteroid_id], "ports": [],
				"mines": [planet_id, asteroid_id], "survey_sites": [planet_id, asteroid_id],
				"stellar_heat": lerpf(0.85, 1.18, _sample(seed, 7)),
				"gravity_parameter": lerpf(7350.0, 8950.0, _sample(seed, 8)),
			}
			for key: String in ["targets", "ports", "mines", "survey_sites"]:
				system[key].make_read_only()
			system.make_read_only()
			systems.append(system)
			sites.append({
				"name": name, "kind": "star", "center": star_center, "radius": 220.0,
				"pad_offset": 310.0, "gate_offset": 470.0, "accent": star_color,
			})
			sites.append(_body(name, star_center, seed, 10, true))
			sites.append(_body(name, star_center, seed, 30, false))
	for site in sites:
		site.make_read_only()
	return {"systems": systems, "sites": sites}


static func _system_position(sector: Vector2i, slot: int, seed: int) -> Vector3:
	var center := (Vector2(sector) + Vector2(0.5, 0.5)) * SECTOR_SIZE
	var spacing: Vector2 = SLOT_OFFSETS[slot]
	var jitter := Vector2(_sample(seed, 0) - 0.5, _sample(seed, 1) - 0.5) * 1.5
	var plane := center + spacing + jitter
	return Vector3(plane.x, plane.y, lerpf(-1.6, 1.6, _sample(seed, 2)))


static func _body(name: String, focus: Vector3, seed: int, salt: int, planet: bool) -> Dictionary:
	var bearing := TAU * _sample(seed, salt)
	var latitude := lerpf(-0.23, 0.23, _sample(seed, salt + 1))
	var ray := Vector3(cos(bearing) * cos(latitude), sin(latitude), sin(bearing) * cos(latitude))
	# Separated radial bands leave room for both surfaces and a safe stellar arrival at any phase.
	var distance := lerpf(970.0, 1150.0, _sample(seed, salt + 2)) if planet else lerpf(1850.0, 2050.0, _sample(seed, salt + 2))
	var radius := lerpf(115.0, 145.0, _sample(seed, salt + 3)) if planet else lerpf(45.0, 69.0, _sample(seed, salt + 3))
	var mineral := floori(_sample(seed, salt + 4) * RESOURCES.size())
	return {
		"name": "%s I" % name if planet else "%s / астероид" % name,
		"kind": "planet" if planet else "asteroid", "center": focus + ray * distance,
		"radius": radius, "pad_offset": radius, "gate_offset": radius + (95.0 if planet else 74.0),
		"seed": int(_sample(seed, salt + 5) * 1000000.0), "surface_color": SURFACE_COLORS[mineral],
		"accent": MINERAL_COLORS[mineral], "resource": RESOURCES[mineral],
		"reserve": 96 + floori(_sample(seed, salt + 6) * 15.0) * 12,
		"drill_seconds": lerpf(7.0, 15.0, _sample(seed, salt + 7)),
		"orbital_elements": Vector3(lerpf(0.02, 0.06, _sample(seed, salt + 8)),
			360.0 * _sample(seed, salt + 9), lerpf(7.0, 22.0, _sample(seed, salt + 10)) * (1.0 if planet else -1.0)),
	}


static func _sample(seed: int, salt: int) -> float:
	# Integer mixing makes every field reproducible without runtime RNG state.
	var mixed := (seed ^ (salt * 374761393)) & 0x7fffffff
	mixed = ((mixed ^ (mixed >> 16)) * 73244475) & 0x7fffffff
	mixed = ((mixed ^ (mixed >> 16)) * 73244475) & 0x7fffffff
	return float(mixed ^ (mixed >> 16)) / 2147483648.0
