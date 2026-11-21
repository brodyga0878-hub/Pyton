extends RefCounted
## Recorded observations and live public information about known systems.

const Catalog := preload("res://scripts/sector_catalog.gd")
const Orbit := preload("res://scripts/orbit_ephemeris.gd")
const Terrain := preload("res://scripts/surface_terrain.gd")
const Dynamics := preload("res://scripts/orbital_dynamics.gd")
const Atmosphere := preload("res://scripts/atmosphere.gd")
const Economy := preload("res://scripts/port_economy.gd")

const SCAN_CLEARANCE := 145.0
const SCAN_SPEED_LIMIT := 34.0
const MAX_EPOCH := 3155760000.0

var _records: Dictionary[int, float] = {}
var _discovered: Dictionary[int, float] = {}


func body_status(sim: RefCounted, site_id: int) -> Dictionary:
	var status := {
		"site": site_id, "name": "", "kind": "", "known": false, "in_system": false,
		"can_scan": false, "reason": "Объект недоступен для наблюдения.",
		"range": -1.0, "relative_speed": -1.0, "scan_limit": 0.0, "recorded_at": -1.0,
		"data": {},
	}
	var system_id := Catalog.system_of_site(site_id)
	if system_id < 0 or not sim.system_known(system_id) or not _visible_site(sim, site_id):
		return status
	var site := Catalog.site(site_id)
	status.name = site.name
	status.kind = site.kind
	status.known = _records.has(site_id)
	status.in_system = system_id == sim.system_id
	status.scan_limit = float(site.radius) + SCAN_CLEARANCE
	if status.in_system:
		status.range = sim.position.distance_to(sim.target_position(site_id))
		status.relative_speed = sim.speed_relative_to(site_id)
	if status.known:
		status.recorded_at = _records[site_id]
		status.data = _body_data(sim, site_id, site)
	status.reason = _scan_reason(sim, status)
	status.can_scan = status.reason.is_empty()
	if status.can_scan:
		status.reason = "Можно записать наблюдение."
	return status


func record(site_id: int, epoch: float) -> bool:
	if Catalog.site(site_id).is_empty() or _records.has(site_id) or not _valid_epoch(epoch, MAX_EPOCH):
		return false
	var system_id := Catalog.system_of_site(site_id)
	if Catalog.is_generated_system(system_id) and (not discovered(system_id) or _discovered[system_id] > epoch):
		return false
	_records[site_id] = epoch
	return true


func surveyed_sites() -> Array[int]:
	var sites := _records.keys()
	sites.sort()
	return sites


func observation_time(site_id: int) -> float:
	return _records.get(site_id, -1.0)


func discovered(system_id: int) -> bool:
	return _discovered.has(system_id)


func neighbors_to_discover(system_id: int) -> Array[int]:
	var neighbors: Array[int] = []
	if Catalog.system(system_id).is_empty() or (Catalog.is_generated_system(system_id) and not discovered(system_id)):
		return neighbors
	for candidate in range(Catalog.AUTHORED_SYSTEM_COUNT, Catalog.SYSTEM_COUNT):
		if candidate != system_id and not discovered(candidate) and Catalog.jump_distance(system_id, candidate) <= Catalog.GENERATED_SCAN_RANGE:
			neighbors.append(candidate)
	return neighbors


func discover_from(system_id: int, epoch: float) -> int:
	if not _valid_epoch(epoch, MAX_EPOCH):
		return 0
	var neighbors := neighbors_to_discover(system_id)
	for candidate in neighbors:
		_discovered[candidate] = epoch
	return neighbors.size()


func system_status(sim: RefCounted, system_id: int) -> Dictionary:
	var ports: Array[int] = []
	var observations: Array[int] = []
	var imports: Array[Dictionary] = []
	var exports: Array[Dictionary] = []
	var status := {
		"known": false, "name": "", "faction": "", "description": "", "ports": ports,
		"target_count": 0, "scan_count": 0, "goods": {}, "imports": imports, "exports": exports,
		"observations": observations,
	}
	var system := Catalog.system(system_id)
	if system.is_empty() or not sim.system_known(system_id):
		return status
	status.known = true
	status.name = system.name
	status.faction = sim.system_faction_name(system_id)
	status.description = system.description
	for site_id: int in Catalog.targets_for(system_id):
		if not _visible_site(sim, site_id):
			continue
		status.target_count += 1
		if Catalog.is_port(site_id):
			ports.append(site_id)
		if _records.has(site_id):
			observations.append(site_id)
	observations.sort()
	status.scan_count = observations.size()
	status.goods = _warehouse_totals(sim, ports)
	_collect_shipments(sim, system_id, ports, imports, exports)
	return status


func snapshot() -> Dictionary:
	var scans: Array[Dictionary] = []
	for site_id in surveyed_sites():
		scans.append({"site": site_id, "epoch": _records[site_id]})
	var systems: Array[Dictionary] = []
	var ids := _discovered.keys()
	ids.sort()
	for system_id: int in ids:
		systems.append({"system": system_id, "epoch": _discovered[system_id]})
	return {"scans": scans, "systems": systems}


func restore(raw: Variant, epoch: float, pre_procedural := false, pre_binary := false, pre_ground_ports := false) -> bool:
	if not _valid_epoch(epoch, MAX_EPOCH) or not raw is Dictionary or raw.size() != (1 if pre_procedural else 2):
		return false
	var surveyed_systems: Dictionary[int, float] = {}
	if not pre_procedural:
		var system_limit := Catalog.PRE_BINARY_SYSTEM_COUNT if pre_binary else Catalog.SYSTEM_COUNT
		var systems: Variant = raw.get("systems")
		if not systems is Array or systems.size() > system_limit - Catalog.AUTHORED_SYSTEM_COUNT:
			return false
		var previous := Catalog.AUTHORED_SYSTEM_COUNT - 1
		for item: Variant in systems:
			if not item is Dictionary or item.size() != 2 or not item.has_all(["system", "epoch"]):
				return false
			if not _valid_sorted_id(item.system, previous, system_limit) or not _valid_epoch(item.epoch, epoch):
				return false
			previous = int(item.system)
			surveyed_systems[previous] = float(item.epoch)
	var scans: Variant = raw.get("scans")
	var site_limit := Catalog.PRE_BINARY_DESTINATION_COUNT if pre_binary else Catalog.DESTINATION_COUNT
	if pre_procedural:
		site_limit = Catalog.AUTHORED_DESTINATION_COUNT
	elif not pre_binary and pre_ground_ports:
		site_limit = Catalog.PRE_GROUND_DESTINATION_COUNT
	if not scans is Array or scans.size() > site_limit:
		return false
	var restored: Dictionary[int, float] = {}
	var previous_site := -1
	for scan: Variant in scans:
		if not scan is Dictionary or scan.size() != 2 or not scan.has_all(["site", "epoch"]):
			return false
		if not _valid_sorted_id(scan.site, previous_site, site_limit) or not _valid_epoch(scan.epoch, epoch):
			return false
		var site_id := int(scan.site)
		if Catalog.site(site_id).is_empty():
			return false
		var system_id := Catalog.system_of_site(site_id)
		if Catalog.is_generated_system(system_id) and (not surveyed_systems.has(system_id) or surveyed_systems[system_id] > float(scan.epoch)):
			return false
		restored[site_id] = float(scan.epoch)
		previous_site = site_id
	_records = restored
	_discovered = surveyed_systems
	return true


static func _valid_sorted_id(value: Variant, prior: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floorf(float(value)) and prior < value and value < high


static func _valid_epoch(value: Variant, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0.0 and value <= high


static func _visible_site(sim: RefCounted, site_id: int) -> bool:
	return not Catalog.site(site_id).is_empty() and (not Catalog.is_port(site_id) or sim.station_operational(site_id))


static func _scan_reason(sim: RefCounted, status: Dictionary) -> String:
	if status.known:
		return "Наблюдение сохранено."
	if not status.in_system:
		return "Прибудьте в систему для наблюдения."
	if sim.jump_seconds_left > 0.0:
		return "Дождитесь завершения прыжка."
	if sim.docked >= 0 and sim.departure_status().active:
		return "Дождитесь выхода из дока."
	if sim.docked >= 0 or sim.landed_site >= 0:
		return "" if status.site in [sim.docked, sim.landed_site] else "Выйдите в полёт к выбранному объекту."
	if status.range > status.scan_limit:
		return "Подойдите к объекту на %d м от центра." % roundi(status.scan_limit)
	if status.relative_speed > SCAN_SPEED_LIMIT:
		return "Снизьте относительную скорость до %d м/с." % SCAN_SPEED_LIMIT
	return ""


static func _body_data(sim: RefCounted, site_id: int, site: Dictionary) -> Dictionary:
	var atmosphere := Atmosphere.profile(site_id)
	var radius: float = site.radius
	var resource: String = site.get("resource", "")
	var parent := Orbit.orbit_parent(site_id)
	return {
		"radius": radius, "period": Orbit.period(site_id),
		"orbit_parent": parent,
		"orbit_reference": str(Catalog.site(parent).name) if parent >= 0 else (
			"Центр масс звёзд" if Catalog.system_of_site(site_id) == Catalog.BINARY_SYSTEM else ""),
		"gravity": Dynamics.gravity_parameter(site_id) / (radius * radius),
		"atmosphere_height": float(atmosphere.get("height", 0.0)),
		"atmosphere_density": float(atmosphere.get("density", 0.0)),
		"resource": resource, "resource_name": Catalog.resource_name(resource) if not resource.is_empty() else "",
		"reserve": sim.mining.reserve_at(site_id) if not resource.is_empty() else 0,
		"spin": float(site.spin) if Catalog.is_port(site_id) else Terrain.spin_rate(site_id),
	}


static func _warehouse_totals(sim: RefCounted, ports: Array[int]) -> Dictionary:
	var totals := {}
	if ports.is_empty():
		return totals
	for good: String in Economy.GOODS:
		var stock := 0
		for port in ports:
			stock += sim.market.stock(port, good)
		totals[good] = stock
	return totals


static func _collect_shipments(sim: RefCounted, system_id: int, ports: Array[int],
		imports: Array[Dictionary], exports: Array[Dictionary]) -> void:
	var seen := {}
	for port in ports:
		for service: Dictionary in sim.freight_status(port):
			if not service.interstellar or not service.in_transit or service.amount <= 0 or seen.has(service.id):
				continue
			var origin := Catalog.system_of_site(service.origin)
			var destination := Catalog.system_of_site(service.destination)
			if origin < 0 or destination < 0 or origin == destination or not sim.system_known(origin) or not sim.system_known(destination):
				continue
			seen[service.id] = true
			var row := {"id": service.id, "name": service.name, "good": service.good,
				"good_name": Economy.good_name(service.good), "amount": service.amount,
				"origin": service.origin, "destination": service.destination}
			if origin == system_id:
				exports.append(row)
			elif destination == system_id:
				imports.append(row)
