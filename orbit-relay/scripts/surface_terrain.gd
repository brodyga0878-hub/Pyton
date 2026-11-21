extends RefCounted
## Shared radial terrain used by the flight, survey and rendering code.

const Catalog = preload("res://scripts/sector_catalog.gd")
const CONTACT_CLEARANCE := 4.0
const MAX_RADIUS_FACTOR := 1.12
const MAX_LANDING_SLOPE := 28.0
const NORMAL_STEP := 0.0015
const MINIMUM_NORMAL_COS := cos(deg_to_rad(MAX_LANDING_SLOPE))
const DRILL_CLEARANCE := 1.05
const DRILL_MAX_GROUND_DISTANCE_SQUARED := 100.0
const LAZUR_SPIN_RATE := 0.025


class Profile:
	var kind: String
	var radius: float
	var pad_face: float
	var morph_phase: float
	var stretch: Vector3
	var wobble: float
	var base_height: float
	var crater_directions: Array[Vector3] = []
	var crater_widths: Array[float] = []
	var spin_axis := Vector3.UP
	var spin_rate := 0.0
	var spin_period := 0.0


static var _profiles: Dictionary[int, Profile] = _build_profiles()


static func spin_rate(id: int) -> float:
	var profile: Profile = _profiles.get(id)
	return profile.spin_rate if profile != null else 0.0


static func spin_basis(id: int, epoch: float) -> Basis:
	# Body-local to inertial. At the reference epoch the landing pad faces +Z.
	var profile: Profile = _profiles.get(id)
	if profile == null or profile.spin_rate == 0.0 or epoch == 0.0 or not is_finite(epoch):
		return Basis.IDENTITY
	var angle := fposmod(epoch, profile.spin_period) * profile.spin_rate
	return Basis(profile.spin_axis, angle)


static func spin_velocity(id: int, world_offset: Vector3) -> Vector3:
	# Velocity about the center only. Add its orbital velocity in the flight frame.
	var profile: Profile = _profiles.get(id)
	if profile == null or profile.spin_rate == 0.0 or not world_offset.is_finite():
		return Vector3.ZERO
	return profile.spin_axis.cross(world_offset) * profile.spin_rate


static func point(id: int, direction: Vector3) -> Vector3:
	var profile: Profile = _profiles.get(id)
	if profile == null:
		return Vector3.ZERO
	var unit := _unit(direction)
	return unit * _height(profile, unit)


static func radius_at(id: int, direction: Vector3) -> float:
	var profile: Profile = _profiles.get(id)
	if profile == null:
		return 0.0
	return _height(profile, _unit(direction))


static func normal(id: int, direction: Vector3) -> Vector3:
	var unit := _unit(direction)
	var profile: Profile = _profiles.get(id)
	if profile == null or unit == Vector3.BACK:
		return unit
	var around := _tangent_basis(unit)
	var first := _difference(profile, unit, around.x)
	var second := _difference(profile, unit, around.y)
	var result := first.cross(second).normalized()
	return result if not result.is_zero_approx() else unit


static func basis(id: int, direction: Vector3) -> Basis:
	return _tangent_basis(normal(id, direction))


static func contact(id: int, direction: Vector3) -> Vector3:
	var unit := _unit(direction)
	var profile: Profile = _profiles.get(id)
	if profile == null:
		return Vector3.ZERO
	return unit * (_height(profile, unit) + CONTACT_CLEARANCE)


static func deposit(id: int, direction: Vector3) -> Transform3D:
	var profile: Profile = _profiles.get(id)
	if profile == null:
		return Transform3D.IDENTITY
	var unit := _unit(direction)
	if unit == Vector3.BACK:
		return Transform3D(Basis.IDENTITY, Vector3(6.1, 0.36, profile.pad_face + DRILL_CLEARANCE))
	var axes := basis(id, unit)
	var tangent_offset := axes.x * 6.1 + axes.y * 0.36
	var cross_offset := axes.y * 6.1 - axes.x * 0.36
	var ground := unit * _height(profile, unit)
	# Keep the usual placement first and search shorter offsets on uneven terrain.
	for step: float in [1.0, 0.5, 0.25]:
		for offset: Vector3 in [tangent_offset, -tangent_offset, cross_offset, -cross_offset]:
			var nearby := _unit(ground + offset * step)
			var drill_normal := normal(id, nearby)
			if drill_normal.dot(nearby) < MINIMUM_NORMAL_COS:
				continue
			var drill_ground := point(id, nearby)
			if drill_ground.distance_squared_to(ground) <= DRILL_MAX_GROUND_DISTANCE_SQUARED:
				return Transform3D(_tangent_basis(drill_normal), drill_ground + drill_normal * DRILL_CLEARANCE)
	return Transform3D(axes, ground + axes.z * DRILL_CLEARANCE)


static func landable(id: int, direction: Vector3) -> bool:
	if not _profiles.has(id) or not direction.is_finite() or direction.is_zero_approx():
		return false
	var unit := _unit(direction)
	return normal(id, unit).dot(unit) >= MINIMUM_NORMAL_COS


static func _height(profile: Profile, unit: Vector3) -> float:
	if unit == Vector3.BACK:
		return profile.pad_face
	var weight := 0.0
	var plane := 0.0
	if unit.z > 0.4:
		plane = profile.pad_face / unit.z
		var from_pad := plane * Vector2(unit.x, unit.y).length()
		if from_pad <= 11.0:
			return plane
		weight = 1.0 - smoothstep(11.0, 23.0, from_pad)

	# Evaluate the profile in ellipsoid coordinates, then recover its radial size
	# in the requested direction. The same ray serves collision and mesh queries.
	var scaled := unit / profile.stretch
	var ray_length := scaled.length()
	var d := scaled / ray_length
	var shape := profile.base_height
	shape += sin(d.x * 7.5 + d.z * 4.5 + profile.morph_phase) * profile.wobble * 0.62
	shape += sin(d.y * 9.0 - d.x * 6.0 + profile.morph_phase) * cos(d.z * 10.0) * profile.wobble * 0.38
	shape += sin(d.y * 23.2 + d.z * 13.0) * sin(d.x * 26.0) * profile.wobble * 0.14
	if profile.kind == "comet":
		shape += smoothstep(0.27, 0.74, absf(d.x)) * 0.12 - 0.04
	for index in range(profile.crater_directions.size()):
		var width := profile.crater_widths[index]
		var distance_squared := d.distance_squared_to(profile.crater_directions[index])
		var influence := width * 1.28
		if distance_squared > influence * influence:
			continue
		var distance := sqrt(distance_squared)
		var valley := 1.0 - smoothstep(width * 0.35, width, distance)
		var rim := 1.0 - smoothstep(width * 0.05, width * 0.28, absf(distance - width))
		shape += 0.028 * rim - 0.105 * valley
	var terrain := clampf(profile.radius * shape / ray_length, profile.radius * 0.6, profile.radius * MAX_RADIUS_FACTOR)
	return lerpf(terrain, plane, weight)


static func _difference(profile: Profile, unit: Vector3, tangent: Vector3) -> Vector3:
	var positive := (unit + tangent * NORMAL_STEP).normalized()
	var negative := (unit - tangent * NORMAL_STEP).normalized()
	return positive * _height(profile, positive) - negative * _height(profile, negative)


static func _tangent_basis(outward: Vector3) -> Basis:
	var up := Vector3.UP if absf(outward.y) < 0.98 else Vector3.RIGHT
	var right := up.cross(outward).normalized()
	return Basis(right, outward.cross(right), outward)


static func _unit(direction: Vector3) -> Vector3:
	if not direction.is_finite() or direction.is_zero_approx():
		return Vector3.BACK
	return direction.normalized()


static func _build_profiles() -> Dictionary[int, Profile]:
	var result: Dictionary[int, Profile] = {}
	for id in range(Catalog.DESTINATION_COUNT):
		if not Catalog.is_mine_site(id):
			continue
		var entry := Catalog.site(id)
		var profile := Profile.new()
		profile.kind = entry.kind
		profile.radius = entry.radius
		profile.pad_face = float(entry.pad_offset) - CONTACT_CLEARANCE
		var random := RandomNumberGenerator.new()
		random.seed = entry.seed
		profile.morph_phase = random.randf_range(-PI, PI)
		profile.stretch = Vector3(random.randf_range(0.96, 1.13), random.randf_range(0.83, 1.07), 0.95)
		profile.wobble = 0.085
		profile.base_height = 0.90
		var crater_count := 5
		match profile.kind:
			"moon":
				profile.stretch = Vector3(1.0, 0.98, 1.0)
				profile.wobble = 0.032
				profile.base_height = 0.975
				crater_count = 9
			"comet":
				profile.stretch = Vector3(1.24, 0.82, 0.88)
				profile.wobble = 0.068
			"planet":
				profile.stretch = Vector3(1.0, 0.98, 1.0)
				profile.wobble = 0.026
				profile.base_height = 0.985
				crater_count = 7
		for index in range(crater_count):
			var angle := TAU * float(index) / crater_count + random.randf_range(-0.17, 0.17)
			var elevation := random.randf_range(0.08, 0.82) if index % 3 != 2 else random.randf_range(-0.9, -0.25)
			var reach := sqrt(1.0 - elevation * elevation)
			profile.crater_directions.append(Vector3(cos(angle) * reach, sin(angle) * reach, elevation))
			profile.crater_widths.append(random.randf_range(0.12, 0.26))
		if id == Catalog.GROUND_BODY or Catalog.is_generated_system(Catalog.system_of_site(id)):
			# A separate seed keeps rotation independent of terrain sampling and its artwork.
			random.seed = int(entry.seed) ^ 0x5E4F9B2D
			profile.spin_rate = LAZUR_SPIN_RATE if id == Catalog.GROUND_BODY else random.randf_range(0.025, 0.052)
			profile.spin_period = TAU / profile.spin_rate
			var tilt := deg_to_rad(random.randf_range(6.0, 28.0))
			var azimuth := random.randf_range(0.0, TAU)
			profile.spin_axis = Vector3(cos(azimuth) * sin(tilt), cos(tilt), sin(azimuth) * sin(tilt)).normalized()
		result[id] = profile
	return result
