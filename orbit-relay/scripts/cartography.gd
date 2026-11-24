extends RefCounted
## Recorded observations and live public information about known systems.

const Catalog := preload("res://scripts/sector_catalog.gd")
const Orbit := preload("res://scripts/orbit_ephemeris.gd")
const Terrain := preload("res://scripts/surface_terrain.gd")
const Dynamics := preload("res://scripts/orbital_dynamics.gd")
const Atmosphere := preload("res://scripts/atmosphere.gd")
const Ground := preload("res://scripts/ground_port.gd")
const Economy := preload("res://scripts/port_economy.gd")
const Dossier := preload("res://scripts/system_dossier.gd")

const SCAN_CLEARANCE := 145.0
const SCAN_SPEED_LIMIT := 34.0
const MAX_EPOCH := 3155760000.0
const GRAVITATIONAL_CONSTANT := 6.67430e-11
const TEMPERATURE_REFERENCE := 278.0
const ORBITAL_REFERENCE := 1000.0
const STELLAR_RADIUS_REFERENCE := 220.0

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
	var physical := Dossier.body_astronomy(site_id)
	var catalog_known := float(physical.get("radius_km", 0.0)) > 0.0 or float(physical.get("mass_kg", 0.0)) > 0.0
	if catalog_known:
		status["catalog_known"] = true
	status.in_system = system_id == sim.system_id
	status.scan_limit = float(site.radius) + SCAN_CLEARANCE
	if status.in_system:
		status.range = sim.position.distance_to(sim.target_position(site_id))
		status.relative_speed = sim.speed_relative_to(site_id)
	if status.known:
		status.recorded_at = _records[site_id]
		status.data = _body_data(sim, site_id, site, status.recorded_at)
	elif catalog_known:
		# Public astronomical facts do not grant a personal observation, scan
		# reward or saved survey record. The old visibility rules still apply.
		status.data = _body_data(sim, site_id, site, float(sim.orbit_time))
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


func mark_discovered(system_id: int, epoch: float) -> bool:
	if not Catalog.is_generated_system(system_id) or not _valid_epoch(epoch, MAX_EPOCH) or discovered(system_id):
		return false
	_discovered[system_id] = epoch
	return true


func discovered_systems() -> Array[int]:
	var systems := _discovered.keys()
	systems.sort()
	return systems


func neighbors_to_discover(system_id: int) -> Array[int]:
	var neighbors: Array[int] = []
	if Catalog.system(system_id).is_empty() or (Catalog.is_generated_system(system_id) and not discovered(system_id)):
		return neighbors
	var astronomy := Catalog.is_astronomical_system(system_id)
	for candidate: int in Catalog.generated_systems_near(system_id, Catalog.GENERATED_SCAN_RANGE, true):
		if not discovered(candidate) and (not astronomy or Catalog.is_astronomical_system(candidate)):
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
	var sectors: Dictionary[float, Array] = {}
	for system_id: int in discovered_systems():
		var epoch := _discovered[system_id]
		if system_id >= Catalog.SYSTEM_COUNT:
			if not sectors.has(epoch):
				sectors[epoch] = []
			sectors[epoch].append(system_id)
		else:
			systems.append({"system": system_id, "epoch": epoch})
	var result := {"scans": scans, "systems": systems}
	if not sectors.is_empty():
		# Many neighboring stars share one radio-scan time. Store it once per group.
		var epochs := sectors.keys()
		epochs.sort()
		var records: Array[Array] = []
		for epoch: float in epochs:
			records.append([epoch, sectors[epoch]])
		result["sector_systems"] = records
	return result


func restore(raw: Variant, epoch: float, pre_procedural := false, system_limit := Catalog.SYSTEM_COUNT,
		site_limit := Catalog.DESTINATION_COUNT, allow_extended := true) -> bool:
	if not _valid_epoch(epoch, MAX_EPOCH) or not raw is Dictionary:
		return false
	var has_sectors: bool = raw.has("sector_systems")
	if (has_sectors and (not allow_extended or pre_procedural)) or raw.size() != (1 if pre_procedural else (3 if has_sectors else 2)):
		return false
	var surveyed_systems: Dictionary[int, float] = {}
	if not pre_procedural:
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
	if has_sectors and not _restore_sector_systems(raw.sector_systems, epoch, surveyed_systems):
		return false
	var scans: Variant = raw.get("scans")
	var active_site_limit := Catalog.SITE_ID_LIMIT if allow_extended and not pre_procedural else site_limit
	if not scans is Array or scans.size() > active_site_limit:
		return false
	var restored: Dictionary[int, float] = {}
	var previous_site := -1
	for scan: Variant in scans:
		if not scan is Dictionary or scan.size() != 2 or not scan.has_all(["site", "epoch"]):
			return false
		if not _valid_sorted_id(scan.site, previous_site, active_site_limit) or not _valid_epoch(scan.epoch, epoch):
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


static func _restore_sector_systems(raw: Variant, epoch: float, surveyed: Dictionary[int, float]) -> bool:
	if not raw is Array or raw.is_empty():
		return false
	var previous_epoch := -1.0
	for group: Variant in raw:
		if not group is Array or group.size() != 2 or not _valid_epoch(group[0], epoch):
			return false
		var scan_epoch := float(group[0])
		if scan_epoch <= previous_epoch or not group[1] is Array or group[1].is_empty():
			return false
		var previous := Catalog.SYSTEM_COUNT - 1
		for id: Variant in group[1]:
			if not _valid_sorted_id(id, previous, Catalog.SYSTEM_ID_LIMIT) or surveyed.has(int(id)):
				return false
			previous = int(id)
			surveyed[previous] = scan_epoch
		previous_epoch = scan_epoch
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
		return "Перейдите в систему объекта, чтобы записать наблюдение."
	if sim.jump_seconds_left > 0.0:
		return "Дождитесь завершения прыжка."
	if sim.docked >= 0 and sim.departure_status().active:
		return "Дождитесь выхода из дока."
	if sim.docked >= 0 or sim.landed_site >= 0:
		return "" if status.site in [sim.docked, sim.landed_site] else "Выйдите в полёт и сблизьтесь с выбранным объектом."
	if status.range > status.scan_limit:
		return "Сблизьтесь с объектом. Для сканирования до его центра должно быть не более %d м." % roundi(status.scan_limit)
	if status.relative_speed > SCAN_SPEED_LIMIT:
		return "Снизьте относительную скорость до %d м/с." % SCAN_SPEED_LIMIT
	return ""


static func _body_data(sim: RefCounted, site_id: int, site: Dictionary, epoch: float) -> Dictionary:
	var radius: float = site.radius
	var mu := Dynamics.gravity_parameter(site_id)
	var resource: String = site.get("resource", "")
	var kind: String = site.kind
	var host := Ground.body(site_id)
	var atmosphere := Atmosphere.profile(host if host >= 0 else site_id)
	var solid := Catalog.is_mine_site(site_id)
	var spin := Terrain.spin_rate(site_id)
	if host >= 0:
		spin = Terrain.spin_rate(host)
	elif Catalog.is_port(site_id):
		spin = float(site.spin)
	var scoop := kind if Catalog.is_star(site_id) or Catalog.is_gas_giant(site_id) else ""
	var data := {
		"radius": radius, "diameter": radius * 2.0, "gravity_parameter": mu,
		"gravity": mu / (radius * radius),
		"mass_kg": mu / GRAVITATIONAL_CONSTANT,
		"temperature_k": _temperature(site_id, kind, epoch),
		"associated_ports": _associated_ports(sim, site_id),
		"surface_class": _surface_class(site_id, kind, host, solid),
		"atmosphere_height": float(atmosphere.get("height", 0.0)),
		"atmosphere_density": float(atmosphere.get("density", 0.0)),
		"landing_max_slope": Terrain.MAX_LANDING_SLOPE if solid else 0.0,
		"contact_clearance": Terrain.CONTACT_CLEARANCE if solid else 0.0,
		"scoop_kind": scoop,
		"resource": resource, "resource_name": Catalog.resource_name(resource) if not resource.is_empty() else "",
		"reserve": sim.mining.reserve_at(site_id) if not resource.is_empty() else 0,
		"spin": spin, "spin_period": TAU / absf(spin) if spin != 0.0 else 0.0,
	}
	data.merge(_orbit_data(site_id, host))
	return physical_body_data(data, site)


static func physical_body_data(model_data: Dictionary, site: Dictionary) -> Dictionary:
	var metadata := Dossier.physical_metadata(site.get("astronomy", {}))
	if metadata.is_empty():
		return model_data
	var data := model_data.duplicate(true)
	var fields: Array[String] = []
	var radius_km := float(metadata.get("radius_km", 0.0))
	var mass := float(metadata.get("mass_kg", 0.0))
	if radius_km > 0.0:
		data.radius = radius_km * 1000.0
		data.diameter = radius_km * 2000.0
		fields.append_array(["radius", "diameter"])
	if mass > 0.0:
		data.mass_kg = mass
		data.gravity_parameter = GRAVITATIONAL_CONSTANT * mass
		fields.append_array(["mass_kg", "gravity_parameter"])
		if radius_km > 0.0:
			data.gravity = float(data.gravity_parameter) / pow(radius_km * 1000.0, 2.0)
			fields.append("gravity")
	var days := float(metadata.get("period_days", 0.0))
	if days > 0.0:
		data.period = days * 86400.0
		fields.append("period")
	var orbit: Variant = site.get("astronomical_orbit", {})
	var semimajor_km := float(metadata.get("semimajor_km", 0.0))
	if semimajor_km > 0.0:
		data["semimajor"] = semimajor_km * 1000.0
		fields.append("semimajor")
		if orbit is Dictionary and Orbit._finite_number(orbit.get("eccentricity")):
			var eccentricity := float(orbit.eccentricity)
			if eccentricity >= 0.0 and eccentricity < 1.0:
				data.periapsis = semimajor_km * 1000.0 * (1.0 - eccentricity)
				data.apoapsis = semimajor_km * 1000.0 * (1.0 + eccentricity)
				data["eccentricity"] = eccentricity
				fields.append_array(["periapsis", "apoapsis", "eccentricity"])
	var temperature := float(metadata.get("temperature_k", 0.0))
	# An invented gameplay equilibrium estimate is not a measured catalog
	# temperature. Leave this quantity unavailable when no real value is given.
	data.temperature_k = temperature
	if temperature > 0.0:
		fields.append("temperature_k")
	var rotation := float(metadata.get("rotation_period_days", 0.0))
	if rotation != 0.0:
		data.spin_period = absf(rotation) * 86400.0
		data.spin = TAU / (rotation * 86400.0)
		fields.append_array(["spin", "spin_period"])
	data["astronomy"] = metadata
	data["physical_fields"] = fields
	data["physical_catalog"] = not fields.is_empty()
	data["physical_type"] = str(metadata.get("type", ""))
	data["astronomy_epoch"] = str(metadata.get("epoch", ""))
	data["scale_notice"] = str(metadata.get("scale_notice", "Справочные величины приведены в физических единицах. Размеры и расстояния в полёте имеют условный масштаб."))
	data["ephemeris_notice"] = str(metadata.get("ephemeris_notice", ""))
	return data


static func _temperature(site_id: int, kind: String, epoch: float) -> float:
	if kind == "star":
		return Dossier.stellar_temperature(site_id)
	if kind == "port":
		return 0.0
	# Estimate equilibrium under the scaled survey model, using the observed orbital geometry.
	var center: Vector3 = Orbit.sample(site_id, epoch).position
	var irradiance := 0.0
	for star_id: int in Catalog.stars_for(Catalog.system_of_site(site_id)):
		var temperature := Dossier.stellar_temperature(star_id)
		if temperature <= 0.0:
			continue
		var radius: float = Catalog.site(star_id).radius
		var star_center: Vector3 = Orbit.sample(star_id, epoch).position
		var range_to_star := maxf(radius, center.distance_to(star_center))
		irradiance += pow(temperature / 5772.0, 4.0) * pow(radius / STELLAR_RADIUS_REFERENCE * ORBITAL_REFERENCE / range_to_star, 2.0)
	return TEMPERATURE_REFERENCE * pow(irradiance, 0.25)


static func _associated_ports(sim: RefCounted, site_id: int) -> Array[int]:
	var ports: Array[int] = []
	if Catalog.is_port(site_id):
		return ports
	var system_id := Catalog.system_of_site(site_id)
	for port: int in Catalog.ports_for(system_id):
		var host := Ground.body(port)
		var reference := host if host >= 0 else int(_orbit_data(port, -1).orbit_parent)
		if reference == site_id and sim.station_operational(port):
			ports.append(port)
	return ports


static func _orbit_data(site_id: int, host: int) -> Dictionary:
	var body := host if host >= 0 else site_id
	var period := Orbit.period(body)
	var system := Catalog.system_of_site(site_id)
	var parent := Orbit.orbit_parent(body)
	var reference := ""
	if parent >= 0:
		reference = Catalog.site(parent).name
	elif period > 0.0:
		if Catalog.stars_for(system).size() > 1:
			reference = "Центр масс звёзд"
		else:
			parent = Catalog.star_for(system)
			reference = Catalog.site(parent).name
	var extrema := Orbit.extrema(body)
	return {
		"period": period, "orbit_parent": parent, "orbit_reference": reference,
		"periapsis": extrema.x, "apoapsis": extrema.y,
		"ground_body": host,
		"ground_reference": str(Catalog.site(host).get("name", "")),
	}


static func _surface_class(site: int, kind: String, host: int, solid: bool) -> String:
	if solid:
		return "solid"
	if host >= 0:
		return "ground_hangar" if Ground.is_hangar(site) else "ground_pad"
	if kind == "port":
		return "orbital_port"
	return kind


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
