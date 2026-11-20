extends RefCounted
## Elliptic two-body orbits around each system's fixed primary. Positions at
## epoch zero coincide with the chart coordinates of saves before orbital motion.

const Catalog = preload("res://scripts/sector_catalog.gd")
const GRAVITY_PARAMETERS := [8500.0, 8000.0, 7600.0, 8100.0, 7400.0]
const ORBIT_SEGMENTS := 96

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


static var _tracks: Array[Track] = _build_tracks()


static func sample(site_id: int, seconds: float) -> Dictionary:
	if site_id < 0 or site_id >= _tracks.size():
		return {"position": Vector3.ZERO, "velocity": Vector3.ZERO}
	var track := _tracks[site_id]
	if track.period <= 0.0:
		return {"position": track.epoch, "velocity": Vector3.ZERO}
	var eccentric_angle := track.eccentric_at_epoch
	if seconds != 0.0 and is_finite(seconds):
		var mean := wrapf(track.mean_at_epoch + track.mean_motion * fposmod(seconds, track.period), -PI, PI)
		eccentric_angle = mean
		# Newton iteration for E - e*sin(E) = M. Catalog eccentricities are below 0.2.
		for iteration in range(4):
			var error := eccentric_angle - track.eccentricity * sin(eccentric_angle) - mean
			var slope := 1.0 - track.eccentricity * cos(eccentric_angle)
			eccentric_angle -= error / slope
	var sine := sin(eccentric_angle)
	var cosine := cos(eccentric_angle)
	var angular_speed := track.mean_motion / (1.0 - track.eccentricity * cosine)
	var velocity := (track.minor_axis * cosine - track.major_axis * sine) * angular_speed
	var position := track.epoch if seconds == 0.0 else _position(track, sine, cosine)
	return {"position": position, "velocity": velocity}


static func orbit_points(site_id: int) -> PackedVector3Array:
	if site_id < 0 or site_id >= _tracks.size():
		return PackedVector3Array()
	return _tracks[site_id].points


static func period(site_id: int) -> float:
	return _tracks[site_id].period if site_id >= 0 and site_id < _tracks.size() else 0.0


static func _build_tracks() -> Array[Track]:
	var result: Array[Track] = []
	for site_id in range(Catalog.DESTINATION_COUNT):
		var track := Track.new()
		track.epoch = Catalog.site(site_id).center
		if ELEMENTS.has(site_id):
			var system_id := Catalog.system_of_site(site_id)
			var elements: Vector3 = ELEMENTS[site_id]
			var eccentricity := elements.x
			track.eccentricity = eccentricity
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
			track.mean_motion = sqrt(GRAVITY_PARAMETERS[system_id] / (semi_major * semi_major * semi_major))
			track.period = TAU / track.mean_motion
			track.points.append(track.epoch)
			for segment in range(1, ORBIT_SEGMENTS):
				var angle := track.eccentric_at_epoch + TAU * float(segment) / ORBIT_SEGMENTS
				track.points.append(_position(track, sin(angle), cos(angle)))
			track.points.append(track.epoch)
		result.append(track)
	return result


static func _position(track: Track, sine: float, cosine: float) -> Vector3:
	return track.focus + track.major_axis * (cosine - track.eccentricity) + track.minor_axis * sine
