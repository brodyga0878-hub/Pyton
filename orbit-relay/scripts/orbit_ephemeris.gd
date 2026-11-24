extends RefCounted
## Analytic orbits in the system's inertial frame. Epoch positions match the
## catalog, and a moving parent contributes both position and velocity.

const Catalog = preload("res://scripts/sector_catalog.gd")
const Ground = preload("res://scripts/ground_port.gd")
const Terrain = preload("res://scripts/surface_terrain.gd")
const GRAVITY_PARAMETERS := [8500.0, 8000.0, 7600.0, 8100.0, 7400.0]
const BODY_DENSITIES := {"planet": 0.00022, "moon": 0.00010, "gas": 0.000024}
const ORBIT_SEGMENTS := 96
const MAX_CACHED_TRACKS := 64

# Eccentricity, true anomaly at the epoch and inclination adjustment in degrees.
# The inclination adjustment rotates the path about the initial star-to-site ray.
const ELEMENTS := {
	0: Vector3(0.101, 107.0, -7.2),
	1: Vector3(0.024, 126.6, 29.8),
	2: Vector3(0.060, 66.1, -6.5),
	3: Vector3(0.091, 93.1, 37.2),
	4: Vector3(0.147, 62.8, 18.5),
	5: Vector3(0.010, 135.5, 0.8),
	6: Vector3(0.099, 26.5, -1.3),
	7: Vector3(0.020, 90.0, 0.0),
	8: Vector3(0.145, 92.5, -24.6),
	10: Vector3(0.140, 185.4, 2.1),
	11: Vector3(0.150, 43.8, 4.6),
	12: Vector3(0.020, 90.0, 0.0),
	13: Vector3(0.001, 56.2, -0.7),
	Catalog.TERRACE_ID: Vector3(0.032, 91.0, 12.0),
	Catalog.FRINGE_ARRIVAL_PORT: Vector3(0.022, 102.0, 7.0),
	Catalog.FRINGE_SECOND_PORT: Vector3(0.035, 148.0, -19.0),
	Catalog.FRINGE_ASTEROID_ID: Vector3(0.104, 52.0, 32.0),
	Catalog.HEATHER_PORT: Vector3(0.027, 118.0, 9.0),
	Catalog.HEATHER_PLANET: Vector3(0.052, 74.0, -11.0),
	Catalog.HEATHER_MOON: Vector3(0.062, 125.0, 16.0),
	Catalog.LIMIT_PORT: Vector3(0.039, 125.0, -8.0),
	Catalog.LIMIT_PLANET: Vector3(0.041, 90.0, 25.0),
	Catalog.LIMIT_ASTEROID: Vector3(0.077, 72.0, 9.0),
	Catalog.GAS_GIANT_ID: Vector3(0.042, 82.0, -8.0),
}


class Track:
	var parent := -1
	var astronomical := false
	var semimajor := 0.0
	var epoch: Vector3
	var focus: Vector3
	var major_axis: Vector3
	var minor_axis: Vector3
	var eccentricity: float
	var mean_at_epoch: float
	var eccentric_at_epoch: float
	var mean_motion: float
	var period: float
	var points := PackedVector3Array()


# Track parameters are cheap to reconstruct after leaving a system. Only the map builds path vertices.
static var _tracks: Dictionary[int, Track] = {}


static func sample(site_id: int, seconds: float) -> Dictionary:
	if not Catalog.is_site_id(site_id):
		return {"position": Vector3.ZERO, "velocity": Vector3.ZERO}
	if Ground.is_port(site_id):
		var host := Ground.body(site_id)
		var surface := sample(host, seconds)
		var offset := Ground.anchor_offset(site_id, seconds)
		return {"position": surface.position + offset, "velocity": surface.velocity + Terrain.spin_velocity(host, offset)}
	var track := _track_for(site_id)
	if track.period <= 0.0:
		return {"position": track.epoch, "velocity": Vector3.ZERO}
	if track.astronomical:
		var state := _astronomical_state(track, seconds)
		if track.parent >= 0:
			var parent := sample(track.parent, seconds if is_finite(seconds) else 0.0)
			state.position += parent.position
			state.velocity += parent.velocity
		return state
	var eccentric_angle := track.eccentric_at_epoch
	if seconds != 0.0 and is_finite(seconds):
		var mean := wrapf(track.mean_at_epoch + track.mean_motion * fposmod(seconds, track.period), -PI, PI)
		eccentric_angle = mean
		if track.eccentricity > 0.0:
			# Newton iteration for E - e*sin(E) = M.
			for iteration in range(4):
				var error := eccentric_angle - track.eccentricity * sin(eccentric_angle) - mean
				var slope := 1.0 - track.eccentricity * cos(eccentric_angle)
				eccentric_angle -= error / slope
	var sine := sin(eccentric_angle)
	var cosine := cos(eccentric_angle)
	var angular_speed := track.mean_motion / (1.0 - track.eccentricity * cosine)
	var velocity := (track.minor_axis * cosine - track.major_axis * sine) * angular_speed
	var position := track.epoch if seconds == 0.0 else _position(track, sine, cosine)
	if track.parent >= 0:
		var parent := sample(track.parent, seconds)
		position += parent.position
		velocity += parent.velocity
	return {"position": position, "velocity": velocity}


static func orbit_parent(site_id: int) -> int:
	if Ground.is_port(site_id):
		return Ground.body(site_id)
	return _track_for(site_id).parent if Catalog.is_site_id(site_id) else -1


static func orbit_points(site_id: int, epoch := 0.0) -> PackedVector3Array:
	if not Catalog.is_site_id(site_id):
		return PackedVector3Array()
	var track := _track_for(site_id)
	if track.period > 0.0 and track.points.is_empty():
		_build_points(track)
	if track.parent < 0:
		return track.points
	var center: Vector3 = sample(track.parent, epoch).position
	var result := PackedVector3Array()
	result.resize(track.points.size())
	for index in range(track.points.size()):
		result[index] = center + track.points[index]
	return result


static func period(site_id: int) -> float:
	if Ground.is_port(site_id):
		return period(Ground.body(site_id))
	return _track_for(site_id).period if Catalog.is_site_id(site_id) else 0.0


static func extrema(site_id: int) -> Vector2:
	if not Catalog.is_site_id(site_id) or Ground.is_port(site_id):
		return Vector2.ZERO
	var track := _track_for(site_id)
	if track.period <= 0.0:
		return Vector2.ZERO
	if track.astronomical:
		return Vector2(track.semimajor * (1.0 - track.eccentricity), track.semimajor * (1.0 + track.eccentricity))
	return Vector2(1.0 - track.eccentricity, 1.0 + track.eccentricity) * track.major_axis.length()


static func gravity_parameter(system_id: int) -> float:
	if system_id >= 0 and system_id < Catalog.AUTHORED_SYSTEM_COUNT:
		return GRAVITY_PARAMETERS[system_id]
	return Catalog.system(system_id).get("gravity_parameter", 0.0)


static func body_gravity_parameter(site_id: int) -> float:
	var site := Catalog.site(site_id)
	if site.has("mu"):
		return float(site.mu)
	var kind: String = site.get("kind", "")
	if kind == "star":
		return gravity_parameter(Catalog.system_of_site(site_id))
	var radius: float = site.get("radius", 0.0)
	return float(BODY_DENSITIES.get(kind, 0.0)) * radius * radius * radius


static func _track_for(site_id: int) -> Track:
	if _tracks.has(site_id):
		return _tracks[site_id]
	if _tracks.size() >= MAX_CACHED_TRACKS:
		_tracks.erase(_tracks.keys()[0])
	var track := _build_track(site_id)
	_tracks[site_id] = track
	return track


static func _build_track(site_id: int) -> Track:
	var site := Catalog.site(site_id)
	var system_id := Catalog.system_of_site(site_id)
	var system := Catalog.system(system_id)
	if site.get("astronomical_orbit") is Dictionary:
		return _build_astronomical_track(site_id, site, system)
	if system.has("barycenter"):
		return _build_binary_track(site, system)
	var track := Track.new()
	track.epoch = site.center
	var elements: Vector3 = ELEMENTS.get(site_id, site.get("orbital_elements", Vector3.ZERO))
	if elements == Vector3.ZERO:
		return track
	var eccentricity := elements.x
	track.eccentricity = eccentricity
	track.parent = int(site.get("orbit_parent", -1))
	var mu := gravity_parameter(system_id)
	if track.parent >= 0:
		track.epoch -= Vector3(Catalog.site(track.parent).center)
		mu = body_gravity_parameter(track.parent)
	else:
		track.focus = Catalog.site(Catalog.star_for(system_id)).center
	var offset := track.epoch - track.focus
	var radial := offset.normalized()
	var tangent := radial.cross(Vector3.UP).normalized().rotated(radial, deg_to_rad(elements.z))
	var true_anomaly := deg_to_rad(elements.y)
	var cosine := cos(true_anomaly)
	var sine := sin(true_anomaly)
	var axis_factor := sqrt(1.0 - eccentricity * eccentricity)
	var semi_major := offset.length() * (1.0 + eccentricity * cosine) / (axis_factor * axis_factor)
	track.major_axis = (radial * cosine - tangent * sine) * semi_major
	track.minor_axis = (radial * sine + tangent * cosine) * (semi_major * axis_factor)
	track.eccentric_at_epoch = atan2(axis_factor * sine, eccentricity + cosine)
	track.mean_at_epoch = track.eccentric_at_epoch - eccentricity * sin(track.eccentric_at_epoch)
	track.mean_motion = sqrt(mu / (semi_major * semi_major * semi_major))
	track.period = TAU / track.mean_motion
	return track


static func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _kepler_difference(angle: float) -> float:
	# E - sin(E) loses its small cubic term near periapsis. Its Taylor form
	# keeps the safeguarded solve useful for eccentricities close to one.
	if absf(angle) >= 0.01:
		return angle - sin(angle)
	var square := angle * angle
	return angle * square / 6.0 * (1.0 - square / 20.0 + square * square / 840.0 - square * square * square / 60480.0)


static func _normalized_angle(angle: float) -> float:
	# fmod preserves tiny anomalies instead of adding/subtracting PI first.
	var value := fmod(angle, TAU)
	return value - TAU if value > PI else value + TAU if value < -PI else value


static func solve_eccentric_anomaly(mean: float, eccentricity: float) -> float:
	if not is_finite(mean) or not is_finite(eccentricity) or eccentricity < 0.0 or eccentricity >= 1.0:
		return NAN
	mean = _normalized_angle(mean)
	if eccentricity == 0.0 or mean == 0.0:
		return mean
	var low := -PI
	var high := PI
	var angle := mean
	if eccentricity >= 0.8:
		# Near periapsis, seed with the smaller linear/cubic solution. This also
		# resolves tiny means at e -> 1 without spending the budget bisecting PI.
		angle = signf(mean) * minf(PI, minf(absf(mean) / (1.0 - eccentricity), pow(6.0 * absf(mean) / eccentricity, 1.0 / 3.0)))
	for iteration in range(80):
		var error := (1.0 - eccentricity) * angle + eccentricity * _kepler_difference(angle) - mean
		if error == 0.0:
			return angle
		if error > 0.0:
			high = angle
		else:
			low = angle
		var half_sine := sin(angle * 0.5)
		var slope := (1.0 - eccentricity) + 2.0 * eccentricity * half_sine * half_sine
		var candidate := angle - error / slope
		if not is_finite(candidate) or candidate <= low or candidate >= high:
			candidate = low + (high - low) * 0.5
		if candidate == angle:
			return angle
		angle = candidate
	return angle


static func _track_from_astronomical_elements(elements: Dictionary, focus := Vector3.ZERO) -> Track:
	var result := Track.new()
	result.epoch = focus
	for field: String in ["semimajor", "eccentricity", "inclination", "ascending_node", "argument_of_periapsis", "mean_anomaly", "period"]:
		if not _finite_number(elements.get(field)):
			return result
	var major := float(elements.semimajor)
	var eccentricity := float(elements.eccentricity)
	var seconds := float(elements.period)
	if major <= 0.0 or eccentricity < 0.0 or eccentricity >= 1.0 or seconds <= 0.0 or not focus.is_finite():
		return result
	var motion := TAU / seconds
	if not is_finite(motion) or motion <= 0.0:
		return result
	var maximum_speed := major * motion * sqrt((1.0 + eccentricity) / (1.0 - eccentricity))
	if not (Vector3.ONE * major * 2.0).is_finite() or not (Vector3.ONE * maximum_speed).is_finite():
		return result
	var inclination := deg_to_rad(fposmod(float(elements.inclination), 360.0))
	var node := deg_to_rad(fposmod(float(elements.ascending_node), 360.0))
	var periapsis := deg_to_rad(fposmod(float(elements.argument_of_periapsis), 360.0))
	var cn := cos(node)
	var sn := sin(node)
	var cp := cos(periapsis)
	var sp := sin(periapsis)
	var ci := cos(inclination)
	var si := sin(inclination)
	# Classical J2000 ecliptic XYZ is represented as scene (X, Z, -Y).
	# This is a proper rotation: +Y is the scene's ecliptic north pole.
	var p := Vector3(cn * cp - sn * sp * ci, sp * si, -(sn * cp + cn * sp * ci))
	var q := Vector3(-cn * sp - sn * cp * ci, cp * si, -(-sn * sp + cn * cp * ci))
	result.major_axis = p * major
	result.minor_axis = q * (major * sqrt((1.0 - eccentricity) * (1.0 + eccentricity)))
	if not result.major_axis.is_finite() or not result.minor_axis.is_finite():
		return Track.new()
	result.focus = focus
	result.eccentricity = eccentricity
	result.semimajor = major
	result.mean_at_epoch = _normalized_angle(deg_to_rad(fmod(float(elements.mean_anomaly), 360.0)))
	result.eccentric_at_epoch = solve_eccentric_anomaly(result.mean_at_epoch, eccentricity)
	result.mean_motion = motion
	result.period = seconds
	result.astronomical = true
	result.epoch = _position(result, sin(result.eccentric_at_epoch), cos(result.eccentric_at_epoch))
	if not result.epoch.is_finite() or not _astronomical_state(result, 0.0).velocity.is_finite():
		return Track.new()
	return result


static func _build_astronomical_track(site_id: int, site: Dictionary, _system: Dictionary) -> Track:
	var parent := int(site.get("orbit_parent", -1))
	if parent >= 0:
		# A supplied catalog graph must terminate inside this same system.
		var ancestors := {}
		ancestors[site_id] = true
		var cursor := parent
		for depth in range(64):
			if ancestors.has(cursor) or not Catalog.is_site_id(cursor) or Catalog.system_of_site(cursor) != Catalog.system_of_site(site_id):
				return Track.new()
			ancestors[cursor] = true
			cursor = int(Catalog.site(cursor).get("orbit_parent", -1))
			if cursor < 0:
				break
		if cursor >= 0:
			return Track.new()
	var focus := Vector3.ZERO if parent >= 0 else Vector3(Catalog.site(Catalog.star_for(Catalog.system_of_site(site_id))).center)
	var track := _track_from_astronomical_elements(site.astronomical_orbit, focus)
	track.parent = parent if track.astronomical else -1
	return track


static func _astronomical_state(track: Track, seconds: float) -> Dictionary:
	var elapsed := seconds if is_finite(seconds) else 0.0
	var mean := _normalized_angle(track.mean_at_epoch + track.mean_motion * fposmod(elapsed, track.period))
	var angle := track.eccentric_at_epoch if elapsed == 0.0 else solve_eccentric_anomaly(mean, track.eccentricity)
	var sine := sin(angle)
	var cosine := cos(angle)
	var half_sine := sin(angle * 0.5)
	var rate := track.mean_motion / ((1.0 - track.eccentricity) + 2.0 * track.eccentricity * half_sine * half_sine)
	return {"position": _position(track, sine, cosine), "velocity": (track.minor_axis * cosine - track.major_axis * sine) * rate}


static func sample_elements(elements: Dictionary, seconds := 0.0) -> Dictionary:
	# Public pure boundary for catalog/audit callers. Invalid or parabolic and
	# hyperbolic elements are unavailable, never a fabricated circular orbit.
	var track := _track_from_astronomical_elements(elements)
	return _astronomical_state(track, seconds) if track.astronomical else {}


static func _build_binary_track(site: Dictionary, system: Dictionary) -> Track:
	var track := Track.new()
	track.parent = int(site.get("orbit_parent", -1))
	track.focus = system.barycenter
	track.epoch = site.center
	var mu := float(system.gravity_parameter)
	if track.parent >= 0:
		var parent := Catalog.site(track.parent)
		track.epoch -= parent.center
		track.focus = Vector3.ZERO
		mu = float(parent.mu)
	track.major_axis = track.epoch - track.focus
	var semimajor := track.major_axis.length()
	var tilt_axis := track.major_axis.normalized()
	var inclination := float(site.get("orbit_inclination", system.binary_inclination))
	if site.kind == "star":
		# Both stellar tracks use opposite scaled axes of the same relative orbit.
		# Its angular rate depends on the total mass and full stellar separation.
		semimajor = system.binary_separation
		tilt_axis = Vector3.RIGHT
	var normal := Vector3.UP.rotated(tilt_axis, deg_to_rad(inclination))
	track.minor_axis = track.major_axis.cross(normal)
	track.mean_motion = sqrt(mu / (semimajor * semimajor * semimajor))
	track.period = TAU / track.mean_motion
	return track


static func _build_points(track: Track) -> void:
	track.points.append(track.epoch)
	for segment in range(1, ORBIT_SEGMENTS):
		var angle := track.eccentric_at_epoch + TAU * float(segment) / ORBIT_SEGMENTS
		track.points.append(_position(track, sin(angle), cos(angle)))
	track.points.append(track.epoch)


static func _position(track: Track, sine: float, cosine: float) -> Vector3:
	return track.focus + track.major_axis * (cosine - track.eccentricity) + track.minor_axis * sine
