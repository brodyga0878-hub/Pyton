extends RefCounted
## Gravity acting on the ship in the current system's inertial frame.

const Catalog = preload("res://scripts/sector_catalog.gd")
const Orbit = preload("res://scripts/orbit_ephemeris.gd")

const GAS_FULL_GRAVITY_RADII := 2.4
const GAS_FIELD_RADII := 3.0
const MIN_SOURCE_RADIUS := 0.001
const MAX_CACHED_SYSTEMS := 8


class Attractor:
	var site: int
	var radius: float
	var mu: float
	var localized: bool

	func _init(site_id: int, source_radius: float, gravity: float, local_field := false) -> void:
		site = site_id
		radius = source_radius
		mu = gravity
		localized = local_field


# Local flight and trajectory prediction share the sources for the system they sample.
static var _attractors: Dictionary[int, Array] = {}


static func gravity_parameter(site_id: int) -> float:
	return Orbit.body_gravity_parameter(site_id)


static func acceleration(sim: RefCounted, point: Vector3) -> Vector3:
	var system: int = sim.system_id
	if system < 0 or system >= Catalog.SYSTEM_COUNT:
		return Vector3.ZERO
	var total := Vector3.ZERO
	for source: Attractor in _sources_for(system):
		total += _source_acceleration(source, point, sim.target_position(source.site))
	return total


static func acceleration_at_epoch(system: int, point: Vector3, epoch: float) -> Vector3:
	if system < 0 or system >= Catalog.SYSTEM_COUNT:
		return Vector3.ZERO
	var total := Vector3.ZERO
	for source: Attractor in _sources_for(system):
		var center: Vector3 = Orbit.sample(source.site, epoch).position
		total += _source_acceleration(source, point, center)
	return total


static func _source_acceleration(source: Attractor, point: Vector3, center: Vector3) -> Vector3:
	var weight := 1.0
	if source.localized:
		# Retain the local well without perturbing legacy trajectories elsewhere.
		var relative_radius := point.distance_to(center) / source.radius
		if relative_radius >= GAS_FIELD_RADII:
			return Vector3.ZERO
		weight -= smoothstep(GAS_FULL_GRAVITY_RADII, GAS_FIELD_RADII, relative_radius)
	return point_acceleration(point, center, source.mu * weight, source.radius)


static func point_acceleration(point: Vector3, center: Vector3, mu: float, min_radius: float) -> Vector3:
	var offset := center - point
	var radius := maxf(min_radius, MIN_SOURCE_RADIUS)
	# Outside the source the field is inverse square. Inside, the uniform-density
	# sphere solution stays finite and joins the exterior at the surface.
	var sampling_radius_squared := maxf(offset.length_squared(), radius * radius)
	return offset * (mu / (sampling_radius_squared * sqrt(sampling_radius_squared)))


static func _sources_for(system_id: int) -> Array[Attractor]:
	if _attractors.has(system_id):
		return _attractors[system_id]
	if _attractors.size() >= MAX_CACHED_SYSTEMS:
		_attractors.erase(_attractors.keys()[0])
	var sources: Array[Attractor] = []
	for star_id: int in Catalog.stars_for(system_id):
		sources.append(Attractor.new(star_id, Catalog.stellar_clearance(star_id), gravity_parameter(star_id)))
	for site_id: int in Catalog.targets_for(system_id):
		if Catalog.is_star(site_id):
			continue
		var mu := gravity_parameter(site_id)
		if mu > 0.0:
			sources.append(Attractor.new(site_id, Catalog.site(site_id).radius, mu, Catalog.is_gas_giant(site_id)))
	_attractors[system_id] = sources
	return sources
