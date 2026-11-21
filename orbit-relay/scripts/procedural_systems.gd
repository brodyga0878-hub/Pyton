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
const SINGLE_SYSTEM_COUNT := SECTOR_COUNT * SYSTEMS_PER_SECTOR
const FRONTIER_RADIUS := 4
const FRONTIER_WIDTH := 2 * FRONTIER_RADIUS + 1
const OCCUPIED_CORE_SECTORS := [Vector2i.ZERO, Vector2i(0, -1), Vector2i(1, -1)]
const FRONTIER_SYSTEM_COUNT := FRONTIER_WIDTH * FRONTIER_WIDTH - SECTOR_COUNT - len(OCCUPIED_CORE_SECTORS)
const ARM_ROOTS := [Vector2i(4, 0), Vector2i(0, 4), Vector2i(-4, -1), Vector2i(-1, -4)]
const ARM_NAMES := ["Кадир", "Талерис", "Мирас", "Сирин"]
const ARM_MEMBER_SUFFIXES := ["", "а", "б", "в"]
const ARM_GROUP_COUNT := 26
const ARM_GROUP_SIZE := len(ARM_MEMBER_SUFFIXES)
const OUTER_SYSTEM_COUNT := len(ARM_ROOTS) * ARM_GROUP_COUNT * ARM_GROUP_SIZE
const COMPANION_GROUPS := [0, 6, 12, 18]
const MOON_COUNT := len(ARM_ROOTS) * len(COMPANION_GROUPS)
const GAS_GIANT_COUNT := MOON_COUNT
const NAMES := [
	"Тальвена", "Ирсавель", "Морикса", "Вестрида", "Ольвенир", "Астрэва",
	"Ниварис", "Сельтура", "Каэлин", "Дорвейн", "Ярсела", "Энтурин",
	"Ровайна", "Остриэль", "Тавернис", "Умберас", "Меллория", "Зарвелион",
]
const FRONTIER_PREFIXES := ["Айл", "Брин", "Вэр", "Гарн", "Дел", "Ирн", "Кел", "Лэйс", "Морн", "Нэв", "Орк", "Рин"]
const FRONTIER_SUFFIXES := ["адар", "алис", "авен", "еваль", "ирас", "онир", "ория", "улет", "эсса", "ювар"]
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
			var position := _system_position(sector, slot, seed)
			_append_single(systems, sites, first_target + sites.size(), sector, seed, name, position)
	_append_binary(systems, sites, first_target + sites.size())
	for site in sites:
		site.make_read_only()
	return {"systems": systems, "sites": sites}


static func build_frontier(first_target: int) -> Dictionary:
	var systems: Array[Dictionary] = []
	var sites: Array[Dictionary] = []
	# Adding an outer ring appends its IDs after all previously published rings.
	for ring in range(1, FRONTIER_RADIUS + 1):
		for y in range(-ring, ring + 1):
			for x in range(-ring, ring + 1):
				if maxi(absi(x), absi(y)) != ring:
					continue
				var sector := Vector2i(x, y)
				if sector in SECTORS or sector in OCCUPIED_CORE_SECTORS:
					continue
				var seed := ((x + 157) * 73856093 ^ (y + 179) * 19349663 ^ 613683211) & 0x7fffffff
				var center := (Vector2(sector) + Vector2(0.5, 0.5)) * SECTOR_SIZE
				var jitter := Vector2(_sample(seed, 0) - 0.5, _sample(seed, 1) - 0.5) * 0.8
				var plane := center + jitter
				var position := Vector3(plane.x, plane.y, lerpf(-0.7, 0.7, _sample(seed, 2)))
				var name := _frontier_name(systems.size())
				_append_single(systems, sites, first_target + sites.size(), sector, seed, name, position)
	for site in sites:
		site.make_read_only()
	return {"systems": systems, "sites": sites}


static func build_outer(first_target: int, frontier: Array[Dictionary]) -> Dictionary:
	var centers: Array[Vector3] = []
	var occupied: Array[Vector3] = []
	for system: Dictionary in frontier:
		occupied.append(system.position_3d)
	# Plan the relay chain first so cluster members cannot overlap an upcoming relay.
	for arm in range(ARM_ROOTS.size()):
		var position := _arm_origin(frontier, ARM_ROOTS[arm])
		for group in range(ARM_GROUP_COUNT):
			var seed := _arm_seed(arm, group, 0)
			var heading := _arm_heading(arm, group)
			var step := lerpf(5.9, 8.4, _sample(seed, 0))
			position += Vector3(cos(heading) * step, sin(heading) * step, 0.0)
			position.z = lerpf(-0.9, 0.9, _sample(seed, 1))
			centers.append(position)
			occupied.append(position)

	var systems: Array[Dictionary] = []
	var sites: Array[Dictionary] = []
	for arm in range(ARM_ROOTS.size()):
		for group in range(ARM_GROUP_COUNT):
			var center := centers[arm * ARM_GROUP_COUNT + group]
			for slot in range(ARM_GROUP_SIZE):
				var seed := _arm_seed(arm, group, slot)
				var position := center
				var name := "%s-%02d%s" % [ARM_NAMES[arm], group + 1, ARM_MEMBER_SUFFIXES[slot]]
				if slot != 0:
					position = _cluster_member(center, _arm_heading(arm, group), seed, slot, occupied)
					occupied.append(position)
				var sector := Vector2i(floori(position.x / SECTOR_SIZE), floori(position.y / SECTOR_SIZE))
				_append_single(systems, sites, first_target + sites.size(), sector, seed, name, position)
	# Append bodies only after every existing site ID has been assigned.
	for arm in range(ARM_ROOTS.size()):
		for group: int in COMPANION_GROUPS:
			var relay_index := (arm * ARM_GROUP_COUNT + group) * ARM_GROUP_SIZE
			_append_outer_moon(systems, sites, relay_index + 1, first_target)
			_append_outer_giant(systems, sites, relay_index + 2, first_target)
	for site: Dictionary in sites:
		site.make_read_only()
	return {"systems": systems, "sites": sites}


static func _append_outer_moon(systems: Array[Dictionary], sites: Array[Dictionary], system_index: int,
		first_target: int) -> void:
	var system := systems[system_index].duplicate()
	var parent_id := int(system.targets[1])
	var parent := sites[parent_id - first_target]
	var seed: int = system.seed
	var radius := lerpf(40.0, 53.0, _sample(seed, 60))
	var orbital_radius := float(parent.gate_offset) + radius + 64.0
	var ray := Vector3.BACK.rotated(Vector3.UP, TAU * _sample(seed, 61))
	var id := first_target + sites.size()
	sites.append({
		"name": "%s I-а" % system.name, "kind": "moon", "system_index": system_index,
		"center": Vector3(parent.center) + ray * orbital_radius, "orbit_parent": parent_id,
		"orbital_elements": Vector3(0.012, 360.0 * _sample(seed, 62), 60.0 + 18.0 * _sample(seed, 63)),
		"radius": radius, "pad_offset": radius, "gate_offset": radius + 78.0,
		"seed": seed ^ 0x4A1072, "surface_color": Color("#72808b"), "accent": MINERAL_COLORS[2],
		"resource": "ice", "reserve": 96 + floori(_sample(seed, 64) * 9.0) * 12,
		"drill_seconds": lerpf(8.0, 13.0, _sample(seed, 65)),
	})
	system.targets = system.targets + [id]
	system.mines = system.mines + [id]
	system.survey_sites = system.survey_sites + [id]
	system.description += " У планеты есть ледяная луна."
	for key: String in ["targets", "mines", "survey_sites"]:
		system[key].make_read_only()
	system.make_read_only()
	systems[system_index] = system


static func _append_outer_giant(systems: Array[Dictionary], sites: Array[Dictionary], system_index: int,
		first_target: int) -> void:
	var system := systems[system_index].duplicate()
	var star_id := int(system.star)
	var star := sites[star_id - first_target]
	var seed: int = system.seed
	var radius := lerpf(416.0, 492.0, _sample(seed, 71))
	var orbital_radius := lerpf(3850.0, 4260.0, _sample(seed, 72))
	var ray := Vector3.BACK.rotated(Vector3.UP, TAU * _sample(seed, 73)).rotated(Vector3.RIGHT, 0.17)
	var id := first_target + sites.size()
	var atmosphere := {"height": lerpf(100.0, 126.0, _sample(seed, 74)),
		"density": lerpf(1.28, 1.81, _sample(seed, 75)), "color": Color("#efb488")}
	atmosphere.make_read_only()
	sites.append({
		"name": "%s II" % system.name, "kind": "gas", "system_index": system_index,
		"center": Vector3(star.center) + ray * orbital_radius, "orbit_parent": star_id,
		"orbital_elements": Vector3(0.035, 360.0 * _sample(seed, 76), 12.0),
		"radius": radius, "pad_offset": radius, "gate_offset": radius + 160.0,
		"accent": atmosphere.color, "atmosphere": atmosphere,
	})
	system.targets = system.targets + [id]
	system.survey_sites = system.survey_sites + [id]
	system.gas_giant = id
	system.description += " В верхних слоях атмосферы газового гиганта доступен сбор водорода."
	system.targets.make_read_only()
	system.survey_sites.make_read_only()
	system.make_read_only()
	systems[system_index] = system


static func _arm_origin(frontier: Array[Dictionary], sector: Vector2i) -> Vector3:
	for system: Dictionary in frontier:
		if system.sector == sector:
			return system.position_3d
	return Vector3.ZERO


static func _arm_heading(arm: int, group: int) -> float:
	var base := Vector2(ARM_ROOTS[arm]).angle()
	var bend := (0.045 + float(arm) * 0.002) * float(group + 1)
	return base + bend + sin(float(group) * 0.47 + float(arm)) * 0.13


static func _arm_seed(arm: int, group: int, slot: int) -> int:
	return ((arm + 31) * 9473179 ^ (group + 101) * 29781251 ^ (slot + 1) * 10868519) & 0x7fffffff


static func _cluster_member(center: Vector3, heading: float, seed: int, slot: int,
		occupied: Array[Vector3]) -> Vector3:
	var bearing := heading + TAU * float(slot) / float(ARM_GROUP_SIZE - 1) + lerpf(-0.55, 0.55, _sample(seed, 0))
	var best := center
	var best_clearance := 0.0
	for attempt in range(16):
		var angle := bearing + float(attempt) * 2.39996322972865
		var distance := lerpf(2.2, 5.8, _sample(seed, attempt + 1))
		var position := center + Vector3(cos(angle) * distance, sin(angle) * distance, lerpf(-2.2, 2.2, _sample(seed, 19)))
		var clearance := INF
		for existing: Vector3 in occupied:
			var offset := existing - position
			clearance = minf(clearance, offset.x * offset.x + offset.y * offset.y)
		if clearance >= 2.25:
			return position
		if clearance > best_clearance:
			best_clearance = clearance
			best = position
	return best


static func _frontier_name(index: int) -> String:
	var suffixes := FRONTIER_SUFFIXES.size()
	var names_per_cycle := FRONTIER_PREFIXES.size() * suffixes
	var slot := index % names_per_cycle
	@warning_ignore("integer_division")
	var prefix := slot / suffixes
	var name := str(FRONTIER_PREFIXES[prefix]) + str(FRONTIER_SUFFIXES[slot % suffixes])
	@warning_ignore("integer_division")
	var cycle := index / names_per_cycle
	return name if cycle == 0 else "%s-%d" % [name, cycle + 1]


static func _append_single(systems: Array[Dictionary], sites: Array[Dictionary], star_id: int,
		sector: Vector2i, seed: int, name: String, position: Vector3) -> void:
	var planet_id := star_id + 1
	var asteroid_id := star_id + 2
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


static func _append_binary(systems: Array[Dictionary], sites: Array[Dictionary], primary_id: int) -> void:
	# Keep the order of the original systems and their three sites stable for saves.
	const NAME := "Элиора"
	const SEED := 158397423
	const POSITION := Vector3(2.2, 5.2, 0.4)
	const BARYCENTER := Vector3(1800, 220, -1720)
	const SEPARATION := 960.0
	const PRIMARY_MU := 6000.0
	const SECONDARY_MU := 3000.0
	const TOTAL_MU := PRIMARY_MU + SECONDARY_MU
	var secondary_id := primary_id + 1
	var planet_id := secondary_id + 1
	var moon_id := planet_id + 1
	var primary_center := BARYCENTER - Vector3.RIGHT * (SEPARATION * SECONDARY_MU / TOTAL_MU)
	var secondary_center := BARYCENTER + Vector3.RIGHT * (SEPARATION * PRIMARY_MU / TOTAL_MU)
	var planet_center := BARYCENTER + Vector3(-0.6, 0, 0.8) * 3350.0
	# The lunar orbit clears the approach gates of both solid bodies at every phase.
	var moon_center := planet_center + Vector3(0.8, 0, -0.6) * 380.0
	var system := {
		"name": NAME, "position": Vector2(POSITION.x, POSITION.y), "position_3d": POSITION,
		"sector": Vector2i.ZERO, "seed": SEED, "accent": STELLAR_COLORS[1],
		"description": "Необитаемая двойная система. Каменистая планета обращается вокруг обеих звёзд и имеет собственную луну.",
		"arrival_port": -1, "arrival_target": primary_id, "star": primary_id, "stars": [primary_id, secondary_id],
		"targets": [primary_id, secondary_id, planet_id, moon_id], "ports": [],
		"mines": [planet_id, moon_id], "survey_sites": [planet_id, moon_id],
		"stellar_heat": 1.08, "gravity_parameter": TOTAL_MU,
		"barycenter": BARYCENTER, "binary_separation": SEPARATION, "binary_inclination": 14.0,
	}
	for key: String in ["stars", "targets", "ports", "mines", "survey_sites"]:
		system[key].make_read_only()
	system.make_read_only()
	systems.append(system)
	sites.append({
		"name": "%s A" % NAME, "kind": "star", "center": primary_center, "radius": 220.0,
		"pad_offset": 310.0, "gate_offset": 470.0, "accent": STELLAR_COLORS[1],
		"mu": PRIMARY_MU, "star_clearance": 250.0, "stellar_heat": 1.08, "cool_star": false,
	})
	sites.append({
		"name": "%s B" % NAME, "kind": "star", "center": secondary_center, "radius": 175.0,
		"pad_offset": 310.0, "gate_offset": 470.0, "accent": STELLAR_COLORS[2],
		"mu": SECONDARY_MU, "star_clearance": 205.0, "stellar_heat": 0.82, "cool_star": true,
	})
	sites.append({
		"name": "%s I" % NAME, "kind": "planet", "center": planet_center, "radius": 150.0,
		"pad_offset": 150.0, "gate_offset": 245.0, "seed": SEED + 1,
		"surface_color": Color("#657e8c"), "accent": Color("#92c5e1"), "resource": "ore",
		"reserve": 228, "drill_seconds": 11.0, "mu": 742.5, "orbit_inclination": 23.0,
	})
	sites.append({
		"name": "%s I-a" % NAME, "kind": "moon", "center": moon_center, "radius": 54.0,
		"pad_offset": 54.0, "gate_offset": 128.0, "seed": SEED + 2,
		"surface_color": Color("#776e8a"), "accent": MINERAL_COLORS[1], "resource": "crystal",
		"reserve": 144, "drill_seconds": 12.0, "mu": 15.7464,
		"orbit_parent": planet_id, "orbit_inclination": -29.0,
	})


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
