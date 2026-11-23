extends RefCounted
## Osculating elements and an engine-off forecast in the system or body frame.

const Catalog = preload("res://scripts/sector_catalog.gd")
const Dynamics = preload("res://scripts/orbital_dynamics.gd")
const Orbit = preload("res://scripts/orbit_ephemeris.gd")
const Terrain = preload("res://scripts/surface_terrain.gd")
const Ground = preload("res://scripts/ground_port.gd")
const Atmosphere = preload("res://scripts/atmosphere.gd")
const MAX_FORECAST_SECONDS := 240.0
const FORECAST_STEP := 0.25
const MAX_POINTS := 128
const MIN_RADIUS := 0.001
const PARABOLIC_ENERGY_FRACTION := 0.000001
const PORT_CORRIDOR_RADIUS := 4.4
const PORT_CORRIDOR_INSET := 0.8
const LOCAL_SURFACE_MARGIN := 18.0
const LOCAL_RADIUS_CAP := 3.5
const HILL_FRACTION := 0.85


static func elements(at: Vector3, velocity: Vector3, center: Vector3, mu: float) -> Dictionary:
	var result := {
		"valid": false, "radius": -1.0, "radial_speed": 0.0, "circular_speed": 0.0,
		"periapsis": -1.0, "apoapsis": -1.0, "eccentricity": 0.0, "period": -1.0, "bound": false,
	}
	var radial := at - center
	var radius := radial.length()
	if not radial.is_finite() or not velocity.is_finite() or not is_finite(radius) \
			or radius < MIN_RADIUS or not is_finite(mu) or mu <= 0.0:
		return result
	var angular_momentum := radial.cross(velocity)
	var eccentricity := (velocity.cross(angular_momentum) / mu - radial / radius).length()
	var energy := velocity.length_squared() * 0.5 - mu / radius
	if not is_finite(eccentricity) or not is_finite(energy):
		return result
	result.valid = true
	result.radius = radius
	result.radial_speed = velocity.dot(radial / radius)
	result.circular_speed = sqrt(mu / radius)
	result.periapsis = (angular_momentum.length_squared() / mu) / (1.0 + eccentricity)
	result.eccentricity = eccentricity
	result.bound = energy < -PARABOLIC_ENERGY_FRACTION * (mu / radius)
	if result.bound:
		var semi_major := -mu / (2.0 * energy)
		result.apoapsis = maxf(result.periapsis, 2.0 * semi_major - result.periapsis)
		result.period = TAU * sqrt(semi_major * semi_major * semi_major / mu)
	return result


static func orbit_normal(radial: Vector3, velocity: Vector3, fallback: Vector3) -> Vector3:
	if not radial.is_finite() or radial.length_squared() < MIN_RADIUS * MIN_RADIUS:
		return Vector3.ZERO
	var outward := radial.normalized()
	var tangent := velocity.slide(outward)
	if not tangent.is_finite() or tangent.length_squared() < 0.0001:
		tangent = fallback.slide(outward)
	if not tangent.is_finite() or tangent.length_squared() < 0.0001:
		var axis := Vector3.UP if absf(outward.y) < 0.9 else Vector3.RIGHT
		tangent = axis.slide(outward)
	return outward.cross(tangent.normalized()).normalized()


static func circular_velocity(radial: Vector3, normal: Vector3, mu: float) -> Vector3:
	if not radial.is_finite() or not normal.is_finite() or not is_finite(mu) or mu <= 0.0:
		return Vector3.ZERO
	var radius := radial.length()
	if radius < MIN_RADIUS or not is_finite(radius):
		return Vector3.ZERO
	var tangent := normal.normalized().cross(radial / radius)
	if tangent.length_squared() < 0.00000001:
		return Vector3.ZERO
	return tangent.normalized() * sqrt(mu / radius)


static func orbit_band(focus_id: int, center: Vector3, primary_center: Vector3, primary_mu: float) -> Vector2:
	var site := Catalog.site(focus_id)
	var kind: String = site.get("kind", "")
	if kind not in ["planet", "moon", "gas"] or not center.is_finite() or not primary_center.is_finite():
		return Vector2.ZERO
	var separation := center.distance_to(primary_center)
	if not is_finite(separation) or primary_mu <= 0.0:
		return Vector2.ZERO
	var radius: float = site.radius
	var mu := Dynamics.gravity_parameter(focus_id)
	var minimum := radius * Terrain.MAX_RADIUS_FACTOR + Terrain.CONTACT_CLEARANCE + LOCAL_SURFACE_MARGIN
	var cap := radius * LOCAL_RADIUS_CAP
	if kind == "gas":
		minimum = radius + float(Atmosphere.profile(focus_id).get("height", 0.0)) + LOCAL_SURFACE_MARGIN
		cap = radius * Dynamics.GAS_FULL_GRAVITY_RADII
	# The approximate Hill radius limits where a local two-body maneuver is offered.
	var hill := separation * pow(mu / (3.0 * primary_mu), 1.0 / 3.0)
	return Vector2(minimum, minf(cap, HILL_FRACTION * hill))


static func forecast(sim: RefCounted, horizon := 180.0, focus_id := -1) -> Dictionary:
	var result := {
		"points": PackedVector3Array(), "relative_points": PackedVector3Array(), "focus_id": -1,
		"seconds": 0.0, "impact": -1,
	}
	var system: int = sim.system_id
	var epoch: float = sim.orbit_time
	var position: Vector3 = sim.position
	var velocity: Vector3 = sim.velocity
	if not Catalog.is_system_id(system) or not is_finite(epoch) \
			or not position.is_finite() or not velocity.is_finite() or not is_finite(horizon) \
			or horizon <= 0.0 or sim.docked >= 0 or sim.landed or sim.jump_seconds_left > 0.0:
		return result

	var ids: Array = sim.local_targets()
	var relative := focus_id in ids
	var focus_start := Vector3.ZERO
	var relative_points := PackedVector3Array()
	if relative:
		focus_start = Orbit.sample(focus_id, epoch).position
		relative_points.append(position)
	var blockers := _blockers(sim, ids)
	var previous_centers := _centers_at(blockers, epoch)
	var duration := minf(horizon, MAX_FORECAST_SECONDS)
	var steps := ceili(duration / FORECAST_STEP)
	var sample_every := ceili(float(steps) / (MAX_POINTS - 1))
	var delta := duration / steps
	var points := PackedVector3Array([position])
	for step in range(1, steps + 1):
		var time := step * delta
		var future_centers := _centers_at(blockers, epoch + time)
		var half_step := delta * 0.5
		velocity += Dynamics.acceleration_at_epoch(system, position, epoch + time - delta) * half_step
		# Sample halfway through the coast step so a fast entry sees drag even
		# if the segment starts just above the atmosphere.
		var midpoint := position + velocity * half_step
		velocity = Atmosphere.drag_at_epoch(system, midpoint, velocity, epoch + time - half_step, delta)
		var next := position + velocity * delta
		velocity += Dynamics.acceleration_at_epoch(system, next, epoch + time) * half_step
		var contact := _swept_contact(blockers, previous_centers, future_centers, position, next, epoch + time - delta, delta)
		if contact.id >= 0:
			var impact_position := position.lerp(next, contact.fraction)
			var impact_time: float = time - delta + contact.fraction * delta
			var impact_moved := impact_position != points[-1]
			if impact_moved:
				points.append(impact_position)
			if relative:
				var projection := _relative_position(impact_position, focus_id, focus_start, epoch + impact_time)
				if impact_moved or projection != relative_points[-1]:
					relative_points.append(projection)
			result.seconds = impact_time
			result.impact = contact.id
			break
		position = next
		previous_centers = future_centers
		if step % sample_every == 0 or step == steps:
			points.append(position)
			if relative:
				relative_points.append(_relative_position(position, focus_id, focus_start, epoch + time))
	result.points = points
	result.relative_points = relative_points
	result.focus_id = focus_id if relative else -1
	if result.impact < 0:
		result.seconds = duration
	return result


static func _relative_position(position: Vector3, focus_id: int, focus_start: Vector3, epoch: float) -> Vector3:
	var future: Vector3 = Orbit.sample(focus_id, epoch).position
	return position + (focus_start - future)


static func _blockers(sim: RefCounted, ids: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: int in ids:
		var site := Catalog.site(id)
		var axes := Vector3.ONE * Catalog.stellar_clearance(id)
		var corridor := INF
		if Catalog.is_port(id):
			axes = Vector3(sim.HULL_X, sim.HULL_Y, sim.HULL_Z)
			corridor = float(site.pad_offset) - PORT_CORRIDOR_INSET
		elif Catalog.is_mine_site(id):
			axes = Vector3.ONE * (float(site.radius) * Terrain.MAX_RADIUS_FACTOR + Terrain.CONTACT_CLEARANCE)
		elif Catalog.is_gas_giant(id):
			axes = Vector3.ONE * float(site.radius)
		result.append({"id": id, "axes": axes, "corridor": corridor})
	return result


static func _centers_at(blockers: Array[Dictionary], epoch: float) -> PackedVector3Array:
	var centers := PackedVector3Array()
	for blocker in blockers:
		centers.append(Orbit.sample(blocker.id, epoch).position)
	return centers


static func _swept_contact(blockers: Array[Dictionary], before: PackedVector3Array, after: PackedVector3Array,
		from: Vector3, to: Vector3, epoch: float, delta: float) -> Dictionary:
	var nearest := 2.0
	var body := -1
	for index in range(blockers.size()):
		var blocker := blockers[index]
		var start := from - before[index]
		var end := to - after[index]
		if Ground.is_port(blocker.id):
			if _sphere_entry(start / 15.0, end / 15.0) >= 0.0:
				var local_start := Ground.basis(blocker.id, epoch).transposed() * start
				var local_end := Ground.basis(blocker.id, epoch + delta).transposed() * end
				var entry := Ground.hull_entry(blocker.id, local_start, local_end)
				if entry >= 0.0 and entry < nearest:
					nearest = entry
					body = blocker.id
			continue
		var axes: Vector3 = blocker.axes
		var fraction := _sphere_entry(start / axes, end / axes)
		if fraction < 0.0:
			continue
		var corridor: float = blocker.corridor
		if is_finite(corridor):
			var contact := start.lerp(end, fraction)
			if contact.z >= corridor and Vector2(contact.x, contact.y).length_squared() < PORT_CORRIDOR_RADIUS * PORT_CORRIDOR_RADIUS:
				fraction = _corridor_exit(start, end, corridor)
				if fraction < 0.0 or (start.lerp(end, fraction) / axes).length_squared() >= 1.0:
					continue
		elif fraction == 0.0 and Catalog.is_mine_site(blocker.id) and start.dot(end - start) >= 0.0:
			# An ascent can begin inside the terrain envelope but outside the local surface.
			var local_direction := Terrain.spin_basis(blocker.id, epoch).transposed() * start.normalized()
			var surface := Terrain.radius_at(blocker.id, local_direction) + Terrain.CONTACT_CLEARANCE - 0.025
			if start.length_squared() >= surface * surface:
				continue
		if fraction < nearest:
			nearest = fraction
			body = blocker.id
	return {"fraction": nearest, "id": body}


static func _sphere_entry(start: Vector3, end: Vector3) -> float:
	var c := start.length_squared() - 1.0
	if c < 0.0:
		return 0.0
	var direction := end - start
	var a := direction.length_squared()
	var b := start.dot(direction)
	var discriminant := b * b - a * c
	if a <= 0.0 or b >= 0.0 or discriminant < 0.0:
		return -1.0
	var entry := (-b - sqrt(discriminant)) / a
	return entry if entry >= 0.0 and entry <= 1.0 else -1.0


static func _corridor_exit(start: Vector3, end: Vector3, floor_z: float) -> float:
	var exit := 2.0
	if end.z < floor_z:
		exit = (floor_z - start.z) / (end.z - start.z)
	var outer := Vector2(end.x, end.y)
	if outer.length_squared() >= PORT_CORRIDOR_RADIUS * PORT_CORRIDOR_RADIUS:
		var inner := Vector2(start.x, start.y)
		var axis := outer - inner
		var a := axis.length_squared()
		var b := inner.dot(axis)
		var c := inner.length_squared() - PORT_CORRIDOR_RADIUS * PORT_CORRIDOR_RADIUS
		if a > 0.0:
			exit = minf(exit, (-b + sqrt(maxf(0.0, b * b - a * c))) / a)
	return exit if exit >= 0.0 and exit <= 1.0 else -1.0
