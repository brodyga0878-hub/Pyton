extends RefCounted
## The address of each system is derived from its sector and local slot.
## Number the four quadrants symmetrically, in concentric square rings.

const ProceduralSystems := preload("res://scripts/procedural_systems.gd")
const GRID_WIDTH := 8192
const QUADRANT_WIDTH := GRID_WIDTH / 2
const QUADRANT_AREA := QUADRANT_WIDTH * QUADRANT_WIDTH
const CORE_SECTOR := Vector2i(128, -48)
const BOUNDS := Rect2i(CORE_SECTOR - Vector2i(QUADRANT_WIDTH, QUADRANT_WIDTH),
	Vector2i(GRID_WIDTH, GRID_WIDTH))
# Each rank represents four sectors. The three bands account for every
# implicit address arithmetically, including the partially filled middle ring.
const INNER_RANKS := 2048 * 2048
const MIDDLE_RANKS := INNER_RANKS + 6848297
const INNER_DENSITY := 14
const MIDDLE_DENSITY := 6
const OUTER_DENSITY := 5
const INNER_SYSTEMS := 4 * INNER_RANKS * INNER_DENSITY
const MIDDLE_SYSTEMS := 4 * (MIDDLE_RANKS - INNER_RANKS) * MIDDLE_DENSITY
const SYSTEMS := INNER_SYSTEMS + MIDDLE_SYSTEMS + 4 * (QUADRANT_AREA - MIDDLE_RANKS) * OUTER_DENSITY
const SITES_PER_SYSTEM := ProceduralSystems.TARGETS_PER_SYSTEM
const CORE_NAME := "Сердцевина"


static func sector_count(coordinates: Vector2i) -> int:
	if not BOUNDS.has_point(coordinates):
		return 0
	return _density(_rank(_fold(coordinates)))


static func sector_ordinals(coordinates: Vector2i) -> Array[int]:
	var result: Array[int] = []
	if not BOUNDS.has_point(coordinates):
		return result
	var rank := _rank(_fold(coordinates))
	var density := _density(rank)
	var quadrant := int(coordinates.x < CORE_SECTOR.x) + 2 * int(coordinates.y < CORE_SECTOR.y)
	var first := _first_ordinal(rank) + quadrant * density
	for slot in range(density):
		result.append(first + slot)
	return result


static func address(ordinal: int) -> Vector3i:
	var rank: int
	var density: int
	var local := ordinal
	@warning_ignore("integer_division")
	if ordinal < INNER_SYSTEMS:
		density = INNER_DENSITY
		rank = local / (4 * density)
	elif ordinal < INNER_SYSTEMS + MIDDLE_SYSTEMS:
		density = MIDDLE_DENSITY
		local -= INNER_SYSTEMS
		rank = INNER_RANKS + local / (4 * density)
	else:
		density = OUTER_DENSITY
		local -= INNER_SYSTEMS + MIDDLE_SYSTEMS
		rank = MIDDLE_RANKS + local / (4 * density)
	@warning_ignore("integer_division")
	var quadrant := (local % (4 * density)) / density
	var ring := floori(sqrt(float(rank)))
	var along_ring := rank - ring * ring
	var folded := Vector2i(ring, along_ring) if along_ring <= ring else Vector2i(along_ring - ring - 1, ring)
	var x := folded.x if (quadrant & 1) == 0 else -folded.x - 1
	var y := folded.y if (quadrant & 2) == 0 else -folded.y - 1
	return Vector3i(CORE_SECTOR.x + x, CORE_SECTOR.y + y, local % density)


static func position_at(ordinal: int, coordinates: Vector2i, slot: int) -> Vector3:
	var corner := Vector2(coordinates) * ProceduralSystems.SECTOR_SIZE
	# The central system of each sector is one 8 ly leg from its neighbors.
	# The other slots follow offset rings with enough separation even in the core.
	if slot == 0:
		return Vector3(corner.x + 4.0, corner.y + 4.0, 0.0)
	var seed := _seed(ordinal)
	var index := slot - 1
	var angle := float(index) * 2.39996322972865
	angle += lerpf(-0.14, 0.14, ProceduralSystems._sample(seed, 1))
	var radial := lerpf(1.0, 3.35, sqrt(float(index) / float(INNER_DENSITY - 2)))
	var plane := corner + Vector2(4.0, 4.0) + Vector2(cos(angle), sin(angle)) * radial
	return Vector3(plane.x, plane.y, lerpf(-0.85, 0.85, ProceduralSystems._sample(seed, 2)))


static func build_system(ordinal: int, first_site: int) -> Dictionary:
	var coordinates := address(ordinal)
	var sector := Vector2i(coordinates.x, coordinates.y)
	var seed := _seed(ordinal)
	var systems: Array[Dictionary] = []
	var sites: Array[Dictionary] = []
	var name := _name(ordinal, seed)
	ProceduralSystems._append_single(systems, sites, first_site, sector, seed, name,
		position_at(ordinal, sector, coordinates.z))
	var system := systems[0]
	if ordinal == 0:
		var accent := Color("#b4d7ff")
		system = system.duplicate()
		system.accent = accent
		system.stellar_heat = 1.20
		system.description = "Система в центральном скоплении галактики. Голубая звезда, каменистая планета «Остов» и ледяной астероид «Скол». Портов нет."
		system.make_read_only()
		sites[0].accent = accent
		sites[0].cool_star = true
		sites[1].name = "Остов"
		sites[1].resource = "ore"
		sites[1].surface_color = ProceduralSystems.SURFACE_COLORS[0]
		sites[1].accent = ProceduralSystems.MINERAL_COLORS[0]
		sites[2].name = "Скол"
		sites[2].resource = "ice"
		sites[2].surface_color = ProceduralSystems.SURFACE_COLORS[2]
		sites[2].accent = ProceduralSystems.MINERAL_COLORS[2]
	for site: Dictionary in sites:
		site.make_read_only()
	sites.make_read_only()
	return {"system": system, "sites": sites}


static func _fold(coordinates: Vector2i) -> Vector2i:
	var offset := coordinates - CORE_SECTOR
	return Vector2i(offset.x if offset.x >= 0 else -offset.x - 1,
		offset.y if offset.y >= 0 else -offset.y - 1)


static func _rank(folded: Vector2i) -> int:
	var ring := maxi(folded.x, folded.y)
	return ring * ring + (folded.y if folded.x == ring else ring + 1 + folded.x)


static func _density(rank: int) -> int:
	if rank < INNER_RANKS:
		return INNER_DENSITY
	return MIDDLE_DENSITY if rank < MIDDLE_RANKS else OUTER_DENSITY


static func _first_ordinal(rank: int) -> int:
	var inner := mini(rank, INNER_RANKS)
	var middle := clampi(rank - INNER_RANKS, 0, MIDDLE_RANKS - INNER_RANKS)
	var outer := maxi(0, rank - MIDDLE_RANKS)
	return 4 * (inner * INNER_DENSITY + middle * MIDDLE_DENSITY + outer * OUTER_DENSITY)


static func _seed(ordinal: int) -> int:
	return ((ordinal + 11) * 73856093 ^ (ordinal + 37) * 19349663) & 0x7fffffff


static func _name(ordinal: int, seed: int) -> String:
	if ordinal == 0:
		return CORE_NAME
	var prefix: String = ProceduralSystems.FRONTIER_PREFIXES[seed % ProceduralSystems.FRONTIER_PREFIXES.size()]
	var suffix: String = ProceduralSystems.FRONTIER_SUFFIXES[(seed >> 8) % ProceduralSystems.FRONTIER_SUFFIXES.size()]
	return "%s%s %X" % [prefix, suffix, ordinal + 1]
