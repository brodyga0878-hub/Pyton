extends RefCounted
## Density, drag and heating in the reference frame of an atmospheric body.

const Catalog = preload("res://scripts/sector_catalog.gd")
const Orbit = preload("res://scripts/orbit_ephemeris.gd")
const Terrain = preload("res://scripts/surface_terrain.gd")

const SAFE_ENTRY_SPEED := 38.0
const NEAR_MARGIN := 90.0
const DRAG_COEFFICIENT := 0.004
const HEAT_REFERENCE_SPEED := 44.0
const HEAT_SCALE := 85.0
const MAX_HEAT_TARGET := 210.0
const GAS_ROTATION := 0.005
const PROFILES := {
	Catalog.GAS_GIANT_ID: {"height": 100.0, "density": 1.75, "color": Color("#edb37e")},
	Catalog.TERRACE_ID: {"height": 46.0, "density": 1.0, "color": Color("#87bdff")},
	Catalog.HEATHER_PLANET: {"height": 38.0, "density": 1.18, "color": Color("#d9b77e")},
	Catalog.LIMIT_PLANET: {"height": 41.0, "density": 0.82, "color": Color("#9bcadf")},
}

static var _system_sites: Dictionary[int, int] = _build_system_sites()


static func profile(site: int) -> Dictionary:
	if PROFILES.has(site):
		return PROFILES[site]
	return Catalog.site(site).get("atmosphere", {})


static func sample(sim: RefCounted, point: Vector3, velocity: Vector3) -> Dictionary:
	var site := _site_for_point(sim.system_id, point, 0.0, sim)
	if site < 0 or not point.is_finite() or not velocity.is_finite():
		return {
			"site": -1, "inside": false, "near": false, "density": 0.0, "altitude": -1.0,
			"relative_speed": 0.0, "vertical_speed": 0.0, "drift": Vector3.ZERO,
			"height": 0.0, "depth": 0.0, "color": Color.TRANSPARENT,
		}

	var center: Vector3 = sim.target_position(site)
	var radial := point - center
	var drift := air_drift(site, radial, sim.target_velocity(site))
	var relative := velocity - drift
	var layer := profile(site)
	var height: float = layer.height
	var altitude := radial.length() - float(Catalog.site(site).radius)
	var depth := _depth(altitude, height)
	return {
		"site": site, "inside": depth > 0.0, "near": altitude <= height + NEAR_MARGIN,
		"density": float(layer.density) * depth * depth, "altitude": altitude,
		"relative_speed": relative.length(), "vertical_speed": radial.normalized().dot(relative),
		"drift": drift, "height": height, "depth": depth, "color": layer.color,
	}


static func drag(velocity: Vector3, drift: Vector3, density: float, delta: float) -> Vector3:
	if density <= 0.0 or delta <= 0.0 or not is_finite(density) or not is_finite(delta) \
			or not velocity.is_finite() or not drift.is_finite():
		return velocity
	var relative := velocity - drift
	# This is the exact quadratic-drag solution for constant density over a step.
	var divisor := 1.0 + DRAG_COEFFICIENT * density * relative.length() * delta
	return drift + relative / divisor


static func drag_at_epoch(system: int, point: Vector3, velocity: Vector3, epoch: float, delta: float) -> Vector3:
	if not point.is_finite() or not is_finite(epoch):
		return velocity
	var site := _site_for_point(system, point, epoch)
	if site < 0:
		return velocity
	var state := Orbit.sample(site, epoch)
	var radial := point - Vector3(state.position)
	var altitude := radial.length() - float(Catalog.site(site).radius)
	var layer := profile(site)
	var depth := _depth(altitude, layer.height)
	return drag(velocity, air_drift(site, radial, state.velocity), float(layer.density) * depth * depth, delta)


static func air_drift(site: int, radial: Vector3, orbital: Vector3) -> Vector3:
	# Solid bodies entrain the air above the rotating surface. Giant cloud belts
	# use a slower planetary rotation because there is no solid reference pad.
	var rotation := Vector3.UP.cross(radial) * GAS_ROTATION if Catalog.is_gas_giant(site) else Terrain.spin_velocity(site, radial)
	return orbital + rotation


static func heat_target(relative_speed: float, density: float) -> float:
	if relative_speed <= 0.0 or density <= 0.0 or not is_finite(relative_speed) or not is_finite(density):
		return 0.0
	var ratio := relative_speed / HEAT_REFERENCE_SPEED
	return minf(MAX_HEAT_TARGET, HEAT_SCALE * density * ratio * ratio * ratio)


static func _depth(altitude: float, height: float) -> float:
	return clampf((height - altitude) / height, 0.0, 1.0)


static func _site_for_system(system: int) -> int:
	return _system_sites.get(system, -1)


static func _site_for_point(system: int, point: Vector3, epoch: float, sim: RefCounted = null) -> int:
	if system != Catalog.SOLAR_SYSTEM:
		return _site_for_system(system)
	if not point.is_finite():
		return -1
	# A multi-planet system has no single global atmosphere. Compare shell
	# heights at the queried position, including the forecast's moving epoch.
	var nearest := -1
	var nearest_height := INF
	for site: int in Catalog.system(system).get("atmospheric_sites", []):
		var layer := profile(site)
		var height := float(layer.get("height", 0.0))
		if height <= 0.0:
			continue
		var center: Vector3 = sim.target_position(site) if sim != null else Orbit.sample(site, epoch).position
		var normalized_height := (point.distance_to(center) - float(Catalog.site(site).radius)) / height
		if normalized_height < nearest_height:
			nearest = site
			nearest_height = normalized_height
	return nearest


static func _build_system_sites() -> Dictionary[int, int]:
	var sites: Dictionary[int, int] = {}
	for system in range(Catalog.SYSTEM_COUNT):
		var giant := Catalog.gas_giant_for(system)
		if giant >= 0:
			sites[system] = giant
	for site: int in PROFILES:
		sites[Catalog.system_of_site(site)] = site
	return sites
