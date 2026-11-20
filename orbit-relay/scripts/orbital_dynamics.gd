extends RefCounted
## Gravity acting on the ship in the current system's inertial frame.

const Catalog = preload("res://scripts/sector_catalog.gd")
const Orbit = preload("res://scripts/orbit_ephemeris.gd")

# Multiply radius cubed by a scaled density to get mu in game units (m^3/s^2).
const PLANET_DENSITY := 0.00022
const MOON_DENSITY := 0.00010
const MIN_SOURCE_RADIUS := 0.001


class Attractor:
	var site: int
	var radius: float
	var mu: float

	func _init(site_id: int, source_radius: float, gravity: float) -> void:
		site = site_id
		radius = source_radius
		mu = gravity


static var _attractors: Array[Array] = _build_attractors()


static func acceleration(sim: RefCounted, point: Vector3) -> Vector3:
	var system: int = sim.system_id
	if system < 0 or system >= _attractors.size():
		return Vector3.ZERO
	var total := Vector3.ZERO
	for source: Attractor in _attractors[system]:
		total += point_acceleration(point, sim.target_position(source.site), source.mu, source.radius)
	return total


static func acceleration_at_epoch(system: int, point: Vector3, epoch: float) -> Vector3:
	if system < 0 or system >= _attractors.size():
		return Vector3.ZERO
	var total := Vector3.ZERO
	for source: Attractor in _attractors[system]:
		var center: Vector3 = Orbit.sample(source.site, epoch).position
		total += point_acceleration(point, center, source.mu, source.radius)
	return total


static func point_acceleration(point: Vector3, center: Vector3, mu: float, min_radius: float) -> Vector3:
	var offset := center - point
	var radius := maxf(min_radius, MIN_SOURCE_RADIUS)
	# Outside the source the field is inverse square. Inside, the uniform-density
	# sphere solution stays finite and joins the exterior at the surface.
	var sampling_radius_squared := maxf(offset.length_squared(), radius * radius)
	return offset * (mu / (sampling_radius_squared * sqrt(sampling_radius_squared)))


static func _build_attractors() -> Array[Array]:
	var by_system: Array[Array] = []
	for system_id in range(Catalog.SYSTEM_COUNT):
		var sources: Array[Attractor] = [
			Attractor.new(Catalog.star_for(system_id), Catalog.STAR_CLEARANCE, Orbit.GRAVITY_PARAMETERS[system_id]),
		]
		for site_id: int in Catalog.targets_for(system_id):
			var site := Catalog.site(site_id)
			var density := 0.0
			match site.kind:
				"planet": density = PLANET_DENSITY
				"moon": density = MOON_DENSITY
			if density > 0.0:
				var radius: float = site.radius
				sources.append(Attractor.new(site_id, radius, density * radius * radius * radius))
		by_system.append(sources)
	return by_system
