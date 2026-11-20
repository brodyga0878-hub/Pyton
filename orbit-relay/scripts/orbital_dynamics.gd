extends RefCounted
## Gravity acting on the ship in the current system's inertial frame.

const Catalog = preload("res://scripts/sector_catalog.gd")
const Orbit = preload("res://scripts/orbit_ephemeris.gd")

# Multiply radius cubed by a scaled density to get mu in game units (m^3/s^2).
const PLANET_DENSITY := 0.00022
const MOON_DENSITY := 0.00010
const GAS_GIANT_DENSITY := 0.000024
const GAS_FULL_GRAVITY_RADII := 2.4
const GAS_FIELD_RADII := 3.0
const MIN_SOURCE_RADIUS := 0.001


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


static var _attractors: Array[Array] = _build_attractors()


static func gravity_parameter(site_id: int) -> float:
	var site := Catalog.site(site_id)
	var kind: String = site.get("kind", "")
	if kind == "star":
		return Orbit.GRAVITY_PARAMETERS[Catalog.system_of_site(site_id)]
	var density := 0.0
	match kind:
		"planet": density = PLANET_DENSITY
		"moon": density = MOON_DENSITY
		"gas": density = GAS_GIANT_DENSITY
		_: return 0.0
	var radius: float = site.radius
	return density * radius * radius * radius


static func acceleration(sim: RefCounted, point: Vector3) -> Vector3:
	var system: int = sim.system_id
	if system < 0 or system >= _attractors.size():
		return Vector3.ZERO
	var total := Vector3.ZERO
	for source: Attractor in _attractors[system]:
		total += _source_acceleration(source, point, sim.target_position(source.site))
	return total


static func acceleration_at_epoch(system: int, point: Vector3, epoch: float) -> Vector3:
	if system < 0 or system >= _attractors.size():
		return Vector3.ZERO
	var total := Vector3.ZERO
	for source: Attractor in _attractors[system]:
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


static func _build_attractors() -> Array[Array]:
	var by_system: Array[Array] = []
	for system_id in range(Catalog.SYSTEM_COUNT):
		var star_id := Catalog.star_for(system_id)
		var sources: Array[Attractor] = [Attractor.new(star_id, Catalog.STAR_CLEARANCE, gravity_parameter(star_id))]
		for site_id: int in Catalog.targets_for(system_id):
			if site_id == star_id:
				continue
			var mu := gravity_parameter(site_id)
			if mu > 0.0:
				sources.append(Attractor.new(site_id, Catalog.site(site_id).radius, mu, Catalog.is_gas_giant(site_id)))
		by_system.append(sources)
	return by_system
